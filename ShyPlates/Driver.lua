-- Attaches a plate to each nameplate, hides Blizzard's unit frame, and routes global events to every plate.
--
-- Blizzard's UnitFrame is reparented to a hidden frame and otherwise untouched (it sets its own alpha, so
-- fading won't hold; its events stay on, so it is correct when put back). WidgetContainer and SoftTargetFrame
-- stay on the nameplate. Never write a field on a Blizzard frame or call a Blizzard nameplate function: taint.
-- Left to Blizzard: forbidden nameplates (friends in instances), the player's own, widget-only and object plates.
-- The hit test uses plate.bounds, set again after each Blizzard UpdateHitTestArea; the stacking bounds are
-- plate.berth, the whole plate, so the game's stacking keeps one plate's debuffs and cast row off the next.

local ADDON, ns = ...
local T, L, U, P = ns.T, ns.Layout, ns.Units, ns.Plate
local Secret = ns.Secret

local D = {}
ns.Driver = D

local SPARES = 12          -- plates built ahead of need
local HOVER_TICK = 0.1     -- there is an event for mouseover gained, none for lost

local active = {}          -- nameplate -> our plate on it
local byUnit = {}          -- unit token -> our plate
local spares = {}
local stood = {}           -- nameplate -> the Blizzard UnitFrame hidden on it
local owner = setmetatable({}, { __mode = "k" })    -- Blizzard UnitFrame -> its nameplate
local hooked = setmetatable({}, { __mode = "k" })   -- Blizzard UnitFrames with our UpdateHitTestArea hook
local hidden, store        -- never shown: parents for hidden Blizzard frames and for spares
local hoverTicker
local started = false

-- Spares

local builtAt   -- the frame (GetTime) a plate was last built on
local function NewPlate()
	builtAt = GetTime()
	local plate = P.Create(store, U)
	plate.root:Hide()
	return plate
end

-- Builds two spares a tenth of a second out of a fight until the store is full. In one, a pull that brings more
-- plates than the store holds would build each on the spot, several on one frame: so the store is filled again a
-- plate a frame, and never on a frame that has built one already. A build the game refuses in a fight waits for
-- its end, as it always did, and is said once.
local stocking, refused = false, false
local onScreen = 0   -- plates of ours on nameplates now
local function Stock()
	-- In a fight the store grows toward what is on screen (a second pull as large as this one), up to twice its size.
	-- (PLAYER_REGEN_DISABLED comes a moment before the lockdown does: the fight is yours already.)
	local fighting = InCombatLockdown() or UnitAffectingCombat("player")
	local want = SPARES
	if fighting then want = math.min(math.max(SPARES, onScreen), SPARES * 2) end
	if #spares >= want then
		stocking = false
		return
	end
	stocking = true
	if not fighting then
		for _ = 1, 2 do spares[#spares + 1] = NewPlate() end
		C_Timer.After(0.1, Stock)
	elseif refused then
		C_Timer.After(0.1, Stock)
	else
		if builtAt ~= GetTime() then
			local ok, plate = pcall(NewPlate)
			if ok then
				spares[#spares + 1] = plate
			else
				refused = true
				geterrorhandler()(plate)
			end
		end
		C_Timer.After(0, Stock)
	end
end

local function Acquire()
	local plate = table.remove(spares) or NewPlate()
	-- Stocked from the next frame: this one is already busy with the plate that came.
	if not stocking then
		stocking = true
		C_Timer.After(0, Stock)
	end
	return plate
end

-- Plates on screen by GUID, and those whose GUID the game kept from us: a change named by GUID (your target,
-- the mouse, ShyDots' word) goes to the one plate it is about, and to those that can't be told apart.
local byGuid, blind = {}, {}
local function Index(plate)
	onScreen = onScreen + 1
	if plate.guid then byGuid[plate.guid] = plate else blind[plate] = true end
end
local function Unindex(plate)
	if plate.nameplate then onScreen = math.max(0, onScreen - 1) end
	if plate.guid and byGuid[plate.guid] == plate then byGuid[plate.guid] = nil end
	blind[plate] = nil
end

local function Release(plate)
	Unindex(plate)
	plate:Clear()
	plate.nameplate = nil
	plate.root:SetParent(store)
	plate.root:ClearAllPoints()
	spares[#spares + 1] = plate
end

-- Blizzard's frame

local function Claim(nameplate, plate)
	if nameplate:CanChangeHitTestPoints() then nameplate:SetAllHitTestPoints(plate.bounds) end
end

local function StandDown(nameplate)
	local frame = nameplate.UnitFrame
	if not frame or frame:IsForbidden() then return false end
	frame:SetParent(hidden)
	frame.WidgetContainer:SetParent(nameplate)
	frame.SoftTargetFrame:SetParent(nameplate)
	stood[nameplate] = frame
	owner[frame] = nameplate
	if not hooked[frame] then
		hooked[frame] = true
		-- Blizzard just reset the hit test area: set ours again.
		hooksecurefunc(frame, "UpdateHitTestArea", function(self)
			local plate = active[owner[self]]
			if plate then Claim(plate.nameplate, plate) end
		end)
	end
	return true
end

-- Returns the two children to the UnitFrame; with `back`, also the UnitFrame to the nameplate.
local function StandUp(nameplate, back)
	local frame = stood[nameplate]
	if not frame then return end
	stood[nameplate] = nil
	owner[frame] = nil
	frame.WidgetContainer:SetParent(frame)
	frame.SoftTargetFrame:SetParent(frame)
	if back and nameplate.UnitFrame == frame then
		frame:SetParent(nameplate)
		nameplate:SetStackingBoundsFrame(frame)
		if nameplate:CanChangeHitTestPoints() then nameplate:SetAllHitTestPoints(frame) end
	end
end

-- A nameplate we used that now holds a unit left to Blizzard still has our stacking bounds: reset them.
local claimed = setmetatable({}, { __mode = "k" })
local function Unclaim(nameplate)
	if not claimed[nameplate] then return end
	claimed[nameplate] = nil
	local frame = nameplate.UnitFrame
	if frame and not frame:IsForbidden() then nameplate:SetStackingBoundsFrame(frame) end
end

-- Units added and removed

-- The player's own nameplate is found by frame, as Blizzard does: UnitIsUnit can be secret.
local function Ours(unit, nameplate)
	if nameplate == C_NamePlate.GetNamePlateForUnit("player") then return false end
	if UnitNameplateShowsWidgetsOnly(unit) or UnitIsGameObject(unit) then return false end
	return true
end

local function Removed(unit)
	local plate = byUnit[unit]
	if not plate then return end
	byUnit[unit] = nil
	local nameplate = plate.nameplate
	active[nameplate] = nil
	-- Fired before the plate detaches, so listeners anchored to it (ShyHits) can let go first.
	Shy:Fire("SHY_NAMEPLATE_GONE", nameplate, unit)
	StandUp(nameplate, false)   -- Blizzard is releasing the frame itself
	Release(plate)
end

local function Added(unit)
	if Secret(unit) or type(unit) ~= "string" then return end
	if byUnit[unit] then Removed(unit) end
	local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
	if not nameplate or nameplate:IsForbidden() then return end
	if not T:IsOn() or not Ours(unit, nameplate) or not StandDown(nameplate) then
		Unclaim(nameplate)
		return
	end
	claimed[nameplate] = true

	local plate = Acquire()
	plate.nameplate = nameplate
	active[nameplate], byUnit[unit] = plate, plate
	plate.root:SetParent(nameplate)
	plate.root:ClearAllPoints()
	plate.root:SetPoint("BOTTOM", nameplate, "BOTTOM", 0, L.LIFT)
	plate:SetUnit(unit)
	Index(plate)
	Claim(nameplate, plate)
	nameplate:SetStackingBoundsFrame(plate.berth)
	Shy:Fire("SHY_NAMEPLATE", unit)
end

-- Brings every nameplate in line with the on/off switch. Switching off resets hit test points,
-- which can't be done in combat, so it waits for PLAYER_REGEN_ENABLED.
local syncWaiting = false
local function Sync()
	if not T:IsOn() and InCombatLockdown() and next(active) then
		syncWaiting = true
		return
	end
	syncWaiting = false
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		if not nameplate:IsForbidden() then
			local unit = nameplate.unitToken   -- set by NamePlateBaseMixin:SetUnit
			local plate = active[nameplate]
			if T:IsOn() then
				if unit and not plate then Added(unit) end
			elseif plate then
				byUnit[plate.unit] = nil
				active[nameplate] = nil
				claimed[nameplate] = nil
				Shy:Fire("SHY_NAMEPLATE_GONE", nameplate)
				StandUp(nameplate, true)
				Release(plate)
			end
		end
	end
	Shy:Fire("SHY_NAMEPLATES")
end

-- CVars. Friendly nameplates in instances are forbidden, so Blizzard draws them. To match `friendNames`
-- there, these two CVars are set while it is on and restored after. Nameplate CVars can't change in combat.
-- (Settings runs at every PLAYER_ENTERING_WORLD: going into an instance and coming out of one.)

local FRIEND_NAMES = { "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateUseClassColorForFriendlyPlayerUnitNames" }
-- The game gives out 40 nameplates and no more, the nearest first; past them it writes a name over the unit itself
-- (in our font: ShyPlates.lua). A friendly player's pet, totem or guardian has a nameplate only where the game is
-- told to give its kind one: outdoors, while pets are ours to name (db.pets) this is on, so it is a small name with
-- its owner under it; otherwise off, so the plates go to players, NPCs and enemies. In an instance a friend's
-- nameplate is the game's own to draw, and the setting is as it was.
local PET_PLATES = "nameplateShowFriendlyPlayerMinions"
-- The guild under a name the game writes: a second line on every player past the 40. Off while ShyPlates is on.
local GUILD_LINE = "UnitNamePlayerGuild"
-- Every setting held; one saved that is not among them is put back as it was.
local HELD = { [PET_PLATES] = true, [GUILD_LINE] = true }
for _, name in ipairs(FRIEND_NAMES) do HELD[name] = true end
local settingsWaiting = false

-- A game setting held at `value` ("1" unless given) while `wanted`, and put back as it was after (db.cvars).
local function Hold(db, name, wanted, value)
	value = value or "1"
	if wanted then
		local now = GetCVar(name)
		if now == nil then return end   -- (no such setting: nothing to hold)
		if db.cvars[name] == nil then db.cvars[name] = now end
		if now ~= value then SetCVar(name, value) end
	elseif db.cvars[name] ~= nil then
		SetCVar(name, db.cvars[name])
		db.cvars[name] = nil
	end
end

local function Settings()
	if InCombatLockdown() then
		settingsWaiting = true
		return
	end
	settingsWaiting = false
	local db = T.db
	local wanted = db.on and db.friendNames
	-- ShyTweaks' classNames feature sets the same two CVars and saves their old values. While it holds
	-- one, it owns the restore value, and ours (the older one) is handed over to it.
	local tweaks = Shy.addons.Tweaks
	local theirs = tweaks and tweaks.db and tweaks.db.options and tweaks.db.options.classNames
	local held = theirs and theirs.restore
	for _, name in ipairs(FRIEND_NAMES) do
		if held and held[name] ~= nil then
			if db.cvars[name] ~= nil then
				held[name] = db.cvars[name]
				db.cvars[name] = nil
			end
		else
			Hold(db, name, wanted)
		end
	end
	Hold(db, PET_PLATES, db.on and not IsInInstance(), db.pets and "1" or "0")
	Hold(db, GUILD_LINE, db.on, "0")
	for name in pairs(db.cvars) do
		if not HELD[name] then Hold(db, name, false) end
	end
end

-- The game counts two stacked plates as side by side once they are a share of their width apart (the client's
-- nameplateOverlapH, 0.8 unless changed: their ends may overlap by a fifth). A plate's room is made that much
-- wider (L.BERTH.wide), so plates meet at their true ends. Read only; left alone where the game has no such
-- setting or stacks more widely already. True when it changed.
local function Sideways()
	local share = tonumber(GetCVar("nameplateOverlapH"))
	local pad = L.BERTH
	local wide = (share and share > 0 and share < 1) and math.min(1 / share, pad.widest) or 1
	if wide == pad.wide then return false end
	pad.wide = wide
	return true
end

-- Events for every plate

local function Each(method, ...)
	for _, plate in pairs(active) do plate[method](plate, ...) end
end

-- A new target or focus changes only the plates it was or is now, and every plate's alpha when a target comes
-- or goes. A plate is the new one only if its GUID is the token's; one whose GUID the game kept, or one marked
-- before (Plate.aimed: your target, your focus, or a secret answer), is always told. A secret GUID tells all.
-- The plates a change concerns, gathered once (a plate is told once however many reasons it has): those in
-- `set` that are on screen, the one `guid` names, and the blind.
local picked, order = {}, {}
local function Add(plate)
	if plate and not picked[plate] and active[plate.nameplate] == plate then
		picked[plate] = true
		order[#order + 1] = plate
	end
end
local function Pick(set, guid)
	wipe(picked)
	wipe(order)
	if set then
		for plate in pairs(set) do Add(plate) end
	end
	if guid ~= nil then Add(byGuid[guid]) end
	for plate in pairs(blind) do Add(plate) end
	return order
end

local hadTarget
local function Retarget(token)
	local exists = UnitExists("target") and true or false
	local guid = UnitGUID(token)
	if Secret(guid) or hadTarget == nil then
		hadTarget = exists
		Each("UpdateTarget")
		return
	end
	local list = Pick(P.aimed, guid)
	for _, plate in ipairs(list) do plate:UpdateTarget() end
	-- A target come or gone: every other plate only steps back or forward.
	if exists ~= hadTarget then
		hadTarget = exists
		local dim = exists and T.db.dim or 1
		for _, plate in pairs(active) do
			if not picked[plate] then plate:Redim(dim) end
		end
	end
end

-- Combo points show only on your target's plate: the others' rows are already hidden.
local function Combos()
	for plate in pairs(P.aimed) do
		if active[plate.nameplate] == plate then plate:UpdateCombo() end
	end
end

-- UPDATE_MOUSEOVER_UNIT doesn't fire when the mouse leaves a unit (Blizzard's own frames follow the event
-- alone, so no other exists), so the plates hovered (P.hovered) are polled while there are any. The event names
-- the one gained: by GUID as for the target, every plate when that can't be told.
local Hover
local function Poll() Hover(true) end
function Hover(polled)
	local list
	if polled then
		list = Pick(P.hovered)
		for i = #list, 1, -1 do
			if blind[list[i]] and not P.hovered[list[i]] then table.remove(list, i) end
		end
	else
		local guid = UnitGUID("mouseover")
		if Secret(guid) then
			list = {}
			for _, plate in pairs(active) do list[#list + 1] = plate end
		else
			list = Pick(P.hovered, guid)
		end
	end
	local any = false
	for _, plate in ipairs(list) do
		if plate:UpdateHover() then any = true end
	end
	if any and not hoverTicker then
		hoverTicker = C_Timer.NewTicker(HOVER_TICK, Poll)
	elseif not any and hoverTicker then
		hoverTicker:Cancel()
		hoverTicker = nil
	end
end

-- Settings changed: lay out every plate again, spares included.
local function Rearrange()
	ns.Auras.waiting = false
	for _, plate in pairs(active) do
		plate:Arrange()
		plate:Update()
	end
	for _, plate in ipairs(spares) do plate:Arrange() end
end

local HANDLERS = {
	NAME_PLATE_UNIT_ADDED = function(unit) Added(unit) end,
	NAME_PLATE_UNIT_REMOVED = function(unit)
		if not Secret(unit) and type(unit) == "string" then Removed(unit) end
	end,
	PLAYER_TARGET_CHANGED = function() Retarget("target") end,
	PLAYER_FOCUS_CHANGED = function() Retarget("focus") end,
	RAID_TARGET_UPDATE = function() Each("UpdateMark") end,
	UPDATE_MOUSEOVER_UNIT = function() Hover() end,
	UNIT_POWER_FREQUENT = function(_, kind)
		if kind == "COMBO_POINTS" then Combos() end
	end,
	UNIT_DISPLAYPOWER = Combos,
	-- Someone joined or left a guild, you among them: the line under a player's name, and whether it is yours.
	PLAYER_GUILD_UPDATE = function() Each("UpdateName") end,
	-- Threat colors depend on group and role.
	GROUP_ROSTER_UPDATE = function() Each("UpdateColor") end,
	PLAYER_ROLES_ASSIGNED = function() Each("UpdateColor") end,
	-- A fight begins: the store grows toward what is on screen, a plate a frame.
	PLAYER_REGEN_DISABLED = function()
		if not stocking then
			stocking = true
			C_Timer.After(0.5, Stock)   -- past the fight's first moments, which are busy enough
		end
	end,
	-- Work deferred by combat lockdown.
	PLAYER_REGEN_ENABLED = function()
		if settingsWaiting then Settings() end
		if syncWaiting then Sync() end
		-- Only the plates whose aura groups waited (built in the fight, or a setting changed in it).
		if ns.Auras.waiting and not ns.Auras.Restricted() then ns.Auras.CatchUp() end
	end,
	ADDON_RESTRICTION_STATE_CHANGED = function()
		if ns.Auras.waiting and not ns.Auras.Restricted() then ns.Auras.CatchUp() end
	end,
	PLAYER_ENTERING_WORLD = function()
		Settings()
		if Sideways() then Each("Berth") end
		Sync()
	end,
}

function D.Start()
	if started then return end
	started = true
	hidden = CreateFrame("Frame")
	hidden:Hide()
	store = CreateFrame("Frame")
	store:Hide()

	local events = CreateFrame("Frame")
	for event in pairs(HANDLERS) do
		if event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
			events:RegisterUnitEvent(event, "player")
		else
			events:RegisterEvent(event)
		end
	end
	events:SetScript("OnEvent", function(_, event, ...) HANDLERS[event](...) end)

	-- Plates set colors directly (restricted regions), so repaint on a theme change. Includes preview plates.
	-- The target's mark follows the look too, when the look picks it.
	Shy:On("SHY_THEME", function()
		for plate in pairs(P.all) do plate:Paint() end
		if ns.T.db.target == "look" then
			for _, plate in pairs(active) do plate:UpdateTarget() end
		end
	end)
	-- What your damage over time still has to deal on a mob changed (ShyDots).
	Shy:On("SHY_DOTS", function(guid)
		if not ns.Doom or guid == nil or Secret(guid) then return end
		local plate = byGuid[guid]
		if plate and active[plate.nameplate] == plate then ns.Doom.Update(plate) end
	end)
	-- A tank's or healer's layout put on or taken off: threat colors read by your role (Shy.Role).
	Shy:On("SHY_ROLE", function() Each("UpdateColor") end)
-- How you are read, picked here or on the threat meter: the same colors at once.
Shy:On("SHY_THREAT_ROLE", function() Each("UpdateColor") end)
	-- A quest dialog has the screen: the plates in the world fade with the rest (Shy.Immersion).
	Shy:On("SHY_IMMERSION_QUIET", function(level)
		ns.quiet = level
		for _, plate in pairs(active) do
			if plate.Fade then plate:Fade() end
		end
	end)
	ns.OnApply(function()
		Settings()
		Sideways()
		Sync()
		Rearrange()
	end)
	Settings()
	Sideways()
	Sync()
	Stock()
end

function D.PlateOn(nameplate)
	return active[nameplate]
end

-- Public API (see ShyPlates.lua).
function T:Tag(nameplate, info)
	local plate = active[nameplate]
	if not plate then return false end
	plate:SetTag(info)
	return true
end

function T:Room(nameplate)
	local plate = active[nameplate]
	if not plate then return nil end
	return plate.root, plate:Room()
end
