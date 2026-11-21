-- The waypoint arrow: a movable Shy.HUD box (dial, name, zone line) pointing at one place. Also /way.
--
--   ns.Arrow.Point({ map =, x =, y =, title =, typed = })   -- x, y 0-9999 (Data.lua's units)
--   ns.Arrow.ToStop(stop)      -- follows a route stop across rebuilds; cleared when the stop is gone
--   ns.Arrow.Clear()
--   ns.Arrow.Target()          -- current target or nil
--   ns.Arrow.Pieces()          -- box, dial, title, sub
--   ns.Arrow.Seat()            -- its pieces in the head's circle (see "In the head"), or nil
--   ns.Arrow.Sample(parent)    -- the arrow as a picture for a picker, drawn by the box's own builder:
--                              -- a frame with :Set(on), pointing at the step the route leads with
--
-- When you stand on the ground where a followed stop's work is found (stop.among, Route.lua: kills,
-- loot and gathering can be done anywhere on it), there is nowhere left to point. The hand hides. The
-- emblem of what is found fills the dial in place of the yards, in its color, and the ring takes that
-- color too (like the quest window's dial, Card.lua). The line under the name says it is here.
-- At any other stop (within ARRIVED yards: a vendor, a trainer, a flight master, someone to talk to)
-- the hand hides too. The emblem of what the stop is for fills the dial in its color (Emblem: a
-- vendor's coin in copper, a trainer's book in periwinkle, a quest's gold mark). The dial is never empty.
--
-- The hand points along the way the maps draw (W.Heading), a few yards ahead of the player, so it
-- turns with each bend of the trail. When the place itself lies well off that heading, a smaller
-- arrowhead of the same make rides the ring toward it, in the accent. The hand is which way to go
-- now. The small one is where it all leads.
--
-- The look: a dark dial in a steel ring, with the name on a plaque that runs to a point. The accent
-- is its light: along the plaque's top edge, on the ring either side of the hand, on the face under
-- it, and on the hand itself. The hand sits in a dark rim so a pale or steel-like color still reads.
--
--   /way 45.2 33.1 [name]            current map
--   /way Darnassus 45.2 33.1 [name]  another zone (or #1457, a map ID)
--   /way clear
-- A /way target is saved per character until reached or cleared, and sets the map's user waypoint.

local ADDON, ns = ...
local T = ns.T
local W, R = ns.World, ns.Route
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors

local A = {}
ns.Arrow = A

local MEDIA = Shy.MEDIA
local UNITS = 10000
local DIAL, DIAL_ART = 46, 56        -- ring size, and the canvas its art is drawn on (as ShyCore's Hover.lua)
local FACE_INNER = 40                -- the dial's face inside its ring: the weave disc made for it (HatchDisc40)
local HAND_ART = 64                  -- the canvas the hand is drawn on: it reaches past the ring
local POINT, PLAQUE = 8, 23          -- plaque: width of its pointed end, height
local LIGHT = 12                     -- height of the plaque's top light (as ShyCore's Hover.lua)
local WIDTH = 196
local OFF = 0.35                     -- how much of a picker's picture shows while the arrow is off
local SAMPLE = { title = "Your next step", sub = "The zone and the place", yards = "120", turn = -0.7, heading = 0.35 }
local HEADING_ALPHA = 0.85           -- the heading's mark is the accent, a little faint (as the media sheet draws it)
local APART = math.rad(25)           -- the heading shows once the place lies this far off where the hand points
local FADE = 8                       -- ... and fades in and out at this share a second
local MARK = 44                      -- the emblem that fills the dial on the ground where a thing is found (MarksLarge's cell, drawn for it)
local ARRIVED = 10                   -- yards
local EVERY = 0.2                    -- seconds between distance updates

local box, dial, title, sub
local target                         -- { map, x, y, title, key, about (the route's stop it follows), following, typed, among,
                                     --   continent, north, west, floor, up }
local held                           -- what it pointed at when a stop that can't wait took it (a ghost's body)
local since = 0

local function Words(parent, size, color, named)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(named and UI.TitleFont(size) or UI.TextFont(size))
	UI.Follow(fs)   -- a title keeps up with the theme's font
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	UI.Ink(fs, color or C.text)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(false)
	return fs
end

-- Same continent as the player, so a distance can be measured. place: the target unless given.
local function Near(place)
	place = place or target
	return place.north ~= nil and W.Known() and place.continent == W.continent
end

local function Yards(place)
	place = place or target
	return Near(place) and W.Between(W.north, W.west, place.north, place.west) or nil
end

local function Far(yards)
	return yards >= 1000 and ("%.1fk"):format(yards / 1000) or ("%d"):format(math.floor(yards + 0.5))
end

-- The hand and the light it throws, turned which way to go; put away with nowhere to point. heading:
-- where the place itself lies, its mark on the ring while that is well off the hand. elapsed: seconds
-- since the last frame, for the mark to fade (none: at once).
-- (Asked every frame: each piece is told only what changed, a turn past a hair of it. dial.aimed: as last told.)
local HAIR = 0.002
local function Aim(dial, turn, heading, elapsed)
	local aimed = dial.aimed
	if not aimed then
		aimed = {}
		dial.aimed = aimed
	end
	local on = turn ~= nil
	if aimed.on ~= on then
		aimed.on, aimed.turn = on, nil
		dial.hand:SetShown(on)
		dial.beam:SetShown(on)
	end
	if turn and (aimed.turn == nil or math.abs(aimed.turn - turn) > HAIR) then
		aimed.turn = turn
		dial.hand:SetRotation(turn)
		dial.beam:SetRotation(turn)
	end
	local apart = turn ~= nil and heading ~= nil and math.abs((heading - turn + math.pi) % (2 * math.pi) - math.pi) > APART
	local want = apart and 1 or 0
	local alpha = dial.headingAlpha or 0
	if alpha ~= want then
		alpha = elapsed and alpha + (want - alpha) * math.min(1, elapsed * FADE) or want
		if math.abs(alpha - want) < 0.02 then alpha = want end
		dial.headingAlpha = alpha
		dial.heading:SetAlpha(alpha)
	end
	local showing = alpha > 0
	if aimed.heading ~= showing then
		aimed.heading, aimed.bearing = showing, nil
		dial.heading:SetShown(showing)
	end
	if heading and showing and (aimed.bearing == nil or math.abs(aimed.bearing - heading) > HAIR) then
		aimed.bearing = heading
		dial.heading:SetRotation(heading)
	end
end

-- "Teldrassil  45.2, 33.1"
local function Where(place)
	local name = W.MapName(place.map)
	local at = ("%.1f, %.1f"):format(place.x / 100, place.y / 100)
	return name and (name .. "  " .. at) or at
end

-- What a stop is for (ns.StopSign, as the card's dial and tag have it): the emblem that fills the dial once
-- there (a cell of the marks' sheet) and its color, then the mark the card's tag is set with (its kind,
-- an objective's tone). An objective's kind, a quest's gold
-- mark to take or hand in, an errand's sign (a vendor's coin, a trainer's book, a flight's wing); the banner
-- for a stop that only goes somewhere, the glass for what a search found.
local function Emblem(stop)
	local sign, tone = ns.StopSign(stop)
	if not sign then
		-- A stop that only goes somewhere (a guide's step with no mark, an errand with no sign, a flight to
		-- take, a zone to start in, what a search found): the mark the card's dial wears for it, the banner
		-- for a place, the wing for a flight, the glass for a find, filling the circle in the place's ice
		-- blue, the flight's teal or the route's white once there.
		local kind = ns.StopMark(stop)
		if kind == "fly" then return "flight", ns.SignColor("flight"), kind end
		-- (A zone's tag is the banner too: its own mark is the map's pin with a count.)
		if kind == "zone" then return "go", ns.ToneColor("go"), "guide" end
		if kind == "guide" or kind == "errand" or kind == "way" then return "go", ns.ToneColor("go"), kind end
		return nil
	end
	if sign == "goal" then return ns.ToneSign(tone), ns.ToneColor(tone), sign, tone end
	-- (What a search found comes back as its own kind: the glass, in the route's white.)
	if sign == "found" then return "find", ns.ToneColor("find"), sign end
	if sign == "pickup" then return "!", ns.MARK.gold, sign end
	if sign == "turnin" then return "?", ns.MARK.gold, sign end
	local cell = sign == "fly" and "flight" or sign
	local color = ns.SignColor(cell)
	if color then return cell, color, sign end
	return nil
end

-- The objective a quest's stop leads with (Route.lua: on a ground of several, the one at hand), or nil:
-- { name, count (its "0/1", or nil), several (the quest has more than one: the name is the objective's,
-- not the quest's), creature (an NPC to show in the circle), shade }.
local function Leading(stop)
	local action = stop and stop.kind == "goal" and stop.objective and stop.actions and stop.actions[1]
	local goal = action and ns.Log.Has(action.id) and ns.Log.Goals(action.id)[stop.objective]
	if not (goal and goal.text and goal.text ~= "") then return nil end
	local source = stop.source
	local one = ns.Objective(action.id, stop.objective)
	local name = (goal.text:gsub("^%s*%d+/%d+%s+", ""):gsub("%s*:%s*%d+/%d+%s*$", ""))
	return { name = name, count = (goal.need or 0) > 0 and ("%d/%d"):format(goal.have or 0, goal.need) or nil, several = one ~= nil,
		shade = one and one.shade or nil,
		creature = source and (source.how == "kill" or source.how == "drops") and source.id or nil }
end

-- What the arrow names: in a quest of several, the objective it leads to with its count, never the quest
-- (the card and the map name the rest); anything else as the card does.
local function Named(stop, leading)
	if leading and leading.several then
		return leading.name .. (leading.count and ("  " .. UI.Wrap(C.dim, leading.count)) or "")
	end
	return (R.Describe(stop))
end

-- The creature an objective is got from, live in the circle once there (a portrait, facing out), in place
-- of the kind's emblem: a square inside the face, so nothing of it reaches the ring. Asked for by the
-- display it wears where the data knows it (D.Look: drawn at once), else by creature, which comes in only
-- once the game has met one; until it is in, and for anything else, the emblem stays.
local PORTRAIT = 28                  -- inside the face's 40: a square that fits the circle
local PATIENCE = 1.0                 -- seconds a display is waited for before the creature is asked for instead
local function Portrait(frame, d)
	local model = CreateFrame("PlayerModel", nil, frame)
	model:SetSize(PORTRAIT, PORTRAIT)
	model:SetPoint("CENTER", 0, -1)
	model:SetFrameLevel(frame:GetFrameLevel() + 1)
	model:Hide()
	model:SetScript("OnModelLoaded", function(self)
		self.loaded = true
		self:SetPortraitZoom(0.9)
		self:SetFacing(0)
		self:SetAlpha(1)
	end)
	d.portrait = model
end

-- Shows `creature` in the circle (nil: none). Whether its model is in, so it stands in for the emblem.
local function Face(d, creature)
	local model = d.portrait
	if not model then return false end
	if model.creature ~= creature then
		model.creature, model.loaded, model.asked = creature, false, GetTime()
		model:SetAlpha(0)
		model:ClearModel()
		local display = creature and ns.Data.Look("n", creature)
		model.display = display or nil
		-- (The creature as itself, its display beside it: drawn at once for one the game has met.)
		if creature then model:SetCreature(creature, display or 0) end
	end
	model:SetShown(creature ~= nil)
	if creature and not model.loaded then
		-- (Some models are in before the frame says so.)
		local ok, file = pcall(model.GetModelFileID, model)
		if ok and type(file) == "number" and file > 0 then
			model:GetScript("OnModelLoaded")(model)
		elseif model.display and GetTime() - model.asked > PATIENCE then
			-- Nothing in after a moment (a creature the game hasn't met): its display alone.
			local display = model.display
			model.display = nil
			model:ClearModel()
			model:SetDisplayInfo(display)
		end
	end
	return creature ~= nil and model.loaded == true
end

-- With nowhere more to point, what fills the dial in place of the yards: its emblem in its color, the ring
-- taking that color too (never the lit plate: a lit bag is one flat dark shape), and the line under the
-- name saying so. Returns whether that is how it stands.
--   sign, color: the emblem (a cell of the marks' sheet) and its color; nil for none
--   words, ink: what the line under the name says and its color (nil: the line is left as it is)
local function Found(d, under, sign, color, words, ink)
	d.mark:SetShown(sign ~= nil)
	d.yards:SetShown(sign == nil)
	d.unit:SetShown(sign == nil)
	UI.Ink(under, ink or C.dim)
	if sign ~= d.among then
		d.among = sign
		UI.Tint(d.face, sign and color or Theme.skin.metal)
		Shy.Skin.WeaveTint(d.weave, sign and color or Theme.skin.metal)
		if sign then
			d.mark:SetTexCoord(unpack(ns.MarkPicture(sign)))
			UI.Tint(d.mark, color)
		end
	end
	if sign and words then under:SetText(words) end
	return sign ~= nil
end

-- The emblem the target shows where the player stands, its color, and what the line under the name says
-- of it: on the ground where what it asks for is found (among), that, in its kind's color, the line naming
-- what is got from here and what other quests find here too (R.Found); arrived at the stop (yards, within
-- ARRIVED), what the stop is for (Emblem), the line as it was. Nothing on the way.
local function Here(yards)
	if target.among then
		-- In a quest of several, the objective at hand: its shade, and the line in a light of it.
		local leading = target.leading
		local own = leading and leading.several and leading.shade
		if own then
			return ns.ToneSign(target.among), own, target.found or "Found around here",
				{ own[1] + (1 - own[1]) * 0.35, own[2] + (1 - own[2]) * 0.35, own[3] + (1 - own[3]) * 0.35 }
		end
		return ns.ToneSign(target.among), ns.ToneColor(target.among), target.found or "Found around here", C.good
	end
	if target.sign and yards and yards <= ARRIVED then return target.sign, target.hue end
	return nil
end

-- Carried: aboard a boat, a zeppelin, an airboat or the tram (Shy.Way.Riding), or on a flight. There is
-- nowhere to point from there: the ride's sign fills the dial in its color (the hand put away, Step), and
-- the line under the name says where it goes and how long it has to go. Returns the sign, its color, the
-- ride ("Zeppelin to Undercity") and the time in words; nothing while on foot.
local carried                        -- whether so, as last written (Step aims the hand only when not)
local lead                           -- the ride, as the plate's name while carried ("Airship to Thunder Bluff")
local function Aboard()
	local ride = Shy.Way.Riding()
	local label, _, share, said
	local sign
	if ride then
		label, _, share, said = Shy.Way.RideLeft()
		local look = label and Shy.Way.RIDES[ride.by]
		sign = label and (look and look.sign or "flight") or nil
	elseif UnitOnTaxi("player") then
		label, _, share, said = Shy.Way.Flight.Left()
		sign = label and "flight" or nil
	end
	carried = sign ~= nil
	lead = sign and label or nil
	if not sign then return nil end
	return sign, ns.SignColor(sign), label, said
end

-- The line under the ride's name: when it lands, and no more (what comes after is on the map and the
-- card). "about 2:24" -> "Lands in about 2:24"; "landing", "arriving", "1:05 so far" stand as they are.
local function Landing(said)
	local words = said or "Aboard"
	if words:match("^%d+:%d%d$") or words:match("^about %d+:%d%d$") then words = "Lands in " .. words end
	return (words:gsub("^%l", string.upper))
end

-- Just off a ride: the line under the name says so for a moment, in the ride's color.
local OFF_SAID = 4                   -- seconds
local off                            -- { text, color, till }
local riding                         -- the ride being taken, as last told (SHY_RIDE)
local function JustOff()
	if off and GetTime() < off.till then return off.text, off.color end
	off = nil
	return nil
end

local function Ride(d, under)
	local sign, color, _, said = Aboard()
	if not sign then return false end
	return Found(d, under, sign, color, Landing(said))
end

local function Write()
	if not (box and target) then return end
	if Ride(dial, sub) then
		title:SetText(lead)
		return
	end
	title:SetText(target.title)
	local yards = Yards()
	Found(dial, sub, Here(yards))
	-- On its ground, the creature it is got from in the circle, once the game has it.
	if Face(dial, target.among and target.leading and target.leading.creature or nil) then dial.mark:Hide() end
	if target.among then return end
	local offText, offColor = JustOff()
	if offText then
		dial.yards:SetText(yards and Far(yards) or "?")
		sub:SetText(offText)
		UI.Ink(sub, offColor)
		return
	end
	if yards then
		dial.yards:SetText(Far(yards))
		sub:SetText(Where(target))
	else
		dial.yards:SetText("?")
		sub:SetText(Where(target) .. (W.Known() and "  (another continent)" or ""))
	end
	-- Close to a cliff the way goes down or water it walks over: the spell to cast, in its picture.
	local cue = yards and ns.Glide and ns.Glide.Cue(target.continent, target.north, target.west, target.floor, target.up)
	if cue then
		sub:SetText(ns.Glide.IconText(cue.icon, 12) .. " " .. cue.text)
		UI.Ink(sub, cue.on and C.good or C.alert)
	end
end

-- Whether the map's user waypoint is still the one /way set.
local function OurPin()
	if not (target and target.pin) then return false end
	local point = Shy.Waypoint.Get()
	if not point or point.uiMapID ~= target.map then return false end
	-- (A pin set from a chat link has a plain { x, y } position, not a vector: read the fields.)
	local pos = point.position
	local x, y = pos and pos.x, pos and pos.y
	if not (x and y) then return false end
	return math.abs(x * UNITS - target.x) < 2 and math.abs(y * UNITS - target.y) < 2
end

-- Following (ns.char.arrow, per character): the arrow stays on screen and points at whatever the
-- quest window is heading for, moving on as steps are done. A /way target or a stop pointed at by
-- hand takes the arrow until it is reached or cleared, then the steps have it again.
local ToLead   -- defined below, once A.Point is

function A.Following()
	return ns.char ~= nil and ns.char.arrow == true
end

function A.Clear()
	if not target then return end
	local was = target
	if OurPin() then Shy.Waypoint.Clear() end
	target = nil
	ns.char.way = nil
	if box then Shy.HUD.Update(box) end
	A.Voice()
	if A.Following() and not was.lead then ToLead() end
end

-- Puts the arrow away for good: following stops too.
local function PutAway()
	ns.char.arrow = nil
	held = nil
	A.Clear()
	if ns.ApplyCard then ns.ApplyCard() end
end

function A.Target()
	return target
end

function A.Pieces()
	return box, dial, title, sub
end

-- The waypoint the arrow leads to, where it is yours to take away: a stop of your route (a guard's directions, a
-- spot set on the map, a /way) or a place pointed at by hand. Returns the route's stop index (0: none) and whether
-- the arrow's own target goes.
local function Yours()
	if not target then return nil end
	local stop = ns.Plan and ns.Plan.Has(target.map, target.x, target.y) or 0
	local own = target.typed or not target.lead
	if stop > 0 or own then return stop, own end
end

-- Taken away: its stop leaves the route (and the map's pin with it), and the arrow goes back to what leads.
local function RemoveWaypoint()
	local stop, own = Yours()
	if not stop then return end
	if own then A.Clear() end
	if stop > 0 then ns.Plan.Remove(stop) end
end

local function Menu(root)
	if Yours() then root:CreateButton("Remove waypoint", RemoveWaypoint) end
	root:CreateCheckbox("Follow my steps", A.Following, function() A.Follow(not A.Following()) end)
	root:CreateButton("Hide arrow", PutAway)
end

-- A frame of the arrow's: the hand of dial `d` turns every frame; `write` says where on the EVERY clock.
local function Step(d, elapsed, write)
	if not target then return end
	local yards = Yards()
	since = since + elapsed
	local due = since >= EVERY
	if due then
		since = 0
		write()
	end
	local turn, heading
	-- (Carried, there is nowhere to point from: the ride's sign has the dial.)
	if not target.among and not carried and yards and yards > ARRIVED then
		turn, heading = W.Heading(target.continent, target.north, target.west, d.keep, elapsed)
	end
	Aim(d, turn, heading, elapsed)
	if not due then return end
	-- A target that follows a route stop stays until the route drops the stop.
	if yards and yards <= ARRIVED and not target.following then
		local name = target.title
		A.Clear()
		T:Print(("reached |cffffffff%s|r, arrow hidden."):format(name))
	end
end

local function Tick(_, elapsed)
	Step(dial, elapsed, Write)
end

-- The arrow's pieces on a frame of its size (WIDTH by DIAL + 2): the box on screen, and its picture
-- in a picker. Every color is the theme's own table, so all of it follows a change of accent; the plaque is
-- dressed again in the look's material on a change of theme.
local plaques = setmetatable({}, { __mode = "k" })
Shy:On("SHY_THEME", function()
	for plaque in pairs(plaques) do Shy.Top.Make.Look(plaque) end
end)
local function Draw(f)
	local plaque = { strip = f:CreateTexture(nil, "ARTWORK", nil, -2), point = f:CreateTexture(nil, "ARTWORK", nil, -2) }
	plaque.strip:SetTexture(MEDIA .. "HoverPlaqueMid")
	plaque.point:SetTexture(MEDIA .. "HoverPlaqueEnd")
	plaque.point:SetSize(POINT, PLAQUE)
	plaque.point:SetPoint("TOPRIGHT", 0, -2)
	plaque.strip:SetPoint("TOPLEFT", DIAL / 2, -2)
	plaque.strip:SetPoint("BOTTOMRIGHT", plaque.point, "BOTTOMLEFT")
	-- The accent as light in the plaque's top edge, from the dial to the point.
	plaque.light = f:CreateTexture(nil, "ARTWORK", nil, 1)   -- over the plaque's material
	plaque.light:SetTexture(MEDIA .. "HoverLight")
	plaque.light:SetHeight(LIGHT)
	plaque.light:SetPoint("TOPLEFT", DIAL - 4, -2)
	plaque.light:SetPoint("TOPRIGHT", plaque.point, "TOPLEFT", 2, 0)
	UI.Tint(plaque.light, Theme.Accent)
	-- The column's make: in every look but Forged the look's own housing where the plaque stands.
	local Make = Shy.Top and Shy.Top.Make
	if Make and Make.Material then
		plaque.mid = plaque.strip
		plaque.tail = plaque.point
		local area = CreateFrame("Frame", nil, f)
		area:SetPoint("TOPLEFT", plaque.strip, "TOPLEFT")
		area:SetPoint("BOTTOMRIGHT", plaque.point, "BOTTOMRIGHT")
		Make.Material(f, plaque, area)
		Make.Look(plaque)
		plaques[plaque] = true
	end

	local d = CreateFrame("Frame", nil, f)
	d:SetSize(DIAL, DIAL)
	d:SetPoint("TOPLEFT", 0, -1)
	d.face = d:CreateTexture(nil, "ARTWORK", nil, -1)
	d.face:SetTexture(MEDIA .. "Dial")
	d.face:SetSize(DIAL_ART, DIAL_ART)
	d.face:SetPoint("CENTER")
	UI.Tint(d.face, Theme.skin.metal)
	d.weave = Shy.Skin.Weave(d, FACE_INNER, "ARTWORK", 0)
	Shy.Skin.WeaveTint(d.weave, Theme.skin.metal)
	-- The light the hand throws on the ring and the face, and the hand in its dark rim: both turn.
	d.beam = d:CreateTexture(nil, "ARTWORK", nil, 1)
	d.beam:SetTexture(ns.MEDIA .. "ArrowBeam")
	d.beam:SetSize(DIAL_ART, DIAL_ART)
	d.beam:SetPoint("CENTER")
	UI.Tint(d.beam, C.hot)
	-- Where the place itself lies, while the way bends off it: under the hand, should the two meet.
	d.heading = d:CreateTexture(nil, "OVERLAY", nil, -1)
	d.heading:SetTexture(ns.MEDIA .. "ArrowGoal")
	d.heading:SetSize(HAND_ART, HAND_ART)
	d.heading:SetPoint("CENTER")
	UI.Tint(d.heading, Theme.Accent, HEADING_ALPHA)
	d.heading:SetAlpha(0)
	d.heading:Hide()
	d.keep = {}
	d.hand = d:CreateTexture(nil, "OVERLAY")
	d.hand:SetTexture(ns.MEDIA .. "ArrowHand")
	d.hand:SetSize(HAND_ART, HAND_ART)
	d.hand:SetPoint("CENTER")
	UI.Tint(d.hand, C.hot)
	d.yards = Words(d, 12, C.head, true)
	d.yards:SetJustifyH("CENTER")
	d.yards:SetPoint("CENTER", 0, 3)
	d.unit = Words(d, 8, C.dim)
	d.unit:SetText("YARDS")
	d.unit:SetPoint("TOP", d.yards, "BOTTOM", 0, 0)
	-- What is found here, while the player stands on its ground (Found): its emblem, from the marks' sheet.
	d.mark = d:CreateTexture(nil, "OVERLAY")
	d.mark:SetTexture(ns.MEDIA .. "MarksLarge")
	d.mark:SetSize(MARK, MARK)
	d.mark:SetPoint("CENTER")
	d.mark:Hide()
	UI.Concentric(d.face, d.weave, d.beam, d.heading, d.hand, d.mark)
	Portrait(d, d)

	-- The name starts clear of the hand when it points along the plaque.
	local name = Words(f, 13, C.text, true)
	name:SetPoint("LEFT", plaque.strip, "LEFT", DIAL / 2 + 10, 0)
	name:SetPoint("RIGHT", plaque.point, "LEFT", -2, 0)
	local under = Words(f, 10, C.dim)
	under:SetPoint("TOPLEFT", f, "TOPLEFT", DIAL + 6, -(PLAQUE + 5))
	under:SetPoint("RIGHT", f, "RIGHT", 0, 0)
	return d, name, under, plaque
end

-- In the head
-- Where ShyCore has the column's head (Shy.Notices.Voice), the arrow is its voice while there is somewhere
-- to point, and the circle is the card's lead (Card.lua) in the head's make: the same arrowhead turns in
-- place in its middle over the bars' weave; on the way the ring, the weave and the arrow are in the accent's
-- light, as the card's are while the arrow is up, and the stop's mark stands over the circle's lower right
-- (the card's tag: a vendor's coin, crossed blades, a pouch); once there what is found where you stand or
-- what the stop is for fills the circle in its color. The head's plate says where to
-- (the name, then the yards and the map's numbers). The arrow's own box stays out of sight meanwhile.
local POINT_ART = 26                 -- ArrowPoint (the card's arrowhead, drawn for it: 52 texels) in the circle
local TAG, TAG_AT = 18, 16           -- the stop's mark over the circle's lower right: its size, and how far right and
                                     -- down of the middle (the card's 13 at its ring of 36, at the head's 46)
local MARK_IN = MARK                 -- what is found, in the circle: its cell's own size, as on the dial

local function Headed()
	return Shy.Notices ~= nil and Shy.Notices.Voice ~= nil
end

local seat                           -- the arrow's pieces in the head's circle
local saying = ""                    -- the plate's line under the name
local voice

-- The arrow's pieces in the head's circle (SeatIn), once it has spoken there: hand, beam, heading, face,
-- weave, mark, tag. For tests and drawings.
function A.Seat()
	return seat
end

-- A to Z only, between escapes: a picture's path and its closing |t, a color's |c and |r stay as they are
-- (upper-cased, they no longer close and the line breaks).
local ESCAPES = { "|T.-|t", "|A.-|a", "|c%x%x%x%x%x%x%x%x", "|r", "|n", "||" }
local Upper
function Upper(text)
	if issecretvalue(text) then return text end
	local out, at = {}, 1
	while true do
		local from, to
		for _, pattern in ipairs(ESCAPES) do
			local s, e = text:find(pattern, at)
			if s and (not from or s < from) then from, to = s, e end
		end
		if not from then break end
		out[#out + 1] = text:sub(at, from - 1):gsub("[a-z]+", string.upper)
		out[#out + 1] = text:sub(from, to)
		at = to + 1
	end
	out[#out + 1] = text:sub(at):gsub("[a-z]+", string.upper)
	return table.concat(out)
end
ns.Upper = Upper      -- (Route.lua fits the line under the name to the plate as the head says it)

-- The plate's line under the name, and what fills the circle while it is found here or carried.
local function HeadWrite()
	local d = seat
	if not (d and target) then return end
	voice.underColor = nil
	local sign, color, label, said = Aboard()
	local yards = Yards()
	if not sign then sign, color = Here(yards) end
	-- There (or carried): the emblem over a face of its color, the ring in that color too. On the way the
	-- circle is the card's lead as it stands while the arrow is up: the ring and the weave in the accent's
	-- light, the arrow in it, and the stop's mark over the circle's lower right.
	local there = sign ~= nil
	-- On its ground, the creature it is got from stands in the circle in place of the emblem, once the game
	-- has it: the ring in the objective's color is its one bezel, the weave behind it quiet steel.
	local faced = Face(d, not label and target.among and target.leading and target.leading.creature or nil)
	d.mark:SetShown(there and not faced)
	if there then
		d.mark:SetTexCoord(unpack(ns.MarkPicture(sign)))
		UI.Tint(d.mark, color)
		UI.Tint(d.face, color)
		Shy.Skin.WeaveTint(d.weave, faced and Theme.skin.metal or color)
	else
		UI.Tint(d.face, C.hot)
		Shy.Skin.WeaveTint(d.weave, C.hot)
	end
	if target.mark and not label then d.tag:Set(target.mark, false, nil, target.tone) end
	d.tag:SetShown(not there and target.mark ~= nil)
	if label then
		saying = Upper(Landing(said))
		return
	end
	if target.among then
		-- (In a quest of several: what the objective at hand is got from, in its color.)
		local _, _, words, ink = Here(yards)
		saying = Upper(words or target.found or "Found around here")
		voice.underColor = ink or C.good
		return
	end
	local offText, offColor = JustOff()
	if offText then
		saying = Upper(offText)
		voice.underColor = offColor
		return
	end
	local where = Where(target)
	if yards then
		saying = Upper(Far(yards) .. " yd  ·  " .. where)
	else
		saying = Upper(where .. (W.Known() and "  (another continent)" or ""))
	end
	-- Close to a cliff the way goes down or water it walks over: the spell to cast, in its picture.
	local cue = yards and ns.Glide and ns.Glide.Cue(target.continent, target.north, target.west, target.floor, target.up)
	if cue then
		saying = ns.Glide.IconText(cue.icon, 11) .. " " .. cue.text
		voice.underColor = cue.on and C.good or C.alert
	end
end

-- The arrow's pieces in the head's circle: the ring and the weave on the face (the accent's light on the
-- way), the arrowhead and the light it throws (turned as the hand is), where the place itself lies on the
-- ring, the stop's mark at the lower right, and what is found here or what the stop is for over a face of
-- its color once there. over: the head's layer above its ring and the level's arc, where the mark stands.
local function Seated(frame, over)
	local d = { keep = {} }
	d.face = frame:CreateTexture(nil, "ARTWORK", nil, -1)
	d.face:SetTexture(MEDIA .. "Dial")
	d.face:SetSize(DIAL_ART, DIAL_ART)
	d.face:SetPoint("CENTER")
	UI.Tint(d.face, C.hot)
	d.weave = Shy.Skin.Weave(frame, FACE_INNER, "ARTWORK", 0)
	Shy.Skin.WeaveTint(d.weave, C.hot)
	-- What the stop is for, over the circle's lower right while the way is pointed: the card's tag, over the
	-- ring and the level's arc.
	d.tag = ns.CreateMark(over, TAG)
	d.tag:SetPoint("CENTER", frame, "CENTER", TAG_AT, -TAG_AT)
	d.tag:Hide()
	d.beam = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	d.beam:SetTexture(Shy.Brand.GLOW)
	d.beam:SetSize(DIAL * 0.8, DIAL * 0.8)
	d.beam:SetPoint("CENTER")
	UI.Tint(d.beam, C.hot, 0.35)
	-- Where the place itself lies: the arrow's own make, small, riding just outside the ring.
	d.heading = frame:CreateTexture(nil, "OVERLAY", nil, -1)
	d.heading:SetTexture(ns.MEDIA .. "ArrowBearing")
	d.heading:SetSize(HAND_ART, HAND_ART)
	d.heading:SetPoint("CENTER")
	UI.Tint(d.heading, Theme.Accent)
	d.heading:SetAlpha(0)
	d.heading:Hide()
	-- Which way to go now: the card's arrowhead in the middle, turning in place, in the accent's light.
	d.hand = frame:CreateTexture(nil, "OVERLAY")
	d.hand:SetTexture(ns.MEDIA .. "ArrowPoint")
	d.hand:SetSize(POINT_ART, POINT_ART)
	d.hand:SetPoint("CENTER")
	UI.Tint(d.hand, C.hot)
	d.mark = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	d.mark:SetTexture(ns.MEDIA .. "MarksLarge")
	d.mark:SetSize(MARK_IN, MARK_IN)
	d.mark:SetPoint("CENTER")
	d.mark:Hide()
	UI.Concentric(d.face, d.weave, d.beam, d.heading, d.hand, d.mark)
	Portrait(frame, d)
	return d
end

local function SeatIn(frame, over)
	local d = Seated(frame, over)
	seat = d
	since = EVERY
	frame:SetScript("OnUpdate", Shy.Clocked("frame: arrow head", function(_, elapsed) Step(d, elapsed, HeadWrite) end))
end

voice = {
	priority = 10, arc = true,
	seat = SeatIn,
	title = function() return target and (lead or target.title) or "" end,
	under = function() return saying end,
	menu = Menu,
	hover = function(owner)
		if not target then return end
		-- A route stop's card under the arrow, as a pin's: its stage turning at once with what the objective
		-- is got from. A typed waypoint has nothing to say of itself.
		local H = ns.CardHover
		if H and target.key then
			for _, stop in ipairs(R.stops) do
				if H.Key(stop) == target.key then
					if H.Beside(owner, stop, { { "right", "Hide, or stop following" } }, "BOTTOM") then return end
					break
				end
			end
		end
		UI.Tip(owner, "Waypoint", "To " .. target.title .. ". Right-click to hide.", { side = "BOTTOM" })
	end,
}

-- A ride beginning or ending (Shy.Way.Riding), a flight taking off or landing: written at once; off a ride
-- or landed, the line says so for a moment.
Shy:On("SHY_RIDE", function(ride)
	if ride then
		riding = ride
	elseif riding then
		local look = Shy.Way.RIDES[riding.by]
		off = { text = "Off the " .. (look and look.word or "ride"):lower(), color = ns.SignColor(look and look.sign or "flight"),
			till = GetTime() + OFF_SAID }
		riding = nil
	end
	since = EVERY
end)
local flying                         -- whether a flight was up, as last told (SHY_FLIGHT)
Shy:On("SHY_FLIGHT", function(flight)
	if flight then
		flying = true
	elseif flying then
		off = { text = "Landed", color = ns.SignColor("flight"), till = GetTime() + OFF_SAID }
		flying = nil
	end
	since = EVERY
end)

-- The head speaks with the arrow while it points somewhere, and stops when it doesn't.
local function Voice()
	if not Headed() then return end
	if target then
		since = EVERY
		HeadWrite()
		Shy.Notices.Voice("guide", voice)
	else
		Shy.Notices.Voice("guide", nil)
	end
end
A.Voice = Voice

local function Build()
	box = Shy.HUD.Create({
		id = "shyquest-arrow",
		title = "ShyQuest: arrow",
		width = WIDTH,
		height = DIAL + 2,
		point = { "TOP", "TOP", 0, -190 },
		-- (In the head's circle where there is one: then this box is out of sight and out of the column.)
		shown = function() return target ~= nil and not Headed() end,
		away = Headed,
		-- In the column down from the top's middle: under the death recap and the way back to the graveyard,
		-- over the zone's name.
		top = { order = 30, sample = A.Sample },
	})
	Shy.HUD.Manage(box, box, Menu)
	dial, title, sub = Draw(box)

	box:SetScript("OnUpdate", Shy.Clocked("frame: arrow box", Tick))
	UI.Help(box, "Waypoint", function()
		return target and ("To " .. target.title .. ". Drag to move, right-click to hide.") or nil
	end)
end

local function Show()
	if not box then Build() end
	since = EVERY
	Write()
	Shy.HUD.Update(box)
	Voice()
end

-- The arrow as a picture for a picker, pointing at the step the route leads with as the arrow would, or
-- saying what it shows while there is none. Set(on): lit while the arrow is wanted, quiet while it is
-- not. Where the head has the arrow (Headed), the picture is the head speaking it, as the screen shows
-- it: the circle with the arrowhead and the stop's mark, the plate with the name and the yards; else the
-- box's own pieces on a plain frame. widest: the most room the head's plate gives the words.

-- The place the route leads with, as the arrow would point at it, or nil.
local function Lead()
	local stop = R.stops[1]
	if not (stop and stop.map and stop.x) then return stop, nil end
	local continent, north, west = W.ToWorld(stop.map, stop.x, stop.y)
	if stop.north then continent, north, west = stop.continent, stop.north, stop.west end
	return stop, { map = stop.map, x = stop.x, y = stop.y, continent = continent, north = north, west = west, among = stop.among }
end

-- The hand turned toward `place` from where the player stands (nowhere to point on its ground or once
-- there), or the picture's own turn while that can't be measured. Returns the yards.
local function AimAt(d, place, elapsed)
	local yards = place and Yards(place)
	if yards then
		local turn, heading
		if not place.among and yards > ARRIVED then
			turn, heading = W.Heading(place.continent, place.north, place.west, d.keep, elapsed)
		end
		Aim(d, turn, heading, elapsed)
	else
		Aim(d, SAMPLE.turn, SAMPLE.heading)
	end
	return yards
end

local function BoxSample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(WIDTH, DIAL + 2)
	local d, name, under = Draw(f)
	local stop, place, clock, built = nil, nil, EVERY, nil

	-- (Read again for every route built: a stop kept from one to the next is the same table.)
	local function Read()
		stop, place, built = Lead()
		built = R.built
		if place then
			name:SetText((R.Describe(stop)))
			local among = place.among
			if not Found(d, under, among and ns.ToneSign(among), among and ns.ToneColor(among), R.Found(stop) or "Found around here", C.good) then
				under:SetText(Where(place))
			end
		else
			Found(d, under, nil)
			name:SetText(SAMPLE.title)
			under:SetText(SAMPLE.sub)
			d.yards:SetText(SAMPLE.yards)
			Aim(d, SAMPLE.turn, SAMPLE.heading)
		end
		clock = EVERY
	end

	f:SetScript("OnUpdate", Shy.Clocked("frame: arrow", function(_, elapsed)
		if R.stops[1] ~= stop or R.built ~= built then Read() end
		if not place then return end
		local yards = AimAt(d, place, elapsed)
		clock = clock + elapsed
		if clock < EVERY then return end
		clock = 0
		d.yards:SetText(yards and Far(yards) or "?")
	end))

	function f:Set(on)
		self:SetAlpha(on and 1 or OFF)
	end
	f.dial, f.title, f.sub = d, name, under
	Read()
	return f
end

-- The head speaking the arrow: HeadWrite's own lines for the route's lead, the stop's mark over the
-- circle on the way, what is found filling it on its ground.
local function HeadSample(parent, widest)
	local d
	local f = Shy.Notices.Picture(parent, { seat = function(frame, over) d = Seated(frame, over) end, widest = widest })
	local stop, place, clock, built = nil, nil, EVERY, nil

	local function Write(yards)
		if not place then
			d.mark:Hide()
			d.tag:Hide()
			UI.Tint(d.face, C.hot)
			Shy.Skin.WeaveTint(d.weave, C.hot)
			f:Say(SAMPLE.title, Upper(SAMPLE.yards .. " yd  ·  " .. SAMPLE.sub))
			return
		end
		local sign, color, mark, tone = Emblem(stop)
		local among = place.among
		local there = among ~= nil or (yards ~= nil and yards <= ARRIVED)
		if among then sign, color = ns.ToneSign(among), ns.ToneColor(among) end
		there = there and sign ~= nil
		d.mark:SetShown(there)
		if there then
			d.mark:SetTexCoord(unpack(ns.MarkPicture(sign)))
			UI.Tint(d.mark, color)
			UI.Tint(d.face, color)
			Shy.Skin.WeaveTint(d.weave, color)
		else
			UI.Tint(d.face, C.hot)
			Shy.Skin.WeaveTint(d.weave, C.hot)
		end
		if mark then d.tag:Set(mark, false, nil, tone) end
		d.tag:SetShown(not there and mark ~= nil)
		local title = (R.Describe(stop))
		if among then
			f:Say(title, Upper(R.Found(stop) or "Found around here"), C.good)
		elseif yards then
			f:Say(title, Upper(Far(yards) .. " yd  ·  " .. Where(place)))
		else
			f:Say(title, Upper(Where(place)))
		end
	end

	f:SetScript("OnUpdate", Shy.Clocked("frame: arrow", function(_, elapsed)
		if R.stops[1] ~= stop or R.built ~= built then
			stop, place = Lead()
			clock, built = EVERY, R.built
		end
		local yards = AimAt(d, place, elapsed)
		clock = clock + elapsed
		if clock < EVERY then return end
		clock = 0
		Write(yards)
	end))

	function f:Set(on)
		self:SetAlpha(on and 1 or OFF)
	end
	f.dial, f.sub = d, f.under
	stop, place = Lead()
	Write(AimAt(d, place))
	return f
end

function A.Sample(parent, widest)
	if Headed() then return HeadSample(parent, widest) end
	return BoxSample(parent)
end

-- place = { map, x, y (0-9999), title, key, following, typed, among, sign, hue, mark, tone (Emblem: what
--   fills the dial once there and its color, and what the tag over the head's circle is set with), floor, up
--   (a stop's W.Prefer: the trail the maps draw to it, so the arrow's cue reads the same one) }
--   holding: it takes the arrow for a while only, so a /way's saved target and its pin on the map stay.
function A.Point(place)
	if not (place and place.map and place.x and place.y) then return false end
	if OurPin() and not place.holding then Shy.Waypoint.Clear() end
	-- (A stop's own world position, where it has one: the way the maps keep to it goes by that.)
	local continent, north, west = place.continent, place.north, place.west
	if not north then continent, north, west = W.ToWorld(place.map, place.x, place.y) end
	-- (A typed waypoint is a place to go to: the banner, as a stop with nothing to say of itself.)
	local sign, hue, mark = place.sign, place.hue, place.mark
	if place.typed and not sign then sign, hue, mark = "go", ns.ToneColor("go"), "guide" end
	target = {
		map = place.map, x = place.x, y = place.y, title = place.title or "Waypoint",
		key = place.key, about = place.about, following = place.following, typed = place.typed, lead = place.lead, among = place.among, found = place.found,
		sign = sign, hue = hue, mark = mark, tone = place.tone, leading = place.leading,
		continent = continent, north = north, west = west, floor = place.floor, up = place.up,
	}
	-- A typed target is saved and set as the map's user waypoint.
	if not place.holding then
		ns.char.way = place.typed and { map = place.map, x = place.x, y = place.y, title = target.title } or nil
	end
	if place.typed and Shy.Waypoint.Set(place.map, place.x / UNITS, place.y / UNITS) then
		target.pin = true
	end
	Show()
	return true
end

local function Key(stop)
	return ns.CardHover and ns.CardHover.Key(stop) or nil
end

-- The route stop with the same key, if any. With `about` (the stop followed until now), as a kept hover
-- follows its stop (CardHover.Follow): a quest's stop whose spot moved is still that quest's stop.
local function InRoute(key, about)
	if not (key and ns.CardHover) then return nil end
	return ns.CardHover.Follow(about, key)
end

-- Where a stop is on a map: its own place, or, for one the data puts on no map (a dock on a world with no
-- zone map of its own), where it falls on the map the player is on, while they are on its world.
local function Placed(stop)
	if not stop then return nil end
	if stop.map and stop.x then return stop.map, stop.x, stop.y end
	if not (stop.north and stop.continent and W.Known() and stop.continent == W.continent) then return nil end
	local map = C_Map.GetBestMapForUnit("player")
	if not map then return nil end
	local x, y = Shy.Maps.ToMap(map, stop.continent, stop.north, stop.west)
	if not x or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
	return map, math.floor(x * UNITS + 0.5), math.floor(y * UNITS + 0.5)
end

-- A route stop is followed; any other stop (a later guide step, a map pin) is pointed at where it is now.
function A.ToStop(stop)
	local map, x, y = Placed(stop)
	if not map then return false end
	local key = Key(stop)
	local following = InRoute(key) ~= nil
	local floor, up = W.Prefer(stop)
	local sign, hue, mark, tone = Emblem(stop)
	local leading = Leading(stop)
	return A.Point({ map = map, x = x, y = y, title = Named(stop, leading), key = key, about = following and stop or nil, following = following, leading = leading,
		among = following and stop.among or nil, found = R.Found(stop), sign = sign, hue = hue, mark = mark, tone = tone,
		continent = stop.continent, north = stop.north, west = stop.west, floor = floor, up = up })
end

-- Points at the stop the quest window is heading for. With nothing there to point at, the arrow
-- waits out of sight.
function ToLead()
	local stop = R.stops[1]
	local map, x, y = Placed(stop)
	if map then
		local sign, hue, mark, tone = Emblem(stop)
		local leading = Leading(stop)
		-- (The level and height the maps lead to: the arrow reads the trail they draw, and asks for no other.)
		local floor, up = W.Prefer(stop)
		A.Point({ map = map, x = x, y = y, title = Named(stop, leading), key = Key(stop), about = stop, following = true, lead = true, leading = leading,
			among = stop.among, found = R.Found(stop), sign = sign, hue = hue, mark = mark, tone = tone,
			holding = held ~= nil,
			continent = stop.continent, north = stop.north, west = stop.west, floor = floor, up = up })
	elseif target and target.lead then
		target = nil
		if box then Shy.HUD.Update(box) end
		Voice()
	end
end

-- on: keep the arrow on screen, following the steps. Off puts it away unless it points elsewhere.
function A.Follow(on)
	ns.char.arrow = on and true or nil
	if on then
		if not (target and target.typed) then ToLead() end
	elseif target and target.lead then
		A.Clear()
	end
	if ns.ApplyCard then ns.ApplyCard() end
end

function A.Toggle()
	A.Follow(not A.Following())
end

-- For the key binding (Bindings.xml).
function ShyQuestToggleArrow()
	A.Toggle()
end
BINDING_NAME_SHYQUEST_ARROW = "Show or hide the waypoint arrow"

-- After a route rebuild a followed stop may have moved or gone.
ns.OnRoute(function(rebuilt, measured)
	if not rebuilt then
		-- (Measured again: the level a stop is on can say more once it is near. The arrow keeps the one the
		-- maps lead to, so the trail it reads is theirs.)
		local stop = measured and target and target.following and InRoute(target.key, target.about)
		if stop then target.floor, target.up = W.Prefer(stop) end
		return
	end
	-- While a stop that can't wait leads (a ghost's way back to its body) the arrow is its, whatever it
	-- pointed at: a /way or a stop pointed at by hand is kept, and has the arrow back afterwards.
	local lead = R.stops[1]
	local urgent = lead ~= nil and lead.urgent and lead.map ~= nil and lead.x ~= nil
	if urgent and (target or A.Following()) then
		if target and not target.lead then
			held = { map = target.map, x = target.x, y = target.y, title = target.title, typed = target.typed, key = target.key,
				about = target.about, following = target.following }
		end
		ToLead()
		return
	end
	if held then
		local back = held
		held = nil
		A.Point(back)
	end
	if A.Following() and (not target or target.lead) then
		ToLead()
		return
	end
	if not (target and target.following) then return end
	local stop = InRoute(target.key, target.about)
	if not (stop and stop.map and stop.x) then
		A.Clear()
		return
	end
	-- (Known by its key from here on, as it now is: a quest's stop moved to another spot has another.)
	target.key, target.about = Key(stop), stop
	if stop.map ~= target.map or stop.x ~= target.x or stop.y ~= target.y then
		target.map, target.x, target.y = stop.map, stop.x, stop.y
		target.continent, target.north, target.west = W.ToWorld(stop.map, stop.x, stop.y)
	end
	if stop.north then target.continent, target.north, target.west = stop.continent, stop.north, stop.west end
	target.floor, target.up = W.Prefer(stop)
	target.leading = Leading(stop)
	target.title, target.among, target.found = Named(stop, target.leading), stop.among, R.Found(stop)
	target.sign, target.hue, target.mark, target.tone = Emblem(stop)
	Write()
end)

-- /way

local function Number(text)
	return tonumber((text:gsub(",", "."):gsub("%.$", "")))
end

-- "45.2 33.1 The cave", "45,2 33,1", "45.2, 33.1": text before the two numbers (0 to 100) is the map name,
-- text after them the waypoint's name. nil without two numbers.
function A.Parse(text)
	text = strtrim(text or "")
	local id, rest = text:match("^#(%d+)%s+(.+)$")
	if id then text = rest end
	local from, to, a, b = text:find("(%d+[%.,]?%d*)[,%s]+(%d+[%.,]?%d*)")
	if not from then return nil end
	local x, y = Number(a), Number(b)
	if not (x and y) or x > 100 or y > 100 then return nil end
	local zone = strtrim(text:sub(1, from - 1))
	local name = strtrim(text:sub(to + 1))
	return { id = id and tonumber(id) or nil, zone = zone ~= "" and zone or nil, x = x, y = y, name = name ~= "" and name or nil }
end

-- Every map under the player's top-level map, by lower-case name. Built once a map is known.
local named

local function Maps()
	if named then return named end
	local top = W.map or C_Map.GetBestMapForUnit("player")
	local info = top and C_Map.GetMapInfo(top)
	while info and info.parentMapID and info.parentMapID > 0 do
		top = info.parentMapID
		info = C_Map.GetMapInfo(top)
	end
	local list = {}
	for _, child in ipairs(top and C_Map.GetMapChildrenInfo(top, nil, true) or {}) do
		if child.name and child.name ~= "" then list[#list + 1] = { name = child.name:lower(), map = child.mapID } end
	end
	if #list > 0 then named = list end
	return list
end

-- Exact name first, then a prefix, then a substring.
function A.MapNamed(text)
	text = text:lower()
	local starts, holds
	for _, entry in ipairs(Maps()) do
		if entry.name == text then return entry.map end
		if not starts and entry.name:sub(1, #text) == text then starts = entry.map end
		if not holds and entry.name:find(text, 1, true) then holds = entry.map end
	end
	return starts or holds
end

local function Usage()
	T:Print("waypoint arrow:")
	print("  /way 45.2 33.1 [name]  - waypoint on the current map")
	print("  /way Darnassus 45.2 33.1 [name]  - in another zone (#1457 for a map ID)")
	print("  /way follow  - keep the arrow up, pointing at your current step")
	print("  /way clear  - hide the arrow")
end

function A.Command(text)
	text = strtrim(text or "")
	local word = text:lower()
	if word == "clear" or word == "reset" or word == "off" or word == "stop" then
		if target or A.Following() then
			PutAway()
			T:Print("arrow hidden.")
		else
			T:Print("no waypoint set.")
		end
		return
	end
	if word == "follow" then
		A.Toggle()
		T:Print(A.Following() and "the arrow follows your steps now. Drag it to move it." or "the arrow no longer follows your steps.")
		return
	end
	local way = A.Parse(text)
	if not way then
		Usage()
		return
	end
	local map = way.id
	if not map and way.zone then
		map = A.MapNamed(way.zone)
		if not map then
			T:Print(("no map named |cffffffff%s|r. Use the name on the world map, or leave it out for the current map."):format(way.zone))
			return
		end
	end
	map = map or W.map or C_Map.GetBestMapForUnit("player")
	if not map or not C_Map.GetMapInfo(map) then
		T:Print("no map for this area. Put the zone name before the coordinates.")
		return
	end
	local x, y = math.floor(way.x * 100 + 0.5), math.floor(way.y * 100 + 0.5)
	A.Point({ map = map, x = x, y = y, title = way.name or ("%s %.1f, %.1f"):format(W.MapName(map) or "Map", way.x, way.y), typed = true })
	local yards = Yards()
	T:Print(("arrow set to |cffffffff%s|r%s. Drag to move, |cff888888/way clear|r to hide."):format(
		target.title, yards and (", " .. W.Yards(yards) .. " from here") or ""))
end

SLASH_SHYWAY1 = "/way"
SlashCmdList.SHYWAY = A.Command

-- Layout mode shows the box with nowhere to point too: it stands there as its picture does, so there is
-- something to place.
Shy:On("SHY_HUD_LAYOUT", function(on)
	if not (on and box) or target then return end
	Found(dial, sub, nil)
	title:SetText(SAMPLE.title)
	sub:SetText(SAMPLE.sub)
	dial.yards:SetText(SAMPLE.yards)
	Aim(dial, SAMPLE.turn, SAMPLE.heading)
end)

-- Built at login so layout mode can place the box before first use; a saved /way target is restored.
Shy:On("SHY_LOGIN", function()
	if not box then Build() end
	local way = ns.char and ns.char.way
	if type(way) == "table" and way.map and way.x and way.y then
		A.Point({ map = way.map, x = way.x, y = way.y, title = way.title, typed = true })
	elseif A.Following() then
		ToLead()
	end
end)
