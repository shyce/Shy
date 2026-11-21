-- The cast row: the keel's bottom row (Plate.lua). It fades in while the keel grows downward, so nothing above moves.
-- Cast times can be secret: the bar takes the duration object (SetTimerDuration) and a text binding writes the seconds.
-- "Not interruptible" can be secret too: colors and the shield go through the boolean-evaluating setters.

local ADDON, ns = ...
local L = ns.Layout
local B, UI, Theme, Skin = Shy.Brand, Shy.UI, Shy.Theme, Shy.Skin
local Secret = ns.Secret

local Cast = {}
ns.Cast = Cast

local HOLD = 0.8      -- how long "interrupted" stays up
local REVEAL = 0.12   -- how long the row takes to fade in

local EVENTS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
	"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
-- Ignored while "Interrupted" is still showing.
local ENDS = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_CHANNEL_STOP = true }

local tenths
local function Tenths()
	if not tenths then
		tenths = C_StringUtil.CreateNumericRuleFormatter()
		tenths:AddBreakpoint({ threshold = 0, step = 0.1, format = "%.1f" })
	end
	return tenths
end

function Cast.Build(plate)
	-- Anchored to the keel's bottom, so the combo row above doesn't move.
	local row = CreateFrame("Frame", nil, plate.keel)
	row:SetPoint("BOTTOMLEFT", plate.keel, "BOTTOMLEFT", 0, L.KEEL.foot)
	row:SetPoint("BOTTOMRIGHT", plate.keel, "BOTTOMRIGHT", 0, L.KEEL.foot)
	row:SetHeight(L.CAST)
	row:Hide()

	local icon = CreateFrame("Frame", nil, row)
	icon:SetSize(L.CAST_ICON, L.CAST_ICON)
	icon:SetPoint("TOPLEFT", L.INSET, -2)
	icon.line = icon:CreateTexture(nil, "BACKGROUND")
	icon.line:SetAllPoints()
	icon.line:SetColorTexture(0.03, 0.03, 0.03, 1)
	icon.art = icon:CreateTexture(nil, "ARTWORK")
	icon.art:SetPoint("TOPLEFT", 1, -1)
	icon.art:SetPoint("BOTTOMRIGHT", -1, 1)
	icon.art:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- inside the icon's own border
	icon.shield = ns.Plate.Glyph(icon, "shield", 8)
	icon.shield:SetPoint("BOTTOMRIGHT", 2, -2)
	icon.shield:SetVertexColor(L.COLORS.silver[1], L.COLORS.silver[2], L.COLORS.silver[3])
	icon.shield:SetAlpha(0)

	local bar = ns.Plate.Bar(row)
	bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", L.INSET, 0)
	bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -L.INSET, 2)
	-- "Interrupted" is a separate texture: a bar driven by SetTimerDuration may not release its value at once.
	bar.stop = bar:CreateTexture(nil, "ARTWORK", nil, 1)
	bar.stop:SetAllPoints()
	Skin.Hatch(bar.stop)
	bar.stop:Hide()

	local over = CreateFrame("Frame", nil, row)   -- texts over the bar
	over:SetAllPoints()
	over:SetFrameLevel(bar:GetFrameLevel() + 2)
	bar.time = over:CreateFontString(nil, "OVERLAY")
	bar.time:SetPoint("RIGHT", bar, "RIGHT", -L.TEXT_INSET + 1, 0)
	bar.time:SetJustifyH("RIGHT")
	bar.time:SetWordWrap(false)
	bar.spell = over:CreateFontString(nil, "OVERLAY")
	bar.spell:SetPoint("LEFT", bar, "LEFT", L.TEXT_INSET - 1, 0)
	bar.spell:SetPoint("RIGHT", bar.time, "LEFT", -2, 0)   -- a long name gives way to the time
	bar.spell:SetJustifyH("LEFT")
	bar.spell:SetWordWrap(false)
	for _, fs in ipairs({ bar.time, bar.spell }) do
		fs:SetShadowColor(0, 0, 0, 1)
		fs:SetShadowOffset(0.8, -0.8)
	end

	bar.binding = C_DurationUtil.CreateDurationTextBinding()
	bar.binding:SetFontString(bar.time)
	bar.binding:SetFormatter(Tenths())

	plate.castRow, plate.cast, plate.castIcon = row, bar, icon
	plate.castEvents = CreateFrame("Frame", nil, plate.root)
	plate.castEvents:SetScript("OnEvent", function(_, event, _, _, _, by)
		Cast.OnEvent(plate, event, by)
	end)
end

function Cast.Arrange(plate)
	local bar = plate.cast
	bar.time:SetFontObject(ns.Plate.Font(L.TEXT - 1))
	bar.spell:SetFontObject(ns.Plate.Font(L.TEXT - 1))
end

-- Fade in while the keel grows; plate.castGrow is the eased share of the row's height.
local function Reveal(plate)
	local row, t = plate.castRow, 0
	row:SetAlpha(0)
	plate.castGrow = 0
	plate:Stack()
	row:SetScript("OnUpdate", function(_, elapsed)
		t = t + elapsed
		local k = math.min(1, t / REVEAL)
		row:SetAlpha(k)
		plate.castGrow = 1 - (1 - k) * (1 - k)
		if k >= 1 then
			plate.castGrow = nil
			row:SetScript("OnUpdate", nil)
		end
		plate:Stack()
	end)
end

local function Show(plate, casting)
	local row, bar = plate.castRow, plate.cast
	local was = plate.casting
	plate.casting = casting
	if casting then plate.castStopped = nil end
	bar.fill:SetAlpha(1)
	bar.stop:Hide()
	if casting then
		if not was then
			row:Show()
			-- No reveal on a plate that was just attached.
			if plate.fresh then
				row:SetAlpha(1)
				plate.castGrow = nil
				plate:Stack()
			else
				Reveal(plate)
			end
		end
	else
		row:SetScript("OnUpdate", nil)
		bar:SetScript("OnUpdate", nil)
		row:Hide()
		plate.castGrow = nil
		plate:Stack()
	end
end

-- A plate with no cast is stopped once: every plate let go of, and every end of a cast, asks again.
function Cast.Stop(plate)
	plate.castHold = nil
	if plate.castStopped then return end
	plate.cast.binding:SetEnabled(false)
	Show(plate, false)
	plate.castStopped = true
end

-- `locked` (not interruptible) may be secret: the game then picks the color and the shield's alpha.
local function Dress(plate, locked, channel)
	local bar, shield = plate.cast, plate.castIcon.shield
	local r, g, b
	if channel then r, g, b = B.Ramp(0.8) else r, g, b = Theme.Accent() end
	if not Secret(locked) and not locked then
		bar:SetStatusBarColor(r, g, b)
		shield:SetAlpha(0)
		return
	end
	local idle, Pick = Skin.colors.idle, C_CurveUtil.EvaluateColorValueFromBoolean
	bar:SetStatusBarColor(Pick(locked, idle[1], r), Pick(locked, idle[2], g), Pick(locked, idle[3], b))
	shield:SetAlphaFromBoolean(locked, 1, 0)
end

function Cast.Read(plate)
	local unit = plate.unit
	if not unit then return end
	if not ns.T.db.casts or plate.mode ~= "full" then
		Cast.Stop(plate)
		return
	end
	local channel, duration = false, nil
	local name, text, texture, from, to, _, _, locked = UnitCastingInfo(unit)
	if Secret(name) or name ~= nil then
		duration = UnitCastingDuration(unit)
	else
		name, text, texture, from, to, _, locked = UnitChannelInfo(unit)
		if Secret(name) or name ~= nil then
			channel = true
			duration = UnitChannelDuration(unit)
		end
	end
	if not (Secret(name) or name ~= nil) or (not Secret(duration) and duration == nil) then
		Cast.Stop(plate)
		return
	end

	local bar = plate.cast
	plate.castHold = nil
	local timed = not Secret(duration)
	if timed then
		bar:SetScript("OnUpdate", nil)
		bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
			channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
	else
		-- A secret duration can't drive the timer, but secret start and end times can be passed to the bar.
		bar:SetMinMaxValues(from, to)
		bar:SetScript("OnUpdate", function(self) self:SetValue(GetTime() * 1000) end)
	end
	bar.spell:SetText(text)
	bar.spell:SetTextColor(1, 1, 1)
	plate.castIcon.art:SetTexture(texture)
	Dress(plate, locked, channel)
	Show(plate, true)
	bar.time:SetShown(timed and ns.T.db.castTime)
	if timed then bar.binding:SetDuration(duration) end
	bar.binding:SetEnabled(timed and ns.T.db.castTime)
end

function Cast.Interrupted(plate, by)
	if not plate.casting then return end
	local bar, bad = plate.cast, UI.colors.bad
	bar.binding:SetEnabled(false)
	bar.time:SetText("")
	bar:SetScript("OnUpdate", nil)
	bar.fill:SetAlpha(0)
	bar.stop:SetVertexColor(bad[1], bad[2], bad[3])
	bar.stop:Show()
	plate.castIcon.shield:SetAlpha(0)
	local who = nil
	if not Secret(by) and by ~= nil then who = UnitNameFromGUID(by) end
	if Secret(who) then
		bar.spell:SetFormattedText(SPELL_INTERRUPTED_BY, who)
	elseif who and who ~= "" and who ~= UNKNOWNOBJECT then
		bar.spell:SetText(SPELL_INTERRUPTED_BY:format(who))
	else
		bar.spell:SetText(INTERRUPTED)
	end
	local hold = GetTime() + HOLD
	plate.castHold = hold
	C_Timer.After(HOLD, function()
		if plate.castHold == hold then Cast.Read(plate) end   -- unless something happened since
	end)
end

function Cast.OnEvent(plate, event, by)
	-- CHANNEL_STOP carries the interrupter's GUID (possibly secret) only when the channel was interrupted.
	if event == "UNIT_SPELLCAST_INTERRUPTED" or (event == "UNIT_SPELLCAST_CHANNEL_STOP" and (Secret(by) or by ~= nil)) then
		Cast.Interrupted(plate, by)
	elseif ENDS[event] and plate.castHold and GetTime() < plate.castHold then
		return
	else
		Cast.Read(plate)
	end
end

function Cast.Attach(plate)
	local events, unit = plate.castEvents, plate.unit
	events:UnregisterAllEvents()
	for _, event in ipairs(EVENTS) do events:RegisterUnitEvent(event, unit) end
	Cast.Read(plate)
end

function Cast.Detach(plate)
	plate.castEvents:UnregisterAllEvents()
	Cast.Stop(plate)
end

-- Called on a theme or settings change.
function Cast.Paint(plate)
	if plate.unit then Cast.Read(plate) end
end
