-- A suggested route, waiting for your answer: a row of ShyCore's group piece (Shy.Party), in the drawer under the
-- head, while a place someone shared (Share.lua) is open. It says who suggests it, in their class's color, where it
-- is and how long the way there takes, with Accept and Decline at its end; its weave is the time left to answer,
-- draining. A click on it shows the place on the map. It comes in with the game's world quest chime.
--
-- A ping (something a group member pointed out) has no row: the head at the top says it for a moment.
--
-- /shy routes switches suggestions off and on, and so does the group piece's layout panel.

local Way = Shy.Way
local Share = Way.Share
local UI = Shy.UI
local C = UI.colors

local K = {
	PINGED = 8,                     -- seconds the head says what was pointed out
}
local DOT = "  \194\183  "

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
	return table.concat(parts, DOT)
end

local function Accept(row) Share.Accept(row.offer) end
local function Decline(row) Share.Decline(row.offer) end
local function Show(row) Shy.Maps.Open(row.offer.map) end

-- The open suggestions, oldest first, as the group piece's rows. A new one rings as it comes.
local function Refresh(what, record)
	local Party = Shy.Party
	if not Party then return end
	if what == "offer" and record and not record.rung then
		record.rung = true
		PlaySound(SOUNDKIT.UI_WORLDQUEST_START)
	end
	local rows = {}
	for _, offer in ipairs(Share.Offers()) do
		rows[#rows + 1] = { key = offer.key, offer = offer, from = offer.from, color = Share.Color(offer.class),
			says = Says(offer), at = offer.at, till = offer.till, accept = Accept, decline = Decline, show = Show }
	end
	Party.Offers(rows)
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
	if not Shy.Party then return end
	Shy.Party.Setting("routes", {
		label = "Suggested routes", hint = "Places your friends send you, to take or leave.",
		get = Share.On,
		set = function(on) Share.SetOn(on) end,
	})
	Refresh()
end)

-- (For finding faults: the routes your friends suggest, offered or not. Not listed.)
Shy.Command("routes", nil, function()
	Share.SetOn(not Share.On())
	Shy.addons.Way:Print(Share.On() and "routes your friends suggest are offered again." or "routes your friends suggest are off.")
end)
