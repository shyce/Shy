-- Registration, defaults, presets, the settings ShyChat takes over from the game, and slash commands.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyChat\\Media\\"
ns.MEDIA = MEDIA

local T = Shy:NewAddon(ADDON, {
	suffix = "Chat",
	icon = MEDIA .. "ShyChat",
	smallIcon = MEDIA .. "ShyChatSmall",
	tagline = "Cleaner, more compact chat",
	savedVariables = "ShyChatDB",
	defaults = {
		enabled = true,          -- rewrite chat lines
		-- channels
		channelStyle = "short",  -- short | number | numshort | name | blizzard
		brackets = "square",     -- square | round | none
		channelNames = {},       -- channel name -> your short name
		typeNames = {},          -- chat type key -> your short name
		-- names
		classColors = true,
		hideRealm = true,
		nameBrackets = false,
		-- messages
		compact = true,          -- "Thrall says:" -> "Thrall:"
		compactLoot = true,      -- "You receive loot: [x]" -> "+ [x]"
		urls = true,
		hoverLinks = true,       -- item/spell tooltips when hovering links
		timestamps = "24",       -- none | 24 | 24s | 12 | 12s
		timeColor = { 0.55, 0.55, 0.58 },
		timeCopy = true,         -- click a timestamp to copy the line
		mentionName = true,
		keywords = "",
		mentionColor = { 1, 0.81, 0.38 },
		mentionSound = true,
		-- window
		font = "default",
		outline = "",
		shadow = true,
		spacing = 1,
		fade = true,
		fadeTime = 60,
		toolbar = "hover",       -- ShyChat's own buttons: show | hover | hide
		sidebar = "hide",        -- Blizzard's button column: show | hover | hide
		wheel = true,            -- Shift+wheel: top/bottom, Ctrl+wheel: page
		autoBottom = 0,          -- seconds before snapping back to the newest line; 0 = off
		arrowKeys = true,
		editSkin = true,         -- restyle the edit box
		windowSkin = true,       -- restyle the windows and tabs (opacity is Theme.Strength)
		move = true,             -- drag the restyled chat by its title strip, resize it by its corner
		-- bubbles
		bubbles = true,          -- chat bubbles in the hover's housing, class and kind shown
		bubbleNames = true,      -- the speaker's name on a plaque
		bubbleSize = 13,         -- text size (the game's is 13)
		-- whispers
		whispers = true,         -- each conversation in a window of its own
		whisperOpen = "window",  -- window: a new one, a step down and right of the last | tab: a blinking tab
		whisperFight = true,     -- the windows step aside in a fight
		whisperLines = 50,       -- lines kept per conversation
		maxLines = 300,
		history = true,
		historyLines = 100,
		spam = true,
		spamWindow = 30,
	},
})
ns.T = T

-- `font` is one file; `family` gives a font family per size and outline (every alphabet).
ns.FONTS = {
	{ value = "default",  text = "Nunito Sans", font = Shy.FONT_TEXT, family = Shy.UI.TextFont },
	{ value = "game",     text = "Game default" },
	{ value = "shy",      text = "Lilita One", font = Shy.FONT },
	{ value = "friz",     text = "Friz Quadrata",    font = "Fonts\\FRIZQT__.TTF" },
	{ value = "arialn",   text = "Arial Narrow",     font = "Fonts\\ARIALN.TTF" },
	{ value = "morpheus", text = "Morpheus",         font = "Fonts\\MORPHEUS.TTF" },
	{ value = "skurri",   text = "Skurri",           font = "Fonts\\SKURRI.TTF" },
}

ns.PRESETS = {
	{
		text = "Clean", desc = "Short tags, compact lines, timestamps. The default.",
		values = { channelStyle = "short", brackets = "square", nameBrackets = false, compact = true,
			compactLoot = true, timestamps = "24", toolbar = "hover", sidebar = "hide", fade = true, fadeTime = 60, spacing = 1 },
	},
	{
		text = "Minimal", desc = "No brackets, no timestamps, hidden buttons, quick fade.",
		values = { channelStyle = "short", brackets = "none", nameBrackets = false, compact = true,
			compactLoot = true, timestamps = "none", toolbar = "hide", sidebar = "hide", fade = true, fadeTime = 20, spacing = 2 },
	},
	{
		text = "Classic+", desc = "Channel numbers, bracketed names, default wording and button column.",
		values = { channelStyle = "number", brackets = "square", nameBrackets = true, compact = false,
			compactLoot = false, timestamps = "24s", toolbar = "hover", sidebar = "show", fade = false, spacing = 0 },
	},
}

function T:ApplyPreset(preset)
	for k, v in pairs(preset.values) do self.db[k] = v end
	self:Apply()
end

-- Default timestamps would double ours: off while ours are on, restored after.
local function SyncTimestamps(db)
	local theirs = GetCVar("showTimestamps")
	if db.timestamps ~= "none" then
		if theirs ~= "none" then
			db.savedBlizzardTimestamps = theirs
			SetCVar("showTimestamps", "none")
		end
	elseif db.savedBlizzardTimestamps then
		SetCVar("showTimestamps", db.savedBlizzardTimestamps)
		db.savedBlizzardTimestamps = nil
	end
end

-- "0" makes the game color every sender name by class.
local function SyncClassColors(db)
	local current = GetCVar("chatClassColorOverride")
	if db.classColors then
		if current ~= "0" then
			db.savedClassColors = current
			SetCVar("chatClassColorOverride", "0")
		end
	elseif db.savedClassColors then
		SetCVar("chatClassColorOverride", db.savedClassColors)
		db.savedClassColors = nil
	end
end

local rerenderQueued

-- Sliders fire many changes a second: re-render once they settle.
local function QueueRerender()
	if rerenderQueued then return end
	rerenderQueued = true
	C_Timer.After(0.15, function()
		rerenderQueued = false
		ns.Format.RerenderAll()
	end)
end

-- Another addon's message frame (the away board's chat) in the chat's face and spacing, kept so.
function T:Dress(frame)
	if self.db then ns.Window.Dress(frame) end
end

function T:Apply()
	local db = self.db
	SyncTimestamps(db)
	SyncClassColors(db)
	ns.Format.RebuildChannels()
	ns.Format.RebuildMentions()
	ns.Window.ApplyAll()
	if ns.Bubbles then ns.Bubbles.Apply() end
	if ns.Whispers then ns.Whispers.Apply() end
	QueueRerender()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Kit paint and formatted lines keep the colors they were made with.
Shy:On("SHY_THEME", function()
	if not T.db then return end
	ns.Look.Apply()
	if ns.Bubbles then ns.Bubbles.Apply() end
	QueueRerender()
	if ns.RefreshOptions then ns.RefreshOptions() end
end)

local lastSoundLine, lastSoundTime = nil, 0

-- A line can land in several windows: one sound per line.
function ns.OnMention(lineID)
	if not T.db.mentionSound or lineID == lastSoundLine then return end
	lastSoundLine = lineID
	if GetTime() - lastSoundTime < 3 then return end
	lastSoundTime = GetTime()
	PlaySound(SOUNDKIT.TELL_MESSAGE)
end

function T:OnLoad()
	ShyChatHistory = ShyChatHistory or {}
	-- (A report on the tabs was once kept with the settings: let go.)
	self.db.tabReport = nil
	ns.Format.Init(self.db)
	ns.Window.Init(self.db)
	-- The whisper windows can't take the rest of chat down with them.
	if ns.Whispers then
		local ok, err = pcall(ns.Whispers.Init, self.db)
		if not ok then
			geterrorhandler()(err)
			ns.Whispers = nil
		end
	end
	if ns.Bubbles then ns.Bubbles.Init(self.db) end
	self:RegisterOptions(ns.CreateOptions())

	local events = CreateFrame("Frame")
	events:RegisterEvent("CHANNEL_UI_UPDATE")
	events:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_LOGOUT")
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGOUT" then
			ns.Window.SaveHistory()
		else
			ns.Format.RebuildChannels()
		end
	end)
end

function T:OnLogin()
	ns.Window.SetupAll()
	ns.Window.RestoreHistory()
	self:Apply()
	if ns.Whispers then ns.Whispers.Restore() end
end

SLASH_SHYCHAT1 = "/shychat"
SLASH_SHYCHAT2 = "/schat"
SlashCmdList.SHYCHAT = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "copy" then
		-- The window whose tab was last selected, or the main one.
		local id = CURRENT_CHAT_FRAME_ID
		ns.Window.CopyFrame(id and _G["ChatFrame" .. id] or ChatFrame1)
	elseif cmd == "clearhistory" then
		ns.Window.ForgetHistory()
		T:Print("saved chat history cleared.")
	elseif cmd == "toggle" then
		T.db.enabled = not T.db.enabled
		T:Apply()
		T:Print("chat formatting " .. (T.db.enabled and "|cff40ff40on|r" or "|cffff4040off|r"))
	elseif cmd == "whispers" and ns.Whispers then
		Shy.UI.ShowCopyBox("Whisper windows", ns.Whispers.Report())
	elseif cmd == "" then
		T:OpenOptions()
	else
		T:Print("commands:")
		print("  /shychat  - open options")
		print("  /shychat copy  - copy the current chat window")
		print("  /shychat toggle  - turn chat formatting on or off")
		print("  /shychat whispers  - the whisper windows as they stand, to copy")
		print("  /shychat clearhistory  - clear saved chat history")
		print("  /clear  - clear the current chat window (/clear all: every window)")
		print("  /rl  - reload the UI")
	end
end

SLASH_SHYCHAT_CLEAR1 = "/clear"
SlashCmdList.SHYCHAT_CLEAR = function(input)
	if strtrim(input or ""):lower() == "all" then
		ns.Window.Clear()
	else
		ns.Window.Clear(SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
	end
end

SLASH_SHYCHAT_RL1 = "/rl"
SlashCmdList.SHYCHAT_RL = function() ReloadUI() end
