-- The Browse tab: LFM and LFG posts from chat channels and Group Finder
-- listings in one list, by category, with filters, a sort order and a detail
-- tooltip. Someone who both posted and listed shows once, as the chat post.

local ADDON, ns = ...
local T, D, W = ns.T, ns.Data, ns.W
local UI = Shy.UI
local C = UI.colors
local Run, People, Board, Search, Listing = ns.Run, ns.People, ns.Board, ns.Search, ns.Listing
local Bt = {}
ns.BoardTab = Bt

local PAD = 16
local LIST_W = ns.Window.WIDTH - PAD * 2
local LIST_TOP = 78
local KINDS = { false, "lfm", "lfg" }
local ROLES = { false, "tank", "healer", "dps" }
-- Palette tables by reference, so they follow a theme change.
local GROUP, PLAYER = C.hot, C.good
local HINTS = { { "left", "Whisper" }, { "right", "More" } }

-- Sort orders: higher key first, newer post on a tie.
local SORTS = {
	{ text = "Newest first", key = function(post) return 0 end },
	{ text = "By dungeon", key = function(post)
		local d = D.byKey[post.keys[1]]
		return d and -d.order or -math.huge
	end },
	{ text = "Fullest first", key = function(post)
		-- Players sort after every group.
		return post.kind == "lfm" and post.count and post.size and post.size > 0 and post.count / post.size or -1
	end },
	{ text = "Highest level first", key = function(post) return post.level or 0 end },
	-- In enum order; posts with no style last.
	{ text = "By style", key = function(post) return post.style and post.style > 0 and -post.style or -math.huge end },
}

-- Filters only a Group Finder listing can match; ticking one hides chat posts.
local QUALITIES = {
	{ key = "friendly", text = "New players welcome", has = function(post) return post.friendly == true end },
	{ key = "known", text = "A guildmate or friend is in it", has = function(post) return (post.guild or post.friends) == true end },
	{ key = "fresh", text = "No bosses down yet", has = function(post) return post.kind == "lfm" and post.downs == 0 end },
}
local SOURCES = {
	{ value = false, text = "From anywhere" },
	{ value = "finder", text = "Only the Group Finder" },
	{ value = "chat", text = "Only chat" },
}

local kind, role, dungeon, order, myLevel, search = false, false, false, 1, true, ""
local styles, wanted, source = {}, {}, false   -- style value -> true; quality key -> true; SOURCES value

-- The category in view: shared with the Run tab's start screen.
local function ViewKind()
	return Search.Kind()
end

-- A post belongs to the category when it names something of that kind, or names nothing.
local function OfKind(post, which)
	if #post.keys == 0 then return true end
	for _, key in ipairs(post.keys) do
		local d = D.byKey[key]
		if d and d.kind == which then return true end
	end
	return false
end

local function Matches(post, level, which)
	if not OfKind(post, which) then return false end
	if kind and post.kind ~= kind then return false end
	if role and not Board.HasRole(post, role) then return false end
	if dungeon and not Board.About(post, dungeon) then return false end
	if next(styles) and not (post.style and styles[post.style]) then return false end
	for _, quality in ipairs(QUALITIES) do
		if wanted[quality.key] and not quality.has(post) then return false end
	end
	if source and (source == "finder") ~= (post.finder == true) then return false end
	if myLevel and not Board.FitsLevel(post, level) then return false end
	if search ~= "" then
		local hay = (post.name .. " " .. post.text .. " " .. (Board.DungeonText(post) or "")):lower()
		if not hay:find(search, 1, true) then return false end
	end
	return true
end

-- The style button's label and whether any filter is on.
local function QualityLabel()
	local names, more = {}, source and 1 or 0
	for _, style in ipairs(Listing.STYLES) do
		if styles[style.value] then names[#names + 1] = style.text end
	end
	for _, quality in ipairs(QUALITIES) do
		if wanted[quality.key] then more = more + 1 end
	end
	local text = #names == 0 and (more == 0 and "Any style" or "") or #names == 1 and names[1] or (#names .. " styles")
	if more == 0 then return text, #names > 0 end
	return text == "" and (more == 1 and "1 filter" or (more .. " filters")) or (text .. "  +" .. more), true
end

-- "dungeon", "raid", "zone", "listing" for the buttons' words.
local function Noun(which)
	if which == "dungeon" or which == "raid" or which == "zone" then return which end
	return "listing"
end

-- Why nothing shows: counts of what the filters hid and what can't be read.
local function Hidden(all, level, which)
	local filtered, foreign = 0, 0
	for _, post in ipairs(all) do
		if not Board.Readable(post) then
			foreign = foreign + 1
		elseif not Matches(post, level, which) then
			filtered = filtered + 1
		end
	end
	return filtered, foreign
end

local function CreateRow(content)
	local row = W.Row(content)
	row.name = W.Name(row, 13)
	row.name:SetPoint("TOPLEFT", 12, -6)
	row.info = UI.Text(row, "", 11, false, C.dim)
	row.info:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
	row.chip = W.Chip(row)
	row.chip:SetPoint("LEFT", row.info, "RIGHT", 8, 0)
	-- Fixed x for dungeon and roles, so rows line up as columns.
	row.dungeon = UI.Text(row, "", 12, false, C.head)
	row.dungeon:SetPoint("TOPLEFT", 300, -8)
	row.dungeon:SetWidth(190)
	row.dungeon:SetJustifyH("LEFT")
	row.dungeon:SetWordWrap(false)
	row.seats = W.Seats(row, 14)
	row.seats:SetPoint("TOPLEFT", 498, -7)
	row.text = W.ChatText(row, C.text, true)
	row.text:SetPoint("BOTTOMLEFT", 12, 7)
	row.text:SetWidth(474)
	row.text:SetWordWrap(false)
	row.source = UI.Text(row, "", 11, false, C.dim)
	row.source:SetPoint("BOTTOMLEFT", 498, 8)
	row.source:SetWidth(164)
	row.source:SetJustifyH("LEFT")
	row.source:SetWordWrap(false)
	row.ago = UI.Text(row, "", 11, false, C.dim)
	row.ago:SetPoint("TOPRIGHT", -112, -8)
	-- Once asked, their standing takes the button's place.
	row.state = W.Chip(row)
	row.state:SetPoint("TOPRIGHT", -8, -5)

	-- A group can be asked for a spot; a player asked into your run, or invited outright.
	row.action = W.Button(row, "", 96, function(self)
		local post = row.item
		if post.kind == "lfg" then
			People.Ask(post, nil)
		else
			People.AskToJoin(post)
		end
	end)
	row.action:SetHeight(20)
	row.action:SetPoint("TOPRIGHT", -8, -4)
	W.Tip(row.action, function() return row.item.kind == "lfg" and "Ask them to join you" or "Ask for a spot" end, function()
		local post = row.item
		if post.kind == "lfg" then return "Whispers: " .. Run.AskText(post, nil) end
		return "Whispers: " .. People.JoinText(post)
	end)
	row.invite = W.Button(row, "Invite", 96, function() People.Invite(row.item.name) end)
	row.invite:SetHeight(20)
	row.invite:SetPoint("BOTTOMRIGHT", -8, 4)
	W.Tip(row.invite, function() return "Invite " .. row.item.name end, "Sends a group invite.")

	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			W.PersonMenu(self, self.item.name, self.item)
		else
			People.Ensure(self.item.name, self.item)
			ChatFrameUtil.SendTell(self.item.name)
		end
	end)
	row:HookScript("OnEnter", function(self)
		local name, opts = W.PostDetails(self.item, HINTS)
		UI.Tip(self, name, nil, opts)
	end)
	row:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	return row
end

local function UpdateRow(row, post)
	local r, g, b = W.ClassColor(post.class)
	row.edge:SetColorTexture(r, g, b, 1)
	row.name:SetText(post.name)
	row.name:SetTextColor(r, g, b)
	row.info:SetText(W.LevelClass(post.level, post.class))
	local group = post.kind == "lfm"
	local label = not group and "Player"
		or post.count and post.size and post.size > 0 and ("Group  " .. post.count .. "/" .. post.size)
		or "Group"
	row.chip:Set(label, group and GROUP or PLAYER)
	-- The name gives way before the dungeon column.
	W.FitName(row.name, row.info, row.chip:GetWidth(), 292)
	row.dungeon:SetText(Board.DungeonText(post) or "")
	row.seats:Set(post)
	row.text:SetText(post.text ~= "" and post.text or "No description")
	row.source:SetText(W.Source(post))
	row.ago:SetText(ns.Ago(post.last))

	-- A player can be asked into your run (if there is one); a group for a spot.
	-- Someone ignored is shown as such, with nothing to press.
	local p = People.Get(post.name)
	local ignored = People.IsIgnored(post.name)
	local asked = p and p.status ~= "found" and p.status ~= "passed"
	local inGroup = p and p.status == "joined"
	row.action:SetShown(not ignored and not asked and (group or Run.Get() ~= nil))
	row.action.text:SetText(group and "Ask to join" or "Ask")
	row.action:SetOn(true)
	if asked and not ignored then
		local text, color = People.StatusText(p)
		row.state:Set(text, color, 96)
	else
		row.state:Set(nil)
	end
	row.invite:SetShown(not ignored and not group and Run.CanInvite() and not inGroup)
	row.invite:SetOn(not (p and p.status == "invited"), "Invited. Waiting on them.")
	if ignored then row.chip:Set("Ignored", C.bad) end
	row:SetAlpha(ignored and 0.5 or 1)
end

function Bt.Create(page)
	-- First row: kind, role, search, refresh
	local kinds = W.Segments(page, { "Everything", "Groups", "Players" }, function(i)
		kind = KINDS[i]
		ns.Changed()
	end)
	kinds:SetPoint("TOPLEFT", PAD, -12)

	local roles = W.Segments(page, { "Any role", "Tank", "Healer", "Damage" }, function(i)
		role = ROLES[i]
		ns.Changed()
	end)
	roles:SetPoint("LEFT", kinds, "RIGHT", 14, 0)
	for _, b in ipairs(roles.buttons) do
		W.Tip(b, "Role", "Groups with this role open, and players who can fill it. Chat posts that name no roles still show.")
	end

	local refresh = W.Button(page, "Refresh", 90, function() Search.Browse() end)
	refresh:SetHeight(24)
	refresh:SetPoint("TOPRIGHT", -PAD, -12)
	refresh:SetMotionScriptsWhileDisabled(true)
	W.Tip(refresh, "Refresh", function()
		local finder = Search.finder
		local when = finder.when and finder.kind == ViewKind() and ("Last asked " .. W.When(finder.when) .. ". ") or ""
		return when .. "Asks the Group Finder again for " .. D.KindName(ViewKind()):lower() .. ". Listings update on their own after that. Chat posts show up as people post them."
	end)

	local find = UI.Input(page, nil, function() return search end, function(v)
		search = strtrim(v):lower()
		ns.Changed()
	end, { width = 180, live = true, placeholder = function() return "Search posts..." end })
	find:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
	find:Refresh()

	-- Second row: category, dungeon, order, style, level
	local category = W.MenuButton(page, "", 130, function(root)
		root:CreateTitle("Category")
		for _, k in ipairs(D.kinds) do
			root:CreateRadio(k.name, function() return ViewKind() == k.kind end, function()
				ns.char.kind = k.kind
				dungeon = false
				Search.Look(k.kind)   -- from a click
				ns.Changed()
			end)
		end
	end, "Dungeons, raids, quest zones or custom listings, as the Group Finder sorts them. Pick one to search the Group Finder for it.")
	category:SetHeight(24)
	category:SetPoint("TOPLEFT", PAD, -44)

	local which = W.MenuButton(page, "", 184, function(root)
		-- Those with posts right now, with a count; with "My level range" on, everything at your level too.
		local counts = Search.Counts()
		local run = Run.Get()
		local mine = run and D.byKey[run.key]
		local view = ViewKind()
		local level = UnitLevel("player")
		do
			root:CreateTitle("Which " .. Noun(view) .. "?")
			-- A row per dungeon: its range and size under the name, who's listed at the right.
			local function Pick(text, key, d)
				local entry = root:CreateRadio(text, function() return dungeon == key end, function()
					dungeon = key
					ns.Changed()
				end)
				if not d then return end
				local sub = D.RangeText(d)
				if d.kind == "dungeon" then sub = sub .. "  \194\183  " .. d.size .. " players" end
				if d.group then sub = sub .. "  \194\183  " .. d.group end
				if sub ~= "" then entry:SetSub(sub) end
				local c = counts[d.key]
				if c then
					local parts = {}
					if c.groups > 0 then parts[#parts + 1] = W.Plural(c.groups, "group") end
					if c.players > 0 then parts[#parts + 1] = W.Plural(c.players, "player") end
					entry:SetDetail(table.concat(parts, ", "))
				end
			end
			Pick("Any " .. Noun(view), false)
			if mine and mine.kind == view then Pick("Your run: " .. mine.name, mine.key, mine) end
			root:CreateDivider()
			for _, d in ipairs(D.OfKind(view)) do
				if d ~= mine and (counts[d.key] or (myLevel and Board.ForLevel(d, level))) then Pick(d.name, d.key, d) end
			end
		end
	end, "Posts for one dungeon, raid or zone. It lists the ones with posts right now, plus everything at your level with \"My level range\" on.")
	which:SetHeight(24)
	which:SetPoint("LEFT", category, "RIGHT", 8, 0)

	local sort = W.MenuButton(page, "", 150, function(root)
		root:CreateTitle("Order")
		for i, option in ipairs(SORTS) do
			root:CreateRadio(option.text, function() return order == i end, function()
				order = i
				ns.Changed()
			end)
		end
	end, "Sort by newest, dungeon level, fullest group, highest level or style.")
	sort:SetHeight(24)
	sort:SetPoint("LEFT", which, "RIGHT", 8, 0)

	local qualities = W.MenuButton(page, "", 150, function(root)
		do
			root:CreateTitle("Style")
			for _, style in ipairs(Listing.STYLES) do
				root:CreateCheckbox(style.text, function() return styles[style.value] == true end, function()
					styles[style.value] = not styles[style.value] or nil
					ns.Changed()
				end)
			end
			root:CreateDivider()
			for _, quality in ipairs(QUALITIES) do
				root:CreateCheckbox(quality.text, function() return wanted[quality.key] == true end, function()
					wanted[quality.key] = not wanted[quality.key] or nil
					ns.Changed()
				end)
			end
			root:CreateDivider()
			for _, option in ipairs(SOURCES) do
				root:CreateRadio(option.text, function() return source == option.value end, function()
					source = option.value
					ns.Changed()
				end)
			end
			root:CreateDivider()
			root:CreateButton("Clear filters", function()
				wipe(styles)
				wipe(wanted)
				source = false
				ns.Changed()
			end)
		end
	end, "Listing style, new players welcome, a guildmate or friend inside, a fresh run, or where posts come from. Only Group Finder listings carry these, so picking one hides chat posts.")
	qualities:SetHeight(24)
	qualities:SetPoint("LEFT", sort, "RIGHT", 8, 0)

	local level = UI.Checkbox(page, "My level range", function() return myLevel end, function(v)
		myLevel = v
		ns.Changed()
	end, { desc = "Shows only posts for dungeons, raids and zones in your level range (for a zone, a level either side). Posts that don't name one always show." })
	level:SetPoint("LEFT", qualities, "RIGHT", 12, 0)
	level:Refresh()

	local list = W.List(page, LIST_W, ns.Window.HEIGHT - ns.Window.HEADER - LIST_TOP - 30, 50, CreateRow, UpdateRow)
	list:SetPoint("TOPLEFT", PAD, -LIST_TOP)

	local summary = UI.Text(page, "", 12, false, C.dim)
	summary:SetPoint("BOTTOMLEFT", PAD, 10)

	local empty = UI.Text(page, "", 13, false, C.dim)
	empty:SetJustifyH("CENTER")
	empty:SetSpacing(4)
	empty:SetWidth(LIST_W - 80)
	empty:SetPoint("CENTER", 0, 0)
	-- Every filter at once back to the start, from the empty list itself.
	local function ClearFilters()
		kind, role, dungeon, search, source = false, false, false, "", false
		wipe(styles)
		wipe(wanted)
		kinds:Select(1)
		roles:Select(1)
		find:Refresh()
		ns.Changed()
	end
	local clear = W.Button(page, "Clear filters", 110, ClearFilters)
	clear:SetPoint("TOP", empty, "BOTTOM", 0, -12)
	clear:Hide()

	local function EmptyText(all, level, view)
		local filtered, foreign = Hidden(all, level, view)
		if filtered + foreign == 0 then
			local text = "Nothing for " .. D.KindName(view):lower() .. " yet.\nPosts like \"LFM Deadmines need tank\" and \"healer LFG\" from your channels show up as people post them."
			if Listing.Available() then
				text = text .. (Search.finder.kind == view and "\nThe Group Finder has no listing for this right now." or "\nPress Refresh for the Group Finder's listings.")
			end
			return text
		end
		local parts = {}
		if filtered > 0 then parts[#parts + 1] = W.Plural(filtered, "post") .. " hidden by your filters" end
		if foreign > 0 then
			parts[#parts + 1] = foreign .. " in a language you can't read (shown with \"Posts you can read\" off in the settings)"
		end
		return "Nothing matches.\n" .. table.concat(parts, "\n")
	end

	function page:Refresh()
		local mine = UnitLevel("player")
		local view = ViewKind()
		local all = Search.Everything()
		local rows, groups = {}, 0
		for _, post in ipairs(all) do
			if Board.Readable(post) and Matches(post, mine, view) then
				rows[#rows + 1] = post
				if post.kind == "lfm" then groups = groups + 1 end
			end
		end
		local key = SORTS[order].key
		table.sort(rows, function(a, b)
			local ka, kb = key(a), key(b)
			if ka ~= kb then return ka > kb end
			if a.last ~= b.last then return a.last > b.last end
			return a.name < b.name
		end)
		list:SetData(rows)

		category:SetLabel(D.KindName(view))
		category:SetShown(#D.kinds > 1)
		local picked = dungeon and D.byKey[dungeon]
		if picked and picked.kind ~= view then
			dungeon, picked = false, nil
		end
		-- A filter that narrows the list shows its pick in the accent's light.
		which:SetLabel(picked and (picked.short or picked.name) or ("Any " .. Noun(view)), picked and C.hot or C.text)
		sort:SetLabel(SORTS[order].text, C.text)
		local label, picky = QualityLabel()
		qualities:SetLabel(label, picky and C.hot or C.text)

		local can = Listing.Available()
		local searching = Search.finder.state == "searching"
		local wait = Search.LookWait()
		refresh:SetShown(can)
		refresh.text:SetText(searching and "Searching..." or wait > 0 and ("Again in " .. wait .. "s") or "Refresh")
		refresh:SetOn(not searching and wait == 0)

		local players = #rows - groups
		local finder = Search.finder
		local when = can and finder.when and finder.kind == view and ("Group Finder asked " .. W.When(finder.when)) or nil
		summary:SetText(#rows == 0 and (when or "") or (W.Plural(groups, "group") .. "  \194\183  " .. W.Plural(players, "player")
			.. (when and ("  \194\183  " .. when) or "")))

		empty:SetShown(#rows == 0)
		Bt.why = #rows == 0 and EmptyText(all, mine, view) or nil
		if Bt.why then empty:SetText(Bt.why) end
		local filtering = kind or role or dungeon or search ~= "" or source or next(styles) or next(wanted)
		clear:SetShown(#rows == 0 and filtering ~= nil and filtering ~= false)
	end
end
