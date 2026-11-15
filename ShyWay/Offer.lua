-- A suggested route, waiting for your answer: a card in the column down from the top's middle while a
-- place someone shared (Share.lua) is open. It says who suggests it, in their class's color, where it is
-- and how long the way there takes, with Accept and Decline under it; the light along its top is the time
-- left to answer, running out. A click on the card shows the place on the map. It comes in with the
-- game's world quest chime and a ring spreading from its pin; the oldest open suggestion shows, the next
-- once that one is answered.
--
-- A ping (something a group member pointed out) has no card: the head at the top says it for a moment.
--
-- /shy routes switches suggestions off and on.

local Way = Shy.Way
local Share = Way.Share
local UI = Shy.UI
local C = UI.colors

local K = {
	WIDTH = 270, HEIGHT = 82,       -- as wide as the pieces it stands among
	PAD = 10,
	PIN = 14,                       -- the pin's glyph, drawn for this size
	SEAT = 30,                      -- the room the pin stands in, left of the words
	GLOW = 44,
	BUTTON = 24, GAP = 6,
	LIGHT = 2,                      -- the light along the top: the time left
	IN = 0.25,                      -- seconds it takes to come in
	PING = 1.1, PINGS = 2,          -- the ring from the pin as it comes: seconds each, and how many
	BREATH = 2.4,                   -- seconds of the glow's slow beat
	PINGED = 8,                     -- seconds the head says what was pointed out
}

local box, shown            -- the card, and the offer it shows
local cameAt = 0

local function Minutes(seconds)
	if seconds < 60 then return "under a minute" end
	return ("%d min"):format(math.floor(seconds / 60 + 0.5))
end

-- "Goldshire  ·  Elwynn Forest 42.1, 65.0  ·  4 min": the place's own name where it has one.
local function Says(offer)
	local parts = {}
	if offer.title ~= ("%s's pin"):format(offer.from) then parts[#parts + 1] = offer.title end
	parts[#parts + 1] = offer.where
	if offer.away == nil then
		local seconds, yards = Share.Away(offer)
		offer.away = seconds and Minutes(seconds) or yards and ("%d yd"):format(math.floor(yards + 0.5)) or false
	end
	if offer.away then parts[#parts + 1] = offer.away end
	return table.concat(parts, "  \194\183  ")
end

local function Fill()
	local offer = shown
	local color = Share.Color(offer.class)
	local r, g, b = 1, 1, 1
	if color then r, g, b = color[1], color[2], color[3] end
	box.who:SetText(("|cff%02x%02x%02x%s|r suggests a route"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
		math.floor(b * 255 + 0.5), offer.from))
	box.what:SetText(Says(offer))
	box.pin:SetVertexColor(r, g, b, 1)
	box.glow:SetVertexColor(r, g, b, 0.5)
	box.ring:SetVertexColor(r, g, b, 1)
	box.light:SetVertexColor(r, g, b, 1)
	local waiting = #Share.Offers()
	box.count:SetText(waiting > 1 and ("+%d"):format(waiting - 1) or "")
end

local function Step(self)
	local offer = shown
	if not offer then return end
	local now = GetTime()
	local age = now - cameAt
	local fight = InCombatLockdown()
	self:SetAlpha(fight and 1 or math.min(1, age / K.IN))
	local left = math.max(0, math.min(1, (offer.till - now) / (offer.till - offer.at)))
	self.light:SetWidth(math.max(0.001, (K.WIDTH - 4) * left))
	-- The ring from the pin, twice as it comes; then the glow's slow beat.
	local t = age / K.PING
	if t < K.PINGS and not fight then
		local f = t % 1
		self.ring:SetSize(K.PIN * (1 + f * 2.6), K.PIN * (1 + f * 2.6))
		self.ring:SetAlpha((1 - f) * 0.9)
		self.ring:Show()
	else
		self.ring:Hide()
	end
	self.glow:SetAlpha(fight and 0.5 or 0.4 + 0.2 * math.sin(now * 2 * math.pi / K.BREATH))
end

local function Build()
	box = Shy.HUD.Create({
		id = "shyway-offer",
		title = "Suggested route",
		width = K.WIDTH,
		height = K.HEIGHT,
		point = { "TOP", "TOP", 0, -150 },
		shown = function() return shown ~= nil end,
		-- In the column down from the top's middle: under the waypoint arrow, over a group's status.
		top = { order = 32, passing = true },
	})
	UI.Panel(box, { brackets = false, hud = true })

	box.light = box:CreateTexture(nil, "OVERLAY")
	box.light:SetColorTexture(1, 1, 1, 1)
	box.light:SetHeight(K.LIGHT)
	box.light:SetPoint("TOPLEFT", 2, -2)

	local seat = K.PAD + K.SEAT / 2
	box.glow = box:CreateTexture(nil, "BACKGROUND", nil, 2)
	box.glow:SetTexture(Shy.MEDIA .. "Glow")
	box.glow:SetSize(K.GLOW, K.GLOW)
	box.glow:SetPoint("CENTER", box, "TOPLEFT", seat, -(K.PAD + 15))
	box.pin = box:CreateTexture(nil, "ARTWORK")
	box.pin:SetTexture(Shy.Skin.GLYPH.pin)
	box.pin:SetSize(K.PIN, K.PIN)
	box.pin:SetPoint("CENTER", box.glow, "CENTER")
	box.ring = box:CreateTexture(nil, "OVERLAY")
	box.ring:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Expand")
	box.ring:SetBlendMode("ADD")
	box.ring:SetPoint("CENTER", box.pin, "CENTER")
	box.ring:Hide()

	local left = K.PAD + K.SEAT + 4
	box.count = UI.Text(box, "", 11, false, C.dim)
	box.count:SetPoint("TOPRIGHT", -K.PAD, -K.PAD)
	box.who = box:CreateFontString(nil, "OVERLAY")
	box.who:SetFontObject(UI.NameFont(13))
	box.who:SetPoint("TOPLEFT", left, -K.PAD)
	box.who:SetWidth(K.WIDTH - left - K.PAD - 22)
	box.who:SetJustifyH("LEFT")
	box.who:SetWordWrap(false)
	box.what = UI.Text(box, "", 11, false, C.dim)
	box.what:SetPoint("TOPLEFT", box.who, "BOTTOMLEFT", 0, -3)
	box.what:SetWidth(K.WIDTH - left - K.PAD)
	box.what:SetJustifyH("LEFT")
	box.what:SetWordWrap(false)

	local wide = (K.WIDTH - K.PAD * 2 - K.GAP) / 2
	box.accept = UI.Button(box, "Accept", wide, function()
		if shown then Share.Accept(shown) end
	end)
	box.accept:SetPrimary(true)
	box.accept:SetPoint("BOTTOMLEFT", K.PAD, K.PAD - 2)
	box.decline = UI.Button(box, "Decline", wide, function()
		if shown then Share.Decline(shown) end
	end)
	box.decline:SetPoint("BOTTOMRIGHT", -K.PAD, K.PAD - 2)

	box:EnableMouse(true)
	box:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or Shy.HUD.WasDragged(box) or not shown or InCombatLockdown() then return end
		OpenWorldMap(shown.map)
	end)
	Shy.HUD.Manage(box, box, function(root)
		root:CreateButton("Accept", function() if shown then Share.Accept(shown) end end)
		root:CreateButton("Decline", function() if shown then Share.Decline(shown) end end)
		root:CreateDivider()
		root:CreateButton("Stop offering routes", function()
			Share.SetOn(false)
			Shy.addons.Way:Print("routes your friends suggest are off. Turn them back on with /shy routes.")
		end)
	end)
	box:SetScript("OnUpdate", Step)
end

-- The oldest open suggestion shows. A new one rings as it comes.
local function Refresh(what, record)
	if not box then return end
	local first = Share.Offers()[1]
	if what == "offer" and record and not record.rung then
		record.rung = true
		PlaySound(SOUNDKIT.UI_WORLDQUEST_START)
	end
	if first ~= shown then
		shown = first
		cameAt = GetTime()
	end
	if shown then Fill() end
	Shy.HUD.Update(box)
end

-- Something a group member pointed out (Share.Ping): the head says what and who for a few seconds, in
-- their class's color, the raid mark before its name; a click on it has it lead you there.
local function Pinged(ping)
	local head = Shy.Notices
	if not (head and head.Voice) then return end
	local color = Share.Color(ping.class) or C.text
	local mark = ping.mark and ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t "):format(ping.mark) or ""
	head.Voice("shyway-ping", { priority = 6, hold = K.PINGED, glyph = "go", color = color, lamp = color, pulse = true,
		title = mark .. ping.title, under = ping.from .. " pinged it",
		click = function() Share.Lead(ping) end })
end

Shy:On("SHY_WAY_SHARE", function(what, record)
	if what == "offer" or what == "gone" then
		Refresh(what, record)
	elseif what == "ping" then
		Pinged(record)
	end
end)

Shy:On("SHY_LOGIN", function()
	Build()
	Refresh()
end)

Shy.Command("routes", "the routes your friends suggest, offered or not", function()
	Share.SetOn(not Share.On())
	Shy.addons.Way:Print(Share.On() and "routes your friends suggest are offered again." or "routes your friends suggest are off.")
end)
