-- The options page: message templates with a live preview, the one-click
-- replies, channels, the Group Finder takeover and extra dungeon names.

local ADDON, ns = ...
local T, D, W = ns.T, ns.Data, ns.W
local UI = Shy.UI
local C = UI.colors

local LEFT, RIGHT, COL, WIDE = 24, 334, 280, 590
local MAX_REPLIES = 8
-- A group of three for the preview, with a tank and two damage dealers still wanted.
local SAMPLE = { dungeon = "Deadmines", count = 3, size = 5, need = "tank, 2 DPS" }
local MISSING = { tank = 1, healer = 0, dps = 2 }
local PEOPLE = {
	{ name = "Ann", class = "WARRIOR", label = "TO A WARRIOR" },
	{ name = "Bo", class = "DRUID", label = "TO A DRUID" },
	{ name = "Cy", class = "MAGE", roles = { dps = true }, label = "TO A MAGE" },
}
local ACTS = {
	{ value = "send", text = "Just send" },
	{ value = "invite", text = "Send, then invite" },
	{ value = "pass", text = "Send, then move on" },
}

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local db
	local group = UI.Group(function() T:Apply() end)
	local preview, channels, wordsKey

	-- With no run, the preview uses SAMPLE.
	local function Example(template, extra)
		local vars = {}
		if not ns.Run.Get() then
			for k, v in pairs(SAMPLE) do vars[k] = v end
		end
		for k, v in pairs(extra or {}) do vars[k] = v end
		return ns.Run.Fill(template, vars)
	end

	local function Build()
		db = T.db
		UI.PageHeader(panel, T)

		-- Preview: what three different people would be asked, your post, and a group.
		preview = CreateFrame("Frame", nil, panel)
		preview:SetPoint("TOPLEFT", LEFT, -112)
		preview:SetSize(WIDE, 112)
		UI.Skin(preview)
		local lines = {}
		local function Line(i)
			local y = -12 - (i - 1) * 20
			local head = UI.Text(preview, "", 11, false, C.dim)
			head:SetPoint("TOPLEFT", 12, y)
			local text = W.ChatText(preview, C.text, true)
			text:SetPoint("TOPLEFT", 118, y)
			text:SetWidth(WIDE - 130)
			text:SetWordWrap(false)
			lines[i] = { head = head, text = text }
		end
		for i = 1, 5 do Line(i) end
		function preview:Refresh()
			local templates = db.templates
			local run = ns.Run.Get()
			local missing = run and ns.Run.Missing() or MISSING
			for i, who in ipairs(PEOPLE) do
				lines[i].head:SetText(who.label)
				-- The same words Ask would send them, for the sample group when there is no run.
				local text = ns.Run.AskText(who, nil, missing)
				if not run then
					text = text:gsub("{(%w+)}", "")
				end
				lines[i].text:SetText(run and text or (function()
					local can = ns.Run.RolesFor(who, missing)
					local vars = { name = who.name }
					if #can == 0 then return Example(templates.ask, vars) end
					if #can == 1 then
						vars.role = ns.Run.ARTICLE[can[1]]
						return Example(templates.askRole, vars)
					end
					local words = {}
					for j, r in ipairs(can) do words[j] = ns.Run.ARTICLE[r] end
					if #can == 2 then
						vars.roles = ns.Run.Or(words)
						return Example(templates.askChoice, vars)
					end
					for j, r in ipairs(can) do words[j] = ns.Run.BARE[r] end
					vars.choices = ns.Run.Or(words)
					return Example(templates.askFlexible, vars)
				end)())
			end
			lines[4].head:SetText("YOU POST")
			lines[4].text:SetText(Example(templates.post))
			lines[5].head:SetText("TO A GROUP")
			lines[5].text:SetText(Example(templates.join, { name = "Dee", myroles = ns.Run.MyRoles() }))
		end
		group:Add(preview)

		-- Messages
		local messages = UI.Header(panel, "Your messages", WIDE)
		messages:SetPoint("TOPLEFT", LEFT, -240)
		local words = UI.Text(panel, "Type anything. Words in braces fill in when you send; hover a line to see what each one says.", 12, false, C.dim)
		words:SetPoint("TOPLEFT", messages, "BOTTOMLEFT", 0, -8)
		words:SetWidth(WIDE)
		words:SetJustifyH("LEFT")

		-- Each wording: its box, the legend on hover, and Reset while it differs from the default.
		local last = words
		local function Template(key, label, desc)
			local function Set(v)
				db.templates[key] = v
				T:Apply()
			end
			local input = group:Input(panel, label, function() return db.templates[key] end, function(v)
				db.templates[key] = v
			end, { width = WIDE - 158, live = true, maxLetters = 200 })
			input:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
			W.Legend(input.box, key ~= "post", desc)
			local words = W.MenuButton(panel, "Words", 84, W.WordsWriter(input.box, key ~= "post", Set),
				"Each word in braces and what it says right now. Click one to put it in the wording.")
			words:SetHeight(24)
			words:SetPoint("BOTTOMLEFT", input, "BOTTOMRIGHT", 8, 0)
			local reset = UI.Button(panel, "Reset", 58, function() Set(T.defaults.templates[key]) end)
			reset:SetPoint("LEFT", words, "RIGHT", 8, 0)
			W.Tip(reset, "Reset", function() return "Back to the default wording: " .. T.defaults.templates[key] end)
			function reset:Refresh() self:SetShown(db.templates[key] ~= T.defaults.templates[key]) end
			group:Add(reset)
			last = input
		end
		Template("ask", "Asking someone along", "When they can't fill any open role. {group} says how many of you there are, or nothing when you're alone.")
		Template("askRole", "Asking for one role", "When one open role fits them, or you picked a role. {role} becomes \"a tank\", \"a healer\" or \"a dps\".")
		Template("askChoice", "Offering two roles", "When two open roles fit them. {roles} becomes \"a tank or a dps\".")
		Template("askFlexible", "Asking what they'd rather play", "When three open roles fit them, as for a druid. {choices} becomes \"tank, heal or dps\".")
		Template("post", "Your chat post", "What Post sends to chat. {need} lists the roles still missing; {tally} is \"(3/5)\", or nothing when you're alone.")
		Template("join", "Asking a group for a spot", "The whisper Ask to join sends. {myroles} is what you ticked as your roles.")

		-- Replies: one-click lines in a conversation, each with what it does next.
		local repliesHeader = UI.Header(panel, "Your replies", WIDE)
		repliesHeader:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -22)
		local repliesNote = UI.Text(panel, "One click sends the line. A reply can also invite them, or take them off your lists. A role question shows up by itself when a role fits them.", 12, false, C.dim)
		repliesNote:SetPoint("TOPLEFT", repliesHeader, "BOTTOMLEFT", 0, -8)
		repliesNote:SetWidth(WIDE)
		repliesNote:SetJustifyH("LEFT")

		local editor = CreateFrame("Frame", nil, panel)
		editor:SetPoint("TOPLEFT", repliesNote, "BOTTOMLEFT", 0, -10)
		editor:SetSize(WIDE, 10)
		editor.rows = {}
		local add = UI.Button(editor, "Add a reply", 110, function()
			if #db.replies >= MAX_REPLIES then return end
			table.insert(db.replies, { text = "", act = "send" })
			T:Apply()
		end)
		-- The shipped set back, for a line taken out or edited past recognition.
		local restore = UI.Button(editor, "Reset replies", 110, function() end)
		restore:SetPoint("LEFT", add, "RIGHT", 10, 0)
		UI.Twice(restore, function()
			db.replies = Shy.CopyTable(T.defaults.replies)
			T:Apply()
		end)
		W.Tip(restore, "Reset replies", "Puts the default replies back in place of yours. Asks twice.")
		function editor:Refresh()
			local replies = db.replies
			for i = 1, math.max(#replies, #self.rows) do
				local row = self.rows[i]
				if not row and i <= #replies then
					row = CreateFrame("Frame", nil, self)
					row:SetSize(WIDE, 26)
					row:SetPoint("TOPLEFT", 0, -(i - 1) * 30)
					row.text = UI.Input(row, nil, function() return replies[i] and replies[i].text or "" end, function(v)
						if db.replies[i] then
							db.replies[i].text = v
							T:Apply()
						end
					end, { width = 340, maxLetters = 200, placeholder = function() return "A line to send in one click" end })
					row.text:SetPoint("LEFT")
					row.act = UI.Dropdown(row, "", ACTS, function() return db.replies[i] and db.replies[i].act or "send" end, function(v)
						if db.replies[i] then
							db.replies[i].act = v
							T:Apply()
						end
					end, { width = 190, desc = "What happens after the line is sent." })
					-- A dropdown carries a label line above its box: bottoms line up.
					row.act:SetPoint("BOTTOMLEFT", row.text, "BOTTOMRIGHT", 10, 0)
					-- Level with the boxes (a dropdown carries a label line above its box); asks twice.
					row.remove = UI.Button(row, "x", 24, function() end)
					row.remove:SetPoint("BOTTOMLEFT", row.act, "BOTTOMRIGHT", 8, 0)
					UI.Twice(row.remove, function()
						table.remove(db.replies, i)
						T:Apply()
					end)
					W.Tip(row.remove, "Remove", "Takes this reply out. Asks twice; Reset replies brings the defaults back.")
					self.rows[i] = row
				end
				if row then
					row:SetShown(i <= #replies)
					if i <= #replies then
						row.text:Refresh()
						row.act:Refresh()
					end
				end
			end
			add:ClearAllPoints()
			add:SetPoint("TOPLEFT", 0, -#replies * 30)
			add:SetShown(#replies < MAX_REPLIES)
			restore:ClearAllPoints()
			restore:SetPoint("TOPLEFT", #replies < MAX_REPLIES and 120 or 0, -#replies * 30)
			self:SetHeight(#replies * 30 + 30)
		end
		group:Add(editor)

		-- Replies (left column)
		local replies = UI.Header(panel, "Replies", COL)
		replies:SetPoint("TOPLEFT", editor, "BOTTOMLEFT", 0, -22)

		local collect = group:Dropdown(panel, "Keep whispers in Replies", {
			{ value = "run", text = "While I'm recruiting" },
			{ value = "always", text = "Always" },
		}, function() return db.collect end, function(v) db.collect = v end,
			{ width = COL, desc = "Whispers from people you asked are always kept. This sets when whispers from anyone else are kept too." })
		collect:SetPoint("TOPLEFT", replies, "BOTTOMLEFT", 0, -12)

		local auto = group:Checkbox(panel, "Auto-invite on yes",
			function() return db.autoInvite end, function(v) db.autoInvite = v end,
			{ desc = "Invites someone you asked when they reply with a clear yes (\"sure\", \"inv\", \"ok\"), if there's room and you can invite." })
		auto:SetPoint("TOPLEFT", collect, "BOTTOMLEFT", 0, -12)

		local screen = UI.Header(panel, "On screen", COL)
		screen:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -22)
		local pill = group:Checkbox(panel, "Status box",
			function() return db.pill end, function(v) db.pill = v end,
			{ desc = "Shows your run, group size and unread replies while the window is closed. Click it and the window opens." })
		pill:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -12)
		local minimap = group:Checkbox(panel, "Minimap button",
			function() return db.minimap end, function(v) db.minimap = v end,
			{ desc = "Click to open or close the window. Shows how many replies are unread." })
		minimap:SetPoint("TOPLEFT", pill, "BOTTOMLEFT", 0, -8)
		local arrange = Shy.HUD.LayoutButton(panel, 130)
		arrange:SetPoint("TOPLEFT", minimap, "BOTTOMLEFT", 0, -12)
		local open = UI.Button(panel, "Open ShyGroup", 130, function()
			Shy.Hub.Close()
			ns.Window.SetOpen(true, nil, true)
		end)
		open:SetPoint("LEFT", arrange, "RIGHT", 10, 0)

		local finder = UI.Header(panel, "Group Finder", COL)
		finder:SetPoint("TOPLEFT", arrange, "BOTTOMLEFT", 0, -22)
		local takeover = group:Checkbox(panel, "Replace the Group Finder",
			function() return db.takeover end, function(v) db.takeover = v end,
			{ desc = "The Group Finder keybind, menu button and minimap eye open ShyGroup instead. Its Who tab stays the game's own, one click away, and the default window opens from your listing's ... menu." })
		takeover:SetPoint("TOPLEFT", finder, "BOTTOMLEFT", 0, -12)

		-- Finding people (right column)
		local finding = UI.Header(panel, "Finding people", COL)
		finding:SetPoint("TOPLEFT", replies, "TOPLEFT", RIGHT - LEFT, 0)

		local expire = group:Slider(panel, "Forget chat posts after", 2, 15, 1,
			function() return db.expire end, function(v) db.expire = v end,
			{ width = COL, format = function(v) return v .. " min" end,
				desc = "A post is removed if it isn't reposted within this time." })
		expire:SetPoint("TOPLEFT", finding, "BOTTOMLEFT", 0, -12)

		local language = group:Checkbox(panel, "Only posts I can read",
			function() return db.myLanguage end, function(v) db.myLanguage = v end,
			{ desc = "Hides posts in a language other than your client's. English always shows." })
		language:SetPoint("TOPLEFT", expire, "BOTTOMLEFT", 0, -12)

		-- Joined channels, each with a read and a post switch.
		channels = CreateFrame("Frame", nil, panel)
		channels:SetPoint("TOPLEFT", language, "BOTTOMLEFT", 0, -16)
		channels:SetSize(COL, 10)
		local name = UI.Text(channels, "CHANNEL", 10, false, C.dim)
		name:SetPoint("TOPLEFT")
		local read = UI.Text(channels, "READ", 10, false, C.dim)
		read:SetPoint("TOPLEFT", 174, 0)
		local post = UI.Text(channels, "POST", 10, false, C.dim)
		post:SetPoint("TOPLEFT", 230, 0)
		channels.rows = {}
		function channels:Refresh()
			local list = ns.Run.Channels()
			for i, channel in ipairs(list) do
				local row = self.rows[i]
				if not row then
					row = CreateFrame("Frame", nil, self)
					row:SetSize(COL, 24)
					row:SetPoint("TOPLEFT", 0, -18 - (i - 1) * 26)
					row.label = UI.Text(row, "", 13)
					row.label:SetPoint("LEFT")
					row.label:SetWidth(162)   -- a long channel name ends before the switches
					row.label:SetJustifyH("LEFT")
					row.label:SetWordWrap(false)
					row.read = UI.Switch(row, "Read this channel", function() return not db.skipChannels[row.channel] end, function(v)
						db.skipChannels[row.channel] = not v or nil
						T:Apply()
					end, { desc = "Posts in this channel show up on the Browse tab and as candidates on the Run tab." })
					row.read:SetPoint("LEFT", 170, 0)
					row.post = UI.Switch(row, "Post in this channel", function() return ns.Run.PostsIn(row.channel) end, function(v)
						db.postChannels[row.channel] = v
						T:Apply()
					end, { desc = "Post sends your chat post to this channel." })
					row.post:SetPoint("LEFT", 226, 0)
					self.rows[i] = row
				end
				row.channel = channel.name
				row.label:SetText(channel.name)
				row.read:Refresh()
				row.post:Refresh()
				row:Show()
			end
			for i = #list + 1, #self.rows do self.rows[i]:Hide() end
			self:SetHeight(18 + #list * 26)
		end
		group:Add(channels)

		local extra = UI.Header(panel, "Extra dungeon names", COL)
		extra:SetPoint("TOPLEFT", channels, "BOTTOMLEFT", 0, -22)
		wordsKey = (ns.Run.Get() and D.byKey[ns.Run.Get().key] and ns.Run.Get().key) or D.list[1].key
		local pick = UI.Button(panel, "", COL, function(self)
			Shy.UI.DropMenu(self, function(root)
				root:SetScrollMode(420)
				for _, d in ipairs(D.list) do
					root:CreateButton(d.name, function()
						wordsKey = d.key
						group:Refresh()
					end)
				end
			end)
		end)
		pick:SetPoint("TOPLEFT", extra, "BOTTOMLEFT", 0, -12)
		function pick:Refresh() self.text:SetText(D.byKey[wordsKey].name) end
		group:Add(pick)
		local more = group:Input(panel, nil, function() return db.extraWords[wordsKey] or "" end, function(v)
			db.extraWords[wordsKey] = strtrim(v) ~= "" and v or nil
		end, { width = COL, maxLetters = 120, placeholder = function() return "other names, separated by commas" end,
			desc = "Other names players on your realm use for this dungeon in chat, separated by commas. The common ones are built in." })
		more:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -8)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
	end)

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then group:Refresh() end
	end
	return panel
end
