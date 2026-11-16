-- Bag windows: the combined bag and the separate ones on panels, each item button a slot.
-- An empty slot is the item button's icon showing slot art, so the icon is faded (SetItemButtonTexture).
-- Slots are pooled and the pool grows, so painting follows ContainerFrame_GenerateFrame.
-- Blizzard re-anchors the search box and sort button in UpdateSearchBox on every bag update; they are
-- placed again after it, and Blizzard's anchors are kept to restore.
-- GamepadBagBar is hidden outside gamepad mode: its OnLoad fails to hide its backpack button, which
-- then covers the sort button and takes its clicks.

local ADDON, ns = ...
local UI = Shy.UI
local C = Shy.Skin.colors

local TITLE = UI.HEAD.window.line - 2   -- title strip height, inside the panel's edge (the core's window header)
local CLOSE = { 5, 6, 5, 3 }   -- 18×18 plate in the 28×28 button (ns.CLOSE in Widgets.lua)

-- From ContainerFrame.lua: slot size, slot gap, right inset, top of the slot grid, widest coin text.
local SLOT, GAP, INSET, GRID, COINS = 37, 5, 8, 75, 168
local HEAD = TITLE + 4   -- bottom of the title strip and its line
local ROW = 22           -- height of the search plate and the sort button
local ROW_Y = math.floor(HEAD + (GRID - HEAD - ROW) / 2)
local SEARCH_PAD = { 4, 2 }      -- search plate outset past the box
local BARS = { 14, 10, 6 }       -- widths of the sort glyph's three bars
local LOW = 3                    -- free slots at which Blizzard's "bags nearly full" tutorial fires

local tiles = {}    -- item button -> its slot
local hooked = {}   -- item buttons with hooks
local stood = {}    -- search box, sort button -> Blizzard's last anchors { points, w, h }
local ours = {}     -- search box, sort button -> currently at our anchors

local function Bags()
	local list = { ContainerFrameCombinedBags }
	for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do list[#list + 1] = frame end
	return list
end

local function OnGamepad()
	return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

local function ShowSlot(kit, button, empty)
	kit:Fade(button.icon, empty and 0 or 1)
	tiles[button]:Empty(empty)
end

-- The slot shows the quality; Blizzard's square IconBorder is hidden.
local function ShowQuality(kit, button, quality)
	kit:Hide(button.IconBorder)
	tiles[button]:Quality(quality)
end

local function PaintSlots(m, kit, frame)
	for _, button in ipairs(frame.Items) do
		-- Pooled buttons keep their skin; only new ones need it.
		if not kit:Has(button.NormalTexture) then
			kit:Hide(button.NormalTexture)
			kit:Hide(button.HighlightTexture)
			tiles[button] = kit:Tile(button, { icon = button.icon })
			ns.Lit(kit, button.PushedTexture, button, C.lit)
			kit:Swipe(button.Cooldown)
			ns.Number(kit, button.Count)
			local bag = button:GetBagID()
			local info = bag ~= nil and C_Container.GetContainerItemInfo(bag, button:GetID()) or nil
			ShowSlot(kit, button, bag ~= nil and info == nil)
			ShowQuality(kit, button, info and info.quality)
			if not hooked[button] then
				hooked[button] = true
				hooksecurefunc(button, "SetItemButtonTexture", function(self, texture)
					if m.on then ShowSlot(m.kit, self, texture == nil) end
				end)
				hooksecurefunc(button, "SetItemButtonQuality", function(self, quality)
					if m.on then ShowQuality(m.kit, self, quality) end
				end)
			end
		end
	end
end

-- The search box and the sort button

-- Records Blizzard's anchors. Blizzard sizes the search box every time and the sort button never.
local function Keep(frame, sized)
	local s = stood[frame]
	if not s then
		s = {}
		stood[frame] = s
	end
	if sized or not s.w then s.w, s.h = frame:GetSize() end
	s.points = {}
	for i = 1, frame:GetNumPoints() do s.points[i] = { frame:GetPoint(i) } end
	ours[frame] = false
end

-- A single TOPRIGHT point: Blizzard sets the sort button's TOPRIGHT without ClearAllPoints.
local function Stand(frame, width, height, x, y, bag)
	frame:ClearAllPoints()
	frame:SetPoint("TOPRIGHT", bag, "TOPRIGHT", x, y)
	frame:SetSize(width, height)
	ours[frame] = true
end

local function PutBack(frame)
	local s = stood[frame]
	if not (s and ours[frame]) then return end
	frame:ClearAllPoints()
	for _, point in ipairs(s.points) do frame:SetPoint(unpack(point)) end
	frame:SetSize(s.w, s.h)
	ours[frame] = false
end

-- placed: Blizzard has just anchored them, so their current anchors are its own.
local function Row(frame, placed)
	local search, sort = BagItemSearchBox, BagItemAutoSortButton
	if search:GetParent() ~= frame then return end
	if OnGamepad() then
		if placed then
			ours[search], ours[sort] = false, false
		else
			PutBack(search)
			PutBack(sort)
		end
		return
	end
	if placed or not ours[search] then Keep(search, true) end
	if placed or not ours[sort] then Keep(sort) end
	if #stood[search].points == 0 then return end   -- no bag has been opened yet
	local wide = frame:GetColumns() * (SLOT + GAP) - GAP
	Stand(sort, SLOT, ROW, -INSET, -ROW_Y, frame)
	Stand(search, wide - SLOT - GAP - 2 * SEARCH_PAD[1], ROW - 2 * SEARCH_PAD[2],
		-(INSET + SLOT + GAP + SEARCH_PAD[1]), -(ROW_Y + SEARCH_PAD[2]), frame)
end

local function PaintTools(kit)
	local search = BagItemSearchBox
	kit:Hide(search.Left)
	kit:Hide(search.Middle)
	kit:Hide(search.Right)
	kit:Plate(search, { x = -SEARCH_PAD[1], y = -SEARCH_PAD[2], fill = UI.colors.bg, hover = true })

	local sort = BagItemAutoSortButton
	kit:Hide(sort:GetNormalTexture())
	kit:Hide(sort:GetHighlightTexture())
	ns.Lit(kit, sort:GetPushedTexture(), sort, C.lit)
	kit:Key(sort)
	for i, width in ipairs(BARS) do
		local bar = ns.Own(kit, sort, "bar" .. i, function(owner)
			local t = owner:CreateTexture(nil, "ARTWORK")
			t:SetSize(width, 2)
			t:SetPoint("TOPLEFT", owner, "CENTER", -BARS[1] / 2, 9 - i * 4)
			return t
		end)
		UI.Paint(bar, C.glyph)
	end
end

-- The coin box

local function CountText(owner)
	return UI.Words(owner, 11)
end

-- Free slots at the left of the coin box: gold when low, red when full.
local counted = {}   -- bag id -> asked already, for one count
local function Count(kit, frame)
	local border = frame.MoneyFrame.Border
	local free = ns.Own(kit, border, "free", function(owner)
		local text = CountText(owner)
		text:SetPoint("LEFT", owner, "LEFT", 8, 0)
		return text
	end)
	local of = ns.Own(kit, border, "of", function(owner)
		local text = CountText(owner)
		text:SetPoint("LEFT", free, "RIGHT", 0, 0)
		return text
	end)
	-- The free room asked once a bag, not once a slot (every loot asks again while the bags are open).
	local room, slots = 0, 0
	wipe(counted)
	for _, button in ipairs(frame.Items) do
		local bag = button:GetBagID()
		if bag then
			slots = slots + 1
			if not counted[bag] then
				counted[bag] = true
				room = room + (C_Container.GetContainerNumFreeSlots(bag) or 0)
			end
		end
	end
	if slots == 0 then
		free:SetText("")
	elseif room == 0 then
		free:SetText("Full")
	else
		free:SetFormattedText("%d free", room)
	end
	UI.Ink(free, (room == 0 and UI.colors.bad) or (room <= LOW and UI.colors.alert) or UI.colors.text)
	-- The total only fits where the coins leave room, not in the narrow backpack.
	local wide = frame:GetColumns() * (SLOT + GAP) - GAP
	of:SetText((room > 0 and wide - COINS > 80) and (" of " .. slots) or "")
	UI.Ink(of, UI.colors.dim)
end

local function PaintBag(m, kit, frame)
	kit:Hide(frame.NineSlice)
	kit:Hide(frame.Bg)
	kit:Hide(frame.ItemSlotBackground)   -- the combined bag's slot art
	local portrait = frame.PortraitContainer
	kit:Unmask(portrait.portrait, portrait.CircleMask)
	kit:Hide(frame.PortraitButton.Highlight)   -- a round glow
	local set = kit:Head(frame, { text = frame.TitleContainer.TitleText, icon = portrait.portrait })
	set.owner = frame
	local pack = { closeTrim = CLOSE[3] or 0, closePlate = CLOSE }
	if frame.CloseButton then
		ns.Close(kit, frame.CloseButton, CLOSE)
		pack.close = frame.CloseButton
	end
	kit:HeadRail(set, pack)
	local money = frame.MoneyFrame   -- the backpack and the combined bag
	if money then
		kit:HideRegions(money.Border)
		kit:Plate(money.Border, { fill = UI.colors.bg })
		Count(kit, frame)
		Row(frame)
	end
	PaintSlots(m, kit, frame)
end

local stoodDown = false   -- we hid the gamepad bag bar

-- Only shows the bar again if we hid it. It can be protected, so this waits for combat to end.
local function SettleGamepadBar(m)
	local bar = GamepadBagBar
	local function Settle()
		local away = m.on and not OnGamepad()
		if away == stoodDown then return end
		stoodDown = away
		bar:SetShown(not away)
	end
	if bar:IsProtected() then ns.AfterCombat("bags:gamepadBar", Settle) else Settle() end
end

ns.Module({
	id = "bags",
	title = "Bags",
	desc = "Restyles the default bags as dark panels with quality-colored slots. Search and Clean Up share one row, and the gold box shows your free slots.",

	Hook = function(m)
		hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
			if m.on then PaintBag(m, m.kit, frame) end
		end)
		for _, frame in ipairs(Bags()) do
			if frame.MoneyFrame then
				hooksecurefunc(frame, "UpdateSearchBox", function(self)
					if m.on then Row(self, true) end
				end)
			end
		end
		local events = CreateFrame("Frame")
		events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")   -- mouse <-> gamepad
		events:RegisterEvent("BAG_UPDATE_DELAYED")
		events:SetScript("OnEvent", function(_, event)
			if event == "INPUT_DEVICE_INTERFACE_TRANSITION" then
				m:Refresh()
			elseif m.on then
				for _, frame in ipairs(Bags()) do
					if frame.MoneyFrame and frame:IsShown() then Count(m.kit, frame) end
				end
			end
		end)
	end,

	Clear = function(m)
		SettleGamepadBar(m)
		if not m.on then
			PutBack(BagItemSearchBox)
			PutBack(BagItemAutoSortButton)
		end
	end,

	Paint = function(m, kit)
		SettleGamepadBar(m)
		PaintTools(kit)
		for _, frame in ipairs(Bags()) do PaintBag(m, kit, frame) end
	end,
})
