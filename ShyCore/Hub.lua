-- The hub: the Shy window (/shy), where every setting has one home. A rail of rooms down its left with what each
-- holds now, the room on show beside it; an addon's own options are a room too, come to from Home. Also options
-- registration, /shy and its commands, the login splash and the version ping.
--
--   Shy.Hub.Open(room)       the window: at a room ("home", "theme", "screen", "play", "keys", "game", "profiles",
--                            "tools"), at an addon's options (the addon), or where it was
--   Shy.Hub.Close()          Shy.Hub.IsOpen()
--   Shy.HubSection(room, build, order)   a section of a room, under those before it (lower orders first; 50
--                            unless told). build(page, top) stands it under `top` (Shy.HubHead, Shy.HubPlace)
--                            and returns its last frame and a function that refreshes it; page.width is the
--                            room's. Built when the room first shows, after every addon has loaded
--   Shy.HubHead(page, top, text)    a section's caption, under what stands above it; returns its frame. A room's
--                            captions hang under its row on the rail while it is open, each a click from its section
--   Shy.HubPlace(page, frame, top)  a section with no caption, under what stands above it
--   Shy.HubBrief(room, fn)   what a room holds now in a few words, under its name on the rail
--   Shy.Command(word, help, fn)     /shy <word>; with `help`, listed in the Tools room
--   T:RegisterOptions(page)  an addon's options: a room of the window, built as it first shows (its OnShow)
--   T:OpenOptions()          the window at them
local Shy = Shy
local B, UI, Theme = Shy.Brand, Shy.UI, Shy.Theme
local Addon, core = Shy.AddonPrototype, Shy.core
local C = UI.colors
local max = math.max
core.tagline = "Theme, layout and profiles for every addon"

local Hub = {}
Shy.Hub = Hub

-- The game's own Options list Shy once: a page whose button opens the window.
local door = CreateFrame("Frame")
door:Hide()
local function DoorName()
	return B.Icon(Shy.SMALL_ICON, 16) .. " " .. B.Gradient("Shy")
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
	local words = UI.Text(self, "Every setting has a window of its own. /shy opens it too.", 12, false, C.dim)
	words:SetPoint("LEFT", open, "RIGHT", 14, 0)
end)

-- The window: the rail flush with its left edge, a rule, then the room. An addon's page stands a little to the
-- left of ours (IN): its own margin is inside it. The room flows taller with the window, never wider.
-- GLIDE: seconds the room takes to glide to a section picked on the rail; AIR: room left over a section's head
-- there, and how near the top a head counts as the one in view.
local W = { EDGE = 2, RAIL = 220, PAD = 28, IN = 24, PAGE = 700, SCROLL = 14, RIGHT = 22, TOP = 16, FOOT = 14, PAGE_H = 580,
	BAR = 26, BAR_GAP = 10, FADE = 0.15, MEASURE = 0.2, SOON = 0.05, SETTLED = 0.5, REST = 4, BRIEFS = 0.5, GLIDE = 0.28, AIR = 10, MOST = 1000 }
-- MOST: the widest a room flows to (maximized), the width the setup window's pages are laid out at, so every
-- shared section is known to stand there.
W.HEADER = UI.HEAD.main.line + UI.LINE
W.WIDTH = W.EDGE + W.RAIL + W.PAD + W.PAGE + W.SCROLL + W.RIGHT
W.HEIGHT = W.HEADER + W.TOP + W.PAGE_H + W.FOOT

local ROOMS = {
	{ key = "home", label = "Home", glyph = "home" },
	{ key = "theme", label = "Theme", glyph = "star", ask = "Theme",
		lead = "A whole theme at once, or any part made yours. Your screen follows as you pick." },
	{ key = "screen", label = "Screen", glyph = "window", ask = "Your screen",
		lead = "How large everything is, and where it all stands." },
	{ key = "play", label = "Play", glyph = "book", ask = "How you play",
		lead = "How you get quests and how much UI stays on screen." },
	{ key = "keys", label = "Keys", glyph = "action", ask = "Your keys",
		lead = "Every ability on a key, laid out around how you move. Nothing changes until you lay them out." },
	{ key = "game", label = "Game", glyph = "log", ask = "Game settings",
		lead = "Ticking one applies it now; unticking gives back what you had. Each is in the game's own options too." },
	{ key = "profiles", label = "Profiles", glyph = "group", ask = "Profiles",
		lead = "A profile holds every addon's settings and your layout." },
	{ key = "tools", label = "Tools", glyph = "use", ask = "Tools",
		lead = "The minimap button, the splash, and what to reach for when something looks wrong." },
}
local ROOM = {}
for _, room in ipairs(ROOMS) do ROOM[room.key] = room end

-- at: the room on show, a key or an addon; pages: each room's page, by the same.
local win = { open = false, at = "home", pages = {}, pageH = W.PAGE_H, pageW = W.PAGE }

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

function Shy.Command(word, help, fn)
	commands[word] = fn
	if help then listed[#listed + 1] = { word = word, help = help } end
end

function Shy.HubHead(page, top, text)
	local f = CreateFrame("Frame", nil, page)
	f:SetSize(page.width, 14)
	f:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, top == page.origin and -6 or -26)
	page.heads = page.heads or {}
	page.heads[#page.heads + 1] = { key = "head" .. (#page.heads + 1), label = text, frame = f }
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

function Shy.HubPlace(page, frame, top)
	frame:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, top == page.origin and -6 or -24)
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

-- The room an open page has: the window's, less the strip over an addon's.
local function Room()
	return win.pageH - (type(win.at) == "table" and W.BAR + W.BAR_GAP or 0)
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
	if not page or page.scrollsItself then return end
	local room = Room()
	local top, bottom = page:GetTop(), page:GetBottom()
	if not top or issecretvalue(top) or issecretvalue(bottom) then return end
	local stands = StandsChild(StandsRegion(0, top, page:GetRegions()), top, 2, page:GetChildren())
	if not whole and page.stood and math.abs(stands - page.stood) < 0.5 then return end
	page.stood = stands
	local held = top - Lowest(page, top, bottom) + 20
	local tall = max(held, room)
	-- A room's sections stand on the rail, to go to, only where the room is taller than the window shows:
	-- with all of it in sight there is nowhere to go, and the lines under its row are only in the way.
	-- (Less the 20 of air under the last piece: that the room scrolls by its air alone hides nothing.)
	local lined = type(win.at) ~= "table" and page.heads ~= nil and #page.heads > 1 and held - 20 > room + 1
	if page.lined ~= lined then
		page.lined = lined
		if type(win.at) ~= "table" then box.rail:SetKids(win.at, lined and page.heads or nil) end
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
	page.width, page.refresh = win.pageW, {}
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
	for i, section in ipairs(list) do
		local ok, last, fresh = pcall(section.build, page, top)
		from = Lap(("hub: %s, section %d made"):format(room.key, i), from)
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
	return page
end

-- An addon's: its own frame, seated in the room. One with a scroll area of its own fills the room instead of
-- standing on ours: nested scroll areas fight over the wheel.
local function TheirPage(addon)
	local box, page = win.box, addon.options
	page:Hide()
	page:ClearAllPoints()
	if page.scrollsItself then
		page:SetParent(box)
		page:SetPoint("TOPLEFT", box.scroll, "TOPLEFT")
		page:SetPoint("BOTTOMRIGHT", box.scroll, "BOTTOMRIGHT", -W.SCROLL, 0)
	else
		page:SetParent(box.content)
		page:SetPoint("TOPLEFT")
		page:SetSize(W.IN + W.PAGE, Room())
	end
	return page
end

local function Show()
	local box = win.box
	local addon = type(win.at) == "table" and win.at or nil
	local lap = debugprofilestop()
	box.rail:Select(addon and "home" or win.at, true)
	box.rail:SetSubs(Briefs())
	lap = Lap("hub: the rail told", lap)
	local page = win.pages[win.at]
	-- (one of ours laid out for another width, the window maximized or put back: laid out again for this one)
	if page and not addon and page.width ~= win.pageW then
		page:Hide()
		page = nil
	end
	if not page then
		page = addon and TheirPage(addon) or OurPage(ROOM[win.at])
		win.pages[win.at] = page
		lap = Lap("hub: a room made", lap)
	end
	-- The strip over an addon's page: back to all of them, its window, its defaults.
	local room = Room()
	box.bar:SetShown(addon ~= nil)
	if addon then
		box.bar.open:SetShown(addon.OpenWindow ~= nil)
		box.bar.defaults:SetShown(page.OnDefault ~= nil)
	end
	-- (Placed again only where it stands otherwise: every room hangs from it, and all of them are laid out
	-- again by the game for a place it is given anew, the same one too.)
	local down = -(W.HEADER + W.TOP + win.pageH - room)
	if box.scroll.shyDown ~= down or box.scroll.shyRoom ~= room then
		box.scroll.shyDown, box.scroll.shyRoom = down, room
		box.scroll:ClearAllPoints()
		box.scroll:SetPoint("TOPLEFT", W.EDGE + W.RAIL + W.PAD - W.IN, down)
		box.scroll:SetHeight(room)
	end
	for at, other in pairs(win.pages) do
		if other ~= page then other:Hide() end
	end
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
	for _, head in ipairs(page and page.heads or {}) do
		local at = head.key == key and HeadAt(page, head)
		if at then
			local to = max(0, math.min(box.scroll:Range(), at - W.AIR))
			win.glide = { from = box.scroll:At(), to = to, t = 0, key = key }
			box.rail:SetKid(key)
		end
	end
end

-- The section in view, marked on the rail: the last head at or over the top of the room, or the last of all
-- once the room is scrolled to its foot. (Not while gliding: the pick stays marked.)
local function InView()
	local page, box = win.pages[win.at], win.box
	if win.glide or not (page and page.heads) or type(win.at) == "table" then return end
	local now, far = box.scroll:At(), box.scroll:Range()
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

-- The window flows: taller, the rail, the room and the page on show take the height; wider (maximized), our
-- rooms are laid out again at the width there is, up to W.MOST. Nothing is scaled.
local function Lay(_, width, height)
	win.pageH = height - (W.HEADER + W.TOP + W.FOOT)
	local room = (width or W.WIDTH) - (W.EDGE + W.RAIL + W.PAD + W.SCROLL + W.RIGHT)
	win.pageW = max(W.PAGE, math.min(W.MOST, math.floor(room)))
	local box = win.box
	if not (box and box.scroll) then return end
	box.scroll:SetWidth(W.IN + win.pageW + W.SCROLL)
	box.content:SetWidth(W.IN + win.pageW)
	box.rail:SetHeight(W.TOP + win.pageH + W.FOOT)
	box.rule:SetHeight(W.TOP + win.pageH + W.FOOT)
	if win.open then Show() end
end

local function Create()
	local box = UI.Window({
		id = "shyhub", name = "ShyHubWindow", title = "Shy", width = W.WIDTH, height = W.HEIGHT,
		grip = { flow = Lay, min = { W.WIDTH, W.HEIGHT }, max = { W.WIDTH } },
		point = { "CENTER", "CENTER", 0, 30 }, shown = function() return win.open end, strata = "HIGH", maximize = true,
		onClose = function() win.open = false end,
		close = function() Hub.Close() end,
		head = { icon = Shy.ICON, brand = "" },
	})
	win.box = box

	local items = {}
	for i, room in ipairs(ROOMS) do items[i] = { key = room.key, label = room.label, glyph = room.glyph } end
	box.rail = UI.Rail(box, function(key) Hub.Open(key) end, { width = W.RAIL, height = W.TOP + W.PAGE_H + W.FOOT, again = true,
		onKid = Glide })
	box.rail:SetPoint("TOPLEFT", W.EDGE, -W.HEADER)
	box.rail:SetItems(items)
	box.rule = box:CreateTexture(nil, "ARTWORK")
	UI.Paint(box.rule, C.border, 0.7)
	box.rule:SetWidth(1)
	box.rule:SetPoint("TOPLEFT", W.EDGE + W.RAIL, -W.HEADER)
	box.rule:SetHeight(W.TOP + W.PAGE_H + W.FOOT)
	-- The credit, at the rail's foot: the name in the paladin's color, the kind of realm after it, the version under it.
	-- A click opens Tools at its Sources (Credits.lua): who else Shy is built with. Under the mouse its words light.
	local version = UI.Text(box, core.version and ("v" .. core.version) or "", 11, false, C.dim)
	version:SetPoint("BOTTOMLEFT", W.EDGE + 14, 12)
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

	box.scroll = UI.ScrollArea(box, W.IN + W.PAGE + W.SCROLL, W.PAGE_H)
	box.content = box.scroll.content
	box.content:SetWidth(W.IN + W.PAGE)

	local bar = CreateFrame("Frame", nil, box)
	bar:SetSize(W.PAGE, W.BAR)
	bar:SetPoint("TOPLEFT", W.EDGE + W.RAIL + W.PAD, -(W.HEADER + W.TOP))
	bar.back = UI.Button(bar, "All addons", 110, function() Hub.Open("home") end)
	bar.back:SetPoint("LEFT")
	bar.defaults = UI.Button(bar, "Defaults", 90, function() end)
	bar.defaults:SetPoint("RIGHT")
	UI.Twice(bar.defaults, function()
		local page = win.pages[win.at]
		if not (page and page.OnDefault) then return end
		page:OnDefault()
		page:Hide()
		page:Show()
	end)
	Help(bar.defaults, "Defaults", "Puts every setting on this page back as it came.")
	bar.open = UI.Button(bar, "Open", 76, function()
		local addon = win.at
		Hub.Close()
		addon:OpenWindow()
	end)
	bar.open:SetPoint("RIGHT", bar.defaults, "LEFT", -8, 0)
	local under = bar:CreateTexture(nil, "ARTWORK")
	UI.Paint(under, C.border, 0.6)
	under:SetHeight(1)
	under:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -W.BAR_GAP / 2)
	under:SetPoint("RIGHT")
	bar:Hide()
	box.bar = bar

	-- While it is open: the page on show measured, and the rail's words kept up as settings change.
	local measured, told = 0, 0
	box:HookScript("OnUpdate", Shy.Clocked("hub: its frame (the room measured, the rail's words)", function(_, elapsed)
		if not win.open then return end
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
	Lay(box, box:GetWidth(), box:GetHeight())
end

-- A room that isn't there (an addon with no options) is Home.
local function Known(room)
	if type(room) == "table" then return room.options and room or "home" end
	return ROOM[room] and room or "home"
end

-- An addon's page waits out a fight when it holds something the game protects: it can't be seated or shown then.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	local room = self.room
	self.room = nil
	if room then Hub.Open(room) end
end)

function Hub.Open(room)
	if room ~= nil then room = Known(room) end
	if type(room) == "table" and InCombatLockdown() and room.options:IsProtected() then
		waiter.room = room
		waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
		core:Print("those options open after the fight.")
		return
	end
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
	win.open = false
	Shy.HUD.Update(win.box)
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

-- Layout mode has the screen to itself.
Shy:On("SHY_HUD_LAYOUT", function(on)
	if on then Hub.Close() end
end)

function Addon:RegisterOptions(page)
	page:Hide()   -- so its first show builds it
	self.options = page
end

function Addon:OpenOptions()
	Hub.Open(self)
end

-- Home: who you are playing, the two things done most (arranging the screen, setting a character up), then
-- every addon, a click from its options.

-- RING: the face's ring, its art's size (DialMid, drawn for 40 to 44); FACE: the face inside it.
local HOME = { BANNER = 64, EDGE = 3, TILE = 40, GAP = 4, ACROSS = 3, ICON = 28, RING = 42, FACE = 28 }

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

local function AddonTile(parent, a, width)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, HOME.TILE)
	UI.Skin(b)
	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(HOME.ICON, HOME.ICON)
	icon:SetPoint("LEFT", 6, 0)
	Theme.Icon(icon, a.icon)
	local name = UI.Text(b, "", 14, true)
	UI.Themed(name, function() return B.Name(a.suffix) end)
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
	local tagline = UI.Text(b, a.tagline or "", 11, false, C.dim)
	tagline:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
	tagline:SetPoint("RIGHT", b, "RIGHT", -8, 0)
	tagline:SetWordWrap(false)
	local usable = a.options ~= nil or a.OpenWindow ~= nil
	b:SetAlpha(usable and 1 or 0.5)
	b:SetScript("OnClick", function()
		if not usable then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		if a.options then
			Hub.Open(a)
		else
			Hub.Close()
			a:OpenWindow()
		end
	end)
	-- (The tagline is cut where the tile ends: the hover says it whole, and the version.)
	b:SetScript("OnEnter", function(self)
		if usable then UI.SetBorder(self, C.hot) end
		UI.Tip(self, B.Name(a.suffix), (a.tagline or "") .. (a.version and ("\n" .. UI.Wrap(C.dim, "v" .. a.version)) or ""))
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.TipHide(self)
	end)
	b.name, b.tagline = name, tagline
	return b
end

function Build.home(page)
	local S = Shy.Setup
	local banner = CreateFrame("Frame", nil, page)
	banner:SetSize(page.width, HOME.BANNER)
	banner:SetPoint("TOPLEFT")
	UI.Skin(banner, C.row, C.border)
	local edge = banner:CreateTexture(nil, "ARTWORK")
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMLEFT", 1, 1)
	edge:SetWidth(HOME.EDGE)
	Theme.Paint(edge, Theme.Accent, 1)
	-- Your character's face in a ring, as the game draws it.
	local ring = banner:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(Shy.MEDIA .. "DialMid")
	ring:SetSize(HOME.RING, HOME.RING)
	ring:SetPoint("CENTER", banner, "LEFT", HOME.EDGE + 12 + HOME.RING / 2, 0)
	UI.Tint(ring, Theme.skin.metal)
	local face = banner:CreateTexture(nil, "ARTWORK", nil, 1)
	face:SetSize(HOME.FACE, HOME.FACE)
	face:SetPoint("CENTER", ring, "CENTER")
	local round = banner:CreateMaskTexture()
	round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	round:SetAllPoints(face)
	face:AddMaskTexture(round)
	UI.Concentric(ring, face)
	-- A player's name: UI.NameFont covers every alphabet. Their level, class and profile under it.
	local who = banner:CreateFontString(nil, "OVERLAY")
	who:SetFontObject(UI.NameFont(18))
	who:SetShadowOffset(1, -1)
	who:SetShadowColor(0, 0, 0, 1)
	UI.Ink(who, C.head)
	who:SetText(First())
	who:SetPoint("TOPLEFT", HOME.EDGE + 12 + HOME.RING + 10, -13)
	local what = UI.Text(banner, "", 12, false, C.dim)
	what:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -5)
	what:SetWordWrap(false)

	local arrange = Shy.HUD.LayoutButton(banner, 130)
	arrange:SetHeight(30)
	arrange:SetPoint("RIGHT", -16, 0)
	Help(arrange, "Layout mode", "Move anything on screen in one editor, the game's pieces and ours. Click a piece for its settings.")
	local setup
	if S and S.Open then
		setup = UI.Button(banner, "Set up " .. First(), 150, function()
			Hub.Close()
			S.Open()
		end)
		setup:SetHeight(30)
		setup:SetPoint("RIGHT", arrange, "LEFT", -8, 0)
	end
	-- (The words end before the buttons: a long profile's name is cut there, never run under them.)
	who:SetPoint("RIGHT", setup or arrange, "LEFT", -16, 0)
	who:SetJustifyH("LEFT")
	who:SetWordWrap(false)
	what:SetPoint("RIGHT", setup or arrange, "LEFT", -16, 0)
	local state = UI.Text(page, "", 11, false, C.dim)
	state:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", HOME.EDGE + 16, -7)
	state:SetWidth(page.width - 2 * (HOME.EDGE + 16))
	state:SetWordWrap(false)

	local head = Shy.HubHead(page, banner, "Your addons")
	head:ClearAllPoints()
	head:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -40)
	-- Whether the addons' data was made for this game (Client.lua), at the caption's right, where its rule
	-- ends: quiet when it was.
	local data = UI.Text(head, "", 11, false, C.dim)
	data:SetPoint("RIGHT")
	Hub.dataLine = data

	local each = (page.width - (HOME.ACROSS - 1) * HOME.GAP * 2) / HOME.ACROSS
	local count = 0
	Hub.tiles = {}
	for _, a in ipairs(Shy.order) do
		if not a.internal then
			local tile = AddonTile(page, a, each)
			tile:SetPoint("TOPLEFT", head, "BOTTOMLEFT", (count % HOME.ACROSS) * (each + HOME.GAP * 2),
				-10 - math.floor(count / HOME.ACROSS) * (HOME.TILE + HOME.GAP))
			count = count + 1
			Hub.tiles[count] = tile
		end
	end
	if count == 0 then
		local none = UI.Text(page, "No addons loaded. Enable them in the AddOns list.", 13, false, C.dim)
		none:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
	end

	page.refresh[#page.refresh + 1] = function()
		SetPortraitTexture(face, "player")
		local _, profile = ProfileWords()
		what:SetText(("level %d %s  \194\183  on %s"):format(UnitLevel("player"), (UnitClass("player")), profile))
		-- The one to press stands filled: setting up until that is done, arranging the screen after.
		local done = not setup or S.Done()
		arrange:SetPrimary(done)
		if setup then setup:SetPrimary(not done) end
		state:SetText(not setup and "" or done and (First() .. " is set up. Set up again to change profile, layout and game settings in one go.")
			or (First() .. " isn't set up yet. A few picks and one reload: profile, layout and recommended game settings."))
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
	local words = UI.Text(page, "Move anything on screen in one editor, the game's pieces and ours. Click a piece for its settings. Ours are saved with each Edit Mode layout.", 12, false, C.dim)
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
			Shy.Reload("Profile switched. Reload to apply it.")
		else
			Relist()   -- the character's own profile, created from current settings: no reload
		end
	end, { width = COL, desc = "A profile holds every addon's settings and your layout. Global is shared by every character that hasn't picked another. Switching to an existing profile needs a reload." })
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
		core:Print("now using profile " .. wanted .. ", a copy of your current settings.")
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
			Shy.Reload("Settings copied. Reload to apply them.")
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

-- Tools: the switches that are nobody else's, and what to reach for when something looks wrong.

function Build.tools(page, top)
	local COL, RIGHT = 260, 306
	local group = UI.Group(function() Shy.UpdateMinimapButton() end)
	local general = Shy.HubHead(page, top, "General")
	local splash = group:Checkbox(page, "Show splash on login",
		function() return core.db.splash end, function(v) core.db.splash = v end,
		{ desc = "Shows the logo for a few seconds when you log in." })
	splash:SetPoint("TOPLEFT", general, "BOTTOMLEFT", 0, -10)
	local preview = UI.Button(page, "Preview splash", 130, function() B.ShowSplash() end)
	preview:SetPoint("TOPLEFT", general, "BOTTOMLEFT", RIGHT, -8)

	local minimap = group:Checkbox(page, "Show minimap button",
		function() return core.db.minimap end, function(v) core.db.minimap = v end,
		{ desc = "A button on the minimap: click opens /shy, right-click lists your addons. On a round minimap, drag it along the rim." })
	minimap:SetPoint("TOPLEFT", splash, "BOTTOMLEFT", 0, -8)
	local gather = group:Checkbox(page, "Gather addon buttons",
		function() return core.db.gather ~= false end, function(v) core.db.gather = v end,
		{ desc = "Moves other addons' minimap buttons off the map and into this button's right-click menu.",
			enabled = function() return core.db.minimap end })
	gather:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -8)

	local rest = group:Slider(page, "Hover delay", 0, 3, 0.1,
		function() return math.floor(core.db.rest * 10 + 0.5) / 10 end,
		function(v) core.db.rest = math.floor(v * 10 + 0.5) / 10 end,
		{ width = COL, format = function(v) return v == 0 and "At once" or string.format("%.1f s", v) end,
			desc = "How long you hover before a tooltip shows more." })
	rest:SetPoint("TOPLEFT", gather, "BOTTOMLEFT", 0, -16)
	local restHelp = UI.Text(page, "Hold Shift to see it all at once. A pinned tooltip always shows everything.", 12, false, C.dim)
	restHelp:SetPoint("TOPLEFT", rest, "TOPLEFT", RIGHT, 0)
	restHelp:SetWidth(page.width - RIGHT)
	restHelp:SetWordWrap(true)

	-- The task manager, the Lua errors kept in a bag (Errors.lua) and who else runs these addons.
	local wrong = Shy.HubHead(page, rest, "When something looks wrong")
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
		local popup = group:Checkbox(page, "Show the game's error window", function() return E.Popup() end, function(v) E.SetPopup(v) end,
			{ desc = "Addon errors also open the game's own error window. Off, they're only kept in Errors caught." })
		popup:SetPoint("TOPLEFT", monitor, "BOTTOMLEFT", 0, -12)
	end
	local ping = UI.Button(page, "Version check", 130, function() Shy.Ping() end)
	ping:SetPoint("LEFT", last, "RIGHT", 10, 0)
	Help(ping, "Version check", "Asks your raid, party or guild which of these addons they run.")

	local cmds = Shy.HubHead(page, monitor, "Commands")
	cmds:ClearAllPoints()
	cmds:SetPoint("TOPLEFT", monitor, "BOTTOMLEFT", 0, Shy.Errors and -62 or -26)
	local lines = { "|cffffd200/shy|r  open this window" }
	for _, command in ipairs(listed) do
		lines[#lines + 1] = "|cffffd200/shy " .. command.word .. "|r  " .. command.help
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

	page.refresh[#page.refresh + 1] = function() group:Refresh() end
	return left
end

Shy.HubBrief("tools", function()
	return core.version and ("v" .. core.version) or nil
end)

-- Version check: "PING" to the group; each copy whispers back its addon list.

local function MyAddons()
	local out = {}
	for _, a in ipairs(Shy.order) do out[#out + 1] = "Shy" .. a.suffix .. " " .. (a.version or "?") end
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
Shy.Command("layout", "toggle layout mode", Layout)
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
	UI.ShowCopyBox("Shy: addon limits", text)
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
Shy.Command("monitor", "the task manager: what each addon costs the game", function() Shy.Monitor() end)
-- The census (Core.lua): the scripts no clock times, timed for the task manager, for one session. Asked for, it
-- runs after this reload and is off again at the next; asked while it runs, the reload ends it.
Shy.Command("census", "time the scripts no clock times, for the task manager (one session)", function()
	local on = not Shy.Census()
	Shy.SetCensus(on)
	Shy.Reload(on and "The task manager will list every script with no clock of its own, until you next reload." or "The task manager goes back to its own clocks.")
end)

-- /shymon before the task manager has loaded: the first use loads it, and its own command (which
-- replaces this one as it loads) takes the words.
local function MonitorCommand(input)
	if not MonitorLoaded() then return end
	local command = SlashCmdList.SHYMONITOR
	if command ~= MonitorCommand then command(input) end
end
SLASH_SHYMONITOR1 = "/shymonitor"
SLASH_SHYMONITOR2 = "/shymon"
SlashCmdList.SHYMONITOR = MonitorCommand

-- /shy: a command, a room by its name, else the window where it was.
SLASH_SHY1 = "/shy"
SlashCmdList.SHY = function(input)
	local word = strtrim(input or ""):lower()
	local command = commands[word]
	if command then
		command()
	elseif ROOM[word] then
		Hub.Open(word)
	else
		Hub.Open()
	end
end
