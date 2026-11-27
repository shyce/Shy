-- The flight or the ride on screen, beside the maps' (Flight.lua, Ride.lua): on the flight master's map a
-- flight point's hover says how long the flight there is in the air, and while flying, or aboard a boat,
-- a zeppelin, an airboat or the tram, a plate in the column at the top's middle (Shy.Top) counts it down,
-- and says for a moment when it is over ("Landed", "Off the boat"). Wherever ShyQuest is loaded the plate
-- stands aside: its arrow counts these down, and the minimap's mark says the time left.
--
-- The hover is a line added to the game's own tooltip, by post-hooks on its taxi map's buttons and on its
-- flight map's points (whichever the flight master opens). The plate has the look of the card's
-- countdown: the way's sign on the left, where to over a bar of the share left, the time at the right.

local Shy = Shy
local UI, HUD, Maps, Flight = Shy.UI, Shy.HUD, Shy.Maps, Shy.Way.Flight
local T = Shy.Way
local C = UI.colors

local PLATE = { w = 232, h = 36, mark = 22, pad = 8, track = 3, clock = 34 }
local SAMPLE = { "Flying to Booty Bay", 0.62, "about 1:24" }   -- the plate in layout mode and in drawings
local OVER_SAID = 4          -- seconds the plate says a flight or a ride is over

-- The hover

local function SayOffer(owner, slot)
	if GameTooltip:GetOwner() ~= owner then return end
	local seconds, timed = Flight.Offer(slot)
	if not seconds then return end
	local said = Flight.Clock(seconds) .. " in the air"
	if not timed then said = "About " .. said end
	local color = Shy.Theme.TRAVEL.flight
	GameTooltip:AddLine(said, color[1], color[2], color[3])
	GameTooltip:Show()
end

local hooked = {}
local function Hover(name)
	if hooked[name] then return end
	if name == "Blizzard_UIPanels_Game" then
		hooksecurefunc("TaxiNodeOnButtonEnter", function(button) SayOffer(button, button:GetID()) end)
	elseif name == "Blizzard_FlightMap" then
		-- (A pin takes the mixin's functions as it is made: hooked as the map loads, before any is.)
		hooksecurefunc(FlightMap_FlightPointPinMixin, "OnMouseEnter", function(pin)
			if pin.taxiNodeData then SayOffer(pin, pin.taxiNodeData.slotIndex) end
		end)
	else
		return
	end
	hooked[name] = true
end

-- The plate

-- The plate's pieces on `f`; f:Say(label, share, said [, sign, color]) fills them, in the way's sign and
-- color (the flight's wing and teal unless told).
local function Plate(f)
	local color = Shy.Theme.TRAVEL.flight
	f:SetSize(PLATE.w, PLATE.h)
	UI.Panel(f, { hud = true, brackets = false })
	local wash = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	wash:SetPoint("TOPLEFT", 1, -1)
	wash:SetPoint("BOTTOMRIGHT", -1, 1)
	wash:SetColorTexture(1, 1, 1, 1)
	local mark = Maps.Mark(f, PLATE.mark)
	mark:SetPoint("CENTER", f, "LEFT", PLATE.pad + PLATE.mark / 2, 0)
	local inset = PLATE.pad * 2 + PLATE.mark
	local label = UI.Text(f, "", 12, false, C.text)
	label:SetPoint("TOPLEFT", inset, -6)
	label:SetWordWrap(false)
	local clock = UI.Text(f, "", 13, true, color)
	clock:SetPoint("TOPRIGHT", -PLATE.pad, -5)
	local words = UI.Text(f, "", 10, false, C.dim)
	words:SetPoint("RIGHT", f, "BOTTOMRIGHT", -PLATE.pad, 8.5)
	local track = f:CreateTexture(nil, "ARTWORK")
	track:SetHeight(PLATE.track)
	track:SetPoint("BOTTOMLEFT", inset, 7)
	UI.Paint(track, C.rowEdge, 1)
	local fill = f:CreateTexture(nil, "ARTWORK", nil, 1)
	fill:SetPoint("TOPLEFT", track, "TOPLEFT")
	fill:SetHeight(PLATE.track)
	f.label, f.clock, f.words, f.fill = label, clock, words, fill
	local function Wear(sign, hue)
		if sign == f.sign and hue == f.hue then return end
		f.sign, f.hue = sign, hue
		wash:SetGradient("HORIZONTAL", CreateColor(hue[1], hue[2], hue[3], 0.16), CreateColor(hue[1], hue[2], hue[3], 0.03))
		mark:Set(sign, hue, false)
		UI.Ink(clock, hue)
		UI.Paint(fill, hue, 1)
	end
	function f:Say(text, share, said, sign, hue)
		Wear(sign or "flight", hue or color)
		if text == self.text and share == self.share and said == self.said then return end
		self.text, self.share, self.said = text, share, said
		-- "about 1:23", "1:05 so far", "landing": the clock large, its words small at the bar's end.
		local before, time, after = said:match("^(.-)%s*(%d+:%d%d)%s*(.*)$")
		if not time then before, time, after = "", said, "" end
		local small = before ~= "" and before or after
		label:SetText(text)
		clock:SetText(time)
		words:SetText(small)
		local room = PLATE.w - inset - PLATE.pad
		label:SetWidth(math.max(20, room - math.max(PLATE.clock, clock:GetStringWidth()) - 8))
		local span = math.max(20, room - (small ~= "" and words:GetStringWidth() + 5 or 0))
		track:SetWidth(span)
		fill:SetWidth(math.max(0.01, span * share))
		fill:SetShown(share > 0)
	end
	return f
end

-- A picture of the plate, for drawings of the screen.
local function Sample(parent)
	local f = Plate(CreateFrame("Frame", nil, parent))
	f:Say(SAMPLE[1], SAMPLE[2], SAMPLE[3])
	return f
end

local box, face
local over                   -- just landed, or off a ride: { text, sign, color, till }
local riding                 -- the ride being taken, as last told (SHY_RIDE)

local function Over()
	if over and GetTime() < over.till then return over end
	over = nil
	return nil
end

-- The ride to count down: none for the tram past its time (it has come in, and there is nothing to say).
local function Riding()
	local ride = T.Riding()
	if ride and ride.tram and not T.RideLeft() then return nil end
	return ride
end

-- Whether there is anything to count down or say.
local function Up()
	return Flight.Now() ~= nil or Riding() ~= nil or Over() ~= nil
end

local function Fill()
	local label, _, share, said = Flight.Left()
	if label then
		face:Say(label, share, said)
		return
	end
	if Flight.Now() then
		-- Asked to land early where the line isn't known: where is the game's to say.
		face:Say("Landing early", 0, "")
		return
	end
	local ride = Riding()
	if ride then
		label, _, share, said = T.RideLeft()
		local look = T.RIDES[ride.by] or T.RIDES.boat
		face:Say(label or look.word, share or 0, said or "", look.sign or "flight", look.color)
		return
	end
	local said = Over()
	if said then
		face:Say(said.text, 0, "", said.sign, said.color)
		return
	end
	face:Say(SAMPLE[1], SAMPLE[2], SAMPLE[3])
end

local function Again()
	HUD.Update(box)
	Shy.Top.Apply()
	Fill()
end

-- Said for a moment once a flight or a ride is over, then the plate goes.
local function Say(text, sign, color)
	over = { text = text, sign = sign, color = color, till = GetTime() + OVER_SAID }
	C_Timer.After(OVER_SAID + 0.1, Again)
end

local function Build()
	box = HUD.Create({
		id = "shy.flight", title = "Flight or ride",
		width = PLATE.w, height = PLATE.h,
		point = { "TOP", "TOP", 0, -4 },
		shown = function() return Up() and Shy.addons.Quest == nil end,
		-- ShyQuest's arrow and the minimap's mark count it down.
		away = function() return Shy.addons.Quest ~= nil end,
		top = { order = 25, sample = Sample, passing = true,
			empty = function() return not Up() and not HUD.IsUnlocked() end },
	})
	face = Plate(CreateFrame("Frame", nil, box))
	face:SetPoint("TOPLEFT")
	HUD.Manage(box, face)
	local wait = 0
	face:SetScript("OnUpdate", function(_, elapsed)
		wait = wait - elapsed
		if wait > 0 then return end
		wait = 0.1
		Fill()
	end)
	local flying
	Shy:On("SHY_FLIGHT", function(flight)
		if flight then
			flying = true
		elseif flying then
			flying = nil
			Say("Landed", "flight", Shy.Theme.TRAVEL.flight)
		end
		Again()
	end)
	Shy:On("SHY_RIDE", function(ride)
		if ride then
			riding = ride
		elseif riding then
			local look = T.RIDES[riding.by] or T.RIDES.boat
			riding = nil
			Say("Off the " .. look.word:lower(), look.sign or "flight", look.color)
		end
		Again()
	end)
	Shy:On("SHY_HUD_LAYOUT", Again)
	Again()
end

Shy:On("SHY_LOGIN", function()
	for _, name in ipairs({ "Blizzard_UIPanels_Game", "Blizzard_FlightMap" }) do
		if C_AddOns.IsAddOnLoaded(name) then Hover(name) end
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("ADDON_LOADED")
	events:SetScript("OnEvent", function(_, _, name) Hover(name) end)
	Build()
end)
