-- Shy.Way.Share: a place sent to someone as a route they can take or leave. Whoever shares names a place
-- (the game's map pin, where they stand, a place of the map's); it reaches the other player's copy as a
-- suggested route under the sender's name and class, and waits there to be taken or passed on. Taken, the
-- game's map pin is put on the place and tracked, and where ShyQuest is on it leads there along a trail in
-- the sender's class color. The sender hears what became of it.
--
-- Whoever has no copy of this still gets the place: when no copy answers within a few seconds, it goes to
-- them as the game's own map pin link, in a whisper (a Battle.net whisper for a Battle.net friend), or in
-- the group's chat when not everyone in the group answered. They click it as any pin link; only the
-- suggested route and its guidance need a copy.
--
-- The game's own map pin link is a suggestion too: one posted in the group's chat or a whisper, by someone
-- in your group or on your friends list, is offered the same way, whatever they run.
--
--   Shy.Way.Share.On() / SetOn(on)        suggestions are offered at all (kept with the account)
--   Shy.Way.Share.Pin() -> place          the game's map pin as a place to share, or nil
--   Shy.Way.Share.Here() -> place         where you stand, as a place to share ("Meet <you>"), or nil
--   Shy.Way.Share.Send(place, to) -> id   place: { map, x, y (shares of the map), title, say (the words before
--                                         its link in chat) }; to: { group = true }, { tell = name } or
--                                         { bnet = gameAccountID, account = bnetAccountID }, with `name` to say
--                                         who. nil, why ("place" | "locked" | "nobody") where it can't be sent
--   Shy.Way.Share.Targets() -> list       who a place can go to now: { label, class, uses, to }, the group
--                                         first, then the friends ShyMaps lists
--   Shy.Way.Share.Write(root, place, label)   the "Share with" entry of a menu (UI.ContextMenu's writer),
--                                         a row for each of Targets; place may be a function
--   Shy.Way.Share.Offers() -> list        what waits to be answered, oldest first: { key, from, class, map, x, y,
--                                         title, where, at, till, link (it came as a chat link) }
--   Shy.Way.Share.Accept(offer) / Decline(offer)
--   Shy.Way.Share.Ping(place, mark) -> id   point a place out to your group now (mark: the raid mark it wears,
--                                         1-8): no offer, nothing to answer. Their copies ring the game's map
--                                         ping and show it a few seconds; the rest get it in the group's chat
--   Shy.Way.Share.Pings() -> list         what was pointed out to you and still stands: { from, class, map, x, y,
--                                         title, mark, where, at, till }
--   Shy.Way.Share.Lead(record)            an offer's or a ping's place leads (the pin, tracked; ShyQuest's route)
--   Shy.Way.Share.Away(offer) -> seconds, yards   how far it is: by ShyWay's journey, and in a straight line
--                                         on the same continent (nil for what isn't known)
--   Shy.Way.Share.Color(class) -> color   a class's color as one table, the same each time (a trail's color)
--
-- Bus: SHY_WAY_SHARE (what, record). An offer: "offer" (it came, or came again), "gone" (answered or timed
-- out; record.state is "accepted", "declined" or "expired"). What you sent: "sent", "got" (their copy has
-- it), "yes", "no", "linked" (no copy answered, or not the whole group's: it went as the pin's chat link),
-- "unheard" (... and the game let no chat go either). A ping: "ping" (it came), "unping" (it is over).
--
-- On the wire (ShyCore's one prefix, this addon's suffix), tab separated:
--   S id map x y class name title     a suggestion; x, y in ten-thousandths of the map
--   P id map x y class name title mark   a ping, with the raid mark (0: none)
--   G id                              got it
--   Y id / N id                       taken / passed on

local Way = Shy.Way
local T = Shy:NewAddon("ShyWay", {
	suffix = "Way",
	internal = true,
	icon = "Interface\\AddOns\\ShyWay\\Media\\ShyWay",
	smallIcon = "Interface\\AddOns\\ShyWay\\Media\\ShyWaySmall",
})

local Share = {}
Way.Share = Share

local K = {
	UNITS = 10000,          -- a place on the wire: ten-thousandths of a map
	HOLD = 90,              -- seconds an offer waits for an answer
	MOST = 4,               -- offers waiting at once; the oldest goes for another
	TITLE = 60,             -- letters of a place's name sent
	HEARD = 3,              -- seconds a send waits for a copy to say it has it; then the pin goes as a chat link
	EVERY = 10,             -- seconds between two sends to the same people
	PING_EVERY = 3,         -- ... and between two pings
	PINGED = 12,            -- seconds a ping stays
	SAME = 0.003,           -- shares of a map: two places this near are one
	TICK = 0.5,
}

local offers = {}           -- oldest first
local pings = {}            -- oldest first: what someone in the group pointed out a moment ago
local recent = {}           -- who -> { map, x, y, till }: the place of theirs just answered
local sent = {}             -- id -> { id, to, name, place, at, got, heard, names, words, link, settled }
local Wake                  -- below
local lastSent = {}         -- who -> when
local nextId = 0
local ticker
local colors = {}

local function Fire(what, record)
	Shy:Fire("SHY_WAY_SHARE", what, record)
end

-- Settings

local function Saved()
	local saved = Way.Saved()
	if type(saved.share) ~= "table" then saved.share = {} end
	return saved.share
end

function Share.On()
	return Saved().off ~= true
end

function Share.SetOn(on)
	Saved().off = (not on) and true or nil
	if not on then
		for i = #offers, 1, -1 do
			local offer = table.remove(offers, i)
			offer.state = "expired"
			Fire("gone", offer)
		end
		for i = #pings, 1, -1 do Fire("unping", table.remove(pings, i)) end
	end
end

-- Who and where

function Share.Color(class)
	if not class then return nil end
	local color = colors[class]
	if color == nil then
		local found = C_ClassColor.GetClassColor(class)
		color = found and { found.r, found.g, found.b } or false
		colors[class] = color
	end
	return color or nil
end

-- Your name as chat gives it: a first name and a surname are one name.
local function Me()
	local name, surname = UnitNameUnmodified("player")
	if surname and surname ~= "" then
		name = name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname
	end
	return name
end

local function Plain(text, most)
	text = tostring(text or ""):gsub("[%c|]", " ")
	text = strtrim(text)
	if #text > most then text = text:sub(1, most) end
	return text
end

-- A place in words: "Elwynn Forest 42.1, 65.0".
local function Where(map, x, y)
	local info = C_Map.GetMapInfo(map)
	return ("%s %.1f, %.1f"):format(info and info.name or "Map", x * 100, y * 100)
end

function Share.Pin()
	local point = Shy.Waypoint.Get()
	local position = point and point.position
	if not (position and point.uiMapID and position.x and position.y) then return nil end
	return { map = point.uiMapID, x = position.x, y = position.y, title = ("%s's pin"):format(Me()) }
end

function Share.Here()
	local map, x, y = Shy.HereOn()
	if not (map and x and y and C_Map.CanSetUserWaypointOnMap(map)) then return nil end
	return { map = map, x = x, y = y, title = "Meet " .. Me(), say = "Meet me here:" }
end

-- A place in the world: continent, north, west; nil where its map lies in none.
local function World(map, x, y)
	local continent, position = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
	if not (continent and position) then return nil end
	local north, west = position:GetXY()
	return continent, north, west
end

function Share.Away(offer)
	local continent, north, west = World(offer.map, offer.x, offer.y)
	local here, n, w = Shy.Here()
	if not (continent and here) then return nil end
	local journey = Way.Journey(Way.Place(here, n, w), Way.Place(continent, north, west))
	local yards = here == continent and math.sqrt((north - n) ^ 2 + (west - w) ^ 2) or nil
	return journey and journey.seconds or nil, yards
end

-- Sending

local function Wire(text, to)
	if to.bnet then
		T:SendBNComm(text, to.bnet)
	elseif to.tell then
		T:SendComm(text, "WHISPER", to.tell)
	elseif to.group then
		local channel = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil
		if not channel then return false end
		T:SendComm(text, channel)
	else
		return false
	end
	return true
end

-- The place as the game's own map pin link, in chat: what someone with no copy of this gets. kind: "WHISPER"
-- (to a name), "BN" (to a Battle.net account) or the group's chat. False where the game lets no chat go.
local function Link(record, kind, target)
	if not record.link or C_ChatInfo.InChatMessagingLockdown() then return false end
	local text = record.words ~= "" and (record.words .. " " .. record.link) or record.link
	if kind == "BN" then return C_BattleNet.SendWhisper(target, text) ~= false end
	C_ChatInfo.SendChatMessage(text, kind, nil, target)
	return true
end

-- Whoever's copy didn't answer has none: they get the pin as a chat link instead, a whisper for a friend,
-- the group's chat for a group not all of whom answered.
local function Unheard(record)
	local to, linked = record.to, false
	if to.group then
		local kind = IsInRaid() and "RAID" or IsInGroup() and "PARTY" or nil
		if not kind or record.heard >= GetNumGroupMembers() - 1 then return end
		linked = Link(record, kind)
		-- (A ping says nothing of itself: the line in chat is plain to see.)
		if record.ping then
			if linked then Fire("linked", record) end
			return
		end
		if linked then T:Print(("linked your pin in %s chat for everyone who didn't get the route."):format(kind == "RAID" and "raid" or "party")) end
	elseif not record.got then
		if to.tell then
			linked = Link(record, "WHISPER", to.tell)
		elseif to.account then
			linked = Link(record, "BN", to.account)
		end
		if linked then T:Print(("%s got your pin as a whisper."):format(record.name)) end
	else
		return
	end
	if linked then
		Fire("linked", record)
	else
		T:Print(("%s didn't get it."):format(record.name))
		Fire("unheard", record)
	end
end

local function Tick()
	local now = GetTime()
	for i = #offers, 1, -1 do
		local offer = offers[i]
		if offer.till <= now then
			table.remove(offers, i)
			offer.state = "expired"
			Fire("gone", offer)
		end
	end
	for i = #pings, 1, -1 do
		local ping = pings[i]
		if ping.till <= now then
			table.remove(pings, i)
			Fire("unping", ping)
		end
	end
	for who, place in pairs(recent) do
		if place.till <= now then recent[who] = nil end
	end
	local waiting = next(recent) ~= nil or #pings > 0
	for id, record in pairs(sent) do
		local age = now - record.at
		if not record.settled and age >= K.HEARD then
			record.settled = true
			Unheard(record)
		end
		if age >= K.HOLD + K.HEARD then sent[id] = nil else waiting = true end
	end
	if #offers == 0 and not waiting and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

Wake = function()
	if not ticker then ticker = C_Timer.NewTicker(K.TICK, Tick) end
end

-- A place out on the wire, as a suggestion ("S") or a ping ("P", with the raid mark it wears).
local function Out(kind, place, to, mark)
	if type(place) == "function" then place = place() end
	if not (place and to and place.map and place.x and place.y and C_Map.CanSetUserWaypointOnMap(place.map)) then
		return nil, "place"
	end
	local ping = kind == "P"
	if C_ChatInfo.InChatMessagingLockdown() then
		if not ping then T:Print("you can't share a place right now. Try again after the fight.") end
		return nil, "locked"
	end
	local who = kind .. (to.bnet and ("bnet:" .. to.bnet) or to.tell or "group")
	local now = GetTime()
	if lastSent[who] and now - lastSent[who] < (ping and K.PING_EVERY or K.EVERY) then
		if not ping then T:Print("you just shared a place with them. Give it a moment.") end
		return nil, "locked"
	end
	nextId = nextId + 1
	local id = nextId
	local class = UnitClassBase("player") or ""
	local text = ("%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s"):format(kind, id, place.map, math.floor(place.x * K.UNITS + 0.5),
		math.floor(place.y * K.UNITS + 0.5), class, Plain(Me(), 40), Plain(place.title, K.TITLE))
	if ping then text = text .. "\t" .. (mark or 0) end
	if not Wire(text, to) then return nil, "nobody" end
	lastSent[who] = now
	-- (The pin's link is made now, while the place is the one asked for: it goes to whoever has no copy.)
	local words = place.say or (place.title and place.title ~= "" and place.title ~= ("%s's pin"):format(Me()) and (place.title .. ":")) or ""
	local record = { id = id, to = to, name = to.name or (to.group and "Your group") or to.tell or "Your friend", place = place, at = now,
		heard = 0, names = {}, words = Plain(words, K.TITLE + 1), link = Shy.UI.PinLink(place.map, place.x, place.y) }
	if ping then
		-- (In chat, for whoever has no copy: the mark's own picture, then its name.)
		record.ping = true
		record.words = (mark and ("{rt%d} "):format(mark) or "") .. Plain(place.title, K.TITLE) .. ":"
	else
		PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CHAT_SHARE)
	end
	sent[id] = record
	Fire("sent", record)
	Wake()
	return id
end

function Share.Send(place, to)
	return Out("S", place, to)
end

function Share.Ping(place, mark)
	if not (IsInRaid() or IsInGroup()) then return nil, "nobody" end
	mark = tonumber(mark)
	return Out("P", place, { group = true, name = IsInRaid() and "Your raid" or "Your party" }, mark and mark >= 1 and mark <= 8 and mark or nil)
end

function Share.Targets()
	local list = {}
	if IsInRaid() then
		list[1] = { label = "Your raid", to = { group = true, name = "Your raid" }, uses = true }
	elseif IsInGroup() then
		list[1] = { label = "Your party", to = { group = true, name = "Your party" }, uses = true }
	end
	local maps = Shy.addons.Maps
	if maps and maps.ShareTargets then
		for _, target in ipairs(maps:ShareTargets()) do list[#list + 1] = target end
	end
	return list
end

function Share.Write(root, place, label)
	local entry = root:CreateButton(label or "Share with")
	entry:SetIcon(Shy.UI.MenuGlyph("share"))
	local targets = Share.Targets()
	if #targets == 0 then
		entry:SetEnabled(false)
		entry:SetDetail("nobody online")
		return entry
	end
	for _, target in ipairs(targets) do
		local row = entry:CreateButton(target.label, function() Share.Send(place, target.to) end)
		local color = Share.Color(target.class)
		if color then row.item.color = color end
	end
	return entry
end

-- What you sent, answered

local function Answered(kind, id, name)
	local record = sent[tonumber(id) or 0]
	if not record then return end
	local who = name or record.name
	if kind == "G" then
		if name and not record.names[name] then
			record.names[name] = true
			record.heard = record.heard + 1
		end
		if not record.got then
			record.got = true
			-- (A group's copies answer one by one: said once. A ping isn't said at all.)
			if not record.ping then T:Print(("sent to %s."):format(record.name)) end
		end
		Fire("got", record)
	elseif kind == "Y" then
		record.got = true
		PlaySound(SOUNDKIT.UI_WORLDQUEST_MAP_SELECT)
		T:Print(("%s is on the way."):format(who))
		Fire("yes", record)
	elseif kind == "N" then
		record.got = true
		T:Print(("%s passed on it."):format(who))
		Fire("no", record)
	end
end

-- Offers

local function Close(offer, state)
	for i, each in ipairs(offers) do
		if each == offer then
			table.remove(offers, i)
			offer.state = state
			-- (Answered: the same place linked in chat a moment later is not asked again.)
			recent[offer.who] = { map = offer.map, x = offer.x, y = offer.y, till = GetTime() + K.HOLD }
			Wake()
			Fire("gone", offer)
			return true
		end
	end
	return false
end

local function Offer(offer)
	if not Share.On() then return end
	local was = offer.link and recent[offer.who]
	if was and was.map == offer.map and math.abs(was.x - offer.x) < K.SAME and math.abs(was.y - offer.y) < K.SAME then return end
	-- Someone's newer place takes their older one's; the same place again only waits longer.
	for i = #offers, 1, -1 do
		local each = offers[i]
		if each.who == offer.who then
			if each.map == offer.map and math.abs(each.x - offer.x) < K.SAME and math.abs(each.y - offer.y) < K.SAME then
				each.till = GetTime() + K.HOLD
				-- (Their copy's word for it is the one answered.)
				if not offer.link then each.id, each.reply, each.link, each.title = offer.id, offer.reply, nil, offer.title end
				Fire("offer", each)
				return each
			end
			table.remove(offers, i)
			each.state = "expired"
			Fire("gone", each)
		end
	end
	while #offers >= K.MOST do
		local old = table.remove(offers, 1)
		old.state = "expired"
		Fire("gone", old)
	end
	offer.at = GetTime()
	offer.till = offer.at + K.HOLD
	offer.where = Where(offer.map, offer.x, offer.y)
	offer.key = offer.who .. ":" .. tostring(offer.id or offer.at)
	offers[#offers + 1] = offer
	Fire("offer", offer)
	Wake()
	return offer
end

function Share.Offers()
	return offers
end

-- The place leads: through ShyQuest's route where it is on, in the sender's color; else the game's own
-- pin, tracked.
local function Lead(offer)
	local quest = Shy.addons.Quest
	if quest and quest.Go and quest:Go(offer.map, offer.x, offer.y, offer.title, { by = offer.from, class = offer.class }) then
		return true
	end
	return Shy.Waypoint.Set(offer.map, offer.x, offer.y, true)
end

-- A ping taken up (or any place of this kind): it leads, as an offer accepted does.
function Share.Lead(record)
	if not (record and record.map and Lead(record)) then return false end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
	return true
end

function Share.Pings()
	return pings
end

-- Something a group member pointed out: it stands a few seconds (the newest of each of theirs), with the
-- game's map ping sound. The same place linked in chat right after, for those with no copy, is not an offer.
local function Pinged(ping)
	if not Share.On() then return end
	for i = #pings, 1, -1 do
		if pings[i].who == ping.who then Fire("unping", table.remove(pings, i)) end
	end
	ping.at = GetTime()
	ping.till = ping.at + K.PINGED
	ping.where = Where(ping.map, ping.x, ping.y)
	recent[ping.who] = { map = ping.map, x = ping.x, y = ping.y, till = ping.at + K.HOLD }
	pings[#pings + 1] = ping
	PlaySound(SOUNDKIT.MAP_PING)
	Fire("ping", ping)
	Wake()
end

function Share.Accept(offer)
	if not Close(offer, "accepted") then return false end
	if offer.reply and not C_ChatInfo.InChatMessagingLockdown() then Wire("Y\t" .. offer.id, offer.reply) end
	if not Lead(offer) then
		T:Print("the game takes no pin on that map.")
		return false
	end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON)
	return true
end

function Share.Decline(offer)
	if not Close(offer, "declined") then return false end
	if offer.reply and not C_ChatInfo.InChatMessagingLockdown() then Wire("N\t" .. offer.id, offer.reply) end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_REMOVE)
	return true
end

-- Receiving

-- Someone whose word is taken: in your group, or on your friends list.
local function Known(name)
	if UnitInParty(name) or UnitInRaid(name) then return true end
	return C_FriendList.GetFriendInfo(name) ~= nil
end

local function Class(token)
	return token and token ~= "" and Share.Color(token) and token or nil
end

-- A suggestion's fields off the wire, checked: nil for one that names no place.
local function Read(id, map, x, y, class, name, title)
	id, map, x, y = tonumber(id), tonumber(map), tonumber(x), tonumber(y)
	if not (id and map and x and y) or x < 0 or y < 0 or x > K.UNITS or y > K.UNITS then return nil end
	if not (C_Map.GetMapInfo(map) and C_Map.CanSetUserWaypointOnMap(map)) then return nil end
	return { id = id, map = map, x = x / K.UNITS, y = y / K.UNITS, class = Class(class), name = Plain(name, 40),
		title = Plain(title, K.TITLE) }
end

local function Heard(msg, who, from, reply)
	local kind, id, map, x, y, class, name, title, mark = strsplit("\t", msg)
	if kind == "P" then
		local ping = Read(id, map, x, y, class, name, title)
		if not ping then return end
		ping.who, ping.from = who, from or (ping.name ~= "" and ping.name) or "Someone"
		mark = tonumber(mark)
		ping.mark = mark and mark >= 1 and mark <= 8 and mark or nil
		if ping.title == "" then ping.title = "Over here" end
		if not C_ChatInfo.InChatMessagingLockdown() then Wire("G\t" .. ping.id, reply) end
		Pinged(ping)
	elseif kind == "S" then
		local offer = Read(id, map, x, y, class, name, title)
		if not offer then return end
		offer.who, offer.reply = who, reply
		offer.from = from or (offer.name ~= "" and offer.name) or "A friend"
		if offer.title == "" then offer.title = ("%s's pin"):format(offer.from) end
		if not C_ChatInfo.InChatMessagingLockdown() then Wire("G\t" .. offer.id, reply) end
		Offer(offer)
	elseif kind == "G" or kind == "Y" or kind == "N" then
		Answered(kind, id, from)
	end
end

function T:OnComm(msg, sender, channel)
	if issecretvalue(msg) or issecretvalue(sender) or Shy.IsMe(sender) then return end
	local name = Ambiguate(sender, "none")
	if channel == "WHISPER" then
		if not Known(name) then return end
	elseif channel ~= "PARTY" and channel ~= "RAID" then
		return
	end
	-- (Answered by whisper, whichever way it came: a group's answers are for the sender alone.)
	Heard(msg, name, name, { tell = sender })
end

function T:OnBNComm(msg, account)
	if issecretvalue(msg) or issecretvalue(account) then return end
	local game = C_BattleNet.GetGameAccountInfoByID(account)
	local name = game and game.characterName
	if name ~= nil and issecretvalue(name) then name = nil end
	Heard(msg, "bnet:" .. tostring(account), name, { bnet = account })
end

-- The game's map pin link in chat, from someone known: a suggestion like any other, with nobody to answer.
local LINKED = { CHAT_MSG_PARTY = true, CHAT_MSG_PARTY_LEADER = true, CHAT_MSG_RAID = true, CHAT_MSG_RAID_LEADER = true,
	CHAT_MSG_WHISPER = true }

local function Linked(text, sender, guid)
	if issecretvalue(text) or issecretvalue(sender) or not Share.On() or Shy.IsMe(sender) then return end
	local map, x, y = text:match("|Hworldmap:(%d+):(%d+):(%d+)|h")
	if not map then return end
	local name = Ambiguate(sender, "none")
	if not Known(name) then return end
	local class
	if guid and not issecretvalue(guid) and guid ~= "" then
		local _, token = GetPlayerInfoByGUID(guid)
		if token and not issecretvalue(token) then class = token end
	end
	local offer = Read(0, map, x, y, class, name, "")
	if not offer then return end
	offer.id, offer.who, offer.from, offer.link = nil, name, name, true
	offer.title = ("%s's pin"):format(name)
	Offer(offer)
end

local events = CreateFrame("Frame")
for event in pairs(LINKED) do events:RegisterEvent(event) end
events:SetScript("OnEvent", function(_, _, text, sender, _, _, _, _, _, _, _, _, _, guid)
	Linked(text, sender, guid)
end)
