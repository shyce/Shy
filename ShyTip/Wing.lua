-- Shows the default tooltip's content in a Shy.Hover card. The tooltip is still built and placed by the
-- game; it is hidden with alpha only (so IsShown stays true) and the card is anchored to its corner.
--   GameTooltip, SettingsTooltip   a card at the mouse (Shy.Hover.Show). A spell, an effect and an item keep the
--                                  game's own lines, order and colors. What is worn in an item's place (Compare.lua)
--                                  stands beside it as a card of its own (Shy.Hover.Beside), and what would change is
--                                  a band on the item's card. Units are Unit.lua's.
--   ShoppingTooltip1/2             out of sight while the card says the comparison; cards beside it when it can't
--   ItemRefTooltip                 a card that stays (Shy.Hover.Stay); the tooltip keeps the clicks and drags
-- The default tooltip shows instead whenever Say returns nil: a secret line, a restricted or secret
-- anchor, an inserted frame (bar, money, reward, widget). All reading runs under pcall for the same reason.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Wing = {}
ns.Wing = Wing

local LONG = 48              -- characters: a longer (or wrapped) line is prose
local CHECK = 0.2            -- seconds between re-reads of a shown tooltip
local LINGER = 0.4           -- seconds a world tooltip's card takes to fade
local TEXTURES = 30          -- line textures per tooltip (SharedTooltipArtTemplate)
local LEAST = 170            -- an item card's narrowest width, the worn one's too, so the two stand alike

-- Tooltip anchor type -> the corner nearest its owner, where the card is anchored.
local CORNERS = {
	ANCHOR_RIGHT = "BOTTOMLEFT", ANCHOR_TOPLEFT = "BOTTOMLEFT", ANCHOR_CURSOR_RIGHT = "BOTTOMLEFT",
	ANCHOR_LEFT = "BOTTOMRIGHT", ANCHOR_TOPRIGHT = "BOTTOMRIGHT", ANCHOR_CURSOR_LEFT = "BOTTOMRIGHT",
	ANCHOR_TOP = "BOTTOM", ANCHOR_CURSOR = "BOTTOM",
	ANCHOR_BOTTOM = "TOP", ANCHOR_BOTTOMRIGHT = "TOPLEFT", ANCHOR_BOTTOMLEFT = "TOPRIGHT",
}

-- What a card costs, piece by piece, for the monitor: the frame's own work, then each step of a re-read.
-- (A step's clock is laid by hand, so the pieces stand under the frame's work rather than beside it.)
local READ = Shy.Clock("tip: a tooltip read again")
local SAID = Shy.Clock("tip: what the tooltip says, gathered")
local STOOD = Shy.Clock("tip: the card put up")
local BESIDE = Shy.Clock("tip: the cards beside")
local SHOWS = Shy.Clock("tip: what the tooltip shows, read")

local clock                  -- OnUpdate frame (Watch)
local hosts = {}             -- replaced tooltips, in order
local veiled = setmetatable({}, { __mode = "k" })     -- tooltip -> hidden by alpha
local sideSaid = setmetatable({}, { __mode = "k" })   -- comparison tooltip -> signature of its card
local told = {}              -- errors already reported

local function On()
	return T.db ~= nil and T.db.replace == true and Shy.Hover ~= nil
end

local function Veil(tip)
	veiled[tip] = true
	tip:SetAlpha(0)
end

local function Unveil(tip)
	if not veiled[tip] then return end
	veiled[tip] = nil
	tip:SetAlpha(1)
end

local function Tell(err)
	err = tostring(err)
	if told[err] then return end
	told[err] = true
	geterrorhandler()("ShyTip's wing: " .. err)
end

-- Reading a tooltip

local function Near(a, b) return math.abs(a - b) < 0.02 end

-- A line's color when it isn't one of the two default text colors; second return is true for gold.
local function Meaning(r, g, b)
	if issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or type(r) ~= "number" then return nil end
	if Near(r, 1) and Near(g, 1) and Near(b, 1) then return nil end
	local nr, ng, nb = NORMAL_FONT_COLOR:GetRGB()
	if Near(r, nr) and Near(g, ng) and Near(b, nb) then return nil, true end
	return { r, g, b }
end

-- A line's text without the line breaks the game writes at its ends (a recipe's made item and reagents
-- start with one); true when it started with one, the game's own gap before it.
local function Unbroken(text)
	local gap = text:find("^%s*\n") ~= nil
	return (text:gsub("^%s*\n", ""):gsub("\n%s*$", "")), gap
end

-- Every line with its text, color and right side; nil when any of it is secret.
local function Lines(tip)
	local n = tip:NumLines()
	if issecretvalue(n) or type(n) ~= "number" or n < 1 then return nil end
	local lines = {}
	for i = 1, n do
		local left, right = tip:GetLeftLine(i), tip:GetRightLine(i)
		if type(left) ~= "table" then return nil end
		local text = left:GetText()
		if issecretvalue(text) then return nil end
		local color, gold = Meaning(left:GetTextColor())
		local words, gap = Unbroken(text or "")
		local line = { text = words, gap = gap, color = color, gold = gold, left = left }
		if type(right) == "table" then
			local shown = right:IsShown()
			if issecretvalue(shown) then return nil end
			if shown then
				local said = right:GetText()
				if issecretvalue(said) then return nil end
				if said and said ~= "" then
					line.right, line.rightColor, line.rightString = said, Meaning(right:GetTextColor()), right
				end
			end
		end
		lines[i] = line
	end
	return lines
end

-- The tooltip holds a frame the card can't show.
local function Formless(tip)
	local inserted = tip.insertedFrames
	if type(inserted) == "table" and #inserted > 0 then return true end   -- progress bar, widgets
	if tip.shownMoneyFrames then return true end                          -- money frame
	local item = tip.ItemTooltip
	if type(item) == "table" and item:IsShown() then return true end      -- embedded reward
	local pool = tip.statusBarPool
	if type(pool) == "table" and pool:GetNumActive() > 0 then return true end
	return false
end

-- Anchoring is restricted or secret: nothing can be anchored to it.
local function Unplaceable(tip)
	local restricted, secret = tip:IsAnchoringRestricted(), tip:IsAnchoringSecret()
	if issecretvalue(restricted) or issecretvalue(secret) then return true end
	return restricted or secret
end

-- The tooltip's first info and data, plus each line's data record by its `lineIndex`.
local function Data(tip)
	local kinds = {}
	local list = tip.infoList
	if type(list) ~= "table" then return nil, nil, kinds end
	local first, data
	for index, info in ipairs(list) do
		local d = info.tooltipData
		if not issecretvalue(d) and type(d) == "table" then
			if index == 1 then first, data = info, d end
			local written = d.lines
			if not issecretvalue(written) and type(written) == "table" then
				for _, line in ipairs(written) do
					local at = line.lineIndex
					if not issecretvalue(at) and type(at) == "number" then kinds[at] = line end
				end
			end
		end
	end
	return first, data, kinds
end

-- nil for a secret value.
local function Open(value)
	if issecretvalue(value) then return nil end
	return value
end

local function AuraWord(info)
	local getter = Open(info.getterName)
	if type(getter) == "string" then
		if getter:find("Debuff", 1, true) then return "Debuff" end
		if getter:find("Buff", 1, true) then return "Buff" end
	end
	local args = Open(info.getterArgs)
	if type(args) == "table" then
		for i = 1, args.n or #args do
			local arg = Open(args[i])
			if type(arg) == "string" then
				if arg:find("HARMFUL", 1, true) then return "Debuff" end
				if arg:find("HELPFUL", 1, true) then return "Buff" end
			end
		end
	end
	return "Effect"
end

local function UnitWord(tip)
	local _, unit = tip:GetUnit()
	if issecretvalue(unit) or not unit then return "Creature" end
	local player = UnitIsPlayer(unit)
	if issecretvalue(player) then return "Creature" end
	if player then return "Player" end
	local reaction = UnitReaction(unit, "player")
	if issecretvalue(reaction) or type(reaction) ~= "number" then return "Creature" end
	return reaction <= 3 and "Enemy" or reaction == 4 and "Neutral" or "Friendly"
end

-- Returns the tooltip's kind as a word, its icon, and true for a unit.
local function Kind(tip, info, data)
	local K = Enum.TooltipDataType
	local kind, id = Open(data.type), Open(data.id)
	if kind == nil then return nil end
	if kind == K.Unit then
		-- Unit functions can error on a unit the tooltip still names.
		local ok, word = pcall(UnitWord, tip)
		return ok and word or "Creature", nil, true
	end
	if type(id) ~= "number" then return nil end
	if kind == K.Item then return "Item", Open(C_Item.GetItemIconByID(id)) end
	if kind == K.Spell then return "Spell", Open((C_Spell.GetSpellTexture(id))) end
	if kind == K.UnitAura then return AuraWord(info), Open((C_Spell.GetSpellTexture(id))) end
	return nil
end

-- An icon in a Shy.Slot, marked with the item's quality color. `sig` feeds the change signature (Sign).
--   worn   you have it on: a tick on the picture's corner
local TICK, TICK_SHADE = 11, 20

local function IconSeat(file, mark, worn)
	local sig = "icon:" .. tostring(file) .. (mark and (":%.2f,%.2f,%.2f"):format(mark[1], mark[2], mark[3]) or "") .. (worn and ":worn" or "")
	return { key = "shytip-icon", sig = sig, set = function(seat)
		if not seat.picture then
			seat.picture = seat:CreateTexture(nil, "ARTWORK")
			seat.picture:SetAllPoints()
			seat.slot = Shy.Slot.New(seat, { icon = seat.picture, hover = false })
		end
		seat.picture:SetTexture(file)
		if mark then seat.slot:Mark(mark[1], mark[2], mark[3]) else seat.slot:Mark() end
		if worn and not seat.badge then
			-- Over the slot's own layers: a white tick on a soft dark spot, readable on any picture.
			local badge = CreateFrame("Frame", nil, seat)
			badge:SetSize(TICK, TICK)
			badge:SetPoint("CENTER", seat, "BOTTOMRIGHT", -2, 2)
			badge:SetFrameLevel(seat:GetFrameLevel() + 5)
			local shade = badge:CreateTexture(nil, "ARTWORK", nil, 1)
			shade:SetSize(TICK_SHADE, TICK_SHADE)
			shade:SetPoint("CENTER")
			shade:SetTexture(Shy.MEDIA .. "Glow")
			shade:SetVertexColor(0, 0, 0, 0.9)
			local tick = badge:CreateTexture(nil, "ARTWORK", nil, 2)
			tick:SetAllPoints()
			Shy.Hover.Glyph(tick, "check", TICK)
			seat.badge = badge
		end
		if seat.badge then seat.badge:SetShown(worn == true) end
	end }
end

ns.IconSeat = IconSeat

-- A texture the tooltip drew beside a line, drawn the same way.
local function PictureSeat(about)
	return { key = "shytip-picture", sig = "picture:" .. tostring(about.atlas or about.file), set = function(seat)
		if not seat.picture then
			seat.picture = seat:CreateTexture(nil, "ARTWORK")
			seat.picture:SetPoint("TOPLEFT", 1, -1)
			seat.picture:SetPoint("BOTTOMRIGHT", -1, 1)
		end
		if about.atlas then seat.picture:SetAtlas(about.atlas) else seat.picture:SetTexture(about.file) end
		seat.picture:SetVertexColor(about.r, about.g, about.b)
	end }
end

-- A tooltip's line textures, found by name once (the template makes them with the tooltip).
local lineArt = setmetatable({}, { __mode = "k" })

local function LineArt(tip, name)
	local list = lineArt[tip]
	if not list or list.name ~= name then
		list = { name = name }
		lineArt[tip] = list
	end
	if list.whole then return list end
	local whole = true
	for i = 1, TEXTURES do
		if list[i] == nil then list[i] = _G[name .. "Texture" .. i] end
		if list[i] == nil then whole = false end
	end
	list.whole = whole
	return list
end

-- Attaches each shown line texture to the line it is anchored to.
local function Pictures(tip, lines)
	local name = tip:GetName()
	if type(name) ~= "string" then return end
	local at = {}
	for index, line in ipairs(lines) do
		at[line.left] = index
		if line.rightString then at[line.rightString] = index end
	end
	local art = LineArt(tip, name)
	for i = 1, TEXTURES do
		local texture = art[i]
		if type(texture) == "table" and texture:IsShown() then
			local _, to = texture:GetPoint(1)
			local index = not issecretvalue(to) and to and at[to]
			if index then
				local r, g, b = texture:GetVertexColor()
				if issecretvalue(r) then r, g, b = 1, 1, 1 end
				lines[index].picture = { atlas = Open(texture:GetAtlas()), file = Open(texture:GetTexture()), r = r, g = g, b = b }
			end
		end
	end
end

-- How many characters of a line are seen: color, picture and link codes take no room.
local function Seen(text)
	return #UI.PlainText(text)
end

-- The line the beta's issue reporter adds to every tooltip ("Press F6 to submit an issue for this ...").
local function Reporter(text)
	local reporter = PTR_IssueReporter
	if type(reporter) ~= "table" then return false end
	local part = reporter.BugTooltipPartialString
	return (type(part) == "string" and text:find(part, 1, true) ~= nil) or text == reporter.MissingBindTooltipString
end

-- An item of uncommon quality or better: its quality's color, for the card's light, edge and head.
local function Quality(data)
	local id = Open(data.id)
	if type(id) ~= "number" then return nil end
	local quality = Open(C_Item.GetItemQualityByID(id))
	if type(quality) ~= "number" or quality < Enum.ItemQuality.Uncommon then return nil end
	local about = ColorManager.GetColorDataForItemQuality(quality)
	return about and { about.color:GetRGB() } or nil
end

-- A spell's school mask from the client's tables (Data/Schools.lua): physical where it isn't listed.
-- nil without the data. Each spell is looked for in the lines as it is first asked and kept, so the
-- first spell hovered doesn't take apart every line of the data.
local schools = {}           -- spell -> mask, as asked
local listed                 -- { mask, ",line," } for each line of the data, made on first use
local function School(id)
	local data = ns.schools
	if not data then return nil end
	local mask = schools[id]
	if mask then return mask end
	if not listed then
		listed = {}
		for each, lines in pairs(data) do
			for _, line in ipairs(lines) do listed[#listed + 1] = { each, "," .. line .. "," } end
		end
	end
	local want = (",%d,"):format(id)
	mask = 1
	for _, entry in ipairs(listed) do
		if entry[2]:find(want, 1, true) then
			mask = entry[1]
			break
		end
	end
	schools[id] = mask
	return mask
end

-- The game is showing its own comparison for this tooltip.
local function Comparing(tip)
	local list = tip.shoppingTooltips
	if type(list) ~= "table" then return false end
	for _, side in ipairs(list) do
		if side:IsShown() and side:IsOwned(tip) then return true end
	end
	return false
end

-- Flattens content into a signature so a changed tooltip can be told from a refreshed one.
-- The key names of a table are sorted in a list kept for its depth, so a re-read makes none.
local depths = {}

local function Sign(value, out, depth)
	local kind = type(value)
	if kind == "table" then
		if value.sig then
			out[#out + 1] = value.sig
			return
		end
		depth = (depth or 0) + 1
		out[#out + 1] = "{"
		for _, each in ipairs(value) do Sign(each, out, depth) end
		local names = depths[depth]
		if not names then
			names = {}
			depths[depth] = names
		end
		local n = 0
		for name in pairs(value) do
			if type(name) == "string" then
				n = n + 1
				names[n] = name
			end
		end
		for i = #names, n + 1, -1 do names[i] = nil end
		table.sort(names)
		for i = 1, n do
			local name = names[i]
			out[#out + 1] = name
			Sign(value[name], out, depth)
		end
		out[#out + 1] = "}"
	elseif kind == "function" or kind == "userdata" then
		out[#out + 1] = "*"
	else
		out[#out + 1] = tostring(value)
	end
end

-- A color the game's data gives a line, read as Meaning reads a drawn one; the game writes gold where it gives none.
local function Ink(color)
	if issecretvalue(color) or type(color) ~= "table" then return Meaning(NORMAL_FONT_COLOR:GetRGB()) end
	return Meaning(color:GetRGB())
end

-- What is worn, as a card of its own beside the item's: built from the game's data for its tooltip, so
-- no tooltip has to be up for it. It is told from the card under the mouse at a glance, not by a
-- sentence: the game's one word on a tab over it, a tick on its picture, and a grey light where the other
-- has its color. Returns its content and signature; nil when the game can't say it or any of it is secret.
local function Worn(item)
	local guid, link = Open(item.guid), Open(item.hyperlink)
	local data
	if guid then
		data = C_TooltipInfo.GetItemByGUID(guid)
	elseif type(link) == "string" and link ~= "" then
		data = C_TooltipInfo.GetHyperlink(link)
	end
	if issecretvalue(data) or type(data) ~= "table" then return nil end
	local written, id = Open(data.lines), Open(data.id)
	if type(written) ~= "table" or type(id) ~= "number" then return nil end
	local L = Enum.TooltipDataLineType
	local GOLD = { NORMAL_FONT_COLOR:GetRGB() }
	local content = { card = true, tab = EQUIPPED, light = C.dim, about = "Worn:" .. id, least = LEAST, body = {} }
	local rows
	for _, line in ipairs(written) do
		local what, text, right = line.type, line.leftText, line.rightText
		if issecretvalue(what) or issecretvalue(text) or issecretvalue(right) then return nil end
		if type(text) ~= "string" then text = "" end
		if type(right) ~= "string" or right == "" then right = nil end
		local gap
		text, gap = Unbroken(text)
		if gap then rows = nil end
		if not content.title then
			if text == "" then return nil end
			content.title, content.titleColor = text, Ink(line.leftColor)
		elseif what == L.SellPrice then
			-- What it would sell for is no part of a comparison.
		elseif what == L.Separator or what == L.Blank or ((text == "" or text == " ") and not right) then
			rows = nil
		else
			if not rows then
				rows = {}
				content.body[#content.body + 1] = { rows = rows }
			end
			local blanks = #text:match("^ *")
			local color, gold = Ink(line.leftColor)
			rows[#rows + 1] = { text = text:sub(blanks + 1), indent = math.floor(blanks / 3), color = color or (gold and GOLD) or nil,
				right = right, rightColor = right and (Ink(line.rightColor)) or nil }
		end
	end
	if not content.title then return nil end
	local icon = Open(C_Item.GetItemIconByID(id))
	if icon then content.seat = IconSeat(icon, content.titleColor, true) end
	local out = {}
	Sign(content, out)
	return content, table.concat(out, "\031")
end

-- An item's price line split into its label and its coins ("" for a range's heading), so the coins stand
-- at the row's right and never wrap away from their numbers. A range's lowest and highest follow its heading.
local function Price(words, range)
	local sold = SELL_PRICE .. ":"
	if words:sub(1, #sold) == sold then return SELL_PRICE, strtrim(words:sub(#sold + 1)) end
	if not range then return nil end
	for _, label in ipairs({ MINIMUM, MAXIMUM }) do
		if words:sub(1, #label + 1) == label .. ":" then return label, strtrim(words:sub(#label + 2)) end
	end
end

-- Builds a tooltip's card content and its signature; nil when it can't be shown faithfully.
--   label   the comparison header ("Equipped")
--   open    show everything at once (a clicked link)
-- Every line is kept as a row in tooltip order, so other addons' lines survive.
local function Say(tip, label, open)
	if tip:IsForbidden() or Formless(tip) or Unplaceable(tip) then return nil end
	local lines = Lines(tip)
	if not lines then return nil end
	local info, data, kinds = Data(tip)
	local first = lines[1]
	-- A tooltip can be rewritten in place: trust its data only while the first line still matches.
	if data then
		local named = kinds[1] and kinds[1].leftText
		if issecretvalue(named) or type(named) ~= "string" or Unbroken(named) ~= first.text then info, data, kinds = nil, nil, {} end
	end
	pcall(Pictures, tip, lines)

	local content = { card = true, body = {} }
	local body = content.body
	local word, icon, unit
	if data then word, icon, unit = Kind(tip, info, data) end
	local from = 2
	-- An item keeps the game's own lines, order and colors; only how it stands against yours is added.
	local item = word == "Item"
	local GOLD = item and { NORMAL_FONT_COLOR:GetRGB() } or nil
	if word then
		content.title, content.titleColor = first.text, first.color
		-- (The game's comparison header stands on a tab over the card: "Equipped", "If equipped together".)
		content.kind = not label and (first.right or (not item and word or nil)) or nil
		content.tab = label
		if icon then content.seat = IconSeat(icon, first.color) end
		if item then
			local quality = Quality(data)
			content.light, content.edge = quality, quality
			content.least = LEAST
		elseif not unit then
			-- A spell, a skill or an effect: its school's color, as an item takes its quality's.
			local id = Open(data.id)
			local mask = type(id) == "number" and School(id)
			if mask then
				local school = { Shy.Theme.School(mask) }
				content.light, content.edge = school, school
			end
		end
	elseif label then
		content.title, from = label, 1
	else
		-- The first line is the title unless it is long enough to be prose.
		local wrapped = Open(first.left:GetNumLines())
		if Seen(first.text) > LONG or (type(wrapped) == "number" and wrapped > 1) then
			from = 1
		else
			content.title, content.titleColor, content.kind = first.text, first.color, first.right
		end
	end

	-- What an item would replace: a band on this card for each (below), and a card each beside it (Sides).
	local bands
	if item and ns.Compare then
		local ok, read, worn = pcall(ns.Compare.Read, { info = info, data = data, side = label ~= nil })
		if ok then bands, content.worn = read, worn else Tell(read) end
	end

	local L = Enum.TooltipDataLineType
	local rows, ranged
	for i = from, #lines do
		local line = lines[i]
		local record = kinds[i]
		local what = record and Open(record.type)
		local text = line.text
		if line.gap then rows = nil end
		if Reporter(text) then
			-- Not needed at a glance: in the foot, which slides down after a rest.
			content.extras = content.extras or {}
			content.extras[#content.extras + 1] = { text = text }
		elseif (what ~= nil and what == L.Separator) or ((text == "" or text == " ") and not line.right) then
			rows = nil
		elseif record == nil and not line.right and Shy.Hover.Headed(text) then
			-- A heading an addon wrote over its own lines: they stand under it, as a section's rows.
			rows = {}
			body[#body + 1] = { title = text, rows = rows }
		else
			local blanks = #text:match("^ *")
			local words = text:sub(blanks + 1)
			-- A picture another addon wrote before its words becomes the row's lead.
			local mark, rest = Shy.Hover.Lead(words)
			if mark then words = rest end
			local wrapped = Open(line.left:GetNumLines())
			local long = not item and not line.right and blanks == 0 and (Seen(words) > LONG or (type(wrapped) == "number" and wrapped > 1))
			local flavor = not item and not line.right and ((what ~= nil and what == L.FlavorText) or (line.gold and words:match('^".*"$') ~= nil))
			if long or flavor then
				rows = nil
				body[#body + 1] = { text = words, color = flavor and C.hot or line.color }
			else
				if not rows then
					rows = {}
					body[#body + 1] = { rows = rows }
				end
				local row = { text = words, indent = math.floor(blanks / 3), color = line.color or (item and line.gold and GOLD) or nil,
					right = line.right, rightColor = line.rightColor }
				local named, price
				if item and not line.right then named, price = Price(words, ranged) end
				ranged = named ~= nil and (price == "" or named ~= SELL_PRICE)
				if named then
					row.text, row.right, row.quiet = named, price ~= "" and price or nil, true
				end
				if mark then
					row.seat = mark
				elseif what == nil then
					-- An untyped line, often another addon's.
					if line.picture and (line.picture.atlas or line.picture.file) then row.seat = PictureSeat(line.picture) end
				elseif what == L.QuestObjective then
					if Open(record.completed) then row.done = true else row.glyph, row.tint = "coin", C.dim end
				elseif what == L.LearnableSpell and Open(record.spellIcon) then
					row.icon = record.spellIcon
				elseif line.picture and (line.picture.atlas or line.picture.file) then
					row.seat = PictureSeat(line.picture)
				end
				-- An objective's count (the game's line, or one another addon added): pips and the numbers at the right.
				if record == nil or what == L.QuestObjective then Shy.Hover.Tally(row) end
				rows[#rows + 1] = row
			end
		end
	end

	-- What addons add to it (Shy.Tips): their sections as they built them, kept until they change.
	local sections = data and Shy.Tips and Shy.Tips.For(tip, data)
	for _, block in ipairs(sections or {}) do body[#body + 1] = block end

	-- A unit takes the colors ShyTip.lua chose for its tooltip.
	if unit then
		local look = ns.LookOf(tip)
		if ns.Unit then
			ns.Unit.Plate(content, { tip = tip, name = first.text, look = look, lines = lines, kinds = kinds, data = data, open = open })
		else
			if look then
				if look.danger then
					content.light, content.pulse = look.danger.color, look.danger.pace
				elseif look.edge then
					content.light = look.edge
				end
				content.wash = look.wash
			end
			local bar = tip.StatusBar
			if type(bar) == "table" then
				local shown = bar:IsShown()
				if not issecretvalue(shown) and shown then
					body[#body + 1] = { bar = { live = function() return bar:GetValue() end, color = look and look.health or C.good } }
				end
			end
		end
	end

	-- A key of yours on the bars (Shy.Keys): the card leads with it. Under the title, the key that presses the
	-- button and the key's name whole (the bars cut it short); then, before the game's own lines, a band of what
	-- the key is for and what it comes to cast next.
	local owner = Open(tip:GetOwner())
	local slot = type(owner) == "table" and not owner:IsForbidden() and Open(owner.action) or nil
	local lead = type(slot) == "number" and Shy.Keys and Shy.Keys.On(slot) or nil
	if lead then
		content.key = { { text = lead.key or "No key", color = C.head }, { text = lead.name, color = C.text } }
		if lead.what or lead.next then
			table.insert(body, 1, { band = { lead = "This key", title = lead.what or lead.next, titleColor = C.text,
				rows = lead.what and lead.next and { { text = lead.next, color = C.dim } } or nil } })
		end
	end

	-- Bands go after every tooltip line. Under the mouse they drop down after a rest or with Shift, unless
	-- the game is comparing already (Shift, or always compare).
	local later = not open and not Comparing(tip)
	for _, band in ipairs(bands or {}) do
		body[#body + 1] = { band = band, more = later or nil }
		content.banded = true
	end
	-- A spell or an effect: the talents of yours that change it, dropping down the same way.
	if word and not item and not unit and ns.Talents then
		local ok, changed = pcall(ns.Talents.For, Open(data.id))
		if not ok then
			Tell(changed)
		elseif changed then
			body[#body + 1] = { title = "Modified by", rows = changed, more = later or nil }
		end
	end

	-- Identity: a refresh of the same thing (a cooldown ticking) keeps the card as open as it was.
	content.about = (word or "") .. ":" .. tostring(Open(data and data.id) or first.text) .. ":" .. tostring(Open(tip:GetOwner()))
	local out = {}
	Sign(content, out)
	return content, table.concat(out, "\031")
end

-- Replacing a tooltip

local function Corner(host)
	if host.corner then return host.corner end
	local tip = host.tip
	local corner = CORNERS[Open(tip:GetAnchorType()) or ""]
	if corner then return corner end
	-- ANCHOR_NONE: use its first point.
	local ok, point = pcall(tip.GetPoint, tip, 1)
	if ok and not issecretvalue(point) and type(point) == "string" then return point end
	return "BOTTOMLEFT"
end

-- The host's card frame, if the hover still belongs to it.
local function Mine(host)
	local Hover = Shy.Hover
	if host.stay then return Hover.Staying(host.stay) end
	return Hover.Owner() == host.holder and Hover.Frame() or nil
end

-- ItemRefTooltip keeps the mouse: its hit rect is shrunk to the card's outline.
local function Grip(host, frame)
	local tip = host.tip
	local wide, tall = tip:GetSize()
	local mine, high = frame:GetSize()
	if issecretvalue(wide) or issecretvalue(tall) or issecretvalue(mine) or issecretvalue(high) then return end
	tip:SetHitRectInsets(wide - mine, 0, 0, tall - high)
	host.gripped = true
end

local function Ungrip(host)
	if not host.gripped then return end
	host.gripped = nil
	host.tip:SetHitRectInsets(0, 0, 0, 0)
end

-- The cards beside an item's: what is worn in its place, at once, with or without the game comparing.
-- The game's own comparison tooltips stay out of sight while the card says it (those cards, or its
-- band); where the card can say nothing of it, they are shown as the cards beside it instead.
local function Sides(host)
	local Hover = Shy.Hover
	local list = host.tip.shoppingTooltips
	if type(list) ~= "table" then return end
	local from = debugprofilestop()
	local of = host.up and Mine(host) or nil
	local worn = of and host.worn or nil
	local count = worn and #worn or 0
	if not worn then
		for _, side in ipairs(list) do
			if side:IsShown() and side:IsOwned(host.tip) then count = count + 1 end
		end
	end
	for n, side in ipairs(list) do
		local beside = Hover.Frame(n)
		local ours = beside and beside.of == of
		local content, key
		local live = of and side:IsShown() and side:IsOwned(host.tip)
		local banded = live and host.banded
		if worn then
			if worn[n] then
				local ok
				ok, content, key = pcall(Worn, worn[n])
				if not ok then
					Tell(content)
					content = nil
				end
			end
		elseif banded then
			-- Already a band on the card.
		elseif live then
			local header = side.CompareHeader
			local label = type(header) == "table" and header:IsShown() and Open(header.Label:GetText()) or nil
			local ok
			ok, content, key = pcall(Say, side, label ~= "" and label or nil, true)
			if not ok then
				Tell(content)
				content = nil
			end
		end
		if content then
			if not ours or sideSaid[side] ~= key then
				local ok, err = pcall(Hover.Beside, n, content, { of = of, count = count })
				if not ok then
					Tell(err)
					content = nil
				end
			end
		end
		if content then
			sideSaid[side] = key
			if live then Veil(side) end
		elseif banded then
			sideSaid[side] = nil
			Veil(side)
			if ours then Hover.Beside(n, nil) end
		else
			sideSaid[side] = nil
			Unveil(side)
			-- Only close a side card that belongs to this host's card.
			if ours or (beside and not host.up and beside.of == host.was) then Hover.Beside(n, nil) end
		end
	end
	BESIDE:Lap(debugprofilestop() - from)
end

-- Closes the card and shows the default tooltip again.
local function Down(host)
	local Hover = Shy.Hover
	host.was = Hover and Mine(host) or nil
	if host.up and Hover then
		if host.stay then Hover.Stay(host.stay, nil) else Hover.Hide(host.holder, true) end
	end
	host.up, host.said, host.leaving = false, nil, nil
	Ungrip(host)
	Unveil(host.tip)
	if Hover then Sides(host) end
	host.was = nil
end

local function Stand(host)
	local Hover = Shy.Hover
	local tip = host.tip
	local from = debugprofilestop()
	local content, key = Say(tip, nil, host.stay ~= nil)
	SAID:Lap(debugprofilestop() - from)
	if not content then return false end
	local corner = Corner(host)
	local scale = tip:GetEffectiveScale() / UIParent:GetEffectiveScale()
	key = key .. "\031" .. corner .. "\031" .. ("%.3f"):format(scale)
	host.banded, host.content = content.banded, content
	-- A link's card stays up while the mouse goes on to other things: the cards beside are the mouse's.
	host.worn = not host.stay and content.worn or nil
	local frame = Mine(host)
	if not frame or key ~= host.said then
		local opts = { at = { corner, tip, corner }, scale = scale, keep = false, onClose = host.close }
		from = debugprofilestop()
		if host.stay then frame = Hover.Stay(host.stay, content, opts) else frame = Hover.Show(host.holder, content, opts) end
		STOOD:Lap(debugprofilestop() - from)
	end
	if not frame then return false end
	-- Cancel a fade in progress.
	if host.leaving and not frame.rising then frame:SetAlpha(1) end
	host.said, host.leaving = key, nil
	if host.stay then Grip(host, frame) end
	return true
end

-- Re-reads a shown tooltip into its card, or falls back to the tooltip itself.
local Keep, Fresh

local function Sync(host)
	local tip = host.tip
	local from = debugprofilestop()
	host.keptAt = nil
	if not tip:IsShown() then return end
	if not On() or ns.Hushed(tip) then
		if host.up or veiled[tip] then Down(host) end
		return
	end
	-- A tooltip the game writes again while the mouse is out of its window stays out of sight (Look).
	if host.up and not host.stay and Shy.Hover.Away() then
		Veil(tip)
		return
	end
	local ok, up = pcall(Stand, host)
	if not ok then Tell(up) end
	if not (ok and up) then
		Down(host)
		return
	end
	host.up, host.since = true, 0
	if clock then clock:Show() end
	Veil(tip)
	Sides(host)
	if not host.stay then Keep(host) end
	READ:Lap(debugprofilestop() - from)
end

-- What a tooltip shows, as a list of values: its lines (words, colors, wrapping), the pictures beside them,
-- what it was built from, its owner and place, its bar, the colors ShyTip gave it, whether the card may stand
-- at all and, for a unit, what the card reads of them (level, side, guild, their target). A card is said again
-- only when these change (Fresh): not for the Show that follows the OnShow which has just said it, nor, for a
-- unit, when the game writes the same tooltip again or the card looks again with nothing new.
-- A secret anywhere and nothing is taken as unchanged.
local SECRET = {}
local held, count = {}, 0
local targets = {}           -- unit token -> its target's token

local Secret = issecretvalue

local function Put(value)
	if Secret(value) then error(SECRET, 0) end
	count = count + 1
	held[count] = value
end

local function PutColor(c, n)
	if type(c) ~= "table" then
		Put(false)
		return
	end
	for i = 1, n do Put(c[i]) end
end

local TAG_LAYERS = { "back", "face", "over" }   -- a tag's textures besides its picture (ShyPlates' :Tag)

local function Shows(host)
	local tip = host.tip
	local n = tip:NumLines()
	if Secret(n) or type(n) ~= "number" then error(SECRET, 0) end
	held[1] = n
	local k = 1
	-- The lines, written straight in: they are most of it.
	for i = 1, n do
		local left, right = tip:GetLeftLine(i), tip:GetRightLine(i)
		if type(left) ~= "table" then error(SECRET, 0) end
		local text, wraps = left:GetText(), left:GetNumLines()
		local r, g, b = left:GetTextColor()
		if Secret(text) or Secret(wraps) or Secret(r) or Secret(g) or Secret(b) then error(SECRET, 0) end
		held[k + 1], held[k + 2], held[k + 3], held[k + 4], held[k + 5], held[k + 6] = left, text, wraps, r, g, b
		local shown, said, sr, sg, sb = false, false, false, false, false
		if type(right) == "table" then
			shown = right:IsShown()
			if Secret(shown) then error(SECRET, 0) end
			if shown then
				said = right:GetText()
				sr, sg, sb = right:GetTextColor()
				if Secret(said) or Secret(sr) or Secret(sg) or Secret(sb) then error(SECRET, 0) end
			end
		end
		held[k + 7], held[k + 8], held[k + 9], held[k + 10], held[k + 11], held[k + 12] = right, shown, said, sr, sg, sb
		k = k + 12
	end
	count = k
	local name = tip:GetName()
	if type(name) == "string" then
		local art = LineArt(tip, name)
		for i = 1, TEXTURES do
			local texture = art[i]
			if texture then
				local shown = texture:IsShown()
				Put(shown)
				if shown then
					local _, to = texture:GetPoint(1)
					local r, g, b = texture:GetVertexColor()
					Put(to)
					Put(texture:GetAtlas())
					Put(texture:GetTexture())
					Put(r)
					Put(g)
					Put(b)
				end
			end
		end
	end
	local list = tip.infoList
	Put(type(list) == "table")
	if type(list) == "table" then
		for _, info in ipairs(list) do
			local data = info.tooltipData
			if Secret(data) then error(SECRET, 0) end
			Put(type(data) == "table")
			Put(info.getterName)
			if type(data) == "table" then
				Put(data.type)
				Put(data.id)
				Put(data.guid)
				local lines = data.lines
				Put(type(lines) == "table")
				if type(lines) == "table" then
					for _, line in ipairs(lines) do
						Put(line.lineIndex)
						Put(line.type)
						Put(line.completed)
						Put(line.spellIcon)
						Put(line.leftText)
					end
				end
			end
		end
	end
	local _, unit = tip:GetUnit()
	local restricted, secret = tip:IsAnchoringRestricted(), tip:IsAnchoringSecret()
	local bar = tip.StatusBar
	Put(unit)
	Put(tip:GetOwner())
	Put(tip:GetAnchorType())
	Put(tip:GetEffectiveScale())
	Put(restricted)
	Put(secret)
	if not (restricted or secret) then Put((tip:GetPoint(1))) end
	Put(tip:IsForbidden())
	Put(type(bar) == "table" and bar:IsShown())
	Put(Formless(tip))
	Put(Comparing(tip))
	Put(On())
	Put(ns.Hushed(tip))
	Put(Shy.Hover.Away())
	local glance = ns.GlanceOf(tip)
	local tag = type(glance) == "table" and glance.tag
	Put(glance ~= nil)
	Put(type(tag) == "table")
	if type(tag) == "table" then
		Put(tag.texture)
		PutColor(tag.coords, 4)
		PutColor(tag.color, 3)
		Put(tag.count)
		Put(tag.mark)
		for _, key in ipairs(TAG_LAYERS) do
			local layer = type(tag[key]) == "table" and tag[key] or nil
			Put(layer ~= nil)
			if layer then
				Put(layer.texture)
				PutColor(layer.coords, 4)
				PutColor(layer.color, 3)
			end
		end
	end
	local look = ns.LookOf(tip)
	if look then
		PutColor(look.edge, 3)
		PutColor(look.wash, 4)
		PutColor(look.health, 3)
		local danger = look.danger
		Put(danger ~= nil)
		if danger then
			PutColor(danger.color, 3)
			Put(danger.pace)
			Put(danger.base)
			Put(danger.above)
		end
	end
	if type(unit) == "string" then
		local player = UnitIsPlayer(unit)
		Put(UnitLevel(unit))
		Put(player)
		Put(UnitCanAttack("player", unit))
		if player then Put((GetGuildInfo(unit))) end
		local theirs = targets[unit]
		if not theirs then
			theirs = unit .. "target"
			targets[unit] = theirs
		end
		local there = UnitExists(theirs)
		Put(there)
		if there then
			Put(UnitIsUnit(theirs, "player"))
			Put(UnitName(theirs))
		end
	end
	return count
end

-- Notes what the host's tooltip shows as its card is said.
function Keep(host)
	local from = debugprofilestop()
	local ok = pcall(Shows, host)
	SHOWS:Lap(debugprofilestop() - from)
	if not ok then
		host.keptAt = nil
		return
	end
	local kept = host.kept
	if not kept then
		kept = {}
		host.kept = kept
	end
	for i = 1, count do kept[i] = held[i] end
	for i = count + 1, kept.n or 0 do kept[i] = nil end
	kept.n, host.keptAt = count, GetTime()
	host.keptUnit = host.content ~= nil and host.content.plate ~= nil
end

-- The card stands for what the tooltip shows now. Across frames only a unit's is trusted: an item's or a
-- spell's card also says what you wear and which talents you have, which a tooltip doesn't show.
-- placed: the caller has seen the card standing.
function Fresh(host, placed)
	if not host.keptAt or not host.up then return false end
	if host.keptAt ~= GetTime() and not host.keptUnit then return false end
	if not placed and not (host.tip:IsShown() and Mine(host)) then return false end
	local from = debugprofilestop()
	local ok = pcall(Shows, host)
	SHOWS:Lap(debugprofilestop() - from)
	local kept = host.kept
	if not ok or count ~= kept.n then return false end
	for i = 1, count do
		if kept[i] ~= held[i] then return false end
	end
	return true
end

-- On any error the tooltip is unhidden, so it is never invisible with no card.
local function Safe(fn, host, ...)
	local ok, err = pcall(fn, host, ...)
	if ok then return end
	host.up, host.said, host.leaving = false, nil, nil
	Unveil(host.tip)
	pcall(function()
		if host.stay then Shy.Hover.Stay(host.stay, nil) else Shy.Hover.Hide(host.holder, true) end
	end)
	Tell(err)
end

-- Per frame. The card closes here, not in OnHide, so a tooltip hidden and re-shown for the next
-- button keeps its card without a blink. Alpha is re-applied because callers reset it.
local function Look(host, elapsed)
	local tip = host.tip
	if host.leaving then
		local gone = (GetTime() - host.leaving) / LINGER
		local frame = Mine(host)
		if gone >= 1 or not frame then Down(host) else frame:SetAlpha(1 - gone) end
	elseif not tip:IsShown() then
		Down(host)
	elseif not host.stay and Shy.Hover.Owner() and Shy.Hover.Owner() ~= host.holder then
		-- Another addon took the hover.
		Down(host)
	elseif not Mine(host) then
		if not host.stay and Shy.Hover.Away() then
			-- The mouse left the game's window: neither shows until it moves.
			tip:SetAlpha(0)
		else
			-- The card was closed from outside: show it again.
			host.said = nil
			Sync(host)
		end
	else
		tip:SetAlpha(0)
		host.since = (host.since or 0) + elapsed
		if host.since >= CHECK then
			if Fresh(host, true) then host.since = 0 else Sync(host) end
		end
	end
end

-- The clock runs while a card is up and stops with the last (Sync starts it again).
local function Watch(self, elapsed)
	local any = false
	for _, host in ipairs(hosts) do
		if host.up then
			Safe(Look, host, elapsed)
			any = any or host.up
		end
	end
	if not any then self:Hide() end
end

local function Host(tip, stay)
	local host = { tip = tip, stay = stay, up = false }
	hosts[#hosts + 1] = host
	-- One hover owner per tooltip, so one tooltip hiding can't close another's card.
	if not stay then host.holder = CreateFrame("Frame") end
	local function Shown() Safe(Sync, host) end
	-- Showing a hidden tooltip runs its OnShow, then the Show that called it, which finds the card said;
	-- and the game writes a unit's tooltip again as it learns more, mostly the same. (A link's card is
	-- gripped at the size each Show ends with.)
	local function Again()
		if Fresh(host) then
			host.since = 0
			Veil(tip)
			return
		end
		Safe(Sync, host)
	end
	tip:HookScript("OnShow", Shown)
	hooksecurefunc(tip, "Show", stay and Shown or Again)
	hooksecurefunc(tip, "SetShown", stay and Shown or Again)
	tip:HookScript("OnHide", function(self)
		Unveil(self)
		-- A link's card closes now; the mouse card is closed by Watch.
		if stay and host.up then Safe(Down, host) end
	end)
	if stay then
		-- Anchored top right so the tooltip's close button sits under the card's.
		host.corner = "TOPRIGHT"
		host.close = function() tip:Hide() end
	else
		-- The game's fade sets the tooltip's alpha and would undo ours: hide it and fade the card instead.
		hooksecurefunc(tip, "FadeOut", function(self)
			if not host.up or not self:IsShown() then return end
			host.leaving = GetTime()
			self:Hide()
		end)
	end
	for _, side in ipairs(type(tip.shoppingTooltips) == "table" and tip.shoppingTooltips or {}) do
		local function Changed()
			if host.up then Safe(Sides, host) end
		end
		side:HookScript("OnShow", Changed)
		hooksecurefunc(side, "Show", Changed)
		hooksecurefunc(side, "SetShown", Changed)
		side:HookScript("OnHide", function(self)
			Unveil(self)
			Changed()
		end)
	end
	return host
end

-- Mouse tooltips that are replaced. Tooltips shown with no mouse on anything are left alone.
local HOVERS = { "GameTooltip", "SettingsTooltip" }

function Wing.Start()
	if clock then return end
	-- Addons' sections are drawn on the cards; where no card stands in for a tooltip, they are written on it.
	if Shy.Tips then
		local hosted = {}
		Shy.Tips.Drawn(function(tip)
			return On() and hosted[tip] == true and not Formless(tip) and not Unplaceable(tip)
		end)
		for _, name in ipairs(HOVERS) do
			if _G[name] then hosted[_G[name]] = true end
		end
		hosted[ItemRefTooltip] = true
	end
	-- (a key's button: the card leads with the key, so the tooltip itself needs no lines of it)
	if Shy.Keys then Shy.Keys.Carded = function() return true end end
	clock = CreateFrame("Frame")
	clock:SetScript("OnUpdate", Shy.Clocked("tip: a frame's work", Watch))
	for _, name in ipairs(HOVERS) do
		if _G[name] then Host(_G[name]) end
	end
	Host(ItemRefTooltip, "link")
end

-- Re-syncs every tooltip after a setting changes.
function Wing.Apply()
	-- (Whether cards stand in changes what addons' sections say: ShyGear's numbers or none.)
	if Shy.Tips then Shy.Tips.Changed() end
	for _, host in ipairs(hosts) do
		host.said = nil
		if host.tip:IsShown() then Safe(Sync, host) elseif host.up then Safe(Down, host) end
	end
end
