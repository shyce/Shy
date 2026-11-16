-- Options page. The preview loops Feed.SAMPLE through the real lanes and motion beside a stand-in plate.

local ADDON, ns = ...
local T, Where, Feed = ns.T, ns.Where, ns.Feed
local UI, Skin = Shy.UI, Shy.Skin

local LEFT, RIGHT, COL = 24, 330, 270
local STRIP_W, STRIP_H = 622, 150    -- tall enough for a crit above the bar's name
local PLATE_W, PLATE_H = 124, 14     -- ShyPlates' housing at its defaults
local BRACKET = 3.5                  -- ShyPlates' target bracket extent
local NAME = 16                      -- ShyPlates' name extent above the housing
local BEAT = 0.55                    -- seconds between sample lines
local REST = 4                       -- idle beats between loops

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end

-- Preview

local strip, foe, me    -- the strip and its two lane pairs
local ticker, beat = nil, 0

local function BuildPreview(panel)
	strip = CreateFrame("Frame", nil, panel)
	strip:SetSize(STRIP_W, STRIP_H)
	strip:SetPoint("TOPLEFT", LEFT, -112)
	UI.Panel(strip, { brackets = false, line = false })
	strip:SetClipsChildren(true)

	local bar = CreateFrame("Frame", nil, strip)
	bar:SetSize(PLATE_W, PLATE_H)
	bar:SetPoint("BOTTOM", strip, "BOTTOMLEFT", 210, 34)
	UI.Skin(bar, { 0, 0, 0, 0.55 }, Skin.colors.edge)
	local fill = bar:CreateTexture(nil, "ARTWORK")
	Skin.Hatch(fill)
	fill:SetVertexColor(0.87, 0.24, 0.22)
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMLEFT", 2, 2)
	fill:SetWidth((PLATE_W - 4) * 0.62)
	local name = UI.Words(bar, UI.NameFont(11, "OUTLINE"), nil, { world = true, justify = "CENTER" })
	name:SetPoint("BOTTOM", bar, "TOP", 0, 3)
	name:SetText("Defias Pillager")
	foe = Where.Pair()
	foe.bar = bar

	-- Lanes placed as in the HUD box (Where.YOU).
	local YOU = Where.YOU
	local stand = CreateFrame("Frame", nil, strip)
	stand:SetSize(YOU.width * 0.62, YOU.height)
	stand:SetPoint("BOTTOM", strip, "BOTTOMLEFT", 478, 40)   -- harm to you falls: room under it
	local label = UI.Text(stand, "You", 11, false, UI.colors.dim)
	label:SetPoint("BOTTOM", 0, YOU.foot)
	me = Where.Pair()
	me.hurt.tone = "hurt"
	me.hurt.to, me.hurt.rel, me.hurt.x, me.hurt.y, me.hurt.justify, me.hurt.fan = stand, "BOTTOMLEFT", YOU.inward, YOU.foot, "RIGHT", -1
	me.heal.to, me.heal.rel, me.heal.x, me.heal.y, me.heal.justify, me.heal.fan = stand, "BOTTOMRIGHT", -YOU.inward, YOU.foot, "LEFT", 1
	me.gain = ns.Stage.Lane("gain")
	me.gain.to, me.gain.rel, me.gain.x, me.gain.y, me.gain.justify, me.gain.fan = stand, "TOP", 0, YOU.over, "CENTER", 1
	me.gain.parent = strip

	for _, pair in ipairs({ foe, me }) do
		pair.hurt.parent, pair.heal.parent = strip, strip
	end
end

local function RefreshPreview()
	Where.Around(foe, foe.bar, true, BRACKET, BRACKET, NAME)
	foe.crit.parent, foe.gain.parent = strip, strip
end

local function Play()
	beat = beat % (#Feed.SAMPLE + REST) + 1
	local line = Feed.SAMPLE[beat]
	if not (line and T.db.on) then return end
	if line[2] then
		if T.db.you then Feed.Sample(me, line) end
	elseif T.db.plates then
		Feed.Sample(foe, line)
	end
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Apply() end)
	local function On() return T.db.on end
	local function Plates() return T.db.on and T.db.plates end
	local function You() return T.db.on and T.db.you end

	local function Build()
		UI.PageHeader(panel, T)
		BuildPreview(panel)

		local switchLabel = UI.Text(panel, "Combat text", 15, true)
		switchLabel:SetPoint("TOPLEFT", LEFT, -274)
		local switch = group:Switch(panel, "Combat text", Get("on"), Set("on"),
			{ desc = "Turn off to go back to the default floating combat text. Your settings are kept." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		At(UI.Header(panel, "Show", COL), panel, LEFT, -306)
		At(group:Checkbox(panel, "On nameplates", Get("plates"), Set("plates"), { enabled = On,
			desc = "Damage and healing next to the nameplate of whatever takes it." }), panel, LEFT, -338)
		At(group:Checkbox(panel, "On you", Get("you"), Set("you"), { enabled = On,
			desc = "Damage you take on one side of your character, healing on the other." }), panel, LEFT, -364)
		At(group:Checkbox(panel, "Healer names", Get("healer"), Set("healer"), { enabled = You,
			desc = "Adds the healer's name after a heal on you, in their class color. Your own heals have no name." }), panel, LEFT + 16, -390)
		At(group:Checkbox(panel, "Misses, dodges and parries", Get("words"), Set("words"), { enabled = On,
			desc = "Shows Miss, Dodge, Parry, Block, Resist and Immune as small text." }), panel, LEFT, -416)
		At(group:Checkbox(panel, "Color by damage type", Get("schools"), Set("schools"), { enabled = On,
			desc = "White physical, orange fire, blue frost, green nature, violet shadow, pink arcane, gold holy. When off, hits are white and damage you take is red." }), panel, LEFT, -442)
		At(group:Checkbox(panel, "Bigger hits stand out", Get("weigh"), Set("weigh"), { enabled = On,
			desc = "A hit well over your usual one is drawn larger. Nothing is drawn smaller for it." }), panel, LEFT, -468)
		At(group:Checkbox(panel, "Theme lettering", Get("lettering"), Set("lettering"), { enabled = On,
			desc = "Numbers use your theme's font. Turn off for the plain rounded one." }), panel, LEFT, -494)

		At(group:Checkbox(panel, "Heals on your party", Get("friends"), Set("friends"), { enabled = On,
			desc = "Heals landing on your party or a friendly target show on their unit frame when there's no nameplate to put them by." }), panel, LEFT, -520)

		At(UI.Header(panel, "What you gain", COL), panel, LEFT, -562)
		At(group:Checkbox(panel, "Experience", Get("gainXP"), Set("gainXP"), { enabled = Plates,
			desc = "XP rises from the foe you just killed, in place of the game's own text. Where nameplates show the default numbers, XP is left to the game too." }), panel, LEFT, -594)
		At(group:Checkbox(panel, "Reputation", Get("gainRep"), Set("gainRep"), { enabled = On,
			desc = "Reputation you gain or lose, with the faction's name." }), panel, LEFT, -620)
		At(group:Checkbox(panel, "Coin you loot", Get("gainCoin"), Set("gainCoin"), { enabled = On,
			desc = "Money you pick up, by your character." }), panel, LEFT, -646)
		At(group:Checkbox(panel, "Skill ups", Get("gainSkill"), Set("gainSkill"), { enabled = On,
			desc = "A weapon or profession skill going up, with its new level." }), panel, LEFT, -672)
		At(group:Checkbox(panel, "Honor", Get("gainHonor"), Set("gainHonor"), { enabled = On,
			desc = "Honor from kills and awards." }), panel, LEFT, -698)

		At(UI.Header(panel, "Appearance", COL), panel, RIGHT, -306)
		At(group:Dropdown(panel, "Nameplate position", {
			{ value = "beside", text = "Beside the health bar" },
			{ value = "above",  text = "Above the name" },
		}, Get("place"), Set("place"), { width = COL, enabled = Plates,
			desc = "Beside keeps the name, your debuffs and combo points uncovered. Name-only nameplates always show numbers above." }), panel, RIGHT, -334)
		At(group:Dropdown(panel, "Animation", {
			{ value = "burst", text = "Punch in, fly off" },
			{ value = "calm",  text = "Calm column" },
		}, Get("motion"), Set("motion"), { width = COL, enabled = On,
			desc = "Punch: hits burst off the nameplate and hang there, crits slam in over it, heals float up and damage you take drops away. Calm: numbers stack in a column, newest at the bottom." }), panel, RIGHT, -390)
		At(group:Slider(panel, "Size", 0.7, 1.6, 0.05, Get("size"), Set("size"), { width = COL, format = Percent, enabled = On,
			desc = "Scales every number. A crit is twice the size of a hit, or about 1.5x with the calm animation." }), panel, RIGHT, -446)
		At(Shy.HUD.LayoutButton(panel, 190), panel, RIGHT, -500)

		At(UI.Header(panel, "In a group", COL), panel, RIGHT, -542)
		local WHOSE = {
			{ value = "all",  text = "Everyone's hits" },
			{ value = "mine", text = "Only yours" },
			{ value = "game", text = "Default numbers" },
		}
		At(group:Dropdown(panel, "In a party", WHOSE, Get("party"), Set("party"), { width = COL, enabled = Plates,
			desc = "The game doesn't say whose hit is whose. Only yours shows the hits that land as you swing or cast, with your damage over time: close, not exact, and your pet's come from the default numbers. Default numbers are exact but plain." }), panel, RIGHT, -570)
		At(group:Dropdown(panel, "In a raid", WHOSE, Get("raid"), Set("raid"), { width = COL, enabled = Plates,
			desc = "The same choice for a raid, where everyone's hits would be a lot to look at." }), panel, RIGHT, -626)
		At(group:Checkbox(panel, "Same font on default numbers", Get("gameFont"), Set("gameFont"),
			{ desc = "The default combat text uses the same rounded font. Applies the next time you log in." }), panel, RIGHT, -682)
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			RefreshPreview()
		end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		RefreshPreview()
		beat = 0
		if not ticker then ticker = C_Timer.NewTicker(BEAT, Play) end
	end)
	panel:SetScript("OnHide", function()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
	end)

	function panel:OnDefault()
		local cvars = T.db.cvars   -- saved CVar values must survive a reset
		T:ResetDB()
		T.db.cvars = cvars
		ns.Apply()
	end

	return panel
end
