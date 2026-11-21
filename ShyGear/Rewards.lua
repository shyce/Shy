-- Quest reward choices: marks the best upgrade and the best vendor price, and selects one at turn-in.
-- A pick is "clear" when every choice is fully read gear and one upgrade leads or none exists;
-- only a clear pick is taken unasked (ns.TakeReward). Nothing is written on Blizzard's frames.

local ADDON, ns = ...
local T = ns.T

local MARGIN = 1   -- weighted percent the best upgrade must lead by to be a clear pick

local marks = setmetatable({}, { __mode = "k" })   -- reward button -> arrow mark
local coins = setmetatable({}, { __mode = "k" })   -- reward button -> coin mark
local waiting   -- a shown reward isn't loaded yet

-- choices: { { link =, count = }, ... }. Returns nil while an item isn't loaded, else
-- { index (nil: no pick), kind = "upgrade" | "later" | "sell", clear, sells (index), worth (copper), verdicts }.
function ns.PickReward(choices)
	local verdicts = {}
	local best, second, sells, worth
	local plain = true
	for i, choice in ipairs(choices) do
		local item = ns.Read(choice.link)
		if not item then return end
		local v = item.slots and ns.Judge(choice.link) or nil
		verdicts[i] = v or false
		if not v then
			plain = false   -- not gear, or no verdict
		else
			-- An unscored effect or a later-level upgrade is left to the player.
			if v.extra or v.kind == "later" then plain = false end
			if ns.MarkFor(v) then
				if not best or v.keep > verdicts[best].keep then
					best, second = i, best
				elseif not second or v.keep > verdicts[second].keep then
					second = i
				end
			end
		end
		local value = item.sell * (choice.count or 1)
		if value > (worth or 0) then sells, worth = i, value end
	end
	if best then
		local lead = not second or verdicts[best].keep >= verdicts[second].keep + MARGIN
		return { index = best, kind = ns.MarkFor(verdicts[best]), clear = plain and lead, sells = sells, worth = worth, verdicts = verdicts }
	end
	if plain and sells then
		return { index = sells, kind = "sell", clear = true, sells = sells, worth = worth, verdicts = verdicts }
	end
	return { sells = sells, worth = worth, verdicts = verdicts }
end

local function Offered()
	local list = {}
	for i = 1, GetNumQuestChoices() do
		local _, _, count = GetQuestItemInfo("choice", i)
		list[i] = { link = GetQuestItemLink("choice", i), count = count }
	end
	return list
end

local function Logged(questID)
	local list = {}
	for i = 1, GetNumQuestLogChoices(questID, true) do
		local _, _, count = GetQuestLogChoiceInfo(i, questID)
		list[i] = { link = GetQuestLogItemLink("choice", i, questID), count = count }
	end
	return list
end

local function Show()
	local info = QuestInfoFrame
	local rewards = info.rewardsFrame
	if not rewards or not rewards.RewardButtons then return end
	local mode = T.db.reward
	local pick
	waiting = false
	-- The map's quest details render through the quest giver's reward frame first; skip that pass.
	local passing = info.questLog and rewards == QuestInfoRewardsFrame and QuestFrame:IsShown()
	if mode ~= "off" and not passing and rewards:IsVisible() then
		local choices = info.questLog and Logged(C_QuestLog.GetSelectedQuest()) or Offered()
		if #choices > 1 then
			pick = ns.PickReward(choices)
			waiting = pick == nil
		end
	end
	for _, button in ipairs(rewards.RewardButtons) do
		local id = pick and button:IsShown() and button.type == "choice" and button.objectType == "item" and button:GetID()
		local chosen = id and id == pick.index
		local kind = chosen and pick.kind ~= "sell" and pick.kind or nil
		local mark = marks[button]
		if kind and not mark then
			mark = ns.CreateMark(button, button.Icon)
			marks[button] = mark
		end
		if mark then mark:Set(kind) end
		local sells = id and id == pick.sells and "sell" or nil
		local coin = coins[button]
		if sells and not coin then
			coin = ns.CreateMark(button, button.Icon, nil, true)
			coins[button] = coin
		end
		if coin then coin:Set(sells) end
		-- At turn-in with nothing chosen: select it through Blizzard's own click handler.
		if chosen and mode == "select" and not info.questLog and info.chooseItems and info.itemChoice == 0 then
			QuestInfoItem_OnClick(button)
		end
	end
end

-- At turn-in: the choice index to take unasked, or nil.
function ns.TakeReward()
	if not T.db.take then return end
	local choices = Offered()
	if #choices < 2 then return end
	local pick = ns.PickReward(choices)
	if not pick or not pick.clear then return end
	local item = ns.Read(choices[pick.index].link)
	if pick.kind == "sell" then
		T:Print(("took %s to sell (%s). Nothing was an upgrade."):format(item.link, ns.Money(pick.worth)))
	else
		T:Print(("took %s: %s."):format(item.link, ns.Words(pick.verdicts[pick.index])))
	end
	return pick.index
end

function ns.SetupRewards()
	hooksecurefunc("QuestInfo_Display", Show)
	-- The quest frame also calls this global directly on QUEST_ITEM_UPDATE, which clears the choice.
	-- QuestInfo_Display holds the function itself, not the global, so Show doesn't run twice.
	hooksecurefunc("QuestInfo_ShowRewards", Show)
	ns.refreshers[#ns.refreshers + 1] = Show
	local events = CreateFrame("Frame")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:SetScript("OnEvent", function()
		if waiting then Show() end
	end)
end
