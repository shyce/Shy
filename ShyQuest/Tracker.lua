-- Drives Blizzard's quest tracker from the route: which quests are watched, their order, hover details.
--
-- Taint: the tracker's quest-item buttons call a protected function, so nothing here adds lines or
-- sections to it, calls its layout, or writes on its frames. The watch list is changed only through
-- C_QuestLog.AddQuestWatch / RemoveQuestWatch.
--
-- Watched (track = "zone"): quests for the current zone, the live guide steps and the chosen quest, in
-- the card's order. With nothing here, the quests of the zone the route heads for next.
-- A manual track or untrack is remembered per quest (ns.char.watch) and wins.
-- New and removed quests and a new top quest apply at once; a reorder below the top must hold SETTLE
-- seconds; nothing changes in combat.
-- The game appends a watch, so order is made by removing and re-adding. If the client keeps its own
-- order (seen on reading back, twice) only the choice of quests is maintained; so too while the other
-- quest addon's tracker is on (Yield.lua).

local ADDON, ns = ...
local T = ns.T
local D, W, L, R, Tips = ns.Data, ns.World, ns.Log, ns.Route, ns.Tips

local MOST = Constants.QuestWatchConsts.MAX_QUEST_WATCHES
local OURS_FOR = 2           -- seconds within which a change we asked for is expected back
local SETTLE = 4             -- seconds a reorder below the top must hold
local ON_THE_ROAD = 3        -- quests tracked when the route's next zone is unknown

-- Hover details

-- In a group Blizzard has already opened its tooltip with party progress: add to it. Solo, use Tips.Open.
local function OnHeaderEnter(_, block, id, grouped)
	if not T.db.tips or not L.entries[id] then return end
	if grouped then
		GameTooltip:AddLine(" ")
		Tips.Quest(GameTooltip, id, false, true)
		GameTooltip:Show()
		return
	end
	local lines = Tips.Lines()
	Tips.Quest(lines, id, true)
	-- The gap clears the quest's marker left of the block.
	Tips.Open(block, lines, { side = "LEFT", gap = 34 })
end

-- EventRegistry announces only the enter; the leave is the section's own method.
local function OnHeaderLeave(_, block)
	Tips.Close(block)
end

-- The next quest's marker: Look.lua paints the leading quest's marker in the focus color.

local function NextQuest()
	local stop = T.db.marker and R.stops[1]
	-- Flights and errands never lead.
	local at = 1
	while stop and (stop.kind == "fly" or stop.kind == "errand") do
		at = at + 1
		stop = R.stops[at]
	end
	if not stop then return nil end
	for _, action in ipairs(stop.actions) do
		if action.kind ~= "pickup" then return action.id end
	end
end

local function Mark()
	if ns.Look and ns.Look.SetLead then ns.Look.SetLead(NextQuest()) end
end

-- The watch list

local says               -- ns.char.watch: quest -> true (always tracked) | false (never)
local asked = {}         -- changes we requested: "12+" / "12-" -> time
local accepted = {}      -- quest -> time accepted
local refused = {}       -- quests the game wouldn't track
local stuck, gaveUp = 0, nil       -- consecutive failed arrangements; the list key given up on
local auto = {}          -- quests the last list held regardless of manual choices
local waiting, since     -- a pending reorder: its key, and since when
local LIVELY = 120       -- seconds a quest stays listed after objective progress, wherever it is
local progressed = {}    -- quest -> time of last objective progress
local followSoon = false -- the tracker's watches are chosen again next frame (QUEST_WATCH_UPDATE)
local byHand = {}        -- quest -> time a watch was taken as manual
local misses, ordering = 0, true   -- times the game didn't keep our order; whether we still try

-- The watched quests in order, and as a set.
local function Watched()
	local list, set = {}, {}
	for index = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
		if id then
			list[#list + 1] = id
			set[id] = true
		end
	end
	return list, set
end

-- A micro map (a cave) counts as its parent zone.
local zones = {}
local function ZoneOf(map)
	local zone = zones[map]
	if not zone then
		zone = map
		local info = C_Map.GetMapInfo(map)
		for _ = 1, 4 do
			if not info or info.mapType ~= Enum.UIMapType.Micro or (info.parentMapID or 0) == 0 then break end
			zone = info.parentMapID
			info = C_Map.GetMapInfo(zone)
		end
		zones[map] = zone
	end
	return zone
end

-- "The Deadmines" and "Deadmines" compare equal.
local function Plain(name)
	return (name:lower():gsub("^the ", ""))
end

-- Names of the current zone, for quests placed only by quest log header or dungeon name.
local function HereNames()
	local names = {}
	for _, name in ipairs({ GetRealZoneText(), GetZoneText(), W.map and W.MapName(ZoneOf(W.map)) }) do
		if name and name ~= "" then names[Plain(name)] = true end
	end
	return names
end

-- The quests to watch, in order. nil when the player's position is unknown and nothing is here.
local function Wanted(current, tracked)
	local zoned = T.db.track == "zone"
	local here = W.map and ZoneOf(W.map)
	local names = HereNames()
	local shown = {}
	if W.map then
		for _, poi in ipairs(C_QuestLog.GetQuestsOnMap(W.map) or {}) do shown[poi.questID] = true end
	end

	local function Here(stop, id)
		if stop.kind == "guide" or stop.chosen or shown[id] then return true end
		if progressed[id] and GetTime() - progressed[id] < LIVELY then return true end
		if stop.dungeon then return names[Plain(D.DungeonName(stop.dungeon) or "")] == true end
		if stop.map then return ZoneOf(stop.map) == here end
		local entry = L.entries[id]
		return entry ~= nil and entry.header ~= nil and names[Plain(entry.header)] == true
	end

	local list, seen, elsewhere = {}, {}, {}
	local function Add(id)
		if not seen[id] and not refused[id] and #list < MOST then
			seen[id] = true
			list[#list + 1] = id
		end
	end

	wipe(auto)
	for _, stop in ipairs(R.stops) do
		for _, action in ipairs(stop.actions) do
			local id = action.id
			-- (Zone mode leaves out the gray quests, unless the player tracked one by hand.)
			if action.kind ~= "pickup" and L.Has(id) and not (zoned and says[id] ~= true and L.Ignored(id)) then
				if not zoned then
					-- track = "order": the player's quests, our order.
					if tracked[id] then Add(id) end
				else
					local near = Here(stop, id)
					if near then auto[id] = true end
					if says[id] == false then
						-- untracked by hand
					elseif near or says[id] then
						Add(id)
					else
						elsewhere[#elsewhere + 1] = { id = id, map = stop.map }
					end
				end
			end
		end
	end

	if zoned and #list == 0 then
		if not W.Known() then return nil end
		-- Nothing here: the quests of the zone the route heads for next.
		local first = elsewhere[1]
		local zone = first and first.map and ZoneOf(first.map)
		for i, entry in ipairs(elsewhere) do
			if zone and entry.map and ZoneOf(entry.map) == zone then
				Add(entry.id)
			elseif not zone and i <= ON_THE_ROAD then
				Add(entry.id)
			end
		end
	end

	-- Then, in the game's order: quests kept by hand, watches that aren't log quests, and failed quests.
	for _, id in ipairs(current) do
		if not zoned or says[id] or not L.Has(id) or L.entries[id].failed then Add(id) end
	end
	return list
end

local function Change(id, add)
	local key = id .. (add and "+" or "-")
	asked[key] = GetTime()
	local done
	if add then
		done = C_QuestLog.AddQuestWatch(id)
	else
		done = C_QuestLog.RemoveQuestWatch(id)
	end
	if not done then
		asked[key] = nil
		if add then refused[id] = true end
	end
	return done
end

-- Whether the order is ours to make: not while the other addon's tracker reads the watch list (Yield.lua), where
-- every watch taken away and put back would churn its list. Which quests are watched is still chosen.
local function Ordering()
	return ordering and not (ns.Yield ~= nil and ns.Yield.To("tracker"))
end

-- Make the watch list match `want`. The head already in order is kept; the rest is removed and re-added.
local function Arrange(want, current, tracked)
	local place = {}
	for i, id in ipairs(want) do place[id] = i end
	local arrow = C_SuperTrack.GetSuperTrackedQuestID() or 0
	local order = Ordering()
	if order then
		local kept = 0
		for _, id in ipairs(current) do
			if place[id] and want[kept + 1] == id then kept = kept + 1 end
		end
		for _, id in ipairs(current) do
			if not place[id] or place[id] > kept then Change(id, false) end
		end
		for i = kept + 1, #want do Change(want[i], true) end
	else
		for _, id in ipairs(current) do
			if not place[id] then Change(id, false) end
		end
		for _, id in ipairs(want) do
			if not tracked[id] then Change(id, true) end
		end
	end
	-- Removing the super-tracked quest's watch can drop the super-track.
	if arrow ~= 0 and place[arrow] and C_SuperTrack.GetSuperTrackedQuestID() ~= arrow then
		R.Repoint(arrow)
	end

	-- Read back: same quests in another order means the game keeps its own order; other quests three
	-- times running means this list can't be had, and it is left until the route wants another.
	local now = Watched()
	local same, all = #now == #want, #now == #want
	for i, id in ipairs(now) do
		if id ~= want[i] then same = false end
		if not place[id] then all = false end
	end
	if all and not same and order then
		misses = misses + 1
		if misses >= 2 then ordering = false end
	elseif same then
		misses = 0
	end
	stuck = all and 0 or stuck + 1
	if stuck >= 3 then gaveUp = table.concat(want, ",") end
end

-- Called when the route has been rebuilt.
local function Follow()
	if T.db.track == "off" or InCombatLockdown() or C_PlayerInfo.IsPlayerNPERestricted() then
		waiting = nil
		return
	end
	local current, tracked = Watched()
	local want = Wanted(current, tracked)
	if not want then return end
	if gaveUp then
		if table.concat(want, ",") == gaveUp then return end
		gaveUp, stuck = nil, 0
	end

	local wanted = {}
	for _, id in ipairs(want) do wanted[id] = true end
	local same = #want == #current
	for _, id in ipairs(current) do
		if not wanted[id] then same = false end
	end
	local order = Ordering()
	if not same or (order and want[1] ~= current[1]) then
		waiting = nil
		Arrange(want, current, tracked)
		return
	end
	if order then
		for i, id in ipairs(want) do
			if id ~= current[i] then
				-- A reorder below the top waits for Settle; the clock keeps running while the order is unchanged.
				local key = table.concat(want, ",")
				if key ~= waiting then waiting, since = key, GetTime() end
				return
			end
		end
	end
	waiting = nil
end

-- Called between rebuilds.
local function Settle()
	if not waiting or GetTime() - since < SETTLE or InCombatLockdown() then return end
	local current, tracked = Watched()
	local want = Wanted(current, tracked)
	local held = want and table.concat(want, ",") == waiting
	waiting = nil
	if held then Arrange(want, current, tracked) end
end

-- A watch changed: ours, the game's, or the player's.
local function OnWatch(id, added)
	if not id or added == nil then return end
	local key = id .. (added and "+" or "-")
	local when = asked[key]
	if when then
		asked[key] = nil
		if GetTime() - when < OURS_FOR then return end
	end
	if T.db.track ~= "zone" then return end
	if added then
		-- The game auto-tracks a quest on accept (it isn't in our log copy yet) ...
		if not L.Has(id) or GetTime() - (accepted[id] or -OURS_FOR) < OURS_FOR then return end
		-- ... and again on each objective update. Neither is a manual choice.
		if GetTime() - (progressed[id] or -OURS_FOR) < OURS_FOR then return end
		says[id] = not auto[id] and true or nil
		byHand[id] = says[id] and GetTime() or nil
	elseif L.Has(id) then
		if auto[id] then says[id] = false else says[id] = nil end
	end
	ns.Refresh()
end

-- The game's tracker, off the screen
--
-- The quest window (Card.lua) shows every tracked quest itself, so while it is up the game's tracker
-- is parked under a frame that is never shown. Nothing is written on it and none of its methods is
-- called: it keeps running unseen (it still tracks a quest you accept), and comes back as it was.
-- Edit Mode and the game's frame manager put it back under UIParent when they lay the screen out,
-- so its SetParent is post-hooked to park it again.
-- It stays on screen on a gamepad (the game's gamepad mode starts from it), and while another of
-- its sections has something to show (a scenario, a tracked recipe).

local OTHERS = {
	"ScenarioObjectiveTracker", "UIWidgetObjectiveTracker", "AdventureObjectiveTracker", "AchievementObjectiveTracker",
	"MonthlyActivitiesObjectiveTracker", "InitiativeTasksObjectiveTracker", "ProfessionsRecipeTracker",
	"BonusObjectiveTracker", "WorldQuestObjectiveTracker",
}
local attic                  -- the hidden frame the tracker is parked under
local parked = false
local parking = false        -- our own SetParent is running
local checking = false       -- a check is due next frame

local function OnGamepad()
	return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Another section has something to show.
local function Busy()
	for _, name in ipairs(OTHERS) do
		local section = _G[name]
		if section and section:HasContents() then return true end
	end
	return false
end

local function Park()
	checking = false
	local tracker = ObjectiveTrackerFrame
	local want = T.db.card.shown and not OnGamepad() and not Busy()
	if want == parked and (not parked or tracker:GetParent() == attic) then return end
	-- Protected only while something secure is parented to it; then it waits for the fight to end.
	if InCombatLockdown() and tracker:IsProtected() then return end
	local was = parked
	parked, parking = want, true
	if want then
		tracker:SetParent(attic)
	else
		FrameUtil.SetParentMaintainRenderLayering(tracker, UIParent)
	end
	parking = false
	if want ~= was then
		-- Back on screen it lays itself out again; ShyDock gives the room it had to whoever is there.
		if not want and Ordering() then C_QuestLog.SortQuestWatches() end
		Shy:Fire("SHY_HUD_LAYOUT")
		-- (The card stands in for a parked tracker, its quest items as buttons: the card and its buttons are
		-- written again, not the whole route, as the fight that parked it ends.)
		ns.RefreshErrands()
	end
end

-- Next frame, once: the tracker's sections update several times in a frame.
local function ParkSoon()
	if checking then return end
	checking = true
	C_Timer.After(0, Park)
end

-- Whether the quest window stands in for the game's tracker.
function ns.TrackerParked()
	return parked
end

-- Quests waiting for a click, which the game shows as a box in its tracker: one an item of yours
-- offers ("OFFER"), or one that can be completed where you stand. The quest window lists them while
-- the tracker is parked: { id, title, offer }.
function ns.QuestPopups()
	local out = {}
	if not parked then return out end
	for i = 1, GetNumAutoQuestPopUps() do
		local id, kind = GetAutoQuestPopUp(i)
		local title = id and C_QuestLog.GetTitleForQuestID(id)
		if title and title ~= "" then out[#out + 1] = { id = id, title = title, offer = kind == "OFFER" } end
	end
	return out
end

-- The click on one: the quest's offer or its completion, as the tracker's box opens it.
function ns.OpenQuestPopup(id, offer)
	if offer then ShowQuestOffer(id) else ShowQuestComplete(id) end
	RemoveAutoQuestPopUp(id)
	ns.Refresh()
end

local function SetupParking()
	attic = CreateFrame("Frame", nil, UIParent)
	attic:SetAllPoints(UIParent)   -- the tracker measures its parent for its height
	attic:Hide()
	hooksecurefunc(ObjectiveTrackerFrame, "SetParent", function()
		if parked and not parking then ParkSoon() end
	end)
	for _, name in ipairs(OTHERS) do
		local section = _G[name]
		if section then hooksecurefunc(section, "Update", ParkSoon) end
	end
	-- A quest waiting for a click is added and taken away through the quest section.
	hooksecurefunc(QuestObjectiveTracker, "AddAutoQuestPopUp", function() ns.Refresh() end)
	hooksecurefunc(QuestObjectiveTracker, "RemoveAutoQuestPopUp", function() ns.Refresh() end)
	Park()
end

-- Quest level and difficulty color in titles (CVars with no default option)

ns.TITLE_SETTINGS = { level = "showQuestLevel", color = "showQuestDifficultyColor" }

function ns.GetTitleSetting(key)
	return C_CVar.GetCVarBool(ns.TITLE_SETTINGS[key]) or false
end

function ns.SetTitleSetting(key, on)
	C_CVar.SetCVar(ns.TITLE_SETTINGS[key], on and "1" or "0")
	-- SortQuestWatches makes the tracker redraw its titles; it sorts by distance, so refresh the route order.
	C_QuestLog.SortQuestWatches()
	ns.Refresh()
end

function ns.ApplyTracker()
	Mark()
	if attic then Park() end
end

function ns.SetupTracker()
	ns.char.watch = ns.char.watch or {}
	says = ns.char.watch
	-- Adopted as a HUD box: Edit Mode places it and ShyDock may give it a home. Nothing is written on it.
	-- While it is parked it has no mover.
	ns.trackerBox = Shy.HUD.Adopt(ObjectiveTrackerFrame, { id = "shyquest-tracker", title = "Objectives", editMode = true,
		active = function() return not parked end })
	SetupParking()
	EventRegistry:RegisterCallback("OnQuestBlockHeader.OnEnter", OnHeaderEnter, T)
	hooksecurefunc(QuestObjectiveTracker, "OnBlockHeaderLeave", OnHeaderLeave)
	-- The campaign section shares the quest section's mixin and fires the same enter callback.
	hooksecurefunc(CampaignQuestObjectiveTracker, "OnBlockHeaderLeave", OnHeaderLeave)
	-- Blocks are reused on each layout.
	hooksecurefunc(QuestObjectiveTracker, "Update", Mark)

	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	events:RegisterEvent("QUEST_WATCH_UPDATE")
	events:RegisterEvent("QUEST_ACCEPTED")
	events:RegisterEvent("QUEST_REMOVED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")
	events:RegisterEvent("QUEST_AUTOCOMPLETE")
	events:SetScript("OnEvent", function(_, event, id, added)
		if event == "QUEST_WATCH_LIST_CHANGED" then
			OnWatch(id, added)
		elseif event == "QUEST_WATCH_UPDATE" then
			-- The game's auto-watch may have arrived first and been taken as manual: undo that.
			if byHand[id] and GetTime() - byHand[id] < OURS_FOR then says[id] = nil end
			progressed[id], byHand[id] = GetTime(), nil
			-- (A quest just worked on is watched for a while, Wanted: the tracker's own choice, from the
			-- route as it stands. Every objective's progress fires this; the log's own update says whether
			-- the route changes. In a fight the fight's end follows, below.)
			if not followSoon and not InCombatLockdown() then
				followSoon = true
				C_Timer.After(0, function()
					followSoon = false
					Follow()
					Mark()
				end)
			end
		elseif event == "QUEST_ACCEPTED" then
			accepted[id] = GetTime()
			says[id] = nil
		elseif event == "QUEST_REMOVED" then
			says[id], accepted[id], refused[id], progressed[id], byHand[id] = nil, nil, nil, nil, nil
		else
			Park()         -- combat ended, or the gamepad was picked up or put down
			-- What waited for it, from the route as it stands (a route gone stale is built anyway).
			Follow()
			Mark()
		end
	end)

	ns.OnRoute(function(rebuilt)
		if rebuilt then
			Follow()
			Mark()
		else
			Settle()
		end
	end)
end
