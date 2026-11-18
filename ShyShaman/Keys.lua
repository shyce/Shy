-- A shaman's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the spell by what you
-- have learned, so a spell arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shyshaman keys)
--   ns.Keys.List()    every key and what it does, as text
--
-- A heal or a cure goes to the friend the mouse is on, else the friend you have targeted, else you.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}
ns.Keys = K

local SHOW = "#showtooltip"
local FRIEND, Grows = Shy.Keys.FRIEND, Shy.Keys.Grows

-- The melee builds strike with Stormstrike on R, and Lightning Bolt (their pull, and their Maelstrom bolt) is its
-- kin on Shift + R: until Stormstrike is learned Bolt stands on R in its place.
local STORM = { name = "Stormstrike", what = "Stormstrike", SHOW, "/cast {17364}" }
local BOLT = { name = "Bolt", role = "bolt", what = "Lightning Bolt", SHOW, "/cast {403}" }
-- Restoration has its heals where the attacks are (Chain Heal R, Lesser Healing Wave E, Healing Wave Q, Riptide
-- its kin on Shift + Q), Bolt standing on R until Chain Heal at 40: you quest with your attacks under your fingers
-- and heal from the same keys once you're a healer. Its Flame Shock is on V (on E until the quick heal comes), Searing Totem on T, Healing Stream
-- (dropped every pull) under the thumb, and Mana Tide on B.
local CHAIN_HEAL = { name = "Chain Heal", what = "Chain Heal", SHOW, "/cast " .. FRIEND .. " {1064}" }
local LESSER = { name = "Lesser", what = "Lesser Healing Wave", SHOW, "/cast " .. FRIEND .. " {8004}" }
local WAVE = { name = "Wave", what = "Healing Wave", SHOW, "/cast " .. FRIEND .. " {331}" }
local RIPTIDE = { name = "Riptide", what = "Riptide", SHOW, "/cast " .. FRIEND .. " {408521}" }
-- (Restoration's: on E, the quick heal's key, until that heal is learned at 20; then on V)
local FLAME = { name = "Flame", what = "Flame Shock", early = "E", asdfEarly = "E", SHOW, "/cast {8050}" }
local NOVA = { name = "Fire Nova", what = "Fire Nova: it bursts round your fire totem", SHOW, "/cast {408341}" }
local SEARING = { name = "Searing", what = "Searing Totem", SHOW, "/cast {3599}" }
local STREAM = { name = "Stream", what = "Healing Stream Totem", SHOW, "/cast {5394}" }
local STONECLAW = { name = "Stoneclaw", what = "Stoneclaw Totem", SHOW, "/cast {5730}" }
local TIDE = { name = "Mana Tide", what = "Mana Tide Totem", SHOW, "/cast {16190}" }
local GUARD = { name = "Guard Totem", what = "Grounding Totem; Tremor Totem until 30", SHOW, "/cast [known:{8177}] {8177}; {8143}" }
-- Elemental and Restoration imbue with Flametongue; a tank keeps Rockbiter for the threat it adds.
local TONGUE = { name = "Weapon", what = "Flametongue Weapon; Rockbiter Weapon until you have it", SHOW, "/cast [known:{8024}] {8024}; {8017}" }
local ROCK = { name = "Weapon", what = "Rockbiter Weapon", SHOW, "/cast {8017}" }
-- Windfury Totem takes the place of your own Windfury Weapon: a melee shaman drops Grace of Air once it has it.
local AIR = { name = "Wind Totem", what = "Grace of Air Totem; Windfury Totem until 42", SHOW, "/cast [known:{8835}] {8835}; {8512}" }

local JOBS = {
	-- The fight, under the fingers that are free while you move.
	{ name = "Bolt", role = "bolt", key = "R", asdf = "R", what = "Lightning Bolt",
		SHOW, "/cast {403}", by = { enh = STORM, tank = STORM, pvp = STORM, resto = CHAIN_HEAL } },
	-- The shocks share one cooldown: Flame Shock opens (its burn runs on while you fight), Earth Shock is the stop.
	{ name = "Flame", key = "E", asdf = "E", what = "Flame Shock",
		SHOW, "/cast {8050}", by = { resto = LESSER } },
	-- Fire Nova bursts round your fire totem: the totem on Q, the blast beside it on T, the area attack.
	{ name = "Searing", key = "Q", asdf = "Q", what = "Searing Totem",
		SHOW, "/cast {3599}", by = { resto = WAVE } },
	{ name = "Fire Nova", key = "T", asdf = "T", what = "Fire Nova: it bursts round your fire totem",
		SHOW, "/cast {408341}", by = { resto = SEARING } },
	-- (Earth Shock, the stop, takes F. Your shield is what you stay in: it is on 2, with the slow things. With ASDF
	-- Earthbind goes on C, under the middle finger that is free while you run, and Ghost Wolf on B: a cast you
	-- make standing, or on the run once it is instant.)
	{ name = "Shield", role = "shield", key = "2", asdf = "2", stay = true, what = "Lightning Shield; Water Shield if you have it",
		SHOW, "/cast [known:{408510}] {408510}; {324}" },
	{ name = "Earthbind", key = "G", asdf = "C", what = "Earthbind Totem",
		SHOW, "/cast {2484}" },
	{ name = "Heal", role = "heal", key = "V", asdf = "V", what = "Lesser Healing Wave; Healing Wave until 20",
		SHOW, Grows(8004, 331), by = { resto = FLAME } },
	{ name = "Mana Spring", key = "X", asdf = "X", what = "Mana Spring Totem",
		SHOW, "/cast {5675}" },
	{ name = "Ghost Wolf", key = "C", asdf = "B", what = "Ghost Wolf",
		SHOW, "/cast {2645}" },
	{ name = "Totems", key = "Z", asdf = "Z", what = "Call of the Elements: the totems you set on your totem bar; your earth totem until 20",
		SHOW, "/cast [known:{66842}] {66842}; [known:{8075}] {8075}; {8071}" },
	-- What you stay in, on 1 2 3: your weapon's imbue, your shield, and your totems called back.
	{ name = "Weapon", key = "1", asdf = "1", stay = true, what = "Windfury Weapon; Rockbiter Weapon until 30",
		SHOW, "/cast [known:{8232}] {8232}; {8017}", by = { ele = TONGUE, resto = TONGUE, tank = ROCK } },
	-- The thumb: what you answer with (a healer's Healing Stream). The stop is on F (G with ASDF), beside the index
	-- finger: Earth Shock, the class's one interrupt, which also hits hard and holds a foe's attention. Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Stoneclaw", key = "BUTTON4", asdf = "BUTTON4", what = "Stoneclaw Totem",
		SHOW, "/cast {5730}", by = { resto = STREAM } },
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Earth Shock: it stops a cast too",
		SHOW, "/cast {8042}" },
	-- With Shift: each key's rarer kin. (In this order they stand in on an easy key whose own job waits.)
	{ name = "Purge", key = "SHIFT-F", asdf = "SHIFT-G", stay = true, what = "Purge",
		SHOW, "/cast {370}" },
	{ name = "Frost", key = "SHIFT-E", asdf = "SHIFT-E", what = "Frost Shock",
		SHOW, "/cast {8056}" },
	{ name = "Magma", key = "SHIFT-T", asdf = "SHIFT-T", what = "Magma Totem",
		SHOW, "/cast {8190}", by = { resto = GUARD } },
	{ name = "Chain", key = "SHIFT-R", asdf = "SHIFT-R", what = "Chain Lightning",
		SHOW, "/cast {421}", by = { enh = BOLT, tank = BOLT, pvp = BOLT, resto = BOLT } },
	-- (With ASDF the pinky leaves A for Shift and only the running finger can reach Q: Shift + Q stops you. So the
	-- totem dropped in a hurry, and a healer's Riptide, take Shift + Mouse 4 there, and Healing Stream Shift + Q.)
	{ name = "Guard Totem", key = "SHIFT-Q", asdf = "SHIFT-BUTTON4", what = "Grounding Totem; Tremor Totem until 30",
		SHOW, "/cast [known:{8177}] {8177}; {8143}", by = { resto = RIPTIDE } },
	{ name = "Wave", key = "B", asdf = "W", what = "Healing Wave",
		SHOW, "/cast " .. FRIEND .. " {331}", by = { resto = TIDE } },
	{ name = "Chain Heal", key = "SHIFT-G", asdf = "SHIFT-W", what = "Chain Heal",
		SHOW, "/cast " .. FRIEND .. " {1064}", by = { resto = NOVA } },
	{ name = "Stream", key = "SHIFT-BUTTON4", asdf = "SHIFT-Q", what = "Healing Stream Totem",
		SHOW, "/cast {5394}", by = { resto = STONECLAW } },
	{ name = "Disease", role = "disease", key = "SHIFT-D", asdf = "SHIFT-D", what = "Cure Disease",
		SHOW, "/cast " .. FRIEND .. " {2870}" },
	{ name = "Recall", key = "3", asdf = "3", stay = true, what = "Totemic Recall",
		SHOW, "/cast {36936}" },
	-- Mouse 5, never hurried: your totems brought along between fights, and the air totem for a group.
	{ name = "Totemic Call", key = "BUTTON5", asdf = "BUTTON5", what = "Totemic Call: your totems come to you",
		SHOW, "/cast {437009}" },
	{ name = "Wind Totem", key = "SHIFT-BUTTON5", asdf = "SHIFT-BUTTON5", what = "Windfury Totem; Grace of Air Totem if that is the one you have",
		SHOW, "/cast [known:{8512}] {8512}; {8835}", by = { enh = AIR, tank = AIR, pvp = AIR } },
	-- The number row: your big cooldown, and a friend's care.
	{ name = "Burst", role = "burst", key = "4", asdf = "4", spare = "MULTIACTIONBAR4BUTTON4",
		what = "Your talent's cooldown: Lightning Mastery, Rage of the Farseer or Nature's Swiftness",
		SHOW, "/cast [known:{16166}] {16166}; [known:{425336}] {425336}; {16188}" },
	{ name = "Raise", role = "raise", key = "5", asdf = "5", stay = true, spare = "MULTIACTIONBAR4BUTTON5",
		what = "Ancestral Spirit on a dead friend, else Cure Poison",
		SHOW, "/cast [@mouseover,help,dead][help,dead] {2008}; " .. FRIEND .. " {526}" },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use.
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })
-- What you press now and then, on Shift + 6 to =: the most useful first.
Shy.Keys.Utility(JOBS, {
	{ name = "Astral Recall", spells = { 556 } },
	{ name = "Water Walking", spells = { 546 } },
	{ name = "Water Breathing", spells = { 131 } },
	{ name = "Tremor Totem", spells = { 8143 } },
	{ name = "Poison Cleansing", what = "Poison Cleansing Totem", spells = { 8166 } },
	{ name = "Disease Totem", what = "Disease Cleansing Totem", spells = { 8170 } },
	{ name = "Far Sight", spells = { 6196 } },
})
K.JOBS = JOBS

-- How to play, by level and build: what you press on one enemy and on a few, in order (each step a job above).
local PLAY = {
	{ from = 1, tip = "Pull with Lightning Bolt, then fight in melee and hit them with Earth Shock as they close in.",
		single = { { "Bolt", "to open" }, { "Stop" }, { "Heal", "under half health" } },
		cleave = { { "Bolt", "to open" }, { "Stop" }, { "Earthbind", "to slow the rest" }, { "Heal", "under half health" } } },
	{ from = 10, tip = "Drop Searing Totem before you pull, open with Flame Shock and finish with Earth Shock.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Searing", "before the pull" }, { "Fire Nova", "near your totem" }, { "Flame" },
			{ "Stoneclaw", "when two hit you" }, { "Stop" } } },
	{ from = 20, tip = "Put a totem of each element on your totem bar, then call them all before a pack; run in Ghost Wolf.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Fire Nova", "near your totem" }, { "Flame" },
			{ "Frost", "to slow a runner" }, { "Stoneclaw", "when two hit you" } } },
	{ from = 30, tip = "Magma Totem and Fire Nova clear a pack; recall your totems after it for the mana.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Magma", "on 3+ enemies" }, { "Fire Nova", "near your totem" },
			{ "Chain" }, { "Stoneclaw", "when two hit you" }, { "Recall", "after the fight" } } },
	{ from = 40, tip = "Chain Lightning starts a pack fight; save your mana for a heal when it goes long.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Chain", "to open" }, { "Magma", "on 3+ enemies" },
			{ "Fire Nova", "near your totem" }, { "Stoneclaw", "when two hit you" }, { "Recall", "after the fight" } } },
	{ from = 50, tip = "Fights are short when your totems are down first; drink between packs, not in them.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Chain", "to open" }, { "Magma", "on 3+ enemies" },
			{ "Fire Nova", "near your totem" }, { "Stoneclaw", "when two hit you" }, { "Recall", "after the fight" } } },

	-- Enhancement: a two-hander, Stormstrike from 25, Windfury from 30, Maelstrom's quick Lightning Bolt from 35. The
	-- shocks share a cooldown: Earth Shock after Stormstrike, Flame Shock on a foe that lives long enough to burn.
	{ from = 25, build = "enh", tip = "Stormstrike, then Earth Shock while its mark is on them: that's most of your damage.",
		single = { { "Searing", "before the pull" }, { "Stormstrike" }, { "Stop", "after Stormstrike" }, { "Flame", "on one that lives" },
			{ "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Fire Nova", "near your totem" }, { "Stormstrike" }, { "Stop" },
			{ "Stoneclaw", "when two hit you" } } },
	{ from = 30, build = "enh", tip = "Windfury on your weapon now: keep it on, and let Stormstrike and Earth Shock do the rest.",
		single = { { "Weapon", "keep it up" }, { "Searing", "before the pull" }, { "Stormstrike" }, { "Stop", "after Stormstrike" },
			{ "Flame", "on one that lives" }, { "Shield", "keep it up" }, { "Heal", "under half health" }, { "Wave", "between fights" } },
		cleave = { { "Totems", "before the pull" }, { "Magma", "on 3+ enemies" }, { "Fire Nova", "near your totem" },
			{ "Stormstrike" }, { "Stop" } } },
	{ from = 40, build = "enh", tip = "Save Rage of the Farseer for a hard fight; at five Maelstrom stacks your Lightning Bolt is quick and cheap.",
		single = { { "Searing", "before the pull" }, { "Burst", "on a hard fight" }, { "Stormstrike" }, { "Stop", "after Stormstrike" }, { "Bolt", "at 5 Maelstrom stacks" },
			{ "Flame", "on one that lives" }, { "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Burst", "on 3+ enemies" }, { "Magma", "on 3+ enemies" },
			{ "Fire Nova", "near your totem" }, { "Stormstrike" }, { "Bolt", "at 5 Maelstrom stacks" } } },
	{ from = 50, build = "enh", tip = "You can take two at once now; pull the second only with your totems down.",
		single = { { "Searing", "before the pull" }, { "Burst", "on a hard fight" }, { "Stormstrike" }, { "Stop", "after Stormstrike" }, { "Bolt", "at 5 Maelstrom stacks" },
			{ "Flame", "on one that lives" }, { "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Burst", "on 3+ enemies" }, { "Magma", "on 3+ enemies" },
			{ "Fire Nova", "near your totem" }, { "Stormstrike" }, { "Bolt", "at 5 Maelstrom stacks" } } },

	-- Elemental: Lightning Bolt from range, Earthbind to hold them off, Chain Lightning from 32. Searing Totem shoots
	-- from range; Magma Totem only burns what stands by it.
	{ from = 20, build = "ele", tip = "Earthbind roots them now: drop it as they reach you and step back to keep casting.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Earthbind", "when they reach you" },
			{ "Stop", "to finish" }, { "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Earthbind", "when they reach you" }, { "Fire Nova", "near your totem" },
			{ "Bolt" }, { "Frost", "to slow a runner" } } },
	{ from = 30, build = "ele", tip = "Your crits hit hard now; Chain Lightning and Magma Totem make packs worth pulling.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Earthbind", "when they reach you" },
			{ "Stop", "to finish" }, { "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Chain", "to open" }, { "Magma", "on 3+ enemies" },
			{ "Earthbind", "when they reach you" }, { "Fire Nova", "near your totem" }, { "Bolt" } } },
	{ from = 40, build = "ele", tip = "Lightning Mastery makes Chain Lightning free to repeat: save it for packs.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Earthbind", "when they reach you" },
			{ "Stop", "to finish" }, { "Burst", "on a hard fight" }, { "Shield", "keep it up" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Burst", "on 3+ enemies" }, { "Chain", "to open" },
			{ "Magma", "on 3+ enemies" }, { "Earthbind", "when they reach you" }, { "Fire Nova", "near your totem" } } },
	{ from = 51, build = "ele", tip = "Water Shield keeps your mana up; you can chain pulls if your totems keep up.",
		single = { { "Shield", "keep it up" }, { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" },
			{ "Earthbind", "when they reach you" }, { "Stop", "to finish" }, { "Burst", "on a hard fight" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the pull" }, { "Burst", "on 3+ enemies" }, { "Chain", "to open" },
			{ "Magma", "on 3+ enemies" }, { "Earthbind", "when they reach you" }, { "Fire Nova", "near your totem" } } },

	-- Restoration: you quest with your attacks and a totem, and heal from the same keys once the heals come.
	{ from = 1, build = "resto", tip = "Pull with Lightning Bolt, Earth Shock as they close, and heal yourself when low.",
		single = { { "Bolt", "to open" }, { "Stop" }, { "Wave", "under half health" } },
		cleave = { { "Bolt", "to open" }, { "Stop" }, { "Earthbind", "to slow the rest" }, { "Wave", "under half health" } } },
	{ from = 10, build = "resto", tip = "You kill slowly alone: let Searing Totem do the work and keep Flame Shock on.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Stop", "to finish" },
			{ "Shield", "keep it up" }, { "Wave", "under half health" } },
		cleave = { { "Searing", "before the pull" }, { "Fire Nova", "near your totem" }, { "Flame" },
			{ "Stoneclaw", "when two hit you" }, { "Wave", "under half health" } } },
	{ from = 20, build = "resto", tip = "In a dungeon, keep Water Shield up and use the fast heal only when it's urgent.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Shield", "keep it up" },
			{ "Wave", "under half health" }, { "Lesser", "when it's urgent" } },
		cleave = { { "Totems", "before the pull" }, { "Stream", "when many are hurt" }, { "Wave", "on the tank" },
			{ "Lesser", "when it's urgent" }, { "Mana Tide", "when you run low" } } },
	{ from = 30, build = "resto", tip = "Nature's Swiftness makes your next heal instant: keep it for someone about to die.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Shield", "keep it up" },
			{ "Wave", "under half health" }, { "Burst", "when you're about to die" } },
		cleave = { { "Totems", "before the pull" }, { "Stream", "when many are hurt" }, { "Wave", "on the tank" },
			{ "Lesser", "when it's urgent" }, { "Burst", "when someone's about to die" }, { "Mana Tide", "when you run low" } } },
	{ from = 40, build = "resto", tip = "Riptide on the tank and Chain Heal when several are hurt: that's your whole pull.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Shield", "keep it up" },
			{ "Riptide", "under half health" }, { "Wave", "if still low" } },
		cleave = { { "Totems", "before the pull" }, { "Riptide", "keep it on the tank" }, { "Chain Heal", "when 3+ are hurt" },
			{ "Wave", "on the tank" }, { "Lesser", "when it's urgent" }, { "Burst", "when someone's about to die" },
			{ "Mana Tide", "when you run low" } } },
	{ from = 50, build = "resto", tip = "Chain Heal off a target with Riptide on heals the most; drink between pulls.",
		single = { { "Searing", "before the pull" }, { "Flame", "to open" }, { "Bolt" }, { "Shield", "keep it up" },
			{ "Riptide", "under half health" }, { "Wave", "if still low" } },
		cleave = { { "Totems", "before the pull" }, { "Riptide", "keep it on the tank" }, { "Chain Heal", "when 3+ are hurt" },
			{ "Wave", "on the tank" }, { "Lesser", "when it's urgent" }, { "Burst", "when someone's about to die" },
			{ "Mana Tide", "when you run low" } } },

	-- Enhancement tank: Rockbiter and Earth Shock (its threat is high) hold them, Fire Nova and Magma Totem a pack.
	{ from = 20, build = "tank", tip = "Rockbiter and Earth Shock hold their attention; wear a shield and keep Lightning Shield up.",
		single = { { "Weapon", "keep it up" }, { "Totems", "before the pull" }, { "Stop", "to hold its attention" },
			{ "Stormstrike" }, { "Flame", "on one that lives" }, { "Shield", "keep it up" } },
		cleave = { { "Totems", "before the pull" }, { "Stoneclaw", "to pull them to you" }, { "Fire Nova", "near your totem" },
			{ "Stop", "on the one that strays" }, { "Stormstrike" } } },
	{ from = 30, build = "tank", tip = "Magma Totem under the pack and Fire Nova hold a group; Earth Shock the one that runs.",
		single = { { "Weapon", "keep it up" }, { "Totems", "before the pull" }, { "Stop", "to hold its attention" },
			{ "Stormstrike" }, { "Flame", "on one that lives" }, { "Shield", "keep it up" } },
		cleave = { { "Totems", "before the pull" }, { "Magma", "on 3+ enemies" }, { "Fire Nova", "near your totem" },
			{ "Stoneclaw", "to pull them to you" }, { "Stop", "on the one that strays" }, { "Stormstrike" } } },
	{ from = 43, build = "tank", tip = "Rage of the Farseer helps a long pull; mark targets and pull small packs.",
		single = { { "Weapon", "keep it up" }, { "Totems", "before the pull" }, { "Stop", "to hold its attention" },
			{ "Stormstrike" }, { "Flame", "on one that lives" }, { "Burst", "on a hard fight" }, { "Shield", "keep it up" } },
		cleave = { { "Totems", "before the pull" }, { "Magma", "on 3+ enemies" }, { "Fire Nova", "near your totem" },
			{ "Stoneclaw", "to pull them to you" }, { "Burst", "on a big pull" }, { "Stop", "on the one that strays" } } },
	{ from = 50, build = "tank", tip = "Pull with Lightning Bolt to bring them to your totems, then hold them there.",
		single = { { "Bolt", "to pull" }, { "Stop", "to hold its attention" }, { "Stormstrike" }, { "Flame", "on one that lives" },
			{ "Burst", "on a hard fight" }, { "Shield", "keep it up" } },
		cleave = { { "Totems", "before the pull" }, { "Magma", "on 3+ enemies" }, { "Fire Nova", "near your totem" },
			{ "Stoneclaw", "to pull them to you" }, { "Burst", "on a big pull" }, { "Stop", "on the one that strays" } } },

	-- Enhancement PvP: instant Ghost Wolf to close in, Stormstrike, Earth Shock on their casts, Purge.
	{ from = 25, build = "pvp", tip = "Close in with Ghost Wolf, Stormstrike, and Frost Shock anyone who runs.",
		single = { { "Ghost Wolf", "to close in" }, { "Stormstrike" }, { "Stop", "when they cast" }, { "Frost", "when they run" },
			{ "Purge", "on their buffs" }, { "Heal", "under half health" } },
		cleave = { { "Totems", "before the fight" }, { "Fire Nova", "near your totem" }, { "Stormstrike" }, { "Guard Totem", "when they fear you" },
			{ "Frost", "when they run" } } },
	{ from = 30, build = "pvp", tip = "Windfury on your weapon wins fights in a few swings; Grounding Totem eats a spell.",
		single = { { "Weapon", "keep it up" }, { "Ghost Wolf", "to close in" }, { "Stormstrike" }, { "Stop", "when they cast" },
			{ "Frost", "when they run" }, { "Purge", "on their buffs" } },
		cleave = { { "Totems", "before the fight" }, { "Guard Totem", "on a caster" }, { "Fire Nova", "near your totem" },
			{ "Stormstrike" }, { "Frost", "when they run" } } },
	{ from = 40, build = "pvp", tip = "Rage of the Farseer and Stormstrike together end a fight before they can heal.",
		single = { { "Ghost Wolf", "to close in" }, { "Burst", "when they're low" }, { "Stormstrike" }, { "Stop", "when they cast" },
			{ "Bolt", "at 5 Maelstrom stacks" }, { "Frost", "when they run" }, { "Purge", "on their buffs" } },
		cleave = { { "Totems", "before the fight" }, { "Guard Totem", "on a caster" }, { "Fire Nova", "near your totem" },
			{ "Stormstrike" }, { "Burst", "when they're low" }, { "Frost", "when they run" } } },
	{ from = 50, build = "pvp", tip = "Purge their shields and buffs first; your shocks hit even harder now.",
		single = { { "Ghost Wolf", "to close in" }, { "Purge", "on their buffs" }, { "Burst", "when they're low" }, { "Stormstrike" },
			{ "Stop", "when they cast" }, { "Bolt", "at 5 Maelstrom stacks" }, { "Frost", "when they run" } },
		cleave = { { "Totems", "before the fight" }, { "Guard Totem", "on a caster" }, { "Fire Nova", "near your totem" },
			{ "Stormstrike" }, { "Burst", "when they're low" }, { "Frost", "when they run" } } },
}
K.PLAY = PLAY

local OPTS = {
	knows = 403,                             -- Lightning Bolt: a shaman's from level 1
	list = "/shyshaman keys list",
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isShaman then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run()
	if not ns.isShaman then
		T:Print("your keys are laid out on a shaman only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA heal or a cure goes to the friend the mouse is on, else the friend you have targeted, else you."
end

-- From login on, a job comes to its key when you learn it, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
