-- A paladin's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the spell by what you
-- have learned, so a spell arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy paladin keys)
--   ns.Keys.Run("force")  every key, even ones you kept or moved (/shy paladin keys force)
--   ns.Keys.List()    every key and what it does, as text
--
-- A heal or a blessing goes to the friend the mouse is on, else the friend you have targeted, else you.
-- Each job names its key for WASD (key) and for ASDF (asdf): with ASDF what WASD has on F is on G, and what
-- it has on G is on W.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}

-- Your auras, each a list for the keys' data: the aura to keep on (OPTS.keep) is the first of a list you have.
-- 1 2 3 hold them in the order the game's bar does.
local RET_AURA = { 7294, 465 }   -- Retribution Aura, Devotion Aura
local DEVOTION_AURA = { 465 }   -- Devotion Aura
local HOLY_AURA = { 19746, 465 }   -- Concentration Aura, Devotion Aura
local RETRIBUTION_AURA = { 7294 }   -- Retribution Aura
local CONCENTRATION_AURA = { 19746 }   -- Concentration Aura
ns.Keys = K

local SHOW, ATTACK = "#showtooltip", "/startattack"
local FRIEND, Grows = Shy.Keys.FRIEND, Shy.Keys.Grows

-- Retribution and Holy: what a shield's key does for them instead.
local REPENT = { name = "Repentance", what = "Repentance", SHOW, "/cast {20066}" }
-- Protection and Holy: Holy Light on V, where the others judge Seal of Justice. Theirs is behind Shift + E.
local HOLY_LIGHT = { name = "Holy Light", what = "Holy Light", SHOW, "/cast " .. FRIEND .. " {635}" }
local SWIFT = { name = "Swift Judgement", what = "Swift Judgement, on the enemy under your mouse, or your target",
	SHOW, ATTACK, "/cast [@mouseover,harm,nodead][] {1310994}" }
-- Holy and Retribution against players: Divine Favor on Shift + Mouse 4, the same key in both.
local FAVOR = { name = "Favor", what = "Divine Favor", SHOW, "/cast {20216}" }
-- Holy: a ward for the tank before a big pull, cast standing still, where the others' Seal of the Crusader is.
local VIGIL = { name = "Vigil", what = "Light's Vigil, on the friend under your mouse, or your target, or you",
	SHOW, "/cast " .. FRIEND .. " {1310911}" }
-- The seal: Seal of Righteousness, then Seal of Command for Retribution. Not Seal of Fury: judging it taunts, and
-- would pull the enemy off your tank. Protection keeps Seal of Fury for that taunt and its shield.
local SEAL = { name = "Seal", what = "Your seal: Seal of Righteousness. Seal of Command if you have it",
	SHOW, "/cast [known:{20375}] {20375}; {21084}" }
local FURY = { name = "Seal", what = "Your seal: Seal of Fury, its Judgement taunts. Seal of Righteousness until 10",
	SHOW, "/cast [known:{1311649}] {1311649}; {21084}" }
-- Holy heals first: the quick heal on Q, where the seal is for the others. Holy Shock is beside the stop, where
-- the others' heal is: never on a mouse button, which nudges the pointer off the frame you aimed at. The seal,
-- cast on yourself, is on the thumb. With ASDF the stop has G: Holy Shock is on T there, and Consecration on W.
local HEAL = { name = "Heal", role = "heal", what = "Flash of Light. Holy Light until 20",
	SHOW, Grows(19750, 635) }
local SHOCK = { name = "Holy Shock", asdf = "T", what = "Holy Shock, on the friend under your mouse, or your enemy",
	SHOW, "/cast [@mouseover,help,nodead][] {1311606}" }
local CONSECRATE = { name = "Consecration", asdf = "W", what = "Consecration", SHOW, "/cast {26573}" }
-- Holy's Oath lasts an hour: sworn on your tank once, beside your other upkeep.
local OATH = { name = "Oath", what = "Oath of Light, on the friend under your mouse or your target",
	"#showtooltip {1328548}", "/cast [@mouseover,help,nodead][help,nodead] {1328548}" }
-- Protection from 40: Hammer of the Righteous on X, where the others judge Seal of the Crusader. It hits four
-- and shares Holy Strike's cooldown: the strike for a pack.
local HAMMER = { name = "Righteous Hammer", what = "Hammer of the Righteous", SHOW, ATTACK, "/cast {407632}" }

-- A key is named for the one ability it casts; one that casts several as you level has a word true of them all
-- (Blessing, Heal, Cure), and what every class has is called the same on each (Stop, Wall, Raise, Strike).
local JOBS = {
	-- The fight, under the fingers that are free while you move.
	{ name = "Seal", key = "Q", asdf = "Q", what = "Your seal: Seal of Righteousness. Seal of Command if you have it",
		SHOW, "/cast [known:{20375}] {20375}; {21084}", by = { prot = FURY, holy = HEAL } },
	{ name = "Judgement", key = "E", asdf = "E", what = "Judgement",
		SHOW, ATTACK, "/cast {20271}" },
	{ name = "Strike", role = "strike", key = "R", asdf = "R", what = "Holy Strike",
		SHOW, ATTACK, "/cast {679}" },
	{ name = "Consecration", key = "T", asdf = "T", what = "Consecration",
		SHOW, "/cast {26573}", by = { holy = CONSECRATE } },
	{ name = "Heal", role = "heal", key = "G", asdf = "W", early = "F", asdfEarly = "G", what = "Flash of Light. Holy Light until 20",
		SHOW, Grows(19750, 635), by = { holy = SHOCK } },
	{ name = "Exorcism", key = "Z", asdf = "Z", what = "Exorcism",
		SHOW, "/cast {879}" },
	-- Seal of Justice, judged on a runner so it can't get away (and its hits can stun a player). A tank stays in Seal
	-- of Fury, so Protection and Holy have Holy Light here.
	{ name = "Justice", key = "V", asdf = "V", what = "Seal of Justice: judge it so a runner can't get away",
		SHOW, "/cast {20164}", by = { prot = HOLY_LIGHT, holy = HOLY_LIGHT } },
	-- Seal of the Crusader judged first on a long fight: the enemy takes more Holy damage while your strikes land.
	-- A tank stays in Seal of Fury and has Hammer of the Righteous here, a healer Light's Vigil.
	{ name = "Crusader", key = "X", asdf = "X", what = "Seal of the Crusader",
		SHOW, "/cast {21082}", by = { prot = HAMMER, holy = VIGIL } },
	{ name = "Cure", role = "cure", key = "C", asdf = "C", what = "Cleanse. Purify until 42",
		SHOW, Grows(4987, 1152) },
	{ name = "Blessing", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Blessing of Kings. Blessing of Might until 20",
		SHOW, Grows(20217, 19740) },
	-- Righteous Fury is threat alone: a tank's, never a damage dealer's. A healer's upkeep here is the Oath.
	{ name = "Righteous Fury", key = "SHIFT-5", asdf = "SHIFT-5", stay = true, what = "Righteous Fury",
		SHOW, "/cast {25780}", by = { ret = false, retpvp = false, holy = OATH } },
	-- The thumb: what you answer with, cast on yourself or your target. The stop is on F (G with ASDF), beside the
	-- index finger: Mouse 5 is too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Holy Shield", key = "BUTTON4", asdf = "BUTTON4", what = "Holy Shield",
		SHOW, "/cast {20925}", by = { ret = REPENT, retpvp = REPENT, holy = SEAL } },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Hammer of Justice",
		SHOW, "/cast {853}" },
	-- The rest, in the order you learn them, each on its own key: only the thumb is lent while it waits.
	-- Shift + Mouse 4 is on the thumb itself until the thumb's own spell comes (Holy Shield or Repentance), and
	-- before the wall: Templar's Bulwark is a tank's answer to a hard hit, Divine Protection isn't.
	{ name = "Bulwark", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", early = "BUTTON4", asdfEarly = "BUTTON4", stay = true, what = "Templar's Bulwark",
		SHOW, "/cast {1311015}",
		by = { ret = false, retpvp = FAVOR, holy = FAVOR } },
	-- The wall is on the thumb while the thumb has nothing of its own, then on 4 for good: it never stands in elsewhere.
	{ name = "Wall", role = "wall", key = "4", asdf = "4", early = "BUTTON4", asdfEarly = "BUTTON4", stay = true, spare = "MULTIACTIONBAR4BUTTON4",
		what = "Divine Shield. Divine Protection until 34", SHOW, "/cast [known:{642}] {642}; {498}" },
	-- Behind Shift and never standing in on an easy key: a slip on it drains all your mana.
	{ name = "Hands", key = "SHIFT-G", asdf = "SHIFT-W", stay = true, what = "Lay on Hands",
		SHOW, "/cast " .. FRIEND .. " {633}" },
	-- Off Shift + D and Shift + A, and never standing in on an easy key: on yourself by accident it stops your
	-- attacks and keeps Divine Shield back.
	{ name = "Protection", key = "SHIFT-T", asdf = "SHIFT-T", stay = true, what = "Blessing of Protection",
		SHOW, "/cast " .. FRIEND .. " {1022}" },
	-- A raise and the blessings are pressed out of a fight, never in a hurry: none of them stands in on an easy key.
	{ name = "Raise", role = "raise", key = "5", asdf = "5", stay = true, spare = "MULTIACTIONBAR4BUTTON5", what = "Redemption, on the dead friend under your mouse or your target, or the one you click next",
		"#showtooltip {7328}", "/cast " .. Shy.Keys.DEAD .. " {7328}" },
	-- On Shift + D, the side step's key: a blessing does no harm when it is pressed by accident.
	{ name = "Wisdom", key = "SHIFT-D", asdf = "SHIFT-D", stay = true, what = "Blessing of Wisdom",
		SHOW, "/cast " .. FRIEND .. " {19742}" },
	{ name = "Freedom", key = "SHIFT-F", asdf = "SHIFT-G", stay = true, what = "Blessing of Freedom",
		SHOW, "/cast " .. FRIEND .. " {1044}" },
	-- On Shift + A, the other side step's key: a blessing again.
	{ name = "Might", key = "SHIFT-A", asdf = "SHIFT-A", stay = true, what = "Blessing of Might",
		SHOW, "/cast " .. FRIEND .. " {19740}" },
	-- With Shift, each key's rarer kin, kept there from the day it comes (no hop onto a key that waits).
	-- Holy Light, the big heal, for a build whose V judges Seal of Justice: cast standing, out of the worst of it.
	-- (until 20 the heal on G is Holy Light, so this waits for Flash of Light to take G)
	-- A tank's is a second Judgement on a cooldown of its own: in Seal of Fury, the taunt for the enemy the mouse is on.
	{ name = "Holy Light", key = "SHIFT-E", asdf = "SHIFT-E", stay = true, what = "Holy Light",
		SHOW, "/cast " .. FRIEND .. " {635}", by = { prot = SWIFT, holy = false } },
	-- For when your mana runs low, a tank's too: judging it doesn't taunt. With Unsealed Wrath, the seal to swap to.
	{ name = "Wisdom Seal", key = "SHIFT-Q", asdf = "SHIFT-Q", stay = true, what = "Seal of Wisdom",
		SHOW, "/cast {20166}" },
	{ name = "Hammer of Wrath", key = "SHIFT-R", asdf = "SHIFT-R", stay = true, what = "Hammer of Wrath",
		SHOW, ATTACK, "/cast {24275}" },
	{ name = "Holy Wrath", key = "B", asdf = "B", what = "Holy Wrath",
		SHOW, "/cast {2812}" },
}
-- Shift + 1 and 2: what your people alone can do. With Shift on the bottom row: what your bags hold, the best of
-- it you can use.
Shy.Keys.People(JOBS)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })
-- What you press now and then, each on the first free key of Shift + 6 to =: what saves a friend before what you
-- seldom need. A tank stays in Seal of Fury.
Shy.Keys.Utility(JOBS, {
	{ name = "Turn Undead", spells = { 10326, 5627, 2878 } },
	{ name = "Sacrifice", what = "Blessing of Sacrifice", spells = { 20729, 6940 } },
	{ name = "Intervention", what = "Divine Intervention", spells = { 19752 } },
	{ name = "Seal of Light", spells = { 20349, 20348, 20347, 20165 }, by = { prot = false } },
	{ name = "Sense Undead", spells = { 5502 } },
})
-- 1 2 3: your auras, each the spell itself on the left flyout. They follow the game's own bar of them, the same
-- in every build: 1 lights its first icon, whatever aura your build keeps on.
do
	local devotion = { name = "Devotion", what = "Devotion Aura", unpack(DEVOTION_AURA) }
	local retribution = { name = "Retribution", what = "Retribution Aura", unpack(RETRIBUTION_AURA) }
	local concentration = { name = "Concentration", what = "Concentration Aura", unpack(CONCENTRATION_AURA) }
	Shy.Keys.Stays(JOBS, { plain = { devotion, retribution, concentration } })
end
K.JOBS = JOBS

-- How to play, by level and build: the plain brackets are a Retribution paladin's (and anyone's without a build);
-- Protection and Holy have their own from where their talents change how a fight goes.
local PLAY = {
	{ from = 1, tip = "Put your seal on before you pull, judge it onto the enemy, then hit it as your strikes come back.",
		single = { { "Seal", "before you pull" }, { "Judgement" }, { "Strike" }, { "Heal", "under half health" } },
		cleave = { { "Seal", "before you pull" }, { "Strike" }, { "Judgement" }, { "Heal", "under half health" } } },
	{ from = 10, tip = "Fights are slow and you rest often. Stun a caster or a runner, and eat between pulls.",
		single = { { "Seal", "keep it up" }, { "Judgement" }, { "Strike" }, { "Stop", "to stop a cast or a runner" },
			{ "Heal", "under half health" }, { "Hands", "about to die" } },
		cleave = { { "Seal", "keep it up" }, { "Strike" }, { "Judgement" }, { "Stop", "on the hardest hitter" },
			{ "Heal", "under half health" }, { "Hands", "about to die" } } },
	{ from = 20, tip = "Open with Exorcism on undead and demons, and keep Consecration for packs. It eats your mana.",
		single = { { "Crusader", "on an elite: judge it first" }, { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Justice", "on a runner" }, { "Heal", "under half health" }, { "Hands", "about to die" } },
		cleave = { { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" }, { "Strike" }, { "Judgement" },
			{ "Stop", "on the hardest hitter" }, { "Heal", "under half health" }, { "Hands", "about to die" } } },
	{ from = 30, tip = "You kill quickly now. With two on you, Repentance takes one out while you finish the other.",
		single = { { "Crusader", "on an elite: judge it first" }, { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Justice", "on a runner" }, { "Heal", "under half health" }, { "Hands", "about to die" } },
		cleave = { { "Repentance", "on the second one" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" },
			{ "Strike" }, { "Judgement" }, { "Stop", "on the hardest hitter" }, { "Heal", "under half health" }, { "Hands", "about to die" } } },
	{ from = 40, tip = "With Unsealed Wrath, swing three times in Command, then once in Wisdom. It pays you mana too.",
		single = { { "Crusader", "on an elite: judge it first" }, { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Hammer of Wrath", "under 20% health" }, { "Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Justice", "on a runner" },
			{ "Heal", "under half health" }, { "Wisdom Seal", "one swing in four" } },
		cleave = { { "Repentance", "on the second one" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" },
			{ "Strike" }, { "Judgement" }, { "Hammer of Wrath", "under 20% health" }, { "Wall", "when it goes wrong" }, { "Hands", "about to die" } } },
	{ from = 50, tip = "Undead and demons fall in packs to Holy Wrath. Everything else goes down one at a time.",
		single = { { "Crusader", "on an elite: judge it first" }, { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Hammer of Wrath", "under 20% health" }, { "Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Justice", "on a runner" },
			{ "Heal", "under half health" }, { "Wisdom Seal", "one swing in four" } },
		cleave = { { "Holy Wrath", "on undead or demons" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" },
			{ "Strike" }, { "Judgement" }, { "Hammer of Wrath", "under 20% health" }, { "Wall", "when it goes wrong" }, { "Hands", "about to die" } } },

	-- Protection: Righteous Fury on and Seal of Fury up (judging it, Judgement and Swift Judgement, taunts),
	-- Consecration from 20 to pull packs, Holy Shield from 30, Hammer of the Righteous for a pack from 40.
	{ from = 10, build = "prot", tip = "Keep Righteous Fury on. Judging Seal of Fury taunts, so judge whatever turns away from you.",
		single = { { "Righteous Fury", "keep it up" }, { "Seal", "keep it up" }, { "Judgement" }, { "Strike" },
			{ "Stop", "to stop a cast" }, { "Heal", "under half health" }, { "Hands", "about to die" } },
		cleave = { { "Righteous Fury", "keep it up" }, { "Seal", "keep it up" }, { "Judgement", "on one that leaves you" }, { "Strike" },
			{ "Stop", "on the hardest hitter" }, { "Heal", "under half health" }, { "Hands", "about to die" } } },
	{ from = 20, build = "prot", tip = "Consecration lets you pull a pack. Drop it first so they all come to you.",
		single = { { "Righteous Fury", "keep it up" }, { "Seal", "keep it up" }, { "Exorcism", "on undead or demons" }, { "Judgement" },
			{ "Swift Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Bulwark", "when you're hit hard" }, { "Heal", "under half health" } },
		cleave = { { "Righteous Fury", "keep it up" }, { "Consecration", "first, under the pack" }, { "Seal", "keep it up" }, { "Judgement" },
			{ "Swift Judgement", "on one that leaves you" }, { "Strike" }, { "Bulwark", "when you're hit hard" }, { "Heal", "under half health" } } },
	{ from = 30, build = "prot", tip = "Keep Holy Shield up while they hit you. Every block hits back and holds them on you.",
		single = { { "Holy Shield", "keep it up" }, { "Seal", "keep it up" }, { "Exorcism", "on undead or demons" }, { "Judgement" },
			{ "Swift Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Bulwark", "when you're hit hard" }, { "Heal", "under half health" } },
		cleave = { { "Righteous Fury", "keep it up" }, { "Consecration", "first, under the pack" }, { "Holy Shield", "keep it up" }, { "Seal", "keep it up" },
			{ "Judgement" }, { "Swift Judgement", "on one that leaves you" }, { "Strike" }, { "Bulwark", "when you're hit hard" } } },
	{ from = 40, build = "prot", tip = "Pull two packs if your mana holds. Divine Shield gets you out when a pull goes wrong.",
		single = { { "Holy Shield", "keep it up" }, { "Seal", "keep it up" }, { "Exorcism", "on undead or demons" }, { "Judgement" },
			{ "Swift Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Bulwark", "when you're hit hard" }, { "Heal", "under half health" },
			{ "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Righteous Fury", "keep it up" }, { "Consecration", "first, under the pack" }, { "Righteous Hammer", "on 3+, for Holy Strike" },
			{ "Holy Shield", "keep it up" }, { "Seal", "keep it up" },
			{ "Judgement" }, { "Swift Judgement", "on one that leaves you" }, { "Strike" }, { "Bulwark", "when you're hit hard" },
			{ "Wall", "when it goes wrong" } } },
	{ from = 50, build = "prot", tip = "Packs of undead and demons are yours. Consecration, Holy Wrath, and Holy Shield up.",
		single = { { "Holy Shield", "keep it up" }, { "Seal", "keep it up" }, { "Exorcism", "on undead or demons" },
			{ "Hammer of Wrath", "under 20% health" }, { "Judgement" }, { "Swift Judgement" }, { "Strike" }, { "Stop", "to stop a cast" },
			{ "Bulwark", "when you're hit hard" }, { "Heal", "under half health" }, { "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Righteous Fury", "keep it up" }, { "Consecration", "first, under the pack" }, { "Righteous Hammer", "on 3+, for Holy Strike" },
			{ "Holy Wrath", "on undead or demons" },
			{ "Holy Shield", "keep it up" }, { "Seal", "keep it up" }, { "Judgement" }, { "Swift Judgement", "on one that leaves you" },
			{ "Strike" }, { "Bulwark", "when you're hit hard" }, { "Wall", "when it goes wrong" } } },

	-- Retribution against players: Repentance takes one out, Seal of Justice stuns, Divine Favor makes a heal land big.
	{ from = 30, build = "retpvp", tip = "Against players, Repentance takes one out of the fight, and Seal of Justice's hits can stun them.",
		single = { { "Crusader", "on an elite: judge it first" }, { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Judgement" }, { "Strike" }, { "Justice", "for stuns on a player" }, { "Stop", "to stop a heal" }, { "Heal", "under half health" },
			{ "Hands", "about to die" } },
		cleave = { { "Repentance", "on the second one" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" },
			{ "Strike" }, { "Judgement" }, { "Stop", "on the hardest hitter" }, { "Heal", "under half health" }, { "Hands", "about to die" } } },
	{ from = 40, build = "retpvp", tip = "Swap to Seal of Wisdom when your mana runs low, and when a fight goes wrong Divine Shield gets you out.",
		single = { { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" }, { "Hammer of Wrath", "under 20% health" },
			{ "Judgement" }, { "Strike" }, { "Justice", "for stuns on a player" }, { "Stop", "to stop a heal" }, { "Heal", "under half health" },
			{ "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Repentance", "on the second one" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" },
			{ "Strike" }, { "Judgement" }, { "Hammer of Wrath", "under 20% health" }, { "Wall", "when it goes wrong" }, { "Hands", "about to die" } } },
	{ from = 50, build = "retpvp", tip = "Undead and demons fall in packs to Holy Wrath. Against a player, Seal of Justice stuns.",
		single = { { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" }, { "Hammer of Wrath", "under 20% health" },
			{ "Judgement" }, { "Strike" }, { "Justice", "for stuns on a player" }, { "Stop", "to stop a heal" }, { "Heal", "under half health" },
			{ "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Repentance", "on the second one" }, { "Holy Wrath", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Consecration", "on 3+ enemies" }, { "Strike" }, { "Judgement" }, { "Hammer of Wrath", "under 20% health" },
			{ "Wall", "when it goes wrong" }, { "Hands", "about to die" } } },
	{ from = 55, build = "retpvp", tip = "Divine Favor before a heal makes it land big. Save it for when they have you low.",
		single = { { "Exorcism", "on undead or demons" }, { "Seal", "keep it up" }, { "Hammer of Wrath", "under 20% health" },
			{ "Judgement" }, { "Strike" }, { "Justice", "for stuns on a player" }, { "Stop", "to stop a heal" },
			{ "Favor", "before a heal" }, { "Heal", "under half health" }, { "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Repentance", "on the second one" }, { "Holy Wrath", "on undead or demons" }, { "Seal", "keep it up" },
			{ "Consecration", "on 3+ enemies" }, { "Strike" }, { "Judgement" }, { "Hammer of Wrath", "under 20% health" },
			{ "Wall", "when it goes wrong" }, { "Favor", "before a heal" }, { "Hands", "about to die" } } },

	-- Holy: slow alone, so fights lean on your own heals; in a group, your Oath on the tank.
	{ from = 20, build = "holy", tip = "You kill slowly alone, so pull one at a time. In a group, swear your Oath on the tank.",
		single = { { "Seal", "keep it up" }, { "Exorcism", "on undead or demons" }, { "Judgement" }, { "Strike" },
			{ "Stop", "to stop a cast" }, { "Heal", "under half health" }, { "Favor", "for a big heal" }, { "Hands", "about to die" } },
		cleave = { { "Oath", "on your tank, once" }, { "Seal", "keep it up" }, { "Consecration", "on 3+ enemies" }, { "Strike" },
			{ "Judgement" }, { "Heal", "under half health" }, { "Holy Light", "when you can stand still" } } },
	{ from = 30, build = "holy", tip = "Holy Shock hits or heals at once. Hit with it alone, save it for a sudden drop in a group.",
		single = { { "Seal", "keep it up" }, { "Holy Shock", "on the enemy, or on you" }, { "Exorcism", "on undead or demons" }, { "Judgement" },
			{ "Strike" }, { "Stop", "to stop a cast" }, { "Heal", "under half health" }, { "Favor", "for a big heal" } },
		cleave = { { "Oath", "on your tank, once" }, { "Holy Shock", "on whoever drops fast" }, { "Heal", "on small hits" },
			{ "Holy Light", "on big hits" }, { "Cure", "on a poison or disease" }, { "Hands", "on one about to die" }, { "Consecration", "on 3+ enemies" } } },
	{ from = 40, build = "holy", tip = "Light's Vigil on the tank before a big pull turns your next Holy Shock into a group heal.",
		single = { { "Seal", "keep it up" }, { "Holy Shock", "on the enemy, or on you" }, { "Exorcism", "on undead or demons" }, { "Judgement" },
			{ "Strike" }, { "Stop", "to stop a cast" }, { "Heal", "under half health" }, { "Favor", "for a big heal" },
			{ "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Vigil", "before a big pull" }, { "Oath", "on your tank, once" }, { "Holy Shock", "on whoever drops fast" },
			{ "Heal", "on small hits" }, { "Holy Light", "on big hits" }, { "Cure", "on a poison or disease" }, { "Hands", "on one about to die" },
			{ "Wall", "when they turn on you" } } },
	{ from = 50, build = "holy", tip = "Keep your mana for the group's heals. Holy Wrath stuns a pack of undead or demons that comes for you.",
		single = { { "Seal", "keep it up" }, { "Holy Shock", "on the enemy, or on you" }, { "Exorcism", "on undead or demons" },
			{ "Hammer of Wrath", "under 20% health" }, { "Judgement" }, { "Strike" }, { "Stop", "to stop a cast" }, { "Heal", "under half health" },
			{ "Favor", "for a big heal" }, { "Wisdom Seal", "when your mana runs low" } },
		cleave = { { "Vigil", "before a big pull" }, { "Oath", "on your tank, once" }, { "Holy Shock", "on whoever drops fast" },
			{ "Heal", "on small hits" }, { "Holy Light", "on big hits" }, { "Cure", "on a poison or disease" },
			{ "Holy Wrath", "on undead or demons" }, { "Hands", "on one about to die" }, { "Wall", "when they turn on you" } } },
}
K.PLAY = PLAY

local OPTS = {
	knows = 21084,                           -- Seal of Righteousness: a paladin's from level 1
	stances = "Devotion, Retribution and Concentration Aura",
	-- The aura to keep on: Retribution alone, Devotion as a tank, Concentration as a healer.
	keep = { plain = RET_AURA, ret = RET_AURA, retpvp = RET_AURA, prot = DEVOTION_AURA, holy = HOLY_AURA },
	keeps = "aura",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isPaladin or not Shy.Keys then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run(typed)
	if not ns.isPaladin then
		T:Print("your keys are laid out on a paladin only.")
		return
	end
	if not Shy.Keys then
		T:Print("restart the game once: your keys need a file it only loads then.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS, nil, typed)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA heal or a blessing goes to the friend under your mouse, or your target, or you."
end

-- From login on, the bags' keys follow the bags.
function ns.SetupKeys()
	if Shy.Keys then Shy.Keys.Watch(T, JOBS, OPTS) end
end
