-- A mage's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the spell by what you
-- have learned, so a spell arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shymage keys)
--   ns.Keys.List()    every key and what it does, as text
--
-- The mana gem's key uses the gem you carry and conjures one when you carry none.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}
ns.Keys = K

local SHOW = "#showtooltip"
local FRIEND, Either = Shy.Keys.FRIEND, Shy.Keys.Either

-- Frost is the layout as it stands. Every build has its main bolt on R and Fire Blast on E. Q holds the build's own
-- spell (Ice Lance, Pyroblast, Arcane Wrath, or Cone of Cold for a mage who fights packs; Arcane Missiles until
-- then), T its area attack (Cone of Cold for Frost, which presses it every fight; Arcane Explosion for the rest),
-- Shift + R its rarer bolt (Scorch, or Arcane's free Missiles), 4 and Shift + Mouse 4 its cooldowns. Nothing of
-- another school stands on a key a build never presses: a Frost mage has no Fireball, a Fire mage no Cone of Cold.
-- Both ways of moving keep the same keys, but for the keys you move with: the wand, Polymorph and Remove Lesser
-- Curse step over them. With ASDF the ring finger holds S to run, so what you press on the run
-- (Fire Blast, Ice Lance, Frost Nova, Blink, Cone of Cold) sits under the middle and index fingers, the thumb and
-- the little finger, and W over the running finger holds Polymorph, which you cast standing. Counterspell, the
-- stop, is on F (G with ASDF), beside the index finger: Mouse 5 is too far to reach in a hurry.

-- The three Frost builds have nothing for a key (by = Frost{ ... }: the rest as given).
local function Frost(by)
	for _, build in ipairs({ "frost", "frostaoe", "frostpvp" }) do
		if by[build] == nil then by[build] = false end
	end
	return by
end

local JOBS = {
	-- The fight, under the fingers that are free while you move. (Every mage levels 4 to 19 on Frostbolt: it slows.)
	{ name = "Bolt", role = "bolt", key = "R", asdf = "R", what = "Frostbolt; Fireball until 4",
		SHOW, "/cast [known:{116}] {116}; {133}",
		by = { fire = { name = "Bolt", role = "bolt", what = "Fireball", SHOW, "/cast {133}" },
			arcane = { name = "Bolt", role = "bolt", what = "Arcane Blast; Frostbolt until you have it", SHOW, "/cast [known:{400574}] {400574}; [known:{116}] {116}; {133}" } } },
	{ name = "Fire Blast", key = "E", asdf = "E", what = "Fire Blast",
		SHOW, "/cast {2136}" },
	{ name = "Filler", role = "filler", key = "Q", asdf = "Q", what = "Ice Lance; Arcane Missiles until you have it",
		SHOW, "/cast [known:{1312002}] {1312002}; {5143}",
		by = { fire = { name = "Filler", role = "filler", what = "Pyroblast; Arcane Missiles until you have it", SHOW, "/cast [known:{11366}] {11366}; {5143}" },
			arcane = { name = "Filler", role = "filler", what = "Arcane Wrath; Arcane Missiles until you have it", SHOW, "/cast [known:{1326079}] {1326079}; {5143}" },
			frostaoe = { name = "Filler", role = "filler", what = "Cone of Cold; Arcane Missiles until you have it", SHOW, "/cast [known:{120}] {120}; {5143}" } } },
	-- (Frost's Arcane Explosion steps down to Z when Cone of Cold takes T)
	{ name = "Area", role = "area", key = "T", asdf = "T", what = "Cone of Cold; Arcane Explosion until you have it",
		SHOW, "/cast [known:{120}] {120}; {1449}",
		by = { arcane = { name = "Area", role = "area", what = "Arcane Explosion", SHOW, "/cast {1449}" },
			fire = { name = "Area", role = "area", what = "Arcane Explosion", SHOW, "/cast {1449}" },
			frostaoe = { name = "Area", role = "area", what = "Arcane Explosion", SHOW, "/cast {1449}" } } },
	{ name = "Wand", role = "wand", key = "SHIFT-F", asdf = "SHIFT-G", early = "F", asdfEarly = "G", stay = true, what = "Shoot your wand",
		SHOW, "/cast !{5019}" },
	{ name = "Polymorph", key = "G", asdf = "W", what = "Polymorph",
		SHOW, "/cast {118}" },
	{ name = "Shield", role = "shield", key = "V", asdf = "V", what = "Ice Barrier if you have it; else Mana Shield",
		SHOW, "/cast [known:{11426}] {11426}; {1463}" },
	{ name = "Mana Gem", key = "X", asdf = "X", what = "Your mana gem; conjures one when you have none",
		supply = { "managem" }, Either({ 10054, 10053, 3552, 759 }) },
	{ name = "Blink", key = "C", asdf = "C", what = "Blink",
		SHOW, "/cast {1953}" },
	{ name = "Intellect", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Arcane Intellect",
		SHOW, "/cast " .. FRIEND .. " {1459}" },
	-- What you stay in, on 1 and 2: your armor, and the one for mana.
	{ name = "Armor", role = "armor", key = "1", asdf = "1", stay = true, what = "Ice Armor; Frost Armor until 30",
		SHOW, "/cast [known:{7302}] {7302}; {168}" },
	-- What you answer with when they reach you, pressed on the run: Frost Nova on the thumb.
	{ name = "Frost Nova", key = "BUTTON4", asdf = "BUTTON4", what = "Frost Nova",
		SHOW, "/cast {122}" },
	-- Z: what is left over of the area attacks (Frost's Arcane Explosion, once Cone of Cold has T; Arcane's Cone
	-- of Cold), and a Frost AoE mage's Ice Lance, for the last one standing.
	{ name = "Explosion", key = "Z", asdf = "Z", what = "Arcane Explosion",
		SHOW, "/cast {1449}",
		by = { arcane = { name = "Cone", what = "Cone of Cold", SHOW, "/cast {120}" },
			frostaoe = { name = "Ice Lance", what = "Ice Lance", SHOW, "/cast {1312002}" },
			fire = false } },
	-- With Shift: each key's rarer kin. Shift + R: the build's rarer bolt, Fire's Scorch and Arcane's free Missiles
	-- (Frost PvP's too, once Missile Barrage frees them).
	-- (The rarer bolt, Evocation and Blizzard stay on their own keys: a spell shouldn't stand on an easy key for a
	-- few levels and then move again.)
	{ name = "Scorch", key = "SHIFT-R", asdf = "SHIFT-R", stay = true, what = "Scorch",
		SHOW, "/cast {2948}",
		by = Frost({ arcane = { name = "Missiles", what = "Arcane Missiles", SHOW, "/cast {5143}" },
			frostpvp = { name = "Missiles", what = "Arcane Missiles, once Missile Barrage frees them", SHOW, "/cast [known:{400588}] {5143}" } }) },
	{ name = "Evocation", key = "SHIFT-E", asdf = "SHIFT-E", stay = true, what = "Evocation",
		SHOW, "/cast {12051}" },
	{ name = "Blizzard", key = "SHIFT-T", asdf = "SHIFT-T", stay = true, what = "Blizzard",
		SHOW, "/cast {10}", by = { arcane = false, fire = false } },
	{ name = "Flamestrike", key = "B", asdf = "B", what = "Flamestrike",
		SHOW, "/cast {2120}", by = { frost = false, frostpvp = false } },
	{ name = "Uncurse", role = "uncurse", key = "SHIFT-G", asdf = "SHIFT-W", stay = true, what = "Remove Lesser Curse",
		SHOW, "/cast " .. FRIEND .. " {475}" },
	{ name = "Mage Armor", key = "2", asdf = "2", stay = true, what = "Mage Armor",
		SHOW, "/cast {6117}" },
	-- Shift + the thumb: what goes with Frost Nova (Cold Snap brings it back, Blast Wave throws them off you). Then
	-- Counterspell, the stop, on F (the wand stands there until you learn it, then steps to Shift + F).
	{ name = "Cold Snap", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", stay = true, what = "Cold Snap",
		SHOW, "/cast {12472}",
		by = { arcane = { name = "Presence of Mind", what = "Presence of Mind", SHOW, "/cast {12043}" },
			fire = { name = "Blast Wave", what = "Blast Wave", SHOW, "/cast {11113}" } } },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Counterspell",
		SHOW, "/cast {2139}" },
	-- The number row: your wall (Frost's Ice Block; Arcane and Fire have none, so their big cooldown), and what you
	-- conjure between fights, water first. (What you press when it goes wrong is where it always is.)
	{ name = "Wall", role = "wall", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4", stay = true, what = "Ice Block",
		SHOW, "/cast {11958}",
		by = { arcane = { name = "Arcane Power", what = "Arcane Power", SHOW, "/cast {12042}" },
			fire = { name = "Combustion", what = "Combustion", SHOW, "/cast {11129}" } } },
	{ name = "Water", key = "5", asdf = "5", spare = "MULTIACTIONBAR4BUTTON5", stay = true, what = "Conjure Water",
		SHOW, "/cast {5504}" },
	{ name = "Food", key = "SHIFT-D", asdf = "SHIFT-D", stay = true, what = "Conjure Food",
		SHOW, "/cast {587}" },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use.
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })

-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first: your
-- side's capitals (each named for the city), Slow Fall, the wards against a caster's school (Frost Warding makes
-- Frost Ward reflect too), and the Alliance's Dalaran at 50. A key only one side has stands for that side alone.
local SIDES = { alliance = { 1, 3, 4, 7, 95 }, horde = { 2, 5, 6, 8, 96 } }
local function Sided(what, alliance, horde)
	local race = {}
	for side, one in pairs({ alliance = alliance, horde = horde }) do
		local made = {}
		Shy.Keys.Utility(made, { one })
		for _, id in ipairs(SIDES[side]) do race[id] = made[1] end
	end
	return { name = (alliance or horde).name, what = what, spot = true, stay = true, race = race }
end
local function Both(one)
	local made = {}
	Shy.Keys.Utility(made, { one })
	return made[1]
end
for _, job in ipairs({
	Sided("Teleport to your side's first capital", { name = "Stormwind", what = "Teleport: Stormwind", spells = { 3561 } },
		{ name = "Orgrimmar", what = "Teleport: Orgrimmar", spells = { 3567 } }),
	Both({ name = "Slow Fall", spells = { 130 } }),
	Sided("Teleport to your side's second capital", { name = "Ironforge", what = "Teleport: Ironforge", spells = { 3562 } },
		{ name = "Undercity", what = "Teleport: Undercity", spells = { 3563 } }),
	Sided("Teleport to your side's third capital", { name = "Darnassus", what = "Teleport: Darnassus", spells = { 3565 } },
		{ name = "Thunder Bluff", what = "Teleport: Thunder Bluff", spells = { 3566 } }),
	Both({ name = "Frost Ward", spells = { 28609, 10177, 8462, 8461, 6143 } }),
	Both({ name = "Fire Ward", spells = { 10225, 10223, 8458, 8457, 543 } }),
	Sided("Teleport: Dalaran", { name = "Dalaran", what = "Teleport: Dalaran", spells = { 1297659 } }),
	-- Last, as there is room: the portals you open for others, your side's three (6 to = once Shift's are full).
	Sided("A portal to your side's first capital", { name = "Stormwind Portal", what = "Portal: Stormwind", spells = { 10059 } },
		{ name = "Orgrimmar Portal", what = "Portal: Orgrimmar", spells = { 11417 } }),
	Sided("A portal to your side's second capital", { name = "Ironforge Portal", what = "Portal: Ironforge", spells = { 11416 } },
		{ name = "Undercity Portal", what = "Portal: Undercity", spells = { 11418 } }),
	Sided("A portal to your side's third capital", { name = "Darnassus Portal", what = "Portal: Darnassus", spells = { 11419 } },
		{ name = "Thunder Portal", what = "Portal: Thunder Bluff", spells = { 11420 } }),
}) do
	JOBS[#JOBS + 1] = job
end
K.JOBS = JOBS

-- How to play, by level and build: each step a job (the key it is on and what it casts then), in the order you
-- press them when they're ready; single is one enemy, cleave two to four close together. Up to 20 every mage
-- fights alike; from 20 the plain brackets are Frost's, and Arcane, Fire and Frost AoE have their own (Frost PvP
-- from 50).
local PLAY = {
	{ from = 1, tip = "Open with your bolt from as far off as you can, finish with Fire Blast, and shoot your wand to save mana.",
		single = { { "Bolt", "to open" }, { "Fire Blast", "to finish it" }, { "Filler", "mana to spare" },
			{ "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the second one" }, { "Bolt" }, { "Fire Blast", "to finish it" }, { "Wand", "to save mana" } } },
	{ from = 10, tip = "Bolt them as they come, Frost Nova when one reaches you, then step back and bolt again; drink between pulls.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Fire Blast", "to finish it" },
			{ "Filler", "mana to spare" },
			{ "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Bolt", "once you step back" }, { "Fire Blast", "to finish one" } } },

	-- Frost (and any mage with no build picked): freeze them, lance them, step back and bolt. Ice Lance and Fire
	-- Blast share a cooldown: Ice Lance for the frozen one, Fire Blast for one that isn't.
	{ from = 20, tip = "Bolt from range, Frost Nova when they close, Ice Lance the frozen one, and Blink away if it gets close again.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Filler", "while it's frozen" },
			{ "Fire Blast", "if it isn't frozen" }, { "Stop", "when it casts" }, { "Blink", "to get away" },
			{ "Shield", "if it's hitting you" }, { "Evocation", "out of mana" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Area", "if they're on you" }, { "Blink", "to get away" } } },
	{ from = 26, tip = "Cone of Cold is your second answer: Frost Nova, step back, and Cone them as they break free.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Filler", "while it's frozen" },
			{ "Area", "as it breaks free" }, { "Fire Blast", "if it isn't frozen" }, { "Stop", "when it casts" },
			{ "Blink", "to get away" }, { "Shield", "if it's hitting you" }, { "Mana Gem", "low on mana" },
			{ "Evocation", "gem spent, still low" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Area", "as they break free" }, { "Explosion", "if they're on you" }, { "Blink", "to get away" } } },
	{ from = 30, tip = "Frost Nova, step back, Cone of Cold as they break free; once you have Ice Block and Cold Snap, two at a time is safe.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Filler", "while it's frozen" },
			{ "Area", "as it breaks free" }, { "Fire Blast", "if it isn't frozen" }, { "Cold Snap", "for a second Nova" },
			{ "Wall", "if it goes badly" }, { "Stop", "when it casts" }, { "Blink", "to get away" },
			{ "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Area", "as they break free" }, { "Cold Snap", "for a second Nova" }, { "Explosion", "if they're on you" },
			{ "Blink", "to get away" }, { "Wall", "if it goes badly" } } },
	{ from = 40, tip = "Put Ice Barrier up before each pull and you can take two or three at once: freeze them, lance them, bolt.",
		single = { { "Shield", "before the pull" }, { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" },
			{ "Filler", "while it's frozen" }, { "Area", "to finish it" }, { "Fire Blast", "if it isn't frozen" },
			{ "Cold Snap", "for a second Nova" }, { "Wall", "if it goes badly" }, { "Stop", "when it casts" },
			{ "Blink", "to get away" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Shield", "before the pull" }, { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" },
			{ "Blizzard", "while they're frozen" }, { "Area", "as they break free" }, { "Cold Snap", "for a second Nova" },
			{ "Explosion", "if they're on you" }, { "Blink", "to get away" }, { "Wall", "if it goes badly" } } },
	{ from = 50, tip = "Pull bigger groups now: Ice Barrier, Frost Nova and Blizzard, then Evocation once your mana gem is spent.",
		single = { { "Shield", "before the pull" }, { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" },
			{ "Filler", "while it's frozen" }, { "Area", "to finish it" }, { "Fire Blast", "if it isn't frozen" },
			{ "Cold Snap", "for a second Nova" }, { "Wall", "if it goes badly" }, { "Stop", "when it casts" },
			{ "Blink", "to get away" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Shield", "before the pull" }, { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" },
			{ "Blizzard", "while they're frozen" }, { "Area", "as they break free" }, { "Cold Snap", "for a second Nova" },
			{ "Explosion", "if they're on you" }, { "Blink", "to get away" }, { "Wall", "if it goes badly" } } },

	-- Arcane: Arcane Blast builds up, Arcane Wrath and free Missiles spend it; mana is the whole game.
	{ from = 20, build = "arcane", tip = "Arcane Blast two or three times, then spend it; stop before your mana runs dry, and Polymorph the extra one.",
		single = { { "Bolt", "two or three times" }, { "Filler", "to spend the build-up" },
			{ "Fire Blast", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Shield", "if it's hitting you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Evocation", "out of mana" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Flamestrike", "as they come in" }, { "Blink", "to get away" } } },
	{ from = 25, build = "arcane", tip = "Arcane Wrath spends the build-up; when Arcane Missiles come free, cast them at once.",
		single = { { "Bolt", "two or three times" }, { "Filler", "to spend the build-up" }, { "Missiles", "when they come free" },
			{ "Fire Blast", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Shield", "if it's hitting you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Evocation", "out of mana" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Cone", "as they break free" }, { "Flamestrike", "as they come in" }, { "Blink", "to get away" } } },
	{ from = 30, build = "arcane", tip = "Presence of Mind makes your next spell instant: finish a fight with it, or when one gets too close.",
		single = { { "Bolt", "two or three times" }, { "Filler", "to spend the build-up" }, { "Missiles", "when they come free" },
			{ "Presence of Mind", "for an instant finish" }, { "Fire Blast", "to finish it" }, { "Frost Nova", "when it reaches you" },
			{ "Shield", "if it's hitting you" }, { "Blink", "to get away" }, { "Stop", "when it casts" },
			{ "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Cone", "as they break free" }, { "Flamestrike", "as they come in" }, { "Blink", "to get away" } } },
	{ from = 40, build = "arcane", tip = "Save Arcane Power for a hard fight; it burns mana fast, so have your mana gem ready.",
		single = { { "Arcane Power", "for a hard fight" }, { "Bolt", "two or three times" }, { "Filler", "to spend the build-up" },
			{ "Missiles", "when they come free" }, { "Presence of Mind", "for an instant finish" }, { "Fire Blast", "to finish it" },
			{ "Frost Nova", "when it reaches you" }, { "Blink", "to get away" }, { "Stop", "when it casts" },
			{ "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Cone", "as they break free" }, { "Arcane Power", "for a big pull" }, { "Flamestrike", "as they come in" },
			{ "Blink", "to get away" } } },
	{ from = 50, build = "arcane", tip = "Your mana sets the pace: keep a gem and Evocation for long fights, and Polymorph the extra one first.",
		single = { { "Arcane Power", "for a hard fight" }, { "Bolt", "two or three times" }, { "Filler", "to spend the build-up" },
			{ "Missiles", "when they come free" }, { "Presence of Mind", "for an instant finish" }, { "Fire Blast", "to finish it" },
			{ "Frost Nova", "when it reaches you" }, { "Blink", "to get away" }, { "Stop", "when it casts" },
			{ "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" }, { "Area", "while they're frozen" },
			{ "Cone", "as they break free" }, { "Arcane Power", "for a big pull" }, { "Flamestrike", "as they come in" },
			{ "Blink", "to get away" } } },

	-- Fire: Pyroblast from range, Fire Blast to speed up the next one, nothing that slows.
	{ from = 20, build = "fire", tip = "Open with Pyroblast from far off, then Fireball; each Fire Blast that hits makes your next Pyroblast quicker.",
		single = { { "Filler", "to open" }, { "Fire Blast", "when it's ready" }, { "Bolt" },
			{ "Scorch", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Shield", "if it's hitting you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Evocation", "out of mana" }, { "Wand", "to save mana" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Flamestrike", "as they come in" }, { "Frost Nova", "when they reach you" },
			{ "Area", "while they're frozen" }, { "Blink", "to get away" } } },
	{ from = 30, build = "fire", tip = "Blast Wave throws back and slows everything around you: your answer when two of them reach you.",
		single = { { "Filler", "to open" }, { "Fire Blast", "when it's ready" }, { "Bolt" },
			{ "Scorch", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Blast Wave", "if it's on you" },
			{ "Shield", "if it's hitting you" }, { "Blink", "to get away" }, { "Stop", "when it casts" },
			{ "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Flamestrike", "as they come in" }, { "Blast Wave", "when they reach you" },
			{ "Frost Nova", "to hold them" }, { "Area", "while they're held" }, { "Blink", "to get away" } } },
	{ from = 40, build = "fire", tip = "Combustion makes your next fire spells hit hard: save it for a tough fight, and keep Nova and Blink ready.",
		single = { { "Combustion", "for a hard fight" }, { "Filler", "to open" }, { "Fire Blast", "when it's ready" }, { "Bolt" },
			{ "Scorch", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Blast Wave", "if it's on you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Mana Gem", "low on mana" },
			{ "Evocation", "gem spent, still low" } },
		cleave = { { "Polymorph", "on the extra one" }, { "Flamestrike", "as they come in" }, { "Blast Wave", "when they reach you" },
			{ "Frost Nova", "to hold them" }, { "Area", "while they're held" }, { "Combustion", "for a big pull" },
			{ "Blink", "to get away" } } },
	{ from = 50, build = "fire", tip = "Pull two or three: Flamestrike as they come, Blast Wave and Nova when they arrive, then Arcane Explosion.",
		single = { { "Combustion", "for a hard fight" }, { "Filler", "to open" }, { "Fire Blast", "when it's ready" }, { "Bolt" },
			{ "Scorch", "to finish it" }, { "Frost Nova", "when it reaches you" }, { "Blast Wave", "if it's on you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Mana Gem", "low on mana" },
			{ "Evocation", "gem spent, still low" } },
		cleave = { { "Flamestrike", "as they come in" }, { "Blast Wave", "when they reach you" }, { "Frost Nova", "to hold them" },
			{ "Area", "while they're held" }, { "Combustion", "for a big pull" }, { "Polymorph", "on the extra one" },
			{ "Blink", "to get away" } } },

	-- Frost AoE: gather a pack, freeze it and bring Blizzard down on it.
	{ from = 20, build = "frostaoe", tip = "Gather a few, Frost Nova them, step back and bring Blizzard down; keep pulls small until your Blizzard slows.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Fire Blast", "to finish it" },
			{ "Filler", "mana to spare" }, { "Shield", "if it's hitting you" }, { "Blink", "to get away" },
			{ "Stop", "when it casts" }, { "Evocation", "out of mana" }, { "Wand", "to save mana" } },
		cleave = { { "Bolt", "to pull them" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Area", "if they're on you" }, { "Blink", "to get away" }, { "Polymorph", "on one that stays back" } } },
	-- (Cone of Cold is on Q from here: the build's second sweep, every pull)
	{ from = 26, build = "frostaoe", tip = "Cone of Cold is your second sweep: Nova them, Blizzard, then Cone as they break free.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Filler", "as it breaks free" },
			{ "Fire Blast", "to finish it" }, { "Shield", "if it's hitting you" }, { "Blink", "to get away" },
			{ "Stop", "when it casts" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" }, { "Wand", "to save mana" } },
		cleave = { { "Bolt", "to pull them" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Filler", "as they break free" }, { "Area", "if they're on you" }, { "Blink", "to get away" },
			{ "Polymorph", "on one that stays back" } } },
	{ from = 30, build = "frostaoe", tip = "Pull three or four now: Nova them, Blizzard, Cone of Cold as they break free, and Ice Block if it goes wrong.",
		single = { { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" }, { "Ice Lance", "while it's frozen" },
			{ "Filler", "as it breaks free" }, { "Fire Blast", "if it isn't frozen" }, { "Shield", "if it's hitting you" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Bolt", "to pull them" }, { "Frost Nova", "when they reach you" }, { "Blizzard", "while they're frozen" },
			{ "Filler", "as they break free" }, { "Area", "if they're on you" }, { "Flamestrike", "as they bunch up" },
			{ "Cold Snap", "for a second Nova" }, { "Blink", "to get away" }, { "Wall", "if it goes badly" },
			{ "Polymorph", "on one that stays back" } } },
	{ from = 40, build = "frostaoe", tip = "Ice Barrier before the pull lets you gather a whole camp; Blizzard twice and Arcane Explosion finish it.",
		single = { { "Shield", "before the pull" }, { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" },
			{ "Ice Lance", "while it's frozen" }, { "Filler", "as it breaks free" }, { "Fire Blast", "if it isn't frozen" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Shield", "before the pull" }, { "Bolt", "to pull them" }, { "Frost Nova", "when they reach you" },
			{ "Blizzard", "while they're frozen" }, { "Filler", "as they break free" }, { "Area", "if they're on you" },
			{ "Flamestrike", "as they bunch up" }, { "Cold Snap", "for a second Nova" }, { "Blink", "to get away" },
			{ "Wall", "if it goes badly" }, { "Polymorph", "on one that stays back" } } },
	{ from = 50, build = "frostaoe", tip = "Big pulls are your way now: Barrier, gather, Nova, Blizzard, and Flamestrike as they bunch up.",
		single = { { "Shield", "before the pull" }, { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" },
			{ "Ice Lance", "while it's frozen" }, { "Filler", "as it breaks free" }, { "Fire Blast", "if it isn't frozen" },
			{ "Blink", "to get away" }, { "Stop", "when it casts" }, { "Mana Gem", "low on mana" }, { "Evocation", "gem spent, still low" } },
		cleave = { { "Shield", "before the pull" }, { "Bolt", "to pull them" }, { "Frost Nova", "when they reach you" },
			{ "Blizzard", "while they're frozen" }, { "Flamestrike", "as they bunch up" }, { "Filler", "as they break free" },
			{ "Area", "if they're on you" }, { "Cold Snap", "for a second Nova" }, { "Blink", "to get away" },
			{ "Wall", "if it goes badly" }, { "Polymorph", "on one that stays back" } } },

	-- Frost PvP: Frost's way, and from Missile Barrage your bolts free up Arcane Missiles.
	{ from = 50, build = "frostpvp", tip = "Keep them slowed and frozen; when Arcane Missiles come free, cast them at once.",
		single = { { "Shield", "before the pull" }, { "Bolt", "to open" }, { "Frost Nova", "when it reaches you" },
			{ "Filler", "while it's frozen" }, { "Missiles", "when they come free" }, { "Area", "to finish it" },
			{ "Fire Blast", "if it isn't frozen" }, { "Cold Snap", "for a second Nova" }, { "Wall", "if it goes badly" },
			{ "Stop", "when it casts" }, { "Blink", "to get away" }, { "Mana Gem", "low on mana" },
			{ "Evocation", "gem spent, still low" } },
		cleave = { { "Shield", "before the pull" }, { "Polymorph", "on the extra one" }, { "Frost Nova", "when they reach you" },
			{ "Blizzard", "while they're frozen" }, { "Area", "as they break free" }, { "Cold Snap", "for a second Nova" },
			{ "Explosion", "if they're on you" }, { "Blink", "to get away" }, { "Wall", "if it goes badly" } } },
}
K.PLAY = PLAY

local OPTS = {
	knows = 133,                             -- Fireball: a mage's from level 1
	list = "/shymage keys list",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isMage then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isMage then
		T:Print("your keys are laid out on a mage only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nThe mana gem's key uses the gem you carry and conjures one when you carry none."
end

-- From login on, a job comes to its key when you learn it, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
