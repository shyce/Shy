-- Settings: where the numbers show, how they look, what you gain, and whose hits you see in a group.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function On() return T.db.on end
local function Plates() return T.db.on and T.db.plates end
local function You() return T.db.on and T.db.you end
local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

local WHOSE = {
	{ value = "all", text = "Everyone's hits" },
	{ value = "mine", text = "Only yours" },
	{ value = "game", text = "Default numbers" },
}

T:Settings({
	apply = function() ns.Apply() end,
	-- What the game's settings were before the numbers took them stays through a reset.
	reset = function()
		local cvars, mended = T.db.cvars, T.db.mended
		T:ResetDB()
		T.db.cvars, T.db.mended = cvars, mended
		ns.Apply()
	end,

	{ key = "on", label = "Damage and healing numbers", words = "combat text floating scrolling hits",
		desc = "Hits and heals show as numbers by nameplates and by you. Turn it off to get the game's combat text back." },
	{ label = "Sample hits", button = "Play", words = "test preview try", enabled = On, run = function() T:Test() end,
		desc = "Plays a short fight on your target and on you. Drag this window aside to see it." },

	{ section = "Where they show" },
	{ key = "plates", label = "On nameplates", enabled = On,
		desc = "Damage and healing beside the nameplate of whatever takes it. With this off, nameplates get the game's numbers." },
	{ key = "place", label = "Nameplate position", sub = true, needs = "Plates", enabled = Plates,
		items = {
			{ value = "beside", text = "Beside the health bar" },
			{ value = "above", text = "Above the name" },
		},
		desc = "Beside keeps the name, your debuffs and combo points clear. Nameplates with only a name get them above." },
	{ key = "you", label = "On you", enabled = On,
		desc = "Damage you take on one side of your character, healing on the other." },
	{ key = "healer", label = "Healer names", sub = true, enabled = You,
		desc = "A heal on you ends with the healer's name in their class color." },
	{ key = "friends", label = "Heals on your party", enabled = On,
		desc = "Heals on your party still show when they have no nameplate, on their frame or by you." },
	Shy.Settings.Layout("Move the numbers that show by you."),

	{ section = "How they look" },
	{ key = "motion", label = "Animation", enabled = On,
		items = {
			{ value = "burst", text = "Punch in, fly off" },
			{ value = "calm", text = "Calm column" },
		},
		desc = "Punch bursts hits off the nameplate and slams crits in over it. Calm stacks them in a column." },
	{ key = "size", label = "Size", min = 0.7, max = 1.6, step = 0.05, format = Percent, settle = true, enabled = On,
		desc = "How big every number is." },
	{ key = "schools", label = "Color by damage type", words = "school fire frost nature shadow arcane holy", enabled = On,
		desc = "Fire is orange, frost blue, shadow violet. With this off, your hits are white and hits on you are red." },
	{ key = "weigh", label = "Bigger hits stand out", enabled = On,
		desc = "A hit well over your usual one is drawn larger." },
	{ key = "words", label = "Misses, dodges and parries", words = "block resist immune", enabled = On,
		desc = "Miss, Dodge, Parry, Block, Resist and Immune show as small words." },
	{ key = "lettering", label = "Theme lettering", words = "font", enabled = On,
		desc = "Numbers use your theme's font. With this off, they use the plain rounded one." },

	{ section = "What you gain" },
	{ key = "gainXP", label = "Experience", words = "xp", enabled = Plates,
		desc = "XP rises from the mob you just killed, in place of the default text." },
	{ key = "gainRep", label = "Reputation", enabled = On,
		desc = "Reputation you gain or lose, with the faction's name." },
	{ key = "gainCoin", label = "Coin you loot", words = "money gold", enabled = On,
		desc = "Money you loot, shown by your character." },
	{ key = "gainSkill", label = "Skill ups", enabled = On,
		desc = "A weapon or profession skill going up, with its new level." },
	{ key = "gainHonor", label = "Honor", enabled = On,
		desc = "Honor from kills and awards." },

	{ section = "In a group" },
	{ key = "party", label = "In a party", items = WHOSE, enabled = Plates,
		desc = "Whose hits you see on nameplates in a party." },
	{ key = "raid", label = "In a raid", items = WHOSE, enabled = Plates,
		desc = "The same for a raid, where everyone's hits are a lot to look at." },
	{ key = "gameFont", label = "Font on default numbers",
		desc = "The game's combat text uses the same rounded font. It changes the next time you log in." },
	{ note = "The game doesn't say whose hit is whose. \"Only yours\" is a close guess, and your pet's hits come from the default numbers." },
})
