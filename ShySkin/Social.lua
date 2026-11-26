-- The social window ("O"): a window of our own in place of the game's (SocialUIFrame, which this client opens in
-- place of the old friends frame). As the professions window: the game's window stays the panel the game opens and
-- closes (the social key, a friend request's toast, /raidinfo, Escape), emptied and taking no mouse, every piece of
-- it in the attic (Shop.lua); ours is a child of it, so it opens and closes with it, and its size never changes.
--
-- Pages, as square tabs down the right edge (those the game offers here):
--   Friends: you (your status, your BattleTag to copy, the message your friends see, changed in place), search and
--   the game's filters (a funnel; each filter on is a chip that clears it), your Battle.net friends under Favorites
--   and Friends, which fold. A friend's row: a slot with the character's class (the game's badge for another game,
--   empty offline) and a dot for online, away or busy; the name, then the character, level and class; where they
--   are; invite. Click whispers, right-click is the game's menu, hover a card beside the window. Add friend below.
--   Friend requests: accept, or decline with block and report under its caret.
--   Quick Join: your friends' groups, what they are doing, ask to join.
--   Raid: tanks, healers and damage, everyone assists, eight groups of five (drag a name onto another to swap the
--   two, onto a group to move it; not in a fight), raid info. In a party, convert to raid.
-- The ignore list and raid info are pages of the window, reached from Friends and Raid.
--
-- Its × is secure: it presses the game's own close button, which closes the window in a fight too (the game's
-- window is protected there once its raid names are made). So the window stays where it is in a fight. Nothing
-- else is secure (raid names don't target, as the game's do): it turns its pages in a fight, and while one is on,
-- the raid page keeps what it showed until it ends.

local ADDON, ns = ...
local UI = Shy.UI
local Theme = Shy.Theme
local Skin = Shy.Skin
local Slot = Shy.Slot
local C = UI.colors
local Shop = ns.Shop
local HEAD = UI.HEAD.window
local TAB = ns.SIDE_TAB
local ICON = Shop.ICON

local L = {
	w = 400, h = 620, pad = 12,
	band = 54,                 -- you: status, BattleTag, message
	find = 22,                 -- the search row
	chips = 24,                -- the row of filters that are on
	row = 44, head = 24, slot = 34, gap = 6,   -- a friend's row, a heading, a row's slot, after a part of a list
	tall = 48,                 -- a request's or a group's row
	slim = 28,                 -- an ignored player's or a saved instance's row
	foot = 24,
	member = 18, group = 186, groupGap = 8, groupH = 116,   -- the raid: a name, a group's width, between, its height
	card = 280,                -- the room a hover card wants beside the window
	most = 127,                -- the longest message the game takes
}
L.head0 = HEAD.line + UI.LINE                    -- the header's foot
L.top = L.head0 + L.band                         -- the search row's top
L.inner = L.w - 2 * L.pad

-- The pages, in the game's order; `has` says whether the game offers one here.
local PAGES = {
	{ key = "friends", title = "SOCIAL_UI_FRIENDS_TAB_NAME", icon = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
		has = function() return C_BattleNet.IsBattleNetFriendsListSupported() end },
	{ key = "join", title = "SOCIAL_UI_QUICK_JOIN_TAB_NAME", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore",
		has = function() return C_SocialQueue.IsSystemSupported() and C_SocialQueue.IsSystemEnabled() end,
		count = function() return #(C_SocialQueue.GetAllGroups() or {}) end },
	{ key = "requests", title = "SOCIAL_UI_FRIEND_REQUESTS_TAB_NAME", icon = "Interface\\Icons\\INV_Letter_15",
		has = function() return C_BattleNet.IsBattleNetFriendsListSupported() end,
		count = function() return BNGetNumFriendInvites() or 0 end },
	{ key = "raid", title = "SOCIAL_UI_RAID_TAB_NAME", icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
		has = function() return C_PartyInfo.IsRaidListSupported() and C_PartyInfo.IsRaidListEnabled() end },
}
local UNDER = { ignore = "friends", raidinfo = "raid" }   -- a page reached from another: that one's tab stays lit

-- The game's filters: a status each (`is` reads a friend's presence), then the tags it supports here. The game's
-- own search is closed to addons, so the list is read and filtered here; its queue filters have nothing open to read.
local STATUS = {
	{ field = "isOnline", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_ONLINE", is = function(p) return p ~= nil end },
	{ field = "isAFK", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_AWAY", is = function(p) return p == "away" end },
	{ field = "isDND", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_BUSY", is = function(p) return p == "busy" end },
	{ field = "isOffline", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_OFFLINE", is = function(p) return p == nil end },
}
-- Your status: how it is set, its word and its dot's color.
local PRESENCE = {
	{ key = "online", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_ONLINE", color = "good" },
	{ key = "away", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_AWAY", color = "alert" },
	{ key = "busy", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_BUSY", color = "bad" },
	{ key = "hidden", label = "SOCIAL_UI_PRESENCE_TYPE_LABEL_APPEAR_OFFLINE", color = "dim" },
}
local ROLE_ATLAS = { TANK = "groupfinder-icon-role-micro-tank", HEALER = "groupfinder-icon-role-micro-heal",
	DAMAGER = "groupfinder-icon-role-micro-dps" }
local RANK_ART = { [2] = "Interface\\GroupFrame\\UI-Group-LeaderIcon", [1] = "Interface\\GroupFrame\\UI-Group-AssistantIcon" }
local BNET_BADGE = "Interface\\FriendsFrame\\Battlenet-Battleneticon"
local WORDS = {
	search = "Search friends", message = "Share a message with your friends", copied = "Copied",
	favorites = "Favorites", friends = "Friends", online = "%s of %d online",
	addFriend = "Add friend", none = "No one matches", noneSay = "Search reads names, characters, classes and places.",
	nobody = "No friends yet", nobodySay = "Add one by BattleTag or character name.",
	requestsSay = "People who want to be your friend.", noRequests = "No requests waiting",
	joinSay = "Groups your friends are in. Ask to join and the leader can invite you.", noGroups = "None of your friends are grouped",
	ask = "Ask to join", raidInfo = "Raid info", assists = "Everyone assists",
	party = "You're in a party", partySay = "A raid holds up to 40 in eight groups of five. Converting keeps everyone where they are.",
	alone = "You aren't in a group", aloneSay = "Join or start a group, then turn it into a raid here.",
	drag = "Drag a name to another group", fight = "Updates after the fight",
	ignoreSay = "Their whispers, invites and chat stay hidden from you.", ignoreAdd = "Ignore a player", ignoreRemove = "Remove",
	player = "Player", battlenet = "Battle.net", noIgnores = "No one ignored",
	savedSay = "Where you're saved, and when each resets.",
	extended = "Extended", whisper = "Whisper", menu = "Menu", unavailable = "Battle.net is unavailable",
}

local M              -- the module
local own = {}       -- our frames, made once
local S = { page = "friends", folds = {}, filters = {}, search = "", ignore = nil, copied = false }
local mouse          -- the game's window took the mouse before we emptied it
local Refresh, Stale, Go

local function Frame() return SocialUIFrame end

local function Text(parent, font, color)
	return Shop.Text(parent, font, color)
end

local function Global(name)
	return rawget(_G, name) or ""
end

local function Fill(parent, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	t:SetColorTexture(1, 1, 1, 1)
	return t
end

local function Plain(v)
	return type(v) == "string" and not issecretvalue(v) and v ~= ""
end

-- Reading

-- Your status, as the game's own window reads it.
local function MyPresence()
	local _, _, _, _, afk, busy, _, hidden = BNGetInfo()
	return (hidden and "hidden") or (afk and "away") or (busy and "busy") or "online"
end

local function SetPresence(key)
	if key == "online" then
		C_BattleNet.SetAFK(false)
		C_BattleNet.SetDND(false)
		C_BattleNet.SetAppearOffline(false)
	elseif key == "away" then
		C_BattleNet.SetAFK(true)
	elseif key == "busy" then
		C_BattleNet.SetDND(true)
	else
		C_BattleNet.SetAppearOffline(true)
	end
end

local function Presence(a)
	local g = a.gameAccountInfo
	if not g.isOnline then return nil end
	if a.isAFK or g.isGameAFK then return "away" end
	if a.isDND or g.isGameBusy then return "busy" end
	return "online"
end

-- What search reads: everything about a friend that is plain words.
local function Matches(a, want)
	if want == "" then return true end
	local g = a.gameAccountInfo
	for _, field in ipairs({ a.battleTag, a.note, g.characterName, g.className, g.areaName, g.richPresence }) do
		if Plain(field) and field:lower():find(want, 1, true) then return true end
	end
	return false
end

-- The filters that are on: any of the chosen statuses, and any of the chosen tags.
local function Passes(a)
	local statuses, tags = {}, {}
	for key in pairs(S.filters) do
		if type(key) == "number" then tags[key] = true end
	end
	for _, s in ipairs(STATUS) do
		if S.filters[s.field] then statuses[#statuses + 1] = s end
	end
	if #statuses > 0 then
		local presence, any = Presence(a), false
		for _, s in ipairs(statuses) do any = any or s.is(presence) end
		if not any then return false end
	end
	if next(tags) then
		for _, t in ipairs(a.friendTags or {}) do
			if tags[t] then return true end
		end
		return false
	end
	return true
end

-- Your friends in the game's order, through the filters and the words; favorites apart.
local function Friends()
	local want = S.search:lower()
	local favs, rest = {}, {}
	for index = 1, BNGetNumFriends() or 0 do
		local a = C_BattleNet.GetFriendAccountInfo(index)
		if a and Passes(a) and Matches(a, want) then
			local list = a.isFavorite and favs or rest
			list[#list + 1] = { index = index, a = a }
		end
	end
	return favs, rest
end

local function Playing(g)
	return FriendsListUtil.IsPlayingSameWoWProject(g) and Plain(g.characterName)
end

-- Building: pieces

-- Where a hover card stands: past the window's edge (and its tabs), level with the row, on the side with room.
local function Beside(row)
	return UI.Beside(own.box, row, { room = L.card, reach = TAB.w })
end

-- A row's shade under the mouse and its line of your color; behind the words (a HIGHLIGHT texture covers them).
-- Hooked: called after the row's own scripts are set.
local function Hot(row)
	row.hot = Fill(row, "BACKGROUND", 1)
	row.hot:SetAllPoints()
	UI.Paint(row.hot, C.row, 0.95)
	row.hot:Hide()
	row.line = Fill(row, "ARTWORK")
	row.line:SetSize(2, row:GetHeight() - 8)
	row.line:SetPoint("LEFT", 0, 0)
	row.line:Hide()
	row:HookScript("OnEnter", function(self)
		self.hot:Show()
		UI.Paint(self.line, Theme.Accent)
		self.line:Show()
	end)
	row:HookScript("OnLeave", function(self)
		self.hot:Hide()
		self.line:Hide()
	end)
end

-- A slot with a picture, and the status dot on its corner.
local function SlotOf(row, size, x)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(size, size)
	row.icon:SetPoint("LEFT", x or 6, 0)
	row.icon:SetTexCoord(unpack(ICON))
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, hover = false })
	local pip = CreateFrame("Frame", nil, row)
	pip:SetSize(10, 10)
	pip:SetPoint("CENTER", row.icon, "BOTTOMRIGHT", -1, 1)
	pip:SetFrameLevel(row:GetFrameLevel() + 6)
	pip.ring = pip:CreateTexture(nil, "ARTWORK")
	pip.ring:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(pip.ring, 10)
	pip.ring:SetPoint("CENTER")
	pip.dot = pip:CreateTexture(nil, "OVERLAY")
	pip.dot:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(pip.dot, 6)
	pip.dot:SetPoint("CENTER")
	row.pip = pip
end

local function SetPip(row, presence)
	row.pip:SetShown(presence ~= nil)
	if not presence then return end
	UI.Tint(row.pip.ring, C.panel)
	for _, p in ipairs(PRESENCE) do
		if p.key == presence then UI.Tint(row.pip.dot, C[p.color]) end
	end
end

local function Heading(list, i)
	local h = list.heads[i]
	if h then return h end
	h = CreateFrame("Button", nil, list.area.content)
	h:SetHeight(L.head)
	h.caret = h:CreateTexture(nil, "ARTWORK")
	h.caret:SetTexture(Skin.GLYPH.caret)
	UI.GlyphFit(h.caret, 8)
	h.caret:SetPoint("LEFT", 3, 0)
	h.name = Text(h, UI.TitleFont(13), C.head)
	h.name:SetPoint("LEFT", 18, 0)
	h.tally = Text(h, UI.NameFont(10), C.dim)
	h.tally:SetPoint("LEFT", h.name, "RIGHT", 6, 0)
	h.rule = Shop.Rule(h)
	h.rule:SetPoint("BOTTOMLEFT", 0, 2)
	h.rule:SetPoint("BOTTOMRIGHT", 0, 2)
	h:SetScript("OnClick", function(self)
		if not self.fold then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		S.folds[self.fold] = not S.folds[self.fold]
		Refresh()
	end)
	list.heads[i] = h
	return h
end

-- A list: a scroll area and its rows, made as they are needed, laid top to bottom by Lay.
local function List(page, top, bottom)
	local list = { heads = {}, rows = {}, y = 0, nHead = 0, nRow = 0 }
	list.area = UI.ScrollArea(page, L.w - 2 * L.pad + 4, 100, { quiet = true })
	list.area:SetPoint("TOPLEFT", L.pad - 4, -top)
	list.area:SetPoint("BOTTOMLEFT", L.pad - 4, bottom)
	list.width = L.w - 2 * L.pad - 10
	return list
end

local function Start(list)
	list.y, list.nHead, list.nRow = 0, 0, 0
end

local function PutHead(list, name, tally, fold)
	list.nHead = list.nHead + 1
	local h = Heading(list, list.nHead)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", list.area.content, "TOPLEFT", 0, -list.y)
	h:SetWidth(list.width)
	h.name:SetText(name)
	h.tally:SetText(tally or "")
	h.fold = fold
	h.caret:SetShown(fold ~= nil)
	h.caret:SetRotation(fold and S.folds[fold] and math.pi / 2 or 0)
	UI.Tint(h.caret, C.dim)
	h.name:SetPoint("LEFT", fold and 18 or 2, 0)
	h:Show()
	list.y = list.y + L.head
	return h
end

local function PutRow(list, make, height)
	list.nRow = list.nRow + 1
	local row = list.rows[list.nRow] or make(list)
	list.rows[list.nRow] = row
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", list.area.content, "TOPLEFT", 0, -list.y)
	row:SetWidth(list.width)
	row:Show()
	list.y = list.y + height
	return row
end

local function Finish(list)
	for i = list.nHead + 1, #list.heads do list.heads[i]:Hide() end
	for i = list.nRow + 1, #list.rows do list.rows[i]:Hide() end
	list.area.content:SetSize(list.width, math.max(1, list.y))
	list.area:Update()
end

-- Words in the middle of a page with nothing to list: a heading and a sentence.
local function Empty(page)
	local e = CreateFrame("Frame", nil, page)
	e:SetPoint("TOPLEFT", 40, -200)
	e:SetPoint("TOPRIGHT", -40, -200)
	e:SetHeight(80)
	e.title = Text(e, UI.TitleFont(15), C.head)
	e.title:SetPoint("TOP")
	e.title:SetJustifyH("CENTER")
	e.words = Text(e, UI.TextFont(12), C.dim)
	e.words:SetPoint("TOPLEFT", 0, -24)
	e.words:SetPoint("TOPRIGHT", 0, -24)
	e.words:SetJustifyH("CENTER")
	e.words:SetWordWrap(true)
	e.words:SetMaxLines(4)
	function e:Say(title, words)
		self.title:SetText(title)
		self.words:SetText(words or "")
		self:Show()
	end
	e:Hide()
	return e
end

-- A sentence under the header saying what a page is.
local function Lead(page, text, left)
	local t = Text(page, UI.TextFont(12), C.dim)
	t:SetPoint("TOPLEFT", left or L.pad + 2, -(L.head0 + 12))
	t:SetPoint("RIGHT", page, "RIGHT", -L.pad, 0)
	t:SetWordWrap(true)
	t:SetMaxLines(2)
	t:SetText(text)
	return t
end

local function Back(page, to)
	local b = UI.GlyphButton(page, Skin.GLYPH.chevron, 20, function() Go(to) end, { glyph = 8 })
	b.glyph:SetRotation(math.pi)
	b:SetPoint("TOPLEFT", L.pad, -(L.head0 + 10))
	return b
end

-- Building: friends

local function Whisper(row)
	local a = row.a
	if a then ChatFrameUtil.SendBNetTell(a.accountName) end
end

local function FriendMenu(row)
	local a = row.a
	if not a then return end
	UnitPopup_OpenMenu(a.gameAccountInfo.isOnline and "BN_FRIEND" or "BN_FRIEND_OFFLINE",
		{ battleTag = a.battleTag, bnetIDAccount = a.bnetAccountID, friendsList = true, name = a.accountName })
end

-- Invite as the game's own button does: the one game account that can be, else a menu of them.
local function Invite(b)
	local index = b:GetParent().index
	if not index or b.dimmed then return end
	local one = FriendsListUtil.GetBattleNetFriendGameAccountInfoIfExactlyOneDirectInviteTargetExists(index)
	if one then
		FriendsListUtil.InviteOrRequestToJoin(one.playerGuid, one.gameAccountID)
		return
	end
	if not FriendsListUtil.HasMultipleGameAccounts(index) then return end
	UI.DropMenu(b, function(root)
		root:CreateTitle(TRAVEL_PASS_INVITE)
		for k = 1, C_BattleNet.GetFriendNumGameAccounts(index) do
			local g = C_BattleNet.GetFriendGameAccountInfo(index, k)
			if g then
				local can = FriendsListUtil.GetGameAccountPartyInviteRestriction(g) == BattleNetFriendPartyInviteRestrictionType.None
				local entry = root:CreateButton(Plain(g.characterName) and g.characterName or (g.richPresence or ""), function()
					local now = C_BattleNet.GetGameAccountInfoByID(g.gameAccountID)
					if now and now.playerGuid then FriendsListUtil.InviteOrRequestToJoin(now.playerGuid, g.gameAccountID) end
				end)
				entry:SetEnabled(can)
			end
		end
	end)
end

local function InviteTip(b)
	local index = b:GetParent().index
	if not index then return end
	local why = b.why
	local label = FriendsListUtil.GetBattleNetFriendInviteTypeLabel(FriendsListUtil.GetBattleNetFriendInviteInfo(index).inviteType)
	UI.Tip(b, label ~= "" and label or TRAVEL_PASS_INVITE, why, { side = "TOP" })
end

local function Card(row)
	local a = row.a
	if not a then return end
	local g = a.gameAccountInfo
	local name = FriendsListUtil.GetFriendAccountNameText(a)
	local r, gg, bb = FriendsListUtil.GetFriendNameDisplayColor(a):GetRGB()
	local key = { { text = Plain(a.battleTag) and a.battleTag or "", color = C.dim } }
	local body = {}
	if Playing(g) then
		local cc = RAID_CLASS_COLORS[g.classFilename or ""]
		body[#body + 1] = { rows = { { text = FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE:format(g.characterName, g.characterLevel or 0,
			g.raceName or "", g.className or ""), color = cc and { cc.r, cc.g, cc.b } or C.text } } }
	end
	local where = FriendsListUtil.BuildLocationDisplayText(a)
	if Plain(where) then body[#body + 1] = { text = where, color = C.dim } end
	local said = FriendsListUtil.BuildTooltipBroadcastText(a)
	if Plain(said) then body[#body + 1] = { text = said, color = C.head } end
	if Plain(a.note) then body[#body + 1] = { text = a.note, color = C.dim } end
	local presence = Presence(a)
	local kind
	for _, p in ipairs(PRESENCE) do if p.key == presence then kind = Global(p.label) end end
	Shy.Hover.Show(row, { card = true, about = "friend:" .. tostring(a.bnetAccountID), title = name, titleColor = { r, gg, bb },
		kind = kind or Global("SOCIAL_UI_PRESENCE_TYPE_LABEL_OFFLINE"), key = key, body = body,
		hints = { { "left", WORDS.whisper }, { "right", WORDS.menu } } }, { at = Beside(row) })
end

local function FriendRow(list)
	local row = CreateFrame("Button", nil, list.area.content)
	row:SetHeight(L.row)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	SlotOf(row, L.slot)
	row.invite = UI.GlyphButton(row, Skin.GLYPH.invite, 22, Invite, { width = 26, glyph = 13 })
	row.invite:SetPoint("RIGHT", -6, 0)
	row.invite:HookScript("OnEnter", InviteTip)
	row.invite:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	row.where = Text(row, UI.TextFont(11), C.dim)
	row.where:SetPoint("TOPRIGHT", -40, -8)
	row.where:SetJustifyH("RIGHT")
	row.name = Text(row, UI.NameFont(13), C.text)
	row.name:SetPoint("TOPLEFT", L.slot + 16, -7)
	row.star = row:CreateTexture(nil, "ARTWORK")
	row.star:SetTexture(Skin.GLYPH.star)
	UI.GlyphFit(row.star, 11)
	row.char = Text(row, UI.TextFont(11), C.dim)
	row.char:SetPoint("TOPLEFT", L.slot + 16, -25)
	row.char:SetPoint("RIGHT", -40, 0)
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then FriendMenu(self) else Whisper(self) end
	end)
	row:SetScript("OnEnter", Card)
	row:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	Hot(row)
	return row
end

local function DrawFriend(row, f)
	local a, g = f.a, f.a.gameAccountInfo
	row.a, row.index = a, f.index
	local presence = Presence(a)
	-- The slot: the character's class, the game's badge for another game, empty offline.
	local playing = Playing(g)
	row.icon:SetDesaturated(false)
	if not presence then
		row.icon:Hide()
		row.slot:Empty(true)
	else
		row.slot:Empty(false)
		row.icon:Show()
		if playing and Plain(g.classFilename) then
			row.icon:SetTexture("Interface\\Icons\\ClassIcon_" .. g.classFilename)
			row.icon:SetTexCoord(unpack(ICON))
		else
			row.icon:SetTexCoord(0, 1, 0, 1)
			C_Texture.SetTitleIconTexture(row.icon, g.clientProgram, Enum.TitleIconVersion.Medium, g.subIcon)
			row.icon:SetDesaturated(FriendsListUtil.IsPlayingWoW(g))
		end
	end
	SetPip(row, presence)
	row.name:SetText(FriendsListUtil.GetFriendAccountNameText(a))
	row.name:SetTextColor(FriendsListUtil.GetFriendNameDisplayColor(a):GetRGB())
	-- Where they are on the right; the name gives way to it.
	row.where:SetText(playing and (g.areaName or "") or "")
	row.where:SetWidth(math.min(150, math.ceil(row.where:GetStringWidth()) + 1))
	local room = L.w - 2 * L.pad - 10 - (L.slot + 16) - 40 - row.where:GetWidth() - 22
	local wide = math.min(room, math.ceil(row.name:GetStringWidth()))
	row.name:SetWidth(wide)
	row.star:ClearAllPoints()
	row.star:SetPoint("LEFT", row.name, "LEFT", wide + 4, 1)
	row.star:SetShown(a.isFavorite == true)
	UI.Tint(row.star, C.alert)
	-- Under the name: the character, level and class in the class's color; else where they are, or when last on.
	if playing then
		local cc = RAID_CLASS_COLORS[g.classFilename or ""]
		local hex = cc and ("|cff%02x%02x%02x"):format(cc.r * 255, cc.g * 255, cc.b * 255) or ""
		row.char:SetText(hex .. g.characterName .. (cc and "|r" or "") .. "  " .. (g.characterLevel or "") .. " " .. (g.className or ""))
	else
		row.char:SetText(FriendsListUtil.BuildLocationDisplayText(a))
	end
	-- Invite: on a friend who is on; faded where the game says they can't be, with its reason.
	row.invite:SetShown(presence ~= nil)
	local restriction = FriendsListUtil.GetBattleNetFriendPartyInviteRestriction(f.index)
	local can = restriction == BattleNetFriendPartyInviteRestrictionType.None
	row.invite.dimmed = not can
	row.invite.why = (not can) and FriendsListUtil.GetBattleNetFriendPartyInviteRestrictionText(restriction) or nil
	row.invite:SetAlpha(can and 1 or 0.35)
end

-- The filter menu: the game's statuses, then its tags.
local function FilterMenu(owner)
	UI.DropMenu(owner, function(root)
		local function Toggle(key) return function()
			S.filters[key] = (not S.filters[key]) or nil
			Refresh()
		end end
		root:CreateSection(Global("SOCIAL_FILTER_DROPDOWN_STATUS"))
		for _, s in ipairs(STATUS) do
			root:CreateCheckbox(Global(s.label), function() return S.filters[s.field] == true end, Toggle(s.field))
		end
		local tags = {}
		for _, t in ipairs(SocialUIUtil.GetSupportedBattleNetFriendTagInterestsForCurrentGameType() or {}) do tags[#tags + 1] = t end
		for _, t in ipairs(SocialUIUtil.GetSupportedBattleNetFriendTagRolesForCurrentGameType() or {}) do tags[#tags + 1] = t end
		if #tags > 0 then
			root:CreateSection(Global("SOCIAL_FILTER_DROPDOWN_TAGS"))
			for _, t in ipairs(tags) do
				root:CreateCheckbox(SocialUIUtil.GetLabelForBattleNetFriendTag(t), function() return S.filters[t] == true end, Toggle(t))
			end
		end
	end)
end

local function FilterLabel(key)
	if type(key) == "number" then return SocialUIUtil.GetLabelForBattleNetFriendTag(key) end
	for _, s in ipairs(STATUS) do if s.field == key then return Global(s.label) end end
	return tostring(key)
end

local function BuildFriends(page)
	-- You: your status, your BattleTag, the message your friends see; the ignore list at the right.
	local pres = CreateFrame("Button", nil, page)
	pres:SetSize(34, 20)
	pres:SetPoint("TOPLEFT", L.pad, -(L.head0 + 10))
	pres.dot = pres:CreateTexture(nil, "OVERLAY")
	pres.dot:SetTexture(Skin.GLYPH.dot)
	UI.GlyphFit(pres.dot, 8)
	pres.dot:SetPoint("LEFT", 7, 0)
	pres.caret = pres:CreateTexture(nil, "OVERLAY")
	pres.caret:SetTexture(Skin.GLYPH.caret)
	UI.GlyphFit(pres.caret, 8)
	pres.caret:SetPoint("RIGHT", -5, 0)
	UI.KeyPress(pres, { fill = C.bg, glyphs = { pres.caret }, sink = { pres.dot, pres.caret } })
	pres:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		UI.DropMenu(self, function(root)
			local mine = MyPresence()
			for _, p in ipairs(PRESENCE) do
				root:CreateRadio(Global(p.label), function() return mine == p.key end, function() SetPresence(p.key) end)
			end
		end)
	end)
	own.pres = pres

	local tag = CreateFrame("Button", nil, page)
	tag:SetHeight(22)
	tag:SetPoint("TOPLEFT", L.pad + 42, -(L.head0 + 9))
	tag.name = Text(tag, UI.TitleFont(17), C.head)
	tag.name:SetPoint("LEFT")
	tag.number = Text(tag, UI.TextFont(11), C.dim)
	tag.number:SetPoint("BOTTOMLEFT", tag.name, "BOTTOMRIGHT", 1, 1)
	tag:SetScript("OnClick", function(self)
		local mine = BNet_GetBattleTagSelf()
		if not Plain(mine) then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		CopyToClipboard(mine)
		S.copied = true
		UI.Tip(self, WORDS.copied, mine, { side = "TOP" })
	end)
	tag:SetScript("OnEnter", function(self) UI.Tip(self, S.copied and WORDS.copied or "Copy your BattleTag", nil, { side = "TOP" }) end)
	tag:SetScript("OnLeave", function(self)
		S.copied = false
		UI.TipHide(self)
	end)
	own.tag = tag

	-- The message: plain words at rest, a field while you change it; Enter sets it, Escape puts it back.
	local say = CreateFrame("EditBox", nil, page)
	say:SetHeight(18)
	say:SetPoint("TOPLEFT", L.pad + 40, -(L.head0 + 32))
	say:SetPoint("RIGHT", page, "RIGHT", -(L.pad + 28), 0)
	say:SetAutoFocus(false)
	say:SetFontObject(UI.TextFont(11))
	say:SetTextInsets(3, 3, 0, 0)
	say:SetMaxLetters(L.most)
	UI.Skin(say, C.bg, C.border)
	UI.SetBorder(say, C.border)
	say.hint = Text(say, UI.TextFont(11), C.dim)
	say.hint:SetPoint("LEFT", 3, 0)
	say.hint:SetText(WORDS.message)
	local function Rest(self)
		local skinned = self:HasFocus() or self:IsMouseOver()
		for _, region in ipairs({ self:GetRegions() }) do
			if region ~= self.hint and region:GetObjectType() == "Texture" then region:SetShown(skinned) end
		end
	end
	say:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) Rest(self) end)
	say:SetScript("OnEditFocusLost", function(self)
		UI.SetBorder(self, C.border)
		local _, _, _, now = BNGetInfo()
		self:SetText(now or "")
		Rest(self)
	end)
	say:SetScript("OnEnter", Rest)
	say:SetScript("OnLeave", Rest)
	say:SetScript("OnEnterPressed", function(self)
		C_BattleNet.SetCustomMessage(strtrim(self:GetText() or ""))
		self:ClearFocus()
	end)
	say:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	say:SetScript("OnTextChanged", function(self) self.hint:SetShown((self:GetText() or "") == "" and not self:HasFocus()) end)
	say.Rest = Rest
	own.say = say

	own.down = Text(page, UI.TextFont(12), C.bad)
	own.down:SetPoint("LEFT", page, "TOPLEFT", L.pad + 42, -(L.head0 + 20))
	own.down:SetText(WORDS.unavailable)

	own.ignoreButton = UI.GlyphButton(page, Skin.GLYPH.block, 20, function() Go("ignore") end,
		{ glyph = 11, tip = { Global("IGNORE_LIST"), WORDS.ignoreSay } })
	own.ignoreButton:SetPoint("TOPRIGHT", -L.pad, -(L.head0 + 10))

	-- Search and the game's filters.
	own.search = Shop.Search(page, WORDS.search, function(text)
		if text == S.search then return end
		S.search = text
		Refresh()
	end)
	own.search:SetPoint("TOPLEFT", L.pad, -(L.top + 6))
	own.search:SetPoint("RIGHT", page, "RIGHT", -(L.pad + 54), 0)
	own.search:SetHeight(L.find - 2)
	local funnel = CreateFrame("Button", nil, page)
	funnel:SetSize(48, L.find)
	funnel:SetPoint("TOPRIGHT", -L.pad, -(L.top + 5))
	funnel.glyph = funnel:CreateTexture(nil, "OVERLAY")
	funnel.glyph:SetTexture(Skin.GLYPH.funnel)
	UI.GlyphFit(funnel.glyph, 12)
	funnel.glyph:SetPoint("LEFT", 7, 0)
	funnel.count = Text(funnel, UI.NameFont(11), C.text)
	funnel.count:SetPoint("LEFT", funnel.glyph, "RIGHT", 3, 0)
	funnel.caret = funnel:CreateTexture(nil, "OVERLAY")
	funnel.caret:SetTexture(Skin.GLYPH.caret)
	UI.GlyphFit(funnel.caret, 8)
	funnel.caret:SetPoint("RIGHT", -6, 0)
	UI.KeyPress(funnel, { words = funnel.count, glyphs = { funnel.glyph, funnel.caret }, sink = { funnel.glyph, funnel.caret, funnel.count } })
	funnel:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		FilterMenu(self)
	end)
	own.funnel = funnel
	own.chips = {}

	own.friends = List(page, L.top + L.find + 12, L.pad + L.foot + 8)
	own.friendsEmpty = Empty(page)
	own.tally = Text(page, UI.TextFont(11), C.dim)
	own.tally:SetPoint("BOTTOMLEFT", L.pad + 2, L.pad + 6)
	own.add = UI.Button(page, WORDS.addFriend, 130, function() AddFriendFrame_Show() end)
	own.add:SetHeight(L.foot)
	own.add:SetPoint("BOTTOMRIGHT", -L.pad, L.pad)
	own.add:SetPrimary(true)
end

local function Chip(i)
	local chip = own.chips[i]
	if chip then return chip end
	chip = Shop.Chip(own.pages.friends, "", function(self)
		S.filters[self.key] = nil
		Refresh()
	end)
	chip:SetOn(true)
	own.chips[i] = chip
	return chip
end

local function DrawFriends()
	local up = BNConnected()
	local tagSelf = BNet_GetBattleTagSelf()
	local name, number = (Plain(tagSelf) and tagSelf or ""):match("^(.-)(#%d+)$")
	own.tag.name:SetText(name or tagSelf or "")
	own.tag.number:SetText(number or "")
	own.tag:SetWidth(math.ceil(own.tag.name:GetStringWidth() + own.tag.number:GetStringWidth()) + 2)
	own.tag:SetShown(up)
	own.say:SetShown(up)
	own.pres:SetShown(up)
	own.down:SetShown(not up)
	if up and not own.say:HasFocus() then
		local _, _, _, now = BNGetInfo()
		own.say:SetText(now or "")
		own.say:Rest()
	end
	local mine = MyPresence()
	for _, p in ipairs(PRESENCE) do
		if p.key == mine then UI.Tint(own.pres.dot, C[p.color]) end
	end

	-- The filters that are on, a chip each; the list moves down under them.
	local keys = {}
	for key in pairs(S.filters) do keys[#keys + 1] = key end
	table.sort(keys, function(x, y) return tostring(x) < tostring(y) end)
	local x = L.pad
	for i, key in ipairs(keys) do
		local chip = Chip(i)
		chip.key = key
		chip:Say(FilterLabel(key) .. "  \195\151")
		chip:ClearAllPoints()
		chip:SetPoint("TOPLEFT", x, -(L.top + L.find + 12))
		chip:Show()
		x = x + chip:GetWidth() + 6
	end
	for i = #keys + 1, #own.chips do own.chips[i]:Hide() end
	own.funnel.count:SetText(#keys > 0 and #keys or "")
	own.funnel:SetOn(#keys > 0)
	local list = own.friends
	list.area:SetPoint("TOPLEFT", L.pad - 4, -(L.top + L.find + 12 + (#keys > 0 and L.chips or 0)))

	-- Favorites, then everyone else, each under a heading that folds.
	local favs, rest = Friends()
	Start(list)
	for _, part in ipairs({ { "favorites", WORDS.favorites, favs }, { "friends", WORDS.friends, rest } }) do
		local fold, label, those = part[1], part[2], part[3]
		if #those > 0 then
			local on = 0
			for _, f in ipairs(those) do if f.a.gameAccountInfo.isOnline then on = on + 1 end end
			PutHead(list, label, WORDS.online:format(on, #those), fold)
			if not S.folds[fold] then
				for _, f in ipairs(those) do DrawFriend(PutRow(list, FriendRow, L.row), f) end
			end
			list.y = list.y + L.gap
		end
	end
	Finish(list)
	local total, online = BNGetNumFriends()
	if #favs + #rest == 0 then
		if not up then own.friendsEmpty:Say(WORDS.unavailable)
		elseif (total or 0) == 0 then own.friendsEmpty:Say(WORDS.nobody, WORDS.nobodySay)
		else own.friendsEmpty:Say(WORDS.none, WORDS.noneSay) end
	else
		own.friendsEmpty:Hide()
	end
	own.tally:SetText(WORDS.online:format(UI.Wrap(C.good, online or 0), total or 0))
	own.add:SetUsable(not C_SocialRestrictions.IsFriendsDisabled())
end

-- Building: friend requests

local FRIEND_LEVEL = {
	[Enum.BattleNetFriendLevel.RealID] = "SOCIAL_UI_FRIEND_REQUESTS_CARD_REAL_ID_LABEL",
	[Enum.BattleNetFriendLevel.BattleTag] = "SOCIAL_UI_FRIEND_REQUESTS_CARD_BATTLE_NET_LABEL",
	[Enum.BattleNetFriendLevel.Title] = "SOCIAL_UI_FRIEND_REQUESTS_CARD_TITLE_LABEL",
}

local function Decline(b)
	local row = b:GetParent()
	local index, id, name = row.index, row.id, row.who
	UI.DropMenu(b, function(root)
		root:CreateButton(DECLINE, function() BNDeclineFriendInvite(id) end)
		root:CreateButton(REPORT_PLAYER, function()
			ReportFrame:InitiateReport(ReportInfo:CreateReportInfoFromType(Enum.ReportType.Friend), name,
				PlayerLocation:CreateFromBattleNetID(id), true)
		end)
		if FriendsListUtil.CanAddFriendRequestSenderToBattleNetBlockList(index) then
			root:CreateButton(BLOCK_INVITES, function() StaticPopup_Show("CONFIRM_BLOCK_INVITES", name, nil, id) end)
		end
	end)
end

local function RequestRow(list)
	local row = CreateFrame("Frame", nil, list.area.content)
	row:SetHeight(L.tall)
	row:EnableMouse(true)
	Hot(row)
	SlotOf(row, L.slot)
	row.pip:Hide()
	row.name = Text(row, UI.NameFont(13), C.text)
	row.name:SetPoint("TOPLEFT", L.slot + 16, -9)
	row.sub = Text(row, UI.TextFont(11), C.dim)
	row.sub:SetPoint("TOPLEFT", L.slot + 16, -27)
	row.decline = UI.Button(row, DECLINE, 84, Decline)
	row.decline:SetHeight(22)
	row.decline:SetPoint("RIGHT", -6, 0)
	row.decline.caret = row.decline:CreateTexture(nil, "OVERLAY")
	row.decline.caret:SetTexture(Skin.GLYPH.caret)
	UI.GlyphFit(row.decline.caret, 7)
	row.decline.caret:SetPoint("RIGHT", -7, 0)
	UI.Tint(row.decline.caret, C.dim)
	row.decline.text:ClearAllPoints()
	row.decline.text:SetPoint("CENTER", -5, 0)
	row.accept = UI.Button(row, ACCEPT, 70, function(self) BNAcceptFriendInvite(self:GetParent().id) end)
	row.accept:SetHeight(22)
	row.accept:SetPoint("RIGHT", row.decline, "LEFT", -6, 0)
	row.accept:SetPrimary(true)
	row.name:SetPoint("RIGHT", row.accept, "LEFT", -8, 0)
	return row
end

local function DrawRequests()
	local list = own.requests
	Start(list)
	local n = BNGetNumFriendInvites() or 0
	for i = 1, n do
		local v = C_BattleNet.GetFriendInviteInfo(i)
		if v then
			local row = PutRow(list, RequestRow, L.tall)
			row.index, row.id, row.who = i, v.inviteID, v.accountName
			row.icon:SetTexture(BNET_BADGE)
			row.icon:SetTexCoord(0, 1, 0, 1)
			row.name:SetText(v.accountName or "")
			local color = v.friendLevel == Enum.BattleNetFriendLevel.Title and NORMAL_FONT_COLOR or BATTLENET_FONT_COLOR
			row.name:SetTextColor(color:GetRGB())
			local parts = { Global(FRIEND_LEVEL[v.friendLevel] or "") }
			if (v.creationTimestamp or 0) > 0 then
				parts[#parts + 1] = SOCIAL_UI_FRIEND_REQUESTS_CARD_TIMESTAMP_FORMAT:format(FriendsListUtil.GetRelativeTimeText(v.creationTimestamp))
			end
			row.sub:SetText(table.concat(parts, "  \194\183  "))
		end
	end
	Finish(list)
	if n == 0 then own.requestsEmpty:Say(WORDS.noRequests) else own.requestsEmpty:Hide() end
end

local function BuildRequests(page)
	Lead(page, WORDS.requestsSay)
	own.requests = List(page, L.head0 + 40, L.pad + L.foot + 8)
	own.requestsEmpty = Empty(page)
	local add = UI.Button(page, WORDS.addFriend, 130, function() AddFriendFrame_Show() end)
	add:SetHeight(L.foot)
	add:SetPoint("BOTTOMRIGHT", -L.pad, L.pad)
	add:SetPrimary(true)
end

-- Building: Quick Join

local function JoinRow(list)
	local row = CreateFrame("Frame", nil, list.area.content)
	row:SetHeight(L.tall)
	row:EnableMouse(true)
	SlotOf(row, L.slot)
	row.name = Text(row, UI.NameFont(13), C.text)
	row.name:SetPoint("TOPLEFT", L.slot + 16, -9)
	row.sub = Text(row, UI.TextFont(11), C.dim)
	row.sub:SetPoint("TOPLEFT", L.slot + 16, -27)
	row.ask = UI.Button(row, WORDS.ask, 96, function(self)
		local guid = self:GetParent().guid
		if guid and QuickJoinRoleSelectionFrame then QuickJoinRoleSelectionFrame:ShowForGroup(guid) end
	end)
	row.ask:SetHeight(22)
	row.ask:SetPoint("RIGHT", -6, 0)
	row.name:SetPoint("RIGHT", row.ask, "LEFT", -8, 0)
	row.sub:SetPoint("RIGHT", row.ask, "LEFT", -8, 0)
	row:SetScript("OnEnter", function(self)
		if not self.guid then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		SocialQueueUtil_SetTooltip(GameTooltip, SocialQueueUtil_GetHeaderName(self.guid), C_SocialQueue.GetGroupQueues(self.guid) or {},
			self.canJoin, SocialQueueUtil_HasRelationshipWithLeader(self.guid))
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
	Hot(row)
	return row
end

local function DrawJoin()
	local list = own.join
	Start(list)
	local groups = C_SocialQueue.GetAllGroups() or {}
	for _, guid in ipairs(groups) do
		local canJoin, numQueues = C_SocialQueue.GetGroupInfo(guid)
		local queues = C_SocialQueue.GetGroupQueues(guid) or {}
		local members = C_SocialQueue.GetGroupMembers(guid) or {}
		local row = PutRow(list, JoinRow, L.tall)
		row.guid = guid
		row.canJoin = canJoin and (numQueues or 0) > 0
		row.name:SetText(SocialQueueUtil_GetHeaderName(guid) or "")
		local what = queues[1] and SocialQueueUtil_GetQueueName(queues[1].queueData) or ""
		row.sub:SetText(what .. ((#members > 0) and ("  \194\183  " .. #members .. (#members == 1 and " in it" or " in the group")) or ""))
		local leader = members[1] and members[1].guid
		local _, class = nil, nil
		if leader then _, class = GetPlayerInfoByGUID(leader) end
		if Plain(class) then
			row.icon:SetTexture("Interface\\Icons\\ClassIcon_" .. class)
			row.icon:SetTexCoord(unpack(ICON))
			row.icon:Show()
			row.slot:Empty(false)
		else
			row.icon:Hide()
			row.slot:Empty(true)
		end
		SetPip(row, "online")
		row.ask:SetUsable(row.canJoin)
	end
	Finish(list)
	if #groups == 0 then own.joinEmpty:Say(WORDS.noGroups) else own.joinEmpty:Hide() end
end

local function BuildJoin(page)
	Lead(page, WORDS.joinSay)
	own.join = List(page, L.head0 + 46, L.pad)
	own.joinEmpty = Empty(page)
end

-- Building: the raid

local function Leads()
	return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Dropped: onto another name in another group swaps the two; onto a group with room moves it there.
local function Drop(row)
	if InCombatLockdown() then return end
	for _, other in ipairs(own.members) do
		if other ~= row and other:IsShown() and other.id and other:IsMouseOver() and other.group ~= row.group then
			SwapRaidSubgroup(row.id, other.id)
			return
		end
	end
	for g, box in ipairs(own.groups) do
		if box:IsMouseOver() and g ~= row.group and box.count < MEMBERS_PER_RAID_GROUP then
			SetRaidSubgroup(row.id, g)
			return
		end
	end
end

local function Member(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(L.member)
	row:RegisterForClicks("RightButtonUp")
	row:RegisterForDrag("LeftButton")
	row:SetMovable(true)
	row.back = Fill(row, "BACKGROUND")
	row.back:SetAllPoints()
	row.rank = row:CreateTexture(nil, "ARTWORK")
	row.rank:SetSize(11, 11)
	row.rank:SetPoint("LEFT", 4, 0)
	row.role = row:CreateTexture(nil, "ARTWORK")
	row.role:SetSize(11, 11)
	row.role:SetPoint("RIGHT", -5, 0)
	row.level = Text(row, UI.TextFont(10), C.dim)
	row.level:SetPoint("RIGHT", -22, 0)
	row.level:SetJustifyH("RIGHT")
	row.name = Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("LEFT", 20, 0)
	row.name:SetPoint("RIGHT", row.level, "LEFT", -4, 0)
	row:SetScript("OnClick", function(self)
		if self.id and self.who then UnitPopup_OpenMenu("RAID", { unit = "raid" .. self.id, name = self.who }) end
	end)
	row:SetScript("OnEnter", function(self)
		if not self.id then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetUnit("raid" .. self.id)
		GameTooltip:Show()
	end)
	row:HookScript("OnLeave", function() GameTooltip:Hide() end)
	row:SetScript("OnDragStart", function(self)
		if not self.id or InCombatLockdown() or not Leads() then return end
		self:SetFrameLevel(self:GetFrameLevel() + 20)
		self:StartMoving()
		self.moving = true
	end)
	row:SetScript("OnDragStop", function(self)
		if not self.moving then return end
		self.moving = false
		self:StopMovingOrSizing()
		self:SetFrameLevel(self:GetFrameLevel() - 20)
		Drop(self)
		Stale()   -- laid back in its place, or where the game now has it
	end)
	Hot(row)
	return row
end

local function BuildRaid(page)
	-- In a raid: the roles, everyone assists, the groups.
	own.roles = {}
	local x = L.pad
	for i, role in ipairs({ "TANK", "HEALER", "DAMAGER" }) do
		local chip = CreateFrame("Frame", nil, page)
		chip:SetSize(76, 18)
		chip:SetPoint("TOPLEFT", x, -(L.head0 + 12))
		UI.Skin(chip, C.bg, C.border)
		chip.icon = chip:CreateTexture(nil, "ARTWORK")
		chip.icon:SetSize(11, 11)
		chip.icon:SetPoint("LEFT", 6, 0)
		chip.icon:SetAtlas(ROLE_ATLAS[role], false)
		chip.text = Text(chip, UI.NameFont(10), C.dim)
		chip.text:SetPoint("LEFT", chip.icon, "RIGHT", 4, 0)
		chip.role = role
		own.roles[i] = chip
		x = x + 80
	end
	own.assists = Shop.Chip(page, WORDS.assists, function(self)
		if not UnitIsGroupLeader("player") then return end
		local want = not IsEveryoneAssistant()
		C_PartyInfo.SetEveryoneIsAssistant(want)
		self:SetOn(want)
	end)
	own.assists:SetPoint("TOPRIGHT", -L.pad, -(L.head0 + 12))
	own.groups, own.members = {}, {}
	local groups = CreateFrame("Frame", nil, page)
	groups:SetPoint("TOPLEFT", L.pad, -(L.head0 + 42))
	groups:SetPoint("BOTTOMRIGHT", -L.pad, L.pad + L.foot + 8)
	own.groupsFrame = groups
	for g = 1, NUM_RAID_GROUPS do
		local box = CreateFrame("Frame", nil, groups)
		box:SetSize(L.group, L.groupH)
		box:SetPoint("TOPLEFT", ((g - 1) % 2) * (L.group + L.groupGap), -math.floor((g - 1) / 2) * (L.groupH + L.groupGap))
		box.title = Text(box, UI.TitleFont(12), C.head)
		box.title:SetPoint("TOPLEFT", 0, -2)
		box.title:SetText(GROUP_NUMBER:format(g))
		box.tally = Text(box, UI.TextFont(10), C.dim)
		box.tally:SetPoint("TOPRIGHT", 0, -3)
		box.rule = Shop.Rule(box)
		box.rule:SetPoint("TOPLEFT", 0, -17)
		box.rule:SetPoint("TOPRIGHT", 0, -17)
		box.slots = {}
		for k = 1, MEMBERS_PER_RAID_GROUP do
			local spot = Fill(box, "BACKGROUND")
			spot:SetPoint("TOPLEFT", 0, -(20 + (k - 1) * (L.member + 0.5)))
			spot:SetPoint("TOPRIGHT", 0, -(20 + (k - 1) * (L.member + 0.5)))
			spot:SetHeight(L.member)
			UI.Paint(spot, C.bg, 0.5)
			box.slots[k] = spot
		end
		box.count = 0
		own.groups[g] = box
	end
	own.raidNote = Text(page, UI.TextFont(11), C.dim)
	own.raidNote:SetPoint("BOTTOMLEFT", L.pad + 112, L.pad + 6)
	own.raidInfo = UI.Button(page, WORDS.raidInfo, 100, function() Go("raidinfo") end)
	own.raidInfo:SetHeight(L.foot)
	own.raidInfo:SetPoint("BOTTOMLEFT", L.pad, L.pad)
	-- In a party, or alone: what a raid is, and Convert to raid.
	own.raidEmpty = Empty(page)
	own.convert = UI.Button(page, CONVERT_TO_RAID, 150, function() C_PartyInfo.ConvertToRaid() end)
	own.convert:SetHeight(L.foot)
	own.convert:SetPoint("TOP", own.raidEmpty, "BOTTOM", 0, -6)
	own.convert:SetPrimary(true)
end

local function DrawRaid()
	local raid = IsInRaid()
	for _, chip in ipairs(own.roles) do chip:SetShown(raid) end
	own.assists:SetShown(raid)
	own.groupsFrame:SetShown(raid)
	own.convert:SetShown(not raid and IsInGroup())
	if not raid then
		for _, row in ipairs(own.members) do row:Hide() end
		own.raidNote:SetText("")
		if IsInGroup() then own.raidEmpty:Say(WORDS.party, WORDS.partySay) else own.raidEmpty:Say(WORDS.alone, WORDS.aloneSay) end
		own.convert:SetUsable(C_PartyInfo.AllowedToDoPartyConversion(true))
		return
	end
	own.raidEmpty:Hide()
	-- A fight: names may not be read, and the groups can't change; the page keeps what it showed.
	if InCombatLockdown() then
		own.raidNote:SetText(WORDS.fight)
		return
	end
	own.raidNote:SetText(Leads() and WORDS.drag or "")
	local counts = GetGroupMemberCountsForDisplay()
	for _, chip in ipairs(own.roles) do
		chip.text:SetText(UI.Wrap(C.text, counts[chip.role] or 0))
		chip:SetWidth(math.ceil(chip.text:GetStringWidth()) + 28)
	end
	own.roles[2]:SetPoint("TOPLEFT", own.roles[1], "TOPRIGHT", 5, 0)
	own.roles[3]:SetPoint("TOPLEFT", own.roles[2], "TOPRIGHT", 5, 0)
	own.assists:SetOn(IsEveryoneAssistant())
	own.assists:SetAlpha(UnitIsGroupLeader("player") and 1 or 0.4)
	for _, box in ipairs(own.groups) do box.count = 0 end
	local used = 0
	for i = 1, GetNumGroupMembers() do
		local name, rank, group, level, _, file, _, online, dead, _, _, lfgRole = GetRaidRosterInfo(i)
		local box = own.groups[group or 0]
		if box and box.count < MEMBERS_PER_RAID_GROUP then
			used = used + 1
			local row = own.members[used]
			if not row then
				row = Member(own.groupsFrame)
				own.members[used] = row
			end
			box.count = box.count + 1
			row.id, row.who, row.group = i, name, group
			row:SetParent(box)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", box.slots[box.count], "TOPLEFT")
			row:SetPoint("TOPRIGHT", box.slots[box.count], "TOPRIGHT")
			row.name:SetText(Plain(name) and Ambiguate(name, "none") or UNKNOWN)
			local cc = RAID_CLASS_COLORS[file or ""]
			if not online then UI.Ink(row.name, C.dim)
			elseif dead then UI.Ink(row.name, C.bad)
			elseif cc then row.name:SetTextColor(cc.r, cc.g, cc.b)
			else UI.Ink(row.name, C.text) end
			row.level:SetText((level or 0) > 0 and level or "")
			row.rank:SetShown(RANK_ART[rank or 0] ~= nil)
			if RANK_ART[rank or 0] then row.rank:SetTexture(RANK_ART[rank]) end
			local atlas = ROLE_ATLAS[lfgRole or ""]
			row.role:SetShown(atlas ~= nil)
			if atlas then row.role:SetAtlas(atlas, false) end
			UI.Paint(row.back, C.row, 0.55)
			row:SetAlpha(online and 1 or 0.6)
			row:Show()
		end
	end
	for i = used + 1, #own.members do own.members[i]:Hide() end
	for _, box in ipairs(own.groups) do box.tally:SetText(("%d of %d"):format(box.count, MEMBERS_PER_RAID_GROUP)) end
end

-- Building: raid info and the ignore list (pages reached from Raid and Friends)

local function LineRow(list)
	local row = CreateFrame("Button", nil, list.area.content)
	row:SetHeight(L.slim)
	row.wash = Fill(row, "BACKGROUND", 2)
	row.wash:SetAllPoints()
	row.wash:Hide()
	row.glyph = row:CreateTexture(nil, "ARTWORK")
	UI.GlyphFit(row.glyph, 11)
	row.glyph:SetPoint("LEFT", 8, 0)
	row.right = Text(row, UI.TextFont(11), C.dim)
	row.right:SetPoint("RIGHT", -8, 0)
	row.right:SetJustifyH("RIGHT")
	row.name = Text(row, UI.NameFont(12), C.text)
	row.name:SetPoint("LEFT", 26, 0)
	row.name:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row:SetScript("OnClick", function(self)
		if not self.pick then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		S.ignore = self.pick
		Refresh()
	end)
	Hot(row)
	return row
end

local function DrawRaidInfo()
	local list = own.saved
	Start(list)
	local n = GetNumSavedInstances() or 0
	for i = 1, n do
		local name, _, reset, _, locked, extended, _, _, _, difficulty = GetSavedInstanceInfo(i)
		local row = PutRow(list, LineRow, L.slim)
		row.pick = nil
		row.glyph:Hide()
		row.name:SetPoint("LEFT", 8, 0)
		local live = locked or extended
		row.name:SetText((name or "") .. (Plain(difficulty) and UI.Wrap(C.dim, "  " .. difficulty) or ""))
		UI.Ink(row.name, live and C.text or C.dim)
		row.right:SetText(live and (SecondsToTime(reset or 0, true, nil, 3) .. (extended and ("  \194\183  " .. WORDS.extended) or ""))
			or RAID_INSTANCE_EXPIRES_EXPIRED)
		row.wash:Hide()
	end
	local bosses = GetNumSavedWorldBosses() or 0
	for i = 1, bosses do
		local name, _, reset = GetSavedWorldBossInfo(i)
		local row = PutRow(list, LineRow, L.slim)
		row.pick = nil
		row.glyph:Hide()
		row.name:SetPoint("LEFT", 8, 0)
		row.name:SetText((name or "") .. UI.Wrap(C.dim, "  " .. RAID_INFO_WORLD_BOSS))
		UI.Ink(row.name, C.text)
		row.right:SetText(SecondsToTime(reset or 0, true, nil, 3))
		row.wash:Hide()
	end
	Finish(list)
	if n + bosses == 0 then own.savedEmpty:Say(NO_RAID_INSTANCES_SAVED) else own.savedEmpty:Hide() end
end

local function BuildRaidInfo(page)
	Back(page, "raid")
	Lead(page, WORDS.savedSay, L.pad + 28)
	own.saved = List(page, L.head0 + 40, L.pad)
	own.savedEmpty = Empty(page)
end

local function Ignored()
	local out = {}
	for i = 1, C_FriendList.GetNumIgnores() or 0 do
		out[#out + 1] = { kind = "ignore", index = i, name = C_FriendList.GetIgnoreName(i) or UNKNOWN }
	end
	for i = 1, BNGetNumBlocked() or 0 do
		local id, name = BNGetBlockedInfo(i)
		out[#out + 1] = { kind = "block", index = i, id = id, name = name or UNKNOWN }
	end
	return out
end

local function Unignore()
	local pick = S.ignore
	if not pick then return end
	if pick.kind == "ignore" then
		C_FriendList.DelIgnoreByIndex(pick.index)
	elseif pick.id then
		C_BattleNet.SetBlocked(pick.id, false)
	end
	S.ignore = nil
end

local function IgnorePlayer()
	if UnitCanCooperate("player", "target") and UnitIsHumanPlayer("target") then
		C_FriendList.AddIgnore(NameUtil.GetUnmodifiedUnitFullName("target"))
	else
		StaticPopup_Show("ADD_IGNORE")
	end
end

local function DrawIgnore()
	local list = own.ignored
	Start(list)
	local all = Ignored()
	-- The pick stays while its player is listed.
	local still
	for _, e in ipairs(all) do
		if S.ignore and e.kind == S.ignore.kind and e.name == S.ignore.name then still = e end
	end
	S.ignore = still or all[1]
	for _, e in ipairs(all) do
		local row = PutRow(list, LineRow, L.slim)
		row.pick = e
		row.glyph:SetTexture(Skin.GLYPH.block)
		UI.GlyphFit(row.glyph, 11)
		UI.Tint(row.glyph, C.bad)
		row.glyph:Show()
		row.name:SetPoint("LEFT", 26, 0)
		row.name:SetText(e.name)
		UI.Ink(row.name, C.text)
		row.right:SetText(e.kind == "ignore" and WORDS.player or WORDS.battlenet)
		local on = S.ignore and S.ignore.kind == e.kind and S.ignore.index == e.index
		if on then
			local r, g, b = Theme.Accent()
			row.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.26), CreateColor(r, g, b, 0.04))
		end
		row.wash:SetShown(on == true)
	end
	Finish(list)
	if #all == 0 then own.ignoredEmpty:Say(WORDS.noIgnores) else own.ignoredEmpty:Hide() end
	own.unignore:SetUsable(S.ignore ~= nil)
end

local function BuildIgnore(page)
	Back(page, "friends")
	Lead(page, WORDS.ignoreSay, L.pad + 28)
	own.ignored = List(page, L.head0 + 40, L.pad + L.foot + 8)
	own.ignoredEmpty = Empty(page)
	local add = UI.Button(page, WORDS.ignoreAdd, 130, IgnorePlayer)
	add:SetHeight(L.foot)
	add:SetPoint("BOTTOMLEFT", L.pad, L.pad)
	own.unignore = UI.Button(page, WORDS.ignoreRemove, 130, Unignore)
	own.unignore:SetHeight(L.foot)
	own.unignore:SetPoint("BOTTOMRIGHT", -L.pad, L.pad)
end

-- Building: the window

-- A side tab on the spine, as the spellbook's and the professions window's: a slot, a wash of your color and a
-- line of light while open, a count in its corner while something waits there.
local function Tab(def)
	local box = own.box
	local tab = CreateFrame("Button", nil, box)
	tab:SetSize(TAB.w, TAB.h)
	tab.wash = Fill(tab, "BACKGROUND", -7)
	tab.wash:SetPoint("TOPLEFT", 0, 1)
	tab.wash:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.hot = tab:CreateTexture(nil, "HIGHLIGHT")
	tab.hot:SetPoint("TOPLEFT", 0, 1)
	tab.hot:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.hot:SetColorTexture(1, 1, 1, 1)
	tab.line = Fill(tab, "ARTWORK")
	tab.line:SetPoint("TOPLEFT")
	tab.line:SetPoint("BOTTOMLEFT")
	tab.line:SetWidth(2)
	tab.rule = tab:CreateTexture(nil, "ARTWORK")
	tab.rule:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 5, 0)
	tab.rule:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", -5, 0)
	tab.rule:SetHeight(1)
	UI.Paint(tab.rule, C.border, 0.9)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(TAB.slot, TAB.slot)
	tab.icon:SetPoint("CENTER", tab, "CENTER", TAB.x, 0)
	tab.icon:SetTexture(def.icon)
	tab.icon:SetTexCoord(unpack(ICON))
	tab.slot = Slot.New(tab, { to = tab.icon, icon = tab.icon })
	local badge = CreateFrame("Frame", nil, tab)
	badge:SetSize(16, 14)
	badge:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -2, -2)
	badge:SetFrameLevel(tab:GetFrameLevel() + 8)
	UI.Skin(badge, C.fill, C.hot)
	badge.text = Text(badge, UI.NameFont(9), C.text)
	badge.text:SetPoint("CENTER", 0, 0)
	tab.badge = badge
	tab.def = def
	tab:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
		Go(self.def.key)
	end)
	tab:SetScript("OnEnter", function(self) UI.Tip(self, Global(self.def.title), nil, { side = "RIGHT" }) end)
	tab:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	return tab
end

local function PaintTab(tab, on)
	local r, g, b = Theme.Accent()
	tab.wash:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.3), CreateColor(r, g, b, 0))
	local h = C.hot
	tab.hot:SetGradient("HORIZONTAL", CreateColor(h[1], h[2], h[3], 0.16), CreateColor(h[1], h[2], h[3], 0))
	tab.line:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
	tab.wash:SetShown(on)
	tab.line:SetShown(on)
	tab.slot:Steel(on and C.hot or nil)
	local v = on and 1 or 0.74
	tab.icon:SetVertexColor(v, v, v)
	local n = (not on) and tab.def.count and tab.def.count() or 0
	tab.badge.text:SetText(n > 0 and n or "")
	tab.badge:SetWidth(math.max(14, math.ceil(tab.badge.text:GetStringWidth()) + 8))
	tab.badge:SetShown(n > 0)
end

-- The ×: a secure button pressing the game's own close button, so the window closes as the game closes it, in a
-- fight too. Set up out of one.
local function CloseKey(box, f)
	local close = CreateFrame("Button", "ShySkinSocialClose", box.head, "SecureActionButtonTemplate")
	close:RegisterForClicks("AnyUp")
	close:SetSize(HEAD.close, HEAD.close)
	close:SetPoint("RIGHT", box.head, "TOPRIGHT", -HEAD.pad + 2, -box.head.mid)
	close:SetFrameLevel(box.head:GetFrameLevel() + 10)
	close.glyph = close:CreateTexture(nil, "OVERLAY")
	close.glyph:SetTexture(UI.CLOSE_GLYPH)
	UI.GlyphFit(close.glyph, HEAD.glyph)
	close.glyph:SetPoint("CENTER")
	UI.KeyPress(close, { glyphs = { close.glyph }, sink = { close.glyph } })
	local function Arm()
		close:SetAttribute("useOnKeyDown", false)
		close:SetAttribute("type1", "click")
		close:SetAttribute("clickbutton", f.CloseButton)
	end
	if InCombatLockdown() then ns.AfterCombat("social:close", Arm) else Arm() end
	return close
end

local BUILD = { friends = BuildFriends, requests = BuildRequests, join = BuildJoin, raid = BuildRaid,
	raidinfo = BuildRaidInfo, ignore = BuildIgnore }

local function Build()
	local f = Frame()
	local box = UI.Window({
		id = "shyskin.social", title = Global("SOCIAL_UI_FRIENDS_TAB_NAME"),
		width = L.w, height = L.h,
		point = { "LEFT", "LEFT", 60, 30 },
		shown = function() return M ~= nil and M.on == true end,
		secure = true, inCombat = true,
		head = { size = "window", title = Global("SOCIAL_UI_FRIENDS_TAB_NAME"), close = false },
	})
	own.box = box
	own.close = CloseKey(box, f)
	-- Opens and closes with the game's window.
	box:SetParent(f)
	-- Its pages stand on its body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)
	own.pages = {}
	for key, build in pairs(BUILD) do
		local page = CreateFrame("Frame", nil, box)
		page:SetAllPoints(body)
		page:Hide()
		own.pages[key] = page
		build(page)
	end
	own.tabs = {}
	for i, def in ipairs(PAGES) do own.tabs[i] = Tab(def) end
end

-- The game's window, emptied: every piece of it in the attic, its art hidden, no mouse. Its tabs are made the first
-- time it opens, so this runs again then. A piece that is protected waits for the fight to end.
local function Emptied(kit)
	local f = Frame()
	local locked = InCombatLockdown()
	if locked and f:IsProtected() then
		ns.AfterCombat("social:empty", function() if M.on then Emptied(kit) end end)
		return
	end
	local attic = Shop.AtticOf(f)
	local kids = {}
	for _, kid in ipairs({ f:GetChildren() }) do
		if kid ~= own.box and kid ~= attic and kid ~= f.CloseButton and not kid:IsForbidden() and not (locked and kid:IsProtected()) then kids[#kids + 1] = kid end
	end
	Shop.PutAway(f, unpack(kids))
	-- The game's close stays on its window, unseen, for our × to press: it closes what it stands on.
	if f.CloseButton then
		f.CloseButton:SetAlpha(0)
		f.CloseButton:EnableMouse(false)
	end
	for _, region in ipairs({ f:GetRegions() }) do kit:Hide(region) end
	if mouse == nil then mouse = f:IsMouseEnabled() end
	f:EnableMouse(false)
end

local function Draw()
	-- A page the game doesn't offer here: the first it does.
	local key = S.page
	local tabKey = UNDER[key] or key
	local offered
	for _, def in ipairs(PAGES) do if def.key == tabKey and def.has() then offered = true end end
	if not offered then
		for _, def in ipairs(PAGES) do if not offered and def.has() then key, tabKey, offered = def.key, def.key, true end end
		S.page = key
	end
	for k, page in pairs(own.pages) do page:SetShown(k == key) end
	local title = {
		friends = Global("SOCIAL_UI_FRIENDS_TAB_NAME"), requests = Global("SOCIAL_UI_FRIEND_REQUESTS_TAB_NAME"),
		join = Global("SOCIAL_UI_QUICK_JOIN_TAB_NAME"), raid = Global("SOCIAL_UI_RAID_TAB_NAME"),
		raidinfo = WORDS.raidInfo, ignore = Global("IGNORE_LIST"),
	}
	own.box.head.title:SetText(title[key] or "")
	-- The tabs the game offers, one under another.
	local last
	for _, tab in ipairs(own.tabs) do
		local has = tab.def.has()
		tab:SetShown(has)
		if has then
			tab:ClearAllPoints()
			if last then
				tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
			else
				tab:SetPoint("TOPLEFT", own.box, "TOPRIGHT", 0, -TAB.top)
			end
			PaintTab(tab, tab.def.key == tabKey)
			last = tab
		end
	end
	if own.spine then own.spine:Fit(last) end
	if key == "friends" then DrawFriends()
	elseif key == "requests" then DrawRequests()
	elseif key == "join" then DrawJoin()
	elseif key == "raid" then DrawRaid()
	elseif key == "raidinfo" then DrawRaidInfo()
	elseif key == "ignore" then DrawIgnore() end
end

Refresh = function()
	local f = Frame()
	if not (M and M.on and own.box and f and f:IsShown()) then return end
	Shop.Try(M, Draw)
end

Stale = Shop.Later(function() Refresh() end)

Go = function(key)
	if S.page == key then return end
	S.page = key
	if key == "raidinfo" then RequestRaidInfo() end
	Shy.Hover.Close()
	Refresh()
end

-- The module

local EVENTS = { "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED", "BN_DISCONNECTED", "BN_INFO_CHANGED",
	"BN_CUSTOM_MESSAGE_CHANGED", "BN_CUSTOM_MESSAGE_LOADED", "PLAYER_FLAGS_CHANGED", "BATTLE_NET_FRIEND_TAG_ENABLED_STATUS_UPDATED",
	"BN_FRIEND_INVITE_ADDED", "BN_FRIEND_INVITE_REMOVED", "BN_FRIEND_INVITE_LIST_INITIALIZED", "SOCIAL_QUEUE_UPDATE",
	"GROUP_ROSTER_UPDATE", "RAID_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED", "UNIT_CONNECTION",
	"UPDATE_INSTANCE_INFO", "IGNORELIST_UPDATE", "BN_BLOCK_LIST_UPDATED", "PLAYER_REGEN_ENABLED" }

-- The game's requests for a page (a friend request's toast, /raidinfo, the ignore list from a menu): ours follows.
local TO_PAGE = {}

local function Hook()
	local f = Frame()
	TO_PAGE = {
		[SocialUITabType.Friends] = "friends", [SocialUITabType.QuickJoin] = "join",
		[SocialUITabType.FriendRequests] = "requests", [SocialUITabType.RaidList] = "raid",
	}
	local SIDE = { [SocialUISideWindowType.IgnoreListFrame] = "ignore", [SocialUISideWindowType.RaidInfoFrame] = "raidinfo" }
	local function Asked(tab, side)
		if not M.on then return end
		local key = (side and SIDE[side]) or TO_PAGE[tab]
		if key then
			S.page = key
			if key == "raidinfo" then RequestRaidInfo() end
			Stale()
		end
	end
	hooksecurefunc(SocialUIControl, "ToggleToTab", function(tab) Asked(tab) end)
	hooksecurefunc(SocialUIControl, "OpenToTab", function(tab) Asked(tab) end)
	hooksecurefunc(SocialUIControl, "ToggleToTabAndSideWindow", function(tab, side) Asked(tab, side) end)
	f:HookScript("OnShow", function()
		if not M.on then return end
		if M.kit then Emptied(M.kit) end   -- its tabs, made as it opens
		Refresh()
	end)
	f:HookScript("OnHide", function()
		if own.say then own.say:ClearFocus() end
		if own.search then own.search:ClearFocus() end
	end)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", function()
		if M.on and own.box and Frame():IsShown() then Stale() end
	end)
end

local function Paint(m, kit)
	m.kit = kit
	Shop.Try(m, function()
		if not own.box then Build() end
		Shy.HUD.Update(own.box)
		own.spine = ns.Spine(kit, own.box, "socialSpine")
		Emptied(kit)
		Refresh()
	end)
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	local f = Frame()
	Shy.Hover.Close()
	ns.AfterCombat("social:clear", function()
		if M.on then return end
		Shop.BringBack(f)
		if f.CloseButton then
			f.CloseButton:SetAlpha(1)
			f.CloseButton:EnableMouse(true)
		end
		if mouse ~= nil then f:EnableMouse(mouse) end
		if own.box then Shy.HUD.Update(own.box) end
	end)
end

M = ns.Module({
	id = "social",
	title = "Social",
	desc = "Your friends list gets a new window with where everyone is, friend requests and Quick Join.",
	group = "rebuilt",
	words = "friends ignore raid who",
	Ready = function() return SocialUIFrame ~= nil end,
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,     -- exposed for inspection
	state = S,
})
