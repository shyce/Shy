-- Who search for the run's level range, and Group Finder search results (every
-- listing of one category: the Browse tab and the start screen show them, solo
-- ones are candidates). Both searches need a hardware event: call only from a
-- click or key. The server returns at most 50 Who results and drops searches
-- sent too close together. Blizzard's Who list opens on any WHO_LIST_UPDATE, so
-- it is unregistered while our own search is pending.

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local S = {}
ns.Search = S

local WHO_WAIT = 5        -- seconds between Who searches
local WHO_TIMEOUT = 6     -- no answer by then: the server dropped it
local WHO_KEEP = 600      -- seconds a Who result stays listed
local FINDER_TIMEOUT = 8  -- no Group Finder answer by then: re-enable the buttons
local LOOK_WAIT = 5       -- seconds between Group Finder searches
local LOOK_FRESH = 60     -- a search of the same category within this many seconds is skipped unless asked for

S.who = { state = "idle", list = {}, found = 0, total = 0 }   -- state: idle | searching | done | silent
-- state: idle | searching | done | failed; kind: the category searched; when: time() the results came
S.finder = { state = "idle", all = {}, kind = nil, when = nil }

-- Who

local whoSent, whoPending = -WHO_WAIT, false
local finderSent = -LOOK_WAIT

local function BlizzardWhoList()
	return LFGWhoListFrame   -- exists once the Group Finder has loaded
end

local function ReleaseWho()
	whoPending = false
	local theirs = BlizzardWhoList()
	if theirs then theirs:RegisterEvent("WHO_LIST_UPDATE") end
	C_FriendList.SetWhoToUi(theirs ~= nil and theirs:IsShown())
end

local function OnWho()
	if not whoPending then return end
	-- Results accumulate across searches (tanks, then healers...).
	local who = S.who
	local byName = {}
	for _, c in ipairs(who.list) do byName[c.name] = c end
	local count, total = C_FriendList.GetNumWhoResults()
	for i = 1, count do
		local info = C_FriendList.GetWhoInfo(i)
		if info then
			local name = ns.Short(info.fullName)
			local c = byName[name]
			if not c then
				c = { name = name }
				byName[name] = c
				who.list[#who.list + 1] = c
			end
			c.class, c.level, c.area = info.filename, info.level, info.area
			c.guild = info.fullGuildName ~= "" and info.fullGuildName or nil
			c.busy = D.IsInstanceArea(info.area)
			c.seen = time()
		end
	end
	for i = #who.list, 1, -1 do
		if time() - who.list[i].seen > WHO_KEEP then table.remove(who.list, i) end
	end
	who.found, who.total = count, total
	who.state = "done"
	ReleaseWho()
	ns.Changed()
end

function S.WhoWait()
	return math.max(0, math.ceil(WHO_WAIT - (GetTime() - whoSent)))
end

-- role: search only classes that can fill it.
local function SendWho(run, role)
	if whoPending or S.WhoWait() > 0 then return end
	local skip = {}
	if role then
		for i = 1, GetNumClasses() do
			local _, class, id = GetClassInfo(i)
			if id and not D.CanFill(class, role) then skip[#skip + 1] = id end
		end
	end
	local theirs = BlizzardWhoList()
	if theirs then theirs:UnregisterEvent("WHO_LIST_UPDATE") end
	C_FriendList.SetWhoToUi(true)
	-- classIDs are classes to exclude; empty uiMapIDs means every zone.
	C_FriendList.SendWho(run.min .. "-" .. run.max, Enum.SocialWhoOrigin.Social,
		{ classIDs = skip, raceIDs = {}, uiMapIDs = {} })
	whoSent, whoPending = GetTime(), true
	S.who.state, S.who.role = "searching", role
	C_Timer.After(WHO_TIMEOUT, function()
		if whoPending and GetTime() - whoSent >= WHO_TIMEOUT - 0.1 then
			S.who.state = "silent"
			ReleaseWho()
			ns.Changed()
		end
	end)
end

-- Group Finder

local function Searching()
	local finder = S.finder
	finder.state = "searching"
	finderSent = GetTime()
	C_Timer.After(FINDER_TIMEOUT, function()
		if finder.state == "searching" and GetTime() - finderSent >= FINDER_TIMEOUT - 0.1 then
			finder.state = "failed"
			ns.Changed()
		end
	end)
end

-- The run's own activities: narrower than a category, so the next look asks again.
local function SendFinder(run)
	local d = D.byKey[run.key]
	local info = d and C_LFGList.GetActivityInfoTable(d.ids[1])
	if not info or S.finder.state == "searching" or GetTime() - finderSent < LOOK_WAIT then return end
	-- Same call as Blizzard's Browse tab, narrowed to this dungeon.
	C_LFGList.Search(info.categoryID, 0, 0, nil, false, nil, d.ids)
	S.finder.kind = nil
	Searching()
end

-- The category to look at: what the player picked, else the run's, else the first the game offers.
function S.Kind()
	local kind = ns.char.kind
	if kind and D.category[kind] then return kind end
	local run = ns.Run.Get()
	local d = run and D.byKey[run.key]
	if d and D.category[d.kind] then return d.kind end
	if D.category.dungeon then return "dungeon" end
	return D.kinds[1] and D.kinds[1].kind or "dungeon"
end

-- Seconds before the Group Finder can be asked again.
function S.LookWait()
	return math.max(0, math.ceil(LOOK_WAIT - (GetTime() - finderSent)))
end

-- Asks the Group Finder for every listing of one category. Skipped while a
-- search is out, too soon after the last, or (unless forced) while the same
-- category's results are fresh. Returns true when a search went out.
function S.Look(kind, force)
	if not ns.Listing.Available() then return false end
	local categoryID = D.category[kind]
	if not categoryID or S.finder.state == "searching" then return false end
	local since = GetTime() - finderSent
	if since < LOOK_WAIT then return false end
	if not force and kind == S.finder.kind and since < LOOK_FRESH then return false end
	C_LFGList.Search(categoryID, 0, 0, nil, false, nil, C_LFGList.GetAvailableActivities(categoryID))
	S.finder.kind = kind
	Searching()
	ns.Changed()
	return true
end

-- What a click or key that opens or changes the window should look at.
function S.Auto()
	return S.Look(S.Kind(), false)
end

-- One listing in the shape of a chat post (see Board). Secret listings and
-- anything that isn't a dungeon, raid, zone or custom listing return nil.
local function Read(resultID)
	local info = C_LFGList.GetSearchResultInfo(resultID)
	if not info or issecretvalue(info) or issecretvalue(info.leaderName) or issecretvalue(info.numMembers) then return nil end
	if not info.leaderName or info.isDelisted or info.hasSelf then return nil end
	local keys, seen, size = {}, {}, 0
	for _, id in ipairs(info.activityIDs) do
		local d = D.byActivity[id]
		if d and not seen[d] then
			seen[d] = true
			keys[#keys + 1] = d.key
			size = math.max(size, d.size)
		end
	end
	if #keys == 0 then return nil end

	local solo = info.numMembers == 1
	local leader = C_LFGList.GetSearchResultLeaderInfo(resultID)
	if issecretvalue(leader) then leader = nil end
	local roles = {}
	local have, open   -- a group's spots by role: filled, and still open
	if solo then
		local offered = leader and leader.lfgRoles
		if offered then roles.tank, roles.healer, roles.dps = offered.tank or nil, offered.healer or nil, offered.dps or nil end
	else
		local counts = C_LFGList.GetSearchResultMemberCounts(resultID)
		if counts and not issecretvalue(counts) then
			-- No role set counts as DPS, as in Blizzard's list.
			have = { tank = counts.TANK or 0, healer = counts.HEALER or 0, dps = (counts.DAMAGER or 0) + (counts.NOROLE or 0) }
			open = { tank = counts.TANK_REMAINING or 0, healer = counts.HEALER_REMAINING or 0, dps = counts.DAMAGER_REMAINING or 0 }
			roles.tank = open.tank > 0 or nil
			roles.healer = open.healer > 0 or nil
			roles.dps = open.dps > 0 or nil
		end
	end
	-- Bosses already killed; 0 is a fresh run.
	local downs
	if not solo then
		local defeated = C_LFGList.GetSearchResultEncounterInfo(resultID)
		downs = defeated and not issecretvalue(defeated) and #defeated or 0
	end
	local area = leader and leader.areaName
	local comment, age, style = info.comment, info.age, info.generalPlaystyle
	local text = comment and not issecretvalue(comment) and comment or ""
	return {
		finder = true,
		id = resultID,
		have = have,
		open = open,
		style = style and not issecretvalue(style) and style or nil,
		downs = downs,
		friendly = info.newPlayerFriendly or nil,
		guild = (info.numGuildMates or 0) > 0 or nil,
		friends = (info.numBNetFriends or 0) + (info.numCharFriends or 0) > 0 or nil,
		name = ns.Short(info.leaderName),
		class = leader and leader.classFilename,
		level = leader and leader.level,
		kind = solo and "lfg" or "lfm",
		keys = keys,
		roles = roles,
		count = info.numMembers,
		size = size,
		area = area and not issecretvalue(area) and area ~= "" and area or nil,
		comment = comment,
		text = text,
		foreign = text ~= "" and ns.Parse.Foreign(text, GetLocale()) or false,
		channel = "the Group Finder",
		last = time() - (age and not issecretvalue(age) and age or 0),
	}
end

local FROM_GAME = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }

-- Members of a listed group, read on demand. Only for groups of up to ten.
function S.Members(post)
	local out = {}
	if not post.id or post.count > 10 then return out end
	for i = 1, post.count do
		local m = C_LFGList.GetSearchResultPlayerInfo(post.id, i)
		if m and not issecretvalue(m) and m.name and not issecretvalue(m.name) then
			out[#out + 1] = { name = ns.Short(m.name), class = m.classFilename, level = m.level,
				role = FROM_GAME[m.assignedRole], leader = m.isLeader or false }
		end
	end
	return out
end

function S.Defeated(post)
	local list = post.id and C_LFGList.GetSearchResultEncounterInfo(post.id)
	if not list or issecretvalue(list) then return {} end
	return list
end

-- Results are shared with Blizzard's window, so this also runs after a search
-- made there, and after the automatic one when your group is listed.
local function OnFinder(failed)
	local finder = S.finder
	wipe(finder.all)
	finder.state = failed and "failed" or "done"
	if not failed then
		finder.when = time()
		local _, results = C_LFGList.GetFilteredSearchResults()
		for _, resultID in ipairs(results) do
			finder.all[#finder.all + 1] = Read(resultID)
		end
	end
	ns.Changed()
end

-- A listing changed or was removed: re-read the results, debounced.
local finderQueued = false

local function OnFinderChange()
	if finderQueued or S.finder.state ~= "done" then return end
	finderQueued = true
	C_Timer.After(0.5, function()
		finderQueued = false
		if S.finder.state == "done" then OnFinder(false) end
	end)
end

-- Everything known, readable or not: chat posts, then listings by people who
-- didn't also post. Someone who both posted and listed shows once, as the post.
function S.Everything()
	local all = {}
	for _, post in ipairs(ns.Board.posts) do all[#all + 1] = post end
	for _, post in ipairs(S.finder.all) do
		if not ns.Board.Get(post.name) then all[#all + 1] = post end
	end
	return all
end

-- Readable posts and listings about one dungeon, groups first, newest first.
function S.For(key)
	local out = {}
	for _, post in ipairs(S.Everything()) do
		if ns.Board.Readable(post) and ns.Board.About(post, key) then out[#out + 1] = post end
	end
	table.sort(out, function(a, b)
		if a.kind ~= b.kind then return a.kind == "lfm" end
		if a.last ~= b.last then return a.last > b.last end
		return a.name < b.name
	end)
	return out
end

-- key -> { groups, players } for everything readable.
function S.Counts()
	local counts = {}
	for _, post in ipairs(S.Everything()) do
		if ns.Board.Readable(post) then
			for _, key in ipairs(post.keys) do
				local c = counts[key]
				if not c then
					c = { groups = 0, players = 0 }
					counts[key] = c
				end
				if post.kind == "lfm" then c.groups = c.groups + 1 else c.players = c.players + 1 end
			end
		end
	end
	return counts
end

-- Solo players listed for the run.
function S.Listed()
	local out = {}
	local run = ns.Run.Get()
	if not run then return out end
	for _, post in ipairs(S.finder.all) do
		if post.kind == "lfg" then
			for _, key in ipairs(post.keys) do
				if key == run.key then
					out[#out + 1] = post
					break
				end
			end
		end
	end
	return out
end

-- From the Find people button.
function S.Find(role)
	local run = ns.Run.Get()
	if not run then return end
	SendWho(run, role)
	if ns.Listing.Available() then SendFinder(run) end
	ns.Changed()
end

-- From a Refresh button: the category in view, again.
function S.Browse()
	S.Look(S.Kind(), true)
end

-- Clears Who results on a run change. Group Finder results are kept.
function S.Clear()
	wipe(S.who.list)
	S.who.state, S.who.found, S.who.total = "idle", 0, 0
end

function S.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("WHO_LIST_UPDATE")
	events:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
	events:RegisterEvent("LFG_LIST_SEARCH_FAILED")
	events:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
	events:SetScript("OnEvent", function(_, event)
		if event == "WHO_LIST_UPDATE" then
			OnWho()
		elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
			OnFinderChange()
		else
			OnFinder(event == "LFG_LIST_SEARCH_FAILED")
		end
	end)
end
