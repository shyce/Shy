-- Options page: the card as a live preview, then steps, tracker, XP, guide and pins.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function GetCard(key) return function() return T.db.card[key] end end
local function SetCard(key) return function(v) T.db.card[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Carded() return T.db.card.shown end
local function Offering() return T.db.pickups end
local function Pinned() return T.db.mapPins or T.db.minimapPins end

local function HiddenCount()
	local count = 0
	for _ in pairs(ns.char.hidden) do count = count + 1 end
	return count
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Apply() end)
	local preview, hidden

	local function Build()
		UI.PageHeader(panel, T)

		-- Everything below the preview hangs from this, so a tall card pushes it down.
		local body = CreateFrame("Frame", nil, panel)
		body:SetSize(1, 1)
		body:SetPoint("TOPLEFT", 0, -372)
		preview = ns.CreateCard(panel, function(_, height)
			body:SetPoint("TOPLEFT", 0, -math.max(372, 112 + height + 24))
		end)
		preview:SetPoint("TOPLEFT", LEFT, -112)

		local switchLabel = UI.Text(panel, "Show the quest window", 15, true)
		switchLabel:SetPoint("TOPLEFT", RIGHT, -114)
		local switch = group:Switch(panel, "Show the quest window", GetCard("shown"), SetCard("shown"),
			{ desc = "Your guide and your tracked quests in one window, in the order you walk them. It takes the place of the game's quest tracker. Click a step to pin its details, drag the window to move it, right-click for more." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, -142)

		At(group:Slider(panel, "Steps listed", 1, 6, 1, GetCard("rows"), SetCard("rows"),
			{ width = COL, enabled = Carded,
			desc = "How many steps the window lists. Quests you track are always listed, and so are your guide's steps." }), panel, RIGHT, -176)
		At(group:Checkbox(panel, "Hide in combat", GetCard("hideInCombat"), SetCard("hideInCombat"),
			{ enabled = Carded, desc = "Hides the card while you are in combat." }), panel, RIGHT, -228)
		At(group:Checkbox(panel, "Flight timer", GetCard("flying"), SetCard("flying"),
			{ enabled = Carded, desc = "On a flight path, the card shows your destination and the time left. A route you haven't flown shows an estimate until it has been timed once." }), panel, RIGHT, -254)

		local panel = body
		local y = 0
		At(UI.Header(panel, "Steps", COL), panel, LEFT, y)
		At(group:Checkbox(panel, "Available quests", Get("pickups"), Set("pickups"),
			{ desc = "Quest givers with a quest for you become steps and get a pin." }), panel, LEFT, y - 32)
		At(group:Checkbox(panel, "Include low-level quests", Get("lowLevel"), Set("lowLevel"),
			{ enabled = Offering, desc = "Also lists quests that give a fifth of their XP or less at your level." }), panel, LEFT + 16, y - 58)
		At(group:Checkbox(panel, "Include repeatable quests", Get("repeatable"), Set("repeatable"),
			{ enabled = Offering, desc = "Also lists repeatable turn-ins, mostly for reputation." }), panel, LEFT + 16, y - 84)
		At(group:Dropdown(panel, "Suggest zones", {
			{ value = "short",  text = "When steps run low" },
			{ value = "always", text = "Always" },
			{ value = "never",  text = "Never" },
		}, Get("zones"), Set("zones"), { width = COL,
			desc = "Adds the zones with the most quests for your character, nearest first, to the end of the card and as numbered pins on the world map. Click one to head there." }), panel, LEFT, y - 116)
		hidden = UI.Button(panel, "", COL, function()
			ns.UnhideAll()
			ns.Apply()
		end)
		At(hidden, panel, LEFT, y - 178)
		local hint = UI.Text(panel, "Right-click a step to hide its quest, for example one this server doesn't have.", 12, false, UI.colors.dim)
		hint:SetWidth(COL)
		At(hint, panel, LEFT, y - 210)

		At(UI.Header(panel, "Quest tracker", COL), panel, RIGHT, y)
		At(group:Checkbox(panel, "Quest details on hover", Get("tips"), Set("tips"),
			{ desc = "Hovering a tracked quest shows what each objective needs, what drops it and how often, the distance, and where to turn in." }), panel, RIGHT, y - 32)
		At(group:Checkbox(panel, "Highlight the next quest", Get("marker"), Set("marker"),
			{ desc = "A glow in your accent color behind the marker of the quest to do next." }), panel, RIGHT, y - 58)
		At(group:Checkbox(panel, "Quest levels in titles", function() return ns.GetTitleSetting("level") end,
			function(v) ns.SetTitleSetting("level", v) end,
			{ desc = "Shows the level, like [12], before each quest name. The world map's filter menu has the same setting." }), panel, RIGHT, y - 84)
		At(group:Checkbox(panel, "Color titles by difficulty", function() return ns.GetTitleSetting("color") end,
			function(v) ns.SetTitleSetting("color", v) end,
			{ desc = "Red, orange, yellow, green and gray, as in the quest log." }), panel, RIGHT, y - 110)
		At(group:Dropdown(panel, "Tracked quests", {
			{ value = "zone",  text = "Current zone, in route order" },
			{ value = "order", text = "My tracked quests, in route order" },
			{ value = "off",   text = "Default" },
		}, Get("track"), Set("track"), { width = COL,
			desc = "Current zone: tracks the quests for your zone, your guide's current steps and the quest you picked, in route order. Other quests come back when you reach their zone. A quest you track or untrack yourself stays that way.\n\nMy tracked quests: only reorders what you track.\n\nNothing changes in combat." }), panel, RIGHT, y - 142)
		At(group:Checkbox(panel, "Gray quests in zone mode", Get("grayZone"), Set("grayZone"), { enabled = function() return T.db.track == "zone" end,
			desc = "Zone mode leaves out quests too low-level to give XP: they aren't tracked or listed, and don't count toward zones to visit. A finished one is still shown, to hand in. Turn this on to have them back." }), panel, RIGHT, y - 196)
		local function GetLook(key) return function() return T.db.look[key] end end
		local function SetLook(key) return function(v) T.db.look[key] = v end end
		At(group:Checkbox(panel, "Restyle the tracker", GetLook("on"), SetLook("on"),
			{ desc = "Gives the game's tracker the quest window's panel, font and markers, for when it shows: with the quest window off, or while it tracks something besides quests. Its opacity follows Background in /shy." }), panel, RIGHT, y - 226)

		y = y - 318
		-- Leveling: ShyXP's numbers on the steps. Without ShyXP there are none, and no section.
		if ns.XP.Loaded() then
			local function GetXP(key) return function() return T.db.xp[key] end end
			local function SetXP(key) return function(v) T.db.xp[key] = v end end
			At(UI.Header(panel, "Leveling", 576), panel, LEFT, y)
			At(group:Checkbox(panel, "XP on steps", GetXP("steps"), SetXP("steps"),
				{ desc = "A turn-in shows its XP and whether it levels you. A guide's grind step shows how much XP is left and how long at your pace. (Your level, XP bar and time to level stand at the bottom of the card until you reach the top level. Hover them for the breakdown, Shift-click to share.)" }), panel, LEFT, y - 32)
			y = y - 72
		end

		-- These only store settings; GuideTalk.lua acts on them.
		local function Giving() return T.db.giver.auto end
		local function GetGiver(key) return function() return T.db.giver[key] end end
		local function SetGiver(key) return function(v) T.db.giver[key] = v end end
		At(UI.Header(panel, "At a quest giver", 576), panel, LEFT, y)
		At(group:Checkbox(panel, "Auto accept and turn in", GetGiver("auto"), SetGiver("auto"),
			{ desc = "Talking to a quest giver accepts their quests and turns in your finished ones. Left to you: reward choices, quests that cost gold or materials, escorts, and quests your guide skips. Hold Shift while talking to do it all yourself." }), panel, LEFT, y - 32)
		At(group:Checkbox(panel, "Accept new quests", GetGiver("accept"), SetGiver("accept"),
			{ enabled = Giving, desc = "Accepts the quests a quest giver offers." }), panel, LEFT + 16, y - 58)
		At(group:Checkbox(panel, "Turn in finished quests", GetGiver("turnIn"), SetGiver("turnIn"),
			{ enabled = Giving, desc = "Turns in a finished quest and takes its reward. A choice of reward is left to you." }), panel, LEFT + 16, y - 84)
		At(group:Checkbox(panel, "Include gray quests", GetGiver("gray"), SetGiver("gray"),
			{ enabled = Giving, desc = "Also accepts quests too low-level to give XP." }), panel, RIGHT, y - 58)
		At(group:Checkbox(panel, "Include repeatable quests", GetGiver("again"), SetGiver("again"),
			{ enabled = Giving, desc = "Also turns in repeatable quests that take items from you each time." }), panel, RIGHT, y - 84)

		y = y - 126
		-- At the top level the guide is this character's levelling help (T:SetQuestStyle), as on the card.
		local function Guided() return ns.Following() end
		local function GetGuide(key) return function() return T.db.guide[key] end end
		local function SetGuide(key) return function(v) T.db.guide[key] = v end end
		At(UI.Header(panel, "Leveling guide", 576), panel, LEFT, y)
		At(group:Checkbox(panel, "Follow the leveling guide", Guided, function(v) T:SetQuestStyle(v and "guide" or "zone") end,
			{ desc = "Step-by-step guides for levels 1 to 30, every starting zone, both factions. The guide's steps lead the card, with nearby quests after them. Your guide and your place in it are worked out from the quests you've done." }), panel, LEFT, y - 32)
		At(group:Checkbox(panel, "Whole guide on the card",
			function() return ns.char.guideFull == true end, function(v) ns.ToggleGuideWindow(v) end,
			{ desc = "Expands the card into the whole guide: your progress, every step, and the list of guides. The chevron at the card's top left, the console's Guide tab and /shyquest guide do the same." }), panel, LEFT, y - 62)
		At(group:Checkbox(panel, "Hardcore route", GetGuide("hardcore"), SetGuide("hardcore"),
			{ enabled = Guided, desc = "Uses the steps written for hardcore: fewer dangerous quests, and warnings about hostile elites well above you. Also adds a full hardcore route to the card's list of guides." }), panel, LEFT, y - 96)
		At(group:Checkbox(panel, "I don't use the AH", GetGuide("selfFound"), SetGuide("selfFound"),
			{ enabled = Guided, desc = "Skips steps that have you buy quest items from the AH and shows the ones written for playing without it." }), panel, LEFT, y - 122)
		At(group:Checkbox(panel, "Include group quests", GetGuide("group"), SetGuide("group"),
			{ enabled = Guided, desc = "Keeps the guide's steps for quests that need a group. Right-click such a quest on the card to ask chat for help, or to find a group through ShyGroup." }), panel, RIGHT, y - 32)
		At(group:Slider(panel, "XP rate", 1, 3, 0.1, GetGuide("xprate"), SetGuide("xprate"),
			{ width = COL, enabled = Guided, format = function(v) return ("%.1fx"):format(v) end,
			desc = "Your server's XP rate. Above 1x, steps only worth doing at the normal rate are skipped." }), panel, RIGHT, y - 64)
		-- Where "Ask for help" goes first: say, yell, your group, the guild or a channel you are in. The one picked
		-- last on the card is remembered here too.
		local function Chats()
			local items = {}
			for _, chat in ipairs(UI.Chats()) do items[#items + 1] = { value = chat.key, text = chat.label } end
			local have = T.db.help.chat
			for _, item in ipairs(items) do
				if item.value == have then return items end
			end
			local names = { SAY = SAY, YELL = YELL, GROUP = PARTY, GUILD = GUILD }
			items[#items + 1] = { value = have, text = (names[have] or (have:gsub("(%l)(%u)", "%1 %2"))) .. "  (not joined)" }
			return items
		end
		local help = group:Dropdown(panel, "Ask for help in", Chats(), function() return T.db.help.chat end,
			function(v) T.db.help.chat = v end, { width = COL,
			desc = "The chat listed first when you ask for help with a quest from the card. Whichever chat you pick from that list becomes the new default." })
		-- (SetItems refreshes the dropdown itself: the list is read again only on a refresh from outside.)
		local refresh, listing = help.Refresh, false
		function help:Refresh()
			if listing then return refresh(self) end
			listing = true
			self:SetItems(Chats())
			listing = false
		end
		At(help, panel, RIGHT, y - 100)
		local credit = UI.Text(panel, "The guides end at level 30, the beta's cap. After that the card lists the nearest turn-in, pickup or objective.", 12, false, UI.colors.dim)
		credit:SetWidth(COL)
		At(credit, panel, RIGHT, y - 154)

		At(group:Checkbox(panel, "Leveling help at max level", function() return ns.char.topHelp == true end,
			function(v) ns.SetTopHelp(v) end,
			{ enabled = ns.AtTop, desc = "At max level this character keeps quests to pick up and errands, not just the quests you have." }), panel, LEFT, y - 148)

		y = y - 26
		-- These only store settings; the files acting on them may not be loaded yet.
		local function Buttoned() return Guided() and T.db.guide.buttons end
		At(UI.Text(panel, "Current step", 13, true, UI.colors.head), panel, LEFT, y - 170)
		At(group:Checkbox(panel, "Use and target buttons", GetGuide("buttons"), SetGuide("buttons"),
			{ enabled = Guided, desc = "The card gets a button for each item, spell or macro the step uses and one for each NPC or creature it names; click to use or target. The first of each can be bound in Key Bindings under ShyQuest." }), panel, LEFT, y - 192)
		At(group:Checkbox(panel, "Mark who I target", GetGuide("marks"), SetGuide("marks"),
			{ enabled = Buttoned, desc = "Targeting from the card also sets a raid marker: star for NPCs, skull for enemies, moon for rares. Only while solo." }), panel, LEFT + 16, y - 218)
		At(group:Checkbox(panel, "Alert for rares", GetGuide("scan"), SetGuide("scan"),
			{ enabled = Buttoned, desc = "When a rare or wandering creature the step needs appears nearby, a sound plays, chat names it and its line lights up." }), panel, LEFT + 16, y - 244)
		At(group:Checkbox(panel, "Auto pick gossip options", GetGuide("gossip"), SetGuide("gossip"),
			{ enabled = Guided, desc = "Picks the gossip option the step needs when you talk to its NPC. Anything with a confirmation is left to you. Hold Shift to choose yourself." }), panel, RIGHT, y - 192)
		At(group:Checkbox(panel, "Auto take flights", GetGuide("takeFlights"), SetGuide("takeFlights"),
			{ enabled = Guided, desc = "When the step is a flight, the game's own flight map takes it as it opens. Hold Shift to choose yourself." }), panel, RIGHT, y - 218)
		At(group:Checkbox(panel, "Auto set hearthstone", GetGuide("setHome"), SetGuide("setHome"),
			{ enabled = Guided, desc = "When the step or the card says to set your hearthstone, talking to the innkeeper does it. Hold Shift to leave it where it is." }), panel, RIGHT, y - 244)
		At(group:Checkbox(panel, "Roleplay timers", GetGuide("timers"), SetGuide("timers"),
			{ enabled = Guided, desc = "Counts down the wait after a turn-in while an NPC talks or walks off." }), panel, LEFT, y - 270)

		-- Which dungeons' quests go in the guide, then every dungeon the guides have steps for on
		-- this faction, lowest first, in two columns.
		y = y - 26
		local detours = ns.Detours()
		local rows = math.ceil(#detours / 2)
		At(UI.Text(panel, "Dungeon quests", 13, true, UI.colors.head), panel, LEFT, y - 280)
		At(group:Dropdown(panel, "Which dungeons", {
			{ value = "ticked", text = "Only the ones ticked below" },
			{ value = "ready", text = "Any at my level, and the ticked ones" },
			{ value = "never", text = "None" },
		}, GetGuide("dungeonPlan"), SetGuide("dungeonPlan"), { width = COL, enabled = Guided,
			desc = "Which dungeons' quests your guide sends you to. \"At my level\" follows the Group Finder's suggested levels. Not ready for one? Right-click one of its steps on the card to put it off." }),
			panel, LEFT, y - 300)
		for i, dungeon in ipairs(detours) do
			local tag = dungeon.short
			local low, high = ns.DungeonRange(dungeon)
			local desc = ("Adds %s to your guide: where to pick up its quests, what they need inside, and where to turn them in."):format(dungeon.name)
			if ns.CanRecruit(dungeon) then
				desc = desc .. "\n\nStarting a run for it in ShyGroup ticks this, and right-clicking one of its steps on the card finds you a group."
			end
			At(group:Checkbox(panel, ("%s  |cff888888%d-%d|r"):format(dungeon.name, low, high),
				function() return T.db.guide.dungeons[tag] == true end, function(v)
					T.db.guide.dungeons[tag] = v or nil
					if v then ns.Unsnooze(tag) end   -- ticked again after Not now
				end,
				{ enabled = Guided, desc = desc }), panel, i <= rows and LEFT or RIGHT, y - 356 - ((i - 1) % math.max(rows, 1)) * 26)
		end

		y = y - 400 - math.max(rows, 1) * 26 + 26
		At(UI.Header(panel, "Map pins", 576), panel, LEFT, y)
		At(group:Checkbox(panel, "On the world map", Get("mapPins"), Set("mapPins"),
			{ desc = "Pins for quests to pick up (!) and turn in (?), your guide's next steps numbered in order, and a quest count on each suggested zone. Click a pin to shade where its objectives are, right-click to go there first." }), panel, LEFT, y - 32)
		At(group:Checkbox(panel, "On the minimap", Get("minimapPins"), Set("minimapPins"),
			{ desc = "The same pins on the minimap, with a trail to your next step. While the step is out of range its pin sits on the minimap's edge." }), panel, LEFT, y - 58)
		At(group:Slider(panel, "Pin size", 0.7, 1.6, 0.1, Get("pinSize"), Set("pinSize"),
			{ width = COL, enabled = Pinned, format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
			desc = "Size of the pins on the world map and minimap." }), panel, RIGHT, y - 30)
		-- (The roads are ShyWay's: without it there is nothing to choose.)
		if not Shy.Way.missing then
			At(group:Dropdown(panel, "Paths", {
				{ value = "never", text = "Shortest" },
				{ value = "auto", text = "Roads unless I outlevel it" },
				{ value = "always", text = "Always roads" },
			}, function() return Shy.Way.Paths() or "never" end,
				function(v) Shy.Way.SetPaths(v) end, { width = COL,
				desc = "Keeps you on roads, leaving them only near your step. \"Unless I outlevel it\" cuts across where everything off the road is below your level. Set per character." }), panel, RIGHT, y - 84)
		end
		At(group:Checkbox(panel, "Areas past the edge", Get("minimapRim"), Set("minimapRim"),
			{ enabled = Get("minimapPins"), desc = "Where a quest area runs on past the minimap's edge, its outline carries on along the edge." }), panel, LEFT + 16, y - 84)
		At(group:Checkbox(panel, "In the quest log", Get("logMarks"), Set("logMarks"),
			{ desc = "Shows each quest's mark and route number in the map's quest log. Hover or click a quest or objective to light up where to go on the map." }), panel, LEFT, y - 110)
		At(group:Checkbox(panel, "Quests in route order", Get("logSort"), Set("logSort"),
			{ enabled = Get("logMarks"), desc = "Lists each zone's quests in the quest log in the order your route takes them, instead of by level." }), panel, LEFT + 16, y - 136)

		-- OptionsWorld.lua's sections; a file new to the TOC isn't loaded until the client restarts.
		if ns.MoreOptions then ns.MoreOptions(panel, group, y - 178) end
	end

	local function Redraw()
		ns.FillPreview(preview)
		local count = HiddenCount()
		hidden.text:SetText(count == 0 and "No quests hidden" or ("Show %d hidden quest%s"):format(count, count == 1 and "" or "s"))
		hidden:SetEnabled(count > 0)
		hidden:SetAlpha(count > 0 and 1 or 0.5)
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			Redraw()
		end
	end

	ns.OnRoute(function(rebuilt, measured)
		if panel.built and panel:IsVisible() then
			if rebuilt then ns.FillPreview(preview) elseif measured ~= false then preview:Measure() end
		end
	end, true)

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		Redraw()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ns.Apply()
	end

	return panel
end
