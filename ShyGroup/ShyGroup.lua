-- ShyGroup: recruiting tool for a group leader. Registration, shared helpers,
-- lifecycle and slash commands.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyGroup\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Group",
	icon = MEDIA .. "ShyGroup",
	smallIcon = MEDIA .. "ShyGroupSmall",
	tagline = "The Group Finder with the work done: pick a run, see who's listed, list yourself, whisper in one click",
	savedVariables = "ShyGroupDB",
	defaults = {
		-- {words} are filled in when sent (see Run.Fill)
		templates = {
			ask = "Hi {name}! Want to come along to {dungeon}?{group}",
			askRole = "Hi {name}! We're looking for {role} for {dungeon}, interested?{group}",
			askChoice = "Hi {name}! We're putting together {dungeon} and could use {roles}, whichever you'd like. Interested?{group}",
			askFlexible = "Hi {name}! We're putting together {dungeon}, want to come? What would you rather play, {choices}?{group}",
			post = "LFM {dungeon}, need {need}{tally}",
			join = "Hi {name}! Level {level} {class} here, any room in {dungeon}? I can {myroles}.",
		},
		-- One-click replies in a conversation; act: send | invite | pass
		-- Lines that need no context; the Replies tab adds the ones the run can tell.
		replies = {
			{ text = "Inviting you now!", act = "invite" },
			{ text = "We're starting in a few minutes, still in?", act = "send" },
			{ text = "Done this one before?", act = "send" },
			{ text = "Sorry, we just filled up. Good luck!", act = "pass" },
			{ text = "No worries, another time.", act = "pass" },
		},
		collect = "run",        -- whispers that land in Replies: run (while you have a run) | always
		autoInvite = false,     -- invite as soon as someone you asked says yes
		expire = 5,             -- minutes a chat post stays listed
		myLanguage = true,      -- leave out posts in a language you can't read
		skipChannels = {},      -- channel name -> true: don't read it
		postChannels = {},      -- channel name -> true/false: your post goes here; unset = only LookingForGroup
		extraWords = {},        -- dungeon key -> extra words players use for it
		playstyle = Enum.LFGEntryGeneralPlaystyle.FunRelaxed,   -- the style your listing carries
		friendly = false,       -- the listing says new players are welcome
		takeover = true,        -- the Group Finder's key and button open ShyGroup
		pill = true,            -- status box while the window is closed
		minimap = true,         -- a minimap button of its own, kept in the strip for quick access
		minimapAngle = 228,     -- degrees around the minimap
	},
})
ns.T = T

BINDING_HEADER_SHYGROUP = "ShyGroup"
BINDING_NAME_SHYGROUP_TOGGLE = "Toggle ShyGroup"

-- ns.Changed() redraws the screens once on the next frame.

local listeners, queued = {}, false

function ns.OnChange(fn) listeners[#listeners + 1] = fn end

local function Flush()
	queued = false
	for _, fn in ipairs(listeners) do fn() end
end

function ns.Changed()
	if queued then return end
	queued = true
	C_Timer.After(0, Flush)
end

-- Drops your own realm from a name; other realms are kept.
function ns.Short(name)
	return Ambiguate(name, "none")
end

-- Chat, Who and the Group Finder give "First Surname" as one string; a unit
-- returns the two separately. Joined here so names match. nil if secret.
function ns.FullName(unit)
	local name, surname = UnitNameUnmodified(unit)
	if issecretvalue(name) or issecretvalue(surname) or not name then return nil end
	if surname and surname ~= "" then
		return name .. Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR .. surname
	end
	return name
end

function ns.Me()
	return ns.FullName("player") or ""
end

function ns.Ago(t)
	local s = math.max(0, time() - t)
	if s < 45 then return "now" end
	if s < 3600 then return math.floor(s / 60 + 0.5) .. "m" end
	return math.floor(s / 3600 + 0.5) .. "h"
end

function T:Apply()
	ns.Parse.Rebuild(self.db.extraWords)
	ns.Changed()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- The wordings 1.1.0 shipped with, replaced by the new ones where never edited.
local SHIPPED = {
	ask = "Hi! Want to join us for {dungeon}? We're {count}/{size}.",
	askRole = "Hi! We need a {role} for {dungeon} - want to join? We're {count}/{size}.",
	post = "LFM {dungeon} - need {need} ({count}/{size})",
	join = "Hi! Level {level} {class} here - room for one more in {dungeon}?",
}

function T:OnLoad()
	for key, old in pairs(SHIPPED) do
		if self.db.templates[key] == old then self.db.templates[key] = self.defaults.templates[key] end
	end
	ShyGroupCharDB = ShyGroupCharDB or {}
	-- kind: the Group Finder category in view (dungeon | raid | zone | custom)
	ns.char = Shy.MergeDefaults(ShyGroupCharDB, { people = {}, open = false, tab = 1, kind = "dungeon" })
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.Data.Init()
	ns.Parse.Rebuild(self.db.extraWords)
	ns.Run.Init()
	ns.People.Init()
	ns.Board.Init()
	ns.Search.Init()
	ns.Window.Init()
	ns.Pill.Init()
	ns.Listing.Init()
	ns.Changed()
end

-- From the hub and the minimap menu: a click.
function T:OpenWindow()
	ns.Window.SetOpen(true, nil, true)
end

-- Another addon asks for a group: for a dungeon, by instance map ID, or for something of its own
-- (ShyQuest's group quests: `want` = { name, quest, zone, size }), as a run named after it.
Shy:On("SHY_GROUP_WANTED", function(map, want)
	if not ns.Window then return end
	local run = ns.Run.Get()
	local d = map and ns.Data.byMap[map]
	if d then
		if not run or run.key ~= d.key then ns.Run.Start(d.key) end
	elseif want and want.name then
		if not run or run.key ~= "custom" or run.name ~= want.name then
			ns.Run.Start("custom", want.name)
			run = ns.Run.Get()
			if want.size and want.size > 1 then run.size = want.size end
		end
	else
		return
	end
	ns.Window.SetOpen(true, 1)
end)

-- The key binding and the slash command: both hardware events.
function ShyGroup_Toggle()
	ns.Window.SetOpen(not ns.char.open, nil, true)
end

SLASH_SHYGROUP1 = "/shygroup"
SLASH_SHYGROUP2 = "/sg"
SlashCmdList.SHYGROUP = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		ShyGroup_Toggle()
	elseif cmd == "options" or cmd == "config" then
		T:OpenOptions()
	elseif cmd == "stop" or cmd == "done" then
		ns.Run.Stop()
		T:Print("run finished.")
	else
		T:Print("commands:")
		print("  /shygroup  - open or close the window")
		print("  /shygroup options  - open the options")
		print("  /shygroup done  - finish the current run")
	end
end
