-- Whisper windows: each conversation a tab, the header the chat's, the words the chat's size. Tabs dock together
-- and come apart (UI.TabWindows): drag one onto another window's tabs, or off into a window of its own. A whisper
-- opens its conversation (a new window a step down and right of the last, or a blinking tab in the window you
-- have), never in a fight. A window maximizes to the screen or minimizes into the whisper dock, a piece of the
-- layout where each conversation waits as a plate that lights up with news and opens on a click.
-- Conversations are kept per character, and the head's whispers notice counts the ones with news.

local ADDON, ns = ...
local UI, HUD, N, Theme = Shy.UI, Shy.HUD, Shy.Notices, Shy.Theme
local C = UI.colors
local T, F = ns.T, ns.Format
local Wh = {}
ns.Whispers = Wh

local db
local SEPARATOR = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
local HEAD = UI.HEAD.piece   -- the chat window's header
local WIDTH, HEIGHT = 380, 240
local LEAST = { 260, 150 }
local MOST = 8           -- windows at once; past it a conversation goes in as a tab
local PAD = 8
local WHO = 15           -- the line under the header: who it is
local TYPING = 22        -- the typing row
local BLINK = 0.5        -- a tab or plate with news turns gold and back this often
local BN_LINES = 200     -- a Battle.net conversation is kept for the session only
local LISTED = 8         -- conversations in the notice's list
local SAID = 48          -- letters of the last line a menu row or plate's hover shows
local NOTICE, VOICE = "whispers", "whisper"
local MEDIA = Shy.MEDIA
-- The dock: a console piece, its header the chat's, a row a conversation under it.
local DOCK_W = 230
local DOCK_HEAD = UI.HEAD_STRIP + UI.LINE
local DOCK_FOOT = 3       -- the panel's edge under the last row
local ROW, ROW_GAP, ROW_PAD, ROW_IN = 34, 2, 4, 4

local talks = {}         -- key -> { key, name, first, bn, rec, unread, held }
local set                -- the windows (UI.TabWindows): set.wins[n], set.of[key]
local lastUsed           -- the window a whisper went to or was typed in last
local started = time()   -- lines before it are a session ago
local quiet = false      -- we are hiding a window ourselves: it isn't being closed
local fighting = false   -- from the fight's start, which comes just before the lockdown, to its end
local sending            -- the conversation a line was just typed in, until its echo comes back
local blinker, lit = nil, false
local dock

local Fill, Post, Paint, Docked, Menu

-- Names: the key is the name chat gives (a first name and a surname, the realm when not yours).

local function Store()
	local kept = ShyChatHistory.whispers
	if type(kept) ~= "table" then
		kept = {}
		ShyChatHistory.whispers = kept
	end
	return kept
end

local function First(name)
	local cut = name:find(SEPARATOR, 1, true) or name:find("-", 1, true)
	return cut and name:sub(1, cut - 1) or name
end

local function ClassOf(guid)
	if guid == nil or issecretvalue(guid) or guid == "" then return nil end
	local named, class, race = GetPlayerInfoByGUID(guid)
	if issecretvalue(class) or issecretvalue(race) or issecretvalue(named) then return nil end
	return class, race and named and (race .. " " .. named) or race
end

-- Their class color as { r, g, b }, or nil.
local function ClassColor(talk)
	local c = talk.rec.class and RAID_CLASS_COLORS[talk.rec.class]
	return c and { c.r, c.g, c.b }
end

local function Talk(key, name, bn)
	local talk = talks[key]
	if talk then return talk end
	local rec
	if bn then
		rec = { name = name, lines = {} }
	else
		local kept = Store()
		rec = kept[key] or { name = name, lines = {} }
		kept[key] = rec
	end
	talk = { key = key, name = rec.name or name, bn = bn, rec = rec, unread = 0 }
	talk.first = bn and talk.name or First(talk.name)
	talks[key] = talk
	return talk
end

-- The window a conversation is in, or nil.
local function Win(talk)
	return set.of[talk.key]
end

-- What a whisper's own color is: the chat's, as you set it.
local function Kind(talk, me)
	local kind = (talk.bn and "BN_" or "") .. (me and "WHISPER_INFORM" or "WHISPER")
	return ChatTypeInfo[kind] or ChatTypeInfo.WHISPER
end

local function NoticeColor()
	local info = ChatTypeInfo.WHISPER
	return info.r, info.g, info.b
end

-- A tab's label: the first name, unless another in the window shares it.
local function Label(key, w)
	local talk = talks[key]
	for _, other in ipairs(w.keys) do
		if other ~= key and talks[other].first == talk.first then return talk.name end
	end
	return talk.first
end

local function Seen(talk)
	local w = Win(talk)
	return w ~= nil and w.current == talk.key and w.box:IsVisible()
end

-- The last thing said, plain and cut short (whole letters), for a menu row or a hover.
local function LastSaid(talk)
	local line = talk.rec.lines[#talk.rec.lines]
	if not line then return nil end
	local text = UI.PlainText(line.m)
	if #text > SAID then text = text:sub(1, SAID):gsub("[\192-\255][\128-\191]*$", "") .. "..." end
	return (line.me and "You: " or "") .. text
end

local function Gold(text) return UI.Wrap(C.alert, text) end

local function Named(talk)
	local c = ClassColor(talk)
	return c and UI.Wrap(c, talk.name) or talk.name
end

-- Lines

-- A line from a session ago is in the dim ink, its links still in theirs.
local function Written(talk, line, old)
	local who = line.me and "You" or talk.first
	local c = not line.me and not old and ClassColor(talk)
	if c then who = UI.Wrap(c, who) end
	return F.Time(line.t) .. who .. ": " .. F.Words(line.m)
end

local function Put(w, talk, line, old)
	if old then
		w.msg:AddMessage(Written(talk, line, true), C.dim[1], C.dim[2], C.dim[3])
		return
	end
	local info = Kind(talk, line.me)
	w.msg:AddMessage(Written(talk, line), info.r, info.g, info.b)
end

local function Who(talk)
	local parts = { Named(talk) }
	local friend = not talk.bn and C_FriendList.GetFriendInfo(talk.key)
	if friend and friend.connected and friend.level and friend.level > 0 then parts[#parts + 1] = "Level " .. friend.level end
	if talk.rec.race then parts[#parts + 1] = talk.rec.race end
	if friend and friend.connected and friend.area and friend.area ~= "" then parts[#parts + 1] = friend.area end
	if talk.bn then parts[#parts + 1] = "Battle.net" end
	return table.concat(parts, "  \194\183  ")
end

-- The words are the chat's: its face at its size.
local function Face(w)
	local chat = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local file, size, flags
	if chat then file, size, flags = chat:GetFont() end
	if type(file) == "string" and type(size) == "number" and size > 0 then
		flags = flags or ""
		w.msg:SetFont(file, size, flags)
		w.edit:SetFont(file, size, flags)
		w.edit.header:SetFont(file, size, flags)
	end
	ns.Window.Dress(w.msg)
end

-- The typing row: "To Mira:" in the whisper's color, the words after it.
local function Header(w, talk)
	local info = Kind(talk, false)
	w.edit.header:SetText("To " .. talk.first .. ":")
	w.edit.header:SetTextColor(info.r, info.g, info.b)
	w.edit:SetTextColor(info.r, info.g, info.b)
	w.edit:SetTextInsets(8 + w.edit.header:GetStringWidth() + 4, 8, 0, 0)
end

function Fill(w)
	local talk = talks[w.current]
	w.msg:Clear()
	if not talk then return end
	local lines = talk.rec.lines
	local before = 0
	for _, line in ipairs(lines) do
		if (line.t or 0) < started then before = before + 1 end
	end
	for i, line in ipairs(lines) do
		Put(w, talk, line, i <= before)
		if i == before and before < #lines then
			w.msg:AddMessage(UI.Wrap(C.dim, "- - -   earlier   - - -"), 1, 1, 1)
		end
	end
	w.who:SetText(Who(talk))
	Header(w, talk)
end

local function Read(talk)
	if talk.unread == 0 then return end
	talk.unread = 0
	Post()
end

-- Tabs and the dock's rows: news blinks gold until the conversation is looked at.

local function Blinking()
	for _, talk in pairs(talks) do
		local w = Win(talk)
		if talk.unread > 0 and w and w.open then return true end
	end
	return false
end

function Paint()
	for _, w in pairs(set.wins) do
		if w.open then
			for i, key in ipairs(w.keys) do
				local tab, talk = w.tabs.tabs[i], talks[key]
				local news = talk.unread > 0 and key ~= w.current
				w.tabs:SetBadge(i, news and talk.unread or 0)
				w.tabs:SetTint(i, ClassColor(talk))
				if news then
					UI.Ink(tab.text, lit and C.alert or C.dim)
				else
					UI.Ink(tab.text, key == w.current and C.text or C.dim)
				end
			end
		end
	end
	if dock then dock:Paint() end
	if Blinking() then
		if not blinker then
			blinker = C_Timer.NewTicker(BLINK, function()
				lit = not lit
				Paint()
			end)
		end
	elseif blinker then
		blinker:Cancel()
		blinker, lit = nil, false
	end
end

local function Picked(w, key)
	lastUsed = w
	Fill(w)
	if w.box:IsVisible() then Read(talks[key]) end
	Paint()
end

local function Show(talk)
	set:Show(talk.key)
end

-- Windows

local function Refresh(w)
	quiet = true
	HUD.Update(w.box)
	quiet = false
	if w.box:IsVisible() and w.current then Read(talks[w.current]) end
	Docked()
	Paint()
end

-- A window let go of: its conversations wait for the next whisper.
local function Shut(w)
	w.min = nil
	Wh.Unmax(w)
	for _, key in ipairs(w.keys) do talks[key].unread = 0 end
	set:Clear(w)
	w.edit:ClearFocus()
	if lastUsed == w then lastUsed = nil end
	Post()
	Docked()
	Paint()
end

-- What happened to the windows lately, for /shychat whispers.
local log = {}
local function Log(text)
	log[#log + 1] = ("%.2f  %s"):format(GetTime(), text)
	if #log > 24 then table.remove(log, 1) end
end

local function Held()
	return db.whisperFight and fighting
end

-- Whether a window is up: open, not in the dock, not stepped aside.
local function Wanted(w)
	return w.open == true and not w.min and db.whispers and not Held()
end

-- Only you close a window, with its ×. It isn't one of the windows Esc closes: Esc leaves its typing row, then
-- opens the game menu as ever, and the game's own sweeps of those windows (as a reload logs in, when the UI is
-- shown again, when you lose control) pass it by. Not closed when it steps aside (a fight, the setting off,
-- the dock), whoever asks the HUD to show it again.
local function Closed(w)
	if quiet or not Wanted(w) then return end
	Log(("window %d closed"):format(w.n))
	Shut(w)
end

-- Its last conversation docked elsewhere or closed: the window goes quietly.
local function Emptied(w)
	quiet = true
	w.box:Hide()
	quiet = false
	Shut(w)
end

-- Maximized: the whole screen, over what is under it. Dragging or sizing it puts it back first.
-- (the window's own: the core's UI.Maximize, the window's max button wearing Maximize or Restore)
local function Maximize(w, on)
	if on == (w.maxed ~= nil) then return end
	if on then
		w.box.maxButton = w.buttons.max
		UI.Maximize(w.box, true)
		w.maxed = w.box.maxed
	else
		Wh.Unmax(w)
	end
end

-- Back to its own size: where it was, or (dragged) under the cursor, held at the same share of its width.
function Wh.Unmax(w, follow)
	if not w.maxed then return end
	w.box.maxButton = w.buttons.max
	UI.Maximize(w.box, false, follow)
	w.maxed = nil
end

-- Minimized: the window goes, its conversations wait in the dock.
local function Minimize(w, on)
	if on and w.maxed then Maximize(w, false) end
	w.min = on or nil
	if on then w.edit:ClearFocus() end
	Refresh(w)
	if not on then w.box:Raise() end
end

-- A window's body: who it is, the lines, the typing row.
local function Build(w)
	local box = w.box
	local top = HEAD.line + UI.LINE

	w.who = UI.Text(box, "", 11, false, C.dim)
	w.who:SetPoint("TOPLEFT", PAD + 2, -(top + 5))
	w.who:SetPoint("RIGHT", box, "RIGHT", -PAD, 0)
	w.who:SetJustifyH("LEFT")
	w.who:SetWordWrap(false)

	local msg = CreateFrame("ScrollingMessageFrame", nil, box)
	msg:SetPoint("TOPLEFT", PAD + 2, -(top + 5 + WHO))
	msg:SetPoint("BOTTOMRIGHT", -PAD - 2, PAD + TYPING + 5)
	msg:SetFontObject(ChatFontNormal)
	msg:SetJustifyH("LEFT")
	msg:SetFading(false)
	msg:SetMaxLines(500)
	msg:SetHyperlinksEnabled(true)
	msg:EnableMouseWheel(true)
	msg:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then self:ScrollUp() else self:ScrollDown() end
	end)
	msg:SetScript("OnHyperlinkClick", function(self, link, text, button) SetItemRef(link, text, button, self) end)
	msg:SetScript("OnHyperlinkEnter", function(self, link) ns.Window.LinkEnter(self, link) end)
	msg:SetScript("OnHyperlinkLeave", function() ns.Window.LinkLeave() end)
	w.msg = msg

	local edit = CreateFrame("EditBox", nil, box)
	edit:SetPoint("BOTTOMLEFT", PAD, PAD)
	edit:SetPoint("BOTTOMRIGHT", -PAD, PAD)
	edit:SetHeight(TYPING)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetMaxLetters(255)
	edit:SetAltArrowKeyMode(false)
	edit:SetHistoryLines(32)
	UI.Skin(edit)
	edit.header = edit:CreateFontString(nil, "OVERLAY")
	edit.header:SetFontObject(ChatFontNormal)
	edit.header:SetPoint("LEFT", 8, 0)
	edit:SetScript("OnEnterPressed", function(self) Wh.Send(w, self) end)
	edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	edit:SetScript("OnTabPressed", function()
		local now = 1
		for i, key in ipairs(w.keys) do
			if key == w.current then now = i end
		end
		local step = IsShiftKeyDown() and -1 or 1
		local key = w.keys[(now - 1 + step) % #w.keys + 1]
		if key then set:Show(key) end
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		UI.SetBorder(self, C.hot)
		lastUsed = w
	end)
	edit:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	w.edit = edit
	Face(w)

	-- A click anywhere in the window puts the cursor in its typing row.
	box:HookScript("OnMouseDown", function() edit:SetFocus() end)
	box:HookScript("OnHide", function()
		-- Hidden by this file (stepping aside, closing): no stack to read.
		local by = quiet and "ShyChat" or (debugstack(2, 6, 0) or ""):gsub("Interface/AddOns/", ""):gsub("\n", " < ")
		Log(("window %d OnHide (open %s, min %s, quiet %s) by %s"):format(w.n, tostring(w.open), tostring(w.min), tostring(quiet), by))
	end)
end

local function AnyOpen()
	if lastUsed and lastUsed.open and not lastUsed.min then return lastUsed end
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open and not w.min then return w end
	end
end

-- Opens a conversation as the setting says. `focus`: bring it up with the cursor in it (a whisper you sent,
-- a plate clicked). A minimized window stays in the dock for news alone.
local function Open(talk, focus)
	if not db.whispers then return end
	if Held() then
		talk.held = true
		return
	end
	talk.held = nil
	local w = Win(talk)
	local was
	if w then
		was = true
	else
		if db.whisperOpen == "tab" then
			w = AnyOpen()
			if w and not set:Fits(w, talk.first) then w = nil end
		end
		w = w or set:Window() or AnyOpen()
		if not w then return end
		was = w.open
		set:Join(w, talk.key)
	end
	if focus then w.min = nil end
	Refresh(w)
	if focus or not was then
		Show(talk)
		w.box:Raise()
	end
	if focus then w.edit:SetFocus() end
end

function Wh.Open(key)
	local talk = talks[key]
	if not talk then return end
	Open(talk, true)
end

-- The whisper dock: a piece of the console's make (capped, its header strip and line), standing where you put it
-- in layout mode while a window is minimized. Each conversation waiting is a row, as the notices' list has them:
-- the person's class color down its edge and in their name, the last thing said under it, when at the right, or
-- a gold count while there is news, the edge blinking gold. A click brings the conversation back.

-- When a conversation last spoke: "now", minutes, else the time of day.
local function Ago(t)
	local d = time() - (t or 0)
	if d < 60 then return "now" end
	if d < 3600 then return math.floor(d / 60) .. " min" end
	return date("%H:%M", t)
end

local function Row(i)
	local r = dock.rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, dock)
	r:SetHeight(ROW)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.edge = r:CreateTexture(nil, "ARTWORK")
	r.edge:SetPoint("TOPLEFT", 1, -1)
	r.edge:SetPoint("BOTTOMLEFT", 1, 1)
	r.edge:SetWidth(2)
	r.badge = CreateFrame("Frame", nil, r)
	r.badge:SetSize(16, 16)
	r.badge:SetPoint("TOPRIGHT", -8, -5)
	local gold = r.badge:CreateTexture(nil, "BACKGROUND")
	gold:SetAllPoints()
	UI.Paint(gold, C.alert)
	r.badge.text = UI.Text(r.badge, "", 11, true, C.onAlert)
	r.badge.text:SetShadowColor(0, 0, 0, 0)
	r.badge.text:SetPoint("CENTER")
	r.when = UI.Text(r, "", 11, false, C.dim)
	r.when:SetPoint("TOPRIGHT", -8, -7)
	r.name = UI.TitleText(r, "", UI.TITLE_SIZE, C.text)
	r.name:SetPoint("TOPLEFT", 11, -6)
	r.name:SetPoint("RIGHT", r, "RIGHT", -54, 0)
	r.name:SetWordWrap(false)
	r.said = UI.Text(r, "", 11, false, C.dim)
	r.said:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.said:SetPoint("RIGHT", r, "RIGHT", -8, 0)
	r.said:SetJustifyH("LEFT")
	r.said:SetWordWrap(false)
	r:SetScript("OnClick", function(self, button)
		local talk = talks[self.key]
		if not talk or HUD.WasDragged(dock) then return end
		if button == "RightButton" then
			UI.ContextMenu(self, function(root)
				root:CreateTitle(talk.name)
				root:CreateButton("Open", function() Wh.Open(talk.key) end)
				if Win(talk) then root:CreateButton("Close", function() set:Leave(talk.key) end) end
			end)
			return
		end
		Wh.Open(talk.key)
	end)
	UI.Press(r, { bare = true })
	HUD.Carry(dock, r)
	dock.rows[i] = r
	return r
end

local function Waiting()
	local list = {}
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open and w.min then
			for _, key in ipairs(w.keys) do list[#list + 1] = talks[key] end
		end
	end
	return list
end

-- Every minimized window back at once, or let go of.
local function Every(fn)
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open and w.min then fn(w) end
	end
end

local function MakeDock()
	dock = HUD.Create({
		id = "shychat.whisperdock", title = "Whisper dock",
		width = DOCK_W, height = DOCK_HEAD + ROW + ROW_PAD * 2,
		point = { "BOTTOMRIGHT", "BOTTOMRIGHT", -24, 260 },
		shown = function() return db.whispers and dock ~= nil and #dock.waiting > 0 end,
	})
	dock.waiting, dock.rows = {}, {}
	UI.Panel(dock, { cap = true, title = UI.HEAD_STRIP, facets = false, hud = true })
	-- (Not `title`: that is the box's name in layout mode.)
	dock.heading = UI.TitleText(dock, "Whispers", UI.TITLE_SIZE)
	UI.OnHead(dock.heading, "LEFT", dock, "LEFT", 10)
	dock.news = UI.Text(dock, "", 11, true, C.dim)
	UI.OnHead(dock.news, "RIGHT", dock, "RIGHT", -10)
	HUD.Manage(dock, dock, function(root)
		root:CreateButton("Bring them all back", function() Every(function(w) Minimize(w, false) end) end)
		root:CreateButton("Close them all", function()
			Every(function(w)
				for i = #w.keys, 1, -1 do set:Leave(w.keys[i]) end
			end)
		end)
	end)

	function dock:Paint()
		local news = 0
		for i, talk in ipairs(self.waiting) do
			local r = self.rows[i]
			local c = ClassColor(talk) or Theme.Accent
			local fresh = talk.unread > 0
			if fresh then news = news + 1 end
			UI.Paint(r.edge, fresh and lit and C.alert or c, fresh and 1 or 0.6)
			UI.Paint(r.shyPress.line, c)
			r.badge:SetShown(fresh)
			r.badge.text:SetText(fresh and talk.unread or "")
			r.when:SetShown(not fresh)
		end
		if news > 0 then
			self.news:SetText(news == 1 and "1 new" or (news .. " new"))
			UI.Ink(self.news, C.alert)
		else
			self.news:SetText(#self.waiting)
			UI.Ink(self.news, C.dim)
		end
	end
end

function Docked()
	if not dock then return end
	dock.waiting = Waiting()
	local y = DOCK_HEAD + ROW_PAD
	for i, talk in ipairs(dock.waiting) do
		local r = Row(i)
		r.key = talk.key
		r.name:SetText(Named(talk))
		r.said:SetText(LastSaid(talk) or "")
		r.when:SetText(Ago(talk.rec.at))
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", dock, "TOPLEFT", ROW_IN, -y)
		r:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -ROW_IN, -y)
		r:Show()
		y = y + ROW + ROW_GAP
	end
	for i = #dock.waiting + 1, #dock.rows do dock.rows[i]:Hide() end
	HUD.Resize(dock, dock:GetWidth(), y - ROW_GAP + ROW_PAD + DOCK_FOOT)
	HUD.Update(dock)
	dock:Paint()
end

-- The head: the notice counts conversations with news, and a whisper nobody sees is said for a moment.

local function Rows()
	local list = {}
	for _, talk in pairs(talks) do
		if talk.rec.lines[1] then list[#list + 1] = talk end
	end
	table.sort(list, function(a, b)
		if (a.unread > 0) ~= (b.unread > 0) then return a.unread > 0 end
		return (a.rec.at or 0) > (b.rec.at or 0)
	end)
	local rows = {}
	for i = 1, math.min(LISTED, #list) do
		local talk = list[i]
		rows[i] = {
			glyph = "talk", tint = talk.unread > 0 and C.alert or C.dim,
			text = talk.name, color = ClassColor(talk) or C.text,
			right = talk.unread > 0 and (talk.unread .. " new") or Ago(talk.rec.at),
			rightColor = talk.unread > 0 and C.alert or C.dim,
			click = function() Wh.Open(talk.key) end,
		}
	end
	return rows
end

function Post()
	local news = 0
	for _, talk in pairs(talks) do
		if talk.unread > 0 then news = news + 1 end
	end
	if news == 0 or not db.whispers then
		N.Clear(NOTICE)
		return
	end
	N.Post(NOTICE, {
		order = 20, glyph = "talk", color = NoticeColor, count = news,
		title = "Whispers",
		says = news == 1 and "Someone whispered you. Click to see who." or (news .. " people whispered you. Click to see who."),
		rows = Rows,
		menu = function(root)
			root:CreateButton("Mark all read", function()
				for _, talk in pairs(talks) do talk.unread = 0 end
				Post()
				Paint()
			end)
		end,
	})
end

local function Speak(talk, text)
	N.Voice(VOICE, {
		priority = 20, hold = 4, glyph = "talk", color = { NoticeColor() },
		title = talk.first, under = UI.PlainText(text),
		click = function() Wh.Open(talk.key) end,
	})
end

-- A conversation's menu (right-click its tab).
function Menu(owner, w, key)
	local talk = talks[key]
	UI.ContextMenu(owner, function(root)
		root:CreateTitle(talk.name)
		if not talk.bn then
			root:CreateButton("Invite to group", function() C_PartyInfo.InviteUnit(talk.key) end)
			if not C_FriendList.GetFriendInfo(talk.key) then
				root:CreateButton("Add friend", function() C_FriendList.AddFriend(talk.key) end)
			end
		end
		root:CreateDivider()
		if #w.keys > 1 then root:CreateButton("Own window", function() set:Own(talk.key) end) end
		root:CreateButton("Clear lines", function()
			wipe(talk.rec.lines)
			if w.current == talk.key then Fill(w) end
		end)
		root:CreateButton("Close", function() set:Leave(talk.key) end)
	end)
end

-- Typing: Enter whispers the conversation open in the window.

function Wh.Send(w, edit)
	local talk = talks[w.current]
	local text = edit:GetText()
	if not talk or not text:find("%S") then
		edit:SetText("")
		return
	end
	if C_ChatInfo.InChatMessagingLockdown() then
		T:Print("whispers can't be sent right now. Your words are still in the box.")
		return
	end
	text = ChatFrameUtil.SubstituteChatMessageBeforeSend(text)
	sending = talk.key
	if talk.bn then
		C_BattleNet.SendWhisper(talk.bn, text)
	else
		C_ChatInfo.SendChatMessage(text, "WHISPER", nil, talk.key)
	end
	edit:AddHistoryLine(text)
	edit:SetText("")
	lastUsed = w
end

-- Hearing whispers

local function Add(talk, line)
	local lines = talk.rec.lines
	lines[#lines + 1] = line
	local most = talk.bn and BN_LINES or db.whisperLines
	while #lines > most do table.remove(lines, 1) end
	talk.rec.at = line.t
	local w = Win(talk)
	if w and w.current == talk.key then Put(w, talk, line) end
end

local EVENTS = {
	CHAT_MSG_WHISPER = false, CHAT_MSG_WHISPER_INFORM = true,
	CHAT_MSG_BN_WHISPER = false, CHAT_MSG_BN_WHISPER_INFORM = true,
}

local function Heard(event, text, sender, _, _, _, _, _, _, _, _, _, guid, bnID)
	-- What the game keeps from addons stays in chat alone.
	if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then return end
	local me = EVENTS[event]
	local bn = event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM"
	local key
	if bn then
		if issecretvalue(bnID) or type(bnID) ~= "number" or bnID == 0 then return end
		key = "bn:" .. bnID
	else
		key = Ambiguate(sender, "none")
	end
	local talk = Talk(key, sender, bn and bnID or nil)
	if not bn then
		local class, race = ClassOf(guid)
		if class then talk.rec.class, talk.rec.race = class, race end
	end
	Add(talk, { t = time(), m = text, me = me or nil })
	if not db.whispers then return end
	if me then
		talk.unread = 0
		local typedHere = sending == key
		sending = nil
		if not typedHere then Open(talk, not InCombatLockdown()) end
	else
		Open(talk, false)
		if not Seen(talk) then
			talk.unread = talk.unread + 1
			Speak(talk, text)
		end
	end
	Post()
	Docked()
	Paint()
end

-- Settings, fights and keeping

function Wh.Apply()
	if not db then return end
	for _, w in pairs(set.wins) do
		Face(w)
		Refresh(w)
		if w.open then Fill(w) end
	end
	Docked()
	Post()
end

function Wh.Forget()
	for _, w in pairs(set.wins) do
		quiet = true
		w.box:Hide()
		quiet = false
		Shut(w)
	end
	wipe(talks)
	Docked()
	Post()
end

-- In a fight the windows step aside (HUD.Update reads it); after it they and what came are back.
-- Only whether a window shows changes: the dock and the tabs stand as they were, unless a window
-- that came back holds news, which is read now.
local function Fight(now)
	fighting = now
	local read = false
	for _, w in pairs(set.wins) do
		quiet = true
		HUD.Update(w.box)
		quiet = false
		local talk = w.current and talks[w.current]
		if talk and talk.unread > 0 and w.box:IsVisible() then
			Read(talk)
			read = true
		end
	end
	if read then Paint() end
	if fighting then return end
	for _, talk in pairs(talks) do
		if talk.held then Open(talk, false) end
	end
	Post()
end

local function Windows()
	set = UI.TabWindows({
		id = "shychat.whispers", title = "Whispers", most = MOST,
		width = WIDTH, height = HEIGHT, least = LEAST,
		point = { "CENTER", "CENTER", -300, 80 },
		shown = Wanted, onClose = Closed,
		-- Right to left after the ×: maximize, minimize.
		controls = {
			{ key = "max", glyph = MEDIA .. "GlyphMaximize", tip = { "Maximize", "Fill the screen. Click again to put it back." },
				click = function(w) Maximize(w, not w.maxed) end },
			{ key = "min", glyph = MEDIA .. "GlyphMinus", tip = { "Minimize", "Tuck it into the whisper dock. Click its name there to bring it back." },
				click = function(w) Minimize(w, true) end },
		},
		list = { "Conversations", "Every conversation in this window." },
		build = Build,
		label = Label,
		name = function(key) return Named(talks[key]) end,
		tint = function(key) return ClassColor(talks[key]) end,
		picked = Picked,
		moved = Refresh,
		emptied = Emptied,
		menu = Menu,
		row = function(entry, key, w)
			local talk = talks[key]
			local said = LastSaid(talk)
			if said then entry:SetSub(said) end
			if talk.unread > 0 then
				entry:SetDetail(Gold(talk.unread .. " new"))
			elseif key == w.current then
				entry:SetDetail("open")
			end
		end,
	})
end

function Wh.Init(settings)
	db = settings
	fighting = InCombatLockdown()
	for key, rec in pairs(Store()) do
		if type(rec) == "table" and type(rec.lines) == "table" and rec.lines[1] then
			Talk(key, rec.name or key)
		else
			Store()[key] = nil
		end
	end
	Windows()
	MakeDock()
	local events = CreateFrame("Frame")
	for event in pairs(EVENTS) do events:RegisterEvent(event) end
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_LOGOUT")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "PLAYER_LOGOUT" then
			Wh.Keep()
		elseif event == "PLAYER_REGEN_DISABLED" then
			Fight(true)
		elseif event == "PLAYER_REGEN_ENABLED" then
			Fight(false)
		else
			Heard(event, ...)
		end
	end)
	-- Shift-click a link while typing in a window puts it there.
	hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
		if type(text) ~= "string" then return end
		for _, w in pairs(set.wins) do
			if w.edit:HasFocus() then w.edit:Insert(text) end
		end
	end)
	-- The chat's text size changed: the windows' words follow.
	if ChatFrame1 then
		hooksecurefunc(ChatFrame1, "SetFont", function()
			for _, w in pairs(set.wins) do Face(w) end
		end)
	end
	-- A maximized window dragged or sized is put back to its own size first.
	Shy:On("SHY_HUD_MOVING", function(box)
		for _, w in pairs(set.wins) do
			if w.box == box and w.maxed then Wh.Unmax(w, true) end
		end
	end)
	Shy:On("SHY_THEME", function()
		for _, w in pairs(set.wins) do
			if w.open then Fill(w) end
		end
		Docked()
		Paint()
	end)
end

-- Across a reload or relog the windows come back as they were: their tabs, the one open, minimized or maximized.
-- (Where each stands is the HUD's, by window.) Battle.net conversations last a session, so they don't.
function Wh.Keep()
	local kept = {}
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open then
			local keys = {}
			for _, key in ipairs(w.keys) do
				if not talks[key].bn then keys[#keys + 1] = key end
			end
			if keys[1] then
				kept[#kept + 1] = { n = n, keys = keys, current = w.current, min = w.min, maxed = w.maxed ~= nil }
			end
		end
	end
	ShyChatHistory.whisperWindows = kept[1] and kept or nil
end

function Wh.Restore()
	local kept = ShyChatHistory.whisperWindows
	Log(("restore: %s kept, whispers %s"):format(type(kept) == "table" and #kept or "none", tostring(db.whispers)))
	if not db.whispers or type(kept) ~= "table" then return end
	for _, saved in ipairs(kept) do
		local n = tonumber(saved.n)
		if n and n >= 1 and n <= MOST and not (set.wins[n] and set.wins[n].open) and type(saved.keys) == "table" then
			local w = set.wins[n] or set:Make(n)
			w.min = saved.min and true or nil
			for _, key in ipairs(saved.keys) do
				local talk = talks[key]
				if talk and not Win(talk) then set:Join(w, key) end
			end
			if w.keys[1] then
				local current = talks[saved.current]
				if current and Win(current) == w then Show(current) end
				set.last = w
				Refresh(w)
				if saved.maxed and not w.min then Maximize(w, true) end
			end
			Log(("restored window %d: %d tabs, shown %s"):format(n, #w.keys, tostring(w.box:IsShown())))
		end
	end
	Docked()
end

-- /shychat whispers: the windows as they stand and what happened to them lately, to copy.
function Wh.Report()
	local out = { ("whispers %s, open as %s, in a fight %s, UI shown %s"):format(tostring(db.whispers),
		tostring(db.whisperOpen), tostring(InCombatLockdown()), tostring(UIParent:IsShown())) }
	local kept = ShyChatHistory.whisperWindows
	out[#out + 1] = "kept: " .. (type(kept) == "table" and #kept or "none")
	for n = 1, MOST do
		local w = set.wins[n]
		if w then
			local box = w.box
			local left, top = box:GetLeft(), box:GetTop()
			out[#out + 1] = ("window %d: open %s, min %s, maxed %s, shown %s, visible %s, alpha %.2f/%.2f, strata %s, at %s,%s size %dx%d, tabs %s, current %s")
				:format(n, tostring(w.open), tostring(w.min), tostring(w.maxed ~= nil), tostring(box:IsShown()),
				tostring(box:IsVisible()), box:GetAlpha(), box:GetEffectiveAlpha(), tostring(box:GetFrameStrata()),
				tostring(left and math.floor(left)), tostring(top and math.floor(top)), box:GetWidth(), box:GetHeight(),
				table.concat(w.keys, " / "), tostring(w.current))
		end
	end
	out[#out + 1] = "lately:"
	for _, line in ipairs(log) do out[#out + 1] = "  " .. line end
	return table.concat(out, "\n")
end

-- For tests and /shychat: the windows, conversations and the dock as they stand, and the windows' set.
function Wh.State() return set.wins, talks, dock, set end
Wh.Minimize, Wh.Maximize = Minimize, Maximize
