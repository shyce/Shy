-- The talents you have taken that change a spell, for its hover's "Modified by" (Wing.lua): each with its
-- picture, its name, the ranks taken and what it does at that rank. Which talent changes which spell is
-- the client's own tables' (Data/Talents.lua); which talents you have is your active tree's (C_Traits).
--   Talents.For(spellID)   -> rows for a card, or nil when none of yours change it

local ADDON, ns = ...
local C = Shy.UI.colors

local Talents = {}
ns.Talents = Talents

local changes = {}           -- spell -> the talents (their definition's spell) that change it, or false; kept as asked
local listed                 -- { talent, ",spells," } for each talent of the data, made on first use
local taken                  -- talent spell -> { rank, ranks, definition }: the tree as it stands, read again on a change

-- Each spell is looked for in the data as it is first asked, so the first spell hovered doesn't take
-- apart every talent's list.
local function Changes(spell)
	local list = changes[spell]
	if list ~= nil then return list or nil end
	if not listed then
		listed = {}
		for talent, about in pairs(ns.talents or {}) do listed[#listed + 1] = { talent, "," .. about[1] .. "," } end
	end
	local want = (",%d,"):format(spell)
	for _, entry in ipairs(listed) do
		if entry[2]:find(want, 1, true) then
			list = list or {}
			list[#list + 1] = entry[1]
		end
	end
	changes[spell] = list or false
	return list
end

-- The talents bought in the active tree. Empty, and asked again next time, while the tree isn't loaded.
local function Taken()
	if taken then return taken end
	local config = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	local info = config and C_Traits.GetConfigInfo(config)
	if not info then return {} end
	taken = {}
	for _, tree in ipairs(info.treeIDs or {}) do
		for _, node in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
			local at = C_Traits.GetNodeInfo(config, node)
			local rank = at and at.ranksPurchased
			if type(rank) == "number" and not issecretvalue(rank) and rank > 0 then
				local entry = (at.activeEntry and at.activeEntry.entryID) or (at.entryIDs and at.entryIDs[1])
				local about = entry and C_Traits.GetEntryInfo(config, entry)
				local definition = about and about.definitionID and C_Traits.GetDefinitionInfo(about.definitionID)
				if definition and definition.spellID then
					taken[definition.spellID] = { rank = rank, ranks = at.maxRanks, definition = definition }
				end
			end
		end
	end
	return taken
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "PLAYER_TALENT_UPDATE" }) do
	events:RegisterEvent(event)
end
events:SetScript("OnEvent", function() taken = nil end)
Shy:On("SHY_SPELLS", function() taken = nil end)

function Talents.For(spell)
	local list = type(spell) == "number" and Changes(spell)
	if not list then return nil end
	local mine, found = Taken(), {}
	for _, talent in ipairs(list) do
		local have = mine[talent]
		if have then
			local definition = have.definition
			-- What it does at the rank taken: that rank's own spell where the data has the ranks.
			local at = ns.talents[talent][1 + have.rank] or talent
			local says = definition.overrideDescription
			if not says or says == "" then says = C_Spell.GetSpellDescription(at) end
			found[#found + 1] = {
				name = definition.overrideName or C_Spell.GetSpellName(talent) or "",
				icon = definition.overrideIcon or C_Spell.GetSpellTexture(talent),
				rank = have.rank, ranks = have.ranks, says = says,
			}
		end
	end
	if #found == 0 then return nil end
	table.sort(found, function(a, b) return a.name < b.name end)
	local rows = {}
	for _, one in ipairs(found) do
		rows[#rows + 1] = { icon = one.icon, text = one.name, right = (one.ranks or 1) > 1 and (one.rank .. "/" .. one.ranks) or nil, rightColor = C.dim }
		if one.says and one.says ~= "" then rows[#rows + 1] = { text = one.says, quiet = true, indent = 1 } end
	end
	return rows
end
