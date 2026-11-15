-- What the game says about the threat on one mob, for everyone in your group.
--
-- The mob: the nameplate under the mouse in a fight (db.hover), else your target, else (your target a friend, as a
-- healer's is) your target's target. Each member and pet is asked UnitDetailedThreatSituation(member, mob):
--   scaled    how close they are to pulling it, 100 at the pull; the one holding it is at 100
--   raw       their threat as a share of the holder's (a melee attacker pulls at 110, a ranged one at 130)
--   status    the game's own state, 0 to 3, as its aggro display colors it (UnitThreatSituation)
-- On a boss the numbers are secret (SecretWhenUnitThreatValuesRestricted): they still go straight to the bars and
-- the words, but nothing can sort by them, so the rows stand by the game's state, then in group order. The state
-- is readable there (SecretWhenUnitThreatStateRestricted spares a group member against a boss).
--
--   Rd.Look()     reads the game: Rd.mob, Rd.rows (shown order), Rd.sorted (false: in group order), Rd.margin
--                 (Shy.Threat's for you on the mob: what the header's light says)
--   Rd.Sample()   a made-up fight's rows, for layout mode, the test and the options' preview
--   Rd.Report()   what the game answers, for a copy box

local ADDON, ns = ...
local T = ns.T

local Rd = { rows = {}, sorted = true }
ns.Read = Rd

local function Secret(v) return issecretvalue(v) end
local function Readable(v) return v ~= nil and not issecretvalue(v) end

-- A unit we can fight: it exists, is no friend and is alive. False when the game won't say.
local function Hostile(unit)
	if not UnitExists(unit) then return false end
	local can = UnitCanAttack("player", unit)
	if Secret(can) or not can then return false end
	local dead = UnitIsDeadOrGhost(unit)
	return not Secret(dead) and not dead
end

-- The mob the meter reads.
function Rd.Mob()
	if T.db.hover and UnitAffectingCombat("player") and Hostile("mouseover") and C_NamePlate.GetNamePlateForUnit("mouseover") then
		return "mouseover"
	end
	if Hostile("target") then return "target" end
	if UnitExists("target") and not Hostile("target") and Hostile("targettarget") then return "targettarget" end
	return nil
end

-- Everyone who may be on its list, each once: the raid's units hold you and your pet too.
local function Members()
	local list = {}
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			list[#list + 1] = { "raid" .. i }
			if T.db.pets then list[#list + 1] = { "raidpet" .. i, "raid" .. i } end
		end
	else
		list[1] = { "player" }
		if T.db.pets then list[2] = { "pet", "player" } end
		for i = 1, 4 do
			list[#list + 1] = { "party" .. i }
			if T.db.pets then list[#list + 1] = { "partypet" .. i, "party" .. i } end
		end
	end
	return list
end

-- Whether a group unit is you: by GUID, where the game tells it.
local function IsMe(unit)
	if unit == "player" then return true end
	local a, b = UnitGUID(unit), UnitGUID("player")
	return Readable(a) and Readable(b) and a == b
end

-- One member's standing on the mob, or nil when they aren't on its list.
local function Standing(unit, owner, mob, order)
	if not UnitExists(unit) then return nil end
	local status = UnitThreatSituation(unit, mob)
	if status == nil then return nil end   -- not on the list (a secret is never nil)
	local tanking, _, scaled, raw = UnitDetailedThreatSituation(unit, mob)
	local _, class = UnitClass(owner or unit)
	local row = {
		unit = unit, owner = owner, pet = owner ~= nil, order = order,
		name = UnitName(unit), class = class,
		status = status, tanking = tanking, scaled = scaled, raw = raw,
		me = not owner and IsMe(unit),
	}
	row.readable = Readable(raw) and Readable(scaled)
	-- The holder's lead over the next player (UnitThreatPercentageOfLead: their threat as a share of the next one's).
	if Readable(tanking) and tanking then
		local lead = UnitThreatPercentageOfLead(unit, mob)
		if Readable(lead) then row.lead = lead end
	end
	-- Where it stands: the holder first, then by share where the game tells it, else by the game's state.
	if row.readable then
		row.rank = raw + ((Readable(tanking) and tanking) and 1000 or 0)
	elseif Readable(status) then
		row.rank = status * 25 + (status == 3 and 1000 or 0)
	else
		row.rank = 0
	end
	return row
end

local function Order(a, b)
	if a.rank ~= b.rank then return a.rank > b.rank end
	return a.order < b.order
end

-- Whether you fight alone: in no group, with no pet. A threat meter then has one row and nothing to say.
function Rd.Alone()
	return not IsInGroup() and not UnitExists("pet")
end

-- Reads the game. Returns whether there is anything to show.
function Rd.Look()
	local mob = Rd.Mob()
	local rows = {}
	local sorted = true
	if mob then
		for i, m in ipairs(Members()) do
			local row = Standing(m[1], m[2], mob, i)
			if row then
				rows[#rows + 1] = row
				if not row.readable then sorted = false end
			end
		end
		table.sort(rows, Order)
	end
	-- Only you (and your pet) on the list, out of a group: nothing a meter says that the plate doesn't, unless asked.
	if T.db.when == "group" and not IsInGroup() then wipe(rows) end
	-- You alone on it (no group, no pet): there is nobody to be ahead of or behind, so no table at all, unless
	-- the meter is asked to stand always.
	if #rows < 2 and T.db.when ~= "always" and Rd.Alone() then wipe(rows) end
	Rd.mob, Rd.rows, Rd.sorted = #rows > 0 and mob or nil, rows, sorted
	Rd.name = Rd.mob and UnitName(mob) or nil
	Rd.margin = Rd.mob and Shy.Threat(mob, T:IsTank() and "tank" or "dps") or nil
	return #rows > 0
end

-- The rows to draw: the first `most`, your own in the last place when it would fall out.
function Rd.Shown(rows, most)
	if #rows <= most then return rows end
	local out = {}
	for i = 1, most do out[i] = rows[i] end
	for i = most + 1, #rows do
		if rows[i].me then
			out[most] = rows[i]
			break
		end
	end
	return out
end

-- A made-up fight: a warrior holds it with a good lead, a mage creeps up on the pull, you in the middle.
local SAMPLE = {
	{ name = "Brannoc", class = "WARRIOR", status = 3, tanking = true, scaled = 100, raw = 100, lead = 128 },
	{ name = "Ysolde", class = "MAGE", status = 1, scaled = 86, raw = 112 },
	{ name = "You", class = nil, status = 0, scaled = 61, raw = 79, me = true },
	{ name = "Thessaly", class = "ROGUE", status = 0, scaled = 48, raw = 53 },
	{ name = "Wolf", class = "HUNTER", pet = true, status = 0, scaled = 30, raw = 39 },
	{ name = "Merrow", class = "PRIEST", status = 0, scaled = 22, raw = 29 },
	{ name = "Odric", class = "HUNTER", status = 0, scaled = 17, raw = 22 },
}
function Rd.Sample()
	local _, class = UnitClass("player")
	local rows = {}
	for i, s in ipairs(SAMPLE) do
		local row = {}
		for k, v in pairs(s) do row[k] = v end
		if row.me then
			row.class = not Secret(class) and class or "PALADIN"
			local name = UnitName("player")
			if Readable(name) then row.name = name end
		end
		row.readable, row.order = true, i
		rows[i] = row
	end
	return rows, "Defias Overseer"
end

function Rd.Report()
	local function Say(...)
		local out = {}
		for i = 1, select("#", ...) do
			local v = (select(i, ...))
			out[i] = Secret(v) and "secret" or tostring(v)
		end
		return table.concat(out, ", ")
	end
	local mob = Rd.Mob()
	local lines = { "ShyThreat", "reading: " .. tostring(mob) .. "; in a group: " .. tostring(IsInGroup())
		.. "; raid: " .. tostring(IsInRaid()) .. "; tank: " .. tostring(T:IsTank()) .. " (setting " .. tostring(T.db.role) .. ")" }
	if mob then
		lines[#lines + 1] = "you, Shy.Threat: " .. Say(Shy.Threat(mob, T:IsTank() and "tank" or "dps"))
		for i, m in ipairs(Members()) do
			if UnitExists(m[1]) then
				lines[#lines + 1] = ("%s: situation %s; detailed (tanking, status, scaled, raw, threat) %s; lead %s"):format(
					m[1], Say(UnitThreatSituation(m[1], mob)), Say(UnitDetailedThreatSituation(m[1], mob)),
					Say(UnitThreatPercentageOfLead(m[1], mob)))
			end
		end
	end
	return table.concat(lines, "\n")
end
