-- The Run tab. Without a run: your roles, the Group Finder's categories and
-- everything in them with who's listed, one click to start. With a run, left:
-- the run, your roles, its Group Finder listing, the group, the chat post.
-- Right: candidates from the Group Finder, chat posts, Who and whispers, each
-- with one button (Ask, then Invite), and the groups you could join instead.

local ADDON, ns = ...
local T, D, W = ns.T, ns.Data, ns.W
local UI = Shy.UI
local C = UI.colors
local Run, People, Search, Board, Listing = ns.Run, ns.People, ns.Search, ns.Board, ns.Listing
local Rc = {}
ns.Recruit = Rc

local PAD, LEFT_W, GAP = 16, 264, 18
local RIGHT_X = PAD + LEFT_W + GAP
local RIGHT_W = ns.Window.WIDTH - RIGHT_X - PAD
local PAGE_W = ns.Window.WIDTH - PAD * 2
local PAGE_H = ns.Window.HEIGHT - ns.Window.HEADER
local LIST_TOP = 76
local FILTERS = { false, "tank", "healer", "dps", "groups" }
local GROUPS = 5   -- the Groups segment
-- Palette tables by reference, so they follow a theme change.
local GROUP, PLAYER = C.hot, C.good

local roleFilter = false
local filter, customName = "", ""

---------------------------------------------------------------------------
-- The start screen
---------------------------------------------------------------------------

local ROW_H = 30
local LIST_Y = 128

-- The categories to offer: the Group Finder's, and Custom even where it has none.
local function KindList()
	local out = {}
	for _, k in ipairs(D.kinds) do out[#out + 1] = k end
	if not D.category.custom then out[#out + 1] = { kind = "custom", name = D.KIND_NAME.custom } end
	return out
end

-- The category in view: what the player picked, if the game offers it.
local function ViewKind()
	local kind = ns.char.kind
	if kind == "custom" or (kind and D.category[kind]) then return kind end
	return Search.Kind()
end

local function Pick(key)
	Run.Start(key)
	Search.Auto()   -- from a click
end

local function CreateActivityRow(content)
	local row = W.Row(content)
	row.name = UI.Text(row, "", 13)
	row.name:SetPoint("LEFT", 12, 0)
	row.name:SetWidth(250)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.range = UI.Text(row, "", 12, false, C.dim)
	row.range:SetPoint("LEFT", 270, 0)
	row.where = UI.Text(row, "", 12, false, C.dim)
	row.where:SetPoint("LEFT", 340, 0)
	row.where:SetWidth(130)
	row.where:SetJustifyH("LEFT")
	row.where:SetWordWrap(false)
	row.groups = W.Chip(row)
	row.players = W.Chip(row)
	row.mine = W.Chip(row)
	row.go = W.Button(row, "Pick", 80, function() Pick(row.item.key) end, true)
	row.go:SetHeight(22)
	row.go:SetPoint("RIGHT", -8, 0)
	row:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then Pick(self.item.key) end
	end)
	row:HookScript("OnEnter", function(self)
		local item = self.item
		local d = item.d
		local rows = {}
		for i, post in ipairs(Search.For(d.key)) do
			if i > 6 then
				rows[#rows + 1] = { text = "and more", quiet = true, indent = 1 }
				break
			end
			local group = post.kind == "lfm"
			local right = group and post.count and post.size and post.size > 0 and (post.count .. "/" .. post.size)
				or (not group and next(post.roles) and W.RoleWords(post.roles)) or ""
			rows[#rows + 1] = { glyph = "star", tint = group and GROUP or PLAYER, color = { W.ClassColor(post.class) },
				text = post.name .. (group and "'s group" or ""), right = right, rightColor = C.dim }
		end
		local note = d.kind == "raid" and (d.size .. " players") or (d.min .. "-" .. d.max)
		if d.group then note = note .. "  \194\183  " .. d.group end
		local text = #rows == 0 and "Nobody listed or posting for it right now. Pick it to recruit, or to list yourself." or nil
		UI.Tip(self, d.name, text, { side = "LEFT", width = 262, note = note,
			sections = #rows > 0 and { { title = "Listed and posting", rows = rows } } or nil,
			hints = { { "left", "Pick" } } })
	end)
	row:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	return row
end

local function UpdateActivityRow(row, item)
	local d = item.d
	row.edge:SetColorTexture(0, 0, 0, 0)
	row.name:SetText(d.name)
	UI.Ink(row.name, item.fit and C.text or C.dim)
	row.range:SetText(d.kind == "raid" and (d.size .. " players") or (d.min .. "-" .. d.max))
	UI.Ink(row.range, item.above and C.alert or C.dim)
	row.where:SetText(d.group or "")
	row.groups:Set(item.groups > 0 and W.Plural(item.groups, "group") or nil, GROUP)
	row.players:Set(item.players > 0 and W.Plural(item.players, "player") or nil, PLAYER)
	row.mine:Set(item.listed and "Your listing" or nil, C.good)
	-- The chips stand in a row from the counts column, only those shown.
	local x = 480
	for _, chip in ipairs({ row.groups, row.players, row.mine }) do
		if chip:IsShown() then
			chip:ClearAllPoints()
			chip:SetPoint("LEFT", x, 0)
			x = x + chip:GetWidth() + 6
		end
	end
	row:SetAlpha(item.fit and 1 or 0.6)
end

-- At your level first; then below it, nearest first; then above it.
local function Tier(item)
	return item.fit and 1 or item.below and 2 or 3
end

local function SortActivities(a, b)
	local ta, tb = Tier(a), Tier(b)
	if ta ~= tb then return ta < tb end
	if ta == 2 and a.d.max ~= b.d.max then return a.d.max > b.d.max end
	if a.d.min ~= b.d.min then return a.d.min < b.d.min end
	return a.d.name < b.d.name
end

local function CreateStart(page)
	local start = CreateFrame("Frame", nil, page)
	start:SetAllPoints()

	-- Row 1: your roles, and the game's own window.
	local roles = W.RoleToggles(start, 20)
	roles:SetPoint("TOPLEFT", PAD, -14)
	local theirs = W.Button(start, "Default Group Finder", 150, function() Listing.OpenBlizzard() end)
	theirs:SetHeight(24)
	theirs:SetPoint("TOPRIGHT", -PAD, -17)
	W.Tip(theirs, "Default Group Finder", "Opens the game's own window: a description for your listing, a custom listing, or anything else it offers.")

	-- Row 2: the question; row 3: the categories and a search.
	local ask = UI.Text(start, "What are you after?", 22, true)
	ask:SetPoint("TOPLEFT", PAD, -58)
	local kindList = KindList()
	local labels = {}
	for i, k in ipairs(kindList) do labels[i] = k.name end
	local kinds = W.Segments(start, labels, function(i)
		ns.char.kind = kindList[i].kind
		Search.Look(ns.char.kind)   -- from a click
		ns.Changed()
	end)
	kinds:SetPoint("TOPLEFT", PAD, -94)
	local find = UI.Input(start, nil, function() return filter end, function(v)
		filter = strtrim(v):lower()
		ns.Changed()
	end, { width = 180, live = true, placeholder = function() return "Search..." end })
	find:SetPoint("TOPRIGHT", -PAD, -94)
	find:Refresh()

	local list = W.List(start, PAGE_W, PAGE_H - LIST_Y - 40, ROW_H, CreateActivityRow, UpdateActivityRow)
	list:SetPoint("TOPLEFT", PAD, -LIST_Y)
	local empty = UI.Text(start, "", 13, false, C.dim)
	empty:SetJustifyH("CENTER")
	empty:SetPoint("CENTER", list, "CENTER", 0, 0)

	-- Custom: a name of your own instead of a list.
	local custom = CreateFrame("Frame", nil, start)
	custom:SetPoint("TOPLEFT", PAD, -LIST_Y)
	custom:SetSize(PAGE_W, 120)
	local nameBox = UI.Input(custom, "Name your run", function() return customName end, function(v) customName = v end,
		{ width = 300, maxLetters = 40, placeholder = function() return "Elite quests in Westfall" end,
			desc = "Your chat post and whispers use this name." })
	nameBox:SetPoint("TOPLEFT", 0, 0)
	local go = W.Button(custom, "Start", 90, function()
		local name = strtrim(customName)
		Pick("custom")
		Run.Get().name = name ~= "" and name or "Group"
		ns.Changed()
	end, true)
	go:SetHeight(24)
	go:SetPoint("BOTTOMLEFT", nameBox, "BOTTOMRIGHT", 10, 0)
	local note = UI.Text(custom, "Your own run. The Group Finder lists it under Custom; you type its description in the default window.", 12, false, C.dim)
	note:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
	note:SetWidth(PAGE_W)
	note:SetJustifyH("LEFT")

	-- Foot: what the Group Finder said, and a fresh look.
	local foot = UI.Text(start, "", 12, false, C.dim)
	foot:SetPoint("BOTTOMLEFT", PAD, 12)
	local refresh = W.Button(start, "Refresh", 90, function() Search.Browse() end)
	refresh:SetHeight(24)
	refresh:SetPoint("BOTTOMRIGHT", -PAD, 10)
	refresh:SetMotionScriptsWhileDisabled(true)
	W.Tip(refresh, "Refresh", "Asks the Group Finder again. Listings update on their own after that; chat posts show up as people post them.")

	local function Foot(kind)
		local finder = Search.finder
		if not Listing.Available() then return "The Group Finder isn't open to you here. Chat posts still show." end
		if finder.state == "searching" then return "Asking the Group Finder..." end
		if finder.state == "failed" then return "The Group Finder didn't answer. Press Refresh to try again." end
		if finder.kind ~= kind or not finder.when then return "Press Refresh to see who's listed for " .. D.KindName(kind):lower() .. "." end
		local groups, players = 0, 0
		for _, post in ipairs(finder.all) do
			if post.kind == "lfm" then groups = groups + 1 else players = players + 1 end
		end
		return W.Plural(groups, "group") .. " and " .. W.Plural(players, "player") .. " listed for " .. D.KindName(kind):lower()
			.. "  \194\183  " .. W.When(finder.when)
	end

	function start:Refresh()
		roles:Refresh()
		local kind = ViewKind()
		for i, k in ipairs(kindList) do
			if k.kind == kind and kinds.selected ~= i then kinds:Select(i) end
		end
		local isCustom = kind == "custom"
		list:SetShown(not isCustom)
		find:SetShown(not isCustom)
		custom:SetShown(isCustom)
		if isCustom then
			nameBox:Refresh()
			empty:Hide()
		else
			local level = UnitLevel("player")
			local counts = Search.Counts()
			local listed = {}
			for _, d in ipairs(Listing.Dungeons()) do listed[d.key] = true end
			local rows = {}
			for _, d in ipairs(D.OfKind(kind)) do
				if filter == "" or d.name:lower():find(filter, 1, true) then
					local c = counts[d.key]
					local fit = D.Fits(d, level)
					rows[#rows + 1] = { key = d.key, d = d, groups = c and c.groups or 0, players = c and c.players or 0,
						listed = listed[d.key] or false, fit = fit, below = not fit and level > d.max, above = not fit and level < d.min }
				end
			end
			table.sort(rows, SortActivities)
			list:SetData(rows)
			empty:SetShown(#rows == 0)
			empty:SetText(filter ~= "" and "Nothing by that name." or "Nothing to pick here.")
		end
		foot:SetText(Foot(kind))
		local can = Listing.Available() and not isCustom
		refresh:SetShown(can)
		local wait = Search.LookWait()
		local searching = Search.finder.state == "searching"
		refresh.text:SetText(searching and "Searching..." or wait > 0 and ("Again in " .. wait .. "s") or "Refresh")
		refresh:SetOn(not searching and wait == 0)
	end
	return start
end

---------------------------------------------------------------------------
-- The run: the left column
---------------------------------------------------------------------------

-- Name, level range, size, your roles; Change and Finish.
local function CreateHead(left)
	local head = {}
	local runName = UI.Text(left, "", 19, true)
	runName:SetPoint("TOPLEFT", 0, -12)
	runName:SetWidth(LEFT_W)
	runName:SetJustifyH("LEFT")
	runName:SetWordWrap(false)
	local customName = UI.Input(left, nil, function() return Run.Get().name end, function(v)
		Run.Get().name = strtrim(v) ~= "" and strtrim(v) or "Group"
		ns.Changed()
	end, { width = LEFT_W, maxLetters = 40, desc = "Name of the run, used in your messages." })
	customName:SetPoint("TOPLEFT", 0, -14)
	local sub = UI.Text(left, "", 12, false, C.dim)
	sub:SetPoint("TOPLEFT", 0, -40)
	sub:SetWidth(LEFT_W - 150)
	sub:SetJustifyH("LEFT")
	sub:SetWordWrap(false)

	local finish = W.Button(left, "Finish", 58, function() Run.Stop() end)
	finish:SetHeight(20)
	finish:SetPoint("TOPRIGHT", 0, -38)
	UI.Twice(finish, function() Run.Stop() end)
	W.Tip(finish, "Finish", "Clears this run and its conversations, and removes your Group Finder listing. Asks twice.")
	local change = W.MenuButton(left, "Change", 86, function(root)
		root:CreateTitle("What are you running?")
		W.RunWriter(root)
	end, "Another dungeon, raid or zone. Your group and conversations stay.")
	change:SetHeight(20)
	change:SetPoint("RIGHT", finish, "LEFT", -6, 0)

	local roles = W.RoleToggles(left, 14)
	roles:SetPoint("TOPLEFT", 0, -66)

	function head:Refresh(run)
		local custom = run.key == "custom"
		runName:SetShown(not custom)
		customName:SetShown(custom)
		if custom then customName:Refresh() else runName:SetText(run.name) end
		local d = D.byKey[run.key]
		sub:SetText((d and d.kind == "raid" and "" or (run.min .. "-" .. run.max .. "  \194\183  ")) .. run.size .. " players")
		roles:Refresh()
	end
	return head
end

-- The Group Finder listing: its state, the one button, style and more, the description.
local function CreateListing(left)
	local block = {}
	local header = UI.Header(left, "Group Finder", LEFT_W)
	header:SetPoint("TOPLEFT", 0, -100)
	local card = CreateFrame("Frame", nil, left)
	card:SetPoint("TOPLEFT", 0, -126)
	card:SetSize(LEFT_W, 68)
	UI.Skin(card)

	local state = UI.Text(card, "", 12)
	state:SetPoint("TOPLEFT", 8, -7)
	state:SetWidth(LEFT_W - 44)
	state:SetJustifyH("LEFT")
	state:SetWordWrap(false)
	-- The line can be long ("Listed as tank, healer, dps  ·  Learning"): the whole of it on hover.
	local stateHit = CreateFrame("Frame", nil, card)
	stateHit:SetPoint("TOPLEFT", 4, -4)
	stateHit:SetSize(LEFT_W - 40, 18)
	stateHit:EnableMouse(true)
	W.Tip(stateHit, "Your listing", function() return state:GetText() end)

	local more = W.Button(card, "...", 22, function(self)
		Shy.UI.DropMenu(self, function(root)
			root:CreateTitle("Your listing")
			for _, style in ipairs(Listing.STYLES) do
				root:CreateRadio(style.text, function() return T.db.playstyle == style.value end, function()
					T.db.playstyle = style.value
					ns.Changed()
				end)
			end
			root:CreateDivider()
			root:CreateCheckbox("New players welcome", function() return T.db.friendly end, function()
				T.db.friendly = not T.db.friendly
				if Listing.State() == "run" then Listing.Post() end
				ns.Changed()
			end)
			root:CreateDivider()
			-- The game's box for it only exists while something is listed.
			if Listing.State() ~= "none" then
				root:CreateButton(Listing.Comment() and "Change the description..." or "Add a description...", function() Listing.OpenDescription() end)
			end
			root:CreateButton("Default Group Finder", function() Listing.OpenBlizzard() end)
		end)
	end)
	more:SetHeight(18)
	more:SetPoint("TOPRIGHT", -6, -5)
	W.Tip(more, "Your listing", "Your listing's style and whether new players are welcome. Once you're listed, you can open the default Group Finder window from here to type a description.")

	local act = W.Button(card, "", LEFT_W - 16, function(self)
		if self.remove then Listing.Remove() else Listing.Post() end
	end, true)
	act:SetPoint("TOPLEFT", 8, -27)
	act:SetMotionScriptsWhileDisabled(true)   -- the tooltip explains why it's disabled
	W.Tip(act, function(self) return self.text:GetText() end, function(self)
		local run = Run.Get()
		if self.remove then return "Removes your Group Finder listing. Finishing the run does this too." end
		if not Listing.CanEdit() then return "Only the group leader can list the group." end
		if run.key == "custom" then return "A custom listing is just a description, which you type in the default Group Finder window. This opens it." end
		if Run.IsFull() then return "Your group is full." end
		if Listing.State() == "other" then return "Your listing is for something else. This lists you for " .. run.name .. " instead." end
		local who = IsInGroup(LE_PARTY_CATEGORY_HOME) and "your group" or "you"
		return "Lists " .. who .. " in the Group Finder for " .. run.name .. ", as " .. Listing.StyleName()
			.. ". Groups and players listed for it show up here as they come."
	end)

	local desc = CreateFrame("Button", nil, card)
	desc:SetPoint("BOTTOMLEFT", 8, 3)
	desc:SetSize(LEFT_W - 16, 14)
	desc.text = W.ChatText(desc, C.dim, true)
	desc.text:SetPoint("LEFT")
	desc.text:SetWidth(LEFT_W - 16)
	desc.text:SetWordWrap(false)
	desc:SetScript("OnClick", function() Listing.OpenDescription() end)
	desc:SetScript("OnEnter", function(self) UI.Ink(self.text, C.hot) end)
	desc:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
	W.Tip(desc, "Description", "What your listing says. You can only type it in the default Group Finder window; this opens it with the box ready.")

	local function StateText(run, listing)
		if listing == "run" then
			local style = Listing.StyleName(Listing.Style())
			local roles = not IsInGroup(LE_PARTY_CATEGORY_HOME) and W.RoleWords(Listing.Roles()) or ""
			local text = IsInGroup(LE_PARTY_CATEGORY_HOME) and "Group listed" or (roles ~= "" and ("Listed as " .. roles) or "Listed")
			return style ~= "" and (text .. "  \194\183  " .. style) or text, C.good
		end
		if listing == "other" then
			local names = Listing.Dungeons()
			local what = names[1] and (names[1].name .. (#names > 1 and (" +" .. (#names - 1)) or "")) or "something else"
			return "Listed for " .. what, C.alert
		end
		if listing == "hidden" then return "Listed, but the details are hidden here", C.dim end
		if run.key == "custom" then return "Not listed. Custom runs are listed from the default window.", C.dim end
		return "Not in the Group Finder", C.dim
	end

	function block:Refresh(run)
		local can = Listing.Available()
		header:SetShown(can)
		card:SetShown(can)
		if not can then return end
		local listing = Listing.State()
		local text, color = StateText(run, listing)
		state:SetText(text)
		UI.Ink(state, color)
		local mine = Listing.CanEdit()
		act:SetShown(listing ~= "hidden")
		act.remove = listing == "run"
		if listing == "run" then
			act.text:SetText("Remove listing")
			act:SetPrimary(false)
			act:SetOn(mine)
		elseif listing == "other" then
			act.text:SetText("Update for " .. run.name)
			act:SetPrimary(true)
			act:SetOn(mine)
		else
			act.text:SetText(run.key == "custom" and "List in the default window" or Listing.Verb())
			act:SetPrimary(true)
			act:SetOn(mine and not Run.IsFull())
		end
		desc:SetShown(listing == "run" and mine)
		if listing == "run" then
			local comment = Listing.Comment()
			desc.text:SetText(comment or "Add a description...")
		end
	end
	return block
end

-- The group: how many of each role, the roster with its roles.
local function CreateGroup(left)
	local block = {}
	local header = UI.Header(left, "Group", LEFT_W)
	header:SetPoint("TOPLEFT", 0, -202)
	local count = UI.Text(left, "", 16, true)
	count:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 1)

	local roleRows = {}
	for i, role in ipairs(D.ROLES) do
		local f = CreateFrame("Frame", nil, left)
		f:SetSize(LEFT_W, 24)
		f:SetPoint("TOPLEFT", 0, -230 - (i - 1) * 26)
		f.icon = W.RoleIcon(f, 16)
		f.icon:SetPoint("LEFT")
		f.icon:SetRole(role)
		f.label = UI.Text(f, D.ROLE_NAME[role], 13)
		f.label:SetPoint("LEFT", 24, 0)
		f.count = UI.Text(f, "", 14, true)
		f.count:SetPoint("RIGHT", -84, 0)
		f.stepper = W.Stepper(f, function() return Run.Get().need[role] end, function(delta) Run.AdjustNeed(role, delta) end)
		f.stepper:SetPoint("RIGHT")
		f:EnableMouse(true)
		W.Tip(f, D.ROLE_NAME[role], "How many you have out of how many you want. Use - and + to change how many you want.")
		roleRows[role] = f
	end

	local rosterHeader = UI.Header(left, "In the group", LEFT_W)
	rosterHeader:SetPoint("TOPLEFT", 0, -310)
	local roleCheck = W.Button(left, "Role check", 84, function() Run.RoleCheck() end)
	roleCheck:SetHeight(18)
	roleCheck:SetPoint("TOPRIGHT", rosterHeader, "TOPRIGHT", 0, 1)
	W.Tip(roleCheck, "Role check", "Starts a role check. Each answer replaces that player's guessed role.")
	local raid = W.Button(left, "To raid", 62, function() C_PartyInfo.ConvertToRaid() end)
	raid:SetHeight(18)
	raid:SetPoint("RIGHT", roleCheck, "LEFT", -6, 0)
	W.Tip(raid, "Make it a raid", "Converts your party to a raid so more than five can join.")

	local roster = W.List(left, LEFT_W, 96, 24, function(content)
		local row = CreateFrame("Frame", nil, content)
		row.role = CreateFrame("Button", nil, row)
		row.role:SetSize(20, 20)
		row.role:SetPoint("LEFT")
		row.role.icon = W.RoleIcon(row.role, 16)
		row.role.icon:SetPoint("CENTER")
		-- Gold "?" on a guessed role.
		row.role.guess = UI.Text(row.role, "?", 11, true, C.alert)
		row.role.guess:SetPoint("BOTTOMRIGHT", 3, -2)
		row.role:SetScript("OnClick", function() Run.CycleRole(row.item.name) end)
		W.Tip(row.role, "Their role", function()
			return (Run.IsGuess(row.item.name) and "A guess: they haven't picked a role, so they count as damage. " or "")
				.. "Click to cycle tank, healer, damage. This also sets their party role, which the Group Finder shows."
		end)
		row.name = W.Name(row, 13)
		row.name:SetPoint("LEFT", 26, 0)
		row.level = UI.Text(row, "", 11, false, C.dim)
		row.level:SetPoint("RIGHT", -4, 0)
		return row
	end, function(row, m)
		local guess = Run.IsGuess(m.name)
		row.role.icon:SetRole(Run.Get().roles[m.name])
		row.role.icon:SetAlpha(guess and 0.55 or 1)
		row.role.guess:SetShown(guess)
		row.name:SetText(m.name)
		row.name:SetTextColor(W.ClassColor(m.class))
		row.level:SetText(m.level or "")
	end)
	roster:SetPoint("TOPLEFT", 0, -332)

	function block:Refresh(run)
		local n = Run.Count()
		count:SetText(n .. "/" .. run.size)
		UI.Ink(count, n >= run.size and C.good or C.text)
		local have = Run.Have()
		for role, f in pairs(roleRows) do
			f.count:SetText(have[role] .. "/" .. run.need[role])
			UI.Ink(f.count, have[role] >= run.need[role] and C.good or C.alert)
			f.stepper:Refresh()
		end
		roster:SetData(Run.Members())
		roleCheck:SetShown(Run.CanRoleCheck())
		raid:SetShown(run.size > 5 and IsInGroup() and not IsInRaid() and UnitIsGroupLeader("player"))
	end
	return block
end

-- Your chat post: its wording, editable in place with words in braces, what it
-- sends right now, and the Post button.
local function CreatePost(left)
	local block = {}
	local header = UI.Header(left, "Your chat post", LEFT_W)
	header:SetPoint("TOPLEFT", 0, -436)
	local function Set(v)
		T.db.templates.post = v
		ns.Changed()
	end
	local wording = W.TextBox(left, LEFT_W, { min = 2, max = 3 }, function() return T.db.templates.post end, Set)
	wording:SetPoint("TOPLEFT", 0, -462)
	W.Legend(wording.box, false)
	-- Words: a menu that drops a word in. Reset: back to the default wording, shown while it differs.
	local words = W.MenuButton(left, "Words", 84, W.WordsWriter(wording.box, false, Set),
		"Each word in braces and what it says right now. Click one to put it in your wording.")
	words:SetHeight(18)
	words:SetPoint("TOPRIGHT", header, "TOPRIGHT", 0, 1)
	local reset = W.Button(left, "Reset", 50, function() Set(T.defaults.templates.post) end)
	reset:SetHeight(18)
	reset:SetPoint("RIGHT", words, "LEFT", -6, 0)
	W.Tip(reset, "Reset", function() return "Back to the default wording: " .. T.defaults.templates.post end)
	-- What goes out, as said, every line of it: one to four lines, then it scrolls,
	-- and the button under it moves down as it grows. Past what a chat line
	-- holds, the words are shown in red: they won't be sent.
	local preview = W.TextView(left, LEFT_W, { min = 1, max = 4 }, C.text)
	preview:SetPoint("TOPLEFT", wording, "BOTTOMLEFT", 0, -6)
	preview:EnableMouse(true)   -- for its hover
	-- Post, with the count of what goes out beside it.
	local post = W.Button(left, "Post", LEFT_W - 66, function() Run.Post() end, true)
	post:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -8)
	local count = UI.Text(left, "", 11, false, C.dim)
	count:SetPoint("RIGHT", post, "RIGHT", 64, 0)
	count:SetJustifyH("RIGHT")
	W.Tip(preview, "What goes out", function()
		local n = #Run.FillFull(T.db.templates.post)
		if n > Run.LIMIT then return "Chat fits " .. Run.LIMIT .. " characters; the red part won't be sent." end
		return "How your post looks in chat: " .. n .. " of " .. Run.LIMIT .. " characters."
	end)
	W.Tip(post, "Post in chat", function()
		local names = {}
		for _, channel in ipairs(Run.PostChannels()) do names[#names + 1] = channel.name end
		if #names == 0 then return "No channel to post in. Join LookingForGroup or pick channels in the options." end
		return "Sends \"" .. Run.PostText() .. "\" to " .. table.concat(names, ", ") .. ". It updates as your group fills."
	end)

	function block:Refresh(run)
		wording:Refresh()
		reset:SetShown(T.db.templates.post ~= T.defaults.templates.post)
		local full = Run.FillFull(T.db.templates.post)
		local over = #full > Run.LIMIT
		preview:SetText(over and (full:sub(1, Run.LIMIT) .. UI.Wrap(C.bad, full:sub(Run.LIMIT + 1))) or full)
		count:SetText(#full .. "/" .. Run.LIMIT)
		UI.Ink(count, over and C.bad or C.dim)
		local wait = Run.PostWait()
		post.text:SetText(wait > 0 and ("Posted  \194\183  again in " .. wait .. "s") or "Post in chat")
		post:SetOn(wait == 0 and not Run.IsFull(), Run.IsFull() and "Your group is full." or "Just posted: chat takes another in a moment.")
	end
	return block
end

---------------------------------------------------------------------------
-- The run: the right column, candidates and groups
---------------------------------------------------------------------------

-- Roles someone offered override what their class could do.
local function Can(row, role)
	if row.roles and next(row.roles) then return row.roles[role] or false end
	return D.CanFill(row.class, role)
end

-- The role to ask for: the role filter, else the first missing role they can fill.
local function RoleFor(row)
	if roleFilter and roleFilter ~= "groups" then return roleFilter end
	local missing = Run.Missing()
	for _, role in ipairs(D.ROLES) do
		if missing[role] > 0 and Can(row, role) then return role end
	end
end

local function Contains(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

-- rank: 1 posted for this dungeon, 2 Group Finder, 3 posted "lfg" at this
-- level, 4 Who, 5 Who but already in a dungeon, 9 only a conversation.
local function Build()
	local run = Run.Get()
	local rows, byName = {}, {}
	local skip = { [ns.Me()] = true }
	for _, m in ipairs(Run.Members()) do skip[m.name] = true end

	local function Row(name, source, rank, detail)
		if skip[name] then return nil end
		local row = byName[name]
		if not row then
			local p = People.Get(name)
			if (p and p.status == "passed") or People.IsIgnored(name) then
				skip[name] = true
				return nil
			end
			row = { name = name, person = p, rank = 10, class = p and p.class, level = p and p.level }
			byName[name] = row
			rows[#rows + 1] = row
		end
		row.class, row.level = source.class or row.class, source.level or row.level
		if rank < row.rank then row.rank, row.detail = rank, detail end
		return row
	end

	for _, post in ipairs(Board.posts) do
		if post.kind == "lfg" and Board.Readable(post) then
			local forRun = Contains(post.keys, run.key)
			local atLevel = not post.level or (post.level >= run.min and post.level <= run.max)
			if forRun or (#post.keys == 0 and atLevel) then
				local row = Row(post.name, post, forRun and 1 or 3, "\"" .. post.text .. "\"")
				if row then
					row.post, row.when = post, post.last
					if next(post.roles) then row.roles = post.roles end
				end
			end
		end
	end
	for _, c in ipairs(Search.Listed()) do
		local row = Row(c.name, c, 2, c.area and ("Listed in the Group Finder  \194\183  " .. c.area) or "Listed in the Group Finder")
		if row then
			row.comment = c.comment
			if next(c.roles) then row.roles = c.roles end
		end
	end
	for _, c in ipairs(Search.who.list) do
		local where = c.guild and (c.area .. "  \194\183  <" .. c.guild .. ">") or c.area
		local row = Row(c.name, c, c.busy and 5 or 4, where)
		if row then row.busy = row.busy or c.busy end
	end
	-- Anyone with a conversation who is no longer in a source above.
	for name, p in pairs(People.All()) do
		if p.status ~= "found" and p.status ~= "joined" then
			local last = p.thread[#p.thread]
			Row(name, p, 9, p.post and ("\"" .. p.post .. "\"") or (last and last.text) or "")
		end
	end

	local out = {}
	for _, row in ipairs(rows) do
		local p = row.person
		local status = p and People.STATUS[p.status]
		-- 0: live conversation, 1: not asked yet, 2: dead end
		row.group = (status and status.live and 0) or (p and p.status ~= "found" and 2) or 1
		row.statusRank = status and status.rank or 99
		if not roleFilter or Can(row, roleFilter) then out[#out + 1] = row end
	end
	table.sort(out, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		if a.group ~= 1 and a.statusRank ~= b.statusRank then return a.statusRank < b.statusRank end
		if a.rank ~= b.rank then return a.rank < b.rank end
		if (a.when or 0) ~= (b.when or 0) then return (a.when or 0) > (b.when or 0) end
		return a.name < b.name
	end)
	return out
end

-- Groups listed or posted for the run, newest first.
local function BuildGroups()
	local run = Run.Get()
	local me = ns.Me()
	local rows = {}
	for _, post in ipairs(Search.For(run.key)) do
		if post.kind == "lfm" and post.name ~= me then
			rows[#rows + 1] = { name = post.name, post = post, isGroup = true, class = post.class, level = post.level,
				person = People.Get(post.name), detail = post.text ~= "" and post.text or "No description" }
		end
	end
	return rows
end

-- Candidate rows

local INVITE_FIRST = { yes = true, wants = true }
local ASK_AGAIN = { no = true, declined = true, grouped = true, busy = true, offline = true, ignoring = true, left = true }

local function RowAction(item)
	local status = item.person and item.person.status or "found"
	if item.isGroup then return (status == "found" or ASK_AGAIN[status]) and "join" or "asked" end
	if status == "invited" then return nil end
	if status == "found" or ASK_AGAIN[status] then return "ask" end
	return "invite"
end

local function CreateRow(content)
	local row = W.Row(content)
	row.name = W.Name(row, 13)
	row.name:SetPoint("TOPLEFT", 12, -5)
	row.info = UI.Text(row, "", 11, false, C.dim)
	row.info:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
	row.roles = W.Roles(row, 14)
	row.roles:SetPoint("LEFT", row.info, "RIGHT", 8, 0)
	row.seats = W.Seats(row, 14)
	row.seats:SetPoint("LEFT", row.info, "RIGHT", 8, 0)
	row.detail = W.ChatText(row, C.dim, true)
	row.detail:SetPoint("BOTTOMLEFT", 12, 6)
	row.detail:SetWidth(RIGHT_W - 230)
	row.detail:SetWordWrap(false)

	row.action = W.Button(row, "Ask", 64, function(self)
		local item = row.item
		if self.kind == "ask" then
			People.Ask(item, RoleFor(item))
		elseif self.kind == "join" then
			People.AskToJoin(item.post)
		elseif self.kind == "invite" then
			People.Invite(item.name)
		end
	end, true)
	row.action:SetPoint("RIGHT", -8, 0)
	W.Tip(row.action, function(self)
		local item = row.item
		if self.kind == "ask" then return "Ask " .. item.name end
		if self.kind == "join" then return "Ask for a spot" end
		if self.kind == "invite" then return "Invite " .. item.name end
		return nil
	end, function(self)
		local item = row.item
		if self.kind == "ask" then return "Whispers: " .. Run.AskText(item, RoleFor(item)) end
		if self.kind == "join" then return "Whispers: " .. People.JoinText(item.post) end
		return "Sends a group invite."
	end)
	row.chip = W.Chip(row)
	row.chip:SetPoint("RIGHT", row.action, "LEFT", -8, 0)

	row:SetScript("OnClick", function(self, button)
		local item = self.item
		if button == "RightButton" then
			W.PersonMenu(self, item.name, item.post or item)
		elseif item.person and #item.person.thread > 0 then
			ns.Window.ShowThread(item.name)
		elseif item.isGroup then
			People.Ensure(item.name, item.post)
			ChatFrameUtil.SendTell(item.name)
		end
	end)
	row:HookScript("OnEnter", function(self)
		local item = self.item
		if item.isGroup then
			local name, opts = W.PostDetails(item.post, { { "left", "Whisper" }, { "right", "More" } })
			UI.Tip(self, name, nil, opts)
			return
		end
		local who = W.LevelClass(item.level, item.class)
		local sections = {}
		if item.post then
			local rows = {}
			rows[#rows + 1] = { glyph = "talk", text = "\"" .. item.post.text .. "\"" }
			rows[#rows + 1] = { text = "in " .. item.post.channel .. ", " .. W.When(item.post.last), quiet = true, indent = 2 }
			sections[#sections + 1] = { title = "Their post", rows = rows }
		end
		local more = {}
		if item.comment and not issecretvalue(item.comment) and item.comment ~= "" then
			more[#more + 1] = { glyph = "note", text = item.comment }
		end
		if item.busy then more[#more + 1] = { glyph = "clock", tint = C.alert, text = "Probably inside a dungeon right now.", color = C.alert } end
		if #more > 0 then sections[#sections + 1] = { rows = more } end
		local hints = { { "right", "More" } }
		if item.person and #item.person.thread > 0 then hints = { { "left", "Conversation" }, { "right", "More" } } end
		UI.Tip(self, item.name, nil, { side = "LEFT", width = 262, color = { W.ClassColor(item.class) }, note = who ~= "" and who or nil,
			sections = sections, hints = hints })
	end)
	row:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	return row
end

local function UpdateRow(row, item)
	-- Class color, set directly: it doesn't follow the theme.
	local r, g, b = W.ClassColor(item.class)
	row.edge:SetColorTexture(r, g, b, 1)
	row.name:SetText(item.name)
	row.name:SetTextColor(r, g, b)
	row.info:SetText(W.LevelClass(item.level, item.class))
	row.roles:SetShown(not item.isGroup)
	row.seats:SetShown(item.isGroup == true)
	if item.isGroup then row.seats:Set(item.post) else row.roles:Set(function(role) return Can(item, role) end) end
	row.detail:SetText(item.detail or "")

	local p = item.person
	local status = p and People.STATUS[p.status]
	if status and status.text then
		local text, color = People.StatusText(p)
		local waiting = p.status == "asked" or p.status == "invited"
		row.chip:Set(waiting and (text .. "  " .. ns.Ago(p.t)) or text, color)
	else
		row.chip:Set(nil)
	end

	local kind = RowAction(item)
	local action = row.action
	action.kind = kind
	action:SetShown(kind ~= nil)
	if kind == "ask" then
		action.text:SetText("Ask")
		action:SetPrimary(not p or p.status == "found")
		action:SetOn(not Run.IsFull(), "Your group is full.")
	elseif kind == "join" then
		action.text:SetText("Ask to join")
		action:SetPrimary(not p or p.status == "found")
		action:SetOn(true)
	elseif kind == "asked" then
		action.text:SetText("Asked")
		action:SetPrimary(false)
		action:SetOn(false, "You asked them for a spot; their answer lands in Replies.")
	elseif kind == "invite" then
		action.text:SetText("Invite")
		action:SetPrimary(INVITE_FIRST[p.status] or false)
		action:SetOn(Run.CanInvite() and not Run.IsFull(), Run.IsFull() and "Your group is full." or "Only the group leader or an assistant can invite.")
	end
	local actionW = (kind == "join" or kind == "asked") and 96 or 64
	action:SetWidth(actionW)
	row.chip:ClearAllPoints()
	if kind then
		row.chip:SetPoint("RIGHT", action, "LEFT", -8, 0)
	else
		row.chip:SetPoint("RIGHT", -8, 0)
	end
	-- The name gives way before the chip and button on the right.
	local taken = 8 + (kind and (actionW + 8) or 0) + (row.chip:IsShown() and (row.chip:GetWidth() + 8) or 0)
	local extra = item.isGroup and row.seats:GetWidth() or row.roles:GetWidth()
	W.FitName(row.name, row.info, extra, RIGHT_W - 14 - taken)
	row:SetAlpha((item.group == 2 or (item.busy and item.group == 1)) and 0.55 or 1)
end

local function SearchStatus()
	local who, finder = Search.who, Search.finder
	if who.state == "searching" then return "Searching..." end
	if who.state == "silent" then return "The server didn't answer. Try again in a moment." end
	local parts = {}
	if who.state == "done" then
		-- The server returns 50 at most.
		local n = who.found
		parts[#parts + 1] = who.total > n and ("First " .. n .. " of " .. who.total .. " online at this level") or (n .. " online at this level")
	end
	if finder.state == "done" then parts[#parts + 1] = #Search.Listed() .. " in the Group Finder" end
	return table.concat(parts, "  \194\183  ")
end

local function CreateRight(main)
	local block = {}
	local right = CreateFrame("Frame", nil, main)
	right:SetPoint("TOPLEFT", RIGHT_X, 0)
	right:SetSize(RIGHT_W, 10)

	local filter = W.Segments(right, { "Everyone", "Tanks", "Healers", "Damage", "Groups" }, function(i)
		roleFilter = FILTERS[i]
		ns.Changed()
	end)
	filter:SetPoint("TOPLEFT", 0, -12)
	W.Tip(filter.buttons[GROUPS], "Groups", "Groups listed or posting for this run, with a spot to ask for.")
	local find = W.Button(right, "Find people", 120, function() Search.Find(roleFilter ~= "groups" and roleFilter or nil) end, true)
	find:SetHeight(24)
	find:SetPoint("TOPRIGHT", 0, -12)
	W.Tip(find, "Find people", "Runs a Who search for these levels and checks the Group Finder. With a role picked, only classes that can fill it are searched.")

	local levels = UI.Text(right, "Levels", 12, false, C.dim)
	levels:SetPoint("TOPLEFT", 0, -50)
	local LEVEL_TIP = { "Levels to search", "The levels Find people searches, and which chat posts count as your level. Shift-click steps by five; the mouse wheel works too." }
	local minLevel = W.Stepper(right, function() return Run.Get().min end, function(delta) Run.AdjustLevel("min", delta) end,
		{ min = 1, max = GetMaxPlayerLevel(), tip = LEVEL_TIP })
	minLevel:SetPoint("LEFT", levels, "RIGHT", 8, 0)
	local to = UI.Text(right, "to", 12, false, C.dim)
	to:SetPoint("LEFT", minLevel, "RIGHT", 8, 0)
	local maxLevel = W.Stepper(right, function() return Run.Get().max end, function(delta) Run.AdjustLevel("max", delta) end,
		{ min = 1, max = GetMaxPlayerLevel(), tip = LEVEL_TIP })
	maxLevel:SetPoint("LEFT", to, "RIGHT", 8, 0)
	-- What the searches found, right-aligned in the room left of the steppers.
	local searchStatus = UI.Text(right, "", 12, false, C.dim)
	searchStatus:SetPoint("LEFT", maxLevel, "RIGHT", 12, 0)
	searchStatus:SetPoint("RIGHT", right, "RIGHT", 0, 0)
	searchStatus:SetJustifyH("RIGHT")
	searchStatus:SetWordWrap(false)

	-- Banner once the group is full.
	local full = CreateFrame("Frame", nil, right)
	full:SetPoint("TOPLEFT", 0, -LIST_TOP)
	full:SetSize(RIGHT_W, 34)
	UI.Skin(full, W.Alpha(C.good, 0.14), W.Alpha(C.good, 0.6))
	local fullText = UI.Text(full, "Your group is full.", 14, true, C.good)
	fullText:SetPoint("LEFT", 12, 0)
	local tell = W.Button(full, "", 10, function()
		local text = People.FullText()
		local waiting = People.Waiting()
		for i = 1, math.min(#waiting, 10) do
			People.Send(waiting[i].name, text)
			People.Pass(waiting[i].name)
		end
	end)
	tell:SetPoint("RIGHT", -6, 0)
	W.Tip(tell, "Let them know", function() return "Whispers everyone still waiting: " .. People.FullText() end)

	local list = W.List(right, RIGHT_W, 100, 46, CreateRow, UpdateRow)
	local empty = UI.Text(right, "", 13, false, C.dim)
	empty:SetWidth(RIGHT_W - 80)
	empty:SetJustifyH("CENTER")
	empty:SetSpacing(4)

	local function EmptyText(run)
		if roleFilter == "groups" then
			return "No group listed or posting for " .. run.name .. " yet.\nThe Group Finder gets checked when the window opens; Refresh on the Browse tab checks again."
		end
		if roleFilter then return "No one for that role yet.\nPress Find people to search for classes that can fill it." end
		return "No one yet.\nPress Find people to search for players in your level range.\nAnyone posting LFG in chat or listed in the Group Finder shows up here."
	end

	function block:Refresh(run)
		minLevel:Refresh()
		maxLevel:Refresh()
		local searching = Search.who.state == "searching"
		local whoWait = Search.WhoWait()
		find.text:SetText(searching and "Searching..." or whoWait > 0 and ("Again in " .. whoWait .. "s") or "Find people")
		find:SetOn(not searching and whoWait == 0)
		searchStatus:SetText(SearchStatus())

		local isFull = Run.IsFull()
		local waiting = isFull and #People.Waiting() or 0
		full:SetShown(isFull)
		tell:SetShown(waiting > 0)
		if waiting > 0 then
			tell.text:SetText(waiting == 1 and "Tell the 1 still waiting" or ("Tell the " .. math.min(waiting, 10) .. " still waiting"))
			tell:SetWidth(tell.text:GetStringWidth() + 24)
		end

		local groups = BuildGroups()
		filter:SetLabel(GROUPS, #groups > 0 and ("Groups  " .. #groups) or "Groups")
		local top = LIST_TOP + (isFull and 42 or 0)
		list:ClearAllPoints()
		list:SetPoint("TOPLEFT", 0, -top)
		list:SetHeight(PAGE_H - top - 12)
		local rows = roleFilter == "groups" and groups or Build()
		list:SetData(rows)
		empty:SetShown(#rows == 0)
		empty:ClearAllPoints()
		empty:SetPoint("TOP", list, "TOP", 0, -90)
		if #rows == 0 then empty:SetText(EmptyText(run)) end
	end
	return block
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

local function CreateMain(page)
	local main = CreateFrame("Frame", nil, page)
	main:SetAllPoints()
	local left = CreateFrame("Frame", nil, main)
	left:SetPoint("TOPLEFT", PAD, 0)
	left:SetSize(LEFT_W, 10)
	local blocks = { CreateHead(left), CreateListing(left), CreateGroup(left), CreatePost(left), CreateRight(main) }
	function main:Refresh()
		local run = Run.Get()
		for _, block in ipairs(blocks) do block:Refresh(run) end
	end
	return main
end

function Rc.Create(page)
	local start = CreateStart(page)
	local main = CreateMain(page)
	function page:Refresh()
		local run = Run.Get()
		start:SetShown(not run)
		main:SetShown(run ~= nil)
		if run then main:Refresh() else start:Refresh() end
	end
end
