-- The full guide on the card (ns.char.guideFull): progress bar, step list and guide picker.
-- Card.lua owns the layout and asks GL.Progress / GL.Layout for heights. Only a window of the
-- guide's steps is laid out, with a "more" row at either end. ns.ToggleGuideWindow(open) switches it.

local ADDON, ns = ...
local T = ns.T
local G, Tips = ns.Guide, ns.Tips
local UI = Shy.UI
local C = UI.colors

local WIDTH, PAD = 270, 10           -- must match Card.lua
local ROW = 18                       -- row height
local ROWS = 13                      -- rows visible at once
local LIST = ROW * ROWS
local INNER = WIDTH - PAD * 2 - 14   -- row width, less the scroll thumb
local NUMBER = 30                    -- title inset: room for three digits
local STRIP = 14                     -- progress strip height
local PERCENT = 28                   -- width of the percent text
local BAR = WIDTH - PAD * 2 - PERCENT - 4
local BEHIND, AHEAD = 6, 40          -- steps laid out before and after the live one
local MORE = 30                      -- steps added by a "more" row
local FILL = Shy.MEDIA .. "Bar"      -- plain fill: the strip is too thin for the hatch

local GL = {}
ns.GuideList = GL

local card, list, scroll, progress, earlier, later
local rows = {}
local from, to                       -- range of steps laid out
local shownFor                       -- guide and live step the range was chosen for

local function LiveIndex()
	local entry = G.active[1]
	if entry and not entry.side then return entry.step.index end
	-- The main step can be waiting behind a side step.
	return G.waiting and G.waiting.step.index or nil
end

local function IsLive(index)
	for _, entry in ipairs(G.active) do
		if entry.step.index == index then return true, entry.side end
	end
	return false
end

local function Clicked(mouse)
	return mouse == "LeftButton" and not (card.wasDragged and card.wasDragged())
end

-- Rows

local function RowMenu(root, row)
	local index, state, view = row.index, row.state, row.view
	if not view then return end
	local live = LiveIndex()
	local ahead = live ~= nil and index > live
	root:CreateTitle("Step " .. view.number)
	-- Each entry with its glyph on the rail (UI.MenuGlyph), as the card's rows have them.
	local function Row(text, glyph, click)
		root:CreateButton(text, click):SetIcon(UI.MenuGlyph(glyph))
	end
	if state == "skipped" and view.skipped ~= index then
		-- Skipped along with the step that dropped its quest: undo that one.
		Row(("Go back to step %d to undo the skip"):format(G.Number(view.skipped)), "back", function() G.BackTo(view.skipped) end)
	elseif state == "skipped" then
		Row(ahead and "Don't skip it after all" or "Go back to this step", "back", function() G.BackTo(index) end)
		Row("This step is done", "done", function() G.MarkDone(index, true) end)
	elseif state == "done" then
		if G.Returnable(index) then
			Row(ahead and "Not done after all" or "Go back to this step", "back", function() G.BackTo(index) end)
		end
		Row("Carry on from here", "first", function() G.StartAt(index) end)
	else
		if ahead then
			Row("Carry on from here", "first", function() G.StartAt(index) end)
		elseif index ~= live and G.Returnable(index) then
			Row("Go back to this step", "back", function() G.BackTo(index) end)
		end
		Row("Skip this step", "skip", function() G.Skip(index) end)
		Row("This step is done", "done", function() G.MarkDone(index, true) end)
	end
	for _, link in ipairs(view.links or {}) do
		Row("Copy the link: " .. link.text, "link", function() UI.ShowCopyBox("A link from your guide", link.url) end)
	end
	-- Any step still to do is taken as on the card (Card.lua, ns.TakeHint): the route leads there, behind the
	-- guide's place or ahead of it, and "Back to my route" brings the guide's place back.
	local stop
	for _, each in ipairs(ns.Route.stops) do
		if each.kind == "guide" and each.view.step.index == index and (each.view.guide or G.current) == G.current then stop = each break end
	end
	if not stop and state == "todo" then stop = { kind = "guide", view = view, map = view.map } end
	local take = stop and ns.TakeHint(stop)
	if take then Row(take, stop.taken and "back" or "route", function() ns.TakeStop(stop) end) end
	root:CreateDivider()
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Frame", nil, scroll.content)
	row:SetSize(INNER, ROW)
	row.fill = row:CreateTexture(nil, "BACKGROUND")
	row.fill:SetAllPoints()
	row.glow = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.glow:SetAllPoints()
	UI.Paint(row.glow, C.hot, 0.07)
	row.glow:Hide()
	row.edge = row:CreateTexture(nil, "BORDER")
	row.edge:SetPoint("TOPLEFT")
	row.edge:SetPoint("BOTTOMLEFT")
	row.edge:SetWidth(2)
	row.number = UI.Text(row, "", 11, true, C.dim)
	row.number:SetPoint("LEFT", 4, 0)
	row.number:SetWidth(NUMBER - 8)
	row.number:SetJustifyH("RIGHT")
	row.title = UI.Text(row, "", 12, false, C.text)
	row.title:SetPoint("LEFT", NUMBER, 0)
	row.title:SetWordWrap(false)
	row.tag = UI.Text(row, "", 10, false, C.dim)
	row.tag:SetPoint("RIGHT", -6, 0)
	row.tag:SetWordWrap(false)
	row:SetScript("OnEnter", function(self)
		self.glow:Show()
		if self.view and Tips.ShowStep then Tips.ShowStep(self, self.view, self.state) end
	end)
	row:SetScript("OnLeave", function(self)
		self.glow:Hide()
		Tips.Close(self)
	end)
	-- Right click opens the menu through card.manage; left click here, unless it was a drag.
	row:SetScript("OnMouseUp", function(self, mouse)
		if Clicked(mouse) then
			Shy.UI.ContextMenu(self, function(root) RowMenu(root, self) end)
		end
	end)
	card.manage(row, function(root) RowMenu(root, row) end)
	rows[i] = row
	return row
end

local function FillRow(row, index, view, state)
	local live, side = IsLive(index)
	row.index, row.state, row.view = index, state, view
	row.number:SetText(tostring(view.number))
	local title = view.who or (view.lines[1] and UI.PlainText(view.lines[1].text)) or ("Step " .. view.number)
	row.title:SetText(title)
	local tag = ""
	if state == "skipped" then
		tag = view.absent and "quest not taken" or "skipped"
	elseif state == "done" then
		tag = "done"
	elseif live and side then
		tag = "along the way"
	end
	-- The step you took, in the gold the card wears for it (Card.lua, Head).
	local taken = ns.Route.StepTaken and ns.Route.StepTaken()
	local took = taken ~= nil and taken.guide == G.current and taken.index == index
	if took then tag = "you took this" end
	UI.Ink(row.tag, took and C.alert or C.dim)
	row.tag:SetText(tag)
	row.title:SetWidth(INNER - NUMBER - 6 - (tag ~= "" and (row.tag:GetStringWidth() + 8) or 0))

	local quiet = state ~= "todo"
	UI.Ink(row.title, quiet and C.dim or C.text)
	UI.Ink(row.number, (live and not side) and C.hot or C.dim)
	if live and not side then
		UI.Paint(row.fill, C.fill, 0.28)
		UI.Paint(row.edge, C.hot, 1)
	elseif live then
		UI.Paint(row.fill, C.fill, 0.12)
		UI.Paint(row.edge, C.fill, 1)
	else
		UI.Paint(row.fill, C.row, 0)
		UI.Paint(row.edge, C.rowEdge, 0)
	end
end

-- The "30 earlier steps..." row at either end of the range.
local function More(which, extend)
	local f = CreateFrame("Frame", nil, scroll.content)
	f:SetSize(INNER, ROW)
	f.text = UI.Text(f, "", 11, false, C.dim)
	f.text:SetPoint("CENTER")
	f.text:SetWordWrap(false)
	function f:Say(count)
		self.text:SetText(("%d %s step%s..."):format(count, which, count == 1 and "" or "s"))
	end
	f:SetScript("OnEnter", function(self) UI.Ink(self.text, C.hot) end)
	f:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
	f:SetScript("OnMouseUp", function(_, mouse)
		if Clicked(mouse) then extend() end
	end)
	card.manage(f)
	return f
end

-- Layout

-- Lays out from..to; the range is re-chosen, and the list scrolled, when the guide or live step changes.
local function Rows()
	local guide = G.current
	local live = LiveIndex()
	local jump = false
	local key = guide.name .. ":" .. tostring(live)
	if key ~= shownFor then
		shownFor = key
		-- No live step: the guide is finished, so show its end.
		local at = live or #guide.raw
		from = math.max(1, at - BEHIND)
		to = math.min(#guide.raw, at + AHEAD)
		jump = true
	end

	local y, used, liveY = 0, 0, nil
	earlier:SetShown(from > 1)
	if from > 1 then
		earlier:Say(math.min(MORE, from - 1))
		earlier:ClearAllPoints()
		earlier:SetPoint("TOPLEFT", 0, -y)
		y = y + ROW
	end
	for index = from, to do
		local view, state = G.View(index)
		if view and #view.lines > 0 then
			used = used + 1
			local row = Row(used)
			FillRow(row, index, view, state)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:Show()
			if index == live then liveY = y end
			y = y + ROW
		end
	end
	for i = used + 1, #rows do rows[i]:Hide() end
	later:SetShown(to < #guide.raw)
	if to < #guide.raw then
		later:Say(math.min(MORE, #guide.raw - to))
		later:ClearAllPoints()
		later:SetPoint("TOPLEFT", 0, -y)
		y = y + ROW
	end
	scroll.content:SetHeight(math.max(1, y))
	if jump then
		-- Live step three rows down, so the last steps done stay visible.
		scroll:SetVerticalScroll(math.max(0, (liveY or 0) - ROW * 3))
	end
	scroll:Update()
end

local function Earlier()
	from = math.max(1, from - MORE)
	Rows()
end

local function Later()
	to = math.min(G.Count(), to + MORE)
	Rows()
end

-- Called by the card

-- Places the progress strip at y below the card's top; returns its height (0 without a guide).
function GL.Progress(owner, y)
	local guide = G.current
	progress:SetShown(guide ~= nil)
	if not guide then return 0 end
	local at, total, share = G.Progress()
	progress.at, progress.total = at, total
	progress.share:SetText(math.floor(share * 100 + 0.5) .. "%")
	progress.fill:SetShown(share > 0)
	progress.fill:SetWidth(math.max(1, (BAR - 2) * share))
	progress:ClearAllPoints()
	progress:SetPoint("TOPLEFT", 0, -y)
	progress:SetPoint("TOPRIGHT", 0, -y)
	return STRIP
end

-- Places the list at y below the card's top; returns its height.
function GL.Layout(owner, y)
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", 0, -y)
	list:SetPoint("TOPRIGHT", 0, -y)
	list:Show()
	-- (Only asked for while a guide is followed: Card.lua's self.full.)
	scroll:Show()
	Rows()
	list:SetHeight(LIST + 10)
	return LIST + 10
end

function GL.Hide(owner)
	list:Hide()
	progress:Hide()
end

-- Adds the guide picker to any menu.
function GL.Menu(root)
	root:CreateTitle("Guides for this character")
	for _, guide in ipairs(G.List()) do
		local at, total = G.Place(guide)
		-- Careful-route guides share names with the normal ones.
		local name = guide.careful and (guide.name .. "  \194\183  careful route") or guide.name
		local label = at and at > 1 and ("%s  (step %d of %d)"):format(name, at, total)
			or ("%s  (%d steps)"):format(name, total)
		root:CreateRadio(label,
			function() return G.current == guide end,
			function()
				shownFor = nil
				G.Pick(guide)
			end)
	end
	root:CreateDivider()
	-- Re-picks guide and step from completed quests, dropping manual ticks, skips and backs.
	root:CreateButton("Find my place again", function()
		shownFor = nil
		G.Auto()
	end)
	-- A dungeon's quests from the start, whatever your place (Run.lua; a file new to the TOC needs a restart).
	if ns.Run then ns.Run.Menu(root) end
end

function GL.Pick(owner)
	Shy.UI.ContextMenu(owner, function(root) GL.Menu(root) end)
end

-- Construction

local function CreateProgress()
	progress = CreateFrame("Frame", nil, card)
	progress:SetHeight(STRIP)
	progress.share = UI.Text(progress, "", 10, false, C.dim)
	progress.share:SetPoint("RIGHT", -PAD, 0)
	progress.share:SetWidth(PERCENT)
	progress.share:SetJustifyH("RIGHT")
	local bar = CreateFrame("Frame", nil, progress)
	bar:SetSize(BAR, 5)
	bar:SetPoint("LEFT", PAD, 0)
	UI.Skin(bar)
	progress.fill = bar:CreateTexture(nil, "ARTWORK")
	progress.fill:SetPoint("TOPLEFT", 1, -1)
	progress.fill:SetPoint("BOTTOMLEFT", 1, 1)
	progress.fill:SetTexture(FILL)
	UI.Tint(progress.fill, Shy.Theme.Accent)
	progress:EnableMouse(true)
	progress:SetScript("OnEnter", function(self)
		UI.Tip(self, self.at and ("Step %d of %d"):format(self.at, self.total) or ("All %d steps done"):format(self.total or 0),
			"Only counts the steps for your character. The arrows beside the count go back or skip a step.", { side = "TOP" })
	end)
	progress:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	card.manage(progress)
	progress:Hide()
	card.progress = progress
end

local function CreateList()
	-- (In the card's body, which scrolls under its lead: the list stands among the steps.)
	list = CreateFrame("Frame", nil, card.body and card.body.content or card)
	list:SetHeight(LIST + 10)
	for _, where in ipairs({ "TOP", "BOTTOM" }) do
		local rule = list:CreateTexture(nil, "ARTWORK")
		rule:SetHeight(1)
		rule:SetPoint(where .. "LEFT", PAD, 0)
		rule:SetPoint(where .. "RIGHT", -PAD, 0)
		UI.Paint(rule, C.rowEdge, 0.8)
	end
	card.manage(list)

	scroll = UI.ScrollArea(list, WIDTH - PAD * 2, LIST)
	scroll:SetPoint("TOPLEFT", PAD, -5)
	card.manage(scroll)
	earlier = More("earlier", Earlier)
	later = More("later", Later)

	list:Hide()
	card.list = list
end

-- Called by Card.lua (SetupCard) once card.manage exists.
function GL.Create(owner)
	card = owner
	CreateProgress()
	CreateList()
end

-- open: true for the full guide, false for next steps only, nil to toggle.
function ns.ToggleGuideWindow(open)
	if open == nil then open = not ns.char.guideFull end
	ns.char.guideFull = open and true or false
	if open then shownFor = nil end
	if ns.ApplyCard then ns.ApplyCard() end
end
