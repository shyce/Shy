-- Options: a live preview above six pages of settings. Every change goes through T:Apply.

local ADDON, ns = ...
local T, F = ns.T, ns.Format
local UI, Skin = Shy.UI, Shy.Skin

local LEFT, RIGHT, COL = 24, 330, 270

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function GetColor(key) return function() return unpack(T.db[key]) end end
local function SetColor(key) return function(r, g, b) T.db[key] = { r, g, b } end end
local function Seconds(v) return v .. "s" end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Formatting() return T.db.enabled end
local function Fading() return T.db.fade end

-- Live preview: sample lines built from the client's global strings, run through F.Format

local function Player(name, class)
	local shown = T.db.classColors and RAID_CLASS_COLORS[class]:WrapTextInColorCode(name) or name
	return "|Hplayer:" .. name .. ":0:NONE|h[" .. shown .. "]|h"
end

local function Samples()
	local me = UnitName("player")
	return {
		{ "|Hchannel:channel:1|h[1. General - Elwynn Forest]|h " .. CHAT_CHANNEL_GET:format(Player("Thrall-Mograine", "WARRIOR")) .. "anyone up for Deadmines? need a tank", "CHAT_MSG_CHANNEL", "CHANNEL1", "Thrall-Mograine" },
		{ CHAT_GUILD_GET:format(Player("Jaina", "MAGE")) .. "raid guide is up at https://example.com/raid", "CHAT_MSG_GUILD", "GUILD", "Jaina" },
		{ CHAT_WHISPER_GET:format(Player("Sylvanas", "HUNTER")) .. "hey " .. me .. ", want to quest together?", "CHAT_MSG_WHISPER", "WHISPER", "Sylvanas" },
		{ CHAT_PARTY_LEADER_GET:format(Player("Anduin", "PRIEST")) .. "pulling in 3", "CHAT_MSG_PARTY_LEADER", "PARTY_LEADER", "Anduin" },
		{ CHAT_SAY_GET:format(Player("Varian", "WARRIOR")) .. "for the Alliance!", "CHAT_MSG_SAY", "SAY", "Varian" },
		{ LOOT_ITEM_SELF:format("|cff0070dd|Hitem:2000::::::::|h[Archeus]|h|r") .. ".", "CHAT_MSG_LOOT", "LOOT" },
	}
end

-- The preview mirrors Look.lua's panel at the same distances, built from UI widgets.
local PREVIEW_W, LINE_H, LINES = 600, 17, 6
local STRIP = ns.Look.STRIP
local TEXT_X, TEXT_RIGHT = 8, 16                   -- right side leaves room for the scroll bar
local TEXT_Y = STRIP + 6                           -- strip, the selected tab's line, 4 clear
local EDIT_H, EDIT_X, EDIT_Y, EDIT_GAP = 22, 4, 5, 7
local FOOT = EDIT_GAP + EDIT_H + EDIT_Y            -- under the text with the edit box
local FOOT_BARE = 6                                -- without one
local PREVIEW_H = TEXT_Y + LINES * LINE_H + FOOT

-- A tab's name, as the window's (the title font); the open one's stretch of the panel's line lit by a mark of the
-- core's, as the window's open tab is (Look.lua), and a glow rising from it to the lip.
local function PreviewTab(parent, wing, text, open)
	local name = UI.TitleText(parent, text, nil, open and UI.colors.text or function() return ns.Look.NameColor(false) end)
	if open then
		-- A tab is 10 wider than its name at each end, and the light stops 1 inside the tab.
		name.line = UI.LineMark(wing, wing.shyLine)
		name.line:Span(name, name, -9)
		name.glow = parent:CreateTexture(nil, "BACKGROUND")
		name.glow:SetTexture(UI.GLOSS)
		name.glow:SetTexCoord(0, 1, 1, 0)   -- flipped: light from below
		name.glow:SetPoint("TOPLEFT", name, "TOPLEFT", -9, 3)
		name.glow:SetPoint("BOTTOMRIGHT", name.line, "BOTTOMRIGHT", 0, 0)
		UI.Tint(name.glow, UI.colors.hot)
	end
	return name
end

local function CreatePreview(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(PREVIEW_W, PREVIEW_H)

	-- No corner folds: the real window has text there.
	local wing = UI.Panel(CreateFrame("Frame", nil, f), { cap = true, title = STRIP, facets = false })
	wing:SetPoint("TOPLEFT")
	wing:SetWidth(PREVIEW_W)
	-- With the restyle off: roughly the default background.
	local plain = f:CreateTexture(nil, "BACKGROUND")
	plain:SetPoint("TOPLEFT", TEXT_X - 2, -TEXT_Y + 3)
	plain:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -1, -TEXT_Y - LINES * LINE_H - 6)
	plain:SetColorTexture(0, 0, 0, 0.25)

	local over = CreateFrame("Frame", nil, f)
	over:SetAllPoints()
	over:SetFrameLevel(wing:GetFrameLevel() + 1)
	local label = UI.Text(over, "preview", 11, true, UI.colors.dim)
	UI.OnHead(label, "RIGHT", wing, "RIGHT", -2 - 12)   -- (the strip stands 2 inside the edge)

	local tabs = { PreviewTab(over, wing, GENERAL, true), PreviewTab(over, wing, COMBAT_LOG) }
	UI.OnHead(tabs[1], "LEFT", wing, "LEFT", 2 + TEXT_X + 6)   -- Blizzard's tabs start a name 8 right of the text
	tabs[2]:SetPoint("LEFT", tabs[1], "RIGHT", 21, 0)

	local edit = CreateFrame("Frame", nil, over)
	edit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", EDIT_X, EDIT_Y)
	edit:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -EDIT_X, EDIT_Y)
	edit:SetHeight(EDIT_H)
	UI.Skin(edit)
	edit.text = edit:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
	edit.text:SetPoint("LEFT", TEXT_X - EDIT_X, 0)
	edit.text:SetText(CHAT_SAY_SEND)
	-- On restyled windows the typing row, open (Look.lua): the seam over it, the channel's light along it.
	edit.seam = {}
	for i, line in ipairs({ ns.Look.Hairline(edit, 0, 0, 0, 0.45), ns.Look.Hairline(edit, 1, 1, 1, 0.06) }) do
		line[1]:SetPoint("TOPLEFT", edit, "TOPLEFT", 0, 1 - i)
		line[3]:SetPoint("TOPRIGHT", edit, "TOPRIGHT", 0, 1 - i)
		for _, t in ipairs(line) do edit.seam[#edit.seam + 1] = t end
	end
	edit.light = edit:CreateTexture(nil, "ARTWORK", nil, 1)
	edit.light:SetTexture(UI.LookArt.SEAM)
	edit.light:SetSize((PREVIEW_W - 2 * EDIT_X) * ns.Look.SEAM_SHARE, UI.LookArt.SEAM_H)
	edit.light:SetPoint("TOPLEFT", edit, "TOPLEFT", 0, 0)
	edit.seam[#edit.seam + 1] = edit.light

	local lines = {}
	for i = 1, LINES do
		local fs = over:CreateFontString(nil, "OVERLAY")
		fs:SetPoint("TOPLEFT", TEXT_X, -TEXT_Y - (i - 1) * LINE_H)
		fs:SetWidth(PREVIEW_W - TEXT_X - TEXT_RIGHT)
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(false)
		lines[i] = fs
	end

	function f:Refresh()
		local db = T.db
		-- Fill at the Background setting's opacity, edge and strip a little stronger, as in Look.lua.
		local strength = Shy.Theme.Strength()
		local housing = Skin.colors.hudMetal[4]
		wing:SetShown(db.windowSkin and strength > 0)
		wing:SetHeight(PREVIEW_H - (db.editSkin and 0 or FOOT - FOOT_BARE))
		UI.Paint(wing.shyBg, UI.colors.panel, strength)
		UI.Tint(wing.shyEdge, Skin.colors.metal, housing)
		for _, piece in ipairs(wing.shyBrackets) do UI.Tint(piece, Shy.Theme.Accent, housing) end
		UI.Paint(wing.shyStrip, Skin.colors.strip, housing)
		plain:SetShown(not db.windowSkin)
		for _, tab in ipairs(tabs) do
			tab:SetShown(db.windowSkin)
			if tab.line then tab.line:SetShown(db.windowSkin) end
		end
		-- The row's light (restyled windows) or the box's border (default ones) and the header in the
		-- channel's color, as the real edit box.
		local say = ChatTypeInfo.SAY
		edit:SetShown(db.editSkin)
		UI.SetBorder(edit, { say.r, say.g, say.b, 1 })
		edit.shyBg:SetShown(not db.windowSkin)
		for _, t in ipairs(edit.shyEdges) do t:SetShown(not db.windowSkin) end
		for _, t in ipairs(edit.seam) do t:SetShown(db.windowSkin) end
		edit.light:SetVertexColor(say.r, say.g, say.b)
		edit.text:SetFont(ChatFrame1.editBox:GetFont())
		edit.text:SetTextColor(say.r, say.g, say.b)

		local fontPath, size, flags = ChatFrame1:GetFont()
		local now = time()
		for i, sample in ipairs(Samples()) do
			local fs = lines[i]
			fs:SetFont(fontPath, math.min(size, 14), flags)
			fs:SetShadowOffset(1, -1)
			fs:SetShadowColor(0, 0, 0, T.db.shadow and 1 or 0)
			local info = ChatTypeInfo[sample[3]] or ChatTypeInfo.CHANNEL
			fs:SetTextColor(info.r, info.g, info.b)
			fs:SetText((F.Format(sample[1], sample[2], now - (6 - i) * 37, 0, sample[4])))
		end
	end
	return f
end

-- Pages

local function StylePage(page, g)
	At(UI.Header(page, "Presets", COL), page, LEFT, 0)
	for i, preset in ipairs(ns.PRESETS) do
		local b = At(UI.Button(page, preset.text, 84, function() T:ApplyPreset(preset) end), page, LEFT + (i - 1) * 92, -32)
		UI.Help(b, preset.text, preset.desc, { side = "RIGHT" })
	end

	At(UI.Header(page, "Channels", COL), page, LEFT, -74)
	At(g:Dropdown(page, "Show channels as", {
		{ value = "short",    text = "Short names     [Gen]  [T]  [G]" },
		{ value = "number",   text = "Numbers     [1]  [2]  [G]" },
		{ value = "numshort", text = "Both     [1\194\183Gen]  [G]" },
		{ value = "name",     text = "Names     [General]  [Guild]" },
		{ value = "blizzard", text = "Game default" },
	}, Get("channelStyle"), Set("channelStyle"), { width = COL, enabled = Formatting,
		desc = "Short names are generated from the channel name. Rename them on the Channels tab." }), page, LEFT, -102)
	At(g:Dropdown(page, "Brackets", {
		{ value = "square", text = "[G]  Square" },
		{ value = "round",  text = "(G)  Round" },
		{ value = "none",   text = "G  None" },
	}, Get("brackets"), Set("brackets"), { width = COL, enabled = Formatting }), page, LEFT, -154)

	At(UI.Header(page, "Player names", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Color names by class", Get("classColors"), Set("classColors")), page, RIGHT, -32)
	At(g:Checkbox(page, "Hide realm names", Get("hideRealm"), Set("hideRealm"), { enabled = Formatting }), page, RIGHT, -58)
	At(g:Checkbox(page, "Brackets around names", Get("nameBrackets"), Set("nameBrackets"), { enabled = Formatting }), page, RIGHT, -84)

	At(UI.Header(page, "Formatting", COL), page, RIGHT, -124)
	At(g:Checkbox(page, "Format chat lines", Get("enabled"), Set("enabled"),
		{ desc = "Off shows default chat lines. Window options still apply." }), page, RIGHT, -156)
	local note = UI.Text(page, "Lines the game hides from addons (in some instances and boss fights) keep the default look.", 12, false, UI.colors.dim)
	note:SetWidth(COL)
	At(note, page, RIGHT, -184)
end

local function MessagesPage(page, g)
	At(UI.Header(page, "Wording", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Compact speech", Get("compact"), Set("compact"),
		{ enabled = Formatting, desc = "\"Thrall says: hi\" becomes \"Thrall: hi\". Whispers get a short [W] / [To] tag." }), page, LEFT, -32)
	At(g:Checkbox(page, "Short loot, gold and XP lines", Get("compactLoot"), Set("compactLoot"),
		{ enabled = Formatting, desc = "\"You receive loot: [Item]\" becomes \"+ [Item]\"." }), page, LEFT, -58)
	At(g:Checkbox(page, "Clickable web links", Get("urls"), Set("urls"),
		{ enabled = Formatting, desc = "Click a web link to open it in a copy box." }), page, LEFT, -84)
	At(g:Checkbox(page, "Link tooltips on hover", Get("hoverLinks"), Set("hoverLinks"),
		{ desc = "Hover an item, spell or quest link in chat to see its tooltip." }), page, LEFT, -110)

	At(UI.Header(page, "Timestamps", COL), page, LEFT, -150)
	At(g:Dropdown(page, "Format", {
		{ value = "none", text = "Off" },
		{ value = "24",   text = "14:05" },
		{ value = "24s",  text = "14:05:09" },
		{ value = "12",   text = "2:05 PM" },
		{ value = "12s",  text = "2:05:09 PM" },
	}, Get("timestamps"), Set("timestamps"), { width = COL, enabled = Formatting }), page, LEFT, -178)
	local function Stamped() return T.db.enabled and T.db.timestamps ~= "none" end
	At(g:ColorSwatch(page, "Timestamp color", GetColor("timeColor"), SetColor("timeColor"), { enabled = Stamped }), page, LEFT, -232)
	At(g:Checkbox(page, "Click a timestamp to copy its line", Get("timeCopy"), Set("timeCopy"), { enabled = Stamped }), page, LEFT, -258)

	At(UI.Header(page, "Mentions", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Highlight my name", Get("mentionName"), Set("mentionName"), { enabled = Formatting }), page, RIGHT, -32)
	At(g:Input(page, "Also highlight (comma separated)", Get("keywords"), Set("keywords"),
		{ width = COL, enabled = Formatting, placeholder = function() return "heal, tank, Onyxia" end }), page, RIGHT, -60)
	At(g:ColorSwatch(page, "Highlight color", GetColor("mentionColor"), SetColor("mentionColor"), { enabled = Formatting }), page, RIGHT, -116)
	At(g:Checkbox(page, "Play a sound when mentioned", Get("mentionSound"), Set("mentionSound"), { enabled = Formatting }), page, RIGHT, -142)
end

local function WindowPage(page, g)
	local VISIBILITY = {
		{ value = "show",  text = "Always show" },
		{ value = "hover", text = "Show on hover" },
		{ value = "hide",  text = "Hide" },
	}

	At(UI.Header(page, "Text", COL), page, LEFT, 0)
	At(g:Dropdown(page, "Chat font", ns.FONTS, Get("font"), Set("font"), { width = COL }), page, LEFT, -28)
	At(g:Dropdown(page, "Outline", {
		{ value = "",             text = "None" },
		{ value = "OUTLINE",      text = "Outline" },
		{ value = "THICKOUTLINE", text = "Thick outline" },
	}, Get("outline"), Set("outline"), { width = COL }), page, LEFT, -80)
	At(g:Checkbox(page, "Text shadow", Get("shadow"), Set("shadow")), page, LEFT, -132)
	At(g:Slider(page, "Line spacing", 0, 8, 1, Get("spacing"), Set("spacing"), { width = COL }), page, LEFT, -158)

	At(UI.Header(page, "Look", COL), page, LEFT, -212)
	At(g:Checkbox(page, "Restyle windows and tabs", Get("windowSkin"), Set("windowSkin"),
		{ desc = "Chat windows match the console, with tab names in the title bar and the selected tab underlined in your accent color. Panel opacity is the Opacity setting in /shy." }), page, LEFT, -244)
	At(g:Checkbox(page, "Restyle the edit box", Get("editSkin"), Set("editSkin"),
		{ desc = "While you type, chat moves up to make room for a typing row in the channel's color." }), page, LEFT, -270)

	At(UI.Header(page, "Chat bubbles", COL), page, LEFT, -312)
	At(g:Checkbox(page, "Restyle chat bubbles", Get("bubbles"), Set("bubbles"),
		{ desc = "Bubbles over people's heads look like the tooltips, in the speaker's class color, with the words tinted a little for say, yell, party or raid." }), page, LEFT, -344)
	At(g:Checkbox(page, "Name on the bubble", Get("bubbleNames"), Set("bubbleNames"),
		{ desc = "Shows the speaker's name at the top in their class color, with yell, party or raid at the right.", enabled = Get("bubbles") }), page, LEFT, -370)
	At(g:Slider(page, "Bubble text size", 10, 18, 1, Get("bubbleSize"), Set("bubbleSize"),
		{ width = COL, enabled = Get("bubbles") }), page, LEFT, -396)

	At(UI.Header(page, "Buttons", COL), page, RIGHT, 0)
	At(g:Dropdown(page, "Toolbar buttons", VISIBILITY, Get("toolbar"), Set("toolbar"), { width = COL,
		desc = "Copy, channels, friends and options, at the right end of the tab bar. With default windows they sit beside each chat window." }), page, RIGHT, -28)
	At(g:Dropdown(page, "Default button column", VISIBILITY, Get("sidebar"), Set("sidebar"), { width = COL,
		desc = "The default column beside the window: chat menu, channels, social and voice. Emotes and languages are only in its chat menu." }), page, RIGHT, -80)

	At(UI.Header(page, "Behavior", COL), page, RIGHT, -140)
	At(g:Checkbox(page, "Fade old lines", Get("fade"), Set("fade")), page, RIGHT, -172)
	At(g:Slider(page, "Fade after", 5, 300, 5, Get("fadeTime"), Set("fadeTime"),
		{ width = COL, format = Seconds, enabled = Fading }), page, RIGHT, -198)
	At(g:Checkbox(page, "Up arrow recalls sent lines", Get("arrowKeys"), Set("arrowKeys"),
		{ desc = "While typing, Up and Down step through lines you sent, without holding Alt. They're kept after a reload when \"Keep chat across reload and relog\" is on." }), page, RIGHT, -244)
	At(g:Checkbox(page, "Fast scrolling with Shift / Ctrl", Get("wheel"), Set("wheel"),
		{ desc = "Shift+wheel jumps to the top or bottom. Ctrl+wheel scrolls a page at a time." }), page, RIGHT, -270)
	At(g:Slider(page, "Jump back to the newest line", 0, 120, 5, Get("autoBottom"), Set("autoBottom"),
		{ width = COL, format = function(v) return v == 0 and "Off" or Seconds(v) end,
		desc = "After you scroll up, chat jumps back to the bottom if you leave it alone this long." }), page, RIGHT, -296)
	At(g:Checkbox(page, "Move and resize", Get("move"), Set("move"),
		{ enabled = Get("windowSkin"), desc = "Drag the chat by its title bar or its first tab, and resize it by any side or corner. Right-click the title bar to lock or reset it. Off leaves both to Edit Mode." }), page, RIGHT, -350)
end

local function WhispersPage(page, g)
	local function Windowed() return T.db.whispers end

	At(UI.Header(page, "Whisper windows", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Whisper windows", Get("whispers"), Set("whispers"),
		{ desc = "Each conversation gets a window, with the people you talk to as tabs. Whispers still show in chat too." }), page, LEFT, -32)
	At(g:Dropdown(page, "New whispers open", {
		{ value = "auto",   text = "Where you put them" },
		{ value = "window", text = "In a new window" },
		{ value = "tab",    text = "As a blinking tab" },
		{ value = "chat",   text = "Docked in chat" },
	}, Get("whisperOpen"), Set("whisperOpen"), { width = COL, enabled = Windowed,
		desc = "Where you put them: each person goes back where you last put them, and someone new where you usually put people." }), page, LEFT, -60)
	At(g:Checkbox(page, "Hide them in a fight", Get("whisperFight"), Set("whisperFight"),
		{ enabled = Windowed, desc = "The windows step aside while you fight and come back after, with anything whispered meanwhile." }), page, LEFT, -112)
	At(g:Slider(page, "Lines kept per person", 10, 200, 10, Get("whisperLines"), Set("whisperLines"),
		{ width = COL, enabled = Windowed, desc = "How much of each conversation you get back after a reload or relog." }), page, LEFT, -138)

	At(UI.Header(page, "Using them", COL), page, RIGHT, 0)
	local tips = UI.Text(page,
		"Whisper someone from chat and their window opens.\n" ..
		"Drag a tab: every place it can go lights up.\n" ..
		"Let go of it on a lit tab strip to join it there, anywhere else for a window of its own.\n" ..
		"A chat window of the game's docks in the chat alone, as the game has it.\n" ..
		"Enter goes back to the conversation you were typing in, R replies in theirs.\n" ..
		"Commands like /rl work in a conversation too.\n" ..
		"Right-click a tab to invite, add a friend or close it.\n" ..
		"Minimize a window into the whisper dock; move the dock in layout mode.\n" ..
		"Tab moves between conversations while you type.", 12, false, UI.colors.dim)
	tips:SetWidth(COL)
	tips:SetSpacing(5)
	At(tips, page, RIGHT, -32)
end

local function ChannelsPage(page, g)
	At(UI.Header(page, "Your channels", COL), page, LEFT, 0)
	local hint = UI.Text(page, "Leave a box empty to use the automatic name.", 12, false, UI.colors.dim)
	At(hint, page, LEFT, -28)

	local rows = {}
	for i = 1, 9 do
		local row = { channel = nil }
		row.label = UI.Text(page, "")
		row.label:SetWidth(150)
		At(row.label, page, LEFT, -56 - (i - 1) * 28)
		row.input = g:Input(page, nil,
			function() return row.channel and T.db.channelNames[row.channel.name] or "" end,
			function(v)
				v = strtrim(v)
				T.db.channelNames[row.channel.name] = v ~= "" and v or nil
			end,
			{ width = 100, maxLetters = 12,
			placeholder = function() return row.channel and F.AutoShort(row.channel.num, row.channel.name) or "" end })
		At(row.input, page, LEFT + 160, -52 - (i - 1) * 28)
		rows[i] = row
	end
	page:HookScript("OnShow", function()
		for i, row in ipairs(rows) do
			row.channel = F.channels[i]
			row.label:SetText(row.channel and (row.channel.num .. ". " .. row.channel.name) or "")
			row.label:SetShown(row.channel ~= nil)
			row.input:SetShown(row.channel ~= nil)
			row.input:Refresh()
		end
	end)

	At(UI.Header(page, "Chat types", COL), page, RIGHT, 0)
	for i, entry in ipairs(F.TYPE_ORDER) do
		local key, name = entry[1], entry[2]
		local x = RIGHT + (i > 6 and 138 or 0)
		local y = -32 - ((i - 1) % 6) * 30
		local label = UI.Text(page, name, 12)
		label:SetWidth(72)
		At(label, page, x, y - 5)
		At(g:Input(page, nil,
			function() return T.db.typeNames[key] or "" end,
			function(v)
				v = strtrim(v)
				T.db.typeNames[key] = v ~= "" and v or nil
			end,
			{ width = 52, maxLetters = 8, placeholder = function() return F.TYPE_DEFAULTS[key] end }), page, x + 74, y)
	end
end

local function MorePage(page, g)
	local function Saving() return T.db.history end

	At(UI.Header(page, "History", COL), page, LEFT, 0)
	At(g:Checkbox(page, "Keep chat across reload and relog", Get("history"), Set("history"),
		{ desc = "Saves recent chat and the last lines you sent, per character. Lines the game hides from addons are never saved." }), page, LEFT, -32)
	At(g:Slider(page, "Lines saved per window", 20, 300, 10, Get("historyLines"), Set("historyLines"),
		{ width = COL, enabled = Saving, desc = "How many lines each window gets back after a reload or relog." }), page, LEFT, -58)
	At(g:Slider(page, "Scrollback per window", 100, 1000, 50, Get("maxLines"), Set("maxLines"),
		{ width = COL, desc = "How many lines you can scroll back in each chat window." }), page, LEFT, -104)
	At(UI.Button(page, "Clear saved history", COL, function()
		ns.Window.ForgetHistory()
		T:Print("saved chat history cleared.")
	end), page, LEFT, -152)

	At(UI.Header(page, "Spam", COL), page, RIGHT, 0)
	At(g:Checkbox(page, "Hide repeated messages", Get("spam"), Set("spam"),
		{ desc = "Hides say, yell and channel messages repeated by the same player. Guild, group and whispers are never filtered." }), page, RIGHT, -32)
	At(g:Slider(page, "Repeats within", 10, 120, 5, Get("spamWindow"), Set("spamWindow"),
		{ width = COL, format = Seconds, enabled = function() return T.db.spam end }), page, RIGHT, -58)

	At(UI.Header(page, "Reset", COL), page, RIGHT, -112)
	At(UI.Button(page, "Reset this addon", COL, function()
		T:ResetDB()
		T:Apply()
		T:Print("settings reset.")
	end), page, RIGHT, -144)

	At(UI.Header(page, "Commands", COL), page, RIGHT, -184)
	local list = UI.Text(page,
		"|cffffd200/shychat|r  these options\n" ..
		"|cffffd200/shychat copy|r  copy the current window\n" ..
		"|cffffd200/shychat toggle|r  chat formatting on/off\n" ..
		"|cffffd200/clear|r  clear this window (|cffffd200/clear all|r: every one)\n" ..
		"|cffffd200/rl|r  reload the UI", 13)
	list:SetSpacing(5)
	At(list, page, RIGHT, -214)
end

-- Panel

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)
	local preview

	local function Build()
		UI.PageHeader(panel, T)

		local pages = {}
		local tabs = UI.Tabs(panel, { "Style", "Messages", "Window", "Whispers", "Channels", "More" }, function(i)
			for j, p in ipairs(pages) do p:SetShown(i == j) end
		end, 600)
		tabs:SetPoint("TOPLEFT", 24, -112)

		preview = CreatePreview(panel)
		preview:SetPoint("TOPLEFT", 24, -152)

		for i, build in ipairs({ StylePage, MessagesPage, WindowPage, WhispersPage, ChannelsPage, MorePage }) do
			local page = CreateFrame("Frame", nil, panel)
			page:SetPoint("TOPLEFT", 0, -152 - PREVIEW_H - 14)
			page:SetPoint("BOTTOMRIGHT")
			page:Hide()
			build(page, group)
			pages[i] = page
		end
		tabs:Select(1)
	end

	ns.RefreshOptions = function()
		if not panel.built then return end
		group:Refresh()
		preview:Refresh()
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		ns.RefreshOptions()
	end)

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
	end

	return panel
end
