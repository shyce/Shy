-- Everyone contacted about the run: status and whisper thread per person.
-- Status: found -> asked -> replied / yes / no -> invited -> joined (or declined,
-- grouped, offline, busy, left), driven by whispers, system messages and the
-- roster. Secret whispers can't be read and are skipped.

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local Pp = {}
ns.People = Pp

local THREAD_MAX = 40
local KEEP_HOURS = 3

-- Palette tables by reference, so statuses follow a theme change.
local C = Shy.UI.colors
local GOOD, ALERT, HOT, BAD, DIM = C.good, C.alert, C.hot, C.bad, C.dim
local STEEL = Shy.Skin.colors.metal   -- asked, nothing back yet

-- rank: lower sorts first. live: still open, may yet join.
Pp.STATUS = {
	yes       = { text = "Says yes",         color = GOOD,     rank = 1, live = true },
	wants     = { text = "Wants in",         color = GOOD,     rank = 2, live = true },
	replied   = { text = "Replied",          color = ALERT,    rank = 3, live = true },
	whispered = { text = "Whispered you",    color = ALERT,    rank = 4, live = true },
	invited   = { text = "Invited",          color = HOT,    rank = 5, live = true },
	asked     = { text = "Asked",            color = STEEL,    rank = 6, live = true },
	no        = { text = "Says no",          color = BAD,      rank = 7 },
	declined  = { text = "Declined",         color = BAD,      rank = 8 },
	grouped   = { text = "In another group", color = DIM,      rank = 9 },
	busy      = { text = "Busy",             color = DIM,      rank = 10 },
	offline   = { text = "Not online",       color = DIM,      rank = 11 },
	ignoring  = { text = "Ignoring you",     color = DIM,      rank = 12 },
	left      = { text = "Left the group",   color = DIM,      rank = 13 },
	joined    = { text = "In your group",    color = GOOD,     rank = 14 },
	passed    = { rank = 15 },
	found     = { rank = 16 },
}

local people   -- ns.char.people: name -> person

function Pp.Get(name)
	return people[name]
end

function Pp.All()
	return people
end

-- info: optional class, level, guid, lang. Their chat post, if any, is copied in.
function Pp.Ensure(name, info)
	local p = people[name]
	if not p then
		p = { name = name, status = "found", t = time(), unread = 0, thread = {} }
		people[name] = p
	end
	if info then
		p.class = info.class or p.class
		p.level = info.level or p.level
		p.guid = info.guid or p.guid
	end
	local post = ns.Board.Get(name)
	if post then p.post = post.text end
	return p
end

local function SetStatus(p, status)
	p.status = status
	p.t = time()
	ns.Changed()
end

local function AddLine(p, text, out)
	local thread = p.thread
	thread[#thread + 1] = { t = time(), text = text, out = out or nil }
	while #thread > THREAD_MAX do table.remove(thread, 1) end
	p.t = time()
end

-- Actions

function Pp.Send(name, text)
	C_ChatInfo.SendChatMessage(text:sub(1, 255), "WHISPER", nil, name)
end

function Pp.Ask(candidate, role)
	local p = Pp.Ensure(candidate.name, candidate)
	p.role = role or p.role
	p.status = "asked"
	Pp.Send(p.name, ns.Run.AskText(candidate, role))
	ns.Changed()
end

-- The whisper asking a listed group for a spot.
function Pp.JoinText(post)
	local d = post.keys[1] and D.byKey[post.keys[1]]
	return ns.Run.Fill(T.db.templates.join, { dungeon = d and d.name or "your group", name = ns.Run.FirstName(post.name),
		myroles = ns.Run.MyRoles() })
end

-- The seat they'll take when they join. In the group already, it is set in the game too.
function Pp.SetRole(name, role)
	local p = Pp.Ensure(name)
	p.role = role
	for _, m in ipairs(ns.Run.Members()) do
		if m.name == name then
			ns.Run.SetRole(name, role)
			return
		end
	end
	ns.Changed()
end

-- A status in words, with the role they named in a reply.
function Pp.StatusText(p)
	local status = Pp.STATUS[p.status]
	if Pp.IsIgnored(p.name) then return "Ignored", BAD end
	if p.said and p.status ~= "joined" and p.status ~= "invited" and status.live then
		local can = "can " .. ns.Run.BARE[p.said]
		if p.status == "replied" then return "Can " .. ns.Run.BARE[p.said], status.color end
		return status.text .. ", " .. can, status.color
	end
	return status.text, status.color
end

-- The canned replies, and the one for people still waiting once the group is full.
function Pp.Replies()
	return T.db.replies
end

function Pp.FullText()
	for _, reply in ipairs(T.db.replies) do
		if reply.act == "pass" and reply.text ~= "" then return reply.text end
	end
	return "Sorry, we just filled up. Good luck!"
end

-- Sends a canned reply and does what it carries: an invite, or marking them not interested.
function Pp.Reply(name, reply)
	if not reply or reply.text == "" then return end
	Pp.Send(name, reply.text)
	if reply.role then Pp.SetRole(name, reply.role) end
	if reply.act == "invite" then
		Pp.Invite(name)
	elseif reply.act == "pass" then
		Pp.Pass(name)
	end
end

function Pp.AskToJoin(post)
	local p = Pp.Ensure(post.name, post)
	p.status = "asked"
	Pp.Send(p.name, Pp.JoinText(post))
	ns.Changed()
end

function Pp.Invite(name)
	if not ns.Run.CanInvite() then
		T:Print("only the group leader or an assistant can invite.")
		return
	end
	local p = Pp.Ensure(name)
	C_PartyInfo.InviteUnit(name)
	SetStatus(p, "invited")
end

-- Hides them from the lists; the thread is kept.
function Pp.Pass(name)
	SetStatus(Pp.Ensure(name), "passed")
end

-- The game's ignore list, shown here and switched from here.
function Pp.IsIgnored(name)
	return C_FriendList.IsIgnored(name) == true
end

function Pp.Ignore(name)
	C_FriendList.AddIgnore(name)
	Pp.Pass(name)
end

-- Back to found: they may be asked again.
function Pp.Unignore(name)
	C_FriendList.DelIgnore(name)
	local p = people[name]
	if p and p.status == "passed" then SetStatus(p, "found") end
	ns.Changed()
end

-- Clears the conversation. Someone in your group stays, with an empty thread.
function Pp.Forget(name)
	local p = people[name]
	if not p then return end
	if p.status == "joined" then
		wipe(p.thread)
		p.unread = 0
	else
		people[name] = nil
	end
	ns.Changed()
end

function Pp.ForgetAll()
	for name in pairs(people) do Pp.Forget(name) end
end

function Pp.Read(name)
	local p = people[name]
	if p and p.unread > 0 then
		p.unread = 0
		ns.Changed()
	end
end

function Pp.Unread()
	local total = 0
	for _, p in pairs(people) do total = total + p.unread end
	return total
end

-- Threads: unread first, then most recent.
function Pp.Threads()
	local list = {}
	for _, p in pairs(people) do
		if #p.thread > 0 then list[#list + 1] = p end
	end
	table.sort(list, function(a, b)
		if (a.unread > 0) ~= (b.unread > 0) then return a.unread > 0 end
		if a.t ~= b.t then return a.t > b.t end
		return a.name < b.name
	end)
	return list
end

-- Everyone with a live status who hasn't joined.
function Pp.Waiting()
	local list = {}
	for _, p in pairs(people) do
		if p.status ~= "joined" and Pp.STATUS[p.status].live then list[#list + 1] = p end
	end
	return list
end

function Pp.Clear()
	wipe(people)
	ns.Changed()
end

function Pp.SyncRoster()
	local inGroup = {}
	for _, m in ipairs(ns.Run.Members()) do
		inGroup[m.name] = true
		local p = people[m.name]
		if p and p.status ~= "joined" then
			p.status = "joined"
			p.t = time()
		end
	end
	for name, p in pairs(people) do
		if p.status == "joined" and not inGroup[name] then
			p.status = "left"
			p.t = time()
		end
	end
	ns.Run.FillRoles()
	ns.Changed()
end

-- Whispers

local function ClassAndLevel(guid)
	if not guid or not canaccessvalue(guid) or guid == "" then return end
	local _, class, _, _, _, _, _, level = GetPlayerInfoByGUID(guid)
	return class, level
end

local function OnWhisper(text, sender, guid)
	if issecretvalue(text) or issecretvalue(sender) then return end
	local name = ns.Short(sender)
	local p = people[name]
	local run = ns.Run.Get()
	if not p then
		-- A stranger is kept only during a run, unless `collect` is "always".
		if not run and T.db.collect ~= "always" then return end
		p = Pp.Ensure(name)
		p.status = ns.Parse.Wants(text) and "wants" or "whispered"
	else
		local was = p.status
		-- "i can heal": remembered, so one click seats them.
		local named = ns.Parse.RoleIn(text)
		if named then p.said = named end
		if was ~= "joined" then
			local verdict = ns.Parse.Reply(text)
			if was == "asked" or was == "invited" then
				p.status = verdict or "replied"
			elseif was == "replied" and verdict then
				-- A clear yes or no after some back and forth.
				p.status = verdict
			elseif not Pp.STATUS[was].live then
				p.status = verdict == "yes" and "yes" or "replied"
			end
			if T.db.autoInvite and was == "asked" and verdict == "yes"
				and run and ns.Run.CanInvite() and not ns.Run.IsFull() then
				C_PartyInfo.InviteUnit(name)
				p.status = "invited"
			end
		end
	end
	local class, level = ClassAndLevel(guid)
	p.class, p.level, p.guid = class or p.class, level or p.level, guid or p.guid
	AddLine(p, text, false)
	-- Unread unless that thread is on screen.
	if not (ns.char.open and Pp.viewing == name) then p.unread = p.unread + 1 end
	-- A reply is news for the group's piece of the faded HUD's watch.
	local immersion = Shy.Immersion
	if immersion and immersion.News then immersion.News("group", 20) end
	ns.Changed()
end

local function OnWhisperSent(text, target)
	if issecretvalue(text) or issecretvalue(target) then return end
	local p = people[ns.Short(target)]
	if not p then return end
	if p.status == "found" then p.status = "asked" end
	AddLine(p, text, true)
	ns.Changed()
end

-- Invite results, matched against the client's localized system messages

local function Pattern(template)
	local escaped = template:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	return "^" .. escaped:gsub("%%%%s", "(.+)") .. "$"
end

local SYSTEM = {
	{ Pattern(ERR_INVITE_PLAYER_S), "invited" },
	{ Pattern(ERR_DECLINE_GROUP_S), "declined" },
	{ Pattern(ERR_ALREADY_IN_GROUP_S), "grouped" },
	{ Pattern(ERR_PLAYER_BUSY_S), "busy" },
	{ Pattern(ERR_CHAT_PLAYER_NOT_FOUND_S), "offline" },
	{ Pattern(ERR_BAD_PLAYER_NAME_S), "offline" },
	{ Pattern(ERR_IGNORING_YOU_S), "ignoring" },
}

local function OnSystem(text)
	if issecretvalue(text) then return end
	for _, entry in ipairs(SYSTEM) do
		local name = text:match(entry[1])
		if name then
			local p = people[ns.Short(name)]
			if p and p.status ~= "joined" then SetStatus(p, entry[2]) end
			return
		end
	end
end

function Pp.Init()
	people = ns.char.people
	local cutoff = time() - KEEP_HOURS * 3600
	for name, p in pairs(people) do
		if p.t < cutoff then people[name] = nil end
	end

	local events = CreateFrame("Frame")
	events:RegisterEvent("CHAT_MSG_WHISPER")
	events:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
	events:RegisterEvent("CHAT_MSG_SYSTEM")
	events:SetScript("OnEvent", function(_, event, text, sender, _, _, _, _, _, _, _, _, _, guid)
		if event == "CHAT_MSG_WHISPER" then
			OnWhisper(text, sender, guid)
		elseif event == "CHAT_MSG_WHISPER_INFORM" then
			OnWhisperSent(text, sender)
		else
			OnSystem(text)
		end
	end)
	Pp.SyncRoster()
end
