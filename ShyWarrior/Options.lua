-- Settings: what lights up on your bars, your shout, the light round the screen, then the way to your keys.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Mine() return ns.isWarrior end
local function Openings() return T.db.openings.shown end
local function Shouts() return T.db.shout.shown end
local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

T:Settings({
	apply = function() ns.Refresh() end,
	{ note = "This one is for warriors. It does nothing on this character.", shown = function() return not ns.isWarrior end },

	{ section = "Openings", shown = Mine },
	{ key = "openings.shown", label = "Light up openings", words = "execute overpower revenge victory rush raging blow proc",
		desc = "Execute, Overpower, Revenge, Victory Rush and Raging Blow light up while you can use them." },
	{ key = "openings.interrupt", label = "Interrupts", sub = true, enabled = Openings, words = "pummel shield bash kick",
		desc = "Pummel or Shield Bash lights up while your target casts something you can stop." },
	{ key = "openings.charge", label = "Charge in range", sub = true, enabled = Openings, words = "intercept",
		desc = "Charge or Intercept lights up while your target is in reach." },
	{ key = "openings.sound", label = "Sound", words = "ping",
		enabled = function() return T.db.openings.shown or T.db.shout.shown end,
		desc = "A soft ping when an opening or your shout lights up." },
	{ note = "Sunder Armor, Thunder Clap, Demoralizing Shout and your shout's time are bars in your cooldown manager." },

	{ section = "Shouts", shown = Mine },
	{ key = "shout.shown", label = "Light up your shout", words = "battle commanding reminder buff",
		desc = "Your shout lights up when it's down or nearly out and you have the rage. Off your bars, it shows mid-screen." },
	{ key = "shout.battle", label = "Battle Shout", sub = true, enabled = Shouts },
	{ key = "shout.commanding", label = "Commanding Shout", sub = true, enabled = Shouts, desc = "Once you know it." },
	{ key = "shout.warnSeconds", label = "Remind when under", min = 5, max = 60, step = 5, sub = true, enabled = Shouts,
		format = function(v) return v .. " sec" end,
		desc = "Out of a fight, you're reminded this long before your shout runs out. In one, just before." },
	Shy.Settings.Layout("Move the shout reminder."),

	{ section = "Screen light", shown = Mine },
	{ key = "rage.shown", label = "Full rage", words = "edge border glow",
		desc = "In a fight, the edge of your screen lights up in your color as your rage nears full." },
	{ key = "rage.from", label = "Light from", min = 0.5, max = 0.95, step = 0.05, sub = true,
		enabled = function() return T.db.rage.shown end, format = function(v) return Percent(v) .. " rage" end,
		desc = "How full your rage is when the light starts." },
	{ key = "threat.glow", label = "Threat", words = "aggro edge border glow",
		desc = "In a group, the light turns gold as threat slips and red once it's lost. Not tanking, it warns as you near pulling." },
	{ key = "threat.alarm", label = "Aggro alarm", words = "taunt",
		desc = "When you're tanking and a mob turns to someone else, the light flashes and Taunt lights up red." },
	{ key = "threat.strength", label = "Brightness", min = 0.2, max = 1, step = 0.1, format = Percent,
		desc = "How bright the light gets." },
	{ label = "The light", button = "Try it", words = "preview test", run = function() ns.Threat.Try() end,
		desc = "Shows the light as rage fills, then as threat slips and is lost." },

	{ section = "Keys", needs = "Keys", shown = Mine },
	{ label = "Your keys", button = "Open", words = "hotkeys bindings macros bars layout abilities",
		run = function() Shy.Hub.Open("keys") end,
		desc = "See what each key does, lay them out, or put them back." },
})
