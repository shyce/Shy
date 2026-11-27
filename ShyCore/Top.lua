-- Shy.Top: the column down from the middle of the screen's top edge. What comes up there comes up in
-- one place each, under one another, so no two ever lie over each other: the head, the death recap's line,
-- the waypoint arrow, a group's status, the zone's name as a new area is entered, the level's stats. The way
-- back to the graveyard floats past the head's point (Top.Graveyard).
--
--   Shy.HUD.Create({ ..., top = {
--       order = 30,                          -- lower stands nearer the screen's edge
--       sample = function(parent) end,       -- optional: the piece as a picture, a frame of the box's size
--                                            -- (a preview of the screen draws it; with none it isn't drawn)
--       passing = true,                      -- optional: it comes and goes (drawn faint in a preview)
--       empty = function() end,              -- optional: true while it has nothing to show; it then takes
--                                            -- no room and what stands under it closes up (a preview still
--                                            -- draws it). Its owner calls Shy.Top.Apply() when that changes
--   } })
--   Shy.Top.Plan(drawn)   -- the column from the top: { { id, title, box, y, x, rel, width, height, scale, sample,
--                         -- passing }, ... } in screen units, y its top edge's distance under the screen's, x the
--                         -- column's middle across from the screen's, rel its top under the column's first piece's.
--                         -- drawn: as a setup leaves it (every piece in its place, nothing of the game's over it)
--   Shy.Top.Foot()        -- where the column ends, as a distance under the screen's top (nothing of it stands
--                         -- there while it is Moved)
--   Shy.Top.Moved()       -- the player put the head somewhere else: the whole column stands there with it
--   Shy.Top.Apply()       -- arranges again
--   Shy.Top.Look(id, picture, width, height)   -- the game's piece drawn by an addon of ours:
--                         -- its picture and size stand for it; Shy.Top.Look(id) gives the game's back
--
-- The column is one piece, led by the head (the notices' circle and plate, `top = { head = true }`). The rest
-- are part of it (HUD.Lead): no handle, place, size or lock of their own. Dragging the head, or any piece of
-- it, moves the whole column; sized, all of it takes the head's size. In layout mode the head's mover lies
-- over the whole column. Without a head each piece is a place of its own: dragged out of the column the rest
-- close up, and let go of near its place it is the column's again.
-- A piece keeps its place whether it shows or not, so nothing moves because something else came up. The
-- game's own widgets at the top (a battleground's score) stand over the column while any show.
--
-- A piece whoever arranges the screen has given a home of their own (a box docked in a deck, a stack by
-- the chat) is theirs for as long: it is out of the column and takes no room in it, and is the column's
-- again once it is handed back the place it had. So is one whose content another piece shows (`away`).
--
-- The game's zone name shows and hides itself, so it stands on a box of ours that is seen in layout mode
-- only, holding a picture of it: game.zone.

local Shy = Shy
local HUD, UI, Theme, Skin = Shy.HUD, Shy.UI, Shy.Theme, Shy.Skin
local C = UI.colors

local Top = {}
Shy.Top = Top

local EDGE = 4    -- between the column and the screen's top edge, or the game's widgets there
local SEAM = 4    -- between two pieces
Top.SEAM = SEAM
local ZONE = { w = 420, h = 84, line = 32 }    -- room for the zone's name, whose land it is and the area; a line of the name

local gave = setmetatable({}, { __mode = "k" })     -- box -> the home the column last gave it
local at = setmetatable({}, { __mode = "k" })       -- box -> { pos, base }: where it was planned last (Apply)
local theirs = setmetatable({}, { __mode = "k" })   -- box -> true while another arranger's home has it
local giving = false                                 -- inside Top.Apply: a home set now is the column's own

local function Same(a, b)
	return a ~= nil and b ~= nil and a[1] == b[1] and a[2] == b[2] and math.abs(a[3] - b[3]) < 0.01 and math.abs(a[4] - b[4]) < 0.01
end

local Soon, Widen      -- (defined below: "Next frame, once" and "One width")
local Lead, Cover      -- (defined below: "One piece")
local Under, Indent    -- (defined below, "The drawer": the room a piece leaves under it; how far one in it is set in)
local Relay            -- (defined below, "The tray": every tray lays its cells again)
-- The drawer under the head (below, "The drawer"): the pieces hanging in it, the head it hangs from while it
-- stands, and the last piece in it.
local wrapping = setmetatable({}, { __mode = "k" })
local headBox, lastBox
-- Where the column hangs from now (Apply): its head, which leads it; the column's middle across from the screen's;
-- `base`, what a piece's place (pos) is measured down from; `home`, how far under the screen's top the head stands
-- at home.
local column = { x = 0, base = 0, home = 0 }
local watched = setmetatable({}, { __mode = "k" })

-- A piece coming or going makes room or gives it back: the column is arranged again the next frame.
local function Watch(frame)
	if watched[frame] then return end
	watched[frame] = true
	frame:HookScript("OnShow", function() Soon() end)
	frame:HookScript("OnHide", function() Soon() end)
end

-- Where a piece stands among the others: by its order, but what hangs in the head's drawer stands right under the
-- head, in its own order there, before anything else the column holds (the drawer is one piece with the head).
local function Rank(box)
	if headBox and box ~= headBox and wrapping[box] then return headBox.top.order + box.top.order / 1000 end
	return box.top.order
end

-- The boxes standing in the column, from the top.
local function Members()
	local list = {}
	HUD.Each(function(box)
		if not box.foreign and box.top and not theirs[box] and not (box.awayFn ~= nil and box.awayFn() == true) then
			list[#list + 1] = box
			Watch(box)
		end
	end)
	table.sort(list, function(a, b) return Rank(a) < Rank(b) end)
	return list
end

local function Empty(box)
	return box.top.empty ~= nil and box.top.empty() == true
end

-- A piece takes room only while it shows (in layout mode every one does, to be placed): its own word
-- (`empty`), else the game's frame standing on it, else its box.
local function Showing(box)
	if HUD.IsUnlocked() then return true end
	if box.top.empty then return not Empty(box) end
	local game = box.top.game
	if game then
		for _, frame in ipairs(game) do
			if frame:IsShown() then return true end
		end
		return false
	end
	return box:IsShown()
end

-- Where the column begins under the screen's top edge.
local function Start()
	local widgets = UIWidgetTopCenterContainerFrame
	if widgets:IsShown() and widgets:HasAnyWidgetsShowing() then
		local bottom = widgets:GetBottom()
		if bottom and not issecretvalue(bottom) then
			return UIParent:GetHeight() - bottom * widgets:GetEffectiveScale() / UIParent:GetEffectiveScale() + EDGE
		end
	end
	return EDGE
end

local function HeadOf(list)
	for _, box in ipairs(list) do
		if box.top.head then return box end
	end
end

-- The head stands where the player put it: the column hangs from there.
local function Moved(head)
	return head ~= nil and HUD.IsPlaced(head)
end

function Top.Moved()
	return Moved(column.head)
end

-- Where the column hangs from: its middle across from the screen's, and its first piece's top under the screen's
-- top. At home, the top's middle, under the game's widgets there. With the head put elsewhere, the head's top
-- stands where it was put (`rel` under the first piece's) and the rest under it.
local function Origin(head, rel)
	if Moved(head) then
		local left, bottom, width, height = head:GetLeft(), head:GetBottom(), head:GetWidth(), head:GetHeight()
		if left and bottom and width and height and not (issecretvalue(left) or issecretvalue(bottom)) then
			local k = head:GetEffectiveScale() / UIParent:GetEffectiveScale()
			return (left + width / 2) * k - UIParent:GetWidth() / 2, UIParent:GetHeight() - (bottom + height) * k - rel
		end
	end
	return 0, Start()
end

function Top.Plan(drawn)
	local members = Members()
	local head = HeadOf(members)
	local list, y, headAt = {}, 0, 0
	for _, box in ipairs(members) do
		local scale = box:GetScale()
		local height = box:GetHeight() * scale
		if box == head then headAt = y end
		list[#list + 1] = { id = box.id, title = box.title, box = box, rel = y, width = box:GetWidth() * scale, height = height,
			scale = scale, sample = box.top.sample, passing = box.top.passing }
		-- A piece the player has elsewhere takes no room: its place is kept for it, where it would stand. (The head
		-- always takes its room: the column goes where it goes.) Nor does one with nothing to show now: what
		-- stands under it closes up (and glides, Apply).
		if drawn or (Showing(box) and (box == head or not HUD.IsPlaced(box))) then
			y = y + height + (not drawn and Under(box) or SEAM)
		end
	end
	local x, start = 0, EDGE
	if not drawn then x, start = Origin(head, headAt) end
	for _, piece in ipairs(list) do piece.x, piece.y = x, start + piece.rel end
	return list, head, headAt
end

-- Where the column ends: how far under the screen's top the next piece would begin. For what stands
-- under the column without being a piece of it (a frame of the game's whose height is its own to change:
-- ShyDock seats an encounter's bar there).
function Top.Foot()
	local foot = Start()
	if Top.Moved() then return foot end
	for _, piece in ipairs(Top.Plan()) do
		if Showing(piece.box) and not HUD.IsPlaced(piece.box) then foot = math.max(foot, piece.y + piece.height + Under(piece.box)) end
	end
	return foot
end

-- A piece whose place changes while it shows glides there (GLIDE seconds, easing out); in a fight, or
-- unseen, it is put there at once.
local GLIDE = 0.2
local gliding = setmetatable({}, { __mode = "k" })   -- box -> { from, to, at } (distances under the top)
local glider

-- A piece's home, `pos` under the column's base: on the column's axis, set in as far as the head's drawer sets it,
-- at the head's size. The head's own home is its place at the top, wherever the player has it: let go of near
-- there, it goes home.
local function Home(box, pos)
	local _, shift = Indent(box)
	local x, y, scale = column.x, column.base + pos, nil
	if box == column.head and Moved(box) then
		x, y = 0, column.home
	elseif box.leader then
		scale = box.leader:GetScale()
	end
	local home = { "TOP", "TOP", x + shift * (scale or 1), -y }
	gave[box] = home
	giving = true
	if not Same(box.defaultPoint, home) or box.givenScale ~= scale then HUD.SetHome(box, home, scale) end
	giving = false
end

local function Along(g, now)
	local u = math.min(1, (now - g.at) / GLIDE)
	return g.from + (g.to - g.from) * (1 - (1 - u) ^ 3), u
end

local function Glide()
	local now, any = GetTime(), false
	local quiet = InCombatLockdown()
	for box, g in pairs(gliding) do
		local y, u = Along(g, now)
		if quiet then y, u = g.to, 1 end
		Home(box, y)
		if u >= 1 then gliding[box] = nil else any = true end
	end
	if not any then glider:SetScript("OnUpdate", nil) end
end

-- Every piece on its way is put where it is going (tests; drawings of the screen).
function Top.Settle()
	for box, g in pairs(gliding) do
		gliding[box] = nil
		Home(box, g.to)
	end
	if Top.Follow then Top.Follow(true) end   -- (and the drawer round what hangs)
end

local FOLD = 8                 -- a piece coming in folds down into its place from this far over it
local wasUp = setmetatable({}, { __mode = "k" })
local arranging, again = false, false

-- Who hangs in the drawer is settled first (a tray lays its cells again as that changes), so every piece is planned
-- at the size it has now. Asked again while it runs (a tray sized), it runs once more the next frame.
function Top.Apply()
	if arranging then
		again = true
		return
	end
	arranging = true
	Lead()
	Widen()
	if Top.Wrap then Top.Wrap() end
	local now, quiet = GetTime(), InCombatLockdown()
	local plan, head, headAt = Top.Plan()
	-- Measured from the screen's top while the column is at home (the game's widgets push it down, and it glides),
	-- from the column's own top while the head is elsewhere (dragged, it moves as one).
	local moved = Moved(head)
	column.head, column.home = head, Start() + headAt
	column.x = moved and plan[1] and plan[1].x or 0
	column.base = moved and plan[1] and plan[1].y - plan[1].rel or 0
	for _, piece in ipairs(plan) do
		local box = piece.box
		local pos = piece.y - column.base
		local was, g = at[box], gliding[box]
		-- (Planned from another base: the column was moved, or put back. It stands there at once.)
		if was and math.abs(was.base - column.base) > 0.01 then was, g, gliding[box] = nil, nil, nil end
		at[box] = { pos = pos, base = column.base }
		local up = Showing(box)
		local arriving = up and wasUp[box] == false
		wasUp[box] = up
		-- (What hangs in the drawer comes with the drawer, which slides out under it: it never folds down over the head.)
		if arriving and was and not quiet and not HUD.IsUnlocked() and not Top.Hung(box) then
			-- (Folds down out of the piece over it, as a hover's foot comes down.)
			gliding[box] = { from = pos - FOLD, to = pos, at = now }
			Home(box, pos - FOLD)
			glider = glider or CreateFrame("Frame")
			glider:SetScript("OnUpdate", Glide)
		elseif g and math.abs(g.to - pos) < 0.01 then
			-- (Already on its way there.)
		elseif was and not quiet and box:IsVisible() and math.abs(was.pos - pos) > 0.5 then
			gliding[box] = { from = g and Along(g, now) or was.pos, to = pos, at = now }
			glider = glider or CreateFrame("Frame")
			glider:SetScript("OnUpdate", Glide)
		else
			gliding[box] = nil
			Home(box, pos)
		end
	end
	Cover(plan, head)
	if Top.Follow then Top.Follow() end
	arranging = false
	if again then
		again = false
		Soon()
	end
end

-- Next frame, once: a box made or sized is often touched several times in a frame.
local soon = false
function Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		Top.Apply()
	end)
end

-- A home given by anyone else: theirs, unless it is the place the box was made with or the one the column
-- gave it last, which is how an arranger hands a box back.
local function Given(box, point)
	if giving or box.foreign or not box.top then return end
	theirs[box] = not (Same(point, box.madePoint) or Same(point, gave[box])) or nil
	Soon()
end

-- One piece
-- The head leads every other piece standing in the column (HUD.Lead): a press that drags one drags the head, and
-- the rest are placed from wherever it stands. A piece out of the column (someone else's, or shown elsewhere) is
-- its own again. Without a head in the column, each piece is.
function Lead()
	local members = Members()
	local head = HeadOf(members)
	local inside = {}
	for _, box in ipairs(members) do inside[box] = true end
	HUD.Each(function(box)
		if box.top and not box.foreign then HUD.Lead(box, inside[box] and head or nil) end
	end)
end

-- In layout mode the column is the head's: its mover lies over all of it, and what lines up with the column lines
-- up with all of it (HUD.Cover). The cover hangs from the head's top, so it goes where the head goes.
local cover, covering
function Cover(plan, head)
	if covering and covering ~= head then HUD.Cover(covering, covering) end
	covering = head
	if not head then return end
	if not cover then
		cover = CreateFrame("Frame", nil, UIParent)
		cover:EnableMouse(false)
	end
	if head.cover ~= cover then HUD.Cover(head, cover) end
	local top, foot, wide, headTop = nil, nil, head:GetWidth() * head:GetScale(), nil
	for _, piece in ipairs(plan) do
		if piece.box == head then headTop = piece.y end
		if piece.box == head or Showing(piece.box) then
			top = math.min(top or piece.y, piece.y)
			foot = math.max(foot or 0, piece.y + piece.height)
			wide = math.max(wide, piece.width)
		end
	end
	if not (top and headTop) then return end
	cover:ClearAllPoints()
	cover:SetPoint("TOP", head, "TOP", 0, headTop - top)
	cover:SetSize(wide, math.max(1, foot - top))
end

-- One width
-- Every plate in the column is as wide as the widest needs to be, and each stands with its ring's middle
-- under the head's circle's middle (SPINE in from its box's left), so the column reads as one piece:
--   Top.Want(box, plate)   -- the plate width (from its ring's middle to its point) this piece's words need
--                             (a tray's: its box's width, which Top.Tray asks for it)
--   Top.Width()            -- the width every plate is laid at: the widest want of the pieces showing
--   Top.SPINE              -- where a ring's middle stands in from its box's left: a box is the plate and
--                             SPINE either side, so the plate stands on the axis
-- Bus: SHY_TOP_WIDTH (width) when it changes; every piece lays itself out again then.
Top.SPINE = 23
local wants = setmetatable({}, { __mode = "k" })
local width = 0

function Widen()
	local most = 0
	for box, want in pairs(wants) do
		if box.top and not theirs[box] and Showing(box) and (box == column.head or not HUD.IsPlaced(box))
			and not (box.awayFn ~= nil and box.awayFn() == true) then
			most = math.max(most, want + (Indent(box)))
		end
	end
	most = 2 * math.ceil(most / 2)
	if most ~= width then
		width = most
		Shy:Fire("SHY_TOP_WIDTH", width)
		Relay()   -- (every tray's cells are laid at it)
	end
end

function Top.Want(box, plate)
	if wants[box] == plate then return end
	wants[box] = plate
	Widen()
end

-- (A piece in the head's drawer is laid narrower, by as much as the drawer sets it in: Top.Width(box). A tray
-- wants its box's width, the others their plate's.)
function Top.Width(box)
	return box and width - (Indent(box)) or width
end

-- The column's make
-- What every piece up there is made of, so they read as one (the notices' ribbon, the way back, the
-- mirror timers): the plaque pointed at its ends on a soft shadow at the hovers' strength, the weave kept
-- to it by the plate's mask (pointed at the right end), the steel ring a sign stands in.
--   Top.Make.Plaque(f, tall) -> p (tall: the head's 34 unit plaque, its own art); Shape(f, p, top, from,
--   bare, tall): from `from` to f's right end, pointed at `from` or (bare) begun square behind a ring;
--   Look(p) again on a theme's change
--   Top.Make.Mask(f) (pointed at f's right, TOP under its top), PlateMask(f, tall) (unplaced), Hatch(f, mask,
--   tall), Ring(f) (FACE across)
--   Measures: TALL, TOP (a plaque in a 24 row), POINT (TALL_POINT the tall one's), LIGHT, REACH, RING, FACE,
--   MASK.
--   The soft shadow is in the plaque's own shape, pointed end and all, fading out REACH units past it:
--   Top.Make.Shade(f, tall) -> s; ShadeShape(s, f, top, from, bare, tall) lays it as Shape lays the plaque;
--   ShadeAlpha(s, a). Pieces (PlaqueShade…, two texels a unit, one set a height): End at the point (mirrored
--   for a pointed start), Mid stretched along, Cap for a square start.
local Make = { TALL = 18, TOP = 3, POINT = 8, TALL_HIGH = 34, TALL_POINT = 15, LIGHT = 12, REACH = 6,
	RING = 24, FACE = 29, MASK = 512 }
Top.Make = Make

function Make.Shade(f, tall)
	local suffix = tall and "Tall" or ""
	local s = { point = tall and Make.TALL_POINT or Make.POINT, tall = tall and Make.TALL_HIGH or Make.TALL }
	s.cap = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.cap:SetTexture(Shy.MEDIA .. "PlaqueShadeCap" .. suffix)
	s.head = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.head:SetTexture(Shy.MEDIA .. "PlaqueShadeEnd" .. suffix)
	s.head:SetTexCoord(1, 0, 0, 1)
	s.mid = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.mid:SetTexture(Shy.MEDIA .. "PlaqueShadeMid" .. suffix)
	s.tail = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	s.tail:SetTexture(Shy.MEDIA .. "PlaqueShadeEnd" .. suffix)
	return s
end

-- The shadow under a plaque from `from` to f's right end, its top `top` under f's: pointed at both ends, or
-- (bare) begun square.
function Make.ShadeShape(s, f, top, from, bare)
	local reach, tall = Make.REACH, s.tall
	local high = tall + 2 * reach
	local start = bare and s.cap or s.head
	s.cap:SetShown(bare == true)
	s.head:SetShown(not bare)
	start:ClearAllPoints()
	start:SetSize(bare and 2 * reach or s.point + reach, high)
	start:SetPoint("TOPLEFT", f, "TOPLEFT", from - reach, -top + reach)
	s.tail:ClearAllPoints()
	s.tail:SetSize(s.point + reach, high)
	s.tail:SetPoint("TOPRIGHT", f, "TOPRIGHT", reach, -top + reach)
	s.mid:ClearAllPoints()
	s.mid:SetPoint("TOPLEFT", start, "TOPRIGHT")
	s.mid:SetPoint("BOTTOMRIGHT", s.tail, "BOTTOMLEFT")
end

function Make.ShadeAlpha(s, a)
	s.cap:SetAlpha(a)
	s.head:SetAlpha(a)
	s.mid:SetAlpha(a)
	s.tail:SetAlpha(a)
end

function Make.Plaque(f, tall)
	local p = { point = tall and Make.TALL_POINT or Make.POINT, tall = tall == true }
	local suffix = tall and "Tall" or ""
	p.shade = Make.Shade(f, tall)
	p.head = f:CreateTexture(nil, "BORDER")
	p.head:SetTexture(Shy.MEDIA .. "HoverPlaqueEnd" .. suffix)
	p.head:SetTexCoord(1, 0, 0, 1)
	p.tail = f:CreateTexture(nil, "BORDER")
	p.tail:SetTexture(Shy.MEDIA .. "HoverPlaqueEnd" .. suffix)
	p.mid = f:CreateTexture(nil, "BORDER")
	p.mid:SetTexture(Shy.MEDIA .. "HoverPlaqueMid" .. suffix)
	-- Where the plaque stands (laid by Shape): the rect its housing is fitted to in the other looks.
	Make.Material(f, p, CreateFrame("Frame", nil, f))
	return p
end

function Make.Shape(f, p, top, from, bare, tall)
	tall = tall or Make.TALL
	local point = p.point or Make.POINT
	p.head:SetShown(not bare)
	p.head:ClearAllPoints()
	p.head:SetSize(point, tall)
	p.head:SetPoint("TOPLEFT", f, "TOPLEFT", from, -top)
	p.tail:ClearAllPoints()
	p.tail:SetSize(point, tall)
	p.tail:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
	p.mid:ClearAllPoints()
	p.mid:SetPoint("TOPLEFT", f, "TOPLEFT", from + (bare and 0 or point), -top)
	p.mid:SetPoint("BOTTOMRIGHT", p.tail, "BOTTOMLEFT")
	Make.ShadeShape(p.shade, f, top, from, bare)
	p.area:ClearAllPoints()
	p.area:SetPoint("TOPLEFT", f, "TOPLEFT", from, -top)
	p.area:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, -(top + tall))
	Make.Look(p)
end

-- A plaque is a housing of the look worn, in its mini make (a plate of its kit on the plaque's own frame, under
-- everything its owner lays on it: the look's own frame, face, ornaments and light, smaller and simpler than a
-- window's), fitted to where the plaque stands, square in every look. A plaque its owner
-- draws itself (the zone's name, the arrow's box) names its pieces in p ({ head, mid, tail, shade }, any may be
-- missing, shade one texture or Make.Shade's) and where it stands (`area`, a region).
--   Top.Make.Material(f, p, area) -> p
--   Top.Make.Fill(p, frame)   a fill (Make.Drain, a status bar) laid to the plaque: inside its housing's frame
--   Top.Make.FillIn()         how far inside the plaque that is, for a fill its owner lays itself (the head's alarm)
local plaques = setmetatable({}, { __mode = "k" })   -- every plaque made, dressed again whenever the theme changes
function Make.Material(f, p, area)
	p.owner, p.area, p.kit, p.fills = f, area, Skin.NewKit(), {}
	-- (Its own: the kit keeps the plate's opts and dresses it with them again when the look changes.)
	p.housing = { key = "plaque", panel = true, hud = true, mini = true, brackets = false, fill = C.tip, to = area }
	plaques[p] = true
	return p
end
-- (The theme as it stands, counted: a plaque dressed for it is not dressed again until it changes. Make.Look)
local themed = 1
Shy:On("SHY_THEME", function()
	themed = themed + 1
	for p in pairs(plaques) do Make.Look(p) end
end)

function Make.Fill(p, d)
	p.fills[d] = true
	p.dressed = nil   -- (laid with the rest)
	Make.Look(p)
end

-- The fills: flush inside the plaque's own frame (its body lies FILL_IN in over its edge, in every look: a bar keeps
-- the rest of the plaque).
function Make.FillIn()
	return UI.LookArt.FILL_IN
end

local function LayFills(p)
	local i = Make.FillIn()
	for d in pairs(p.fills) do
		d:ClearAllPoints()
		d:SetPoint("TOPLEFT", p.area, "TOPLEFT", i, -i)
		d:SetPoint("BOTTOMRIGHT", p.area, "BOTTOMRIGHT", -i, i)
	end
end

-- The drawer
-- The head (its circle and the plate coming off it) is the column's own piece: `top = { head = true, wrap = true }`.
-- What says `top = { wrap = true }` hangs from its plate in one drawer: the look's mini border (its own smaller,
-- simpler make of the plate's frame, `mini`), run up under the plate's foot, set in from the plate's ends and starting
-- clear of the circle. What hangs in it is a tray of cells (below, "The tray"), and the drawer is made to them: a cell
-- runs from the drawer's inner face to its inner face, the first begins under the plate's foot, each stands right on
-- the next and the last stands on the drawer's foot. Nothing in it wears a frame, a ring or room of its own. The
-- pieces in it stand right under the head whatever their order (Rank), the head's own list (`top.hangs`) first of
-- all. The drawer slides out from under the plate as the first cell comes and back as the last goes (at once in a
-- fight). A piece the player has put elsewhere, or someone else arranges (a deck's), is a tray of its own.
--   top.foot = function() end    -- the head's: how far over its box's foot its plate's foot stands (the box's units)
--   top.hangs = function() end   -- the head's: a frame of its own hanging in the drawer now (its list), or nil
--   Top.Hung(box)         -- whether a piece hangs in the head's drawer
--   Top.Hanging()         -- whether anything does (the drawer stands)
--   Top.Bay()             -- left, right, lip: how far in from the head's plate's ends, and under its foot, a cell
--                         -- in the drawer stands (the head lays its own list by it)
--   Top.Drawer()          -- the drawer's frame while it stands, else nil
-- Bus: SHY_TOP_HUNG (standing) when who hangs in it changes.
local headPlaque                                       -- the head's plate (its tall plaque) while the drawer stands
-- GAP: between the circle and the drawer's side; TUCK: how far it runs up under the plate's foot; INSET: how far its
-- right end stands in from the plate's; STEP: edges on whole half units; SLIDE: how quickly its foot follows what it
-- holds (the share of the way left, a second); NEAR: within this it is there; BORDER: its border where the look says
-- none; LID, SHADE: the plate's shadow on the first cell, how far down it falls and how dark it starts; OVER: the
-- shadow's frame level, over the cells.
local WRAP = { GAP = 3, TUCK = 4, INSET = 10, STEP = 0.5, SLIDE = 16, NEAR = 0.25, BORDER = 4, LID = 6, SHADE = 0.34, OVER = 200 }
local drawer                                           -- { frame, laid = { l, b, r, t }, l, r, t, to, b }

local function BoxOf(p)
	if p.box == nil then
		local f = p.owner
		while f and not (f.id and f.top and HUD.Find(f.id) == f) do f = f:GetParent() end
		p.box = f or false
	end
	return p.box or nil
end

-- A tray's housing: the look's mini border, the hovers' fill (words stand on it over the world).
function Make.House(f)
	UI.Panel(f, { hud = true, mini = true, brackets = false, line = false, fill = C.tip })
end

-- A housing's border: its frame's inner face, in from its edge.
local function Border(f)
	local h = f.shyLook
	if h then return math.max(UI.LookBorder(h)) end
	return WRAP.BORDER
end

-- The drawer, made on first need (hidden: Follow shows it while something hangs).
local function Drawer()
	if drawer then return drawer end
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("BACKGROUND")
	f:EnableMouse(false)
	Make.House(f)
	f:Hide()
	-- The plate's shadow on what hangs under it: over the first cell's top, on a frame over the cells (theirs is the
	-- DIALOG strata), so the tray reads as lying under the plate it slides out of.
	local lid = CreateFrame("Frame", nil, f)
	lid:SetFrameStrata("DIALOG")
	lid:SetFrameLevel(WRAP.OVER)
	lid:EnableMouse(false)
	lid.shade = lid:CreateTexture(nil, "OVERLAY")
	lid.shade:SetAllPoints()
	lid.shade:SetColorTexture(1, 1, 1, 1)
	lid.shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, WRAP.SHADE))
	drawer = { frame = f, lid = lid, laid = {} }
	f:SetScript("OnUpdate", Shy.Clocked("top: the head's drawer", function(_, elapsed) Top.Follow(elapsed) end))
	return drawer
end

local function Edge()
	return Border(Drawer().frame)
end

-- Under the plate's foot the first cell stands clear of the plate's own frame: as far as the look draws a frame past
-- its piece's edge (UI.LookOut), on a whole STEP. A hairline look draws nothing there, and the cell stands on the foot.
local function Lip()
	return math.ceil(UI.LookOut(Drawer().frame.shyLook) / WRAP.STEP) * WRAP.STEP
end

function Top.Hung(box)
	return box ~= nil and headBox ~= nil and box ~= headBox and wrapping[box] == true
end

-- Whether the drawer stands: something hangs under the head.
function Top.Hanging()
	return headBox ~= nil
end

function Top.Bay()
	local edge = Edge()
	return Top.SPINE + WRAP.GAP + edge, WRAP.INSET + edge, Lip()
end

-- How far a piece in the drawer is set in: narrower than the head's plate by `less`, its box moved over by `shift`,
-- so its cells stand from the drawer's inner face to its inner face.
function Indent(box)
	if not Top.Hung(box) then return 0, 0 end
	local left, right = Top.Bay()
	return left + right, (left - right) / 2
end

-- The head's frame of its own hanging in the drawer (its list), while it shows.
local function Hangs(box)
	local fn = box and box.top.hangs
	local frame = fn and fn()
	if frame and frame:IsShown() then return frame end
end

-- The room a piece leaves under it: the seam. With the drawer standing, the head leaves its plate's foot and the lip
-- (the first cell begins there, beside the circle's foot) and what hangs of its own; a piece in the drawer none (the
-- next stands right on it), and the last thing in it the drawer's foot and the seam.
function Under(box)
	if not headBox then return Top.SEAM end
	if box == headBox then
		local scale = box:GetScale()
		local hangs = Hangs(box)
		local foot = box.top.foot and box.top.foot() or 0
		local room = Lip() - foot * scale + (hangs and hangs:GetHeight() * scale or 0)
		if lastBox == box then room = room + Edge() + Lip() + Top.SEAM end
		return room
	end
	-- (Under the drawer's foot what comes next stands clear of the drawer's own frame, as the first cell of the plate's.)
	if wrapping[box] then return box == lastBox and Edge() + Lip() + Top.SEAM or 0 end
	return Top.SEAM
end

-- A region's rect in UIParent's units, or nil.
local function RectOf(region)
	local x, y, w, h = region:GetRect()
	if not x or issecretvalue(x) or issecretvalue(w) or not w or w <= 0 or h <= 0 then return end
	local k = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * k, y * k, (x + w) * k, (y + h) * k
end

-- Where the drawer stands, in UIParent's units (nil: nothing in it shows): across, from the circle's edge to the
-- plate's right end less INSET; down, from under the plate's foot to its border under the last cell.
local function Bounds()
	local p = headPlaque
	if not (headBox and p and p.owner:IsVisible()) then return end
	local left, foot, right = RectOf(p.area)
	if not left then return end
	local low
	for box in pairs(wrapping) do
		if box ~= headBox and box:IsVisible() and box:GetAlpha() > 0.05 then
			local _, y = RectOf(box)
			if y then low = math.min(low or y, y) end
		end
	end
	local hangs = Hangs(headBox)
	if hangs and hangs:IsVisible() then
		local _, y = RectOf(hangs)
		if y then low = math.min(low or y, y) end
	end
	if not low then return end
	return left + Top.SPINE + WRAP.GAP, low - Edge(), right - WRAP.INSET, foot + WRAP.TUCK
end

-- The drawer stands round what hangs, every frame it is up: its sides and top the plate's, its foot gliding to the
-- last cell's (out from under the plate as the first comes, back under it as the last goes; at once in a fight, and
-- wherever no time passes: Top.Settle). All the way in with nothing hanging, it is put away.
local function Follow(elapsed)
	if not drawer and not headBox then return end
	local d = Drawer()
	local f, step = d.frame, WRAP.STEP
	local l, b, r, t = Bounds()
	if l then
		d.l, d.r, d.t = math.floor(l / step) * step, math.ceil(r / step) * step, math.ceil(t / step) * step
		d.to = math.floor(b / step) * step
	elseif not d.t then
		f:Hide()
		return
	end
	local shut = d.t - WRAP.TUCK
	local to = l and d.to or shut
	local at = d.b or shut
	if InCombatLockdown() or elapsed == true then
		at = to
	elseif elapsed then
		at = at + (to - at) * math.min(1, elapsed * WRAP.SLIDE)
		if math.abs(to - at) < WRAP.NEAR then at = to end
	end
	d.b = at
	if not l and at >= shut then
		d.b, d.t = nil, nil
		wipe(d.laid)
		f:Hide()
		return
	end
	f:Show()
	local laid = d.laid
	if laid[1] == d.l and laid[2] == at and laid[3] == d.r and laid[4] == d.t then return end
	laid[1], laid[2], laid[3], laid[4] = d.l, at, d.r, d.t
	f:ClearAllPoints()
	f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", d.l, at)
	f:SetSize(d.r - d.l, math.max(1, d.t - at))
	-- The plate's shadow: from where the first cell begins, never past the drawer's inner foot.
	local edge, lip = Edge(), Lip()
	local room = d.t - WRAP.TUCK - lip - (at + edge)
	d.lid:SetShown(room > 0)
	if room > 0 then
		d.lid:ClearAllPoints()
		d.lid:SetPoint("TOPLEFT", f, "TOPLEFT", edge, -(WRAP.TUCK + lip))
		d.lid:SetPoint("TOPRIGHT", f, "TOPRIGHT", -edge, -(WRAP.TUCK + lip))
		d.lid:SetHeight(math.min(WRAP.LID, room))
	end
end
Top.Follow = Follow

-- Who hangs in it: the pieces that say so, in the column's place and showing, under the head wherever it stands;
-- the drawer stands while any does, or the head's own list is open. In layout mode too: the column is one piece
-- there as in play, each piece in it showing what it would say.
local function Wrap()
	local now, head, last, n = {}, nil, nil, 0
	for _, box in ipairs(Members()) do
		if box.top.wrap and Showing(box) and box:IsShown() then
			if box.top.head then
				head = box
			elseif not HUD.IsPlaced(box) then
				now[box] = true
				last = box
				n = n + 1
			end
		end
	end
	if not head then
		wipe(now)
		last, n = nil, 0
	end
	if head and (n > 0 or Hangs(head)) then
		now[head] = true
		last = last or head
	else
		wipe(now)
		head, last = nil, nil
	end
	local changed = head ~= headBox
	for box in pairs(wrapping) do if not now[box] then changed = true end end
	for box in pairs(now) do if not wrapping[box] then changed = true end end
	lastBox = last
	if changed then
		wipe(wrapping)
		for box in pairs(now) do wrapping[box] = true end
		headBox, headPlaque = head, nil
		for p in pairs(plaques) do
			if head and p.tall and BoxOf(p) == head then headPlaque = p end
		end
		Relay()    -- (every tray is laid again: in the drawer, or by itself)
		Widen()
		Soon()     -- (and the pieces stood again, set in or back on the axis)
		Shy:Fire("SHY_TOP_HUNG", headBox ~= nil)
	end
end
Top.Wrap = Wrap

function Top.Drawer()
	local f = drawer and drawer.frame
	return f and f:IsShown() and f or nil
end

Shy:On("SHY_HUD_LAYOUT", function() Top.Apply() end)
-- (The drawer's border is the look's, and a tray's by itself: a change of look lays every tray again.)
Shy:On("SHY_THEME", function()
	Relay()
	Widen()
	Soon()
end)

-- The plaque by the theme's look (owners call this again on SHY_THEME): no point and no plaque of its own in any
-- look, but the look's housing where it stands (a plate of its kit at the hovers' strength: text stands on it over
-- the world), dressed again whenever the look changes. Its owners ask at every change of their words or their
-- width: one dressed for the theme as it stands is left as it is (its housing lays itself again as its size
-- changes), and only what its owner may have painted of its own pieces is put away again.
function Make.Look(p)
	if p.head then p.head:SetVertexColor(1, 1, 1, 0) end
	if p.mid then p.mid:SetVertexColor(1, 1, 1, 0) end
	if p.tail then p.tail:SetVertexColor(1, 1, 1, 0) end
	local s = p.shade
	if s then
		if s.cap then Make.ShadeAlpha(s, 0) else s:SetAlpha(0) end
	end
	if not p.kit or p.dressed == themed then return end
	p.kit:Plate(p.owner, p.housing)
	p.wore, p.dressed = true, themed
	LayFills(p)
end

-- The weave: tall, the head's 34 unit plaque's (Skin.HATCH_TALL, drawn for it).
function Make.Hatch(f, mask, tall)
	local t = f:CreateTexture(nil, "BORDER", nil, 3)
	Skin.Hatch(t, tall)
	t:AddMaskTexture(mask)
	return t
end

-- The plate's mask: the inside of a plaque, pointed at its right end, MASK units long (longer than any plate
-- up there, so stood on a plate's right end it covers all of it); tall: the head's 34 unit plaque's, whose
-- point is its own. PlateMaskLong / PlateMaskLongTall, two texels a unit.
function Make.PlateMask(f, tall)
	local mask = f:CreateMaskTexture()
	-- (Square: no piece is pointed in any look. Solid art of ours, kept to the mask's own rect.)
	mask:SetTexture(Shy.MEDIA .. "HoverPlaqueMid", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetSize(Make.MASK, tall and Make.TALL_HIGH or Make.TALL)
	return mask
end

-- A bar's fill: the weave laid once along the whole bar, still, behind a window that narrows from the right
-- as the share falls, so only its end moves and only ever leftward (a status bar crops its fill's texture
-- as it runs, and the weave in it seemed to run one way while its end ran the other). Kept to the plaque by
-- the plate's mask, pointed at the right. The window's right edge is an unseen status bar's fill's, so the
-- share may be a secret (your health, as the game evaluates it): the game lays it, nothing here reads it.
--   Top.Make.Drain(f, tall) -> d (a frame: anchor it as the bar; tall: on the head's 34 unit plaque);
--   d:Share(0..1, or a secret); d.fill (tint it); d.mask
function Make.Drain(f, tall)
	local d = CreateFrame("Frame", nil, f)
	d.mask = Make.PlateMask(d, tall)
	d.mask:SetPoint("RIGHT", d, "RIGHT")
	Skin.DrainClip(d)
	d.measure:SetMinMaxValues(0, 1)
	d.measure:SetValue(1)
	Skin.Hatch(d.fill, tall)
	d.fill:AddMaskTexture(d.mask)
	function d:Share(share)
		self.measure:SetValue(share)
	end
	return d
end

function Make.Mask(f)
	local mask = Make.PlateMask(f)
	mask:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -Make.TOP)
	return mask
end

function Make.Ring(f)
	local ring = f:CreateTexture(nil, "ARTWORK", nil, 1)
	ring:SetTexture(Shy.MEDIA .. "DialSmall")
	ring:SetSize(Make.FACE, Make.FACE)
	ring.look = UI.LookRing(ring, Make.RING)   -- the look's border round it (ring.look:Plain(false) under a meaning's color)
	return ring
end

-- The tray
-- What hangs under the head is a tray of cells: every row the same square make, flush from side to side, one right
-- on the next with a hairline between. A cell is a tab (a square: a sign on a wash of its color, or a picture in a
-- slot), then its name and what stands at its right. Where it counts, the cell itself is the meter: the bars' weave
-- over its whole height from the tab on, filling or draining, a line of light where it ends. The circle is the
-- head's alone: nothing in a tray is round, and nothing in it has room of its own round it.
--   Top.Tray(box, { least = 150, lay = function() end }) -> tray
--       a column piece's tray. In the head's drawer the box is its cells and the drawer frames them; by itself
--       (a place the player gave it, a deck) the box is the tray, the look's mini border round the cells
--       (border-box). `lay`: the piece lays its cells again (the column's width, who hangs or the look changed)
--   tray:Fit(need, tall) -> width, inset
--       need: the widest its cells' words need; tall: its cells' height all together (0: none). Sizes the box and
--       tells the column: a cell is `width` wide, the first `inset` in from the box's top left (tray.width, .inset)
--   tray:Fix(width)   the width someone else gives the box (a deck's column), nil: the column's again. Docked in
--       a deck (HUD.SetDocked) the deck is its housing: it wears none of its own
--   Top.Make.Cell(parent, kind) -> cell   (kind: "Button" for one that is clicked)
--   cell:Set({ sign = a hover glyph's name, file = art drawn for GLYPH units, icon = a picture (in a slot),
--       mark = an item's quality color round its slot, color = its meaning's, name, nameColor, right, rightColor,
--       room = units kept for what stands at the right while it counts, fill = the meter's color (nil: none),
--       indent = 1, tab = false (words alone, centred: said, saidColor, strip = their meaning's color) }) -> need
--       (the width its words need, nil where the game keeps them secret; also cell.need)
--   cell:Share(share)   the meter, 0 to 1        cell:Pulse(p)   lit as it changes (1 down to 0)
--   cell:Gleam(u)       a light crossing the meter, u of the way (nil: none)
--   cell:Rule(on)       the hairline along its top (off on the first cell of a tray standing by itself)
--   cell:Hot(on)        under the mouse          cell:Dim(on)    its meter paused
--   Top.Make.Heading(parent) -> heading; heading:Set({ sign, file, title, color }) -> need; heading:Rule(on)
--   Top.Make.Still(frame, wide, rows) -> frame    a tray by itself holding `rows` (cells, headings): a picture
--   Top.Make.CELL       the measures: ROW a cell's height, RULE between two, HEAD a heading's
local CELL = {
	ROW = 20, RULE = 1, TAB = 20, GLYPH = 12, PAD = 8, GAP = 10, INDENT = 14, STRIP = 2, LIGHT = 12,
	HEAD = 16, HEADING = 10, HAIR = 24, NAME = 13, RIGHT = 12, SAID = 13,
	LINE = 0.22,              -- a hairline's strength, in the look's metal
	WASH = { 0.10, 0.36 },    -- a tab's wash of its color: at its foot, at its top
	BAND = 0.14,              -- a heading's wash of its color, at its top (none at its foot)
	FILL = 0.75, PAUSED = 0.45, TIP = 0.6, GLEAM = 0.45, HOT = 0.08, FLARE = 0.9,
	-- A line is as tall as its size and its baseline at the font's ascender share of it: the title font's and the
	-- rounded font's (the title font is the rounded one for Cyrillic).
	TITLE_SHARE = 0.923 / (0.923 + 0.220), ROUND_SHARE = 1.011 / (1.011 + 0.353),
}
Make.CELL = CELL
do
	-- The name and what stands at its right share a baseline: the name's capitals centred on the cell.
	local share = GetLocale() == "ruRU" and CELL.ROUND_SHARE or CELL.TITLE_SHARE
	local base = math.floor(CELL.NAME * (share - 0.5) + 0.5)
	CELL.NAME_Y = CELL.NAME * (share - 0.5) - base
	CELL.RIGHT_Y = CELL.RIGHT * (CELL.ROUND_SHARE - 0.5) - base
end

local function Hue(color)
	if type(color) == "function" then return color() end
	return color[1], color[2], color[3]
end

local function Words(parent, font, side)
	return UI.Words(parent, font, nil, { wrap = false, justify = side })
end

-- The width a string's words need whole, or nil where the game keeps it secret.
local function Wide(fs)
	local w = fs:GetUnboundedStringWidth()
	if w == nil or issecretvalue(w) then return nil end
	return w
end

local function Even(w) return 2 * math.ceil(w / 2) end

-- A hairline in the look's metal.
local function Hair(parent)
	local t = parent:CreateTexture(nil, "ARTWORK", nil, 3)
	t:SetColorTexture(1, 1, 1, 1)
	UI.Tint(t, Theme.skin.metal, CELL.LINE)
	return t
end

local CellOf = {}

-- The slot a picture stands in: the tab itself, made the first time a cell shows one.
local function Hold(c)
	local hold = CreateFrame("Frame", nil, c.tab)
	hold:SetAllPoints()
	c.icon = hold:CreateTexture(nil, "ARTWORK")
	c.icon:SetAllPoints()
	c.slot = Shy.Slot.New(hold, { icon = c.icon, size = CELL.TAB, hover = false })
	c.hold = hold
	return hold
end

function CellOf:Set(d)
	local indent = (d.indent or 0) * CELL.INDENT
	local tabbed = d.tab ~= false
	local color = d.color or C.text
	local r, g, b = Hue(color)
	self.tab:SetShown(tabbed)
	self.tab:ClearAllPoints()
	self.tab:SetPoint("TOPLEFT", self, "TOPLEFT", indent, 0)
	self.rule:ClearAllPoints()
	self.rule:SetPoint("TOPLEFT", self, "TOPLEFT", indent, 0)
	self.rule:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
	-- The tab: a picture in its slot, or a sign in its color's light on a wash of the color.
	local pictured = tabbed and d.icon ~= nil
	self.wash:SetShown(not pictured)
	self.glyph:SetShown(not pictured)
	self.edge:SetShown(not pictured)
	if pictured then
		local hold = self.hold or Hold(self)
		hold:Show()
		self.icon:SetTexture(d.icon)
		if d.mark then self.slot:Mark(Hue(d.mark)) else self.slot:Mark() end
	else
		if self.hold then self.hold:Hide() end
		if d.file then
			self.glyph:SetTexture(d.file)
			self.glyph:SetTexCoord(0, 1, 0, 1)
		else
			Shy.Hover.Glyph(self.glyph, d.sign or "note", CELL.GLYPH)
		end
		UI.Tint(self.glyph, Make.Light(color))
		self.wash:SetGradient("VERTICAL", CreateColor(r, g, b, CELL.WASH[1]), CreateColor(r, g, b, CELL.WASH[2]))
	end
	-- The meter: the cell's body, from the tab on.
	local fill = tabbed and d.fill or nil
	self.bar:SetShown(fill ~= nil)
	self.tip:SetShown(fill ~= nil)
	self.bar:ClearAllPoints()
	self.bar:SetPoint("TOPLEFT", self, "TOPLEFT", indent + CELL.TAB, 0)
	self.bar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
	if fill then
		UI.Tint(self.bar.fill, fill, CELL.FILL)
		UI.Tint(self.tip, Make.Light(fill), CELL.TIP)
	end
	UI.Tint(self.flare, color, 1)
	self.flare:ClearAllPoints()
	self.flare:SetPoint("TOPLEFT", self, "TOPLEFT", indent, 0)
	self.flare:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
	-- Its words, and the room they need.
	self.name:SetShown(tabbed)
	self.right:SetShown(tabbed)
	self.said:SetShown(not tabbed)
	self.strip:SetShown(not tabbed and d.strip ~= nil)
	local need
	if tabbed then
		self.name:SetText(d.name or "")
		self.right:SetText(d.right or "")
		UI.Ink(self.name, d.nameColor or C.text)
		UI.Ink(self.right, d.rightColor or C.head)
		self.name:ClearAllPoints()
		self.name:SetPoint("LEFT", self, "LEFT", indent + CELL.TAB + CELL.PAD, CELL.NAME_Y)
		self.name:SetPoint("RIGHT", self.right, "LEFT", -CELL.GAP, CELL.NAME_Y - CELL.RIGHT_Y)
		local name = Wide(self.name)
		local right = math.max(Wide(self.right) or 0, d.room or 0)
		need = name and indent + CELL.TAB + CELL.PAD + name + (right > 0 and CELL.GAP + right or 0) + CELL.PAD
	else
		self.said:SetText(d.said)
		UI.Ink(self.said, d.saidColor or C.text)
		if d.strip then UI.Tint(self.strip, d.strip, 1) end
		local said = Wide(self.said)
		need = said and said + 2 * (CELL.STRIP + CELL.PAD)
	end
	self.need = need and Even(need) or nil
	return self.need
end

function CellOf:Share(share)
	self.bar.measure:SetValue(share)
end

function CellOf:Pulse(p)
	self.flare:SetAlpha(CELL.FLARE * p)
end

function CellOf:Dim(on)
	self.bar:SetAlpha(on and CELL.PAUSED or 1)
end

function CellOf:Rule(on)
	self.rule:SetShown(on)
end

function CellOf:Hot(on)
	self.hot:SetShown(on)
end

function CellOf:Gleam(u)
	local gleam = self.bar.gleam
	if not u then
		gleam:Hide()
		return
	end
	local reach = gleam:GetWidth()
	gleam:ClearAllPoints()
	gleam:SetPoint("LEFT", self.bar, "LEFT", -reach + (self.bar:GetWidth() + reach) * u, 0)
	gleam:SetAlpha(CELL.GLEAM * math.sin(math.pi * u))
	gleam:Show()
end

function Make.Cell(parent, kind)
	local c = CreateFrame(kind or "Frame", nil, parent)
	c:SetHeight(CELL.ROW)
	c.tall = CELL.ROW
	-- The meter: the weave laid once along the whole cell, still, behind a window that narrows from the right (as
	-- Make.Drain's: its edge an unseen status bar's, so the game lays it), square and the cell's whole height.
	local bar = CreateFrame("Frame", nil, c)
	bar:EnableMouse(false)
	bar:SetPoint("TOPLEFT", c, "TOPLEFT", CELL.TAB, 0)
	bar:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 0)
	Skin.DrainClip(bar)
	bar.measure:SetMinMaxValues(0, 1)
	bar.measure:SetValue(1)
	Skin.Hatch(bar.fill)
	bar.gleam = bar.window:CreateTexture(nil, "OVERLAY")
	bar.gleam:SetTexture(Shy.MEDIA .. "Sheen")
	bar.gleam:SetSize(CELL.ROW * 2, CELL.ROW)
	bar.gleam:Hide()
	bar:Hide()
	c.bar = bar
	-- Everything else stands over the meter.
	local over = CreateFrame("Frame", nil, c)
	over:EnableMouse(false)
	over:SetAllPoints()
	over:SetFrameLevel(bar:GetFrameLevel() + 3)
	c.over = over
	c.hot = over:CreateTexture(nil, "BACKGROUND", nil, 1)
	c.hot:SetAllPoints()
	c.hot:SetColorTexture(1, 1, 1, CELL.HOT)
	c.hot:Hide()
	-- Where the meter ends: a line of light, on the window's own edge.
	c.tip = over:CreateTexture(nil, "ARTWORK", nil, 1)
	c.tip:SetColorTexture(1, 1, 1, 1)
	c.tip:SetWidth(1)
	c.tip:SetPoint("TOPRIGHT", bar.measureFill, "TOPRIGHT")
	c.tip:SetPoint("BOTTOMRIGHT", bar.measureFill, "BOTTOMRIGHT")
	c.tip:Hide()
	c.tab = CreateFrame("Frame", nil, over)
	c.tab:EnableMouse(false)
	c.tab:SetSize(CELL.TAB, CELL.ROW)
	c.tab:SetPoint("TOPLEFT")
	c.wash = c.tab:CreateTexture(nil, "BACKGROUND")
	c.wash:SetAllPoints()
	c.wash:SetColorTexture(1, 1, 1, 1)
	c.glyph = c.tab:CreateTexture(nil, "ARTWORK")
	c.glyph:SetSize(CELL.GLYPH, CELL.GLYPH)
	c.glyph:SetPoint("CENTER")
	c.edge = Hair(c.tab)
	c.edge:SetWidth(CELL.RULE)
	c.edge:SetPoint("TOPRIGHT")
	c.edge:SetPoint("BOTTOMRIGHT")
	c.rule = Hair(over)
	c.rule:SetHeight(CELL.RULE)
	c.rule:SetPoint("TOPLEFT")
	c.rule:SetPoint("TOPRIGHT")
	c.strip = over:CreateTexture(nil, "ARTWORK", nil, 2)
	c.strip:SetColorTexture(1, 1, 1, 1)
	c.strip:SetWidth(CELL.STRIP)
	c.strip:SetPoint("TOPLEFT")
	c.strip:SetPoint("BOTTOMLEFT")
	c.strip:Hide()
	-- Lit as it changes: a light along its top in its color, gone at rest.
	c.flare = over:CreateTexture(nil, "ARTWORK", nil, 4)
	c.flare:SetTexture(Shy.MEDIA .. "HoverLight")
	c.flare:SetHeight(CELL.LIGHT)
	c.flare:SetPoint("TOPLEFT")
	c.flare:SetPoint("TOPRIGHT")
	c.flare:SetAlpha(0)
	c.name = Words(over, UI.TitleFont(CELL.NAME), "LEFT")
	c.right = Words(over, UI.NameFont(CELL.RIGHT), "RIGHT")
	c.right:SetPoint("RIGHT", c, "RIGHT", -CELL.PAD, CELL.RIGHT_Y)
	c.said = Words(over, UI.TextFont(CELL.SAID), "CENTER")
	c.said:SetPoint("LEFT", c, "LEFT", CELL.STRIP + CELL.PAD, 0)
	c.said:SetPoint("RIGHT", c, "RIGHT", -(CELL.STRIP + CELL.PAD), 0)
	c.said:Hide()
	for name, fn in pairs(CellOf) do c[name] = fn end
	return c
end

-- A heading over a run of cells: its sign and title in its color on the tray's middle, a hairline fading out either
-- side, a wash of the color falling from its top.
function Make.Heading(parent)
	local h = CreateFrame("Frame", nil, parent)
	h:EnableMouse(false)
	h:SetHeight(CELL.HEAD)
	h.tall = CELL.HEAD
	h.wash = h:CreateTexture(nil, "BACKGROUND")
	h.wash:SetAllPoints()
	h.wash:SetColorTexture(1, 1, 1, 1)
	h.rule = Hair(h)
	h.rule:SetHeight(CELL.RULE)
	h.rule:SetPoint("TOPLEFT")
	h.rule:SetPoint("TOPRIGHT")
	h.words = Words(h, UI.NameFont(CELL.HEADING), "CENTER")
	h.words:SetPoint("CENTER", h, "CENTER", (CELL.HEADING + 4) / 2, 0)
	h.glyph = h:CreateTexture(nil, "ARTWORK")
	h.glyph:SetSize(CELL.HEADING, CELL.HEADING)
	h.glyph:SetPoint("RIGHT", h.words, "LEFT", -4, 0)
	h.left = h:CreateTexture(nil, "ARTWORK")
	h.left:SetColorTexture(1, 1, 1, 1)
	h.left:SetHeight(1)
	h.left:SetPoint("LEFT", h, "LEFT", CELL.PAD, 0)
	h.left:SetPoint("RIGHT", h.glyph, "LEFT", -6, 0)
	h.right = h:CreateTexture(nil, "ARTWORK")
	h.right:SetColorTexture(1, 1, 1, 1)
	h.right:SetHeight(1)
	h.right:SetPoint("LEFT", h.words, "RIGHT", 6, 0)
	h.right:SetPoint("RIGHT", h, "RIGHT", -CELL.PAD, 0)
	function h:Set(d)
		local color = d.color or C.text
		local r, g, b = Hue(color)
		if d.file then
			self.glyph:SetTexture(d.file)
			self.glyph:SetTexCoord(0, 1, 0, 1)
		else
			Shy.Hover.Glyph(self.glyph, d.sign or "note", CELL.HEADING)
		end
		UI.Tint(self.glyph, color)
		UI.Ink(self.words, color)
		self.words:SetText((d.title or ""):upper())
		self.left:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.45))
		self.right:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.45), CreateColor(r, g, b, 0))
		self.wash:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, CELL.BAND))
		local words = Wide(self.words)
		self.need = words and Even(CELL.HEADING + 4 + words + 2 * (6 + CELL.HAIR + CELL.PAD)) or nil
		return self.need
	end
	function h:Rule(on)
		self.rule:SetShown(on)
	end
	return h
end

-- A tray by itself as a picture: `f` dressed as the tray, `rows` stood in it one on the next, `width` across border
-- and all; it is as tall as they need.
function Make.Still(f, wide, rows)
	Make.House(f)
	local e = Border(f)
	local y = e
	for i, row in ipairs(rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", f, "TOPLEFT", e, -y)
		row:SetWidth(wide - 2 * e)
		row:Rule(i > 1)
		y = y + row.tall + (i < #rows and CELL.RULE or 0)
	end
	f:SetSize(wide, y + e)
	return f
end

local trays = setmetatable({}, { __mode = "k" })   -- box -> its tray
local Tray = {}
Tray.__index = Tray

function Top.Tray(box, opts)
	opts = opts or {}
	-- Its own housing, for while it stands by itself: on the box, under its cells.
	local house = CreateFrame("Frame", nil, box)
	house:EnableMouse(false)
	house:SetAllPoints()
	house:SetFrameLevel(box:GetFrameLevel())
	Make.House(house)
	house:Hide()
	local tray = setmetatable({ box = box, house = house, least = opts.least or 0, lay = opts.lay, inset = 0,
		width = opts.least or 0 }, Tray)
	trays[box] = tray
	return tray
end

function Tray:Fit(need, tall)
	local box = self.box
	local bare = Top.Hung(box) or box.docked == true
	local e = bare and 0 or Border(self.house)
	need = math.max(need or 0, self.least)
	-- (The column may lay every tray again as it takes this one's want: not this one, which is being laid.)
	self.fitting = true
	Top.Want(box, tall > 0 and need + 2 * e or 0)
	self.fitting = nil
	local wide = self.fixed or math.max(need + 2 * e, Top.Width(box))
	self.inset, self.width = e, wide - 2 * e
	self.house:SetShown(not bare and tall > 0)
	HUD.Resize(box, wide, math.max(tall, CELL.ROW) + 2 * e)
	return self.width, e
end

function Tray:Fix(width)
	if self.fixed == width then return end
	self.fixed = width
	if self.lay then self.lay() end
end

function Relay()
	for _, tray in pairs(trays) do
		if tray.lay and not tray.fitting then tray.lay() end
	end
end

-- A sign in the head's circle, in the arrow's make (the waypoint arrow there): the dial's ring, the weave on
-- its dark face and a soft light in its middle, all in the color's light (Theme.Hot), the sign in it too.
-- The head's own signs (HeadSigns.blp, every size drawn at its own: news, a place discovered, the server's word, the bags full, a level,
-- an alarm, a caught error, air running out) fill the face as the arrow's emblem does once there, EMBLEM units, drawn for it;
-- any other (a hover glyph's name, or a file drawn for SIGN units) stands at SIGN.
--   Top.Make.SIGNS: the sheet's names, in its order
--   Top.Make.Sign(texture, sign) -> the size to show it at
--   Top.Make.Light(color) -> { r, g, b }: the color's light (a palette table, { r, g, b } or a function)
Make.SIGNS = { "news", "go", "talk", "full", "level", "alert", "bug", "breath" }
Make.EMBLEM, Make.SIGN = 44, 24
local SIGN_CELL = {}
for i, name in ipairs(Make.SIGNS) do SIGN_CELL[name] = i - 1 end

function Make.Sign(texture, sign)
	local cell = SIGN_CELL[sign]
	if cell then
		local col, row = cell % 4, math.floor(cell / 4)
		texture:SetTexture(Shy.MEDIA .. "HeadSigns")
		texture:SetTexCoord(col / 4, (col + 1) / 4, row / 2, (row + 1) / 2)
		return Make.EMBLEM
	end
	if sign:find("\\", 1, true) then
		texture:SetTexture(sign)
		texture:SetTexCoord(0, 1, 0, 1)
	else
		Shy.Hover.Glyph(texture, sign, Make.SIGN)
	end
	return Make.SIGN
end

function Make.Light(color)
	local r, g, b
	if type(color) == "function" then r, g, b = color() else r, g, b = color[1], color[2], color[3] end
	return { Theme.Hot(r, g, b) }
end

-- The way back from death
-- Our own button for what the game's does (PortGraveyard, which the game doesn't protect): the spirit
-- healer in a steel ring, floating a little past the head's point while you are a ghost (the head then
-- says where your body lies). Its hover names it. The game's button stays seated under ours, its pieces
-- faded and small enough that all of it is under ours, so a click is never its.
--   Top.Graveyard.New(parent) -> button
local SPIRIT = { 0.70, 0.88, 1.00 }
local SPIRIT_ICON = "Interface\\Icons\\spell_holy_guardianspirit"
local GRAVE_RING, GRAVE_FACE = 34, 42   -- the ring across (the head's plate's height), its art's size (DialMid)
local GRAVE_ICON = 28                   -- the spirit healer inside the ring: its face (29 across)
local GRAVE_ZOOM = 0.08                 -- the icon's square frame, cut away so its art fills the round
local GRAVE_GAP = 10                    -- from the head's point to the ring
local Grave = {}
Top.Graveyard = Grave

function Grave.New(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(GRAVE_RING, GRAVE_RING)
	b.glow = b:CreateTexture(nil, "BACKGROUND")
	b.glow:SetTexture(Shy.MEDIA .. "Glow")
	b.glow:SetSize(GRAVE_RING * 2, GRAVE_RING * 2)
	b.glow:SetPoint("CENTER")
	UI.Tint(b.glow, SPIRIT, 0.35)
	b.ring = b:CreateTexture(nil, "ARTWORK")
	b.ring:SetTexture(Shy.MEDIA .. "DialMid")
	b.ring:SetSize(GRAVE_FACE, GRAVE_FACE)
	b.ring:SetPoint("CENTER")
	UI.Tint(b.ring, Theme.skin.metal)
	b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.icon:SetTexture(SPIRIT_ICON)
	b.icon:SetTexCoord(GRAVE_ZOOM, 1 - GRAVE_ZOOM, GRAVE_ZOOM, 1 - GRAVE_ZOOM)
	b.icon:SetSize(GRAVE_ICON, GRAVE_ICON)
	b.icon:SetPoint("CENTER")
	local round = b:CreateMaskTexture()
	round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	round:SetAllPoints(b.icon)
	b.icon:AddMaskTexture(round)
	UI.Concentric(b.glow, b.ring, b.icon)
	b:RegisterForClicks("LeftButtonUp")
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
		PortGraveyard()
	end)
	b:SetScript("OnEnter", function(self)
		UI.Tint(self.glow, SPIRIT, 0.8)
		UI.Tip(self, RETURN_TO_GRAVEYARD)
	end)
	b:SetScript("OnLeave", function(self)
		UI.Tint(self.glow, SPIRIT, 0.35)
		UI.TipHide(self)
	end)
	return b
end

local own                      -- the way back on screen
local ghostKit                 -- fades the game's button's pieces
local seatingGhost = false

-- The game's button under ours, small enough that all of it is under it.
local function SitGhost()
	if seatingGhost or not own then return end
	seatingGhost = true
	local fit = math.min(GRAVE_RING / GhostFrame:GetWidth(), GRAVE_RING / GhostFrame:GetHeight())
	GhostFrame:SetScale(own:GetEffectiveScale() / UIParent:GetEffectiveScale() * fit)
	GhostFrame:ClearAllPoints()
	GhostFrame:SetPoint("CENTER", own, "CENTER", 0, 0)
	seatingGhost = false
end

-- Shown while you are a ghost who can go back (CanPortGraveyard: not at the graveyard already), a little
-- past the head's point, on the middle of its plate (it follows the plate as it glides wider or narrower,
-- and the head wherever it is placed). The game shows its own button only as you release, if you can go
-- back then (and released at the graveyard, you can't), so ours asks the game itself: on the death events
-- and, while you are a ghost, every GHOST_EVERY seconds as you walk.
local GHOST_EVERY = 1
local ghostWatch = CreateFrame("Frame")
local function Ghosted()
	local ghost = UnitIsGhost("player")
	own:SetShown(ghost and CanPortGraveyard())
	SitGhost()
	local since = 0
	ghostWatch:SetScript("OnUpdate", ghost and function(_, elapsed)
		since = since + elapsed
		if since < GHOST_EVERY then return end
		since = 0
		own:SetShown(CanPortGraveyard())
	end or nil)
end

-- On the head's plate.
local function Hang()
	local plate = Shy.Notices.Plate()
	own:SetParent(plate:GetParent())
	own:SetFrameStrata("HIGH")
	own:ClearAllPoints()
	own:SetPoint("LEFT", plate, "RIGHT", GRAVE_GAP, 0)
	Ghosted()
end

-- The zone's name as the game writes it over the world: where you are now, in the game's own fonts and
-- the color it has for this land.
local function ZonePicture(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(ZONE.w, ZONE.h)
	local zone = f:CreateFontString(nil, "ARTWORK", "ZoneTextFont")
	zone:SetPoint("TOP")
	local area = f:CreateFontString(nil, "ARTWORK", "SubZoneTextFont")
	area:SetPoint("TOP", zone, "BOTTOM")
	local function Read()
		local name, under = GetZoneText(), GetSubZoneText()
		zone:SetText(name)
		area:SetText(under ~= name and under or "")
		zone:SetTextColor(ZoneTextString:GetTextColor())
		area:SetTextColor(ZoneTextString:GetTextColor())
	end
	f:SetScript("OnShow", Read)
	Read()
	return f
end

-- A frame of the game's stands on a box of ours: hung by `point` from the box's top, at the box's size,
-- and put back whenever the game anchors it. `with`: frames that only take the size.
local function Seat(frame, box, point, y, with)
	local seating = false
	local function Sit()
		if seating then return end
		seating = true
		local scale = box:GetScale()
		frame:SetScale(scale)
		for _, other in ipairs(with or {}) do other:SetScale(scale) end
		frame:ClearAllPoints()
		frame:SetPoint(point, box, "TOP", 0, y)
		seating = false
	end
	local sit = Shy.Clocked("top: a game frame in the column moved", Sit)
	hooksecurefunc(frame, "SetPoint", sit)
	hooksecurefunc(box, "SetScale", sit)
	Sit()
end

-- The game's pieces, and a look another addon gives one of them (ShySkin draws the zone's name).
local stands = {}   -- id -> { box, own = the game's picture, frames = picture -> frame, size }
local looks = {}    -- id -> { picture, width, height }

-- The box shows the picture of the look worn now, and has its size; so does every drawing of the screen.
local function Dress(id)
	local s = stands[id]
	if not s then return end
	local look = looks[id]
	local picture = look and look.picture or s.own
	s.box.top.sample = picture
	local frame = s.frames[picture]
	if not frame then
		frame = picture(s.box)
		frame:SetPoint("TOPLEFT")
		s.frames[picture] = frame
	end
	for _, each in pairs(s.frames) do each:SetShown(each == frame) end
	HUD.Resize(s.box, look and look.width or s.size.w, look and look.height or s.size.h)
end

-- Top.Look(id, picture, width, height): one of the game's pieces drawn by an addon of ours, whose picture
-- and size stand for it in layout mode and in the screen's drawings; Top.Look(id) gives the game's back.
-- away: the look shows the piece somewhere else of ours (the zone's name in the notices' ribbon): its box
-- leaves the column and the drawings.
function Top.Look(id, picture, width, height, away)
	looks[id] = picture and { picture = picture, width = width, height = height, away = away or nil } or nil
	Dress(id)
	Soon()
end

-- A box seen in layout mode only, with the picture of what stands on it. It takes room in the column while
-- the game's frames on it (`game`) show, and is away while a look of ours shows that piece elsewhere.
local function Stand(id, title, size, order, picture, game)
	local box = HUD.Create({
		id = id, title = title, width = size.w, height = size.h,
		point = { "TOP", "TOP", 0, -EDGE },
		shown = function() return false end,
		away = function() return looks[id] ~= nil and looks[id].away == true end,
		top = { order = order, sample = picture, passing = true, game = game },
	})
	for _, frame in ipairs(game) do Watch(frame) end
	stands[id] = { box = box, own = picture, frames = {}, size = size }
	Dress(id)
	return box
end

local begun = false

local function Begin()
	if begun then return end
	begun = true
	-- The button's own height is the box's; the name's first line begins at the box's top, the lines under
	-- it hang from that one (the area's and the land's owner are anchored to it by the game).
	-- The way back: ours past the head's point, the game's button faded under it. The head is made at this
	-- same login, after this: ours follows the game's button from the moment the head says it is made.
	own = Grave.New(UIParent)
	own:Hide()
	ghostKit = Skin.NewKit()
	ghostKit:HideRegions(GhostFrame)
	if GhostFrameContentsFrame then
		ghostKit:HideRegions(GhostFrameContentsFrame)
		ghostKit:Hide(GhostFrameContentsFrameText)
		ghostKit:Hide(GhostFrameContentsFrameIcon)
	end
	Shy:On("SHY_HEAD", function()
		hooksecurefunc(GhostFrame, "SetPoint", SitGhost)
		GhostFrame:HookScript("OnShow", SitGhost)
		for _, event in ipairs({ "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
			ghostWatch:RegisterEvent(event)
		end
		ghostWatch:SetScript("OnEvent", Ghosted)
		Hang()
	end)
	Seat(ZoneTextFrame, Stand("game.zone", "Zone name", ZONE, 40, ZonePicture, { ZoneTextFrame, SubZoneTextFrame }), "CENTER",
		-ZONE.line / 2, { SubZoneTextFrame })

	local function Mine(box)
		if box and not box.foreign and box.top then Soon() end
	end
	Shy:On("SHY_HUD_MOVED", Mine)
	Shy:On("SHY_HUD_RESIZED", Mine)
	-- The head moved: the column goes with it now, not a frame later (what it leads hung from it for the drag, and
	-- is placed again as it is let go of). Sized, the rest take its size.
	Shy:On("SHY_HUD_MOVED", function(box)
		if box ~= nil and box == column.head then Top.Apply() end
	end)
	Shy:On("SHY_HUD_SCALED", Mine)
	-- Placed again by anything else (a reset, another Edit Mode layout, a setup): a piece may be back in the
	-- column, or out of it.
	hooksecurefunc(HUD, "Apply", Shy.Clocked("top: a box applied", Mine))
	hooksecurefunc(HUD, "SetHome", Shy.Clocked("top: a box given a home", Given))
	hooksecurefunc(HUD, "Create", Soon)   -- boxes made after login
	-- The game lays its top-centre widgets out again whenever one shows, hides or changes.
	-- (The game lays its widgets out every frame one of them changes: only where the column starts matters.)
	local started
	hooksecurefunc(UIWidgetTopCenterContainerFrame, "UpdateWidgetLayout", Shy.Clocked("top: the game's widgets laid out", function()
		local start = Start()
		if start == started then return end
		started = start
		Top.Apply()
	end))
	local events = CreateFrame("Frame")
	events:RegisterEvent("DISPLAY_SIZE_CHANGED")
	events:RegisterEvent("UI_SCALE_CHANGED")
	events:SetScript("OnEvent", Soon)
	Top.Apply()
	Soon()   -- and once every addon's login has made its boxes
end

Shy:On("SHY_LOGIN", Begin)
