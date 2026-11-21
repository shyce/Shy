-- The tooltip of the icon under the mouse, and a menu for whoever cast it.
--
-- An aura icon is the game's. It runs no script of ours, its own tooltip is forbidden (no lines, no look of
-- ours, no tooltip post-call), and asked whether the mouse is over it, it answers with a secret. But the game
-- places the icons by rules that can be followed (AnchorUtil.ApplyFlowLayout, the AuraUtil comparators, the
-- candidate filters), and out of a fight every aura can be read: so where each icon stands and which aura it
-- shows is worked out here from what each container was told (Kit's plans), and the mouse is matched to one.
--
-- Out of a fight the icons' own tooltip is given no place and the game's ordinary tooltip is shown for the
-- aura under the mouse instead: the one every other addon can dress and add to (the caster's line among it).
-- A fight keeps auras from us, so just before one starts (ADDON_RESTRICTION_STATE_CHANGED while it is
-- "activating", and PLAYER_REGEN_DISABLED) the icons' own tooltip has its place back.
--
-- Shift + right-click on the shelf: a right-click on an aura button removes the buff and the button runs no
-- script of ours, so while Shift is held with the mouse on the shelf a shield of ours lies over the box and
-- takes the click: the menu is for the caster of the buff under the mouse (ShyTip's person menu), or lists
-- your buffs by caster when the mouse is on none.

local ADDON, ns = ...
local T, K = ns.T, ns.Kit
local UI = Shy.UI

local C = {}
ns.Caster = C

local LOOK = 0.1          -- seconds between looks
local REFRESH = 1         -- seconds before a shown tooltip is filled again (its time left)
local REACH = 400         -- how far from a container's corner its icons may stand: nearer is worth working out

local ticker
local holder              -- owns the tooltip while it is ours
local told                -- the first failure, said once
local last = {}           -- what the last looks found (for /shy buffs who)
local looks = 0
local shownKey, shownAt   -- what the tooltip shows, and since when

-- Said once in chat (the game shows no Lua errors), and kept for the report.
local function Report(where, err)
	err = tostring(err)
	last.error = where .. ": " .. err
	if told then return end
	told = true
	T:Print("buff tooltips, " .. where .. ": " .. err)
end

-- Where the icons stand

local sorts
local function Sorts()
	if not sorts then
		sorts = {
			[AuraContainerSortMethod.Default] = AuraUtil.DefaultAuraCompare,
			[AuraContainerSortMethod.ExpirationOnly] = AuraUtil.ExpirationOnlyAuraCompare,
			[AuraContainerSortMethod.NameOnly] = AuraUtil.NameOnlyAuraCompare,
		}
	end
	return sorts
end

-- Every aura on `unit` the filter string takes, as the game hands them out. Nil when one can't be read.
local function Auras(unit, filter)
	local list, whole = {}, true
	local function Slots(token, ...)
		for i = 1, select("#", ...) do
			local aura = C_UnitAuras.GetAuraDataBySlot(unit, (select(i, ...)))
			if issecretvalue(aura) then
				whole = false
			elseif aura then
				if issecretvalue(aura.auraInstanceID) or issecretvalue(aura.duration) or issecretvalue(aura.spellId) then
					whole = false
				else
					list[#list + 1] = aura
				end
			end
		end
		return token
	end
	local token
	repeat
		token = Slots(C_UnitAuras.GetAuraSlots(unit, filter, nil, token))
	until token == nil
	return whole and list or nil
end

-- The game's candidate filters, as far as ours use them (AuraContainerUtil.DoesAuraPassCandidateFilters).
local function Passes(aura, filters)
	if not filters then return true end
	if filters.excludeSpellIDs and filters.excludeSpellIDs[aura.spellId] then return false end
	if filters.includeSpellIDs and not filters.includeSpellIDs[aura.spellId] then return false end
	if filters.maxDuration and (aura.duration > filters.maxDuration or aura.duration == 0) then return false end
	return true
end

-- A plan's rows in the order the game lays them out: { layout, hit, list }, a list item being an aura or
-- { slot = inventory slot } for a weapon's coating. Nil when it can't be said.
local function Rows(plan)
	local rows = {}
	local coating = plan.coating
	if coating.layout then
		local list = {}
		for _, slot in ipairs(coating.order) do
			local worn = AuraContainerItemEnchantmentToInventorySlot[slot]
			if coating.on[slot] and worn and C_PaperDollInfo.GetTemporaryEnchantmentInfo(worn) then list[#list + 1] = { slot = worn } end
		end
		rows[#rows + 1] = { layout = coating.layout, hit = coating.hit, list = list }
	end
	for _, group in ipairs(plan.groups) do
		if group.on then
			local compare = Sorts()[group.options.sortMethod]
			local all = compare and Auras(plan.unit, group.filter)
			if not all then return nil end
			local list = {}
			for _, aura in ipairs(all) do
				if Passes(aura, group.filters) then list[#list + 1] = aura end
			end
			table.sort(list, compare)
			local most = group.options.maxFrameCount
			if most then
				for i = #list, most + 1, -1 do list[i] = nil end
			end
			rows[#rows + 1] = { layout = group.options.layout, hit = group.hit, list = list }
		end
	end
	return rows
end

-- AnchorUtil.ApplyFlowLayout, for rows that flow sideways: each item's place as distances from the corner the
-- first one stands in, along the row (`along`) and across the rows (`across`), with the size the mouse can be on.
local function Cells(rows, line)
	local cells = {}
	local along, across = 0, 0      -- where the next one goes
	local used, tall = 0, 0         -- the line so far: its length (with the gap after its last), its height
	local placed = false
	local function NextLine(gap)
		along, across = 0, across + tall + gap
		used, tall = 0, 0
	end
	for _, row in ipairs(rows) do
		local layout = row.layout
		local gap, lineGap = layout.elementSpacing or 0, layout.lineSpacing or 0
		local before, groupGap = layout.groupSpacing or 0, layout.groupLineSpacing or lineGap
		if placed and #row.list > 0 then
			if layout.forceNewLine then
				NextLine(groupGap)
			elseif before > 0 then
				if used > 0 and used + before > line then
					NextLine(groupGap)
				else
					along, used = along + before, used + before
				end
			end
		end
		for _, item in ipairs(row.list) do
			local width, height = layout.elementWidth, layout.elementHeight
			local after = used > 0 and used + width or width
			if used > 0 and after > line then
				NextLine(lineGap)
				after = width
			end
			cells[#cells + 1] = { along = along, across = across, w = row.hit[1], h = row.hit[2], item = item }
			along, used, tall = along + width + gap, after + gap, math.max(tall, height)
			placed = true
		end
	end
	return cells
end

-- A plan's corner on screen and the way its icons run from it, in the cursor's units. Nil when it can't be read.
local function Corner(plan)
	local at = plan.at
	local frame = at and at.frame
	if not frame or not frame:IsVisible() then return nil end
	local eff = frame:GetEffectiveScale()
	local x = at.corner:find("RIGHT") and frame:GetRight() or frame:GetLeft()
	local y = at.corner:find("TOP") and frame:GetTop() or frame:GetBottom()
	if issecretvalue(eff) or issecretvalue(x) or issecretvalue(y) or not (eff and x and y) then return nil end
	local unit = eff * plan.scale   -- one of the container's own units, on screen
	return x * eff + at.x * unit, y * eff + at.y * unit, unit, plan.flow.across == "Left" and -1 or 1, plan.flow.up == "Up" and 1 or -1
end

-- The icon under the mouse: { unit, id | slot, name, left, right, top, bottom (on screen), bar }, or nil.
local function Find()
	local mx, my = GetCursorPosition()
	for _, plan in pairs(K.Plans()) do
		if plan.on and plan.unit then
			local cx, cy, unit, dx, dy = Corner(plan)
			if cx then
				local u, v = (mx - cx) * dx / unit, (my - cy) * dy / unit
				local reach = plan.flow.line or REACH
				if u >= 0 and u <= reach and v >= 0 and v <= REACH then
					local rows = Rows(plan)
					for _, cell in ipairs(rows and Cells(rows, plan.flow.line or math.huge) or {}) do
						if u >= cell.along and u <= cell.along + cell.w and v >= cell.across and v <= cell.across + cell.h then
							local x0, x1 = cx + dx * cell.along * unit, cx + dx * (cell.along + cell.w) * unit
							local y0, y1 = cy + dy * cell.across * unit, cy + dy * (cell.across + cell.h) * unit
							local item = cell.item
							return { unit = plan.unit, id = item.auraInstanceID, slot = item.slot, name = item.name,
								left = math.min(x0, x1), right = math.max(x0, x1), bottom = math.min(y0, y1), top = math.max(y0, y1),
								bar = cell.w > 3 * cell.h, down = dy < 0 }
						end
					end
				end
			end
		end
	end
end

-- The tooltip

local function Drop()
	if not shownKey then return end
	shownKey = nil
	if GameTooltip:IsOwned(holder) then GameTooltip:Hide() end
end

-- Beside the icon, where the icon's own would hang: under a shelf icon to its left, left of a bar, over an
-- icon on a unit frame to its right. `again`: the same icon as before, filled anew where it stands.
local function Tip(hit, again)
	if not again then
		local scale = UIParent:GetEffectiveScale()
		GameTooltip:SetOwner(holder, "ANCHOR_NONE")
		GameTooltip:ClearAllPoints()
		if hit.bar then
			GameTooltip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", hit.left / scale - 4, hit.top / scale)
		elseif hit.down then
			GameTooltip:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", hit.left / scale, hit.bottom / scale - 2)
		else
			GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", hit.right / scale, hit.top / scale + 2)
		end
	end
	if hit.slot then
		GameTooltip:SetInventoryItem("player", hit.slot)
	else
		GameTooltip:SetUnitAuraByAuraInstanceID(hit.unit, hit.id)
	end
end

-- The mouse resting where nothing was found finds nothing again until something moves: the auras of the units
-- watched (UNIT_AURA), who they are, a weapon's coating. Then nothing is worked out, but once a second, for
-- anything that moves without a word (a box dragged, the screen's scale).
local still = { x = nil, y = nil, at = 0, dirty = true }
local STILL = 1
local function Stirred()
	still.dirty = true
end

local function Look()
	looks = looks + 1
	last.free = ns.Free()
	if not last.free then
		Drop()
		still.dirty = true
		return
	end
	-- The fight is over: the tooltip is ours again.
	if not K.Owning() then last.refused = K.Tips(true) end
	local mx, my = GetCursorPosition()
	local now = GetTime()
	if not shownKey and not still.dirty and mx == still.x and my == still.y and now - still.at < STILL then return end
	still.x, still.y, still.at, still.dirty = mx, my, now, false
	local hit = Find()
	last.hit = hit and (hit.slot and "a weapon's coating" or hit.name) or nil
	if hit then last.seen, last.seenAt = last.hit, GetTime() end
	if not hit then
		Drop()
		return
	end
	local key = hit.slot and ("slot" .. hit.slot) or (hit.unit .. ":" .. hit.id)
	local same = key == shownKey and GameTooltip:IsOwned(holder)
	if same and GetTime() - shownAt < REFRESH then return end
	Tip(hit, same)
	shownKey, shownAt = key, GetTime()
end

-- A fight is about to keep auras from us: the icons' own tooltip has its place back.
local function Yield()
	Drop()
	if not K.Owning() then return end
	last.kept = K.Tips(false)
end

-- Shift + right-click on the shelf

local shield

local function Kind(who)
	if who.player then return who.foe and "foe" or "friend" end
	return who.foe and "enemy" or "npc"
end

local function Person(entry)
	local person = { name = entry.who.name, guid = entry.guid, kind = Kind(entry.who) }
	local tip = Shy.addons.Tip
	if tip and tip.PersonItems then return tip:PersonItems(person) end
	return {
		{ heading = person.name },
		{ text = "Whisper", click = function() ChatFrameUtil.SendTell(person.name) end },
		{ text = "Thank", click = function() C_ChatInfo.PerformEmote("THANK", person.name) end },
		{ text = "Wave", click = function() C_ChatInfo.PerformEmote("WAVE", person.name) end },
	}
end

function C.Menu()
	local tweaks = Shy.addons.Tweaks
	local list = tweaks and tweaks.AuraCasters and tweaks:AuraCasters()
	if not list then
		if C_Secrets.ShouldAurasBeSecret() then T:Print("can't tell who cast what during a fight.") end
		return
	end
	local items
	-- The buff under the mouse: its caster's menu at once.
	local hit = ns.Free() and Find()
	if hit and hit.id and hit.unit == "player" then
		for _, entry in ipairs(list) do
			if entry.id == hit.id then items = Person(entry) end
		end
		if not items then
			T:Print((hit.name or "that") .. " is yours, or no one knows who cast it.")
			return
		end
	elseif #list == 0 then
		T:Print("nothing on you came from anyone else.")
		return
	else
		items = { { heading = "Who cast what" } }
		for _, entry in ipairs(list) do
			items[#items + 1] = { text = entry.name, detail = entry.who.name, icon = entry.icon, items = Person(entry) }
		end
	end
	UI.Menu(UIParent, items, { side = "cursor", keepOn = "RightButton", foot = "Left-click away to close" })
end

-- The shield is up while Shift is held and the mouse is on the shelf.
local function OnShelf()
	local unit, at = T:AuraUnderMouse()
	return unit == "player" and at ~= nil and at[2] == (ns.Shelf.End())
end

local function Guard()
	if not shield then return end
	local up = (IsShiftKeyDown() and OnShelf()) and true or false
	if up ~= shield:IsShown() then shield:SetShown(up) end
end

local function Shield()
	local box = ns.Shelf.End()
	if not box or shield then return end
	shield = CreateFrame("Frame", nil, UIParent)
	shield:SetAllPoints(box)
	shield:SetFrameStrata("HIGH")
	shield:EnableMouse(true)
	shield:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			local ok, err = pcall(C.Menu)
			if not ok then Report("the menu", err) end
		end
	end)
	shield:Hide()
	shield:RegisterEvent("MODIFIER_STATE_CHANGED")
	shield:SetScript("OnEvent", function(_, _, key)
		if key == "LSHIFT" or key == "RSHIFT" then Guard() end
	end)
end

-- /shy buffs who: what the looker found, as text for the copy box.
function C.Report()
	local lines = {}
	local function Say(text) lines[#lines + 1] = text end
	local count = 0
	for _ in pairs(K.Plans()) do count = count + 1 end
	Say("Buff tooltips: " .. (ticker and "watching" or "not started") .. ", " .. looks .. " looks, " .. count .. " rows of icons known.")
	Say("The icons' own tooltip: " .. (K.Owning() and "put away (ours shows instead)" or "in place (a fight, or not yet taken)") .. ".")
	if last.refused and last.refused > 0 then Say(last.refused .. " icons refused to give their tooltip up.") end
	if last.kept and last.kept > 0 then Say(last.kept .. " icons could not have their tooltip back for the last fight.") end
	if looks > 0 then
		if not last.free then
			Say("Last look: a fight, or auras secret: the icons show their own tooltip.")
		else
			Say("Last look: " .. (last.hit and ("the mouse on " .. last.hit) or "the mouse on no icon") .. ".")
		end
		if last.seen then Say(("Last icon the mouse was on: %s, %d s ago."):format(last.seen, math.floor(GetTime() - last.seenAt))) end
	end
	if last.error then Say("Last error: " .. last.error) end
	return table.concat(lines, "\n")
end

function C.Start()
	if ticker then return end
	holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(1, 1)
	holder:SetPoint("BOTTOMLEFT")
	holder:RegisterEvent("PLAYER_REGEN_DISABLED")
	holder:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
	holder:SetScript("OnEvent", function(_, event, _, state)
		if event == "ADDON_RESTRICTION_STATE_CHANGED" and state ~= Enum.AddOnRestrictionState.Activating then return end
		local ok, err = pcall(Yield)
		if not ok then Report("before a fight", err) end
	end)
	Shield()
	-- What changes what the mouse may be on while it rests: the units watched and their auras, your coatings.
	local stirs = { "player", "target", "party1", "party2", "party3", "party4" }
	for i = 1, #stirs, 2 do
		local f = CreateFrame("Frame")
		f:RegisterUnitEvent("UNIT_AURA", stirs[i], stirs[i + 1])
		f:SetScript("OnEvent", Stirred)
	end
	local others = CreateFrame("Frame")
	others:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	others:RegisterEvent("PLAYER_TARGET_CHANGED")
	others:RegisterEvent("GROUP_ROSTER_UPDATE")
	others:SetScript("OnEvent", Stirred)
	ticker = C_Timer.NewTicker(LOOK, function()
		local ok, err = pcall(function()
			Look()
			Guard()
		end)
		if not ok then Report("looking", err) end
	end)
end
