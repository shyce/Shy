-- How much each of your heals heals: the client's tables at your level with your healing power, times what
-- your talents add. That last part is learned from the game's own estimate of a heal you are casting, which
-- can be read out of a fight, and kept (db.heals; db.healFamily stands in for a rank not cast yet).
-- Bus: SHY_HEAL_SIZES when any size may have changed (a share learned, your healing power, your level).

local ADDON, ns = ...
local T = ns.T
local Secret = issecretvalue

local Z = {}
ns.Sizes = Z

-- Columns of a Data/Heals.lua entry.
local BASE, PER_LEVEL, LEVEL, MOST, POWER, FAMILY = 2, 3, 4, 5, 6, 7
local LOW, HIGH = 0.5, 2.5   -- an estimate this share of the tables' is believed; any other is some other heal

local casting       -- the heal you are casting, while its estimate is listened for
local events
local said = {}     -- what sizes were last told from: power, level

-- The tables' size at your level with your healing power, before your talents.
local function Table(d)
	local level = UnitLevel("player") or 0
	if d[MOST] > 0 and level > d[MOST] then level = d[MOST] end
	return math.max(1, d[BASE] + d[PER_LEVEL] * math.max(0, level - d[LEVEL]) + d[POWER] * ns.Track.Power())
end

function Z.Size(spell)
	local d = spell and ns.heals[spell]
	if not d then return nil end
	return Table(d) * (T.db.heals[spell] or T.db.healFamily[d[FAMILY]] or 1)
end

-- Your heal on its way, as the game reckons it, against the tables'.
local function Learn(unit)
	local d = ns.heals[casting]
	local mine = UnitGetIncomingHeals(unit, "player")
	if mine == nil or Secret(mine) or mine <= 0 then return end
	local share = mine / Table(d)
	if share < LOW or share > HIGH then return end
	share = math.floor(share * 1000 + 0.5) / 1000
	if T.db.heals[casting] == share then return end
	T.db.heals[casting] = share
	T.db.healFamily[d[FAMILY]] = share
	Shy:Fire("SHY_HEAL_SIZES")
end

local function Told()
	ns.Track.ReadStats()
	local power, level = ns.Track.Power(), UnitLevel("player")
	if power == said.power and level == said.level then return end
	said.power, said.level = power, level
	Shy:Fire("SHY_HEAL_SIZES")
end

local function Cast(spell)
	casting = not Secret(spell) and ns.heals[spell] and spell or nil
	if casting then events:RegisterEvent("UNIT_HEAL_PREDICTION") end
end

local function Done()
	casting = nil
	events:UnregisterEvent("UNIT_HEAL_PREDICTION")
end

local HANDLERS = {
	UNIT_SPELLCAST_START = function(_, _, spell) Cast(spell) end,
	UNIT_SPELLCAST_STOP = Done,
	UNIT_SPELLCAST_FAILED = Done,
	UNIT_SPELLCAST_INTERRUPTED = Done,
	UNIT_HEAL_PREDICTION = function(unit)
		if casting and not Secret(unit) then Learn(unit) end
	end,
	PLAYER_EQUIPMENT_CHANGED = Told,
	PLAYER_REGEN_ENABLED = Told,
	-- (the game says your new level a moment before it gives it)
	PLAYER_LEVEL_UP = function() C_Timer.After(0, Told) end,
}

function Z.Start()
	if events then return end
	events = CreateFrame("Frame")
	for event in pairs(HANDLERS) do
		if event:sub(1, 15) == "UNIT_SPELLCAST_" then
			events:RegisterUnitEvent(event, "player")
		elseif event ~= "UNIT_HEAL_PREDICTION" then   -- only while casting
			events:RegisterEvent(event)
		end
	end
	events:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)
	said.power, said.level = ns.Track.Power(), UnitLevel("player")
end

-- For the report.
function Z.Learned()
	local n = 0
	for _ in pairs(T.db.heals) do n = n + 1 end
	return n
end
