-- Cast bars: player, gamepad, pet, and the spell bars under target, focus and boss frames (CastingBarMixin).
-- Blizzard swaps the fill's art by state in UpdateBarFillTexture (bar.barType); the hatch goes on after it.
-- barType is secret for other units in instances: then the fill is left as Blizzard set it.
-- Nothing is moved or measured: the target's spell bar is anchored to its aura row, whose size is restricted.
-- In ShyDock's cockpit the player's bar gets no panel and its icon is shown (Dock:CockpitHolds, Dock:CockpitCast).

local ADDON, ns = ...
local B, UI, Skin, Theme = Shy.Brand, Shy.UI, Shy.Skin, Shy.Theme
local C = Skin.colors

-- Panel insets by bar.look: { left, top, right, bottom }.
local PANELS = {
	below = { -5, -5, -5, -17 },        -- "CLASSIC": name under the bar
	withIcon = { -29, -6, -5, -20 },    -- no look: name under the bar, 20 px icon and shield at the left
	beside = { -26, -6, -5, -6 },       -- "UNITFRAME": name on the bar, 16 px icon beside it
}
local LOOKS = { CLASSIC = "below", UNITFRAME = "beside" }

-- Blizzard's spark and glow textures, tinted to the accent.
local LIGHTS = {
	"Spark", "Flash", "StandardGlow", "CraftGlow", "EnergyGlow", "Flakes01", "Flakes02", "Flakes03",
	"Shine", "BaseGlow", "WispGlow", "Sparkles01", "Sparkles02",
}

local hooked = {}   -- bars already hooked
local tiles = {}    -- bar -> its icon's slot
local full = setmetatable({}, { __mode = "k" })   -- bar -> Blizzard last set the finished-cast art
local hatched = setmetatable({}, { __mode = "k" })   -- fills with the tiling hatch on them
local docked = setmetatable({}, { __mode = "k" })    -- bar -> in ShyDock's cockpit, where we show its icon
local TEXT_IN = 4    -- text inset on a docked bar

-- Returns the icon size and its gap from the bar while ShyDock's cockpit holds the bar, else nil.
local function Docked(bar)
	if bar ~= PlayerCastingBarFrame then return nil end
	local dock = Shy.addons.Dock
	if dock == nil or dock.CockpitHolds == nil or dock.CockpitCast == nil or dock:CockpitHolds("cast") ~= true then return nil end
	return dock:CockpitCast()
end

local function Bars()
	local list = { PlayerCastingBarFrame, GamepadPlayerCastingBarFrame, PetCastingBarFrame, TargetFrameSpellBar, FocusFrameSpellBar }
	for _, frame in ipairs(BossTargetFrameContainer.BossTargetFrames) do list[#list + 1] = frame.spellbar end
	return list
end

-- Spell names are localized: a font family.
local function LabelFont(size)
	return UI.TitleFont(size, "OUTLINE")
end

-- Cast times carry a localized letter ("2.4 s"): a font family.
local function TimeFont(size)
	return UI.NameFont(size, "OUTLINE")
end

local function PaintText(kit, fontString, font, color)
	if not fontString then return end
	local _, size = fontString:GetFont()
	kit:FontObject(fontString, font(math.floor(size + 0.5)))
	kit:Text(fontString, color)
end

-- The bar's state, or nil when it is secret.
local function State(bar)
	local state = bar.barType
	if issecretvalue(state) then return nil end
	return state or CastingBarType.Standard
end

local function FillColor(state, finished)
	local c
	if state == CastingBarType.Interrupted then
		c = UI.colors.bad
	elseif state == CastingBarType.Uninterruptable then
		c = C.idle
	elseif finished then
		c = Theme.light
	elseif state == CastingBarType.Channel then
		return B.Ramp(0.8)
	else
		return Theme.Accent()
	end
	return c[1], c[2], c[3]
end

-- The hatch tiles; Blizzard's fill art must not, so tiling is switched off before handing a fill back.
local function Unhatch(bar)
	local fill = bar:GetStatusBarTexture()
	if fill and hatched[fill] then
		hatched[fill] = nil
		fill:SetHorizTile(false)
	end
end

-- An empowered cast has no fill (Blizzard draws its stages), so it is left alone.
local function PaintFill(bar)
	local state = State(bar)
	if not state or state == CastingBarType.Empowered then
		Unhatch(bar)
		return
	end
	Skin.HatchBar(bar)
	local fill = bar:GetStatusBarTexture()
	Skin.Hatch(fill)
	hatched[fill] = true
	bar:SetStatusBarColor(FillColor(state, full[bar]))
end

-- Sets what UpdateBarFillTexture would for the bar's current state.
local function BlizzardFill(bar)
	Unhatch(bar)
	local state = State(bar)
	if not state or state == CastingBarType.Empowered then return end
	local info = CastingBarTypeInfo[state]
	bar:SetStatusBarTexture(full[bar] and info.full or info.filling)
	bar:SetStatusBarColor(1, 1, 1)
end

-- The slot's frame follows the icon's visibility.
local function ShowIcon(bar)
	-- Blizzard hides the player bar's icon; the cockpit shows it.
	if docked[bar] then bar.Icon:Show() end
	local tile = tiles[bar]
	if not tile then return end
	local shown = bar.Icon:IsShown()
	tile:Bare(issecretvalue(shown) or not shown)
end

local function HookBar(m, bar)
	if hooked[bar] then return end
	hooked[bar] = true
	hooksecurefunc(bar, "UpdateBarFillTexture", function(self, finished)
		full[self] = finished and true or nil
		if m.on then PaintFill(self) end
	end)
	hooksecurefunc(bar, "UpdateIconShown", function(self)
		if m.on then ShowIcon(self) end
	end)
	-- SetLook changes the layout and resets the name's font.
	hooksecurefunc(bar, "SetLook", function()
		if m.on then m:Refresh() end
	end)
end

local function PaintBar(m, kit, bar)
	HookBar(m, bar)
	local side, gap = Docked(bar)
	local look = bar.look
	local panel = look == nil and "withIcon" or LOOKS[look]
	if not side and not panel then return end   -- unknown look

	kit:Hide(bar.TextBorder)
	if side then
		-- In the cockpit the bar is a row of the display's block: the cockpit frames the row (its steel round
		-- the picture and the bar, a hairline between), so the bar has no border and the picture no slot of
		-- its own; the picture is a square of the row's height, its dark rim cropped away.
		docked[bar] = true
		kit:Place(bar.Icon, side, side, { "RIGHT", bar, "LEFT", -gap, 0 })
		kit:Crop(bar.Icon, 0.08, 0.92, 0.08, 0.92)
		kit:Place(bar.Text, 0, nil, { "LEFT", bar, "LEFT", TEXT_IN, 0 })
		kit:Place(bar.CastTimeText, nil, nil, { "RIGHT", bar, "RIGHT", -TEXT_IN, 0 })
	else
		docked[bar] = nil
		kit:Plate(bar, { key = panel, panel = true, brackets = false, inset = PANELS[panel], hud = true })
	end
	-- Blizzard's background reaches a pixel past some bars; the track is exactly the bar.
	kit:Art(bar.Background, C.well)
	kit:Track(bar)
	if side then
		kit:Hide(bar.Border)
	else
		kit:Art(bar.Border, Skin.FRAME, { slice = Skin.FRAME_SLICE, color = C.metal })
	end
	PaintFill(bar)

	PaintText(kit, bar.Text, LabelFont, C.text)
	PaintText(kit, bar.CastTimeText, TimeFont, UI.colors.text)

	if side then
		tiles[bar] = nil
	else
		tiles[bar] = kit:Tile(bar, { to = bar.Icon, x = -1, y = -1, well = false, hover = false, icon = bar.Icon })
	end
	ShowIcon(bar)

	for _, key in ipairs(LIGHTS) do
		local light = bar[key]
		if light then kit:Tint(light, Theme.light) end
	end
end

local m = ns.Module({
	id = "castbars",
	title = "Cast bars",
	desc = "The game's cast bars fill in your color. A cast you can't interrupt is gray, and an interrupted one is red.",
	group = "screen",
	words = "casting spell",

	Paint = function(m, kit)
		for _, bar in ipairs(Bars()) do PaintBar(m, kit, bar) end
	end,

	-- The kit doesn't track the fill or a docked bar's icon: both are restored here.
	Clear = function()
		for _, bar in ipairs(Bars()) do
			BlizzardFill(bar)
			if docked[bar] then
				docked[bar] = nil
				bar.Icon:SetShown(bar:ShouldIconBeShown() == true)
			end
		end
	end,
})

-- The cockpit moved or changed shape: the bars are dressed again only if it took the cast bar in or let it go,
-- or the icon's size there changed. Its moving alone changes nothing they wear.
local held
Shy:On("SHY_COCKPIT", function()
	if not m.on then return end
	local size, gap = Docked(PlayerCastingBarFrame)
	local now = size and (size .. ":" .. tostring(gap)) or false
	if now == held then return end
	held = now
	m:Refresh()
end)
