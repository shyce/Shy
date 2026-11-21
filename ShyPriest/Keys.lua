-- A priest's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the spell by what you
-- have learned, so a spell arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy priest keys)
--   ns.Keys.List()    every key and what it does, as text
--
-- A heal, a shield or a blessing goes to the friend the mouse is on, else the friend you have targeted, else you.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}

-- The form to stay in (OPTS.keep), on 1 for a build that takes it.
local SHADOWFORM = { 15473 }   -- Shadowform
ns.Keys = K

local SHOW = "#showtooltip"
local FRIEND, Grows = Shy.Keys.FRIEND, Shy.Keys.Grows

-- Discipline and Holy heal first: their three heals stand where the others' three attacks do, and the
-- attacks where the heals were. Discipline and Holy each have a spell of their own where Shadow Word: Death is, and
-- Shadow has Vampiric Embrace and Silence where the others have Holy Fire and Shackle Undead.
local function Healer(job) return { disc = job, holy = job } end
local function Shadow(job) return { shadow = job, shadowpvp = job } end
local PAIN = { name = "Pain", what = "Shadow Word: Pain", SHOW, "/cast {589}" }
local BLAST = { name = "Mind Blast", what = "Mind Blast", SHOW, "/cast {8092}" }
-- (a healer's nuke, and the shield and wand build's: Smite, by the word every class's nuke has)
local SMITE = { name = "Bolt", role = "bolt", what = "Smite", SHOW, "/cast {585}" }
local HEAL = { name = "Heal", role = "heal", what = "Greater Heal, with Inner Focus when it is ready. Heal until 40",
	"#showtooltip [known:{2060}] {2060}; {2054}", "/cast {14751}", Grows(2060, 2054) }
local RENEW = { name = "Renew", role = "renew", what = "Renew", SHOW, "/cast " .. FRIEND .. " {139}" }
local QUICK = { name = "Quick Heal", what = "Flash Heal. Lesser Heal until 20", SHOW, Grows(2061, 2050) }
local CONTROL = { name = "Control", what = "Mind Control", SHOW, "/cast {605}" }
local SILENCE = { name = "Silence", what = "Silence", SHOW, "/cast {15487}" }
local EMBRACE = { name = "Embrace", what = "Vampiric Embrace", SHOW, "/cast {15286}" }
local PENANCE = { name = "Penance", what = "Penance, on the friend under your mouse, or your target",
	SHOW, "/cast [@mouseover,help,nodead][] {402174}" }
local NOVA = { name = "Holy Nova", what = "Holy Nova", SHOW, "/cast {15237}" }
-- Shield and wand: the wand is the build's damage, so it takes the easiest key, Mind Blast R and Smite the wand's.
local WAND = { name = "Wand", role = "wand", what = "Shoot your wand", SHOW, "/cast !{5019}" }
-- Shadow: Devouring Plague on T, the area key (Devouring Contagion spreads it), and the big heal on B. You can't heal
-- in Shadowform, so Shadow's heals drop it first.
local PLAGUE = { name = "Plague", what = "Devouring Plague", SHOW, "/cast {2944}" }
local FORMHEAL = { name = "Heal", role = "heal", what = "Greater Heal. Heal until 40. Drops Shadowform first",
	"#showtooltip [known:{2060}] {2060}; {2054}", "/cancelform", Grows(2060, 2054) }
-- Shadow takes Inner Focus late, for Mind Blast: on a key of its own, where the healers' Prayer of Mending is.
-- (the other builds spend it on the big heal, which casts it first)
local FOCUS = { name = "Inner Focus", what = "Inner Focus", SHOW, "/cast {14751}" }
local FORMRENEW = { name = "Renew", role = "renew", what = "Renew. Drops Shadowform first",
	SHOW, "/cancelform", "/cast " .. FRIEND .. " {139}" }
local FORMQUICK = { name = "Quick Heal", what = "Flash Heal. Lesser Heal until 20. Drops Shadowform first",
	SHOW, "/cancelform", Grows(2061, 2050) }

-- A key is named for the one ability it casts; one that casts several as you level has a word true of them all
-- (Heal, Quick Heal, Disease), and what every class has is called the same on each (Stop, Bolt, Wand, Raise).
-- Each job's key as you move: key with WASD, asdf with ASDF (S forward, F back: the hand a key further right).
local JOBS = {
	-- The fight, under the fingers that are free while you move. The nuke is first, so it is R's from level 1.
	{ name = "Bolt", role = "bolt", key = "R", asdf = "R", what = "Smite. Mind Flay if you have it",
		SHOW, "/cast [known:{15407}] {15407}; {585}", by = { disc = HEAL, holy = HEAL, wand = BLAST } },
	{ name = "Pain", key = "Q", asdf = "Q", what = "Shadow Word: Pain",
		SHOW, "/cast {589}", by = Healer(RENEW) },
	{ name = "Mind Blast", key = "E", asdf = "E", what = "Mind Blast",
		SHOW, "/cast {8092}", by = { disc = QUICK, holy = QUICK, wand = WAND } },
	-- With ASDF the wand goes over the running finger: you shoot it standing still, and G is kept for an instant cast on the run.
	{ name = "Wand", role = "wand", key = "Z", asdf = "W", early = "F", what = "Shoot your wand",
		SHOW, "/cast !{5019}", by = { wand = SMITE } },
	-- A healer's Smite stands on R until the big heal is learned (16), then goes to T.
	{ name = "Heal", role = "heal", key = "T", asdf = "T", early = "R", asdfEarly = "R", what = "Greater Heal, with Inner Focus when it is ready. Heal until 40",
		"#showtooltip [known:{2060}] {2060}; {2054}", "/cast {14751}", Grows(2060, 2054),
		by = { disc = SMITE, holy = SMITE, shadow = PLAGUE, shadowpvp = PLAGUE } },
	-- With ASDF the stop takes G, so Renew (a healer's Pain) is on Z there; it stands on G until the stop comes.
	{ name = "Renew", role = "renew", key = "G", asdf = "Z", asdfEarly = "G", what = "Renew",
		SHOW, "/cast " .. FRIEND .. " {139}", by = { disc = PAIN, holy = PAIN, shadow = FORMRENEW, shadowpvp = FORMRENEW } },
	{ name = "Quick Heal", key = "V", asdf = "V", what = "Flash Heal. Lesser Heal until 20",
		SHOW, Grows(2061, 2050), by = { disc = BLAST, holy = BLAST, shadow = FORMQUICK, shadowpvp = FORMQUICK } },
	{ name = "Fade", key = "X", asdf = "X", what = "Fade",
		SHOW, "/cast {586}" },
	{ name = "Dispel", key = "C", asdf = "C", what = "Dispel Magic, on whoever is under your mouse, or your target, or you",
		SHOW, "/cast [@mouseover,exists,nodead][exists,nodead][@player] {527}" },
	-- Devouring Plague costs too much to cast without Devouring Contagion, which only Shadow takes: Shadow has it on
	-- T, and the big heal here. The other builds leave the far key empty.
	{ name = "Plague", key = "B", asdf = "B", what = "Devouring Plague",
		SHOW, "/cast {2944}", by = { shadow = FORMHEAL, shadowpvp = FORMHEAL, wand = false, disc = false, holy = false } },
	{ name = "Fortitude", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Power Word: Fortitude",
		SHOW, "/cast " .. FRIEND .. " {1243}" },
	{ name = "Inner Fire", key = "SHIFT-5", asdf = "SHIFT-5", stay = true, what = "Inner Fire",
		SHOW, "/cast {588}" },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Shield", role = "shield", key = "BUTTON4", asdf = "BUTTON4", what = "Power Word: Shield",
		SHOW, "/cast " .. FRIEND .. " {17}" },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Psychic Scream",
		SHOW, "/cast {8122}" },
	{ name = "Infusion", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", what = "Power Infusion",
		SHOW, "/cast " .. FRIEND .. " {10060}" },
	{ name = "Shackle", key = "SHIFT-F", asdf = "SHIFT-G", what = "Shackle Undead",
		SHOW, "/cast {9484}", by = Shadow(SILENCE) },
	-- The number row: what your people's priests alone are taught, each people its own two (the one that guards you
	-- on 4, the other on 5), and the ward every priest has, on 3 beside them.
	-- (they stay on their keys from the level they are learned: neither hops over the easy keys meanwhile)
	{ name = "Gift", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", stay = true, what = "Your race's defensive priest spell",
		race = Shy.Keys.Gifts("PRIEST", 1) },
	{ name = "Second Gift", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", stay = true, what = "Your race's other priest spell",
		race = Shy.Keys.Gifts("PRIEST", 2) },
	{ name = "Fear Ward", key = "3", asdf = "3", stay = true, what = "Fear Ward, on the friend under your mouse, or your target, or you",
		SHOW, "/cast " .. FRIEND .. " {6346}" },
	-- With Shift: each key's rarer kin.
	-- (Holy Fire is Holy's opener; Discipline's and the wand build's Mind Blast does that job)
	-- With ASDF the little finger holds Shift and the ring finger S, so Shift + Q is a stretch that stops you: an
	-- opener cast every pull takes Shift + E there, and Mana Burn, which you seldom cast, has Shift + Q.
	{ name = "Holy Fire", key = "SHIFT-Q", asdf = "SHIFT-E", what = "Holy Fire",
		SHOW, "/cast {14914}", by = { shadow = EMBRACE, shadowpvp = EMBRACE, wand = false, disc = false } },
	-- (a fight with another player's mana: PvP's alone)
	{ name = "Mana Burn", key = "SHIFT-E", asdf = "SHIFT-Q", what = "Mana Burn",
		SHOW, "/cast {8129}", by = { shadow = false, wand = false, disc = false, holy = false } },
	-- The nuke's rarer kin: Shadow Word: Death finishes; Discipline's Penance, Holy's Holy Nova.
	{ name = "Death", key = "SHIFT-R", asdf = "SHIFT-R", what = "Shadow Word: Death",
		SHOW, "/cast {1309595}", by = { disc = PENANCE, wand = PENANCE, holy = NOVA } },
	-- (a group heal: the healers'; Shadow PvP has Mind Control here)
	{ name = "Prayer", key = "SHIFT-T", asdf = "SHIFT-T", what = "Prayer of Healing",
		SHOW, "/cast {596}", by = { shadow = false, shadowpvp = CONTROL, wand = false } },
	{ name = "Raise", role = "raise", key = "BUTTON5", asdf = "BUTTON5", stay = true, what = "Resurrection, on the dead friend under your mouse or your target, or the one you click next",
		"#showtooltip {2006}", "/cast " .. Shy.Keys.DEAD .. " {2006}" },
	-- With ASDF, Shift + W would lift the running finger: Mending, kept on the tank every ten seconds, takes Shift + F,
	-- the index finger's own key (a Mending pressed instead of a step back does no harm). Shadow has Inner Focus here.
	{ name = "Mending", key = "SHIFT-G", asdf = "SHIFT-F", what = "Prayer of Mending",
		SHOW, "/cast " .. FRIEND .. " {401859}", by = Shadow(FOCUS) },
	-- Shift + A side-steps too: a blessing does no harm there.
	{ name = "Spirit", key = "SHIFT-A", asdf = "SHIFT-A", what = "Divine Spirit",
		SHOW, "/cast " .. FRIEND .. " {14752}" },
	-- Shift + D side-steps: only a cure, harmless if it is pressed by mistake.
	{ name = "Disease", role = "disease", key = "SHIFT-D", asdf = "SHIFT-D", stay = true, what = "Abolish Disease. Cure Disease until 32",
		SHOW, Grows(552, 528) },
}
-- Shift + 1 and 2: what your people alone can do. With Shift on the bottom row: what your bags hold, the best of
-- it you can use.
Shy.Keys.People(JOBS)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })
-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first. Shackle
-- Undead is here for Shadow, whose Silence has its key; Mind Control for every build but Shadow PvP, which has it on
-- Shift + T. (Mind Vision, Mana Burn outside PvP and the 56-60 group prayers do nothing for you while leveling.)
Shy.Keys.Utility(JOBS, {
	{ name = "Levitate", spells = { 1706 } },
	{ name = "Shackle Undead", spells = { 10955, 9485, 9484 }, by = { wand = false, disc = false, holy = false } },
	{ name = "Mind Soothe", spells = { 10953, 8192, 453 } },
	{ name = "Protection", what = "Shadow Protection", spells = { 10958, 10957, 976 } },
	{ name = "Prayer Fortitude", what = "Prayer of Fortitude", spells = { 21564, 21562 } },
	{ name = "Mind Control", spells = { 10912, 10911, 605 }, by = { shadowpvp = false } },
})
-- 1: Shadowform, the spell itself on the left flyout, for a build that takes it (2 and 3 are yours to fill).
do
	local form = { { name = "Shadowform", unpack(SHADOWFORM) } }
	Shy.Keys.Stays(JOBS, { shadow = form, shadowpvp = form, wand = {}, disc = {}, holy = {} })
end
K.JOBS = JOBS

-- How to fight, by level and build: each step a job (its key and what it casts then; a step not learned yet
-- drops out). single: one enemy, first things first. cleave: two to four at once.
local PLAY = {
	{ from = 1, tip = "Smite from range, put Pain on it and let your wand finish it. Heal yourself once you drop under half.",
		single = { { "Bolt", "to open" }, { "Pain", "keep it up" }, { "Shield", "before it reaches you" }, { "Wand", "to finish it" },
			{ "Quick Heal", "under half health" } },
		cleave = { { "Shield", "before they reach you" }, { "Pain", "on each enemy" }, { "Bolt" }, { "Wand" },
			{ "Quick Heal", "under half health" } } },
	{ from = 10, tip = "Shield first, then Pain and Mind Blast. Your wand finishes it and saves mana for the next pull.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt", "mana to spare" },
			{ "Wand", "to finish it" }, { "Quick Heal", "under half health" } },
		cleave = { { "Shield", "to open" }, { "Pain", "on each enemy" }, { "Stop", "when they're on you" }, { "Mind Blast" },
			{ "Wand" }, { "Renew", "keep it on you" } } },
	{ from = 20, tip = "Shield, Pain and Mind Blast, then Mind Flay (Smite until you have it). Fall back on your wand when mana runs low.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt" },
			{ "Wand", "mana running low" }, { "Quick Heal", "under half health" } },
		cleave = { { "Shield", "to open" }, { "Plague", "on the first of them" }, { "Pain", "on each enemy" }, { "Stop", "on 3+ enemies" },
			{ "Mind Blast" }, { "Bolt" }, { "Renew", "keep it on you" } } },
	{ from = 30, tip = "Open with Vampiric Embrace and Pain so your hits heal you, Mind Blast when it's ready, Mind Flay for the rest.",
		single = { { "Shield", "to open" }, { "Embrace", "keep it up" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" },
			{ "Silence", "when it starts a cast" }, { "Bolt" }, { "Death", "to finish it" }, { "Wand", "mana running low" } },
		cleave = { { "Shield", "to open" }, { "Plague", "on the first of them" }, { "Pain", "on each enemy" },
			{ "Embrace", "on the one you hit" }, { "Stop", "on 3+ enemies" }, { "Mind Blast" }, { "Bolt" } } },
	{ from = 40, tip = "Once you have Shadowform (1), stay in it. Shield, Vampiric Embrace, Pain, Plague and Mind Blast, then Mind Flay.",
		single = { { "Shield", "to open" }, { "Embrace", "keep it up" }, { "Pain", "keep it up" }, { "Plague", "when it's ready" },
			{ "Mind Blast", "when it's ready" }, { "Silence", "when it starts a cast" }, { "Bolt" }, { "Death", "to finish it" } },
		cleave = { { "Shield", "to open" }, { "Plague", "on the first of them" }, { "Pain", "on each enemy" },
			{ "Embrace", "on the one you hit" }, { "Stop", "on 3+ enemies" }, { "Mind Blast" }, { "Bolt" } } },
	{ from = 50, tip = "Mobs hit harder now. Silence the casters, Scream away a pack, and keep Shadowform up between pulls.",
		single = { { "Shield", "to open" }, { "Embrace", "keep it up" }, { "Pain", "keep it up" }, { "Plague", "when it's ready" },
			{ "Inner Focus", "just before Mind Blast" }, { "Mind Blast", "when it's ready" }, { "Silence", "when it starts a cast" }, { "Bolt" }, { "Death", "to finish it" } },
		cleave = { { "Shield", "to open" }, { "Plague", "on the first of them" }, { "Pain", "on each enemy" },
			{ "Embrace", "on the one you hit" }, { "Stop", "on 3+ enemies" }, { "Mind Blast" }, { "Bolt" } } },

	-- Shield and wand: Discipline's safe way to quest.
	{ from = 20, build = "wand", tip = "Shield, Pain, then your wand does the work. Mind Blast only when you have mana to spare.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Wand" }, { "Mind Blast", "mana to spare" },
			{ "Renew", "under half health" }, { "Quick Heal", "in trouble" } },
		cleave = { { "Shield", "to open" }, { "Pain", "on each enemy" }, { "Stop", "on 3+ enemies" }, { "Wand" },
			{ "Shackle", "on an undead add" }, { "Renew", "keep it on you" } } },
	{ from = 30, build = "wand", tip = "Shield and Pain, Penance when it's ready, and your wand for everything else. You rarely need to drink.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Wand" },
			{ "Mind Blast", "mana to spare" }, { "Renew", "under half health" } },
		cleave = { { "Shield", "to open" }, { "Pain", "on each enemy" }, { "Stop", "on 3+ enemies" }, { "Penance" },
			{ "Wand" }, { "Renew", "keep it on you" } } },
	{ from = 40, build = "wand", tip = "Keep Shield and Inner Fire up and let Pain and your wand do the killing. Penance hurts or heals as you need.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Wand" },
			{ "Mind Blast", "mana to spare" }, { "Heal", "under half health" } },
		cleave = { { "Shield", "to open" }, { "Pain", "on each enemy" }, { "Stop", "on 3+ enemies" }, { "Penance" },
			{ "Wand" }, { "Heal", "under half health" } } },
	{ from = 50, build = "wand", tip = "Two at a time is fine. Shield soaks the hits, Pain ticks on both and your wand finishes them.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Wand" },
			{ "Mind Blast", "mana to spare" }, { "Bolt", "mana to spare" }, { "Heal", "under half health" } },
		cleave = { { "Shield", "to open" }, { "Pain", "on each enemy" }, { "Penance" }, { "Wand" }, { "Stop", "when they're on you" },
			{ "Infusion", "on yourself, a hard pull" }, { "Heal", "under half health" } } },

	-- The healers: one enemy is how you fight alone; several is a pack on your tank, and you heal it.
	-- Discipline: shields first, alone and in a group.
	{ from = 10, build = "disc", tip = "Alone, Shield, Pain and your wand. With a tank, Shield and Renew them and heal when they drop.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "mana to spare" }, { "Wand", "to finish it" },
			{ "Quick Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Shield", "on whoever is hit" }, { "Renew", "on your tank" }, { "Heal", "when your tank drops" },
			{ "Quick Heal", "in a hurry" }, { "Pain", "on each enemy" }, { "Wand", "mana to spare" } } },
	{ from = 20, build = "disc", tip = "Alone, Shield, Pain and your wand. With a tank, keep a shield on whoever is hit and Renew on the tank.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "mana to spare" }, { "Wand" },
			{ "Quick Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Shield", "on whoever is hit" }, { "Renew", "on your tank" }, { "Heal", "when your tank drops" },
			{ "Quick Heal", "in a hurry" }, { "Pain", "on each enemy" }, { "Wand", "mana to spare" } } },
	{ from = 30, build = "disc", tip = "Penance hits the enemy or heals a friend under the mouse. Keep a shield on whoever is taking hits.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Wand" },
			{ "Mind Blast", "mana to spare" }, { "Quick Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Shield", "on whoever is hit" }, { "Renew", "on your tank" }, { "Penance", "on your tank" },
			{ "Heal", "when your tank drops" }, { "Quick Heal", "in a hurry" }, { "Pain", "mana to spare" } } },
	{ from = 40, build = "disc", tip = "Shield and Penance carry you. Save Power Infusion for a hard pull and Greater Heal for big hits.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Mind Blast", "mana to spare" },
			{ "Wand" }, { "Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Shield", "on whoever is hit" }, { "Renew", "on your tank" }, { "Penance", "on your tank" },
			{ "Heal", "when your tank drops" }, { "Infusion", "a hard pull" }, { "Quick Heal", "in a hurry" } } },
	{ from = 50, build = "disc", tip = "Your shields soak more than ever. Keep one on your tank, Renew them, and Penance whatever needs it most.",
		single = { { "Shield", "to open" }, { "Pain", "keep it up" }, { "Penance", "when it's ready" }, { "Mind Blast", "mana to spare" },
			{ "Wand" }, { "Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Shield", "on whoever is hit" }, { "Renew", "on your tank" }, { "Penance", "on your tank" },
			{ "Heal", "when your tank drops" }, { "Infusion", "a hard pull" }, { "Quick Heal", "in a hurry" } } },

	-- Holy: Holy Fire and Smite alone; Renew and the big heal on your tank, Holy Nova for packs.
	{ from = 10, build = "holy", tip = "Alone, Smite, Pain and your wand. With a tank, keep Renew on them and heal when they drop.",
		single = { { "Bolt", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Shield", "before it reaches you" },
			{ "Wand", "to finish it" }, { "Quick Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Renew", "on your tank" }, { "Heal", "when your tank drops" }, { "Shield", "on whoever is hit" },
			{ "Quick Heal", "in a hurry" }, { "Pain", "on each enemy" }, { "Bolt", "mana to spare" } } },
	{ from = 20, build = "holy", tip = "Alone, open with Holy Fire, then Smite and your wand. With a tank, Renew them and heal when they drop.",
		single = { { "Holy Fire", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt" }, { "Wand", "mana running low" },
			{ "Quick Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Renew", "on your tank" }, { "Heal", "when your tank drops" }, { "Holy Nova", "when they're close" },
			{ "Shield", "on whoever is hit" }, { "Quick Heal", "in a hurry" }, { "Pain", "on each enemy" } } },
	{ from = 30, build = "holy", tip = "Holy Fire, Mind Blast and Smite hit hard but cost mana. In a group, Renew your tank and Holy Nova the pack.",
		single = { { "Holy Fire", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt" },
			{ "Wand", "mana running low" }, { "Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Renew", "on your tank" }, { "Heal", "when your tank drops" }, { "Holy Nova", "when they're close" },
			{ "Prayer", "when all are hurt" }, { "Shield", "on whoever is hit" }, { "Quick Heal", "in a hurry" } } },
	{ from = 40, build = "holy", tip = "Prayer of Mending on your tank before a pull, Holy Nova when they close in, Greater Heal if it goes wrong.",
		single = { { "Holy Fire", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt" },
			{ "Wand", "mana running low" }, { "Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Mending", "on your tank" }, { "Renew", "on your tank" }, { "Heal", "when your tank drops" }, { "Shield", "on whoever is hit" },
			{ "Holy Nova", "when they're close" }, { "Prayer", "when all are hurt" }, { "Quick Heal", "in a hurry" } } },
	{ from = 50, build = "holy", tip = "Smite and Holy Fire still kill fast. Holy Nova and Mending turn a pack's hits into healing.",
		single = { { "Holy Fire", "to open" }, { "Pain", "keep it up" }, { "Mind Blast", "when it's ready" }, { "Bolt" },
			{ "Wand", "mana running low" }, { "Heal", "under half health" }, { "Stop", "to break off and heal" } },
		cleave = { { "Mending", "on your tank" }, { "Renew", "on your tank" }, { "Heal", "when your tank drops" }, { "Shield", "on whoever is hit" },
			{ "Holy Nova", "when they're close" }, { "Prayer", "when all are hurt" }, { "Quick Heal", "in a hurry" } } },
}
K.PLAY = PLAY

local OPTS = {
	knows = 585,                             -- Smite: a priest's from level 1
	stances = "Shadowform, for a build that takes it",
	keep = { shadow = SHADOWFORM, shadowpvp = SHADOWFORM },   -- (the other builds stay as they are)
	-- 1 presses Shadowform for a build that takes it; any other build has 1 2 3 as buttons of its own.
	keeps = "form",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isPriest then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isPriest then
		T:Print("your keys are laid out on a priest only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA heal, a shield or a blessing goes to the friend under your mouse, or your target, or you."
end

-- From login on, the bags' keys follow the bags.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
