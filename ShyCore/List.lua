-- Two pieces of the kit for finding one thing among many: a long list that only makes what is in sight, and
-- the field you type what you are looking for into.
--
-- UI.List: rows of any height, hundreds of them. Only the rows in sight are placed, and a row is made the first
-- time it comes into sight, a few a frame. Scrolling moves the rows in sight and nothing else.
--   local list = UI.List(parent, width, height, opts)
--       opts.draw(item, may) -> frame, made   the item's row, a child of list.view. Not made yet and `may` is
--                                       false: nil, and it is asked for again next frame. made: true when this
--                                       call made it (a few are made a frame, the rest the frames after)
--       opts.over(item)                 the row under the mouse changed (nil: none)
--       opts.onPlace(offset)            the rows in sight were placed: how far down the list stands
--   list:SetItems(items, fresh)   items[i] = { h = its height, x = from the left (0), ... }, top down. The tables are
--                                 the caller's; the list writes item.y. fresh: rows coming into sight fade in
--                                 item.blank: room with no row (a gap between groups)
--   list:Resize(width, height)
--   list:Go(y, now)               that far down the list brought to the top, gliding unless `now`
--   list:At()                     how far down it stands;  list:ItemAt(y) -> item, index
--   list:Again()                  the rows in sight placed again (an item's row changed)
--   list.view, list.scroll, list.tall
--
-- UI.SearchBox: a lens, what you type, a cross to empty it. A line of your color grows under it while it has
-- the keys. Esc empties it first and lets go of the keys second.
--   local box = UI.SearchBox(parent, width, opts)
--       opts.placeholder   the quiet words while it is empty
--       opts.onChange(text)  at every key      opts.onEnter(text)      opts.height (28)
--   box:SetText(text)   box:GetText()   box:Focus()   box.edit
--
-- UI.Marks: found words in a line of text, each on a badge: a plate of your color under the whole word, the word
-- in the ink that reads on it. For a line that doesn't wrap.
--   local marks = UI.Marks(fontString)
--   marks:Set(text, ranges)   text: plain. ranges: from, to byte pairs, a word each (none: the text alone)
local Shy = Shy
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors
local floor, max, min = math.floor, math.max, math.min

-- BAR: room kept for the scroll bar. ROWS, BUDGET: the most new rows made in one frame, and the most ms spent
-- making them. FADE: a fresh row coming in.
local LIST = { BAR = 14, ROWS = 4, BUDGET = 3, FADE = 0.16 }

function UI.List(parent, width, height, opts)
	opts = opts or {}
	local list = { items = {}, n = 0, tall = 0, at = 0, round = 0, shown = {}, was = {}, height = height }
	local scroll, view

	local function Index(y)
		local items, lo, hi = list.items, 1, list.n
		while lo < hi do
			local mid = floor((lo + hi) / 2)
			local item = items[mid]
			if item.y + item.h > y then hi = mid else lo = mid + 1 end
		end
		return lo
	end

	-- Rows still to be made, the frame after: a key and the frame's own turn come in the same frame, and
	-- would make two frames' worth of rows in one.
	local function Again()
		if list.placed ~= GetTime() then list:Place() end
	end

	function list:Place(offset)
		offset = floor((offset or self.at) + 0.5)
		self.at = offset
		local items, n = self.items, self.n
		local foot = offset + self.height
		local shown, was = self.was, self.shown
		self.shown, self.was = shown, was
		self.round, self.placed = self.round + 1, GetTime()
		local round, count, waiting, new = self.round, 0, false, 0
		local from = debugprofilestop()
		for i = Index(offset), n do
			local item = items[i]
			if item.y >= foot then break end
			if item.h > 0 and not item.blank then
				local frame, made = opts.draw(item, new < LIST.ROWS and (new == 0 or debugprofilestop() - from < LIST.BUDGET))
				if made then new = new + 1 end
				if frame then
					count = count + 1
					shown[count] = frame
					local x, y = item.x or 0, item.y - offset
					if frame.listX ~= x or frame.listY ~= y then
						frame.listX, frame.listY = x, y
						frame:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
					end
					if not frame:IsShown() then
						frame:Show()
						if self.fresh then UI.FadeIn(frame, LIST.FADE) end
					end
					frame.listRound = round
				else
					waiting = true
				end
			end
		end
		for i = #was, 1, -1 do
			local frame = was[i]
			if frame.listRound ~= round then frame:Hide() end
			was[i] = nil
		end
		-- (Rows still to be made come in over the next frames; fresh ones fade until all are in.)
		if not waiting then self.fresh = nil end
		view:SetScript("OnUpdate", waiting and Again or nil)
		if opts.onPlace then opts.onPlace(offset) end
	end

	function list:Again() self:Place() end

	function list:SetItems(items, fresh)
		self.items, self.n = items, #items
		local y = 0
		for i = 1, self.n do
			local item = items[i]
			item.y = y
			y = y + item.h
		end
		self.tall, self.fresh = y, fresh
		scroll.content:SetHeight(max(1, y))
		-- (The game tells the new range a frame late: what is in sight must not wait for it.)
		local far = max(0, y - self.height)
		if scroll:At() > far then scroll:SetVerticalScroll(far) end
		self:Place(min(self.at, far))
		scroll:Update()
	end

	function list:Resize(wide, tall)
		self.height = tall
		scroll:SetSize(wide, tall)
		scroll.content:SetWidth(wide - LIST.BAR)
		local far = max(0, self.tall - tall)
		if scroll:At() > far then scroll:SetVerticalScroll(far) end
		self:Place(min(self.at, far))
		scroll:Update()
	end

	function list:Go(y, now)
		y = max(0, min(max(0, self.tall - self.height), y))
		if now or not scroll:IsVisible() then
			scroll:SetVerticalScroll(y)
			self:Place(y)
			scroll:Update()
		else
			scroll:Reveal(y, y + self.height)
		end
	end

	function list:At() return self.at end

	function list:ItemAt(y)
		if self.n == 0 or y < 0 or y >= self.tall then return nil end
		local i = Index(y)
		return self.items[i], i
	end

	-- (How far it scrolls is the list's own count: the game's comes a frame late, and a jump made in that frame
	-- would be held to the old one.)
	scroll = UI.ScrollArea(parent, width, height, { smooth = true, onScroll = function(_, offset) list:Place(offset) end,
		range = function() return max(0, list.tall - list.height) end })
	view = CreateFrame("Frame", nil, parent)
	view:SetPoint("TOPLEFT", scroll, "TOPLEFT")
	view:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", -LIST.BAR, 0)
	view:SetClipsChildren(true)
	view:SetFrameLevel(scroll:GetFrameLevel() + 2)
	list.scroll, list.view = scroll, view

	-- The row under the mouse, asked each frame while the list is up: a row's own controls take the mouse
	-- from it, so the row can't be told its coming and going.
	if opts.over then
		local watch = CreateFrame("Frame", nil, view)
		local last
		watch:SetScript("OnUpdate", Shy.Clocked("list: the row under the mouse", function()
			local item
			if view:IsMouseOver() then
				local _, y = GetCursorPosition()
				local top, scale = view:GetTop(), view:GetEffectiveScale()
				if top and scale and scale > 0 and not issecretvalue(top) then
					item = list:ItemAt(top - y / scale + list.at)
				end
			end
			-- (A menu open over the list: the row it belongs to stays the one.)
			if item ~= last and not UI.MenuOwner() then
				last = item
				opts.over(item)
			end
		end))
		watch:SetScript("OnHide", function()
			if last then
				last = nil
				opts.over(nil)
			end
		end)
	end
	return list
end

-- GROW: seconds the line under the box takes to grow or go.
local SEARCH = { H = 28, LENS = 12, IN = 30, CROSS = 8, GROW = 0.18 }

function UI.SearchBox(parent, width, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, opts.height or SEARCH.H)
	UI.Skin(f, C.bg, C.border)
	local lens = f:CreateTexture(nil, "ARTWORK")
	lens:SetTexture(Shy.Skin.GLYPH.lens)
	lens:SetSize(SEARCH.LENS, SEARCH.LENS)
	lens:SetPoint("LEFT", 10, 0)
	Theme.Tint(lens, C.dim)

	local edit = CreateFrame("EditBox", nil, f)
	edit:SetPoint("TOPLEFT", SEARCH.IN, 0)
	edit:SetPoint("BOTTOMRIGHT", -SEARCH.IN, 0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(GameFontHighlight)
	edit:SetMaxLetters(opts.maxLetters or 60)
	f.edit = edit
	local hint = UI.Text(f, opts.placeholder or "", nil, false, C.dim)
	hint:SetPoint("LEFT", SEARCH.IN, 0)

	local cross = CreateFrame("Button", nil, f)
	cross:SetSize(SEARCH.H, SEARCH.H)
	cross:SetPoint("RIGHT")
	cross.glyph = cross:CreateTexture(nil, "ARTWORK")
	cross.glyph:SetTexture(UI.CLOSE_GLYPH)
	cross.glyph:SetSize(SEARCH.CROSS, SEARCH.CROSS)
	cross.glyph:SetPoint("CENTER")
	Theme.Tint(cross.glyph, C.dim)
	cross:SetScript("OnEnter", function(self) Theme.Tint(self.glyph, C.head) end)
	cross:SetScript("OnLeave", function(self) Theme.Tint(self.glyph, C.dim) end)
	cross:Hide()

	-- The line: grows from the left as the box takes the keys, goes as it lets them go.
	local line = f:CreateTexture(nil, "OVERLAY")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 1, 1)
	line:SetColorTexture(1, 1, 1, 1)
	Theme.Tint(line, Theme.Accent)
	line:SetAlpha(0)
	local share, goal = 0, 0
	local function Grow(self, elapsed)
		local step = elapsed / SEARCH.GROW
		share = goal > share and min(goal, share + step) or max(goal, share - step)
		local eased = 1 - (1 - share) ^ 3
		line:SetWidth(max(1, eased * (f:GetWidth() - 2)))
		line:SetAlpha(eased)
		if share == goal then self:SetScript("OnUpdate", nil) end
	end
	local function Lit(on)
		goal = on and 1 or 0
		Theme.Tint(lens, on and C.head or C.dim)
		UI.SetBorder(f, on and C.hot or C.border)
		f:SetScript("OnUpdate", Grow)
	end

	local function Told()
		local text = edit:GetText()
		hint:SetShown(text == "")
		cross:SetShown(text ~= "")
		if opts.onChange then opts.onChange(text) end
	end
	edit:SetScript("OnTextChanged", function(_, typed)
		if typed then Told() end
	end)
	edit:SetScript("OnEditFocusGained", function() Lit(true) end)
	edit:SetScript("OnEditFocusLost", function() Lit(false) end)
	edit:SetScript("OnEnterPressed", function(self)
		if opts.onEnter then opts.onEnter(self:GetText()) end
		self:ClearFocus()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then
			self:SetText("")
			Told()
		else
			self:ClearFocus()
		end
	end)
	cross:SetScript("OnClick", function()
		edit:SetText("")
		Told()
		edit:SetFocus()
	end)
	-- (A click anywhere on the field is a click into it.)
	f:EnableMouse(true)
	f:SetScript("OnMouseDown", function() edit:SetFocus() end)

	function f:SetText(text)
		if edit:GetText() == (text or "") then return end
		edit:SetText(text or "")
		Told()
	end
	function f:GetText() return edit:GetText() end
	function f:Focus() edit:SetFocus() end
	return f
end

-- PAD: how far a badge reaches past its word, each side. TALL: its height over the font's size.
local MARK = { PAD = 3, TALL = 5 }

-- The badge's colors: your color as a face words read on, and the ink for it. Worked out once for a theme
-- (finding an ink that reads is many steps), not for every word.
local function Badge()
	if not MARK.open then
		local r, g, b = Theme.FaceFor(Theme.Accent())
		local ir, ig, ib = Theme.InkOn(r, g, b)
		MARK.r, MARK.g, MARK.b = r, g, b
		MARK.open = ("|cff%02x%02x%02x"):format(floor(ir * 255 + 0.5), floor(ig * 255 + 0.5), floor(ib * 255 + 0.5))
		MARK.lit = ("|cff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
	end
	return MARK.r, MARK.g, MARK.b, MARK.open
end
Shy:On("SHY_THEME", function() MARK.open = nil end)

function UI.Marks(fs)
	local host = fs:GetParent()
	-- (A measuring string: where a word stands is the width of what comes before it.)
	local measure = host:CreateFontString(nil, "BACKGROUND")
	measure:Hide()
	local marks = { plates = {} }
	local plates = marks.plates
	local function Wide(text)
		measure:SetText(text)
		return measure:GetUnboundedStringWidth() or 0
	end
	-- starts: for words on several lines, where each line after the first begins in `text` (its line ends are
	-- in it). false: the lines aren't known, so the found words are lit in your color and stand on no badge.
	function marks:Set(text, ranges, starts)
		local n = ranges and floor(#ranges / 2) or 0
		if n == 0 then
			fs:SetText(text)
		elseif starts == false then
			n = 0
			Badge()
			fs:SetText(Shy.Search.Mark(text, ranges, MARK.lit, "|r"))
		else
			-- The plate is your color as a face words read on; the word wears the ink for it.
			local r, g, b, open = Badge()
			fs:SetText(Shy.Search.Mark(text, ranges, open, "|r"))
			local file, size, flags = fs:GetFont()
			measure:SetFont(file, size, flags)
			local room = fs:GetWidth() or 0
			local lines = starts and #starts + 1 or 1
			local tall = lines > 1 and (fs:GetStringHeight() or 0) / lines or 0
			if tall <= 0 then tall = size + 2 end
			for i = 1, n do
				local from, to = ranges[i * 2 - 1], ranges[i * 2]
				-- (Where a word stands is the width of what comes before it on its line.)
				local line = 0
				while lines > 1 and starts[line + 1] and starts[line + 1] <= from do line = line + 1 end
				local word = Wide(text:sub(from, to))
				local at = Wide(text:sub(line > 0 and starts[line] or 1, to)) - word
				local plate = plates[i]
				if not plate then
					plate = host:CreateTexture(nil, "ARTWORK")
					plate:SetSnapToPixelGrid(true)
					plate:SetTexelSnappingBias(0)
					plates[i] = plate
				end
				-- (A word past where one line is cut has no badge: it isn't there to stand on.)
				if lines == 1 and room > 0 and at + word > room + 1 then
					plate:Hide()
				else
					plate:SetColorTexture(r, g, b, 1)
					plate:ClearAllPoints()
					if lines > 1 then
						plate:SetPoint("LEFT", fs, "TOPLEFT", at - MARK.PAD, -(line + 0.5) * tall)
					else
						plate:SetPoint("LEFT", fs, "LEFT", at - MARK.PAD, 0)
					end
					plate:SetSize(word + MARK.PAD * 2, size + MARK.TALL)
					plate:Show()
				end
			end
		end
		for i = n + 1, #plates do plates[i]:Hide() end
	end
	function marks:Hide()
		for i = 1, #plates do plates[i]:Hide() end
	end
	return marks
end
