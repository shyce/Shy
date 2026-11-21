-- A dungeon run: every step you still need for one dungeon's quests, as a guide of its own that stands in
-- for yours until they are done, whatever your place in it. It is made from your faction's guides: first
-- the quests the dungeon's own wait on (each from the guide that takes it, and whatever those wait on in
-- turn, oldest first), then the dungeon's steps as the guides have them: pick up, the run, hand in. It
-- starts at its first step, passes whatever you have done already, and when nothing is left (or you
-- stop it) your guide is back where you left it. Guide.lua keeps the run current (ns.char.guide.run).
-- The first time a dungeon's step leads your guide, you're asked before you travel ("Asking first", below).

local _, ns = ...
local T = ns.T
local G, D, L = ns.Guide, ns.Data, ns.Log

local Run = {}
ns.Run = Run

local GROUP = "Dungeon quests"   -- the run's guide group: its saved place has a key of its own
local DEPTH = 8                  -- quests followed back from the dungeon's own
local NONE = {}
local COMMANDS = { "accept", "complete", "collect", "turnin" }
-- A step taken from a levelling guide keeps the tasks for the quests the run wants and what helps with
-- them (who to find, words, buttons, places); errands of that guide's own (a flight, the hearth, a
-- vendor) and other quests' tasks stay there, with whatever belongs to them.
local QUESTED = { accept = true, turnin = true, objective = true, collect = true, abandon = true }
local HELPS = { target = true, kill = true, scan = true, note = true, gossip = true, pickGossip = true, useItem = true,
	useSpell = true, macro = true, place = true, path = true, timer = true, noCheckbox = true, talk = true }

-- A run's phases, in order: { the step caption's words, the banner's label }.
local PHASES = { { "GETTING READY", "Ready" }, { "PICK UP", "Pick up" }, { "IN THE DUNGEON", "Dungeon" }, { "HAND IN", "Hand in" } }
local made = {}      -- short name -> the run's guide this session (false: none to make)
local blocks = {}    -- short name -> { guide, indexes, quests }: the dungeon's own steps
local fresh = false  -- a run just started: the banner comes in with its flourish (Banner)

local function Read(raw)
	if type(raw) == "table" then return raw end
	local make = type(raw) == "string" and loadstring("return " .. raw)
	local step = make and make()
	return type(step) == "table" and step or nil
end

-- The quests a step's `when` says must be handed in first: { quest, is = "done" }, alone, among `all`, or as
-- what `among` someone `needs`. (Never inside `no` or `any`: those don't say a quest is needed.)
local function Waits(when, into)
	if type(when) ~= "table" then return into end
	if when.quest ~= nil and when.is == "done" then
		for _, id in ipairs(type(when.quest) == "table" and when.quest or { when.quest }) do into[#into + 1] = id end
	end
	for _, member in ipairs(type(when.all) == "table" and when.all or NONE) do Waits(member, into) end
	if when.needs ~= nil then Waits(when.needs, into) end
	return into
end

-- The guides a run is made from: the one it stands in for first, then this character's chain, then any
-- other of its own (a careful route only on the hardcore route).
local function Sources(prefer)
	local out, seen = {}, {}
	local function Add(guide)
		if guide and not guide.run and not seen[guide] then
			seen[guide] = true
			out[#out + 1] = guide
		end
	end
	Add(prefer)
	for _, guide in ipairs(G.Chain()) do Add(guide) end
	for _, guide in ipairs(G.List()) do
		if not guide.careful or T.db.guide.hardcore then Add(guide) end
	end
	return out
end

-- Is this one of the dungeon's own steps (not one for when it isn't run).
local function Own(guide, index, short)
	for _, element in ipairs(G.Step(guide, index).elements) do
		if element.command == "dungeon" then
			local not_, name = element.args:match("^(!?)(%w+)")
			if name == short and not_ == "" then return true end
		end
	end
	return false
end

-- The dungeon's own steps, from the first guide that has them (every guide that has them has the same).
-- Read as text first: only steps that name the dungeon are parsed.
local function Block(short, sources)
	local known = blocks[short]
	if known then return known end
	local mark = 'dungeon="' .. short .. '"'
	for _, guide in ipairs(sources) do
		local indexes, quests = {}, {}
		for index, raw in ipairs(guide.raw) do
			if (type(raw) ~= "string" or raw:find(mark, 1, true)) and Own(guide, index, short) then
				indexes[#indexes + 1] = index
				for _, element in ipairs(G.Step(guide, index).elements) do
					local id = element.command == "accept" and G.lib.Ids(element)[1]
					if id then quests[#quests + 1] = id end
				end
			end
		end
		if #indexes > 0 then
			known = { guide = guide, indexes = indexes, quests = quests }
			blocks[short] = known
			return known
		end
	end
end

-- A step of a levelling guide, cut to the run's quests: nil when none of its quest tasks is for them.
local function Trim(raw, wanted)
	local step = Read(raw)
	if not step then return nil end
	local tasks, keep, any = {}, false, false
	for _, task in ipairs(step.tasks or NONE) do
		local mine
		if task.attached then
			mine = keep
		elseif QUESTED[task.type] then
			mine = task.type ~= "abandon" and type(task.quest) == "number" and wanted[task.quest] == true
			any = any or mine
			keep = mine
		else
			mine = HELPS[task.type] == true
			keep = mine
		end
		if mine then tasks[#tasks + 1] = task end
	end
	if not any then return nil end
	-- (Alone here: no side step, label or loop of the guide it came from.)
	return { when = step.when, at = step.at, tasks = tasks }
end

local function IdOf(guide, index)
	return guide.ids and guide.ids[index] or (guide.name .. "#" .. index)
end

-- Where a dungeon is: the zone of its first way in (Data/Dungeons.lua's fifth field, "map:xy;..."), or nil.
local function ZoneOf(dungeon)
	local info = ns.data.dungeonInfo and ns.data.dungeonInfo[dungeon.area]
	local door = info and tonumber(info:match("^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^(%d+)"))
	return door and ns.World.MapName(door) or nil
end

-- How risky a dungeon's way in is for you: "city" (by the other side's capital) or "land" (in their land), with
-- that zone's map and whose it is. nil when any way in is in your land or contested land (Data/Lands.lua).
local THEIRS = { A = "Alliance", H = "Horde" }
local function Danger(dungeon)
	local lands, capitals = ns.data.lands, ns.data.capitals or NONE
	local mine = L.Side()
	if not lands or not THEIRS[mine] then return nil end
	local doors = {}
	local info = ns.data.dungeonInfo and ns.data.dungeonInfo[dungeon.area]
	local places = info and info:match("^[^%^]*%^[^%^]*%^[^%^]*%^[^%^]*%^(.*)$")
	for map in (places or ""):gmatch("(%d+)[^:;]*:") do doors[#doors + 1] = tonumber(map) end
	local noted = dungeon.map and T.db.doors and T.db.doors[dungeon.map]
	if #doors == 0 and noted then doors[1] = noted[1] end
	local worst, at
	for _, map in ipairs(doors) do
		local whose = lands[map]
		if not whose or whose == mine then return nil end
		local how = capitals[map] and "city" or "land"
		-- (The safest way in is the one that counts.)
		if not worst or (worst == "city" and how == "land") then worst, at = how, map end
	end
	return worst, at, at and lands[at]
end

-- Where a quest's giver or taker stands (an NPC or an object, out in the world), as a step's place.
local function Spot(token)
	local kind = token and token.kind
	local thing = kind == "n" and D.Npc(token.id) or kind == "o" and D.Object(token.id) or nil
	if not thing then return nil, nil end
	for _, place in ipairs(thing.places or NONE) do
		if not place.dungeon and place.points[2] then
			return { map = place.map, x = place.points[1] / 100, y = place.points[2] / 100 }, thing
		end
	end
	return nil, thing
end

-- A step at whoever gives or takes a quest.
local function Visit(token, task)
	local at, thing = Spot(token)
	local tasks = {}
	if thing and token.kind == "n" then tasks[1] = { type = "target", who = { name = thing.name, npc = thing.id } } end
	tasks[#tasks + 1] = task
	return { at = at, tasks = tasks }
end

-- The steps of a quest no guide has, from the quest data: { kind, step } for the ones `has` lacks (pick it up, its
-- objectives, hand it in).
local function Written(quest, has)
	local out = {}
	if not has.accept then out[#out + 1] = { "accept", Visit(ns.Route.Usable(quest.starts), { type = "accept", quest = quest.id }) } end
	if not has.complete and not has.collect and #quest.goals > 0 then
		local tasks = {}
		for n = 1, #quest.goals do tasks[n] = { type = "objective", quest = quest.id, objective = n } end
		out[#out + 1] = { "objective", { when = { quest = quest.id, is = "active" }, tasks = tasks } }
	end
	if not has.turnin then out[#out + 1] = { "turnin", Visit(ns.Route.Usable(quest.ends), { type = "turnin", quest = quest.id }) } end
	return out
end

-- The run's guide for a dungeon, or nil when its guides have no steps for it. `prefer`: the guide it stands
-- in for, whose own copy of the dungeon's steps it takes.
local function Make(dungeon, prefer)
	local sources = Sources(prefer)
	local block = Block(dungeon.short, sources)
	if not block then return nil end
	local home = block.guide
	local taken = {}
	for _, id in ipairs(block.quests) do taken[id] = true end

	-- Where a quest is taken: the first guide with a step accepting it.
	local function Where(id)
		for _, guide in ipairs(sources) do
			local list = G.Asks(guide).accept[id]
			if list and #list > 0 then return guide, list end
		end
	end

	-- The quests to do first, in the order they are found, each after what it waits on: all of preGroup, one of
	-- preSingle (the first a guide takes, unless one is handed in already), and what the steps taking it wait on.
	-- after[id]: the quests found for it.
	local need, order, after = {}, {}, {}
	local side = L.Side()
	local Follow
	local function Want(id, depth, from)
		if taken[id] or depth > DEPTH or L.Done(id) then return end
		local quest = D.Quest(id)
		if quest and quest.side ~= "" and side ~= "" and quest.side ~= side then return end
		if from then
			after[from] = after[from] or {}
			table.insert(after[from], id)
		end
		if need[id] then return end
		need[id] = true
		Follow(id, depth)
		order[#order + 1] = id
	end
	function Follow(id, depth)
		local quest = D.Quest(id)
		if quest then
			for _, before in ipairs(quest.preGroup or NONE) do Want(before, depth + 1, id) end
			local single = quest.preSingle
			if single and #single > 0 then
				local open = false
				for _, before in ipairs(single) do
					if L.Done(before) then open = true end
				end
				if not open then
					local pick = single[1]
					for _, before in ipairs(single) do
						if Where(before) then
							pick = before
							break
						end
					end
					Want(pick, depth + 1, id)
				end
			end
		end
		local guide, list = Where(id)
		for _, index in ipairs(list or NONE) do
			local step = Read(guide.raw[index])
			for _, before in ipairs(Waits(step and step.when, {})) do Want(before, depth + 1, id) end
		end
	end
	for _, index in ipairs(block.indexes) do
		local step = Read(home.raw[index])
		for _, before in ipairs(Waits(step and step.when, {})) do Want(before, 0) end
	end
	for _, id in ipairs(block.quests) do Follow(id, 0) end

	-- Their steps, each from the first guide that has that kind for the quest, in the guides' order.
	local rank, seen, picked, has = {}, {}, {}, {}
	for at, guide in ipairs(sources) do rank[guide] = at end
	-- (The chain guides go before any other: a guide the character never plays stands last.)
	for at, guide in ipairs(G.Chain()) do rank[guide] = at - 1000 end
	for _, index in ipairs(block.indexes) do seen[IdOf(home, index)] = true end
	for _, id in ipairs(order) do
		has[id] = {}
		for _, command in ipairs(COMMANDS) do
			for _, guide in ipairs(sources) do
				local list = G.Asks(guide)[command][id]
				if list and #list > 0 then
					has[id][command] = true
					for _, index in ipairs(list) do
						local sid = IdOf(guide, index)
						if not seen[sid] then
							seen[sid] = true
							picked[#picked + 1] = { rank[guide], index, guide, sid, id }
						end
					end
					break
				end
			end
		end
	end
	table.sort(picked, function(a, b)
		if a[1] ~= b[1] then return a[1] < b[1] end
		return a[2] < b[2]
	end)
	local list = {}
	for _, each in ipairs(picked) do
		local step = Trim(each[3].raw[each[2]], need)
		if step then list[#list + 1] = { raw = step, id = each[4], quest = each[5] } end
	end

	-- What no guide has for a quest is written from the quest data, after the last step for it or for what it
	-- waits on.
	for _, id in ipairs(order) do
		local quest = D.Quest(id)
		local written = quest and Written(quest, has[id]) or NONE
		if #written > 0 then
			local mine = { [id] = true }
			for _, before in ipairs(after[id] or NONE) do mine[before] = true end
			local at = 0
			for position, entry in ipairs(list) do
				if mine[entry.quest] then at = position end
			end
			for n, step in ipairs(written) do
				table.insert(list, at + n, { raw = step[2], id = "run-" .. step[1] .. "-" .. id, quest = id })
			end
		end
	end

	-- Each step's phase (PHASES): what the dungeon's quests wait on is getting ready; its own steps are picking
	-- up, the dungeon or handing in, by what they ask, never going back a phase along the way.
	local raws, ids, phases = {}, {}, {}
	for _, entry in ipairs(list) do
		raws[#raws + 1] = entry.raw
		ids[#ids + 1] = entry.id
		phases[#raws] = 1
	end
	local phase = 2
	for _, index in ipairs(block.indexes) do
		raws[#raws + 1] = home.raw[index]
		ids[#ids + 1] = IdOf(home, index)
		local asks = {}
		local step = Read(home.raw[index])
		for _, task in ipairs(step and step.tasks or NONE) do asks[task.type] = true end
		phase = math.max(phase, asks.objective and 3 or asks.turnin and 4 or asks.accept and 2 or 3)
		phases[#raws] = phase
	end
	local low, high = ns.DungeonRange(dungeon)
	return { name = dungeon.name .. " quests", group = GROUP, cond = "", raw = raws, ids = ids, steps = {}, next = {},
		internal = true, run = dungeon.short, low = low, high = high, title = dungeon.name, map = dungeon.map,
		quests = block.quests, where = ZoneOf(dungeon), phases = phases }
end

-- Whether any of a dungeon's own quests is still to hand in.
function Run.Left(dungeon)
	local block = Block(dungeon.short, Sources(G.current))
	if not block then return false end
	for _, id in ipairs(block.quests) do
		if not L.Done(id) then return true end
	end
	return #block.quests == 0
end

-- What the run hands back to when it ends: "zone" (it began in zone mode) or "guide"; and the words for going there,
-- short (the banner's link) or whole (a menu's).
function Run.Back()
	local run = ns.char and ns.char.guide and ns.char.guide.run
	return type(run) == "table" and run.zone and "zone" or "guide"
end
function Run.BackWords(short)
	if Run.Back() == "zone" then return short and "Back to zone" or "Back to zone quests" end
	return short and "Back to guide" or "Back to my guide"
end

-- The dungeon being run (its short name), or nil.
function Run.Doing()
	local run = ns.char and ns.char.guide and ns.char.guide.run
	return type(run) == "table" and run.short or nil
end

-- The run's guide (Guide.lua asks while a run lasts): made once a session, and anew by Start.
function Run.Guide(run)
	local guide = made[run.short]
	if guide == nil then
		local dungeon = ns.Detour(run.short)
		guide = dungeon and Make(dungeon, G.ByKey(run.back)) or false
		if guide then G.Adopt(guide) end
		made[run.short] = guide
	end
	return guide or nil
end

-- Starts a run from its first step. A run started during another stands in for the same guide.
function Run.Start(short)
	local dungeon = ns.Detour(short)
	if not dungeon or not ns.char then return end
	if not Run.Left(dungeon) then
		T:Print(("you've done every quest for |cffffffff%s|r."):format(dungeon.name))
		return
	end
	local state = ns.char.guide
	local was = type(state.run) == "table" and state.run or nil
	local back = was and was.back or state.key
	local picked = was and was.picked or state.picked
	local guide = Make(dungeon, G.ByKey(back))
	if not guide then
		T:Print(("your guides have no steps for |cffffffff%s|r."):format(dungeon.name))
		return
	end
	made[short] = guide
	fresh = true
	-- From zone mode the card follows the run, and goes back to zone mode when it ends (Run.Ended).
	-- flipped: the run turned the guide on, for every character on the profile, and turns it off again.
	local zone = (was and was.zone) or (not ns.Following()) or nil
	local flipped = (was and was.flipped) or (zone and not T.db.guide.follow) or nil
	state.run = { short = short, back = back, picked = picked, zone = zone, flipped = flipped }
	if zone and not T.db.guide.follow then T.db.guide.follow = true end
	G.Run(guide)
	Shy:Fire("SHY_DUNGEON_RUN", dungeon.map)
	if zone and not was then ns.Apply() end
	T:Print(zone and ("showing every step for the quests of |cffffffff%s|r. The card goes back to your zone's quests once they're done.")
		:format(dungeon.name)
		or ("showing every step for the quests of |cffffffff%s|r. Your guide picks up where you left off once they're done.")
		:format(dungeon.name))
end

-- A run over (Guide.lua's EndRun): one started from zone mode puts the card back in it. `kept`: a guide was picked
-- or found again by hand, so the card stays on the guide.
function Run.Ended(run, kept)
	Shy:Fire("SHY_DUNGEON_RUN", nil)
	if kept or type(run) ~= "table" or not run.zone then return end
	C_Timer.After(0, function()
		if Run.Doing() or not T.db.guide.follow then return end
		if ns.Levelling() then
			T:SetQuestStyle("zone")
		elseif run.flipped then
			-- At the top level the style is this character's levelling help; the run's own switch goes back.
			T.db.guide.follow = false
			ns.Apply()
		end
	end)
end

-- Ends the run: back to the guide it stood in for, at its place. `kept`: the card stays on the guide even when the
-- run began in zone mode (Guide picked on the card's switch).
function Run.Stop(kept)
	if not Run.Doing() then return end
	local back = G.StopRun(kept == true)
	T:Print(back and ("back to |cffffffff%s|r."):format(back.name) or "back to your guide.")
end

-- The guide menu's entries (GuideWindow.lua's list): a dungeon of this faction's guides to run, each with its
-- levels, and the way back to your guide during one.
-- Whether there is a run to offer: a dungeon this faction's guides have quests for. (In zone mode too: a run
-- shows the guide while it lasts.)
function Run.Offered()
	return #ns.Detours() > 0
end

-- Each dungeon with its levels (or "all done", not to be picked), the one being run picked.
local function Dungeons(root)
	for _, dungeon in ipairs(ns.Detours()) do
		local low, high = ns.DungeonRange(dungeon)
		local left = Run.Left(dungeon)
		local levels = high > 0 and high ~= low and (low .. "-" .. high) or tostring(low)
		local entry = root:CreateRadio(("%s  (%s)"):format(dungeon.name, left and levels or "all done"),
			function() return Run.Doing() == dungeon.short end,
			function() Run.Start(dungeon.short) end)
		entry:SetEnabled(left)
	end
end

function Run.Menu(root)
	if not Run.Offered() then return end
	root:CreateDivider()
	local menu = root:CreateButton("Get dungeon quests")
	menu:SetSub("Every step for one dungeon's quests")
	Dungeons(menu)
	if Run.Doing() then root:CreateButton(Run.BackWords(), Run.Stop) end
end

-- The Dungeon mode's menu (the card's switch): the dungeons, then the way back.
function Run.Pick(owner)
	if not Run.Offered() then return end
	Shy.UI.ContextMenu(owner, function(root)
		root:CreateTitle("Get dungeon quests")
		Dungeons(root)
		if Run.Doing() then
			root:CreateDivider()
			root:CreateButton(Run.BackWords(), Run.Stop)
		end
		local maps = Shy.addons.Maps
		if maps and maps.Dungeon then
			root:CreateDivider()
			root:CreateButton("Bosses and loot", function() maps:Dungeon(Run.DoingMap()) end)
		end
	end)
end

-- The dungeon's theme. In Dungeon mode the whole card becomes the dungeon's: its colors (Theme.Scope: every part of
-- the card painted in the accent or the palette takes the dungeon's color instead), its look (UI.SetLook: the housing
-- the card wears) and its picture (the loading screen, as the dungeons step of setup shows it) behind the card's whole
-- header, fading out under it. At the header's foot the banner on that picture: DUNGEON RUN with a live light, the
-- dungeon's name, where it is and its levels, how many of its quests are done with a line along its foot filling as
-- they are (half lit for those in your log), and the way back (to the guide, or zone mode when the run began there).
-- Its words are lettered by the kit for the ground they stand on (UI.Letter). Hovered, it names each quest and where
-- it stands. A run started comes in with a sweep of light across the banner, the ready sound and the top's notice.
-- The run over, the card is the theme's again.
local UI = Shy.UI
local C = UI.colors
local Theme = Shy.Theme
local BANNER = { tall = 88, gap = 6, stripe = 3, pad = 12, line = 3, phaseGap = 6, shade = 0.75, dot = 6,
	sweep = 0.9, sheen = 70, intro = 0.35, breathe = 1.1, notice = 6, art = 0.62, fade = 46,
	ground = { 0.04, 0.04, 0.05 } }   -- ground: what the banner's words stand on, the picture under its shade
-- Each dungeon's color and look (Shy.Instances.Theme, by instance map), by the short name its guides use.
function Run.Theme(short)
	local dungeon = ns.Detour(short)
	return dungeon and Shy.Instances and Shy.Instances.Theme(dungeon.map) or nil
end

-- The card in the dungeon's theme (`guide` a run's), or back in the theme's own (nil). Asked at every layout: it
-- changes only what differs (a docked card's housing is the deck's, so its look is left alone).
local function Dress(card, guide, width, reach)
	-- (A run's dungeon keeps its theme: looked up once for its guide.)
	if guide and guide.theme == nil then guide.theme = Run.Theme(guide.run) or false end
	local theme = guide and guide.theme or nil
	local color = theme and theme.color
	if color then
		Theme.Scope(card, color[1], color[2], color[3])
	elseif Theme.Scoped(card) then
		Theme.Scope(card)
	end
	local look = theme and theme.look or nil
	if not card.docked and card.runLook ~= look then
		card.runLook = look
		UI.SetLook(card, look)
	end
	-- The header: the picture behind the card's top down to the banner's foot (`reach`), then fading out over FADE.
	-- Two pieces of one crop: `art` solid, `artFoot` the fade.
	local art, foot = card.runArt, card.runArtFoot
	local one = guide and guide.picture
	if not one then
		if art then
			art:Hide()
			foot:Hide()
		end
		return
	end
	if not art then
		art = card:CreateTexture(nil, "BACKGROUND", nil, 2)
		foot = card:CreateTexture(nil, "BACKGROUND", nil, 2)
		card.runArt, card.runArtFoot = art, foot
	end
	local said = ("%d|%d|%d"):format(one.file, width, reach)
	if art.said ~= said then
		art.said = said
		local total = reach + BANNER.fade
		-- The cut is 2:1: as wide as the header, cut down at its sides to the header's shape (or at top and foot
		-- when the header is the wider).
		local l, t, r, bottom = one.cut[1], one.cut[2], one.cut[3], one.cut[4]
		local shape = width / math.max(1, total)
		local across = math.min(1, shape / 2)
		local down = shape > 2 and 2 / shape or 1
		local middle = (l + r) / 2
		local left, right = middle - (r - l) * across / 2, middle + (r - l) * across / 2
		local top = t + (bottom - t) * (1 - down) * 0.45
		local base = top + (bottom - t) * down
		local split = top + (base - top) * (reach / total)
		for _, piece in ipairs({ art, foot }) do
			piece:SetTexture(one.file)
			piece:ClearAllPoints()
		end
		art:SetTexCoord(left, right, top, split)
		art:SetPoint("TOPLEFT", 1, -1)
		art:SetPoint("TOPRIGHT", -1, -1)
		art:SetHeight(reach - 1)
		art:SetVertexColor(1, 1, 1, BANNER.art)
		foot:SetTexCoord(left, right, split, base)
		foot:SetPoint("TOPLEFT", art, "BOTTOMLEFT")
		foot:SetPoint("TOPRIGHT", art, "BOTTOMRIGHT")
		foot:SetHeight(BANNER.fade)
		foot:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, BANNER.art))
	end
	art:Show()
	foot:Show()
end

local function Picture(map)
	for _, one in ipairs(ns.Dungeons and ns.Dungeons.Instances() or NONE) do
		if one.map == map then return one end
	end
end

-- A quest's state: "done", "carried" or "ahead".
local function State(id)
	if L.Done(id) then return "done" end
	if L.Has(id) then return "carried" end
	return "ahead"
end
local SAYS = { done = "Handed in", carried = "In your log", ahead = "To pick up" }

local Phase   -- (written below, with the banner it is for)

-- For other addons (the maps' dungeon journal), by instance map.
local function ByMap(map)
	for _, dungeon in ipairs(map and ns.Detours() or NONE) do
		if dungeon.map == map then return dungeon end
	end
end

-- A dungeon's own quests: { { id, name, state ("done" | "carried" | "ahead"), level, needs = { creature, ... } } },
-- needs the creatures a quest asks you to kill or that drop what it asks for; nil where your guides have none.
function Run.Quests(map)
	local dungeon = ByMap(map)
	local block = dungeon and Block(dungeon.short, Sources(G.current))
	if not block then return nil end
	local out = {}
	for _, id in ipairs(block.quests) do
		local quest = D.Quest(id)
		local needs = {}
		for _, goal in ipairs(quest and quest.goals or NONE) do
			if goal.kind == "c" then
				needs[#needs + 1] = goal.id
			elseif goal.kind == "k" then
				for _, npc in ipairs(goal.ids) do needs[#needs + 1] = npc end
			elseif goal.kind == "i" then
				local item = D.Item(goal.id)
				for _, source in ipairs(item and item.sources or NONE) do
					if source.kind == "n" and not D.Dropless(source.id, goal.id) then needs[#needs + 1] = source.id end
				end
			end
		end
		out[#out + 1] = { id = id, name = D.Name("quests", id) or ("Quest " .. id), state = State(id),
			level = quest and quest.level or nil, needs = needs }
	end
	return out
end

-- A dungeon's quests as a journal reads them, in the order the run takes them, and how the run stands:
--   { running (its run is on), phase (the run's phase now: "Pick up", "Dungeon" ..., or nil),
--     quests = { { id, name, state, level, xp, needs,
--                  giver, taker = { name, npc, at = { map, x, y } or nil (shares of the map, 0 to 1, as :Go
--                  takes them), inside (it stands in the dungeon) },
--                  first = { { id, name, state } } (what it waits on, the nearest last), next = { id, name } or nil,
--                  goals = { { text, done } } (a quest in your log: what it asks, as the game words it) } } }
-- nil where your guides have no quests for it.
function Run.Plan(map)
	local dungeon = ByMap(map)
	local rows = Run.Quests(map)
	if not (dungeon and rows) then return nil end
	local function Who(token)
		local at, thing = Spot(token)
		if not thing then return nil end
		local inside = false
		for _, place in ipairs(not at and thing.places or NONE) do
			if place.dungeon then inside = true end
		end
		-- (A step's place is in hundredths of the map; a place handed to another addon is a share of it.)
		if at then at = { map = at.map, x = at.x / 100, y = at.y / 100 } end
		return { name = thing.name, npc = token.kind == "n" and thing.id or nil, at = at, inside = inside }
	end
	local side = L.Side()
	local function Row(id)
		return { id = id, name = D.Name("quests", id) or ("Quest " .. id), state = State(id) }
	end
	-- What a quest waits on, back along its chain: every one of its group, the first of its singles that is yours.
	local function First(id, into, depth, seen)
		local quest = D.Quest(id)
		if not quest or depth > DEPTH then return into end
		local function Take(pre)
			pre = math.abs(pre)
			local before = D.Quest(pre)
			if seen[pre] or not before or (before.side ~= "" and side ~= "" and before.side ~= side) then return false end
			seen[pre] = true
			First(pre, into, depth + 1, seen)
			into[#into + 1] = Row(pre)
			return true
		end
		for _, pre in ipairs(quest.preGroup or NONE) do Take(pre) end
		for _, pre in ipairs(quest.preSingle or NONE) do
			if Take(pre) then break end
		end
		return into
	end
	local out = { running = Run.Doing() == dungeon.short, quests = rows }
	for _, row in ipairs(rows) do
		local quest = D.Quest(row.id)
		if quest then
			row.xp = quest.xp
			row.giver, row.taker = Who(ns.Route.Usable(quest.starts)), Who(ns.Route.Usable(quest.ends))
			row.first = First(row.id, {}, 1, { [row.id] = true })
			if quest.next and quest.next > 0 then row.next = Row(quest.next) end
		end
		row.goals = {}
		if row.state == "carried" then
			for _, goal in ipairs(C_QuestLog.GetQuestObjectives(row.id) or NONE) do
				if goal.text and not issecretvalue(goal.text) and goal.text ~= "" then
					row.goals[#row.goals + 1] = { text = goal.text, done = goal.finished == true }
				end
			end
		end
	end
	if out.running then
		local run = ns.char.guide.run
		local guide = Run.Guide(run)
		local phase = guide and Phase(guide)
		out.phase = phase and PHASES[phase] and PHASES[phase][2] or nil
	end
	return out
end

-- The instance map of the dungeon being run, or nil.
function Run.DoingMap()
	local dungeon = ns.Detour(Run.Doing())
	return dungeon and dungeon.map or nil
end

function Run.StartMap(map)
	local dungeon = ByMap(map)
	if dungeon then Run.Start(dungeon.short) end
end

-- Where a dungeon's way in is: { map, x, y } (shares of the map), from the data's first way in, else the door you
-- noted going in; nil where neither knows.
function Run.Door(map)
	for _, info in pairs(ns.data.dungeonInfo or NONE) do
		local instance, places = info:match("^[^%^]*%^[^%^]*%^[^%^]*%^(%d+)%^(.*)$")
		if tonumber(instance) == map then
			local zone, x, y = (places or ""):match("(%d+)[^:;]*:(%d%d%d%d)(%d%d%d%d)")
			if zone then return { map = tonumber(zone), x = tonumber(x) / 10000, y = tonumber(y) / 10000 } end
		end
	end
	local noted = T.db and T.db.doors and T.db.doors[map]
	if noted then return { map = noted[1], x = noted[2], y = noted[3] } end
end

-- The maps' journal, where it is: the dungeon's bosses and loot.
local function Journal()
	local maps = Shy.addons.Maps
	return maps and maps.Dungeon and maps or nil
end

local function Tip(banner)
	local guide = G.current
	if not (guide and guide.run) then return end
	local lines = UI.Lines()
	lines:AddLine("Dungeon run: " .. guide.title)
	local back = G.ByKey(ns.char.guide.run and ns.char.guide.run.back)
	local says
	if Run.Back() == "zone" then
		says = "Your zone's quests come back once these are done."
	elseif back then
		says = ("Your guide is on hold at %s. It picks up there once these are done."):format(back.name)
	else
		says = "Your guide is on hold. It picks up where you left it once these are done."
	end
	lines:AddLine(says, C.text[1], C.text[2], C.text[3], true)
	lines:AddLine(" ")
	for _, id in ipairs(guide.quests or NONE) do
		local state = State(id)
		local color = state == "done" and C.good or state == "carried" and C.text or C.dim
		lines:AddDoubleLine(D.Name("quests", id) or ("Quest " .. id), SAYS[state], color[1], color[2], color[3], C.dim[1], C.dim[2], C.dim[3])
	end
	UI.Tip(banner, lines, { side = "TOP", hints = { { "left", Run.BackWords() } } })
end

-- The phase the run is in: its main live step's (1 to #PHASES), or nil.
Phase = function(guide)
	for _, entry in ipairs(G.active) do
		if not entry.side then return guide.phases and guide.phases[entry.step.index] end
	end
	local waiting = G.waiting
	return waiting and guide.phases and guide.phases[waiting.step.index] or nil
end

local function Create(card)
	-- (No housing of its own: it stands on the card's header, the dungeon's picture behind both, Dress.)
	local b = CreateFrame("Button", nil, card)
	b:SetHeight(BANNER.tall)
	-- Dark on the left where the words are, clearing toward the right.
	b.shade = b:CreateTexture(nil, "ARTWORK", nil, 1)
	b.shade:SetPoint("TOPLEFT", 1, -1)
	b.shade:SetPoint("BOTTOMRIGHT", -1, 1)
	b.shade:SetColorTexture(1, 1, 1, 1)
	b.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, BANNER.shade), CreateColor(0, 0, 0, 0.25))
	b.stripe = b:CreateTexture(nil, "OVERLAY")
	b.stripe:SetPoint("TOPLEFT", 1, -1)
	b.stripe:SetPoint("BOTTOMLEFT", 1, 1)
	b.stripe:SetWidth(BANNER.stripe)
	UI.Paint(b.stripe, Shy.Theme.Accent)
	-- The live light before DUNGEON RUN, breathing while the run lasts.
	b.dot = b:CreateTexture(nil, "OVERLAY")
	b.dot:SetSize(BANNER.dot, BANNER.dot)
	b.dot:SetPoint("TOPLEFT", BANNER.pad, -11)
	UI.Paint(b.dot, Shy.Theme.Accent)
	local breathe = b.dot:CreateAnimationGroup()
	breathe:SetLooping("BOUNCE")
	local fade = breathe:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.3)
	fade:SetDuration(BANNER.breathe)
	fade:SetSmoothing("IN_OUT")
	b.breathe = breathe
	-- The words stand on the picture: lettered by the kit for that ground (UI.Letter), its ink, outline and shadow
	-- what reads there; the accent's words and the link keep their own ink, a shadow under them at the least.
	b.kicker = UI.Letter(UI.Text(b, "DUNGEON RUN", 10, true, Shy.Theme.Accent), { least = "shadow" })
	b.kicker:SetPoint("LEFT", b.dot, "RIGHT", 5, 0)
	b.title = UI.Letter(UI.Text(b, "", 18, true, C.head), { least = "shadow", ground = BANNER.ground })
	b.title:SetPoint("TOPLEFT", BANNER.pad, -23)
	b.title:SetPoint("RIGHT", -BANNER.pad, 0)
	b.title:SetJustifyH("LEFT")
	b.title:SetWordWrap(false)
	-- Under the name: where it is and its levels; at the foot's right, how many of its quests are done; along the
	-- foot, a line filling as they are (half lit for those in your log).
	b.sub = UI.Letter(UI.Text(b, "", 11, true, C.text), { least = "shadow", ground = BANNER.ground })
	b.sub:SetPoint("TOPLEFT", BANNER.pad, -46)
	b.sub:SetWordWrap(false)
	b.count = UI.Letter(UI.Text(b, "", 11, true, C.head), { least = "shadow", ground = BANNER.ground })
	b.count:SetPoint("TOPRIGHT", -BANNER.pad, -46)
	b.count:SetWordWrap(false)
	-- The run's phases along the foot (Getting ready, Pick up, Dungeon, Hand in): a bar and its word each, the one
	-- you're in lit, those behind you half lit, those ahead dim. Laid across in Banner.
	b.phases = {}
	for i, phase in ipairs(PHASES) do
		local bar = b:CreateTexture(nil, "OVERLAY")
		bar:SetHeight(BANNER.line)
		local word = UI.Letter(UI.Text(b, phase[2]:upper(), 9, true, C.dim), { least = "shadow" })
		word:SetWordWrap(false)
		word:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 3)
		b.phases[i] = { bar = bar, word = word }
	end
	-- The way back, at the top right: to the guide, or to zone mode when the run began there.
	b.back = CreateFrame("Button", nil, b)
	b.back.label = UI.Letter(UI.Text(b.back, "", 10, true, C.dim), { least = "shadow" })
	b.back.label:SetPoint("CENTER")
	b.back:SetPoint("TOPRIGHT", -6, -5)
	b.back:SetScript("OnEnter", function(self) UI.Ink(self.label, C.hot) end)
	b.back:SetScript("OnLeave", function(self) UI.Ink(self.label, C.dim) end)
	b.back:SetScript("OnClick", function() Run.Stop() end)
	-- Beside it, the dungeon's bosses and loot (the maps' journal, where it is).
	b.journal = CreateFrame("Button", nil, b)
	b.journal.label = UI.Letter(UI.Text(b.journal, "Bosses and loot", 10, true, C.dim), { least = "shadow" })
	b.journal.label:SetPoint("CENTER")
	b.journal:SetPoint("RIGHT", b.back, "LEFT", -8, 0)
	b.journal:SetScript("OnEnter", function(self) UI.Ink(self.label, C.hot) end)
	b.journal:SetScript("OnLeave", function(self) UI.Ink(self.label, C.dim) end)
	b.journal:SetScript("OnClick", function()
		local maps, guide = Journal(), G.current
		if maps and guide and guide.run then maps:Dungeon(guide.map) end
	end)
	b:SetScript("OnEnter", function(self) Tip(self) end)
	b:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	b:SetScript("OnClick", function() Run.Stop() end)

	-- The flourish of a run started: the banner fades in, and a band of light sweeps across its picture.
	b:SetClipsChildren(true)
	b.intro = b:CreateAnimationGroup()
	local rise = b.intro:CreateAnimation("Alpha")
	rise:SetFromAlpha(0)
	rise:SetToAlpha(1)
	rise:SetDuration(BANNER.intro)
	b.sheen = CreateFrame("Frame", nil, b)
	b.sheen:SetSize(BANNER.sheen, BANNER.tall)
	b.sheen:SetPoint("RIGHT", b, "LEFT", 0, 0)
	b.sheen:SetFrameLevel(b:GetFrameLevel() + 2)
	for i, from in ipairs({ { 0, 0.42 }, { 0.42, 0 } }) do
		local half = b.sheen:CreateTexture(nil, "OVERLAY")
		half:SetColorTexture(1, 1, 1, 1)
		half:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, from[1]), CreateColor(1, 1, 1, from[2]))
		half:SetSize(BANNER.sheen / 2, BANNER.tall)
		half:SetPoint(i == 1 and "LEFT" or "RIGHT")
	end
	b.sheen:Hide()
	b.sweep = b.sheen:CreateAnimationGroup()
	b.sweep.move = b.sweep:CreateAnimation("Translation")
	b.sweep.move:SetDuration(BANNER.sweep)
	b.sweep.move:SetSmoothing("IN_OUT")
	b.sweep:SetScript("OnFinished", function() b.sheen:Hide() end)
	return b
end

-- A run started: in it comes, its name on the top's notice, with the ready sound.
local function Flourish(b, guide, width)
	b.intro:Play()
	b.sheen:Show()
	b.sweep.move:SetOffset(width + BANNER.sheen, 0)
	b.sweep:Play()
	PlaySound(SOUNDKIT.READY_CHECK)
	if Shy.Notices and Shy.Notices.Voice then
		Shy.Notices.Voice("shyquest-run", { priority = 5, hold = BANNER.notice, icon = "Interface\\AddOns\\ShyQuest\\Media\\ShyQuest",
			title = guide.title, under = "Dungeon run" })
	end
end

-- Lays the banner on the card at `y` (Card.lua asks while it lays its top out), `width` wide. Returns the height it
-- takes, 0 when there is no run.
function Run.Banner(card, y, width)
	local guide = G.current
	local b = card.runBanner
	if not (guide and guide.run and ns.Following()) then
		Dress(card, nil, width)
		if b then
			b:Hide()
			b.breathe:Stop()
		end
		return 0
	end
	if guide.picture == nil then
		local one = Picture(guide.map)
		guide.picture = one and one.file > 0 and one.cut and one or false
	end
	Dress(card, guide, width, y + BANNER.tall)
	if not b then
		b = Create(card)
		card.runBanner = b
	end
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", 0, -y)
	b:SetPoint("TOPRIGHT", 0, -y)
	b.title:SetText(guide.title)
	local low, high = guide.low or 0, guide.high or 0
	local levels = high > 0 and high ~= low and ("levels %d-%d"):format(low, high) or ("level %d"):format(low)
	b.sub:SetText(guide.where and (guide.where .. "  \194\183  " .. levels) or levels)
	local done, carried, quests = 0, 0, guide.quests or NONE
	for _, id in ipairs(quests) do
		local state = State(id)
		if state == "done" then done = done + 1 elseif state == "carried" then carried = carried + 1 end
	end
	b.count:SetText(carried > 0 and ("%d of %d done  \194\183  %d in log"):format(done, #quests, carried)
		or ("%d of %d quests done"):format(done, #quests))
	local now = Phase(guide) or 1
	-- (Laid across again only for a new width, painted again only for a new phase: the theme keeps what was worn.)
	if b.laidWidth ~= width then
		b.laidWidth = width
		local each = (width - BANNER.pad * 2 - BANNER.phaseGap * (#PHASES - 1)) / #PHASES
		for i, phase in ipairs(b.phases) do
			phase.bar:ClearAllPoints()
			phase.bar:SetPoint("BOTTOMLEFT", BANNER.pad + (i - 1) * (each + BANNER.phaseGap), 8)
			phase.bar:SetWidth(math.max(1, each))
		end
	end
	if b.phase ~= now then
		for i, phase in ipairs(b.phases) do
			if i == now then
				UI.Paint(phase.bar, Shy.Theme.Accent)
				UI.Ink(phase.word, Shy.Theme.Accent)
			elseif i < now then
				UI.Paint(phase.bar, Shy.Theme.Accent, 0.45)
				UI.Ink(phase.word, C.text)
			else
				UI.Paint(phase.bar, C.dim, 0.3)
				UI.Ink(phase.word, C.dim)
			end
		end
	end
	b.phase = now
	b.back.label:SetText(Run.BackWords(true))
	b.back:SetSize(b.back.label:GetStringWidth() + 8, 16)
	b.journal:SetShown(Journal() ~= nil)
	b.journal:SetSize(b.journal.label:GetStringWidth() + 8, 16)
	b:Show()
	if not b.breathe:IsPlaying() then b.breathe:Play() end
	if fresh then
		fresh = false
		Flourish(b, guide, width)
	end
	return BANNER.tall + BANNER.gap
end

-- The card's caption for a step of the run (`index`): its phase and the dungeon ("PICK UP  ·  THE DEADMINES").
function Run.Caption(guide, index)
	if not (guide and guide.run) then return nil end
	local phase = PHASES[guide.phases and index and guide.phases[index] or 0]
	return (phase and phase[1] or "DUNGEON RUN") .. "  \194\183  " .. (guide.title or guide.name):upper()
end

-- Asking first. A dungeon's first step can be across the world. The first time one leads the guide, a small
-- window asks before you travel:
--   Do it now        starts the run (Dungeon mode)
--   As I get there   its steps stay in the guide and lead only when you're near them (Guide.lua's Away)
--   Later            puts it off for two hours, then asks again
--   Skip it          drops its quests for good
-- Closing it is Later. The answer is kept per dungeon and character (ns.char.asked: "along" or "skip").
-- Never asked in combat, on a flight, dead, in an instance or during a run.
local ASK = { width = 360, pad = 14, row = 26, says = 118, top = 40, later = 2, sign = 20 }
local ask                    -- the window, made on first use
local asking                 -- the dungeon being asked about
local pending = false        -- waiting for a quiet moment

local function Asked()
	ns.char.asked = ns.char.asked or {}
	return ns.char.asked
end

-- Whether a dungeon's steps wait until you're near them (Guide.lua asks).
function ns.DungeonAlong(short)
	local asked = ns.char and ns.char.asked
	return asked ~= nil and asked[short] == "along"
end

-- The dungeon the guide's leading step is for, or nil. Never during a run.
local function Leading()
	local guide = G.current
	if not guide or guide.run or not ns.Following() then return nil end
	local entry = G.active[1]
	return entry and ns.Detour(G.Dungeon(entry.step.index, entry.guide)) or nil
end

-- how: "now", "along", "skip", or "later" (also when closed).
local function Answer(how)
	local dungeon = asking
	if not dungeon then return end
	asking = nil
	ask:Hide()
	if how == "now" then
		-- (If the run is stopped early, what's left waits until you're near it.)
		Asked()[dungeon.short] = "along"
		Run.Start(dungeon.short)
	elseif how == "along" then
		Asked()[dungeon.short] = "along"
		T:Print(("|cffffffff%s|r is in your guide. Its steps come up when you're near them."):format(dungeon.name))
		ns.Apply()
	elseif how == "skip" then
		Asked()[dungeon.short] = "skip"
		ns.Snooze(dungeon, "off")
	else
		ns.Snooze(dungeon, "hours")
	end
end

local function CreateAsk()
	ask = CreateFrame("Frame", "ShyQuestDungeonAsk", UIParent)
	ask:SetWidth(ASK.width)
	ask:SetPoint("TOP", UIParent, "TOP", 0, -150)
	ask:SetFrameStrata("HIGH")
	ask:SetToplevel(true)
	ask:EnableMouse(true)
	ask:Hide()
	ask.head = UI.Head(ask, { size = "window", title = "", close = function() Answer("later") end })
	-- (The text sits on a frame above the body. The body's sheet would cover it.)
	local face = CreateFrame("Frame", nil, ask)
	face:SetAllPoints(ask)
	local inner = ASK.width - ASK.pad * 2
	ask.facts = UI.Text(face, "", 10, false, C.dim)
	-- A warning when the way in is in the other side's land: red by their capital, gold elsewhere in their land.
	ask.warnSign = face:CreateTexture(nil, "OVERLAY")
	UI.GlyphArt(ask.warnSign, "kill")
	ask.warn = UI.Text(face, "", 12, false, C.alert)
	ask.warn:SetWidth(inner - ASK.sign)
	ask.warn:SetJustifyH("LEFT")
	ask.warn:SetWordWrap(true)
	ask.warnSign:SetPoint("TOPRIGHT", ask.warn, "TOPLEFT", -6, 0)
	ask.say = UI.Text(face, "Want to do this dungeon?", 12, false, C.text)
	-- Four lines to pick from, each lit under the mouse: what it's called, then what it does.
	local function Choice(label, says, how)
		local row = CreateFrame("Button", nil, ask)
		row:SetSize(inner, ASK.row)
		row.light = UI.RowLight(row)
		row.label = UI.Text(row, label, 13, true, C.head)
		row.label:SetPoint("LEFT", UI.ROW_INSET, 0)
		row.says = UI.Text(row, says, 11, false, C.dim)
		row.says:SetPoint("LEFT", ASK.says, 0)
		row:SetScript("OnEnter", function(self) self.light:Set(true) end)
		row:SetScript("OnLeave", function(self) self.light:Set(false) end)
		row:SetScript("OnClick", function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			Answer(how)
		end)
		return row
	end
	ask.now = Choice("Do it now", "Drop what you're doing and go.", "now")
	ask.along = Choice("As I get there", "Its steps come up when you're near.", "along")
	ask.later = Choice("Later", "Ask again in 2 hours.", "later")
	ask.skip = Choice("Skip it", "Leave it out of your guide.", "skip")
end

local function ShowAsk(dungeon)
	if not ask then CreateAsk() end
	asking = dungeon
	ask.head.title:SetText(dungeon.name)
	-- Levels, zone (if known) and quests left.
	local low, high = ns.DungeonRange(dungeon)
	local facts = { high > 0 and high ~= low and ("LEVELS %d-%d"):format(low, high) or ("LEVEL %d"):format(low) }
	local where = ZoneOf(dungeon)
	if where then facts[#facts + 1] = where:upper() end
	local block, left = Block(dungeon.short, Sources(G.current)), 0
	for _, id in ipairs(block and block.quests or NONE) do
		if not L.Done(id) then left = left + 1 end
	end
	if left > 0 then facts[#facts + 1] = left == 1 and "1 QUEST" or (left .. " QUESTS") end
	ask.facts:SetText(table.concat(facts, "  \194\183  "))
	local body, y = UI.Body(ask), ASK.top
	local function Put(text, gap, indent)
		text:ClearAllPoints()
		text:SetPoint("TOPLEFT", body, "TOPLEFT", ASK.pad + (indent or 0), -y)
		y = y + math.max(12, text:GetStringHeight()) + gap
	end
	Put(ask.facts, 6)
	local danger, _, whose = Danger(dungeon)
	ask.warn:SetShown(danger ~= nil)
	ask.warnSign:SetShown(danger ~= nil)
	ask.danger = danger
	if danger then
		-- (Its zone is on the line above.)
		local side = THEIRS[whose]
		local color = danger == "city" and C.bad or C.alert
		ask.warn:SetText(danger == "city"
			and ("The way in is by the %s capital. Its guards will attack you."):format(side)
			or ("It's in %s land. Watch out for their guards and players."):format(side))
		UI.Ink(ask.warn, color)
		Shy.Theme.Tint(ask.warnSign, color, 1)
		Put(ask.warn, 8, ASK.sign)
	end
	Put(ask.say, 10)
	for _, row in ipairs({ ask.now, ask.along, ask.later, ask.skip }) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", body, "TOPLEFT", ASK.pad, -y)
		row.light:Set(false)
		y = y + ASK.row
	end
	UI.BodyFit(ask, ASK.width, y + ASK.pad - 4)
	ask:Show()
end

-- Asks about the leading dungeon if it hasn't been asked yet. Waits for a quiet moment.
local function Ask()
	pending = false
	local dungeon = Leading()
	if not dungeon or asking or IsInInstance() then return end
	-- (One you skipped leads again only if you put it back yourself. Then it's a new question.)
	local was = Asked()[dungeon.short]
	if was == "skip" then Asked()[dungeon.short] = nil elseif was then return end
	local other = _G.ShyQuestOffGuide   -- (the other guide question opens in the same spot)
	if InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player") or (other and other:IsShown()) then
		pending = true
		return C_Timer.After(ASK.later, Ask)
	end
	ShowAsk(dungeon)
end

ns.OnRoute(function(rebuilt)
	if not rebuilt then return end
	if asking then
		-- (It no longer leads: put off from the menu, done, or the guide changed.)
		local dungeon = Leading()
		if not dungeon or dungeon.short ~= asking.short then
			asking = nil
			ask:Hide()
		end
	end
	if not asking and not pending then Ask() end
end, true)

-- /shy quest dungeon [name]: starts the run of a dungeon named in part ("dead", "dm"); "stop" ends one; no
-- name lists them.
function Run.Command(words)
	words = strtrim(words or ""):lower()
	if words == "stop" then
		if Run.Doing() then Run.Stop() else T:Print("no dungeon run to stop.") end
		return
	end
	local dungeons = ns.Detours()
	if words ~= "" then
		for _, dungeon in ipairs(dungeons) do
			if dungeon.short:lower() == words or dungeon.name:lower():find(words, 1, true) then
				Run.Start(dungeon.short)
				return
			end
		end
	end
	local names = {}
	for _, dungeon in ipairs(dungeons) do names[#names + 1] = dungeon.name end
	T:Print(#names > 0 and ("dungeons with quests in your guides: %s. Type |cff888888/shy quest dungeon <name>|r."):format(table.concat(names, ", "))
		or "your guides have no dungeon quests.")
end
