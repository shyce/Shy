-- Events into numbers, and Blizzard's floating combat text switched off while ours draws.
-- UNIT_COMBAT (unit, what, how, amount, school) is each hit a unit takes, with no source:
-- "WOUND" with an amount is damage, without one a miss or absorb; "HEAL"; else a word
-- (CombatFeedbackText). It fires per unit token: "nameplateN" is used, "target" only until
-- a nameplate token has been seen. Heals on the player get the caster's name from
-- COMBAT_TEXT_UPDATE, matched by amount within WINDOW.
-- Any payload may be secret: a secret amount is still written, a secret kind or name is skipped.
-- A blow well over your usual one is written larger, learned from the amounts that can be read.

local ADDON, ns = ...
local T, Stage, Where = ns.T, ns.Stage, ns.Where
local UI, Theme = Shy.UI, Shy.Theme
local Secret = issecretvalue

local F = {}
ns.Feed = F

local PHYSICAL = Enum.Damageclass.MaskPhysical
local WINDOW = 0.15   -- seconds between a heal and its caster's name
-- The game's own text that ours stands in for, each setting taken to 0 while ours is written and put
-- back after: { its name, the setting of ours it goes with (nil: the numbers on nameplates), whether it
-- is off wherever ours are on (else only while ours are written on nameplates) }. Its numbers for your
-- and your pet's damage, and for healing (off in a group too: a heal on a nameplate is always ours to
-- write, since the game says nothing of one on somebody at full health); the size of all its text over a unit, which is what is left there
-- once those are off: the experience a kill gave; its scrolling lines for reputation and honor.
-- The fourth: what the game ships it as. The game keeps its settings for the whole install and ours are
-- kept by account, so a remembered "0" can be our own doing (another account's, or one left with nothing kept)
-- and is never put back for a setting the game ships on: its numbers would stay off for good.
-- The fifth: what it is held at where only your own are written and you have a pet out. Its blows can't
-- be told from the others' there (measured: with ten others in melee, about half of what would be taken for
-- its swings would be someone else's), so the game's own numbers say them, which are exact: both held
-- on, and the game's text over a unit left its size ("back") so they can be seen.
-- The sixth: what is off for it (nil: "0"). The game's text over a unit is never gone at size 0, only small,
-- so it is made too large to be seen instead.
local ENGINE = {
	{ "floatingCombatTextCombatDamage_v2", nil, false, "1" }, { "floatingCombatTextCombatHealing_v2", "plates", true, "1" },
	{ "floatingCombatTextPetMeleeDamage_v2", nil, false, "1", "1" }, { "floatingCombatTextPetSpellDamage_v2", nil, false, "0", "1" },
	{ "WorldTextScale_v2", "gainXP", false, "1", "back", "1000" },
	{ "floatingCombatTextRepChanges_v2", "gainRep", true, "0" },
	{ "floatingCombatTextHonorGains_v2", "gainHonor", true, "0" },
}
local WORLD, HUGE = "WorldTextScale_v2", 1000
-- COMBAT_TEXT_UPDATE kinds that are a heal on the player (CombatTextConstants.lua).
local HEALS = {
	HEAL = true, HEAL_CRIT = true, PERIODIC_HEAL = true, PERIODIC_HEAL_CRIT = true,
	HEAL_ABSORB = true, HEAL_CRIT_ABSORB = true, PERIODIC_HEAL_ABSORB = true,
}
local STOPPED = { ABSORB = true, BLOCK = true, RESIST = true }
local NEAR = { "target", "focus", "mouseover" }
local inParty = { party1 = true, party2 = true, party3 = true, party4 = true }
-- A number's size beside others of its kind: the amount over the usual plain one of its sort lately (`learn`:
-- how fast that follows, never by more than `step` times at one blow, so one freak blow changes little), a
-- critical strike over `crit` times it, flattened by `curve` and held to `most`. It only ever adds: what
-- is usual sits over most of the blows it is learned from (one heavy blow outweighs several plain ones,
-- and on a nameplate everyone's count), so a number made smaller for being under it made nearly all small.
local WEIGH = { learn = 0.15, step = 1.25, crit = 1.8, curve = 0.35, most = 1.30, critMost = 1.20 }
local usual = {}           -- what was hit and how ("deal", "mend", "hurt", "healed") -> the usual plain amount lately
F.PLAY = {}                -- the same for the sample fight, so it teaches the real one nothing

local drawing = false      -- we are drawing on nameplates
local ownsXP = false       -- the game's text over a unit is off: experience gained is ours to write
local platesSpeak = false  -- UNIT_COMBAT has fired for a nameplate token: "target" is ignored
local heard = {}           -- nameplate -> { time, what, viaTarget } of the last hit drawn
local waiting, names = {}, {}   -- heals awaiting a name; names awaiting a heal
local classes = {}         -- player name -> class
local unknown = {}         -- player name -> when no unit of theirs was found (looked for again after MISS)
local MISS = 5             -- seconds
-- Whether a unit token is a nameplate's, kept per token: UNIT_COMBAT names several for every hit.
local plateToken = setmetatable({}, { __index = function(t, unit)
	local is = unit:sub(1, 9) == "nameplate"
	t[unit] = is
	return is
end })

-- Hits into numbers

local function Short(n)
	n = math.floor(n + 0.5)
	if n >= 1000000 then return ("%.1f%s"):format(n / 1000000, SECOND_NUMBER_CAP_NO_SPACE) end
	if n >= 10000 then return ("%.1f%s"):format(n / 1000, FIRST_NUMBER_CAP_NO_SPACE) end
	return tostring(n)
end

-- Returns kind (a key of Stage.KIND), word, isHeal; nil for events not shown.
local function Read(what, how, amount)
	if what == "HEAL" then
		if not Secret(amount) and amount == 0 then return nil end
		return how == "CRITICAL" and "crit" or "hit", nil, true
	elseif what == "WOUND" then
		if Secret(amount) or amount ~= 0 then
			if how == "CRITICAL" or how == "CRUSHING" then return "crit" end
			if how == "GLANCING" then return "glance" end
			return "hit"
		end
		return "word", STOPPED[how] and CombatFeedbackText[how] or CombatFeedbackText.MISS
	elseif what == "ENERGIZE" then
		return nil
	end
	local word = CombatFeedbackText[what]
	if word then return "word", word end
end

-- How large a blow's number stands: 1 as its kind is, more for one over the usual, never less.
-- An amount the game keeps back is not weighed. Only plain hits teach what is usual.
local function Weigh(book, sort, kind, amount)
	if not T.db.weigh or kind == "glance" or Secret(amount) then return 1 end
	local base = book[sort]
	if amount <= 0 then return 1 end
	if kind == "hit" then
		book[sort] = base and math.max(base / WEIGH.step, math.min(base * WEIGH.step, base + (amount - base) * WEIGH.learn)) or amount
	end
	if not base then return 1 end
	if kind == "crit" then
		return math.max(1, math.min(WEIGH.critMost, (amount / (base * WEIGH.crit)) ^ WEIGH.curve))
	end
	return math.max(1, math.min(WEIGH.most, (amount / base) ^ WEIGH.curve))
end

-- Heals are one color; damage takes its school's, and physical damage on the player is red.
local function Tint(onYou, heal, school)
	if heal then
		local c = UI.colors.good
		return c[1], c[2], c[3]
	end
	local known = T.db.schools and school ~= nil and not Secret(school)
	if onYou and not (known and school ~= PHYSICAL) then return Theme.Harm() end
	return Theme.School(known and school or PHYSICAL)
end

-- Draws one hit into a pair of lanes. `book`: what is usual there (default: the fights' own).
-- Returns the entry and whether it was a heal.
function F.Tell(pair, onYou, what, how, amount, school, book)
	local kind, word, heal = Read(what, how, amount)
	if not kind then return nil end
	if word then
		if not T.db.words then return nil end
		local c = UI.colors.dim
		return Stage.Add(pair.hurt, kind, nil, c[1], c[2], c[3], "%s", word)
	end
	local r, g, b = Tint(onYou, heal, school)
	local lane = heal and pair.heal or pair.hurt
	if kind == "crit" and not heal and pair.crit and T.db.motion ~= "calm" then lane = pair.crit end
	local grow = Weigh(book or usual, onYou and (heal and "healed" or "hurt") or (heal and "mend" or "deal"), kind, amount)
	local sign = heal and "+" or (onYou and "-" or "")
	if Secret(amount) then return Stage.Add(lane, kind, grow, r, g, b, sign .. "%d", amount), heal end
	return Stage.Add(lane, kind, grow, r, g, b, "%s", sign .. Short(amount)), heal
end

-- Healer names

-- Characters on this client have a first name and a surname; an event may carry either form.
local function Is(unit, name)
	local first, last = UnitNameUnmodified(unit)
	if first == nil or Secret(first) or Secret(last) then return false end
	if name == first then return true end
	return last ~= nil and last ~= "" and name == first .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. last
end

local function Look(unit, name)
	local player = UnitIsPlayer(unit)
	if player == nil or Secret(player) or not player or not Is(unit, name) then return nil end
	local class = UnitClassBase(unit)
	if class == nil or Secret(class) then return nil end
	return class
end

-- The class behind a name, searched among current unit tokens and cached.
local function Class(name)
	local class = classes[name]
	if class then return class end
	-- Someone no unit was found for a moment ago (an unseen healer heals again and again): not looked for again yet.
	local missed = unknown[name]
	if missed and GetTime() - missed < MISS then return nil end
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do class = class or Look("raid" .. i, name) end
	elseif IsInGroup() then
		for i = 1, GetNumSubgroupMembers() do class = class or Look("party" .. i, name) end
	end
	for _, unit in ipairs(NEAR) do class = class or Look(unit, name) end
	if not class then
		for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
			local unit = not nameplate:IsForbidden() and nameplate.unitToken   -- set by Blizzard's nameplate code
			if type(unit) == "string" and not Secret(unit) then class = class or Look(unit, name) end
		end
	end
	classes[name] = class
	unknown[name] = not class and GetTime() or nil
	return class
end

local function Label(entry, name)
	-- A secret name can't be compared with the player's own, so it is skipped.
	if Secret(name) or type(name) ~= "string" or name == "" or Is("player", name) then return end
	local class = Class(name)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then
		Stage.Tail(entry, color.r, color.g, color.b, "%s", name)
	else
		local c = UI.colors.dim
		Stage.Tail(entry, c[1], c[2], c[3], "%s", name)
	end
end

local function Fits(a, b)
	if a == nil or b == nil or Secret(a) or Secret(b) then return true end
	return a == b
end

-- Removes and returns the first item within WINDOW whose amount matches.
local function Take(list, amount, now)
	for i = #list, 1, -1 do
		if now - list[i].time > WINDOW then table.remove(list, i) end
	end
	for i, item in ipairs(list) do
		if Fits(item.amount, amount) then return table.remove(list, i) end
	end
end

-- The heal and its caster's name arrive in either order.
local function Healed(entry, amount)
	local now = GetTime()
	local said = Take(names, amount, now)
	if said then
		Label(entry, said.name)
	else
		waiting[#waiting + 1] = { entry = entry, amount = amount, time = now }
	end
end

local function Named(name, amount)
	local now = GetTime()
	local up = Take(waiting, amount, now)
	if up then
		Label(up.entry, name)
	else
		names[#names + 1] = { name = name, amount = amount, time = now }
	end
end

-- Events

local function OnYou(what, how, amount, school)
	local entry, heal = F.Tell(Where.You(), true, what, how, amount, school)
	if entry and heal and T.db.healer then Healed(entry, amount) end
end

local plated, platedAt   -- (set where the tellings of one heal are settled, below)

-- Whose blow. The game tells what a unit takes and never from whom, so where only your own are
-- wanted (a raid as it comes, a party if chosen), a blow or a heal is taken for yours when it lands as you act: with your swing (`melee`
-- seconds after it, two blows: one may be an extra attack), your shot (`shot`: it has to fly), or a spell
-- you cast (`cast` on your target, for its flight; on anyone for `wide` seconds, up to `most`: a spell
-- that strikes many, or a heal on someone you only clicked). A channelled spell is a blow on your target
-- every `channel` seconds. Your damage over time follows no act of that instant: ShyDots knows the
-- rhythm of each of your spells on each mob, and a blow in its school on its beat is taken for its tick,
-- one a `beat`. What your blow sets off in the same instant (a weapon's proc, an extra attack) is told
-- with it. It is a guess: someone else's blow in such a moment is taken for yours, and what comes later
-- of nothing you did then (a proc's own damage over time) is left out. Your pet's blows are not guessed
-- at: the game's own numbers say them in such a raid (ENGINE, above).
local MINE = { melee = 0.12, shot = 1.2, cast = 1.6, wide = 0.3, most = 6, late = 0.06, channel = 0.5, beat = 0.6, acts = 6, held = 4 }
local ticked = {}          -- nameplate -> when a blow on it was last taken for a tick of yours
local onlyMine = false     -- only your own are written on nameplates (as chosen for a party or a raid)
local acts, actAt = {}, 0  -- what you did lately, a ring: { till, left, wideTill, wideLeft, usedAt }
local channelling, channelAt = false, 0
-- Blows on your target told a moment before the act they may be of (the game may tell the blow first).
local late = { n = 0, plate = {}, what = {}, how = {}, amount = {}, school = {}, at = {} }

-- Whether what has just landed, on your target or on another, comes of something you did. One act
-- answers for everything told in the instant it is first used (a blow is told under several names).
local function Mine(onTarget, now)
	for i = 1, MINE.acts do
		local a = acts[i]
		if a and a.usedAt == now then return true end
	end
	for i = 1, MINE.acts do
		local a = acts[i]
		if a then
			if onTarget and a.left > 0 and now <= a.till then
				a.left, a.usedAt = a.left - 1, now
				return true
			elseif a.wideLeft > 0 and now <= a.wideTill then
				a.wideLeft, a.usedAt = a.wideLeft - 1, now
				return true
			end
		end
	end
	if onTarget and channelling and now - channelAt >= MINE.channel then
		channelAt = now
		return true
	end
	return false
end

-- Whether a blow on a nameplate's unit is a tick of your damage over time there: ShyDots says it is on
-- the beat of one of your spells in that school, and no other blow has been taken for that beat.
local function Tick(nameplate, unit, what, school, now)
	if what ~= "WOUND" then return false end
	local last = ticked[nameplate]
	if last == now then return true end
	if last and now - last < MINE.beat then return false end
	local dots = Shy.addons.Dots
	if not (dots and dots.TickOn and dots:IsOn() and dots:TickOn(unit, school)) then return false end
	ticked[nameplate] = now
	return true
end

local Written   -- (a blow written by its nameplate: below)

-- You did something: blows may come of it. Those told a moment before it are written now.
local function Act(till, left, wideTill, wideLeft)
	if not onlyMine then return end
	actAt = actAt % MINE.acts + 1
	local a = acts[actAt]
	if not a then
		a = {}
		acts[actAt] = a
	end
	a.till, a.left, a.wideTill, a.wideLeft, a.usedAt = till, left, wideTill, wideLeft, nil
	local now = GetTime()
	for i = 1, late.n do
		local nameplate = late.plate[i]
		if nameplate and now - late.at[i] <= MINE.late and not nameplate:IsForbidden() and Mine(true, now) then
			Written(nameplate, late.what[i], late.how[i], late.amount[i], late.school[i])
		end
		late.plate[i], late.amount[i] = nil, nil
	end
	late.n = 0
end

local function OnPlate(unit, what, how, amount, school)
	local viaTarget = unit == "target"
	if not viaTarget and not plateToken[unit] then return end
	if viaTarget and platesSpeak then return end
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate or nameplate:IsForbidden() then return end
	if nameplate == C_NamePlate.GetNamePlateForUnit("player") then return end   -- handled as "player"
	local now = GetTime()
	local last = heard[nameplate]
	if not last then
		last = {}
		heard[nameplate] = last
	elseif not viaTarget and last.viaTarget and last.time == now and last.what == what then
		-- Already drawn as "target". Only once: a second hit in the same frame is a new hit.
		platesSpeak, last.viaTarget = true, false
		return
	end
	if not viaTarget then platesSpeak = true end
	last.time, last.what, last.viaTarget = now, what, viaTarget
	if onlyMine then
		local onTarget = nameplate == C_NamePlate.GetNamePlateForUnit("target")
		if not Mine(onTarget, now) and not Tick(nameplate, unit, what, school, now) then
			-- Not yours as far as can be told yet: a blow on your target is kept a moment, for an act told after it.
			if onTarget and what ~= "HEAL" then
				local i = late.n % MINE.held + 1
				late.n = math.max(late.n, i)
				late.plate[i], late.what[i], late.how[i], late.amount[i], late.school[i], late.at[i] = nameplate, what, how, amount, school, now
			end
			return
		end
	end
	Written(nameplate, what, how, amount, school)
end

function Written(nameplate, what, how, amount, school)
	local pair = Where.Plate(nameplate)
	if what == "HEAL" then
		local now = GetTime()
		if platedAt ~= now then plated, platedAt = 0, now end
		plated = plated + 1
	else
		Where.Hit(pair)   -- a blow: what is gained a moment after comes of this unit
	end
	F.Tell(pair, false, what, how, amount, school)
end

-- A heal on a friend with no nameplate to write it by (none up, or one addons may not touch): on their
-- unit frame, or with no frame of ours in sight by your character with their name.
local function OnFrame(unit, what, how, amount, school)
	local pair = Where.Frame(unit)
	if pair then
		F.Tell(pair, false, what, how, amount, school)
		return
	end
	local kind = Read(what, how, amount)
	if not kind then return end
	local name = UnitName(unit)   -- (written unread, if it is kept back)
	if not Secret(name) and name == nil then name = "" end
	local c, lane = UI.colors.good, Where.You().gain
	local grow = Weigh(usual, "mend", kind, amount)
	if Secret(amount) then
		Stage.Add(lane, kind, grow, c[1], c[2], c[3], "+%d %s", amount, name)
	else
		Stage.Add(lane, kind, grow, c[1], c[2], c[3], "+%s %s", Short(amount), name)
	end
end

-- One heal is told under every name its unit goes by: as one of your party, as your target, as a
-- nameplate. The game won't say which nameplate is whose of your party (it refuses the asking), and in a
-- fight not even whether your target is one of them, so the tellings of one instant are held to its end
-- and settled together: a heal a nameplate wrote is written nowhere else; else one of your party's is
-- written on their frame, and your target's only where none of your party's was told (it is one of them
-- otherwise) and it isn't you.
local held = { n = 0, unit = {}, how = {}, amount = {}, school = {} }
plated = 0                        -- heals written by nameplates, in the instant `platedAt`
local youAt                       -- the instant a heal on you was last told

local function Settle()
	local n, stamp = held.n, held.at
	held.n = 0
	if not T:IsOn() then return end
	local byPlates = platedAt == stamp and plated or 0
	local parties, target = 0, nil
	for i = 1, n do
		if held.unit[i] == "target" then target = i else parties = parties + 1 end
	end
	if parties > 0 then
		-- (With as many written by nameplates as were told of your party, those were these.)
		if byPlates < parties then
			for i = 1, n do
				if held.unit[i] ~= "target" then OnFrame(held.unit[i], "HEAL", held.how[i], held.amount[i], held.school[i]) end
			end
		end
	elseif target and byPlates == 0 and youAt ~= stamp then
		OnFrame("target", "HEAL", held.how[target], held.amount[target], held.school[target])
	end
	for i = 1, n do held.amount[i] = nil end
end

local function Friend(unit, how, amount, school)
	local now = GetTime()
	if held.n == 0 or held.at ~= now then
		if held.n == 0 then C_Timer.After(0, Settle) end
		held.at = now
	end
	local i = held.n + 1
	held.n = i
	held.unit[i], held.how[i], held.amount[i], held.school[i] = unit, how, amount, school
end

local function Combat(unit, what, how, amount, school)
	if not T:IsOn() then return end
	if Secret(unit) or Secret(what) or type(unit) ~= "string" then return end
	if Secret(how) then how = nil end
	local heal = what == "HEAL"
	if unit == "player" then
		if heal then youAt = GetTime() end
		if T.db.you then OnYou(what, how, amount, school) end
		return
	end
	-- Blows on nameplates are ours only while the game's own numbers are off there; a heal always is.
	if drawing or (heal and T.db.plates) then OnPlate(unit, what, how, amount, school) end
	if heal and T.db.friends and (inParty[unit] or unit == "target") and (not onlyMine or Mine(unit == "target", GetTime())) then
		Friend(unit, how, amount, school)
	end
end

local function CombatText(kind)
	if not (T:IsOn() and T.db.you and T.db.healer) then return end
	if Secret(kind) or not HEALS[kind] then return end
	local name, amount = C_CombatText.GetCurrentEventInfo()
	Named(name, amount)
end

-- Blizzard's numbers are off while ours draw on nameplates; saved values are restored otherwise.
local function Engine()
	local db = T.db
	-- In a party and in a raid each as chosen: everyone's ("all"), only what is taken for your own
	-- ("mine"), or the game's own numbers ("game"). Alone, a blow on a nameplate is yours or your pet's.
	local mode = "all"
	if IsInGroup() then mode = IsInRaid() and db.raid or db.party end
	drawing = db.on and db.plates and mode ~= "game"
	onlyMine = drawing and mode == "mine"
	-- (With no pet out, nothing is left for the game's numbers to say there.)
	local pet = onlyMine and UnitExists("pet")
	for _, setting in ipairs(ENGINE) do
		local name, key, anywhere, ships, inRaid = setting[1], setting[2], setting[3], setting[4], setting[5]
		local off = setting[6] or "0"
		-- What it is held at while ours are written: off, or in such a raid what that asks; nil: as it was.
		local held = (key == nil or db[key]) and ((anywhere and db.on) or drawing) and off or nil
		if pet and inRaid then held = inRaid ~= "back" and inRaid or nil end
		local is = GetCVar(name)
		if is == nil then
			-- (A setting this game doesn't have.)
		elseif held then
			if db.cvars[name] == nil then db.cvars[name] = is end
			if is ~= held then SetCVar(name, held) end
		elseif db.cvars[name] ~= nil then
			local back = db.cvars[name]
			if back == "0" or back == off then back = ships end
			if is ~= back then SetCVar(name, back) end
			db.cvars[name] = nil
		elseif not db.mended and (is == "0" or is == off) and ships ~= is then
			SetCVar(name, ships)   -- left off with nothing remembered: put right, once
		end
	end
	db.mended = true
	-- Read back: only with the game's own gone is the experience written by us, so it is never said twice.
	ownsXP = drawing and db.gainXP == true and (tonumber(GetCVar(WORLD)) or 0) >= HUGE
end

-- COMBAT_TEXT_UPDATE reports one active unit, normally set by Blizzard's scrolling combat text.
local function Listen()
	if C_CombatText.GetActiveUnit() == nil then C_CombatText.SetActiveUnit("player") end
end

local function Gone(unit)
	if Secret(unit) or type(unit) ~= "string" then return end
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if nameplate then
		Where.LetGo(nameplate, unit)
		heard[nameplate], ticked[nameplate] = nil, nil
	end
end

local HANDLERS = {
	UNIT_COMBAT = Combat,
	COMBAT_TEXT_UPDATE = CombatText,
	GROUP_ROSTER_UPDATE = Engine,
	PLAYER_ENTERING_WORLD = function()
		Engine()
		Listen()
	end,
	-- Nameplates are pooled: a new unit must not inherit the last one's lanes.
	NAME_PLATE_UNIT_ADDED = Gone,
	NAME_PLATE_UNIT_REMOVED = Gone,
	-- What you do, for telling your own blows in a raid (Mine).
	PLAYER_SWING = function(_, kind)
		local now = GetTime()
		if kind == Enum.PlayerSwingType.Ranged then Act(now + MINE.shot, 1, 0, 0) else Act(now + MINE.melee, 2, 0, 0) end
	end,
	UNIT_SPELLCAST_SUCCEEDED = function()
		local now = GetTime()
		Act(now + MINE.cast, 1, now + MINE.wide, MINE.most)
	end,
	UNIT_SPELLCAST_CHANNEL_START = function() channelling, channelAt = true, 0 end,
	UNIT_SPELLCAST_CHANNEL_STOP = function() channelling = false end,
	UNIT_PET = Engine,   -- a pet called or sent away: whose numbers say its blows
}
local MY = { UNIT_SPELLCAST_SUCCEEDED = true, UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_PET = true }

function F.Start()
	local events = CreateFrame("Frame")
	for event in pairs(HANDLERS) do
		if MY[event] then events:RegisterUnitEvent(event, "player") else events:RegisterEvent(event) end
	end
	events:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)
	-- The numbers' frames and fonts are made out of a fight: on nameplates at the size set, beside you
	-- at the size times the box's scale.
	local function Warm()
		if T:IsOn() then Stage.Warm(T.db.size, T.db.size * Where.box:GetScale()) end
	end
	ns.OnApply(function()
		Engine()
		if not T:IsOn() then Stage.Clear() end
		Warm()
	end)
	Engine()
	Listen()
	Warm()
end

function F.Drawing()
	return drawing
end

-- Whether only what is taken for your own is written on nameplates.
function F.OnlyMine()
	return onlyMine
end

-- Whether the experience a kill gives is ours to write (the game's own text over the unit is off).
function F.OwnsXP()
	return ownsXP
end

-- Sample fight: seconds in, on the player or not, then the UNIT_COMBAT payload.
F.SAMPLE = {
	{ 0.00, false, "WOUND", "", 45, 1 },
	{ 0.35, false, "WOUND", "", 18, 8 },
	{ 0.60, true,  "WOUND", "", 32, 1 },
	{ 0.90, false, "WOUND", "CRITICAL", 110, 1 },
	{ 1.50, false, "DODGE", "", 0, 1 },
	{ 1.80, true,  "HEAL", "", 312, 2, healer = { "Clara", "PRIEST" } },
	{ 2.20, false, "WOUND", "", 64, 4 },
	{ 2.60, true,  "WOUND", "", 27, 32 },
	{ 3.00, false, "WOUND", "GLANCING", 22, 1 },
	{ 3.40, true,  "HEAL", "CRITICAL", 540, 8, healer = { "Bram", "DRUID" } },
	{ 3.90, false, "WOUND", "", 71, 1, kill = true, xp = 120, rep = { "Stormwind", 75 } },
	{ 4.50, true, coin = 1240 },
}

function F.Sample(pair, line)
	local gains = ns.Gains
	if line.coin then
		if gains and pair.gain and T.db.gainCoin then gains.Show("coin", line.coin, nil, pair.gain) end
		return
	end
	local entry, heal = F.Tell(pair, line[2], line[3], line[4], line[5], line[6], F.PLAY)
	if entry and heal and line.healer and T.db.healer then
		local color = C_ClassColor.GetClassColor(line.healer[2])
		Stage.Tail(entry, color.r, color.g, color.b, "%s", line.healer[1])
	end
	if entry and line.kill then
		Stage.Final(pair.hurt, pair.crit)
		if gains and pair.gain then
			if line.xp and T.db.gainXP then gains.Show("xp", line.xp, nil, pair.gain, gains.AFTER) end
			if line.rep and T.db.gainRep then gains.Show("rep", line.rep[2], line.rep[1], pair.gain, gains.AFTER) end
		end
	end
end

-- The sample fight, where the numbers are switched on: on your target's nameplate and on you. Coin is
-- written by you either way, as it is in play.
function F.Test()
	local db = T.db
	if not db.on then
		T:Print("the numbers are off. Turn them on to see a sample.")
		return
	end
	local nameplate = db.plates and UnitExists("target") and C_NamePlate.GetNamePlateForUnit("target") or nil
	if nameplate and nameplate:IsForbidden() then nameplate = nil end
	if db.plates and not nameplate then
		T:Print(db.you and "showing the numbers on you. Target something with a nameplate to see those too."
			or "target something with a nameplate to see the numbers.")
	end
	for _, line in ipairs(F.SAMPLE) do
		local shown = nameplate
		if line[2] then shown = db.you or line.coin end
		if shown then
			C_Timer.After(line[1], function()
				if line[2] then
					F.Sample(Where.You(), line)
				else
					F.Sample(Where.Plate(nameplate), line)
				end
			end)
		end
	end
end
