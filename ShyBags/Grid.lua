-- A grid of slots: live (following the game's bags) or stored (showing saved slot strings).
--   grid:SetBags({ 0, 1, ... })                    live
--   grid:SetLists({ slots, ... }, guid, source)    stored
--   grid.columns / grid.rows fix the shape (set before either); grid.least is a minimum row count
--   grid.prefer is the column count the player chose: kept within what the slots allow (Grid.Columns).
--     When it alone changes, the slots slide to their new places and nothing is read again (grid:Lay).
--   grid:Morph(from, to, f) draws the slots a share f of the way between two column counts.
--   grid.order(bags, sizes) returns every slot as { bag, slot } in layout order; grid.sort names that order.
--     A special bag's slots (herbs, souls, arrows, the reagent bag...) are framed and welled in their kind's
--     color (BagBar.Kind). With grid.apart they stand after the ordinary ones whatever the order, a run for
--     each kind on rows of its own under the kind's name; without it they stand in with the rest.
--     The order is read only on Build, so slots don't move under the mouse; grid:Settled() is false once
--     a fresh Build would lay them out differently.
--   grid:Filter(test), grid:Room() (free, total), grid:Shape() (columns, rows), grid.onChange
--   grid:Down(columns) the rows the slots take that many across; grid.gap the room the runs' names take,
--     over the rows' own height
-- A live slot is the game's own button (Tile.lua). Every slot of every bag has one of its own for good
-- (grid.where), made, told its bag and place and seated out of a fight: at login and whenever a bag changes
-- size, shown or not. So a fight finds the window whole and only paints. A fight never makes, moves, shows,
-- hides or retargets a slot (doing any of it then taints the click or clears the button off the window):
-- a new bag's slots, another order, a slide or a dragged edge that a fight interrupts wait where they are,
-- and the layout catches up once the fight ends (grid.pending, PLAYER_REGEN_ENABLED).
-- Shown, a live grid follows every bag event and paints the slots that changed; closed, it only keeps its
-- seats (a bag put on or taken off), so nothing is read for a window nobody sees.

local ADDON, ns = ...
local Tile = ns.Tile
local UI = Shy.UI

local Grid = {}
ns.Grid = Grid

local KEYS = Enum.BagIndex.Keyring
local STEP = Tile.SIZE + Tile.GAP
local MOST, LEAST = 10, 4   -- most columns; fewest columns, and rows filled before widening
local CAPTION = 14          -- room over a run that stands apart, for its name
Grid.SLIDE = 0.16           -- seconds a slot takes to slide to a new place as the grid is reshaped
Grid.CAPTION = CAPTION

local Methods = {}

local function Key(bag, slot)
	return bag * 1000 + slot
end

-- GetKeyRingSize is the key ring's used length, not its mostly empty capacity. Nil when the count
-- can't be read (a secret, or a bank tab asked away from the banker), so that is never taken for an
-- empty bag.
local function Size(bag)
	local ok, n = pcall(bag == KEYS and GetKeyRingSize or C_Container.GetContainerNumSlots, bag)
	if not ok or type(n) ~= "number" or issecretvalue(n) then return nil end
	return n
end

-- Layout key: bags, shape and sort; and the same without the column count the player chose, which alone
-- moves the slots without changing what any of them holds.
local function Held(self)
	return table.concat(self.bags or {}, ",") .. "|" .. tostring(self.rows) .. "|" .. tostring(self.columns) .. "|" .. tostring(self.sort)
		.. "|" .. tostring(self.apart)
end

local function Asked(self)
	return Held(self) .. "|" .. tostring(self.prefer)
end

-- Work a fight stopped: done once it ends.
local function Queue(self)
	self.pending = true
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- True while a live slot must not be made, moved, shown, hidden or told its bag. Doing any of it in a
-- fight clears it off the window for the rest of the fight, or taints its click.
local function Frozen(self)
	return self.live and InCombatLockdown()
end

function Methods:SetBags(bags)
	self.bags = bags
	if Asked(self) == self.laid then return end
	if self.count > 0 and Held(self) == self.held then
		self:Lay(self:IsVisible())
	else
		self:Build()
	end
end

local function Same(a, b)
	if not a or not b or #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

function Methods:SetLists(lists, guid, source)
	local same = self.count > 0 and guid == self.guid and source == self.source and Same(lists, self.lists)
		and Held(self) == self.held
	self.lists, self.guid, self.source = lists, guid, source
	if same and Asked(self) ~= self.laid then
		self:Lay(true)
	else
		self:Build()
	end
end

-- The fewest and the most columns n slots may be laid in: the title and footer need LEAST columns, and
-- LEAST rows are filled before a grid widens, so the widest shape is LEAST rows tall.
function Grid.Columns(n)
	return LEAST, math.max(LEAST, math.ceil(n / LEAST))
end

-- The rows n slots take with `columns` across: a run that stands apart starts a row of its own.
local function Down(self, n, columns)
	local spans, rows = self.spans, 0
	if spans and #spans > 1 then
		for _, span in ipairs(spans) do rows = rows + math.ceil(span.count / columns) end
	else
		rows = math.ceil(n / columns)
	end
	return math.max(self.least or 1, rows)
end

local function Fit(self, n)
	local columns, rows
	if self.columns then
		columns = self.columns
	elseif self.rows then
		columns = math.max(1, math.ceil(n / self.rows))
	elseif self.prefer then
		local least, most = Grid.Columns(n)
		columns = math.max(least, math.min(most, self.prefer))
	else
		-- The title and footer need at least LEAST columns.
		columns = math.max(LEAST, math.min(MOST, math.ceil(n / LEAST)))
	end
	rows = self.rows or Down(self, n, columns)
	return columns, rows
end

-- Columns, rows for n slots: by itself, or as near `prefer` columns as n slots allow.
function Grid.Fit(n, prefer)
	return Fit({ prefer = prefer }, n)
end

-- Where each slot stands is kept here by its number, not on the slot (a live one is the game's button):
-- { x, y } its place, and while it slides { fromX, fromY } where it left from and { nowX, nowY }.
local function Put(self, tile, x, y)
	if Frozen(self) then return end
	tile:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
end

local function PlaceAt(self, tile, n, x, y, slide)
	if Frozen(self) then return end
	local at = self.at[n]
	if slide and at then
		at.fromX, at.fromY = at.nowX or at.x, at.nowY or at.y
		at.x, at.y = x, y
	else
		self.at[n] = { x = x, y = y }
		tile:ClearAllPoints()
		Put(self, tile, x, y)
	end
	tile:Show()
end

local function Place(self, tile, n, columns, lead, slide)
	local cell = lead + n - 1
	PlaceAt(self, tile, n, (cell % columns) * STEP, math.floor(cell / columns) * STEP, slide)
end

-- The name over a run that stands apart, in its kind's color, and a rule on to the grid's right edge.
-- Made as they are needed and kept. y: the middle of its line, down from the grid's top.
local function Caption(self, k, span, y)
	self.heads = self.heads or {}
	local head = self.heads[k]
	if not head then
		head = { text = UI.Text(self, "", 9, true, UI.colors.dim), rule = self:CreateTexture(nil, "ARTWORK") }
		head.text:SetWordWrap(false)
		head.rule:SetHeight(1)
		UI.Paint(head.rule, UI.colors.border, 0.9)
		self.heads[k] = head
	end
	if head.name ~= span.name or head.color ~= span.color then
		head.name, head.color = span.name, span.color
		head.text:SetText(span.name:upper())
		Shy.Theme.Ink(head.text, span.color)
	end
	head.text:ClearAllPoints()
	head.text:SetPoint("LEFT", self, "TOPLEFT", 1, -y)
	head.rule:ClearAllPoints()
	head.rule:SetPoint("LEFT", self, "TOPLEFT", head.text:GetStringWidth() + 8, -y)
	head.rule:SetPoint("RIGHT", self, "TOPRIGHT", 0, -y)
	head.text:Show()
	head.rule:Show()
end

local function HideCaptions(self, from)
	local heads = self.heads
	for k = from, heads and #heads or 0 do
		heads[k].text:Hide()
		heads[k].rule:Hide()
	end
end

-- Every slot to its place, `columns` across and `rows` down. The first run is indented so its last slot
-- ends its last row (a fixed shape fills from the top left); a run that stands apart starts a row of its
-- own, under its name. Keeps the room the names take (grid.gap).
local function Stand(self, columns, rows, slide)
	local spans = self.spans
	local runs = spans and #spans or 1
	local fixed = self.rows or self.columns
	local row, gap = 0, 0
	for k = 1, runs do
		local first, count = 1, self.count
		if spans then first, count = spans[k].first, spans[k].count end
		local down = runs == 1 and rows or math.ceil(count / columns)
		local lead = 0
		if k == 1 then
			if not fixed then lead = math.max(0, columns * down - count) end
		else
			Caption(self, k - 1, spans[k], row * STEP + gap + (CAPTION - Tile.GAP) / 2)
			gap = gap + CAPTION
		end
		for i = 1, count do
			local cell, n = lead + i - 1, first + i - 1
			PlaceAt(self, self.tiles[n], n, (cell % columns) * STEP, (row + math.floor(cell / columns)) * STEP + gap, slide)
		end
		row = row + down
	end
	HideCaptions(self, runs)
	self.gap = gap
end

-- Every slot in its place at once, whatever was sliding.
local function Arrive(self)
	self:SetScript("OnUpdate", nil)
	if not self.sliding then return end
	-- Still on the way when a fight starts: leave every button where it is. Snapping it now clears it.
	if Frozen(self) then
		self.sliding = nil
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		Queue(self)
		return
	end
	self.sliding = nil
	if self.live then self:UnregisterEvent("PLAYER_REGEN_DISABLED") end
	for n = 1, self.count do
		local at = self.at[n]
		if at and at.fromX then
			at.fromX, at.fromY, at.nowX, at.nowY = nil, nil, nil, nil
			Put(self, self.tiles[n], at.x, at.y)
		end
	end
end

local function Slide(self, elapsed)
	if Frozen(self) then
		Arrive(self)
		return
	end
	local t = math.min(1, self.sliding + elapsed / Grid.SLIDE)
	if t >= 1 then
		Arrive(self)
		return
	end
	self.sliding = t
	local left = 1 - t
	local eased = 1 - left * left * left   -- quick away, soft to rest
	for n = 1, self.count do
		local at = self.at[n]
		if at and at.fromX then
			at.nowX, at.nowY = at.fromX + (at.x - at.fromX) * eased, at.fromY + (at.y - at.fromY) * eased
			Put(self, self.tiles[n], at.nowX, at.nowY)
		end
	end
end

-- The same slots in another shape: each slides to its new place. Nothing is read or painted again.
function Methods:Lay(slide)
	if Frozen(self) then
		Queue(self)
		return
	end
	local columns, rows = Fit(self, self.count)
	self.laid, self.held = Asked(self), Held(self)
	Stand(self, columns, rows, slide)
	self.across, self.down = columns, rows
	self:SetSize(columns * STEP - Tile.GAP, rows * STEP - Tile.GAP + self.gap)
	-- A live slot is the game's button and can't be moved in a fight: a slide stops where it is.
	if slide and not InCombatLockdown() then
		if self.live and not self.sliding then self:RegisterEvent("PLAYER_REGEN_DISABLED") end
		self.sliding = 0
		self:SetScript("OnUpdate", Slide)
	else
		self.sliding = self.sliding or 0
		Arrive(self)
	end
end

-- Between two shapes: every slot a share `f` of the way from its place with `from` columns to its place
-- with `to`. The mouse drives it as the window's edge is dragged; nothing is read or painted.
function Methods:Morph(from, to, f)
	if Frozen(self) then return end
	Arrive(self)
	local total = self.count
	local fromRows, toRows = Down(self, total, from), Down(self, total, to)
	local spans = self.spans
	local runs = spans and #spans or 1
	local rowA, rowB, gap = 0, 0, 0
	for k = 1, runs do
		local first, count = 1, total
		if spans then first, count = spans[k].first, spans[k].count end
		local downA = runs == 1 and fromRows or math.ceil(count / from)
		local downB = runs == 1 and toRows or math.ceil(count / to)
		local leadA, leadB = 0, 0
		if k == 1 then
			leadA, leadB = math.max(0, from * downA - count), math.max(0, to * downB - count)
		else
			Caption(self, k - 1, spans[k], (rowA + (rowB - rowA) * f) * STEP + gap + (CAPTION - Tile.GAP) / 2)
			gap = gap + CAPTION
		end
		for i = 1, count do
			local a, b, n = leadA + i - 1, leadB + i - 1, first + i - 1
			local ax, ay = (a % from) * STEP, (rowA + math.floor(a / from)) * STEP
			local at = self.at[n]
			at.x, at.y = ax + ((b % to) * STEP - ax) * f, ay + ((rowB + math.floor(b / to)) * STEP - ay) * f + gap
			Put(self, self.tiles[n], at.x, at.y)
		end
		rowA, rowB = rowA + downA, rowB + downB
	end
	self:SetSize((from + (to - from) * f) * STEP - Tile.GAP, (fromRows + (toRows - fromRows) * f) * STEP - Tile.GAP + gap)
end

function Methods:Down(columns)
	return Down(self, self.count, columns)
end

-- Seating: a button of its own for every slot the bags have, kept for good (a slot gone keeps its button
-- aside, hidden, for its return). Follows the bags out of a fight; in one it stands as it was, and the
-- fight's end seats what it missed. Returns the slots seated and whether the seating changed; nil when
-- the bags can't be read, or nothing was ever seated and a fight is on.
local function Seat(self)
	local sizes, total = {}, 0
	for _, bag in ipairs(self.bags) do
		local n = Size(bag)
		if n == nil then
			if InCombatLockdown() then Queue(self) end
			return nil
		end
		sizes[bag] = n
		total = total + n
	end
	local same = self.seated ~= nil
	if same then
		for bag, n in pairs(sizes) do
			if self.sizes[bag] ~= n then same = false end
		end
		for bag in pairs(self.sizes) do
			if sizes[bag] == nil then same = false end
		end
	end
	if same then return total, false end
	if InCombatLockdown() then
		Queue(self)
		return self.seated, false
	end
	for key, tile in pairs(self.where) do
		local bag, slot = Tile.At(tile)
		if slot > (sizes[bag] or 0) then
			self.where[key], self.spare[key] = nil, tile
			tile:Hide()
		end
	end
	for _, bag in ipairs(self.bags) do
		for slot = 1, sizes[bag] do
			local key = Key(bag, slot)
			if not self.where[key] then
				local tile = self.spare[key]
				self.spare[key] = nil
				if not tile then
					tile = Tile.Live(self)
					Tile.Assign(tile, bag, slot)
				end
				self.where[key] = tile
			end
		end
	end
	self.sizes, self.seated = sizes, total
	return total, true
end

-- Special bags (herbs, souls, arrows, the reagent bag...): by bag, their kind's color as the bag column
-- shows it, its name and its name for several (BagBar.Kind); an ordinary bag and the key ring have none.
-- A live grid only: a stored one can't be asked.
local function Kinds(self)
	local kind = ns.BagBar and ns.BagBar.Kind
	local colors, names, many = {}, {}, {}
	if not (self.live and kind) then return colors, names, many end
	for _, bag in ipairs(self.bags or {}) do
		if bag ~= KEYS then colors[bag], names[bag], many[bag] = kind(bag) end
	end
	return colors, names, many
end

-- A kind's color as a slot's well: deep, so the item in it still reads (one table per color, kept).
local DEEP = 0.26
local deep = {}
local function Deep(color)
	if not color then return nil end
	if not deep[color] then deep[color] = { color[1] * DEEP, color[2] * DEEP, color[3] * DEEP } end
	return deep[color]
end

-- The slots in the runs they are laid out in, with grid.apart: the ordinary bags' first, then a run for each
-- kind of special bag in the order its first slot came, whatever the sort. Returns the list in that order
-- and its runs, the ordinary one first: { first, count, name, color }. Not apart, or no special bag: the
-- list as it came, and no runs. bagOf(entry) is an entry's bag.
local function Runs(self, list, bagOf)
	if not self.apart then return list end
	local colors, names, many = Kinds(self)
	if next(names) == nil then return list end
	local out, runs, byName = {}, {}, {}
	for _, entry in ipairs(list) do
		local bag = bagOf(entry)
		local name = names[bag]
		if name then
			local run = byName[name]
			if not run then
				run = { list = {}, bags = {}, held = 0, name = name, many = many[bag], color = colors[bag] }
				byName[name] = run
				runs[#runs + 1] = run
			end
			if not run.bags[bag] then
				run.bags[bag] = true
				run.held = run.held + 1
			end
			run.list[#run.list + 1] = entry
		else
			out[#out + 1] = entry
		end
	end
	if #runs == 0 then return list end
	local spans = { { first = 1, count = #out } }
	for _, run in ipairs(runs) do
		spans[#spans + 1] = { first = #out + 1, count = #run.list, name = run.held > 1 and run.many or run.name, color = run.color }
		for _, entry in ipairs(run.list) do out[#out + 1] = entry end
	end
	return out, spans
end

-- The runs in a word, to tell when they change though no slot moved (a bag swapped for one of another kind).
local function Told(spans)
	local out = ""
	for _, span in ipairs(spans or {}) do out = out .. span.first .. ":" .. tostring(span.name) .. ";" end
	return out
end

local function PlaceBag(place) return place[1] end
local function TileBag(tile) return (Tile.At(tile)) end

-- The seated buttons in the order they are laid out, and their runs: the sort's order, else bag by bag,
-- the special bags' apart when asked (Runs). (A sort that misses a slot, or names one with no seat, falls
-- back to bag order.)
local function Arrange(self)
	local list
	local places = self.order and self.order(self.bags, self.sizes)
	if places and #places == self.seated then
		list = {}
		for _, place in ipairs(places) do
			local tile = self.where[Key(place[1], place[2])]
			if not tile then
				list = nil
				break
			end
			list[#list + 1] = tile
		end
	end
	if not list then
		list = {}
		for _, bag in ipairs(self.bags) do
			for slot = 1, self.sizes[bag] do list[#list + 1] = self.where[Key(bag, slot)] end
		end
	end
	return Runs(self, list, TileBag)
end

local function SameOrder(self, list)
	if #list ~= self.count then return false end
	for i, tile in ipairs(list) do
		if self.tiles[i] ~= tile then return false end
	end
	return true
end

-- Stored slots: plain frames, one per saved slot string, made as they are needed.
local function BuildStored(self)
	local total = 0
	for _, list in ipairs(self.lists or {}) do total = total + #list end
	self.pending = nil
	Arrive(self)
	self.laid, self.held = Asked(self), Held(self)
	self.spans, self.gap = nil, 0
	local columns, rows = Fit(self, total)
	-- A short first row is indented, like the combined bag, so the last slot ends the last row.
	local lead = math.max(0, columns * rows - total)
	if self.rows or self.columns then lead = 0 end   -- a fixed shape fills from the top left
	local n = 0
	for _, list in ipairs(self.lists or {}) do
		for _, slot in ipairs(list) do
			n = n + 1
			local tile = self.tiles[n]
			if not tile then
				tile = Tile.Plain(self)
				self.tiles[n] = tile
			end
			Place(self, tile, n, columns, lead)
			Tile.Show(tile, slot, self.guid, self.source)
		end
	end
	for i = n + 1, #self.tiles do self.tiles[i]:Hide() end
	self.count, self.across, self.down = n, columns, rows
	self:SetSize(columns * STEP - Tile.GAP, rows * STEP - Tile.GAP)
	self:Paint()
end

-- Live slots: seated, put in order and laid out (out of a fight), then painted (while shown). In a fight
-- the buttons stand as they were, painted afresh; what the fight stopped is done once it ends.
function Methods:Build()
	if not self.live then return BuildStored(self) end
	if not self.bags then return end
	local total, reseated = Seat(self)
	if total == nil then return end
	local list, spans = Arrange(self)
	local asked, told = Asked(self), Told(spans)
	if reseated or self.pending or asked ~= self.laid or told ~= self.told or not SameOrder(self, list) then
		if Frozen(self) then
			Queue(self)
		else
			self.pending = nil
			Arrive(self)
			self.tiles, self.count = list, #list
			self.spans, self.told = spans, told
			self.laid, self.held = asked, Held(self)
			local columns, rows = Fit(self, total)
			Stand(self, columns, rows)
			self.across, self.down = columns, rows
			self:SetSize(columns * STEP - Tile.GAP, rows * STEP - Tile.GAP + self.gap)
		end
	end
	if self:IsVisible() then self:Paint() end
end

-- only = { [bag] = true } limits it to those bags.
function Methods:Paint(only)
	local free = 0
	for i = 1, self.count do
		local tile = self.tiles[i]
		if self.live and only == nil then
			Tile.Paint(tile)
		elseif self.live and only[Tile.At(tile)] then
			Tile.Repaint(tile)
		end
		if not Tile.Filled(tile) then free = free + 1 end
	end
	self.free = free
	self:Filter(self.test)
	if self.onChange then self.onChange(self) end
end

-- One slot painted again (a lock picked up or let go): the rest of its bag is as it was.
function Methods:PaintOne(bag, slot)
	local tile = self.where and self.where[Key(bag, slot)]
	if not tile then return self:Paint({ [bag] = true }) end
	local had = Tile.Filled(tile)
	Tile.Paint(tile)
	local has = Tile.Filled(tile)
	if had ~= has then self.free = (self.free or 0) + (had and 1 or -1) end
	self:Filter(self.test)
	if self.onChange then self.onChange(self) end
end

function Methods:Filter(test)
	self.test = test
	local hits = 0
	local focus = self.live and self.focus or nil
	local kinds = Kinds(self)
	for i = 1, self.count do
		local tile = self.tiles[i]
		local item = Tile.Item(tile)
		local miss = test ~= nil and item ~= nil and not test(item)
		local bag = Tile.At(tile)
		local mine = focus ~= nil and bag == focus
		Tile.Dim(tile, miss or (focus ~= nil and not mine))
		Tile.Steel(tile, mine and self.focusColor or kinds[bag])
		Tile.Well(tile, Deep(kinds[bag]))
		if test and item and not miss then hits = hits + 1 end
	end
	self.hits = hits
end

-- One bag's slots, empty ones too, stand out in `color` while the rest dim (nil: none).
function Methods:Focus(bag, color)
	self.focus, self.focusColor = bag, color
	self:Filter(self.test)
end

-- Its slots in the bank's gold (Tile.Gild), or the bags' again: every one it has made, seated or spare, and every
-- one it makes from now.
function Methods:Gild(on)
	on = on and true or false
	if self.gold == on then return end
	self.gold = on
	for _, list in ipairs({ self.tiles or {}, self.where or {}, self.spare or {} }) do
		for _, tile in pairs(list) do Tile.Gild(tile, on) end
	end
end

function Methods:Room()
	return self.free or 0, self.count or 0
end

-- Clears "new" on every item, as the default bags do on closing.
function Methods:Seen()
	if not self.live then return end
	for i = 1, self.count do
		local tile = self.tiles[i]
		if Tile.Filled(tile) then C_NewItems.RemoveNewItem(Tile.At(tile)) end
	end
end

function Methods:Shape()
	return self.across or 0, self.down or 0
end

-- False once the bags have changed so that a fresh layout would differ from the one shown.
function Methods:Settled()
	local places = self.live and self.order and self.order(self.bags or {}, self.sizes)
	if not places or #places ~= self.count then return true end
	places = Runs(self, places, PlaceBag)
	for i, place in ipairs(places) do
		local tile = self.tiles[i]
		local bag, slot = Tile.At(tile)
		if bag ~= place[1] or slot ~= place[2] then return false end
	end
	return true
end

local function Resized(self, dirty)
	for bag in pairs(dirty or {}) do
		if self.sizes[bag] then
			local now = Size(bag)
			if now and now ~= self.sizes[bag] then return true end
		end
	end
	return false
end

-- Followed while shown: what the slots paint from.
local PAINTING = { "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "BAG_NEW_ITEMS_UPDATED" }
-- Followed always: a bag put on or taken off changes the seats, and the end of a burst is when a grid with
-- no seat yet (the bags not known at login) looks again.
local SEATING = { "BAG_UPDATE_DELAYED", "BAG_CONTAINER_UPDATE" }

local function OnEvent(self, event, bag, slot)
	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if self.pending then self:Build() end
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		Arrive(self)
	elseif event == "BAG_CONTAINER_UPDATE" then
		-- A bag put on or taken off: the seats follow, shown or not. Only then; the order is read again
		-- on no other account, so nothing moves under the mouse.
		if self.bags and Resized(self, self.sizes) then self:Build() end
	elseif event == "BAG_UPDATE" then
		self.dirty = self.dirty or {}
		self.dirty[bag] = true
	elseif event == "BAG_UPDATE_DELAYED" then
		local dirty = self.dirty
		self.dirty = nil
		if (self.seated or 0) == 0 then
			-- No seat yet (the bags not known when the grid was made): looked at again at the end of a burst.
			if self.bags and (dirty or not self:IsVisible()) then self:Build() end
		elseif not self:IsVisible() then
			return   -- closed: nothing is read for it
		elseif Resized(self, dirty) then
			self:Build()
		elseif dirty then
			self:Paint(dirty)
		end
	elseif event == "ITEM_LOCK_CHANGED" then
		-- Without a slot it is an equipped item.
		if slot and self.sizes[bag] then self:PaintOne(bag, slot) end
	elseif event == "BAG_NEW_ITEMS_UPDATED" then
		-- Only the slots whose "new" mark changed paint again.
		local all = {}
		for held in pairs(self.sizes) do all[held] = true end
		self:Paint(all)
	else
		for i = 1, self.count do Tile.Cooldown(self.tiles[i]) end
	end
end

local function OnShow(self)
	for _, event in ipairs(PAINTING) do self:RegisterEvent(event) end
	self.dirty = nil
	if self.bags then self:Build() end
end

local function OnHide(self)
	for _, event in ipairs(PAINTING) do self:UnregisterEvent(event) end
	self.dirty = nil
end

function Grid.New(parent, live)
	local grid = CreateFrame("Frame", nil, parent)
	for name, method in pairs(Methods) do grid[name] = method end
	grid.live = live ~= false
	grid.tiles, grid.sizes, grid.count, grid.at, grid.gap = {}, {}, 0, {}, 0
	if grid.live then
		grid.where, grid.spare = {}, {}   -- bag * 1000 + slot -> its button, seated; set aside
		grid:Hide()   -- a new frame starts shown, so OnShow would never fire
		grid:SetScript("OnShow", OnShow)
		grid:SetScript("OnHide", OnHide)
		grid:SetScript("OnEvent", OnEvent)
		for _, event in ipairs(SEATING) do grid:RegisterEvent(event) end
	end
	return grid
end
