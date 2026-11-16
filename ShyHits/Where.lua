-- Where lanes are anchored: beside or above a nameplate, and in a HUD box beside the player.
-- With ShyPlates, lanes anchor to its housing frame and take its extents from
-- Shy.addons.Plates:Room, so they hold at any plate scale; other nameplates get numbers above.

local ADDON, ns = ...
local T, Stage = ns.T, ns.Stage
local UI, HUD = Shy.UI, Shy.HUD

local W = {}
ns.Where = W

local GAP = 4        -- between the plate's outermost piece and a number beside it
local FOOT = -1      -- y from the housing's bottom that centers a number on the health bar
local OVER = 3       -- between the plate's topmost piece and a number above it
local HEAL_X = 46    -- above a plate, heals start this far right of center
local BARE = 1       -- assumed top extent of a nameplate ShyPlates doesn't draw
local FELL = 1.2     -- seconds after a plate's last blow, or its going, that a gain is taken to come of it

-- The box beside the player: size, lane inset from each side and from the bottom, default position.
-- What you gain stands `over` the box's top, in its middle.
local YOU = { width = 300, height = 44, inward = 64, foot = 8, over = 22, point = { "CENTER", "CENTER", 0, -24 } }
W.YOU = YOU

local byPlate = {}   -- nameplate -> its lanes
-- A friend with no nameplate to write by is written on their unit frame: over its top, in the middle.
local FRAME = { over = 2 }
local onFrame = {}   -- a unit frame's button -> its lanes
local buttons        -- unit -> its frame's button, asked of ShyFrames once
-- Numbers on unit frames stand over them.
local above = CreateFrame("Frame", nil, UIParent)
above:SetAllPoints()
above:SetFrameStrata("MEDIUM")
local you, box

function W.Pair()
	return { hurt = Stage.Lane("deal"), heal = Stage.Lane("heal") }
end

-- Sets a pair's lanes around `frame`: `full` (bar plate, not name-only) and how far its
-- pieces extend left, right and above. Crits always land above the center.
function W.Around(pair, frame, full, left, right, top)
	pair.crit = pair.crit or Stage.Lane("deal")
	pair.gain = pair.gain or Stage.Lane("gain")
	local hurt, heal, crit, gain = pair.hurt, pair.heal, pair.crit, pair.gain
	hurt.to, heal.to, crit.to, gain.to = frame, frame, frame, frame
	-- What comes of killing it rises from over its middle, over where a crit lands, so the blow that killed
	-- never stands on it.
	gain.rel, gain.x, gain.y, gain.justify, gain.fan = "TOP", 0, top + OVER + Stage.Landing(T.db.size), "CENTER", 1
	if full and T.db.place == "beside" then
		hurt.rel, hurt.x, hurt.y, hurt.justify, hurt.fan = "BOTTOMLEFT", -(left + GAP), FOOT, "RIGHT", -1
		heal.rel, heal.x, heal.y, heal.justify, heal.fan = "BOTTOMRIGHT", right + GAP, FOOT, "LEFT", 1
	else
		hurt.rel, hurt.x, hurt.y, hurt.justify, hurt.fan = "TOP", 0, top + OVER, "CENTER", 0
		heal.rel, heal.x, heal.y, heal.justify, heal.fan = "TOP", HEAL_X, top + OVER, "LEFT", 1
	end
	crit.rel, crit.x, crit.y, crit.justify = "TOP", 0, top + OVER, "CENTER"
end

-- A nameplate's lanes, re-placed on every call because the plate's extents change.
function W.Plate(nameplate)
	local pair = byPlate[nameplate]
	if not pair then
		pair = W.Pair()
		byPlate[nameplate] = pair
	end
	local plates = Shy.addons.Plates
	local root, full, left, right, top, half, lift, tall
	if plates and plates.Room then root, full, left, right, top, half, lift, tall = plates:Room(nameplate) end
	if root then
		W.Around(pair, root, full, left, right, top)
		pair.half, pair.lift, pair.tall = half, lift, tall
	else
		W.Around(pair, nameplate, false, 0, 0, BARE)
		pair.half = nil
	end
	return pair
end

-- A lane's anchor re-expressed from the nameplate's bottom: Stage.Detach's fallback.
local function FromFoot(pair, lane, nameplate)
	if not pair.half or lane.to == nameplate then return nil end
	local x, y = lane.x, lane.y + pair.lift
	if lane.rel == "BOTTOMLEFT" then
		x = x - pair.half
	elseif lane.rel == "BOTTOMRIGHT" then
		x = x + pair.half
	else
		y = y + pair.tall
	end
	return nameplate, "BOTTOM", x, y
end

-- Whether the unit a nameplate carries has died; the game may keep that back, and then it is taken not to have.
local function Died(nameplate, unit)
	if not unit then
		if nameplate:IsForbidden() then return false end
		unit = nameplate.unitToken   -- set by Blizzard's nameplate code
	end
	if type(unit) ~= "string" or issecretvalue(unit) then return false end
	local dead = UnitIsDead(unit)
	if issecretvalue(dead) then return false end
	return dead == true
end

-- A nameplate is losing its unit (`unit`, where the caller knows it): its numbers carry on, and the blow
-- that killed it is marked.
function W.LetGo(nameplate, unit)
	local pair = byPlate[nameplate]
	if not pair then return end
	byPlate[nameplate] = nil
	if pair.at and GetTime() - pair.at <= FELL then pair.at, W.recent = GetTime(), pair end
	if Died(nameplate, unit) then W.Slain(pair) end
	Stage.Detach(pair.hurt, FromFoot(pair, pair.hurt, nameplate))
	Stage.Detach(pair.heal, FromFoot(pair, pair.heal, nameplate))
	Stage.Detach(pair.crit, FromFoot(pair, pair.crit, nameplate))
	Stage.Detach(pair.gain, FromFoot(pair, pair.gain, nameplate))
end

-- A blow has just landed on the unit of these lanes: what is gained a moment after comes of it.
function W.Hit(pair)
	pair.at, W.recent = GetTime(), pair
end

-- The unit of these lanes has died (it is seen to have, or experience has come of it): its last blow is
-- struck as the one that killed, once.
function W.Slain(pair)
	if pair.slain then return end
	pair.slain = true
	Stage.Final(pair.hurt, pair.crit)
end

-- Where a gain is written: over the unit it has just come of (`ofKill`: it is a kind that comes of a
-- kill), else by your character. Returns the lane, and the unit's lanes in the first case.
function W.Gain(ofKill)
	local pair = W.recent
	if ofKill and pair and ns.Feed.Drawing() and GetTime() - pair.at <= FELL then return pair.gain, pair end
	return W.You().gain
end

-- The lanes on a unit's frame (your party's, your target's), or nil where it has none in sight.
function W.Frame(unit)
	local frames = Shy.addons.Frames
	if not (frames and frames.EachFrame) then return nil end
	if not buttons then
		buttons = {}
		frames:EachFrame(function(_, kind, of, button)
			if kind == "party" or kind == "target" then buttons[of] = button end
		end)
	end
	local button = buttons[unit]
	if not button or not button:IsVisible() then return nil end
	local pair = onFrame[button]
	if not pair then
		pair = W.Pair()
		local heal = pair.heal
		heal.to, heal.rel, heal.x, heal.y, heal.justify, heal.parent = button, "TOP", 0, FRAME.over, "CENTER", above
		onFrame[button] = pair
	end
	return pair
end

function W.LetGoAll()
	for nameplate in pairs(byPlate) do W.LetGo(nameplate) end
end
local function Gone(nameplate, unit) W.LetGo(nameplate, unit) end

function W.You()
	local scale = box:GetScale()
	you.hurt.scale, you.heal.scale, you.gain.scale = scale, scale, scale
	return you
end

-- Sample numbers the box shows in layout mode.
local samples = {}
local function Sample(lane, point, text, color)
	local fs = box:CreateFontString(nil, "OVERLAY")
	fs:SetPoint(point, box, lane.rel, lane.x, lane.y)
	fs.say, fs.color = text, color
	samples[#samples + 1] = fs
end

-- A sample another file adds (what you gain), once the box is made.
function W.Sample(lane, point, text, color)
	Sample(lane, point, text, color)
	W.PaintSamples()
end

local function PaintSamples()
	local size = math.max(6, math.floor(Stage.SIZE * T.db.size + 0.5))
	for _, fs in ipairs(samples) do
		Stage.Face(fs, size)
		fs:SetText(fs.say)
		UI.Ink(fs, fs.color)
	end
end

function W.Start()
	box = HUD.Create({
		id = "shyhits-you", title = "Hits on you",
		width = YOU.width, height = YOU.height, point = YOU.point,
		shown = function() return false end,   -- visible in layout mode only
		-- Its options' "On you" (and combat text with it, turned on).
		switch = {
			get = function() return T.db.on ~= false and T.db.you ~= false end,
			set = function(on)
				if on then T.db.on = true end
				T.db.you = on
				ns.Apply()
				if ns.RefreshOptions then ns.RefreshOptions() end
			end,
			hint = "The hits and heals you take, beside you",
		},
	})
	W.box = box
	you = W.Pair()
	you.hurt.tone = "hurt"
	you.hurt.to, you.hurt.rel, you.hurt.x, you.hurt.y, you.hurt.justify, you.hurt.fan = box, "BOTTOMLEFT", YOU.inward, YOU.foot, "RIGHT", -1
	you.heal.to, you.heal.rel, you.heal.x, you.heal.y, you.heal.justify, you.heal.fan = box, "BOTTOMRIGHT", -YOU.inward, YOU.foot, "LEFT", 1
	you.gain = Stage.Lane("gain")
	you.gain.to, you.gain.rel, you.gain.x, you.gain.y, you.gain.justify, you.gain.fan = box, "TOP", 0, YOU.over, "CENTER", 1
	W.PaintSamples = PaintSamples
	Sample(you.hurt, "BOTTOMRIGHT", "-45", UI.colors.bad)
	Sample(you.heal, "BOTTOMLEFT", "+312", UI.colors.good)
	PaintSamples()
	ns.OnApply(PaintSamples)
	Shy:On("SHY_FONT", PaintSamples)

	-- Fired by ShyPlates while its plate is still on the nameplate.
	Shy:On("SHY_NAMEPLATE_GONE", Gone)
	Shy:On("SHY_NAMEPLATES", W.LetGoAll)
end
