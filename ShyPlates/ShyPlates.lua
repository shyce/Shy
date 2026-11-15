-- ShyPlates: replacement nameplates. Registration, defaults and slash command.
--
-- API (Shy.addons.Plates):
--   :IsOn()                true while ShyPlates draws the nameplates
--   :Tag(nameplate, info)  another addon's icon on a plate. info = { texture, coords, color, count,
--                          back / face / over = { coords, color, texture }, flat = the same (its square form, drawn
--                          alone in a full plate's compartment), lead, mark }; nil clears; false if not our plate.
--                          The list is kept as given, and one that draws as the last did asks nothing of the game:
--                          give another list for a change, never the same one written to
--   :Room(nameplate)       frame, full, left, right, top, half, lift, tall (see Plate:Room); nil if not our plate
-- Bus: SHY_NAMEPLATE (unit) plate attached, SHY_NAMEPLATES all plates switched,
-- SHY_NAMEPLATE_GONE (nameplate, the unit leaving it if one is) fired before a plate detaches. SHY_PLATE belongs to ShyFrames.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Plates",
	icon = "Interface\\AddOns\\ShyPlates\\Media\\ShyPlates",
	smallIcon = "Interface\\AddOns\\ShyPlates\\Media\\ShyPlatesSmall",
	tagline = "Nameplates with casts, debuffs, threat and combo points",
	savedVariables = "ShyPlatesDB",
	defaults = {
		on = true,
		scale = 1,              -- the whole plate
		width = 124,            -- the housing
		room = "all",           -- what a plate keeps clear of other plates when the game stacks them: "all" (its
		                        -- debuffs and cast row too) | "bar" (its name and bar)
		font = "shy",           -- "shy" | "game"
		nameSize = 11,
		level = true,           -- the level before the name of a player and of anything you can attack
		guild = true,           -- a player's guild, under their name while they are only a name
		health = "hurt",        -- the number on the bar: "off" | "hurt" (percent once it is hurt) | "percent" | "value"
		execute = true,         -- a line at the health your finisher needs
		classColors = true,     -- players in their class color
		threat = "auto",        -- "auto" | "tank" | "dps" | "off"
		target = "lift",        -- what marks your target's plate, the same in every look: "lift" (its own colors
		                        -- richer and lighter) | "line" | "corners" (in your color) | "none"
		dim = 0.7,              -- how much of the other plates is left while you have a target
		casts = true,
		castTime = true,
		auras = true,           -- what you put on it
		control = true,         -- crowd control from anyone, larger
		steal = true,           -- its buffs you could take off it
		auraSize = 1,
		combo = true,
		doom = true,            -- what your damage over time still has to deal, and a check once it is enough
		calm = false,           -- enemies are a name until they matter
		friendNames = true,     -- friends are a name
		titles = true,          -- what an NPC does, under its name; whose a pet is, under its
		pets = false,           -- friends' pets, totems and guardians get a nameplate (a small name), not the game's own name
		cvars = {},             -- game settings as they were before ShyPlates changed them
	},
})
ns.T = T

ns.MEDIA = "Interface\\AddOns\\ShyPlates\\Media\\"

function T:IsOn()
	return self.db ~= nil and self.db.on == true
end

-- A settings change reruns every function registered with ns.OnApply.
local appliers = {}
function ns.OnApply(fn)
	appliers[#appliers + 1] = fn
end

function ns.Apply()
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:OnLoad()
	-- (The mark no longer goes by the theme's look, and the light once laid round the plate is its colors lifted.)
	if self.db.target == "look" or self.db.target == "glow" then self.db.target = "lift" end
	-- The names the game writes itself, over the units past its 40 nameplates (Driver.lua), in the plates' font.
	-- The engine reads these once at login, so a change applies from the next login.
	if self.db.on and self.db.font == "shy" then
		UNIT_NAME_FONT = Shy.FONT_ROUNDED
		UNIT_NAME_FONT_ROMAN = Shy.FONT_ROUNDED
		UNIT_NAME_FONT_CYRILLIC = Shy.FONT_ROUNDED
	end
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.Driver.Start()
end

SLASH_SHYPLATES1 = "/shyplates"
SLASH_SHYPLATES2 = "/spl"
SlashCmdList.SHYPLATES = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "on" or cmd == "off" then
		T.db.on = cmd == "on"
		ns.Apply()
		T:Print(T.db.on and "nameplates on." or "default nameplates are back.")
	else
		T:Print("commands:")
		print("  /shyplates  - open options")
		print("  /shyplates on | off  - these nameplates, or the default ones")
	end
end
