-- The map window's two sides: the world (the map) and its dungeons (the journal, DungeonWindow.lua). One window,
-- turned over: you only ever read one of them.
--   The switch leads the top bar on both sides, at the same spot: on the map's breadcrumb row (Nav.lua) and on
--   the journal's bar. Two pictures on one small plate, the globe and the journal's sign (the first build wrote
--   World | Dungeons on it and took the breadcrumb's room: its maps folded away): the half of the side you are
--   on is lit; the other turns the window. Each says what it is under the mouse.
--   Dungeons lays the journal's face on a host of ours over everything under the window's header (the row, the
--   map), its bar where the row is (Window.Room). The window's header and its keys are never touched.
--   The map opens on the world; inside a dungeon the journal has, on that dungeon, until you turn it to the world
--   yourself in there.
--   The door joins them: an entrance on the map goes in (Sides.Enter), the journal's ways out show the door on
--   the map (Sides.ToDoor).
-- With the map shut the journal stands in a window of its own; there its World half and its ways out open the
-- map's window, on the world.
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

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Sides = {}
ns.Sides = Sides

local S = {
	tall = 22, half = 24, glyph = 12,   -- the switch: a plate of the bar's, a half and its picture
	fade = 0.18,               -- seconds the journal takes to come up over the map
	deep = 2.2,                -- how close the view comes to a door, times the whole map's size, at the least
	fresh = 1,                 -- seconds an asked opening of the map window answers for
}
local side = "world"
local host                   -- ours, in the map window: the journal's face stands on it
local stay                   -- { map, side }: the side turned to by hand inside that dungeon
local doors                  -- dungeon -> its entrance, read from the game's maps once
local after                  -- { dungeon, at }: the map window asked open on the world (at a door), to answer as it opens
local came                   -- { dungeon, map, x, y, zoom }: where the view stood as you went in at a door

local function View() return ns.View end
local function Window() return ns.Window end

function Sides.Now() return side end

function Sides.MapUp()
	local window = Window()
	return window ~= nil and window.Shown() == true and View().InUse() == true
end

---------------------------------------------------------------------------
-- The host
---------------------------------------------------------------------------
-- Over everything under the window's header, from the body's edges: the journal's bar where the window's row is,
-- its pieces beginning where the map's edge is (the switch stands there on both sides). Returns its size, and how
-- far in the bar's pieces begin.
local function Stand()
	local box, body, top, pad = Window().Room()
	if not host then
		host = CreateFrame("Frame", nil, box)
		-- (Over the window's own plates on the map, which stand in its strata; menus and hovers stand higher still.)
		host:SetFrameStrata("DIALOG")
		host:SetFrameLevel(20)
		host:EnableMouse(true)
		host:EnableMouseWheel(true)
		host:SetScript("OnMouseWheel", function() end)
		host.ground = host:CreateTexture(nil, "BACKGROUND", nil, -8)
		host.ground:SetAllPoints()
		host.ground:SetColorTexture(0, 0, 0, 1)
		host:Hide()
	end
	host:ClearAllPoints()
	host:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -top)
	host:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
	return body:GetWidth(), body:GetHeight() - top, pad
end

-- The window was sized (maximized, put back, dragged): the face is laid out for it again.
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
		if not Sides.MapUp() then return end
		local was = side
		side = "dungeons"
		sizing = true
		local width, height, x = Stand()
		host:Show()
		-- (Under its bar the journal is as small as everything laid over the map: the map gets the room.)
		ns.Journal.Home(host, width, height, x, Shy.Maps.OVER)
		sizing = false
		if was ~= "dungeons" then UI.FadeIn(host, S.fade) end
	else
		side, came = "world", nil
		if host then host:Hide() end
	end
end

-- The map window opened on the world (from the journal in its own window: its World half, a way out), at a
-- dungeon's door where one is named.
local function OpenWorld(dungeon)
	local window = Window()
	if not (window and T.db.on) then
		-- (The view off: the game's map is the map, and not ours to open.)
		T:Print("open the map with its own key to see the world.")
		return
	end
	after = { dungeon = dungeon, at = GetTime() }
	local door = dungeon and ns.Journal.Door(dungeon)
	if door then View().Open(door.map) end
	window.Set(true)
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
		OpenWorld(nil)
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
	local here = ns.Journal.Here()
	if here then stay = { map = here, side = "world" } end
	if not Sides.MapUp() then
		OpenWorld(dungeon)
		return
	end
	Sides.Turn("world")
	Land(door)
end

---------------------------------------------------------------------------
-- The map's window
---------------------------------------------------------------------------
-- The map window opened. Asked open on the world (at a door, with a dungeon named), on the world; else on the world,
-- or inside a dungeon the journal has, on that dungeon.
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
		-- (A frame on: the view has opened by then.)
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

if ns.Window then
	ns.Window.Tell(function(what)
		if what == "shown" then
			Shown()
		elseif what == "hidden" then
			Hidden()
		else
			Sized()
		end
	end)
end

-- (The view given up while the journal lies on the map: the map's window closes with it.)
ns.OnApply(function()
	if side == "dungeons" and not Sides.MapUp() then Hidden() end
end)
