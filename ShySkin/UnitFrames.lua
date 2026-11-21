-- Unit frames: player, target, focus, their targets, pet, and party with its pets.
-- Blizzard's frame art and bar masks are removed and a panel is drawn in their place.
-- Only regions are touched (alpha, art, anchors), never a frame, so everything is safe in combat.
-- Blizzard's bars carry their color in their art, so with the hatch the color is set here.
-- A unit's class and classification can be secret: then the name, bar and dragon stay Blizzard's.
-- Blizzard reapplies art in UnitFrameManaBar_UpdateType, UnitFramePortrait_Update, UnitFrame_Update,
-- PlayerFrame_ToPlayerArt / ToVehicleArt, CheckClassification, the party members' To*Art and
-- PartyFrame:InitializePartyMemberFrames. The first three run every frame for a target's target: keep them cheap.
-- Sizes and insets come from Blizzard_UnitFrame's XML and its Camelot overrides.

local ADDON, ns = ...
local UI, Skin = Shy.UI, Shy.Skin
local C = Skin.colors

local CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"   -- square class icons on one sheet
local CROP = 0.018      -- trims each icon's own rim
local PLAIN = {}        -- shared empty options table
local WOVEN = { tile = true }           -- the hatch tiles along a bar
local WELL = { 0, 0, 0, 0.55 }
local BAND = { 1, 1, 1, 0.38 }          -- white: Blizzard colors it
local TINY = 0.01                       -- size of a hidden portrait
local BRACKET = 10                      -- corner brackets on the two big frames
local TALL = 11                         -- extra height for a druid's second power bar
local SPARE = 8                         -- how far our power bar mask overshoots the end it doesn't cut

-- Fixed meanings: these don't follow the accent.
local HEALTH = { 0.20, 0.80, 0.28 }
local OFFLINE = { 0.50, 0.50, 0.52 }
local GOLD, SILVER = { 1.00, 0.80, 0.28 }, { 0.90, 0.94, 1.00 }

-- Classification -> { label, color }, replacing Blizzard's dragon.
local RANKS = {
	worldboss = { BOSS, GOLD },
	elite = { ELITE, GOLD },
	rare = { ITEM_QUALITY3_DESC, SILVER },
	rareelite = { ITEM_QUALITY3_DESC .. " " .. ELITE, SILVER },
}

local specs, list = {}, {}   -- unit frame -> its spec
local powers = {}            -- power bar -> its frame's spec
local clipped = {}           -- power bar fill -> our mask on it
local moved = {}             -- font string -> Blizzard's anchors
local classColors, powerColors = {}, {}

local function Add(s)
	specs[s.frame] = s
	list[#list + 1] = s
	if s.power then powers[s.power] = s end
	if s.box then s.well = { -1, -1, -1, -(s.powerHeight + 2) } end   -- one well behind both bars
	return s
end

-- Reading values that can be secret

-- Returns the texture's atlas, or nil; the second value is true when it is secret.
local function AtlasOf(texture)
	local atlas = texture:GetAtlas()
	if issecretvalue(atlas) then return nil, true end
	if atlas and atlas ~= "" then return atlas end
end

-- A player's class color, or nil for a non-player or a secret class.
local function ClassColor(unit)
	local isPlayer = UnitIsPlayer(unit)
	if issecretvalue(isPlayer) or not isPlayer then return end
	local class = UnitClassBase(unit)
	if not class or issecretvalue(class) then return end
	local color = classColors[class]
	if color == nil then
		local c = C_ClassColor.GetClassColor(class)
		color = c and { c:GetRGB() } or false
		classColors[class] = color
	end
	return color or nil
end

-- One of RANKS, nil for a normal unit, false when the classification is secret.
local function RankOf(unit)
	local kind = UnitClassification(unit)
	if issecretvalue(kind) then return false end
	local boss = UnitIsBossMob(unit)
	if not issecretvalue(boss) and boss then return RANKS.worldboss end
	return RANKS[kind]
end

-- A region whose anchors are secret can't be restored, so it isn't moved. In a fight even how many
-- anchors it has can be secret.
local function CanPlace(region)
	local points = region:GetNumPoints()
	if not canaccessvalue(points) then return false end
	for i = 1, points do
		if not canaccessvalue(region:GetPoint(i)) then return false end
	end
	return canaccessvalue(region:GetSize())
end

local function Place(kit, region, ...)
	if not (region and CanPlace(region)) then return false end
	kit:Place(region, ...)
	return true
end

-- For a font string that sizes to its text (a level): the kit would restore a fixed size, so only anchors are kept.
local function Move(fontString, ...)
	if not moved[fontString] then
		local points = {}
		for i = 1, fontString:GetNumPoints() do
			if not canaccessvalue(fontString:GetPoint(i)) then return end
			points[i] = { fontString:GetPoint(i) }
		end
		moved[fontString] = points
	end
	fontString:ClearAllPoints()
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		fontString:SetPoint(p[1], p[2], p[3], p[4], p[5])
	end
end

-- The panel

-- An invisible region the panel, glows and badges anchor to; it can move after they are made.
local function Bound(m, kit, s)
	local bounds = ns.Own(kit, s.owner, "bounds", function(owner)
		local t = owner:CreateTexture(nil, "BACKGROUND")
		t:SetColorTexture(0, 0, 0, 0)
		return t
	end)
	local inset = m.opt.portraits and s.wide or s.slim
	local foot = inset[4]
	if s.frame.activeAlternatePowerBar then foot = foot - TALL end   -- player frame only
	bounds:ClearAllPoints()
	bounds:SetPoint("TOPLEFT", s.owner, "TOPLEFT", inset[1], -inset[2])
	bounds:SetPoint("BOTTOMRIGHT", s.owner, "BOTTOMRIGHT", -inset[3], foot)
	s.bounds = bounds
end

-- The panel and the portrait's frame, in steel or a rank's color.
local function Edge(m, kit, s, color)
	if s.flat then
		kit:Plate(s.owner, { to = s.bounds, hud = true })
	else
		kit:Plate(s.owner, { to = s.bounds, panel = true, brackets = s.big and BRACKET or false, border = color, hud = true })
	end
	if not (s.tile and m.opt.portraits) then return end
	local tile = ns.Own(kit, s.owner, "tile", function(owner)
		local t = owner:CreateTexture(nil, "OVERLAY")
		t:SetTexture(Skin.FRAME)
		t:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
		t:SetPoint("TOPLEFT", s.portrait, "TOPLEFT", -s.tile, s.tile)
		t:SetPoint("BOTTOMRIGHT", s.portrait, "BOTTOMRIGHT", s.tile, -s.tile)
		return t
	end)
	local c = color or C.metal
	tile:SetVertexColor(c[1], c[2], c[3])
end

-- Portraits

-- Redraws Blizzard's round portrait square. A class icon portrait (atlas "classicon-<class>")
-- becomes the square icon of that class. fresh: Blizzard has just redrawn it.
local function Square(s, fresh)
	local portrait = s.portrait
	local atlas, hidden = AtlasOf(portrait)
	if hidden then return end
	if atlas then
		local class = atlas:lower():match("^classicon%-(%a+)$")
		local at = class and CLASS_ICON_TCOORDS[class:upper()]
		if at then
			portrait:SetTexture(CLASSES)
			portrait:SetTexCoord(at[1] + CROP, at[2] - CROP, at[3] + CROP, at[4] - CROP)
			s.emblem = atlas
		end
		return
	end
	if s.emblem then
		if not fresh then return end   -- still our square icon
		portrait:SetTexCoord(0, 1, 0, 1)
		s.emblem = nil
	end
	-- PlayerFrame's is already square (disablePortraitMask).
	if s.frame.disablePortraitMask or not UnitExists(s.frame.unit) then return end
	SetPortraitTexture(portrait, s.frame.unit, true)
	s.squared = true
end

local function Face(m, kit, s)
	local portrait = s.portrait
	if not portrait then return end
	if not m.opt.portraits then
		-- Blizzard sets a portrait's alpha itself, so it is shrunk instead of faded. The pet's
		-- bars are anchored to its portrait, so that one is only faded.
		if s.gone then
			Place(kit, portrait, TINY, TINY, { "CENTER", s.owner, "TOPLEFT", s.gone[1], -s.gone[2] })
		else
			kit:Hide(portrait)
		end
		return
	end
	kit:Unmask(portrait, s.mask)
	if s.face then
		Place(kit, portrait, s.face[1], s.face[1], { "CENTER", s.owner, "TOPLEFT", s.face[2], -s.face[3] })
	end
	Square(s)
end

-- Bars

-- Blizzard swaps a bar's art on the fill texture; the kit records what is there each time,
-- so a restore returns Blizzard's current art, not what it had at login.
local function Fill(kit, bar)
	local fill = bar:GetStatusBarTexture()
	kit:Art(fill, Skin.HATCH, WOVEN)
	return fill
end

local function ColorHealth(m, kit, s)
	if not s.box then return end   -- Blizzard colors a party pet's bar itself
	local unit = s.frame.unit
	local color = HEALTH
	local online = UnitIsConnected(unit)
	if not issecretvalue(online) and online == false then
		color = OFFLINE
	elseif m.opt.classHealth then
		color = ClassColor(unit) or HEALTH
	end
	kit:Tint(s.health:GetStatusBarTexture(), color, true)
end

-- Blizzard resets a power bar's art on every type update and leaves the type in bar.powerToken.
-- A type without a PowerBarColor keeps Blizzard's color.
local function Power(kit, bar)
	local fill = Fill(kit, bar)
	local token = bar.powerToken
	if token == nil or issecretvalue(token) then return end
	local color = powerColors[token]
	if color == nil then
		local info = PowerBarColor[token]
		color = info and info.r and { info.r, info.g, info.b } or false
		powerColors[token] = color
	end
	-- Blizzard desaturates a dead player's bar.
	local grey = fill:IsDesaturated()
	if not issecretvalue(grey) and grey then color = OFFLINE end
	if color then kit:Tint(fill, color, true) end
end

-- Blizzard's power bars run past the health bar under the portrait ring (s.runs: which way), which
-- its mask hid. Our mask cuts the bar where the health bar ends, and overshoots the other end
-- because a mask's edge is soft.
local function Clip(s)
	if not s.runs then return end
	local fill = s.power:GetStatusBarTexture()
	if clipped[fill] then return end
	local mask = s.clip
	if not mask then
		local left, right = s.runs == "RIGHT" and -SPARE or 0, s.runs == "LEFT" and SPARE or 0
		mask = s.power:CreateMaskTexture()
		mask:SetTexture(Skin.BAR, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")   -- any fully opaque texture
		mask:SetPoint("TOPLEFT", s.box, "BOTTOMLEFT", left, 0)
		mask:SetPoint("BOTTOMRIGHT", s.box, "BOTTOMRIGHT", right, -(s.powerHeight + 4))
		s.clip = mask
	end
	fill:AddMaskTexture(mask)
	clipped[fill] = mask
end

local function Bars(m, kit, s)
	kit:Unmask(Fill(kit, s.health), s.healthMask)
	ColorHealth(m, kit, s)
	if s.box then kit:Plate(s.box, { key = "well", inset = s.well, fill = WELL, border = C.edge }) end
	if s.power then
		kit:Unmask(s.power:GetStatusBarTexture(), s.powerMask)
		Clip(s)
		Power(kit, s.power)
	end
	for _, fontString in ipairs(s.numbers) do ns.Number(kit, fontString) end
end

-- Names, levels and classification

-- "Elite" and "Rare" are localized: a font family.
local function LabelFont()
	return UI.TitleFont(10, "OUTLINE")
end

local function ColorName(kit, s)
	if not s.plain then return end
	kit:Text(s.name, s.mine and C.text or (s.classy and ClassColor(s.frame.unit)) or s.plain)
end

local function Name(kit, s)
	local name = s.name
	if not name then return end
	local r, g, b = name:GetTextColor()
	if not canaccessvalue(r, g, b) then
		s.plain = nil
		return
	end
	s.plain = { r, g, b }
	-- Color first, so the kit records Blizzard's: a font object brings its own.
	kit:Text(name, s.plain)
	kit:FontObject(name, UI.NameFont(s.nameSize, "OUTLINE"))
	ColorName(kit, s)
end

-- A target's name row: name on Blizzard's reaction-colored band, rank label, level at the right.
local function Row(kit, s)
	local level, band = s.level, s.band
	if not band then
		if level then Move(level, { "BOTTOMRIGHT", s.box, "TOPRIGHT", -2, 3 }) end
		-- A target's target: its name was anchored to the portrait, which has moved.
		if s.nameAt then Place(kit, s.name, nil, nil, { "TOPLEFT", s.owner, "TOPLEFT", s.nameAt[1], -s.nameAt[2] }) end
		return
	end
	kit:Art(band, BAND, PLAIN)
	-- The name is anchored to the band, so both move or neither.
	s.rowed = CanPlace(s.name) and Place(kit, band, nil, 14,
		{ "BOTTOMLEFT", s.box, "TOPLEFT", 0, 1 }, { "BOTTOMRIGHT", s.box, "TOPRIGHT", 0, 1 })
	Move(level, { "RIGHT", band, "RIGHT", -4, 0 })
	Place(kit, s.skull, nil, nil, { "RIGHT", band, "RIGHT", -4, 0 })
end

local function Mark(m, kit, s)
	local rank = RankOf(s.frame.unit)
	-- The dragon stays when the classification is secret.
	kit:Fade(s.dragon, rank == false and 1 or 0)
	Edge(m, kit, s, rank and rank[2] or nil)
	-- A skull replaces the level when it is too high to show.
	local right = s.level
	local numbered = right:IsShown()
	if not issecretvalue(numbered) and not numbered then right = s.skull end
	if rank then
		local label = ns.Own(kit, s.labelOn, "rank", function(owner)
			return UI.Words(owner, LabelFont())
		end)
		label:ClearAllPoints()
		label:SetPoint("RIGHT", right, "LEFT", -4, 0)
		label:SetText(rank[1])
		label:SetTextColor(rank[2][1], rank[2][2], rank[2][3])
		s.label, right = label, label
	elseif s.label then
		s.label:Hide()
	end
	if s.rowed then
		Place(kit, s.name, nil, 12, { "LEFT", s.band, "LEFT", 4, 0 }, { "RIGHT", right, "LEFT", -4, 0 })
	end
end

-- Glows and badges

-- Blizzard keeps showing, coloring and pulsing the texture; only its art and anchors change.
local function Glow(kit, texture, around, out)
	if not texture then return end
	kit:Art(texture, Skin.GLOW, { fit = around, x = -out, y = -out, slice = Skin.GLOW_SLICE, blend = "ADD" })
end

local function Glows(m, kit, s)
	Glow(kit, s.flash, s.bounds, s.big and 3 or 2)
	if s.tile and m.opt.portraits then
		Glow(kit, s.status, s.portrait, s.tile)
	else
		Glow(kit, s.status, s.bounds, -1)
	end
end

-- When a frame changes kind (vehicle, elite) Blizzard resets the health fill and the glows.
local function Refit(m, kit, s)
	Bound(m, kit, s)
	Fill(kit, s.health)
	Glows(m, kit, s)
	if s.dragon then Mark(m, kit, s) end
end

local function Dress(m, kit, s)
	for _, region in ipairs(s.hide) do kit:Hide(region) end
	Bound(m, kit, s)
	Face(m, kit, s)
	Bars(m, kit, s)
	Name(kit, s)
	Row(kit, s)
	Glows(m, kit, s)
	-- The PvP badge and attack icon move from Blizzard's rim to the panel's.
	Place(kit, s.pvp, nil, nil, { "CENTER", s.bounds, s.pvpSide, 0, 0 })
	Place(kit, s.attack, nil, nil, { "CENTER", s.bounds, "BOTTOMLEFT", 3, 3 })
	if s.dragon then Mark(m, kit, s) else Edge(m, kit, s) end
end

-- The frames. wide / slim: panel insets { left, top, right, bottom } with and without a portrait.
-- face: portrait size and center from the frame's top left. gone: where a hidden portrait goes
-- (marks anchored to it follow). tile: outset of the portrait's frame.

-- 232 x 100. Bars 124 wide at x 85; health 41..60, power to 71; name at 88, 27.
local function PlayerSpec()
	local f = PlayerFrame
	local art, main = f.PlayerFrameContainer, f.PlayerFrameContent.PlayerFrameContentMain
	local context = f.PlayerFrameContent.PlayerFrameContentContextual
	local box, power = main.HealthBarsContainer, main.ManaBarArea.ManaBar
	Add({
		frame = f, owner = art, big = true,
		wide = { 32, 21, 18, 25 }, slim = { 80, 21, 18, 25 },
		hide = { art.FrameTexture, art.VehicleFrameTexture, art.AlternatePowerFrameTexture,
			main.LevelBackgroundCircle, context.PlayerPortraitCornerIcon },
		portrait = art.PlayerPortrait, mask = art.PlayerPortraitMask, face = { 42, 59, 48 }, gone = { 54, 49 }, tile = 2,
		name = PlayerName, nameSize = 12, mine = true, level = PlayerLevelText,
		box = box, health = box.HealthBar, healthMask = box.HealthBarMask,
		power = power, powerMask = power.ManaBarMask, powerHeight = 10,
		numbers = { box.HealthBarText, box.LeftText, box.RightText,
			power.ManaBarText, power.LeftText, power.RightText, PlayerLevelText },
		flash = art.FrameFlash, status = main.StatusTexture,
		pvp = main.PvpBackgroundCircle, pvpSide = "LEFT", attack = context.AttackIcon,
	})
end

-- 232 x 100, mirrored. Health 126 wide from x 23, 40..60; power 134 wide, to 71.
-- Blizzard anchors the auras at 74.5 down, so the panel ends at 75 (the player's too).
local function TargetSpec(f)
	local art, main = f.TargetFrameContainer, f.TargetFrameContent.TargetFrameContentMain
	local context = f.TargetFrameContent.TargetFrameContentContextual
	local box, power = main.HealthBarsContainer, main.ManaBar
	Add({
		frame = f, owner = art, big = true,
		wide = { 18, 21, 30, 25 }, slim = { 18, 21, 78, 25 },
		hide = { art.FrameTexture, main.LevelBackgroundCircle },
		portrait = art.Portrait, mask = art.PortraitMask, face = { 42, 175, 48 }, gone = { 154, 21 }, tile = 2,
		name = main.Name, nameSize = 12, classy = true,
		level = main.LevelText, skull = context.HighLevelTexture, band = main.ReputationColor, labelOn = main,
		box = box, health = box.HealthBar, healthMask = box.HealthBarMask,
		power = power, powerMask = power.ManaBarMask, powerHeight = 10, runs = "RIGHT",
		numbers = { box.HealthBarText, box.LeftText, box.RightText,
			power.ManaBarText, power.LeftText, power.RightText, main.LevelText },
		flash = art.Flash, dragon = art.BossPortraitFrameTexture,
		pvp = context.PvpBackgroundCircle, pvpSide = "RIGHT",
	})
end

-- 120 x 49. Health 70 wide from x 44, 17..27; power 74 wide from x 40, to 35.
local function TargetOfTargetSpec(f)
	Add({
		frame = f, owner = f,
		wide = { 6, 1, 1, 9 }, slim = { 39, 1, 1, 9 },
		hide = { f.FrameTexture },
		portrait = f.Portrait, mask = f.PortraitMask, face = { 27, 25.5, 20.5 }, gone = { 39, 20 }, tile = 2,
		name = f.Name, nameSize = 10, classy = true, nameAt = { 44, 5 },
		box = f.HealthBar, health = f.HealthBar, healthMask = f.HealthBar.HealthBarMask,
		power = f.ManaBar, powerMask = f.ManaBar.ManaBarMask, powerHeight = 7, runs = "LEFT",
		numbers = {},
	})
end

-- Like a target's target, but the name and bars are anchored to the portrait, so it keeps Blizzard's place and size.
local function PetSpec()
	Add({
		frame = PetFrame, owner = PetFrame,
		wide = { 1, 1, 1, 3 }, slim = { 39, 1, 1, 9 },
		hide = { PetFrameTexture },
		portrait = PetFrame.Portrait, mask = PetFrame.PortraitMask, tile = 0,
		name = PetName, nameSize = 10,
		box = PetFrameHealthBar, health = PetFrameHealthBar, healthMask = PetFrameHealthBarMask,
		power = PetFrameManaBar, powerMask = PetFrameManaBarMask, powerHeight = 7, runs = "LEFT",
		numbers = { PetFrameHealthBarText, PetFrameHealthBarTextLeft, PetFrameHealthBarTextRight,
			PetFrameManaBarText, PetFrameManaBarTextLeft, PetFrameManaBarTextRight },
		flash = PetFrameFlash, status = PetAttackModeTexture,
	})
end

-- 120 x 53. Health 70 wide from x 45, 19..29; power 74 wide from x 41, to 37; debuffs and pet from 43.
-- The ready check is anchored to the portrait's center, so that barely moves (from 25.5, 24.5).
local function PartySpec(m, f)
	local box, power, pet = f.HealthBarContainer, f.ManaBar, f.PetFrame
	local s = Add({
		frame = f, owner = f,
		wide = { 6, 2, 0, 11 }, slim = { 40, 2, 0, 11 },
		hide = { f.Texture, f.VehicleTexture },
		portrait = f.Portrait, mask = f.PortraitMask, face = { 28, 26, 22 }, gone = { 25.5, 24.5 }, tile = 2,
		name = f.Name, nameSize = 10, classy = true,
		box = box, health = box.HealthBar, healthMask = box.HealthBarMask,
		power = power, powerMask = power.ManaBarMask, powerHeight = 7, runs = "LEFT",
		numbers = { box.CenterText, box.LeftText, box.RightText, power.CenterText, power.LeftText, power.RightText },
		flash = f.Flash, status = f.PartyMemberOverlay.Status,
	})
	-- Its pet, 64 x 23: too small for a beveled edge or a portrait frame.
	Add({
		frame = pet, owner = pet, flat = true,
		wide = { 1, 1, 5, 0 }, slim = { 19, 6, 5, 6 },
		hide = { pet.Texture },
		portrait = pet.Portrait, mask = pet.PortraitMask,
		health = pet.HealthBar, numbers = {},
		flash = pet.Flash,
	})
	for _, method in ipairs({ "ToPlayerArt", "ToVehicleArt", "ToCharacterStyleArt" }) do
		hooksecurefunc(f, method, function()
			if m.on then Refit(m, m.kit, s) end
		end)
	end
end

ns.Module({
	id = "units",
	title = "Unit frames",
	desc = "The game's unit frames get dark panels, square portraits and class-colored names.",
	group = "screen",
	words = "player target focus pet party",
	shown = function() return ns.Theirs(PlayerFrame, PetFrame, TargetFrame, FocusFrame, PartyFrame) end,
	options = {
		{ key = "portraits", label = "Portraits", default = true,
			desc = "Each frame shows its portrait. Off, you get a slim frame with the name and bars." },
		{ key = "classHealth", label = "Class-colored health", default = false,
			desc = "Players' health bars take their class color, yours too. NPCs stay green." },
	},

	Hook = function(m)
		PlayerSpec()
		PetSpec()
		for _, f in ipairs({ TargetFrame, FocusFrame }) do
			TargetSpec(f)
			TargetOfTargetSpec(f.totFrame)
			hooksecurefunc(f, "CheckClassification", function(self)
				if m.on then Refit(m, m.kit, specs[self]) end
			end)
		end
		for f in PartyFrame.PartyMemberFramePool:EnumerateActive() do PartySpec(m, f) end
		-- Party frames are pooled and set up again each time the party frame shows.
		hooksecurefunc(PartyFrame, "InitializePartyMemberFrames", function(self)
			for f in self.PartyMemberFramePool:EnumerateActive() do
				if not specs[f] then PartySpec(m, f) end
				if m.on then
					Dress(m, m.kit, specs[f])
					Dress(m, m.kit, specs[f.PetFrame])
				end
			end
		end)

		local function PlayerArt()
			if m.on then Refit(m, m.kit, specs[PlayerFrame]) end
		end
		hooksecurefunc("PlayerFrame_ToPlayerArt", PlayerArt)
		hooksecurefunc("PlayerFrame_ToVehicleArt", PlayerArt)

		-- These three run for every unit frame, and every rendered frame for a target's target.
		hooksecurefunc("UnitFrame_Update", function(frame)
			local s = m.on and specs[frame]
			if not s then return end
			ColorName(m.kit, s)
			ColorHealth(m, m.kit, s)
		end)
		hooksecurefunc("UnitFramePortrait_Update", function(frame)
			local s = m.on and specs[frame]
			if s and s.portrait and m.opt.portraits then Square(s, true) end
		end)
		hooksecurefunc("UnitFrameManaBar_UpdateType", function(bar)
			if m.on and bar and powers[bar] then Power(m.kit, bar) end
		end)
	end,

	Paint = function(m, kit)
		for _, s in ipairs(list) do Dress(m, kit, s) end
	end,

	-- Not tracked by the kit: our masks, the levels we moved and the portraits we redrew.
	Clear = function(m)
		for fill, mask in pairs(clipped) do fill:RemoveMaskTexture(mask) end
		wipe(clipped)
		for fontString, points in pairs(moved) do
			fontString:ClearAllPoints()
			for _, p in ipairs(points) do fontString:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
		end
		wipe(moved)
		for _, s in ipairs(list) do
			if s.emblem then
				s.portrait:SetAtlas(s.emblem)
				s.emblem = nil
			elseif s.squared and not m.on and UnitExists(s.frame.unit) and not AtlasOf(s.portrait) then
				SetPortraitTexture(s.portrait, s.frame.unit)   -- round again
			end
			s.squared = nil
		end
	end,
})
