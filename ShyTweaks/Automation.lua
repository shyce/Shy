-- Quests, gossip, trainers, vendors and loot.
-- Holding Shift pauses every automation here for that interaction.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local function Money(copper)
	return UI.Money(copper)
end

-- Quests & NPCs (accepting and turning in quests lives in ShyQuest)

ns.Feature({
	id = "skipGossip",
	category = "Quests & NPCs",
	title = "Skip NPC gossip",
	desc = "When an NPC has only one thing to offer, you go straight to it. Hold Shift to stop and read.",
	keywords = "gossip npc dialog dialogue chatter talk flight master vendor banker skip auto",
	default = false,
	events = {
		GOSSIP_SHOW = function()
			if ns.Paused() then return end
			if C_GossipInfo.GetNumActiveQuests() > 0 or C_GossipInfo.GetNumAvailableQuests() > 0 then return end
			local options = C_GossipInfo.GetOptions()
			if #options == 1 then C_GossipInfo.SelectOption(options[1].gossipOptionID) end
		end,
	},
})

-- Train all: everything you can afford, in the one click. The game takes a purchase only from a click.
local trainButton

local function Available()
	local count, cost = 0, 0
	for i = 1, GetNumTrainerServices() do
		local _, kind = GetTrainerServiceInfo(i)
		if kind == "available" then
			count = count + 1
			cost = cost + (GetTrainerServiceCost(i) or 0)
		end
	end
	return count, cost
end

-- From the top, as far as your gold goes; bought from the bottom up, so no skill's place moves under the rest.
local function TrainAll()
	local plan, left = {}, GetMoney()
	for i = 1, GetNumTrainerServices() do
		local _, kind = GetTrainerServiceInfo(i)
		local cost = GetTrainerServiceCost(i) or 0
		if kind == "available" and cost <= left then
			plan[#plan + 1] = i
			left = left - cost
		end
	end
	for n = #plan, 1, -1 do BuyTrainerService(plan[n]) end
end

-- ShySkin's trainer window has its own "Train all": this button hides while it does, and the tweak's row
-- is left out.
local function SkinTrains()
	local skin = Shy.addons.Skin
	return skin ~= nil and skin.owns ~= nil and skin.owns.trainAll == true
end

local function UpdateTrainButton()
	if not trainButton then return end
	local count, cost = Available()
	local on = ns.Get("trainAll"):IsOn() and not SkinTrains()
	trainButton:SetShown(on and count > 0)
	trainButton.text:SetText(("Train all (%d)"):format(count))
	trainButton.cost = cost
end

local function CreateTrainButton()
	if trainButton or not ClassTrainerFrame then return end
	trainButton = UI.Button(ClassTrainerFrame, "Train all", 120, TrainAll)
	trainButton:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -6, 0)
	trainButton:SetFrameLevel(ClassTrainerTrainButton:GetFrameLevel() + 1)
	trainButton:HookScript("OnEnter", function(self)
		UI.Tip(self, "Train all", "Learns everything you can afford.", { side = "TOP",
			sections = { { rows = { { glyph = "coin", text = "Total", right = Money(self.cost or 0) } } } } })
	end)
	trainButton:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	ClassTrainerFrame:HookScript("OnShow", UpdateTrainButton)
end

Shy:On("SHY_SKIN_OWNS", function(piece)
	if piece == "trainAll" then UpdateTrainButton() end
end)

ns.Feature({
	id = "trainAll",
	category = "Quests & NPCs",
	title = "Train all button",
	desc = "Trainers get a button that learns everything you can afford. Point at it for the total.",
	keywords = "trainer train all spells ranks learn skills profession class",
	default = true,
	leftOut = SkinTrains,
	events = {
		ADDON_LOADED = function(_, _, name)
			if name == "Blizzard_TrainerUI" then CreateTrainButton() end
		end,
		TRAINER_UPDATE = UpdateTrainButton,
	},
	Enable = function()
		CreateTrainButton()
		UpdateTrainButton()
	end,
	Disable = function()
		if trainButton then trainButton:Hide() end
	end,
})

-- Loot & vendors

local function JunkValue()
	local total = 0
	for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
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

-- ShyBags (which loads first) owns selling junk and repairing when it is installed.
if not Shy.addons.Bags then
	ns.Feature({
		id = "sellJunk",
		category = "Loot & vendors",
		title = "Sell junk",
		desc = "Your gray items sell when you open a vendor. Hold Shift to keep them this time.",
		keywords = "gray grey junk vendor sell auto automatic money gold trash",
		default = true,
		options = {
			{ key = "report", kind = "checkbox", label = "Say the total", default = true,
				desc = "Chat tells you what the junk sold for." },
		},
		events = {
			MERCHANT_SHOW = function(f)
				if ns.Paused() then return end
				local value = JunkValue()
				if value == 0 then return end
				C_MerchantFrame.SellAllJunkItems()
				if f.opt.report then T:Print("sold junk for " .. Money(value)) end
			end,
		},
	})

	ns.Feature({
		id = "autoRepair",
		category = "Loot & vendors",
		title = "Repair gear",
		desc = "Your gear gets repaired when you open a vendor who can. Hold Shift to skip it.",
		keywords = "repair auto automatic durability armor gear gold guild bank vendor",
		default = true,
		options = {
			{ key = "guild", kind = "checkbox", label = "Use guild funds", default = false,
				desc = "The guild bank pays when your rank allows it. Otherwise you do." },
			{ key = "report", kind = "checkbox", label = "Say the cost", default = true,
				desc = "Chat tells you what the repair cost." },
		},
		events = {
			MERCHANT_SHOW = function(f)
				if ns.Paused() or not CanMerchantRepair() then return end
				local cost, canRepair = GetRepairAllCost()
				if not canRepair or cost == 0 then return end
				if f.opt.guild and IsInGuild() and CanGuildBankRepair() then
					RepairAllItems(true)
					if f.opt.report then T:Print("repaired for " .. Money(cost) .. " |cff888888(guild)|r") end
				elseif GetMoney() >= cost then
					RepairAllItems()
					if f.opt.report then T:Print("repaired for " .. Money(cost)) end
				else
					T:Print("not enough gold to repair (" .. Money(cost) .. ")")
				end
			end,
		},
	})
end

local lastLoot = 0

ns.Feature({
	id = "fasterLoot",
	category = "Loot & vendors",
	title = "Faster auto loot",
	desc = "With auto loot on, you pick up everything at once instead of item by item.",
	keywords = "loot fast faster quick instant auto pick up corpse",
	default = true,
	events = {
		LOOT_READY = function()
			-- LOOT_READY can fire twice for one corpse.
			if GetTime() - lastLoot < 0.3 then return end
			lastLoot = GetTime()
			if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
				for i = GetNumLootItems(), 1, -1 do LootSlot(i) end
			end
		end,
	},
})

ns.Feature({
	id = "lootConfirm",
	category = "Loot & vendors",
	title = "Skip loot confirmations",
	desc = "You won't be asked \"this will bind to you\" when you loot or roll. You still pick what to roll.",
	keywords = "bind pickup bop confirm confirmation popup loot roll need greed",
	default = false,
	events = {
		LOOT_BIND_CONFIRM = function(_, _, slot)
			ConfirmLootSlot(slot)
			StaticPopup_Hide("LOOT_BIND")
		end,
		CONFIRM_LOOT_ROLL = function(_, _, rollID, rollType)
			ConfirmLootRoll(rollID, rollType)
			StaticPopup_Hide("CONFIRM_LOOT_ROLL")
		end,
	},
})

-- The two delete dialogs that ask for the word to be typed (rare items and better).
local TYPED = { "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }

ns.Feature({
	id = "easyDelete",
	category = "Loot & vendors",
	title = "Easy item delete",
	desc = "The word you have to type to delete a rare item is filled in for you.",
	keywords = "delete destroy item rare epic confirm type word popup",
	default = false,
	events = {
		DELETE_ITEM_CONFIRM = function()
			-- The game shows its dialog on the same event.
			C_Timer.After(0, function()
				for _, which in ipairs(TYPED) do
					local dialog = StaticPopup_FindVisible(which)
					if dialog then dialog:GetEditBox():SetText(DELETE_ITEM_CONFIRM_STRING) end
				end
			end)
		end,
	},
})

-- Cinematics and movies: Esc (Space or Enter on a movie) makes the game ask whether to stop;
-- the answer is yes, given on the same key press.
local hooked

local function SkipCinematic()
	if not ns.Get("skipCinematics").running or not CinematicFrame.closeDialog:IsShown() then return end
	if CinematicFrame.isRealCinematic then
		StopCinematic()
	elseif IsInCinematicScene() and CanCancelScene() then
		CancelScene()
	end
end

local function SkipMovie()
	if not ns.Get("skipCinematics").running or InCombatLockdown() then return end
	if MovieFrame.CloseDialog:IsShown() then MovieFrame:FinishMovie() end
end

ns.Feature({
	id = "skipCinematics",
	category = "System",
	title = "Skip cinematics at once",
	desc = "Esc ends a cinematic or movie without asking if you're sure.",
	keywords = "cinematic movie cutscene scene skip escape esc confirm",
	default = false,
	Enable = function()
		if hooked then return end
		hooked = true
		CinematicFrame:HookScript("OnKeyDown", SkipCinematic)
		CinematicFrame:HookScript("OnGamePadButtonDown", SkipCinematic)
		MovieFrame:HookScript("OnKeyUp", SkipMovie)
	end,
})
