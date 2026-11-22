-- Shy.Chooser: choosing a theme, one flow wherever it is asked (the setup window's Theme page, the /shy
-- window's Theme room). A theme is its parts: a look, a color (one, or a gradient), a font, the bars'
-- fill and the icons' frames, your health's color and the look's own options. A preset is all of them picked to
-- go together; a part changed after makes the theme your own. Every pick goes on at once, so the screen, the
-- window and everything drawn here show it as it is made.
--
--   Chooser.Preview(parent, width, height)   the HUD in what is worn, standing in the looks' scene: a unit's plate,
--                                            a bar of buttons, two buttons and a chat window with its typing row
--   Chooser.Summary(parent, width)           the theme worn, in words: its preset (or your own) and every part
--   Chooser.Gallery(parent, width, opts)     the presets as cards, each in its own look, color, bars, frames and
--                                            font, your own mix first; opts.perRow, opts.height (a scroll area)
--   Chooser.Part(key, parent, width, opts)   one part's controls, keys in Chooser.PARTS; opts.background: the
--                                            Background slider with the look's options
--   Chooser.PARTS                            { key, name } in the order they are asked
--   Chooser.Room(parent, width, room, opts)  the whole flow in one place: the presets and every part, a tab each
-- Every frame has :Refresh() and refreshes itself when any part changes while it shows, and as it comes up.

local Shy = Shy
local UI, Theme = Shy.UI, Shy.Theme
local Skin, Slot = Shy.Skin, Shy.Slot
local C = UI.colors
local floor, max = math.floor, math.max

local Chooser = {}
Shy.Chooser = Chooser

local CARD_SCENE, CARD_GAP = 64, 12 -- a preset card's scene, and between cards
local LOOK_SCENE = 56               -- a look card's scene in the Look part
local COL, COL_GAP = 260, 16        -- a part's controls: two columns
local ROW_GAP = 14                  -- between rows of controls
local HUES = 36                     -- swatches along the hue slider
local TRACK = { 0.02, 0.02, 0.025, 1 }   -- a bar's empty track

-- Every part's change, as the core tells it.
local EVENTS = { "SHY_THEME", "SHY_BAR", "SHY_SLOT_STYLE", "SHY_HEALTH", "SHY_FONT" }
local function Follow(f)
	for _, event in ipairs(EVENTS) do
		Shy:On(event, function()
			if f:IsVisible() then f:Refresh() end
		end)
	end
	f:HookScript("OnShow", function(self) self:Refresh() end)
end

-- Words

local function Named(list, key, field)
	for _, item in ipairs(list) do
		if (item.key or item.value) == key then return item[field or "name"] end
	end
end

local function FontName(key)
	return Theme.FONTS and Named(Theme.FONTS, key or (Theme.Font and Theme.Font())) or nil
end

-- The color worn, in a few words.
local function ColorWords()
	if Theme.Gradient() then
		local key = Theme.GradientPick()
		return key ~= "own" and Named(Theme.GRADIENTS, key) or "A gradient of your own"
	end
	local pick = Theme.Pick()
	if pick == "custom" then return "Your own color" end
	return Named(Theme.Picks(), pick, "text") or "Your own color"
end

-- A preset's color in a few words, as they follow its look's name: a gradient by its name, a color in lower case.
local function PresetColorWords(preset)
	if preset.gradient then
		local named = Named(Theme.GRADIENTS, preset.gradient)
		return (named and named ~= preset.name) and named or "a gradient"
	end
	if preset.accent == "class" then return "your class color" end
	return ((Named(Theme.Picks(), preset.accent, "text") or ""):gsub("^%u", string.lower))
end

-- A preset's color as a ramp (one stop for one color), for its swatch.
local function PresetRamp(preset)
	if preset.gradient then
		for _, item in ipairs(Theme.GRADIENTS) do
			if item.key == preset.gradient then return item.ramp end
		end
	end
	local r, g, b
	if preset.accent == "class" then
		local class = UnitClassBase("player")
		local color = class and C_ClassColor.GetClassColor(class)
		if color then r, g, b = color:GetRGB() end
	else
		r, g, b = Theme.PresetColor(preset.accent)
	end
	if not r then r, g, b = Theme.Accent() end
	local h, s, l = Theme.ToHSL(r, g, b)
	return { stops = { { at = 0, h = h, s = s, l = l } }, mids = {} }
end

-- A preset's own accent for a card drawn in it: its color, a ramp's middle.
local function PresetAccent(preset)
	local ramp = PresetRamp(preset)
	return function() return Theme.Grad.Sample(ramp, 0.5) end
end

-- A ramp shown as a swatch: the gradient editor's ramp, or one flat color where it isn't loaded.
local function Swatch(parent, width, height)
	if UI.GradientRamp then return UI.GradientRamp(parent, width, height) end
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	local t = f:CreateTexture(nil, "ARTWORK")
	t:SetAllPoints()
	function f:SetRamp(ramp)
		local stop = ramp.stops[1]
		t:SetColorTexture(Theme.HueColor(stop.h, stop.s, stop.l))
	end
	return f
end

-- The preview

-- A bar in a piece: its dark track, its fill the bars' design in use, tinted by `color` (a function).
local function Bar(owner, y, h, value)
	local track = owner:CreateTexture(nil, "ARTWORK")
	track:SetPoint("TOPLEFT", 8, -y)
	track:SetPoint("TOPRIGHT", -8, -y)
	track:SetHeight(h)
	track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
	local bar = CreateFrame("StatusBar", nil, owner)
	bar:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
	bar:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -1, 1)
	Skin.HatchBar(bar)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(value)
	return bar
end

-- A piece's words on its header's middle, named its title as a real piece's are (a look may set them off).
local function Title(panel, text)
	local fs = UI.TitleText(panel, text, UI.HEAD.piece.text)
	UI.OnHead(fs, "LEFT", panel, "LEFT", UI.HEAD.piece.pad)
	if panel.shyLook then UI.LookTitle(panel.shyLook, fs, true) end
	return fs
end

local CHAT_LINES = {
	{ "[Trade] ", "Selling Linen Cloth x20" },
	{ "[Guild] ", "Anyone for Ragefire?" },
	{ "Kaito: ", "lfg Wailing Caverns" },
	{ "", "You receive loot: Copper Ore x3" },
	{ "[Party] ", "Pulling after this drink" },
}
local CHAT_FOOT = 24   -- the chat window's typing row

function Chooser.Preview(parent, width, height)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, height)
	UI.Skin(f)
	-- The world: dusk sky to a hazy horizon, the ground falling dark, as the looks' cards have it.
	local SC = UI.SCENE
	local scene = CreateFrame("Frame", nil, f)
	scene:SetPoint("TOPLEFT", 1, -1)
	scene:SetPoint("BOTTOMRIGHT", -1, 1)
	scene:SetClipsChildren(true)
	local sky = scene:CreateTexture(nil, "BACKGROUND")
	sky:SetColorTexture(1, 1, 1, 1)
	sky:SetGradient("VERTICAL", CreateColor(SC.haze[1], SC.haze[2], SC.haze[3], 1), CreateColor(SC.sky[1], SC.sky[2], SC.sky[3], 1))
	sky:SetPoint("TOPLEFT")
	sky:SetPoint("TOPRIGHT")
	sky:SetHeight(height * 0.5)
	local ground = scene:CreateTexture(nil, "BACKGROUND")
	ground:SetColorTexture(1, 1, 1, 1)
	ground:SetGradient("VERTICAL", CreateColor(SC.deep[1], SC.deep[2], SC.deep[3], 1), CreateColor(SC.ground[1], SC.ground[2], SC.ground[3], 1))
	ground:SetPoint("TOPLEFT", sky, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT")
	-- The card's hairline over the scene and everything in it.
	local rim = CreateFrame("Frame", nil, f)
	rim:SetAllPoints()
	rim:SetFrameLevel(f:GetFrameLevel() + 30)
	for _, edge in ipairs(f.shyEdges) do edge:SetParent(rim) end

	local m = 14
	local colW = floor((width - 3 * m) / 2)
	local strip = UI.HEAD_STRIP

	-- A unit's plate: your name on its header, health and power under.
	local plate = CreateFrame("Frame", nil, scene)
	plate:SetSize(colW, strip + 34)
	plate:SetPoint("TOPLEFT", m, -m)
	UI.Panel(plate, { title = strip, cap = true, facets = false, hud = true })
	f.name = Title(plate, UnitName("player") or "")
	local health = Bar(plate, strip + 6, 12, 0.78)
	local power = Bar(plate, strip + 20, 7, 0.55)

	-- A bar of buttons in the console's housing, sunk where the look sinks content.
	local PAD, SLOTS, SLOT_GAP = 8, 6, 4
	local each = floor((colW - 2 * PAD - (SLOTS - 1) * SLOT_GAP) / SLOTS)
	local console = CreateFrame("Frame", nil, scene)
	console:SetSize(colW, each + 2 * PAD)
	console:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", 0, -12)
	UI.Panel(console, { cap = true, facets = false, hud = true })
	if console.shyLook then UI.LookContent(console.shyLook, { PAD, PAD, PAD, PAD }) end
	f.slots = {}
	for i = 1, SLOTS do
		local holder = CreateFrame("Frame", nil, console)
		holder:SetSize(each, each)
		holder:SetPoint("TOPLEFT", PAD + (i - 1) * (each + SLOT_GAP), -PAD)
		local icon = holder:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		local picture = GetActionTexture(i)
		if picture then icon:SetTexture(picture) else icon:Hide() end
		f.slots[i] = Slot.New(holder, { icon = picture and icon or nil, hover = false })
	end

	-- Two buttons in the look's make: the one that goes ahead, and the other.
	local half = floor((colW - 8) / 2)
	f.yes = UI.Button(scene, "Accept", half, function() end)
	f.yes:SetPoint("TOPLEFT", console, "BOTTOMLEFT", 0, -14)
	if f.yes.SetPrimary then f.yes:SetPrimary(true) end
	f.no = UI.Button(scene, "Decline", half, function() end)
	f.no:SetPoint("LEFT", f.yes, "RIGHT", 8, 0)

	-- A chat window: its tab's name on the header, a few lines, and the typing row along its foot.
	local chat = CreateFrame("Frame", nil, scene)
	chat:SetPoint("TOPLEFT", plate, "TOPRIGHT", m, 0)
	chat:SetPoint("BOTTOMRIGHT", -m, m)
	UI.Panel(chat, { title = strip, cap = true, facets = false, hud = true })
	Title(chat, "General")
	if chat.shyLook then UI.LookZones(chat.shyLook, nil, CHAT_FOOT) end
	local y = strip + 8
	for _, line in ipairs(CHAT_LINES) do
		local fs = UI.Words(chat, UI.TextFont(11), C.text, { wrap = false })
		fs:SetPoint("TOPLEFT", 9, -y)
		fs:SetPoint("RIGHT", chat, "RIGHT", -8, 0)
		fs:SetText(line[1] == "" and line[2] or (UI.Wrap(C.dim, line[1]) .. line[2]))
		y = y + 15
	end
	local seam = chat:CreateTexture(nil, "ARTWORK")
	seam:SetHeight(1)
	seam:SetPoint("BOTTOMLEFT", 4, CHAT_FOOT)
	seam:SetPoint("BOTTOMRIGHT", -4, CHAT_FOOT)
	Theme.Paint(seam, C.border, 0.8)
	local typing = UI.Words(chat, UI.TextFont(11), C.text)
	typing:SetPoint("BOTTOMLEFT", 9, (CHAT_FOOT - 11) / 2)
	typing:SetText("Say: on my way|")
	f.plate, f.console, f.chat = plate, console, chat

	function f:Refresh()
		-- The bars' colors: your health's and your accent (a gradient's, where the bar stands).
		Theme.Tint(health:GetStatusBarTexture(), function() return Skin.HealthRGB() end)
		Theme.Tint(power:GetStatusBarTexture(), Theme.Accent)
	end
	Follow(f)
	f:Refresh()
	return f
end

-- The summary

local SUMMARY_ROWS = { { "look", "Look" }, { "color", "Color" }, { "font", "Font" }, { "text", "Text" }, { "bar", "Bars" }, { "slot", "Icon frames" },
	{ "health", "Your health" } }

local function PartWords(key)
	local look = Theme.Look()
	if key == "look" then return UI.LOOK_NAMES[look] end
	if key == "color" then return ColorWords() end
	if key == "font" then return FontName() end
	if key == "text" then return Named(Theme.TEXTS, Theme.TextEffect(), "name") end
	if key == "bar" then return Skin.BarFor(look).name end
	if key == "slot" then return Slot.StyleFor(look).name end
	if key == "health" then return Named(Skin.HealthPicks(), Skin.HealthColor(), "text") or "Your own color" end
end

function Chooser.Summary(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	-- (The brand's words in the theme's font, not a header's: a look's header lettering is for its own strip.)
	f.title = UI.Text(f, "", 18, true, C.head)
	f.title:SetPoint("TOPLEFT")
	f.words = UI.Text(f, "", 12, false, C.dim)
	f.words:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
	f.words:SetWidth(width)
	f.words:SetWordWrap(true)
	f.rows = {}
	local labelW = 96
	for i, row in ipairs(SUMMARY_ROWS) do
		local label = UI.Text(f, row[2], 12, false, C.dim)
		local value = UI.Text(f, "", 12, false, C.text)
		value:SetWidth(width - labelW)
		value:SetWordWrap(false)
		f.rows[i] = { key = row[1], label = label, value = value }
	end
	function f:Refresh()
		local worn = Theme.PresetWorn()
		local preset = worn ~= "own" and Named(Theme.PRESETS, worn, "desc") and worn
		self.title:SetText(preset and Named(Theme.PRESETS, worn) or "Your own")
		self.words:SetText(preset and Named(Theme.PRESETS, worn, "desc") or "Your own mix of a look, a color and a finish.")
		local y = -(self.title:GetStringHeight() + 5 + self.words:GetStringHeight() + 12)
		for _, row in ipairs(self.rows) do
			local said = PartWords(row.key)
			row.label:SetShown(said ~= nil)
			row.value:SetShown(said ~= nil)
			if said then
				row.label:ClearAllPoints()
				row.label:SetPoint("TOPLEFT", 0, y)
				row.value:ClearAllPoints()
				row.value:SetPoint("TOPLEFT", labelW, y)
				row.value:SetText(said)
				y = y - 18
			end
		end
		self:SetSize(width, -y)
	end
	Follow(f)
	f:Refresh()
	return f
end

-- The presets

-- The mix you made, kept when a preset goes on over it, so your own card can put it back.
local ownMix

-- What is worn now, every part: what a page plans, what the window puts back, your own mix.
function Chooser.Snapshot()
	local _, hue, sat, light = Theme.Mode()
	local look = Theme.Look()
	local options = {}
	for _, o in ipairs(Theme.LookOptions(look)) do options[o.key] = Theme.LookOption(look, o.key) end
	return { look = look, bar = Skin.Bar(), slot = Slot.Style(), pick = Theme.Pick(), hue = hue, sat = sat, light = light,
		health = Skin.HealthColor(), healthHSL = { Skin.HealthHSL() }, strength = floor(Theme.Strength() * 100 + 0.5), wells = floor(Slot.WellArt() * 100 + 0.5),
		gradient = Theme.Gradient(), font = Theme.Font and Theme.Font() or nil, options = options,
		text = Theme.TextChosen() or false, textStrength = Theme.TextStrength() }   -- (text false: the look's own)
end

-- Two parts alike, tables by what they hold (a ramp's stops, a color's three numbers).
local function Alike(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not Alike(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

-- Every part of `t` (Chooser.Snapshot's shape) put on. Each change restyles the whole screen, so only the
-- parts that differ from what is worn go on: putting back a look nobody changed costs nothing.
function Chooser.Wear(t)
	local now = Chooser.Snapshot()
	for key, value in pairs(t.options or {}) do
		if Theme.LookOption(t.look, key) ~= value then Theme.SetLookOption(t.look, key, value) end
	end
	if t.look and t.look ~= now.look then Theme.SetLook(t.look) end
	if t.bar and t.bar ~= now.bar then Skin.SetBar(t.bar) end
	if t.slot then Slot.SetStyle(t.slot) end
	if t.health == "custom" and t.healthHSL then
		if now.health ~= "custom" or not Alike(t.healthHSL, now.healthHSL) then
			Skin.SetHealthHSL(t.healthHSL[1], t.healthHSL[2], t.healthHSL[3])
		end
	elseif t.health and t.health ~= now.health then
		Skin.SetHealthColor(t.health)
	end
	-- The accent: a pick as it is, your own color, or a gradient.
	if t.pick == "custom" then
		if now.pick ~= "custom" or t.hue ~= now.hue or t.sat ~= now.sat or t.light ~= now.light then
			Theme.Set("hue", t.hue, t.sat, t.light)
		end
	elseif t.pick == "gradient" then
		if now.pick ~= "gradient" or not Alike(t.gradient, now.gradient) then Theme.SetGradient(t.gradient) end
	elseif t.pick and t.pick ~= now.pick then
		Theme.SetPick(t.pick)
	end
	if t.strength and t.strength ~= now.strength then Theme.SetStrength(t.strength) end
	if t.wells then Slot.SetWellArt(t.wells) end
	if t.font and Theme.SetFont then Theme.SetFont(t.font) end
	if t.textStrength and t.textStrength ~= now.textStrength then Theme.SetTextStrength(t.textStrength) end
	if t.text ~= nil and t.text ~= now.text then Theme.SetTextEffect(t.text or nil) end
end

-- A preset put on; the mix worn before it is kept when it was your own.
function Chooser.Pick(key)
	if key == "own" then
		if ownMix then Chooser.Wear(ownMix) end
		return
	end
	if Theme.PresetWorn() == "own" then ownMix = Chooser.Snapshot() end
	Theme.SetPreset(key)
end

-- A card: the preset's look in the scene, its bars, frames and color, its name in its own font.
local function PresetCard(parent, width, preset)
	-- (Its look's options as the preset has them, not the worn ones: a frame drawn as the preset draws it.)
	local parts = Theme.PresetParts(preset.key)
	local card = UI.LookCard(parent, width, preset.look, { scene = CARD_SCENE, short = true, accent = PresetAccent(preset),
		options = parts and parts.options, onClick = function() Chooser.Pick(preset.key) end })
	card.key = preset.key
	card.name:SetText(preset.name)
	if UI.TitleFace then UI.TitleFace(card.name, 15, "", preset.font or Theme.FONT) end
	card.words:SetText(UI.LOOK_NAMES[preset.look] .. ", " .. PresetColorWords(preset))
	card:SetBar(Skin.BarFile(preset.bar, preset.look))
	card:SetSlots(preset.slot)
	card.ramp = Swatch(card, width - 2, 3)
	card.ramp:SetPoint("TOPLEFT", card.scene, "BOTTOMLEFT", 0, 0)
	card.ramp:SetRamp(PresetRamp(preset))
	UI.Help(card, preset.name, preset.desc)
	return card
end

-- Your own card: the scene in what you wear (or wore before a preset), first in the gallery.
local function OwnCard(parent, width)
	local card = UI.LookCard(parent, width, nil, { scene = CARD_SCENE, short = true, onClick = function() Chooser.Pick("own") end })
	card.key = "own"
	card.name:SetText("Your own")
	card.ramp = Swatch(card, width - 2, 3)
	card.ramp:SetPoint("TOPLEFT", card.scene, "BOTTOMLEFT", 0, 0)
	UI.Help(card, "Your own", "Your own mix. It stays here when you pick a preset, so you can come back to it.")
	return card
end

function Chooser.Gallery(parent, width, opts)
	opts = opts or {}
	local perRow = opts.perRow or 3
	local each = floor((width - (opts.height and 14 or 0) - (perRow - 1) * CARD_GAP) / perRow)
	local f = CreateFrame("Frame", nil, parent)
	local area, holder
	if opts.height then
		area = UI.ScrollArea(f, width, opts.height)
		area:SetPoint("TOPLEFT")
		holder = area.content
	else
		holder = f
	end
	-- (A preset of a look that isn't there can't be put on, so it isn't offered.)
	local cards = { OwnCard(holder, each) }
	for _, preset in ipairs(Theme.PRESETS) do
		if UI.LOOK_NAMES[preset.look] then cards[#cards + 1] = PresetCard(holder, each, preset) end
	end
	local tall = 0
	for i, card in ipairs(cards) do
		local column, row = (i - 1) % perRow, floor((i - 1) / perRow)
		card:SetPoint("TOPLEFT", column * (each + CARD_GAP), -row * (card:GetHeight() + CARD_GAP))
		tall = (row + 1) * card:GetHeight() + row * CARD_GAP
	end
	f.cards, f.area = cards, area
	if area then
		f.handlesScroll = true
		holder:SetHeight(tall)
		area:Update()
		f:SetSize(width, opts.height)
	else
		f:SetSize(width, tall)
	end
	function f:Fit(height)
		if not area then return end
		area:SetHeight(height)
		self:SetHeight(height)
		area:Update()
	end
	function f:Refresh()
		local worn = Theme.PresetWorn()
		local own = cards[1]
		-- Your own card shows what you wear while it is yours, else the mix kept for you; none yet: dimmed.
		local mix = worn == "own" and Chooser.Snapshot() or ownMix
		own.look = mix and mix.look or Theme.Look()
		own:SetAlpha(mix and 1 or 0.5)
		if worn == "own" then
			local said = ColorWords()
			own.words:SetText(UI.LOOK_NAMES[own.look] .. ", " .. (Theme.Gradient() and said or said:gsub("^%u", string.lower)))
		else
			own.words:SetText(mix and (UI.LOOK_NAMES[own.look] .. ", as you left it") or "Change any part to make one")
		end
		-- Worn, it is the theme's housing; kept, the look you left (in the color on screen: a card has one accent).
		UI.SetLook(own.piece, worn ~= "own" and own.look or nil)
		own:SetBar(Skin.BarFile(mix and mix.bar or Skin.Bar(), own.look))
		own:SetSlots(mix and mix.slot or Slot.Style())
		if worn == "own" or not mix then
			own.ramp:SetRamp(Theme.Stops())
		else
			own.ramp:SetRamp(mix.gradient or { stops = { { at = 0, h = mix.hue, s = mix.sat, l = mix.light } }, mids = {} })
		end
		for _, card in ipairs(cards) do
			card:Paint(card.key == worn)
		end
	end
	Follow(f)
	f:Refresh()
	return f
end

-- The parts

Chooser.PARTS = {
	{ key = "look", name = "Look" },
	{ key = "color", name = "Color" },
	{ key = "font", name = "Font" },
	{ key = "finish", name = "Bars and icons" },
	{ key = "options", name = "Options" },
}

-- Whether a part can be offered here (the font needs its picker).
function Chooser.Offered(key)
	if key == "font" then return UI.FontPicker ~= nil end
	return true
end

local Parts = {}

-- The looks as cards, each a housing of its make in the scene, in your color, font, bars and frames.
function Parts.look(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local perRow = max(1, floor((width + 12) / (176 + 12)))
	local each = floor((width - (perRow - 1) * 12) / perRow)
	local cards = {}
	local tall = 0
	for i, look in ipairs(Theme.LOOKS) do
		local card = UI.LookCard(f, each, look, { scene = LOOK_SCENE, short = true, onClick = function(pick) Theme.SetLook(pick) end })
		local column, row = (i - 1) % perRow, floor((i - 1) / perRow)
		card:SetPoint("TOPLEFT", column * (each + 12), -row * (card:GetHeight() + 12))
		cards[look] = card
		tall = (row + 1) * card:GetHeight() + row * 12
	end
	f.cards = cards
	f:SetSize(width, tall)
	function f:Refresh()
		local now = Theme.Look()
		for look, card in pairs(cards) do
			card:Paint(now == look)
			card:SetBar(Skin.BarFile(Skin.Bar(), look))
			card:SetSlots(Slot.Style())
		end
	end
	return f
end

-- Your color: one, picked or made on the sliders, or a gradient made in the editor.
function Parts.color(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local ramped = UI.GradientEditor ~= nil
	-- One color or a gradient: the choice that decides what stands under it.
	local one = UI.Button(f, "One color", 130, function()
		if Theme.Gradient() then Theme.SetGradientPick(nil) end
	end)
	one:SetPoint("TOPLEFT")
	local many = UI.Button(f, "Gradient", 130, function()
		if not Theme.Gradient() then Theme.SetGradientPick("kept") end
	end)
	many:SetPoint("LEFT", one, "RIGHT", 8, 0)
	many:SetShown(ramped)
	local top = -(24 + ROW_GAP)

	-- One color: your class's, any class's, one of ours, or your own. A pick fills the sliders; moving one makes the
	-- color your own, put on once the slider rests (`own` holds it meanwhile, so the sliders never jump back).
	local solid = CreateFrame("Frame", nil, f)
	solid:SetPoint("TOPLEFT", 0, top)
	local own
	Shy:On("SHY_THEME", function() own = nil end)
	local function HSL()
		if own then return own[1], own[2], own[3] end
		local _, h, s, l = Theme.Mode()
		return h, s, l
	end
	local function Move(i, v)
		own = { HSL() }
		own[i] = v
		Theme.SetSoon("hue", own[1], own[2], own[3])
		solid:Refresh()
	end
	local function Making()
		if own then return Theme.HueColor(own[1], own[2], own[3]) end
		return Theme.Accent()
	end
	local picks = {}
	for _, item in ipairs(Theme.Picks()) do
		if item.value ~= "gradient" then picks[#picks + 1] = item end
	end
	local mode = UI.Dropdown(solid, "Color", picks, function() return own and "custom" or Theme.SolidPick() end, function(v)
		own = nil
		Theme.SetPick(v)
	end, { width = COL, desc = "The color on every window, bar and title. Use your class color, another class's, a ready-made one, or your own." })
	mode:SetPoint("TOPLEFT")
	local hue = UI.Slider(solid, "Hue", 0, 359, 1, function() return (HSL()) end, function(v) Move(1, v) end,
		{ width = COL, format = function(v) return v .. "\194\176" end, color = Making,
			desc = "Hue of the accent color. " .. Theme.SAPPHIRE .. "\194\176 matches the " .. Shy.Brand.FAMILY .. " logo." })
	hue:SetPoint("TOPLEFT", COL + COL_GAP, 0)
	-- Under the hue, every hue at the saturation and lightness in use.
	local strip = CreateFrame("Frame", nil, solid)
	strip:SetSize(COL, 5)
	strip:SetPoint("TOPLEFT", hue, "BOTTOMLEFT", 0, -2)
	strip.cells = {}
	for i = 1, HUES do
		local t = strip:CreateTexture(nil, "ARTWORK")
		t:SetSize(COL / HUES + 0.5, 5)
		t:SetPoint("LEFT", (i - 1) * COL / HUES, 0)
		strip.cells[i] = t
	end
	local SR, LR = Theme.SAT_RANGE, Theme.LIGHT_RANGE
	local function Percent(v) return v .. "%" end
	local sat = UI.Slider(solid, "Saturation", SR[1] * 100, SR[2] * 100, 1, function() return floor(select(2, HSL()) * 100 + 0.5) end,
		function(v) Move(2, v / 100) end, { width = COL, format = Percent, color = Making, desc = "How strong the color is. Low is muted, high is vivid." })
	sat:SetPoint("TOPLEFT", mode, "BOTTOMLEFT", 0, -ROW_GAP - 8)
	local light = UI.Slider(solid, "Lightness", LR[1] * 100, LR[2] * 100, 1, function() return floor(select(3, HSL()) * 100 + 0.5) end,
		function(v) Move(3, v / 100) end, { width = COL, format = Percent, color = Making, desc = "How light the color is. Low is deep, high is pale." })
	light:SetPoint("TOPLEFT", sat, "TOPRIGHT", COL_GAP, 0)
	solid:SetSize(width, 46 + ROW_GAP + 8 + 46)
	local strung
	function solid:Refresh()
		mode:Refresh()
		hue:Refresh()
		sat:Refresh()
		light:Refresh()
		local _, s, l = HSL()
		local key = s .. " " .. l
		if strung ~= key then
			strung = key
			for i, t in ipairs(strip.cells) do t:SetColorTexture(Theme.HueColor((i - 0.5) * 360 / HUES, s, l)) end
		end
	end

	-- A gradient: the editor, put on once a drag rests.
	local editor
	if ramped then
		editor = UI.GradientEditor(f, width, { get = Theme.Gradient, set = Theme.SetGradientSoon })
		editor:SetPoint("TOPLEFT", 0, top)
	end

	function f:Refresh()
		local grad = ramped and Theme.Gradient() ~= nil
		one:SetPrimary(not grad)
		many:SetPrimary(grad)
		solid:SetShown(not grad)
		if editor then editor:SetShown(grad) end
		if grad then
			editor:Refresh()
			self:SetSize(width, -top + UI.GRADIENT_EDITOR_H)
		else
			solid:Refresh()
			self:SetSize(width, -top + solid:GetHeight())
		end
	end
	f:Refresh()
	return f
end

-- The font of every title, header, tab and button.
function Parts.font(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local picker = UI.FontPicker(f, { width = COL })
	picker:SetPoint("TOPLEFT")
	local words = UI.Text(f, "Your font is on every title, header, tab and button. Chat and names keep a font made for reading.", 12, false, C.dim)
	words:SetPoint("TOPLEFT", COL + COL_GAP, -4)
	words:SetWidth(width - COL - COL_GAP)
	words:SetWordWrap(true)
	-- What the words wear to stand off their ground: the look's own, or one picked (hovering one shows it), and how
	-- deep a shadow is.
	local effects = { { value = "look", text = "By look" } }
	for _, t in ipairs(Theme.TEXTS) do effects[#effects + 1] = { value = t.key, text = t.name } end
	local text = UI.Dropdown(f, "Text", effects, function() return Theme.TextChosen() or "look" end,
		function(v) Theme.SetTextEffect(v ~= "look" and v or nil) end,
		{ width = COL, preview = function(v) Theme.PreviewTextEffect(v ~= "look" and v or nil) end,
			desc = "A shadow or an outline keeps text readable over bright or busy backgrounds. By look uses the one your look comes with." })
	text:SetPoint("TOPLEFT", picker, "BOTTOMLEFT", 0, -ROW_GAP)
	local deep = UI.Slider(f, "Shadow", 0, 100, 5, function() return floor(Theme.TextStrength() * 100 + 0.5) end,
		function(v) Theme.SetTextStrength(v / 100) end,
		{ width = COL, format = function(v) return v .. "%" end, enabled = function() return Theme.TextEffect() == "shadow" end,
			desc = "How deep the shadow under text is." })
	deep:SetPoint("TOPLEFT", text, "TOPRIGHT", COL_GAP, 0)
	-- The worn font at a few sizes, as headers and titles show it.
	local big = UI.TitleText(f, "Shyce Cream", 24, C.head)
	big:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -ROW_GAP - 6)
	local mid = UI.TitleText(f, "General   Trade   Guild   Party", UI.HEAD.window.text, C.text)
	mid:SetPoint("TOPLEFT", big, "BOTTOMLEFT", 0, -10)
	local small = UI.TitleText(f, "Accept  Decline  Options  Close", UI.HEAD.piece.text, C.dim)
	small:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", 0, -8)
	f:SetSize(width, 46 + ROW_GAP + 46 + ROW_GAP + 6 + 24 + 10 + 16 + 8 + 14)
	function f:Refresh()
		picker:Refresh()
		text:Refresh()
		deep:Refresh()
	end
	return f
end

-- The icons' shape, with what you wear in it: an empty slot, a plain one, two in quality colors, one in debuff red.
local ICON_UNKNOWN = 134400   -- question mark, for an empty equipment slot
local WORN = { 16, 5, 8, 1 }  -- inventory slot ids: main hand, chest, feet, head

local function Shape(f)
	local shape = UI.Dropdown(f, "Icon shape", Slot.SHAPES, Slot.Shape, Slot.Set, { width = COL, desc = Slot.DESC })
	shape:SetPoint("TOPLEFT")
	local uncommon = ColorManager.GetColorDataForBagItemQuality(Enum.ItemQuality.Uncommon)
	local rare = ColorManager.GetColorDataForBagItemQuality(Enum.ItemQuality.Rare)
	local marks = { false, { uncommon.r, uncommon.g, uncommon.b }, { rare.r, rare.g, rare.b }, { Theme.Harm() } }
	local samples = {}
	for i = 0, #WORN do
		local holder = CreateFrame("Frame", nil, f)
		holder:SetSize(Slot.SIZE, Slot.SIZE)
		holder:SetPoint("LEFT", shape, "RIGHT", COL_GAP + i * (Slot.SIZE + Slot.GAP), -6)
		holder:EnableMouse(true)   -- so the slot's hover light shows
		local icon = holder:CreateTexture(nil, "BORDER")
		icon:SetAllPoints(holder)
		local slot = Slot.New(holder, { icon = icon })
		local mark = marks[i]
		if mark then slot:Mark(mark[1], mark[2], mark[3]) end
		slot:Empty(i == 0)
		samples[i + 1] = { icon = icon, worn = WORN[i] }
	end
	function shape.Samples()
		for _, sample in ipairs(samples) do
			local picture = sample.worn and (GetInventoryItemTexture("player", sample.worn) or ICON_UNKNOWN) or nil
			sample.icon:SetTexture(picture)
			sample.icon:SetShown(picture ~= nil)
		end
	end
	return shape
end

-- The bars' fill and the icons' frames, each with a sample at true size, and your health's color. opts.shape: the
-- icons' shape first (the /shy window: it is no part of a theme, so setup leaves it be).
function Parts.finish(parent, width, opts)
	local f = CreateFrame("Frame", nil, parent)
	local shape = opts and opts.shape and Shape(f) or nil
	local top = shape and 46 + ROW_GAP or 0
	local fills = { { value = "auto", text = "By look" } }
	for _, bar in ipairs(Skin.BARS) do fills[#fills + 1] = { value = bar.key, text = bar.name } end
	local bars = UI.Dropdown(f, "Bar fill", fills, Skin.Bar, Skin.SetBar,
		{ width = COL, desc = "The texture that fills every health, power and cast bar. By look uses the one your look comes with." })
	bars:SetPoint("TOPLEFT", 0, -top)
	local swatch = UI.FillSwatch(f, COL, 18)
	swatch:SetPoint("LEFT", bars, "RIGHT", COL_GAP, -11)
	local finishes = { { value = "auto", text = "By look" } }
	for _, style in ipairs(Slot.STYLES) do finishes[#finishes + 1] = { value = style.key, text = style.name } end
	local slots = UI.Dropdown(f, "Icon frames", finishes, Slot.Style, Slot.SetStyle,
		{ width = COL, desc = "The frame around every icon on action buttons, bags, buffs and cooldowns. By look uses the one your look comes with." })
	slots:SetPoint("TOPLEFT", bars, "BOTTOMLEFT", 0, -ROW_GAP)
	local tiles = UI.SlotSwatch(f)
	tiles:SetPoint("LEFT", slots, "RIGHT", COL_GAP, -11)
	local wells = UI.Slider(f, "Icon wells", 0, 100, 5, function() return floor(Slot.WellArt() * 100 + 0.5) end, Slot.SetWellArt,
		{ width = COL, format = function(v) return v .. "%" end, desc = "How solid the art behind empty icons is. Lower lets more show through." })
	wells:SetPoint("TOPLEFT", slots, "BOTTOMLEFT", 0, -ROW_GAP)
	-- Your health's color, made as the accent is: a pick fills the sliders; moving one makes it your own.
	local health = UI.Dropdown(f, "Your health", Skin.HealthPicks(), Skin.HealthColor, Skin.SetHealthColor,
		{ width = COL, desc = "The color of your own health bars, on your frame and under your character." })
	health:SetPoint("TOPLEFT", wells, "BOTTOMLEFT", 0, -ROW_GAP - 8)
	local own
	Shy:On("SHY_HEALTH", function() own = nil end)
	local function HSL()
		if own then return own[1], own[2], own[3] end
		return Skin.HealthHSL()
	end
	local function Move(i, v)
		own = { HSL() }
		own[i] = v
		Skin.SetHealthHSL(own[1], own[2], own[3])
	end
	local SR, LR = Theme.SAT_RANGE, Theme.LIGHT_RANGE
	local function Percent(v) return v .. "%" end
	local hHue = UI.Slider(f, "Hue", 0, 359, 1, function() return (HSL()) end, function(v) Move(1, v) end,
		{ width = COL, format = function(v) return v .. "\194\176" end, desc = "Hue of your health bar." })
	hHue:SetPoint("TOPLEFT", health, "TOPRIGHT", COL_GAP, 0)
	local hSat = UI.Slider(f, "Saturation", SR[1] * 100, SR[2] * 100, 1, function() return floor(select(2, HSL()) * 100 + 0.5) end,
		function(v) Move(2, v / 100) end, { width = COL, format = Percent, desc = "How strong your health bar's color is." })
	hSat:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -ROW_GAP)
	local hLight = UI.Slider(f, "Lightness", LR[1] * 100, LR[2] * 100, 1, function() return floor(select(3, HSL()) * 100 + 0.5) end,
		function(v) Move(3, v / 100) end, { width = COL, format = Percent, desc = "How light your health bar's color is." })
	hLight:SetPoint("TOPLEFT", hSat, "TOPRIGHT", COL_GAP, 0)
	f:SetSize(width, top + 5 * 46 + 4 * ROW_GAP + 8)
	function f:Refresh()
		for _, c in ipairs({ bars, slots, wells, health, hHue, hSat, hLight }) do c:Refresh() end
		swatch:SetFill(Skin.HATCH)
		tiles:SetStyle(nil, nil)
		if shape then
			shape:Refresh()
			shape.Samples()
		end
	end
	f.shape = shape
	return f
end

-- The look's own options (none for some looks), and with opts.background the Background strength.
function Parts.options(parent, width, opts)
	local f = CreateFrame("Frame", nil, parent)
	local Lay
	local options = UI.LookOptions(f, { width = COL, perRow = 2, changed = function() if Lay then Lay() end end })
	options:SetPoint("TOPLEFT")
	local none = UI.Text(f, "", 12, false, C.dim)
	none:SetPoint("TOPLEFT")
	local strength, through, sheet, reads
	if opts and opts.background then
		strength = UI.Slider(f, "Background", 0, 100, 5, function() return floor(Theme.Strength() * 100 + 0.5) end, Theme.StrengthSoon,
			{ width = COL, format = function(v) return v .. "%" end, desc = "How solid the console, chat, quest tracker and HUD boxes are." })
		through = UI.Text(f, "Lower shows more of the world. Tooltips follow it but stay darker.", 12, false, C.dim)
		through:SetPoint("LEFT", strength, "RIGHT", COL_GAP, -9)
		through:SetWidth(width - COL - COL_GAP)
		through:SetWordWrap(true)
		-- The two are set apart: the frame of a window can let the world through without the window's own
		-- words going with it.
		sheet = UI.Slider(f, "Window content", 0, 100, 5, function() return floor(Theme.Sheet() * 100 + 0.5) end, Theme.SheetSoon,
			{ width = COL, format = function(v) return v .. "%" end, desc = "How solid a window's background is." })
		reads = UI.Text(f, "This sits behind a window's rows and text. The frame around them follows Background.", 12, false, C.dim)
		reads:SetPoint("LEFT", sheet, "RIGHT", COL_GAP, -9)
		reads:SetWidth(width - COL - COL_GAP)
		reads:SetWordWrap(true)
	end
	function Lay()
		local y = 0
		if options.count > 0 then
			none:Hide()
			y = options:GetHeight() + ROW_GAP + 8
		else
			none:SetText(UI.LOOK_NAMES[Theme.Look()] .. " has no options of its own.")
			none:Show()
			y = 18 + ROW_GAP
		end
		if strength then
			strength:ClearAllPoints()
			strength:SetPoint("TOPLEFT", 0, -y)
			y = y + 46
			sheet:ClearAllPoints()
			sheet:SetPoint("TOPLEFT", 0, -y)
			y = y + 46
		end
		f:SetSize(width, max(1, y))
	end
	function f:Refresh()
		options:Refresh()
		if strength then strength:Refresh() end
		Lay()
	end
	f:Refresh()
	return f
end

function Chooser.Part(key, parent, width, opts)
	local f = Parts[key](parent, width, opts)
	f.key = key
	Follow(f)
	f:Refresh()
	return f
end

-- The whole flow in one place (the /shy window's Theme room, the setup window's Theme page): the presets, then
-- each part, a tab each. The presets scroll in the room they are given (f:Fit(height) as it changes); a part
-- taller than it makes f taller. opts.perRow: presets to a row (4); opts.shape: the icons' shape with the bars
-- and icons.
--   f.tabs, f.gallery, f.parts[key]
-- A part is made the first time its tab is opened, or it is asked for (f.parts[key]): the presets alone show
-- as the room comes up, and making all five parts with them was most of the room's 170 ms.

local TABS_H = 30

function Chooser.Room(parent, width, room, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	local labels, offered, frames, parts, open = { "Presets" }, {}, {}, {}, 1
	local body = TABS_H + 18
	for _, part in ipairs(Chooser.PARTS) do
		if Chooser.Offered(part.key) then
			offered[#offered + 1] = part
			labels[#labels + 1] = part.name
		end
	end
	-- The part of tab `index` (the presets are the first): made when first asked for.
	local function Made(index)
		local frame, part = frames[index], offered[index - 1]
		if frame or not part then return frame end
		frame = Chooser.Part(part.key, f, width, { background = true, shape = opts.shape })
		frame:SetPoint("TOPLEFT", 0, -body)
		frame:SetShown(open == index)
		frames[index] = frame
		rawset(parts, part.key, frame)
		return frame
	end
	setmetatable(parts, { __index = function(_, key)
		for i, part in ipairs(offered) do
			if part.key == key then return Made(i + 1) end
		end
	end })
	local tabs = UI.Tabs(f, labels, function(i)
		open = i
		Made(i)
		for j = 1, #labels do
			if frames[j] then frames[j]:SetShown(j == i) end
		end
		if f.Refresh then f:Refresh() end
	end, width, 15)
	tabs:SetPoint("TOPLEFT")
	local gallery = Chooser.Gallery(f, width, { perRow = opts.perRow or 4, height = room - body })
	gallery:SetPoint("TOPLEFT", 0, -body)
	frames[1] = gallery
	function f:Refresh()
		local shown = frames[open] or Made(open)
		shown:Refresh()
		self:SetSize(width, max(room, body + shown:GetHeight()))
	end
	function f:Fit(height)
		room = height
		gallery:Fit(height - body)
		self:Refresh()
	end
	f.tabs, f.gallery, f.parts = tabs, gallery, parts
	tabs:Select(1)
	return f
end

if Shy.HubSection then
	Shy.HubSection("theme", function(page, top)
		local room = Chooser.Room(page, page.width, page:GetHeight() - UI.LEAD_H - 6, { shape = true })
		Shy.HubPlace(page, room, top)
		-- The presets scroll in the room: the page takes the window's height, and gives it on.
		function page:Fit(height) room:Fit(height - 6) end
		page.theme = room
		return room, function() room:Refresh() end
	end)
	-- The preset worn (or that it is your own mix), and the look.
	Shy.HubBrief("theme", function()
		local worn = Theme.PresetWorn()
		local preset = worn ~= "own" and Named(Theme.PRESETS, worn)
		local look = UI.LOOK_NAMES[Theme.Look()]
		if preset and preset ~= look then return preset .. ", " .. look end
		return preset or (look and ("Your own, " .. look)) or nil
	end)
end

-- The setup window's step: the same room as its page, the presets and every part a tab each. Its picks are the
-- plan's `theme`, read from what is worn as they go on (every pick is put on at once), and what was worn is
-- put back when the window closes without Finish.

local S = Shy.Setup
if not (S and S.Step) then return end

local planned   -- the plan the window is showing

local function Capture()
	if not (planned and planned.theme and S.IsOpen and S.IsOpen()) then return end
	local was, wasWells = planned.theme.wasStrength, planned.theme.wasWells
	planned.theme = Chooser.Snapshot()
	planned.theme.wasStrength, planned.theme.wasWells = was, wasWells
end
for _, event in ipairs(EVENTS) do Shy:On(event, Capture) end

-- The page is the whole width: the screen behind the window shows every pick as it goes on.
local function ThemePage(parent, width, plan, room)
	planned = plan
	return Chooser.Room(parent, width, room or 494, { perRow = 5 })
end

-- The plan's lines on the last page: the preset (or your own), the look, the color, and any part apart from them.
local function Lines(plan)
	local t = plan.theme
	local lines = { { text = "The " .. UI.LOOK_NAMES[t.look] .. " look", sub = (UI.LOOK_WORDS[t.look]:gsub("%.$", ""):gsub("^%u", string.lower)) } }
	local worn = Theme.PresetWorn({ look = t.look, accent = t.pick, bar = t.bar, slot = t.slot, health = t.health,
		gradient = Theme.GradientKey(t.gradient), font = t.font, options = t.options })
	local desc = Named(Theme.PRESETS, worn, "desc")
	if desc then table.insert(lines, 1, { text = "The " .. Named(Theme.PRESETS, worn) .. " preset", sub = (desc:gsub("%.$", ""):gsub("^%u", string.lower)) }) end
	if t.pick == "custom" then
		lines[#lines + 1] = { text = "In a color of your own",
			sub = ("%d\194\176, %d%% saturated, %d%% light"):format(t.hue, floor(t.sat * 100 + 0.5), floor(t.light * 100 + 0.5)) }
	elseif t.pick == "class" then
		lines[#lines + 1] = { text = "In your class color", sub = UnitClass("player") }
	elseif t.pick == "gradient" then
		local key = Theme.GradientKey(t.gradient)
		lines[#lines + 1] = { text = "In a gradient", sub = key and Named(Theme.GRADIENTS, key) or "of your own" }
	else
		local said = Named(Theme.Picks(), t.pick, "text")
		if said then lines[#lines + 1] = { text = "In " .. said } end
	end
	if t.font and t.font ~= Theme.FONT and FontName(t.font) then lines[#lines + 1] = { text = "Lettered in " .. FontName(t.font) } end
	if t.bar ~= "auto" then
		local said = Named(Skin.BARS, t.bar)
		if said then lines[#lines + 1] = { text = "Bars filled with " .. said:lower(), sub = "on every look" } end
	end
	if t.slot ~= "auto" then
		local said = Named(Slot.STYLES, t.slot)
		if said then lines[#lines + 1] = { text = said .. " icon frames", sub = "on every look" } end
	end
	if t.strength ~= t.wasStrength then lines[#lines + 1] = { text = "Background " .. t.strength .. "%", sub = "on everything on screen" } end
	if t.wells and t.wells ~= t.wasWells then lines[#lines + 1] = { text = "Icon wells " .. t.wells .. "%", sub = "the art under every icon" } end
	return lines
end

S.Step({
	id = "theme", order = 15, title = "Theme", glyph = "star",
	ask = "Pick a theme",
	lead = "Pick a ready-made theme, or change the parts you want. You'll see it on your screen right away.",
	brief = function(plan)
		local t = plan.theme
		local worn = Theme.PresetWorn({ look = t.look, accent = t.pick, bar = t.bar, slot = t.slot, health = t.health,
			gradient = Theme.GradientKey(t.gradient), font = t.font, options = t.options })
		local preset, look = Named(Theme.PRESETS, worn), UI.LOOK_NAMES[t.look]
		if preset and preset ~= look then return preset .. ", " .. look end
		return preset or ("Your own, " .. look)
	end,
	Plan = function(plan)
		plan.theme = Chooser.Snapshot()
		plan.theme.wasStrength, plan.theme.wasWells = plan.theme.strength, plan.theme.wells
		planned = plan
	end,
	Build = ThemePage,
	Lines = Lines,
	Run = function(plan)
		local answers = plan.theme
		if S.Act(plan) == "stay" then Chooser.Wear(answers) else S.Wait("theme", answers) end
		return false
	end,
	Later = Chooser.Wear,
	-- Live: what was worn before the window opened, put back when it closes without Finish.
	Worn = Chooser.Snapshot,
	PutBack = Chooser.Wear,
})
