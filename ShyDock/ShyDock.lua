-- ShyDock: the console along the bottom of the screen. Action bars in a housing,
-- chat as the left wing (skinned by ShyChat), the damage meter as the right (ShySkin).
--
--   Housing.lua   frame behind the bottom bars; follows their rectangles, never anchored to them
--   Rack.lua      end pieces behind the side bars
--   Cockpit.lua   box under the character: cooldowns, tracked buffs, health and power; its looks
--   Console.lua   pure geometry: sizes and positions from which bars are on, for both layouts
--   Layout.lua    the Edit Mode layout "Shy", written through C_EditMode; bars that grow; the cockpit's plan
--   Vessel.lua    the names and words of the cockpit's choices (its size, the tracked bars' side)
--   Parts.lua     the planned screen as a list of rectangles, for the preview and the ghost; touches no frame
--   Arrange.lua   homes for the HUD boxes while the layout is in use
--   Drawers.lua   the rows under the minimap and the racks as drawers (Shy.Drawer): tucked to a pull, out under the mouse
--   Deck.lua      panel for the docked boxes: a tab per box, the level at its foot
--   Extras.lua    the extra ability's slot over the cockpit, an encounter's bar under the column at the top
--   Move.lua      layout mode: dragging and sizing the cockpit, picking the console's size
--   Pieces.lua    taking the cockpit apart: a mover per piece, sockets, loose pieces; its editor panel
--   NextSwing.lua next-swing abilities by class (generated)
--   Coatings.lua  temporary weapon enchants: poisons, stones, oils (generated)
--   Swing.lua     swing timer row in the cockpit; other addons add to it (T:AddSwingModule)
--   Offer.lua     the console's step in the setup window (ShyCore's Setup.lua)
--   Picker.lua    the cockpit's size and bars' side: its setup step, /shy section and drawing
--   Grow.lua      offers another bar when the abilities known outgrow the bars
--   Preview.lua   scaled drawing of the screen with the layouts and sizes to pick from
--
-- ShyDockDB is account-wide; ShyDockCharDB is per character, matching Edit
-- Mode's per-character active layout (its layout, size and bars too).

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyDock\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Dock",
	category = "interface",
	icon = MEDIA .. "ShyDock",
	smallIcon = MEDIA .. "ShyDockSmall",
	savedVariables = "ShyDockDB",
	-- cockpit: the cockpit's top edge as a percent of screen height; cockpitX: its centre, in units from the screen's.
	-- cockpitFollow: the cockpit uses the core's background opacity (Theme.Strength); off, it is solid.
	-- swingWas (not a default): the showSwingTimer CVar as it was before the swing row took it;
	-- swingEditWas: Edit Mode's "Swing Timer" switch as it was. editShownWas: Edit Mode's "Cast Bar" and "Cooldown
	-- Viewer" switches as they were before the console turned them on (Move.lua), by setting.
	-- cooldownsInCombat: the console's layout shows essential and utility cooldowns only in combat (Layout.lua).
	-- menuDrawer: the micro menu and the bag bar tuck away to a pull under the minimap (Drawers.lua).
	-- cockpitScale: the cockpit's size (0.75 to 1.5) about its top edge's middle; barsSide: the tracked bars'
	-- wing, "left" or "right". (Its look is the theme's: ShyCore.)
	-- joined: the tracked bars (in a classic layout) and the pings and markers stand on the cooldown manager's plate,
	-- the bars in a flap joined by a rib, the pings in a bay at its end; off, each has a place of its own.
	defaults = { housing = true, arrange = true, deck = true, blades = true, cockpit = 36, cockpitX = 0,
		cockpitFollow = true, swing = true, cooldownsInCombat = true, menuDrawer = true,
		cockpitScale = 1, barsSide = "left", joined = false },
})
ns.T = T

-- loose: cockpit pieces the player took out (Pieces.lua) or dragged off in Edit Mode (Move.lua).
-- shown: each cooldown row's own visibility before "in combat only" took it; seen: a row's size when last on screen (Layout.lua).
-- style, size: the layout and its size. grow: bars come as the abilities need them;
-- asked: the last step offered (Grow.lua).
local CHAR_DEFAULTS = { placed = {}, loose = {}, shown = {}, seen = {} }

local started

-- Color functions for UI.SetFill: the HUD background at the core's opacity.
function ns.Graphite()
	local c = Shy.UI.colors.hud
	return c[1], c[2], c[3], c[4]
end

function ns.CockpitGraphite()
	local c = Shy.UI.colors.hud
	return c[1], c[2], c[3], T.db.cockpitFollow and c[4] or 1
end

-- For ShyCore's game step: a layout by role's slim vessel keeps the personal resource display off (Layout.lua),
-- so its row there is left alone while one is the layout in use.
function T:HoldsDisplay()
	return ns.Layout.HoldsDisplay()
end

function T:Apply()
	if not started then return end
	ns.Housing.Apply()
	ns.Rack.Apply()
	if ns.PetBar then ns.PetBar.Apply() end
	ns.Cockpit.Apply()
	if ns.Swing then ns.Swing.Apply() end
	if ns.Pieces then ns.Pieces.Apply() end
	ns.Arrange.Apply()
	if ns.Drawers then ns.Drawers.Apply() end
	if ns.RefreshOptions then ns.RefreshOptions() end
	if ns.Vessel and ns.Vessel.Refresh then ns.Vessel.Refresh() end
end

-- For other addons (ShyPaladin's seal, ShyRogue's poisons): a color or something drawn on the swing bar,
-- see Swing.lua's modules. Returns a handle with Overlay().
function T:AddSwingModule(module)
	return ns.Swing.Add(module)
end

function T:OnLoad()
	ShyDockCharDB = Shy.MergeDefaults(ShyDockCharDB or {}, CHAR_DEFAULTS)
	ns.char = ShyDockCharDB
	-- An opacity saved here is the core's: handed to it once per profile.
	if type(self.db.strength) == "number" then
		Shy.Theme.SetStrength(self.db.strength)
		self.db.strength = nil
	end
	-- So was the cockpit's look, which is the whole theme's now: one picked here is handed on once (the
	-- old default was never a pick, so it is dropped).
	local look = self.db.cockpitLook
	self.db.cockpitLook = nil
	if (look == "clear" or look == "eclipse") and not Shy.Theme.LookChosen() then Shy.Theme.SetLook(look) end
	-- The cooldown manager's layout is no setting: one saved in a profile is dropped.
	self.db.cockpitLayout = nil
end

function T:OnLogin()
	started = true
	ns.Housing.Start()
	ns.Rack.Start()
	if ns.PetBar then ns.PetBar.Start() end   -- (a new file: loaded once the client restarts)
	ns.Cockpit.Start()
	ns.Deck.Start()
	ns.Arrange.Start()
	if ns.Drawers then ns.Drawers.Start() end   -- guarded: a newly added file isn't loaded until the client restarts
	ns.Move.Start()
	if ns.Pieces then ns.Pieces.Start() end   -- guarded: a newly added file isn't loaded until the client restarts
	if ns.Swing then ns.Swing.Start() end
	self:Apply()
	-- A stale console is only reported, never rewritten unasked. The delay lets the bars lay out.
	C_Timer.After(5, function()
		ns.screenSeen = ns.Screen()
		if InCombatLockdown() then return end
		ns.Layout.Settle()
		if not ns.char.toldCombat and ns.Layout.CooldownsWaiting() then
			ns.char.toldCombat = true
			T:Print("\"Cooldowns in combat only\" isn't in your console yet. Type /shy setup to add it.")
		end
		if ns.toldStale or not (ns.Layout.IsActive() and ns.Layout.IsStale()) then return end
		ns.toldStale = true
		T:Print("the console no longer fits your screen. Type /shy setup to refit it.")
	end)
end

-- The /shy window's Screen room: the console's layout and size, under layout mode's button.
Shy.HubSection("screen", function(page, top)
	local head = Shy.HubHead(page, top, "Console")
	local words = Shy.UI.Text(page, "How your bars, chat and meter are laid out. With the console in use, a pick shows right away.", 12, false, Shy.UI.colors.dim)
	words:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
	words:SetWidth(page.width)
	words:SetWordWrap(false)
	local section = ns.Preview.Section(page, page.width)
	section:SetPoint("TOPLEFT", words, "BOTTOMLEFT", 0, -10)
	return section, function() if section.Refresh then section:Refresh() end end
end, 30)

Shy.HubBrief("screen", function()
	if not ns.Layout.IsActive() then return nil end
	return ns.Preview.STYLES[ns.Layout.Style()]
end)

-- The screen changed size while you play (the size of everything picked again, or another resolution): the
-- console was laid out for the old one. Not while logging in: the game puts its scale on as it starts, and
-- the look five seconds in (above) says what needs saying. Nor while setup is open: it refits the console
-- itself. Said once a session, like every word about a console that no longer fits.
function ns.Screen()
	return math.floor(UIParent:GetWidth() + 0.5) .. "x" .. math.floor(UIParent:GetHeight() + 0.5)
end

Shy:On("SHY_SCREEN", function()
	if not ns.screenSeen or Shy.Setup.IsOpen() then return end
	local screen = ns.Screen()
	if screen == ns.screenSeen then return end
	ns.screenSeen = screen
	if ns.toldStale or not (ns.Layout.IsActive() and ns.Layout.IsStale()) then return end
	ns.toldStale = true
	T:Print("your screen changed size, so the console no longer fits it. Type /shy setup to refit it.")
end)

-- ShyXP's bars moved under the action bars, or away from there: the room kept for them is no longer the room
-- the console was laid out with. (Not while setup is open: it fits the console itself.)
Shy:On("SHY_XP_PLACE", function()
	if not started or Shy.Setup.IsOpen() then return end
	if ns.Layout.IsActive() and ns.Layout.IsStale() and not ns.toldStale then
		ns.toldStale = true
		T:Print("your XP bars moved, so the console no longer fits them. Type /shy setup to refit it.")
	end
end)

-- A wing's art changed size: the layout may no longer meet it.
Shy:On("SHY_WINGS", function()
	if not started then return end
	-- (Not while setup is open: its picks go on live, and it fits the console itself.)
	if ns.Layout.IsActive() and ns.Layout.IsStale() and not ns.toldStale and not Shy.Setup.IsOpen() then
		ns.toldStale = true
		T:Print("chat or the damage meter changed size. Type /shy setup to refit the console.")
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end)

-- /shy dock setup, then a layout, a size, or both, in either order. "reset" is the same, said of a console in
-- use: every piece back in its place and at its size. A word that is neither sets nothing up.
local function SetUp(rest)
	local size, style
	for word in rest:lower():gmatch("%a+") do
		if ns.Console.SIZES[word] then
			size = word
		elseif ns.Console.STYLES[word] then
			style = word
		else
			T:Print(("\"%s\" isn't a layout or a size. Layouts: %s. Sizes: %s."):format(word,
				table.concat(ns.Console.STYLE_ORDER, ", "), table.concat(ns.Console.SIZE_ORDER, ", ")))
			return
		end
	end
	ns.Layout.Report(ns.Layout.SetUp(size, style))
	if ns.RefreshOptions then ns.RefreshOptions() end
end
T:Command("setup", "set the console up again, or as another layout or size (open grand)", SetUp)
T:Command("reset", nil, SetUp)
T:Command("back", "go back to the layout you had before", function()
	ns.Layout.Report(ns.Layout.GoBack())
	if ns.RefreshOptions then ns.RefreshOptions() end
end)
