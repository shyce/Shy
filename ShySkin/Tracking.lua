-- Tracking on the square minimap: a lens on the map holding what you are finding, and a tray under the
-- strip to choose what you find and what the map shows.
--
-- The lens is a glass in the dial's ring in the map's top left corner. While you are finding something
-- it stays up; so too after dying stopped it (gold: one click finds it again). Holding nothing it is the
-- map's furniture, up with the zoom and the dial while the mouse is on the map. A click opens the tray,
-- a right click stops or finds the last again. The wheel over it zooms the map, as anywhere on the map.
-- Finding more than one thing, the others stand behind the lens as glasses of its own make, each out past
-- the one before as a hand of cards is held: close at rest, dealt wide under the mouse, where the hover
-- names them all. They are made the first time a second find is on and move only while they are dealt, so
-- one find costs what it did.
-- The tray is the column's make (Shy.Top.Make): the lens and what it says, a cell for each thing you
-- can find, two abreast, then a strip of squares for what the map shows, named by the heading over it.
-- A spell's row is a cast, so what was asked for shows at once and for ASKED seconds, then what the game
-- says (MINIMAP_UPDATE_TRACKING).
-- The game's own tracking button is faded and deaf meanwhile and its mail flag stands in the strip, so the
-- map's corner is the lens's alone (Minimap.lua, Place); nothing of the game's is touched here.
-- A picture of the game's is set once, plainly, as every slot sets its own: set again with another filter
-- while the game was still reading it, a spell's picture took the client down. Our own art is drawn for the
-- size it is shown at.

local ADDON, ns = ...
local UI, Theme = Shy.UI, Shy.Theme
local C, P = Shy.Skin.colors, UI.colors
local Make = Shy.Top.Make
local CELL = Make.CELL

local L = {}
ns.Lens = L

local K = {
	ON_MAP = 3,                    -- in from the map's corner, as the zoom and the dial
	LEVEL = 10,                    -- over the map, as the zoom
	GLASS = 18,                    -- the picture under the glass (the small dial's)
	CROP = 0.08,                   -- a spell picture's own frame, cut off
	GLYPH = 12, REST = 0.62,       -- the lens with nothing in it, and how quiet it is at rest
	LOST = 0.55,                   -- how dark the picture of what stopped is
	GLOW = 2.1, GLOW_OVER = 0.34, GLOW_LOST = 0.6,
	ASKED = 1.5,                   -- seconds a pick shows before the game has said so
	GLEAM = 0.7, GLEAM_REACH = 150, GLEAM_WIDE = 2,
	WORDS = 6,                     -- the tray's words, past the lens
	CAPTION = 9, TITLE = 15, APART = 6.5,
	PICTURE = 16,                  -- a square's picture, in the strip of what the map shows
	WASH = 0.5, BAND = 2, OFF = 0.5,
	NAME = 11,                     -- a find's name, two cells abreast
	ABOVE = 20,                    -- the lens's frame level over its tray
	DECK = 3,                      -- the glasses that can stand behind the lens (the hover names any past them)
	OVER = 8,                      -- the lens's frame level over the map's: two under it for each glass behind
	PEEK = 9, FAN = 20,            -- how far each stands out past the one before: at rest, and under the mouse
	DEAL = 0.16,                   -- seconds a glass takes to its place
	CAST = 80, SHADE = 0.75, FACE = 25,   -- the shadow the one before casts on a glass, and the face it falls on
	SAYS = 20,                     -- the letters two names may take in the tray's title
	ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
	-- The game's words for its finding spells, said once by the tray's heading. Other tongues keep the whole name.
	LEADS = { "^Find (.+)", "^Track (.+)", "^Sense (.+)" },
}

local stage, lens, tray, gleam
local standing = false   -- the lens is in use: the skin on, the map square, the game allowing tracking
local finds, shows = {}, {}
local want = {}          -- index -> { on, at }: what was just asked for, shown until the game says
local last               -- the spell found last: what a right click finds again
local dropped            -- the spell that was on when you died
local furnish = 1        -- how far the map's furniture shows
local over = false       -- the mouse is on the lens
local found = {}         -- the finds that are on: the one the lens holds, then the rest as the game lists them
-- The glasses behind the lens: `cards` as they were made (nearest first), `live` while any is out, `reach` how far
-- the furthest stands out now, `peek` and `fan` a step in whole pixels, `hit` how far the lens's mouse reaches.
local deck = { cards = {}, live = false, reach = 0, peek = K.PEEK, fan = K.FAN, hit = 0, t = 0 }
local Look, Fill, Tip

-- What the game tracks

local function Plain(value)
	if issecretvalue(value) then return nil end
	return value
end

local function Short(name)
	for _, lead in ipairs(K.LEADS) do
		local rest = name:match(lead)
		if rest then return rest end
	end
	return name
end

local function Alive()
	local dead = UnitIsDeadOrGhost("player")
	if issecretvalue(dead) then return false end
	return not dead
end

-- The game's list, as two: what you can find (spells) and what the map shows (the filters its own menu offers).
local function Read()
	local now, was = GetTime(), {}
	for _, row in ipairs(finds) do was[row.spell] = row.real end
	wipe(finds)
	wipe(shows)
	local lastOn = false
	for index = 1, C_Minimap.GetNumTrackingTypes() do
		local filter, info = C_Minimap.GetTrackingFilter(index), C_Minimap.GetTrackingInfo(index)
		if filter and info then
			local name = Plain(info.name)
			local real = Plain(info.active) == true
			local asked = want[index]
			if asked and now - asked.at >= K.ASKED then
				want[index] = nil
				asked = nil
			end
			local on = real
			if asked then on = asked.on end
			local row = { index = index, name = name or "", texture = info.texture, on = on, real = real }
			if filter.spellID then
				row.spell = filter.spellID
				if name then row.name = Short(name) end
				finds[#finds + 1] = row
				if on and row.spell == last then lastOn = true end
				-- Stopped by the game while you are dead, not by you: what the lens offers to find again.
				if not real and was[row.spell] and not asked and not Alive() then dropped = row.spell end
			elseif MinimapConstants.OPTIONAL_FILTERS[filter.filterID] then
				shows[#shows + 1] = row
			end
		end
	end
	if not lastOn then
		for _, row in ipairs(finds) do
			if row.on then
				last = row.spell
				break
			end
		end
	end
end

local function Row(spell)
	for _, row in ipairs(finds) do
		if row.spell == spell then return row end
	end
end

-- The find the lens holds: the one picked last of those that are on.
local function Held()
	local first
	for _, row in ipairs(finds) do
		if row.on then
			if row.spell == last then return row end
			first = first or row
		end
	end
	return first
end

-- Every find that is on, the one the lens holds first (one list, filled again: nothing is made).
local function On()
	wipe(found)
	local front = Held()
	if not front then return found end
	found[1] = front
	for _, row in ipairs(finds) do
		if row.on and row ~= front then found[#found + 1] = row end
	end
	return found
end

-- What is found, in a few words: the tray's title.
local function Says()
	local count = #found
	if count == 0 then return nil end
	local first = found[1].name
	if count == 1 then return first end
	if count == 2 then
		local both = first .. " and " .. found[2].name
		if #both <= K.SAYS then return both end
	end
	return first .. " and " .. (count - 1) .. " more"
end

local function Lost()
	if not dropped or not Alive() then return nil end
	return Row(dropped)
end

local function Ask(row, on)
	if row.on == on then return end
	C_Minimap.SetTracking(row.index, on)
	want[row.index] = { on = on, at = GetTime() }
	row.on = on
end

-- A light runs the map's edge from the lens, once: what you find changed.
local function Gleam()
	if not gleam then return end
	local r, g, b = Theme.light[1], Theme.light[2], Theme.light[3]
	gleam.top:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
	gleam.side:SetGradient("VERTICAL", CreateColor(r, g, b, 1), CreateColor(r, g, b, 0))
	gleam.at = 0
	gleam:Show()
end

local function Settle()
	C_Timer.After(K.ASKED + 0.05, function()
		if not standing then return end
		Read()
		Look()
		if over then Tip() end
	end)
end

local function Changed()
	dropped = nil
	Gleam()
	Look()
	Settle()
end

-- One find on or off, as a click on its cell.
local function Turn(row, on)
	Ask(row, on)
	if on then last = row.spell end
	Changed()
end

-- Nothing found any more, as the right click.
local function Stop()
	for _, each in ipairs(finds) do Ask(each, false) end
	Changed()
end

-- The tray

local function Close()
	if tray then tray:Hide() end
end

local function Border()
	local look = tray.shyLook
	return look and math.max(UI.LookBorder(look)) or 0
end

local function Words(parent, font, side)
	return UI.Words(parent, font, nil, { wrap = false, justify = side })
end

local function Hair(parent)
	local t = parent:CreateTexture(nil, "ARTWORK", nil, 3)
	t:SetColorTexture(1, 1, 1, 1)
	UI.Tint(t, C.metal, CELL.LINE)
	return t
end

-- A cell of something you can find: the tray's own row, lit while it is on (its body filled, its slot in the
-- accent's light). Two stand abreast, so its name is set a size down and has the cell to its end.
local function FindCell(parent)
	local cell = Make.Cell(parent, "Button")
	cell.name:SetFontObject(UI.TitleFont(K.NAME))
	UI.Follow(cell.name)
	cell:SetScript("OnEnter", function(self) self:Hot(true) end)
	cell:SetScript("OnLeave", function(self) self:Hot(false) end)
	cell:SetScript("OnClick", function(self)
		if self.row then Turn(self.row, not self.row.on) end
	end)
	return cell
end

-- Two cells abreast: a row of the tray.
local function FindRow()
	local row = CreateFrame("Frame", nil, tray)
	row:SetHeight(CELL.ROW)
	row.tall = CELL.ROW
	row.cells = { FindCell(row), FindCell(row) }
	row.cells[1]:SetPoint("TOPLEFT")
	row.cells[2]:SetPoint("TOPLEFT", row, "TOP")
	row.split = Hair(row.cells[2].over)
	row.split:SetWidth(CELL.RULE)
	row.split:SetPoint("TOPLEFT")
	row.split:SetPoint("BOTTOMLEFT")
	function row:Rule(on)
		for _, cell in ipairs(self.cells) do cell:Rule(on) end
	end
	return row
end

local function Square()
	local b = CreateFrame("Button", nil, tray.strip)
	b:SetHeight(CELL.ROW)
	b.wash = b:CreateTexture(nil, "BACKGROUND")
	b.wash:SetAllPoints()
	b.wash:SetColorTexture(1, 1, 1, 1)
	UI.Tint(b.wash, P.fill, K.WASH)
	b.band = b:CreateTexture(nil, "ARTWORK", nil, 2)
	b.band:SetColorTexture(1, 1, 1, 1)
	b.band:SetHeight(K.BAND)
	b.band:SetPoint("TOPLEFT")
	b.band:SetPoint("TOPRIGHT")
	UI.Tint(b.band, Theme.light)
	b.picture = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.picture:SetSize(K.PICTURE, K.PICTURE)
	b.picture:SetPoint("CENTER", 0, -K.BAND / 2)
	b.hot = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	b.hot:SetAllPoints()
	b.hot:SetColorTexture(1, 1, 1, CELL.HOT)
	b.hot:Hide()
	b.split = Hair(b)
	b.split:SetWidth(CELL.RULE)
	b.split:SetPoint("TOPLEFT")
	b.split:SetPoint("BOTTOMLEFT")
	b:SetScript("OnEnter", function(self)
		self.hot:Show()
		tray.over = self.row
		Fill()
	end)
	b:SetScript("OnLeave", function(self)
		self.hot:Hide()
		if tray.over == self.row then tray.over = nil end
		Fill()
	end)
	b:SetScript("OnClick", function(self)
		local row = self.row
		if not row then return end
		Ask(row, not row.on)
		Fill()
		Settle()
	end)
	return b
end

local function Build()
	tray = CreateFrame("Frame", "ShySkinTracking", stage)
	tray:SetFrameStrata("DIALOG")
	tray:SetPoint("TOPLEFT")
	tray:EnableMouse(true)   -- a click on it is not a click on the map under it
	tray:Hide()
	-- The lens and what it says.
	local head = CreateFrame("Frame", nil, tray)
	head.caption = Words(head, UI.NameFont(K.CAPTION), "LEFT")
	head.title = Words(head, UI.TitleFont(K.TITLE), "LEFT")
	UI.Follow(head.title)
	UI.Ink(head.caption, P.dim)
	function head:Rule() end
	tray.head = head
	tray.rows = {}
	tray.heading = Make.Heading(tray)
	local strip = CreateFrame("Frame", nil, tray)
	strip:SetHeight(CELL.ROW)
	strip.tall = CELL.ROW
	strip.rule = Hair(strip)
	strip.rule:SetHeight(CELL.RULE)
	strip.rule:SetPoint("TOPLEFT")
	strip.rule:SetPoint("TOPRIGHT")
	function strip:Rule(on) self.rule:SetShown(on) end
	strip.squares = {}
	tray.strip = strip
	-- Escape closes it, and so does a click anywhere but on it or the lens.
	table.insert(UISpecialFrames, "ShySkinTracking")
	tray:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
	tray:SetScript("OnHide", function(self)
		self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
		self.over = nil
		L.Raise(stage:GetFrameStrata(), stage:GetFrameLevel() + K.OVER)
		if ns.FurnishMap then ns.FurnishMap() end
		Look()
	end)
	tray:SetScript("OnEvent", function(self)
		local on = self:IsMouseOver()
		local onLens = lens:IsMouseOver()
		if issecretvalue(on) or issecretvalue(onLens) then return end
		if not on and not onLens then Close() end
	end)
end

-- The tray's rows for what there is now, stood as a tray by itself across the map's top.
local function Lay()
	local rows = { tray.head }
	local needed = math.ceil(#finds / 2)
	for i = 1, math.max(needed, #tray.rows) do
		local row = tray.rows[i]
		if i <= needed then
			if not row then
				row = FindRow()
				tray.rows[i] = row
			end
			row:Show()
			rows[#rows + 1] = row
		elseif row then
			row:Hide()
		end
	end
	rows[#rows + 1] = tray.heading
	rows[#rows + 1] = tray.strip
	local squares = tray.strip.squares
	for i = 1, math.max(#shows, #squares) do
		if i <= #shows and not squares[i] then squares[i] = Square() end
		squares[i]:SetShown(i <= #shows)
	end
	-- The first row is as tall as the lens with its room, less the tray's border over it.
	Make.House(tray)
	local edge = Border()
	local head = tray.head
	local inset = lens.inset or K.ON_MAP
	head.tall = inset * 2 + Make.FACE - edge
	head:SetHeight(head.tall)
	head.x, head.mid, head.at = inset + Make.FACE + K.WORDS - edge, inset + Make.FACE / 2 - edge, nil
	L.Lead()
	local wide = Minimap:GetWidth() * Minimap:GetEffectiveScale() / tray:GetEffectiveScale()   -- the map's, in the tray's units
	Make.Still(tray, wide, rows)
	local half = (wide - 2 * edge) / 2
	for i = 1, needed do
		for _, cell in ipairs(tray.rows[i].cells) do cell:SetWidth(half) end
	end
	local each = (wide - 2 * edge) / math.max(1, #shows)
	for i = 1, #shows do
		local b = squares[i]
		b:SetWidth(each)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", tray.strip, "TOPLEFT", (i - 1) * each, 0)
		b.split:SetShown(i > 1)
	end
end

-- What the tray says of what is on now.
function Fill()
	local head, held = tray.head, On()[1]
	head.caption:SetText(#finds > 0 and "FINDING" or "TRACKING")
	head.title:SetText(Says() or (#finds > 0 and "Nothing" or "Nothing to find"))
	UI.Ink(head.title, held and C.text or P.dim)
	for i, row in ipairs(finds) do
		local cell = tray.rows[math.ceil(i / 2)].cells[(i - 1) % 2 + 1]
		cell.row = row
		cell:Show()
		-- Said again only when it changed: the tray is filled at every move of the mouse on it, and a cell
		-- sets its picture each time it is said.
		local says = tostring(row.texture) .. ":" .. row.name .. (row.on and "+" or "-")
		if cell.says ~= says then
			cell.says = says
			cell:Set({ icon = row.texture, name = row.name, nameColor = row.on and C.text or P.dim,
				mark = row.on and Theme.light or nil, fill = row.on and P.fill or nil })
			cell:Share(1)
			cell:Pulse(0)   -- its light along the top is for a change: none at rest
			cell.name:ClearAllPoints()
			cell.name:SetPoint("LEFT", cell, "LEFT", CELL.TAB + CELL.PAD, 0)
			cell.name:SetPoint("RIGHT", cell, "RIGHT", -CELL.PAD, 0)
			cell.icon:SetDesaturated(not row.on)
		end
	end
	if #finds % 2 == 1 then
		local spare = tray.rows[math.ceil(#finds / 2)].cells[2]
		spare.row = nil
		spare:Hide()
	end
	local on = 0
	for i, row in ipairs(shows) do
		local b = tray.strip.squares[i]
		b.row = row
		if b.shows ~= row.texture then   -- only when it changed: a picture is never set over itself
			b.shows = row.texture
			b.picture:SetTexture(row.texture)
		end
		b.picture:SetDesaturated(not row.on)
		b.picture:SetAlpha(row.on and 1 or K.OFF)
		b.wash:SetShown(row.on)
		b.band:SetShown(row.on)
		if row.on then on = on + 1 end
	end
	local said = tray.over
	tray.heading:Set({ file = Shy.Skin.GLYPH.lens, color = said and C.text or P.dim,
		title = said and said.name or ("On the map \194\183 " .. on .. " of " .. #shows) })
end

local function Open()
	if not tray then Build() end
	UI.TipHide(lens, true)
	Read()
	Lay()
	Fill()
	L.Raise("DIALOG", tray:GetFrameLevel() + K.ABOVE)
	tray:Show()
	if ns.FurnishMap then ns.FurnishMap() end   -- the dial stands where the tray lies: down while it is open
	Look()
end

-- The glasses behind the lens

-- A glass: the dial's small ring, a picture cut round under it, the look's ring over both. The lens is one, and
-- so is each find that stands behind it.
local function Glass(frame)
	frame:SetSize(Make.FACE, Make.FACE)
	frame.ring = frame:CreateTexture(nil, "ARTWORK", nil, 1)
	frame.ring:SetTexture(Shy.MEDIA .. "DialSmall")
	frame.ring:SetSize(Make.FACE, Make.FACE)
	frame.ring:SetPoint("CENTER")
	frame.picture = frame:CreateTexture(nil, "ARTWORK", nil, 2)
	frame.picture:SetSize(K.GLASS, K.GLASS)
	frame.picture:SetPoint("CENTER")
	frame.picture:SetTexCoord(K.CROP, 1 - K.CROP, K.CROP, 1 - K.CROP)
	frame.round = frame:CreateMaskTexture()
	frame.round:SetTexture(K.ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	frame.round:SetAllPoints(frame.picture)
	frame.picture:AddMaskTexture(frame.round)
	UI.Concentric(frame.ring, frame.picture)
	-- The look's ring stands over the picture.
	frame.above = CreateFrame("Frame", nil, frame)
	frame.above:SetAllPoints()
	frame.above:EnableMouse(false)
	frame.ring.look = UI.LookRing(frame.ring, Make.RING, frame.above)
end

-- A glass under the lens and under those nearer than it: two levels each, itself and its look's ring.
local function Under(card, i)
	local level = lens:GetFrameLevel() - 2 * i
	card:SetFrameStrata(lens:GetFrameStrata())
	card:SetFrameLevel(level)
	card.above:SetFrameLevel(level + 1)
end

-- The lens at a level (on the map, or over its tray), the glasses behind it kept under it.
function L.Raise(strata, level)
	lens:SetFrameStrata(strata)
	lens:SetFrameLevel(level)
	for i, card in ipairs(deck.cards) do Under(card, i) end
end

-- The i-th glass behind the lens. The one before it (the lens, for the first) casts its shadow on it: dark at
-- that one's rim, gone across the face, and cut to the face so none falls on the map.
local function Card(i)
	local card = CreateFrame("Frame", nil, lens)
	card:EnableMouse(false)
	Glass(card)
	UI.Tint(card.ring, C.metal)
	card.shade = card.above:CreateTexture(nil, "OVERLAY")
	card.shade:SetTexture(Shy.Brand.GLOW)
	card.shade:SetSize(K.CAST, K.CAST)
	card.shade:SetPoint("CENTER", deck.cards[i - 1] or lens, "CENTER")
	card.shade:SetVertexColor(0, 0, 0, K.SHADE)
	card.face = card.above:CreateMaskTexture()
	card.face:SetTexture(K.ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	card.face:SetSize(K.FACE, K.FACE)
	card.face:SetPoint("CENTER")
	card.shade:AddMaskTexture(card.face)
	UI.Concentric(card.shade)
	card.at, card.from, card.to, card.gone = 0, 0, 0, false
	card:Hide()
	deck.cards[i] = card
	Under(card, i)
	return card
end

-- The tray's words stand past the lens and whatever stands out behind it.
function L.Lead()
	local head = tray and tray.head
	if not head or not head.x then return end
	local x = head.x + deck.reach
	if head.at == x then return end
	head.at = x
	head.caption:ClearAllPoints()
	head.caption:SetPoint("LEFT", head, "TOPLEFT", x, -(head.mid - K.APART))
	head.title:ClearAllPoints()
	head.title:SetPoint("LEFT", head, "TOPLEFT", x, -(head.mid + K.APART - 1))
end

-- The glasses where they are `share` of the way to their places (1: there, and those that left put away).
local function Deal(share)
	local reach, live = 0, false
	for _, card in ipairs(deck.cards) do
		if card:IsShown() then
			if share >= 1 and card.gone then
				card:Hide()
			else
				card.at = share >= 1 and card.to or card.from + (card.to - card.from) * share
				card:SetPoint("CENTER", lens, "CENTER", card.at, 0)
				live = true
				if card.at > reach then reach = card.at end
			end
		end
	end
	deck.live, deck.reach = live, reach
	if tray and tray:IsShown() then L.Lead() end
end

-- Runs only while a glass is on its way (the frame is hidden otherwise).
local function Dealing(self, elapsed)
	deck.t = deck.t + elapsed
	local u = deck.t / K.DEAL
	if u >= 1 then
		self:Hide()
		Deal(1)
	else
		Deal(1 - (1 - u) * (1 - u))
	end
end

-- Where the glasses stand for what is on: each out past the one before by a step, a wide one under the mouse
-- (the tray shut), so each picture shows; one that came is dealt from under the one before it, one that left
-- goes back under the lens. The mouse reaches the lens over them. `now`: there at once.
function L.Spread(now)
	local count = math.min(math.max(#found - 1, 0), K.DECK)
	if count == 0 and not deck.live then return end   -- one find or none, and nothing out: no more than this
	local step = (over and not (tray and tray:IsShown())) and deck.fan or deck.peek
	local moves = false
	for i = 1, math.max(count, #deck.cards) do
		local card = deck.cards[i]
		if i <= count then
			card = card or Card(i)
			local row = found[i + 1]
			if card.shows ~= row.texture then   -- only when it changed: a picture is never set over itself
				card.shows = row.texture
				card.picture:SetTexture(row.texture)
			end
			if not card:IsShown() then
				local before = deck.cards[i - 1]
				card.at = before and before.at or 0
				card:Show()
			end
			card.gone, card.to = false, i * step
		elseif card:IsShown() then
			card.gone, card.to = true, 0
		end
		if card:IsShown() then
			card.from = card.at
			if card.gone or card.at ~= card.to then moves = true end
		end
	end
	local hit = count * step
	if deck.hit ~= hit then
		deck.hit = hit
		lens:SetHitRectInsets(0, -hit, 0, 0)
	end
	if not moves then return end
	if now then
		deck.run:Hide()
		Deal(1)
	else
		deck.t = 0
		deck.live = true
		deck.run:Show()
	end
end

-- The lens

function Tip()
	if tray and tray:IsShown() then return end
	local held, lost = On()[1], nil
	if not held then lost = Lost() end
	if lost then
		UI.Tip(lens, lost.name, "This stopped when you died.", { side = "LEFT", note = "Stopped",
			hints = { { "left", "Find again" }, { "right", "Leave it" } } })
	elseif #found > 1 then
		-- Each by its picture and name, in the order they stand: the lens's first.
		local rows = {}
		for i, row in ipairs(found) do rows[i] = { icon = row.texture, text = row.name, wrap = false } end
		UI.Tip(lens, "Finding " .. #found .. " things", nil, { side = "LEFT", sections = { { rows = rows } },
			hints = { { "left", "Choose" }, { "right", "Stop all" } } })
	elseif held then
		UI.Tip(lens, "Finding " .. held.name, nil, { side = "LEFT", hints = { { "left", "Choose" }, { "right", "Stop" } } })
	elseif #finds > 0 then
		local again = last and Row(last)
		UI.Tip(lens, "Tracking", "You aren't finding anything.", { side = "LEFT",
			hints = { { "left", "Choose" }, again and { "right", "Find " .. again.name } or nil } })
	else
		UI.Tip(lens, "Tracking", "Choose what your map shows.", { side = "LEFT", hints = { { "left", "Choose" } } })
	end
end

function Look()
	if not lens then return end
	local held, lost = On()[1], nil
	if not held then lost = Lost() end
	local row = held or lost
	local open = tray ~= nil and tray:IsShown()
	lens.stays = row ~= nil
	lens.picture:SetShown(row ~= nil)
	lens.glyph:SetShown(row == nil)
	if row then
		local shade = lost and K.LOST or 1
		if lens.shows ~= row.texture then   -- only when it changed: a picture is never set over itself
			lens.shows = row.texture
			lens.picture:SetTexture(row.texture)
		end
		lens.picture:SetDesaturated(lost ~= nil)
		lens.picture:SetVertexColor(shade, shade, shade)
	else
		UI.Tint(lens.glyph, over and C.lit or C.glyph, over and 1 or K.REST)
	end
	UI.Tint(lens.ring, lost and P.alert or ((over or open) and C.lit or (row and C.metal or C.idle)))
	lens.ring.look:Plain(lost == nil)
	lens.glow:SetShown(lost ~= nil or over)
	if lost then
		UI.Tint(lens.glow, P.alert, K.GLOW_LOST)
	elseif over then
		UI.Tint(lens.glow, Theme.light, K.GLOW_OVER)
	end
	lens:SetAlpha((lens.stays or open) and 1 or furnish)
	L.Spread()
	if open then Fill() end
end

local function Click(_, button)
	local held, lost = Held(), nil
	if not held then lost = Lost() end
	if button == "RightButton" then
		if held then
			last = held.spell
			Stop()
		elseif lost then
			dropped = nil
			Look()
		elseif last and Row(last) then
			Turn(Row(last), true)
		end
	elseif lost then
		Turn(lost, true)
	elseif tray and tray:IsShown() then
		Close()
	else
		Open()
	end
	if over then Tip() end
end

local function MakeLens()
	stage = CreateFrame("Frame", nil, Minimap)
	stage:SetAllPoints(Minimap)
	stage:SetFrameLevel(Minimap:GetFrameLevel() + K.LEVEL)
	stage:EnableMouse(false)

	lens = CreateFrame("Button", nil, stage)
	Glass(lens)
	lens:SetFrameLevel(stage:GetFrameLevel() + K.OVER)
	lens:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	lens.glow = lens:CreateTexture(nil, "BACKGROUND")
	lens.glow:SetTexture(Shy.Brand.GLOW)
	lens.glow:SetSize(Make.FACE * K.GLOW, Make.FACE * K.GLOW)
	lens.glow:SetPoint("CENTER")
	lens.glow:SetBlendMode("ADD")
	lens.glow:Hide()
	lens.glyph = lens:CreateTexture(nil, "ARTWORK", nil, 2)
	lens.glyph:SetTexture(Shy.Skin.GLYPH.lens)
	lens.glyph:SetSize(K.GLYPH, K.GLYPH)
	lens.glyph:SetPoint("CENTER")
	UI.Concentric(lens.glow, lens.glyph)
	-- (It takes no wheel: over the lens, as anywhere on the map, the wheel zooms.)
	lens:SetScript("OnClick", Click)
	lens:SetScript("OnEnter", function()
		over = true
		if ns.WakeMap then ns.WakeMap() end
		Look()
		Tip()
	end)
	lens:SetScript("OnLeave", function(self)
		over = false
		UI.TipHide(self)
		Look()
	end)

	gleam = CreateFrame("Frame", nil, stage)
	gleam:SetAllPoints()
	gleam:EnableMouse(false)
	gleam:Hide()
	gleam.top = gleam:CreateTexture(nil, "OVERLAY")
	gleam.top:SetColorTexture(1, 1, 1, 1)
	gleam.top:SetHeight(K.GLEAM_WIDE)
	gleam.top:SetPoint("TOPLEFT")
	gleam.side = gleam:CreateTexture(nil, "OVERLAY")
	gleam.side:SetColorTexture(1, 1, 1, 1)
	gleam.side:SetWidth(K.GLEAM_WIDE)
	gleam.side:SetPoint("TOPLEFT")
	gleam:SetScript("OnUpdate", function(self, elapsed)
		self.at = self.at + elapsed
		local u = self.at / K.GLEAM
		if u >= 1 then
			self:Hide()
			return
		end
		local reach = math.max(1, K.GLEAM_REACH * (1 - (1 - u) * (1 - u)))
		self.top:SetWidth(reach)
		self.side:SetHeight(reach)
		self:SetAlpha(1 - u)   -- the frame's: each line's own strength is its gradient's
	end)

	deck.run = CreateFrame("Frame", nil, lens)
	deck.run:Hide()
	deck.run:SetScript("OnUpdate", Dealing)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "MINIMAP_UPDATE_TRACKING", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "PLAYER_ALIVE",
		"PLAYER_UNGHOST" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		if not standing then return end
		if event == "PLAYER_DEAD" then
			local held = Held()
			if held then dropped = held.spell end
		end
		Read()
		-- Back alive with it still on: the game kept it, and nothing was lost.
		if dropped and Alive() and Held() then dropped = nil end
		Look()
		if over then Tip() end
	end)
end

-- For Minimap.lua

-- The lens comes into use or goes out of it (the skin on a square map, where the game allows tracking).
function L.Stand(on)
	on = on and not C_GameRules.IsGameRuleActive(Enum.GameRule.IngameTrackingDisabled)
	standing = on
	if Shy.SetMinimapTracking then Shy.SetMinimapTracking(on) end
	if on then
		if not stage then MakeLens() end
		L.Seat()
		stage:Show()
		Read()
		Look()
	elseif stage then
		Close()
		stage:Hide()
	end
end

function L.Stands()
	return standing
end

-- The tray is open: what stands on the map's top where it lies (the dial) stands down.
function L.Open()
	return tray ~= nil and tray:IsShown()
end

-- At the screen's scale whatever Edit Mode's minimap size, as the zoom: its art keeps its density. In from the
-- corner by whole screen pixels, so the ring's edge is not drawn between two.
function L.Seat()
	if not stage then return end
	stage:SetScale(1 / MinimapCluster.MinimapContainer:GetScale())
	lens.inset = UI.BoxPixels(lens, K.ON_MAP)
	lens:ClearAllPoints()
	lens:SetPoint("TOPLEFT", lens.inset, -lens.inset)
	-- A glass's step in whole pixels too: each ring is drawn as the lens's is.
	deck.peek, deck.fan = UI.BoxPixels(lens, K.PEEK), UI.BoxPixels(lens, K.FAN)
	if deck.live then L.Spread(true) end
end

-- How far the map's furniture shows: the lens goes with it while it holds nothing.
function L.Furnish(alpha)
	furnish = alpha
	if lens and standing and not lens.stays and not (tray and tray:IsShown()) then lens:SetAlpha(alpha) end
end

-- For tests and reports.
function L.State()
	local held, lost = Held(), nil
	if not held then lost = Lost() end
	return { finds = finds, shows = shows, held = held, lost = lost, lens = lens, tray = tray, stage = stage, gleam = gleam,
		found = On(), deck = deck }
end
