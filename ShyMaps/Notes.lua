-- Notes and drawings on the map, kept on the account (T.db.notes, T.db.drawings).
--
-- A note is a place with a few words, in one of the theme's inks (Shy.Theme.NOTE): the family's mark with the
-- note sign where it is, on every map that shows that ground, its words under it. Its hover says the words,
-- where it is and how far; a click leads you there (the way ShyQuest leads, else the game's pin and arrow); a
-- right click edits its words or ink, shares it, or takes it away. The bar's notes button puts one down with
-- your next click on the map or where you stand, lists every note (a click shows it), and takes up the pen.
--
-- The pen draws on the map in a note's ink, with a tool: the pen's own line where the mouse goes, a straight line,
-- an arrow, a ring, a raid mark, or the eraser; the right button pans the map, the wheel zooms; the bar's button
-- (lit while the pen is up), or the "Done drawing" plate over the map, puts it down. A stroke is kept in the world's
-- yards, so it stands on every map of that ground; the last can be taken back, or every stroke on the map shown.
-- Drawn for a note (its menu), it goes when the note does. Notes travel as codes to paste anywhere (Notes.Code,
-- Notes.FromCode); a pin your group shares is kept as one when that is asked for.
--
--   Notes.Add(world, north, west, map, x, y) -> note    a note there, its words to write at once
--   Notes.All() -> notes                               { id, world, north, west, map, x, y, text, ink, at }
--   Notes.Remove(note)
--   Notes.Pen(on)                                      take up the pen (true), put it down (false); Notes.Pen() -> up

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local Maps = Shy.Maps
local Theme = Shy.Theme

local Notes = {}
ns.Notes = Notes

local K = {
	SIZE = 20,              -- a note's mark, units on screen
	WORDS = 28,             -- letters of a note's words shown under it (the hover has them all)
	STEP = 3,               -- port units the mouse moves before the stroke takes another point
	THICK = 2.6,            -- a stroke's width, pixels
	ALPHA = 0.95,
	BEND = 0.6,             -- art pixels a drawn stroke may stray from the points taken (thinned as it is kept)
	MOST = 400,             -- points a stroke keeps at the most
}

local pins, used = {}, 0
local pen                   -- the pen: { ink, stroke (being drawn), sheet, lay (Maps pen), done (the plate) }
local barButton

local function All()
	T.db.notes = T.db.notes or {}
	return T.db.notes
end
Notes.All = All

local function Strokes()
	T.db.drawings = T.db.drawings or {}
	return T.db.drawings
end

-- Where a place of the world lies on the map shown, as shares; nil off it.
local function Shown(world, north, west, map, x, y)
	local shown = View.Map()
	if not shown then return nil end
	if map == shown and x then return x, y end
	local sx, sy = ns.OnMap(shown, world, north, west)
	if sx and sx >= 0 and sx <= 1 and sy >= 0 and sy <= 1 then return sx, sy end
	return nil
end

local function Where(note)
	local info = note.map and C_Map.GetMapInfo(note.map)
	return info and info.name or nil
end

local function Words(note)
	local text = note.text or ""
	if text == "" then return "Note" end
	return text
end

local function Short(text)
	if #text <= K.WORDS then return text end
	return text:sub(1, K.WORDS - 1):gsub("%s+%S*$", "") .. "..."
end

-- A note as a place to lead to or share.
local function Place(note)
	return { map = note.map, x = note.x, y = note.y, title = Words(note), say = Words(note) .. ":" }
end

local Draw   -- below

-- Writing a note's words: a field beside its pin, what is there now selected. A note just put down that is let go
-- with nothing written goes again.
local function Write(note, owner, fresh)
	UI.WriteField(owner, note.text or "", function(text)
		if text == nil then
			if fresh then Notes.Remove(note) end
			return
		end
		note.text = text
		Draw()
	end, { hint = "Enter to keep" })
end

local function Lead(note)
	local share = Shy.Way.Share
	if not Shy.Way.missing and share and share.Lead then
		share.Lead(Place(note))
		return
	end
	if not C_Map.CanSetUserWaypointOnMap(note.map) then
		UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA())
		return
	end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
	Shy.Waypoint.Set(note.map, note.x, note.y, true)
end

local function Tip(pin)
	local note = pin.note
	if not note then return end
	local rows = {}
	local where = Where(note)
	if where then rows[#rows + 1] = { glyph = "go", text = where } end
	local share = Shy.Way.Share
	local seconds, yards
	if not Shy.Way.missing and share and share.Away then seconds, yards = share.Away(Place(note)) end
	if seconds then
		rows[#rows + 1] = { glyph = "clock", text = seconds < 60 and "Under a minute away" or ("%d min away"):format(math.floor(seconds / 60 + 0.5)) }
	elseif yards then
		rows[#rows + 1] = { glyph = "clock", text = ("%d yd away"):format(math.floor(yards + 0.5)) }
	end
	local color = Theme.Note(note.ink)
	Shy.Hover.Show(pin, { title = Words(note), titleColor = color, sections = #rows > 0 and { { rows = rows } } or nil,
		hints = { { "left", "Lead me there" }, { "right", "Edit or remove" } } })
end

local function Menu(pin)
	local note = pin.note
	UI.ContextMenu(pin, function(root)
		root:CreateTitle(Short(Words(note)))
		root:CreateButton("Edit note", function() Write(note, pin) end)
		local inks = root:CreateButton("Color")
		for _, ink in ipairs(Theme.NOTE) do
			inks:CreateRadio(ink.name, function() return (note.ink or Theme.NOTE[1].key) == ink.key end, function()
				note.ink = ink.key
				Draw()
			end)
		end
		root:CreateButton("Lead me there", function() Lead(note) end)
		root:CreateButton("Draw for this note", function() Notes.Pen(true, note) end):SetSub("It goes when the note does")
		root:CreateButton("Copy as a code", function() UI.CopyField(pin, Notes.Code({ note }), { cursor = true }) end)
		local share = Shy.Way.Share
		if not Shy.Way.missing and share and share.Write then share.Write(root, function() return Place(note) end, "Share with") end
		UI.TellMenu(root, "Link in chat", function() return Words(note) .. ":" end, function()
			return note.map, note.x, note.y
		end)
		root:CreateDivider()
		root:CreateButton("Remove note", function() Notes.Remove(note) end)
	end)
end

local function Click(pin, button)
	UI.TipHide(pin)
	if button == "RightButton" then Menu(pin) else Lead(pin.note) end
end

local function Pin(i)
	local pin = pins[i]
	if not pin then
		pin = View.Pin("PIN_FRAME_LEVEL_ACTIVE_QUEST", K.SIZE, Tip, Click)
		pin.icon:Hide()
		pin.mark = Maps.Mark(pin, K.SIZE)
		pin.mark:SetPoint("CENTER")
		pin.label = pin:CreateFontString(nil, "OVERLAY")
		pin.label:SetFontObject(UI.NameFont(10, "OUTLINE"))
		pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -1)
		pins[i] = pin
	end
	return pin
end

-- The pins of the notes on the map shown.
local function Stand()
	used = 0
	if View.IsOpen() and T.db.notesOn and not ns.Inside() then
		for _, note in ipairs(All()) do
			local x, y = Shown(note.world, note.north, note.west, note.map, note.x, note.y)
			if x then
				used = used + 1
				local pin = Pin(used)
				local color = Theme.Note(note.ink)
				pin.note = note
				pin.mark:Set("note", color)
				pin.label:SetText(Short(Words(note)))
				pin.label:SetTextColor(color[1], color[2], color[3])
				View.Stand(pin, x, y)
			end
		end
	end
	for i = used + 1, #pins do
		pins[i].note = nil
		pins[i]:Hide()
	end
end

-- The pin a note stands as on the map shown, or nil.
function Notes.PinOf(note)
	for i = 1, used do
		if pins[i].note == note then return pins[i] end
	end
end

-- text: its words already (a code's, a shared pin's): no field opens for them.
function Notes.Add(world, north, west, map, x, y, text, ink)
	if not (world and north and map and x) then return nil end
	local list = All()
	T.db.noteId = (T.db.noteId or 0) + 1
	local note = { id = T.db.noteId, world = world, north = north, west = west, map = map, x = x, y = y, text = text or "",
		ink = ink or T.db.noteInk or Theme.NOTE[1].key, at = time() }
	list[#list + 1] = note
	if text then
		Draw()
		return note
	end
	PlaySound(SOUNDKIT.UI_MAP_WAYPOINT_CLICK_TO_PLACE)
	Draw()
	local pin = Notes.PinOf(note)
	if pin then Write(note, pin, true) end
	return note
end

function Notes.Remove(note)
	local list = All()
	for i = #list, 1, -1 do
		if list[i] == note then table.remove(list, i) end
	end
	-- (What was drawn for it goes with it.)
	local strokes = T.db.drawings or {}
	for i = #strokes, 1, -1 do
		if note.id and strokes[i].note == note.id then table.remove(strokes, i) end
	end
	Draw()
end

-- A note where a click on the map shown fell.
local function AddAt(map, x, y)
	local world, position = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
	if not (world and position) then
		UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA())
		return
	end
	local north, west = position:GetXY()
	Notes.Add(world, north, west, map, x, y)
end

local function AddHere()
	local world, north, west = Shy.Here(true)
	local map, x, y = Shy.HereOn(true)
	if not (world and map and x) then
		UIErrorsFrame:AddMessage(MAP_PIN_INVALID_MAP, RED_FONT_COLOR:GetRGBA())
		return
	end
	Notes.Add(world, north, west, map, x, y)
end

-- The pen

local function Ink()
	return Theme.Note(pen and pen.ink or T.db.noteInk)
end

-- A stroke: { world, ink, north, west, ... } in yards, and its kind: none for the pen's own line, "line" and
-- "arrow" (from and to), "ring" (its middle and a point of its rim), "mark" (a raid mark, `mark` 1 to 8, at its
-- one place); `note`: the note it was drawn for, which it goes with.
local TOOLS = {
	{ key = "pen", name = "Pen" }, { key = "line", name = "Straight line" }, { key = "arrow", name = "Arrow" },
	{ key = "ring", name = "Ring" }, { key = "mark", name = "Raid mark" }, { key = "eraser", name = "Eraser" },
}
local MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local MARK_NAMES = { RAID_TARGET_1, RAID_TARGET_2, RAID_TARGET_3, RAID_TARGET_4, RAID_TARGET_5, RAID_TARGET_6, RAID_TARGET_7, RAID_TARGET_8 }
local SHAPE = { head = 14, spread = 0.45, ring = 48, mark = 22, erase = 9 }   -- pixels on screen; the head's turn

-- A stroke's points as the map's art pixels: x, y, x, y, ...; nil off the map shown's world.
local function Flat(stroke, map, world, w, h)
	if stroke[1] ~= world then return nil end
	local flat = {}
	for i = 3, #stroke - 1, 2 do
		local x, y = ns.OnMap(map, world, stroke[i], stroke[i + 1])
		if x then flat[#flat + 1], flat[#flat + 2] = x * w, y * h end
	end
	return flat
end

local function Lay()
	if not (pen and pen.lay) then return end
	local map, s = View.Map(), View.Scale()
	local w, h = View.Size()
	local world = map and View.World(map)
	pen.marked = 0
	Maps.Begin(pen.lay, 1 / s)
	if world and w and View.IsOpen() and T.db.notesOn and not ns.Inside() then
		local function Segment(ax, ay, bx, by, color)
			Maps.Segment(pen.lay, ax, ay, bx, by, K.THICK, K.ALPHA, color)
		end
		local function One(stroke)
			local flat = Flat(stroke, map, world, w, h)
			if not flat or #flat < 2 then return end
			local color, kind = Theme.Note(stroke[2]), stroke.kind
			if kind == "mark" then
				pen.marked = pen.marked + 1
				local t = pen.marks[pen.marked]
				if not t then
					t = pen.sheet:CreateTexture(nil, "OVERLAY")
					pen.marks[pen.marked] = t
				end
				t:SetTexture(MARK .. (stroke.mark or 1))
				t:SetSize(SHAPE.mark / s, SHAPE.mark / s)
				t:ClearAllPoints()
				t:SetPoint("CENTER", pen.sheet, "TOPLEFT", flat[1], -flat[2])
				t:Show()
				return
			end
			if kind == "ring" and #flat >= 4 then
				local cx, cy = flat[1], flat[2]
				local r = math.sqrt((flat[3] - cx) ^ 2 + (flat[4] - cy) ^ 2)
				local px, py = cx + r, cy
				for i = 1, SHAPE.ring do
					local a = i / SHAPE.ring * 2 * math.pi
					local nx, ny = cx + r * math.cos(a), cy + r * math.sin(a)
					Segment(px, py, nx, ny, color)
					px, py = nx, ny
				end
				return
			end
			if #flat == 2 then flat[3], flat[4] = flat[1] + 0.01, flat[2] end
			for i = 1, #flat - 3, 2 do Segment(flat[i], flat[i + 1], flat[i + 2], flat[i + 3], color) end
			if kind == "arrow" then
				local n = #flat
				local dx, dy = flat[n - 1] - flat[n - 3], flat[n] - flat[n - 2]
				local len = math.sqrt(dx * dx + dy * dy)
				if len > 0 then
					local head = SHAPE.head / s
					local back = math.atan2(-dy, -dx)
					for _, turn in ipairs({ SHAPE.spread, -SHAPE.spread }) do
						Segment(flat[n - 1], flat[n], flat[n - 1] + head * math.cos(back + turn), flat[n] + head * math.sin(back + turn), color)
					end
				end
			end
		end
		for _, stroke in ipairs(Strokes()) do One(stroke) end
		if pen.stroke then One(pen.stroke) end
	end
	Maps.Finish(pen.lay)
	for i = pen.marked + 1, #pen.marks do pen.marks[i]:Hide() end
	pen.laidAt = s
end

-- The world's yards under the mouse, on the map shown.
local function Under()
	local map = View.Map()
	local x, y = View.Cursor(true)
	if not (map and x) then return nil end
	local world, position = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
	if not (world and position) then return nil end
	local north, west = position:GetXY()
	return world, north, west
end

local function Kept(stroke)
	-- Thinned in the map's art pixels, kept in yards.
	local map = View.Map()
	local w, h = View.Size()
	if not (map and w) or #stroke < 7 then return stroke end
	local flat, yards = {}, {}
	for i = 3, #stroke - 1, 2 do
		local x, y = ns.OnMap(map, stroke[1], stroke[i], stroke[i + 1])
		if x then
			flat[#flat + 1], flat[#flat + 2] = x * w, y * h
			yards[#flat / 2] = { stroke[i], stroke[i + 1] }
		end
	end
	local thin = ns.Travel and ns.Travel.Thin(flat, K.BEND / View.Scale()) or flat
	local out, j = { stroke[1], stroke[2], note = stroke.note }, 1
	for i = 1, #thin, 2 do
		while j <= #flat / 2 and (flat[2 * j - 1] ~= thin[i] or flat[2 * j] ~= thin[i + 1]) do j = j + 1 end
		if yards[j] then out[#out + 1], out[#out + 2] = yards[j][1], yards[j][2] end
	end
	return out
end

-- How far (art pixels) a point is from a stroke as it is drawn.
local function Away(flat, kind, px, py)
	if kind == "mark" or #flat < 4 then return math.sqrt((flat[1] - px) ^ 2 + (flat[2] - py) ^ 2) end
	if kind == "ring" then
		local r = math.sqrt((flat[3] - flat[1]) ^ 2 + (flat[4] - flat[2]) ^ 2)
		return math.abs(math.sqrt((px - flat[1]) ^ 2 + (py - flat[2]) ^ 2) - r)
	end
	local best = math.huge
	for i = 1, #flat - 3, 2 do
		local ax, ay, bx, by = flat[i], flat[i + 1], flat[i + 2], flat[i + 3]
		local dx, dy = bx - ax, by - ay
		local t = (dx * dx + dy * dy) > 0 and math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy))) or 0
		best = math.min(best, math.sqrt((ax + t * dx - px) ^ 2 + (ay + t * dy - py) ^ 2))
	end
	return best
end

-- The eraser: every stroke under the mouse goes.
local function Erase()
	local map = View.Map()
	local w, h = View.Size()
	local world = map and View.World(map)
	local x, y = View.Cursor(true)
	if not (world and w and x) then return end
	local px, py, reach = x * w, y * h, SHAPE.erase / View.Scale()
	local list, gone = Strokes(), false
	for i = #list, 1, -1 do
		local flat = Flat(list[i], map, world, w, h)
		if flat and #flat >= 2 and Away(flat, list[i].kind, px, py) <= reach + (list[i].kind == "mark" and SHAPE.mark / 2 / View.Scale() or 0) then
			table.remove(list, i)
			gone = true
		end
	end
	if gone then Lay() end
end

local function Tool() return pen and pen.tool or "pen" end

local function PenEvent(what)
	if not pen then return end
	local tool = Tool()
	if what == "down" then
		if tool == "eraser" then
			pen.erasing = true
			Erase()
			return
		end
		local world, north, west = Under()
		if not world then return end
		if tool == "mark" then
			table.insert(Strokes(), { world, pen.ink, north, west, kind = "mark", mark = pen.mark or 1, note = pen.note })
			Lay()
			return
		end
		if tool == "pen" then
			pen.stroke = { world, pen.ink, north, west, note = pen.note }
		else
			pen.stroke = { world, pen.ink, north, west, north, west, kind = tool, note = pen.note }
		end
		pen.last = { GetCursorPosition() }
	elseif what == "up" then
		pen.erasing = false
		local stroke = pen.stroke
		pen.stroke = nil
		if not stroke then return end
		if not stroke.kind then
			if #stroke >= 4 then table.insert(Strokes(), Kept(stroke)) end
		elseif (stroke[3] - stroke[5]) ^ 2 + (stroke[4] - stroke[6]) ^ 2 > 1 then
			table.insert(Strokes(), stroke)
		end
		Lay()
	end
end

-- While a stroke is drawn: the pen takes a point each time the mouse has moved far enough; a line, an arrow or a
-- ring follows the mouse with its other end; the eraser goes on erasing.
local function PenTick()
	if pen and pen.erasing then
		Erase()
		return
	end
	if not (pen and pen.stroke) then
		if pen and pen.laidAt and math.abs(View.Scale() / pen.laidAt - 1) > 0.02 then Lay() end
		return
	end
	local cx, cy = GetCursorPosition()
	local e = View.Port():GetEffectiveScale()
	local last = pen.last
	if (cx - last[1]) ^ 2 + (cy - last[2]) ^ 2 < (K.STEP * e) ^ 2 or #pen.stroke >= 2 * K.MOST + 2 then return end
	local world, north, west = Under()
	if world ~= pen.stroke[1] then return end
	local stroke = pen.stroke
	if stroke.kind then
		stroke[5], stroke[6] = north, west
	else
		stroke[#stroke + 1], stroke[#stroke + 2] = north, west
	end
	pen.last[1], pen.last[2] = cx, cy
	Lay()
end

local function Done()
	if pen and pen.done then return pen.done end
	local done = CreateFrame("Button", nil, View.Chrome())
	done:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 120)
	done:SetSize(150, 26)
	done:SetPoint("BOTTOM", View.Port(), "BOTTOM", 0, 16)
	UI.Skin(done, UI.colors.bgHot)
	done.text = UI.Text(done, "Done drawing", 12, false, UI.colors.head)
	done.text:SetPoint("CENTER")
	UI.Press(done, { fill = UI.colors.bgHot })
	done:SetScript("OnClick", function() Notes.Pen(false) end)
	done:Hide()
	return done
end

-- note: what is drawn now goes with that note (and goes when it does).
function Notes.Pen(on, note)
	if on == nil then return pen ~= nil and pen.up == true end
	if on then
		pen = pen or {}
		pen.up, pen.ink, pen.note = true, T.db.noteInk or Theme.NOTE[1].key, note and note.id or nil
		pen.done = Done()
		pen.done.text:SetText(note and "Done drawing for the note" or "Done drawing")
		pen.done:SetWidth(note and 190 or 150)
		pen.done:Show()
		View.SetPen(PenEvent)
		SetCursor("CAST_CURSOR")
	elseif pen and pen.up then
		pen.up, pen.stroke, pen.erasing, pen.note = false, nil, false, nil
		if pen.done then pen.done:Hide() end
		View.SetPen(nil)
		ResetCursor()
	end
	if barButton then barButton:SetOn(Notes.Pen()) end
end

function Notes.Tool(key, mark)
	pen = pen or {}
	pen.tool, pen.mark = key, mark or pen.mark
	if not Notes.Pen() then Notes.Pen(true) end
end

local function TakeBack()
	local list = Strokes()
	table.remove(list)
	Lay()
end

local function ClearShown()
	local map = View.Map()
	local world = map and View.World(map)
	local list = Strokes()
	for i = #list, 1, -1 do
		local stroke = list[i]
		if stroke[1] == world then
			for j = 3, #stroke - 1, 2 do
				local x, y = ns.OnMap(map, world, stroke[j], stroke[j + 1])
				if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then
					table.remove(list, i)
					break
				end
			end
		end
	end
	Lay()
end

-- Codes: notes as a line of text to paste anywhere and add back ("shynotes1;map:x:y:ink:words;..."; x and y in
-- ten-thousandths of the map, the words with %, : and ; written as %XX).
local CODE = "shynotes1"
local function Escape(text) return (text:gsub("[%%:;]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function Unescape(text) return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)) end

function Notes.Code(list)
	local parts = { CODE }
	for _, note in ipairs(list) do
		parts[#parts + 1] = ("%d:%d:%d:%s:%s"):format(note.map, math.floor(note.x * 10000 + 0.5), math.floor(note.y * 10000 + 0.5),
			note.ink or Theme.NOTE[1].key, Escape(note.text or ""))
	end
	return table.concat(parts, ";")
end

-- The notes a code holds, added (those already there skipped): how many were.
function Notes.FromCode(text)
	text = strtrim(text or "")
	if text:sub(1, #CODE + 1) ~= CODE .. ";" then return 0 end
	local added = 0
	for part in text:sub(#CODE + 2):gmatch("[^;]+") do
		local map, x, y, ink, words = part:match("^(%d+):(%d+):(%d+):([%w]*):(.*)$")
		map, x, y = tonumber(map), tonumber(x), tonumber(y)
		if map and x and y then
			x, y, words = x / 10000, y / 10000, Unescape(words or "")
			local there = false
			for _, note in ipairs(All()) do
				if note.map == map and math.abs(note.x - x) < 1e-4 and math.abs(note.y - y) < 1e-4 and (note.text or "") == words then there = true end
			end
			local world, position = C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x, y))
			if not there and world and position then
				local north, west = position:GetXY()
				Notes.Add(world, north, west, map, x, y, words, ink ~= "" and ink or nil)
				added = added + 1
			end
		end
	end
	return added
end

-- The bar's button

local function Show(note)
	local map = View.Map()
	local x, y = Shown(note.world, note.north, note.west, note.map, note.x, note.y)
	if x then
		View.Glide(x, y, math.max(View.Scale() / View.Fit(), 2.5))
	elseif note.map ~= map then
		View.Fly(note.map, function()
			local nx, ny = Shown(note.world, note.north, note.west, note.map, note.x, note.y)
			if nx then View.Glide(nx, ny, math.max(View.Scale() / View.Fit(), 2.5)) end
		end)
	end
end

local function BarMenu(root)
	root:CreateTitle("Notes")
	local next = root:CreateButton("Add a note", function()
		Notes.Pen(false)
		if ns.Nav and ns.Nav.Next then ns.Nav.Next(AddAt) end
	end)
	next:SetSub("Then click the map where you want it")
	local here = root:CreateButton("Add a note where I am", AddHere)
	if not Shy.Here() then here:SetEnabled(false) end
	local list = All()
	if #list > 0 then
		local all = root:CreateButton(("Your notes (%d)"):format(#list))
		for i = #list, 1, -1 do
			local note = list[i]
			local row = all:CreateButton(Short(Words(note)), function() Show(note) end)
			row:SetDetail(Where(note))
		end
		all:SetScrollMode(360)
	end
	if #list > 0 then
		root:CreateButton("Copy all as a code", function() UI.ShowCopyBox("Your notes", Notes.Code(list)) end)
	end
	root:CreateButton("Add from a code", function()
		UI.WriteField(barButton, "", function(text)
			if not text then return end
			local added = Notes.FromCode(text)
			T:Print(added == 1 and "1 note added." or ("%d notes added."):format(added))
		end, { hint = "Paste, then Enter", most = 0, width = 300 })
	end)
	root:CreateCheckbox("Add my group's shared pins", function() return T.db.notesFromGroup == true end,
		function() T.db.notesFromGroup = not T.db.notesFromGroup end):SetTooltip("A pin someone in your group shares with you is kept as a note too.")
	root:CreateDivider()
	root:CreateCheckbox("Draw on the map", function() return Notes.Pen() end, function() Notes.Pen(not Notes.Pen()) end)
	local tools = root:CreateButton("Tool")
	for _, tool in ipairs(TOOLS) do
		if tool.key == "mark" then
			local marks = tools:CreateButton(tool.name)
			for i, name in ipairs(MARK_NAMES) do
				local row = marks:CreateRadio(name, function() return Tool() == "mark" and (pen.mark or 1) == i end, function() Notes.Tool("mark", i) end)
				row:SetIcon(MARK .. i)
			end
		else
			tools:CreateRadio(tool.name, function() return Tool() == tool.key end, function() Notes.Tool(tool.key) end)
		end
	end
	local inks = root:CreateButton("Ink")
	for _, ink in ipairs(Theme.NOTE) do
		inks:CreateRadio(ink.name, function() return (T.db.noteInk or Theme.NOTE[1].key) == ink.key end, function()
			T.db.noteInk = ink.key
			if pen then pen.ink = ink.key end
		end)
	end
	local back = root:CreateButton("Take back the last stroke", TakeBack)
	back:SetEnabled(#Strokes() > 0)
	local clear = root:CreateButton("Clear this map's drawing", ClearShown)
	clear:SetEnabled(#Strokes() > 0)
end

if T.BarButton then
	T:BarButton("notes", {
		size = 14, order = 2,
		tip = "Notes",
		text = "Your own notes on the map, and a pen to draw on it.",
		hints = { { "left", "Add, find or draw" } },
		lit = function() return Notes.Pen() end,
		click = function(self) UI.DropMenu(self, BarMenu) end,
		made = function(made)
			barButton = made
			Shy.Hover.Glyph(made.glyph, "note", 14)
		end,
	})
end

-- The layer

Draw = function()
	Stand()
	Lay()
end

local function Build()
	local sheet = CreateFrame("Frame", nil, View.Canvas())
	sheet:SetAllPoints()
	sheet:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_FLIGHT_ROUTES"))
	pen = pen or {}
	pen.sheet = sheet
	pen.lay = Maps.Pen(sheet, "TOPLEFT", sheet, true)
	pen.marks = {}
end

ns.Layer({
	id = "notes",
	later = true,
	Use = function(on)
		if on and not (pen and pen.lay) then Build() end
		if not on then
			Notes.Pen(false)
			Draw()
		end
	end,
	Map = Draw,
	Scale = function()
		for i = 1, used do View.Stand(pins[i], pins[i].x, pins[i].y) end
		if pen and pen.laidAt and math.abs(View.Scale() / pen.laidAt - 1) > (View.Busy() and 0.45 or 0.02) then Lay() end
	end,
	Tick = PenTick,
	Close = function() Notes.Pen(false) end,
})

ns.OnApply(function()
	if View.IsOpen() then Draw() end
end)

-- A pin someone in your group shares (ShyWay's offer), kept as a note too while that is asked for.
Shy:On("SHY_WAY_SHARE", function(what, record)
	if what ~= "offer" or not (T.db.notesFromGroup and type(record) == "table" and record.map and record.x and record.from) then return end
	local from = record.from
	if not (UnitInParty(from) or UnitInRaid(from)) then return end
	local words = (record.title and record.title ~= "" and record.title or "Shared pin") .. " (" .. from .. ")"
	for _, note in ipairs(All()) do
		if note.map == record.map and math.abs(note.x - record.x) < 1e-4 and math.abs(note.y - record.y) < 1e-4 then return end
	end
	local world, position = C_Map.GetWorldPosFromMapPos(record.map, CreateVector2D(record.x, record.y))
	if not (world and position) then return end
	local north, west = position:GetXY()
	Notes.Add(world, north, west, record.map, record.x, record.y, words, "teal")
end)
