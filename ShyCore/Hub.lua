-- The hub: the Shy window (/shy), where every setting has one home. A rail of rooms down its left with what each
-- holds now, the room on show beside it. Every addon's settings stand in one of them, the Settings room. Also
-- what an addon tells of its settings, /shy and its commands, the login splash and the version ping.
--
--   Shy.Hub.Open(room)       the window: at a room ("home", "settings", "theme", "screen", "play", "keys", "game",
--                            "profiles", "tools"), at an addon's settings (the addon), or where it was
--   Shy.Hub.Close()          Shy.Hub.IsOpen()
--   Bus: SHY_HUB_CLOSED      the window was closed (not lent to a guest: the guest tells its own)
--   Shy.HubSection(room, build, order)   a section of a room, under those before it (lower orders first; 50
--                            unless told). build(page, top) stands it under `top` (Shy.HubHead, Shy.HubPlace)
--                            and returns its last frame and a function that refreshes it; page.width is the
--                            room's. Built when the room first shows, after every addon has loaded
--   Shy.HubHead(page, top, text)    a section's caption, under what stands above it; returns its frame. A room's
--                            captions hang under its row on the rail while it is open, each a click from its section
--   Shy.HubPlace(page, frame, top)  a section with no caption, under what stands above it
--   Shy.HubBrief(room, fn)   what a room holds now in a few words, under its name on the rail
--   Shy.Command(word, help, fn)     /shy <word>: fn(rest), the words after it as typed. `word` may be several
--                            ("errors clear"): the longest the typed words begin with runs. With `help`, listed:
--                            only what a player would type has one. A word for finding faults (a report to
--                            copy, a test) runs without, and is never shown
--   T:Command(word, help, fn)       an addon's: /shy <its name> <word>. No word: /shy <its name> alone, which
--                            opens its settings unless told otherwise
--   T:Settings(list)         an addon's settings, told as a list (Settings.lua has what an entry may say). They
--                            stand in the Settings room, found as you type. Told again, the list grows
--   T:OpenOptions()          the window at them
--   /shy <anything else>     looks for it in the settings; /set does the same
--
-- The setup walks through the same window: lent, its rail is the guest's pages and a foot opens under its room.
--   Shy.Hub.Lend(guest)      the window open on a guest's pages: guest = { items (the rail's), words, name (after
--                            the window's name in its header), Go(key) (a row clicked), Lay(sizing) (the window
--                            resized: Shy.Hub.Size; sizing, a corner still dragged, every frame the mouse moves,
--                            so nothing is read again), Close() (its ×), Leave() (another room asked for), Hidden(box) (the
--                            window hidden by Esc or the game), Away() (true: kept out of sight, still open) }.
--                            Returns the window: box.rail, box.scroll, box.content (a page at Shy.Hub.IN across),
--                            box.foot. Shy.Hub.Lent(): the guest, or nil
--   Shy.Hub.Return(shut)     the window back to its own rooms, open (shut: closed)
--   Shy.Hub.Size()           the page's width and the room's height under the header, now
--   Shy.Hub.Band(parent, width)      the band that names your character: band:Tell(setup) (the edge gold while
--                            setting up: nothing is kept yet); band.who, band.what
--   Shy.Hub.Tile(parent, width)      a tile: b.icon, b.name, b.line (cut where the tile ends); Shy.Hub.HOME its sizes
--   Shy.Hub.Caption(parent, width, text)   a caption over a group, a rule after its words
local Shy = Shy
local B, UI, Theme = Shy.Brand, Shy.UI, Shy.Theme
local Addon, core = Shy.AddonPrototype, Shy.core
local C = UI.colors
local max = math.max

local Hub = {}
Shy.Hub = Hub

-- The game's own Options list ShyUI once: a page whose button opens the window.
local door = CreateFrame("Frame")
door:Hide()
local function DoorName()
	return B.Icon(core.mark, 16) .. " " .. B.Name()
end
Shy.category = Settings.RegisterCanvasLayoutCategory(door, DoorName())
Settings.RegisterAddOnCategory(Shy.category)
-- (The list's name carries the accent in escape codes: written again on a theme change.)
Shy:On("SHY_THEME", function() Shy.category:SetName(DoorName()) end)
door:SetScript("OnShow", function(self)
	if self.built then return end
	self.built = true
	local emblem = UI.PageHeader(self, core)
	local open = UI.Button(self, "Open settings", 180, function()
		SettingsPanel:Close(true)
		Hub.Open()
	end)
	open:SetHeight(30)
	open:SetPrimary(true)
	open:SetPoint("TOPLEFT", emblem, "BOTTOMLEFT", 0, -40)
	local words = UI.Text(self, "All the settings are in their own window. You can also type /shy.", 12, false, C.dim)
	words:SetPoint("LEFT", open, "RIGHT", 14, 0)
end)

-- The window: the rail flush with its left edge, a rule, then the room, IN from the scroll area's edge. The room
-- flows with the window, up to MOST across.
-- GLIDE: seconds the room takes to glide to a section picked on the rail; AIR: room left over a section's head
-- there, and how near the top a head counts as the one in view.
local W = { EDGE = 2, RAIL = 220, PAD = 28, IN = 24, PAGE = 700, SCROLL = 14, RIGHT = 22, TOP = 16, FOOT = 14, PAGE_H = 580,
	FADE = 0.15, MEASURE = 0.2, SOON = 0.05, SETTLED = 0.5, REST = 4, BRIEFS = 0.5, GLIDE = 0.28, AIR = 10, MOST = 1000,
	WALK = 46, UNDER = 12, STEP = 10, STICK = 12 }
-- WALK: the foot a guest walks its pages on, up from the window's bottom to its rule; UNDER: room over that rule.
-- MOST: the widest a room flows to (maximized), the width the setup window's pages are laid out at, so every
-- shared section is known to stand there. STEP: the widths a room is laid out at go in steps of this (PAGE and
-- MOST among them): a room is built for each width it stands at and kept, so there are few.
W.HEADER = UI.HEAD.main.line + UI.LINE
W.WIDTH = W.EDGE + W.RAIL + W.PAD + W.PAGE + W.SCROLL + W.RIGHT
W.HEIGHT = W.HEADER + W.TOP + W.PAGE_H + W.FOOT

local ROOMS = {
	{ key = "home", label = "Home", glyph = "home" },
	-- (owned: Settings.lua fills it. Until that file is there the rail leaves it out.)
	{ key = "settings", label = "Settings", glyph = "options", owned = true },
	{ key = "theme", label = "Theme", glyph = "star", ask = "Theme",
		lead = "Pick a ready-made theme, or change the parts you want. You'll see it on your screen right away." },
	{ key = "screen", label = "Screen", glyph = "window", ask = "Your screen",
		lead = "Change how big everything is, and move things where you want them." },
	{ key = "play", label = "Play", glyph = "book", ask = "How you play",
		lead = "Pick how you take and hand in quests, and how much of the UI you see while you play." },
	-- (owned: an addon's room, not the core's. Without that addon nothing fills it, so the rail leaves it out.)
	-- (not paged: you come here to change a key, not to walk through setting them up again)
	{ key = "keys", label = "Keys", glyph = "action", owned = true, ask = "Keys",
		lead = "Your class's abilities on your keys. Change any of them here. Nothing changes until you save." },
	{ key = "game", label = "Game", glyph = "log", ask = "Game settings",
		lead = "Tick one and it changes right away. Untick it and you get back what you had. They're all in the game's own options too." },
	{ key = "profiles", label = "Profile", glyph = "group", ask = "Profiles",
		lead = "A profile saves all your addon settings and your layout. Characters on the same profile share them." },
	{ key = "tools", label = "Tools", glyph = "use", ask = "Tools",
		lead = "Help for when something goes wrong, and every command." },
}
local ROOM = {}
for _, room in ipairs(ROOMS) do ROOM[room.key] = room end

-- at: the room on show, by its key; pages: each room's page, by the same. kept: each room's pages
-- by the width it was built for (a page built is never let go: the game keeps every frame, and its sections
-- keep what they registered).
local win = { open = false, at = "home", pages = {}, kept = {}, parts = {}, pageH = W.PAGE_H, pageW = W.PAGE }
-- (parts: the part on show in each paged room, by its key: kept through the room built again for another width)

-- A hover on a control: hooked on enter rather than UI.Help, which needs Shy.Hover as it is called.
local function Help(frame, title, text)
	frame:HookScript("OnEnter", function(self) UI.Tip(self, title, text) end)
	frame:HookScript("OnLeave", function(self) UI.TipHide(self) end)
end
local sections, briefs = {}, {}
local commands, listed = {}, {}
local Build = {}

function Shy.HubSection(room, build, order)
	sections[room] = sections[room] or {}
	local list = sections[room]
	list[#list + 1] = { build = build, order = order or 50, at = #list + 1 }
end

function Shy.HubBrief(room, fn)
	briefs[room] = briefs[room] or {}
	table.insert(briefs[room], fn)
end

function Shy.Command(word, help, fn, addon, bare)
	-- (Told again by the one that told it, the new one stands: an addon loaded again is the same addon.
	-- Another's word is an error.)
	local was = commands[word]
	local whose = addon and addon.name or false
	if was and was.whose ~= whose then error("Shy.Command: /shy " .. word .. " is taken", 2) end
	commands[word] = { fn = fn, addon = addon, whose = whose, bare = bare }
	if not help then return end
	for _, command in ipairs(listed) do
		if command.word == word then
			command.help = help
			return
		end
	end
	listed[#listed + 1] = { word = word, help = help, addon = addon }
end

-- The commands with a line of help, as they were told: { word, help, addon }.
function Hub.Commands() return listed end

-- (The addon's name alone takes no words after it: words that are none of its commands are looked for in the
-- settings, as after any name.)
function Addon:Command(word, help, fn)
	local name = self.suffix:lower()
	if word == "" then
		Shy.Command(name, help, fn, self, true)
	else
		Shy.Command(name .. " " .. word, help, fn, self)
	end
end

-- Settings: what each addon told, kept here so telling works before Settings.lua has loaded.
--   told[suffix] = { addon, entries, apply, reset }; order: as they were told; doors: a room's own controls,
--   to find and go to; stamp: goes up with every telling
local Settings = { told = {}, order = {}, doors = {}, stamp = 0 }
Shy.Settings = Settings
function Settings.Refresh() end

function Addon:Settings(list)
	local told = Settings.told[self.suffix]
	if not told then
		told = { addon = self, entries = {} }
		Settings.told[self.suffix] = told
		Settings.order[#Settings.order + 1] = told
	end
	for _, entry in ipairs(list) do told.entries[#told.entries + 1] = entry end
	told.apply, told.reset = list.apply or told.apply, list.reset or told.reset
	Settings.stamp = Settings.stamp + 1
end

-- The entry every addon with a piece on screen ends its list with: a button to layout mode.
--   Shy.Settings.Layout(desc)   desc: what is moved there, in a sentence
function Settings.Layout(desc)
	return { label = "Position", button = "Layout mode", words = "move place drag unlock size where",
		desc = desc or "Move and size it on your screen.", run = function()
			Hub.Close()
			Shy.HUD.SetUnlocked(true)
		end }
end

-- A control that lives in one of the window's own rooms: found in the settings, a click goes to its room.
--   Shy.Settings.Door(room, label, desc, words, head)   head: the section of the room it stands in
function Settings.Door(room, label, desc, words, head)
	Settings.doors[#Settings.doors + 1] = { room = room, label = label, desc = desc, words = words, head = head }
	Settings.stamp = Settings.stamp + 1
end

function Hub.Caption(parent, width, text)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 14)
	local words = UI.Text(f, text:upper(), 11, true, C.dim)
	words:SetPoint("LEFT")
	local rule = f:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.6)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", words, "RIGHT", 10, 0)
	rule:SetPoint("RIGHT")
	f.words, f.rule = words, rule
	return f
end

-- A section's head: a caption with its rule, its line on the rail (label: other words there than its own). In a
-- paged room (ROOMS' `paged`) each section is a page of its own: its head is the page's heading, its words
-- over `sentence`, as setup's pages have them.
function Shy.HubHead(page, top, text, sentence, label)
	local f
	if page.paged then
		f = UI.Lead(page, page.width)
		f:Set(text, sentence or "")
		f:SetHeight(UI.LEAD_H - 12)
		f:SetPoint("TOPLEFT", page.origin, "BOTTOMLEFT", 0, 0)
	else
		f = Hub.Caption(page, page.width, text)
		f:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, top == page.origin and -6 or -26)
	end
	page.heads = page.heads or {}
	page.heads[#page.heads + 1] = { key = "head" .. (#page.heads + 1), label = label or text, frame = f }
	return f
end

function Shy.HubPlace(page, frame, top)
	frame:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, top == page.origin and -6 or -24)
end

-- A bar that stays at the window's foot while a room has something waiting there (keys picked and not saved).
-- It stands under the room rather than in it, so it is in the same place however far the room is scrolled, and
-- the room is given that much less height while it shows. Call Shy.HubFoot(page, nil) to take it away again.
--   frame:SetHeight() before this: the height it is given back is the one the room loses
function Shy.HubFoot(page, frame)
	-- (placed again when the window is made wider or narrower: the room is laid out at another width then,
	-- and the bar stands across that width, not the window's)
	if page.stick == frame and page.stickW == (frame and win.pageW or nil) then return end
	if page.stick and page.stick ~= frame then
		page.stick:ClearAllPoints()
		page.stick:Hide()
	end
	page.stick, page.stickW = frame, frame and win.pageW or nil
	if frame then
		frame:SetParent(win.box)
		frame:ClearAllPoints()
		-- The bar is a surface, so it spans the whole of the room's side of the window -- from the rule beside
		-- the rail to the far edge, the sheet's own width. What it holds stands in from that by the room's
		-- margins (frame:Inset), so its words and its buttons line up with the rows it covers.
		frame:SetPoint("BOTTOMLEFT", win.body, "BOTTOMLEFT", W.EDGE + W.RAIL, W.FOOT)
		frame:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", 0, W.FOOT)
		if frame.Inset then frame:Inset(W.PAD, W.RIGHT + W.SCROLL) end
		frame:SetFrameLevel(win.box:GetFrameLevel() + 20)   -- (over the room it covers the foot of)
		frame:Show()
	end
	if Hub.IsOpen() then Hub.Refit() end
end

-- A page as tall as what it holds. Lowest() skips regions stretched to the page's own bottom edge (the page
-- would grow forever), nested scroll areas, and secret measurements (they can't be compared).
local function Seen(thing)
	local shown = thing:IsShown()
	return not issecretvalue(shown) and shown
end

-- (Every piece of the room is asked: nothing is made for it, the pieces taken as they are handed over.)
local Lowest
local function Lower(lowest, floor, bottom)
	if bottom and not issecretvalue(bottom) and math.abs(bottom - floor) > 1 and bottom < lowest then return bottom end
	return lowest
end
local function LowestRegion(lowest, floor, ...)
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if Seen(region) then lowest = Lower(lowest, floor, region:GetBottom()) end
	end
	return lowest
end
local function LowestChild(lowest, floor, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		if Seen(child) and child:GetObjectType() ~= "ScrollFrame" then
			if child:GetNumChildren() == 0 and child:GetNumRegions() == 0 then
				lowest = Lower(lowest, floor, child:GetBottom())
			else
				lowest = Lowest(child, lowest, floor)
			end
		end
	end
	return lowest
end
function Lowest(f, lowest, floor)
	return LowestChild(LowestRegion(lowest, floor, f:GetRegions()), floor, f:GetChildren())
end

-- The room an open page has: the window's. Lent: less the foot under it.
local function Room()
	if win.guest then return win.pageH + W.FOOT - W.UNDER - W.WALK end
	-- (a bar at the foot stands under the room, not in it: the room is that much shorter while it shows)
	local page = win.pages and win.pages[win.at]
	local stick = page and page.stick and page.stick:IsShown() and (page.stick:GetHeight() + W.STICK) or 0
	return win.pageH - stick
end

-- Where a room's pieces stand, two deep (its sections and what they hold), as one number: how far each is
-- below the room's top, added up. The measuring walks every piece of a room, thousands in one with drawings in
-- it (54 ms in the Screen room): it is done again only when this has changed, or when asked whatever it says.
local function StandsRegion(sum, top, ...)
	for i = 1, select("#", ...) do
		local region = select(i, ...)
		if Seen(region) then
			local bottom = region:GetBottom()
			if bottom and not issecretvalue(bottom) then sum = sum + (top - bottom) end
		end
	end
	return sum
end
local function StandsChild(sum, top, deep, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		if Seen(child) then
			local bottom = child:GetBottom()
			if bottom and not issecretvalue(bottom) then sum = sum + (top - bottom) end
			if deep > 1 and child:GetObjectType() ~= "ScrollFrame" then
				sum = StandsChild(StandsRegion(sum, top, child:GetRegions()), top, deep - 1, child:GetChildren())
			end
		end
	end
	return sum
end

-- whole: measured whatever stands where (a room just shown). Else only where its pieces have moved.
local function Measure(whole)
	local box, page = win.box, win.pages[win.at]
	if win.guest or not page then return end
	-- One that scrolls by itself fills the room: the window's own scroll has nowhere to go.
	if page.scrollsItself then
		local room = Room()
		if math.abs(room - page:GetHeight()) > 0.5 then page:SetHeight(room) end
		if math.abs(room - box.content:GetHeight()) > 0.5 then box.content:SetHeight(room) end
		box.scroll:Update()
		return
	end
	local room = Room()
	local top, bottom = page:GetTop(), page:GetBottom()
	if not top or issecretvalue(top) or issecretvalue(bottom) then return end
	local stands = StandsChild(StandsRegion(0, top, page:GetRegions()), top, 2, page:GetChildren())
	if not whole and page.stood and math.abs(stands - page.stood) < 0.5 then return end
	page.stood = stands
	local held = top - Lowest(page, top, bottom) + 20
	page.held = held
	local tall = max(held, room)
	-- A room's sections stand on the rail, to go to, only where the room is taller than the window shows:
	-- with all of it in sight there is nowhere to go, and the lines under its row are only in the way.
	-- (Less the 20 of air under the last piece: that the room scrolls by its air alone hides nothing.)
	local lined = page.heads ~= nil and #page.heads > 1 and (page.paged or held - 20 > room + 1)
	if page.lined ~= lined then
		page.lined = lined
		box.rail:SetKids(win.at, lined and page.heads or nil)
	end
	if math.abs(tall - page:GetHeight()) > 1 then page:SetHeight(tall) end
	if math.abs(tall - box.content:GetHeight()) > 0.5 then box.content:SetHeight(tall) end
	box.scroll:Update()
end

-- What each room holds now, in a few words, for the rail.
local function Briefs()
	local out = {}
	for key, list in pairs(briefs) do
		local said = {}
		for i, fn in ipairs(list) do
			-- (Each on the clock: they are asked twice a second for as long as the window is open.)
			local from = debugprofilestop()
			local ok, words = pcall(fn)
			list.clocks = list.clocks or {}
			list.clocks[i] = list.clocks[i] or Shy.Clock(("hub: the rail's words, %s %d"):format(key, i))
			list.clocks[i]:Lap(debugprofilestop() - from)
			if ok and words and words ~= "" then said[#said + 1] = words end
		end
		if #said > 0 then out[key] = table.concat(said, "  \194\183  ") end
	end
	return out
end

-- Each piece of a room's showing on the clock (the task manager): the time since `from` under `name`; the
-- time now, for the next piece. A click on the rail is all of them, and none had a clock.
local function Lap(name, from)
	local now = debugprofilestop()
	Shy.Clock(name):Lap(now - from)
	return now
end

-- One of ours: its heading, then what the core builds for it and every section registered for it, top down.
local function OurPage(room)
	local page = CreateFrame("Frame", nil, win.box.content)
	page:SetPoint("TOPLEFT", W.IN, 0)
	page:SetSize(win.pageW, win.pageH)
	page.width, page.refresh, page.paged = win.pageW, {}, room.paged
	page.origin = CreateFrame("Frame", nil, page)
	page.origin:SetSize(win.pageW, 1)
	page.origin:SetPoint("BOTTOMLEFT", page, "TOPLEFT", 0, room.ask and -UI.LEAD_H or 0)
	if room.ask then
		page.lead = UI.Lead(page, win.pageW)
		page.lead:SetPoint("TOPLEFT")
		page.lead:Set(room.ask, room.lead)
	end
	local top = page.origin
	-- (Each part of a room on the clock as it is made, and as it reads its settings again at every showing.)
	page.read = {}
	local from = debugprofilestop()
	if Build[room.key] then
		top = Build[room.key](page, top) or top
		from = Lap(("hub: %s, the core's part made"):format(room.key), from)
	end
	local list = sections[room.key] or {}
	table.sort(list, function(a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.at < b.at
	end)
	-- (One section failing must not take the room with it: the rest stand, and the error is told.)
	page.parts = room.paged and {} or nil
	for i, section in ipairs(list) do
		local heads = page.heads and #page.heads or 0
		local ok, last, fresh = pcall(section.build, page, room.paged and page.origin or top)
		from = Lap(("hub: %s, section %d made"):format(room.key, i), from)
		-- (paged: the section's head and what it built, to show it alone)
		if ok and page.parts and page.heads and #page.heads > heads then
			page.parts[#page.parts + 1] = { head = page.heads[#page.heads], frame = last }
		end
		if ok then
			top = last or top
			if fresh then
				page.refresh[#page.refresh + 1] = fresh
				page.read[#page.refresh] = ("hub: %s, section %d read again"):format(room.key, i)
			end
		else
			geterrorhandler()(last)
		end
	end
	-- One part on show (by its head's key; the first unless told), the others put away.
	function page:Part(key)
		self.part = key or win.parts[room.key] or self.part or (self.parts[1] and self.parts[1].head.key)
		win.parts[room.key] = self.part
		for _, part in ipairs(self.parts or {}) do
			local on = part.head.key == self.part
			part.head.frame:SetShown(on)
			if part.frame then part.frame:SetShown(on) end
		end
	end
	if page.parts then page:Part() end
	return page
end

-- The scroll area, `down` from the body's top and `room` tall: from the rule's side to the window's right edge,
-- whatever width the room on show is laid out at, so its bar stands at the edge. (Placed again only where it stands
-- otherwise: every room hangs from it, and all of them are laid out again by the game for a place it is given
-- anew, the same one too.)
-- (A guest walking a few pages one at a time has no rail: its page stands in the middle. See Focus.)
local function Focused() return win.guest ~= nil and win.guest.focus == true end

local function Place(down, room)
	local scroll = win.box.scroll
	local left = W.EDGE + W.RAIL + W.PAD - W.IN
	if Focused() then
		left = max(W.PAD - W.IN, math.floor(((win.bodyW or W.WIDTH) - (W.IN + win.pageW + W.SCROLL)) / 2))
	end
	if scroll.shyDown == down and scroll.shyRoom == room and scroll.shyLeft == left then return end
	scroll.shyDown, scroll.shyRoom, scroll.shyLeft = down, room, left
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", win.body, "TOPLEFT", left, down)
	scroll:SetPoint("TOPRIGHT", win.body, "TOPRIGHT", -W.RIGHT, down)
	scroll:SetHeight(room)
end

-- The room on show fitted to the window's height: its scroll area, its own fit (the theme's lists), how tall it
-- stands. `walk`: measured whole, as it shows and once a corner is let go. While a corner is dragged (every frame
-- the mouse moves) nothing is walked or read again: the room takes the height from what it held when last measured.
local function Fit(walk)
	local box, page = win.box, win.pages[win.at]
	local room = Room()
	-- (a bar at the window's foot takes its height off the bottom, so the room ends above it rather than
	-- sliding down under it)
	Place(-(W.HEADER + W.TOP), room)
	if page.Fit then page:Fit(room - (page.lead and UI.LEAD_H or 0)) end
	if walk or page.scrollsItself then return Measure(true) end
	if not page.held then return end
	local tall = max(page.held, room)
	if math.abs(tall - page:GetHeight()) > 1 then page:SetHeight(tall) end
	if math.abs(tall - box.content:GetHeight()) > 0.5 then box.content:SetHeight(tall) end
	box.scroll:Update()
end

-- The room fitted again: a bar come to the window's foot, or gone from it, changes how much room is left.
function Hub.Refit()
	if win.open and win.pages and win.pages[win.at] then Fit() end
end

local function Show()
	local box = win.box
	local lap = debugprofilestop()
	box.rail:Select(win.at, true)
	box.rail:SetSubs(Briefs())
	lap = Lap("hub: the rail told", lap)
	local page = win.pages[win.at]
	-- (Laid out for another width, the window maximized or put back: the room as built for this width when
	-- it last stood at it, else built for it now.)
	if page and page.width ~= win.pageW then
		page:Hide()
		page = win.kept[win.at] and win.kept[win.at][win.pageW]
		if page then
			page.lined = nil   -- (its heads go on the rail again as it is measured)
			win.pages[win.at] = page
		end
	end
	if not page then
		page = OurPage(ROOM[win.at])
		win.pages[win.at] = page
		win.kept[win.at] = win.kept[win.at] or {}
		win.kept[win.at][win.pageW] = page
		lap = Lap("hub: a room made", lap)
	end
	if page.paged then page:Part(win.parts[win.at]) end
	-- A room that scrolls by itself: the window's own scroll stands still, so there is one bar, the room's.
	box.scroll:Rest(page.scrollsItself == true)
	for at, other in pairs(win.pages) do
		if other ~= page then other:Hide() end
	end
	local room = Room()
	Place(-(W.HEADER + W.TOP + win.pageH - room), room)
	if page.Fit then page:Fit(room - (page.lead and UI.LEAD_H or 0)) end
	lap = Lap("hub: the room fitted, the others put away", lap)
	-- (Hidden first: a page builds and refreshes itself as it shows.)
	page:Hide()
	page:Show()
	lap = Lap("hub: a room shown (it builds and reads its settings as it shows)", lap)
	for i, fresh in ipairs(page.refresh or {}) do
		local from = debugprofilestop()
		fresh()
		if page.read and page.read[i] then Lap(page.read[i], from) end
	end
	lap = Lap("hub: a room's sections read again", lap)
	win.glide = nil
	-- (Only where it isn't there: the game lays the whole room out again for a scroll set.)
	local at = box.scroll:GetVerticalScroll()
	if issecretvalue(at) or at ~= 0 then box.scroll:SetVerticalScroll(0) end
	lap = Lap("hub: the room scrolled to its top", lap)
	-- (Just shown: measured again in a moment, as after a press.)
	win.stirred = true
	if win.shown ~= page then
		win.shown = page
		UI.FadeIn(page, W.FADE)
	end
	lap = Lap("hub: the room's fade begun", lap)
	Measure(true)
	Lap("hub: a room measured, its sections on the rail", lap)
end

-- Where a section's head stands in the room, from its top (nil while it can't be read).
local function HeadAt(page, head)
	local top, at = page:GetTop(), head.frame:GetTop()
	if not top or not at or issecretvalue(top) or issecretvalue(at) then return nil end
	return top - at
end

-- A section picked on the rail: the room glides until its head stands near the top (as near as the room goes).
local function Glide(room, key)
	if room ~= win.at then Hub.Open(room) end
	local page, box = win.pages[win.at], win.box
	if page and page.paged then
		page:Part(key)
		box.rail:SetKid(page.part)
		box.scroll:SetVerticalScroll(0)
		for _, fresh in ipairs(page.refresh or {}) do fresh() end
		UI.FadeIn(page, W.FADE)
		Measure(true)
		return
	end
	for _, head in ipairs(page and page.heads or {}) do
		local at = head.key == key and HeadAt(page, head)
		if at then
			local to = max(0, math.min(box.scroll:Range(), at - W.AIR))
			win.glide = { from = box.scroll:At(), to = to, t = 0, key = key }
			-- (The pick, and where the room stands for it: it stays the marked one until the room is scrolled.)
			win.picked = { key = key, at = to, page = page }
			box.rail:SetKid(key)
		end
	end
end

-- The section in view, marked on the rail: the last head at or over the top of the room, or the last of all
-- once the room is scrolled to its foot. (Not while gliding: the pick stays marked.)
-- A section picked on the rail stays the marked one while the room stands where the pick left it. A room
-- only a little taller than the window can't bring every section to its top: it stops at its foot, where
-- the last section would be marked instead of the one picked.
local function InView()
	local page, box = win.pages[win.at], win.box
	if win.guest or win.glide or not (page and page.heads) then return end
	if page.paged then return box.rail:SetKid(page.part) end
	local now, far = box.scroll:At(), box.scroll:Range()
	local pick = win.picked
	if pick then
		if pick.page == page and math.abs(now - pick.at) < 1 then return box.rail:SetKid(pick.key) end
		win.picked = nil
	end
	local key
	for i, head in ipairs(page.heads) do
		local at = HeadAt(page, head)
		if at and (at - now <= W.AIR * 3 or (far > 0 and now >= far - 1 and i == #page.heads)) then key = head.key end
	end
	box.rail:SetKid(key or (page.heads[1] and page.heads[1].key))
end

local function Gliding(elapsed)
	local glide = win.glide
	if not glide then return end
	glide.t = math.min(1, glide.t + elapsed / W.GLIDE)
	local eased = 1 - (1 - glide.t) ^ 3
	win.box.scroll:SetVerticalScroll(glide.from + (glide.to - glide.from) * eased)
	if glide.t >= 1 then win.glide = nil end
end

-- The window flows: taller, the rail, the room and the page on show take the height; wider (a corner let go, or
-- maximized), our rooms stand as laid out for the width there is, in steps of W.STEP up to W.MOST, the scroll
-- area to the window's edge. Nothing is scaled. (width, height: its body's, UI.Body)
-- The step is what a room's width is rounded down to, and so what it leaves unused at its right edge. It is
-- small: a room built for a width is kept, and there are only as many as the widths you rest the corner at.
local function Lay(_, width, height)
	win.bodyW = width or win.bodyW
	win.pageH = height - (W.HEADER + W.TOP + W.FOOT)
	-- (While a corner is dragged the page keeps its width: a room is built for another, and that waits for the
	-- corner to be let go.)
	if not win.sizing then
		local room = (width or W.WIDTH) - (W.EDGE + W.RAIL + W.PAD + W.SCROLL + W.RIGHT)
		win.pageW = max(W.PAGE, math.min(W.MOST, math.floor(room / W.STEP) * W.STEP))
	end
	local box = win.box
	if not (box and box.scroll) then return end
	box.content:SetWidth(W.IN + win.pageW)
	-- (lent: the rail and its rule end at the foot's)
	local rail = win.guest and W.TOP + Room() + W.UNDER or W.TOP + win.pageH + W.FOOT
	box.rail:SetHeight(rail)
	box.rule:SetHeight(rail)
	if win.guest then
		Place(-(W.HEADER + W.TOP), Room())
		win.guest.Lay(win.sizing)
	elseif win.open then
		-- (Shown whole only where it isn't up (back from a guest) or for another width: a height alone is the room
		-- fitted, not read again.)
		local page = win.pages[win.at]
		if not page or page ~= win.shown or page.width ~= win.pageW then
			Show()
		else
			Fit(not win.sizing)
		end
	end
end

function Hub.Size()
	return win.pageW, Room()
end
Hub.IN = W.IN
Hub.PAD = W.PAD   -- (what a bar at the window's foot stands its own words in by, to meet the room's)

-- The rooms as the rail lists them. A room an addon brings (`owned`) is listed only once that addon has filled
-- it, so switching the addon off takes its room with it rather than leaving an empty one (Keys without ShyKeys).
function Hub.Rooms()
	local items = {}
	for _, room in ipairs(ROOMS) do
		if not room.owned or sections[room.key] then
			items[#items + 1] = { key = room.key, label = room.label, glyph = room.glyph }
		end
	end
	return items
end

local function Create()
	local box = UI.Window({
		id = "shyhub", name = "ShyHubWindow", title = B.FAMILY, width = W.WIDTH, height = W.HEIGHT,
		grip = { flow = Lay, min = { W.WIDTH, W.HEIGHT }, max = { W.WIDTH - W.PAGE + W.MOST } },
		-- (lent, the guest may keep it out of sight a while, open still: a fight while setting up)
		point = { "CENTER", "CENTER", 0, 30 }, strata = "HIGH", maximize = true,
		shown = function() return win.open and not (win.guest and win.guest.Away()) end,
		-- (lent, the guest tells whether a hide closed it: the game hides it on a loading screen too)
		onClose = function(self)
			if win.guest then return win.guest.Hidden(self) end
			win.open = false
			Shy:Fire("SHY_HUB_CLOSED")
		end,
		close = function() Hub.Close() end,
		head = { icon = core.mark, brand = "", panel = { glazed = true } },
	})
	win.box = box
	-- Everything under the header stands on the body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)
	win.body = body
	-- The sheet the rooms are read off: from the rule beside the rail to the window's other edges, under the
	-- head. The rail, the head and the edge round them are the housing's, and follow the other setting.
	UI.BodySheet(box, true, { W.EDGE + W.RAIL, W.HEADER, 0, 0 })

	box.rail = UI.Rail(box, function(key)
		if win.guest then win.guest.Go(key) else Hub.Open(key) end
	end, { width = W.RAIL, height = W.TOP + W.PAGE_H + W.FOOT, again = true, onKid = function(room, kid)
		-- (lent: a line under a guest's row is the guest's, a page of its own)
		if win.guest and win.guest.Kid then win.guest.Kid(room, kid) else Glide(room, kid) end
	end })
	box.rail:SetPoint("TOPLEFT", body, "TOPLEFT", W.EDGE, -W.HEADER)
	box.rail:SetItems(Hub.Rooms())
	-- Lent: what the window is doing after its name in the header ("Setting up", your name).
	-- One line in one face (a name's, which writes every alphabet), on the middle the logotype stands on.
	box.mode = UI.Words(box.head, UI.NameFont(14))
	box.mode:SetPoint("LEFT", box.head.title, "RIGHT", 14, 0)
	UI.Themed(box.mode, function()
		local guest = win.guest
		return guest and (UI.Wrap(C.dim, guest.words or "") .. " " .. UI.Wrap(C.head, guest.name or "")) or ""
	end)
	box.mode:Hide()
	-- Lent: the foot the guest's walk stands on, a rule over it across the window.
	local foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 2, 0)
	foot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 0)
	foot:SetHeight(W.WALK)
	-- It runs under the rail and the room alike, so it is a surface of its own: one opaque fill, or the rail's
	-- darker ground and the rule beside it show through and cut the foot in two.
	foot.fill = foot:CreateTexture(nil, "BACKGROUND")
	foot.fill:SetAllPoints()
	Theme.Paint(foot.fill, C.bg, 1)
	foot.rule = foot:CreateTexture(nil, "ARTWORK")
	UI.Paint(foot.rule, C.border, 0.7)
	foot.rule:SetHeight(1)
	foot.rule:SetPoint("TOPLEFT")
	foot.rule:SetPoint("TOPRIGHT")
	foot:Hide()
	box.foot = foot
	box.rule = box:CreateTexture(nil, "ARTWORK")
	UI.Paint(box.rule, C.border, 0.7)
	box.rule:SetWidth(1)
	box.rule:SetPoint("TOPLEFT", body, "TOPLEFT", W.EDGE + W.RAIL, -W.HEADER)
	box.rule:SetHeight(W.TOP + W.PAGE_H + W.FOOT)
	-- The credit, at the rail's foot: the name in the paladin's color, the kind of realm after it, the version under it.
	-- A click opens Tools at its Sources (Credits.lua): who else Shy is built with. Under the mouse its words light.
	local version = UI.Text(box, core.version and ("v" .. core.version) or "", 11, false, C.dim)
	version:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", W.EDGE + 14, 12)
	local credit = UI.Text(box, "", 12, true)
	credit:SetPoint("BOTTOMLEFT", version, "TOPLEFT", 0, 4)
	local function Credit(lit)
		local words = lit and C.text or C.dim
		return UI.Wrap(words, "Made by ") .. UI.Wrap({ Theme.PresetColor("class:PALADIN") }, "Shyce Cream") .. UI.Wrap(words, " (PvP)")
	end
	UI.Themed(credit, function() return Credit(false) end)
	local door = CreateFrame("Button", nil, box)
	door:SetPoint("TOPLEFT", credit, "TOPLEFT", -2, 2)
	door:SetPoint("BOTTOMRIGHT", credit, "BOTTOMRIGHT", 2, -2)
	door:SetScript("OnEnter", function() credit:SetText(Credit(true)) end)
	door:SetScript("OnLeave", function() credit:SetText(Credit(false)) end)
	door:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Hub.OpenAt("tools", Shy.Credits and Shy.Credits.HEAD or "Sources")
	end)
	Hub.credit, Hub.creditDoor = credit, door
	box.credits = { version, credit, door }   -- (put away while lent: the foot stands there)

	box.scroll = UI.ScrollArea(box, W.IN + W.PAGE + W.SCROLL, W.PAGE_H)
	box.content = box.scroll.content
	box.content:SetWidth(W.IN + W.PAGE)

	-- While it is open: the page on show measured, and the rail's words kept up as settings change.
	local measured, told = 0, 0
	box:HookScript("OnUpdate", Shy.Clocked("hub: its frame (the room measured, the rail's words)", function(_, elapsed)
		if not win.open or win.guest then return end
		Gliding(elapsed)
		measured, told = measured + elapsed, told + elapsed
		-- A room's height is another only after something in it is pressed (a section unfolds, a list grows) or
		-- as it comes in: it is measured W.SOON and W.SETTLED seconds after the mouse's button is let go or a
		-- showing, and every W.REST otherwise. (The measuring walks every piece of the room: it took 8 to 11 ms,
		-- five times a second, for as long as the window stood open.)
		local now = GetTime()
		local down = IsMouseButtonDown("LeftButton")
		if win.held and not down then win.stirred = true end
		win.held = down
		if win.stirred then win.stirred, win.soon, win.settled = nil, now + W.SOON, now + W.SETTLED end
		win.rested = (win.rested or 0) + elapsed
		local due = win.rested >= W.REST
		if win.soon and now >= win.soon then win.soon, due = nil, true end
		if win.settled and now >= win.settled then win.settled, due = nil, true end
		if due then
			win.rested = 0
			Measure()
		end
		if measured >= W.MEASURE then
			measured = 0
			InView()
		end
		if told >= W.BRIEFS then
			told = 0
			box.rail:SetSubs(Briefs())
		end
	end))
	-- (A kept height may have been put on before the room was here to take it.)
	Lay(box, UI.BodySize(box))
end

-- A room that isn't there (an addon that told no settings) is Home.
local function Known(room)
	return ROOM[room] and room or "home"
end

function Hub.Open(room)
	-- Lent: brought up as it is; a room asked for ends the guest's walk first.
	if win.guest then
		if room == nil then
			win.open = true
			Shy.HUD.Update(win.box)
			return
		end
		win.guest.Leave()
	end
	-- An addon that told its settings: the Settings room, at them.
	if type(room) == "table" and Settings.told[room.suffix] and Settings.Show then
		Hub.Open("settings")
		Settings.Show(room)
		return
	end
	if room ~= nil then room = Known(room) end
	if not win.box then Create() end
	if room ~= nil then win.at = room end
	win.open = true
	local lap = debugprofilestop()
	Shy.HUD.Update(win.box)
	Lap("hub: its window brought up", lap)
	Show()
end

function Hub.Close()
	if not win.box then return end
	if win.guest then return win.guest.Close() end
	win.open = false
	Shy.HUD.Update(win.box)
end

-- Lent to a guest: our rooms put away, the rail the guest's, the foot open, the header saying what it does.
-- Solid whatever the screen under it does (the guest may hold the screen up: the setup does).
local Focus   -- (made below, with the pips)
function Hub.Lend(guest)
	if not win.box then Create() end
	local box = win.box
	if win.guest ~= guest then
		win.guest, win.glide, win.shown = guest, nil, nil
		for _, page in pairs(win.pages) do
			page:Hide()
			page.lined = nil
		end
		for _, room in ipairs(ROOMS) do box.rail:SetKids(room.key, nil) end
		box.rail:SetItems(guest.items)
		for _, part in ipairs(box.credits) do part:Hide() end
		box.foot:Show()
		box.mode:SetText(UI.Wrap(C.dim, guest.words or "") .. " " .. UI.Wrap(C.head, guest.name or ""))
		box.mode:Show()
		box.content.shyTall = nil
		box.scroll:SetVerticalScroll(0)
		box:SetIgnoreParentAlpha(true)
	end
	win.open = true
	Focus()
	Shy.HUD.Update(box)
	Lay(box, UI.BodySize(box))
	return box
end

function Hub.Lent() return win.guest end

-- Lent to a guest that walks a few pages one at a time (its `focus`): no rail, the sheet from edge to edge, the
-- page in the middle (Place), and where the walk is as named steps in the header (UI.Stepper, as the welcome's).
--   Hub.Pips(names, at, onClick)   the steps, the one at `at` lit, those before it done (onClick(i): back to one);
--                                  none: put away. box.pips: a step each
function Hub.Pips(names, at, onClick)
	local box = win.box
	if not box then return end
	if not box.steps then
		box.steps = UI.Stepper(box.head)
		box.steps:SetPoint("LEFT", box.mode, "RIGHT", 24, 0)
		box.pips = box.steps.items
	end
	box.steps:Set(type(names) == "table" and names or nil, at or 0, onClick)
end

function Focus()
	local box, on = win.box, Focused()
	if box.focused == on then return end
	box.focused = on
	box.rail:SetShown(not on)
	box.rule:SetShown(not on)
	UI.BodySheet(box, true, { on and 0 or W.EDGE + W.RAIL, W.HEADER, 0, 0 })
	if not on then Hub.Pips(0) end
end

-- The guest's rail and header told again (its own walk within its walk: other rows, another title).
function Hub.Retell(guest)
	local box = win.box
	if not box or win.guest ~= guest then return end
	box.rail:SetItems(guest.items)
	box.mode:SetText(UI.Wrap(C.dim, guest.words or "") .. " " .. UI.Wrap(C.head, guest.name or ""))
	Focus()
	Lay(box, UI.BodySize(box))
end

-- shut: closed as it goes back (nothing laid out for a window going away).
function Hub.Return(shut)
	local guest, box = win.guest, win.box
	if not guest then return end
	win.guest, win.shown = nil, nil
	if shut then
		win.open = false
		Shy.HUD.Update(box)
	end
	for _, item in ipairs(guest.items) do
		if item.key then box.rail:SetDone(item.key, false) end
	end
	box.rail:SetItems(Hub.Rooms())
	for _, part in ipairs(box.credits) do part:Show() end
	box.foot:Hide()
	box.mode:Hide()
	box:SetIgnoreParentAlpha(false)
	Focus()
	-- (Home again: where the walk began)
	win.at = "home"
	Lay(box, UI.BodySize(box))
end

-- A room opened at one of its heads, by the head's words (the credit opens Tools at its Sources). The glide waits
-- a frame: the room is laid out as it is shown.
function Hub.OpenAt(room, words)
	Hub.Open(room)
	C_Timer.After(0, function()
		local page = win.pages[win.at]
		for _, head in ipairs(page and page.heads or {}) do
			if head.label == words then return Glide(win.at, head.key) end
		end
	end)
end

function Hub.IsOpen() return win.open end

-- A corner dragged: the window takes the height at once and the width when let go (see Lay).
Shy:On("SHY_HUD_MOVING", function(box)
	if box == win.box then win.sizing = true end
end)
Shy:On("SHY_HUD_MOVED", function(box)
	if box ~= win.box or not win.sizing then return end
	win.sizing = nil
	Lay(box, UI.BodySize(box))
end)

-- Layout mode has the screen to itself (but for a guest's walk, which may send you there and back).
Shy:On("SHY_HUD_LAYOUT", function(on)
	if on and not win.guest then Hub.Close() end
end)

function Addon:OpenOptions()
	Hub.Open(self)
end

-- Home: who you are playing, the two things done most (arranging the screen, setting a character up), then
-- every addon, a click from its settings.

-- RING: the face's ring, its art's size (DialMid, drawn for 40 to 44); FACE: the face inside it.
-- FIRST: the first caption under the band; BELOW: a caption's top to its tiles'; NEXT: the last row to the next caption.
local HOME = { BANNER = 64, EDGE = 3, TILE = 40, GAP = 4, ACROSS = 3, ICON = 32, RING = 42, FACE = 28, FIRST = 40, BELOW = 24,
	NEXT = 26 }

local function First() return (UnitName("player")) end

-- The profile in use, in a word or two: Global, this character's own, another character's (by their name, not
-- the name and realm it is kept under) or a named one.
local function ProfileWords()
	local P = Shy.Profiles
	local name = P.Current()
	if name == P.GLOBAL then return "Global", "the Global profile" end
	if name == P.Character() then return "Only " .. First(), "a profile of your own" end
	local whose = name:match("^(.-) %- ")
	if whose then return whose, whose .. "'s profile" end
	return name, "the " .. name .. " profile"
end

Hub.HOME = HOME

-- A tile: an icon at its left, a name, a line under it cut where the tile ends. Lit under the mouse.
function Hub.Tile(parent, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOME.TILE)
	UI.Skin(b)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(HOME.ICON, HOME.ICON)
	b.icon:SetPoint("LEFT", 6, 0)
	b.name = UI.Text(b, "", 14, true)
	b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, 0)
	b.line = UI.Text(b, "", 11, false, C.dim)
	b.line:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
	b.line:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	b.line:SetWordWrap(false)
	return b
end

local function AddonTile(parent, a, width)
	local b = Hub.Tile(parent, width)
	Theme.Icon(b.icon, a.mark)
	b.name:SetText(a.suffix)
	UI.Ink(b.name, C.head)
	b.line:SetText(a.tagline or "")
	local told = Settings.told[a.suffix] ~= nil and Settings.Show ~= nil
	local usable = told or a.OpenWindow ~= nil
	b:SetAlpha(usable and 1 or 0.5)
	b:SetScript("OnClick", function()
		if not usable then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if told then
			Hub.Open(a)
		else
			Hub.Close()
			a:OpenWindow()
		end
	end)
	-- (The tagline is cut where the tile ends: the hover says it whole, and the version.)
	b:SetScript("OnEnter", function(self)
		if usable then UI.SetBorder(self, C.hot) end
		UI.Tip(self, a.suffix, (a.tagline or "") .. (a.version and ("\n" .. UI.Wrap(C.dim, "v" .. a.version)) or ""))
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.TipHide(self)
	end)
	b.tagline = b.line
	return b
end

-- The band: your character's face in a ring as the game draws it, your name, your level, class and profile under
-- it, an edge down its left in your color. Setting up, the edge is gold: nothing is kept until Finish.
function Hub.Band(parent, width)
	local band = CreateFrame("Frame", nil, parent)
	band:SetSize(width, HOME.BANNER)
	UI.Skin(band, C.row, C.border)
	band.edge = band:CreateTexture(nil, "ARTWORK")
	band.edge:SetPoint("TOPLEFT", 1, -1)
	band.edge:SetPoint("BOTTOMLEFT", 1, 1)
	band.edge:SetWidth(HOME.EDGE)
	Theme.Paint(band.edge, Theme.Accent, 1)
	local ring = band:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(Shy.MEDIA .. "DialMid")
	ring:SetSize(HOME.RING, HOME.RING)
	ring:SetPoint("CENTER", band, "LEFT", HOME.EDGE + 12 + HOME.RING / 2, 0)
	UI.Tint(ring, Theme.skin.metal)
	band.face = band:CreateTexture(nil, "ARTWORK", nil, 1)
	band.face:SetSize(HOME.FACE, HOME.FACE)
	band.face:SetPoint("CENTER", ring, "CENTER")
	local round = band:CreateMaskTexture()
	round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	round:SetAllPoints(band.face)
	band.face:AddMaskTexture(round)
	UI.Concentric(ring, band.face)
	-- A player's name: UI.NameFont covers every alphabet.
	local who = UI.Words(band, UI.NameFont(18), C.head, { wrap = false })
	who:SetPoint("TOPLEFT", HOME.EDGE + 12 + HOME.RING + 10, -13)
	who:SetPoint("RIGHT", band, "RIGHT", -16, 0)
	local what = UI.Text(band, "", 12, false, C.dim)
	what:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -5)
	what:SetPoint("RIGHT", band, "RIGHT", -16, 0)
	what:SetWordWrap(false)
	band.who, band.what = who, what
	function band:Tell(setup)
		Theme.Paint(self.edge, setup and C.alert or Theme.Accent, 1)
		SetPortraitTexture(self.face, "player")
		self.who:SetText(First())
		local _, profile = ProfileWords()
		self.what:SetText(("level %d %s  \194\183  on %s"):format(UnitLevel("player"), (UnitClass("player")), profile))
	end
	-- (The words end before what stands at the band's right: a long profile's name is cut there.)
	function band:EndAt(frame)
		self.who:SetPoint("RIGHT", frame, "LEFT", -16, 0)
		self.what:SetPoint("RIGHT", frame, "LEFT", -16, 0)
	end
	return band
end

-- What applies when, under the band: in /shy as you pick; setting up, nothing until Finish.
Hub.LIVE = "Anything you change here happens right away."

function Build.home(page)
	local S = Shy.Setup
	local banner = Hub.Band(page, page.width)
	banner:SetPoint("TOPLEFT")

	local arrange = Shy.HUD.LayoutButton(banner, 130)
	arrange:SetHeight(30)
	arrange:SetPoint("RIGHT", -16, 0)
	Help(arrange, "Layout mode", "Move the game's pieces and the addons' in one editor. Click a piece for its settings.")
	local setup
	if S and S.Open then
		setup = UI.Button(banner, "Set up " .. First(), 150, function() S.Start() end)
		setup:SetHeight(30)
		setup:SetPoint("RIGHT", arrange, "LEFT", -8, 0)
	end
	banner:EndAt(setup or arrange)
	local state = UI.Text(page, "", 11, false, C.dim)
	state:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", HOME.EDGE + 16, -7)
	state:SetWidth(page.width - 2 * (HOME.EDGE + 16))
	state:SetWordWrap(false)

	-- Every addon, a caption for each category and its tiles under it, by name (Shy.Listed); each caption a
	-- click from the rail.
	local each = (page.width - (HOME.ACROSS - 1) * HOME.GAP * 2) / HOME.ACROSS
	local y, head = HOME.FIRST, nil
	Hub.tiles = {}
	for _, group in ipairs(Shy.Listed()) do
		local caption = Shy.HubHead(page, banner, group.title)
		caption:ClearAllPoints()
		caption:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -y)
		head = head or caption
		y = y + HOME.BELOW
		for i, a in ipairs(group.addons) do
			local tile = AddonTile(page, a, each)
			tile:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", ((i - 1) % HOME.ACROSS) * (each + HOME.GAP * 2),
				-(y + math.floor((i - 1) / HOME.ACROSS) * (HOME.TILE + HOME.GAP)))
			Hub.tiles[#Hub.tiles + 1] = tile
		end
		y = y + math.ceil(#group.addons / HOME.ACROSS) * (HOME.TILE + HOME.GAP) - HOME.GAP + HOME.NEXT
	end
	if not head then
		head = Shy.HubHead(page, banner, "Your addons")
		head:ClearAllPoints()
		head:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -HOME.FIRST)
		local none = UI.Text(page, "No addons loaded. Enable them in the AddOns list.", 13, false, C.dim)
		none:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
	end
	-- Whether the addons' data was made for this game (Client.lua), at the first caption's right, where its rule
	-- ends: quiet when it was.
	local data = UI.Text(head, "", 11, false, C.dim)
	data:SetPoint("RIGHT")
	Hub.dataLine = data

	page.refresh[#page.refresh + 1] = function()
		banner:Tell(false)
		-- The one to press stands filled: setting up until that is done, arranging the screen after.
		local done = not setup or S.Done()
		arrange:SetPrimary(done)
		if setup then setup:SetPrimary(not done) end
		state:SetText(not setup and Hub.LIVE or done and (Hub.LIVE .. " Set up again to change profile, layout and game settings in one go.")
			or (Hub.LIVE .. " " .. First() .. " isn't set up yet. It only takes a few clicks and one reload."))
		local words, color
		if Shy.DataCheck then words, color = Shy.DataCheck.Words() end
		data:SetText(words or "")
		UI.Ink(data, color or C.dim)
		head.rule:SetPoint("RIGHT", head, "RIGHT", words and -(data:GetStringWidth() + 10) or 0, 0)
	end
end

Shy.HubBrief("home", function()
	local count = 0
	for _, a in ipairs(Shy.order) do
		if not a.internal then count = count + 1 end
	end
	return count == 1 and "1 addon" or (count .. " addons")
end)

-- Screen: where everything stands. Its size and the console are other files' sections.

Shy.HubSection("screen", function(page, top)
	local head = Shy.HubHead(page, top, "Layout")
	local arrange = Shy.HUD.LayoutButton(page, 180)
	arrange:SetHeight(30)
	arrange:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
	local words = UI.Text(page, "Move the game's pieces and the addons' in one editor. Click a piece for its settings. Addon pieces are saved with each Edit Mode layout.", 12, false, C.dim)
	words:SetPoint("TOPLEFT", arrange, "TOPRIGHT", 14, 2)
	words:SetWidth(page.width - 180 - 14)
	words:SetWordWrap(true)
	return arrange
end, 20)

-- Profiles (Core.lua, "Profiles")

function Build.profiles(page, top)
	local P = Shy.Profiles
	local COL, RIGHT = 260, 306
	local Label = P.Label
	-- `others`: only existing profiles other than the one in use.
	local function Items(others)
		local items = {}
		for _, entry in ipairs(P.List()) do
			if not others or not (entry.current or entry.new) then items[#items + 1] = { value = entry.name, text = Label(entry) } end
		end
		return items
	end

	local group = UI.Group()
	local picked, typed = nil, ""
	local uses, other

	local function Relist()
		local others, still = Items(true), false
		for _, item in ipairs(others) do
			if item.value == picked then still = true end
		end
		if not still then picked = others[1] and others[1].value end
		uses:SetItems(Items())
		other:SetItems(others)
		group:Refresh()
	end

	uses = group:Dropdown(page, "This character uses", Items(), P.Current, function(name)
		if P.Use(name) then
			Shy.Reload("You've switched profiles. Reload to finish.")
		else
			Relist()   -- the character's own profile, created from current settings: no reload
		end
	end, { width = COL, desc = "A profile saves all your addon settings and your layout. Every character uses Global unless you pick another. Switching to a profile you already have needs a reload." })
	uses:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, -8)

	local words = UI.Text(page, "Characters on the same profile share all settings. Give this character its own, or name one to share between a few (your healers, for example).", 12, false, C.dim)
	words:SetPoint("TOPLEFT", uses, "TOPLEFT", RIGHT, -4)
	words:SetWidth(page.width - RIGHT)
	words:SetWordWrap(true)

	local name = group:Input(page, "New profile", function() return typed end, function(v) typed = v end,
		{ width = 170, maxLetters = 24, placeholder = function() return "Name" end,
			desc = "Creates a profile from your current settings and switches this character to it. No reload needed." })
	name:SetPoint("TOPLEFT", uses, "BOTTOMLEFT", 0, -14)
	local create = UI.Button(page, "Create", 80, function()
		name.box:ClearFocus()   -- commits the typed text
		local wanted = strtrim(typed)
		local ok, why = P.Create(wanted)
		if not ok then
			core:Print(why == "empty" and "enter a name for the new profile." or ("there is already a profile called " .. wanted .. "."))
			return
		end
		core:Print("you're on profile " .. wanted .. " now, a copy of your current settings.")
		typed = ""
		Relist()
	end)
	create:SetPoint("BOTTOMLEFT", name, "BOTTOMRIGHT", 10, 0)

	other = group:Dropdown(page, "Another profile", Items(true), function() return picked end, function(v) picked = v end,
		{ width = COL, enabled = function() return picked ~= nil end,
			desc = "Pick a profile to copy from or delete." })
	other:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -14)

	local copy = UI.Button(page, "Copy it here", 110, function() end)
	copy:SetPoint("BOTTOMLEFT", other, "BOTTOMRIGHT", 10, 0)
	Help(copy, "Copy it here", "Replaces this profile's settings with the picked profile's, then asks for a reload.")
	UI.Twice(copy, function()
		if picked and P.CopyFrom(picked) then
			Shy.Reload("The settings are copied. Reload to use them.")
		end
	end)
	function copy:Refresh() self:SetUsable(picked ~= nil) end
	group:Add(copy)

	local delete = UI.Button(page, "Delete it", 90, function() end)
	delete:SetPoint("LEFT", copy, "RIGHT", 8, 0)
	Help(delete, "Delete it", "Deletes the picked profile. Characters that used it go back to Global.")
	UI.Twice(delete, function()
		local gone = picked
		if not (gone and P.Delete(gone)) then return end
		core:Print("deleted profile " .. gone .. ". Characters that used it are back on Global.")
		Relist()
	end)
	function delete:Refresh() self:SetUsable(picked ~= nil and picked ~= P.GLOBAL) end   -- Global can't be deleted
	group:Add(delete)

	page.refresh[#page.refresh + 1] = Relist
	return other
end

Shy.HubBrief("profiles", function() return (ProfileWords()) end)

-- Tools: what to reach for when something looks wrong, and the core's commands. (An addon's commands are
-- listed with its settings.)

function Build.tools(page, top)
	-- The task manager, the Lua errors kept in a bag (Errors.lua) and who else runs these addons.
	local wrong = Shy.HubHead(page, top, "When something looks wrong")
	local monitor = UI.Button(page, "Task manager", 130, function()
		Hub.Close()
		Shy.Monitor()
	end)
	monitor:SetPoint("TOPLEFT", wrong, "BOTTOMLEFT", 0, -10)
	Help(monitor, "Task manager", "What each addon costs your game: frame time, memory and errors, down to the exact piece of code behind a number.")
	local last = monitor
	if Shy.Errors then
		local E = Shy.Errors
		local report = UI.Button(page, "Errors caught", 130, function()
			Hub.Close()
			E.Open()
		end)
		report:SetPoint("LEFT", last, "RIGHT", 10, 0)
		last = report
	end
	local ping = UI.Button(page, "Version check", 130, function() Shy.Ping() end)
	ping:SetPoint("LEFT", last, "RIGHT", 10, 0)
	Help(ping, "Version check", "Asks your raid, party or guild which of these addons they run.")

	local cmds = Shy.HubHead(page, monitor, "Commands")
	local lines = { "|cffffd200/shy|r  open this window", "|cffffd200/set|r  find a setting" }
	for _, command in ipairs(listed) do
		if not command.addon then lines[#lines + 1] = "|cffffd200/shy " .. command.word .. "|r  " .. command.help end
	end
	-- Two columns: the list is long and each line short.
	local half = math.ceil(#lines / 2)
	local left = UI.Text(page, table.concat(lines, "\n", 1, half), 12)
	left:SetSpacing(4)
	left:SetPoint("TOPLEFT", cmds, "BOTTOMLEFT", 0, -10)
	left:SetWidth(page.width / 2 - 10)
	left:SetWordWrap(false)
	local right = UI.Text(page, table.concat(lines, "\n", half + 1), 12)
	right:SetSpacing(4)
	right:SetPoint("TOPLEFT", cmds, "BOTTOMLEFT", page.width / 2 + 10, -10)
	right:SetWidth(page.width / 2 - 10)
	right:SetWordWrap(false)
	local more = UI.Text(page, "Each addon's own commands are listed with its settings.", 12, false, C.dim)
	more:SetPoint("TOPLEFT", left, "BOTTOMLEFT", 0, -14)
	return more
end

-- The core's own settings, in the Settings room with everyone's.
core:Settings({
	apply = function()
		if Shy.UpdateMinimapButton then Shy.UpdateMinimapButton() end
	end,
	{ key = "splash", label = "Login splash", desc = "Shows the logo for a few seconds when you log in." },
	{ label = "See the splash", button = "Show it", sub = true, run = function() B.ShowSplash() end },
	{ key = "minimap", label = "Minimap button", desc = "Click it to open this window. Right-click it for your addons." },
	{ key = "gather", label = "Gather addon buttons", sub = true, default = true, words = "minimap buttons tidy collect",
		get = function() return core.db.gather ~= false end,
		enabled = function() return core.db.minimap end,
		desc = "Tucks other addons' minimap buttons into this button's right-click menu." },
	{ key = "rest", label = "Hover delay", min = 0, max = 3, step = 0.1, words = "tooltip wait",
		get = function() return math.floor(core.db.rest * 10 + 0.5) / 10 end,
		set = function(v) core.db.rest = math.floor(v * 10 + 0.5) / 10 end,
		format = function(v) return v == 0 and "At once" or string.format("%.1f s", v) end,
		desc = "How long you hover before a tooltip shows more. Hold Shift to see it all at once." },
	{ label = "Game's error window", default = false, words = "lua errors popup bug",
		shown = function() return Shy.Errors ~= nil end,
		get = function() return Shy.Errors.Popup() end, set = function(v) Shy.Errors.SetPopup(v) end,
		desc = "Addon errors also open the game's error window. With this off, they only go to Errors caught." },

	-- How threat is read for you: one pick for the meter, the nameplates and a class's own warnings. Told here,
	-- once, and only while something of yours shows threat.
	{ section = "Threat", shown = function() return Shy.addons.Threat ~= nil or Shy.addons.Plates ~= nil or Shy.addons.Warrior ~= nil end },
	{ key = "threat.role", label = "You are", words = "tank dps healer role aggro",
		items = { { value = "auto", text = "By your role" }, { value = "tank", text = "The tank" }, { value = "dps", text = "Not the tank" } },
		get = function() return Shy.ThreatRolePick() end, set = function(v) Shy.SetThreatRole(v) end,
		-- (By your role: what that is read as right now.)
		says = function() return Shy.ThreatRolePick() == "auto" and Shy.RoleSays and Shy.RoleSays() or nil end,
		desc = "Whether a mob on you is good news or bad. It colors threat everywhere it shows." },
	-- (It sounds only while something reads the mobs: the threat meter, a class's own warning.)
	{ key = "threat.sound", label = "Aggro sound", words = "warning alarm pull",
		enabled = function()
			if Shy.Aggro and Shy.Aggro.Watched and Shy.Aggro.Watched() then return true end
			return false, "Nothing of yours is watching threat right now."
		end,
		get = function() return Shy.ThreatSound() end, set = function(v) Shy.SetThreatSound(v) end,
		desc = "Plays a warning when you pull aggro, or lose it while you tank." },
})
-- (Picked on the meter's menu or a nameplate's too: the list reads again.)
Shy:On("SHY_THREAT_ROLE", function() Settings.Refresh() end)
Shy:On("SHY_THREAT_SOUND", function() Settings.Refresh() end)

-- What the window's other rooms hold, so the search finds it and a click goes there.
do
	local Door = Settings.Door
	Door("theme", "Ready-made themes", "Pick a whole look in one click.", "preset look style skin")
	Door("theme", "Your color", "The accent color, or a blend of several.", "accent hue saturation lightness class color gradient")
	Door("theme", "Text", "The font and its shadow.", "font typeface shadow outline")
	Door("theme", "Icons", "Their shape, frames and wells.", "icon shape round square slot border")
	Door("theme", "Bar fill", "How health and power bars are filled.", "texture statusbar")
	Door("theme", "Your health color", "What color your own health bar is.", "health bar class color")
	Door("theme", "Background", "How see-through panels and windows are.", "opacity transparency alpha strength")
	Door("screen", "Size", "How big everything is.", "ui scale zoom bigger smaller")
	Door("screen", "Layout", "Move anything on your screen.", "layout mode edit mode position unlock drag", "Layout")
	Door("play", "Waypoint arrow", "Points the way to your next step and says how far it is.", "arrow direction distance")
	Door("play", "Fade HUD when idle", "The HUD fades while nothing is happening.", "immersive hide ui immersion")
	Door("play", "Voices", "People speak their lines aloud.", "voice over spoken quest text")
	Door("play", "Quest text size", "How big a quest giver's words are.", "font size dialog")
	Door("play", "Camera", "How the camera follows you.", "slopes map fade tilt")
	Door("keys", "Your keys", "Your class's abilities on your keys.", "keybinds hotkeys bindings action bars")
	Door("profiles", "Profile", "Which settings this character uses, and copies of them.", "profile character global copy delete create")
	Door("tools", "Task manager", "What each addon costs your game.", "performance fps memory cpu monitor")
	Door("tools", "Errors caught", "The addon errors kept so far.", "lua error bug report")
	Door("tools", "Version check", "Ask your group or guild who runs these addons.", "ping version")
end

Shy.HubBrief("tools", function()
	return core.version and ("v" .. core.version) or nil
end)

-- Version check: "PING" to the group; each copy whispers back its addon list.

local function MyAddons()
	local out = {}
	for _, a in ipairs(Shy.order) do out[#out + 1] = a.name .. " " .. (a.version or "?") end
	return table.concat(out, ", ")
end

function Shy.Ping()
	local channel = Shy.GroupChannel()
	if not channel then
		core:Print("you're not in a group or guild, so there is nobody to ask.")
		return
	end
	core:Print("asking your " .. channel:lower() .. "...")
	core:SendComm("PING", channel)
end

function core:OnComm(msg, sender, channel)
	if Shy.IsMe(sender) then return end
	local cmd, body = msg:match("^(%u+)\t?(.*)$")
	if cmd == "PING" then
		self:SendComm("PONG\t" .. MyAddons(), "WHISPER", sender)
	elseif cmd == "PONG" then
		self:Print("|cffffffff" .. Ambiguate(sender, "short") .. "|r runs " .. body)
	end
end

-- Login splash and /shy

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self, _, isInitialLogin)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if isInitialLogin == false or not core.db.splash then return end   -- not on /reload
	C_Timer.After(1.5, B.ShowSplash)
end)

local function Layout() Shy.HUD.SetUnlocked(not Shy.HUD.IsUnlocked()) end
Shy.Command("splash", "show the splash", function() B.ShowSplash() end)
Shy.Command("ping", "ask your group or guild who runs these addons", function() Shy.Ping() end)
Shy.Command("minimap", "show or hide the minimap button", function()
	core.db.minimap = not core.db.minimap
	Shy.UpdateMinimapButton()
	if win.open then Show() end
end)
Shy.Command("layout", "move anything on your screen", Layout)
Shy.Command("move", nil, Layout)

-- For testing out of a fight: the game's limits on addons (secret values and all) forced on, one setting
-- per kind of limit, each by the name of its kind in Enum.AddOnRestrictionType. Not listed in the window.
-- A client may lack any of them, or refuse to have it set: the copy box says which.
local FORCED = { Combat = "addonCombatRestrictionsForced", Encounter = "addonEncounterRestrictionsForced",
	ChallengeMode = "addonChallengeModeRestrictionsForced", PvPMatch = "addonPvPMatchRestrictionsForced",
	Map = "addonMapRestrictionsForced", Chat = "addonChatRestrictionsForced" }
local FORCED_ORDER = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map", "Chat" }

function Shy.Secrets(on)
	local lines, have, took = {}, 0, 0
	for _, kind in ipairs(FORCED_ORDER) do
		local setting = FORCED[kind]
		local line
		if C_CVar.GetCVar(setting) == nil then
			line = setting .. ": not in this client"
		else
			have = have + 1
			if on ~= nil then C_CVar.SetCVar(setting, on and "1" or "0") end
			local now = C_CVar.GetCVar(setting)
			if on ~= nil and now == (on and "1" or "0") then took = took + 1 end
			line = setting .. " = " .. tostring(now)
		end
		local active = C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType[kind])
		line = line .. "; " .. kind .. " limits " .. (issecretvalue(active) and "secret" or (active and "active" or "not active"))
		lines[#lines + 1] = line
	end
	local head = on == nil and "Addon limits forced" or ("Addon limits forced %s: %d of %d settings took it, %d not in this client.")
		:format(on and "on" or "off", took, have, #FORCED_ORDER - have)
	table.insert(lines, 1, head)
	table.insert(lines, 2, "")
	local text = table.concat(lines, "\n")
	UI.ShowCopyBox(B.FAMILY .. ": addon limits", text)
	return text
end
Shy.Command("secrets", nil, function() Shy.Secrets() end)
Shy.Command("secrets on", nil, function() Shy.Secrets(true) end)
Shy.Command("secrets off", nil, function() Shy.Secrets(false) end)

-- The task manager (ShyMonitor, loaded when first asked for): what every addon costs the game, from all
-- of them down to the one handler behind a number. `view` and `key` are its ("addons", "addon" with a
-- name, "errors"); nothing given opens it at all addons.
local function MonitorLoaded()
	local addon = Shy.addons.Monitor
	if not addon then
		local loaded, why = C_AddOns.LoadAddOn("ShyMonitor")
		addon = Shy.addons.Monitor
		if not (loaded and addon) then
			Shy.core:Print("the task manager could not load" .. (why and (": " .. tostring(why):lower()) or "."))
			return nil
		end
	end
	return addon
end
function Shy.Monitor(view, key)
	local addon = MonitorLoaded()
	if not addon then return false end
	addon:Open(view, key)
	return true
end
-- /shy monitor: its window, opened or closed. With an addon's name, at that addon; "errors", the errors caught.
Shy.Command("monitor", "what each addon costs your game", function(rest)
	local addon = MonitorLoaded()
	if not addon then return end
	if addon.Ask then addon:Ask(rest) else addon:Open() end
end)
-- The census (Core.lua): the scripts no clock times, timed for the task manager, for one session. Asked for, it
-- runs after this reload and is off again at the next; asked while it runs, the reload ends it.
-- (For finding faults. Not listed.)
Shy.Command("census", nil, function()
	local on = not Shy.Census()
	Shy.SetCensus(on)
	Shy.Reload(on and "The task manager will list every script with no clock of its own, until you next reload." or "The task manager goes back to its own clocks.")
end)

-- /shy: a command and what was typed after it, a room or an addon by its name, anything else looked for in the
-- settings; nothing typed, the window where it was.
local function Words(typed)
	local words, ends = {}, {}
	for word, stop in typed:gmatch("(%S+)()") do
		words[#words + 1], ends[#ends + 1] = word:lower(), stop
	end
	return words, ends
end

local function AddonNamed(word)
	for _, a in ipairs(Shy.order) do
		if not a.internal and a.suffix:lower() == word then return a end
	end
end

function Hub.Run(input)
	local typed = strtrim(input or "")
	local words, ends = Words(typed)
	for k = #words, 1, -1 do
		local command = commands[table.concat(words, " ", 1, k)]
		local rest = command and strtrim(typed:sub(ends[k]))
		if command and not (command.bare and rest ~= "") then
			command.fn(rest)
			return
		end
	end
	local word = words[1]
	if not word then
		Hub.Open()
	elseif #words == 1 and ROOM[word] and (not ROOM[word].owned or sections[word]) then
		Hub.Open(word)
	elseif #words == 1 and AddonNamed(word) then
		Hub.Open(AddonNamed(word))
	elseif Settings.Find then
		Settings.Find(typed)
	else
		Hub.Open()
	end
end

SLASH_SHY1 = "/shy"
SlashCmdList.SHY = function(input) Hub.Run(input) end

-- /set: the settings, at what was typed after it.
local function Set(rest)
	if Settings.Find then Settings.Find(rest or "") else Hub.Open() end
end
Shy.Command("settings", "find a setting", Set)
SLASH_SHYSET1 = "/set"
SlashCmdList.SHYSET = function(input) Set(strtrim(input or "")) end
