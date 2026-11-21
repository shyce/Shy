-- /shy bags check: in-game compatibility checks. Results go to chat and to ShyBagsStore.checks.
--   ns.Check.Add({ id, title, ready = function() return true (or false, "what to do first") end,
--       run = function() return ok, note end })      ok nil: no result yet
--   ns.Check.Say(id, ok, note)                       for checks that record as you play
-- C1 hidden default bags run no OnShow; C2 slots are not protected; C3 using an item in combat; C4 layout in combat;
-- C5 pick up, sell, split; C6 bank away from a banker; C7 invoices on unread mail; C8 owned auctions; C9 names;
-- C10 withdraw and deposit; C11 hidden BankFrame reports its bank type; C12 buying a bank slot;
-- C13 send window readable in SendMail (Mail.lua); R1 free-slot count and sell prices (Room.lua)

local ADDON, ns = ...
local T = ns.T
local Store = ns.Store

local Check = { list = {} }
ns.Check = Check

function Check.Add(def)
	Check.list[#Check.list + 1] = def
end

function Check.Say(id, ok, note)
	Store.Verdict(id, ok, note)
end

local Wrap, C = Shy.Theme.Wrap, Shy.UI.colors

local function Word(ok)
	if ok == nil then return Wrap(C.dim, "nothing yet") end
	return ok and Wrap(C.good, "yes") or Wrap(C.bad, "no")
end

local function Text(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		out[i] = issecretvalue(v) and "(kept back)" or tostring(v)
	end
	return table.concat(out, ", ")
end

function Check.Run()
	T:Print("checks:")
	for _, def in ipairs(Check.list) do
		local ready, first = true, nil
		if def.ready then ready, first = def.ready() end
		if ready then
			local ran, ok, note = pcall(def.run)
			if not ran then ok, note = false, "error: " .. tostring(ok) end
			if ok ~= nil then Store.Verdict(def.id, ok, note) end
			print("  " .. def.id .. " " .. def.title .. ": " .. Word(ok) .. (note and (" - " .. note) or ""))
		else
			local kept = Store.Checks()[def.id]
			local was = kept and (" (last: " .. Word(kept.ok) .. ")") or ""
			print("  " .. def.id .. " " .. def.title .. ": " .. Wrap(C.dim, first or "not now") .. was)
		end
	end
end

T:Command("check", nil, Check.Run)

local function Kept(id, waiting)
	return function()
		local kept = Store.Checks()[id]
		if not kept then return nil, waiting end
		return kept.ok, kept.note
	end
end

Check.Add({
	id = "build",
	title = "Client",
	run = function()
		local version, build, _, interface = GetBuildInfo()
		return true, Text(version, build, interface)
	end,
})

Check.Add({
	id = "C9",
	title = "Names",
	run = function()
		local guid = UnitGUID("player")
		local note = "UnitName " .. Text(UnitName("player")) .. " | Unmodified " .. Text(UnitNameUnmodified("player"))
			.. " | FullName " .. Text(UnitFullName("player")) .. " | realm " .. Text(GetRealmName(), GetNormalizedRealmName())
			.. " | guid " .. Text(guid)
		return guid ~= nil and not issecretvalue(guid), note
	end,
})

Check.Add({
	id = "C6",
	title = "Bank away from a banker",
	ready = function()
		if BankFrame:IsShown() then return false, "walk away from the banker first" end
		return true
	end,
	run = function()
		local tabs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character) or {}
		local slots, items = 0, 0
		for _, tab in ipairs(tabs) do
			local size = C_Container.GetContainerNumSlots(tab)
			slots = slots + size
			for slot = 1, size do
				if C_Container.GetContainerItemInfo(tab, slot) then items = items + 1 end
			end
		end
		local note = #tabs .. " tabs, " .. slots .. " slots, " .. items .. " items read"
		-- No tabs is inconclusive: unreadable, or the bank was never opened.
		if #tabs == 0 then return nil, note .. " (tells nothing until this character has used a bank)" end
		return items > 0, note
	end,
})

Check.Add({
	id = "C7",
	title = "Invoices on unopened mail",
	ready = function()
		if not MailFrame:IsShown() then return false, "open a mailbox with auction mail in it" end
		return true
	end,
	run = function()
		local unread, unreadWith, read, readWith = 0, 0, 0, 0
		for index = 1, (GetInboxNumItems()) do
			local wasRead = select(9, GetInboxHeaderInfo(index))
			local invoice = GetInboxInvoiceInfo(index) ~= nil
			if wasRead then
				read = read + 1
				if invoice then readWith = readWith + 1 end
			else
				unread = unread + 1
				if invoice then unreadWith = unreadWith + 1 end
			end
		end
		local note = unread .. " unopened (" .. unreadWith .. " with an invoice), " .. read .. " opened (" .. readWith .. " with one)"
		if unreadWith > 0 then return true, note end
		if readWith > 0 and unread > 0 then return false, note end
		return nil, note .. ": needs an unopened auction mail"
	end,
})

Check.Add({
	id = "C8",
	title = "Your auctions",
	ready = function()
		if not ns.Auctions.IsOpen() then return false, "visit an auction house" end
		return true
	end,
	run = function()
		local me = Store.Me()
		local seen = me and me.auctions and me.auctions.at
		if not seen then return nil, "asked, no answer yet: try again in a moment" end
		return true, #me.auctions .. " auctions read, " .. ns.Ago(seen)
	end,
})

-- Checks recorded as the window is used

local Takeover = ns.Takeover
local woke = 0                       -- times a hidden default bag ran OnShow
local uses = { fight = 0, calm = 0 } -- slot clicks Blizzard's handler completed
local blocked = {}                   -- blocked actions
local did = {}                       -- picked, sold, split
local moved = {}                     -- withdrew, deposited
local selling, moving                -- slot clicked at a vendor, at the bank: { bag, slot, id }
local buying = false                 -- the buy button was clicked

local function Seen(set, names, idle)
	local seen = {}
	for _, what in ipairs(names) do
		if set[what] then seen[#seen + 1] = what end
	end
	return (#seen == #names) and true or nil, #seen > 0 and ("seen: " .. table.concat(seen, ", ")) or idle
end

local function SayUses()
	local note = uses.fight .. " in a fight, " .. uses.calm .. " out of one, " .. #blocked .. " blocked"
	if #blocked > 0 then note = note .. ": " .. table.concat(blocked, "; ") end
	local ok = nil
	if #blocked > 0 then ok = false elseif uses.fight > 0 then ok = true end
	Check.Say("C3", ok, note)
	return ok, note
end

local function SayDid()
	local ok, note = Seen(did, { "picked", "sold", "split" }, "nothing tried yet")
	Check.Say("C5", ok, note)
	return ok, note
end

local function SayMoved()
	local ok, note = Seen(moved, { "withdrew", "deposited" }, "right-click something in the bank, and something in your bags")
	Check.Say("C10", ok, note)
	return ok, note
end

-- Asked once a session it passes: the window lays itself out in a fight, and the check's own rebuild
-- of every slot would only do it again.
local laidOut = false

local function LayOutInAFight()
	if laidOut or not (InCombatLockdown() and Takeover.IsOn() and (Takeover.Visible())) then return end
	local ok, result = pcall(ns.Window.Rebuild)
	laidOut = ok
	Check.Say("C4", ok, ok and (tostring(result) .. " slots laid out in a fight") or tostring(result))
end

function Check.Init()
	local buttons = ns.BankWindow and ns.BankWindow.BuyButtons() or {}
	if #buttons == 0 then return end   -- the windows were not built

	Takeover.OnChange(LayOutInAFight)

	EventRegistry:RegisterCallback("ContainerFrame.OpenBag", function()
		if Takeover.IsOn() then woke = woke + 1 end
	end, Check)

	-- Fired at the end of Blizzard's click handler.
	EventRegistry:RegisterCallback("ContainerFrameItemButton.OnItemClicked", function(_, button)
		if not ns.Window.Owns(button) then return end
		local when = InCombatLockdown() and "fight" or "calm"
		uses[when] = uses[when] + 1
		if CursorHasItem() then did.picked = true end
		local bag, slot = button:GetBagID(), button:GetID()
		local id = C_Container.GetContainerItemID(bag, slot)
		if MerchantFrame:IsShown() then selling = { bag = bag, slot = slot, id = id } end
		if ns.Bank.IsLive() then moving = { bag = bag, slot = slot, id = id, bank = ns.Window.IsBank(button) } end
		C_Timer.After(0.5, function()
			SayUses()
			SayDid()
		end)
	end, Check)

	hooksecurefunc(StackSplitFrame, "OpenStackSplitFrame", function(_, _, owner)
		if ns.Window.Owns(owner) then
			did.split = true
			SayDid()
		end
	end)

	for _, button in ipairs(buttons) do button:HookScript("OnClick", function() buying = true end) end
	SayUses()

	ns.Bank.OnChange(function(live)
		if not live then return end
		C_Timer.After(0.5, function()
			local shown, seen, kind = BankFrame:IsShown(), BankFrame:IsVisible(), BankFrame:GetActiveBankType()
			Check.Say("C11", shown and not seen and kind == Enum.BankType.Character,
				"shown " .. tostring(shown) .. ", seen " .. tostring(seen) .. ", bank type " .. tostring(kind))
		end)
	end)

	local events = CreateFrame("Frame")
	events:RegisterEvent("ADDON_ACTION_BLOCKED")
	events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:RegisterEvent("BANK_TABS_CHANGED")
	events:SetScript("OnEvent", function(_, event, addon, what)
		if event == "PLAYER_REGEN_DISABLED" then
			LayOutInAFight()
		elseif event == "BANK_TABS_CHANGED" then
			if buying then
				buying = false
				Check.Say("C12", true, "a bag slot was bought from the window's button")
			end
		elseif event == "BAG_UPDATE_DELAYED" then
			if selling then
				if selling.id and C_Container.GetContainerItemID(selling.bag, selling.slot) ~= selling.id then
					did.sold = true
					SayDid()
				end
				selling = nil
			end
			if moving then
				if moving.id and C_Container.GetContainerItemID(moving.bag, moving.slot) ~= moving.id then
					moved[moving.bank and "withdrew" or "deposited"] = true
					SayMoved()
				end
				moving = nil
			end
		elseif addon == ADDON then
			blocked[#blocked + 1] = tostring(what)
			SayUses()
		end
	end)
end

local function Ours()
	if not Takeover.IsOn() then return false, "the bag window is off: /shy bags blizzard turns it on" end
	return true
end

local function Open()
	local ours, first = Ours()
	if not ours then return false, first end
	if not Takeover.Visible() then return false, "open your bags first" end
	return true
end

local function AtOurBank()
	local ours, first = Ours()
	if not ours then return false, first end
	if not ns.Bank.IsLive() then return false, "visit a banker" end
	if ns.Bank.Fresh() then return false, "this character's bank was never opened: open it from the window first" end
	return true
end

Check.Add({
	id = "C1",
	title = "Default bags hidden",
	ready = Open,
	run = function()
		local shown, seen = false, false
		if ContainerFrameCombinedBags:IsShown() then shown, seen = true, ContainerFrameCombinedBags:IsVisible() end
		for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do
			if frame:IsShown() then
				shown = true
				seen = seen or frame:IsVisible()
			end
		end
		return shown and not seen and woke == 0,
			"shown " .. tostring(shown) .. ", seen " .. tostring(seen) .. ", woke " .. woke .. " times"
	end,
})

Check.Add({
	id = "C2",
	title = "A slot is not protected",
	ready = Open,
	run = function()
		local tile, grid = ns.Window.AnyTile()
		if not tile then return nil, "no slot to ask" end
		local slot, holder = tile:IsProtected(), grid:IsProtected()
		return not slot and not holder, "slot " .. tostring(slot) .. ", grid " .. tostring(holder)
	end,
})

Check.Add({ id = "C3", title = "Using an item in a fight", ready = Ours, run = SayUses })
Check.Add({ id = "C4", title = "Laying slots out in a fight", ready = Ours, run = Kept("C4", "have your bags open as a fight starts") })
Check.Add({ id = "C5", title = "Pick up, sell, split", ready = Ours, run = SayDid })
Check.Add({ id = "C10", title = "Withdraw and deposit", ready = AtOurBank, run = SayMoved })
Check.Add({ id = "C11", title = "Default bank hidden", ready = AtOurBank, run = Kept("C11", "a moment after the bank opens") })
Check.Add({ id = "C12", title = "Buying a bank slot", ready = AtOurBank, run = Kept("C12", "buy a slot with the window's button when you want one") })

Check.Add({
	id = "R1",
	title = "Room and worth",
	ready = function()
		if not (ns.Room and ns.Room.Check) then return false, "not loaded yet" end
		return true
	end,
	run = function() return ns.Room.Check() end,
})
