-- Follows the player's damage over time on each mob and says what it still has to deal.
--
-- Health and auras are secret in a fight, and so is the size of every blow, so nothing here reads them. A
-- spell is known from its cast: UNIT_SPELLCAST_SENT names the mob (its GUID, which stays readable),
-- UNIT_SPELLCAST_SUCCEEDED the spell, and Data/Dots.lua what the client's tables say about its ticks. Its
-- ticks are the UNIT_COMBAT hits on that mob that land in its school on its rhythm: each takes a tick off
-- what is to come, and the first says the spell landed. A miss, resist or dodge right after the cast means
-- it never landed. What is still to come is the ticks left times the tick.
-- A tick's size is the tables' until it is learned and kept (db.ticks): after a fight from the game's own
-- damage meter (what the spell dealt over the ticks counted), or from a tick whose size is readable (out of
-- a fight), which is then matched by its size too and tells of a longer run of ticks than the tables promise
-- (db.spans: talents that lengthen a spell).

local ADDON, ns = ...
local T = ns.T
local Secret = issecretvalue

local K = {}
ns.Track = K

-- Columns of a Data/Dots.lua entry.
local SCHOOL, DURATION, MORE_PER_COMBO, PERIOD, BASE, PER_LEVEL, LEVEL, POINTS_PER_COMBO, POWER, ATTACK, FLIES, DIRECT =
	1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12

local WINDOW = 0.45          -- seconds either side of an expected tick, until the first is seen
local WINDOW_SET = 0.25      -- once the rhythm is known from the first tick
local FLIGHT = 1.5           -- a flying spell's first tick can be this late (it starts when it lands)
local MISSED = 2             -- ticks that could have been seen and weren't: the cast never landed
local SLACK = 0.25           -- share a tick may differ from the size seen on this cast
local FIRST_SLACK = 0.3      -- from a size learned on an earlier cast
local CRIT_LOW, CRIT_HIGH = 1.3, 2.3
local OUTCOME = 0.4          -- seconds after a cast within which a miss or resist is its own
local LOOKBACK = 0.25        -- or before its event
local SAME_SLOT = 0.2        -- two hits this close took one tick's slot
local HOUSEKEEP = 0.25
local COMBO_FRESH = 3        -- seconds a readable combo count is trusted
local SENT_KEEP = 10
local PHYSICAL = 1
local AVOIDS = { MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true, DEFLECT = true, RESIST = true, REFLECT = true }
local MELEE_AVOIDS = { DODGE = true, PARRY = true, DEFLECT = true }   -- a spell can't be dodged: someone's melee
local LOG = 60
-- Sizes from the damage meter after a fight.
local METER = {
	TRIES = 20, EVERY = 0.5,   -- asked this often, this many times, while the meter keeps the fight secret or has none
	TICKS = 2,                 -- a fight with fewer ticks of a spell teaches nothing
	LOW = 0.5, HIGH = 2.5,     -- a size outside these shares of the tables' tick is something else's damage
}

local mobs = {}          -- guid -> { [spell name] = dot }
local sent = {}          -- castGUID -> { guid, at }
local lastCast           -- { guid, name, dot, previous, at }: a cast whose outcome isn't known yet
local lastOutcome        -- { guid, avoided, action, school, at }
local lastBuilder        -- { guid, points, at }
local counted = 0        -- combo points counted from builders while the game keeps the count secret
local comboAtSend        -- a readable count when the finisher was sent
local lastCombo, lastComboAt = nil, 0
local stats = { attack = 0 }   -- spell power by school index, attack power: read out of fights
local mult = {}          -- by school index: the share your buffs and debuffs leave of your damage (1 = as is)
local fighting = false   -- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED
local fight = {}         -- spell -> { keys = { [size key] = { weight, ticks, table } }, unsure, shown }: this fight's ticks
local reading            -- { fight, tries }: the fight whose sizes are being asked of the damage meter
local log = {}
local ticker, events
local names = {}         -- spell -> name

-- Reading

local function Now() return GetTime() end

local function Note(fmt, ...)
	log[#log + 1] = ("%.1f %s"):format(Now(), fmt:format(...))
	if #log > LOG then table.remove(log, 1) end
end

local function Name(spell)
	local name = names[spell]
	if name == nil then
		name = C_Spell.GetSpellName(spell)
		if name == nil or Secret(name) then name = "#" .. spell end
		names[spell] = name
	end
	return name
end

local function Guid(unit)
	local guid = UnitGUID(unit)
	if guid == nil or Secret(guid) then return nil end
	return guid
end

local function Dead(unit)
	local dead = UnitIsDead(unit)
	return not Secret(dead) and dead == true
end

-- School mask -> the index GetSpellBonusDamage takes (1 physical ... 7 arcane); the highest of several.
local function SchoolIndex(mask)
	local index, bit = 0, 1
	for i = 1, 7 do
		if mask >= bit and math.floor(mask / bit) % 2 == 1 then index = i end
		bit = bit * 2
	end
	return index
end

function K.ReadStats()
	for i = 2, 7 do
		local bonus = GetSpellBonusDamage(i)
		if bonus ~= nil and not Secret(bonus) then stats[i] = bonus end
	end
	local base, up, down = UnitAttackPower("player")
	if base ~= nil and canaccessvalue(base, up, down) then stats.attack = base + (up or 0) + (down or 0) end
end

-- Your buffs and debuffs that change the damage you deal (ns.mods: resurrection sickness, a form, a trinket),
-- read while the game lets auras be read, as one share per school.
-- Read on every UNIT_AURA of yours: the share is worked out in a table kept for it.
local AURA_FILTERS, share = { "HELPFUL", "HARMFUL" }, {}
function K.ReadModifiers()
	if C_Secrets.ShouldAurasBeSecret() then return false end
	for s = 1, 7 do share[s] = 1 end
	for _, filter in ipairs(AURA_FILTERS) do
		local i = 1
		while true do
			local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
			if aura == nil or Secret(aura) then break end
			local id = aura.spellId
			local mod = not Secret(id) and ns.mods[id]
			if mod then
				for at = 1, #mod, 2 do
					local mask, percent = mod[at], mod[at + 1]
					for s = 1, 7 do
						if math.floor(mask / 2 ^ (s - 1)) % 2 == 1 then share[s] = share[s] * (1 + percent / 100) end
					end
				end
			end
			i = i + 1
		end
	end
	for s = 1, 7 do mult[s] = share[s] end
	return true
end

local function Share(school)
	return mult[SchoolIndex(school)] or 1
end

-- Combo points for a finisher: readable at the send, else recent, else counted from builders.
local function Combo()
	local points = comboAtSend
	local source = "read"
	if not (points and points > 0) then
		if lastCombo and Now() - lastComboAt <= COMBO_FRESH then
			points, source = lastCombo, "recent"
		elseif counted > 0 then
			points, source = counted, "counted"
		else
			points, source = nil, "unknown"
		end
	end
	comboAtSend, counted, lastBuilder = nil, 0, nil
	return points, source
end

local function ReadCombo()
	local points = GetComboPoints("player", "target")
	if points == nil or Secret(points) then
		points = UnitPower("player", Enum.PowerType.ComboPoints)
		if points == nil or Secret(points) then return nil end
	end
	return points
end

-- The size the tables promise for a tick, from what is readable out of fights, before your modifiers.
local function TableTick(d, combo)
	local level = UnitLevel("player")
	local tick = d[BASE] + d[PER_LEVEL] * math.max(0, (level or 0) - d[LEVEL]) + d[POINTS_PER_COMBO] * (combo or 0)
	tick = tick + d[POWER] * (stats[SchoolIndex(d[SCHOOL])] or 0) + d[ATTACK] * stats.attack
	return math.max(1, tick)
end

-- The expected tick: this cast's own ticks, else what was learned on earlier casts, else the tables; the
-- learned and the tables' sizes are as they would be with no modifier, times the cast's share.
local function Expected(dot)
	if dot.seen > 0 then return dot.sum / dot.seen end
	return ((dot.key and T.db.ticks[dot.key]) or dot.table) * dot.mult
end

local function Ramp(dot, number)
	local ramp = dot.ramp
	if not ramp then return 1 end
	local i = math.ceil(math.min(math.max(number, 1), dot.ticks) / dot.ticks * #ramp)
	return ramp[math.max(1, math.min(i, #ramp))]
end

local function TickAt(dot, when)
	return math.max(1, math.floor((when - dot.applied) / dot.period + 0.5))
end

-- Seconds to the nearest expected tick and that tick's number: on the first tick's rhythm once seen, else the cast's.
local function Distance(dot, now)
	local anchor = dot.firstAt or dot.applied
	if not dot.firstAt and dot.flies then
		local late = now - (anchor + dot.period)
		if late > 0 then anchor = anchor + math.min(late, FLIGHT) end
	end
	local k = math.max(1, math.floor((now - anchor) / dot.period + 0.5))
	return math.abs(now - (anchor + k * dot.period)), k
end

local function Plausible(dot, amount, crit, number)
	local known, slack
	if dot.seen > 0 then
		known, slack = dot.sum / dot.seen, SLACK
	else
		known, slack = dot.key and T.db.ticks[dot.key], FIRST_SLACK
		if known then known = known * dot.mult end
	end
	if not known then return true end
	known = known * Ramp(dot, number)
	if crit then return amount >= known * CRIT_LOW - 1 and amount <= known * CRIT_HIGH + 1 end
	return math.abs(amount - known) <= math.max(1, known * slack)
end

-- This fight's count for a spell: what the damage meter's total for it will be shared over.
local function Fought(spell)
	local f = fight[spell]
	if not f then
		f = { keys = {} }
		fight[spell] = f
	end
	return f
end

-- A tick the meter counted and this didn't see, or a cast it couldn't follow: the fight can't teach the spell.
local function Unsure(spell)
	Fought(spell).unsure = true
end

-- A tick whose size was hidden, counted at the share of its size it should be (your modifiers, a ramp).
local function Tally(dot, number)
	if not dot.key then return Unsure(dot.spell) end
	local keys = Fought(dot.spell).keys
	local k = keys[dot.key]
	if not k then
		k = { weight = 0, ticks = 0, table = dot.table }
		keys[dot.key] = k
	end
	k.weight = k.weight + dot.mult * Ramp(dot, number)
	k.ticks = k.ticks + 1
end

local function Learn(dot)
	if dot.key and dot.seen > 0 then
		local first = T.db.ticks[dot.key] == nil
		T.db.ticks[dot.key] = math.floor(dot.sum / dot.seen / dot.mult * 10 + 0.5) / 10
		if first and ns.RefreshOptions then ns.RefreshOptions() end
		if fighting then Fought(dot.spell).shown = true end   -- its size showed: the meter has nothing to add
	end
end

-- What a mob's dots still have to deal.
local function Remaining(dot)
	if dot.nextAt > dot.expires + dot.period / 2 then return 0 end
	local left = math.floor((dot.expires - dot.nextAt) / dot.period + 0.5) + 1
	local tick = Expected(dot)
	if not dot.ramp then return left * tick end
	local total = 0
	for number = math.max(1, dot.ticks - left + 1), dot.ticks do total = total + tick * Ramp(dot, number) end
	return total
end

-- Whether a blow in `school` landing on a mob now is on the rhythm of one of your spells there: one of
-- its ticks, as far as can be told. For whoever writes only your own blows; it counts nothing, so it
-- answers the same before and after the blow is counted here.
function K.OnBeat(guid, school)
	local dots = mobs[guid]
	if not dots or Secret(school) then return false end
	local now = Now()
	for _, dot in pairs(dots) do
		if dot.school == school then
			-- (Counted here this very instant, its rhythm now runs from it: it was its tick.)
			if dot.lastAt == now then return true end
			if TickAt(dot, now) <= dot.ticks and Distance(dot, now) <= (dot.firstAt and WINDOW_SET or WINDOW) then return true end
		end
	end
	return false
end

function K.Coming(guid)
	local dots = mobs[guid]
	if not dots then return nil end
	local total, count = 0, 0
	for _, dot in pairs(dots) do
		if not dot.doubtful then
			total = total + Remaining(dot)
			count = count + 1
		end
	end
	total = math.floor(total + 0.5)
	if count == 0 or total <= 0 then return nil end
	return total, count
end

-- Each spell's own share, oldest first: { school, coming, name }, and the total; nil when nothing is coming.
local breakdown = {}
function K.Breakdown(guid)
	local dots = mobs[guid]
	if not dots then return nil end
	wipe(breakdown)
	local total = 0
	for name, dot in pairs(dots) do
		if not dot.doubtful then
			local coming = math.floor(Remaining(dot) + 0.5)
			if coming > 0 then
				breakdown[#breakdown + 1] = { school = dot.school, coming = coming, name = name, at = dot.applied }
				total = total + coming
			end
		end
	end
	if total <= 0 then return nil end
	table.sort(breakdown, function(a, b)
		if a.at ~= b.at then return a.at < b.at end
		return a.name < b.name
	end)
	return breakdown, total
end

local told = {}   -- guid -> what was last told on the bus
local function Tell(guid)
	local coming = K.Coming(guid) or 0
	if told[guid] ~= coming then
		told[guid] = coming ~= 0 and coming or nil
		Shy:Fire("SHY_DOTS", guid)
	end
end

-- Casts

local function Sent(target, castGUID, spell)
	local now = Now()
	for id, s in pairs(sent) do
		if now - s.at > SENT_KEEP then sent[id] = nil end
	end
	if castGUID and not Secret(castGUID) then sent[castGUID] = { guid = Guid("target"), at = now } end
	local d = ns.dots[spell]
	if d and (d[POINTS_PER_COMBO] > 0 or d[MORE_PER_COMBO] > 0) then comboAtSend = ReadCombo() end
end

local function AvoidedJustBefore(guid)
	if lastOutcome and lastOutcome.avoided and lastOutcome.guid == guid and Now() - lastOutcome.at <= LOOKBACK then
		return lastOutcome
	end
end

-- A dropped cast never landed; a recast gives the earlier one back. A spell can't be dodged, and a miss not told
-- in its school may be someone's melee: then the spell waits for its first tick instead (doubtful).
local function Drop(cast, action, school)
	local dot, dots = cast.dot, mobs[cast.guid]
	if not dots or dots[cast.name] ~= dot then return true end
	local own = type(school) == "number" and not Secret(school) and school == dot.school
	if dot.school ~= PHYSICAL and not own then
		if MELEE_AVOIDS[action] then return false end
		if not cast.previous then
			dot.doubtful = true
			Note("%s: %s right after, may be another's; waiting for its first tick", cast.name, action)
			return true
		end
	end
	if cast.previous then
		dots[cast.name] = cast.previous
		Note("%s: %s right after the recast; the earlier one stays", cast.name, action)
	else
		dots[cast.name] = nil
		Note("%s: %s; never landed", cast.name, action)
	end
	Tell(cast.guid)
	return true
end

local function Cast(spell, castGUID)
	local now = Now()
	local s = castGUID and not Secret(castGUID) and sent[castGUID]
	local guid = s and s.guid or Guid("target")
	if s then sent[castGUID] = nil end
	local award = ns.builders[spell]
	if award and guid then
		if AvoidedJustBefore(guid) then
			lastBuilder = nil
		else
			counted = math.min(5, counted + award)
			lastBuilder = { guid = guid, points = award, at = now }
		end
	end
	local d = ns.dots[spell]
	if not d then return end
	if not guid then return Unsure(spell) end   -- the meter will count its ticks; nothing here can
	local finisher = d[POINTS_PER_COMBO] > 0 or d[MORE_PER_COMBO] > 0
	local combo, source
	if finisher then combo, source = Combo() end
	local key = spell
	if finisher then key = combo and (spell .. "x" .. combo) or nil end
	local name = Name(spell)
	local period = d[PERIOD] / 1000
	local duration = (d[DURATION] + d[MORE_PER_COMBO] * (combo or 1)) / 1000
	local ticks = math.max(1, math.floor(duration / period + 0.5))
	local span = T.db.spans[spell]
	if span and span > ticks then ticks = span end
	local dots = mobs[guid]
	if not dots then
		dots = {}
		mobs[guid] = dots
	end
	local previous = dots[name]
	local dot = {
		spell = spell, key = key, school = d[SCHOOL], period = period, ticks = ticks, ramp = ns.ramps[spell],
		flies = d[FLIES] == 1, table = TableTick(d, combo or 1), mult = Share(d[SCHOOL]),
		applied = now, expires = now + ticks * period, nextAt = now + period,
		sum = 0, seen = 0, ticked = 0, missed = 0,
	}
	dots[name] = dot
	lastCast = { guid = guid, name = name, dot = dot, previous = previous, at = now }
	Note("%s cast: %d ticks of about %.0f%s", name, ticks, Expected(dot),
		finisher and (", " .. tostring(combo or "?") .. " points " .. source) or "")
	local avoided = AvoidedJustBefore(guid)
	if avoided and Drop(lastCast, avoided.action, avoided.school) then lastCast = nil end
	Tell(guid)
	K.Watch()
end

-- Hits

-- The last outcome is one table, written again for every blow that lands near you (every mob's, not only yours).
local function Outcome(guid, avoided, action, school, at)
	local o = lastOutcome or {}
	lastOutcome = o
	o.guid, o.avoided, o.action, o.school, o.at = guid, avoided, action, school, at
end

local function Avoided(guid, action, school)
	local now = Now()
	Outcome(guid, true, action, school, now)
	if lastBuilder and lastBuilder.guid == guid then
		if now - lastBuilder.at <= OUTCOME then counted = math.max(0, counted - lastBuilder.points) end
		lastBuilder = nil
	end
	if lastCast and lastCast.guid == guid then
		if now - lastCast.at > OUTCOME or Drop(lastCast, action, school) then lastCast = nil end
	end
end

local function Landed(guid, school)
	Outcome(guid, false, nil, nil, Now())
	if lastBuilder and lastBuilder.guid == guid then lastBuilder = nil end
	if lastCast and lastCast.guid == guid and (lastCast.dot.school == PHYSICAL or lastCast.dot.school == school) then
		lastCast = nil
	end
end

-- One blow is told once for every token the mob has (target, focus, nameplateN), all in one frame, each token
-- in the order they landed: a token's nth blow on a mob this frame is new only when no token told of an nth yet.
local frame = { at = 0, told = {}, tokens = {} }
local function ToldAlready(unit, guid, now)
	if frame.at ~= now then
		frame.at = now
		wipe(frame.told)
		for _, blows in pairs(frame.tokens) do wipe(blows) end
	end
	local blows = frame.tokens[unit]
	if not blows then
		blows = {}
		frame.tokens[unit] = blows
	end
	local n = (blows[guid] or 0) + 1
	blows[guid] = n
	if n <= (frame.told[guid] or 0) then return true end
	frame.told[guid] = n
	return false
end

-- The spell on a mob whose tick a blow in `school` is: on its rhythm, that tick not counted yet, the nearest
-- to its beat. A blow whose size is readable (`amount`) must be of a plausible size; one whose size is hidden
-- must fall within the run the spell promises.
local function Due(dots, school, now, amount, crit)
	local best, bestName, bestDistance, bestIndex
	for name, dot in pairs(dots) do
		if dot.school == school then
			local number = TickAt(dot, now)
			local fits
			if amount then fits = Plausible(dot, amount, crit, number) else fits = number <= dot.ticks end
			if fits then
				local distance, index = Distance(dot, now)
				local window = dot.firstAt and WINDOW_SET or WINDOW
				local last = dot.firstAt and dot.lastIndex or dot.lastSlot or 0
				if index > last and distance <= window and (not bestDistance or distance < bestDistance) then
					best, bestName, bestDistance, bestIndex = dot, name, distance, index
				end
			end
		end
	end
	return best, bestName, bestIndex
end

-- A tick whose own time is known (its size was readable, or the spell flew and this is where it landed): the
-- rhythm and the end follow it. A readable one past the promised run lengthens the run.
local function Anchor(dot, index, now)
	dot.ticked = dot.ticked + 1
	dot.missed = 0
	if dot.firstAt then
		dot.lastIndex = index
	else
		dot.firstAt, dot.lastIndex = now, 0
		if dot.flies then dot.applied = now - index * dot.period end
	end
	dot.lastAt = now
	dot.nextAt = now + dot.period
	local number = TickAt(dot, now)
	-- A tick past the promised run: the spell runs longer than the tables say (a talent). Remember it.
	if number > dot.ticks then
		dot.ticks = number
		if not dot.key or dot.key == dot.spell then
			T.db.spans[dot.spell] = math.max(T.db.spans[dot.spell] or 0, number)
		end
	end
	dot.expires = now + (dot.ticks - number) * dot.period
	return number
end

-- A tick taken on the cast's own schedule, which stands: a blow of another's, or a swing of yours, a moment
-- before the tick can't pull the spell's rhythm or its end with it.
local function Beat(dot, index)
	dot.ticked = dot.ticked + 1
	dot.missed = 0
	dot.lastSlot = index
	local nextAt = dot.applied + (index + 1) * dot.period
	if nextAt > dot.nextAt then dot.nextAt = nextAt end
	return index
end

-- A blow whose size the game hides, as every blow in a fight is: the spell in its school whose tick is due is
-- taken to have ticked. It says the spell landed and takes a tick off what is to come; it teaches no size
-- and no longer run.
local function Hidden(guid, dots, school, now)
	local dot, name, index = Due(dots, school, now)
	if not dot then return end
	local number
	if dot.firstAt or dot.flies then
		number = Anchor(dot, index, now)
	else
		number = Beat(dot, index)
	end
	dot.doubtful, dot.offBeat, dot.lastAmount = nil, nil, nil
	if fighting then Tally(dot, number) end
	Note("%s tick %d of %d: size hidden", name, number, dot.ticks)
	Tell(guid)
end

local function Hit(unit, action, flag, amount, school)
	if Secret(action) then return end
	local guid = Guid(unit)
	if not guid then return end
	if AVOIDS[action] then return Avoided(guid, action, school) end
	if action ~= "WOUND" then return end
	if Secret(school) then return end
	Landed(guid, school)
	local dots = mobs[guid]
	if not dots then return end
	local now = Now()
	if ToldAlready(unit, guid, now) then return end
	if Secret(amount) then return Hidden(guid, dots, school, now) end
	if type(amount) ~= "number" or amount == 0 then return end
	local crit = not Secret(flag) and flag == "CRITICAL"

	local best, bestName, bestIndex = Due(dots, school, now, amount, crit)
	if not best then
		-- Two hits in one slot: the nearer to the expected size is the tick.
		for name, dot in pairs(dots) do
			if dot.school == school and not crit and not dot.lastCrit and dot.lastAmount and dot.lastAt and now - dot.lastAt <= SAME_SLOT then
				local reference = (dot.seen > 1 and (dot.sum - dot.lastAmount / dot.lastRamp) / (dot.seen - 1) or dot.table) * dot.lastRamp
				if math.abs(amount - reference) < math.abs(dot.lastAmount - reference) then
					dot.sum = dot.sum + (amount - dot.lastAmount) / dot.lastRamp
					dot.lastAmount = amount
					Learn(dot)
					Note("%s: %.0f was another blow, %.0f the tick", name, dot.lastAmount, amount)
					Tell(guid)
					return
				end
			end
		end
		-- A learned size that is wrong refuses every real tick: two hits in a row on the rhythm that agree are it.
		for name, dot in pairs(dots) do
			if dot.school == school and not crit then
				local distance, index = Distance(dot, now)
				local window = dot.firstAt and WINDOW_SET or WINDOW
				local fresh = not dot.firstAt or index > dot.lastIndex
				if fresh and distance <= window then
					local ramp = Ramp(dot, TickAt(dot, now))
					local was = dot.offBeat
					dot.offBeat = { index = index, amount = amount, average = amount / ramp, at = now }
					if was and index == was.index + 1 and math.abs(amount / ramp - was.average) <= math.max(1, was.average * SLACK) then
						Note("%s: ticks of %.0f and %.0f on its rhythm didn't fit %.0f; learned again", name, was.amount, amount, Expected(dot))
						dot.offBeat = nil
						dot.sum, dot.seen = was.average + amount / ramp, 2
						dot.lastAmount, dot.lastRamp, dot.lastCrit = amount, ramp, false
						dot.doubtful = nil
						Learn(dot)
						if not dot.firstAt then
							dot.firstAt, dot.lastIndex = was.at, 0
							index = 1
						end
						Anchor(dot, index, now)
						Tell(guid)
						return
					end
				end
			end
		end
		return
	end

	local ramp = Ramp(best, TickAt(best, now))
	best.lastAmount, best.lastRamp, best.lastCrit = amount, ramp, crit
	best.offBeat = nil
	best.doubtful = nil
	if not crit then
		best.sum = best.sum + amount / ramp
		best.seen = best.seen + 1
		Learn(best)
	end
	local number = Anchor(best, bestIndex, now)
	Note("%s tick %d of %d: %.0f%s", bestName, number, best.ticks, amount, crit and " crit" or "")
	Tell(guid)
end

-- After a fight

-- The fight's one size key for a spell and its count, when the meter's total can be shared over it: every
-- tick counted and none whose size showed, no damage at once in the total, one count of combo points.
local function Teaches(spell, f)
	if f.unsure or f.shown then return nil end
	local d = ns.dots[spell]
	if not d or d[DIRECT] == 1 then return nil end
	local key, k = next(f.keys)
	if not key or next(f.keys, key) ~= nil then return nil end
	if k.ticks < METER.TICKS or k.weight <= 0 then return nil end
	return key, k
end

-- What each of your spells dealt in the fight just over, by spell, from the game's damage meter. Nil while it
-- keeps the fight secret or has nothing of it yet; false when it can't be asked.
local function MeterTotals()
	local me = Guid("player")
	if not me or not C_DamageMeter.IsDamageMeterAvailable() then
		Note("the damage meter isn't there to ask; no size learned")
		return false
	end
	local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
		Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone, me)
	if not ok then
		Note("the damage meter couldn't be asked: %s", not Secret(source) and type(source) == "string" and source or "?")
		return false
	end
	if Secret(source) or type(source) ~= "table" or not canaccesstable(source) then return nil end
	local spells = source.combatSpells
	if Secret(spells) or type(spells) ~= "table" or not canaccesstable(spells) then return nil end
	local totals
	for _, spell in ipairs(spells) do
		if Secret(spell) or type(spell) ~= "table" or not canaccesstable(spell) then return nil end
		local id, total = spell.spellID, spell.totalAmount
		if Secret(id) or Secret(total) or type(id) ~= "number" or type(total) ~= "number" then return nil end
		totals = totals or {}
		totals[id] = (totals[id] or 0) + total
	end
	return totals
end

-- A spell's tick is what it dealt over the ticks counted; halfway from the size kept to it, so one odd fight
-- can't carry the size off and a new level or weapon soon shows.
local function LearnFight(taken, totals)
	for spell, f in pairs(taken) do
		local key, k = Teaches(spell, f)
		local total = key and totals[spell]
		if total then
			local size = total / k.weight
			if size >= k.table * METER.LOW and size <= k.table * METER.HIGH then
				local kept = T.db.ticks[key]
				T.db.ticks[key] = math.floor((kept and (kept + size) / 2 or size) * 10 + 0.5) / 10
				Note("%s: %.0f over %d ticks in the fight, %.1f a tick; kept as %.1f", Name(spell), total, k.ticks, size, T.db.ticks[key])
			else
				Note("%s: %.0f over %d ticks in the fight is no tick of about %.0f; not learned", Name(spell), total, k.ticks, k.table)
			end
		end
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

local function AskMeter()
	local r = reading
	if not r then return end
	local totals = MeterTotals()
	if totals then
		reading = nil
		return LearnFight(r.fight, totals)
	end
	r.tries = r.tries - 1
	if totals == false or r.tries <= 0 then
		reading = nil
		if totals == nil then Note("the damage meter told nothing of the fight; no size learned") end
		return
	end
	C_Timer.After(METER.EVERY, function()
		if reading == r then AskMeter() end
	end)
end

-- The fight's count is taken and a new one begun, so the next pull can't mix in; the meter is asked only
-- when a spell's ticks were counted well enough to learn from.
local function FightOver()
	local taken = fight
	fighting, fight, reading = false, {}, nil
	for spell, f in pairs(taken) do
		if Teaches(spell, f) then
			reading = { fight = taken, tries = METER.TRIES }
			return AskMeter()
		end
	end
end

-- Time passing

-- Whether blows on a mob reach us: UNIT_COMBAT names the target, the focus and the nameplates. The token it
-- is seen by, or nil.
-- The GUIDs in sight are gathered once a housekeeping pass, the first time one is asked for, not once a tick
-- missed on every mob.
local sight, looked = {}, false
local function Seen(guid)
	if not looked then
		looked = true
		wipe(sight)
		local g = Guid("target")
		if g then sight[g] = "target" end
		g = Guid("focus")
		if g then sight[g] = sight[g] or "focus" end
		for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
			local unit = not nameplate:IsForbidden() and nameplate.unitToken
			if type(unit) == "string" and not Secret(unit) then
				g = Guid(unit)
				if g then sight[g] = sight[g] or unit end
			end
		end
	end
	return sight[guid]
end

local function Housekeep()
	looked = false
	local now = Now()
	for guid, dots in pairs(mobs) do
		local changed, dead = false, false
		for name, dot in pairs(dots) do
			local late = (dot.ticked == 0 and dot.flies) and FLIGHT or 0
			-- A tick's time went by and no blow was it.
			while dot.nextAt < now - WINDOW - late and dot.nextAt <= dot.expires do
				local unit = Seen(guid)
				if unit and Dead(unit) then
					dead = true
					break
				end
				dot.nextAt = dot.nextAt + dot.period
				changed = true
				if fighting then Unsure(dot.spell) end
				if dot.ticked == 0 and unit then dot.missed = dot.missed + 1 end
			end
			if dead then break end
			-- One that ticked is kept a tick past its end: a tick there says it runs longer than the tables promise.
			local grace = dot.ticked > 0 and dot.period or 0
			if now > dot.expires + grace + WINDOW then
				dots[name] = nil
				changed = true
			elseif dot.ticked == 0 and dot.missed >= MISSED then
				dots[name] = nil
				changed = true
				Note("%s never ticked; resisted or immune", name)
			end
		end
		if dead then
			-- Its ticks stopped because it died: nothing more is coming.
			mobs[guid] = nil
			Tell(guid)
		else
			if next(dots) == nil then mobs[guid] = nil end
			if changed then Tell(guid) end
		end
	end
	if next(mobs) == nil and ticker then
		ticker:Cancel()
		ticker = nil
	end
end

function K.Watch()
	if not ticker and next(mobs) then ticker = C_Timer.NewTicker(HOUSEKEEP, Housekeep) end
end

-- Events

local HANDLERS = {
	UNIT_SPELLCAST_SENT = function(_, target, castGUID, spell)
		if not T:IsOn() or Secret(spell) then return end
		Sent(target, castGUID, spell)
	end,
	UNIT_SPELLCAST_SUCCEEDED = function(_, castGUID, spell)
		if not T:IsOn() or Secret(spell) then return end
		Cast(spell, castGUID)
	end,
	UNIT_POWER_FREQUENT = function(_, kind)
		if kind ~= "COMBO_POINTS" then return end
		local points = ReadCombo()
		if points and points > 0 then lastCombo, lastComboAt = points, Now() end
	end,
	UNIT_COMBAT = function(unit, action, flag, amount, school)
		if not T:IsOn() or Secret(unit) or type(unit) ~= "string" then return end
		Hit(unit, action, flag, amount, school)
	end,
	PLAYER_TARGET_CHANGED = function()
		counted, lastBuilder = 0, nil
	end,
	-- A mob dead is a plate gone: what its spells still had to deal is nothing now, and kept no longer.
	NAME_PLATE_UNIT_REMOVED = function(unit)
		if Secret(unit) or type(unit) ~= "string" then return end
		local guid = Guid(unit)
		if not guid or not mobs[guid] or not Dead(unit) then return end
		mobs[guid] = nil
		Tell(guid)
	end,
	-- A new fight: the meter's is no longer the one whose ticks were counted.
	PLAYER_REGEN_DISABLED = function()
		fighting, reading = true, nil
	end,
	PLAYER_REGEN_ENABLED = function()
		K.ReadStats()
		K.ReadModifiers()
		FightOver()
	end,
	UNIT_AURA = function() K.ReadModifiers() end,
	PLAYER_ENTERING_WORLD = function()
		K.ReadStats()
		K.ReadModifiers()
		wipe(mobs)
		wipe(told)
		fighting, fight, reading = InCombatLockdown(), {}, nil
	end,
}

function K.Start()
	if events then return end
	events = CreateFrame("Frame")
	for event in pairs(HANDLERS) do
		if event:sub(1, 5) == "UNIT_" and event ~= "UNIT_COMBAT" then
			events:RegisterUnitEvent(event, "player")
		else
			events:RegisterEvent(event)
		end
	end
	events:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)
	fighting = InCombatLockdown()
	K.ReadStats()
	K.ReadModifiers()
end

function K.Apply()
	if not T:IsOn() then
		for guid in pairs(mobs) do
			mobs[guid] = nil
			Tell(guid)
		end
		fight, reading = {}, nil
	end
end

-- For tests and the report.
function K.Mobs() return mobs end

function K.Report()
	local out = { "ShyDots: " .. (T:IsOn() and "on" or "off") }
	local now = Now()
	for guid, dots in pairs(mobs) do
		local coming, count = K.Coming(guid)
		out[#out + 1] = ("%s: %.0f to come from %d"):format(guid, coming or 0, count or 0)
		for name, dot in pairs(dots) do
			out[#out + 1] = ("  %s: tick %.0f (%s), %d of %d ticks seen, %.1f s left%s"):format(name, Expected(dot),
				dot.seen > 0 and "seen" or (dot.key and T.db.ticks[dot.key]) and "learned" or "tables",
				dot.ticked, dot.ticks, dot.expires - now, dot.doubtful and ", doubtful" or "")
		end
	end
	for spell, f in pairs(fight) do
		local ticks = 0
		for _, k in pairs(f.keys) do ticks = ticks + k.ticks end
		out[#out + 1] = ("this fight, %s: %d ticks counted%s%s"):format(Name(spell), ticks,
			f.unsure and ", not all of them seen" or "", f.shown and ", a size showed" or "")
	end
	local learned = 0
	for _ in pairs(T.db.ticks) do learned = learned + 1 end
	out[#out + 1] = ("%d tick sizes learned; spell power %s; attack power %.0f; %s"):format(learned,
		stats[6] and tostring(stats[6]) or "unread", stats.attack,
		reading and "asking the damage meter about the last fight" or fighting and "in a fight" or "out of a fight")
	local shares = {}
	for s = 1, 7 do shares[s] = ("%.2f"):format(mult[s] or 1) end
	out[#out + 1] = "your damage's share by school (physical to arcane): " .. table.concat(shares, " ")
	out[#out + 1] = ""
	for _, line in ipairs(log) do out[#out + 1] = line end
	return table.concat(out, "\n")
end
