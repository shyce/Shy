-- Skins Blizzard's objective tracker to match the card: a panel behind it, fonts, colors, markers, the
-- quest item in a slot, bars.
--
-- THE TRACKER MUST STAY UNTAINTED: its quest-item buttons call the protected UseQuestLogSpecialItem.
--   * Nothing is written on a tracker table; state is kept in our own tables keyed by Blizzard's regions.
--   * No layout function, Update or MarkDirty is called. A relayout is requested only through
--     C_QuestLog.SortQuestWatches().
--   * OBJECTIVE_TRACKER_COLOR is read, never changed: the layout reads it back.
--   * Only regions are touched (color, alpha, art, placement) through a Shy.Skin kit, plus our own
--     textures. The tracker sizes itself from measured text, never from what is drawn on a block.
--   * Hook the sections with hooksecurefunc, never the container: it keeps a copy of Update.
--
-- Fonts: every line inherits ObjectiveTrackerLineFont / ObjectiveTrackerHeaderFont, which the game
-- re-points on an Edit Mode text size change (ObjectiveTrackerManager:SetTextSize). Re-pointing those
-- keeps the tracker's measuring right; font strings are never given fonts one by one.
--
-- Colors: Blizzard recolors a line only when its colorStyle changes, so each line is given our color
-- for its style after every block layout and header enter / leave. With "color titles by difficulty"
-- on, a title's color is in its text and stays.
--
-- Markers: Blizzard re-sets a marker's art in POIButtonMixin:UpdateButtonStyle, so each is post-hooked.
--
-- The panel is our own frame behind the tracker, from its title to the last shown section. Its
-- strength is the core's background setting; at zero there is no panel and the title keeps a line.
--
-- From the top of the tracker's title (32 high): 5 panel edge, 7..25 title strip, 25..27 line,
-- 38 first section name (26 high, a line 22 under its top).
--
-- Not skinned: positions and spacing, the key binding on a quest item (the fonts lack the range dot),
-- the "find a group" eye, and the boxes and bars of scenario and bonus sections.

local ADDON, ns = ...
local T = ns.T
local UI, Skin, B = Shy.UI, Shy.Skin, Shy.Brand
local C, P = Skin.colors, UI.colors
local L = {}
ns.Look = L

local kit = Skin.NewKit()
local ready, on, hooked = false, false, false
local size = 12              -- the tracker's text size (Edit Mode: 12 to 20)
local modules = {}           -- the tracker's sections
local styles = {}            -- Blizzard color style -> our color
local under                  -- the panel's frame

local CLEAR, WHITE = { 0, 0, 0, 0 }, { 1, 1, 1 }
local GLYPH = Skin.GLYPH
local CHECK = Shy.MEDIA .. "GlyphCheck"   -- drawn for the tracker's 16 units (the card's Check is for 10)
local MARKS = ns.MARKS_SMALL
local PLATE, PLATE_LIT, ASK = ns.MarkPicture("badge"), ns.MarkPicture("lit"), ns.MarkPicture("?")
local EMBLEM = {}            -- an objective's emblem, by kind (Marks.lua, KIND)
for kind in pairs(ns.KIND) do EMBLEM[ns.ToneSign(kind)] = ns.MarkPicture(ns.ToneSign(kind)) end
local CHECK_ATLAS = "ui-questtracker-tracker-check"

-- Every section the tracker can hold (ObjectiveTrackerManager:Init).
local MODULES = {
	"ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "CampaignQuestObjectiveTracker",
	"QuestObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
	"MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
	"BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}

local STRIP = UI.HEAD.piece.line - 2                          -- title strip height, inside the panel's edge
local GROUND = { left = 18, top = 5, right = 4, bottom = 8 }  -- the panel's reach past the tracker
local TOP_LINE, SUB_LINE = 25, 22                             -- a line's drop under its header's top
local TOP_GLYPH = { 2, 2.5, 2, 2.5 }                          -- a 14 box in the title's 18 x 19 fold button
local SUB_GLYPH = { 1, 1, 1, 1 }                              -- and in a section's 16 x 16 one
local GLYPH_SIZE = 11
local MARK = 17                                               -- marker plate, and what stands on it (Blizzard's is 24)
local LIGHT = 0.3                                             -- strength of the hover light behind a title
local MIN_SIZE, MAX_SIZE = 12, 20                             -- text sizes the game accepts

-- A failed line under the mouse.
local HOT_BAD = { P.bad[1] + (1 - P.bad[1]) * 0.4, P.bad[2] + (1 - P.bad[2]) * 0.4, P.bad[3] + (1 - P.bad[3]) * 0.4 }

-- Fonts

-- Quest text is localized: a font family covering every alphabet.
local function LineFont()
	return UI.NameFont(size - 1)
end

local function HeadFont()
	return UI.TitleFont(size)
end

-- The current text size, from the font the line font points at ("ObjectiveTrackerFont12" to "...20").
local function ReadSize()
	local font = ObjectiveTrackerLineFont:GetFontObject()
	local name = font and font:GetName()
	local n = name and tonumber(name:match("^ObjectiveTrackerFont(%d+)$"))
	if n and n >= MIN_SIZE and n <= MAX_SIZE then size = n end
end

local function Fonts()
	if on then
		ObjectiveTrackerLineFont:SetFontObject(LineFont())
		ObjectiveTrackerHeaderFont:SetFontObject(HeadFont())
		UI.Follow(ObjectiveTrackerHeaderFont)   -- the headers keep up with the theme's font
	else
		-- As ObjectiveTrackerManager:SetTextSize points them.
		ObjectiveTrackerLineFont:SetFontObject("ObjectiveTrackerFont" .. size)
		ObjectiveTrackerHeaderFont:SetFontObject("ObjectiveTrackerFont" .. (size + 2))
	end
	-- A font object brings its own alignment and shadow: restore those of Blizzard_ObjectiveTrackerFonts.xml.
	for _, font in ipairs({ ObjectiveTrackerLineFont, ObjectiveTrackerHeaderFont }) do
		font:SetJustifyH("LEFT")
		font:SetJustifyV("TOP")
		font:SetShadowOffset(1, -1)
		font:SetShadowColor(0, 0, 0, 1)
	end
	if not on then ObjectiveTrackerHeaderFont:SetTextColor(NORMAL_FONT_COLOR:GetRGB()) end
end

-- Heights were measured in the other font: make the game lay the tracker out again. That sorts by
-- distance, so the route order is refreshed after it (Tracker.lua).
local function Relayout()
	C_QuestLog.SortQuestWatches()
	ns.Refresh()
end

-- Text colors

local inked = setmetatable({}, { __mode = "k" })   -- font strings we colored

-- A style that isn't one of the tracker's nine keeps Blizzard's color.
local function Ink(fontString)
	local color = styles[fontString.colorStyle]
	if not color then return end
	inked[fontString] = true
	fontString:SetTextColor(color[1], color[2], color[3])
end

-- Restore each font string's color from its own style.
local function Unink()
	for fontString in pairs(inked) do
		local style = fontString.colorStyle
		if style then fontString:SetTextColor(style.r, style.g, style.b) end
	end
	wipe(inked)
end

-- Blocks

local lights = setmetatable({}, { __mode = "k" })   -- title button -> hover light

-- In the HIGHLIGHT layer, so the engine shows it only under the mouse.
local function Light(button)
	local light = lights[button]
	if not light then
		light = button:CreateTexture(nil, "HIGHLIGHT")
		light:SetTexture(B.GLOW)
		light:SetBlendMode("ADD")
		light:SetPoint("TOPLEFT", button, "TOPLEFT", -12, 3)
		light:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 12, -4)
		lights[button] = light
	end
	light:SetVertexColor(C.hover[1] * LIGHT, C.hover[2] * LIGHT, C.hover[3] * LIGHT)
	light:Show()
end

-- Replaces Blizzard's check. Any other atlas a section sets on the same texture later is left as it is.
local function PaintCheck(icon)
	if not icon:IsObjectType("Texture") then return end   -- some sections keep another object under this key
	local atlas = icon:GetAtlas()
	if not atlas or atlas == "" then return end   -- already ours
	if atlas:lower() ~= CHECK_ATLAS then
		if kit:Has(icon) then kit:Tint(icon, WHITE, true) end
		return
	end
	kit:Art(icon, CHECK, { color = P.good })
end

-- Colors only: all that changes on hover.
local function PaintText(block)
	if block.HeaderText then Ink(block.HeaderText) end
	if not block.usedLines then return end
	local dash = block.isHighlighted and P.text or P.dim
	for _, line in pairs(block.usedLines) do
		if line.Text then Ink(line.Text) end
		if line.Dash then kit:Text(line.Dash, dash) end
	end
end

local PaintMarker, PaintItem, PaintBar
local PaintBlock
local lead                                -- the card's leading quest (L.SetLead)

local markers = setmetatable({}, { __mode = "k" })   -- markers already hooked

-- Our own marker where Blizzard shows none: a block only has a POI button while the world map's
-- "Show Quest Objectives" filter is on (questPOI; ObjectiveTrackerManager:CanShowPOIs).
local owned = setmetatable({}, { __mode = "k" })     -- block -> our mark
local function OwnMarker(block, wanted)
	local id = wanted and block.poiQuestID
	local mark = owned[block]
	if not id then
		if mark then mark:Hide() end
		return
	end
	if not mark then
		mark = ns.CreateMark(block, MARK)
		mark:SetMouseMotionEnabled(true)
		mark:SetMouseClickEnabled(true)
		mark:SetScript("OnEnter", function(self)
			self:SetHovered(true)
			if T.db.tips == false then return end
			local lines = ns.Tips.Lines()
			ns.Tips.Quest(lines, self.id, true)
			if #lines == 0 then return end
			local pointed = Shy.Waypoint.QuestID() == self.id
			ns.Tips.Open(self, lines, { side = "LEFT", hints = { { "left", pointed and "Let the game choose" or "Point the way" } } })
		end)
		mark:SetScript("OnLeave", function(self)
			self:SetHovered(false)
			ns.Tips.Close(self)
		end)
		mark:SetScript("OnMouseUp", function(self, button)
			if button ~= "LeftButton" or not self.id then return end
			Shy.Waypoint.Quest(Shy.Waypoint.QuestID() == self.id and 0 or self.id)
		end)
		owned[block] = mark
	end
	mark.id = id
	mark:ClearAllPoints()
	-- Where Blizzard anchors its marker.
	mark:SetPoint("CENTER", block.HeaderText or block, "TOPLEFT", -17, -5)
	mark:Set(block.poiIsComplete and "turnin" or "goal", block.poiIsSuperTracked or id == lead, nil, ns.QuestKind(id))
	mark:Show()
end

-- The card's leading quest (from Tracker.lua): its marker takes the focus color.
function L.SetLead(id)
	if id == lead then return end
	local was = lead
	lead = id
	if not on then return end
	-- Repaint the markers directly: PaintBlock skips a marker it has painted. pairs, since `was` may be nil.
	for _, quest in pairs({ was, id }) do
		local block = QuestObjectiveTracker and QuestObjectiveTracker:GetExistingBlock(quest)
		if type(block) == "table" and block:IsShown() then
			if block.poiButton then PaintMarker(block.poiButton) end
			OwnMarker(block, block.poiButton == nil)
		end
	end
end

function PaintBlock(block)
	PaintText(block)
	if block.HeaderButton then Light(block.HeaderButton) end
	if block.HeaderGlow and not kit:Has(block.HeaderGlow) then kit:Tint(block.HeaderGlow, P.hot) end
	if block.usedLines then
		for _, line in pairs(block.usedLines) do
			if line.Icon then PaintCheck(line.Icon) end
			if line.CheckGlow and not kit:Has(line.CheckGlow) then kit:Tint(line.CheckGlow, P.good) end
			if line.Glow and not kit:Has(line.Glow) then kit:Tint(line.Glow, P.hot) end
		end
	end
	local marker = block.poiButton
	if marker then
		if not markers[marker] then
			markers[marker] = true
			-- Blizzard re-sets a marker's art when super-tracking changes.
			hooksecurefunc(marker, "UpdateButtonStyle", function(self)
				if on then PaintMarker(self) end
			end)
			PaintMarker(marker)
		elseif not kit:Has(marker.NormalTexture) then
			PaintMarker(marker)
		end
	end
	OwnMarker(block, marker == nil)
	if block.ItemButton then PaintItem(block.ItemButton) end
	-- Progress and timer bars under a line.
	if block.addedRegions then
		for region in pairs(block.addedRegions) do
			if region.Bar and region.Bar.BorderMid then PaintBar(region) end
		end
	end
end

-- Markers

function PaintMarker(button)
	local center = { "CENTER", button, "CENTER", 0, 0 }
	local style = button.style
	local ready = style == POIButtonUtil.Style.QuestComplete
	local M = ns.MARK
	-- Colors as Marks.lua: gold when ready to turn in, steel otherwise, hover under the mouse. The
	-- super-tracked or leading quest is the focus color, or, while it is being worked on, the plate lit
	-- in the color of what it asks for next (KIND).
	local selected = button.selected or (lead ~= nil and button.questID == lead)   -- questID: POIButtonMixin:SetQuestID
	local tone = style == POIButtonUtil.Style.QuestInProgress and (button.questID and ns.QuestKind(button.questID) or "go") or nil
	local worked = tone ~= nil and selected
	local plate = (ready or worked) and PLATE_LIT or PLATE
	kit:Art(button.NormalTexture, MARKS, { coords = plate, color = worked and ns.ToneColor(tone) or selected and M.focus or ready and M.gold or M.steel })
	kit:Place(button.NormalTexture, MARK, MARK, center)
	kit:Art(button.PushedTexture, MARKS, { coords = plate, color = M.hover })
	kit:Place(button.PushedTexture, MARK, MARK, center)
	kit:Art(button.HighlightTexture, MARKS, { coords = plate, color = M.hover, blend = "BLEND" })
	kit:Place(button.HighlightTexture, MARK, MARK, center)
	kit:Hide(button.Glow)

	local display = button.Display
	local icon = display.Icon
	local middle = { "CENTER", display, "CENTER", 0, 0 }
	if ready then
		kit:Art(icon, MARKS, { coords = ASK, color = selected and WHITE or M.onGold })
		kit:Place(icon, MARK, MARK, middle)
	elseif tone then
		-- The emblem of what the quest asks for next, in its color (Marks.lua, KIND).
		kit:Art(icon, MARKS, { coords = EMBLEM[ns.ToneSign(tone)], color = worked and M.graphite or ns.ToneColor(tone) })
		kit:Place(icon, MARK, MARK, middle)
	elseif kit:Has(icon) then
		-- Another style (a lock, a direction): Blizzard's picture, untinted.
		kit:Tint(icon, WHITE, true)
	end
end

-- Quest item and bars

-- kit:Tile (Shy.Slot). Regions only: this is the protected button.
function PaintItem(button)
	local normal = button:GetNormalTexture()
	if kit:Has(normal) then return end
	kit:Hide(normal)
	kit:Hide(button:GetHighlightTexture())
	kit:Lit(button:GetPushedTexture(), button, C.lit)
	-- Blizzard flashes Glow while the item can be used here.
	kit:Piece(button.Glow, "glow", button, { x = -2, y = -2, color = P.hot, blend = "ADD" })
	kit:Tile(button, { icon = button.icon })
	kit:Swipe(button.Cooldown)
	kit:Font(button.Count, Shy.FONT_ROUNDED, nil, "OUTLINE")
end

local barColors = setmetatable({}, { __mode = "k" })   -- bar -> Blizzard's color

-- ObjectiveTrackerProgressBarTemplate and ObjectiveTrackerTimerBarTemplate.
function PaintBar(frame)
	local bar = frame.Bar
	if kit:Has(bar) then return end
	local track = kit:Bar(bar).track
	local fill = bar:GetStatusBarTexture()
	for _, region in ipairs({ bar:GetRegions() }) do
		if region ~= fill and region ~= track and region:IsObjectType("Texture") then kit:Hide(region) end
	end
	kit:Plate(bar, { x = -1, y = -1, fill = CLEAR })
	if not barColors[bar] then barColors[bar] = { bar:GetStatusBarColor() } end
	bar:SetStatusBarColor(Shy.Theme.Accent())
	local label = bar.Label or frame.Label
	if label then kit:Font(label, Shy.FONT_ROUNDED, 11, "OUTLINE") end
end

local function ResetBars()
	for bar, color in pairs(barColors) do bar:SetStatusBarColor(color[1], color[2], color[3], color[4]) end
	wipe(barColors)
end

-- Headers

-- Blizzard re-sets a collapse button's art on every toggle, so it is faded out and the glyph is ours.
local function PaintFold(button, folded, inset)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Plate(button, { inset = inset, fill = CLEAR, border = CLEAR, hover = true,
		icon = folded and GLYPH.plus or GLYPH.minus, iconSize = GLYPH_SIZE })
end

-- An accent line across a header, `drop` under its top: the header's own (thin: a section's rule, 1 thick).
local function HeaderLine(header, drop, thin)
	local line = kit:Line(header, header).line
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -drop)
	line:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, -drop)
	if thin then
		UI.LineFit(line, false)
		line:SetHeight(1)
	end
end

-- A section header ("Quests").
local function PaintHeader(module)
	local header = module.Header
	-- Blizzard animates this background's alpha, so it is given nothing to draw instead of being faded.
	kit:Art(header.Background, CLEAR)
	kit:Text(header.Text, C.text)
	kit:Tint(header.Glow, P.hot)
	kit:Tint(header.Shine, P.hot)
	PaintFold(header.MinimizeButton, module.isCollapsed, SUB_GLYPH)
	HeaderLine(header, SUB_LINE, true)
end

-- The tracker's title ("All Objectives").
local function PaintTitle(grounded)
	local header = ObjectiveTrackerFrame.Header
	kit:Art(header.Background, CLEAR)
	kit:Text(header.Text, C.text)
	PaintFold(header.MinimizeButton, ObjectiveTrackerFrame.isCollapsed, TOP_GLYPH)
	-- The panel's title strip has its own line.
	if not grounded then HeaderLine(header, TOP_LINE) end
end

-- The panel

local function Under()
	if not under then
		under = CreateFrame("Frame", nil, ObjectiveTrackerFrame)
		under:SetFrameStrata("BACKGROUND")   -- under the whole tracker
	end
	return under
end

-- From the title to the last shown section, or the title strip alone when collapsed.
local function Refit()
	if not (on and under) then return end
	local frame = ObjectiveTrackerFrame
	local header = frame.Header
	local last
	if not frame.isCollapsed then
		for _, module in ipairs(frame.modules) do
			if module:IsShown() then last = module end
		end
	end
	under:ClearAllPoints()
	under:SetPoint("TOP", header, "TOP", 0, -GROUND.top)
	under:SetPoint("LEFT", frame, "LEFT", -GROUND.left, 0)
	under:SetPoint("RIGHT", frame, "RIGHT", GROUND.right, 0)
	if last then
		under:SetPoint("BOTTOM", last, "BOTTOM", 0, -GROUND.bottom)
	else
		under:SetPoint("BOTTOM", header, "BOTTOM", 0, 0)
	end
end

-- The last shown section is only known after Blizzard has updated them all: refit next frame.
local pending
local function RefitSoon()
	if pending then return end
	pending = true
	C_Timer.After(0, function()
		pending = false
		Refit()
	end)
end

local function PaintGround(strength)
	-- Blizzard's tracker background (Edit Mode "Opacity") is replaced.
	kit:HideRegions(ObjectiveTrackerFrame.NineSlice)
	if strength <= 0 then return end
	kit:Plate(Under(), { key = "ground", panel = true, brackets = 10, title = STRIP, hud = true })
end

-- The core's background strength setting.
local function Strength()
	return Shy.Theme.Strength()
end

local function Paint()
	local strength = Strength()
	PaintGround(strength)
	PaintTitle(strength > 0)
	for _, module in ipairs(modules) do
		PaintHeader(module)
		for _, blocks in pairs(module.usedBlocks) do
			for _, block in pairs(blocks) do PaintBlock(block) end
		end
	end
	Refit()
end

-- Restore Blizzard's look.
local function Clear()
	kit:Restore()
	Unink()
	ResetBars()
	for _, light in pairs(lights) do light:Hide() end
	for _, mark in pairs(owned) do mark:Hide() end
end

local function Hook()
	if hooked then return end
	hooked = true
	for _, module in ipairs(modules) do
		hooksecurefunc(module, "LayoutBlock", function(_, block)
			if on then PaintBlock(block) end
		end)
		-- Blizzard recolors the block on header enter and leave.
		hooksecurefunc(module, "OnBlockHeaderEnter", function(_, block)
			if on then PaintText(block) end
		end)
		hooksecurefunc(module, "OnBlockHeaderLeave", function(_, block)
			if on then PaintText(block) end
		end)
		hooksecurefunc(module, "SetCollapsed", function(self)
			if on then PaintHeader(self) end
		end)
		hooksecurefunc(module, "Update", function()
			if on then RefitSoon() end
		end)
	end
	hooksecurefunc(ObjectiveTrackerFrame, "SetCollapsed", function()
		if not on then return end
		PaintTitle(Strength() > 0)
		Refit()
	end)
	-- An Edit Mode text size change re-points the fonts at Blizzard's and lays the tracker out in them.
	hooksecurefunc(ObjectiveTrackerManager, "SetTextSize", function(_, textSize)
		if not on or textSize < MIN_SIZE or textSize > MAX_SIZE then return end
		size = textSize
		Fonts()
		Clear()
		Paint()
		Relayout()
	end)
end

-- Apply the settings. Safe in combat: no protected frame is touched.
-- atLogin: the tracker hasn't been laid out yet, so no relayout is needed.
function L.Apply(atLogin)
	if not ready then return end
	local was = on
	-- Not while the other quest addon's tracker stands in for this one (Yield.lua): it is out of sight.
	on = T.db.look.on and not (ns.Yield ~= nil and ns.Yield.To("tracker"))
	Clear()
	if on ~= was then
		if on then ReadSize() end   -- while the fonts are still Blizzard's
		Fonts()
		if atLogin ~= true then Relayout() end
	end
	if on then
		Hook()
		Paint()
	end
	-- For ShyDock's layout: how far the panel reaches past the tracker's frame (left, top, right, bottom). The
	-- same whatever the Background setting, as chat's: the minimap and the column stay put as it is dragged.
	-- Said when it comes or goes (the minimap is as wide as this panel); at login whoever reads it reads it after.
	local had = Shy.wings.tracker ~= nil
	Shy.wings.tracker = on and { GROUND.left, GROUND.top, GROUND.right, GROUND.bottom } or nil
	if had ~= (on and true or false) and atLogin ~= true then Shy:Fire("SHY_WINGS") end
end
ns.ApplyLook = function() L.Apply() end

Shy:On("SHY_LOGIN", function()
	local O = OBJECTIVE_TRACKER_COLOR
	styles[O.Normal], styles[O.NormalHighlight] = P.dim, P.text
	styles[O.Complete] = P.good
	styles[O.Failed], styles[O.FailedHighlight] = P.bad, HOT_BAD
	styles[O.TimeLeft], styles[O.TimeLeftHighlight] = P.bad, HOT_BAD
	styles[O.Header], styles[O.HeaderHighlight] = P.text, P.hot
	for _, name in ipairs(MODULES) do modules[#modules + 1] = _G[name] end
	ready = true
	L.Apply(true)
end)

-- What a kit painted keeps its colors: repaint on a theme change.
Shy:On("SHY_THEME", function() L.Apply() end)
