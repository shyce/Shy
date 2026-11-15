-- Dungeons, raids and quest zones (ids, levels and sizes from the Group Finder's
-- activities) and their chat words. `words` are lower case with no punctuation,
-- as Parse flattens text.

local ADDON, ns = ...
local D = {}
ns.Data = D

-- kind: dungeon | raid | zone (a Quests & Zones listing) | custom (the Group Finder's one custom activity)
local KIND_ORDER = { dungeon = 1, raid = 2, zone = 3, custom = 4 }

local function Dungeon(key, ids, name, min, max, words, size, raid)
	return { key = key, ids = ids, name = name, min = min, max = max, words = words, size = size or 5, raid = raid or false,
		kind = raid and "raid" or "dungeon" }
end

D.list = {
	Dungeon("RFC",    { 798 },  "Ragefire Chasm",            13, 18, { "rfc", "ragefire" }),
	Dungeon("THANES", { 1984 }, "Hall of Thanes",            13, 20, { "hot", "thanes", "thane", "hall of thanes", "halls of thanes" }),
	Dungeon("WC",     { 796 },  "Wailing Caverns",           15, 24, { "wc", "wailing" }),
	Dungeon("LORD",   { 1982 }, "Ruins of Lordaeron",        15, 22, { "rol", "lordaeron", "lord ruins", "ruins of lordaeron" }),
	Dungeon("VC",     { 799 },  "Deadmines",                 17, 26, { "deadmines", "dead mines", "vc", "vancleef" }),
	Dungeon("SFK",    { 800 },  "Shadowfang Keep",           20, 30, { "sfk", "shadowfang" }),
	Dungeon("BFD",    { 801 },  "Blackfathom Deeps",         24, 32, { "bfd", "blackfathom" }),
	Dungeon("STK",    { 802 },  "Stormwind Stockades",       24, 32, { "stocks", "stockades", "stockade", "stk" }),
	Dungeon("EXCAV",  { 1981 }, "Excavation Site: Wetlands", 26, 33, { "esw", "excavation", "excav", "excavation site", "dig site", "digsite" }),
	Dungeon("DAL",    { 1983 }, "City of Dalaran",           28, 35, { "cod", "dalaran", "dala", "city of dalaran" }),
	Dungeon("GNO",    { 803 },  "Gnomeregan",                29, 38, { "gnomer", "gnomeregan", "gnome" }),
	Dungeon("RFK",    { 804 },  "Razorfen Kraul",            29, 38, { "rfk", "kraul" }),
	Dungeon("SMG",    { 805 },  "Scarlet Monastery - Graveyard", 30, 38, { "gy", "graveyard", "smgy", "sm gy" }),
	Dungeon("SML",    { 829 },  "Scarlet Monastery - Library",   33, 41, { "lib", "library", "smlib", "sm lib" }),
	Dungeon("SMA",    { 827 },  "Scarlet Monastery - Armory",    36, 44, { "arm", "armory", "armoury", "smarm", "sm arm", "herod" }),
	Dungeon("RFD",    { 806 },  "Razorfen Downs",            37, 46, { "rfd", "downs" }),
	Dungeon("SMC",    { 828 },  "Scarlet Monastery - Cathedral", 38, 46, { "cath", "cathedral", "smcath", "sm cath" }),
	Dungeon("ULD",    { 807 },  "Uldaman",                   41, 51, { "uld", "ulda", "uldaman" }),
	Dungeon("ZF",     { 808 },  "Zul'Farrak",                44, 54, { "zf", "zulfarrak", "farrak" }),
	Dungeon("MARA",   { 809 },  "Maraudon",                  46, 55, { "mara", "maraudon", "princess run" }),
	Dungeon("ST",     { 810 },  "Sunken Temple",             50, 60, { "st", "sunken", "sunken temple", "atal", "atalhakkar" }),
	Dungeon("BRD",    { 811 },  "Blackrock Depths",          52, 60, { "brd", "blackrock depths", "emp run", "arena run", "lava run", "angerforge" }),
	Dungeon("DME",    { 813 },  "Dire Maul (East)",          54, 60, { "dme", "dm east", "dm e", "dire maul east", "jump run" }),
	Dungeon("LBRS",   { 812 },  "Lower Blackrock Spire",     55, 60, { "lbrs", "lower brs", "lower blackrock" }),
	Dungeon("DMW",    { 814 },  "Dire Maul (West)",          56, 60, { "dmw", "dm west", "dm w", "dire maul west" }),
	Dungeon("DMN",    { 815 },  "Dire Maul (North)",         56, 60, { "dmn", "dm north", "dm n", "dire maul north", "tribute", "dm tribute" }),
	Dungeon("STRAT",  { 816, 1603 }, "Stratholme",           58, 60, { "strat", "stratholme", "baron run" }),
	Dungeon("SCHOLO", { 797 },  "Scholomance",               58, 60, { "scholo", "scholomance", "sholo" }),
	Dungeon("UBRS",   { 837 },  "Upper Blackrock Spire",     59, 60, { "ubrs", "upper brs", "upper blackrock", "rend run" }, 10),

	Dungeon("ZG",     { 836 },  "Zul'Gurub",                 60, 60, { "zg", "zulgurub", "gurub" }, 20, true),
	Dungeon("AQ20",   { 842 },  "Ahn'Qiraj Ruins",           60, 60, { "aq20", "aq 20", "raq", "ruins of ahnqiraj" }, 20, true),
	Dungeon("MC",     { 839 },  "Molten Core",               60, 60, { "mc", "molten core" }, 40, true),
	Dungeon("ONY",    { 838 },  "Onyxia's Lair",             60, 60, { "ony", "onyxia" }, 40, true),
	Dungeon("BWL",    { 840 },  "Blackwing Lair",            60, 60, { "bwl", "blackwing" }, 40, true),
	Dungeon("AQ40",   { 843 },  "Ahn'Qiraj Temple",          60, 60, { "aq40", "aq 40", "taq", "temple of ahnqiraj" }, 40, true),
	Dungeon("NAXX",   { 841 },  "Naxxramas",                 60, 60, { "naxx", "nax", "naxxramas" }, 40, true),
}
-- A group word means every wing unless the line names one.
D.GROUPS = {
	{ words = { "sm", "scarlet", "monastery" }, keys = { "SMG", "SML", "SMA", "SMC" } },
	{ words = { "dire maul", "diremaul" },      keys = { "DME", "DMW", "DMN" } },
	{ words = { "brs", "blackrock spire" },     keys = { "LBRS", "UBRS" } },
	{ words = { "aq", "ahnqiraj" },             keys = { "AQ20", "AQ40" } },
}

-- "DM" is Deadmines below `split`, Dire Maul from there up.
D.DM = { low = "VC", high = { "DME", "DMW", "DMN" }, split = 40 }

D.ROLES = { "tank", "healer", "dps" }
D.ROLE_NAME = { tank = "Tank", healer = "Healer", dps = "Damage" }
D.ROLE_WORD = { tank = "tank", healer = "healer", dps = "DPS" }

-- Whether a class can play a role: the core's answer, the same for everything that reads a role.
function D.CanFill(class, role)
	return Shy.CanFill(class, role)
end

function D.DefaultNeed(size)
	local tank = size <= 5 and 1 or size <= 10 and 2 or size <= 25 and 3 or 4
	local healer = math.max(1, math.floor(size * 0.22 + 0.5))
	return { tank = tank, healer = healer, dps = size - tank - healer }
end

-- The Group Finder's custom listing: one activity, described in words only. Not
-- in D.list: a custom run of your own has the key "custom" and no entry.
D.CUSTOM = { key = "CUSTOM", ids = {}, name = "Custom", min = 1, max = 60, words = {}, size = 5, raid = false, kind = "custom" }

-- Fallback names; the game's own category names replace them at login.
D.KIND_NAME = { dungeon = "Dungeons", raid = "Raids", zone = "Quests & Zones", custom = "Custom" }

D.byKey = {}
D.byActivity = {}   -- Group Finder activity id -> dungeon
D.category = {}     -- kind -> Group Finder category id
D.kinds = {}        -- { { kind, id, name }, ... } in the Group Finder's order; filled at login
D.byMap = {}        -- instance map -> dungeon (lowest wing where several share a map); filled at login

local function Index()
	table.sort(D.list, function(a, b)
		if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
		if a.min ~= b.min then return a.min < b.min end
		return a.name < b.name
	end)
	wipe(D.byKey)
	wipe(D.byActivity)
	for i, d in ipairs(D.list) do
		d.order = i
		D.byKey[d.key] = d
		for _, id in ipairs(d.ids) do D.byActivity[id] = d end
	end
	D.CUSTOM.order = #D.list + 1
	D.byKey[D.CUSTOM.key] = D.CUSTOM
	for _, id in ipairs(D.CUSTOM.ids) do D.byActivity[id] = D.CUSTOM end
end
Index()
-- Stratholme has two activities; the localized name would be one entrance's.
D.byKey.STRAT.keepName = true

local function Plain(name)
	return strtrim((name:lower():gsub("'", ""):gsub("[%p%c]", " "):gsub("%s+", " ")))
end

-- The level range the game suggests for an activity, as its own "at your level" uses.
local function Range(info)
	local min = (info.minLevelSuggestion or 0) > 0 and info.minLevelSuggestion or info.minLevel or 0
	local max = (info.maxLevelSuggestion or 0) > 0 and info.maxLevelSuggestion or min
	return min, math.max(max, min)
end

-- What the game knows of an activity beyond its name: the short name where it
-- has one, and the suggested bounds its own level filter uses (0: no bound).
local function Learn(d, info)
	local short = info.shortName
	d.short = short and short ~= "" and short ~= info.fullName and short or nil
	d.low, d.high = info.minLevelSuggestion or 0, info.maxLevelSuggestion or 0
end

-- Whether an activity is for this level, as the game's own filter decides: a
-- bound it doesn't set doesn't apply. A zone's quests take a level either
-- side; a custom listing has no range.
function D.Fits(d, level)
	if d.kind == "custom" then return true end
	local slack = d.kind == "dungeon" and 0 or 1
	local low = d.low or d.min
	local high = d.high or d.max
	if low > 0 and level < low - slack then return false end
	if high > 0 and level > high + slack then return false end
	return true
end

-- A zone listing has no size: a party of five for its group quests.
local function Zone(id, info)
	local groupID = info.groupFinderActivityGroupID
	local groupName = groupID and groupID > 0 and C_LFGList.GetActivityGroupInfo(groupID) or nil
	local min, max = Range(info)
	min = math.max(1, min)
	local words = { Plain(info.fullName) }
	local short = info.shortName and info.shortName ~= "" and Plain(info.shortName)
	if short and short ~= words[1] then words[2] = short end
	local d = Dungeon("Z" .. id, { id }, info.fullName, min, math.max(max, min), words, 5)
	d.kind, d.zone, d.group = "zone", true, groupName
	Learn(d, info)
	return d
end

-- What a category the known dungeons don't name holds: the custom listing, zones, or something else (PvP).
local function KindOf(category, ids)
	if category.autoChooseActivity then return "custom" end
	local info = ids[1] and C_LFGList.GetActivityInfoTable(ids[1])
	if info and info.maxNumPlayers == 0 and not info.isPvpActivity then return "zone" end
	return nil
end

-- Localizes names and level ranges, learns the Group Finder's categories and
-- adds any dungeon, raid or zone not listed above.
function D.Init()
	local byMap, kinds = {}, {}
	for _, d in ipairs(D.list) do
		local info = C_LFGList.GetActivityInfoTable(d.ids[1])
		if info then
			if not d.keepName then d.name = info.fullName end
			local min, max = Range(info)
			if min > 0 then d.min, d.max = min, max end
			Learn(d, info)
			byMap[info.mapID] = d
			kinds[info.categoryID] = d.kind
		end
	end
	local known = {}
	for _, d in ipairs(D.list) do
		for _, id in ipairs(d.ids) do known[id] = true end
	end
	for _, id in ipairs(D.CUSTOM.ids) do known[id] = true end
	D.CUSTOM.max = GetMaxPlayerLevel()

	wipe(D.kinds)
	wipe(D.category)
	for _, categoryID in ipairs(C_LFGList.GetAvailableCategories()) do
		local category = C_LFGList.GetLfgCategoryInfo(categoryID)
		local ids = C_LFGList.GetAvailableActivities(categoryID)
		local kind = kinds[categoryID] or (category and KindOf(category, ids))
		if kind and not D.category[kind] and #ids > 0 then
			D.category[kind] = categoryID
			D.kinds[#D.kinds + 1] = { kind = kind, id = categoryID, name = category and category.name or D.KIND_NAME[kind] }
			for _, id in ipairs(ids) do
				local info = not known[id] and C_LFGList.GetActivityInfoTable(id)
				if info then
					known[id] = true
					if kind == "custom" then
						table.insert(D.CUSTOM.ids, id)
					elseif kind == "zone" then
						table.insert(D.list, Zone(id, info))
					else
						local twin = byMap[info.mapID]
						if twin then
							table.insert(twin.ids, id)
						else
							local min, max = Range(info)
							local d = Dungeon("A" .. id, { id }, info.fullName, min, max,
								{ Plain(info.fullName) }, info.maxNumPlayers, kind == "raid")
							Learn(d, info)
							table.insert(D.list, d)
							byMap[info.mapID] = d
						end
					end
				end
			end
		end
	end
	Index()
	wipe(D.byMap)
	for _, d in ipairs(D.list) do
		local info = d.kind == "dungeon" and C_LFGList.GetActivityInfoTable(d.ids[1])
		if info then
			d.map = info.mapID
			D.byMap[d.map] = D.byMap[d.map] or d
		end
	end
end

-- The name the game gives a kind's category, else our own.
function D.KindName(kind)
	for _, k in ipairs(D.kinds) do
		if k.kind == kind then return k.name end
	end
	return D.KIND_NAME[kind] or kind
end

-- Everything of one kind, in level order.
function D.OfKind(kind)
	local out = {}
	for _, d in ipairs(D.list) do
		if d.kind == kind then out[#out + 1] = d end
	end
	return out
end

function D.ForLevel(level, kind)
	local out = {}
	for _, d in ipairs(D.list) do
		if (not kind or d.kind == kind) and D.Fits(d, level) then out[#out + 1] = d end
	end
	return out
end

-- "13-18", "40 players" for a raid, nothing for a custom listing.
function D.RangeText(d)
	if d.kind == "custom" then return "" end
	if d.kind == "raid" then return d.size .. " players" end
	return d.min .. "-" .. d.max
end

-- True when a Who result's zone is a listed instance. Quest zones are the
-- open world and don't count.
function D.IsInstanceArea(area)
	if not area or area == "" then return false end
	local plain = Plain(area)
	for _, d in ipairs(D.list) do
		if d.kind ~= "zone" then
			local name = Plain(d.name)
			if name == plain or name:find(plain, 1, true) == 1 then return true end
		end
	end
	return false
end
