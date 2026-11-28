-- A quest's page in a window of its own (QuestLogPopupDetailFrame): "Open Quest Details" on a tracked quest opens
-- the log's page for it by itself, on parchment, in a stone window. Here it is one of the family's windows: the
-- page's words light, the rewards' own among them, and the log's buttons under them. The game leaves its title
-- strip empty: it says what the window is.
-- Some quests have a page of their own (a letter, a notice: the quest's theme, which the game reads with
-- C_QuestLog.GetQuestDetailsTheme): the game lays that paper behind the words (SealMaterialBG) and closes them
-- with a seal and a signature. Such a quest keeps its page: the paper shows as the game lays it, and the words
-- stay in the ink the game writes on paper in.
-- QuestInfo's font strings are shared between windows and dark for parchment. Blizzard only recolors most of them
-- when the material changes, so each one's color is kept and given back when they leave this window (the quest
-- giver's window has them next). No field is written on a Blizzard frame or table (weak tables here), and every
-- hook is a post-hook.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors

local KEY = { 0, 5, 0, 5 }        -- the Show Map button's plate in its 32 tall button
local GAP = { 1, 0, 1, 0 }        -- inset between the three buttons under the page

-- Blizzard's textures on a frame, listed on first sight, before any of ours is added.
local theirs = setmetatable({}, { __mode = "k" })
local FACES = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local function Art(frame)
	local list = theirs[frame]
	if not list then
		list = {}
		local listed = {}
		local function Add(texture)
			if texture and not listed[texture] then
				listed[texture] = true
				list[#list + 1] = texture
			end
		end
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:IsObjectType("Texture") then Add(region) end
		end
		-- A button's state textures may not be among its regions.
		if frame:IsObjectType("Button") then
			for _, face in ipairs(FACES) do Add(frame[face](frame)) end
		end
		theirs[frame] = list
	end
	return list
end

local function HideArt(kit, frame)
	for _, texture in ipairs(Art(frame)) do kit:Hide(texture) end
end

-- Sets a font object, keeping the string's color: a font object brings its own. The color goes through the kit
-- first, so Restore returns Blizzard's.
local function Face(kit, fontString, object)
	if not kit:Has(fontString) then
		local r, g, b = fontString:GetTextColor()
		kit:Text(fontString, { r, g, b })
	end
	local r, g, b = fontString:GetTextColor()
	kit:FontObject(fontString, object)
	fontString:SetTextColor(r, g, b)
end

-- Our own font string.
local function Words(kit, owner, key, object)
	return ns.Own(kit, owner, key, function(o)
		return UI.Words(o, object, nil, { wrap = false })
	end)
end

-- The quest's own paper shows where it has one (true); else none.
local function Paper(kit, holder)
	local paper = holder.SealMaterialBG
	local atlas = paper:IsShown() and paper:GetAtlas() or nil
	local papered = atlas ~= nil and atlas ~= ""
	kit:Fade(paper, papered and 1 or 0)
	return papered
end

local lit = setmetatable({}, { __mode = "k" })   -- font string -> { was = Blizzard's color, now = ours }

local function Same(r, g, b, c)
	return math.abs(r - c[1]) < 0.01 and math.abs(g - c[2]) < 0.01 and math.abs(b - c[3]) < 0.01
end

local function Lighten(fontString, heading)
	if not fontString then return end
	local r, g, b = fontString:GetTextColor()
	local was = lit[fontString]
	if was and Same(r, g, b, was.now) then return end   -- still as we left it
	local color
	if Same(r, g, b, { QUEST_OBJECTIVE_COMPLETED_FONT_COLOR:GetRGB() }) then
		color = UI.colors.good
	elseif 0.299 * r + 0.587 * g + 0.114 * b < 0.5 then
		color = heading and UI.colors.head or UI.colors.text
	else
		lit[fontString] = nil   -- already light
		return
	end
	lit[fontString] = { was = { r, g, b }, now = { color[1], color[2], color[3] } }
	fontString:SetTextColor(color[1], color[2], color[3])
end

local function Darken()
	for fontString, e in pairs(lit) do
		local r, g, b = fontString:GetTextColor()
		if Same(r, g, b, e.now) then fontString:SetTextColor(e.was[1], e.was[2], e.was[3]) end
	end
	wipe(lit)
end

local function LightenPage()
	Lighten(QuestInfoTitleHeader, true)
	Lighten(QuestInfoDescriptionHeader, true)
	Lighten(QuestInfoObjectivesHeader, true)
	Lighten(QuestInfoQuestType)
	Lighten(QuestInfoObjectivesText)
	Lighten(QuestInfoTimerText)
	Lighten(QuestInfoSpellObjectiveLearnLabel)
	Lighten(QuestInfoRequiredMoneyText)
	Lighten(QuestInfoGroupSize)
	Lighten(QuestInfoDescriptionText)
	Lighten(QuestInfoRewardText)
	Lighten(QuestInfoSealFrame.Text)
	for _, objective in ipairs(QuestInfoObjectivesFrame.Objectives) do Lighten(objective) end
	local rewards = QuestInfoRewardsFrame
	Lighten(rewards.Header, true)
	Lighten(rewards.ItemChooseText)
	Lighten(rewards.ItemReceiveText)
	Lighten(rewards.PlayerTitleText)
	Lighten(rewards.QuestSessionBonusReward)
	Lighten(rewards.XPFrame.ReceiveText)
end

-- Where QuestInfo's text stands while it is in the page's window.
local function PageWords()
	return QuestLogPopupDetailFrame.ScrollFrame.ScrollChild
end

local function InPage()
	return QuestInfoTitleHeader:GetParent() == PageWords()
end

-- QuestInfo's words, inked for where they stand now: light on a page of ours, the game's own ink on a quest's own
-- paper, and the game's again anywhere else (the quest giver's window).
local function InkQuest(m, parent)
	if m.on and parent == PageWords() then
		if Paper(m.kit, QuestLogPopupDetailFrame) then Darken() else LightenPage() end
	else
		Darken()
	end
end

local function PaintPage(kit)
	local page = QuestLogPopupDetailFrame
	HideArt(kit, page)   -- the stone, the parchment, the book in the corner
	Paper(kit, page)     -- (a quest's own paper stays)
	local set = ns.Window(kit, page, { portrait = false })
	kit:Hide(page.Inset.NineSlice)
	kit:Hide(page.Inset.Bg)
	ns.ScrollBar(kit, page.ScrollFrame.ScrollBar)

	local title = Words(kit, page.TitleContainer, "title", UI.TitleFont(UI.HEAD.window.text))
	title:ClearAllPoints()
	title:SetPoint("LEFT", set.titleText, "LEFT", 0, 0)
	title:SetText(QUEST_LOG)
	title:SetTextColor(UI.TitleInk(C.text))
	if set.look then UI.LookTitle(set.look, title) end   -- these are the window's title, not the game's empty one

	-- Show Map: the game's picture of a map beside the words gives way to a button with the words on it.
	local show = page.ShowMapButton
	kit:Hide(show.Texture)
	kit:Hide(show.Highlight)
	kit:Key(show, { inset = KEY })
	Face(kit, show.Text, UI.TextFont(12))
	kit:Text(show.Text, C.text)
	kit:Place(show.Text, nil, nil, { "CENTER", show, "CENTER", 0, 0 })

	ns.Button(kit, page.AbandonButton, GAP)
	ns.Button(kit, page.ShareButton, GAP)
	ns.Button(kit, page.TrackButton, GAP)
end

ns.Module({
	id = "questpage",
	title = "Quest pages",
	desc = "A quest's page opened from the tracker matches your theme, with light text.",
	group = "window",
	words = "quest log details",

	Ready = function()
		return QuestLogPopupDetailFrame ~= nil and ns.Window ~= nil
	end,

	Hook = function(m)
		hooksecurefunc("QuestInfo_Display", function(_, parent) InkQuest(m, parent) end)
	end,

	-- Not tracked by the kit: the quest text's colors.
	Clear = function()
		Darken()
	end,

	Paint = function(m, kit)
		PaintPage(kit)
		if InPage() then InkQuest(m, QuestInfoTitleHeader:GetParent()) end
	end,
})
