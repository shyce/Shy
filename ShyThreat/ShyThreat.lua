-- Who has aggro and who is about to pull it: the threat table of the mob you're fighting, for your group,
-- in a meter that stands with the damage meter. Read.lua reads the game, Meter.lua draws it.
--
-- Public (Shy.addons.Threat):
--   T:Mob()      the unit the meter reads now ("mouseover", "target", "targettarget"), or nil
--   T:Rows()     what it shows: { unit, name, class, pet, tanking, status, scaled, lead, me, readable }, in order
--   T:IsTank()   whether the meter reads you as the tank: the family's one choice (Shy.ThreatRole), which the
--                nameplates' threat colors and a class's light read too
--   T:Piece()    the meter as a piece of a planned screen ({ id, width, height, scale, head, row, rows }), nil while
--                it is off; bus SHY_THREAT_PIECE when that changes (ShyDock plans the screen again)

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Threat",
	category = "combat",
	icon = "Interface\\AddOns\\ShyThreat\\Media\\ShyThreat",
	smallIcon = "Interface\\AddOns\\ShyThreat\\Media\\ShyThreatSmall",
	savedVariables = "ShyThreatDB",
	defaults = {
		on = true,            -- the meter on screen
		when = "combat",      -- "combat": in your fights (not one fought alone: no group, no pet) | "always": up between fights too, the last fight
		                      -- kept | "group": in group fights. Layout mode always shows it, to place and size.
		rows = 6,             -- the rows it is planned at (its height until you size it); more scroll
		pets = true,          -- pets' rows
		hover = true,         -- a nameplate under the mouse in a fight: the meter reads that mob
		warn = true,          -- the header lights as you near the pull (or, tanking, as the next player catches up)
		-- (How you are read and the warning sound are the family's: Shy.ThreatRole, Shy.ThreatSound.)
	},
})
ns.T = T

local appliers = {}
ns.appliers = appliers

-- When the meter shows (T.db.when), as the settings and the meter's menu offer it.
ns.WHEN = {
	{ value = "combat", text = "In combat" },
	{ value = "always", text = "Always" },
	{ value = "group",  text = "In group fights" },
}

function ns.Apply()
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:IsTank() return Shy.ThreatRole() == "tank" end

function T:Mob() return ns.Read.mob end
function T:Rows() return ns.Read.rows end

function T:OnLoad()
	-- How you were read before the family had one choice for it: carried over once. (The meter's own sound,
	-- near the pull, gave way to the family's, when aggro changes hands.)
	Shy.AdoptThreatRole(self.db.role)
	self.db.role, self.db.sound = nil, nil
end

function T:OnLogin()
	ns.Meter.Start()
end

-- For finding faults: a made-up fight, and what the game says of the threat on your target. Not listed.
T:Command("test", nil, function()
	ns.Meter.Try()
	T:Print("a made-up fight for ten seconds, so you can see and place the meter.")
end)
T:Command("report", nil, function()
	Shy.UI.ShowCopyBox("ShyThreat", ns.Read.Report())
end)
