-- What you gain, written like a blow's number: experience, reputation, coin looted, a skill gone up,
-- honor. What comes of a kill rises from over the unit that fell, a moment after the blow that killed
-- it; anything else stands by your character.
-- Experience is read from your own bar (PLAYER_XP_UPDATE) and written only while the game's own text
-- over a unit is off (Feed.OwnsXP), so it is never said twice; it is also the word that a unit died.
-- Coin is what you carry more of when the game says you looted some. The rest is read from the game's
-- own lines, by patterns made of its strings. A payload the game keeps back is left out.

local ADDON, ns = ...
local T, Stage, Where, Feed = ns.T, ns.Stage, ns.Where, ns.Feed
local UI = Shy.UI
local Secret = issecretvalue

local G = {}
ns.Gains = G

-- A gain's color says what it is; never the accent. Reputation is the palette's good and bad.
G.COLOR = {
	xp    = { 0.80, 0.62, 1.00 },
	coin  = { 1.00, 0.86, 0.36 },
	skill = { 0.52, 0.74, 1.00 },
	honor = { 1.00, 0.64, 0.28 },
}
-- The lesser kinds: lit less than the experience beside them.
G.LESSER = { rep = true, loss = true, coin = true, skill = true, honor = true }
-- The setting each kind goes by.
G.KEY = { xp = "gainXP", rep = "gainRep", loss = "gainRep", coin = "gainCoin", skill = "gainSkill", honor = "gainHonor" }
G.AFTER = 0.3        -- seconds a kill's gains wait, so the blow that killed is seen first
local WORD = 0.74    -- a gain's word beside its number: this share of its color's light
local NEAR = 1       -- seconds within which more coin in hand and the game's word of loot are one thing

-- A word in a color, dimmer than the number it stands by.
local function Word(color, word)
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(color[1] * WORD * 255), math.floor(color[2] * WORD * 255),
		math.floor(color[3] * WORD * 255), word)
end

-- Writes a gain in a lane, `wait` seconds from now. `amount`: a number; `name`: whose (a faction, a skill).
function G.Show(kind, amount, name, lane, wait)
	local color = kind == "rep" and UI.colors.good or kind == "loss" and UI.colors.bad or G.COLOR[kind]
	local text
	if kind == "xp" then
		text = "+" .. amount .. " " .. Word(color, XP)
	elseif kind == "rep" then
		text = "+" .. amount .. " " .. Word(color, name)
	elseif kind == "loss" then
		text = "-" .. amount .. " " .. Word(color, name)
	elseif kind == "coin" then
		text = "+" .. C_CurrencyInfo.GetCoinTextureString(amount)
	elseif kind == "skill" then
		text = Word(color, name) .. " " .. amount
	else
		text = "+" .. amount .. " " .. Word(color, HONOR)
	end
	local function Add()
		if T:IsOn() then Stage.Add(lane, G.LESSER[kind] and "note" or "gain", nil, color[1], color[2], color[3], "%s", text) end
	end
	if wait and wait > 0 and T.db.motion ~= "calm" then C_Timer.After(wait, Add) else Add() end
end

-- A gain the game told of: where it belongs, and when.
local function Gained(kind, amount, name)
	if not (T:IsOn() and T.db[G.KEY[kind]]) then return end
	local lane, pair = Where.Gain(kind ~= "skill")
	G.Show(kind, amount, name, lane, pair and G.AFTER or 0)
end

-- Experience

local xp, xpMax

local function Experience(quiet)
	local is, max = UnitXP("player"), UnitXPMax("player")
	-- (Zoning, the game can say there is none to be had for a moment: the last reading stands.)
	if Secret(is) or Secret(max) or type(is) ~= "number" or type(max) ~= "number" or max <= 0 then return end
	local was, wasMax = xp, xpMax
	xp, xpMax = is, max
	if quiet or not was then return end
	local gained = is - was
	-- Less than there was: a level gained, so what was left of it and this much of the next. (Anything
	-- that would be more than a whole level is a reading gone wrong, and is not told.)
	if gained < 0 then gained = gained + wasMax end
	if gained <= 0 or gained > wasMax then return end
	-- Experience just after a blow on a unit: that unit died of it.
	local _, pair = Where.Gain(true)
	if pair then Where.Slain(pair) end
	if Feed.OwnsXP() then Gained("xp", gained) end
end

-- Coin

local coin, looted, owed, owedAt

local function Coin()
	local is = GetMoney()
	if Secret(is) or type(is) ~= "number" then return end
	local more = coin and is - coin or 0
	coin = is
	if more <= 0 then return end
	local now = GetTime()
	if looted and now - looted <= NEAR then
		looted = nil
		Gained("coin", more)
	else
		owed, owedAt = more, now   -- (it may be loot the game hasn't said yet; a sale or a letter is never said)
	end
end

local function Looted()
	local now = GetTime()
	if owed and now - owedAt <= NEAR then
		Gained("coin", owed)
		owed = nil
	else
		looted = now
	end
end

-- The game's lines

-- A line's pattern from the string the game makes it of: its %s and %d taken out as captures. Not held to
-- the line's end, so a line with a bonus said after it reads the same.
local function Pattern(made)
	local p = made:gsub("%%%d+%$", "%%")                       -- (an argument's place, in other languages)
	p = p:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	p = p:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
	return "^" .. p
end

local lines   -- event -> { { pattern, kind }, ... }

-- What a line says: the number among what it captured (the last), and the name (the first that isn't one).
local function Read(text, pattern)
	local a, b, c, d = text:match(pattern)
	if not a then return nil end
	local amount, name
	for _, part in ipairs({ a, b, c, d }) do
		if part:match("^%d+$") then amount = tonumber(part) elseif not name then name = part end
	end
	return amount, name
end

-- A faction you can't see: in your reputation list only as a heading with no standing of its own (a
-- whole side, whose cities gain with it).
local function Unseen(name)
	for i = 1, C_Reputation.GetNumFactions() do
		local faction = C_Reputation.GetFactionDataByIndex(i)
		if faction and faction.name == name then return faction.isHeader and not faction.isHeaderWithRep end
	end
	return false
end

local function Line(event, text)
	if Secret(text) or type(text) ~= "string" then return end
	for _, line in ipairs(lines[event]) do
		local amount, name = Read(text, line[1])
		if amount then
			if amount > 0 and not (name and G.KEY[line[2]] == "gainRep" and Unseen(name)) then Gained(line[2], amount, name) end
			return
		end
	end
end

function G.Start()
	lines = {
		CHAT_MSG_COMBAT_FACTION_CHANGE = {
			{ Pattern(FACTION_STANDING_INCREASED), "rep" },
			{ Pattern(FACTION_STANDING_DECREASED), "loss" },
		},
		CHAT_MSG_SKILL = { { Pattern(SKILL_RANK_UP), "skill" } },
		CHAT_MSG_COMBAT_HONOR_GAIN = {
			{ Pattern(COMBATLOG_HONORGAIN), "honor" },
			{ Pattern(COMBATLOG_HONORGAIN_NO_RANK), "honor" },
			{ Pattern(COMBATLOG_HONORAWARD), "honor" },
		},
	}
	local events = CreateFrame("Frame")
	for event in pairs(lines) do events:RegisterEvent(event) end
	for _, event in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "CHAT_MSG_MONEY" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, text)
		if lines[event] then
			Line(event, text)
		elseif event == "PLAYER_XP_UPDATE" then
			Experience()
		elseif event == "PLAYER_MONEY" then
			Coin()
		elseif event == "CHAT_MSG_MONEY" then
			Looted()
		else
			Experience(true)   -- a new place: what you have is read, not told
			coin = nil
			Coin()
		end
	end)
	Experience(true)
	Coin()
	Where.Sample(Where.You().gain, "BOTTOM", "+120 " .. XP, G.COLOR.xp)
end
