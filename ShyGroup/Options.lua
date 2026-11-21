-- Settings: your messages and quick replies, the whispers you keep, the chat posts you read, what is on
-- screen and the Group Finder.

local ADDON, ns = ...
local T, D, W = ns.T, ns.Data, ns.W
local UI = Shy.UI
local C = UI.colors

ns.RefreshOptions = Shy.Settings.Refresh
-- A change made in the window, a menu or the chat channels shows here too.
ns.OnChange(Shy.Settings.Refresh)

-- PICK: the message picker; WORDS, RESET: the buttons beside it; GAP: between two of them; LINE: the top
-- row; LINES: the box's lines; INSET: the box's own margin; WHEN: the line under the box.
local M = { PICK = 220, WORDS = 84, RESET = 58, GAP = 8, LINE = 24, LINES = 2, INSET = 12, WHEN = 12, UNDER = 5 }
-- ROW: a reply's line; STEP: from one to the next; ACT: what it does next; X: the button that removes it;
-- ADD: the buttons under the list; MOST: how many replies there can be.
local R = { ROW = 24, STEP = 26, ACT = 170, X = 24, GAP = 6, ADD = 110, MOST = 8 }

local MESSAGES = {
	{ value = "ask", text = "Asking someone along", when = "Whispered when no open role fits them." },
	{ value = "askRole", text = "Asking for one role", when = "Whispered when one open role fits them, or you picked the role." },
	{ value = "askChoice", text = "Offering two roles", when = "Whispered when two open roles fit them." },
	{ value = "askFlexible", text = "Asking what they'd play", when = "Whispered when three open roles fit them, like a druid." },
	{ value = "post", text = "Your chat post", when = "What Post sends to chat. You can write it on the Run tab too." },
	{ value = "join", text = "Asking a group for a spot", when = "Whispered by Ask to join." },
}
local ACTS = {
	{ value = "send", text = "Just send" },
	{ value = "invite", text = "Send, then invite" },
	{ value = "pass", text = "Send, then move on" },
}

-- What you were typing is kept before the line it was typed for changes.
local function Settle()
	local typing = GetCurrentKeyBoardFocus()
	if typing then typing:ClearFocus() end
end

-- Your messages: pick one, write it. Words drops a word in braces in. Reset shows while it isn't the default.
local function MessageEditor(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local at = MESSAGES[1]
	local box
	local function Set(text)
		T.db.templates[at.value] = text
		ns.Changed()
		f:Refresh()
	end
	local pick = UI.Dropdown(f, nil, MESSAGES, function() return at.value end, function(value)
		for _, message in ipairs(MESSAGES) do
			if message.value == value then at = message end
		end
		box.box:ClearFocus()
		f:Refresh()
	end, { width = M.PICK })
	pick:SetPoint("TOPLEFT")
	box = W.TextBox(f, width, { min = M.LINES, max = M.LINES }, function() return T.db.templates[at.value] end, Set)
	box:SetPoint("TOPLEFT", 0, -(M.LINE + M.GAP))
	local words = W.MenuButton(f, "Words", M.WORDS, function(root)
		W.WordsWriter(box.box, at.value ~= "post", Set)(root)
	end, "Each word in braces and what it says right now. Click one to put it in.")
	words:SetHeight(M.LINE)
	words:SetPoint("LEFT", pick, "RIGHT", M.GAP, 0)
	local reset = UI.Button(f, "Reset", M.RESET, function()
		box.box:ClearFocus()
		Set(T.defaults.templates[at.value])
	end)
	reset:SetPoint("LEFT", words, "RIGHT", M.GAP, 0)
	local when = UI.Text(f, "", 11, false, C.dim)
	when:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -M.UNDER)
	when:SetJustifyH("LEFT")
	when:SetWordWrap(false)

	function f:Fit(wide)
		self:SetSize(wide, M.LINE + M.GAP + box:GetHeight() + M.UNDER + M.WHEN)
		box:SetWidth(wide)
		box.content:SetWidth(wide - 14)
		box.box:SetWidth(wide - 18)
		when:SetWidth(wide)
	end
	function f:Refresh()
		pick:Refresh()
		box:Refresh()
		when:SetText(at.when)
		reset:SetShown(T.db.templates[at.value] ~= T.defaults.templates[at.value])
	end
	f.pick, f.box = pick, box
	f:Fit(width)
	return f
end

local function MessagesHeight()
	return M.LINE + M.GAP + M.LINES * W.LineHeight() + M.INSET + M.UNDER + M.WHEN
end

-- Your quick replies: a line each, what it does after it is sent, and a way to take it out.
local function ReplyEditor(parent, width)
	local f = CreateFrame("Frame", nil, parent)
	local rows = {}
	local wide = width
	local function Changed()
		ns.Changed()
		f:Refresh()
	end
	local add = UI.Button(f, "Add a reply", R.ADD, function()
		if #T.db.replies >= R.MOST then return end
		table.insert(T.db.replies, { text = "", act = "send" })
		Changed()
	end)
	local restore = UI.Button(f, "Reset replies", R.ADD, function() end)
	UI.Twice(restore, function()
		Settle()
		T.db.replies = Shy.CopyTable(T.defaults.replies)
		Changed()
	end)
	W.Tip(restore, "Reset replies", "Puts the replies you started with back in place of yours.")

	local function Row(i)
		local row = CreateFrame("Frame", nil, f)
		row:SetPoint("TOPLEFT", 0, -(i - 1) * R.STEP)
		row.text = UI.Input(row, nil, function() return T.db.replies[i] and T.db.replies[i].text or "" end, function(text)
			if not T.db.replies[i] then return end
			T.db.replies[i].text = text
			Changed()
		end, { width = 200, maxLetters = 200, placeholder = function() return "A line to send in one click" end })
		row.text:SetPoint("LEFT")
		row.act = UI.Dropdown(row, nil, ACTS, function() return T.db.replies[i] and T.db.replies[i].act or "send" end, function(act)
			if not T.db.replies[i] then return end
			T.db.replies[i].act = act
			Changed()
		end, { width = R.ACT, desc = "What happens after the line is sent." })
		row.act:SetPoint("LEFT", row.text, "RIGHT", R.GAP, 0)
		row.remove = UI.Button(row, "x", R.X, function() end)
		row.remove:SetPoint("LEFT", row.act, "RIGHT", R.GAP, 0)
		UI.Twice(row.remove, function()
			Settle()
			if not T.db.replies[i] then return end
			table.remove(T.db.replies, i)
			Changed()
		end)
		W.Tip(row.remove, "Remove", "Takes this reply out.")
		function row:Fit(to)
			local room = to - R.ACT - R.X - R.GAP * 2
			self:SetSize(to, R.ROW)
			self.text:SetWidth(room)
			self.text.box:SetWidth(room)
		end
		row:Fit(wide)
		rows[i] = row
		return row
	end

	function f:Fit(to)
		wide = to
		for _, row in ipairs(rows) do row:Fit(to) end
		self:SetWidth(to)
	end
	function f:Refresh()
		local count = #T.db.replies
		for i = 1, math.max(count, #rows) do
			local row = rows[i] or (i <= count and Row(i))
			if row then
				row:SetShown(i <= count)
				if i <= count then
					row.text:Refresh()
					row.act:Refresh()
				end
			end
		end
		local room = count < R.MOST
		add:SetShown(room)
		add:ClearAllPoints()
		add:SetPoint("TOPLEFT", 0, -count * R.STEP)
		restore:ClearAllPoints()
		restore:SetPoint("TOPLEFT", room and (R.ADD + R.GAP) or 0, -count * R.STEP)
		self:SetHeight(count * R.STEP + R.ROW)
	end
	f.rows = rows
	f:SetSize(width, R.ROW)
	return f
end

local function RepliesHeight()
	return #T.db.replies * R.STEP + R.ROW
end

-- The channels you are in: which you read posts from, and which your own post goes to.
local function Reads(name) return not T.db.skipChannels[name] end
local function Posts(name) return ns.Run.PostsIn(name) end

local function Joined()
	if #ns.Run.Channels() > 0 then return true end
	return false, "Join a chat channel first."
end

local function ChannelSays(on)
	return function()
		local list, count, last = ns.Run.Channels(), 0, nil
		if #list == 0 then return "None joined" end
		for _, channel in ipairs(list) do
			if on(channel.name) then count, last = count + 1, channel.name end
		end
		if count == 0 then return "None" end
		if count == 1 then return last end
		if count == #list then return "All" end
		return count .. " of " .. #list
	end
end

local function ChannelMenu(title, on, toggle)
	return function(button)
		UI.DropMenu(button, function(root)
			root:CreateTitle(title)
			for _, channel in ipairs(ns.Run.Channels()) do
				local name = channel.name
				root:CreateCheckbox(name, function() return on(name) end, function()
					toggle(name, not on(name))
					Shy.Settings.Refresh()
				end)
			end
		end)
	end
end

-- Other names for a dungeon: the one picked here is the one the names are typed for.
local picked
local dungeons = {}

local function Picked()
	if not (picked and D.byKey[picked]) then
		local run = ns.Run.Get()
		picked = run and D.byKey[run.key] and run.key or (D.list[1] and D.list[1].key)
	end
	return picked
end

local function Dungeons()
	if #dungeons ~= #D.list then
		wipe(dungeons)
		for i, d in ipairs(D.list) do dungeons[i] = { value = d.key, text = d.name } end
	end
	return dungeons
end

T:Settings({
	apply = function() ns.Changed() end,
	reset = function()
		T:ResetDB()
		picked = nil
		T:Apply()
	end,

	{ section = "Your messages" },
	{ build = MessageEditor, height = MessagesHeight, words = "templates wording whisper ask post invite braces words" },
	{ note = "Words in braces fill in as you send. Words lists each one and what it says right now." },

	{ section = "Quick replies" },
	{ build = ReplyEditor, height = RepliesHeight, words = "replies one click answer line invite pass" },
	{ note = "In a conversation, one click sends a reply. It can also invite them or take them off your lists." },

	{ section = "Whispers" },
	{ key = "collect", label = "Keep whispers", words = "replies tab save",
		items = { { value = "run", text = "While recruiting" }, { value = "always", text = "Always" } },
		desc = "Whispers from people you asked always go to Replies. This is for whispers from anyone else." },
	{ key = "autoInvite", label = "Invite on yes", words = "auto invite",
		desc = "Invites someone you asked as soon as they say a clear yes, like \"sure\" or \"inv\"." },

	{ section = "Chat posts" },
	{ key = "expire", label = "Forget posts after", min = 2, max = 15, step = 1, format = function(v) return v .. " min" end,
		apply = function() ns.Board.Prune() end,
		desc = "A post drops off your list if nobody reposts it in this time." },
	{ key = "myLanguage", label = "Posts you can read", words = "language foreign",
		desc = "Hides posts in a language other than your game's. English always shows." },
	{ label = "Channels you read", button = "Pick", words = "lfg lookingforgroup trade general world",
		enabled = Joined, says = ChannelSays(Reads),
		run = ChannelMenu("Channels you read", Reads, function(name, on)
			T.db.skipChannels[name] = not on or nil
			ns.Board.Prune()
		end),
		desc = "Posts in these channels show up on Browse and as people to ask." },
	{ label = "Channels you post in", button = "Pick", words = "lfg lookingforgroup trade general world",
		enabled = Joined, says = ChannelSays(Posts),
		run = ChannelMenu("Channels you post in", Posts, function(name, on)
			T.db.postChannels[name] = on
			ns.Changed()
		end),
		desc = "Post sends your chat post to each of these." },
	{ label = "Other names for", items = Dungeons, default = Picked, get = Picked,
		set = function(key)
			Settle()
			picked = key
		end,
		words = "extra dungeon names abbreviation short",
		desc = "Pick a dungeon, then type what players call it in chat." },
	{ label = "Its other names", sub = true, text = true, maxLetters = 120, placeholder = "names, with commas", default = "",
		words = "extra dungeon names abbreviation short",
		get = function() return T.db.extraWords[Picked()] or "" end,
		set = function(text) T.db.extraWords[Picked()] = strtrim(text) ~= "" and text or nil end,
		apply = function() T:Apply() end,
		desc = "Put a comma between them. The common ones are built in." },

	{ section = "On screen" },
	{ key = "pill", label = "Run status", words = "status box notice",
		desc = "Shows your run, group size and unread replies while the window is closed." },
	{ key = "minimap", label = "Minimap button", desc = "Opens and closes the window, and counts your unread replies." },

	{ section = "Group Finder" },
	{ key = "takeover", label = "Replace the Group Finder", words = "lfg eye keybind",
		desc = "The Group Finder's key, menu button and minimap eye open your group window instead." },
	{ note ="The game's own Group Finder is still a click away, in your listing's ... menu." },
})
