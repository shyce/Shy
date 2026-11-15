-- Scans this character's bags, key ring, bank and gold as they change.
-- BAG_UPDATE marks a bag dirty; BAG_UPDATE_DELAYED ends the burst and reads each dirty bag once.

local ADDON, ns = ...
local Store = ns.Store

local Scan = {}
ns.Scan = Scan

local KEYS = Enum.BagIndex.Keyring
local HELD = {}   -- bag -> true: carried bags
for bag = Enum.BagIndex.Backpack, Enum.BagIndex.ReagentBag do HELD[bag] = true end
HELD[KEYS] = true

local dirty = {}   -- bag -> changed since last read
local atBank = false
local tabs = {}    -- bank tab -> true, while at a banker
local bankDue = false

local function Slot(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local id = info and info.itemID
	if not id then return "" end
	local item = info.hyperlink and Store.ItemString(info.hyperlink) or tostring(id)
	local flags = info.isBound and "b" or ""
	-- Same test as ContainerFrameItemButtonMixin:UpdateQuestItem.
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	if quest then
		if quest.questID and not quest.isActive then
			flags = flags .. "s"
		elseif quest.questID or quest.isQuestItem then
			flags = flags .. "q"
		end
	end
	local plain = Store.Note(id, info.quality, info.itemName)
	local name = (plain and info.itemName and info.itemName ~= plain) and info.itemName or nil
	return Store.Pack(item, info.stackCount, flags, name)
end

-- A bag's slots in order, or nil for no bag. The key ring is trimmed to its last key.
function Scan.Read(bag)
	local size = C_Container.GetContainerNumSlots(bag)
	if size == 0 then return nil end
	local slots, last = {}, 0
	for slot = 1, size do
		slots[slot] = Slot(bag, slot)
		if slots[slot] ~= "" then last = slot end
	end
	if bag == KEYS then
		for slot = size, last + 1, -1 do slots[slot] = nil end
		if last == 0 then return nil end
	end
	return slots
end

local function ReadInto(bags, bag)
	bags[bag] = Scan.Read(bag)
end

local function Flush()
	local c = Store.Me()
	if not c then return end
	local bags = c.bags or {}
	c.bags = bags
	local read, bankRead = false, false
	for bag in pairs(dirty) do
		dirty[bag] = nil
		if HELD[bag] then
			if bag ~= KEYS or C_ActionBar.ShouldShowKeyring() then
				ns.Guard(ReadInto, bags, bag)
				read = true
			end
		elseif atBank and tabs[bag] then
			c.bank = c.bank or {}
			ns.Guard(ReadInto, c.bank, bag)
			bankRead = true
		end
	end
	if read then Store.Touch("bags") end
	if bankRead then Store.Touch("bank") end
end

-- The bank can only be read at a banker: every tab on opening, then dirty tabs.
local function Bank()
	bankDue = false
	local c = Store.Me()
	if not c or not atBank then return end
	tabs = {}
	for _, tab in ipairs(C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) or {}) do
		tabs[tab] = true
		dirty[tab] = true
	end
	c.bank = c.bank or {}
	for key in pairs(c.bank) do
		if type(key) == "number" and not tabs[key] then c.bank[key] = nil end
	end
	Flush()
	Store.Touch("bank")
end

local function BankSoon()
	if bankDue then return end
	bankDue = true
	C_Timer.After(0, Bank)
end

local function Money()
	local c = Store.Me()
	if not c then return end
	c.money, c.moneyAt = GetMoney(), ns.Now()
	Store.Touch("money")
end

function Scan.All()
	for bag in pairs(HELD) do dirty[bag] = true end
	Flush()
	Money()
end

function Scan.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("BAG_UPDATE")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("PLAYER_MONEY")
	events:RegisterEvent("BANKFRAME_OPENED")
	events:RegisterEvent("BANKFRAME_CLOSED")
	events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	events:RegisterEvent("BANK_TABS_CHANGED")
	events:SetScript("OnEvent", function(_, event, bag)
		if event == "BAG_UPDATE" then
			dirty[bag] = true
		elseif event == "BAG_UPDATE_DELAYED" then
			Flush()
		elseif event == "PLAYER_MONEY" then
			Money()
		elseif event == "BANKFRAME_CLOSED" then
			atBank = false
		else
			-- Opened, or changed without naming a tab.
			if event == "BANKFRAME_OPENED" then atBank = true end
			if atBank then BankSoon() end
		end
	end)
	Scan.All()
end

ns.Command("list", "saved characters, their gold and bags", function()
	local UI = Shy.UI
	ns.T:Print("saved characters:")
	for _, entry in ipairs(Store.List()) do
		local c = entry.char
		local items, slots = 0, 0
		for key, list in pairs(c.bags or {}) do
			if type(list) == "table" and key ~= KEYS then
				for _, slot in ipairs(list) do
					slots = slots + 1
					if slot ~= "" then items = items + 1 end
				end
			end
		end
		local bags = c.bags and c.bags.at and (items .. " of " .. slots .. " bag slots filled, seen " .. ns.Ago(c.bags.at)) or "bags not scanned yet"
		local money = c.money and UI.Money(c.money) or "gold unknown"
		print("  " .. Store.Name(c) .. ": " .. money .. "; " .. bags)
	end
end)
