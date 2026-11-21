-- ShyDots: what your damage over time still has to deal, mob by mob. Registration, defaults, API, commands.
--
-- API (Shy.addons.Dots):
--   :IsOn()              true while casts are being followed
--   :Coming(guid)        damage still to come on that mob (a plain number) and how many of your spells
--                        make it; nil when none
--   :ComingOn(unit)      the same by unit token; nil when the game keeps the unit's identity secret
--   :Breakdown(guid)     each spell's own share, oldest first, as { school, coming, name }, and the total
--   :BreakdownOn(unit)   the same by unit token
--   :Report()            what is being followed now, as text
-- Bus: SHY_DOTS (guid) when a mob's coming damage changes.
-- The look is each addon's own: ShyPlates draws it on its nameplates and ShyFrames on the target frame.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Dots",
	category = "combat",
	icon = "Interface\\AddOns\\ShyDots\\Media\\ShyDots",
	smallIcon = "Interface\\AddOns\\ShyDots\\Media\\ShyDotsSmall",
	savedVariables = "ShyDotsDB",
	defaults = {
		on = true,
		ticks = {},     -- learned size of a tick, by spell (and combo points spent)
		spans = {},     -- learned number of ticks, by spell
	},
})
ns.T = T

function T:IsOn()
	return self.db ~= nil and self.db.on == true
end

function T:OnLogin()
	ns.Track.Start()
end

function T:Coming(guid)
	return ns.Track.Coming(guid)
end

function T:ComingOn(unit)
	local guid = UnitGUID(unit)
	if guid == nil or issecretvalue(guid) then return nil end
	return ns.Track.Coming(guid)
end

-- Whether a blow in `school` landing on a unit now is a tick of one of your spells there, as far as can be told.
function T:TickOn(unit, school)
	local guid = UnitGUID(unit)
	if guid == nil or issecretvalue(guid) then return false end
	return ns.Track.OnBeat(guid, school)
end

function T:Breakdown(guid)
	return ns.Track.Breakdown(guid)
end

function T:BreakdownOn(unit)
	local guid = UnitGUID(unit)
	if guid == nil or issecretvalue(guid) then return nil end
	return ns.Track.Breakdown(guid)
end

function T:Report()
	return ns.Track.Report()
end

function T:Forget()
	wipe(self.db.ticks)
	wipe(self.db.spans)
end

function T:Apply()
	ns.Track.Apply()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

local function Switch(on)
	T.db.on = on
	T:Apply()
	T:Print(on and "tracking your DoTs." or "off.")
end

T:Command("on", "track your DoTs", function() Switch(true) end)
T:Command("off", "stop tracking your DoTs", function() Switch(false) end)
-- For finding faults: what is tracked, to copy. Not listed.
T:Command("report", nil, function() Shy.UI.ShowCopyBox("ShyDots", T:Report()) end)
T:Command("forget", "forget the tick sizes learned so far", function()
	T:Forget()
	Shy.Settings.Refresh()
	T:Print("learned tick sizes forgotten.")
end)
