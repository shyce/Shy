-- A hunter's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the ability by what you
-- have learned, so an ability arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy hunter keys)
--   ns.Keys.List()    every key and what it does, as text

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}
ns.Keys = K

local SHOW, ATTACK = "#showtooltip", "/startattack"
local Either = Shy.Keys.Either

-- What a build has on a key in place of the plain job. Survival fights in reach: its two strikes stand where the
-- others' Aimed and Arcane Shots do, Arcane Shot behind Shift, Deterrence on the wall's key and Disengage alone on the
-- escape. Beast Mastery's hawks (which share Arcane Shot's cooldown) and Marksmanship's Sniper Shot stand beside
-- Arcane Shot; the shooting builds strike and bite in reach with one key. Bestial Wrath is a cooldown on 5 beside
-- Rapid Fire; Trueshot Aura is the long buff on Shift + 4.
local RAPTOR = { name = "Raptor", what = "Raptor Strike", SHOW, ATTACK, "/cast {2973}" }
local BITE = { name = "Mongoose", what = "Mongoose Bite", SHOW, ATTACK, "/cast {1495}" }
-- Survival in reach: the Beast's melee power to fight in (the Monkey until it comes), Freezing Trap its one stop,
-- Strider Kick a strike between Raptor Strikes, Lacerate its bleed beside the sting, Rapid Fire its cooldown (it
-- hastens blows too), and Concussive Shot behind Shift once the kick takes its key.
local IN_REACH = { name = "Aspect", what = "Aspect of the Beast. Aspect of the Monkey until 30",
	SHOW, "/cast [known:{13161}] {13161}; {13163}" }
local FREEZE = { name = "Stop", role = "stop", what = "Freezing Trap", SHOW, "/cast {1499}" }
local KICK = { name = "Strider Kick", what = "Strider Kick", SHOW, ATTACK, "/cast {1317257}" }
local CONCUSSIVE = { name = "Concussive", what = "Concussive Shot", SHOW, "/cast {5116}" }
local LACERATE = { name = "Lacerate", what = "Lacerate", SHOW, ATTACK, "/cast {24118}" }
local RAPID = { name = "Rapid Fire", what = "Rapid Fire", SHOW, "/cast {3045}" }
local ARCANE = { name = "Arcane", what = "Arcane Shot", SHOW, "/cast {3044}" }
local DETER = { name = "Deterrence", what = "Deterrence", SHOW, "/cast {19263}" }
local DISENGAGE = { name = "Disengage", what = "Disengage", SHOW, "/cast {781}" }
local SNIPER = { name = "Sniper Shot", what = "Sniper Shot", SHOW, "/cast {1310687}" }
local FLARE = { name = "Flare", what = "Flare", SHOW, "/cast {1543}" }
-- Beast Mastery PvP drains a caster's mana with Viper Sting, on Shift + E beside Arcane Shot (where the others' hawks
-- or Sniper Shot stand); Scorpid Sting stays the sting's kin on Shift + Q, for those who hit you.
local VIPER = { name = "Viper", what = "Viper Sting", SHOW, "/cast {3034}" }
-- Lone Wolf hits a fifth harder with no pet out: put it away at a dungeon's door, on the slow utility's key.
-- (never standing in on an easy key: pressed there by mistake in a fight, it would send your pet away)
local DISMISS = { name = "Dismiss Pet", what = "Dismiss Pet", stay = true, SHOW, "/cast {2641}" }

local JOBS = {
	-- The fight, under the fingers that are free while you move.
	{ name = "Sting", key = "Q", asdf = "Q", what = "Serpent Sting",
		SHOW, "/cast {1978}" },
	{ name = "Arcane", key = "E", asdf = "E", what = "Arcane Shot",
		SHOW, "/cast {3044}", by = { survival = BITE } },
	-- The main shot: Aimed Shot, which shares its cooldown with Multi-Shot on Shift + R (one or the other, every
	-- 6 sec: Aimed on one enemy, Multi on a pack). Survival's main strike is Raptor Strike.
	{ name = "Aimed", key = "R", asdf = "R", what = "Aimed Shot",
		SHOW, "/cast {19434}", by = { survival = RAPTOR } },
	-- (With ASDF, F backs you off under the index finger: Multi-Shot, shot on the move, goes on Shift + W, the ring
	-- finger's, and the strikes in reach take Shift + R.)
	{ name = "Multi-Shot", key = "SHIFT-R", asdf = "SHIFT-W", what = "Multi-Shot",
		SHOW, "/cast {2643}" },
	-- The fire trap is the area key from 16 on; Volley comes at 40 as its rarer kin, so nothing moves then.
	{ name = "Fire Trap", key = "T", asdf = "T", what = "Explosive Trap. Immolation Trap until 34",
		SHOW, "/cast [known:{13813}] {13813}; {13795}" },
	-- Every build pulls with a shot and the pet; Survival's strikes start the fight in reach themselves.
	{ name = "Attack", role = "attack", key = "Z", asdf = "Z", early = "F", asdfEarly = "G", what = "Auto Shot, and your pet attacks",
		"#showtooltip {75}", "/cast !{75}", "/petattack" },
	-- With ASDF, W is under the ring finger, free while you stand or back off with F: where you slow what comes at you.
	{ name = "Concussive", key = "G", asdf = "W", what = "Concussive Shot",
		SHOW, "/cast {5116}", by = { survival = KICK } },
	{ name = "Pet", key = "V", asdf = "V", what = "Mend Pet. Call Pet with none out, Revive Pet over its body",
		SHOW, "/cast [pet,@pet,nodead] {136}; [@pet,dead] {982}; {883}" },
	-- With ASDF, C is under the middle finger, free while you run on S: you feign as you run from a fight gone bad.
	{ name = "Feign", key = "X", asdf = "C", what = "Feign Death",
		SHOW, "/cast {5384}" },
	{ name = "Travel", role = "travel", key = "3", asdf = "3", stay = true, what = "Aspect of the Cheetah. Aspect of the Pack in a group",
		SHOW, "/cast [group,known:{13159}] {13159}; {5118}" },
	-- Pressed before every pull: an easy key (with ASDF, X under the ring finger, pressed before you set off).
	{ name = "Hunter's Mark", key = "C", asdf = "X", what = "Hunter's Mark",
		SHOW, "/cast {1130}" },
	-- What you stay in, on 1 2 3: the Hawk to fight, the Monkey when they reach you, the Cheetah to travel.
	{ name = "Aspect", key = "1", asdf = "1", stay = true, what = "Aspect of the Hawk. Aspect of the Monkey until 10",
		SHOW, "/cast [known:{13165}] {13165}; {13163}", by = { survival = IN_REACH } },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Wing Clip", key = "BUTTON4", asdf = "BUTTON4", what = "Wing Clip",
		SHOW, ATTACK, "/cast {2974}" },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Scatter Shot or Intimidation. Freezing Trap until you have one",
		SHOW, Either({ 19503, 19577, 1499 }), by = { survival = FREEZE } },
	{ name = "Escape", role = "escape", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", what = "Deterrence if you have it, otherwise Disengage",
		SHOW, "/cast [known:{19263}] {19263}; {781}", by = { survival = DISENGAGE } },
	{ name = "Freezing Trap", key = "SHIFT-F", asdf = "SHIFT-G", what = "Freezing Trap",
		SHOW, "/cast {1499}", by = { survival = false } },
	-- The number row: the big cooldowns.
	{ name = "Rapid Fire", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", what = "Rapid Fire",
		SHOW, "/cast {3045}", by = { survival = DETER } },
	{ name = "Bestial Wrath", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", what = "Bestial Wrath",
		SHOW, "/cast {19574}", by = { mm = FLARE, lonewolf = DISMISS, survival = RAPID } },
	-- With Shift: each key's rarer kin.
	{ name = "Scorpid", key = "SHIFT-Q", asdf = "SHIFT-Q", what = "Scorpid Sting",
		SHOW, "/cast {3043}", by = { survival = LACERATE } },
	{ name = "Summon Hawk", key = "SHIFT-E", asdf = "SHIFT-E", what = "Summon Hawk",
		SHOW, "/cast {1293241}", by = { survival = ARCANE, mm = SNIPER, lonewolf = SNIPER, bmpvp = VIPER } },
	-- In reach, for the builds that shoot: one press bites when Mongoose Bite is lit and strikes with Raptor Strike
	-- (which waits for no other), on R until Aimed Shot comes at 20.
	{ name = "Melee", role = "melee", key = "SHIFT-G", asdf = "SHIFT-R", early = "R", asdfEarly = "R",
		what = "Mongoose Bite when it's lit, and Raptor Strike",
		"#showtooltip {2973}", ATTACK, "/cast [known:{1495}] {1495}", "/cast {2973}", by = { survival = CONCUSSIVE } },
	{ name = "Volley", key = "SHIFT-T", asdf = "SHIFT-T", what = "Volley",
		SHOW, "/cast {1510}" },
	-- Never hurried: the far key, for what hides from you, in PvP (Marksmanship keeps Flare on 5, its slow
	-- utility). No taunt: questing, the pet's Growl holds what it fights; in a group the tank does.
	{ name = "Flare", key = "B", asdf = "B", what = "Flare",
		SHOW, "/cast {1543}", by = { bm = false, mm = false, lonewolf = false, survival = false } },
	{ name = "Frost Trap", key = "BUTTON5", asdf = "BUTTON5", what = "Frost Trap",
		SHOW, "/cast {13809}" },
	-- The long buff, on its key in every class: a build that takes Trueshot Aura has it there; another never sees it.
	{ name = "Trueshot", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Trueshot Aura",
		SHOW, "/cast {1299346}" },
	{ name = "Monkey", key = "2", asdf = "2", stay = true, what = "Aspect of the Monkey",
		SHOW, "/cast {13163}" },
	-- Your pet kept fed, where the other classes keep themselves up: the plainest food in your bags that it eats.
	{ name = "Feed Pet", key = "SHIFT-5", asdf = "SHIFT-5", what = "Feed your pet food it eats, from your bags",
		supply = { "petfood" }, show = "#showtooltip {6991}", before = { "/cast {6991}" } },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use.
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })
-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first. Track Hidden
-- finds the rogues PvP is full of; Tranquilizing Shot ends a boss's frenzy in the dungeons you run at 60, which a
-- PvP pet build never does.
Shy.Keys.Utility(JOBS, {
	{ name = "Track Humanoids", spells = { 19883 } },
	{ name = "Track Hidden", spells = { 19885 }, by = { bm = false, mm = false, survival = false, lonewolf = false } },
	{ name = "Track Beasts", spells = { 1494 } },
	{ name = "Tame Beast", spells = { 1515 } },
	{ name = "Scare Beast", spells = { 14327, 14326, 1513 } },
	{ name = "Eagle Eye", spells = { 6197 } },
	{ name = "Tranquilizing", what = "Tranquilizing Shot", spells = { 19801 }, by = { bmpvp = false } },
})
K.JOBS = JOBS

-- How to play, by level and build: each step a job by its name, in the order you press them.
local PET = { "Pet", "pet under half health" }

local BEAST = {   -- Beast Mastery, questing and in PvP alike
	{ from = 30, tip = "Your pet does much of the damage now. Send it in first, and stun with Intimidation if anything reaches you.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Summon Hawk" }, { "Aimed" },
			{ "Arcane" }, { "Multi-Shot", "on the move" }, { "Rapid Fire", "on a tough enemy" }, { "Concussive", "if it runs" },
			{ "Escape", "if it turns on you" }, { "Stop", "when it reaches you" },
			{ "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Freezing Trap", "on the extra enemy" }, { "Fire Trap", "in their path" }, { "Stop", "on one hitting you" },
			{ "Multi-Shot" }, { "Sting", "on each enemy" }, { "Summon Hawk" }, PET, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	{ from = 40, tip = "Bestial Wrath makes your pet a killer for a short while. Save it for tough enemies and pulls of two.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Bestial Wrath", "on a tough enemy" }, { "Rapid Fire", "on a tough enemy" },
			{ "Sting", "keep it up" }, { "Summon Hawk" }, { "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" },
			{ "Concussive", "if it runs" }, { "Escape", "if it turns on you" }, { "Stop", "when it reaches you" },
			{ "Melee", "when it reaches you" }, PET },
		cleave = { { "Freezing Trap", "on the extra enemy" }, { "Bestial Wrath", "on 2+ enemies" }, { "Fire Trap", "under the pack" },
			{ "Volley", "on 3+ enemies" }, { "Multi-Shot" }, { "Sting", "on each enemy" }, { "Summon Hawk" }, PET } },
	{ from = 50, tip = "Pulls of two are safe now. Bestial Wrath on one while the pet holds it, Freezing Trap on the other.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Bestial Wrath", "on a tough enemy" }, { "Rapid Fire", "on a tough enemy" },
			{ "Sting", "keep it up" }, { "Summon Hawk" }, { "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" },
			{ "Concussive", "if it runs" }, { "Escape", "if it turns on you" }, { "Stop", "when it reaches you" },
			{ "Melee", "when it reaches you" }, PET },
		cleave = { { "Freezing Trap", "on the extra enemy" }, { "Bestial Wrath", "on 2+ enemies" }, { "Fire Trap", "under the pack" },
			{ "Volley", "on 3+ enemies" }, { "Multi-Shot" }, { "Sting", "on each enemy" }, { "Summon Hawk" }, PET,
			{ "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
}

local MARKS = {   -- Marksmanship, with the pet out or put away
	{ from = 30, tip = "Keep Trueshot Aura up and open from as far as you can. Your pet keeps them busy while you shoot.",
		single = { { "Trueshot", "keep it up" }, { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" },
			{ "Rapid Fire", "on a tough enemy" }, { "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" }, { "Concussive", "if it runs" },
			{ "Escape", "if it turns on you" }, { "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Fire Trap", "in their path" }, { "Multi-Shot" },
			{ "Sting", "on each enemy" }, { "Arcane" }, { "Frost Trap", "to slow them all" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	{ from = 40, tip = "Open with Sniper Shot from the edge of your range. A pull should be half done before it reaches you.",
		single = { { "Trueshot", "keep it up" }, { "Hunter's Mark", "to open" }, { "Sniper Shot", "to open, then when ready" },
			{ "Attack" }, { "Sting", "keep it up" }, { "Rapid Fire", "on a tough enemy" }, { "Aimed" }, { "Arcane" },
			{ "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Escape", "if it turns on you" },
			{ "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Fire Trap", "under the pack" }, { "Volley", "on 3+ enemies" },
			{ "Multi-Shot" }, { "Sting", "on each enemy" }, { "Sniper Shot" }, { "Arcane" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	{ from = 50, tip = "Most things die before they reach you now. Feign Death if a pull grows, and they go home.",
		single = { { "Trueshot", "keep it up" }, { "Hunter's Mark", "to open" }, { "Sniper Shot", "to open, then when ready" },
			{ "Attack" }, { "Sting", "keep it up" }, { "Rapid Fire", "on a tough enemy" }, { "Aimed" }, { "Arcane" },
			{ "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Escape", "if it turns on you" },
			{ "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Fire Trap", "under the pack" }, { "Volley", "on 3+ enemies" },
			{ "Multi-Shot" }, { "Sting", "on each enemy" }, { "Sniper Shot" }, { "Arcane" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
}

local PLAY = {
	{ from = 1, tip = "You start in melee. Shoot as it comes, then hit it with Raptor Strike once it reaches you.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Arcane" },
			{ "Melee", "when it reaches you" }, { "Concussive", "if it runs" } },
		cleave = { { "Attack" }, { "Sting", "on each enemy" }, { "Arcane" }, { "Melee", "when it reaches you" } } },
	{ from = 10, tip = "Your pet holds the enemy while you shoot. Send it in first, mend it between fights, and keep Hawk up.",
		single = { { "Aspect", "keep it up" }, { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Arcane" },
			{ "Concussive", "if it runs" }, { "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Attack" }, { "Sting", "on each enemy" }, { "Arcane" }, { "Concussive", "on one coming at you" }, PET } },
	{ from = 20, tip = "Aimed Shot is your big shot now, Multi-Shot its twin for packs. Trap a second enemy and kill the first.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Aimed" }, { "Arcane" },
			{ "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Escape", "if it turns on you" },
			{ "Wing Clip", "when it reaches you" }, { "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Fire Trap", "in their path" }, { "Multi-Shot" },
			{ "Sting", "on each enemy" }, { "Arcane" }, PET } },
	{ from = 30, tip = "Save Rapid Fire for tough fights, and Feign Death if a fight goes bad. They drop you and go home.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Rapid Fire", "on a tough enemy" },
			{ "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Wing Clip", "when it reaches you" },
			{ "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Freezing Trap", "on the extra enemy" }, { "Fire Trap", "in their path" }, { "Multi-Shot" },
			{ "Sting", "on each enemy" }, { "Arcane" }, { "Frost Trap", "to slow them all" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	{ from = 40, tip = "Volley and Explosive Trap clear packs but pull them onto you. Let your pet hold them first.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Rapid Fire", "on a tough enemy" },
			{ "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Wing Clip", "when it reaches you" },
			{ "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Freezing Trap", "on the extra enemy" }, { "Fire Trap", "under the pack" }, { "Volley", "on 3+ enemies" },
			{ "Multi-Shot" }, { "Sting", "on each enemy" }, { "Arcane" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	{ from = 50, tip = "Your gear carries you now. Keep the sting and the pet up, and pull two at a time when it feels safe.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "keep it up" }, { "Rapid Fire", "on a tough enemy" },
			{ "Aimed" }, { "Arcane" }, { "Multi-Shot", "on the move" }, { "Concussive", "if it runs" }, { "Wing Clip", "when it reaches you" },
			{ "Melee", "when it reaches you" }, PET },
		cleave = { { "Stop", "on the extra enemy" }, { "Freezing Trap", "on the extra enemy" }, { "Fire Trap", "under the pack" }, { "Volley", "on 3+ enemies" },
			{ "Multi-Shot" }, { "Sting", "on each enemy" }, { "Arcane" }, { "Monkey", "when they reach you" }, { "Feign", "if it goes bad" } } },
	-- Survival fights in reach from the start: Raptor Strike on R, the Monkey (the Beast from 30) on 1.
	{ from = 1, build = "survival", tip = "You fight in melee. Shoot as it comes, then hit it with Raptor Strike once it reaches you.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" }, { "Arcane", "as it comes in" },
			{ "Raptor" }, { "Concussive", "if it runs" } },
		cleave = { { "Attack" }, { "Sting", "on each enemy" }, { "Arcane" }, { "Raptor" } } },
	{ from = 10, build = "survival", tip = "Open with a shot and send your pet in, then strike beside it. The Monkey keeps you dodging.",
		single = { { "Aspect", "keep it up" }, { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" },
			{ "Arcane", "as it comes in" }, { "Raptor" }, { "Mongoose", "when it's lit" }, { "Wing Clip", "if it runs" }, PET },
		cleave = { { "Attack" }, { "Sting", "on each enemy" }, { "Fire Trap", "at your feet" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, PET } },
	{ from = 20, build = "survival", tip = "Shoot as it comes in, then strike in melee. Disengage hands an enemy back to your pet.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" }, { "Arcane", "as it comes in" },
			{ "Raptor" }, { "Mongoose", "when it's lit" }, { "Wing Clip", "if it runs" }, { "Deterrence", "under half health" }, PET },
		cleave = { { "Fire Trap", "at your feet" }, { "Stop", "on the extra enemy" }, { "Raptor" }, { "Mongoose", "when it's lit" },
			{ "Multi-Shot", "as they come in" }, { "Sting", "on each enemy" }, { "Disengage", "to give one to your pet" }, PET } },
	{ from = 30, build = "survival", tip = "Fight in the Beast. Strider Kick and Lacerate fill the gaps between strikes. Deterrence when two hit you.",
		single = { { "Aspect", "keep it up" }, { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" },
			{ "Raptor" }, { "Strider Kick" },
			{ "Mongoose", "when it's lit" }, { "Lacerate", "keep it up" }, { "Rapid Fire", "on a tough enemy" },
			{ "Wing Clip", "if it runs" }, { "Deterrence", "under half health" }, PET },
		cleave = { { "Fire Trap", "at your feet" }, { "Stop", "on the extra enemy" }, { "Deterrence", "when two hit you" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, { "Strider Kick" }, { "Lacerate", "on each enemy" },
			{ "Disengage", "to give one to your pet" }, { "Monkey", "when they hit hard" }, { "Feign", "if it goes bad" } } },
	{ from = 40, build = "survival", tip = "Keep Hunter's Mark on what you fight. Mongoose Bite lights far more often on a marked enemy.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, { "Strider Kick" },
			{ "Lacerate", "keep it up" }, { "Rapid Fire", "on a tough enemy" }, { "Wing Clip", "if it runs" },
			{ "Deterrence", "under half health" }, PET },
		cleave = { { "Fire Trap", "at your feet" }, { "Stop", "on the extra enemy" }, { "Deterrence", "when two hit you" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, { "Strider Kick" }, { "Lacerate", "on each enemy" }, { "Volley", "on 3+ at range" },
			{ "Monkey", "when they hit hard" }, { "Feign", "if it goes bad" } } },
	{ from = 50, build = "survival", tip = "Pull two at a time. The fire trap at your feet and your pet beside you hold them both.",
		single = { { "Hunter's Mark", "to open" }, { "Attack" }, { "Sting", "as it comes in" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, { "Strider Kick" },
			{ "Lacerate", "keep it up" }, { "Rapid Fire", "on a tough enemy" }, { "Wing Clip", "if it runs" },
			{ "Deterrence", "under half health" }, PET },
		cleave = { { "Fire Trap", "at your feet" }, { "Stop", "on the extra enemy" }, { "Deterrence", "when two hit you" }, { "Raptor" },
			{ "Mongoose", "when it's lit" }, { "Strider Kick" }, { "Lacerate", "on each enemy" },
			{ "Disengage", "to give one to your pet" }, { "Monkey", "when they hit hard" }, { "Feign", "if it goes bad" } } },
}
-- A build's own brackets, from a shared list (the tip may be its own; a job the build never has left out; `more`
-- adds the build's own steps to a bracket, by its level, after the step named `after` or at the end:
-- { [from] = { single = { after = "Sting", step, ... }, cleave = {...} } }).
local function Own(build, list, tips, without, more)
	local function Steps(steps)
		if not without then return steps end
		local out = {}
		for _, step in ipairs(steps) do
			if step[1] ~= without then out[#out + 1] = step end
		end
		return out
	end
	local function Plus(steps, extra)
		if not extra then return steps end
		local out, put = {}, false
		for _, step in ipairs(steps) do
			out[#out + 1] = step
			if step[1] == extra.after then
				for _, own in ipairs(extra) do out[#out + 1] = own end
				put = true
			end
		end
		if not put then
			for _, own in ipairs(extra) do out[#out + 1] = own end
		end
		return out
	end
	for _, bracket in ipairs(list) do
		local own = more and more[bracket.from] or {}
		PLAY[#PLAY + 1] = { from = bracket.from, build = build, tip = tips and tips[bracket.from] or bracket.tip,
			single = Plus(Steps(bracket.single), own.single), cleave = Plus(Steps(bracket.cleave), own.cleave) }
	end
end
Own("bm", BEAST)
local VIPER_STEP = { "Viper", "on a caster or healer" }
Own("bmpvp", BEAST, { [50] = "Against players, Concussive Shot keeps them off you while your pet runs them down." }, "Summon Hawk",
	{ [40] = { single = { after = "Sting", VIPER_STEP } }, [50] = { single = { after = "Sting", VIPER_STEP } } })
Own("mm", MARKS)
Own("lonewolf", MARKS, { [40] = "Questing, keep the pet out to hold enemies; in a dungeon put it away and let the tank hold them." })
K.PLAY = PLAY

local OPTS = {
	knows = 2973,                            -- Raptor Strike: a hunter's from level 1
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isHunter then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isHunter then
		T:Print("your keys are laid out on a hunter only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T)
end

-- From login on, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
