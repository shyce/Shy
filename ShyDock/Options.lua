-- Settings: the console's layout, size and bars, then its switches, the cooldown manager's, the bars a character has
-- and the way back to the layout before it. The Screen room picks the same things on cards that draw each one.

local ADDON, ns = ...
local T = ns.T
local L = ns.Layout

-- The Screen room's drawings follow a change too.
ns.RefreshOptions = function()
	Shy.Settings.Refresh()
	ns.Preview.Refresh()
end

local STEP_NAMES = { "One bar", "Two bars", "Three bars", "Every bar" }
local STEPS = {}
for i, name in ipairs(STEP_NAMES) do STEPS[i] = { value = i, text = name } end

local function Active() return L.IsActive() end
local function Arranged() return T.db.arrange and L.IsActive() end

-- The cooldown manager stands somewhere you dragged it: there is a middle to go back to.
local function Moved()
	return L.IsActive() and (T.db.cockpitX ~= T.defaults.cockpitX or T.db.cockpit ~= T.defaults.cockpit or ns.char.barsAt ~= nil)
end

-- Nothing of the console's is written in a fight: said, and false.
local function Calm()
	return L.Report(not InCombatLockdown(), "combat")
end

-- The bars: the game's own switches. They come back from the server a moment after a pick, so the pick is
-- what the row shows meanwhile (HOLD seconds at most).
local HOLD = 2
local asked, askedAt

local function Step()
	local now = L.StepNow()
	if asked and (asked == now or GetTime() - askedAt > HOLD) then asked = nil end
	return asked or now
end

-- The console's choices, as the Screen room's cards and chips name them.
local function Styles()
	local items = {}
	for _, row in ipairs(ns.Preview.STYLE_ROWS) do
		for _, key in ipairs(row[2]) do items[#items + 1] = { value = key, text = ns.Preview.STYLES[key] } end
	end
	return items
end
local function Sizes()
	local items = {}
	for i, key in ipairs(ns.Console.SIZE_ORDER) do items[i] = { value = key, text = ns.Preview.NAMES[key] } end
	return items
end
local GROW = { { value = "grow", text = "Grow with me" }, { value = "all", text = "Every bar now" } }
local function Vessel(keys)
	local items = {}
	for i, key in ipairs(keys) do items[i] = { value = key, text = ns.Vessel.NAMES[key] } end
	return items
end
-- (Preview.Wear puts the console on and draws again itself.)
local function Picked() end

local function SetStep(step)
	if not L.Report(L.SetUp(nil, nil, { step = step, words = "Your bars are set. Reload to apply them." })) then return end
	-- Picked by hand: the bars aren't offered again until the abilities need more than this.
	ns.char.asked = math.max(ns.char.asked or 0, L.StepFor(L.Abilities()))
	asked, askedAt = step, GetTime()
	C_Timer.After(HOLD + 0.1, Shy.Settings.Refresh)
end

T:Settings({
	reset = function()
		-- What the game had before the console took it is given back later: kept through a reset.
		local swing, edit, shown = T.db.swingWas, T.db.swingEditWas, T.db.editShownWas
		T:ResetDB()
		T.db.swingWas, T.db.swingEditWas, T.db.editShownWas = swing, edit, shown
		T:Apply()
		L.CooldownsInCombat()
	end,

	{ note = "Not set up on this character yet. Pick a layout and it's set up, with a reload.", alert = true,
		shown = function() return not Active() end },
	{ label = "Layout", items = Styles, default = function() return ns.Console.STYLE end, get = function() return L.Style() end, set = function(v) ns.Preview.Wear("style", v) end,
		apply = Picked, words = "console flanks open stack center healer tank minimal by role classic set up",
		desc = "Where your bars, frames, chat and meter stand. A pick goes on at once, with a reload as you close." },
	{ label = "Size", items = Sizes, default = function() return ns.Console.DEFAULT end, get = function() return L.Size() end, set = function(v) ns.Preview.Wear("size", v) end,
		apply = Picked, enabled = Active, words = "compact roomy grand big small",
		desc = "How much room the console takes along the bottom of your screen." },
	{ label = "Bars", items = GROW, default = "all", get = function() return L.Grows() and "grow" or "all" end,
		set = function(v) ns.Preview.Wear("grow", v == "grow") end, apply = Picked, enabled = Active,
		words = "grow with me every bar level abilities",
		desc = "Grow with me starts you with fewer bars and adds them as you learn abilities." },
	{ label = "Cooldown size", items = Vessel(ns.Vessel.SIZES), enabled = Active, words = "cooldown manager icons bars small medium large",
		default = function() return ns.Vessel.SizeOf(T.defaults.cockpitScale) end,
		get = function() return ns.Vessel.SizeOf(L.Scale()) end,
		set = function(v) T.db.cockpitScale = ns.Vessel.SCALES[v] end,
		desc = "How big your cooldowns and tracked bars are, in the cooldown manager under your character." },
	{ label = "Tracked bars", items = Vessel(ns.Vessel.SIDES), enabled = Active, words = "tracked buffs bars side left right",
		default = function() return T.defaults.barsSide end,
		get = function() return L.BarsSide() end,
		set = function(v) T.db.barsSide = v end,
		desc = "Which side of the cooldown manager your tracked bars hang off." },

	{ section = "Console" },
	{ key = "housing", label = "Bar housing", words = "gryphons frame action bars steel pet bar",
		desc = "A steel frame sits behind your action bars and follows them when you move them. It hides the main bar's gryphons." },
	{ key = "arrange", label = "Arrange around the console", enabled = Active, words = "boxes pieces spots homes",
		desc = "Everything else on your screen gets a spot around the console. Anything you moved stays where you put it." },
	-- (Only with a guide or a group status to hold.)
	{ key = "deck", label = "Guide and group panel", sub = true, enabled = Arranged, words = "deck dock tabs quest status",
		shown = function() return ns.Arrange.Decks() end,
		desc = "The guide and group status stack in one panel under the minimap, with a tab each. Right-click it to take one out." },
	{ key = "menuDrawer", label = "Menu in a drawer", sub = true, enabled = Arranged, words = "micro menu bags tray pull",
		desc = "The micro menu and bags tuck away under the guide. Point at the pull to slide them out, or click it to keep them out." },
	{ note = "Change these in a fight and they apply when it ends." },

	{ section = "Cooldown manager" },
	{ key = "cockpitFollow", label = "See-through", enabled = Active, words = "opacity transparent solid background",
		desc = "The cooldown manager is as see-through as the Background you set in Theme. Off, it's solid." },
	-- (On, but the layout in use was written without it: off is the truth, and switching it on writes it.)
	{ key = "cooldownsInCombat", label = "Cooldowns in combat only", enabled = Active, words = "hide out of combat essential utility fight",
		get = function() return T.db.cooldownsInCombat and not L.CooldownsWaiting() end,
		apply = function() L.CooldownsInCombat() end,
		desc = "Your cooldowns show only in a fight, and tracked buffs stay up. You'll be asked to reload." },
	{ key = "swing", label = "Swing timer", enabled = Active, words = "weapon speed auto attack next swing",
		desc = "A bar for each weapon takes your cast bar's spot while you swing. Off, the game's own swing timer shows if you have it on." },
	{ note = "The swing bar turns gold with a next-swing ability queued, and red when your target is out of reach." },
	-- (A layout by role keeps the bars by your frames: there it is the pings' alone, if there are any.)
	{ key = "joined", label = "Bars and pings attached", enabled = Arranged, words = "tracked bars markers joined flap bay",
		shown = function() return not ns.Console.ROLE[L.Style()] or Shy.HUD.Find(ns.Parts.STRIP_ID) ~= nil end,
		desc = "Your tracked bars and the pings join the cooldown manager. In a layout by role, the bars stay by your frames." },
	-- (A rogue's, and only while ShyRogue's combo points are a piece on screen.)
	{ key = "blades", label = "Combo points on it", needs = "Rogue", enabled = Arranged, words = "blades rogue",
		shown = function() return UnitClassBase("player") == "ROGUE" and Shy.HUD.Find("shyrogue-combo") ~= nil end,
		desc = "Your combo points sit in the cooldown manager's top edge and move with it. Off, they're a box of their own." },
	{ label = "Pieces", button = "Take apart", enabled = Active, words = "loose socket handle separate",
		run = function()
			if not Calm() then return end
			Shy.Hub.Close()
			ns.Pieces.Enter()
		end,
		desc = "Opens layout mode with a handle on every piece. Drag one out, or drop it back on its socket." },
	{ label = "Place", button = "Center", enabled = Moved, words = "middle reset position",
		run = function()
			if Calm() then ns.Move.Reset() end
		end,
		desc = "Puts the cooldown manager back under your character." },

	{ section = "Bars" },
	{ label = "Action bars", items = STEPS, get = Step, set = SetStep, default = Step, enabled = Active,
		words = "rows side bars one two three every",
		says = function()
			local known = L.Abilities()
			local need = L.StepFor(known)
			if need > Step() then return ("%d abilities need %s"):format(known, STEP_NAMES[need]:lower()) end
			return ("room for %d abilities"):format(known)
		end,
		desc = "A bar you put away keeps its buttons. You'll be asked to reload." },

	{ section = "Your layout" },
	Shy.Settings.Layout("Drag the cooldown manager, your bars and anything else into place."),
	{ label = "Your old layout", button = "Go back", enabled = Active, words = "previous edit mode undo leave",
		run = function() L.Report(L.GoBack()) end,
		desc = "Switches to the Edit Mode layout you had before the console. You'll be asked to reload." },
	{ note = "A damage meter you dragged by its title stays where you put it. Right-click its title to give it back to the console." },
})
