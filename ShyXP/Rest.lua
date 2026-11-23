-- Rested XP as Forever counts it (Data/Rest.lua). The Legacy talent Well Rested builds it faster and
-- holds more of it, rank by rank. The camp adds two things: a camp tent raises it once an hour, and a
-- sleeping bag gives an XP bonus that stacks. Auras are read only out of a fight (they are secret in
-- one): in a fight the last reading stands.

local ADDON, ns = ...

local Rest = {}
ns.Rest = Rest

local BASE = { rate = 0.05 / 8, cap = 1.5 }   -- a level's share an hour while resting; levels held at most

local ranks                  -- Well Rested's ranks bought, or nil to read again
local camp = { bag = 0, tent = false, sitting = false }   -- bag stacks, a tent nearby, by a fire; had: when the tent's rest is back

local function Data()
	return ns.data and ns.data.rest
end

-- Well Rested's ranks on this account: 0 while the tree can't be read (asked again next time).
function Rest.Ranks()
	if ranks then return ranks end
	local talent = Data() and Data().talent
	if not talent then return 0 end
	local config = C_Traits.GetConfigIDByTreeID(talent.tree)
	local info = config and C_Traits.GetNodeInfo(config, talent.node)
	-- A rank count other than the data's: the tree has changed, so count none.
	if not info or issecretvalue(info.ranksPurchased) or info.maxRanks ~= #talent.rate then return 0 end
	ranks = info.ranksPurchased
	return ranks
end

-- How rested XP builds: a level's share an hour while resting, the levels it holds at most, and Well
-- Rested's rank, percent faster and percent more.
function Rest.Rules()
	local talent = Data() and Data().talent
	local rank = Rest.Ranks()
	if rank <= 0 then return BASE.rate, BASE.cap, 0, 0, 0 end
	local faster, more = talent.rate[rank], talent.cap[rank]
	return BASE.rate * (1 + faster / 100), BASE.cap * (1 + more / 100), rank, faster, more
end

-- Well Rested's name as the game gives it, or nil while the spell isn't loaded.
function Rest.TalentName()
	local talent = Data() and Data().talent
	return talent and C_Spell.GetSpellName(talent.spell)
end

-- The sleeping bag's bonus: XP percent, stacks, stacks at most. 0 without it.
function Rest.Bag()
	local data = Data()
	if not data or camp.bag <= 0 then return 0, 0, data and data.bagMost or 0 end
	return camp.bag * data.bagEach, camp.bag, data.bagMost
end

-- The camp tent: seconds until its rest can be had again (nil when it can be), whether one is nearby,
-- and the share of a level it raises rested XP to.
function Rest.Tent()
	local data = Data()
	if not data then return nil, false, 0 end
	local left = camp.had and camp.had - GetTime()
	return left and left > 0 and left or nil, camp.tent, data.tentShare / 100
end

-- Resting anywhere: an inn or a city, by a welcoming fire, or near a tent.
function Rest.Resting()
	return IsResting() or camp.sitting or camp.tent
end

local function Aura(spell)
	local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
	if aura == nil or issecretvalue(aura) then return nil end
	return aura
end

local function Plain(value)
	if value == nil or issecretvalue(value) then return nil end
	return value
end

local function ReadCamp()
	local data = Data()
	if not data or InCombatLockdown() then return end
	local bag, tent, had, sitting = Aura(data.bag), Aura(data.tent), Aura(data.had), Aura(data.sitting)
	-- A single stack reads as 0.
	local stacks = bag and math.max(1, Plain(bag.applications) or 1) or 0
	local back = had and Plain(had.expirationTime)
	back = back and back > 0 and back or nil
	local changed = stacks ~= camp.bag or (tent ~= nil) ~= camp.tent or (sitting ~= nil) ~= camp.sitting or back ~= camp.had
	camp.bag, camp.tent, camp.sitting, camp.had = stacks, tent ~= nil, sitting ~= nil, back
	if changed then ns.Soon() end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
	if event == "UNIT_AURA" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
		ReadCamp()
	else
		-- Trait events come in bursts: read the ranks again when next asked.
		ranks = nil
		ns.Soon()
	end
end)

-- After login: the bars and the card are there to tell.
function Rest.Start()
	events:RegisterUnitEvent("UNIT_AURA", "player")
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "TRAIT_CONFIG_LIST_UPDATED",
		"TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED" }) do
		events:RegisterEvent(event)
	end
	ReadCamp()
end
