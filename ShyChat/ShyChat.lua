-- Registration, defaults, presets, the settings ShyChat takes over from the game, and its commands.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyChat\\Media\\"
ns.MEDIA = MEDIA

local T = Shy:NewAddon(ADDON, {
	suffix = "Chat",
	category = "social",
	icon = MEDIA .. "ShyChat",
	smallIcon = MEDIA .. "ShyChatSmall",
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
		whisperOpen = "auto",    -- auto: where you put that person, else where you usually put people | window | tab | chat
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
		text = "Clean", desc = "Short tags, compact lines and timestamps. How it comes.",
		values = { channelStyle = "short", brackets = "square", nameBrackets = false, compact = true,
			compactLoot = true, timestamps = "24", toolbar = "hover", sidebar = "hide", fade = true, fadeTime = 60, spacing = 1 },
	},
	{
		text = "Minimal", desc = "No brackets or timestamps, no buttons and a quick fade.",
		values = { channelStyle = "short", brackets = "none", nameBrackets = false, compact = true,
			compactLoot = true, timestamps = "none", toolbar = "hide", sidebar = "hide", fade = true, fadeTime = 20, spacing = 2 },
	},
	{
		text = "Classic+", desc = "Channel numbers, names in brackets and the game's own wording and buttons.",
		values = { channelStyle = "number", brackets = "square", nameBrackets = true, compact = false,
			compactLoot = false, timestamps = "24s", toolbar = "hover", sidebar = "show", fade = false, spacing = 0 },
	},
}

function T:ApplyPreset(preset)
	for k, v in pairs(preset.values) do self.db[k] = v end
	self:Apply()
end

-- Default timestamps would double ours: off while ours show, restored after.
local function SyncTimestamps(db)
	local theirs = GetCVar("showTimestamps")
	if db.enabled and db.timestamps ~= "none" then
		if theirs ~= "none" then
			db.savedBlizzardTimestamps = theirs
			SetCVar("showTimestamps", "none")
		end
	elseif db.savedBlizzardTimestamps then
		SetCVar("showTimestamps", db.savedBlizzardTimestamps)
		db.savedBlizzardTimestamps = nil
	end
end

-- The game colors every sender name by class at "0" and none at "1". Off is none, whatever it was before.
local function SyncClassColors(db)
	local want = db.classColors and "0" or "1"
	if GetCVar("chatClassColorOverride") ~= want then SetCVar("chatClassColorOverride", want) end
	db.savedClassColors = nil
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

-- Parts of Apply, for a setting that touches nothing else: how lines are written, and whose names are colored.
function ns.ApplyLines()
	SyncTimestamps(T.db)
	ns.Format.RebuildChannels()
	ns.Format.RebuildMentions()
	QueueRerender()
end

function ns.ApplyNames()
	SyncClassColors(T.db)
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
			-- (The settings list the channels you are in.)
			if ns.RefreshOptions then ns.RefreshOptions() end
		end
	end)
end

function T:OnLogin()
	ns.Window.SetupAll()
	ns.Window.RestoreHistory()
	self:Apply()
	if ns.Whispers then ns.Whispers.Restore() end
end

-- Saved chat, the lines you sent and every whisper conversation, gone.
function ns.ForgetHistory()
	ns.Window.ForgetHistory()
	T:Print("saved chat and whispers cleared.")
end

T:Command("copy", "copy the chat window you're on", function()
	-- The window whose tab was last selected, or the main one.
	local id = CURRENT_CHAT_FRAME_ID
	ns.Window.CopyFrame(id and _G["ChatFrame" .. id] or ChatFrame1)
end)
T:Command("toggle", "rewrite chat lines, or leave them as the game writes them", function()
	T.db.enabled = not T.db.enabled
	ns.ApplyLines()
	if ns.RefreshOptions then ns.RefreshOptions() end
	T:Print("rewriting chat lines is " .. (T.db.enabled and "|cff40ff40on|r" or "|cffff4040off|r"))
end)
T:Command("clearhistory", "forget saved chat and whispers", function() ns.ForgetHistory() end)
-- (For finding faults: the whisper windows as they stand, to copy. Not listed.)
T:Command("whispers", nil, function()
	if ns.Whispers then Shy.UI.ShowCopyBox("Whisper windows", ns.Whispers.Report()) end
end)

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
