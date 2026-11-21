-- Shy.Screen: the screen and the size of everything on it.
--
-- The size is the game's own two settings, "Use UI Scale" (useUiScale) and its slider (uiScale, 0.65 to
-- 1.15), so the game's options and Shy's always agree. The game's number is no size the eye knows: at 1 the
-- screen is 768 units high whatever its pixels (a unit is 1.9 pixels at 1440p), and with Use UI Scale off
-- the game picks a unit to a pixel, never under 0.64 (1440p comes to 0.64: 2133 x 1200 units). Shy says
-- sizes against that: 100% is the game's own size for the screen, "normal", what the family is drawn at;
-- 90% is smaller, 120% larger. Under the game's floor there is nothing to go to, so on a large screen the
-- sizes start at 100%.
--
--   Shy.Screen.Pixels()        the screen's width and height in pixels
--   Shy.Screen.Room(scale)     the screen's width and height in units, now or at the game's `scale`
--   Shy.Screen.Scale()         the game's scale now (UIParent's)
--   Shy.Screen.Normal()        the game's own scale for this screen (seen with Use UI Scale off, kept by screen)
--   Shy.Screen.Own()           the game's scale you set while Use UI Scale is on, else nil
--   Shy.Screen.Size(scale)     a scale as a size against normal, in whole percent (100: normal); now without one
--   Shy.Screen.ScaleOf(size)   the game's scale for a size; nil for 100 (the game's own)
--   Shy.Screen.Sizes()         the least and the most size the game's slider allows on this screen
--   Shy.Screen.Suggested()     the size suggested for this screen (Suggested, below)
--   Shy.Screen.Fits(size)      does every layout of the family fit whole at that size (now, without one)
--   Shy.Screen.Set(size)       puts a size on (100 or nil: the game's own); false and why ("combat", "refused")
--   Shy.Screen.ROOM            the room every layout of the family fits in whole (see ROOM)
--
-- Bus: SHY_SCREEN, once a change of the scale or of the screen has settled (a frame later, when every
-- frame has its new size). Whoever planned something for the old screen (ShyDock's console) hears it.
--
-- Setup asks it first, as a strip over the profile's section (its step is `inside` the profile's), and the
-- /shy window's Screen room has the same strip.

local Shy = Shy
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors
local core = Shy.core
local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

local Sc = {}
Shy.Screen = Sc
core.keep.screen = true   -- ShyCoreDB.screen: the game's own scale by screen, the account's

-- The game's slider (Blizzard_SettingsDefinitions_Shared/Graphics.lua: .65 to 1.15 by .01).
local MIN, MAX = 0.65, 1.15
-- The interface is 768 units high at scale 1; at any other scale it is 768 / scale (UIParent).
local HIGH = 768
-- The game's own scale goes no lower than this (1440p's, under the slider's least).
local FLOOR = 0.64
-- Every layout and size of ShyDock's console fits whole from this room up (its corner layouts, Grand,
-- beside the plates); under it the wings give way and the small frames stand on their roofs.
Sc.ROOM = { w = 1728, h = 1080 }
-- Never so small that a unit is under this much of a pixel: the text stays sharp and readable.
local SHARP = 0.9

-- The game's scale on its slider's steps, as whole hundredths (0.7, not 0.70000000000000007).
local function Snap(scale) return floor(scale * 100 + 0.5) / 100 end
local function Clamp(scale) return max(MIN, min(MAX, scale)) end

function Sc.Pixels()
	local w, h = GetPhysicalScreenSize()
	if not (w and h) or w <= 0 or h <= 0 then return HIGH * 16 / 9, HIGH end
	return w, h
end

local function Key()
	local w, h = Sc.Pixels()
	return w .. "x" .. h
end

function Sc.Scale()
	return UIParent:GetScale()
end

function Sc.Room(scale)
	if not scale then return UIParent:GetWidth(), UIParent:GetHeight() end
	local w, h = Sc.Pixels()
	local high = HIGH / scale
	return high * w / h, high
end

function Sc.Own()
	if not C_CVar.GetCVarBool("useUiScale") then return nil end
	return Clamp(Snap(tonumber(C_CVar.GetCVar("uiScale")) or 1))
end

-- The game's own scale: as it stands while Use UI Scale is off (and kept for this screen), else as it stood
-- last time on this screen, else what the game picks (a unit to a pixel, never under its floor).
local function Kept()
	local db = rawget(_G, "ShyCoreDB")
	if not db then return nil end
	db.screen = db.screen or {}
	return db.screen
end

function Sc.Normal()
	local kept = Kept()
	if not C_CVar.GetCVarBool("useUiScale") then
		local now = Sc.Scale()
		if kept then kept[Key()] = now end
		return now
	end
	local _, h = Sc.Pixels()
	return kept and kept[Key()] or max(FLOOR, HIGH / h)
end

function Sc.Size(scale)
	return floor((scale or Sc.Scale()) / Sc.Normal() * 100 + 0.5)
end

function Sc.ScaleOf(size)
	if size == nil or size == 100 then return nil end
	return Clamp(Snap(size / 100 * Sc.Normal()))
end

function Sc.Sizes()
	local normal = Sc.Normal()
	return min(100, ceil(MIN / normal * 100 - 0.001)), max(100, floor(MAX / normal * 100 + 0.001))
end

-- The suggestion, as the game's scale: as large as the system's own text scaling asks (a unit to a pixel,
-- times it), no larger than lets every layout fit whole (ROOM), and never so small that a unit is under
-- SHARP of a pixel. As a size, on whole percents, rounded down (a little more room, never less); the
-- game's own when it comes to that, or when the game can't go that small.
function Sc.Suggested()
	local w, h = Sc.Pixels()
	local crisp = HIGH / h
	local dpi = tonumber(GetScreenDPIScale()) or 1
	if dpi < 1 or dpi > 4 then dpi = 1 end
	local fit = HIGH / max(Sc.ROOM.h, Sc.ROOM.w * h / w)
	local scale = max(min(crisp * dpi, fit), crisp * SHARP)
	local lo, hi = Sc.Sizes()
	local size = floor(scale / Sc.Normal() * 100 + 0.001)
	if abs(size - 100) <= 1 then return 100 end
	return max(lo, min(hi, size))
end

function Sc.Fits(size)
	local w, h = Sc.Room(size and (Sc.ScaleOf(size) or Sc.Normal()))
	return w >= Sc.ROOM.w - 0.5 and h >= Sc.ROOM.h - 0.5
end

-- SetCVar fails silently for a setting the game keeps from addons, so each is read back.
local function Write(name, value)
	C_CVar.SetCVar(name, value)
	local now = C_CVar.GetCVar(name)
	return now ~= nil and abs((tonumber(now) or -1) - tonumber(value)) < 0.001
end

function Sc.Set(size)
	if InCombatLockdown() then return false, "combat" end
	Sc.Normal()   -- the game's own, kept while it still stands (Use UI Scale off)
	local scale = Sc.ScaleOf(size)
	if scale == nil then
		if not C_CVar.GetCVarBool("useUiScale") or Write("useUiScale", "0") then return true end
		return false, "refused"
	end
	local own = Sc.Own()
	if own and abs(own - scale) < 0.001 then return true end
	if not Write("uiScale", ("%.2f"):format(scale)) then return false, "refused" end
	if not C_CVar.GetCVarBool("useUiScale") and not Write("useUiScale", "1") then return false, "refused" end
	return true
end

local WHY = {
	combat = "You're in combat. Try again after combat.",
	refused = "The game won't let addons change this. Set it in the game's options, under Graphics.",
}

-- The bus: one SHY_SCREEN a frame after the game's events (they come in twos, and frames take their
-- new sizes from them).
local settling
local events = CreateFrame("Frame")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function()
	if settling then return end
	settling = true
	C_Timer.After(0, function()
		settling = nil
		Shy:Fire("SHY_SCREEN")
	end)
end)

-- The strip, as setup and the /shy window have it. `state` holds the pick: { pick = "suggested" | "game" |
-- "own", size = percent } (setup's plan.scale; the /shy window's own, which follows the screen). `live`: each
-- pick goes on at once (setup puts the plan on as its page shows, and on each pick).
--
--   |  Size                 [=========o==========]  100%   [ Suggested ]  [ Normal ]  |
--   |  2560 x 1440 screen                                                              |
--      Everything has room at this size.
--
-- One panel in the family's make, an accent edge down its left, the title in the brand's letters with the
-- screen under it; the slider (taken when it is let go) and its value, large; the two quick picks, the
-- picked one in the accent (a primary button). A line under the panel says what the size comes to.

-- What a state comes to: a size (100: the game's own).
local function Wanted(state)
	if state.pick == "game" then return 100 end
	if state.pick == "suggested" then return Sc.Suggested() end
	return state.size
end

-- The state the screen is in now.
local function Read(state)
	local own = Sc.Own()
	state.size = own and Sc.Size(own) or 100
	if not own then
		state.pick = "game"
	elseif state.size == Sc.Suggested() then
		state.pick = "suggested"
	else
		state.pick = "own"
	end
	return state
end

-- Puts the state on. nil, or why it couldn't (a sentence).
local function Wear(state)
	local ok, why = Sc.Set(Wanted(state))
	if ok then return nil end
	return WHY[why] or WHY.refused
end

local function Screen()
	local w, h = Sc.Pixels()
	return ("%d \195\151 %d"):format(w, h)
end

local function Percent(size) return size .. "%" end

local PANEL_H, EDGE, PAD = 58, 3, 16
local NAME_W = 150                       -- the title and the screen under it
local VALUE_W = 64                       -- the size, large
local PICK_H, PICK_GAP = 26, 8
local NOTE_H = 20

local function Strip(parent, width, state)
	local f = CreateFrame("Frame", nil, parent)
	-- Narrow: the quick picks on a row of their own under the slider.
	local wide = width >= 700
	local panelH = wide and PANEL_H or PANEL_H + PICK_H + 10
	f:SetSize(width, panelH + 6 + NOTE_H)

	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT")
	panel:SetSize(width, panelH)
	UI.Skin(panel, C.row, C.border)
	local edge = panel:CreateTexture(nil, "ARTWORK")
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMLEFT", 1, 1)
	edge:SetWidth(EDGE)
	Theme.Paint(edge, Theme.Accent, 1)

	local name = UI.Text(panel, "Size", 16, true, C.head)
	name:SetPoint("TOPLEFT", PAD + EDGE, -13)
	local screen = UI.Text(panel, "", 11, false, C.dim)
	screen:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)

	local value = UI.Text(panel, "", 22, true, C.head)
	value:SetJustifyH("RIGHT")
	value:SetWidth(VALUE_W)

	local picks = {}
	local failed, held
	local Paint
	local function Pick(pick, size)
		state.pick = pick
		if size then state.size = size end
		failed = state.live and Wear(state) or nil
		Paint()
	end
	picks.game = UI.Button(panel, "Normal", 92, function() Pick("game") end)
	picks.suggested = UI.Button(panel, "Suggested", 132, function() Pick("suggested") end)
	for _, b in pairs(picks) do b:SetHeight(PICK_H) end

	local lo, hi = Sc.Sizes()
	local pickW = 92 + PICK_GAP + 132
	local slideW = wide and (width - PAD - EDGE - NAME_W - VALUE_W - 14 - pickW - 2 * PAD) or (width - PAD - EDGE - NAME_W - VALUE_W - 14 - PAD)
	-- The value shows as the knob moves; the screen takes it when the knob is let go.
	local slider = UI.Slider(panel, "", lo, hi, 1, function()
		return held or Wanted(state)
	end, function(v)
		held = v
		value:SetText(Percent(v))
	end, {
		width = slideW,
		format = function() return "" end,
		desc = "Smaller fits more on screen. Larger is easier to read. The game's options have the same setting.",
		settle = function(v)
			held = nil
			if v == Wanted(state) then return end
			Pick(v == 100 and "game" or v == Sc.Suggested() and "suggested" or "own", v)
		end,
	})
	slider:SetPoint("TOPLEFT", PAD + EDGE + NAME_W, -(PANEL_H - 38) / 2 + 6)
	value:SetPoint("LEFT", slider, "RIGHT", 14, -6)
	if wide then
		picks.game:SetPoint("RIGHT", panel, "TOPRIGHT", -PAD, -PANEL_H / 2)
	else
		picks.game:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -PANEL_H - 2)
	end
	picks.suggested:SetPoint("RIGHT", picks.game, "LEFT", -PICK_GAP, 0)

	local note = UI.Text(f, "", 11, false, C.dim)
	note:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", PAD + EDGE, -6)
	note:SetWidth(width - 2 * PAD)
	note:SetWordWrap(false)
	note:SetJustifyH("LEFT")

	Paint = function()
		local suggested, size = Sc.Suggested(), Wanted(state)
		screen:SetText(Screen() .. " screen")
		value:SetText(Percent(held or size))
		picks.suggested:SetLabel(suggested == 100 and "Suggested" or ("Suggested " .. Percent(suggested)))
		picks.suggested:SetPrimary(state.pick == "suggested")
		picks.game:SetPrimary(state.pick == "game")
		slider:Refresh()
		if failed then
			note:SetText(failed)
			UI.Ink(note, C.alert)
			return
		end
		local words
		if state.pick == "suggested" and suggested == 100 then
			words = "Your screen has room for everything at its normal size."
		elseif Sc.Fits(size) then
			words = size == 100 and "Normal: the size the game picks for your screen. Everything has room."
				or "Everything has room at this size."
		else
			words = "Some pieces move aside to fit at this size. Go smaller to give them room."
		end
		if lo >= 100 and size == 100 then words = words .. " The game can't go smaller on this screen." end
		note:SetText(words)
		UI.Ink(note, C.dim)
	end

	function f:Refresh()
		if state.follow then Read(state) end
		Paint()
	end
	f.slider, f.picks = slider, picks
	return f
end

-- Setup's step: a strip over the profile's section, the first thing set, so every preview after it (the
-- looks, the layout) is drawn at the size the screen will have and the console is planned on that screen.

local function Lines(plan)
	local s = plan.scale
	local size = Wanted(s)
	if size == 100 then return { { text = "Everything at normal size", sub = "the game's own for your " .. Screen() .. " screen" } } end
	return { { text = "Everything at " .. Percent(size), sub = s.pick == "suggested" and ("suggested for your " .. Screen() .. " screen")
		or "your own size" } }
end

Shy.Setup.Step({
	id = "scale", order = 5, title = "Size", inside = "profile", atOpen = true, glyph = "size",
	brief = function(plan) return Percent(Wanted(plan.scale)) end,
	-- Recommended: a size you chose stays as it is (setup opening never resizes your screen under you); on the
	-- game's own size, the suggested one.
	Plan = function(plan)
		local own = Sc.Own()
		local size = own and Sc.Size(own) or 100
		local s = { live = true, size = size }
		plan.scale = s
		local suggested = Sc.Suggested()
		if not own or size == suggested then
			s.pick, s.size = "suggested", suggested
		else
			s.pick = "own"
		end
	end,
	Build = function(parent, width, plan) return Strip(parent, width, plan.scale) end,
	Lines = Lines,
	-- Live: the plan is on the screen while its page shows, and kept by Finish.
	Shown = function(plan) Wear(plan.scale) end,
	Run = function(plan)
		Wear(plan.scale)
		return false
	end,
	-- The setting is the game's, the same for every character and profile: put back as it stood.
	Worn = function()
		local own = Sc.Own()
		return { size = own and Sc.Size(own) or 100 }
	end,
	PutBack = function(kept) Sc.Set(kept.size) end,
})

-- The /shy window's Screen room: the same strip first, each pick put on as it is made, following the screen as it is.
Shy.HubSection("screen", function(page, top)
	local section = Strip(page, page.width, Read({ live = true, follow = true }))
	Shy.HubPlace(page, section, top)
	Shy:On("SHY_SCREEN", function() if section:IsVisible() then section:Refresh() end end)
	return section, function() section:Refresh() end
end, 10)

Shy.HubBrief("screen", function()
	local own = Sc.Own()
	return Percent(own and Sc.Size(own) or 100)
end)
