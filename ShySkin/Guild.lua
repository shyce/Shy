-- The guild window: a window of our own that the guild key opens in place of the game's (CommunitiesFrame, which
-- holds the guild on this client). The game's window is never emptied, reparented or drawn on: its pieces reach it
-- through GetParent, and put in another frame they raise errors in the game's own code (one of them in its OnShow,
-- which then never reaches a hook). So the game answers the key as it always does, and a post-hook on
-- ToggleGuildFrame puts its window away again in the same breath and opens or closes ours (Toggled). Ours is a window
-- like any of the family's: it flows to any size and Escape closes it.
-- Built for what you open it for: what the guild has to say, talking with it, and who is on.
--
-- The band: the guild's tabard and name, pills (how many are on, how many there are, your rank) and its three pages.
-- Under it, on every page, the message of the day on a page inked to read in every theme, every link in it (a
-- Discord invite, a web address) a chip under it: a click lays the link out selected, ready for Ctrl+C
-- (UI.CopyField); Copy takes the whole message the same way. Those the guild lets change it write in place.
--   Chat: the guild's chat, and the officers' where your rank reads it, with what was said before you opened it
--   (the guild's own streams, C_Club), names in their class's color, a link in a line a click from copied; the
--   typing row under it. Beside it, where the window is wide enough, who is on.
--   Roster: who is on or everyone, a search, and how they are sorted and grouped (rank, class, where they are, level,
--   name, last on). A member's row: the class in a slot with a dot for on, away or busy; the name in the class's
--   color; level, class and rank; where they are (when they were last on); their note; invite. A click whispers, a
--   right-click is the game's menu with the guild's rows added (notes, rank, remove), a hover a card beside the window
--   where there is more to say. Only the rows in sight are made: a roster runs to hundreds.
--   Info: what the guild says of itself, with its links as the message's, and what happened lately (who joined,
--   left, was promoted).
-- The foot: Invite member for those who may, Guild control for its officers, and Communities: the game's own window
-- (your communities, the guild finder, recruitment), shown as it is with the way back to ours on it. Out of a guild
-- the key is the game's alone, and so is whatever else opens its window (a finder's link, an invitation).
--
-- The roster and the chat are read from the guild's club (C_Club), whose answers are withheld in some fights: the
-- window keeps what it showed until they are given again. What the game already has is drawn the moment the window
-- opens; the roster and the log are asked for then and drawn as they arrive.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Skin = Shy.Skin
local Slot = Shy.Slot
local C = UI.colors
local Shop = ns.Shop
local HEAD = UI.HEAD.window

local L = {
	w = 880, h = 600, least = { 400, 480 },
	split = 700, side = 300, gap = 10,     -- who is on stands beside the chat from this width: its width, between the two
	pad = 12, band = 62, icon = 40, foot = 38, button = 12, between = 8, quiet = 10,
	pill = 18, pillGap = 6, segW = 204, segH = 22,
	inset = 12,                            -- a column's margin
	kick = 18, kickGap = 4, section = 16,  -- a section's heading, from it to its page, between two sections
	notice = 8,                            -- over and under the message of the day
	page = 10, text = 13, feather = 22,    -- a page's inset and its words' size
	chip = 22, chipGap = 5,                -- a link under a page
	log = 20, logMost = 40,                -- a line of what happened, and how many are kept
	strip = 22, stripTop = 8, stripGap = 6, find = 90,   -- a pane's controls; the least a search is worth
	head = 26, fold = 20, rail = 17, groupGap = 4,
	row = 44, slot = Slot.SIZES.medium, name = 46, right = 40,   -- a member: where the words begin, the invite's room
	slim = 400, broad = 600,               -- a list narrower than the one says less a row; from the other it stands in columns
	where = 0.38, note = 0.62,             -- where those columns begin, as shares of the list's width
	over = 80,                             -- rows are laid this far past what is in sight
	card = 280,                            -- the room a hover card wants beside the window
	motd = 255, info = 499, say = 255,     -- the letters the game takes
	typing = 24, lines = 400, first = 100, more = 50,   -- the chat: its typing row; lines kept, read at first, read further back
	pace = 1,                              -- seconds between two readings of the roster
}
L.head0 = HEAD.line + UI.LINE
local ICON = Shop.ICON
local DOT = "  \194\183  "

local WORDS = {
	title = "Guild", chat = "Chat", roster = "Roster", board = "Info",
	online = "%d online", members = "%d members", you = "You: %s",
	motd = "Message of the day", info = "About the guild", lately = "Lately", whoOn = "Online",
	noMotd = "Nothing today.", noInfo = "Nothing written yet.",
	copy = "Copy", edit = "Edit", save = "Save", cancel = "Cancel", letters = "%d of %d letters",
	search = "Search the roster", on = "Online", all = "Everyone", sortBy = "Sort by",
	ago = "%s ago", of = "%d of %d on", offline = "Offline", nowhere = "Somewhere", noRank = "No rank", noClass = "Unknown",
	none = "No one matches", noneSay = "Search reads names, classes, ranks, places and notes.",
	invite = "Invite member", control = "Guild control", theirs = "Communities",
	theirsSay = "The game's own window: your communities, the guild finder and recruitment.",
	back = "Back to your guild", held = "Updates after the fight",
	note = "Note", officer = "Officer note", editNote = "Edit note", editOfficer = "Edit officer note",
	rank = "Rank", remove = "Remove from guild", mobile = "On the mobile app",
	guildChat = "Guild", officerChat = "Officers", say = "Say something to the guild", sayOfficers = "Say something to the officers",
	mute = "Your rank can't speak here", locked = "Chat can't be sent right now. Your message is still in the box.",
	gone = "This message was removed.", latest = "Newest", quiet = "Nothing has been said yet.",
}
local TONE = { good = C.good, bad = C.bad, alert = C.alert, hot = C.hot }
local PAGES = { "chat", "roster", "board" }

-- How the roster is sorted, and whether it stands under a head a group.
local SORTS = {
	{ key = "rank", label = "Rank", by = "By rank", group = true },
	{ key = "class", label = "Class", by = "By class", group = true },
	{ key = "zone", label = "Where they are", by = "By place", group = true },
	{ key = "level", label = "Level", by = "By level" },
	{ key = "name", label = "Name", by = "By name" },
	{ key = "last", label = "Last online", by = "Last online" },
}
local SORT = {}
for _, sort in ipairs(SORTS) do SORT[sort.key] = sort end

-- What happened: the game's own sentence for each kind, how many it names, and its mark's color.
local LOG = {
	invite = { "GUILDEVENT_TYPE_INVITE", 2, "hot" }, join = { "GUILDEVENT_TYPE_JOIN", 1, "good" },
	promote = { "GUILDEVENT_TYPE_PROMOTE", 3, "alert" }, demote = { "GUILDEVENT_TYPE_DEMOTE", 3 },
	remove = { "GUILDEVENT_TYPE_REMOVE", 2, "bad" }, quit = { "GUILDEVENT_TYPE_QUIT", 1, "bad" },
}

-- An address written without "http": taken for a link only where it ends in one of these.
local ENDS = {}
for _, tld in ipairs({ "gg", "com", "net", "org", "io", "tv", "me", "eu", "co", "uk", "de", "fr", "es", "ru", "us", "ca",
	"app", "xyz", "info", "link", "dev", "chat", "live", "wiki" }) do ENDS[tld] = true end
local COPY_LINK = "addon:ShySkin:copy:"   -- a link in a line of chat that a click lays out to copy

ns.T.defaults.guild = { sort = "rank", show = "online" }

local M              -- the module
local own = { pills = {}, rows = {}, heads = {}, logs = {}, sections = {} }   -- our frames, made once
local S = { page = "chat", stream = "guild", search = "", folds = {}, open = false, stale = true, held = false, laid = 0 }
local guild = { name = "", rank = "", motd = "", info = "" }
local roster = {}    -- every member, as last read
local sum = { total = 0, online = 0 }
local entries = {}   -- the roster as it is listed: heads and members, each with where it stands
local lately = {}    -- what happened, newest first
local chat = { streams = {} }   -- the guild's streams by kind; .shown the one on show, .oldest its oldest line's id
local Refresh, Stale, Open, Shut, Theirs

local function Frame() return CommunitiesFrame end

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

local function Plain(value)
	if value == nil or issecretvalue(value) then return nil end
	return value
end

-- A table the game answered with, or nil where it withheld it.
local function Given(value)
	if issecretvalue(value) or type(value) ~= "table" then return nil end
	return value
end

local function Opt()
	return ns.T.db.guild
end

-- Links

-- Every link in a text, in the order they stand: { from, to, text }. A scheme's ("https://..."), a "www." one, or a
-- bare address ending in a name the web uses ("discord.gg/abc"); what a sentence puts after one is left off.
local function Links(text)
	local found = {}
	local function Free(from, to)
		for _, link in ipairs(found) do
			if from <= link.to and to >= link.from then return false end
		end
		return true
	end
	local function Take(from, link)
		link = link:gsub("[%.,;:!%?%)%]'\"]+$", "")
		if #link > 3 and Free(from, from + #link - 1) then
			found[#found + 1] = { from = from, to = from + #link - 1, text = link }
		end
	end
	for _, pattern in ipairs({ "()(%a[%w+.-]*://[^%s|<>\"]+)", "()(www%.[%w-]+%.[^%s|<>\"]+)" }) do
		for from, link in text:gmatch(pattern) do Take(from, link) end
	end
	for from, host, tld, rest in text:gmatch("()([%w][%w%-%.]*)%.(%a%a+)([^%s|<>\"]*)") do
		local before = from > 1 and text:sub(from - 1, from - 1) or ""
		if ENDS[tld:lower()] and before ~= "@" and before ~= "/" and (rest == "" or rest:find("^[/%?#:]")) then
			Take(from, host .. "." .. tld .. rest)
		end
	end
	table.sort(found, function(a, b) return a.from < b.from end)
	return found
end

-- A text with each link written by `write(link)`, the rest by `plain(words)`.
local function Woven(text, links, write, plain)
	local out, at = {}, 1
	for _, link in ipairs(links) do
		out[#out + 1] = plain(text:sub(at, link.from - 1))
		out[#out + 1] = write(link.text)
		at = link.to + 1
	end
	out[#out + 1] = plain(text:sub(at))
	return table.concat(out)
end

-- A page's text as it is shown: its links in the color of what can be pressed, its own bars written out.
local function Marked(text, links)
	local hex = "|cff" .. UI.Hex(C.hot)
	return Woven(text, links, function(link) return hex .. link .. "|r" end, function(words) return (words:gsub("|", "||")) end)
end

-- A line of chat as it is shown: each link pressed lays it out to copy.
local function Linked(text)
	local links = Links(text)
	if #links == 0 then return text end
	local hex = "|cff" .. UI.Hex(C.hot)
	return Woven(text, links, function(link) return hex .. "|H" .. COPY_LINK .. link .. "|h" .. link .. "|h|r" end,
		function(words) return words end)
end

-- Reading

-- How long since a member was on: hours (for the order) and the game's words, or nil while they are.
local function Since(info)
	local hour = Plain(info.lastOnlineHour)
	if not hour then return nil end
	local year, month, day = Plain(info.lastOnlineYear) or 0, Plain(info.lastOnlineMonth) or 0, Plain(info.lastOnlineDay) or 0
	return ((year * 12 + month) * 30 + day) * 24 + hour, TimeUtil.GetRecentTimeDate(year, month, day, hour)
end

local function Member(club, id)
	local info = Given(C_Club.GetMemberInfo(club, id))
	local name = info and Plain(info.name)
	if type(name) ~= "string" or name == "" then return nil end
	local classID = Plain(info.classID)
	local class = classID and C_CreatureInfo.GetClassInfo(classID) or nil
	local presence = Plain(info.presence)
	local P = Enum.ClubMemberPresence
	local on = presence ~= nil and presence ~= P.Offline and presence ~= P.Unknown
	local hours, ago = Since(info)
	return {
		id = id, info = info, full = name, name = Ambiguate(name, "none"), guid = Plain(info.guid), me = info.isSelf == true,
		class = class and class.classFile or nil, className = class and class.className or WORDS.noClass,
		level = Plain(info.level) or 0, zone = Plain(info.zone) or "", rank = Plain(info.guildRank) or WORDS.noRank,
		order = Plain(info.guildRankOrder) or 99, note = Plain(info.memberNote) or "", officer = Plain(info.officerNote) or "",
		on = on, presence = presence, mobile = presence == P.OnlineMobile, race = Plain(info.race),
		hours = on and 0 or (hours or 0), ago = (not on) and ago or nil,
	}
end

local function ReadLog()
	wipe(lately)
	for i = GetNumGuildEvents() or 0, 1, -1 do
		local kind, who, whom, rank, year, month, day, hour = GetGuildEventInfo(i)
		local said = LOG[Plain(kind) or ""]
		if said and #lately < L.logMost then
			local names = { Plain(who) or UNKNOWN, Plain(whom) or UNKNOWN, Plain(rank) or "" }
			if said[2] == 1 then names[2], names[3] = nil, nil elseif said[2] == 2 then names[3] = nil end
			lately[#lately + 1] = { text = _G[said[1]]:format(unpack(names)), tone = said[3],
				when = TimeUtil.GetRecentTimeDate(Plain(year), Plain(month), Plain(day), Plain(hour)) }
		end
	end
end

-- The guild's two streams of chat, as far as your rank is given them.
local function ReadStreams()
	wipe(chat.streams)
	local list = Given(C_Club.GetStreams(guild.club))
	local kinds = Enum.ClubStreamType
	for _, stream in ipairs(list or {}) do
		if stream.streamType == kinds.Guild then
			chat.streams.guild = Plain(stream.streamId)
		elseif stream.streamType == kinds.Officer then
			chat.streams.officer = Plain(stream.streamId)
		end
	end
end

-- The guild as the game has it now. Its members are withheld in some fights (and so are their names, one by one):
-- what was read before stands until they are given again.
local function Read()
	S.readAt = GetTime()
	local name, rank = GetGuildInfo("player")
	guild.name, guild.rank = Plain(name) or guild.name, Plain(rank) or guild.rank
	-- (The message of the day is empty until the server has answered: what the game last told of it stands till then.)
	local motd = Plain(C_GuildInfo.GetMOTD())
	if motd and (motd ~= "" or not guild.told) then guild.motd = motd end
	guild.info = Plain(C_GuildInfo.GetInfoText()) or guild.info
	guild.club = Plain(C_Club.GetGuildClubId())
	ReadLog()
	S.held = C_ChatInfo.InChatMessagingLockdown() == true
	if S.held or not guild.club then return end
	local ids = Given(C_Club.GetClubMembers(guild.club))
	if not ids then
		S.held = true
		return
	end
	local list, on = {}, 0
	for _, id in ipairs(ids) do
		local m = Member(guild.club, id)
		if m then
			list[#list + 1] = m
			if m.on then on = on + 1 end
		end
	end
	if #ids > 0 and #list == 0 then
		S.held = true
		return
	end
	roster, sum.total, sum.online = list, #list, on
	ReadStreams()
end

-- The roster as it is listed

local BY = {
	rank = function(a, b) if a.order ~= b.order then return a.order < b.order end end,
	class = function(a, b) if a.className ~= b.className then return a.className < b.className end end,
	zone = function(a, b)
		if a.on ~= b.on then return a.on end
		if a.on and a.zone ~= b.zone then return a.zone < b.zone end
	end,
	level = function(a, b) if a.level ~= b.level then return a.level > b.level end end,
	name = function() end,
	last = function(a, b) if a.hours ~= b.hours then return a.hours < b.hours end end,
}

local function Before(a, b)
	local first = BY[Opt().sort](a, b)
	if first ~= nil then return first end
	if a.on ~= b.on then return a.on end
	return a.name < b.name
end

-- The group a member stands in: what tells it from the next, and its name.
local function GroupOf(m, sort)
	if sort == "rank" then return m.order, m.rank end
	if sort == "class" then return m.className, m.className end
	if not m.on then return "\255", WORDS.offline end
	return m.zone, m.zone ~= "" and m.zone or WORDS.nowhere
end

local function Reads(field, want)
	return field ~= "" and field:lower():find(want, 1, true) ~= nil
end

local function Listed(m, want, everyone)
	if not (everyone or m.on) then return false end
	if want == "" then return true end
	return Reads(m.name, want) or Reads(m.className, want) or Reads(m.rank, want) or Reads(m.zone, want) or Reads(m.note, want)
		or Reads(m.officer, want)
end

-- side: the list beside the chat, which is who is on and no more.
local function List(side)
	local opt = Opt()
	local sort = SORT[opt.sort] or SORTS[1]
	opt.sort = sort.key
	local want, everyone = side and "" or S.search:lower(), not side and opt.show == "all"
	local list = {}
	for _, m in ipairs(roster) do
		if Listed(m, want, everyone) then list[#list + 1] = m end
	end
	table.sort(list, Before)
	wipe(entries)
	local y, head = 0, nil
	for _, m in ipairs(list) do
		if sort.group and not side then
			local key, name = GroupOf(m, sort.key)
			if not head or head.key ~= key then
				if head then y = y + L.groupGap end
				head = { head = true, key = key, fold = sort.key .. "\n" .. tostring(key), name = name, n = 0, on = 0, y = y, h = L.head }
				head.open = not S.folds[head.fold]
				entries[#entries + 1] = head
				y = y + L.head
			end
			head.n = head.n + 1
			if m.on then head.on = head.on + 1 end
		end
		if not head or head.open then
			entries[#entries + 1] = { m = m, y = y, h = L.row }
			y = y + L.row
		end
	end
	entries.tall, entries.count, entries.everyone = y, #list, everyone
	S.laid = S.laid + 1
end

-- What you do with a member

local function Whisper(m)
	ChatFrameUtil.SendTell(m.full)
end

-- The game's own menu for a guild member, as its roster opens it; the guild's rows are added to it (Extend).
local function MemberMenu(m)
	local club = guild.club and C_Club.GetClubInfo(guild.club)
	if not club then return end
	UnitPopup_OpenMenu("COMMUNITIES_GUILD_MEMBER", {
		name = m.full, clubMemberInfo = m.info, clubInfo = club, clubPrivileges = C_Club.GetClubPrivileges(guild.club),
		clubAssignableRoles = C_Club.GetAssignableRoles(guild.club, m.id), isSelf = m.me, guid = m.guid,
		isMobile = m.mobile, isGuildMember = true,
	})
end

-- The guild's rows in that menu while ours stands: notes, the rank, removing, each as the guild lets you, through
-- the game's own dialogs and calls.
local function Extend(_, root, context)
	if not (M and M.on and S.open) then return end
	local info = type(context) == "table" and context.clubMemberInfo
	if type(info) ~= "table" or not context.isGuildMember then return end
	local guid, name = Plain(info.guid), Plain(info.name)
	if not (guid and name) then return end
	local rows = {}
	local function Note(label, public, now)
		rows[#rows + 1] = function()
			root:CreateButton(label, function()
				StaticPopup_Show("SET_GUILD_COMMUNITIY_NOTE", nil, nil, { guid = guid, currentNote = Plain(now) or "", isPublic = public })
			end)
		end
	end
	if info.isSelf == true or CanEditPublicNote() then Note(WORDS.editNote, true, info.memberNote) end
	if C_GuildInfo.CanEditOfficerNote() then Note(WORDS.editOfficer, false, info.officerNote) end
	local mine = guild.club and Given(C_Club.GetMemberInfoForSelf(guild.club))
	local my, order = mine and Plain(mine.guildRankOrder), Plain(info.guildRankOrder)
	if my and order then
		local up, down = CanGuildPromote(), CanGuildDemote()
		local lowest = GuildControlGetNumRanks()
		if (up and order > my + 1) or (down and order < lowest and order > my) then
			rows[#rows + 1] = function()
				local ranks = root:CreateButton(WORDS.rank)
				for at = up and (my + 1) or order, down and lowest or order do
					local radio = ranks:CreateRadio(GuildControlGetRankName(at), function() return at == order end, function()
						if at ~= order then C_GuildInfo.SetGuildRankOrder(guid, at) end
					end)
					if not C_GuildInfo.IsGuildRankAssignmentAllowed(guid, at) then radio:SetEnabled(false) end
				end
			end
		end
		if CanGuildRemove() and order > my then
			rows[#rows + 1] = function()
				root:CreateButton(WORDS.remove, function()
					StaticPopup_Show("REMOVE_GUILDMEMBER", nil, nil, { name = name, guid = guid })
				end)
			end
		end
	end
	if #rows == 0 then return end
	root:CreateDivider()
	for _, write in ipairs(rows) do write() end
end

-- A member's card, beside the window: what the row has no room for. One with nothing more to say has none.
local function Card(row)
	local m = row.m
	if not m then return end
	local rows = {}
	-- (A slim row says neither where they are nor their note.)
	if m.note ~= "" and (row.slim or row.note:IsTruncated()) then
		rows[#rows + 1] = { text = WORDS.note, color = C.dim, right = m.note, rightColor = C.text }
	end
	if m.officer ~= "" and C_GuildInfo.CanViewOfficerNote() then
		rows[#rows + 1] = { text = WORDS.officer, color = C.dim, right = m.officer, rightColor = C.text }
	end
	for _, n in ipairs({ 1, 2 }) do
		local craft, skill = Plain(m.info["profession" .. n .. "Name"]), Plain(m.info["profession" .. n .. "Rank"])
		if type(craft) == "string" and craft ~= "" then
			rows[#rows + 1] = { text = craft, color = C.dim, right = skill and tostring(skill) or "", rightColor = C.text }
		end
	end
	if m.mobile then rows[#rows + 1] = { text = WORDS.mobile, color = C.dim } end
	if #rows == 0 then return end
	local color = m.class and RAID_CLASS_COLORS[m.class]
	local race = m.race and C_CreatureInfo.GetRaceInfo(m.race)
	local key = COMMUNITY_MEMBER_CHARACTER_INFO_FORMAT:format(m.level, race and race.raceName or "", m.className)
	Shy.Hover.Show(row, { card = true, about = "guild:" .. m.full, title = m.name, titleColor = color and { color.r, color.g, color.b } or nil,
		kind = m.rank, key = { { text = key, color = C.dim } }, body = { { rows = rows } } },
		{ at = UI.Beside(own.box, row, { room = L.card }) })
end

-- The chat

-- When a line was said: the hour today, the day with it this week, the date before that.
local function Stamp(epoch)
	local at, now = epoch / 1000000, time()
	if now - at > 6 * 86400 then return date("%b %d %H:%M", at) end
	if date("%j", at) ~= date("%j", now) then return date("%a %H:%M", at) end
	return date("%H:%M", at)
end

-- A message as a line: when, who in their class's color (a name to click, as in the chat window), what they said.
local function Line(message)
	local author = Given(message.author)
	local name = author and Plain(author.name)
	local shown = name and Ambiguate(name, "none") or UNKNOWN
	local classID = author and Plain(author.classID)
	local class = classID and C_CreatureInfo.GetClassInfo(classID)
	local color = class and RAID_CLASS_COLORS[class.classFile]
	if color then
		shown = ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), shown)
	end
	if name then shown = "|Hplayer:" .. name .. "|h" .. shown .. "|h" end
	local content = message.content
	if not issecretvalue(content) then
		if Plain(message.destroyed) == true then
			content = UI.Wrap(C.dim, WORDS.gone)
		elseif type(content) == "string" then
			content = Linked(content)
		else
			content = ""
		end
	end
	local id = Given(message.messageId)
	local epoch = id and Plain(id.epoch)
	return ("%s %s: %s"):format(UI.Wrap(C.dim, epoch and Stamp(epoch) or ""), shown, content)
end

local function ChatInk()
	local info = ChatTypeInfo[S.stream == "officer" and "OFFICER" or "GUILD"]
	if info then return info.r, info.g, info.b end
	return C.text[1], C.text[2], C.text[3]
end

-- The stream on show from its newest lines back; none read yet are asked for (CLUB_MESSAGE_HISTORY_RECEIVED).
local function ShowChat()
	local msg = own.msg
	if S.stream == "officer" and not chat.streams.officer then S.stream = "guild" end
	local stream = chat.streams[S.stream]
	if chat.focus and chat.focus ~= stream and guild.club then C_Club.UnfocusStream(guild.club, chat.focus) end
	chat.shown, chat.oldest, chat.asked, chat.focus = nil, nil, nil, nil
	msg:Clear()
	own.latest:Hide()
	if S.held or not (guild.club and stream) then return end
	chat.shown, chat.focus = stream, stream
	C_Club.FocusStream(guild.club, stream)
	local ranges = Given(C_Club.GetMessageRanges(guild.club, stream))
	local range = ranges and Given(ranges[#ranges])
	local messages = range and Given(C_Club.GetMessagesBefore(guild.club, stream, range.newestMessageId, L.first))
	if not messages or #messages == 0 then
		chat.asked = true
		C_Club.RequestMoreMessagesBefore(guild.club, stream, nil)
		return
	end
	local r, g, b = ChatInk()
	for _, message in ipairs(messages) do msg:AddMessage(Line(message), r, g, b) end
	chat.oldest = messages[1].messageId
end

local function SameId(a, b)
	a, b = Given(a), Given(b)
	return a ~= nil and b ~= nil and Plain(a.epoch) == Plain(b.epoch) and Plain(a.position) == Plain(b.position)
end

-- What was said before the oldest line on show, laid over it.
local function Backfill()
	if not (chat.shown and chat.oldest) then return end
	local messages = Given(C_Club.GetMessagesBefore(guild.club, chat.shown, chat.oldest, L.more))
	if not messages or #messages == 0 then return end
	local last = #messages - (SameId(messages[#messages].messageId, chat.oldest) and 1 or 0)
	local r, g, b = ChatInk()
	for i = last, 1, -1 do own.msg:BackFillMessage(Line(messages[i]), r, g, b) end
	chat.oldest = messages[1].messageId
end

-- Scrolled to its top: what came before is asked for, once at a time.
local function Older()
	if not (chat.shown and chat.oldest) or chat.asked or S.held then return end
	if C_Club.IsBeginningOfStream(guild.club, chat.shown, chat.oldest) == true then return end
	if C_Club.RequestMoreMessagesBefore(guild.club, chat.shown, chat.oldest, L.more) then
		Backfill()
	else
		chat.asked = true
	end
end

-- The club's news of the chat: a line said, or lines from before that were asked for.
local function Heard(event, club, stream, id)
	if S.held or Plain(club) ~= guild.club or Plain(stream) == nil or Plain(stream) ~= chat.shown then return end
	if event == "CLUB_MESSAGE_ADDED" then
		local message = Given(C_Club.GetMessageInfo(club, stream, id))
		if not message then return end
		local r, g, b = ChatInk()
		own.msg:AddMessage(Line(message), r, g, b)
		chat.oldest = chat.oldest or message.messageId
	else
		chat.asked = nil
		if own.msg:GetNumMessages() > 0 and chat.oldest then Backfill() else ShowChat() end
	end
end

local function Send(edit)
	local text = edit:GetText() or ""
	if not text:find("%S") then
		edit:SetText("")
		edit:ClearFocus()
		return
	end
	if C_ChatInfo.InChatMessagingLockdown() then
		own.status:SetText(UI.Wrap(C.alert, WORDS.locked))
		return
	end
	text = ChatFrameUtil.SubstituteChatMessageBeforeSend(text)
	C_ChatInfo.SendChatMessage(text, S.stream == "officer" and "OFFICER" or "GUILD")
	edit:AddHistoryLine(text)
	edit:SetText("")
end

-- Building: pieces

local function Groove(frame, top)
	local groove = frame:CreateTexture(nil, "BORDER")
	groove:SetColorTexture(0, 0, 0, 0.85)
	groove:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT")
	groove:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT")
	groove:SetHeight(1)
	local lip = frame:CreateTexture(nil, "BORDER")
	lip:SetColorTexture(1, 1, 1, 0.07)
	lip:SetPoint(top and "TOPLEFT" or "BOTTOMLEFT", 0, top and -1 or 1)
	lip:SetPoint(top and "TOPRIGHT" or "BOTTOMRIGHT", 0, top and -1 or 1)
	lip:SetHeight(1)
end

local function Pill(i)
	local pill = own.pills[i]
	if pill then return pill end
	pill = CreateFrame("Frame", nil, own.band)
	pill:SetHeight(L.pill)
	pill.fill = pill:CreateTexture(nil, "BACKGROUND")
	pill.fill:SetAllPoints()
	pill.edge = pill:CreateTexture(nil, "BORDER")
	pill.edge:SetPoint("TOPLEFT")
	pill.edge:SetPoint("BOTTOMLEFT")
	pill.edge:SetWidth(2)
	pill.text = Text(pill, UI.TextFont(11), C.text)
	pill.text:SetPoint("LEFT", 8, 0)
	own.pills[i] = pill
	return pill
end

-- A word to press that is no button: quiet, lit under the mouse (Copy, Edit beside a section's name).
local function Quiet(parent, word, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(14)
	b.text = Text(b, UI.NameFont(10), C.dim)
	b.text:SetPoint("CENTER")
	b.text:SetText(word)
	b:SetWidth(math.ceil(b.text:GetStringWidth()) + 8)
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(self)
	end)
	b:SetScript("OnEnter", function(self) UI.Ink(self.text, C.hot) end)
	b:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
	return b
end

local function FootButton(word, onClick)
	local b = UI.Button(own.foot, word, 96, onClick)
	b:SetFrameLevel(own.foot:GetFrameLevel() + 2)
	b:Hide()
	return b
end

-- Building: what the guild says (the message of the day, its information)

local function Editing()
	return S.edit and own.sections[S.edit] or nil
end

local function StopEdit()
	local s = Editing()
	S.edit = nil
	if s then s.box:ClearFocus() end
	Refresh()
end

local function Save()
	local s = Editing()
	if not s then return end
	local text = strtrim(s.box:GetText() or "")
	if s.key == "motd" then
		C_GuildInfo.SetMOTD(text)
		guild.motd = text
	else
		C_GuildInfo.SetInfoText(text)
		guild.info = text
	end
	StopEdit()
end

local function Edit(key)
	local s = own.sections[key]
	UI.CopyFieldClose()
	S.edit = key
	s.box:SetText(guild[key] or "")
	Refresh()
	s.box:SetFocus()
end

-- A link under a page: its chip, which a click turns into the link selected.
local function Chip(s, i)
	local chip = s.chips[i]
	if chip then return chip end
	chip = CreateFrame("Button", nil, s.sheet)
	chip:SetHeight(L.chip)
	chip.glyph = chip:CreateTexture(nil, "OVERLAY")
	UI.GlyphArt(chip.glyph, "link")
	chip.glyph:SetPoint("LEFT", 5, 0)
	chip.text = Text(chip, UI.NameFont(11), C.text)
	chip.text:SetPoint("LEFT", 24, 0)
	UI.KeyPress(chip, { words = chip.text, glyphs = { chip.glyph }, sink = { chip.glyph, chip.text } })
	chip:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UI.CopyField(self, self.link)
	end)
	s.chips[i] = chip
	return chip
end

-- A section on a sheet: its name with Copy and Edit at its right, its words on a page, a box to change them in.
local function Section(sheet, key, word, letters)
	local s = { sheet = sheet, key = key, word = word, letters = letters, chips = {}, raw = "" }
	s.kick = Shop.Kicker(sheet)
	s.copy = Quiet(sheet, WORDS.copy, function() UI.CopyField(s.page, s.raw) end)
	s.edit = Quiet(sheet, WORDS.edit, function() Edit(key) end)
	s.edit:SetPoint("TOPRIGHT", s.kick, "TOPRIGHT", 0, 2)
	s.page = UI.PaperPage(sheet, { feather = L.feather })
	s.page:SetFrameLevel(sheet:GetFrameLevel() + 1)
	s.words = s.page:CreateFontString(nil, "ARTWORK")
	s.words:SetFontObject(UI.TextFont(L.text))
	s.words:SetJustifyH("LEFT")
	s.words:SetJustifyV("TOP")
	s.words:SetWordWrap(true)
	s.words:SetSpacing(2)
	s.words:SetPoint("TOPLEFT", L.page, -L.page)
	local box = CreateFrame("EditBox", nil, s.page)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetMaxLetters(letters)
	box:SetFontObject(UI.TextFont(L.text))
	box:SetSpacing(2)
	box:SetPoint("TOPLEFT", L.page, -L.page)
	box:SetPoint("RIGHT", s.page, "RIGHT", -L.page, 0)
	box:Hide()
	box:SetScript("OnEscapePressed", StopEdit)
	-- (The message of the day is a line: Enter sets it. The guild's information takes lines of its own.)
	if key == "motd" then box:SetScript("OnEnterPressed", Save) end
	box:SetScript("OnTextChanged", function(_, typed) if typed then Stale() end end)
	s.box = box
	s.page:EnableMouse(true)
	s.page:SetScript("OnMouseDown", function() if S.edit == key then box:SetFocus() end end)
	own.sections[key] = s
	return s
end

local function LogRow(i)
	local row = own.logs[i]
	if row then return row end
	row = CreateFrame("Frame", nil, own.board.content)
	row:SetHeight(L.log)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetSize(2, L.log - 8)
	row.mark:SetPoint("LEFT", 0, 0)
	row.when = Text(row, UI.TextFont(10), C.dim)
	row.when:SetPoint("RIGHT", 0, 0)
	row.when:SetJustifyH("RIGHT")
	row.text = Text(row, UI.TextFont(11), C.text)
	row.text:SetPoint("LEFT", 9, 0)
	row.text:SetPoint("RIGHT", row.when, "LEFT", -8, 0)
	own.logs[i] = row
	return row
end

-- Building: the roster

local function Row(i)
	local row = own.rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, own.list.content)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- Its shade under the mouse and its line of your color, behind the words.
	row.hot = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.95)
	row.hot:Hide()
	row.line = row:CreateTexture(nil, "ARTWORK")
	row.line:SetSize(2, L.row - 10)
	row.line:SetPoint("LEFT", 0, 0)
	row.line:SetColorTexture(1, 1, 1, 1)
	row.line:Hide()
	row.rule = row:CreateTexture(nil, "BORDER")
	row.rule:SetPoint("BOTTOMLEFT", L.name, 0)
	row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
	row.rule:SetHeight(1)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(L.slot, L.slot)
	row.icon:SetPoint("LEFT", 8, 0)
	row.icon:SetTexCoord(unpack(ICON))
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, size = L.slot, hover = false })
	local pip = CreateFrame("Frame", nil, row)
	pip:SetSize(10, 10)
	pip:SetPoint("CENTER", row.icon, "BOTTOMRIGHT", -1, 1)
	pip:SetFrameLevel(row:GetFrameLevel() + 6)
	pip.ring = pip:CreateTexture(nil, "ARTWORK")
	pip.ring:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(pip.ring, 10)
	pip.ring:SetPoint("CENTER")
	pip.dot = pip:CreateTexture(nil, "OVERLAY")
	pip.dot:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(pip.dot, 6)
	pip.dot:SetPoint("CENTER")
	row.pip = pip
	row.invite = UI.GlyphButton(row, Skin.GLYPH.invite, 22, function(self)
		local m = self:GetParent().m
		if m then C_PartyInfo.InviteUnit(m.full) end
	end, { width = 26, glyph = 13, tip = { TRAVEL_PASS_INVITE } })
	row.invite:SetPoint("RIGHT", -6, 0)
	row.where = Text(row, UI.TextFont(11), C.text)
	row.note = Text(row, UI.TextFont(11), C.dim)
	row.name = Text(row, UI.NameFont(13), C.text)
	row.sub = Text(row, UI.TextFont(11), C.dim)
	row:SetScript("OnClick", function(self, button)
		local m = self.m
		if not m then return end
		if button == "RightButton" or m.me or not m.on then MemberMenu(m) else Whisper(m) end
	end)
	row:SetScript("OnEnter", function(self)
		self.hot:Show()
		UI.Paint(self.line, Theme.Accent)
		self.line:Show()
		S.over = self
		Card(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.hot:Hide()
		self.line:SetShown(self.m ~= nil and self.m.me)
		if S.over == self then S.over = nil end
		Shy.Hover.Hide(self)
	end)
	own.rows[i] = row
	return row
end

local PRESENCE   -- a presence's dot: its color's key (made once the game's enum is read)
local function DrawRow(row, e)
	local m = e.m
	local slim = (own.listW or 300) < L.slim
	row.m, row.slim = m, slim
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", own.list.content, "TOPLEFT", 0, -e.y)
	row:SetPoint("RIGHT", own.list.content, "RIGHT", 0, 0)
	local sort = Opt().sort
	local color = m.class and RAID_CLASS_COLORS[m.class]
	row.slot:Empty(m.class == nil)
	row.icon:SetShown(m.class ~= nil)
	if m.class then row.icon:SetTexture("Interface\\Icons\\ClassIcon_" .. m.class) end
	row.icon:SetDesaturated(not m.on)
	row.icon:SetAlpha(m.on and 1 or 0.5)
	local P = Enum.ClubMemberPresence
	PRESENCE = PRESENCE or { [P.Online] = "good", [P.Away] = "alert", [P.Busy] = "bad", [P.OnlineMobile] = "dim" }
	local dot = m.on and PRESENCE[m.presence] or nil
	row.pip:SetShown(dot ~= nil)
	if dot then
		UI.Tint(row.pip.ring, C.panel)
		UI.Tint(row.pip.dot, C[dot])
	end
	row.name:SetText(m.name)
	if not m.on then UI.Ink(row.name, C.dim)
	elseif color then row.name:SetTextColor(color.r, color.g, color.b)
	else UI.Ink(row.name, C.text) end
	row.invite:SetShown(m.on and not m.me and not m.mobile)
	-- Where they are, or when they were last on.
	local place = m.on and (sort ~= "zone" and m.zone or "") or (m.ago and WORDS.ago:format(m.ago) or WORDS.offline)
	-- Under the name: level and class, and the rank where the heads don't say it.
	local sub = strtrim((m.level > 0 and (m.level .. " ") or "") .. (sort ~= "class" and m.className or ""))
	if sort ~= "rank" and not slim then sub = sub .. (sub ~= "" and DOT or "") .. m.rank end
	row.where:SetShown(not slim)
	row.note:SetShown(not slim)
	for _, text in ipairs({ row.name, row.sub, row.where, row.note }) do text:ClearAllPoints() end
	row.name:SetPoint("TOPLEFT", L.name, -7)
	row.sub:SetPoint("TOPLEFT", L.name, -25)
	local wide = own.listW or 300
	if slim then
		-- A slim row: the place after the level and class; the note is the card's.
		if place ~= "" then sub = sub .. (sub ~= "" and DOT or "") .. (m.on and UI.Wrap(C.text, place) or place) end
		row.name:SetPoint("RIGHT", row, "RIGHT", -L.right, 0)
		row.sub:SetPoint("RIGHT", row, "RIGHT", -L.right, 0)
	elseif wide >= L.broad then
		-- A broad row: where they are and their note each in a column of its own, down the list.
		local at, to = math.floor(wide * L.where), math.floor(wide * L.note)
		row.where:SetJustifyH("LEFT")
		row.where:SetPoint("LEFT", row, "LEFT", at, 0)
		row.where:SetWidth(to - at - 12)
		row.where:SetText(place)
		row.note:SetJustifyH("LEFT")
		row.note:SetPoint("LEFT", row, "LEFT", to, 0)
		row.note:SetWidth(wide - to - L.right - 8)
		row.note:SetText(m.note)
		row.name:SetPoint("RIGHT", row, "LEFT", at - 12, 0)
		row.sub:SetPoint("RIGHT", row, "LEFT", at - 12, 0)
	else
		-- At the right: where they are, their note under it. Each gives way to the name.
		local room = math.floor(wide * 0.44)
		row.where:SetJustifyH("RIGHT")
		row.where:SetWidth(0)
		row.where:SetText(place)
		row.where:SetWidth(math.min(room, math.ceil(row.where:GetStringWidth()) + 1))
		row.where:SetPoint("TOPRIGHT", -L.right, -8)
		row.note:SetJustifyH("RIGHT")
		row.note:SetWidth(0)
		row.note:SetText(m.note)
		row.note:SetWidth(math.min(room, math.ceil(row.note:GetStringWidth()) + 1))
		row.note:SetPoint("TOPRIGHT", -L.right, -25)
		row.name:SetPoint("RIGHT", row.where, "LEFT", -8, 0)
		row.sub:SetPoint("RIGHT", row.note, "LEFT", -8, 0)
	end
	UI.Ink(row.where, m.on and C.text or C.dim)
	row.sub:SetText(sub)
	row.line:SetShown(m.me or row.hot:IsShown())
	UI.Paint(row.line, Theme.Accent)
	UI.Paint(row.rule, C.rowEdge, 0.5)
	row:Show()
end

local function Head(i)
	local h = own.heads[i]
	if h then return h end
	h = UI.GroupHead(own.list.content, { height = L.head, rail = L.rail, gutter = 34, right = 6, foldSize = L.fold, line = true,
		click = function(self, button)
			if button ~= "LeftButton" or not self.key then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			S.folds[self.key] = self.open or nil
			Refresh()
		end })
	own.heads[i] = h
	return h
end

local function DrawHead(h, e)
	h.key = e.fold
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", own.list.content, "TOPLEFT", 0, -e.y)
	h:SetPoint("RIGHT", own.list.content, "RIGHT", 0, 0)
	h:Set(e.name)
	h:SetOpen(e.open)
	-- How many are in it; with everyone listed, how many of them are on.
	local says = tostring(e.n)
	if entries.everyone and e.key ~= "\255" then says = WORDS.of:format(e.on, e.n) end
	h:SetBadges({ { text = says, color = C.dim } })
	h:Show()
end

-- The rows in sight, and a little past it: a row a member, made as the list is scrolled to them.
local function LayList()
	local area = own.list
	local at, view = area:At(), area:GetHeight()
	if issecretvalue(view) or not view or view <= 0 then view = L.h end
	local first, last = 1, #entries
	while first < last do
		local mid = math.floor((first + last) / 2)
		if entries[mid].y + entries[mid].h <= at - L.over then first = mid + 1 else last = mid end
	end
	local rows, heads = 0, 0
	for i = first, #entries do
		local e = entries[i]
		if e.y > at + view + L.over then break end
		if e.head then
			heads = heads + 1
			DrawHead(Head(heads), e)
		else
			rows = rows + 1
			DrawRow(Row(rows), e)
		end
	end
	for i = rows + 1, #own.rows do
		own.rows[i].m = nil
		own.rows[i]:Hide()
	end
	for i = heads + 1, #own.heads do own.heads[i]:Hide() end
	own.laid = S.laid
	-- The row under the mouse holds another member now: its card follows.
	if S.over and S.over:IsShown() and S.over.m then Card(S.over) end
end

local function BuildRoster(box)
	local pane = CreateFrame("Frame", nil, box)
	pane:SetFrameLevel(box:GetFrameLevel() + 3)
	own.roster = pane
	-- Its controls, on the roster's own page: who is listed, a search, the order.
	local strip = CreateFrame("Frame", nil, pane)
	strip:SetHeight(L.strip)
	strip:SetPoint("TOPLEFT", L.inset - 4, -L.stripTop)
	strip:SetPoint("TOPRIGHT", -(L.inset - 4), -L.stripTop)
	own.strip = strip
	own.filter = UI.Segments(strip, { WORDS.on, WORDS.all }, function(i)
		Opt().show = i == 2 and "all" or "online"
		own.list:SetVerticalScroll(0)
		Refresh()
	end, { height = L.strip })
	own.filter:SetPoint("LEFT")
	own.sort = UI.MenuButton(strip, { height = L.strip, plate = true, menu = { align = "RIGHT" }, write = function(root)
		root:CreateSection(WORDS.sortBy)
		for _, sort in ipairs(SORTS) do
			root:CreateRadio(sort.label, function() return Opt().sort == sort.key end, function()
				Opt().sort = sort.key
				own.list:SetVerticalScroll(0)
				Refresh()
			end)
		end
	end })
	own.sort:SetPoint("RIGHT")
	own.search = Shop.Search(strip, WORDS.search, function(text)
		if text == S.search then return end
		S.search = text
		own.list:SetVerticalScroll(0)
		Refresh()
	end)
	own.search:SetHeight(L.strip - 2)
	-- Beside the chat: its name and how many, no more.
	own.sideKick = Shop.Kicker(pane)
	own.sideKick:SetPoint("TOPLEFT", L.inset - 4, -(L.stripTop + 3))
	own.sideKick:SetPoint("TOPRIGHT", -(L.inset - 4), -(L.stripTop + 3))
	local list = UI.ScrollArea(pane, L.w, L.h, { smooth = true, shades = C.panel, onScroll = function()
		if own.laid then own.Lay() end
	end })
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", 0, -(L.stripTop + L.strip + 8))
	list:SetPoint("BOTTOMRIGHT", 0, 0)
	own.list = list
	own.Lay = LayList
	own.none = CreateFrame("Frame", nil, pane)
	own.none:SetPoint("TOPLEFT", list, "TOPLEFT", 20, -50)
	own.none:SetPoint("TOPRIGHT", list, "TOPRIGHT", -20, -50)
	own.none:SetHeight(60)
	own.none.title = Text(own.none, UI.TitleFont(15), C.head)
	own.none.title:SetPoint("TOP")
	own.none.title:SetJustifyH("CENTER")
	own.none.title:SetText(WORDS.none)
	own.none.words = Text(own.none, UI.TextFont(12), C.dim)
	own.none.words:SetPoint("TOPLEFT", 0, -24)
	own.none.words:SetPoint("TOPRIGHT", 0, -24)
	own.none.words:SetJustifyH("CENTER")
	own.none.words:SetWordWrap(true)
	own.none.words:SetMaxLines(3)
	own.none.words:SetText(WORDS.noneSay)
end

-- Building: the chat

-- The words are the chat's: its face at its size, and ShyChat's spacing where it is on.
local function ChatFace()
	local window = SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
	local file, size, flags
	if window then file, size, flags = window:GetFont() end
	if type(file) == "string" and type(size) == "number" and size > 0 then
		own.msg:SetFont(file, size, flags or "")
		own.say:SetFont(file, size, flags or "")
	end
	local theirs = Shy.addons.Chat
	if theirs and theirs.Dress then theirs:Dress(own.msg) end
end

local function BuildChat(box)
	local pane = CreateFrame("Frame", nil, box)
	pane:SetFrameLevel(box:GetFrameLevel() + 3)
	own.chat = pane
	own.streams = UI.Segments(pane, { WORDS.guildChat, WORDS.officerChat }, function(i)
		S.stream = i == 2 and "officer" or "guild"
		ShowChat()
		Refresh()
	end, { height = L.strip })
	own.streams:SetPoint("TOPLEFT", L.inset, -L.stripTop)

	local say = CreateFrame("EditBox", nil, pane)
	say:SetPoint("BOTTOMLEFT", L.inset, L.inset - 4)
	say:SetPoint("BOTTOMRIGHT", -L.inset, L.inset - 4)
	say:SetHeight(L.typing)
	say:SetAutoFocus(false)
	say:SetFontObject(UI.TextFont(L.text))
	say:SetTextInsets(8, 8, 0, 0)
	say:SetMaxLetters(L.say)
	say:SetAltArrowKeyMode(false)
	say:SetHistoryLines(32)
	UI.Skin(say, C.bg, C.border)
	say.hint = Text(say, UI.TextFont(12), C.dim)
	say.hint:SetPoint("LEFT", 8, 0)
	say:SetScript("OnEnterPressed", Send)
	say:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	say:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) end)
	say:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	say:SetScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "") end)
	own.say = say

	local msg = CreateFrame("ScrollingMessageFrame", nil, pane)
	msg:SetPoint("BOTTOMLEFT", say, "TOPLEFT", 2, 8)
	msg:SetPoint("BOTTOMRIGHT", say, "TOPRIGHT", -2, 8)
	msg:SetFontObject(UI.TextFont(L.text))
	msg:SetJustifyH("LEFT")
	msg:SetFading(false)
	msg:SetMaxLines(L.lines)
	msg:SetHyperlinksEnabled(true)
	msg:EnableMouseWheel(true)
	msg:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			if self:AtTop() then Older() else self:ScrollUp() end
		else
			self:ScrollDown()
		end
		own.latest:SetShown(not self:AtBottom())
	end)
	-- A link of ours in a line is laid out to copy where the mouse is; the rest are the game's (a name whispers).
	msg:SetScript("OnHyperlinkClick", function(self, link, text, button)
		local url = link:sub(1, #COPY_LINK) == COPY_LINK and link:sub(#COPY_LINK + 1) or nil
		if url then
			UI.CopyField(self, url, { cursor = true })
		else
			SetItemRef(link, text, button, self)
		end
	end)
	own.msg = msg
	-- A click on the lines puts the cursor in the typing row.
	pane:EnableMouse(true)
	pane:SetScript("OnMouseDown", function() if own.say:IsShown() and not own.say.off then own.say:SetFocus() end end)
	own.empty = Text(pane, UI.TextFont(12), C.dim)
	own.empty:SetPoint("BOTTOMLEFT", msg, "BOTTOMLEFT", 6, 4)
	own.empty:SetText(WORDS.quiet)
	own.latest = Quiet(pane, WORDS.latest, function(self)
		own.msg:ScrollToBottom()
		self:Hide()
	end)
	own.latest:SetFrameLevel(pane:GetFrameLevel() + 4)
	own.latest:SetPoint("BOTTOMRIGHT", msg, "BOTTOMRIGHT", -2, 2)
	own.latest:Hide()
	ChatFace()
end

-- Building: the window

local function Build()
	-- A window of its own (Escape closes it by its name): the game's guild window is never its parent, nor touched.
	local box = UI.Window({
		id = "shyskin.guild", name = "ShySkinGuildWindow", title = WORDS.title, width = L.w, height = L.h,
		point = { "TOPLEFT", "TOPLEFT", 16, -116 },
		shown = function() return M ~= nil and M.on == true and S.open == true end,
		inCombat = true,
		head = { size = "window", title = WORDS.title, close = function() Shut() end },
		grip = { flow = function() if Stale then Stale() end end, min = { L.least[1], L.least[2] } },
	})
	own.box = box

	-- The band and the foot stand on the window's body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)

	-- The band: your color's wash from the left, a groove along its foot.
	local band = CreateFrame("Frame", nil, box)
	band:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -L.head0)
	band:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -L.head0)
	band:SetHeight(L.band)
	band:SetFrameLevel(box:GetFrameLevel() + 2)
	own.band = band
	local wash = band:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints()
	wash:SetColorTexture(1, 1, 1, 1)
	function wash:Ink()
		local r, g, b = Theme.Accent()
		self:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.12), CreateColor(r, g, b, 0))
	end
	own.wash = wash
	Groove(band, false)
	-- The tabard: its cloth in the slot, its emblem on it.
	own.icon = band:CreateTexture(nil, "ARTWORK")
	own.icon:SetSize(L.icon, L.icon)
	own.icon:SetPoint("LEFT", L.pad, 0)
	own.icon:SetColorTexture(1, 1, 1, 1)
	own.emblem = band:CreateTexture(nil, "ARTWORK", nil, 2)
	own.emblem:SetSize(L.icon - 6, L.icon - 6)
	own.emblem:SetPoint("CENTER", own.icon, "CENTER", 0, 0)
	own.iconSlot = Slot.New(band, { to = own.icon, icon = own.icon, size = L.icon, hover = false })
	own.left = L.pad + L.icon + 12
	own.switch = UI.Segmented(band, { WORDS.chat, WORDS.roster, WORDS.board }, function()
		for i, page in ipairs(PAGES) do
			if page == S.page then return i end
		end
		return 1
	end, function(i)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		S.page = PAGES[i]
		Shy.Hover.Close()
		Refresh()
	end, { width = L.segW, height = L.segH })
	own.switch:SetPoint("TOPRIGHT", band, "TOPRIGHT", -L.pad, -10)
	own.title = Text(band, UI.TitleFont(15), C.head)
	own.title:SetPoint("TOPLEFT", own.left, -12)
	own.title:SetPoint("RIGHT", own.switch, "LEFT", -10, 0)

	-- The foot: a hover's foot, its floor under a groove and a lip of light.
	local foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 2, 2)
	foot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
	foot:SetHeight(L.foot)
	foot:SetFrameLevel(box:GetFrameLevel() + 6)
	own.foot = foot
	local floor = foot:CreateTexture(nil, "BACKGROUND")
	floor:SetAllPoints()
	floor:SetColorTexture(0, 0, 0, 0.30)
	Groove(foot, true)
	own.status = Text(foot, UI.TextFont(11), C.dim)
	own.status:SetPoint("LEFT", L.button, 0)
	own.b = {
		invite = FootButton(WORDS.invite, function()
			if guild.club then CommunitiesUtil.OpenInviteDialog(guild.club) end
		end),
		control = FootButton(WORDS.control, function() GuildControlUI_Show() end),
		theirs = FootButton(WORDS.theirs, function() Theirs() end),
		save = FootButton(WORDS.save, Save),
		cancel = FootButton(WORDS.cancel, StopEdit),
	}
	own.b.theirs:HookScript("OnEnter", function(self) UI.Tip(self, WORDS.theirs, WORDS.theirsSay, { side = "TOP" }) end)
	own.b.theirs:HookScript("OnLeave", function(self) UI.TipHide(self) end)

	-- The reading ground: the look keeps the frame, the band and the foot; the rest stands on the window's plain color.
	local ground = CreateFrame("Frame", nil, box)
	ground:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
	ground:SetFrameLevel(box:GetFrameLevel() + 1)
	ground.fill = ground:CreateTexture(nil, "BACKGROUND")
	ground.fill:SetAllPoints()
	UI.Paint(ground.fill, C.panel, 1)
	own.ground = ground

	-- The message of the day, on every page: a notice across the window, a hairline under it.
	local notice = CreateFrame("Frame", nil, box)
	notice:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
	notice:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
	notice:SetFrameLevel(box:GetFrameLevel() + 3)
	notice.rule = notice:CreateTexture(nil, "ARTWORK")
	notice.rule:SetPoint("BOTTOMLEFT")
	notice.rule:SetPoint("BOTTOMRIGHT")
	notice.rule:SetHeight(1)
	UI.Paint(notice.rule, C.border, 0.9)
	own.notice = notice
	Section(notice, "motd", WORDS.motd, L.motd)
	own.measure = notice:CreateFontString(nil, "BACKGROUND")
	own.measure:SetFontObject(UI.TextFont(L.text))
	own.measure:SetJustifyH("LEFT")
	own.measure:SetWordWrap(true)
	own.measure:SetSpacing(2)
	own.measure:SetAlpha(0)

	-- The pages.
	local board = UI.ScrollArea(box, L.w, L.h, { smooth = true, shades = C.panel })
	board:SetFrameLevel(box:GetFrameLevel() + 3)
	own.board = board
	Section(board.content, "info", WORDS.info, L.info)
	own.latelyKick = Shop.Kicker(board.content)
	own.divide = box:CreateTexture(nil, "ARTWORK")
	own.divide:SetWidth(1)
	UI.Paint(own.divide, C.border, 0.9)
	BuildChat(box)
	BuildRoster(box)
end

-- Drawing

local function Pills(list)
	local x, y = own.left, -36
	local room = UI.BodySize(own.box) - 4 - L.pad
	local shown = 0
	for _, fact in ipairs(list) do
		local pill = Pill(shown + 1)
		pill.text:SetText(fact.text)
		local wide = math.ceil(pill.text:GetStringWidth() + 16)
		if x + wide > room then break end
		shown = shown + 1
		local tone = TONE[fact.tone]
		UI.Paint(pill.fill, tone or C.text, tone and 0.16 or 0.07)
		UI.Paint(pill.edge, tone or C.dim, 0.9)
		UI.Ink(pill.text, tone or C.text)
		pill:SetWidth(wide)
		pill:ClearAllPoints()
		pill:SetPoint("TOPLEFT", own.band, "TOPLEFT", x, y)
		pill:Show()
		x = x + wide + L.pillGap
	end
	for i = shown + 1, #own.pills do own.pills[i]:Hide() end
end

local function DrawBand()
	own.wash:Ink()
	own.switch:Refresh()
	own.box.head.title:SetText(WORDS.title)
	own.title:SetText(guild.name)
	-- (The game's own painter: the cloth's color, the emblem's picture, color and width.)
	own.emblem:SetHeight(L.icon - 6)
	SetLargeGuildTabardTextures("player", own.emblem, own.icon, nil)
	local facts = { { text = WORDS.online:format(sum.online), tone = sum.online > 0 and "good" or nil },
		{ text = WORDS.members:format(sum.total) } }
	if guild.rank ~= "" then facts[#facts + 1] = { text = WORDS.you:format(guild.rank) } end
	if S.held then facts[#facts + 1] = { text = WORDS.held, tone = "alert" } end
	Pills(facts)
end

-- A section laid at `y` down its sheet, `column` wide from `x`: returns where the next begins.
local function DrawSection(s, raw, none, can, x, y, column)
	local sheet = s.sheet
	local editing = S.edit == s.key
	s.raw = raw
	s.kick:ClearAllPoints()
	s.kick:SetPoint("TOPLEFT", sheet, "TOPLEFT", x, -y)
	s.kick:SetWidth(column)
	s.kick:Say(s.word, editing and WORDS.letters:format(UI.Letters(s.box:GetText() or ""), s.letters) or nil)
	s.edit:SetShown(can and not editing)
	s.copy:SetShown(raw ~= "" and not editing)
	s.copy:ClearAllPoints()
	if s.edit:IsShown() then
		s.copy:SetPoint("RIGHT", s.edit, "LEFT", -4, 0)
	else
		s.copy:SetPoint("TOPRIGHT", s.kick, "TOPRIGHT", 0, 2)
	end
	y = y + L.kick + L.kickGap

	-- The words on their page; while they are changed, the box in their place, as tall as what is written.
	local links = (not editing and raw ~= "") and Links(raw) or {}
	local inner = column - 2 * L.page
	s.words:SetShown(not editing)
	s.box:SetShown(editing)
	local tall
	if editing then
		own.measure:SetWidth(inner)
		local written = s.box:GetText() or ""
		own.measure:SetText(written ~= "" and (written .. "\n ") or " \n ")
		tall = math.ceil(own.measure:GetStringHeight())
		s.box:SetHeight(tall)
	else
		s.words:SetWidth(inner)
		s.words:SetText(raw ~= "" and Marked(raw, links) or none)
		tall = math.ceil(s.words:GetStringHeight())
	end
	tall = tall + 2 * L.page
	s.page:ClearAllPoints()
	s.page:SetPoint("TOPLEFT", sheet, "TOPLEFT", x, -y)
	s.page:SetSize(column, tall)
	local face, ink = s.page:Lay(nil)
	UI.FaceInk(s.words, s.page, face, raw ~= "" and ink or C.dim)
	UI.FaceInk(s.box, s.page, face, ink)
	y = y + tall

	-- Its links, a chip each, wrapping onto the next line.
	local at, shown = 0, 0
	if #links > 0 then y = y + L.chipGap + 2 end
	for i, link in ipairs(links) do
		local chip = Chip(s, i)
		chip.link = link.text
		chip.text:SetWidth(0)
		chip.text:SetText(link.text)
		local wide = math.min(column, math.ceil(chip.text:GetStringWidth()) + 34)
		chip.text:SetWidth(wide - 34)
		if at > 0 and at + wide > column then
			at = 0
			y = y + L.chip + L.chipGap
		end
		chip:SetWidth(wide)
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", sheet, "TOPLEFT", x + at, -y)
		chip:Show()
		at = at + wide + L.chipGap
		shown = i
	end
	if shown > 0 then y = y + L.chip end
	for i = shown + 1, #s.chips do s.chips[i]:Hide() end
	return y
end

-- The message of the day across the window; with none, only for those who may write one. Returns its height.
local function DrawNotice(wide)
	local s = own.sections.motd
	local can = CanEditMOTD() and true or false
	local shown = guild.motd ~= "" or can
	own.notice:SetShown(shown)
	if not shown then
		own.notice:SetHeight(1)
		return 0
	end
	local tall = DrawSection(s, guild.motd, WORDS.noMotd, can, L.inset, L.notice, wide - 4 - 2 * L.inset) + L.notice
	own.notice:SetHeight(tall)
	return tall
end

local function DrawBoard(width)
	local sheet = own.board.content
	sheet:SetWidth(width)
	local column = width - 2 * L.inset
	local y = DrawSection(own.sections.info, guild.info, WORDS.noInfo, CanEditGuildInfo() and true or false, L.inset, L.inset, column) + L.section
	-- What happened lately.
	own.latelyKick:SetShown(#lately > 0)
	if #lately > 0 then
		own.latelyKick:ClearAllPoints()
		own.latelyKick:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
		own.latelyKick:SetWidth(column)
		own.latelyKick:Say(WORDS.lately)
		y = y + L.kick + 2
	end
	for i, event in ipairs(lately) do
		local row = LogRow(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", sheet, "TOPLEFT", L.inset, -y)
		row:SetWidth(column)
		row.when:SetText(event.when or "")
		row.text:SetText(event.text)
		UI.Paint(row.mark, TONE[event.tone] or C.dim, 0.9)
		row:Show()
		y = y + L.log
	end
	for i = #lately + 1, #own.logs do own.logs[i]:Hide() end
	sheet:SetHeight(y + L.inset)
	own.board:Update()
end

-- side: beside the chat, who is on under its name; else the roster's page, with its controls.
local function DrawRoster(width, side)
	local opt = Opt()
	own.listW = width - 14
	own.list.content:SetWidth(own.listW)
	own.strip:SetShown(not side)
	own.sideKick:SetShown(side)
	if side then
		own.sideKick:Say(WORDS.whoOn, tostring(sum.online), C.good)
	else
		own.filter:Select(opt.show == "all" and 2 or 1)
		own.filter:SetCount(1, sum.online)
		own.filter:SetCount(2, sum.total)
		own.sort:SetLabel((SORT[opt.sort] or SORTS[1]).by)
		-- The search takes what the two leave, where that is worth a search.
		local room = width - 2 * (L.inset - 4) - own.filter:GetWidth() - own.sort:GetWidth() - 2 * L.stripGap
		own.search:SetShown(room >= L.find)
		own.search:ClearAllPoints()
		own.search:SetPoint("LEFT", own.filter, "RIGHT", L.stripGap, 0)
		own.search:SetPoint("RIGHT", own.sort, "LEFT", -L.stripGap, 0)
	end
	if own.side ~= side then
		own.side = side
		own.list:SetVerticalScroll(0)
	end
	List(side)
	own.list.content:SetHeight(math.max(1, entries.tall))
	own.list:Update()
	LayList()
	own.none:SetShown(not side and entries.count == 0 and S.search ~= "")
end

local function DrawChat()
	local officers = chat.streams.officer ~= nil
	own.streams:SetShown(officers)
	own.streams:Select(S.stream == "officer" and 2 or 1)
	own.msg:ClearAllPoints()
	own.msg:SetPoint("BOTTOMLEFT", own.say, "TOPLEFT", 2, 8)
	own.msg:SetPoint("BOTTOMRIGHT", own.say, "TOPRIGHT", -2, 8)
	own.msg:SetPoint("TOP", own.chat, "TOP", 0, -(officers and (L.stripTop + L.strip + 8) or L.stripTop))
	-- The stream on show is the one picked, read again once it is known or given again.
	if not S.held and chat.shown ~= chat.streams[S.stream] then ShowChat() end
	own.empty:SetShown(chat.shown ~= nil and own.msg:GetNumMessages() == 0)
	local can = S.stream == "officer" or C_GuildInfo.CanSpeakInGuildChat()
	own.say.off = not can
	own.say:SetEnabled(can)
	own.say:SetAlpha(can and 1 or 0.6)
	own.say.hint:SetText(not can and WORDS.mute or (S.stream == "officer" and WORDS.sayOfficers or WORDS.say))
	own.say.hint:SetShown((own.say:GetText() or "") == "")
end

-- The foot: what is under way at its left; at its right the answer filled (Save, Invite member), the rest quiet words.
local function DrawFoot()
	for _, b in pairs(own.b) do b:Hide() end
	local B = own.b
	local list, first = {}, false   -- right to left; first: the first of them is the answer
	if Editing() then
		list, first = { B.save, B.cancel }, true
	else
		if CanGuildInvite() then
			list[#list + 1] = B.invite
			first = true
		end
		if IsGuildLeader() or C_GuildInfo.IsGuildOfficer() then list[#list + 1] = B.control end
		list[#list + 1] = B.theirs
	end
	own.status:SetText("")
	local gap = L.between
	local room = UI.BodySize(own.box) - 4 - 2 * L.button
	local need = 0
	for i, b in ipairs(list) do
		local quiet = not (first and i == 1)
		b:SetPrimary(not quiet)
		b:SetBare(quiet)
		local wide = math.ceil(b.text:GetUnboundedStringWidth())
		b.full = quiet and (wide + 2 * L.quiet) or math.max(96, wide + 34)
		b.least = quiet and b.full or (wide + 22)
		need = need + b.full + (i > 1 and gap or 0)
	end
	local least = need > room
	local right = -L.button
	for _, b in ipairs(list) do
		b:SetWidth(least and b.least or b.full)
		b.text:SetWidth(b:GetWidth() - 8)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", own.foot, "RIGHT", right, 0)
		b:Show()
		right = right - b:GetWidth() - gap
	end
end

-- The body under the message of the day: the page picked; who is on beside the chat and the guild's information where
-- the window is wide enough, the roster's own page across it.
local function Draw()
	if S.stale then
		-- (Read at most once a pace: a large guild's members come and go by the second.)
		if S.readAt and GetTime() - S.readAt < L.pace then
			if not S.waiting then
				S.waiting = true
				C_Timer.After(L.pace, function()
					S.waiting = false
					Stale()
				end)
			end
		else
			S.stale = false
			Read()
		end
	end
	local box = own.box
	local wide, tall = UI.BodySize(box)   -- (what it holds stands on its body: UI.Body)
	if issecretvalue(wide) or not wide or wide <= 0 then wide = L.w end
	if issecretvalue(tall) or not tall or tall <= 0 then tall = L.h end
	local page = S.page
	local side = wide >= L.split and page ~= "roster"
	own.chat:SetShown(page == "chat")
	own.board:SetShown(page == "board")
	own.roster:SetShown(page == "roster" or side)
	own.divide:SetShown(side)

	DrawBand()
	local top = DrawNotice(wide)
	local left = page == "chat" and own.chat or own.board
	local leftW = side and (wide - 4 - L.side - L.gap) or (wide - 4)
	if page ~= "roster" then
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", own.band, "BOTTOMLEFT", 0, -top)
		left:SetPoint("BOTTOM", own.foot, "TOP", 0, 2)
		left:SetWidth(leftW)
	end
	own.roster:ClearAllPoints()
	if side then
		own.roster:SetPoint("TOPLEFT", left, "TOPRIGHT", L.gap, 0)
		own.divide:ClearAllPoints()
		own.divide:SetPoint("TOP", own.notice, "BOTTOM", 0, 0)
		own.divide:SetPoint("BOTTOM", own.foot, "TOP", 0, 0)
		own.divide:SetPoint("LEFT", left, "RIGHT", L.gap / 2, 0)
	else
		own.roster:SetPoint("TOPLEFT", own.band, "BOTTOMLEFT", 0, -top)
	end
	own.roster:SetPoint("BOTTOMRIGHT", own.foot, "TOPRIGHT", -4, 2)

	if page == "board" then DrawBoard(leftW - 14) end
	if page == "chat" then DrawChat() end
	if page == "roster" then DrawRoster(wide - 8, false) elseif side then DrawRoster(L.side - 4, true) end
	DrawFoot()
end

Refresh = function()
	if not (M and M.on and S.open and own.box) then return end
	Shop.Try(M, Draw)
end

Stale = Shop.Later(function() Refresh() end)

-- Opening and closing

-- Ours goes away: by its ×, Escape, the guild key, the module switched off. What it held of the game's is let go of
-- (the stream it asked the game to follow, the keyboard).
local function Closed()
	S.open, S.edit = false, nil
	UI.CopyFieldClose()
	if chat.focus and guild.club then C_Club.UnfocusStream(guild.club, chat.focus) end
	chat.focus, chat.shown = nil, nil
	for _, s in pairs(own.sections) do s.box:ClearFocus() end
	if own.search then own.search:ClearFocus() end
	if own.say then own.say:ClearFocus() end
end

Shut = function()
	if not S.open then return end
	S.open = false
	Shy.Hover.Close()
	if own.box then Shy.HUD.Update(own.box) end   -- (hidden: Closed runs from its OnHide)
end

Open = function()
	if not own.box then
		Shop.Try(M, function()
			Build()
			own.box:HookScript("OnHide", Closed)
		end)
		if not own.box then return end
	end
	S.open, S.edit, S.stale, S.readAt = true, nil, true, nil
	-- The roster and the log are asked for; what the game already has is drawn at once, the rest as it arrives.
	C_GuildInfo.GuildRoster()
	QueryGuildEventLog()
	Shy.HUD.Update(own.box)
	Refresh()
end

-- The game's own window, asked for from ours: ours steps aside, and the way back stands on the game's until it closes.
Theirs = function()
	local f = Frame()
	if not f then return end
	Shut()
	if not own.back then
		own.back = UI.Button(f, WORDS.back, 150, function()
			HideUIPanel(Frame())
			Open()
		end)
		own.back:SetHeight(22)
		own.back:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -4, 4)
		own.back:SetPrimary(true)
		f:HookScript("OnHide", function() own.back:Hide() end)
	end
	own.back:Show()
	ShowUIPanel(f)
end

-- The guild key and the guild's button, after the game has answered them (a post-hook on ToggleGuildFrame): in a
-- guild, the game's window it just opened is put away again, untouched, and ours opens or closes in its place.
-- Whatever else opens the game's window (a guild finder's link, an invitation, Communities in our foot) leaves it be,
-- and so does the key that closes it.
local function Toggled()
	if not (M and M.on) or not IsInGuild() then return end
	local f = Frame()
	if not (f and f:IsShown()) then return end
	if InCombatLockdown() and f:IsProtected() then return end
	HideUIPanel(f)
	if S.open then Shut() else Open() end
end

-- The module

local EVENTS = { "GUILD_ROSTER_UPDATE", "GUILD_MOTD", "GUILD_RANKS_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_EVENT_LOG_UPDATE",
	"CLUB_MEMBER_ADDED", "CLUB_MEMBER_REMOVED", "CLUB_MEMBER_UPDATED", "CLUB_MEMBERS_UPDATED", "CLUB_MEMBER_PRESENCE_UPDATED",
	"CLUB_STREAMS_LOADED", "CLUB_STREAM_SUBSCRIBED", "CLUB_MESSAGE_ADDED", "CLUB_MESSAGE_HISTORY_RECEIVED", "PLAYER_REGEN_ENABLED" }

local function Hook()
	hooksecurefunc("ToggleGuildFrame", Toggled)
	Menu.ModifyMenu("MENU_UNIT_COMMUNITIES_GUILD_MEMBER", Extend)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function(_, event, ...)
		-- (The message of the day is kept as the game tells it, open or not: it is there the moment the window is.)
		if event == "GUILD_MOTD" then guild.motd, guild.told = Plain((...)) or guild.motd, true end
		if not (M.on and S.open and own.box) then return end
		if event == "PLAYER_GUILD_UPDATE" and not IsInGuild() then return Shut() end
		if event == "CLUB_MESSAGE_ADDED" or event == "CLUB_MESSAGE_HISTORY_RECEIVED" then
			local club, stream, id = ...
			Shop.Try(M, function() Heard(event, club, stream, id) end)
			if own.empty then own.empty:SetShown(chat.shown ~= nil and own.msg:GetNumMessages() == 0) end
			return
		end
		-- (The game's window asks for the roster again when the server says it changed; it is not up, so we do.)
		if event == "GUILD_ROSTER_UPDATE" and Plain((...)) == true then C_GuildInfo.GuildRoster() end
		S.stale = true
		Stale()
	end)
	Shy:On("SHY_THEME", function() if own.msg then ChatFace() end end)
end

local function Paint(m)
	if not S.open then return end
	S.stale = true
	Refresh()
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	Shut()
	if own.back then own.back:Hide() end
end

M = ns.Module({
	id = "guild",
	title = "Guild",
	desc = "Your guild gets a new window with its chat, who's online and where, and a roster you can search.",
	group = "rebuilt",
	words = "roster officer",
	Ready = function() return Shop ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,     -- exposed for inspection
	state = S,
	guild = guild,
	chat = chat,
	Links = Links,
	Extend = Extend,
	Open = function() Open() end,
	Shut = function() Shut() end,
})

