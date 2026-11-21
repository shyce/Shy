-- Chat parsing. Pure text, no game calls.
--   Parse.Message(text, authorLevel, myLevel) -> nil, or
--       { kind = "lfm" | "lfg", keys, roles, count, size }   (count/size only from "3/5")
--   Parse.Foreign(text, locale) -> true when the line isn't in the player's language
--   Parse.Reply(text) -> "yes" | "no" | nil
--   Parse.Wants(text) -> true when a whisper reads like "invite me"
-- Lines are flattened first (lower case, no links or punctuation, space padded)
-- so words match whole: " lf1m zulfarrak need tank ".

local ADDON, ns = ...
local P = {}
ns.Parse = P

local D = ns.Data

local function Set(words)
	local set = {}
	for word in words:gmatch("%S+") do set[word] = true end
	return set
end

-- A line with any of these is trade or a service, not a group.
local SERVICE = Set("wts wtb wtt selling buying boost boosts boosting boosted carry carries recruiting recruits recruit layer summon summons port ports portal portals lockpicking")

local ROLE = {}
for word in ("tank tanks tanking prot mt ot"):gmatch("%S+") do ROLE[word] = "tank" end
for word in ("heal heals healer healers healing hlr resto holy"):gmatch("%S+") do ROLE[word] = "healer" end
for word in ("dps dd dds damage dmg dpser dpsers caster casters melee ranged"):gmatch("%S+") do ROLE[word] = "dps" end

-- Allowed between "need" / "lf" and the role: "need a good tank".
local FILLER = Set("a an one two three four 1 2 3 4 1x 2x 3x x good geared decent more last final another and or the")
local GROUP_WORD = Set("group grp party pt")
-- Roles after these are the ones a group has, until it asks again: "have tank and heals, need dps".
local HAVE = Set("have has got")

local YES = Set("yes yea yeah yep yup ye ya sure ok okay k kk inv invite down definitely absolutely omw ready y pls plz please coming")
local YES_PHRASE = { " im in ", " i am in ", " count me in ", " sounds good ", " lets go ", " why not ", " im down ", " id love to ", " on my way ",
	" group me " }
local NO = Set("no nope nah busy pass cant cannot")
local NO_PHRASE = { " no thanks ", " no thx ", " no ty ", " not now ", " not right now ", " another time ", " maybe later ", " in a group ", " im good ", " all good ", " im ok ",
	" no time ", " in group " }
local WANTS = Set("inv invite join spot room lfg")

function P.Flatten(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|Hitem:.-|h.-|h", " ")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", " "):gsub("|A.-|a", " "):gsub("{.-}", " ")
	text = text:lower():gsub("\226\128[\152-\159]", ""):gsub("['`]", "")   -- curly and straight quotes dropped alike
	text = text:gsub("[%p%c]", " "):gsub("%s+", " ")
	return " " .. strtrim(text) .. " "
end

local words = {}   -- { { find = " vc ", key = "VC", zone = false }, ... }
local groups = {}   -- { { find = " sm ", keys = { ... } }, ... }

-- extra: the player's own words, dungeon key -> "word, word".
function P.Rebuild(extra)
	wipe(words)
	wipe(groups)
	for _, d in ipairs(D.list) do
		local zone = d.kind == "zone"
		for _, word in ipairs(d.words) do
			words[#words + 1] = { find = " " .. word .. " ", key = d.key, zone = zone }
		end
		-- The full localized name counts too.
		words[#words + 1] = { find = P.Flatten(d.name), key = d.key, zone = zone }
		local more = extra and extra[d.key]
		if more then
			for raw in more:gmatch("[^,]+") do
				local word = strtrim(P.Flatten(raw))
				if word ~= "" then words[#words + 1] = { find = " " .. word .. " ", key = d.key, zone = zone } end
			end
		end
	end
	for _, g in ipairs(D.GROUPS) do
		for _, word in ipairs(g.words) do
			groups[#groups + 1] = { find = " " .. word .. " ", keys = g.keys }
		end
	end
end

-- A zone's name counts only when no dungeon or raid is named: "lfg wc, at the
-- barrens entrance" is about the dungeon.
local function FindDungeons(flat, authorLevel, myLevel)
	local found, keys, zones = {}, {}, {}
	local function Add(key)
		if not found[key] and D.byKey[key] then
			found[key] = true
			keys[#keys + 1] = key
		end
	end
	for _, w in ipairs(words) do
		if flat:find(w.find, 1, true) then
			if w.zone then zones[#zones + 1] = w.key else Add(w.key) end
		end
	end
	for _, g in ipairs(groups) do
		if flat:find(g.find, 1, true) then
			local named = false
			for _, key in ipairs(g.keys) do named = named or found[key] end
			if not named then
				for _, key in ipairs(g.keys) do Add(key) end
			end
		end
	end
	if flat:find(" dm ", 1, true) then
		local dm = D.DM
		local named = found[dm.low]
		for _, key in ipairs(dm.high) do named = named or found[key] end
		if not named then
			local level = authorLevel or myLevel or 1
			if level < dm.split then
				Add(dm.low)
			else
				for _, key in ipairs(dm.high) do Add(key) end
			end
		end
	end
	if #keys == 0 then
		for _, key in ipairs(zones) do Add(key) end
	end
	return keys
end

-- Channel posts

function P.Message(text, authorLevel, myLevel)
	-- "3/5": a group counting its members.
	local a, b = text:match("(%d+)%s*/%s*(%d+)")
	a, b = tonumber(a), tonumber(b)
	local counted = a and b and a < b and (b == 5 or b == 10 or b == 20 or b == 40)
	local count, size = counted and a or nil, counted and b or nil

	local flat = P.Flatten(text)
	local tokens = {}
	for tok in flat:gmatch("%S+") do
		if SERVICE[tok] then return nil end
		tokens[#tokens + 1] = tok
	end
	local n = #tokens

	-- After "lf" / "need": "members" (a role or "more"), "group", or nil.
	local function Ahead(i)
		for j = i + 1, math.min(n, i + 4) do
			local t = tokens[j]
			if ROLE[t] or t == "more" or t:match("^%d+m$") then return "members" end
			if GROUP_WORD[t] then return "group" end
			if not FILLER[t] and not t:match("^%d+$") then return nil end
		end
	end

	local lfm, lfg, bareLF = counted, false, false
	local roles = {}
	local owned = false   -- past "have": the roles named are filled, not wanted
	for i, tok in ipairs(tokens) do
		local asks = true
		if tok == "lfm" or tok:match("^lf%d+m?$") or tok:match("^lfm%d+$") then
			lfm = true
		elseif tok == "lfg" then
			lfg = true
		elseif tok == "lf" or (tok == "for" and tokens[i - 1] == "looking") then
			local what = Ahead(i)
			if what == "members" then lfm = true
			elseif what == "group" then lfg = true
			else bareLF = true end
		elseif tok == "need" or tok == "needs" or tok == "needing" then
			if Ahead(i) == "members" then lfm = true end
		else
			asks = false
		end
		if asks then
			owned = false
		elseif HAVE[tok] then
			owned = true
		elseif ROLE[tok] and not owned then
			roles[ROLE[tok]] = true
		end
	end

	local keys = FindDungeons(flat, authorLevel, myLevel)
	-- "LF WC": a player after that dungeon.
	if not lfm and not lfg and bareLF and #keys > 0 then lfg = true end
	if not lfm and not lfg then return nil end
	return { kind = lfm and "lfm" or "lfg", keys = keys, roles = roles,
		count = lfm and count or nil, size = lfm and size or nil }
end

-- Language detection: another alphabet (by UTF-8 lead byte), or LFG words of
-- German, Spanish, Portuguese and French. English always counts as readable.

local OWN_SCRIPT = { ruRU = "cyrillic", koKR = "hangul", zhCN = "cjk", zhTW = "cjk" }
local OWN_LANGUAGE = { deDE = "de", esES = "es", esMX = "es", ptBR = "pt", ptPT = "pt", frFR = "fr" }

-- strong: one word is enough; weak: two are needed.
local LATIN = {
	de = { strong = Set("suche sucht suchen gesucht"), weak = Set("f\195\188r fuer noch und wir brauchen heiler gruppe jemand einen") },
	es = { strong = Set("busco buscamos necesito necesitamos"), weak = Set("para grupo alguien sanador tanque vamos falta faltan mazmorra") },
	pt = { strong = Set("procuro procurando preciso precisamos"), weak = Set("para grupo alguem vamos curador tanque falta faltam masmorra") },
	fr = { strong = Set("cherche cherchons recherche besoin"), weak = Set("pour groupe soigneur nous donjon dispo quelqu") },
}

-- Alphabet of a UTF-8 lead byte (nil: Latin, punctuation, symbols).
local function Script(lead, nextByte)
	if lead < 0xCA then return nil end
	if lead >= 0xD0 and lead <= 0xD4 then return "cyrillic" end
	if lead <= 0xE1 then return "other" end                       -- Greek, Hebrew, Arabic, Thai...
	if lead == 0xE2 or lead == 0xEE or lead >= 0xF0 then return nil end   -- punctuation, symbols, emoji
	if lead == 0xEF then return nextByte and nextByte >= 0xBC and "cjk" or nil end   -- full-width forms
	if lead >= 0xEA then return "hangul" end
	return "cjk"                                                  -- 0xE3 to 0xE9
end

function P.Foreign(text, locale)
	local own = OWN_SCRIPT[locale]
	local letters = 0
	for i = 1, #text do
		local script = Script(text:byte(i), text:byte(i + 1))
		if script and script ~= own then letters = letters + 1 end
	end
	if letters >= 2 then return true end

	-- Words shared with the player's own language ("para", "grupo") don't count.
	local mine = LATIN[OWN_LANGUAGE[locale]]
	local flat = P.Flatten(text)
	for _, sets in pairs(LATIN) do
		if sets ~= mine then
			local weak = 0
			for tok in flat:gmatch("%S+") do
				if not (mine and (mine.strong[tok] or mine.weak[tok])) then
					if sets.strong[tok] then return true end
					if sets.weak[tok] then weak = weak + 1 end
				end
			end
			if weak >= 2 then return true end
		end
	end
	return false
end

-- Whispers

local function HasAny(flat, set, phrases)
	for _, phrase in ipairs(phrases) do
		if flat:find(phrase, 1, true) then return true end
	end
	for tok in flat:gmatch("%S+") do
		if set[tok] then return true end
	end
	return false
end

function P.Reply(text)
	local flat = P.Flatten(text)
	if HasAny(flat, NO, NO_PHRASE) then return "no" end
	-- A question ("which dm?") is neither.
	if text:find("?", 1, true) then return nil end
	if HasAny(flat, YES, YES_PHRASE) then return "yes" end
	return nil
end

-- The one role a line names ("i can heal", "tank here"); nil when none or several.
function P.RoleIn(text)
	local flat = P.Flatten(text)
	local found
	for tok in flat:gmatch("%S+") do
		local role = ROLE[tok]
		if role then
			if found and found ~= role then return nil end
			found = role
		end
	end
	return found
end

function P.Wants(text)
	local flat = P.Flatten(text)
	if flat:find(" group me ", 1, true) then return true end
	for tok in flat:gmatch("%S+") do
		if WANTS[tok] or ROLE[tok] then return true end
	end
	return false
end
