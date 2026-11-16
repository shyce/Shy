-- Under the action bars: your XP and the reputation you watch as one piece, its edges those of the console's
-- floor (ShyDock's UnderSpan), its top a seam under it, everything in whole screen pixels. One height always: two
-- bars split by a hairline, or one filling it, so the console is never laid out again when you start or stop
-- watching a faction. Without the console it stands at the bottom of the screen's middle, as the game's bar did.
--
--   ns.Under.Room()      the height the console keeps for it (the piece and the seam under it), nil when not in use
--   ns.Under.Refresh()   said again; ns.Under.Place() stood again (the console moved, the scale changed)

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local U = {}
ns.Under = U

local K = {
	bar = 10,                -- a bar's height in units, rounded to whole pixels where it stands: room for its words
	text = 9,                -- the words' size
	inset = 6,               -- from a bar's ends to its words
	least = 3,               -- pixels: never thinner
	seam = 4,                -- the gap under it, the console's seam
	width = 1024,            -- without the console
	hints = { { "left", "Shift: share" }, { "right", "Track" } },
}

local piece, rows

function U.On()
	return ns.Place() == "under" and T.db.barStyle ~= "blizzard"
end

-- Units a pixel where the piece stands (UIParent's scale).
local function Pixel()
	local scale = UIParent:GetEffectiveScale()
	if issecretvalue(scale) or not scale or scale <= 0 then return 1 end
	return PixelUtil.GetPixelToUIUnitFactor() / scale
end

-- In pixels: a bar, and the whole piece (an edge, a bar, the hairline, a bar, an edge).
local function Sizes()
	local px = Pixel()
	local bar = math.max(K.least, math.floor(K.bar / px + 0.5))
	return px, bar, 2 * bar + 3
end

local function Seam()
	local dock = Shy.addons.Dock
	return dock and dock.Seam and dock:Seam() or K.seam
end

function U.Room()
	if not U.On() then return nil end
	local px, _, tall = Sizes()
	return tall * px + Seam()
end

-- What the two rows show: XP over the faction you watch while you level, else whichever there is.
local function Sources()
	local xp, rep = S.Active(), ns.Rep ~= nil and ns.Rep.Watched() ~= nil
	if xp and rep then return "xp", "rep" end
	if xp then return "xp" end
	if rep then return "rep" end
end

local function Line(layer)
	local t = piece:CreateTexture(nil, layer or "BORDER")
	t:SetSnapToPixelGrid(true)
	t:SetTexelSnappingBias(0)
	UI.Paint(t, C.border)
	return t
end

local function Row()
	local bar = ns.CreateXPBar(piece, true)
	-- Its words at its two ends, in the text face (its own outlined title words stay hidden): what it is at the
	-- left, how far along at the right.
	local words = CreateFrame("Frame", nil, bar)
	words:SetAllPoints()
	words:SetFrameLevel(bar:GetFrameLevel() + 2)
	bar.left = UI.Text(words, "", K.text, false, C.text)
	bar.left:SetPoint("LEFT", K.inset, 0)
	bar.right = UI.Text(words, "", K.text, false, C.text)
	bar.right:SetPoint("RIGHT", -K.inset, 0)
	bar:EnableMouse(true)
	bar:SetScript("OnEnter", function(self)
		self.hovered = true
		U.Refresh()
		if T.db.tooltip then ns.ShowSummaryTooltip(self, K.hints, self.source) end
	end)
	bar:SetScript("OnLeave", function(self)
		self.hovered = false
		UI.TipHide(self)
		U.Refresh()
	end)
	bar:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and IsShiftKeyDown() then ns.Share(self.source) end
		if button == "RightButton" and ns.Rep then UI.ContextMenu(self, ns.Rep.Menu) end
	end)
	return bar
end

local function Build()
	piece = CreateFrame("Frame", "ShyXPUnder", UIParent)
	piece:SetFrameStrata("LOW")
	piece.ground = piece:CreateTexture(nil, "BACKGROUND")
	piece.ground:SetAllPoints()
	UI.Paint(piece.ground, C.hud)
	piece.edges = { Line(), Line(), Line(), Line() }
	piece.hairline = Line()
	rows = { Row(), Row() }
end

-- Stands it where it goes, every edge on a pixel, and lays the rows out for what they show.
function U.Place()
	if not U.On() then
		if piece then piece:Hide() end
		return
	end
	local first, second = Sources()
	if not first then
		if piece then piece:Hide() end
		return
	end
	if not piece then Build() end
	local px, bar, tall = Sizes()
	local function Snap(v) return math.floor(v / px + 0.5) * px end
	local dock = Shy.addons.Dock
	local left, right, top
	if dock and dock.UnderSpan then left, right, top = dock:UnderSpan() end
	if not left then
		local half = UIParent:GetWidth() / 2
		left, right, top = half - K.width / 2, half + K.width / 2, K.seam + tall * px
	end
	left, right, top = Snap(left), Snap(right), Snap(top)
	local w, h = right - left, tall * px
	piece:ClearAllPoints()
	piece:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
	piece:SetSize(w, h)

	local e = piece.edges
	e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(px)
	e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(px)
	e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(px)
	e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(px)

	local one, two = rows[1], rows[2]
	one.source, two.source = first, second
	one:ClearAllPoints()
	one:SetPoint("TOPLEFT", px, -px)
	one:SetPoint("TOPRIGHT", -px, -px)
	if second then
		one:SetHeight(bar * px)
		piece.hairline:ClearAllPoints()
		piece.hairline:SetPoint("TOPLEFT", px, -(1 + bar) * px)
		piece.hairline:SetPoint("TOPRIGHT", -px, -(1 + bar) * px)
		piece.hairline:SetHeight(px)
		piece.hairline:Show()
		two:ClearAllPoints()
		two:SetPoint("TOPLEFT", px, -(2 + bar) * px)
		two:SetPoint("TOPRIGHT", -px, -(2 + bar) * px)
		two:SetHeight(bar * px)
		two:Show()
	else
		one:SetHeight((2 * bar + 1) * px)
		piece.hairline:Hide()
		two:Hide()
	end
	piece:Show()
	U.Refresh()
end

function U.Refresh()
	if not (piece and piece:IsShown()) then return end
	for _, bar in ipairs(rows) do
		if bar:IsShown() and bar.source then
			bar:Update()
			local on = T.db.barText == "always" or (T.db.barText == "hover" and bar.hovered)
			if on then
				local left, right = ns.BarParts(bar.source)
				bar.left:SetText(left)
				bar.right:SetText(right)
			end
			bar.left:SetShown(on)
			bar.right:SetShown(on)
		end
	end
end

function U.Start()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED", "PLAYER_ENTERING_WORLD" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function() U.Place() end)
	-- The console moved, or what the bars show changed (a faction watched or let go, the top level reached).
	Shy:On("SHY_CONSOLE", U.Place)
	Shy:On("SHY_XP_MODE", U.Place)
	U.Place()
end
