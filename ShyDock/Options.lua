-- Settings: the console's switches, the cooldown manager's, the bars a character has and the way back to the
-- layout before it. The layouts and sizes are picked in the Screen room, a button away.

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

	{ note = "The console isn't in use on this character, so most of this does nothing yet. Set it up on Screen.", alert = true,
		shown = function() return not Active() end },
	{ label = "Layout and size", button = "Screen",
		words = "console flanks open stack center healer tank minimal compact roomy grand grow with me set up put it back cooldown size tracked bars side left right small medium large",
		says = function()
			if not Active() then return "not set up" end
			return ns.Preview.STYLES[L.Style()] .. ", " .. ns.Preview.NAMES[L.Size()]:lower()
		end,
		run = function() Shy.Hub.OpenAt("screen", "Console") end,
		desc = "Pick the console's layout and size, bars that grow as you level, and how big your cooldowns are." },

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
