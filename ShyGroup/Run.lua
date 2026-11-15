-- The current run: dungeon, wanted roles, group members and their roles, and
-- the messages built from them. Saved per character. Roles sync both ways with
-- the game's party roles (UnitGroupRolesAssigned / UnitSetRole).

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local R = {}
ns.Run = R

local POST_WAIT = 30   -- seconds before the chat post can go out again
local FROM_GAME = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
local TO_GAME = { tank = "TANK", healer = "HEALER", dps = "DAMAGER" }

function R.Get()
	return ns.char.run
end

-- The group

-- Everyone in the group, the player included. Members with secret names are skipped.
function R.Members()
	local list = {}
	local me = ns.Me()
	local function Add(unit)
		local name = ns.FullName(unit)
		if not name then return end
		local _, class = UnitClass(unit)
		local level = UnitLevel(unit)
		local role = UnitGroupRolesAssigned(unit)
		list[#list + 1] = {
			name = ns.Short(name),
			unit = unit,
			class = not issecretvalue(class) and class or nil,
			level = not issecretvalue(level) and level > 0 and level or nil,
			role = not issecretvalue(role) and FROM_GAME[role] or nil,
			me = name == me,
		}
	end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do Add("raid" .. i) end
	else
		Add("player")
		for i = 1, GetNumSubgroupMembers() do Add("party" .. i) end
	end
	return list
end

function R.Count()
	return math.max(1, GetNumGroupMembers())
end

function R.IsFull()
	local run = R.Get()
	return run ~= nil and R.Count() >= run.size
end

function R.CanInvite()
	return not IsInGroup() or UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function R.Have()
	local run = R.Get()
	local have = { tank = 0, healer = 0, dps = 0 }
	for _, m in ipairs(R.Members()) do
		local role = run.roles[m.name]
		if role then have[role] = have[role] + 1 end
	end
	return have
end

function R.Missing()
	local run = R.Get()
	local have = R.Have()
	local missing, total = {}, 0
	for _, role in ipairs(D.ROLES) do
		missing[role] = math.max(0, run.need[role] - have[role])
		total = total + missing[role]
	end
	return missing, total
end

function R.NextRole()
	local missing = R.Missing()
	for _, role in ipairs(D.ROLES) do
		if missing[role] > 0 then return role end
	end
end

-- Gives every member a role, in order: the game's role, the role they were
-- recruited for (the player: last choice, else the Group Finder tick), else
-- DPS, flagged as a guess when the class could also tank or heal.
function R.FillRoles()
	local run = R.Get()
	if not run then return end
	run.guessed = run.guessed or {}
	run.game = run.game or {}
	for _, m in ipairs(R.Members()) do
		-- Applied only when the game's role changes, so a role set here
		-- afterwards holds even if UnitSetRole was refused.
		if m.role ~= run.game[m.name] then
			run.game[m.name] = m.role
			if m.role then
				run.roles[m.name] = m.role
				run.guessed[m.name] = nil
				if m.me then ns.char.role = m.role end
			end
		end
		if not run.roles[m.name] then
			local p = ns.People.Get(m.name)
			local known = m.me and (ns.char.role or ns.Listing.SoloRole()) or (p and (p.role or p.said))
			if known and D.CanFill(m.class, known) then
				run.roles[m.name] = known
			else
				run.roles[m.name] = "dps"
				run.guessed[m.name] = D.CanFill(m.class, "tank") or D.CanFill(m.class, "healer") or nil
			end
		end
	end
end

function R.IsGuess(name)
	local run = R.Get()
	return run.guessed ~= nil and run.guessed[name] == true
end

-- Pushes a role to the game. In a group only your own role, or anyone's as
-- leader or assistant; solo it sets your listing's roles. Not in combat.
local function TellGame(name, role)
	if InCombatLockdown() then return end
	local mine = name == ns.Me()
	if not IsInGroup() then
		if mine then ns.Listing.SyncRoles() end
		return
	end
	if not mine and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then return end
	for _, m in ipairs(R.Members()) do
		if m.name == name then UnitSetRole(m.unit, TO_GAME[role]) end
	end
end

-- Must run from a click: UnitSetRole needs a hardware event. Works without a
-- run for your own seat, which the next run starts with.
function R.SetRole(name, role)
	local run = R.Get()
	if run then
		run.roles[name] = role
		if run.guessed then run.guessed[name] = nil end
	end
	if name == ns.Me() then ns.char.role = role end
	TellGame(name, role)
	ns.Changed()
end

function R.CanRoleCheck()
	return IsInGroup() and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end

function R.RoleCheck()
	if R.CanRoleCheck() then InitiateRolePoll() end
end

function R.CycleRole(name)
	local order = { tank = "healer", healer = "dps", dps = "tank" }
	R.SetRole(name, order[R.Get().roles[name] or "dps"])
end

-- The run's dungeon entry; nil for a run of your own.
function R.Dungeon()
	local run = R.Get()
	return run and D.byKey[run.key] or nil
end

-- "17-26", "40 players" for a raid, "Group quests" for a zone, nothing for your own run.
function R.Detail()
	local run = R.Get()
	local d = R.Dungeon()
	if not d then return run and (run.min .. "-" .. run.max) or "" end
	if d.kind == "raid" then return d.size .. " players" end
	if d.kind == "zone" then return d.min .. "-" .. d.max .. "  \194\183  " .. (d.group or "Group quests") end
	return d.min .. "-" .. d.max
end

function R.AdjustNeed(role, delta)
	local run = R.Get()
	run.need[role] = math.max(0, math.min(run.size, run.need[role] + delta))
	ns.Changed()
end

function R.AdjustLevel(which, delta)
	local run = R.Get()
	local value = math.max(1, math.min(GetMaxPlayerLevel(), run[which] + delta))
	run[which] = value
	if run.min > run.max then
		if which == "min" then run.max = value else run.min = value end
	end
	ns.Changed()
end

-- Starting and finishing

-- key: a dungeon key from Data, or "custom" with customName.
function R.Start(key, customName)
	local old = R.Get()
	local d = D.byKey[key]
	local level = UnitLevel("player")
	local run = { key = key, started = time(), roles = old and old.roles or {} }
	if d then
		run.name, run.min, run.max, run.size = d.name, d.min, d.max, d.size
	else
		run.key, run.name, run.size = "custom", customName, 5
		run.min, run.max = math.max(1, level - 3), math.min(GetMaxPlayerLevel(), level + 3)
	end
	run.need = D.DefaultNeed(run.size)
	run.guessed, run.game = old and old.guessed, old and old.game
	ns.char.run = run
	if d and D.category[d.kind] then ns.char.kind = d.kind end
	R.FillRoles()
	ns.Search.Clear()
	ns.Changed()
	if d and d.map then Shy:Fire("SHY_GROUP_RUN", d.map) end
end

-- Also removes this run's Group Finder listing, which needs a hardware event:
-- call only from a click or a slash command.
function R.Stop()
	if ns.Listing.State() == "run" then ns.Listing.Remove() end
	ns.char.run = nil
	ns.People.Clear()
	ns.Search.Clear()
	ns.Changed()
end

-- Messages

local function Plural(n, one, many)
	return n == 1 and one or (n .. " " .. many)
end

-- "tank, healer, 2 DPS", or nil when every role is covered.
function R.NeedText()
	local missing = R.Missing()
	local parts = {}
	if missing.tank > 0 then parts[#parts + 1] = Plural(missing.tank, "tank", "tanks") end
	if missing.healer > 0 then parts[#parts + 1] = Plural(missing.healer, "healer", "healers") end
	if missing.dps > 0 then parts[#parts + 1] = Plural(missing.dps, "DPS", "DPS") end
	if #parts > 0 then return table.concat(parts, ", ") end
end

-- Roles in a whisper: "a tank", "tank, heal or dps".
R.ARTICLE = { tank = "a tank", healer = "a healer", dps = "a dps" }
R.BARE = { tank = "tank", healer = "heal", dps = "dps" }

-- "a tank", "a tank or a healer", "tank, heal or dps"
function R.Or(words)
	if #words <= 1 then return words[1] or "" end
	if #words == 2 then return words[1] .. " or " .. words[2] end
	return table.concat(words, ", ", 1, #words - 1) .. " or " .. words[#words]
end

-- "Ann" from "Ann Smith" or "Ann-Realm"; "" when unknown.
function R.FirstName(name)
	return name and name:match("^[^%s%-]+") or ""
end

-- The open roles someone could fill: what they offered (a post or listing),
-- else what their class can do. missing: the run's, or a sample for a preview.
function R.RolesFor(candidate, missing)
	missing = missing or R.Missing()
	local offered = candidate and candidate.roles
	if offered and not next(offered) then offered = nil end
	local out = {}
	for _, role in ipairs(D.ROLES) do
		if missing[role] > 0 and (offered and offered[role] or (not offered and D.CanFill(candidate and candidate.class, role))) then
			out[#out + 1] = role
		end
	end
	return out
end

-- The words in braces, in the order the legend shows them, with what each says.
-- whisper: those only a whisper has.
R.WORDS = {
	{ key = "dungeon", what = "The run's name" },
	{ key = "need", what = "Roles still missing, like \"tank, 2 DPS\"" },
	{ key = "tally", what = "\"(3/5)\" once there are two of you; nothing alone" },
	{ key = "left", what = "Spots left" },
	{ key = "count", what = "How many of you there are" },
	{ key = "size", what = "The group's size" },
	{ key = "levels", what = "The run's level range" },
	{ key = "style", what = "Your listing's style" },
	{ key = "me", what = "Your first name" },
	{ key = "myroles", what = "Roles you can play, like \"tank or dps\"" },
	{ key = "level", what = "Your level" },
	{ key = "class", what = "Your class" },
	{ key = "name", what = "Their first name", whisper = true },
	{ key = "group", what = "\"We're 3/5.\" once there are two of you; nothing alone", whisper = true },
	{ key = "role", what = "The one role you're asking for, like \"a healer\"", whisper = true },
	{ key = "roles", what = "Two roles to pick from, like \"a tank or a dps\"", whisper = true },
	{ key = "choices", what = "Three roles to pick from, like \"tank, heal or dps\"", whisper = true },
}

-- Everything a template can say right now. extra: the caller's own words.
function R.Vars(extra)
	local run = R.Get()
	local n = R.Count()
	local vars = {
		dungeon = run and run.name or "",
		count = n,
		size = run and run.size or 5,
		need = run and R.NeedText() or "more",
		left = run and math.max(0, run.size - n) or "",
		levels = run and (run.min .. "-" .. run.max) or "",
		style = ns.Listing.StyleName(),
		me = R.FirstName(ns.Me()),
		myroles = R.MyRoles(),
		level = UnitLevel("player"),
		class = UnitClass("player"),
		name = "",
	}
	for k, v in pairs(extra or {}) do vars[k] = v end
	local count, size = tonumber(vars.count) or 1, tonumber(vars.size) or 5
	if vars.group == nil then vars.group = count < 2 and "" or (" We're " .. count .. "/" .. size .. ".") end
	if vars.tally == nil then vars.tally = count < 2 and "" or (" (" .. count .. "/" .. size .. ")") end
	return vars
end

-- A chat line holds this many characters; the rest is never sent.
R.LIMIT = 255

-- Fills a template's {words} (R.WORDS), however long it comes out.
function R.FillFull(template, extra)
	local vars = R.Vars(extra)
	local text = template:gsub("{(%w+)}", function(key)
		return vars[key] ~= nil and tostring(vars[key]) or ""
	end)
	-- "Hi {name}!" with no name reads "Hi!".
	text = text:gsub("%s+([!,?.])", "%1")
	return strtrim((text:gsub("%s+", " ")))
end

-- The same, cut to what a chat line holds.
function R.Fill(template, extra)
	return R.FillFull(template, extra):sub(1, R.LIMIT)
end

-- The legend: each word with what it says right now, or what it would.
--   { { key, value, what }, ... }   whisper: include the whisper-only words
function R.Legend(whisper)
	local vars = R.Vars()
	local out = {}
	for _, word in ipairs(R.WORDS) do
		if whisper or not word.whisper then
			local value = vars[word.key]
			value = value ~= nil and strtrim(tostring(value)) or ""
			out[#out + 1] = { key = word.key, value = value, what = word.what }
		end
	end
	return out
end

-- The whisper asking someone in. role: ask for that one; else the open roles
-- they could fill decide: one is named, two are offered as a choice, more
-- become a question. missing: the run's unless a preview passes a sample.
function R.AskText(candidate, role, missing)
	local templates = T.db.templates
	local vars = { name = R.FirstName(candidate and candidate.name) }
	if role then
		vars.role = R.ARTICLE[role]
		return R.Fill(templates.askRole, vars)
	end
	local can = R.RolesFor(candidate, missing)
	if #can == 0 then return R.Fill(templates.ask, vars) end
	if #can == 1 then
		vars.role = R.ARTICLE[can[1]]
		return R.Fill(templates.askRole, vars)
	end
	local words = {}
	for i, r in ipairs(can) do words[i] = R.ARTICLE[r] end
	if #can == 2 then
		vars.roles = R.Or(words)
		return R.Fill(templates.askChoice, vars)
	end
	for i, r in ipairs(can) do words[i] = R.BARE[r] end
	vars.choices = R.Or(words)
	return R.Fill(templates.askFlexible, vars)
end

-- "tank or heal": the roles you offer, else your seat, else "help".
function R.MyRoles()
	local words = {}
	local ticked = ns.Listing.Roles()
	for _, role in ipairs(D.ROLES) do
		if ticked[role] then words[#words + 1] = R.BARE[role] end
	end
	if #words == 0 and ns.char.role then words[1] = R.BARE[ns.char.role] end
	return #words > 0 and R.Or(words) or "help"
end

function R.PostText()
	return R.Fill(T.db.templates.post)
end

-- Chat channels

-- "2. General - Elwynn Forest" -> "General"
function R.ChannelBase(name)
	name = name:gsub("^%d+%.%s*", "")
	return (name:gsub("%s+%-%s+.*$", ""))
end

function R.Channels()
	local out = {}
	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		out[#out + 1] = { id = list[i], name = R.ChannelBase(list[i + 1]) }
	end
	return out
end

-- Unset in the options means LookingForGroup only.
function R.PostsIn(name)
	local chosen = T.db.postChannels[name]
	if chosen == nil then return name == "LookingForGroup" end
	return chosen
end

function R.PostChannels()
	local out = {}
	for _, channel in ipairs(R.Channels()) do
		if R.PostsIn(channel.name) then out[#out + 1] = channel end
	end
	return out
end

local lastPost = -POST_WAIT

function R.PostWait()
	return math.max(0, math.ceil(POST_WAIT - (GetTime() - lastPost)))
end

-- Sending to a channel needs a hardware event: call only from the Post button.
function R.Post()
	if R.PostWait() > 0 then return end
	local channels = R.PostChannels()
	if #channels == 0 then
		T:Print("no channel to post in. Join LookingForGroup or pick channels in the options.")
		return
	end
	local text = R.PostText()
	for _, channel in ipairs(channels) do
		C_ChatInfo.SendChatMessage(text, "CHANNEL", nil, channel.id)
	end
	lastPost = GetTime()
	ns.Changed()
end

function R.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("CHANNEL_UI_UPDATE")
	events:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	events:SetScript("OnEvent", function(_, event)
		if event ~= "CHANNEL_UI_UPDATE" then ns.People.SyncRoster() end
		ns.Changed()
	end)
end
