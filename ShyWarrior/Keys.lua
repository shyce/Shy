-- A warrior's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the ability by your
-- stance and by what you have learned, so an ability arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy warrior keys)
--   ns.Keys.Run("force")  every key, even ones you kept or moved (/shy warrior keys force)
--   ns.Keys.List()    every key and what it does, as text
--
-- The rule on every key: an ability that needs another stance takes you there on the first press and is used
-- on the second. Three keys are the stance's own instead: Counter (Overpower, Revenge, Whirlwind), Taunt
-- (Mocking Blow, Taunt) and Wall (Retaliation, Recklessness; a shield's is Shield Wall alone, the rule's way).
-- Disarm only ever disarms: its key is
-- where a side-step lands while Shift is held, so a slip never changes your stance.
--
-- Each job names its key for WASD (key) and for ASDF (asdf: S forward, F back, the hand a key further right).
-- ASDF keeps every WASD key but the ones it moves with: F's job goes to G, G's to W, and the same with Shift.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}

-- The stance to fight in (OPTS.keep): the first of a list you have.
local BATTLE_STANCE = { 2457 }   -- Battle Stance
local DEFENSIVE_STANCE = { 71, 2457 }   -- Defensive Stance, Battle Stance
local BERSERKER_STANCE = { 2458, 2457 }   -- Berserker Stance, Battle Stance
ns.Keys = K

local SHOW, ATTACK = "#showtooltip", "/startattack"

-- Arms and Fury: what a shield's key does for a two-hander or two weapons instead.
local function Damage(job) return { arms = job, armspvp = job, fury = job } end

-- Sword and board: the same keys, with Defensive Stance's ability shown first.
local function Shield(job) return { protsolo = job, prot = job } end

-- The strike: each tree's own big hit once its talent comes, Slam until then, Rend before that.
local function Strike(spell, name)
	return { name = "Strike", role = "strike", what = name .. "; Slam until 40, Rend until 20",
		SHOW, ATTACK, ("/cast [known:{%d}] {%d}; [known:{1240193}] {1240193}; {772}"):format(spell, spell) }
end
local MORTAL_STRIKE = Strike(12294, "Mortal Strike")
-- Two weapons never Slam (without its talent Slam stops both swings): Heroic Strike, what Fury presses most, until
-- Bloodthirst.
local BLOODTHIRST = { name = "Strike", role = "strike", what = "Bloodthirst, or Heroic Strike until you have it",
	SHOW, ATTACK, "/cast [known:{23881}] {23881}; !{78}" }
-- A shield's: Shield Slam once its talent comes, Rend until then, never Slam. Slam's cast stops your swings, and with a
-- fast one-hander it hits for too little to be worth it.
local SHIELD_SLAM = { name = "Strike", role = "strike", what = "Shield Slam, or Rend until you have it",
	SHOW, ATTACK, "/cast [known:{23922}] {23922}; {772}" }

local REND = { name = "Rend", what = "Rend", SHOW, ATTACK, "/cast [stance:3] {2457}; {772}" }
local HAMSTRING = { name = "Slow", role = "slow", what = "Hamstring", SHOW, ATTACK, "/cast [stance:1/3] {1715}; {2457}" }
-- A shield's taunt: Taunt first, from Defensive Stance.
local SHIELD_TAUNT = { name = "Taunt", role = "taunt", what = "Taunt what's under your mouse, or your target. Mocking Blow in Battle Stance",
	SHOW, "/cast [stance:2,@mouseover,harm,nodead][stance:2] {355}; [stance:1] {694}; {71}" }
-- No shield to go back to: Charge from Battle Stance, Intercept from Berserker, and stay.
local DAMAGE_CHARGE = { name = "Charge", role = "charge", what = "Charge, with Bloodrage. Intercept in a fight from 30",
	SHOW, "/cast [nocombat,stance:1] {100}; [nocombat] {2457}; [stance:3] {20252}; [known:{20252}] {2458}", "/cast [combat] {2687}" }
-- A shield never leaves Defensive Stance in a fight: no Intercept, so a second press can't take your block away.
local SHIELD_CHARGE = { name = "Charge", role = "charge", what = "Charge, then back to Defensive Stance with Bloodrage",
	SHOW, "/cast [nocombat,stance:1][nocombat,stance:2,known:{1310317}] {100}; [nocombat] {2457}",
	"/cast [combat,nostance:2] {71}", "/cast [combat] {2687}" }

local JOBS = {
	-- The fight, under the fingers that are free while you move. The strike comes first: until Slam it is Rend,
	-- and an ability stands on the first key that casts it, so a two-hander's Rend is on R too, not on Q.
	{ name = "Strike", role = "strike", key = "R", asdf = "R", what = "Shield Slam, Mortal Strike or Bloodthirst. Slam until 40, Rend until 20",
		SHOW, ATTACK, "/cast [known:{23922}] {23922}; [known:{12294}] {12294}; [known:{23881}] {23881}; [known:{1240193}] {1240193}; {772}",
		by = { protsolo = SHIELD_SLAM, prot = SHIELD_SLAM, arms = MORTAL_STRIKE, armspvp = MORTAL_STRIKE, fury = BLOODTHIRST } },
	{ name = "Sunder", key = "Q", asdf = "Q", what = "Sunder Armor",
		SHOW, ATTACK, "/cast {7386}",
		-- (In PvP every runner wants Hamstring: it takes Q, and Rend steps over to Shift + Q.)
		by = { arms = REND, fury = REND, armspvp = HAMSTRING } },
	{ name = "Counter", role = "counter", key = "E", asdf = "E", what = "Revenge. Overpower in Battle Stance, Whirlwind in Berserker",
		SHOW, ATTACK, "/cast [stance:1] {7384}; [stance:3] {1680}; {6572}",
		-- Fury lives in Berserker Stance: its key shows Whirlwind first. A stance's own ability counts only once it
		-- is learned (Revenge at 14, Whirlwind at 36): until then the key shows Overpower, not a blank.
		by = { fury = { name = "Counter", role = "counter", what = "Whirlwind in Berserker Stance. Overpower in Battle, Revenge in Defensive",
				SHOW, ATTACK, "/cast [stance:3,known:{1680}] {1680}; [nostance:2] {7384}; {6572}" },
			protsolo = { name = "Counter", role = "counter", what = "Revenge. Overpower in Battle Stance, Whirlwind in Berserker",
				SHOW, ATTACK, "/cast [stance:2,known:{6572}] {6572}; [stance:3,known:{1680}] {1680}; {7384}" },
			prot = { name = "Counter", role = "counter", what = "Revenge. Overpower in Battle Stance, Whirlwind in Berserker",
				SHOW, ATTACK, "/cast [stance:2,known:{6572}] {6572}; [stance:3,known:{1680}] {1680}; {7384}" } } },
	{ name = "Heroic", key = "G", asdf = "W", early = "F", asdfEarly = "G", what = "Heroic Strike",
		SHOW, ATTACK, "/cast !{78}" },
	{ name = "Clap", key = "T", asdf = "T", what = "Thunder Clap",
		SHOW, "/cast [stance:3] {2457}; {6343}" },
	{ name = "Taunt", role = "taunt", key = "Z", asdf = "Z", what = "Taunt what's under your mouse, or your target. Mocking Blow in Battle Stance",
		SHOW, "/cast [stance:1] {694}; [stance:2,@mouseover,harm,nodead][stance:2] {355}; {71}",
		-- (A two-hander or two weapons never taunt: no key.)
		by = { protsolo = SHIELD_TAUNT, prot = SHIELD_TAUNT, arms = false, armspvp = false, fury = false } },
	{ name = "Charge", role = "charge", key = "C", asdf = "C", what = "Charge, then back to Defensive Stance with Bloodrage. Intercept in a fight from 30",
		SHOW,
		"/cast [nocombat,stance:1][nocombat,stance:2,known:{1310317}] {100}; [nocombat] {2457}; [stance:3] {20252}; [stance:2,known:{20252}] {2458}",
		"/cast [combat,nostance:2] {71}",
		"/cast [combat] {2687}",
		by = { arms = DAMAGE_CHARGE, armspvp = DAMAGE_CHARGE, fury = DAMAGE_CHARGE, protsolo = SHIELD_CHARGE, prot = SHIELD_CHARGE } },
	{ name = "Victory", key = "V", asdf = "V", what = "Victory Rush",
		SHOW, ATTACK, "/cast {402927}" },
	{ name = "Bloodrage", key = "X", asdf = "X", what = "Bloodrage",
		SHOW, "/cast {2687}" },
	{ name = "Shout", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Battle Shout",
		SHOW, "/cast {6673}" },
	-- Every fleeing mob wants Hamstring, so it has a plain key.
	{ name = "Slow", role = "slow", key = "B", asdf = "B", what = "Hamstring. Piercing Howl in Defensive Stance once you have it",
		SHOW, ATTACK, "/cast [stance:1/3] {1715}; [known:{12323}] {12323}; {2457}",
		by = { arms = HAMSTRING, fury = HAMSTRING, armspvp = false } },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Block", key = "BUTTON4", asdf = "BUTTON4", what = "Shield Block",
		SHOW, "/cast [stance:2] {2565}; {71}",
		by = { arms = { name = "Sweeping Strikes", what = "Sweeping Strikes", SHOW, "/cast {12292}" },
			armspvp = { name = "Sweeping Strikes", what = "Sweeping Strikes", SHOW, "/cast {12292}" },
			-- (Fury presses Berserker Rage every half minute for rage: the thumb's. Death Wish, rarer, is Shift's.)
			fury = { name = "Berserker Rage", what = "Berserker Rage", SHOW, "/cast [stance:3] {18499}; {2458}" } } },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Shield Bash. Pummel in Berserker Stance",
		SHOW, "/cast [nostance:3] {72}; [known:{6552}] {6552}; {2457}",
		-- No shield to bash with: Pummel, from Berserker Stance, once you have it.
		by = Damage({ name = "Stop", role = "stop", what = "Pummel", SHOW, "/cast [stance:3] {6552}; [known:{6552}] {2458}" }) },
	-- (No shield, no Last Stand: a two-hander's is Berserker Rage, the answer to a fear, and Fury's Death Wish. It
	-- never stands in: a long cooldown has no place on the stop's key.)
	{ name = "Stand", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", what = "Last Stand",
		SHOW, "/cast {12975}",
		by = { arms = { name = "Berserker Rage", what = "Berserker Rage", SHOW, "/cast [stance:3] {18499}; {2458}" },
			armspvp = { name = "Berserker Rage", what = "Berserker Rage", SHOW, "/cast [stance:3] {18499}; {2458}" },
			fury = { name = "Death Wish", what = "Death Wish", stay = true, SHOW, "/cast {12328}" } } },
	{ name = "Concussion", key = "SHIFT-F", asdf = "SHIFT-G", what = "Concussion Blow",
		SHOW, ATTACK, "/cast {12809}",
		by = Damage({ name = "Piercing Howl", what = "Piercing Howl", SHOW, "/cast {12323}" }) },
	-- The number row.
	{ name = "Wall", role = "wall", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", stay = true, what = "Shield Wall. Retaliation in Battle Stance, Recklessness in Berserker",
		SHOW, "/cast [stance:1] {20230}; [stance:3] {1719}; {871}",
		-- A shield's wall is Shield Wall, from 28: Defensive Stance's own, so the first press takes you there. A
		-- two-hander's or two weapons' is Retaliation, Recklessness in Berserker Stance once learned.
		by = { protsolo = { name = "Wall", role = "wall", what = "Shield Wall", SHOW, "/cast [stance:2] {871}; {71}" },
			prot = { name = "Wall", role = "wall", what = "Shield Wall", SHOW, "/cast [stance:2] {871}; {71}" },
			arms = { name = "Wall", role = "wall", what = "Retaliation. Recklessness in Berserker Stance",
				SHOW, "/cast [stance:3,known:{1719}] {1719}; [stance:1] {20230}; {2457}" },
			armspvp = { name = "Wall", role = "wall", what = "Retaliation. Recklessness in Berserker Stance",
				SHOW, "/cast [stance:3,known:{1719}] {1719}; [stance:1] {20230}; {2457}" },
			fury = { name = "Wall", role = "wall", what = "Retaliation. Recklessness in Berserker Stance",
				SHOW, "/cast [stance:3,known:{1719}] {1719}; [stance:1] {20230}; {2457}" } } },
	{ name = "Pull", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", stay = true, what = "Shoot or Throw, whichever you carry",
		SHOW, "/cast [worn:Crossbows] {7919}; [worn:Bows] {2480}; [worn:Guns] {7918}; {2764}" },
	-- With Shift: each key's rarer kin.
	-- (Sunder Armor is a tank's: a two-hander or two weapons have Rend on Q and no Sunder key, and in PvP Rend is
	-- here, under Hamstring. A shield has no Rend key once Shield Slam takes R: its rage goes to Sunder Armor and
	-- Heroic Strike.)
	{ name = "Rend", key = "SHIFT-Q", asdf = "SHIFT-Q", what = "Rend",
		SHOW, ATTACK, "/cast [stance:3] {2457}; {772}",
		by = { arms = false, fury = false, prot = false, protsolo = false } },
	-- (A shield lives in Defensive Stance: the 10 rage a stance change keeps is short of Execute's cost, so a shield
	-- has no Execute key.)
	-- (Pressed at the end of every fight: it keeps one key, never standing in for a few levels elsewhere.)
	{ name = "Execute", key = "SHIFT-E", asdf = "SHIFT-E", stay = true, what = "Execute",
		SHOW, ATTACK, "/cast [stance:1/3] {5308}; [known:{5308}] {2457}",
		by = Shield(false) },
	-- (A shield never Slams, nor do two weapons, so their strike has no rarer kin: Shift + R stays free.)
	{ name = "Slam", key = "SHIFT-R", asdf = "SHIFT-R", what = "Slam",
		SHOW, ATTACK, "/cast {1240193}",
		by = { protsolo = false, prot = false, fury = false } },
	-- The other thing you do to a pack, with Shift on Thunder Clap's key. It puts every mob in reach in the fight,
	-- so it is never on Shift and a key you move with.
	{ name = "Demoralizing", key = "SHIFT-T", asdf = "SHIFT-T", stay = true, what = "Demoralizing Shout",
		SHOW, "/cast {1160}" },
	{ name = "Cleave", key = "SHIFT-G", asdf = "SHIFT-W", what = "Cleave",
		SHOW, ATTACK, "/cast !{845}" },
	-- (A slip with this one turns every mob in reach on you: it never stands in on an easy key. A group's tank alone
	-- wants it: alone, or without a shield, Mouse 5 stays free.)
	{ name = "Challenging", key = "BUTTON5", asdf = "BUTTON5", stay = true, what = "Challenging Shout",
		SHOW, "/cast {1161}",
		by = { protsolo = false, arms = false, armspvp = false, fury = false } },
	-- Berserker Rage is a shield's last resort, for a fear: on the number row, as Shift + C is the bandage's on every
	-- class.
	{ name = "Berserker Rage", key = "SHIFT-5", asdf = "SHIFT-5", stay = true, what = "Berserker Rage",
		SHOW, "/cast [stance:3] {18499}; {2458}",
		-- (A two-hander or two weapons have Berserker Rage on the thumb, and neither build takes Last Stand or
		-- Reckless Swings: no key here, rather than a key that never comes.)
		by = Damage(false) },
	-- (Disarm is Defensive Stance's and the key never changes stance: a two-hander or two weapons have none.)
	{ name = "Disarm", key = "SHIFT-D", asdf = "SHIFT-D", stay = true, what = "Disarm, in Defensive Stance",
		SHOW, "/cast [stance:2] {676}",
		by = Damage(false) },
	-- A last resort when too many are on you: rare, and a slip sends a pack running into more, so it waits on the
	-- far thumb button with Shift.
	{ name = "Intimidating", key = "SHIFT-BUTTON5", asdf = "SHIFT-BUTTON5", stay = true, what = "Intimidating Shout",
		SHOW, "/cast {5246}" },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use. (No water for a warrior: Shift + X
-- stays free, so the row reads the same on every character.)
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { stone = true, potion = { name = "Rage", kind = "rage", what = "Drink your best rage potion" } })
-- 1 2 3: your stances, each the spell itself on the left flyout, beside the game's own bar of them.
Shy.Keys.Stays(JOBS, { plain = { { name = "Battle Stance", 2457 }, { name = "Defensive Stance", 71 }, { name = "Berserker Stance", 2458 } } })
K.JOBS = JOBS

-- How to play, by level and build: each step a job (the key it is on and what it casts then), in the order you
-- press them when they're ready; single is one enemy, cleave two to four close together. From 20 each build
-- has its own.

-- A shield from 10, in Defensive Stance: Sunder Armor, the block and Shield Bash are part of every fight.
local function ShieldFrom10(build)
	return { from = 10, build = build, tip = "Defensive Stance from 10. Bloodrage after Charge, Revenge whenever it lights up, Sunder Armor with spare rage.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Strike", "keep it up" }, { "Sunder", "rage to spare" }, { "Heroic", "lots of rage" }, { "Stop", "to stop a cast" },
			{ "Slow", "when it runs" }, { "Shout", "keep it up" } },
		cleave = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" },
			{ "Counter", "when it's lit" }, { "Sunder", "on each enemy" }, { "Heroic", "rage to spare" } } }
end

local PLAY = {
	-- (Until each tree's big hit, the strike's key is Rend: the steps name the key, Strike.)
	{ from = 1, tip = "Charge in, keep Rend on it and spend spare rage on Heroic Strike. You'll rest after most fights.",
		single = { { "Charge", "to open" }, { "Strike", "keep it up" }, { "Heroic", "rage to spare" },
			{ "Slow", "when it runs" }, { "Shout", "keep it up" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Strike", "on each enemy" },
			{ "Heroic", "rage to spare" } } },
	{ from = 10, tip = "Bloodrage after Charge for an early start, and press Overpower or Revenge whenever it lights up.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" },
			{ "Strike", "keep it up" }, { "Heroic", "rage to spare" }, { "Stop", "to stop a cast" }, { "Slow", "when it runs" },
			{ "Shout", "keep it up" } },
		cleave = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" },
			{ "Counter", "when it's lit" }, { "Strike", "on each enemy" }, { "Heroic", "rage to spare" } } },
	-- No build picked: a two-hander's way in Battle Stance, with the shield's keys there if you carry one.
	{ from = 20, tip = "Charge in, keep Rend up and Overpower when it lights. Your strike when it's ready, Heroic Strike with spare rage.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Rend", "keep it up" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Heroic", "rage to spare" },
			{ "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Sunder", "on a tough one" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Rend", "on each enemy" },
			{ "Cleave", "rage to spare" }, { "Counter", "when it's lit" }, { "Victory", "when it's lit" } } },
	-- Fury's strike is Heroic Strike until Bloodthirst, and Rend has its own key, Q.
	{ from = 1, build = "fury", tip = "Charge in, keep Rend on it and spend spare rage on Heroic Strike. You'll rest after most fights.",
		single = { { "Charge", "to open" }, { "Rend", "keep it up" }, { "Strike", "rage to spare" },
			{ "Slow", "when it runs" }, { "Shout", "keep it up" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Rend", "on each enemy" },
			{ "Strike", "rage to spare" } } },
	{ from = 10, build = "fury", tip = "Bloodrage after Charge for an early start, and press Overpower whenever it lights up.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" },
			{ "Rend", "keep it up" }, { "Strike", "rage to spare" }, { "Slow", "when it runs" }, { "Shout", "keep it up" } },
		cleave = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" },
			{ "Counter", "when it's lit" }, { "Rend", "on each enemy" }, { "Strike", "rage to spare" } } },

	-- Sword and board: Defensive Stance, a block for every Revenge, and little rest.
	ShieldFrom10("protsolo"),
	{ from = 20, build = "protsolo", tip = "You fight in Defensive Stance now. Block, then Revenge, and you'll hardly need to rest.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Victory", "when it's lit" }, { "Stop", "to stop a cast" }, { "Strike", "keep it up" }, { "Sunder", "rage to spare" },
			{ "Heroic", "lots of rage" }, { "Stand", "low on health" }, { "Slow", "when it runs" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Block", "when you're hit" }, { "Cleave", "rage to spare" }, { "Victory", "when it's lit" }, { "Wall", "if it goes badly" },
			{ "Stand", "low on health" } } },
	{ from = 30, build = "protsolo", tip = "Pull two or three at a time. Concussion Blow buys you a breather, and Last Stand saves a bad pull.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Victory", "when it's lit" }, { "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Strike", "keep it up" },
			{ "Sunder", "rage to spare" }, { "Heroic", "lots of rage" }, { "Stand", "low on health" }, { "Slow", "when it runs" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Block", "when you're hit" }, { "Cleave", "rage to spare" }, { "Concussion", "on the hardest hitter" },
			{ "Disarm", "on a hard hitter" }, { "Wall", "if it goes badly" }, { "Stand", "low on health" } } },
	{ from = 40, build = "protsolo", tip = "Shield Slam hits hardest of all you have. Press it, Revenge and your block, and the rest is filler.",
		single = { { "Charge", "to open" }, { "Counter", "when it's lit" }, { "Strike", "when it's ready" }, { "Block", "when you're hit" },
			{ "Victory", "when it's lit" }, { "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Sunder", "rage to spare" },
			{ "Heroic", "lots of rage" }, { "Bloodrage", "for rage" }, { "Stand", "low on health" }, { "Slow", "when it runs" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Block", "when you're hit" }, { "Cleave", "rage to spare" },
			{ "Disarm", "on a hard hitter" }, { "Wall", "if it goes badly" }, { "Stand", "low on health" } } },
	{ from = 50, build = "protsolo", tip = "Big pulls are yours now. Thunder Clap and Demoralizing Shout keep the pack weak, Shield Wall when it goes badly.",
		single = { { "Charge", "to open" }, { "Counter", "when it's lit" }, { "Strike", "when it's ready" }, { "Block", "when you're hit" },
			{ "Victory", "when it's lit" }, { "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Sunder", "rage to spare" },
			{ "Heroic", "lots of rage" }, { "Bloodrage", "for rage" }, { "Stand", "low on health" }, { "Slow", "when it runs" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Block", "when you're hit" }, { "Cleave", "rage to spare" },
			{ "Slow", "if they run", as = "known" }, { "Wall", "if it goes badly" }, { "Stand", "low on health" } } },

	-- Protection for dungeons: the same shield, Sunder Armor and Taunt to hold what you pull.
	ShieldFrom10("prot"),
	{ from = 20, build = "prot", tip = "Stay in Defensive Stance and stack Sunder Armor on what you pull. Taunt anything that turns away.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Sunder", "stack it" }, { "Stop", "to stop a cast" }, { "Victory", "when it's lit" }, { "Strike", "keep it up" },
			{ "Heroic", "lots of rage" }, { "Taunt", "if it turns away" }, { "Stand", "low on health" } },
		cleave = { { "Pull", "to pull to you" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Sunder", "on each enemy" }, { "Taunt", "if one turns away" }, { "Cleave", "rage to spare" }, { "Wall", "if it goes badly" },
			{ "Stand", "low on health" } } },
	{ from = 30, build = "prot", tip = "Mark your pulls and hold them. Concussion Blow and Shield Bash stop the casters, Last Stand saves a bad pull.",
		single = { { "Charge", "to open" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" }, { "Sunder", "stack it" },
			{ "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Victory", "when it's lit" }, { "Strike", "keep it up" },
			{ "Heroic", "lots of rage" }, { "Taunt", "if it turns away" }, { "Stand", "low on health" }, { "Bloodrage", "for rage" } },
		cleave = { { "Pull", "to pull to you" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Counter", "when it's lit" },
			{ "Sunder", "on each enemy" }, { "Taunt", "if one turns away" }, { "Challenging", "if they all turn" },
			{ "Cleave", "rage to spare" }, { "Wall", "if it goes badly" }, { "Stand", "low on health" } } },
	{ from = 40, build = "prot", tip = "Shield Slam and Revenge hold the pack on you. Keep Sunder Armor stacked on the one everyone hits.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Sunder", "stack it" }, { "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Victory", "when it's lit" },
			{ "Heroic", "lots of rage" }, { "Taunt", "if it turns away" }, { "Stand", "low on health" }, { "Bloodrage", "for rage" } },
		cleave = { { "Pull", "to pull to you" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Strike", "when it's ready" },
			{ "Counter", "when it's lit" }, { "Sunder", "on each enemy" }, { "Taunt", "if one turns away" },
			{ "Challenging", "if they all turn" }, { "Cleave", "rage to spare" }, { "Wall", "if it goes badly" } } },
	{ from = 50, build = "prot", tip = "Shield Wall and Last Stand are your saves for a pull gone wrong. Use one, then the other.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Block", "when you're hit" },
			{ "Sunder", "stack it" }, { "Stop", "to stop a cast" }, { "Concussion", "when it's ready" }, { "Victory", "when it's lit" },
			{ "Heroic", "lots of rage" }, { "Taunt", "if it turns away" }, { "Wall", "if it goes badly" }, { "Stand", "low on health" },
			{ "Bloodrage", "for rage" } },
		cleave = { { "Pull", "to pull to you" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Strike", "when it's ready" },
			{ "Counter", "when it's lit" }, { "Sunder", "on each enemy" }, { "Taunt", "if one turns away" },
			{ "Challenging", "if they all turn" }, { "Cleave", "rage to spare" }, { "Wall", "if it goes badly" } } },

	-- Arms: one big two-hander from Battle Stance.
	{ from = 20, build = "arms", tip = "Charge into every pull, Rend and Overpower, then Slam. Victory Rush heals you between fights.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Rend", "keep it up" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Heroic", "lots of rage" },
			{ "Slow", "when it runs" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Rend", "on each enemy" }, { "Demoralizing", "on 3+ enemies" },
			{ "Cleave", "rage to spare" }, { "Counter", "when it's lit" }, { "Victory", "when it's lit" } } },
	{ from = 30, build = "arms", tip = "Sweeping Strikes makes two at once easy. Pull a pair, Sweeping Strikes, then Cleave or Slam.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Rend", "keep it up" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Heroic", "lots of rage" },
			{ "Slow", "when it runs" }, { "Wall", "if it goes badly" }, { "Berserker Rage", "if you're feared" }, { "Stop", "to stop a cast" } },
		cleave = { { "Charge", "to open" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Clap", "on 3+ enemies" }, { "Cleave", "rage to spare" },
			{ "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Rend", "on each enemy" }, { "Victory", "when it's lit" } } },
	{ from = 40, build = "arms", tip = "Mortal Strike every time it's ready, Overpower when it lights, and Slam with what rage is left.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Execute", "under 20% health" },
			{ "Rend", "keep it up" }, { "Victory", "when it's lit" }, { "Slam", "rage to spare" }, { "Bloodrage", "for rage" },
			{ "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Wall", "if it goes badly" }, { "Heroic", "lots of rage" } },
		cleave = { { "Charge", "to open" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Strike", "when it's ready" }, { "Cleave", "rage to spare" },
			{ "Clap", "on 3+ enemies" }, { "Counter", "when it's lit" }, { "Victory", "when it's lit" } } },
	{ from = 50, build = "arms", tip = "Fights are short now. Open with Charge, Mortal Strike on cooldown, and Retaliation if you pull too many.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Execute", "under 20% health" },
			{ "Victory", "when it's lit" }, { "Slam", "rage to spare" }, { "Rend", "on long fights" }, { "Bloodrage", "for rage" },
			{ "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Berserker Rage", "if you're feared" }, { "Heroic", "lots of rage" } },
		cleave = { { "Charge", "to open" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Strike", "when it's ready" }, { "Cleave", "rage to spare" },
			{ "Clap", "on 3+ enemies" }, { "Wall", "on 3+ enemies" }, { "Victory", "when it's lit" } } },

	-- Arms PvP: the same blows, with every runner slowed.
	{ from = 20, build = "armspvp", tip = "Charge, Hamstring and keep hitting. Overpower when they dodge, Execute when they're nearly down.",
		single = { { "Charge", "to open" }, { "Slow", "keep it up" }, { "Rend", "keep it up" }, { "Counter", "when it's lit" },
			{ "Strike", "when it's ready" }, { "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Heroic", "lots of rage" },
			{ "Bloodrage", "for rage" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Rend", "on each enemy" }, { "Demoralizing", "on 3+ enemies" },
			{ "Cleave", "rage to spare" }, { "Counter", "when it's lit" }, { "Victory", "when it's lit" } } },
	{ from = 30, build = "armspvp", tip = "Intercept catches anyone who got away, and Berserker Rage breaks a fear.",
		single = { { "Charge", "to open" }, { "Slow", "keep it up" }, { "Counter", "when it's lit" }, { "Execute", "under 20% health" },
			{ "Rend", "keep it up" }, { "Victory", "when it's lit" }, { "Strike", "when it's ready" }, { "Berserker Rage", "if you're feared" },
			{ "Wall", "if it goes badly" }, { "Bloodrage", "for rage" } },
		cleave = { { "Charge", "to open" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Clap", "on 2+ enemies" }, { "Cleave", "rage to spare" },
			{ "Strike", "when it's ready" }, { "Counter", "when it's lit" }, { "Slow", "on the runner" }, { "Intimidating", "on 3+ enemies" } } },
	{ from = 40, build = "armspvp", tip = "Mortal Strike cuts their healing. Keep it on whoever heals, and Hamstring anyone who runs.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Slow", "keep it up" }, { "Counter", "when it's lit" },
			{ "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Slam", "rage to spare" }, { "Stop", "to stop a cast" },
			{ "Rend", "keep it up" }, { "Berserker Rage", "if you're feared" }, { "Wall", "if it goes badly" }, { "Heroic", "lots of rage" } },
		cleave = { { "Charge", "to open" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Strike", "when it's ready" }, { "Cleave", "rage to spare" },
			{ "Clap", "on 3+ enemies" }, { "Slow", "on the runner" }, { "Intimidating", "on 3+ enemies" } } },
	{ from = 50, build = "armspvp", tip = "Save Intimidating Shout for when a healer is about to save them. Piercing Howl, once you have it, slows them all.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Slow", "keep it up" }, { "Counter", "when it's lit" },
			{ "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Slam", "rage to spare" }, { "Stop", "to stop a cast" },
			{ "Rend", "keep it up" }, { "Berserker Rage", "if you're feared" }, { "Wall", "if it goes badly" }, { "Bloodrage", "for rage" } },
		cleave = { { "Charge", "to open" }, { "Piercing Howl", "on 2+ enemies" }, { "Sweeping Strikes", "on 2+ enemies" }, { "Strike", "when it's ready" },
			{ "Cleave", "rage to spare" }, { "Intimidating", "on 3+ enemies" }, { "Wall", "if it goes badly" } } },

	-- Fury: two weapons, fast swings, a lot of rage.
	{ from = 20, build = "fury", tip = "Two weapons from 20. Rend and Overpower early, Heroic Strike with every bit of spare rage.",
		single = { { "Charge", "to open" }, { "Bloodrage", "after Charge" }, { "Counter", "when it's lit" }, { "Execute", "under 20% health" },
			{ "Victory", "when it's lit" }, { "Rend", "keep it up" }, { "Strike", "rage to spare" }, { "Slow", "when it runs" },
			{ "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Clap", "on 2+ enemies" }, { "Demoralizing", "on 3+ enemies" }, { "Cleave", "rage to spare" },
			{ "Counter", "when it's lit" }, { "Victory", "when it's lit" } } },
	-- (Overpower and Rend need Battle Stance: in Berserker, Whirlwind takes Overpower's key from 36.)
	{ from = 30, build = "fury", tip = "Move to Berserker Stance. Intercept in, Death Wish on hard fights, Berserker Rage for more rage.",
		single = { { "Charge", "to open" }, { "Rend", "after Charge" }, { "Death Wish", "on hard fights" }, { "Berserker Rage", "for more rage" },
			{ "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Strike", "rage to spare" }, { "Bloodrage", "for rage" },
			{ "Slow", "when it runs" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Cleave", "rage to spare" }, { "Demoralizing", "on 3+ enemies" },
			{ "Death Wish", "on hard fights" }, { "Berserker Rage", "for more rage" }, { "Victory", "when it's lit" } } },
	{ from = 36, build = "fury", tip = "Whirlwind is yours now. Press it whenever it's ready, on one enemy or a whole pack.",
		single = { { "Charge", "to open" }, { "Counter", "when it's ready" }, { "Death Wish", "on hard fights" }, { "Berserker Rage", "for more rage" },
			{ "Execute", "under 20% health" }, { "Victory", "when it's lit" }, { "Strike", "rage to spare" }, { "Bloodrage", "for rage" },
			{ "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Rend", "after Charge" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Counter", "when it's ready" }, { "Cleave", "rage to spare" }, { "Demoralizing", "on 3+ enemies" },
			{ "Death Wish", "on hard fights" }, { "Berserker Rage", "for more rage" }, { "Victory", "when it's lit" } } },
	{ from = 40, build = "fury", tip = "Bloodthirst and Whirlwind whenever they're ready, and Heroic Strike soaks up the rest of your rage.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's ready" }, { "Execute", "under 20% health" },
			{ "Victory", "when it's lit" }, { "Berserker Rage", "for more rage" }, { "Heroic", "rage to spare" }, { "Death Wish", "on hard fights" },
			{ "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Bloodrage", "for rage" }, { "Wall", "if it goes badly" } },
		cleave = { { "Charge", "to open" }, { "Counter", "when it's ready" }, { "Strike", "when it's ready" }, { "Cleave", "rage to spare" },
			{ "Demoralizing", "on 3+ enemies" }, { "Berserker Rage", "for more rage" }, { "Death Wish", "on hard fights" } } },
	{ from = 50, build = "fury", tip = "Recklessness and Death Wish together end a hard fight fast. Piercing Howl keeps a pack from running.",
		single = { { "Charge", "to open" }, { "Strike", "when it's ready" }, { "Counter", "when it's ready" }, { "Execute", "under 20% health" },
			{ "Victory", "when it's lit" }, { "Berserker Rage", "for more rage" }, { "Heroic", "rage to spare" }, { "Death Wish", "on hard fights" },
			{ "Wall", "on hard fights" }, { "Stop", "to stop a cast" }, { "Slow", "when it runs" }, { "Bloodrage", "for rage" } },
		cleave = { { "Charge", "to open" }, { "Counter", "when it's ready" }, { "Strike", "when it's ready" }, { "Cleave", "rage to spare" },
			{ "Piercing Howl", "if they run" }, { "Demoralizing", "on 3+ enemies" }, { "Death Wish", "on hard fights" }, { "Wall", "on hard fights" } } },
}
K.PLAY = PLAY

local OPTS = {
	forms = 3,                               -- Battle, Defensive, Berserker: the main bar has a page for each
	knows = ns.stances[ns.forms.battle],
	shifts = { [2457] = true, [71] = true, [2458] = true },   -- a stance a key only passes through is not what the key is for
	stances = "Battle, Defensive and Berserker Stance",
	-- The stance to fight in: Defensive behind a shield, Berserker for Fury from 30, Battle for the rest.
	keep = { plain = BATTLE_STANCE, arms = BATTLE_STANCE, armspvp = BATTLE_STANCE, protsolo = DEFENSIVE_STANCE,
		prot = DEFENSIVE_STANCE, fury = BERSERKER_STANCE },
	keeps = "stance",
	build = function() return Shy.Keys.Build() end,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isWarrior or not Shy.Keys then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run(typed)
	if not ns.isWarrior then
		T:Print("your keys are laid out on a warrior only.")
		return
	end
	if not Shy.Keys then
		T:Print("restart the game once: your keys need a file it only loads then.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS, nil, typed)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA key whose ability needs another stance takes you there first: press it again."
end

-- From login on, the bags' keys follow the bags.
function ns.SetupKeys()
	if Shy.Keys then Shy.Keys.Watch(T, JOBS, OPTS) end
end
