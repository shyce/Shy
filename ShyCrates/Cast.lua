-- Filling a crate (or opening one) is a cast. While it lasts, which crate and the time left: told to the lists every
-- tenth of a second, and not at all otherwise (its clock runs only during the cast).
--   Cast.Now()      crate, seconds left; or nil
--   Cast.Watch(fn)  fn() as a cast begins, at every tenth, and as it ends
--   Cast.Pressed(crate)   a button of ours was pressed for it: a cast of a crate's spell we don't know by number
--                   that begins soon after (one the server casts in its place) is that crate's

local ADDON, ns = ...

local Cast = {}
ns.Cast = Cast

local GUESS = 1.5   -- a fill's cast, in seconds, should the game not say
local SOON = 3      -- seconds after a press a cast of a crate's spell is taken for it
local pressed       -- { crate, at }
local names         -- the crates' spells' names (Stock Crate, Read Label), read once
local now        -- { crate, ends, cast }
local watchers = {}
local tenth

function Cast.Now()
	if now then return now.crate, math.max(0, now.ends - GetTime()) end
end

function Cast.Watch(fn) watchers[#watchers + 1] = fn end

function Cast.Pressed(crate)
	pressed = crate and { crate = crate, at = GetTime() } or nil
end

-- A crate's by its number; else, by its name, the crate pressed for a moment ago.
local function Crate(spell)
	local crate = ns.fills[spell]
	if crate or not (pressed and GetTime() - pressed.at < SOON) then return crate end
	if not names then
		names = {}
		for known in pairs(ns.fills) do
			local name = C_Spell.GetSpellName(known)
			if name then names[name] = true end
		end
	end
	local name = C_Spell.GetSpellName(spell)
	if name and not issecretvalue(name) and names[name] then return pressed.crate end
end

local function Tell()
	for _, fn in ipairs(watchers) do fn() end
end

local clock = CreateFrame("Frame")
clock:Hide()
clock:SetScript("OnUpdate", Shy.Clocked("crates: a fill's countdown", function(self)
	if not now then return self:Hide() end
	local left = math.ceil((now.ends - GetTime()) * 10)
	if left ~= tenth then
		tenth = left
		Tell()
	end
end))

local function Stop()
	if not now then return end
	now, tenth = nil, nil
	clock:Hide()
	Tell()
end

function Cast.Start()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED" }) do
		events:RegisterUnitEvent(event, "player")
	end
	events:SetScript("OnEvent", Shy.Clocked("crates: casts", function(_, event, _, cast, spell)
		if issecretvalue(spell) or issecretvalue(cast) then return end
		-- A cast ends as the one that began: by its own id.
		if event ~= "UNIT_SPELLCAST_START" then
			if now and cast == now.cast then Stop() end
			return
		end
		local crate = Crate(spell)
		if not crate then return end
		local _, _, _, _, ends = UnitCastingInfo("player")
		ends = (ends and not issecretvalue(ends)) and ends / 1000 or GetTime() + GUESS
		now, tenth, pressed = { crate = crate, ends = ends, cast = cast }, nil, nil
		clock:Show()
		Tell()
	end))
end
