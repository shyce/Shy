-- The journal's loot: a row an item. Its picture in a slot; its name in its quality's color, which has its line
-- to itself; under it what it is, and at that line's end what ShyGear makes of it for you (an arrow and what you
-- gain: said whole, what the item is giving way where the row is narrow); at the right how often it drops over a
-- fine bar of that share, and a star for one you want. Whose count a chance is stands once, in the head of the rows it is
-- true of (the window lays a list by source: Loot.BySource), never on every row.
--   Loot.Lay(parent, y, width, rows, x) -> y  lays rows (J.Loot's, or a quest's rewards) down a page from y, x in
--                                             from its left, a pool per parent. A row's `note` leads the line
--                                             under its name ("Choose one")
--   Loot.Clear(parent)                        puts a page's rows away
--   Loot.Pick(rows) -> rows, left out         the rows to show, by the two choices. "For me" keeps what ShyGear
--                                             calls an upgrade, now or later, and what it says nothing of (a
--                                             recipe, a bag, what starts a quest); "Everything" keeps all
--   Loot.BySource(rows) -> { { key, rows, kills } }   "here" (recorded in this game, or seen by you), then "classic"
--   Loot.Bar(parent, onChange) -> frame       the choices themselves (nil without ShyGear: nothing to choose by)
--   Loot.Verdict(item) -> verdict             ShyGear's, or nil
--   Loot.OnLate(fn)                           fn() when something a list was picked by has come in since (an
--                                             item the game hadn't told of): the list is to be picked again

local ADDON, ns = ...
local T = ns.T
local J = ns.Dungeons
local UI = Shy.UI
local C = UI.colors
local Slot = Shy.Slot

ns.Journal = ns.Journal or {}
local Loot = {}
ns.Journal.Loot = Loot

local L = {
	row = 32, gap = 0, icon = 24, pad = 4, words = 8,    -- words: from the picture to the name
	line = 3,                  -- its two lines stand this far inside the row's top and foot
	star = 11, starRoom = 22,  -- the star, and the room it stands in at the row's right end
	chance = 44,               -- the chance's column: the number over its bar
	bar = 2,                   -- that bar's height
	least = 56,                -- what an item is keeps this much of its line at the least
	arrow = 9,                 -- its arrow
	choices = 20,
	late = 0.2,                -- seconds from an item coming in to the list being picked again
	most = 2,                  -- the places an item's hover names
}
local VERDICT = { later = "Later", same = "About the same", worse = "Worse than yours", cant = "Can't use" }
local NOT_MINE = { same = true, worse = true, cant = true }   -- what "For me" leaves out

-- A line of the journal's page (a drop, a spell, a boss, a quest): no box round it, the page being one surface
-- and not a grid of them: a hairline under it; under the mouse a wash of your color in from its left edge and a
-- bar of it on that edge.
--   Journal.Line(row)   row:Glow(on)
function ns.Journal.Line(row)
	row.rule = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.rule:SetPoint("BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
	row.rule:SetHeight(1)
	UI.Paint(row.rule, C.border, 0.45)
	row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 2)
	row.wash:SetPoint("TOPLEFT", 0, 0)
	row.wash:SetPoint("BOTTOMRIGHT", 0, 1)
	row.wash:SetColorTexture(1, 1, 1, 1)
	row.wash:Hide()
	row.bar = row:CreateTexture(nil, "BACKGROUND", nil, 3)
	row.bar:SetPoint("TOPLEFT", 0, 0)
	row.bar:SetPoint("BOTTOMLEFT", 0, 1)
	row.bar:SetWidth(2)
	UI.Paint(row.bar, Shy.Theme.Accent)
	row.bar:Hide()
	function row:Glow(on)
		on = on and true or false
		if self.glowing == on then return end
		self.glowing = on
		if on then
			local r, g, b = Shy.Theme.Accent()
			self.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.24), CreateColor(r, g, b, 0))
		end
		self.wash:SetShown(on)
		self.bar:SetShown(on)
	end
	return row
end

local pools = {}             -- parent -> its rows
local shown = {}             -- item -> rows showing it now (painted again as the game tells of the item)
local verdicts = {}          -- item -> ShyGear's verdict (false: none), until the gear changes
local late = {}              -- who is told when a list is to be picked again
local waiting = false
local own = false            -- the hover being filled is one of these rows': it says where it drops already

local function Gear()
	local gear = Shy.addons.Gear
	return gear and gear.Judge and gear or nil
end

function Loot.OnLate(fn)
	late[#late + 1] = fn
end

-- Tells, once a moment, that what a list was picked by has changed.
local function Late()
	if waiting then return end
	waiting = true
	C_Timer.After(L.late, function()
		waiting = false
		for _, fn in ipairs(late) do
			local ok, err = pcall(fn)
			if not ok then geterrorhandler()(err) end
		end
	end)
end

function Loot.Verdict(item)
	local gear = Gear()
	if not gear then return nil end
	local v = verdicts[item]
	if v == nil then
		local _, link = C_Item.GetItemInfo(item)
		if not link then
			C_Item.RequestLoadItemDataByID(item)
			return nil
		end
		v = gear:Judge(link) or false
		verdicts[item] = v
	end
	return v or nil
end

function Loot.Pick(rows)
	local out, left = {}, 0
	local mine = T.db.journal.forMe and Gear() ~= nil
	for _, row in ipairs(rows) do
		local v = mine and Loot.Verdict(row.item)
		if v and NOT_MINE[v.kind] then
			left = left + 1
		else
			out[#out + 1] = row
		end
	end
	if T.db.journal.sort == "upgrade" and Gear() then
		local worth = {}
		for _, row in ipairs(out) do
			local v = Loot.Verdict(row.item)
			worth[row] = not v and -1000 or v.kind == "upgrade" and 1000 + (v.score or 0)
				or v.kind == "later" and 500 + (v.score or 0) or v.kind == "same" and 0 or -500
		end
		table.sort(out, function(x, y)
			if worth[x] ~= worth[y] then return worth[x] > worth[y] end
			if (x.chance or -1) ~= (y.chance or -1) then return (x.chance or -1) > (y.chance or -1) end
			return x.item < y.item
		end)
	end
	return out, left
end

-- A list by whose count it is: what was recorded in this game (or seen by you) first, then Classic's.
function Loot.BySource(rows)
	local here, classic = { key = "here", rows = {}, kills = 0 }, { key = "classic", rows = {}, kills = 0 }
	for _, row in ipairs(rows) do
		local into = row.source == "classic" and classic or here
		into.rows[#into.rows + 1] = row
		into.kills = math.max(into.kills, row.kills or 0)
	end
	local out = {}
	if #here.rows > 0 then out[#out + 1] = here end
	if #classic.rows > 0 then out[#out + 1] = classic end
	return out
end

local function Percent(chance)
	if not chance then return "" end
	if chance >= 99.5 then return "100%" end
	if chance < 1 then return ("%.1f%%"):format(chance) end
	return ("%d%%"):format(math.floor(chance + 0.5))
end

local function Hex(color)
	return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
end

-- What an item is, in a line: where it is worn and its kind ("Chest  ·  Mail"), or its kind alone; and the
-- least of it, for a row with no room for both.
local function What(kind, subKind, where)
	local slot = where and where ~= "" and _G[where] or nil
	if slot == "" then slot = nil end
	local what = subKind and subKind ~= "" and subKind ~= OTHER and subKind or nil
	local short = slot or what or kind or ""
	if slot and what and what ~= slot then return slot .. "  \194\183  " .. what, short end
	return short, short
end

local function Paint(row)
	local data = row.data
	local item = data.item
	local name, link, quality, _, _, kind, subKind, _, where, icon = C_Item.GetItemInfo(item)
	row.link = link
	local what, short = "", ""
	if not name then
		-- (Not told of yet: asked for, and painted again as the answer comes.)
		C_Item.RequestLoadItemDataByID(item)
		row.icon:SetTexture(C_Item.GetItemIconByID(item))
		row.name:SetText("")
		row.slot:Quality(nil)
	else
		row.icon:SetTexture(icon)
		row.name:SetText(name)
		local color = ITEM_QUALITY_COLORS[quality or 1]
		row.name:SetTextColor(color.r, color.g, color.b)
		row.slot:Quality(quality)
		what, short = What(kind, subKind, where)
	end
	if data.note then
		what = Hex(C.text) .. data.note .. "|r" .. (what ~= "" and ("  \194\183  " .. what) or "")
		short = Hex(C.text) .. data.note .. "|r"
	end
	if data.mine then what = (what ~= "" and (what .. "  \194\183  ") or "") .. Hex(C.good) .. "You've seen it drop|r" end
	row.sub:SetText(what)
	-- What it is to you: an arrow and what you gain for an upgrade, a quiet word for the rest.
	local v = name and Loot.Verdict(item)
	local cant = v and v.kind == "cant"
	local words, color, arrow = "", C.dim, false
	if v then
		local gear = Gear()
		if v.kind == "upgrade" then
			words, color, arrow = gear.Words and gear:Words(v) or "", C.good, true
			if words == "" then words = "Upgrade" end
		else
			words = VERDICT[v.kind] or ""
			if v.kind == "later" then color = C.alert end
		end
	end
	row.verdict:SetText(words)
	UI.Ink(row.verdict, color)
	row.arrow:SetShown(arrow)
	row.icon:SetDesaturated(cant and true or false)
	row:SetAlpha(cant and 0.5 or 1)
	-- How often: the number over a bar of that share.
	local chance = data.chance
	row.chance:SetText(Percent(chance))
	row.track:SetShown(chance ~= nil)
	row.fill:SetShown(chance ~= nil)
	if chance then row.fill:SetWidth(math.max(1, L.chance * math.min(chance, 100) / 100)) end
	local want = J.Wanted(item)
	UI.Tint(row.star.glyph, want and C.alert or C.dim, want and 1 or 0.3)
	-- The words' room: the name has its line; under it the verdict is said whole, what the item is in what is left.
	local room = row.room or 200
	local mark = arrow and L.arrow + 5 or 0
	local said = words ~= "" and math.min(row.verdict:GetUnboundedStringWidth() + 2, room - mark - L.least) or 0
	row.verdict:SetWidth(math.max(1, said))
	row.name:SetWidth(room)
	local left = math.max(L.least - 12, room - said - mark - (said > 0 and 12 or 0))
	row.sub:SetWidth(left)
	-- (No room for all it is beside the verdict: the least of it said whole, its note or where it is worn.)
	if not data.mine and row.sub:GetUnboundedStringWidth() > left then row.sub:SetText(short) end
end

local function Tip(row)
	own = true
	UI.GameTipAt(row):SetItemByID(row.data.item)
	own = false
	GameTooltip:Show()
end

local function Make(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(L.row)
	ns.Journal.Line(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(L.icon, L.icon)
	row.icon:SetPoint("LEFT", L.pad, 0)
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, hover = false })
	row.name = UI.Text(row, "", 12, false, C.head)
	row.name:SetPoint("TOPLEFT", row, "TOPLEFT", L.pad + L.icon + L.words, -L.line)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.sub = UI.Text(row, "", 10, false, C.dim)
	row.sub:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", L.pad + L.icon + L.words, L.line)
	row.sub:SetJustifyH("LEFT")
	row.sub:SetWordWrap(false)
	-- From the right: the star, the chance over its bar, what ShyGear says with its arrow before it.
	row.star = CreateFrame("Button", nil, row)
	row.star:SetSize(L.starRoom, L.row)
	row.star:SetPoint("RIGHT", 0, 0)
	row.star.glyph = row.star:CreateTexture(nil, "ARTWORK")
	row.star.glyph:SetSize(L.star, L.star)
	row.star.glyph:SetPoint("CENTER", -2, 0)
	Shy.Hover.Glyph(row.star.glyph, "star", L.star)
	row.star:SetScript("OnClick", function()
		local item = row.data.item
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		J.Want(item, not J.Wanted(item))
	end)
	row.star:SetScript("OnEnter", function(self)
		row:Glow(true)
		UI.Tip(self, J.Wanted(row.data.item) and "Starred" or "Star this drop",
			"Starred drops are listed on the dungeon's Overview, and you're told when one drops.", { side = "LEFT" })
	end)
	row.star:SetScript("OnLeave", function(self)
		row:Glow(false)
		UI.TipHide(self)
	end)
	row.track = row:CreateTexture(nil, "ARTWORK")
	row.track:SetSize(L.chance, L.bar)
	row.track:SetPoint("BOTTOMRIGHT", row.star, "BOTTOMLEFT", -2, 7)
	UI.Paint(row.track, C.border, 0.7)
	row.fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
	row.fill:SetHeight(L.bar)
	row.fill:SetPoint("BOTTOMLEFT", row.track, "BOTTOMLEFT")
	UI.Paint(row.fill, Shy.Theme.Accent)
	row.chance = UI.Text(row, "", 12, false, C.head)
	row.chance:SetFont(Shy.FONT_ROUNDED, 12, "")
	row.chance:SetPoint("BOTTOMRIGHT", row.track, "TOPRIGHT", 0, 3)
	row.chance:SetJustifyH("RIGHT")
	row.verdict = UI.Text(row, "", 10, false, C.dim)
	row.verdict:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -(L.starRoom + 2 + L.chance + 14), L.line)
	row.verdict:SetJustifyH("RIGHT")
	row.verdict:SetWordWrap(false)
	row.arrow = row:CreateTexture(nil, "ARTWORK")
	row.arrow:SetSize(L.arrow, L.arrow)
	row.arrow:SetPoint("RIGHT", row.verdict, "LEFT", -5, 0)
	Shy.Hover.Glyph(row.arrow, "up", L.arrow)
	UI.Tint(row.arrow, C.good)
	row:SetScript("OnEnter", function(self)
		self:Glow(true)
		Tip(self)
	end)
	row:SetScript("OnLeave", function(self)
		self:Glow(false)
		GameTooltip:Hide()
	end)
	-- A held key links it in chat or tries it on, as the game's own item buttons do.
	row:SetScript("OnClick", function(self)
		if self.link and IsModifiedClick() then HandleModifiedItemClick(self.link) end
	end)
	return row
end

function Loot.Clear(parent)
	local pool = pools[parent]
	if not pool then return end
	for _, row in ipairs(pool) do
		if row.data then
			local rows = shown[row.data.item]
			if rows then rows[row] = nil end
		end
		row.data = nil
		row:Hide()
	end
	pool.used = 0
end

function Loot.Lay(parent, y, width, rows, x)
	local pool = pools[parent]
	if not pool then
		pool = { used = 0 }
		pools[parent] = pool
	end
	for _, data in ipairs(rows) do
		pool.used = pool.used + 1
		local row = pool[pool.used]
		if not row then
			row = Make(parent)
			pool[pool.used] = row
		end
		row.data = data
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", x or 0, -y)
		row:SetWidth(width)
		row.room = width - L.pad - L.icon - L.words - 14 - L.chance - 2 - L.starRoom
		shown[data.item] = shown[data.item] or {}
		shown[data.item][row] = true
		Paint(row)
		row:Show()
		y = y + L.row + L.gap
	end
	return y
end

-- The list's choices. Nothing to choose by without ShyGear.
function Loot.Bar(parent, onChange)
	if not Gear() then return nil end
	local bar = CreateFrame("Frame", nil, parent)
	local telling = false    -- the choices being set to what is kept, not made
	bar.mine = UI.Segments(bar, { "For me", "Everything" }, function(i)
		if telling then return end
		T.db.journal.forMe = i == 1
		onChange()
	end, { height = L.choices })
	bar.mine:SetPoint("RIGHT", 0, 0)
	bar.sort = UI.Segments(bar, { "Likeliest", "Best" }, function(i)
		if telling then return end
		T.db.journal.sort = i == 2 and "upgrade" or "chance"
		onChange()
	end, { height = L.choices })
	bar.sort:SetPoint("RIGHT", bar.mine, "LEFT", -8, 0)
	bar:SetSize(bar.mine:GetWidth() + 8 + bar.sort:GetWidth(), L.choices)
	function bar:Refresh()
		telling = true
		self.mine:Select(T.db.journal.forMe and 1 or 2)
		self.sort:Select(T.db.journal.sort == "upgrade" and 2 or 1)
		telling = false
	end
	bar:Refresh()
	return bar
end

-- Any item's hover says where it drops (T.db.drops): the likeliest two, and how many more.
local function Where(tip, data)
	if own or not (T.db and T.db.drops) or (tip ~= GameTooltip and tip ~= ItemRefTooltip) then return end
	local item = data and data.id
	if not item or issecretvalue(item) then return end
	local drops = J.Drops(item)
	if not drops then return end
	table.sort(drops, function(x, y) return (x.chance or -1) > (y.chance or -1) end)
	for i = 1, math.min(L.most, #drops) do
		local drop = drops[i]
		local from = drop.boss and (drop.boss .. ", " .. drop.name) or drop.name
		local chance = Percent(drop.chance)
		tip:AddDoubleLine("Drops from " .. from, chance ~= "" and (chance .. (drop.source == "classic" and " in Classic" or "")) or "",
			C.text[1], C.text[2], C.text[3], C.dim[1], C.dim[2], C.dim[3])
	end
	if #drops > L.most then tip:AddLine(("and %d more places"):format(#drops - L.most), C.dim[1], C.dim[2], C.dim[3]) end
end
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, Where)

-- The game told of an item a row asked for: the rows showing it say so, and a list picked without it is picked again.
local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, _, item)
	if not item then return end
	local asked = verdicts[item] == nil and Gear() ~= nil
	verdicts[item] = nil
	local any = false
	for row in pairs(shown[item] or {}) do
		if row.data and row.data.item == item then
			Paint(row)
			any = true
		end
	end
	if any and asked then Late() end
end)
Shy:On("SHY_GEAR", function()
	wipe(verdicts)
end)
