-- Whisper windows: each conversation a tab, the header the chat's, the words the chat's size. Tabs dock together
-- and come apart (UI.TabWindows): drag one onto another window's tabs, onto the chat, or off into a window of its
-- own. A whisper opens its conversation where you put that person last (someone new: where you usually put people,
-- or as the setting says), never in a fight. A window maximizes to the screen or minimizes into the whisper dock, a
-- piece of the layout where each conversation waits as a plate that lights up with news and opens on a click.
-- Docked in the chat (restyled windows only): tabs of ours after the game's in its strip; the open one lays its
-- conversation over the chat's text, which fades out under it (its alpha alone: nothing of the chat's is moved,
-- called or written), until a game tab is clicked.
-- Keys go where you were: Enter to the conversation you last typed in (or the one open in the chat) while it shows,
-- the reply keys to the person's conversation, and "/" to the chat box as ever. A command typed in a conversation's
-- row runs as the chat box's do (Window.lua). The keys are override bindings of our own, set only out of a fight.
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
-- In the chat: its strip's tabs (the panel's header, the line under it), a little clear of the game's last tab, over
-- the chat's own frames (the toolbar stands higher still); the page over its text.
local CHAT = { tall = UI.HEAD_STRIP + UI.LINE, gap = 1, strip = 20, page = 25 }
local HABIT = 6           -- the places you last put conversations in, for where someone new goes
local TAB_REST = 0.55     -- a tab at rest: this much of the way from the dim ink to its whisper's color
local COMMAND = "^/[^%s/]"   -- a line that is a command, not words to whisper
-- The keys: buttons our override bindings click, and the game's commands they stand in for.
local KEYS = { owner = nil, word = nil,
	talk = { "OPENCHAT", "ShyChatWhisperTalk" }, reply = { "REPLY", "ShyChatWhisperReply" }, retell = { "REPLY2", "ShyChatWhisperRetell" } }

local talks = {}         -- key -> { key, name, first, bn, rec, unread, held }
local set                -- the windows (UI.TabWindows): set.wins[n], set.of[key]
local host               -- the chat, as a place conversations dock (set:Host); nil without the chat's dock
local hostUp = false     -- a conversation docked in the chat is open over its text
local covered, boxWas    -- the chat window under the page; whether its box ignored its alpha before
local lastUsed           -- the window a whisper went to or was typed in last
local talkTo             -- where Enter goes: the window you were typing in, while it shows
local lastFrom, lastTo   -- who whispered you last; whom you whispered last
local started = time()   -- lines before it are a session ago
local quiet = false      -- we are hiding a window ourselves: it isn't being closed
local fighting = false   -- from the fight's start, which comes just before the lockdown, to its end
local sending            -- the conversation a line was just typed in, until its echo comes back
local blinker, lit = nil, false
local dock

local Fill, Post, Paint, Docked, Menu, HostLay, Keys, GameDrags

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

-- Where you put conversations: each person's place (rec.home: "chat", "tab" or "window"), and the last few places
-- you put anyone (db.whisperHabit), the most of them where someone new goes.

-- Conversations can dock in the chat: whisper windows on, the chat's windows restyled, and the chat's dock there.
local function InChat()
	return host ~= nil and db.whispers and db.windowSkin
end

local function Habit()
	local list = db.whisperHabit
	if type(list) ~= "table" or not list[1] then return "window" end
	local chat, tab, window = 0, 0, 0
	for _, home in ipairs(list) do
		if home == "chat" then chat = chat + 1 elseif home == "tab" then tab = tab + 1 else window = window + 1 end
	end
	local most = math.max(chat, tab, window)
	-- Even: the latest of the ones that tie.
	for i = #list, 1, -1 do
		local home = list[i]
		if (home == "chat" and chat == most) or (home == "tab" and tab == most) or (home == "window" and window == most) then
			return home
		end
	end
	return "window"
end

local function Home(talk)
	local how = db.whisperOpen
	if how == "auto" then how = talk.rec.home or Habit() end
	if how == "chat" and not InChat() then how = "window" end
	return how
end

-- You put a conversation in `w` (carried there, or from a menu).
local function Remember(key, w)
	local talk = talks[key]
	if not (talk and w) then return end
	local home = (w == host and "chat") or (#w.keys > 1 and "tab") or "window"
	talk.rec.home = home
	local list = db.whisperHabit
	if type(list) ~= "table" then
		list = {}
		db.whisperHabit = list
	end
	list[#list + 1] = home
	while #list > HABIT do table.remove(list, 1) end
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

-- The chat window a conversation's words are sized by, and whose text size its menu sets: the one it lies over in
-- the chat (the chat's open window while it isn't), the chat's first window for a whisper window.
local function Chat(w)
	if w == host then return covered or GeneralDockManager.selected or DEFAULT_CHAT_FRAME end
	return DEFAULT_CHAT_FRAME
end

-- The words are the chat's: its face at its size.
local function Face(w)
	local chat = Chat(w)
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

local function Ink(edit, words, c)
	edit.header:SetText(words)
	edit.header:SetTextColor(c[1], c[2], c[3])
	edit:SetTextColor(c[1], c[2], c[3])
	edit:SetTextInsets(8 + edit.header:GetStringWidth() + 4, 8, 0, 0)
end

-- The typing row: "To Mira:" in the whisper's color, the words after it; "Command:" while a command is typed.
local function Header(w, talk)
	w.command = false
	local info = Kind(talk, false)
	Ink(w.edit, "To " .. talk.first .. ":", { info.r, info.g, info.b })
end

local function Typed(w)
	local text = w.edit:GetText()
	local command = not issecretvalue(text) and text:find(COMMAND) ~= nil
	if command == w.command then return end
	local talk = talks[w.current]
	if command then
		w.command = true
		Ink(w.edit, "Command:", C.text)
	elseif talk then
		Header(w, talk)
	end
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
	Typed(w)
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

-- A conversation's tab words in its whisper's color, as chat writes whispers: whole while open or under the mouse,
-- stepped back toward the dim ink at rest. (Kept on the conversation and filled again: this runs at every blink.)
local function Inks(talk)
	local inks = talk.inks
	if not inks then
		inks = { open = {}, rest = {} }
		talk.inks = inks
	end
	local info, dim = Kind(talk, false), C.dim
	inks.open[1], inks.open[2], inks.open[3] = info.r, info.g, info.b
	for i, v in ipairs(inks.open) do inks.rest[i] = dim[i] + (v - dim[i]) * TAB_REST end
	return inks
end

-- A window's tabs (the chat's: its open one reads as open only while it is in view).
local function PaintWin(w)
	if not w.open then return end
	local shown = w ~= host or hostUp
	for i, key in ipairs(w.keys) do
		local tab, talk = w.tabs.tabs[i], talks[key]
		local open = key == w.current and shown
		local news = talk.unread > 0 and not open
		local inks = Inks(talk)
		w.tabs:SetBadge(i, news and talk.unread or 0)
		w.tabs:SetTint(i, ClassColor(talk))
		w.tabs:SetInk(i, inks.open, inks.rest)
		if news then UI.Ink(tab.text, lit and C.alert or inks.rest) end
	end
end

function Paint()
	for _, w in pairs(set.wins) do PaintWin(w) end
	if host then PaintWin(host) end
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
	-- A docked tab clicked: its conversation over the chat, and Enter goes there.
	if w == host and not hostUp then
		hostUp = true
		talkTo = host
		HostLay()
	end
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
	if w == host then
		HostLay()
	else
		quiet = true
		HUD.Update(w.box)
		quiet = false
	end
	if w.box:IsVisible() and w.current then Read(talks[w.current]) end
	Docked()
	Paint()
	Keys()
end

-- A window let go of: its conversations wait for the next whisper.
local function Shut(w)
	w.min = nil
	Wh.Unmax(w)
	for _, key in ipairs(w.keys) do talks[key].unread = 0 end
	set:Clear(w)
	w.edit:ClearFocus()
	if lastUsed == w then lastUsed = nil end
	if talkTo == w then talkTo = nil end
	Post()
	Docked()
	Paint()
	Keys()
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

-- The chat's last conversation taken out: its text is back.
local function HostDown()
	hostUp = false
	if talkTo == host then talkTo = nil end
	if host.tabs.selected then host.tabs:Select(nil) end
	HostLay()
	Paint()
end

-- Its last conversation docked elsewhere or closed: the window goes quietly.
local function Emptied(w)
	if w == host then
		HostDown()
		Post()
		return
	end
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

-- A window's body: who it is, the lines, the typing row. The chat's page lies on its text, edge to edge with it.
local function Build(w)
	local box = w.box
	local docked = w.host ~= nil
	local top = docked and 0 or HEAD.line + UI.LINE
	local pad = docked and 0 or PAD
	-- On the window's body: clear of the look's work round the edge (UI.Body).
	local body = docked and box or UI.Body(box)

	w.who = UI.Text(body, "", 11, false, C.dim)
	w.who:SetPoint("TOPLEFT", pad + (docked and 0 or 2), -(top + 5))
	w.who:SetPoint("RIGHT", body, "RIGHT", -pad, 0)
	w.who:SetJustifyH("LEFT")
	w.who:SetWordWrap(false)

	local msg = CreateFrame("ScrollingMessageFrame", nil, body)
	msg:SetPoint("TOPLEFT", pad + (docked and 0 or 2), -(top + 5 + WHO))
	msg:SetPoint("BOTTOMRIGHT", -pad - (docked and 0 or 2), pad + TYPING + 5)
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

	local edit = CreateFrame("EditBox", nil, body)
	edit:SetPoint("BOTTOMLEFT", pad, pad)
	edit:SetPoint("BOTTOMRIGHT", -pad, pad)
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
	-- Esc leaves the row; Enter no longer comes back to a window (the chat's open conversation still takes it).
	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		if talkTo == w and w ~= host then
			talkTo = nil
			Keys()
		end
	end)
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
		talkTo = w
		Keys()
	end)
	edit:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	edit:SetScript("OnTextChanged", function() Typed(w) end)
	w.edit = edit
	-- Commands typed here run as the chat box's do (a protected one through the chat's own button).
	ns.Window.Commands(edit)
	Face(w)

	-- A click anywhere in the window puts the cursor in its typing row.
	if docked then box:EnableMouse(true) end
	box:HookScript("OnMouseDown", function() edit:SetFocus() end)
	box:HookScript("OnHide", function()
		-- Hidden by this file (stepping aside, closing): no stack to read.
		local by = quiet and "ShyChat" or (debugstack(2, 6, 0) or ""):gsub("Interface/AddOns/", ""):gsub("\n", " < ")
		Log(("window %s OnHide (open %s, min %s, quiet %s) by %s"):format(tostring(w.n), tostring(w.open), tostring(w.min), tostring(quiet), by))
	end)
end

-- A whisper window up to join as a tab (never the chat).
local function AnyOpen()
	if lastUsed and lastUsed ~= host and lastUsed.open and not lastUsed.min then return lastUsed end
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open and not w.min then return w end
	end
end

-- Opens a conversation where it goes (Home). `focus`: bring it up with the cursor in it (a whisper you sent, a plate
-- clicked, a reply key). Without it, news alone: a minimized window stays in the dock, the chat shows its own text.
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
		local home = Home(talk)
		if home == "chat" then
			w = host
		elseif home == "tab" then
			w = AnyOpen()
			if w and not set:Fits(w, talk.first) then w = nil end
		end
		w = w or set:Window() or AnyOpen()
		if not w then return end
		was = w.open
		set:Join(w, talk.key)
	end
	if w == host then
		HostLay()
		if focus then
			Show(talk)
			host.edit:SetFocus()
		end
		return
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

-- Docked in the chat. The chat's dock holds its first window and the ones docked with it; the selected one is the
-- one in view. Our strip stands after the game's last tab (or its overflow arrow) to the strip's end, on the chat's
-- header; a drop anywhere on the chat docks there. Its line is the chat's own: ours is laid along it unseen, for
-- the open tab's mark to stand on.

-- What the strip stands after; asked each time the game lays its tabs out, so only a change is worked on.
-- (Asked each time the game lays its tabs out: only a change of its windows is worked on.)
local after = {}
local function Anchor()
	local manager = GeneralDockManager
	local list = manager.DOCKED_CHAT_FRAMES
	local count, last = #list, list[#list] or false
	if after.laid and count == after.count and last == after.last then return end
	after.laid, after.count, after.last = true, count, last
	local dynamic
	for i = count, 1, -1 do
		if not list[i].isStaticDocked then
			dynamic = list[i]
			break
		end
	end
	local strip, bg = host.head, DEFAULT_CHAT_FRAME.Background
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOM", bg, "TOP", 0, ns.Look.STRIP_FOOT - UI.LINE)
	if dynamic then
		strip:SetPoint("LEFT", _G[dynamic:GetName() .. "Tab"], "RIGHT", CHAT.gap, 0)
	else
		strip:SetPoint("LEFT", manager.scrollFrame:GetScrollChild(), "LEFT", CHAT.gap, 0)
	end
end

-- The game's window under the page: its text faded out, the page laid over it, its tab no longer the open one. Its
-- box and our toolbar on it (children of it) stay seen. Uncovered as it was.
local function Cover(on)
	local frame = on and (GeneralDockManager.selected or DEFAULT_CHAT_FRAME) or nil
	if frame == covered then return end
	if covered then
		covered:SetAlpha(1)
		covered.editBox:SetIgnoreParentAlpha(boxWas)
		local bar = ns.Window.Tools(covered)
		if bar then bar:SetIgnoreParentAlpha(false) end
	end
	covered = frame
	if frame then
		host.box:ClearAllPoints()
		host.box:SetAllPoints(frame)
		Face(host)   -- in the size of the window it lies over
		boxWas = frame.editBox:IsIgnoringParentAlpha()
		frame:SetAlpha(0)
		frame.editBox:SetIgnoreParentAlpha(true)
		local bar = ns.Window.Tools(frame)
		if bar then bar:SetIgnoreParentAlpha(true) end
	end
	ns.Look.Aside(frame)
end

-- The chat as a place to dock, as things stand: taking drops, its strip while it holds tabs, its page while one is open.
function HostLay()
	if not host then return end
	local can = InChat()
	host.zone:SetShown(can)
	host.head:SetShown(can and host.open)
	local up = can and host.open and hostUp and not Held()
	if host.box:IsShown() ~= up then
		quiet = true
		host.box:SetShown(up)
		quiet = false
	end
	Cover(up)
	if up and host.current then Read(talks[host.current]) end
	-- Ours came, went or opened: the row as the chat's look keeps it (the open tab in view).
	ns.Look.SettleTabs()
	Keys()
end

local function MakeHost()
	local manager, chat = GeneralDockManager, DEFAULT_CHAT_FRAME
	local bg = chat.Background
	local zone = CreateFrame("Frame", nil, manager)
	zone:SetFrameStrata("BACKGROUND")
	zone:SetPoint("TOPLEFT", bg, "TOPLEFT", 0, ns.Look.STRIP_FOOT + UI.HEAD_STRIP)
	zone:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT")
	zone:Hide()
	-- Our tabs in the row of the game's that scroll, after its last: they scroll with it and are cut to its view.
	local strip = CreateFrame("Frame", nil, manager.scrollFrame:GetScrollChild())
	strip:SetFrameStrata("MEDIUM")
	strip:SetFrameLevel(CHAT.strip)
	strip:SetHeight(CHAT.tall)
	strip.shyStripColor = C.hudStrip
	strip.shyLine = UI.HeadLine(strip)
	strip.shyLine:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, -UI.HEAD_STRIP)
	strip.shyLine:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, -UI.HEAD_STRIP)
	strip.shyLine:SetAlpha(0)
	strip:Hide()
	-- The chat's whole header row: a tab let go of along it lands among ours where the cursor is.
	local band = CreateFrame("Frame", nil, zone)
	band:SetPoint("BOTTOMLEFT", bg, "TOPLEFT")
	band:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
	band:SetHeight(ns.Look.STRIP_FOOT + UI.HEAD_STRIP)
	local page = CreateFrame("Frame", nil, manager)
	page:SetFrameStrata("MEDIUM")
	page:SetFrameLevel(CHAT.page)
	page:SetAllPoints(chat)
	page:Hide()
	-- Kept readable with the chat while the HUD is faded.
	local immersion = Shy.Immersion
	if immersion and immersion.Watch then
		immersion.Watch("chat", page)
		immersion.Watch("chat", strip)
	end
	host = set:Host({ box = page, zone = zone, strip = strip, band = band, tall = CHAT.tall, mid = UI.HEAD_MID,
		gap = CHAT.gap, up = function() return hostUp end })
	Anchor()
	hooksecurefunc("FCFDock_UpdateTabs", function(manager)
		if manager == GeneralDockManager then Anchor() end
	end)
	-- A game tab picked: its text is back. Clicked, even the one under the page (the game selects nothing then, it
	-- already is): its text is back too.
	hooksecurefunc("FCFDock_SelectWindow", function(manager)
		if manager == GeneralDockManager and hostUp then HostDown() end
	end)
	hooksecurefunc("FCF_Tab_OnClick", function(_, button)
		if hostUp and button ~= "RightButton" and button ~= "MiddleButton" then HostDown() end
	end)
	-- The chat box in use: the page's own row makes way for it; let go of, Enter comes back to the page.
	EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function()
		host.edit:SetShown(not covered)
		talkTo = nil
		Keys()
	end, Wh)
	EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusLost", function()
		host.edit:Show()
		if host.box:IsShown() then talkTo = host end
		Keys()
	end, Wh)
end

-- For the chat's toolbar, grip and menu: how far our tabs reach, the page while it covers the chat, our tabs while
-- they show, how many are docked, whether one is open, a row each.
function Wh.Page() return covered and host.box or nil end
function Wh.Tabs() return host and host.head:IsVisible() and host.tabs or nil end
-- The conversation open over the chat: its tab, for the row to keep in view.
function Wh.OpenTab()
	if not (hostUp and host.current and host.head:IsVisible()) then return nil end
	for i, key in ipairs(host.keys) do
		if key == host.current then return host.tabs.tabs[i] end
	end
end

-- (Our last tab's own right edge: the row ends there, not at the spacing after it.)
function Wh.StripRight()
	if not (host and host.open and host.head:IsVisible()) then return nil end
	local last = host.tabs.tabs[#host.keys]
	return last and last:GetRight() or nil
end

function Wh.InChat() return host and #host.keys or 0 end
function Wh.Covering() return covered ~= nil end
-- Whether a conversation lies over this chat window now (its tools are the conversation's then).
function Wh.Over(frame) return covered ~= nil and covered == frame end

-- A conversation's lines in the copy box, as they read; its lines let go of.
function Wh.Copy(talk)
	local out = {}
	for _, line in ipairs(talk.rec.lines) do out[#out + 1] = UI.PlainText(Written(talk, line, true)) end
	ns.Window.ShowCopy(talk.name, table.concat(out, "\n"))
end

function Wh.Clear(w, talk)
	wipe(talk.rec.lines)
	if w.current == talk.key then Fill(w) end
end

function Wh.CopyOpen()
	local talk = host.current and talks[host.current]
	if talk then Wh.Copy(talk) end
end

function Wh.ClearOpen()
	local talk = host.current and talks[host.current]
	if talk then Wh.Clear(host, talk) end
end

function Wh.MenuRows(root)
	for _, key in ipairs(host.keys) do
		local talk = talks[key]
		local row = root:CreateButton(Named(talk), function() Wh.Open(key) end)
		if talk.unread > 0 then
			row:SetDetail(Gold(talk.unread .. " new"))
		elseif hostUp and key == host.current then
			row:SetDetail("open")
		end
	end
end

-- Keys: Enter to the conversation you were typing in while it shows; the reply keys to the person's. Bound only
-- while there is somewhere for them to go, and never changed in a fight (a fight that hides the windows lets them go
-- as it starts, just before the lockdown). The game's keys for each are read as they are bound: keys changed in its
-- settings are taken up the next time where they go changes.

local function Showing(w)
	return w ~= nil and w.open and w.box:IsVisible()
end

local function Bind(pair, out)
	local a, b = GetBindingKey(pair[1])
	if a then SetOverrideBindingClick(KEYS.owner, false, a, pair[2]) end
	if b then SetOverrideBindingClick(KEYS.owner, false, b, pair[2]) end
	return out .. " " .. pair[1] .. "=" .. tostring(a) .. "," .. tostring(b)
end

-- (A word for what is bound, so only a change binds again: this runs as often as windows come and go.)
function Keys(again)
	if not KEYS.owner or InCombatLockdown() then return end
	local live = db.whispers and not Held()
	local talk = live and Showing(talkTo)
	local reply = live and lastFrom ~= nil
	local retell = live and lastTo ~= nil
	local word = (talk and "t" or "") .. (reply and "r" or "") .. (retell and "w" or "")
	if word == KEYS.word and not again then return end
	ClearOverrideBindings(KEYS.owner)
	local out = ""
	if talk then out = Bind(KEYS.talk, out) end
	if reply then out = Bind(KEYS.reply, out) end
	if retell then out = Bind(KEYS.retell, out) end
	KEYS.word, KEYS.bound = word, out
end

local function MakeKeys()
	KEYS.owner = CreateFrame("Frame")
	local function Button(pair, click)
		local b = CreateFrame("Button", pair[2], UIParent)
		b:Hide()
		b:SetScript("OnClick", click)
	end
	Button(KEYS.talk, function()
		local w = Showing(talkTo) and talkTo or (host and host.box:IsVisible() and host) or nil
		if w then w.edit:SetFocus() end
	end)
	Button(KEYS.reply, function() if lastFrom then Wh.Open(lastFrom) end end)
	Button(KEYS.retell, function() if lastTo then Wh.Open(lastTo) end end)
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
		if w ~= host and InChat() then
			root:CreateButton("Dock in chat", function()
				set:Join(host, talk.key)
				Remember(talk.key, host)
				Open(talk, true)
			end)
		end
		if #w.keys > 1 or w == host then
			root:CreateButton("Own window", function() Remember(talk.key, set:Own(talk.key)) end)
		end
		-- The chat's own tools, as its windows have them.
		root:CreateButton("Copy chat", function() Wh.Copy(talk) end)
		root:CreateButton("Clear window", function() Wh.Clear(w, talk) end)
		ns.Window.SizeRows(root, Chat(w))
		root:CreateDivider()
		root:CreateButton("Close", function() set:Leave(talk.key) end)
	end)
end

-- Typing: Enter whispers the conversation open in the window. A command got here only when it couldn't run.

function Wh.Send(w, edit)
	local talk = talks[w.current]
	local text = edit:GetText()
	if not talk or not text:find("%S") then
		edit:SetText("")
		return
	end
	if text:find(COMMAND) then
		T:Print(InCombatLockdown() and "commands typed in a whisper run once the fight is over. Your words are still in the box."
			or "that command didn't run. Your words are still in the box.")
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
	if me then lastTo = key else lastFrom = key end
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
	Keys()
end

-- Settings, fights and keeping

function Wh.Apply()
	if not db then return end
	for _, w in pairs(set.wins) do
		Face(w)
		Refresh(w)
		if w.open then Fill(w) end
	end
	if host then
		-- The chat no longer restyled: what was docked there goes to a window of its own (as tabs, once every
		-- window is in use).
		if host.open and db.whispers and not db.windowSkin then
			local w = set:Window() or AnyOpen()
			if w then
				set:Merge(host, w)
				Refresh(w)
			end
		end
		Face(host)
		if host.open then Fill(host) end
		HostLay()
	end
	Docked()
	Post()
	Keys(true)
end

function Wh.Forget()
	for _, w in pairs(set.wins) do
		quiet = true
		w.box:Hide()
		quiet = false
		Shut(w)
	end
	if host then
		set:Clear(host)
		HostDown()
	end
	wipe(talks)
	lastFrom, lastTo = nil, nil
	Docked()
	Post()
	Keys()
end

-- In a fight the windows step aside (HUD.Update reads it); after it they and what came are back.
-- Only whether a window shows changes: the dock and the tabs stand as they were, unless a window
-- that came back holds news, which is read now. The keys go to the chat in it, and come back after.
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
	HostLay()
	if read then Paint() end
	if fighting then return end
	for _, talk in pairs(talks) do
		if talk.held then Open(talk, false) end
	end
	Post()
	Keys()
end

-- A chat window of the game's carried by its tab (the game carries it whole) can dock in the chat and nowhere else:
-- the chat lights as the place it can go, as it does for a conversation carried, until the mouse is let go. (Not the
-- chat's first window: its tab carries the whole chat.)
local dragged = setmetatable({}, { __mode = "k" })   -- tabs followed
local letGo = CreateFrame("Frame")
letGo:SetScript("OnEvent", function(self)
	self:UnregisterEvent("GLOBAL_MOUSE_UP")
	set:Unhint()
end)

-- Any chat window's text size changed (its menu, the game's settings): the conversations' words follow.
local function Refont()
	for _, w in pairs(set.wins) do Face(w) end
	Face(host)
end

local function GameDrag(frame)
	local tab = _G[frame:GetName() .. "Tab"]
	if not tab or dragged[tab] then return end
	dragged[tab] = true
	hooksecurefunc(frame, "SetFont", Refont)
	tab:HookScript("OnDragStart", function()
		if frame == DEFAULT_CHAT_FRAME or not InChat() then return end
		set:Hint(host)
		letGo:RegisterEvent("GLOBAL_MOUSE_UP")
	end)
end

function GameDrags()
	ChatFrameUtil.ForEachChatFrame(GameDrag)
	hooksecurefunc("FCF_OpenNewWindow", function() ChatFrameUtil.ForEachChatFrame(GameDrag) end)
	hooksecurefunc("FCF_OpenTemporaryWindow", function() ChatFrameUtil.ForEachChatFrame(GameDrag) end)
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
		placed = Remember,
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
	MakeHost()
	MakeDock()
	MakeKeys()
	GameDrags()
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
		if host.edit:HasFocus() then host.edit:Insert(text) end
	end)
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
		if host.open then Fill(host) end
		Docked()
		Paint()
	end)
end

-- Across a reload or relog the windows come back as they were: their tabs, the one open, minimized or maximized,
-- and what was docked in the chat (n "chat"), open over it or not. (Where each window stands is the HUD's, by
-- window.) Battle.net conversations last a session, so they don't.
local function Kept(w)
	local keys = {}
	for _, key in ipairs(w.keys) do
		if not talks[key].bn then keys[#keys + 1] = key end
	end
	return keys
end

function Wh.Keep()
	local kept = {}
	for n = 1, MOST do
		local w = set.wins[n]
		if w and w.open then
			local keys = Kept(w)
			if keys[1] then
				kept[#kept + 1] = { n = n, keys = keys, current = w.current, min = w.min, maxed = w.maxed ~= nil }
			end
		end
	end
	if host.open then
		local keys = Kept(host)
		if keys[1] then kept[#kept + 1] = { n = "chat", keys = keys, current = host.current, up = hostUp } end
	end
	ShyChatHistory.whisperWindows = kept[1] and kept or nil
end

function Wh.Restore()
	local kept = ShyChatHistory.whisperWindows
	Log(("restore: %s kept, whispers %s"):format(type(kept) == "table" and #kept or "none", tostring(db.whispers)))
	if not db.whispers or type(kept) ~= "table" then return end
	for _, saved in ipairs(kept) do
		local n = tonumber(saved.n)
		if saved.n == "chat" and type(saved.keys) == "table" then
			for _, key in ipairs(saved.keys) do
				local talk = talks[key]
				if talk and not Win(talk) then set:Join(host, key) end
			end
			local current = talks[saved.current]
			if saved.up and InChat() and current and Win(current) == host then
				Show(current)
			else
				HostLay()
			end
			Log(("restored the chat's %d tabs, open %s"):format(#host.keys, tostring(hostUp)))
		elseif n and n >= 1 and n <= MOST and not (set.wins[n] and set.wins[n].open) and type(saved.keys) == "table" then
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
	out[#out + 1] = ("chat: can dock %s, tabs %s, current %s, open %s, covering %s"):format(tostring(InChat()),
		table.concat(host.keys, " / "), tostring(host.current), tostring(hostUp), tostring(covered and covered:GetName()))
	out[#out + 1] = ("keys: %s (habit %s)"):format(tostring(KEYS.bound),
		type(db.whisperHabit) == "table" and table.concat(db.whisperHabit, " ") or "none")
	out[#out + 1] = "lately:"
	for _, line in ipairs(log) do out[#out + 1] = "  " .. line end
	return table.concat(out, "\n")
end

-- For tests and /shychat: the windows, conversations and the dock as they stand, and the windows' set.
function Wh.State() return set.wins, talks, dock, set, host end
Wh.Minimize, Wh.Maximize = Minimize, Maximize
