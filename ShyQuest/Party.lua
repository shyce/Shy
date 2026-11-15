-- Party quest progress, shared over addon messages in the other quest addon's format (Wire.lua), so
-- it works with group members running either addon. Shown in tooltips (Hover.lua, Tips.lua).
--
-- Messages: a table with ver (sender's version), msgVer (5) and msgId:
--   1    one quest changed   quest = { id, objectives = { { id, typ, fin, ful, req }, ... } }
--                            id: the objective's creature, object or item; typ: first letter of the
--                            objective type (m, i, o, e ...); fin, ful, req: finished, have, need
--   2    quest removed       id
--   10   whole log, old form rawQuestList = { [id] = quest as in 1 }
--   11   request for a log   answered by whisper: 12, or 10 for a sender of version 5 or less
--   12   whole log           [1] = { quest count, then per quest: id, objective count, and per
--                            objective: id (0 for none), typ's byte, have, need }
--   14   one quest, as in 12 (read, never sent)
--
-- On joining a group: send 11 and our log (12); members already there don't ask. On someone else
-- joining: send 11 again. Not sent: that addon's second channel.
-- Party only, not raids. One message a second (the game drops bursts), none during
-- C_ChatInfo.InChatMessagingLockdown. With the other addon loaded only what the others send is read.
-- Members' objectives stand on the maps too (P.Marks), for quests not in our own log.

local ADDON, ns = ...
local T = ns.T
local L, Wire = ns.Log, ns.Wire

local P = {}
ns.Party = P

local VERSION = "6.0.0"      -- the version reported: the oldest that reads 12, so nobody is told to update
local BETWEEN = 1            -- seconds between two messages
local BLOCK = 200            -- approximate bytes of a whole log per message
local ASK_WAIT = 2           -- seconds after the group changes before asking
local ANSWER_WAIT = 1.5      -- seconds after being asked before answering

local members = {}           -- name -> { quests = { [id] = { complete, goals = { { have, need, done } } } } }
local sent = {}              -- quest -> its progress as last sent
local queue = {}             -- outgoing messages: { text, channel, target }
local parts = {}             -- incoming multi-part messages (Wire.Receive)
local answers = {}           -- who asked for our log -> when to answer, and in which form
local roster = {}            -- full name -> unit
local lastSent, askAt, tellAll = 0, nil, false

local function Sharing()
	return T.db.party.share
end

local function Grouped()
	return Sharing() and IsInGroup() and not IsInRaid()
end

local function Channel()
	return IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT" or "PARTY"
end

-- A unit's name as chat senders have it: first name and surname joined.
local function FullName(unit)
	local name, surname = UnitNameUnmodified(unit)
	if issecretvalue(name) or issecretvalue(surname) or not name then return nil end
	if surname and surname ~= "" then
		return name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname
	end
	return name
end

-- Sending

local function Packet(id)
	return { ver = VERSION, msgVer = Wire.VERSION, msgId = id }
end

-- The id of the objective's creature, object or item.
local function About(goal)
	local token = goal.tokens[1]
	if token and token.kind ~= "k" then return token.id end
end

local function Letter(goal)
	return (goal.type or "e"):sub(1, 1)
end

-- A quest in message 1's form; nil for a quest with no objectives.
local function Quest(entry)
	local objectives = {}
	for index, goal in ipairs(L.Goals(entry.id)) do
		objectives[index] = { id = About(goal), typ = Letter(goal), fin = goal.finished and true or nil,
			ful = goal.have or 0, req = goal.need or 0 }
	end
	if #objectives == 0 then return nil end
	return { id = entry.id, objectives = objectives }
end

-- A quest's progress as one string, for change detection.
local function Progress(entry)
	local counts = {}
	for index, goal in ipairs(entry.goals or {}) do counts[index] = goal.have .. "/" .. goal.need end
	return table.concat(counts, ",")
end

local OTHER = "Questie"      -- the other quest addon: its folder

-- With the other addon loaded it does the sending (and answers when asked): both would say everything
-- twice. What the others send is still heard.
local function Send(packet, channel, target)
	if C_AddOns.IsAddOnLoaded(OTHER) then return end
	for _, frame in ipairs(Wire.Frames(Wire.Encode(packet))) do
		queue[#queue + 1] = { text = frame, channel = channel, target = target }
	end
end

-- The whole log in messages of about BLOCK bytes, as 12 or (older) 10.
local function SendLog(channel, target, older)
	local block, count
	local function Close()
		if not block then return end
		local packet = Packet(older and 10 or 12)
		if older then
			packet.rawQuestList = block
		else
			block[1] = count
			packet[1] = block
		end
		Send(packet, channel, target)
		block = nil
	end
	local function Add(quest)
		if not block then block, count = older and {} or { 0 }, 0 end
		count = count + 1
		if older then
			block[quest.id] = quest
		else
			block[#block + 1] = quest.id
			block[#block + 1] = #quest.objectives
			for _, objective in ipairs(quest.objectives) do
				block[#block + 1] = objective.id or 0
				block[#block + 1] = objective.typ:byte()
				block[#block + 1] = objective.ful
				block[#block + 1] = objective.req
			end
		end
	end
	for _, entry in ipairs(L.order) do
		local quest = Quest(entry)
		if quest then
			if block and #Wire.Encode({ block }) + #Wire.Encode({ quest }) > BLOCK then Close() end
			Add(quest)
		end
	end
	Close()
end

local function SendChanges()
	for _, entry in ipairs(L.order) do
		local now = Progress(entry)
		if sent[entry.id] ~= now then
			local first = sent[entry.id] == nil
			sent[entry.id] = now
			local quest = Quest(entry)
			-- A newly accepted quest is sent even with no progress.
			if quest and (first or now ~= "") then
				local packet = Packet(1)
				packet.quest = quest
				Send(packet, Channel())
			end
		end
	end
	for id in pairs(sent) do
		if not L.entries[id] then
			sent[id] = nil
			local packet = Packet(2)
			packet.id = id
			Send(packet, Channel())
		end
	end
end

local function Remember()
	wipe(sent)
	for _, entry in ipairs(L.order) do sent[entry.id] = Progress(entry) end
end

-- Sends at most one queued message per BETWEEN seconds.
local function Drain()
	local now = GetTime()
	if askAt and now >= askAt then
		askAt = nil
		if Grouped() then
			Send(Packet(11), Channel())
			if tellAll then
				SendLog(Channel())
				Remember()
			end
		end
		tellAll = false
	end
	for name, answer in pairs(answers) do
		if now >= answer.at then
			answers[name] = nil
			if Grouped() then SendLog("WHISPER", answer.to, answer.older) end
		end
	end
	if #queue == 0 or now - lastSent < BETWEEN then return end
	if not Grouped() then
		wipe(queue)
		return
	end
	if C_ChatInfo.InChatMessagingLockdown() then return end
	lastSent = now
	local message = table.remove(queue, 1)
	C_ChatInfo.SendAddonMessage(Wire.PREFIX, message.text, message.channel, message.target)
end

-- Receiving

local function Whole(value)
	return type(value) == "number" and value >= 0 and value == math.floor(value)
end

local function Keep(member, id, goals)
	local complete = #goals > 0
	for _, goal in ipairs(goals) do
		if not goal.done then complete = false end
	end
	member.quests[id] = { goals = goals, complete = complete }
end

local function Take(member, quest)
	if type(quest) ~= "table" or not Whole(quest.id) or type(quest.objectives) ~= "table" then return end
	local goals = {}
	for index, objective in pairs(quest.objectives) do
		if Whole(index) and type(objective) == "table" and Whole(objective.ful) and Whole(objective.req) then
			goals[index] = { have = objective.ful, need = objective.req,
				done = objective.fin == true or (objective.req > 0 and objective.ful >= objective.req),
				about = Whole(objective.id) and objective.id > 0 and objective.id or nil,
				typ = type(objective.typ) == "string" and objective.typ:sub(1, 1) or nil }
		end
	end
	-- A malformed objective leaves a gap: keep only the contiguous run from 1.
	local row = {}
	for index, goal in ipairs(goals) do row[index] = goal end
	Keep(member, quest.id, row)
end

-- Reads a quest in message 12's form at `at` in a list of numbers. Returns where the next begins.
local function TakeRow(member, row, at)
	local id, count = row[at], row[at + 1]
	if not Whole(id) or not Whole(count) or count > 40 then return nil end
	local goals = {}
	at = at + 2
	for index = 1, count do
		local about, letter, have, need = row[at], row[at + 1], row[at + 2], row[at + 3]
		if not Whole(have) or not Whole(need) then return nil end
		goals[index] = { have = have, need = need, done = have == need,
			about = Whole(about) and about > 0 and about or nil,
			typ = Whole(letter) and letter >= 97 and letter <= 122 and string.char(letter) or nil }
		at = at + 4
	end
	Keep(member, id, goals)
	return at
end

local handlers = {
	[1] = function(member, packet) Take(member, packet.quest) end,
	[2] = function(member, packet)
		if Whole(packet.id) then member.quests[packet.id] = nil end
	end,
	[10] = function(member, packet)
		if type(packet.rawQuestList) ~= "table" then return end
		for _, quest in pairs(packet.rawQuestList) do Take(member, quest) end
	end,
	[11] = function(_, packet, name, sender)
		if answers[name] then return end
		local major = type(packet.ver) == "string" and tonumber(packet.ver:match("^(%d+)%.")) or 0
		answers[name] = { at = GetTime() + ANSWER_WAIT, to = sender, older = major <= 5 }
	end,
	[12] = function(member, packet)
		local row = packet[1]
		if type(row) ~= "table" or not Whole(row[1]) then return end
		local at = 2
		for _ = 1, math.min(row[1], 40) do
			at = TakeRow(member, row, at)
			if not at then return end
		end
	end,
	[14] = function(member, packet)
		if type(packet[1]) == "table" then TakeRow(member, packet[1], 1) end
	end,
}

-- Whether `name` is a party member other than the player. UnitIsUnit can be secret.
local function Theirs(name)
	if roster[name] then return true end
	local me = UnitIsUnit(name, "player")
	if issecretvalue(me) or me then return false end
	return UnitInParty(name) == true
end

local function OnMessage(_, _, prefix, text, channel, sender)
	if issecretvalue(prefix) or issecretvalue(text) or issecretvalue(channel) or issecretvalue(sender) then return end
	if prefix ~= Wire.PREFIX or (channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" and channel ~= "WHISPER") or not Grouped() then return end
	local name = Ambiguate(sender, "none")
	if not Theirs(name) then return end
	local whole = Wire.Receive(parts, name .. channel, text)
	local packet = whole and Wire.Decode(whole)
	if not packet or type(packet.msgVer) ~= "number" or math.floor(packet.msgVer) ~= Wire.VERSION then return end
	local handler = handlers[packet.msgId]
	if not handler then return end
	local member = members[name]
	if not member then
		member = { quests = {} }
		members[name] = member
	end
	handler(member, packet, name, sender)
	ns.Refresh()
end

-- The group

local function Forget()
	wipe(members)
	wipe(queue)
	wipe(sent)
	wipe(parts)
	wipe(answers)
	askAt, tellAll = nil, false
end

local function ReadRoster()
	local was, had = {}, next(roster) ~= nil
	for name in pairs(roster) do was[name] = true end
	wipe(roster)
	if IsInGroup() and not IsInRaid() then
		local me = FullName("player")
		for i = 1, GetNumSubgroupMembers() do
			local unit = "party" .. i
			local name = FullName(unit)
			if name and name ~= me then roster[name] = unit end
		end
	end
	local joined = false
	for name in pairs(roster) do
		if not was[name] then joined = true end
	end
	for name in pairs(members) do
		if not roster[name] and not UnitInParty(name) then members[name] = nil end
	end
	if not next(roster) then
		Forget()
	elseif joined and Sharing() then
		-- On joining (or after a reload) also send our log: members already there don't ask.
		askAt = askAt or (GetTime() + ASK_WAIT)
		if not had then tellAll = true end
	end
	ns.Refresh()
end

-- Queries

-- Who else is on a quest: { { name, unit, complete, have, need, finished }, ... }, sorted by name.
-- With `index`, have and need are that objective's; `finished` is that objective or the quest done.
function P.On(id, index)
	local out
	for name, member in pairs(members) do
		local quest = member.quests[id]
		if quest then
			local goal = index and quest.goals[index]
			out = out or {}
			out[#out + 1] = { name = name, unit = roster[name] or name, complete = quest.complete,
				have = goal and goal.have, need = goal and goal.need,
				finished = quest.complete or (goal ~= nil and goal ~= false and goal.done) or false }
		end
	end
	if out then table.sort(out, function(a, b) return a.name < b.name end) end
	return out
end

function P.Any()
	return next(members) ~= nil
end

-- Their objectives on a map

local TOKEN = { m = "c", i = "i", o = "o" }   -- the wire's objective letter to the data's goal kind
local spots = {}             -- "c723:1429" -> the spawns of that goal on that map, x and y in turn

local function Spots(kind, id, map)
	local key = kind .. id .. ":" .. map
	local found = spots[key]
	if not found then
		found = {}
		for _, places in ipairs((ns.Route.GroundOf({ kind = kind, id = id }))) do
			for _, place in ipairs(places) do
				if place.map == map and not place.dungeon then
					for i = 1, #place.points do found[#found + 1] = place.points[i] end
				end
			end
		end
		spots[key] = found
	end
	return found
end

local function Named(kind, id)
	local thing = kind == "i" and ns.Data.Item(id) or ns.Data.Thing(kind == "c" and "n" or "o", id)
	return thing and thing.name or nil
end

-- One mark per open objective of a member's quest that isn't in our own log (ours have marks of their
-- own), where a stop for it would stand (Route.lua's R.BestOf: at the heart of the best camp, as many
-- left as the member has), or at its spawn nearest the player on a map they aren't on; members on the
-- same objective share it. As Pins.lua's other marks: { stop, x, y (shares of the map), kind }.
-- stop.party = { index, what }.
function P.Marks(map)
	local out = {}
	if not map or not Grouped() or not next(members) then return out end
	local W, D = ns.World, ns.Data
	local here = W.map == map and C_Map.GetPlayerMapPosition(map, "player")
	local px, py
	if here then px, py = here:GetXY() end
	local seen = {}
	for _, member in pairs(members) do
		for id, quest in pairs(member.quests) do
			if not quest.complete and not L.Has(id) then
				for index, goal in ipairs(quest.goals) do
					local kind, key = TOKEN[goal.typ or ""], id .. ":" .. index
					if not goal.done and goal.about and kind and not seen[key] then
						seen[key] = true
						local lists, _, from = ns.Route.GroundOf({ kind = kind, id = goal.about })
						local spot = here and ns.Route.BestOf(lists, from, "party" .. key, (goal.need or 1) - (goal.have or 0))
						local x, y
						if spot and spot.map == map then
							x, y = spot.x, spot.y
						else
							local points, least = Spots(kind, goal.about, map), nil
							for i = 1, #points, 2 do
								local far = px and ((points[i] / 10000 - px) ^ 2 + (points[i + 1] / 10000 - py) ^ 2) or i
								if not least or far < least then x, y, least = points[i], points[i + 1], far end
							end
						end
						if x then
							local data = D.Quest(id)
							local stop = { kind = "goal", map = map, x = x, y = y, yards = W.Distance(map, x, y),
								tone = kind == "c" and "kill" or kind == "o" and "gather" or ns.ItemKind(goal.about),
								key = "party" .. key, party = { index = index, what = Named(kind, goal.about) },
								actions = { { kind = "goal", id = id, level = data and data.level or 0,
									title = data and data.name or C_QuestLog.GetTitleForQuestID(id) or "A quest" } } }
							stop.continent, stop.north, stop.west = W.ToWorld(map, x, y)
							out[#out + 1] = { stop = stop, x = x / 10000, y = y / 10000, kind = "goal" }
						end
					end
				end
			end
		end
	end
	-- (Members are kept by name in no order: the marks keep one, so they don't trade places.)
	table.sort(out, function(a, b) return a.stop.key < b.stop.key end)
	return out
end

-- "Clara 3/8", "Clara done", in class color.
function P.Text(who)
	local color
	local _, class = UnitClass(who.unit)
	if class and not issecretvalue(class) then color = C_ClassColor.GetClassColor(class) end
	local name = who.name:match("^[^%s%-]+") or who.name
	if color then name = ("|cff%02x%02x%02x%s|r"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5), name) end
	if who.finished then return name .. " done" end
	if who.have and who.need and who.need > 0 then return ("%s %d/%d"):format(name, who.have, who.need) end
	return name
end

-- Tooltip line under a quest or objective: "Bron done, Clara 3/8".
ns.Tips.AddUnder(function(tip, id, index, indent)
	local others = P.On(id, index)
	if not others then return end
	local texts = {}
	for i, who in ipairs(others) do texts[i] = P.Text(who) end
	ns.Tips.Line(tip, table.concat(texts, ", "), Shy.UI.colors.dim, indent)
end)

local shared = true          -- whether sharing was on when the settings were last applied

function ns.ApplyParty()
	local on = Sharing()
	if not on then
		Forget()
	elseif not shared and next(roster) then
		-- Switched on while grouped: treat as just joined.
		askAt, tellAll = GetTime() + ASK_WAIT, true
	end
	shared = on
end

Shy:On("SHY_LOGIN", function()
	C_ChatInfo.RegisterAddonMessagePrefix(Wire.PREFIX)
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", ReadRoster)
	local messages = CreateFrame("Frame")
	messages:RegisterEvent("CHAT_MSG_ADDON")
	messages:SetScript("OnEvent", OnMessage)
	ns.OnApply(ns.ApplyParty)
	ns.OnRoute(function(rebuilt)
		if rebuilt and Grouped() and next(roster) and not tellAll then SendChanges() end
		Drain()
	end)
end)
