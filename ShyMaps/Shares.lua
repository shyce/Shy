-- Places shared as routes (Shy.Way.Share), on the map.
--
-- The share button on the map's bar, a pin: it is lit while you have a pin, and its menu sends your pin or
-- where you stand to your group or a friend as a route they can accept, links the pin in any chat, drops
-- the pin with your next click on the map, or takes it away.
--
-- A route someone suggested stands on the map while it waits for your answer: a pin in their class's
-- color with their name under it and a ring beating out of it. Its hover says who, where and how far; a
-- click accepts it, a right click declines. Something a group member pinged stands the same way for a few
-- seconds, under its raid mark and name; a click has it lead you there.
--
-- None of it while ShyWay is off.

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI

local Share = Shy.Way.Share
if Shy.Way.missing or not (Share and Share.Offers) then return end

local K = {
	PIN = 16,               -- an offered pin, in units on screen
	GLOW = 40,
	BEAT = 1.4,             -- seconds a ring takes out of an offered pin
	REACH = 2.8,            -- how many times the pin's size the ring grows to
	MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_",
}

local pins = {}
local used = 0
local button                -- the bar's share button, once made

-- Where an offer lies on the map shown, as shares of it; nil off it.
local function OnShown(offer, map)
	if offer.map == map then return offer.x, offer.y end
	local continent, position = C_Map.GetWorldPosFromMapPos(offer.map, CreateVector2D(offer.x, offer.y))
	if not (continent and position) then return nil end
	local north, west = position:GetXY()
	local x, y = ns.OnMap(map, continent, north, west)
	if not x then
		local _, spot = C_Map.GetMapPosFromWorldPos(continent, CreateVector2D(north, west), map)
		if spot then x, y = spot:GetXY() end
	end
	if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return x, y end
	return nil
end

local function Tip(pin)
	local ping = pin.ping
	if ping then
		Shy.Hover.Show(pin, { title = ping.title, sub = ping.from .. " pinged it", titleColor = Share.Color(ping.class),
			sections = { { rows = { { glyph = "go", text = ping.where } } } }, hints = { { "left", "Lead me there" } } })
		return
	end
	local offer = pin.offer
	if not offer then return end
	local color = Share.Color(offer.class)
	local rows = { { glyph = "go", text = offer.where } }
	local seconds, yards = Share.Away(offer)
	if seconds then
		rows[#rows + 1] = { glyph = "clock", text = seconds < 60 and "Under a minute away" or ("%d min away"):format(math.floor(seconds / 60 + 0.5)) }
	elseif yards then
		rows[#rows + 1] = { glyph = "clock", text = ("%d yd away"):format(math.floor(yards + 0.5)) }
	end
	Shy.Hover.Show(pin, { title = offer.from, titleColor = color, sub = "Suggests a route", sections = { { rows = rows } },
		hints = { { "left", "Accept" }, { "right", "Decline" } } })
end

local function Click(pin, mouse)
	if pin.ping then
		UI.TipHide(pin)
		if mouse == "LeftButton" then Share.Lead(pin.ping) end
		return
	end
	local offer = pin.offer
	if not offer then return end
	UI.TipHide(pin)
	if mouse == "RightButton" then Share.Decline(offer) else Share.Accept(offer) end
end

local function Pin(i)
	local pin = pins[i]
	if not pin then
		pin = View.Pin("PIN_FRAME_LEVEL_TOPMOST", K.PIN, Tip, Click)
		pin.icon:SetTexture(Shy.Skin.GLYPH.pin)
		pin.glow = pin:CreateTexture(nil, "BACKGROUND")
		pin.glow:SetTexture(Shy.MEDIA .. "Glow")
		pin.glow:SetPoint("CENTER")
		pin.glow:SetSize(K.GLOW, K.GLOW)
		pin.ring = pin:CreateTexture(nil, "OVERLAY")
		pin.ring:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Expand")
		pin.ring:SetBlendMode("ADD")
		pin.ring:SetPoint("CENTER")
		pin.label = pin:CreateFontString(nil, "OVERLAY")
		pin.label:SetFontObject(UI.NameFont(10, "OUTLINE"))
		pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
		pins[i] = pin
	end
	return pin
end

-- A pin for an offer (the sender's name under it) or a ping (what was pointed out, under its raid mark).
local function Put(record, ping, map)
	local x, y = OnShown(record, map)
	if not x then return end
	used = used + 1
	local pin = Pin(used)
	local color = Share.Color(record.class)
	local r, g, b = 1, 1, 1
	if color then r, g, b = color[1], color[2], color[3] end
	pin.offer, pin.ping = not ping and record or nil, ping and record or nil
	if ping and record.mark then
		pin.icon:SetTexture(K.MARK .. record.mark)
		pin.icon:SetVertexColor(1, 1, 1, 1)
	else
		pin.icon:SetTexture(Shy.Skin.GLYPH.pin)
		pin.icon:SetVertexColor(r, g, b, 1)
	end
	pin.glow:SetVertexColor(r, g, b, 0.55)
	pin.ring:SetVertexColor(r, g, b, 1)
	pin.label:SetText(ping and record.title or record.from)
	pin.label:SetTextColor(r, g, b)
	View.Stand(pin, x, y)
end

local function Draw()
	local map = View.Map()
	used = 0
	if map and View.IsOpen() then
		for _, offer in ipairs(Share.Offers()) do Put(offer, false, map) end
		for _, ping in ipairs(Share.Pings()) do Put(ping, true, map) end
	end
	for i = used + 1, #pins do
		pins[i].offer, pins[i].ping = nil, nil
		pins[i]:Hide()
	end
end

local function Restand()
	for i = 1, used do
		local pin = pins[i]
		if pin:IsShown() then View.Stand(pin, pin.x, pin.y) end
	end
end

-- The ring out of each waiting pin.
local function Beat()
	if used == 0 then return end
	local f = (GetTime() % K.BEAT) / K.BEAT
	local size, alpha = K.PIN * (1 + f * (K.REACH - 1)), (1 - f) * 0.9
	for i = 1, used do
		local ring = pins[i].ring
		ring:SetSize(size, size)
		ring:SetAlpha(alpha)
	end
end

ns.Layer({
	id = "shares",
	later = true,
	Open = Draw,
	Map = Draw,
	Scale = Restand,
	Use = function(on) if not on then Draw() end end,
	Tick = Beat,
})

Shy:On("SHY_WAY_SHARE", function(what)
	if (what == "offer" or what == "gone" or what == "ping" or what == "unping") and View.IsOpen() then Draw() end
end)

-- The bar's share button

local function Lit()
	return C_Map.HasUserWaypoint() == true
end

local function Write(root)
	root:CreateTitle("Share a place")
	local pinned = Lit()
	if pinned then
		ns.PinMenu(root)
		root:CreateDivider()
	end
	local drop = root:CreateButton(pinned and "Move my pin" or "Drop a pin", function()
		if ns.Nav and ns.Nav.PinNext then ns.Nav.PinNext(true) end
	end)
	drop:SetSub("Then click the map where you want it")
	local here = Share.Write(root, Share.Here, "Share where I am with")
	if not Share.Here() then
		here:SetEnabled(false)
		here:SetDetail("not on this map")
	end
end

if T.BarButton then
	T:BarButton("share", {
		art = Shy.Skin.GLYPH.pin, size = 14, order = 1,
		tip = "Share a place",
		text = "Send your pin, or where you are, to your group or a friend. They get it as a route they can accept.",
		hints = { { "left", "Choose what to share" } },
		lit = Lit,
		click = function(self) UI.DropMenu(self, Write) end,
		made = function(made) button = made end,
	})
end

local events = CreateFrame("Frame")
events:RegisterEvent("USER_WAYPOINT_UPDATED")
events:SetScript("OnEvent", function()
	if button and not UI.PinBorrowed() then button:SetOn(Lit()) end
end)
