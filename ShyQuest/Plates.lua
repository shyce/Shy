-- Quest marks on nameplates: its kind's mark on creatures to kill or loot, and the card's mark on the NPC the
-- route leads to (quest giver, flight master, vendor, trainer, a guide step's target).
-- Nameplates are restricted (no measuring): one texture, one anchor, sized by a number, colored directly.
-- Plates are pooled, so each is decided again per unit.
-- With ShyPlates loaded the mark is handed over as a tag (Shy.addons.Plates:Tag) and drawn by its plate.
-- Listen to SHY_NAMEPLATE / SHY_NAMEPLATES, never SHY_PLATE (ShyFrames' unit frames).
-- A tag with `lead = true` is the one NPC being headed for; ShyPlates gives it a plaque.

local ADDON, ns = ...
local T = ns.T
local I, D, R = ns.Index, ns.Data, ns.Route

local SIZE = 18
local GAP = 3
local LEAD = 1.3            -- scale of a lead's mark on a default nameplate
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local WHITE = { 1, 1, 1 }
local marks = setmetatable({}, { __mode = "k" })   -- plate -> mark
local placed = setmetatable({}, { __mode = "k" })  -- mark -> last placement key

-- The least left among unfinished objectives needing more than one of this creature.
local function Left(id)
	local least
	for _, tie in ipairs(I.Npc(id) or {}) do
		local goal = tie.goal
		if goal and not tie.done and tie.kind ~= "sells" and goal.need and goal.have and goal.need > 1 then
			local left = goal.need - goal.have
			if left > 0 and (not least or left < least) then least = left end
		end
	end
	return least
end

-- Leads

-- The leading stop, when this creature is its NPC.
local function Heading(id)
	local stop = R.stops[1]
	local thing = stop and stop.thing
	if not thing or thing.id ~= id then return nil end
	if stop.kind ~= "turnin" and stop.kind ~= "pickup" and stop.kind ~= "fly" then return nil end
	-- Object and creature IDs overlap: match the name too.
	local npc = D.Npc(id)
	if not npc or npc.name ~= stop.who then return nil end
	-- Not a creature that only drops a quest starter.
	for _, action in ipairs(stop.actions or {}) do
		if action.from then return nil end
	end
	return stop
end

-- The sign of any errand stop (vendor, trainer) this creature is the NPC of, leading or not: its
-- `thing`, or one of the others to speak to there (`with`).
local function Errand(id)
	for _, stop in ipairs(R.stops) do
		if stop.kind == "errand" and stop.thing and ns.StopMark(stop) == stop.mark then
			local npc = D.Npc(id)
			if stop.thing.id == id and npc and npc.name == stop.who then return stop.mark end
			for _, other in ipairs(stop.with or {}) do
				if other.id == id and npc and npc.name == other.name then return stop.mark end
			end
		end
	end
end

-- Vendors the live guide steps name to sell to. Cached until the route rebuilds.
local sellers

local function Seller(id)
	if not sellers then
		sellers = {}
		for _, stop in ipairs(R.stops) do
			for _, npc in ipairs(stop.kind == "guide" and stop.view.sells or {}) do sellers[npc] = true end
		end
	end
	return sellers[id] and D.Npc(id) ~= nil
end

-- Vendors to buy a quest item from: a guide step's view.buys and a stop's `seller`. Cached like sellers.
local buyers

local function Buyer(id)
	if not buyers then
		buyers = {}
		for _, stop in ipairs(R.stops) do
			for _, npc in ipairs(stop.kind == "guide" and stop.view.buys or {}) do buyers[npc] = true end
			if stop.seller then buyers[stop.seller] = true end
		end
	end
	return buyers[id] and D.Npc(id) ~= nil
end

-- The live guide steps' targets, by name and by NPC ID where given: { kind, marker, npc }. Cached likewise.
local named

local function Named()
	if named then return named end
	named = {}
	if ns.StepTargets then
		local list, marker = ns.StepTargets()
		for _, target in ipairs(list) do
			local entry = { kind = target.kind, marker = marker[target.name], npc = target.npc }
			named[target.name] = entry
			if target.npc then named[target.npc] = entry end
		end
	end
	return named
end

-- A secret name (in instances) matches nothing.
local function Step(unit, id)
	local list = Named()
	if list[id] then return list[id] end
	local name = UnitName(unit)
	if name == nil or issecretvalue(name) then return nil end
	local entry = list[name]
	-- An entry with an NPC ID matches by ID only.
	if entry and not entry.npc then return entry end
end

-- Tags, in the form ShyPlates takes

-- The marks are the card's and the map's (ns.MarkTag): the glass, its bezel and its picture, the face lit
-- for the one chosen. In the compartment of a ShyPlates housing the picture stands alone (the tag's `flat`).

-- Every nameplate is asked its tag again at each route built, and most have the tag they had: a tag is made once
-- for what it shows and kept (the same list each time, never written to after), so a plate given the list it wears
-- asks nothing of the game. Made again when the theme's colors or the settings change (Forget).
local kept = { goal = {}, stop = {}, sign = {}, chip = {} }
local function Slot(of, key)
	local slot = of[key]
	if not slot then
		slot = {}
		of[key] = slot
	end
	return slot
end
local function Forget()
	for _, of in pairs(kept) do wipe(of) end
end

-- tone: the kind of what the creature is wanted for (Marks.lua, KIND): its emblem, in its color.
local function Tag(count, tone)
	count = count and math.min(count, 99) or false
	local of = Slot(kept.goal, tone or false)
	local tag = of[count]
	if not tag then
		tag = ns.MarkTag("goal", false, tone)
		tag.count, tag.objective = count or nil, true
		of[count] = tag
	end
	return tag
end

-- The kind of the first objective this creature still counts for.
local function Tone(id)
	for _, tie in ipairs(I.Npc(id) or {}) do
		if not tie.done and tie.kind ~= "turnin" and tie.kind ~= "pickup" and tie.kind ~= "sells" then return ns.TieTone(tie) end
	end
end

-- The card's mark for a stop (a hand-in, a quest to pick up, a flight): lit when the stop is chosen.
local function StopTag(stop)
	local of, chosen = Slot(kept.stop, stop.kind), stop.chosen and true or false
	local tag = of[chosen]
	if not tag then
		tag = ns.MarkTag(stop.kind, chosen)
		tag.lead = true
		of[chosen] = tag
	end
	return tag
end

-- An errand NPC's sign (Marks.lua, SIGN). `many`: one of several who would do, so not a lead.
local function SignTag(sign, many)
	many = many and true or false
	local of = Slot(kept.sign, sign)
	local tag = of[many]
	if not tag then
		tag = ns.MarkTag(sign, false)
		tag.lead = not many
		of[many] = tag
	end
	return tag
end

-- A guide target's raid-mark picture. `mark` lets a plate that also has the real raid mark show it once.
local function ChipTag(step, count)
	local many = step.kind == "mob"
	count = many and count and math.min(count, 99) or false
	local of = Slot(Slot(kept.chip, step.marker), many)
	local tag = of[count]
	if not tag then
		tag = { texture = RAID_ICON .. step.marker, color = WHITE, mark = step.marker, count = count or nil, lead = not many }
		of[count] = tag
	end
	return tag
end

-- The tag for this unit, or nil.
local function UnitTag(unit)
	local guid = UnitGUID(unit)
	if issecretvalue(guid) then return nil end
	local id = ns.Hover.CreatureID(guid)
	if not id then return nil end            -- a player, a pet
	local stop = Heading(id)
	if stop then return StopTag(stop) end
	local sign = Errand(id) or (Seller(id) and "sell") or (Buyer(id) and "buy")
	if sign then return SignTag(sign) end
	local step = Step(unit, id)
	if step then return ChipTag(step, Left(id)) end
	local mark = I.Mark(id)
	if mark == "goal" then return Tag(Left(id), Tone(id)) end
	-- Other vendors of a wanted quest item get the buy sign, unless they are quest givers (the game marks those).
	if mark ~= "turnin" and mark ~= "pickup" and I.Sells(id) then return SignTag("buy", true) end
	if mark ~= nil then return nil end
	local related = C_QuestLog.UnitIsRelatedToActiveQuest(unit)
	if not issecretvalue(related) and related == true then return Tag() end
end
ns.UnitTag = UnitTag          -- Hover.lua hands it to ShyTip's plate

-- Whether the other quest addon stands its own icon on this unit's plate (Yield.lua): it marks the
-- creatures quests count.
local function Theirs(unit)
	return ns.Yield ~= nil and ns.Yield.To("plates", unit)
end

-- The tag for this unit's nameplate, or nil, and whether the other addon's icon is on the plate too. An
-- objective's mark is then left to it; the NPC the route heads for, errands and guide targets stay ours.
local function Wanted(unit)
	if not T.db.plates.on then return nil end
	local tag = UnitTag(unit)
	local theirs = tag ~= nil and Theirs(unit)
	if theirs and tag.objective then return nil end
	return tag, theirs
end

-- On a default nameplate

-- beside: the other addon's icon stands at the plate's left, so a mark meant for there goes to its right.
local function Place(plate, mark, grown, beside)
	local where, size = T.db.plates.where, SIZE * T.db.plates.size * grown
	if beside and where == "left" then where = "right" end
	local key = where .. size
	if placed[mark] == key then return end
	placed[mark] = key
	mark:SetSize(size, size)
	mark:ClearAllPoints()
	if where == "above" then
		mark:SetPoint("BOTTOM", plate, "TOP", 0, GAP)
	elseif where == "right" then
		mark:SetPoint("LEFT", plate, "RIGHT", GAP, 0)
	else
		mark:SetPoint("RIGHT", plate, "LEFT", -GAP, 0)
	end
end

local function Picture(texture, file, coords, color)
	texture:SetTexture(file)
	if coords then texture:SetTexCoord(unpack(coords)) else texture:SetTexCoord(0, 1, 0, 1) end
	texture:SetVertexColor(color[1], color[2], color[3])
end

-- The layers under and over the picture, bottom to top: glass, lit face; bezel.
local LAYERS = { "back", "face", "over" }

local function Hide(mark)
	if not mark or mark.tag == nil then return end   -- (none, or put away already)
	mark.tag = nil
	mark:Hide()
	for _, key in ipairs(LAYERS) do mark[key]:Hide() end
end

local function Paint(unit)
	if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate or plate:IsForbidden() then return end
	local tag, beside = Wanted(unit)
	local mark = marks[plate]
	-- ShyPlates draws the tag on its own plates.
	local plates = Shy.addons.Plates
	if (plates and plates.Tag and plates:Tag(plate, tag)) or not tag then
		Hide(mark)
		return
	end
	if not mark then
		mark = plate:CreateTexture(nil, "OVERLAY")
		mark.back = plate:CreateTexture(nil, "ARTWORK")
		mark.face = plate:CreateTexture(nil, "ARTWORK", nil, 1)
		mark.over = plate:CreateTexture(nil, "OVERLAY", nil, 1)
		for _, key in ipairs(LAYERS) do mark[key]:SetAllPoints(mark) end
		marks[plate] = mark
	end
	Place(plate, mark, tag.lead and LEAD or 1, beside)
	-- (The tag it wears already: a tag is the same list for the same mark.)
	if mark.tag == tag then return end
	mark.tag = tag
	Picture(mark, tag.texture, tag.coords, tag.color)
	for _, key in ipairs(LAYERS) do
		local layer = tag[key]
		mark[key]:SetShown(layer ~= nil)
		if layer then Picture(mark[key], layer.texture or tag.texture, layer.coords, layer.color) end
	end
	mark:Show()
end

local function Clear(unit)
	if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	Hide(plate and marks[plate])
end

local function PaintAll()
	named, sellers, buyers = nil, nil, nil
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		if not plate:IsForbidden() then
			local unit = plate.unitToken          -- set by NamePlateBaseMixin:SetUnit
			if unit then Paint(unit) end
		end
	end
end
ns.ApplyPlates = PaintAll

Shy:On("SHY_LOGIN", function()
	local events = CreateFrame("Frame")
	events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then Paint(unit) else Clear(unit) end
	end)
	ns.OnApply(function()
		Forget()
		PaintAll()
	end)
	-- Repaint on a rebuild, or when re-measuring changed the leading NPC.
	local headed
	ns.OnRoute(function(rebuilt)
		local stop = R.stops[1]
		local now = stop and stop.thing or nil
		if rebuilt or now ~= headed then PaintAll() end
		headed = now
	end)
	Shy:On("SHY_NAMEPLATE", Paint)
	Shy:On("SHY_NAMEPLATES", PaintAll)
	-- Samples for ShyPlates' options preview.
	local plates = Shy.addons.Plates
	local function Samples()
		if not plates then return end
		plates.sampleTag = Tag()
		plates.sampleLead = StopTag({ kind = "turnin" })
	end
	Samples()
	-- A tag's colors were read when it was made: a lit white mark wears the accent.
	Shy:On("SHY_THEME", function()
		Forget()
		Samples()
		PaintAll()
	end)
end)
