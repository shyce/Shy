-- The game's alerts by the chat: a friend coming online or going, a friend's new message, a friend request
-- (BNToastFrame), and the notes of the same make (the time played alert, a realm transfer's countdown). Each
-- comes and goes, so it wears the theme's mini border on the hovers' fill, as a tooltip does. Its close is the
-- family's cross, with an edge under the mouse; the flare it comes up with is in your color; its words are in
-- the family's fonts and keep the colors the game gives them each time (a Battle.net name's own, the grey of
-- what is said about it). The picture is the game's.
--
-- Regions only: the game shows, sizes, places and fades each alert itself, and writes its words anew for each
-- one, which changes neither their font nor anything of ours.

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors

local CLEAR = { 0, 0, 0, 0 }
-- The frames (SocialToastTemplate), by name: each is dressed where this client has it.
local ALERTS = { "BNToastFrame", "TimeAlertFrame", "ShardTransferImminentFrame" }
-- The template's backdrop (BackdropTemplate's pieces).
local BACKDROP = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
-- An alert's lines: the first is a name, in the names' font; the rest are said about it.
local NAME, SAID = "TopLine", { "MiddleLine", "BottomLine", "DoubleLine", "Text" }
local TEXT, SMALL = 12, 11      -- the lines' size (the game's), and the size of the note that drops from a long message
local CROSS = 8                 -- the close's glyph, in its 18 square
local HOUSING = { key = "alert", panel = true, hud = true, mini = true, brackets = false, fill = C.tip }

-- A font object brings its own color and sides, and the game colors a line anew for each alert: a string keeps the
-- color and sides it has now, when it is given our font and when the kit hands the game's back (Keep).
local faced = setmetatable({}, { __mode = "k" })   -- the strings wearing our fonts

local function Wearing(fontString)
	return { fontString:GetJustifyH(), fontString:GetJustifyV(), fontString:GetTextColor() }
end

local function Wear(fontString, was)
	fontString:SetJustifyH(was[1])
	fontString:SetJustifyV(was[2])
	fontString:SetTextColor(was[3], was[4], was[5], was[6])
end

local function Face(kit, fontString, object)
	if not fontString then return end
	local was = Wearing(fontString)
	kit:FontObject(fontString, object)
	Wear(fontString, was)
	faced[fontString] = true
end

-- The kit is our own table, so wrapping its Restore taints nothing.
local function Keep(kit)
	local restore = kit.Restore
	kit.Restore = function(self)
		local was = {}
		for fontString in pairs(faced) do was[fontString] = Wearing(fontString) end
		wipe(faced)
		restore(self)
		for fontString, wore in pairs(was) do Wear(fontString, wore) end
	end
end

local function Close(kit, button)
	if not button then return end
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Plate(button, { fill = CLEAR, border = CLEAR, hover = true, icon = UI.CLOSE_GLYPH, iconSize = CROSS })
end

-- A piece of an alert's by its key, or nil: not every alert has every piece.
local function Part(alert, key)
	local part = alert[key]
	return type(part) == "table" and part or nil
end

local function PaintAlert(kit, alert)
	for _, piece in ipairs(BACKDROP) do kit:Hide(Part(alert, piece)) end
	kit:Plate(alert, HOUSING)
	local flare = Part(alert, "glow")
	if flare then kit:Tint(flare, C.hot) end
	Close(kit, Part(alert, "CloseButton"))
	Face(kit, Part(alert, NAME), UI.NameFont(TEXT))
	for _, key in ipairs(SAID) do Face(kit, Part(alert, key), UI.TextFont(TEXT)) end

	-- A friend's message too long for its line drops down in a note of its own while the mouse is on the alert.
	local note = Part(alert, "TooltipFrame")
	if note then
		kit:Hide(note.NineSlice)
		kit:Plate(note, HOUSING)
		Face(kit, note.Text, UI.TextFont(SMALL))
	end
end

local function Alerts()
	local list = {}
	for _, name in ipairs(ALERTS) do
		local alert = _G[name]
		if alert then list[#list + 1] = alert end
	end
	return list
end

ns.Module({
	id = "alerts",
	title = "Chat alerts",
	desc = "Alerts that come up by the chat, like a friend coming online, match your theme.",
	group = "screen",
	words = "toast friend online",

	Ready = function() return BNToastFrame ~= nil end,

	Hook = function(m) Keep(m.kit) end,

	Paint = function(_, kit)
		for _, alert in ipairs(Alerts()) do PaintAlert(kit, alert) end
	end,
})
