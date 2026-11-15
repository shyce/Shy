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
	desc = "Restyles every action button as a steel-framed slot in the icon shape set in /shy. Empty buttons are dim, with their key still showing, and the main bar's border is removed.",
	options = {
		{ key = "gloss", label = "Glossy buttons", default = true,
			desc = "Adds a soft highlight across the top of every button." },
		{ key = "endCaps", label = "Tint the gryphons", default = true,
			desc = "Turns the gryphons at the ends of the main bar steel, with a hint of your accent color." },
		{ key = "hotkeys", label = "Show key bindings", default = true,
			desc = "Shows the key on each button, your stances and auras too. Hiding it also hides the red out-of-range key." },
		{ key = "macros", label = "Show macro names", default = true,
			desc = "Shows the name along the bottom of a macro's button." },
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
			end)
		end)
	end,

	Paint = function(m, kit)
		for _, bar in ipairs(bars) do
			for _, button in ipairs(bar.actionButtons) do PaintButton(m, kit, button) end
		end
		PaintExtra(m, kit)
		PaintMainBar(m, kit)
	end,
})
