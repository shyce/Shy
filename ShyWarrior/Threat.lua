-- What the light round the screen says (Light.lua draws it, in your look). In any fight it rises in your color as
-- your rage nears full: the game itself puts your rage through a curve (UnitPowerPercent), dark below the share
-- set, rising to full at the cap, and its answer, which it may keep secret in a fight, goes straight to the
-- light's gate. In a group fight threat trouble takes it over while it lasts: gold as someone catches up on a
-- mob you tank (or as you near pulling one you don't), crimson once one is lost. The worst mob of the target
-- and the nameplates sets it (Shy.Threat). The aggro alarm: a tank who loses a mob hears it, the light
-- flashes, and Openings lights Taunt red.

local ADDON, ns = ...
local T = ns.T
local UI, Theme = Shy.UI, Shy.Theme

local Th = {}
ns.Threat = Th

local EVERY = 0.2            -- seconds between looks in a fight
local GLIDE = 3              -- how fast the light follows (per second)
local TROUBLE = 0.5          -- a tank's margin under this is threat trouble: it takes the light over
local DPS_FROM = 0.6         -- anyone else's
local LOST = { 0.95, 0.24, 0.32 }
local ALARM_GAP = 3          -- seconds at least between two alarm sounds
local TRY = {                -- /shywarrior light: a second each (rage as the gate would let it through)
	{ gate = 0.45 }, { gate = 1 }, { margin = 0.4 }, { margin = 0.2 }, { margin = 0 },
}

local driver
local now = { r = 1, g = 1, b = 1, a = 0 }   -- what is shown
local want = { r = 1, g = 1, b = 1, a = 0, speed = 0.25, depth = 0.1 }
local mode                   -- "rage" (the gate is your rage), "threat", "try" or nil
local tryGate = 1
local gleam = 0              -- the rim's flash: a mob lost
local margin                 -- the worst margin now (nil: nothing to say)
local held = {}              -- mob GUID -> true while you were tanking it, "lost" once it turned
local soundAt = 0
local trying                 -- the preview's start time
local flashed = false
local gateOpen = false       -- the gate is set to a plain 1

-- Your rage through the curve: 0 under the share set, 0.35 there, 0.8 just short of full, 1 at the cap.
local curve, curveFrom
local function RageCurve()
	local from = T.db.rage.from
	if curve and curveFrom == from then return curve end
	curve, curveFrom = C_CurveUtil.CreateCurve(), from
	curve:SetType(Enum.LuaCurveType.Linear)
	curve:AddPoint(0, 0)
	curve:AddPoint(from - 0.001, 0)
	curve:AddPoint(from, 0.35)
	curve:AddPoint(0.999, 0.8)
	curve:AddPoint(1, 1)
	return curve
end

local function Fighting()
	return UnitAffectingCombat("player") == true
end

-- The threat color at a margin: crimson (0) to gold (TROUBLE).
local function Trouble(m)
	local gold = UI.colors.alert
	local t = math.max(0, math.min(1, m / TROUBLE))
	return LOST[1] + (gold[1] - LOST[1]) * t, LOST[2] + (gold[2] - LOST[2]) * t, LOST[3] + (gold[3] - LOST[3]) * t
end

-- What the light should be: threat trouble at margin `m` first, else your rage in a fight.
local function Aim(m, tank)
	local from = tank and TROUBLE or DPS_FROM
	if m ~= nil and m < from then
		local worry = 1 - m / from
		mode = "threat"
		want.r, want.g, want.b = Trouble(m)
		want.a = 0.45 + 0.55 * worry
		want.speed, want.depth = 0.25 + 0.75 * worry, 0.06 + 0.24 * worry
	elseif T.db.rage.shown and Fighting() then
		mode = "rage"
		want.r, want.g, want.b = Theme.Accent()
		want.a = 1
		want.speed, want.depth = 0.45, 0.18
	else
		mode = nil
		want.a = 0
	end
end

local function Gate()
	if mode == "rage" then
		gateOpen = false
		ns.Light.Gate(UnitPowerPercent("player", Enum.PowerType.Rage, false, RageCurve()))
	elseif mode == "try" then
		gateOpen = false
		ns.Light.Gate(tryGate)
	elseif not gateOpen and (mode ~= nil or now.a < 0.01) then
		-- (Out of a fight the light fades out under the gate your rage last set: opened while it was still
		-- fading, the whole border flashed up as the fight ended.)
		gateOpen = true
		ns.Light.Gate(1)
	end
end

local function Animate(_, dt)
	local k = math.min(1, dt * GLIDE)
	now.r = now.r + (want.r - now.r) * k
	now.g = now.g + (want.g - now.g) * k
	now.b = now.b + (want.b - now.b) * k
	now.a = now.a + (want.a - now.a) * k
	if gleam > 0 then gleam = math.max(0, gleam - dt * 1.4) end
	local strength = T.db.threat.strength
	local breath = 1 - want.depth * (0.5 + 0.5 * math.sin(GetTime() * math.pi * 2 * want.speed))
	local a = now.a * strength
	Gate()
	ns.Light.Color(now.r, now.g, now.b)
	ns.Light.Strength(a * breath, math.min(1, (a > 0.01 and 0.3 or 0) + a * (0.55 + 0.45 * breath) + gleam * strength),
		math.min(0.75, a * 0.8))
	-- Faded out with nothing coming: rest.
	if want.a == 0 and now.a < 0.01 and gleam == 0 then
		now.a = 0
		ns.Light.Shown(false)
	end
end

-- The units to ask: the target and every nameplate, once each.
local function Units()
	local list = { "target" }
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		if not plate:IsForbidden() and plate.unitToken then list[#list + 1] = plate.unitToken end
	end
	return list
end

local function Guid(unit)
	local guid = UnitGUID(unit)
	if guid == nil or issecretvalue(guid) then return nil end
	return guid
end

local function Alarm()
	ns.Openings.Aggro(true)
	gleam = 1
	want.r, want.g, want.b = LOST[1], LOST[2], LOST[3]
	if T.db.threat.sound and GetTime() - soundAt > ALARM_GAP then
		soundAt = GetTime()
		PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING, "Master")
	end
end

-- The worst margin over the mobs in a group fight; for a tank, any mob you held that has turned.
local function Threat(tank)
	if not IsInGroup() then return nil end
	local worst
	local seen, regained, lost = {}, false, false
	for _, unit in ipairs(Units()) do
		local guid = Guid(unit)
		if UnitExists(unit) and UnitCanAttack("player", unit) and not (guid and seen[guid]) then
			if guid then seen[guid] = true end
			local m = Shy.Threat(unit, tank and "tank" or "dps")
			if type(m) == "number" and (worst == nil or m < worst) then worst = m end
			if tank and guid then
				local status = UnitThreatSituation("player", unit)
				if status ~= nil and not issecretvalue(status) then
					if status >= 2 then
						if held[guid] == "lost" then regained = true end
						held[guid] = true
					elseif held[guid] == true and m ~= "theirs" then
						held[guid] = "lost"
						lost = true
					end
				end
			end
		end
	end
	if lost and T.db.threat.alarm then Alarm() end
	if regained then ns.Openings.Aggro(false) end
	return worst
end

local function Look()
	local tank = ns.IsTank()
	margin = Threat(tank)
	Aim(T.db.threat.glow and margin or nil, tank)
	if want.a > 0 or gleam > 0 then ns.Light.Shown(true) end
end

local function Wake()
	if trying then return end
	if Fighting() then
		driver:Show()
		Look()
	else
		driver:Hide()
		wipe(held)
		margin, mode, want.a = nil, nil, 0
		ns.Openings.Aggro(false)
	end
end

-- Shows the light as rage fills and caps, then as threat slips and is lost: a second at each step.
function Th.Try()
	trying, flashed = GetTime(), false
	ns.Light.Shown(true)
	driver:Show()
end

local function Trying()
	local step = math.floor(GetTime() - trying) + 1
	local s = TRY[step]
	if not s then
		trying, mode = nil, nil
		want.a = 0
		Wake()
		return
	end
	if s.gate then
		mode, tryGate = "try", s.gate
		want.r, want.g, want.b = Theme.Accent()
		want.a, want.speed, want.depth = 1, 0.45, 0.18
	else
		Aim(s.margin, true)
		if s.margin == 0 and not flashed then
			flashed = true
			gleam = 1
		end
	end
end

function ns.SetupThreat()
	ns.Light.Setup(Animate)

	driver = CreateFrame("Frame")
	driver:Hide()
	local wait = 0
	driver:SetScript("OnUpdate", function(_, dt)
		wait = wait - dt
		if wait > 0 then return end
		wait = EVERY
		if trying then
			Trying()
			ns.Light.Shown(true)
			return
		end
		Look()
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE",
		"PLAYER_ROLES_ASSIGNED", "UPDATE_SHAPESHIFT_FORM" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", Wake)
	Shy:On("SHY_ROLE", Wake)
	table.insert(ns.refreshers, Wake)
	Wake()
end
