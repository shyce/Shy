-- Buffs and debuffs: the player's rows (Blizzard_BuffFrame) and the ones under target and focus
-- (Blizzard_AuraContainer), each in a slot (kit:Tile). Debuff frames use Shy.Theme.HARM by type.
-- The debuff type is read from the border's atlas, which Blizzard sets in the button's Update, never from the aura.
-- Edit Mode fills rows with samples without Update, so rows are repainted after UpdateAuraButtons while it is open.
-- Target/focus: the container's methods can't be hooked and its auras can't be read. New buttons are found
-- after AnchorAuraContainer; Blizzard colors the dispel border itself (AuraUtil.SetAuraBorderColor).
-- Nothing is drawn on the rows themselves: they measure their buttons to lay out.

local ADDON, ns = ...
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = Skin.colors

local MARK = 13            -- dispel type icon size on a 30 px aura
local HARM_LIGHT = 0.9     -- alpha of the glow inside a debuff's frame
local FOLD = { 5, 0, 0, 0 }   -- plate inset on the 15 x 30 collapse button: { left, top, right, bottom }

local hooked = {}       -- buttons with an Update hook
local tiles = {}        -- player aura button -> its slot
local marks = {}        -- ... -> its dispel type icon
local lights = {}       -- ... -> its debuff glow
local borders           -- border atlas -> { kind =, icon = }
local arrow             -- our keyed plate on the collapse button (kit:Key's set: :Turn turns its glyph)
local dressed = {}      -- target and focus buttons skinned since the last restore
local refused = setmetatable({}, { __mode = "k" })   -- ... and those that errored
local told = false

-- The aura container's refusals can't be predicted from its source: catch them, report once.
local function Try(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not told then
		told = true
		geterrorhandler()(err)
	end
	return ok
end

-- The player's rows

local function Buttons()
	local list = {}
	local function Add(frames)
		for _, frame in ipairs(frames) do
			-- Private aura anchors are drawn by the game.
			if not frame.isAuraAnchor then list[#list + 1] = frame end
		end
	end
	local folded = BuffFrame.ConsolidatedBuffs
	Add(BuffFrame.auraFrames)
	Add(DebuffFrame.auraFrames)
	Add(ExternalDefensivesFrame.auraFrames)
	Add({ folded, DeadlyDebuffFrame.Debuff })
	Add(folded.Tooltip.Auras.auraFrames)
	return list
end

-- Durations carry a localized letter ("5 m"), so they need a font family.
local function TimeFont(fontString)
	local _, size = fontString:GetFont()
	return UI.NameFont(math.floor(size + 0.5), "OUTLINE")
end

local function Reading(border)
	local atlas = border:GetAtlas()
	if issecretvalue(atlas) or type(atlas) ~= "string" then return nil end
	return borders[atlas:lower()]
end

local function ShowMark(kit, button, atlas)
	local mark = marks[button]
	if not atlas then
		if mark then mark:Hide() end
		return
	end
	mark = ns.Own(kit, button, "dispel", function(owner)
		local t = owner:CreateTexture(nil, "OVERLAY", nil, 2)
		t:SetSize(MARK, MARK)
		t:SetPoint("CENTER", owner.Icon, "BOTTOMLEFT", 3, 3)
		return t
	end)
	marks[button] = mark
	mark:SetAtlas(atlas)
end

local function ShowLight(kit, button, r, g, b)
	local light = lights[button]
	if not r then
		if light then light:Hide() end
		return
	end
	light = ns.Own(kit, button, "harm", function(owner)
		local t = owner:CreateTexture(nil, "ARTWORK", nil, 6)
		Shy.Slot.Follow(t, "glow", owner.Icon)
		t:SetAlpha(HARM_LIGHT)
		return t
	end)
	lights[button] = light
	light:SetVertexColor(r, g, b)
end

local function ShowKind(kit, button)
	local tile = tiles[button]
	if not tile then return end
	local kind = button.auraType
	local known, mark, harm = true, nil, false
	local r, g, b   -- nil for a buff: plain steel
	if kind == "TempEnchant" then
		r, g, b = C.on[1], C.on[2], C.on[3]
	elseif kind == "Debuff" or kind == "DeadlyDebuff" then
		local says = Reading(button.DebuffBorder)
		if says then
			r, g, b = Theme.Harm(says.kind)
			mark, harm = says.icon, true
		else
			known = false
		end
	end
	kit:Fade(button.DebuffBorder, known and 0 or 1)
	tile:Bare(not known)
	tile:Mark(r, g, b)
	if harm then ShowLight(kit, button, r, g, b) else ShowLight(kit, button) end
	ShowMark(kit, button, mark)
end

local function PaintButton(m, kit, button)
	if not hooked[button] then
		hooked[button] = true
		hooksecurefunc(button, "Update", function(self)
			if m.on then ShowKind(m.kit, self) end
		end)
	end
	-- The button is taller than its icon: the duration is under it.
	tiles[button] = kit:Tile(button, { to = button.Icon, icon = button.Icon })
	kit:Hide(button.TempEnchantBorder)
	ns.Number(kit, button.Count)
	-- In Traditional Chinese Blizzard resets the duration font every frame (BuffFrame.lua OnUpdate): leave it.
	if not SMALLER_AURA_DURATION_FONT_MIN_THRESHOLD then
		kit:FontObject(button.Duration, TimeFont(button.Duration))
	end
	kit:Text(button.Duration, UI.colors.text)
	ShowKind(kit, button)
end

-- Blizzard's arrow points right at rotation 0; our caret points down.
local function TurnArrow(button)
	local turned = button:GetNormalTexture():GetRotation()
	if arrow and not issecretvalue(turned) then arrow:Turn(turned + math.pi / 2) end
end

local function PaintArrow(kit, button)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetHighlightTexture())
	arrow = kit:Key(button, { inset = FOLD, icon = Skin.GLYPH.caret, iconSize = 9 })
	TurnArrow(button)
end

-- Under the target and focus

local function Allowed(button)
	if issecretvalue(button) or dressed[button] or refused[button] then return false end
	local forbidden = button:IsForbidden()
	if issecretvalue(forbidden) or forbidden then return false end
	return button.GetCount ~= nil   -- only aura buttons
end

-- 17 or 21 px buttons. A debuff's dispel border, which Blizzard colors, becomes the slot's colored
-- piece; where that piece is the frame itself, the slot's steel frame is hidden.
local function DressUnitAura(kit, button)
	ns.Number(kit, button:GetCount())
	local tile = kit:Tile(button, { x = -1, y = -1, well = false, hover = false, icon = button:GetIcon() })
	if button.GetDispelBorder then
		kit:Piece(button:GetDispelBorder(), "mark", nil, { size = tile.level })
		tile:Bare(not Shy.Slot.MarkApart())
	end
	kit:Swipe(button:GetCooldown())
end

local function DressUnitAuras(kit, frame)
	for _, button in ipairs({ frame:GetAuraContainer():GetChildren() }) do
		if Allowed(button) then
			if Try(DressUnitAura, kit, button) then
				dressed[button] = true
			else
				refused[button] = true
			end
		end
	end
end

local function PaintUnitAuras(kit, frame)
	Try(DressUnitAuras, kit, frame)
end

ns.Module({
	id = "auras",
	title = "Buffs and debuffs",
	desc = "Restyles your buffs and debuffs, and the ones under your target and focus, as slots in the icon shape set in /shy. A debuff's frame is red, or the color of its type: poison, curse, magic or disease.",

	Hook = function(m)
		borders = {}
		for kind, info in pairs(AuraUtil.GetDebuffDisplayInfoTable()) do
			borders[info.basicAtlas:lower()] = { kind = kind }
			if info.dispelAtlas then
				borders[info.dispelAtlas:lower()] = { kind = kind, icon = info.dispelIconAtlas }
			end
		end
		-- Edit Mode's samples skip Update and reset the duration font.
		for _, frame in ipairs({ BuffFrame, DebuffFrame, ExternalDefensivesFrame }) do
			hooksecurefunc(frame, "UpdateAuraButtons", function(self)
				if not (m.on and self.hasInitializedForEditMode) then return end
				for _, button in ipairs(self.auraFrames) do
					if not button.isAuraAnchor then PaintButton(m, m.kit, button) end
				end
			end)
		end
		hooksecurefunc(BuffFrame.CollapseAndExpandButton, "UpdateOrientation", function(self)
			if m.on then TurnArrow(self) end
		end)
		for _, frame in ipairs({ TargetFrame, FocusFrame }) do
			hooksecurefunc(frame, "AnchorAuraContainer", function(self)
				if m.on then PaintUnitAuras(m.kit, self) end
			end)
		end
	end,

	Paint = function(m, kit)
		for _, button in ipairs(Buttons()) do PaintButton(m, kit, button) end
		PaintArrow(kit, BuffFrame.CollapseAndExpandButton)
		PaintUnitAuras(kit, TargetFrame)
		PaintUnitAuras(kit, FocusFrame)
	end,

	-- After a restore the target and focus buttons need skinning again.
	Clear = function()
		wipe(dressed)
	end,
})
