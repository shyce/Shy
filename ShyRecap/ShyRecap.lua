-- ShyRecap: a death recap that persists after release. Settings, text helpers and the death history.
-- Settings are in ShyRecapDB (per profile); deaths in ShyRecapCharDB (per character, last 20).
--
-- API, as Shy.addons.Recap:
--   :IsOn()       recording deaths
--   :Latest()     newest death record or nil (fields: Death.lua)
--   :ShareText(death, spot)   the line said in chat for a death; `spot` ("45, 62") follows the place
--                 (the record's own spot when not given)
--   :Open()       show the last death's line; false when there is none
--   :Test()       show a sample death

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyRecap\\Media\\"
local UI = Shy.UI
local C = UI.colors

local T = Shy:NewAddon(ADDON, {
	suffix = "Recap",
	icon = MEDIA .. "ShyRecap",
	smallIcon = MEDIA .. "ShyRecapSmall",
	tagline = "Who killed you, how long ago and how",
	savedVariables = "ShyRecapDB",
	defaults = {
		on = true,
		stay = "closed",     -- "closed" (until closed) | "alive" (until alive again)
		creatures = true,    -- show PvE and environmental deaths too
	},
})
ns.T = T

ns.KEEP = 20   -- deaths kept for a character

function T:IsOn()
	return self.db ~= nil and self.db.on == true
end

-- A settings change reruns every function registered with ns.OnApply.
local appliers = {}
function ns.OnApply(fn)
	appliers[#appliers + 1] = fn
end

function ns.Apply()
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Text

-- "just now", "12 min ago", "1 h 20 min ago", "7 h ago", "3 days ago"
function ns.Ago(at, now)
	local seconds = math.max(0, (now or time()) - at)
	if seconds < 60 then return "just now" end
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then return minutes .. " min ago" end
	local hours = math.floor(minutes / 60)
	if hours < 24 then
		local rest = minutes % 60
		if hours < 6 and rest > 0 then return ("%d h %d min ago"):format(hours, rest) end
		return hours .. " h ago"
	end
	local days = math.floor(hours / 24)
	return days == 1 and "1 day ago" or days .. " days ago"
end

-- "8:45 pm", or "20:45" with the 24-hour clock setting.
function ns.Clock(at)
	if GetCVarBool("timeMgrUseMilitaryTime") then return date("%H:%M", at) end
	local hour = tonumber(date("%H", at))
	return ("%d:%s %s"):format((hour - 1) % 12 + 1, date("%M", at), hour < 12 and "am" or "pm")
end

function ns.Day(at)
	return date("%Y%m%d", at)
end

-- "2nd", "3rd", "11th"
function ns.Nth(n)
	local tens, ones = n % 100, n % 10
	if tens >= 11 and tens <= 13 then return n .. "th" end
	return n .. (ones == 1 and "st" or ones == 2 and "nd" or ones == 3 and "rd" or "th")
end

-- Environmental deaths: { headline, chat text }.
local WORLD = {
	FALLING = { "You fell to your death", "Fell to my death" },
	DROWNING = { "You drowned", "Drowned" },
	FATIGUE = { "You died of fatigue", "Died of fatigue" },
	FIRE = { "You burned to death", "Burned to death" },
	LAVA = { "You died in lava", "Died in lava" },
	SLIME = { "You died in slime", "Died in slime" },
}

-- Class color for a player, hostile red for a creature.
local classColors = {}
function ns.NameColor(a)
	if a.class then
		local c = classColors[a.class]
		if c == nil then
			local color = C_ClassColor.GetClassColor(a.class)
			c = color and { color.r, color.g, color.b } or false
			classColors[a.class] = c
		end
		if c then return c end
	end
	if a.player == false then return C.bad end
	return C.text
end

local function Level(level)
	return level > 0 and tostring(level) or "??"   -- a skull-level unit is -1
end

-- "14 Orc Rogue", "Level 6 creature", or "" when only the name is known.
function ns.Describe(a)
	if a.player then
		local parts = {}
		if a.level then parts[#parts + 1] = Level(a.level) end
		if a.race then parts[#parts + 1] = a.race end
		if a.classText then parts[#parts + 1] = a.classText end
		return table.concat(parts, " ")
	elseif a.player == false then
		return a.level and ("Level %s creature"):format(Level(a.level)) or "A creature"
	end
	return ""
end

function ns.Killer(death)
	if death.killed then return death.who[1] end
end

-- Returns text, color, number of other attackers, and the verb after a name (nil after a sentence).
function ns.Headline(death)
	local killer = ns.Killer(death)
	if killer then return killer.name, ns.NameColor(killer), #death.who - 1, "killed you" end
	local world = death.env and WORLD[death.env]
	return world and world[1] or "You died", C.text, 0, nil
end

-- Short name for a death in a list: the killer, or the environmental damage type.
function ns.Short(death)
	local killer = ns.Killer(death)
	if killer then return killer.name, ns.NameColor(killer) end
	local word = death.env and _G["ACTION_ENVIRONMENTAL_DAMAGE_" .. death.env]
	return word or "Unknown", C.dim
end

function ns.Place(death)
	if death.sub and death.sub ~= "" then return death.sub, "at" end
	if death.zone and death.zone ~= "" then return death.zone, "in" end
end

-- Where it happened, for a map pin: map, x, y as shares of it (nil for an older record, or a dungeon).
function ns.Where(death)
	if death.map and death.x and death.y then return death.map, death.x, death.y end
end

-- `spot` ("45, 62") follows the place; the record's own when not given.
function ns.ShareText(death, spot)
	if not spot and death.x and death.y then spot = ("%.0f, %.0f"):format(death.x * 100, death.y * 100) end
	local killer = ns.Killer(death)
	local world = death.env and WORLD[death.env]
	local text = "Died"
	if killer then
		text = "Killed by " .. killer.name
		local line = ns.Describe(killer)
		if line ~= "" then text = text .. " (" .. line .. ")" end
		local others = #death.who - 1
		if others == 1 then
			text = text .. " and " .. death.who[2].name
		elseif others > 1 then
			text = text .. " and " .. others .. " others"
		end
	elseif world then
		text = world[2]
	end
	local place, how = ns.Place(death)
	if place then text = text .. " " .. how .. " " .. place end
	if spot then text = text .. " (" .. spot .. ")" end
	return text .. ", " .. ns.Ago(death.at)
end

function ns.Share(death)
	if not death then return end
	local text = ns.ShareText(death)
	local map, x, y = ns.Where(death)
	local link = map and UI.PinLink(map, x, y)
	if link then text = text .. " " .. link end
	local editBox = ChatFrameUtil.GetActiveWindow()
	if editBox then editBox:Insert(text) else ChatFrameUtil.OpenChat(text) end
end

-- History

function ns.Latest()
	return ns.char.deaths[1]
end

function ns.Keep(death)
	local deaths = ns.char.deaths
	table.insert(deaths, 1, death)
	while #deaths > ns.KEEP do table.remove(deaths) end
end

-- Same killer: a player by GUID, a creature by name (every spawn has its own GUID).
local function KillerKey(death)
	local killer = ns.Killer(death)
	if not killer then return nil end
	return killer.player and killer.guid or killer.name
end

-- { death, again, earlier }: `again` is the killer's kill count that day (nil for the first),
-- `earlier` the day's previous deaths, newest first, two at most.
function ns.View(death)
	local day, key = ns.Day(death.at), KillerKey(death)
	local again, earlier = 1, {}
	for _, other in ipairs(ns.char.deaths) do
		if other ~= death and other.at <= death.at and ns.Day(other.at) == day then
			if #earlier < 2 then earlier[#earlier + 1] = other end
			if key and KillerKey(other) == key then again = again + 1 end
		end
	end
	return { death = death, again = again > 1 and again or nil, earlier = earlier }
end

-- With "creatures" off, only deaths to players show, and deaths with no named killer (it may be a player).
function ns.Wanted(death)
	if T.db.creatures then return true end
	if death.env then return false end
	local killer = ns.Killer(death)
	return not killer or killer.player ~= false
end

-- Loading

function T:Latest() return ns.Latest() end
function T:ShareText(death, spot) return ns.ShareText(death, spot) end
function T:Open() return ns.Open() end
function T:Test() ns.Test() end

function T:OnLoad()
	ShyRecapCharDB = ShyRecapCharDB or {}
	ns.char = ShyRecapCharDB
	if type(ns.char.deaths) ~= "table" then ns.char.deaths = {} end
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.Seen.Start()
	ns.Blows.Start()
	ns.SetupLine()
	ns.Death.Start()
end

SLASH_SHYRECAP1 = "/shyrecap"
SLASH_SHYRECAP2 = "/srecap"
SlashCmdList.SHYRECAP = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		if not ns.Open() then T:OpenOptions() end
	elseif cmd == "options" then
		T:OpenOptions()
	elseif cmd == "test" then
		ns.Test()
	elseif cmd == "raw" then
		UI.ShowCopyBox("ShyRecap: raw data for your last death", ns.Death.RawText())
	else
		T:Print("commands:")
		print("  /shyrecap  - show your last death again")
		print("  /shyrecap options  - open options")
		print("  /shyrecap test  - show a sample death")
		print("  /shyrecap raw  - raw data for your last death, to copy")
	end
end
