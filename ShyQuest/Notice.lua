-- Quest progress notices: completion sounds, party chat announcements, a chat line for an item
-- that starts a quest, and the "Quests your guide skips" window.
-- Announcements go to a party only (not raids), never twice, and not during chat lockdown. Each is
-- marked as an addon's line (Shy.Brand.Chat).

local ADDON, ns = ...
local T = ns.T
local D, L, W, G, R = ns.Data, ns.Log, ns.World, ns.Guide, ns.Route
local UI = Shy.UI

local finished = {}          -- objectives finished in this log update: { entry, goal }
local ready = false          -- a quest became ready in it
local waiting = false
local said = {}              -- lines sent already
local handedIn = {}          -- quests just turned in, so their removal isn't announced as abandoned

-- Announcing

local function InParty()
	return IsInGroup() and not IsInRaid()
end

local OTHER = "Questie"      -- the quest addon ShyQuest works beside: its folder

-- A line the other quest addon says itself with its own setting for that kind on (Yield.lua).
local function Theirs(kind)
	if ns.Yield then return ns.Yield.To("announce", kind) end
	return C_AddOns.IsAddOnLoaded(OTHER)
end

-- Sends a party line if that kind is enabled. True when sent now or earlier.
local function Say(kind, text)
	if not T.db.party.tell[kind] or not InParty() or Theirs(kind) then return false end
	if said[text] then return true end
	if C_ChatInfo.InChatMessagingLockdown() then return false end
	said[text] = true
	C_ChatInfo.SendChatMessage(Shy.Brand.Chat(text), "PARTY")
	return true
end

local function QuestName(id, title)
	return GetQuestLink(id) or ("[" .. (title or D.Name("quests", id) or "a quest") .. "]")
end

-- Progress

local function Speak()
	waiting = false
	local sound = T.db.sound
	for _, item in ipairs(finished) do
		if item.goal.text and item.goal.text ~= "" then
			Say("objectives", ("%s for %s"):format(item.goal.text, QuestName(item.entry.id, item.entry.title)))
		end
	end
	-- One sound per log update; a ready quest outranks an objective.
	if ready and sound ~= "off" then
		PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE)
	elseif #finished > 0 and sound == "all" then
		PlaySound(SOUNDKIT.MAP_PING)
	end
	wipe(finished)
	ready = false
end

L.OnProgress(function(kind, entry, goal)
	if kind == "ready" then
		ready = true
	elseif kind == "objective" then
		finished[#finished + 1] = { entry = entry, goal = goal }
	else
		return
	end
	-- One log update reports all its changes in the same frame: announce on the next.
	if not waiting then
		waiting = true
		C_Timer.After(0, Speak)
	end
end)

-- An item that starts a quest

-- A loot global string ("You receive loot: %s.") as a Lua pattern.
local function Pattern(text)
	local pattern = text:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%s", ".+"):gsub("%%d", "%%d+")
	return "^" .. pattern
end
local LOOTED = { Pattern(LOOT_ITEM_SELF_MULTIPLE), Pattern(LOOT_ITEM_SELF), Pattern(LOOT_ITEM_PUSHED_SELF_MULTIPLE), Pattern(LOOT_ITEM_PUSHED_SELF) }

-- A loot chat line; only the player's own loot counts.
local function OnLoot(text)
	if issecretvalue(text) or type(text) ~= "string" then return end
	local mine = false
	for _, pattern in ipairs(LOOTED) do
		if text:find(pattern) then mine = true end
	end
	local id = mine and tonumber(text:match("|Hitem:(%d+)"))
	local item = id and D.Item(id)
	-- The other quest addon tells of such an item itself, to the party or to the player.
	if not item or not item.begins or Theirs("starts") then return end
	local link = text:match("|c%x+|Hitem:.-|h.-|h|r") or ("[" .. item.name .. "]")
	for _, quest in ipairs(item.begins) do
		local record = D.Quest(quest)
		if record and L.CanStart(record, true) then
			local name = "[" .. record.name .. "]"
			if not Say("starts", ("Picked up %s, which starts %s"):format(link, name)) then
				T:Print(("you picked up %s, which starts |cffffffff%s|r."):format(link, record.name))
			end
			return
		end
	end
end

-- Off the guide
-- One window for quests the followed guide doesn't use: per zone, "Guide only" or "Quest here too"
-- (R.Extras, saved per character), and for each such quest in the log (R.Strays), keep or drop.
-- It opens by itself only after such a quest is accepted or once per new zone the guide doesn't
-- visit, never in combat or on a flight. ns.OffGuide opens it on request.

local OFF_WIDTH, OFF_PAD = 360, 14
local OFF_ROWS, OFF_ROW = 6, 28
local INNER = OFF_WIDTH - OFF_PAD * 2
local SURE = 4               -- seconds a "Sure?" stays armed
local SOON = 1.5             -- seconds after a quest is accepted before asking: more may follow
local LATER = 2              -- seconds before retrying when in combat or on a flight
local NEW_ZONE = 3           -- ask about a zone with at least this many worthwhile quests the guide skips
local FAR = 40               -- upcoming guide steps checked for "the guide goes there"
local off                    -- the window, created on first use
local why                    -- what it opened for: { quests = { id, ... } } | { zone = map } | nil (opened by the player)
local want                   -- pending question, the same shape
local asked = {}             -- zones asked about since login
local armed, armedUntil      -- the button showing "Sure?", and until when
local Fill

local function Guided()
	return ns.Following() and G.current ~= nil and not G.finished
end

-- How many available quests on a map the guide doesn't use.
local function Others(map, worth)
	local count = 0
	for _, quest in ipairs(L.StartsOn(map)) do
		if not G.Uses(quest.id) and (not worth or R.WorthOffer(quest)) then count = count + 1 end
	end
	return count
end

local function Begun(entry)
	for _, goal in ipairs(entry.goals or {}) do
		if goal.finished or (goal.have or 0) > 0 then return true end
	end
	return false
end

local function Drop(id)
	L.Abandon(id)
end

-- True on a second click within SURE seconds; the first click shows "Sure?".
local function Sure(button)
	if armed == button and GetTime() < armedUntil then
		armed = nil
		return true
	end
	armed, armedUntil = button, GetTime() + SURE
	button.text:SetText("Sure?")
	C_Timer.After(SURE, function()
		if armed == button then
			armed = nil
			if off:IsShown() then Fill() end
		end
	end)
	return false
end

local function Settled()
	if #R.Strays() == 0 then off:Hide() else Fill() end
end

local function Choose(on)
	if not W.map then return end
	ns.char.zones[W.map] = on
	ns.Apply()
	Settled()
end

local function Create()
	local C = UI.colors
	off = CreateFrame("Frame", "ShyQuestOffGuide", UIParent)
	off:SetWidth(OFF_WIDTH)
	off:SetPoint("TOP", UIParent, "TOP", 0, -150)
	off:SetFrameStrata("HIGH")
	off:SetToplevel(true)
	off:EnableMouse(true)
	off:Hide()
	UI.Head(off, { size = "window", title = "Quests your guide skips", close = function() off:Hide() end })
	-- (its words stand on a frame above the body, whose sheet would cover them)
	local face = CreateFrame("Frame", nil, off)
	face:SetAllPoints(off)
	table.insert(UISpecialFrames, "ShyQuestOffGuide")

	local function Lines(size, color)
		local text = UI.Text(face, "", size, false, color)
		text:SetWidth(INNER)
		text:SetJustifyH("LEFT")
		text:SetWordWrap(true)
		return text
	end
	off.say = Lines(12, C.text)

	off.zone = Lines(10, C.dim)
	local half = (INNER - 8) / 2
	local function Way(label, on)
		local button = UI.Button(off, label, half, function() Choose(on) end)
		button:SetScript("OnLeave", function(self) UI.SetBorder(self, self.chosen and C.hot or C.border) end)
		return button
	end
	off.only, off.too = Way("Guide only", false), Way("Quest here too", true)
	off.means = Lines(11, C.dim)

	off.log = Lines(10, C.dim)
	off.rows = {}
	for i = 1, OFF_ROWS do
		local row = CreateFrame("Frame", nil, off)
		row:SetSize(INNER, OFF_ROW)
		row.drop = UI.Button(row, "Drop", 56, function(self)
			if row.begun and not Sure(self) then return end
			Drop(row.id)
		end)
		row.drop:SetPoint("RIGHT")
		row.keep = UI.Button(row, "Keep", 56, function()
			ns.char.kept[row.id] = true
			ns.Refresh()
			Settled()
		end)
		row.keep:SetPoint("RIGHT", row.drop, "LEFT", -6, 0)
		row.note = UI.Text(row, "", 11, false, C.dim)
		row.note:SetPoint("RIGHT", row.keep, "LEFT", -8, 0)
		row.title = UI.Text(row, "", 12, false, C.text)
		row.title:SetPoint("LEFT")
		row.title:SetPoint("RIGHT", row.note, "LEFT", -8, 0)
		row.title:SetJustifyH("LEFT")
		row.title:SetWordWrap(false)
		off.rows[i] = row
	end
	off.more = Lines(11, C.dim)
	-- The sweep: every quest listed, in one confirmed click; one the game won't let go is kept and said.
	off.all = UI.Button(off, "", 130, function(self)
		if not Sure(self) then return end
		local dropped, kept = 0, {}
		for _, entry in ipairs(R.Strays()) do
			if C_QuestLog.CanAbandonQuest(entry.id) then
				Drop(entry.id)
				dropped = dropped + 1
			else
				kept[#kept + 1] = entry.title
			end
		end
		if dropped > 0 then T:Print(("dropped %d quest%s your guide skips."):format(dropped, dropped == 1 and "" or "s")) end
		if #kept > 0 then T:Print(("couldn't drop %s: the game won't let you abandon it."):format(table.concat(kept, ", "))) end
	end)
end

function Fill()
	local C = UI.colors
	local guide = G.current and G.current.name or "your guide"
	local map = W.map
	local zone = map and W.MapName(map)
	local strays = Guided() and R.Strays() or {}
	local y = 40
	local function Put(thing, gap, height)
		thing:ClearAllPoints()
		thing:SetPoint("TOPLEFT", UI.Body(off), "TOPLEFT", OFF_PAD, -y)   -- (on its body: UI.Body)
		thing:Show()
		y = y + (height or math.max(12, thing:GetStringHeight())) + (gap or 0)
	end

	local taken = {}
	for _, id in ipairs(why and why.quests or {}) do
		if L.Has(id) then taken[#taken + 1] = L.entries[id].title end
	end
	if #taken == 1 then
		off.say:SetText(("|cffffffff%s|r isn't in your guide (%s)."):format(taken[1], guide))
	elseif #taken > 1 then
		off.say:SetText(("%d quests you just took aren't in your guide (%s)."):format(#taken, guide))
	elseif why and why.zone and zone then
		off.say:SetText(("|cffffffff%s|r isn't on your guide's route (%s). Quest here anyway?"):format(zone, guide))
	else
		off.say:SetText(("Quests %s skips."):format(guide))
	end
	Put(off.say, 12)

	local zoned = Guided() and zone ~= nil
	off.zone:SetShown(zoned)
	off.only:SetShown(zoned)
	off.too:SetShown(zoned)
	off.means:SetShown(zoned)
	if zoned then
		off.zone:SetText("IN " .. zone:upper())
		Put(off.zone, 5)
		local too = R.Extras(map)
		off.only.chosen, off.too.chosen = not too, too
		for _, button in ipairs({ off.only, off.too }) do
			UI.SetBorder(button, button.chosen and C.hot or C.border)
			UI.Ink(button.text, button.chosen and C.head or C.dim)
		end
		off.only:ClearAllPoints()
		off.only:SetPoint("TOPLEFT", UI.Body(off), "TOPLEFT", OFF_PAD, -y)
		off.too:ClearAllPoints()
		off.too:SetPoint("TOPRIGHT", UI.Body(off), "TOPRIGHT", -OFF_PAD, -y)
		y = y + 24 + 6
		local others = Others(map)
		if too then
			off.means:SetText("Other quests here show on your card after your guide's step, and get accepted as usual.")
		elseif others > 0 then
			off.means:SetText(("The %d other quest%s here stay%s off your card and your map, and %s accepted for you.")
				:format(others, others == 1 and "" or "s", others == 1 and "s" or "", others == 1 and "isn't" or "aren't"))
		else
			off.means:SetText("Quests your guide doesn't take stay off your card and aren't accepted for you.")
		end
		Put(off.means, 14)
	end

	if #strays > 0 then
		off.log:SetText(("IN YOUR LOG  \194\183  %d NOT IN YOUR GUIDE"):format(#strays))
	else
		off.log:SetText("EVERYTHING IN YOUR LOG IS IN YOUR GUIDE")
	end
	Put(off.log, 4)
	for i, row in ipairs(off.rows) do
		local entry = strays[i]
		row:SetShown(entry ~= nil)
		if entry then
			row.id, row.begun = entry.id, Begun(entry)
			row.title:SetText(entry.title)
			row.note:SetText(("%d  \194\183  %d%%"):format(entry.level or 0, math.floor(L.Share(entry.level or 0) * 100 + 0.5)))
			if armed ~= row.drop then row.drop.text:SetText("Drop") end
			Put(row, 0, OFF_ROW)
		end
	end
	off.more:SetShown(#strays > OFF_ROWS)
	if #strays > OFF_ROWS then
		off.more:SetText(("and %d more"):format(#strays - OFF_ROWS))
		Put(off.more, 4)
	end
	off.all:SetShown(#strays > 1)
	if #strays > 1 then
		if armed ~= off.all then off.all.text:SetText(("Drop all %d"):format(#strays)) end
		y = y + 6
		Put(off.all, 0, 24)
	end
	UI.BodyFit(off, OFF_WIDTH, y + OFF_PAD)   -- (and the look's clearance round it: UI.Body)
end

-- Opens the window, or closes it with show == false. reason: see `why`.
function ns.OffGuide(show, reason)
	if not off then Create() end
	if show == false then return off:Hide() end
	why, armed = reason, nil
	Fill()
	off:Show()
end

-- Whether you're only passing through this zone on the way to your guide's step: the route boards a ride here,
-- or the step is a short walk off (a flight to the next zone over can be quicker than the road).
local PASSING = 1000         -- yards: the guide's step this near is where you're headed
local function Passing(map)
	for _, stop in ipairs(R.stops) do
		if stop.kind == "fly" and stop.map == map then return true end
		if stop.kind == "guide" and not stop.side then
			return stop.yards ~= nil and stop.yards <= PASSING
		end
	end
	return false
end

-- Asks once out of combat and off a flight.
local waiting = false
local function Ask()
	waiting = false
	if not want then return end
	if InCombatLockdown() or UnitOnTaxi("player") then
		waiting = true
		return C_Timer.After(LATER, Ask)
	end
	local reason = want
	want = nil
	if not Guided() then return end
	if reason.quests then
		-- Only quests that are still strays: the zone may have been answered or the quest dropped since.
		local stray, kept = {}, {}
		for _, entry in ipairs(R.Strays()) do stray[entry.id] = true end
		for _, id in ipairs(reason.quests) do
			if stray[id] then kept[#kept + 1] = id end
		end
		if #kept == 0 then return end
		reason.quests = kept
	elseif reason.zone ~= W.map or ns.char.zones[reason.zone] ~= nil then
		return
	elseif Passing(reason.zone) then
		-- (Landed on the way: asked again only when you next come into it.)
		asked[reason.zone] = nil
		return
	end
	ns.OffGuide(true, reason)
end

local function AskSoon(delay)
	if waiting then return end
	waiting = true
	C_Timer.After(delay, Ask)
end

-- A quest was accepted. Ask about one the guide doesn't use, unless the route itself offered it.
local function OnTaken(id)
	if not Guided() or G.Uses(id) or ns.char.kept[id] then return end
	if not R.offGuide or R.Takes(id) then
		ns.char.kept[id] = true
		return
	end
	want = (want and want.quests) and want or { quests = {} }
	want.quests[#want.quests + 1] = id
	AskSoon(SOON)
end

-- A new zone: ask once if the guide doesn't go there and it has enough worthwhile quests.
local function OnZone()
	local map = W.map
	if not map or asked[map] or want or not Guided() or not R.offGuide or ns.char.zones[map] ~= nil then return end
	for _, view in ipairs(G.Upcoming(FAR)) do
		if view.map == map then return end
	end
	if Others(map, true) < NEW_ZONE or Passing(map) then return end
	asked[map] = true
	want = { zone = map }
	AskSoon(0)
end

-- Whether the card takes this quest: the route has it to pick up, you kept it, the guide picks it up within its
-- next AHEAD steps, or it's a class quest the card's own row has (ClassQuests.lua: any town's version of it).
local AHEAD = 12
function T:GuideTakes(quest)
	if quest == nil then return false end
	if R.Takes(quest) or ns.char.kept[quest] then return true end
	if ns.ClassQuests and ns.ClassQuests.Covers(quest) then return true end
	for _, view in ipairs(G.Upcoming(AHEAD)) do
		for _, action in ipairs(view.actions) do
			if action.kind == "pickup" and action.id == quest then return true end
		end
	end
	return false
end

-- Whether auto-accept (GuideTalk.lua) should leave this quest to the player because guide-only mode is in
-- force and the card doesn't take it.
function T:GuideSkips(quest)
	return R.offGuide == true and quest ~= nil and not T:GuideTakes(quest)
end

-- Whether the immersive dialog's Space passes an offered quest by (Shy.Talk.Pass, GuideTalk.lua). Following the
-- guide, with no zone chosen to quest in too: one the card doesn't take. Otherwise, as in zone mode: one your
-- settings leave out of the card's quests (one you hid, a repeatable or outgrown one, a gray one). Your class's
-- own quests are always yours.
function T:TalkPasses(quest)
	if quest == nil then return false end
	if Guided() and not R.Extras() then return not T:GuideTakes(quest) end
	local info = D.Quest(quest)
	if ns.char.hidden[quest] then return true end
	if info and info.classes then return false end
	if not T.db.repeatable and C_QuestLog.IsRepeatableQuest(quest) and not (info and L.Hands(info)) then return true end
	if info and not T.db.lowLevel and L.Outgrown(info) then return true end
	local gray
	if info then gray = L.Trivial(info.level or 0) else gray = C_QuestLog.IsQuestTrivial(quest) end
	return gray == true and T.db.track == "zone" and not T.db.grayZone
end

ns.OnRoute(function()
	if off and off:IsShown() then Fill() end
end)

Shy:On("SHY_LOGIN", function()
	local events = CreateFrame("Frame")
	events:RegisterEvent("CHAT_MSG_LOOT")
	events:RegisterEvent("QUEST_ACCEPTED")
	events:RegisterEvent("QUEST_TURNED_IN")
	events:RegisterEvent("QUEST_REMOVED")
	events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	events:SetScript("OnEvent", function(_, event, id)
		if event == "CHAT_MSG_LOOT" then
			OnLoot(id)
		elseif event == "ZONE_CHANGED_NEW_AREA" then
			-- After the route has been rebuilt for the new zone.
			C_Timer.After(LATER, OnZone)
		elseif event == "QUEST_ACCEPTED" then
			OnTaken(id)
			Say("accepted", "Accepted " .. QuestName(id))
		elseif event == "QUEST_TURNED_IN" then
			handedIn[id] = GetTime()
			Say("handedIn", "Turned in " .. QuestName(id))
		else
			ns.char.kept[id] = nil
			-- A quest can be accepted again, so its lines may repeat.
			wipe(said)
			-- QUEST_REMOVED also fires on turn-in, in no fixed order with QUEST_TURNED_IN: wait.
			C_Timer.After(1, function()
				local when = handedIn[id]
				handedIn[id] = nil
				if not when or GetTime() - when > 5 then Say("abandoned", "Abandoned " .. QuestName(id)) end
			end)
		end
	end)
end)
