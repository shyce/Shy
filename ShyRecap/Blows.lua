-- A short log of damage taken (UNIT_COMBAT on the player: amount and school, no source),
-- covering the part of a fight before the blows C_DeathRecap names.
-- Event order between UNIT_COMBAT and UNIT_HEALTH is not assumed: health before a blow is
-- the health one frame later plus the amount, else the health at the event, else the last
-- health above zero. Secret amounts are skipped and secret health is ignored.

local ADDON, ns = ...
local Secret = issecretvalue

local B = {}
ns.Blows = B

local KEEP = 40    -- blows
local SPAN = 60    -- seconds before a death that count as its fight
local GAP = 12     -- seconds without a blow that end a fight

local list = {}       -- oldest first: { time, amount, school, crit, was, now, after }
local pending = {}    -- this frame's blows, waiting for the health after them
local settling = false
local alive           -- last health above zero

local function Health()
	local health = UnitHealth("player")
	if Secret(health) or health == nil then return nil end
	return health
end

local function Sample()
	local health = Health()
	if health and health > 0 then alive = health end
end

-- Runs a frame later: fills in the health after each of the frame's blows, newest first.
local function Settle()
	settling = false
	local after = Health()
	for i = #pending, 1, -1 do
		local blow = pending[i]
		blow.after = after
		if after then after = after + blow.amount end
		pending[i] = nil
	end
	Sample()
end

local function Combat(unit, what, how, amount, school)
	if Secret(unit) or unit ~= "player" then return end
	if Secret(what) or what ~= "WOUND" then return end
	if Secret(amount) or type(amount) ~= "number" or amount <= 0 then return end
	local blow = { time = GetTime(), amount = amount, was = alive, now = Health() }
	if not Secret(school) and type(school) == "number" then blow.school = school end
	if not Secret(how) and (how == "CRITICAL" or how == "CRUSHING") then blow.crit = true end
	list[#list + 1] = blow
	if #list > KEEP then table.remove(list, 1) end
	pending[#pending + 1] = blow
	if not settling then
		settling = true
		C_Timer.After(0, Settle)
	end
end

local function Before(blow)
	if blow.after and blow.after > 0 then return blow.after + blow.amount end
	if blow.now and blow.now > 0 then return blow.now end
	return blow.was
end

-- The fight that just ended, oldest first: { t, amount, school, crit, before }, t in seconds before now.
-- Timed from now, not the last blow: UNIT_COMBAT for the killing blow arrives after PLAYER_DEAD.
function B.Recent()
	local out = {}
	local last = list[#list]
	local now = GetTime()
	if not last or now - last.time > GAP then return out end
	local from = #list
	for i = #list - 1, 1, -1 do
		if last.time - list[i].time > SPAN or list[i + 1].time - list[i].time > GAP then break end
		from = i
	end
	for i = from, #list do
		local blow = list[i]
		out[#out + 1] = { t = now - blow.time, amount = blow.amount, school = blow.school, crit = blow.crit, before = Before(blow) }
	end
	return out
end

function B.Clear()
	wipe(list)
	wipe(pending)
end

function B.Start()
	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_COMBAT", "player")
	events:RegisterUnitEvent("UNIT_HEALTH", "player")
	events:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_COMBAT" then Combat(...) else Sample() end
	end)
	Sample()
end
