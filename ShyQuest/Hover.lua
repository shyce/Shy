-- Quest lines on GameTooltip for a creature, object or item: quests that need it (progress, drop
-- chance), quests it gives or completes, a quest item's status, and party progress (Party.lua).
-- Also a warning on hostile elites three or more levels above the player, in careful play only (the
-- hardcore route, or a hardcore realm).
--
-- The game's tooltip already names a quest and its progress on creatures it counts (QuestTitle
-- lines). For those, the drop chance goes at the right of the game's own objective line and only
-- party progress is added.
-- Lines are added in TooltipDataProcessor post-calls, so they are rewritten whenever the game rebuilds
-- the tooltip. Only the tooltip's data is read, never its text. Anything secret is left alone.

local ADDON, ns = ...
local T = ns.T
local D, L, I, Tips = ns.Data, ns.Log, ns.Index, ns.Tips
local C = Shy.UI.colors

local WHITE, DIM, HOT, GOLD, GOOD = C.text, C.dim, C.hot, C.alert, C.good
local MARK = 12              -- size of the mark before a quest's name
local ROW_MARK = 16          -- a mark's seat, leading a hover's row
local MOST_OFFERS = 4        -- quests listed for one quest giver
local NONE = {}

local H = {}
ns.Hover = H

local STEEP = 3              -- levels above the player from which an elite is a danger
local ELITES = { [1] = "elite", [2] = "rare elite", [3] = "boss" }

-- { kind, low, high, why } for a dangerous creature by NPC ID, or nil: an elite STEEP or more levels above
-- the player, and no other. why: the text shown.
function H.Danger(id)
	local npc = id and D.Npc(id)
	local kind = npc and ELITES[npc.rank]
	if not kind or npc.maxLevel <= 0 then return nil end
	local above = npc.maxLevel - L.Level()
	if above < STEEP then return nil end
	return { kind = kind, low = npc.minLevel > 0 and npc.minLevel or npc.maxLevel, high = npc.maxLevel,
		why = ("%s, %d levels above you"):format(kind, above) }
end

local HOSTILE = 2            -- the game's reaction at or below which a creature is hostile to the player

-- Only hostile units count: attackable, and hostile to the player (not a friendly guard, an emissary of the
-- player's side, nor a creature that is merely attackable).
local function Foe(unit)
	if issecretvalue(unit) or type(unit) ~= "string" then return false end
	local can = UnitCanAttack("player", unit)
	if issecretvalue(can) or can ~= true then return false end
	local reaction = UnitReaction(unit, "player")
	return not issecretvalue(reaction) and reaction ~= nil and reaction <= HOSTILE
end

-- "elite, level 15-16"
local function DangerWords(danger)
	return danger.why .. ", level " .. (danger.low == danger.high and danger.high or (danger.low .. "-" .. danger.high))
end

-- Whether the warnings are on: the switch, and careful play (the hardcore route, or a hardcore realm).
local function Warns()
	return T.db.hover.careful and ns.Safety ~= nil and ns.Safety.Careful()
end

local function Careful(tip, id)
	-- ShyTip marks danger on the tooltip itself: no lines then.
	if Shy.Tip and Shy.Tip.MarksDanger() then return end
	local danger = Warns() and H.Danger(id)
	if not danger then return end
	Tips.Line(tip, "Careful", GOLD)
	Tips.Line(tip, DangerWords(danger), DIM, true)
end

local function Percent(chance)
	return chance and (chance .. "%") or ""
end

-- The objective's own text ("Crisp Spider Meat: 3/5"), else the item's or quest's name.
local function GoalText(tie)
	local goal = tie.goal
	if goal and goal.text and goal.text ~= "" then return goal.text end
	return tie.item and tie.item.name or tie.title
end

-- The picture leading an objective's line, by what is to be done for it, as on a step's hover. With
-- the count in its text, the hover draws the line as a row with pips (Shy.Hover.Tally).
local GLYPH = { kill = "kill", use = "use" }
local function Lead(tie)
	return Shy.Hover.GlyphText(GLYPH[tie.kind] or "loot", ns.ToneColor(ns.TieTone(tie))) .. " "
end

-- The kind of the first objective among `ties` still open, for the mark before their quest's name.
local function Tone(ties)
	for _, tie in ipairs(ties) do
		if not tie.done and tie.kind ~= "turnin" and tie.kind ~= "pickup" then return ns.TieTone(tie) end
	end
end

-- `ties` grouped by quest, in first-seen order.
local function ByQuest(ties)
	local order, by = {}, {}
	for _, tie in ipairs(ties) do
		local group = by[tie.id]
		if not group then
			group = { id = tie.id, title = tie.title, level = tie.level, ties = {}, seen = {} }
			by[tie.id] = group
			order[#order + 1] = group
		end
		-- One line per objective.
		local key = tie.kind .. (tie.index or 0)
		if not group.seen[key] then
			group.seen[key] = true
			group.ties[#group.ties + 1] = tie
		end
	end
	return order
end

-- Writes a drop chance at the right of the game's own line for that objective, found by the
-- item it names. False when the game has no such line, or it already says something there.
local function OnOwnLine(tip, lines, tie)
	local name, have = tie.item.name, tie.goal and tie.goal.have
	local at
	for _, line in ipairs(lines) do
		local counts = type(line.have) ~= "number" or type(have) ~= "number" or line.have == have
		-- The line about it: "Big Bear Meat" is not "Bear Meat".
		if counts and not at and L.Names(line.text, name) then at = line.at end
	end
	local right = at and tip:GetRightLine(at)
	if type(right) ~= "table" then return false end
	local shown, said = right:IsShown(), right:GetText()
	if issecretvalue(shown) or issecretvalue(said) or (shown and said and said ~= "") then return false end
	right:SetText(Percent(tie.chance))
	right:SetTextColor(HOT[1], HOT[2], HOT[3])
	right:Show()
	return true
end

-- Lines for a creature or object. named: quests the game's own lines already name, each with
-- its objective lines (Named).
function H.Thing(tip, ties, named)
	local offers, more = 0, 0
	for _, group in ipairs(ByQuest(ties)) do
		local titled = false
		local function Head()
			if titled then return end
			titled = true
			Tips.Line(tip, ns.MarkText("goal", MARK, Tone(group.ties)) .. " " .. group.title, WHITE)
		end
		for _, tie in ipairs(group.ties) do
			if tie.kind == "turnin" then
				Tips.Double(tip, ns.MarkText("turnin", MARK) .. " " .. tie.title, "Turn in", GOLD, DIM)
				Tips.Under(tip, tie.id, nil, true)
			elseif tie.kind == "pickup" then
				offers = offers + 1
				if offers <= MOST_OFFERS then
					local color = GetQuestDifficultyColor(tie.level > 0 and tie.level or L.Level())
					tip:AddDoubleLine(ns.MarkText("pickup", MARK) .. " " .. tie.title, tie.level > 0 and ("Level " .. tie.level) or "",
						color.r, color.g, color.b, DIM[1], DIM[2], DIM[3])
					-- Started by an item this creature drops or sells.
					if tie.from and tie.item then
						Tips.Double(tip, (tie.from == "v" and "Sells " or "Drops ") .. tie.item.name .. ", which starts it",
							Percent(tie.chance), DIM, HOT, true)
					end
				else
					more = more + 1
				end
			elseif not tie.done then
				if tie.kind == "sells" then
					Head()
					Tips.Line(tip, "Sells " .. tie.item.name, DIM, true)
				elseif named[tie.id] then
					-- The game shows the quest and count: the drop chance goes on that line, party progress under.
					if tie.chance and not OnOwnLine(tip, named[tie.id], tie) then
						Tips.Double(tip, "Drops " .. tie.item.name, Percent(tie.chance), DIM, HOT, true)
					end
					Tips.Under(tip, tie.id, tie.index, true)
				else
					Head()
					Tips.Double(tip, Lead(tie) .. GoalText(tie), Percent(tie.chance), WHITE, HOT, true)
					Tips.Under(tip, tie.id, tie.index, true)
				end
			end
		end
	end
	if more > 0 then Tips.Line(tip, ("and %d more quest%s"):format(more, more == 1 and "" or "s"), DIM, true) end
end

-- A creature in the way of one an open objective wants (I.Blocks): that quest, and what killing it does.
function H.Room(tip, id)
	if not (I and I.Blocks) then return end
	local wanted, tie = I.Blocks(id)
	if not wanted then return end
	local tone = ns.TieTone(tie)
	Tips.Line(tip, ns.MarkText("goal", MARK, tone) .. " " .. tie.title, WHITE)
	Tips.Double(tip, Shy.Hover.GlyphText("kill", ns.ToneColor(tone)) .. " Kill it to make room for " .. Shy.Plural(wanted.name),
		"Shared spawn", WHITE, DIM, true)
end

-- With the other quest addon's quest lines on the tooltip (Yield.lua) ours step aside; while its drop chances are off,
-- ours still stand at the right of the game's own objective lines, which adds no line.
local function Theirs(what)
	return ns.Yield ~= nil and ns.Yield.To(what)
end
H.Theirs = Theirs

function H.Chances(tip, ties, named)
	if Theirs("drops") then return end
	for _, tie in ipairs(ties) do
		if not tie.done and tie.chance and tie.item and named[tie.id] then OnOwnLine(tip, named[tie.id], tie) end
	end
end

-- For ShyTip's plate: the mark this creature's nameplate carries.
local function Glance(tip, unit)
	local say = Shy.Tip and Shy.Tip.Glance
	if not say or not ns.UnitTag or issecretvalue(unit) or type(unit) ~= "string" then return end
	say(tip, { tag = ns.UnitTag(unit) })
end

-- Labels for I.Quests' quest states.
local STANDS = { held = "In your log", ready = "Ready to turn in", failed = "Failed", open = "Not accepted yet",
	done = "Turned in", dropped = "Abandoned", outgrown = "Outgrown", far = "Too high for now" }
local UNTAKEN = { open = true, outgrown = true, far = true }
-- Which of several quests of one name speaks for it: the one that matters most now.
local LEADS = { ready = 1, failed = 2, held = 3, open = 4, far = 5, outgrown = 6, dropped = 7, done = 8 }

-- An item's quests as the lines to say of them: one a name (the parts of a chain share theirs, and "turned
-- in" beside "ready to turn in" under one name reads as a contradiction), and nothing of what is behind
-- you while another still wants the item. `said`: quests and names with a line already; each quest dealt
-- with here is added to it.
local function Told(quests, behind, said, named)
	local lead, out = {}, {}
	for _, quest in ipairs(quests) do
		if not said[quest.id] then
			said[quest.id] = true
			if not named[quest.title] and (behind or not quest.behind) then
				local first = lead[quest.title]
				if not first then
					lead[quest.title] = quest
					out[#out + 1] = quest.title
				elseif (LEADS[quest.state] or 9) < (LEADS[first.state] or 9) then
					lead[quest.title] = quest
				end
			end
		end
	end
	for i, title in ipairs(out) do out[i] = lead[title] end
	return out
end

-- Lines for an item: log quests that need it, the quest it starts, and for a pure quest item the
-- state of its quests, or that it is left over once they are all done.
function H.Item(tip, ties, id)
	local said, named = {}, {}
	for _, tie in ipairs(ties or {}) do
		said[tie.id] = true
		if tie.kind ~= "pickup" then named[tie.title] = true end
		if tie.kind == "pickup" then
			local color = GetQuestDifficultyColor(tie.level > 0 and tie.level or L.Level())
			tip:AddDoubleLine(ns.MarkText("pickup", MARK) .. " Starts " .. tie.title, tie.level > 0 and ("Level " .. tie.level) or "",
				color.r, color.g, color.b, DIM[1], DIM[2], DIM[3])
		elseif tie.kind == "collect" or tie.kind == "needs" then
			local goal = tie.goal
			local count = (tie.kind == "collect" and goal.need and goal.need > 0) and (goal.have .. "/" .. goal.need) or "Needed"
			Tips.Double(tip, ns.MarkText("goal", MARK, ns.TieTone(tie)) .. " " .. tie.title, count, WHITE, tie.done and GOOD or HOT)
			Tips.Under(tip, tie.id, tie.index, true)
		end
	end
	local quests, behind
	if id then quests, behind = I.Quests(id) end
	for _, quest in ipairs(Told(quests or {}, behind, said, named)) do
		local state = quest.state
		local name = (quest.starts and (UNTAKEN[state] and "Starts " or "Started ") or "") .. quest.title
		if state == "ready" then
			Tips.Double(tip, ns.MarkText("turnin", MARK) .. " " .. name, STANDS[state], GOLD, DIM)
		elseif state == "held" or state == "failed" then
			Tips.Double(tip, ns.MarkText("goal", MARK, id and ns.ItemKind(id)) .. " " .. name, STANDS[state], WHITE, state == "failed" and GOLD or DIM)
		else
			Tips.Double(tip, name, STANDS[state], state == "open" and WHITE or DIM, DIM)
		end
	end
	if behind then Tips.Line(tip, "No quest needs this anymore.", DIM) end
	-- How it stands with what is ahead (Stash.lua): the quest your guide, or one you haven't taken, wants it
	-- for, where no line above named it; that it can wait in the bank; or that it is needed with you and
	-- lies in the bank or the mailbox.
	local stash = ns.Stash
	if id and stash and stash.Status then
		local when, quest = stash.Status(id)
		if (when == "now" or when == "later") and not (quest and said[quest]) then
			-- (A step of the guide's that asks for it by itself, for no quest: the guide's.)
			local entry, data = quest and L.entries[quest], quest and ns.Data.Quest(quest)
			Tips.Double(tip, entry and entry.title or data and data.name or "Your guide", when == "later" and "Needed later" or "Needed soon", WHITE, DIM)
		end
		if when == "later" then Tips.Line(tip, "It can wait in your bank.", DIM) end
		if when == "now" and stash.Fetch then
			local bank, mail = stash.Fetch(id)
			if bank > 0 then Tips.Line(tip, bank == 1 and "Take it out of your bank." or ("Take %d out of your bank."):format(bank), GOLD) end
			if mail > 0 then Tips.Line(tip, mail == 1 and "Take it out of your mailbox." or ("Take %d out of your mailbox."):format(mail), GOLD) end
		end
	end
end

-- Tooltip data

-- "Creature-0-4170-0-41-442-00003A1B2C" is 442.
local function CreatureID(guid)
	if type(guid) ~= "string" then return nil end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
H.CreatureID = CreatureID

-- Quests the game's own lines name, by ID, each with its objective lines: { text, have, at }
-- (at: the line's place on the tooltip, only once a tooltip has drawn it). nil when any of it is
-- secret: a line left out would read as one the game doesn't show.
local function Named(data)
	local named = {}
	local lines = data.lines
	if issecretvalue(lines) or type(lines) ~= "table" then return nil end
	local LINE = Enum.TooltipDataLineType
	local own
	for _, line in ipairs(lines) do
		local kind, id = line.type, line.id
		if issecretvalue(kind) or issecretvalue(id) then return nil end
		if kind == LINE.QuestTitle then
			own = nil
			if id then
				own = named[id] or {}
				named[id] = own
			end
		elseif kind == LINE.QuestObjective and own then
			local text, have, at = line.leftText, line.numFulfilled, line.lineIndex
			if issecretvalue(text) or issecretvalue(have) or issecretvalue(at) then return nil end
			if type(text) == "string" then
				own[#own + 1] = { text = text, have = have, at = type(at) == "number" and at or nil }
			end
		end
	end
	return named
end

-- What the game's own lines on a creature (Named) say of what it drops. The game names on a creature each
-- quest it counts for, with every objective of it the creature counts for, finished or not. So where it
-- names a quest of ours but no line for an unfinished objective whose item the data says the creature
-- drops, the creature doesn't drop it; where it has the line, it does (D.NoteDrop). Only an objective whose
-- own text names its item is judged: the game's line for it is known by that name.
local function Learn(id, named)
	local changed = false
	for quest, lines in pairs(named) do
		if #lines > 0 and L.entries[quest] then
			for _, goal in ipairs(L.Goals(quest)) do
				for _, token in ipairs(goal.finished and NONE or goal.tokens) do
					local item = token.kind == "i" and D.ListsDropper(token.id, id) and D.Item(token.id)
					if item and L.Names(goal.text, item.name) then
						local shown = false
						for _, line in ipairs(lines) do
							if L.Names(line.text, item.name) then shown = true end
						end
						if D.NoteDrop(id, item.id, shown) then changed = true end
					end
				end
			end
		end
	end
	if changed then ns.Refresh() end
end

-- The main tooltip being filled with its primary data (not a comparison or an appended block).
local function Ours(tip, data, also)
	if tip ~= GameTooltip and tip ~= also then return false end
	if tip:IsForbidden() or issecretvalue(data) or type(data) ~= "table" then return false end
	return tip:GetPrimaryTooltipData() == data
end

local function OnUnit(tip, data)
	if not Ours(tip, data) then return end
	local guid = data.guid
	if issecretvalue(guid) then return end
	local id = CreatureID(guid)
	local _, unit = tip:GetUnit()
	local named = id and Named(data)
	if named then Learn(id, named) end
	if T.db.hover.units then
		local ties = id and I.Npc(id)
		if ties and named then
			if Theirs("tooltips") then H.Chances(tip, ties, named) else H.Thing(tip, ties, named) end
		end
		if id and named then H.Room(tip, id) end
		if id then Glance(tip, unit) end
	end
	if id and Foe(unit) then Careful(tip, id) end
end

-- A creature the data says drops what an open objective asks for is read when its nameplate shows (Learn),
-- once each until the log changes, so what it doesn't drop is known before it is hovered.
local read, readAt = {}, nil
local function Glimpse(_, _, unit)
	if issecretvalue(unit) or type(unit) ~= "string" then return end
	local guid = UnitGUID(unit)
	if issecretvalue(guid) then return end
	local id = CreatureID(guid)
	if not id then return end
	if readAt ~= L.stamp then
		wipe(read)
		readAt = L.stamp
	end
	if read[id] then return end
	read[id] = true
	local asks = false
	for _, tie in ipairs(I.Npc(id) or NONE) do
		if tie.kind == "drop" and not tie.done then asks = true end
	end
	if not asks then return end
	local data = C_TooltipInfo.GetUnit(unit)
	if issecretvalue(data) or type(data) ~= "table" then return end
	local named = Named(data)
	if named then Learn(id, named) end
end

if Shy.Memory then
	Shy.Memory.Cache("Quest hover: creatures read off their plates", function() wipe(read) end, function()
		local n = 0
		for _ in pairs(read) do n = n + 1 end
		return n
	end)
end

-- One chat warning per dangerous creature targeted.
local warned = {}
local function OnTarget()
	if not Warns() or UnitIsPlayer("target") or UnitIsDead("target") or not Foe("target") then return end
	local guid = UnitGUID("target")
	if guid == nil or issecretvalue(guid) then return end
	local id = CreatureID(guid)
	if not id or warned[id] then return end
	local danger = H.Danger(id)
	if not danger then return end
	warned[id] = true
	local name = UnitName("target")
	if name == nil or issecretvalue(name) then name = D.Name("npcs", id) or "that one" end
	T:Print(("careful, |cffffffff%s|r is %s."):format(name, DangerWords(danger)))
end

local function OnObject(tip, data)
	if not T.db.hover.objects or not Ours(tip, data) then return end
	local lines = data.lines
	if issecretvalue(lines) or type(lines) ~= "table" then return end
	local name = lines[1] and lines[1].leftText
	if issecretvalue(name) or type(name) ~= "string" or name == "" then return end
	local ties = I.Object(name)
	local named = ties and Named(data)
	if named then
		if Theirs("tooltips") then H.Chances(tip, ties, named) else H.Thing(tip, ties, named) end
	end
end

local function OnItem(tip, data)
	if not T.db.hover.items or Theirs("tooltips") or not Ours(tip, data, ItemRefTooltip) then return end
	local id = data.id
	if issecretvalue(id) or type(id) ~= "number" then return end
	H.Item(tip, I.Item(id), id)
end

Shy:On("SHY_LOGIN", function()
	Shy.OnTip(Enum.TooltipDataType.Unit, "a quest's creature", OnUnit)
	Shy.OnTip(Enum.TooltipDataType.Object, "a quest's object", OnObject)
	Shy.OnTip(Enum.TooltipDataType.Item, "a quest's item", OnItem)
	-- In a hover the mark before a quest's name is drawn whole, as the row's lead (tooltips, and the
	-- lines Tips.lua writes for pins and the tracker).
	for _, kind in ipairs({ "goal", "pickup", "turnin" }) do
		Shy.Hover.Mark(ns.MarkText(kind, MARK) .. " ", ns.MarkSeat(kind, ROW_MARK))
	end
	-- An objective's emblem in each kind's color is a mark of its own in the text.
	for tone in pairs(ns.KIND) do
		Shy.Hover.Mark(ns.MarkText("goal", MARK, tone) .. " ", ns.MarkSeat("goal", ROW_MARK, nil, tone))
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	events:SetScript("OnEvent", OnTarget)
	local plates = CreateFrame("Frame")
	plates:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	plates:SetScript("OnEvent", Shy.Clocked("plates: what creatures drop", Glimpse))
end)
