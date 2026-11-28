-- Shy.Setup: character setup. The /shy window, lent to it, walks a few steps (profile, game settings, plus steps
-- other addons register), each picked as recommended from the start and shown together on its overview, then
-- S.Run applies them all with at most one reload. Offered at every login until the character is set up
-- (once its intro has played), and opened from /shy setup and from the /shy window's Home, whose rooms hold the
-- same pieces as live sections. While it is open the screen stays up and every pick goes on it as it is made;
-- nothing is kept until Finish.
--
--   Shy.Setup.Step{ id, order, title,     registered by the addon that owns the step
--       glyph,                            its picture on the rail and its overview card (UI.GlyphArt's names)
--       ask, lead,                        the question its page answers and a sentence under it, its heading
--       brief,                            what it holds now in a few words ("Forged"), under its name on the
--                                         rail and on its overview card; a string or function(plan)
--                                         (each a string or a function of the plan; the window draws them)
--       told(plan),                       false: nothing was worked out for it yet (the talents of a character
--                                         with none), so the welcome leaves its pick out
--       why(plan),                        why it picked that, in a few words that read after it ("fits your
--                                         2560 x 1440 screen"); nil with nothing worth saying. The welcome says it
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
--       Follow(plan),                     the build picked changed (plan.talents.build): read the plan again
--                                         (the screen: the layout that build's role has)
--       guided = true,                    one of the few pages a new player is walked through. The others, and
--                                         every page's further tabs, are the advanced ones: picked as recommended
--                                         and out of sight until asked for (S.Advanced). With no guided step
--                                         registered, every page is walked
--       last = true,                      run after the others
--       inside = id,                      no page of its own: its Build is a strip over that step's
--                                         heading, on its page (shown with it; Shown runs with it)
--       tab = id,                         no page of its own while that step has one: it is a tab of that
--                                         step's page, after the step's own (a subject's steps together)
--       tabTitle,                         its tab's name there, when its title alone would not say it
--       walk = id,                        one of the pages of that step's own walk (see S.Walk): no row of its
--                                         own on the rail nor a card on the overview; it hangs under that step's
--                                         row, and is walked after it, while the step's `walks(plan)` says so
--       walks(plan),                      a step with a walk of its own: whether its pages are walked now
--       Later(answers),                   answers kept by S.Wait, given back after the reload
--       Shown(plan),                      its page came up: put the plan's picks on the screen
--       Wear(plan),                       for a step with no Shown whose picks go on live: put the plan's on (the
--                                         welcome's Undo)
--       Picture(parent, width, height),   its pick drawn small, as its page draws it, for its line on the welcome:
--                                         a frame with :Refresh(plan) (false: nothing to draw, its glyph instead)
--       Restate(plan),                    what it planned read again, the world changed under it (a layout made
--                                         by hand): see S.Restate
--       resets(plan), Reset(plan),        a quick way back on the welcome's line: resets names it ("Reset",
--                                         "Set up"; nil: none), Reset puts the recommended pick in the plan
--       now(plan),                        what stands now that finishing would replace ("the game's layout"), for
--                                         the welcome's line to say; nil: it stands as planned
--       atOpen = true,                    its Shown runs as the overview comes up too (the size: the first
--                                         thing set, whatever page is opened next)
--       Worn(),                           for a step whose picks go on as they are made: what stands now,
--       PutBack(kept, moving) }           put back when the window closes without Finish (moving: Finish
--                                         switched profile, so only the old profile's settings go back)
--   Shy.Setup.Act(plan)        what the profile step does: "stay", "use" or "fresh"
--   Shy.Setup.Wait(id, answers)   a step's profile settings, applied after the reload once the profile has loaded
--   Shy.Setup.Tile(parent, width, glyph, name, onClick, height, icon)   a choice tile, as the profile page has them
--   Shy.Setup.Row(parent, width, item, get, set)   a whole-row tick: item = { title, desc, say }
--   Shy.Setup.Questions{ ... }            an addon's own switches as a step: see "Questions"
--   Shy.Setup.Plan(plan)       fills `plan` (or a new table) with the recommended choices
--   Shy.Setup.Check(plan)      true, or false and why
--   Shy.Setup.Run(plan)        applies everything: true, or false and why
--   Shy.Setup.Open(at) / Close() / IsOpen()   at: a step's id to open on, the overview unless told
--   Shy.Setup.Start()          the one way in, for everything that offers setup (/shy setup, the minimap's menu,
--                              a login): the welcome, for every character (one set up is welcomed back, its picks
--                              saved by Save changes); from inside the /shy window, or while it is open, the window
--   Shy.Setup.Fresh()          this character counted as never set up again, and the welcome up (/shy setup fresh)
--   Shy.Setup.Greet() / Greeting()   the welcome a character not set up yet is offered first: what to play, your
--                              addons doing a job the UI does, then what was set up, with Start playing (one
--                              click) or Customize (the pages); whether it is up
--   Shy.Setup.Back()           from a page opened from the welcome back to it, what was picked there kept
--   Shy.Setup.Pending()        not set up yet and not put away this session: the welcome is coming, or up
--   Shy.Setup.Follow(plan)     the build picked changed: the steps that go by it read the plan again
--   Shy.Setup.At()             the page on show ("overview" or a step's id); nil while it is closed
--   Shy.Setup.Advanced(on)     every page and tab on the rail (true) or the guided few (false), kept for the account;
--                              with no word, whether they are. Opt in: the window opens with the guided few until
--                              you ask for them all
--   Shy.Setup.Relabel()        the open page's heading again (a step whose lead changed)
--   Shy.Setup.Grew()           the open page measured again (a step's page that grew by itself): it scrolls that far
--   Shy.Setup.Walk(id)         a step's walk taken up or left (its `walks` says which, now): its pages hang under
--                              its row on the rail, or go; taken up, to its first page. Next and Back walk them as
--                              any others, Finish does what was picked there.
--   Shy.Setup.Show(id)         to a step's page
--   Shy.Setup.Done()           this character has been set up (Finish ran for it), as its record says
--   Shy.Setup.Away()           the window was offered and put away this session (Not now, Esc): it won't come again
--   Shy.Setup.Untouched()      Global has only ever been used by one character
--
--   Shy.Setup.GAME             game settings: { key, group, title, desc, want = { cvar = value },
--                              flags = { cvar = index }, on, off, can, owner, holder, round } (see "Game settings").
--                              owner: an addon with its own switch for it (the row goes while it's loaded), or a
--                              function true while something holds it (the row stays, dimmed, and holder says what)
--   Shy.Setup.Listed(def)      whether its row stands: the client has it and no addon's own switch stands in
--   Shy.Setup.Owned(def)       whether something holds it right now
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
--   ShyCoreDB.setup = { untouched, chars = { [character] = { done, settled, said, left, pending, round } },
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

-- This character's own file (ShyCoreCharDB: the game keeps it with the character, not the account) holds the time
-- its setup finished, under its name. The record is the account's, so it outlasts a character whose files were
-- deleted to start over; the stamp doesn't. Once a login has found the two agreeing (`stamped`: the stamp is
-- known to be kept), a record whose stamp is gone is a character starting over, and is dropped.
local function Stamps()
	ShyCoreCharDB = ShyCoreCharDB or {}
	return ShyCoreCharDB
end
local function Proven()
	local book, me = Book(), P.Character()
	local mine = book.chars[me]
	if not (mine and mine.done) then return end
	local stamps = Stamps()
	if stamps[me] == mine.done then
		mine.stamped = true
	elseif mine.stamped and stamps[me] == nil then
		book.chars[me] = nil
	else
		stamps[me] = mine.done
	end
end

-- True while only one character has ever logged in on a fresh account (the profile page words its tiles for it).
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
		desc = "You can zoom the camera out a bit past the end of its slider. (Options > Controls > Max Camera Distance)",
		want = { cameraDistanceMaxZoomFactor = "2.6" } },
	{ key = "dropTarget", group = "Controls", title = "Click ground to deselect", on = true,
		desc = "Clicking empty ground clears your target. (Options > Controls > Sticky Targeting, off)",
		want = { deselectOnClick = "1" } },
	{ key = "oneBag", group = "Controls", title = "Combined bags", on = true,
		desc = "Your bags open as one window. (Options > Controls > Use Combined Inventory Bags)",
		want = { combinedBags = "1" } },
	{ key = "autoLoot", group = "Loot", title = "Auto loot", on = true,
		desc = "You loot everything at once. Hold the loot key to look first. (Options > Controls > Auto Loot)",
		want = { autoLootDefault = "1" } },
	{ key = "lootAtMouse", group = "Loot", title = "Loot window at cursor",
		desc = "The loot window opens under your cursor. (Options > Controls > Open Loot Window at Mouse)",
		want = { lootUnderMouse = "1" } },
	{ key = "tutorials", group = "Fewer interruptions", title = "No tutorial pop-ups", on = true,
		desc = "Turns off the tutorial tips. (Options > Interface > Tutorials)",
		want = { showTutorials = "0" } },
	{ key = "toasts", group = "Fewer interruptions", title = "No item pop-ups", on = true,
		desc = "No banner when you loot an item, add to a collection or learn a recipe. Chat still tells you. (Options > Interface, the three Toasts)",
		want = { enableLootToasts = "0", enableCollectionToasts = "0", enableLearnedRecipeToasts = "0" } },
	{ key = "errorSpeech", group = "Fewer interruptions", title = "No spoken error messages", on = true,
		desc = "Your character won't say \"Not enough energy\" and the like. You still see the red text. (Options > Audio > Error Speech)",
		want = { Sound_EnableErrorSpeech = "0" } },
	{ key = "errorWindow", group = "Fewer interruptions", title = "No error pop-ups", on = true, round = 8,
		desc = "Addon errors go to /shy errors instead of opening a window in the middle of the screen.",
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
		desc = "Player names in chat show in their class color, in every channel.",
		want = { chatClassColorOverride = "0" }, off = { chatClassColorOverride = "1" } },
	{ key = "soundInBackground", group = "Sound", title = "Sound in background", on = true,
		desc = "You still hear whispers, queue pops and combat while you're tabbed out. (Options > Audio > Sound in Background)",
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
		desc = "The game's meter shows damage and healing for you and your group. (Options > Advanced Options > Damage Meter)",
		want = { damageMeterEnabled = "1" } },
	{ key = "meterReset", group = "Features", title = "Fresh meter each dungeon", on = true, round = 2, can = MeterOffered,
		desc = "The damage meter starts over as you enter a dungeon or raid. (Options > Advanced Options > Damage Meter)",
		want = { damageMeterResetOnNewInstance = "1" } },
	{ key = "cooldowns", group = "Features", title = "Cooldown manager", on = true, round = 2, can = CooldownsOffered,
		desc = "Your main cooldowns show in a row under your character. (Options > Advanced Options > Cooldown Manager)",
		want = { cooldownViewerEnabled = "1" } },
	{ key = "personalResource", group = "Features", title = "Personal resource display", on = true, round = 2, can = PersonalOffered,
		-- ShyDock's layouts by role have no place for it (your frame shows health and power) and keep it off while in use.
		owner = function()
			local dock = Shy.addons.Dock
			return dock ~= nil and dock.HoldsDisplay ~= nil and dock:HoldsDisplay() == true
		end,
		holder = "Your console layout shows your health and power on your unit frame, so this stays off.",
		desc = "Your health and power show just under your character, where you look in a fight. Console layouts by role keep this off. (Options > Combat)",
		want = { nameplateShowSelf = "1" } },
	{ key = "enemyPlates", group = "Nameplates", title = "Enemy nameplates", on = true, round = 2,
		owner = Tweaks("npcNames"), holder = "The Restyle NPC names tweak sets this while it's on.",
		desc = "Every enemy near you gets a nameplate with its health, casts and your debuffs. The Restyle NPC names tweak controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowEnemies = "1" } },
	{ key = "friendPlates", group = "Nameplates", title = "Friendly nameplates", on = true, round = 2,
		owner = Tweaks("classNames"), holder = "The Restyle player names tweak sets this while it's on.",
		desc = "Players on your side get a nameplate, so a group or a fight is easy to read. The Restyle player names tweak controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowFriendlyPlayers = "1" } },
	{ key = "alwaysPlates", group = "Nameplates", title = "Nameplates out of combat", on = true, round = 2,
		owner = Tweaks("npcNames"), holder = "The Restyle NPC names tweak sets this while it's on.",
		desc = "Nameplates show all the time, not only once a fight starts. The Restyle NPC names tweak controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowAll = "1" } },
	{ key = "plateAggro", group = "Nameplates", title = "Threat colors on nameplates", on = true, round = 9,
		-- ShyPlates colors the bars by threat itself while it draws the plates.
		owner = function()
			local plates = Shy.addons.Plates
			return plates ~= nil and plates.IsOn ~= nil and plates:IsOn() == true
		end,
		holder = "Your restyled nameplates already color by threat.",
		desc = "An enemy's health bar changes color when you lose threat as a tank, or pull threat as anyone else. (Options > Nameplates > Aggro Display > Health Bar Color)",
		flags = { nameplateThreatDisplay = Enum.NamePlateThreatDisplay.HealthBarColor } },
	{ key = "stackPlates", group = "Nameplates", title = "Stack enemy nameplates", on = true, round = 2,
		desc = "Enemy nameplates stack instead of overlapping, so each stays readable. (Options > Nameplates)",
		flags = { nameplateStackingTypes = Enum.NamePlateStackType.Enemy } },
	{ key = "npcPlates", group = "Nameplates", title = "Friendly NPC nameplates", on = true, round = 11,
		owner = Tweaks("npcNames"), holder = "The Restyle NPC names tweak sets this while it's on.",
		desc = "Guards, vendors and quest givers get a nameplate with their name. The one for your next quest step gets a mark. The Restyle NPC names tweak controls this while it's on. (Options > Nameplates)",
		want = { nameplateShowFriendlyNpcs = "1" } },
	{ key = "minionPlates", group = "Nameplates", title = "Enemy pet nameplates", round = 2,
		desc = "Pets, totems and other minions of your enemies get nameplates too. (Options > Nameplates)",
		want = { nameplateShowEnemyMinions = "1" } },
	{ key = "chatTabs", group = "Chat", title = "Short chat tabs", on = true, round = 4,
		desc = "General becomes Gen and Combat Log becomes Combat, so more tabs fit. The names change after a reload. (Right-click a chat tab > Settings)",
		is = TabsIs, take = TabsTake, back = TabsBack,
		reload = "The chat tabs change after a reload." },
	{ key = "lfgTab", group = "Chat", title = "Own tab for LookingForGroup", on = true, round = 3,
		desc = "You join the LookingForGroup channel and it gets its own chat tab, so General stays readable. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = LfgIs, take = LfgTake, back = LfgBack,
		reload = "The LookingForGroup tab changes after a reload.", fail = "needs a free chat window. Close one first." },
	{ key = "tellsTab", group = "Chat", title = "Own tab for whispers", on = true, round = 4,
		desc = "Whispers get their own chat tab, named Tells, so they never scroll away. General still shows them too. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = TellsIs, take = TellsTake, back = TellsBack,
		reload = "The Tells tab changes after a reload.", fail = "needs a free chat window. Close one first." },
	{ key = "guildTab", group = "Chat", title = "Own tab for guild chat", on = true, round = 10,
		desc = "Guild and officer chat get their own chat tab, named Guild, so they never scroll away. General stays as it was. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = GuildIs, take = GuildTake, back = GuildBack,
		reload = "The Guild tab changes after a reload.", fail = "needs a free chat window. Close one first." },
	{ key = "defenseTab", group = "Chat", title = "Own tab for LocalDefense", on = true, round = 7,
		desc = "LocalDefense calls out attacks on the zone's towns. It gets its own chat tab, named LD, so General stays readable. The tab appears after a reload. (Right-click a chat tab > Settings)",
		is = DefenseIs, take = DefenseTake, back = DefenseBack,
		reload = "The LocalDefense tab changes after a reload.", fail = "needs a free chat window. Close one first." },
	{ key = "partyBubbles", group = "Chat", title = "Party chat bubbles", on = true, round = 5,
		desc = "Party chat shows in bubbles over their heads, like /say does. (Options > Interface > Chat Bubbles > Party Chat)",
		want = { chatBubbles = "1", chatBubblesParty = "1" } },
	{ key = "interactKey", group = "Controls", title = "Interact key", on = true, round = 12,
		desc = "Your Interact key talks to, loots or gathers whatever is closest in front of you. Bind it in Key Bindings. (Options > Controls > Enable Interact Key)",
		want = { softTargetInteract = tostring(Enum.SoftTargetEnableFlags.Any) },
		off = { softTargetInteract = tostring(Enum.SoftTargetEnableFlags.Gamepad) } },
	{ key = "cameraThrough", group = "Camera", title = "Camera past small things", on = true, round = 12,
		desc = "The camera slides past trees, posts and lamps instead of zooming in on you.",
		want = { cameraIndirectVisibility = "1", cameraIndirectOffset = "10" } },
	{ key = "farPlates", group = "Nameplates", title = "Nameplates further out", on = true, round = 12,
		desc = "Nameplates show for enemies further away, so you see a pull coming.",
		want = { nameplateMaxDistance = "41" } },
	{ key = "sharpen", group = "Graphics", title = "Sharper picture", on = true, round = 12,
		desc = "The game sharpens the picture at full render scale, so edges and text look crisp.",
		want = { ResampleAlwaysSharpen = "1" } },
	{ key = "grass", group = "Graphics", title = "Fuller grass", round = 12,
		desc = "You get more grass, and it shows further out. It costs some frame rate. Herbs and quest items hide in it a bit more.",
		want = { groundEffectDensity = "128", groundEffectDist = "320" } },
	{ key = "weather", group = "Graphics", title = "Heavier weather", round = 12,
		desc = "Rain and snow fall thicker when the zone has them.",
		want = { weatherDensity = "3" } },
	{ key = "fastLoading", group = "Fewer interruptions", title = "Shorter loading screens", round = 12,
		desc = "Loading screens end sooner. Far-off parts of the world fill in as you play.",
		want = { worldPreloadNonCritical = "0" } },
}
-- Columns of groups: three where the list has the width (the setup window, the /shy window), two where it is
-- narrower. And the list's line spacing.
local COLUMNS = {
	[3] = { { "Camera", "Controls", "Loot", "Chat" }, { "On screen", "Fewer interruptions", "Sound" }, { "Features", "Nameplates", "Graphics" } },
	[2] = { { "Camera", "Controls", "Loot", "Chat", "Features" }, { "On screen", "Fewer interruptions", "Sound", "Nameplates", "Graphics" } },
}
local WIDE = 700   -- a list at least this wide has three columns

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

-- A row of the list: offered, or held by something else (shown dimmed, saying what holds it).
function S.Listed(def)
	return S.Can(def) and (type(def.owner) == "function" or not Owned(def))
end

function S.Owned(def)
	return Owned(def) == true
end

-- One switch of a game setting, wherever it is switched (setup, the Game room, the Settings list): not in a fight
-- (the game refuses most then), read back, said when the game wouldn't take it, a reload offered where one is needed.
-- True when it took.
function S.Switch(def, on)
	if InCombatLockdown() then
		Shy.core:Print("you can't change game settings in a fight.")
		return false
	end
	if on then S.Take(def) else S.Return(def) end
	if S.Is(def) ~= on then
		Shy.core:Print("\"" .. def.title .. "\" " .. (def.fail or "is locked. The game won't let addons change it."))
		return false
	end
	if def.reload then Shy.Reload(def.reload) end
	return true
end


local function Rows()
	local rows = {}
	for _, def in ipairs(S.GAME) do
		if S.Listed(def) then rows[#rows + 1] = def end
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

-- A step that fails to plan is reported and left out from then on: the window still opens with the others.
function S.Plan(plan)
	plan = plan or {}
	local failed
	for _, step in ipairs(steps) do
		if step.Plan then
			local ok, err = pcall(step.Plan, plan)
			if not ok then
				failed = failed or {}
				failed[step] = true
				geterrorhandler()(err)
			end
		end
	end
	for i = #steps, 1, -1 do
		if failed and failed[steps[i]] then table.remove(steps, i) end
	end
	return plan
end

-- The build picked changed (the welcome, the Play as page): each step that goes by it reads the plan again.
function S.Follow(plan)
	for _, step in ipairs(steps) do
		if step.Follow then
			local ok, err = pcall(step.Follow, plan)
			if not ok then geterrorhandler()(err) end
		end
	end
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

-- Only the record says so: what a step finds on the screen can't, since the game keeps some of it (Edit Mode's
-- layouts) where it outlasts a session whose saved variables were never written.
function S.Done()
	local mine = Mine()
	return mine.done ~= nil or mine.settled == true
end

-- Said once when setup is over (after its reload, if it had one), with the send-off: in its turn (Shy.Queue),
-- before anything else that comes up by itself.
local function Tell()
	local mine = Mine()
	if mine.said then return false end
	mine.said = true
	core:Print(First() .. " is set up. Change anything later with /shy.")
	if mine.left then
		core:Print("these stayed as they were. Only the game's Options window can change them: " .. mine.left .. ".")
		mine.left = nil
	end
	S.SendOff()
	return S.Sent()
end
local function Told()
	Shy.Queue.Ask("sendoff", 10, Tell, function() return S.Sent() end)
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
	mine.done, mine.said, mine.left = time(), nil, nil
	Stamps()[P.Character()] = mine.done
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
		-- (What waited for this reload, your addons switched from the welcome among it, goes with it.)
		reload = Shy.HoldReload(false) or reload or Shy.ReloadOwed()
		if not reload then Told() end
		return true, nil, reload
	end
	if reload or Shy.ReloadOwed() then Shy.Reload(DONE) else Told() end
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
	return "fresh", me, nil, "character"
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
			sub = name == P.GLOBAL and "the shared profile, so nothing changes" or "nothing changes" } }
	elseif act == "use" then
		return { { text = first .. " uses " .. (name == P.GLOBAL and "Global" or name),
			sub = "every character on it shares it. Your old profile keeps its settings" } }
	elseif name == me then
		return { { text = first .. " gets a profile of their own, on default settings",
			sub = ShyCoreDB.profiles[me] and "their profile goes back to defaults. Your other characters stay as they are" or "your other characters keep theirs" } }
	end
	return { { text = "A new profile, " .. name .. ", on default settings", sub = "other characters can pick it later" } }
end

local TILE_H, GAP = 76, 8

-- A choice: a picture, a name, a sentence, a word at its right. The picture is a glyph in a well (one
-- of S.GLYPH, or the caller's own drawn on b.glyph), or with `icon` an icon of the game's, which stands
-- in a slot and is given by SetIcon. Under the sentence a second one in the caution color (b.note), for
-- a choice that has a catch.
-- `tall`: a card standing up (what to play): the picture large at its top, its word a chip at its right, the
-- name under it, then a line for its kind (b:SetKind(atlas, words): the game's role icon), the sentence and the
-- catch, marked.
-- b:Fit() says how tall it stands as its words are.
--   b:Paint(on, tag, off, tagColor)   on: picked. tag: true shows the word "in use", a string says that
--                                     instead (in tagColor, else dim). off: can't be picked.
local CARD = { IN = 12, WELL = 52, CHIP = 16 }
local function Tile(parent, width, glyph, name, onClick, height, icon, tall)
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
	b.well:SetSize(tall and CARD.WELL or 40, tall and CARD.WELL or 40)
	b.well:SetPoint("TOPLEFT", tall and CARD.IN or 8, -(tall and CARD.IN or 8))
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
	b.tall = tall
	if tall then
		local x = CARD.IN
		-- (lit when picked: the accent washing down from its top)
		b.wash = b:CreateTexture(nil, "BACKGROUND", nil, 2)
		b.wash:SetPoint("TOPLEFT", 1, -1)
		b.wash:SetPoint("TOPRIGHT", -1, -1)
		b.wash:SetHeight(90)
		b.wash:SetColorTexture(1, 1, 1, 1)
		b.wash:SetGradient("VERTICAL", CreateColor(C.hot[1], C.hot[2], C.hot[3], 0), CreateColor(C.hot[1], C.hot[2], C.hot[3], 0.16))
		b.wash:Hide()
		b.chip = CreateFrame("Frame", nil, b)
		b.chip:SetHeight(CARD.CHIP)
		b.chip:SetPoint("TOPRIGHT", -10, -10)
		UI.Skin(b.chip, C.bg, C.border)
		b.tag:SetParent(b.chip)
		b.tag:ClearAllPoints()
		b.tag:SetPoint("CENTER", 0, 0)
		b.name:ClearAllPoints()
		b.name:SetPoint("TOPLEFT", x, -(CARD.IN + CARD.WELL + 10))
		b.kindGlyph = b:CreateTexture(nil, "ARTWORK")
		b.kindGlyph:SetSize(14, 14)
		b.kindGlyph:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -5)
		b.kind = UI.Text(b, "", 11, false, C.dim)
		b.kind:SetPoint("LEFT", b.kindGlyph, "RIGHT", 4, 0)
		b.say:ClearAllPoints()
		b.say:SetPoint("TOPLEFT", b.kindGlyph, "BOTTOMLEFT", 0, -8)
		b.say:SetWidth(width - 2 * x)
		UI.Ink(b.say, C.text)
		b.mark = b:CreateTexture(nil, "ARTWORK")
		b.mark:SetTexture(Shy.MEDIA .. "GlyphAlert")
		b.mark:SetSize(11, 11)
		b.mark:SetPoint("TOPLEFT", b.say, "BOTTOMLEFT", 0, -8)
		UI.Tint(b.mark, C.alert)
		b.note:ClearAllPoints()
		b.note:SetPoint("TOPLEFT", b.mark, "TOPRIGHT", 5, 1)
		b.note:SetWidth(width - 2 * x - 16)
		function b:SetKind(atlas, words)
			self.kind:SetText(words or "")
			self.kindGlyph:SetShown(atlas ~= nil)
			if atlas then self.kindGlyph:SetAtlas(atlas, false) end
		end
		function b:Fit()
			local note = self.note:GetText() or ""
			self.mark:SetShown(note ~= "")
			local h = CARD.IN + CARD.WELL + 10 + 18 + 5 + 14 + 8 + math.ceil(self.say:GetStringHeight())
			if note ~= "" then h = h + 8 + math.ceil(self.note:GetStringHeight()) end
			return h + CARD.IN + 2
		end
	end

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
			self.tag:SetText(self.tall and (tag:gsub("^%l", string.upper)) or tag)
			UI.Ink(self.tag, tagColor or C.dim)
		end
		if self.tall then
			-- (the chip stays beside the picture, inside the card: a word too long for it is cut short)
			local room = self:GetWidth() - 2 * CARD.IN - CARD.WELL - 8
			self.tag:SetWidth(0)
			local chip = math.min(math.ceil(self.tag:GetStringWidth()) + 12, room)
			self.tag:SetWidth(chip - 10)
			self.tag:SetWordWrap(false)
			self.chip:SetShown(tag and true or false)
			self.chip:SetWidth(chip)
			UI.SetBorder(self.chip, tagColor or C.border)
			self.wash:SetShown(on and true or false)
		end
		UI.SetFill(self, on and C.row or C.bg)
		UI.SetBorder(self, (on or self.hover) and C.hot or C.border)
		if self.glyph then
			UI.SetBorder(self.well, on and C.hot or C.border)
			UI.Tint(self.glyph, on and Theme.light or C.dim)
		end
		UI.Ink(self.name, on and (self.tall and C.hot or C.head) or C.text)
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
	end, { width = half - 66 - 4, desc = "Use a profile another character has, or one you named. A change on one character shows on all of them." })
	others:SetPoint("TOPLEFT", 58, -8)

	name = UI.Input(tiles.new, nil, function() return plan.profile.name end, function(v)
		plan.profile.name, plan.profile.choice = v, "new"
		Paint()
	end, { width = half - 66 - 4, maxLetters = 24, live = true, placeholder = function() return "Name" end,
		desc = "Give it a name. It starts on default settings, and your other characters can pick it too." })
	name:SetPoint("TOPLEFT", 58, -28)
	name.box:HookScript("OnEditFocusGained", Choose("new"))
	-- One line under the box; it must not wrap out of the tile.
	tiles.new.say:ClearAllPoints()
	tiles.new.say:SetPoint("TOPLEFT", 58, -57)
	tiles.new.say:SetWordWrap(false)
	tiles.new.say:SetText("Starts from the defaults.")

	function f:Refresh()
		local first, untouched, users = First(), S.Untouched(), Others(P.GLOBAL)
		tiles.default.say:SetText(untouched and (first .. " starts fresh on default settings, in a profile of their own.")
			or (first .. " starts fresh on default settings. Your other characters keep theirs."))
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
	-- (Said on the welcome only where it means something: another character has used Global.)
	told = function() return not S.Untouched() end,
	why = function(plan)
		local act, name = Target(plan)
		if act == "fresh" then return "starts on default settings" end
		return name == P.GLOBAL and "shared with your other characters" or nil
	end,
	ask = function() return "Which profile should " .. First() .. " use?" end,
	lead = "A profile saves all your addon settings and your layout. Characters on the same profile share them.",
	brief = function(plan)
		local act, name = Target(plan)
		if not act then return nil end
		return name == P.GLOBAL and "Global" or name == P.Character() and "Own profile" or name
	end,
	-- A character gets a profile of its own: what one changes stays with it. One on a profile already, or set up on
	-- Global before, stays where it is.
	Plan = function(plan)
		local current = P.Current()
		plan.profile = { name = "", choice = "default" }
		if current ~= P.GLOBAL then
			plan.profile.choice, plan.profile.other = "other", current
		elseif S.Done() then
			plan.profile.choice = "global"
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
	ask = "Which game settings do you want?",
	lead = "Recommended ones are ticked, and green ones are already on. Untick anything you don't want.",
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

-- The whole row is the tick. opts: height (a taller row, its words kept at its middle); slim (a
-- shorter row with the title alone); enabled (a function: false dims it, and a click does nothing).
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
	-- A tick, as every setting has (the game's settings beside it too): the row takes the click and the mouse,
	-- the box only shows it.
	b.box = UI.Checkbox(b, "", Get, Set)
	b.box:EnableMouse(false)
	b.box:SetPoint("LEFT", 10, 0)
	local x = 38
	b.name = UI.Text(b, item.title, 13)
	if slim then
		b.name:SetPoint("LEFT", x, 0)
		b.name:SetPoint("RIGHT", -6, 0)
		b.name:SetJustifyH("LEFT")
		b.name:SetWordWrap(false)
	else
		b.name:SetPoint("TOPLEFT", x, -5 - lift)
		b.say = UI.Text(b, item.say or "", 11, false, C.dim)
		b.say:SetPoint("TOPLEFT", x, -21 - lift)
		b.say:SetWidth(width - x - 6)
		b.say:SetWordWrap(false)
	end

	local enabled = opts and opts.enabled
	function b:Refresh()
		local on = Get()
		self.dimmed = enabled ~= nil and not enabled()
		self:SetAlpha(self.dimmed and 0.4 or 1)
		self.box:Refresh()
		self.lit:SetShown(on)
		UI.SetFill(self, on and C.row or C.bg)
		UI.Ink(self.name, on and C.head or C.text)
	end
	b:SetScript("OnClick", function(self)
		if self.dimmed then return end
		Set(not Get())
		PlaySound(Get() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		self:Refresh()
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

-- The game's settings as plates, as the tweaks beside them have: the whole row the tick, the setting's name on
-- it, what it does under the mouse. With a plan a tick is a pick for later (one a page put on live goes off with
-- it), and green says the game has it that way already; without one it switches the setting live. `changed`:
-- the list reads every row again.
local function GameRow(f, def, plan, enabled, changed)
	local get, set
	if plan then
		-- (A plan ticks the ones already set: unticked, Finish turns one off.)
		get = function() return plan.game.pick[def.key] == true end
		set = function(v)
			plan.game.pick[def.key] = v
			if not v then S.Live(def.key, false) end
			changed()
		end
	else
		get = function() return S.Is(def) end
		set = function(v)
			S.Switch(def, v)
			changed()
		end
	end
	-- Dimmed while the master switch is off, or while something else switches this setting.
	local row = QuestionRow(f, 100, def, get, set, { slim = true, enabled = function()
		return (not enabled or enabled()) and not Owned(def)
	end })
	row.text = row.name
	if plan then
		local Base = row.Refresh
		function row:Refresh()
			Base(self)
			if S.Is(def) and not took[def.key] then UI.Ink(self.name, C.good) end
		end
	end
	return row
end

-- A group's caption, as the tweaks' full list has them: its name, a rule on to the column's edge.
local function GameCaption(f, name, width)
	local cap = CreateFrame("Frame", nil, f)
	cap:SetSize(width, Q_CAPTION - 4)
	cap.text = UI.Text(cap, name:upper(), 11, true, C.dim)
	cap.text:SetPoint("LEFT")
	local rule = cap:CreateTexture(nil, "ARTWORK")
	UI.Paint(rule, C.border, 0.7)
	rule:SetHeight(1)
	rule:SetPoint("LEFT", cap.text, "RIGHT", 8, 0)
	rule:SetPoint("RIGHT")
	return cap
end

-- With a plan, a plate over the list says whether setup changes the game's settings at all.
local MASTER = { title = "Use the recommended game settings", say = "Untick this to leave every game setting as it is.",
	desc = "Finish changes the ones ticked below. Green ones are already on. You can undo any of them later in /shy." }

function S.GameList(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local rows = {}
	local function Changed() f:Refresh() end
	local top, enabled = 0, nil
	if plan then
		local all = QuestionRow(f, width, MASTER, function() return plan.game.on end, function(v)
			plan.game.on = v
			Changed()
		end)
		all.text = all.name
		all:SetPoint("TOPLEFT")
		rows[#rows + 1] = all
		top = Q_ROW + Q_BREAK + 4
		enabled = function() return plan.game.on end
	end
	local tallest, list = top, Rows()
	local columns = COLUMNS[width >= WIDE and 3 or 2]
	local col = (width - (#columns - 1) * GAP) / #columns
	for column, names in ipairs(columns) do
		local x, y = (column - 1) * (col + GAP), top
		for _, name in ipairs(names) do
			local any = false
			for _, def in ipairs(list) do
				if def.group == name then
					if not any then
						any = true
						GameCaption(f, name, col):SetPoint("TOPLEFT", x, -y)
						y = y + Q_CAPTION
					end
					local row = GameRow(f, def, plan, enabled, Changed)
					row:SetWidth(col)
					row:SetPoint("TOPLEFT", x, -y)
					rows[#rows + 1] = row
					y = y + Q_SLIM + Q_SLIM_GAP
				end
			end
			if any then y = y + Q_BREAK end
		end
		tallest = max(tallest, y - Q_BREAK - Q_SLIM_GAP)
	end
	f:SetSize(width, tallest)
	function f:Refresh()
		for _, row in ipairs(rows) do row:Refresh() end
	end
	return f
end


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
		if next(answers) == nil then return { { text = noun .. " stay as the profile has them", sub = "none changed here" } } end
		return { { text = noun .. " as you picked them", sub = on .. " switched on after the reload" } }
	end
	local on, off, answers = {}, {}, Answers(def, plan)
	for _, item in ipairs(def.items()) do
		local want = answers[item.key]
		if want ~= nil and want ~= (item.get() and true or false) then
			local list = want and on or off
			list[#list + 1] = (item.title:gsub("^%u", string.lower))
		end
	end
	if #on + #off == 0 then return { { text = noun .. " stay as they are", sub = #def.items() .. " in all, none changed" } } end
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
			return state and state.all and ("All the " .. def.noun .. ", by category. Hover over one to see what it does.") or def.lead
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

-- The window: the /shy window, lent (Shy.Hub.Lend). Its rail holds the setup's pages, each with what it holds
-- now under its name; the one on show stands beside the rail under its own question, as the window's rooms do.
-- A page is a step; steps on one subject share a page as its tabs (a step's `tab`: the screen's page holds the
-- cooldown manager, the game's the tweaks). It opens on the overview: your band, then every step's pick on a
-- tile, the steps in groups (GROUPS), each recommended from the start, so Finish there sets a character up in one
-- click and a click on a tile goes to its step. Next and Back walk the pages and their tabs in order; Finish
-- stands on every page, so a character set up before can open one, change it and finish. The band's edge is gold
-- and the foot says so: nothing is kept until Finish. A page coming up fades in; nothing moves.

local HEAD_H = UI.LEAD_H   -- a page's heading, down to the page
local TABS_H = 42          -- a page's tabs (the steps sharing it), down to its heading
-- The foot's buttons: in from the window's right edge and up from its foot, each one's width, between two, and
-- each side of the divider.
local FEET = { EDGE = 14, UP = 11, NEXT = 110, BACK = 76, FINISH = 110, LATER = 86, HOME = 170, GAP = 8, DIVIDE = 12 }
local STRIP_GAP = 22 -- under a strip standing over a page's heading (a step `inside` another)
local FADE = 0.15    -- seconds a page comes up in
-- The size is no page: it is a strip over the profile's page (its step is `inside` the profile's), so it is
-- the first thing set and every preview after it is drawn at the size the screen will have.
-- The overview's groups, and the pages in the rail's order with them.
local GROUPS = {
	{ title = "You", steps = { "talents", "profile" } },
	{ title = "Your screen", steps = { "theme", "screen", "xp" } },
	{ title = "How you play", steps = { "immersion", "keys", "dungeons" } },
	{ title = "The game", steps = { "game" } },
}
local OVERVIEW = "overview"
-- The overview: the band, a line under it (DOWN), the first caption FIRST under the band, the others NEXT under
-- the tiles before them, tiles BELOW a caption; GLYPH a step's without one of its own.
local CARD = { GLYPH = "note", DOWN = 7, FIRST = 40, NEXT = 26, BELOW = 24, AIR = 20 }
-- at: the page on show (OVERVIEW or its step's id); tabs: each page's tab on show, by page; order: the pages in
-- the rail's order; done: the steps gone past, by id; first: what each step held as the window opened, by id;
-- wasDone: the character was set up before it opened; pageW, pageH: the page's width and height in the window
-- now; back: opened from the /shy window, which Not now goes back to; fight: put away for a fight, open still.
local win = { open = false, plan = {}, pages = {}, built = {}, at = OVERVIEW, tabs = {}, order = {}, done = {}, first = {}, pageW = 700, pageH = 538,
	keys = {} }   -- keys: the secure keys laid over what finishes (FinishKey)

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
		if step.inside or Host(step) or not step.Build or step.walk then placed[step] = true end
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

-- Guided and advanced. A new player is walked through the few pages that are a matter of taste (a step's
-- `guided`); the rest are picked as recommended and stay out of sight, with every page's further tabs, until
-- asked for: the foot's switch, a tile of the overview, a page opened by name. win.advanced says they are on show.
local function Guided()
	for _, step in ipairs(steps) do
		if step.guided and step.Build then return true end
	end
	return false
end
local function Listed(step)
	return win.advanced or step.guided or not Guided()   -- (no guided step at all: every page is walked)
end
-- The guided few are walked a page at a time, with no rail and no overview (the /shy window's focus: Hub.Lend):
-- a question, its page, and where the walk is as pips in the header. Advanced brings the rail and the overview.
local function Focused() return not win.advanced and Guided() end

-- A cinematic or movie on screen (a new character's intro): setup waits for it.
local function Watching()
	return InCinematic() or CinematicFrame:IsShown() or MovieFrame:IsShown()
end

-- The screen stays up while the window is open, the first time too: every pick shows on it as it is made
-- (the look, the layout, the cooldown manager), so nothing fades.
local function Awake(on)
	if Shy.Immersion then Shy.Immersion.Hold("setup", on) end
end

-- Picks go on as they are made, so the window and the screen show them. Each step that does so hands what
-- stood before (its Worn, when the window opens) and puts it back (its PutBack) when the window closes
-- without Finish. moving: Finish switched profile, so only what the old profile holds goes back; the picks
-- follow the new one after the reload (S.Wait).
local function Worn()
	local kept = {}
	for _, step in ipairs(steps) do
		if step.Worn then
			local ok, worn = pcall(step.Worn)
			if ok then kept[step.id] = worn else geterrorhandler()(worn) end
		end
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

local Go, RailRows, guest, Walked, Branches, FinishKey   -- (the rail's rows and branches, what the /shy window asks of setup, and the key that finishes: made below; a walk and the overview ask for them before)

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

-- A tile of the overview, as the /shy window's Home has them: a step's glyph, its name, what it holds now (in
-- gold when it can't go ahead as it is). At its right end, how the pick stands: a check while it is the one
-- recommended (a first setup), "changed" once it is another than the window opened with. The sentence that says
-- more is its hover. A click goes to the step's page (a step inside another's or a tab of it: to that page, at
-- its tab).
local function Card(parent, width, step)
	local b = Shy.Hub.Tile(parent, width)
	b.glyph = b:CreateTexture(nil, "ARTWORK")
	b.glyph:SetPoint("CENTER", b.icon, "CENTER")
	if not UI.GlyphArt(b.glyph, step.glyph or CARD.GLYPH) then b.glyph:SetSize(16, 16) end
	UI.Tint(b.glyph, C.dim)
	b.name:SetText(step.title)
	UI.Ink(b.name, C.head)
	b.value = b.line
	b.check = b:CreateTexture(nil, "OVERLAY")
	b.check:SetTexture(MEDIA .. "GlyphCheckS")   -- drawn for 12 units
	b.check:SetSize(12, 12)
	b.check:SetPoint("TOPRIGHT", -8, -7)
	UI.Tint(b.check, C.good)
	b.tag = UI.Text(b, "changed", 10, true, C.alert)
	b.tag:SetPoint("TOPRIGHT", -8, -6)
	b.step = step
	function b:Refresh()
		local brief = Brief(step)
		local line, bad = Line(step)
		self.value:SetText(brief or step.title)
		UI.Ink(self.value, bad and C.alert or C.text)
		self.says = line
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
		UI.Tint(self.glyph, Theme.light)
		if self.says and self.says ~= "" then UI.Tip(self, step.title, self.says) end
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		UI.Tint(self.glyph, C.dim)
		UI.TipHide(self)
	end)
	return b
end

-- The overview: the band that names the character, the line saying nothing is kept until Finish, then a group a
-- caption and its tiles, as many across as Home has (one inside another's page or a tab of it after its host).
local function Overview(parent)
	local Hub, H = Shy.Hub, Shy.Hub.HOME
	local width = win.pageW
	local f = CreateFrame("Frame", nil, parent)
	f.width = width
	f:SetSize(width, win.pageH)
	f.band = Hub.Band(f, width)
	f.band:SetPoint("TOPLEFT")
	f.state = UI.Text(f, "", 11, false, C.text)
	f.state:SetPoint("TOPLEFT", f.band, "BOTTOMLEFT", H.EDGE + 16, -CARD.DOWN)
	f.state:SetWidth(width - 2 * (H.EDGE + 16))
	f.state:SetWordWrap(false)

	f.cards = {}
	local each = (width - (H.ACROSS - 1) * H.GAP * 2) / H.ACROSS
	local y = H.BANNER + CARD.FIRST
	for _, group in ipairs(Groups()) do
		local caption = Hub.Caption(f, width, group.title)
		caption:SetPoint("TOPLEFT", 0, -y)
		y = y + CARD.BELOW
		local list = {}
		for _, host in ipairs(group.steps) do
			list[#list + 1] = host
			for _, inner in ipairs(Insides(host)) do
				if inner.brief then list[#list + 1] = inner end
			end
			for i, part in ipairs(Parts(host)) do
				if i > 1 then list[#list + 1] = part end
			end
		end
		for i, step in ipairs(list) do
			local card = Card(f, each, step)
			local column, row = (i - 1) % H.ACROSS, math.floor((i - 1) / H.ACROSS)
			card:SetPoint("TOPLEFT", column * (each + H.GAP * 2), -(y + row * (H.TILE + H.GAP)))
			f.cards[#f.cards + 1] = card
		end
		y = y + math.ceil(#list / H.ACROSS) * (H.TILE + H.GAP) - H.GAP + CARD.NEXT
	end
	f.tall = y - CARD.NEXT + CARD.AIR
	function f:Relabel()
		self.band:Tell(true)
		local kept = UI.Wrap(C.alert, "Nothing is saved until you press Finish.")
		if win.wasDone then
			self.state:SetText("This is how " .. First() .. " is set up. Click anything to change it. " .. kept)
		else
			self.state:SetText("It's all picked for you already. Click anything to change it. " .. kept)
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
	local width = win.pageW
	local f = CreateFrame("Frame", nil, parent)
	f.width = width
	f:SetSize(width, win.pageH)
	f.step, f.parts, f.strips, f.sections, f.top, f.open = host, Parts(host), {}, {}, 0, 1
	-- The steps inside this one: each a strip over its heading, top down.
	for _, inner in ipairs(Insides(host)) do
		local strip = inner.Build(f, width, win.plan, Room())
		strip:ClearAllPoints()
		strip:SetPoint("TOPLEFT", 0, -f.top)
		f.strips[#f.strips + 1] = strip
		f.top = f.top + strip:GetHeight() + STRIP_GAP
	end
	-- Its tabs (the steps sharing it) stand over its heading while the advanced pages are on show; without them
	-- the heading stands where they would (f:Depth lays both ways).
	f.base = f.top
	if #f.parts > 1 then
		local labels = {}
		for i, part in ipairs(f.parts) do labels[i] = part.tabTitle or part.title end
		f.tabs = UI.Tabs(f, labels, function(i)
			if win.tabs[host.id] ~= i and win.shown == host.id then Go(host.id, i) end
		end, width, 15)
		f.tabs:SetPoint("TOPLEFT", 0, -f.top)
		if win.advanced then f.top = f.top + TABS_H end
	end
	f.lead = UI.Lead(f, width)
	for i, part in ipairs(f.parts) do
		f.sections[i] = part.Build(f, width, win.plan, Room() - f.top)
	end
	function f:Depth(advanced)
		local deep = self.tabs ~= nil and advanced == true
		if self.tabs then self.tabs:SetShown(deep) end
		local top = self.base + (deep and TABS_H or 0)
		if self.laid == top then return end
		self.top, self.laid = top, top
		self.lead:ClearAllPoints()
		self.lead:SetPoint("TOPLEFT", 0, -top)
		for _, section in ipairs(self.sections) do
			section:ClearAllPoints()
			section:SetPoint("TOPLEFT", 0, -top - HEAD_H)
			if section.Fit then section:Fit(Room() - top) end
		end
	end
	f:Depth(win.advanced)
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

-- The page on show grew or shrank by itself (a pick that shows more under it): measured again, and the window
-- scrolls as far as it now reaches.
function S.Grew()
	local f = win.open and win.shown and win.pages[win.shown]
	if not (f and f.sections) then return end
	local section = f.sections[f.open]
	local h = section and section:GetHeight()
	f:SetHeight(max(win.pageH, f.top + HEAD_H + ((type(h) == "number" and not issecretvalue(h)) and h or 0)))
	Tall(f)
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
	box.rail:SetSubs(Briefs())
	for _, id in ipairs(win.order) do
		local step, done = Step(id), id ~= OVERVIEW
		for _, part in ipairs(step and Parts(step) or {}) do done = done and win.done[part.id] == true end
		box.rail:SetDone(id, done)
	end
	-- (a walk's page: its step's row open, its own line on the branch lit)
	box.rail:Select(host and host.walk or key, true)
	box.rail:SetKid(host and host.walk and key or nil)
	lap = Lap("setup: the rail told", lap)
	-- Pages are built on first visit, and for each width the window stands at (maximized or put back), each kept:
	-- a page built is never let go (the game keeps every frame, its sections what they registered).
	local f = win.pages[key]
	if f and f.width ~= win.pageW then
		f:Hide()
		f = win.built[key] and win.built[key][win.pageW]
		if f then win.pages[key] = f end
	end
	if not f then
		f = host and StepPage(box.content, host) or Overview(box.content)
		f:SetPoint("TOPLEFT", Shy.Hub.IN, 0)
		win.pages[key] = f
		win.built[key] = win.built[key] or {}
		win.built[key][win.pageW] = f
		lap = Lap("setup: a page made", lap)
	end
	for id, other in pairs(win.pages) do other:SetShown(id == key) end
	lap = Lap("setup: the page shown, the others put away", lap)
	local parts = host and f.parts or {}
	local tab = math.min(max(win.tabs[key] or 1, 1), max(#parts, 1))
	if not win.advanced then tab = 1 end
	win.tabs[key] = tab
	win.shown = key
	if host then
		f:Depth(win.advanced)
		f:Open(tab)
	end
	-- A step whose picks go on the screen puts its plan on as its page comes up (Shown), so the screen
	-- already is what the page shows. The overview shows every pick: one that goes on as the window opens
	-- (`atOpen`: the size, so everything after is drawn at it) is put on there.
	-- (fresh: the first page since the window opened, the overview or not: the guided walk has none.)
	if host or key == OVERVIEW then
		local each = host and Insides(host) or {}
		each[#each + 1] = parts[tab]
		local among = {}
		for _, step in ipairs(each) do among[step] = true end
		for _, step in ipairs((not host or win.fresh) and steps or {}) do
			if step.atOpen and not among[step] then each[#each + 1] = step end
		end
		win.fresh = nil
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
	-- ahead; its hover says why. Beside Not now, on a step's page, what Finish is for (the overview's band says
	-- it there).
	local first, last, over = at == 1, at == #win.order, key == OVERVIEW
	local alone = win.alone ~= nil
	local behind = not first or win.greeted == true
	box.back:SetShown(behind and not alone)
	box.next:SetShown(not last and not alone)
	box.next:SetPrimary(not over)
	box.divider:SetShown(not last and not alone)
	box.kept:SetShown(not over or alone)
	box.later:SetShown(not alone)
	box.deep:SetShown(not alone)
	box.home:SetShown(alone)
	box.kept:ClearAllPoints()
	if alone then
		box.kept:SetPoint("LEFT", box.foot, "BOTTOMLEFT", FEET.EDGE, FEET.UP + 12)
		box.kept:SetText(S.Done() and "Nothing changes until you press Save changes." or "Nothing is saved until you press Start playing.")
	else
		box.kept:SetPoint("LEFT", box.deep, "RIGHT", 14, 0)
		box.kept:SetText("Nothing is saved until you press Finish.")
	end
	local names
	if guest.focus and not alone then
		names = {}
		for i, id in ipairs(win.order) do
			local step = Step(id)
			names[i] = step and step.title or id
		end
	end
	Shy.Hub.Pips(names, at, function(i) Go(win.order[i], 1) end)
	-- (A page alone: Esc and the x go back to the welcome too, said in the header.)
	if not box.alone then
		box.alone = UI.Text(box.head, "Esc and close also take you back.", 11, false, C.dim)
		box.alone:SetPoint("RIGHT", box.head.buttons and box.head.buttons[1] or box.head.close, "LEFT", -14, 0)
	end
	box.alone:SetShown(alone)
	local finish = box.finish
	local ok, why = S.Check(win.plan)
	finish.dimmed = not ok
	finish.why = why
	finish:SetAlpha(ok and 1 or 0.4)
	finish:SetPrimary(over or last)
	finish:SetShown(not alone)
	box.deep.text:SetText(win.advanced and "Simple" or "Advanced")
	local walk = FEET.EDGE + FEET.NEXT + (behind and FEET.GAP + FEET.BACK or 0)
	box.back:ClearAllPoints()
	box.back:SetPoint("BOTTOMRIGHT", box.foot, "BOTTOMRIGHT", -(FEET.EDGE + (last and FEET.FINISH or FEET.NEXT) + FEET.GAP), FEET.UP)
	box.divider:ClearAllPoints()
	box.divider:SetPoint("BOTTOMRIGHT", box.foot, "BOTTOMRIGHT", -(walk + FEET.DIVIDE), FEET.UP + 1)
	finish:ClearAllPoints()
	finish:SetPoint("BOTTOMRIGHT", box.foot, "BOTTOMRIGHT", -(last and FEET.EDGE or walk + 2 * FEET.DIVIDE + 1), FEET.UP)
	if not InCombatLockdown() then finish.key:SetAttribute("type", nil) end
	finish.key.armed = nil
end

-- The step on show, or nil on the overview.
local function Showing()
	local f = win.at ~= OVERVIEW and win.pages[win.at]
	return f and f.parts and f.parts[win.tabs[win.at] or 1] or nil
end

-- The page on show is gone past: checked off from here on, its tabs with it (Next goes page to page).
local function Leave()
	local f = win.at ~= OVERVIEW and win.pages[win.at]
	for _, step in ipairs(f and f.parts or {}) do win.done[step.id] = true end
end

-- The advanced pages and tabs on show, or the guided few: the rail told again. keep: the account's choice from
-- now on (the switch), not just what this walk needed.
local function Deepen(on, keep)
	win.advanced = on and true or false
	if keep then Book().advanced = on and true or nil end
	guest.items = RailRows()
	if win.box and win.open then
		Shy.Hub.Retell(guest)
		Branches()
	end
end

-- To a page, by its key, at a tab of it (the one it had open unless told; "last": its last).
function Go(key, tab)
	if not key or (key == win.at and (not tab or tab == win.tabs[key])) then return end
	-- (One the short walk leaves out: asked for, so they are all on show.)
	if not win.advanced and (not Index(key) or (type(tab) == "number" and tab > 1) or tab == "last") then
		Deepen(true)
	end
	Leave()
	win.at = key
	if tab then
		local step = Step(key)
		win.tabs[key] = tab == "last" and (step and #Parts(step) or 1) or tab
	end
	Show()
end

-- Next and Back walk the pages in the rail's order, one press a page: a page comes up at its first tab, and its
-- other tabs are there for whoever wants them (each is picked as recommended already).
local function Forward()
	local at = Index(win.at) or 1
	if at < #win.order then Go(win.order[at + 1], 1) end
end

local function Backward()
	local at = Index(win.at) or 1
	if at > 1 then Go(win.order[at - 1], 1) elseif win.greeted then S.Back() end
end

-- A walk within the walk: in and out. The rail and the header follow; the page comes up at the walk's first page,
-- and back at the one it was entered from.
function S.Walk(id)
	local host = Step(id)
	if not (win.open and host) then return end
	guest.items = RailRows()
	Shy.Hub.Retell(guest)
	Branches()
	local first = Walked(host)[1]
	if first then Go(first.id) else Show() end
end
function S.Show(id)
	if win.open then Go(Place(id)) end
end

function S.Advanced(on)
	if on == nil then return win.advanced == true end
	Deepen(on, true)
	if not win.open then return end
	if not Index(win.at) then win.at = OVERVIEW end
	Show()
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

-- The window flows taller: the page and every page built take the height. Wider (maximized), the page on show
-- stands as built for the width there is, as the window's own rooms do. Nothing is scaled. `sizing`: a corner is
-- still dragged, every frame the mouse moves: the page takes the height, nothing is read again.
local function Lay(sizing)
	if not win.box then return end
	win.pageW, win.pageH = Shy.Hub.Size()
	for _, f in pairs(win.pages) do
		if f.width == win.pageW then f:Fit() end
	end
	local f = win.shown and win.pages[win.shown]
	if f and win.open then
		if f.width ~= win.pageW then
			Show()
		else
			if not sizing then f:Refresh() end
			Tall(f)
		end
	end
end

-- When the game last closed every window itself (GetTime, the same all through a frame): see "Offered".
local gameAt

-- The way out of the walk, open or not: the screen let go, what was put on and not finished put back, Finish's
-- key put away. back: to the /shy window's rooms, open; else the window closes.
local function Out(back)
	win.open, win.alone, win.greeted, win.planned = false, nil, nil, nil
	win.fromHub = nil   -- (back to its rooms, or closed: the welcome's way back to it is spent)
	Awake(false)
	PutBack()
	local key = win.box and win.box.finish.key
	if key and not InCombatLockdown() then key:Hide() end
	-- (Our pages stand on the window's content too: put away before its rooms come back, faded in when next shown.)
	for _, f in pairs(win.pages) do f:Hide() end
	win.shown, win.section = nil, nil
	Shy.Hub.Return(not back)
end

-- What the /shy window asks of its guest.
guest = { words = "Setting up" }
function guest.Go(key) Go(key) end
-- A line under a row (a walk's page): to its page.
function guest.Kid(_, kid) Go(Place(kid)) end
function guest.Lay(sizing) Lay(sizing) end
function guest.Close() if win.alone then S.Back() else S.Close() end end
function guest.Leave() S.Close(true) end
function guest.Away() return win.fight == true end
-- Hidden: by Esc it is put away until the next login. By the game (a loading screen, dying, a cinematic), it is
-- offered again once the world is back. Put away for a fight, it stays open to come back: by the next frame the
-- fight has locked things down.
function guest.Hidden(box)
	local at = GetTime()
	C_Timer.After(0, function()
		if box:IsShown() or InCombatLockdown() or win.fight or not win.open then return end
		if win.alone then
			S.Back()
			return
		end
		Out(false)
		if at ~= gameAt and not Watching() then
			win.away = true
			Shy.ReloadAsk()
		end
	end)
end

-- Finish: sets everything up and, when that needs a reload, reloads in the same click. The game refuses an
-- addon the reload itself; a secure button running /reload is allowed. So Finish is one of the window's buttons
-- with a secure key laid over it while the mouse is on it, a child of the screen placed by its corners, never
-- the window's (that would make the window protected): as Layout mode's is (Shy.HUD.EditModeKey). Its PreClick
-- runs the setup (held: no Reload panel) and arms it only when a reload is wanted. Down and up both reach it (the
-- reload fires on whichever the game acts on), so it runs once per click. In a fight the window is away.
function FinishKey(finish, name)
	local key = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	win.keys[#win.keys + 1] = key
	key:SetFrameStrata("FULLSCREEN_DIALOG")
	key:SetFrameLevel(500)
	key:RegisterForClicks("AnyUp", "AnyDown")
	key:SetAttribute("macrotext", SLASH_RELOAD1)
	key:Hide()
	-- Hover and press are Finish's, for its look and its hover.
	local function Tell(script)
		return function(_, ...)
			local fn = finish:GetScript(script)
			if fn then fn(finish, ...) end
		end
	end
	key:SetScript("OnEnter", Tell("OnEnter"))
	key:SetScript("OnLeave", function(self)
		Tell("OnLeave")(self)
		if not InCombatLockdown() and self.armed ~= "reload" then self:Hide() end
	end)
	key:HookScript("OnMouseDown", Tell("OnMouseDown"))
	key:HookScript("OnMouseUp", Tell("OnMouseUp"))
	-- armed: nil before a click; "reload" (the macro fires), "done" (nothing to reload) or "failed".
	key:SetScript("PreClick", function(self)
		if self.armed ~= nil or finish.dimmed or InCombatLockdown() then return end
		local ok, why, reload = S.Run(win.plan, true)
		-- What is worn now is the answer; switching profile, the old one keeps what it had.
		if ok and S.Act(win.plan) ~= "stay" then PutBack(true) elseif ok then win.kept = nil end
		if ok then wipe(took) win.planned = nil end   -- what a page put on live is set up now
		self.armed = not ok and "failed" or reload and "reload" or "done"
		-- (Set up: what asked goes at once, before the reload the release brings.)
		if ok and finish.after then finish.after(true) end
		if reload and ok then
			self:SetAttribute("type", "macro")
			-- Should the click never reach the game's action (released off the button), the panel finishes it.
			C_Timer.After(1, function()
				if self.armed ~= "reload" then return end
				self.armed = nil
				if finish.after then finish.after(true) end
				S.Close()
				Shy.Reload(DONE)
			end)
		elseif not ok then
			core:Print(why)
		end
	end)
	key:SetScript("PostClick", function(self, _, down)
		if down or self.armed == "reload" then return end
		local done = self.armed == "done"
		self.armed = nil
		if not InCombatLockdown() then
			self:SetAttribute("type", nil)
			if done then self:Hide() end   -- (what it lay over is gone: nothing stays under the mouse)
		end
		if finish.after then finish.after(done) end
		if done then S.Close() elseif win.open then Show() end
	end)
	finish:HookScript("OnEnter", function(self)
		if InCombatLockdown() then return end
		local left, bottom, width, height = self:GetLeft(), self:GetBottom(), self:GetWidth(), self:GetHeight()
		if not left then return end
		local s = self:GetEffectiveScale() / UIParent:GetEffectiveScale()
		key:ClearAllPoints()
		key:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
		key:SetSize(width * s, height * s)
		key:Show()
	end)
	finish.key = key
end

-- The foot's buttons on the window's foot, once; and what keeps the walk up while it is open.
local function Build(box)
	local foot = box.foot
	local later = UI.Button(foot, "Not now", FEET.LATER, function() S.Close(win.back) end)
	later:SetPoint("BOTTOMLEFT", FEET.EDGE, FEET.UP)
	later:HookScript("OnEnter", function(self)
		UI.Tip(self, "Not now", (win.back and "Go back to the rest of /shy." or "Close this until you next log in.")
			.. " Nothing you picked here is saved. Type /shy setup to come back to it.", { side = "TOP" })
	end)
	later:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	box.later = later
	-- The switch between the guided few and every page and tab (S.Advanced).
	box.deep = UI.Button(foot, "Advanced", FEET.LATER, function() S.Advanced(not win.advanced) end)
	box.deep:SetPoint("LEFT", later, "RIGHT", FEET.GAP, 0)
	box.deep:HookScript("OnEnter", function(self)
		if win.advanced then
			UI.Tip(self, "Simple", "Show just the main pages again. Your other choices stay as they are.", { side = "TOP" })
		else
			UI.Tip(self, "Advanced", "Show every page and option, like your profile, keys, dungeons and game settings.", { side = "TOP" })
		end
	end)
	box.deep:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	-- What Finish is for, beside them on every step's page.
	box.kept = UI.Text(foot, "Nothing is saved until you press Finish.", 12, false, C.alert)
	box.kept:SetPoint("LEFT", box.deep, "RIGHT", 14, 0)

	local finish = UI.Button(foot, "Finish", FEET.FINISH, function() end)
	finish:SetPoint("BOTTOMRIGHT", -FEET.EDGE, FEET.UP)
	finish:HookScript("OnEnter", function(self)
		UI.Tip(self, "Finish", self.dimmed and self.why or "Saves everything you picked, with one reload if it needs one. You can change any of it later in /shy.", { side = "TOP" })
	end)
	finish:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	FinishKey(finish, "ShySetupFinish")
	box.finish = finish

	-- Next at the window's right end and Back before it, the way through the pages, and the divider between
	-- them and Finish (Show places Back, the divider and Finish).
	box.next = UI.Button(foot, "Next", FEET.NEXT, function() Forward() end)
	box.next:SetPoint("BOTTOMRIGHT", -FEET.EDGE, FEET.UP)
	box.back = UI.Button(foot, "Back", FEET.BACK, function() Backward() end)
	box.back:SetPoint("BOTTOMRIGHT", -(FEET.EDGE + FEET.NEXT + FEET.GAP), FEET.UP)
	-- A page opened alone from the welcome: its one way on, back there.
	box.home = UI.Button(foot, "Back to your setup", FEET.HOME, function() S.Back() end)
	box.home:SetPoint("BOTTOMRIGHT", -FEET.EDGE, FEET.UP)
	box.home:SetPrimary(true)
	box.home:Hide()
	box.divider = foot:CreateTexture(nil, "ARTWORK")
	UI.Paint(box.divider, C.border, 0.9)
	box.divider:SetSize(1, 22)

	-- What each step holds now, under its name and on the overview's tiles, kept up as picks change.
	local since = 0
	box:HookScript("OnUpdate", function(_, elapsed)
		since = since + elapsed
		if since < 0.25 or not win.open then return end
		since = 0
		box.rail:SetSubs(Briefs())
		local f = win.at == OVERVIEW and win.pages[OVERVIEW]
		if f then f:Refresh() end
	end)

	-- A fight puts the window away (nothing can be set up in one) and brings it back after. A layout put on (a
	-- pick on the screen page) or a size (the size page) moves the screen: the page shows it once it has.
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("PLAYER_REGEN_DISABLED")
	watch:RegisterEvent("PLAYER_REGEN_ENABLED")
	watch:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	watch:RegisterEvent("UI_SCALE_CHANGED")
	watch:RegisterEvent("DISPLAY_SIZE_CHANGED")
	watch:SetScript("OnEvent", function(_, event)
		if not win.open then return end
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			win.fight = event == "PLAYER_REGEN_DISABLED" or nil
			if win.fight and not InCombatLockdown() then
				for _, key in ipairs(win.keys) do key:Hide() end
			end
			Shy.HUD.Update(box)
			Show()
			return
		end
		-- (A pick can be laid out a moment after its click, once what it switched on is up: the page shows it then.)
		local f = win.shown and win.pages[win.shown]
		if f and f:IsShown() then f:Refresh() end
	end)
end

function S.IsOpen() return win.open end
function S.Away() return win.away == true end
-- Not set up yet and not put away this session: the welcome is coming, or up. A reload that can wait, waits for
-- setup's (Shy.Reload), and nothing else comes up by itself meanwhile, nor over the open window.
function S.Pending() return not S.Done() and not win.away end
Shy.Queue.Hold(function() return S.Pending() or win.open end)

-- The greeting
--
-- A character not set up yet is welcomed in a small window of its own, in up to three steps, named in its header.
-- Play as asks the one thing nothing else can work out: what you want to play (skipped when your talents say it).
-- Your addons, only while any is due, lists your other addons doing a job your UI does, each with its button:
-- kept or turned off before anything else. Your setup tells what was set up, a line a pick with a picture of it
-- and why, and offers two ways on: Start playing (everything as told, one click) or Customize (the pages, one
-- at a time). Every line can be changed: its step again, or its page alone, then back here (S.Back). A line
-- changed says what it was, with Undo.
--   S.Greet()      show it          S.Greeting()   whether it is up
-- TOP, MARK: the hero's start and its fox; IN: the card's padding; CAP: its caption; ROW: a told line, its
-- picture WELL_W x WELL_H; LINE: an addon's line, VIEW of them before the list scrolls; BAND: the foot; DECIDE,
-- START, CHANGE, UNDO: buttons; TOLD: the steps told, in this order; SENT, DOOR: the send-off's width and doors.
local GREET = { W = 720, PAD = 16, TOP = 34, MARK = 44, GAP = 8, IN = 10, CAP = 30, ROW = 56, WELL_W = 112, WELL_H = 42,
	LINE = 34, VIEW = 10, BAND = 48, DECIDE = 110, START = 130, CHANGE = 76, UNDO = 56, SLIDE = 0.12, SHIFT = 12, HOLD = 0.25,
	TOLD = { "talents", "screen", "theme", "scale", "immersion", "profile" }, SENT = 640, DOOR = 118 }
-- How the header names a page opened alone from the welcome.
local CHANGING = { talents = "what you play", immersion = "how you play", scale = "your size" }
local greet

-- A band across the foot of a small window: a hairline over a darker strip.
local function Band(body)
	local band = CreateFrame("Frame", nil, body)
	band:SetPoint("BOTTOMLEFT")
	band:SetPoint("BOTTOMRIGHT")
	band:SetHeight(GREET.BAND)
	band.fill = band:CreateTexture(nil, "BACKGROUND")
	band.fill:SetAllPoints()
	UI.Paint(band.fill, C.bg, 0.55)
	band.rule = band:CreateTexture(nil, "BORDER")
	band.rule:SetPoint("TOPLEFT")
	band.rule:SetPoint("TOPRIGHT")
	band.rule:SetHeight(1)
	UI.Paint(band.rule, C.border, 0.9)
	return band
end

-- Words that act: dim, lit under the mouse.
local function Link(parent, text, onClick)
	local b = CreateFrame("Button", nil, parent)
	b.text = UI.Text(b, text, 11, true, C.dim)
	b.text:SetPoint("CENTER")
	b:SetSize(math.ceil(b.text:GetStringWidth()) + 8, 20)
	b:SetScript("OnEnter", function(self) UI.Ink(self.text, C.head) end)
	b:SetScript("OnLeave", function(self) UI.Ink(self.text, C.dim) end)
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick()
	end)
	return b
end

-- A small glyph of the family's (the menus' and hovers' set) or a texture, lit in the accent.
local function Glyph(parent, name, size, color)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	if name then UI.GlyphArt(t, name) end
	t:SetSize(size, size)
	UI.Tint(t, color or C.hot)
	return t
end

-- A small mark drawn in a well (your addons' switches), and all of them put away.
local function Mark(well, x, y, w, h, color, alpha)
	local n = #well.marks + 1
	local t = well.marks[n] or well:CreateTexture(nil, "ARTWORK")
	well.marks[n] = t
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", x, -y)
	t:SetSize(w, h)
	UI.Paint(t, color, alpha or 1)
	t:Show()
end
local function Wipe(well)
	for _, t in ipairs(well.marks or {}) do t:Hide() end
	if well.marks then wipe(well.marks) end
end

local function Greeting()
	if greet then return greet end
	local f = CreateFrame("Frame", "ShySetupGreeting", UIParent)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
	f:SetFrameStrata("DIALOG")
	f:EnableMouse(true)   -- so clicks don't fall through to the world
	f:Hide()
	f.base = {}
	local function Later()
		win.away = true   -- (as the window's Not now: not offered again until the next login)
		f:Hide()
		PutBack()            -- (a page changed alone put its pick on the screen: it goes back)
		win.planned = nil
		if f.list then Shy.Others.Settle() end   -- (an addon switched here: its reload is owed)
		Shy.ReloadAsk()   -- (a reload that waited for setup's is asked for now)
		-- (asked for from /shy: back to it, where you were)
		if win.fromHub then
			win.fromHub = nil
			Shy.Hub.Open()
		end
	end
	local head = UI.Head(f, { size = "window", brand = "", close = Later })   -- (the family's name: the headline is under it)
	local body = UI.Body(f)
	local inner = GREET.W - 2 * GREET.PAD
	local y = GREET.TOP

	-- The steps, in the header (UI.Stepper, as the walk's): those done a way back to them.
	f.stepper = UI.Stepper(head)
	f.stepper:SetPoint("RIGHT", head.close, "LEFT", -14, 0)
	function f:Steps()
		local names, faces = {}, {}
		local function Add(name, face)
			names[#names + 1], faces[#faces + 1] = name, face
		end
		if self.asks then Add("Play as", "ask") end
		if self:Due() then Add("Addons", "addons") end
		Add("Your setup", "told")
		local at = #faces
		for i, face in ipairs(faces) do
			if face == self.face then at = i end
		end
		self.stepper:Set(#names > 1 and names or nil, at, function(i) self:Face(faces[i], false, true) end)
	end

	-- A soft light in the accent falling from the header, behind the hero (the welcome's one flourish).
	f.light = body:CreateTexture(nil, "BACKGROUND", nil, 3)
	f.light:SetTexture(Shy.MEDIA .. "TalkStageGlow")
	f.light:SetTexCoord(0, 1, 1, 0)
	f.light:SetPoint("TOP", body, "TOP", 0, -26)
	f.light:SetSize(GREET.W - 120, 170)
	UI.Tint(f.light, C.hot, 0.2)

	-- The hero, over Play as and Your setup: the fox, your name, a line, the question.
	f.mark = B.CreateEmblem(body, core.mark, GREET.MARK)
	f.mark:SetPoint("CENTER", body, "TOP", 0, -(y + GREET.MARK / 2))
	y = y + GREET.MARK + 8
	-- (A player's name: UI.NameFont covers every alphabet.)
	f.name = UI.Words(body, UI.NameFont(26), C.hot, { wrap = false })
	f.name:SetPoint("TOP", body, "TOP", 0, -y)
	f.name:SetWidth(inner)
	f.name:SetJustifyH("CENTER")
	y = y + 34
	f.line = B.CreateLine(body, 140, 2, 16, true)
	f.line:SetPoint("TOP", body, "TOP", 0, -y)
	y = y + 12
	f.words = UI.Text(body, "", 13, true, C.text)
	f.words:SetPoint("TOP", body, "TOP", 0, -y)
	f.words:SetWidth(inner)
	f.words:SetJustifyH("CENTER")
	y = y + 28
	f.under = y

	-- The plain heading, over Your addons: its name at the left, a line, a sentence.
	local top = GREET.TOP + 2
	f.title = UI.Text(body, "Your addons", 20, true, C.hot)
	f.title:SetPoint("TOPLEFT", GREET.PAD, -top)
	f.rule = B.CreateLine(body, 72, 2, 16, true)
	f.rule:SetPoint("TOPLEFT", GREET.PAD, -(top + 28))
	f.lead = UI.Text(body, "Your UI already does what these do. Two addons doing one job can clash.", 13, false, C.text)
	f.lead:SetPoint("TOPLEFT", GREET.PAD, -(top + 40))
	f.plain = top + 66

	-- The foot: the way out at its left, the step's own buttons at its right, the one that goes on last.
	f.band = Band(body)
	f.later = UI.Button(f.band, "Not now", FEET.LATER, Later)
	f.later:SetPoint("LEFT", GREET.PAD, 0)
	f.back = UI.Text(f.band, "", 11, false, C.dim)
	f.back:SetPoint("LEFT", f.later, "RIGHT", GREET.GAP + 4, 0)

	-- Play as: the class's builds (Shy.Build.Tiles, made as it first comes up). A pick moves on.
	f.ask = CreateFrame("Frame", nil, body)
	f.ask:SetPoint("TOPLEFT", GREET.PAD, -f.under)
	f.ask:SetSize(inner, 1)
	f.note = UI.Text(f.ask, "Your pick sets your screen layout, keys, gear advice and threat colors. You can change it later.", 11, false, C.dim)
	f.note:SetWidth(inner)
	f.note:SetJustifyH("CENTER")
	f.hint = CreateFrame("Frame", nil, f.band)
	f.hint:SetSize(1, 20)
	f.hint:SetPoint("RIGHT", -GREET.PAD, 0)
	f.hint.text = UI.Text(f.hint, "Pick one to continue", 12, true, C.alert)
	f.hint.text:SetPoint("RIGHT")
	f.hint.dot = f.hint:CreateTexture(nil, "ARTWORK")
	f.hint.dot:SetTexture(Shy.Skin.GLYPH.dot)
	f.hint.dot:SetSize(8, 8)
	f.hint.dot:SetPoint("RIGHT", f.hint.text, "LEFT", -6, 0)
	UI.Tint(f.hint.dot, C.alert)

	-- Your setup: what was set up, a line a pick in a card. Its two ways on are the foot's.
	f.told = CreateFrame("Frame", nil, body)
	f.told:SetPoint("TOPLEFT", GREET.PAD, -f.under)
	f.told:SetSize(inner, 1)
	f.card = CreateFrame("Frame", nil, f.told)
	f.card:SetPoint("TOPLEFT")
	f.card:SetWidth(inner)
	UI.Skin(f.card, C.row, C.border)
	f.who = UI.Text(f.card, "", 11, false, C.dim)
	f.who:SetPoint("LEFT", f.card, "TOPLEFT", GREET.IN, -GREET.CAP / 2)
	f.can = UI.Text(f.card, "Every line can be changed", 11, false, C.dim)
	f.can:SetPoint("RIGHT", f.card, "TOPRIGHT", -GREET.IN, -GREET.CAP / 2)
	f.capRule = f.card:CreateTexture(nil, "BORDER")
	f.capRule:SetPoint("TOPLEFT", 1, -GREET.CAP)
	f.capRule:SetPoint("TOPRIGHT", -1, -GREET.CAP)
	f.capRule:SetHeight(1)
	UI.Paint(f.capRule, C.border, 0.9)
	f.saved = UI.Text(f.told, "Nothing is saved until you press Start playing. It reloads your UI once.", 11, false, C.dim)
	f.saved:SetWidth(inner)
	f.saved:SetJustifyH("CENTER")
	f.rows = {}

	-- Start playing is Finish (FinishKey): the press sets the character up, the release reloads.
	f.quick = UI.Button(f.band, "Start playing", GREET.START, function() end)
	f.quick:SetPrimary(true)
	f.quick:SetPoint("RIGHT", -GREET.PAD, 0)
	FinishKey(f.quick)
	f.quick.after = function(done)
		if done then f:Hide() end
	end
	f.walk = UI.Button(f.band, "Customize", GREET.DECIDE, function()
		f:Hide()
		win.greeted = true
		S.Open()
		-- (What to play was asked here: on to the page after it.)
		local at = win.order[1] == OVERVIEW and 2 or 1
		if win.order[at] == "talents" and win.order[at + 1] then at = at + 1 end
		Go(win.order[at], 1)
	end)
	f.walk:SetPoint("RIGHT", f.quick, "LEFT", -GREET.GAP, 0)
	-- A character set up already, nothing changed here: Done puts it away. Nothing runs, nothing reloads.
	f.done = UI.Button(f.band, "Done", GREET.DECIDE, Later)
	f.done:SetPrimary(true)
	f.done:SetPoint("RIGHT", -GREET.PAD, 0)
	f.done:Hide()

	-- Your addons, while any is due: your other addons doing a job your UI does. A line each with its own button,
	-- as their window has them (Shy.Others); nobody starts playing with them undecided. What is switched goes with
	-- setup's reload.
	f.theirs = CreateFrame("Frame", nil, body)
	f.theirs:SetPoint("TOPLEFT", GREET.PAD, -f.plain)
	f.theirs:SetSize(inner, 1)
	f.table = CreateFrame("Frame", nil, f.theirs)
	f.table:SetPoint("TOPLEFT")
	f.table:SetWidth(inner)
	UI.Skin(f.table, C.row, C.border)
	f.count = UI.Text(f.table, "", 11, false, C.dim)
	f.count:SetPoint("LEFT", f.table, "TOPLEFT", GREET.IN, -GREET.CAP / 2)
	f.allOff = Link(f.table, "Turn all off", function()
		local O = Shy.Others
		for _, entry in ipairs(f.list) do
			if O.On(entry) then O.Switch(entry, false) end
		end
		f:Theirs()
	end)
	f.allOff:SetPoint("RIGHT", f.table, "TOPRIGHT", -GREET.IN + 4, -GREET.CAP / 2)
	f.keepAll = Link(f.table, "Keep these", function()
		Shy.Others.KeepOn(f.list)
		f:Theirs()
	end)
	f.keepAll:SetPoint("RIGHT", f.allOff, "LEFT", -GREET.GAP, 0)
	f.tableRule = f.table:CreateTexture(nil, "BORDER")
	f.tableRule:SetPoint("TOPLEFT", 1, -GREET.CAP)
	f.tableRule:SetPoint("TOPRIGHT", -1, -GREET.CAP)
	f.tableRule:SetHeight(1)
	UI.Paint(f.tableRule, C.border, 0.9)
	f.safe = CreateFrame("Frame", nil, f.theirs)
	f.safe:SetSize(inner, 18)
	f.safe.text = UI.Text(f.safe, "Nothing is deleted. /shy addons brings any of them back.", 11, false, C.dim)
	f.safe.text:SetPoint("CENTER", 9, 0)
	f.safe.mark = Glyph(f.safe, S.GLYPH.check, 10, C.good)
	f.safe.mark:SetPoint("RIGHT", f.safe.text, "LEFT", -6, 0)
	local function Sorted()
		f.sorted = true
		Shy.Others.Settle()
		f:Face("told")
	end
	f.next = UI.Button(f.band, "Next", FEET.NEXT, function()
		Shy.Others.KeepOn(f.list)   -- (left on: looked at, and kept)
		Sorted()
	end)
	f.next:SetPrimary(true)
	f.next:SetPoint("RIGHT", -GREET.PAD, 0)
	f.prev = UI.Button(f.band, "Back", FEET.BACK, function() f:Face("ask", false, true) end)
	f.prev:SetPoint("RIGHT", f.next, "LEFT", -GREET.GAP, 0)
	f.tally = UI.Text(f.band, "", 11, false, C.dim)
	-- Those to ask about, listed once a showing of the game: a line stays where it is while you switch it. More
	-- than VIEW scroll.
	function f:Due()
		if not self.list then
			local O = Shy.Others
			local list = O and O.Lines and O.Doubled() or {}
			if #list == 0 then return false end
			self.list = list
			local host, width = self.table, inner
			if #list > GREET.VIEW then
				self.scroll = UI.ScrollArea(self.table, inner - 2, GREET.VIEW * GREET.LINE)
				self.scroll:SetPoint("TOPLEFT", 1, -GREET.CAP - 1)
				local fade = self.table:CreateTexture(nil, "OVERLAY")
				fade:SetPoint("BOTTOMLEFT", 1, 1)
				fade:SetPoint("BOTTOMRIGHT", -15, 1)
				fade:SetHeight(26)
				fade:SetColorTexture(1, 1, 1, 1)
				fade:SetGradient("VERTICAL", CreateColor(C.row[1], C.row[2], C.row[3], 1), CreateColor(C.row[1], C.row[2], C.row[3], 0))
				host, width = self.scroll.content, inner - 16
			end
			local lines, ends = O.Lines(host, GREET.IN, host == self.table and GREET.CAP + 1 or 0, list,
				function(region) return region end, function() self:Theirs() end, width)
			self.lines = lines
			if self.scroll then host:SetHeight(ends) end
			local view = self.scroll and GREET.VIEW * GREET.LINE + GREET.CAP + 2 or ends + 1
			self.table:SetHeight(view)
		end
		return true
	end
	function f:Theirs()
		local O = Shy.Others
		O.Tell(self.lines)
		local off, kept, open = 0, 0, 0
		for _, entry in ipairs(self.list) do
			if not O.On(entry) then off = off + 1
			elseif O.Kept(entry) then kept = kept + 1
			else open = open + 1 end
		end
		local n = #self.list
		local groups = self.lines.heads and #self.lines.heads or 0
		self.count:SetText(n == 1 and "One addon does a job your UI already does" or ("%d addons do jobs your UI already does"):format(n)
			.. (groups > 1 and (", in %d groups"):format(groups) or ""))
		self.keepAll:SetShown(open > 0)
		self.allOff:SetShown(off < n)
		self.tally:SetText(("%d off, %d kept"):format(off, kept) .. (open > 0 and ". The rest stay on." or ""))
	end
	-- After what you play: your other addons until they were looked at, then what was set up.
	function f:On(quiet)
		self:Face((not self.sorted and self:Due()) and "addons" or "told", quiet)
	end

	-- A told line: a picture of the pick, its step's name over what it holds and why, and Change. A line changed
	-- since you first saw it says so, with what it was and Undo.
	local function Change(id)
		if (id == "talents" and f.asks) or id == "addons" then
			f:Face(id == "addons" and "addons" or "ask")
			return
		end
		f:Hide()
		win.greeted = true
		S.Open(id, true)
	end
	local function Undo(id)
		local was = f.base[id]
		if not was then return end
		win.plan[id] = was.copy and Shy.CopyTable(was.copy) or nil
		local step = Step(id)
		if id == "talents" then S.Follow(win.plan) end
		local wear = step and (step.Shown or step.Wear)
		if wear then
			local ok, err = pcall(wear, win.plan)
			if not ok then geterrorhandler()(err) end
		end
		f:Face("told", true)
	end
	local function Row(n)
		local row = CreateFrame("Button", nil, f.card)
		row:SetSize(inner - 2, GREET.ROW)
		UI.Skin(row, C.row, C.row)
		row.fill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
		row.fill:SetAllPoints()
		UI.Paint(row.fill, C.hot, 0.07)
		row.fill:Hide()
		row.rule = row:CreateTexture(nil, "BORDER")
		row.rule:SetPoint("BOTTOMLEFT", GREET.IN, 0)
		row.rule:SetPoint("BOTTOMRIGHT", -GREET.IN, 0)
		row.rule:SetHeight(1)
		UI.Paint(row.rule, C.border, 0.5)
		row.well = CreateFrame("Frame", nil, row)
		row.well:SetSize(GREET.WELL_W, GREET.WELL_H)
		row.well:SetPoint("LEFT", 6, 0)
		row.well:SetClipsChildren(true)
		UI.Skin(row.well, C.bg, C.border)
		row.pics = {}
		-- (what you play: its tab's icon in a slot, as square as the game draws it)
		row.spec = CreateFrame("Frame", nil, row.well)
		row.spec:SetSize(GREET.WELL_H - 8, GREET.WELL_H - 8)
		row.spec:SetPoint("CENTER")
		row.icon = row.spec:CreateTexture(nil, "ARTWORK")
		row.icon:SetAllPoints()
		row.slot = Shy.Slot.New(row.spec, { icon = row.icon, hover = false })
		row.glyph = row.well:CreateTexture(nil, "ARTWORK")
		row.glyph:SetPoint("CENTER")
		row.big = UI.Text(row.well, "", 14, true, C.hot)
		row.big:SetPoint("CENTER")
		row.flat = CreateFrame("Frame", nil, row.well)
		row.flat:SetAllPoints()
		row.flat.marks = {}
		local x = 6 + GREET.WELL_W + 12
		row.name = UI.Text(row, "", 11, false, C.dim)
		row.name:SetPoint("TOPLEFT", x, -10)
		row.what = UI.Text(row, "", 15, true, C.head)
		row.what:SetPoint("TOPLEFT", x, -26)
		row.what:SetWordWrap(false)
		row.wash = row:CreateTexture(nil, "BACKGROUND", nil, 2)
		row.wash:SetPoint("TOPLEFT", 1, -1)
		row.wash:SetPoint("BOTTOMLEFT", 1, 1)
		row.wash:SetWidth(GREET.W / 2)
		row.wash:SetColorTexture(1, 1, 1, 1)
		row.wash:SetGradient("HORIZONTAL", CreateColor(C.hot[1], C.hot[2], C.hot[3], 0.16), CreateColor(C.hot[1], C.hot[2], C.hot[3], 0))
		row.wash:Hide()
		row.tag = CreateFrame("Frame", nil, row)
		row.tag:SetHeight(16)
		UI.Skin(row.tag, C.hot, C.hot)
		row.tag.text = UI.Text(row.tag, "Changed", 10, true, C.bg)
		row.tag.text:SetPoint("CENTER")
		row.tag:SetWidth(math.ceil(row.tag.text:GetStringWidth()) + 12)
		row.tag:SetPoint("LEFT", row.what, "RIGHT", 8, 0)
		row.why = UI.Text(row, "", 12, false, C.dim)
		row.why:SetWordWrap(false)
		row.change = UI.Button(row, "Change", GREET.CHANGE, function() Change(row.id) end)
		row.change:SetPoint("RIGHT", -GREET.IN, 0)
		row.undo = Link(row, "Undo", function() Undo(row.id) end)
		row.undo:SetPoint("RIGHT", row.change, "LEFT", -GREET.GAP, 0)
		-- (a line made yours, or never set up: one click back to what is recommended)
		row.reset = Link(row, "Reset", function()
			local step = Step(row.id)
			if not (step and step.Reset) then return end
			local ok, err = pcall(step.Reset, win.plan)
			if not ok then geterrorhandler()(err) end
			local wear = step.Shown or step.Wear
			if ok and wear then pcall(wear, win.plan) end
			f:Face("told", true)
		end)
		row.reset:SetPoint("RIGHT", row.change, "LEFT", -GREET.GAP, 0)
		row:SetScript("OnEnter", function(self) self.fill:Show() end)
		row:SetScript("OnLeave", function(self) self.fill:Hide() end)
		row:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			Change(self.id)
		end)
		f.rows[n] = row
		return row
	end

	-- A line's picture: the step's own where it draws one (the theme's card, the screen's layout, as their pages
	-- have them), the tree's icon for what you play, the size as a number, your addons as a row of switches; else
	-- its step's glyph.
	local function Picture(row, id, step)
		row.spec:Hide()
		row.glyph:Hide()
		row.big:Hide()
		row.flat:Hide()
		Wipe(row.flat)
		for _, pic in pairs(row.pics) do pic:Hide() end
		if step and step.Picture then
			local pic = row.pics[id]
			if not pic then
				local ok, made = pcall(step.Picture, row.well, GREET.WELL_W - 2, GREET.WELL_H - 2)
				if ok and made then
					pic = made
					row.pics[id] = pic
				elseif not ok then
					geterrorhandler()(made)
				end
			end
			if pic then
				local ok, err = pcall(pic.Refresh, pic, win.plan)
				if ok and err ~= false then
					pic:Show()
					return
				end
				if not ok then geterrorhandler()(err) end
			end
		end
		if id == "talents" then
			local Build = Shy.Build
			local icon = Build and Build.Icon and Build.Icon(Build.Planned(win.plan))
			if icon then
				row.icon:SetTexture(icon)
				row.slot:Empty(false)
				row.spec:Show()
				return
			end
		elseif id == "scale" then
			row.big:SetText(Brief(step) or "")
			row.big:ClearAllPoints()
			row.big:SetPoint("CENTER", 10, 0)
			row.big:Show()
			UI.GlyphArt(row.glyph, "window")
			row.glyph:SetSize(16, 16)
			UI.Tint(row.glyph, C.hot)
			row.glyph:ClearAllPoints()
			row.glyph:SetPoint("RIGHT", row.big, "LEFT", -6, 0)
			row.glyph:Show()
			return
		elseif id == "addons" then
			-- (a switch an addon, off ones first: the row of them centred)
			local O, off, on = Shy.Others, {}, {}
			for _, entry in ipairs(f.list) do
				local list = O.On(entry) and on or off
				list[#list + 1] = entry
			end
			local n = math.min(#off + #on, 7)
			local x = math.floor((GREET.WELL_W - (n * 9 - 1)) / 2)
			row.flat:Show()
			for i = 1, n do
				local lit = i > #off
				Mark(row.flat, x, 18, 8, 8, lit and C.hot or C.dim, 1)
				if not lit then Mark(row.flat, x + 1, 19, 6, 6, C.bg, 1) end
				x = x + 9
			end
			return
		end
		UI.GlyphArt(row.glyph, step and step.glyph or "options")
		row.glyph:SetSize(24, 24)
		row.glyph:ClearAllPoints()
		row.glyph:SetPoint("CENTER")
		UI.Tint(row.glyph, C.hot)
		row.glyph:Show()
	end

	-- Who it is set up for, then a line a pick (GREET.TOLD), then your addons. Returns how tall the card stands.
	function f:Tell()
		self.who:SetText(("Set up for your level %d %s"):format(UnitLevel("player"), (UnitClass("player"))))
		local n = 0
		local function Line(id, step, what, why)
			n = n + 1
			local row = self.rows[n] or Row(n)
			row.id = id
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 1, -(GREET.CAP + 1 + (n - 1) * GREET.ROW))
			Picture(row, id, step)
			row.name:SetText(step and step.title or "Addons")
			row.what:SetText(what)
			-- (Changed since you first saw it here: said, with what it was.)
			local was = self.base[id]
			if not was and id ~= "addons" then
				was = { brief = what, copy = win.plan[id] and Shy.CopyTable(win.plan[id]) }
				self.base[id] = was
			end
			local changed = was ~= nil and was.brief ~= what
			-- (Not changed by you, but finishing replaces what you have: said too, in an outlined chip.)
			local known, now = pcall(Said, step and step.now, win.plan)
			now = not changed and known and now or nil
			if changed or now then self.dirty = true end
			row.tag.text:SetText(changed and "Changed" or "Will change")
			UI.Ink(row.tag.text, changed and C.bg or C.hot)
			UI.Skin(row.tag, changed and C.hot or C.bg, C.hot)
			row.tag:SetWidth(math.ceil(row.tag.text:GetStringWidth()) + 12)
			row.tag:SetShown(changed or now ~= nil)
			row.undo:SetShown(changed)
			local fine, resets = pcall(Said, step and step.Reset and step.resets, win.plan)
			resets = not changed and fine and resets or nil
			row.reset.text:SetText(resets or "Reset")
			row.reset:SetWidth(math.ceil(row.reset.text:GetStringWidth()) + 8)
			row.reset:SetShown(resets ~= nil)
			row.why:ClearAllPoints()
			row.why:SetPoint("BOTTOMLEFT", row.what, "BOTTOMRIGHT", row.tag:IsShown() and row.tag:GetWidth() + 16 or 8, 1)
			row.why:SetPoint("RIGHT", row.change, "LEFT", -((changed or resets) and GREET.UNDO + GREET.GAP or GREET.GAP), 0)
			row.why:SetText(changed and ("was " .. was.brief) or now and ("replaces " .. now) or why or "")
			UI.SetBorder(row, changed and C.hot or C.row)
			row.wash:SetShown(changed)
			row:Show()
		end
		for _, id in ipairs(GREET.TOLD) do
			local step = Step(id)
			local ok, brief = pcall(Said, step and step.brief, win.plan)
			local known, told = pcall(Said, step and step.told, win.plan)
			if step and ok and brief and not (known and told == false) then
				local fine, why = pcall(Said, step.why, win.plan)
				Line(id, step, brief, fine and why ~= "" and why or nil)
			end
		end
		-- Then your other addons as you left them, and the way back to them.
		if self:Due() then
			local O, on, off = Shy.Others, 0, 0
			for _, entry in ipairs(self.list) do
				if O.On(entry) then on = on + 1 else off = off + 1 end
			end
			Line("addons", nil, off == 0 and ("%d kept"):format(on)
				or on == 0 and ("%d turned off"):format(off) or ("%d turned off, %d kept"):format(off, on), "when you finish")
		end
		for i = n + 1, #self.rows do self.rows[i]:Hide() end
		if self.list and Shy.Others.Pending() then self.dirty = true end
		local card = GREET.CAP + 2 + n * GREET.ROW
		self.card:SetHeight(card)
		self.saved:ClearAllPoints()
		self.saved:SetPoint("TOP", self.card, "BOTTOM", 0, -10)
		return card + 10 + 14
	end

	-- A step coming up slides in a little, from the right going on, from the left going back.
	local slide = CreateFrame("Frame", nil, f)
	slide:Hide()
	slide:SetScript("OnUpdate", function(self, elapsed)
		self.t = self.t + elapsed
		local k = math.min(self.t / GREET.SLIDE, 1)
		local x = self.from * (1 - k) * (2 - k)
		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", GREET.PAD + x, -self.y)
		if k >= 1 then self:Hide() end
	end)
	local function Slide(frame, y, back)
		slide.frame, slide.y, slide.t, slide.from = frame, y, 0, back and -GREET.SHIFT or GREET.SHIFT
		slide:Show()
	end

	-- One step up, the window as tall as it stands, the foot under it. quiet: no fade (the window itself comes up).
	-- back: going back a step (it slides in from the left).
	function f:Face(face, quiet, back)
		local Build = Shy.Build
		if face == "ask" and not self.builds then
			self.builds = Build.Tiles(self.ask, inner, win.plan, { asked = true, picked = function(build)
				self.hint.text:SetText(build.name .. " it is")
				UI.Ink(self.hint.text, C.good)
				self.hint.dot:SetTexture(S.GLYPH.check)
				self.hint.dot:SetSize(11, 11)
				UI.Tint(self.hint.dot, C.good)
				local mine = {}
				self.going = mine
				C_Timer.After(GREET.HOLD, function()
					if self.going == mine and self:IsShown() and self.face == "ask" then self:On() end
				end)
			end })
			self.builds:SetPoint("TOPLEFT")
		end
		self.face = face
		local ask, theirs, told = face == "ask", face == "addons", face == "told"
		for _, hero in ipairs({ self.mark, self.name, self.line, self.words, self.light }) do hero:SetShown(not theirs) end
		for _, plain in ipairs({ self.title, self.rule, self.lead }) do plain:SetShown(theirs) end
		self.ask:SetShown(ask)
		self.theirs:SetShown(theirs)
		self.told:SetShown(told)
		self.hint:SetShown(ask)
		self.walk:SetShown(told)
		self.next:SetShown(theirs)
		self.prev:SetShown(theirs and self.asks)
		self.tally:SetShown(theirs)
		self.tally:ClearAllPoints()
		self.tally:SetPoint("RIGHT", (theirs and self.asks) and self.prev or self.next, "LEFT", -12, 0)
		self.back:SetShown(not theirs)
		-- Beside Not now: how to come back, or why Start playing can't go ahead yet.
		local stuck = told and self.quick.dimmed and self.quick.why
		self.back:SetText(stuck or "Opens again with /shy setup.")
		UI.Ink(self.back, stuck and C.alert or C.dim)
		local tall, at = 0, self.under
		if ask then
			self.words:SetText("What do you want to play?")
			self.builds:Refresh()
			local picked = false
			for _, tile in ipairs(self.builds.tiles) do picked = picked or tile.on == true end
			self.going = nil
			self.hint.text:SetText(picked and "Pick again to go on" or "Pick one to continue")
			UI.Ink(self.hint.text, C.alert)
			self.hint.dot:SetTexture(Shy.Skin.GLYPH.dot)
			self.hint.dot:SetSize(8, 8)
			UI.Tint(self.hint.dot, C.alert)
			self.hint:SetWidth(self.hint.text:GetStringWidth() + 14)
			self.note:ClearAllPoints()
			self.note:SetPoint("TOP", self.builds, "BOTTOM", 0, -12)
			tall = self.builds:GetHeight() + 12 + 14
		elseif theirs then
			at = self.plain
			self:Theirs()
			self.safe:ClearAllPoints()
			self.safe:SetPoint("TOP", self.table, "BOTTOM", 0, -8)
			tall = self.table:GetHeight() + 8 + 18
		else
			self.words:SetText(self.setUp and "Here's your setup. Change any line, then save." or "Here's your setup. Start playing, or customize it first.")
			self.dirty = false
			tall = self:Tell()
		end
		-- Set up already and nothing changed: Done, no reload. Else Start playing, or Save changes.
		local idle = told and self.setUp and not self.dirty
		self.quick:SetShown(told and not idle)
		self.done:SetShown(idle)
		if told and self.setUp then
			self.saved:SetText(idle and "Your setup is as you left it. Change a line to save something new."
				or "Nothing changes until you press Save changes.")
		end
		self:Steps()
		UI.BodyFit(self, GREET.W, at + tall + 18 + GREET.BAND)
		if not quiet then
			local frame = ask and self.ask or theirs and self.theirs or self.told
			UI.FadeIn(frame, FADE)
			Slide(frame, at, back)
		end
	end

	-- (Your addons switched in their own window meanwhile: their line says what stands now.)
	Shy:On("SHY_OTHERS", function()
		if f:IsShown() and f.face == "told" then f:Face("told", true) end
	end)
	-- Put away, whatever put it away: its key with it, unless a reload is on its way through it.
	f:HookScript("OnHide", function()
		local key = f.quick.key
		if key.armed == nil and not InCombatLockdown() then key:Hide() end
	end)
	-- A fight puts it away (nothing can be set up in one); the offer brings it back after.
	local watch = CreateFrame("Frame")
	watch:RegisterEvent("PLAYER_REGEN_DISABLED")
	watch:SetScript("OnEvent", function()
		if not InCombatLockdown() then f.quick.key:Hide() end
		f:Hide()
	end)
	greet = f
	return f
end

function S.Greeting() return greet ~= nil and greet:IsShown() end

-- A step's plan read again, the world changed under it (your layout saved in Edit Mode): its Restate, then the
-- welcome and the window told again. What you picked here stands (the step keeps it); its line starts afresh, so
-- what it says now isn't called a change.
function S.Restate(id)
	if not win.planned then return end
	local step = Step(id)
	if not (step and step.Restate) then return end
	local ok, err = pcall(step.Restate, win.plan)
	if not ok then
		geterrorhandler()(err)
		return
	end
	if greet then
		greet.base[id] = nil
		if greet:IsShown() and greet.face == "told" then greet:Face("told", true) end
	end
	if win.open then Show() end
end

-- From a page opened from the welcome (a line's Change, or Customize) back to it: the window put away, what
-- was picked there kept, the welcome's Your setup up again saying what changed.
function S.Back()
	if not win.open then return end
	win.open, win.alone, win.greeted = false, nil, nil
	Awake(false)
	local key = win.box and win.box.finish.key
	if key and not InCombatLockdown() then key:Hide() end
	for _, f in pairs(win.pages) do f:Hide() end
	win.shown, win.section = nil, nil
	guest.words = "Setting up"
	Shy.Hub.Return(true)
	S.Greet()
end

-- The send-off
--
-- A character just set up is shown, once, where to go when it wants more: other themes, moving things about,
-- your keys, every setting. A door each, side by side, and a way out; each door closes it. Shown with the line
-- setup says when it is over (Tell), after its reload if it had one.
--   S.SendOff()    show it          S.Sent()   whether it is up
local sent

-- A door: its glyph in a well, its name, a sentence, all centred. Under the mouse its edge lights.
local function Door(parent, width, glyph, name, words, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, GREET.DOOR)
	UI.Skin(b, C.row, C.border)
	b.well = CreateFrame("Frame", nil, b)
	b.well:SetSize(36, 36)
	b.well:SetPoint("TOP", 0, -14)
	UI.Skin(b.well, C.bg, C.border)
	b.glyph = Glyph(b.well, glyph, 20, C.hot)
	b.glyph:SetPoint("CENTER")
	b.name = UI.Text(b, name, 13, true, C.head)
	b.name:SetPoint("TOP", b.well, "BOTTOM", 0, -10)
	b.say = UI.Text(b, words, 11, false, C.dim)
	b.say:SetPoint("TOP", b.name, "BOTTOM", 0, -5)
	b.say:SetWidth(width - 20)
	b.say:SetJustifyH("CENTER")
	b.say:SetWordWrap(true)
	b.glow = b:CreateTexture(nil, "BORDER", nil, -1)
	b.glow:SetTexture(Skin.GLOW)
	b.glow:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	b.glow:SetPoint("TOPLEFT", -3, 3)
	b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
	UI.Tint(b.glow, C.hot, 0.6)
	b.glow:Hide()
	b:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		self.glow:Show()
	end)
	b:SetScript("OnLeave", function(self)
		UI.SetBorder(self, C.border)
		self.glow:Hide()
	end)
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick()
	end)
	return b
end

function S.Sent() return sent ~= nil and sent:IsShown() end

function S.SendOff()
	-- (Not over a fight: once it is over.)
	if InCombatLockdown() then
		local wait = CreateFrame("Frame")
		wait:RegisterEvent("PLAYER_REGEN_ENABLED")
		wait:SetScript("OnEvent", function(self)
			self:UnregisterAllEvents()
			S.SendOff()
		end)
		return
	end
	if not sent then
		local f = CreateFrame("Frame", "ShySetupSendOff", UIParent)
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 70)
		f:SetFrameStrata("DIALOG")
		f:EnableMouse(true)   -- so clicks don't fall through to the world
		f:Hide()
		local function Close() f:Hide() end
		UI.Head(f, { size = "window", brand = "", close = Close })
		local body = UI.Body(f)
		local inner = GREET.SENT - 2 * GREET.PAD
		local y = GREET.TOP
		f.light = body:CreateTexture(nil, "BACKGROUND", nil, 3)
		f.light:SetTexture(Shy.MEDIA .. "TalkStageGlow")
		f.light:SetTexCoord(0, 1, 1, 0)
		f.light:SetPoint("TOP", body, "TOP", 0, -26)
		f.light:SetSize(GREET.SENT - 100, 190)
		UI.Tint(f.light, C.hot, 0.22)
		f.mark = B.CreateEmblem(body, core.mark, 72)
		f.mark:SetPoint("CENTER", body, "TOP", 0, -(y + 36))
		y = y + 72 + 10
		f.name = UI.Words(body, UI.NameFont(26), C.hot, { wrap = false })
		f.name:SetPoint("TOP", body, "TOP", 0, -y)
		f.name:SetWidth(inner)
		f.name:SetJustifyH("CENTER")
		y = y + 36
		-- Saved, between two lines.
		-- Saved, between two lines fading out from it.
		f.said = CreateFrame("Frame", nil, body)
		f.said:SetSize(inner, 18)
		f.said:SetPoint("TOP", body, "TOP", 0, -y)
		f.saved = UI.Text(f.said, "Saved", 12, true, C.good)
		f.saved:SetPoint("CENTER", 8, 0)
		f.tick = Glyph(f.said, S.GLYPH.check, 10, C.good)
		f.tick:SetPoint("RIGHT", f.saved, "LEFT", -5, 0)
		for side = -1, 1, 2 do
			local rule = f.said:CreateTexture(nil, "ARTWORK")
			rule:SetSize(110, 1)
			rule:SetColorTexture(1, 1, 1, 1)
			local near, far = CreateColor(C.good[1], C.good[2], C.good[3], 0.7), CreateColor(C.good[1], C.good[2], C.good[3], 0)
			if side < 0 then
				rule:SetPoint("RIGHT", f.tick, "LEFT", -10, 0)
				rule:SetGradient("HORIZONTAL", far, near)
			else
				rule:SetPoint("LEFT", f.saved, "RIGHT", 10, 0)
				rule:SetGradient("HORIZONTAL", near, far)
			end
		end
		y = y + 26
		f.words = UI.Text(body, "If you want to change something later, start here.", 13, false, C.text)
		f.words:SetPoint("TOP", body, "TOP", 0, -y)
		f.words:SetWidth(inner)
		f.words:SetJustifyH("CENTER")
		y = y + 30
		f.doors = {}
		local function Add(glyph, name, words, onClick)
			f.doors[#f.doors + 1] = { glyph, name, words, onClick }
		end
		Add("star", "Change the theme", "Colors, housings and fonts.", function()
			Close()
			Shy.Hub.Open("theme")
		end)
		-- (Layout mode opens by a secure key laid over the door: the click is the key's, and the card goes as
		-- layout mode comes up.)
		Add("window", "Move things around", "Drag any part of your screen.", function() end)
		-- (Your keys are never laid out without your say: this is where a new character finds them.)
		local keys = Shy.Keys
		if keys and keys.Mine and keys.Mine() then
			Add("action", "Your keys", "See and change your keys.", function()
				Close()
				Shy.Hub.Open("keys")
			end)
		end
		Add("options", "All settings", "Everything, by subject.", function()
			Close()
			Shy.Hub.Open("settings")
		end)
		local n = #f.doors
		local each = math.floor((inner - (n - 1) * GREET.GAP) / n)
		for i, one in ipairs(f.doors) do
			local door = Door(body, each, one[1], one[2], one[3], one[4])
			door:SetPoint("TOPLEFT", GREET.PAD + (i - 1) * (each + GREET.GAP), -y)
			f.doors[i] = door
		end
		Shy.HUD.EditModeKey(f.doors[2])
		Shy:On("SHY_HUD_LAYOUT", function(on)
			if on then f:Hide() end
		end)
		y = y + GREET.DOOR + 18
		local band = Band(body)
		f.done = UI.Button(band, "Got it", FEET.NEXT, Close)
		f.done:SetPoint("RIGHT", -GREET.PAD, 0)
		f.done:SetPrimary(true)
		f.back = UI.Text(band, "/shy opens these any time.", 11, false, C.dim)
		f.back:SetPoint("LEFT", GREET.PAD, 0)
		UI.BodyFit(f, GREET.SENT, y + GREET.BAND)
		sent = f
	end
	sent.name:SetText("You're ready to play")
	sent:Show()
	UI.FadeIn(sent, FADE)
	-- (Saved comes in just after the window: what was done, said once it is there.)
	sent.said:SetAlpha(0)
	C_Timer.After(FADE, function()
		if sent:IsShown() then UI.FadeIn(sent.said, FADE) end
	end)
end

-- The one way in: the welcome, for every character, set up or not (one set up sees its setup as it stands, a line
-- to change each). Asked from inside the /shy window (its Home), the window steps aside for it, and comes back
-- where it was once the welcome is put away; Customize opens in it. (The window open already is brought up as
-- it is.)
function S.Start()
	if win.open then
		S.Open()
		return
	end
	win.fromHub = Shy.Hub.IsOpen() and not Shy.Hub.Lent() or nil
	if win.fromHub then Shy.Hub.Close() end
	S.Greet()
end

local waiting   -- asked for in a fight: it comes when the fight is over

function S.Greet()
	-- (Nothing can be set up in a fight: said, and it comes up after.)
	if InCombatLockdown() then
		core:Print("you're in combat. Setup opens after the fight.")
		if not waiting then
			waiting = CreateFrame("Frame")
			waiting:SetScript("OnEvent", function(self)
				self:UnregisterAllEvents()
				if not win.open then S.Greet() end
			end)
		end
		waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local f = Greeting()
	-- Planned once a session: what you picked here, and on a page opened from here, stands until you finish or
	-- put it away.
	if not win.planned then
		S.Plan(win.plan)
		win.planned = true
		wipe(f.base)
	end
	local back = S.Done()
	f.setUp = back
	f.name:SetText((back and "Welcome back, " or "Welcome, ") .. First())
	f.quick:SetLabel(back and "Save changes" or "Start playing")
	f.saved:SetText(back and "Nothing changes until you press Save changes." or "Nothing is saved until you press Start playing. It reloads your UI once.")
	-- What to play is asked first, while nothing says it yet: no talent point spent, none picked here.
	local Build = Shy.Build
	f.asks = Build ~= nil and Build.Tiles ~= nil and #Build.Builds() >= 2
	local known = f.asks and (Build.Spent() > 0 or (win.plan.talents ~= nil and win.plan.talents.picked == true))
	-- Dimmed while setup can't go ahead as it is picked, and saying why.
	local ok, why = S.Check(win.plan)
	f.quick.dimmed, f.quick.why = not ok, why
	f.quick:SetAlpha(ok and 1 or 0.4)
	f.quick.key.armed = nil
	if not InCombatLockdown() then f.quick.key:SetAttribute("type", nil) end
	f:Show()
	if f.asks and not known then f:Face("ask", true) else f:On(true) end
	UI.FadeIn(f, FADE)
end

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

-- The rail's rows: the overview, then every page.
-- A step's walk while it is walked: its pages, in order (none while its `walks` says not).
function Walked(host)
	local out = {}
	local ok, on = pcall(Said, host.walks, win.plan)
	if not (ok and on) then return out end
	for _, step in ipairs(steps) do
		if step.walk == host.id and step.Build then out[#out + 1] = step end
	end
	return out
end

-- Each walked step's pages under its row on the rail, a line each (unfolded while the row is open).
function Branches()
	local box = win.box
	if not box then return end
	for _, step in ipairs(steps) do
		if step.walks then
			local kids = {}
			for i, page in ipairs(Walked(step)) do kids[i] = { key = page.id, label = page.title } end
			box.rail:SetKids(step.id, kids)
		end
	end
end

-- (Each page numbered in the order Next walks them: the family's numbered pin, the open one lit.)
function RailRows()
	local items = {}
	win.order = {}
	guest.focus = Focused()
	if not guest.focus then
		items[1] = { key = OVERVIEW, label = "Overview", glyph = "home" }
		win.order[1] = OVERVIEW
	end
	local n = 0
	for _, group in ipairs(Groups()) do
		for _, step in ipairs(group.steps) do
			if Listed(step) then
				n = n + 1
				items[#items + 1] = { key = step.id, label = step.title, glyph = step.glyph or CARD.GLYPH, step = n }
				win.order[#win.order + 1] = step.id
				for _, page in ipairs(Walked(step)) do win.order[#win.order + 1] = page.id end
			end
		end
	end
	return items
end

-- win.plan is refilled in place, never replaced: the pages hold a reference to it. `at`: the step to open
-- on (its id), the overview unless told. Opened from the /shy window, Not now goes back to it. alone: that page by
-- itself, from the welcome (its line's Change), with a way back to it.
function S.Open(at, alone)
	if greet then greet:Hide() end
	-- (this session the window is the way: closed by the game, it is what comes back. A page alone isn't.)
	if not alone then win.walked = true end
	if not win.open then
		win.back = (Shy.Hub.IsOpen() and not Shy.Hub.Lent()) or win.fromHub == true
		-- (Opened from the welcome, its picks stand, and those of a page opened from it. Else planned anew.)
		if not (win.planned and win.greeted) then
			S.Plan(win.plan)
			win.planned = true
		end
		win.at, win.fresh = OVERVIEW, true
		win.fight = nil
		wipe(win.tabs)
		wipe(win.done)
		-- (What stood before, once: back from the welcome, the screen already wears what was picked.)
		if win.kept == nil then
			win.kept, win.doneWas, win.wasDone = Worn(), Mine().done, S.Done()
			wipe(took)
			wipe(win.first)
			for _, step in ipairs(steps) do win.first[step.id] = Brief(step) end
		end
		win.advanced = Book().advanced == true   -- (opt in: only once you've asked for it)
		guest.items, guest.name, guest.words = RailRows(), First(), "Setting up"
	end
	-- A page alone, from a line of the welcome: every tab of it, no rail, no pips, and its way back to the welcome.
	win.alone = alone and at or nil
	if win.alone then
		local step = Step(at)
		win.advanced = true
		guest.items = RailRows()
		guest.focus = true
		guest.words, guest.name = "Changing", CHANGING[at] or ("your " .. (step and step.title or at):lower())
	end
	local key, tab = Place(at)
	if key and not win.advanced and (not Index(key) or (tab or 1) > 1) then
		win.advanced = true
		guest.items = RailRows()
	end
	if key and Index(key) then
		win.at = key
		win.tabs[key] = tab
	end
	win.open = true
	local box = Shy.Hub.Lend(guest)
	if win.alone then Shy.Hub.Retell(guest) end   -- (lent already: its header says what is changed)
	if not win.box then
		win.box = box
		Build(box)
	end
	Awake(true)
	Branches()
	Lay()
	Show()
end

-- Closed by the player: not offered again this session. Only Finish is an answer for good. back: to the rest of
-- the /shy window (Not now there, or another room asked for), else the window closes.
function S.Close(back)
	win.away = true
	if greet then greet:Hide() end
	if win.open then Out(back) end
	Shy.ReloadAsk()   -- (a reload that waited for setup's is asked for now)
end

-- Offered, the hub and /shy setup
--
-- The window is offered at every login until the character is set up (Finish), once the splash and the
-- intro are over. Closed by the player (Esc, its ×, Not now), it isn't offered again until the next login.
-- The game closes every window of its kind itself (CloseAllWindows) on each loading screen, on dying, as a
-- cinematic takes the screen and as the interface comes back after it: none of that is the player's answer,
-- so it is offered again once the world is back, never in a fight, never over a cinematic, never while dead.

local WAIT = 7   -- seconds after login: the splash is gone and Edit Mode layouts are loaded
local AFTER = 2  -- seconds after a cinematic, a movie or a loading screen: the world is back in view
local ready      -- the login's wait is over
local offer = CreateFrame("Frame")   -- what holds the offer back ending: a fight, a cinematic, a movie, death
local AGAIN = { "PLAYER_REGEN_ENABLED", "CINEMATIC_STOP", "STOP_MOVIE", "PLAYER_ENTERING_WORLD", "PLAYER_ALIVE", "PLAYER_UNGHOST" }

-- Once per round of recommendations: a character set up before it (or found set up before there was a
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
	core:Print(First() .. " is missing " .. (#missing == 1 and "a recommended game setting" or (#missing .. " recommended game settings"))
		.. ": " .. Named(missing, 6) .. ". You can tick " .. (#missing == 1 and "it" or "them") .. " under Game settings in /shy.")
end

local function Offer()
	if not ready or win.open or S.Greeting() or InCombatLockdown() or Watching() or UnitIsDeadOrGhost("player") then return end
	if S.Done() or win.away then
		offer:UnregisterAllEvents()
		return
	end
	-- The welcome first; once the window has been opened this session, the window again.
	if win.walked then S.Open() else S.Greet() end
end

offer:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" then Offer() else C_Timer.After(AFTER, Offer) end
end)
-- A movie skipped by the player ends without an event.
MovieFrame:HookScript("OnHide", function() C_Timer.After(AFTER, Offer) end)

-- The game closing every window: the events it does so on, and the interface coming back (UIParent shown
-- again, after a cinematic or anything else that took the screen). Its own handlers run in the same frame.
local closer = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_DEAD", "CINEMATIC_START" }) do closer:RegisterEvent(event) end
closer:SetScript("OnEvent", function() gameAt = GetTime() end)
UIParent:HookScript("OnShow", function()
	gameAt = GetTime()
	C_Timer.After(AFTER, Offer)
end)

Shy:On("SHY_ADDON_LOADED", function(a)
	if a ~= core then return end
	if core.isNew then Book().untouched = true end
	win.away = nil   -- (a new session: nothing was put away yet)
	ShyCoreDB.setupSpot = nil   -- (where its own window stood: it walks the /shy window now)
	RepairDock()
end)

Shy:On("SHY_LOGIN", function()
	RepairDock()   -- again, past the chat windows' own load
	Proven()   -- (a character whose own files were deleted starts over)
	local book, mine = Book(), Mine()
	if next(book.chars, (next(book.chars))) then book.untouched = nil end   -- a second character exists
	-- A record from before: `asked` with a round of recommendations and nothing done was a character found
	-- with its screen already set up, before there was a window: set up. `asked` alone was a window closed.
	if mine.asked then
		if mine.round and not mine.done then mine.settled = true end
		mine.asked = nil
	end
	SetPending()
	win.away, win.walked, win.planned, ready = nil, nil, nil, nil   -- a login is a new session
	if mine.done and not mine.said then Told() end
	if S.Done() then
		C_Timer.After(WAIT, Remind)
		return
	end
	for _, event in ipairs(AGAIN) do offer:RegisterEvent(event) end
	C_Timer.After(WAIT, function()
		ready = true
		Offer()
	end)
end)

Shy.Command("setup", "set this character up", function() S.Start() end)

-- For looking at a first setup again: this character's record is dropped, so it counts as never set up, and the
-- welcome comes up at once. Nothing on the screen is undone. Not listed.
function S.Fresh()
	if win.open then S.Close() end
	Book().chars[P.Character()] = nil
	Stamps()[P.Character()] = nil
	win.away, win.walked, win.planned = nil, nil, nil
	S.Start()
end
Shy.Command("setup fresh", nil, function() S.Fresh() end)
Shy.Command("fresh", nil, function() S.Fresh() end)   -- (the same, as it gets typed)

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
	return on == of and "All recommended on" or ("%d of %d recommended on"):format(on, of)
end)
