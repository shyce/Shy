-- A druid's keys (Shy.Keys lays them out): one job a key, each a macro that chooses the ability by the form
-- you are in and by what you have learned, so an ability arrives on its key as you train it.
--
--   ns.Keys.Run()     lays them out and says what was done (/shy druid keys)
--   ns.Keys.Run("force")  every key, even ones you kept or moved (/shy druid keys force)
--   ns.Keys.List()    every key and what it does, as text
--
-- A form is asked for by its spell ("[stance:{768}]"), written as its place on your own stance bar: the right
-- form whichever you have trained, Dire Bear Form where Bear Form was.
-- A heal goes to the friend the mouse is on, else the friend you have targeted, else you.
-- Each job names its key for WASD (key) and for ASDF (asdf): F and G move to G and W there, Shift + F and G to
-- Shift + G and W, and the rest stay where they are.
--
-- PLAY is how to fight at each level, by build (Shy.Keys draws it): each step a job, in the order you press them.

local ADDON, ns = ...
local T = ns.T

-- Without ShyKeys there is nothing to lay keys out: this class's keys, macros and buttons are left as they are.
if not Shy.Keys then return end

local K = {}

-- Your forms, each a list: the first of it you have is the one to fight in (OPTS.keep), and the one on 1 2 3.
local CAT_FORM = { 768 }   -- Cat Form
local BEAR_FORM = { 9634, 5487 }   -- Dire Bear Form, Bear Form
local MOONKIN_FORM = { 24858 }   -- Moonkin Form
local TRAVEL_FORM = { 783 }   -- Travel Form
ns.Keys = K

local SHOW = "#showtooltip"
local FRIEND, Grows = Shy.Keys.FRIEND, Shy.Keys.Grows
-- A key means one thing in each form: the strike on R (Wrath, Maul, Claw), the heavy hit on E, what you keep up
-- on Q, the bear's area and the cat's finisher on T. Where a form has nothing for a key it casts nothing there
-- ("[stance:...] ;"), so a key never shifts you out of a form by casting a caster's spell.
local BEAR, CAT_STANCE = "[stance:{9634|5487}]", "[stance:{768}]"
local MARK_FORMS = "/cast " .. BEAR .. " {99}; [stance:{768},known:{1822}] {1822}; " .. CAT_STANCE .. " ; "

-- Restoration heals first: out of a form its three heals stand where the others' three attacks do (Rejuvenation
-- on Q, Healing Touch on R, Regrowth on E), the attacks where the heals were; a bear's keys are everyone's.
local RENEW = { name = "Renew", role = "renew", what = "Rejuvenation. Demoralizing Roar as a bear, Rake as a cat",
	SHOW, MARK_FORMS .. FRIEND .. " {774}" }
-- (Wrath until Regrowth comes at 12: before then Wrath is your strike, on R like every druid's.)
local BIG = { name = "Big Heal", what = "Healing Touch, Wrath until 12. Maul as a bear, Claw as a cat",
	SHOW, "/cast " .. BEAR .. " {6807}; " .. CAT_STANCE .. " {1082}; [known:{8936},@mouseover,help,nodead][known:{8936},help,nodead][known:{8936},@player] {5185}; {5176}" }
-- (Regrowth has no bear clause: pressed as a bear it shifts you out and heals.)
local HEAL = { name = "Heal", role = "heal", what = "Regrowth, Healing Touch until 12. As a bear it shifts you out to heal",
	SHOW, Grows(8936, 5185) }
local MARK = { name = "Mark", what = "Moonfire. Swipe as a bear, Ferocious Bite as a cat",
	SHOW, "/cast " .. BEAR .. " {779}; [stance:{768},known:{1328618}] {1328618}; " .. CAT_STANCE .. " {1079}; {8921}" }
local WRATH = { name = "Wrath", what = "Wrath", SHOW, "/cast {5176}" }
local WILD_GROWTH = { name = "Wild Growth", what = "Wild Growth", SHOW, "/cast " .. FRIEND .. " {408120}" }
-- Balance: Hurricane is its area, on T; Insect Swarm its second damage over time, on G (Faerie Fire is on Shift + Q).
local HURRICANE = { name = "Hurricane", what = "Hurricane", SHOW, "/cast " .. BEAR .. " ; " .. CAT_STANCE .. " ; {16914}" }
local SWARM = { name = "Insect Swarm", what = "Insect Swarm", SHOW, "/cast " .. BEAR .. " ; " .. CAT_STANCE .. " ; {5570}" }
-- A build that never fights as a cat has no Cower on its B: Nature's Grasp alone, once Barkskin has Mouse 4.
local GRASP = { name = "Escape", role = "escape", what = "Nature's Grasp once Barkskin has Mouse 4 (44)", SHOW, "/cast [known:{22812}] {16689}" }

local JOBS = {
	-- The fight, under the fingers that are free while you move. The strike is R's in every form, from level 1.
	-- From Prowl a cat's R Pounces and its E Ravages, as a rogue's attack keys open from Stealth.
	{ name = "Strike", role = "strike", key = "R", asdf = "R", what = "Wrath. Maul as a bear, Claw as a cat (Pounce from Prowl)",
		SHOW, "/cast [stance:{768},stealth,known:{9005}] {9005}; " .. BEAR .. " {6807}; " .. CAT_STANCE .. " {1082}; {5176}",
		by = { resto = BIG } },
	{ name = "Heavy", key = "E", asdf = "E", what = "Starfire. Lacerate as a bear, Shred as a cat (Ravage from Prowl)",
		SHOW, "/cast [stance:{768},stealth,known:{6785}] {6785}; " .. CAT_STANCE .. " {5221}; [stance:{9634|5487},known:{1328617}] {1328617}; "
			.. BEAR .. " ; [known:{2912}] {2912}", by = { resto = HEAL } },
	{ name = "Mark", key = "Q", asdf = "Q", what = "Moonfire. Demoralizing Roar as a bear, Rake as a cat",
		SHOW, MARK_FORMS .. "{8921}", by = { resto = RENEW } },
	-- The bear's area and the cat's finisher; a cat's Rip waits here until Ferocious Bite comes at 24.
	{ name = "Tear", key = "T", asdf = "T", what = "Swipe as a bear. Ferocious Bite as a cat, Rip until 24",
		SHOW, "/cast " .. BEAR .. " {779}; [stance:{768},known:{1328618}] {1328618}; " .. CAT_STANCE .. " {1079}",
		by = { resto = MARK, balance = HURRICANE } },
	{ name = "Gore", key = "G", asdf = "W", what = "Rip as a cat, once Ferocious Bite has T. Primal Bite as a bear",
		SHOW, "/cast [stance:{768},known:{1328618}] {1079}; [stance:{9634|5487},known:{407995}] {407995}",
		by = { resto = WILD_GROWTH, balance = SWARM } },
	-- (Prowl: a cat presses it before every pull, so it stands on an easy key.) A bear's Growl goes to what the
	-- mouse is on first, as a tank picks up what breaks off.
	{ name = "Hold", key = "Z", asdf = "Z", what = "Entangling Roots. Growl as a bear (what's under your mouse, or your target), Prowl as a cat",
		SHOW, "/cast " .. CAT_STANCE .. " {5215}; [stance:{9634|5487},@mouseover,harm,nodead]" .. BEAR .. " {6795}; {339}" },
	{ name = "Heal", role = "heal", key = "V", asdf = "V", what = "Regrowth, Healing Touch until 12. In a form it shifts you out to heal",
		SHOW, Grows(8936, 5185), by = { resto = WRATH } },
	-- What you pull with: Enrage as a bear, Tiger's Fury as a cat (free, so pressed every pull), Innervate out of form.
	{ name = "Vigor", key = "X", asdf = "X", what = "Innervate. Enrage as a bear, Tiger's Fury as a cat",
		SHOW, "/cast " .. BEAR .. " {5229}; [stance:{768},known:{5217}] {5217}; " .. CAT_STANCE .. " ; [known:{29166}] {29166}" },
	-- Feral Charge's leap behind your target as a cat in a fight, once you have it; Dash otherwise.
	{ name = "Move", key = "C", asdf = "C", what = "Travel Form, Aquatic Form in water. Feral Charge as a bear. Dash as a cat (its leap in a fight once you have it)",
		SHOW, "/cast [stance:{768},combat,known:{1238122}] {1238122}; " .. CAT_STANCE .. " {1850}; [stance:{9634|5487},known:{1238122}] {1238122}; "
			.. BEAR .. " ; [swimming] {1066}; {783}" },
	{ name = "Wild", key = "SHIFT-4", asdf = "SHIFT-4", stay = true, what = "Mark of the Wild",
		SHOW, "/cast " .. FRIEND .. " {1126}" },
	{ name = "Thorns", key = "SHIFT-5", asdf = "SHIFT-5", stay = true, what = "Thorns",
		SHOW, "/cast " .. FRIEND .. " {467}" },
	-- The thumb: what you answer with. The stop is on F (G with ASDF), beside the index finger: Mouse 5 is
	-- too far to reach in a hurry, so it keeps only what is never hurried.
	{ name = "Guard", key = "BUTTON4", asdf = "BUTTON4", what = "Barkskin (Nature's Grasp until 44). Frenzied Regeneration as a bear from 36",
		SHOW, "/cast [stance:{9634|5487},known:{22842}] {22842}; [known:{22812}] {22812}; {16689}" },
	-- A cat has no stop of its own: its F turns it into a bear, and F again Bashes.
	{ name = "Stop", role = "stop", key = "F", asdf = "G", what = "Hibernate. Bash as a bear. As a cat it makes you a bear, so press it twice",
		SHOW, "/cast [stance:{768},known:{9634}] {9634}; " .. CAT_STANCE .. " {5487}; " .. BEAR .. " {5211}; {2637}" },
	{ name = "Swiftness", key = "SHIFT-BUTTON4", asdf = "SHIFT-BUTTON4", stay = true, what = "Nature's Swiftness",
		SHOW, "/cast {17116}" },
	{ name = "Tranquility", key = "SHIFT-BUTTON5", asdf = "SHIFT-BUTTON5", stay = true, what = "Tranquility",
		SHOW, "/cast {740}", by = { cat = false, bear = false, feralpvp = false, balance = false } },
	-- (A slip with this one turns every mob in reach on you: it never stands in on an easy key.)
	{ name = "Roar", key = "BUTTON5", asdf = "BUTTON5", stay = true, what = "Challenging Roar",
		SHOW, "/cast {5209}", by = { balance = false, resto = false, cat = false, feralpvp = false } },   -- (a tank's)
	-- The number row.
	{ name = "Raise", role = "raise", key = "5", asdf = "5", stay = true, spare = "MULTIACTIONBAR4BUTTON5", what = "Revive, or Rebirth in a fight, on the dead friend under your mouse or your target, or the one you click next",
		"#showtooltip {20484}", "/cast [combat,@mouseover,help,dead][combat,help,dead][combat,@none] {20484}; " .. Shy.Keys.DEAD .. " {437138}" },
	-- With Shift: each key's rarer kin. A heal you cast between fights never stands in on an easy key: pressed in a
	-- form it would shift you out.
	{ name = "Faerie Fire", key = "SHIFT-Q", asdf = "SHIFT-Q", stay = true, what = "Faerie Fire (in any form)",
		SHOW, "/cast {770}" },
	{ name = "Shifting Power", key = "SHIFT-E", asdf = "SHIFT-E", what = "Shifting Power: Energy for a cat",
		SHOW, "/cast {1322605}" },
	-- Restoration's Swiftmend stands on the key Wild Growth comes to at 40, and goes home then.
	{ name = "Swiftmend", key = "SHIFT-R", asdf = "SHIFT-R", early = "G", asdfEarly = "W", stay = true, what = "Swiftmend",
		SHOW, "/cast " .. FRIEND .. " {18562}" },
	{ name = "Renew", role = "renew", key = "SHIFT-T", asdf = "SHIFT-T", stay = true, what = "Rejuvenation",
		SHOW, "/cast " .. FRIEND .. " {774}", by = { resto = false } },   -- (Restoration's is on Q)
	{ name = "Touch", key = "SHIFT-F", asdf = "SHIFT-G", stay = true, what = "Healing Touch",
		SHOW, "/cast " .. FRIEND .. " {5185}", by = { resto = false } },   -- (Restoration's is on R)
	-- (Remove Curse on the key a mage's is on.)
	{ name = "Uncurse", role = "uncurse", key = "SHIFT-G", asdf = "SHIFT-W", stay = true, what = "Remove Curse",
		SHOW, "/cast " .. FRIEND .. " {2782}" },
	{ name = "Escape", role = "escape", key = "B", asdf = "B", what = "Cower as a cat. Nature's Grasp once Barkskin has Mouse 4 (44)",
		SHOW, "/cast [stance:{768},known:{8998}] {8998}; [known:{22812}] {16689}", by = { bear = GRASP, balance = GRASP, resto = GRASP } },
	-- (Shift + D is a strafe key with Shift held, and a cure drops your form: in a form it does nothing.)
	{ name = "Poison", key = "SHIFT-D", asdf = "SHIFT-D", stay = true, what = "Abolish Poison, out of a form. Cure Poison until 26",
		SHOW, (Grows(2893, 8946):gsub("%[", "[noform,")) },
}
-- With Shift on the bottom row: what your bags hold, the best of it you can use.
Shy.Keys.People(JOBS)   -- (Shift + 1 and 2: what your people alone can do)
Shy.Keys.Carried(JOBS, { drink = true, stone = true, potion = Shy.Keys.MANA })
-- What you press now and then, on Shift + 6 to = (the first free, kept from then on), the most used first. Track
-- Humanoids works in Cat Form alone, so it is a cat's; Gift of the Wild is for a group, with its berries.
Shy.Keys.Utility(JOBS, {
	{ name = "Track Humanoids", spells = { 5225 }, by = { bear = false, balance = false, resto = false } },
	{ name = "Soothe Animal", spells = { 9901, 8955, 2908 } },
	{ name = "Gift of the Wild", spells = { 21850, 21849 } },
	{ name = "Moonglade", what = "Teleport: Moonglade", spells = { 18960 } },
})
-- 1 2 3: your forms, each the spell itself on the left flyout, beside the game's own bar of them: Bear, Cat and
-- Travel Form, Moonkin Form third for Balance.
do
	local bear, cat = { name = "Bear Form", unpack(BEAR_FORM) }, { name = "Cat Form", unpack(CAT_FORM) }
	Shy.Keys.Stays(JOBS, { plain = { bear, cat, { name = "Travel Form", unpack(TRAVEL_FORM) } },
		balance = { bear, cat, { name = "Moonkin Form", unpack(MOONKIN_FORM) } } })
end
K.JOBS = JOBS

-- How to fight, by level and build. The plain brackets are the cat's way (the build for questing alone); the
-- others take over from the level they begin. A key answers by form, so a step says which ability it means (as:
-- text of that clause of its macro, the spell's own "{id}", or a cat's stance where what it casts grows).
local CAT, FRIEND_HEAL = "stance:{768}", "@mouseover"
local AFTER = { "Heal", "after, out of bear" }
local BETWEEN = { "Heal", "between fights" }
-- A bear's steps.
local ENRAGE, DEMO, SWIPE, MAUL = { "Vigor", "as you pull", as = "{5229}" }, { "Mark", "on 2+ enemies", as = "{99}" },
	{ "Tear", "on 2+ enemies", as = "{779}" }, { "Strike", as = "{6807}" }
local BASH, CHARGE = { "Stop", "if it casts", as = "{5211}" }, { "Move", "to charge in", as = "{1238122}" }
local REGEN, PRIMAL = { "Guard", "under half health", as = "{22842}" }, { "Gore", "when it's ready", as = "{407995}" }
local GROWL = { "Hold", "on one that wanders off", as = "{6795}" }
local BEAR_PACK = { ENRAGE, DEMO, SWIPE, MAUL, { "Stop", "if one casts", as = "{5211}" }, AFTER }
local BEAR_PACK_LATE = { ENRAGE, DEMO, SWIPE, MAUL, { "Stop", "if one casts", as = "{5211}" }, REGEN, GROWL }
local BEAR_PACK_CHARGE = { CHARGE, ENRAGE, DEMO, SWIPE, MAUL, { "Stop", "if one casts", as = "{5211}" }, REGEN, GROWL }
local BASH_PACK = { CHARGE, ENRAGE, { "Stop", "to stop a caster", as = "{5211}" }, DEMO, SWIPE, MAUL }
local BASH_PACK_LATE = { CHARGE, ENRAGE, { "Stop", "to stop a caster", as = "{5211}" }, DEMO, SWIPE, MAUL, REGEN }
-- A cat's steps (from Prowl R Pounces and E Ravages; a cat's F makes it a bear, and F again Bashes).
local PROWL, CLAW = { "Hold", "to sneak in", as = "{5215}" }, { "Strike", "to build points", as = "{1082}" }
local FURY, RAKE = { "Vigor", "as you open", as = "{5217}" }, { "Mark", "keep it up", as = "{1822}" }
local SHRED, BITE = { "Heavy", "to open, from behind", as = "{5221}" }, { "Tear", "at 5 points", as = CAT }
local RIP, CAT_BASH = { "Gore", "at 5, on a tough one", as = "{1079}" }, { "Stop", "if it casts: bear, Bash", as = "{5211}" }
local CAT_FIRST = { PROWL, SHRED, CLAW, BITE, CAT_BASH, BETWEEN }
local CAT_SHRED = { PROWL, FURY, SHRED, RAKE, CLAW, BITE, RIP, CAT_BASH, BETWEEN }
local CAT_BLEED = { PROWL, FURY, SHRED, RAKE, CLAW, BITE, RIP, { "Move", "if it runs", as = CAT }, BETWEEN }
local CAT_RAVAGE = { PROWL, FURY, { "Heavy", "to open, from behind", as = "{6785}" }, RAKE, CLAW, BITE, RIP, CAT_BASH, BETWEEN }
local CAT_LATE = { PROWL, FURY, { "Heavy", "to open, from behind", as = "{6785}" }, RAKE, CLAW, BITE, RIP,
	{ "Shifting Power", "low on Energy" }, { "Move", "if it runs", as = CAT }, BETWEEN }
-- A tank's: Faerie Fire works in bear form and pulls from range.
local PULL, LACERATE = { "Faerie Fire", "to pull" }, { "Heavy", "keep it stacked", as = "{1328617}" }
local TANK = { PULL, CHARGE, ENRAGE, { "Mark", "keep it up", as = "{99}" }, LACERATE, MAUL, BASH, AFTER }
local TANK_LATE = { PULL, CHARGE, ENRAGE, { "Mark", "keep it up", as = "{99}" }, LACERATE, PRIMAL, MAUL, REGEN, BASH }
local TANK_PACK = { CHARGE, ENRAGE, SWIPE, { "Mark", "keep it up", as = "{99}" }, { "Heavy", "on the toughest one", as = "{1328617}" },
	{ "Hold", "on one that's off you", as = "{6795}" }, MAUL }
local TANK_PACK_ROAR = { CHARGE, ENRAGE, SWIPE, { "Mark", "keep it up", as = "{99}" }, { "Heavy", "on the toughest one", as = "{1328617}" },
	{ "Hold", "on one that's off you", as = "{6795}" }, MAUL, { "Roar", "if all run for the healer" } }
local TANK_PACK_LATE = { CHARGE, ENRAGE, SWIPE, { "Mark", "keep it up", as = "{99}" }, { "Heavy", "on the toughest one", as = "{1328617}" },
	PRIMAL, { "Hold", "on one that's off you", as = "{6795}" }, MAUL, { "Roar", "if all run for the healer" }, REGEN }
-- Balance's (its T is Hurricane, its G Insect Swarm).
local CASTER_PACK = { { "Hold", "on the second one", as = "{339}" }, { "Mark", "on each enemy", as = "{8921}" },
	{ "Stop", "on a beast", as = "{2637}" }, { "Strike", as = "{5176}" }, { "Heal", "under half health" } }
local SWARM_PACK = { { "Hold", "on the second one", as = "{339}" }, { "Mark", "on each enemy", as = "{8921}" },
	{ "Stop", "on a beast", as = "{2637}" }, { "Insect Swarm", "on the toughest one" }, { "Strike", as = "{5176}" },
	{ "Heal", "under half health" } }
local STARFIRE = { { "Heavy", "to pull", as = "{2912}" }, { "Mark", "keep it up", as = "{8921}" },
	{ "Strike", as = "{5176}" }, { "Hold", "when it reaches you", as = "{339}" }, { "Heal", "under half health" } }
local MOON = { { "Heavy", "to pull", as = "{2912}" }, { "Mark", "keep it up", as = "{8921}" },
	{ "Insect Swarm", "keep it up" }, { "Strike", as = "{5176}" }, { "Hold", "when it reaches you", as = "{339}" },
	{ "Vigor", "low on mana", as = "{29166}" }, { "Heal", "under half, out of form" } }
local MOON_BARK = { { "Heavy", "to pull", as = "{2912}" }, { "Mark", "keep it up", as = "{8921}" },
	{ "Insect Swarm", "keep it up" }, { "Strike", as = "{5176}" }, { "Hold", "when it reaches you", as = "{339}" },
	{ "Guard", "when you're hit", as = "{22812}" }, { "Vigor", "low on mana", as = "{29166}" }, { "Heal", "under half, out of form" } }
local MOON_PACK = { { "Hold", "on the second one", as = "{339}" },
	{ "Mark", "on each enemy", as = "{8921}" }, { "Hurricane", "on 3+ enemies" }, { "Strike", as = "{5176}" },
	{ "Heal", "under half, out of form" } }
-- Restoration's (Renew on Q, Big Heal on R, Heal on E, Mark on T: a bear's on the same keys as everyone's; E as a
-- bear is Regrowth, which shifts you out to heal).
local MEND = { ENRAGE, { "Renew", "keep it up", as = "{99}" }, { "Big Heal", as = "{6807}" }, BASH, AFTER }
local MEND_BEAR = { ENRAGE, { "Renew", "on 2+ enemies", as = "{99}" }, { "Big Heal", as = "{6807}" }, AFTER }
local MEND_PACK = { ENRAGE, { "Renew", "on 2+ enemies", as = "{99}" }, { "Mark", "on 2+ enemies", as = "{779}" },
	{ "Big Heal", as = "{6807}" }, AFTER }
local MEND_LATE = { ENRAGE, { "Renew", "keep it up", as = "{99}" }, { "Big Heal", as = "{6807}" }, REGEN, BASH, AFTER }
local MEND_PACK_LATE = { ENRAGE, { "Renew", "on 2+ enemies", as = "{99}" }, { "Mark", "on 2+ enemies", as = "{779}" },
	{ "Big Heal", as = "{6807}" }, REGEN, { "Wild Growth", "after, out of bear" } }
local PLAY = {
	{ from = 1, tip = "You fight from range. Pull with Wrath, keep Moonfire on it, and heal yourself between fights.",
		single = { { "Thorns", "before you pull" }, { "Strike", "to pull, and in between", as = "{5176}" },
			{ "Mark", "keep it up", as = "{8921}" }, { "Heal", "under half health" } },
		cleave = { { "Hold", "on the second one", as = "{339}" }, { "Mark", "on each enemy", as = "{8921}" },
			{ "Strike", as = "{5176}" }, { "Heal", "under half health" } } },
	{ from = 10, tip = "Pull with Wrath, then go bear and Maul with Demoralizing Roar up. Heal in caster form once it's dead.",
		single = { ENRAGE, { "Mark", "keep it up", as = "{99}" }, MAUL, BASH, AFTER },
		cleave = { ENRAGE, DEMO, MAUL, AFTER } },
	{ from = 16, tip = "As a bear, Swipe hits everything in front of you, so you can take two or three at once.",
		single = { ENRAGE, { "Mark", "keep it up", as = "{99}" }, MAUL, BASH, AFTER },
		cleave = BEAR_PACK },
	{ from = 20, tip = "Go cat. Sneak in with Prowl, Claw up to five combo points and spend them on Rip. Go bear when several hit you.",
		single = CAT_FIRST, cleave = BEAR_PACK },
	{ from = 24, tip = "Rake, Ferocious Bite and Tiger's Fury come now. Keep Rake bleeding, and spend five points on a Bite, or on Rip if it's tough.",
		single = CAT_SHRED, cleave = BEAR_PACK },
	{ from = 30, tip = "Keep Rake bleeding and Shred from behind. Your talents make a bleeding enemy take far more from both.",
		single = CAT_BLEED, cleave = BEAR_PACK },
	{ from = 32, tip = "Ravage is your opener now. Prowl up behind it, Ravage, then Rake and Claw to five points.",
		single = CAT_RAVAGE, cleave = BEAR_PACK },
	{ from = 40, tip = "From Prowl your Claw key Pounces and your Shred key Ravages. Shifting Power refills your Energy from your mana.",
		single = CAT_LATE, cleave = BEAR_PACK_LATE },
	{ from = 50, tip = "Fights are short now. Regrowth between them saves you from eating, and Innervate gives you mana back.",
		single = CAT_LATE, cleave = BEAR_PACK_CHARGE },

	-- Feral bear: a bear all the way, the group's tank.
	{ from = 20, build = "bear", tip = "You stay a bear. Faerie Fire to pull, Feral Charge in, Enrage, Maul and Swipe, and Growl back what goes for a friend.",
		single = { PULL, CHARGE, ENRAGE, { "Mark", "keep it up", as = "{99}" }, MAUL, BASH, AFTER },
		cleave = { CHARGE, ENRAGE, SWIPE, { "Mark", "keep it up", as = "{99}" }, { "Hold", "on one that's off you", as = "{6795}" }, MAUL } },
	{ from = 25, build = "bear", tip = "Lacerate bleeds and builds threat. Stack it on what you're holding, and Maul with the rage left over.",
		single = TANK, cleave = TANK_PACK },
	{ from = 30, build = "bear", tip = "In a group, Swipe the pack, Growl what breaks off, and Challenging Roar if they all run for the healer.",
		single = TANK, cleave = TANK_PACK_ROAR },
	{ from = 40, build = "bear", tip = "Primal Bite is your big threat now. Frenzied Regeneration turns rage into health, so press it before you're low.",
		single = TANK_LATE, cleave = TANK_PACK_LATE },
	{ from = 50, build = "bear", tip = "You can take whole camps. Charge in, Swipe them down and keep Lacerate on the toughest one.",
		single = TANK_LATE, cleave = TANK_PACK_LATE },

	-- Feral PvP: the cat's way, with Feral Charge and a longer Bash from the start.
	{ from = 20, build = "feralpvp", tip = "Fight as a cat. When a pack or a caster comes at you, go bear, Feral Charge in and Bash.",
		single = CAT_FIRST, cleave = BASH_PACK },
	{ from = 24, build = "feralpvp", tip = "Rake, Ferocious Bite and Tiger's Fury come now. Keep Rake bleeding, and spend five points on a Bite, or on Rip if it's tough.",
		single = CAT_SHRED, cleave = BASH_PACK },
	{ from = 30, build = "feralpvp", tip = "Keep Rake bleeding and Claw to five points. Feral Charge leaps you onto a runner, and Bash stops a caster.",
		single = CAT_BLEED, cleave = BASH_PACK },
	{ from = 32, build = "feralpvp", tip = "Ravage is your opener now. Prowl up behind it, Ravage, then Rake and Claw to five points.",
		single = CAT_RAVAGE, cleave = BASH_PACK },
	{ from = 42, build = "feralpvp", tip = "From Prowl your Claw key Pounces to stun them and your Shred key Ravages. In bear, Bash holds a caster still.",
		single = CAT_LATE, cleave = BASH_PACK_LATE },
	{ from = 50, build = "feralpvp", tip = "Fights are short now. Regrowth between them saves you from eating, and Innervate gives you mana back.",
		single = CAT_LATE, cleave = BASH_PACK_LATE },

	-- Balance: a caster all the way.
	{ from = 10, build = "balance", tip = "Wrath from range, keep Moonfire on, and root it when it reaches you. You drink a lot, so pull one at a time.",
		single = { { "Strike", "to pull, and in between", as = "{5176}" }, { "Mark", "keep it up", as = "{8921}" },
			{ "Hold", "when it reaches you", as = "{339}" }, { "Heal", "under half health" } },
		cleave = { { "Hold", "on the second one", as = "{339}" }, { "Mark", "on each enemy", as = "{8921}" },
			{ "Strike", as = "{5176}" }, { "Heal", "under half health" } } },
	{ from = 20, build = "balance", tip = "Open with Starfire from as far as you can, then Moonfire and Wrath. Root it and step back if it gets close.",
		single = STARFIRE, cleave = CASTER_PACK },
	{ from = 30, build = "balance", tip = "Moonfire and Insect Swarm hurt while you cast, so put both on early. A crit makes your next cast quicker.",
		single = { { "Heavy", "to pull", as = "{2912}" }, { "Insect Swarm", "keep it up" },
			{ "Mark", "keep it up", as = "{8921}" }, { "Strike", "once it's close", as = "{5176}" },
			{ "Hold", "when it reaches you", as = "{339}" }, { "Heal", "under half health" } },
		cleave = SWARM_PACK },
	{ from = 40, build = "balance", tip = "Fight in Moonkin Form and leave it only to heal. Root a pack in place and Hurricane it.",
		single = MOON, cleave = MOON_PACK },
	{ from = 44, build = "balance", tip = "Barkskin takes the edge off what reaches you, and you keep casting through it.",
		single = MOON_BARK, cleave = MOON_PACK },
	{ from = 50, build = "balance", tip = "Most things die before they reach you now. Innervate when you're low and keep pulling.",
		single = MOON_BARK, cleave = MOON_PACK },

	-- Restoration: a healer, who fights alone as a bear to save mana.
	{ from = 1, build = "resto", tip = "Wrath and Moonfire do the killing. Rejuvenation keeps you up, and you drink between fights.",
		single = { { "Big Heal", "to pull, and in between", as = "{5176}" }, { "Mark", "keep it up", as = "{8921}" },
			{ "Renew", "when you're hit", as = FRIEND_HEAL }, { "Heal", "under half health" } },
		cleave = { { "Hold", "on the second one", as = "{339}" }, { "Mark", "on each enemy", as = "{8921}" },
			{ "Big Heal", as = "{5176}" }, { "Renew", "keep it on you", as = FRIEND_HEAL }, { "Heal", "under half health" } } },
	{ from = 10, build = "resto", tip = "Fight as a bear to save your mana for healing, then heal yourself up in caster form once it's dead.",
		single = MEND, cleave = MEND_BEAR },
	{ from = 16, build = "resto", tip = "As a bear, Swipe hits everything in front of you, so you can take two at once and heal up after.",
		single = MEND, cleave = MEND_PACK },
	{ from = 20, build = "resto", tip = "In a group keep Rejuvenation on the tank and Regrowth whoever drops low. Alone you still fight as a bear.",
		single = MEND, cleave = MEND_PACK },
	{ from = 30, build = "resto", tip = "Swiftmend turns a Rejuvenation into a big heal at once, and Nature's Swiftness makes your next heal instant.",
		single = { ENRAGE, { "Renew", "keep it up", as = "{99}" }, { "Big Heal", as = "{6807}" }, BASH,
			{ "Swiftmend", "if it goes wrong" }, AFTER },
		cleave = { ENRAGE, { "Renew", "on 2+ enemies", as = "{99}" }, { "Mark", "on 2+ enemies", as = "{779}" },
			{ "Big Heal", as = "{6807}" }, { "Swiftness", "then a heal, if you're low" }, AFTER } },
	{ from = 40, build = "resto", tip = "Wild Growth heals your whole group at once, and Innervate gives you mana back when you run dry.",
		single = MEND_LATE, cleave = MEND_PACK_LATE },
	{ from = 50, build = "resto", tip = "Alone you're still slow. Pull one at a time, and let Rejuvenation and Regrowth tick while you drink.",
		single = MEND_LATE, cleave = MEND_PACK_LATE },
}
K.PLAY = PLAY

local OPTS = {
	forms = 4, plain = true,                 -- cat, tree, bear and moonkin each turn the main bar's page
	knows = 5176,                            -- Wrath: a druid's from level 1
	stances = "Bear Form, Cat Form and Travel Form; Moonkin Form for Balance",
	-- 1 2 3: the forms you fight and travel in, wherever the stance bar has them.
	-- The form to fight in: a cat, a bear (Dire Bear once you have it) or a moonkin; a healer stays as they are.
	keep = { cat = CAT_FORM, feralpvp = CAT_FORM, bear = BEAR_FORM, balance = MOONKIN_FORM },
	keeps = "form",
	-- A form a key only passes through (a cat's stop makes it a bear) is not what the key is for.
	shifts = { [5487] = true, [9634] = true },
	build = Shy.Keys.Build,
	play = PLAY,
}
K.OPTS = OPTS

function K.Apply()
	if not ns.isDruid then return nil, "class" end
	return Shy.Keys.Apply(T, JOBS, OPTS)
end

function K.Run(typed)
	if not ns.isDruid then
		T:Print("these keys are for druids only.")
		return
	end
	Shy.Keys.Run(T, JOBS, OPTS, nil, typed)
end

function K.List()
	return Shy.Keys.List(JOBS, OPTS, T) .. "\n\nA heal goes to the friend under your mouse, or your target, or you."
end

-- From login on, a job comes to its key when you learn it, the bags' keys follow the bags and the layout your build.
function ns.SetupKeys()
	Shy.Keys.Watch(T, JOBS, OPTS)
end
