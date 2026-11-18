-- ShyKeys: a class's keys laid out once for every level, and the hotkeys to press them with. A class addon
-- gives its jobs (ShyPaladin's Keys.lua, and one for every other class); this lays them out the same way for
-- all of them. Keys.lua is the whole of it; this registers the addon and keeps its settings.
--
-- Switched off, nothing of a layout happens: a class addon's own keys file does nothing without Shy.Keys, the
-- /shy window has no Keys room, and the keys and buttons you have are left exactly as they are.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyKeys\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Keys",
	category = "interface",
	icon = MEDIA .. "ShyKeys",
	smallIcon = MEDIA .. "ShyKeysSmall",
	savedVariables = "ShyKeysDB",
	-- The keys you keep, where what a key did goes, and the log: yours, not a setting a profile carries.
	keep = { hotkeys = true, keysLog = true, keysOwn = true },
	defaults = {},
})
ns.T = T

-- The core kept these while the keys were part of it. They come across once, so a character's layout, the keys
-- you keep, where what each did went and the way you move are all exactly as they were.
local MOVED = { "hotkeys", "keysMove", "keysGuide", "keysLog" }

local function Inherit(from, to)
	if not (from and to) then return end
	for _, name in ipairs(MOVED) do
		if to[name] == nil and from[name] ~= nil then to[name] = from[name] end
		from[name] = nil
	end
end

function T:OnLoad()
	if self.db.keysOwn then return end
	self.db.keysOwn = true
	Inherit(Shy.core.db, self.db)
	-- (and every profile's copy, so a character on another profile still moves the way it did)
	for _, profile in pairs(ShyCoreDB and ShyCoreDB.profiles or {}) do
		local data = profile.data
		if data and data.ShyCore then
			data.ShyKeys = data.ShyKeys or {}
			Inherit(data.ShyCore, data.ShyKeys)
		end
	end
end

function T:OpenWindow()
	Shy.Hub.Open("keys")
end

SLASH_SHYKEYS1 = "/shykeys"
SlashCmdList.SHYKEYS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		Shy.Hub.Open("keys")
	elseif cmd == "guide" then
		Shy.Keys.ShowGuide(not Shy.Keys.GuideShown())
	elseif cmd == "why" then
		Shy.UI.ShowCopyBox("Your keys", Shy.Keys.Report())
	else
		T:Print("commands:")
		print("  /shykeys  - your keys, and what comes to them as you level")
		print("  /shykeys guide  - how to play at your level, on screen or put away")
		print("  /shykeys why  - why each of your keys is where it is")
	end
end
