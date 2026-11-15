-- The light round the screen, worn in the look you picked for the family (Theme.Look), every edge alike:
--   forged    a solid rim with the family's brackets at the corners
--   steel     (Glass) a fine rim, your light along the top and the foot (the hover's light art)
--   clear     (Frosted) an etched pale line, the color a hair inside it
--   eclipse   a bright line with a wide halo falling in from it
--   stitched  a seam of stitches sewn in from a dark welt
--   riveted   a metal hairline, the color inside it, a rivet in each corner
-- Any other look wears the forged make. Under every look: a short dark fall, so the light reads on snow, and
-- the light's own fall in its color (normal blending, not added light).
--
--   Light.Setup()                   Light.Dress()   (again on SHY_THEME: the look may have changed)
--   Light.Color(r, g, b)            only when it changed
--   Light.Strength(fall, rim, shade)   each layer's alpha
--   Light.Gate(alpha)               over all of them: may be a secret the game evaluated (your rage)
--   Light.Shown(on)

local ADDON, ns = ...
local UI, Skin = Shy.UI, Shy.Skin
local ART = UI.LookArt

local L = {}
ns.Light = L

local CORNER = 64            -- the fall's corner pieces' size on screen (the halo's: HALO times it)
local HALO = 1.8
local EDGE_U = 1 - 1 / 128   -- the corner art's last column (and row): the edge's fall, stretched between corners
local BRACKET = 2            -- the forged corners: the family's bracket art at this many times its one size
local RIVET = 9              -- a rivet's size on screen

local root, gate, shadeF, fallF, rimF
local shade, fall = {}, {}
local parts = {}             -- look -> { regions = {}, colored = {} }
local worn                   -- the look dressed now
local color = { -1, -1, -1 }

-- Four corners and four edges of one corner art, laid round the frame.
local function Fall(parent, file, layer, list)
	local corners = {}
	local function Corner(point, l, r, t, b)
		local tex = parent:CreateTexture(nil, layer)
		tex:SetTexture(file)
		tex:SetTexCoord(l, r, t, b)
		tex:SetPoint(point)
		tex:SetSize(CORNER, CORNER)
		list[#list + 1] = tex
		corners[#corners + 1] = tex
		return tex
	end
	local tl = Corner("TOPLEFT", 0, 1, 0, 1)
	local tr = Corner("TOPRIGHT", 1, 0, 0, 1)
	local bl = Corner("BOTTOMLEFT", 0, 1, 1, 0)
	local br = Corner("BOTTOMRIGHT", 1, 0, 1, 0)
	local function Edge(a, aTo, b, bTo, l, r, t, bt)
		local tex = parent:CreateTexture(nil, layer)
		tex:SetTexture(file)
		tex:SetTexCoord(l, r, t, bt)
		tex:SetPoint("TOPLEFT", a, aTo)
		tex:SetPoint("BOTTOMRIGHT", b, bTo)
		list[#list + 1] = tex
	end
	Edge(tl, "TOPRIGHT", tr, "BOTTOMLEFT", EDGE_U, 1, 0, 1)         -- top
	Edge(bl, "TOPRIGHT", br, "BOTTOMLEFT", EDGE_U, 1, 1, 0)         -- foot
	Edge(tl, "BOTTOMLEFT", bl, "TOPRIGHT", 0, 1, EDGE_U, 1)         -- left
	Edge(tr, "BOTTOMLEFT", br, "TOPRIGHT", 1, 0, EDGE_U, 1)         -- right
	return corners
end

local fallCorners

-- A look's regions, made once.
local function Kit(look)
	local kit = { regions = {}, colored = {} }
	parts[look] = kit
	local function Add(region, colored)
		kit.regions[#kit.regions + 1] = region
		if colored then kit.colored[#kit.colored + 1] = region end
		region:Hide()
		return region
	end
	-- A line `width` thick, `inset` in from the screen's edges, as four strips (the sides between the top and
	-- the foot, so no corner is drawn twice).
	local function Lines(width, inset, colored, layer, sub)
		local strips = {}
		for i = 1, 4 do
			local t = Add(rimF:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0), colored)
			t:SetColorTexture(1, 1, 1)
			strips[i] = t
		end
		local top, foot, left, right = strips[1], strips[2], strips[3], strips[4]
		top:SetPoint("TOPLEFT", inset, -inset)
		top:SetPoint("TOPRIGHT", -inset, -inset)
		top:SetHeight(width)
		foot:SetPoint("BOTTOMLEFT", inset, inset)
		foot:SetPoint("BOTTOMRIGHT", -inset, inset)
		foot:SetHeight(width)
		left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
		left:SetPoint("BOTTOMLEFT", foot, "TOPLEFT")
		left:SetWidth(width)
		right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
		right:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
		right:SetWidth(width)
		return strips
	end
	local function Tone(strips, r, g, b, a)
		for _, t in ipairs(strips) do t:SetVertexColor(r, g, b, a) end
	end

	if look == "steel" then
		Lines(1, 0, true)
		-- The hover's light, along the top and (turned over) the foot.
		for _, foot in ipairs({ false, true }) do
			local light = Add(rimF:CreateTexture(nil, "ARTWORK", nil, 1), true)
			light:SetTexture(ART.LIGHT)
			light:SetBlendMode("ADD")
			light:SetHeight(ART.LIGHT_H * 1.5)
			if foot then
				light:SetTexCoord(0, 1, 1, 0)
				light:SetPoint("BOTTOMLEFT", ART.LIGHT_IN, 0)
				light:SetPoint("BOTTOMRIGHT", -ART.LIGHT_IN, 0)
			else
				light:SetPoint("TOPLEFT", ART.LIGHT_IN, 0)
				light:SetPoint("TOPRIGHT", -ART.LIGHT_IN, 0)
			end
		end
	elseif look == "clear" then
		Tone(Lines(1, 0, false), 1, 1, 1, 0.6)          -- the etched edge
		Lines(1, 2, true)
	elseif look == "eclipse" then
		Lines(1, 0, true)
		Tone(Lines(1, 1, false), 0, 0, 0, 0.5)          -- the slab's dark hairline inside the light
	elseif look == "stitched" then
		Tone(Lines(2, 0, false), 0.02, 0.02, 0.02, 0.75)   -- the welt
		Lines(1, 2, true)                                    -- a line of your color inside it
	elseif look == "riveted" then
		local metal = Skin.colors.metal
		Tone(Lines(1, 0, false), metal[1], metal[2], metal[3], 0.9)
		Lines(1, 1, true)
		local RC, s = ART.RIVET_CELLS, 12                  -- the cell drawn for a rivet 12 pixels across
		local u = (s - RC.least) * (s + RC.least + 1) / 2
		local v0 = 3 * (RC.most + 1)                        -- the row whose middle sits on a texel both ways
		for _, def in ipairs(UI.BRACKETS) do
			local t = Add(rimF:CreateTexture(nil, "OVERLAY"), false)
			t:SetTexture(ART.RIVET)
			t:SetTexCoord(u / RC.w, (u + s) / RC.w, v0 / RC.h, (v0 + s) / RC.h)
			t:SetSize(RIVET, RIVET)
			local x = def[1]:find("LEFT") and 4 or -4
			local y = def[1]:find("TOP") and -4 or 4
			t:SetPoint(def[1], x, y)
		end
	else
		-- Forged: a solid rim, the family's brackets at the corners.
		Lines(2, 0, true)
		for _, def in ipairs(UI.BRACKETS) do
			local t = Add(rimF:CreateTexture(nil, "OVERLAY"), true)
			t:SetTexture(UI.BRACKET)
			t:SetTexCoord(def[2], def[3], def[4], def[5])
			t:SetSize(UI.BRACKET_SIZE * BRACKET, UI.BRACKET_SIZE * BRACKET)
			t:SetPoint(def[1])
		end
	end
	return kit
end

local function Known(look)
	return look == "steel" or look == "clear" or look == "eclipse" or look == "stitched" or look == "riveted"
end

function L.Dress()
	if not root then return end
	local look = Shy.Theme.Look()
	if not Known(look) then look = "forged" end
	if look ~= worn then
		if worn and parts[worn] then
			for _, region in ipairs(parts[worn].regions) do region:Hide() end
		end
		local kit = parts[look] or Kit(look)
		for _, region in ipairs(kit.regions) do region:Show() end
		worn = look
		for _, corner in ipairs(fallCorners) do
			local size = look == "eclipse" and CORNER * HALO or CORNER
			corner:SetSize(size, size)
		end
	end
	-- The color is laid again on the new look's regions.
	color[1] = -1
end

function L.Look()
	return worn
end

function L.Color(r, g, b)
	-- In the screen's 8-bit steps: a glide that moves nothing visible sets nothing.
	local q = math.floor
	if q(r * 255) == color[1] and q(g * 255) == color[2] and q(b * 255) == color[3] then return end
	color[1], color[2], color[3] = q(r * 255), q(g * 255), q(b * 255)
	for _, tex in ipairs(fall) do tex:SetVertexColor(r, g, b) end
	for _, region in ipairs(parts[worn].colored) do region:SetVertexColor(r, g, b) end
end

local alphas = { -1, -1, -1 }
function L.Strength(fallA, rimA, shadeA)
	local q = function(a) return math.floor(a * 255 + 0.5) end
	if q(fallA) ~= alphas[1] then alphas[1] = q(fallA); fallF:SetAlpha(fallA * (worn == "eclipse" and 0.75 or 0.6)) end
	if q(rimA) ~= alphas[2] then alphas[2] = q(rimA); rimF:SetAlpha(rimA) end
	if q(shadeA) ~= alphas[3] then alphas[3] = q(shadeA); shadeF:SetAlpha(shadeA) end
end

-- How much of the light comes through, over the rest: a plain number, or the game's own answer handed on as
-- it is (your rage through a curve, which the game may keep secret in a fight).
function L.Gate(alpha)
	gate:SetAlpha(alpha)
end

function L.Shown(on)
	root:SetShown(on)
end

-- The layers, for the tests: the fall's textures and the root.
function L.Parts()
	return { root = root, gate = gate, fall = fall, shade = shade, look = worn and parts[worn] }
end

function L.Setup(onUpdate)
	root = CreateFrame("Frame", nil, UIParent)
	root:SetAllPoints()
	root:SetFrameStrata("BACKGROUND")
	root:SetFrameLevel(0)
	root:EnableMouse(false)
	root:Hide()
	gate = CreateFrame("Frame", nil, root)
	gate:SetAllPoints()
	shadeF = CreateFrame("Frame", nil, gate)
	shadeF:SetAllPoints()
	fallF = CreateFrame("Frame", nil, gate)
	fallF:SetAllPoints()
	rimF = CreateFrame("Frame", nil, gate)
	rimF:SetAllPoints()
	Fall(shadeF, ns.MEDIA .. "EdgeShade", "BACKGROUND", shade)
	for _, tex in ipairs(shade) do tex:SetVertexColor(0, 0, 0) end
	fallCorners = Fall(fallF, ns.MEDIA .. "EdgeSoft", "BORDER", fall)
	root:SetScript("OnUpdate", onUpdate)
	L.Dress()
	Shy:On("SHY_THEME", L.Dress)
end
