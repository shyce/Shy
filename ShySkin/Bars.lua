-- Action bars: main, the seven extras, stance, pet and possess, and the extra ability's button, each
-- button a slot (kit:Tile).
-- Nothing is drawn on a bar itself: bars measure every region on them to size themselves.
-- Gryphons and page arrows are only tinted: a faded button would still take clicks.
-- Key bindings keep Blizzard's font: it has the "in range" dot, which ours lacks.

local ADDON, ns = ...
local C = Shy.Skin.colors

local RIM = 3        -- how far the slot's frame covers the icon
local GLOSS = 0.8    -- gloss alpha
local CROP = 0.08    -- trims the icon's own dark rim
local LOST = { 0.17, 0, 0, 0.64 }   -- loss-of-control swipe color (ActionButtonTemplate.xml)
local NAME = 9.5     -- on-screen height of a macro name
local NAME_MIN, NAME_MAX = 10, 14
local KEY_EMPTY = 0.6   -- an empty button's key: dim, there to say which key presses it

local bars

-- Heal fit: a heal's button carries a strip up its right edge, inside the frame, clear of the words on it.
-- Filled from the foot, mint is what of it would land on the friend you'd
-- cast it on (the one under your mouse, else your target, else you), soft red what would be wasted. The heal's
-- size is ShyHots' (the tables with your healing power and talents). What is missing is the game's, heals on
-- their way counted, and goes to the bar unread, so it works in a fight. It shows only while they're hurt.
-- Nothing runs while nothing changes.
local FIT = { width = 3, inset = 2, seam = 0.7, track = 0.9, shade = 0.85, shadeWidth = 14, poll = 0.1, art = "Interface\\Buttons\\WHITE8X8" }
local FIT_BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight",
	"MultiBar5", "MultiBar6", "MultiBar7" }
local fit = { strips = {}, shown = 0 }   -- button -> its strip; how many show; the unit drawn; a draw waiting

-- Edit Mode scales the button's holder, so the font size is divided by that scale.
local function PaintName(kit, button)
	local size = math.floor(NAME / button.container:GetScale() + 0.5)
	size = math.max(NAME_MIN, math.min(NAME_MAX, size))
	kit:FontObject(button.Name, Shy.UI.NameFont(size, "OUTLINE"))   -- macro names are player-made: any alphabet
end

-- A secret action counts as filled.
local function Filled(button)
	local action = button.action
	if action == nil or issecretvalue(action) then return true end
	local has = HasAction(action)
	if issecretvalue(has) then return true end
	return has and true or false
end

-- Touches only our own regions, so it is safe in combat.
local function PaintFill(m, kit, button)
	local tile = kit:Tile(button, { icon = button.icon })
	local filled = Filled(button)
	tile:Empty(not filled)
	-- (an empty slot keeps its key, dim, on every bar: the keys say which key presses a button you could fill.
	-- A button no key presses has none to show: the game puts its label away.)
	if m.opt.hotkeys then kit:Fade(button.HotKey, filled and 1 or KEY_EMPTY) end
	return tile
end

-- A stance button's key: the game never fills its label (only action buttons fill theirs), so the skin writes one
-- of its own, as every other button has. 1, 2 and 3 then say what they press.
local function PaintStanceKey(m, kit, button)
	local command = button.commandName
	if not (command and command:find("^SHAPESHIFTBUTTON")) then return end
	local key = m.opt.hotkeys and GetBindingKey(command)
	kit:KeyLabel(button, key and GetBindingText(key, 1) or nil)
end

local function PaintButton(m, kit, button)
	kit:Hide(button.NormalTexture)
	kit:Hide(button.SlotBackground)
	kit:Hide(button.SlotArt)
	kit:Hide(button.HighlightTexture)
	kit:Unmask(button.icon, button.IconMask)
	kit:Crop(button.icon, CROP, 1 - CROP, CROP, 1 - CROP)
	local tile = PaintFill(m, kit, button)
	if m.opt.gloss then tile:Clip(ns.Gloss(kit, button, { x = RIM, y = RIM, alpha = GLOSS })) end
	kit:Swipe(button.cooldown, { inside = true, size = tile.level })
	kit:Swipe(button.lossOfControlCooldown, { inside = true, color = LOST, size = tile.level })
	ns.Lit(kit, button.PushedTexture, button, C.lit)
	ns.Lit(kit, button.CheckedTexture, button, C.on)
	ns.Number(kit, button.Count)
	PaintName(kit, button)
	if not m.opt.hotkeys then kit:Hide(button.HotKey) end
	if not m.opt.macros then kit:Hide(button.Name) end
	PaintStanceKey(m, kit, button)
end

-- The extra ability's button (one a fight or a quest hands you) is a slot like the rest. It has no slot
-- art of its own to put away, and the picture the game draws round it is left to whoever seats the button.
local function PaintExtra(m, kit)
	local button = ExtraActionButton1
	kit:Hide(button.HighlightTexture)
	kit:Unmask(button.icon, button.IconMask)
	kit:Crop(button.icon, CROP, 1 - CROP, CROP, 1 - CROP)
	local tile = kit:Tile(button, { icon = button.icon })
	if m.opt.gloss then tile:Clip(ns.Gloss(kit, button, { x = RIM, y = RIM, alpha = GLOSS })) end
	kit:Swipe(button.cooldown, { inside = true, size = tile.level })
	kit:Swipe(button.lossOfControlCooldown, { inside = true, color = LOST, size = tile.level })
	ns.Lit(kit, button.PushedTexture, button, C.lit)
	ns.Number(kit, button.Count)
	if not m.opt.hotkeys then kit:Hide(button.HotKey) end
end

-- Heal fit

local function Plain(x) return x ~= nil and not issecretvalue(x) end

-- A friend you can heal, there and alive. What the game keeps is no answer.
local function Helpable(unit)
	local there = UnitExists(unit)
	if not Plain(there) or not there then return false end
	local help, dead = UnitCanAssist("player", unit), UnitIsDeadOrGhost(unit)
	return Plain(help) and Plain(dead) and help and not dead
end

-- Whom a heal key lands on: as the keys' own macros choose.
local function Whom()
	if Helpable("mouseover") then return "mouseover" end
	if Helpable("target") then return "target" end
	return "player"
end

local function DrawFit()
	local unit = Whom()
	fit.unit = unit
	local missing = UnitHealthMissing(unit, true)
	local hurt = UnitHealthPercent(unit, true, Shy.UI.HurtCurve())
	for _, strip in pairs(fit.strips) do
		if strip.size then
			if strip.most ~= strip.size then
				strip.most = strip.size
				strip:SetMinMaxValues(0, strip.size)
			end
			strip:SetValue(missing)
			strip:SetAlpha(hurt)
		end
	end
end

-- While it shows the friend under your mouse, a look now and then for them going: the game says when one
-- comes under it, not when one goes.
local Poll
Poll = Shy.Clocked("ShySkin heal fit", function()
	fit.polling = false
	if fit.unit ~= "mouseover" or fit.shown == 0 then return end
	if not Helpable("mouseover") then return DrawFit() end
	fit.polling = true
	C_Timer.After(FIT.poll, Poll)
end)

local Draw = Shy.Clocked("ShySkin heal fit", function()
	fit.waiting = false
	DrawFit()
	if fit.unit == "mouseover" and not fit.polling then
		fit.polling = true
		C_Timer.After(FIT.poll, Poll)
	end
end)

-- Drawn once on the next frame, however many changes come before it.
local function MarkFit()
	if fit.shown == 0 or fit.waiting then return end
	fit.waiting = true
	C_Timer.After(0, Draw)
end

-- What one cast of the button's spell heals; nil for anything that is no heal on one friend.
local function HealOn(button)
	local hots = Shy.addons.Hots
	local action = button.action
	if not (hots and hots.HealSize) or not Plain(action) or not HasAction(action) then return nil end
	local spell = C_ActionBar.GetSpell(action)
	if not Plain(spell) then return nil end
	return hots:HealSize(spell)
end

local function NewStrip(button)
	local strip = CreateFrame("StatusBar", nil, button)
	strip:SetPoint("TOPRIGHT", button, "TOPRIGHT", -RIM, -RIM - FIT.inset)
	strip:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -RIM, RIM + FIT.inset)
	strip:SetWidth(FIT.width)
	strip:SetOrientation("VERTICAL")
	strip:SetFrameLevel(button:GetFrameLevel() + 4)   -- over the cooldown's swipe
	strip:SetStatusBarTexture(FIT.art)
	local good, bad = Shy.UI.colors.good, Shy.UI.colors.bad
	strip:SetStatusBarColor(good[1], good[2], good[3], 1)
	local track = strip:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetTexture(FIT.art)
	track:SetVertexColor(bad[1], bad[2], bad[3], FIT.track)
	-- A shade behind it, deepest at the edge and gone toward the middle, so it reads on any picture.
	local shade = strip:CreateTexture(nil, "BACKGROUND", nil, -8)
	shade:SetColorTexture(1, 1, 1, 1)
	shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, FIT.shade))
	shade:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
	shade:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
	shade:SetWidth(FIT.shadeWidth)
	-- A dark hairline beside it, so it stands off the picture.
	local seam = strip:CreateTexture(nil, "BORDER")
	seam:SetColorTexture(0, 0, 0, FIT.seam)
	seam:SetPoint("TOPRIGHT", strip, "TOPLEFT", 0, 0)
	seam:SetPoint("BOTTOMRIGHT", strip, "BOTTOMLEFT", 0, 0)
	seam:SetWidth(1)
	strip:SetAlpha(0)
	fit.strips[button] = strip
	return strip
end

-- Which buttons hold a heal, and how big: when the bars, a size or the switch change.
local function FitButtons(m)
	local on = m.on and m.opt.fit and Shy.addons.Hots ~= nil
	local shown = 0
	for _, name in ipairs(FIT_BARS) do
		local bar = _G[name]
		for _, button in ipairs(bar and bar.actionButtons or {}) do
			local size = on and HealOn(button) or nil
			local strip = fit.strips[button]
			if size then
				strip = strip or NewStrip(button)
				strip.size = size
				strip:Show()
				shown = shown + 1
			elseif strip and strip.size then
				strip.size = nil
				strip:Hide()
			end
		end
	end
	fit.shown = shown
	MarkFit()
end

local function WatchFit(m)
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UPDATE_MOUSEOVER_UNIT",
		"PLAYER_TARGET_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, unit)
		-- (a change to someone else's health, while it's you or your target that is shown, changes nothing)
		local drawn = fit.unit
		if Plain(unit) and (drawn == "player" or drawn == "target") and unit ~= drawn then return end
		MarkFit()
	end)
	Shy:On("SHY_HEAL_SIZES", function() FitButtons(m) end)
end

local function PaintMainBar(m, kit)
	local bar = MainActionBar
	kit:Hide(bar.BorderArt)
	ns.HideDividers(kit, bar)
	if m.opt.endCaps then
		kit:Tint(bar.EndCaps.LeftEndCap.Texture, C.metal)
		kit:Tint(bar.EndCaps.RightEndCap.Texture, C.metal)
	end
	local page = bar.ActionBarPageNumber
	kit:Button(page.UpButton, C.lit, C.lit, C.hover)
	kit:Button(page.DownButton, C.lit, C.lit, C.hover)
	kit:Title(page.Text)
	kit:Text(page.Text, C.text)
end

ns.Module({
	id = "bars",
	title = "Action bars",
	desc = "Your action buttons get steel frames in your icon shape. Empty ones go dim but keep their key.",
	group = "screen",
	words = "buttons hotkeys keybinds gryphons stance pet",
	options = {
		{ key = "gloss", label = "Glossy buttons", default = true,
			desc = "A soft highlight runs across the top of each button." },
		{ key = "endCaps", label = "Steel gryphons", default = true,
			desc = "The gryphons at the ends of your main bar turn steel, with a hint of your color." },
		{ key = "hotkeys", label = "Key bindings", default = true,
			desc = "Each button shows its key. Without it, the red out-of-range mark goes too." },
		{ key = "macros", label = "Macro names", default = true,
			desc = "A macro's name shows along the bottom of its button." },
		{ key = "fit", label = "Heal fit", default = true, shown = function() return Shy.addons.Hots ~= nil end,
			desc = "A heal's button shows in mint how much would land on whoever you'd heal. Red is what would be wasted." },
	},

	Hook = function(m)
		bars = {
			MainActionBar, MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight,
			MultiBar5, MultiBar6, MultiBar7, StanceBar, PetActionBar, PossessActionBar,
		}
		-- A key bound or let go: the stance buttons' labels follow (the game's own buttons update theirs).
		local keys = CreateFrame("Frame")
		keys:RegisterEvent("UPDATE_BINDINGS")
		keys:SetScript("OnEvent", function()
			if not m.on then return end
			for _, button in ipairs(StanceBar.actionButtons) do PaintStanceKey(m, m.kit, button) end
		end)
		for _, bar in ipairs(bars) do
			-- Blizzard reapplies a button's art when Edit Mode switches the bar's art.
			for _, button in ipairs(bar.actionButtons) do
				hooksecurefunc(button, "UpdateButtonArt", function(self)
					if m.on then PaintButton(m, m.kit, self) end
				end)
			end
			hooksecurefunc(bar, "UpdateSystemSettingIconSize", function(self)
				if not m.on then return end
				for _, button in ipairs(self.actionButtons) do PaintName(m.kit, button) end
			end)
		end
		hooksecurefunc(MainActionBar, "UpdateDividers", function(self)
			if m.on then ns.HideDividers(m.kit, self) end
		end)
		WatchFit(m)
		-- Slot contents changed: refill once on the next frame, however many events arrive.
		local slots = CreateFrame("Frame")
		for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
			"UPDATE_SHAPESHIFT_FORM", "UPDATE_VEHICLE_ACTIONBAR", "UPDATE_OVERRIDE_ACTIONBAR", "PLAYER_ENTERING_WORLD" }) do
			slots:RegisterEvent(event)
		end
		local pending
		slots:SetScript("OnEvent", function()
			if pending or not m.on then return end
			pending = true
			C_Timer.After(0, function()
				pending = nil
				if not m.on then return end
				for _, bar in ipairs(bars) do
					for _, button in ipairs(bar.actionButtons) do PaintFill(m, m.kit, button) end
				end
				FitButtons(m)
			end)
		end)
	end,

	Paint = function(m, kit)
		for _, bar in ipairs(bars) do
			for _, button in ipairs(bar.actionButtons) do PaintButton(m, kit, button) end
		end
		PaintExtra(m, kit)
		PaintMainBar(m, kit)
		ns.Claim("barText", true)
		FitButtons(m)
	end,

	Clear = function(m)
		if not m.on then
			ns.Claim("barText", false)
			FitButtons(m)
		end
	end,
})
