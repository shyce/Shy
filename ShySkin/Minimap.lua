-- The minimap (MinimapCluster): a square map on a panel, the zone name as its title strip, flat buttons.
-- The cluster is an Edit Mode frame and is never moved; its children are re-anchored inside it (Place).
-- Blizzard anchors Minimap once (Minimap.xml) but re-anchors the container, header, mail and instance
-- flags in SetHeaderUnderneath on every Edit Mode pass, so Place runs again on the frame after each.
-- The right action bars hang from the cluster, so nothing is placed or restored in combat (Stand).
-- Nothing is drawn on the cluster or the mail holder: both lay out their children.
-- The map's mask can't be read back, so the one Blizzard sets is remembered and restored.
-- The zone name is written in the header color; Blizzard's territory color is noted on every zone
-- change and comes back with the skin off (a font object brings its own color, so it is reapplied).
-- The game's addon menu is faded out and deaf: the family has buttons of its own.
-- So are the game's zoom buttons: the zoom is a capsule of ours, which with the day and night dial
-- shows only while the mouse is on the map (the map's furniture).
-- Shy.SetMinimapShape tells the core the map is square: its buttons then leave the map for a row
-- in the strip, between the zone name and the clock (Shy.MinimapStrip, told at every Place).
-- The game can't turn a square map, so with "Rotate Minimap" on the map stays round.

local ADDON, ns = ...
local UI = Shy.UI
local C = Shy.Skin.colors
local GLYPH = Shy.Skin.GLYPH

local SQUARE = "Interface\\Buttons\\WHITE8X8"
local ROUND = "ui-hud-minimap-frame-generic-mask"   -- from Blizzard_Minimap/Camelot/Skin.lua
local CLEAR = { 0, 0, 0, 0 }

local RIM = 4         -- panel outset past the map at the sides and bottom
local STRIP = UI.HEAD.piece.line                 -- the header every console piece wears
local HEAD_RIM = STRIP - 16                      -- the panel's reach over BorderTop (16 tall): the header's lip
local MAP_LINE = { -1, -1, -1, -1 }   -- hairline round the map
local MAP_DROP = 4    -- gap between the strip's line and the map
local MAP_X = -5      -- the map's center relative to the header's (Minimap.xml)
local MAP_MIN = 198   -- Blizzard's map size (Minimap.xml)
local STRIP_GAP = 2   -- between buttons in the strip
local STRIP_SEP = 5   -- either side of the hairline between the tools and the clock
local ZONE_IN = 6     -- the zone name's inset from the strip's left end
local BUTTON = 16     -- a strip button's side (as the core's)
local FLAG = 24       -- the mail flag's holder is 32 x 24 (MinimapIndicatorFrameTemplate.xml)
local ON_MAP = 3      -- inset of the mail flag, zoom and coordinates from the map's corners
-- The strip's middle over the map, where every header's words stand (UI.HEAD_MID down from its top edge): its
-- line's top stands MAP_DROP over the map, the header's top edge STRIP over that.
local STRIP_MID = MAP_DROP + STRIP - UI.HEAD_MID

-- Plate insets { left, top, right, bottom } in the strip's 16 high buttons.
local BAND = {
	tracking = { 0, 0.5, 0, 0.5 },   -- tracking is 17 high
	calendar = { 0, 1, 0, 1 },       -- a page 16 wide and 14 high: 2 clear of the strip's line and of its rim
}

local theirs = ROUND      -- the mask Blizzard last set
local squared = false     -- our square mask is on
local setting = false     -- guard: we are setting the mask
local clock = false       -- Blizzard_TimeManager has loaded
local zone                -- the zone name's color as Blizzard last set it

local function SetMask(asset)
	setting = true
	Minimap:SetMaskTexture(asset)
	setting = false
end

-- The rings the game draws round a quest's area, a bonus objective's and a dig site's are drawn for a
-- round map: none on the square one. What the game had can't be read back; 1 is taken to be it.
local function Rings(on)
	local value = on and 1 or 0
	Minimap:SetQuestBlobRingAlpha(value)
	Minimap:SetQuestBlobRingScalar(value)
	Minimap:SetTaskBlobRingAlpha(value)
	Minimap:SetTaskBlobRingScalar(value)
	Minimap:SetArchBlobRingAlpha(value)
	Minimap:SetArchBlobRingScalar(value)
end

local function SetSquare(square)
	if square == squared then return end
	squared = square
	SetMask(square and SQUARE or theirs)
	Rings(not square)
	Shy.SetMinimapShape(square and "SQUARE" or "ROUND")
end

-- The game draws the map's picture for the map's size only when the view changes (you move, the zoom
-- changes): a map sized while you stood still (at login, a reload, the tracker under it widening) kept
-- the picture of its old size in its top left corner until you walked. After every change of size,
-- and once the world is in, the zoom takes a step and comes back on the next frame: the picture is
-- drawn again at the map's size.
local redraw = false   -- a redraw waits for the next frame

local function Redraw()
	redraw = false
	local at, levels = Minimap:GetZoom(), Minimap:GetZoomLevels()
	if levels < 2 then return end
	Minimap:SetZoom(at > 0 and at - 1 or at + 1)
	Minimap:SetZoom(at)
end

local function RedrawSoon()
	if redraw then return end
	redraw = true
	C_Timer.After(0, Redraw)
end

-- The game can't turn a square map: with "Rotate Minimap" on, the map stays round.
local function Square(m)
	return m.opt.square and not GetCVarBool("rotateMinimap")
end

-- Zone names and the clock are localized: a font family.
local LabelFont = UI.TitleFont

local function KeepZoneColor()
	zone = { MinimapZoneText:GetTextColor() }
end

-- Ours: the header color every Shy title is written in. Else Blizzard's territory color, back with the skin off.
local function InkZone(ours)
	if ours then
		MinimapZoneText:SetTextColor(C.text[1], C.text[2], C.text[3])
	else
		MinimapZoneText:SetTextColor(zone[1], zone[2], zone[3], zone[4])
	end
end

local function HideArt(kit, button)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetHighlightTexture())
end

local function PaintRing(kit)
	local ring, under = MinimapCompassTexture, MinimapCompassTextureUnderlay
	-- With "Rotate Minimap" on, the underlay is the ring and this texture is only the north pointer, which stays.
	local turning = GetCVarBool("rotateMinimap")
	kit:Tint(under, C.metal)
	kit:Tint(ring, turning and C.lit or C.metal)
	if squared then
		kit:Hide(under)
		kit:Fade(ring, turning and 1 or 0)
	end
end

-- The zoom: a capsule of the dial's steel in the map's bottom right corner, plus over minus, each half a
-- button that lights under the mouse. Its art (ZoomRim, ZoomFill) is 20 x 44 at two texels a unit; the
-- capsule is scaled against the container's scale (Edit Mode's minimap size) so it keeps that density.
local ZOOM_W, ZOOM_H, ZOOM_GLYPH = 20, 44, 11
local ZOOM_LIT = 0.22   -- the hovered half's light
local zoom

local function ZoomLook(half)
	local on = half:IsEnabled()
	UI.Tint(half.glyph, not on and C.idle or (half.over and C.lit or C.glyph))
	half.lit:SetShown(on and half.over == true)
end

-- In and out as far as the map can go; the mouse wheel zooms too, so this is asked again while the map is hovered.
local function ZoomState()
	if not zoom then return end
	local at, levels = Minimap:GetZoom(), Minimap:GetZoomLevels()
	zoom.zin:SetEnabled(at < levels - 1)
	zoom.zout:SetEnabled(at > 0)
	ZoomLook(zoom.zin)
	ZoomLook(zoom.zout)
end

local function SeatZoom()
	if not zoom then return end
	zoom:SetScale(1 / MinimapCluster.MinimapContainer:GetScale())
	zoom:ClearAllPoints()
	zoom:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -ON_MAP, ON_MAP)
end

local Wake   -- the furniture's fader, below

local function ZoomHalf(top, glyph, click)
	local half = CreateFrame("Button", nil, zoom)
	half:SetSize(ZOOM_W, ZOOM_H / 2)
	half:SetPoint(top and "TOP" or "BOTTOM")
	half.lit = half:CreateTexture(nil, "ARTWORK")
	half.lit:SetTexture(Shy.MEDIA .. "ZoomFill")
	half.lit:SetAllPoints()
	half.lit:SetTexCoord(0, 1, top and 0 or 0.5, top and 0.5 or 1)
	UI.Tint(half.lit, C.hover, ZOOM_LIT)
	half.glyph = half:CreateTexture(nil, "OVERLAY")
	half.glyph:SetTexture(glyph)
	half.glyph:SetSize(ZOOM_GLYPH, ZOOM_GLYPH)
	half.glyph:SetPoint("CENTER", 0, top and -1 or 1)   -- toward the groove: the rounded end makes the half look lower
	half:SetScript("OnClick", function()
		click()
		ZoomState()
	end)
	half:SetScript("OnEnter", function(self)
		self.over = true
		ZoomLook(self)
		Wake()
	end)
	half:SetScript("OnLeave", function(self)
		self.over = false
		ZoomLook(self)
	end)
	return half
end

local function MakeZoom()
	if zoom then return end
	zoom = CreateFrame("Frame", nil, Minimap)
	zoom:SetSize(ZOOM_W, ZOOM_H)
	zoom:SetFrameLevel(Minimap:GetFrameLevel() + 10)
	zoom.fill = zoom:CreateTexture(nil, "BACKGROUND")
	zoom.fill:SetTexture(Shy.MEDIA .. "ZoomFill")
	zoom.fill:SetAllPoints()
	UI.Tint(zoom.fill, UI.colors.bg)
	zoom.rim = zoom:CreateTexture(nil, "BORDER")
	zoom.rim:SetTexture(Shy.MEDIA .. "ZoomRim")
	zoom.rim:SetAllPoints()
	UI.Tint(zoom.rim, C.metal)
	zoom.zin = ZoomHalf(true, GLYPH.plus, function() Minimap_ZoomIn() end)
	zoom.zout = ZoomHalf(false, GLYPH.minus, function() Minimap_ZoomOut() end)
	-- The rim lies over both halves' light.
	zoom.cover = CreateFrame("Frame", nil, zoom)
	zoom.cover:SetAllPoints()
	zoom.cover:SetFrameLevel(zoom.zin:GetFrameLevel() + 1)
	zoom.rim:SetParent(zoom.cover)
end

-- The game's own zoom buttons: faded out and deaf while ours stand in for them.
local function Theirs(on)
	for _, button in ipairs({ Minimap.ZoomIn, Minimap.ZoomOut }) do
		button:SetAlpha(on and 1 or 0)
		button:EnableMouse(on)
	end
end

-- The map's furniture (the dial, the zoom) shows only while the mouse is on the map: it fades in on hover
-- and out after. The fader runs while it shows or fades, to notice the mouse leave by way of a button on the map.
local FADE = 0.2         -- seconds for a whole fade
local waiting = false    -- the skin is on: the furniture waits for the mouse
local shown = 1          -- how far it shows
local fader

local function OverMap()
	local over = Minimap:IsMouseOver()
	return not issecretvalue(over) and over
end

local function Show(alpha)
	shown = alpha
	local lens = ns.Lens
	-- Tracking's tray lies over the map's top while it is open: the dial stands down under it.
	MinimapCluster.DielFrame:SetAlpha(lens and lens.Open() and 0 or alpha)
	if zoom then zoom:SetAlpha(alpha) end
	if lens then lens.Furnish(alpha) end   -- tracking's lens, while it holds nothing
end

local function Ease(self, elapsed)
	local target = (not waiting or OverMap()) and 1 or 0
	local step = elapsed / FADE
	Show(shown < target and math.min(target, shown + step) or math.max(target, shown - step))
	if target == 1 then ZoomState() end
	if shown == target and (target == 0 or not waiting) then self:Hide() end
end

function Wake()
	if not waiting then return end
	if not fader then
		fader = CreateFrame("Frame")
		fader:SetScript("OnUpdate", Ease)
	end
	fader:Show()
end

local function Wait(on)
	waiting = on
	if fader then fader:Hide() end
	Show((on and not OverMap()) and 0 or 1)
	if on and OverMap() then Wake() end
end

-- For what else stands on the map (tracking's lens): the mouse is on it, so the furniture comes up; and its
-- tray opened or closed, so the furniture is shown afresh.
function ns.WakeMap() Wake() end
function ns.FurnishMap() Show(shown) end

-- What Blizzard anchors once has its anchors kept and restored by Unplace; what it anchors on
-- every pass is restored by running that pass again.
local kept = {}         -- frame -> Blizzard's anchors
local placed = false    -- our layout is applied
local placing = false   -- guard: Place's own SetSize must not re-trigger it

local function Keep(frame)
	if kept[frame] then return end
	local points = {}
	for i = 1, frame:GetNumPoints() do points[i] = { frame:GetPoint(i) } end
	kept[frame] = points
end

local function Give(frame)
	local points = kept[frame]
	if not points then return end
	frame:ClearAllPoints()
	for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
	kept[frame] = nil
end

-- Edit Mode's "Header Underneath" setting.
local function Underneath(cluster)
	return cluster.GetSettingValueBool ~= nil and cluster:GetSettingValueBool(Enum.EditModeMinimapSetting.HeaderUnderneath) or false
end

-- Map width in the container's units: as wide as the objective tracker's panel, never under Blizzard's.
local function MapWidth(scale)
	local reach = Shy.wings.tracker
	local tracker = ObjectiveTrackerFrame and ObjectiveTrackerFrame:GetWidth() or 0
	if issecretvalue(tracker) then tracker = 0 end
	local panel = tracker + (reach and reach[1] + reach[3] or 0)
	return math.max(MAP_MIN, (panel - 2 * RIM) / scale)
end

local size = {}   -- frame -> Blizzard's size

local function KeepSize(frame)
	if not size[frame] then size[frame] = { frame:GetSize() } end
end

-- Scales changed, with Blizzard's, to give back (Unplace).
local scales = {}
local function KeepScale(frame)
	if not scales[frame] then scales[frame] = frame:GetScale() end
end

-- Frame levels changed, with Blizzard's, to give back (Unplace).
local levels = {}
local function KeepLevel(frame)
	if not levels[frame] then levels[frame] = frame:GetFrameLevel() end
end

-- The queue eye (QueueStatusButton, an Edit Mode frame) is anchored by the game at the map's
-- center less (68, 68): the edge of a round map, well inside a square or wider one. On the square
-- map it takes the bottom left corner, by the engine's own anchoring so no Edit Mode code runs.
-- A place the player gave it in layout mode wins; Blizzard's anchors come back with the round map.
local EYE = "game.QueueStatusButton"
local eyeHome   -- Blizzard's anchors while ours are set

local function PlaceEye(map, s)
	local eye = QueueStatusButton
	if not eye or not eye.SetPointBase then return end
	local box = Shy.HUD.Find(EYE)
	if box and Shy.HUD.IsPlaced(box) then return end
	if not eyeHome then
		eyeHome = {}
		for i = 1, eye:GetNumPoints() do eyeHome[i] = { eye:GetPoint(i) } end
	end
	local e = eye:GetScale()
	eye:ClearAllPointsBase()
	eye:SetPointBase("BOTTOMLEFT", map, "BOTTOMLEFT", ON_MAP * s / e, ON_MAP * s / e)
end

local function UnplaceEye()
	local eye = QueueStatusButton
	if not eyeHome or not eye then return end
	eye:ClearAllPointsBase()
	for _, point in ipairs(eyeHome) do eye:SetPointBase(unpack(point)) end
	eyeHome = nil
end

-- The header strip the square map hangs from: our own frame on the cluster, where the game's header
-- (175 x 16, 4 under the top or 2 over the bottom, 15 right of center) stood before it moved into the
-- zone button, which we move.
local headerFrame

local function Header(cluster)
	if not headerFrame then
		headerFrame = CreateFrame("Frame", nil, cluster)
		headerFrame:SetSize(175, 16)
	end
	headerFrame:ClearAllPoints()
	if Underneath(cluster) then
		headerFrame:SetPoint("BOTTOM", cluster, "BOTTOM", 15, 2)
	else
		headerFrame:SetPoint("TOP", cluster, "TOP", 15, -4)
	end
	return headerFrame
end

-- The hairline between the tools and the clock, in the strip's units, over the map's top edge.
local dividerFrame

local function Divider()
	if not dividerFrame then
		dividerFrame = CreateFrame("Frame", nil, Minimap)
		dividerFrame:SetSize(1, BUTTON - 6)
		local line = dividerFrame:CreateTexture(nil, "ARTWORK")
		line:SetAllPoints()
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		Shy.Theme.Paint(line, C.edge)
	end
	return dividerFrame
end

-- Offsets on the map and container are in the container's scale (Edit Mode's minimap size); the rest in UIParent's.
local function Place(cluster)
	local container, map, header = cluster.MinimapContainer, Minimap, Header(cluster)
	local s = container:GetScale()
	placing = true
	KeepSize(map)
	local width = MapWidth(s)
	map:SetSize(width, width)
	Keep(map)
	map:ClearAllPoints()
	if Underneath(cluster) then
		map:SetPoint("BOTTOM", header, "TOP", MAP_X / s, MAP_DROP / s)
	else
		map:SetPoint("TOP", header, "BOTTOM", MAP_X / s, -MAP_DROP / s)
	end
	container:ClearAllPoints()
	container:SetPoint("TOP", map, "TOP", 0, 0)
	container:SetSize(width, width)

	-- The strip: tracking, zone name, the family's buttons, clock, calendar. The game's addon menu
	-- (faded out, PaintAddons) is parked under the clock's place.
	local tracking, zoneButton = cluster.Tracking, cluster.ZoneTextButton
	Keep(tracking)
	Keep(GameTimeFrame)
	KeepSize(GameTimeFrame)
	GameTimeFrame:SetSize(BUTTON, BUTTON)   -- the page is drawn to the strip's button, not the game's
	GameTimeFrame:ClearAllPoints()
	GameTimeFrame:SetPoint("RIGHT", map, "TOPRIGHT", 0, STRIP_MID)
	Keep(AddonCompartmentFrame)
	AddonCompartmentFrame:ClearAllPoints()
	AddonCompartmentFrame:SetPoint("RIGHT", GameTimeFrame, "LEFT", -STRIP_GAP, 0)
	local last = GameTimeFrame
	if clock then
		Keep(TimeManagerClockButton)
		TimeManagerClockButton:ClearAllPoints()
		TimeManagerClockButton:SetPoint("RIGHT", GameTimeFrame, "LEFT", -STRIP_GAP, 0)
		last = TimeManagerClockButton
	end
	-- A hairline sets the clock and calendar apart from the tools: tracking and the family's buttons
	-- stand in a row before it, and the zone name has all the room from the strip's left end to them.
	local divider = Divider()
	divider:ClearAllPoints()
	divider:SetPoint("RIGHT", last, "LEFT", -STRIP_SEP, 0)
	divider:Show()
	local row = Shy.MinimapStrip(divider, STRIP_SEP)
	tracking:ClearAllPoints()
	tracking:SetPoint("RIGHT", row, "LEFT", -STRIP_GAP, 0)
	-- With the family's buttons folded into the core's menu, tracking is a row of that menu too: its
	-- button stays placed (the menu opens from it) but out of sight and reach. So too while tracking
	-- is the lens on the map (Tracking.lua).
	local lens = ns.Lens and ns.Lens.Stands() and ns.Lens or nil
	local folded = lens ~= nil or (Shy.MinimapFolding and Shy.MinimapFolding()) or false
	tracking:SetAlpha(folded and 0 or 1)
	tracking:EnableMouse(not folded)
	-- The mail flag: on the map in its top left corner. While the lens has that corner the flag is one of the
	-- strip's tools, before the family's row at a strip button's height: a flag beside the lens left a gap in
	-- the corner whenever the lens was away, and lay over the lens's tray.
	local flags = cluster.IndicatorFrame
	KeepScale(flags)
	flags:ClearAllPoints()
	if lens then
		local small = BUTTON / FLAG
		flags:SetScale(scales[flags] * small)
		flags:SetPoint("RIGHT", row, "LEFT", -STRIP_GAP / small, 0)
	else
		flags:SetScale(scales[flags])
		flags:SetPoint("TOPLEFT", map, "TOPLEFT", ON_MAP, -ON_MAP)
	end
	Keep(zoneButton)
	KeepSize(zoneButton)
	zoneButton:SetHeight(BUTTON)   -- the game's is 23 high: it fits the strip
	zoneButton:ClearAllPoints()
	zoneButton:SetPoint("LEFT", map, "TOPLEFT", ZONE_IN, STRIP_MID)
	zoneButton:SetPoint("RIGHT", lens and flags or (folded and row or tracking), "LEFT", -STRIP_SEP, 0)

	-- On the map: tracking's lens, zoom (SeatZoom), coordinates, instance flag, dial.
	if lens then lens.Seat() end
	SeatZoom()
	-- Coordinates at the bottom's middle: the queue eye has the left corner, zoom the right.
	local coords = container.PlayerCoords
	Keep(coords)
	coords:ClearAllPoints()
	coords:SetPoint("BOTTOM", map, "BOTTOM", 0, ON_MAP)
	-- Under everything laid on the map (the trail, pins, a flight's mark and its time), over the map itself:
	-- the map's own level, where the game had it over all of them.
	KeepLevel(coords)
	coords:SetFrameLevel(map:GetFrameLevel())
	-- The day and night dial in the top right corner, the instance flag beside it.
	local dial = cluster.DielFrame
	if dial then
		local d = dial:GetScale()
		Keep(dial)   -- Blizzard anchors it by its center and ours is a corner: the two must never add up
		dial:ClearAllPoints()
		dial:SetPoint("TOPRIGHT", map, "TOPRIGHT", -ON_MAP * s / d, -ON_MAP * s / d)
	end
	local flag = cluster.InstanceDifficulty   -- this client's cluster has no such frame
	if flag then
		flag:ClearAllPoints()
		if dial then
			flag:SetPoint("TOPRIGHT", dial, "TOPLEFT", -STRIP_GAP, 0)
		else
			flag:SetPoint("TOPRIGHT", map, "TOPRIGHT", -ON_MAP, -ON_MAP)
		end
	end
	PlaceEye(map, s)
	-- The cluster sizes itself round its children; the right action bars hang from it.
	cluster:Layout()
	placing = false
	placed = true
end

-- Combat lockdown: Place and Unplace move frames that protected frames are anchored to, so they
-- only run from Stand, and Stand only through ns.AfterCombat. `want` holds the latest wish.
local STAND = "minimap"
local want = false   -- skin on and map square
local Stand

-- Blizzard has just re-anchored the cluster's children: place again next frame, once per pass.
local soon
local function PlaceSoon(cluster)
	if soon or placing or not placed then return end
	soon = true
	C_Timer.After(0, function()
		soon = nil
		if placed then ns.AfterCombat(STAND, Stand) end
	end)
end

-- Restores Blizzard's layout: kept anchors and sizes, then the cluster's own passes.
local function Unplace(cluster)
	cluster.Tracking:SetAlpha(1)
	cluster.Tracking:EnableMouse(true)
	if not placed then return end
	placed = false
	placing = true
	local container = cluster.MinimapContainer
	for frame, was in pairs(size) do frame:SetSize(was[1], was[2]) end
	wipe(size)
	for frame, was in pairs(levels) do frame:SetFrameLevel(was) end
	wipe(levels)
	for frame, was in pairs(scales) do frame:SetScale(was) end
	wipe(scales)
	for frame in pairs(kept) do Give(frame) end
	Shy.MinimapStrip()   -- the strip is Blizzard's again: no row of ours in it
	if dividerFrame then dividerFrame:Hide() end
	UnplaceEye()
	local art = C_Texture.GetAtlasInfo(GetCVarBool("rotateMinimap") and "UI-HUD-Minimap-Frame-Pointer" or "UI-HUD-Minimap-Frame")
	container:SetSize(art and art.width or 215, art and art.height or 226)
	cluster:SetHeaderUnderneath(Underneath(cluster))   -- container, header, mail and instance flags
	cluster:SetEditModeScale(container:GetScale())      -- the dial (Camelot/Diel.lua)
	cluster:Layout()
	placing = false
end

-- Out of combat only.
function Stand()
	if want then Place(MinimapCluster) else Unplace(MinimapCluster) end
end

-- The panel: our own frame under UIParent, so nothing is drawn on an Edit Mode frame.
local under

local function Under(cluster)
	if not under then
		under = CreateFrame("Frame", nil, UIParent)
		under:SetFrameStrata("BACKGROUND")
		under:EnableMouse(false)
		under:SetPoint("TOP", Header(cluster), "TOP", 0, HEAD_RIM)
		under:SetPoint("LEFT", Minimap, "LEFT", -RIM, 0)
		under:SetPoint("RIGHT", Minimap, "RIGHT", RIM, 0)
		under:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, -RIM)
		-- The minimap's housing while the HUD is faded: gone while you play, back while you are away.
		local immersion = Shy.Immersion
		if immersion and immersion.Watch then immersion.Watch("minimap", under, "housing") end
	end
	return under
end

-- For ShyDock: the panel's left, bottom, right, top in UIParent units, or nil when there is no panel.
function ns.T:MinimapPanel()
	if not (placed and under and under:IsShown()) then return nil end
	local left, bottom, width, height = under:GetScaledRect()
	if left == nil or issecretvalue(left) then return nil end
	local originX, originY = UIParent:GetScaledRect()
	local scale = UIParent:GetEffectiveScale()
	left, bottom = (left - originX) / scale, (bottom - originY) / scale
	return left, bottom, left + width / scale, bottom + height / scale
end

local function PaintGround(kit, cluster)
	kit:Plate(Under(cluster), { key = "ground", panel = true, cap = true, title = STRIP, hud = true })
	-- The layout editor fits its sheet to the panel, not the cluster (wider and shorter than the square map).
	Shy.HUD.SetHousing(cluster, Under(cluster))
	-- MinimapBackdrop is above the map and under the buttons.
	kit:Plate(MinimapBackdrop, { key = "line", to = Minimap, over = true, fill = CLEAR, border = C.edge, inset = MAP_LINE })
end

-- grounded: the panel carries the strip and the zone button only lights on hover. Round: the button carries the strip.
local zoneJustify   -- Blizzard's justification of the zone name, while ours is set

-- The art the game draws on its header buttons (the zone name's box, tracking's lens, the calendar's
-- page) is a state texture and a light that comes on under the mouse. Both are faded, and the light
-- is faded again each time the game sets it.
local skinned = false   -- the skin is on: the light stays faded
local quieted = {}

local function Quiet(kit, button)
	kit:Hide(button.StateTexture)
	kit:Hide(button.AddTexture)
	if quieted[button] or not button.OnButtonStateChanged then return end
	quieted[button] = true
	hooksecurefunc(button, "OnButtonStateChanged", function(self)
		if skinned then self.AddTexture:SetAlpha(0) end
	end)
end

local function PaintHeader(kit, cluster, grounded)
	local button = cluster.ZoneTextButton
	if grounded then
		Quiet(kit, button)
		kit:Plate(button, { key = "wide", fill = CLEAR, border = CLEAR, hover = true })
		kit:Place(MinimapZoneText, nil, nil, { "LEFT", button, "LEFT", STRIP_GAP, 0 }, { "RIGHT", button, "RIGHT", -STRIP_GAP, 0 })
		zoneJustify = zoneJustify or MinimapZoneText:GetJustifyH()
		MinimapZoneText:SetJustifyH("LEFT")
	else
		Quiet(kit, button)
		kit:Plate(button, { fill = C.strip, hover = true })
		ns.Gloss(kit, button, { over = button, x = 1, y = 1 })
		kit:Line(button, button)
	end
	kit:FontObject(MinimapZoneText, LabelFont())
	InkZone(true)
end

-- Tracking is the lens the guide's finder wears: the search box's own picture, quiet at rest and
-- lit under the mouse or while its menu is open.
local LENS, LENS_REST = 12, 0.62
local lenses = {}

local function PaintTracking(kit, tracking)
	local button = tracking.Button
	kit:Hide(tracking.Background)
	Quiet(kit, button)
	kit:Plate(button, { to = tracking, inset = BAND.tracking, fill = CLEAR, border = CLEAR, hover = true })
	local lens = lenses[button]
	if not lens then
		local holder = CreateFrame("Frame", nil, button)
		holder:SetAllPoints(tracking)
		local mark = holder:CreateTexture(nil, "OVERLAY")
		mark:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
		mark:SetSize(LENS, LENS)
		mark:SetPoint("CENTER", 0, -0.5)
		lens = { holder = holder, mark = mark, over = false }
		lenses[button] = lens
		function lens.Ink()
			local lit = lens.over or button:IsMenuOpen()
			UI.Tint(mark, lit and C.lit or C.glyph)
			mark:SetAlpha(lit and 1 or LENS_REST)
		end
		button:HookScript("OnEnter", function() lens.over = true; lens.Ink() end)
		button:HookScript("OnLeave", function() lens.over = false; lens.Ink() end)
	end
	lens.holder:Show()
	lens.Ink()
end

-- A page of a calendar: a band of the accent's light along its top, the day under it. A number
-- alone on a plate said nothing of what it is.
local PAGE_BAND, PAGE_DAY = 3, 8   -- the band's height; the day's text size ("20" is 9 wide in the page's 14)

local function PaintCalendar(kit)
	local button = GameTimeFrame
	HideArt(kit, button)
	Quiet(kit, button)
	local plate = kit:Plate(button, { inset = BAND.calendar, fill = CLEAR, border = C.glyph, hover = true, band = PAGE_BAND, label = "", labelSize = PAGE_DAY })
	plate.label:ClearAllPoints()
	plate.label:SetPoint("CENTER", plate.fill, "CENTER", 0, -PAGE_BAND / 2)
	plate.label:SetText(C_DateAndTime.GetCurrentCalendarTime().monthDay)
end

-- The game's addon menu: the family has buttons of its own, so it is faded out and deaf.
-- Blizzard shows it again whenever an addon registers (UpdateDisplay), so it is not hidden.
local function PaintAddons()
	AddonCompartmentFrame:SetAlpha(0)
	AddonCompartmentFrame:EnableMouse(false)
end

local function PaintClock(kit)
	kit:FontObject(TimeManagerClockTicker, LabelFont(11))
	kit:Text(TimeManagerClockTicker, C.text)
end

-- The day/night dial: everything but the sun or moon (Background) is tinted.
local function PaintDial(kit, dial)
	for _, region in ipairs({ dial:GetRegions() }) do
		if region ~= dial.Background then kit:Tint(region, C.metal) end
	end
end

ns.Module({
	id = "minimap",
	title = "Minimap",
	desc = "Your minimap gets a steel frame, the zone's name on a strip and flat buttons for the calendar and zoom.",
	group = "screen",
	words = "tracking clock",

	options = {
		{ key = "square", label = "Square map", default = true,
			desc = "The minimap is square, with your coordinates in its corner. A rotating minimap stays round." },
	},

	Hook = function(m)
		KeepZoneColor()
		-- Blizzard writes the territory color on every zone change: noted for the skin's off, ours put back.
		hooksecurefunc("Minimap_Update", function()
			KeepZoneColor()
			if m.on then InkZone(true) end
		end)
		-- Blizzard resets the mask when "Rotate Minimap" changes, and the ring's textures change.
		hooksecurefunc(Minimap, "SetMaskTexture", function(_, asset)
			if setting then return end
			theirs = asset
			-- Rotation switched on or off: the map changes shape, all of it at once a frame later.
			if m.on and Square(m) ~= squared then
				C_Timer.After(0, function() m:Refresh() end)
				return
			end
			if squared then SetMask(SQUARE) end
			if m.on then PaintRing(m.kit) end
		end)
		hooksecurefunc("GameTimeFrame_SetDate", function()
			if m.on then PaintCalendar(m.kit) end
		end)
		EventUtil.ContinueOnAddOnLoaded("Blizzard_TimeManager", function()
			clock = true
			if m.on then PaintClock(m.kit) end
			if placed then ns.AfterCombat(STAND, Stand) end   -- the clock joins the strip
		end)
		-- Every pass in which Blizzard re-anchors the cluster's children.
		local cluster = MinimapCluster
		local function Again()
			SeatZoom()   -- the minimap's size changed, round map or square
			PlaceSoon(cluster)
		end
		hooksecurefunc(cluster, "SetHeaderUnderneath", Again)
		hooksecurefunc(cluster, "SetEditModeScale", Again)
		hooksecurefunc(cluster.MinimapContainer, "SetSize", Again)
		EventRegistry:RegisterCallback("EditMode.Enter", Again, m)   -- so Edit Mode's selection box fits the map
		-- The queue eye is re-anchored by the game on every minimap scale change and Edit Mode pass,
		-- and put back by the layout editor's reset: ours again after each.
		if QueueStatusButton then
			hooksecurefunc(QueueStatusButton, "UpdateDefaultAnchor", Again)
			hooksecurefunc(QueueStatusButton, "SetPoint", Again)
		end
		Shy:On("SHY_HUD_LAYOUT", Again)
		-- The map is as wide as the objective tracker's panel (MapWidth), whose reach is said once everyone has
		-- logged in, after the map was first placed, and again whenever that panel comes or goes: placed again
		-- then, so the map is the same width at every login.
		Shy:On("SHY_LOGIN", Again)
		Shy:On("SHY_WINGS", Again)
		Minimap:HookScript("OnEnter", function() Wake() end)
		-- The picture drawn again at the map's size: after each resize, and once the world is in.
		Minimap:HookScript("OnSizeChanged", RedrawSoon)
		local loaded = CreateFrame("Frame")
		loaded:RegisterEvent("LOADING_SCREEN_DISABLED")
		loaded:SetScript("OnEvent", RedrawSoon)
	end,

	Paint = function(m, kit)
		local cluster = MinimapCluster
		skinned = true
		SetSquare(Square(m))
		PaintRing(kit)
		want = squared
		if ns.Lens then ns.Lens.Stand(squared) end   -- before the pieces are placed: the strip and the mail flag go by it
		ns.AfterCombat(STAND, Stand)
		if squared then PaintGround(kit, cluster) else Shy.HUD.SetHousing(cluster, nil) end
		PaintHeader(kit, cluster, squared)
		PaintTracking(kit, cluster.Tracking)
		PaintCalendar(kit)
		PaintAddons()
		if clock then PaintClock(kit) end
		MakeZoom()
		SeatZoom()
		zoom:Show()
		ZoomState()
		Theirs(false)
		PaintDial(kit, cluster.DielFrame)
		Wait(true)
		ns.Number(kit, cluster.MinimapContainer.PlayerCoords.CoordText)
	end,

	-- The kit's restore resets the zone name's font and with it its color.
	Clear = function(m)
		skinned = false
		if ns.Lens then ns.Lens.Stand(false) end
		for _, lens in pairs(lenses) do lens.holder:Hide() end
		InkZone(false)
		Wait(false)
		if zoom then zoom:Hide() end
		Theirs(true)
		AddonCompartmentFrame:SetAlpha(1)
		AddonCompartmentFrame:EnableMouse(true)
		if zoneJustify then
			MinimapZoneText:SetJustifyH(zoneJustify)
			zoneJustify = nil
		end
		if not m.on then
			SetSquare(false)
			want = false
			ns.AfterCombat(STAND, Stand)
		end
	end,
})
