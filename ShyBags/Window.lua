-- The bag window: a rail of characters on the left, the search box as the title, the bags, and a footer of counts
-- that open the wing (mail, auctions, gold, results, room, keys), the bank and your auctions, each a window of its
-- own docked beside this one (BankWindow.lua, AuctionWindow.lua): on its right, or wherever the screen has room.
-- Your own bags are live slots (Blizzard's item buttons, Tile.lua); other characters are drawn from the store.
-- The window is a Shy.HUD box hung by its top left corner: it grows right and down, kept on the screen.
-- It follows Takeover.lua; if it fails to build, the default bags stay.
--   Window.Look(guid)         show a character (nil: yourself); Window.Looked() returns c, guid, isMe
--   Window.Open(wing)         "mail", "auctions", "gold", "results", "room", "keys" or nil
--   Window.Point(bag, slot)   light one slot alone while making room (nil: all of them)

local ADDON, ns = ...
local T = ns.T
local UI, Skin = Shy.UI, Shy.Skin
local C, SC = UI.colors, Skin.colors
local Store, Tile, Grid, Takeover = ns.Store, ns.Tile, ns.Grid, ns.Takeover
local MEDIA = ns.MEDIA

local Window = {}
ns.Window = Window

T.defaults.window = true
T.defaults.columns = 0   -- slots across, as dragged by the window's corner; 0: the bags fit themselves
T.defaults.apart = true  -- a special bag's slots stand apart under its name (the bank's too); off: in with the rest

local STEP = Tile.SIZE + Tile.GAP
local TOP, RIGHT = 35, 8                  -- slot grid's top offset and right margin
local SPINE = 39                          -- slot grid's left edge, past the character rail
local FOOT, SEAM = 17, 13                 -- footer height, seam width
local SEAT, SEAT_TOP, SEAT_STEP = 22, 36, 27
local GRAB = 28                           -- of the title strip kept bare between the name and the search box
local RAIL_BUTTON = 20                   -- the rail's buttons over the menu (sort again, the bag row's switch)
local RAIL_STEP = RAIL_BUTTON + 4        -- one more above the last
local BOX_W, BOX_H = SPINE + 10 * STEP - Tile.GAP + RIGHT, TOP + 5 * STEP + 24
local LOW = 3   -- free slots at which the count turns gold
local WING_EDGE = 8                       -- the wing window's margin round its content
local WING_MIN = { 2 * 8 + 220, 180 }     -- the least you can size the wing to

local box, win
local P = {}                       -- the window's parts, by name
local railed = {}                  -- other addons' rail buttons (T:RegisterRailButton), in their order
local left = SPINE
local view = { guid = nil, wing = nil }
local query, test = "", nil
local searchOpen = false           -- narrow window: the search box was opened
local seats, doors = {}, {}
local wings = {}                   -- name -> { frame, Show(c, guid, isMe), Width(rows), Foot() }

local function Me() return Store.Guid() end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

local function Rounded(parent, size, color)
	return UI.Words(parent, size or 11, color, { justify = "CENTER" })
end
Window.Rounded = Rounded

-- A plate inside the window (the search box, the footers): the window's own strip, as clear as the Background
-- setting makes the window.
local function Plate(parent)
	local f = CreateFrame("Frame", nil, parent)
	UI.Skin(f, C.hudStrip, C.border)
	return f
end
Window.Plate = Plate

-- The bank's vault, under its gold slots (Tile.GOLD): a plate of warm gold deepening toward its foot, a bright
-- line of gold along its top with a soft glow falling from it, and fine gold sides. v.plate is placed by its
-- owner; the rest follow it. Gold whatever the theme: the bank is where your wealth is kept.
local VAULT = { pad = 4, gold = { 1.0, 0.80, 0.38 }, deep = { 0.42, 0.28, 0.06 }, top = 0.30, foot = 0.14, glow = 10,
	glowA = 0.28, line = 0.95, side = 0.45 }
local function Vault(parent)
	local v = {}
	local g, d = VAULT.gold, VAULT.deep
	local function Region(sub)
		local t = parent:CreateTexture(nil, "BACKGROUND", nil, sub)
		t:SetColorTexture(1, 1, 1, 1)
		v[#v + 1] = t
		return t
	end
	v.plate = Region(1)
	v.plate:SetGradient("VERTICAL", CreateColor(d[1], d[2], d[3], VAULT.foot), CreateColor(g[1], g[2], g[3], VAULT.top))
	v.glow = Region(2)
	v.glow:SetPoint("TOPLEFT", v.plate, "TOPLEFT", 1, -1)
	v.glow:SetPoint("TOPRIGHT", v.plate, "TOPRIGHT", -1, -1)
	v.glow:SetHeight(VAULT.glow)
	v.glow:SetGradient("VERTICAL", CreateColor(g[1], g[2], g[3], 0), CreateColor(g[1], g[2], g[3], VAULT.glowA))
	local line = Region(3)
	line:SetPoint("TOPLEFT", v.plate, "TOPLEFT")
	line:SetPoint("TOPRIGHT", v.plate, "TOPRIGHT")
	line:SetHeight(1)
	line:SetVertexColor(g[1], g[2], g[3], VAULT.line)
	for _, side in ipairs({ "LEFT", "RIGHT" }) do
		local t = Region(3)
		t:SetPoint("TOP" .. side, v.plate, "TOP" .. side, 0, -1)
		t:SetPoint("BOTTOM" .. side, v.plate, "BOTTOM" .. side)
		t:SetWidth(1)
		t:SetGradient("VERTICAL", CreateColor(d[1], d[2], d[3], VAULT.side * 0.6), CreateColor(g[1], g[2], g[3], VAULT.side))
	end
	local foot = Region(3)
	foot:SetPoint("BOTTOMLEFT", v.plate, "BOTTOMLEFT", 1, 0)
	foot:SetPoint("BOTTOMRIGHT", v.plate, "BOTTOMRIGHT", -1, 0)
	foot:SetHeight(1)
	foot:SetVertexColor(d[1], d[2], d[3], VAULT.side)
	function v:SetShown(on)
		for _, t in ipairs(self) do t:SetShown(on) end
	end
	return v
end
Window.Vault, Window.VAULT_PAD = Vault, VAULT.pad

local function Rule(parent)
	local t = parent:CreateTexture(nil, "ARTWORK")
	UI.Paint(t, C.border, 0.9)
	return t
end

-- Returns the character shown, its guid, and whether it is you.
local function Who()
	local guid = view.guid or Me()
	local c = guid and Store.Char(guid)
	if not c then guid, c = Me(), Store.Me() end
	return c, guid, guid == Me()
end
Window.Looked = Who

-- The bank window is up (for the character shown: it follows this window).
local function BankUp()
	return ns.BankWindow ~= nil and ns.BankWindow.IsShown()
end

local function Possessive(name)
	return name .. (name:sub(-1) == "s" and "'" or "'s")
end

-- The filter for live slots: the search, and while making room only the lit (or pointed) slots.
local pointed
local function Sift()
	local room = ns.Room
	if not (room and room.On()) then return test end
	local typed, only = test, pointed
	return function(item)
		if typed and not typed(item) then return false end
		if not item.live then return false end
		if only then return item.bag == only[1] and item.slot == only[2] end
		return room.Lit(item.bag, item.slot) ~= nil
	end
end

-- One bag's slots, empty ones too, stand out in `color` while the rest dim (nil: none).
function Window.Focus(bag, color)
	if P.live then P.live:Focus(bag, color) end
end

-- Footer: free slots, the doors, gold

-- The auctions window is up.
local function AuctionsUp()
	return ns.AuctionWindow ~= nil and ns.AuctionWindow.IsShown()
end

-- Whether a door's place is open: its wing, or the bank's or the auctions' window for their doors.
local function DoorOpen(wing)
	if wing == "bank" then return BankUp() end
	if wing == "auctions" then return AuctionsUp() end
	return view.wing == wing
end

-- What a door opens, said under the mouse: what it is and where it opens. Its count is on the door itself.
local DOOR_SAYS = {
	bank = { "Bank", "Your bank as last seen, in a window beside the bags." },
	mail = { "Mail", "Your mailbox as last seen, beside the bags." },
	auctions = { "Auctions", "Your auctions as last seen, beside the bags." },
}

-- The gold door's hover, the one door that shows more than a line: every character of this realm and their gold,
-- then, under it, who has gold waiting in the mail or from sold auctions, and how much.
local function GoldTip(door)
	local gold = ns.Views.Gold()
	local rows, owed = {}, {}
	for _, row in ipairs(gold.rows) do
		local c = row.char
		local class = c.class and C_ClassColor.GetClassColor(c.class)
		local color = class and { class.r, class.g, class.b } or C.text
		rows[#rows + 1] = { text = Store.Name(c), color = color, right = Coins(row.hand), rightColor = C.text }
		local waiting = row.mail + row.sold
		if waiting > 0 then owed[#owed + 1] = { text = Store.Name(c), color = color, right = Coins(waiting), rightColor = C.alert } end
	end
	local sections = { { title = "On this realm", rows = rows } }
	if #owed > 0 then sections[2] = { title = "Waiting in the mail", rows = owed } end
	-- Your currencies, all your characters' together.
	local held = {}
	for _, cur in ipairs(ns.Views.Currencies()) do
		held[#held + 1] = { text = cur.name, icon = cur.icon, right = BreakUpLargeNumbers(cur.total), rightColor = C.text }
	end
	if #held > 0 then sections[#sections + 1] = { title = "Currencies", rows = held } end
	UI.Tip(door, "Gold", nil, { side = "TOP", note = Coins(gold.hand), sections = sections,
		hints = { { "left", "Open beside the bags" } } })
end

-- A door: a footer button that opens a wing (the bank's, the bank window).
local function Door(parent, glyph, wing)
	local d = CreateFrame("Button", nil, parent)
	d:SetHeight(15)
	d.fill = d:CreateTexture(nil, "BACKGROUND")
	d.fill:SetAllPoints()
	UI.Paint(d.fill, C.row, 0.95)
	d.fill:Hide()
	d.edge = Rule(d)
	d.edge:SetPoint("TOPLEFT")
	d.edge:SetPoint("BOTTOMLEFT")
	d.edge:SetWidth(1)
	d.lit = d:CreateTexture(nil, "OVERLAY")
	d.lit:SetPoint("BOTTOMLEFT", d, "TOPLEFT", 0, 0)
	d.lit:SetPoint("BOTTOMRIGHT", d, "TOPRIGHT", 0, 0)
	d.lit:SetHeight(2)
	UI.Paint(d.lit, C.hot)
	d.lit:Hide()
	if glyph then
		d.glyph = d:CreateTexture(nil, "ARTWORK")
		d.glyph:SetTexture(MEDIA .. glyph)
		d.glyph:SetSize(16, 16)
		d.glyph:SetPoint("CENTER", d, "LEFT", 6 + 5.5, 0)
		UI.Tint(d.glyph, C.dim)
		-- (The quest's mark on its corner, while the place holds something a quest needs with you: DoorPins.)
		d.pin = Shy.Slot.Pin(d, d.glyph, "TOPRIGHT", 10)
	end
	d.text = Rounded(d, 11)
	d.text:SetPoint("LEFT", d, "LEFT", glyph and 21 or 6, 0)
	d.wing = wing
	d:SetScript("OnEnter", function(self)
		self.fill:Show()
		if self.glyph then UI.Tint(self.glyph, C.head) end
		if self.wing == "gold" then return GoldTip(self) end
		local say = DOOR_SAYS[self.wing]
		if say then UI.Tip(self, say[1], say[2], { side = "TOP" }) end
	end)
	d:SetScript("OnLeave", function(self)
		self.fill:SetShown(DoorOpen(self.wing))
		if self.glyph then UI.Tint(self.glyph, self.urgent and C.alert or C.dim) end
		UI.TipHide(self)
	end)
	d:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		if self.wing == "bank" then
			if ns.BankWindow then ns.BankWindow.Toggle() end
		elseif self.wing == "auctions" and ns.AuctionWindow then
			ns.AuctionWindow.Toggle()
		else
			Window.Open(view.wing ~= self.wing and self.wing or nil)
		end
	end)
	-- Sets the text and sizes the door to it. With no text, a glyph alone, gold when it says something urgent.
	function d:Say(text, color, urgent)
		self.text:SetText(text)
		UI.Ink(self.text, color or C.text)
		self.urgent = urgent and text == "" or nil
		if self.glyph then UI.Tint(self.glyph, self.urgent and C.alert or C.dim) end
		self:SetWidth((self.glyph and 21 or 6) + (text ~= "" and self.text:GetStringWidth() or -4) + 6)
	end
	return d
end

-- What another addon says a place holds that a quest needs with you (T:Holds: "bank", "mail"): the quest's
-- mark stands on that door of your own, so the bags say where to go for it.
local holds = {}
local function DoorPins(isMe)
	local marked = ns.Marks.On("quest")   -- the quest's mark switched off is off here too
	for _, name in ipairs({ "bank", "mail" }) do
		local door = doors[name]
		local held = false
		for _, test in ipairs(marked and isMe and door and door:IsShown() and holds or {}) do
			local ok, yes = pcall(test, name)
			if ok and yes then held = true end
		end
		if door and door.pin then door.pin:Set(held and "quest" or nil) end
	end
end

-- Each returns the long text, the short text, and whether it is urgent.
-- At a banker the bank window is up for the visit: no door to it.
local function BankFact(c)
	if not c.bank or ns.Bank.IsLive() then return nil end
	local free, any = 0, false
	for key, list in pairs(c.bank) do
		if type(key) == "number" then
			any = true
			for _, slot in ipairs(list) do
				if slot == "" then free = free + 1 end
			end
		end
	end
	if not any then return nil end
	return free .. " free", "", false
end

local function MailFact(c)
	local rows = c.mail and c.mail.rows or {}
	if #rows == 0 then return nil end
	local gold, soon = 0, false
	for _, row in ipairs(rows) do
		gold = gold + (row.money or 0)
		if not row.sent then
			local _, pressing = ns.Views.Left(row.exp)
			soon = soon or pressing
		end
	end
	local long
	if soon then
		local first
		for _, row in ipairs(rows) do
			if not row.sent and (not first or row.exp < first) then first = row.exp end
		end
		long = #rows .. " \194\183 " .. ns.Views.Left(first)
	elseif gold > 0 then
		long = #rows .. " \194\183 " .. Coins(gold)
	else
		long = #rows .. " \194\183 " .. (#rows == 1 and "letter" or "letters")
	end
	return long, tostring(#rows), soon
end

local function AuctionFact(c)
	local list = c.auctions or {}
	if #list == 0 then return nil end
	local up, sold = 0, 0
	for _, auction in ipairs(list) do
		if auction.sold then sold = sold + 1 else up = up + 1 end
	end
	local long = up .. " up"
	if sold > 0 then long = long .. " \194\183 " .. Shy.Theme.Wrap(C.alert, sold .. " sold") end
	return long, tostring(up + sold), false
end

-- Returns true when the foot needs the window wider (P.footNeed): the caller lays it out again.
local function Foot(isMe, c)
	local grid = isMe and P.live or P.mem
	local free, slots = grid:Room()
	-- Your own count excludes special bags (quiver, herb bag): "Full" must mean no room for loot.
	if isMe and ns.Room then free, slots = ns.Room.Free() end
	local width = P.foot:GetWidth()

	local facts = {
		bank = { BankFact(c) }, mail = { MailFact(c) }, auctions = { AuctionFact(c) },
	}
	local coins = c.money and Coins(c.money) or ""
	-- Tight: the largest coin alone (25g), never a run of coins under the slots.
	local tight = (c.money and c.money >= 10000) and Coins(math.floor(c.money / 10000) * 10000) or coins
	-- Its currencies (Merchant's Favor) on the gold's door before the gold: those it shows on its backpack, else its
	-- largest two.
	local purse = {}
	for _, cur in ipairs(ns.Views.Carried(c, 2)) do
		purse[#purse + 1] = ("|T%s:11:11:0:0|t %s"):format(tostring(cur.icon or ""), BreakUpLargeNumbers(cur.n))
	end
	purse = #purse > 0 and (table.concat(purse, "  ") .. "   ") or nil

	-- The longest wording that fits: long count and doors, then a short count, then short doors, then doors as
	-- glyphs alone and the gold as its largest coin. Even that too wide, the window widens to it (Layout).
	local function Try(longCount, longDoors, glyphs, tightGold, currencies)
		local count, of = "", ""
		if slots == 0 then
			count = "no bags saved"
		elseif isMe then
			count = free == 0 and "Full" or (free .. " free")
			if longCount and free > 0 then of = " of " .. slots end
		else
			local age = c.bags and c.bags.at and ("seen " .. ns.Ago(c.bags.at)) or ""
			if longCount then count, of = free .. " free", "  " .. age else count = age end
		end
		P.free:SetText(count)
		P.of:SetText(of)
		local used = 6 + P.free:GetStringWidth() + P.of:GetStringWidth() + 6
		for _, name in ipairs({ "bank", "mail", "auctions" }) do
			local fact, door = facts[name], doors[name]
			door:SetShown(fact[1] ~= nil)
			if fact[1] then
				door:Say(glyphs and "" or (longDoors and fact[1] or fact[2]), fact[3] and C.alert or C.text, fact[3])
				used = used + door:GetWidth()
			end
		end
		doors.gold:Say((currencies and purse or "") .. (tightGold and tight or coins))
		return used + doors.gold:GetWidth() <= width, used + doors.gold:GetWidth()
	end
	-- The currencies stay while anything else can give way; they go before the gold is cut to its largest coin.
	local fits = Try(true, true, false, false, true) or Try(false, true, false, false, true)
		or Try(false, false, false, false, true) or Try(false, false, true, false, true) or Try(false, false, true)
	if not fits then
		local ok, need = Try(false, false, true, true)
		-- (Asked once: the window is laid out again that much wider, and the foot said again.)
		if not ok and not P.footWide then
			P.footNeed = need
			return true
		end
	end

	UI.Ink(P.free, (not isMe and C.text) or (free == 0 and C.bad) or (free <= LOW and C.alert) or C.text)

	local x = 6 + P.free:GetStringWidth() + P.of:GetStringWidth() + 6
	P.home:SetWidth(x - 1)
	-- The count is clickable: into making room (own bags only).
	local room = isMe and ns.Room or nil
	P.home:EnableMouse(room ~= nil)
	if P.homeLit then P.homeLit:SetShown(room ~= nil and room.On()) end
	for _, name in ipairs({ "bank", "mail", "auctions" }) do
		local door = doors[name]
		if door:IsShown() then
			door:ClearAllPoints()
			door:SetPoint("LEFT", P.foot, "LEFT", x, 0)
			x = x + door:GetWidth()
			door.fill:SetShown(DoorOpen(name))
			door.lit:SetShown(DoorOpen(name))
		end
	end
	doors.gold.fill:SetShown(view.wing == "gold")
	doors.gold.lit:SetShown(view.wing == "gold")
	DoorPins(isMe)
end

-- Character rail

-- The first letters of a word, as many as `count`; UTF-8 characters are kept whole.
local function Letters(word, count)
	local letters = {}
	for letter in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		letters[#letters + 1] = letter
		if #letters == count then break end
	end
	return table.concat(letters)
end

-- The name's first letter and the surname's, upper-cased. With no surname, the name's first two.
local function Initials(c)
	if c.surname and c.surname ~= "" then return (Letters(c.name, 1) .. Letters(c.surname, 1)):upper() end
	return Letters(c.name, 2):upper()
end

-- Characters as UI.Menu rows.
function Window.Faces(list)
	local _, looked = Who()
	local rows = {}
	for _, entry in ipairs(list) do
		local c, guid = entry.char, entry.guid
		local color = c.class and C_ClassColor.GetClassColor(c.class)
		local rgb = color and { color.r, color.g, color.b } or nil
		local on = guid == looked
		local sub
		if guid == Me() then
			sub = "this character"
		elseif c.bags and c.bags.at then
			sub = "bags seen " .. ns.Ago(c.bags.at)
		else
			sub = "not scanned yet"
		end
		rows[#rows + 1] = {
			text = Store.Name(c), color = rgb, sub = sub,
			detail = c.money and Coins(c.money) or nil,
			icon = { MEDIA .. "SeatDisc", { MEDIA .. (on and "SeatRingOn" or "SeatRing"), on and rgb or SC.idle } },
			iconText = Initials(c),
			on = on,
			click = function() Window.Look(guid) end,
		}
	end
	return rows
end

-- A face's right-click: remove a character that is gone, with everything remembered of it. The row has
-- to be clicked twice. Never offered for the one being played.
local function SeatMenu(seat)
	local guid, sure = seat.guid, false
	UI.Menu(seat, function()
		local c = Store.Char(guid)
		if not c then return {} end
		return {
			{ heading = Store.Name(c) },
			{
				text = sure and "Sure? Remove" or "Remove character", color = sure and C.bad or nil, keep = not sure,
				tip = "For a character you've deleted. Forgets its bags, bank, mail, auctions and gold.",
				click = function()
					if sure then Window.Forget(guid) else sure = true end
				end,
			},
		}
	end, { side = "cursor" })
end

local function Seat(index)
	local seat = seats[index]
	if seat then return seat end
	seat = CreateFrame("Button", nil, win)
	seat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	seat:SetSize(SEAT, SEAT)
	seat.disc = seat:CreateTexture(nil, "BACKGROUND")
	seat.disc:SetTexture(MEDIA .. "SeatDisc")
	seat.disc:SetSize(32, 32)
	seat.disc:SetPoint("CENTER")
	seat.ring = seat:CreateTexture(nil, "ARTWORK")
	seat.ring:SetSize(32, 32)
	seat.ring:SetPoint("CENTER")
	seat.pointer = seat:CreateTexture(nil, "ARTWORK")
	seat.pointer:SetTexture(MEDIA .. "SeatPointer")
	seat.pointer:SetSize(8, 8)
	seat.pointer:SetPoint("CENTER", seat, "RIGHT", 4, 0)
	UI.Tint(seat.pointer, C.hot)
	-- The name font covers every alphabet; no shadow, which would shift the letters off centre.
	seat.text = seat:CreateFontString(nil, "OVERLAY")
	seat.text:SetFontObject(UI.NameFont(9))
	seat.text:SetPoint("CENTER", seat, "CENTER", 0, 0)
	seat.text:SetJustifyH("CENTER")
	seat.text:SetJustifyV("MIDDLE")
	seat.text:SetShadowColor(0, 0, 0, 0)
	-- Search hits on this character.
	seat.badge = seat:CreateTexture(nil, "OVERLAY", nil, 1)
	seat.badge:SetTexture(MEDIA .. "Badge")
	seat.badge:SetSize(16, 16)
	seat.badge:SetPoint("CENTER", seat, "BOTTOMRIGHT", -1, 3)
	UI.Tint(seat.badge, C.alert)
	seat.hits = Rounded(seat, 8.5, C.onAlert)
	seat.hits:SetDrawLayer("OVERLAY", 2)
	seat.hits:SetPoint("CENTER", seat.badge, "CENTER", 0, 0)
	seat:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			UI.TipHide(self, true)
			if self.guid and self.guid ~= Me() then SeatMenu(self) end
		elseif self.more then
			UI.Menu(self, Window.Faces(self.more), { side = "right", icon = SEAT, art = 32 })
		else
			Window.Look(self.guid)
		end
	end)
	seat:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		-- Under the mouse a seat not shown lifts its ring (the shown one already stands lit in its class color).
		if not self.on then UI.Tint(self.ring, C.head) end
		if not self.guid then return end
		local c = Store.Char(self.guid)
		if not c then return end
		local rows = {}
		if c.money then rows[#rows + 1] = { glyph = "coin", text = "Gold", right = Coins(c.money), color = C.dim } end
		if self.guid ~= Me() and c.bags and c.bags.at then
			rows[#rows + 1] = { glyph = "clock", text = "Bags seen", right = ns.Ago(c.bags.at), color = C.dim, rightColor = C.dim }
		end
		local class = c.class and C_ClassColor.GetClassColor(c.class)
		-- Out to the left of the rail, clear of the bags (on the right where the screen's edge leaves no room).
		UI.Tip(self, Store.Name(c), nil, { side = "LEFT", note = c.class and LOCALIZED_CLASS_NAMES_MALE[c.class] or nil,
			color = class and { class.r, class.g, class.b } or nil,
			sections = #rows > 0 and { { rows = rows } } or nil,
			hints = self.guid ~= Me() and { { "left", "Show bags" }, { "right", "Remove" } } or { { "left", "Show bags" } } })
	end)
	seat:SetScript("OnLeave", function(self)
		self:SetAlpha(self.on and 1 or 0.82)
		if not self.on then UI.Tint(self.ring, SC.idle) end
		UI.TipHide(self)
	end)
	seats[index] = seat
	return seat
end

local function PlaceSeat(seat, index)
	seat:ClearAllPoints()
	seat:SetPoint("TOPLEFT", UI.Body(win), "TOPLEFT", 5, -(SEAT_TOP + (index - 1) * SEAT_STEP))
end

-- The rail: as many characters as fit, the rest behind a "+N" seat, and the menu button at the bottom.
local function Spine(looked, rows)
	local list = Store.List()
	local fit = math.max(2, math.floor((TOP + rows * STEP - 9 - SEAT_TOP + 5 - (2 + (P.railedShown or 0)) * RAIL_STEP) / SEAT_STEP))
	local shown, rest = {}, {}
	if #list <= fit then
		shown = list
	else
		-- One seat is the "+N"; you and the character shown always keep a seat.
		local keep, place = fit - 1, {}
		for index, entry in ipairs(list) do
			place[entry] = index
			if entry.guid == Me() or entry.guid == looked then shown[#shown + 1] = entry end
		end
		for _, entry in ipairs(list) do
			if entry.guid ~= Me() and entry.guid ~= looked then
				if #shown < keep then shown[#shown + 1] = entry else rest[#rest + 1] = entry end
			end
		end
		table.sort(shown, function(a, b) return place[a] < place[b] end)
	end
	local n = 0
	for _, entry in ipairs(shown) do
		n = n + 1
		local seat, c = Seat(n), entry.char
		PlaceSeat(seat, n)
		seat.guid, seat.more, seat.on = entry.guid, nil, entry.guid == looked
		local color = c.class and C_ClassColor.GetClassColor(c.class)
		seat.text:SetText(Initials(c))
		if color then seat.text:SetTextColor(color.r, color.g, color.b) else UI.Ink(seat.text, C.text) end
		seat.ring:SetTexture(MEDIA .. (seat.on and "SeatRingOn" or "SeatRing"))
		if seat.on and color then seat.ring:SetVertexColor(color.r, color.g, color.b) else UI.Tint(seat.ring, SC.idle) end
		seat.pointer:SetShown(seat.on)
		local hits = P.hits and P.hits[entry.guid]
		seat.badge:SetShown(hits ~= nil)
		seat.hits:SetText(hits and tostring(hits) or "")
		seat:SetAlpha((seat.on or hits) and 1 or 0.82)
		seat:Show()
	end
	if #rest > 0 then
		n = n + 1
		local seat = Seat(n)
		PlaceSeat(seat, n)
		seat.guid, seat.more, seat.on = nil, rest, false
		seat.text:SetText("+" .. #rest)
		UI.Ink(seat.text, C.head)
		seat.ring:SetTexture(MEDIA .. "SeatRing")
		UI.Tint(seat.ring, SC.idle)
		seat.pointer:Hide()
		seat.badge:Hide()
		seat.hits:SetText("")
		seat:SetAlpha(0.82)
		seat:Show()
	end
	for index = n + 1, #seats do seats[index]:Hide() end
end

-- The bags' shape: the window's corner is dragged to lay the slots wide, tall or square. What is kept is
-- the column count (0: the bags fit themselves), and the rows follow from the slots there are.

-- The most columns and the most rows the screen has room for.
local function Room()
	local scale = box:GetEffectiveScale()
	local l, t, r, b = UI.BodyIn(win)   -- (the look's clearance round the body: UI.Body)
	local across = math.floor((GetScreenWidth() / scale - SPINE - RIGHT - l - r + Tile.GAP) / STEP)
	local down = math.floor((GetScreenHeight() / scale - TOP - 24 - t - b - P.live.gap) / STEP)
	return math.max(1, across), math.max(1, down)
end

-- The fewest and the most columns `slots` may be laid in here.
local function Span(slots)
	local least, most = Grid.Columns(slots)
	local across, down = Room()
	most = math.max(least, math.min(most, across))
	least = math.min(most, math.max(least, math.ceil(slots / down)))
	return least, most
end

-- The column count the player chose, or nil while the bags fit themselves.
local function Prefer()
	local columns = T.db.columns
	if columns <= 0 then return nil end
	local across = Room()
	return math.min(columns, across)
end

local function BagSlots(c, isMe)
	if isMe and P.live.count > 0 then return P.live.count end
	local slots = 0
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
		slots = slots + #(c.bags and c.bags[bag] or {})
	end
	return slots
end

-- Columns and rows of a character's bags; a stored bank shown in their place reuses the shape.
local function BagShape(c, isMe)
	if isMe then
		local columns, rows = P.live:Shape()
		if columns > 0 then return columns, rows end
	end
	return Grid.Fit(BagSlots(c, isMe), Prefer())
end

-- The shapes `slots` can take, narrowest first: for each number of rows, the fewest columns that make it,
-- so each is wider and lower than the one before and none has a row it doesn't need. grid: the one that
-- holds them, asked for its rows (a run that stands apart starts a row of its own).
local function Shapes(slots, grid)
	local least, most = Span(slots)
	local list = {}
	for columns = least, most do
		local rows = grid and grid:Down(columns) or math.ceil(slots / columns)
		if #list == 0 or list[#list].rows ~= rows then list[#list + 1] = { columns = columns, rows = rows } end
	end
	return list
end

-- The key ring, while it is open.
wings.keys = {
	Show = function(_, _, _, rows)
		P.keys.rows = rows
		P.keys:SetBags({ Enum.BagIndex.Keyring })
		local columns = P.keys:Shape()
		local free, slots = P.keys:Room()
		local keys = slots - free
		return math.max(1, columns) * STEP - Tile.GAP, "Keys", keys .. (keys == 1 and " key" or " keys"), ""
	end,
}

for name, wing in pairs(ns.Views.Wings) do wings[name] = wing end

-- Layout

-- The band (the bag column, BagBar.lua) stands beside the grid while it is open.
local function BandOpen()
	return P.band ~= nil and P.bandGet(P.mine) == true
end

-- The rail's buttons, for your own bags: "sort again" lit while its order is in use, gold once the bags
-- have changed since; the bag row's switch lit while the row is open.
local function Rail(mine)
	local order = ns.Order
	P.sortRail:SetShown(mine == true and order ~= nil)
	if mine and order then
		local _, _, inUse = order.Latest()
		local changed = inUse and not P.live:Settled()
		P.sortRail:Lit(inUse, changed and C.alert or nil)
	end
	P.bandToggle:SetShown(P.band ~= nil and mine == true)
	if P.band then P.bandToggle:Lit(BandOpen()) end
	-- Other addons' buttons, above the bag row's switch: each asked whether it shows, is lit, glimmers, and set in
	-- its place as it is shown (a button made after the window was laid out would stand at the rail's foot).
	local shown = 0
	for _, def in ipairs(railed) do
		local on = mine == true and (def.shown == nil or def.shown() == true)
		if on and not def.button and P.RailButton then
			local b = P.RailButton(nil, 0)
			b.railBottom = nil
			if def.icon then Shy.Theme.Icon(b.glyph, def.icon, 16) end
			b:SetScript("OnClick", function(self)
				UI.TipHide(self, true)
				def.click()
			end)
			if def.tip then b:HookScript("OnEnter", function(self) def.tip(self) end) end
			def.button = b
		end
		local b = def.button
		if b then
			b:SetShown(on)
			if on then
				shown = shown + 1
				local bottom = 7 + FOOT + 4 + 1 + 4 + (shown + 1) * RAIL_STEP
				if b.railBottom ~= bottom then
					b.railBottom = bottom
					b:ClearAllPoints()
					b:SetPoint("BOTTOMLEFT", UI.Body(win), "BOTTOMLEFT", 4, bottom)
				end
				b:Lit(def.lit and def.lit() or false)
				UI.Glimmer(b, def.glimmer and def.glimmer() or false)
			else
				UI.Glimmer(b, false)
			end
		end
	end
	P.railedShown = shown
end

-- The wing is a window of its own, docked to the bags. Beside them it is as tall as they are, its rows level with
-- theirs, and its width is yours; anywhere else its height is yours too. It is never narrower than its list asks.
-- Its list fills what room it has: it flows as you size it.
local WING_FOOT = 24                       -- of the wing's body under its list: its foot, as the bags' is
local function LayWing(wingWidth)
	P.wing:SetShown(wingWidth ~= nil)
	P.wingFoot:SetShown(wingWidth ~= nil)
	Shy.HUD.Update(P.wingBox)
	if not wingWidth then return end
	local l, t, r, b = UI.BodyIn(P.wingWin)
	-- As wide as you made it, else as its list asks; a wider list (gold's) widens it while it shows. With a grip,
	-- the list's width is the size the wing is made at (HUD.Made), and the grip keeps yours over it.
	local want = WING_EDGE + wingWidth + WING_EDGE + l + r
	local grip = Shy.HUD.Grip and Shy.HUD.Grip(P.wingBox)
	if grip and Shy.HUD.Made then
		if not P.flowing then Shy.HUD.Made(P.wingBox, want, box:GetHeight()) end
	else
		local w = math.max(P.wingHand or 0, want)
		local h = Shy.HUD.DockTall(P.wingBox) or P.wingBox:GetHeight()
		-- (Sized by its grip, the grip has the say: it is only laid out.)
		if not P.flowing and (math.abs(w - P.wingBox:GetWidth()) > 0.5 or math.abs(h - P.wingBox:GetHeight()) > 0.5) then
			Shy.HUD.Resize(P.wingBox, w, h)
		end
	end
	local body = UI.Body(P.wingWin)
	P.wing:ClearAllPoints()
	P.wing:SetPoint("TOPLEFT", body, "TOPLEFT", WING_EDGE, -TOP)
	P.wing:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -WING_EDGE, WING_FOOT + Tile.GAP)
	P.wingFoot:ClearAllPoints()
	P.wingFoot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", WING_EDGE, WING_FOOT - FOOT)
	P.wingFoot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -WING_EDGE, WING_FOOT - FOOT)
	P.wingFoot:SetHeight(FOOT)
end

-- How many rows of slots tall the wing's list is, from the height the wing has: beside a window (the bags, the
-- bank), as tall as that one is now; else as tall as you made it.
local function WingRows()
	local _, t, _, b = UI.BodyIn(P.wingWin)
	local h = Shy.HUD.DockTall(P.wingBox) or P.wingBox:GetHeight()
	return math.max(1, (h - t - b - TOP - WING_FOOT) / STEP)
end

-- The wing's list shown for the room the wing has, and the wing laid out round it.
local function FillWing()
	local s = P.shown
	local wing = s and s.wing and wings[s.wing]
	if not wing then return LayWing(nil) end
	local wingWidth, title, detail, right = wing.Show(s.c, s.guid, s.isMe, WingRows())
	P.wingTitle:SetText(title)
	P.wingDetail:SetText(detail or "")
	P.wingRight:SetText(right or "")
	s.wingWidth = wingWidth
	LayWing(wingWidth)
end

-- Everything stands on the window's body (UI.Body): clear of the look's work round the edge, the window that much
-- bigger (UI.BodyFit). Returns the window's whole width.
local function Layout(columns, rows, wingWidth)
	local body = UI.Body(win)
	local band = BandOpen()
	local top = TOP
	local bagW = columns * STEP - Tile.GAP
	-- The bag column stands beside the grid, a seam off, so opening it widens the window and nothing on
	-- the left moves; a column taller than the grid makes the window taller.
	-- (The names over the runs that stand apart take room of their own, over the rows'.)
	local tall, colW = rows * STEP + (P.live:IsShown() and P.live.gap or 0), 0
	if band then
		colW = SEAM + P.band:GetWidth()
		tall = math.max(tall, P.band:GetHeight() + Tile.GAP)
	end
	local gridH = tall - Tile.GAP
	local gx = left
	local fy = top + tall
	-- The foot is never narrower than its shortest wording needs (Foot): the window widens to it.
	local footW = math.max(bagW + colW, P.footNeed or 0)
	local W, H = gx + footW + RIGHT, fy + 24
	UI.BodyFit(win, W, H)
	-- HUD.Resize keeps the top left corner in place.
	Shy.HUD.Resize(box, win:GetWidth(), win:GetHeight())

	if P.band then
		P.band:SetShown(band)
		P.band:ClearAllPoints()
		P.band:SetPoint("TOPLEFT", body, "TOPLEFT", gx + bagW + SEAM, -top)
	end
	for _, grid in ipairs({ P.live, P.mem }) do
		grid:ClearAllPoints()
		grid:SetPoint("TOPLEFT", body, "TOPLEFT", gx, -top)
	end
	P.foot:ClearAllPoints()
	P.foot:SetPoint("TOPLEFT", body, "TOPLEFT", gx, -fy)
	P.foot:SetSize(footW, FOOT)

	P.spineRule:SetPoint("TOPLEFT", body, "TOPLEFT", 32, -30)
	P.spineRule:SetSize(1, H - 35)
	-- The rail's foot: the menu, its rule and the buttons over it.
	P.menu:ClearAllPoints()
	P.menu:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 5, 7)
	P.divide:ClearAllPoints()
	P.divide:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 8, 7 + FOOT + 4)
	for _, b in ipairs({ P.sortRail, P.bandToggle }) do
		b:ClearAllPoints()
		b:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, b.railBottom)
	end
	for _, def in ipairs(railed) do
		local b = def.button
		if b and b:IsShown() then
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 4, b.railBottom)
		end
	end
	for index, seat in pairs(seats) do PlaceSeat(seat, index) end

	return win:GetWidth()
end

-- The window is never thrown from one shape to another. Held by an edge it is drawn wherever between
-- two shapes the mouse has it (`morph`, further down); given another shape with no hand on it (the fit
-- switched back on) it glides there, as the slots slide to their new places (Grid.SLIDE, the same ease).
local morph                        -- an edge is held, or was just let go: see Reshape
local easing                       -- the next layout glides to its shape
local drawn                        -- the columns and rows the window is drawn at: fractions between shapes
local glide
local glider = CreateFrame("Frame")

local function Glide(self, elapsed)
	local t = math.min(1, glide.t + elapsed / Grid.SLIDE)
	glide.t = t
	local left = 1 - t
	local eased = 1 - left * left * left
	local columns = glide.fromColumns + (glide.columns - glide.fromColumns) * eased
	local rows = glide.fromRows + (glide.rows - glide.fromRows) * eased
	if t >= 1 then
		columns, rows = glide.columns, glide.rows
		self:SetScript("OnUpdate", nil)
	end
	drawn = { columns, rows }
	Layout(columns, rows, glide.wingWidth)
	if t >= 1 then glide = nil end
end

-- Lays the window out for a shape and returns its width there.
local function Settle(columns, rows, wingWidth)
	-- An edge is in the player's hand: the window stays where that has it.
	if morph then return Layout(drawn[1], drawn[2], wingWidth) end
	local W = Layout(columns, rows, wingWidth)
	if easing and drawn and (drawn[1] ~= columns or drawn[2] ~= rows) then
		glide = { fromColumns = drawn[1], fromRows = drawn[2], columns = columns, rows = rows,
			wingWidth = wingWidth, t = 0 }
		Layout(drawn[1], drawn[2], wingWidth)   -- drawn where it was: it leaves from there
		glider:SetScript("OnUpdate", Glide)
	else
		glide = nil
		glider:SetScript("OnUpdate", nil)
		drawn = { columns, rows }
	end
	return W
end

-- The title strip: the character's name and the search box. In a narrow window the search box is a
-- button until opened, then replaces the name while it has text or focus.
local function Title(W, c, bankStands)
	local x = 30      -- past the emblem
	-- The search stands in the ×'s cluster: `apart` from it, as every header control.
	local right = UI.HeadCloseRight(win.shyLook or win, UI.HEAD.window) + UI.HEAD.window.control + UI.HEAD.window.apart
	local room = W - x - right
	local wide = room >= 300
	local open = wide or searchOpen or query ~= ""
	local width = wide and math.max(120, math.min(210, room - 120 - GRAB)) or room

	local mid = win.shyLook and -UI.HeadStripMid(win.shyLook, UI.HEAD.window, UI.HEAD.window.control) or (UI.HEAD.window.lip + UI.HEAD.window.line) / 2
	P.search:SetShown(open)
	P.search:ClearAllPoints()
	P.search:SetPoint("RIGHT", win, "TOPRIGHT", -right, -mid)
	P.search:SetWidth(width)
	P.glass:SetShown(not open)
	P.glass:ClearAllPoints()
	P.glass:SetPoint("RIGHT", win, "TOPRIGHT", -right, -mid)

	-- The name is only as wide as its text, and stops GRAB short of the search box, so the strip between
	-- them stays bare to drag by. (The name and the search box drag the window too, pressed and moved.)
	local many = #Store.List() > 1
	local color = c.class and C_ClassColor.GetClassColor(c.class)
	local most = room - (wide and (width + GRAB) or (18 + 4))
	P.who:SetChoices(many)
	P.who:SetLabel(Store.Name(c), color and { color.r, color.g, color.b } or C.head, most)
	P.who:SetShown(wide or not open)

	local what = bankStands and " bags and bank" or " bags"
	P.hint:SetText("Search " .. Possessive(Store.Name(c)) .. what)
	if P.hint:GetStringWidth() > width - 26 then P.hint:SetText("Search" .. what) end
	if P.hint:GetStringWidth() > width - 26 then P.hint:SetText("Search") end
	P.hint:SetShown(P.edit:GetText() == "")
	return width
end

-- "also 3 in your bank, 5 on other characters": search matches that are not on screen.
local function Also(isMe, bankStands, width)
	P.hits = {}   -- guid -> search matches on that character
	if not test then
		P.also:SetText("")
		P.edit:SetPoint("BOTTOMRIGHT", P.search, "BOTTOMRIGHT", -4, 0)
		return
	end
	local mine, others = 0, 0
	for _, item in ipairs(ns.Index.All()) do
		item.known, item.kind, item.owner = nil, nil, nil
		if test(item) then
			if item.guid ~= Me() then
				others = others + 1
				P.hits[item.guid] = (P.hits[item.guid] or 0) + 1
			elseif isMe and item.source == "bank" and not bankStands then
				mine = mine + 1
			end
		end
	end
	local hot = function(n) return Shy.Theme.Wrap(C.hot, tostring(n)) end
	local text = ""
	if mine + others > 0 then
		if width < 200 then
			text = "+" .. hot(mine + others)
		elseif width < 360 then
			text = "also " .. hot(mine + others)
		elseif mine > 0 and others > 0 then
			text = "also " .. hot(mine) .. " in your bank, " .. hot(others) .. " on other characters"
		elseif mine > 0 then
			text = "also " .. hot(mine) .. " in your bank"
		else
			text = "also " .. hot(others) .. " on other characters"
		end
		if width >= 200 then text = text .. "  " .. Shy.Theme.Wrap(C.dim, "Enter") end
	end
	P.also:SetText(text)
	P.edit:SetPoint("BOTTOMRIGHT", P.search, "BOTTOMRIGHT", -(text ~= "" and (P.also:GetStringWidth() + 10) or 4), 0)
end

-- Your own bags on the live grid: which bags, and the order they are shown in (display order only: nothing
-- in the bags moves). Also called as the window is built, so every slot has its button before the bags
-- first open: a fight can't make one.
local function Carry()
	local bags = {}
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do bags[#bags + 1] = bag end
	local order = ns.Order
	P.live.prefer = Prefer()
	P.live.sort = order and order.Key() or nil
	P.live.order = P.live.sort and order.Places or nil
	P.live.apart = T.db.apart == true
	P.live:SetBags(bags)
end

function Window.Refresh()
	if not (win and box:IsShown()) then return end
	local c, guid, isMe = Who()
	if not c then return end
	-- (Other addons' rail buttons counted first: the characters' seats stand clear of them.)
	local railing = 0
	for _, def in ipairs(railed) do
		if isMe and (def.shown == nil or def.shown() == true) then railing = railing + 1 end
	end
	P.railedShown = railing
	-- The bank window follows the character shown; it is placed first, so the search knows whether it is up.
	if ns.BankWindow then ns.BankWindow.Refresh() end
	if ns.AuctionWindow then ns.AuctionWindow.Refresh() end
	local bankUp = BankUp()

	local grid = isMe and P.live or P.mem
	P.live:SetShown(grid == P.live)
	P.mem:SetShown(grid == P.mem)
	P.live.prefer, P.mem.prefer = Prefer(), Prefer()
	if isMe then
		Carry()
	else
		local lists = {}
		for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do
			local list = c.bags and c.bags[bag]
			if list then lists[#lists + 1] = list end
		end
		P.mem:SetLists(lists, guid, "bags")
	end
	if grid == P.live then grid:Filter(Sift()) else grid:Filter(test) end
	local columns, rows = grid:Shape()
	if columns == 0 then columns, rows = 4, 4 end

	-- The key ring takes the wing while it is open.
	local name = view.wing
	local _, keysUp = Takeover.Visible()
	if isMe and keysUp then name = "keys" end
	local wing = name and wings[name]
	local wingWidth
	-- Shown before it is filled: a live grid only reads the bags once visible. (Filled once the bags are laid out:
	-- docked beside them, it takes their height.)
	P.wingWanted = wing ~= nil
	Shy.HUD.Update(P.wingBox)
	P.wing:SetShown(wing ~= nil)
	for other, w in pairs(wings) do
		if w.frame then w.frame:SetShown(other == name) end
	end

	P.mine = isMe
	-- What the strip and the rail are drawn from, for when an edge is dragged (and the shape, for Facts).
	P.shown = { c = c, guid = guid, isMe = isMe, bank = bankUp, wingWidth = wingWidth,
		wing = name, columns = columns, rows = rows, gap = isMe and P.live.gap or 0 }
	P.footNeed = nil
	local W = Settle(columns, rows, wingWidth)
	local width = Title(W, c, bankUp)
	Also(isMe, bankUp, width)
	Spine(guid, rows)
	if Foot(isMe, c) then
		-- The foot needs more room than the bags give it: laid out that much wider, and said again.
		P.footWide = true
		W = Settle(columns, rows, wingWidth)
		width = Title(W, c, bankUp)
		Also(isMe, bankUp, width)
		Foot(isMe, c)
		P.footWide = nil
	end
	Rail(P.mine)
	if P.band and P.band.OnRefresh then P.band.OnRefresh(P.mine) end
	FillWing()
end

-- The wing sized again: by hand, or by the window it stands beside growing or shrinking (the bags, the bank). Its
-- list is shown again for the room it has now, and laid out. The bags stay as they are.
function Window.FlowWing()
	-- (A width counts as yours once you sized it by hand; one it took from a wider list doesn't.)
	P.wingHand = Shy.HUD.HasSize(P.wingBox) and P.wingBox:GetWidth() or nil
	if P.building or P.flowing or not (P.wing and P.wingFoot) then return end
	P.flowing = true
	FillWing()
	P.flowing = nil
end

-- The bag column (BagBar.lua) registers itself: a frame that sizes itself, shown beside the grid while
-- get(mine) is true; set(on) is the rail's switch. Returns false while there is no window to stand in.
function Window.SetBand(frame, _, get, set)
	if not win then return false end
	P.band, P.bandGet, P.bandSet = frame, get, set
	frame:SetParent(win)
	frame:Hide()
	Window.Refresh()
	return true
end

function Window.Look(guid)
	view.guid = guid ~= Me() and guid or nil
	-- Making room applies to your own bags only.
	if view.wing == "room" and view.guid then
		view.wing = nil
		if ns.Room then ns.Room.Stop() end
	end
	Window.Refresh()
end

-- Removes a character and everything remembered of it; looking at it, the window goes back to your own.
-- Never the one being played. Returns whether it was removed.
function Window.Forget(guid)
	if not Store.Forget(guid) then return false end
	if view.guid == guid then Window.Look(nil) else Window.Refresh() end
	return true
end

-- Leaving the room wing ends making room.
function Window.Open(wing)
	-- (Your auctions are a window of their own.)
	if wing == "auctions" and ns.AuctionWindow then
		if not ns.AuctionWindow.IsShown() then ns.AuctionWindow.Toggle() end
		return
	end
	local was = view.wing
	view.wing = wing
	if was == "room" and wing ~= "room" then
		pointed = nil
		if ns.Room then ns.Room.Stop() end
	end
	Window.Refresh()
end

function Window.Wing()
	return view.wing
end

function Window.Point(bag, slot)
	pointed = bag and { bag, slot } or nil
	if P.live and P.live:IsVisible() then P.live:Filter(Sift()) end
end

-- An item's tooltip from a list beside the bags: off the top right corner of its own slot, so the bags stay in sight
-- (UI.GameTipAt: the top left where the screen's edge is too near). The row owns it, not the slot: a slot redraws a
-- tooltip it owns every frame, by its own rule, and the two would take turns. Off the row while the slot is away.
function Window.TipAt(row, bag, slot)
	local tile = P.live and P.live:IsVisible() and P.live.where and P.live.where[bag * 1000 + slot]
	UI.GameTipAt(row, (tile and tile:IsVisible()) and tile or nil):SetBagItem(bag, slot)
	GameTooltip:Show()
end

-- Rows for UI.Menu: every wing with a summary beside it. Clicking the open one closes it.
function Window.Menu()
	local c, _, isMe = Who()
	local items = {}
	local function Go(label, wing, glyph, fact, missing)
		local on = DoorOpen(wing)
		items[#items + 1] = {
			text = label, detail = fact, on = on,
			icon = { type(glyph) == "table" and glyph or { glyph, on and C.head or C.dim } },
			disabled = missing ~= nil, tip = missing,
			click = function()
				if wing == "bank" then
					if ns.BankWindow then ns.BankWindow.Toggle() end
				elseif wing == "auctions" and ns.AuctionWindow then
					ns.AuctionWindow.Toggle()
				else
					Window.Open(not on and wing or nil)
				end
			end,
		}
	end
	items[#items + 1] = {
		text = "Clean up bags", disabled = not isMe,
		detail = not isMe and "your own bags only" or nil,
		click = function()
			PlaySound(SOUNDKIT.UI_BAG_SORTING_01)
			C_Container.SortBags()
		end,
	}
	local room = isMe and ns.Room or nil
	if room then
		local first = room.List()[1]
		items[#items + 1] = {
			text = "Make room", on = room.On(),
			detail = first and ("from " .. room.Coins(first.value)) or "nothing to spare",
			tip = "Lights the cheapest items you could drop or sell, with their vendor price.",
			click = function() room.Toggle() end,
		}
	end
	local order = isMe and ns.Order or nil
	if order then
		items[#items + 1] = { divider = true }
		for _, row in ipairs(order.Rows(P.live)) do items[#items + 1] = row end
	end
	items[#items + 1] = { divider = true }
	local bank, mail, auctions = BankFact(c), (MailFact(c)), (AuctionFact(c))
	Go("Bank", "bank", MEDIA .. "DoorBank", bank or (not c.bank and "not scanned yet" or nil),
		not c.bank and "Visit a banker on this character once to see its bank here." or nil)
	Go("Mailbox", "mail", MEDIA .. "DoorMail", mail or (c.mail and "empty" or "not scanned yet"))
	Go("Auctions", "auctions", MEDIA .. "DoorAuctions", auctions or (c.auctions and "none" or "not scanned yet"))
	Go("Gold", "gold", { atlas = "coin-gold" }, c.money and Coins(c.money) or nil)
	items[#items + 1] = {
		text = "Search all characters", icon = { { "Interface\\Common\\UI-Searchbox-Icon", C.dim } },
		click = function() Window.OpenSearch() end,
	}
	items[#items + 1] = { divider = true }
	items[#items + 1] = {
		text = "Settings", icon = { { Skin.GLYPH.gear, C.dim } },
		click = function() T:OpenOptions() end,
	}
	return items
end

function Window.OpenSearch()
	searchOpen = true
	Window.Refresh()
	P.edit:SetFocus()
end

function Window.Owns(button)
	if type(button) ~= "table" then return false end
	local grid = Tile.Grid(button)
	if grid ~= nil and (grid == P.live or grid == P.keys) then return true end
	return Window.IsBank(button)
end

-- One of the bank window's live slots.
function Window.IsBank(button)
	return ns.BankWindow ~= nil and ns.BankWindow.Owns(button)
end

-- For Check.lua.
function Window.Rebuild()
	P.live:Build()
	return P.live.count
end

function Window.AnyTile()
	return P.live.tiles[1], P.live
end

-- wing = { frame, Show, Build }.
function Window.AddWing(name, wing)
	wings[name] = wing
	if win and wing.Build then wing.Build(P.wing) end
end

local function Search(text)
	query = strtrim(text)
	test = ns.Search.Compile(query)
	ns.Views.query, ns.Views.test = query, test
	if not test and view.wing == "results" then view.wing = nil end
	Window.Refresh()
end

-- The window held by a corner or a side. Its shapes lie in a row, each wider and lower than the one
-- before; `morph.at` is where between them the mouse has it (2.4: four tenths of the way from the second
-- to the third), and the window and every slot are drawn there, so they move with the mouse and nothing
-- steps. Let go, it comes to rest on the nearest shape, which is kept.
local REST = 0.12   -- seconds to come to rest

-- Columns and rows (fractions) at a place between shapes, the two shapes, and the share between them.
local function Between(list, at)
	local i = math.max(1, math.min(#list, math.floor(at)))
	local a, b = list[i], list[i + 1] or list[i]
	local f = math.max(0, math.min(1, at - i))
	return a.columns + (b.columns - a.columns) * f, a.rows + (b.rows - a.rows) * f, a, b, f
end

local function Draw(at)
	morph.at = at
	local columns, rows, a, b, f = Between(morph.list, at)
	if morph.grid then morph.grid:Morph(a.columns, b.columns, f) end
	drawn = { columns, rows }
	local s = P.shown
	local W = Layout(columns, rows, s.wingWidth)
	morph.hold()
	local width = Title(W, s.c, s.bank)
	Also(s.isMe, s.bank, width)
	-- The rail seats as many characters as it has room for.
	local whole = math.floor(rows + 0.5)
	if whole ~= morph.rows then
		morph.rows = whole
		Spine(s.guid, whole)
	end
end

-- Where between its shapes the window is asked to be: by a side, the place that wide (or that tall); by
-- a corner, the place nearest the mouse.
local function Asked(wider, taller)
	local list = morph.list
	local width, height = wider and morph.width + wider, taller and morph.height + taller
	local best, off = 1, nil
	for i = 1, #list - 1 do
		local a, b = list[i], list[i + 1]
		local ax, ay = a.columns * STEP, a.rows * STEP
		local vx, vy = b.columns * STEP - ax, b.rows * STEP - ay
		local f
		if width and height then
			f = ((width - ax) * vx + (height - ay) * vy) / (vx * vx + vy * vy)
		elseif width then
			f = (width - ax) / vx
		else
			f = (height - ay) / vy
		end
		f = math.max(0, math.min(1, f))
		local dx = width and (ax + vx * f - width) or 0
		local dy = height and (ay + vy * f - height) or 0
		local d = dx * dx + dy * dy
		if not off or d < off then best, off = i + f, d end
	end
	return best
end

-- At rest on a shape: its place and its columns are kept, and everything is laid out whole again.
-- A fight can't move a live slot (that clears it off the window), so the shape is only remembered and
-- the window is laid out once the fight ends.
local function Rest()
	local m = morph
	glider:SetScript("OnUpdate", nil)
	glider:UnregisterEvent("PLAYER_REGEN_DISABLED")
	local shape = math.max(1, math.min(#m.list, math.floor(m.at + 0.5)))
	local columns = m.list[shape].columns
	if InCombatLockdown() then
		m.hold(true)
		morph = nil
		T.db.columns = columns
		glider:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	Draw(shape)
	m.hold(true)
	morph = nil
	T.db.columns = columns
	Window.Refresh()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

local function ComeToRest(_, elapsed)
	if InCombatLockdown() then
		Rest()
		return
	end
	local m = morph
	m.t = math.min(1, m.t + elapsed / REST)
	if m.t >= 1 then
		Rest()
		return
	end
	local left = 1 - m.t
	Draw(m.from + (m.to - m.from) * (1 - left * left * left))
end

-- Live slots are the game's own buttons and can't be moved in a fight. One that starts while the edge
-- is held keeps the shape and leaves the slots where they are until the fight ends.
glider:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then
		glider:UnregisterEvent("PLAYER_REGEN_ENABLED")
		Window.Refresh()
		if ns.RefreshOptions then ns.RefreshOptions() end
		return
	end
	if morph then Rest() end
end)

local function Reshape(wider, taller, phase, point)
	if phase == "start" then
		if InCombatLockdown() or not P.shown then return end
		local c, _, isMe = Who()
		local slots = c and BagSlots(c, isMe) or 0
		if slots == 0 then return end
		local list = Shapes(slots, isMe and P.live.count > 0 and P.live or nil)
		-- Taken hold of again before it came to rest: from where it is.
		local at = morph and morph.slots == slots and morph.at
		if not at then
			local columns, rows = BagShape(c, isMe)
			at = 1
			for i, shape in ipairs(list) do
				if shape.rows == rows then
					-- As it stands now, though that has a column to spare: taking hold moves nothing.
					shape.columns, at = columns, i
					break
				end
				if math.abs(shape.columns - columns) < math.abs(list[at].columns - columns) then at = i end
			end
		end
		glide = nil
		glider:SetScript("OnUpdate", nil)
		glider:RegisterEvent("PLAYER_REGEN_DISABLED")
		local grid = P.live:IsShown() and P.live or P.mem
		morph = { list = list, slots = slots, grid = grid.count > 0 and grid or nil,
			hold = Shy.HUD.Hold(box, point) }
		local columns, rows = Between(list, at)
		morph.width, morph.height = columns * STEP, rows * STEP
		Draw(at)
		return
	end
	if not morph or morph.t then return end
	Draw(Asked(wider, taller))
	if phase == "stop" then
		morph.from, morph.to, morph.t = morph.at, math.floor(morph.at + 0.5), 0
		glider:SetScript("OnUpdate", ComeToRest)
	end
end

-- Whether the bags fit themselves; Window.SetAutoShape(false) keeps the shape they have now.
function Window.AutoShape()
	return T.db.columns <= 0
end

function Window.SetAutoShape(on)
	local columns = 0
	if not on and win then
		local c, _, isMe = Who()
		columns = c and (BagShape(c, isMe)) or 0
	end
	T.db.columns = columns
	easing = true
	Window.Refresh()
	easing = nil
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Your own slots changed while they are shown (loot, a sale, an item picked up): the slots have painted
-- themselves, so only what the foot and the rail say is said again. The whole window when its shape
-- changed, or it shows anything else (the bank, a wing, another character).
local function Facts()
	local now = P.shown
	if not (box:IsShown() and now and now.isMe and not now.wing) then return Window.Refresh() end
	local columns, rows = P.live:Shape()
	if columns == 0 then columns, rows = 4, 4 end
	if columns ~= now.columns or rows ~= now.rows or P.live.gap ~= now.gap then return Window.Refresh() end
	if Foot(true, now.c) then return Window.Refresh() end
	Rail(P.mine)
	if P.band and P.band.OnRefresh then P.band.OnRefresh(P.mine) end
end

local function Build()
	box = Shy.HUD.Create({
		id = "shybags",
		title = "ShyBags window",
		width = BOX_W,
		height = BOX_H,
		-- Starts at the screen's bottom right, anchored by its top left.
		point = { "TOPLEFT", "BOTTOMRIGHT", -(BOX_W + 8), 96 + BOX_H },
		shown = function()
			local bags, keys = Takeover.Visible()
			return Takeover.IsOn() and (bags or keys)
		end,
		window = true,
		hang = true,
	})
	-- Your bags closed: the rail's other buttons are told (what they opened may close with them).
	box:HookScript("OnHide", function()
		for _, def in ipairs(railed) do
			if def.hidden then
				local ok, err = pcall(def.hidden)
				if not ok then geterrorhandler()(err) end
			end
		end
	end)
	win = CreateFrame("Frame", "ShyBagsWindow", box)
	win:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	win:SetSize(BOX_W, BOX_H)
	win:SetToplevel(true)
	win:EnableMouse(true)
	-- The character's name and the search box stand in the header in place of a title. As clear as the Background
	-- setting makes the pieces on screen: the bags are open as you play.
	UI.Head(win, { size = "window", close = function() Takeover.Close() end, panel = { glazed = true } })

	Shy.HUD.DragHandle(box, win)
	-- The corner shapes the bags. Its square is small: the footer's last count ends there.
	if Shy.HUD.Grip then
		Shy.HUD.Grip(box, {
			over = win, core = 8, shape = Reshape, tip = "Drag to make your bags wider or taller.",
			menu = function(root)
				root:CreateCheckbox("Fit bags automatically", Window.AutoShape, function() Window.SetAutoShape(not Window.AutoShape()) end)
			end,
		})
	end

	local emblem = CreateFrame("Button", nil, win)
	emblem:SetSize(18, 18)
	UI.OnHead(emblem, "LEFT", win, "LEFT", 7)
	-- The sack alone, drawn for these 16 units, in the accent: the round mini icon is too fine at this size.
	local icon = emblem:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("CENTER")
	icon:SetTexture(MEDIA .. "ShyBagsGlyph")
	Shy.Theme.Tint(icon, Shy.Theme.icon)
	emblem:SetScript("OnClick", function() T:OpenOptions() end)
	emblem:SetScript("OnEnter", function(self)
		UI.Tip(self, "ShyBags", nil, { side = "TOP", hints = { { "left", "Settings" } } })
	end)
	emblem:SetScript("OnLeave", function(self) UI.TipHide(self) end)

	-- The menu button, at the bottom of the rail, level with the footer.
	P.menu = CreateFrame("Button", nil, win)
	P.menu:SetSize(22, FOOT)
	P.menu:SetPoint("BOTTOMLEFT", 5, 7)
	-- Three bars with a bar's height between them, each a whole number of screen pixels (UI.LineFit): two
	-- units are rarely whole pixels, and the bars came out 3, 3 and 2. The middle one holds the rest.
	local bars, gaps = {}, {}
	for i = 1, 3 do
		local bar = P.menu:CreateTexture(nil, "OVERLAY")
		bar:SetWidth(12)
		bar:SetColorTexture(1, 1, 1, 1)   -- white: the make tints it as a glyph
		UI.LineFit(bar)
		bars[i] = bar
	end
	for i = 1, 2 do
		gaps[i] = P.menu:CreateTexture(nil, "OVERLAY")
		gaps[i]:SetWidth(12)
		UI.LineFit(gaps[i])
	end
	bars[2]:SetPoint("LEFT", P.menu, "CENTER", -6, 0)
	gaps[1]:SetPoint("BOTTOMLEFT", bars[2], "TOPLEFT")
	bars[1]:SetPoint("BOTTOMLEFT", gaps[1], "TOPLEFT")
	gaps[2]:SetPoint("TOPLEFT", bars[2], "BOTTOMLEFT")
	bars[3]:SetPoint("TOPLEFT", gaps[2], "BOTTOMLEFT")
	UI.KeyPress(P.menu, { fill = C.bg, glyphs = bars, sink = { bars[2] } })
	P.menu:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		UI.Menu(self, Window.Menu, {
			side = "right", join = true, width = 200,
			onShow = function(owner) owner:SetOn(true) end,
			onHide = function(owner) owner:SetOn(false) end,
		})
	end)
	P.menu:HookScript("OnEnter", function(self)
		if UI.MenuOwner() == self then return end
		UI.Tip(self, "Menu", "Clean up, sorting, the bank, the mailbox, your auctions, gold, search and options.", { side = "TOP" })
	end)
	P.menu:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	P.divide = Rule(win)
	P.divide:SetSize(16, 1)
	P.divide:SetPoint("BOTTOMLEFT", UI.Body(win), "BOTTOMLEFT", 8, 7 + FOOT + 4)

	-- The character's name, and a menu of the others.
	P.who = UI.MenuButton(win, {
		font = UI.NameFont(13), height = 18, tip = "Choose a character", drag = box,
		menu = {
			icon = SEAT, art = 32, width = 210, font = UI.NameFont(12),
			foot = function()
				local gold = ns.Views.Gold()
				return "On this realm", Coins(gold.hand)
			end,
		},
		items = function() return Window.Faces(Store.List()) end,
	})
	UI.OnHead(P.who, "LEFT", win, "LEFT", 26)

	-- The search button, for a title too narrow for the box.
	P.glass = CreateFrame("Button", nil, win)
	P.glass:SetSize(18, 18)
	local lens = P.glass:CreateTexture(nil, "OVERLAY")
	lens:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	lens:SetSize(12, 12)
	lens:SetPoint("CENTER", 0, -1)
	P.glass:SetScript("OnClick", function()
		if not Shy.HUD.WasDragged(box) then Window.OpenSearch() end
	end)
	P.glass:SetScript("OnEnter", function(self)
		UI.Tip(self, "Search", "Your bags and every character's.", { side = "TOP" })
	end)
	P.glass:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	UI.KeyPress(P.glass, { fill = C.bg, glyphs = { lens }, sink = { lens } })
	Shy.HUD.Carry(box, P.glass)

	-- The rail's buttons over the menu, each a glyph of ours on a plate like the menu's: "sort again" and the
	-- bag row's switch. The title strip stays a drag handle.
	local function RailButton(glyph, bottom)
		local b = CreateFrame("Button", nil, win)
		b:SetSize(24, RAIL_BUTTON)
		b:SetPoint("BOTTOMLEFT", UI.Body(win), "BOTTOMLEFT", 4, bottom)
		b.railBottom = bottom
		b.glyph = b:CreateTexture(nil, "OVERLAY")
		if glyph then b.glyph:SetTexture(MEDIA .. glyph) end
		b.glyph:SetSize(16, 16)
		b.glyph:SetPoint("CENTER", 0, 0)
		UI.KeyPress(b, { fill = C.bg, glyphs = { b.glyph }, sink = { b.glyph } })
		-- on: the plate stays lit; color: the glyph's (default: lit or dim with the plate).
		-- Told again at every change of the bags: the key is dressed only when its state changes.
		function b:Lit(on, color)
			on = on and true or false
			if self.litOn == on and self.litColor == color then return end
			self.litOn, self.litColor = on, color
			self:SetMark(color)
			self:SetOn(on)
		end
		b:HookScript("OnLeave", function(self) UI.TipHide(self) end)
		b:Hide()
		return b
	end
	P.RailButton = RailButton
	P.sortRail = RailButton("RailSort", 7 + FOOT + 4 + 1 + 4)
	P.sortRail:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		if ns.Order then ns.Order.Again() end
	end)
	P.sortRail:HookScript("OnEnter", function(self)
		local _, words, inUse = ns.Order.Latest()
		local changed = inUse and not P.live:Settled()
		UI.Tip(self, words.name, changed and "Your bags changed since they were sorted." or "Nothing in your bags moves.",
			{ side = "TOP", hints = { { "left", (inUse and not changed) and "Sort again" or "Sort" } } })
	end)
	P.bandToggle = RailButton("RailBags", 7 + FOOT + 4 + 1 + 4 + RAIL_STEP)
	P.bandToggle:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		if not P.band then return end
		P.bandSet(not BandOpen())
		if BandOpen() and P.band.Reveal then P.band.Reveal() end
		Window.Refresh()
		if ns.RefreshOptions then ns.RefreshOptions() end
	end)
	P.bandToggle:HookScript("OnEnter", function(self)
		UI.Tip(self, "Bag slots", "The bags you carry, in a column beside your items. Hover one to see what's in it, or drag a bag to swap it.",
			{ side = "TOP", hints = { { "left", BandOpen() and "Hide" or "Show" } } })
	end)

	P.search = Plate(win)
	P.search:SetHeight(18)
	local glass = P.search:CreateTexture(nil, "ARTWORK")
	glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	glass:SetSize(12, 12)
	glass:SetPoint("LEFT", 5, -1)
	UI.Tint(glass, C.dim)
	P.edit = CreateFrame("EditBox", nil, P.search)
	P.edit:SetPoint("TOPLEFT", 20, 0)
	P.edit:SetPoint("BOTTOMRIGHT", -4, 0)
	P.edit:SetAutoFocus(false)
	P.edit:SetFontObject(UI.TextFont(11))
	P.edit:SetMaxLetters(80)
	P.hint = UI.Text(P.search, "", 11, false, C.dim)
	P.hint:SetPoint("LEFT", 20, 0)
	P.hint:SetPoint("RIGHT", -6, 0)
	P.hint:SetWordWrap(false)
	P.also = UI.Text(P.search, "", 10, false, C.dim)
	P.also:SetPoint("RIGHT", -6, 0)
	P.also:SetWordWrap(false)
	local pending
	P.edit:SetScript("OnTextChanged", function(self, userInput)
		P.hint:SetShown(self:GetText() == "")
		if not userInput then return end
		-- Debounced.
		local mine = {}
		pending = mine
		C_Timer.After(0.15, function()
			if pending == mine then Search(self:GetText()) end
		end)
	end)
	P.edit:SetScript("OnEnterPressed", function(self)
		Search(self:GetText())
		if test and wings.results then Window.Open("results") end
		self:ClearFocus()
	end)
	P.edit:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
		Search("")
	end)
	-- The box's states: at rest (dim lens, plain rim), under the mouse (the rim and lens lift), typing (rim and lens
	-- in the accent), and holding a search while you look elsewhere (the lens stays lit, so a filtered window is
	-- never mistaken for a plain one).
	local function SearchLook()
		local typing, over = P.edit:HasFocus(), P.searchOver
		UI.SetBorder(P.search, typing and C.hot or (over and C.dim or C.border))
		UI.Tint(glass, typing and C.hot or ((over or P.edit:GetText() ~= "") and C.head or C.dim))
	end
	P.edit:HookScript("OnTextChanged", SearchLook)
	P.edit:SetScript("OnEditFocusGained", SearchLook)
	P.edit:SetScript("OnEditFocusLost", function(self)
		SearchLook()
		if searchOpen and self:GetText() == "" then
			searchOpen = false
			C_Timer.After(0, Window.Refresh)
		end
	end)
	-- Until it is typed in, the search box drags the window like the strip it stands on.
	local cover = Shy.HUD.CarryEdit(box, P.edit, P.search)
	-- Under the mouse: the cover while nobody types, the box itself once they do.
	for _, part in ipairs({ cover, P.edit }) do
		part:HookScript("OnEnter", function() P.searchOver = true; SearchLook() end)
		part:HookScript("OnLeave", function() P.searchOver = false; SearchLook() end)
	end
	-- (A click on the lens or anywhere on the box puts the cursor in: the cover lies over all of it.)

	P.spineRule = Rule(win)

	P.live = Grid.New(win, true)
	P.mem = Grid.New(win, false)
	P.live.onChange = function()
		if P.building then return end
		Facts()
	end

	P.foot = Plate(win)
	P.home = CreateFrame("Button", nil, P.foot)
	P.home:SetPoint("TOPLEFT", 1, -1)
	P.home:SetPoint("BOTTOMLEFT", 1, 1)
	P.home:SetWidth(40)
	-- The hover fill lies under the count, as a door's does; a highlight layer would cover the words.
	P.home.fill = P.home:CreateTexture(nil, "BACKGROUND")
	P.home.fill:SetAllPoints()
	UI.Paint(P.home.fill, C.row, 0.95)
	P.home.fill:Hide()
	P.homeLit = P.home:CreateTexture(nil, "OVERLAY")
	P.homeLit:SetPoint("BOTTOMLEFT", P.foot, "TOPLEFT", 0, 0)
	P.homeLit:SetPoint("BOTTOMRIGHT", P.home, "TOPRIGHT", 0, 1)
	P.homeLit:SetHeight(2)
	UI.Paint(P.homeLit, C.alert)
	P.homeLit:Hide()
	P.home:SetScript("OnClick", function(self)
		UI.TipHide(self, true)
		if ns.Room then ns.Room.Toggle() end
	end)
	P.home:SetScript("OnEnter", function(self)
		self.fill:Show()
		local room = ns.Room
		if not room then return end
		if room.On() then
			UI.Tip(self, "Making room", nil, { side = "TOP", hints = { { "left", "Stop" } } })
		else
			if #room.List() == 0 then
				UI.Tip(self, "Make room", "Nothing is safe to drop.", { side = "TOP" })
			else
				UI.Tip(self, "Make room", "Lights the cheapest items you could drop or sell.", { side = "TOP",
					hints = { { "left", "Light them" } } })
			end
		end
	end)
	P.home:SetScript("OnLeave", function(self)
		self.fill:Hide()
		UI.TipHide(self)
	end)
	P.home:EnableMouse(false)
	P.free = Rounded(P.home, 11)
	P.free:SetPoint("LEFT", P.foot, "LEFT", 6, 0)
	P.of = Rounded(P.home, 11, C.dim)
	P.of:SetPoint("LEFT", P.free, "RIGHT", 0, 0)
	doors.bank = Door(P.foot, "DoorBank", "bank")
	doors.mail = Door(P.foot, "DoorMail", "mail")
	doors.auctions = Door(P.foot, "DoorAuctions", "auctions")
	doors.gold = Door(P.foot, nil, "gold")
	doors.gold:SetPoint("RIGHT", P.foot, "RIGHT", -1, 0)

	-- The wing: a window of its own docked to the bags, as the bank's is. It opens on their right, or wherever the
	-- screen has room, and can be dragged to any side of any window.
	local function CloseWing()
		local _, keysUp = Takeover.Visible()
		if keysUp then Takeover.CloseKeys() else Window.Open(nil) end
	end
	P.wingBox = Shy.HUD.Create({
		id = "shybags.wing",
		title = "ShyBags side window",
		width = WING_EDGE + 256 + WING_EDGE,   -- the lists' own width
		height = BOX_H,
		-- Where it stands once dragged away from the bags with no place kept: the screen's middle.
		point = { "TOP", "CENTER", 0, 200 },
		shown = function() return P.wingWanted == true and box:IsShown() end,
		window = true,
		hang = true,
		dock = { to = "shybags", side = "RIGHT", label = "Beside the bags", tall = true },
	})
	P.wingWin = CreateFrame("Frame", "ShyBagsWing", P.wingBox)
	P.wingWin:SetAllPoints(P.wingBox)
	P.wingWin:SetToplevel(true)
	P.wingWin:EnableMouse(true)
	local head = UI.Head(P.wingWin, { size = "window", title = "", close = CloseWing, panel = { glazed = true } })
	Shy.HUD.DragHandle(P.wingBox, P.wingWin)
	P.wing = CreateFrame("Frame", nil, P.wingWin)
	P.wingFoot = Plate(P.wingWin)
	P.wingTitle = head.title
	P.wingDetail = Rounded(P.wingFoot, 10.5, C.dim)
	P.wingDetail:SetPoint("LEFT", 6, 0)
	P.wingRight = Rounded(P.wingFoot, 10.5, C.dim)
	P.wingRight:SetPoint("RIGHT", -6, 0)
	-- Sized by any corner or side, its list flowing to fill it. (Last: the grip flows it as it takes hold.)
	if Shy.HUD.Grip then
		Shy.HUD.Grip(P.wingBox, { over = P.wingWin, flow = function() Window.FlowWing() end, min = WING_MIN,
			tip = "Drag to make it wider or taller." })
	end

	P.keys = Grid.New(P.wing, true)
	P.keys:SetPoint("TOPLEFT")
	P.keys.onChange = function()
		if P.building then return end
		Window.Refresh()
	end
	wings.keys.frame = P.keys

	for name, wing in pairs(wings) do
		if wing.Build then wing.Build(P.wing, name) end
	end
end

-- Re-entrancy guard: painting a grid calls Refresh, and Refresh paints grids.
local refresh = Window.Refresh
function Window.Refresh()
	if P.building then return end
	P.building = true
	local ok, err = pcall(refresh)
	P.building = false
	if not ok then geterrorhandler()(err) end
end

-- Heritage Frame (fine / bold) moves HeadCloseReserve; the search box sits on that inset.
Shy:On("SHY_THEME", function()
	if not (win and P.shown and box and box:IsShown()) then return end
	local s = P.shown
	Title(win:GetWidth(), s.c, s.bank)
end)
-- The look keeps another clearance round the body (UI.Body): the window laid out again, that much bigger.
Shy:On("SHY_BODY", function(f)
	if f ~= win or not (P.shown and box and box:IsShown()) then return end
	Window.Refresh()
end)

function Window.Init()
	local ok, err = pcall(Build)
	if not ok then
		win = nil
		T:Print("the window failed to load, so the default bags stay. See your error log.")
		geterrorhandler()(err)
		return
	end

	-- Blizzard's bags clear "new" on closing; reparented they never do, so it is cleared here.
	C_NewItems.ClearAll()
	EventRegistry:RegisterCallback("ContainerFrameItemButton.EnterButton", function(_, button)
		if Window.Owns(button) then Tile.Paint(button) end
	end, Window)

	Takeover.OnChange(function(visible, keysUp)
		if not visible and not keysUp then
			P.live:Seen()
			-- Closing resets to your own bags with no search and no room mode.
			view.guid = nil
			if view.wing == "results" or view.wing == "room" then view.wing = nil end
			pointed = nil
			if ns.Room then ns.Room.Stop() end
			searchOpen = false
			if query ~= "" then
				P.edit:SetText("")
				query, test = "", nil
				ns.Views.query, ns.Views.test = "", nil
			end
		end
		Shy.HUD.Update(box)
		Shy.HUD.Update(P.wingBox)
		Window.Refresh()
	end)
	Takeover.OnSwitch(function()
		Shy.HUD.Update(box)
		Shy.HUD.Update(P.wingBox)
	end)
	ns.Bank.OnChange(function() Window.Refresh() end)
	ns.Marks.OnRefresh(function(only)
		if not box:IsShown() then return end
		if only then
			-- The slots whose marks changed, alone.
			for key in pairs(only) do
				local tile = P.live.where and P.live.where[key]
				if tile and P.live:IsVisible() then Tile.Paint(tile) end
			end
		else
			P.live:Paint()
			-- (What a quest needs changed: so may which doors it is behind.)
			DoorPins(select(3, Who()))
		end
		if ns.BankWindow then ns.BankWindow.Paint(only) end
	end)
	Shy:On("SHY_BAGS_SCANNED", function(guid, source)
		if not box:IsShown() or P.soon then return end
		-- Your own bags changing while they are shown (loot, a sale): their slots have painted themselves
		-- and said what changed (the live grid's onChange, Facts): nothing more to do here.
		local s = P.shown
		if source == "bags" and guid == Me() and s and s.isMe and not s.wing then return end
		P.soon = true
		C_Timer.After(0, function()
			P.soon = false
			Window.Refresh()
		end)
	end)
	-- Every slot has its button before the bags first open, and the key ring's keys theirs, seated out of a
	-- fight: opened in one, the window is whole and only paints. (A fight can't make, move or retarget a slot.)
	Carry()
	if C_ActionBar.ShouldShowKeyring() == true then P.keys:SetBags({ Enum.BagIndex.Keyring }) end
	Takeover.Set(T.db.window)
end

function Window.Apply()
	Takeover.Set(win ~= nil and T.db.window)
	if win then Window.Refresh() end   -- the bags' shape, after a reset
end

T:Command("blizzard", "switch between one bag window and the default bags", function()
	T.db.window = not T.db.window
	Window.Apply()
	if T.db.window then
		T:Print("one window for all your bags again, the next time they open.")
	else
		T:Print("default bags are back the next time they open. /shy bags blizzard switches again.")
	end
	if ns.RefreshOptions then ns.RefreshOptions() end
end)

function T:OpenWindow()
	Takeover.Open()
end

-- For another addon: a button of its own on the rail, above the bag row's switch, while your own bags are shown.
--   T:RegisterRailButton({ id, order, icon (a mark or texture), click = function() end,
--       shown = function() return bool end, lit = function() return bool end,
--       glimmer = function() return bool end,   -- it has something for you: UI.Glimmer
--       tip = function(button) end,            -- its hover
--       hidden = function() end })             -- your bags closed (what it opened may close with them)
-- They are asked again at every change of the bags, and on T:RefreshRail(): keep them cheap.
function T:RegisterRailButton(def)
	assert(type(def) == "table" and def.id and def.click, "a rail button needs an id and a click")
	for index, other in ipairs(railed) do
		if other.id == def.id then
			table.remove(railed, index)
			break
		end
	end
	railed[#railed + 1] = def
	table.sort(railed, function(a, b)
		if (a.order or 99) ~= (b.order or 99) then return (a.order or 99) < (b.order or 99) end
		return tostring(a.id) < tostring(b.id)
	end)
	if win then Window.Refresh() end
end

-- A rail button's state changed outside the bags (a price, a purchase): asked again while the window is up.
function T:RefreshRail()
	if not (box and box:IsShown()) then return end
	local was = P.railedShown
	Rail(P.mine)
	if P.railedShown ~= was then Window.Refresh() end
end

-- For another addon: test(place) true while your "bank" or your "mail" holds something a quest needs with you.
-- The quest's mark then stands on that door in the window's foot.
function T:Holds(test)
	holds[#holds + 1] = test
	if win then Window.Refresh() end
end

-- For an addon that shows the bags for a moment (ShyCore's quest dialog, at a reward): whether the window
-- stands in for the bags, whether it is up, and closing it again.
function T:WindowOn()
	return Takeover.IsOn() == true
end

function T:WindowShown()
	return (Takeover.Visible()) == true
end

function T:CloseWindow()
	Takeover.Close()
end
