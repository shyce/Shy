-- Shy.Settings: every setting of every addon in one list, the /shy window's Settings room. An addon column down
-- its left, the list beside it, a field over both that finds a setting as you type.
--
-- An addon tells its settings as a list, top down, in its own Options.lua:
--
--   T:Settings({
--       { section = "Beside the minimap" },                       a caption. What follows stands under it
--       { key = "debuffs", label = "Debuffs", desc = "..." },     a switch: T.db.debuffs, true or false
--       { key = "size", label = "Size", min = 20, max = 44, step = 2 },                         a slider
--       { key = "look", label = "Buffs", items = { { value = "run", text = "Icons" }, ... } },  a choice
--       { key = "tint", label = "Color", color = true },          a color: T.db.tint = { r, g, b }
--       { key = "name", label = "Name", text = true },            words you type
--       { label = "Moved windows", button = "Reset", run = function() end },   a button
--       { note = "..." },                                         a quiet sentence
--       { build = function(parent, width) return frame end, height = 120 },    a piece of your own: a list
--                                                                 to edit, never a preview. A setting shows on
--                                                                 the thing it changes, on your screen
--   })
--
-- What an entry may say:
--   key        where it is kept: a name in T.db, or a path ("card.shown"). The list reads, writes and resets it,
--              and its default is the one in the addon's defaults
--   get, set   for one read or written its own way. With no key, `default` says what a reset puts back
--   label      one to four words                desc    one sentence: what changes on your screen. It may be a
--              function, for a sentence that says how things stand now; so may a button's word
--   words      more words to find it by
--   shown()    false: left out.                 needs = "Frames": left out without that addon
--   enabled()  false: dimmed. false and a few words: dimmed, and the row says why under the mouse
--   apply(v)   after a change, instead of the list's own `apply`
--   format(v)  a slider's value in words.       settle = true: taken when the knob is let go
--   says()     a few words after the label: what it holds now (a button's row)
--   run(button)   what a button does.           button: its word ("Go")
--   alert      a quiet sentence that is a warning: in gold
--   confirm    a button that asks first.        placeholder, maxLetters: of words you type
--   height     of a piece of your own: a number, or function(width) (asked again whenever a setting changes)
--   sub        it hangs on the setting above it: stood in a little
--   kind       only where the rest doesn't say it: "toggle", "slider", "choice", "color", "text", "action",
--              "note", "custom"
-- The list itself may say:
--   apply()    after any change (T:Apply() unless told)      reset()   what Defaults does (T:ResetDB(), then apply)
--
--   Shy.Settings.Open()            the room             Shy.Settings.Show(addon)   the room, at that addon
--   Shy.Settings.Find(words)       the room, looking for them
--   Shy.Settings.Refresh()         something changed a setting from outside the list (a command, a menu on the
--                                  piece, layout mode): the rows in sight read again on the next frame. Nothing
--                                  while the room is closed. The room hears the game's own settings change by itself
--   Shy.Settings.Groups()          every addon's settings as the list holds them: { key, addon, title, entries }
--   Shy.Settings.Get(m) / Set(m, value) / Default(m) / Changed(m) / Reset(m) / Shown(m)   m: one of a group's entries
--   Shy.Settings.Count()           how many settings there are
--   Shy.Settings.List()            the room's list (UI.List), once it has been opened
-- Bus: SHY_SETTING (addon, key, value) after a setting changed here. An addon that wants to hear of one
-- setting alone: Shy:OnFor("SHY_SETTING", T, function(_, key, value) end).
local Shy = Shy
local UI, Theme, Hub, Search, B = Shy.UI, Shy.Theme, Shy.Hub, Shy.Search, Shy.Brand
local Settings = Shy.Settings
local C = UI.colors
local floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs

-- TOP: the field's strip. NAV: the addon column; GAP: between it and the list; BAR: the list's scroll bar.
-- LINE, CAP: a line and a caption of the column. HEAD: an addon's heading; SECTION: a caption; ROW: a setting
-- with no sentence; SAYS: a sentence's line; TAIL: under an addon's last row. PAD: a row's own margin.
-- FEW: a choice of this many at most stands side by side, where every word fits; SEG, SEG_LETTER: a side's
-- width, and what each letter of its longest word adds. CONTROL: the widest a control is; ROOM: between a row's words and its
-- control. EASE: how fast the column's mark glides, per second. LETTER: about how wide a letter of a sentence is, to cut one to its line. READ: ms a
-- frame spent reading words into the search. SURE: a sentence this many times shorter or longer than its line,
-- by its letters, is one line or two without being measured.
local S = { TOP = 40, NAV = 164, GAP = 20, BAR = 14, LINE = 22, CAP = 24, HEAD = 50, SECTION = 30, ROW = 28, SAYS = 13,
	TAIL = 18, PAD = 14, CONTROL = 220, ROOM = 18, FIELD = 28, COUNT = 96, EASE = 14, MARK = 2, LETTER = 5.6, READ = 1, SURE = 1.3,
	SWITCH = 36, SWATCH = 38, PICK = 180, BUTTON = 96, NOTE = 8, SUB = 16, FEW = 3, SEG = 22, SEG_LETTER = 8 }
local KEPT = { toggle = true, slider = true, choice = true, color = true, text = true }
local WIDE = { toggle = S.SWITCH, slider = S.CONTROL, choice = S.PICK, color = S.SWATCH, text = S.PICK, action = S.BUTTON,
	door = S.BUTTON }

---------------------------------------------------------------------------
-- What was told, as the list holds it
---------------------------------------------------------------------------

local model = { stamp = -1, commands = -1, groups = {}, byKey = {}, count = 0 }
local records, commandEntries, doorEntries = {}, {}, {}

local function KindOf(e)
	if e.kind then return e.kind end
	if e.section then return "section" end
	if e.note then return "note" end
	if e.build then return "custom" end
	if e.run then return "action" end
	if e.items then return "choice" end
	if e.min then return "slider" end
	if e.color then return "color" end
	if e.text then return "text" end
	return "toggle"
end

local function Path(key)
	local parts = {}
	for part in tostring(key):gmatch("[^.]+") do parts[#parts + 1] = tonumber(part) or part end
	return parts
end

local function Read(root, path)
	local t = root
	for i = 1, #path do
		if type(t) ~= "table" then return nil end
		t = t[path[i]]
	end
	return t
end

local function Write(root, path, value)
	local t = root
	for i = 1, #path - 1 do
		local nxt = t[path[i]]
		if type(nxt) ~= "table" then
			nxt = {}
			t[path[i]] = nxt
		end
		t = nxt
	end
	t[path[#path]] = value
end

local function Record(group, e, section)
	local m = records[e]
	if not m then
		m = { e = e }
		records[e] = m
	end
	m.group, m.kind, m.under = group, KindOf(e), section
	m.path = e.key and Path(e.key) or nil
	m.label = e.label or e.section or ""
	m.desc = e.desc or e.note
	-- (A sentence that says how things stand now: asked for whenever the row is written.)
	if type(m.desc) == "function" then
		m.says = m.desc
		m.desc = m.says() or ""
	else
		m.says = nil
	end
	m.hw = nil
	return m
end

function Settings.Shown(m)
	local e = m.e
	if e.needs and not Shy.addons[e.needs] then return false end
	if e.shown and not e.shown() then return false end
	local under = m.under
	if under and under ~= m then return Settings.Shown(under) end
	return true
end

function Settings.Get(m)
	local e = m.e
	if e.get then return e.get() end
	local db = m.group.addon.db
	if not (db and m.path) then return nil end
	local value = Read(db, m.path)
	if m.kind == "color" and type(value) == "table" then return value[1], value[2], value[3] end
	return value
end

function Settings.Default(m)
	local e = m.e
	local default = e.default
	if type(default) == "function" then default = default() end
	if default == nil and m.path then default = Read(m.group.addon.defaults or {}, m.path) end
	return default
end

local function Same(a, b)
	if type(a) == "number" and type(b) == "number" then return abs(a - b) < 0.0001 end
	return a == b
end

function Settings.Changed(m)
	if not KEPT[m.kind] then return false end
	local default = Settings.Default(m)
	if default == nil then return false end
	if m.kind == "color" then
		if type(default) ~= "table" then return false end
		local r, g, b = Settings.Get(m)
		return not (Same(r, default[1]) and Same(g, default[2]) and Same(b, default[3]))
	end
	return not Same(Settings.Get(m), default)
end

local function Applied(m, ...)
	local e, group = m.e, m.group
	local told, addon = group.told, group.addon
	if e.apply then
		e.apply(...)
	elseif told and told.apply then
		told.apply()
	elseif addon.Apply then
		addon:Apply()
	end
	Shy:Fire("SHY_SETTING", addon, e.key, ...)
	Settings.Refresh()
end

function Settings.Set(m, ...)
	local e, db = m.e, m.group.addon.db
	if e.set then
		e.set(...)
	elseif m.path and db then
		if m.kind == "color" then
			local color = Read(db, m.path)
			if type(color) ~= "table" then
				color = {}
				Write(db, m.path, color)
			end
			color[1], color[2], color[3] = ...
		else
			Write(db, m.path, (...))
		end
	end
	Applied(m, ...)
end

function Settings.Reset(m)
	local default = Settings.Default(m)
	if default == nil then return end
	if m.kind == "color" then
		Settings.Set(m, default[1], default[2], default[3])
	else
		Settings.Set(m, default)
	end
end

-- An addon's Defaults: its own way, or every saved setting back as it shipped.
function Settings.Defaults(group)
	local told, addon = group.told, group.addon
	if told.reset then
		told.reset()
	else
		addon:ResetDB()
		if told.apply then told.apply() elseif addon.Apply then addon:Apply() end
	end
	Settings.Refresh()
end

local function Synthetic(cache, key, make)
	local e = cache[key]
	if not e then
		e = make()
		cache[key] = e
	end
	return e
end

local function Model()
	local listed = Hub.Commands()
	if model.stamp == Settings.stamp and model.commands == #listed then return model end
	model.stamp, model.commands = Settings.stamp, #listed
	local groups, byKey = {}, {}
	model.groups, model.byKey, model.count = groups, byKey, nil
	-- What can be looked for, in the list's order. The words are read off them later, a few a frame (Index).
	local docs = {}
	model.index, model.docs, model.indexed = Search.New(), docs, 0

	local function Add(group, e, section)
		local m = Record(group, e, section)
		group.entries[#group.entries + 1] = m
		if m.kind ~= "section" then
			m.where = group.where .. " " .. (section and section.label or "")
			docs[#docs + 1] = m
		end
		return m
	end

	local function Group(told, category)
		local addon = told.addon
		local group = model.kept and model.kept[addon.suffix] or { head = { isHead = true }, tail = { blank = true, h = S.TAIL }, hits = {} }
		group.head.group, group.head.h, group.tail.group = group, S.HEAD, group
		group.key, group.addon, group.told, group.category = addon.suffix, addon, told, category
		group.title = addon.internal and "General" or addon.suffix
		group.tagline = addon.internal and "What every addon shares." or addon.tagline
		group.mark = addon.mark
		group.where = (addon.internal and (Shy.Brand.FAMILY .. " " .. Shy.Brand.OLD .. " general") or (addon.name .. " " .. addon.suffix))
		group.entries = {}
		local section
		for _, e in ipairs(told.entries) do
			local m = Add(group, e, section)
			if m.kind == "section" then
				section, m.under = m, nil
			end
		end
		-- Its commands, under its settings. (The core's own are in the Tools room: found from here, listed there.)
		local first = true
		for _, command in ipairs(listed) do
			if command.addon and command.addon.name == addon.name then
				if first then
					first = false
					section = Add(group, Synthetic(commandEntries, "section " .. addon.suffix, function()
						return { section = "Commands", words = "slash command" }
					end))
					section.under = nil
				end
				local e = Synthetic(commandEntries, command.word, function() return { kind = "command" } end)
				e.label, e.desc = "/shy " .. command.word, command.help
				Add(group, e, section)
			end
		end
		groups[#groups + 1] = group
		byKey[group.key] = group
		return group
	end

	local core = Settings.told[Shy.core.suffix]
	if core then Group(core, nil) end
	for _, category in ipairs(Shy.Listed(function(a) return Settings.told[a.suffix] ~= nil end)) do
		for _, addon in ipairs(category.addons) do Group(Settings.told[addon.suffix], category.title) end
	end
	-- The window's own rooms: found, never listed.
	local rooms = {}
	for _, item in ipairs(Hub.Rooms()) do rooms[item.key] = item.label end
	-- (The game's settings are a list of their own: each is found, and opens the Game room.)
	local doors = {}
	for i, door in ipairs(Settings.doors) do doors[i] = door end
	for _, command in ipairs(listed) do
		if not command.addon then
			local door = Synthetic(doorEntries, "command " .. command.word, function()
				return { room = "tools", head = "Commands", words = "slash command" }
			end)
			door.label, door.desc = "/shy " .. command.word, command.help
			doors[#doors + 1] = door
		end
	end
	for _, def in ipairs(Shy.Setup and Shy.Setup.GAME or {}) do
		doors[#doors + 1] = Synthetic(doorEntries, "game " .. def.key, function()
			return { room = "game", label = def.title, desc = def.desc, words = def.group }
		end)
	end
	for i, door in ipairs(doors) do
		local key = "room " .. door.room
		local group = byKey[key]
		if not rooms[door.room] then
			-- (A room no addon here fills: nothing to go to.)
		elseif not group then
			group = model.kept and model.kept[key] or { head = { isHead = true }, tail = { blank = true, h = S.TAIL }, hits = {} }
			group.head.group, group.head.h, group.tail.group = group, S.HEAD, group
			group.key, group.addon, group.door, group.room = key, Shy.core, true, door.room
			group.title, group.mark = rooms[door.room] or door.room, Shy.core.mark
			group.tagline = "A room of this window."
			group.where = group.title
			group.entries = {}
			groups[#groups + 1] = group
			byKey[key] = group
		end
		if group then
			local e = Synthetic(doorEntries, door, function() return { kind = "door" } end)
			e.label, e.desc, e.words, e.door = door.label, door.desc, door.words, door
			Add(group, e, nil)
		end
	end
	model.kept = byKey
	return model
end

-- The words of every setting read into the search, as far as `ms` allows (all of them unless told). Done a
-- little a frame once the room is open, and finished at the first letter typed if it isn't yet. True when done.
local function Index(ms)
	local docs, index = model.docs, model.index
	local from = debugprofilestop()
	while model.indexed < #docs do
		local m = docs[model.indexed + 1]
		index:Add(m, { { m.label, 1 }, { m.e.words or "", 0.7 }, { m.where, 0.5 }, { m.desc or "", 0.4 } })
		model.indexed = model.indexed + 1
		if ms and debugprofilestop() - from >= ms then break end
	end
	return model.indexed >= #docs
end

function Settings.Groups() return Model().groups end

---------------------------------------------------------------------------
-- The room
---------------------------------------------------------------------------

-- epoch: goes up when what a row says may have changed. A row reads again the first time it is drawn after.
local room = { query = "", epoch = 0, items = {}, order = {}, ranges = {}, parts = {} }

-- How many settings the list holds now: the ones left out are not counted. Counted again only when what was
-- told changed, or a setting did (one may bring others in).
function Settings.Count()
	local now = Model()
	if now.count and now.countedAt == room.epoch then return now.count end
	local count = 0
	for _, group in ipairs(now.groups) do
		for _, m in ipairs(group.entries) do
			if KEPT[m.kind] and Settings.Shown(m) then count = count + 1 end
		end
	end
	now.count, now.countedAt = count, room.epoch
	return count
end

-- The list itself (UI.List), once the room has been opened.
function Settings.List() return room.list end

local function Searching() return room.query ~= "" end

-- A few short choices stand side by side, all in sight (UI.Segmented); more, or longer ones, in a dropdown.
-- Returns how wide the row of them is, or nil for a dropdown.
local function Side(e)
	local items = e.items
	if type(items) ~= "table" or #items > S.FEW then return nil end
	-- (Every side is as wide as the longest word needs: a word must never be cut. Too wide, it is a dropdown.)
	local longest = 0
	for _, item in ipairs(items) do longest = max(longest, #item.text) end
	local wide = #items * (S.SEG + S.SEG_LETTER * longest)
	if wide > S.CONTROL then return nil end
	return wide
end

-- How wide a row's control is: what its words must stop short of.
local function ControlWidth(m)
	if m.kind == "choice" then return Side(m.e) or S.PICK end
	return WIDE[m.kind]
end

-- How much room a row's words have, beside its control.
local function TextWidth(m)
	local control = ControlWidth(m)
	return room.listW - S.PAD * 2 - (control and (control + S.ROOM) or 0) - (m.e.sub and S.SUB or 0)
end

local function Height(m)
	local e, kind = m.e, m.kind
	if m.says then
		local now = m.says() or ""
		if now ~= m.desc then m.desc, m.hw = now, nil end
	end
	if m.hw == room.listW and not (kind == "custom" and type(e.height) == "function") then return m.h end
	m.hw = room.listW
	if kind == "section" then
		m.h = S.SECTION
	elseif kind == "custom" then
		local tall = e.height
		if type(tall) == "function" then tall = tall(room.listW - S.PAD * 2) end
		m.h = (tall or 60) + S.NOTE + (e.label and 22 or 0)
	elseif kind == "note" then
		room.measure:SetWidth(room.listW - S.PAD * 2)
		room.measure:SetText(m.desc or "")
		m.h = max(S.SAYS, room.measure:GetStringHeight() or S.SAYS) + S.NOTE * 2
	elseif m.desc and m.desc ~= "" then
		-- A sentence wraps, whole, however narrow its room: never cut. Most are plainly so many lines by
		-- their length; one near a line's end is laid out to count them, once for a width.
		local wide, guess = TextWidth(m), #m.desc * S.LETTER
		local lines = ceil(guess / S.SURE / wide)
		if lines ~= ceil(guess * S.SURE / wide) then
			if m.saysOf ~= m.desc or m.saysAt ~= wide then
				room.measure:SetWidth(wide)
				room.measure:SetText(m.desc)
				m.saysLines, m.saysOf, m.saysAt = max(1, room.measure:GetNumLines() or 1), m.desc, wide
			end
			lines = m.saysLines
		end
		m.lines = lines
		m.h = S.ROW + lines * S.SAYS
	else
		m.h = S.ROW
	end
	return m.h
end

-- Rows -----------------------------------------------------------------

local function Enabled(m)
	local enabled = m.e.enabled
	if not enabled then return true end
	local on, why = enabled()
	return on and true or false, not on and why or nil
end

-- The last space in `text` at or before `at`, after `from`.
local function SpaceBefore(text, at, from)
	for i = at, from + 1, -1 do
		if text:byte(i) == 32 then return i end
	end
end

local function Fits(text, from, to, wide)
	room.measure:SetText(text:sub(from, to))
	return (room.measure:GetUnboundedStringWidth() or 0) <= wide
end

-- A row's sentence as it wraps in `wide`, whole words to a line: its text with the line ends in it, and where
-- each line after the first begins. A badge needs the line its word is on, so only a row with a found word
-- asks; laid once for a sentence and a width.
local function Wrapped(m, wide)
	local text = m.desc
	if m.wrapOf == text and m.wrapAt == wide then return m.wrapped, m.starts end
	local starts = m.starts or {}
	wipe(starts)
	room.measure:SetWidth(0)
	local from, last = 1, #text
	local reach = max(8, floor(wide / S.LETTER))   -- the letters a line holds, about
	while not Fits(text, from, last, wide) do
		-- The space the line ends at: guessed by its letters, then walked to the last one that fits.
		local stop = SpaceBefore(text, min(last, from + reach), from) or text:find(" ", from + reach, true)
		if not stop then break end   -- (one long word: nowhere to break)
		if Fits(text, from, stop - 1, wide) then
			while true do
				local after = text:find(" ", stop + 1, true)
				if not after or not Fits(text, from, after - 1, wide) then break end
				stop = after
			end
		else
			-- (A first word wider than the line stands on it alone.)
			while true do
				local before = SpaceBefore(text, stop - 1, from)
				if not before then break end
				stop = before
				if Fits(text, from, stop - 1, wide) then break end
			end
		end
		starts[#starts + 1] = stop + 1
		from = stop + 1
	end
	local parts, at = room.parts, 1
	wipe(parts)
	for i = 1, #starts do
		parts[i] = text:sub(at, starts[i] - 2)
		at = starts[i]
	end
	parts[#starts + 1] = text:sub(at)
	m.wrapped, m.starts, m.wrapOf, m.wrapAt = table.concat(parts, "\n"), starts, text, wide
	return m.wrapped, starts
end

-- The words of a row, as they stand now. Looking for something, each found word stands on a badge, whole,
-- on whichever line of its sentence it falls.
local function Tell(row)
	local m = row.m
	local label, desc = m.label, m.desc or ""
	local finding = Searching() and model.index:Score(m) ~= nil
	local wide = TextWidth(m)
	if row.where then
		local says = m.e.says
		row.where:SetText(Searching() and m.under and m.under.label or says and says() or "")
	end
	-- (A label is cut where the control begins. One that fits keeps no width of its own: a box pinned to its
	-- measured width snaps to the pixel where the row stands, and may lose its last letter to "...".)
	row.label:SetWidth(0)
	row.label:SetText(label)
	local space = max(40, wide - (row.where and row.where:GetStringWidth() + 8 or 0))
	local need = row.label:GetUnboundedStringWidth() or 0
	if need > space then row.label:SetWidth(space) end
	row.marks:Set(label, finding and model.index:Ranges(m, 1, room.ranges, true) or nil)
	if not row.desc then return end
	row.desc:SetWidth(wide)
	local found = finding and model.index:Ranges(m, 4, room.ranges, true) or nil
	if found and #found > 0 and m.kind ~= "note" then
		-- (Laid as the row was measured, each word gets its badge. Laid otherwise, the words are lit alone:
		-- a badge is never drawn where its word may not be.)
		local text, starts = Wrapped(m, wide)
		if #starts + 1 == m.lines then
			row.says:Set(text, found, starts)
		else
			row.says:Set(desc, found, false)
		end
	else
		row.says:Set(desc, nil)
	end
end

local function Fresh(row)
	local m = row.m
	local on, why = Enabled(m)
	row.off, row.why = not on, why
	if row.control and row.control.Refresh then row.control:Refresh() end
	if row.piece and row.piece.Refresh then row.piece:Refresh() end
	row.label:SetAlpha(on and 1 or 0.45)
	if row.dot then row.dot:SetShown(Settings.Changed(m)) end
	if row.back then row.back:SetShown(room.lit == row and Settings.Changed(m)) end
end

local function Base(m)
	local row = CreateFrame("Button", nil, room.list.view)
	row:SetSize(room.listW, m.h)
	row:Hide()
	row.m = m
	row.light = UI.RowLight(row)
	row.label = UI.Text(row, "", 13)
	row.label:SetPoint("TOPLEFT", S.PAD + (m.e.sub and S.SUB or 0), -6)
	row.label:SetWordWrap(false)
	row.marks = UI.Marks(row.label)
	row.Tell, row.Fresh = Tell, Fresh
	return row
end

local function Says(row)
	row.desc = UI.Text(row, "", 11, false, C.dim)
	row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
	row.desc:SetWordWrap(true)
	row.says = UI.Marks(row.desc)
	row.where = UI.Text(row, "", 10, false, C.dim)
	row.where:SetPoint("LEFT", row.label, "RIGHT", 8, -1)
	row.where:SetWordWrap(false)
end

-- A kept setting's own marks: a dot while it isn't as it shipped, and under the mouse a way back.
local function Marks(row)
	local m = row.m
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetTexture(Shy.Skin.GLYPH.dot)
	row.dot:SetSize(6, 6)
	row.dot:SetPoint("CENTER", row, "TOPLEFT", 6, -13)
	Theme.Tint(row.dot, Theme.Accent)
	row.dot:Hide()
	local back = CreateFrame("Button", nil, row)
	back:SetSize(16, 16)
	back:SetPoint("LEFT", row.where, "RIGHT", 4, 1)
	back.glyph = back:CreateTexture(nil, "ARTWORK")
	back.glyph:SetPoint("CENTER")
	UI.GlyphArt(back.glyph, "reset")
	back.glyph:SetSize(12, 12)
	Theme.Tint(back.glyph, C.dim)
	back:SetScript("OnEnter", function(self)
		Theme.Tint(self.glyph, C.head)
		UI.Tip(self, "Back to default")
	end)
	back:SetScript("OnLeave", function(self)
		Theme.Tint(self.glyph, C.dim)
		UI.TipHide(self)
	end)
	back:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Settings.Reset(m)
	end)
	back:Hide()
	row.back = back
end

local Make = {}

function Make.toggle(m)
	local row = Base(m)
	Says(row)
	Marks(row)
	local enabled = function() return Enabled(m) end
	row.control = UI.Switch(row, m.label, function() return Settings.Get(m) and true or false end,
		function(value) Settings.Set(m, value) end, { enabled = enabled })
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	-- (The whole row is the switch.)
	row:SetScript("OnClick", function()
		if not row.off then row.control:Click() end
	end)
	return row
end

function Make.slider(m)
	local row = Base(m)
	Says(row)
	Marks(row)
	local e = m.e
	local held
	local opts = { width = S.CONTROL, bare = true, wheel = false, format = e.format, enabled = function() return Enabled(m) end }
	local get, set = function() return Settings.Get(m) or e.min end, function(value) Settings.Set(m, value) end
	if e.settle then
		-- Taken when the knob is let go: until then the knob shows where it is held, and nothing changes.
		get = function() return held or Settings.Get(m) or e.min end
		set = function(value) held = value end
		opts.settle = function(value)
			held = nil
			Settings.Set(m, value)
		end
	end
	row.control = UI.Slider(row, "", e.min, e.max, e.step or 1, get, set, opts)
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	return row
end

local function Items(e)
	local items = e.items
	if type(items) == "function" then items = items() end
	return items or {}
end

function Make.choice(m)
	local row = Base(m)
	Says(row)
	Marks(row)
	local e = m.e
	local items = Items(e)
	local enabled = function() return Enabled(m) end
	local side = Side(e)
	if side then
		-- A few short choices: all in sight, the lit one gliding to the pick.
		local labels = {}
		for i, item in ipairs(items) do labels[i] = item.text end
		row.control = UI.Segmented(row, labels, function()
			local now = Settings.Get(m)
			for i, item in ipairs(items) do
				if item.value == now then return i end
			end
			return false
		end, function(i)
			if Enabled(m) then Settings.Set(m, items[i].value) end
		end, { width = side, height = 22 })
		local read = row.control.Refresh
		function row.control:Refresh()
			read(self)
			self:SetAlpha(Enabled(m) and 1 or 0.4)
		end
	else
		row.control = UI.Dropdown(row, nil, items, function() return Settings.Get(m) end, function(value) Settings.Set(m, value) end,
			{ width = S.PICK, enabled = enabled })
		if type(e.items) == "function" then
			-- A list that changes is read again with the row. (SetItems reads the dropdown itself: once.)
			local read, listing = row.control.Refresh, false
			function row.control:Refresh()
				if listing or UI.MenuOwner() == self.button then return read(self) end
				listing = true
				self:SetItems(Items(e))
				listing = false
			end
		end
	end
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	return row
end

function Make.color(m)
	local row = Base(m)
	Says(row)
	Marks(row)
	row.control = UI.ColorSwatch(row, "", function()
		local r, g, b = Settings.Get(m)
		return r or 1, g or 1, b or 1
	end, function(r, g, b) Settings.Set(m, r, g, b) end, { enabled = function() return Enabled(m) end })
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	return row
end

function Make.text(m)
	local row = Base(m)
	Says(row)
	Marks(row)
	local e = m.e
	row.control = UI.Input(row, nil, function() return Settings.Get(m) or "" end, function(value) Settings.Set(m, value) end,
		{ width = S.PICK, maxLetters = e.maxLetters, enabled = function() return Enabled(m) end,
			placeholder = e.placeholder and function() return e.placeholder end })
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	return row
end

function Make.action(m)
	local row = Base(m)
	Says(row)
	local e = m.e
	local function Run()
		e.run(row.control)
		Settings.Refresh()
	end
	local word = e.button or "Go"
	local says = type(word) == "function" and word or nil
	row.control = UI.Button(row, says and (says() or "") or word, S.BUTTON, e.confirm and function() end or Run)
	if e.confirm then UI.Twice(row.control, Run) end
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	-- (A word that changes with how things stand: "Show" while it is hidden, "Hide" while it shows.)
	function row.control:Refresh()
		self:SetUsable(Enabled(m))
		if says then self:SetLabel(says() or "") end
	end
	return row
end

function Make.door(m)
	local row = Base(m)
	Says(row)
	local door = m.e.door
	row.control = UI.Button(row, "Open", S.BUTTON, function()
		if door.head then Hub.OpenAt(door.room, door.head) else Hub.Open(door.room) end
	end)
	row.control:SetPoint("RIGHT", -S.PAD, 0)
	return row
end

function Make.command(m)
	local row = Base(m)
	Says(row)
	UI.Ink(row.label, C.alert)
	return row
end

function Make.note(m)
	local row = Base(m)
	row.label:Hide()
	row.desc = UI.Text(row, "", 11, false, C.dim)
	row.desc:SetPoint("TOPLEFT", S.PAD, -S.NOTE)
	row.desc:SetWordWrap(true)
	row.says = UI.Marks(row.desc)
	if m.e.alert then UI.Ink(row.desc, C.alert) end
	row.light = nil
	return row
end

function Make.custom(m)
	local row = Base(m)
	local e = m.e
	local wide = room.listW - S.PAD * 2
	row.label:SetShown(e.label ~= nil)
	row.piece = e.build(row, wide)
	row.piece:SetPoint("TOPLEFT", S.PAD, -(e.label and 26 or 4))
	row.light = nil
	function row:Wide(to)
		if self.piece.Fit then self.piece:Fit(to - S.PAD * 2) end
	end
	return row
end

function Make.section(m)
	local row = CreateFrame("Frame", nil, room.list.view)
	row:SetSize(room.listW, S.SECTION)
	row:Hide()
	row.m = m
	row.caption = Hub.Caption(row, room.listW - S.PAD * 2, m.label)
	row.caption:SetPoint("BOTTOMLEFT", S.PAD, 5)
	function row:Tell() end
	function row:Fresh() end
	function row:Wide(wide) self.caption:SetWidth(wide - S.PAD * 2) end
	return row
end

-- An addon's heading: its mark and name, what it is in a few words, a stub of your color and a rule. At its
-- right its window and its defaults; while looking for something, how many were found.
local function Head(item)
	local group = item.group
	local row = CreateFrame("Frame", nil, room.list.view)
	row:SetSize(room.listW, S.HEAD)
	row:Hide()
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(22, 22)
	row.icon:SetPoint("TOPLEFT", S.PAD - 2, -13)
	Theme.Icon(row.icon, group.mark)
	row.title = UI.TitleText(row, group.title, 16)
	row.title:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	-- (A still stub of your color: a heading is one of thirty, and a line that glimmers is a dozen pieces each.)
	local stub = row:CreateTexture(nil, "ARTWORK")
	stub:SetSize(36, 2)
	stub:SetPoint("BOTTOMLEFT", S.PAD - 2, 7)
	stub:SetColorTexture(1, 1, 1, 1)
	Theme.Tint(stub, Theme.Accent)
	local rule = row:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.7)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", stub, "RIGHT", 0, 0)
	rule:SetPoint("RIGHT", row, "RIGHT", -S.PAD, 0)
	rule:SetPoint("TOP", stub, "TOP", 0, 0)
	row.found = UI.Text(row, "", 11, false, C.dim)
	row.found:SetPoint("RIGHT", row, "TOPRIGHT", -S.PAD, -24)
	row.line = UI.Text(row, group.tagline or "", 11, false, C.dim)
	row.line:SetPoint("LEFT", row.title, "RIGHT", 10, -1)
	row.line:SetPoint("RIGHT", row.found, "LEFT", -10, 0)
	row.line:SetWordWrap(false)
	-- Its buttons, made the first time they are wanted: a heading among what was found has none.
	local function Buttons()
		if row.made then return end
		row.made = true
		local last
		if group.door then
			row.go = UI.Button(row, "Open", 64, function() Hub.Open(group.room) end)
			row.go:SetHeight(22)
			row.go:SetPoint("RIGHT", row, "TOPRIGHT", -S.PAD, -24)
			last = row.go
		else
			row.defaults = UI.Button(row, "Defaults", 78, function() end)
			row.defaults:SetHeight(22)
			row.defaults:SetPoint("RIGHT", row, "TOPRIGHT", -S.PAD, -24)
			UI.Twice(row.defaults, function() Settings.Defaults(group) end)
			UI.Help(row.defaults, "Defaults", "Puts every " .. group.title .. " setting back as it shipped.")
			last = row.defaults
			if group.addon.OpenWindow then
				row.open = UI.Button(row, "Open", 64, function()
					Hub.Close()
					group.addon:OpenWindow()
				end)
				row.open:SetHeight(22)
				row.open:SetPoint("RIGHT", row.defaults, "LEFT", -6, 0)
				last = row.open
			end
		end
		row.last = last
	end
	function row:Tell()
		local finding = Searching()
		local buttons = group.door or not finding
		if buttons then Buttons() end
		if self.defaults then self.defaults:SetShown(not finding) end
		if self.open then self.open:SetShown(not finding) end
		if self.go then self.go:SetShown(true) end
		local found = finding and not group.door
		self.found:SetShown(found)
		self.found:SetText(found and (group.found == 1 and "1 found" or (group.found .. " found")) or "")
		-- (Its few words end before whatever stands at its right now.)
		local ends = (buttons and self.last) or self.found
		if self.ends ~= ends then
			self.ends = ends
			self.line:SetPoint("RIGHT", ends, "LEFT", -10, 0)
		end
	end
	function row:Fresh() end
	return row
end

local function Draw(item, may)
	local row, made = item.row, false
	if not row then
		if not may then return nil end
		row = item.isHead and Head(item) or Make[item.kind](item)
		item.row = row
		row.wide = room.listW
		made = true
	end
	if row.wide ~= room.listW then
		row.wide = room.listW
		row:SetWidth(room.listW)
		if row.Wide then row:Wide(room.listW) end
		row.epoch = nil
	end
	if row.epoch ~= room.epoch then
		row.epoch = room.epoch
		if item.h and row:GetHeight() ~= item.h then row:SetHeight(item.h) end
		row:Tell()
		row:Fresh()
	end
	return row, made
end

-- The row under the mouse: lit, its way back to the default in reach, its sentence whole where it was cut.
local function Over(item)
	local was = room.lit
	if was then
		if was.light then was.light:Set(false, false) end
		if was.back then was.back:Hide() end
		UI.TipHide(was)
	end
	local row = item and item.e and item.row or nil
	room.lit = row
	if not row then return end
	if row.light then row.light:Set(true, false) end
	if row.back then row.back:SetShown(Settings.Changed(row.m)) end
	local m = row.m
	if row.why then
		-- Out of use: why, before anything else.
		UI.Tip(row, m.label ~= "" and m.label or nil, row.why, { at = UI.Beside(room.window or row, row) })
	end
end

-- What the list holds ----------------------------------------------------

-- Every addon in turn: its heading, its settings under their captions, a little air.
local function Browse()
	local items, n = room.items, 0
	for _, group in ipairs(model.groups) do
		group.found = 0
		if not group.door then
			local first, any, caption = n, false, nil
			n = n + 1
			items[n] = group.head
			for _, m in ipairs(group.entries) do
				if m.kind == "section" then
					caption = Settings.Shown(m) and m or nil
				elseif Settings.Shown(m) then
					if caption then
						Height(caption)
						n = n + 1
						items[n], caption = caption, nil
					end
					Height(m)
					n = n + 1
					items[n], any = m, true
				end
			end
			if any then
				n = n + 1
				items[n] = group.tail
			else
				n = first
			end
			group.shown = any
		end
	end
	for i = #items, n + 1, -1 do items[i] = nil end
	return items
end

-- What was found, the best first: an addon's heading where its first one stands, its others under it.
local function Results()
	local items, order = room.items, room.order
	local from = debugprofilestop()
	Index()
	local hits, count = model.index:Find(room.query)
	Shy.Clock("settings: looked for"):Lap(debugprofilestop() - from)
	for _, group in ipairs(model.groups) do group.found, group.shown = 0, false end
	for i = #order, 1, -1 do order[i] = nil end
	local total = 0
	for i = 1, count do
		local m = hits[i]
		if Settings.Shown(m) then
			local group = m.group
			if group.found == 0 then order[#order + 1] = group end
			group.found = group.found + 1
			group.hits[group.found] = m
			total = total + 1
		end
	end
	local n = 0
	for _, group in ipairs(order) do
		group.shown = true
		n = n + 1
		items[n] = group.head
		for i = 1, group.found do
			local m = group.hits[i]
			Height(m)
			n = n + 1
			items[n] = m
		end
		for i = #group.hits, group.found + 1, -1 do group.hits[i] = nil end
		n = n + 1
		items[n] = group.tail
	end
	for i = #items, n + 1, -1 do items[i] = nil end
	return items, total
end

-- The addon column ----------------------------------------------------------

local function NavLine(parent)
	local line = CreateFrame("Button", nil, parent)
	line:SetHeight(S.LINE)
	line.lift = line:CreateTexture(nil, "BACKGROUND")
	line.lift:SetAllPoints()
	Theme.Paint(line.lift, C.row, 0.5)
	line.lift:Hide()
	line.icon = line:CreateTexture(nil, "ARTWORK")
	line.icon:SetSize(14, 14)
	line.icon:SetPoint("LEFT", 10, 0)
	line.name = UI.Text(line, "", 12, false, C.dim)
	line.name:SetPoint("LEFT", 30, 0)
	line.name:SetWordWrap(false)
	line.count = UI.Text(line, "", 10, false, C.dim)
	line.count:SetPoint("RIGHT", -8, 0)
	line:SetScript("OnEnter", function(self)
		self.over = true
		self:Paint()
	end)
	line:SetScript("OnLeave", function(self)
		self.over = false
		self:Paint()
	end)
	line:SetScript("OnClick", function(self)
		if not self.group.shown then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		room.list:Go(self.group.head.y or 0)
	end)
	function line:Paint()
		local group = self.group
		local on, there = room.at == group, group.shown
		self.lift:SetShown(self.over and there or false)
		UI.Ink(self.name, on and C.head or (self.over and there) and C.text or C.dim)
		self:SetAlpha(there and 1 or 0.35)
		local count = Searching() and group.found or 0
		self.count:SetText(count > 0 and tostring(count) or "")
	end
	return line
end

-- The column as the model stands: a caption a category, a line an addon.
local function Nav()
	local nav = room.nav
	local content = nav.content
	local lines, captions, y, l, c = room.lines, room.captions, 0, 0, 0
	local category = false
	for _, group in ipairs(model.groups) do
		if not group.door then
			if group.category ~= category and group.category then
				c = c + 1
				local caption = captions[c]
				if not caption then
					caption = UI.Text(content, "", 10, true, C.dim)
					captions[c] = caption
				end
				caption:SetText(group.category:upper())
				caption:ClearAllPoints()
				caption:SetPoint("BOTTOMLEFT", content, "TOPLEFT", 10, -(y + S.CAP) + 5)
				caption:Show()
				y = y + S.CAP
			end
			category = group.category
			l = l + 1
			local line = lines[l]
			if not line then
				line = NavLine(content)
				lines[l] = line
			end
			line.group, group.line, group.lineY = group, line, y
			Theme.Icon(line.icon, group.mark)
			line.name:SetText(group.title)
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", 0, -y)
			line:SetPoint("RIGHT", content, "RIGHT", 0, 0)
			line:Show()
			y = y + S.LINE
		end
	end
	for i = l + 1, #lines do lines[i]:Hide() end
	for i = c + 1, #captions do captions[i]:Hide() end
	content:SetHeight(max(1, y + 8))
	nav:Update()
end

-- The addon in sight is the one marked in the column: a bar of your color that glides to it.
local function Glide(self, elapsed)
	local mark = room.mark
	local gap = mark.goal - mark.at
	if abs(gap) < 0.5 then
		mark.at = mark.goal
		self:SetScript("OnUpdate", nil)
	else
		mark.at = mark.at + gap * min(1, elapsed * S.EASE)
	end
	mark:SetPoint("TOPLEFT", 0, -(mark.at + 4))
end

local function Spy(offset)
	local item = room.list:ItemAt(offset + 4)
	local at = item and item.group or nil
	if at == room.at then return end
	local was = room.at
	room.at = at
	if was and was.line then was.line:Paint() end
	local mark = room.mark
	if not (at and at.line) then
		mark:Hide()
		return
	end
	at.line:Paint()
	mark.goal = at.lineY
	if not mark:IsShown() then
		mark.at = mark.goal
		mark:SetPoint("TOPLEFT", 0, -(mark.at + 4))
		mark:Show()
	else
		room.nav.content:SetScript("OnUpdate", Glide)
	end
	room.nav:Reveal(at.lineY, at.lineY + S.LINE)
end

-- Laying it out ---------------------------------------------------------------

-- The list as it stands now. fresh: what it holds changed (a word typed), so rows fade in from the top.
local function Fill(fresh)
	Model()
	room.epoch = room.epoch + 1
	local items, total
	if Searching() then
		items, total = Results()
		room.count:SetText(total == 0 and "" or total == 1 and "1 found" or (total .. " found"))
		room.empty:SetShown(total == 0)
		if total == 0 then room.empty:SetText("Nothing found for \"" .. room.query .. "\". Try another word.") end
	else
		items = Browse()
		room.count:SetText(model.count .. " settings")
		room.empty:Hide()
	end
	room.at = nil
	room.mark:Hide()
	if fresh then
		room.list.at = 0
		room.list.scroll:SetVerticalScroll(0)
	end
	room.list:SetItems(items, fresh)
	for _, line in ipairs(room.lines) do
		if line:IsShown() then line:Paint() end
	end
end

local function Lay(wide, tall)
	local listW = wide - S.NAV - S.GAP - S.BAR
	local under = tall - S.TOP
	if room.wide == wide and room.tall == tall then return end
	local widened = room.listW ~= listW
	room.wide, room.tall, room.listW = wide, tall, listW
	room.host:SetSize(wide, tall)
	room.search:SetWidth(wide - S.COUNT)
	room.nav:SetSize(S.NAV, under)
	room.nav.content:SetWidth(S.NAV - S.BAR)
	room.nav:Update()
	room.list:Resize(listW + S.BAR, under)
	if widened and room.filled then Fill() end
end

-- A game setting changed (the game's own options, a macro, another addon): a row that shows one reads again.
-- Heard only while the room is on show.
local game = CreateFrame("Frame")
game:SetScript("OnEvent", function() Settings.Refresh() end)
local function Hears(on)
	if on then game:RegisterEvent("CVAR_UPDATE") else game:UnregisterEvent("CVAR_UPDATE") end
end

local function Create()
	local host = CreateFrame("Frame")
	room.host = host
	room.lines, room.captions = {}, {}
	room.search = UI.SearchBox(host, 400, {
		height = S.FIELD, placeholder = "Find a setting",
		onChange = function(text)
			local query = strtrim(text)
			if query == room.query then return end
			room.query = query
			Fill(true)
		end,
	})
	room.search:SetPoint("TOPLEFT")
	room.count = UI.Text(host, "", 11, false, C.dim)
	room.count:SetPoint("RIGHT", host, "TOPRIGHT", -2, -S.FIELD / 2)

	room.nav = UI.ScrollArea(host, S.NAV, 300, { smooth = true })
	room.nav:SetPoint("TOPLEFT", 0, -S.TOP)
	local mark = room.nav.content:CreateTexture(nil, "ARTWORK")
	mark:SetSize(S.MARK, S.LINE - 8)
	mark:SetColorTexture(1, 1, 1, 1)
	Theme.Tint(mark, Theme.Accent)
	mark:Hide()
	mark.at, mark.goal = 0, 0
	room.mark = mark
	local rule = host:CreateTexture(nil, "ARTWORK")
	Theme.Paint(rule, C.border, 0.6)
	rule:SetWidth(1)
	rule:SetPoint("TOPLEFT", S.NAV + S.GAP / 2, -S.TOP)
	rule:SetPoint("BOTTOM", host, "BOTTOM", 0, 0)

	room.listW = 400
	room.list = UI.List(host, 400, 300, { draw = Draw, over = Over, onPlace = Spy })
	room.list.scroll:SetPoint("TOPLEFT", S.NAV + S.GAP, -S.TOP)
	room.empty = UI.Text(host, "", 13, false, C.dim)
	room.empty:SetPoint("TOP", room.list.scroll, "TOP", 0, -60)
	room.empty:Hide()
	room.measure = UI.Text(host, "", 11)
	room.measure:Hide()
	-- The search's words, read a millisecond a frame while the room is open and there are some left.
	room.reader = CreateFrame("Frame", nil, host)
	room.reader:Hide()
	room.reader:SetScript("OnUpdate", Shy.Clocked("settings: words read for the search", function(self)
		if Index(S.READ) then self:Hide() end
	end))
	host:SetScript("OnShow", function() Hears(true) end)
	host:SetScript("OnHide", function() Hears(false) end)

end

-- A setting changed, here or from outside: what is in sight reads again, once, on the next frame.
local Again = Shy.Clocked("settings: the list read again", function(self)
	self:SetScript("OnUpdate", nil)
	room.dirty = nil
	Fill()
end)

function Settings.Refresh()
	if room.dirty or not (room.host and room.filled and room.host:IsVisible()) then return end
	room.dirty = true
	room.host:SetScript("OnUpdate", Again)
end

Shy:On("SHY_THEME", Settings.Refresh)

Shy.HubSection("settings", function(page)
	page.scrollsItself = true
	local seat = CreateFrame("Frame", nil, page)
	seat:SetPoint("TOPLEFT")
	seat:SetSize(page.width, 1)
	if not room.host then Create() end
	function page:Fit(tall)
		local host = room.host
		if host:GetParent() ~= seat then
			host:SetParent(seat)
			host:ClearAllPoints()
			host:SetPoint("TOPLEFT")
		end
		room.window = ShyHubWindow
		Lay(page.width, tall)
	end
	return seat, function()
		room.filled = true
		Nav()
		Fill()
		if not Index(0) then room.reader:Show() end
	end
end)

Shy.HubBrief("settings", function()
	local count = Settings.Count()
	return count > 0 and (count .. " settings") or nil
end)

function Settings.Open()
	Hub.Open("settings")
end

-- The room at an addon's settings: where they stand in the whole list, nothing looked for.
function Settings.Show(addon)
	if not (room.host and room.host:IsVisible()) then Hub.Open("settings") end
	if not room.host then return end
	room.search:SetText("")
	local group = Model().byKey[addon.suffix]
	if group and group.head.y then room.list:Go(group.head.y, true) end
end

-- The room looking for some words, the field ready for more.
function Settings.Find(words)
	if not (room.host and room.host:IsVisible()) then Hub.Open("settings") end
	if not room.host then return end
	room.search:SetText(strtrim(words or ""))
	room.search:Focus()
	C_Timer.After(0, function()
		if room.host:IsVisible() then room.search:Focus() end
	end)
end
