-- Shared widgets: role icons, chips, steppers, segments, pooled lists, menus.
-- Colors go through UI.Paint / UI.Ink with palette tables (by reference) so
-- they follow a theme change. Class colors are set directly and don't.

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local UI = Shy.UI
local C = UI.colors
local W = {}
ns.W = W

-- A palette color at another alpha, as a function so it follows theme changes.
function W.Alpha(color, alpha)
	return function() return color[1], color[2], color[3], alpha end
end

-- The Group Finder's own role icons, small and large.
local ROLE_ATLAS = {
	tank = "groupfinder-icon-role-micro-tank",
	healer = "groupfinder-icon-role-micro-heal",
	dps = "groupfinder-icon-role-micro-dps",
}
local LARGE_ROLE_ATLAS = {
	tank = "groupfinder-icon-role-large-tank",
	healer = "groupfinder-icon-role-large-heal",
	dps = "groupfinder-icon-role-large-dps",
}

-- "1 group", "3 players"
function W.Plural(n, one, many)
	return n == 1 and ("1 " .. one) or (n .. " " .. (many or (one .. "s")))
end

function W.ClassColor(class)
	local c = class and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.85, 0.85, 0.85   -- class unknown
end

-- "23 Warrior", "Warrior", "23" or "" from whatever is known.
function W.LevelClass(level, class)
	local name = class and LOCALIZED_CLASS_NAMES_MALE[class]
	if level and name then return level .. " " .. name end
	return name or (level and tostring(level)) or ""
end

-- Player names: a font family that covers every alphabet.
function W.Name(parent, size)
	return UI.Words(parent, UI.NameFont(size), nil, { wrap = false })
end

-- A menu of the words in braces, each with what it says right now; a click
-- puts the word into `box` (an edit box) at the cursor and tells `set`.
-- W.WordsWriter gives the menu for a W.MenuButton; W.WordsMenu opens it on an owner.
function W.WordsWriter(box, whisper, set)
	return function(root)
		root:CreateTitle("Words in braces")
		for _, word in ipairs(ns.Run.Legend(whisper)) do
			-- The word, what it is for under it, and what it says right now at the right.
			local entry = root:CreateButton("{" .. word.key .. "}", function()
				-- Inserted at the cursor, or at the end when the box isn't being edited.
				if not box:HasFocus() then box:SetCursorPosition(#box:GetText()) end
				box:Insert("{" .. word.key .. "}")
				set((box:GetText():gsub("[\r\n]+", " ")))
			end)
			entry:SetSub(word.what)
			if word.value ~= "" then entry:SetDetail(word.value) end
		end
	end
end

function W.WordsMenu(owner, box, whisper, set)
	Shy.UI.DropMenu(owner, W.WordsWriter(box, whisper, set))
end

-- The legend of words in braces as a hover on `frame`: each word and what it
-- says right now (what it would, dim, when there is nothing to say yet).
function W.Legend(frame, whisper, text)
	frame:HookScript("OnEnter", function(self)
		local rows = {}
		for _, word in ipairs(ns.Run.Legend(whisper)) do
			local live = word.value ~= ""
			rows[#rows + 1] = { text = "{" .. word.key .. "}", color = C.head, right = live and word.value or word.what,
				rightColor = live and C.text or C.dim }
		end
		UI.Tip(self, "Words in braces", text or "Type anything; these fill in when you send.", { side = "RIGHT", width = 320,
			sections = { { rows = rows } } })
	end)
	frame:HookScript("OnLeave", function(self) UI.TipHide(self) end)
end

-- Truncates a row's name so its top line (name at x 12, then info, then
-- something `extra` wide, 8 apart) ends before `limit`.
function W.FitName(name, info, extra, limit)
	local avail = limit - 28 - info:GetStringWidth() - extra
	name:SetWidth(math.max(40, math.min(name:GetStringWidth() + 1, avail)))
end

-- Player-written chat text: Blizzard font objects, which cover every alphabet.
function W.ChatText(parent, color, small)
	local fs = UI.Words(parent, small and GameFontHighlightSmall or ChatFontNormal, color)
	fs:SetJustifyV("TOP")
	return fs
end

-- Tooltip on hover. title and body are strings or functions called on each
-- hover; a nil title shows nothing.
function W.Tip(frame, title, body)
	frame:HookScript("OnEnter", function(self)
		local head, text = title, body
		if type(head) == "function" then head = head(self) end
		if type(text) == "function" then text = text(self) end
		if not head then return end
		UI.Tip(self, head, text, { side = "RIGHT" })
	end)
	frame:HookScript("OnLeave", function(self) UI.TipHide(self) end)
end

-- Role icons

function W.RoleIcon(parent, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	function t:SetRole(role)
		self:SetShown(role ~= nil)
		if role then self:SetAtlas(ROLE_ATLAS[role], false) end
	end
	return t
end

-- The roles you offer, as the Group Finder ticks them: one button per role,
-- those the class can't fill shown dim. A click flips the tick. size: the
-- icon; the large art from 18 up.
function W.RoleToggles(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	local height = size + 10
	f:SetHeight(height)
	f.buttons = {}
	local _, myClass = UnitClass("player")
	local className = LOCALIZED_CLASS_NAMES_MALE[myClass] or ""
	local x = 0
	for i, role in ipairs(D.ROLES) do
		local b = CreateFrame("Button", nil, f)
		b.role, b.can = role, D.CanFill(myClass, role)
		b:SetHeight(height)
		b.icon = b:CreateTexture(nil, "OVERLAY")
		b.icon:SetSize(size, size)
		b.icon:SetPoint("LEFT", 6, 0)
		b.icon:SetAtlas(size >= 18 and LARGE_ROLE_ATLAS[role] or ROLE_ATLAS[role], false)
		b.text = UI.Text(b, D.ROLE_NAME[role], size >= 18 and 14 or 12, true)
		b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
		b:SetWidth(size + b.text:GetStringWidth() + 24)
		b:SetPoint("LEFT", x, 0)
		x = x + b:GetWidth() + 6
		b:SetScript("OnClick", function(self)
			if not self.can then return end
			ns.Listing.ToggleRole(self.role)
		end)
		W.Tip(b, function(self) return self.can and D.ROLE_NAME[self.role] or ("Not for a " .. className) end, function(self)
			if not self.can then return "A " .. className .. " can't " .. (self.role == "tank" and "tank" or "heal") .. "." end
			return "Roles you can play. Ticked ones show on your Group Finder listing; the last one you tick is your role in the group."
		end)
		-- The family's button make; ticked, its primary (Refresh).
		UI.KeyPress(b, { sink = { b.icon } })
		f.buttons[i] = b
	end
	f:SetWidth(x - 6)
	function f:Refresh()
		local roles = ns.Listing.Roles()
		for _, b in ipairs(self.buttons) do
			local on = b.can and roles[b.role]
			b.on = on
			b:SetPrimary(on == true)
			UI.Ink(b.text, on and C.onFill or C.dim)
			b.icon:SetAlpha(on and 1 or 0.55)
			b:SetAlpha(b.can and 1 or 0.4)
		end
	end
	return f
end

function W.Roles(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(size)
	f.icons = {}
	for i = 1, 3 do f.icons[i] = W.RoleIcon(f, size) end
	-- can: function(role) -> bool
	function f:Set(can)
		local n = 0
		for _, role in ipairs(D.ROLES) do
			if can(role) then
				n = n + 1
				local icon = self.icons[n]
				icon:SetRole(role)
				icon:ClearAllPoints()
				icon:SetPoint("LEFT", (n - 1) * (size + 2), 0)
			end
		end
		for i = n + 1, 3 do self.icons[i]:Hide() end
		self:SetWidth(math.max(1, n * (size + 2)))
	end
	return f
end

-- A post's roles. A Group Finder group shows every role with its count
-- ("1/2" and lit while a spot is open); a chat post shows only the roles it
-- named, after "Needs" or "Can".
function W.Seats(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(size)
	f.label = UI.Text(f, "", 11, false, C.dim)
	f.label:SetPoint("LEFT")
	f.slots = {}
	for i, role in ipairs(D.ROLES) do
		f.slots[i] = { role = role, icon = W.RoleIcon(f, size), count = UI.Text(f, "", 12, true) }
	end
	function f:Set(post)
		local counted = post.have ~= nil
		local word = not counted and next(post.roles) and (post.kind == "lfm" and "Needs" or "Can") or ""
		self.label:SetText(word)
		local x = word ~= "" and self.label:GetStringWidth() + 6 or 0
		for _, slot in ipairs(self.slots) do
			local role = slot.role
			local shown = counted or post.roles[role] or false
			slot.icon:SetRole(shown and role or nil)
			slot.count:SetShown(shown and counted)
			if shown then
				slot.icon:ClearAllPoints()
				slot.icon:SetPoint("LEFT", x, 0)
				x = x + size + 3
				local free = counted and post.open[role] > 0
				slot.icon:SetAlpha((not counted or free) and 1 or 0.4)
				if counted then
					local have = post.have[role]
					slot.count:SetText(free and (have .. "/" .. (have + post.open[role])) or have)
					UI.Ink(slot.count, free and C.alert or C.dim)
					slot.count:ClearAllPoints()
					slot.count:SetPoint("LEFT", x, 0)
					x = x + slot.count:GetStringWidth() + 9
				end
			end
		end
		self:SetWidth(math.max(1, x))
	end
	return f
end

-- Chips, buttons, steppers, segments

-- A small label in a palette color over a faint fill of the same color.
function W.Chip(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetHeight(18)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.text = UI.Text(f, "", 11)
	f.text:SetPoint("CENTER")
	-- most: the widest the chip may be; longer words are cut with an ellipsis.
	function f:Set(text, color, most)
		self:SetShown(text ~= nil)
		if not text then return end
		self.text:SetText(text)
		UI.Ink(self.text, color)
		UI.Paint(self.bg, color, 0.16)
		local width = self.text:GetStringWidth() + 14
		if most and width > most then
			width = most
			self.text:SetWidth(most - 14)
			self.text:SetWordWrap(false)
		else
			self.text:SetWidth(0)
		end
		self:SetWidth(width)
	end
	return f
end

-- UI.Button with SetOn (in use or not, and why not); primary: it starts as the primary.
-- font "name": the player's own words, in a font with every alphabet.
function W.Button(parent, text, width, onClick, primary, font)
	local b = UI.Button(parent, text, width, onClick)
	b:SetHeight(22)
	if primary then b:SetPrimary(true) end
	if font == "name" then b.text:SetFontObject(UI.NameFont(12)) end
	function b:SetOn(on, why)
		self:SetUsable(on, why)
	end
	return b
end

-- The core's menu button, plated as every button here: write(root) builds the
-- menu, which opens at least as wide as the button.
function W.MenuButton(parent, text, width, write, tip)
	local b = UI.MenuButton(parent, { write = write, width = width, height = 22, plate = true, tip = tip, menu = { fit = true } })
	b:SetLabel(text)
	return b
end

-- [-] value [+]. opts: min, max (the ends dim there), tip. The wheel steps it
-- too; Shift steps by five.
function W.Stepper(parent, get, change, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(64, 20)
	local function Step(delta)
		change(IsShiftKeyDown() and delta * 5 or delta)
	end
	local minus = W.Button(f, "-", 18, function() Step(-1) end)
	minus:SetHeight(18)
	minus:SetPoint("LEFT")
	local plus = W.Button(f, "+", 18, function() Step(1) end)
	plus:SetHeight(18)
	plus:SetPoint("RIGHT")
	f.value = UI.Text(f, "", 14, true)
	f.value:SetPoint("CENTER")
	f:EnableMouse(true)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta) Step(delta > 0 and 1 or -1) end)
	if opts.tip then W.Tip(f, opts.tip[1], opts.tip[2]) end
	function f:Refresh()
		local v = get()
		self.value:SetText(v)
		minus:SetOn(opts.min == nil or v > opts.min)
		plus:SetOn(opts.max == nil or v < opts.max)
	end
	return f
end

-- Segmented control: the family's one (UI.Segments). onSelect(index)
function W.Segments(parent, labels, onSelect)
	return UI.Segments(parent, labels, onSelect)
end

-- A box of several lines for a wording: live `set` on every keystroke, Enter
-- and Esc leave it (Esc puts the saved text back). Line breaks are spaces.
-- The height of one line of the text font, measured, so boxes of lines fit.
local lineHeight
local function LineHeight()
	if not lineHeight then
		local fs = UIParent:CreateFontString(nil, "OVERLAY")
		fs:SetFontObject(GameFontHighlightSmall)
		fs:SetText("Ag")
		lineHeight = math.ceil(math.max(fs:GetLineHeight(), fs:GetStringHeight(), 10)) + 1
		fs:Hide()
	end
	return lineHeight
end

-- A multi-line edit box grows with its text: the frame around it starts
-- `lines.min` lines tall, grows to `lines.max`, then scrolls. Returns that
-- frame, with the box as `.box`; the frame's height changes with the text.
function W.TextBox(parent, width, lines, get, set)
	local f = UI.ScrollArea(parent, width, 10)
	UI.Skin(f)
	f:EnableMouse(true)
	local box = CreateFrame("EditBox", nil, f.content)
	f.box = box
	box:SetPoint("TOPLEFT")
	box:SetWidth(width - 18)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetTextInsets(8, 6, 6, 6)
	box:SetMaxLetters(200)
	local line = LineHeight()
	local least, most = lines.min * line + 12, lines.max * line + 12
	f:SetHeight(least)
	f.content:SetHeight(least)
	-- A click on the empty part of the frame edits too.
	f:SetScript("OnMouseDown", function() box:SetFocus() end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	-- Esc puts back what was there when editing began; every keystroke since went to `set`.
	box:SetScript("OnEscapePressed", function(self)
		local was = self.was or get() or ""
		self:SetText(was)
		if was ~= (get() or "") then set(was) end
		self:ClearFocus()
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self.was = self:GetText()
		UI.SetBorder(f, C.hot)
	end)
	box:SetScript("OnEditFocusLost", function() UI.SetBorder(f, C.border) end)
	box:SetScript("OnTextChanged", function(self, userInput)
		local need = self:GetHeight()
		f:SetHeight(math.max(least, math.min(most, need)))
		f.content:SetHeight(math.max(f:GetHeight(), need))
		f:Update()
		if userInput then set((self:GetText():gsub("[\r\n]+", " "))) end
	end)
	-- Keeps the cursor in view while typing.
	box:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, view = -y, f:GetHeight()
		local now = f:At()
		if top < now then
			f:SetVerticalScroll(top)
		elseif top + h > now + view then
			f:SetVerticalScroll(top + h - view)
		end
		f:Update()
	end)
	function f:Refresh()
		if not box:HasFocus() then box:SetText(get() or "") end
	end
	return f
end

-- Text to read, every line of it, in color where asked: `lines.min` lines
-- tall at least, `lines.max` at most, scrolling past that. f:SetText(text).
function W.TextView(parent, width, lines, color)
	local f = UI.ScrollArea(parent, width, 10)
	local fs = UI.Words(f.content, GameFontHighlightSmall, color)
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetNonSpaceWrap(true)   -- a run of letters with no space in it breaks too, as it does in an edit box
	fs:SetPoint("TOPLEFT", 2, -2)
	-- A width and no height: the text takes every line it needs (as the Replies bubbles do), and
	-- the frame clips what is past its own height.
	fs:SetWidth(width - 18)
	f.text = fs
	local line = LineHeight()
	local least, most = lines.min * line + 4, lines.max * line + 4
	f:SetHeight(least)
	function f:SetText(text)
		fs:SetText(text)
		local need = math.ceil(fs:GetStringHeight()) + 4
		self:SetHeight(math.max(least, math.min(most, need)))
		self.content:SetHeight(math.max(self:GetHeight(), need))
		self:Update()
	end
	return f
end

-- One-line chat box: Enter sends and keeps focus, Esc clears focus.
function W.ChatInput(parent, width, onSend, placeholderText)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(width, 24)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetTextInsets(8, 8, 0, 0)
	box:SetMaxLetters(255)
	UI.Skin(box)
	local placeholder = UI.Text(box, placeholderText or "", nil, false, C.dim)
	placeholder:SetPoint("LEFT", 8, 0)
	function box:Send()
		local text = strtrim(self:GetText())
		if text == "" then return end
		self:SetText("")
		onSend(text)
	end
	box:SetScript("OnEnterPressed", box.Send)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) end)
	box:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	box:SetScript("OnTextChanged", function(self) placeholder:SetShown(self:GetText() == "") end)
	return box
end

-- Pooled list: rows are created once and reused.
--   list:SetData(items)     create(content) -> row ; update(row, item, index)

function W.List(parent, width, height, rowHeight, create, update)
	local scroll = UI.ScrollArea(parent, width, height)
	local rows = {}
	function scroll:SetData(items)
		local content = self.content
		for i, item in ipairs(items) do
			local row = rows[i]
			if not row then
				row = create(content)
				row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
				row:SetSize(width - 14, rowHeight - 2)
				rows[i] = row
			end
			row.item = item
			update(row, item, i)
			row:Show()
		end
		for i = #items + 1, #rows do rows[i]:Hide() end
		content:SetHeight(math.max(1, #items * rowHeight))
		self:Update()
	end
	return scroll
end

-- List row: hover border, a left edge for the class color (row.edge, set by
-- the caller) and an accent fill when selected.
local ROW_SELECTED = W.Alpha(C.fill, 0.5)

function W.Row(parent)
	local row = CreateFrame("Button", nil, parent)
	UI.Skin(row, C.row, C.rowEdge)
	row.edge = row:CreateTexture(nil, "ARTWORK")
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(3)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnEnter", function(self) UI.SetBorder(self, C.hot) end)
	row:SetScript("OnLeave", function(self) UI.SetBorder(self, C.rowEdge) end)
	function row:SetSelected(on)
		self.selected = on
		UI.SetFill(self, on and ROW_SELECTED or C.row)
	end
	return row
end

-- "just now", "2m ago"
function W.When(t)
	local ago = ns.Ago(t)
	return ago == "now" and "just now" or (ago .. " ago")
end

-- Where a post came from: "in LookingForGroup", "Group Finder  ·  Relaxed".
function W.Source(post)
	if not post.finder then return "in " .. post.channel end
	local style = post.style and ns.Listing.StyleName(post.style) or ""
	return style ~= "" and ("Group Finder  \194\183  " .. style) or "Group Finder"
end

function W.RoleWords(roles)
	local words = {}
	for _, r in ipairs(D.ROLES) do
		if roles[r] then words[#words + 1] = D.ROLE_WORD[r] end
	end
	return table.concat(words, ", ")
end

-- A post's hover: what it is, what it's for, who's in it, what it said.
-- Returns the title and the options for UI.Tip. hints: the mouse hints to show.
function W.PostDetails(post, hints)
	local Search = ns.Search
	local group = post.kind == "lfm"
	local who = W.LevelClass(post.level, post.class)
	local sections = {}
	local function Section(title, rows)
		if #rows > 0 then sections[#sections + 1] = { title = title, rows = rows } end
	end

	local what = {}
	if group then
		what[1] = { glyph = "star", tint = C.hot, color = C.hot, text = post.count
			and ("A group of " .. post.count .. (post.size and post.size > 0 and (" out of " .. post.size) or "")) or "A group looking for members" }
	else
		what[1] = { glyph = "star", tint = C.good, color = C.good, text = "A player looking for a group" }
	end
	if post.area then what[2] = { glyph = "go", text = post.area, quiet = true } end
	Section(nil, what)

	local wants = {}
	for _, key in ipairs(post.keys) do
		local d = D.byKey[key]
		if d then
			local right = d.kind == "raid" and (d.size .. " players") or d.kind == "custom" and "" or (d.min .. "-" .. d.max)
			wants[#wants + 1] = { text = d.name, right = right, color = C.head, rightColor = C.dim }
		end
	end
	if next(post.roles) then
		wants[#wants + 1] = { text = (group and "Needs: " or "Can be: ") .. W.RoleWords(post.roles), color = C.alert }
	elseif post.have then
		wants[#wants + 1] = { text = "No open spots", quiet = true }
	end
	Section("For", wants)

	if group and post.finder then
		local inside = {}
		for _, m in ipairs(Search.Members(post)) do
			local detail = W.LevelClass(m.level, m.class)
			if m.role then detail = detail .. "  \194\183  " .. D.ROLE_WORD[m.role] end
			inside[#inside + 1] = { text = m.leader and (m.name .. "  (leader)") or m.name, right = detail, color = { W.ClassColor(m.class) } }
		end
		local defeated = Search.Defeated(post)
		if #defeated > 0 then
			inside[#inside + 1] = { glyph = "kill", tint = C.alert, color = C.alert, text = "Already defeated: " .. table.concat(defeated, ", ") }
		end
		Section("In the group", inside)
	end

	local notes = {}
	local style = post.style and ns.Listing.StyleName(post.style) or ""
	if style ~= "" then notes[#notes + 1] = "Style: " .. style end
	if post.friendly then notes[#notes + 1] = "New players welcome" end
	if post.guild then notes[#notes + 1] = "A guildmate is in it" end
	if post.friends then notes[#notes + 1] = "A friend is in it" end
	local good = {}
	for _, note in ipairs(notes) do good[#good + 1] = { glyph = "check", tint = C.good, color = C.good, text = note } end
	Section(nil, good)

	-- The text, then its source.
	local words = {}
	if post.text ~= "" then words[#words + 1] = { glyph = "talk", text = "\"" .. post.text .. "\"" } end
	words[#words + 1] = { text = W.Source(post) .. ", " .. W.When(post.last), quiet = true, indent = #words > 0 and 2 or 0 }
	Section(group and "Their listing" or "Their post", words)

	return post.name, { side = "LEFT", width = 262, color = { W.ClassColor(post.class) }, note = who ~= "" and who or nil,
		sections = sections, hints = hints }
end

-- Right-click menu for a person. info: optional class, level, guid, lang.

function W.PersonMenu(owner, name, info)
	local p = ns.People.Get(name)
	Shy.UI.ContextMenu(owner, function(root)
		root:CreateTitle(name)
		root:CreateButton("Whisper", function()
			-- Registered first, so their reply is kept in Replies.
			ns.People.Ensure(name, info)
			ChatFrameUtil.SendTell(name)
		end)
		root:CreateButton("Invite", function() ns.People.Invite(name) end)
		if p and #p.thread > 0 then
			root:CreateButton("Open conversation", function() ns.Window.ShowThread(name) end)
		end
		if ns.Run.Get() and p and p.status ~= "found" and p.status ~= "joined" then
			root:CreateButton("Ask again", function() ns.People.Ask(p, p.role) end)
		end
		root:CreateDivider()
		root:CreateButton("Not interested", function() ns.People.Pass(name) end)
		if ns.People.IsIgnored(name) then
			root:CreateButton("Stop ignoring", function() ns.People.Unignore(name) end)
		else
			root:CreateButton("Ignore", function() ns.People.Ignore(name) end)
		end
		if p and #p.thread > 0 then
			root:CreateButton("Clear conversation", function() ns.People.Forget(name) end)
		end
	end)
end

-- "Deadmines  17-26", "Molten Core  40 players", "Westfall  8-24"
function W.DungeonLabel(d)
	local detail = d.kind == "raid" and (d.size .. " players") or (d.min .. "-" .. d.max)
	return d.name .. "  |cff888888" .. detail .. "|r"
end

-- The run menu: what's at your level, then everything by kind, then a run of your own.
function W.RunWriter(root)
	local level = UnitLevel("player")
	for _, d in ipairs(D.ForLevel(level)) do
		if d.kind ~= "zone" then root:CreateButton(W.DungeonLabel(d), function() ns.Run.Start(d.key) end) end
	end
	local menus = {}
	for _, kind in ipairs({ "dungeon", "raid", "zone" }) do
		local all = D.OfKind(kind)
		if #all > 0 then
			local menu = root:CreateButton(kind == "dungeon" and "All dungeons" or D.KindName(kind))
			menu:SetScrollMode(420)
			menus[kind] = menu
		end
	end
	for _, d in ipairs(D.list) do
		local menu = menus[d.kind]
		if menu then menu:CreateButton(W.DungeonLabel(d), function() ns.Run.Start(d.key) end) end
	end
	root:CreateButton("Custom...", function() ns.Run.Start("custom", "Group") end)
end

function W.RunMenu(owner)
	Shy.UI.ContextMenu(owner, function(root)
		root:CreateTitle("What are you running?")
		W.RunWriter(root)
	end)
end
