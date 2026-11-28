-- Settings: what you gear for, where upgrades show, and quest rewards.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- Your talent build first, when its weights are known. Then your class's roles.
local function FocusItems()
	local items = {}
	local build = ns.Build()
	local known = build and ns.BUILDS[ns.Class()]
	if known and known[build.id] then items[1] = { value = "build", text = "Your build: " .. build.name } end
	for _, focus in ipairs(ns.Focuses()) do items[#items + 1] = { value = focus, text = ns.FOCUS_NAME[focus] } end
	return items
end

-- The default bags are away while the bag window stands in for them. It has its own upgrade mark.
local function DefaultBags()
	local bags = Shy.addons.Bags
	return not (bags and bags.owns and bags.owns.window)
end

-- The default quest window is away while the quest page stands in for it. The page suggests a reward itself.
local function QuestPage()
	local talk = Shy.Talk
	return talk ~= nil and talk.IsOn ~= nil and talk.IsOn() == true
end

-- A tooltip and a hand-in read their switches as they come.
local function Nothing() end

T:Settings({
	apply = function() ns.Refresh() end,
	reset = function()
		T:ResetDB()
		ShyGearCharDB.focus = nil
		ns.Refresh()
	end,

	{ section = "What you gear for" },
	{ label = "Gear for", items = FocusItems, words = "role build spec tank healer melee caster ranged",
		get = function() return ns.Focus() end,
		-- Picking what it follows anyway is no pick: it goes on following.
		set = function(v) ShyGearCharDB.focus = v ~= ns.Follows() and v or nil end,
		default = function() return ns.Follows() end,
		shown = function() return #FocusItems() > 1 end,
		desc = "What counts as an upgrade for you." },
	{ key = "lean", label = "Damage or survival", words = "health armor stamina tough",
		items = {
			{ value = "damage", text = "Favor damage" },
			{ value = "balanced", text = "Balanced" },
			{ value = "tough", text = "Favor survival" },
		},
		desc = "How much health and armor count when an item trades damage for them." },
	{ label = "Your numbers", button = "Show", run = function() ns.ShowReport() end,
		words = "report stats rates weights strength agility stamina intellect spirit attack power crit",
		desc = "What a point of each stat gives you and how your gear is weighed, to read or copy." },

	{ section = "Where upgrades show" },
	{ key = "tooltip", label = "In item tooltips", apply = Nothing, words = "compare",
		desc = "An upgrade's tooltip says what it would change for you." },
	{ key = "worse", label = "Worse gear too", sub = true, apply = Nothing, enabled = function() return T.db.tooltip end,
		desc = "Gear that's worse or about the same says so too." },
	{ key = "bags", label = "In your bags", apply = ns.Tell, shown = DefaultBags, words = "arrow mark",
		desc = "Upgrades in your bags get an arrow." },

	{ section = "Quest rewards" },
	{ key = "reward", label = "Reward choices", apply = ns.Tell, words = "arrow coin mark select sell vendor",
		items = {
			{ value = "off", text = "Do nothing" },
			{ value = "mark", text = "Mark the best" },
			{ value = "select", text = "Mark and select the best" },
		},
		desc = "In the quest log and the default quest window, the best upgrade gets an arrow and the best seller a coin." },
	{ note = "Your quest page already suggests a reward. This only marks rewards in your quest log.", alert = true, shown = QuestPage },
	{ key = "take", label = "Pick obvious rewards", needs = "Quest", apply = Nothing, words = "auto turn in hand",
		desc = "Takes the reward when one upgrade clearly wins, or the best seller when none is an upgrade. Needs auto turn-in on." },
	{ note = "You still choose between potions, bags, items with effects and upgrades for later levels.", needs = "Quest" },
	{ note = "A filled arrow is an upgrade. An outlined arrow is one for a few levels on. A coin is the reward that sells for the most." },
})

Shy:On("SHY_BAGS_OWNS", Shy.Settings.Refresh)
Shy:On("SHY_IMMERSION", Shy.Settings.Refresh)
