-- The Edit Mode layout "Shy": bars, chat, damage meter and the rest of the
-- console, written through C_EditMode.
--
-- Nothing is moved from addon code. The active layout is copied, the console's
-- positions and sizes are written into the copy, and the copy is saved the way
-- Blizzard's "new layout" does it (Blizzard_EditMode/Shared/EditModeManager.lua,
-- MakeNewLayout): C_EditMode.GetLayouts, SaveLayouts, OnLayoutAdded(index, true),
-- or SetActiveLayout(index) for one that exists.
--
-- Then a reload. The game applies a layout by firing EDIT_MODE_LAYOUTS_UPDATED
-- from inside the call; called by an addon, everything Edit Mode's manager
-- writes while applying it is tainted, and Blizzard's bar code can then be
-- blocked in combat. After a reload the game applies the saved layout itself.
--
-- Rules:
--   - only from a player's click or slash command, never in combat
--   - the previous layout stays in Edit Mode's list and is remembered per
--     character for GoBack
--   - the layout is per character: it depends on which bars are on
--   - a second run rewrites the layout in place; it never adds another
--   - every size is one its Edit Mode slider can reach (ranges read from Blizzard)
--
-- Placed always: the three bottom bars, chat and the meter. The systems in
-- PLACES are placed only while they are where Blizzard (or an earlier run)
-- put them; one the player moved is left alone. On this client the XP bar,
-- stance, pet and possess bars and the leave-vehicle button are stacked on the
-- main bar, so they have to move with it.
--
-- The cockpit (L.Cockpit; drawn by Cockpit.lua) seats the personal resource
-- display, the cooldown viewers, the stance bar and the cast bar under the
-- character. T.db.cockpit is its height as a share of the screen's.
-- The side bars go in the racks (Rack.lua). The system column at the top right:
-- the minimap, the micro menu and the bag bar as two short rows under it (each
-- at the largest size its slider has that fits the map's width, Console.RowFit),
-- then the objectives tracker. The group column at the top left: the raid
-- frames five to a row, groups stacked, a frame's size by the console's
-- (Console.Raid); Blizzard's party frames take the same corner while
-- ShyFrames' party row isn't the one in use. The bottom corners hold only chat
-- and the meter.
--
-- Per character: the layout (ns.char.style, Console.STYLES), its size
-- (ns.char.size) and whether the bars grow with the character (ns.char.grow,
-- L.STEPS): then setup turns on only the bars the abilities known need, never
-- putting away a bar that holds anything, and Grow.lua offers the next step.
--
-- The cockpit is planned in design units about its top edge's middle and then
-- scaled (T.db.cockpitScale) about that point, so the Edit Mode layout, the
-- signature and the sizes written for the viewers never see the scale. Which
-- pieces are seated (ns.char.loose) shapes the plan: a row taken out reserves
-- nothing. Its size, the tracked bars' side and its look change anchors and
-- art only, so they apply live.

local ADDON, ns = ...
local T = ns.T
local Console = ns.Console
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local L = {}
ns.Layout = L

L.NAME = "Shy"

local System = Enum.EditModeSystem
local Bar, BarSetting = Enum.EditModeActionBarSystemIndices, Enum.EditModeActionBarSetting
local Chat, Meter = Enum.EditModeChatFrameSetting, Enum.EditModeDamageMeterSetting
local Character = Enum.EditModeLayoutType.Character

local SMALL = 50            -- pet bar icon size, percent
L.OVER = 13                 -- minimum rise of what ShyFrames builds onto its plates' top edges (see Now)
local CLEAR = Console.SEAM  -- gap between the housing (or plates) and what sits on them
-- Above the cockpit: offsets of the default swing timers, and of the extra ability over them.
local SWING, SWING_STEP, EXTRA = 32, 20, 28
-- The extra ability's slot on the cockpit's top line: the game's button (52) a little smaller, this far
-- over what the cockpit mounts there, an encounter's bar a gap over it. The game hangs the button in a
-- frame 120 tall: the button's foot is EXTRA_DROP over the frame's.
local EXTRA_BUTTON, EXTRA_SCALE, EXTRA_OVER, EXTRA_GAP, EXTRA_DROP = 52, 0.85, 12, 8, 30
-- The cockpit's box. Gems (essential cooldowns) and combo blades are half out of
-- its top edge; the first row of small tiles (stances, utility cooldowns) is half
-- out of its bottom. A second row of utility cooldowns hangs under that one.
local BOX_W = 300
local BOX_IN = 12                        -- box side to the gems, and to the blades' slot
local GEM, GEM_SIZE = 60, 30             -- essential icon size setting, and the icon it gives
local GEMS = 4                           -- gems per row
local GEM_GAP = 4
local SLOT_PAD = 4                       -- a slot's padding around its icons
local BLADES_W, BLADES_H = 112, 14       -- must match ShyRogue's docked box (its Combo.lua, DOCK)
local DISPLAY, DISPLAY_W = 140, 280      -- display width setting, and the frame it gives
local HEALTH, POWER = 15, 10             -- bar heights
-- The display adds 4 to its padding setting (PersonalResourceDisplayMixin:GetBarPadding) and Edit Mode
-- clamps the setting to its slider's range as it applies it, so by its settings the bars never stand
-- closer than 4. In the cockpit they stand SEAM apart: Cockpit.lua anchors the power bar (and a druid's
-- mana bar) again after the display anchors them, and sets its height to match, so the display is one
-- block (one frame round every bar, hairlines of its steel between them). The setting is written as 0.
-- The class bar is written as hidden, and Cockpit.lua keeps it hidden while the display is seated.
local BARS_PAD = 0
local SEAM = 1
local BARS_GAP = SEAM
local TILE, TILE_SIZE = 80, 24           -- stance and utility icon size setting, and the icon it gives
-- Tracked buffs: Blizzard's 40 at 60%, or at the 50% minimum when the edge is short of room (FitBuffs).
local BUFF, BUFF_SMALL, BUFF_BASE = 60, 50, 40
local BUFF_GAP = 2
local BAR = 220                          -- a tracked bar's width at 100%
local BAR_TEMPLATE = 30                  -- the game's item: 30 tall, 220 wide
local BAR_H = HEALTH                     -- drawn at the health bar's height, not the tile's
local BAR_GAP = 2
local BAR_PITCH = BAR_H + BAR_GAP
-- Within the vessel its pieces stand TIGHT apart; the console's seam (CLEAR) is for separate pieces.
local TIGHT = 2
local PAD_IN = 6                         -- the plate's padding round its rows
local RIB = 16                           -- the join between the box and the tracked bars' flap (ShyCore's Rib)
-- The top row rides the plate's top edge and the foot row hangs under its foot (seated, stacked): this much of
-- the row's room stands outside the plate.
local MOUNT = 0.5
-- Offsets down from the box's top edge.
local BAR_FRAME = 2                          -- must match the bar frame in ShySkin's Personal.lua
local SLOT_REACH = GEM_SIZE / 2 + SLOT_PAD
local BARS_TOP = SLOT_REACH + BAR_FRAME + TIGHT
local TILES_TOP = BARS_TOP + HEALTH + BARS_GAP + POWER + BAR_FRAME + TIGHT + SLOT_PAD
local EDGE_H = TILES_TOP + TILE_SIZE / 2     -- box height
-- The swing row (Swing.lua) makes the box taller and lowers everything under it.
local SWING_H = 6
-- The cast bar is a row of the vessel while a cast is up: the health bar's height, the spell's picture a
-- square of that height at its left end, a seam from the bar. Under the display's block, a seam apart in
-- the block's one frame, in every layout: the plate's foot goes down by the row, the foot row riding it
-- still, and comes back when the cast is over. (The stance bar and the totem bar are protected: in a
-- fight the game holds them until it ends, and Shy.HUD seats them then.) With the display out of the
-- vessel the row hangs under what is left in a frame of its own, CLEAR under it.
-- The cockpit's design units, for the pieces made elsewhere (the swing row).
L.UNITS = {
	BOX_W = BOX_W, BOX_IN = BOX_IN, GEM_SIZE = GEM_SIZE, GEM_GAP = GEM_GAP, SLOT_PAD = SLOT_PAD, SLOT_REACH = SLOT_REACH,
	DISPLAY_W = DISPLAY_W, HEALTH = HEALTH, POWER = POWER, BARS_GAP = BARS_GAP, BAR_FRAME = BAR_FRAME, TILE_SIZE = TILE_SIZE,
	BUFF_GAP = BUFF_GAP, BAR = BAR, BAR_H = BAR_H, BAR_TEMPLATE = BAR_TEMPLATE,
	CLEAR = CLEAR, SWING_H = SWING_H,
	BLADES_W = BLADES_W, BLADES_H = BLADES_H, TIGHT = TIGHT, RIB = RIB, PAD_IN = PAD_IN,
	MOUNT = MOUNT,
}
-- The cockpit's rows. height: used when nothing of the row shows.
--   set       the setup sets the row's size, so the plan uses `height`, not a measurement
--   items     the frame keeps room for hidden items: measure the shown children instead
--   limit     icons per row
--   leftward  icons grow leftward from the right end
--   fit       icon size is picked for the number of items (tracked buffs)
local ROWS = {
	{ key = "cast", frame = "PlayerCastingBarFrame", height = 11 },
	{ key = "stances", frame = "StanceBar", stead = "PossessActionBar", height = TILE_SIZE, items = true, set = true },
	{ key = "utility", frame = "UtilityCooldownViewer", height = TILE_SIZE, items = true, viewer = "Utility", limit = 8, size = TILE, set = true },
	{ key = "essential", frame = "EssentialCooldownViewer", height = GEM_SIZE, items = true, viewer = "Essential", limit = GEMS, size = GEM, gap = GEM_GAP, set = true },
	{ key = "display", frame = "PersonalResourceDisplayFrame", height = HEALTH + BARS_GAP + POWER, core = true, set = true },
	{ key = "buffs", frame = "BuffIconCooldownViewer", height = BUFF_BASE * BUFF / 100, items = true, viewer = "BuffIcon", size = BUFF,
		gap = BUFF_GAP, leftward = true, fit = true, set = true },
	-- height stays the tile's, and set, so a layout already written still fits. The bar is drawn at BAR_H and seated live.
	{ key = "bars", frame = "BuffBarCooldownViewer", height = TILE_SIZE, items = true, viewer = "BuffBar", bars = true,
		size = BAR_H / BAR_TEMPLATE * 100, gap = BAR_GAP, shownOnly = true, set = true },
}
L.ROWS = ROWS
-- The rows "cooldowns in combat only" hides out of combat, by their Edit Mode index name.
local HIDES = { essential = "Essential", utility = "Utility" }
-- ... and their categories in the game's own list of cooldowns.
local CATEGORIES = { essential = "Essential", utility = "Utility" }

-- How many cooldowns of a hidden row the character knows, from the game's list (C_CooldownViewer, never
-- the settings' data, which addon code must not touch): the room a row never seen will take in a fight,
-- and what a drawing of the vessel shows. nil when the game cannot say.
local function Known(key)
	local category = Enum.CooldownViewerCategory and Enum.CooldownViewerCategory[CATEGORIES[key]]
	local api = _G.C_CooldownViewer
	if not (category and api and api.GetCooldownViewerCategorySet and api.GetCooldownViewerCooldownInfo) then return nil end
	local ids = api.GetCooldownViewerCategorySet(category, false)
	if type(ids) ~= "table" then return nil end
	local hidden = Enum.CooldownSetSpellFlags and Enum.CooldownSetSpellFlags.HideByDefault
	local count = 0
	for _, id in ipairs(ids) do
		local info = api.GetCooldownViewerCooldownInfo(id)
		local flags = info and info.flags
		local away = hidden and flags and not issecretvalue(flags) and bit.band(flags, hidden) ~= 0
		if info and not away then count = count + 1 end
	end
	return count
end

-- A row's rectangle: the frame's, or for `items` the union of its shown children (and, fifth, how many).
-- nil: nothing shows. false: the rect is secret.
function L.RowRect(def)
	for _, name in ipairs({ def.frame, def.stead }) do
		local frame = _G[name]
		if frame then
			local l, b, r, t = Console.Rect(frame)
			local count
			if l == false then return false end
			if l and def.items then
				l, b, r, t, count = nil, nil, nil, nil, 0
				for _, child in ipairs({ frame:GetChildren() }) do
					local cl, cb, cr, ct = Console.Rect(child)
					if cl == false then return false end
					-- Edit Mode's outline over the whole row is no item of it.
					if cl and child ~= frame.Selection then
						if def.shownOnly then
							local shown = child:IsShown()
							if issecretvalue(shown) then return false end
							if not shown then cl = nil end
						end
						if cl then
							l, b = min(l or cl, cl), min(b or cb, cb)
							r, t = max(r or cr, cr), max(t or ct, ct)
							count = count + 1
						end
					end
				end
			end
			if l then return l, b, r, t, count end
		end
	end
	return nil
end

-- Where the tracked buffs go and at what size: "top" (right end of the top
-- edge), "foot" (bottom edge, when the blades have the top), or "over" the box
-- when the row is too long for either. Blizzard's row keeps a place for every
-- tracked buff and never wraps (BuffIconCooldownViewerMixin:GetStride), so its
-- width is the tracked count.
local function FitBuffs(now)
	local wide, room = now.wide, nil
	if now.blades then
		local forms = now.forms
		local stances = wide.stances or (forms * TILE_SIZE + max(0, forms - 1) * 2)
		local utility = wide.utility or 0
		local tiles = stances + utility + ((stances > 0 and utility > 0) and CLEAR or 0)
		room = DISPLAY_W - tiles - (tiles > 0 and 2 * SLOT_PAD + CLEAR or 0)
	else
		room = BOX_W - 2 * BOX_IN - (wide.essential or 2 * GEM_SIZE + GEM_GAP) - 2 * SLOT_PAD - CLEAR
	end
	for _, icon in ipairs({ BUFF, BUFF_SMALL }) do
		local size = BUFF_BASE * icon / 100
		if now.tracked * size + (now.tracked - 1) * BUFF_GAP <= room then return now.blades and "foot" or "top", icon end
	end
	return "over", BUFF
end
L.FitBuffs = FitBuffs
local CORNER = Console.SEAM      -- inset of the columns from the screen's corners
local UNDER_MAP = Console.SEAM   -- between the last row under the minimap and the objectives
-- The rows under the minimap at 100%, when their frames can't be measured.
local MENU_NATURAL = { w = 290, h = 40 }
local BAGS_NATURAL = { w = 315, h = 45 }
local BUFFS_GAP = Console.SEAM   -- between the minimap panel and the buffs
local BUFFS_TOP = CORNER    -- Auras.lua keeps buffs and debuffs here live

-- Edit Mode settings

local function Slider(system, setting)
	return EditModeSettingDisplayInfoManager:GetSystemSettingDisplayInfoMap(system)[setting]
end

-- The core's background opacity, in percent.
local function Strength()
	return floor(Shy.Theme.Strength() * 100 + 0.5)
end

local function Range(system, setting)
	local slider = Slider(system, setting)
	return { slider.minValue, slider.maxValue, slider.stepSize or 1 }
end

-- The nearest value the slider can reach, in the layout's stored form (the
-- slider's ConvertValue: a step count for percentages, an offset for sizes).
local function Stored(system, setting, value)
	local slider = Slider(system, setting)
	local step = slider.stepSize or 1
	value = max(slider.minValue, min(slider.maxValue, value))
	value = slider.minValue + floor((value - slider.minValue) / step + 0.5) * step
	if slider.ConvertValue then return slider:ConvertValue(value) end
	return value   -- stored as displayed (the cooldown viewers' icon limit)
end

local function Find(layout, system, index)
	for _, info in ipairs(layout.systems) do
		if info.system == system and info.systemIndex == index then return info end
	end
end

local function Value(info, setting)
	for _, entry in ipairs(info.settings) do
		if entry.setting == setting then return entry.value end
	end
end

local function Set(info, setting, value)
	for _, entry in ipairs(info.settings) do
		if entry.setting == setting then
			entry.value = value
			return
		end
	end
	info.settings[#info.settings + 1] = { setting = setting, value = value }
end

-- Current state

-- `coming` (here and below): what Furnish has just turned on or off, which the
-- game won't report until after the reload. A table { bar2, bar3, right, left,
-- meter }: those as given, the rest as they are. false: everything as it is.
local function Coming(coming, key, now)
	if coming and coming[key] ~= nil then return coming[key] end
	return now
end

local function MeterOn(coming)
	local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_DamageMeter")
	return loaded and Coming(coming, "meter", C_CVar.GetCVarBool("damageMeterEnabled")) and true or false
end

-- The first side bar that is on goes in the right rack (beside the meter), the
-- second in the left. Returns each as its Edit Mode index, or nil.
local SIDE_BARS = { { "MultiBarRight", Bar.RightBar1, "right" }, { "MultiBarLeft", Bar.RightBar2, "left" } }

local function RackBars(coming)
	local on = {}
	for _, def in ipairs(SIDE_BARS) do
		if Coming(coming, def[3], _G[def[1]]:IsShown() == true) then on[#on + 1] = def[2] end
	end
	return on[1], on[2]
end

-- The bar frame for a rack (side 1 right, -1 left), or nil.
function L.RackBar(side)
	local right, left = RackBars()
	local index = side > 0 and right or left
	for _, def in ipairs(SIDE_BARS) do
		if def[2] == index then return _G[def[1]] end
	end
end

-- Height of ShyFrames' plates on the housing; 0 without ShyFrames or when the
-- player moved both the player and target frames elsewhere.
local PLATES = { "shyframes-player", "shyframes-target" }

function L.Plates()
	local theirs = Shy.addons.Frames
	if not theirs then return 0 end
	for _, id in ipairs(PLATES) do
		local box = Shy.HUD.Find(id)
		if box and box.shownFn() and not Shy.HUD.IsPlaced(box) then return theirs:PlatesHeight() + Console.SEAM end
	end
	return 0
end

function L.Size()
	local size = ns.char.size
	return Console.SIZES[size] and size or Console.DEFAULT
end

-- The vessel's settings: the scale and the tracked bars' side (its look is the theme's, ShyCore's
-- Theme.Look). A plan's `now.vessel` (a drawing of another choice) overrides the saved ones.
L.SCALE_MIN, L.SCALE_MAX, L.SCALE_STEP = 0.75, 1.5, 0.05

function L.ClampScale(scale)
	scale = tonumber(scale) or 1
	scale = max(L.SCALE_MIN, min(L.SCALE_MAX, scale))
	scale = floor(scale / L.SCALE_STEP + 0.5) * L.SCALE_STEP
	return floor(scale * 100 + 0.5) / 100   -- a clean hundredth, as the steps are
end

function L.Scale(now)
	local over = now and now.vessel and now.vessel.scale
	return L.ClampScale(over or T.db.cockpitScale or 1)
end

function L.BarsSide(now)
	local over = now and now.vessel and now.vessel.side
	local side = over or T.db.barsSide
	return side == "right" and "right" or "left"
end

-- Is a cast up? The cast bar showing with a cast or a channel on it (the game keeps it up a moment
-- after, fading), or Edit Mode showing it; or one just over, the row held open a moment for the next
-- (Cockpit.lua's hold). The plate opens the cast bar's row for it.
function L.Casting()
	local bar = _G.PlayerCastingBarFrame
	if not bar then return false end
	if ns.Cockpit and ns.Cockpit.CastHeld and ns.Cockpit.CastHeld() then return true end
	local shown = bar:IsShown()
	if issecretvalue(shown) or not shown then return false end
	local manager = _G.EditModeManagerFrame
	if manager and manager.IsEditModeActive and manager:IsEditModeActive() then return true end
	for _, key in ipairs({ "casting", "channeling", "reverseChanneling" }) do
		local on = bar[key]
		if not issecretvalue(on) and on then return true end
	end
	return false
end

-- Pieces taken out or moved in Edit Mode; taken apart (Pieces.lua) the vessel keeps its whole shape,
-- every socket waiting for its piece.
local function Loose()
	if ns.Pieces and ns.Pieces.Apart() then return {} end
	return ns.char.loose
end
L.Loose = Loose

-- The layouts by role have a slim vessel: cooldowns alone, with no health and power block (your frame beside
-- your character shows them), and the game's own display is off with it (SetUp). `now`: a plan's inputs, or
-- nil for the layout in use.
function L.Slim(now)
	return Console.ROLES[now and now.style or L.Style()] == true
end

-- Which pieces the vessel holds: seated (not taken out) and there for this character.
function L.Present(now)
	local loose = Loose()
	return {
		gems = not loose.essential,
		utility = not loose.utility,
		stances = not loose.stances and (now.forms or 0) > 0,
		tiles = not loose.utility or (not loose.stances and (now.forms or 0) > 0),
		display = not loose.display and not L.Slim(now),
		cast = not loose.cast and L.WasSeated("cast"),
		buffs = not loose.buffs,
		bars = not loose.bars,
		blades = now.blades and true or false,
		swing = T.db.swing and not loose.swing and true or false,
	}
end

function L.Style()
	local style = ns.char.style
	return Console.STYLES[style] and style or Console.STYLE
end

-- The plan's inputs: which bars are on, what is under the console, each wing's
-- art overhang, and measurements of what is on screen.
local function Now(coming)
	local now = {
		bar2 = Coming(coming, "bar2", MultiBar1_IsVisible()) and true or false,   -- MultiBarBottomLeft
		bar3 = Coming(coming, "bar3", MultiBar2_IsVisible()) and true or false,   -- MultiBarBottomRight
		rackRight = nil, rackLeft = nil,
		chat = Shy.wings.chat,
		meter = MeterOn(coming) and (Shy.wings.meter or {}) or false,
		screen = UIParent:GetWidth(),
		size = L.Size(),
		style = L.Style(),
		under = 0, second = 0,
	}
	now.plates = L.Plates()
	-- How wide ShyFrames' small frames beside the plates are: the corner layouts' wings keep clear of them.
	now.beside = { left = 0, right = 0 }
	local frames = Shy.addons.Frames
	if now.plates > 0 and frames and frames.Beside then now.beside.left, now.beside.right = frames:Beside() end
	-- How far ShyFrames' risers (buff check, combo points) reach above the plates.
	local over = 0
	if now.plates > 0 then over = max(L.OVER, frames and frames.Overhang and frames:Overhang() or 0) end
	now.rise = now.plates + over + CLEAR
	now.class = UnitClassBase("player")
	now.totems = now.class == "SHAMAN"
	-- Arrange.lua docks ShyRogue's combo box in the cockpit's top edge (unless it was taken out).
	now.blades = now.class == "ROGUE" and T.db.arrange and T.db.blades and not Loose().blades
		and Shy.HUD.Find("shyrogue-combo") ~= nil
	-- The vessel's scale: everything measured is kept in design units (divided by it).
	now.scale = L.Scale()
	-- A druid's mana in a form: the display's third bar, which the vessel makes room for.
	now.altH = 0
	local display = _G.PersonalResourceDisplayFrame
	if display and display.AlternatePowerBar then
		local shown = display.AlternatePowerBar:IsShown()
		if not issecretvalue(shown) and shown then now.altH = BARS_GAP + POWER end
	end
	-- XP bar and, when a reputation is watched too, a second bar.
	local first, second = MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
	if first:IsShown() then
		now.under = first:GetHeight()
		now.second = now.under - 1   -- Blizzard stacks them sharing an edge
		if second:IsShown() then now.under = now.second + second:GetHeight() end
	end
	-- The minimap panel's size, and how far MinimapCluster's top right corner
	-- extends past the panel's (the cluster is what the layout places).
	local function Rect(frame)
		local l, b, w, h = frame:GetScaledRect()
		if l == nil or issecretvalue(l) or issecretvalue(b) or issecretvalue(w) or issecretvalue(h) then return nil end
		local originX, originY = UIParent:GetScaledRect()
		local scale = UIParent:GetEffectiveScale()
		l, b = (l - originX) / scale, (b - originY) / scale
		return l, b, l + w / scale, b + h / scale
	end
	local cl, cb, cr, ct = Rect(MinimapCluster)
	local skin = Shy.addons.Skin
	local left, bottom, right, top = nil, nil, nil, nil
	if skin and skin.MinimapPanel then left, bottom, right, top = skin:MinimapPanel() end
	if not left then left, bottom, right, top = cl, cb, cr, ct end
	now.map = {
		width = left and right - left or 256, height = top and top - bottom or 256,
		pastRight = (cr and right) and cr - right or 0, pastTop = (ct and top) and ct - top or 0,
	}
	now.tracker = Shy.wings.tracker or { 0, 0, 0, 0 }
	-- The rows under the minimap: the micro menu and, unless ShyBags keeps the bags in its window and
	-- stands the default bar down, the bag bar; each at the largest size its slider has that fits the
	-- map's width less the pad either side of them in their tray. A frame's own width and height are in its units, whatever its scale: the row at 100%.
	-- The bag bar standing as a column is as tall as its bags together, and no measure of a row: a bag
	-- button's height and the bar's padding round it is.
	local function Natural(frame, fallback)
		local w, h = frame and frame:GetWidth(), frame and frame:GetHeight()
		if w == nil or h == nil or issecretvalue(w) or issecretvalue(h) or w <= 0 or h <= 0 then return fallback end
		if frame == BagsBar and h >= 80 then
			local bag
			for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
				bag = button:GetHeight()
				break
			end
			h = (bag == nil or issecretvalue(bag)) and fallback.h or bag + 8
			w = max(w, h)
		end
		return { w = w, h = h }
	end
	now.bagsGone = Shy.addons.Bags ~= nil and Shy.addons.Bags.owns.bagbar == true
	-- The bags' row as it would stand, gone or not (L.WithBags).
	now.bagsRow = Console.RowFit(Natural(BagsBar, BAGS_NATURAL), now.map.width - 2 * Console.PAD,
		Range(System.Bags, Enum.EditModeBagsSetting.Size))
	now.column = {
		menu = Console.RowFit(Natural(_G.MicroMenu, MENU_NATURAL), now.map.width - 2 * Console.PAD, Range(System.MicroMenu, Enum.EditModeMicroMenuSetting.Size)),
		bags = not now.bagsGone and now.bagsRow or nil,
	}
	-- The menu's drawer (Drawers.lua): with it on, a pull stands over the rows and, tucked, the column keeps
	-- only the pull's room (the rows slide down out of it over what hangs below); pinned out they take
	-- their room. The layout has pull and rows under the map and is written for the drawer tucked (a setup
	-- tucks it); while the deck stands in the column Arrange.lua hangs them under the guide instead, and
	-- what hangs under them follows the pin, live.
	now.drawer = T.db.menuDrawer and T.db.arrange and true or false
	local drawer = now.drawer and Shy.Drawer and Shy.Drawer.Find("menu")
	now.tucked = now.drawer and not (drawer and drawer:IsOpen())
	-- The group column: a raid frame's size for this console size, and whether Blizzard's party frames are
	-- the ones in use (ShyFrames' party row switched off, or no ShyFrames).
	now.raid = Console.Raid(now.size)
	local frames = Shy.addons.Frames
	now.partyOurs = not (frames and frames.db and frames.db.units and frames.db.units.party)
	-- In a raid (or a party on the game's own frames) the group's frames hang from the top left corner, and the
	-- deck under them (Arrange.lua, Parts.lua).
	now.raiding = IsInRaid() or (IsInGroup() and not now.partyOurs)
	-- Your frames' sizes, for the layouts by role (Parts.lua, P.Role): ShyFrames' own while it draws them, else
	-- the game's frames' as they stand (a size the game won't tell is left to Parts' stand-ins).
	if frames and frames.Sizes then
		now.units = frames:Sizes()
	else
		now.units = {}
		local tot = _G.TargetFrame and _G.TargetFrame.totFrame
		for key, frame in pairs({ player = _G.PlayerFrame, target = _G.TargetFrame, focus = _G.FocusFrame, pet = _G.PetFrame,
			targettarget = tot }) do
			local w, h = frame:GetSize()
			if w and h and not issecretvalue(w) and not issecretvalue(h) and w > 0 and h > 0 then now.units[key] = { w, h } end
		end
	end
	-- The cockpit's rows: measured heights, or the defaults (see ROWS). Widths
	-- are kept for drawing only; they aren't part of the signature.
	now.height = UIParent:GetHeight()
	-- The screen's pixels to a unit: the vessel is planned on them (the pixel grid, below).
	local _, physical = GetPhysicalScreenSize()
	now.ppu = (physical and physical > 0 and now.height > 0) and physical / now.height or 1
	now.forms = GetNumShapeshiftForms()
	now.stances = now.forms > 0
	now.viewer, now.wide, now.tall, now.shown, now.count = {}, {}, {}, {}, {}
	local seen, k = ns.char.seen, now.scale
	for _, def in ipairs(ROWS) do
		local height = def.height
		local l, b, r, t, count = L.RowRect(def)
		-- A row with something showing in it (or secret: as it was) takes its room.
		now.shown[def.key] = l ~= nil
		if l then
			now.wide[def.key], now.tall[def.key], now.count[def.key] = (r - l) / k, (t - b) / k, count
			if not def.set then height = (t - b) / k end
			if HIDES[def.key] then
				seen[def.key] = seen[def.key] or {}
				seen[def.key][1], seen[def.key][2], seen[def.key][3] = (r - l) / k, (t - b) / k, count
			end
		elseif l == nil and HIDES[def.key] and seen[def.key] then
			-- A row shown only in combat keeps the room it had when last seen.
			now.wide[def.key], now.tall[def.key], now.count[def.key] = seen[def.key][1], seen[def.key][2], seen[def.key][3]
		elseif l == nil and HIDES[def.key] then
			-- Never seen: the room the cooldowns the character knows will take, as the viewer lays them out.
			local n = Known(def.key)
			if n and n > 0 then
				local size, gap, limit = def.height, def.gap or 2, def.limit or 8
				local across, down = min(n, limit), math.ceil(n / limit)
				now.wide[def.key], now.tall[def.key], now.count[def.key] = across * (size + gap) - gap, down * (size + gap) - gap, n
			end
		end
		if def.key == "stances" and not now.stances then height = 0 end
		now.viewer[def.key] = height
	end
	-- The viewer has an active item for every tracked buff, shown or not.
	local tracked = _G.BuffIconCooldownViewer
	now.tracked = tracked and tracked.itemFramePool:GetNumActive() or 0
	-- And for every tracked bar: the room their home keeps (L.Flap), the same whether one is up or all of them
	-- (layout mode shows them all; a fight a few).
	local bars = _G.BuffBarCooldownViewer
	local pool = bars and bars.itemFramePool
	now.barsTracked = pool and pool.GetNumActive and pool:GetNumActive() or 0
	now.buffsIn, now.buffIcon = FitBuffs(now)
	now.viewer.buffs = BUFF_BASE * now.buffIcon / 100
	now.casting = L.Casting()
	now.present = L.Present(now)
	now.rackRight, now.rackLeft = RackBars(coming)
	now.limits = {
		chatWidth = Range(System.ChatFrame, Enum.EditModeChatFrameDisplayOnlySetting.Width),
		chatHeight = Range(System.ChatFrame, Enum.EditModeChatFrameDisplayOnlySetting.Height),
		meterWidth = Range(System.DamageMeter, Meter.FrameWidth),
		meterHeight = Range(System.DamageMeter, Meter.FrameHeight),
		iconSize = Range(System.ActionBar, BarSetting.IconSize),
	}
	return now
end

-- The inputs as one string. When it differs from the one saved at setup, the
-- console is stale (L.IsStale).
local function Signature(now)
	-- The first word is the layout's shape version: change it when the plan
	-- changes shape, so layouts written by older versions read as stale.
	-- The cockpit's position isn't included: it follows live (Move.lua).
	local parts = { "tiles", Strength(), now.size, math.floor(now.height), now.forms,
		math.floor(now.viewer.stances), math.floor(now.viewer.utility), math.floor(now.viewer.essential), math.floor(now.viewer.display),
		math.floor(now.viewer.bars), math.floor(now.viewer.buffs), math.floor(now.screen), now.bar2 and 1 or 0, now.bar3 and 1 or 0, now.under, now.meter and 1 or 0, now.plates, now.rise,
		math.floor(now.map.width), math.floor(now.map.height), math.floor(now.map.pastRight), math.floor(now.map.pastTop),
		now.rackLeft or -1, now.rackRight or -1, math.floor(now.column.menu.h), math.floor(now.column.bags and now.column.bags.h or 0),
		now.partyOurs and 1 or 0, now.drawer and 1 or 0 }
	for _, wing in ipairs({ now.chat or {}, now.meter or {} }) do
		for i = 1, 4 do parts[#parts + 1] = wing[i] or 0 end
	end
	if now.style ~= Console.STYLE then parts[#parts + 1] = now.style end
	return table.concat(parts, " ")
end

L.Signature = Signature

-- Placements

local function BarSettings(size, spacing, more)
	local out = more or {}
	out[BarSetting.Orientation] = Enum.ActionBarOrientation.Horizontal
	out[BarSetting.NumRows] = 1
	out[BarSetting.IconSize] = Stored(System.ActionBar, BarSetting.IconSize, size)
	out[BarSetting.IconPadding] = Stored(System.ActionBar, BarSetting.IconPadding, spacing)
	return out
end

local function Twelve()
	return { [BarSetting.NumIcons] = Stored(System.ActionBar, BarSetting.NumIcons, Console.BUTTONS) }
end

-- A bottom bar in the housing. `fades`: a bar the minimal layout shows only in a fight (now.barsShow, written
-- when a layout is picked, so a choice made in Edit Mode since stands).
local function Row(index, row, more, fades)
	return {
		system = System.ActionBar, index = index, ours = true,
		place = function(g) return "BOTTOM", "BOTTOM", 0, g.rows[row] end,
		settings = function(_, now)
			local out = BarSettings(Console.ICON, Console.SPACING, Twelve())
			for setting, value in pairs(more or {}) do out[setting] = value end
			if fades and now.barsShow ~= nil then out[BarSetting.VisibleSetting] = now.barsShow end
			return out
		end,
	}
end

-- A small bar above one end of the housing (side -1 left, 1 right); in a layout by role, the pet and stance row
-- under the bars, in their middle (Console.Build's g.petBar).
local function End(index, side)
	return {
		system = System.ActionBar, index = index,
		place = function(g, now)
			if g.petBar then return "BOTTOM", "BOTTOM", 0, g.petBar end
			return side < 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", "BOTTOM", side * g.width / 2, g.housing.top + now.rise
		end,
		settings = function() return BarSettings(SMALL, 2) end,
	}
end

-- The cockpit's plan: x from the screen's centre, y from its bottom. Every
-- piece is placed by its bottom edge: this client's Edit Mode misplaces a frame
-- anchored by its top.
--   top, foot              the box
--   gems, gemsLeft         essential cooldowns: bottom and left
--   blades                 right end of the blades' slot
--   bars, swing            bottom of the display, and of the swing row (nil when off)
--   row, utilityLeft       bottom of the small tiles; left of the utility cooldowns
--   cast, castLeft, castWidth, castHeight, castSide, castGap   the cast bar's row and its icon (a square of the
--                          row's height at its left end, castGap from the bar); castIn: "block" (joined to
--                          the display's block, a seam under its last bar) or "own" (in a frame of its own)
--   casting                the row is open: the plate's foot (foot) is castFoot, else restFoot; low is the lower
--   hangs                  the foot of what hangs under the block at the plate's foot (nil: nothing does)
--   buffsIn, buffsRight, buffs   tracked buffs: "top" | "foot" (sharing a row) | "row" | "head" (their own),
--                          right end, bottom
--   buffsSpan              width of the tracked buffs' row with every place filled
--   over, above            bottom of what goes above the box
--   barsLeft, barsFoot     the tracked bars' seat, in their flap (nil when they are out)
--   present                what the vessel holds (L.Present)
--   scale, barsSide        the vessel's settings this plan was made with
--   m, px, scales, ppu     the grid's measures in units and in pixels, each piece's scale by seat key, and
--                          the screen's pixels a unit
--   strip                  the Shift strip's bay (L.Bay)
--   rects                  { left, bottom, right, top } per piece, for the art; barsWing is the bars' flap
-- L.Seated plans in whole pixels about (x, top);
-- L.Cockpit then adds the bars' flap and the strip's bay and turns the plan into the screen's units.
local TILE_GAP = 2   -- the small tiles' gap: the stance bar's icon padding (the game's least) and the utility cooldowns'

-- The pixel grid
--
-- The vessel is planned in whole screen pixels and only then turned into the screen's units, so every
-- padding, seam and edge lands on a pixel at any size and UI scale. A design unit is `s` pixels (the size
-- times the screen's pixels a unit); each measure is rounded once, here, and used everywhere:
--   pad, tight, clear, slot, frame, seam, rib   the plate's padding (the same on every side), the gap between
--                         its rows, between two groups of a row (and two pieces), a slot's reach, the block's
--                         frame and seams, the rib
--   gem, tile, buff       an icon; with its gap (gemGap ...) a whole number of pixels (gemPitch ...), so every
--                         icon of a row is drawn alike and a row grows by exactly that with each one learned
--   displayW, health, power, swing   the display: whole fifths of a pixel a unit, which keep its 15 and 10 whole
--   bladesW, bladesH, barW, barH, cell   the blades, a tracked bar, a button of the Shift strip
-- The game sizes a frame's contents together, so each piece gets the scale that gives its measures
-- (scales, by seat key). The icons' differ from the size by a hundredth or so; the display's goes in steps
-- of a fifth of a pixel a unit, so two sizes close together can share its step while the icons differ.
-- A button of the Shift strip; the smallest it is drawn in three rows, and in two.
local STRIP_CELL, STRIP_GOOD, STRIP_LEAST = 24, 20, 16

local function Round(v) return floor(v + 0.5) end
local function Half(v) return floor(v / 2) end

-- An icon and its gap for a whole pitch.
local function Pitch(size, gap, pitch)
	local icon = Round(size * pitch / (size + gap))
	return icon, pitch - icon, pitch
end

function L.Grid(now, k)
	k = k or L.Scale(now)
	local ppu = now.ppu or 1
	local s = k * ppu
	local function Px(units) return max(1, Round(units * s)) end
	local m = { ppu = ppu, k = k, s = s }
	m.pad, m.tight, m.clear, m.slot, m.frame, m.rib = Px(PAD_IN), Px(TIGHT), Px(CLEAR), Px(SLOT_PAD), Px(BAR_FRAME), Px(RIB)
	local fifth = max(2, Round(5 * s))
	m.displayW, m.health, m.power = DISPLAY_W * fifth / 5, HEALTH * fifth / 5, POWER * fifth / 5
	m.seam, m.swing = max(1, Round(BARS_GAP * fifth / 5)), max(2, Round(SWING_H * fifth / 5))
	m.gem, m.gemGap, m.gemPitch = Pitch(GEM_SIZE, GEM_GAP, max(8, Round((GEM_SIZE + GEM_GAP) * s)))
	m.tile, m.tileGap, m.tilePitch = Pitch(TILE_SIZE, TILE_GAP, max(8, Round((TILE_SIZE + TILE_GAP) * s)))
	m.buffBase = now.viewer and now.viewer.buffs or BUFF_BASE * BUFF / 100
	m.buff, m.buffGap, m.buffPitch = Pitch(m.buffBase, BUFF_GAP, max(8, Round((m.buffBase + BUFF_GAP) * s)))
	m.bladesH = max(4, Round(BLADES_H * s))
	m.bladesW = m.bladesH * BLADES_W / BLADES_H
	-- A tracked bar is the health bar's height, on the same fifth-pixel grid. The 30 template is drawn at
	-- BAR_H / 30 and the seat's scale puts that, and the 220, on these pixels (see scales.bars).
	m.barH = BAR_H * fifth / 5
	m.barGap = max(1, Round(BAR_GAP * fifth / 5))
	m.barPitch = m.barH + m.barGap
	m.barW = Round(BAR * m.barH / BAR_H)
	m.cell, m.cellGood, m.cellLeast = Px(STRIP_CELL), Px(STRIP_GOOD), Px(STRIP_LEAST)
	-- The cast bar's row: the health bar's height, so the spell's picture is as tall as a bar with its frame.
	m.castH = m.health
	local tiles = m.tilePitch / (TILE_SIZE + TILE_GAP) / ppu
	m.scales = {
		display = fifth / 5 / ppu, swing = fifth / 5 / ppu, essential = m.gemPitch / (GEM_SIZE + GEM_GAP) / ppu,
		utility = tiles, stances = tiles, totems = tiles, buffs = m.buffPitch / (m.buffBase + BUFF_GAP) / ppu,
		bars = m.barH / (BAR_H * ppu), blades = m.bladesH / BLADES_H / ppu, cast = k,
	}
	return m
end

-- Sets a row's icon ("gem", "tile", "buff") to `want` pixels: the whole pitch that gives it. A layout asks so
-- that what stands on one line is as tall, or at least centred on a whole pixel with it.
local function Sized(m, key)
	if key == "gem" then return GEM_SIZE, GEM_GAP, { "essential" } end
	if key == "buff" then return m.buffBase, BUFF_GAP, { "buffs" } end
	return TILE_SIZE, TILE_GAP, { "utility", "stances", "totems" }
end

local function SetPitch(m, key, pitch)
	local size, gap, seats = Sized(m, key)
	m[key], m[key .. "Gap"], m[key .. "Pitch"] = Pitch(size, gap, pitch)
	for _, seat in ipairs(seats) do m.scales[seat] = pitch / (size + gap) / m.ppu end
end

function L.Tune(m, key, want)
	local size, gap = Sized(m, key)
	local pitch = Round(want * (size + gap) / size)
	for _, try in ipairs({ pitch, pitch + 1, pitch - 1 }) do
		if Round(size * try / (size + gap)) == want then
			pitch = try
			break
		end
	end
	SetPitch(m, key, pitch)
end

-- The same icon a pixel taller or shorter, whichever is nearer its drawn size, when it and `beside` differ
-- in evenness: two things centred on one line then share its pixel.
function L.Even(m, key, beside)
	if (m[key] - beside) % 2 == 0 then return end
	local size = Sized(m, key)
	L.Tune(m, key, size * m.s < m[key] and m[key] - 1 or m[key] + 1)
end

-- A row of `count` icons made to fit `room` pixels: the biggest whole pitch that does, never under `least`
-- of its own (then nothing changes and it answers false). With `beside`, a pitch whose icon is centred on a
-- whole pixel with something that tall is taken first.
function L.Squeeze(m, key, count, room, least, beside)
	local size, gap = Sized(m, key)
	local pitch = m[key .. "Pitch"]
	local fits, match
	for try = pitch, max(4, math.ceil(pitch * least)), -1 do
		local icon = Round(size * try / (size + gap))
		if count * try - (try - icon) <= room then
			fits = fits or try
			if not beside or (icon - beside) % 2 == 0 then
				match = try
				break
			end
		end
	end
	if not fits then return false end
	if (match or fits) ~= pitch then SetPitch(m, key, match or fits) end
	return true
end

-- A plan begun: its grid, its top edge's middle on a pixel, and what the vessel holds. In pixels (x from the
-- screen's middle, y from its foot) until L.Cockpit turns it into units.
function L.Begin(now, top)
	local m = L.Grid(now)
	local c = { m = m }
	c.x = Round((T.db.cockpitX or 0) * m.ppu)
	c.top = Round((top or floor(now.height * T.db.cockpit / 100 + 0.5)) * m.ppu)
	c.present = now.present or L.Present(now)
	return c, m
end

-- The rows every layout is made of, in pixels: what each holds, how wide and tall it is, and the room it
-- keeps. A row is counted, not measured: so many icons at the grid's pitch, whatever the frames say to a
-- fraction. No sockets: the rows stand in the plate, `tight` apart, and the plate hugs them.
-- `fit`: the width a row may take ({ tiles =, buffs = }); one that is longer is drawn smaller until it fits
-- (L.Squeeze), so the plate keeps its width however much is learned.
function L.Lines(c, now, fit)
	local m, present = c.m, c.present
	local wide, tall, shown = now.wide or {}, now.tall or {}, now.shown or {}
	-- A row's icons across and down, and how many in all. Counted from the icons that show (Now's count)
	-- and the row's shape, which say the same at whatever scale the row stands; from its width where there
	-- is no count. nil for a row never seen.
	local function Count(key, size, gap)
		local w, h, n = wide[key], tall[key] or size, (now.count or {})[key]
		if not w then return nil end
		local pitch = size + gap
		if not n or n < 1 or h <= 0 then
			local across, down = max(1, Round((w + gap) / pitch)), max(1, Round((h + gap) / pitch))
			return across, down, across * down
		end
		local best, miss
		for across = 1, n do
			local shape = (across * pitch - gap) / (math.ceil(n / across) * pitch - gap)
			local off = abs(shape * h / w - 1)
			if not miss or off < miss then best, miss = across, off end
		end
		return best, math.ceil(n / best), n
	end
	local r = {}
	-- The utility cooldowns as they were last seen; never seen, there are none to keep room for.
	local utilityAcross, utilityDown = Count("utility", TILE_SIZE, TILE_GAP)
	utilityAcross, utilityDown = utilityAcross or 0, utilityDown or 1
	if fit then
		local stances = (present.stances and (now.forms or 0) > 0) and now.forms or 0
		local utility = present.utility and utilityAcross or 0
		if fit.tiles and stances + utility > 0 then
			L.Squeeze(m, "tile", stances + utility, fit.tiles - ((stances > 0 and utility > 0) and (m.clear - m.tileGap) or 0), 0.6)
		end
		if fit.buffs and present.buffs and (now.tracked or 0) > 0 then L.Squeeze(m, "buff", now.tracked, fit.buffs, 0.6) end
	end
	-- The gems: so many across and down. Unseen, the room of one row of two.
	local across, down, gems = Count("essential", GEM_SIZE, GEM_GAP)
	across, down, gems = across or 2, down or 1, gems or 2
	r.gemsWide, r.gemsTall = across * m.gemPitch - m.gemGap, down * m.gemPitch - m.gemGap
	-- How many there are, across and in all, for a drawing of them (the last row may not be full).
	c.gemsAcross, c.gemsCount = across, gems
	-- They take room only while they show (out of a fight they may not): the plate hugs what shows.
	r.gems = present.gems and shown.essential ~= false
	-- The small tiles: the stances, then the utility cooldowns, `clear` between. The utility cooldowns that
	-- show nothing are 0 wide; tilesRoom is the row with them. Seats go by the room, so nothing is seated
	-- anew when they come with a fight; only the plate's edge goes by what shows.
	local forms = now.forms or 0
	-- Forms alone do not grow the plate: a warrior always has stances, and the foot stays hugged until
	-- those icons (or the utility cooldowns) actually show. `shown.stances ~= false` keeps a plan that
	-- has not measured the row yet (drawings, the pixel grid) as it was.
	c.stanceWidth = (present.stances and forms > 0 and now.shown.stances ~= false) and (forms * m.tilePitch - m.tileGap) or 0
	local room = (present.utility and utilityAcross > 0) and (utilityAcross * m.tilePitch - m.tileGap) or 0
	r.utility = shown.utility ~= false and room or 0
	r.tilesTall = (room > 0 and utilityDown or 1) * m.tilePitch - m.tileGap
	local function Both(utility) return c.stanceWidth + utility + ((c.stanceWidth > 0 and utility > 0) and m.clear or 0) end
	r.tilesW, r.tilesRoom = Both(r.utility), Both(room)
	-- The tracked buffs: a place for every one tracked, up or not.
	r.count = now.tracked or 0
	c.buffsSpan = r.count > 0 and (r.count * m.buffPitch - m.buffGap) or 0
	-- The buffs that are up, from the first to the last of them: the row's shape gives how many places that is.
	local places = 3
	if wide.buffs and (tall.buffs or 0) > 0 then
		places = max(1, Round((wide.buffs / tall.buffs * m.buffBase + BUFF_GAP) / (m.buffBase + BUFF_GAP)))
	end
	r.buffsWide = places * m.buffPitch - m.buffGap
	r.buffH = m.buff
	r.buffsUp = present.buffs and r.count > 0
	-- A rogue's blades in their slot.
	r.blades = now.blades and true or false
	r.bladesW, r.bladesH = m.bladesW + 2 * m.slot, m.bladesH + 2 * m.slot
	-- The display's bars a seam apart (a druid's mana the third), and the swing row's growth under them.
	r.displayH = m.health + m.seam + m.power + ((now.altH or 0) > 0 and (m.seam + m.power) or 0)
	r.grow = present.swing and (m.seam + m.swing) or 0
	r.span = m.displayW + 2 * m.frame   -- the block's width: what seated and stacked set every row on
	-- The cast bar's row is open while a cast is up: it joins the block, and the plate's foot goes down
	-- with it, the foot row riding the foot still. (The stance bar and the totem bar are protected: in a
	-- fight the game holds them where they are until it ends, and Shy.HUD seats them then.)
	r.cast = present.cast and now.casting == true
	return r
end

-- How far a second row of utility cooldowns hangs under the first. The first row is the one on the
-- border; one row hangs nothing.
function L.Hang(m, tall)
	return max(0, (tall or 0) - m.tile)
end

-- The display's block with its top at `y` (the swing row in it), or its seat waiting: returns its foot.
function L.Stand(c, r, y)
	local m, present = c.m, c.present
	c.displayLeft = c.x - m.displayW / 2
	if present.display then
		c.bars = y - m.frame - r.displayH
		c.swing = present.swing and (c.bars - r.grow) or nil
		return (c.swing or c.bars) - m.frame
	end
	c.bars = y - r.displayH
	-- With no display the swing row stands alone in the block's frame (Cockpit.lua's Block).
	if not present.swing then
		c.swing = nil
		return y
	end
	c.swing = y - m.frame - m.swing
	return c.swing - m.frame
end

-- A plan's rects, and the cast bar's row: the block's width, the spell's picture a square of the row's
-- height, then a seam, then the bar. It joins the block (a seam under its last bar, in the block's frame)
-- while the vessel holds the display (`c.castJoin`): the plate's foot is lower by the row while a cast is
-- up and the foot row, if any, rides it down (the builder has moved it, `c.grown`). With the display out it
-- hangs under what is left in a frame of its own, `clear` under what hangs at the foot (`c.hangs`) or under
-- the plate, and the plate is as it was. c.restFoot keeps the plate's foot at rest, c.castFoot the vessel's
-- foot with the row open, c.low the lower.
function L.Finish(c, r, box, blades)
	local m, present = c.m, c.present
	local s = m.slot
	local tilesRight = c.utilityLeft + r.utility
	local ub = c.utilityRow or c.row
	local tilesBottom = min(c.row, ub)
	-- The foot row from the first utility cooldown to the last stance, or round whichever of them there is.
	local stances = c.stanceWidth > 0 and { c.stancesLeft, c.row, c.stancesLeft + c.stanceWidth, c.row + m.tile } or nil
	local tl = (stances and r.utility == 0) and stances[1] or c.utilityLeft
	local tr = stances and stances[3] or tilesRight
	c.rects = {
		box = box,
		gems = { c.gemsLeft - s, c.gems - s, c.gemsLeft + r.gemsWide + s, c.gems + r.gemsTall + s },
		blades = blades,
		display = { c.displayLeft, c.bars, c.displayLeft + m.displayW, c.bars + r.displayH },
		swing = c.swing and { c.displayLeft, c.swing, c.displayLeft + m.displayW, c.swing + m.swing } or nil,
		stances = stances,
		utility = { c.utilityLeft, ub, tilesRight, ub + max(r.tilesTall, m.tile) },
		tiles = { tl - s, tilesBottom - s, tr + s, c.row + m.tile + s },
		buffs = { c.buffsRight - r.buffsWide, c.buffs, c.buffsRight, c.buffs + r.buffH },
	}
	local F, H, P = m.frame, m.castH, m.pad
	local grow = m.seam + H
	local bl = c.displayLeft - F
	local br = bl + m.displayW + 2 * F
	local joined = c.castJoin and present.display
	local top
	if joined then
		top = (c.swing or c.bars) - m.seam
	else
		local under = c.hangs or ((present.display or present.swing) and (c.swing or c.bars) - F or (box[2] + P))
		top = under - m.clear - F
	end
	c.castIn = joined and "block" or "own"
	c.cast = top - H
	c.castLeft = bl + F + H + m.seam
	c.castWidth = br - F - c.castLeft
	c.castHeight, c.castSide, c.castGap = H, H, m.seam
	-- The row's rect: with its frame, or up to the seam that joins it to the block.
	c.rects.cast = { bl, c.cast - F, br, joined and top or (top + F) }
	c.casting = r.cast
	if joined then
		if r.cast and not c.grown then box[2] = box[2] - grow end
		c.restFoot = r.cast and (box[2] + grow) or box[2]
		c.castFoot = c.restFoot - grow
	else
		-- Apart, the row hangs under the plate's foot row in its own frame, and the plate is as it was: the
		-- foot row rides the plate's foot still.
		c.restFoot = box[2]
		c.castFoot = c.cast - F
	end
	c.low = min(c.restFoot, c.castFoot)
	c.foot = box[2]
	return c
end

-- The cooldown manager's one layout: three rows in one plate set on the display's span, which the plate always
-- is: its width never changes as cooldowns are learned, and the bars stand `pad` in from it on every side. It
-- is a mirror: what you press stands at the left, what is happening to you at the right. The top row: the
-- gems at the left, growing rightward (a second row of them stands over the first); a rogue's blades, else
-- the tracked buffs, at the right. The display's block. The foot row: the utility cooldowns at the left, the
-- stances (a shaman's totems) at the right end, a rogue's tracked buffs left of the stances. Tracked buffs too many to stand beside what they share a row
-- with are drawn a little smaller, and past that stand in a row of their own over the vessel. A row that
-- holds nothing takes no room, except the gems', which keeps the room it had while they wait for a fight, so
-- nothing moves when one starts. The gems (and the blades) ride the plate's top edge and the first row of
-- tiles rides its foot, half of each outside it, so the plate is a band round the display with the rows
-- mounted on it. A second row of utility cooldowns hangs under that first row. With nothing to ride an
-- edge, the edge is `pad` from the bars, like the sides, and the tracked buffs
-- stand at its right end where they would ride: the plate is never shaped by a buff, which comes and goes
-- all through a fight. The cast bar in its piece under it all.
function L.Seated(now, top)
	local c, m = L.Begin(now, top)
	local present = c.present
	local P, G, CL = m.pad, m.tight, m.clear
	local W = m.displayW + 2 * m.frame
	local cl = c.x - W / 2
	local cr = cl + W
	-- What shares a row is centred on one line with it.
	local beside = now.blades and "tile" or "gem"
	local fit = { tiles = W, buffs = W }
	local r = L.Lines(c, now, fit)
	L.Even(m, "buff", m[beside])
	r = L.Lines(c, now, fit)
	-- Where the tracked buffs go: beside the gems; a rogue's beside the tiles; else a row of their own.
	local taken = r.blades and r.tilesRoom or (present.gems and r.gemsWide or 0)
	local room = W - taken - (taken > 0 and CL or 0)
	local share = r.buffsUp and (c.buffsSpan <= room or L.Squeeze(m, "buff", r.count, room, 0.85, m[beside]))
	if share then r = L.Lines(c, now, fit) end
	local topShare, footShare = share and not r.blades, share and r.blades
	local own = r.buffsUp and not share
	local left, right = cl - P, cr + P
	-- The row that rides the top edge: the gems' first row (their room kept while they are the vessel's, shown
	-- or not), the blades, the buffs that share it. More rows of gems stand over it.
	-- The plan's top is that row's: a second row of gems grows upward from it and moves nothing.
	-- The plate's edge rides it only for the gems and the blades: tracked buffs come and go all through a
	-- fight (the game keeps a place for each, up or not), so the plate is never shaped by them, in no layout.
	local band = max(present.gems and m.gem or 0, topShare and r.buffH or 0, r.blades and r.bladesH or 0)
	local shows = max(r.gems and m.gem or 0, r.blades and r.bladesH or 0)
	local y, edge, blades = c.top, nil, nil
	c.gemsLeft, c.gems = cl, y - m.gem
	c.buffsIn, c.buffsRight, c.buffs = "top", cr, c.top
	if band > 0 then
		local foot = y - band
		if shows > 0 then edge = y - Half(band) end
		c.gems = foot + Half(band - m.gem)
		if r.blades then
			c.blades = cr - m.slot
			local by = foot + Half(band - m.bladesH)
			blades = { c.blades - m.bladesW, by, c.blades, by + m.bladesH }
		end
		if topShare then c.buffs = foot + Half(band - r.buffH) end
		y = foot - G
	end
	if band == 0 then y = y - P end
	-- Nothing rides the top edge: the plate hugs what it holds.
	edge = edge or (y + P)
	-- Tracked buffs with no row to share stand over the vessel at its right end: over the gems while those
	-- show, else over the plate. They come and go all through a fight, so they are given no room in the plate
	-- that would stand empty without them. A group apart, `clear` over what they stand on: the game's alert
	-- round a cooldown (a flash, marching ants) reaches past the icon, and must not reach into them.
	local stand = r.gems and (c.gems + r.gemsTall) or (shows > 0 and c.top or edge)
	if own then c.buffsIn, c.buffs = "above", stand + CL end
	local blockTop = y
	y = L.Stand(c, r, y)
	-- The cast bar's row joins the block while a cast is up, and what is under the block goes down with the
	-- plate's foot: the foot row rides it still.
	c.castJoin = present.display
	if r.cast and c.castJoin then
		y = y - (m.seam + m.castH)
		c.grown = true
	end
	if y ~= blockTop then y = y - G end
	-- The foot row: the first row of tiles rides the plate's foot, half above it and half below. A second
	-- row of utility cooldowns hangs under that and does not move it. The utility cooldowns' room is kept
	-- while they wait for a fight, so the seats stay put when one starts; only the plate's edge goes by
	-- what shows.
	local first = m.tile
	local hang = (present.tiles and r.tilesRoom > 0) and L.Hang(m, r.tilesTall) or 0
	local ride = (present.tiles and r.tilesRoom > 0) and first or 0
	local footH = max(ride, footShare and r.buffH or 0)
	local tilesShow = (present.tiles and r.tilesW > 0) and first or 0
	local footShows = tilesShow
	local hug = (y ~= blockTop and y + G or y) - P   -- the foot with nothing hanging from it
	-- The utility cooldowns from the left end, under the gems; the stances at the right end, under what is on you.
	-- The stance bar's seat goes by the forms the character has, shown or not, so it stands at the right end
	-- the moment it shows.
	local forms = now.forms or 0
	c.utilityLeft = cl
	c.stancesLeft = cr - max(c.stanceWidth, forms > 0 and (forms * m.tilePitch - m.tileGap) or 0)
	c.totemsRight = cr
	if footH > 0 then
		c.row = y - footH + Half(footH - first)
		if footShare then
			c.buffsIn = "foot"
			c.buffsRight = c.stancesLeft - (c.stanceWidth > 0 and CL or 0)
			c.buffs = y - footH + Half(footH - r.buffH)
		end
		-- The foot runs through the first row while it shows. The cast bar's row keeps clear of what hangs
		-- under it: a second utility row, or the buffs' places there (up or not: a buff must not move the
		-- cast bar); with neither it joins the block.
		c.foot = footShows > 0 and (y - Half(footH)) or hug
		c.hangs = (tilesShow > 0 or footShare or hang > 0) and (y - footH - hang) or nil
	else
		c.row = y - m.tile
		c.foot = hug
	end
	c.utilityRow = c.row - hang
	-- What goes above the vessel stands over the topmost thing there, the buffs' places with a buff up or not.
	c.over = max(stand, (own or topShare) and (c.buffs + r.buffH) or stand) + CL
	c.above = c.over
	c.shows = { gems = r.gems, utility = r.utility > 0, buffs = r.buffsUp }
	return L.Finish(c, r, { left, c.foot, right, edge }, blades)
end

-- The tracked bars' flap: a plate of the vessel's make beside it (c.barsSide), joined by a rib where the two
-- overlap. The first bar's foot is the health bar's; more bars grow upward. The wing hugs the bars with the
-- plate's padding. Nothing when the bars are out.
function L.Flap(c, now)
	local present, m = c.present, c.m
	if not present.bars then
		c.barsLeft, c.barsFoot, c.rects.bars, c.rects.barsWing, c.rects.rib, c.barsUp = nil, nil, nil, nil, nil, nil
		return
	end
	local box, wide = c.rects.box, now.wide or {}
	local up = wide.bars and ((now.count or {}).bars or max(1, Round((now.viewer.bars + BAR_GAP) / BAR_PITCH))) or 2
	-- A home of their own keeps room for every bar tracked, not only those up now.
	c.barsUp = (now.barsTracked or 0) > 0 and now.barsTracked or up
	local barsH = up * m.barPitch - m.barGap
	local w, h = m.barW + 2 * m.pad, barsH + 2 * m.pad
	local display = present.display and c.rects.display
	local foot = display and (display[4] - m.barH) or (box[2] + m.pad)
	local bottom = foot - m.pad
	local function Band()
		local y0, y1 = max(bottom, box[2]), min(bottom + h, box[4])
		if y1 < y0 then y0, y1 = box[2], box[2] end
		return y0, y1
	end
	local left
	if c.barsSide == "right" then
		left = box[3] + m.rib
		local y0, y1 = Band()
		c.rects.rib = { box[3], y0, left, y1 }
	else
		left = box[1] - m.rib - w
		local y0, y1 = Band()
		c.rects.rib = { left + w, y0, box[1], y1 }
	end
	c.rects.barsWing = { left, bottom, left + w, bottom + h }
	c.barsLeft, c.barsFoot = left + m.pad, foot
	c.rects.bars = { c.barsLeft, c.barsFoot, c.barsLeft + m.barW, c.barsFoot + barsH }
end

-- The tracked bars' home in a classic layout: a seam off the plate on their side (c.barsSide), standing on its
-- foot and growing up, a bar wide and as tall as every bar tracked (c.barsUp); the pings and markers take the
-- plate's other side (Arrange.lua), so the two flank the cooldown manager as a pair.
function L.Beside(c)
	local m, box = c.m, c.rects.box
	local w = m.barW + 2 * m.pad
	local h = c.barsUp * (m.barH + m.barGap) - m.barGap + 2 * m.pad
	local l = c.barsSide == "right" and box[3] + Console.SEAM or box[1] - Console.SEAM - w
	return { l, box[2], l + w, box[2] + h }
end

-- The tracked bars' home `r` where the player dragged it in layout mode (ns.char.barsAt: its left edge from the
-- screen's middle and its top edge), its size kept and inside the screen's corners; as planned otherwise.
function L.Moved(r, now)
	local at = ns.char.barsAt
	if not at then return r end
	local w, h = r[3] - r[1], r[4] - r[2]
	local edge = now.screen / 2 - CORNER
	local l = max(-edge, min(edge - w, at[1]))
	local top = max(CORNER + h, min(now.height - CORNER, at[2]))
	return { l, top - h, l + w, top }
end

-- The tracked bars moved to a home of their own (c.barsApart; a layout by role: Parts.lua's P.BarsHome), in
-- screen units: `r` its housing, the bars inside it by the plate's padding, as wide as it. `grow` is the edge it
-- keeps: "down" hangs the bars from its top edge, "up" stands them on its foot; the bars that show are seated
-- against that edge (Seat) and the housing hugs them from it (Cockpit.lua's Flap).
function L.Home(c, r, grow)
	local m = c.m
	c.rects.barsWing, c.rects.rib, c.barsApart, c.barsGrow = r, nil, true, grow == "up" and "up" or "down"
	c.barsLeft, c.barsFoot, c.barsTop = r[1] + m.pad, r[2] + m.pad, r[4] - m.pad
	c.barsWidth = r[3] - r[1] - 2 * m.pad
	c.rects.bars = { c.barsLeft, c.barsFoot, r[3] - m.pad, c.barsTop }
end

-- The Shift strip's bay (ShyTip's pings and markers): the plate grown at one end, as tall as the plate, with
-- the plate's own padding round a grid of buttons. Its end is the one the tracked bars' flap is not at. The
-- grid goes by the plate's height: three rows of four (the pings over the markers), two rows of six (the
-- pings two by two, then the markers) or one row of twelve, whichever gives the biggest button, and the
-- buttons with their gaps fill the height to the pixel, or stand centred in it.
--   side, left, bottom, width, height   the bay
--   cell, gap, rows, columns            the grid
--   at[1..12]                           a button's top left corner from the bay's: the four pings, then the markers
function L.Bay(c)
	local m, box = c.m, c.rects.box
	local P = m.pad
	-- The plate at rest: a cast opening its row under it changes nothing of the bay.
	local foot = c.restFoot or box[2]
	-- A plate lower than a button (the display taken out): the bay is as tall as one, from the plate's foot.
	local tall = max(box[4] - foot, m.cellLeast + 2 * P)
	local inner = tall - 2 * P
	-- The most rows whose buttons are still a good size: the bay stays narrow.
	local rows, cell = 1, min(m.cell, inner)
	for _, count in ipairs({ 3, 2 }) do
		local fit = min(m.cell, floor((inner - (count - 1) * m.tight) / count))
		if fit >= (count == 3 and m.cellGood or m.cellLeast) then
			rows, cell = count, fit
			break
		end
	end
	local gap = m.tight
	local spare = inner - rows * cell - (rows - 1) * gap
	if rows == 1 then
		if spare % 2 == 1 then cell, spare = cell - 1, spare + 1 end
	elseif spare % (rows - 1) ~= 0 then
		cell, spare = cell - 1, spare + rows
	end
	-- A pixel or two over goes into the gaps, so the grid fills the height; more than that and it is centred.
	local down = 0
	if rows > 1 and spare / (rows - 1) <= m.tight then
		gap = gap + spare / (rows - 1)
	else
		down = Half(spare)
	end
	local columns = rows == 3 and 4 or rows == 2 and 6 or 12
	local pings = rows == 3 and 4 or rows == 2 and 2 or 4   -- columns the pings take
	local apart = rows == 3 and 0 or max(0, P - gap)          -- between the pings and the markers
	local width = 2 * P + columns * cell + (columns - 1) * gap + apart
	local at = {}
	local function Put(index, column, row)
		at[index] = { P + (column - 1) * (cell + gap) + (column > pings and apart or 0), P + down + (row - 1) * (cell + gap) }
	end
	for i = 1, 4 do
		if rows == 2 then Put(i, (i - 1) % 2 + 1, floor((i - 1) / 2) + 1) else Put(i, i, 1) end
	end
	for i = 1, 8 do
		if rows == 3 then
			Put(4 + i, (i - 1) % 4 + 1, 2 + floor((i - 1) / 4))
		elseif rows == 2 then
			Put(4 + i, 2 + (i - 1) % 4 + 1, floor((i - 1) / 4) + 1)
		else
			Put(4 + i, 4 + i, 1)
		end
	end
	local side = (c.present.bars and c.barsSide == "right") and "left" or "right"
	c.strip = { side = side, left = side == "left" and box[1] - width or box[3], bottom = foot, width = width,
		height = tall, cell = cell, gap = gap, rows = rows, columns = columns, at = at }
end

-- A plan from pixels into the screen's units: every place and size divided by the pixels a unit. The grid's
-- measures go with it (c.m in units, c.px as planned), and each piece's scale (c.scales).
local PLACED = { "x", "top", "gemsLeft", "blades", "utilityLeft", "stancesLeft", "totemsRight", "castLeft", "buffsRight",
	"displayLeft", "barsLeft", "gems", "bars", "swing", "row", "utilityRow", "cast", "castFoot", "restFoot", "low", "hangs", "over", "above",
	"buffs", "foot", "barsFoot", "castWidth", "castHeight", "castSide", "castGap", "buffsSpan", "stanceWidth" }
local MEASURES = { "pad", "tight", "clear", "slot", "frame", "rib", "seam", "displayW", "health", "power", "swing", "gem", "gemGap",
	"tile", "tileGap", "buff", "buffGap", "bladesW", "bladesH", "barW", "barH", "barGap", "cell", "castH" }
function L.Units(c)
	local px = c.m
	local ppu = px.ppu
	for _, key in ipairs(PLACED) do
		if c[key] then c[key] = c[key] / ppu end
	end
	local done = {}
	for _, r in pairs(c.rects) do
		if not done[r] then
			done[r] = true
			for i = 1, 4 do r[i] = r[i] / ppu end
		end
	end
	local strip = c.strip
	if strip then
		for _, key in ipairs({ "left", "bottom", "width", "height", "cell", "gap" }) do strip[key] = strip[key] / ppu end
		for _, at in ipairs(strip.at) do at[1], at[2] = at[1] / ppu, at[2] / ppu end
	end
	local m = {}
	for _, key in ipairs(MEASURES) do m[key] = px[key] / ppu end
	c.px, c.m, c.scales, c.scale, c.ppu = px, m, px.scales, px.k, ppu
	return c
end

local function Cockpit(now, top)
	now.present = now.present or L.Present(now)
	local function Make(at)
		local c = L.Seated(now, at)
		c.barsSide = L.BarsSide(now)
		L.Flap(c, now)
		L.Bay(c)
		return L.Units(c)
	end
	local c = Make(top)
	-- In a layout by role the vessel stands just over the bars under your character's feet: its foot (with the
	-- cast bar's row open) a gap over the housing and its racks, whatever its height setting; a place the
	-- player dragged it to is Move.lua's.
	local role = Console.ROLES[now.style]
	if role then
		local g = Console.Build(now)
		if not top then
			local base = max(g.housing.top, g.rack and g.rack.top or 0) + CLEAR
			if abs(c.low - base) > 0.5 then c = Make(c.top + base - c.low) end
		end
		-- The tracked bars have a home of their own on your side (Parts.lua, P.BarsHome), no rib joining it to the
		-- plate, wherever the plate is dragged: planned against the frames as a fight shows them (the healer's group
		-- over the plate at its own height), as the frames themselves are (Arrange.lua), so the two always agree.
		if c.rects.barsWing then
			local fight = (rawget(now, "fight") and not top) and c or L.Fighting(now)
			local plan = ns.Parts.Role(g, now, fight, ns.Parts.ThreatPiece())
			if plan and plan.bars then L.Home(c, L.Moved(plan.bars, now), plan.barsGrow) end
		end
		return c
	end
	-- At its default height the vessel perches a seam over the party's row over the plates, lifted or
	-- lowered to it, however tall the housing under it, with room for the cast bar's row under it; a height
	-- the player chose is kept.
	if not top and (now.plates or 0) > 0 and T.db.cockpit == T.defaults.cockpit then
		local party = Console.Build(now).housing.top + now.rise + now.plates + CLEAR
		if abs(c.low - party) > 0.5 then c = Make(c.top + party - c.low) end
	end
	-- The tracked bars have a home of their own here too, beside the plate (L.Beside); joined (a setting), its flap.
	if c.rects.barsWing and not T.db.joined then L.Home(c, L.Moved(L.Beside(c), now), "up") end
	return c
end

-- The plan as a fight shows it: the rows that wait for one (and were seen in one) showing. The Shift strip is
-- stood for both beforehand, since a fight can start while it is up.
function L.Fighting(now)
	return Cockpit(L.Shown(now))
end

-- The plan's inputs with the rows that wait for a fight showing (those ever seen): a fight, or with `all`
-- a drawing of the vessel with everything it has, a cast up too.
function L.Shown(now, all)
	local shown = {}
	for key, value in pairs(now.shown or {}) do shown[key] = value end
	for key in pairs(HIDES) do
		if (now.wide or {})[key] then shown[key] = true end
	end
	-- fight: a plan made from these is the one a layout by role homes the tracked bars by (Cockpit).
	return setmetatable({ shown = shown, casting = all and true or nil, fight = true }, { __index = now })
end

-- A piece's seat: anchor point, x, y. Both the layout (PLACES) and live moves
-- (Move.lua) use these, so they agree. nil for a piece the plan has no seat for.
local function Seat(key, c)
	if key == "display" then return "BOTTOMLEFT", c.displayLeft, c.bars end
	if key == "essential" then return "BOTTOMLEFT", c.gemsLeft, c.gems end
	if key == "stances" then return "BOTTOMLEFT", c.stancesLeft or c.displayLeft, c.row end
	if key == "utility" then return "BOTTOMLEFT", c.utilityLeft, c.utilityRow or c.row end
	if key == "totems" then return "BOTTOMRIGHT", c.totemsRight or (c.displayLeft + DISPLAY_W), c.row end
	if key == "cast" then return "BOTTOMLEFT", c.castLeft, c.cast end
	if key == "buffs" then
		if c.buffsIn == "over" or c.buffsIn == "middle" then return "BOTTOM", c.x, c.buffs end
		return "BOTTOMRIGHT", c.buffsRight, c.buffs   -- they grow leftward
	end
	if key == "bars" then
		if not c.barsLeft then return nil end
		-- The viewer keeps a place for every tracked bar (hidden ones still sit in the layout). Seat the
		-- frame so the bars that show stand at the health bar's foot, not the empty slot under them.
		-- In a home of their own that hangs them from its top edge (L.Home, "down") the topmost bar that shows is put
		-- under that edge, still by the frame's bottom corner (nothing of the cockpit is anchored by its top); one that
		-- stands them on its foot ("up") is seated as beside the plate, by the lowest bar that shows.
		local down = c.barsApart and c.barsGrow == "down"
		local x, y = c.barsLeft, down and (c.barsTop - c.m.barH) or c.barsFoot
		local sl, sb, st, vl, vb
		for _, def in ipairs(ROWS) do
			if def.key == "bars" then
				local _
				sl, sb, _, st = L.RowRect(def)
				break
			end
		end
		local viewer = _G.BuffBarCooldownViewer
		if viewer then vl, vb = Console.Rect(viewer) end
		if sl and vl then
			x = x - (sl - vl)
			y = down and (c.barsTop - (st - vb)) or (y - (sb - vb))
		end
		return "BOTTOMLEFT", x, y
	end
	local r = c.rects[key]   -- swing, blades
	if r then return "BOTTOMLEFT", r[1], r[2] end
	return nil
end
local function SeatAt(key, now)
	local point, x, y = Seat(key, Cockpit(now))
	if not point then return nil end
	return point, "BOTTOM", x, y
end
function L.Seat(key, c) return Seat(key, c) end

function L.Cockpit(now) return Cockpit(now) end
L.CORNER = CORNER
L.BOX = { w = BOX_W, h = EDGE_H }
L.GEM = { size = GEM_SIZE, gap = GEM_GAP }
L.TILE = { size = TILE_SIZE, gap = TILE_GAP }
L.BUFF = { gap = BUFF_GAP, pad = SLOT_PAD }
L.BARS = { health = HEALTH, power = POWER, gap = BARS_GAP }
-- Tracked-bar size as Edit Mode writes it (never assigned onto BuffBarCooldownViewer: that taints
-- the viewer's aura map). Icon size shortens the 30 template to the health bar; width scale puts the 220 back;
-- padding is what the viewer takes 4 off of so the bars stand BAR_GAP apart.
L.TRACKED = { icon = BAR_H / BAR_TEMPLATE, width = BAR_TEMPLATE / BAR_H, pad = BAR_GAP + 4 }

-- Where an extra ability comes up, and an encounter's bar: over the cockpit, centred on it, each in a
-- place of its own. The slot's foot is a little over what the cockpit mounts on its top line, or over the
-- game's three swing timers while those show (the swing row isn't ours). c: the cockpit's plan. written:
-- at the game's own size, as the Edit Mode layout has it; else at the slot's size, as it is seated in play.
--   -> { x, scale (the game's frame's), foot, button = { l, b, r, t }, extra (the game's frame's foot),
--        encounter (the bar's foot) }, in screen units
function L.Over(c, written)
	local k = written and 1 or EXTRA_SCALE * (c.scale or 1)
	-- Close over the cockpit's top line, unless the game's own swing timers stand there (the cockpit's
	-- swing row off and the game keeping time): then over them. Edit Mode's layout keeps room for them.
	local theirs = not T.db.swing and C_CVar.GetCVarBool("showSwingTimer")
	local foot = c.above + ((written or theirs) and (SWING + 2 * SWING_STEP + EXTRA) or EXTRA_OVER)
	if written and T.db.swing then foot = c.above + EXTRA_OVER end
	local half = EXTRA_BUTTON * k / 2
	return {
		x = c.x, scale = k, foot = foot,
		button = { c.x - half, foot, c.x + half, foot + 2 * half },
		extra = foot - EXTRA_DROP * k,
		encounter = foot + 2 * half + EXTRA_GAP,
	}
end

-- A system centred above the cockpit, `more` above c.above.
local function Above(system, index, more)
	return {
		system = system, index = index,
		place = function(_, now)
			local c = Cockpit(now)
			return "BOTTOM", "BOTTOM", c.x, c.above + more
		end,
	}
end

local Viewer = Enum.EditModeCooldownViewerSetting
local Display = Enum.EditModePersonalResourceDisplaySetting

-- A cockpit row at its seat with its settings: the display, a cooldown viewer,
-- or (with `bar`) the stance or possess bar.
local function Seated(key, bar)
	local def
	for _, row in ipairs(ROWS) do
		if row.key == key then def = row end
	end
	local entry = { ours = true, place = function(_, now) return SeatAt(key, now) end }
	if bar then
		entry.system, entry.index = System.ActionBar, bar
		entry.settings = function() return BarSettings(TILE, TILE_GAP) end
	elseif def.core then
		entry.system = System.PersonalResourceDisplay or -1
		entry.settings = function()
			if not Display then return {} end
			return {
				[Display.BarWidth] = Stored(entry.system, Display.BarWidth, DISPLAY),
				[Display.HealthBarHeight] = Stored(entry.system, Display.HealthBarHeight, HEALTH),
				[Display.PowerBarHeight] = Stored(entry.system, Display.PowerBarHeight, POWER),
				[Display.Padding] = Stored(entry.system, Display.Padding, BARS_PAD),
				[Display.ShowBarText] = 1,
				-- The box has room for a druid's mana in a form, not for the class bar (see EXTRAS in Cockpit.lua).
				[Display.HideClassInfo] = 1,
				[Display.HideAltPower] = 0,
			}
		end
	else
		entry.system = System.CooldownViewer or -1
		entry.index = Enum.EditModeCooldownViewerSystemIndices and Enum.EditModeCooldownViewerSystemIndices[def.viewer]
		entry.settings = function(_, now)
			if not Viewer then return {} end
			local out = {
				[Viewer.Orientation] = def.bars and Enum.CooldownViewerOrientation.Vertical or Enum.CooldownViewerOrientation.Horizontal,
				[Viewer.IconSize] = Stored(entry.system, Viewer.IconSize, def.fit and now.buffIcon or def.size or 100),
				-- A viewer subtracts 4 from its padding (GetAdditionalPaddingOffset), so add it back.
				[Viewer.IconPadding] = Stored(entry.system, Viewer.IconPadding, (def.gap or 2) + 4),
			}
			if Viewer.IconDirection and Enum.CooldownViewerIconDirection and Enum.CooldownViewerIconDirection.Right then
				-- A column of bars stacks up with Right and down with Left (CooldownViewerMixin:RefreshLayout): away from
				-- the edge their home keeps in a layout by role (L.Home), up from the health bar's foot beside the plate.
				local home = def.bars and now and Console.ROLES[now.style] and Cockpit(now)
				local left = def.leftward or (home and home.barsApart and home.barsGrow == "down")
				out[Viewer.IconDirection] = left and Enum.CooldownViewerIconDirection.Left or Enum.CooldownViewerIconDirection.Right
			end
			if def.limit then out[Viewer.IconLimit] = Stored(entry.system, Viewer.IconLimit, def.limit) end
			if def.bars then
				-- Icon size shortens the 30 template to the health bar. The width scale puts the 220 back.
				out[Viewer.BarWidthScale] = Stored(entry.system, Viewer.BarWidthScale, BAR_TEMPLATE / BAR_H * 100)
				out[Viewer.BarContent] = Enum.CooldownViewerBarContent.IconAndName
			end
			return out
		end
	end
	return entry
end

-- The XP bar and the second status bar: under the floor, a seam short of each
-- end of the console (as close as the size slider's steps allow).
local TRIM = 2 * Console.SEAM

local function Under(index, height)
	return {
		system = System.StatusTrackingBar, index = index, ours = true,
		-- (By role, under the bars and the pet bar: g.xp.)
		place = function(g, now) return "BOTTOM", "BOTTOM", (g.left + g.right) / 2, (g.xp or 0) + height(now) end,
		settings = function(g)
			local percent = (g.right - g.left - TRIM) / MainStatusTrackingBarContainer:GetExpectedWidth() * 100
			return { [Enum.EditModeStatusTrackingBarSetting.Size] =
				Stored(System.StatusTrackingBar, Enum.EditModeStatusTrackingBarSetting.Size, percent) }
		end,
	}
end

-- Inset of the minimap column from the screen's right edge.
local function ColumnEdge()
	return CORNER
end

-- A side bar in its rack (side -1 left, 1 right). Which bar depends on which
-- are on (RackBars), so `index` is a function. Upright at a wing's outer end
-- in the console; a shelf beside the housing, at the bars' size, in the open layout.
local function Rack(side)
	return {
		system = System.ActionBar, ours = true,
		index = function(now) return side > 0 and now.rackRight or now.rackLeft end,
		when = function(_, g) return side > 0 and g.rack.right or g.rack.left end,
		place = function(g)
			local slot = g.rack.slots[side]
			return side > 0 and "BOTTOMLEFT" or "BOTTOMRIGHT", "BOTTOM", slot[1], slot[2]
		end,
		settings = function(g)
			return {
				[BarSetting.Orientation] = g.rack.flat and Enum.ActionBarOrientation.Horizontal or Enum.ActionBarOrientation.Vertical,
				[BarSetting.NumRows] = g.rack.lines,   -- on a vertical bar, "rows" are columns
				[BarSetting.NumIcons] = Stored(System.ActionBar, BarSetting.NumIcons, g.rack.icons),
				[BarSetting.IconSize] = Stored(System.ActionBar, BarSetting.IconSize, g.rack.percent),
				[BarSetting.IconPadding] = Stored(System.ActionBar, BarSetting.IconPadding, Console.SPACING),
			}
		end,
	}
end
local function NotLocked(info) return Value(info, Enum.EditModeCastBarSetting.LockToPlayerFrame) ~= 1 end

-- A layout by role's plan of your frames, the group and the threat meter (Parts.lua, P.Role), with the vessel
-- as a fight has it (the healer's group stands over it); nil in a classic layout.
local function RolePlan(g, now)
	if not g.role then return nil end
	return ns.Parts.Role(g, now, L.Fighting(now))
end

-- Where the raid frames (and the game's party frames) hang from: the group column's top left corner, or by role
-- the role's group's top left corner.
local function GroupAt(g, now)
	local plan = RolePlan(g, now)
	if plan then return "TOPLEFT", "TOPLEFT", plan.group[1] + now.screen / 2, plan.group[4] - now.height end
	return "TOPLEFT", "TOPLEFT", CORNER + Console.RAID_TAB + Console.SEAM, -CORNER
end

-- The game's own layout's anchor for a system (the first preset), to give back what a layout by role moved.
local function Preset(system, index)
	local presets = EditModePresetLayoutManager:GetCopyOfPresetLayouts()
	local info = presets and presets[1] and Find(presets[1], system, index)
	return info and info.anchorInfo
end

-- One of the game's unit frames: by role at its place in the plan, by its foot's middle (a frame placed by its
-- top is misplaced on this client); in a classic layout given back the game's own place, once, after a layout by
-- role had it (ns.char.roleFrames).
local function GameFrame(index, key)
	return {
		system = System.UnitFrame, index = index, ours = true,
		when = function(_, g) return g.role ~= nil or ns.char.roleFrames == true end,
		place = function(g, now)
			local plan = RolePlan(g, now)
			if plan then
				local r = plan[key]
				return "BOTTOM", "BOTTOM", (r[1] + r[3]) / 2, r[2]
			end
			local a = Preset(System.UnitFrame, index)
			if a then return a.point, a.relativePoint, a.offsetX, a.offsetY, a.relativeTo end
		end,
	}
end

local PLACES = {
	-- `ours`: always placed. The main bar's art and page arrows would poke out of the housing.
	Row(Bar.MainBar, "main", { [BarSetting.HideBarArt] = 1, [BarSetting.HideBarScrolling] = 1 }),
	Row(Bar.Bar2, "bar2", nil, true),
	Row(Bar.Bar3, "bar3", nil, true),
	{
		system = System.ChatFrame, ours = true,
		place = function(g) return "BOTTOMRIGHT", "BOTTOM", g.chat.right, g.chat.bottom end,
		settings = function(g)
			return {
				[Chat.WidthHundreds] = floor(g.chat.width / 100), [Chat.WidthTensAndOnes] = g.chat.width % 100,
				[Chat.HeightHundreds] = floor(g.chat.height / 100), [Chat.HeightTensAndOnes] = g.chat.height % 100,
			}
		end,
	},
	{
		system = System.DamageMeter, ours = true,
		when = function(_, g) return g.meter ~= nil end,
		place = function(g) return "BOTTOMLEFT", "BOTTOM", g.meter.left, g.meter.bottom end,
		-- Background at the core's opacity so the wing matches the housing; bars solid, no row padding.
		settings = function(g, now)
			local out = {
				[Meter.FrameWidth] = Stored(System.DamageMeter, Meter.FrameWidth, g.meter.width),
				[Meter.FrameHeight] = Stored(System.DamageMeter, Meter.FrameHeight, g.meter.height),
				[Meter.Padding] = Stored(System.DamageMeter, Meter.Padding, 0),
				[Meter.Transparency] = Stored(System.DamageMeter, Meter.Transparency, 100),
				[Meter.BackgroundTransparency] = Stored(System.DamageMeter, Meter.BackgroundTransparency, Strength()),
			}
			if now.wear then out[Meter.TextSize] = Stored(System.DamageMeter, Meter.TextSize, now.wear.meter) end
			if now.shows then out[Meter.Visibility] = now.shows end
			return out
		end,
	},
	-- The gryphons, hidden through their own Edit Mode setting.
	{ system = System.MainActionBarEndCap, index = Enum.EditModeMainActionBarEndCapSystemIndices.EndCapLeft, ours = true,
		settings = function() return { [Enum.EditModeMainActionBarEndCapSetting.Hidden] = 1 } end },
	{ system = System.MainActionBarEndCap, index = Enum.EditModeMainActionBarEndCapSystemIndices.EndCapRight, ours = true,
		settings = function() return { [Enum.EditModeMainActionBarEndCapSetting.Hidden] = 1 } end },

	-- Systems Blizzard anchors to the main bar, placed only while still in their default position.
	Under(Enum.EditModeStatusTrackingBarSystemIndices.StatusTrackingBar1, function() return 0 end),
	Under(Enum.EditModeStatusTrackingBarSystemIndices.StatusTrackingBar2, function(now) return now.second end),
	End(Bar.PetActionBar, 1),
	{
		system = System.VehicleLeaveButton,
		place = function(g, now) return "BOTTOMLEFT", "BOTTOM", -g.width / 2, g.housing.top + now.rise end,
	},
	Rack(1),
	Rack(-1),
	-- Minimap column
	{
		system = System.Minimap, ours = true,
		place = function(_, now)
			local map = now.map
			return "TOPRIGHT", "TOPRIGHT", -ColumnEdge(now) + map.pastRight, -CORNER + map.pastTop
		end,
	},
	{
		system = System.ObjectiveTracker, ours = true,
		place = function(_, now)
			-- Written for the drawer tucked: under its pull.
			local column = Console.Column({ screen = now.screen, height = now.height, map = now.map, column = now.column,
				drawer = now.drawer, tucked = now.drawer })
			return "TOPRIGHT", "TOPRIGHT", -ColumnEdge(now) - now.tracker[3], column.foot - now.height - UNDER_MAP + now.tracker[2]
		end,
	},
	{
		-- System -1 matches nothing in a layout, so the entry is inert where the enum is missing.
		system = System.AuraFrame or -1, index = Enum.EditModeAuraFrameSystemIndices and Enum.EditModeAuraFrameSystemIndices.BuffFrame,
		place = function(_, now) return "TOPRIGHT", "TOPRIGHT", -ColumnEdge(now) - now.map.width - BUFFS_GAP, -BUFFS_TOP end,
	},
	-- The rows under the minimap, in their tray: a pad in from its right edge, which is the map's
	-- (Console.Column). The micro menu's size scales its buttons
	-- inside the frame the layout places, so its offsets are in screen units; the bag bar's size scales
	-- the bar itself, and a layout's offsets are in the frame's own scale, so its are divided by it.
	{
		system = System.MicroMenu, ours = true,
		place = function(_, now)
			local column = Console.Column(now)
			return "TOPRIGHT", "TOPRIGHT", column.menu[3] - now.screen / 2, column.menu[4] - now.height
		end,
		settings = function(_, now)
			local out = { [Enum.EditModeMicroMenuSetting.Orientation] = Enum.MicroMenuOrientation.Horizontal }
			if Enum.EditModeMicroMenuSetting.Size then
				out[Enum.EditModeMicroMenuSetting.Size] = Stored(System.MicroMenu, Enum.EditModeMicroMenuSetting.Size, now.column.menu.percent)
			end
			return out
		end,
	},
	{
		system = System.Bags, ours = true,
		when = function(_, _, now) return now.column.bags ~= nil end,
		place = function(_, now)
			local column, s = Console.Column(now), now.column.bags.percent / 100
			return "TOPRIGHT", "TOPRIGHT", (column.bags[3] - now.screen / 2) / s, (column.bags[4] - now.height) / s
		end,
		settings = function(_, now)
			return {
				[Enum.EditModeBagsSetting.Orientation] = Enum.BagsOrientation.Horizontal,
				[Enum.EditModeBagsSetting.Direction] = Enum.BagsDirection.Left,
				[Enum.EditModeBagsSetting.Size] = Stored(System.Bags, Enum.EditModeBagsSetting.Size, now.column.bags.percent),
			}
		end,
	},
	-- The group column: the raid frames from the top left corner, past the raid manager's folded tab, five
	-- to a row with the groups stacked, a frame's size by the console's. Blizzard's party frames stand in
	-- the same corner while they are the party frames in use; their own settings are left alone. In a layout
	-- by role both stand where the role has the group (GroupAt), grouped as it says.
	{
		system = System.UnitFrame, index = Enum.EditModeUnitFrameSystemIndices.Raid, ours = true,
		place = function(g, now) return GroupAt(g, now) end,
		settings = function(g, now)
			local U = Enum.EditModeUnitFrameSetting
			local plan = RolePlan(g, now)
			return {
				[U.RaidGroupDisplayType] = Enum.RaidGroupDisplayType[plan and plan.raid or "SeparateGroupsHorizontal"],
				[U.FrameWidth] = Stored(System.UnitFrame, U.FrameWidth, now.raid.w),
				[U.FrameHeight] = Stored(System.UnitFrame, U.FrameHeight, now.raid.h),
				[U.DisplayBorder] = 0,
			}
		end,
	},
	{
		system = System.UnitFrame, index = Enum.EditModeUnitFrameSystemIndices.Party, ours = true,
		when = function(_, _, now) return now.partyOurs end,
		place = function(g, now) return GroupAt(g, now) end,
	},
	-- Your frame, your target's and your focus as the game draws them (while ShyFrames doesn't draw its own): by
	-- role where the role has them; in a classic layout back where the game's own layout has them.
	GameFrame(Enum.EditModeUnitFrameSystemIndices.Player, "player"),
	GameFrame(Enum.EditModeUnitFrameSystemIndices.Target, "target"),
	GameFrame(Enum.EditModeUnitFrameSystemIndices.Focus, "focus"),
	-- Cockpit
	Seated("display"),
	Seated("essential"),
	Seated("stances", Bar.StanceBar),
	Seated("stances", Bar.PossessActionBar),   -- shown in place of the stance bar
	{ system = System.TotemActionBar, place = function(_, now) return SeatAt("totems", now) end },
	Seated("utility"),
	-- Always placed unless locked to the player frame (see WasSeated).
	{ system = System.CastBar, ours = true, when = NotLocked,
		place = function(_, now) return SeatAt("cast", now) end,
		-- Scale 100% so the offsets are in screen units; Cockpit.lua sets the bar's size.
		settings = function()
			local S = Enum.EditModeCastBarSetting
			if not (S and S.BarSize and Slider(System.CastBar, S.BarSize)) then return {} end
			return { [S.BarSize] = Stored(System.CastBar, S.BarSize, 100) }
		end },
	Seated("buffs"),
	Seated("bars"),
	Above(System.SwingTimer, Enum.EditModeSwingTimerSystemIndices.MainHand, SWING),
	Above(System.SwingTimer, Enum.EditModeSwingTimerSystemIndices.OffHand, SWING + SWING_STEP),
	Above(System.SwingTimer, Enum.EditModeSwingTimerSystemIndices.Ranged, SWING + 2 * SWING_STEP),
	-- The extra ability's slot and an encounter's bar over it (L.Over), at the game's own size: in play the
	-- slot is seated a little smaller, live (Extras.lua).
	{ system = System.ExtraAbilities, place = function(_, now)
		local over = L.Over(Cockpit(now), true)
		return "BOTTOM", "BOTTOM", over.x, over.extra
	end },
	{ system = System.EncounterBar, place = function(_, now)
		local over = L.Over(Cockpit(now), true)
		return "BOTTOM", "BOTTOM", over.x, over.encounter
	end },
}

local function Key(system, index)
	return system .. ":" .. (index or 0)
end

-- Is this cockpit piece seated? Always, except the cast bar while Edit Mode has
-- it locked to the player frame. (A cast bar left where the player had moved it
-- tends to overlap the cockpit, so it is seated even when not in its default position.)
function L.WasSeated(key)
	if key ~= "cast" then return true end
	local bar = PlayerCastingBarFrame
	return not (bar and bar:IsAttachedToPlayerFrame())
end

-- Is this still where an earlier setup put it?
local function StillOurs(info, was)
	local anchor = info.anchorInfo
	return was and anchor and anchor.point == was[1]
		and abs(anchor.offsetX - was[2]) < 0.5 and abs(anchor.offsetY - was[3]) < 0.5
end

-- Write the console into a layout. again: the layout is ours from an earlier
-- run, so what that run placed may be placed again.
local function Write(layout, g, now, again)
	local was = again and ns.char.placed or {}
	local placed, taken = {}, {}
	for _, def in ipairs(PLACES) do
		local index = def.index
		if type(index) == "function" then
			index = index(now)
			if index == nil then index = false end   -- a rack with no bar
		end
		local info = index ~= false and Find(layout, def.system, index) or nil
		local key = Key(def.system, index)
		local mine = info and (def.ours or info.isInDefaultPosition or StillOurs(info, was[key]))
		if mine and def.when and not def.when(info, g, now) then mine = false end
		if mine and def.with and not taken[def.with] then mine = false end
		if mine then
			taken[def.system] = true
			local point, relativePoint, x, y, relativeTo
			if def.place then point, relativePoint, x, y, relativeTo = def.place(g, now, taken) end
			if point then
				info.anchorInfo = { point = point, relativeTo = relativeTo or "UIParent", relativePoint = relativePoint, offsetX = x, offsetY = y }
				info.anchorInfo2 = nil
				info.isInDefaultPosition = false
				placed[key] = { point, x, y }
			end
			if def.settings then
				for setting, value in pairs(def.settings(g, now)) do Set(info, setting, value) end
			end
		end
	end
	return placed
end

-- Layouts

local function Presets() return Enum.EditModePresetLayoutsMeta.NumValues end

local function IsMine(layout)
	return layout and layout.layoutName == L.NAME and layout.layoutType == Character
end

-- Index of our layout in the saved list, or nil.
local function Mine(saved)
	for i, layout in ipairs(saved) do
		if IsMine(layout) then return i end
	end
end

-- Index for a new character layout: after the character's last, else after the
-- account's (as MakeNewLayout does). nil when the character is at the limit.
local function NewIndex(saved)
	local count, lastOfAccount, lastOfCharacter = 0, nil, nil
	for i, layout in ipairs(saved) do
		if layout.layoutType == Character then
			count, lastOfCharacter = count + 1, i
		else
			lastOfAccount = i
		end
	end
	if count >= Constants.EditModeConsts.EditModeMaxLayoutsPerType then return nil end
	return Presets() + (lastOfCharacter or lastOfAccount or 0) + 1
end

-- C_EditMode.GetLayouts hands over every layout whole, new each time (hundreds of KB), and "is it in use" is
-- asked from some thirty places, in bursts. What is only read is read from one hand-over, kept until the game
-- says its layouts changed or one is written here, and HOLD seconds at most. (Whatever writes asks the game
-- itself, and drops this. At half a second, the /shy window's rail, which asks twice a second whether the
-- console is in use, had every layout handed over anew each time: 57 ms and 260 KB.)
local HOLD = 60
local held, heldAt
local function Layouts()
	local now = GetTime()
	if not held or now - heldAt >= HOLD then held, heldAt = C_EditMode.GetLayouts(), now end
	return held
end
local function Forget() held = nil end
L.Forget = Forget

-- ShyCore's Shy.Role: the tank and healer layouts say whose screen this is while one is in use, so threat reads
-- as theirs with no group role given. Told a frame later: the game may be applying a layout from inside a call.
local function TellRole()
	if not ns.char then return end
	local style = L.IsActive() and L.Style() or nil
	Shy.SetLayoutRole((style == "tank" or style == "healer") and style or nil)
end
local layoutNews = CreateFrame("Frame")
layoutNews:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
layoutNews:SetScript("OnEvent", function()
	Forget()
	C_Timer.After(0, TellRole)
end)
Shy:On("SHY_LOGIN", TellRole)

function L.Exists()
	return Mine(Layouts().layouts) ~= nil
end

function L.IsActive()
	local info = Layouts()
	return IsMine(info.layouts[info.activeLayout - Presets()])
end

-- Is this system still where the console's setup put it, in the layout in use? (A piece the player moved
-- in Edit Mode since isn't; nor is anything while another layout is in use.)
function L.InPlace(system, index)
	local info = Layouts()
	local layout = info.layouts[info.activeLayout - Presets()]
	if not IsMine(layout) then return false end
	local entry = Find(layout, system, index)
	return entry ~= nil and StillOurs(entry, ns.char.placed[Key(system, index)]) == true
end

-- Was the console set up for different inputs than now, or with the old bar
-- order (the main bar below another that is on: see Console.ORDER)?
function L.IsStale()
	if ns.char.built == nil then return false end
	local now = Now()
	local placed = ns.char.placed
	local main = placed[Key(System.ActionBar, Bar.MainBar)]
	for row, index in pairs({ bar2 = Bar.Bar2, bar3 = Bar.Bar3 }) do
		local other = placed[Key(System.ActionBar, index)]
		if now[row] and main and other and main[3] < other[3] - 1 then return true end
	end
	return ns.char.built ~= Signature(now)
end

-- A setup measures the screen before its reload, and the reload moves what it measures (the pieces only
-- stand where it wrote them now): the first login after a setup takes the inputs as they stand.
function L.Settle()
	if not ns.char.settle then return end
	ns.char.settle = nil
	if L.IsActive() then ns.char.built = Signature(Now()) end
end

-- The inputs saved at setup and today's, for the position report.
function L.Signatures()
	return ns.char.built or "-", Signature(Now())
end

-- Bars that grow with the character

-- Each step: which of bars 2 to 5 are on. Rows fill the housing from the floor
-- up; bar 4, the first side bar, is there from the start for food, potions and
-- the like. A step holds its rows' buttons less SPARE for what isn't an ability.
L.STEPS = {
	{ bar2 = false, bar3 = false, right = true, left = false, rows = 1, sides = 1 },
	{ bar2 = true, bar3 = false, right = true, left = false, rows = 2, sides = 1 },
	{ bar2 = true, bar3 = true, right = true, left = false, rows = 3, sides = 1 },
	{ bar2 = true, bar3 = true, right = true, left = true, rows = 3, sides = 2 },
}
L.SPARE = 2
L.KEYED = 4   -- the step a layout of keys needs: three rows, and both side bars (the flyouts) for the number row
-- The game's switches (GetActionBarToggles) and action pages (MultiActionBars.lua) of bars 2 to 5.
local TOGGLED = {
	{ key = "bar2", toggle = 1, bar = 2, page = "BOTTOMLEFT_ACTIONBAR_PAGE" },
	{ key = "bar3", toggle = 2, bar = 3, page = "BOTTOMRIGHT_ACTIONBAR_PAGE" },
	{ key = "right", toggle = 3, bar = 4, page = "RIGHT_ACTIONBAR_PAGE" },
	{ key = "left", toggle = 4, bar = 5, page = "LEFT_ACTIONBAR_PAGE" },
}

-- Abilities that go on a bar: active spells and flyouts in the spellbook, each
-- name once (ranks share it). Guild perks, hidden lines and other specs' don't count.
function L.Abilities()
	local seen, count = {}, 0
	local bank = Enum.SpellBookSpellBank.Player
	local spell, flyout = Enum.SpellBookItemType.Spell, Enum.SpellBookItemType.Flyout
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info and not info.isGuild and not info.shouldHide and not info.offSpecID then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if item and (item.itemType == spell or item.itemType == flyout) and not item.isPassive and not item.isOffSpec then
					local name = item.name
					if name ~= nil and not issecretvalue(name) and not seen[name] then
						seen[name] = true
						count = count + 1
					end
				end
			end
		end
	end
	return count
end

-- Buttons a step has room for: its rows, and a second side bar.
function L.Room(i)
	local step = L.STEPS[i]
	return (step.rows + step.sides - 1) * Console.BUTTONS - L.SPARE
end

-- The smallest step with room for this many abilities.
function L.StepFor(abilities)
	for i = 1, #L.STEPS do
		if abilities <= L.Room(i) then return i end
	end
	return #L.STEPS
end

-- The smallest step that has every bar in `on` ({ bar2, bar3, right, left }).
local function Holds(on)
	for i, step in ipairs(L.STEPS) do
		local all = true
		for _, def in ipairs(TOGGLED) do
			if on[def.key] and not step[def.key] then all = false end
		end
		if all then return i end
	end
	return #L.STEPS
end

-- Does this bar hold anything? Its buttons keep their actions while it's off.
local function Holding(def)
	local first = (_G[def.page] - 1) * Console.BUTTONS
	for slot = first + 1, first + Console.BUTTONS do
		local has = HasAction(slot)
		if not issecretvalue(has) and has then return true end
	end
	return false
end

-- The step the bars are at now (the game's switches).
function L.StepNow()
	local toggles, on = { GetActionBarToggles() }, {}
	for _, def in ipairs(TOGGLED) do on[def.key] = toggles[def.toggle] and true or false end
	return Holds(on)
end

-- The step a grown setup gives: what the abilities need, and never fewer bars than hold something.
function L.GrowStep()
	local on = {}
	for _, def in ipairs(TOGGLED) do on[def.key] = Holding(def) end
	return max(L.StepFor(L.Abilities()), Holds(on))
end

function L.Grows()
	return ns.char.grow and true or false
end

-- Will a setup now switch the damage meter on? While ShyCore's setup window is
-- open its game settings decide; otherwise a first setup does (Furnish).
local function MeterComing()
	local picked = Shy.Setup.Picked("damageMeter")
	if picked ~= nil then return picked end
	return not ns.char.furnished
end

-- The plan now, or at another size and layout. whole: as a setup would leave
-- it, everything Furnish turns on counted as on, or with `grow` the bars of the
-- step the abilities call for (for the previews): true for that step, a number
-- for a step, "all" for every bar (the "every bar now" choice), nil or false
-- for the bars as they are.
function L.Plan(size, whole, style, grow)
	local coming = false
	if whole then
		coming = { meter = MeterComing() or nil }
		if grow == "all" or (not grow and not ns.char.furnished) then
			coming.bar2, coming.bar3, coming.right, coming.left = true, true, true, true
		elseif grow then
			local step = L.STEPS[type(grow) == "number" and grow or L.GrowStep()]
			coming.bar2, coming.bar3, coming.right, coming.left = step.bar2, step.bar3, step.right, step.left
		end
	end
	local now = Now(coming)
	if size then now.size = size end
	if Console.STYLES[style] then now.style = style end
	return Console.Build(now), now
end

-- A plan's inputs with the bags' row under the menu's, or without it, whatever stands now: a choice not
-- made yet (the previews), or one that waits for a reload (a setup).
function L.WithBags(now, on)
	now.bagsGone = not on
	now.column.bags = on and now.bagsRow or nil
end

-- Cooldowns in combat only: the essential and utility rows' own Edit Mode visibility, written into
-- the console's layout. The game applies a layout's settings at a reload.

local function ViewerInfo(layout, key)
	return Find(layout, System.CooldownViewer, Enum.EditModeCooldownViewerSystemIndices[HIDES[key]])
end

-- Writes the option into `layout`. fresh: the layout was just copied from the player's, so what
-- the rows had is theirs. Turned off, each row gets back what it had before (ns.char.shown).
-- Returns true when something changed.
local function Visibility(layout, fresh)
	local visible = Enum.CooldownViewerVisibleSetting
	if fresh then wipe(ns.char.shown) end
	local was, changed = ns.char.shown, false
	for key in pairs(HIDES) do
		local info = ViewerInfo(layout, key)
		if info then
			local now, want = Value(info, Viewer.VisibleSetting), nil
			if T.db.cooldownsInCombat then
				if was[key] == nil then was[key] = now or visible.Always end
				want = visible.InCombat
			elseif was[key] ~= nil then
				want, was[key] = was[key], nil
			end
			if want ~= nil and want ~= now then
				Set(info, Viewer.VisibleSetting, want)
				changed = true
			end
		end
	end
	return changed
end

-- Does the layout in use show this cooldown row ("essential" or "utility") only in combat?
function L.CombatOnly(key)
	local info = Layouts()
	local layout = info.layouts[info.activeLayout - Presets()]
	local entry = layout and ViewerInfo(layout, key)
	return entry ~= nil and Value(entry, Viewer.VisibleSetting) == Enum.CooldownViewerVisibleSetting.InCombat
end

-- Does a fight beginning or ending show or hide any of these frames (global names) by its own setting: an action
-- bar's visibility in Edit Mode ("InCombat", "OutOfCombat"), a cooldown viewer's? Only then can a fight's edge
-- move what is measured round them. Read from the frames, as the game keeps them; nothing is written.
L.FIGHT_SHOWN = { InCombat = true, OutOfCombat = true }
function L.FightShows(names)
	local viewer = Enum.CooldownViewerVisibleSetting and Enum.CooldownViewerVisibleSetting.InCombat
	for _, name in ipairs(names) do
		local frame = rawget(_G, name)
		if type(frame) == "table" then
			local bar, rows = rawget(frame, "visibility"), rawget(frame, "visibleSetting")
			if (type(bar) == "string" and L.FIGHT_SHOWN[bar]) or (viewer ~= nil and rows == viewer) then return true end
		end
	end
	return false
end

-- The option changed: written into the console's layout at once if it is in use, with the reload
-- asked for; otherwise it waits for the next setup. In a fight, once the fight is over.
local afterFight
function L.CooldownsInCombat()
	if not L.IsActive() then return end
	if InCombatLockdown() then
		if not afterFight then
			afterFight = CreateFrame("Frame")
			afterFight:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				L.CooldownsInCombat()
			end)
		end
		afterFight:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	Forget()
	local info = C_EditMode.GetLayouts()
	local mine = Mine(info.layouts)
	if not (mine and Visibility(info.layouts[mine])) then return end
	C_EditMode.SaveLayouts(info)
	Forget()
	Shy.Reload("The cooldown setting is saved. Reload to apply it.")
end

-- The option is on but the console's layout in use was written without it. The layout is never
-- rewritten unasked, so this is only said (once per character).
function L.CooldownsWaiting()
	return T.db.cooldownsInCombat and next(ns.char.shown) == nil and L.IsActive() and not L.CombatOnly("essential")
end

-- First setup, and per-size text

-- A character's first setup turns on what the console is built from, the way
-- the default options do:
--     SetActionBarToggles    bars 2 and 3 (housing), 4 and 5 (racks)
--     damageMeterEnabled     the right wing
--     cooldownViewerEnabled  the cockpit's cooldowns
--     nameplateShowSelf      the personal resource display
-- Once per character (ns.char.furnished): what the player turns off later stays off.
-- With a step (bars that grow), every setup sets bars 2 to 5 to that step's.
-- From ShyCore's setup window the last three are its game settings' to switch
-- (opts.pieces = false): the game step runs first, and here only the bars are.
local DISPLAY_CVAR = "nameplateShowSelf"
local PIECES = {
	{ cvar = "damageMeterEnabled", name = "the damage meter" },
	{ cvar = "cooldownViewerEnabled", name = "the cooldown manager" },
	{ cvar = DISPLAY_CVAR, name = "the personal resource display" },
}

-- A layout by role has a slim vessel with no health and power block, so the game's own display goes off as
-- it is set up (ns.char.displayOff remembers it was this that put it off) and comes back with a classic
-- layout. ShyCore's game step leaves the setting alone while a layout by role is in use (T:HoldsDisplay).
local function SlimDisplay(slim)
	if slim then
		if C_CVar.GetCVarBool(DISPLAY_CVAR) then
			ns.char.displayOff = true
			C_CVar.SetCVar(DISPLAY_CVAR, "0")
		end
	elseif ns.char.displayOff then
		ns.char.displayOff = nil
		C_CVar.SetCVar(DISPLAY_CVAR, "1")
	end
end

function L.HoldsDisplay()
	return L.IsActive() and L.Slim()
end

-- "a", "a and b", "a, b and c".
local function Listed(items)
	if #items < 3 then return table.concat(items, " and ") end
	return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end

local function Bars(numbers)
	return (#numbers > 1 and "action bars " or "action bar ") .. Listed(numbers)
end

-- Returns what to pass to Now as `coming`: what a first setup just turned on
-- (every bar, and the meter unless `pieces` is false), the step's bars with a
-- step, else false. `slim`: the lift layout is being set up, whose vessel has no
-- place for the personal resource display: it is left off.
local function Furnish(step, pieces, slim)
	local first = not ns.char.furnished
	if not (first or step) then return false end
	ns.char.furnished = true
	pieces = first and pieces
	local new, gone = {}, {}
	local coming = { meter = pieces or nil }
	local on, bars = { GetActionBarToggles() }, {}
	local was = { on[1], on[2], on[3], on[4] }
	if step then
		local want = L.STEPS[step]
		for _, def in ipairs(TOGGLED) do
			local now = want[def.key]
			coming[def.key] = now
			if now and not on[def.toggle] then bars[#bars + 1] = tostring(def.bar) end
			if on[def.toggle] and not now then gone[#gone + 1] = tostring(def.bar) end
			on[def.toggle] = now
		end
	elseif first then
		for _, def in ipairs(TOGGLED) do
			if not on[def.toggle] then bars[#bars + 1] = tostring(def.bar) end
			on[def.toggle] = true
			coming[def.key] = true
		end
	end
	if on[1] ~= was[1] or on[2] ~= was[2] or on[3] ~= was[3] or on[4] ~= was[4] then
		SetActionBarToggles(on[1] or false, on[2] or false, on[3] or false, on[4] or false, on[5] or false, on[6] or false, on[7] or false)
	end
	if #bars > 0 then new[#new + 1] = Bars(bars) end
	if pieces then
		for _, piece in ipairs(PIECES) do
			if not C_CVar.GetCVarBool(piece.cvar) and not (slim and piece.cvar == DISPLAY_CVAR) then
				C_CVar.SetCVar(piece.cvar, "1")
				new[#new + 1] = piece.name
			end
		end
	end
	ns.char.news = #new > 0 and Listed(new) or nil
	ns.char.stowed = #gone > 0 and Bars(gone) or nil
	return coming
end

-- Text sizes per console size: chat font size, and the meter's Edit Mode text size in percent.
L.WEAR = {
	compact = { chat = 11, meter = 90 },
	roomy = { chat = 12, meter = 100 },
	grand = { chat = 14, meter = 110 },
}

-- Only the saved setting is written (SetChatWindowSize); the windows read it
-- after the reload. No FCF_ function is called: chat must stay untainted.
local function Wear(wear)
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(i)
		if shown or docked then SetChatWindowSize(i, wear.chat) end
	end
end

-- After the reload: report what the setup turned on, and what it put away.
local function Tell()
	local news, stowed = ns.char.news, ns.char.stowed
	ns.char.news, ns.char.stowed = nil, nil
	if news then
		T:Print("setup turned on " .. news
			.. ". Turn any of them off in the game's options; setting up again won't turn them back on.")
	end
	if stowed then
		T:Print("put away " .. stowed .. " until you learn more abilities. Their buttons are kept.")
	end
end
Shy:On("SHY_LOGIN", function() C_Timer.After(4, Tell) end)

-- Live: the setup window's picks go on the screen as they are made. The layout is written and applied
-- at once (Activate), with no reload. Edit Mode applying a layout for an addon leaves what it writes
-- tainted until the next reload, so the window's Finish reloads, and closing it puts back what stood
-- before the first pick (Unpreview) and asks for one (Owed).
local before   -- what stood before the first live pick: the layouts, the bars' switches, chat's text sizes, ns.char
local owed     -- a layout was applied live since the last reload
local wearing  -- a live pick waiting for the bars it switched on (L.Wear)

local function Hold()
	if before then return end
	local chat = {}
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local _, size = GetChatWindowInfo(i)
		chat[i] = size
	end
	before = { info = C_EditMode.GetLayouts(), toggles = { GetActionBarToggles() }, chat = chat, char = Shy.CopyTable(ns.char),
		display = C_CVar.GetCVar(DISPLAY_CVAR) }
end

-- Applies layout `index` now (or by `call`, which makes it the one in use). The game applies one from inside
-- SetActiveLayout (EDIT_MODE_LAYOUTS_UPDATED); for the one already in use it may not, and then it is sent to
-- another and back.
local applied = false
local applying = CreateFrame("Frame")
applying:SetScript("OnEvent", function() applied = true end)
local function Activate(index, call)
	applied = false
	applying:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	if call then call() else C_EditMode.SetActiveLayout(index) end
	if not applied then
		C_EditMode.SetActiveLayout(index == 1 and 2 or 1)
		C_EditMode.SetActiveLayout(index)
	end
	applying:UnregisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	Forget()
	owed = true
end

-- Bars 2 to 5 switched: the game shows them as its options would, once its switches have come back from
-- the server; then the pieces built round them are laid again.
local function ShowBars()
	for _, wait in ipairs({ 0.3, 1 }) do
		C_Timer.After(wait, function()
			if InCombatLockdown() then return end
			MultiActionBar_Update()
			T:Apply()
		end)
	end
end

function L.Previewing() return before ~= nil end
function L.Owed() return owed == true end

-- Finish: what is on the screen is the answer. The bars it switched on or put away since the first pick are
-- told after the reload, as a setup's are.
function L.Keep()
	local was = before
	before, wearing = nil, nil
	if not was then return end
	local on, new, gone = { GetActionBarToggles() }, {}, {}
	for _, def in ipairs(TOGGLED) do
		if on[def.toggle] and not was.toggles[def.toggle] then new[#new + 1] = tostring(def.bar) end
		if was.toggles[def.toggle] and not on[def.toggle] then gone[#gone + 1] = tostring(def.bar) end
	end
	ns.char.news = #new > 0 and Bars(new) or nil
	ns.char.stowed = #gone > 0 and Bars(gone) or nil
end

-- Puts back what stood before the first live pick: the layouts as they were (ours taken out again when a
-- pick added it), the one in use, the bars' switches, chat's text sizes and this character's console
-- settings. In a fight, once it is over.
local putting
function L.Unpreview()
	wearing = nil
	if not before then return end
	if InCombatLockdown() then
		if not putting then
			putting = CreateFrame("Frame")
			putting:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				L.Unpreview()
			end)
		end
		putting:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local was = before
	before = nil
	local added = not Mine(was.info.layouts) and Mine(C_EditMode.GetLayouts().layouts)
	C_EditMode.SaveLayouts(was.info)
	if added then C_EditMode.OnLayoutDeleted(Presets() + added) end
	Activate(was.info.activeLayout)
	SetActionBarToggles(unpack(was.toggles))
	-- (The lift's slim vessel put the game's display off as a live pick: back as it was.)
	if was.display ~= nil and C_CVar.GetCVar(DISPLAY_CVAR) ~= was.display then C_CVar.SetCVar(DISPLAY_CVAR, was.display) end
	for i, size in pairs(was.chat) do
		local _, now = GetChatWindowInfo(i)
		if size and now ~= size then SetChatWindowSize(i, size) end
	end
	wipe(ns.char)
	for k, v in pairs(was.char) do ns.char[k] = v end
	ShowBars()
	T:Apply()
end

-- size: a key of Console.SIZES; style: a key of Console.STYLES; nil keeps the one in use.
-- opts: grow (true or false: keep it for this character), step (the bars of that step,
-- whether growing or not), words (what the reload panel says), pieces (false: a first
-- setup leaves the meter, cooldown manager and personal resource display alone), bags and drawer
-- (true or false: the bag bar under the menu, the menu in a drawer, as the settings will be after the
-- reload when they aren't yet: a setup that changes profile), live (true: applied now, no reload asked;
-- what stood before is kept for Unpreview), keep (true: the menu's drawer stays as the player left it).
function L.SetUp(size, style, opts)
	opts = opts or {}
	if InCombatLockdown() then return false, "combat" end
	-- (Live: before anything is written, once SetUp's checks have passed.)
	if opts.live then
		local ok, why = L.CanSetUp()
		if not ok then return false, why end
		Hold()
	end
	Forget()
	local info = C_EditMode.GetLayouts()
	local saved, presets, active = info.layouts, Presets(), info.activeLayout
	local mine = Mine(saved)
	local again = mine ~= nil and active == presets + mine

	local layout, index
	if again then
		layout = saved[mine]
	else
		-- Copy the active layout: a preset or one of the player's.
		local source = active <= presets and EditModePresetLayoutManager:GetCopyOfPresetLayouts()[active]
			or saved[active - presets]
		if not source then return false, "none" end
		if not mine then
			index = NewIndex(saved)
			if not index then return false, "full" end
		end
		layout = {
			layoutName = L.NAME, layoutType = Character, interfaceStyle = source.interfaceStyle,
			systems = Shy.CopyTable(source.systems),
		}
		ns.char.previous = active <= presets and { preset = active }
			or { name = source.layoutName, type = source.layoutType }
	end

	if Console.SIZES[size] then ns.char.size = size end
	if Console.STYLES[style] then ns.char.style = style end
	if opts.grow ~= nil then ns.char.grow = opts.grow and true or false end
	-- The bars: a step given, the one the abilities call for while growing, or every bar when "every bar" is picked.
	local step = L.STEPS[opts.step] and opts.step or (ns.char.grow and L.GrowStep()) or (opts.grow == false and #L.STEPS) or nil
	ns.char.loose = {}   -- pieces taken out or moved in Edit Mode are seated again
	ns.char.barsAt = nil   -- and the tracked bars' home goes back to its planned place
	local slim = L.Slim()
	local now = Now(Furnish(step, opts.pieces ~= false, slim))
	SlimDisplay(slim)
	if opts.bags ~= nil then L.WithBags(now, opts.bags) end
	if opts.drawer ~= nil then
		now.drawer = opts.drawer and T.db.arrange and true or false
		now.tucked = now.drawer
	end
	-- Text sizes are only applied for a new size or a fresh layout, so a
	-- repeat setup keeps the sizes the player picked since.
	if not again or ns.char.dressed ~= now.size then
		now.wear = L.WEAR[now.size]
		Wear(now.wear)
		ns.char.dressed = now.size
	end
	-- The meter shows always, a piece of every layout, and so do bars 2 and 3; the minimal layout shows them only
	-- in a fight (Console.ROLE's `combat`). Written for a fresh layout or a new one, so a choice made in Edit Mode
	-- since stands.
	if not again or (ns.char.styled or Console.STYLE) ~= now.style then
		local fights = Console.ROLE[now.style] and Console.ROLE[now.style].combat
		now.shows = fights and Enum.DamageMeterVisibility.InCombat or Enum.DamageMeterVisibility.Always
		now.barsShow = fights and Enum.ActionBarVisibleSetting.InCombat or Enum.ActionBarVisibleSetting.Always
		ns.char.styled = now.style
	end
	local g = Console.Build(now)
	ns.char.placed = Write(layout, g, now, again)
	-- The game's own unit frames stand where a layout by role put them: a classic layout gives them back (GameFrame).
	ns.char.roleFrames = g.role ~= nil or nil
	Visibility(layout, not again)
	ns.char.built = Signature(now)
	ns.char.settle = true
	ns.Arrange.TakeIn()
	-- The menu's drawer goes back to its default (tucked) for the layout being written; not while setup's picks
	-- go on live (or are kept), where it stays as the player left it (pinned out stays out).
	if Shy.Drawer and not (opts.live or opts.keep) then Shy.Drawer.Reset("menu", "tucked") end

	if mine then
		saved[mine] = layout
		C_EditMode.SaveLayouts(info)
		Forget()
		if opts.live then Activate(presets + mine) elseif not again then C_EditMode.SetActiveLayout(presets + mine) end
	else
		table.insert(saved, index - presets, layout)
		C_EditMode.SaveLayouts(info)
		local function Add() C_EditMode.OnLayoutAdded(index, true, false) end
		if opts.live then Activate(index, Add) else Add() end
	end
	Forget()
	C_Timer.After(0, TellRole)   -- another layout by role over the one in use switches no layout
	if opts.live then
		-- Measured before it moved, as a setup's reload would; taken as it stands once it has.
		ShowBars()
		C_Timer.After(0.5, L.Settle)
		return true
	end
	-- Addons can't call C_UI.Reload on this client; Shy.Reload shows a button the player clicks.
	Shy.Reload(opts.words or "The console is saved. Reload to apply it.")
	return true
end

-- The bars' switches a setup with `opts` leaves (as SetUp's Furnish works them out): the step's while
-- growing, or every bar, or every bar on a first setup; else as they are.
local function Wanted(opts)
	local on = { GetActionBarToggles() }
	local grow = opts.grow
	if grow == nil then grow = ns.char.grow end
	local step = L.STEPS[opts.step] and opts.step or (grow and L.GrowStep()) or (opts.grow == false and #L.STEPS) or nil
	for _, def in ipairs(TOGGLED) do
		if step then
			on[def.toggle] = L.STEPS[step][def.key] and true or false
		elseif not ns.char.furnished then
			on[def.toggle] = true
		end
	end
	return on
end

-- Has the game the bars switched as wanted? (Its switches come back from the server a moment after they're set.)
local function Switched(want)
	local on = { GetActionBarToggles() }
	for _, def in ipairs(TOGGLED) do
		if (on[def.toggle] and true or false) ~= (want[def.toggle] and true or false) then return false end
	end
	return true
end

-- A live pick, in the order a setup's reload brings things: the bars switched on first (and what the
-- caller switched on just before: settle), then, once the game has them up, the layout written and applied
-- (SetUp's live way), so it is measured with them there. A newer pick drops one still waiting; done runs
-- once it is laid out. Gives up waiting on the game after WEAR_TRIES and lays it out anyway.
local WEAR_WAIT, WEAR_TRIES = 0.1, 15
function L.Wear(size, style, opts, done)
	if InCombatLockdown() then return false, "combat" end
	local ok, why = L.CanSetUp()
	if not ok then return false, why end
	Hold()
	local token = {}
	wearing = token
	local want, settle = Wanted(opts), opts.settle
	if not Switched(want) then
		SetActionBarToggles(want[1] or false, want[2] or false, want[3] or false, want[4] or false, want[5] or false, want[6] or false, want[7] or false)
		settle = true
	end
	local tries = 0
	local function Go()
		if wearing ~= token or InCombatLockdown() then return end
		if not Switched(want) and tries < WEAR_TRIES then
			tries = tries + 1
			C_Timer.After(WEAR_WAIT, Go)
			return
		end
		wearing = nil
		MultiActionBar_Update()
		L.SetUp(size, style, { grow = opts.grow, pieces = false, live = true })
		if done then done() end
	end
	if settle then C_Timer.After(WEAR_WAIT, Go) else Go() end
	return true
end

-- Switch back to the previous layout. Ours stays in Edit Mode's list.
function L.GoBack()
	if InCombatLockdown() then return false, "combat" end
	if not L.IsActive() then return false, "elsewhere" end
	local info = C_EditMode.GetLayouts()
	local was, target = ns.char.previous, nil
	if was and was.preset then
		target = was.preset
	elseif was then
		for i, layout in ipairs(info.layouts) do
			if layout.layoutName == was.name and layout.layoutType == was.type then target = Presets() + i end
		end
	end
	-- The previous layout was deleted: fall back to the default.
	target = target or C_EditMode.GetEditModeDefaultLayout() + 1
	C_EditMode.SetActiveLayout(target)
	Forget()
	Shy.Reload("Switched back to your previous layout. Reload to apply it.")
	return true
end

local WHY = {
	combat = "you're in combat. Try again after combat.",
	full = "this character has no free Edit Mode layout slots. Delete a layout in Edit Mode, then set up again.",
	none = "couldn't read your current layout. Open and close Edit Mode once, then try again.",
	elsewhere = "you aren't using the console layout, so there is nothing to go back from.",
}

function L.Report(ok, why)
	if not ok then T:Print(WHY[why]) end
	return ok
end

-- SetUp's checks without writing anything; returns the same reasons.
function L.CanSetUp()
	if InCombatLockdown() then return false, "combat" end
	local info = C_EditMode.GetLayouts()
	local saved, presets, active = info.layouts, Presets(), info.activeLayout
	local mine = Mine(saved)
	if mine ~= nil and active == presets + mine then return true end
	local source = active <= presets and EditModePresetLayoutManager:GetCopyOfPresetLayouts()[active]
		or saved[active - presets]
	if not source then return false, "none" end
	if not mine and not NewIndex(saved) then return false, "full" end
	return true
end

-- A reason as a capitalised sentence (WHY's lines start lower case for chat).
function L.Words(why)
	return (WHY[why]:gsub("^%l", string.upper))
end

-- For other addons: is the console's layout the one in use (ShySkin hides the gryphons' highlights then).
function T:ConsoleActive()
	return L.IsActive()
end
