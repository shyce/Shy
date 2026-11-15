-- Options: a live preview and three tabs. The preview uses real plates from Plate.lua,
-- fed by `Fake`, a reader (see Units.lua) over a sample table per plate.

local ADDON, ns = ...
local T, L, U, P = ns.T, ns.Layout, ns.Units, ns.Plate
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270
local STRIP_W, STRIP_H = 622, 172

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end
local function Whole(v) return tostring(math.floor(v + 0.5)) end

-- Preview reader: a plate's unit is a table

local Fake = {}

function Fake.Exists(unit) return unit == "target" or type(unit) == "table" end
function Fake.Name(unit) return unit.name, false end
function Fake.IsPlayer(unit) return unit.class ~= nil end
function Fake.CanAttack(unit) return unit.stance ~= "friendly" end
function Fake.Stance(unit) return unit.stance end
function Fake.Tapped(unit) return unit.tapped == true end
function Fake.Crest(unit) return unit.crest end
function Fake.Level(unit) return unit.level or 0 end
Fake.LevelColor = U.LevelColor
function Fake.Rank(unit) return unit.rank end
function Fake.ClassColor(unit)
	local color = C_ClassColor.GetClassColor(unit.class)
	if color then return color.r, color.g, color.b end
end
function Fake.Fighting(unit) return unit.fighting == true end
function Fake.IsTarget(unit) return unit.target == true, false end
function Fake.IsFocus(unit) return unit.focus == true, false end
function Fake.IsMouseover(unit) return unit.hover == true, false end
function Fake.FillHealth(bar, unit)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(unit.health)
end
function Fake.HealthThrough(unit, curve)
	if curve then return unit.health < 1 and 1 or 0 end   -- the only curve a plate passes is "hurt"
	return unit.health * 100
end
function Fake.HealthValue(unit) return unit.value end
function Fake.Threat(unit, mode)
	if mode == "off" then return nil, false end
	return unit.threat, unit.threat ~= nil
end
function Fake.Guid() return nil end
-- unit.dots: { { school, share of its most health }, ... }
function Fake.Breakdown(unit)
	if not unit.dots then return nil end
	local list, total = {}, 0
	for i, dot in ipairs(unit.dots) do
		list[i] = { school = dot[1], coming = dot[2] }
		total = total + dot[2]
	end
	return list, total
end
function Fake.FillDoom(doom, unit, list, total)
	local used = math.min(#list, #doom.segs)
	for i = 1, used do
		doom.segs[i]:SetMinMaxValues(0, 1)
		doom.segs[i]:SetValue(list[i].coming)
	end
	doom.meter:SetMinMaxValues(0, unit.health)
	doom.meter:SetValue(total)
	return used
end
function Fake.RaidMark(unit) return unit.mark, unit.mark ~= nil end
function Fake.Title(unit) return unit.title end
function Fake.Guild(unit) return unit.guild, unit.kin == true, false end
function Fake.Minion(unit) return unit.minion end
function Fake.Owner(unit) return unit.owner, false end
function Fake.Simplified() return false end
function Fake.BuildsCombo()
	local class = UnitClassBase("player")
	return class == "ROGUE" or class == "DRUID"
end
function Fake.Combo() return Fake.BuildsCombo() and 3 or 0, "player" end
function Fake.ComboLit(_, i) return i <= 3 and 1 or 0 end

-- Icons referenced by Blizzard's own UI, so they exist in this client.
local ICON = "Interface\\Icons\\"
local function Sample()
	local level = UnitLevel("player")
	return {
		{ x = 112, y = 62, tagged = true, unit = { name = "Defias Pillager", level = level + 1, stance = "hostile", health = 0.62, value = "412",
			target = true, fighting = true, threat = 1, dots = { { 32, 0.42 }, { 4, 0.28 } },
			cast = { name = "Fireball", icon = ICON .. "Spell_Shadow_Teleport", at = 0.55, left = "1.4" },
			auras = { { icon = ICON .. "Spell_Magic_PolymorphChicken", time = "8", kind = "control" },
				{ icon = ICON .. "Ability_ThunderClap", time = "6" },
				{ icon = ICON .. "Ability_Racial_BloodRage", time = "11", count = "3" } } } },
		{ x = 318, y = 62, unit = { name = "Hogger", level = level + 3, rank = "elite", stance = "hostile", health = 0.84, value = "1.2K",
			mark = 8, fighting = true, threat = 0.45, dots = { { 1, 0.25 } }, focus = true,
			cast = { name = "Head Butt", icon = ICON .. "Ability_Defend", at = 0.7, left = "0.6", locked = true },
			auras = { { icon = ICON .. "Spell_Nature_TimeStop", time = "4", kind = "steal" } } } },
		{ x = 518, y = 62, unit = { name = "Mother Fang", level = level, rank = "rare", stance = "neutral", health = 1, value = "380",
			hover = true } },
		-- A friend and, under her, her pet (there while pets are ours to name).
		{ x = 112, y = 124, unit = { name = "Ilse Varga", level = math.max(1, level - 2), class = "PRIEST", stance = "friendly", health = 1,
			value = "296", guild = "Night Watch" } },
		{ x = 112, y = 153, pet = true, unit = { name = "Mossfang", stance = "friendly", health = 1, value = "212", minion = "theirs",
			owner = UNITNAME_TITLE_PET:format("Ilse Varga") } },
		{ x = 318, y = 136, unit = { name = "Kotel Nica", level = level, class = "MAGE", stance = "hostile", health = 0.8, value = "640",
			fighting = true } },
		{ x = 518, y = 136, led = true, unit = { name = "Innkeeper Farley", stance = "friendly", health = 1, value = "1.9K", title = "Innkeeper" } },
	}
end

local previews = {}

local function BuildPreview(panel)
	local strip = CreateFrame("Frame", nil, panel)
	strip:SetSize(STRIP_W, STRIP_H)
	strip:SetPoint("TOPLEFT", LEFT, -112)
	UI.Panel(strip, { brackets = false, line = false })
	strip:SetClipsChildren(true)   -- large plates stay inside the strip
	for i, def in ipairs(Sample()) do
		local plate = P.Create(strip, Fake)
		plate.spot = def
		previews[i] = plate
	end
	return strip
end

local function RefreshPreview()
	local scale = T.db.scale
	for _, plate in ipairs(previews) do
		local def = plate.spot
		plate.root:ClearAllPoints()
		plate.root:SetPoint("CENTER", plate.root:GetParent(), "TOPLEFT", def.x / scale, -def.y / scale)
		plate:Arrange()
		local unit = def.unit
		plate:SetUnit(unit)
		-- Sample tags are set by other addons (ShyQuest: T.sampleTag, T.sampleLead).
		local tag = def.tagged and T.sampleTag or def.led and T.sampleLead or nil
		plate:SetTag(tag and { texture = tag.texture, coords = tag.coords, color = tag.color, back = tag.back,
			face = tag.face, over = tag.over, lead = tag.lead, count = def.tagged and 5 or nil } or nil)
		ns.Cast.Fake(plate, unit.cast)
		ns.Auras.Fake(plate, unit.auras)
		plate.root:SetShown(not def.pet or T.db.pets)
	end
end

-- Tabs

local function LookPage(page, g)
	At(UI.Header(page, "The plate", COL), page, LEFT, 0)
	At(g:Slider(page, "Size", 0.7, 1.5, 0.05, Get("scale"), Set("scale"),
		{ width = COL, format = Percent, desc = "Scale of every nameplate. Far-away plates still shrink." }), page, LEFT, -30)
	At(g:Slider(page, "Width", 90, 160, 2, Get("width"), Set("width"),
		{ width = COL, format = Whole, desc = "Width of the health bar." }), page, LEFT, -80)
	At(g:Dropdown(page, "Health text", {
		{ value = "hurt",    text = "Percent when hurt" },
		{ value = "percent", text = "Percent" },
		{ value = "value",   text = "Current health" },
		{ value = "off",     text = "None" },
	}, Get("health"), Set("health"), { width = COL,
		desc = "The number at the right end of the health bar." }), page, LEFT, -132)
	At(g:Dropdown(page, "Room when stacked", {
		{ value = "all", text = "Whole plate" },
		{ value = "bar", text = "Name and bar" },
	}, Get("room"), Set("room"), { width = COL,
		desc = "How much room a plate keeps when nameplates stack: all of it, so debuffs and cast bars never cover the plate next to them, or only its name and bar, for a tighter stack." }), page, LEFT, -188)

	At(UI.Header(page, "Font", COL), page, RIGHT, 0)
	At(g:Dropdown(page, "Name font", {
		{ value = "shy",  text = "Rounded", font = Shy.FONT_ROUNDED },
		{ value = "game", text = "Game font", font = "Fonts\\FRIZQT__.TTF" },
	}, Get("font"), Set("font"), { width = COL,
		desc = "Both fonts cover accented letters, Cyrillic, Korean and Chinese. Names the game writes past its 40 nameplates change at your next login." }), page, RIGHT, -28)
	At(g:Slider(page, "Name size", 9, 14, 1, Get("nameSize"), Set("nameSize"),
		{ width = COL, format = Whole, desc = "Font size of the name above each plate." }), page, RIGHT, -84)

	At(UI.Header(page, "Which units get nameplates", COL), page, RIGHT, -140)
	local note = UI.Text(page, "Enemies, friends, always or only in combat, stacked or overlapping: set these in the default nameplate options.", 12, false, UI.colors.dim)
	note:SetWidth(COL)
	At(note, page, RIGHT, -168)
	At(UI.Button(page, "Open nameplate options", 190, function()
		if not InCombatLockdown() then Settings.OpenToCategory(Settings.NAMEPLATE_OPTIONS_CATEGORY_ID) end
	end), page, RIGHT, -212)
end

local function ShowsPage(page, g)
	local function Casts() return T.db.casts end
	local function AnyAuras() return T.db.auras or T.db.control or T.db.steal end

	At(UI.Header(page, "On the plate", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Level", Get("level"), Set("level"),
		{ desc = "Shows the level before the name of players and of anything you can attack, colored by difficulty on what you can attack. A skull means the level is hidden." }), page, LEFT, -32)
	At(g:Checkbox(page, "Guild", Get("guild"), Set("guild"),
		{ desc = "Shows a player's guild in green under their name while they show only a name. Your own guild is in your color." }), page, LEFT, -58)
	At(g:Checkbox(page, "Pet names", Get("pets"), Set("pets"),
		{ desc = "Pets, totems and guardians of friendly players show a small name with their owner under it, and yours are in your color. Each takes one of the game's 40 nameplates." }), page, LEFT, -84)
	At(g:Checkbox(page, "Cast bar", Get("casts"), Set("casts"),
		{ desc = "A cast bar under the plate, in your color if you can interrupt it, grey with a shield if you can't. Interrupted casts flash red and show who stopped them." }), page, LEFT, -110)
	At(g:Checkbox(page, "Cast time left", Get("castTime"), Set("castTime"),
		{ enabled = Casts, desc = "Seconds remaining, at the right end of the cast bar." }), page, LEFT + 16, -136)
	At(g:Checkbox(page, "Combo points on your target", Get("combo"), Set("combo"),
		{ desc = "Five pips under your target's plate, gold to crimson as they fill. Only for classes that use combo points." }), page, LEFT, -162)
	At(g:Checkbox(page, "Execute line", Get("execute"), Set("execute"),
		{ desc = "A line on the health bar at 20% for warriors and paladins: below it, Execute and Hammer of Wrath are usable." }), page, LEFT, -188)
	-- (The damage to come is ShyDots': without it, no switch.)
	if Shy.addons.Dots then
		At(g:Checkbox(page, "As good as dead", Get("doom"), Set("doom"),
			{ desc = "Marks the DoT damage still to come on the health bar, in each spell's school color, with a check once it's enough to kill the mob. Needs ShyDots." }), page, LEFT, -214)
	end

	At(UI.Header(page, "Above the name", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Your debuffs", Get("auras"), Set("auras"),
		{ desc = "Your debuffs and your pet's, shortest first, with time left and stacks." }), page, RIGHT, -32)
	At(g:Checkbox(page, "Crowd control from anyone", Get("control"), Set("control"),
		{ desc = "Polymorph, Sap, traps and the like from any player, shown larger at the start of the row." }), page, RIGHT, -58)
	At(g:Checkbox(page, "Buffs you can remove", Get("steal"), Set("steal"),
		{ desc = "Enemy buffs you can dispel or steal, in a gold border." }), page, RIGHT, -84)
	At(g:Slider(page, "Icon size", 0.8, 1.4, 0.05, Get("auraSize"), Set("auraSize"),
		{ width = COL, format = Percent, enabled = AnyAuras, desc = "Size of the icons above the name." }), page, RIGHT, -116)
	local note = UI.Text(page, "Changes to these made in combat apply after the fight.", 12, false, UI.colors.dim)
	note:SetWidth(COL)
	At(note, page, RIGHT, -168)
end

-- The threat colors: the run from held to lost, then what another tank holds.
local LEGEND = {
	{ 1, "Yours, with room to spare" },
	{ 0.5, "Slipping" },
	{ 0, "Lost, or on you when you're not the tank" },
	{ "theirs", "Another tank has it" },
}

local function TargetPage(page, g)
	At(UI.Header(page, "Your target", COL), page, LEFT, 0)
	At(g:Dropdown(page, "Target mark", {
		{ value = "lift",    text = "Richer colors" },
		{ value = "line",    text = "Line along the top" },
		{ value = "corners", text = "Corner brackets" },
		{ value = "none",    text = "None" },
	}, Get("target"), Set("target"), { width = COL,
		desc = "How your target's plate stands out. A line or brackets are in your accent color, gold for your focus." }), page, LEFT, -28)
	At(g:Slider(page, "Other plates", 0.4, 1, 0.05, Get("dim"), Set("dim"),
		{ width = COL, format = function(v) return v >= 1 and "Not dimmed" or Percent(v) end,
		desc = "Opacity of every other plate while you have a target." }), page, LEFT, -84)

	At(UI.Header(page, "Name only", COL), page, LEFT, -140)
	At(g:Checkbox(page, "Friendly units", Get("friendNames"), Set("friendNames"),
		{ desc = "Friendly players and NPCs show only a name, players in class color, until you target them. In dungeons, raids and battlegrounds the default UI draws friendly names." }), page, LEFT, -172)
	At(g:Checkbox(page, "NPC titles", Get("titles"), Set("titles"),
		{ enabled = function() return T.db.friendNames end,
		desc = "A second line under a friendly NPC's name, such as Innkeeper or Flight Master, and under a pet's, saying whose it is." }), page, LEFT + 16, -198)
	At(g:Checkbox(page, "Enemies out of combat", Get("calm"), Set("calm"),
		{ desc = "Enemies show only name and level until you target them or they enter combat." }), page, LEFT, -224)

	At(UI.Header(page, "Colors", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Class colors on players", Get("classColors"), Set("classColors"),
		{ desc = "Player health bars and friendly names in class color. An enemy's name is always red." }), page, RIGHT, -32)
	At(g:Dropdown(page, "Threat colors in a group", {
		{ value = "auto", text = "By my role" },
		{ value = "tank", text = "As a tank" },
		{ value = "dps",  text = "As damage or healer" },
		{ value = "off",  text = "Off" },
	}, Get("threat"), Set("threat"), { width = COL,
		desc = "In a group, health bars go from green through orange to red as you lose threat: for a tank, as the next player catches up; for anyone else, as you get close to pulling aggro. Your role is the one your group gave you, else your talent build's, else your tank or healer layout's. Solo, a neutral mob just turns red once it attacks you." }), page, RIGHT, -62)
	-- The run of colors, in steps.
	local STEPS = 24
	for i = 0, STEPS - 1 do
		local step = page:CreateTexture(nil, "ARTWORK")
		step:SetSize(COL / STEPS, 9)
		step:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT + i * COL / STEPS, -120)
		step:SetTexture(Shy.Skin.BAR)
		step:SetVertexColor(L.ThreatColor(1 - i / (STEPS - 1)))
	end
	for i, row in ipairs(LEGEND) do
		local y = -136 - (i - 1) * 19
		local swatch = page:CreateTexture(nil, "ARTWORK")
		swatch:SetSize(22, 9)
		swatch:SetPoint("TOPLEFT", page, "TOPLEFT", RIGHT, y - 2)
		swatch:SetTexture(Shy.Skin.BAR)
		if row[1] == "theirs" then
			local c = L.COLORS.theirs
			swatch:SetVertexColor(c[1], c[2], c[3])
		else
			swatch:SetVertexColor(L.ThreatColor(row[1]))
		end
		At(UI.Text(page, row[2], 12, false, UI.colors.dim), page, RIGHT + 30, y)
	end
end

-- Panel

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Apply() end)

	local function Build()
		UI.PageHeader(panel, T)
		BuildPreview(panel)

		local switchLabel = UI.Text(panel, "Replace nameplates", 15, true)
		switchLabel:SetPoint("TOPLEFT", LEFT, -296)
		local switch = group:Switch(panel, "Replace nameplates", Get("on"), Set("on"),
			{ desc = "Turn off to go back to the default nameplates. Your settings are kept." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		local pages = {}
		local tabs = UI.Tabs(panel, { "The plate", "What it shows", "Target & colors" }, function(i)
			for j, p in ipairs(pages) do p:SetShown(i == j) end
		end, 580, 15)
		tabs:SetPoint("TOPLEFT", LEFT, -330)

		for i, build in ipairs({ LookPage, ShowsPage, TargetPage }) do
			local page = CreateFrame("Frame", nil, panel)
			page:SetPoint("TOPLEFT", 0, -372)
			page:SetSize(670, 250)
			page:Hide()
			build(page, group)
			pages[i] = page
		end
		tabs:Select(1)
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
	end)

	function panel:OnDefault()
		local cvars = T.db.cvars   -- saved CVar values must survive a reset
		T:ResetDB()
		T.db.cvars = cvars
		ns.Apply()
	end

	return panel
end
