-- Friends and your guild on the map. The game says where someone is only in your group, so each copy of this
-- addon tells where its player is to friends (and, if you let it, guild members) who use it and are looking
-- at their map. Guild members are asked once through the guild ("look" to the guild's channel), friends one by
-- one; a guild member who isn't a friend is answered only while you share with your guild. Opening the map asks
-- every online friend ("look"); a friend who has the asker on their own list, and shares, answers with
-- where they are ("at") as they move, until the asker closes the map ("done") or stops asking. Nothing
-- is sent while nobody looks. Asks go out a few at a time; a friend who never answers is left alone for
-- a while. A character on the friends list is whispered; a Battle.net friend is reached through their
-- game account, on any realm. The list itself is asked of the server (the game fills it only when its
-- own window asks) at login, at each open and now and then while someone looks; a look heard from
-- someone the list doesn't have yet is kept until it does.
--
--   look              ask for where the friend is, for LOOKED seconds
--   done              stop
--   at c n w m        on continent c at north n, west w (yards), on map m; "away" where there is no map position
--
-- Every friend online is a pin: a dot in their class color with their name where they are, fading as
-- their last word ages; without an answer, dim, at the middle of the zone the friends list gives; guild
-- members who don't answer stand together, one badge a zone with how many are there (its hover names them); and
-- out of view, waiting at the map's rim toward them, a caret pointing the way. Its hover says who, where
-- and how far (the dial turns toward them); a click whispers (at the rim: flies the map to them), a
-- right click offers the rest (invite, send them your pin or ask them to meet you where you stand, follow
-- them with the game's waypoint arrow, show them).

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local C = UI.colors

local Friends = {}
ns.Friends = Friends

local ASK = 20              -- seconds between asks while the map is open
local LOOKED = 45           -- seconds an ask holds for
local SAY = 2               -- seconds between answers while moving
local STILL = 12            -- ... and while standing
local MOVED = 3             -- yards that count as moving
local STALE = 30            -- seconds a friend's last place is shown for
local FADE = 10             -- ... the last of which it fades through
local QUIET = 300           -- seconds a friend who never answered is not asked
local FRESH = 60            -- seconds between asking the server for the friends list
local SOON = 5              -- ... at the least, when a stranger looks
local PACE = 0.25           -- seconds between batches of messages
local BATCH = 3
local DOT = 14
local BADGE = 18            -- the guild's badge for a zone
local WORLD = 947           -- the map every zone lies under

local DIM = 0.55            -- alpha of a friend placed by the list alone
local WAITING = 0.8         -- ... and of one waiting at the rim
local RIM_IN = 24           -- how far inside the port's edge a waiting pin stands
local CARET = 10            -- the caret pointing out from a waiting pin

local online = {}           -- name -> { name, tell, bnet, account, guid, class, className, level, area, afk, dnd, note,
                            --   friend (on the friends list), guild (in your guild) }
local byAccount = {}        -- Battle.net game account -> name
local lookers = {}          -- name -> until when they look at our place
local places = {}           -- name -> { c, n, w, map, at }
local asked = {}            -- name -> { at, answered, count }
local pending = {}          -- name or game account -> when a look came from someone not listed yet
local queue = {}
local pins = {}
local last = { at = 0 }     -- what we last said
local askedAt, freshAt = 0, -FRESH
local followed              -- the friend the game's waypoint arrow follows
local set                   -- the waypoint we last set for them: { map, x, y }
local rims = {}             -- the pins waiting at the rim
local badges = {}           -- the guild's badges, one a zone
local ticker
local Wake, Follow, Guild   -- below

-- A name as the friends list and a whisper's sender come to the same key. Names are never taken apart
-- (a first name and a surname are one name); a whisper goes to the name the list gives.
local function Short(name)
	if not name or issecretvalue(name) then return nil end
	return Ambiguate(name, "none")
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

local CLASSES = {}
for i = 1, GetNumClasses() do
	local name, file = GetClassInfo(i)
	if name then CLASSES[name] = file end
end

-- The friends list

local function Entry(name)
	local e = online[name]
	if not e then
		e = { name = name }
		online[name] = e
	end
	return e
end

local function Pending()
	local now = GetTime()
	for who, at in pairs(pending) do
		local name = type(who) == "number" and byAccount[who] or who
		if now - at > LOOKED then
			pending[who] = nil
		elseif name and online[name] then
			pending[who] = nil
			Friends.Heard("look", name, "WHISPER")
		end
	end
end

-- Your guild, as its club has it (withheld in some fights: then those read before stand): every member online
-- in the game but you, joined to a friend's entry where they are one.
local guildmates = {}
local function ReadGuild()
	if not (T.db.guild and IsInGuild()) then
		wipe(guildmates)
		return
	end
	local club = Plain(C_Club.GetGuildClubId())
	local ids = club and Given(C_Club.GetClubMembers(club))
	if not ids then return end
	local P = Enum.ClubMemberPresence
	local list = {}
	for _, id in ipairs(ids) do
		local info = Given(C_Club.GetMemberInfo(club, id))
		local full = info and Plain(info.name)
		local presence = info and Plain(info.presence)
		if type(full) == "string" and full ~= "" and info.isSelf ~= true and presence and presence ~= P.Offline
			and presence ~= P.Unknown and presence ~= P.OnlineMobile then
			local classID = Plain(info.classID)
			local class = classID and C_CreatureInfo.GetClassInfo(classID)
			list[#list + 1] = { full = full, name = Short(full), level = Plain(info.level), zone = Plain(info.zone),
				class = class and class.classFile, className = class and class.className, note = Plain(info.memberNote) }
		end
	end
	guildmates = list
end

Guild = function()
	for _, m in ipairs(guildmates) do
		if m.name then
			local e = Entry(m.name)
			e.guild = true
			e.tell = e.tell or m.full
			e.level, e.class, e.className = e.level or m.level, e.class or m.class, e.className or m.className
			if not e.area or e.area == "" then e.area = m.zone end
			e.note = e.note or m.note
		end
	end
end

local function Roster()
	ReadGuild()
	wipe(online)
	wipe(byAccount)
	for i = 1, C_FriendList.GetNumFriends() or 0 do
		local info = C_FriendList.GetFriendInfoByIndex(i)
		local name = info and info.connected and Short(info.name)
		if name then
			local e = Entry(name)
			e.friend = true
			e.tell, e.guid, e.level = info.name, Plain(info.guid), Plain(info.level)
			e.className, e.area, e.note = Plain(info.className), Plain(info.area), Plain(info.notes)
			e.afk, e.dnd = Plain(info.afk) == true, Plain(info.dnd) == true
			e.class = e.className and CLASSES[e.className]
		end
	end
	if C_BattleNet.IsBattleNetFriendsListEnabled() and BNConnected() then
		for i = 1, BNGetNumFriends() or 0 do
			local account = C_BattleNet.GetFriendAccountInfo(i)
			local game = account and account.gameAccountInfo
			local name = game and game.isOnline and game.clientProgram == BNET_CLIENT_WOW
				and game.wowProjectID == WOW_PROJECT_ID and game.isInCurrentRegion and Short(game.characterName)
			if name then
				local e = Entry(name)
				e.friend = true
				e.bnet, e.account = game.gameAccountID, Plain(account.accountName)
				e.bnetAccount = Plain(account.bnetAccountID)
				e.guid = e.guid or Plain(game.playerGuid)
				e.level = e.level or Plain(game.characterLevel)
				e.className = e.className or Plain(game.className)
				e.class = e.class or Plain(game.classFilename)
				e.area = e.area or Plain(game.areaName)
				e.note = e.note or Plain(account.note)
				e.afk = e.afk or Plain(account.isAFK) == true or Plain(game.isGameAFK) == true
				e.dnd = e.dnd or Plain(account.isDND) == true or Plain(game.isGameBusy) == true
				byAccount[game.gameAccountID] = name
			end
		end
	end
	Guild()
	Pending()
end

-- Asks the server for the list (the game fills it only when its own window asks).
local function Fresh(soon)
	local now = GetTime()
	if now - freshAt < (soon and SOON or FRESH) then return end
	freshAt = now
	C_FriendList.ShowFriends()
	if T.db.guild and IsInGuild() then C_GuildInfo.GuildRoster() end
end

-- Messages

local function Send(text, to)
	queue[#queue + 1] = { text, to }
end

local function Drain()
	for _ = 1, BATCH do
		local item = table.remove(queue, 1)
		if not item then return end
		local friend = online[item[2]]
		if friend then
			if friend.bnet then
				T:SendBNComm(item[1], friend.bnet)
			elseif friend.tell then
				T:SendComm(item[1], "WHISPER", friend.tell)
			end
		end
	end
end

-- Where we are, as the world has it, and the map we are on.
local function Here()
	local continent, n, w = Shy.Here(true)
	if not continent then return nil end
	return continent, n, w, (Shy.HereOn())
end

-- Whether someone asking is answered: a friend while you share, a guild member while you share with your guild.
local function Answered(name)
	local e = online[name]
	return e ~= nil and ((e.friend and T.db.share) or (e.guild and T.db.shareGuild)) == true
end

local function Answer(force)
	local now, any = GetTime(), false
	for name, until_ in pairs(lookers) do
		if until_ < now or not Answered(name) then lookers[name] = nil else any = true end
	end
	if not any then return end
	local c, n, w, map = Here()
	local moved = c and (c ~= last.c or math.abs(n - last.n) + math.abs(w - last.w) > MOVED)
	local due = now - last.at >= (moved and SAY or STILL)
	if not (force or due) then return end
	local text = c and ("at\t%d\t%.1f\t%.1f\t%d"):format(c, n, w, map) or "away"
	if not force and text == last.text and now - last.at < STILL then return end
	last.c, last.n, last.w, last.at, last.text = c, n, w, now, text
	for name in pairs(lookers) do Send(text, name) end
end

-- Asks every online friend, or one.
local function Ask(only)
	local now = GetTime()
	local guild = false
	if not only then askedAt = now end
	for name, e in pairs(online) do
		if not only and e.guild and not e.friend then
			-- (Your guild is asked once, through its channel.)
			guild = guild or T.db.guild
		elseif only == name or (not only and e.friend and T.db.friends) then
			local a = asked[name]
			-- Asked twice and never answered: left alone for a while.
			local quiet = a and not a.answered and a.count >= 2 and now - a.at < QUIET
			if not quiet then
				asked[name] = { at = now, answered = a and a.answered, count = (a and not a.answered and a.count or 0) + 1 }
				Send("look", name)
			end
		end
	end
	if guild then T:SendComm("look", "GUILD") end
end

local function Done()
	for name, a in pairs(asked) do
		if a.answered and online[name] and name ~= followed then Send("done", name) end
	end
end

local function Heard(msg, name)
	local kind, c, n, w, m = strsplit("\t", msg)
	if kind == "look" then
		if Answered(name) then
			lookers[name] = GetTime() + LOOKED
			Answer(true)
			Wake()
		end
	elseif kind == "done" then
		lookers[name] = nil
	elseif kind == "at" or kind == "away" then
		local a = asked[name]
		if a then a.answered = true end
		if kind == "at" then
			places[name] = { c = tonumber(c), n = tonumber(n), w = tonumber(w), map = tonumber(m), at = GetTime() }
		else
			places[name] = nil
		end
		Follow(name)
	end
end

-- Someone the list doesn't have yet: the list is asked for again, and their look kept until it comes.
local function Stranger(who, msg)
	if msg == "look" then
		pending[who] = GetTime()
		Fresh(true)
		Wake()
	end
end

function Friends.Heard(msg, sender, channel)
	local name = Short(sender)
	if not name then return end
	if channel == "GUILD" then
		-- (Only a look comes through the guild; one from a member not read yet waits for the next.)
		local e = online[name]
		if msg == "look" and e and e.guild and not Shy.IsMe(sender) then Heard(msg, name) end
		return
	end
	if channel ~= "WHISPER" then return end
	if not online[name] then return Stranger(name, msg) end
	Heard(msg, name)
end

function Friends.HeardBN(msg, account)
	local name = byAccount[account]
	if not name then return Stranger(account, msg) end
	Heard(msg, name)
end

-- Where a friend is, as words and as the map shown has it

-- A friend's place as shares of a map (the one shown, or `map`).
local function OnShown(at, map)
	map = map or View.Map()
	if not (map and at and at.c) then return nil end
	local x, y = ns.OnMap(map, at.c, at.n, at.w)
	if not x then
		local _, pos = C_Map.GetMapPosFromWorldPos(at.c, CreateVector2D(at.n, at.w), map)
		if pos then x, y = pos:GetXY() end
	end
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
	return nil
end

local function Placed(name)
	local at = places[name]
	return at ~= nil and GetTime() - at.at < STALE and online[name] ~= nil
end

-- The zone they answered from, else the one the friends list gives.
local function Where(name)
	local at = places[name]
	local info = at and at.map and C_Map.GetMapInfo(at.map)
	if info and info.name then return info.name end
	local e = online[name]
	local area = e and e.area
	if area and area ~= "" then return area end
	return nil
end

local function Yards(at)
	local c, n, w = Here()
	if not (c and at and at.c == c) then return nil end
	return math.sqrt((at.n - n) ^ 2 + (at.w - w) ^ 2)
end

-- How to turn an up arrow toward them (counter-clockwise radians), from where we face.
local function Turn(at)
	local facing = GetPlayerFacing()
	local c, n, w = Here()
	if not (facing and c and at and at.c == c) then return nil end
	return math.atan2(at.w - w, at.n - n) - facing
end

local function Ago(seconds)
	if seconds < 60 then return ("%d s"):format(math.floor(seconds)) end
	return ("%d min"):format(math.floor(seconds / 60))
end

-- Every zone by name (each continent's), for a friend the list places but who doesn't answer.
local zonesByName
local function ZoneNamed(name)
	if not zonesByName then
		zonesByName = {}
		for _, continent in ipairs(C_Map.GetMapChildrenInfo(WORLD, Enum.UIMapType.Continent) or {}) do
			if continent.mapType == Enum.UIMapType.Continent then
				for _, zone in ipairs(C_Map.GetMapChildrenInfo(continent.mapID, Enum.UIMapType.Zone) or {}) do
					if zone.mapType == Enum.UIMapType.Zone and zone.name and not zonesByName[zone.name] then
						zonesByName[zone.name] = zone.mapID
					end
				end
			end
		end
	end
	return zonesByName[name]
end

-- What a friend can be asked for

local function Whisper(name)
	local e = online[name]
	if not e then return end
	if e.tell then
		ChatFrameUtil.SendTell(e.tell)
	elseif e.account then
		ChatFrameUtil.SendBNetTell(e.account)
	end
end

local function Invite(name)
	local e = online[name]
	if not e then return end
	if e.tell then
		C_PartyInfo.InviteUnit(e.tell)
	elseif e.bnet then
		C_BattleNet.InviteFriend(e.bnet)
	end
end

-- The map flies to them (to their zone, when they don't answer but the list places them).
local function GoTo(name)
	if not View.IsOpen() then return end
	local at = Placed(name) and places[name]
	local function Land()
		local x, y = OnShown(at)
		if x then View.Glide(x, y, math.max(View.Scale() / View.Fit(), 2.5)) end
	end
	if at and at.c then
		local map = at.map or View.Map()
		if map == View.Map() then
			Land()
		elseif not View.Fly(map, Land) then
			View.Show(map, "into")
			Land()
		end
		return
	end
	local e = online[name]
	local zone = e and e.area and ZoneNamed(e.area)
	if zone and zone ~= View.Map() then View.Fly(zone) end
end

-- Following: the game's waypoint arrow stands on them, moved as they move; asked for while followed
-- even with the map closed. Stops when they go quiet or offline, or when the pin is moved or taken away.
local function Unfollow(why)
	if not followed then return end
	local name = followed
	followed, set = nil, nil
	if why then T:Print(("no longer following %s: %s."):format(name, why)) end
end

Follow = function(name)
	if name ~= followed then return end
	local at = places[name]
	local map = at and at.map
	if not at then return Unfollow("they have no map position") end
	if not (map and at.c) then return Unfollow("their copy of ShyMaps doesn't say which map they are on") end
	if not C_Map.CanSetUserWaypointOnMap(map) then return Unfollow("you can't put a pin on that map") end
	local x, y = OnShown(at, map)
	if not x then return Unfollow("they are off the map") end
	if set and set.map == map and math.abs(set.x - x) < 1e-4 and math.abs(set.y - y) < 1e-4 then return end
	set = { map = map, x = x, y = y }
	Shy.Waypoint.Set(map, x, y, true)
end

function Friends.Follow(name)
	if followed == name then
		Unfollow()
		return false
	end
	followed, set = name, nil
	Follow(name)
	if followed then
		Ask(name)
		Wake()
	end
	return followed ~= nil
end

function Friends.Following()
	return followed
end

-- The pin went elsewhere, or away: whoever moved it has the arrow now.
local function PinMoved()
	if not (followed and set) or Shy.UI.PinBorrowed() then return end
	local point = C_Map.GetUserWaypoint()
	local pos = point and point.position
	if not (pos and point.uiMapID == set.map and math.abs(pos.x - set.x) < 1e-3 and math.abs(pos.y - set.y) < 1e-3) then
		Unfollow()
	end
end

-- The hover, the click and the menu, for a pin or a row (its `name`)

local function Tip(owner)
	local name = owner.name
	local e, at = online[name], places[name]
	if not (name and e) then return end
	local color = e.class and C_ClassColor.GetClassColor(e.class)
	local content = { title = name }
	if color then content.titleColor = { color.r, color.g, color.b } end
	if e.level and e.className then content.sub = ("Level %d %s"):format(e.level, e.className) end
	local rows = {}
	local where = Where(name)
	if where then rows[#rows + 1] = { glyph = "go", text = where } end
	if at and at.c and Yards(at) then
		content.dial = { yards = function() return Yards(at) end, turn = function() return Turn(at) end }
	end
	if e.afk then
		rows[#rows + 1] = { glyph = "clock", text = "Away from the keyboard", quiet = true }
	elseif e.dnd then
		rows[#rows + 1] = { glyph = "clock", text = "Busy", quiet = true }
	end
	if e.guild and not e.friend then rows[#rows + 1] = { glyph = "home", text = "In your guild", quiet = true } end
	if e.note and e.note ~= "" then rows[#rows + 1] = { glyph = "note", text = e.note, quiet = true } end
	if lookers[name] then rows[#rows + 1] = { glyph = "star", text = "Looking at your map too" } end
	if followed == name then rows[#rows + 1] = { glyph = "up", text = "The arrow follows them", lit = true } end
	local age = at and GetTime() - at.at
	if age and age > FADE then rows[#rows + 1] = { glyph = "clock", text = "Last heard " .. Ago(age) .. " ago", quiet = true } end
	if not at and not UnitInParty(name) then
		rows[#rows + 1] = { text = "Somewhere in their zone: they don't use ShyMaps, or don't share where they are", quiet = true }
	end
	if #rows > 0 then content.sections = { { rows = rows } } end
	content.hints = { { "left", owner.rim and "Show them" or "Whisper" }, { "right", "More" } }
	Shy.Hover.Show(owner, content)
end

-- Who a place can be shared with (Shy.Way.Share): how a friend's copy is reached, a whisper or their
-- Battle.net game account (and the account itself, for a whisper to a friend with no copy).
local function To(name)
	local e = online[name]
	if not e then return nil end
	if e.bnet then return { bnet = e.bnet, account = e.bnetAccount, name = name } end
	if e.tell then return { tell = e.tell, name = name } end
	return nil
end

-- Every friend online as someone to share a place with: { label, class, uses, to }; uses: their copy has
-- answered this session (they stand first; the rest get the pin as a whisper if no copy answers).
function Friends.Targets()
	local list = {}
	for name, e in pairs(online) do
		local to = e.friend and To(name)
		if to then
			local a = asked[name]
			list[#list + 1] = { label = name, class = e.class, uses = (a and a.answered) == true or Placed(name), to = to }
		end
	end
	-- Those whose copy answers first, each by name.
	table.sort(list, function(a, b)
		if a.uses ~= b.uses then return a.uses end
		return a.label < b.label
	end)
	return list
end

-- A friend's rows for sharing a place with them: your pin, and where you stand. None while ShyWay is off.
local function ShareRows(items, name)
	local share = Shy.Way.Share
	if Shy.Way.missing or not (share and share.Send) then return end
	local to = To(name)
	if not to then return end
	local pin = share.Pin()
	items[#items + 1] = { text = "Send them my pin", icon = UI.MenuGlyph("share"),
		tip = "They get your map pin as a route they can accept or decline.",
		disabled = not pin, detail = not pin and "no pin" or nil,
		click = function() share.Send(share.Pin(), to) end }
	items[#items + 1] = { text = "Ask them to meet me here", icon = UI.MenuGlyph("share"),
		tip = "They get where you stand now as a route they can accept or decline.",
		click = function() share.Send(share.Here(), to) end }
	items[#items + 1] = { divider = true }
end

local function Menu(owner, name)
	local e, at = online[name], places[name]
	if not e then return end
	local following = followed == name
	local items = {
		{ heading = name },
		{ text = "Whisper", click = function() Whisper(name) end },
		{ text = "Invite to group", click = function() Invite(name) end },
		{ divider = true },
	}
	ShareRows(items, name)
	for _, item in ipairs({
		{ text = following and "Stop following" or "Follow with the arrow",
			tip = "The game's waypoint arrow points at them and moves with them, until you move the pin or they go quiet.",
			disabled = not following and not (at and at.map), detail = (not following and not (at and at.map)) and "no position" or nil,
			click = function() Friends.Follow(name) end },
		{ text = "Show on the map", disabled = not (at or (e.area and ZoneNamed(e.area))), click = function() GoTo(name) end },
		{ divider = true },
		{ text = "Copy their name", click = function() UI.ShowCopyBox("Their name", e.tell or name) end },
	}) do
		items[#items + 1] = item
	end
	UI.Menu(owner, items, { side = "cursor" })
end

local function Click(owner, button)
	if not owner.name then return end
	if button == "RightButton" then
		Menu(owner, owner.name)
	elseif owner.rim then
		GoTo(owner.name)
	else
		Whisper(owner.name)
	end
end

-- Every friend online: those who answer first, each by name.
local function Names()
	local list = {}
	for name in pairs(online) do list[#list + 1] = name end
	table.sort(list, function(a, b)
		local fa, fb = Placed(a), Placed(b)
		if fa ~= fb then return fa end
		return a < b
	end)
	return list
end

-- On the map

local function Pin(i)
	local pin = pins[i]
	if not pin then
		pin = View.Pin("PIN_FRAME_LEVEL_GROUP_MEMBER", DOT, Tip, Click)
		pin.icon:SetAtlas("WhiteCircle-RaidBlips")
		pin.ring = pin:CreateTexture(nil, "BACKGROUND")
		pin.ring:SetTexture(Shy.MEDIA .. "Glow")
		pin.ring:SetPoint("CENTER")
		pin.ring:SetSize(DOT * 2.4, DOT * 2.4)
		pin.label = pin:CreateFontString(nil, "OVERLAY")
		pin.label:SetFontObject(UI.NameFont(10, "OUTLINE"))
		pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
		pins[i] = pin
	end
	return pin
end

-- A pin waiting at the rim: over the window (never on the overlay), the same dot and name, a caret pointing out.
local function RimPin(i)
	local pin = rims[i]
	if not pin then
		pin = CreateFrame("Button", nil, View.Chrome())
		pin:SetSize(DOT, DOT)
		pin:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 100)
		pin:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		pin.rim = true
		pin.icon = pin:CreateTexture(nil, "ARTWORK")
		pin.icon:SetAtlas("WhiteCircle-RaidBlips")
		pin.icon:SetAllPoints()
		pin.ring = pin:CreateTexture(nil, "BACKGROUND")
		pin.ring:SetTexture(Shy.MEDIA .. "Glow")
		pin.ring:SetPoint("CENTER")
		pin.ring:SetSize(DOT * 2.4, DOT * 2.4)
		pin.caret = pin:CreateTexture(nil, "OVERLAY")
		pin.caret:SetTexture(Shy.MEDIA .. "GlyphCaret")
		pin.caret:SetSize(CARET, CARET)
		pin.label = pin:CreateFontString(nil, "OVERLAY")
		pin.label:SetFontObject(UI.NameFont(10, "OUTLINE"))
		pin:SetScript("OnEnter", Tip)
		pin:SetScript("OnLeave", function(self) UI.TipHide(self) end)
		pin:SetScript("OnClick", Click)
		pin:Hide()
		rims[i] = pin
	end
	return pin
end

-- Stands a waiting pin where the line from the port's middle toward (px, py), port units, meets the
-- rect RIM_IN inside its edge; the caret outward, the name inward.
local function AtRim(pin, px, py, pw, ph)
	local dx, dy = px - pw / 2, py - ph / 2
	local t = math.huge
	if dx ~= 0 then t = math.min(t, (pw / 2 - RIM_IN) / math.abs(dx)) end
	if dy ~= 0 then t = math.min(t, (ph / 2 - RIM_IN) / math.abs(dy)) end
	if t == math.huge then return false end
	local rx, ry = pw / 2 + dx * t, ph / 2 + dy * t
	pin.rx, pin.ry = rx, ry
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", View.Port(), "TOPLEFT", rx, -ry)
	local len = math.sqrt(dx * dx + dy * dy)
	local ux, uy = dx / len, dy / len
	local reach = DOT / 2 + CARET / 2 + 1
	pin.caret:ClearAllPoints()
	pin.caret:SetPoint("CENTER", pin, "CENTER", ux * reach, -uy * reach)
	pin.caret:SetRotation(math.atan2(dx, dy))
	pin.label:ClearAllPoints()
	if math.abs(ux) > math.abs(uy) then
		if ux > 0 then pin.label:SetPoint("RIGHT", pin, "LEFT", -3, 0) else pin.label:SetPoint("LEFT", pin, "RIGHT", 3, 0) end
	elseif uy > 0 then
		pin.label:SetPoint("BOTTOM", pin, "TOP", 0, 2)
	else
		pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -2)
	end
	return true
end

-- A friend's whereabouts as shares of the map shown, in view or not: their place, else the middle of
-- the zone the friends list gives; nil on another world.
local function Whereabouts(name)
	local map = View.Map()
	if not map then return nil end
	local at = Placed(name) and places[name]
	if at then
		if not at.c then return nil end
		return ns.OnMap(map, at.c, at.n, at.w)
	end
	local e = online[name]
	local zone = e and e.area and ZoneNamed(e.area)
	if not zone then return nil end
	local world, n0, w0, n1, w1 = View.World(zone)
	if not world then return nil end
	return ns.OnMap(map, world, (n0 + n1) / 2, (w0 + w1) / 2)
end

local function Paint(pin, name, r, g, b)
	pin.name = name
	pin.icon:SetVertexColor(r, g, b, 1)
	pin.ring:SetVertexColor(r, g, b, 0.5)
	if pin.caret then pin.caret:SetVertexColor(r, g, b, 1) end
	pin.label:SetText(name)
	pin.label:SetTextColor(r, g, b)
end

-- The guild's badge for a zone: a quiet dot with how many of your guild are there, its hover naming them.
local function BadgeTip(badge)
	local rows = {}
	for _, name in ipairs(badge.names) do
		local e = online[name]
		local color = e and e.class and C_ClassColor.GetClassColor(e.class)
		rows[#rows + 1] = { text = name, name = true, color = color and { color.r, color.g, color.b } or nil,
			right = e and e.level and tostring(e.level) or nil }
	end
	Shy.Hover.Show(badge, { title = badge.zone, sub = #badge.names == 1 and "1 of your guild" or (#badge.names .. " of your guild"),
		sections = { { rows = rows } } })
end

local function BadgeClick(badge, button)
	if button == "LeftButton" and badge.map and badge.map ~= View.Map() then View.Fly(badge.map) end
end

local function Badge(i)
	local badge = badges[i]
	if not badge then
		badge = View.Pin("PIN_FRAME_LEVEL_GROUP_MEMBER", BADGE, BadgeTip, BadgeClick)
		badge.icon:SetAtlas("WhiteCircle-RaidBlips")
		badge.count = badge:CreateFontString(nil, "OVERLAY")
		badge.count:SetFontObject(UI.NameFont(10, "OUTLINE"))
		badge.count:SetPoint("CENTER", 0, 0)
		badges[i] = badge
	end
	return badge
end

-- Guild members who don't answer (and aren't friends), by the zone the guild gives: { [zone map] = { names } }.
local function Gathered()
	local by = {}
	for name, e in pairs(online) do
		if e.guild and not e.friend and not Placed(name) and not (UnitInParty(name) or UnitInRaid(name)) then
			local zone = e.area and ZoneNamed(e.area)
			if zone then
				by[zone] = by[zone] or {}
				table.insert(by[zone], name)
			end
		end
	end
	for _, names in pairs(by) do table.sort(names) end
	return by
end

-- Every friend online, each beat and on every pan and zoom: on the canvas in view, else at the rim; the guild's
-- quiet ones as their zones' badges.
local function Draw()
	local map, port = View.Map(), View.Port()
	local used, waiting, gathered, now = 0, 0, 0, GetTime()
	local inside = ns.Inside()
	if map and port and View.IsOpen() and T.db.guild and not inside then
		local tint = C.dim
		for zone, names in pairs(Gathered()) do
			local world, n0, w0, n1, w1 = View.World(zone)
			local x, y
			if world then x, y = ns.OnMap(map, world, (n0 + n1) / 2, (w0 + w1) / 2) end
			if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
				gathered = gathered + 1
				local badge = Badge(gathered)
				local info = C_Map.GetMapInfo(zone)
				badge.names, badge.map, badge.zone = names, zone, info and info.name or ""
				badge.icon:SetVertexColor(tint[1], tint[2], tint[3], 1)
				badge.count:SetText(tostring(#names))
				badge:SetAlpha(DIM)
				View.Stand(badge, x, y)
			end
		end
	end
	if map and port and View.IsOpen() and (T.db.friends or T.db.guild) and not inside then
		local pw, ph = port:GetWidth(), port:GetHeight()
		for _, name in ipairs(Names()) do
			local e = online[name]
			local shown = (e.friend and T.db.friends) or (e.guild and T.db.guild and Placed(name))
			if shown and not (UnitInParty(name) or UnitInRaid(name)) then
				local x, y = Whereabouts(name)
				if x then
					local e = online[name]
					local color = e.class and C_ClassColor.GetClassColor(e.class)
					local r, g, b = 1, 1, 1
					if color then r, g, b = color.r, color.g, color.b end
					local lit = Placed(name)
					local alpha = lit and 1 or DIM
					if lit then
						local age = now - places[name].at
						if age > STALE - FADE then alpha = math.max(0.25, (STALE - age) / FADE) end
					end
					local px, py = View.ToPort(x, y)
					local pin
					if px >= 0 and px <= pw and py >= 0 and py <= ph then
						used = used + 1
						pin = Pin(used)
						View.Stand(pin, x, y)
					else
						pin = RimPin(waiting + 1)
						if AtRim(pin, px, py, pw, ph) then
							waiting = waiting + 1
							alpha = alpha * WAITING
							pin:Show()
						else
							pin = nil
						end
					end
					if pin then
						Paint(pin, name, r, g, b)
						pin:SetAlpha(alpha)
					end
				end
			end
		end
	end
	for i = used + 1, #pins do pins[i]:Hide() end
	for i = waiting + 1, #rims do rims[i]:Hide() end
	for i = gathered + 1, #badges do badges[i]:Hide() end
end

-- The plate

-- The beat: answers while someone looks, asks while our map is open (or someone is followed), the
-- paced queue, and the map's drawing.

local function Beat()
	Answer(false)
	local now = GetTime()
	if View.IsOpen() and (T.db.friends or T.db.guild) then
		if now - askedAt >= ASK then Ask() end
		Fresh()
	elseif followed then
		if now - askedAt >= ASK then
			askedAt = now
			Ask(followed)
		end
	end
	if next(lookers) then Fresh() end
	if next(pending) then Fresh(true) end
	if followed and not Placed(followed) then Unfollow("they went quiet") end
	Drain()
	if View.IsOpen() then Draw() end
	local idle = #queue == 0 and next(lookers) == nil and next(pending) == nil and not View.IsOpen() and not followed
	if idle and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

Wake = function()
	if not ticker then ticker = C_Timer.NewTicker(PACE, Beat) end
end

-- What is going on, for the copy box (/shymaps friends).
function Friends.Report()
	local now = GetTime()
	local lines = { "ShyMaps friends", "" }
	local function Add(fmt, ...) lines[#lines + 1] = fmt:format(...) end
	Add("friends on the map: %s   share where I am: %s   guild on the map: %s   share with the guild: %s   map open: %s",
		tostring(T.db.friends), tostring(T.db.share), tostring(T.db.guild), tostring(T.db.shareGuild), tostring(View.IsOpen()))
	Add("Battle.net list: %s   list asked for %s ago   beat: %s   queued: %d   following: %s",
		tostring(C_BattleNet.IsBattleNetFriendsListEnabled() and BNConnected()), Ago(now - freshAt),
		ticker and "running" or "idle", #queue, followed or "nobody")
	Add("last said: %s (%s ago)", last.text or "nothing", Ago(now - last.at))
	lines[#lines + 1] = ""
	local count = 0
	for _, name in ipairs(Names()) do
		count = count + 1
		local e, a, at = online[name], asked[name], places[name]
		local how = (e.bnet and ("Battle.net " .. tostring(e.bnet)) or ("whisper " .. tostring(e.tell)))
			.. (e.friend and "" or ", guild")
		local askedSay = a and ("asked %d (%s ago, %s)"):format(a.count, Ago(now - a.at), a.answered and "answered" or "no answer") or "not asked"
		local placeSay = at and ("at %s (%s ago)"):format(Where(name) or "?", Ago(now - at.at)) or "no place"
		Add("%s: %s; %s %s; %s; %s; %s", name, how, tostring(e.level), tostring(e.className), askedSay, placeSay,
			lookers[name] and "looks at us" or "not looking")
	end
	if count == 0 then lines[#lines + 1] = "nobody online on the friends list" end
	local waiting = 0
	for _ in pairs(pending) do waiting = waiting + 1 end
	if waiting > 0 then Add("%d look(s) from someone not on the list yet", waiting) end
	return table.concat(lines, "\n")
end

-- For other addons (Shy.addons.Maps:Friends()): every friend online, { name, level, className, class, zone,
-- map, x, y, placed }: on `map` at x, y (shares) where they answered from, else at the middle of the zone
-- the friends list gives (placed false); no map when neither is known.
function Friends.List()
	local list = {}
	for _, name in ipairs(Names()) do
		local e = online[name]
		if e.friend then
			local entry = { name = name, level = e.level, className = e.className, class = e.class, placed = Placed(name), zone = Where(name) }
			local at = entry.placed and places[name]
			if at then
				if at.c and at.map then entry.map, entry.x, entry.y = at.map, OnShown(at, at.map) end
				if not entry.x then entry.map = nil end
			else
				local zone = e.area and ZoneNamed(e.area)
				if zone then entry.map, entry.x, entry.y = zone, 0.5, 0.5 end
			end
			list[#list + 1] = entry
		end
	end
	return list
end

ns.Layer({
	id = "friends",
	later = true,
	Open = function()
		if not (T.db.friends or T.db.guild) then return end
		Roster()
		Fresh()
		askedAt = 0
		Wake()
	end,
	Close = function()
		Done()
		Draw()
	end,
	Map = Draw,
	-- (A zoom or a pan moves the rim against them: laid again, cheaply.)
	Scale = Draw,
	Pan = Draw,
	Use = function(on)
		if not on then Draw() end
	end,
})

ns.OnApply(function()
	Roster()
	if View.IsOpen() then
		if T.db.friends or T.db.guild then Wake() end
		Draw()
	end
	for name in pairs(lookers) do
		if not Answered(name) then lookers[name] = nil end
	end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("FRIENDLIST_UPDATE")
events:RegisterEvent("BN_CONNECTED")
events:RegisterEvent("BN_DISCONNECTED")
events:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
events:RegisterEvent("BN_FRIEND_INFO_CHANGED")
events:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
events:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:RegisterEvent("GUILD_ROSTER_UPDATE")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		Fresh()
	elseif event == "USER_WAYPOINT_UPDATED" then
		PinMoved()
	else
		Roster()
		if View.IsOpen() then Draw() end
	end
end)
