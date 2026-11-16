-- Shy.Shop: the shared parts of a window of our own standing in a game window's place (ShySkin's vendor, trainer,
-- mailbox, professions, social and guild windows, ShyAuction's auction house) or laying one out again (the spellbook,
-- the talents). How they stay safe:
--   * Blizzard's window (MerchantFrame, ClassTrainerFrame, MailFrame) stays the UI panel, with all its
--     scripts and events. Ours is a window that is its child, so it opens and closes with it.
--   * Blizzard's children are reparented to a hidden frame the size of the window ("attic").
--     Blizzard keeps showing and anchoring them there; nothing is hidden, shown or re-anchored
--     by us. Shop.BringBack restores each one's parent, level and strata.
--   * The window may be resized (Shop.Size / Shop.Unsize). The panel manager reads the width itself
--     (GetUIPanelWidth); it is never called from here.
--   * No field is written on a Blizzard frame. Blizzard's buy code is handed a row of ours that
--     carries the fields its item buttons do.
--
--   Shop.PutAway(window, ...)       -- Blizzard frames into the attic (nil and repeats are skipped)
--   Shop.AtticOf(window)            -- the attic frame, once made
--   Shop.BringBack(window)
--   Shop.Empty(kit, window, ours) / Shop.Refill(window)   -- a game window emptied for ours, and given back
--   Shop.Veil(kit, window, ours) / Shop.Unveil(window)    -- the same for a window whose pieces need their parent (the
--                                   -- auction house's): hidden where they stand, never moved
--   Shop.Size(window, w, h) / Shop.Unsize(window)
--   Shop.Desk(def)                  -- a window of ours in a game window's place for someone you deal with, in the
--                                   -- quest giver's window's make, with its opening (see there)
--   Shop.Text(parent, font, color)  -- a one-line font string
--   Shop.Upper(text)                -- upper case, A to Z only
--   Shop.Money(copper)              -- coin text at the list's font size
--   Shop.Button(parent, look, onClick)   -- look: "go" (gold, the primary action), "accent", or nil
--       button:Say(text)   button:SetOff(off)   button.tip = { title, text }
--   Shop.Chip(parent, label, onClick)    -- a pill of the family's make (a filter); chip:Say(text), chip:SetOn(on)
--   Shop.Search(parent, hint, onText)    -- a search box: the glass, a hint while empty, onText(text) as it changes
--   Shop.Stepper(parent, opts)      -- a count you step or type
--   Shop.Kicker(parent)             -- a section's name in small capitals over a hairline
--   Shop.Lines(holder, opts)        -- a game tooltip's lines laid down a holder
--   Shop.Rule(parent)               -- a hairline
--   Shop.Later(fn)                  -- runs fn once, next frame
--   Shop.Try(module, draw, say)     -- draws the layout; on error restores Blizzard's window for the session and
--                                   -- says so through say(text) (the owner's chat line)

local UI = Shy.UI
local Theme = Shy.Theme
local C = UI.colors

local Shop = {}
Shy.Shop = Shop

Shop.ICON = { 0.08, 0.92, 0.08, 0.92 }   -- trims an icon's dark rim

local weak = { __mode = "k" }

-- The attic

local attics = setmetatable({}, weak)   -- window -> { frame, away = { piece -> { parent, level, strata } } }

local function Attic(window)
	local attic = attics[window]
	if not attic then
		attic = { frame = CreateFrame("Frame", nil, window), away = {} }
		-- The window's size, so a point Blizzard anchors "to its parent" lands where it would have.
		attic.frame:SetAllPoints(window)
		attic.frame:Hide()
		attics[window] = attic
	end
	return attic
end

function Shop.PutAway(window, ...)
	local attic = Attic(window)
	for i = 1, select("#", ...) do
		local piece = select(i, ...)
		if piece and not attic.away[piece] then
			local parent = piece:GetParent()
			-- Level relative to the parent's: the window and its children are raised on click.
			attic.away[piece] = { parent = parent, level = piece:GetFrameLevel() - parent:GetFrameLevel(), strata = piece:GetFrameStrata() }
			piece:SetParent(attic.frame)
		end
	end
end

function Shop.BringBack(window)
	local attic = attics[window]
	if not attic then return end
	for piece, was in pairs(attic.away) do
		piece:SetParent(was.parent)
		piece:SetFrameLevel(math.max(0, was.parent:GetFrameLevel() + was.level))
		if piece:GetFrameStrata() ~= was.strata then piece:SetFrameStrata(was.strata) end
		for i = 1, piece:GetNumPoints() do
			local point, to, toPoint, x, y = piece:GetPoint(i)
			if to == attic.frame then piece:SetPoint(point, was.parent, toPoint, x, y) end
		end
	end
	wipe(attic.away)
end

-- The attic itself (a child of the window): what a caller putting every child away must leave where it is.
function Shop.AtticOf(window)
	return attics[window] and attics[window].frame or nil
end

-- True while the piece is in the attic.
function Shop.IsAway(window, piece)
	local attic = attics[window]
	return attic ~= nil and attic.away[piece] ~= nil
end

-- The window

local sizes = setmetatable({}, weak)   -- window -> Blizzard's size

function Shop.Size(window, width, height)
	if not sizes[window] then sizes[window] = { window:GetSize() } end
	local w, h = window:GetSize()
	if math.abs(w - width) < 0.5 and math.abs(h - height) < 0.5 then return end
	window:SetSize(width, height)
end

function Shop.Unsize(window)
	local was = sizes[window]
	if not was then return end
	sizes[window] = nil
	window:SetSize(was[1], was[2])
end

-- Text

function Shop.Text(parent, font, color)
	return UI.Words(parent, font, color, { wrap = false })
end

-- A to Z only: string.upper follows the machine's locale and breaks UTF-8 letters.
function Shop.Upper(text)
	return (text:gsub("[a-z]", string.upper))
end

function Shop.Money(copper)
	return UI.Money(copper, nil, 10)
end

-- A button

-- A button of the family's make (UI.KeyPress). "go", the primary action, is in the merchant's gold (its face
-- deep, its edge and words gold); "accent", the one the shop suggests, wears an edge in your color at rest.
function Shop.Button(parent, look, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(60, 18)
	b.look = look
	b.label = Shop.Text(b, UI.NameFont(11), C.text)
	b.label:SetPoint("CENTER", 0, 0)
	b:SetScript("OnClick", function(self)
		if self.off then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(self)
	end)
	b:SetScript("OnEnter", function(self)
		if self.tip then UI.Tip(self, self.tip[1], self.tip[2], { side = "TOP" }) end
	end)
	b:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	UI.KeyPress(b, { tone = look == "go" and C.alert or nil, words = b.label, sink = { b.label } })
	if look == "accent" then UI.SetBorder(b, Theme.Accent) end

	-- Sets the text and sizes the button to it.
	function b:Say(text)
		self.label:SetText(text)
		self:SetWidth(math.ceil(self.label:GetStringWidth()) + 14)
	end
	-- Dims the button and ignores clicks; the mouse stays enabled for its tooltip.
	function b:SetOff(off)
		self.off = off and true or false
		self.dimmed = self.off
		self:SetAlpha(self.off and 0.4 or 1)
		self:SetOn(false)   -- paints it again
	end
	return b
end

-- A chip: a pill holding a word or two, lit while on (a filter); sized to its words.
function Shop.Chip(parent, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(18)
	b.text = Shop.Text(b, UI.NameFont(10), C.text)
	b.text:SetPoint("CENTER", 0, 0)
	function b:Say(text)
		self.text:SetText(text)
		self:SetWidth(math.ceil(self.text:GetStringWidth()) + 18)
	end
	b:Say(label or "")
	UI.KeyPress(b, { words = b.text, sink = { b.text } })
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(self)
	end)
	return b
end

-- A search box: the glass at its left, a hint while it is empty, Escape clears it. onText(text) as it changes,
-- trimmed.
function Shop.Search(parent, hint, onText)
	local box = CreateFrame("EditBox", nil, parent)
	box:SetSize(150, UI.HEAD.window.control)
	box:SetAutoFocus(false)
	box:SetFontObject(UI.TextFont(11))
	box:SetTextInsets(19, 4, 0, 0)
	box:SetMaxLetters(40)
	UI.Skin(box, C.bg, C.border)
	box.glass = box:CreateTexture(nil, "OVERLAY")
	box.glass:SetSize(10, 10)
	box.glass:SetPoint("LEFT", 5, 0)
	box.glass:SetAtlas("common-search-magnifyingglass")
	box.glass:SetDesaturated(true)
	UI.Tint(box.glass, C.dim)
	box.hint = Shop.Text(box, UI.TextFont(11), C.dim)
	box.hint:SetPoint("LEFT", 19, 0)
	box.hint:SetText(hint)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) end)
	box:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	box:SetScript("OnTextChanged", function(self)
		local text = strtrim(self:GetText() or "")
		self.hint:SetShown(text == "")
		onText(text)
	end)
	return box
end

-- Lines

function Shop.Rule(parent)
	local rule = parent:CreateTexture(nil, "ARTWORK")
	rule:SetHeight(1)
	UI.Paint(rule, C.border, 0.9)
	return rule
end

-- Refreshing

-- With Blizzard's children in the attic, an error in our layout would leave an unusable window.
-- On error the module is off for the session and Blizzard's window is restored; the saved
-- setting is untouched, so the next load tries again.
function Shop.Try(module, draw, say)
	if module.failed then return end
	if xpcall(draw, geterrorhandler()) then return end
	module.failed = true
	module.IsOn = function() return false end
	module:Refresh()
	if say then say(module.title:lower() .. ": hit an error, so this window is back to default until you reload.") end
end

-- Update events arrive many times a frame (every bag slot of a sale): lay out once, next frame.
function Shop.Later(fn)
	local waiting = false
	local function Run()
		waiting = false
		fn()
	end
	return function()
		if waiting then return end
		waiting = true
		C_Timer.After(0, Run)
	end
end

-- A kicker: a section's name in small capitals over a hairline that runs out to the right, a few quiet words after it.
--   local k = Shop.Kicker(parent)   k:Say(word, aside, color)
function Shop.Kicker(parent)
	local k = CreateFrame("Frame", nil, parent)
	k:SetHeight(18)
	k.text = Shop.Text(k, UI.NameFont(9), C.dim)
	k.text:SetPoint("TOPLEFT")
	k.aside = Shop.Text(k, UI.NameFont(10), C.dim)
	k.aside:SetPoint("LEFT", k.text, "RIGHT", 6, 0)
	k.rule = k:CreateTexture(nil, "ARTWORK")
	k.rule:SetPoint("TOPLEFT", 0, -15)
	k.rule:SetPoint("TOPRIGHT", 0, -15)
	k.rule:SetHeight(1)
	k.rule:SetColorTexture(1, 1, 1, 1)
	function k:Say(word, aside, color)
		self.text:SetText(Shop.Upper(word))
		self.aside:SetText(aside or "")
		if color and color.GetRGB then self.aside:SetTextColor(color:GetRGB()) else UI.Ink(self.aside, color or C.dim) end
		local e = C.border
		self.rule:SetGradient("HORIZONTAL", CreateColor(e[1], e[2], e[3], 1), CreateColor(e[1], e[2], e[3], 0))
	end
	return k
end

-- A count you step or type: one plate holding a step at either end of the number and, with opts.max, a word past
-- a hairline at its right end that takes the count to its most. Digits only, read as you type; Enter or a click
-- away settles it within its bounds and onto a whole step, Escape puts back what was there.
--   local s = Shop.Stepper(parent, { width = 128, height = 22, max = "Max", onChange = function(n) end })
--   s:Set(n, least, most, step)   -- the count, its bounds, and what a press adds (a typed number is cut down to one)
--   s:Get()                       s.box: the edit box; s.less, s.more, s.max: its keys (.off while one can't go on)
function Shop.Stepper(parent, opts)
	opts = opts or {}
	local tall = opts.height or 22
	local s = UI.KeyPlate(CreateFrame("Button", nil, parent))
	s:SetSize(opts.width or 96, tall)
	s.n, s.least, s.most, s.step = 1, 1, 999, 1
	local STEP = 26                      -- a step's width
	local WORD = opts.max and 40 or 0    -- the word's
	local function Within(n)
		n = math.max(s.least, math.min(s.most, n))
		if s.step > 1 then n = math.max(s.least, math.floor(n / s.step) * s.step) end
		return n
	end
	local function Show()
		if not s.box:HasFocus() then s.box:SetText(tostring(s.n)) end
		s.less:SetOff(s.n <= s.least)
		s.more:SetOff(s.n >= s.most)
		if s.max then s.max:SetOff(s.n >= s.most) end
	end
	local function Take(n)
		if n == s.n then return Show() end
		s.n = n
		Show()
		if opts.onChange then opts.onChange(n) end
	end
	-- A key on the plate: its sign or word alone, brighter under the mouse, faint while it can't go on. to(): the
	-- count a press asks for.
	local function Key(sign, size, wide, side, x, to)
		local b = CreateFrame("Button", nil, s)
		b:SetSize(wide, tall)
		b:SetPoint(side, x, 0)
		b.text = Shop.Text(b, UI.NameFont(size), C.dim)
		b.text:SetPoint("CENTER", 0, size > 12 and 1 or 0)
		b.text:SetText(sign)
		b:SetScript("OnClick", function(self)
			if self.off then return end
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			s.box:ClearFocus()
			Take(Within(to()))
		end)
		b:SetScript("OnEnter", function(self) if not self.off then UI.Ink(self.text, C.hot) end end)
		b:SetScript("OnLeave", function(self) UI.Ink(self.text, self.off and C.border or C.dim) end)
		function b:SetOff(off)
			self.off = off
			UI.Ink(self.text, off and C.border or C.dim)
		end
		return b
	end
	s.less = Key("\226\136\146", 15, STEP, "LEFT", 0, function() return s.n - s.step end)
	s.more = Key("+", 15, STEP, "RIGHT", -WORD, function() return s.n + s.step end)
	if opts.max then
		s.max = Key(opts.max, 11, WORD, "RIGHT", 0, function() return s.most end)
		s.rule = s:CreateTexture(nil, "OVERLAY")
		s.rule:SetSize(1, tall - 10)
		s.rule:SetPoint("RIGHT", -WORD, 0)
		UI.Paint(s.rule, C.border, 0.9)
	end
	local box = CreateFrame("EditBox", nil, s)
	box:SetPoint("TOPLEFT", STEP, 0)
	box:SetPoint("BOTTOMRIGHT", -(STEP + WORD), 0)
	box:SetFontObject(UI.NameFont(13))
	box:SetShadowOffset(1, -1)
	box:SetShadowColor(0, 0, 0, 1)
	UI.Ink(box, C.head)
	box:SetJustifyH("CENTER")
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(4)
	box:SetScript("OnEditFocusGained", function(self)
		self.was = s.n
		self:HighlightText()
		s:SetTone(Theme.Accent, true)
	end)
	box:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		s:SetTone(Theme.Accent, false)
		Take(Within(s.n))
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self)
		local was = self.was or s.n
		self:ClearFocus()
		Take(Within(was))
	end)
	box:SetScript("OnTextChanged", function(self, typed)
		if not typed then return end
		local n = tonumber(self:GetText())
		if n and n >= 1 then
			n = math.min(s.most, n)
			if n ~= s.n then
				s.n = n
				if opts.onChange then opts.onChange(n) end
			end
		end
	end)
	s.box = box

	function s:Set(n, least, most, step)
		self.step = math.max(1, step or 1)
		self.least = math.max(1, least or 1)
		self.most = math.max(self.least, most or 999)
		self.n = Within(n or self.least)
		Show()
	end
	function s:Get() return self.n end
	s:Set(1)
	return s
end

-- A game tooltip's lines laid down a holder as the game colors them: one alone wraps to the holder's width (a Use:
-- line runs long), one with words at its right stays a line, cut short of them.
--   local lines = Shop.Lines(holder, { font = 12, pad = 10, gap = 2 })
--   local tall, shown = lines:Lay(data, from, width, room)   -- data: C_TooltipInfo's table; from: the first line laid
--                                         -- (2: past the name); room: the most height; tall: what they took
function Shop.Lines(holder, opts)
	opts = opts or {}
	local font, pad, gap = opts.font or 12, opts.pad or 10, opts.gap or 2
	local lines = { rows = {} }
	local function Row(i)
		local row = lines.rows[i]
		if not row then
			row = { left = Shop.Text(holder, UI.TextFont(font), C.text), right = Shop.Text(holder, UI.TextFont(font), C.text) }
			row.right:SetJustifyH("RIGHT")
			row.left:SetSpacing(2)
			lines.rows[i] = row
		end
		return row
	end
	function lines:Lay(data, from, width, room)
		local list = (type(data) == "table" and not issecretvalue(data) and data.lines) or {}
		room = room or 4000
		local used, y = 0, pad
		local inner = width - 2 * pad
		local line = font + 3
		for i = from or 1, #list do
			local said = list[i]
			local left = said and said.leftText
			if type(left) == "string" and not issecretvalue(left) and left:find("%S") and y + line <= room then
				used = used + 1
				local row = Row(used)
				local right = said.rightText
				right = type(right) == "string" and not issecretvalue(right) and right or ""
				row.left:SetWidth(right ~= "" and math.floor(inner * 0.65) or inner)
				row.left:SetWordWrap(right == "")
				row.left:SetMaxLines(right == "" and math.max(1, math.floor((room - y) / line)) or 1)
				row.left:SetText(left)
				row.left:ClearAllPoints()
				row.left:SetPoint("TOPLEFT", holder, "TOPLEFT", pad, -y)
				row.right:SetText(right)
				row.right:ClearAllPoints()
				row.right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -pad, -y)
				local color = said.leftColor
				if type(color) == "table" and color.GetRGB then row.left:SetTextColor(color:GetRGB()) else UI.Ink(row.left, C.text) end
				color = said.rightColor
				if type(color) == "table" and color.GetRGB then row.right:SetTextColor(color:GetRGB()) else UI.Ink(row.right, C.text) end
				row.left:Show()
				row.right:Show()
				local tall = row.left:GetStringHeight()
				tall = (issecretvalue(tall) or not tall) and line or math.ceil(tall)
				y = y + math.max(line, tall) + gap
			end
		end
		for i = used + 1, #self.rows do
			self.rows[i].left:Hide()
			self.rows[i].right:Hide()
		end
		return used > 0 and y + pad - gap or 0, used
	end
	return lines
end

-- A game window emptied for a window of ours to stand in: every child of it but `ours` in the attic, the art drawn
-- on it hidden through the kit (which puts it back), no mouse. Shop.Refill gives it all back.
local mice = setmetatable({}, weak)   -- window -> { mouse, wheel } as it was

function Shop.Empty(kit, window, ours)
	local attic = Shop.AtticOf(window)
	local kids = {}
	for _, kid in ipairs({ window:GetChildren() }) do
		if kid ~= ours and kid ~= attic and not kid:IsForbidden() then kids[#kids + 1] = kid end
	end
	Shop.PutAway(window, unpack(kids))
	for _, region in ipairs({ window:GetRegions() }) do kit:Hide(region) end
	if not mice[window] then mice[window] = { window:IsMouseEnabled(), window:IsMouseWheelEnabled() } end
	window:EnableMouse(false)
	window:EnableMouseWheel(false)
end

function Shop.Refill(window)
	Shop.BringBack(window)
	local was = mice[window]
	if not was then return end
	mice[window] = nil
	window:EnableMouse(was[1])
	window:EnableMouseWheel(was[2])
end

-- A game window veiled for a window of ours, for one whose pieces ask their parent for the window (the auction house's
-- every frame calls GetParent() for it, so none may be moved to the attic): each child but `ours` stays where it is and
-- is hidden, again whenever the game shows it; the art on the window is hidden through the kit; no mouse.
-- Shop.Unveil shows again what it hid and gives the mouse back. Children the game makes later are veiled at the next
-- Shop.Veil (the owner calls it at each opening).
local veiled = setmetatable({}, weak)   -- window -> { on, kids = { kid -> true } }

function Shop.Veil(kit, window, ours)
	local v = veiled[window]
	if not v then
		v = { kids = {}, hid = {} }
		veiled[window] = v
	end
	v.on = true
	for _, kid in ipairs({ window:GetChildren() }) do
		if kid ~= ours and not kid:IsForbidden() then
			if not v.kids[kid] then
				v.kids[kid] = true
				kid:HookScript("OnShow", function(self)
					if v.on then
						v.hid[self] = true
						self:Hide()
					end
				end)
			end
			if kid:IsShown() then
				v.hid[kid] = true
				kid:Hide()
			end
		end
	end
	for _, region in ipairs({ window:GetRegions() }) do kit:Hide(region) end
	if not mice[window] then mice[window] = { window:IsMouseEnabled(), window:IsMouseWheelEnabled() } end
	window:EnableMouse(false)
	window:EnableMouseWheel(false)
end

-- (What it hid is shown again; the window's art comes back with the owner's kit:Restore.)
function Shop.Unveil(window)
	local v = veiled[window]
	if v then
		v.on = false
		for kid in pairs(v.hid) do kid:Show() end
		wipe(v.hid)
	end
	local was = mice[window]
	if not was then return end
	mice[window] = nil
	window:EnableMouse(was[1])
	window:EnableMouseWheel(was[2])
end

-- A desk: a window of our own in a game window's place for someone you deal with (a vendor, a trainer), in the make of
-- the quest giver's window (Shy.Talk.Shell: the band with their face, the foot, the plain ground), so a talk that
-- leads to it turns into it where it stands. It is the game window's child, so it opens and closes with it, and it
-- flows.
--   local desk = Shop.Desk({
--       id = "shyskin.merchant", title = "Vendor",   -- its place in the layout, and its name there
--       frame = function() return MerchantFrame end,  -- the game's window
--       on = function() return M.on end,              -- the module paints
--       try = function(fn) Shop.Try(M, fn) end,       -- how a draw of the module's is run
--       glyph = "coin",                               -- the mark at the face's corner (one of Shy.Hover's)
--       width, height, least = { w, h },              -- its made and least size (the talk window's, unless told)
--       flow = function() end,                        -- dragged to another size
--       close = function() end,                       -- closed by its ×: leave them
--   })
--   desk.box, desk.shell, desk.driver
--   desk:Meet(unit, visit) -> role, place   -- the header names them, the band says who they are (kept in visit.role
--                                           -- once the game's tooltip knows) or where you are; each draw
--
-- The opening. The owner says what moves:
--   desk.Pieces = function() return { region, ... } end   -- what comes a line after a line: each a .line (0 first)
--   desk.Firsts = function() return { region, ... } end   -- what comes with the first line (one that .dims or is
--                                                         -- .off stands at 0.4 while it can't be pressed)
--   desk.risers = { { frame, parent, x, y }, ... }        -- what rises into place: frame's TOPLEFT on parent's
--   desk.Draw = function() end                            -- lays the window out again (at each size of a glide)
--   desk:Begin(unit)   -- a visit begins (the game's window shows). After a talk in a window (Shy.Talk.Yield) this
--                      -- one stands at once where that stood and glides to its own place and size where they
--                      -- differ, only its body and foot arriving; after none it fades in
--   desk:Motion()      -- everything at its moment of the opening, or as it stands once that is over: after each draw
--   desk:Rest()        -- the opening is over or cut short: the visit ended, the module stood down
local Desk = {}
Desk.__index = Desk
-- The window's own fade (after no talk), a piece's fade, the gap from a line to the next and the longest any line
-- waits, how far the risers rise, and the glide from where a talk stood.
Shop.MOVE = { fade = 0.15, cascade = 0.2, stagger = 0.025, most = 0.3, rise = 8, glide = 0.24 }
local MOVE = Shop.MOVE

local function Ease(k)
	k = math.max(0, math.min(1, k))
	return 1 - (1 - k) ^ 3
end

function Shop.Desk(def)
	local WIN = Shy.Talk.WIN
	local frame = def.frame()
	local least = def.least or WIN.least
	local desk = setmetatable({ def = def }, Desk)
	local box = UI.Window({
		id = def.id, title = def.title, width = def.width or WIN.w, height = def.height or WIN.h,
		point = { "TOPLEFT", "TOPLEFT", 16, -116 },
		shown = function() return def.on() == true end,
		head = { size = "window", title = " " },
		grip = { flow = function() if def.flow then def.flow() end end, min = { least[1], least[2] } },
		-- Closed by its ×: they are left, as the game's window leaves them.
		onClose = function()
			if def.on() and frame:IsShown() then def.close() end
		end,
	})
	box:SetParent(frame)
	desk.box = box
	desk.driver = CreateFrame("Frame", nil, box)
	desk.shell = Shy.Talk.Shell(box)
	desk.shell:Sign(nil, nil, def.glyph)
	return desk
end

function Desk:Meet(unit, visit)
	local shell, title = self.shell, self.box.head.title
	local name = UnitName(unit)
	if issecretvalue(name) or name then title:SetText(name) else title:SetText("") end
	if not visit.role then
		local who = shell:Who(unit)   -- asked again until the tooltip's data is there
		if who ~= "" then visit.role = who end
	end
	local role, place = visit.role or "", GetMinimapZoneText() or ""
	shell.role:SetText(role ~= "" and role or place)
	return role, place
end

function Desk:Motion()
	local t = self.motion and self.motion.t
	-- (One that can't be pressed stands dim: a button that says so by .off, or by .dims and the game's own word.)
	local function Dim(piece)
		return (piece.off or (piece.dims and not piece:IsEnabled())) and 0.4 or 1
	end
	for _, piece in ipairs(self.Pieces and self.Pieces() or {}) do
		piece:SetAlpha(Dim(piece) * (t and Ease((t - math.min((piece.line or 0) * MOVE.stagger, MOVE.most)) / MOVE.cascade) or 1))
	end
	local lift = t and -MOVE.rise * (1 - Ease(t / (MOVE.most + MOVE.cascade))) or 0
	for _, riser in ipairs(self.risers or {}) do
		riser[1]:ClearAllPoints()
		riser[1]:SetPoint("TOPLEFT", riser[2], "TOPLEFT", riser[3] or 0, (riser[4] or 0) + lift)
	end
	local first = t and Ease(t / MOVE.cascade) or 1
	for _, piece in ipairs(self.Firsts and self.Firsts() or {}) do piece:SetAlpha(Dim(piece) * first) end
end

function Desk:Rest()
	local glided = self.motion and self.motion.from
	self.motion = nil
	self.driver:SetScript("OnUpdate", nil)
	self.box:SetAlpha(1)
	if glided then Shy.HUD.Apply(self.box) end   -- its own place and size again (the glide ended on them)
	self:Motion()
end

-- The window on its way from where the talk stood to its own place, k of the way there.
function Desk:Glide(k)
	local m, box = self.motion, self.box
	local a, b, s = m.from, m.to, m.scale
	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (a[1] + (b[1] - a[1]) * k) / s, (a[2] + (b[2] - a[2]) * k) / s)
	if m.sized then box:SetSize((a[3] + (b[3] - a[3]) * k) / s, (a[4] + (b[4] - a[4]) * k) / s) end
end

function Desk:Begin(unit)
	local box = self.box
	if self.motion then self:Rest() end
	local left, top, wide, tall = Shy.Talk.Yield()
	local m = { t = 0, fresh = left == nil }
	self.motion = m
	if left then
		local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local l, t, w, h = box:GetLeft(), box:GetTop(), box:GetWidth(), box:GetHeight()
		local known = true
		for _, n in ipairs({ l or false, t or false, w or false, h or false, s or false }) do
			if issecretvalue(n) or type(n) ~= "number" then known = false end
		end
		if known then
			l, t, w, h = l * s, t * s, w * s, h * s
			local sized = math.abs(w - wide) > 0.5 or math.abs(h - tall) > 0.5
			if sized or math.abs(l - left) > 0.5 or math.abs(t - top) > 0.5 then
				m.from, m.to, m.scale, m.sized = { left, top, wide, tall }, { l, t, w, h }, s, sized
				self:Glide(0)
			end
		end
	end
	box:SetAlpha(m.fresh and 0 or 1)
	self.shell:Head(unit)
	self.driver:SetScript("OnUpdate", function(_, elapsed)
		local now = self.motion
		if not now then return self:Rest() end
		now.t = now.t + elapsed
		self.def.try(function()
			local t = now.t
			if now.fresh then box:SetAlpha(Ease(t / MOVE.fade)) end
			if now.from then
				self:Glide(Ease(t / MOVE.glide))
				if now.sized and self.Draw then self.Draw() end   -- laid again at each size on the way
			end
			if t >= MOVE.most + MOVE.cascade and t >= MOVE.glide then self:Rest() else self:Motion() end
		end)
	end)
end
