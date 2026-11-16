-- ShyHots: what your heals over time still have to heal, friend by friend. Registration, defaults, API, slash command.
--
-- API (Shy.addons.Hots):
--   :IsOn()              true while casts are being followed
--   :Coming(guid)        healing still to come on that friend (a plain number) and how many of your spells
--                        make it; nil when none
--   :ComingOn(unit)      the same by unit token; nil when the game keeps the unit's identity secret
--   :Breakdown(guid)     each spell's own share, oldest first, as { school, coming, name }, and the total.
--                        The list is one table, filled again by the next call: read it, don't keep it.
--   :BreakdownOn(unit)   the same by unit token
--   :Report()            what is being followed now, as text
-- Bus: SHY_HOTS (guid) when a friend's coming healing changes.
-- The look is each addon's own: ShyFrames draws it past the end of the health someone has.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Hots",
	category = "combat",
	icon = "Interface\\AddOns\\ShyHots\\Media\\ShyHots",
	smallIcon = "Interface\\AddOns\\ShyHots\\Media\\ShyHotsSmall",
	savedVariables = "ShyHotsDB",
	defaults = {
		on = true,
		shares = {},    -- learned: how much more (or less) a spell's tick is than its own numbers say, by spell
		family = {},    -- the same by the spell's family, for a rank not seen yet
		spans = {},     -- learned: the number of ticks, by spell, where one runs longer than its own numbers say
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
	wipe(self.db.shares)
	wipe(self.db.family)
	wipe(self.db.spans)
end

function T:Apply()
	ns.Track.Apply()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

SLASH_SHYHOTS1 = "/shyhots"
SLASH_SHYHOTS2 = "/sho"
SlashCmdList.SHYHOTS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "on" or cmd == "off" then
		T.db.on = cmd == "on"
		T:Apply()
		T:Print(T.db.on and "tracking your HoTs." or "off.")
	elseif cmd == "report" then
		Shy.UI.ShowCopyBox("ShyHots", T:Report())
	elseif cmd == "forget" then
		T:Forget()
		T:Print("learned tick sizes forgotten.")
	else
		T:Print("commands:")
		print("  /shyhots  - open options")
		print("  /shyhots on | off")
		print("  /shyhots report  - what's being tracked, to copy")
		print("  /shyhots forget  - forget the tick sizes learned so far")
	end
end
