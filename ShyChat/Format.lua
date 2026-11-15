-- Chat lines in ShyChat's words: the game keeps each line as it came, and its visible lines are given
-- our text as the game draws them (Lines, below). A secret line is only composed (its timestamp), never read.

local ADDON, ns = ...
local UI = Shy.UI
local F = {}
ns.Format = F

local db
local gsub, find, sub, upper, lower = string.gsub, string.find, string.sub, string.upper, string.lower
local concat = table.concat
local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"
local DOT = "\194\183"

local function Escape(s)
	return (gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Chat type tags ([Guild] -> [G]). Labels come from the client's global strings, so any locale works.

F.TYPE_ORDER = {
	{ "GUILD", "Guild" }, { "OFFICER", "Officer" }, { "PARTY", "Party" }, { "PARTY_LEADER", "Party lead" },
	{ "RAID", "Raid" }, { "RAID_LEADER", "Raid lead" }, { "RAID_WARNING", "Raid warn" },
	{ "INSTANCE_CHAT", "Instance" }, { "INSTANCE_CHAT_LEADER", "Inst. lead" },
	{ "WHISPER", "Whisper" }, { "WHISPER_INFORM", "Whisper to" },
}

F.TYPE_DEFAULTS = {
	GUILD = "G", OFFICER = "O", PARTY = "P", PARTY_LEADER = "PL", PARTY_GUIDE = "DG",
	RAID = "R", RAID_LEADER = "RL", RAID_WARNING = "RW", INSTANCE_CHAT = "I",
	INSTANCE_CHAT_LEADER = "IL", GUILD_DISCORD = "GD", WHISPER = "W", WHISPER_INFORM = "To",
}

local LABEL_TO_TYPE = {}
for key in pairs(F.TYPE_DEFAULTS) do
	local template = _G["CHAT_" .. key .. "_GET"]
	local label = template and template:match("|h%[(.-)%]|h")
	if label then LABEL_TO_TYPE[label] = key end
end
local RAID_WARNING_LABEL = CHAT_RAID_WARNING_GET:match("^%[.-%]")

function F.TypeShort(key)
	local custom = db.typeNames[key]
	if custom and custom ~= "" then return custom end
	return F.TYPE_DEFAULTS[key]
end

local function Tag(label)
	if db.brackets == "round" then return "(" .. label .. ")" end
	if db.brackets == "none" then return label end
	return "[" .. label .. "]"
end

-- Channel short names are derived: "General" -> G (taken by Guild) -> Gen, "LookingForGroup" -> LFG.
-- The lowest channel number gets the shortest free name; a custom name wins.

local auto = {}          -- channel number -> automatic short name
F.channels = {}          -- { { num = 1, name = "General" }, ... } currently joined

local function BaseName(text)
	text = gsub(text, "^%d+%.%s*", "")
	return (gsub(text, "%s+%-%s+.*$", ""))
end
F.BaseName = BaseName

local function Take(word, n)
	local out = {}
	for ch in word:gmatch(UTF8_CHAR) do
		if #out == n then break end
		out[#out + 1] = ch
	end
	return concat(out)
end

local function Words(name)
	local words = {}
	for w in gsub(name, "(%l)(%u)", "%1 %2"):gmatch("[^%s%-_/:]+") do words[#words + 1] = w end
	return words
end

local function Candidates(name)
	local words = Words(name)
	if #words == 0 then return { name } end
	if #words == 1 then
		local w = words[1]
		return { upper(Take(w, 1)), upper(Take(w, 1)) .. Take(w, 3):sub(#Take(w, 1) + 1), upper(Take(w, 1)) .. w:sub(#Take(w, 1) + 1) }
	end
	local initials = ""
	for _, w in ipairs(words) do initials = initials .. upper(Take(w, 1)) end
	return { initials, upper(Take(words[1], 1)) .. Take(words[1], 2):sub(#Take(words[1], 1) + 1) .. initials:sub(2) }
end

function F.RebuildChannels()
	wipe(auto)
	wipe(F.channels)
	local taken = {}
	for key in pairs(F.TYPE_DEFAULTS) do taken[lower(F.TypeShort(key))] = true end
	for _, custom in pairs(db.channelNames) do taken[lower(custom)] = true end

	local list = { GetChannelList() }
	for i = 1, #list, 3 do
		local num, base = list[i], BaseName(list[i + 1])
		local choice
		for _, candidate in ipairs(Candidates(base)) do
			if not taken[lower(candidate)] then
				choice = candidate
				break
			end
		end
		choice = choice or (Candidates(base)[1] .. num)
		taken[lower(choice)] = true
		auto[num] = choice
		F.channels[#F.channels + 1] = { num = num, name = base }
	end
end

function F.AutoShort(num, base)
	return auto[num] or Candidates(base)[1]
end

function F.ChannelLabel(num, text)
	local base = BaseName(text)
	local custom = db.channelNames[base]
	local short = (custom and custom ~= "") and custom or F.AutoShort(num, base)
	local style = db.channelStyle
	if style == "number" then return tostring(num) end
	if style == "name" then return base end
	if style == "numshort" then return num .. DOT .. short end
	return short
end

local function Channels(msg, event)
	msg = gsub(msg, "|Hchannel:channel:(%d+)|h%[(.-)%]|h", function(num, text)
		return "|Hchannel:channel:" .. num .. "|h" .. Tag(F.ChannelLabel(tonumber(num), text)) .. "|h"
	end, 1)
	msg = gsub(msg, "|Hchannel:CHANNEL:(%d+)|h%[(.-)%]|h", function(num, text)
		return "|Hchannel:CHANNEL:" .. num .. "|h" .. Tag(F.ChannelLabel(tonumber(num), text)) .. "|h"
	end, 1)
	msg = gsub(msg, "|Hchannel:(%u[%u_]*)|h%[(.-)%]|h", function(kind, text)
		local key = LABEL_TO_TYPE[text] or kind
		local label = db.channelStyle == "name" and text or F.TypeShort(key) or text
		return "|Hchannel:" .. kind .. "|h" .. Tag(label) .. "|h"
	end, 1)
	if event == "CHAT_MSG_RAID_WARNING" and find(msg, RAID_WARNING_LABEL, 1, true) == 1 then
		msg = Tag(F.TypeShort("RAID_WARNING")) .. sub(msg, #RAID_WARNING_LABEL + 1)
	end
	return msg
end

-- Compact wording: "Thrall says: hi" -> "Thrall: hi", whispers get a tag

local SPEECH = {
	CHAT_MSG_SAY = { CHAT_SAY_GET },
	CHAT_MSG_YELL = { CHAT_YELL_GET },
	CHAT_MSG_WHISPER = { CHAT_WHISPER_GET, "WHISPER" },
	CHAT_MSG_WHISPER_INFORM = { CHAT_WHISPER_INFORM_GET, "WHISPER_INFORM" },
	CHAT_MSG_BN_WHISPER = { CHAT_BN_WHISPER_GET, "WHISPER" },
	CHAT_MSG_BN_WHISPER_INFORM = { CHAT_BN_WHISPER_INFORM_GET, "WHISPER_INFORM" },
}
for _, s in pairs(SPEECH) do
	s.pre, s.suf = s[1]:match("^(.-)%%s(.*)$")
end

local PLAYER_LINK = "|H%a*[Pp]layer:.-|h.-|h"

local function CompactSpeech(msg, event)
	local s = SPEECH[event]
	if not s or sub(msg, 1, #s.pre) ~= s.pre then return msg end
	local _, linkEnd = find(msg, PLAYER_LINK, #s.pre + 1)
	if not linkEnd or sub(msg, linkEnd + 1, linkEnd + #s.suf) ~= s.suf then return msg end
	local who = sub(msg, #s.pre + 1, linkEnd)
	local tag = s[2] and (Tag(F.TypeShort(s[2])) .. " ") or ""
	return tag .. who .. ": " .. sub(msg, linkEnd + #s.suf + 1)
end

-- Loot, money and XP lines, matched against the client's global strings.
local PLUS = "|cff5cff7a+|r "
local LOOT_EVENTS = { CHAT_MSG_LOOT = true, CHAT_MSG_MONEY = true, CHAT_MSG_CURRENCY = true, CHAT_MSG_COMBAT_XP_GAIN = true }
local LOOT = {
	{ LOOT_ITEM_SELF_MULTIPLE, PLUS .. "%1 x%2" },
	{ LOOT_ITEM_PUSHED_SELF_MULTIPLE, PLUS .. "%1 x%2" },
	{ CURRENCY_GAINED_MULTIPLE, PLUS .. "%1 x%2" },
	{ LOOT_ITEM_SELF, PLUS .. "%1" },
	{ LOOT_ITEM_PUSHED_SELF, PLUS .. "%1" },
	{ CURRENCY_GAINED, PLUS .. "%1" },
	{ LOOT_ITEM_CREATED_SELF, PLUS .. "%1 |cff888888crafted|r" },
	{ YOU_LOOT_MONEY, PLUS .. "%1" },
	{ LOOT_MONEY_SPLIT, PLUS .. "%1 |cff888888share|r" },
	{ COMBATLOG_XPGAIN_FIRSTPERSON, PLUS .. "%2 XP  |cff888888%1|r" },
	{ COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED, PLUS .. "%1 XP" },
}
for _, entry in ipairs(LOOT) do
	local p = gsub(Escape(entry[1]), "%%%%s", "(.-)")
	entry.pattern = "^" .. gsub(p, "%%%%d", "(%%d+)") .. "%.?$"
end

local function CompactLoot(msg)
	for _, entry in ipairs(LOOT) do
		local out, n = gsub(msg, entry.pattern, entry[2])
		if n > 0 then return out end
	end
	return msg
end

local function Names(msg)
	return (gsub(msg, "(|H%a*[Pp]layer:[^|]*|h)%[(.-)%](|h)", function(open, name, close)
		if db.hideRealm then name = gsub(name, "%-[^|%s]+", "", 1) end
		if db.nameBrackets then name = "[" .. name .. "]" end
		return open .. name .. close
	end))
end

-- Links, mentions and timestamps: only text outside hyperlinks is touched

local function OutsideLinks(msg, fn)
	local out, pos = {}, 1
	while true do
		local s, e = find(msg, "|H.-|h.-|h", pos)
		if not s then break end
		out[#out + 1] = fn(sub(msg, pos, s - 1))
		out[#out + 1] = sub(msg, s, e)
		pos = e + 1
	end
	out[#out + 1] = fn(sub(msg, pos))
	return concat(out)
end

local URL_PATTERNS = { "%a[%w+.-]*://[^%s|]+", "www%.[%w-]+%.[^%s|]+" }

local function LinkURL(url)
	local trail = url:match("[%.,;:!%?%)]+$")
	if trail then url = sub(url, 1, -#trail - 1) end
	return "|cff" .. UI.Hex(UI.colors.hot) .. "|Haddon:ShyChat:url:" .. url .. "|h" .. url .. "|h|r" .. (trail or "")
end

-- One pass per pattern; each skips links the pass before made.
local function URLs(msg)
	for _, pattern in ipairs(URL_PATTERNS) do
		msg = OutsideLinks(msg, function(text) return (gsub(text, pattern, LinkURL)) end)
	end
	return msg
end

local mentionPatterns = {}

function F.RebuildMentions()
	wipe(mentionPatterns)
	local words = {}
	if db.mentionName then words[1] = UnitName("player") end
	for raw in db.keywords:gmatch("[^,]+") do
		local word = strtrim(raw)
		if word ~= "" then words[#words + 1] = word end
	end
	for _, word in ipairs(words) do
		local caseless = gsub(Escape(word), "%a", function(c) return "[" .. upper(c) .. lower(c) .. "]" end)
		mentionPatterns[#mentionPatterns + 1] = "%f[%w]" .. caseless .. "%f[%W]"
	end
end

local TIME_FORMATS = { ["24"] = "%H:%M", ["24s"] = "%H:%M:%S", ["12"] = "%I:%M %p", ["12s"] = "%I:%M:%S %p" }

local function Stamp(t, id)
	local text = date(TIME_FORMATS[db.timestamps], t)
	if db.timestamps == "12" or db.timestamps == "12s" then text = gsub(text, "^0", "") end
	local color = "|cff" .. UI.Hex(db.timeColor)
	if db.timeCopy then
		return color .. "|Haddon:ShyChat:line:" .. id .. "|h" .. text .. "|h|r "
	end
	return color .. text .. "|r "
end

-- A line's time as chat shows it, with a space after; "" while timestamps are off.
function F.Time(t)
	if db.timestamps == "none" then return "" end
	local text = date(TIME_FORMATS[db.timestamps], t)
	if db.timestamps == "12" or db.timestamps == "12s" then text = gsub(text, "^0", "") end
	return "|cff" .. UI.Hex(db.timeColor) .. text .. "|r "
end

-- What someone said, as chat would show it (web links made clickable).
function F.Words(msg)
	if db.enabled and db.urls then return URLs(msg) end
	return msg
end

-- The pipeline: returns the new line, and true if it mentions you.
function F.Format(msg, event, t, id, author)
	if not db.enabled then return msg end
	if db.channelStyle ~= "blizzard" then msg = Channels(msg, event) end
	if db.compact then msg = CompactSpeech(msg, event) end
	if db.compactLoot and LOOT_EVENTS[event] then msg = CompactLoot(msg) end
	msg = Names(msg)
	if db.urls then msg = URLs(msg) end

	local mentioned = false
	if author and #mentionPatterns > 0 and not Shy.IsMe(author) then
		local color = "|cff" .. UI.Hex(db.mentionColor)
		msg = OutsideLinks(msg, function(text)
			for _, pattern in ipairs(mentionPatterns) do
				text = gsub(text, pattern, function(word)
					mentioned = true
					return color .. word .. "|r"
				end)
			end
			return text
		end)
	end

	if db.timestamps ~= "none" and t then msg = Stamp(t, id) .. msg end
	return msg, mentioned
end

-- Lines: what each said, and how it is shown
--
-- Nothing is written into the game's history: each line it keeps (an entry of the message frame's
-- history buffer) is noted as it comes, in tables of our own, and its restyled text is set on the
-- frame's visible lines each time the game draws them (its display callback). A line is formatted once
-- and kept until a setting changes; then the frames are only told to draw again. A line goes from
-- these tables when the game lets its entry go.

local meta = setmetatable({}, { __mode = "k" })     -- the game's entry -> what we know of its line
local byArgs = setmetatable({}, { __mode = "k" })   -- a line's event arguments -> the same (kept by copies and remade lines)
local byId = setmetatable({}, { __mode = "v" })     -- a timestamp link's id -> the line
local TEXTS = 512
local byText, ring, ringAt = {}, {}, 0              -- the newest lines by their words, for copies that carry nothing else
local watched = setmetatable({}, { __mode = "k" })  -- message frame -> "chat" (the game's windows) | "copy" (another's)
local version = 1                                   -- the settings lines were formatted with
local nextId = 0
local Secret = issecretvalue

-- A line as it came: { original, t, event, author, args, id, text (as shown), version }.
local function Note(original, t, event, author, args)
	nextId = nextId + 1
	local line = { original = original, t = t, event = event, author = author, args = args, id = nextId }
	byId[nextId] = line
	if args then byArgs[args] = line end
	if not Secret(original) then
		ringAt = ringAt % TEXTS + 1
		local old = ring[ringAt]
		if old and byText[old.original] == old then byText[old.original] = nil end
		ring[ringAt] = line
		byText[original] = line
	end
	return line
end

-- The line as it is shown with today's settings, formatted on first need. A secret line is only
-- composed: its timestamp put before it, nothing inside it read. Returns the text (nil: as the game has
-- it) and whether it mentions you.
local function Shown(line)
	if line.version == version then return line.text end
	local text, hit
	if Secret(line.original) then
		if db.enabled and db.timestamps ~= "none" and line.t then text = Stamp(line.t, line.id) .. line.original end
	else
		text, hit = F.Format(line.original, line.event, line.t, line.id, line.author)
	end
	line.text, line.version = text, version
	return text, hit
end

-- Post-hook on each chat frame's AddMessage: the entry the game has just put at the front of its
-- history is this line's. The message, the author and the event can be secret.
function F.OnAddMessage(frame, message, r, g, b, infoID, accessID, typeID, event, eventArgs)
	if not Secret(message) and type(message) ~= "string" then return end
	local history = frame.historyBuffer
	local entry = history and history:GetEntryAtIndex(1)
	if not entry or meta[entry] then return end
	if not Secret(message) and entry.message ~= message then return end
	local args = not Secret(eventArgs) and type(eventArgs) == "table" and eventArgs or nil
	local author = args and args[2]
	if author and (Secret(author) or author == "") then author = nil end
	if Secret(event) then event = nil end
	local line = Note(message, time(), event, author, args)
	meta[entry] = line
	local _, hit = Shown(line)
	if hit then ns.OnMention(args and args[11]) end
end

-- What we know of an entry's line: noted as it came, else one the game made again from it (a censored
-- line shown, which keeps its event arguments) and, in another addon's copy, a line it copied.
local function LineOf(entry, copy)
	local line = meta[entry]
	if line then return line end
	local message = entry.message
	if Secret(message) then return nil end
	local extra = entry.extraData
	local args = type(extra) == "table" and extra[5]
	if not Secret(args) and type(args) == "table" then line = byArgs[args] end
	if line and line.original ~= message then
		-- The same line in other words (the game uncensored it): noted afresh, at the time it came.
		line = Note(message, line.t, line.event, line.author, args)
	end
	if not line and copy then line = byText[message] end
	if line then meta[entry] = line end
	return line
end

-- The frame's display callback: each visible line in our words.
local function Draw(frame)
	local lines = frame.visibleLines
	if not lines then return end
	local copy = watched[frame] == "copy"
	for i = 1, #lines do
		local fontString = lines[i]
		local entry = fontString.messageInfo
		local line = entry and LineOf(entry, copy)
		if line then
			local text = Shown(line)
			if text ~= nil then fontString:SetText(text) end
		end
	end
end

local function Drawn(frame)
	local ok, err = pcall(Draw, frame)
	if not ok then geterrorhandler()(err) end
end

-- A message frame whose lines are shown in our words: the game's chat windows ("chat"), or another
-- addon's frame showing lines copied from them ("copy").
function F.Watch(frame, kind)
	if watched[frame] then return end
	if not frame.AddOnDisplayRefreshedCallback then return end
	watched[frame] = kind or "chat"
	frame:AddOnDisplayRefreshedCallback(Drawn)
	frame:MarkDisplayDirty()
end

-- A setting changed: every line is formatted again as it is next shown.
function F.RerenderAll()
	version = version + 1
	for frame in pairs(watched) do frame:MarkDisplayDirty() end
end

-- A line of a frame's history, as GetMessageInfo counts them (1 the oldest): the game's entry and
-- what we know of it (nil for a line that isn't ours).
function F.Line(frame, i)
	local history = frame.historyBuffer
	if not history then return nil end
	local entry = history:GetEntryAtIndex(history:GetNumElements() - i + 1)
	if not entry then return nil end
	return entry, LineOf(entry, watched[frame] == "copy")
end

-- A line's original words and facts, and how it is shown: original, t, event, author, text.
function F.About(line)
	return line.original, line.t, line.event, line.author, (Shown(line))
end

-- A kept line put back at the top of a window's history (history across a reload), noted as it was.
function F.BackFill(frame, original, r, g, b, t, event, author)
	frame:BackFillMessage(original, r, g, b)
	local history = frame.historyBuffer
	local entry = history and history:GetEntryAtIndex(history:GetNumElements())
	if entry and not meta[entry] and entry.message == original then meta[entry] = Note(original, t, event, author) end
end

-- The shown text of the line whose timestamp link carries `id`.
function F.FindLine(_, id)
	local line = id and byId[id]
	return line and (Shown(line)) or nil
end

function F.Init(settings)
	db = settings
	F.RebuildChannels()
	F.RebuildMentions()
end
