-- Settings: the plate, what stands on it, your target, who is just a name, and the colors.
-- Each setting tells the plates on screen only what it changes (Driver.lua: Tell, Relay, Game).

local ADDON, ns = ...
local T, L, D = ns.T, ns.Layout, ns.Driver

ns.RefreshOptions = Shy.Settings.Refresh

local OFF = "Replace nameplates is off."

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

local function On()
	if T.db.on then return true end
	return false, OFF
end

-- In use while the plates are on and `test` holds; `why` is said when it doesn't.
local function With(test, why)
	return function()
		if not T.db.on then return false, OFF end
		if test() then return true end
		return false, why
	end
end

local function Class(...)
	local mine = UnitClassBase("player")
	for i = 1, select("#", ...) do
		if mine == select(i, ...) then return true end
	end
	return false
end

-- The game stacks nameplates, enemies' or friends': only then does a plate keep room.
local function Stacked()
	local kinds = Enum.NamePlateStackType
	return C_CVar.GetCVarBitfield("nameplateStackingTypes", kinds.Enemy) == true
		or C_CVar.GetCVarBitfield("nameplateStackingTypes", kinds.Friendly) == true
end

local function Tracking()
	local dots = Shy.addons.Dots
	return dots ~= nil and dots:IsOn()
end

local function Relay() D.Relay() end
local function Names() D.Tell("UpdateName") end
local function Health() D.Tell("UpdateHealth") end
local function Stance() D.Tell("UpdateStance") end
local function Target() D.Tell("UpdateTarget") end
local function Colors() D.Tell("UpdateColor") end
local function CastTime() D.Tell(ns.Cast.Paint) end

T:Settings({
	apply = function() ns.Apply() end,
	-- What the game's settings were before the plates took them stays through a reset.
	reset = function()
		local cvars = T.db.cvars
		T:ResetDB()
		T.db.cvars = cvars
		ns.Apply()
	end,

	{ key = "on", label = "Replace nameplates", words = "plates enemy health bars",
		desc = "Nameplates get this look, with casts, your debuffs and threat. Off, you get the default ones back." },

	{ section = "The plate" },
	{ key = "scale", label = "Size", min = 0.7, max = 1.5, step = 0.05, format = Percent, settle = true, enabled = On,
		apply = Relay, desc = "How big every nameplate is." },
	{ key = "width", label = "Width", min = 90, max = 160, step = 2, settle = true, enabled = On, apply = Relay,
		desc = "How wide the health bar is." },
	{ key = "health", label = "Health text", words = "percent number", enabled = On, apply = Health,
		items = {
			{ value = "hurt", text = "Percent when hurt" },
			{ value = "percent", text = "Percent" },
			{ value = "value", text = "Current health" },
			{ value = "off", text = "None" },
		},
		desc = "The number at the right end of the health bar." },
	{ key = "room", label = "Room when stacked", words = "stack overlap spacing",
		enabled = With(Stacked, "The game isn't stacking nameplates."),
		apply = function() D.Tell("Berth") end,
		items = {
			{ value = "all", text = "Whole plate" },
			{ value = "bar", text = "Name and bar" },
		},
		desc = "Whole plate keeps debuffs and cast bars off the next plate. Name and bar stacks them tighter." },
	{ key = "font", label = "Name font", enabled = On, apply = Relay,
		items = {
			{ value = "shy", text = "Rounded" },
			{ value = "game", text = "Game font" },
		},
		desc = "Both show names in every alphabet. Names past the game's 40 nameplates change at your next login." },
	{ key = "nameSize", label = "Name size", min = 9, max = 14, step = 1, settle = true, enabled = On, apply = Relay,
		desc = "How big the name over each plate is." },

	{ section = "On the plate" },
	{ key = "level", label = "Level", enabled = On, apply = Names,
		desc = "The level before the name of players and anything you can attack. Elites and rares always wear theirs in a seal." },
	{ key = "casts", label = "Cast bar", words = "casting interrupt kick", enabled = On,
		apply = function() D.Tell(ns.Cast.Paint, "Berth") end,
		desc = "What a mob is casting, under its plate. Your color means you can interrupt it, grey with a shield means you can't." },
	{ key = "castTime", label = "Cast time left", sub = true, apply = CastTime,
		enabled = With(function() return T.db.casts end, "The cast bar is off."),
		desc = "Seconds left, at the right end of the cast bar." },
	{ key = "combo", label = "Combo points", words = "pips", enabled = On,
		shown = function() return Class("ROGUE", "DRUID") end,
		apply = function() D.Tell("UpdateCombo") end,
		desc = "Five pips under your target's plate, gold to crimson as they fill." },
	{ key = "execute", label = "Execute line", words = "hammer of wrath finisher 20%", enabled = On,
		shown = function() return L.FINISHERS[UnitClassBase("player")] == true end, apply = Health,
		desc = "A line on the health bar at 20%. Below it you can use Execute or Hammer of Wrath." },
	-- (The marks are the DoT tracker's to switch: this is one of the places they show, there only while it runs.)
	{ key = "doom", label = "DoT marks", needs = "Dots", words = "dots damage over time kill as good as dead", enabled = On,
		shown = Tracking, apply = function() D.Tell(ns.Doom.Update) end,
		desc = "Your DoT damage still to come shows on nameplates here, with a check once it's enough for the kill." },

	{ section = "Above the name" },
	{ key = "auras", label = "Your debuffs", words = "dots auras icons", enabled = On, apply = Relay,
		desc = "Your debuffs and your pet's, the one ending soonest first, with time left and stacks." },
	{ key = "control", label = "Crowd control", words = "cc polymorph sheep sap trap stun", enabled = On, apply = Relay,
		desc = "Polymorph, Sap, traps and the like from anyone, bigger and first in the row." },
	{ key = "steal", label = "Buffs you can remove", words = "dispel purge spellsteal", enabled = On, apply = Relay,
		desc = "Enemy buffs you can dispel or steal, in a gold frame." },
	{ key = "auraSize", label = "Icon size", min = 0.8, max = 1.4, step = 0.05, format = Percent, settle = true, apply = Relay,
		enabled = With(function() return T.db.auras or T.db.control or T.db.steal end, "All three kinds of icon are off."),
		desc = "How big the icons over the name are." },
	{ note = "Changes to these made in a fight apply after it." },

	{ section = "Your target" },
	{ key = "target", label = "Target mark", words = "highlight line brackets corners", enabled = On, apply = Target,
		items = {
			{ value = "lift", text = "Richer colors" },
			{ value = "line", text = "Line along the top" },
			{ value = "corners", text = "Corner brackets" },
			{ value = "none", text = "None" },
		},
		desc = "How your target's plate stands out. A line or brackets are in your color, gold for your focus." },
	{ key = "dim", label = "Other plates", min = 0.4, max = 1, step = 0.05, words = "fade opacity dim", enabled = On,
		apply = Target, format = function(v) return v >= 1 and "Not dimmed" or Percent(v) end,
		desc = "How much of the other plates is left while you have a target." },

	{ section = "Name only" },
	{ key = "friendNames", label = "Friendly units", words = "players npcs names", enabled = On,
		apply = function()
			D.Game()
			Stance()
		end,
		desc = "Friendly players and NPCs are just a name until you target them." },
	{ key = "titles", label = "NPC titles", sub = true, words = "innkeeper flight master trainer vendor", apply = Names,
		enabled = With(function() return T.db.friendNames end, "Friendly units show their health bars."),
		desc = "A line under the name says what an NPC does, or whose pet it is." },
	{ key = "calm", label = "Enemies out of combat", enabled = On, apply = Stance,
		desc = "Enemies are just a name and level until you target them or they start fighting." },
	{ key = "guild", label = "Guild", apply = Names,
		enabled = With(function() return T.db.friendNames or T.db.calm end, "Nobody is just a name."),
		desc = "A player's guild under their name while they're just a name. Your own guild is in your color." },
	{ key = "pets", label = "Friendly pets", words = "minions totems guardians", enabled = On,
		apply = function() D.Game() end,
		desc = "Pets and totems on your side get a small nameplate, each one of the game's 40. Off, the game names them its own way." },
	{ note = "In dungeons, raids and battlegrounds the game draws friendly nameplates itself." },

	{ section = "Colors" },
	{ key = "classColors", label = "Class colors", enabled = On,
		apply = function()
			D.Game()
			D.Tell("UpdateName", "UpdateColor")
		end,
		desc = "Player health bars and friendly names in class color. An enemy's name stays red." },
	{ key = "threat", label = "Threat colors", default = true, words = "aggro tank", enabled = On, apply = Colors,
		get = function() return T.db.threat ~= "off" end,
		set = function(v) T.db.threat = v and "auto" or "off" end,
		desc = "In a group, health bars go green, orange, then red as you lose your hold. Solo, a neutral mob turns red once it attacks you." },
	{ note = "Blue means another tank has that mob." },

	{ note = "Who gets a nameplate at all, and whether they stack, is the game's to say. Those are under Game in this window." },
})

-- Your role picked or changed somewhere else: its row reads again.
Shy:On("SHY_THREAT_ROLE", function() Shy.Settings.Refresh() end)
Shy:On("SHY_ROLE", function() Shy.Settings.Refresh() end)
