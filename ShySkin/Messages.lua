-- The game's messages at the top of the screen: quest progress, "Inventory is full", what the server says.
-- Blizzard's line (UIErrorsFrame) is faded and still decides what is said, what repeats and what sounds;
-- every message it takes is drawn here, a cell a line of the column's tray (Shy.Top.Make.Cell), in the drawer
-- under the head at the top's middle.
--
-- Quest progress is a cell whose tab holds what the objective asks for (a bag, crossed swords) and whose body
-- is the meter: its weave fills as the count grows; the same objective again updates its cell where it stands,
-- and once done the tab, the count and the fill turn mint and a gleam crosses it. Anything else is its words
-- alone, a strip down its left edge in the message's meaning: the accent for news, soft red for an error, the
-- server's own color for what it says. New lines come in under the others; a line that goes leaves the others
-- to close up. Nothing is read from a message the game keeps secret: it is drawn as said, as news.
--
--   ns.Messages.Sample(parent)   -- the piece as a picture, the box's size (the screen's preview)
--   ns.Messages.Live()           -- what is up: { { key, text, tone, glyph, have, need, done, sample, row }, ... }

local ADDON, ns = ...
local T = ns.T
local UI, Theme, HUD = Shy.UI, Shy.Theme, Shy.HUD
local C = UI.colors

local M = {}
ns.Messages = M

local ROWS = 3
local CELL = Shy.Top.Make.CELL
local ROW, RULE = CELL.ROW, CELL.RULE
local WIDTH = 340                           -- the most a line's words are given (a line the game keeps secret has it)
local LEAST = 160                           -- the narrowest its cells stand
local HOLD = { progress = 4, done = 5, info = 3, error = 2.5, system = 3.5 }
local IN, OUT, QUICK = 0.15, 0.5, 0.15      -- fade in, fade out, the fade of a line pushed out by a fourth
local SETTLE = 14                           -- how quickly a line glides to its place (per second)
local FILL, PULSE, GLEAM = 0.3, 0.6, 0.8    -- seconds: the fill growing, a light's flare dying, the gleam's crossing
local SAMPLE = { { "ERR_QUEST_ADD_ITEM_SII", "Linen Cloth", 5, 8 }, { "ERR_QUEST_ADD_KILL_SII", "Kobold Vermin", 8, 8 }, { "ERR_INV_FULL" } }

local box, tray
local live, leaving = {}, {}
local pool = {}
local failed                                -- the first failure, said once in chat

-- Reading a message

-- A format of the game's (ERR_QUEST_ADD_ITEM_SII "%s: %d/%d") as a pattern, and the order of its values.
local function Pattern(format)
	local order = {}
	local p = format:gsub("%%%d+%$([sd])", "\1%1"):gsub("%%([sd])", "\1%1")
	for kind in p:gmatch("\1([sd])") do order[#order + 1] = kind end
	p = p:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
	p = p:gsub("\1s", "(.-)"):gsub("\1d", "(%%d+)")
	return "^" .. p .. "$", order
end

-- Kill before items: "%s slain: %d/%d" would read as an item called "... slain".
local FORMS = {
	{ key = "ERR_QUEST_ADD_KILL_SII", glyph = "kill" },
	{ key = "ERR_QUEST_ADD_PLAYER_KILL_SII", glyph = "kill" },
	{ key = "ERR_QUEST_ADD_ITEM_SII", glyph = "loot" },
	{ key = "ERR_QUEST_ADD_FOUND_SII", glyph = "go" },
	{ key = "ERR_QUEST_OBJECTIVE_COMPLETE_S", done = true },
}
local forms

local function Forms()
	if forms then return forms end
	forms = {}
	for _, def in ipairs(FORMS) do
		local format = _G[def.key]
		if type(format) == "string" then
			local pattern, order = Pattern(format)
			forms[#forms + 1] = { pattern = pattern, order = order, glyph = def.glyph, done = def.done }
		end
	end
	return forms
end

-- What an objective is called, without its count.
local function Label(text)
	local label = text:gsub("%s*%d+%s*/%s*%d+%s*$", ""):gsub("[%s:]+$", "")
	return label ~= "" and label or text
end

-- Quest progress: { label, glyph, have, need, done }, or nil for any other message. `unnamed`: the game's
-- "Objective Complete.", which names no objective.
function M.Read(text)
	if text == _G.ERR_QUEST_UNKNOWN_COMPLETE then return { label = text, done = true, unnamed = true } end
	for _, form in ipairs(Forms()) do
		local values = { text:match(form.pattern) }
		if #values > 0 then
			if form.done then return { label = values[1], done = true } end
			local numbers = {}
			for i, kind in ipairs(form.order) do
				if kind == "d" then numbers[#numbers + 1] = tonumber(values[i]) end
			end
			local have, need = numbers[1], numbers[2]
			if have and need then
				return { label = Label(text), glyph = form.glyph, have = have, need = need, done = need > 0 and have >= need }
			end
		end
	end
end

local function Near(a, b) return math.abs(a - b) < 0.02 end

-- The game's red is an error, its yellow news; any other color is the server's own.
local function Tone(r, g, b)
	if type(r) ~= "number" or issecretvalue(r) or issecretvalue(g) or issecretvalue(b) then return "info" end
	local rr, rg, rb = RED_FONT_COLOR:GetRGB()
	if Near(r, rr) and Near(g, rg) and Near(b, rb) then return "error" end
	local yr, yg, yb = YELLOW_FONT_COLOR:GetRGB()
	if Near(r, yr) and Near(g, yg) and Near(b, yb) then return "info" end
	return "system"
end

-- Drawing a line

-- A line is a cell of the column's tray (Shy.Top.Make.Cell), with what it is doing now.
local function NewRow(parent)
	local row = Shy.Top.Make.Cell(parent)
	row.alpha, row.share, row.pulse = 0, 0, 0
	return row
end

-- An error's words: its red, most of the way to white.
local function ErrorInk()
	local r, g, b = C.bad[1], C.bad[2], C.bad[3]
	return r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55
end

-- Colors and pieces for what the row says now. d: { text, tone, color, glyph, have, need, done, progress }.
-- row.need: the width its words need (WIDTH at most, and for words the game keeps secret).
local function Dress(row, d)
	local need
	if d.progress then
		-- The objective's kind has a color of its own (ShyQuest's, shared as Shy.Kinds): kill, loot, explore. Its
		-- tab wears it; the meter fills in your color, and all of it turns mint once done.
		local kind = Shy.Kinds and d.glyph and Shy.Kinds[d.glyph]
		need = row:Set({ sign = d.done and "check" or (d.glyph or "loot"),
			color = d.done and C.good or kind and kind.color or Theme.Accent, name = d.text,
			right = d.need and (d.have .. "/" .. d.need) or "", rightColor = d.done and C.good or C.head,
			fill = d.done and C.good or Theme.Accent })
	else
		-- Anything else is its words alone, a strip down its left edge in the message's meaning.
		local tone = d.tone
		need = row:Set({ tab = false, said = d.text,
			saidColor = tone == "error" and ErrorInk or tone == "system" and d.color or C.text,
			strip = tone == "error" and C.bad or tone == "system" and d.color or Theme.Accent })
	end
	row.need = math.min(WIDTH, need or WIDTH)
end

-- The fill, the flare and the gleam as they stand.
local function Draw(row)
	row:SetAlpha(row.alpha)
	row:Share(row.share)
	row:Pulse(row.pulse)
	row:Gleam(row.gleam)
end

-- A line `y` under the first line's place (row.x: how far in the tray's cells stand from the box's top left).
local function Stand(row, y)
	row.y = y
	local x = row.x or 0
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", row:GetParent(), "TOPLEFT", x, -(x + y))
end

local function Slot(i) return (i - 1) * (ROW + RULE) end

-- The piece as a picture: three lines of what it says, one of each kind.
local function SampleData()
	local list = {}
	for _, s in ipairs(SAMPLE) do
		local format = _G[s[1]]
		if type(format) == "string" then
			local text = s[2] and format:format(s[2], s[3], s[4]) or format
			local read = M.Read(text)
			if read then
				list[#list + 1] = { text = read.label, progress = true, glyph = read.glyph, have = read.have, need = read.need, done = read.done }
			else
				list[#list + 1] = { text = text, tone = "error" }
			end
		end
	end
	return list
end

function M.Sample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:EnableMouse(false)
	local cells = {}
	for i, d in ipairs(SampleData()) do
		local row = NewRow(f)
		Dress(row, d)
		row.alpha, row.share = 1, d.need and d.need > 0 and math.min(1, d.have / d.need) or (d.done and 1 or 0)
		Draw(row)
		cells[i] = row
	end
	return Shy.Top.Make.Still(f, WIDTH, cells)
end

-- The lines on screen

local function Ticker() end   -- set below
local ticking = false

local function Wake()
	if ticking or not box then return end
	ticking = true
	box:SetScript("OnUpdate", Ticker)
end

local function Release(row)
	row:Hide()
	-- (A sample's mark goes too: a line taken again after layout mode would never leave.)
	row.key, row.id, row.data, row.gleam, row.sample = nil, nil, nil, nil, nil
	pool[#pool + 1] = row
end

local function Take()
	local row = table.remove(pool) or NewRow(box)
	row.alpha, row.share, row.pulse, row.gleam = 0, 0, 0, nil
	row:Show()
	return row
end

local function Find(key)
	if not key then return nil end
	for _, row in ipairs(live) do
		if row.key == key then return row end
	end
end

local function Hold(row)
	local d = row.data
	return HOLD[d.progress and (d.done and "done" or "progress") or (d.tone or "info")]
end

-- The lines stood in the tray: each the tray's width (the drawer's while it hangs there, as wide as the widest
-- line's words need), one right on the next; every one wears the hairline along its top but the first of a tray
-- standing by itself, which stands under its own border. The box hugs them and takes no room in the column with
-- none: the column is arranged again as their number changes.
local function Room()
	if not box then return end
	local need, n = LEAST, #live
	for _, row in ipairs(live) do need = math.max(need, row.need or 0) end
	local width, inset = tray:Fit(need, n > 0 and n * ROW + (n - 1) * RULE or 0)
	local hung = Shy.Top.Hung(box)
	for i, row in ipairs(live) do
		row:SetWidth(width)
		row.x = inset
		row:Rule(hung or i > 1)
		if row.y then Stand(row, row.y) end
	end
	for _, row in ipairs(leaving) do row:SetWidth(width) end
	if n ~= box.lines then
		box.lines = n
		Shy.Top.Apply()
	end
end

-- A message the game showed: a new line, or one already up said again.
local function Say(d, key, id)
	local row = Find(key)
	if row then
		local was = row.data
		if d.progress and was.progress then
			-- "(Complete)" says no count: the one the line had is kept, made whole.
			if d.have == nil and was.need then d.have, d.need = was.need, was.need end
			d.glyph = d.glyph or was.glyph
		end
		local finished = d.done and not was.done
		row.data, row.id = d, id or row.id
		Dress(row, d)
		if finished then row.gleam = 0 end
		if row.state == "out" then row.state = "in" end
	else
		if #live >= ROWS then
			local oldest = table.remove(live, 1)
			oldest.state = "leave"
			leaving[#leaving + 1] = oldest
		end
		row = Take()
		row.key, row.id, row.data, row.state = key, id, d, "in"
		row.x = tray.inset
		row:SetWidth(tray.width)
		Dress(row, d)
		live[#live + 1] = row
		Stand(row, Slot(#live))
		if d.done and d.progress then row.gleam = 0 end
	end
	row.shareTo = d.progress and (d.need and d.need > 0 and math.min(1, d.have / d.need) or (d.done and 1 or 0)) or 0
	row.left = Hold(row)
	row.pulse = 1
	Draw(row)
	Wake()
	Room()
end

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not failed then
		failed = tostring(err)
		T:Print("messages: " .. failed)
	end
end

-- Where ShyCore has the column's head, a word of the game's that is no quest's count is said there: its
-- sign in the head's circle, its words on the plate, for as long as a line of it would stand here; what
-- counts stays here, a plate a line.
local BAGS = {}
for _, name in ipairs({ "ERR_INV_FULL", "ERR_BAG_FULL", "INVENTORY_FULL" }) do
	if type(_G[name]) == "string" then BAGS[_G[name]] = true end
end

-- A place discovered ("Discovered: %s", and with the experience it gave): the banner a place to go to wears,
-- in its ice blue (ShyQuest's, shared as Shy.Kinds; this one while ShyQuest is off).
local FOUND = {}
for _, name in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
	if type(_G[name]) == "string" then FOUND[#FOUND + 1] = (Pattern(_G[name])) end
end
local EXPLORE = { 0.44, 0.80, 1.00 }

local function Discovered(text)
	if issecretvalue(text) then return false end
	for _, pattern in ipairs(FOUND) do
		if text:find(pattern) then return true end
	end
	return false
end

local function Head(text, tone, r, g, b)
	local N = Shy.Notices
	if not (N and N.Voice) then return false end
	local bags = not issecretvalue(text) and BAGS[text]
	local found = tone ~= "error" and Discovered(text)
	local kind = Shy.Kinds and Shy.Kinds.go
	-- An error is the red of the head's caught errors (the last of the combo colors), not the palette's.
	local color = tone == "error" and Theme.COMBO[#Theme.COMBO] or found and (kind and kind.color or EXPLORE)
		or tone == "system" and { r, g, b } or { Theme.Accent() }
	-- Each its head sign, in the circle in its color's light: an error the alarm's exclamation mark, the bags
	-- full a satchel, a place discovered the banner, the server's word a bubble, any other news an i.
	local sign = tone == "error" and (bags and "full" or "alert") or found and "go" or tone == "system" and "talk" or "news"
	N.Voice("said", {
		priority = 20, hold = HOLD[tone] or HOLD.info, glyph = sign, color = color,
		title = text, titleColor = tone == "system" and color or C.text, under = "",
	})
	return true
end

-- Whether a quest's count that has come whole is up.
local function Counted()
	for _, row in ipairs(live) do
		local d = row.data
		if d and d.progress and d.need and d.done then return true end
	end
	return false
end

local function Message(text, r, g, b, id)
	if not M.on then return end
	if issecretvalue(id) then id = nil end
	-- A secret is handed to the font string unread, as news.
	if issecretvalue(text) then
		if Head(text, "info") then return end
		Say({ text = text, tone = "info" }, nil, id)
		return
	end
	if type(text) ~= "string" then return end
	local tone = Tone(r, g, b)
	local read = tone ~= "error" and M.Read(text) or nil
	if read then
		-- "Objective Complete." after a count that came whole says nothing the count's line hasn't: its cell turned
		-- mint with its check, and the game's sound played. It is a line only where no such count is up to say it.
		if read.unnamed and Counted() then return end
		Say({ text = read.label, progress = true, glyph = read.glyph, have = read.have, need = read.need, done = read.done }, "q:" .. read.label, id)
		return
	end
	if Head(text, tone, r, g, b) then return end
	Say({ text = text, tone = tone, color = tone == "system" and { r, g, b } or nil }, "m:" .. text, id)
end

-- The game flashes a line it would say again instead of adding one: the line here flares and stays.
local function Again(id)
	if not M.on or issecretvalue(id) or id == nil then return end
	for _, row in ipairs(live) do
		if row.id == id then
			row.pulse, row.left = 1, Hold(row)
			if row.state == "out" then row.state = "in" end
			Wake()
		end
	end
end

local function Approach(now, to, rate)
	local moved = now + (to - now) * rate
	if math.abs(to - moved) < 0.01 then return to end
	return moved
end

-- Two lists in turn, so nothing is made a frame while lines move.
local spare = {}
Ticker = function(_, elapsed)
	local busy = false
	local kept, before = spare, #live
	wipe(kept)
	for i, row in ipairs(live) do
		local gone = false
		if row.state == "in" then
			row.alpha = math.min(1, row.alpha + elapsed / IN)
			if row.alpha >= 1 then row.state = "hold" end
		elseif row.state == "hold" then
			if not row.sample then
				row.left = row.left - elapsed
				if row.left <= 0 then row.state = "out" end
			end
		elseif row.state == "out" then
			row.alpha = row.alpha - elapsed / OUT
			if row.alpha <= 0 then gone = true end
		end
		if gone then
			Release(row)
		else
			kept[#kept + 1] = row
			local y = Approach(row.y, Slot(#kept), math.min(1, elapsed * SETTLE))
			if y ~= row.y then Stand(row, y) end
			if row.shareTo then row.share = Approach(row.share, row.shareTo, math.min(1, elapsed / FILL * 3)) end
			row.pulse = math.max(0, row.pulse - elapsed / PULSE)
			if row.gleam then
				row.gleam = row.gleam + elapsed / GLEAM
				if row.gleam >= 1 then row.gleam = nil end
			end
			Draw(row)
			if not (row.state == "hold" and row.sample and row.pulse == 0 and not row.gleam and row.share == (row.shareTo or row.share) and y == Slot(#kept)) then
				busy = true
			end
		end
	end
	live, spare = kept, live
	-- The room changes only as a line goes (a new one asks for it as it comes, and the column's width has its event).
	if #live ~= before then Room() end
	for i = #leaving, 1, -1 do
		local row = leaving[i]
		row.alpha = row.alpha - elapsed / QUICK
		if row.alpha <= 0 then
			table.remove(leaving, i)
			Release(row)
		else
			Draw(row)
			busy = true
		end
	end
	if not busy then
		ticking = false
		box:SetScript("OnUpdate", nil)
	end
end

local function Drop(samplesOnly)
	local kept = {}
	for _, row in ipairs(live) do
		if samplesOnly and not row.sample then kept[#kept + 1] = row else Release(row) end
	end
	live = kept
	for _, row in ipairs(leaving) do Release(row) end
	wipe(leaving)
end

-- Layout mode: with nothing up, the piece shows what it would say, so there is something to place.
local function Samples(on)
	if not (box and M.on) then return end
	if on then
		if #live > 0 then return end
		for i, d in ipairs(SampleData()) do
			Say(d, "sample:" .. i)
			live[#live].sample = true
		end
	else
		Drop(true)
	end
end

function M.Live()
	local list = {}
	for _, row in ipairs(live) do
		local d = row.data
		list[#list + 1] = { key = row.key, text = d.text, tone = d.tone, glyph = d.glyph, have = d.have, need = d.need, done = d.done,
			sample = row.sample, row = row }
	end
	return list
end

-- The box

local function Build()
	if box then return end
	box = HUD.Create({
		id = "shyskin.messages", title = "Messages",
		width = WIDTH, height = ROWS * ROW + (ROWS - 1) * RULE,
		point = { "TOP", "TOP", 0, -122 },
		shown = function() return M.on == true end,
		away = function() return M.on ~= true end,
		-- In the drawer under the head, after breath and fatigue.
		top = { order = 32, sample = M.Sample, passing = true, wrap = true,
			empty = function() return #live == 0 and not HUD.IsUnlocked() end },
	})
	box:SetFrameStrata("DIALOG")
	box:EnableMouse(false)
	-- The column lays the lines again as its width, who hangs in the drawer or the look changes.
	tray = Shy.Top.Tray(box, { least = LEAST, lay = function() Safe(Room) end })
	-- The lines are made now, hidden: the first kill's count makes nothing.
	for _ = 1, ROWS + 1 do Release(NewRow(box)) end
	Shy:On("SHY_HUD_LAYOUT", function(on) Safe(Samples, on) end)
	-- (A tab's wash and a sign's light are the theme's to color.)
	Shy:On("SHY_THEME", function()
		for _, row in ipairs(live) do Dress(row, row.data) end
	end)
end

local hooked = false
local function Hook()
	if hooked then return end
	hooked = true
	hooksecurefunc(UIErrorsFrame, "AddMessage", function(_, text, r, g, b, _, id) Safe(Message, text, r, g, b, id) end)
	hooksecurefunc(UIErrorsFrame, "ResetMessageFadeByID", function(_, id) Safe(Again, id) end)
end

local function Arrange()
	if not box then return end
	HUD.Update(box)
	if Shy.Top then Shy.Top.Apply() end
end

ns.Module({
	id = "messages",
	title = "Messages",
	desc = "Quest progress, errors and other messages show at the top of your screen.",
	group = "screen",
	words = "red error text",

	Ready = function() return UIErrorsFrame ~= nil end,

	Hook = function()
		Build()
		Hook()
	end,

	Paint = function(m, kit)
		kit:Hide(UIErrorsFrame)
		local was = M.on
		M.on = true
		if not was then
			Arrange()
			if HUD.IsUnlocked() then Samples(true) end
		end
	end,

	Clear = function(m)
		if m.on then return end
		M.on = false
		Drop(false)
		Room()
		Arrange()
	end,
})
