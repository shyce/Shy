-- What you read: books, letters, plaques and gravestones (ItemTextFrame). The window is the family's, titled with
-- what is read, as the game names it. The page is the game's own and stays so: every text keeps the paper or the
-- stone it is written on (parchment, a great book's spread, stone, marble, silver, bronze) and the ink the game
-- writes on that in, so a letter reads as a letter and a plaque as a plaque. The pages turn by two keys of the
-- family's make where the game's arrows were, their words and the page's number in the family's fonts; the bar
-- that fills while a text is made out wears the bars' fill.
--
-- Regions only: the game sizes the window to the text (a great book is larger), lays the page out and shows and
-- hides the keys itself.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors

local CLEAR = { 0, 0, 0, 0 }
local KEY = { 5, 5, 5, 5 }       -- a turning key's plate in its 32 square
local CARET = 10
local WORDS, NUMBER = 11, 12     -- the keys' words; the page's number
-- The page: what the text is written on. Everything else of the game's on the window is its stone and its book.
local PAGE = { "ItemTextFramePageBg", "ItemTextMaterialTopLeft", "ItemTextMaterialTopRight", "ItemTextMaterialBotLeft", "ItemTextMaterialBotRight" }

-- The game's textures on the window but the page's, listed on first sight: before any of ours is drawn there.
local stone
local function Stone(frame)
	if stone then return stone end
	local page = {}
	for _, name in ipairs(PAGE) do
		if _G[name] then page[_G[name]] = true end
	end
	stone = {}
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") and not page[region] then stone[#stone + 1] = region end
	end
	return stone
end

-- A font object brings its own color and side: the string keeps its side, and takes the color given.
local function Face(kit, fontString, object, color)
	kit:Text(fontString, color)   -- first, so the kit keeps the game's color
	local side = fontString:GetJustifyH()
	kit:Justify(fontString, side)
	kit:FontObject(fontString, object)
	fontString:SetJustifyH(side)
	kit:Text(fontString, color)
end

-- A key that turns the page: the game's arrow away, the family's key with a caret, the game's word beside it.
local function Turn(kit, button, turn)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetDisabledTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Key(button, { inset = KEY, icon = Skin.GLYPH.caret, iconSize = CARET }):Turn(turn)
	for _, region in ipairs({ button:GetRegions() }) do
		if region:IsObjectType("FontString") and not Skin.IsOwn(region) then Face(kit, region, UI.TextFont(WORDS), UI.colors.dim) end
	end
end

local function Paint(kit)
	local frame = ItemTextFrame
	for _, region in ipairs(Stone(frame)) do kit:Hide(region) end
	ns.Window(kit, frame, { portrait = false })
	kit:Hide(frame.Inset.NineSlice)
	kit:Hide(frame.Inset.Bg)
	ns.ScrollBar(kit, ItemTextScrollFrame.ScrollBar)

	Turn(kit, ItemTextPrevPageButton, -math.pi / 2)
	Turn(kit, ItemTextNextPageButton, math.pi / 2)
	Face(kit, ItemTextCurrentPage, UI.TextFont(NUMBER), UI.colors.dim)

	-- The bar that fills while a text is made out: its border away, the bars' fill in a thin frame.
	local bar = ItemTextStatusBar
	local track = kit:Bar(bar).track
	local fill = bar:GetStatusBarTexture()
	for _, region in ipairs({ bar:GetRegions() }) do
		if region ~= fill and region ~= track and region:IsObjectType("Texture") and not Skin.IsOwn(region) then kit:Hide(region) end
	end
	kit:Plate(bar, { x = -1, y = -1, fill = CLEAR })
	bar:SetStatusBarColor(Shy.Theme.Accent())
end

local barColor   -- the game's color for the bar

ns.Module({
	id = "book",
	title = "Books and letters",
	desc = "The window you read books, letters and plaques in wears your theme. Each page keeps its paper.",
	group = "window",
	words = "item text",

	Ready = function() return ItemTextFrame ~= nil and ns.Window ~= nil end,

	Hook = function()
		barColor = { ItemTextStatusBar:GetStatusBarColor() }
	end,

	Paint = function(_, kit) Paint(kit) end,

	Clear = function(m)
		if m.on or not barColor then return end
		ItemTextStatusBar:SetStatusBarColor(barColor[1], barColor[2], barColor[3], barColor[4])
	end,
})
