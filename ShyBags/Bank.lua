-- The bank at a banker, shown in the ShyBags window while BankFrame is reparented out of sight.
-- BankFrame must stay shown during a visit: GetActiveBankType reads IsShown to make a right-click a deposit.
-- Reparented, it never runs OnShow/OnHide, so the visit is opened and ended (C_Bank.CloseBankFrame) here.
-- Its UIPanel "area" is removed while hidden so it holds no place among the side-by-side panels.
-- Every tab, the first (Bank.Fresh) and each bag slot after it, is bought through
-- BankPanelPurchaseButtonScriptTemplate, which asks with the game's own prompt; never by our code.
--   Bank.OnSlots(fn)   during a visit: a bag slot was bought or a bag put in or taken out, or your gold changed
--                      (what the next slot costs may now be within reach)

local ADDON, ns = ...

local Bank = {}
ns.Bank = Bank

local CHARACTER = Enum.BankType.Character
local SOCKETS = Enum.BagIndex.Characterbanktab   -- the container holding the bank's bag slots

local away = false     -- BankFrame is reparented
local home, area       -- its parent and panel area, to restore
local open = false     -- at a banker
local live = false     -- and our window shows the visit
local opened = false   -- we opened the window for the visit
local listeners = {}
local watchers = {}    -- Bank.OnSlots

-- Only between visits.
local function Apply()
	local should = ns.Takeover.IsOn()
	if should == away or open or BankFrame:IsShown() then return end
	if should then
		home = BankFrame:GetParent()
		area = UIPanelWindows.BankFrame and UIPanelWindows.BankFrame.area
		SetUIPanelAttribute(BankFrame, "area", nil)
		BankFrame:SetParent(ns.Takeover.Attic())
	else
		FrameUtil.SetParentMaintainRenderLayering(BankFrame, home)
		SetUIPanelAttribute(BankFrame, "area", area)
	end
	away = should
end

local function Tell()
	for _, fn in ipairs(listeners) do ns.Guard(fn, live) end
end

function Bank.IsLive() return live end
function Bank.IsAway() return away end
function Bank.OnChange(fn) listeners[#listeners + 1] = fn end
function Bank.OnSlots(fn) watchers[#watchers + 1] = fn end

function Bank.Tabs()
	return C_Bank.FetchPurchasedBankTabIDs(CHARACTER) or {}
end

function Bank.Fresh()
	return live and C_Bank.FetchNumPurchasedBankTabs(CHARACTER) == 0
end

-- The bag slots: { slot, bought, icon, quality, locked } for each, its bag's while one is in it.
function Bank.Sockets()
	local list = {}
	local bought = C_Bank.FetchNumPurchasedBankTabs(CHARACTER)
	-- Tab 1 is the bank itself; bag slots start at 2.
	for slot = 2, C_Bank.FetchMaxNumBankTabs(CHARACTER) do
		local info = slot <= bought and C_Container.GetContainerItemInfo(SOCKETS, slot) or nil
		list[#list + 1] = { slot = slot, bought = slot <= bought, icon = info and info.iconFileID or nil,
			quality = info and info.quality or nil, locked = info and info.isLocked or nil }
	end
	return list
end

function Bank.Take(slot)
	C_Container.PickupContainerItem(SOCKETS, slot)
end

function Bank.Next()
	if not C_Bank.CanPurchaseBankTab(CHARACTER) then return nil end
	local data = C_Bank.FetchNextPurchasableBankTabData(CHARACTER)
	if not data then return nil end
	return data.tabCost, data.canAfford
end

-- The game's template for an addon's purchase button: its click opens the game's own prompt, with the price,
-- for the next tab of the bank its attribute names. Never give it an OnClick of ours.
Bank.PURCHASE = "BankPanelPurchaseButtonScriptTemplate"

function Bank.Arm(button)
	button:SetAttribute("overrideBankType", CHARACTER)
	button:RegisterForClicks("LeftButtonUp")
	return button
end

function Bank.Close()
	if open then C_Bank.CloseBankFrame() end
end

local function Opened()
	open = true
	if not away then return end   -- the default bank window is handling it
	live = true
	if not ns.Takeover.Visible() then
		opened = true
		ns.Takeover.Open()
	end
	Tell()
end

local function Closed()
	open = false
	if live then
		live = false
		Tell()
		if opened then
			opened = false
			ns.Takeover.Close()
		end
	end
	-- Blizzard hides BankFrame shortly after BANKFRAME_CLOSED.
	C_Timer.After(0.5, Apply)
end

function Bank.Init()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BANK_TABS_CHANGED", "PLAYERBANKSLOTS_CHANGED",
		"BAG_CONTAINER_UPDATE", "PLAYER_MONEY" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, kind)
		if event == "BANKFRAME_OPENED" then
			Opened()
		elseif event == "BANKFRAME_CLOSED" then
			Closed()
		elseif live and not (event == "BANK_TABS_CHANGED" and kind ~= CHARACTER) then
			for _, fn in ipairs(watchers) do ns.Guard(fn) end
		end
	end)
	ns.Takeover.OnChange(function(visible)
		if live and not visible then
			opened = false
			Bank.Close()
		end
	end)
	ns.Takeover.OnSwitch(Apply)
	Apply()
end
