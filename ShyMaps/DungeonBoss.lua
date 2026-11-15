-- The journal's boss: the creature whole on a stage (Shy.Model, by the display the data knows it wears), and what
-- it does as rows. A row is a spell's picture in a slot and, beside it, lines that never share their room: its
-- name with when it comes at the line's end (under the name where the row is too narrow for both), then what it
-- asks of a group as pills (the part your class can answer first, in your color), then what it does in words:
-- the game's own, or the data's sentence for a spell the game says nothing of (J.Says).
-- A row is as tall as what it holds.
--   Boss.Stage(parent, bare) -> stage   stage:Set(look) -> whether there is anything to show (J.Look's: a display,
--                                    or a creature you have met). bare: no plate of its own (it stands on a band)
--   Boss.Lay(parent, y, width, spells, x) -> y  lays rows (J.Spells') down a page from y (x in from its left), a
--                                               pool per parent; a spell cast at several points of a fight (its
--                                               ranks, one a share of health) is one row saying each
--   Boss.Clear(parent)
--   Boss.OnLate(fn)                  fn() when a spell's words have come in since its row was laid

local ADDON, ns = ...
local J = ns.Dungeons
local UI = Shy.UI
local C = UI.colors
local Slot = Shy.Slot

ns.Journal = ns.Journal or {}
local Boss = {}
ns.Journal.Boss = Boss

local L = {
	icon = 24, pad = 4, words = 8,    -- the picture, its margin, and from it to the words
	top = 4, foot = 5,                -- over the first line and under the last
	name = 14, line = 13,             -- the name's line, and a line of when it comes under it
	pillGap = 4, pillRow = 19,        -- between two pills, and a line of them
	says = 12,                        -- the game's words: a line of them at the least (they wrap, the row grows)
	least = 32,                       -- a row's height at the least: the picture and its margins
	gap = 0,
	apart = 12,                       -- between the name and when it comes, on one line
	turn = 0.35,                      -- the stage turns this many radians a second
}

local pools = {}

function Boss.Stage(parent, bare)
	local stage = CreateFrame("Frame", nil, parent)
	if not bare then UI.Skin(stage, C.row, C.rowEdge) end
	stage.view = Shy.Model.New(stage)
	stage.view:SetPoint("TOPLEFT", 2, -2)
	stage.view:SetPoint("BOTTOMRIGHT", -2, 2)
	stage.view.turn = L.turn
	function stage:Set(look)
		self.view:Set(look)
		self:SetShown(look ~= nil)
		return look ~= nil
	end
	return stage
end

-- Lays a row out for what it holds at `width`; returns its height, and whether the game's words for it are in.
local function Lay(row, width)
	local data = row.data
	local info = C_Spell.GetSpellInfo(data.spell)
	row.icon:SetTexture(info and info.iconID or C_Spell.GetSpellTexture(data.spell))
	row.name:SetText(info and info.name or "")
	local says = J.Says(data.spell)
	local when = data.said or J.When(data) or ""
	local room = width - L.pad - L.icon - L.words - 12
	local x = L.pad + L.icon + L.words
	local y = L.top

	-- The name, with when it comes at the line's end; under the name where both don't fit.
	row.when:SetText(when)
	local nameW, whenW = row.name:GetUnboundedStringWidth(), row.when:GetUnboundedStringWidth()
	local beside = when ~= "" and nameW + L.apart + whenW <= room
	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", x, -y)
	row.name:SetWidth(beside and room - whenW - L.apart or room)
	row.when:ClearAllPoints()
	y = y + L.name
	if beside then
		row.when:SetPoint("TOPRIGHT", row, "TOPLEFT", x + room, -(L.top + 1))
		row.when:SetWidth(whenW + 2)
		row.when:SetJustifyH("RIGHT")
	elseif when ~= "" then
		row.when:SetPoint("TOPLEFT", x, -y - 1)
		row.when:SetWidth(room)
		row.when:SetJustifyH("LEFT")
		y = y + L.line
	end
	row.when:SetShown(when ~= "")

	-- What it asks of a group: pills, a line of them, another where a line is full.
	local cues = J.Cues(data)
	local px, lines = 0, #cues > 0 and 1 or 0
	for i, cue in ipairs(cues) do
		local pill = row.pills[i]
		if not pill then
			pill = UI.Badge(row)
			row.pills[i] = pill
		end
		pill:Set({ text = cue.words, color = cue.color })
		local w = pill:GetWidth()
		if px > 0 and px + w > room then
			px, lines = 0, lines + 1
		end
		pill:ClearAllPoints()
		pill:SetPoint("TOPLEFT", x + px, -(y + 3 + (lines - 1) * L.pillRow))
		pill:Show()
		px = px + w + L.pillGap
	end
	for i = #cues + 1, #row.pills do row.pills[i]:Hide() end
	y = y + lines * L.pillRow

	-- The game's own words for it.
	local said = says ~= ""
	row.says:SetShown(said)
	if said then
		row.says:ClearAllPoints()
		row.says:SetPoint("TOPLEFT", x, -(y + 3))
		row.says:SetWidth(room)
		row.says:SetText(says)
		y = y + 3 + math.max(L.says, math.ceil(row.says:GetStringHeight() or 0))
	end
	local tall = math.max(L.least, y + L.foot)
	-- (A row of its name alone: the name on the picture's middle.)
	if lines == 0 and not said and (beside or when == "") then
		row.name:ClearAllPoints()
		row.name:SetPoint("LEFT", x, 0)
		if beside then
			row.when:ClearAllPoints()
			row.when:SetPoint("RIGHT", row, "LEFT", x + room, 0)
		end
	end
	row.icon:ClearAllPoints()
	row.icon:SetPoint("TOPLEFT", L.pad, -math.min(L.top, (tall - L.icon) / 2))
	row:SetHeight(tall)
	return tall, said
end

local function Make(parent)
	local row = CreateFrame("Button", nil, parent)
	ns.Journal.Line(row)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(L.icon, L.icon)
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, hover = false })
	row.name = UI.Text(row, "", 12, false, C.head)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.when = UI.Text(row, "", 10, false, C.dim)
	row.when:SetWordWrap(false)
	row.says = UI.Text(row, "", 11, false, C.dim)
	row.says:SetJustifyH("LEFT")
	row.says:SetJustifyV("TOP")
	row.says:SetWordWrap(true)
	row.pills = {}
	row:SetScript("OnEnter", function(self)
		self:Glow(true)
		UI.GameTipAt(self):SetSpellByID(self.data.spell)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self:Glow(false)
		GameTooltip:Hide()
	end)
	return row
end

function Boss.Clear(parent)
	local pool = pools[parent]
	if not pool then return end
	for _, row in ipairs(pool) do
		row.data = nil
		row:Hide()
	end
	pool.used = 0
end

-- Spells of one name and one asking are one row: when each comes, said together ("Below 60%, 40% and 20% health").
local function Together(spells)
	local out, by = {}, {}
	for _, data in ipairs(spells) do
		local info = C_Spell.GetSpellInfo(data.spell)
		local key = (info and info.name or tostring(data.spell)) .. "|" .. data.cues
		local first = by[key]
		if not first then
			first = { spell = data.spell, when = data.when, a = data.a, b = data.b, cues = data.cues, all = {} }
			by[key] = first
			out[#out + 1] = first
		end
		first.all[#first.all + 1] = data
	end
	for _, first in ipairs(out) do
		if #first.all > 1 then
			local shares, whens, seen = {}, {}, {}
			for _, data in ipairs(first.all) do
				if data.when == "h" and data.a > 0 then shares[#shares + 1] = data.a .. "%" end
				local when = J.When(data)
				if when and not seen[when] then
					seen[when] = true
					whens[#whens + 1] = when
				end
			end
			if #shares == #first.all then
				first.said = "Below " .. table.concat(shares, ", ", 1, #shares - 1) .. " and " .. shares[#shares] .. " health"
			elseif #whens > 0 then
				first.said = table.concat(whens, ", ")
			end
		end
	end
	return out
end

function Boss.Lay(parent, y, width, spells, x)
	local pool = pools[parent]
	if not pool then
		pool = { used = 0 }
		pools[parent] = pool
	end
	for _, data in ipairs(Together(spells)) do
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
		local tall, said = Lay(row, width)
		if not said then
			-- (The game hasn't the spell's words in yet: the page is laid again once it has, the row grown for them.)
			Spell:CreateFromSpellID(data.spell):ContinueOnSpellLoad(function()
				if row.data == data and J.Says(data.spell) ~= "" and Boss.late then Boss.late() end
			end)
		end
		row:Show()
		y = y + tall + L.gap
	end
	return y
end

function Boss.OnLate(fn)
	Boss.late = fn
end
