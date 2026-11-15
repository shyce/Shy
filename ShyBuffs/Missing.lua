-- What you and your party are missing that someone with you can cast: a grey icon on a gold frame.
-- Yours stand past the left end of the shelf beside the minimap; a party member's on their cell's top right.
-- Nine pairs (single and group version). A blessing has no caster class, so it is never counted as missing.
-- Auras are matched by the client's localized spell name, and can only be read out of a fight:
-- in one, a buff counts as it last was.

local ADDON, ns = ...
local T = ns.T
local UI, Slot = Shy.UI, Shy.Slot

local M = {}
ns.Missing = M

M.BUFFS = {
	{ spells = { 1459, 23028 }, class = "MAGE" },      -- Arcane Intellect, Arcane Brilliance
	{ spells = { 1243, 21562 }, class = "PRIEST" },    -- Power Word: Fortitude, Prayer of Fortitude
	{ spells = { 14752, 27681 }, class = "PRIEST" },   -- Divine Spirit, Prayer of Spirit
	{ spells = { 1126, 21849 }, class = "DRUID" },     -- Mark of the Wild, Gift of the Wild
	{ spells = { 976, 27683 }, class = "PRIEST" },     -- Shadow Protection, Prayer of Shadow Protection
	{ spells = { 20217, 25898 } },                     -- Blessing of Kings, Greater Blessing of Kings
	{ spells = { 1038, 25895 } },                      -- Blessing of Salvation, Greater Blessing of Salvation
	{ spells = { 19742, 25894 } },                     -- Blessing of Wisdom, Greater Blessing of Wisdom
	{ spells = { 19740, 25782 } },                     -- Blessing of Might, Greater Blessing of Might
}

local GAP = 2
local CELL, CELL_MOST = 12, 3     -- on a party member's cell: icon size, and how many at most
local DIM = 0.6

local function Secret(...)
	for i = 1, select("#", ...) do
		if issecretvalue((select(i, ...))) then return true end
	end
	return false
end

-- The classes in your group, yours included.
local classes, stale = {}, true
local function GroupHas(class)
	if stale then
		stale = false
		wipe(classes)
		local kind, count = "party", GetNumSubgroupMembers()
		if IsInRaid() then kind, count = "raid", GetNumGroupMembers() end
		local _, mine = UnitClass("player")
		if not Secret(mine) and mine then classes[mine] = true end
		for i = 1, count do
			local _, token = UnitClass(kind .. i)
			if not Secret(token) and token then classes[token] = true end
		end
	end
	return classes[class] == true
end

-- A buff or debuff of that exact name, from any caster. A secret aura is not returned at all.
local function HasAura(unit, name)
	local aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HELPFUL")
	if issecretvalue(aura) or aura then return true end
	aura = C_UnitAuras.GetAuraDataBySpellName(unit, name, "HARMFUL")
	return (issecretvalue(aura) or aura) and true or false
end

-- A spell's name, asked of the game once it has one: every read asks for eighteen.
local names = {}
local function SpellName(id)
	local name = names[id]
	if name == nil then
		name = C_Spell.GetSpellName(id)
		if not Secret(name) and name then names[id] = name end
	end
	return name
end

-- Returns: one of the pair is on the unit; and whether a "no" is reliable.
local function Has(unit, buff)
	local open = true   -- neither spell's aura is secret right now
	for _, id in ipairs(buff.spells) do
		local name = SpellName(id)
		if name and HasAura(unit, name) then return true, true end
		if C_Secrets.ShouldSpellAuraBeSecret(id) then open = false end
	end
	return false, open
end

-- Fills `out` with the pairs (by index, in order) the unit lacks. `memory` holds each pair's last reliable state.
function M.Read(unit, memory, out)
	wipe(out)
	for i, buff in ipairs(M.BUFFS) do
		local on, sure = Has(unit, buff)
		if on or sure then memory[i] = on end
		if not memory[i] and buff.class and GroupHas(buff.class) then out[#out + 1] = i end
	end
	return out
end

-- A tray: icons from its right end leftward. `riser`: ShyFrames' measures, for one on a frame's edge: then it is a
-- housing of the look's mini make, as the row of icons beside it is, standing on the frame's edge.
local function NewTray(parent, size, riser)
	local tray = CreateFrame("Frame", nil, parent)
	tray:Hide()
	tray.size, tray.icons, tray.riser = size, {}, riser
	if riser then
		tray:SetSize(1, 1)
		UI.Panel(tray, { hud = true, mini = true, brackets = false, line = false })
	end
	return tray
end

-- Room round a housed tray's icons, the same on every side as round the row beside it (Kit.ShellRoom).
local function Margins()
	return ns.Kit.ShellRoom()
end

local function Icon(tray, i)
	local icon = tray.icons[i]
	if icon then return icon end
	local size = tray.size
	icon = CreateFrame("Frame", nil, tray)
	icon:SetSize(size, size)
	icon.picture = icon:CreateTexture(nil, "ARTWORK")
	icon.picture:SetAllPoints()
	icon.picture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.picture:SetDesaturated(true)
	icon.picture:SetAlpha(DIM)
	icon.slot = Slot.New(icon, { icon = icon.picture, size = size, hover = false })
	local gold = UI.colors.alert
	icon.slot:Mark(gold[1], gold[2], gold[3])
	icon:EnableMouse(true)
	Shy.Hover.Attach(icon, function(self) return self.name end, "You're missing this. Someone in your group can cast it.")
	tray.icons[i] = icon
	return icon
end

-- Shows the pairs in `list` (at most `most`), and sizes the tray to them.
local function Fill(tray, list, most)
	local count = math.min(#list, most or #list)
	-- UNIT_AURA brings a read every frame in a fight; the same pairs stand where they stood.
	local was = tray.was
	if was and count == tray.count then
		local same = true
		for i = 1, count do
			if was[i] ~= list[i] then
				same = false
				break
			end
		end
		if same then return end
	end
	was = was or {}
	tray.was = was
	for i = 1, count do was[i] = list[i] end
	local size, riser = tray.size, tray.riser
	local ends, pad, foot = 0, 0, 0
	if riser then
		-- On the cell's top edge in front of its rim, its own line on every side, the icons the same room from each.
		local around = Margins()
		ends, pad, foot = around, around, around
	end
	for i = 1, math.max(count, #tray.icons) do
		local icon = i <= count and Icon(tray, i) or tray.icons[i]
		if i <= count then
			local buff = M.BUFFS[list[i]]
			if icon.pair ~= list[i] then
				icon.pair = list[i]
				icon.picture:SetTexture(C_Spell.GetSpellTexture(buff.spells[1]))
				icon.name = C_Spell.GetSpellName(buff.spells[1]) or ""
			end
			icon:ClearAllPoints()
			icon:SetPoint("BOTTOMRIGHT", tray, "BOTTOMRIGHT", -ends - (i - 1) * (size + GAP), foot)
			icon:Show()
		elseif icon then
			icon:Hide()
		end
	end
	tray:SetShown(count > 0)
	if count > 0 then tray:SetSize(count * size + (count - 1) * GAP + ends * 2, size + pad + foot) end
	tray.count = count
end

local trays = {}     -- unit -> { tray, memory, list, most }
local soon = {}

local function Wanted(unit)
	return T.db.missing and UnitExists(unit) and UnitIsPlayer(unit) and UnitIsFriend("player", unit)
end

local function Update(unit)
	local t = trays[unit]
	if not t then return end
	-- A cell's tray stands at the end of its row of icons, which can't be told anything in a fight: it changes
	-- once they can, and the row is told to stop short of it.
	if t.cell and not ns.Free() then
		ns.WhenFree("missing-" .. unit, function() Update(unit) end)
		return
	end
	-- (A cell of the healing grid has no top edge to stand on: its cells stand close.)
	local grid = t.cell and ns.Grid ~= nil and ns.Grid.On()
	if Wanted(unit) and not grid then M.Read(unit, t.memory, t.list) else wipe(t.list) end
	Fill(t.tray, t.list, t.most)
	if t.cell then ns.Plates.Room(unit, t.tray:IsShown() and t.tray:GetWidth() or 0) end
end

-- UNIT_AURA fires in bursts: read once, on the next frame.
local later = {}   -- unit -> its read on the next frame, made once
local function Soon(unit)
	if soon[unit] or not trays[unit] then return end
	soon[unit] = true
	local fn = later[unit]
	if not fn then
		fn = function()
			soon[unit] = nil
			Update(unit)
		end
		later[unit] = fn
	end
	C_Timer.After(0, fn)
end

function M.Apply()
	for unit in pairs(trays) do Update(unit) end
end

-- For tests and the options: the pairs `unit` is shown as missing.
function M.Shown(unit)
	local t = trays[unit]
	return t and t.tray:IsShown() and t.tray.count or 0
end

function M.Start()
	-- Yours: past the left end of the shelf's first row.
	local box, size = ns.Shelf.End()
	local mine = NewTray(box, size)
	mine:SetPoint("TOPRIGHT", box, "TOPLEFT", -8, 0)
	trays.player = { tray = mine, memory = {}, list = {} }
	-- A party member's: on their cell's top right, in a housing of its own.
	local frames = Shy.addons.Frames
	if frames and frames.EachFrame then
		local r = frames:Riser()
		frames:EachFrame(function(_, kind, unit, button)
			if kind ~= "party" then return end
			local tray = NewTray(button, CELL, r)
			tray:SetFrameLevel(button:GetFrameLevel() + 3)   -- over the cell's rim, as the row beside it
			tray:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 0)
			trays[unit] = { tray = tray, memory = {}, list = {}, most = CELL_MOST, cell = true }
		end)
	end
	-- A new look: a new border, so new room round the icons, and the row beside the tray told again.
	Shy:On("SHY_THEME", function()
		for unit, t in pairs(trays) do
			if t.cell then
				t.tray.was = nil
				Update(unit)
			end
		end
	end)
	-- One listener a unit: in a fight the event's own words are kept from us.
	for unit in pairs(trays) do
		local listener = CreateFrame("Frame")
		listener:RegisterUnitEvent("UNIT_AURA", unit)
		listener:SetScript("OnEvent", function() Soon(unit) end)
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", function(_, event)
		if event ~= "PLAYER_REGEN_ENABLED" then
			stale = true
			-- A seat may hold someone else now: what was known of it is forgotten.
			for _, t in pairs(trays) do wipe(t.memory) end
		end
		for known in pairs(trays) do Soon(known) end
	end)
end
