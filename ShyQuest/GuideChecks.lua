-- Guide step checks for gear, bags, skills, cooldowns and auras, registered in G.checks.
-- check(element, env = { guide, step, number, latched, bare }) returns "skip", or isTask, done (as Judge in Guide.lua).
--
-- Checks that hide a step:
--
--   .itemStat 16,ITEM_MOD_DAMAGE_PER_SECOND_SHORT,<10.9   only while what is in that slot is worse than this
--   .money <0.05  /  .money >0.50      not while poorer than 5 silver / not once you have 50 silver
--   .skill cooking,<10,1               not while cooking is under 10 (",1" makes it a check; without "<": not once it is 10)
--   .subzoneskip 442  /  ,1            not while in that area / only while in it
--   .cooldown item,6948,>0             not while that is cooling down ("<": not while it is ready)
--   .aura 2828  /  -2828               not while you have that effect / only while you have it
--   .equip 16,5579  /  -16,...         not once that is in that slot / only once it is
--   .showwhiledead                     only while dead
--
-- Tasks:
--
--   .skill herbalism,15 >> text        reach that skill
--   .destroy 6948                      until none is left in your bags
--   .cast 2383 >> text                 cast it (remembered once it happens)
--   .gossipoption 136768 >> text       be offered that line by someone (GuideTalk.lua notices)
--   .aura / .equip with text           have the effect / wear the item
--   .bankdeposit / .bankwithdraw       until none of those is in your bags / in your bank

local ADDON, ns = ...
local G, L, W = ns.Guide, ns.Log, ns.World
local lib = G.lib
local Args, Ids = lib.Args, lib.Ids
local checks = G.checks

local HEARTHSTONE, ASTRAL_RECALL = 6948, 556
local HEARTH_CASTS = { [8690] = true, [556] = true }     -- Hearthstone, Astral Recall: what .hs waits for

-- Equipped gear

local worn = {}      -- slot -> { stats, quality, level } until the gear changes

local function Worn(slot)
	local entry = worn[slot]
	if not entry then
		entry = {}
		local link = GetInventoryItemLink("player", slot)
		if link then
			entry.stats = C_Item.GetItemStats(link)
			entry.quality = GetInventoryItemQuality("player", slot)
			entry.level = C_Item.GetDetailedItemLevelInfo(link)
		end
		worn[slot] = entry
	end
	return entry
end

-- The step stays while the comparison holds, and when the slot is empty or lacks the stat.
checks.itemStat = function(element)
	local list = Args(element)
	local slot, stat = tonumber(list[1]), list[2]
	local op, total = (list[3] or ""):match("^([<>]?)(.*)$")
	if not (slot and stat and total and total ~= "") then return false end
	local entry = Worn(slot)
	local value
	if stat == "QUALITY" then
		value = entry.quality
	elseif stat == "LEVEL" then
		value = entry.level
	else
		value = entry.stats and entry.stats[stat]
	end
	if type(value) ~= "number" then return false end
	value = math.floor(value * 10 + 0.5) / 10
	local wanted = tonumber(total) or 0
	local holds = (op == ">" and wanted < value) or (op == "<" and wanted > value) or (op == "" and wanted == value)
	if not holds then return "skip" end
	return false
end

-- A task when it has text, else a check. A negative slot inverts it.
checks.equip = function(element)
	local list = Args(element)
	local slot, item = tonumber(list[1]), tonumber(list[2])
	if not slot then return false end
	local reverse = slot < 0
	local wearing = GetInventoryItemID("player", math.abs(slot))
	local met = (wearing ~= nil and (item == nil or item == wearing)) ~= reverse
	if element.text then return true, met end
	if met then return "skip" end
	return false
end

-- Bags and gold

checks.money = function(element)
	local op, amount = element.args:match("^%s*([<>])%s*([%d.]+)")
	amount = tonumber(amount)
	if not amount then return false end
	local rich = GetMoney() >= amount * 10000
	-- "<" skips below the amount, ">" skips at or above it.
	if rich == (op == ">") then return "skip" end
	return false
end

checks.destroy = function(element)
	local id = Ids(element)[1]
	if not id then return false end
	return true, C_Item.GetItemCount(id) == 0
end

-- Dying on purpose (a `die` line) is never asked of the character: the line counts as done.
checks.deathskip = function()
	return true, true
end

checks.bankdeposit = function(element)
	for _, id in ipairs(Ids(element)) do
		if C_Item.GetItemCount(id) > 0 then return true, false end
	end
	return true, true
end

-- Bank counts are the client's cache from the last time the bank was open.
checks.bankwithdraw = function(element)
	if not element.text then return false end
	for _, id in ipairs(Ids(element)) do
		if C_Item.GetItemCount(id, true) > C_Item.GetItemCount(id) then return true, false end
	end
	return true, true
end

-- Skills and casts

checks.skill = function(element)
	local list = Args(element)
	local name = list[1]
	local below, wanted = (list[2] or ""):gsub("%s", ""):match("(<?)(%d+)")
	wanted = tonumber(wanted)
	if not (name and wanted) then return false end
	local level = lib.SkillLevel(name)
	local met = (level >= wanted) ~= (below == "<")
	if tonumber(list[3]) then
		if met then return "skip" end
		return false
	end
	return true, met
end

checks.cast = function(element, env)
	if not element.text then return false end
	return true, env.latched[env.number] == true
end

-- Latched by GuideTalk.lua when the gossip option is offered.
checks.gossipoption = function(element, env)
	if not element.text then return false end
	return true, env.latched[env.number] == true
end

-- Place and state

checks.subzoneskip = function(element)
	local list = Args(element)
	local flags = tonumber(list[2]) or 0
	if lib.InArea(tonumber(list[1]), flags % 4 >= 2) == (flags % 2 == 0) then return "skip" end
	return false
end

checks.showwhiledead = function()
	if not UnitIsDeadOrGhost("player") then return "skip" end
	return false
end

-- GetTime() at which a cooldown ends; 0 when not running, nil when unreadable.
local function Ends(kind, id)
	local start, duration
	if kind == "spell" then
		local info = C_Spell.GetSpellCooldown(id)
		if info then start, duration = info.startTime, info.duration end
	elseif kind == "item" then
		start, duration = C_Container.GetItemCooldown(id)
	end
	-- Can be secret in combat.
	if start == nil or duration == nil or issecretvalue(start) or issecretvalue(duration) then return nil end
	return start + duration
end

checks.cooldown = function(element)
	local list = Args(element)
	local kind, id = list[1], tonumber(list[2])
	local op, amount, unit = (list[3] or ""):match("([<>]?)%s*(%d+%.?%d*)%s*([ms]?)")
	amount = tonumber(amount)
	if not (kind and id and amount) then return false end
	local ends = Ends(kind, id)
	if not ends then return false end
	-- Astral Recall counts as the hearthstone.
	if kind == "item" and id == HEARTHSTONE and C_SpellBook.IsSpellKnown(ASTRAL_RECALL) then
		local recall = Ends("spell", ASTRAL_RECALL)
		if recall then ends = math.min(ends, recall) end
	end
	local left = math.max(amount * (unit == "m" and 60 or 1), 2)
	local now = GetTime()
	-- ">" skips while more than that is left, "<" once less is.
	if op == "<" then
		if now > ends - left then return "skip" end
	elseif now < ends - left then
		return "skip"
	end
	return false
end

checks.aura = function(element)
	local list = Args(element)
	local id = tonumber(list[1])
	if not id or C_Secrets.ShouldAurasBeSecret() then return false end
	local below, amount, stacks = (list[2] or ""):match("(<?)%s*(%d+)([%-%+]?)")
	local reverse = below == "<" or stacks == "-"
	if id < 0 then id, reverse = -id, not reverse end
	amount = tonumber(amount) or 0
	local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
	local found = false
	if aura then
		if stacks == "+" or stacks == "-" then
			found = (aura.applications or 0) >= amount
		else
			found = aura.duration == 0 or aura.expirationTime - GetTime() > amount
		end
	end
	local met = found ~= reverse
	if element.text then return true, met end
	if met then return "skip" end
	return false
end

-- Events

local watching = false       -- a live step uses .cooldown or .aura

local function Uses(entry, wanted)
	for _, part in ipairs(entry.parts) do
		if wanted[part.element.command] then return true end
	end
	return false
end

local TIMED = { cooldown = true, aura = true }

Shy:On("SHY_LOGIN", function()
	G.OnLive(function()
		watching = false
		for _, entry in ipairs(G.active) do
			if Uses(entry, TIMED) then watching = true end
		end
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BANKFRAME_OPENED",
		"BANKFRAME_CLOSED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do
		events:RegisterEvent(event)
	end
	events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:SetScript("OnEvent", function(_, event, _, _, spell)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if spell == nil or issecretvalue(spell) then return end
			if HEARTH_CASTS[spell] then G.Happened("hs") end
			G.Latch(function(element)
				if element.command ~= "cast" then return false end
				for _, id in ipairs(Ids(element)) do
					if id == spell then return true end
				end
				return false
			end)
			return
		elseif event == "PLAYER_EQUIPMENT_CHANGED" then
			wipe(worn)
		elseif event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" or event == "UNIT_AURA" then
			-- Frequent in combat: only refresh while a live step needs them.
			if not watching then return end
		end
		ns.Refresh()
	end)
	-- No event fires when a cooldown ends, so poll.
	C_Timer.NewTicker(5, function()
		if watching then ns.Refresh() end
	end)
end)

ns.GuideChecks = { Ends = Ends }
