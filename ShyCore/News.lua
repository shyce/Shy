-- What's new: a release that brings something you'd want to know of says so as you log in, once for the account.
-- An item belongs to one release: it shows only while that release is the one you run, so updating past it, or
-- any update after, says nothing of it. Keep it short: a title and a line or two. An item may also list the
-- switches this character turned off that bear on it, each ticked to turn back on with one click, or left as they
-- are: asked once on each character.
-- Nobody is told before their character is set up (a fresh install: everything is new to it), and nothing comes
-- up in a fight or over the setup window.
--   Shy.News.Add(item)   item = { id, release = "5.2.6", addon (whose version: "ShyCore"), title, icon,
--                                 lines = { "a sentence", ... },
--                                 off = function() return { { text = "a switch", on = function() end }, ... } end }
--   Shy.News.Due()       the items this character hasn't been told of, or asked about
--   Shy.News.Open(all)   the window: what's due, or every item of this release (/shy news)
-- Account-wide, outside profiles: ShyCoreDB.news = { seen = { [id] = true }, asked = { [character] = { [id] = true } } }

local Shy = Shy
local UI, P = Shy.UI, Shy.Profiles
local core = Shy.core
local C = UI.colors

local News = { items = {} }
Shy.News = News
core.keep.news = true

local K = {
	WIDTH = 440, PAD = 14, GAP = 6, LINE_GAP = 4, ITEM_GAP = 10,
	TITLE = 13, TEXT = 12, ICON = 16, STAR = 10, BOX = 16, BUTTON = 24, LEAST_BUTTON = 110,
	WAIT = 4,          -- seconds after logging in before it is asked
	AGAIN = 10,        -- seconds before asking again, while a fight or setup is in the way
	TRIES = 30,
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

-- The window

local win, open, shown, picks
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
local function Para(parent, color, width, text)
	local fs = UI.Words(parent, UI.TextFont(K.TEXT), color)
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetWidth(width)
	fs:SetText(text)
	return fs
end

-- Told and asked: every item shown is seen, and this character asked about each.
local function Settle()
	local book = Book()
	if not book then return end
	local asked = Asked()
	for _, item in ipairs(shown or {}) do
		book.seen[item.id] = true
		asked[item.id] = true
	end
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
end

-- What's new, item by item; then what this character turned off, ticked to come back.
local function Lay(items)
	Clear()
	local body, W = win.body, K.WIDTH
	local inner = W - 2 * K.PAD
	local y = UI.HEAD.window.line + UI.LINE + K.PAD
	picks = {}
	for _, item in ipairs(items) do
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
		local head = Keep(UI.Text(body, "You turned these off", K.TITLE, true, C.head))
		head:SetPoint("TOPLEFT", K.PAD, -y)
		y = y + K.TITLE + K.GAP
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

-- What's due, or with `all` every item of this release; nothing to show, nothing shown.
function News.Open(all)
	local items = all and News.Current() or News.Due()
	if #items == 0 then return false end
	if not win then Create() end
	shown = items
	Lay(items)
	open = true
	Shy.HUD.Update(win)
	win:Raise()
	return true
end

function News.Window() return win, picks, shown end

-- Whether no character on the account has been set up yet: a fresh install.
local function Fresh()
	local chars = ShyCoreDB.setup and ShyCoreDB.setup.chars or {}
	for _, record in pairs(chars) do
		if record.done ~= nil or record.settled then return false end
	end
	return true
end

-- As you log in: once the game has settled, out of a fight and with the setup window shut. A character not yet
-- set up is told nothing. On a fresh install what is new now is noted as seen: it is all new to them.
local tries = 0
local function Try()
	local book = Book()
	if not book then return end
	local setup = Shy.Setup
	if not book.started and Fresh() then
		book.started = true
		for _, item in ipairs(News.items) do book.seen[item.id] = true end
		return
	end
	book.started = true
	if setup and not setup.Done() then return end
	if InCombatLockdown() or (setup and setup.IsOpen()) then
		tries = tries + 1
		if tries < K.TRIES then C_Timer.After(K.AGAIN, Try) end
		return
	end
	if not News.Open() then return end
end

Shy:On("SHY_LOGIN", function() C_Timer.After(K.WAIT, Try) end)
-- /shy news: this release's news, told or not. /shy news 5.2.6: that release's, whatever runs (to look over news
-- before its release ships).
Shy.Command("news", "what's new in this release, and anything you turned off that goes with it", function(rest)
	asking = rest and rest:match("^%d+%.%d+%.%d+$") or nil
	local ok, opened = pcall(News.Open, true)
	asking = nil
	if not ok then error(opened, 0) end
	if not opened then core:Print(("nothing new to tell in %s."):format(rest ~= "" and rest or "this release")) end
end)
