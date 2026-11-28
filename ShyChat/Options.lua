-- Settings: how chat lines are written, then the text, the windows, bubbles, whisper windows and what is kept.

local ADDON, ns = ...
local T, F = ns.T, ns.Format

ns.RefreshOptions = Shy.Settings.Refresh

local DOT = "\194\183"

local function Rewriting() return T.db.enabled end
local function Stamped() return T.db.enabled and T.db.timestamps ~= "none" end
local function Shortened() return T.db.enabled and (T.db.channelStyle == "short" or T.db.channelStyle == "numshort") end
local function Typed() return T.db.enabled and T.db.channelStyle ~= "name" and T.db.channelStyle ~= "blizzard" end
local function Whispered() return T.db.enabled and T.db.compact end
local function Restyled() return T.db.windowSkin end
local function Fading() return T.db.fade end
local function Filtering() return T.db.spam end
local function Bubbled() return T.db.bubbles end
local function Windowed() return T.db.whispers end
local function Saving() return T.db.history end
local function Seconds(v) return v .. "s" end

-- What a change reaches: the lines' wording, whose names are colored, the windows' text, the bubbles, or
-- nothing (read where it is used). The rest goes through T:Apply.
local function Lines() ns.ApplyLines() end
local function Names() ns.ApplyNames() end
local function Text() ns.Window.ApplyText() end
local function Bubbles() if ns.Bubbles then ns.Bubbles.Apply() end end
local function Nothing() end

local SHOWN = {
	{ value = "show", text = "Always" },
	{ value = "hover", text = "On hover" },
	{ value = "hide", text = "Never" },
}

local list = {
	{ key = "enabled", label = "Rewrite chat lines", apply = Lines, words = "format formatting",
		desc = "Chat lines get short tags, tidy names and the rest below. Turn it off to keep them as the game writes them." },
	{ note = "In some instances and boss fights the game hides lines from addons. Those keep the game's look." },

	{ section = "Presets" },
}
local function Add(entries)
	for _, entry in ipairs(entries) do list[#list + 1] = entry end
end

-- A preset is in use while every setting it sets still holds its value.
local function Wearing(preset)
	for key, value in pairs(preset.values) do
		if T.db[key] ~= value then return false end
	end
	return true
end

for _, preset in ipairs(ns.PRESETS) do
	Add({ { label = preset.text, button = "Use", words = "preset style look", desc = preset.desc,
		says = function() return Wearing(preset) and "In use" or "" end,
		run = function() T:ApplyPreset(preset) end } })
end

Add({
	{ section = "Tags" },
	{ key = "channelStyle", label = "Channel tags", enabled = Rewriting, apply = Lines, words = "names numbers short general trade",
		items = {
			{ value = "short", text = "Short" },
			{ value = "number", text = "Numbers" },
			{ value = "numshort", text = "Both" },
			{ value = "name", text = "Names" },
			{ value = "blizzard", text = "Game default" },
		},
		desc = "How a channel is named on a line: [Gen], [1], [1" .. DOT .. "Gen] or [General]." },
	{ key = "brackets", label = "Brackets", enabled = Rewriting, apply = Lines,
		items = { { value = "square", text = "[G]" }, { value = "round", text = "(G)" }, { value = "none", text = "G" } },
		desc = "What goes around a tag." },

	{ section = "Your own tags" },
	{ note = "Leave one empty for the usual tag. A dimmed row's tag isn't in use right now." },
})

-- A channel you are in, by its number.
local function Joined(num)
	for _, channel in ipairs(F.channels) do
		if channel.num == num then return channel end
	end
end

for num = 1, Constants.ChatFrameConstants.MaxChatChannels do
	Add({ { label = "Channel " .. num, text = true, sub = true, default = "", maxLetters = 12, placeholder = "Automatic",
		words = "channel tag short name rename", enabled = Shortened, apply = Lines,
		shown = function() return Joined(num) ~= nil end,
		says = function()
			local channel = Joined(num)
			return channel and ("%s, %s"):format(channel.name, F.AutoShort(channel.num, channel.name)) or ""
		end,
		get = function()
			local channel = Joined(num)
			return channel and T.db.channelNames[channel.name] or ""
		end,
		set = function(v)
			local channel = Joined(num)
			if not channel then return end
			v = strtrim(v)
			T.db.channelNames[channel.name] = v ~= "" and v or nil
		end } })
end

local TYPES = {
	{ "GUILD", "Guild" }, { "OFFICER", "Officer" }, { "PARTY", "Party" }, { "PARTY_LEADER", "Party leader" },
	{ "RAID", "Raid" }, { "RAID_LEADER", "Raid leader" }, { "RAID_WARNING", "Raid warning" },
	{ "INSTANCE_CHAT", "Instance" }, { "INSTANCE_CHAT_LEADER", "Instance leader" },
	{ "WHISPER", "Whisper", true }, { "WHISPER_INFORM", "Whisper to", true },
}

for _, entry in ipairs(TYPES) do
	local key = entry[1]
	Add({ { label = entry[2], text = true, sub = true, default = "", maxLetters = 8, placeholder = F.TYPE_DEFAULTS[key],
		words = "chat type tag short name rename", enabled = entry[3] and Whispered or Typed, apply = Lines,
		get = function() return T.db.typeNames[key] or "" end,
		set = function(v)
			v = strtrim(v)
			T.db.typeNames[key] = v ~= "" and v or nil
		end } })
end

Add({
	{ section = "Names" },
	{ key = "classColors", label = "Class colors", apply = Names, words = "names",
		desc = "Player names in chat get their class color. Lines already in chat stay as they are." },
	{ key = "hideRealm", label = "Hide realms", enabled = Rewriting, apply = Lines,
		desc = "Drops the realm after the name of someone from another realm." },
	{ key = "nameBrackets", label = "Brackets round names", enabled = Rewriting, apply = Lines,
		desc = "Names show as [Thrall], like the game writes them." },

	{ section = "Wording" },
	{ key = "compact", label = "Short speech", enabled = Rewriting, apply = Lines, words = "compact says whisper",
		desc = "\"Thrall says: hi\" becomes \"Thrall: hi\", and whispers get a [W] or [To] tag." },
	{ key = "compactLoot", label = "Short loot lines", enabled = Rewriting, apply = Lines, words = "compact gold xp money",
		desc = "\"You receive loot: [Item]\" becomes \"+ [Item]\". Gold and XP too." },
	{ key = "hoverLinks", label = "Tooltips on links", apply = Nothing, words = "hover item spell quest",
		desc = "Point at an item, spell or quest link in chat to see its tooltip." },
	{ note = "Click a web link in chat to copy it." },

	{ section = "Time" },
	{ key = "timestamps", label = "Timestamps", enabled = Rewriting, apply = Lines, words = "time clock",
		items = {
			{ value = "none", text = "Off" },
			{ value = "24", text = "14:05" },
			{ value = "24s", text = "14:05:09" },
			{ value = "12", text = "2:05 PM" },
			{ value = "12s", text = "2:05:09 PM" },
		},
		desc = "Shows the time before each line. With this off, you get the game's back if you had them on." },
	{ key = "timeColor", label = "Timestamp color", color = true, sub = true, enabled = Stamped, apply = Lines },
	{ key = "timeCopy", label = "Click to copy", sub = true, enabled = Stamped, apply = Lines,
		desc = "Click a timestamp to copy its line." },

	{ section = "Mentions" },
	{ key = "mentionName", label = "Highlight your name", enabled = Rewriting, apply = Lines,
		desc = "Your name stands out when someone else says it." },
	{ key = "keywords", label = "Other words", text = true, placeholder = "heal, tank, Onyxia", enabled = Rewriting, apply = Lines,
		words = "keywords highlight", desc = "More words to highlight, with commas between them." },
	{ key = "mentionColor", label = "Highlight color", color = true, enabled = Rewriting, apply = Lines,
		desc = "The color they stand out in." },
	{ key = "mentionSound", label = "Mention sound", enabled = Rewriting, apply = Nothing,
		desc = "Plays a sound when a line mentions you." },

	{ section = "Text" },
	{ key = "font", label = "Font", items = ns.FONTS, desc = "The font of chat, whisper windows and chat bubbles." },
	{ key = "outline", label = "Outline",
		items = { { value = "", text = "None" }, { value = "OUTLINE", text = "Outline" }, { value = "THICKOUTLINE", text = "Thick" } },
		desc = "A dark edge around the letters, in chat and on bubbles." },
	{ key = "shadow", label = "Text shadow", desc = "A shadow under the letters in chat." },
	{ key = "spacing", label = "Line spacing", min = 0, max = 8, step = 1, settle = true, apply = Text,
		desc = "The gap between lines." },
	{ note = "Text size is on a chat tab's right-click menu." },

	{ section = "Windows" },
	{ key = "windowSkin", label = "Restyle windows", words = "tabs skin panel",
		desc = "Chat windows get the console's panel, with tab names in the title bar." },
	{ key = "editSkin", label = "Restyle the typing row", words = "edit box",
		desc = "While you type, chat moves up for a typing row in the channel's color." },
	{ key = "move", label = "Move and resize", enabled = Restyled,
		desc = "Drag chat by its title bar and size it from any edge. With this off, Edit Mode does both." },
	{ key = "toolbar", label = "Chat buttons", items = SHOWN, words = "toolbar copy channels friends",
		desc = "Buttons for copy, channels, friends and settings at the end of the tab bar." },
	{ key = "sidebar", label = "Default button column", items = SHOWN, words = "sidebar menu social voice",
		desc = "The game's column of chat menu, channels, social and voice buttons beside chat." },
	Shy.Settings.Layout("Move chat and the whisper dock."),

	{ section = "Reading" },
	{ key = "fade", label = "Fade old lines", apply = Text, desc = "Lines fade out a while after they come in." },
	{ key = "fadeTime", label = "Fade after", sub = true, min = 5, max = 300, step = 5, format = Seconds, enabled = Fading, apply = Text },
	{ key = "maxLines", label = "Scrollback", min = 100, max = 1000, step = 50, apply = Text,
		desc = "How many lines you can scroll back in each window." },
	{ key = "autoBottom", label = "Back to newest", min = 0, max = 120, step = 5, apply = Nothing,
		format = function(v) return v == 0 and "Off" or Seconds(v) end,
		desc = "After you scroll up, chat jumps back down once you leave it alone this long." },
	{ key = "arrowKeys", label = "Up arrow recalls", apply = Text, words = "history sent alt",
		desc = "While typing, Up and Down step through lines you sent, without holding Alt." },
	{ key = "spam", label = "Hide repeats", apply = Nothing, words = "spam duplicate",
		desc = "Hides a say, yell or channel line the same player just sent. Guild, group and whispers always show." },
	{ key = "spamWindow", label = "Repeats within", sub = true, min = 10, max = 120, step = 5, format = Seconds, enabled = Filtering,
		apply = Nothing },
	{ note = "Shift and the wheel jump to the top or bottom. Ctrl and the wheel scroll a page." },

	{ section = "Chat bubbles", shown = function() return ns.Bubbles ~= nil end },
	{ key = "bubbles", label = "Restyle chat bubbles", apply = Bubbles,
		desc = "Bubbles over people's heads look like your tooltips, in the speaker's class color." },
	{ key = "bubbleNames", label = "Name on the bubble", sub = true, enabled = Bubbled, apply = Bubbles,
		desc = "The speaker's name at the top, with yell, party or raid beside it." },
	{ key = "bubbleSize", label = "Bubble text size", sub = true, min = 10, max = 18, step = 1, settle = true, enabled = Bubbled,
		apply = Bubbles },

	{ section = "Whispers", shown = function() return ns.Whispers ~= nil end },
	{ key = "whispers", label = "Whisper windows", words = "tells conversations",
		desc = "Each conversation gets a window, with the people you talk to as tabs. Whispers still show in chat." },
	{ key = "whisperOpen", label = "New whispers open", enabled = Windowed, apply = Nothing,
		items = {
			{ value = "auto", text = "Where you put them" },
			{ value = "window", text = "In a new window" },
			{ value = "tab", text = "As a blinking tab" },
			{ value = "chat", text = "Docked in chat" },
		},
		desc = "\"Where you put them\" remembers each person's place. Docking in chat needs restyled windows." },
	{ key = "whisperFight", label = "Hide in a fight", enabled = Windowed,
		desc = "The windows hide while you fight and come back after, with what you missed." },
	{ key = "whisperLines", label = "Lines per person", min = 10, max = 200, step = 10, enabled = Windowed, apply = Nothing,
		desc = "How many lines of each conversation you keep, even after a reload." },
	{ note = "Drop a tab on another window's tabs to join it, or anywhere else for a window of its own. Right-click a tab to invite, add a friend or close it. Tab moves between conversations while you type." },

	{ section = "History" },
	{ key = "history", label = "Keep chat", apply = Nothing, words = "save reload relog",
		desc = "Recent chat and the lines you sent come back after a reload or relog." },
	{ key = "historyLines", label = "Lines per window", sub = true, min = 20, max = 300, step = 10, enabled = Saving, apply = Nothing },
	{ label = "Saved chat", button = "Forget", confirm = true, words = "clear history", run = function() ns.ForgetHistory() end,
		desc = "Forgets saved chat, the lines you sent and every whisper conversation." },
	{ note = "/clear empties the chat window you're on, /clear all every one. /rl reloads." },
})

T:Settings(list)
