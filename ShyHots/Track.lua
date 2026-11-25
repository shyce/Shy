-- Follows your heals over time on each friend and says what they still have to heal.
--
-- Auras are secret in a fight, and so are health and the size of every heal, so nothing here reads them
-- there. A spell is known from its cast: UNIT_SPELLCAST_SENT names who it is for (whoever you cast on: your
-- target, a frame you clicked, yourself), UNIT_SPELLCAST_SUCCEEDED the spell, and Data/Hots.lua what the
-- client's tables say about its ticks. A heal can't miss, so from the cast on its ticks are counted off by
-- the clock: what is still to come is the ticks left times the tick.
-- Out of a fight the game lets the aura be read: its own end is taken (a longer run than the tables promise,
-- a talent's, is kept: db.spans), and one that is gone (dispelled, clicked off) is dropped. Whoever dies has
-- nothing more coming.
-- A tick's size is the tables' with your healing power, times a share learned and kept (db.shares): what
-- your talents add, read off a tick whose size shows (out of a fight) on someone still hurt enough for all
-- of it to count.

local ADDON, ns = ...
local T = ns.T
local Secret = issecretvalue

local K = {}
ns.Track = K

-- Columns of a Data/Hots.lua entry.
local SCHOOL, DURATION, PERIOD, BASE, PER_LEVEL, LEVEL, MOST, POWER, FAMILY = 1, 2, 3, 4, 5, 6, 7, 8, 9

local HOUSEKEEP = 0.25
local LAG = 0.15             -- seconds a tick is still counted as to come after its time: the server's is a little behind
local GRACE = 1              -- seconds after a cast before a missing aura means the spell is gone
local WINDOW = 0.45          -- seconds either side of a tick's time within which a heal can be that tick
local LOW, HIGH = 0.5, 2.5   -- a tick this share of the tables' is believed at once; any other must come twice
local AGREE = 0.15           -- share two ticks in a row may differ and still be the same size
local SENT_KEEP = 10
local LOG = 60
local MINE = "HELPFUL|PLAYER"

-- Who a cast can be for, by name: the likeliest first.
local NEAR = { "target", "mouseover", "focus", "player", "pet" }
for i = 1, 4 do NEAR[#NEAR + 1] = "party" .. i end
for i = 1, 4 do NEAR[#NEAR + 1] = "partypet" .. i end
local RAID = {}
for i = 1, 40 do RAID[i] = "raid" .. i end

local friends = {}       -- guid -> { [spell name] = hot }
local sent = {}          -- castGUID -> { guid, at }
local power = 0          -- your healing power, read out of fights
local log = {}
local names = {}         -- spell -> name
local ticker, events

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

-- A token for a friend being followed, or nil when the game won't say.
local function Unit(guid)
	local unit = UnitTokenFromGUID(guid)
	if unit == nil or Secret(unit) then return nil end
	return unit
end

local function Dead(unit)
	local dead = UnitIsDeadOrGhost(unit)
	return not Secret(dead) and dead == true
end

function K.ReadStats()
	local bonus = GetSpellBonusHealing()
	if bonus ~= nil and not Secret(bonus) then power = bonus end
end

function K.Power() return power end

-- Whether a unit is who a cast names: by its name alone, or its name with what the game adds to it.
local function Named(unit, target)
	local name = UnitName(unit)
	if name == nil or Secret(name) or name == "" then return false end
	if name == target then return true end
	local after = target:sub(#name + 1, #name + 1)
	return target:sub(1, #name) == name and (after == "-" or after == " ")
end

-- Who a cast is for. The game may keep the name: then nobody is guessed at.
local function Who(target)
	if type(target) ~= "string" or Secret(target) or target == "" then return nil end
	for _, unit in ipairs(NEAR) do
		if Named(unit, target) then return Guid(unit) end
	end
	if IsInRaid() then
		for _, unit in ipairs(RAID) do
			if Named(unit, target) then return Guid(unit) end
		end
	end
	return nil
end

-- The size the tables promise for a tick, with your healing power, before what your talents add.
local function TableTick(d)
	local level = UnitLevel("player") or 0
	if d[MOST] > 0 and level > d[MOST] then level = d[MOST] end
	return math.max(1, d[BASE] + d[PER_LEVEL] * math.max(0, level - d[LEVEL]) + d[POWER] * power)
end

-- What was learned of a spell's tick over the tables': this rank's, else its family's, else nothing more.
local function Share(spell, d)
	return T.db.shares[spell] or T.db.family[d[FAMILY]] or 1
end

-- Ticks still to come: one for every tick's time not yet reached, counted back from the end.
local function Left(hot, now)
	local span = hot.expires + LAG - now
	if span <= 0 then return 0 end
	return math.min(hot.ticks, math.ceil(span / hot.period))
end

local function Remaining(hot, now)
	return Left(hot, now) * hot.table * hot.share
end

function K.Coming(guid)
	local hots = friends[guid]
	if not hots then return nil end
	local now = Now()
	local total, count = 0, 0
	for _, hot in pairs(hots) do
		local coming = Remaining(hot, now)
		if coming > 0 then
			total = total + coming
			count = count + 1
		end
	end
	total = math.floor(total + 0.5)
	if count == 0 or total <= 0 then return nil end
	return total, count
end

-- Each spell's own share, oldest first: { school, coming, name }, and the total; nil when nothing is coming.
-- One list and its entries, filled again by every call (asked on every change of a friend's health).
local breakdown, pool = {}, {}
local function Older(a, b)
	if a.at ~= b.at then return a.at < b.at end
	return a.name < b.name
end
function K.Breakdown(guid)
	local hots = friends[guid]
	if not hots then return nil end
	local now = Now()
	local n, total = 0, 0
	for name, hot in pairs(hots) do
		local coming = math.floor(Remaining(hot, now) + 0.5)
		if coming > 0 then
			n = n + 1
			local entry = pool[n]
			if not entry then
				entry = {}
				pool[n] = entry
			end
			entry.school, entry.coming, entry.name, entry.at = hot.school, coming, name, hot.applied
			breakdown[n] = entry
			total = total + coming
		end
	end
	for i = n + 1, #breakdown do breakdown[i] = nil end
	if total <= 0 then return nil end
	table.sort(breakdown, Older)
	return breakdown, total
end

local told = {}   -- guid -> what was last told on the bus
local function Tell(guid)
	local coming = K.Coming(guid) or 0
	if told[guid] ~= coming then
		told[guid] = coming ~= 0 and coming or nil
		Shy:Fire("SHY_HOTS", guid)
	end
end

-- Casts

local function Sent(target, castGUID, spell)
	local now = Now()
	for id, s in pairs(sent) do
		if now - s.at > SENT_KEEP then sent[id] = nil end
	end
	if not ns.hots[spell] or castGUID == nil or Secret(castGUID) then return end
	sent[castGUID] = { guid = Who(target), at = now }
end

local function Cast(spell, castGUID)
	local d = ns.hots[spell]
	if not d then return end
	local s = castGUID ~= nil and not Secret(castGUID) and sent[castGUID]
	if s then sent[castGUID] = nil end
	local name = Name(spell)
	local guid = s and s.guid
	if not guid then
		Note("%s cast: on nobody the game named; not followed", name)
		return
	end
	local now = Now()
	local period = d[PERIOD] / 1000
	local ticks = math.max(1, math.floor(d[DURATION] / d[PERIOD] + 0.5))
	local span = T.db.spans[spell]
	if span and span > ticks then ticks = span end
	local hots = friends[guid]
	if not hots then
		hots = {}
		friends[guid] = hots
	end
	-- Cast again, it starts again: the one before is replaced.
	local hot = {
		spell = spell, school = d[SCHOOL], period = period, ticks = ticks, table = TableTick(d), share = Share(spell, d),
		applied = now, expires = now + ticks * period, left = ticks, beat = 0,
	}
	hots[name] = hot
	Note("%s cast: %d ticks of about %.0f", name, ticks, hot.table * hot.share)
	Tell(guid)
	K.Watch()
end

-- Learning

-- One heal is told once for every token its friend has (player, party1, target), all at one time: the
-- second telling of the same size and school on the same friend is the first again.
local last = { at = -1 }
local function ToldAlready(guid, amount, school, now)
	if last.at == now and last.guid == guid and last.amount == amount and last.school == school then return true end
	last.at, last.guid, last.amount, last.school = now, guid, amount, school
	return false
end

local function Learn(guid, name, hot, share)
	share = math.floor(share * 1000 + 0.5) / 1000
	T.db.shares[hot.spell] = share
	T.db.family[ns.hots[hot.spell][FAMILY]] = share
	hot.share, hot.odd = share, nil
	Note("%s: a tick of %.0f where the tables say %.0f; kept as %.3f of them", name, hot.table * share, hot.table, share)
	if ns.RefreshOptions then ns.RefreshOptions() end
	Tell(guid)
end

-- A heal whose size shows, on a friend with one spell of yours whose tick is due: that tick's size. Only on
-- someone hurt by at least as much, so none of it can have been wasted and gone unsaid.
local function Healed(unit, flag, amount, school)
	if Secret(amount) or type(amount) ~= "number" or amount <= 0 then return end
	if Secret(flag) or flag == "CRITICAL" then return end
	local guid = Guid(unit)
	local hots = guid and friends[guid]
	if not hots then return end
	local now = Now()
	if Secret(school) or type(school) ~= "number" then school = nil end
	if ToldAlready(guid, amount, school, now) then return end
	local hp, max = UnitHealth(unit), UnitHealthMax(unit)
	if Secret(hp) or Secret(max) or type(hp) ~= "number" or type(max) ~= "number" or max - hp < amount then return end
	local found, foundName, foundBeat
	for name, hot in pairs(hots) do
		if school == nil or school == hot.school then
			local beat = math.floor((now - hot.applied) / hot.period + 0.5)
			if beat >= 1 and beat <= hot.ticks and beat > hot.beat and math.abs(now - (hot.applied + beat * hot.period)) <= WINDOW then
				if found then return end   -- two of yours tick together: whose it is can't be told
				found, foundName, foundBeat = hot, name, beat
			end
		end
	end
	if not found then return end
	found.beat = foundBeat
	local share = amount / found.table
	if share >= LOW and share <= HIGH then
		if math.abs(share - found.share) > 0.001 then Learn(guid, foundName, found, share) end
		return
	end
	-- Far from the tables' size (they don't say all there is to some spells): the next tick must agree.
	local odd = found.odd
	found.odd = { beat = foundBeat, share = share }
	if odd and odd.beat == foundBeat - 1 and math.abs(share - odd.share) <= math.max(odd.share, share) * AGREE then
		Learn(guid, foundName, found, share)
	end
end

-- Time passing

local function Housekeep()
	local now = Now()
	local readable = not C_Secrets.ShouldAurasBeSecret()
	for guid, hots in pairs(friends) do
		local unit = Unit(guid)
		local changed = false
		if unit and Dead(unit) then
			wipe(hots)
			changed = true
		end
		for name, hot in pairs(hots) do
			if readable and unit and now - hot.applied > GRACE then
				local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, MINE)
				if aura == nil then
					hots[name] = nil
					changed = true
					Note("%s: gone before its end", name)
				elseif not Secret(aura) then
					local ends = aura.expirationTime
					if type(ends) == "number" and not Secret(ends) and ends > now then
						hot.expires = ends
						-- It runs longer than the tables promise (a talent): so will the next, in a fight too.
						local ticks = math.floor((ends - hot.applied) / hot.period + 0.5)
						if ticks > hot.ticks then
							hot.ticks = ticks
							T.db.spans[hot.spell] = ticks
						end
					end
				end
			end
			if hots[name] then
				local left = Left(hot, now)
				if left ~= hot.left then
					hot.left = left
					changed = true
				end
				if left == 0 then hots[name] = nil end
			end
		end
		if next(hots) == nil then friends[guid] = nil end
		if changed then Tell(guid) end
	end
	if next(friends) == nil and ticker then
		ticker:Cancel()
		ticker = nil
		events:UnregisterEvent("UNIT_COMBAT")
	end
end

-- The clock runs, and heals are listened for (every unit's, so only then), while something is followed.
function K.Watch()
	if not ticker and next(friends) then
		ticker = C_Timer.NewTicker(HOUSEKEEP, Housekeep)
		events:RegisterEvent("UNIT_COMBAT")
	end
end

-- Events

local function Forget()
	for guid in pairs(friends) do
		friends[guid] = nil
		Tell(guid)
	end
	wipe(sent)
end

local HANDLERS = {
	UNIT_SPELLCAST_SENT = function(_, target, castGUID, spell)
		if not T:IsOn() or Secret(spell) then return end
		Sent(target, castGUID, spell)
	end,
	UNIT_SPELLCAST_SUCCEEDED = function(_, castGUID, spell)
		if not T:IsOn() or Secret(spell) then return end
		Cast(spell, castGUID)
	end,
	UNIT_COMBAT = function(unit, action, flag, amount, school)
		if Secret(unit) or type(unit) ~= "string" or Secret(action) or action ~= "HEAL" then return end
		Healed(unit, flag, amount, school)
	end,
	PLAYER_REGEN_ENABLED = function() K.ReadStats() end,
	PLAYER_ENTERING_WORLD = function()
		K.ReadStats()
		Forget()
	end,
}

function K.Start()
	if events then return end
	events = CreateFrame("Frame")
	for event in pairs(HANDLERS) do
		if event:sub(1, 15) == "UNIT_SPELLCAST_" then
			events:RegisterUnitEvent(event, "player")
		elseif event ~= "UNIT_COMBAT" then   -- K.Watch
			events:RegisterEvent(event)
		end
	end
	events:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)
	K.ReadStats()
end

function K.Apply()
	if not T:IsOn() then Forget() end
end

-- For tests and the report.
function K.Friends() return friends end
K.Housekeep = Housekeep

function K.Report()
	local out = { "ShyHots: " .. (T:IsOn() and "on" or "off") }
	local now = Now()
	for guid, hots in pairs(friends) do
		local coming, count = K.Coming(guid)
		out[#out + 1] = ("%s: %.0f to come from %d"):format(guid, coming or 0, count or 0)
		for name, hot in pairs(hots) do
			out[#out + 1] = ("  %s: tick %.0f (%s), %d of %d ticks left, %.1f s left"):format(name, hot.table * hot.share,
				hot.share ~= 1 and "learned" or "tables", Left(hot, now), hot.ticks, hot.expires - now)
		end
	end
	local learned = 0
	for _ in pairs(T.db.shares) do learned = learned + 1 end
	out[#out + 1] = ("%d tick sizes and %d heal sizes learned; healing power %.0f"):format(learned, ns.Sizes.Learned(), power)
	out[#out + 1] = ""
	for _, line in ipairs(log) do out[#out + 1] = line end
	return table.concat(out, "\n")
end
