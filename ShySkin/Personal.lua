-- The personal resource display (PersonalResourceDisplayFrame): health and power bars on a panel.
-- Nothing is measured or moved, so Edit Mode's size, scale and fade settings keep working.
-- Blizzard sets the bars' colors and never swaps their art, so they are painted once.

local ADDON, ns = ...

local TRACK = "ui-hud-cooldownmanager-bar-bg"   -- atlas of Blizzard's track behind each bar
local OUT = 2                                   -- frame outset, as CastingBarFrame.xml's Border
local PANEL = { -5, -5, -5, -5 }

local tracks = setmetatable({}, { __mode = "k" })   -- bar -> Blizzard's track texture

-- Blizzard's track is unnamed: found once by its atlas.
local function Track(bar)
	local track = tracks[bar]
	if track ~= nil then return track or nil end
	track = false
	for _, region in ipairs({ bar:GetRegions() }) do
		if region:IsObjectType("Texture") then
			local atlas = region:GetAtlas()
			if type(atlas) == "string" and atlas:lower() == TRACK then
				track = region
				break
			end
		end
	end
	tracks[bar] = track
	return track or nil
end

-- In ShyDock's cockpit the bars get no panel and no frame of their own: the cockpit's box is the panel,
-- and the display is one block there, framed as one by the cockpit with the gaps as its dividers.
local function InCockpit()
	local dock = Shy.addons.Dock
	return dock ~= nil and dock.CockpitHolds ~= nil and dock:CockpitHolds("display") == true
end

-- A bar's numbers sized to the bar in the cockpit, where the bars stand at their planned heights (15 and
-- 10) a seam apart: at the font's own size they stood as tall as the power bar and read as touching
-- its edges. Never under NUMBER_LEAST. The size is a whole number of screen pixels at the bar's scale.
local NUMBER_OF_BAR, NUMBER_LEAST = 0.7, 8

-- A line's box is as tall as its font, with the baseline at the font's ascent share of it (1011 of
-- 1011 + 353), and digits stand 716 over the baseline: centred on the bar by their box, the digits sat
-- this share of the size high, the power bar's against its top. Each number goes down by it, in whole pixels.
local DIGIT_LIFT = 0.5 - (1011 / 1364 - 0.716 / 2)

-- Screen pixels to a unit of the bar.
local function Pixels(bar)
	local scale = bar:GetEffectiveScale()
	local _, physical = GetPhysicalScreenSize()
	if issecretvalue(scale) or not (physical and physical > 0) then return end
	return scale * physical / 768
end

local function NumberSize(bar, ppu)
	local h = bar:GetHeight()
	if h == nil or issecretvalue(h) or h <= 0 then return end
	local pixels = math.max(math.floor(NUMBER_LEAST * ppu + 0.5), math.floor(h * ppu * NUMBER_OF_BAR))
	return pixels / ppu
end

-- The number at the side Blizzard put it, lowered so its digits stand on the bar's middle.
local function Settle(kit, fontString, bar, ppu)
	local point, _, relativePoint, x = fontString:GetPoint(1)
	local _, size = fontString:GetFont()
	if not point or issecretvalue(x) or not size then return end
	local drop = math.floor(DIGIT_LIFT * size * ppu + 0.5) / ppu
	kit:Place(fontString, nil, nil, { point, bar, relativePoint, x, -drop })
end

local function PaintBar(kit, bar, framed)
	if not bar then return end
	kit:Hide(Track(bar))
	-- The track goes under everything Blizzard draws on the bar, heal predictions included.
	local set = kit:Bar(bar)
	set.track:SetDrawLayer("BACKGROUND", 1)
	if framed then kit:Frame(bar, { x = -OUT, y = -OUT }) end
	local ppu = Pixels(bar)
	local size = ppu and not framed and NumberSize(bar, ppu) or nil
	for _, fontString in ipairs({ bar.TextString, bar.LeftText, bar.RightText }) do
		ns.Number(kit, fontString)
		if size and fontString then kit:Font(fontString, Shy.FONT_ROUNDED, size, "OUTLINE") end
		if ppu and fontString then Settle(kit, fontString, bar, ppu) end
	end
end

-- Your health in the color picked (Shy.Skin.HealthRGB), exactly as your frame draws it when ShyFrames is on
-- (its HealthFill). The game colors the bar in UpdateHealthColor; after it, the fill texture (a region) is
-- tinted, the bar left alone.
local hooked = false
local function Tone()
	local bar = PersonalResourceDisplayFrame.HealthBarsContainer.healthBar
	local fill = bar:GetStatusBarTexture()
	if not fill then return end
	local frames = Shy.addons.Frames
	if frames and frames.HealthFill then
		local r, g, b = frames:HealthFill()
		fill:SetVertexColor(r, g, b)
	else
		fill:SetVertexColor(Shy.Skin.HealthRGB())
	end
end

local m = ns.Module({
	id = "personal",
	title = "Personal resource display",
	desc = "The health and power bars under your character match your cast bar.",
	group = "screen",
	words = "health mana energy rage",

	Ready = function()
		return PersonalResourceDisplayFrame ~= nil
	end,

	Paint = function(m, kit)
		local f = PersonalResourceDisplayFrame
		local alone = not InCockpit()
		if alone then kit:Plate(f, { panel = true, brackets = false, inset = PANEL, hud = true }) end
		PaintBar(kit, f.HealthBarsContainer.healthBar, alone)
		PaintBar(kit, f.PowerBar, alone)
		PaintBar(kit, f.AlternatePowerBar, alone)
		if not hooked then
			hooked = true
			hooksecurefunc(f, "UpdateHealthColor", function()
				if m.on then Tone() end
			end)
		end
		Tone()
	end,
})

-- The pick changed, or the accent it may be.
Shy:On("SHY_HEALTH", function()
	if m.on then Tone() end
end)
Shy:On("SHY_THEME", function()
	if m.on and Shy.Skin.HealthColor() == "accent" then Tone() end
end)

-- The cockpit moved or changed shape: the bars are dressed again only if it took the display in or let it go.
local held
Shy:On("SHY_COCKPIT", function()
	if not m.on then return end
	local now = InCockpit()
	if now == held then return end
	held = now
	m:Refresh()
end)
