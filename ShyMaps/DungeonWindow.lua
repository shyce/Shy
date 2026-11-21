-- The dungeon journal: the map window's other side. The map is the world outside; this is the world inside its
-- instances, laid out as the map is so the two read as one window turned over, and joined at each dungeon's door.
-- For the questions you bring to a dungeon: what's in there, where is each boss, what does it do, what drops for
-- me, which quests should I bring, and how do I get in.
--
-- The face: one frame that stands in the map window while it is open (Sides.lua: over everything under the
-- window's header) and in a window of its own, the map window's size, while it is shut (a command, the run card
-- and the options open the journal there; its World half and its ways out open the map's window).
--   the bar     as the map's, and its size: the side switch (World | Dungeons) leading it, the way down to where
--               you are as crumbs (every dungeon, this one, the page), the search at its right end
-- Under the bar everything is small and close, as what is laid over the map is (Shy.Maps.OVER there): as much as
-- can be read at once.
--   the place   where the map is: the dungeon whole, the floor you are on bright and the others dim round it,
--               read as the map is (DungeonFloors.lua: the wheel zooms, a drag pans, a right click goes out a
--               step), every boss a numbered mark, and a small arrow where the floor leads onto another (a click
--               goes there); its picture and the bosses in order where the game has no floor of it. In its
--               corners the way out to its zone, and the floors
--   the column  where the quest log is, in the theme's housing as the place is: the band (the dungeon's picture
--               melting into the page; the way back before its name, where it is, what there is to know at a
--               glance as pills), then its list, a line each and no box round any: every boss with its mark as
--               the floor wears it (the family's glass mark, its number on it, in the color of what it has for
--               you; the mouse on a line lights its mark on the floor, and on a mark its line) and, at the line's
--               end, what it has for you (the drops themselves as
--               pictures, then a few words), the rest of the dungeon, its quests; under it the drops you starred
--               and your best upgrades. A boss opened, the band is its stage (the creature, its name, the keys to
--               the boss before and after) over what it does (DungeonBoss.lua) and what it drops (DungeonLoot.lua),
--               a list for each count. Under the column, the keys that take you there, each only where the addon
--               it works through is: find a group (ShyGroup), lead me there and get its quests (ShyQuest)
-- Every dungeon: each as the game's own picture of it (Shy.Instances.Card), dungeons by level then raids, yours
-- at your level lit; what the search finds stands in their place.
-- The face is the theme's, as every window is: a dungeon's own picture is on its band, never its color on the face.
--   Journal.Open(map, boss)   opens it: on a dungeon (and a boss, by its place in the order), every dungeon with none
--   Journal.Page(page)        turns to a page of the dungeon open: "overview", a boss's place, "trash", "quests"
--   Journal.Up()              out a step: a page to its overview, the overview to every dungeon (or, come in
--                             at its door on the map, back out to the map as you left it)
--   Journal.Out()             out of the door: the map turned to the world, at the dungeon's entrance
--   Journal.Door(map)         its way in: { map, x, y, name (its zone's) }, or nil where nothing knows it
--   Journal.Home(parent, w, h, x, scale)   the face stood on a host (Sides.lua's, in the map window), w by h, its
--                             bar's pieces beginning x in, what is under the bar at `scale`; told again when the
--                             host is sized
--   Journal.Row(key)          the list's line for a page (a boss's place, "trash", "quests"), while it shows
--   Journal.Toggle()          Journal.IsOpen()          Journal.Command(words)   /shymaps dungeons [name]

local ADDON, ns = ...
local T = ns.T
local J = ns.Dungeons
local UI = Shy.UI
local C = UI.colors

ns.Journal = ns.Journal or {}
local Journal = ns.Journal
local Loot, Boss, Floors = Journal.Loot, Journal.Boss, Journal.Floors

local L = {
	w = 1035, h = 562, least = { 760, 440 },   -- the shell: the windowed map's size
	-- The bar, in the face's own units (the map's bar's).
	bar = 36, pad = 10,
	search = 190, searchLeast = 130,       -- the search box, and at the least
	crumb = 12, crumbTall = 20, slash = 12,
	-- Under the bar, in the units of what is laid there.
	gap = 6,                               -- round the pieces and between them
	frame = 3,                             -- this much of the column's housing shows round its page, inside the look's border
	ground = 0.8,                          -- how solid the page's ground is over the look's own face
	side = 6,                              -- the page's words in from its left edge
	fade = 20,                             -- the band's picture melts into the page over this much of its foot
	col = { 0.36, 380, 470 },              -- the column: its share of the width, at the least, at the most
	band = 72,                             -- a dungeon's band
	stage = { 0.2, 84, 124 },              -- a boss's stage: its share of the column's height, at the least, at the most
	model = 0.3,                           -- the creature's share of the stage's width, at the most
	title = 16, lesser = 13,               -- the band's name, and where it has no room at that
	key = 20, glyph = 9,                   -- a key on the band (the way back, the boss before and after), and its caret
	pillGap = 5,                           -- between the band's pills
	card = 190, cardGap = 6, caption = 20, -- a dungeon's card on the first page, and a caption over a kind
	scroll = 14,                           -- a scroll bar's room
	foot = 30, footKey = 22, keyGap = 4,   -- the keys under the column
	top = 4,                               -- over a page's first section, under the band
	kick = 19,                             -- a section's name over its hairline
	sub = 15,                              -- a list's own name, under its section's
	note = 16,                             -- a quiet line
	row = 26, rowGap = 0,                  -- a line of the dungeon's list
	mark = 20,                             -- its number, as its mark on the floor
	icon = 18, icons = 4, iconGap = 3,     -- a drop's picture at its end, how many at the most, and between two
	result = 30, quest = 26, under = 14,   -- under: how far in a quest's rewards stand under its row
	best = 5,                              -- your best upgrades listed on the overview
	corner = 22, cornerIn = 6,             -- a plate in the place's corner, and how far in from it
	choice = 20,                           -- the floors' choice
}
local HEADER = UI.HEAD.window.line + UI.LINE
local NONE = {}
local STATE = { done = { "Handed in", "good" }, carried = { "In your log", "head" }, ahead = { "To pick up", "dim" } }
local PAGES = { trash = { "The rest of the dungeon", "What only its other creatures drop.", short = "The rest" },
	quests = { "Quests" }, runs = { "Your runs", "How your runs here went.", short = "Your runs" },
	sets = { "Sets", "The item sets with a piece that drops here.", short = "Sets" } }
local Run = ns.DungeonRun

local own = { cards = {}, captions = {}, results = {}, kicks = {}, notes = {}, quests = {}, pills = {}, floors = {},
	rows = {}, byKey = {}, has = {}, tones = {}, w = L.w, h = L.h - HEADER, k = 1 }
local state = { map = nil, page = "overview", floor = nil, query = "" }
local Fill, Hover   -- (both used above where they are written)

---------------------------------------------------------------------------
-- The other addons it works with
---------------------------------------------------------------------------
local function Quest()
	local quest = Shy.addons.Quest
	return quest and quest.DungeonQuests and quest or nil
end

local function Quests(map)
	local quest = Quest()
	return quest and quest:DungeonQuests(map) or NONE
end

local function Handed(quests)
	local done = 0
	for _, one in ipairs(quests) do
		if one.state == "done" then done = done + 1 end
	end
	return done
end

-- Which creatures your quests for the dungeon still need something of: { [creature] = true }.
local function Needed(map)
	local out = {}
	for _, one in ipairs(Quests(map)) do
		if one.state ~= "done" then
			for _, creature in ipairs(one.needs or NONE) do out[creature] = true end
		end
	end
	return out
end

-- How many of a list's drops are upgrades for you (ShyGear's word), of those the game has told of.
local function Upgrades(rows)
	local n = 0
	for _, row in ipairs(rows) do
		local v = Loot.Verdict(row.item)
		if v and v.kind == "upgrade" then n = n + 1 end
	end
	return n
end

local function Count(n, one, many)
	return n == 1 and ("1 " .. one) or (n .. " " .. many)
end

-- A dungeon's way in: ShyQuest's word for it, else the entrance the game's own map has of that name.
function Journal.Door(map)
	local quest = Quest()
	local door = quest and quest.DungeonDoor and quest:DungeonDoor(map)
	if not door and ns.Sides and ns.Sides.Door then door = ns.Sides.Door(map) end
	if not door then return nil end
	local info = C_Map.GetMapInfo(door.map)
	return { map = door.map, x = door.x, y = door.y, name = info and info.name or nil }
end

-- What a list of drops has for you: the drops to show as pictures (those you starred, then your upgrades, the
-- best first; with nothing to judge by, its likeliest), and a few words with their color. needed: a quest of
-- yours needs the creature they drop from.
local function Has(rows, needed)
	local stars, ups, items = {}, {}, {}
	for _, row in ipairs(rows) do
		if J.Wanted(row.item) then
			stars[#stars + 1] = row.item
		else
			local v = Loot.Verdict(row.item)
			if v and v.kind == "upgrade" then ups[#ups + 1] = { item = row.item, score = v.score or 0 } end
		end
	end
	table.sort(ups, function(a, b)
		if a.score ~= b.score then return a.score > b.score end
		return a.item < b.item
	end)
	for _, item in ipairs(stars) do items[#items + 1] = item end
	for _, up in ipairs(ups) do items[#items + 1] = up.item end
	if #items == 0 and not Shy.addons.Gear then
		for i = 1, math.min(3, #rows) do items[i] = rows[i].item end
	end
	local upgrades = Upgrades(rows)
	if needed then return items, "A quest needs it", C.alert end
	if #stars > 0 then return items, #stars == 1 and "A starred drop" or (#stars .. " starred drops"), C.alert end
	if upgrades > 0 then return items, Count(upgrades, "upgrade", "upgrades"), C.good end
	return items, #rows > 0 and Count(#rows, "drop", "drops") or "No drops yet", C.dim
end

---------------------------------------------------------------------------
-- Small pieces
---------------------------------------------------------------------------
local function Take(pool, make, parent)
	pool.used = (pool.used or 0) + 1
	local piece = pool[pool.used]
	if not piece then
		piece = make(parent)
		pool[pool.used] = piece
	end
	piece:Show()
	return piece
end

local function Rest(pool)
	for i = 1, #pool do pool[i]:Hide() end
	pool.used = 0
end

-- A section's name in small capitals over a hairline that runs out to the right, a few quiet words after it.
local function Kicker(parent)
	local k = CreateFrame("Frame", nil, parent)
	k:SetHeight(15)
	k.text = UI.Words(k, UI.NameFont(10), C.text)
	k.text:SetPoint("TOPLEFT")
	k.aside = UI.Words(k, UI.NameFont(10), C.dim)
	k.aside:SetPoint("LEFT", k.text, "RIGHT", 7, 0)
	k.rule = k:CreateTexture(nil, "ARTWORK")
	k.rule:SetPoint("TOPLEFT", 0, -14)
	k.rule:SetPoint("TOPRIGHT", 0, -14)
	k.rule:SetHeight(1)
	k.rule:SetColorTexture(1, 1, 1, 1)
	-- quiet: a list's own name under its section's: dim, no rule.
	function k:Say(word, aside, quiet)
		self.text:SetText(word:upper())
		self.aside:SetText(aside or "")
		UI.Ink(self.text, quiet and C.dim or C.text)
		self.rule:SetShown(not quiet)
		local e = C.border
		self.rule:SetGradient("HORIZONTAL", CreateColor(e[1], e[2], e[3], 1), CreateColor(e[1], e[2], e[3], 0))
	end
	return k
end

-- Lays a section's name down the page at y; returns y under it.
local function Kick(y, width, word, aside, quiet)
	local k = Take(own.kicks, Kicker, own.body.content)
	k:ClearAllPoints()
	k:SetPoint("TOPLEFT", 0, -y)
	k:SetWidth(width)
	k:Say(word, aside, quiet)
	return y + (quiet and L.sub or L.kick)
end

local function Note(y, width, words, color, indent)
	local note = Take(own.notes, function(parent)
		local text = UI.Text(parent, "", 11, false, C.dim)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(true)
		return text
	end, own.body.content)
	note:ClearAllPoints()
	note:SetPoint("TOPLEFT", 2 + (indent or 0), -y)
	note:SetWidth(width - 4 - (indent or 0))
	note:SetText(words)
	UI.Ink(note, color or C.dim)
	return y + math.max(L.note, (note:GetStringHeight() or 0) + 5)
end

-- A key of the family's make with words on it, `tall`: a way back wears the caret before them, turned to point
-- back; quiet, it shows its plate only under the mouse (a second thing to do beside the one that matters).
local function Key(parent, words, onClick, tall, back, quiet)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(tall)
	b.text = UI.Text(b, "", 11, true, C.head)
	local glyphs
	if back then
		b.glyph = b:CreateTexture(nil, "OVERLAY")
		b.glyph:SetSize(L.glyph, L.glyph)
		b.glyph:SetPoint("LEFT", 7, 0)
		-- (The family's caret, drawn pointing down: turned to point back.)
		b.glyph:SetTexture(Shy.Skin.GLYPH.caret)
		b.glyph:SetRotation(-math.pi / 2)
		b.text:SetPoint("LEFT", b.glyph, "RIGHT", 5, 0)
		glyphs = { b.glyph }
	else
		b.text:SetPoint("LEFT", 8, 0)
	end
	UI.KeyPress(b, { words = b.text, glyphs = glyphs, sink = back and { b.text, b.glyph } or { b.text } })
	b:SetRest(C.head)   -- (the arrow as plain as the words it leads)
	if quiet then b:SetBare(true) end
	function b:Say(said)
		self.text:SetText(said)
		self:SetWidth((back and 7 + L.glyph + 5 or 8) + math.ceil(self.text:GetStringWidth()) + (back and 9 or 8))
	end
	b:Say(words)
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(self)
	end)
	return b
end

-- A key with the caret alone, turned: back (-1: the way back, the boss before) or on (1: the boss after).
local function Step(parent, way, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(L.key, L.key)
	b.glyph = b:CreateTexture(nil, "OVERLAY")
	b.glyph:SetSize(L.glyph, L.glyph)
	b.glyph:SetPoint("CENTER")
	b.glyph:SetTexture(Shy.Skin.GLYPH.caret)
	b.glyph:SetRotation(way < 0 and -math.pi / 2 or math.pi / 2)
	UI.KeyPress(b, { glyphs = { b.glyph }, sink = { b.glyph } })
	b:SetRest(C.head)
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick()
	end)
	return b
end

-- A crumb, as the map's: a split button, its words where you are bright, those above it dim, the hover color
-- while a click on them would go there.
local function Crumb(parent)
	local b
	b = UI.SplitButton(parent, { font = UI.NameFont(L.crumb), height = L.crumbTall, inset = 9, caretY = 1,
		write = function(root) if b.write then b.write(root) end end })
	local look = b.OnLook
	function b:OnLook(s)
		look(self, s)
		local color = self.rest or C.dim
		if s.on then
			color = C.text
		elseif s.over and not (s.tail and self.act) then
			color = C.hot
		end
		UI.Ink(self.text, color)
	end
	-- here: where you are (bright, its words no way anywhere); go: where a click on its words goes; write: its menu.
	function b:Fill(label, here, go, write)
		self.rest = here and C.text or C.dim
		self.write = write
		self:SetAction(not here and go or nil)
		self:SetChoices(write ~= nil)
		self:SetLabel(label)
		self:OnLook(self.shyPress)
	end
	return b
end

-- Turns to a page of the dungeon open; a boss's page turns the place to the floor it stands on.
local function Turn(page)
	state.page = page
	if type(page) == "number" then state.floor = Floors.FloorOf(state.map, page) or state.floor end
end

---------------------------------------------------------------------------
-- Every dungeon
---------------------------------------------------------------------------
-- The dungeon of an instance that is several (Scarlet Monastery's four), by the floor shown: its record
-- (Floors.Wings), or nil for an instance that is one dungeon.
local function Wing()
	local wings = state.map and Floors.Wings(state.map)
	local all = wings and Floors.Of(state.map)
	local floor = all and all[state.floor or 1]
	return floor and floor.wing and wings[floor.wing] or nil
end

-- Every dungeon there is a card for: an instance the Group Finder lists as several is each of those, under the
-- game's own short name for it, with its own levels (the rest of it the instance's).
local function Listed()
	if own.listed then return own.listed end
	local out = {}
	for _, one in ipairs(J.List()) do
		local wings = Floors.Wings(one.map)
		for _, wing in ipairs(wings or NONE) do
			out[#out + 1] = setmetatable({ name = wing.short, low = wing.low, high = wing.high, wing = wing.index,
				key = one.map .. ":" .. wing.index }, { __index = one })
		end
		if not wings then out[#out + 1] = one end
	end
	own.listed = out
	return out
end

local function CardWords(one)
	local bosses = #J.Book(one.map).bosses
	if one.wing then bosses = #Floors.Wings(one.map)[one.wing].bosses end
	local words = ("%s  \194\183  %s"):format(Shy.Instances.Levels(one), Count(bosses, "boss", "bosses"))
	if one.kind == "raid" and one.players > 0 then words = words .. ("  \194\183  %d players"):format(one.players) end
	return words
end

local function AtLevel(one)
	local level = UnitLevel("player")
	return level >= one.low and (one.high == 0 or level <= one.high)
end

local function Card(one)
	local card = own.cards[one.key or one.map]
	if card then return card end
	card = Shy.Instances.Card(own.gallery.content, L.card, one)
	card:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Journal.Open(one.map, nil, one.wing)
	end)
	card:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
	end)
	card:SetScript("OnLeave", function(self)
		self.hover = false
		UI.SetBorder(self, self.on and C.hot or C.border)
	end)
	own.cards[one.key or one.map] = card
	return card
end

local function Result(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(L.result)
	Journal.Line(row)
	row.name = UI.Text(row, "", 12, false, C.head)
	row.name:SetPoint("TOPLEFT", 10, -3)
	row.under = UI.Text(row, "", 10, false, C.dim)
	row.under:SetPoint("BOTTOMLEFT", 10, 3)
	row:SetScript("OnEnter", function(self) self:Glow(true) end)
	row:SetScript("OnLeave", function(self) self:Glow(false) end)
	row:SetScript("OnClick", function(self)
		state.query = ""
		own.search:Refresh()
		Journal.Open(self.found.map, self.found.boss)
	end)
	return row
end

local function FillGallery(width)
	local content = own.gallery.content
	Rest(own.results)
	Rest(own.captions)
	for _, card in pairs(own.cards) do card:Hide() end
	local y = 0
	if state.query ~= "" then
		local found = J.Search(state.query)
		for _, each in ipairs(found) do
			local row = Take(own.results, Result, content)
			row.found = each
			row.name:SetText(each.name)
			row.under:SetText(each.under)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetWidth(width)
			y = y + L.result + 2
		end
		own.empty:SetText(#found == 0 and "No dungeon or boss by that name." or "")
	else
		own.empty:SetText("")
		local per = math.max(1, math.floor((width + L.cardGap) / (L.card + L.cardGap)))
		local cardW = math.floor((width - (per - 1) * L.cardGap) / per)
		local cardH = math.floor(cardW / 2 + 0.5)
		for _, kind in ipairs({ { "dungeon", "Dungeons" }, { "raid", "Raids" } }) do
			local of = {}
			for _, one in ipairs(Listed()) do
				if one.kind == kind[1] then of[#of + 1] = one end
			end
			if #of > 0 then
				local caption = Take(own.captions, Kicker, content)
				caption:ClearAllPoints()
				caption:SetPoint("TOPLEFT", 0, -y)
				caption:SetWidth(width)
				caption:Say(kind[2], tostring(#of))
				y = y + L.caption
				for i, one in ipairs(of) do
					local card = Card(one)
					card:SetSize(cardW, cardH)
					card:ClearAllPoints()
					card:SetPoint("TOPLEFT", ((i - 1) % per) * (cardW + L.cardGap), -y - math.floor((i - 1) / per) * (cardH + L.cardGap))
					card:Say(CardWords(one))
					-- (In color at your level; no tick: nothing here is chosen.)
					card:Lit(AtLevel(one), false, false)
					card:Show()
				end
				y = y + math.ceil(#of / per) * (cardH + L.cardGap) + L.gap
			end
		end
	end
	content:SetHeight(math.max(1, y))
	own.gallery:Update()
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------
-- A page's name, as its crumb says it.
local function PageName(book, page)
	if type(page) == "number" then return book.bosses[page].name end
	return PAGES[page] and (PAGES[page].short or PAGES[page][1]) or "Overview"
end

-- The dungeon's crumb's menu: the dungeons at your level, and the way to every one.
local function WriteDungeons(root)
	local any = false
	for _, one in ipairs(Listed()) do
		if one.kind == "dungeon" and AtLevel(one) then
			if not any then root:CreateTitle("At your level") end
			any = true
			root:CreateRadio(("%s  %s"):format(one.name, Shy.Instances.Levels(one)), function()
				local wing = Wing()
				return state.map == one.map and (one.wing == nil or (wing ~= nil and wing.index == one.wing))
			end, function()
				Journal.Open(one.map, nil, one.wing)
			end)
		end
	end
	if any then root:CreateDivider() end
	root:CreateButton("All dungeons", function() Journal.Open() end)
end

-- The page's crumb's menu: every page of the dungeon open.
local function WritePages(root)
	local book = state.map and J.Book(state.map)
	if not book then return end
	local function Row(page, label)
		root:CreateRadio(label, function() return state.page == page end, function() Journal.Page(page) end)
	end
	Row("overview", "Overview")
	root:CreateDivider()
	for step, index in ipairs(J.Order(state.map)) do Row(index, ("%d  %s"):format(step, book.bosses[index].name)) end
	local rest = #J.Loot(state.map, "trash") + #J.Others(state.map)
	local quests = #Quests(state.map)
	if rest > 0 or quests > 0 then root:CreateDivider() end
	if rest > 0 then Row("trash", "The rest") end
	if quests > 0 then Row("quests", "Quests") end
	if #J.Sets(state.map) > 0 then Row("sets", "Sets") end
	if Run.Of(state.map) or #Run.History(state.map) > 0 then Row("runs", "Your runs") end
end

local function FillBar(width, book)
	local bar = own.bar
	bar:SetSize(width, L.bar)
	local x = own.barX or L.pad
	if own.switch then
		own.switch:ClearAllPoints()
		own.switch:SetPoint("LEFT", bar, "LEFT", x, 0)
		x = x + own.switch:GetWidth() + L.pad
	end
	-- The crumbs: every dungeon, the one open, its page.
	local chain = { own.root }
	own.root:Fill("All dungeons", book == nil, function() Journal.Open() end)
	if book then
		local overview = state.page == "overview"
		own.crumbs[1]:Fill(book.one.name, overview, function() Journal.Page("overview") end, WriteDungeons)
		chain[2] = own.crumbs[1]
		if not overview then
			own.crumbs[2]:Fill(PageName(book, state.page), true, nil, WritePages)
			chain[3] = own.crumbs[2]
		end
	end
	local function Wide(from)
		local total = 0
		for i = from, #chain do total = total + (i > from and L.slash or 0) + chain[i]:GetWidth() end
		return total
	end
	-- Short of room, the search gives some of its own; then the first crumb goes (the switch's half goes there too).
	local search = L.search
	local room = width - x - 2 * L.pad
	if Wide(1) > room - search then search = math.max(L.searchLeast, room - Wide(1)) end
	local first = (#chain > 1 and Wide(1) > room - search) and 2 or 1
	own.search:SetWidth(search)
	own.search.box:SetWidth(search)
	own.search:ClearAllPoints()
	own.search:SetPoint("RIGHT", bar, "RIGHT", -L.pad, 0)
	for _, crumb in ipairs({ own.root, own.crumbs[1], own.crumbs[2] }) do crumb:Hide() end
	for _, slash in ipairs(own.slashes) do slash:Hide() end
	for i = first, #chain do
		if i > first then
			local slash = own.slashes[i - 1]
			slash:ClearAllPoints()
			slash:SetPoint("CENTER", bar, "LEFT", x + L.slash / 2 + 1, 0)
			slash:Show()
			x = x + L.slash
		end
		chain[i]:ClearAllPoints()
		chain[i]:SetPoint("LEFT", bar, "LEFT", x, 0)
		chain[i]:Show()
		x = x + chain[i]:GetWidth()
	end
end

---------------------------------------------------------------------------
-- A dungeon: the place, the band, the keys
---------------------------------------------------------------------------
-- The floors' choice, a set for each count of floors: "Floor 1", or the number alone where the place is too
-- narrow for the words beside the way out (`room`). A dungeon whose floors go by more than their numbers (its
-- ground and what lies under it, its places by their zones) has a set of its own.
local function FloorChoice(map, count, room)
	local named = Floors.Named(map)
	local function Set(key, short)
		local choice = own.floors[key]
		if not choice then
			local labels = {}
			for i = 1, count do labels[i] = Floors.Label(map, i, short) end
			choice = UI.Segments(own.corners, labels, function(i)
				if state.floor == i then return end
				state.floor = i
				Fill()
			end, { height = L.choice })
			own.floors[key] = choice
		end
		return choice
	end
	local choice = Set(named and ("of " .. map) or count, false)
	if choice:GetWidth() > room then choice = Set(count .. " short", true) end
	return choice
end

local function FillPlace(width, height)
	local map = state.map
	local boss = type(state.page) == "number" and state.page or nil
	local floors = Floors.Of(map)
	local door = Journal.Door(map)
	local pane = own.place
	pane:ClearAllPoints()
	pane:SetPoint("TOPLEFT", own.main, "TOPLEFT", L.gap, -L.gap)
	pane.width, pane.height = width, height
	-- (What stands in its corners has the foot of it to itself: the whole floor is fitted over them.)
	local corners = (door and door.name) or (floors and #floors > 1)
	pane:Open(map, state.floor or 1, {
		picked = boss, door = door and door.name,
		clear = corners and L.corner + L.cornerIn or 0,
		tones = own.tones,
		done = Run.Of(map) and Run.Of(map).kills or nil, next = Run.Next(map),
		room = Journal.Room(map), others = Journal.Others(map),
		onHover = function(index, on) Hover(index, on, true) end,
		-- (A way onto another floor, clicked where it is on this one.)
		onFloor = function(floor)
			state.floor = floor
			Fill()
		end,
		onBoss = function(index)
			Turn(index)
			Fill()
		end,
		onDoor = door and Journal.Out or nil,
		onOut = Journal.Up,
	})
	if floors then state.floor = pane.floor end
	if boss then pane:Focus(boss) end
	-- Its corners, over it: the way out to its zone, and the floors where it has more than one.
	own.corners:ClearAllPoints()
	own.corners:SetAllPoints(pane)
	local inset = L.cornerIn + 6
	local taken = 0
	own.out:SetShown(door ~= nil and door.name ~= nil)
	if door and door.name then
		own.out:Say(door.name)
		own.out:ClearAllPoints()
		own.out:SetPoint("BOTTOMLEFT", own.corners, "BOTTOMLEFT", inset, inset)
		taken = own.out:GetWidth() + 10
	end
	for _, choice in pairs(own.floors) do choice:Hide() end
	if floors and #floors > 1 then
		local choice = FloorChoice(map, #floors, width - 2 * inset - taken)
		choice:ClearAllPoints()
		choice:SetPoint("BOTTOMRIGHT", own.corners, "BOTTOMRIGHT", -inset, inset)
		choice:Select(pane.floor)
		choice:Show()
	end
end

-- The band's name: at its size where it has the room, a size down where it hasn't.
local function Title(band, words, x, y, room)
	band.title:SetText(words)
	local small = (band.title:GetStringWidth() or 0) > room
	band.title:SetShown(not small)
	band.lesser:SetShown(small)
	local text = small and band.lesser or band.title
	text:SetText(words)
	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", x, -(small and y + 2 or y))
	text:SetWidth(room)
end

-- The band, three close lines: the way back before the name; where it is (or which boss); what there is to know.
local function FillBand(width, tall, book)
	local band = own.band
	local one = book.one
	local page = state.page
	local boss = type(page) == "number" and book.bosses[page] or nil
	band:SetSize(width, tall)
	-- The picture: its 2:1 cut cut down again to the band's shape, a little above its middle; dark behind a boss.
	if one.file > 0 and one.cut then
		local l, t, r, b = one.cut[1], one.cut[2], one.cut[3], one.cut[4]
		local down = math.min(1, 2 / (width / tall))
		local top = t + (b - t) * (1 - down) * 0.4
		local shade = boss and 0.5 or 1
		band.art:SetTexture(one.file)
		band.art:SetTexCoord(l, r, top, top + (b - t) * down)
		band.art:SetVertexColor(shade, shade, shade, 1)
	end
	-- (One this build has no picture of: a plain plate.)
	band.art:SetShown(one.file > 0 and one.cut ~= nil)
	band.plain:SetShown(not band.art:IsShown())
	-- Its foot melts into the page: the page's own ground, coming up from nothing.
	local ground = C.bg
	band.fade:SetGradient("VERTICAL", CreateColor(ground[1], ground[2], ground[3], 0.85), CreateColor(ground[1], ground[2], ground[3], 0))

	Rest(own.pills)
	local x = 8
	local function Pill(text, color)
		local pill = Take(own.pills, UI.Badge, band.over)
		pill:Set({ text = text, color = color })
		-- (What has no room left on the band's foot is left off: the least telling come last.)
		if x + pill:GetWidth() > width - 8 then
			pill:Hide()
			return
		end
		pill:ClearAllPoints()
		pill:SetPoint("BOTTOMLEFT", x, 6)
		x = x + pill:GetWidth() + L.pillGap
		return pill
	end
	own.clock = nil

	local words = 8 + L.key + 6      -- where the name begins, after the way back
	band.where:Hide()
	band.rest:SetText("")
	band.prev:SetShown(boss ~= nil)
	band.next:SetShown(boss ~= nil)
	band.sub:ClearAllPoints()
	if boss then
		-- Its stage: the creature whole at the left under the way back, its name beside it, the bosses before and
		-- after at the right.
		local staged = band.stage:Set(J.Look(state.map, page))
		if staged then
			local model = math.min(tall, math.floor(width * L.model))
			band.stage:SetSize(model, tall)
			words = math.max(words, model + 6)
		end
		x = words
		Title(band, boss.name, words, 7, width - words - 8 - 2 * L.key - 6)
		local floor, all = Floors.FloorOf(state.map, page), Floors.Of(state.map)
		local step = J.Step(state.map, page)
		local said = ("Boss %d of %d"):format(step, #book.bosses)
		-- (Which floor: by its name where its floors have names, a wing's or a place's.)
		if floor and all and #all > 1 then
			said = said .. "  \194\183  " .. (Floors.Named(state.map) and Floors.Label(state.map, floor)
				or ("floor %d of %d"):format(floor, #all))
		end
		band.sub:SetText(said)
		band.sub:SetPoint("TOPLEFT", words, -30)
		band.prev:SetAlpha(step > 1 and 1 or 0.35)
		band.prev:SetEnabled(step > 1)
		band.next:SetAlpha(step < #book.bosses and 1 or 0.35)
		band.next:SetEnabled(step < #book.bosses)
		local _, has, color = Has(J.Loot(state.map, page), boss.npc > 0 and Needed(state.map)[boss.npc])
		Pill(has, color)
		return
	end
	band.stage:Set(nil)
	local kind = one.kind == "raid" and "Raid" or "Dungeon"
	local named = PAGES[page]
	-- (An instance that is several dungeons: the one shown, by name, with its own levels and bosses.)
	local wing = Wing()
	Title(band, named and named[1] or (wing and ("%s: %s"):format(one.name, wing.name)) or one.name, words, 7, width - words - 8)
	band.sub:SetPoint("TOPLEFT", 8, -30)
	if page == "quests" then
		local quests = Quests(state.map)
		band.sub:SetText(("%s  \194\183  %d of %d handed in"):format(one.name, Handed(quests), #quests))
	elseif named then
		band.sub:SetText(one.name .. "  \194\183  " .. named[2])
	else
		-- Where it is: its zone a way out of the door, where something knows the door.
		local door = Journal.Door(state.map)
		local players = one.players > 0 and ("%d players"):format(one.players) or nil
		if door and door.name then
			band.sub:SetText(kind .. " in")
			band.where:Say(door.name)
			band.where:ClearAllPoints()
			band.where:SetPoint("LEFT", band.sub, "RIGHT", 0, 0)
			band.where:Show()
			band.rest:SetText(players and ("\194\183  " .. players) or "")
		else
			band.sub:SetText(players and (kind .. "  \194\183  " .. players) or kind)
		end
		-- What there is to know at a glance, as pills along the band's foot: the run you are on first.
		local run = Run.Of(state.map)
		if run and not run.ended then
			local down = 0
			for _ in pairs(run.kills) do down = down + 1 end
			local of = #Run.Bosses(state.map)
			local function Words()
				return ("Run %s  \194\183  %d of %d"):format(Run.Time(Run.Clock(state.map)), down, of)
			end
			-- (Its clock runs on the pill alone: the page is not laid again for a second gone by.)
			own.clock = Pill(Words(), Shy.Theme.Accent)
			if own.clock then own.clock.words = Words end
			if not own.ticker then
				own.ticker = C_Timer.NewTicker(1, function()
					local pill = own.clock
					local live = Run.Of(state.map)
					if pill and pill:IsVisible() and live and not live.ended then
						pill:Set({ text = pill.words(), color = Shy.Theme.Accent })
					end
				end)
			end
		end
		local levels, hue = ns.Levels(wing and wing.low or one.low, wing and wing.high or one.high, true)
		if levels then Pill(levels, { hue.r, hue.g, hue.b }) end
		-- (ShyQuest's run of its quests, while it is on: which part of it you are at.)
		local questing = Quest()
		if questing and questing:Running() == state.map then
			local plan = questing:DungeonPlan(state.map)
			Pill(plan and plan.phase and ("Quests: " .. plan.phase:lower()) or "On its quests", Shy.Theme.Accent)
		end
		-- (On a run the count of its bosses is on the run's own pill.)
		if not (run and not run.ended) then Pill(Count(wing and #wing.bosses or #book.bosses, "boss", "bosses"), C.text) end
		local quests = Quests(state.map)
		if #quests > 0 then
			local done = Handed(quests)
			Pill(("%d of %d quests"):format(done, #quests), done == #quests and C.good or C.alert)
		end
		local upgrades = 0
		for index = 1, #book.bosses do upgrades = upgrades + Upgrades(J.Loot(state.map, index)) end
		if upgrades > 0 then Pill(Count(upgrades, "upgrade for you", "upgrades for you"), C.good) end
		local starred = #J.WantedIn(state.map)
		if starred > 0 then Pill(Count(starred, "starred drop", "starred drops"), C.alert) end
	end
end

-- The keys under the column, from its right: the one that matters filled, the others quiet. Returns the room
-- they take (none where no addon they work through is here).
local function FillFoot(width)
	local quest = Quest()
	local quests = Quests(state.map)
	local running = quest and quest.Running and quest:Running() == state.map
	local at, any = -6, false
	local function Stand(key, on, label)
		key:SetShown(on)
		if not on then return end
		any = true
		if label then key:Say(label) end
		key:ClearAllPoints()
		key:SetPoint("RIGHT", own.foot, "RIGHT", at, 0)
		at = at - key:GetWidth() - L.keyGap
	end
	Stand(own.run, #quests > 0, running and "Back to my guide" or "Get its quests")
	own.run:SetPrimary(#quests > 0 and not running)
	Stand(own.lead, quest ~= nil and quest.Go ~= nil and Journal.Door(state.map) ~= nil)
	Stand(own.group, Shy.addons.Group ~= nil)
	own.foot:SetShown(any)
	own.foot:SetSize(width, L.foot)
	return any and L.foot or 0
end

---------------------------------------------------------------------------
-- The dungeon's list
---------------------------------------------------------------------------
-- The mouse on a boss, on its line of the list or on its mark on the floor (`there`): both light.
Hover = function(key, on, there)
	local row = own.byKey[key]
	if row and row:IsShown() then
		row:Glow(on)
		row:Paint(on)
	end
	if not there and type(key) == "number" then own.place:Hover(on and key or nil) end
end

-- A drop's picture at a line's end: its own hover, the line's click.
local function RowIcon(row, i)
	local b = row.icons[i]
	if b then return b end
	b = CreateFrame("Button", nil, row)
	b:SetSize(L.icon, L.icon)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.slot = Shy.Slot.New(b, { to = b.icon, icon = b.icon, hover = false })
	b:SetScript("OnEnter", function(self)
		Hover(row.key, true)
		-- (Off the line's corner, as a drop's row: clear of the line both ways.)
		UI.GameTipAt(row):SetItemByID(self.item)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function()
		Hover(row.key, false)
		GameTooltip:Hide()
	end)
	b:SetScript("OnClick", function() row:Click() end)
	row.icons[i] = b
	return b
end

-- A line of the list: a boss's mark as the floor wears it, the family's, its number on it, in the color of what
-- it has for you and lit under the mouse (a glyph for the rest and the quests); its name; and at the line's end
-- what it has for you: the drops themselves, then a few words.
local function ListRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(L.row)
	Journal.Line(row)
	row.badge = Shy.Maps.Mark(row, L.mark)
	row.badge:SetPoint("LEFT", 3, 0)
	row.num = row.badge:CreateFontString(nil, "OVERLAY")
	row.num:SetFont(Shy.FONT_ROUNDED, 11, "")
	row.num:SetPoint("CENTER", 0, 0)
	-- (Down this run: a tick where its number was. The next one standing: a word after its name.)
	row.tick = row.badge:CreateTexture(nil, "OVERLAY")
	row.tick:SetSize(10, 10)
	row.tick:SetPoint("CENTER")
	row.tick:SetTexture(Shy.Skin.GLYPH.tick)
	row.tick:Hide()
	function row:Paint(lit)
		if type(self.key) ~= "number" then return end
		local tone = self.tone or Floors.STEEL
		self.badge:Set(nil, tone, lit == true)
		UI.Ink(self.num, lit and Floors.GRAPHITE or tone)
		UI.Tint(self.tick, lit and Floors.GRAPHITE or tone)
	end
	row.glyph = row:CreateTexture(nil, "OVERLAY")
	row.glyph:SetPoint("CENTER", row, "LEFT", 3 + L.mark / 2, 0)
	row.name = UI.Text(row, "", 12, true, C.head)
	row.name:SetPoint("LEFT", 3 + L.mark + 8, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.tag = UI.Text(row, "NEXT", 9, true, C.head)
	row.tag:Hide()
	row.says = UI.Text(row, "", 11, false, C.dim)
	row.says:SetPoint("RIGHT", -8, 0)
	row.says:SetJustifyH("RIGHT")
	row.says:SetWordWrap(false)
	row.icons = {}
	row:SetScript("OnEnter", function(self) Hover(self.key, true) end)
	row:SetScript("OnLeave", function(self) Hover(self.key, false) end)
	row:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Turn(self.key)
		Fill()
	end)
	return row
end

-- Lays a line at y: key (the page it opens), its number or glyph, its name, what it says and in which color,
-- and the drops to picture. Returns y under it.
local function Line(y, width, key, glyph, name, says, color, items)
	local row = Take(own.rows, ListRow, own.body.content)
	row.key = key
	own.byKey[key] = row
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -y)
	row:SetWidth(width)
	local number = type(key) == "number"
	row.badge:SetShown(number)
	row.glyph:SetShown(not number)
	row:Glow(false)
	local down = number and Run.Killed(state.map, key)
	local upNext = number and Run.Next(state.map) == key
	row.tick:SetShown(down == true)
	row.tag:SetShown(upNext == true)
	UI.Ink(row.tag, Shy.Theme.Accent)
	UI.Ink(row.name, down and C.dim or C.head)
	if number then
		-- (Its mark in the color of what it has for you; a plain one for a count of drops.)
		row.tone = own.tones[key]
		row.num:SetText(down and "" or J.Step(state.map, key))
		row:Paint(false)
	else
		UI.GlyphArt(row.glyph, glyph)
		UI.Tint(row.glyph, C.dim)
	end
	row.name:SetText(name)
	row.says:SetText(says)
	UI.Ink(row.says, color or C.dim)
	-- From the right: the words, then the drops, the best nearest the words' side of the name.
	local taken = 8 + math.ceil(row.says:GetStringWidth())
	local shown = math.min(L.icons, #(items or NONE))
	for i = 1, shown do
		local b = RowIcon(row, i)
		local item = items[shown - i + 1]
		b.item = item
		b.icon:SetTexture(C_Item.GetItemIconByID(item))
		local _, _, quality = C_Item.GetItemInfo(item)
		b.slot:Quality(quality)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", row, "RIGHT", -(taken + 8 + (i - 1) * (L.icon + L.iconGap)), 0)
		b:Show()
	end
	for i = shown + 1, #row.icons do row.icons[i]:Hide() end
	if shown > 0 then taken = taken + 8 + shown * (L.icon + L.iconGap) - L.iconGap end
	local room = math.max(40, width - (3 + L.mark + 8) - taken - 8 - (upNext and row.tag:GetStringWidth() + 8 or 0))
	row.name:SetWidth(room)
	if upNext then
		row.tag:ClearAllPoints()
		row.tag:SetPoint("LEFT", row.name, "LEFT", math.min(room, row.name:GetStringWidth()) + 8, 0)
	end
	return y + L.row + L.rowGap
end

function Journal.Row(key)
	local row = own.byKey[key]
	return row and row:IsShown() and row or nil
end

-- The dungeon's pages down the column: each boss in the game's order, the rest of the dungeon, its quests.
local function List(y, width)
	local map = state.map
	local book = J.Book(map)
	local wings = Floors.Wings(map)
	if wings then
		-- An instance that is several dungeons: each under its name and its levels, its bosses under it; then
		-- those nothing places in any.
		local listed = {}
		for _, wing in ipairs(wings) do
			y = Kick(y + (wing.index > 1 and 6 or 0), width, wing.name, (ns.Levels(wing.low, wing.high, true))) + 2
			for _, index in ipairs(J.Order(map)) do
				if Floors.WingOf(map, index) == wing.index then
					local has = own.has[index]
					y = Line(y, width, index, nil, book.bosses[index].name, has[2], has[3], has[1])
					listed[index] = true
				end
			end
		end
		local rest = {}
		for index in ipairs(book.bosses) do
			if not listed[index] then rest[#rest + 1] = index end
		end
		if #rest > 0 then y = Kick(y + 6, width, "Bosses", tostring(#rest)) + 2 end
		for _, index in ipairs(rest) do
			local has = own.has[index]
			y = Line(y, width, index, nil, book.bosses[index].name, has[2], has[3], has[1])
		end
	else
		y = Kick(y, width, "Bosses", tostring(#book.bosses)) + 2
		-- (In the order they are met, each wearing its place in it.)
		for _, index in ipairs(J.Order(map)) do
			local has = own.has[index]
			y = Line(y, width, index, nil, book.bosses[index].name, has[2], has[3], has[1])
		end
	end
	local trash = J.Loot(map, "trash")
	local rest = #trash
	for _, other in ipairs(J.Others(map)) do rest = rest + #other.loot end
	local quests = Quests(map)
	if rest > 0 or #quests > 0 then y = Kick(y + 8, width, "Also") + 2 end
	if rest > 0 then
		local items, says, color = Has(trash, false)
		if says == "No drops yet" or color == C.dim then says = Count(rest, "drop", "drops") end
		y = Line(y, width, "trash", "loot", "The rest", says, color, items)
	end
	if #quests > 0 then
		local done = Handed(quests)
		y = Line(y, width, "quests", "book", "Quests", ("%d of %d handed in"):format(done, #quests), done == #quests and C.good or C.alert)
	end
	-- The item sets a piece of which drops here.
	local sets = J.Sets(map)
	if #sets > 0 then
		if rest == 0 and #quests == 0 then y = Kick(y + 8, width, "Also") + 2 end
		local pieces = 0
		for _, one in ipairs(sets) do pieces = pieces + #one.here end
		y = Line(y, width, "sets", "star", "Sets", ("%s here of %s"):format(Count(pieces, "piece", "pieces"), Count(#sets, "set", "sets")))
	end
	-- Your runs here: the one you are on, and those before it.
	local run, kept = Run.Of(map), Run.History(map)
	if run or #kept > 0 then
		if rest == 0 and #quests == 0 and #sets == 0 then y = Kick(y + 8, width, "Also") + 2 end
		local best = Run.Best(map)
		local says = run and not run.ended and ("On it for " .. Run.Time(Run.Clock(map)))
			or (best and ("%s  \194\183  best %s"):format(Count(#kept, "run", "runs"), Run.Time(best)))
			or Count(#kept, "run", "runs")
		y = Line(y, width, "runs", "clock", "Your runs", says, run and not run.ended and Shy.Theme.Accent or C.dim)
	end
	return y + 6
end

---------------------------------------------------------------------------
-- The pages
---------------------------------------------------------------------------
-- What "For me" left out of a list, said under it: how many, and what shows them.
local function Hidden(y, width, left)
	if left == 0 then return y end
	return Note(y, width, left == 1 and "1 drop that isn't an upgrade for you is hidden. Everything shows it."
		or ("%d drops that aren't upgrades for you are hidden. Everything shows them."):format(left)) + 4
end

-- The drops' section: its name with the list's two choices at its right, then a list for each count (this
-- game's, then Classic's), each under its own quiet name. `none`: what to say of a list with nothing in it.
-- Returns y under it.
local function LootSections(y, width, rows, none)
	if own.choices then
		own.choices:ClearAllPoints()
		own.choices:SetPoint("TOPRIGHT", own.body.content, "TOPLEFT", width, -y + 4)
		own.choices:Refresh()
		own.choices:Show()
	end
	y = Kick(y, own.choices and width - own.choices:GetWidth() - 8 or width, "Drops") + 3
	if #rows == 0 then return Note(y, width, none) + 6 end
	local picked, left = Loot.Pick(rows)
	if #picked == 0 then
		-- (Every one of them left out: the section still stands, saying why it is empty.)
		return Note(y, width, left == 1 and "Its one drop isn't an upgrade for you. Everything shows it."
			or ("None of its %d drops is an upgrade for you. Everything shows them."):format(left)) + 6
	end
	for _, part in ipairs(Loot.BySource(picked)) do
		local word, aside
		if part.key == "here" then
			word = "In this game"
			aside = part.kills > 0 and ("counted over %s"):format(Count(part.kills, "kill", "kills")) or "seen by players here"
		else
			word, aside = "In Classic", "may differ in this game"
		end
		y = Loot.Lay(own.body.content, Kick(y, width, word, aside, true), width, part.rows) + 6
	end
	return Hidden(y, width, left)
end

-- What Classic asked of you at the door, each said with how you stand to it: the level, the item to carry, the
-- quest to have done. Returns y under it (y itself where nothing was asked).
local function Asked(y, width)
	local asked = ns.data.dungeonEnter and ns.data.dungeonEnter[state.map]
	local level, item, quest = (asked or ""):match("^(%d+):(%d+):(%d+)$")
	level, item, quest = tonumber(level) or 0, tonumber(item) or 0, tonumber(quest) or 0
	if level == 0 and item == 0 and quest == 0 then return y end
	-- (A level you have long had, and nothing else asked: nothing worth a section.)
	if item == 0 and quest == 0 and UnitLevel("player") >= level then return y end
	y = Kick(y, width, "To get in", "as Classic had it") + 2
	if level > 0 then
		y = Note(y, width, ("Level %d"):format(level), UnitLevel("player") >= level and C.good or C.alert)
	end
	if item > 0 then
		local name = C_Item.GetItemNameByID(item)
		if not name then C_Item.RequestLoadItemDataByID(item) end
		local have = C_Item.GetItemCount(item, true) > 0
		y = Note(y, width, ("%s, carried%s"):format(name or "An item", have and ": you have it" or ""), have and C.good or C.alert)
	end
	if quest > 0 then
		local name = C_QuestLog.GetTitleForQuestID(quest)
		local done = C_QuestLog.IsQuestFlaggedCompleted(quest)
		y = Note(y, width, ("%s, done%s"):format(name and ("\"" .. name .. "\"") or "A quest", done and ": you have" or ""),
			done and C.good or C.alert)
	end
	return y + 8
end

local function Overview(y, width)
	local map = state.map
	local book = J.Book(map)
	y = List(y, width)
	y = Asked(y, width)
	local wants = {}
	for _, want in ipairs(J.WantedIn(map)) do
		for _, row in ipairs(J.Loot(map, want.index or "trash")) do
			if row.item == want.item then
				-- (One you have already: said on its row, the star still yours to take off.)
				if C_Item.GetItemCount(row.item, true) > 0 then row = setmetatable({ note = "You have it" }, { __index = row }) end
				wants[#wants + 1] = row
			end
		end
	end
	if #wants > 0 then
		y = Loot.Lay(own.body.content, Kick(y, width, "Starred", Count(#wants, "drop", "drops")) + 3, width, wants) + 8
	end
	-- The recipes anything in it drops: a boss's, then the rest's.
	local recipes, listed = {}, {}
	local function Recipes(rows)
		for _, row in ipairs(rows) do
			local _, _, _, _, _, class = C_Item.GetItemInfoInstant(row.item)
			if class == Enum.ItemClass.Recipe and not listed[row.item] then
				listed[row.item] = true
				recipes[#recipes + 1] = row
			end
		end
	end
	for index = 1, #book.bosses do Recipes(J.Loot(map, index)) end
	Recipes(J.Loot(map, "trash"))
	if #recipes > 0 then
		y = Loot.Lay(own.body.content, Kick(y, width, "Recipes", Count(#recipes, "drop", "drops")) + 3, width, recipes) + 8
	end
	-- Your best upgrades anywhere in it (with ShyGear).
	if Shy.addons.Gear then
		local best, seen = {}, {}
		for index = 1, #book.bosses do
			for _, row in ipairs(J.Loot(map, index)) do
				local v = not seen[row.item] and Loot.Verdict(row.item)
				if v and v.kind == "upgrade" then
					seen[row.item] = true
					best[#best + 1] = { row = row, score = v.score or 0 }
				end
			end
		end
		table.sort(best, function(a, b) return a.score > b.score end)
		if #best > 0 then
			local rows = {}
			for i = 1, math.min(L.best, #best) do rows[i] = best[i].row end
			local aside = #best > L.best and ("the best %d of %d"):format(L.best, #best) or nil
			y = Loot.Lay(own.body.content, Kick(y, width, "Best for you", aside) + 3, width, rows) + 8
		end
	end
	return y
end

local function BossPage(y, width, index)
	local map = state.map
	local boss = J.Book(map).bosses[index]
	local spells = J.Spells(map, index)
	-- (Whose word it is: Classic's, your own fights', or both.)
	local classic, yours = false, false
	for _, row in ipairs(spells) do
		if row.seen then yours = true else classic = true end
	end
	local aside = classic and yours and "as in Classic, and seen in your fights" or yours and "seen in your fights"
		or classic and "as in Classic" or nil
	local under = Kick(y, width, "What it does", aside) + 3
	if #spells > 0 then
		y = Boss.Lay(own.body.content, under, width, spells) + 8
	else
		y = Note(under, width, boss.npc > 0 and "Nothing is known of what it does yet. It's noted as you fight it."
			or "Nothing is known of this boss yet. It shows here once you've met it, and what it casts as you fight it.") + 6
	end
	return LootSections(y, width, J.Loot(map, index), "No drops known yet. They show here once you've looted it.")
end

local function TrashPage(y, width)
	local map = state.map
	y = LootSections(y, width, J.Loot(map, "trash"), "Nothing is known of what drops anywhere in it.")
	-- Its other creatures that players saw drop something, a list each; what "For me" left out of them is
	-- said once, under the last.
	local hidden = 0
	for _, other in ipairs(J.Others(map)) do
		local picked, left = Loot.Pick(other.loot)
		hidden = hidden + left
		if #picked > 0 then
			y = Loot.Lay(own.body.content, Kick(y, width, other.name, "seen by players here", true), width, picked) + 6
		end
	end
	return Hidden(y, width, hidden)
end

-- The item sets with a piece here: each by the game's own name for it, how many of its pieces drop here, and
-- those pieces, each saying who drops it.
local function SetsPage(y, width)
	for _, one in ipairs(J.Sets(state.map)) do
		local name = C_Item.GetItemSetInfo(one.set)
		local rows = {}
		for _, piece in ipairs(one.here) do
			rows[#rows + 1] = setmetatable({ note = piece.from or "The rest" }, { __index = piece.row })
		end
		y = Kick(y, width, name or "A set", ("%d of its %d drop here"):format(#one.here, #one.pieces)) + 3
		y = Loot.Lay(own.body.content, y, width, rows) + 8
	end
	return y
end

-- Your runs here: the one you are on boss by boss (when each went down), then those before it.
local function RunsPage(y, width)
	local map = state.map
	local book = J.Book(map)
	local run = Run.Of(map)
	if run then
		local down = 0
		for _ in pairs(run.kills) do down = down + 1 end
		-- (Its bosses: every one, or those of the dungeon of the instance the run is in.)
		local of = Run.Bosses(map)
		y = Kick(y, width, run.ended and "Your last run" or "This run",
			("%s  \194\183  %d of %d down"):format(Run.Time(Run.Clock(map)), down, #of)) + 2
		for _, index in ipairs(of) do
			local at = run.kills[index]
			y = Note(y, width, ("%d  %s   %s"):format(J.Step(map, index), book.bosses[index].name, at and ("down at " .. Run.Time(at)) or "standing"),
				at and C.text or C.dim)
		end
		y = y + 8
	end
	local kept = Run.History(map)
	if #kept > 0 then
		local best = Run.Best(map)
		y = Kick(y, width, "Before", best and ("best " .. Run.Time(best)) or nil) + 2
		for _, one in ipairs(kept) do
			local whole = one.killed >= one.of
			y = Note(y, width, ("%s   %s   %d of %d"):format(date("%b %d, %H:%M", one.at), Run.Time(one.took), one.killed, one.of),
				whole and (best == one.took and C.good or C.text) or C.dim)
		end
	elseif not run then
		y = Note(y, width, "None yet. A run is kept from the moment you walk in.", C.dim)
	end
	return y
end

-- A quest's line: its level, its name, how it stands. A click leads you to whoever it is at now (who gives one
-- to pick up, who takes one in your log), where that is out in the world.
local function QuestRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(L.quest)
	Journal.Line(row)
	row.level = UI.Text(row, "", 10, false, C.dim)
	row.level:SetPoint("LEFT", 8, 0)
	row.level:SetWidth(20)
	row.level:SetJustifyH("LEFT")
	row.name = UI.Text(row, "", 12, false, C.head)
	row.name:SetPoint("LEFT", 30, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.says = UI.Text(row, "", 10, false, C.dim)
	row.says:SetPoint("RIGHT", -8, 0)
	row:SetScript("OnEnter", function(self)
		self:Glow(self.to ~= nil)
		if self.to then UI.Tip(self, self.to.name, self.where, { side = "TOP", hints = { { "left", "Lead me there" } } }) end
	end)
	row:SetScript("OnLeave", function(self)
		self:Glow(false)
		UI.TipHide(self)
	end)
	row:SetScript("OnClick", function(self)
		local quest = Shy.addons.Quest
		if not (self.to and self.to.at and quest and quest.Go) then return end
		PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
		quest:Go(self.to.at.map, self.to.at.x, self.to.at.y, self.to.name)
	end)
	return row
end

-- A count with its thousands apart: 1,350.
local function Thousands(n)
	local out = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Where someone stands, as words: "in Westfall", "inside the dungeon", or nothing where nothing says.
local function Whereabouts(who)
	if not who then return nil end
	if who.inside then return "inside the dungeon" end
	local info = who.at and C_Map.GetMapInfo(who.at.map)
	return info and info.name and ("in " .. info.name) or nil
end

-- The dungeon's quests as ShyQuest has them (its plan: Run.Plan there), in the order its run takes them: those
-- in your log with what each asks and who takes it; those to pick up with who gives each, where, and what it
-- waits on; those handed in. How the run stands is said first.
local function QuestsPage(y, width)
	local quest = Quest()
	local plan = quest and quest:DungeonPlan(state.map)
	if not plan then return y end
	local book = J.Book(state.map)
	local left = #plan.quests - Handed(plan.quests)
	if plan.running then
		y = Kick(y + L.top, width, "On its quests", plan.phase and ("now: " .. plan.phase:lower()) or nil) + 2
		y = Note(y, width, "Your card has every step, in order. The key below takes you back to your guide.", C.text) + 4
	elseif left > 0 then
		y = Note(y + L.top, width, "Get its quests puts every step on your card: what to do first, where to pick each one up, and where to hand it in.") + 4
	else
		y = y + L.top
	end
	-- A boss a quest needs, by the creature: its name and place in the order.
	local function Needs(one)
		local out = {}
		for _, creature in ipairs(one.needs or NONE) do
			for index, boss in ipairs(book.bosses) do
				if boss.npc == creature then out[#out + 1] = ("%s (boss %d)"):format(boss.name, J.Step(state.map, index)) end
			end
		end
		return #out > 0 and table.concat(out, ", ") or nil
	end
	local function Lay(one, to, where)
		local row = Take(own.quests, QuestRow, own.body.content)
		local says = STATE[one.state] or STATE.ahead
		row.level:SetText(one.level and one.level > 0 and tostring(one.level) or "")
		row.name:SetText(one.name)
		row.name:SetWidth(width - 30 - 76)
		row.says:SetText(says[1])
		UI.Ink(row.says, C[says[2]])
		UI.Ink(row.name, one.state == "done" and C.dim or C.head)
		row.to, row.where = to and to.at and to or nil, where
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -y)
		row:SetWidth(width)
		y = y + L.quest + 2
	end
	local function Section(state, word)
		local any = false
		for _, one in ipairs(plan.quests) do
			if one.state == state then
				if not any then
					any = true
					y = Kick(y + 4, width, word) + 2
				end
				if state == "carried" then
					local where = Whereabouts(one.taker)
					Lay(one, one.taker, one.taker and ("Hand it in " .. (where or "there")) or nil)
					-- What it asks, as the game words it, and which boss that is.
					for _, goal in ipairs(one.goals or NONE) do
						y = Note(y, width, goal.text, goal.done and C.good or C.text, L.under)
					end
					local needs = Needs(one)
					if needs then y = Note(y, width, "From " .. needs, C.alert, L.under) end
					if one.taker then
						y = Note(y, width, ("Hand in to %s%s"):format(one.taker.name, where and (" " .. where) or ""), C.dim, L.under)
					end
				elseif state == "ahead" then
					local where = Whereabouts(one.giver)
					Lay(one, one.giver, one.giver and ("Pick it up " .. (where or "there")) or nil)
					if one.giver then
						local xp = one.xp and one.xp > 0 and ("  \194\183  %s XP"):format(Thousands(one.xp)) or ""
						y = Note(y, width, ("From %s%s%s"):format(one.giver.name, where and (" " .. where) or "", xp), C.text, L.under)
					end
					-- What it waits on that isn't handed in yet, the first to do first.
					-- (A chain's parts often share a name: said once, with how many of them there are.)
					local first, parts = {}, {}
					for _, before in ipairs(one.first or NONE) do
						if before.state ~= "done" then
							local at = parts[before.name]
							if at then
								first[at].count = first[at].count + 1
							else
								first[#first + 1] = { name = before.name, count = 1, carried = before.state == "carried" }
								parts[before.name] = #first
							end
						end
					end
					for i, before in ipairs(first) do
						first[i] = before.name .. (before.count > 1 and (" (%d parts)"):format(before.count)
							or before.carried and " (in your log)" or "")
					end
					if #first > 0 then y = Note(y, width, "First: " .. table.concat(first, ", then "), C.alert, L.under) end
				else
					Lay(one)
				end
				-- What it pays, under it: the game's own word for one in your log, Classic's for another.
				local rewards = one.state ~= "done" and J.Rewards(one.id, one.state == "carried") or NONE
				if #rewards > 0 then y = Loot.Lay(own.body.content, y, width - L.under, rewards, L.under) + 4 end
			end
		end
	end
	Section("carried", "In your log")
	Section("ahead", "To pick up")
	Section("done", "Handed in")
	return Note(y + 6, width, "Rewards are as Classic had them until a quest is in your log; then they're the game's own.")
end

---------------------------------------------------------------------------
-- Laying it out
---------------------------------------------------------------------------
Fill = function()
	local face = own.face
	if not (face and Journal.IsOpen()) then return end
	-- (In its own window it is that window's size under its header, however it came by it.)
	if own.home == "shell" then
		local w, h = UI.BodySize(own.box)
		own.w, own.h = w, h - HEADER
	end
	face:SetSize(own.w, own.h)
	local book = state.map and J.Book(state.map)
	if book and type(state.page) == "number" and not book.bosses[state.page] then state.page = "overview" end
	-- (What the search finds stands where every dungeon does, whatever was open.)
	local open = book ~= nil and state.query == ""
	FillBar(own.w, book)
	-- Under the bar: laid at its scale, in its own units.
	local k = own.k
	local main = own.main
	local width, height = own.w / k, (own.h - L.bar) / k
	main:SetScale(k)
	main:ClearAllPoints()
	main:SetPoint("TOPLEFT", face, "TOPLEFT", 0, -L.bar / k)
	main:SetSize(width, height)
	own.gallery:SetShown(not open)
	own.empty:SetShown(not open)
	for _, piece in ipairs(own.dungeon) do piece:SetShown(open) end
	-- (The list's choices are made the first time ShyGear is there to choose by.)
	if not own.choices then
		own.choices = Loot.Bar(own.body.content, function() Fill() end)
		Journal.bar = own.choices
	end
	if own.choices then own.choices:Hide() end
	if not open then
		local inner = width - 2 * L.gap - 4
		own.gallery:SetSize(inner, height - 2 * L.gap)
		own.gallery.content:SetWidth(inner - L.scroll)
		FillGallery(inner - L.scroll)
		return
	end
	-- The place at the left, the column at the right: its band, its page, its keys.
	local tall = height - 2 * L.gap
	local col = math.max(L.col[2], math.min(L.col[3], math.floor(width * L.col[1])))
	local colW = col - L.gap
	-- What each boss has for you, once: its line says it, and its mark on the floor wears its color.
	local needed = Needed(state.map)
	wipe(own.has)
	wipe(own.tones)
	for index, boss in ipairs(book.bosses) do
		local items, says, color = Has(J.Loot(state.map, index), boss.npc > 0 and needed[boss.npc])
		own.has[index] = { items, says, color }
		own.tones[index] = color ~= C.dim and color or nil
	end
	FillPlace(width - col - 2 * L.gap, tall)
	-- The column wears the theme's housing, as the place does; inside its rim, the page: band, list, keys.
	local housing = own.col
	housing:ClearAllPoints()
	housing:SetPoint("TOPLEFT", main, "TOPLEFT", width - col, -L.gap)
	housing:SetSize(colW, tall)
	local rim = math.max(UI.LookBorder(housing.shyLook)) + L.frame
	UI.LookContent(housing.shyLook, { rim, rim, rim, rim })
	local page = own.page
	local pageW, pageH = colW - 2 * rim, tall - 2 * rim
	page:ClearAllPoints()
	page:SetPoint("TOPLEFT", housing, "TOPLEFT", rim, -rim)
	page:SetSize(pageW, pageH)
	local isBoss = type(state.page) == "number"
	local bandH = isBoss and math.max(L.stage[2], math.min(L.stage[3], math.floor(tall * L.stage[1]))) or L.band
	own.band:ClearAllPoints()
	own.band:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	FillBand(pageW, bandH, book)
	own.foot:ClearAllPoints()
	own.foot:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	local keys = FillFoot(pageW)
	own.body:ClearAllPoints()
	own.body:SetPoint("TOPLEFT", page, "TOPLEFT", L.side, -(bandH + 4))
	own.body:SetSize(pageW - L.side, pageH - bandH - 4 - keys)
	own.body.content:SetWidth(pageW - L.side - L.scroll)
	Rest(own.kicks)
	Rest(own.notes)
	Rest(own.quests)
	Rest(own.rows)
	wipe(own.byKey)
	Loot.Clear(own.body.content)
	Boss.Clear(own.body.content)
	local w = pageW - L.side - L.scroll
	local y
	if state.page == "overview" then
		y = Overview(0, w)
	elseif state.page == "trash" then
		y = TrashPage(L.top, w)
	elseif state.page == "quests" then
		y = QuestsPage(0, w)
	elseif state.page == "runs" then
		y = RunsPage(L.top, w)
	elseif state.page == "sets" then
		y = SetsPage(L.top, w)
	else
		y = BossPage(L.top, w, state.page)
	end
	-- Where it all comes from, said once, under the page.
	own.sources:ClearAllPoints()
	own.sources:SetPoint("TOPLEFT", 2, -(y + 2))
	y = y + 20
	own.body.content:SetHeight(math.max(1, y))
	own.body:Update()
	-- A new page opens at its top.
	local shown = state.map .. ":" .. tostring(state.page)
	if own.shown ~= shown then
		own.shown = shown
		own.body:Reveal(0, 1)
	end
end
Journal.Fill = Fill
Journal.quests = own.quests   -- (the quests' lines, for a test to click)

-- Turns to a page of the dungeon open: "overview", a boss by its place in the order, "trash" or "quests".
function Journal.Page(page)
	Turn(page)
	Fill()
end

-- Out a step: a page to its dungeon's overview, the overview to every dungeon (come in at its door on the map,
-- back out of it, to the map as you left it).
function Journal.Up()
	if not state.map then return end
	if state.page ~= "overview" then
		Journal.Page("overview")
	elseif not (ns.Sides and ns.Sides.Back(state.map)) then
		Journal.Open()
	end
end

-- Out of the door: the map turned to the world, at the dungeon's entrance.
function Journal.Out()
	if state.map and ns.Sides and ns.Sides.ToDoor then ns.Sides.ToDoor(state.map) end
end

local function Sources(self)
	local lines = UI.Lines()
	lines:AddLine("Where this comes from")
	lines:AddLine("Bosses and their order are the game's own.", C.text[1], C.text[2], C.text[3], true)
	lines:AddLine(" ")
	lines:AddLine("Drops in this game", C.head[1], C.head[2], C.head[3])
	lines:AddLine("What players recorded here, with the kills they counted, and what you've looted yourself.", C.text[1], C.text[2], C.text[3], true)
	lines:AddLine(J.CREDIT, C.dim[1], C.dim[2], C.dim[3], true)
	lines:AddLine(" ")
	lines:AddLine("Drops in Classic, and what bosses do", C.head[1], C.head[2], C.head[3])
	lines:AddLine("As the Classic game had them. This game may differ.", C.text[1], C.text[2], C.text[3], true)
	lines:AddLine("So with what a door asked of you, and where its rares stood.", C.text[1], C.text[2], C.text[3], true)
	lines:AddLine(" ")
	lines:AddLine("The newest dungeons", C.head[1], C.head[2], C.head[3])
	lines:AddLine("Where a boss stands and where you come in are learned as you play them.", C.text[1], C.text[2], C.text[3], true)
	-- (Another's work, shown under its credit: where the newest dungeons' bosses stand, and the way through.)
	if ns.data.dungeonRoutesCredit then
		lines:AddLine("Until then, placed by hand from guides and videos, with the way through. Rough places.", C.text[1], C.text[2], C.text[3], true)
		lines:AddLine(ns.data.dungeonRoutesCredit, C.dim[1], C.dim[2], C.dim[3], true)
	end
	UI.Tip(self, lines, { side = "TOP" })
end

---------------------------------------------------------------------------
-- Making it
---------------------------------------------------------------------------
-- The face into its shell, its body's size (its own, or the one it was just given): on its body, clear of the look's
-- work round the edge (UI.Body).
local function Shell(width, height)
	local box, face = own.box, own.face
	if own.home ~= "shell" then
		own.home = "shell"
		face:SetParent(box)
		face:ClearAllPoints()
		face:SetPoint("TOPLEFT", UI.Body(box), "TOPLEFT", 0, -HEADER)
		face:SetFrameLevel(box:GetFrameLevel() + 1)
		face.ground:Hide()
		own.barX, own.k = nil, 1
	end
	local w, h = UI.BodySize(box)
	own.w, own.h = width or w, (height or h) - HEADER
	face:Show()
end

local function MakeBar(face)
	local bar = CreateFrame("Frame", nil, face)
	bar:SetPoint("TOPLEFT")
	bar:SetSize(L.w, L.bar)
	-- (The map's bar is black; this one stands on it there, and wears the same in its own window.)
	bar.fill = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
	bar.fill:SetAllPoints()
	UI.Paint(bar.fill, C.bg)
	bar.rule = bar:CreateTexture(nil, "ARTWORK")
	UI.Paint(bar.rule, C.border, 0.7)
	bar.rule:SetHeight(1)
	bar.rule:SetPoint("BOTTOMLEFT")
	bar.rule:SetPoint("BOTTOMRIGHT")
	own.bar = bar
	if ns.Sides and ns.Sides.Switch then own.switch = ns.Sides.Switch(bar, "dungeons") end
	Journal.switch = own.switch
	own.root = Crumb(bar)
	own.crumbs = { Crumb(bar), Crumb(bar) }
	own.slashes = {}
	for i = 1, 2 do
		local text = UI.Words(bar, UI.NameFont(L.crumb), Shy.Skin.colors.idle)
		text:SetText("/")
		own.slashes[i] = text
	end
	Journal.back = own.root
	own.search = UI.Input(bar, nil, function() return state.query end, function(text)
		state.query = text or ""
		Fill()
	end, { width = L.search, live = true, maxLetters = 40, placeholder = function() return "Find a dungeon or a boss" end })
	own.search:Refresh()
end

local function MakeBand(main)
	local band = CreateFrame("Frame", nil, main)
	-- (No box round it: its picture fills the page's top and melts into the page at its foot.)
	band.art = band:CreateTexture(nil, "ARTWORK")
	band.art:SetAllPoints()
	band.plain = band:CreateTexture(nil, "ARTWORK")
	band.plain:SetAllPoints()
	UI.Paint(band.plain, C.fill, 0.5)
	band.shade = band:CreateTexture(nil, "ARTWORK", nil, 1)
	band.shade:SetAllPoints()
	band.shade:SetColorTexture(1, 1, 1, 1)
	band.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.9), CreateColor(0, 0, 0, 0.15))
	band.fade = band:CreateTexture(nil, "ARTWORK", nil, 2)
	band.fade:SetPoint("BOTTOMLEFT")
	band.fade:SetPoint("BOTTOMRIGHT")
	band.fade:SetHeight(L.fade)
	band.fade:SetColorTexture(1, 1, 1, 1)
	-- A boss's stage: the creature whole, on the picture.
	band.stage = Boss.Stage(band, true)
	band.stage:SetPoint("BOTTOMLEFT", 0, 0)
	band.stage:Hide()
	-- What is written on it stands over the creature.
	local over = CreateFrame("Frame", nil, band)
	over:SetAllPoints()
	over:SetFrameLevel(band.stage:GetFrameLevel() + 10)
	band.over = over
	-- The way back, a key of the family's make in the band's top corner where the eye starts, before the name:
	-- to every dungeon from an overview, to the overview from a page.
	band.back = Step(over, -1, function() Journal.Up() end)
	band.back:SetPoint("TOPLEFT", 6, -6)
	Journal.up = band.back
	band.title = UI.Letter(UI.Text(over, "", L.title, true, C.head), { least = "shadow" })
	band.lesser = UI.Letter(UI.Text(over, "", L.lesser, true, C.head), { least = "shadow" })
	for _, text in ipairs({ band.title, band.lesser }) do
		text:SetJustifyH("LEFT")
		text:SetWordWrap(false)
	end
	band.sub = UI.Letter(UI.Text(over, "", 11, false, C.text), { least = "shadow" })
	-- Where it is: its zone, a way out of the door.
	band.where = CreateFrame("Button", nil, over)
	band.where:SetHeight(16)
	band.where.text = UI.Letter(UI.Text(band.where, "", 11, true, C.hot), { least = "shadow" })
	band.where.text:SetPoint("LEFT", 4, 0)
	function band.where:Say(zone)
		self.text:SetText(zone)
		self:SetWidth(4 + math.ceil(self.text:GetStringWidth()) + 6)
	end
	band.where:SetScript("OnEnter", function(self)
		UI.Ink(self.text, C.head)
		UI.Tip(self, "The way in", nil, { side = "TOP", hints = { { "left", "Show it on the map" } } })
	end)
	band.where:SetScript("OnLeave", function(self)
		UI.Ink(self.text, C.hot)
		UI.TipHide(self)
	end)
	band.where:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Journal.Out()
	end)
	band.rest = UI.Letter(UI.Text(over, "", 11, false, C.text), { least = "shadow" })
	band.rest:SetPoint("LEFT", band.where, "RIGHT", 0, 0)
	-- The boss before, and the boss after.
	-- (The boss before and after, in the order they are met.)
	local function Along(by)
		local order = J.Order(state.map)
		local to = type(state.page) == "number" and order[J.Step(state.map, state.page) + by]
		if to then Journal.Page(to) end
	end
	band.next = Step(over, 1, function() Along(1) end)
	band.next:SetPoint("TOPRIGHT", -6, -6)
	band.prev = Step(over, -1, function() Along(-1) end)
	band.prev:SetPoint("RIGHT", band.next, "LEFT", -3, 0)
	own.band = band
end

local function MakeFoot(main)
	-- The keys under the column, in the hover's foot's make: a darker floor under a groove and its lip.
	local foot = CreateFrame("Frame", nil, main)
	foot:SetHeight(L.foot)
	foot.floor = foot:CreateTexture(nil, "BACKGROUND", nil, 2)
	foot.floor:SetAllPoints()
	foot.floor:SetColorTexture(0, 0, 0, 0.30)
	foot.groove = foot:CreateTexture(nil, "ARTWORK")
	foot.groove:SetColorTexture(0, 0, 0, 0.85)
	foot.groove:SetHeight(1)
	foot.groove:SetPoint("TOPLEFT")
	foot.groove:SetPoint("TOPRIGHT")
	foot.lip = foot:CreateTexture(nil, "ARTWORK")
	foot.lip:SetColorTexture(1, 1, 1, 0.07)
	foot.lip:SetHeight(1)
	foot.lip:SetPoint("TOPLEFT", 0, -1)
	foot.lip:SetPoint("TOPRIGHT", 0, -1)
	own.foot = foot
	-- The one that matters filled, the others quiet.
	own.run = Key(foot, "Get its quests", function()
		local quest = Quest()
		if not quest then return end
		if quest.Running and quest:Running() == state.map then quest:StopDungeon() else quest:RunDungeon(state.map) end
		Fill()
	end, L.footKey)
	own.lead = Key(foot, "Lead me there", function()
		local door, quest = Journal.Door(state.map), Shy.addons.Quest
		if door and quest and quest.Go then
			PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
			quest:Go(door.map, door.x, door.y, J.Book(state.map).one.name)
			-- (With the map open, the way shows at once: the window turns to the world at the door.)
			if ns.Sides and ns.Sides.MapUp and ns.Sides.MapUp() then Journal.Out() end
		end
	end, L.footKey, false, true)
	own.group = Key(foot, "Find a group", function()
		Shy:Fire("SHY_GROUP_WANTED", state.map)
	end, L.footKey, false, true)
end

local function Create()
	local box = UI.Window({
		id = "shymaps.dungeons",
		name = "ShyMapsDungeons",
		title = "Dungeon journal",
		width = L.w, height = L.h,
		point = { "CENTER", "CENTER", 0, 20 },
		shown = function() return T.db.journal.open end,
		grip = { flow = function(_, width, height)
			if own.home == "shell" then
				Shell(width, height)
				Fill()
			end
		end, min = L.least },
		strata = "HIGH",
		maximize = true,
		onClose = function() T.db.journal.open = false end,
		close = function() Journal.Toggle(false) end,
		head = { size = "window", icon = T.mark, title = "Dungeons" },
	})
	own.box = box

	-- The face: everything under the header, here or in the map window.
	local face = CreateFrame("Frame", nil, box)
	face:SetSize(L.w, L.h - HEADER)
	face:EnableMouse(true)
	-- (In the map window it lies over the map: a ground of its own, the window's.)
	face.ground = face:CreateTexture(nil, "BACKGROUND")
	face.ground:SetAllPoints()
	UI.Paint(face.ground, C.panel)
	face.ground:Hide()
	own.face = face
	Journal.face = face

	MakeBar(face)

	-- Everything under the bar stands on one frame, laid at the scale its home gives it.
	local main = CreateFrame("Frame", nil, face)
	main:SetPoint("TOPLEFT", 0, -L.bar)
	main:SetSize(L.w, L.h - HEADER - L.bar)
	own.main = main

	-- Every dungeon: the cards, or what the search finds.
	own.gallery = UI.ScrollArea(main, L.w - 2 * L.gap, L.h - HEADER - L.bar - 2 * L.gap)
	own.gallery:SetPoint("TOPLEFT", L.gap + 4, -L.gap)
	own.empty = UI.Text(main, "", 12, false, C.dim)
	own.empty:SetPoint("TOP", own.gallery, "TOP", 0, -40)

	-- The place, and what stands in its corners over it.
	own.place = Floors.Pane(main)
	Journal.place = own.place
	own.corners = CreateFrame("Frame", nil, main)
	own.corners:SetFrameLevel(own.place:GetFrameLevel() + 20)
	own.out = Key(own.corners, "", function() Journal.Out() end, L.corner, true)
	own.out:HookScript("OnEnter", function(self)
		UI.Tip(self, "The way in", nil, { side = "TOP", hints = { { "left", "Show it on the map" } } })
	end)
	own.out:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	Journal.out = own.out

	-- The column, in the theme's housing as the place is: inside its rim the page, its ground the look's own face
	-- darkened; on it the band, and under that the list in a scroll (a raid has more bosses than a column has room).
	own.col = CreateFrame("Frame", nil, main)
	UI.Panel(own.col, { looks = true, brackets = false, line = false })
	local page = CreateFrame("Frame", nil, own.col)
	page:SetFrameLevel(own.col:GetFrameLevel() + 1)
	page.ground = page:CreateTexture(nil, "BACKGROUND", nil, -8)
	page.ground:SetAllPoints()
	UI.Paint(page.ground, C.bg, L.ground)
	own.page = page
	MakeBand(page)
	own.body = UI.ScrollArea(page, L.col[2], 200)
	-- Where it all comes from: a quiet word under every page.
	own.sources = CreateFrame("Button", nil, own.body.content)
	own.sources.label = UI.Text(own.sources, "Sources", 10, false, C.dim)
	own.sources.label:SetPoint("LEFT")
	own.sources:SetSize(48, 16)
	own.sources:SetScript("OnEnter", function(self)
		UI.Ink(self.label, C.text)
		Sources(self)
	end)
	own.sources:SetScript("OnLeave", function(self)
		UI.Ink(self.label, C.dim)
		UI.TipHide(self)
	end)

	MakeFoot(page)
	-- What shows only while a dungeon is open.
	own.dungeon = { own.place, own.corners, own.col }

	-- An item the game hadn't told of has come in (a list picked without it is picked again), or a spell's words
	-- (its row grows for them).
	local function Late()
		if Journal.IsOpen() then Fill() end
	end
	Loot.OnLate(Late)
	Boss.OnLate(Late)
end

---------------------------------------------------------------------------
-- Opening it
---------------------------------------------------------------------------
-- The dungeon you are standing in, if the journal has it.
local function Here()
	local _, kind, _, _, _, _, _, map = GetInstanceInfo()
	if (kind == "party" or kind == "raid") and map and J.Book(map) then return map end
end
Journal.Here = Here

-- The room of the dungeon `map` you stand in, by the words the game has over the minimap: nil anywhere else.
function Journal.Room(map)
	if Here() ~= map then return nil end
	local name = GetMinimapZoneText()
	if name == nil or issecretvalue(name) or name == "" then return nil end
	return name
end

-- Your group in the dungeon with you: each one's copy says which room it is in as it walks into one (to the
-- party or the raid, where you share where you are: T.db.share), and the journal lights those rooms too.
local HEARD = 900            -- seconds a room someone said they were in is believed
local group = {}             -- sender -> { map, room, at }
local told                   -- the room last said, with its map

-- Who of your group is in which room of `map`: { [room] = { name, ... } }, or nil where nobody said.
function Journal.Others(map)
	local out
	local now = GetTime()
	for sender, heard in pairs(group) do
		if heard.map == map and now - heard.at <= HEARD then
			out = out or {}
			out[heard.room] = out[heard.room] or {}
			table.insert(out[heard.room], (Ambiguate(sender, "short")))
		end
	end
	for _, names in pairs(out or NONE) do table.sort(names) end
	return out
end

function Journal.Heard(msg, sender)
	if sender == nil or issecretvalue(sender) or Shy.IsMe(sender) then return end
	local map, room = msg:match("^room\t(%d+)\t(.*)$")
	map = tonumber(map)
	if not map then return end
	-- (An empty room: they walked out of the dungeon.)
	group[sender] = room ~= "" and { map = map, room = room, at = GetTime() } or nil
	if own.face and Journal.IsOpen() and state.map == map then Fill() end
end

-- Says which room you are in, once for each room, to your group.
local function Tell()
	if not (T.db and T.db.share) then return end
	local channel = Shy.GroupChannel()
	if channel ~= "PARTY" and channel ~= "RAID" then return end
	local map = Here()
	local now = map and ((map .. "\t" .. (Journal.Room(map) or ""))) or nil
	if now == told then return end
	-- (Out of the dungeon: the last one you were in is told you left.)
	local was = told and told:match("^(%d+)\t")
	told = now
	if now then
		T:SendComm("room\t" .. now, channel)
	elseif was then
		T:SendComm("room\t" .. was .. "\t", channel)
	end
end

-- You walked into another room of the dungeon the journal shows: the place turns to that room's floor, and
-- lights it.
local function Moved()
	Tell()
	if not (own.face and Journal.IsOpen() and state.map and Here() == state.map and state.query == "") then return end
	local floor = Floors.RoomFloor(state.map, Journal.Room(state.map))
	if floor then state.floor = floor end
	Fill()
end
local walked = CreateFrame("Frame")
walked:RegisterEvent("ZONE_CHANGED")
walked:RegisterEvent("ZONE_CHANGED_INDOORS")
walked:RegisterEvent("ZONE_CHANGED_NEW_AREA")
walked:RegisterEvent("PLAYER_ENTERING_WORLD")
walked:SetScript("OnEvent", function()
	local ok, err = pcall(Moved)
	if not ok then geterrorhandler()(err) end
end)
Journal.walked = walked   -- (for a test to send it an event)

-- The boss you have targeted, of the dungeon `map`: its place in the order.
local function Targeted(map)
	local name = UnitName("target")
	local book = map and J.Book(map)
	if not (name and book) or issecretvalue(name) then return nil end
	for index, boss in ipairs(book.bosses) do
		if boss.name == name then return index end
	end
end

-- The face on a host of the map window's (Sides.lua): its size, how far in its bar's pieces begin, and the scale
-- of what is under the bar (what is laid over the map is smaller: the map gets the room).
function Journal.Home(parent, width, height, x, scale)
	if not own.face then Create() end
	local face = own.face
	own.home = "map"
	face:SetParent(parent)
	face:ClearAllPoints()
	face:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	face:SetFrameLevel(parent:GetFrameLevel() + 1)
	face.ground:Show()
	own.w, own.h, own.barX, own.k = width, height, x, scale or 1
	face:Show()
	Fill()
end

-- Shows the journal as its state says: in the map window while that is open, else in its own.
local function Show()
	local sides = ns.Sides
	if sides and sides.MapUp and sides.MapUp() then
		if T.db.journal.open then
			T.db.journal.open = false
			Shy.HUD.Update(own.box)
		end
		sides.Turn("dungeons")
		return
	end
	T.db.journal.open = true
	Shell()
	Shy.HUD.Update(own.box)
	own.box:Raise()
	Fill()
end

-- wing: the dungeon of an instance that is several to open it at (its place among them).
function Journal.Open(map, boss, wing)
	if not T.db then return end
	if not own.face then Create() end
	if map and not J.Book(map) then map = nil end
	if map ~= state.map then
		state.floor = nil
		if ns.Sides then ns.Sides.Forget() end
	end
	state.map = map
	state.query = ""
	own.search:Refresh()
	state.page = map and boss and J.Book(map).bosses[boss] and boss or "overview"
	if map and type(state.page) == "number" then state.floor = Floors.FloorOf(map, state.page) end
	local wings = map and wing and Floors.Wings(map)
	if wings and wings[wing] and wings[wing].floors[1] then state.floor = wings[wing].floors[1] end
	Show()
end

function Journal.IsOpen()
	if not T.db then return false end
	if T.db.journal.open == true then return true end
	local sides = ns.Sides
	return own.home == "map" and sides ~= nil and sides.Now() == "dungeons" and sides.MapUp() == true
end

function Journal.Toggle(open)
	if open == nil then open = not Journal.IsOpen() end
	if open then
		-- In a dungeon, on that one (on the boss you have targeted); else as it was left; on a run, on the dungeon
		-- being run.
		local here = Here()
		if here and here ~= state.map then
			Journal.Open(here, Targeted(here))
			return
		end
		local quest = Quest()
		local map = here or state.map or (quest and quest.Running and quest:Running()) or nil
		if map ~= state.map or not own.face then
			Journal.Open(map)
		else
			Show()
		end
		return
	end
	local sides = ns.Sides
	if own.home == "map" and sides and sides.Now() == "dungeons" then sides.Turn("world") end
	T.db.journal.open = false
	if own.box then Shy.HUD.Update(own.box) end
end

-- The map window opened while the journal stood in its own: that window closes (the face goes into the map's).
function Journal.Yield()
	if not (T.db and T.db.journal.open) then return false end
	T.db.journal.open = false
	if own.box then Shy.HUD.Update(own.box) end
	return true
end

-- /shymaps dungeons [name]: opens on a dungeon or a boss named in part; with no name, on every dungeon.
function Journal.Command(words)
	words = strtrim(words or "")
	if words == "" then
		if Journal.IsOpen() then Journal.Toggle(false) else Journal.Open(Here()) end
		return
	end
	local found = J.Search(words)[1]
	if found then
		Journal.Open(found.map, found.boss)
	else
		T:Print(("no dungeon or boss called |cffffffff%s|r."):format(words))
	end
end

if Shy.Command then Shy.Command("dungeons", "bosses and loot for every dungeon", function() Journal.Toggle() end) end

-- What changes what a page says: a drop noted, a star, the gear, a run started or stopped.
local function Changed()
	-- (Its own window is not kept open from one session to the next: nothing is made until it is asked for.)
	if not own.face then
		if T.db then T.db.journal.open = false end
		return
	end
	if Journal.IsOpen() then Fill() end
end
Shy:On("SHY_MAPS_SEEN", Changed)
Shy:On("SHY_MAPS_WANT", Changed)
Shy:On("SHY_MAPS_RUN", Changed)
Shy:On("SHY_GEAR", Changed)
Shy:On("SHY_DUNGEON_RUN", Changed)
ns.OnApply(Changed)
