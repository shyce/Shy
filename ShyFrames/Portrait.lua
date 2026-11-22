-- The portrait: a picture at one end of a frame, in one of two styles (T.db.portrait.style):
--   ours      set into the frame: a square as tall as the bars' room, on the look's own well, with no border of its
--             own (the frame's housing is its border)
--   blizzard  like the game's: a circle as tall as the frame at its very end, in the family's dial (a dark face, a
--             steel ring), the look's own ring over it where the look has one (UI.LookRing). The ring is tinted
--             steel, your color or the unit's class (T.db.portrait.ring)
-- In either a picture is a class icon (the game's class picture, cropped as icons are), a 2D face (the game's own flat
-- portrait) or a 3D head. A model takes no mask, so a round 3D head is the same head drawn in strips, each clipped
-- by a frame of its own to a band of the circle no wider than the ring's outer edge allows (Strips): the strips meet
-- under the ring's inner line, and nothing of the head reaches past the ring. Where a head can't be drawn a player's
-- class picture stands in, anyone else's flat portrait.
-- Which frames take one, and at which end, is Layout.lua's (L.PORTRAITS, L.MIRRORED). Only our own regions move, so a
-- portrait comes and goes in a fight.

local ADDON, ns = ...
local T, L = ns.T, ns.Layout
local UI, Theme, Slot = Shy.UI, Shy.Theme, Shy.Slot

local P = {}
ns.Portrait = P

-- Frame levels over the host frame: the well or the dial's face, the head on it, the picture and the ring over the
-- head, crowd control's cover over them (its button a level up), all under the marks (6) and the words (7).
local LEVELS = { col = 2, head = 3, rim = 4, cover = 4, button = 5 }
local CROP = 0.08                                                -- the family's crop of an icon's picture
local CIRCLE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"   -- the game's round mask, and a round swipe
local SOLID = "Interface\\Buttons\\WHITE8X8"
local SHADE = { 0, 0, 0, 0.64 }                                  -- a cooldown's dark (the game's own)
local GLASS = { 0.16, 0.16, 0.19 }   -- the dial's ring under a look's own ring (two rings would show)
local COVER_FILTER = "HARMFUL|CROWD_CONTROL"
local FADE, TIME = 0.52, 0.36   -- the cover's foot shade and its time's text, as shares of its side
local CLEAR = 0.25              -- how far inside the ring's outer edge a strip of a round head stops (units)
-- A head's light: from the front and a little left and above, warm, the shadow side kept soft. Made when the first
-- head is.
local LIGHT = { point = { -1, 0.4, -0.35 }, ambient = { 0.7, 0.78, 0.78, 0.82 }, diffuse = { 0.8, 1, 0.96, 0.9 } }
local function Light()
	if not LIGHT.made then
		local a, d, p = LIGHT.ambient, LIGHT.diffuse, LIGHT.point
		LIGHT.made = { omnidirectional = false, point = CreateVector3D(p[1], p[2], p[3]),
			ambientIntensity = a[1], ambientColor = CreateColor(a[2], a[3], a[4]),
			diffuseIntensity = d[1], diffuseColor = CreateColor(d[2], d[3], d[4]) }
	end
	return LIGHT.made
end

-- "none", "class", "face" or "head" for a kind of frame.
function P.Mode(kind)
	local key = L.PORTRAITS[kind]
	local db = T.db.portrait
	return key and db and db[key] or "none"
end

-- Whether portraits are like the game's: round, in a ring.
function P.Ringed()
	local db = T.db.portrait
	return db ~= nil and db.style == "blizzard"
end

-- Whether a frame has a portrait, and what it takes from the bars (L.Bars): the width they give up, whether it
-- stands at the right end, how far the housing stands in from the frame's top and foot, and the radius of a ring the
-- bars start under.
function P.Room(plate)
	if P.Mode(plate.kind) == "none" then return false, 0, false, 0, 0 end
	local side, _, _, give, inset, _, ring = L.Portrait(L.Of(plate.kind), P.Ringed(), plate.pad)
	if side == 0 then return false, 0, false, 0, 0 end
	return true, give, L.MIRRORED[plate.kind] == true, inset, ring
end

-- The plate's housing: over the whole frame, or (like the game's) standing back behind the circle and on its
-- middle. What stands on the housing's top edge (combo points, a buff row) stands as far down (plate.drop).
local function House(plate, inX, inset, mirrored)
	local house = plate.house
	if not house or (plate.houseX == inX and plate.drop == inset and plate.houseMirrored == mirrored) then return end
	plate.houseX, plate.drop, plate.houseMirrored = inX, inset, mirrored
	house:ClearAllPoints()
	house:SetPoint("TOPLEFT", plate.owner, "TOPLEFT", mirrored and 0 or inX, -inset)
	house:SetPoint("BOTTOMRIGHT", plate.owner, "BOTTOMRIGHT", mirrored and -inX or 0, inset)
	if plate.SeatRiser then plate:SeatRiser() end
end

local function Build(plate)
	local owner = plate.owner
	local level = owner:GetFrameLevel()
	local box = { covering = false, heads = {}, tint = {} }
	local col = CreateFrame("Frame", nil, owner)
	col:SetFrameLevel(level + LEVELS.col)
	local rim = CreateFrame("Frame", nil, col)
	rim:SetFrameLevel(level + LEVELS.rim)
	rim:SetAllPoints(col)
	box.col, box.rim = col, rim
	box.face = col:CreateTexture(nil, "BACKGROUND")
	box.icon = rim:CreateTexture(nil, "ARTWORK")
	box.mask = rim:CreateMaskTexture()
	box.mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	box.ring = rim:CreateTexture(nil, "ARTWORK", nil, 4)   -- over the picture; a look's own ring over it (5 to 7)
	for _, t in ipairs({ box.face, box.ring }) do
		t:SetSnapToPixelGrid(false)   -- (on the circle's own middle)
		t:SetTexelSnappingBias(0)
	end
	plate.portrait = box
	return box
end

-- The ring's color: steel (glass under a look's own ring), your color, or the unit's class where it can be read.
-- A hunter's pet that isn't happy wears its mood instead (Mood.lua).
local function RingColor(box, unit)
	if box.look and box.look:Worn() then return GLASS end
	local mood = ns.Mood and ns.Mood.Ring(unit)
	if mood then return mood end
	local pick = T.db.portrait.ring
	if pick == "accent" then return { Theme.Accent() } end
	if pick == "class" and unit then
		local player = UnitIsPlayer(unit)
		if not issecretvalue(player) and player then
			local _, class = UnitClass(unit)
			local color = not issecretvalue(class) and class and C_ClassColor.GetClassColor(class)
			if color then return { color.r, color.g, color.b } end
		end
	end
	return Theme.skin.metal
end

local function Tint(box, unit)
	if not box.ringed then return end
	local c = RingColor(box, unit)
	local tint = box.tint
	if tint[1] ~= c[1] or tint[2] ~= c[2] or tint[3] ~= c[3] then
		tint[1], tint[2], tint[3] = c[1], c[2], c[3]
		box.ring:SetVertexColor(c[1], c[2], c[3])
	end
end

-- A dial piece (Media\Portrait<piece><circle>) on the circle's middle, as large as the circle it is shown for.
local function Dial(t, piece, circle, across, col)
	t:SetTexture(L.RING.media .. "Portrait" .. piece .. circle)
	local span = (circle + 2 * L.RING.pad) * across / circle
	t:ClearAllPoints()
	t:SetPoint("CENTER", col, "CENTER", 0, 0)
	t:SetSize(span, span)
end

-- The bands of a circle `r` across in which a round head is drawn, none reaching past `R` (Strips): { bottom, top,
-- half width } from the middle. The middle band is as wide as the circle; each further one as wide as the circle is
-- at its near edge, and as tall as that width allows inside `R`.
local function Strips(r, R)
	local out = {}
	local h = math.sqrt(math.max(0, R * R - r * r))
	out[1] = { -h, h, r }
	local y = h
	while y < r do
		local w = math.sqrt(r * r - y * y)
		local up = math.min(r, math.sqrt(R * R - w * w))
		out[#out + 1] = { y, up, w }
		out[#out + 1] = { -up, -y, w }
		y = up
	end
	return out
end
P.Strips = Strips

local Camera

-- A model takes no alpha from its frames. So a head is given its frame's own, or it stays solid while the HUD fades.
local function SeeThrough(model)
	local a = model:GetEffectiveAlpha()
	if not issecretvalue(a) and a ~= model.shyAlpha then
		model.shyAlpha = a
		model:SetModelAlpha(a)
		return true
	end
	return false
end

-- The heads the style draws: one filling the square, or one a band of the circle. Made once each, and kept.
local function Heads(plate, box)
	local key = box.ringed and "round" or "square"
	local set = box.heads[key]
	if not set then
		set = { frames = {} }
		box.heads[key] = set
	end
	local at = box.ringed and box.r or box.side
	if set.at == at then return set end
	set.at = at
	local level = plate.owner:GetFrameLevel() + LEVELS.head
	local bands = box.ringed and Strips(box.r, box.R - CLEAR) or { false }
	for i, band in ipairs(bands) do
		local model = set[i]
		if not model then
			local holder = box.col
			if band then
				holder = CreateFrame("Frame", nil, box.col)
				holder:SetClipsChildren(true)
				holder:SetFrameLevel(level)
				set.frames[i] = holder
			end
			model = CreateFrame("PlayerModel", nil, holder)
			model:SetFrameLevel(level)
			model:SetKeepModelOnHide(true)
			model:SetScript("OnShow", function()
				if box.pending then P.Draw(plate) end
			end)
			model:SetScript("OnModelLoaded", Camera)
			set[i] = model
		end
		model:ClearAllPoints()
		if band then
			local holder = set.frames[i]
			holder:ClearAllPoints()
			holder:SetPoint("BOTTOMLEFT", box.col, "CENTER", -band[3], band[1])
			holder:SetPoint("TOPRIGHT", box.col, "CENTER", band[3], band[2])
			holder:Show()
			model:SetPoint("TOPLEFT", box.col, "CENTER", -box.r, box.r)
			model:SetPoint("BOTTOMRIGHT", box.col, "CENTER", box.r, -box.r)
		else
			model:SetAllPoints(box.col)
		end
	end
	for i = #bands + 1, #set do
		set[i]:Hide()
		if set.frames[i] then set.frames[i]:Hide() end
	end
	set.count = #bands
	return set
end

-- Every head of a style put away.
local function HideHeads(box, key)
	local set = box.heads[key]
	if not set then return end
	for i, model in ipairs(set) do
		if model:IsShown() then model:Hide() end
		if set.frames[i] then set.frames[i]:Hide() end
	end
end

-- The portrait dressed for the style and size: the square's well, or the dial round the circle.
local function Dress(plate, box)
	local side, ringed = box.side, box.ringed
	local col, icon, mask = box.col, box.icon, box.mask
	icon:ClearAllPoints()
	if ringed then
		local circle, r, R = L.Ring(side)
		box.r, box.R = r, R
		Dial(box.face, "Face", circle, side, col)
		Dial(box.ring, "Ring", circle, side, col)
		box.face:Show()
		box.ring:Show()
		if box.slot then box.slot.well:Hide() end
		icon:SetPoint("CENTER", col, "CENTER", 0, 0)
		icon:SetSize(2 * r, 2 * r)
		mask:ClearAllPoints()
		mask:SetAllPoints(icon)
		if not box.masked then
			icon:AddMaskTexture(mask)
			box.masked = true
		end
		box.look = box.look or UI.LookRing(box.ring, side)
		box.look.size = side
		box.look:Dress()
		Tint(box, plate.unit)
	else
		box.face:Hide()
		box.ring:Hide()   -- (a look's own ring follows its dial)
		if box.masked then
			icon:RemoveMaskTexture(mask)
			box.masked = false
		end
		icon:SetAllPoints(col)
		local opts = { to = col, size = side, style = "none", hover = false }
		if box.slot then box.slot:Set(opts) else box.slot = Slot.New(col, opts) end
		box.slot.well:Show()
	end
	HideHeads(box, ringed and "square" or "round")
end

local Unwatch

-- Seated where Plate:Arrange left the bars: at the frame's left end, or its right when mirrored.
function P.Arrange(plate, on, mirrored)
	local box = plate.portrait
	if not on then
		House(plate, 0, 0, false)
		if box and box.col:IsShown() then
			box.col:Hide()
			box.side, box.mode = nil, nil
			Unwatch(box)
		end
		if box then P.Cover(plate) end
		return
	end
	box = box or Build(plate)
	local ringed = P.Ringed()
	local side, inX, top, _, inset, behind = L.Portrait(plate.layout, ringed, plate.pad)
	local x = mirrored and plate.width - inX - side or inX
	House(plate, behind, inset, mirrored)
	if box.side ~= side or box.x ~= x or box.top ~= top or box.ringed ~= ringed then
		box.side, box.x, box.top, box.ringed = side, x, top, ringed
		local col = box.col
		col:ClearAllPoints()
		col:SetPoint("TOPLEFT", plate.owner, "TOPLEFT", x, -top)
		col:SetSize(side, side)
		Dress(plate, box)
		box.mode = nil
	end
	local mode = P.Mode(plate.kind)
	if not box.col:IsShown() or box.mode ~= mode then
		box.col:Show()
		box.mode = mode
		P.Draw(plate)
	end
	Tint(box, plate.unit)   -- (the ring's color may be what changed)
	P.Cover(plate)
end

-- A readable class of a player, or nil.
local function ClassOf(unit)
	local player = UnitIsPlayer(unit)
	if issecretvalue(player) or not player then return nil end
	local _, class = UnitClass(unit)
	if issecretvalue(class) or not class then return nil end
	return class
end

-- The class picture, cut from the game's class atlas as an icon is cropped. False where the game has none.
local function ClassPicture(box, class)
	if box.class == class then return true end
	local info = C_Texture.GetAtlasInfo(GetClassAtlas(class))
	if not info then return false end
	local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
	local icon = box.icon
	icon:SetTexture(info.file or info.filename)
	icon:SetTexCoord(l + (r - l) * CROP, r - (r - l) * CROP, t + (b - t) * CROP, b - (b - t) * CROP)
	box.class, box.flat = class, false
	return true
end

-- The game's own flat portrait, square, cropped as an icon is: a ring cuts it round. Drawn again whenever asked:
-- the game says when it changed (UNIT_PORTRAIT_UPDATE).
local function FlatPicture(box, unit)
	local icon = box.icon
	if not box.flat then icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP) end
	box.class, box.flat = nil, true
	SetPortraitTexture(icon, unit, true)
end

-- The head: a model of the unit, still, filling the square, or each band of the circle. Asked for only when the unit
-- is someone new (an animation restarts at every ask), and again when it shows after being out of sight.
function Camera(model)
	model:SetPortraitZoom(1)
	model:SetRotation(0)
	model:SetLight(true, Light())
	model:FreezeAnimation(0, 0, 0)
	model.shyAlpha = nil   -- (a new model may come in solid)
	SeeThrough(model)
end

-- A head's models given its frame's alpha (SeeThrough) where it changed.
local function Fade(box)
	local set = box.headShown and box.heads[box.ringed and "round" or "square"]
	if not set then return false end
	local changed = false
	for i = 1, set.count do
		if SeeThrough(set[i]) then changed = true end
	end
	return changed
end

-- Every frame while something fades the HUD (the idle fade, or your frame's own out of a fight), and until the
-- heads stop changing.
local follow = CreateFrame("Frame")
local function Fading()
	local hud, fader = Shy.Immersion, ns.Fader
	return (hud ~= nil and hud.Faded ~= nil and hud.Faded() == true) or (fader ~= nil and fader.Busy())
end
local followed = Shy.Clocked("ShyFrames portrait fade", function()
	local changed = false
	for _, frame in ipairs(ns.Frames and ns.Frames.list or {}) do
		local box = frame.plate and frame.plate.portrait
		if box and box.col:IsShown() and Fade(box) then changed = true end
	end
	if not changed and not Fading() then follow:SetScript("OnUpdate", nil) end
end)
function P.Follow()
	follow:SetScript("OnUpdate", followed)
end
-- Whether the heads are being followed.
function P.Following()
	return follow:GetScript("OnUpdate") ~= nil
end
P.FollowStep = followed
Shy:On("SHY_IMMERSION_FADE", P.Follow)

-- Whether the head is drawn: the game answers false, or nothing to be read, when it can't be.
local function Head(plate, box, unit)
	local set = Heads(plate, box)
	for i = 1, set.count do
		local holder = set.frames[i]
		if holder and not holder:IsShown() then holder:Show() end
		if not set[i]:IsShown() then set[i]:Show() end
	end
	box.pending = not set[1]:IsVisible()
	if box.pending then return false end
	local shown = false
	local withheld = C_Secrets.ShouldUnitIdentityBeSecret(unit)
	if not issecretvalue(withheld) and not withheld then
		shown = true
		for i = 1, set.count do
			local ok, set_ = pcall(set[i].SetUnit, set[i], unit)
			if not (ok and (issecretvalue(set_) or set_ ~= false)) then shown = false end
		end
	end
	if not shown then
		for i = 1, set.count do set[i]:ClearModel() end
	end
	return shown
end

-- One event frame a portrait, told its unit the first time the frame draws it.
local EVENTS = { "UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE" }
local heard = Shy.Clocked("ShyFrames portrait", function(events, event)
	local plate = events.plate
	local box = plate.portrait
	if event == "UNIT_MODEL_CHANGED" or (box.flat and not box.headShown) then P.Draw(plate) end
end)

local function Watch(plate, box, unit)
	if box.watching == unit then return end
	local events = box.events
	if not events then
		events = CreateFrame("Frame", nil, plate.owner)
		events.plate = plate
		events:SetScript("OnEvent", heard)
		box.events = events
	end
	events:UnregisterAllEvents()
	for _, event in ipairs(EVENTS) do events:RegisterUnitEvent(event, unit) end
	box.watching = unit
end

function Unwatch(box)
	if box.events and box.watching then
		box.events:UnregisterAllEvents()
		box.watching = nil
	end
end

-- Drawn when the frame shows someone new, when the game says the unit's look changed, and when a setting changes.
function P.Draw(plate)
	local box = plate.portrait
	if not box or not box.col:IsShown() then return end
	P.Cover(plate)
	local unit = plate.unit
	if not unit then return end
	local exists = UnitExists(unit)
	if not issecretvalue(exists) and not exists then return end
	Watch(plate, box, unit)
	Tint(box, unit)
	local mode = box.mode
	local head = mode == "head" and Head(plate, box, unit)
	if mode ~= "head" then HideHeads(box, box.ringed and "round" or "square") end
	if not head then
		-- A face is the flat portrait; a class icon, or a head that can't be drawn, a player's class.
		local class = mode ~= "face" and ClassOf(unit)
		if not (class and ClassPicture(box, class)) then FlatPicture(box, unit) end
	end
	if head ~= (box.headShown == true) then
		box.headShown = head
		box.icon:SetShown(not head)
	end
	if head then Fade(box) end
end

-- The level in a circle of its own (T.db.portrait.level), as the game's frames of old held it: the family's small dial
-- (ShyCore's DialSmall, drawn for it) on the round picture's lower edge, toward the frame's end, the level in its
-- difficulty's color. Your frame and your target's only. -> whether the level shows there (the class line then leaves
-- it out).
-- The number stands on the circle's middle to the pixel: measured, its width and height in whole screen pixels, and
-- the circle's middle laid on a pixel's edge or its middle as they ask, so the two share one middle exactly (the
-- ring isn't snapped to the grid: UI.Concentric). `shadow`: words over the world wear a drop shadow this far right and
-- down (UI.Words' world shadow); half of it is moved back, so the ink with its shadow is what is centred.
local BADGE = { ring = 24, face = 29, x = 0.6, y = 0.62, font = 11, shadow = 0.8 }   -- circle, art, its middle off the ring's (of R)

local function Badge(plate, box)
	local badge = box.badge
	if badge then return badge end
	badge = CreateFrame("Frame", nil, plate.owner)
	badge:SetFrameLevel(plate.owner:GetFrameLevel() + LEVELS.button)
	badge:SetSize(BADGE.ring, BADGE.ring)
	badge.dial = badge:CreateTexture(nil, "ARTWORK")
	badge.dial:SetTexture(Shy.MEDIA .. "DialSmall")
	badge.dial:SetSize(BADGE.face, BADGE.face)
	badge.dial:SetPoint("CENTER", badge, "CENTER", 0, 0)
	UI.Concentric(badge.dial)   -- on the circle's own middle, not snapped a pixel off it
	badge.look = UI.LookRing(badge.dial, BADGE.ring)
	badge.word = UI.Words(badge, UI.NameFont(BADGE.font, "OUTLINE"), UI.colors.text, { world = true, justify = "CENTER" })
	badge.word:SetWordWrap(false)
	box.badge = badge
	return badge
end

function P.Level(plate)
	local box = plate.portrait
	local on = box ~= nil and box.ringed and box.col:IsShown() and plate.layout.texts.class ~= nil
		and T.db.portrait.level and plate.unit ~= nil
	if not on then
		if box and box.badge and box.badge:IsShown() then box.badge:Hide() end
		return false
	end
	local badge = Badge(plate, box)
	local level, red, green, blue = ns.Units.Level(plate.unit)
	local word = badge.word
	word:SetText(level)
	word:SetTextColor(red, green, blue)
	local mirrored = L.MIRRORED[plate.kind] == true
	local r = box.side / 2
	local x, y = r - BADGE.x * r, r + BADGE.y * r
	-- In whole screen pixels where the frame stands (a unit each where they can't be read).
	local scale, factor = plate.owner:GetEffectiveScale(), PixelUtil.GetPixelToUIUnitFactor()
	local per = (not issecretvalue(scale) and scale and scale > 0 and factor and factor > 0) and scale / factor or 1
	local w, h = word:GetUnboundedStringWidth(), word:GetStringHeight()
	if issecretvalue(w) or issecretvalue(h) or not w or not h then w, h = 0, 0 end
	local wp, hp = math.floor(w * per + 0.5), math.floor(h * per + 0.5)
	local half = BADGE.shadow / 2
	-- The ink's middle over the line's: its capitals' (UI.NameLift, less the family's own shadow allowance), with
	-- half this shadow.
	local liftp = math.floor((UI.NameLift(BADGE.font) - 0.5 + half) * per + 0.5)
	local cx = (math.floor(x * per + 0.5) + (wp % 2) * 0.5) / per
	local cy = (math.floor(y * per + 0.5) + (hp % 2) * 0.5) / per
	local key = cx .. ":" .. cy .. ":" .. wp .. ":" .. hp .. ":" .. tostring(mirrored)
	if badge.at ~= key then
		badge.at = key
		badge:ClearAllPoints()
		badge:SetPoint("CENTER", plate.owner, mirrored and "TOPRIGHT" or "TOPLEFT", mirrored and -cx or cx, -cy)
		word:ClearAllPoints()
		word:SetPoint("TOPLEFT", badge, "CENTER", (-wp / 2 - math.floor(half * per + 0.5)) / per, (hp / 2 + liftp) / per)
	end
	local c = badge.look:Worn() and GLASS or Theme.skin.metal
	badge.dial:SetVertexColor(c[1], c[2], c[3])
	if not badge:IsShown() then badge:Show() end
	return true
end

-- The ring's color asked again (a pet's mood changed).
function P.Retint(plate)
	local box = plate.portrait
	if box and box.ringed and box.col:IsShown() then Tint(box, plate.unit) end
end

-- The ring's colors follow the theme.
Shy:On("SHY_THEME", function()
	for _, frame in ipairs(ns.Frames and ns.Frames.list or {}) do
		local box = frame.plate and frame.plate.portrait
		if box and box.ringed and box.col:IsShown() then
			wipe(box.tint)
			Tint(box, frame.plate.unit)
		end
	end
end)

-- Crowd control: the game's own aura container with one slot, over the portrait, in its shape. The game shows and
-- hides its button, so a sheeped or feared unit's picture is covered and uncovered with nothing of ours asking. In the
-- round the cover wears its own ring, in gold. A container can only be made, placed, sized and switched while auras
-- can be read: out of a fight, or it waits for the end.

local function Free()
	return not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret()
end

-- The cover's button stands where the portrait does and is as big as it: on the frame, never on the portrait's own
-- frame, which Arrange moves in a fight.
local function Fit(box, owner)
	local parts, side = box.parts, box.side
	local button, icon, ringed = parts.button, parts.icon, box.ringed
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", owner, "TOPLEFT", box.x, -box.top)
	button:SetSize(side, side)
	icon:ClearAllPoints()
	if ringed then
		icon:SetPoint("CENTER", button, "CENTER", 0, 0)
		icon:SetSize(2 * box.r, 2 * box.r)
		parts.mask:ClearAllPoints()
		parts.mask:SetAllPoints(icon)
		if not parts.masked then
			for _, t in ipairs({ icon, parts.fade }) do t:AddMaskTexture(parts.mask) end
			parts.masked = true
		end
		parts.cooldown:SetSwipeTexture(CIRCLE, SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		local circle = L.Ring(side)
		Dial(parts.ring, "Ring", circle, side, button)
		parts.ring:Show()
	else
		icon:SetAllPoints(button)
		if parts.masked then
			for _, t in ipairs({ icon, parts.fade }) do t:RemoveMaskTexture(parts.mask) end
			parts.masked = false
		end
		parts.cooldown:SetSwipeTexture(SOLID, SHADE[1], SHADE[2], SHADE[3], SHADE[4])
		parts.ring:Hide()
	end
	parts.fade:SetHeight((ringed and 2 * box.r or side) * FADE)
	parts.time:SetFontObject(UI.NameFont(math.max(9, math.floor(side * TIME + 0.5)), "OUTLINE"))
	box.fitSide, box.fitX, box.fitTop, box.fitRinged = side, box.x, box.top, ringed
end

local function MakeButton(button, plate)
	local box = plate.portrait
	local parts = { button = button }
	box.parts = parts
	button:SetFrameLevel(plate.owner:GetFrameLevel() + LEVELS.button)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	parts.icon = icon
	parts.mask = button:CreateMaskTexture()
	parts.mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetDrawBling(false)
	cooldown:SetDrawEdge(false)
	cooldown:SetHideCountdownNumbers(true)   -- the time is our own text
	cooldown:SetReverse(true)                -- the shade grows as time runs out
	parts.cooldown = cooldown
	local over = CreateFrame("Frame", nil, button)
	over:SetAllPoints()
	over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local fade = over:CreateTexture(nil, "BACKGROUND")
	fade:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
	fade:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
	fade:SetColorTexture(1, 1, 1)
	fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0))
	parts.fade = fade
	local ring = over:CreateTexture(nil, "ARTWORK")
	ring:SetSnapToPixelGrid(false)
	ring:SetTexelSnappingBias(0)
	ring:SetVertexColor(unpack(UI.colors.alert))
	ring:Hide()
	parts.ring = ring
	local time = UI.Words(over, UI.NameFont(11, "OUTLINE"), UI.colors.text, { world = true, justify = "CENTER" })
	time:SetWordWrap(false)
	time:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
	parts.time = time
	button:SetIcon(icon)
	button:SetDurationCooldown(cooldown)
	button:SetDurationText(time)
	pcall(button.EnableMouse, button, false)   -- a click lands on the frame
	Fit(box, plate.owner)
end

local function MakeCover(plate)
	local owner = plate.owner
	local c = CreateFrame("AuraContainer", nil, owner, "CustomAuraContainerTemplate")
	c:SetEnabled(false)
	c:Hide()
	c:SetPoint("TOPLEFT", owner, "TOPLEFT", 0, 0)
	c:SetSize(1, 1)
	c:SetFrameLevel(owner:GetFrameLevel() + LEVELS.cover)
	c:AddAuraSlot("control", COVER_FILTER, { initializeFrame = function(button) MakeButton(button, plate) end })
	plate.portrait.cover = c
	return c
end

local waiting, order = {}, {}   -- the plates whose cover waits for the fight to end

local function Fitted(box)
	return box.fitSide == box.side and box.fitX == box.x and box.fitTop == box.top and box.fitRinged == box.ringed
end

-- Switched on, off, seated and told its unit only when that changed.
function P.Cover(plate)
	local box = plate.portrait
	if not box then return end
	local unit = plate.unit
	local on = (box.col:IsShown() and T.db.control and unit ~= nil) and true or false
	local c = box.cover
	if not c and not on then return end
	if on == box.covering and (not on or (Fitted(box) and box.coverUnit == unit)) then return end
	if not Free() then
		waiting[plate] = true
		return
	end
	if on then
		c = c or MakeCover(plate)
		if box.coverUnit ~= unit then
			c:SetUnit(unit)
			box.coverUnit = unit
		end
		if box.parts and not Fitted(box) then Fit(box, plate.owner) end
		if not box.covering then
			c:SetEnabled(true)
			c:Show()
			box.covering = true
		end
	elseif box.covering then
		c:SetEnabled(false)
		c:Hide()
		box.covering = false
	end
end

local waiter = CreateFrame("Frame")
waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
waiter:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
local release = Shy.Clocked("ShyFrames portrait cover", function()
	if not Free() then return end
	wipe(order)
	for plate in pairs(waiting) do order[#order + 1] = plate end
	wipe(waiting)
	for _, plate in ipairs(order) do P.Cover(plate) end
end)
waiter:SetScript("OnEvent", function() C_Timer.After(0, release) end)
