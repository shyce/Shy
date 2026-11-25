-- Shy.Tips: what addons add to the game's tooltips, as sections of a card. Each addon tells once what it adds; what it
-- builds for a thing is kept until it says it changed, so a tooltip the game redraws five times a second asks nothing
-- again. ShyTip draws the sections on its cards as they are (Shy.Tips.For); where no card of ShyTip's stands in for a
-- tooltip, one hook here writes them on it as lines.
--
--   Shy.Tips.Add({ id, order, kind, on, build, stamp, fresh, per })
--     id      a name for it (the monitor's clock: "tip sections: <id>")
--     order   where its sections stand among the others, lowest first (the game's own lines always lead)
--     kind    "item" (the default), "unit" or "object"
--     on      function() -> whether it adds anything now (its setting); asked each time, never kept
--     build   function(about, out): about = { tip, data, id, link, owner }; out takes what it adds (below)
--     stamp   function() -> a value; what it built is kept while this is the same
--     fresh   seconds what it built is kept without a stamp (default 0.5)
--     per     function(about) -> a key, where what it builds depends on more than the thing (a bag slot's stack)
--   out, as a tooltip takes lines (read once into a card's rows, the way ShyTip reads a tooltip's: a heading made
--   with Shy.Hover.Heading starts a section, a leading picture or a mark is the row's lead, "3/5" its count):
--     out:AddLine(text, r, g, b)   out:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
--   or as a card's rows, as they are (Shy.Hover's row fields: text, color, right, rightColor, icon, seat, count...):
--     out:Section(title)   out:Row(row)   out:Text(words, color) a line of its own, wrapped (a note)
--   Shy.Tips.For(tip, data)   the sections for that tooltip's thing, a card's body blocks (each with its .sig), or nil
--   Shy.Tips.Lines(tip, data) the same as the lines written where no card stands in: { { left, right, color, rightColor } }
--   Shy.Tips.Drawn(fn)        fn(tip) true where a card draws the tooltip (ShyTip's): the lines aren't written there
--   Shy.Tips.Changed()        what was kept goes (a setting changed what a section says)

local Shy = Shy

local Tips = {}
Shy.Tips = Tips

local KINDS = {}       -- the game's kind of tooltip -> ours
for kind, ours in pairs({ Item = "item", Unit = "unit", Object = "object" }) do
	local value = Enum.TooltipDataType[kind]
	if value ~= nil then KINDS[value] = ours end
end
local FRESH = 0.5      -- seconds a section without a stamp is kept
local MOST = 256       -- sections kept at once, before all are let go

local providers = { item = {}, unit = {}, object = {} }
local kept, count = {}, 0   -- key -> { at, blocks, lines }
local drawn                 -- ShyTip's: whether its card stands in for a tooltip

local function Ordered(a, b)
	if (a.order or 50) ~= (b.order or 50) then return (a.order or 50) < (b.order or 50) end
	return a.id < b.id
end

function Tips.Add(def)
	assert(type(def) == "table" and def.id and def.build, "a tip section needs an id and a build")
	local list = providers[def.kind or "item"]
	for i, other in ipairs(list) do
		if other.id == def.id then
			table.remove(list, i)
			break
		end
	end
	def.build = Shy.Clocked("tip sections: " .. def.id, def.build)
	list[#list + 1] = def
	table.sort(list, Ordered)
end

function Tips.Drawn(fn) drawn = fn end

function Tips.Changed()
	wipe(kept)
	count = 0
end

-- What a provider writes: kept as lines (for a tooltip without a card) and as a card's blocks.
local Out = {}
Out.__index = Out

local function Color(r, g, b)
	if type(r) ~= "number" then return nil end
	return { r, g, b }
end

local function Rows(out)
	local rows = out.rows
	if not rows then
		rows = {}
		out.rows = rows
		out.blocks[#out.blocks + 1] = { rows = rows }
	end
	return rows
end

-- A line read as ShyTip reads another addon's: a blank ends a section, a heading starts one, a leading picture or
-- a mark is the row's lead, "3/5" its count.
local function Read(out, left, right, color, rightColor)
	if type(left) ~= "string" or issecretvalue(left) then return end
	local Hover = Shy.Hover
	if right == "" then right = nil end
	if (left == "" or left == " ") and not right then
		out.rows = nil
	elseif not right and Hover and Hover.Headed(left) then
		out.rows = {}
		out.blocks[#out.blocks + 1] = { title = left, rows = out.rows }
	else
		local blanks = #left:match("^ *")
		local words = left:sub(blanks + 1)
		local mark, rest
		if Hover then mark, rest = Hover.Lead(words) end
		if mark then words = rest end
		local row = { text = words, indent = math.floor(blanks / 3), color = color, right = right, rightColor = rightColor }
		if mark then row.seat = mark end
		if Hover then Hover.Tally(row) end
		local rows = Rows(out)
		rows[#rows + 1] = row
	end
end

function Out:AddLine(text, r, g, b)
	local color = Color(r, g, b)
	self.lines[#self.lines + 1] = { text, nil, color }
	Read(self, text, nil, color)
end

function Out:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
	local color, rightColor = Color(lr, lg, lb), Color(rr, rg, rb)
	self.lines[#self.lines + 1] = { left, right, color, rightColor }
	Read(self, left, right, color, rightColor)
end

function Out:Section(title)
	self.rows = {}
	self.blocks[#self.blocks + 1] = { title = title, rows = self.rows }
	local dim = Shy.UI.colors.dim
	self.lines[#self.lines + 1] = { " " }
	self.lines[#self.lines + 1] = { Shy.Hover.Heading(title), nil, dim }
end

function Out:Row(row)
	local rows = Rows(self)
	rows[#rows + 1] = row
	local lead = row.icon and ("|T" .. tostring(row.icon) .. ":0|t ") or ""
	self.lines[#self.lines + 1] = { (" "):rep((row.indent or 0) * 3) .. lead .. (row.text or ""), row.right, row.color, row.rightColor }
end

function Out:Text(words, color)
	self.rows = nil
	self.blocks[#self.blocks + 1] = { text = words, color = color }
	self.lines[#self.lines + 1] = { " " }
	self.lines[#self.lines + 1] = { words, nil, color }
end

-- The thing a tooltip shows: { tip, data, id, link, owner }, or nil for one we don't add to.
local function About(tip, data)
	-- (The tooltips sections are added to: the mouse's, and a clicked link's.)
	if not (tip == GameTooltip or tip == ItemRefTooltip) or issecretvalue(data) or type(data) ~= "table" then return nil end
	local kind = data.type
	if issecretvalue(kind) or not KINDS[kind] then return nil end
	local id = data.id
	if issecretvalue(id) then id = nil end
	local link = data.hyperlink
	if issecretvalue(link) then link = nil end
	local guid = data.guid
	if issecretvalue(guid) then return nil end   -- (the game keeps the thing itself back: nothing is said of it)
	if not link and kind == Enum.TooltipDataType.Item and type(guid) == "string" then
		link = C_Item.GetItemLinkByGUID(guid)
	end
	local owner = tip:GetOwner()
	if issecretvalue(owner) then owner = nil end
	return { tip = tip, data = data, id = id, link = link, owner = owner, kind = KINDS[kind] }
end

-- One provider's sections for a thing, from what was kept or built now.
local function Built(def, about)
	local per = def.per and def.per(about)
	local key = def.id .. "\031" .. tostring(about.id or about.link) .. "\031" .. tostring(per or "")
	local stamp = def.stamp and def.stamp()
	local entry = kept[key]
	local now = GetTime()
	if entry then
		if def.stamp then
			if entry.stamp == stamp then return entry end
		elseif now - entry.at < (def.fresh or FRESH) then
			return entry
		end
	end
	local out = setmetatable({ blocks = {}, lines = {} }, Out)
	local ok, err = pcall(def.build, about, out)
	if not ok then geterrorhandler()(err) end
	if not entry then
		count = count + 1
		if count > MOST then
			wipe(kept)
			count = 1
		end
	end
	-- (A block says what it is by its provider and stamp: a card that holds it signs it so, not by its rows.)
	local sig = key .. "\031" .. tostring(stamp or now)
	for i, block in ipairs(out.blocks) do block.sig = sig .. "\031" .. i end
	entry = { at = now, stamp = stamp, blocks = out.blocks, lines = out.lines }
	kept[key] = entry
	return entry
end

local function Each(about, fn)
	for _, def in ipairs(providers[about.kind]) do
		if def.on == nil or def.on() then fn(Built(def, about)) end
	end
end

function Tips.For(tip, data)
	local about = About(tip, data)
	if not about then return nil end
	local blocks
	Each(about, function(entry)
		for _, block in ipairs(entry.blocks) do
			blocks = blocks or {}
			blocks[#blocks + 1] = block
		end
	end)
	return blocks
end

function Tips.Lines(tip, data)
	local about = About(tip, data)
	if not about then return nil end
	local lines = {}
	Each(about, function(entry)
		for _, line in ipairs(entry.lines) do lines[#lines + 1] = line end
	end)
	return lines
end

-- Where no card stands in for the tooltip (ShyTip off, or a tooltip it leaves the game's): the sections as lines.
local function Write(tip, data)
	if tip:IsForbidden() or tip:GetPrimaryTooltipData() ~= data then return end
	if drawn and drawn(tip) then return end
	local about = About(tip, data)
	if not about then return end
	Each(about, function(entry)
		for _, line in ipairs(entry.lines) do
			local text, right, color, rightColor = line[1], line[2], line[3], line[4]
			color, rightColor = color or Shy.UI.colors.text, rightColor or Shy.UI.colors.text
			if right then
				tip:AddDoubleLine(text, right, color[1], color[2], color[3], rightColor[1], rightColor[2], rightColor[3])
			else
				tip:AddLine(text, color[1], color[2], color[3], true)
			end
		end
	end)
end

Shy:On("SHY_LOGIN", function()
	for kind in pairs(KINDS) do Shy.OnTip(kind, "sections", Write) end
	if Shy.Memory then Shy.Memory.Cache("tip sections", Tips.Changed, function() return count end) end
end)
