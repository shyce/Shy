-- Builds a death record at PLAYER_DEAD from C_DeathRecap and the damage log in Blows.lua.
--
-- C_DeathRecap.GetRecapEvents (first event is the killing blow) gives the ledger's rows:
-- `currentHP` is the health before the blow and `amount` includes `overkill`. Log entries
-- from before the oldest event become one sum (`prior`). A log entry matches an event when
-- the amounts agree (with or without overkill) and the times are within SLACK. The log
-- supplies the rows only when the client returns no events. Event counts are not assumed.
--
-- Events can be missing at PLAYER_DEAD or still be the previous death's (same newest
-- timestamp): the record is then built from the log and rebuilt on a retry (RETRY).
-- Any field can be secret: each is checked with issecretvalue first, and only readable
-- values are used or saved. The raw answer is saved in ShyRecapCharDB.raw for "/shy recap raw".
--
-- A record (saved, plain values only):
--   at            time()
--   zone, sub     zone and subzone
--   map, x, y     where on which map, as shares of it (none inside a dungeon)
--   max           max health
--   away          flagged AFK
--   who           attackers, the killer first when `killed`: { name, guid, player (true,
--                 false for a creature, nil unknown), class (token), classText, race, level, guild }
--   killed        who[1] dealt the killing blow
--   env           environmental: "FALLING", "DROWNING", "FATIGUE", "FIRE", "LAVA", "SLIME"
--   blows         oldest first, killing blow last: { t (seconds before death), spell, id, icon,
--                 amount, school (mask), crit, by (index into who), before (health), over (overkill), env }
--   prior         damage before those blows: { n (blows), amount (total), t (first blow) }
--   seen          its ledger has been opened
--   stamp         the client's timestamp for the killing blow

local ADDON, ns = ...
local T = ns.T
local Secret = issecretvalue

local D = {}
ns.Death = D

-- Melee icon, Ability_MeleeDamage. Blizzard's recap uses spell 88163's icon, which this client lacks.
local MELEE = 132223
-- The icons Blizzard's recap uses for environmental damage.
local WORLD_ICON = {
	DROWNING = "spell_shadow_demonbreath", FALLING = "ability_rogue_quickrecovery", FIRE = "spell_fire_fire",
	LAVA = "spell_fire_fire", SLIME = "inv_misc_slime_01", FATIGUE = "ability_creature_cursed_05",
}
local WORLD_OTHER = "ability_creature_cursed_05"

local ROWS = 12             -- most blows in a record: the newest
local SLACK = 1             -- seconds an event and a log entry may differ (under a creature's 2 s swing)
local RETRY = { 0.3, 1, 3 } -- seconds after PLAYER_DEAD to ask the client again
local KEPT_BACK = "(kept back)"

-- issecretvalue must come first: comparing a secret to nil is an error.
local function Read(value)
	if Secret(value) or value == nil then return nil end
	return value
end

local function Number(value)
	value = Read(value)
	if type(value) == "number" then return value end
end

local function Text(value)
	value = Read(value)
	if type(value) == "string" and value ~= "" then return value end
end

-- Reading C_DeathRecap

-- An event's readable values, and the names of its secret fields.
local function Plain(event)
	local values, hidden = {}, {}
	if Secret(event) or type(event) ~= "table" then return values, hidden end
	for key, value in pairs(event) do
		if type(key) == "string" then
			if Secret(value) then
				hidden[#hidden + 1] = key
			else
				local kind = type(value)
				if kind == "string" or kind == "number" or kind == "boolean" then values[key] = value end
			end
		end
	end
	table.sort(hidden)
	return values, hidden
end

-- Returns the events (or nil), max health, and a note of the raw answer for "/shy recap raw".
local function Game()
	local note = { events = {}, hidden = {} }
	local has = C_DeathRecap.HasRecapEvents()
	if Secret(has) then
		note.has = KEPT_BACK
		return nil, nil, note
	end
	note.has = has and "yes" or "no"
	if not has then return nil, nil, note end
	local events = C_DeathRecap.GetRecapEvents()
	if Secret(events) or type(events) ~= "table" then
		note.has = KEPT_BACK
		return nil, nil, note
	end
	for i, event in ipairs(events) do note.events[i], note.hidden[i] = Plain(event) end
	local max = Number(C_DeathRecap.GetRecapMaxHealth())
	if max and max <= 0 then max = nil end
	note.max = max
	if #note.events == 0 then return nil, max, note end
	return note.events, max, note
end

local function Newest(game)
	local newest
	for _, event in ipairs(game) do
		local stamp = event.timestamp
		if type(stamp) == "number" and (not newest or stamp > newest) then newest = stamp end
	end
	return newest
end

-- One event as a ledger row. `event` comes from Plain, so nothing in it is secret.
local function Row(event)
	local row = {}
	if type(event.amount) == "number" then row.amount = event.amount end
	if type(event.school) == "number" then row.school = event.school end
	if type(event.currentHP) == "number" then row.before = event.currentHP end
	if type(event.timestamp) == "number" then row.stamp = event.timestamp end
	if type(event.overkill) == "number" and event.overkill > 0 then row.over = event.overkill end
	if event.critical == true then row.crit = true end

	local kind = event.event
	if kind == "SWING_DAMAGE" then
		row.spell, row.icon = ACTION_SWING, MELEE
	elseif kind == "ENVIRONMENTAL_DAMAGE" then
		local what = type(event.environmentalType) == "string" and event.environmentalType:upper() or "OTHER"
		row.env = what
		row.spell = _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. what]
		row.icon = "Interface\\Icons\\" .. (WORLD_ICON[what] or WORLD_OTHER)
	else
		if type(event.spellName) == "string" and event.spellName ~= "" then row.spell = event.spellName end
		if type(event.spellId) == "number" then
			row.id = event.spellId
			if not row.spell then row.spell = Text(C_Spell.GetSpellName(row.id)) end
			row.icon = Number((C_Spell.GetSpellTexture(row.id)))
		end
		if not row.spell and kind == "RANGE_DAMAGE" then row.spell = RANGED end
	end
	-- Source for People below: none for environmental damage or a hidden caster.
	if not row.env and event.hideCaster ~= true then
		if type(event.sourceName) == "string" and event.sourceName ~= "" then row.name = event.sourceName end
		if type(event.sourceGUID) == "string" and event.sourceGUID ~= "" then row.guid = event.sourceGUID end
	end
	return row
end

-- Events as rows, oldest first, killing blow last, with `t`; also returns the newest timestamp.
local function Rows(game)
	local rows = {}
	for i = #game, 1, -1 do rows[#rows + 1] = Row(game[i]) end
	local newest = Newest(game)
	-- Times are only used when every timestamp is readable.
	local timed = newest ~= nil
	for _, row in ipairs(rows) do
		if not row.stamp then timed = false end
	end
	if not timed then return rows, newest end
	for _, row in ipairs(rows) do row.t = math.max(0, newest - row.stamp) end
	-- Sort by timestamp; the killing blow stays last.
	local kill = table.remove(rows)
	for i = 2, #rows do
		local row, j = rows[i], i - 1
		while j >= 1 and rows[j].stamp > row.stamp do
			rows[j + 1] = rows[j]
			j = j - 1
		end
		rows[j + 1] = row
	end
	rows[#rows + 1] = kill
	return rows, newest
end

-- Merging events and the log

-- Whether an event row and a log entry are the same blow. A row with a secret amount or
-- time can't be checked and matches the next entry in line.
local function Fits(row, blow)
	if row.amount and row.amount ~= blow.amount and not (row.over and row.amount - row.over == blow.amount) then return false end
	return not (row.t and math.abs(row.t - blow.t) > SLACK)
end

-- The first `count` log entries as one sum: { n, amount, t (first blow) }.
local function Prior(own, count)
	if count < 1 then return nil end
	local prior = { n = count, amount = 0, t = own[1].t }
	for k = 1, count do prior.amount = prior.amount + own[k].amount end
	return prior
end

-- `rows` are the client's events (oldest first), `own` the log. Each row takes its missing
-- values from its matching log entry. Returns the rows and the sum of the entries before them.
local function Merge(rows, own)
	local below, first = #own + 1, nil
	for i = #rows, 1, -1 do
		local row = rows[i]
		for k = below - 1, 1, -1 do
			local blow = own[k]
			if Fits(row, blow) then
				row.amount = row.amount or blow.amount
				row.crit = row.crit or blow.crit
				row.before = row.before or blow.before
				row.school = row.school or blow.school
				row.t = row.t or blow.t
				below, first = k, k
				break
			end
		end
	end
	local cut = 0
	if #rows == 0 then
		cut = #own
	elseif rows[1].t then
		for k, blow in ipairs(own) do
			if blow.t <= rows[1].t + 0.5 then break end
			cut = k
		end
		if first then cut = math.min(cut, first - 1) end
	elseif first then
		cut = first - 1
	end
	if #rows > 0 then return rows, Prior(own, cut) end
	-- No events: the log's entries are the rows, without spell names.
	local out = {}
	for k = 1, cut do
		local blow = own[k]
		out[#out + 1] = { t = blow.t, amount = blow.amount, school = blow.school, crit = blow.crit, before = blow.before }
	end
	return out, nil
end

-- Client quirk: the recap appends a bogus surname to a creature's sourceName, a different
-- one on each event ("Kobold Miner Bubble", "Kobold Miner Cauthon"). The name is the
-- leading words all of them share.
local function Shared(names)
	if not names then return nil end
	local words
	for _, name in ipairs(names) do
		local these = {}
		for word in name:gmatch("%S+") do these[#these + 1] = word end
		if not words then
			words = these
		else
			for i = 1, #words do
				if words[i] ~= these[i] then
					for k = #words, i, -1 do words[k] = nil end
					break
				end
			end
		end
	end
	if not words or #words == 0 then return names[1] end
	return table.concat(words, " ")
end

-- An attacker: class and race from the GUID, level, guild and full name from Seen.lua.
local function Attacker(names, guid)
	local name = Shared(names)
	local a = { name = name, guid = guid }
	if guid then
		local player = Read(C_PlayerInfo.GUIDIsPlayer(guid))
		if player ~= nil then a.player = player == true end
		if a.player then
			local classText, class, race, _, _, said, _, level = GetPlayerInfoByGUID(guid)
			a.classText, a.class, a.race, a.level = Text(classText), Text(class), Text(race), Number(level)
			if a.level and a.level <= 0 then a.level = nil end
			a.name = a.name or Text(said)
		end
	end
	local seen = ns.Seen.Find(guid, name)
	if seen then
		if a.player == nil then a.player = seen.player end
		a.level = seen.level or a.level
		a.guild = seen.guild
		a.class, a.classText, a.race = a.class or seen.class, a.classText or seen.classText, a.race or seen.race
		-- Prefer the unit's own name when matched by GUID, or when the recap gave the first name alone.
		if not a.name or seen.first == a.name or (guid and ns.Seen.Find(guid) == seen) then a.name = seen.name end
	end
	if not a.name then return nil end
	return a
end

-- The attackers the rows name: killer first, then by damage. Sets each row's `by` to an index into the list.
local function People(rows)
	local who, at = {}, {}
	local told = {}   -- every sourceName given for each attacker
	for _, row in ipairs(rows) do
		local key = row.guid or row.name
		if key and row.name then
			told[key] = told[key] or {}
			table.insert(told[key], row.name)
		end
	end
	for _, row in ipairs(rows) do
		local key = row.guid or row.name
		if key then
			local i = at[key]
			if not i then
				local a = Attacker(told[key], row.guid)
				if a then
					a.dealt, a.was = 0, #who + 1
					who[a.was] = a
					i = a.was
					at[key] = i
				end
			end
			if i then
				who[i].dealt = who[i].dealt + (row.amount or 0)
				row.by = i
			end
		end
		row.name, row.guid = nil, nil
	end
	local kill = rows[#rows]
	local killer = kill and kill.by and who[kill.by] or nil
	table.sort(who, function(x, y)
		if (x == killer) ~= (y == killer) then return x == killer end
		if x.dealt ~= y.dealt then return x.dealt > y.dealt end
		return x.was < y.was
	end)
	local moved = {}
	for i, a in ipairs(who) do moved[a.was] = i end
	for _, row in ipairs(rows) do
		if row.by then row.by = moved[row.by] end
	end
	for _, a in ipairs(who) do a.dealt, a.was = nil, nil end
	return who, killer ~= nil
end

-- Fills in missing `before` values by counting back from the next blow. Returns max health.
local function Health(rows, max)
	for i = #rows, 1, -1 do
		local row, after = rows[i], rows[i + 1]
		if not row.before and row.amount then
			if after and after.before then
				row.before = after.before + row.amount
			elseif not after then
				row.before = math.max(1, row.amount - (row.over or 0))
			end
		end
	end
	if not max then
		for _, row in ipairs(rows) do
			if row.before and (not max or row.before > max) then max = row.before end
		end
	end
	for _, row in ipairs(rows) do
		if row.before and max and row.before > max then row.before = max end
	end
	return max
end

-- moment: { at, zone, sub, away, max } at death; own: Blows.Recent() at death;
-- game, max: the client's events and max health, or nil.
function D.Record(moment, own, game, max)
	local rows, stamp = {}, nil
	if game then rows, stamp = Rows(game) end
	local prior
	rows, prior = Merge(rows, own)
	-- Past ROWS, the oldest rows are folded into `prior`.
	while #rows > ROWS do
		local blow = table.remove(rows, 1)
		prior = prior or { n = 0, amount = 0 }
		prior.n, prior.amount = prior.n + 1, prior.amount + (blow.amount or 0)
		if blow.t and (not prior.t or blow.t > prior.t) then prior.t = blow.t end
	end
	local who, killed = People(rows)
	local death = {
		at = moment.at, zone = moment.zone, sub = moment.sub, away = moment.away or nil,
		map = moment.map, x = moment.x, y = moment.y,
		max = Health(rows, max or moment.max), who = who, blows = rows, prior = prior, stamp = stamp,
	}
	local last = rows[#rows]
	if last and last.env then
		death.env = last.env
	elseif killed then
		death.killed = true
	end
	for _, row in ipairs(rows) do row.stamp = nil end
	return death
end

-- PLAYER_DEAD

local moment, own   -- the current death's state, and the log of its fight
local telling = 0   -- counter identifying the death still being retried

-- Builds the record: on the first try with whatever the client returns, on later tries
-- only if it now has the events. Returns true when it had them.
local function Tell(try)
	-- If C_DeathRecap errors, report it and still build the record from the log.
	local ok, game, max, note = pcall(Game)
	if not ok then
		geterrorhandler()(game)
		game, max, note = nil, nil, { events = {}, hidden = {}, has = "error: " .. tostring(game) }
		moment.told = true   -- a retry would fail again
	end
	if game then
		local newest = Newest(game)
		if newest and newest == ns.char.stamp then
			game, note.stale = nil, true   -- still the previous death's events
		end
	end
	note.at, note.try, note.after, note.own = moment.at, try, GetTime() - moment.clock, own
	ns.char.raw = note
	if not (game or try == 1) then return false end
	local death = D.Record(moment, own, game, max)
	if try == 1 then
		ns.Keep(death)
		ns.char.up = true
	else
		death.seen = ns.char.deaths[1].seen
		ns.char.deaths[1] = death
	end
	if game then
		moment.told = true
		if death.stamp then ns.char.stamp = death.stamp end
	end
	ns.Refresh()
	return game ~= nil
end

-- Where the player stands: map, x, y as shares of it; nothing where the game gives no place.
local function Spot()
	local map = Number(C_Map.GetBestMapForUnit("player"))
	local at = map and C_Map.GetPlayerMapPosition(map, "player")
	if not at then return nil end
	local x, y = at:GetXY()
	x, y = Number(x), Number(y)
	if x and y then return map, x, y end
end

local function Died()
	if not T:IsOn() then return end
	local feigned = UnitIsFeignDeath("player")
	if not Secret(feigned) and feigned then return end
	local now = GetTime()
	if moment and now - moment.clock < 2 then return end   -- PLAYER_DEAD fired twice
	local away = Read(UnitIsAFK("player"))
	local max = Number(UnitHealthMax("player"))
	moment = {
		at = time(), clock = now, zone = Text(GetZoneText()), sub = Text(GetSubZoneText()),
		away = away == true, max = max and max > 0 and max or nil,
	}
	moment.map, moment.x, moment.y = Spot()
	own = ns.Blows.Recent()
	ns.Blows.Clear()
	telling = telling + 1
	local mine, this = telling, moment
	if Tell(1) then return end
	for i, delay in ipairs(RETRY) do
		C_Timer.After(delay, function()
			if telling == mine and not this.told then Tell(i + 1) end
		end)
	end
end

function D.Start()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_DEAD")
	events:SetScript("OnEvent", Died)
end

-- "/shy recap raw"

local function Pairs(values)
	local keys, parts = {}, {}
	for key in pairs(values) do keys[#keys + 1] = key end
	table.sort(keys)
	for i, key in ipairs(keys) do parts[i] = key .. "=" .. tostring(values[key]) end
	return table.concat(parts, "  ")
end

function D.RawText()
	local raw = ns.char.raw
	if not raw then return "No death has been recorded on this character yet." end
	local lines = {}
	local function Say(text, ...) lines[#lines + 1] = select("#", ...) > 0 and text:format(...) or text end
	Say("Death at %s on %s, %s.", ns.Clock(raw.at), date("%Y-%m-%d", raw.at), ns.Ago(raw.at))
	Say("Asked %d time(s); the note below is from %.2f s after PLAYER_DEAD.", raw.try or 0, raw.after or 0)
	Say("C_DeathRecap.HasRecapEvents: %s%s", tostring(raw.has), raw.stale and "  (the events were still the previous death's)" or "")
	Say("C_DeathRecap.GetRecapMaxHealth: %s", tostring(raw.max))
	Say("")
	Say("C_DeathRecap.GetRecapEvents: %d event(s). The first is the killing blow.", #raw.events)
	for i, values in ipairs(raw.events) do
		Say("  %d  %s", i, Pairs(values))
		local hidden = raw.hidden[i]
		if hidden and #hidden > 0 then Say("     kept back: %s", table.concat(hidden, ", ")) end
	end
	Say("")
	Say("ShyRecap's own log of the fight (UNIT_COMBAT on you): %d blow(s), oldest first.", #raw.own)
	for _, blow in ipairs(raw.own) do
		Say("  -%.2f s  amount=%s  school=%s  crit=%s  health before=%s", blow.t, tostring(blow.amount), tostring(blow.school),
			tostring(blow.crit or false), tostring(blow.before))
	end
	local death = ns.Latest()
	if death and death.at == raw.at then
		Say("")
		Say("The record made of it: %s. Max health %s.%s%s", ns.ShareText(death), tostring(death.max),
			death.away and " AFK." or "", death.env and (" Environment: " .. death.env .. ".") or "")
		for i, a in ipairs(death.who) do
			Say("  attacker %d  %s", i, Pairs(a))
		end
		if death.prior then Say("  before the rows  %s", Pairs(death.prior)) end
		for i, blow in ipairs(death.blows) do
			Say("  blow %d  %s", i, Pairs(blow))
		end
	end
	return table.concat(lines, "\n")
end

-- A sample death for layout mode and "/shy recap test"

-- { t, spell ID, fallback name, amount, school, attacker, crit }. Names and icons come from the client.
local SAMPLE = {
	{ 4.1, 8676, "Ambush", 79, 1, 1, true },
	{ 3.0, 116, "Frostbolt", 34, 16, 2 },
	{ 2.1, 1752, "Sinister Strike", 27, 1, 1 },
	{ 1.0, 2136, "Fire Blast", 21, 4, 2 },
	{ 0, 2098, "Eviscerate", 38, 1, 1 },
}

-- A view (see ns.View) of a made-up death, `ago` seconds back.
function D.Sample(ago)
	local at = time() - (ago or 720)
	local zugg = { name = "Zugg Skullsplitter", player = true, class = "ROGUE", classText = LOCALIZED_CLASS_NAMES_MALE.ROGUE,
		race = "Orc", level = 14, guild = "Blood Pact" }
	local mala = { name = "Mala Coldhand", player = true, class = "MAGE", classText = LOCALIZED_CLASS_NAMES_MALE.MAGE,
		race = "Undead", level = 12 }
	local death = { at = at, zone = "Elwynn Forest", sub = "Crystal Lake", away = true, max = 174, killed = true,
		who = { zugg, mala }, blows = {} }
	local health = death.max
	for i, line in ipairs(SAMPLE) do
		local blow = { t = line[1], id = line[2], amount = line[4], school = line[5], by = line[6], crit = line[7], before = health }
		blow.spell = Text(C_Spell.GetSpellName(blow.id)) or line[3]
		blow.icon = Number((C_Spell.GetSpellTexture(blow.id)))
		if blow.amount > health then blow.over = blow.amount - health end
		health = math.max(0, health - blow.amount)
		death.blows[i] = blow
	end
	return { death = death, again = 2, earlier = {
		{ at = at - 33 * 60, killed = true, who = { zugg }, blows = {} },
		{ at = at - 65 * 60, killed = true, who = { { name = "Kobold Miner", player = false, level = 6 } }, blows = {} },
	} }
end
