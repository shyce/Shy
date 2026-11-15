-- A warlock's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the spell by what you
-- have learned, so a spell arrives on its key as you train it. Every job names its key for WASD (key) and for
-- ASDF (asdf: S forward, F back, the hand a key further right), and the guide to playing names its jobs.
--
--   ns.Keys.Run()     lays them out and says what was done (/shywarlock keys)
--   ns.Keys.List()    every key and what it does, as text
--
-- A stone's key uses the stone you carry and makes one when you carry none.

local ADDON, ns = ...
local T = ns.T

local K = {}
ns.Keys = K

local SHOW = "#showtooltip"

-- Each build's own talent where Destruction's Shadowburn is.
local SHADOWBURN = { name = "Shadowburn", what = "Shadowburn", SHOW, "/cast {17877}" }
local WRACK = { name = "Wrack", what = "Wrack", SHOW, "/cast {1316697}" }
local LINK = { name = "Soul Link", what = "Soul Link, kept on while your demon is out", SHOW, "/cast {19028}" }
-- Only Destruction learns Incinerate: the other builds have Shadow Bolt on R for good, and Destruction keeps it
-- beside, for the Shadow damage its Conflagrate raises.
local SHADOW_BOLT = { name = "Bolt", role = "bolt", what = "Shadow Bolt", SHOW, "/cast {686}" }
local SHADOW = { name = "Shadow Bolt", what = "Shadow Bolt, once Incinerate has R", SHOW, "/cast {686}" }
-- E is each build's second spell: Destruction's Immolate, Affliction's Siphon Life, Demonology's Searing Pain (its
-- Demonic Brand). Where E's own comes later, Immolate stands on E until then and goes home to Shift + Q.
local SIPHON = { name = "Siphon Life", what = "Siphon Life", SHOW, "/cast {18265}" }
local SEARING = { name = "Searing Pain", what = "Searing Pain", SHOW, "/cast {5676}" }
local IMMOLATE = { name = "Immolate", what = "Immolate", SHOW, "/cast {348}" }
-- Curses go on beside a bane: Weakness takes the sting out of a hard hitter; Destruction only kills, so the
-- Elements; the PvP build slows with Exhaustion. (Recklessness would make the mob ignore your Fear.)
local ELEMENTS = { name = "Curse", what = "Curse of the Elements; Curse of Weakness until 20",
	SHOW, "/cast [known:{440892}] {440892}; {702}" }
-- Its Amplify Curse goes on first whenever it's ready (it takes no global cooldown), so the curse you put on is the
-- stronger one with no key of its own to think of.
local EXHAUSTION = { name = "Curse", what = "Curse of Exhaustion, made stronger by Amplify Curse when it's ready; Curse of Weakness until you have it",
	"#showtooltip [known:{18223}] {18223}; {702}", "/cast [known:{18288}] {18288}", "/cast [known:{18223}] {18223}; {702}" }
-- Destruction's cleave: a bane on a second mob takes a share of every hit you land on the first. It has the key
-- beside Rain of Fire's (Shift + T; Shift + Q with ASDF), and Hellfire, seldom pressed, takes Mouse 5.
local HAVOC = { name = "Bane of Havoc", what = "Bane of Havoc, on a second mob", SHOW, "/cast {1225228}" }
local HELLFIRE = { name = "Hellfire", what = "Hellfire", SHOW, "/cast {1949}" }
local SUCCUBUS = { name = "Succubus", what = "Summon Succubus, with Fel Domination when you have it",
	"#showtooltip {712}", "/cast {18708}", "/cast {712}" }

-- The instants you cast on the run (Corruption, Agony, Life Tap) sit under the fingers that stay free while
-- you hold forward, in both ways of moving: Q, C and V. What you cast standing still takes the rest; W and X, in
-- ASDF, are over the finger that holds forward.
local JOBS = {
	{ name = "Corruption", key = "Q", asdf = "Q", what = "Corruption",
		SHOW, "/cast {172}" },
	{ name = "Immolate", key = "E", asdf = "E", what = "Immolate",
		SHOW, "/cast {348}", by = { aff = SIPHON, demopvp = SIPHON, demo = SEARING } },
	{ name = "Bolt", role = "bolt", key = "R", asdf = "R", what = "Shadow Bolt; Incinerate if you have it",
		SHOW, "/cast [known:{412758}] {412758}; {686}", by = { aff = SHADOW_BOLT, demo = SHADOW_BOLT, demopvp = SHADOW_BOLT } },
	{ name = "Rain", key = "T", asdf = "T", what = "Rain of Fire",
		SHOW, "/cast {5740}" },
	-- Until Death Coil, your Fear is what you press in a hurry: it stands beside the index finger (before the
	-- Wand, so it takes that key at 8). With ASDF its own key is Z, a cast you stand still for.
	{ name = "Fear", key = "G", asdf = "Z", early = "F", asdfEarly = "G", what = "Fear",
		SHOW, "/cast {5782}" },
	-- Pressed every pull, and you stop to shoot: with ASDF it takes W, over the finger that holds forward.
	{ name = "Wand", role = "wand", key = "Z", asdf = "W", early = "F", what = "Shoot your wand, and your demon attacks",
		"#showtooltip {5019}", "/cast !{5019}", "/petattack" },
	-- A channel you stand still for: X is under the finger that holds forward.
	{ name = "Drain Life", key = "X", asdf = "X", what = "Drain Life",
		SHOW, "/cast {689}" },
	-- Tapped on the run between fights, so it takes V, free while you hold forward (C with ASDF, where Agony
	-- takes V: Corruption, Agony and Siphon Life then fall to three fingers, and Agony is the index's either way).
	{ name = "Life Tap", key = "V", asdf = "C", what = "Life Tap",
		SHOW, "/cast {1454}" },
	{ name = "Agony", key = "C", asdf = "V", what = "Bane of Agony",
		SHOW, "/cast {980}" },
	-- Pressed as a mob dies, for a shard, every few fights: a plain key.
	{ name = "Drain Soul", key = "B", asdf = "B", what = "Drain Soul",
		SHOW, "/cast {1120}" },
	{ name = "Voidwalker", key = "2", asdf = "2", stay = true, what = "Summon Voidwalker, with Fel Domination when you have it",
		"#showtooltip {697}", "/cast {18708}", "/cast {697}" },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Healthstone", key = "BUTTON4", asdf = "BUTTON4", what = "Your healthstone; makes one when you have none",
		supply = { "healthstone" }, "/cast {6201}" },
	-- The stop: Death Coil, or your Felhunter's Spell Lock while it is out.
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Death Coil; your Felhunter's Spell Lock while it is out",
		SHOW, "/cast [nopet:Felhunter] {6789}; [known:{6789}] {19244}" },
	-- Your demon kept alive: a channel you stand still for.
	{ name = "Funnel", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", what = "Health Funnel",
		SHOW, "/cast {755}" },
	{ name = "Banish", key = "SHIFT-BUTTON5", asdf = "SHIFT-BUTTON5", what = "Banish",
		SHOW, "/cast {710}" },
	-- Never hurried: your demon given up for a buff that lasts half an hour (Demonology, with Demonic Pact). The PvP
	-- build takes it only on the way to Soul Link, which needs the demon; Destruction has its Hellfire here.
	{ name = "Demonic", key = "BUTTON5", asdf = "BUTTON5", stay = true, what = "Demonic Sacrifice: your demon, for a buff of its kind",
		SHOW, "/cast {18788}", by = { aff = false, destro = HELLFIRE, demopvp = false } },
	-- The number row: what you press standing. 4 the wall, 5 the raise.
	{ name = "Wall", role = "wall", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", what = "Your Voidwalker's Sacrifice shield while it is out; else Shadow Ward",
		SHOW, "/cast [pet:Voidwalker] {7812}; {6229}" },
	{ name = "Soulstone", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", what = "Your soulstone, on a friend or you; makes one when you have none",
		supply = { "soulstone" }, friend = true, "/cast {693}" },
	{ name = "Summon", key = "3", asdf = "3", stay = true, what = "Summon Felhunter, with Fel Domination when you have it; Succubus until 30",
		"#showtooltip [known:{691}] {691}; {712}", "/cast {18708}", "/cast [known:{691}] {691}; {712}", by = { demopvp = SUCCUBUS } },
	-- With Shift: each key's rarer kin. Immolate stands on E until E's own spell comes. With ASDF the little
	-- finger holds Shift and Q is its own key, so Shift + Q keeps only what you seldom press, standing (Hellfire),
	-- and this job takes Shift + T: Destruction's Shadow Bolt is pressed every fight.
	{ name = "Searing Pain", key = "SHIFT-Q", asdf = "SHIFT-T", early = "E", asdfEarly = "E", what = "Searing Pain",
		SHOW, "/cast {5676}", by = { aff = IMMOLATE, demo = IMMOLATE, demopvp = IMMOLATE, destro = SHADOW } },
	{ name = "Burn", key = "SHIFT-E", asdf = "SHIFT-E", what = "Conflagrate if you have it; else Soul Fire",
		SHOW, "/cast [known:{1293817}] {1293817}; {6353}", by = { aff = false, demo = false, demopvp = false } },
	{ name = "Talent", key = "SHIFT-R", asdf = "SHIFT-R", what = "Shadowburn, Soul Link or Wrack: the talent you have",
		SHOW, "/cast [known:{17877}] {17877}; [known:{19028}] {19028}; {1316697}",
		by = { destro = SHADOWBURN, aff = WRACK, demo = LINK, demopvp = LINK } },
	{ name = "Hellfire", key = "SHIFT-T", asdf = "SHIFT-Q", what = "Hellfire",
		SHOW, "/cast {1949}", by = { aff = false, demopvp = false, destro = HAVOC } },
	-- An instant curse pulls whatever you target, so it keeps off Shift + a key you move with, and never stands
	-- in on an easy key.
	{ name = "Curse", key = "SHIFT-F", asdf = "SHIFT-G", stay = true, what = "Curse of Weakness",
		SHOW, "/cast {702}", by = { destro = ELEMENTS, demopvp = EXHAUSTION } },
	{ name = "Howl of Terror", key = "SHIFT-G", asdf = "SHIFT-W", what = "Howl of Terror",
		SHOW, "/cast {5484}" },
	-- Shift with a key you move with holds only what does no harm when pressed by mistake: your armor.
	{ name = "Armor", role = "armor", key = "SHIFT-5", asdf = "SHIFT-5", stay = true, what = "Demon Armor; Demon Skin until 20",
		SHOW, "/cast [known:{706}] {706}; {687}" },
	-- Never stands in on an easy key (stay): it sends your demon away.
	{ name = "Imp", key = "1", asdf = "1", what = "Summon Imp", stay = true,
		SHOW, "/cast {688}" },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use. (Your healthstone has the thumb's
-- key, so Healing is the potion alone.)
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { drink = true, potion = Shy.Keys.MANA })
-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first. Drain
-- Mana is for the PvP build, on a healer; the leveling builds have Life Tap. (Your Felsteed is your mount's key.)
Shy.Keys.Utility(JOBS, {
	{ name = "Unending Breath", spells = { 5697 } },
	{ name = "Curse of Tongues", spells = { 11719, 1714 } },
	{ name = "Drain Mana", spells = { 11704, 11703, 6226, 5138 }, by = { aff = false, demo = false, destro = false } },
	{ name = "Summoning", what = "Ritual of Summoning", spells = { 698 } },
	{ name = "Subjugate Demon", spells = { 11726, 11725, 1098 } },
	{ name = "Sense Demons", spells = { 5500 } },
	{ name = "Inferno", spells = { 1122 } },
})
K.JOBS = JOBS

-- How to play, by level and build: each step a job, the first you press first. Single is one enemy; cleave is
-- two to four close together.
-- The demon you level with, out before every pull: the Imp at first, the Voidwalker from 10 (the PvP build its
-- Succubus from 20). The Felhunter and the Succubus on 3 are for when you need them: casters, more damage.
local IMP = { "Imp", "out before you pull" }
local VOID = { "Voidwalker", "out before you pull" }
local SUCC = { "Succubus", "out before you pull" }
local SEND = { "Wand", "to send your demon" }
local SHARD = { "Drain Soul", "as it dies, for a shard" }
local TAP = { "Life Tap", "after the fight" }
local HURT = { "Drain Life", "when you're hurt" }
local WRONG = { "Stop", "when it goes wrong" }
local LOW = { "Funnel", "your demon is low" }
local HARD = { "Curse", "on a hard hitter" }
local SHIELD = { "Wall", "when it's too many" }
local STONE = { "Healthstone", "under half health" }
local SPLIT = { "Fear", "on one it isn't holding" }
local RAIN = { "Rain", "on 3+ close together" }
local HOWL = { "Howl of Terror", "when they reach you" }
local NIGHTFALL = { "Bolt", "when it's lit" }
local SECOND = { "Bane of Havoc", "on the second one" }
local KEEP = "keep it up"

local PLAY = {
	{ from = 1, tip = "Open with Immolate and Corruption, then Shadow Bolt or your wand while your Imp helps; rest when you're low.",
		single = { IMP, { "Immolate", "to open" }, { "Corruption" }, { "Agony" }, { "Bolt" }, { "Wand", "to finish it" }, TAP },
		cleave = { { "Corruption" }, { "Agony" }, { "Immolate" }, { "Fear", "on the second one" }, { "Wand" } } },
	{ from = 10, tip = "Send your Voidwalker in, put your damage over time on, then wand it down; tap and eat between fights.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, HURT, SHARD, LOW, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, LOW, STONE } },
	{ from = 20, tip = "Your Voidwalker holds the mob while your damage over time and your wand do the work; Rain of Fire for packs.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt", "mana to spare" }, HARD, HURT, SHARD, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, LOW, STONE } },
	{ from = 30, tip = "Put your demon in front, everything on, and wand to finish; Hellfire only when your health can take it.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt", "mana to spare" }, HARD, HURT, SHARD, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, { "Hellfire", "with plenty of health" }, LOW, SHIELD } },
	{ from = 40, tip = "Howl of Terror gets you out of a bad pull, and Death Coil from 42; otherwise fights go as before.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt", "mana to spare" }, HARD, HURT, WRONG, LOW, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, HOWL, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 50, tip = "You can take two at once: dot both, Fear one, and keep your demon healed.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt", "mana to spare" }, HARD, HURT, WRONG, LOW, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, HOWL, RAIN, LOW, STONE, SHIELD } },

	-- Affliction: Corruption instant from 14, Nightfall from 26, Siphon Life at 30, Wrack at 40.
	{ from = 20, build = "aff", tip = "Corruption is instant now: put your dots on, let Drain Life heal you, and wand to save mana.",
		single = { VOID, SEND, { "Corruption" }, { "Agony" }, { "Immolate", "mana to spare" }, HARD, HURT, NIGHTFALL, SHARD, TAP },
		cleave = { { "Corruption" }, { "Agony" }, SPLIT, HURT, RAIN, LOW, SHIELD } },
	{ from = 30, build = "aff", tip = "Three dots on every mob, then Drain Life through the fight; you'll seldom need to eat.",
		single = { VOID, SEND, { "Corruption" }, { "Agony" }, { "Siphon Life", KEEP }, HARD, HURT, NIGHTFALL, SHARD, TAP },
		cleave = { { "Corruption" }, { "Agony" }, { "Siphon Life" }, SPLIT, HURT, RAIN, SHIELD } },
	{ from = 40, build = "aff", tip = "Dot up, then channel Wrack to speed your dots along; Howl, and Death Coil from 42, save a bad pull.",
		single = { VOID, SEND, { "Corruption" }, { "Agony" }, { "Siphon Life", KEEP }, { "Wrack", "with all your dots on" }, HURT, NIGHTFALL, WRONG, SHARD, TAP },
		cleave = { { "Corruption" }, { "Agony" }, { "Siphon Life" }, HOWL, SPLIT, HURT, RAIN, SHIELD } },
	{ from = 50, build = "aff", tip = "Take two or three at once: dot them all, Fear one, and Drain Life through the rest.",
		single = { VOID, SEND, { "Corruption" }, { "Agony" }, { "Siphon Life", KEEP }, { "Wrack", "with all your dots on" }, HURT, NIGHTFALL, WRONG, SHARD, TAP },
		cleave = { { "Corruption" }, { "Agony" }, { "Siphon Life" }, SPLIT, HOWL, HURT, RAIN, LOW, SHIELD } },

	-- Demonology: a tougher demon, Soul Link at 30, Demonic Pact at 40, Corruption instant from the mid 40s.
	{ from = 20, build = "demo", tip = "Your Voidwalker tanks and takes the hits; add your dots and Searing Pain, and heal it when it's low.",
		single = { VOID, SEND, { "Agony" }, { "Corruption" }, { "Bolt" }, { "Searing Pain", "once it holds the mob" }, HARD, HURT, LOW, SHARD, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 30, build = "demo", tip = "Turn Soul Link on and leave it: your demon takes part of every hit, so keep it healed.",
		single = { VOID, { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, { "Bolt" }, { "Searing Pain", "once it holds the mob" }, HARD, HURT, LOW, SHARD, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, { "Hellfire", "with plenty of health" }, LOW, SHIELD } },
	{ from = 40, build = "demo", tip = "Give up your Imp for its buff, then fight beside your Voidwalker; Death Coil from 42 whatever gets loose.",
		single = { { "Imp", "then give it up" }, { "Demonic", "your Imp, each half hour" }, VOID, { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, { "Bolt" }, { "Searing Pain", "once it holds the mob" }, HURT, WRONG, LOW, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, HOWL, SPLIT, RAIN, { "Hellfire", "with plenty of health" }, LOW, SHIELD } },
	{ from = 50, build = "demo", tip = "Corruption is instant now too, so put your dots on a whole pack while your demon holds it.",
		single = { { "Imp", "then give it up" }, { "Demonic", "your Imp, each half hour" }, VOID, { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, { "Bolt" }, { "Searing Pain", "once it holds the mob" }, HURT, WRONG, LOW, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, HOWL, SPLIT, RAIN, { "Hellfire", "with plenty of health" }, LOW, SHIELD } },

	-- Destruction: Shadowburn at 20, Conflagrate at 25, Bane of Havoc at 30, Incinerate at 40.
	{ from = 20, build = "destro", tip = "Send the Voidwalker first, then Immolate and Shadow Bolts; Shadowburn finishes it and gives you a shard.",
		single = { VOID, SEND, { "Immolate", "to open" }, { "Bolt" }, { "Shadowburn", "to finish it" }, { "Agony" }, { "Curse", "on a tough one" }, HURT, TAP },
		cleave = { SEND, { "Immolate" }, { "Corruption" }, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 25, build = "destro", tip = "Immolate, then Conflagrate to burst it; Shadow Bolts in between, and Shadowburn to finish.",
		single = { VOID, SEND, { "Immolate", "to open" }, { "Burn", "while Immolate is on" }, { "Bolt" }, { "Shadowburn", "to finish it" }, { "Agony" }, { "Curse", "on a tough one" }, HURT, TAP },
		cleave = { SEND, { "Immolate" }, { "Corruption" }, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 30, build = "destro", tip = "Put Bane of Havoc on a second mob: it takes a share of every hit you land. Let your demon go first, and Life Tap often.",
		single = { VOID, SEND, { "Immolate", "to open" }, { "Burn", "while Immolate is on" }, { "Bolt" }, { "Shadowburn", "to finish it" }, { "Agony" }, { "Curse", "on a tough one" }, HURT, LOW, TAP },
		cleave = { SEND, SECOND, { "Immolate" }, SPLIT, RAIN, { "Hellfire", "with plenty of health" }, LOW, SHIELD } },
	{ from = 40, build = "destro", tip = "Incinerate hits harder on a burning target, Shadow Bolt after a Conflagrate: keep Immolate on.",
		single = { VOID, SEND, { "Immolate", KEEP }, { "Burn", "when it's ready" }, { "Shadow Bolt", "after Conflagrate" }, { "Bolt" }, { "Shadowburn", "to finish it" }, HURT, WRONG, LOW, TAP },
		cleave = { SEND, SECOND, { "Immolate" }, HOWL, RAIN, { "Hellfire", "with plenty of health" }, SPLIT, SHIELD } },
	{ from = 50, build = "destro", tip = "Open from range and burn it down fast; Death Coil and Howl anything that reaches you.",
		single = { VOID, SEND, { "Immolate", KEEP }, { "Burn", "when it's ready" }, { "Shadow Bolt", "after Conflagrate" }, { "Bolt" }, { "Shadowburn", "to finish it" }, { "Corruption" }, HURT, WRONG, LOW, TAP },
		cleave = { SEND, SECOND, { "Immolate" }, HOWL, RAIN, { "Hellfire", "with plenty of health" }, SPLIT, LOW, SHIELD } },

	-- Soul Link PvP: a tough demon back in a moment, Soul Link at 30, Corruption instant from the 40s, Amplify
	-- Curse at 41 (on the curse's key), Curse of Exhaustion at 46, Siphon Life at 54.
	{ from = 20, build = "demopvp", tip = "Your demon is tough and comes back fast: put your dots on and let it take the hits.",
		single = { SUCC, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt" }, HARD, HURT, LOW, SHARD, TAP },
		cleave = { SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 30, build = "demopvp", tip = "Turn Soul Link on and leave it: your demon takes part of every hit, so keep it healed.",
		single = { SUCC, { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, { "Immolate" }, { "Bolt" }, HARD, HURT, LOW, SHARD, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Agony" }, { "Corruption" }, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 40, build = "demopvp", tip = "Corruption turns instant over these levels, your curse is amplified from 41, and Howl and Death Coil keep anything off you.",
		single = { SUCC, { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, { "Immolate" }, { "Bolt" }, { "Curse", "amplified, on a hard hitter" }, HURT, WRONG, LOW, SHARD, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, HOWL, SPLIT, RAIN, LOW, SHIELD } },
	{ from = 50, build = "demopvp", tip = "Your dots now and then light up Shadow Bolt: cast it then, and let your demon hold the rest.",
		single = { SUCC, { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, { "Siphon Life", KEEP }, { "Immolate", "until Siphon Life" }, { "Curse", "amplified, on one that runs" }, NIGHTFALL, HURT, WRONG, LOW, SHARD, TAP },
		cleave = { { "Soul Link", KEEP }, SEND, { "Corruption" }, { "Agony" }, HOWL, SPLIT, RAIN, LOW, SHIELD } },
}
K.PLAY = PLAY

local OPTS = {
	knows = 686,                             -- Shadow Bolt: a warlock's from level 1
	list = "/shywarlock keys list",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isWarlock then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isWarlock then
		T:Print("your keys are laid out on a warlock only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA stone's key uses the stone you carry and makes one when you carry none."
end

-- From login on, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
