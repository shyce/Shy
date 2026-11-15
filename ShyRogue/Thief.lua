-- Lockboxes: a secure button (Pick Lock on a bag slot) for a lockbox your Lockpicking can open.
-- Pick Pocket: loot totals, this session and all time on this character.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local WIDTH, PAD = 290, 10

-- Lockboxes

local box, button, found
local REQUIRES = "^" .. ITEM_MIN_SKILL
	:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
	:gsub("%%%%s", ".-")
	:gsub("%%%%d", "(%%d+)") .. "$"

local function LockpickingSkill()
	for i = 1, C_SkillInfo.GetNumSkillLines() do
		local info = C_SkillInfo.GetSkillLineInfo(i)
		if info and info.skillID == ns.SKILL_LOCKPICKING then return info.rank + info.modifier end
	end
end

-- Items already seen not to be lockboxes; skips their tooltip scan on later bag updates.
local plainItems = {}

-- Lockboxes in the bags you can open: { bag, slot, itemID, need, skill }.
local function FindLockboxes()
	local list = {}
	if not C_SpellBook.IsSpellKnown(ns.SPELL_PICK_LOCK) then return list end
	local skill = LockpickingSkill()
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and not plainItems[info.itemID] then
				local data = C_TooltipInfo.GetBagItem(bag, slot)
				local locked, need = false, nil
				for _, line in ipairs(data and data.lines or {}) do
					local text = line.leftText
					if text == LOCKED then locked = true end
					local n = text and text:match(REQUIRES)
					if n then need = tonumber(n) end
				end
				if locked and (not skill or not need or skill >= need) then
					list[#list + 1] = { bag = bag, slot = slot, itemID = info.itemID, need = need, skill = skill }
				elseif not locked and not need and not info.hasLoot then
					plainItems[info.itemID] = true
				end
			end
		end
	end
	return list
end

local function UpdateLockboxes()
	if InCombatLockdown() or not box then return end
	found = T.db.lockboxes.shown and FindLockboxes() or {}
	local first = found[1]
	if first then
		button:SetAttribute("target-bag", first.bag)
		button:SetAttribute("target-slot", first.slot)
		button.icon:SetTexture(C_Item.GetItemIconByID(first.itemID))
		button.name:SetText(C_Item.GetItemNameByID(first.itemID) or "Lockbox")
		local detail = first.need and ("needs " .. first.need .. (first.skill and ("  \194\183  you have " .. first.skill) or "")) or ""
		if #found > 1 then detail = detail .. ("  \194\183  %d more"):format(#found - 1) end
		button.detail:SetText(detail)
	end
	Shy.HUD.Update(box)
end

local function SetupLockboxes()
	box = Shy.HUD.Create({
		id = "shyrogue-lockboxes",
		title = "Lockboxes",
		width = WIDTH,
		height = 60,
		point = { "CENTER", "CENTER", 0, 110 },
		shown = function() return found and #found > 0 end,
		secure = true,
	})
	UI.Panel(box, { hud = true })

	button = CreateFrame("Button", nil, box, "SecureActionButtonTemplate")
	button:SetPoint("TOPLEFT", 4, -4)
	button:SetPoint("BOTTOMRIGHT", -4, 4)
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "spell")
	button:SetAttribute("spell", tostring(ns.SPELL_PICK_LOCK))
	local hl = button:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	UI.Paint(hl, C.hot, 0.12)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(34, 34)
	button.icon:SetPoint("LEFT", 6, 0)
	-- The whole row is the button and has its own highlight, so the slot gets none.
	Shy.Slot.New(button, { to = button.icon, icon = button.icon, hover = false })
	button.name = UI.Text(button, "", 14, true)
	button.name:SetPoint("TOPLEFT", button.icon, "TOPRIGHT", 10, -1)
	button.detail = UI.Text(button, "", 11, false, C.dim)
	button.detail:SetPoint("TOPLEFT", button.name, "BOTTOMLEFT", 0, -3)
	local action = UI.Text(button, "Pick lock", 13, true, C.good)
	action:SetPoint("RIGHT", -8, 0)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", UpdateLockboxes)
	table.insert(ns.refreshers, UpdateLockboxes)
	UpdateLockboxes()
end

-- Pick Pocket

local session = { money = 0, items = 0, value = 0 }
local pocketUntil = 0      -- window after a Pick Pocket lands
local moneyUntil = 0       -- PLAYER_MONEY from that loot can arrive after LOOT_CLOSED
local looting = false
local lastMoney

local function Add(money, items, value)
	local all = ShyRogueCharDB
	session.money, session.items, session.value = session.money + money, session.items + items, session.value + value
	all.money, all.items, all.value = all.money + money, all.items + items, all.value + value
end

local function OnLootReady()
	if GetTime() > pocketUntil then return end
	pocketUntil = 0   -- LOOT_READY can fire twice per pocket
	looting = true
	local items, value = 0, 0
	for i = 1, GetNumLootItems() do
		if GetLootSlotType(i) == Enum.LootSlotType.Item then
			local _, _, quantity = GetLootSlotInfo(i)
			local link = GetLootSlotLink(i)
			local price = link and select(11, C_Item.GetItemInfo(link)) or 0
			items = items + (quantity or 1)
			value = value + price * (quantity or 1)
		end
	end
	Add(0, items, value)
	if T.db.pickpocket.report and items > 0 then
		T:Print(("pickpocketed %d item%s worth %s"):format(items, items == 1 and "" or "s", ns.Money(value)))
	end
end

local function OnMoney()
	local now = GetMoney()
	local gained = lastMoney and now - lastMoney or 0
	lastMoney = now
	if gained > 0 and (looting or GetTime() < moneyUntil) then
		Add(gained, 0, 0)
		if T.db.pickpocket.report then T:Print("pickpocketed " .. ns.Money(gained)) end
	end
end

function ns.LootLines()
	local all = ShyRogueCharDB
	return {
		{ "This session", ns.Money(session.money) .. ("  |cff999999+ %d items (%s)|r"):format(session.items, ns.Money(session.value)) },
		{ "All time", ns.Money(all.money) .. ("  |cff999999+ %d items (%s)|r"):format(all.items, ns.Money(all.value)) },
	}
end

function ns.ShowLootTooltip(owner)
	local rows = {}
	for _, line in ipairs(ns.LootLines()) do
		rows[#rows + 1] = { glyph = "coin", text = line[1], right = line[2], color = C.dim }
	end
	UI.Tip(owner, "Pick Pocket", nil, { width = 300, sections = { { rows = rows } } })
end

function ns.PrintLoot()
	for _, line in ipairs(ns.LootLines()) do T:Print(line[1] .. ": " .. line[2]) end
end

function ns.ResetLoot()
	session.money, session.items, session.value = 0, 0, 0
	ShyRogueCharDB.money, ShyRogueCharDB.items, ShyRogueCharDB.value = 0, 0, 0
end

local function SetupPickpocket()
	lastMoney = GetMoney()
	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	for _, event in ipairs({ "LOOT_READY", "LOOT_CLOSED", "PLAYER_MONEY" }) do events:RegisterEvent(event) end
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local spellID = select(3, ...)
			if spellID == ns.SPELL_PICK_POCKET then pocketUntil = GetTime() + 3 end
		elseif event == "LOOT_READY" then
			OnLootReady()
		elseif event == "LOOT_CLOSED" then
			if looting then moneyUntil = GetTime() + 2 end
			looting = false
		elseif event == "PLAYER_MONEY" then
			OnMoney()
		end
	end)
end

function ns.SetupThief()
	SetupLockboxes()
	SetupPickpocket()
end
