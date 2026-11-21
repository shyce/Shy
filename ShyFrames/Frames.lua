-- The unit frames: one SecureUnitButtonTemplate button per unit, each carrying a plate.
-- Visibility is the game's: RegisterUnitWatch for single units, a state driver for party and party pets.

local ADDON, ns = ...
local T, L, Plate = ns.T, ns.Layout, ns.Plate

local F = {}
ns.Frames = F

F.list = {}    -- every frame: { key, unit, kind, group, button, plate }
F.byKey = {}

local UNITS = {
	{ key = "player", unit = "player", kind = "player" },
	{ key = "target", unit = "target", kind = "target" },
	{ key = "targettarget", unit = "targettarget", kind = "targettarget" },
	{ key = "pet", unit = "pet", kind = "pet" },
	{ key = "focus", unit = "focus", kind = "focus" },
}
for i = 1, 4 do
	UNITS[#UNITS + 1] = { key = "party" .. i, unit = "party" .. i, kind = "party", index = i }
	UNITS[#UNITS + 1] = { key = "partypet" .. i, unit = "partypet" .. i, kind = "partypet", index = i }
end
-- You, as a cell among your party's: only the healing grid has it (seat 0).
F.SELF = "partyself"
UNITS[#UNITS + 1] = { key = F.SELF, unit = "player", kind = "party", index = 0 }

local function OnEnter(self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self)
	GameTooltip:SetUnit(self:GetAttribute("unit"))
end

local function OnLeave()
	GameTooltip:Hide()
end

local function Make(def)
	local button = CreateFrame("Button", "ShyFrames_" .. def.key, UIParent, "SecureUnitButtonTemplate, PingableUnitFrameTemplate")
	button:Hide()
	-- LOW, like the default unit frames: under windows.
	button:SetFrameStrata("LOW")
	button:SetAttribute("unit", def.unit)
	button:SetAttribute("*type1", "target")
	button:SetAttribute("*type2", "togglemenu")
	-- On release only: a menu toggled on press and release would open and close.
	button:RegisterForClicks("AnyUp")
	button:SetScript("OnEnter", OnEnter)
	button:SetScript("OnLeave", OnLeave)

	local frame = { key = def.key, unit = def.unit, kind = def.kind, index = def.index, button = button, watched = false }
	-- A party member's pet is a bar at the end of its owner's cell, over it.
	if L.Of(def.kind).bars then
		frame.plate = Plate.Create(button, def.kind)
	else
		frame.plate = Plate.CreateSliver(button)
		button:SetFrameLevel(button:GetFrameLevel() + Plate.LEVELS.texts + 2)
	end
	-- ShyDock listens for "SHY_PLATE" (kind, shown).
	button:HookScript("OnShow", function()
		-- The fader first: a party member's plate then fades itself by reach.
		ns.Fader.Shown(frame)
		frame.plate:Update(true)
		Shy:Fire("SHY_PLATE", def.kind, true)
	end)
	button:HookScript("OnHide", function() Shy:Fire("SHY_PLATE", def.kind, false) end)
	frame.plate:SetUnit(def.unit)
	F.list[#F.list + 1] = frame
	F.byKey[def.key] = frame
end

-- Your health's color picked (or the accent it may be): your frame takes it at once.
local function Retone()
	local frame = F.byKey.player
	if frame and frame.plate and frame.plate.UpdateTone then frame.plate:UpdateTone() end
end
Shy:On("SHY_HEALTH", Retone)
-- ShyBuffs' rows came or went: your target's combo points' housing may stand under them (ns.Plinth).
Shy:On("SHY_BUFFS_ROWS", function()
	if F.list then F.Redraw() end
end)
Shy:On("SHY_THEME", function()
	if Shy.Skin.HealthColor() == "accent" then Retone() end
end)

function F.On(frame)
	if frame.index == 0 and not ns.Grid() then return false end
	-- A party member's pet stands in its owner's cell: without the party's frames it has nowhere to be.
	if frame.kind == "partypet" and not T.db.units.party then return false end
	return T.db.units[frame.kind] == true
end

-- The test party's members, for the seats nobody holds (ns.Sampling): one by the party's own numbers. The first
-- is its tank, and wears a shield. Healing to come as it would stand: your healing over time (`hots`: what
-- each spell still has to heal) on the health's end, a heal on its way after it (`mine`: yours; `heal`:
-- others'). The second is full, so hers stands back over the bar's end; the last has room for some of hers.
F.SAMPLES = {
	{ name = "Borin", class = "WARRIOR", hp = 2900, max = 6100, power = 40, powerMax = 100, powerType = 1, shield = 1500, mine = 900, hots = { 700 } },
	{ name = "Clara", class = "MAGE", hp = 3000, max = 3000, power = 4000, powerMax = 5000, powerType = 0, hots = { 450 } },
	{ name = "Dara", class = "ROGUE", hp = 1250, max = 3600, power = 60, powerMax = 100, powerType = 3, heal = 800 },
	{ name = "Elwenna", class = "HUNTER", hp = 2850, max = 3900, power = 2500, powerMax = 4000, powerType = 0, hots = { 700, 600 } },
}

-- When the game shows a party cell: its member is there, and you aren't in a raid. Your own, whenever you're in
-- a party. With the test party, any cell out of a fight too: the rule is the game's to follow, so a fight
-- puts the samples away and its end brings them back with nothing of ours touching a frame.
local function Shows(frame)
	local sample = (frame.kind == "party" and ns.Sampling()) and " [nocombat] show;" or ""
	if frame.index == 0 then return "[group:raid] hide; [group:party] show;" .. sample .. " hide" end
	return ("[group:raid] hide; [@%s,exists] show;%s hide"):format(frame.unit, sample)
end

-- Whether frame `key` (player, target...) is on screen. A secret IsShown counts as shown.
function F.Shown(key)
	local frame = F.byKey[key]
	if not frame or not F.On(frame) then return false end
	local shown = frame.button:IsShown()
	if issecretvalue(shown) then return true end
	return shown
end

-- Registers or unregisters the frame's visibility driver. Out of combat only; the caller checks.
function F.Watch(frame)
	local on = F.On(frame)
	-- A party cell's rule changes with the test party: told again when it does.
	local rule = on and frame.index and Shows(frame) or nil
	if frame.watched == on and frame.rule == rule then return end
	frame.watched, frame.rule = on, rule
	local button = frame.button
	if frame.index then
		if on then
			RegisterStateDriver(button, "visibility", rule)
		else
			UnregisterStateDriver(button, "visibility")
			button:Hide()
		end
	elseif on then
		RegisterUnitWatch(button)
	else
		UnregisterUnitWatch(button)
		button:Hide()
	end
end

-- The party box's cells that hold someone, in the order they stand: the party's four as the game numbers them,
-- or in the healing grid the tanks first, then you, then the rest, so the two you heal most are always the
-- first two. Seats past the last one hold whoever isn't there (they stand on past the box's end).
-- `grid`: as the grid seats them; `sample`: with the test party, whose members hold every empty seat (its first is
-- the tank). Both by default as the frames stand now.
--   -> keys in order, how many of them hold someone
function F.Seats(grid, sample)
	if grid == nil then grid = ns.Grid() end
	if sample == nil then sample = ns.Sampling() end
	local held, empty = {}, {}
	local function Seat(key, unit)
		local list = (sample or UnitExists(unit)) and held or empty
		list[#list + 1] = key
	end
	if not grid then
		for i = 1, 4 do Seat("party" .. i, "party" .. i) end
	else
		local rest = {}
		for i = 1, 4 do
			local unit = "party" .. i
			local tank
			if UnitExists(unit) then
				local role = UnitGroupRolesAssigned(unit)
				tank = not issecretvalue(role) and role == "TANK"
			else
				tank = sample and i == 1
			end
			if tank then Seat(unit, unit) else rest[#rest + 1] = unit end
		end
		held[#held + 1] = F.SELF
		for _, unit in ipairs(rest) do Seat(unit, unit) end
	end
	local count = #held
	for _, key in ipairs(empty) do held[#held + 1] = key end
	return held, count
end

-- Lays out every plate again. Only our own regions move, so it is safe in combat.
function F.Redraw()
	for _, frame in ipairs(F.list) do
		local plate = frame.plate
		plate:Arrange()
		plate:Update()
		-- An empty seat of the test party shows its sample member.
		if frame.kind == "party" and plate.Sample then
			plate:Sample(ns.Sampling() and F.SAMPLES[frame.index] or nil)
		end
	end
end

function F.Start()
	for _, def in ipairs(UNITS) do Make(def) end
end
