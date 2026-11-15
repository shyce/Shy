-- What an item compares to (Compare.Read): a band for each equipped item it would replace, with the stat
-- changes, and those items themselves, for a card each beside the item's. The item's own lines stay as the
-- game wrote them (Wing.lua). With ShyGear, each change says what it is worth to you ("+3 Agility" and
-- "+1.4% damage", most first); without it, the differences alone.

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors

local Compare = {}
ns.Compare = Compare

local function Link(item)
	if item.guid then return C_Item.GetItemLinkByGUID(item.guid) end
	return item.hyperlink
end

local function Signed(amount)
	if math.abs(amount - math.floor(amount + 0.5)) < 0.05 then return ("%+d"):format(math.floor(amount + 0.5)) end
	return ("%+.1f"):format(amount)
end

-- A stat's name as the game words it. ShyGear knows the keys the game has no word for (resistances);
-- without it such a key is spelled out rather than shown raw.
local function Name(stat)
	local gear = Shy.addons.Gear
	if gear and gear.StatName then return gear:StatName(stat) end
	local name = _G[stat]
	if type(name) ~= "string" then name = stat:gsub("^ITEM_MOD_", ""):gsub("_SHORT$", ""):gsub("_", " "):lower() end
	return (name:gsub("^%l", string.upper))
end

-- An item's stats by name. The game can give one stat under two keys (a resistance as
-- ITEM_MOD_NATURE_RESISTANCE_SHORT and as RESISTANCE3_NAME): under one name it counts once, the larger.
local function Stats(item)
	local link = Link(item)
	local out = {}
	for stat, amount in pairs(link and C_Item.GetItemStats(link) or {}) do
		local name = Name(stat)
		if not out[name] or math.abs(amount) > math.abs(out[name]) then out[name] = amount end
	end
	return out
end

-- The stat differences as rows, DPS and armor first.
local function Changes(new, old)
	local first = { [Name("ITEM_MOD_DAMAGE_PER_SECOND_SHORT")] = 1, [Name("RESISTANCE0_NAME")] = 2 }
	local by, order, rows = {}, {}, {}
	local stats = {}
	for name in pairs(new) do stats[name] = true end
	for name in pairs(old) do stats[name] = true end
	for name in pairs(stats) do
		local change = (new[name] or 0) - (old[name] or 0)
		if math.abs(change) >= 0.05 then
			by[name] = change
			order[#order + 1] = name
		end
	end
	table.sort(order, function(a, b)
		local fa, fb = first[a] or 9, first[b] or 9
		if fa ~= fb then return fa < fb end
		return a < b
	end)
	for _, name in ipairs(order) do
		rows[#rows + 1] = { text = name, right = Signed(by[name]), rightColor = by[name] > 0 and C.good or C.bad }
	end
	return rows
end

-- An item's stats by name, only those ShyGear doesn't weigh.
local function Uncounted(item, gear)
	local link = Link(item)
	local out = {}
	for stat, amount in pairs(link and C_Item.GetItemStats(link) or {}) do
		if not gear:Counted(stat) then
			local name = Name(stat)
			if not out[name] or math.abs(amount) > math.abs(out[name]) then out[name] = amount end
		end
	end
	return out
end

-- ShyGear's worth of each change as rows, then the stats it doesn't weigh; nil without ShyGear's say.
local function Worth(mine, worn)
	local gear = Shy.addons.Gear
	if not (gear and gear.Trade and gear.Counted) then return nil end
	local link = Link(mine)
	local wornLinks = {}
	for i, item in ipairs(worn) do wornLinks[i] = Link(item) end
	if not link or #wornLinks ~= #worn then return nil end
	local ok, parts = pcall(gear.Trade, gear, link, wornLinks)
	if not ok or type(parts) ~= "table" then return nil end
	local rows = {}
	for _, part in ipairs(parts) do
		local color = part.worth > 0.005 and C.good or part.worth < -0.005 and C.bad or C.dim
		rows[#rows + 1] = { text = Signed(part.n) .. " " .. part.name, right = part.says, rightColor = color }
	end
	local before = {}
	for _, item in ipairs(worn) do
		for name, amount in pairs(Uncounted(item, gear)) do before[name] = (before[name] or 0) + amount end
	end
	for _, row in ipairs(Changes(Uncounted(mine, gear), before)) do
		rows[#rows + 1] = { text = row.right .. " " .. row.text, right = "not counted", rightColor = C.dim }
	end
	return rows
end

-- False when ShyGear says your build would never put `mine` in place of `worn`.
local function Weighed(mine, worn)
	local gear = Shy.addons.Gear
	if not (gear and gear.Weighs) then return true end
	local link, wornLink = Link(mine), Link(worn)
	if not (link and wornLink) then return true end
	local ok, weighs = pcall(gear.Weighs, gear, link, wornLink)
	return not ok or weighs ~= false
end

local function Sum(a, b)
	local out = {}
	for stat, amount in pairs(a) do out[stat] = amount end
	for stat, amount in pairs(b) do out[stat] = (out[stat] or 0) + amount end
	return out
end

-- An item as a band names it: its icon and its name in its quality's color. nil until its name is known.
local function Named(item)
	local link = Link(item)
	if not link then return nil end
	local name = C_Item.GetItemNameByID(link)
	if not name then return nil end
	local color
	local data = ColorManager.GetColorDataForItemQuality(C_Item.GetItemQualityByID(link))
	if data then color = { data.color:GetRGB() } end
	local icon = C_Item.GetItemIconByID(link)
	return { seat = icon and ns.IconSeat(icon) or nil, title = name, titleColor = color }
end

-- A band for what is worn, and the stat changes.
--   partner   also replaced (both hands, against a two-hander): named under it the same way
--   with      worn with this one from the bags (one of a pair, against a two-hander): a quiet line
local function Band(worn, rows, partner, with)
	local band = Named(worn)
	if not band then return nil end
	band.lead = "Replaces"
	band.others = { partner and Named(partner) or nil }
	if #rows == 0 then rows = { { text = "Same stats", quiet = true } } end
	local paired = with and Named(with)
	if paired then table.insert(rows, 1, { text = "with " .. UI.Wrap(paired.titleColor or C.text, paired.title), quiet = true }) end
	band.rows = rows
	return band
end

-- about = { info, data, side } from Wing.lua: the tooltip's first info and its data, and true for a
-- comparison tooltip. Returns the bands and the worn items, or nil: nothing for an equipped item, for a
-- comparison tooltip, or for anything but an item.
-- Two rings, trinkets or weapons get a band each (but a weapon never against a shield your build keeps); a
-- two-hander is compared to both hands summed; one of a pair is compared, with its partner, to an equipped
-- two-hander.
function Compare.Read(about)
	local data = about.data
	local kind = data.type
	if issecretvalue(kind) or kind ~= Enum.TooltipDataType.Item then return nil end
	local getter = about.info and about.info.getterName
	if about.side or (not issecretvalue(getter) and getter == "GetInventoryItem") then return nil end
	local guid, link = data.guid, data.hyperlink
	if issecretvalue(guid) or issecretvalue(link) then return nil end
	local item = guid and { guid = guid } or (type(link) == "string" and link ~= "" and { hyperlink = link }) or nil
	if not item then return nil end
	local found = C_TooltipComparison.GetItemComparisonInfo(item)
	if not found or not found.item then return nil end
	local M = Enum.TooltipComparisonMethod
	local mine, worn = Stats(item), Stats(found.item)
	local other = found.additionalItems and found.additionalItems[1]
	local bands, on = {}, { found.item }
	if found.method == M.WithBothHands and other then
		bands[1] = Band(found.item, Worth(item, { found.item, other }) or Changes(mine, Sum(worn, Stats(other))), other)
		on[2] = other
	elseif (found.method == M.WithBagMainHandItem or found.method == M.WithBagOffHandItem) and other then
		-- The partner is in the bags, not worn.
		bands[1] = Band(found.item, Changes(Sum(mine, Stats(other)), worn), nil, other)
	else
		-- Only what your build would put it in place of (a tank's one-hander leaves the shield be); both
		-- when that can't be said.
		local places = {}
		for _, each in ipairs({ found.item, other }) do
			if Weighed(item, each) then places[#places + 1] = each end
		end
		if #places == 0 then places = { found.item, other } end
		for _, each in ipairs(places) do
			bands[#bands + 1] = Band(each, Worth(item, { each }) or Changes(mine, Stats(each)))
		end
		on = places
	end
	if not bands[1] then return nil end
	return bands, on
end
