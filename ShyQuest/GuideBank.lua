-- Bank steps done for you. A live step's `deposit` lines name what to put away and its `withdraw` lines
-- what to take out (GuideChecks.lua judges them: .bankdeposit, .bankwithdraw); when the bank opens, those
-- items are moved, as GuideTalk.lua accepts the guide's quests. Shift held as it opens leaves it all to
-- the player. Nothing else in the bags or the bank is touched, and nothing is bought.

local ADDON, ns = ...
local T = ns.T
local G = ns.Guide
local Ids = G.lib.Ids

local CHARACTER = Enum.BankType.Character

-- The items a live step says to deposit or withdraw: { [item] = true }, and how many lines said so.
local function Wanted(command)
	local out, count = {}, 0
	for _, entry in ipairs(G.active or {}) do
		for _, part in ipairs(entry.parts or {}) do
			local element = part.element
			if element.command == command and (part.can or part.soft) and not part.done then
				for _, id in ipairs(Ids(element)) do
					out[id], count = true, count + 1
				end
			end
		end
	end
	return out, count
end

-- Moves every stack of the wanted items out of the containers: into the bank (deposit) or into the bags.
local function Move(containers, wanted, deposit)
	local moved = 0
	for _, bag in ipairs(containers) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and not issecretvalue(id) and wanted[id] then
				C_Container.UseContainerItem(bag, slot, nil, deposit and CHARACTER or nil)
				moved = moved + 1
			end
		end
	end
	return moved
end

local function AtBank()
	if not (ns.char and T.db.guide.follow) or IsShiftKeyDown() then return end
	local deposit, depositing = Wanted("bankdeposit")
	local withdraw, withdrawing = Wanted("bankwithdraw")
	if depositing == 0 and withdrawing == 0 then return end
	local bags = {}
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do bags[#bags + 1] = bag end
	local put = depositing > 0 and Move(bags, deposit, true) or 0
	local took = withdrawing > 0 and Move(C_Bank.FetchPurchasedBankTabIDs(CHARACTER) or {}, withdraw, false) or 0
	if put + took == 0 then return end
	local said = {}
	if put > 0 then said[#said + 1] = ("put %d in the bank"):format(put) end
	if took > 0 then said[#said + 1] = ("took %d out"):format(took) end
	T:Print(("For the guide: %s."):format(table.concat(said, ", ")))
	-- (The bank's counts settle a moment later: the lines are judged again then.)
	C_Timer.After(0.5, function() ns.Refresh() end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("BANKFRAME_OPENED")
events:SetScript("OnEvent", AtBank)
