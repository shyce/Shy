-- One slot: Shy.Slot art plus the marks from Marks.lua.
-- A live slot is a ContainerFrameItemButtonTemplate, so every click is Blizzard's secure handler. The bag it
-- reads is SetBagID's attribute, and its place is its ID. Both are set once, when the button is made for its
-- slot (Grid.lua seats a button per slot for good), and only out of a fight: setting either in one taints the
-- click, and the slot then refuses to pick up or use anything. A holder per bag is only where
-- the button is drawn. Blizzard's painters (Initialize, SetItemButtonCount, SetItemButtonQuality) write other
-- fields the click reads, so they are never called: icon, count, cooldown and marks are set on the regions
-- directly. A stored slot (another character, or a bank away from a banker) is a plain frame, drawn flat.
--   Tile.Paint(tile)                             a live slot from the game; true when filled
--   Tile.Show(tile, slotString, guid, source)    a stored slot
--   Tile.Grid(tile)                              the grid it was made for; nil for a button that is not ours

local ADDON, ns = ...
local Skin, Slot = Shy.Skin, Shy.Slot
local C = Skin.colors
local Store, Marks = ns.Store, ns.Marks

local Tile = {}
ns.Tile = Tile

Tile.SIZE = Slot.SIZE
Tile.GAP = Slot.GAP

local tiles = setmetatable({}, { __mode = "k" })     -- tile -> its state
local holders = setmetatable({}, { __mode = "k" })   -- grid -> { [bag] = its holder }

-- The bank's slots are gold: a polished bezel of it over a deep gold well, whatever the look (Tile.Gild).
local GOLD = { frame = { 1.0, 0.80, 0.38 }, well = { 0.20, 0.14, 0.05 }, finish = "band" }
Tile.GOLD = GOLD

-- The slot as it is worn: its wells as clear as the Background setting makes the window; a stored slot a print of
-- the hardware, but a gold one is the hardware itself. A special bag's slot has its kind's well (Tile.Well).
local function Dress(s)
	s.slot:Set({ icon = s.icon, flat = not s.live and not s.gold, hover = s.live, glazed = true,
		style = s.gold and GOLD.finish or nil, color = s.steel or (s.gold and GOLD.frame or nil),
		fill = s.well or (s.gold and GOLD.well or nil) })
end

local function Make(tile, grid, live, icon, count)
	local s = { grid = grid, live = live, icon = icon, count = count, marks = {}, gold = grid.gold == true }
	tiles[tile] = s
	s.slot = Slot.New(tile, { icon = icon, flat = not live and not s.gold, hover = live, glazed = true })
	Dress(s)
	s.slot:Count(count)
	return s
end

-- A frame over the grid for one bag, so its slots share a parent. The click does not read this frame's ID.
local function Holder(grid, bag)
	local set = holders[grid]
	if not set then
		set = {}
		holders[grid] = set
	end
	local holder = set[bag]
	if not holder then
		holder = CreateFrame("Frame", nil, grid)
		holder:SetAllPoints(grid)
		holder:SetID(bag)
		set[bag] = holder
	end
	return holder
end

function Tile.Live(parent)
	local tile = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
	tile:GetNormalTexture():SetAlpha(0)
	tile:GetHighlightTexture():SetAlpha(0)
	-- The template shows this glow by default and only UpdateNewItem, which is never called here, hides it.
	tile.BattlepayItemTexture:Hide()
	-- Shown again whenever the button is shown, from the game's item-context check. A mismatch paints a
	-- black cover over the whole slot, and that check runs as a fight starts. Nothing here is choosing
	-- an item for a trade, so the slot never takes part.
	local cover = rawget(tile, "ItemContextOverlay")
	if cover then cover:Hide() end
	tile.GetItemContextMatchResult = function()
		local result = ItemButtonUtil and ItemButtonUtil.ItemContextMatchResult
		return result and result.DoesNotApply
	end
	local s = Make(tile, parent, true, tile.icon, tile.Count)
	s.lift = tile:GetFrameLevel() - parent:GetFrameLevel()   -- how far above the grid the template draws it
	s.slot:Light(tile:GetPushedTexture(), C.lit)
	Slot.Swipe(tile.Cooldown)
	return tile
end

function Tile.Plain(parent)
	local tile = CreateFrame("Frame", nil, parent)
	tile:SetSize(Tile.SIZE, Tile.SIZE)
	local icon = tile:CreateTexture(nil, "BORDER")
	icon:SetAllPoints(tile)
	local count = tile:CreateFontString(nil, "ARTWORK")
	Make(tile, parent, false, icon, count)
	tile:EnableMouse(true)
	tile:SetScript("OnEnter", function(self)
		local item = tiles[self].item
		if not item then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(Store.Link(item.item))
		GameTooltip:Show()
	end)
	tile:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return tile
end

-- Seats a button: this bag and slot, for good. True when it already was or was just made so; false in a
-- fight when it is not (the grid never asks then: it seats out of a fight and tries again after one).
function Tile.Assign(tile, bag, slot)
	local s = tiles[tile]
	local held = tile:GetAttribute("bagid") == bag and tile:GetID() == slot
	if held then s.bag, s.index = bag, slot end
	if InCombatLockdown() then return held end
	local holder = Holder(s.grid, bag)
	if tile:GetParent() ~= holder then
		tile:SetParent(holder)
		-- A new parent can move the slot's level: back to where the template drew it above the grid.
		tile:SetFrameLevel(math.max(0, s.grid:GetFrameLevel() + s.lift))
	end
	if tile:GetAttribute("bagid") ~= bag then tile:SetBagID(bag) end
	if tile:GetID() ~= slot then tile:SetID(slot) end
	s.bag, s.index = bag, slot
	if not held then s.paintedEmpty = nil end   -- another slot: painted afresh
	return true
end

-- The bag and slot this button was given. Kept here so a fight reads a plain number, not the button's
-- own bag field (that one is for the click).
function Tile.At(tile)
	local s = tiles[tile]
	if s and s.bag ~= nil then return s.bag, s.index end
	return tile:GetBagID(), tile:GetID()
end

function Tile.Grid(tile)
	local s = tiles[tile]
	return s and s.grid
end

-- Corner marks are the slot's pins (Shy.Slot.PINS): a mark's id is its pin's kind, its channel the corner.
local CORNER = { tr = "TOPRIGHT", bl = "BOTTOMLEFT" }
local DIMMED = 0.22   -- a pin on a slot that is not what is looked for

-- The quality mark says nothing of a white item (its test passes it by), but the slot's frame does: with the mark
-- on, a white item's quality is told to the slot too, so its border is a white item's in every look.
local qualityMark
local function Quality(item, found)
	if found.border then return found.border.kind end
	if not item or item.quality ~= Enum.ItemQuality.Common then return nil end
	if not qualityMark then
		for _, def in ipairs(Marks.List()) do
			if def.id == "quality" then qualityMark = def end
		end
	end
	return qualityMark and Marks.IsOn(qualityMark) and item.quality or nil
end

local function Draw(tile, s, item)
	local found = item and Marks.For(item) or {}

	local slot = s.slot
	slot:Empty(item == nil)
	slot:Quality(Quality(item, found))
	slot:Fresh(found.glow ~= nil)

	for channel, corner in pairs(CORNER) do
		local hit, pin = found[channel], s.marks[channel]
		local kind = hit and Slot.PINS[hit.id] and hit.id or nil
		if kind and not pin then
			pin = Slot.Pin(tile, nil, corner)
			slot:Clip(pin.texture)
			s.marks[channel] = pin
		end
		if pin then pin:Set(kind) end
	end

	-- Marks with their own art (def.make), created on first use.
	for _, channel in ipairs({ "tl", "top", "tint" }) do
		local hit = found[channel]
		local def = hit and hit.def
		local key = "x" .. channel
		if def and def.make and not s[key] then
			s[key] = { def = def, mark = def.make(tile) }
			-- Clipped to the slot's shape.
			for _, part in ipairs(s[key].mark.parts or {}) do s.slot:Clip(part) end
		end
		local other = s[key]
		if other then other.def.show(other.mark, (def == other.def) and hit.kind or nil) end
	end
end

local function Settle(s)
	local item = s.item
	local alpha = s.dim and 0.26 or ((item and item.locked) and 0.7 or 1)
	s.icon:SetDesaturated(s.dim or (item ~= nil and item.locked == true))
	s.icon:SetVertexColor(alpha, alpha, alpha)
	s.count:SetAlpha(s.dim and 0.22 or 1)
	s.slot:Dim(s.dim == true)
	for _, pin in pairs(s.marks) do pin.texture:SetAlpha(s.dim and DIMMED or 1) end
end

local function Fill(tile, s, item, texture)
	s.item = item
	s.icon:SetTexture(texture)
	s.icon:SetShown(texture ~= nil)
	local count = item and item.count or 0
	s.count:SetText(count > 1 and count or "")
	s.count:SetShown(count > 1)
	Draw(tile, s, item)
	Settle(s)
end

-- What a live slot was painted from, so a bag's update paints again only the slots that changed in it.
local function Same(s, info, new)
	if not info then return s.paintedEmpty == true end
	return s.paintedEmpty == false and s.pID == info.itemID and s.pCount == info.stackCount and s.pLocked == info.isLocked
		and s.pLink == info.hyperlink and s.pQuality == info.quality and s.pBound == info.isBound
		and s.pIcon == info.iconFileID and s.pNew == new
end

local function Painted(s, info, new)
	s.paintedEmpty = info == nil
	if info then
		s.pID, s.pCount, s.pLocked, s.pLink = info.itemID, info.stackCount, info.isLocked, info.hyperlink
		s.pQuality, s.pBound, s.pIcon, s.pNew = info.quality, info.isBound, info.iconFileID, new
	end
end

-- The slot's cooldown swipe, set on its own region: the game's UpdateCooldown writes fields on the button.
local function Swipe(tile, s, filled)
	local cooldown = tile.Cooldown
	if not filled then
		if s.cooling then
			s.cooling = nil
			cooldown:Hide()
		end
		return
	end
	local bag, slot = Tile.At(tile)
	local start, duration, enable = C_Container.GetContainerItemCooldown(bag, slot)
	if issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable) then return end
	if duration and duration > 0 and enable ~= 0 then
		s.cooling = true
		cooldown:SetCooldown(start, duration)
	elseif s.cooling then
		s.cooling = nil
		cooldown:Hide()
	end
end

-- A live slot painted again only if what it holds changed (a bag's update names the bag, not the slot).
-- Returns whether it holds something.
function Tile.Repaint(tile)
	local s = tiles[tile]
	local bag, slot = Tile.At(tile)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if issecretvalue(info) then return s.item ~= nil end
	local new = info ~= nil and Marks.IsNew(bag, slot) or false
	if Same(s, info, new) then return s.item ~= nil end
	return Tile.Paint(tile, info)
end

function Tile.Paint(tile, info)
	local s = tiles[tile]
	local bag, slot = Tile.At(tile)
	if info == nil then
		local ok, got = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if not ok or issecretvalue(got) then return s.item ~= nil end
		info = got
	end
	if issecretvalue(info) then return s.item ~= nil end
	if info and (issecretvalue(info.itemID) or issecretvalue(info.iconFileID)) then return s.item ~= nil end
	Painted(s, info, info ~= nil and Marks.IsNew(bag, slot) or false)
	local texture = info and info.iconFileID
	local item = Marks.Item(bag, slot)
	if item then
		item.item = info.hyperlink and Store.ItemString(info.hyperlink) or tostring(item.id)
		item.name = info.itemName
	end
	Fill(tile, s, item, texture)
	Swipe(tile, s, texture ~= nil)
	return item ~= nil
end

function Tile.Show(tile, slot, guid, source)
	local s = tiles[tile]
	local item = Marks.Remembered(slot, guid, source)
	local texture
	if item then
		local _, _, _, _, icon = C_Item.GetItemInfoInstant(item.id or 0)
		texture = icon
	end
	Fill(tile, s, item, texture)
	return item ~= nil
end

function Tile.Dim(tile, dimmed)
	local s = tiles[tile]
	dimmed = dimmed and true or false
	if s.dim == dimmed then return end
	s.dim = dimmed
	Settle(s)
end

function Tile.Item(tile)
	return tiles[tile].item
end

-- The frame in a color of its own (a focused bag's), or back to steel (gold on a bank's slot).
function Tile.Steel(tile, color)
	local s = tiles[tile]
	if s.steel == color then return end
	s.steel = color
	s.slot:Steel(color or (s.gold and GOLD.frame or nil))
end

-- The well in a color of its own (a special bag's kind, deep), or back to the look's (gold on a bank's slot).
function Tile.Well(tile, color)
	local s = tiles[tile]
	if s.well == color then return end
	s.well = color
	Dress(s)
	Settle(s)
end

function Tile.Welled(tile)
	return tiles[tile].well
end

-- A bank's slot in gold (Tile.GOLD), or the bags' again.
function Tile.Gild(tile, on)
	local s = tiles[tile]
	on = on and true or false
	if s.gold == on then return end
	s.gold = on
	Dress(s)
	Settle(s)
end

function Tile.Steeled(tile)
	return tiles[tile].steel
end

function Tile.Filled(tile)
	return tiles[tile].item ~= nil
end

function Tile.Cooldown(tile)
	local s = tiles[tile]
	if s.item then Swipe(tile, s, true) end
end

-- Redraws every slot after the enabled marks change.
function Tile.Restyle()
	for tile, s in pairs(tiles) do
		Draw(tile, s, s.item)
		Settle(s)
	end
end
