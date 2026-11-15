-- ShyDots: what your damage over time still has to deal, mob by mob. Registration, defaults, API, slash command.
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
	icon = "Interface\\AddOns\\ShyDots\\Media\\ShyDots",
	smallIcon = "Interface\\AddOns\\ShyDots\\Media\\ShyDotsSmall",
	tagline = "Shows when your DoTs will finish a mob",
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

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
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

function T:Apply()
	ns.Track.Apply()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

SLASH_SHYDOTS1 = "/shydots"
SLASH_SHYDOTS2 = "/sdo"
SlashCmdList.SHYDOTS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "on" or cmd == "off" then
		T.db.on = cmd == "on"
		T:Apply()
		T:Print(T.db.on and "tracking your DoTs." or "off.")
	elseif cmd == "report" then
		Shy.UI.ShowCopyBox("ShyDots", T:Report())
	elseif cmd == "forget" then
		wipe(T.db.ticks)
		wipe(T.db.spans)
		T:Print("learned tick sizes forgotten.")
	else
		T:Print("commands:")
		print("  /shydots  - open options")
		print("  /shydots on | off")
		print("  /shydots report  - what's being tracked, to copy")
		print("  /shydots forget  - forget the tick sizes learned so far")
	end
end
