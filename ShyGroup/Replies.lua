-- The Replies tab. Left: conversations, unread first. Right: the whisper
-- thread with the selected person, the seat they'll take, one-click replies
-- (some carrying an invite) and Invite.

local ADDON, ns = ...
local T, D, W = ns.T, ns.Data, ns.W
local UI = Shy.UI
local C = UI.colors
local Run, People = ns.Run, ns.People
local Rp = {}
ns.Replies = Rp

local PAD, LIST_W = 16, 250
local PANE_X = PAD + LIST_W + 16
local PANE_W = ns.Window.WIDTH - PANE_X - PAD
local PANE_H = ns.Window.HEIGHT - ns.Window.HEADER
local BUBBLE_MAX = 330
local THREAD_TOP = 96
local CHIP_H, CHIP_GAP = 22, 6
-- Bubble fills (yours in the accent) and the darker thread background.
local MINE, THEIRS = W.Alpha(C.fill, 0.92), C.bgHot
local WELL = { 0, 0, 0, 0.35 }
local INVITE, PASS = W.Alpha(C.good, 0.22), W.Alpha(C.bad, 0.18)

local selected

function Rp.Select(name)
	selected = name
end

local function Shorten(text, n)
	if #text <= n then return text end
	return text:sub(1, n - 1):gsub("[\128-\191]*$", "") .. "\226\128\166"
end

-- A warlock in the group, other than this person: a summon is on offer.
local function Warlock(p)
	for _, m in ipairs(Run.Members()) do
		if m.class == "WARLOCK" and m.name ~= p.name then return true end
	end
	return false
end

-- Where to meet: a dungeon's entrance, a zone, a raid; nothing for a run of your own.
local function Place()
	local d = Run.Dungeon()
	if not d then return nil end
	if d.kind == "zone" then return "in " .. d.name end
	if d.kind == "raid" then return "at " .. d.name end
	return "at the " .. d.name .. " entrance"
end

-- The replies to offer this person, from what the run knows: a seat for the
-- role they named, else a role question when a seat fits them; where to meet,
-- with a summon only when a warlock is along; a kind no for someone too low;
-- then the lines of your own.
local function RepliesFor(p)
	local out = {}
	local run = Run.Get()
	local inGroup = p.status == "joined" or p.status == "invited"
	if run then
		local can = Run.RolesFor(p)
		local said
		for _, r in ipairs(can) do
			if r == p.said then said = r end
		end
		if said and not inGroup then
			out[#out + 1] = { text = "Great, come " .. Run.BARE[said] .. " for us, inviting you now.", act = "invite", role = said, ask = true }
		elseif #can == 1 and not inGroup then
			out[#out + 1] = { text = "Could you " .. Run.BARE[can[1]] .. "?", act = "send", ask = true }
		elseif #can > 1 and not inGroup then
			local words = {}
			for i, r in ipairs(can) do words[i] = Run.BARE[r] end
			out[#out + 1] = { text = "Would you rather " .. Run.Or(words) .. "?", act = "send", ask = true }
		end
		local place = Place()
		if place then
			if Warlock(p) then
				out[#out + 1] = { text = "We've got a warlock, we can summon you " .. place .. ".", act = "send" }
			else
				out[#out + 1] = { text = "Meet us " .. place .. ".", act = "send" }
			end
		end
		if p.level and p.level < run.min and not inGroup then
			out[#out + 1] = { text = "You're a bit low for " .. run.name .. ", sorry. Another time!", act = "pass" }
		end
	end
	for _, reply in ipairs(People.Replies()) do
		if reply.text ~= "" and not (inGroup and reply.act == "invite") then out[#out + 1] = reply end
	end
	return out
end

function Rp.Create(page)
	-- People
	local list = W.List(page, LIST_W, PANE_H - 48, 50, function(content)
		local row = W.Row(content)
		row.dot = row:CreateTexture(nil, "OVERLAY")
		row.dot:SetSize(6, 6)
		row.dot:SetPoint("TOPRIGHT", -6, -6)
		UI.Paint(row.dot, C.alert)
		row.name = W.Name(row, 13)
		row.name:SetPoint("TOPLEFT", 12, -6)
		row.ago = UI.Text(row, "", 10, false, C.dim)
		row.ago:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
		row.snippet = W.ChatText(row, C.dim, true)
		row.snippet:SetPoint("BOTTOMLEFT", 12, 7)
		row.snippet:SetWordWrap(false)
		row.chip = W.Chip(row)
		row.chip:SetPoint("BOTTOMRIGHT", -6, 5)
		row:SetScript("OnClick", function(self, button)
			if button == "RightButton" then
				W.PersonMenu(self, self.item.name, self.item)
			else
				selected = self.item.name
				ns.Changed()
			end
		end)
		row:HookScript("OnEnter", function(self)
			local p = self.item
			local who = W.LevelClass(p.level, p.class)
			UI.Tip(self, p.name, nil, { side = "LEFT", color = { W.ClassColor(p.class) }, note = who ~= "" and who or nil,
				hints = { { "left", "Open" }, { "right", "Whisper, invite, ignore, clear" } } })
		end)
		row:HookScript("OnLeave", function(self) UI.TipHide(self) end)
		return row
	end, function(row, p)
		local r, g, b = W.ClassColor(p.class)
		row.edge:SetColorTexture(r, g, b, 1)
		row.name:SetText(p.name)
		row.name:SetTextColor(r, g, b)
		row.name:SetWidth(math.min(row.name:GetStringWidth() + 1, LIST_W - 70))
		row.ago:SetText(ns.Ago(p.t))
		row.dot:SetShown(p.unread > 0)
		local text, color = People.StatusText(p)
		row.chip:Set(text, color or C.dim)
		local last = p.thread[#p.thread]
		row.snippet:SetWidth(LIST_W - 40 - (text and row.chip:GetWidth() or 0))
		row.snippet:SetText((last.out and "You: " or "") .. last.text)
		row:SetSelected(p.name == selected)
	end)
	list:SetPoint("TOPLEFT", PAD, -12)

	local none = UI.Text(page, "No conversations yet.\nPeople you ask, and anyone who whispers you\nduring a run, show up here.", 13, false, C.dim)
	none:SetJustifyH("CENTER")
	none:SetSpacing(4)
	none:SetPoint("CENTER", 0, 20)

	-- The conversation
	local pane = CreateFrame("Frame", nil, page)
	pane:SetPoint("TOPLEFT", PANE_X, 0)
	pane:SetSize(PANE_W, PANE_H)

	-- Line one: the name and their level and class, clear of the buttons at the right.
	-- Line two: their status and what they posted.
	local name = W.Name(pane, 17)
	name:SetPoint("TOPLEFT", 0, -12)
	local info = UI.Text(pane, "", 12, false, C.dim)
	info:SetPoint("LEFT", name, "RIGHT", 10, 0)
	local chip = W.Chip(pane)
	chip:SetPoint("TOPLEFT", 0, -38)

	local clear = W.Button(pane, "Clear", 56, function() end)
	clear:SetPoint("TOPRIGHT", 0, -12)
	UI.Twice(clear, function()
		People.Forget(selected)
		selected = nil
	end)
	W.Tip(clear, "Clear", "Takes this conversation off the list. Someone in your group stays, with an empty thread. Asks twice.")
	local ignore = W.Button(pane, "Ignore", 66, function(self)
		if self.ignoring then People.Unignore(selected) else People.Ignore(selected) end
	end)
	ignore:SetPoint("RIGHT", clear, "LEFT", -8, 0)
	W.Tip(ignore, function(self) return self.ignoring and "Stop ignoring" or "Ignore" end, function(self)
		if self.ignoring then return "Takes them off your ignore list. They can be asked again." end
		return "Puts them on your ignore list: no more whispers, and they leave your lists here."
	end)
	local pass = W.Button(pane, "Not interested", 110, function()
		People.Pass(selected)
		selected = nil
	end)
	pass:SetPoint("RIGHT", ignore, "LEFT", -8, 0)
	W.Tip(pass, "Not interested", "Removes them from your lists. The conversation stays here.")
	local invite = W.Button(pane, "Invite", 72, function() People.Invite(selected) end, true)
	invite:SetPoint("RIGHT", pass, "LEFT", -8, 0)
	W.Tip(invite, "Invite", "Sends a group invite.")

	local clearAll = W.Button(page, "Clear all", 80, function() end)
	clearAll:SetHeight(20)
	clearAll:SetPoint("BOTTOMLEFT", PAD, 10)
	UI.Twice(clearAll, function()
		People.ForgetAll()
		selected = nil
	end)
	W.Tip(clearAll, "Clear all", "Takes every conversation off the list. People in your group stay. Asks twice.")

	-- The seat they'll take: a button per role their class can fill.
	local seatLabel = UI.Text(pane, "Their role", 12, false, C.dim)
	seatLabel:SetPoint("TOPLEFT", 0, -64)
	local seats = CreateFrame("Frame", nil, pane)
	seats:SetPoint("LEFT", seatLabel, "RIGHT", 10, 0)
	seats:SetSize(10, 22)
	seats.buttons = {}
	local x = 0
	for i, role in ipairs(D.ROLES) do
		local b = CreateFrame("Button", nil, seats)
		b.role = role
		b:SetSize(76, 22)
		b:SetPoint("LEFT", x, 0)
		x = x + 80
		b.icon = W.RoleIcon(b, 14)
		b.icon:SetPoint("LEFT", 6, 0)
		b.icon:SetRole(role)
		b.text = UI.Text(b, D.ROLE_NAME[role], 12, true)
		b.text:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
		-- Gold dot: the role they named themselves. Their seat is the primary (lit along its top).
		b.said = b:CreateTexture(nil, "OVERLAY")
		b.said:SetSize(6, 6)
		b.said:SetPoint("TOPRIGHT", -4, -4)
		UI.Paint(b.said, C.alert)
		b:SetScript("OnClick", function(self) People.SetRole(selected, self.role) end)
		W.Tip(b, D.ROLE_NAME[role], function(self)
			local p = People.Get(selected)
			local said = p and p.said == self.role and "They said they'd " .. Run.BARE[self.role] .. ". " or ""
			return said .. "The role they'll fill when they join. Your post and whispers count it as filled once they're in."
		end)
		UI.KeyPress(b, { sink = { b.icon } })
		seats.buttons[i] = b
	end
	seats:SetWidth(x - 4)

	-- What they posted, after the status chip; the whole of it on hover.
	local posted = W.ChatText(pane, C.dim, true)
	posted:SetPoint("LEFT", chip, "RIGHT", 8, 0)
	posted:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
	posted:SetWordWrap(false)
	local postedHit = CreateFrame("Frame", nil, pane)
	postedHit:SetPoint("TOPLEFT", 0, -34)
	postedHit:SetSize(PANE_W, 20)
	postedHit:EnableMouse(true)
	W.Tip(postedHit, function()
		local p = People.Get(selected)
		return p and p.post and "Their post" or nil
	end, function()
		local p = People.Get(selected)
		return p and p.post and ("\"" .. p.post .. "\"") or nil
	end)

	local thread = UI.ScrollArea(pane, PANE_W, 100)
	thread:SetPoint("TOPLEFT", 0, -THREAD_TOP)
	UI.Skin(thread, WELL)
	local bubbles = {}
	local drawn   -- signature of the thread on screen; layout is redone only when it changes

	local function Bubble(i)
		local b = bubbles[i]
		if not b then
			b = CreateFrame("Frame", nil, thread.content)
			b.bg = b:CreateTexture(nil, "BACKGROUND")
			b.bg:SetAllPoints()
			b.text = W.ChatText(b)
			b.text:SetPoint("TOPLEFT", 8, -5)
			b.time = UI.Text(thread.content, "", 10, false, C.dim)
			bubbles[i] = b
		end
		return b
	end

	local function DrawThread(p)
		local last = p.thread[#p.thread]
		local signature = p.name .. #p.thread .. (last and last.t or 0) .. thread:GetHeight()
		if signature == drawn then return end
		drawn = signature
		local y = -8
		for i, line in ipairs(p.thread) do
			local b = Bubble(i)
			b.text:SetWidth(BUBBLE_MAX)
			b.text:SetText(line.text)
			local w = math.min(BUBBLE_MAX, b.text:GetStringWidth())
			local h = b.text:GetStringHeight()
			b.text:SetWidth(w + 1)
			b:SetSize(w + 16, h + 10)
			UI.Paint(b.bg, line.out and MINE or THEIRS)
			b:ClearAllPoints()
			b.time:ClearAllPoints()
			b.time:SetText(date("%H:%M", line.t))
			if line.out then
				b:SetPoint("TOPRIGHT", thread.content, "TOPRIGHT", -8, y)
				b.time:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -6, 2)
			else
				b:SetPoint("TOPLEFT", thread.content, "TOPLEFT", 8, y)
				b.time:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 6, 2)
			end
			b:Show()
			b.time:Show()
			y = y - h - 10 - 6
		end
		for i = #p.thread + 1, #bubbles do
			bubbles[i]:Hide()
			bubbles[i].time:Hide()
		end
		thread.content:SetHeight(-y + 4)
		-- Scroll to the newest line on the next frame, once the new height applies.
		C_Timer.After(0, function()
			thread:SetVerticalScroll(thread:GetVerticalScrollRange())
			thread:Update()
		end)
	end

	-- One-click replies, as many rows as they need above the input.
	local chips = {}
	local function Chip(i)
		local b = chips[i]
		if not b then
			b = W.Button(pane, "", 10, function(self) People.Reply(selected, self.reply) end, false, "name")
			b:SetHeight(CHIP_H)
			W.Tip(b, function(self)
				local act = self.reply.act
				return act == "invite" and "Send and invite" or act == "pass" and "Send and move on" or "Send this"
			end, function(self)
				local text = "Whispers: " .. self.reply.text
				if self.reply.act == "invite" then return text .. "\nThen sends a group invite." end
				if self.reply.act == "pass" then return text .. "\nThen takes them off your lists." end
				return text
			end)
			chips[i] = b
		end
		return b
	end

	local function LayChips(p)
		local replies = RepliesFor(p)
		local x, rows = 0, 1
		local canInvite = Run.CanInvite() and not Run.IsFull()
		for i, reply in ipairs(replies) do
			local b = Chip(i)
			b.reply = reply
			b.text:SetText(Shorten(reply.text, 90))
			local w = math.min(PANE_W, b.text:GetStringWidth() + 20)
			if x > 0 and x + w > PANE_W then
				x, rows = 0, rows + 1
			end
			b:SetWidth(w)
			b:SetLabel(Shorten(reply.text, 90))
			b:ClearAllPoints()
			b:SetPoint("BOTTOMLEFT", x, 44 + (rows - 1) * (CHIP_H + CHIP_GAP))
			x = x + w + CHIP_GAP
			UI.SetFill(b, reply.act == "invite" and INVITE or reply.act == "pass" and PASS or reply.ask and C.fill or C.bgHot)
			b:SetOn(reply.act ~= "invite" or canInvite, Run.IsFull() and "Your group is full." or "Only the group leader or an assistant can invite.")
			b:Show()
		end
		for i = #replies + 1, #chips do chips[i]:Hide() end
		-- The newest chips stand highest; the thread ends above them.
		local height = PANE_H - THREAD_TOP - 44 - rows * (CHIP_H + CHIP_GAP) - 6
		thread:SetHeight(math.max(80, height))
	end

	local send
	local input = W.ChatInput(pane, PANE_W - 78, function(text) People.Send(selected, text) end, "Write a reply...")
	input:SetPoint("BOTTOMLEFT", 0, 12)
	send = W.Button(pane, "Send", 70, function() input:Send() end)
	send:SetHeight(24)
	send:SetPoint("BOTTOMRIGHT", 0, 12)

	page:SetScript("OnHide", function() People.viewing = nil end)

	function page:Refresh()
		local threads = People.Threads()
		local p = selected and People.Get(selected)
		if not p or #p.thread == 0 then
			p = threads[1]
			selected = p and p.name
		end
		none:SetShown(p == nil)
		pane:SetShown(p ~= nil)
		list:SetShown(p ~= nil)
		clearAll:SetShown(p ~= nil)
		People.viewing = selected
		if not p then return end

		People.Read(p.name)
		list:SetData(threads)

		name:SetText(p.name)
		name:SetTextColor(W.ClassColor(p.class))
		name:SetWidth(math.min(name:GetStringWidth() + 1, PANE_W - 400))
		info:SetWidth(math.max(10, PANE_W - 400 - name:GetWidth() - 10 + 30))
		info:SetJustifyH("LEFT")
		info:SetWordWrap(false)
		local ignoring = People.IsIgnored(p.name)
		ignore.ignoring = ignoring
		ignore.text:SetText(ignoring and "Stop ignoring" or "Ignore")
		ignore:SetWidth(ignoring and 100 or 66)
		UI.SetFill(ignore, ignoring and W.Alpha(C.bad, 0.25) or C.bgHot)
		info:SetText(W.LevelClass(p.level, p.class))
		local text, color = People.StatusText(p)
		chip:Set(text, color or C.dim)
		posted:SetText(p.post and ("Posted: \"" .. p.post .. "\"") or "")

		local canInvite = Run.CanInvite() and p.status ~= "joined" and p.status ~= "invited" and not Run.IsFull() and not ignoring
		invite:SetOn(canInvite, ignoring and "They're on your ignore list." or p.status == "joined" and "They're in your group."
			or p.status == "invited" and "Invited; waiting on them." or Run.IsFull() and "Your group is full."
			or "Only the group leader or an assistant can invite.")
		invite:SetPrimary(p.status == "yes" or p.status == "wants" or p.said ~= nil)
		pass:SetOn(p.status ~= "passed" and p.status ~= "joined")

		local run = Run.Get()
		local seat = run and run.roles[p.name] or p.role
		for _, b in ipairs(seats.buttons) do
			local can = D.CanFill(p.class, b.role)
			b:SetShown(can)
			local on = seat == b.role
			b:SetPrimary(on)
			UI.Ink(b.text, on and C.onFill or C.dim)
			b.said:SetShown(p.said == b.role and not on)
		end

		LayChips(p)
		DrawThread(p)
	end
end
