-- Unit tooltips as a plate (level ring, name over a health bar) over a card with what the tooltip says,
-- there at once. A PvP flag is a crest before the name and an enemy player's name is red, so the tooltip's own
-- lines saying so are dropped. And what you can do to someone:
-- A right-click on a unit frame opens the game's menu for them; a thanks, a wave and the other emotes are added
-- to it (Menu.ModifyMenu, the game's own way for addons to add rows). A right-click in the world is the game's alone.
-- The same rows and more make a menu of our own for someone known by name (T:PersonItems). It uses unprotected
-- calls only; raid markers and pings are secure rows. InspectUnit is left out: it is Blizzard Lua that would run
-- tainted from an addon's click.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Unit = {}
ns.Unit = Unit

local DOT = " \194\183 "
local RAID_ICONS = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

-- nil for a secret value.
local function Open(value)
	if issecretvalue(value) then return nil end
	return value
end

-- The plate

-- The class as a word in its color: { text, color }, or nil.
local function ClassWord(unit)
	local class, token = UnitClass(unit)
	class, token = Open(class), Open(token)
	if not class then return nil end
	local color = token and C_ClassColor.GetClassColor(token)
	return { text = class, color = color and { color:GetRGB() } or nil }, token
end

-- Whether an ally player's class is already said: their bar is in its color (ShyTip colors them by class) and their
-- name is white. An enemy player's name is red over the same bar (Flag), so theirs is said in words, as ShyPlates
-- tells an enemy druid from a friendly one.
local function ClassShown(unit, look)
	if not (look and look.class and look.health) then return false end
	return Open(UnitCanAttack("player", unit)) == false
end

-- "Night Elf Rogue · Olympus Veterans"; "Night Elf · Olympus Veterans" when their bar says the class (`shown`).
local function PlayerLine(unit, shown)
	local parts = {}
	local race = Open(UnitRace(unit))
	if race then parts[#parts + 1] = { text = race } end
	local class = not shown and ClassWord(unit)
	if class then
		if race then class.text = " " .. class.text end
		parts[#parts + 1] = class
	end
	local guild = Open(GetGuildInfo(unit))
	if guild and guild ~= "" then parts[#parts + 1] = { text = (#parts > 0 and DOT or "") .. guild } end
	return #parts > 0 and parts or nil
end

-- The card's rows that the plate says better are dropped, so a unit with nothing more to say has no card at all, only
-- its plate and the line under it: their faction and PvP flag (the crest, an enemy's red name), a corpse (the plate
-- is grey and says Dead), the level line (the ring holds the level, the dragon the rank), and what the line under the
-- plate says (a creature's kind, family and class, an NPC's title, a player's race, class and guild, each also as a
-- line of its own, as this client's tooltip may write them).
local LEVEL = TOOLTIP_UNIT_LEVEL:match("^(.-)%%s")
local function Plain(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
local function Drop(content, plate, unit, player)
	local said = {}
	for _, name in ipairs({ "FACTION_ALLIANCE", "FACTION_HORDE", "PVP_ENABLED", "CORPSE" }) do
		if _G[name] then said[_G[name]] = true end
	end
	local line = plate.line
	if line then
		local whole = {}
		for _, part in ipairs(line) do whole[#whole + 1] = part.text end
		said[table.concat(whole)] = true
		if #line == 1 then said[line[1].text] = true end
	end
	if unit then
		local kind, family = Open(UnitCreatureType(unit)), Open(UnitCreatureFamily(unit))
		if kind then said[kind] = true end
		if family then said[family] = true end
		local class = Open(UnitClass(unit))
		if class then said[class] = true end
		if player then
			local race = Open(UnitRace(unit))
			if race then said[race] = true end
			local guild = Open(GetGuildInfo(unit))
			if guild and guild ~= "" then
				said[guild] = true
				said["<" .. guild .. ">"] = true
			end
		end
	end
	for at = #content.body, 1, -1 do
		local rows = content.body[at].rows
		if rows then
			for i = #rows, 1, -1 do
				local row = rows[i]
				local text = type(row.text) == "string" and Plain(row.text) or nil
				-- The level line goes with the gap ShyTip.lua wrote at its right: the plate's danger tab says that.
				local level = text and unit and LEVEL and LEVEL ~= "" and text:find(LEVEL, 1, true) == 1
				if text and ((not row.right and said[text]) or level) then
					table.remove(rows, i)
				end
			end
			if #rows == 0 then table.remove(content.body, at) end
		end
	end
end

-- An enemy player's name in the enemy's red, and their PvP crest; a rank's dragon round the level.
local function Flag(plate, unit, player)
	plate.crest = UI.PvPCrest(unit)
	plate.rank = UI.UnitRank(unit)
	plate.dead = Open(UnitIsDead(unit)) == true or nil
	local attack = Open(UnitCanAttack("player", unit))
	if player and attack then plate.titleColor = T.db.colors.hostile end
end

-- Marks: what their nameplate carries, standing past the plaque's point

local function Picture(art, file, coords, color)
	art:SetTexture(file)
	if coords then art:SetTexCoord(unpack(coords)) else art:SetTexCoord(0, 1, 0, 1) end
	art:SetVertexColor(color[1], color[2], color[3])
end

-- A tag's textures besides its picture: under it (back, then face) and over it.
local LAYERS = { "back", "face", "over" }

-- Another addon's mark for them (ShyQuest's), in the form ShyPlates takes a tag.
local function TagSeat(tag)
	return { key = "shytip-tag", tag = tag, set = function(seat)
		if not seat.art then
			seat.back = seat:CreateTexture(nil, "BORDER")
			seat.face = seat:CreateTexture(nil, "BORDER", nil, 1)
			seat.art = seat:CreateTexture(nil, "ARTWORK")
			seat.over = seat:CreateTexture(nil, "OVERLAY")
			for _, key in ipairs(LAYERS) do seat[key]:SetAllPoints() end
			seat.art:SetAllPoints()
			seat.count = UI.Words(seat, UI.NameFont(9), { 1, 1, 1 })
			-- Beside the mark, on its middle (as a nameplate's count is): the plaque's compartment makes room for it.
			seat.count:SetPoint("LEFT", seat, "RIGHT", 2, UI.NameLift(9))
		end
		Picture(seat.art, tag.texture, tag.coords, tag.color or C.hot)
		for _, key in ipairs(LAYERS) do
			local layer = tag[key]
			seat[key]:SetShown(layer ~= nil)
			if layer then Picture(seat[key], layer.texture or tag.texture, layer.coords, layer.color or C.hot) end
		end
		seat.count:SetText(tag.count and tostring(tag.count) or "")
		seat.after = tag.count and (2 + math.ceil(seat.count:GetStringWidth())) or nil
	end }
end

-- A unit token for a GUID. hint: the tooltip's own token, which the game may not give back for it.
local function TokenOf(guid, hint)
	local unit = UnitTokenFromGUID(guid)
	if not issecretvalue(unit) and unit then return unit end
	local theirs = hint and UnitGUID(hint)
	if theirs and not issecretvalue(theirs) and theirs == guid then return hint end
end

-- Their raid mark, read by GUID as the plate stands, so one set from the pin's menu shows too.
-- shown: the marker a tag already pictures.
local function RaidSeat(guid, hint, shown)
	return { key = "shytip-raid", guid = guid, set = function(seat)
		if not seat.art then
			seat.art = seat:CreateTexture(nil, "ARTWORK")
			seat.art:SetAllPoints()
			seat.art:SetTexture(RAID_ICONS)
		end
		seat.there = false
	end, live = function(seat)
		local unit = TokenOf(guid, hint)
		if not unit then return seat.there end
		-- The index can be secret; the game's own function takes it as it is.
		local index = GetRaidTargetIndex(unit)
		seat.there = issecretvalue(index) or (index ~= nil and index ~= shown)
		if seat.there then SetRaidTargetIconTexture(seat.art, index) end
		return seat.there
	end }
end

-- A ping on them can't be shown: the game refuses addons its ping events (UNIT_PING_PIN_ADDED).

-- An NPC's title ("Innkeeper") when the second line isn't the level line, else its creature type and its class
-- ("Humanoid · Mage"). Every plain creature is a warrior to the game, so that class says nothing and is left out.
local function CreatureLine(about, unit)
	local second = about.lines[2]
	local level = TOOLTIP_UNIT_LEVEL:match("^(.-)%%s")
	if second and second.text ~= "" and not second.right and not (level and level ~= "" and second.text:find(level, 1, true) == 1) then
		return { { text = second.text, color = second.color } }
	end
	if not unit then return nil end
	local kind, family = Open(UnitCreatureType(unit)), Open(UnitCreatureFamily(unit))
	local parts = {}
	if kind then parts[1] = { text = family and (kind .. DOT .. family) or kind } end
	local class, token = ClassWord(unit)
	if class and token ~= "WARRIOR" then
		if kind then class.text = DOT .. class.text end
		parts[#parts + 1] = class
	end
	return #parts > 0 and parts or nil
end

-- What the plate reads of the unit, each under its own pcall in Unit.Plate (named, so a re-read makes no
-- closures).
local function TipUnit(tip)
	local _, token = tip:GetUnit()
	return Open(token)
end

-- The plate's level and percent; returns whether they are a player.
local function Rank(plate, unit)
	local level = Open(UnitLevel(unit))
	if type(level) == "number" then plate.level = level > 0 and tostring(level) or "??" end
	local player = Open(UnitIsPlayer(unit)) == true
	if CurveConstants and CurveConstants.ScaleTo100 then
		plate.percent = function() return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100) end
		-- The percent shows only once they are hurt.
		plate.hurt = function() return UnitHealthPercent(unit, true, UI.HurtCurve()) end
	end
	-- A player's resource, as their form has it now (a druid's energy in cat form, rage as a bear, mana otherwise).
	if player then
		plate.power = function() return UnitPower(unit), UnitPowerMax(unit), (UnitPowerType(unit)) end
	end
	return player
end

local function OneLine(player, unit, about, shown)
	return (player and unit and PlayerLine(unit, shown)) or (not player and CreatureLine(about, unit)) or nil
end

-- A card that drops anyway (their target, lines the plate doesn't say) covers the line under the plate: the line
-- leads the card instead, its colored words kept, so nothing it says is lost.
local function LineFirst(content, plate)
	local line, body = plate.line, content.body
	if not line or #body == 0 then return end
	local words = {}
	for _, part in ipairs(line) do words[#words + 1] = part.color and UI.Wrap(part.color, part.text) or part.text end
	local row = { text = table.concat(words) }
	if body[1].rows then
		table.insert(body[1].rows, 1, row)
	else
		table.insert(body, 1, { rows = { row } })
	end
	plate.line = nil
end

-- Their target, as the card's last row.
local function Targeting(content, unit)
	local theirs = unit .. "target"
	if Open(UnitExists(theirs)) ~= true then return end
	local name = Open(UnitIsUnit(theirs, "player")) == true and "you" or Open(UnitName(theirs))
	if type(name) ~= "string" then return end
	local body = content.body
	local last = body[#body]
	if not (last and last.rows) then
		last = { rows = {} }
		body[#body + 1] = last
	end
	last.rows[#last.rows + 1] = { text = "Targeting", color = C.dim, right = name }
end

-- Turns the card content Wing.lua built for a unit into a plate over a card.
--   about = { tip, name, look (colors from ShyTip.lua), lines, kinds, data, open }
function Unit.Plate(content, about)
	local tip, look = about.tip, about.look
	local plate = { title = about.name }
	-- Unit functions can error on a unit the tooltip still names, hence the pcalls.
	local got, unit = pcall(TipUnit, tip)
	if not got then unit = nil end
	local player = false
	if unit then
		local ok, is = pcall(Rank, plate, unit)
		if ok then player = is end
	end
	-- Health can be secret: the tooltip bar's value is passed straight to ours, never read.
	local color = look and look.health or C.good
	local bar = tip.StatusBar
	local shown = type(bar) == "table" and bar:IsShown()
	if shown and not issecretvalue(shown) then
		plate.health = { live = function() return bar:GetValue() end, color = color }
	else
		plate.health, plate.percent = { color = color }, nil
	end
	local danger = look and look.danger
	if danger then
		plate.danger = { color = danger.base, tab = danger.above and danger.above > 0 and ("+" .. danger.above) or nil }
	end
	local shown = false
	if unit and player then
		local got, is = pcall(ClassShown, unit, look)
		shown = got and is
	end
	-- One line under the plate, for a unit whose tooltip says nothing more (no card drops then).
	local ok, line = pcall(OneLine, player, unit, about, shown)
	if ok then plate.line = line end
	pcall(Drop, content, plate, unit, player)
	if unit then pcall(Flag, plate, unit, player) end
	local glance = ns.GlanceOf(tip)
	local guid = Open(about.data.guid)
	local tag = glance and glance.tag
	local marks = {}
	if tag then marks[#marks + 1] = TagSeat(tag) end
	if type(guid) == "string" then
		marks[#marks + 1] = RaidSeat(guid, unit, tag and tag.mark)
	end
	plate.marks = marks
	if unit then pcall(Targeting, content, unit) end
	pcall(LineFirst, content, plate)
	content.plate = plate
	content.title, content.titleColor, content.kind, content.key = nil, nil, nil, nil
	content.light, content.pulse, content.wash = nil, nil, nil
	-- The card is there at once; only the foot waits for a rest.
	content.open = nil
end

-- What you can do to someone

-- Who a menu is about: { guid, name, kind }; nil for yourself or when anything is secret.
--   "friend"  a player you can't attack       "foe"    a player you can
--   "npc"     anyone else you can't attack    "enemy"  a creature you can
local function Who(unit)
	local guid = Open(UnitGUID(unit))
	if type(guid) ~= "string" then return nil end
	local attack, player = Open(UnitCanAttack("player", unit)), Open(UnitIsPlayer(unit))
	if attack == nil or player == nil then return nil end
	local mine = Open(UnitGUID("player"))
	if mine == guid then return nil end
	local name, surname = UnitNameUnmodified(unit)
	if issecretvalue(name) or issecretvalue(surname) or type(name) ~= "string" then return nil end
	if surname and surname ~= "" then name = name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname end
	local kind = player and (attack and "foe" or "friend") or (attack and "enemy" or "npc")
	return { guid = guid, name = name, kind = kind }
end

-- A unit token for them: "target" while they are yours, or whatever the GUID resolves to.
local function Token(who)
	local target = UnitGUID("target")
	if not issecretvalue(target) and target == who.guid then return "target" end
	local unit = UnitTokenFromGUID(who.guid)
	if issecretvalue(unit) then return nil end
	return unit
end

-- Emote submenu: greetings first, then Blizzard's EmoteList minus the ones with no target.
local GREETINGS = { "WAVE", "HELLO", "CHEER", "HUG", "CONGRATULATE" }
local ALONE = { STAND = true, SIT = true, SLEEP = true, KNEEL = true, LEAN = true, EAT = true, TALK = true }

-- Emote icons: a white 8 by 4 sprite sheet, tinted. EMOTE_CELLS must match the sheet's cell order.
local EMOTE_ART = "Interface\\AddOns\\ShyTip\\Media\\Emotes"
local EMOTE_COLS, EMOTE_ROWS = 8, 4
local EMOTE_CELLS = { "THANK", "WAVE", "HELLO", "CHEER", "HUG", "CONGRATULATE", "BOW", "DANCE",
	"APPLAUD", "BEG", "CHICKEN", "CRY", "FLEX", "KISS", "LAUGH", "POINT", "ROAR", "RUDE", "SALUTE", "SHY" }
local EMOTE_AT = {}
for index, token in ipairs(EMOTE_CELLS) do EMOTE_AT[token] = index - 1 end

local function EmoteIcon(token)
	local at = EMOTE_AT[token]
	if not at then return nil end
	local col, row = at % EMOTE_COLS, math.floor(at / EMOTE_COLS)
	return { { EMOTE_ART, C.head, coords = { col / EMOTE_COLS, (col + 1) / EMOTE_COLS, row / EMOTE_ROWS, (row + 1) / EMOTE_ROWS } } }
end

-- Players are emoted at by name; others as the current target (an emote with no name goes to the target).
local function Emote(who, token)
	if who.kind ~= "friend" and who.kind ~= "foe" and Token(who) == "target" then
		C_ChatInfo.PerformEmote(token)
	else
		C_ChatInfo.PerformEmote(token, who.name)
	end
end

local function Emotes(who)
	local list, seen = {}, {}
	local function Add(token)
		if seen[token] or ALONE[token] then return end
		seen[token] = true
		list[#list + 1] = { text = token:sub(1, 1) .. token:sub(2):lower(), icon = EmoteIcon(token), click = function() Emote(who, token) end }
	end
	for _, token in ipairs(GREETINGS) do Add(token) end
	for _, token in ipairs(EmoteList or {}) do Add(token) end
	return list
end

-- Raid markers. SetRaidTarget is blocked for addons, so each row is a secure button (type "raidtarget")
-- acting on your target.
local MARKS = 8

local function Marks()
	local list = {}
	for index = 1, MARKS do
		list[index] = { text = _G["RAID_TARGET_" .. index] or ("Mark " .. index),
			icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index,
			-- "toggle": clicking the marker they already have removes it.
			secure = { type = "raidtarget", action = "toggle", marker = index, unit = "target" } }
	end
	list[#list + 1] = { divider = true }
	list[#list + 1] = { text = "No mark", secure = { type = "raidtarget", action = "clear", unit = "target" } }
	return list
end

-- Pings are blocked for addons too: secure macro rows running /ping with the command's own numbers
-- (1 attack, 2 warning, 3 on my way, 4 assist). Listed only while the ping system is enabled.
local PINGS = {
	{ name = "PING_TYPE_ATTACK", word = "Attack", number = 1 },
	{ name = "PING_TYPE_ASSIST", word = "Assist", number = 4 },
	{ name = "PING_TYPE_WARNING", word = "Warning", number = 2 },
	{ name = "PING_TYPE_ON_MY_WAY", word = "On my way", number = 3 },
}

local function Pings()
	if not (C_Ping and C_Ping.IsPingSystemEnabled and C_Ping.IsPingSystemEnabled()) then return nil end
	local list = {}
	for index, ping in ipairs(PINGS) do
		list[index] = { text = _G[ping.name] or ping.word, secure = { type = "macro", macrotext = "/ping [@target] " .. ping.number } }
	end
	return list
end

-- Invites can arrive late, so an invite or a request is also said in /say, never the same line twice running.
local OFFER = {
	"hey %s, want to group up? sent you an invite",
	"%s, invite's on its way if you want to team up",
	"hey %s, tossed you an invite if you're up for it",
}
local ASK = {
	"hey %s, mind if I join you?",
	"%s, got room for one more?",
	"hey %s, could I get an invite?",
}
local saidLast = {}

local function Say(lines, who)
	local first = who.name:match("^(%S+)") or who.name
	local pick = math.random(#lines)
	if pick == saidLast[lines] then pick = pick % #lines + 1 end
	saidLast[lines] = pick
	C_ChatInfo.SendChatMessage(lines[pick]:format(first), "SAY")
end

-- Rows every menu ends with: marker, ping, copy name.
local function Common(items, who)
	items[#items + 1] = { text = "Mark", tip = "Puts a raid marker on them.", items = Marks() }
	local pings = Pings()
	if pings then items[#items + 1] = { text = "Ping", tip = "Pings them for your group.", items = pings } end
	items[#items + 1] = { divider = true }
	items[#items + 1] = { text = "Copy their name", click = function() UI.ShowCopyBox("Their name", who.name) end }
	return items
end

-- One-click rows at the top. Attackable: attack ping, skull, and a wave for an enemy player.
-- Anyone else: thank, wave, skull, attack ping.
local SKULL, ATTACK = 8, 1

local function Quick(items, who)
	local foe = who.kind == "enemy" or who.kind == "foe"
	local thank = { text = "Thank", detail = "emote", icon = EmoteIcon("THANK"), click = function() Emote(who, "THANK") end }
	local wave = { text = "Wave", detail = "emote", icon = EmoteIcon("WAVE"), click = function() Emote(who, "WAVE") end }
	local skull = { text = _G["RAID_TARGET_" .. SKULL] or "Skull", detail = "mark",
		icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. SKULL,
		secure = { type = "raidtarget", action = "toggle", marker = SKULL, unit = "target" } }
	local ping
	if C_Ping and C_Ping.IsPingSystemEnabled and C_Ping.IsPingSystemEnabled() then
		local kit = C_Ping.GetTextureKitForType and Enum.PingSubjectType and C_Ping.GetTextureKitForType(Enum.PingSubjectType.Attack)
		ping = { text = _G.PING_TYPE_ATTACK or "Attack", detail = "ping", icon = kit and { { atlas = "Ping_Wheel_Icon_" .. kit } } or nil,
			secure = { type = "macro", macrotext = "/ping [@target] " .. ATTACK } }
	end
	if foe then
		if ping then items[#items + 1] = ping end
		items[#items + 1] = skull
		if who.kind == "foe" then items[#items + 1] = wave end
	else
		items[#items + 1] = thank
		items[#items + 1] = wave
		items[#items + 1] = skull
		if ping then items[#items + 1] = ping end
	end
	items[#items + 1] = { divider = true }
	return items
end

-- Menu for an NPC, a mob or an enemy player. `heading`: over the rows (default: their name).
local function OtherItems(who, heading)
	local items = Quick({ { heading = heading or who.name } }, who)
	items[#items + 1] = { text = who.kind == "npc" and "More emotes" or "Emote", items = Emotes(who) }
	return Common(items, who)
end

local function Items(who, heading)
	if who.kind ~= "friend" then return OtherItems(who, heading) end
	local pings = Pings()
	local items = Quick({ { heading = heading or who.name } }, who)
	for _, item in ipairs({
		{ text = "Whisper", click = function() ChatFrameUtil.SendTell(who.name) end },
		{ text = "More emotes", items = Emotes(who) },
		{ divider = true },
		{ text = "Invite to group", tip = "Sends an invite and tells them in /say, since invites can be slow to arrive.", click = function()
			C_PartyInfo.InviteUnit(who.name)
			Say(OFFER, who)
		end },
		{ text = "Ask to join their group", tip = "Requests an invite from their group leader and asks them in /say.", click = function()
			C_PartyInfo.RequestInviteFromUnit(who.name)
			Say(ASK, who)
		end },
		{ text = "Trade", tip = "They must be your target and in range.", click = function()
			local unit = Token(who)
			if unit then InitiateTrade(unit) else T:Print("target " .. who.name .. " first to trade with them.") end
		end },
		{ text = "Duel", click = function() StartDuel(who.name, true) end },
		{ text = "Follow", click = function() FollowUnit(who.name, true) end },
		{ text = "Mark", tip = "Puts a raid marker on them.", items = Marks() },
	}) do items[#items + 1] = item end
	if pings then items[#items + 1] = { text = "Ping", tip = "Pings them for your group.", items = pings } end
	items[#items + 1] = { divider = true }
	items[#items + 1] = { text = "Add friend", click = function() C_FriendList.AddFriend(who.name) end }
	items[#items + 1] = { text = "Ignore", click = function() C_FriendList.AddIgnore(who.name) end }
	items[#items + 1] = { text = "Copy their name", click = function() UI.ShowCopyBox("Their name", who.name) end }
	return items
end

-- Secure rows can't be set up during combat lockdown: they are shown disabled, submenus included.
local function Fought(items)
	if not InCombatLockdown() then return items end
	for _, item in ipairs(items) do
		if item.secure then item.disabled, item.detail = true, "after combat" end
		if item.items then Fought(item.items) end
	end
	return items
end

-- For other addons (Shy.addons.Tip:PersonItems): the menu's rows for someone known by name,
-- who = { name, guid, kind = "friend" | "foe" | "npc" | "enemy" }, under `heading` (default: their name).
function T:PersonItems(who, heading)
	return Fought(Items(who, heading))
end

-- The game's unit menu

-- The game's menus for someone in a unit frame, by the name it tags each with ("MENU_UNIT_" and this). Yours and
-- your pet's are left as they are.
local MENUS = { "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "RAID", "TARGET", "FOCUS", "OTHERPET", "BOSS" }
-- The ones that copy a name themselves.
local NAMED = { PLAYER = true, ENEMY_PLAYER = true, PARTY = true, RAID_PLAYER = true }

-- Our rows, added under the game's as the menu opens: a thanks and a wave, one click each (no thanks for what
-- you can attack, no wave for a creature you can), then the rest of the emotes a list away. Whisper, invite,
-- trade, marks and the rest are the game's own rows above. `context`: the game's, { unit, which }.
local function Extend(_, root, context)
	if not T.db.emotes then return end
	local unit = type(context) == "table" and context.unit
	if type(unit) ~= "string" then return end
	-- Unit functions can error on a unit the frame still names, hence the pcall.
	local known, who = pcall(Who, unit)
	if not (known and who) then return end
	if not NAMED[context.which] then
		root:CreateButton("Copy their name", function() UI.ShowCopyBox("Their name", who.name) end)
	end
	root:CreateDivider()
	local quick = false
	if who.kind == "friend" or who.kind == "npc" then
		root:CreateButton("Thank", function() Emote(who, "THANK") end)
		quick = true
	end
	if who.kind ~= "enemy" then
		root:CreateButton("Wave", function() Emote(who, "WAVE") end)
		quick = true
	end
	local more = root:CreateButton(quick and "More emotes" or "Emote")
	for _, item in ipairs(Emotes(who)) do more:CreateButton(item.text, item.click) end
end

local started

function Unit.Start()
	if started then return end
	started = true
	for _, which in ipairs(MENUS) do Menu.ModifyMenu("MENU_UNIT_" .. which, Extend) end
end
