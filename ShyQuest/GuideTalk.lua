-- NPC automation: the live step's gossip (.skipgossipid / .gossipoption / .skipgossip), hearthstone (.home,
-- or the card's inn row) and flights (.fly), and auto accept / turn-in. Shift pauses all of it. Known flight points are ShyWay's (Shy.Way.Flights).
--   T:GuideWants(questID) -> "accept" | "turnin" | "leave" (named, but by hand) | nil
--   T:GuideSkips(questID) -> true when guide-only mode leaves this quest to the player (Notice.lua)
--   T:GuideTakes(questID) -> true when the card takes this quest (Notice.lua)
--   T:TalkPasses(questID) -> true when the immersive dialog's Space passes this offered quest by (Notice.lua)
--   T:TalkWaiting() -> true while a request made for the player waits for the game's answer
--   T:Flight() -> slot, whose: the flight the guide or the route asks for on the flight master's map now open

local ADDON, ns = ...
local T = ns.T
local G, R = ns.Guide, ns.Route
local lib = G.lib

local order                -- ".skipgossip npc,1,2": which pick this talk is on

local function On(key)
	return T.db.guide[key] == true
end

-- Views of the live guide steps, the main one first.
local function Views()
	local views = {}
	for _, stop in ipairs(R.stops) do
		if stop.kind == "guide" and stop.view and stop.view.talk then views[#views + 1] = stop.view end
	end
	return views
end

local function Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	return tonumber((select(6, strsplit("-", guid))))
end

-- Gossip

local function Offered()
	local options = C_GossipInfo.GetOptions()
	table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end)
	return options
end

local BIND = 132052        -- Interface\GossipFrame\BinderGossipIcon: "Make this inn your home."
local ANSWER = 3           -- seconds the game's "make this your home?" may take to come
local binding              -- when an innkeeper's bind line was picked for a step
local answered             -- when the game's question about it was answered

-- The innkeeper's bind line among the options, if it is there.
local function BindLine(options)
	for _, option in ipairs(options) do
		local icon = option.overrideIconID or option.icon
		if option.gossipOptionID and icon ~= nil and not issecretvalue(icon) and icon == BIND then return option.gossipOptionID end
	end
end

-- Whether the card's "Make this inn your home" (Hearth.lua) names this innkeeper.
local function Homing(npc)
	if npc == nil then return false end
	for _, stop in ipairs(R.stops) do
		if stop.kind == "errand" and stop.errand == "sethome" and stop.thing and stop.thing.id == npc then return true end
	end
	return false
end

-- The card's errands at this NPC (Route.lua's stops: the trainer with spells due, a vendor to sell or buy
-- at, the flight master, a talent reset): the gossip line that does what the card sent you for, asked of
-- ShyCore's quest dialog (Shy.Talk.Want), which picks it as the page comes, or shows why it leads.
local ERRAND_LINE = { train = "train", pettrainer = "train", weapons = "train", aid = "train", reset = "unlearn",
	sell = "vendor", supplies = "vendor", potions = "vendor", flightpath = "fly", bank = "bank" }

local function ErrandLine(npc, lines)
	if npc == nil then return nil end
	for _, stop in ipairs(R.stops) do
		local kind = stop.kind == "errand" and ERRAND_LINE[stop.errand]
		if kind and stop.thing and stop.thing.id == npc then
			for _, line in ipairs(lines) do
				if line.kind == kind then
					-- The stop's words, without their "Train:" or "Sell:".
					local why = stop.title and (stop.title:gsub("^[^:]+:%s*", "")) or nil
					return line, why ~= "" and why or nil
				end
			end
		end
	end
end

ns.ErrandLine = ErrandLine
if Shy.Talk and Shy.Talk.Want then Shy.Talk.Want("quest", ErrandLine) end

-- The immersive dialog's word on a quest offered you that the guide doesn't use: while it leads (guide-only
-- mode, Notice.lua's T:GuideSkips), the quest's row and page say so. Following a zone, nothing is said.
local OFF_GUIDE = "Not in your guide"
ns.OFF_GUIDE = OFF_GUIDE
if Shy.Talk and Shy.Talk.Note then
	Shy.Talk.Note("quest", function(quest)
		if T.GuideSkips and T:GuideSkips(quest) then return OFF_GUIDE end
	end)
end

-- An offered quest the immersive dialog's Space passes by (Notice.lua's T:TalkPasses): its row is still there to click.
if Shy.Talk and Shy.Talk.Pass then
	Shy.Talk.Pass("quest", function(quest) return T.TalkPasses ~= nil and T:TalkPasses(quest) end)
end

-- The quest window's pills on a quest (Shy.Talk.Facts): that your guide takes it, where it stands in its chain and the
-- quest it leads to, and on an offer who takes it back (and where, when that isn't here).
local CHAIN = 25   -- the longest chain walked either way
local function Facts(quest, kind)
	local D, Here, L = ns.Data, ns.World, ns.Log
	local out = {}
	local wants = T.GuideWants and T:GuideWants(quest)
	if wants == "accept" or wants == "turnin" then out[#out + 1] = { text = "In your guide", tone = "good" } end
	local info = D.Quest(quest)
	if not info then return out end
	-- The chain: back while the quest before leads to this one, on through each quest's next.
	local seen, before, after = { [quest] = true }, 0, 0
	local at = info
	while before < CHAIN and at.preSingle and #at.preSingle == 1 and not seen[at.preSingle[1]] do
		local prev = D.Quest(at.preSingle[1])
		if not (prev and prev.next == at.id) then break end
		seen[prev.id] = true
		before, at = before + 1, prev
	end
	at = info
	while after < CHAIN and at.next and not seen[at.next] do
		local nextQuest = D.Quest(at.next)
		if not nextQuest then break end
		seen[nextQuest.id] = true
		after, at = after + 1, nextQuest
	end
	if before + after > 0 then out[#out + 1] = { text = ("Part %d of %d"):format(before + 1, before + after + 1) } end
	local follow = info.next and D.Quest(info.next)
	if follow and follow.name then out[#out + 1] = { text = "Then " .. follow.name, tone = "hot" } end
	if kind ~= "detail" then return out end
	for _, token in ipairs(info.ends or {}) do
		local thing = D.Thing(token.kind, token.id)
		if thing and thing.name and (token.kind == "o" or L.Friendly(thing)) then
			local here = UnitName("questnpc")
			if not issecretvalue(here) and here == thing.name then
				out[#out + 1] = { text = "Hand in here" }
			else
				local place = thing.places and thing.places[1]
				local zone = place and place.map and Here.MapName(place.map)
				if zone == GetZoneText() then zone = nil end
				out[#out + 1] = { text = "Hand in to " .. thing.name .. (zone and (", " .. zone) or "") }
			end
			break
		end
	end
	return out
end
ns.TalkFacts = Facts
if Shy.Talk and Shy.Talk.Facts then Shy.Talk.Facts("quest", Facts) end

local function OnGossip()
	local options = Offered()
	if #options == 0 then return end
	local has = {}
	for _, option in ipairs(options) do
		if option.gossipOptionID then has[option.gossipOptionID] = true end
	end
	-- Being offered the option completes the task.
	G.Latch(function(element)
		return element.command == "gossipoption" and has[lib.Ids(element)[1] or 0] == true
	end)
	if IsShiftKeyDown() then return end
	local npc = Talker()
	-- A step with targets is about them only: "first option" with no NPC id, and its inn.
	local function Meant(view)
		if #view.targets == 0 then return true end
		local name = UnitName("npc")
		if issecretvalue(name) then name = nil end
		for _, target in ipairs(view.targets) do
			if (target.npc ~= nil and target.npc == npc) or (name ~= nil and target.name == name) then return true end
		end
		return false
	end
	-- Returns true so the caller does nothing else with this gossip.
	local function Say(id)
		C_GossipInfo.SelectOption(id)
		return true
	end
	-- A step or the card's inn row that sets the hearthstone: its innkeeper's bind line, before
	-- anything else here. Not when home is this inn already.
	local bind = On("setHome") and not (binding and GetTime() - binding < ANSWER) and not (ns.Hearth and ns.Hearth.AtHome()) and BindLine(options)
	if bind then
		if Homing(npc) then
			binding = GetTime()
			return Say(bind)
		end
		for _, view in ipairs(Views()) do
			if view.binds and Meant(view) then
				binding = GetTime()
				return Say(bind)
			end
		end
	end
	if not On("gossip") then return end
	for _, view in ipairs(Views()) do
		for _, talk in ipairs(view.talk) do
			if talk.kind == "option" then
				for _, id in ipairs(talk.ids) do
					if has[id] then return Say(id) end
				end
			elseif C_GossipInfo.GetNumAvailableQuests() == 0 and C_GossipInfo.GetNumActiveQuests() == 0 then
				if talk.kind == "first" and ((talk.npc == nil and Meant(view)) or (talk.npc ~= nil and talk.npc == npc)) then
					return Say(options[1].gossipOptionID)
				elseif talk.kind == "order" and (talk.npc == npc or talk.npc == 0) then
					-- One pick per GOSSIP_SHOW.
					order = (order or 0) % #talk.picks + 1
					local option = options[talk.picks[order] or 0]
					if option then return Say(option.gossipOptionID) end
				end
			end
		end
	end
end

-- The game asks before it moves the hearthstone. Asked for a step, it is answered on the next
-- frame, when the game's own question is up to be put away.
local function OnBinder()
	local asked = binding
	binding = nil
	if not asked or GetTime() - asked > ANSWER or IsShiftKeyDown() then return end
	C_Timer.After(0, function()
		local manager, binder = C_PlayerInteractionManager, Enum.PlayerInteractionType.Binder
		if not manager.IsValidNPCInteraction(binder) then return end
		answered = GetTime()
		manager.ConfirmationInteraction(binder)
		manager.ClearInteraction(binder)
		StaticPopup_Hide("CONFIRM_BINDER")
	end)
end

-- Said once the game has moved it.
local function OnBound()
	local mine = answered ~= nil and GetTime() - answered < ANSWER
	answered = nil
	if not mine then return end
	local inn = GetBindLocation()
	if inn == nil or inn == "" then inn = "this inn" end
	T:Print(("hearthstone set to |cffffffff%s|r. Hold Shift at an innkeeper to leave it where it is."):format(inn))
end

-- What a giver offers
-- The NPC's quest list is checked against the data (L.Heard). A quest the live step wants from
-- them that isn't listed is dropped from the guide and reported in chat.

local NONE = {}
local talking              -- a gossip window was read since the last one closed: later pages list no quests

-- Returns "n" (creature) or "o" (object) and its data record.
local function Giver()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	id = tonumber(id)
	if not id then return nil end
	if kind == "GameObject" then return "o", ns.Data.Object(id) end
	if kind == "Creature" or kind == "Vehicle" then return "n", ns.Data.Npc(id) end
end

-- Quests the live steps or the class quest row accept from this giver: { [quest] = true } or nil.
local function Asked(kind, thing)
	local asked
	for _, entry in ipairs(kind == "n" and ns.ClassQuests and ns.ClassQuests.Open() or NONE) do
		if entry.npc.id == thing.id then
			asked = asked or {}
			asked[entry.quest.id] = true
		end
	end
	for _, list in ipairs({ G.active, G.behind }) do
		for _, entry in ipairs(list) do
			for _, part in ipairs(entry.parts) do
				local element = part.element
				local id = element.command == "accept" and not part.done and not part.dropped and lib.Ids(element)[1]
				local quest = id and ns.Data.Quest(id)
				for _, token in ipairs(quest and quest.starts or NONE) do
					if token.kind == kind and token.id == thing.id then
						asked = asked or {}
						asked[id] = true
					end
				end
			end
		end
	end
	return asked
end

-- Quests whose page the game showed lately ([quest] = when): offered, though the window that comes back
-- once one is taken lists it nowhere (it is handed in to someone else) and the log may not have it yet.
local shown = {}
local SHOWN = 30             -- seconds

-- offered: { [quest] = true } as listed. unsure: a missing quest proves nothing.
local function Hear(kind, thing, offered, unsure)
	local L = ns.Log
	local before = L.version
	local asked = Asked(kind, thing)
	for quest, at in pairs(shown) do
		if GetTime() - at < SHOWN then offered[quest] = true else shown[quest] = nil end
	end
	for _, quest in ipairs(L.Heard(kind, thing, offered, unsure, asked) or NONE) do
		if asked and asked[quest.id] then
			T:Print(("%s isn't offering |cffffffff%s|r, so the guide skips it. Accept it later and the guide picks it up.")
				:format(thing.name, quest.name))
		end
	end
	if L.version ~= before then ns.Refresh() end
end

-- The player says a quest isn't offered (the card's menu): an object with nothing to give opens no
-- window, so nothing was heard. The guide lets the quest go as it does when a giver's list leaves it out.
function ns.NotOffered(quest)
	local data = ns.Data.Quest(quest)
	local token = data and R.Usable(data.starts)
	if not token or (token.kind ~= "n" and token.kind ~= "o") then return end
	local thing = token.kind == "n" and ns.Data.Npc(token.id) or ns.Data.Object(token.id)
	ns.Log.NotOffered(quest, token.kind .. token.id)
	T:Print(("%s isn't offering |cffffffff%s|r, so the guide skips it. Accept it later and the guide picks it up.")
		:format(thing and thing.name or "The giver", data.name))
	ns.Refresh()
end

local function HearGossip()
	local first = not talking
	talking = true
	local kind, thing = Giver()
	if not thing then return end
	local offered, unsure = {}, not first
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if issecretvalue(quest.questID) then unsure = true else offered[quest.questID] = true end
	end
	-- A turn-in is pending, which may unlock the next quest. A quest held from them is theirs: just
	-- accepted, it is listed here before the log has it.
	for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
		if issecretvalue(quest.isComplete) or quest.isComplete then unsure = true end
		if not issecretvalue(quest.questID) then offered[quest.questID] = true end
	end
	Hear(kind, thing, offered, unsure)
end

local function HearGreeting()
	local kind, thing = Giver()
	if not thing then return end
	local offered, unsure = {}, false
	for i = 1, GetNumAvailableQuests() do
		local _, _, _, _, quest = GetAvailableQuestInfo(i)
		if quest then offered[quest] = true end
	end
	for i = 1, GetNumActiveQuests() do
		local _, complete = GetActiveTitle(i)
		if complete then unsure = true end
		local quest = GetActiveQuestID(i)
		if quest then offered[quest] = true end
	end
	Hear(kind, thing, offered, unsure)
end

-- Flights

-- (The flight points the map shows are learned by ShyWay: Shy.Way.Learn.) The flight the guide or the
-- route asks for at the flight master whose map is open: its node, and whose it is ("guide" or "route").
local function Wanted()
	local nodes = C_TaxiMap.GetAllTaxiNodes(GetTaxiMapID())
	for _, stop in ipairs(R.stops) do
		local to = stop.kind == "guide" and stop.view and stop.view.fly
		-- Or a flight the route added, when at its flight master (not a boat's town that has one too).
		local route = stop.kind == "fly" and not stop.ferry and stop.yards and stop.yards <= 50
		if route then to = stop.fly end
		if to then
			to = to:upper()
			for _, node in ipairs(nodes) do
				if node.state == Enum.FlightPathState.Reachable and node.name and node.name:upper():find(to, 1, true) then
					return node, route and "route" or "guide"
				end
			end
		end
	end
end

-- Taking it as the map opens. ShySkin's flight master window, where it stands in for the game's map, offers it
-- instead, picked and one press away, and nothing is taken for you (T:Flight).
local function OnTaxi(system)
	if not On("takeFlights") or IsShiftKeyDown() then return end
	local skin = Shy.addons.Skin
	if system == Enum.UIMapSystem.Taxi and skin and skin.owns and skin.owns.flights then return end
	local node = Wanted()
	if not node then return end
	T:Print(("flying to |cffffffff%s|r. Hold Shift at a flight master to pick your own."):format(node.name))
	TakeTaxiNode(node.slotIndex)
end

-- For the flight master's window (ShySkin): the slot of the flight the guide or the route asks for on the map now
-- open, and whose it is ("guide" or "route"); nil for none.
function T:Flight()
	local node, whose = Wanted()
	if not node then return nil end
	return node.slotIndex, whose
end

-- Quests

function T:GuideWants(quest)
	local wants
	for _, entry in ipairs(G.active) do
		for _, part in ipairs(entry.parts) do
			local element = part.element
			local command = element.command
			if (command == "accept" or command == "turnin") and not part.done and not part.dropped and lib.Ids(element)[1] == quest then
				local list = lib.Args(element)
				-- ".accept id,1" and ".turnin id,reward,1" mean by hand.
				local byHand = (tonumber(list[command == "accept" and 2 or 3]) or 0) % 2 == 1
				if byHand then return "leave" end
				wants = wants or command
			end
		end
	end
	return wants
end

-- Reward index a live step names (".turnin 123,2"), if any.
local function Reward(quest)
	for _, entry in ipairs(G.active) do
		for _, part in ipairs(entry.parts) do
			local element = part.element
			if element.command == "turnin" and lib.Ids(element)[1] == quest then
				local reward = tonumber(lib.Args(element)[2]) or 0
				if reward > 0 then return reward end
			end
		end
	end
end

local function OnReward()
	local reward = Reward(GetQuestID())
	if not reward or GetNumQuestChoices() < math.max(2, reward) then return end
	local link = GetQuestItemLink("choice", reward)
	if link then T:Print(("your guide suggests %s."):format(link)) end
end

-- Auto accept and turn-in (T.db.giver)
-- Never automated: a quest that costs gold or has a reward choice (unless ShyGear picks a clear one),
-- anything in Data/ByHand.lua, a step marked by hand, and in guide-only mode a quest off the guide.
--
-- The client answers each request a moment later, and a second click on the NPC can re-show a list
-- that still names the quest just accepted or turned in. Acting on it again leaves a page nothing
-- closes, or an interaction the client still counts as open, and the NPC stops responding. So:
--   * one request at a time (`pending`); lists that show before the answer, or WAIT, are re-read after;
--   * a listed quest already in the log, or just turned in, is skipped;
--   * a page for a quest already accepted or turned in is closed, not acted on;
--   * a pick that brings no page and leaves no window clears the interaction.

local WAIT = 3                 -- seconds to wait for the client's answer
local ECHO = 2                 -- an unrequested page this soon after its quest was accepted or turned in is a repeat
local MOMENT = 0.2             -- seconds the client gets to close a page itself
local KEPT = 240               -- log lines kept
local yours = false            -- Shift was held during this interaction: hands off until it ends
local pending                  -- { what = "pick" | "accept" | "finish" | "reward", quest = id, at = when }
local taken, gone = {}, {}     -- [quest] = when it was accepted / turned in
local told = {}                -- quests already reported as off the guide
local closing
local PickGossip, PickGreeting

-- Off until Data/ByHand.lua is loaded (a new file needs a client restart). Off while the other quest
-- addon accepts or hands in quests itself (Yield.lua): two addons answering one window leave it half done.
local function Giving()
	return T.db.giver.auto == true and ns.data.byHand ~= nil and not (ns.Yield ~= nil and ns.Yield.To("giver"))
end

local function Paused()
	if IsShiftKeyDown() then yours = true end
	return yours
end

local function Open()
	return GossipFrame:IsShown() or QuestFrame:IsShown()
end

-- A page of the game's quest window is up. While immersive quest text stands in for that window
-- (Shy.Talk), the window is never visible and the dialog says which page the game is on.
local function Up(panel, page)
	if panel:IsVisible() then return true end
	local talk = Shy.Talk
	return talk ~= nil and talk.Page ~= nil and talk.Page() == page
end

-- Interaction log, kept across reloads; "/shy quest talk" shows it. Each line is prefixed with
-- G / Q (gossip / quest window shown) and g / q (client counts that interaction as open).
local function Note(text, quest)
	local manager, kind = C_PlayerInteractionManager, Enum.PlayerInteractionType
	local log = ns.char.talks or {}
	ns.char.talks = log
	log[#log + 1] = ("%.2f  %s%s%s%s  %s%s"):format(GetTime(),
		GossipFrame:IsShown() and "G" or "-", QuestFrame:IsShown() and "Q" or "-",
		manager.IsInteractingWithNpcOfType(kind.Gossip) and "g" or "-", manager.IsInteractingWithNpcOfType(kind.QuestGiver) and "q" or "-",
		text, quest and (" " .. tostring(quest)) or "")
	if #log > KEPT then table.remove(log, 1) end
end

function ns.ShowTalks()
	local log = ns.char.talks or {}
	Shy.UI.ShowCopyBox("ShyQuest: quest giver log", table.concat({
		"Seconds, windows open (G gossip, Q quest; g / q: the game still counts that one as open), then the event.",
		"In a list: 12! is available, 12? is ready to turn in, 12.. is in progress. -> is what ShyQuest did.",
		"[...] are the icons of a gossip window's other choices: 132060 is a shop.",
		"",
		#log > 0 and table.concat(log, "\n") or "Nothing yet. Turn on auto accept and turn-in, then talk to a quest giver.",
	}, "\n"))
end

local function AllClosed()
	if closing then return end
	closing = true
	C_Timer.After(0.5, function()
		closing = false
		if Open() then return end
		yours = false
		Note("no window left")
	end)
end

local function Lately(when)
	return when ~= nil and GetTime() - when < ECHO
end

local function Waiting()
	return pending ~= nil and GetTime() - pending.at < WAIT
end

local function Already(what, quest)
	return Waiting() and pending.what == what and pending.quest == quest
end

-- Something was asked of the game for the player and its answer is still out: a list or page that
-- shows meanwhile is looked at again once it is in (ShyCore's quest dialog waits for it too).
function T:TalkWaiting()
	return Giving() and not yours and Waiting()
end

-- A list can still name a quest that was just accepted.
local function Held(quest)
	return quest ~= nil and C_QuestLog.IsOnQuest(quest)
end

-- kind: "accept" | "turnIn" (Data/ByHand.lua).
local function Never(kind, quest)
	return quest ~= nil and ns.data.byHand[kind][quest] == true
end

-- An NPC whose quests are never automated. A secret GUID counts as one.
local function Stranger(unit)
	local guid = UnitGUID(unit)
	if guid == nil then return false end
	if issecretvalue(guid) then return true end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return (kind == "Creature" or kind == "Vehicle") and ns.data.byHand.npcs[tonumber(id) or 0] == true
end

-- A quest a stranger shares that ShyTweaks turns away: left for it to decline.
local function TurnedAway()
	local tweaks = Shy.addons.Tweaks
	return tweaks ~= nil and tweaks.TurnsShareAway ~= nil and tweaks:TurnsShareAway()
end

local function ByHand(quest)
	return quest ~= nil and T:GuideWants(quest) == "leave"
end

-- A guide step on the card picks this quest up. Its optional steps count: they offer gray quests still worth their XP.
local function Sent(quest)
	local route = ns.Route
	for _, list in ipairs({ route.stops, route.offered }) do
		for _, stop in ipairs(list) do
			if stop.kind == "guide" then
				for _, action in ipairs(stop.actions) do
					if action.kind == "pickup" and action.id == quest then return true end
				end
			end
		end
	end
	return false
end

-- Gray quests wait for "Gray quests too", unless your guide sends you for one.
local function LeftGray(quest, trivial)
	return trivial == true and not T.db.giver.gray and not Sent(quest)
end

-- Guide-only mode: a quest off the guide is left to the player, reported once.
local function OffGuide(quest)
	if quest == nil or T.GuideSkips == nil or not T:GuideSkips(quest) then return false end
	if not told[quest] then
		told[quest] = true
		T:Print(("|cffffffff%s|r isn't in your guide. Accept it yourself if you want it."):format(C_QuestLog.GetTitleForQuestID(quest) or "This quest"))
	end
	return true
end

-- No window is up but the client may still count the interaction as open: clear it.
local function LetGo()
	local manager, kind = C_PlayerInteractionManager, Enum.PlayerInteractionType
	for _, talk in ipairs({ kind.Gossip, kind.QuestGiver }) do
		if manager.IsInteractingWithNpcOfType(talk) then
			Note("-> let go of the talk")
			manager.ClearInteraction(talk)
		end
	end
end

-- Closes a stale quest page as its own button would, and the window if the client leaves it up.
local function PutAway(quest)
	Note("-> put away", quest)
	if QuestGetAutoAccept() then AcknowledgeAutoAcceptQuest() else CloseQuest() end
	if QuestFrame:IsShown() and not InCombatLockdown() then HideUIPanel(QuestFrame) end
end

-- Re-reads a list that showed while a request was pending.
local function Again()
	if not Giving() or Paused() or Waiting() then return end
	if GossipFrame:IsShown() then PickGossip() elseif Up(QuestFrameGreetingPanel, "greeting") then PickGreeting() end
end

-- Marks one request as pending. Unanswered after WAIT: a pick with no window left clears the
-- interaction; anything else re-reads the list.
local function Ask(what, quest)
	local mine = { what = what, quest = quest, at = GetTime() }
	pending = mine
	Note("-> " .. what, quest)
	C_Timer.After(WAIT, function()
		if pending ~= mine then return end
		pending = nil
		Note("no answer to " .. what, quest)
		if what ~= "pick" then
			Again()
		elseif not Open() then
			LetGo()
		end
	end)
end

-- A page showed: clears a pending "pick" (or `also`). True when the page answers that request.
local function Page(quest, also)
	local wanted = pending ~= nil and pending.quest == quest and (pending.what == "pick" or pending.what == also)
	if pending and (pending.what == "pick" or pending.what == also) then pending = nil end
	return wanted
end

-- Shortly after an accept or turn-in: close its page if still up, else re-read the list.
local function Settle(quest, page, kind)
	C_Timer.After(MOMENT, function()
		if not Giving() or Paused() then return end
		if Up(page, kind) and GetQuestID() == quest and not (Waiting() and pending.quest == quest) then
			PutAway(quest)
		else
			Again()
		end
	end)
end

-- Log form of a list entry: 12! available, 12? ready to turn in, 12.. in progress.
local function Entry(quest, mark)
	return (issecretvalue(quest) and "(kept)" or tostring(quest)) .. mark
end

function PickGossip()
	if Paused() or Stranger("npc") then return end
	if Waiting() then return Note("left for now, still out: " .. pending.what, pending.quest) end
	local giver = T.db.giver
	if giver.turnIn then
		for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
			local quest = q.questID
			if not issecretvalue(quest) and not issecretvalue(q.isComplete) and q.isComplete and not gone[quest]
				and not Never("turnIn", quest) and not ByHand(quest) then
				Ask("pick", quest)
				return C_GossipInfo.SelectActiveQuest(quest)
			end
		end
	end
	if giver.accept then
		for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do
			local quest = q.questID
			if not issecretvalue(quest) and not LeftGray(quest, q.isTrivial) and (giver.again or not q.repeatable) and not Held(quest)
				and not Never("accept", quest) and not ByHand(quest) and not OffGuide(quest) then
				Ask("pick", quest)
				return C_GossipInfo.SelectAvailableQuest(quest)
			end
		end
	end
end

-- The quest-list window of an NPC with no gossip.
function PickGreeting()
	if Paused() or Stranger("npc") then return end
	if Waiting() then return Note("left for now, still out: " .. pending.what, pending.quest) end
	local giver = T.db.giver
	if giver.turnIn then
		for i = 1, GetNumActiveQuests() do
			local _, isComplete = GetActiveTitle(i)
			local quest = GetActiveQuestID(i)
			if isComplete and not gone[quest] and not Never("turnIn", quest) and not ByHand(quest) then
				Ask("pick", quest)
				return SelectActiveQuest(i)
			end
		end
	end
	if giver.accept then
		for i = 1, GetNumAvailableQuests() do
			local isTrivial, _, isRepeatable, _, quest = GetAvailableQuestInfo(i)
			if not LeftGray(quest, isTrivial) and (giver.again or not isRepeatable) and not Held(quest)
				and not Never("accept", quest) and not ByHand(quest) and not OffGuide(quest) then
				Ask("pick", quest)
				return SelectAvailableQuest(i)
			end
		end
	end
end

local function AtGossip()
	if not Giving() then return end
	local list = {}
	for _, q in ipairs(C_GossipInfo.GetActiveQuests()) do
		list[#list + 1] = Entry(q.questID, not issecretvalue(q.isComplete) and q.isComplete and "?" or "..")
	end
	for _, q in ipairs(C_GossipInfo.GetAvailableQuests()) do list[#list + 1] = Entry(q.questID, "!") end
	-- The window's other choices, by icon (132060 is a shop: Bags.lua).
	local icons = {}
	for _, option in ipairs(C_GossipInfo.GetOptions()) do
		local icon = option.overrideIconID or option.icon
		icons[#icons + 1] = (icon == nil or issecretvalue(icon)) and "?" or tostring(icon)
	end
	if #icons > 0 then list[#list + 1] = "[" .. table.concat(icons, " ") .. "]" end
	Note("GOSSIP_SHOW " .. table.concat(list, " "))
	PickGossip()
end

local function AtGreeting()
	if not Giving() then return end
	local list = {}
	for i = 1, GetNumActiveQuests() do
		local _, isComplete = GetActiveTitle(i)
		list[#list + 1] = Entry(GetActiveQuestID(i), isComplete and "?" or "..")
	end
	for i = 1, GetNumAvailableQuests() do list[#list + 1] = Entry((select(5, GetAvailableQuestInfo(i))), "!") end
	Note("QUEST_GREETING " .. table.concat(list, " "))
	PickGreeting()
end

local function AtDetail()
	if not Giving() then return end
	local giver, quest = T.db.giver, GetQuestID()
	Note("QUEST_DETAIL", quest)
	Page(quest)
	-- quest == 0: the client closed the page as it opened.
	if Paused() or not giver.accept or quest == 0 or Stranger("questnpc") or TurnedAway() then return end
	-- Auto-accepted by the client, or a repeat page for a quest just accepted.
	if QuestGetAutoAccept() or Held(quest) then return PutAway(quest) end
	if LeftGray(quest, C_QuestLog.IsQuestTrivial(quest)) then return end
	if not giver.again and C_QuestLog.IsRepeatableQuest(quest) then return end
	if Never("accept", quest) or ByHand(quest) or OffGuide(quest) or Already("accept", quest) then return end
	Ask("accept", quest)
	AcceptQuest()
end

-- A group member started an escort quest.
local function AtConfirm()
	if not Giving() or Paused() or not T.db.giver.accept then return end
	ConfirmAcceptQuest()
	StaticPopup_Hide("QUEST_ACCEPT")
end

local function AtProgress()
	if not Giving() then return end
	local quest = GetQuestID()
	Note("QUEST_PROGRESS", quest)
	local wanted = Page(quest)
	if Paused() or Stranger("questnpc") then return end
	-- An unrequested page for a quest just turned in or accepted is a repeat.
	if not wanted and (Lately(gone[quest]) or (Lately(taken[quest]) and not IsQuestCompletable())) then return PutAway(quest) end
	if not T.db.giver.turnIn or Already("finish", quest) then return end
	if IsQuestCompletable() and GetQuestMoneyToGet() == 0 and not Never("turnIn", quest) and not ByHand(quest) then
		Ask("finish", quest)
		CompleteQuest()
	end
end

local function AtReward()
	if not Giving() then return end
	local quest = GetQuestID()
	Note("QUEST_COMPLETE", quest)
	local wanted = Page(quest, "finish")
	if Paused() or Stranger("questnpc") then return end
	if not wanted and Lately(gone[quest]) then return PutAway(quest) end
	if not T.db.giver.turnIn or Never("turnIn", quest) or Already("reward", quest) then return end
	local choices = GetNumQuestChoices()
	-- A reward choice is the player's unless ShyGear has a clear pick.
	local gear = Shy.addons.Gear
	local pick = choices <= 1 and choices or (gear and gear:TakeReward())
	if pick then
		Ask("reward", quest)
		GetQuestReward(pick)
	end
end

local function AtTaken(quest)
	if not Giving() then return end
	Note("QUEST_ACCEPTED", quest)
	taken[quest], gone[quest] = GetTime(), nil
	if pending and pending.quest == quest then pending = nil end
	if T.db.giver.accept then Settle(quest, QuestFrameDetailPanel, "detail") end
end

local function AtHandedIn(quest)
	if not Giving() then return end
	Note("QUEST_TURNED_IN", quest)
	gone[quest] = GetTime()
	if pending and pending.quest == quest then pending = nil end
	if T.db.giver.turnIn then Settle(quest, QuestFrameRewardPanel, "reward") end
end

local function AtClosed(what)
	if not Giving() then return end
	Note(what)
	AllClosed()
end

-- One-time import of the setting from ShyTweaks, where it used to live.
local function Inherit()
	local old = ShyTweaksDB
	local was = old and old.features and old.features.autoQuest
	if was == nil then return end
	local options, giver = old.options and old.options.autoQuest or {}, T.db.giver
	giver.auto = was
	if options.accept ~= nil then giver.accept = options.accept end
	if options.turnIn ~= nil then giver.turnIn = options.turnIn end
	if options.skipTrivial ~= nil then giver.gray = not options.skipTrivial end
	if options.skipRepeatable ~= nil then giver.again = not options.skipRepeatable end
	old.features.autoQuest = nil
	if old.options then old.options.autoQuest = nil end
end

Shy:On("SHY_LOGIN", function()
	Inherit()
	if T.db.giver.auto and ns.data.byHand == nil then
		T:Print("auto accept and turn-in needs a full game restart, not a reload. Until then, click quests yourself.")
	end
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "TAXIMAP_OPENED", "QUEST_COMPLETE", "UI_INFO_MESSAGE", "CONFIRM_BINDER", "HEARTHSTONE_BOUND",
		"QUEST_GREETING", "QUEST_DETAIL", "QUEST_TURNED_IN", "QUEST_PROGRESS", "QUEST_ACCEPTED", "QUEST_ACCEPT_CONFIRM", "QUEST_FINISHED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, first, message)
		if event == "GOSSIP_SHOW" then
			HearGossip()
			-- A gossip option picked for the step is this interaction's one request.
			if not OnGossip() then AtGossip() end
		elseif event == "CONFIRM_BINDER" then
			OnBinder()
		elseif event == "HEARTHSTONE_BOUND" then
			OnBound()
		elseif event == "GOSSIP_CLOSED" then
			order, talking = nil, nil
			AtClosed(first and "GOSSIP_CLOSED, the talk carries on" or "GOSSIP_CLOSED")
		elseif event == "QUEST_GREETING" then
			HearGreeting()
			AtGreeting()
		elseif event == "QUEST_DETAIL" then
			-- An offered quest is available, whatever a list said earlier.
			local before = ns.Log.version
			if GetQuestID() ~= 0 then shown[GetQuestID()] = GetTime() end
			ns.Log.Offered(GetQuestID())
			if ns.Log.version ~= before then ns.Refresh() end
			AtDetail()
		elseif event == "QUEST_TURNED_IN" then
			ns.Log.HandedIn(first)
			AtHandedIn(first)
		elseif event == "TAXIMAP_OPENED" then
			OnTaxi(first)
		elseif event == "QUEST_COMPLETE" then
			OnReward()
			AtReward()
		elseif event == "QUEST_PROGRESS" then
			AtProgress()
		elseif event == "QUEST_ACCEPTED" then
			AtTaken(first)
		elseif event == "QUEST_ACCEPT_CONFIRM" then
			AtConfirm()
		elseif event == "QUEST_FINISHED" then
			AtClosed("QUEST_FINISHED")
		elseif event == "UI_INFO_MESSAGE" and not issecretvalue(message) and message == ERR_NEWTAXIPATH then
			G.Happened("fp")
		end
	end)
end)
