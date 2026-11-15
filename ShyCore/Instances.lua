-- Shy.Instances: the dungeons and raids the Group Finder lists, for every addon that shows one.
--   Shy.Instances.List()            each as { map, name, kind ("dungeon" | "raid"), low, high, players,
--                                   file (its loading screen's, 0 for none), cut = { left, top, right, bottom } },
--                                   dungeons by level, then raids
--   Shy.Instances.ByMap(map)        one of them, by its instance map
--   Shy.Instances.Theme(map)        its own color and look: { color = { r, g, b }, look = "forged" }, or nil
--   Shy.Instances.Levels(one)       "17-26", and its lowest level
--   Shy.Instances.Card(parent, width, one)
--                                   its picture card, 2:1: the game's loading screen cut to the card, the name
--                                   over a line of words on a dark band at its foot, a tick at the band's right.
--                                   A Button with .picture, .band, .name, .levels, .check and .instance; the
--                                   owner says what it shows (card:Say(words), card:Lit(on, dimmed)).

local Shy = Shy
local UI = Shy.UI
local C = UI.colors

local Instances = {}
Shy.Instances = Instances

local BAND = 44          -- the glass at a picture's foot: the name over the levels
local CHECK = 14         -- the tick at the band's right

-- Each one's color and look, by instance map.
local THEMES = {
	[389] = { color = { 0.95, 0.42, 0.14 }, look = "forged" },     -- Ragefire Chasm: lava under the city
	[3065] = { color = { 0.90, 0.70, 0.28 }, look = "forged" },    -- The Hall of Thanes: dwarven gold
	[2999] = { color = { 0.52, 0.78, 0.32 }, look = "eclipse" },   -- Ruins of Lordaeron: the blight
	[43] = { color = { 0.30, 0.80, 0.50 }, look = "clear" },       -- Wailing Caverns: venom
	[36] = { color = { 0.82, 0.20, 0.17 }, look = "riveted" },     -- The Deadmines: Defias red, mine iron
	[33] = { color = { 0.60, 0.45, 0.90 }, look = "eclipse" },     -- Shadowfang Keep: moonlight
	[48] = { color = { 0.18, 0.66, 0.74 }, look = "clear" },       -- Blackfathom Deeps: deep water
	[34] = { color = { 0.66, 0.68, 0.72 }, look = "steel" },       -- The Stockade: prison iron
	[2998] = { color = { 0.86, 0.62, 0.30 }, look = "riveted" },   -- Excavation Site: lantern light
	[2959] = { color = { 0.82, 0.38, 0.88 }, look = "eclipse" },   -- City of Dalaran: the arcane
	[90] = { color = { 0.68, 0.88, 0.20 }, look = "riveted" },     -- Gnomeregan: radiation
	[47] = { color = { 0.78, 0.54, 0.24 }, look = "forged" },      -- Razorfen Kraul: thorns and earth
	[189] = { color = { 0.86, 0.16, 0.20 }, look = "steel" },      -- Scarlet Monastery: the crusade's red
	[129] = { color = { 0.56, 0.62, 0.48 }, look = "eclipse" },    -- Razorfen Downs: bone and rot
	[70] = { color = { 0.84, 0.68, 0.40 }, look = "forged" },      -- Uldaman: titan stone
	[209] = { color = { 0.94, 0.76, 0.34 }, look = "clear" },      -- Zul'Farrak: sand
	[349] = { color = { 0.74, 0.44, 0.84 }, look = "clear" },      -- Maraudon: crystal
	[109] = { color = { 0.24, 0.72, 0.42 }, look = "eclipse" },    -- Sunken Temple: jade
	[230] = { color = { 0.96, 0.46, 0.12 }, look = "forged" },     -- Blackrock Depths: the forge
	[429] = { color = { 0.50, 0.76, 0.30 }, look = "clear" },      -- Dire Maul: overgrown halls
	[229] = { color = { 0.90, 0.30, 0.14 }, look = "riveted" },    -- Blackrock Spire: ember
	[289] = { color = { 0.52, 0.80, 0.70 }, look = "eclipse" },    -- Scholomance: ghost light
	[329] = { color = { 0.92, 0.52, 0.18 }, look = "steel" },      -- Stratholme: the burning city
	[531] = { color = { 0.80, 0.66, 0.30 }, look = "eclipse" },    -- Ahn'Qiraj Temple: old gold
	[509] = { color = { 0.92, 0.74, 0.36 }, look = "clear" },      -- Ruins of Ahn'Qiraj: sand
	[469] = { color = { 0.86, 0.18, 0.16 }, look = "forged" },     -- Blackwing Lair: dragon red
	[409] = { color = { 0.98, 0.50, 0.10 }, look = "forged" },     -- Molten Core: fire
	[533] = { color = { 0.44, 0.74, 0.90 }, look = "steel" },      -- Naxxramas: frost
	[249] = { color = { 0.70, 0.30, 0.86 }, look = "forged" },     -- Onyxia's Lair: the broodmother
	[309] = { color = { 0.30, 0.76, 0.36 }, look = "clear" },      -- Zul'Gurub: jungle
}

local list, byMap

local function Read()
	list, byMap = {}, {}
	for _, record in ipairs(Shy.InstanceData or {}) do
		local f = {}
		for field in (record .. "^"):gmatch("([^%^]*)%^") do f[#f + 1] = field end
		local one = { map = tonumber(f[1]), name = f[2], kind = f[3], low = tonumber(f[4]) or 0, high = tonumber(f[5]) or 0,
			players = tonumber(f[6]) or 0, file = tonumber(f[7]) or 0 }
		if f[8] then one.cut = { tonumber(f[8]), tonumber(f[9]), tonumber(f[10]), tonumber(f[11]) } end
		list[#list + 1] = one
		byMap[one.map] = one
	end
end

function Instances.List()
	if not list then Read() end
	return list
end

function Instances.ByMap(map)
	if not list then Read() end
	return map and byMap[map] or nil
end

function Instances.Theme(map)
	return map and THEMES[map] or nil
end

function Instances.Levels(one)
	local low, high = one.low, one.high
	return high > 0 and high ~= low and (low .. "-" .. high) or tostring(low), low
end

-- The picture of one on a texture: its loading screen cut 2:1, or a plain plate where this build has none.
function Instances.Picture(texture, one)
	if one.file > 0 and one.cut then
		texture:SetTexture(one.file)
		texture:SetTexCoord(one.cut[1], one.cut[3], one.cut[2], one.cut[4])
		return true
	end
	UI.Paint(texture, C.fill, 0.5)
	return false
end

function Instances.Card(parent, width, one)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, math.floor(width / 2 + 0.5))
	UI.Skin(b)
	b.picture = b:CreateTexture(nil, "ARTWORK")
	b.picture:SetPoint("TOPLEFT", 1, -1)
	b.picture:SetPoint("BOTTOMRIGHT", -1, 1)
	Instances.Picture(b.picture, one)
	b.band = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.band:SetPoint("BOTTOMLEFT", 1, 1)
	b.band:SetPoint("BOTTOMRIGHT", -1, 1)
	b.band:SetHeight(BAND + 16)
	b.band:SetColorTexture(1, 1, 1, 1)
	b.band:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.86), CreateColor(0, 0, 0, 0))
	b.name = UI.Text(b, one.name, 13, true, C.head)
	b.name:SetPoint("BOTTOMLEFT", 10, 21)
	b.name:SetPoint("RIGHT", -(CHECK + 16), 0)
	b.name:SetWordWrap(false)
	b.levels = UI.Text(b, "", 11, false, C.dim)
	b.levels:SetPoint("BOTTOMLEFT", 10, 7)
	b.levels:SetPoint("RIGHT", -(CHECK + 16), 0)
	b.levels:SetWordWrap(false)
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetSize(CHECK, CHECK)
	b.check:SetPoint("BOTTOMRIGHT", -10, 14)
	Shy.Hover.Glyph(b.check, "check", CHECK)
	UI.Tint(b.check, C.good)
	b.check:Hide()
	b.instance = one

	function b:Say(words)
		self.levels:SetText(words or "")
	end
	-- on: in color with its tick; dimmed: nothing to choose here
	function b:Lit(on, dimmed, ticked)
		self.on, self.dimmed = on, dimmed
		self:SetAlpha(dimmed and 0.45 or 1)
		self.check:SetShown(ticked == nil and on or ticked == true)
		self.picture:SetDesaturated(not on)
		UI.SetBorder(self, (on or self.hover) and C.hot or C.border)
		UI.Ink(self.name, on and C.head or C.text)
		UI.Ink(self.levels, on and C.text or C.dim)
	end
	return b
end
