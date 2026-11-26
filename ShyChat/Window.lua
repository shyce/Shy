-- Chat window behavior: font, spacing, fade, toolbar, Blizzard's button column, sent-line history,
-- mouse wheel, copy, links, saved history, duplicate filter. Look.lua has the art.

local ADDON, ns = ...
local UI = Shy.UI
local F = ns.Format
local W = {}
ns.Window = W

local db
local frames = {}          -- chat frames ShyChat has set up
local tabs = {}            -- tab -> its chat frame
local lastScroll = {}

local function Each(fn) for frame in pairs(frames) do fn(frame) end end

-- Font

local OUTLINES = { OUTLINE = "OUTLINE", THICKOUTLINE = "OUTLINE, THICK" }

local function Font()
	for _, f in ipairs(ns.FONTS) do
		if f.value == db.font then return f end
	end
	return ns.FONTS[1]
end

-- The default face is a font family per size (every alphabet); the others are one file over
-- ChatFontNormal. A font object brings its own alignment, color and shadow: keep the region's.
local wearing

local function Wear(region, flags, shadow)
	if wearing then return end
	wearing = true
	local font = Font()
	local _, size = region:GetFont()
	local justify = region:GetJustifyH()
	local r, g, b, a = region:GetTextColor()
	if font.family then
		region:SetFontObject(font.family(math.floor(size + 0.5), flags))
	else
		region:SetFontObject(ChatFontNormal)
		region:SetFont(font.font or (ChatFontNormal:GetFont()), size, flags)
	end
	region:SetJustifyH(justify)
	region:SetTextColor(r, g, b, a)
	region:SetShadowColor(0, 0, 0, shadow and 1 or 0)
	region:SetShadowOffset(1, -1)
	wearing = false
end

-- Blizzard resets a window's font on size changes; Setup post-hooks SetFont with this to reapply ours.
local function WearChat(frame)
	Wear(frame, OUTLINES[db.outline] or "", db.shadow)
end

-- Edit box: sent lines on the arrow keys

-- The client's per-box history (Alt+Up) is lost on reload; this list is saved and restored.
local TYPED_MAX = 32   -- matches an edit box's own history size
local typed = {}       -- oldest first
local refilling

local browsing = {}    -- edit box -> { at = index in `typed`, draft = unsent text }
local lastArrow = 0

local function RememberTyped(editBox, text)
	browsing[editBox] = nil
	if refilling or issecretvalue(text) or type(text) ~= "string" or text == "" then return end
	if typed[#typed] == text then return end
	typed[#typed + 1] = text
	if #typed > TYPED_MAX then table.remove(typed, 1) end
end

-- On this client the arrow keys reach the chat box but its built-in history doesn't step on them,
-- so stepping is done here. Down past the newest restores the draft.
-- Putting the line in with SetText marks it as ours. The box's own Enter then runs it, and a protected
-- slash command (/target and the rest) is refused. Those lines go to a secure button instead: Enter
-- clicks it, and the box is emptied first so its handler has nothing protected left to run.
-- A typing row of ShyChat's own (a whisper's): its protected commands go to the button, the rest are run by the
-- game's own reading of a typed line (W.Run); after either the row stays, emptied, to go on talking.
local RECALL = "ShyChatRecall"
local recall, armedBox, armedText, handing, combatWatch
local placed = {}   -- edit box -> secure line we put there, until it is sent or replaced
local passing       -- edit box handing its keys on to the bindings for the Enter that runs the line
local own = setmetatable({}, { __mode = "k" })   -- typing rows of ShyChat's own

-- A box left passing keys on fires every hotkey while you type. Key passing can't change in a fight,
-- so this runs again when the fight ends and whenever the box takes focus.
local function StopPassing()
	if not passing or InCombatLockdown() then return end
	passing:SetPropagateKeyboardInput(false)
	passing = nil
end

local function SecureLine(text)
	if issecretvalue(text) or type(text) ~= "string" then return nil end
	local command = text:match("^(/[^%s]+)")
	if command and IsSecureCmd(command) then return text end
end

-- The line Enter hands to the button from this box, or nil: a protected command (a chat box's or ours).
local function Runs(box, text)
	return SecureLine(text)
end

-- A command typed in a row of ours that isn't protected (/rl, /dance, /s hi): run as the chat box would run it, by
-- the game's own reading of a line, in a box of ours the way the game runs a macro's lines. Unknown: the game's
-- help line, in the main chat.
local runner
function W.Run(text)
	if not runner then
		runner = Mixin(CreateFrame("EditBox"), ChatFrameEditBoxBaseMixin)
		runner:SetAutoFocus(false)
		runner:Hide()
		runner:SetStickyType("SAY")
		runner.chatFrame = DEFAULT_CHAT_FRAME
	end
	runner:SetChatType("SAY")
	runner:SetText(text)
	runner:SendText()
	runner:SetText("")
end

local function Unbind()
	armedBox, armedText = nil, nil
	if not recall or InCombatLockdown() then return end
	ClearOverrideBindings(recall)
end

local Arm

local function RecallButton()
	if recall then return recall end
	recall = CreateFrame("Button", RECALL, UIParent, "SecureActionButtonTemplate")
	recall:SetAttribute("type", "macro")
	-- A binding click is one Click(), with no down flag. The action has to run on that, not on key-down.
	recall:SetAttribute("useOnKeyDown", false)
	recall:Hide()
	-- The binding click ran the command. Close the box the way a sent line does, without touching
	-- its channel (that attribute has to stay the game's).
	recall:SetScript("PostClick", function()
		local box = armedBox
		if box then placed[box] = nil end
		Unbind()
		if box then
			box:SetText("")
			if not own[box] then box:Hide() end
		end
	end)
	combatWatch = CreateFrame("Frame")
	combatWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
	combatWatch:SetScript("OnEvent", function()
		StopPassing()
		local box = armedBox
		local text = box and not issecretvalue(box:GetText()) and box:GetText()
		if box and box:HasFocus() and Runs(box, text) then
			Arm(box, text)
		else
			Unbind()
		end
	end)
	return recall
end

-- True when Enter will click the button. In a fight the binding can't be changed: the line is still
-- remembered so Enter won't hand it to the box, and the binding is dropped once the fight ends.
function Arm(editBox, text)
	armedBox, armedText = editBox, text
	placed[editBox] = text
	if InCombatLockdown() then return false end
	local button = RecallButton()
	button:SetAttribute("macrotext", text)
	SetOverrideBindingClick(button, true, "ENTER", RECALL)
	SetOverrideBindingClick(button, true, "NUMPADENTER", RECALL)
	return true
end

local function OnEnterKey(editBox)
	if editBox ~= armedBox then return end
	-- Name completion accepts its pick on Enter. Leave that to the box.
	if AutoCompleteBox:IsShown() and AutoCompleteBox.parent == editBox then return end
	local text = editBox:GetText()
	if not Runs(editBox, text) then
		placed[editBox] = nil
		Unbind()
		return
	end
	-- In a fight a row of ours can't hand its key on: the line stays for its own Enter to explain.
	if own[editBox] and InCombatLockdown() then return end
	if text ~= armedText then Arm(editBox, text) end
	-- Still dispatching this key: keep the binding until it has clicked, then drop it.
	-- The line is no longer one we put there: focusing the box again must not grab Enter.
	placed[editBox] = nil
	handing = true
	editBox:SetText("")
	if not InCombatLockdown() then
		editBox:SetPropagateKeyboardInput(true)
		passing = editBox
	end
	C_Timer.After(0, function()
		handing = nil
		StopPassing()
		Unbind()
	end)
end

local function OnArrow(editBox, key)
	if key ~= "UP" and key ~= "DOWN" then return end
	if not db.arrowKeys then return end
	-- While Blizzard's name completion is open the arrows pick from it.
	if AutoCompleteBox:IsShown() and AutoCompleteBox.parent == editBox then return end
	-- The same key press can arrive through both hooks.
	if lastArrow == GetTime() then return end
	lastArrow = GetTime()

	local state = browsing[editBox]
	if not state then
		if key == "DOWN" or #typed == 0 then return end
		state = { at = #typed + 1, draft = editBox:GetText() }
		browsing[editBox] = state
	end
	state.at = math.max(1, math.min(#typed + 1, state.at + (key == "UP" and -1 or 1)))
	local text = typed[state.at] or state.draft
	if state.at > #typed then browsing[editBox] = nil end
	if Runs(editBox, text) then
		Arm(editBox, text)
	else
		placed[editBox] = nil
		Unbind()
	end
	editBox:SetText(text)
	editBox:SetCursorPosition(#text)
end

local hookedBoxes = {}

-- Enter on a line the button runs, followed as it is typed, focused and let go of.
local function HookCommands(editBox)
	editBox:HookScript("OnKeyDown", function(self, key)
		if key == "ENTER" or key == "NUMPADENTER" then OnEnterKey(self) end
	end)
	editBox:HookScript("OnTextChanged", function(self, userInput)
		-- (a chat box runs what is typed in it itself: only a line put there is the button's)
		if not userInput or (self ~= armedBox and not own[self]) then return end
		local text = self:GetText()
		if issecretvalue(text) or (self == armedBox and text == armedText) then return end
		if Runs(self, text) then
			Arm(self, text)
		elseif self == armedBox then
			placed[self] = nil
			Unbind()
		end
	end)
	editBox:HookScript("OnEditFocusLost", function(self)
		if handing or self ~= armedBox then return end
		Unbind()
	end)
	editBox:HookScript("OnEditFocusGained", function(self)
		if self == passing then StopPassing() end
		local text = self:GetText()
		if (own[self] or (placed[self] and text == placed[self])) and Runs(self, text) then Arm(self, text) end
	end)
	editBox:HookScript("OnHide", function(self)
		browsing[self] = nil
		if handing then return end
		placed[self] = nil
		if self == armedBox then Unbind() end
	end)
end

-- A typing row of ShyChat's own: the commands typed in it run as the chat box's do.
function W.Commands(editBox)
	if own[editBox] then return end
	own[editBox] = true
	HookCommands(editBox)
end

local function SetupEditBox(editBox)
	if not hookedBoxes[editBox] then
		hookedBoxes[editBox] = true
		hooksecurefunc(editBox, "UpdateHeader", ns.Look.EditHeader)
		hooksecurefunc(editBox, "AddHistoryLine", RememberTyped)
		editBox:HookScript("OnArrowPressed", function(self, key) OnArrow(self, key) end)
		editBox:HookScript("OnKeyDown", function(self, key)
			if key ~= "ENTER" and key ~= "NUMPADENTER" then OnArrow(self, key) end
		end)
		HookCommands(editBox)
	end
	editBox:SetAltArrowKeyMode(not db.arrowKeys)
	Wear(editBox, "", true)
	Wear(editBox.header, "", true)
	Wear(editBox.headerSuffix, "", true)
	Wear(editBox.languageHeader, "", true)
	Wear(editBox.prompt, "", true)
end

-- Copy

-- The shared copy box's title carries the accent color: rewritten on SHY_THEME, but only while
-- it still shows our title (another addon may have used the box since).
local copyNote, copyTitle

local function CopyTitle()
	return Shy.Brand.Name("Chat") .. "  |cff888888" .. copyNote .. "|r"
end

local function ShowCopy(note, text)
	copyNote = note
	copyTitle = CopyTitle()
	UI.ShowCopyBox(copyTitle, text)
end
W.ShowCopy = ShowCopy   -- a conversation's lines too (Whispers.lua)

Shy:On("SHY_THEME", function()
	local box = UI.copyBox
	if box and copyTitle and box.title:GetText() == copyTitle then
		copyTitle = CopyTitle()
		box.title:SetText(copyTitle)
	end
end)

function W.CopyFrame(frame)
	local lines = {}
	for i = 1, frame:GetNumMessages() do
		-- As it is shown: our words where the line is ours.
		local entry, line = F.Line(frame, i)
		local message = entry and entry.message
		if line then
			local original, _, _, _, text = F.About(line)
			if not issecretvalue(original) then message = text or original end
		end
		lines[#lines + 1] = (message == nil or issecretvalue(message)) and "(protected message)" or UI.PlainText(message)
	end
	-- A whisper tab's name can be secret.
	local tab = _G[frame:GetName() .. "Tab"]
	local name = tab and tab:GetText()
	if name == nil or issecretvalue(name) then name = "" end
	ShowCopy(name, table.concat(lines, "\n"))
end

-- The toolbar: our buttons on each window, replacing Blizzard's button column. Restyled windows:
-- glyphs at the tab strip's right end, shown only on hover when tab names reach them; once they
-- reach it, the row folds to the one gear, whose menu (W.ChatMenu) lists every tab and the tools, so
-- a full row of tabs still has a way to any of them. Default windows: a column of boxed buttons on
-- the side opposite Blizzard's column.
-- Nothing is written onto Blizzard's frames; per-window state lives in tables here.

local Look = ns.Look
local BESIDE = { size = 22, gap = 2, icon = 14 }
local IN_STRIP = { size = Look.CHANNEL, gap = 5, icon = 12 }   -- 8 between glyphs
local TOOL_OFFSET = { RIGHT = 4, LEFT = -6 }     -- beside the window, from Blizzard's background
local STRIP_END = 3                              -- last button ends this far inside Blizzard's background
local ARROW = 18                                 -- Blizzard's overflow arrow: 16 wide plus 2 clear
local OVER_TABS = 30                             -- frame level above Blizzard's tabs (MEDIUM strata)

local tools = setmetatable({}, { __mode = "k" })   -- chat frame -> its toolbar

function W.Tools(frame) return tools[frame] end

local function FriendsOnline()
	local _, battleNet = BNGetNumFriends()
	return (C_FriendList.GetNumOnlineFriends() + battleNet) .. " online"
end

-- Only a button whose hover tells what can't be seen has one: how many friends are online.
local TOOLS = {
	{ icon = ns.MEDIA .. "Copy", click = function(frame) W.CopyFrame(frame) end },
	{ icon = ns.MEDIA .. "Channels", click = function() ToggleChannelFrame() end },
	{ icon = ns.MEDIA .. "Friends", tip = "Friends", note = FriendsOnline,
		click = function() ToggleFriendsFrame() end },
	{ icon = Shy.Skin.GLYPH.gear, click = function(frame, button) W.ChatMenu(button, frame) end },
}
local GEAR = #TOOLS   -- the one button left when the row folds

-- Glyph color at rest: dim in the strip, plain on a boxed button.
local function AtRest(bar)
	return bar.side == "STRIP" and UI.colors.dim or UI.colors.head
end

local function ToolButton(bar, tool, frame)
	local b = CreateFrame("Button", nil, bar)
	b.icon = b:CreateTexture(nil, "OVERLAY")
	b.icon:SetPoint("CENTER")
	b.icon:SetTexture(tool.icon)
	if tool.tip then
		b:SetScript("OnEnter", function(self)
			local note = type(tool.note) == "function" and tool.note() or tool.note
			UI.Tip(self, tool.tip, note, { side = bar.side == "RIGHT" and "RIGHT" or "LEFT" })
		end)
		b:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	end
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		tool.click(frame, self)
	end)
	-- The family's button make: boxed beside the window, bare in the tab strip (Layout).
	UI.KeyPress(b, { fill = UI.colors.bg, glyphs = { b.icon }, sink = { b.icon } })
	return b
end

local function Toolbar(frame)
	local bar = CreateFrame("Frame", nil, frame)
	bar.buttons = {}
	for i, tool in ipairs(TOOLS) do bar.buttons[i] = ToolButton(bar, tool, frame) end
	-- Shown behind the buttons when they cover tab names.
	bar.back = bar:CreateTexture(nil, "BACKGROUND")
	bar.back:SetPoint("TOPLEFT", -6, 0)
	bar.back:SetPoint("BOTTOMRIGHT", 2, 0)
	UI.Paint(bar.back, Shy.Skin.colors.strip)
	bar.back:Hide()
	-- IsMouseOver needs a shown frame: the zone is always shown. It keeps the whole row's room,
	-- folded or not, so crowding is judged against the same edge every time.
	bar.zone = CreateFrame("Frame", nil, frame)
	bar.zone:SetAllPoints(bar)
	bar:SetAlpha(0)
	bar:Hide()
	return bar
end

-- In the strip on restyled windows; else beside the window, opposite Blizzard's column. Folded
-- (tab names reaching the row), only the gear stands, at the row's end.
-- Where the strip's tabs must end to stay clear of the toolbar (the gear it keeps at the row's end once names reach it)
-- and the dock's overflow arrow, as a screen x: the tab row scrolls its last tab to there, not under them.
function W.RowEnd(frame)
	local bg = frame.Background
	local right = bg and bg:GetRight()
	if not right or issecretvalue(right) then return nil end
	local x = right - STRIP_END
	if frame.isDocked and GeneralDockManager.overflowButton:IsShown() then x = x - ARROW end
	if db.windowSkin and db.toolbar ~= "hide" then x = x - IN_STRIP.size - IN_STRIP.gap end
	return x
end

local function PlaceToolbar(frame, folded)
	local bar = tools[frame]
	local side = db.windowSkin and "STRIP" or (frame.buttonSide == "right" and "LEFT" or "RIGHT")
	local strip = side == "STRIP"
	folded = strip and folded or false
	-- Leave room for Blizzard's overflow arrow at the docked strip's end.
	local arrow = strip and frame.isDocked and GeneralDockManager.overflowButton:IsShown() or false
	if bar.side == side and bar.arrow == arrow and bar.folded == folded then return end
	bar.side, bar.arrow, bar.folded = side, arrow, folded
	local lay = strip and IN_STRIP or BESIDE
	local long = #bar.buttons * (lay.size + lay.gap) - lay.gap
	bar:ClearAllPoints()
	bar.zone:ClearAllPoints()
	if strip then
		local endX = -STRIP_END - (arrow and ARROW or 0)
		bar:SetSize(folded and lay.size or long, lay.size)
		bar:SetPoint("BOTTOMRIGHT", frame.Background, "TOPRIGHT", endX, Look.STRIP_FOOT)
		bar:SetFrameStrata("MEDIUM")
		bar:SetFrameLevel(OVER_TABS)
		bar.zone:SetSize(long, lay.size)
		bar.zone:SetPoint("BOTTOMRIGHT", frame.Background, "TOPRIGHT", endX, Look.STRIP_FOOT)
	else
		bar:SetSize(lay.size, long)
		if side == "RIGHT" then
			bar:SetPoint("TOPLEFT", frame.Background, "TOPRIGHT", TOOL_OFFSET.RIGHT, 0)
		else
			bar:SetPoint("TOPRIGHT", frame.Background, "TOPLEFT", TOOL_OFFSET.LEFT, 0)
		end
		bar:SetFrameStrata(frame:GetFrameStrata())
		bar:SetFrameLevel(frame:GetFrameLevel() + 5)
		bar.zone:SetAllPoints(bar)
	end
	for i, b in ipairs(bar.buttons) do
		local at = (i - 1) * (lay.size + lay.gap)
		b:SetSize(lay.size, lay.size)
		b:ClearAllPoints()
		if folded then
			b:SetShown(i == GEAR)
			b:SetPoint("LEFT", 0, 0)
		else
			b:Show()
			if strip then b:SetPoint("LEFT", at, 0) else b:SetPoint("TOP", 0, -at) end
		end
		b.icon:SetSize(lay.icon, lay.icon)
		b:SetRest(AtRest(bar))
		b:SetBare(strip)
	end
end

-- Do tab names reach the toolbar? Docked windows share a strip. A tab's edge can be secret.
-- A window's tab, found by name once (the tick asks for every docked window's, twenty times a second).
local tabs = setmetatable({}, { __mode = "k" })
local function TabOf(frame)
	local tab = tabs[frame]
	if not tab then
		tab = _G[frame:GetName() .. "Tab"]
		tabs[frame] = tab
	end
	return tab
end

-- How far right a window's tab name reaches (nil: not shown, or kept secret), and the furthest of the docked
-- windows', which share one strip: that one asked once a tick (W.Tick) and handed to each docked window, not
-- worked out again for every one of them.
local function TabRight(frame)
	local tab = TabOf(frame)
	local right = tab:IsShown() and tab:GetRight()
	if right and not issecretvalue(right) then return right end
end
local function DockRight()
	local most
	for other in pairs(frames) do
		if other.isDocked then
			local right = TabRight(other)
			if right and (not most or right > most) then most = right end
		end
	end
	-- Conversations docked after the game's tabs reach further.
	local docked = ns.Whispers and ns.Whispers.StripRight and ns.Whispers.StripRight()
	if docked and (not most or docked > most) then most = docked end
	return most or false
end

local function Crowded(frame, bar, dockRight)
	if bar.side ~= "STRIP" then return false end
	local left = bar.zone:GetLeft()
	if not left then return false end
	local right
	if frame.isDocked then right = dockRight or nil else right = TabRight(frame) end
	return right ~= nil and right > left
end

-- Mouse on the window, its tabs or the toolbar beside it?
local function NearWindow(frame)
	local left, right = 8, 20
	local side = tools[frame].side
	local reach = BESIDE.size + 6
	if side == "RIGHT" then right = right + reach elseif side == "LEFT" then left = left + reach end
	return frame:IsMouseOver(side == "STRIP" and 32 or 28, -8, -left, right)
end

-- One window, or every window with no frame. History is saved at logout, so cleared lines stay gone.
function W.Clear(frame)
	if frame then frame:Clear() else Each(function(f) f:Clear() end) end
end

-- Per-frame setup and settings

local function OnWheel(frame, delta)
	lastScroll[frame] = GetTime()
	if IsShiftKeyDown() then
		if delta > 0 then frame:ScrollToTop() else frame:ScrollToBottom() end
	elseif IsControlKeyDown() then
		if delta > 0 then frame:PageUp() else frame:PageDown() end
	end
end

local function ApplyFrame(frame)
	WearChat(frame)
	frame:SetSpacing(db.spacing)
	frame:SetFading(db.fade)
	frame:SetTimeVisible(db.fadeTime)
	frame:SetMaxLines(db.maxLines)
	SetupEditBox(frame.editBox)
end

-- A message frame of another addon's (the away board's chat) wearing the chat's face and spacing at its
-- own size, and again whenever the settings change.
local dressed = setmetatable({}, { __mode = "k" })

function W.Dress(frame)
	dressed[frame] = true
	WearChat(frame)
	frame:SetSpacing(db.spacing)
	-- The lines it copies from the chat windows are shown in our words, as there.
	F.Watch(frame, "copy")
end

local function DressAll()
	for frame in pairs(dressed) do W.Dress(frame) end
end

-- Blizzard's button column and the social button are hidden, not faded: Blizzard animates the
-- column's alpha itself and a transparent column still takes clicks. W.Tick does the hiding.
local unwanted = setmetatable({}, { __mode = "k" })   -- the setting wants it hidden
local put = setmetatable({}, { __mode = "k" })        -- we hid it, so we show it again

-- Edit Mode clamps ChatFrame1 to the screen with room for the button column on both sides, shown
-- or not. With the column hidden, clamp at the art's real edge instead. Blizzard recomputes the
-- insets on layout and scale changes, hence the hook on UpdateClampOffsets.

local BLIZZARD_LEFT, BLIZZARD_RIGHT = 2, 15   -- Blizzard's background past the window's sides (right has the scroll bar)

local function FreeEdges(frame)
	if db.sidebar ~= "hide" then return end
	local _, _, top, bottom = frame:GetClampRectInsets()
	-- Look.lua's reach; nil with default windows. The restyled edit box opens inside the panel (the window
	-- lifts for it), so the panel's foot is the edge; Blizzard's hangs under the window and keeps its room.
	local reach = Shy.wings.chat
	if reach then
		frame:SetClampRectInsets(-reach[1], reach[3], top, db.editSkin and -reach[4] or math.min(bottom, -reach[4]))
	else
		frame:SetClampRectInsets(-BLIZZARD_LEFT, BLIZZARD_RIGHT, top, bottom)
	end
end

-- The game's alerts by the chat (a friend coming online, a voice chat's prompt) stand in ChatAlertFrame, which the
-- game hangs over the top of the first window's button column, once, as it loads. With the column hidden the window
-- stands right up to the screen's edge and the column's place is off it, the alerts with it. So while it is hidden
-- they stand over the window instead: along its panel's top (Blizzard's background with default windows), where the
-- game lays them from its left end, or from its right while the column is the right side's. The game's own anchors
-- are kept, and put back whenever the column is in use.
local ALERTS = { over = 6, bare = 24 }   -- above the panel's top edge; above Blizzard's background (clear of its tabs, as the game has them)
local alertsHome                         -- the game's anchors for the frame
local alertsOn                           -- the region they stand over now

local function StandAlerts()
	local alerts, frame = ChatAlertFrame, ChatFrame1
	if not alerts or not frame then return end
	local to, rise
	if db.sidebar == "hide" then
		to, rise = Shy.HUD.HousingOf(frame), ALERTS.over
		if not to then to, rise = frame.Background, ALERTS.bare end
	end
	if to == alertsOn then return end
	if alerts:IsProtected() and InCombatLockdown() then return end
	if not alertsHome then
		alertsHome = {}
		for i = 1, alerts:GetNumPoints() do alertsHome[i] = { alerts:GetPoint(i) } end
	end
	alertsOn = to
	alerts:ClearAllPoints()
	if to then
		alerts:SetPoint("BOTTOMLEFT", to, "TOPLEFT", 0, rise)
		alerts:SetPoint("BOTTOMRIGHT", to, "TOPRIGHT", 0, rise)
	else
		for _, p in ipairs(alertsHome) do alerts:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
	end
end

local function Setup(frame)
	if frames[frame] then return end
	frames[frame] = true
	local tab = _G[frame:GetName() .. "Tab"]
	if tab then tabs[tab] = frame end
	if frame.UpdateClampOffsets then
		hooksecurefunc(frame, "UpdateClampOffsets", FreeEdges)
		FreeEdges(frame)
	end
	hooksecurefunc(frame, "AddMessage", F.OnAddMessage)
	F.Watch(frame)
	hooksecurefunc(frame, "SetFont", WearChat)
	frame:HookScript("OnMouseWheel", OnWheel)
	tools[frame] = Toolbar(frame)
	-- Blizzard re-shows the column itself (leaving gamepad mode does).
	frame.buttonFrame:HookScript("OnShow", function(self)
		if unwanted[self] then
			put[self] = true
			self:Hide()
		end
	end)
	ApplyFrame(frame)
end

function W.SetupAll()
	ChatFrameUtil.ForEachChatFrame(Setup)
	ns.Look.Apply()
end

-- The windows' own settings alone: face, spacing, fading, how much they keep.
function W.ApplyText()
	Each(ApplyFrame)
	DressAll()
end

function W.ApplyAll()
	W.ApplyText()
	-- Look first: the clamp insets depend on its reach. UpdateClampOffsets restores Blizzard's
	-- insets before the hook applies ours, so re-showing the column gets its room back.
	ns.Look.Apply()
	Each(function(frame)
		if frame.UpdateClampOffsets then frame:UpdateClampOffsets() end
	end)
end

-- Hover: the toolbar, Blizzard's button column and jumping back to the newest line

local lastOver = 0

-- The button columns, in a list kept while the windows are the same (asked twenty times a second).
local columns, columnsOf = {}, -1
local function ButtonFrames()
	local count = 0
	for _ in pairs(frames) do count = count + 1 end
	if count ~= columnsOf then
		columnsOf = count
		wipe(columns)
		for frame in pairs(frames) do columns[#columns + 1] = frame.buttonFrame end
		columns[#columns + 1] = QuickJoinToastButton
	end
	return columns
end

function W.Tick()
	local now = GetTime()
	local over = false
	local dockRight   -- how far the docked tabs reach: asked once, by the first docked window in a strip
	for frame in pairs(frames) do
		local visible = frame:IsVisible()
		local hovered = visible and frame:IsMouseOver()
		local bf = frame.buttonFrame
		if bf:IsShown() and bf:IsMouseOver() then hovered = true end
		over = over or hovered

		-- (The toolbar is the window's own: on a window out of sight, another tab's, it is neither seen nor
		-- pointed at, and is laid and faded when the window next shows.)
		if visible then
			local bar = tools[frame]
			PlaceToolbar(frame, bar.folded)
			-- Crowded: the row folds to the gear, and tab names win until the mouse is at that end.
			if dockRight == nil and frame.isDocked and bar.side == "STRIP" then dockRight = DockRight() end
			local crowded = Crowded(frame, bar, dockRight)
			if crowded ~= (bar.folded or false) then PlaceToolbar(frame, crowded) end
			-- A menu opened from the row keeps the row: the menu closes with the button it hangs from.
			local menuOwner = UI.MenuOwner()
			local wanted
			if menuOwner and menuOwner:GetParent() == bar then
				wanted = true
			elseif db.toolbar == "hide" then
				wanted = false
			elseif crowded then
				wanted = visible and bar.zone:IsMouseOver()
			else
				wanted = db.toolbar == "show" or (visible and NearWindow(frame))
			end
			if bar.crowded ~= crowded then
				bar.crowded = crowded
				bar.back:SetShown(crowded)
			end
			-- Faded toward where it is wanted; told nothing once it is there.
			local target = wanted and 1 or 0
			local was = bar:GetAlpha()
			if was ~= target then
				local alpha = was + (target - was) * 0.35
				if math.abs(target - alpha) < 0.02 then alpha = target end
				bar:SetAlpha(alpha)
				bar:SetShown(alpha > 0)
			elseif bar:IsShown() ~= (target > 0) then
				bar:SetShown(target > 0)
			end
		end

		if db.autoBottom > 0 and not frame:AtBottom() and not hovered
			and now - (lastScroll[frame] or 0) > db.autoBottom then
			frame:ScrollToBottom()
		end
	end
	if QuickJoinToastButton:IsShown() and QuickJoinToastButton:IsMouseOver() then over = true end
	if over then lastOver = now end

	local show = db.sidebar == "show" or (db.sidebar == "hover" and now - lastOver < 0.6)
	local changed = false
	for _, bf in ipairs(ButtonFrames()) do
		unwanted[bf] = not show or nil
		if show then
			if put[bf] then
				put[bf] = nil
				bf:Show()
				changed = true
			end
		elseif bf:IsShown() then
			put[bf] = true
			bf:Hide()
			changed = true
		end
	end
	-- OnShow/OnHide don't fire for columns of windows that aren't visible, so refit by hand.
	if changed then ns.Look.Refit() end
	StandAlerts()
end

-- Links: copy URLs and lines, tooltips when hovering item-style links

local HOVER_TYPES = { item = true, spell = true, achievement = true, quest = true, enchant = true, currency = true, talent = true }
local hoverShown

local function OnLinkClick(_, link, _, _, frame)
	local kind, data = link:match("^addon:ShyChat:(%a+):(.*)$")
	if kind == "url" then
		ShowCopy("link", data)
	elseif kind == "line" and frame then
		local text = F.FindLine(frame, tonumber(data))
		if text then ShowCopy("line", UI.PlainText(text)) end
	end
end

local function OnLinkEnter(_, frame, link)
	if not db.hoverLinks or issecretvalue(link) then return end
	if HOVER_TYPES[link:match("^(%a+):")] then
		GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
		hoverShown = true
	end
end

local function OnLinkLeave()
	if hoverShown then
		GameTooltip:Hide()
		hoverShown = nil
	end
end

-- The same for a message frame of ShyChat's own (a whisper window's).
function W.LinkEnter(frame, link) OnLinkEnter(nil, frame, link) end
W.LinkLeave = OnLinkLeave

-- History across reload and relog (per character; secret lines are never saved)

function W.SaveHistory()
	-- Conversations and their windows are kept by the whisper windows, whatever this setting says.
	local whispers, windows = ShyChatHistory.whispers, ShyChatHistory.whisperWindows
	wipe(ShyChatHistory)
	ShyChatHistory.whispers, ShyChatHistory.whisperWindows = whispers, windows
	if not db.history then return end
	-- No chat window is named "typed", so the key can't clash.
	if #typed > 0 then ShyChatHistory.typed = typed end
	Each(function(frame)
		local lines = {}
		local total = frame:GetNumMessages()
		for i = math.max(1, total - db.historyLines + 1), total do
			-- Only lines we know (not the "earlier" divider), and never a secret one.
			local entry, line = F.Line(frame, i)
			if line then
				local original, t, event, author = F.About(line)
				if not issecretvalue(original) and type(original) == "string" then
					lines[#lines + 1] = { m = original, r = entry.r, g = entry.g, b = entry.b, t = t, e = event, a = author }
				end
			end
		end
		if #lines > 0 then ShyChatHistory[frame:GetName()] = lines end
	end)
end

function W.ForgetHistory()
	wipe(ShyChatHistory)
	wipe(typed)
	if ns.Whispers then ns.Whispers.Forget() end
	Each(function(frame)
		if frame.editBox then frame.editBox:ClearHistory() end
	end)
end

function W.RestoreHistory()
	if not db.history then return end
	local sent = ShyChatHistory.typed
	if type(sent) == "table" and type(sent[1]) == "string" then
		refilling = true
		for _, text in ipairs(sent) do
			typed[#typed + 1] = text
			Each(function(frame)
				if frame.editBox then frame.editBox:AddHistoryLine(text) end
			end)
		end
		refilling = false
	end
	for name, lines in pairs(ShyChatHistory) do
		local frame = _G[name]
		if name ~= "typed" and name ~= "whispers" and name ~= "whisperWindows" and frame and frames[frame] and #lines > 0 then
			-- Back-filling pushes each line above what's already there, so newest first.
			frame:BackFillMessage(UI.Wrap(UI.colors.dim, "- - -   earlier   - - -"), 1, 1, 1)
			for i = #lines, 1, -1 do
				local line = lines[i]
				F.BackFill(frame, line.m, line.r, line.g, line.b, line.t, line.e, line.a)
			end
		end
	end
end

-- Duplicate filter: same text from the same sender within N seconds (filters never see secret lines)

local recent = {}

local function SpamFilter(_, _, msg, author, ...)
	if not db.spam or Shy.IsMe(author) then return false end
	local lineID = select(9, ...)
	local key = author .. "\n" .. msg
	local seen = recent[key]
	local now = GetTime()
	if seen and seen.line ~= lineID and now - seen.time < db.spamWindow then
		return true
	end
	if not seen or seen.line ~= lineID then recent[key] = { time = now, line = lineID } end
	return false
end

local function PruneSpam()
	local now = GetTime()
	for key, seen in pairs(recent) do
		if now - seen.time > 300 then recent[key] = nil end
	end
end

-- The tab's right-click menu: the game's is closed as it opens (FCF_Tab_SetupMenu) and ShyChat's
-- takes its place. Locking, undocking, renaming, opening and closing windows change the dock, which
-- only the game may touch (Look.lua), so one row runs the game's own menu through a secure
-- right-click of the tab (/click), and the hook lets that one be.
local CLICK_TAB = "/click %sTab RightButton"

local function SetTextSize(frame, height)
	local file, _, flags = frame:GetFont()
	frame:SetFont(file, height, flags)
	SetChatWindowSize(frame:GetID(), height)
end

-- The window's text sizes under a "Text size" row (a conversation's menu has them too: its words are its chat's).
function W.SizeRows(root, frame)
	local size = root:CreateButton("Text size")
	local _, current = frame:GetFont()
	current = current and math.floor(current + 0.5)
	for _, height in ipairs(CHAT_FONT_HEIGHTS) do
		size:CreateRadio(tostring(height), function() return height == current end, function() SetTextSize(frame, height) end)
	end
end

local SELECT_TAB = "/click %sTab LeftButton"

-- A window's name for a menu: a whisper tab's can be secret.
local function WindowName(tab)
	local name = tab and tab:GetText()
	if name == nil or issecretvalue(name) or name == "" then return "Chat window" end
	return name
end

local function Gold(text)
	local c = UI.colors.alert
	return ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5),
		math.floor(c[3] * 255 + 0.5), text)
end

-- The docked tabs in their order, each a secure row that clicks its tab (the game's own switch): the
-- way to any tab once the row is full. The open one says so; one with new lines says so in gold.
local function TabRows(root)
	local dock = GeneralDockManager
	local list = type(dock) == "table" and dock.DOCKED_CHAT_FRAMES
	if type(list) ~= "table" then return end
	local Wh = ns.Whispers
	local docked = Wh and Wh.InChat and Wh.InChat() or 0
	if #list + docked < 2 then return end
	local covering = Wh and Wh.Covering and Wh.Covering()
	root:CreateTitle("Tabs")
	for _, other in ipairs(list) do
		local tab = _G[other:GetName() .. "Tab"]
		local row = root:CreateButton(WindowName(tab))
		row:SetSecure({ type = "macro", macrotext = SELECT_TAB:format(other:GetName()) })
		if other == dock.selected and not covering then
			row:SetDetail("open")
		elseif tab and (Look.Unread(other) or ChatFrameUtil.IsTabAlerting(tab)) then
			row:SetDetail(Gold("new"))
		end
	end
	if docked > 0 then Wh.MenuRows(root) end
	root:CreateDivider()
end

-- The rows every chat menu shares: this window's tools, then the game's own.
-- (A conversation docked over the window's text: copying and clearing are the conversation's, and its words wear the
-- window's size, so the window's size is set as ever.)
local function MenuRows(root, frame)
	local Wh = ns.Whispers
	local over = Wh and Wh.Over and Wh.Over(frame)
	root:CreateButton("Copy chat", function() if over then Wh.CopyOpen() else W.CopyFrame(frame) end end)
	root:CreateButton("Clear window", function() if over then Wh.ClearOpen() else W.Clear(frame) end end)
	W.SizeRows(root, frame)
	root:CreateDivider()
	root:CreateButton("Settings", function() ns.T:OpenOptions() end)
	root:CreateButton("Channels", function() ToggleChannelFrame() end)
	root:CreateButton("Messages and colors", function() ShowUIPanel(ChatConfigFrame) end)
		:SetSub("The game's own: what each tab shows")
	root:CreateDivider()
	if frame == DEFAULT_CHAT_FRAME then
		root:CreateButton("Layout mode"):SetSecure({ type = "macro", macrotext = SLASH_EDITMODE1 })
	end
	local more = root:CreateButton("Window options")
	more:SetSub("The game's own: lock, rename, background, close")
	more:SetSecure({ type = "macro", macrotext = CLICK_TAB:format(frame:GetName()) })
end

local function TabMenu(tab, frame)
	UI.ContextMenu(tab, function(root)
		root:CreateTitle(WindowName(tab))
		MenuRows(root, frame)
	end)
end

-- The gear's menu: every tab, then the window's rows. Open already: it closes.
function W.ChatMenu(owner, frame)
	if UI.MenuOwner() == owner then
		UI.CloseMenu()
		return
	end
	UI.DropMenu(owner, function(root)
		TabRows(root)
		MenuRows(root, frame)
	end)
end

local function OnTabMenu(tab)
	local frame = tabs[tab]
	if not frame then return end
	-- ShyChat's "Window options" row asked for the game's menu: it stands, ShyChat's goes.
	if UI.MenuOwner() == tab then
		UI.CloseMenu()
		return
	end
	Menu.GetManager():CloseMenus()
	TabMenu(tab, frame)
end

function W.Init(settings)
	db = settings
	W.SetupAll()
	hooksecurefunc("FCF_OpenTemporaryWindow", W.SetupAll)
	hooksecurefunc("FCF_OpenNewWindow", W.SetupAll)
	hooksecurefunc("FCF_Tab_SetupMenu", OnTabMenu)

	EventRegistry:RegisterCallback("SetItemRef", OnLinkClick, W)
	EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkEnter", OnLinkEnter, W)
	EventRegistry:RegisterCallback("ChatFrame.OnHyperlinkLeave", OnLinkLeave, W)
	-- Name completion flips the arrow-key mode while open; put it back on focus.
	EventRegistry:RegisterCallback("ChatFrame.OnEditBoxFocusGained", function(_, editBox)
		editBox:SetAltArrowKeyMode(not db.arrowKeys)
	end, W)

	for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL" }) do
		ChatFrameUtil.AddMessageEventFilter(event, SpamFilter)
	end

	local elapsed = 0
	local driver = CreateFrame("Frame")
	local look = Shy.Clocked("chat: the windows looked at", function() W.Tick() end)
	driver:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.05 then return end
		elapsed = 0
		look()
	end)
	C_Timer.NewTicker(60, PruneSpam)
end
