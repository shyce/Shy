-- Settings: the quest window, then steps, tracking, quest givers, the guide and the pins.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Carded() return T.db.card.shown end
local function Offering() return T.db.pickups end
local function Tracking() return T.db.track == "zone" end
local function Giving() return T.db.giver.auto end
local function Guided() return ns.Following() end
local function Buttoned() return Guided() and T.db.guide.buttons end
local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Read when it is used: nothing on screen to draw again.
local function AtUse() end
-- Its setter applies it.
local function Applied() end
-- The pins alone, or the tracker's look alone: the route stays as it is.
local function Pins()
	if ns.ApplyPins then ns.ApplyPins() end
end
local function Look()
	if ns.ApplyLook then ns.ApplyLook() end
end

-- Another quest addon doing the same thing: ours waits for it, and the list says so.
local function Theirs(what, ...) return ns.Yield ~= nil and ns.Yield.To(what, ...) end
local function TheirPins()
	for _, kind in ipairs({ "pickup", "turnin", "goal" }) do
		if Theirs("map", kind) or Theirs("map", kind, true) then return true end
	end
	return false
end

local function HiddenCount()
	local count = 0
	for _ in pairs(ns.char.hidden) do count = count + 1 end
	return count
end

T:Settings({
	apply = function() ns.Apply() end,

	{ section = "Quest window" },
	{ key = "card.shown", label = "Show the quest window", words = "card tracker",
		desc = "Your steps in one window, in the order you'll do them. It takes the place of the game's quest tracker." },
	{ key = "card.rows", label = "Steps listed", sub = true, min = 1, max = 6, step = 1, settle = true, enabled = Carded,
		desc = "How many steps it lists. Quests you track and your guide's steps always show." },
	{ key = "card.hideInCombat", label = "Hide in combat", sub = true, enabled = Carded,
		desc = "The quest window gets out of your way while you fight." },
	Shy.Settings.Layout("Move the quest window."),

	{ section = "Steps" },
	{ key = "pickups", label = "Available quests", desc = "Quest givers with a quest for you become steps and get a pin." },
	{ key = "lowLevel", label = "Low-level quests", sub = true, enabled = Offering,
		desc = "Includes quests that give a fifth of their XP or less." },
	{ key = "repeatable", label = "Repeatable quests", sub = true, enabled = Offering,
		desc = "Includes repeatable turn-ins, mostly for reputation." },
	{ key = "zones", label = "Suggest zones",
		items = { { value = "short", text = "When steps run low" }, { value = "always", text = "Always" }, { value = "never", text = "Never" } },
		desc = "The zones with the most quests for you show at the end of the quest window and on the world map. Click one to head there." },
	{ label = "Hidden quests", button = "Show them", shown = function() return HiddenCount() > 0 end,
		says = function() return tostring(HiddenCount()) end,
		run = function()
			ns.UnhideAll()
			ns.Apply()
		end,
		desc = "Brings back the quests you hid with a right-click on a step." },
	{ key = "xp.steps", label = "XP on steps", needs = "XP",
		desc = "A turn-in shows its XP and whether it levels you. A grind step shows the XP left." },

	{ section = "Tracked quests" },
	{ key = "track", label = "Tracked quests",
		items = {
			{ value = "zone", text = "Current zone, in route order" },
			{ value = "order", text = "My tracked quests, in route order" },
			{ value = "off", text = "Default" },
		},
		desc = "Current zone tracks your quests for where you are, in the order you'll do them. A quest you track or untrack yourself stays that way." },
	{ key = "grayZone", label = "Gray quests too", sub = true, enabled = Tracking,
		desc = "Also tracks and lists quests too low to give XP." },

	{ section = "The game's tracker" },
	{ note = "The quest window takes the place of the game's tracker. You'll see these when it's off.", shown = Carded },
	{ note = "Another quest addon's tracker is on, so these are off for now.", alert = true, shown = function() return Theirs("tracker") end },
	{ key = "look.on", label = "Restyle the tracker", apply = Look,
		desc = "The game's tracker gets the quest window's panel, font and markers." },
	{ key = "tips", label = "Quest details on hover",
		desc = "Hover a quest in the tracker or the quest log for what it needs, what drops it and where to turn in." },
	{ key = "beside.distance", label = "Distance to each quest",
		desc = "Each tracked quest shows how far its next stop is, under its marker." },
	{ key = "beside.elsewhere", label = "Quests in other zones", enabled = Tracking,
		desc = "The tracker's title counts your quests in other zones. Hover it to see which." },

	{ section = "At a quest giver" },
	{ note = "Another quest addon is accepting and turning in for you, so this is off for now.", alert = true,
		shown = function() return Theirs("giver") end },
	{ key = "giver.auto", label = "Auto accept and turn-in", words = "automatic instant quests",
		desc = "Talking to a quest giver takes their quests and turns in yours. Hold Shift to do it yourself." },
	{ key = "giver.accept", label = "Accept new quests", sub = true, enabled = Giving, apply = AtUse,
		desc = "Takes the quests a quest giver offers." },
	{ key = "giver.turnIn", label = "Turn in finished quests", sub = true, enabled = Giving, apply = AtUse,
		desc = "Turns in and takes the reward. You pick when there's a choice." },
	{ key = "giver.gray", label = "Gray quests too", sub = true, enabled = Giving, apply = AtUse,
		desc = "Also accepts gray quests your guide doesn't send you for." },
	{ key = "giver.again", label = "Repeatable quests too", sub = true, enabled = Giving, apply = AtUse,
		desc = "Also turns in repeatables that take items from you each time." },

	{ section = "Leveling guide" },
	{ label = "Follow the leveling guide", default = true, words = "guide route steps", apply = Applied,
		get = Guided, set = function(v) T:SetQuestStyle(v and "guide" or "zone") end,
		desc = "Your guide's steps come first in the quest window, then nearby quests. It finds your place from the quests you've done." },
	{ key = "guide.nearby", label = "Nearby quests first", sub = true, enabled = Guided,
		desc = "A turn-in or objective close by goes before your guide's step." },
	{ key = "guide.hardcore", label = "Hardcore route", enabled = Guided,
		desc = "Fewer dangerous quests, and a full hardcore route in the list of guides." },
	{ key = "hover.careful", label = "Warn about dangerous creatures", sub = true, words = "hardcore elite",
		shown = function() return ns.Safety ~= nil and ns.Safety.Careful() end,
		desc = "Tooltips flag hostile elites three or more levels above you. Chat warns you once when you target one." },
	{ key = "guide.selfFound", label = "Play without the AH", enabled = Guided, words = "self found auction house",
		desc = "Skips steps that buy quest items from the AH and shows the ones written for playing without it." },
	{ key = "guide.group", label = "Group quests", enabled = Guided,
		desc = "Keeps your guide's steps for quests that need a group. Right-click one to ask chat for help." },
	{ key = "guide.xprate", label = "XP rate", min = 1, max = 3, step = 0.1, settle = true, enabled = Guided,
		format = function(v) return ("%.1fx"):format(v) end,
		desc = "Your server's XP rate. Above 1x, your guide skips steps only worth doing at the normal rate." },
	{ label = "Help at max level", default = false, shown = function() return ns.AtTop() end, apply = Applied,
		get = function() return ns.char.topHelp == true end, set = function(v) ns.SetTopHelp(v) end,
		desc = "At max level, keep the quests to pick up and the errands, not just the quests you have." },

	{ section = "Current step" },
	{ key = "guide.buttons", label = "Use and target buttons", enabled = Guided,
		desc = "The quest window gets a button for each item or spell the step uses and each NPC it names. Bind the first of each in Key Bindings." },
	{ key = "guide.marks", label = "Mark who I target", sub = true, enabled = Buttoned, words = "raid marker star skull moon",
		desc = "Targeting from a button also sets a raid marker, while you're solo." },
	{ key = "guide.scan", label = "Rare alert", enabled = Guided, words = "rare scan creature warning",
		desc = "You hear a warning and get a line in chat when a creature your step needs shows up." },
	{ key = "guide.gossip", label = "Auto pick gossip options", enabled = Guided, apply = AtUse,
		desc = "Picks the gossip option the step needs. Hold Shift to choose yourself." },
	{ key = "guide.takeFlights", label = "Auto take flights", enabled = Guided, apply = AtUse,
		desc = "When the step is a flight, opening the flight map takes it. Hold Shift to choose yourself." },
	{ note = "Your flight master window picks the step's flight for you instead. One press takes it.",
		shown = function()
			local skin = Shy.addons.Skin
			return skin ~= nil and skin.owns ~= nil and skin.owns.flights == true
		end },
	{ key = "guide.setHome", label = "Auto set hearthstone", enabled = Guided, apply = AtUse,
		desc = "At the step's innkeeper, talking sets your hearthstone. Hold Shift to leave it." },

	{ section = "Map pins" },
	{ note = "Another quest addon is drawing some of these pins, so yours stay out of its way.", alert = true, shown = TheirPins },
	{ key = "mapPins", label = "On the world map", apply = Pins,
		desc = "Pins for quests to pick up and turn in, and your guide's steps in order. Your next step keeps its pin either way." },
	{ key = "minimapPins", label = "On the minimap", apply = Pins, desc = "The same pins on the minimap, with a trail to your next step." },
	{ key = "minimapRim", label = "Areas past the edge", sub = true, apply = Pins, enabled = function() return T.db.minimapPins end,
		desc = "A quest area that runs past the minimap's edge shows along the edge." },
	{ key = "goals", label = "Pins for unmarked objectives", apply = Pins,
		desc = "Where the map shows no area for a quest, each objective left gets a pin of its own." },
	{ key = "pinSize", label = "Pin size", min = 0.7, max = 1.6, step = 0.1, settle = true, format = Percent, apply = Pins,
		enabled = function() return T.db.mapPins or T.db.minimapPins end,
		desc = "How big the pins are on the world map and minimap." },
	{ label = "Paths", default = "high", words = "roads shortest route",
		shown = function() return not Shy.Way.missing end,
		items = {
			{ value = "high", text = "Roads in higher zones" },
			{ value = "auto", text = "Roads unless I outlevel it" },
			{ value = "always", text = "Always roads" },
			{ value = "never", text = "Shortest" },
		},
		get = function() return Shy.Way.Paths() or "high" end, set = function(v) Shy.Way.SetPaths(v) end,
		desc = "Keeps you on roads until you're near your step. Higher zones are ones where mobs off the road are 5 or more levels above you." },
	{ key = "logMarks", label = "In the quest log",
		desc = "Each quest in the map's quest log shows its mark and route number. Hover one to light up where to go." },
	{ key = "logSort", label = "Quests in route order", sub = true, enabled = function() return T.db.logMarks end,
		desc = "The quest log lists each zone's quests in the order you'll do them, not by level." },
})

-- Which dungeons' quests go in the guide, then every dungeon the guides have steps for on this faction, lowest
-- first. Told at login: which faction you are is known then.
local told
Shy:On("SHY_LOGIN", function()
	if told then return end
	told = true
	local function Planned() return Guided() and T.db.guide.dungeonPlan ~= "never" end
	local list = {
		{ section = "Dungeon quests" },
		{ key = "guide.dungeonPlan", label = "Which dungeons", enabled = Guided,
			items = {
				{ value = "ticked", text = "Only the ones switched on" },
				{ value = "ready", text = "Any at my level, and those" },
				{ value = "never", text = "None" },
			},
			desc = "Which dungeons' quests your guide sends you to. \"At my level\" follows the Group Finder's suggested levels." },
	}
	for _, dungeon in ipairs(ns.Detours()) do
		local tag = dungeon.short
		local low, high = ns.DungeonRange(dungeon)
		list[#list + 1] = { label = dungeon.name, sub = true, default = false, enabled = Planned,
			words = "dungeon " .. tag, says = function() return low .. "-" .. high end,
			desc = ("Your guide takes in the quests for %s."):format(dungeon.name),
			get = function() return T.db.guide.dungeons[tag] == true end,
			set = function(v)
				T.db.guide.dungeons[tag] = v or nil
				if v then ns.Unsnooze(tag) end   -- switched on again after Not now
			end }
	end
	T:Settings(list)
end)
