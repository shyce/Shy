-- Options page. The preview is your zone as the map draws it, by the map's own painters: its look and
-- what unexplored ground looks like change it as they are picked.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270
local STRIP_W, STRIP_H = 622, 150

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

-- Preview

local strip, inner, art, ground, travel

local function BuildPreview(panel)
	strip = CreateFrame("Frame", nil, panel)
	strip:SetSize(STRIP_W, STRIP_H)
	strip:SetPoint("TOPLEFT", LEFT, -112)
	UI.Panel(strip, { brackets = false, line = false })
	strip:SetClipsChildren(true)
	inner = CreateFrame("Frame", nil, strip)
	inner:SetFrameLevel(strip:GetFrameLevel() + 1)
	ground = ns.Terrain.New(inner, strip:GetFrameLevel() + 1)
	art = ns.Art.New(inner, strip:GetFrameLevel() + 2)
	if ns.Travel then
		local over = CreateFrame("Frame", nil, inner)
		over:SetAllPoints()
		over:SetFrameLevel(strip:GetFrameLevel() + 4)
		travel = ns.Travel.Painter(over)
	end
	-- A lid over the art: the strip's edge, and you on the map.
	local lid = CreateFrame("Frame", nil, strip)
	lid:SetAllPoints()
	lid:SetFrameLevel(strip:GetFrameLevel() + 6)
	UI.Panel(lid, { brackets = false, line = false, fill = { 0, 0, 0, 0 } })
	strip.me = lid:CreateTexture(nil, "OVERLAY")
	strip.me:SetAtlas("UI-WorldMapArrow")
	strip.me:SetSize(22, 22)
end

local function RefreshPreview()
	if not strip then return end
	local map = MapUtil.GetDisplayableMapForPlayer()
	local terrain = ns.Terrain.Covers(map)
	local w, h = ns.Art.Paint(art, map, T.db.fog, terrain)
	if not w then return end
	ns.Art.Detail(art, 1)
	local scale = STRIP_W / w
	local x, y = ns.View.PlayerAt(map)
	local top = math.max(0, math.min(h * scale - STRIP_H, (y or 0.5) * h * scale - STRIP_H / 2))
	inner:SetSize(w, h)
	inner:SetScale(scale)
	inner:ClearAllPoints()
	inner:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, top / scale)
	if terrain then
		ns.Terrain.Lay(ground, map, 0, 1, top / (h * scale), (top + STRIP_H) / (h * scale), w, h)
	else
		ns.Terrain.Clear(ground)
	end
	if travel then ns.Travel.Paint(travel, map, w, h, scale) end
	strip.me:SetShown(x ~= nil)
	if x then
		strip.me:ClearAllPoints()
		strip.me:SetPoint("CENTER", strip, "TOPLEFT", x * STRIP_W, -(y * h * scale - top))
		strip.me:SetRotation(GetPlayerFacing() or 0)
	end
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Apply() end)
	local function On() return T.db.on end
	local function Friends() return T.db.on and T.db.friends end
	local function Guild() return T.db.on and T.db.guild end

	local function Build()
		UI.PageHeader(panel, T)
		BuildPreview(panel)

		local switchLabel = UI.Text(panel, "World map", 15, true)
		switchLabel:SetPoint("TOPLEFT", LEFT, -274)
		local switch = group:Switch(panel, "World map", Get("on"), Set("on"),
			{ desc = "Turn off to go back to the default map. Your settings and saved views are kept." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		At(UI.Header(panel, "The map", COL), panel, LEFT, -306)
		At(group:Dropdown(panel, "Look of a zone", {
			{ value = "drawn", text = "Drawn map" },
			{ value = "terrain", text = "Terrain from above" },
		}, Get("style"), Set("style"), { width = COL, enabled = On,
			desc = "Terrain shows the actual ground, like the minimap, and lets you pan into the zones around it." }), panel, LEFT, -334)
		At(group:Dropdown(panel, "Unexplored areas", {
			{ value = "faded", text = "Shown faded" },
			{ value = "clear", text = "Shown as explored" },
			{ value = "hidden", text = "Hidden" },
		}, Get("fog"), Set("fog"), { width = COL, enabled = On,
			desc = "How a drawn map shows the places you haven't been yet." }), panel, LEFT, -390)
		At(group:Checkbox(panel, "Reopen where you left it", Get("remember"), Set("remember"), { enabled = On,
			desc = "The map opens on the place and zoom you left it at, until you move to another zone." }), panel, LEFT, -446)
		At(group:Checkbox(panel, "Follow me", Get("follow"), Set("follow"), { enabled = On,
			desc = "Keeps you in view as you move and looks ahead the way you're going; drag it away and it offers to stay put. Also in the map's corner." }), panel, LEFT, -472)
		local forget = UI.Button(panel, "Forget saved views", 180, function()
			wipe(T.db.views)
			wipe(T.db.last)
		end)
		At(forget, panel, LEFT, -506)

		At(UI.Header(panel, "Overlay", COL), panel, LEFT, -552)
		At(group:Checkbox(panel, "Map over the screen", Get("overlay"), Set("overlay"), { enabled = On,
			desc = "While the map is closed, it lies faintly over the whole game and clicks go through it; Key Bindings has a key to switch it." }),
			panel, LEFT, -580)
		local function Laid() return T.db.on and T.db.overlay end
		local function Percent(v) return v .. "%" end
		At(group:Slider(panel, "Opacity by day", 5, 70, 1,
			function() return math.floor(T.db.overlayOpacity * 100 + 0.5) end,
			function(v) T.db.overlayOpacity = v / 100 end,
			{ width = COL, enabled = Laid, format = Percent,
				desc = "How solid the map is over the game in daylight; lower lets more of the game show through." }), panel, LEFT, -612)
		At(group:Slider(panel, "Opacity at night", 5, 70, 1,
			function() return math.floor(T.db.overlayNight * 100 + 0.5) end,
			function(v) T.db.overlayNight = v / 100 end,
			{ width = COL, enabled = Laid, format = Percent,
				desc = "The dark makes the map stand out, so it can be fainter at night; dawn and dusk blend the two." }), panel, LEFT, -660)
		At(group:Slider(panel, "Trail and pins", 20, 100, 1,
			function() return math.floor(T.db.overlayMarks * 100 + 0.5) end,
			function(v) T.db.overlayMarks = v / 100 end,
			{ width = COL, enabled = Laid, format = Percent,
				desc = "How solid you, your trail and the pins stay on the faint map." }), panel, LEFT, -708)

		At(UI.Header(panel, "On the map", COL), panel, RIGHT, -306)
		local y = -338
		local DESC = {
			zones = "Each zone's name and levels on a continent, colored against your level; the seas too on the terrain.",
			flights = "Flight masters, with the ones you haven't found yet faded.",
			routes = "Faint lines along the flight paths between flight points you know.",
			travel = "Where to catch boats, zeppelins and the tram, and where each goes.",
			dungeons = "Each dungeon's entrance and levels. Click one to go in: its floor, bosses and loot.",
			spirits = "Spirit healers in each zone; when you're dead, the nearest one lights up.",
			places = "Towns, landmarks and other marked places.",
			rares = "Where rare creatures turn up in a zone, with their names and levels. Needs ShyQuest.",
			directions = "Where a guard points you when you ask for directions. The map opens on it; click it to have the arrow lead you there.",
			links = "Doors and paths into other maps; click one to open that map.",
			friends = "Friends who use ShyMaps, even outside your group. Friends off the map wait at its edge, on the side they're on. Battle.net friends too.",
			guild = "Your guild: those who share where they are as a dot, the rest by the zone they're in.",
			notesOn = "Notes you put on the map, and what you drew on it. The notes button on the map's bar adds them.",
			coords = "Your coordinates, and the mouse's while it's on the map.",
		}
		for _, item in ipairs(ns.SWITCHES) do
			At(group:Checkbox(panel, item.label, Get(item.key), Set(item.key), { enabled = On, desc = DESC[item.key] }),
				panel, RIGHT, y)
			y = y - 26
		end
		At(group:Checkbox(panel, "Share where you are", Get("share"), Set("share"), { enabled = Friends,
			desc = "Friends who use ShyMaps see you on their map while they look at it. Only friends on your list." }),
			panel, RIGHT + 16, y)
		y = y - 26
		At(group:Checkbox(panel, "Share with your guild", Get("shareGuild"), Set("shareGuild"), { enabled = Guild,
			desc = "Your guild sees you on their map while they look at it, if they use ShyMaps too." }),
			panel, RIGHT + 16, y)
		y = y - 26
		At(group:Checkbox(panel, "Clear in instances", Get("quietInside"), Set("quietInside"), { enabled = On,
			desc = "In a dungeon, raid or battleground, the map leaves out friends, your guild, boats, notes and quest marks." }),
			panel, RIGHT, y)
		-- (The game's own setting, which its settings don't offer here: it fades the game's window, and ours follows it.)
		y = y - 26
		At(group:Checkbox(panel, "Fade while moving", function() return GetCVarBool("mapFade") end,
			function(on) SetCVar("mapFade", on and "1" or "0") end,
			{ desc = "The map fades while you move, and comes back when you stop or point at it." }),
			panel, RIGHT, y)
		-- Routes friends and your group suggest (ShyWay's): not offered without it.
		local share = Shy.Way.Share
		if not Shy.Way.missing and share and share.SetOn then
			y = y - 26
			At(group:Checkbox(panel, "Suggested routes", function() return share.On() end, function(on) share.SetOn(on) end, { enabled = On,
				desc = "When a friend or someone in your group shares a pin with you, you can accept it as a route or decline it." }),
				panel, RIGHT, y)
		end
		-- The dungeon journal: its way in.
		if ns.Journal and ns.Journal.Toggle and ns.Dungeons then
			y = y - 44
			At(UI.Header(panel, "Dungeons", COL), panel, RIGHT, y)
			y = y - 32
			At(UI.Button(panel, "Bosses and loot", 150, function() ns.Journal.Toggle(true) end), panel, RIGHT, y)
			y = y - 34
			At(group:Checkbox(panel, "Where items drop", Get("drops"), Set("drops"),
				{ desc = "An item's hover says which boss drops it, and how often." }), panel, RIGHT, y)
		end
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			RefreshPreview()
		end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		RefreshPreview()
	end)

	function panel:OnDefault()
		T:ResetDB()   -- saved views are kept
		ns.Apply()
	end

	return panel
end
