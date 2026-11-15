-- The marks inside a cell of ShyFrames' healing grid (your party and you): what a healer goes by, each in a
-- place of its own, so where a mark stands says what it is before its picture does.
--
--   your heals   along the foot of the health bar from its left, a seat each (Data/Heals.lua, by class): a
--                priest's Renew is always the first, the shield the second. A hair of your color under each runs
--                out with its time; what stacks or has charges carries its count. Where a spell can't be cast
--                again for a while (the shield's Weakened Soul), that stands in its seat once the spell is gone.
--   a debuff     at the foot's right end. One you can remove comes first and lights the whole cell in its
--                kind's color: a glow in from its edges that breathes, a line round it, a faint wash. The thing
--                to act on is the cell that changed color.
--
-- Each mark is a slot of the game's aura container (one aura in one fixed place), so all of it works in a
-- fight, where an addon is told nothing of auras. The marks take no mouse: a click anywhere on a cell is a
-- click on the cell. A cell's own row of icons over it (Plates.lua) and its reminders (Missing.lua) stand
-- down while it is one of the grid's.
--
-- One plan says what a cell's marks are and where they stand (Marks); the game's slots are made from it
-- (Build), and so are the stand-ins on ShyFrames' test party (Stand): sample members have no auras for the game
-- to draw, so the same recipes are run on buttons of ours and told what a fight would bring. A stand-in is
-- the real mark's pieces in the real mark's place, and a child of its cell: gone with it when a fight hides
-- the samples.

local ADDON, ns = ...
local T, K = ns.T, ns.Kit
local Skin, Theme = Shy.Skin, Shy.Theme

local G = {}
ns.Grid = G

local SOLID = "Interface\\Buttons\\WHITE8X8"
local LEVEL = 8            -- a cell's marks over its bars and its words (ShyFrames' texts are seven over the cell)
local OVER = 2             -- a mark that covers the one in the same seat stands this much higher
-- The light of a debuff you can remove, in the cell's own levels: over its bars, under its words.
local LIGHT = { level = 6, wash = 0.10, glow = 0.9, low = 0.4, beat = 0.75, reach = 1 }

local frames               -- ShyFrames
local cells = {}           -- key -> { c, unit, button, bar, index, sample }
local was = false          -- whether the grid's marks were on, when last applied

-- Whether the marks stand: ShyFrames' party is the grid, and the frames carry buffs and debuffs at all.
function G.On()
	return frames ~= nil and T.db.frames and frames:Grid() and true or false
end

-- The whole cell in the kind's color while a debuff you can remove is on its member. All of it is the mark's own
-- children, so it shows and goes with the mark, and none of it takes the mouse:
--   a glow in from the cell's edges, breathing (it plays from the moment the debuff shows)
--   a line round the cell
--   a wash over its bars, faint: the health under it still reads
local function Light(button, cell)
	local level = cell:GetFrameLevel() + LIGHT.level
	local glow = CreateFrame("Frame", nil, button)
	glow:SetPoint("TOPLEFT", cell, "TOPLEFT", -LIGHT.reach, LIGHT.reach)
	glow:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", LIGHT.reach, -LIGHT.reach)
	glow:SetFrameLevel(level)
	glow:SetAlpha(LIGHT.glow)
	local soft = glow:CreateTexture(nil, "ARTWORK")
	soft:SetAllPoints()
	soft:SetTexture(Skin.GLOW)
	soft:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	soft:SetBlendMode("ADD")
	K.Kind(button, soft)
	local breath = glow:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local fade = breath:CreateAnimation("Alpha")
	fade:SetFromAlpha(LIGHT.glow)
	fade:SetToAlpha(LIGHT.low)
	fade:SetDuration(LIGHT.beat)
	fade:SetSmoothing("IN_OUT")
	button:AddAuraShownAnimation(breath)
	local edge = CreateFrame("Frame", nil, button)
	edge:SetAllPoints(cell)
	edge:SetFrameLevel(level)
	local line = edge:CreateTexture(nil, "OVERLAY")
	line:SetAllPoints()
	line:SetTexture(Skin.FRAME)
	line:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
	K.Kind(button, line)
	local wash = CreateFrame("Frame", nil, button)
	wash:SetPoint("TOPLEFT", cell, "TOPLEFT", 2, -2)
	wash:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -2, 2)
	wash:SetFrameLevel(level)
	wash:SetAlpha(LIGHT.wash)
	local fill = wash:CreateTexture(nil, "ARTWORK")
	fill:SetAllPoints()
	fill:SetTexture(SOLID)
	K.Kind(button, fill)
end

-- A cell's marks, in the order they are made:
--   { key, filter, spec (Kit.Maker's), corner, x (from the health bar's corner), lift (levels over the
--     container), filters (candidate filters), light (it lights the cell), seat (which of your seats) }
local function Marks(room, seats)
	local heal = { size = room.mark, plain = true, mine = true, foot = room.hair, through = true }
	local after = { size = room.mark, plain = true, harm = true, through = true }
	local harm = { size = room.harm, harm = true, through = true }
	local marks = {}
	for i, seat in ipairs(seats) do
		if i > room.seats then break end
		local x = room.ends + (i - 1) * (room.mark + room.gap)
		-- What stops the spell being cast again: a debuff of yours on them, no longer than that one lasts. The game
		-- matches no debuff on a friend by spell.
		if seat.after then
			marks[#marks + 1] = { key = seat.key .. "-after", filter = "HARMFUL|PLAYER", spec = after, corner = "BOTTOMLEFT", x = x,
				lift = 0, filters = { maxDuration = seat.after } }
		end
		marks[#marks + 1] = { key = seat.key, filter = "HELPFUL|PLAYER", spec = heal, corner = "BOTTOMLEFT", x = x, lift = OVER,
			filters = { includeSpellIDs = seat.spells }, seat = i }
	end
	-- Any debuff; over it, one you can remove (the game's own test: "RAID" among debuffs).
	marks[#marks + 1] = { key = "harm", filter = "HARMFUL", spec = harm, corner = "BOTTOMRIGHT", x = -room.ends, lift = 0 }
	marks[#marks + 1] = { key = "cure", filter = "HARMFUL|RAID", spec = harm, corner = "BOTTOMRIGHT", x = -room.ends, lift = OVER,
		light = true }
	return marks
end

-- A mark's button made by its recipe, standing where the plan says.
local function Make(mark, b, level, cell, bar, room)
	pcall(b.SetFrameLevel, b, level + 1 + mark.lift)   -- before its pieces are made: they stand over it
	K.Maker(mark.spec)(b)
	b:ClearAllPoints()
	b:SetPoint(mark.corner, bar, mark.corner, mark.x, room.foot)
	if mark.light then Light(b, cell) end
end

-- One cell's marks: a container of slots on its button, each placed from the health bar's own corners.
local function Build(key, unit, button, bar, room, seats)
	local c = K.Container(button, { point = "BOTTOMLEFT", across = "Right", up = "Up" })
	c:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	c:SetSize(1, 1)
	c:SetFrameLevel(button:GetFrameLevel() + LEVEL)
	local level = c:GetFrameLevel()
	for _, mark in ipairs(Marks(room, seats)) do
		K.AddSlot(c, mark.key, mark.filter, function(b) Make(mark, b, level, button, bar, room) end, mark.filters)
	end
	cells[key] = { c = c, unit = unit, button = button, bar = bar, index = tonumber(key:match("^party(%d)$")) }
end

local function BuildAll()
	local room = frames:GridRoom()
	local seats = ns.Heals and ns.Heals[UnitClassBase("player")] or {}
	frames:EachCell(function(key, unit, button, bar)
		if not cells[key] then Build(key, unit, button, bar, room, seats) end
	end)
end

---------------------------------------------------------------------------
-- The test party's stand-ins
---------------------------------------------------------------------------

-- What a sample member wears, by the party's own numbers: which of your seats are lit (the share of its time
-- left; `count` on a seat: what it stacks to), a debuff's kind, whether you could remove it.
local SAMPLE = {
	{ seats = { 0.8, 0.35, 0.6 }, count = { [3] = 3 }, harm = "None" },
	{ seats = {} },
	{ seats = { false, 0.5 }, harm = "Poison", cure = true },
	{ seats = { 0.25, false, false, 0.9 } },
}

-- A button of ours that takes what the game's aura button is told, and keeps it: the recipe then makes on it
-- exactly what it makes on the game's.
local function Button(parent)
	local b = CreateFrame("Frame", nil, parent)
	b.kinds, b.shown = {}, {}
	function b:SetIcon(texture) self.icon = texture end
	function b:SetDurationCooldown(cooldown) self.cooldown = cooldown end
	function b:SetDurationText(text) self.time = text end
	function b:SetDurationBar(bar) self.bar = bar end
	function b:SetApplicationCount(text) self.count = text end
	function b:AddDispelTypeTexture(texture, options) self.kinds[#self.kinds + 1] = { texture, options } end
	function b:AddAuraShownAnimation(group) self.shown[#self.shown + 1] = group end
	function b:SetCancelAuraButtons() end
	function b:SetTooltipAnchorPoint() end
	return b
end

-- A debuff's picture for a stand-in: a spell for enemies out of your own book (a real debuff's art, whatever
-- your class), else none (the kind's own sign stands in).
local harmIcon
local function HarmIcon()
	if harmIcon == nil then
		harmIcon = false
		local bank = Enum.SpellBookSpellBank.Player
		for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
			if info and not info.isGuild and not info.offSpecID then
				for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
					local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
					if item and item.spellID and item.iconID and not item.isPassive and C_Spell.IsSpellHarmful(item.spellID) then
						harmIcon = item.iconID
						return harmIcon
					end
				end
			end
		end
	end
	return harmIcon
end

-- Tells a stand-in what the game would tell the mark: its picture, how much of its time is left, its count, its
-- kind's color; and starts what plays as it shows.
local function Tell(b, picture, left, count, kind)
	if b.icon and picture then b.icon:SetTexture(picture) end
	if b.bar then b.bar:SetValue(left or 1) end
	if b.count then b.count:SetText(count and tostring(count) or "") end
	for _, entry in ipairs(b.kinds) do
		local texture, options = entry[1], entry[2]
		local color = options.customDispelColorMap and (options.customDispelColorMap[kind] or options.customDispelColorMap.None)
		if color then texture:SetVertexColor(color.r, color.g, color.b, 1) end
		texture:Show()
	end
	for _, group in ipairs(b.shown) do group:Play() end
end

-- The stand-ins on a sample member's cell: the plan's own marks, those a fight would have lit.
local function Stand(cell, room, seats)
	local plan = SAMPLE[cell.index] or SAMPLE[2]
	local button, bar = cell.button, cell.bar
	local holder = CreateFrame("Frame", nil, button)
	holder:SetAllPoints(button)
	holder:SetFrameLevel(button:GetFrameLevel() + LEVEL)
	local level = holder:GetFrameLevel()
	for _, mark in ipairs(Marks(room, seats)) do
		local left = mark.seat and plan.seats[mark.seat]
		local harm = plan.harm and ((mark.key == "cure" and plan.cure) or (mark.key == "harm" and not plan.cure))
		if left or harm then
			local b = Button(holder)
			Make(mark, b, level, button, bar, room)
			if left then
				-- The seat's own picture: its first spell's.
				local first
				for id in pairs(seats[mark.seat].spells) do
					if not first or id < first then first = id end
				end
				Tell(b, C_Spell.GetSpellTexture(first), left, plan.count and plan.count[mark.seat])
			else
				local picture = HarmIcon()
				Tell(b, picture or nil, nil, nil, plan.harm)
				if not picture and b.icon then AuraUtil.SetAuraDispelTypeIcon(b.icon, plan.harm) end
			end
		end
	end
	return holder
end

-- The stand-ins show on every cell that holds a sample member, and nowhere else. They are made out of a fight
-- (a cell is a secure button); shown and hidden at any time.
local function Sample()
	local on = G.On() and frames.Sampling ~= nil and frames:Sampling()
	local room, seats
	for _, cell in pairs(cells) do
		local show = on and cell.index ~= nil and not UnitExists(cell.unit)
		if show and not cell.sample and not InCombatLockdown() then
			room = room or frames:GridRoom()
			seats = seats or (ns.Heals and ns.Heals[UnitClassBase("player")] or {})
			cell.sample = Stand(cell, room, seats)
		end
		if cell.sample then cell.sample:SetShown(show and true or false) end
	end
end

function G.Apply()
	if not frames then return end
	ns.WhenFree("grid", function()
		local on = G.On()
		if on and not next(cells) then BuildAll() end
		for _, cell in pairs(cells) do K.Watch(cell.c, cell.unit, on) end
		Sample()
		if on ~= was then
			was = on
			-- The cells' rows over them and their reminders stand down for the grid, or come back.
			ns.Plates.Apply()
			ns.Missing.Apply()
		end
	end)
end

-- A cell's container and what it was told, for tests: { c, unit, button, bar, index, sample }.
function G.Cell(key)
	return cells[key]
end

function G.Start()
	frames = Shy.addons.Frames
	if not (frames and frames.EachCell and frames.Grid) then
		frames = nil
		return
	end
	-- The frames were laid out again: the party may have become the grid, or stopped being it.
	Shy:On("SHY_FRAMES_FIT", G.Apply)
	-- A seat may hold someone else now: the game refreshes on aura events, not on this.
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:SetScript("OnEvent", function()
		for _, cell in pairs(cells) do ns.Try(cell.c.UpdateAllAuras, cell.c) end
		Sample()   -- a sample member's seat may be someone's now, or free again
	end)
end
