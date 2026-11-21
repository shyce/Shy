-- A rogue's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the ability by stealth and
-- by what you have learned, so an ability arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy rogue keys)
--   ns.Keys.List()    every key and what it does, as text
--
-- In stealth the three attack keys open instead: Cheap Shot, Garrote and Ambush (Subtlety: Ambush on the
-- main key, Cheap Shot and Garrote beside it).

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}
ns.Keys = K


local SHOW, ATTACK = "#showtooltip", "/startattack"
-- A key that opens from Stealth starts no swing there: pressed on the way in, a swing would break Stealth first.
local OPENER = "/startattack [nostealth]"
local Either = Shy.Keys.Either

local JOBS = {
	-- The fight, under the fingers that are free while you move. Each build's main strike is on R.
	{ name = "Strike", role = "strike", key = "R", asdf = "R", what = "Sinister Strike (Mutilate or Hemorrhage if you have it). Cheap Shot from stealth",
		SHOW, OPENER, "/cast [stealth,known:{1833}] {1833}; [known:{399956}] {399956}; [known:{16511}] {16511}; {1752}",
		by = {
			combat = { name = "Strike", role = "strike", what = "Sinister Strike. Cheap Shot from stealth",
				SHOW, OPENER, "/cast [stealth,known:{1833}] {1833}; {1752}" },
			assassination = { name = "Strike", role = "strike", what = "Sinister Strike, Mutilate once you have it. Cheap Shot from stealth",
				SHOW, OPENER, "/cast [stealth,known:{1833}] {1833}; [known:{399956}] {399956}; {1752}" },
			-- Daggers and your back: Backstab is what you press most, and Ambush opens.
			subtlety = { name = "Stab", what = "Backstab. Ambush from stealth",
				SHOW, OPENER, "/cast [stealth,known:{8676}] {8676}; {53}" },
			subpvp = { name = "Strike", role = "strike", what = "Sinister Strike, Hemorrhage once you have it. Cheap Shot from stealth",
				SHOW, OPENER, "/cast [stealth,known:{1833}] {1833}; [known:{16511}] {16511}; {1752}" },
		} },
	{ name = "Finish", role = "finish", key = "E", asdf = "E", what = "Eviscerate. Ambush from stealth",
		SHOW, OPENER, "/cast [stealth,known:{8676}] {8676}; {2098}",
		by = {
			-- (Combat holds swords: no Ambush.)
			combat = { name = "Finish", role = "finish", what = "Eviscerate", SHOW, OPENER, "/cast {2098}" },
			subtlety = { name = "Finish", role = "finish", what = "Eviscerate. Garrote from stealth",
				SHOW, OPENER, "/cast [stealth,known:{703}] {703}; {2098}" },
		} },
	{ name = "Stab", key = "Q", asdf = "Q", what = "Backstab. Garrote from stealth",
		SHOW, OPENER, "/cast [stealth,known:{703}] {703}; {53}",
		by = {
			-- Your strike for when you can't get behind, beside the Backstab on R.
			subtlety = { name = "Strike", role = "strike", what = "Sinister Strike, Hemorrhage once you have it. Cheap Shot from stealth",
				SHOW, OPENER, "/cast [stealth,known:{1833}] {1833}; [known:{16511}] {16511}; {1752}" },
		} },
	{ name = "Slice", key = "T", asdf = "T", what = "Slice and Dice",
		SHOW, "/cast {5171}" },
	-- Shank, on cooldown in every build: an easy key for what comes round every ten seconds, under F.
	{ name = "Shank", key = "V", asdf = "V", what = "Shank",
		SHOW, ATTACK, "/cast {1329283}" },
	-- The stun you lean on while leveling, the stop's kin.
	{ name = "Kidney", key = "SHIFT-F", asdf = "SHIFT-G", what = "Kidney Shot",
		SHOW, ATTACK, "/cast {408}" },
	-- Gouge stops a cast too: it keeps the stop's key (F, G with ASDF) until Kick comes.
	{ name = "Gouge", key = "G", early = "F", asdf = "W", asdfEarly = "G", what = "Gouge",
		SHOW, "/cast {1776}" },
	-- Sap is how you pull one of two: pressed standing still in Stealth, so a far key will do.
	{ name = "Sap", key = "B", asdf = "B", what = "Sap",
		SHOW, "/cast {6770}" },
	-- From Stealth, before you open: from level 4, so it holds its key the whole way. (With ASDF, X is under the
	-- finger on S: fine for what you press standing still.)
	{ name = "Pick Pocket", key = "X", asdf = "X", what = "Pick Pocket",
		SHOW, "/cast {921}" },
	{ name = "Sprint", key = "C", asdf = "C", what = "Sprint",
		SHOW, "/cast {2983}" },
	{ name = "Stealth", key = "Z", asdf = "Z", what = "Stealth",
		SHOW, "/cast {1784}" },
	-- Slice and Dice's kin, the other finisher you keep up: Rupture, for the builds that bleed. Combat never
	-- Ruptures while leveling: its Blade Flurry stands here.
	{ name = "Rupture", key = "SHIFT-T", asdf = "SHIFT-T", stay = true, what = "Rupture",
		SHOW, ATTACK, "/cast {1943}",
		by = {
			combat = { name = "Flurry", what = "Blade Flurry", SHOW, "/cast {13877}" },
		} },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Evasion", key = "BUTTON4", asdf = "BUTTON4", what = "Evasion",
		SHOW, "/cast {5277}" },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Kick",
		SHOW, "/cast {1766}" },
	-- With Shift: each key's rarer kin.
	-- Feint sheds a group's threat: never pressed alone, so it never stands in on an easy key.
	{ name = "Feint", key = "SHIFT-BUTTON5", asdf = "SHIFT-BUTTON5", stay = true, what = "Feint",
		SHOW, "/cast {1966}" },
	{ name = "Burst", role = "burst", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", what = "Adrenaline Rush or Cold Blood, whichever you have",
		SHOW, Either({ 13750, 14177 }),
		by = {
			-- (Combat's Cold Blood, its last talent, is on Mouse 5.)
			combat = { name = "Burst", role = "burst", what = "Adrenaline Rush", SHOW, "/cast {13750}" },
			assassination = { name = "Cold Blood", what = "Cold Blood", SHOW, "/cast {14177}" },
			subpvp = { name = "Cold Blood", what = "Cold Blood", SHOW, "/cast {14177}" },   -- (its last talent)
			subtlety = false,   -- (takes neither)
		} },
	-- The strike's kin: Riposte when it lights, or the subtlety builds' Ghostly Strike.
	{ name = "Counter", role = "counter", key = "SHIFT-R", asdf = "SHIFT-R", what = "Riposte or Ghostly Strike, whichever you have",
		SHOW, ATTACK, Either({ 5237, 14278 }),
		by = {
			combat = { name = "Riposte", what = "Riposte", SHOW, ATTACK, "/cast {5237}" },
			subtlety = { name = "Ghostly", what = "Ghostly Strike", SHOW, ATTACK, "/cast {14278}" },
			subpvp = { name = "Ghostly", what = "Ghostly Strike", SHOW, ATTACK, "/cast {14278}" },
			assassination = false,   -- (takes neither)
		} },
	-- The finisher's kin: Death Mark, a finisher with a cooldown of its own, for the subtlety builds.
	{ name = "Death Mark", key = "SHIFT-E", asdf = "SHIFT-E", stay = true, what = "Death Mark",
		SHOW, ATTACK, "/cast {1316709}",
		by = { combat = false, assassination = false } },
	-- Pressed in Stealth before you open: not hurried. (With ASDF Shift + W, where the hand is.)
	{ name = "Premeditation", key = "SHIFT-Q", asdf = "SHIFT-W", what = "Premeditation",
		SHOW, "/cast {14183}",
		by = { combat = false, assassination = false } },
	-- Never hurried: Preparation, or Cold Blood for combat (its last talent) before an Eviscerate you plan.
	{ name = "Preparation", key = "BUTTON5", asdf = "BUTTON5", what = "Preparation",
		SHOW, "/cast {14185}",
		by = {
			combat = { name = "Cold Blood", what = "Cold Blood", SHOW, "/cast {14177}" },
			assassination = false,
		} },
	{ name = "Distract", key = "SHIFT-G", asdf = "SHIFT-Q", spell = 1725, stay = true, what = "Distract",
		SHOW, "/cast {1725}" },
	-- The group's key: Expose Armor is what a rogue does for everyone's hits. Never pressed alone, so it
	-- never stands in on an easy key.
	{ name = "Expose", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Expose Armor",
		SHOW, ATTACK, "/cast {8647}" },
	-- One rank each and nothing to choose: Distract and Disarm Trap stand as the spells themselves, with no macro.
	{ name = "Disarm Trap", key = "SHIFT-D", asdf = "SHIFT-D", spell = 1842, what = "Disarm Trap",
		SHOW, "/cast {1842}" },
	-- The number row: the big way out, where it isn't pressed by mistake, and the add you take out of a fight.
	{ name = "Vanish", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", stay = true, what = "Vanish",
		SHOW, "/cast {1856}" },
	{ name = "Blind", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", what = "Blind",
		SHOW, "/cast {2094}" },
	-- What you stay in, beside Stealth on 1: your poisons. 2 puts the quick one on your main hand, 3 the lasting one
	-- on your off hand (each the other kind when you carry only that), the best of it you can use.
	{ name = "Main Hand", key = "2", asdf = "2", what = "Poison your main hand: Instant Poison first",
		supply = { "instant", "venom" }, only = true, "/use 16" },
	{ name = "Off Hand", key = "3", asdf = "3", what = "Poison your off hand: Deadly, Crippling or the like first",
		supply = { "venom", "instant" }, only = true, "/use 17" },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use. (No water for a rogue: Shift + X
-- stays free, so the row reads the same on every character.)
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { stone = true, potion = { name = "Tea", kind = "energy", what = "Drink your Thistle Tea" } })
-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first: a throw
-- or a shot pulls one enemy away from its friends, and Poisons opens the window you make them in.
Shy.Keys.Utility(JOBS, {
	{ name = "Throw", spells = { 2764 } },
	{ name = "Shoot", what = "Shoot your bow, gun or crossbow", spells = { 2480, 7918, 7919 } },
	{ name = "Poisons", what = "Make poisons", spells = { 2842 } },
})
K.JOBS = JOBS

-- How to play, by level and build: what you press, in order, on one enemy and on a few.
local PLAY = {
	{ from = 1, tip = "You build combo points with your strike and spend them on Eviscerate. Eat between pulls so each starts full.",
		single = { { "Strike" }, { "Stab", "from behind, with a dagger" }, { "Finish", "at 3 or more combo points" } },
		cleave = { { "Gouge", "on the second enemy" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" } } },
	{ from = 10, tip = "Come in from Stealth, put Slice and Dice up and spend the rest on Eviscerate. Sap a second enemy first.",
		single = { { "Stealth", "before you pull" }, { "Stab", "to open from behind", as = "stealth" }, { "Slice", "keep it up" }, { "Strike" },
			{ "Finish", "at 4 or 5 combo points" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Gouge", "on one that joins" },
			{ "Slice", "keep it up" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" } } },
	{ from = 20, tip = "Fights last longer now. Keep Slice and Dice up, Kick the casters, and Vanish if a pull goes wrong.",
		single = { { "Stealth", "before you pull" }, { "Stab", "to open from behind", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" }, { "Strike" },
			{ "Finish", "at 5 combo points" }, { "Rupture", "on a tough enemy" }, { "Stop", "when it casts" }, { "Evasion", "when you're losing" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Gouge", "on one that joins" },
			{ "Slice", "keep it up" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Evasion", "when two hit you" },
			{ "Vanish", "if it goes wrong" } } },
	{ from = 30, tip = "Cheap Shot opens and Kidney Shot stuns again, so most enemies barely hit you back.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Kidney", "to stun it again" }, { "Finish", "at 5 combo points" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Kidney", "on the one that joins" },
			{ "Gouge", "while Kidney Shot wears off" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },
	{ from = 40, tip = "You open, stun and kill before most enemies act. Blind or Sap the extras and fight one at a time.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Kidney", "to stun it again" }, { "Finish", "at 5 combo points" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Blind", "on the one that joins" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" },
			{ "Kidney", "on a caster" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },
	{ from = 50, tip = "Enemies hit hard this high. Never pull three, keep a potion and bandages, and Vanish before you're low.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Kidney", "to stun it again" }, { "Finish", "at 5 combo points" }, { "Stop", "when it casts" }, { "Evasion", "when you're losing" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Blind", "on the one that joins" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" },
			{ "Kidney", "on a caster" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },

	-- Combat: Riposte after a parry, Blade Flurry on two, Adrenaline Rush on the hard ones.
	{ from = 20, build = "combat", tip = "Sinister Strike is cheap now and Riposte lights up after you parry. Press it every time it does.",
		single = { { "Stealth", "before you pull" }, { "Stab", "to open from behind", as = "stealth" }, { "Slice", "keep it up" }, { "Strike" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Slice", "keep it up" }, { "Strike" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Gouge", "on one that joins" },
			{ "Evasion", "when two hit you" } } },
	{ from = 30, build = "combat", tip = "Two enemies are fine now. Blade Flurry hits both while Slice and Dice keeps you swinging fast.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Flurry", "on 2 or more enemies" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Strike" },
			{ "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },
	{ from = 40, build = "combat", tip = "Adrenaline Rush and Blade Flurry together tear through a pack of two or three. Save them for that.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Burst", "on a tough enemy" },
			{ "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Flurry", "on 2 or more enemies" }, { "Burst", "with Blade Flurry" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Riposte", "when it's lit" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" },
			{ "Vanish", "if it goes wrong" } } },
	{ from = 50, build = "combat", tip = "You kill fast enough to pull two at a time. Keep a potion ready and Evasion for the third.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Burst", "on a tough enemy" },
			{ "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Flurry", "on 2 or more enemies" }, { "Burst", "with Blade Flurry" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Riposte", "when it's lit" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when a third joins" },
			{ "Vanish", "if it goes wrong" } } },
		{ from = 60, build = "combat", tip = "Cold Blood, your last talent, makes the next Eviscerate a sure crit. Save it for a tough enemy.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Riposte", "when it's lit" }, { "Burst", "on a tough enemy" },
			{ "Cold Blood", "right before Eviscerate" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Flurry", "on 2 or more enemies" }, { "Burst", "with Blade Flurry" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Riposte", "when it's lit" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Cold Blood", "to finish one quickly" },
			{ "Evasion", "when a third joins" }, { "Vanish", "if it goes wrong" } } },

	-- Assassination: crits and cheap finishers, Cold Blood, then Mutilate on daggers.
	{ from = 20, build = "assassination", tip = "Your finishers cost less and crit more. Build to five points, and keep poison on both blades.",
		single = { { "Stealth", "before you pull" }, { "Stab", "to open from behind", as = "stealth" }, { "Slice", "keep it up" }, { "Strike" },
			{ "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Gouge", "on one that joins" },
			{ "Slice", "keep it up" }, { "Shank", "on cooldown" }, { "Strike" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" } } },
	{ from = 30, build = "assassination", tip = "Cold Blood makes your next Eviscerate a sure crit. Use it to end a fight that's going long.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "right before Eviscerate" }, { "Finish", "at 5 combo points" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" },
			{ "Rupture", "on a tough enemy" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Kidney", "on the one that joins" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "to finish one quickly" }, { "Evasion", "when two hit you" } } },
	{ from = 40, build = "assassination", tip = "With daggers in both hands Mutilate builds points fast. Open, stun and Eviscerate before it fights back.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "right before Eviscerate" }, { "Finish", "at 5 combo points" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" },
			{ "Rupture", "on a tough enemy" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Blind", "on the one that joins" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "to finish one quickly" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },
	{ from = 50, build = "assassination", tip = "Keep fights to one enemy and they end in seconds. Blind or Sap anything else that comes.",
		single = { { "Stealth", "before you pull" }, { "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "right before Eviscerate" }, { "Finish", "at 5 combo points" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" },
			{ "Rupture", "on a tough enemy" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Blind", "on the one that joins" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" },
			{ "Cold Blood", "to finish one quickly" }, { "Evasion", "when two hit you" }, { "Vanish", "if it goes wrong" } } },

	-- Subtlety: a dagger and your back. Ambush opens and Backstab follows, both on R.
	{ from = 10, build = "subtlety", tip = "Sneak behind it in Stealth and open from there. Keep a dagger in your main hand and strike from behind.",
		single = { { "Stealth", "before you pull" }, { "Stab", "to open from behind", as = "stealth" }, { "Slice", "keep it up" },
			{ "Strike", "when you can't get behind" }, { "Finish", "at 4 or 5 combo points" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Gouge", "then get behind it" },
			{ "Stab", "from behind" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" }, { "Evasion", "when two hit you" } } },
	{ from = 20, build = "subtlety", tip = "Premeditation hands you points before Ambush, so a pull can open with a full Eviscerate.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Stab", "to open from behind", as = "stealth" },
			{ "Slice", "keep it up" }, { "Strike", "when you can't get behind" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" },
			{ "Ghostly", "whenever it's ready" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Stab", "to open from behind", as = "stealth" }, { "Gouge", "then get behind it" }, { "Ghostly", "whenever it's ready" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Evasion", "when two hit you" } } },
	{ from = 30, build = "subtlety", tip = "Hemorrhage hits from any side now. Preparation brings Vanish back, so you can open from Stealth twice.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Stab", "to open from behind", as = "stealth" },
			{ "Slice", "keep it up" }, { "Strike", "when you can't get behind" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" },
			{ "Ghostly", "whenever it's ready" }, { "Rupture", "on a tough enemy" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Stab", "to open from behind", as = "stealth" }, { "Kidney", "on the one that joins" }, { "Ghostly", "whenever it's ready" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
	{ from = 40, build = "subtlety", tip = "Death Mark is a finisher that holds back part of your damage and lets it out a few seconds later. Use it on a tough enemy.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Stab", "to open from behind", as = "stealth" },
			{ "Slice", "keep it up" }, { "Strike", "when you can't get behind" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" },
			{ "Ghostly", "whenever it's ready" }, { "Death Mark", "on a tough enemy" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Stab", "to open from behind", as = "stealth" }, { "Blind", "on the one that joins" }, { "Ghostly", "whenever it's ready" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
	{ from = 50, build = "subtlety", tip = "Every fight starts in Stealth on your terms. One enemy at a time, the rest Sapped or Blinded.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Stab", "to open from behind", as = "stealth" },
			{ "Slice", "keep it up" }, { "Strike", "when you can't get behind" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" },
			{ "Ghostly", "whenever it's ready" }, { "Death Mark", "on a tough enemy" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Stab", "to open from behind", as = "stealth" }, { "Blind", "on the one that joins" }, { "Ghostly", "whenever it's ready" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },

	-- Subtlety for fighting players: Premeditation and Cheap Shot, then Hemorrhage.
	{ from = 20, build = "subpvp", tip = "Premeditation and Cheap Shot (from 26) open every fight from Stealth. Gouge buys time when you need it.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Ghostly", "whenever it's ready" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Strike", "opens, then builds points", as = "stealth" }, { "Slice", "keep it up" }, { "Finish", "at 3 or more combo points" },
			{ "Gouge", "on one that joins" }, { "Shank", "on cooldown" }, { "Evasion", "when two hit you" } } },
	{ from = 30, build = "subpvp", tip = "Hemorrhage is your strike now, from any side. Kidney Shot and Preparation keep a fight in your hands.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Ghostly", "whenever it's ready" },
			{ "Kidney", "to stun it again" }, { "Rupture", "on a tough enemy" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Strike", "opens, then builds points", as = "stealth" }, { "Kidney", "on the one that joins" }, { "Gouge", "while Kidney Shot wears off" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
	{ from = 40, build = "subpvp", tip = "Death Mark and a full Eviscerate end most fights before the other side can answer.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Ghostly", "whenever it's ready" },
			{ "Death Mark", "on a tough enemy" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Strike", "opens, then builds points", as = "stealth" }, { "Blind", "on the one that joins" }, { "Kidney", "on a caster" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
	{ from = 50, build = "subpvp", tip = "Quests go slower in this build. Pick your fights, open from Stealth and never take on two awake.",
		single = { { "Stealth", "before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" }, { "Ghostly", "whenever it's ready" },
			{ "Death Mark", "on a tough enemy" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Strike", "opens, then builds points", as = "stealth" }, { "Blind", "on the one that joins" }, { "Kidney", "on a caster" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
	{ from = 60, build = "subpvp", tip = "Cold Blood, your last talent, makes the Eviscerate after your opener a sure crit. Most fights end there.",
		single = { { "Premeditation", "in Stealth, before you open", as = "stealth" }, { "Strike", "opens, then builds points", as = "stealth" },
			{ "Slice", "keep it up" }, { "Cold Blood", "right before Eviscerate" }, { "Finish", "at 5 combo points" }, { "Shank", "on cooldown" },
			{ "Ghostly", "whenever it's ready" }, { "Death Mark", "on a tough enemy" }, { "Kidney", "to stun it again" }, { "Stop", "when it casts" } },
		cleave = { { "Stealth", "before you pull" }, { "Sap", "on one, before you pull" }, { "Premeditation", "in Stealth, before you open", as = "stealth" },
			{ "Strike", "opens, then builds points", as = "stealth" }, { "Blind", "on the one that joins" }, { "Cold Blood", "to finish one quickly" },
			{ "Finish", "at 3 or more combo points" }, { "Shank", "on cooldown" }, { "Vanish", "to open again" }, { "Preparation", "for a second Vanish" } } },
}
K.PLAY = PLAY

local OPTS = {
	forms = 1, plain = true,                 -- in stealth the main bar turns its page
	knows = 1752,                            -- Sinister Strike: a rogue's from level 1
	stances = "Stealth",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isRogue then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isRogue then
		T:Print("your keys are laid out on a rogue only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nIn stealth the three attack keys open instead: Cheap Shot, Garrote and Ambush."
end

-- From login on, a job comes to its key when you learn it, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
