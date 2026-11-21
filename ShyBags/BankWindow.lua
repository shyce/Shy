-- The bank, in a window of its own beside the bags window: docked to its side and moving with it, or wherever
-- it is dragged (dragged back near either side, it docks there again; Shy.HUD's `dock`).
-- It shows the bank of the character the bags window shows: live at a banker (the game's own item buttons, as
-- your bags are), remembered anywhere else. At a banker it is up for the visit and its × ends the visit; away
-- from one the bags' bank door and menu open and close it, and closing the bags closes it.
-- Beside its slots stand the bank's bag slots, of the bag column's make (BagBar.NewSlot): a bag shows what it
-- is, and hovered its slots light in the grid; an empty slot takes a bag dragged to it; the next slot to buy is
-- a plus that buys it through the game's own prompt (BankPanelPurchaseButtonScriptTemplate, Bank.Arm);
-- the ones after it are locked until it is bought. A bank never opened has no tab yet: the window offers the
-- first, which is free.
-- Under the foot at a banker stand the bank's jobs: what another addon offers to do with the bank in one go
-- (T:RegisterBankJob; ShyQuest's take out, put away and clear out), a line each while it has something to
-- do, its pin before its words, a click doing it and its hover saying what it would move.
--   BankWindow.Toggle()        open or close the remembered bank (away from a banker)
--   BankWindow.IsShown()       BankWindow.Owns(button)   BankWindow.BuyButtons()   BankWindow.Refresh()
--   BankWindow.Paint(only)     paint the live slots again (only: those keys, bag * 1000 + slot)

local ADDON, ns = ...
local T = ns.T
local UI, Skin = Shy.UI, Shy.Skin
local C, SC = UI.colors, Skin.colors
local Store, Tile, Grid, Takeover, Bank, Window, BagBar = ns.Store, ns.Tile, ns.Grid, ns.Takeover, ns.Bank, ns.Window, ns.BagBar

local BankWindow = {}
ns.BankWindow = BankWindow

T.defaults.bankColumns = 0   -- slots across, as dragged by the bank window's corner; 0: the bank fits itself

local STEP = Tile.SIZE + Tile.GAP
local TOP, EDGE = 35, 8          -- the slots' top, and the margin round them: the bags window's
local FOOT, SEAM = 17, 13        -- the foot's height; the room between the slots and the bag slots
local SIZE, GAP = BagBar.SIZE, BagBar.GAP
local FRESH_W = 5 * STEP - Tile.GAP
local SOCKETS = Enum.BagIndex.Characterbanktab   -- the container holding the bank's bag slots
local FIRST = Enum.BagIndex.CharacterBankTab_1   -- the bank's first tab; bag slot n holds tab n
local GOLD = { 1.0, 0.80, 0.38 }                 -- the vault's gold: the slot that buys the next one
local JOB = { tall = 17, gap = 3, pad = 5, pin = 14, seat = 12, between = 2 }   -- a job's line; its pin, and the room it sits in

local box, win
local P = {}
local jobs = {}        -- T:RegisterBankJob's, in their order
local wanted = false   -- opened from the bags window (away from a banker)
local building = false

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- The bank's lists of remembered slots, tab by tab.
local function Lists(c)
	local keys, lists = {}, {}
	for key in pairs(c.bank or {}) do
		if type(key) == "number" then keys[#keys + 1] = key end
	end
	table.sort(keys)
	for index, key in ipairs(keys) do lists[index] = c.bank[key] end
	return lists
end

-- What the window shows now, and for whom: "live" (your bank at a banker), "fresh" (yours, never opened), or
-- "stored" (remembered); nil while it is down.
local function Mode()
	if not (Takeover.IsOn() and (Takeover.Visible())) then return nil end
	local c, guid, isMe = Window.Looked()
	if not c then return nil end
	if isMe and Bank.IsLive() then return Bank.Fresh() and "fresh" or "live", c, guid, isMe end
	if not (wanted or Bank.IsLive()) or #Lists(c) == 0 then return nil end
	return "stored", c, guid, isMe
end

function BankWindow.IsShown()
	return box ~= nil and box:IsShown()
end

function BankWindow.Owns(button)
	return P.live ~= nil and type(button) == "table" and Tile.Grid(button) == P.live
end

function BankWindow.BuyButtons()
	if not win then return {} end
	return { P.buy.button, P.open }
end

function BankWindow.Paint(only)
	if not (P.live and P.live:IsVisible()) then return end
	if not only then
		P.live:Paint()
		return
	end
	for key in pairs(only) do
		local tile = P.live.where and P.live.where[key]
		if tile then Tile.Paint(tile) end
	end
end

-- The column count the player chose, or nil while the bank fits itself.
local function Prefer()
	local columns = T.db.bankColumns
	return (columns and columns > 0) and columns or nil
end

-- The bag slots

-- A plain bag slot: a bag bought (with or without a bag in it), or one locked behind the next to buy.
local function Socket(index)
	local e = P.sockets[index]
	if e then return e end
	e = BagBar.NewSlot(win)
	e.mark = e.button:CreateTexture(nil, "OVERLAY")
	e.mark:SetSize(12, 12)
	e.mark:SetPoint("CENTER")
	local button = e.button
	button:RegisterForDrag("LeftButton")
	local function Take()
		if e.bought then Bank.Take(e.index) end
	end
	button:SetScript("OnClick", Take)
	button:SetScript("OnDragStart", Take)
	button:SetScript("OnReceiveDrag", Take)
	button:SetScript("OnEnter", function(self)
		if e.icon:IsShown() then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if GameTooltip:SetBagItem(SOCKETS, e.index) then GameTooltip:Show() else GameTooltip:Hide() end
			-- Its slots in the grid, empty ones too, stand out in its kind's color, or the accent's light.
			if P.live:IsShown() then P.live:Focus(e.bag, e.color or C.hot) end
		elseif e.bought then
			UI.Tip(self, "Bag slot", "Drag a bag here to keep it in your bank.", { side = "RIGHT" })
		else
			UI.Tip(self, "Bag slot", "Buy the one before it first.", { side = "RIGHT" })
		end
	end)
	button:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		UI.TipHide(self)
		if P.live:IsShown() then P.live:Focus(nil) end
	end)
	P.sockets[index] = e
	return e
end

local function PaintSocket(e, socket)
	-- index: its place among the bag slots, which is the bank tab it holds.
	e.index, e.bought, e.bag = socket.slot, socket.bought, FIRST + socket.slot - 1
	local filled = socket.icon ~= nil
	e.icon:SetTexture(socket.icon)
	e.icon:SetShown(filled)
	e.icon:SetDesaturated(socket.locked == true)
	e.slot:Empty(not filled)
	e.color = filled and BagBar.KindColor(e.bag) or nil
	e.slot:Steel(e.color)
	-- An ordinary bag shows its quality; a kind's color says enough.
	e.slot:Quality((filled and not e.color) and socket.quality or nil)
	-- Locked until the one before it is bought.
	e.mark:SetShown(not socket.bought)
	e.mark:SetTexture(Skin.GLYPH.lock)
	UI.Tint(e.mark, SC.idle)
	e.mark:SetAlpha(0.6)
	e.button:SetAlpha(socket.bought and 1 or 0.7)
end

-- The slot that buys the next one: the game's purchase button, which opens its own prompt with the price.
local function PaintBuy(at)
	local cost, can = Bank.Next()
	local b = P.buy
	b.button:SetShown(at ~= nil and cost ~= nil)
	if not (at and cost) then return end
	b.button:ClearAllPoints()
	b.button:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", at[1], -at[2])
	b.button:SetEnabled(can == true)
	UI.Tint(b.mark, can and GOLD or C.dim)
	b.mark:SetAlpha(can and 1 or 0.6)
	b.slot:Steel(can and GOLD or nil)
end

local function BuyTip(self)
	local cost, can = Bank.Next()
	if not cost then return end
	local rows = { { glyph = "coin", text = "Costs", right = Coins(cost), color = C.dim } }
	if not can then rows[2] = { glyph = "coin", text = "You have", right = Coins(GetMoney()), color = C.dim } end
	UI.Tip(self, "Buy a bag slot", can and "Room for one more bag in your bank." or "You can't afford it yet.", {
		side = "RIGHT", sections = { { rows = rows } }, hints = can and { { "left", "Buy" } } or nil,
	})
end

-- Down the column at x: the bag slots bought, the one to buy, the locked ones. Returns how tall it is (0: none).
local function Sockets(x)
	local list = Bank.Sockets()
	local buyAt
	local y = TOP
	for index, socket in ipairs(list) do
		local e = Socket(index)
		local next = not socket.bought and not buyAt
		if next then buyAt = { x, y } end
		e.button:SetShown(not next)
		if not next then
			PaintSocket(e, socket)
			e.button:ClearAllPoints()
			e.button:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", x, -y)
		end
		y = y + SIZE + GAP
	end
	for index = #list + 1, #P.sockets do P.sockets[index].button:Hide() end
	PaintBuy(buyAt)
	P.rule:SetShown(#list > 0)
	if #list == 0 then return 0 end
	P.rule:ClearAllPoints()
	P.rule:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", x - 7, -TOP)
	P.rule:SetHeight(#list * (SIZE + GAP) - GAP)
	return #list * (SIZE + GAP) - GAP
end

local function HideSockets()
	for _, e in ipairs(P.sockets) do e.button:Hide() end
	P.buy.button:Hide()
	P.rule:Hide()
end

-- Layout

local function Size(W, H)
	-- Its content on its body (UI.Body), the window that much bigger than it.
	UI.BodyFit(win, W, H)
	Shy.HUD.Resize(box, win:GetWidth(), win:GetHeight())
end

local function Foot(width, tall, free, slots, right)
	P.foot:ClearAllPoints()
	P.foot:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", EDGE, -(TOP + tall))
	P.foot:SetSize(width, FOOT)
	P.free:SetText(free == 0 and "Full" or (free .. " free"))
	UI.Ink(P.free, free == 0 and C.bad or C.text)
	P.of:SetText(width >= 150 and (" of " .. slots) or "")
	P.right:SetText(right or "")
end

-- The jobs

-- A job's button: its pin (a kind of Shy.Slot's) and its words, lit under the mouse.
local function JobButton(index)
	local b = P.jobs[index]
	if b then return b end
	b = CreateFrame("Button", nil, P.work)
	b:SetHeight(JOB.tall)
	b.fill = b:CreateTexture(nil, "BACKGROUND")
	b.fill:SetAllPoints()
	UI.Paint(b.fill, C.row, 0.95)
	b.fill:Hide()
	-- (A pin sits in from a corner: the corner of a seat its own size.)
	b.seat = b:CreateTexture(nil, "ARTWORK")
	b.seat:SetSize(JOB.seat, JOB.seat)
	b.seat:SetPoint("LEFT", b, "LEFT", JOB.pad, 0)
	b.pin = Shy.Slot.Pin(b, b.seat, "TOPLEFT", JOB.pin)
	b.text = Window.Rounded(b, 11)
	b:SetScript("OnEnter", function(self)
		self.fill:Show()
		if self.says then Shy.Hover.Show(self, self.says, { at = UI.Beside(win, self, { up = true }), keep = false }) end
	end)
	b:SetScript("OnLeave", function(self)
		self.fill:Hide()
		UI.TipHide(self)
	end)
	b:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		if self.job then ns.Guard(self.job.run) end
	end)
	P.jobs[index] = b
	return b
end

-- Lays the jobs that have something to do across `width` under `top`, on as many lines as they take.
-- Returns the room they take under the foot (0: none).
local function Work(live, width, top)
	local shown, x, line = 0, 0, 0
	for _, job in ipairs(live and jobs or {}) do
		local ok, words, says = pcall(job.look)
		if not ok then
			geterrorhandler()(words)
		elseif words then
			shown = shown + 1
			local b = JobButton(shown)
			b.job, b.says = job, says
			b.pin:Set(job.pin)
			b.text:ClearAllPoints()
			b.text:SetPoint("LEFT", b, "LEFT", JOB.pad + (job.pin and JOB.seat + 4 or 0), 0)
			b.text:SetText(words)
			local wide = JOB.pad + (job.pin and JOB.seat + 4 or 0) + b.text:GetStringWidth() + JOB.pad
			if x > 0 and x + wide > width then x, line = 0, line + 1 end
			b:SetWidth(wide)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", P.work, "TOPLEFT", x, -line * JOB.tall)
			b:Show()
			x = x + wide + JOB.between
		end
	end
	for index = shown + 1, #P.jobs do P.jobs[index]:Hide() end
	P.work:SetShown(shown > 0)
	if shown == 0 then return 0 end
	P.work:ClearAllPoints()
	P.work:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", EDGE, -top)
	P.work:SetSize(width, (line + 1) * JOB.tall)
	return JOB.gap + (line + 1) * JOB.tall
end

local function Title(c, isMe)
	local text = "Bank"
	if not isMe then
		local name = Store.Name(c)
		text = name .. (name:sub(-1) == "s" and "'" or "'s") .. " bank"
	end
	P.head.title:SetText(text)
end

local function Lay()
	local mode, c, guid, isMe = Mode()
	P.shown = nil
	if not mode then return end
	Title(c, isMe)
	P.fresh:SetShown(mode == "fresh")
	P.sort:SetShown(mode == "live")
	if mode == "fresh" then
		P.live:Hide()
		P.mem:Hide()
		P.vault:SetShown(false)
		HideSockets()
		local cost = Bank.Next()
		P.open:SetShown(cost ~= nil)
		P.freshText:SetText((cost or 0) > 0 and ("You haven't opened your bank yet.\n\nThe first tab costs " .. Coins(cost) .. ".")
			or "You haven't opened your bank yet.\n\nThe first tab is free.")
		local tall = 4 * STEP
		P.fresh:ClearAllPoints()
		P.fresh:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", EDGE, -TOP)
		P.fresh:SetSize(FRESH_W, tall - Tile.GAP)
		P.foot:Hide()
		Work(false)
		Size(EDGE + FRESH_W + EDGE, TOP + tall + 24)
		P.shown = { mode = mode, guid = guid }
		return
	end

	local live = mode == "live"
	local grid = live and P.live or P.mem
	P.live:SetShown(live)
	P.mem:SetShown(not live)
	grid.prefer = Prefer()
	grid.apart = T.db.apart == true   -- special bags' slots apart or in with the rest, as in your bags
	if live then grid:SetBags(Bank.Tabs()) else grid:SetLists(Lists(c), guid, "bank") end
	grid:Filter(ns.Views.test)
	local columns, rows = grid:Shape()
	if columns == 0 then columns, rows = 4, 4 end
	local gridH = rows * STEP + grid.gap   -- with the room the names over the runs apart take
	local gridW = columns * STEP - Tile.GAP
	local colW, colH = 0, 0
	if live then
		colH = Sockets(EDGE + gridW + SEAM)
		if colH > 0 then colW = SEAM + SIZE end
	else
		HideSockets()
	end
	local tall = math.max(gridH, colH + Tile.GAP)
	P.vault:SetShown(true)
	P.vault.plate:ClearAllPoints()
	P.vault.plate:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", EDGE - Window.VAULT_PAD, -(TOP - Window.VAULT_PAD))
	P.vault.plate:SetSize(gridW + 2 * Window.VAULT_PAD, gridH - Tile.GAP + 2 * Window.VAULT_PAD)
	P.foot:Show()
	local free, slots = grid:Room()
	local seen = (not live and c.bank and c.bank.at) and ("seen " .. ns.Ago(c.bank.at)) or nil
	Foot(gridW + colW, tall, free, slots, seen)
	local work = Work(live, gridW + colW, TOP + tall + FOOT + JOB.gap)
	Size(EDGE + gridW + colW + EDGE, TOP + tall + 24 + work)
	P.shown = { mode = mode, guid = guid, grid = grid, columns = columns, rows = rows }
end

-- The look keeps another clearance round the body (UI.Body): laid out again, the window that much bigger.
Shy:On("SHY_BODY", function(f)
	if f == win then BankWindow.Refresh() end
end)

function BankWindow.Refresh()
	if not win or building then return end
	building = true
	Shy.HUD.Update(box)
	local ok, err = true, nil
	if box:IsShown() then ok, err = pcall(Lay) end
	building = false
	if not ok then geterrorhandler()(err) end
end

-- Open or close the remembered bank of the character the bags window shows (at a banker the bank is up
-- for the whole visit).
function BankWindow.Toggle()
	if Bank.IsLive() then return end
	wanted = not BankWindow.IsShown()
	BankWindow.Refresh()
	Window.Refresh()
end

-- The ×: at a banker it ends the visit, as walking away does; elsewhere it puts the remembered bank away.
local function Close()
	if Bank.IsLive() then
		Bank.Close()
		return
	end
	wanted = false
	BankWindow.Refresh()
	Window.Refresh()
end

-- The window's corner lays the slots wider or taller, a column at a time; what is kept is the column count.
local shaping
local function Reshape(wider, taller, phase, point)
	if phase == "start" then
		shaping = nil
		local s = P.shown
		if InCombatLockdown() or not (s and s.grid) then return end
		local _, slots = s.grid:Room()
		if slots == 0 then return end
		shaping = { columns = s.columns, rows = s.rows, slots = slots, hold = Shy.HUD.Hold(box, point) }
		return
	end
	local m = shaping
	if not m then return end
	local columns = m.columns
	-- A corner goes the way it was moved most; a side, its one way.
	if wider and (not taller or math.abs(wider) >= math.abs(taller)) then
		columns = m.columns + math.floor(wider / STEP + 0.5)
	elseif taller then
		columns = math.ceil(m.slots / math.max(1, m.rows + math.floor(taller / STEP + 0.5)))
	end
	local least, most = Grid.Columns(m.slots)
	columns = math.max(least, math.min(most, columns))
	if columns ~= Prefer() then
		T.db.bankColumns = columns
		BankWindow.Refresh()
	end
	m.hold(phase == "stop")
	if phase == "stop" then shaping = nil end
end

-- Building

local function Build()
	box = Shy.HUD.Create({
		id = "shybags.bank",
		title = "ShyBags bank",
		width = EDGE + FRESH_W + EDGE,
		height = TOP + 4 * STEP + 24,
		-- Where it stands once dragged away from the bags with no place kept: the screen's middle.
		point = { "TOP", "CENTER", 0, 200 },
		shown = function() return Mode() ~= nil end,
		window = true,
		hang = true,
		dock = { to = "shybags", side = "LEFT", label = "Beside the bags" },
	})
	win = CreateFrame("Frame", "ShyBagsBank", box)
	win:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	win:SetSize(box:GetWidth(), box:GetHeight())
	win:SetToplevel(true)
	win:EnableMouse(true)
	P.head = UI.Head(win, { size = "window", title = "Bank", close = Close, panel = { glazed = true } })
	Shy.HUD.DragHandle(box, win)
	if Shy.HUD.Grip then
		Shy.HUD.Grip(box, {
			over = win, core = 8, shape = Reshape, tip = "Drag to make your bank wider or taller.",
			menu = function(root)
				root:CreateCheckbox("Fit bank automatically", function() return not Prefer() end, function()
					local s = P.shown
					T.db.bankColumns = Prefer() and 0 or (s and s.columns or 0)
					BankWindow.Refresh()
				end)
			end,
		})
	end

	-- The slots on the vault's gold: live at a banker, remembered elsewhere.
	P.vault = Window.Vault(win)
	P.live = Grid.New(win, true)
	P.mem = Grid.New(win, false)
	for _, grid in ipairs({ P.live, P.mem }) do
		grid:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", EDGE, -TOP)
		grid:Gild(true)
		grid.onChange = function()
			if not building then BankWindow.Refresh() end
		end
	end

	-- The bag slots, past a hairline, as the bag column stands past the bags.
	P.sockets = {}
	P.rule = win:CreateTexture(nil, "ARTWORK")
	P.rule:SetWidth(1)
	UI.Paint(P.rule, C.border, 0.9)
	P.rule:Hide()
	P.buy = BagBar.NewSlot(win, nil, Bank.PURCHASE)
	Bank.Arm(P.buy.button)
	P.buy.slot:Empty(true)
	P.buy.mark = P.buy.button:CreateTexture(nil, "OVERLAY")
	P.buy.mark:SetSize(12, 12)
	P.buy.mark:SetPoint("CENTER")
	P.buy.mark:SetTexture(Skin.GLYPH.plus)
	P.buy.button:SetMotionScriptsWhileDisabled(true)
	P.buy.button:SetScript("OnEnter", BuyTip)
	P.buy.button:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	P.buy.button:Hide()

	-- A bank never opened: what it is, and the game's button to open it.
	P.fresh = CreateFrame("Frame", nil, win)
	P.fresh:Hide()
	P.freshText = UI.Text(P.fresh, "", 11, false, C.dim)
	P.freshText:SetPoint("BOTTOM", P.fresh, "CENTER", 0, 6)
	P.freshText:SetWidth(FRESH_W - 16)
	P.freshText:SetJustifyH("CENTER")
	P.freshText:SetSpacing(2)
	P.open = CreateFrame("Button", nil, P.fresh, Bank.PURCHASE)
	Bank.Arm(P.open)
	P.open:SetSize(150, 24)
	P.open:SetPoint("TOP", P.fresh, "CENTER", 0, -8)
	UI.ButtonFace(P.open, "Open your bank")
	if P.open.SetPrimary then P.open:SetPrimary(true) end

	-- The foot: room, and the sort (live) or when the bank was seen (remembered).
	P.foot = Window.Plate(win)
	P.free = Window.Rounded(P.foot, 11)
	P.free:SetPoint("LEFT", P.foot, "LEFT", 6, 0)
	P.of = Window.Rounded(P.foot, 11, C.dim)
	P.of:SetPoint("LEFT", P.free, "RIGHT", 0, 0)
	P.right = Window.Rounded(P.foot, 10.5, C.dim)
	P.right:SetPoint("RIGHT", P.foot, "RIGHT", -6, 0)
	P.sort = CreateFrame("Button", nil, P.foot)
	P.sort:SetSize(28, 15)
	P.sort:SetPoint("RIGHT", -1, 0)
	for i, width in ipairs({ 14, 10, 6 }) do
		local bar = P.sort:CreateTexture(nil, "ARTWORK")
		bar:SetSize(width, 2)
		bar:SetPoint("TOPLEFT", P.sort, "CENTER", -7, 8 - i * 4)
		UI.Paint(bar, SC.glyph)
	end
	P.sort:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
		C_Container.SortBank(Enum.BankType.Character)
	end)
	P.sort:SetScript("OnEnter", function(self)
		UI.Tip(self, "Clean up bank", nil, { side = "TOP", hints = { { "left", "Clean up" } } })
	end)
	P.sort:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	P.sort:Hide()

	-- The jobs, under the foot: a plate of its make, a button a job (made as a job first has something to do).
	P.work = Window.Plate(win)
	P.work:Hide()
	P.jobs = {}
end

-- For other addons: a job the bank window offers at a banker.
--   def = { id, order, pin = a Shy.Slot pin's kind (or none), look = function() return words, says end,
--           run = function() end }
--   look: the job's words now ("Take out 3"), nil while it has nothing to do; says: its hover's content
--   (Shy.Hover's), or nil. It is asked whenever the bank or the bags change during a visit, on T:RefreshMarks,
--   and on T:RefreshBank. run: a click on it.
function T:RegisterBankJob(def)
	assert(type(def) == "table" and def.id and def.look and def.run, "a bank job needs an id, a look and a run")
	for index, other in ipairs(jobs) do
		if other.id == def.id then
			table.remove(jobs, index)
			break
		end
	end
	jobs[#jobs + 1] = def
	table.sort(jobs, function(a, b)
		if (a.order or 99) ~= (b.order or 99) then return (a.order or 99) < (b.order or 99) end
		return tostring(a.id) < tostring(b.id)
	end)
	BankWindow.Refresh()
end

function T:RefreshBank()
	if Bank.IsLive() then BankWindow.Refresh() end
end

function BankWindow.Init()
	if not (Window.Looked and Shy.HUD.Find("shybags")) then return end   -- the bags window failed to build
	local ok, err = pcall(Build)
	if not ok then
		win = nil
		T:Print("the bank window failed to load. See your error log.")
		geterrorhandler()(err)
		return
	end
	Takeover.OnChange(function(visible)
		-- Closing the bags puts the remembered bank away with them.
		if not visible then wanted = false end
		BankWindow.Refresh()
	end)
	Bank.OnChange(BankWindow.Refresh)
	Bank.OnSlots(BankWindow.Refresh)
	-- (What the marks say changed: so may what the jobs have to do.)
	ns.Marks.OnRefresh(function()
		if Bank.IsLive() then BankWindow.Refresh() end
	end)
	BankWindow.Refresh()
end
