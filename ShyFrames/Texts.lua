-- The frame texts: name, health, class line, power and druid mana.
-- Each Write function has a secret-value path that compares and cuts nothing:
--   Name    the whole name through SetFormattedText; the font string's width truncates it.
--   Health  separate font strings in a row, colored and faded by curves on UnitHealthPercent.
--   Class   the race or creature type formatted in unread.
--   Power   the raw number, colored and hidden at 100% by a curve on UnitPowerPercent.
--   Druid   empty.

local ADDON, ns = ...
local Units = ns.Units

local T = {}
ns.Texts = T

local Secret, Hex, Num, Short = Units.Secret, Units.Hex, Units.Num, Units.Short

local function Paint(hex, text)
	return "|cff" .. hex .. text .. "|r"
end

-- Name

-- A name over `limit` characters keeps its last word and the initials of the rest:
-- "Lieutenant General Andorov" -> "LG. Andorov". One long word is cut to the limit.
function T.NameText(name, raidGroup, limit)
	local text = Shy.UI.ShortName(name, limit)
	if raidGroup then return text .. " " .. raidGroup end
	return text
end

local SEPARATOR = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

-- The bar's color says who it is, so every name is one light ink.
T.INK = { 0.957, 0.941, 0.906 }
T.GONE = { 0.55, 0.54, 0.51 }      -- dead or offline

-- Dead and offline are never secret. A name is inked on every change of health: told only when it changes.
function T.InkName(fs, unit)
	local ink = (UnitIsDeadOrGhost(unit) or Units.Offline(unit)) and T.GONE or T.INK
	if fs.shyInk == ink then return end
	fs.shyInk = ink
	fs:SetTextColor(ink[1], ink[2], ink[3])
end

-- A name cut to its frame, kept by limit, raid group and name: working it out takes a dozen strings.
local cut, cutCount = {}, 0
local function Cut(name, group, limit)
	local key = limit .. (group and (":" .. group) or "") .. ":" .. name
	local text = cut[key]
	if not text then
		if cutCount >= 400 then
			cut, cutCount = {}, 0
		end
		text = T.NameText(name, group, limit)
		cut[key], cutCount = text, cutCount + 1
	end
	return text
end

-- Plain text told only when it differs from what the font string was last told here; a secret is always told.
local function Say(fs, text)
	if fs.shySaid == text then return end
	fs.shySaid = text
	fs:SetText(text)
end
local function SayFormatted(fs, ...)
	fs.shySaid = nil
	fs:SetFormattedText(...)
end

-- `first`: the first name alone, for a frame too narrow for both.
function T.WriteName(fs, unit, limit, first)
	T.InkName(fs, unit)
	if first then
		local given = UnitName(unit)
		if Secret(given) then
			SayFormatted(fs, "%s", given)
		else
			Say(fs, given and Units.Sub(given, 1, limit) or "")
		end
		return
	end
	local name, surname, secret = Units.Name(unit)
	local group = Units.RaidGroup()
	if secret then
		-- Secret: formatted in unread, first name and surname if there is one.
		local pattern = "%s"
		local both = Secret(surname) or (surname ~= nil and surname ~= "")
		if both then pattern = "%s" .. SEPARATOR .. "%s" end
		if group then pattern = pattern .. " " .. group end
		if both then SayFormatted(fs, pattern, name, surname) else SayFormatted(fs, pattern, name) end
	else
		Say(fs, name and Cut(name, group, limit) or "")
	end
end

-- A sample member's name and health (the test party: `s` = { name, hp, max }), written as a party member's are:
-- the first name cut to `limit`, and what is missing.
function T.WriteSample(name, segs, s, limit)
	if name.shyInk ~= T.INK then
		name.shyInk = T.INK
		name:SetTextColor(T.INK[1], T.INK[2], T.INK[3])
	end
	Say(name, Units.Sub(s.name, 1, limit))
	T.WriteSampleHealth(segs, s)
end

-- Health: "current/max" on your own frame, "missing | percent" on a friend, "current | percent" on anything else.
-- What you have is bone, warm when low; the most is dimmed; what is missing is soft red.

local BONE, DIM, LOST, LOW = "ece8de", "b7b3a8", "ff6b61", "ffb08a"
local LOW_AT = 0.35   -- under this share of health the number turns warm
local DEAD, OFFLINE, RAISED = Paint("ff7a5c", "Dead"), Paint("9b9b9b", "Offline"), Paint("ffcf61", "Being raised")
local BAR = Paint(DIM, "||")

-- s: { hp, max, dead, offline, friend, own, rez, short }. Not a friend includes neutral.
-- `short` says only what is missing; `rez`: someone is raising them.
function T.HealthText(s)
	local hp, max = s.hp, s.max
	local missing = max - hp
	local ink = hp / max < LOW_AT and LOW or BONE
	local percent = Num(Units.Percent(hp, max)) .. "%"
	local parts = {}
	if s.dead then parts[#parts + 1] = s.rez and RAISED or DEAD end
	if s.offline then parts[#parts + 1] = OFFLINE end
	if s.short then
		if not s.dead and not s.offline and missing ~= 0 then parts[#parts + 1] = Paint(LOST, Short(-missing)) end
		return table.concat(parts, " ")
	end
	if not s.dead and s.friend and missing ~= 0 then
		parts[#parts + 1] = Paint(LOST, Short(-missing))
		parts[#parts + 1] = BAR
	end
	if not s.dead then
		local last = ""
		if s.own then last = Paint(ink, Short(hp)) .. Paint(DIM, "/" .. Short(max)) end
		if s.friend and not s.own then last = last .. Paint(ink, percent) end
		if not s.friend then last = last .. Paint(ink, Units.VeryShort(hp)) .. " " .. BAR .. " " .. Paint(ink, percent) end
		parts[#parts + 1] = last
	end
	return table.concat(parts, " ")
end

local function Rgb(hex)
	return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- Curves the game evaluates on a secret percent.
local curves
local function Curves()
	if curves then return curves end
	local function Color(points)
		local curve = C_CurveUtil.CreateColorCurve()
		curve:SetType(Enum.LuaCurveType.Linear)
		for _, p in ipairs(points) do curve:AddPoint(p[1], CreateColor(p[2], p[3], p[4], p[5] or 1)) end
		return curve
	end
	local hurt = C_CurveUtil.CreateCurve()
	hurt:SetType(Enum.LuaCurveType.Linear)
	hurt:AddPoint(0, 1)
	hurt:AddPoint(0.9999, 1)
	hurt:AddPoint(1, 0)
	local lr, lg, lb = Rgb(LOW)
	local br, bg, bb = Rgb(BONE)
	curves = {
		-- Matches T.HealthText: warm under LOW_AT, bone from there.
		ink = Color({ { 0, lr, lg, lb }, { LOW_AT - 0.0001, lr, lg, lb }, { LOW_AT, br, bg, bb }, { 1, br, bg, bb } }),
		hurt = hurt,                                                              -- 1 while health is missing, 0 at full
		power = Color({                                                           -- matches T.PowerText's steps
			{ 0, 1, 0, 0 }, { 0.3499, 1, 0, 0 }, { 0.35, 1, 1, 0 }, { 0.70, 1, 1, 0 },
			{ 0.7001, 0, 128 / 255, 0 }, { 0.9999, 0, 128 / 255, 0 }, { 1, 0, 128 / 255, 0, 0 },
		}),
	}
	return curves
end

-- A curve's color as numbers for a setter; white if it isn't a readable color table.
local function Unpack(color)
	if Secret(color) or type(color) ~= "table" then return 1, 1, 1, 1 end
	return color.r, color.g, color.b, color.a
end

-- Every health event writes every piece: one already showing the same plain text, color and alpha is left
-- alone. A secret or formatted piece is always told, and forgets what it held.
local function Segment(fs, r, g, b, alpha, text, ...)
	if select("#", ...) > 0 then
		SayFormatted(fs, text, ...)
	elseif Secret(text) then
		fs.shySaid = nil
		fs:SetText(text)
	else
		Say(fs, text)
	end
	if Secret(r, g, b) then
		fs.shyR = nil
		fs:SetTextColor(r, g, b)
	elseif fs.shyR ~= r or fs.shyG ~= g or fs.shyB ~= b then
		fs.shyR, fs.shyG, fs.shyB = r, g, b
		fs:SetTextColor(r, g, b)
	end
	if Secret(alpha) then
		fs.shyAlpha = nil
		fs:SetAlpha(alpha)
	elseif fs.shyAlpha ~= alpha then
		fs.shyAlpha = alpha
		fs:SetAlpha(alpha)
	end
end

local reading = {}   -- T.HealthText's question, asked again on every health event

-- A sample member's health in a party cell's words: what is missing.
function T.WriteSampleHealth(segs, s)
	for i = 2, #segs do Segment(segs[i], 1, 1, 1, 1, "") end
	local words = reading
	words.hp, words.max, words.dead, words.offline, words.friend, words.own, words.rez, words.short = s.hp, s.max, false, false, true, false, false, true
	Segment(segs[1], 1, 1, 1, 1, T.HealthText(words))
end

-- segs: font strings in a row, [1] at the right end. One string when readable, one piece each when secret.
-- `short`: only what is missing (see T.HealthText).
function T.WriteHealth(segs, unit, short)
	local hp, max, secret = Units.Health(unit)
	local dead, offline, friend = UnitIsDeadOrGhost(unit), Units.Offline(unit), Units.IsFriend(unit)
	local own = unit == "player"
	local rez = dead and UnitHasIncomingResurrection(unit)
	if Secret(rez) then rez = false end
	for i = 2, #segs do Segment(segs[i], 1, 1, 1, 1, "") end
	if not secret then
		local s = reading
		s.hp, s.max, s.dead, s.offline, s.friend, s.own, s.rez, s.short = hp, max, dead, offline, friend, own, rez, short
		Segment(segs[1], 1, 1, 1, 1, T.HealthText(s))
		return
	end

	-- Dead and offline are never secret.
	if dead then
		local word = rez and RAISED or DEAD
		Segment(segs[1], 1, 1, 1, 1, offline and word .. " " .. OFFLINE or word)
		return
	end
	local c = Curves()
	local r, g, b = Unpack(UnitHealthPercent(unit, true, c.ink))
	local dr, dg, db = Rgb(DIM)
	local lr, lg, lb = Rgb(LOST)
	local n = 1
	local function Next(...)   -- the next piece to the left
		Segment(segs[n], ...)
		n = n + 1
	end
	if short then
		if offline then
			Next(1, 1, 1, 1, OFFLINE)
		elseif friend then
			Next(lr, lg, lb, UnitHealthPercent(unit, true, c.hurt), "-%s", AbbreviateNumbers(UnitHealthMissing(unit, true)))
		end
		return
	end
	local percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
	if own then
		Next(dr, dg, db, 1, AbbreviateNumbers(max))
		Next(dr, dg, db, 1, "/")
		Next(r, g, b, 1, AbbreviateNumbers(hp))
	elseif friend then
		Next(r, g, b, 1, "%.0f%%", percent)
	else
		Next(r, g, b, 1, "%.0f%%", percent)
		Next(dr, dg, db, 1, " | ")
		Next(r, g, b, 1, AbbreviateNumbers(hp))
	end
	if friend then
		local hurt = UnitHealthPercent(unit, true, c.hurt)
		Next(dr, dg, db, hurt, "| ")
		Next(lr, lg, lb, hurt, "-%s ", AbbreviateNumbers(UnitHealthMissing(unit, true)))
	end
	if offline then Next(1, 1, 1, 1, OFFLINE .. " ") end
end

T.SEGMENTS = 6   -- the most pieces WriteHealth ever uses

-- Class line: classification, level, druid form, race or creature type

function T.ClassText(classification, level, r, g, b, form, race)
	local text = (classification and classification .. " " or "") .. Paint(Hex(r, g, b), level) .. " "
		.. (form and "(" .. form .. ") " or "") .. (race or "")
	return (text:gsub("%s$", ""))
end

function T.WriteClass(fs, unit)
	local level, r, g, b = Units.Level(unit)
	local race, secret = Units.Race(unit)
	local text = T.ClassText(Units.Classification(unit), level, r, g, b, Units.DruidForm(unit), not secret and race or nil)
	if secret then
		fs:SetFormattedText(text:gsub("%%", "%%%%") .. " %s", race)
	else
		fs:SetText(text)
	end
end

-- Power: hidden at 100%, green above 70%, yellow above 35%, red below

function T.PowerText(power, max)
	local percent = Units.Percent(power, max)
	if percent == 100 then return "" end
	if percent > 70 then return Paint("008000", Num(power)) end
	if percent > 35 then return Paint("ffff00", Num(power)) end
	if percent < 35 then return Paint("ff0000", Num(power)) end
	return ""
end

function T.WritePower(fs, unit)
	local power, max, secret = Units.Power(unit)
	if not secret then
		fs:SetText(T.PowerText(power, max))
		fs:SetTextColor(1, 1, 1, 1)
		return
	end
	fs:SetFormattedText("%s", power)
	fs:SetTextColor(Unpack(UnitPowerPercent(unit, nil, false, Curves().power)))
end

-- Druid mana: on a druid's own frame while shapeshifted

function T.WriteDruid(fs)
	local mana, max = UnitPower("player", Enum.PowerType.Mana), UnitPowerMax("player", Enum.PowerType.Mana)
	if Secret(mana, max) then
		fs:SetText("")
	else
		fs:SetText(Num(mana) .. "/" .. Num(max))
	end
end
