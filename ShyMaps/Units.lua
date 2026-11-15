-- Who and what stands on the map: you (the game's arrow, turned as you face, on a soft light, with a
-- ping as the map opens or turns), your group in class colors, your corpse and your map pin (a click
-- tracks it, a right click shares it or takes it away).

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI

local LOOK = 0.05             -- seconds between places read
local ME = 26                 -- your arrow, in units on screen
local MATE = 13               -- a group member's dot
local PING = 1.1              -- seconds a ping ring takes
local PINGS = 2

local me, light, ring         -- your arrow's frame, the light under it, the ping's ring
local mates = {}
local corpse, pin
local lookIn, pingAt = 0, nil

local function Members()
	local list, raid = {}, IsInRaid()
	for i = 1, raid and GetNumGroupMembers() or GetNumSubgroupMembers() do
		local unit = (raid and "raid" or "party") .. i
		local same = UnitIsUnit(unit, "player")
		if issecretvalue(same) or not same then list[#list + 1] = unit end
	end
	return list
end

local function MateTip(self)
	local unit = self.unit
	if not (unit and UnitExists(unit)) then return end
	local name = UnitName(unit)
	if issecretvalue(name) then return end
	UI.Tip(self, name, nil, { color = self.color })
end

-- Your pin as a place: its map, where on it (shares), and that in words.
local function PinPlace()
	local point = Shy.Waypoint.Get()
	local at = point and point.position
	if not (at and point.uiMapID and at.x and at.y) then return nil end
	local info = C_Map.GetMapInfo(point.uiMapID)
	return point.uiMapID, at.x, at.y, ("%s %.1f, %.1f"):format(info and info.name or "", at.x * 100, at.y * 100)
end

local function RemovePin()
	Shy.Waypoint.Clear()
	Shy.Waypoint.Track(false)
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_REMOVE)
end

-- The pin's hover: where it is and how long the way there takes (ShyWay), and what a click does.
local function PinTip(self)
	local map, x, y, where = PinPlace()
	local content = { title = MAP_PIN }
	local rows = {}
	if where then rows[#rows + 1] = { glyph = "go", text = where } end
	local share = Shy.Way.Share
	local seconds, yards
	if map and share and share.Away then seconds, yards = share.Away({ map = map, x = x, y = y }) end
	if seconds then
		rows[#rows + 1] = { glyph = "clock", text = seconds < 60 and "Under a minute away" or ("%d min away"):format(math.floor(seconds / 60 + 0.5)) }
	elseif yards then
		rows[#rows + 1] = { glyph = "clock", text = ("%d yd away"):format(math.floor(yards + 0.5)) }
	end
	if #rows > 0 then content.sections = { { rows = rows } } end
	content.hints = {
		{ "left", Shy.Waypoint.Tracking() and "Stop tracking" or "Track" },
		{ "right", "Share or remove" },
	}
	Shy.Hover.Show(self, content)
end

-- The pin's menu: who to send it to as a route of theirs, its link for any chat, and taking it away.
-- (ns.PinMenu: the bar's share button writes the same rows.)
function ns.PinMenu(root)
	local share = Shy.Way.Share
	if not Shy.Way.missing and share and share.Write then share.Write(root, share.Pin, "Share with") end
	UI.TellMenu(root, "Link in chat", function() return "Meet me here:" end, function()
		local map, x, y = PinPlace()
		return map, x, y
	end)
	root:CreateDivider()
	root:CreateButton("Remove pin", RemovePin)
end

local function PinClick(self, button)
	if IsModifiedClick("CHATLINK") then
		ChatFrameUtil.InsertLink(C_Map.GetUserWaypointHyperlink())
		PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CHAT_SHARE)
	elseif button == "RightButton" then
		UI.TipHide(self)
		UI.ContextMenu(self, function(root)
			root:CreateTitle(MAP_PIN)
			ns.PinMenu(root)
		end)
	else
		local track = not Shy.Waypoint.Tracking()
		Shy.Waypoint.Track(track)
		PlaySound(track and SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_OFF)
	end
end

local function Build()
	me = View.Pin("PIN_FRAME_LEVEL_GROUP_MEMBER", ME)
	-- (On the lift: you stay in sight while one thing is looked at alone.)
	me:SetParent(View.Lift())
	me:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_GROUP_MEMBER") + 5)
	me.icon:SetAtlas("UI-WorldMapArrow")
	light = me:CreateTexture(nil, "BACKGROUND")
	light:SetTexture(Shy.MEDIA .. "Glow")
	light:SetPoint("CENTER")
	light:SetSize(ME * 2.2, ME * 2.2)
	ring = me:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Expand")
	ring:SetBlendMode("ADD")
	ring:SetPoint("CENTER")
	ring:Hide()

	corpse = View.Pin("PIN_FRAME_LEVEL_CORPSE", 24, function(self) UI.Tip(self, CORPSE) end)
	corpse.icon:SetTexture("Interface\\Minimap\\POIIcons")
	corpse.icon:SetTexCoord(0.56640625, 0.6328125, 0.001953125, 0.03515625)

	pin = View.Pin("PIN_FRAME_LEVEL_TOPMOST", 26, PinTip, PinClick)
end

local function Mate(i)
	local dot = mates[i]
	if not dot then
		dot = View.Pin("PIN_FRAME_LEVEL_GROUP_MEMBER", MATE, MateTip)
		dot.icon:SetAtlas("WhiteCircle-RaidBlips")
		mates[i] = dot
	end
	return dot
end

local function Ping()
	pingAt = GetTime()
end

local function Read()
	local map = View.Map()
	if not (map and me) then return end
	local light3 = Shy.Theme.light
	light:SetVertexColor(light3[1], light3[2], light3[3], 0.45)
	View.Stand(me, View.PlayerAt(map))

	local used = 0
	for _, unit in ipairs(Members()) do
		local pos = C_Map.GetPlayerMapPosition(map, unit)
		if pos then
			local x, y = pos:GetXY()
			used = used + 1
			local dot = Mate(used)
			local _, class = UnitClass(unit)
			local color = class and C_ClassColor.GetClassColor(class)
			dot.unit = unit
			dot.color = color and { color.r, color.g, color.b } or nil
			if color then dot.icon:SetVertexColor(color.r, color.g, color.b, 1) else dot.icon:SetVertexColor(1, 1, 1, 1) end
			View.Stand(dot, x, y)
		end
	end
	for i = used + 1, #mates do mates[i]:Hide() end

	local body = C_DeathInfo.GetCorpseMapPosition(map)
	if body then View.Stand(corpse, body:GetXY()) else corpse:Hide() end

	local mark = C_Map.GetUserWaypointPositionForMap(map)
	if mark then
		pin.icon:SetAtlas(C_SuperTrack.IsSuperTrackingUserWaypoint() and "Waypoint-MapPin-Tracked" or "Waypoint-MapPin-Untracked")
		View.Stand(pin, mark:GetXY())
	else
		pin:Hide()
	end
end

-- The zoom changed: each stays where it was read, at its size on screen (read again within LOOK).
local function Restand()
	if not me then return end
	if me:IsShown() then View.Stand(me, me.x, me.y) end
	if corpse:IsShown() then View.Stand(corpse, corpse.x, corpse.y) end
	if pin:IsShown() then View.Stand(pin, pin.x, pin.y) end
	for _, dot in ipairs(mates) do
		if dot:IsShown() then View.Stand(dot, dot.x, dot.y) end
	end
end

local function Turn(dt)
	-- (Turned only as you turn.)
	local facing = GetPlayerFacing()
	if facing and facing ~= me.facing then
		me.facing = facing
		me.icon:SetRotation(facing)
	end
	if pingAt then
		local t = (GetTime() - pingAt) / PING
		if t >= PINGS then
			pingAt = nil
			ring:Hide()
		else
			local f = t % 1
			ring:SetSize(ME * (0.8 + f * 2.4), ME * (0.8 + f * 2.4))
			ring:SetAlpha((1 - f) * 0.9)
			ring:Show()
		end
	end
end

ns.Layer({
	id = "units",
	Use = function(on) if on and not me then Build() end end,
	Map = function()
		Read()
		Ping()
	end,
	Scale = Restand,
	Open = function() Ping() end,
	Tick = function(dt)
		lookIn = lookIn - dt
		if lookIn <= 0 then
			lookIn = LOOK
			Read()
		end
		Turn(dt)
	end,
})
