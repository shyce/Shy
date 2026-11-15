-- Shy.Setup: character setup. A window holds a few steps (profile, game settings, plus steps other
-- addons register), each picked as recommended from the start and shown together on its overview, then
-- S.Run applies them all with at most one reload. Opens on a character's first login once its intro has
-- played, from /shy setup, and from the /shy window, where the same pieces are live sections. While it is
-- open the screen stays up and every pick goes on it as it is made.
--
--   Shy.Setup.Step{ id, order, title,     registered by the addon that owns the step
--       glyph,                            its picture on the rail and its overview card (UI.GlyphArt's names)
--       ask, lead,                        the question its page answers and a sentence under it, its heading
--       brief,                            what it holds now in a few words ("Forged"), under its name on the
--                                         rail and on its overview card; a string or function(plan)
--                                         (each a string or a function of the plan; the window draws them)
--       changes(plan),                    how many things Finish changes here; a page whose tabs all count
--                                         them shows their sum on the rail ("5 changes") instead of one brief
--       Plan(plan),                       fill its part of a plan with the recommended choices
--       Build(parent, width, plan, room), its page: a frame with :Refresh(); read the plan on demand, keep no copy.
--                                         room: the height it has on show; the window flows taller, and a page
--                                         with :Fit(room) is told the new room each time. None: no page, it
--                                         only runs (a setting setup always puts back)
--       Check(plan),                      true, or false and a sentence saying why
--       Lines(plan),                      summary: { { text =, sub = }, ... }; the first line's text stands on
--                                         its overview card
--       Run(plan),                        apply it: true when a reload is needed
--       last = true,                      run after the others
--       inside = id,                      no page of its own: its Build is a strip over that step's
--                                         heading, on its page (shown with it; Shown runs with it)
--       tab = id,                         no page of its own while that step has one: it is a tab of that
--                                         step's page, after the step's own (a subject's steps together)
--       tabTitle,                         its tab's name there, when its title alone would not say it
--       Settled(),                        true when this character already has it from before setup existed
--       Later(answers),                   answers kept by S.Wait, given back after the reload
--       Shown(plan),                      its page came up: put the plan's picks on the screen
--       atOpen = true,                    its Shown runs as the overview comes up too (the size: the first
--                                         thing set, whatever page is opened next)
--       Worn(),                           for a step whose picks go on as they are made: what stands now,
--       PutBack(kept, moving) }           put back when the window closes without Finish (moving: Finish
--                                         switched profile, so only the old profile's settings go back)
--   Shy.Setup.Act(plan)        what the profile step does: "stay", "use" or "fresh"
--   Shy.Setup.Wait(id, answers)   a step's profile settings, applied after the reload once the profile has loaded
--   Shy.Setup.Tile(parent, width, glyph, name, onClick, height, icon)   a choice tile, as the profile page has them
--   Shy.Setup.Row(parent, width, item, get, set)   a whole-row switch: item = { title, desc, say }
--   Shy.Setup.Questions{ ... }            an addon's own switches as a step: see "Questions"
--   Shy.Setup.Plan(plan)       fills `plan` (or a new table) with the recommended choices
--   Shy.Setup.Check(plan)      true, or false and why
--   Shy.Setup.Run(plan)        applies everything: true, or false and why
--   Shy.Setup.Open(at) / Close() / IsOpen()   at: a step's id to open on, the overview unless told
--   Shy.Setup.At()             the page on show ("overview" or a step's id); nil while it is closed
--   Shy.Setup.Relabel()        the open page's heading again (a step whose lead changed)
--   Shy.Setup.Done()           this character has been set up
--   Shy.Setup.Untouched()      Global has only ever been used by one character
--
--   Shy.Setup.GAME             game settings: { key, group, title, desc, want = { cvar = value },
--                              flags = { cvar = index }, on, off, can, owner, round } (see "Game settings");
--                              one that isn't a CVar has is(), take(kept), back(kept) instead, and may
--                              have reload (a sentence: it shows after a reload) and fail (why it couldn't)
--   Shy.Setup.Offered()        the ones available on this client and nobody else's to switch right now
--   Shy.Setup.Is(def)          is it set that way now
--   Shy.Setup.Can(def)         can every CVar of it be set (exists, not locked, not refused before), and
--                              does the game offer the feature here
--   Shy.Setup.Take(def)        set it; the previous value is kept
--   Shy.Setup.Return(def)      restore the previous value (or the default)
--   Shy.Setup.GameList(parent, width, plan)   the list: picks into plan.game, or live switches without a plan
--   Shy.Setup.Picked(key)      while the window is open: does its plan switch that game setting on
--                              (true or false); nil while it is closed
--   Shy.Setup.Live(key, on)    a page puts a game setting the plan picks on now (on), or gives it back;
--                              closing without Finish gives back all it put on
--   Shy.Setup.RepairDock()     rewrites saved chat tab ranks the game can't load (runs at load): true when it did
--
-- Account-wide, outside profiles:
--   ShyCoreDB.setup = { untouched, chars = { [character] = { asked, done, said, left, pending, round } },
--                       locked = { [cvar] = true } for CVars the game refused,
--                       refused = last ten blocked actions: { at, addon, what, during } }
--   ShyCoreDB.game  = { [cvar] = value before it was changed here; ["cvar:index"] = "0" or "1" for a flag }

local Shy = Shy
local B, UI, Theme, P, Skin = Shy.Brand, Shy.UI, Shy.Theme, Shy.Profiles, Shy.Skin
local core = Shy.core
local C = UI.colors
local MEDIA = Shy.MEDIA
local max = math.max

local S = {}
Shy.Setup = S
core.keep.setup, core.keep.game = true, true

S.GLYPH = { star = MEDIA .. "GlyphStar", globe = MEDIA .. "GlyphGlobe", people = MEDIA .. "GlyphPeople", check = MEDIA .. "GlyphCheck" }

local function First() return (UnitName("player")) end

-- "a", "a and b", "a, b and c".
local function Listed(items)
	if #items < 3 then return table.concat(items, " and ") end
	return table.concat(items, ", ", 1, #items - 1) .. " and " .. items[#items]
end

-- How many things Finish changes, in a few words.
local function Changes(n)
	return n == 0 and "No changes" or n == 1 and "1 change" or (n .. " changes")
end

-- Titles as they read inside a sentence, the first `most` of them and how many more.
local function Named(defs, most)
	local names = {}
	for i, def in ipairs(defs) do
		if i > most then
			names[#names + 1] = (#defs - most) .. " more"
			break
		end
		names[i] = (def.title:gsub("^%u", string.lower))
	end
	return Listed(names)
end

-- Setup records

local function Book()
	local db = ShyCoreDB
	db.setup = db.setup or {}
	db.setup.chars = db.setup.chars or {}
	return db.setup
end

local function Mine()
	local chars, me = Book().chars, P.Character()
	chars[me] = chars[me] or {}
	return chars[me]
end

-- True while only one character has ever logged in on a fresh account. "Default setup" then resets
-- Global itself; once a second character exists it resets the character's own profile instead.
function S.Untouched()
	return Book().untouched == true
end

-- Other characters on a profile, as "First Surname" (first names alone can collide).
local function Others(name)
	local out, me = {}, P.Character()
	for character in pairs(Book().chars) do
		if character ~= me and (ShyCoreDB.uses[character] or P.GLOBAL) == name then
			out[#out + 1] = character:match("^(.-) %- ") or character
		end
	end
	table.sort(out)
	return out
end

-- Game settings
--
-- Each entry is a line of the game's Options window (Blizzard_SettingsDefinitions_Frame and _Shared;
-- chatClassColorOverride is Blizzard_ChatFrameBase's). `on`: ticked by default in the setup window.
-- `want`: each CVar and the value wanted. `flags`: a CVar that holds several switches, and the index
-- of the one wanted on (as C_CVar.GetCVarBitfield takes it); the others are left as they are.
-- `can`: false while the game doesn't offer the feature (a realm without it).
-- `owner`: suffix of an addon that manages the same CVar itself; while it is loaded the entry is not
-- offered. Or a function, true while something else switches it: the row stays, dimmed, and setup
-- leaves it alone.
-- `round`: the set of recommendations the entry came with (none: the first). A character set up
-- before a newer round is told once which of its recommended settings it doesn't have.
-- Left out on purpose: personal taste (mouse speed, FOV, key bindings) and graphics. The swing timer,
-- chat timestamps and Blizzard's nameplate look are switched by the addons that use them, while they
-- run. Instant Quest Text is the immersion step's (Immersion.lua), one of its three kinds of quest text.

local function MeterOffered() return (C_DamageMeter.IsDamageMeterAvailable()) end
local function CooldownsOffered() return (C_CooldownViewer.IsCooldownViewerAvailable()) end
local function PersonalOffered() return not C_GameRules.IsGameRuleActive(Enum.GameRule.PersonalResourceDisplayDisabled) end

-- True while one of these ShyTweaks tweaks is on: it switches the same setting itself.
local function Tweaks(...)
	local ids = { ... }
	return function()
		local tweaks = Shy.addons.Tweaks
		if not (tweaks and tweaks.IsTweakOn) then return false end
		for _, id in ipairs(ids) do
			if tweaks:IsTweakOn(id) then return true end
		end
		return false
	end
end

-- Chat windows

-- In use (shown, or a tab in the dock: the dock hides every tab but the one picked, and a hidden chat
-- frame is written as not shown), and the window's place in the dock (nil off the dock: the game reports
-- that as 0).
local function Shown(id)
	local _, _, _, _, _, _, shown, _, docked = GetChatWindowInfo(id)
	docked = tonumber(docked)
	if docked == 0 then docked = nil end
	return (shown or docked) and true or false, docked
end

-- The first window past the game's own that isn't shown, as the tab menu's New Window picks it.
local function FreeWindow()
	for id = C_ChatInfo.GetNumReservedChatWindows() + 1, Constants.ChatFrameConstants.MaxChatWindows do
		if not Shown(id) then return id end
	end
end

-- The docked tabs in their order: General first (the dock's primary, docked whatever its flags say;
-- the dock asserts at load if anything else is ranked first), then by docked index, then by window.
-- A ranked window is docked whether or not it is shown (the game docks it at load either way).
local function Docked()
	local list = { { id = 1, at = 1 } }
	for id = 2, Constants.ChatFrameConstants.MaxChatWindows do
		local _, docked = Shown(id)
		if docked then list[#list + 1] = { id = id, at = docked } end
	end
	table.sort(list, function(a, b)
		if a.id == 1 or b.id == 1 then return a.id == 1 end
		if a.at ~= b.at then return a.at < b.at end
		return a.id < b.id
	end)
	return list
end

-- Writes an order as the game reads it back: at load each window takes its index among the windows
-- before it (by number), so a contiguous ranking is the one way the row comes back as written.
local function Order(list)
	for i, entry in ipairs(list) do SetChatWindowDocked(entry.id, i) end
end

-- Saved ranks the game can't load (another window ranked first, which the dock asserts on, losing
-- that tab; or ranks out of step) are rewritten as the game reads them, as soon as the addon loads.
-- Nothing is written while they are right.
local function RepairDock()
	local list = Docked()
	for i, entry in ipairs(list) do
		if entry.at ~= i then
			Order(list)
			return true
		end
	end
	return false
end
S.RepairDock = RepairDock

-- Docked after the last tab. General and the combat log are the dock's two fixed tabs: the game
-- stands them first, in that order, before every other tab, whatever order is saved, and a dragged
-- combat log can only be dropped beside General. So the row is always General, the combat log,
-- then the rest in their order.
local function DockLast(id)
	local list = Docked()
	list[#list + 1] = { id = id }
	Order(list)
end

-- A free window made ready for a tab of ours: named, in the game's own colors and General's font size,
-- carrying nothing (but `keep`, a channel it may hold already).
local function Blank(id, tab, keep)
	local _, size = GetChatWindowInfo(1)
	SetChatWindowName(id, tab)
	SetChatWindowColor(id, DEFAULT_CHATFRAME_COLOR.r, DEFAULT_CHATFRAME_COLOR.g, DEFAULT_CHATFRAME_COLOR.b)
	SetChatWindowAlpha(id, DEFAULT_CHATFRAME_ALPHA)
	if size > 0 then SetChatWindowSize(id, size) end
	for _, group in ipairs({ GetChatWindowMessages(id) }) do RemoveChatWindowMessages(id, group) end
	local list = { GetChatWindowChannels(id) }
	for i = 1, #list, 2 do
		if list[i] ~= keep then RemoveChatWindowChannel(id, list[i]) end
	end
end

-- A channel in a chat window of its own, so General stays readable. The window is written the way the
-- game keeps its chat windows between sessions (what the chat tab's own settings write), never through
-- the dock's functions, so it is there after a reload. Every other window stops showing the channel.
-- Kept as ShyCoreDB.game[key]: the window that showed the channel before, or "0" for none.
--   join: the game never joins this channel by itself, so ticking joins it, and "0" means it wasn't
--   joined: unticking leaves it again. Without it the channel is one the game joins on its own (a zone
--   channel, there as you enter a zone that has one), and the tab is set up whether or not it is now.
-- Returns is, take and back for an entry of S.GAME.
local function ChannelTab(channel, tab, key, join)
	local function Joined() return (GetChannelName(channel)) > 0 end

	-- Does the window carry the channel, and does it carry that alone (no other channel, no chat kind).
	local function Carries(id)
		local has, alone = false, select("#", GetChatWindowMessages(id)) == 0
		local list = { GetChatWindowChannels(id) }
		for i = 1, #list, 2 do
			if list[i] == channel then has = true else alone = false end
		end
		return has, alone
	end

	-- The shown window that is the channel's own, if there is one.
	local function Window()
		for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
			if Shown(id) then
				local has, alone = Carries(id)
				if has and alone then return id end
			end
		end
	end

	local function Is()
		if join and not Joined() then return false end
		local own = Window()
		if not own then return false end
		for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
			if id ~= own and Shown(id) and Carries(id) then return false end
		end
		return true
	end

	local function Take(kept)
		local own, fresh = Window(), false
		if not own then
			own, fresh = FreeWindow(), true
			if not own then return false end
		end
		if kept[key] == nil then
			local was = "0"
			if not join or Joined() then
				if join then was = "1" end
				for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
					if id ~= own and Carries(id) then was = tostring(id) break end
				end
			end
			kept[key] = was
		end
		if join and not Joined() and not JoinPermanentChannel(channel, nil, own, 1) then return false end
		if fresh then
			Blank(own, tab, channel)
			AddChatWindowChannel(own, channel)
			SetChatWindowShown(own, true)
			DockLast(own)
		end
		for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
			if id ~= own and Carries(id) then RemoveChatWindowChannel(id, channel) end
		end
		return Is()
	end

	local function Back(kept)
		local was = kept[key] or "0"
		kept[key] = nil
		local own = Window()
		if own then
			RemoveChatWindowChannel(own, channel)
			SetChatWindowShown(own, false)
			SetChatWindowDocked(own, nil)
		end
		if was ~= "0" then
			AddChatWindowChannel(tonumber(was) or 1, channel)
		elseif join then
			LeaveChannelByName(channel)
		end
	end

	return Is, Take, Back
end

-- LookingForGroup: this client never joins it by itself, and ShyGroup posts and reads there.
local LfgIs, LfgTake, LfgBack = ChannelTab("LookingForGroup", "LFG", "chat:lfg", true)
-- LocalDefense: the zone's calls when its towns are attacked. LD, to fit the row.
local DefenseIs, DefenseTake, DefenseBack = ChannelTab("LocalDefense", "LD", "chat:defense")

-- Some kinds of chat (whispers, guild chat) in a chat window of their own beside General, which goes on
-- showing them, so they are read in the flow and kept where they don't scroll away. Written as the game
-- keeps its windows, like a channel's tab. Nothing is kept for unticking: the window is put away, and
-- General showed the chat all along.
--   general: General is made to show these kinds too. Without it General is left as it is.
-- Returns window (the shown window that is the tab's own, if there is one; General is never it) and
-- is, take and back for an entry of S.GAME.
local function KindTab(tab, groups, general)
	local mine = {}
	for _, group in ipairs(groups) do mine[group] = true end

	-- Does the window carry any of the kinds, and those alone (no other kind, no channel).
	local function Carries(id)
		local has, alone = false, select("#", GetChatWindowChannels(id)) == 0
		for _, group in ipairs({ GetChatWindowMessages(id) }) do
			if mine[group] then has = true else alone = false end
		end
		return has, alone
	end

	local function Window()
		for id = 2, Constants.ChatFrameConstants.MaxChatWindows do
			if Shown(id) then
				local has, alone = Carries(id)
				if has and alone then return id end
			end
		end
	end

	local function Is()
		return Window() ~= nil
	end

	local function Take()
		local own = Window()
		if not own then
			own = FreeWindow()
			if not own then return false end
			Blank(own, tab)
			for _, group in ipairs(groups) do AddChatWindowMessages(own, group) end
			SetChatWindowShown(own, true)
			DockLast(own)
		end
		if general then
			for _, group in ipairs(groups) do AddChatWindowMessages(1, group) end
		end
		return Is()
	end

	local function Back()
		local own = Window()
		if not own then return end
		for _, group in ipairs(groups) do RemoveChatWindowMessages(own, group) end
		SetChatWindowShown(own, false)
		SetChatWindowDocked(own, nil)
	end

	return Window, Is, Take, Back
end

-- The Tells tab: whispers (Battle.net ones too). General always shows them as well: a tell is read in
-- the flow, and its tab lights up until it is read there.
local TellsWindow, TellsIs, TellsTake, TellsBack = KindTab("Tells", { "WHISPER", "BN_WHISPER" }, true)
S.TellsWindow = TellsWindow
-- The Guild tab: guild and officer chat, and the guild's announcements.
local _, GuildIs, GuildTake, GuildBack = KindTab("Guild", { "GUILD", "OFFICER", "GUILD_ACHIEVEMENT" })

-- Short chat tabs: General reads Gen and Combat Log reads Combat, so more tabs fit the row. The
-- names they had are kept (ShyCoreDB.game["chat:gen"] / ["chat:combat"]). Their places are the
-- game's (see DockLast): nothing here orders the row.

local COMBAT = 2   -- the combat log's window
local GEN_TAB, COMBAT_TAB = "Gen", "Combat"
local GEN_KEY, COMBAT_KEY = "chat:gen", "chat:combat"

local function TabsIs()
	return (GetChatWindowInfo(1)) == GEN_TAB and (GetChatWindowInfo(COMBAT)) == COMBAT_TAB
end

local function TabsTake(kept)
	if kept[GEN_KEY] == nil then kept[GEN_KEY] = (GetChatWindowInfo(1)) or GENERAL end
	if kept[COMBAT_KEY] == nil then kept[COMBAT_KEY] = (GetChatWindowInfo(COMBAT)) or COMBAT_LOG end
	SetChatWindowName(1, GEN_TAB)
	SetChatWindowName(COMBAT, COMBAT_TAB)
	return TabsIs()
end

local function TabsBack(kept)
	SetChatWindowName(1, kept[GEN_KEY] or GENERAL)
	SetChatWindowName(COMBAT, kept[COMBAT_KEY] or COMBAT_LOG)
	kept[GEN_KEY], kept[COMBAT_KEY] = nil, nil
end

S.GAME = {
	{ key = "cameraFollow", group = "Camera", title = "Camera never follows", on = true,
		desc = "The camera stays where you put it instead of swinging behind your character. (Options > Controls > Camera Following Style)",
		want = { cameraSmoothStyle = "0" }, off = { cameraSmoothStyle = "4" } },
	{ key = "headBob", group = "Camera", title = "No head bob", on = true,
		desc = "The view doesn't bounce as you walk in first person. (Options > Controls > Head Bob)",
		want = { cameraBobbing = "0" } },
	{ key = "waterCamera", group = "Camera", title = "Camera free in water", on = true, round = 6,
		desc = "The camera moves freely above and below the water instead of stopping at the surface. (Options > Controls > Water Collision, off)",
		want = { cameraWaterCollision = "0" }, off = { cameraWaterCollision = "1" } },
	{ key = "zoomOut", group = "Camera", title = "Zoom out further", on = true, owner = "Tweaks",
		desc = "Lets the camera zoom out a little past the end of its slider. (Options > Controls > Max Camera Distance)",
		want = { cameraDistanceMaxZoomFactor = "2.6" } },
	{ key = "dropTarget", group = "Controls", title = "Click ground to deselect", on = true,
		desc = "Clicking empty ground clears your target. (Options > Controls > Sticky Targeting, off)",
		want = { deselectOnClick = "1" } },
	{ key = "oneBag", group = "Controls", title = "Combined bags", on = true,
		desc = "Your bags open as one window. (Options > Controls > Use Combined Inventory Bags)",
		want = { combinedBags = "1" } },
	{ key = "autoLoot", group = "Loot", title = "Auto loot", on = true,
		desc = "Looting grabs everything. Hold the loot key to look first. (Options > Controls > Auto Loot)",
		want = { autoLootDefault = "1" } },
	{ key = "lootAtMouse", group = "Loot", title = "Loot window at cursor",
		desc = "The loot window opens under your cursor. (Options > Controls > Open Loot Window at Mouse)",
		want = { lootUnderMouse = "1" } },
	{ key = "tutorials", group = "Fewer interruptions", title = "No tutorial pop-ups", on = true,
		desc = "Turns off the tutorial tips. (Options > Interface > Tutorials)",
		want = { showTutorials = "0" } },
	{ key = "toasts", group = "Fewer interruptions", title = "No item pop-ups", on = true,
		desc = "No banner when you loot an item, add to a collection or learn a recipe. Chat still reports it. (Options > Interface, the three Toasts)",
		want = { enableLootToasts = "0", enableCollectionToasts = "0", enableLearnedRecipeToasts = "0" } },
	{ key = "errorSpeech", group = "Fewer interruptions", title = "No spoken error messages", on = true,
		desc = "Your character stops saying \"Not enough energy\" and the like. The red text still shows. (Options > Audio > Error Speech)",
		want = { Sound_EnableErrorSpeech = "0" } },
	{ key = "errorWindow", group = "Fewer interruptions", title = "No error pop-ups", on = true, round = 8,
		desc = "Addon errors are kept for /shy errors instead of opening a window in the middle of the screen.",
		is = function() return not Shy.Errors.Popup() end,
		take = function() Shy.Errors.SetPopup(false) return true end,
		back = function() Shy.Errors.SetPopup(true) end },
	{ key = "cooldownNumbers", group = "On screen", title = "Cooldown numbers", on = true, owner = "Tweaks",
		desc = "Buttons on cooldown show the time left. (Options > Action Bars > Show Numbers for Cooldowns)",
		want = { countdownForCooldowns = "1" } },
	{ key = "statusText", group = "On screen", title = "Health and mana as numbers", on = true, owner = "Frames",
		desc = "Unit frames show the number and percent on their bars. (Options > Interface > Status Text, Both)",
		want = { statusTextDisplay = "BOTH", statusText = "1" }, off = { statusTextDisplay = "NONE", statusText = "0" } },
	{ key = "chatClassColors", group = "On screen", title = "Class colors in chat", on = true, owner = "Chat",
		desc = "Player names in chat are class colored, in every channel.",
		want = { chatClassColorOverride = "0" }, off = { chatClassColorOverride = "1" } },
	{ key = "soundInBackground", group = "Sound", title = "Sound in background", on = true,
		desc = "You still hear the game while tabbed out: whispers, queue pops, combat. (Options > Audio > Sound in Background)",
		want = { Sound_EnableSoundWhenGameIsInBG = "1" } },
	{ key = "musicLoop", group = "Sound", title = "Loop music", on = true,
		desc = "Zone music restarts without a silence in between. (Options > Audio > Loop Music)",
		want = { Sound_ZoneMusicNoDelay = "1" } },
	{ key = "lossOfControl", group = "On screen", title = "Loss of control alerts", on = true, round = 2,
		desc = "A banner in the middle of the screen says when you're stunned, silenced or feared, and for how long. (Options > Combat)",
		want = { lossOfControl = "1" } },
	{ key = "raidColors", group = "On screen", title = "Raid frame class colors", round = 2,
		desc = "Raid frames show each player's health in their class color. (Options > Interface > Raid Frames)",
		want = { raidFramesDisplayClassColor = "1" } },
	{ key = "raidAggro", group = "On screen", title = "Aggro on raid frames", on = true, round = 9,
		desc = "Raid frames outline whoever has aggro or is about to pull it. (Options > Interface > Raid Frames > Display Aggro Highlight)",
		want = { raidFramesDisplayAggroHighlight = "1" } },
	{ key = "loadingTips", group = "Fewer interruptions", title = "No loading screen tips", on = true, round = 2,
		desc = "Loading screens show only their art. (Options > Interface > Loading Screen Tips)",
		want = { showLoadingScreenTips = "0" } },
	{ key = "damageMeter", group = "Features", title = "Damage meter", on = true, round = 2, can = MeterOffered,
		desc = "The game's own meter of damage and healing, for you and your group. (Options > Advanced Options > Damage Meter)",
		want = { damageMeterEnabled = "1" } },
	{ key = "meterReset", group = "Features", title = "Fresh meter each dungeon", on = true, round = 2, can = MeterOffered,
		desc = "The damage meter starts over as you enter a dungeon or raid. (Options > Advanced Options > Damage Meter)",
		want = { damageMeterResetOnNewInstance = "1" } },
	{ key = "cooldowns", group = "Features", title = "Cooldown manager", on = true, round = 2, can = CooldownsOffered,
		desc = "Your main abilities' cooldowns in a row under your character. (Options > Advanced Options > Cooldown Manager)",
		want = { cooldownViewerEnabled = "1" } },
	{ key = "personalResource", group = "Features", title = "Personal resource display", on = true, round = 2, can = PersonalOffered,
		-- ShyDock's layouts by role have no place for it (your frame shows health and power) and keep it off while in use.
		owner = function()
			local dock = Shy.addons.Dock
			return dock ~= nil and dock.HoldsDisplay ~= nil and dock:HoldsDisplay() == true
		end,
		desc = "Your health and power just under your character, where you're looking in a fight. ShyDock's layouts by role show them on your unit frame instead and keep this off. (Options > Combat)",
		want = { nameplateShowSelf = "1" } },
	{ key = "enemyPlates", group = "Nameplates", title = "Enemy nameplates", on = true, round = 2,
		owner = Tweaks("combatPlates", "npcNames"),
		desc = "Every enemy near you gets a nameplate with its health, casts and your debuffs. ShyTweaks' NPC names and combat-only nameplates control this while they're on. (Options > Nameplates)",
		want = { nameplateShowEnemies = "1" } },
	{ key = "friendPlates", group = "Nameplates", title = "Friendly nameplates", on = true, round = 2,
		desc = "Players on your side get a nameplate, so a group or a fight is easy to read. (Options > Nameplates)",
		want = { nameplateShowFriendlyPlayers = "1" } },
	{ key = "alwaysPlates", group = "Nameplates", title = "Nameplates out of combat", on = true, round = 2,
		owner = Tweaks("npcNames"),
		desc = "Nameplates show all the time, not only once a fight starts. ShyTweaks' NPC names controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowAll = "1" } },
	{ key = "plateAggro", group = "Nameplates", title = "Threat colors on nameplates", on = true, round = 9, owner = "Plates",
		desc = "An enemy's health bar changes color as you lose threat on it as a tank, or pull it otherwise. (Options > Nameplates > Aggro Display > Health Bar Color)",
		flags = { nameplateThreatDisplay = Enum.NamePlateThreatDisplay.HealthBarColor } },
	{ key = "stackPlates", group = "Nameplates", title = "Stack enemy nameplates", on = true, round = 2,
		desc = "Enemy nameplates stack instead of overlapping, so each stays readable. (Options > Nameplates)",
		flags = { nameplateStackingTypes = Enum.NamePlateStackType.Enemy } },
	{ key = "npcPlates", group = "Nameplates", title = "Friendly NPC nameplates", round = 2,
		owner = Tweaks("npcNames"),
		desc = "Guards, vendors and quest givers get a nameplate with their name. ShyTweaks' NPC names controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowFriendlyNpcs = "1" } },
	{ key = "minionPlates", group = "Nameplates", title = "Enemy pet nameplates", round = 2,
		desc = "Pets, totems and other minions of your enemies get nameplates too. (Options > Nameplates)",
		want = { nameplateShowEnemyMinions = "1" } },
	{ key = "chatTabs", group = "Chat", title = "Short chat tabs", on = true, round = 4,
		desc = "General reads Gen and Combat Log reads Combat, so more tabs fit the row. The names change after a reload. (Right-click a chat tab > Settings)",
		is = TabsIs, take = TabsTake, back = TabsBack,
		reload = "The chat tabs change after a reload." },
	{ key = "lfgTab", group = "Chat", title = "Own tab for LookingForGroup", on = true, round = 3,
		desc = "You join the LookingForGroup channel and it gets its own chat tab, so General stays readable. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = LfgIs, take = LfgTake, back = LfgBack,
		reload = "The LookingForGroup tab changes after a reload.", fail = "needs a free chat window; close one first." },
	{ key = "tellsTab", group = "Chat", title = "Own tab for whispers", on = true, round = 4,
		desc = "Whispers get their own chat tab, named Tells, so they never scroll away. General still shows them too. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = TellsIs, take = TellsTake, back = TellsBack,
		reload = "The Tells tab changes after a reload.", fail = "needs a free chat window; close one first." },
	{ key = "guildTab", group = "Chat", title = "Own tab for guild chat", on = true, round = 10,
		desc = "Guild and officer chat get their own chat tab, named Guild, so they never scroll away. General still shows what it showed. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = GuildIs, take = GuildTake, back = GuildBack,
		reload = "The Guild tab changes after a reload.", fail = "needs a free chat window; close one first." },
	{ key = "defenseTab", group = "Chat", title = "Own tab for LocalDefense", on = true, round = 7,
		desc = "LocalDefense, which calls out attacks on the zone's towns, gets its own chat tab named LD, so General stays readable. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = DefenseIs, take = DefenseTake, back = DefenseBack,
		reload = "The LocalDefense tab changes after a reload.", fail = "needs a free chat window; close one first." },
	{ key = "partyBubbles", group = "Chat", title = "Party chat bubbles", on = true, round = 5, owner = "Chat",
		desc = "Party chat shows in bubbles over their heads, like /say does. (Options > Interface > Chat Bubbles > Party Chat)",
		want = { chatBubbles = "1", chatBubblesParty = "1" } },
}
-- Columns of groups: three where the list has the width (the setup window, the /shy window), two where it is
-- narrower. And the list's line spacing.
local COLUMNS = {
	[3] = { { "Camera", "Controls", "Loot", "Chat" }, { "On screen", "Fewer interruptions", "Sound" }, { "Features", "Nameplates" } },
	[2] = { { "Camera", "Controls", "Loot", "Chat", "Features" }, { "On screen", "Fewer interruptions", "Sound", "Nameplates" } },
}
local WIDE = 700   -- a list at least this wide has three columns
local ROW, SUB, BETWEEN, MASTER = 22, 17, 6, 28

-- The newest round of recommendations.
local ROUND = 1
for _, def in ipairs(S.GAME) do ROUND = max(ROUND, def.round or 1) end

-- CVars come back as text: "0" and "0.000000" are the same value.
local function Same(a, b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and x == y
end

-- A CVar an addon can set: it exists, isn't locked or read-only, and wasn't refused before
-- (Write records refusals in ShyCoreDB.setup.locked).
local function Settable(setting)
	local value, _, _, _, locked, _, readOnly = C_CVar.GetCVarInfo(setting)
	return value ~= nil and not locked and not readOnly and not (Book().locked and Book().locked[setting])
end

local NONE = {}

function S.Can(def)
	for setting in pairs(def.want or NONE) do
		if not Settable(setting) then return false end
	end
	for setting in pairs(def.flags or NONE) do
		if not Settable(setting) then return false end
	end
	-- Asked last: only once the game is known to have the settings.
	return not def.can or def.can() and true or false
end

-- An addon that is loaded switches it, or (a function) something switches it right now.
local function Owned(def)
	if type(def.owner) == "function" then return def.owner() end
	return def.owner ~= nil and Shy.addons[def.owner] ~= nil
end

function S.Offered()
	local offered = {}
	for _, def in ipairs(S.GAME) do
		if not Owned(def) and S.Can(def) then offered[#offered + 1] = def end
	end
	return offered
end

-- The list's rows: what is offered, and what something switches for now (shown dimmed).
local function Rows()
	local rows = {}
	for _, def in ipairs(S.GAME) do
		if S.Can(def) and (type(def.owner) == "function" or not Owned(def)) then rows[#rows + 1] = def end
	end
	return rows
end

function S.Is(def)
	if def.is then return def.is() end
	for setting, value in pairs(def.want or NONE) do
		if not Same(C_CVar.GetCVar(setting), value) then return false end
	end
	for setting, index in pairs(def.flags or NONE) do
		if not C_CVar.GetCVarBitfield(setting, index) then return false end
	end
	return true
end

local function Kept()
	ShyCoreDB.game = ShyCoreDB.game or {}
	return ShyCoreDB.game
end

-- A refused CVar is recorded and never tried or offered again.
local function Lock(setting)
	local book = Book()
	book.locked = book.locked or {}
	book.locked[setting] = true
end

-- SetCVar fails silently for CVars the game keeps from addons (RequiresNonSecureCVar), so the value is
-- read back. True when it was set.
local function Write(setting, value)
	C_CVar.SetCVar(setting, value)
	if Same(C_CVar.GetCVar(setting), value) then return true end
	Lock(setting)
	return false
end

-- One switch of a CVar that holds several, read back the same way.
local function Flag(setting, index, on)
	C_CVar.SetCVarBitfield(setting, index, on)
	if (C_CVar.GetCVarBitfield(setting, index) and true or false) == on then return true end
	Lock(setting)
	return false
end

-- True when every CVar of the entry is as wanted afterwards.
function S.Take(def)
	if def.take then return def.take(Kept()) end
	local kept, took = Kept(), true
	for setting, value in pairs(def.want or NONE) do
		local now = C_CVar.GetCVar(setting)
		if not Same(now, value) then
			if Write(setting, value) then
				if kept[setting] == nil then kept[setting] = now end
			else
				took = false
			end
		end
	end
	for setting, index in pairs(def.flags or NONE) do
		if not C_CVar.GetCVarBitfield(setting, index) then
			if Flag(setting, index, true) then
				local key = setting .. ":" .. index
				if kept[key] == nil then kept[key] = "0" end
			else
				took = false
			end
		end
	end
	return took
end

-- Restores the kept value, else the CVar's default, else `off` or the opposite: unticking must
-- always change something. A flag goes off.
function S.Return(def)
	local kept = Kept()
	if def.back then
		def.back(kept)
		return
	end
	for setting, value in pairs(def.want or NONE) do
		local was = kept[setting]
		if was == nil or Same(was, value) then was = C_CVar.GetCVarDefault(setting) end
		if was == nil or Same(was, value) then was = def.off and def.off[setting] or (Same(value, "1") and "0" or "1") end
		kept[setting] = nil
		Write(setting, was)
	end
	for setting, index in pairs(def.flags or NONE) do
		kept[setting .. ":" .. index] = nil
		Flag(setting, index, false)
	end
end

-- Game settings a page puts on live for the open window's plan (ShyDock's screen: the pieces its layout
-- holds, so they are up when it is laid out), given back when the window closes without Finish or when
-- their row is unticked.
local took = {}

-- on: put it on now, if the plan picks it and it isn't on already; off: give back what was put on.
-- True when something changed.
function S.Live(key, on)
	local def = took[key]
	if not on then
		if not def then return false end
		took[key] = nil
		S.Return(def)
		return true
	end
	if def or not S.Picked(key) then return false end
	for _, entry in ipairs(S.GAME) do
		if entry.key == key then
			if S.Is(entry) or not S.Take(entry) then return false end
			took[key] = entry
			return true
		end
	end
	return false
end

-- With a plan the checkbox is a pick for later (one a page put on live goes off with it); without one it
-- switches the setting live.
local function GameRow(f, group, def, plan, enabled)
	local get, set
	if plan then
		-- (A plan ticks the ones already set: unticked, Finish turns one off.)
		get = function() return plan.game.pick[def.key] == true end
		set = function(v)
			plan.game.pick[def.key] = v
			if not v then S.Live(def.key, false) end
		end
	else
		get = function() return S.Is(def) end
		set = function(v)
			-- Many CVars can't be set in combat.
			if InCombatLockdown() then
				core:Print("game settings can't be changed in combat.")
				return
			end
			if v then S.Take(def) else S.Return(def) end
			if S.Is(def) ~= v then
				core:Print("\"" .. def.title .. "\" " .. (def.fail or "can only be changed in the game's Options window."))
			elseif def.reload then
				Shy.Reload(def.reload)
			end
		end
	end
	-- Dimmed while the master switch is off, or while something else switches this setting.
	local row = group:Checkbox(f, def.title, get, set, { desc = def.desc, enabled = function()
		return (not enabled or enabled()) and not Owned(def)
	end })
	if plan then
		-- Green: already set that way, so leaving it ticked changes nothing.
		local Base = row.Refresh
		function row:Refresh()
			Base(self)
			UI.Ink(self.text, (S.Is(def) and not took[def.key]) and C.good or C.text)
		end
	end
	return row
end

function S.GameList(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local group = UI.Group()
	local top, enabled = 0, nil
	if plan then
		local all = group:Checkbox(f, "Apply recommended game settings",
			function() return plan.game.on end, function(v) plan.game.on = v end,
			{ desc = "Applies the settings ticked below during setup. Green ones are already set. You can undo any of them later on /shy." })
		all:SetPoint("TOPLEFT")
		top = MASTER
		enabled = function() return plan.game.on end
	end
	local tallest, rows = top, Rows()
	local columns = COLUMNS[width >= WIDE and 3 or 2]
	for column, names in ipairs(columns) do
		local x, y = (column - 1) * (width + 10) / #columns, top
		for _, name in ipairs(names) do
			local any = false
			for _, def in ipairs(rows) do
				if def.group == name then
					if not any then
						any = true
						local sub = UI.Text(f, name:upper(), 11, true, C.dim)
						sub:SetPoint("TOPLEFT", x, -y)
						y = y + SUB
					end
					GameRow(f, group, def, plan, enabled):SetPoint("TOPLEFT", x, -y)
					y = y + ROW
				end
			end
			if any then y = y + BETWEEN end
		end
		tallest = max(tallest, y - BETWEEN)
	end
	f:SetSize(width, tallest)
	function f:Refresh() group:Refresh() end
	return f
end

-- Steps

local steps = {}

function S.Step(def)
	for i, step in ipairs(steps) do
		if step.id == def.id then table.remove(steps, i) break end
	end
	steps[#steps + 1] = def
	table.sort(steps, function(a, b) return a.order < b.order end)
	return def
end

function S.Plan(plan)
	plan = plan or {}
	for _, step in ipairs(steps) do
		if step.Plan then step.Plan(plan) end
	end
	return plan
end

function S.Check(plan)
	if InCombatLockdown() then return false, "You're in combat. Run setup after the fight." end
	for _, step in ipairs(steps) do
		if step.Check then
			local ok, why = step.Check(plan)
			if not ok then return false, why end
		end
	end
	return true
end

local function Settled()
	for _, step in ipairs(steps) do
		if step.Settled and step.Settled() then return true end
	end
	return false
end

function S.Done()
	return Mine().done ~= nil or Settled()
end

-- Printed once when setup is over (after its reload, if it had one).
local function Tell()
	local mine = Mine()
	if mine.said then return end
	mine.said = true
	core:Print(First() .. " is set up. Change anything later with /shy.")
	if mine.left then
		core:Print("these can only be changed in the game's Options window and were left alone: " .. mine.left .. ".")
		mine.left = nil
	end
end

-- "Interface action failed because of an AddOn" names nothing and shows once a session, so the last
-- ten blocked actions of any addon named Shy* are kept in ShyCoreDB.setup.refused for diagnosis.
local running
local refusals = CreateFrame("Frame")
refusals:RegisterEvent("ADDON_ACTION_BLOCKED")
refusals:RegisterEvent("ADDON_ACTION_FORBIDDEN")
refusals:SetScript("OnEvent", function(_, event, addon, what)
	if not ShyCoreDB or type(addon) ~= "string" or issecretvalue(addon) or not addon:find("^Shy") then return end
	local book = Book()
	book.refused = book.refused or {}
	table.insert(book.refused, 1, { at = time(), addon = addon, what = tostring(what), during = running })
	book.refused[11] = nil
end)

-- Under pcall: a failing step must not stop the others or the reload.
local function RunStep(step, plan)
	running = step.id
	local ok, result = pcall(step.Run, plan)
	running = nil
	if not ok then geterrorhandler()(result) end
	return ok and result
end

local DONE = "Setup complete. Reload to apply it."

-- Ordinary steps first, then `last` ones, then one reload through Shy.Reload if any step asked for it.
-- held: the caller reloads itself (the window's Finish button): nothing asks for a reload, the window
-- stays for the caller to close, and the third result says whether to reload.
function S.Run(plan, held)
	local ok, why = S.Check(plan)
	if not ok then return false, why end
	local mine = Mine()
	mine.asked, mine.done, mine.said, mine.left = true, time(), nil, nil
	mine.round = ROUND   -- every recommendation was on the game step's page
	plan.act = nil
	local reload = false
	if held then Shy.HoldReload(true) end
	for _, step in ipairs(steps) do
		if not step.last and step.Run and RunStep(step, plan) then reload = true end
	end
	if not held then S.Close() end
	for _, step in ipairs(steps) do
		if step.last and step.Run and RunStep(step, plan) then reload = true end
	end
	if held then
		reload = Shy.HoldReload(false) or reload
		if not reload then Tell() end
		return true, nil, reload
	end
	if reload then Shy.Reload(DONE) else Tell() end
	return true
end

-- The profile step

-- Returns act ("stay" | "use" | "fresh"), profile name, why not, kind.
local function Target(plan)
	local pick, current, me = plan.profile, P.Current(), P.Character()
	if pick.choice == "global" then
		return current == P.GLOBAL and "stay" or "use", P.GLOBAL
	elseif pick.choice == "other" then
		if not pick.other then return nil, nil, "Pick the profile to use." end
		return current == pick.other and "stay" or "use", pick.other
	elseif pick.choice == "new" then
		local name, why = P.Free(pick.name)
		if not name then
			return nil, nil, why == "empty" and "Enter a name for the new profile." or ("There is already a profile called " .. strtrim(pick.name) .. ".")
		end
		return "fresh", name, nil, "custom"
	end
	return "fresh", S.Untouched() and P.GLOBAL or me, nil, "character"
end

-- Once the profile step has run, its act is kept in the plan: Target would answer "stay" by then.
function S.Act(plan)
	return plan.act or (Target(plan))
end

-- The steps in their order, for whoever lists what a plan will do.
function S.Steps()
	return steps
end

local function OtherProfiles()
	local items = {}
	for _, entry in ipairs(P.List()) do
		if entry.kind ~= "global" and not entry.new then
			items[#items + 1] = { value = entry.name, text = P.Label(entry) .. (entry.current and "  (in use)" or "") }
		end
	end
	return items
end

local function ProfileLines(plan)
	local act, name, why = Target(plan)
	local first, me = First(), P.Character()
	if not act then return { { text = why, bad = true } } end
	if act == "stay" then
		return { { text = first .. " stays on " .. (name == P.GLOBAL and "Global" or name),
			sub = name == P.GLOBAL and "the profile your characters share; nothing changes" or "nothing changes" } }
	elseif act == "use" then
		return { { text = first .. " uses " .. (name == P.GLOBAL and "Global" or name),
			sub = "shared with every character that uses it; the old profile keeps its settings" } }
	elseif name == P.GLOBAL then
		return { { text = "Every addon on default settings", sub = "saved in Global, shared by every character that hasn't picked another" } }
	elseif name == me then
		return { { text = first .. " gets default settings in a profile of their own",
			sub = ShyCoreDB.profiles[me] and "their own profile goes back to defaults; no other character is affected" or "your other characters keep theirs" } }
	end
	return { { text = "New profile " .. name .. " on default settings", sub = "other characters can pick it later" } }
end

local TILE_H, GAP = 76, 8

-- A choice: a picture, a name, a sentence, a word at its right. The picture is a glyph in a well (one
-- of S.GLYPH, or the caller's own drawn on b.glyph), or with `icon` an icon of the game's, which stands
-- in a slot and is given by SetIcon. Under the sentence a second one in the caution color (b.note), for
-- a choice that has a catch.
--   b:Paint(on, tag, off, tagColor)   on: picked. tag: true shows the word "in use", a string says that
--                                     instead (in tagColor, else dim). off: can't be picked.
local function Tile(parent, width, glyph, name, onClick, height, icon)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, height or TILE_H)
	UI.Skin(b)
	b.glow = b:CreateTexture(nil, "BORDER", nil, -1)
	b.glow:SetTexture(Skin.GLOW)
	b.glow:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	b.glow:SetPoint("TOPLEFT", -3, 3)
	b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	UI.Tint(b.glow, C.hot, 0.6)
	b.well = CreateFrame("Frame", nil, b)
	b.well:SetSize(40, 40)
	b.well:SetPoint("TOPLEFT", 8, -8)
	if icon then
		b.icon = b.well:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		b.slot = Shy.Slot.New(b.well, { icon = b.icon, hover = false })
	else
		UI.Skin(b.well, C.bg, C.border)
		b.glyph = b.well:CreateTexture(nil, "ARTWORK")
		b.glyph:SetTexture(glyph)
		b.glyph:SetSize(24, 24)
		b.glyph:SetPoint("CENTER")
	end
	b.name = UI.Text(b, name, 15, true)
	b.name:SetPoint("TOPLEFT", 58, -8)
	b.tag = UI.Text(b, "in use", 10, true, C.good)
	b.tag:SetPoint("TOPRIGHT", -8, -10)
	b.say = UI.Text(b, "", 11, false, C.dim)
	b.say:SetPoint("TOPLEFT", 58, -28)
	b.say:SetWidth(width - 66)
	b.say:SetWordWrap(true)
	b.note = UI.Text(b, "", 11, false, C.alert)
	b.note:SetPoint("TOPLEFT", b.say, "BOTTOMLEFT", 0, -3)
	b.note:SetWidth(width - 66)
	b.note:SetWordWrap(true)

	-- The game's icon for a tile made with `icon`; nil leaves the slot empty.
	function b:SetIcon(texture)
		self.icon:SetTexture(texture)
		self.slot:Empty(texture == nil)
	end

	function b:Paint(on, tag, off, tagColor)
		self.on, self.dimmed = on, off
		self:SetAlpha(off and 0.45 or 1)
		self.tag:SetShown(tag and true or false)
		if type(tag) == "string" then
			self.tag:SetText(tag)
			UI.Ink(self.tag, tagColor or C.dim)
		end
		UI.SetFill(self, on and C.row or C.bg)
		UI.SetBorder(self, (on or self.hover) and C.hot or C.border)
		if self.glyph then
			UI.SetBorder(self.well, on and C.hot or C.border)
			UI.Tint(self.glyph, on and Theme.light or C.dim)
		end
		UI.Ink(self.name, on and C.head or C.text)
		self.glow:SetShown(on and true or false)
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick()
	end)
	b:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		UI.SetBorder(self, self.on and C.hot or C.border)
	end)
	return b
end
S.Tile = Tile

local function ProfilePage(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(width, 2 * TILE_H + GAP)
	local half = (width - GAP) / 2

	local tiles, others, name = {}, nil, nil
	local function Paint()
		local choice, current = plan.profile.choice, P.Current()
		tiles.default:Paint(choice == "default")
		tiles.global:Paint(choice == "global", current == P.GLOBAL)
		tiles.other:Paint(choice == "other", current ~= P.GLOBAL, f.none)
		tiles.new:Paint(choice == "new")
	end
	local function Choose(choice)
		return function()
			plan.profile.choice = choice
			Paint()
		end
	end
	tiles.default = Tile(f, half, S.GLYPH.star, "Default setup", Choose("default"))
	tiles.default:SetPoint("TOPLEFT", 0, 0)
	tiles.global = Tile(f, half, S.GLYPH.globe, "Global", Choose("global"))
	tiles.global:SetPoint("TOPLEFT", half + GAP, 0)
	tiles.other = Tile(f, half, S.GLYPH.people, "Another profile", Choose("other"))
	tiles.other:SetPoint("TOPLEFT", 0, -TILE_H - GAP)
	tiles.new = Tile(f, half, Skin.GLYPH.plus, "A new profile", Choose("new"))
	tiles.new:SetPoint("TOPLEFT", half + GAP, -TILE_H - GAP)

	-- No label: the tile's name is the label.
	others = UI.Dropdown(tiles.other, "", {}, function() return plan.profile.other end, function(v)
		plan.profile.other, plan.profile.choice = v, "other"
		Paint()
	end, { width = half - 66 - 4, desc = "Share a profile another character uses or one you named. A change on one character applies to all of them." })
	others:SetPoint("TOPLEFT", 58, -8)

	name = UI.Input(tiles.new, nil, function() return plan.profile.name end, function(v)
		plan.profile.name, plan.profile.choice = v, "new"
		Paint()
	end, { width = half - 66 - 4, maxLetters = 24, live = true, placeholder = function() return "Name" end,
		desc = "A named profile on default settings. Other characters can pick it too." })
	name:SetPoint("TOPLEFT", 58, -28)
	name.box:HookScript("OnEditFocusGained", Choose("new"))
	-- One line under the box; it must not wrap out of the tile.
	tiles.new.say:ClearAllPoints()
	tiles.new.say:SetPoint("TOPLEFT", 58, -57)
	tiles.new.say:SetWordWrap(false)
	tiles.new.say:SetText("Starts from the defaults.")

	function f:Refresh()
		local first, untouched, users = First(), S.Untouched(), Others(P.GLOBAL)
		tiles.default.say:SetText(untouched and "Every addon on default settings. Your other characters share them until they pick another."
			or ("Default settings for " .. first .. " alone. Your other characters keep theirs."))
		tiles.global.say:SetText(untouched and "One setup for every character. Nobody has changed it yet."
			or #users > 2 and ("One setup for every character. " .. #users .. " of yours use it.")   -- a list of names wouldn't fit the tile
			or #users > 0 and ("One setup for every character. " .. Listed(users) .. (#users == 1 and " uses it." or " use it."))
			or "One setup for every character that hasn't picked another.")
		local items, found = OtherProfiles(), false
		for _, item in ipairs(items) do
			if item.value == plan.profile.other then found = true end
		end
		if not found then plan.profile.other = items[1] and items[1].value end
		self.none = #items == 0
		if self.none and plan.profile.choice == "other" then plan.profile.choice = "global" end
		others:SetItems(items)
		others:SetShown(not self.none)
		tiles.other.say:SetText(self.none and "No other profiles yet." or "")
		name:Refresh()
		Paint()
	end
	return f
end

S.Step({
	id = "profile", order = 10, title = "Profile", glyph = "group",
	ask = function() return "Which profile should " .. First() .. " use?" end,
	lead = "A profile holds every addon's settings and your layout.",
	brief = function(plan)
		local act, name = Target(plan)
		if not act then return nil end
		return name == P.GLOBAL and "Global" or name
	end,
	Plan = function(plan)
		local current = P.Current()
		plan.profile = { name = "", choice = "global" }
		if S.Untouched() then
			plan.profile.choice = "default"
		elseif current ~= P.GLOBAL then
			plan.profile.choice, plan.profile.other = "other", current
		end
	end,
	Build = ProfilePage,
	Check = function(plan)
		local act, _, why = Target(plan)
		return act ~= nil, why
	end,
	Lines = ProfileLines,
	Run = function(plan)
		local act, name, _, kind = Target(plan)
		-- Kept for later steps: once the profile has changed, Target would answer "stay".
		plan.act = act
		if act == "use" then return P.Use(name) end
		if act == "fresh" then return P.Fresh(name, kind) end
		return false
	end,
})

-- The theme's step is Chooser.lua's: the same flow as the /shy window's Theme room.

-- The game step

-- Entries a plan would change: those to put on (picked, not set yet), then those to turn off (set, and
-- unticked: the plan ticks every one already set).
local function Changing(plan)
	local on, off = {}, {}
	if plan.game.on then
		for _, def in ipairs(S.Offered()) do
			local pick, is = plan.game.pick[def.key], S.Is(def)
			if pick and not is then
				on[#on + 1] = def
			elseif not pick and is then
				off[#off + 1] = def
			end
		end
	end
	return on, off
end

local function Changed(plan)
	local on, off = Changing(plan)
	return #on + #off
end

S.Step({
	id = "game", order = 30, title = "Game", tabTitle = "Game settings", glyph = "log",   -- one word: the rail holds every page's title
	ask = "Pick the game settings to change",
	lead = "The recommended ones are ticked; green ones are set already. Untick one to turn it off.",
	brief = function(plan) return Changes(Changed(plan)) end,
	changes = Changed,
	Plan = function(plan)
		plan.game = { on = true, pick = {} }
		for _, def in ipairs(S.GAME) do plan.game.pick[def.key] = def.on or S.Is(def) end
	end,
	Build = function(parent, width, plan) return S.GameList(parent, width, plan) end,
	Lines = function(plan)
		local on, off = Changing(plan)
		local n = #on + #off
		if n == 0 then
			return { { text = "Game settings stay as they are",
				sub = plan.game.on and "the picked ones are already set" or "none picked" } }
		end
		-- The review's line has room for two lines of names.
		local sub = Named(on, 8)
		if #off > 0 then
			local parts = {}
			if #on > 0 then parts[#parts + 1] = #on .. " on (" .. Named(on, 4) .. ")" end
			parts[#parts + 1] = #off .. " off (" .. Named(off, 4) .. ")"
			sub = table.concat(parts, "; ")
		end
		return { { text = n == 1 and "1 game setting changes" or (n .. " game settings change"), sub = sub } }
	end,
	Run = function(plan)
		local left, reload = {}, false
		local on, off = Changing(plan)
		for _, def in ipairs(on) do
			if not S.Take(def) then
				left[#left + 1] = def.title
			elseif def.reload then
				reload = true
			end
		end
		for _, def in ipairs(off) do
			S.Return(def)
			if S.Is(def) then
				left[#left + 1] = def.title
			elseif def.reload then
				reload = true
			end
		end
		Mine().left = #left > 0 and Listed(left) or nil   -- printed by Tell
		return reload
	end,
})

-- Questions: an addon's own switches as a setup step
--
-- The page shows the `ask` items (up to ten) as two columns of switches; "Show all" lists every item
-- by group, flowing through all the room the window gives it.
--
--   Shy.Setup.Questions{ id, order, title,
--       noun = "tweaks",                 plural, for the page's text
--       ask = "Which tweaks do you want?",   the question over the page ("Which <noun> do you want?" unless given)
--       lead = "A sentence over the short list.",
--       groups = { "Windows", ... },     in the order the full list shows them
--       items = function() return { {
--           key, group, title, desc,     desc: hover text
--           default = bool,
--           ask = true, order = n,       on the short list, and where
--           suggest = bool, say = "..."  suggested answer, and one line under the title (must not wrap)
--           get = function() end, set = function(on) end,
--       }, ... } end }
--
-- Applied when setup runs: every switch the player touched, plus the asked ones as shown, unless the
-- character is joining an existing profile (then only what was touched). When the profile changes,
-- the answers wait in ShyCoreDB.setup.chars[character].pending and are applied after the reload,
-- once the profile's settings are loaded.

local questions = {}   -- by step id
local Q_ROW, Q_GAP, Q_MOST = 38, 6, 10
local Q_SLIM, Q_SLIM_GAP = 28, 4   -- the full list's rows: the title alone
local Q_COL, Q_CAPTION, Q_BREAK = 280, 17, 8   -- the full list's narrowest column, a group's caption, between groups
local Q_FOOT = 8 + 24   -- under the list: the button

-- Starting state: each switch as it is now; an asked one still on its default takes the suggestion.
local function FillAnswers(def, plan)
	local state = { pick = {}, touched = {}, all = false }
	for _, item in ipairs(def.items()) do
		local now = item.get() and true or false
		if item.ask and item.suggest ~= nil and now == (item.default or false) then now = item.suggest end
		state.pick[item.key] = now
	end
	plan[def.id] = state
end

local function Answers(def, plan)
	local state, act = plan[def.id], plan.act or Target(plan)
	local out = {}
	for _, item in ipairs(def.items()) do
		if state.touched[item.key] or (item.ask and act ~= "use") then out[item.key] = state.pick[item.key] end
	end
	return out
end

local function SetAnswers(def, answers)
	for _, item in ipairs(def.items()) do
		local want = answers[item.key]
		if want ~= nil and (item.get() and true or false) ~= want then
			local ok, err = pcall(item.set, want)
			if not ok then geterrorhandler()(err) end
		end
	end
end

-- The whole row is the switch. opts: height (a taller row, its words kept at its middle); slim (a
-- shorter row with the title alone).
local function QuestionRow(parent, width, item, Get, Set, opts)
	local slim = opts and opts.slim
	local tall = slim and Q_SLIM or (opts and opts.height or Q_ROW)
	local lift = (tall - Q_ROW) / 2
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, tall)
	UI.Skin(b)
	b.lit = b:CreateTexture(nil, "ARTWORK")
	b.lit:SetPoint("TOPLEFT", 1, -1)
	b.lit:SetPoint("BOTTOMLEFT", 1, 1)
	b.lit:SetWidth(2)
	UI.Paint(b.lit, Theme.Accent)
	b.switch = UI.Switch(b, item.title, Get, Set, { desc = item.desc })
	b.switch:SetPoint("LEFT", 10, 0)
	b.name = UI.Text(b, item.title, 13)
	if slim then
		b.name:SetPoint("LEFT", 56, 0)
		b.name:SetPoint("RIGHT", -6, 0)
		b.name:SetJustifyH("LEFT")
		b.name:SetWordWrap(false)
	else
		b.name:SetPoint("TOPLEFT", 56, -5 - lift)
		b.say = UI.Text(b, item.say or "", 11, false, C.dim)
		b.say:SetPoint("TOPLEFT", 56, -21 - lift)
		b.say:SetWidth(width - 62)
		b.say:SetWordWrap(false)
	end

	function b:Refresh()
		local on = Get()
		self.switch:Refresh()
		self.lit:SetShown(on)
		UI.SetFill(self, on and C.row or C.bg)
		UI.Ink(self.name, on and C.head or C.text)
	end
	b:SetScript("OnClick", function()
		Set(not Get())
		PlaySound(Get() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end)
	b:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		UI.Tip(self, item.title, item.desc, { side = "RIGHT" })
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.TipHide(self)
	end)
	return b
end
S.Row = QuestionRow

local function QuestionsPage(parent, width, plan, def, room)
	local f = CreateFrame("Frame", nil, parent)
	local shortH = 5 * Q_ROW + 4 * Q_GAP   -- five rows
	room = room or shortH + Q_FOOT
	f:SetSize(width, shortH + Q_FOOT)
	local items = def.items()
	local half = (width - GAP) / 2
	local rows, full, captions = {}, {}, {}
	local function Getter(item)
		return function() return plan[def.id].pick[item.key] end
	end
	local function Setter(item)
		return function(v)
			local state = plan[def.id]
			state.pick[item.key], state.touched[item.key] = v, true
			f:Refresh()
		end
	end

	local asked = {}
	for _, item in ipairs(items) do
		if item.ask then asked[#asked + 1] = item end
	end
	table.sort(asked, function(a, b) return (a.order or 0) < (b.order or 0) end)
	local short = CreateFrame("Frame", nil, f)
	short:SetPoint("TOPLEFT", 0, 0)
	short:SetSize(width, shortH)
	for i = 1, math.min(#asked, Q_MOST) do
		local item = asked[i]
		local row = QuestionRow(short, half, item, Getter(item), Setter(item))
		row:SetPoint("TOPLEFT", ((i - 1) % 2) * (half + GAP), -math.floor((i - 1) / 2) * (Q_ROW + Q_GAP))
		rows[#rows + 1] = row
	end

	-- The full list is built on first use: the short list's switches, slimmer, by group. It flows: down
	-- a column to the foot of the room, on in the next, a group's caption again over the rest of it. Past
	-- the last column it carries on under them all, and scrolls.
	local all, groups
	local function Flow(inner, view)
		local n = max(1, math.floor((inner + GAP) / (Q_COL + GAP)))
		local col = (inner - (n - 1) * GAP) / n
		local band, column, y, heads = 0, 1, 0, 0
		local function Spot()
			return (column - 1) * (col + GAP), -(band * (view + Q_BREAK) + y)
		end
		-- On to the next column when `need` won't fit under what this one holds.
		local function Room(need)
			if y == 0 or y + need <= view then return false end
			y, column = 0, column + 1
			if column > n then column, band = 1, band + 1 end
			return true
		end
		-- A group's caption: its name, and the section heading's rule on to the column's edge.
		local function Caption(name)
			heads = heads + 1
			local cap = captions[heads]
			if not cap then
				cap = CreateFrame("Frame", nil, all.content)
				cap:SetHeight(Q_CAPTION - 4)
				cap.text = UI.Text(cap, "", 11, true, C.dim)
				cap.text:SetPoint("LEFT")
				cap.rule = cap:CreateTexture(nil, "ARTWORK")
				UI.Paint(cap.rule, C.border, 0.7)
				cap.rule:SetHeight(1)
				cap.rule:SetPoint("LEFT", cap.text, "RIGHT", 8, 0)
				cap.rule:SetPoint("RIGHT")
				captions[heads] = cap
			end
			cap.text:SetText(name:upper())
			cap:SetWidth(col)
			cap:ClearAllPoints()
			cap:SetPoint("TOPLEFT", Spot())
			cap:Show()
			y = y + Q_CAPTION
		end
		for _, group in ipairs(groups) do
			if y > 0 then y = y + Q_BREAK end
			Room(Q_CAPTION + Q_SLIM)
			Caption(group.name)
			for _, row in ipairs(group.rows) do
				if Room(Q_SLIM) then Caption(group.name) end
				row:SetWidth(col)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", Spot())
				y = y + Q_SLIM + Q_SLIM_GAP
			end
		end
		for i = heads + 1, #captions do captions[i]:Hide() end
		return band
	end
	-- The whole width while it fits; room for the scroll bar once it doesn't.
	local function LayAll()
		local view = all:GetHeight()
		local band = Flow(width, view)
		if band > 0 then band = Flow(width - 14, view) end
		all.content:SetWidth(band > 0 and width - 14 or width)
		all.content:SetHeight((band + 1) * (view + Q_BREAK) - Q_BREAK)
		all:Update()
	end
	local function BuildAll()
		all = UI.ScrollArea(f, width, max(shortH, room - Q_FOOT))
		all:SetPoint("TOPLEFT", 0, 0)
		groups = {}
		for _, name in ipairs(def.groups) do
			local group = { name = name, rows = {} }
			for _, item in ipairs(items) do
				if item.group == name then
					local row = QuestionRow(all.content, Q_COL, item, Getter(item), Setter(item), { slim = true })
					group.rows[#group.rows + 1] = row
					full[#full + 1] = row
				end
			end
			if #group.rows > 0 then groups[#groups + 1] = group end
		end
		LayAll()
	end

	local toggle = UI.Button(f, "", 190, function()
		plan[def.id].all = not plan[def.id].all
		f:Refresh()
	end)
	toggle:SetPoint("BOTTOMLEFT")
	local count = UI.Text(f, "", 12, false, C.dim)
	count:SetPoint("BOTTOMRIGHT", 0, 5)

	-- The room under the section's heading, as the window flows.
	function f:Fit(height)
		room = height
		if not all then return end
		all:SetHeight(max(shortH, room - Q_FOOT))
		LayAll()
		self:Refresh()
	end

	function f:Refresh()
		local state = plan[def.id]
		local showAll = state.all or #rows == 0
		if showAll and not all then BuildAll() end
		short:SetShown(not showAll)
		if all then all:SetShown(showAll) end
		self:SetHeight((showAll and all:GetHeight() or shortH) + Q_FOOT)
		S.Relabel()   -- (the section's lead says which list this is)
		toggle:SetShown(#rows > 0)
		toggle.text:SetText(showAll and "Back to the short list" or ("Show all " .. #items .. " " .. def.noun))
		for _, row in ipairs(rows) do row:Refresh() end
		if showAll then
			for _, row in ipairs(full) do row:Refresh() end
			all:Update()
		end
		local on = 0
		for _, item in ipairs(items) do
			if state.pick[item.key] then on = on + 1 end
		end
		count:SetText(on .. " of " .. #items .. " on")
	end
	return f
end

local function QuestionLines(def, plan)
	local state, act = plan[def.id], Target(plan)
	local noun = def.noun:gsub("^%l", string.upper)
	if act ~= "stay" then
		local on, answers = 0, Answers(def, plan)
		for _, want in pairs(answers) do
			if want then on = on + 1 end
		end
		if next(answers) == nil then return { { text = noun .. " as the profile has them", sub = "none changed here" } } end
		return { { text = noun .. " as you picked them", sub = on .. " switched on; applied after the reload" } }
	end
	local on, off, answers = {}, {}, Answers(def, plan)
	for _, item in ipairs(def.items()) do
		local want = answers[item.key]
		if want ~= nil and want ~= (item.get() and true or false) then
			local list = want and on or off
			list[#list + 1] = (item.title:gsub("^%u", string.lower))
		end
	end
	if #on + #off == 0 then return { { text = noun .. " stay as they are", sub = #def.items() .. " in all; none changed" } } end
	local parts = {}
	if #on > 0 then parts[#parts + 1] = #on .. " switched on (" .. Listed(on) .. ")" end
	if #off > 0 then parts[#parts + 1] = #off .. " switched off (" .. Listed(off) .. ")" end
	return { { text = noun .. ": " .. (#on + #off) .. (#on + #off == 1 and " changes" or " change"), sub = table.concat(parts, "; ") } }
end

function S.Questions(def)
	questions[def.id] = def
	return S.Step({
		id = def.id, order = def.order, title = def.title, glyph = def.glyph, tab = def.tab,
		ask = def.ask or ("Which " .. def.noun .. " do you want?"),
		lead = function(plan)
			local state = plan[def.id]
			return state and state.all and ("All " .. def.noun .. " by category. Hover one to see what it does.") or def.lead
		end,
		brief = function(plan)
			local state, items, on = plan[def.id], def.items(), 0
			for _, item in ipairs(items) do
				if state.pick[item.key] then on = on + 1 end
			end
			return on .. " of " .. #items .. " on"
		end,
		-- Those picked otherwise than they stand now.
		changes = function(plan)
			local n, answers = 0, Answers(def, plan)
			for _, item in ipairs(def.items()) do
				local want = answers[item.key]
				if want ~= nil and want ~= (item.get() and true or false) then n = n + 1 end
			end
			return n
		end,
		Plan = function(plan) FillAnswers(def, plan) end,
		Build = function(parent, width, plan, room) return QuestionsPage(parent, width, plan, def, room) end,
		Lines = function(plan) return QuestionLines(def, plan) end,
		Run = function(plan)
			local answers = Answers(def, plan)
			if (plan.act or Target(plan)) == "stay" then
				SetAnswers(def, answers)
			else
				local mine = Mine()
				mine.pending = mine.pending or {}
				mine.pending[def.id] = answers
			end
			return false
		end,
	})
end

function S.Wait(id, answers)
	local mine = Mine()
	mine.pending = mine.pending or {}
	mine.pending[id] = answers
end

-- After a reload: apply the answers that waited for the new profile to load.
local function SetPending()
	local mine = Mine()
	for id, answers in pairs(mine.pending or {}) do
		if questions[id] then
			SetAnswers(questions[id], answers)
		else
			for _, step in ipairs(steps) do
				if step.id == id and step.Later then
					local ok, err = pcall(step.Later, answers)
					if not ok then geterrorhandler()(err) end
				end
			end
		end
	end
	mine.pending = nil
end

-- The window: a rail of pages down its left, each with what it holds now under its name; the one on show stands
-- beside the rail under its own question. A page is a step; steps on one subject share a page as its tabs (a
-- step's `tab`: the layout's page holds the cooldown manager, the game's the tweaks). It opens on the
-- overview: every step's pick on a card, in columns (GROUPS), each recommended from the start, so Finish there
-- sets a character up in one click and a click on a card goes to its step. Next and Back walk the pages and
-- their tabs in order; Finish stands on every page, so a character set up before can open one, change it and
-- finish. A page coming up fades in; nothing moves.

local FOOT, PAD, PAGE_H = 46, 40, 538
local HEADER = UI.HEAD.main.line + UI.LINE   -- a main window's header, down to its line's foot
local EDGE, NAV_W = 2, 220   -- the window's own edge; the steps down its left (UI.Rail), flush with it
local NAV_H = 16 + PAGE_H + 12   -- the rail: from the header's line to the foot's
local SECTION_W = 1000   -- the page on show beside the rail
local SECTION_X = EDGE + NAV_W + PAD   -- its left: the window's padding from the rail's rule
local WIDTH = SECTION_X + SECTION_W + 40   -- the page's scroll bar and the window's edge after it
local HEAD_H = UI.LEAD_H   -- a page's heading, down to the page
local TABS_H = 42          -- a page's tabs (the steps sharing it), down to its heading
-- The foot's buttons: in from the window's right edge and up from its foot, each one's width, between two, and
-- each side of the divider.
local FEET = { EDGE = 14, UP = 11, NEXT = 110, BACK = 76, FINISH = 110, GAP = 8, DIVIDE = 12 }
local STRIP_GAP = 22 -- under a strip standing over a page's heading (a step `inside` another)
local FADE = 0.15    -- seconds a page takes to come up
local MADE_H = HEADER + 16 + PAGE_H + 12 + FOOT   -- the window as made; it flows taller, never wider
-- The size is no page: it is a strip over the profile's page (its step is `inside` the profile's), so it is
-- the first thing set and every preview after it is drawn at the size the screen will have.
-- The overview's columns, and the pages in the rail's order with them.
local GROUPS = {
	{ title = "You", steps = { "profile" } },
	{ title = "Your screen", steps = { "theme", "screen" } },
	{ title = "How you play", steps = { "immersion", "talents", "dungeons" } },
	{ title = "The game", steps = { "game" } },
}
local OVERVIEW = "overview"
-- The overview: its band (BAND tall, an accent EDGE down its left, your face in a ring: RING its art's size,
-- Dial's, FACE the face in it), then a column a group under its caption, a card a step (its glyph in a WELL).
local CARD = { H = 92, GAP = 10, CAPTION = 24, GLYPH = "note", WELL = 36, BAND = 88, EDGE = 3, RING = 56, FACE = 38 }
-- at: the page on show (OVERVIEW or its step's id); tabs: each page's tab on show, by page; order: the pages in
-- the rail's order; done: the steps gone past, by id; first: what each step held as the window opened, by id;
-- wasDone: the character was set up before it opened; pageH: the page's height at the window's height now.
local win = { open = false, plan = {}, pages = {}, at = OVERVIEW, tabs = {}, order = {}, done = {}, first = {}, pageH = PAGE_H }

-- The room a page has under its heading.
local function Room() return win.pageH - HEAD_H end

-- The steps standing inside another's page (`inside`: that step's id), in order.
local function Insides(host)
	local out = {}
	for _, step in ipairs(steps) do
		if step.inside == host.id then out[#out + 1] = step end
	end
	return out
end

local function Step(id)
	for _, step in ipairs(steps) do
		if step.id == id then return step end
	end
end

-- The step whose page another stands on as a tab (its `tab`), while that step is here with a page.
local function Host(step)
	local host = step.tab and Step(step.tab)
	return host and host.Build and not host.inside and not host.tab and host or nil
end

-- A page's steps, in the order of its tabs: its own, then those standing on it.
local function Parts(host)
	local out = { host }
	for _, step in ipairs(steps) do
		if step.Build and Host(step) == host then out[#out + 1] = step end
	end
	return out
end

-- The groups with their pages, in order; a step no group names stands in a group of its own before the game's.
-- A step inside another's page or a tab of it has no page of its own, nor has one with nothing to show (it
-- only runs).
local function Groups()
	local out, placed = {}, {}
	for _, step in ipairs(steps) do
		if step.inside or Host(step) or not step.Build then placed[step] = true end
	end
	for _, def in ipairs(GROUPS) do
		local group = { title = def.title, steps = {} }
		for _, id in ipairs(def.steps) do
			for _, step in ipairs(steps) do
				if step.id == id and not placed[step] then
					group.steps[#group.steps + 1] = step
					placed[step] = true
				end
			end
		end
		out[#out + 1] = group
	end
	local more = { title = "More", steps = {} }
	for _, step in ipairs(steps) do
		if not placed[step] then more.steps[#more.steps + 1] = step end
	end
	table.insert(out, #out, more)
	for i = #out, 1, -1 do
		if #out[i].steps == 0 then table.remove(out, i) end
	end
	return out
end

local function Said(value, plan)
	if type(value) == "function" then return value(plan) end
	return value
end

-- A cinematic or movie on screen (a new character's intro): setup waits for it.
local function Watching()
	return InCinematic() or CinematicFrame:IsShown() or MovieFrame:IsShown()
end

-- The screen stays up while the window is open, the first time too: every pick shows on it as it is made
-- (the look, the layout, the cooldown manager), so nothing fades and the window stands in the empty room in
-- its middle (Stand).
local function Awake(on)
	if Shy.Immersion then Shy.Immersion.Hold("setup", on) end
end

-- The window in the empty room in the screen's middle (Shy.HUD.Room), as large as fits there (never under
-- MIN_FIT), unless the player has put it somewhere. Where they put it is their screen's, not a profile's
-- (positions are a profile's, and the window opens as profiles are picked, made and switched to): it is
-- kept for the account too, and the window stands there again in any profile.
local MIN_FIT = 0.6
local function Stand()
	local box = win.box
	if InCombatLockdown() then return end
	local spot = ShyCoreDB and ShyCoreDB.setupSpot
	if spot and not Shy.HUD.IsPlaced(box) then Shy.HUD.SetSpot(box, spot) end
	if Shy.HUD.IsPlaced(box) then return end
	local l, b, r, t = Shy.HUD.Room(box)
	local w, h = box:GetWidth(), box:GetHeight()
	local fit = math.max(MIN_FIT, math.min(1, (r - l) / w, (t - b) / h))
	local x, y = (l + r) / 2 - UIParent:GetWidth() / 2, (b + t) / 2 - UIParent:GetHeight() / 2
	Shy.HUD.SetHome(box, { "CENTER", "CENTER", x / fit, y / fit }, fit)
end

-- Does the window still stand in the room? (A layout picked moves what closes it in.)
local function Fits()
	local box = win.box
	local left, bottom = box:GetLeft(), box:GetBottom()
	if not (left and bottom) then return true end
	local l, b, r, t = Shy.HUD.Room(box)
	local s = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return left * s >= l - 1 and bottom * s >= b - 1
		and (left + box:GetWidth()) * s <= r + 1 and (bottom + box:GetHeight()) * s <= t + 1
end

-- Picks go on as they are made, so the window and the screen show them. Each step that does so hands what
-- stood before (its Worn, when the window opens) and puts it back (its PutBack) when the window closes
-- without Finish. moving: Finish switched profile, so only what the old profile holds goes back; the picks
-- follow the new one after the reload (S.Wait).
local function Worn()
	local kept = {}
	for _, step in ipairs(steps) do
		if step.Worn then kept[step.id] = step.Worn() end
	end
	return kept
end
local function PutBack(moving)
	local kept = win.kept
	win.kept = nil
	-- (Setup ran since it opened: what is worn is the answer.)
	if not kept or (not moving and Mine().done ~= win.doneWas) then return end
	for _, step in ipairs(steps) do
		if step.PutBack and kept[step.id] ~= nil then
			local ok, err = pcall(step.PutBack, kept[step.id], moving)
			if not ok then geterrorhandler()(err) end
		end
	end
	-- (Game settings aren't the profile's: switching profile, they stay.)
	if not moving then
		for key in pairs(took) do S.Live(key, false) end
	end
end

local Go

-- What a step holds now, in a few words (its `brief`), and in a sentence (what stands under its first line, else the line).
local function Brief(step)
	local ok, said = pcall(Said, step.brief, win.plan)
	return ok and said or nil
end
local function Line(step)
	if not step.Lines then return nil end
	local ok, lines = pcall(step.Lines, win.plan)
	local line = ok and lines and lines[1]
	if not line then return nil end
	-- (What stands under the line says more than the line, which the few words over it already say.)
	local said = line.sub ~= nil and line.sub ~= "" and not line.bad and line.sub or line.text
	return (said:gsub("^%l", string.upper)), line.bad
end

-- What a page holds now. A page with tabs that each count what they change: how many changes Finish makes
-- across them all (one tab's brief alone reads as the page's).
local function PageBrief(step)
	local parts, n = Parts(step), 0
	if #parts < 2 then return Brief(step) end
	for _, part in ipairs(parts) do
		if not part.changes then return Brief(step) end
		local ok, c = pcall(part.changes, win.plan)
		if not ok or type(c) ~= "number" then return Brief(step) end
		n = n + c
	end
	return Changes(n)
end

-- What every page holds now, by its step's id, for the rail.
local function Briefs()
	local out = {}
	for _, id in ipairs(win.order) do
		local step = Step(id)
		if step then out[id] = PageBrief(step) end
	end
	return out
end

-- Where a step shows: its page's key and its tab there.
local function Place(id)
	local step = Step(id)
	if not step then return id == OVERVIEW and OVERVIEW or nil end
	if step.inside then return Place(step.inside) end
	local host = Host(step) or step
	for i, part in ipairs(Parts(host)) do
		if part == step then return host.id, i end
	end
end

-- A card of the overview: a step's glyph in a well, its name, what it holds now and that in a sentence. At its
-- corner, how the pick stands: a check while it is the one recommended (a first setup), "changed" once it is
-- another than the window opened with. A click goes to the step's page (a step inside another's or a tab of
-- it: to that page, at its tab).
local function Card(parent, width, step)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, CARD.H)
	UI.Skin(b)
	b.well = CreateFrame("Frame", nil, b)
	b.well:SetSize(CARD.WELL, CARD.WELL)
	b.well:SetPoint("TOPLEFT", 10, -10)
	UI.Skin(b.well, C.bg, C.border)
	b.glyph = b.well:CreateTexture(nil, "ARTWORK")
	b.glyph:SetPoint("CENTER")
	if not UI.GlyphArt(b.glyph, step.glyph or CARD.GLYPH) then b.glyph:SetSize(16, 16) end
	UI.Tint(b.glyph, C.dim)
	local x = 10 + CARD.WELL + 10
	b.name = UI.Text(b, step.title:upper(), 11, true, C.dim)
	b.name:SetPoint("TOPLEFT", x, -11)
	b.value = UI.Text(b, "", 15, true, C.head)
	b.value:SetPoint("TOPLEFT", x, -27)
	b.value:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	b.value:SetWordWrap(false)
	b.says = UI.Text(b, "", 11, false, C.dim)
	b.says:SetPoint("TOPLEFT", 10, -(10 + CARD.WELL + 8))
	b.says:SetPoint("RIGHT", b, "RIGHT", -10, 0)
	b.says:SetJustifyV("TOP")
	b.says:SetWordWrap(true)
	b.says:SetMaxLines(2)
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetTexture(MEDIA .. "GlyphCheckS")   -- drawn for 12 units
	b.check:SetSize(12, 12)
	b.check:SetPoint("TOPRIGHT", -10, -10)
	UI.Tint(b.check, C.good)
	b.tag = UI.Text(b, "changed", 10, true, C.alert)
	b.tag:SetPoint("TOPRIGHT", -10, -11)
	b.step = step
	function b:Refresh()
		local brief = Brief(step)
		local line, bad = Line(step)
		self.value:SetText(brief or step.title)
		self.says:SetText(line or "")
		UI.Ink(self.says, bad and C.alert or C.dim)
		local changed = win.first[step.id] ~= nil and brief ~= win.first[step.id]
		self.tag:SetShown(changed)
		self.check:SetShown(not changed and not win.wasDone)
	end
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		Go(Place(step.id))
	end)
	b:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		UI.SetBorder(self.well, C.hot)
		UI.Tint(self.glyph, Theme.light)
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.SetBorder(self.well, C.border)
		UI.Tint(self.glyph, C.dim)
	end)
	return b
end

-- The overview: a band that names the character, then a column a group under its caption, a card a step (one
-- inside another's page or a tab of it under its host).
local function Overview(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(SECTION_W, PAGE_H)
	local band = CreateFrame("Frame", nil, f)
	band:SetSize(SECTION_W, CARD.BAND)
	band:SetPoint("TOPLEFT")
	UI.Skin(band, C.row, C.border)
	local edge = band:CreateTexture(nil, "ARTWORK")
	edge:SetPoint("TOPLEFT", 1, -1)
	edge:SetPoint("BOTTOMLEFT", 1, 1)
	edge:SetWidth(CARD.EDGE)
	Theme.Paint(edge, Theme.Accent, 1)
	-- Your character's face in a ring, as the game draws it.
	local ring = band:CreateTexture(nil, "ARTWORK")
	ring:SetTexture(MEDIA .. "Dial")
	ring:SetSize(CARD.RING, CARD.RING)
	ring:SetPoint("CENTER", band, "LEFT", CARD.EDGE + 16 + CARD.RING / 2, 0)
	UI.Tint(ring, Theme.skin.metal)
	f.face = band:CreateTexture(nil, "ARTWORK", nil, 1)
	f.face:SetSize(CARD.FACE, CARD.FACE)
	f.face:SetPoint("CENTER", ring, "CENTER")
	local round = band:CreateMaskTexture()
	round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	round:SetAllPoints(f.face)
	f.face:AddMaskTexture(round)
	UI.Concentric(ring, f.face)
	local x = CARD.EDGE + 16 + CARD.RING + 16
	f.title = UI.Text(band, "", 20, true, C.head)
	f.title:SetPoint("BOTTOMLEFT", band, "LEFT", x, 2)
	f.words = UI.Text(band, "", 12, false, C.dim)
	f.words:SetPoint("TOPLEFT", band, "LEFT", x, -6)
	f.words:SetPoint("RIGHT", band, "RIGHT", -16, 0)
	f.words:SetWordWrap(false)

	f.cards = {}
	local groups = Groups()
	local each = (SECTION_W - (#groups - 1) * CARD.GAP * 2) / #groups
	local tall = 0
	for column, group in ipairs(groups) do
		local x0, y = (column - 1) * (each + CARD.GAP * 2), CARD.BAND + 20
		local caption = UI.Text(f, group.title:upper(), 11, true, C.dim)
		caption:SetPoint("TOPLEFT", x0, -y)
		local rule = f:CreateTexture(nil, "ARTWORK")
		Theme.Paint(rule, C.border, 0.6)
		rule:SetHeight(1)
		rule:SetPoint("LEFT", caption, "RIGHT", 10, 0)
		rule:SetPoint("RIGHT", f, "TOPLEFT", x0 + each, -y - 6)
		y = y + CARD.CAPTION
		for _, host in ipairs(group.steps) do
			local list = { host }
			for _, inner in ipairs(Insides(host)) do
				if inner.brief then list[#list + 1] = inner end
			end
			for i, part in ipairs(Parts(host)) do
				if i > 1 then list[#list + 1] = part end
			end
			for _, step in ipairs(list) do
				local card = Card(f, each, step)
				card:SetPoint("TOPLEFT", x0, -y)
				f.cards[#f.cards + 1] = card
				y = y + CARD.H + CARD.GAP
			end
		end
		tall = max(tall, y)
	end
	f.tall = tall
	function f:Relabel()
		SetPortraitTexture(self.face, "player")
		local first = First()
		if win.wasDone then
			self.title:SetText(first .. " is set up like this")
			self.words:SetText("Click anything to change it, then Finish.")
		else
			self.title:SetText("Ready when you are, " .. first)
			self.words:SetText("Everything is picked for you. Finish sets it all up at once; click anything to change it first.")
		end
	end
	function f:Fit() end
	function f:Refresh()
		for _, card in ipairs(self.cards) do card:Refresh() end
		self:SetHeight(max(win.pageH, self.tall))
	end
	return f
end

-- A page: its step under a heading (the step's question, its sentence under), with the steps inside it as
-- strips over that and the steps sharing it as tabs between, one on show at a time under its own heading. The
-- page is laid again on every refresh: it may grow.
local function StepPage(parent, host)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(SECTION_W, PAGE_H)
	f.step, f.parts, f.strips, f.sections, f.top, f.open = host, Parts(host), {}, {}, 0, 1
	-- The steps inside this one: each a strip over its heading, top down.
	for _, inner in ipairs(Insides(host)) do
		local strip = inner.Build(f, SECTION_W, win.plan, Room())
		strip:ClearAllPoints()
		strip:SetPoint("TOPLEFT", 0, -f.top)
		f.strips[#f.strips + 1] = strip
		f.top = f.top + strip:GetHeight() + STRIP_GAP
	end
	if #f.parts > 1 then
		local labels = {}
		for i, part in ipairs(f.parts) do labels[i] = part.tabTitle or part.title end
		f.tabs = UI.Tabs(f, labels, function(i)
			if win.tabs[host.id] ~= i and win.shown == host.id then Go(host.id, i) end
		end, SECTION_W, 15)
		f.tabs:SetPoint("TOPLEFT", 0, -f.top)
		f.top = f.top + TABS_H
	end
	f.lead = UI.Lead(f, SECTION_W)
	f.lead:SetPoint("TOPLEFT", 0, -f.top)
	for i, part in ipairs(f.parts) do
		local section = part.Build(f, SECTION_W, win.plan, Room() - f.top)
		section:ClearAllPoints()
		section:SetPoint("TOPLEFT", 0, -f.top - HEAD_H)
		f.sections[i] = section
	end
	-- The tab on show: its section alone, its name lit.
	function f:Open(i)
		self.open = math.min(max(i or 1, 1), #self.parts)
		for j, section in ipairs(self.sections) do section:SetShown(j == self.open) end
		if self.tabs and self.tabs.selected ~= self.open then self.tabs:Select(self.open) end
	end
	-- (A step's words failing must not stop the page: its title stands, and the error is told.)
	function f:Relabel()
		local part = self.parts[self.open]
		local ok, ask = pcall(Said, part.ask, win.plan)
		if not ok then geterrorhandler()(ask) end
		local fine, lead = pcall(Said, part.lead, win.plan)
		if not fine then geterrorhandler()(lead) end
		self.lead:Set(ok and ask or part.title, fine and lead or "")
	end
	function f:Fit()
		for _, section in ipairs(self.sections) do
			if section.Fit then section:Fit(Room() - self.top) end
		end
	end
	function f:Refresh()
		for _, strip in ipairs(self.strips) do strip:Refresh() end
		local section = self.sections[self.open]
		section:Refresh()
		local h = section:GetHeight()
		self:SetHeight(max(win.pageH, self.top + HEAD_H + ((type(h) == "number" and not issecretvalue(h)) and h or 0)))
	end
	f:Open(1)
	return f
end

-- The scroll area's content as tall as the page on show; it scrolls when that is taller than the window's page.
local function Tall(f)
	local box, tall = win.box, f:GetHeight()
	tall = max(win.pageH, (type(tall) == "number" and not issecretvalue(tall)) and tall or win.pageH)
	-- (Only where it is another: the game lays every page out again for a height it is given anew.)
	if box.content.shyTall ~= tall then
		box.content.shyTall = tall
		box.content:SetHeight(tall)
	end
	box.scroll:Update()
end

-- Each piece of a page's showing on the clock (the task manager): a click on the rail is all of them.
local function Lap(name, from)
	local now = debugprofilestop()
	Shy.Clock(name):Lap(now - from)
	return now
end

local function Index(key)
	for i, at in ipairs(win.order) do
		if at == key then return i end
	end
end

local function Show()
	local box = win.box
	local at = Index(win.at) or 1
	local key = win.order[at]
	win.at = key
	local host = key ~= OVERVIEW and Step(key) or nil
	local lap = debugprofilestop()
	-- The rail: what each page holds now, those gone past checked, the one on show open.
	box.nav:SetSubs(Briefs())
	for _, id in ipairs(win.order) do
		local step, done = Step(id), id ~= OVERVIEW
		for _, part in ipairs(step and Parts(step) or {}) do done = done and win.done[part.id] == true end
		box.nav:SetDone(id, done)
	end
	box.nav:Select(key, true)
	lap = Lap("setup: the rail told", lap)
	-- Pages are built on first visit.
	if not win.pages[key] then
		local f = host and StepPage(box.content, host) or Overview(box.content)
		f:SetPoint("TOPLEFT")
		win.pages[key] = f
		lap = Lap("setup: a page made", lap)
	end
	for id, f in pairs(win.pages) do f:SetShown(id == key) end
	lap = Lap("setup: the page shown, the others put away", lap)
	local f = win.pages[key]
	local parts = host and f.parts or {}
	local tab = math.min(max(win.tabs[key] or 1, 1), max(#parts, 1))
	win.tabs[key] = tab
	win.shown = key
	if host then f:Open(tab) end
	-- A step whose picks go on the screen puts its plan on as its page comes up (Shown), so the screen
	-- already is what the page shows. The overview shows every pick: one that goes on as the window opens
	-- (`atOpen`: the size, so everything after is drawn at it) is put on there.
	if host or key == OVERVIEW then
		local each = host and Insides(host) or {}
		each[#each + 1] = parts[tab]
		for _, step in ipairs(host and {} or steps) do
			if step.atOpen then each[#each + 1] = step end
		end
		for _, shown in ipairs(each) do
			if shown.Shown then
				local ok, err = pcall(shown.Shown, win.plan)
				if not ok then geterrorhandler()(err) end
			end
		end
	end
	lap = Lap("setup: the page opened, its plan put on the screen", lap)
	-- The page's heading, and the page comes up with a fade when it is a new one.
	S.Relabel()
	local section = key .. " " .. tab
	if win.section ~= section then
		win.section = section
		UI.FadeIn(f, FADE)
	end
	lap = Lap("setup: the page's heading, its fade begun", lap)
	f:Refresh()
	lap = Lap("setup: the page read again", lap)
	-- The page scrolls when it is taller than the window's; each starts at its top. (Set only where it
	-- isn't there: the game lays the page out again for a scroll it is given anew.)
	local scrolled = box.scroll:GetVerticalScroll()
	if issecretvalue(scrolled) or scrolled ~= 0 then box.scroll:SetVerticalScroll(0) end
	Tall(f)
	lap = Lap("setup: the page scrolled to its top and measured", lap)
	-- The foot: Back and Next at the window's right end, the way through the pages, Next last so it never
	-- moves under the mouse; Finish before them past a divider: it ends the walk, they go on with it. On the
	-- last page there is nothing to go on to, and Finish takes Next's place. The one to press stands filled:
	-- Finish on the overview and the last page, Next between them. Finish is dimmed while a step can't go
	-- ahead; its hover says why. (It is placed and its attributes set only out of combat: it is protected, and
	-- the window steps aside in a fight anyway.)
	local first, last = at == 1, at == #win.order and tab >= #parts
	box.back:SetShown(not first)
	box.next:SetShown(not last)
	box.next:SetPrimary(not first)
	box.divider:SetShown(not last)
	local finish = box.finish
	local ok, why = S.Check(win.plan)
	finish.dimmed = not ok
	finish.why = why
	finish:SetAlpha(ok and 1 or 0.4)
	finish:SetPrimary(first or last)
	if not InCombatLockdown() then
		-- How far in from the right edge the walk's buttons reach; Finish stands past the divider from there.
		local walk = FEET.EDGE + FEET.NEXT + (first and 0 or FEET.GAP + FEET.BACK)
		box.back:ClearAllPoints()
		box.back:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(FEET.EDGE + (last and FEET.FINISH or FEET.NEXT) + FEET.GAP), FEET.UP)
		box.divider:ClearAllPoints()
		box.divider:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(walk + FEET.DIVIDE), FEET.UP + 1)
		finish:ClearAllPoints()
		finish:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(last and FEET.EDGE or walk + 2 * FEET.DIVIDE + 1), FEET.UP)
		finish:Show()
		finish.armed = nil
		finish:SetAttribute("type", nil)
	end
end

-- The step on show, or nil on the overview.
local function Showing()
	local f = win.at ~= OVERVIEW and win.pages[win.at]
	return f and f.parts[win.tabs[win.at] or 1] or nil
end

-- The step on show is gone past: checked off from here on.
local function Leave()
	local step = Showing()
	if step then win.done[step.id] = true end
end

-- To a page, by its key, at a tab of it (the one it had open unless told; "last": its last).
function Go(key, tab)
	if not key or (key == win.at and (not tab or tab == win.tabs[key])) then return end
	Leave()
	win.at = key
	if tab then
		local step = Step(key)
		win.tabs[key] = tab == "last" and (step and #Parts(step) or 1) or tab
	end
	Show()
end

-- Next and Back walk a page's tabs, then the pages, in the rail's order.
local function Forward()
	local at = Index(win.at) or 1
	local step = Step(win.at)
	local tab = win.tabs[win.at] or 1
	if step and tab < #Parts(step) then Go(win.at, tab + 1) elseif at < #win.order then Go(win.order[at + 1], 1) end
end

local function Backward()
	local at = Index(win.at) or 1
	local tab = win.tabs[win.at] or 1
	if tab > 1 then Go(win.at, tab - 1) elseif at > 1 then Go(win.order[at - 1], "last") end
end

-- The page's heading again: the step's question and its sentence.
function S.Relabel()
	local box = win.box
	if not (box and win.open) then return end
	local f = win.pages[win.at]
	if f then f:Relabel() end
end

-- The open window's plan (nil while it is closed), for whoever lists what it will do.
function S.Current()
	return win.open and win.plan or nil
end

-- The step on show, by its id ("overview" there); nil while the window is closed.
function S.At()
	if not win.open then return nil end
	local step = Showing()
	return step and step.id or OVERVIEW
end

-- The window flows taller: the page, the rail beside it and every page built take the height. Wider (maximized),
-- the pages keep the width they are laid out for, SECTION_W, a readable one every step's page is built to, and
-- stand in the middle of the room there is. Nothing is scaled.
local function Lay(_, width, height)
	win.pageH = height - (HEADER + 16 + 12 + FOOT)
	local box = win.box
	if not (box and box.scroll) then return end
	local extra = math.max(0, math.floor(((width or WIDTH) - WIDTH) / 2))
	box.scroll:ClearAllPoints()
	box.scroll:SetPoint("TOPLEFT", SECTION_X + extra, -(HEADER + 16))
	box.scroll:SetHeight(win.pageH)
	box.nav:SetHeight(16 + win.pageH + 12)
	box.navRule:SetHeight(16 + win.pageH + 12)
	for _, f in pairs(win.pages) do f:Fit() end
	local f = win.shown and win.pages[win.shown]
	if f and win.open then
		f:Refresh()
		Tall(f)
	end
end

local function Build()
	-- Secure: the Finish button reloads, so the window is hidden in a fight by a state driver and
	-- comes back after it.
	local box = UI.Window({
		id = "shysetup", name = "ShySetupWindow", title = "Set up", width = WIDTH, height = MADE_H,
		grip = { flow = Lay, min = { WIDTH, MADE_H }, max = { WIDTH } },
		point = { "CENTER", "CENTER", 0, 40 }, shown = function() return win.open end, secure = true, strata = "HIGH",
		maximize = true,
		-- Closed by Esc. A fight hides it too (its state driver), and then it stays open to come back:
		-- by the next frame the fight has locked things down. A cinematic taking the screen closes it
		-- as well; that isn't the player's answer, so it is offered again once the cinematic is over.
		onClose = function(self)
			C_Timer.After(0, function()
				if self:IsShown() or InCombatLockdown() or not win.open then return end
				win.open = false
				Awake(false)
				PutBack()
				Shy.HUD.Update(self)
				if not Watching() then Mine().asked = true end
			end)
		end,
		close = function() S.Close() end,
		-- The title stands above the middle, the name under it: the two share the strip's middle.
		head = { icon = Shy.ICON, title = "Set up", lift = 7, panel = { glazed = true } },
	})
	win.box = box
	-- Moved: kept for the account (Stand). Let go of at its home: nothing kept, it finds the room again.
	Shy:On("SHY_HUD_MOVED", function(moved)
		if moved == box and ShyCoreDB then ShyCoreDB.setupSpot = Shy.HUD.Spot(box) end
	end)
	-- Solid whatever the screen under it does.
	box:SetIgnoreParentAlpha(true)
	local header = box.head
	local what = header.title
	-- A player name: UI.NameFont covers every alphabet. Their level and class after it.
	local who = UI.Text(header, "", 12, false, C.hot)
	who:SetFontObject(UI.NameFont(12))
	UI.Ink(who, C.hot)
	who:SetText(First())
	who:SetPoint("TOPLEFT", what, "BOTTOMLEFT", 1, -2)
	local whoElse = UI.Text(header, "", 12, false, C.dim)
	whoElse:SetPoint("LEFT", who, "RIGHT", 6, 0)
	whoElse:SetText(("\194\183  level %d %s"):format(UnitLevel("player"), (UnitClass("player"))))
	box.who = whoElse

	-- The rail: the overview, then every page; a click opens one.
	local items = { { key = OVERVIEW, label = "Overview", glyph = "home" } }
	win.order = { OVERVIEW }
	for _, group in ipairs(Groups()) do
		for _, step in ipairs(group.steps) do
			items[#items + 1] = { key = step.id, label = step.title, glyph = step.glyph or CARD.GLYPH }
			win.order[#win.order + 1] = step.id
		end
	end
	box.nav = UI.Rail(box, function(key) Go(key) end, { width = NAV_W, height = NAV_H })
	box.nav:SetPoint("TOPLEFT", EDGE, -HEADER)
	box.nav:SetItems(items)
	-- One rule down the rail's right, from the header's line to the foot's.
	box.navRule = box:CreateTexture(nil, "ARTWORK")
	UI.Paint(box.navRule, C.border, 0.7)
	box.navRule:SetWidth(1)
	box.navRule:SetPoint("TOPLEFT", EDGE + NAV_W, -HEADER)
	box.navRule:SetHeight(NAV_H)
	-- What each step holds now, under its name and on the overview's cards, kept up as picks change.
	local since = 0
	box:HookScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since < 0.25 or not win.open then return end
		since = 0
		box.nav:SetSubs(Briefs())
		local f = win.at == OVERVIEW and win.pages[OVERVIEW]
		if f then f:Refresh() end
	end)
	-- The page on show stands on a scroll area's content; one taller than the window's page scrolls (Show).
	box.scroll = UI.ScrollArea(box, SECTION_W + 14, PAGE_H)
	box.scroll:SetPoint("TOPLEFT", SECTION_X, -(HEADER + 16))
	box.content = box.scroll.content
	box.content:SetWidth(SECTION_W)

	local rule = box:CreateTexture(nil, "ARTWORK")
	UI.Paint(rule, C.border, 0.7)
	rule:SetHeight(1)
	rule:SetPoint("BOTTOMLEFT", 2, FOOT)
	rule:SetPoint("BOTTOMRIGHT", -2, FOOT)
	local later = UI.Button(box, "Not now", 86, function() S.Close() end)
	later:SetPoint("BOTTOMLEFT", 14, 11)
	later:HookScript("OnEnter", function(self) UI.Tip(self, "Not now", "Closes this. /shy setup opens it again.", { side = "TOP" }) end)
	later:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	box.later = later

	-- Finish: sets everything up and, when that needs a reload, reloads in the same click. The game
	-- refuses an addon the reload itself; a secure button running /reload is allowed. Its PreClick runs
	-- the setup (held: no Reload panel) and arms the button only when a reload is wanted. Down and up
	-- both reach it (the reload fires on whichever the game acts on), so it runs once per click.
	-- Show places it (a protected button anchors to its window alone).
	local finish = CreateFrame("Button", nil, box, "SecureActionButtonTemplate")
	finish:SetSize(FEET.FINISH, 24)
	finish:SetPoint("BOTTOMRIGHT", -FEET.EDGE, FEET.UP)
	finish:RegisterForClicks("AnyUp", "AnyDown")
	finish:SetAttribute("macrotext", SLASH_RELOAD1)
	UI.ButtonFace(finish, "Finish")
	finish:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		UI.Tip(self, "Finish", self.dimmed and self.why or "Applies everything you picked, with one reload if needed. Change any of it later with /shy.", { side = "TOP" })
	end)
	finish:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.TipHide(self)
	end)
	-- armed: nil before a click; "reload" (the macro fires), "done" (nothing to reload) or "failed".
	finish:SetScript("PreClick", function(self)
		if self.armed ~= nil or self.dimmed or InCombatLockdown() then return end
		local ok, why, reload = S.Run(win.plan, true)
		-- What is worn now is the answer; switching profile, the old one keeps what it had.
		if ok and S.Act(win.plan) ~= "stay" then PutBack(true) elseif ok then win.kept = nil end
		if ok then wipe(took) end   -- what a page put on live is set up now
		self.armed = not ok and "failed" or reload and "reload" or "done"
		if reload and ok then
			self:SetAttribute("type", "macro")
			-- Should the click never reach the game's action (released off the button), the panel finishes it.
			C_Timer.After(1, function()
				if self.armed ~= "reload" then return end
				self.armed = nil
				S.Close()
				Shy.Reload(DONE)
			end)
		elseif not ok then
			core:Print(why)
		end
	end)
	finish:SetScript("PostClick", function(self, _, down)
		if down or self.armed == "reload" then return end
		local done = self.armed == "done"
		self.armed = nil
		if not InCombatLockdown() then self:SetAttribute("type", nil) end
		if done then S.Close() elseif win.open then Show() end
	end)
	finish:Hide()
	box.finish = finish

	-- Next at the window's right end and Back before it, the way through the pages, and the divider between
	-- them and Finish (Show places Back, the divider and Finish).
	box.next = UI.Button(box, "Next", FEET.NEXT, function() Forward() end)
	box.next:SetPoint("BOTTOMRIGHT", -FEET.EDGE, FEET.UP)
	box.back = UI.Button(box, "Back", FEET.BACK, function() Backward() end)
	box.back:SetPoint("BOTTOMRIGHT", -(FEET.EDGE + FEET.NEXT + FEET.GAP), FEET.UP)
	box.divider = box:CreateTexture(nil, "ARTWORK")
	UI.Paint(box.divider, C.border, 0.9)
	box.divider:SetSize(1, 22)

	-- Combat starting or ending changes whether setup can run. A layout put on (a pick on the screen page)
	-- or a size (the size page) moves the screen: once it has settled, the window stands again if it no
	-- longer fits the room.
	box:RegisterEvent("PLAYER_REGEN_DISABLED")
	box:RegisterEvent("PLAYER_REGEN_ENABLED")
	box:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	box:RegisterEvent("UI_SCALE_CHANGED")
	box:RegisterEvent("DISPLAY_SIZE_CHANGED")
	box:SetScript("OnEvent", function(_, event)
		if not win.open then return end
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			Show()
			return
		end
		-- (A pick can be laid out a moment after its click, once what it switched on is up: the page shows it then.)
		local f = win.shown and win.pages[win.shown]
		if f and f:IsShown() then f:Refresh() end
		C_Timer.After(0.6, function()
			if win.open and not InCombatLockdown() and not Fits() then Stand() end
		end)
	end)
	-- (A kept height may have been put on before the page was here to take it.)
	Lay(box, box:GetWidth(), box:GetHeight())
end

function S.IsOpen() return win.open end

-- For a step whose page draws what setup will leave (ShyDock's screen): does the open window's plan
-- switch this game setting on.
function S.Picked(key)
	if not win.open then return nil end
	local game = win.plan.game
	if not (game and game.on and game.pick[key]) then return false end
	for _, def in ipairs(S.Offered()) do
		if def.key == key then return true end
	end
	return false
end

-- win.plan is refilled in place, never replaced: the pages hold a reference to it. `at`: the step to open
-- on (its id), the overview unless told.
function S.Open(at)
	if not win.box then Build() end
	if not win.open then
		S.Plan(win.plan)
		win.at = OVERVIEW
		wipe(win.tabs)
		wipe(win.done)
		win.kept, win.doneWas, win.wasDone = Worn(), Mine().done, S.Done()
		wipe(took)
		wipe(win.first)
		for _, step in ipairs(steps) do win.first[step.id] = Brief(step) end
	end
	local key, tab = Place(at)
	if key and Index(key) then
		win.at = key
		win.tabs[key] = tab
	end
	win.open = true
	Awake(true)
	Shy.HUD.Update(win.box)
	Stand()
	Show()
end

-- Closing it is the player's answer: the window isn't offered again on its own.
function S.Close()
	if not win.box then return end
	Mine().asked = true
	win.open = false
	Awake(false)
	PutBack()
	Shy.HUD.Update(win.box)
end

-- First login, the hub and /shy setup

local WAIT = 7   -- seconds after login: the splash is gone and Edit Mode layouts are loaded
local AFTER = 2  -- seconds after a cinematic or movie: the world is back in view
local settled
local offer = CreateFrame("Frame")   -- what holds the offer back ending: a fight, a cinematic, a movie

-- Once per round of recommendations: a character set up before it (or, Settled, before there was a
-- window, so it has seen none) is told which recommended settings of the newer rounds it doesn't have.
local function Remind()
	local mine = Mine()
	if not S.Done() or (mine.round or 0) >= ROUND then return end
	local seen = mine.round or (mine.done and 1 or 0)
	mine.round = ROUND
	local missing = {}
	for _, def in ipairs(S.Offered()) do
		if def.on and (def.round or 1) > seen and not S.Is(def) then missing[#missing + 1] = def end
	end
	if #missing == 0 then return end
	core:Print((#missing == 1 and "a recommended game setting isn't set for " or (#missing .. " recommended game settings aren't set for "))
		.. First() .. ": " .. Named(missing, 6) .. ". Tick " .. (#missing == 1 and "it" or "them") .. " under Game settings in /shy.")
end

-- Until the character is set up or the player closes the window; never in combat or over a cinematic
-- or movie (a new character's intro), retried when they end; skipped when a step is already Settled.
local function Offer()
	if not settled or win.open or InCombatLockdown() or Watching() then return end
	local mine = Mine()
	if mine.asked or mine.done then
		offer:UnregisterAllEvents()
		return
	end
	if Settled() then
		mine.asked = true
		offer:UnregisterAllEvents()
		Remind()
		return
	end
	S.Open()
end

offer:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then Offer() else C_Timer.After(AFTER, Offer) end
end)
-- A movie skipped by the player ends without an event.
MovieFrame:HookScript("OnHide", function() C_Timer.After(AFTER, Offer) end)

Shy:On("SHY_ADDON_LOADED", function(a)
	if a ~= core then return end
	if core.isNew then Book().untouched = true end
	RepairDock()
end)

Shy:On("SHY_LOGIN", function()
	RepairDock()   -- again, past the chat windows' own load
	local book, mine = Book(), Mine()
	if next(book.chars, (next(book.chars))) then book.untouched = nil end   -- a second character exists
	SetPending()
	if mine.done and not mine.said then C_Timer.After(4, Tell) end
	if mine.asked or mine.done then
		C_Timer.After(WAIT, Remind)
		return
	end
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "CINEMATIC_STOP", "STOP_MOVIE" }) do offer:RegisterEvent(event) end
	C_Timer.After(WAIT, function()
		settled = true
		Offer()
	end)
end)

Shy.Command("setup", "set up this character: profile, layout and game settings", function() S.Open() end)

-- The /shy window's Game room: the same list, each row switched as it is ticked.
Shy.HubSection("game", function(page, top)
	local list = S.GameList(page, page.width)
	Shy.HubPlace(page, list, top)
	return list, function() list:Refresh() end
end)

-- How many of the recommended ones are set.
Shy.HubBrief("game", function()
	local on, of = 0, 0
	for _, def in ipairs(S.Offered()) do
		if def.on then
			of = of + 1
			if S.Is(def) then on = on + 1 end
		end
	end
	return on == of and "All recommended set" or ("%d of %d recommended"):format(on, of)
end)
