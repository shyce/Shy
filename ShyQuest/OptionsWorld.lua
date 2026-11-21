-- Settings: tooltips, nameplates, your party and the sound.

local ADDON, ns = ...
local T = ns.T

local function Marked() return T.db.plates.on end
local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Read when it is used: nothing on screen to draw again.
local function AtUse() end

-- Another quest addon doing the same thing: ours waits for it, and the list says so.
local function Theirs(what, ...) return ns.Yield ~= nil and ns.Yield.To(what, ...) end
local function TheirLines()
	for _, kind in ipairs({ "objectives", "accepted", "handedIn", "abandoned" }) do
		if Theirs("announce", kind) then return true end
	end
	return false
end

T:Settings({
	{ section = "In the world" },
	{ note = "Another quest addon is writing quest lines on tooltips, so yours step aside for them.", alert = true,
		shown = function() return Theirs("tooltips") end },
	{ label = "Quests on tooltips", default = true, words = "creature object chest hover drop rate",
		get = function() return T.db.hover.units end,
		set = function(v) T.db.hover.units, T.db.hover.objects = v, v end,
		desc = "A creature's or object's tooltip lists your quests that need it, with your progress and the drop rate." },
	{ key = "hover.items", label = "On items too", sub = true,
		desc = "An item's tooltip names the quest that needs it and how many you have." },
	{ key = "plates.on", label = "Mark quest nameplates",
		desc = "A mark on the nameplate of anything you still need to kill or loot, and on the NPC for your next step." },
	{ key = "plates.where", label = "Mark position", sub = true, enabled = Marked,
		items = { { value = "left", text = "Left" }, { value = "right", text = "Right" }, { value = "above", text = "Above" } },
		desc = "Where the mark sits on a nameplate." },
	{ key = "plates.size", label = "Mark size", sub = true, min = 0.7, max = 1.6, step = 0.1, settle = true, enabled = Marked,
		format = Percent, desc = "How big the mark is." },
	{ key = "sound", label = "Progress sound", apply = AtUse,
		items = {
			{ value = "off", text = "None" },
			{ value = "ready", text = "Quest ready to turn in" },
			{ value = "all", text = "Quest ready and each objective" },
		},
		desc = "A chime when a quest is ready to turn in, and a ping for each objective if you want one." },

	{ section = "Your party" },
	{ key = "party.share", label = "Share quest progress",
		desc = "Your party's progress shows under each objective in tooltips, and yours shows in theirs." },

	{ section = "Tell your party" },
	{ note = "Another quest addon is saying some of these lines, so yours stay quiet.", alert = true, shown = TheirLines },
	{ key = "party.tell.objectives", label = "Finished objectives", words = "announce party chat", apply = AtUse,
		desc = "Party chat gets a line like \"Gnoll Paw: 8/8 for [Patrolling Westfall]\"." },
	{ key = "party.tell.starts", label = "Quest starters", words = "announce party chat item", apply = AtUse,
		desc = "Names an item you loot that starts a quest. Solo, the line is for you alone." },
	{ key = "party.tell.accepted", label = "Accepted quests", words = "announce party chat", apply = AtUse,
		desc = "Party chat hears which quest you accepted." },
	{ key = "party.tell.handedIn", label = "Turned-in quests", words = "announce party chat", apply = AtUse,
		desc = "Party chat hears which quest you turned in." },
	{ key = "party.tell.abandoned", label = "Abandoned quests", words = "announce party chat", apply = AtUse,
		desc = "Party chat hears which quest you abandoned." },
})
