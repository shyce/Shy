-- The map window's two sides: the world (the map) and its dungeons (the journal, DungeonWindow.lua). One window,
-- turned over: you only ever read one of them.
--   The switch leads the top bar on both sides, at the same spot: on the map's breadcrumb row (Nav.lua) and on
--   the journal's bar. Two pictures on one small plate, the globe and the journal's sign (the first build wrote
--   World | Dungeons on it and took the breadcrumb's room: its maps folded away): the half of the side you are
--   on is lit; the other turns the window. Each says what it is under the mouse.
--   Dungeons lays the journal's face on a host of ours over everything under the window's title (the bar's row,
--   the map, the quest log). The game's window, its header and its keys are never touched.
--   The map opens on the world; inside a dungeon the journal has, on that dungeon, until you turn it to the world
--   yourself in there.
--   The door joins them: an entrance on the map goes in (Sides.Enter), the journal's ways out show the door on
--   the map (Sides.ToDoor).
-- The game's map is never opened from addon code. With the map shut the journal stands in a window of its own;
-- there its World half and its ways out are answered by one secure button (ShyMapsSideKey) laid over them while
-- the mouse is on them, out of a fight, which clicks the micro menu's quest log button: the game opens its map.
--   Sides.Switch(parent, mine) -> frame   the switch, for the side `mine` ("world" | "dungeons")
--   Sides.Now() -> "world" | "dungeons"   the side the map window shows
--   Sides.MapUp()                         the map window is open, with our view in use
--   Sides.Turn(side)                      turns the open map window to a side
--   Sides.Enter(dungeon, x, y)            in through a door: the view glides to x, y of the map shown as the
--                                         journal comes up on the dungeon (its instance map)
--   Sides.Back(dungeon) -> bool           back out of the door you came in by: the view as it stood then
--   Sides.Forget()                        the journal left that dungeon: its way out is every dungeon again
--   Sides.ToDoor(dungeon)                out through it: the world, the view flown to its entrance
--   Sides.Door(dungeon) -> { map, x, y }  its entrance as the game's own maps have it, or nil
--   Sides.KeyOver(button, dungeon)        the secure button laid over one of the journal's own (dungeon: the
--                                         one whose door the map is to open on)

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Sides = {}
ns.Sides = Sides

local S = {
	tall = 22, half = 24, glyph = 12,   -- the switch: a plate of the bar's, a half and its picture
	fade = 0.18,               -- seconds the journal takes to come up over the map
	head = 28,                 -- the host's top under the window's, where the game's bar can't be measured
	mid = 18,                  -- the journal's bar's middle under its top (half its row)
	crumb = 5,                 -- the map's crumbs stand this far under the game's bar's middle (Nav.lua)
	left = 2, right = 3, foot = 2,   -- the host inside the window's edge, as the game's canvas is
	deep = 2.2,                -- how close the view comes to a door, times the whole map's size, at the least
	fresh = 1,                 -- seconds a click of the secure button answers for the map's opening
	key = "ShyMapsSideKey",
}
local side = "world"
local host                   -- ours, in the map window: the journal's face stands on it
local stay                   -- { map, side }: the side turned to by hand inside that dungeon
local doors                  -- dungeon -> its entrance, read from the game's maps once
local after                  -- { dungeon, at }: the secure button's click, to answer as the map opens
local came                   -- { dungeon, map, x, y, zoom }: where the view stood as you went in at a door

local function View() return ns.View end

function Sides.Now() return side end

function Sides.MapUp()
	local map = rawget(_G, "WorldMapFrame")
	return map ~= nil and map:IsShown() == true and View().InUse() == true
end

---------------------------------------------------------------------------
-- The host
---------------------------------------------------------------------------
local function Host()
	if host then return host end
	local map = rawget(_G, "WorldMapFrame")
	if not (map and map.NavBar) then return nil end
	host = CreateFrame("Frame", nil, map)
	-- (Over the window's own buttons on the map, which stand in HIGH; menus and hovers stand higher still.)
	host:SetFrameStrata("DIALOG")
	host:SetFrameLevel(20)
	host:EnableMouse(true)
	host:EnableMouseWheel(true)
	host:SetScript("OnMouseWheel", function() end)
	host.ground = host:CreateTexture(nil, "BACKGROUND", nil, -8)
	host.ground:SetAllPoints()
	host.ground:SetColorTexture(0, 0, 0, 1)
	host:Hide()
	return host
end

-- Stands the host under the window's title, its top where the journal's bar lies on the map's own; returns its
-- size, and how far in the game's bar begins (the switch stands there on both sides).
local function Stand()
	local map = WorldMapFrame
	local bar = map.NavBar
	local top, x = S.head, nil
	local mapTop, mapLeft = map:GetTop(), map:GetLeft()
	local barTop, barBottom, barLeft = bar:GetTop(), bar:GetBottom(), bar:GetLeft()
	if mapTop and barTop and barBottom then top = math.max(0, mapTop - (barTop + barBottom) / 2 + S.crumb - S.mid) end
	if mapLeft and barLeft then x = math.max(0, barLeft - mapLeft - S.left) end
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", map, "TOPLEFT", S.left, -top)
	host:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -S.right, S.foot)
	return map:GetWidth() - S.left - S.right, map:GetHeight() - top - S.foot, x
end

-- The window was sized (maximized, put back, its quest log shown or shut): the face is laid out for it again,
-- its bar beginning where the game's does now.
local sizing = false
local function Sized()
	if sizing or side ~= "dungeons" or not (host and host:IsShown()) then return end
	sizing = true
	local width, height, x = Stand()
	ns.Journal.Home(host, width, height, x, Shy.Maps.OVER)
	sizing = false
end

function Sides.Turn(to)
	if to == "dungeons" then
		if not (Sides.MapUp() and Host()) then return end
		local was = side
		side = "dungeons"
		sizing = true
		local width, height, x = Stand()
		host:Show()
		-- (Under its bar the journal is as small as everything laid over the map: the map's window gets the room.)
		ns.Journal.Home(host, width, height, x, Shy.Maps.OVER)
		sizing = false
		if was ~= "dungeons" then UI.FadeIn(host, S.fade) end
	else
		side, came = "world", nil
		if host then host:Hide() end
	end
end

---------------------------------------------------------------------------
-- The switch
---------------------------------------------------------------------------
-- A half is pressed for its side: the other side's turns the window; your own side's goes to its top (every
-- dungeon), or does nothing on the world.
local function Pick(key, mine)
	local journal = ns.Journal
	if key == mine then
		if key == "dungeons" then journal.Open() end
		return
	end
	-- (Turned by hand inside a dungeon, the map opens on that side while you are still in there.)
	local here = journal.Here()
	if here then stay = { map = here, side = key } end
	if key == "dungeons" then
		journal.Toggle(true)
	elseif Sides.MapUp() then
		Sides.Turn("world")
	else
		-- (The journal in its own window, in a fight: the secure button isn't there to open the map.)
		T:Print("open the map with its own key to see the world.")
	end
end

function Sides.Switch(parent, mine)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(S.tall)
	UI.Skin(f, C.bgHot)
	local function Half(key, label, says, hover)
		local b = CreateFrame("Button", nil, f)
		b:SetSize(S.half, S.tall)
		b.glyph = b:CreateTexture(nil, "ARTWORK")
		b.glyph:SetSize(S.glyph, S.glyph)
		b.glyph:SetPoint("CENTER")
		if hover then
			Shy.Hover.Glyph(b.glyph, hover, S.glyph)
		else
			b.glyph:SetTexture(Shy.MEDIA .. "GlyphGlobeS")
		end
		UI.Press(b, { fill = C.bgHot, bare = true, sink = { b.glyph } })
		-- The half of the side you are on wears the theme's selected fill, as the look's does.
		function b:OnLook(s)
			if s.on and not s.down then UI.Paint(self.shyBg, C.fill) end
			UI.Tint(self.glyph, s.on and C.head or C.text)
		end
		b:SetOn(key == mine)
		b:SetScript("OnClick", function() Pick(key, mine) end)
		-- (A picture alone: its name under the mouse, under the bar, which is the window's top edge.)
		b:HookScript("OnEnter", function(self) UI.Tip(self, label, says, { side = "BOTTOM" }) end)
		b:HookScript("OnLeave", function(self) UI.TipHide(self) end)
		return b
	end
	f.world = Half("world", "World", "The map.")
	f.dungeons = Half("dungeons", "Dungeons", "Each dungeon's floor, its bosses, what they do and what they drop.", "kill")
	f.world:SetPoint("LEFT", f, "LEFT", 0, 0)
	f.dungeons:SetPoint("LEFT", f.world, "RIGHT", 0, 0)
	f:SetWidth(f.world:GetWidth() + f.dungeons:GetWidth())
	-- (The journal's own, in its own window: the map is opened by the secure button over its World half.)
	if mine == "dungeons" then
		f.world:HookScript("OnEnter", function(self) Sides.KeyOver(self) end)
	end
	return f
end

---------------------------------------------------------------------------
-- The door
---------------------------------------------------------------------------
-- Every dungeon's entrance, as the game's own zone maps have them, by the name each gives.
function Sides.Door(dungeon)
	if not doors then
		doors = {}
		local J = ns.Dungeons
		if not (J and C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap and C_Map.GetFallbackWorldMapID
			and C_Map.GetMapChildrenInfo) then
			return nil
		end
		for _, zone in ipairs(C_Map.GetMapChildrenInfo(C_Map.GetFallbackWorldMapID(), Enum.UIMapType.Zone, true) or {}) do
			for _, door in ipairs(C_EncounterJournal.GetDungeonEntrancesForMap(zone.mapID) or {}) do
				local map = J.ByName(door.name)
				if map and not doors[map] then
					local x, y = door.position:GetXY()
					doors[map] = { map = zone.mapID, x = x, y = y }
				end
			end
		end
	end
	return doors[dungeon]
end

-- The view to a door on the map it shows or another: there in one move, then in close.
local function Land(door)
	local view = View()
	local function Close()
		-- (A flight within one world ends on whichever map its zoom came down through, the continent's as
		-- often as the zone's: the door's place is a share of its own zone's map, and glided to on another it
		-- was a place somewhere else, the zone under which the view then stepped into. Its zone first.)
		if view.Map() ~= door.map and not view.Show(door.map, "into") then return end
		view.Glide(door.x, door.y, math.max(view.Scale() / view.Fit(), S.deep))
	end
	if view.Map() == door.map then
		Close()
	elseif not view.Fly(door.map, Close) then
		if view.Show(door.map, "into") then Close() end
	end
end

function Sides.Enter(dungeon, x, y)
	local view = View()
	local on = view.Map()
	local was
	if on then
		local cx, cy = view.Center()
		if cx and cy then was = { dungeon = dungeon, map = on, x = cx, y = cy, zoom = view.Scale() / view.Fit() } end
	end
	if x and y and on then view.Glide(x, y, math.max(view.Scale() / view.Fit(), S.deep)) end
	ns.Journal.Open(dungeon)
	came = was
end

-- The journal left the dungeon you came in on: out of it is every dungeon again, not the door.
function Sides.Forget() came = nil end

-- Back out of the door you came in by: the world, the view gliding back to where it stood as you went in.
-- False when you didn't come in by one (the journal then goes to every dungeon).
function Sides.Back(dungeon)
	local was = came
	if not (was and was.dungeon == dungeon and side == "dungeons" and Sides.MapUp()) then return false end
	local here = ns.Journal.Here()
	if here then stay = { map = here, side = "world" } end
	Sides.Turn("world")
	local view = View()
	if view.Map() ~= was.map and not view.Show(was.map) then return true end
	view.Glide(was.x, was.y, was.zoom)
	return true
end

function Sides.ToDoor(dungeon)
	local door = ns.Journal.Door(dungeon)
	if not door then return end
	if not Sides.MapUp() then
		-- (The map shut, and no secure button to open it: it opens there next time.)
		View().Open(door.map)
		T:Print("its door shows when you open the map.")
		return
	end
	local here = ns.Journal.Here()
	if here then stay = { map = here, side = "world" } end
	Sides.Turn("world")
	Land(door)
end

---------------------------------------------------------------------------
-- The game's window
---------------------------------------------------------------------------
-- The map window opened. A click of the secure button asked for the world (at a door, with a dungeon named);
-- else it opens on the world, or inside a dungeon the journal has, on that dungeon.
local function Shown()
	local journal = ns.Journal
	local asked = after
	after = nil
	if View().InUse() ~= true then
		side = "world"
		return
	end
	journal.Yield()
	if asked and GetTime() - asked.at <= S.fresh then
		Sides.Turn("world")
		local door = asked.dungeon and journal.Door(asked.dungeon)
		-- (A frame on: the view has opened by then, whichever of us heard the window first.)
		if door then C_Timer.After(0, function()
			if Sides.MapUp() and side == "world" then Land(door) end
		end) end
		return
	end
	local here = journal.Here()
	if not here then
		stay = nil
		Sides.Turn("world")
	elseif stay and stay.map == here and stay.side == "world" then
		Sides.Turn("world")
	else
		journal.Toggle(true)
	end
end

local function Hidden()
	side, came = "world", nil
	if host then host:Hide() end
end

local hooked = false
local function Hook()
	if hooked then return end
	local map = rawget(_G, "WorldMapFrame")
	if not map then return end
	hooked = true
	map:HookScript("OnShow", Shown)
	map:HookScript("OnHide", Hidden)
	map:HookScript("OnSizeChanged", Sized)
end

-- (The view given up while the journal lies on the map: the game's own map has no side of ours.)
ns.OnApply(function()
	Hook()
	if side == "dungeons" and not Sides.MapUp() then Hidden() end
end)

---------------------------------------------------------------------------
-- Opening the map from the journal's own window
---------------------------------------------------------------------------
local key = CreateFrame("Button", S.key, UIParent, "SecureActionButtonTemplate")
key:SetFrameStrata("FULLSCREEN_DIALOG")
key:SetFrameLevel(500)
key:RegisterForClicks("AnyUp")
key:SetAttribute("type", "click")
key:SetAttribute("useOnKeyDown", false)
key:Hide()

-- The quest log's button of the micro menu, as the button's click (set out of a fight, once it is there).
local armed = false
local function Arm()
	if armed or InCombatLockdown() then return end
	local button = rawget(_G, "QuestLogMicroButton")
	if type(button) ~= "table" then return end
	key:SetAttribute("clickbutton", button)
	armed = true
end

local function Away()
	key.owner, key.dungeon = nil, nil
	if not InCombatLockdown() then key:Hide() end
end

key:SetScript("PreClick", function(self)
	after = { dungeon = self.dungeon, at = GetTime() }
	-- (Where the map is to open: on the door's own map.)
	local door = self.dungeon and ns.Journal.Door(self.dungeon)
	if door then View().Open(door.map) end
end)
key:SetScript("PostClick", Away)

-- Laid over a button, the hover and the press are the button's under it, for its look.
local function Tell(script)
	return function(self, ...)
		local owner = self.owner
		local fn = owner and owner:GetScript(script)
		if fn then fn(owner, ...) end
	end
end
key:SetScript("OnEnter", Tell("OnEnter"))
key:SetScript("OnLeave", function(self)
	Tell("OnLeave")(self)
	Away()
end)
key:HookScript("OnMouseDown", Tell("OnMouseDown"))
key:HookScript("OnMouseUp", Tell("OnMouseUp"))

function Sides.KeyOver(button, dungeon)
	if InCombatLockdown() or not armed or Sides.MapUp() then return end
	if key.owner == button and key:IsShown() then return end
	local left, bottom, width, height = button:GetLeft(), button:GetBottom(), button:GetWidth(), button:GetHeight()
	if not left then return end
	local s = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	key.owner, key.dungeon = button, dungeon
	key:ClearAllPoints()
	key:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
	key:SetSize(width * s, height * s)
	key:Show()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (Laid over a button as the fight begins: gone before the lockdown holds it there.)
		Away()
	else
		Arm()
		Hook()
	end
end)
Arm()
