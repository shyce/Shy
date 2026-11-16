-- ShyGear: compares an item with what is equipped and marks upgrades, weighed for your talent build.
-- API (Shy.addons.Gear): :Judge(link) verdict or nil, :Words(verdict) "+4% damage, +2% survival",
-- :Parts(verdict) and :Trade(link, wornLinks) what each stat changed is worth to you (Model.lua),
-- :Counted(key) whether a GetItemStats key is weighed at all, :Weighs(link, wornLink) false when your
-- build would never put the item in that worn item's place (a tank's shield),
-- :StatName(key) a GetItemStats key as the game words it ("Nature Resistance"),
-- :TakeReward() reward index or nil, :PickReward(choices) the pick among { { link =, count = }, ... } (Rewards.lua),
-- :MarkFor(verdict) mark kind or nil, :Mark(host) mark with :Set(kind). Bus: SHY_GEAR when verdicts may
-- have changed (ask again then: a verdict is nil while the game is still loading what it needs).

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyGear\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Gear",
	category = "items",
	icon = MEDIA .. "ShyGear",
	smallIcon = MEDIA .. "ShyGearSmall",
	savedVariables = "ShyGearDB",
	defaults = {
		lean = "balanced",   -- damage | balanced | tough
		tooltip = true,
		worse = false,       -- tooltip line on items that are no upgrade
		bags = true,
		reward = "select",   -- off | mark | select
		take = false,        -- let ShyQuest take a clear pick at turn-in
	},
})
ns.T = T
ns.MEDIA = MEDIA

-- Hand-written: the client has no table of what a class gears for. First entry is the default.
ns.FOCUS = {
	WARRIOR = { "melee", "tank" },
	ROGUE = { "melee" },
	HUNTER = { "ranged" },
	PALADIN = { "melee", "tank", "healer" },
	SHAMAN = { "melee", "caster", "healer" },
	DRUID = { "melee", "tank", "caster", "healer" },
	MAGE = { "caster" },
	WARLOCK = { "caster" },
	PRIEST = { "caster", "healer" },
}
local ANY_CLASS = { "melee", "caster" }

ns.FOCUS_NAME = {
	melee = "Melee damage",
	ranged = "Ranged damage",
	tank = "Tanking",
	caster = "Spell damage",
	healer = "Healing",
}

local class   -- UnitClass can be secret; keep the last readable one
function ns.Class()
	local _, token = UnitClass("player")
	if not issecretvalue(token) then class = token end
	return class
end

function ns.Focuses()
	return ns.FOCUS[ns.Class()] or ANY_CLASS
end

-- The talent build ShyQuest follows (the setup's pick), if it is loaded: { id, name, role, goal }.
function ns.Build()
	local quest = Shy.addons.Quest
	if not (quest and quest.Build) then return nil end
	local ok, build = pcall(quest.Build, quest)
	return ok and type(build) == "table" and build or nil
end

-- What gear is weighed for: a role picked in the options, else "build" (the talent build, when its
-- weights are known), else the build's role, else the class's first role.
function ns.Focus()
	local list = ns.Focuses()
	local picked = ShyGearCharDB and ShyGearCharDB.focus
	for _, focus in ipairs(list) do
		if focus == picked then return focus end
	end
	local build = ns.Build()
	if build then
		local known = ns.BUILDS and ns.BUILDS[ns.Class()]
		if known and known[build.id] then return "build" end
		for _, focus in ipairs(list) do
			if focus == build.role then return focus end
		end
	end
	return list[1]
end

function ns.Money(copper)
	return Shy.UI.Money(copper)
end

-- Functions run when verdicts may have changed, at most once a frame. Other addons hear SHY_GEAR.
ns.refreshers = {}
ns.awaited = {}     -- item ID -> true: an item a verdict waits on, not yet loaded (Items.lua)
local pending
local RETRY = 1     -- seconds before asking again for verdicts that waited on the game
local retrying

local function RunRefreshers()
	pending = false
	for _, fn in ipairs(ns.refreshers) do fn() end
	Shy:Fire("SHY_GEAR")
end

-- Verdicts that couldn't be given may be ready now: everything showing one asks again.
function ns.Tell()
	if not pending then
		pending = true
		C_Timer.After(0, RunRefreshers)
	end
end

-- What a verdict goes by has changed.
function ns.Refresh()
	if ns.Stale then ns.Stale() end
	ns.Tell()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- A verdict waited on the game (an item's tooltip, the gear worn, stats kept back): ask again soon.
function ns.Later()
	if retrying then return end
	retrying = true
	C_Timer.After(RETRY, function()
		retrying = false
		ns.Tell()
	end)
end

function T:Judge(link) return ns.Judge(link) end
function T:Words(verdict) return ns.Words(verdict) end
function T:Parts(verdict) return ns.Parts(verdict) end
function T:Trade(link, worn) return ns.Trade(link, worn) end
function T:Counted(key) return ns.Counted(key) end
function T:Weighs(link, wornLink) return ns.Weighs(link, wornLink) end
function T:StatName(key) return ns.StatName(key) end
function T:TakeReward() return ns.TakeReward() end
function T:PickReward(choices) return ns.PickReward(choices) end
function T:MarkFor(verdict) return ns.MarkFor(verdict) end
function T:Mark(host, anchor, size) return ns.CreateMark(host, anchor, size) end

function T:OnLoad()
	ShyGearCharDB = ShyGearCharDB or {}
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	events:RegisterEvent("PLAYER_LEVEL_UP")
	events:RegisterEvent("SKILL_LINES_CHANGED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterUnitEvent("UNIT_STATS", "player")   -- stats update a moment after the gear does
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	-- Talents change what a stat is worth (Model.lua reads them from the tree).
	local TALENTS = { SPELLS_CHANGED = true, TRAIT_CONFIG_UPDATED = true, PLAYER_TALENT_UPDATE = true, ACTIVE_COMBAT_CONFIG_CHANGED = true }
	for event in pairs(TALENTS) do events:RegisterEvent(event) end
	events:SetScript("OnEvent", function(_, event, id)
		-- Item data arrives all the while (loot, chat links, tooltips): only an item a verdict waits on is news.
		if event == "GET_ITEM_INFO_RECEIVED" then
			if id and ns.awaited[id] then
				ns.awaited[id] = nil
				ns.Tell()
			end
			return
		end
		if TALENTS[event] then
			if ns.ForgetTalents then ns.ForgetTalents() end
			return ns.Refresh()
		end
		-- A new level or weapon skill changes which items are usable.
		if event ~= "PLAYER_EQUIPMENT_CHANGED" and event ~= "UNIT_STATS" then ns.Forget() end
		ns.Refresh()
	end)
	Shy:On("SHY_BUILD", ns.Refresh)   -- ShyQuest's talent build changed
	ns.SetupTooltip()
	ns.SetupRewards()
	ns.SetupBags()
end

SLASH_SHYGEAR1 = "/shygear"
SLASH_SHYGEAR2 = "/sgear"
SlashCmdList.SHYGEAR = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "report" then
		Shy.UI.ShowCopyBox("ShyGear: how your gear is weighed", ns.Report())
	else
		T:Print("commands:")
		print("  /shygear  - open options")
		print("  /shygear report  - copy how your gear is weighed")
	end
end
