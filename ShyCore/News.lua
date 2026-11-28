-- What's new: a window as you log in after an update, for what the release brings.
--   What changed: every release's notes since the account last saw them (Shy.CHANGES, Data/Changes.lua), newest
--   first, each line the addon it is about and what you'll notice. A long list scrolls.
--   A release's own story (Shy.News.Add): a title and a line or two, shown while that release is the one you run.
--   It may list the switches this character turned off that bear on it, each ticked to turn back on.
-- Nobody is told before their character is set up (a fresh install: everything is new to it), and nothing comes up
-- in a fight, over the setup window or over Your addons (Others.lua).
--   Shy.News.Add(item)   item = { id, release = "5.2.6", addon (whose version: "ShyCore"), title, icon,
--                                 lines = { "a sentence", ... },
--                                 off = function() return { { text = "a switch", on = function() end }, ... } end }
--   Shy.News.Due()       the stories this character hasn't been told of, or asked about
--   Shy.News.Open(all)   the window: what's due, or with `all` this release's notes and stories (/shy news)
-- Account-wide, outside profiles: ShyCoreDB.news = { seen = { [id] = true }, saw = "5.2.16" (the notes read up to),
--                                                    asked = { [character] = { [id] = true } } }

local Shy = Shy
local UI, P = Shy.UI, Shy.Profiles
local core = Shy.core
local C = UI.colors
local max = math.max

local News = { items = {} }
Shy.News = News
core.keep.news = true

local K = {
	WIDTH = 460, PAD = 14, GAP = 6, LINE_GAP = 3, ITEM_GAP = 10,
	TITLE = 13, TEXT = 12, SMALL = 11, ICON = 16, STAR = 10, BOX = 16, BUTTON = 24, LEAST_BUTTON = 110,
	CHANGES = 250,     -- the tallest the notes stand before they scroll
	RELEASES = 3,      -- the most releases /shy news shows
	WAIT = 4,          -- seconds after logging in before a fresh install's notes are noted as read
}

local function Book()
	local db = ShyCoreDB
	if not db then return nil end
	db.news = db.news or { seen = {}, asked = {} }
	db.news.seen, db.news.asked = db.news.seen or {}, db.news.asked or {}
	return db.news
end

local function Asked()
	local book, me = Book(), P.Character()
	book.asked[me] = book.asked[me] or {}
	return book.asked[me]
end

function News.Add(item)
	for i, have in ipairs(News.items) do
		-- (told again by an addon loaded again: the new one stands)
		if have.id == item.id then
			News.items[i] = item
			return
		end
	end
	News.items[#News.items + 1] = item
end

-- An item's switches this character has off, as its owner says (none for an owner whose answer errs).
local function Off(item)
	if not item.off then return {} end
	local ok, list = pcall(item.off)
	if not ok then
		geterrorhandler()(list)
		return {}
	end
	return type(list) == "table" and list or {}
end

-- The version an addon runs at, as its TOC says, or nil.
local function Running(addon)
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, addon or "ShyCore", "Version")
	return ok and type(version) == "string" and version or nil
end

-- Whether an item is this release's: the version it names is the one running (or the one asked about: /shy news 5.2.6).
local asking
local function Current(item)
	return item.release ~= nil and item.release == (asking or Running(item.addon))
end

function News.Due()
	local book = Book()
	if not book then return {} end
	local asked, out = Asked(), {}
	for _, item in ipairs(News.items) do
		if Current(item) and (not book.seen[item.id] or (not asked[item.id] and #Off(item) > 0)) then out[#out + 1] = item end
	end
	return out
end

-- This release's items, told or not (/shy news).
function News.Current()
	local out = {}
	for _, item in ipairs(News.items) do
		if Current(item) then out[#out + 1] = item end
	end
	return out
end

-- "5.2.16" before "5.2.9": a version as numbers, compared one by one.
local function Before(a, b)
	local x, y = {}, {}
	for n in a:gmatch("%d+") do x[#x + 1] = tonumber(n) end
	for n in b:gmatch("%d+") do y[#y + 1] = tonumber(n) end
	for i = 1, max(#x, #y) do
		if (x[i] or 0) ~= (y[i] or 0) then return (x[i] or 0) < (y[i] or 0) end
	end
	return false
end

-- The releases whose notes are due: those after the ones read, up to the one running. Never read here (the notes
-- came in with this release): the one running alone. With `all`, the newest few up to it, read or not.
local function Releases(all)
	local book, running, out = Book(), asking or Running("ShyCore"), {}
	if not (book and running) then return out end
	for _, release in ipairs(Shy.CHANGES or {}) do
		local upto = not Before(running, release.version)
		local unread = book.saw and Before(book.saw, release.version) or (not book.saw and release.version == running)
		if upto and (all or unread) then out[#out + 1] = release end
		if all and #out >= K.RELEASES then break end
	end
	return out
end

-- "26 Nov" from "2026-11-26".
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
local function Day(date)
	local month, day = date:match("^%d+%-(%d+)%-(%d+)$")
	month = month and MONTHS[tonumber(month)]
	return month and (tonumber(day) .. " " .. month) or ""
end

-- The window

local win, open, shown, picks, notes
local made = {}            -- the regions laid on the body last time: hidden before the next lay

local function Clear()
	for _, region in ipairs(made) do region:Hide() end
	wipe(made)
end

local function Keep(region)
	made[#made + 1] = region
	return region
end

-- Running words, wrapping at their width (as the error window's are).
local function Para(parent, color, width, text, size)
	local fs = UI.Words(parent, UI.TextFont(size or K.TEXT), color)
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetWidth(width)
	fs:SetText(text)
	return fs
end

-- Told and asked: the notes read, every story shown seen and this character asked about each.
local function Settle()
	local book = Book()
	if not book then return end
	local asked = Asked()
	for _, item in ipairs(shown or {}) do
		book.seen[item.id] = true
		asked[item.id] = true
	end
	local running = Running("ShyCore")
	if running and (not book.saw or Before(book.saw, running)) then book.saw = running end
end

local function Close()
	open = false
	if win then Shy.HUD.Update(win) end
end

local function Create()
	win = UI.Window({
		id = "shy.news", name = "ShyNewsWindow", title = "What's new",
		width = K.WIDTH, height = 200,
		point = { "CENTER", "CENTER", 0, 60 }, strata = "DIALOG",
		shown = function() return open end,
		-- (closed by the ×, Esc or a loading screen: kept as it is, and not asked again)
		onClose = function()
			if open then Settle() end
			open = false
		end,
		head = { size = "window", icon = core.mark, title = "What's new" },
	})
	win.body = UI.Body(win)
	win.keep = UI.Button(win.body, "Keep as they are", K.LEAST_BUTTON, function()
		Settle()
		Close()
	end)
	win.go = UI.Button(win.body, "Turn back on", K.LEAST_BUTTON, function()
		for _, pick in ipairs(picks or {}) do
			if pick.on then
				local ok, err = pcall(pick.entry.on)
				if not ok then geterrorhandler()(err) end
			end
		end
		Settle()
		Close()
	end)
	win.go:SetPrimary(true)
end

-- A section's heading: its name in the head's ink.
local function Heading(body, text, y)
	local head = Keep(UI.Text(body, text, K.TITLE, true, C.head))
	head:SetPoint("TOPLEFT", K.PAD, -y)
	return y + K.TITLE + K.GAP
end

-- The notes, release by release in a scroll area: the version and its date, then each group (Added, Changed,
-- Fixed) under its name, each line the addon it is about and what changed.
local function Notes(body, y, inner)
	local area = notes
	if not area then
		area = UI.ScrollArea(body, inner, K.CHANGES)
		notes = area
		area.made = {}
	end
	for _, region in ipairs(area.made) do region:Hide() end
	wipe(area.made)
	local wide, at, ends = inner - 14, 0, {}
	-- (Each kept with how far down the list it stands.)
	local function Hold(region)
		area.made[#area.made + 1] = region
		region.shyAt = at
		region:Show()
		return region
	end
	for r, release in ipairs(shown.releases) do
		if r > 1 then at = at + K.ITEM_GAP end
		local name = Hold(UI.Text(area.content, release.version, K.TEXT, true, C.head))
		name:SetPoint("TOPLEFT", 0, -at)
		if Day(release.date) ~= "" then
			local date = Hold(UI.Text(area.content, Day(release.date), K.SMALL, false, C.dim))
			date:SetPoint("LEFT", name, "RIGHT", 8, 0)
		end
		at = at + K.TEXT + K.GAP
		for _, group in ipairs(release.groups) do
			local kind = Hold(UI.Text(area.content, group.title:upper(), 10, true, C.dim))
			kind:SetPoint("TOPLEFT", 0, -at)
			at = at + 10 + K.LINE_GAP + 1
			for _, line in ipairs(group) do
				local scope = line[1] == "Release" and "Shy" or line[1]
				local said = scope ~= "" and (UI.Wrap(C.head, scope) .. "  " .. line[2]) or line[2]
				local text = Hold(Para(area.content, C.text, wide - K.STAR - K.GAP, said))
				text:SetPoint("TOPLEFT", K.STAR + K.GAP, -at)
				local star = Hold(area.content:CreateTexture(nil, "ARTWORK"))
				star:SetTexture(Shy.MEDIA .. "GlyphStar")
				star:SetSize(K.STAR, K.STAR)
				Shy.Theme.Tint(star, Shy.Theme.Accent)
				star:SetPoint("TOPLEFT", 0, -at - 2)
				text.shyEnd = at + math.ceil(text:GetStringHeight())
				ends[#ends + 1] = text.shyEnd
				at = text.shyEnd + K.LINE_GAP
			end
			at = at + K.GAP - K.LINE_GAP
		end
	end
	at = at - K.GAP
	area.content:SetHeight(max(at, 1))
	-- (Cut between two lines, never through one.)
	local tall = at
	if at > K.CHANGES then
		tall = 0
		for _, e in ipairs(ends) do
			if e <= K.CHANGES then tall = max(tall, e) end
		end
	end
	area:SetHeight(tall)
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", body, "TOPLEFT", K.PAD, -y)
	area:Show()
	area:Update()
	return y + tall + K.ITEM_GAP + K.GAP
end

-- The notes, then this release's stories and what this character turned off for them, ticked to come back.
local function Lay()
	Clear()
	local body, W = win.body, K.WIDTH
	local inner = W - 2 * K.PAD
	local y = UI.HEAD.window.line + UI.LINE + K.PAD
	picks = {}
	if notes then notes:Hide() end
	if #shown.releases > 0 then
		y = Heading(body, #shown.releases == 1 and "What changed" or "What changed since you last played", y)
		y = Notes(body, y, inner)
	end
	for _, item in ipairs(shown) do
		local x = K.PAD
		if item.icon then
			local icon = Keep(body:CreateTexture(nil, "ARTWORK"))
			icon:SetTexture(item.icon)
			icon:SetSize(K.ICON, K.ICON)
			icon:SetPoint("TOPLEFT", K.PAD, -y)
			icon:Show()
			x = x + K.ICON + K.GAP
		end
		local title = Keep(UI.Text(body, item.title, K.TITLE, true, C.head))
		title:SetPoint("LEFT", body, "TOPLEFT", x, -y - K.ICON / 2)
		y = y + K.ICON + K.GAP
		for _, line in ipairs(item.lines or {}) do
			local star = Keep(body:CreateTexture(nil, "ARTWORK"))
			star:SetTexture(Shy.MEDIA .. "GlyphStar")
			star:SetSize(K.STAR, K.STAR)
			Shy.Theme.Tint(star, Shy.Theme.Accent)
			star:SetPoint("TOPLEFT", K.PAD + 2, -y - 2)
			local text = Keep(Para(body, C.text, inner - K.STAR - K.GAP - 2, line))
			text:SetPoint("TOPLEFT", K.PAD + K.STAR + K.GAP + 2, -y)
			y = y + math.ceil(text:GetStringHeight()) + K.LINE_GAP
		end
		for _, entry in ipairs(Off(item)) do picks[#picks + 1] = { entry = entry, on = true } end
		y = y + K.ITEM_GAP
	end
	if #picks > 0 then
		y = Heading(body, "You turned these off", y)
		local say = Keep(Para(body, C.dim, inner, "They work with what's new. Untick any you want to keep off."))
		say:SetPoint("TOPLEFT", K.PAD, -y)
		y = y + math.ceil(say:GetStringHeight()) + K.GAP
		for _, pick in ipairs(picks) do
			local box = Keep(UI.Checkbox(body, pick.entry.text, function() return pick.on end, function()
				pick.on = not pick.on
			end, { box = K.BOX, size = K.TEXT }))
			box:SetPoint("TOPLEFT", K.PAD, -y)
			box:Refresh()
			y = y + K.BOX + K.GAP
		end
		y = y + K.ITEM_GAP - K.GAP
	end
	-- The foot: with switches to give back, keep them or turn the ticked ones on; with none, one button to close.
	local any = #picks > 0
	win.go:SetLabel(any and "Turn back on" or "Got it")
	win.keep:SetShown(any)
	win.go:ClearAllPoints()
	win.go:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -K.PAD, K.PAD)
	win.keep:ClearAllPoints()
	win.keep:SetPoint("RIGHT", win.go, "LEFT", -K.GAP, 0)
	UI.BodyFit(win, W, y + K.BUTTON + K.PAD)
end

-- What's due, or with `all` this release's notes and stories; nothing to show, nothing shown.
function News.Open(all)
	local items = all and News.Current() or News.Due()
	items.releases = Releases(all)
	if #items == 0 and #items.releases == 0 then return false end
	if not win then Create() end
	shown = items
	Lay()
	open = true
	Shy.HUD.Update(win)
	win:Raise()
	return true
end

function News.Window() return win, picks, shown, notes end

-- Whether no character on the account has been set up yet: a fresh install.
local function Fresh()
	local chars = ShyCoreDB.setup and ShyCoreDB.setup.chars or {}
	for _, record in pairs(chars) do
		if record.done ~= nil or record.settled then return false end
	end
	return true
end

-- As you log in, in its turn (Shy.Queue): out of a fight, setup put away or done, after the send-off and Your
-- addons. A character not set up yet is told nothing. On a fresh install the notes and stories are noted as read:
-- it is all new to them.
-- True on a fresh install, its notes and stories noted as read (once the game has settled, whatever else waits).
local function Mark()
	local book = Book()
	if not book then return true end
	if not book.started and Fresh() then
		book.started = true
		for _, item in ipairs(News.items) do book.seen[item.id] = true end
		book.saw = Running("ShyCore")
		return true
	end
	book.started = true
	return false
end

local function Try()
	if Mark() then return false end
	local setup = Shy.Setup
	if setup and not setup.Done() then return false end
	return News.Open()
end

Shy:On("SHY_LOGIN", function()
	C_Timer.After(K.WAIT, Mark)
	Shy.Queue.Ask("news", 30, Try, function() return open == true end)
end)
-- /shy news: this release's news, told or not. /shy news 5.2.6: that release's, whatever
-- runs (to look over news before its release ships).
Shy.Command("news", "what's new in this release", function(rest)
	asking = rest and rest:match("^%d+%.%d+%.%d+$") or nil
	local ok, opened = pcall(News.Open, true)
	asking = nil
	if not ok then error(opened, 0) end
	if not opened then core:Print(("there's nothing new in %s."):format(rest ~= "" and rest or "this release")) end
end)
