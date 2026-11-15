-- Sells junk and repairs when a vendor opens (Shift skips both), through the vendor's own Sell Junk and Repair All.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local Vendor = {}
ns.Vendor = Vendor

T.defaults.sellJunk = true
T.defaults.sellReport = true
T.defaults.repair = true
T.defaults.repairGuild = false
T.defaults.repairReport = true

local function JunkValue()
	local total = 0
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.quality == Enum.ItemQuality.Poor and not info.hasNoValue then
				local price = select(11, C_Item.GetItemInfo(info.itemID)) or 0
				total = total + price * info.stackCount
			end
		end
	end
	return total
end

local function SellJunk()
	local value = JunkValue()
	if value == 0 then return end
	C_MerchantFrame.SellAllJunkItems()
	if T.db.sellReport then T:Print("sold junk for " .. UI.Money(value)) end
	Shy:Fire("SHY_BAGS_SOLD", value)   -- copper
end

local function Repair()
	if not CanMerchantRepair() then return end
	local cost, needed = GetRepairAllCost()
	if not needed or cost == 0 then return end
	if T.db.repairGuild and IsInGuild() and CanGuildBankRepair() then
		RepairAllItems(true)
		if T.db.repairReport then T:Print("repaired for " .. UI.Money(cost) .. " " .. Shy.Theme.Wrap(UI.colors.dim, "(guild)")) end
		Shy:Fire("SHY_BAGS_REPAIRED", cost, true)    -- copper, paid by guild
	elseif GetMoney() >= cost then
		RepairAllItems()
		if T.db.repairReport then T:Print("repaired for " .. UI.Money(cost)) end
		Shy:Fire("SHY_BAGS_REPAIRED", cost, false)
	else
		T:Print("not enough gold to repair (" .. UI.Money(cost) .. ")")
	end
end

-- Once per profile: carry over the ShyTweaks settings these features came from.
local function Adopt()
	if T.db.adoptedVendor then return end
	T.db.adoptedVendor = true
	local old = ShyTweaksDB
	if type(old) ~= "table" or type(old.features) ~= "table" then return end
	local options = type(old.options) == "table" and old.options or {}
	if old.features.sellJunk ~= nil then T.db.sellJunk = old.features.sellJunk and true or false end
	if old.features.autoRepair ~= nil then T.db.repair = old.features.autoRepair and true or false end
	local junk, repair = options.sellJunk or {}, options.autoRepair or {}
	if junk.report ~= nil then T.db.sellReport = junk.report and true or false end
	if repair.report ~= nil then T.db.repairReport = repair.report and true or false end
	if repair.guild ~= nil then T.db.repairGuild = repair.guild and true or false end
end

function Vendor.Init()
	ns.Guard(Adopt)
	local events = CreateFrame("Frame")
	events:RegisterEvent("MERCHANT_SHOW")
	events:SetScript("OnEvent", function()
		if IsShiftKeyDown() then return end
		if T.db.sellJunk then ns.Guard(SellJunk) end
		if T.db.repair then ns.Guard(Repair) end
	end)
end
