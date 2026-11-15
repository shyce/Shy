-- A virtual list: only as many row frames as fit, scrolled by mouse wheel or the thumb.
--   Rows.New(parent, rowHeight, make, fill): make(row) once per row, fill(row, thing, index) on each show
--   list:SetShownRows(n), list:SetThings(things), list:Refresh()

local ADDON, ns = ...
local UI = Shy.UI

local Rows = {}
ns.Rows = Rows

local Methods = {}

function Methods:SetShownRows(n)
	self.shown = n
	self:SetHeight(n * self.rowHeight)
	for index = #self.rows + 1, n do
		local row = CreateFrame("Frame", nil, self)
		row:SetHeight(self.rowHeight)
		row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(index - 1) * self.rowHeight)
		row:SetPoint("RIGHT", self, "RIGHT", -6, 0)   -- room for the thumb
		self.make(row)
		self.rows[index] = row
	end
	self:Refresh()
end

function Methods:SetThings(things)
	self.things = things
	self.offset = 0
	self:Refresh()
end

function Methods:Scroll(by)
	local most = math.max(0, #self.things - self.shown)
	local offset = math.min(most, math.max(0, self.offset + by))
	if offset == self.offset then return end
	self.offset = offset
	self:Refresh()
end

function Methods:Refresh()
	local things, most = self.things, math.max(0, #self.things - self.shown)
	if self.offset > most then self.offset = most end
	for index, row in ipairs(self.rows) do
		local thing = index <= self.shown and things[self.offset + index] or nil
		row:SetShown(thing ~= nil)
		if thing then self.fill(row, thing, self.offset + index) end
	end
	local thumb = self.thumb
	thumb:SetShown(most > 0)
	self.grip:SetShown(most > 0)
	if most > 0 then
		local height = self.shown * self.rowHeight
		local length = math.max(12, height * self.shown / #things)
		thumb:SetHeight(length)
		thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(height - length) * self.offset / most)
	end
end

function Rows.New(parent, rowHeight, make, fill)
	local list = CreateFrame("Frame", nil, parent)
	for name, method in pairs(Methods) do list[name] = method end
	list.rowHeight, list.make, list.fill = rowHeight, make, fill
	list.rows, list.things, list.offset, list.shown = {}, {}, 0, 0
	list.thumb = list:CreateTexture(nil, "OVERLAY")
	list.thumb:SetWidth(2)
	UI.Paint(list.thumb, UI.colors.dim)
	list.thumb:Hide()
	-- Dragged, the thumb picks the row at the top; the bar reaches into the plate's margin.
	list.grip = UI.ThumbGrip(list, list.thumb, { width = 9, out = 3, drag = function(share)
		local offset = math.floor(share * math.max(0, #list.things - list.shown) + 0.5)
		if offset == list.offset then return end
		list.offset = offset
		list:Refresh()
	end })
	list.grip:Hide()
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(self, delta) self:Scroll(-delta) end)
	return list
end
