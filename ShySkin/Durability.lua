-- The armor stand: the figure that says your gear is wearing out, as a piece of its own that comes up
-- only while something is damaged and can be placed like any other. The game's own (DurabilityFrame,
-- which the game stands under the minimap) is stood down while this one is on, through its roleset, so
-- nothing of the game's is moved or hidden by hand.
--
-- The figure is the game's own art, piece by piece as the game lays it out: a worn piece gold, a broken
-- one soft red, the rest steel; the weapons only while one of them is worn, as the game has it. Under it
-- the worst piece's durability, in that piece's color. Its hover names each worn piece.
--
--   T:StandPiece()   -- the piece for a preview of the screen: { id, width, height, scale, sample, passing },
--                    -- nil while the game's own is in use
--   ns.Durability.Parts()    -- box, plate

local ADDON, ns = ...
local T = ns.T
local UI, Theme, HUD = Shy.UI, Shy.Theme, Shy.HUD
local C = UI.colors

local D = {}
ns.Durability = D

local ART = "Interface\\Durability\\UI-Durability-Icons"
local BLOCKED = "alwaysBlocked"
local FIGURE = 0.75                 -- the figure's scale: the game's is 58 to 92 across and 76 tall
local TALL = 76
local PAD = 7
local SAID = 11                     -- the percent's line
local BOX = 84                      -- the box: the widest figure and its plate
local FADE, GLIDE = 0.25, 12        -- seconds to come up or go; how quickly the plate takes a new width
local OK_ALPHA = 0.45               -- a piece in good repair

-- GetInventoryAlertStatus's order, the inventory slot it is about, and the game's art and anchors for it
-- (Blizzard_DurabilityFrame/DurabilityFrame.xml). Weapons only show while worn (`apart`).
local PIECES = {
	{ name = "Head", slot = INVSLOT_HEAD, size = { 18, 22 }, coords = { 0, 0.140625, 0, 0.171875 } },
	{ name = "Shoulders", slot = INVSLOT_SHOULDER, size = { 48, 22 }, coords = { 0.140625, 0.515625, 0, 0.171875 }, at = { "TOP", "Head", "BOTTOM", 0, 16 } },
	{ name = "Chest", slot = INVSLOT_CHEST, size = { 20, 22 }, coords = { 0.515625, 0.6640625, 0, 0.171875 }, at = { "TOP", "Shoulders", "TOP", 0, -7 } },
	{ name = "Waist", slot = INVSLOT_WAIST, size = { 16, 5 }, coords = { 0.328125, 0.46875, 0.171875, 0.203125 }, at = { "TOP", "Chest", "BOTTOM", 0, 6 } },
	{ name = "Legs", slot = INVSLOT_LEGS, size = { 29, 20 }, coords = { 0.46875, 0.6875, 0.171875, 0.3203125 }, at = { "TOP", "Waist", "BOTTOM", 0, 2 } },
	{ name = "Feet", slot = INVSLOT_FEET, size = { 41, 32 }, coords = { 0.6875, 1, 0.171875, 0.4140625 }, at = { "TOP", "Legs", "BOTTOM", 0, 8 } },
	{ name = "Wrists", slot = INVSLOT_WRIST, size = { 44, 22 }, coords = { 0.6640625, 1, 0, 0.171875 }, at = { "TOP", "Shoulders", "BOTTOM", 0, 7 } },
	{ name = "Hands", slot = INVSLOT_HAND, size = { 42, 18 }, coords = { 0, 0.328125, 0.171875, 0.3046875 }, at = { "TOP", "Wrists", "BOTTOM", 0, 15 } },
	{ name = "Weapon", slot = INVSLOT_MAINHAND, size = { 20, 45 }, coords = { 0, 0.140625, 0.3203125, 0.6640625 }, at = { "RIGHT", "Wrists", "LEFT", 0, -6 }, apart = "left" },
	{ name = "Shield", slot = INVSLOT_OFFHAND, size = { 25, 31 }, coords = { 0.1875, 0.375, 0.3203125, 0.5546875 }, at = { "LEFT", "Wrists", "RIGHT", 0, 10 }, apart = "right" },
	{ name = "Ranged", slot = INVSLOT_RANGED, size = { 28, 38 }, coords = { 0.1875, 0.3984375, 0.5546875, 0.84375 }, at = { "TOP", "Shield", "BOTTOM", 0, 5 }, apart = "right" },
}
-- An off-hand weapon is drawn as a second blade where the shield would be.
local OFF_WEAPON = { size = { 20, 45 }, coords = { 0, 0.140625, 0.3203125, 0.6640625 }, at = { "LEFT", "Wrists", "RIGHT", 0, -6 } }
local SAMPLE = { 1, 0, 2, 0, 0, 1, 0, 0, 1, 0, 0 }   -- what layout mode and the preview show

local box, stand
local states = {}             -- index -> 0, 1 worn, 2 broken
local shown, alpha = false, 0
local own                     -- the game's frame's rolesets before it was stood down (false for none)
local refused
local failed

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not failed then
		failed = tostring(err)
		T:Print("armor stand: " .. failed)
	end
end

local function Disabled()
	return C_GameRules.IsGameRuleActive(Enum.GameRule.RepairArmorDisabled) == true
end

-- The figure

local function Color(state)
	if state == 2 then return C.bad end
	if state == 1 then return C.alert end
	return Theme.skin.metal
end

-- A plate with the figure on it, on `parent`. Returns it; :Set(states, percent) dresses it and gives its width.
local function Build(parent)
	local plate = CreateFrame("Frame", nil, parent)
	UI.Panel(plate, { hud = true })
	local figure = CreateFrame("Frame", nil, plate)
	figure:SetScale(FIGURE)
	figure:SetSize(58, TALL)
	figure:SetPoint("TOP", plate, "TOP", 0, -PAD / FIGURE)
	local art = {}
	for _, p in ipairs(PIECES) do
		local t = figure:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART)
		t:SetTexCoord(unpack(p.coords))
		t:SetSize(p.size[1], p.size[2])
		art[p.name] = t
	end
	local off = figure:CreateTexture(nil, "ARTWORK")
	off:SetTexture(ART)
	off:SetTexCoord(unpack(OFF_WEAPON.coords))
	off:SetSize(OFF_WEAPON.size[1], OFF_WEAPON.size[2])
	for _, p in ipairs(PIECES) do
		if p.at then art[p.name]:SetPoint(p.at[1], art[p.at[2]], p.at[3], p.at[4], p.at[5]) end
	end
	off:SetPoint(OFF_WEAPON.at[1], art.Wrists, OFF_WEAPON.at[3], OFF_WEAPON.at[4], OFF_WEAPON.at[5])
	local said = UI.Words(plate, UI.NameFont(SAID), nil, { justify = "CENTER" })
	said:SetPoint("BOTTOM", plate, "BOTTOM", 0, PAD - 1)
	plate.art, plate.off, plate.said = art, off, said

	-- states: by PIECES' index; offhandWeapon: the off hand holds a blade. Returns the plate's width.
	function plate:Set(list, percent, worst, offhandWeapon)
		local left, right = false, false
		for i, p in ipairs(PIECES) do
			local t = art[p.name]
			local state = list[i] or 0
			if p.name == "Shield" and offhandWeapon then
				t:Hide()
				t = off
			elseif p.name == "Shield" then
				off:Hide()
			end
			UI.Tint(t, Color(state), state > 0 and 1 or OK_ALPHA)
			if p.apart then
				t:SetShown(state > 0)
				if state > 0 then
					if p.apart == "left" then left = true else right = true end
				end
			else
				t:Show()
			end
		end
		-- The head stands further in while a shield or a bow hangs at the right (the game's 20 and 40).
		local width = 58 + (right and 20 or 0) + (left and 14 or 0)
		art.Head:ClearAllPoints()
		art.Head:SetPoint("TOPRIGHT", figure, "TOPRIGHT", right and -40 or -20, 0)
		figure:SetWidth(width)
		figure:ClearAllPoints()
		figure:SetPoint("TOPRIGHT", plate, "TOPRIGHT", -PAD / FIGURE, -PAD / FIGURE)
		said:SetText(percent and (percent .. "%") or "")
		UI.Ink(said, Color(worst or 1))
		return 2 * math.ceil((width * FIGURE + 2 * PAD) / 2)
	end
	return plate
end

local function Height()
	return 2 * math.ceil((PAD + TALL * FIGURE + 1 + SAID + PAD) / 2)
end

-- What the game says of your gear: states by PIECES' index, the worst piece's percent and state, and
-- whether anything is worn.
local function Read()
	local any, worst, worstState = false, nil, nil
	for i, p in ipairs(PIECES) do
		local state = GetInventoryAlertStatus(i) or 0
		states[i] = state
		if state > 0 then
			any = true
			local now, whole = GetInventoryItemDurability(p.slot)
			if not issecretvalue(now) and not issecretvalue(whole) and now and whole and whole > 0 then
				local percent = math.floor(now / whole * 100)
				if not worst or percent < worst then worst, worstState = percent, state end
			end
		end
	end
	return any, worst, worstState
end

-- The game's own frame stood down, or handed back

local function StandDown()
	if own ~= nil or refused then return end
	local tags = DurabilityFrame:GetRolesetNames()
	-- A frame with no tags returns "roleless".
	own = (#tags > 0 and tags[1] ~= "roleless") and table.concat(tags, ",") or false
	DurabilityFrame:SetRolesets(BLOCKED)
	-- Only a shown frame can confirm the engine filters it.
	if DurabilityFrame:IsShown() and not DurabilityFrame:IsRolesetFiltered() then
		DurabilityFrame:SetRolesets(own or nil)
		own, refused = nil, true
		T:Print("couldn't hide the game's armor stand, so you'll see both.")
	end
end

local function GiveBack()
	if own == nil then return end
	DurabilityFrame:SetRolesets(own or nil)
	own = nil
end

-- The piece on screen

local function Sampling()
	return HUD.IsUnlocked() and D.on == true
end

local function Refresh()
	if not stand then return end
	local list, any, worst, worstState = states, false, nil, nil
	if Sampling() then
		list, any, worst, worstState = SAMPLE, true, 62, 1
	elseif not Disabled() then
		any, worst, worstState = Read()
	end
	stand.width = stand:Set(list, worst, worstState, C_PaperDollInfo.OffhandHasWeapon())
	if not stand.at then stand.at = stand.width end
	shown = D.on == true and any
	stand:EnableMouse(shown)
	if shown then stand:Show() end
	box:SetScript("OnUpdate", D.Step)
end

function D.Step(_, elapsed)
	local want = shown and 1 or 0
	alpha = want > alpha and math.min(want, alpha + elapsed / FADE) or math.max(want, alpha - elapsed / FADE)
	local width = stand.at + (stand.width - stand.at) * math.min(1, elapsed * GLIDE)
	if math.abs(stand.width - width) < 0.05 then width = stand.width end
	stand.at = width
	stand:SetAlpha(alpha)
	stand:SetWidth(width)
	if alpha == want and width == stand.width then
		box:SetScript("OnUpdate", nil)
		if alpha == 0 then stand:Hide() end
	end
end

local function Tip(owner)
	local lines = UI.Lines()
	lines:AddLine(REPAIR_ARMOR_TOOLTIP_TITLE)
	for i, p in ipairs(PIECES) do
		local state = states[i] or 0
		if state > 0 then
			local link = GetInventoryItemLink("player", p.slot)
			local name = not issecretvalue(link) and link and link:match("%[(.-)%]") or p.name
			local now, whole = GetInventoryItemDurability(p.slot)
			local readable = not issecretvalue(now) and not issecretvalue(whole) and now and whole and whole > 0
			local right = readable and (math.floor(now / whole * 100) .. "%") or ""
			local c = Color(state)
			lines:AddDoubleLine(name, right, 1, 1, 1, c[1], c[2], c[3])
		end
	end
	UI.Tip(owner, lines)
end

local function Make()
	if box then return end
	box = HUD.Create({
		id = "shyskin.durability", title = "Armor stand",
		width = BOX, height = Height(),
		-- Left of a stock minimap, at its foot: where the game's own would be seen first.
		point = { "TOPRIGHT", "TOPRIGHT", -232, -232 },
		shown = function() return D.on == true end,
		away = function() return D.on ~= true end,
	})
	box:EnableMouse(false)
	stand = Build(box)
	stand:SetPoint("TOPRIGHT")
	stand:SetHeight(Height())
	stand:SetAlpha(0)
	stand:Hide()
	stand:SetScript("OnEnter", function(self) if not Sampling() then Safe(Tip, self) end end)
	stand:SetScript("OnLeave", function(self) UI.TipHide(self) end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "UPDATE_INVENTORY_ALERTS", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function() if D.on then Safe(Refresh) end end)
	Shy:On("SHY_HUD_LAYOUT", function() Safe(Refresh) end)
end

-- For a preview of the screen (ShyDock's): the stand as a picture at the box's size.
function D.Sample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(BOX, Height())
	local plate = Build(f)
	plate:SetPoint("TOPRIGHT")
	plate:SetHeight(Height())
	plate:SetWidth(plate:Set(SAMPLE, 62, 1, false))
	return f
end

function T:StandPiece()
	if not (D.on and box) then return nil end
	local scale = box:GetScale()
	return { id = box.id, width = BOX * scale, height = Height() * scale, scale = scale, sample = D.Sample, passing = true }
end

-- The box and the plate on it.
function D.Parts() return box, stand end

ns.Module({
	id = "durability",
	title = "Armor stand",
	desc = "The damaged gear figure stands on a plate in your color, with your worst piece's durability under it.",
	group = "screen",
	words = "durability broken repair",

	Ready = function() return DurabilityFrame ~= nil end,

	Hook = function() Make() end,

	Paint = function()
		local was = D.on
		D.on = true
		ns.AfterCombat("durability", function() if D.on then StandDown() end end)
		if not was then
			HUD.Update(box)
			Safe(Refresh)
		end
	end,

	Clear = function(m)
		if m.on then return end
		D.on = false
		ns.AfterCombat("durability", function() if not D.on then GiveBack() end end)
		shown = false
		stand:EnableMouse(false)
		alpha = 0
		stand:SetAlpha(0)
		stand:Hide()
		box:SetScript("OnUpdate", nil)
		HUD.Update(box)
	end,
})
