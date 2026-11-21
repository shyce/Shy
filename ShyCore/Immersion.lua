-- Shy.Immersion: how quests reach the player and how much of the screen stays in the way. Questing by
-- guide or by zone, quest givers by hand or instant turn-in and the waypoint arrow (ShyQuest's), quest
-- text, the HUD fading when idle with a few pieces keeping watch, and the game's camera and map
-- switches. One builder serves the setup step and the /shy window's Play room.
--
--   Shy.Immersion.QuestText() / SetQuestText(mode)         "instant" | "normal" | "immersive"
--   Shy.Immersion.TextSize() / SetTextSize(size)           quest text's size, 0.8 to 1.5 of the game's (1)
--   Shy.Immersion.QuestFontHeight(name, size)              a quest font of the game's at that size
--   Shy.Immersion.ReadAloud() / SetReadAloud(on)           recorded voices in the immersive dialog; nil
--                                                          without the voice addon (Voice.lua)
--   Shy.Immersion.Greetings() / SetGreetings(on)           NPCs greet you and read a quest's page aloud at every
--                                                          talk, not only the first; nil where the voice addon
--                                                          can't be asked
--   Shy.Immersion.Questing() / SetQuesting(style)          "guide" | "zone"; nil without ShyQuest
--   Shy.Immersion.InstantTurnIn() / SetInstantTurnIn(on)   nil without ShyQuest
--   Shy.Immersion.WaypointArrow() / SetWaypointArrow(on)   nil without ShyQuest; the character's own
--   Shy.Immersion.Fade() / SetFade(on)                     fade the HUD when idle
--   Shy.Immersion.Hold(key, on)        keep the HUD up while on (something on screen wants to be seen)
--   Shy.Immersion.Quiet(key, on, frame, still)  fade the HUD while on, idle or not; never in a fight. frame:
--                                      the piece asking (a dialog): the cursor on it is in the dialog. still:
--                                      nothing comes back under the cursor while it is on
--   Shy.Immersion.Faded()              the HUD is faded or on its way
--   Shy.Immersion.Solid(frame)         a window or tooltip a dialog just showed: solid while quiet
--   Shy.Immersion.Watch(key, frame, how)  frame keeps watch with the piece `key` while the HUD is faded:
--                                      "chat", "group", "minimap", "map", or a key of the addon's own.
--                                      how: nil for content, "housing" for a panel under it, false to
--                                      take it out again
--   Shy.Immersion.News(key, seconds)   the piece has news: it lights up for a while (12 seconds)
--   Shy.Immersion.Depth()              0 while you play, 1 while you are away (eased between)
--   Shy.Immersion.AwayLine()           the away board's line (time away, what came in), or nil
--   Shy.Immersion.board                the board (Away.lua): Set(depth, now, since, came), Drop()
--   Shy.Immersion.Section(parent, width, plan)   the choices: picks into plan.immersion, or live without a plan
--   Shy.Immersion.GAME                 the game's camera and map switches, as Setup.GAME entries
--
-- Bus: SHY_IMMERSION (what, value) when a choice changes: "questText", "textSize", "voice", "greetings", "questing", "turnIn",
--      "arrow", "fade", "game".
--      SHY_IMMERSION_FADE (faded) as the HUD starts to fade, and once it is all the way back.
--      SHY_IMMERSION_QUIET (level) while a dialog keeps the screen quiet: how much of the nameplates to show.
--      SHY_IMMERSION_NEWS (key) when a piece of the watch lights up.
--
-- Quest text: instant and normal are the game's Instant Quest Text setting (kept and given back through
-- Setup.Take / Setup.Return). Immersive leaves that setting off and is stored per profile
-- (ShyCoreDB.immersion.immersive) for the quest dialog (Shy.Talk, Talk.lua) to act on; it hears of a
-- change through SHY_IMMERSION, and without it the game's own window shows the text as normal. A dialog
-- that wants the screen to itself calls Quiet while it is up, and stands on UIParent only with
-- SetIgnoreParentAlpha(true).
--
-- What fades is UIParent's alpha. Nameplates and chat bubbles belong to the world, not to UIParent, and
-- stay. Alpha is not protected, so the HUD can come back in a fight.
--
-- The watch: while the HUD is faded, chat, the group, the minimap and the open map stay readable. Only
-- their content keeps watch: a piece's housing (the panel UI.Panel drew, listed in its frame's
-- shyHousing, what its owner added there, and a frame joined as "housing") fades away with the HUD, so
-- words, bars and the map stand on the world alone. Each piece is lifted off UIParent's alpha
-- (SetIgnoreParentAlpha) and given its own, dimmed while you play. News lights a piece to full for a
-- while: someone talking lights chat, the group changing or a member fighting lights the group, a new
-- area the minimap, and an addon's own news comes through News. The game writes the map's alpha every
-- frame (its own fade while moving), so the map is lifted and never dimmed. The game never writes the
-- alpha of its chat frames, minimap cluster or party frame, so theirs is ours while kept; chat tabs (the
-- game animates them) go with the HUD. Anything of an addon's joins through Watch.
--
-- Away: once nothing has been heard from you for a minute after the fade (the cursor, the character
-- moving, anything that keeps the HUD up), the watch goes down too and the away board comes up
-- (Away.lua): the world darkens, your character stands on a lit floor, chat stands large beside it,
-- and the board says how long you have been away, what came in meanwhile (whispers, group and guild
-- lines, the group changing) and how things stand. The housing never comes back while away.
-- A piece with news while you are away is lit once you are back, for a while. The board falls in half
-- a second, the HUD coming back under it as quickly as ever. A fight, a quiet dialog or the fade
-- switched off hands everything back as it was.
--
-- While a dialog keeps the screen quiet, it comes back by where the cursor rests, not all at once: one of
-- Shy's own boxes (Shy.HUD) under the cursor comes back alone; anything else of the game's (action bars,
-- chat, minimap) comes back together, as UIParent, Shy's boxes staying quiet unless the cursor is on them;
-- resting on the world brings back the nameplates (ShyPlates' own plates follow SHY_IMMERSION_QUIET).
-- Something comes back once the cursor has rested on it a moment, and stays while the cursor is on it,
-- while it moves about outside the dialog and for a while after, and a moment after it is back on the
-- dialog: time to drag a window or move a bag. A still quiet (the quest dialog's) brings nothing back that
-- way. Windows (the game's panels, bags, anything Esc closes, Shy's windows) and tooltips (the game's and
-- Shy's hovers) stay solid meanwhile: they are set to ignore UIParent's alpha while quiet, nothing else,
-- and put back after. A fight ends it all at once.

local Shy = Shy
local UI, S = Shy.UI, Shy.Setup
local core = Shy.core
local C = UI.colors
local max, min, abs = math.max, math.min, math.abs

local I = {}
Shy.Immersion = I

local function Db()
	local db = core.db
	db.immersion = db.immersion or {}
	return db.immersion
end

-- ShyQuest, once loaded and new enough to answer.
local function Quest()
	local quest = Shy.addons.Quest
	if quest and quest.db and quest.SetQuestStyle and quest.SetInstantTurnIn and quest.HasGuide then return quest end
end

local function Tell(what, value)
	Shy:Fire("SHY_IMMERSION", what, value)
end

-- Quest text

local INSTANT = { key = "questText", want = { instantQuestText = "1" } }

function I.QuestText()
	if Db().immersive then return "immersive" end
	return S.Is(INSTANT) and "instant" or "normal"
end

-- The game's setting for it; false when the game kept it as it was.
local function WriteText(mode)
	local want = mode == "instant"
	if S.Is(INSTANT) == want then return true end
	if not S.Can(INSTANT) then return false end
	if want then S.Take(INSTANT) else S.Return(INSTANT) end
	return S.Is(INSTANT) == want
end

local TEXT = { instant = true, normal = true, immersive = true }

function I.SetQuestText(mode)
	if not TEXT[mode] then return false end
	local was = I.QuestText()
	local ok = WriteText(mode)
	Db().immersive = mode == "immersive"
	if I.QuestText() ~= was then Tell("questText", I.QuestText()) end
	return ok
end

-- Quest text size: the game's quest fonts (quest, gossip and book pages) and the immersive stage's words.
-- A font object of the game's is given a height, never a file, so every alphabet keeps its own; one never
-- changed is never written.

I.SIZE_MIN, I.SIZE_MAX, I.SIZE_STEP = 0.8, 1.5, 0.05
local QUEST_FONTS = { "QuestFont", "QuestFontLeft", "QuestTitleFont", "QuestTitleFontBlackShadow", "QuestFontNormalSmall" }
local fontHeight = {}   -- font object's name -> the height the game gave it, once this has changed it

function I.TextSize()
	return Db().textSize or 1
end

-- The height a quest font has at a size: the game's own, scaled, on a whole unit.
function I.QuestFontHeight(name, size)
	local font = _G[name]
	if not font then return nil end
	return math.floor((fontHeight[name] or font:GetFontHeight()) * (size or I.TextSize()) + 0.5)
end

local function SizeFonts()
	local size = I.TextSize()
	for _, name in ipairs(QUEST_FONTS) do
		local font = _G[name]
		if font and (fontHeight[name] or size ~= 1) then
			local height = I.QuestFontHeight(name, size)
			fontHeight[name] = fontHeight[name] or font:GetFontHeight()
			font:SetFontHeight(height)
		end
	end
end

function I.SetTextSize(size)
	size = math.floor(math.floor(size / I.SIZE_STEP + 0.5) * I.SIZE_STEP * 100 + 0.5) / 100
	size = max(I.SIZE_MIN, min(I.SIZE_MAX, size))
	if abs(size - I.TextSize()) < 0.001 then return end
	Db().textSize = abs(size - 1) >= 0.001 and size or nil
	SizeFonts()
	Tell("textSize", I.TextSize())
end

Shy:On("SHY_LOGIN", SizeFonts)

-- Voices: the people in the immersive dialog speaking in recorded voices (Shy.Voice). The voice addon's own
-- switches, so there is one setting, wherever it is changed; nil without it.

function I.ReadAloud()
	return Shy.Voice.On()
end

function I.SetReadAloud(on)
	on = on and true or false
	if I.ReadAloud() == nil or I.ReadAloud() == on then return end
	Shy.Voice.SetOn(on)
	Tell("voice", on)
end

-- Greetings: an NPC's opening words read at every talk, not only the first (the voice addon's own setting); a
-- quest's page goes by it too (Voice.lua).
function I.Greetings()
	return Shy.Voice.Greetings()
end

function I.SetGreetings(on)
	on = on and true or false
	if I.Greetings() == nil or I.Greetings() == on then return end
	Shy.Voice.SetGreetings(on)
	Tell("greetings", on)
end

-- ShyQuest's settings

function I.Questing()
	local quest = Quest()
	return quest and quest:QuestStyle() or nil
end

function I.SetQuesting(style)
	local quest = Quest()
	if not quest or (style ~= "guide" and style ~= "zone") or quest:QuestStyle() == style then return end
	quest:SetQuestStyle(style)
	Tell("questing", style)
end

function I.InstantTurnIn()
	local quest = Quest()
	if not quest then return nil end
	return quest:InstantTurnIn()
end

function I.SetInstantTurnIn(on)
	local quest = Quest()
	on = on and true or false
	if not quest or quest:InstantTurnIn() == on then return end
	quest:SetInstantTurnIn(on)
	Tell("turnIn", on)
end

-- ShyQuest with a waypoint arrow to ask about.
local function Arrow()
	local quest = Quest()
	if quest and quest.WaypointArrow and quest.SetWaypointArrow then return quest end
end

function I.WaypointArrow()
	local quest = Arrow()
	if not quest then return nil end
	return quest:WaypointArrow()
end

function I.SetWaypointArrow(on)
	local quest = Arrow()
	on = on and true or false
	if not quest or quest:WaypointArrow() == on then return end
	quest:SetWaypointArrow(on)
	Tell("arrow", on)
end

-- The game's own switches (Options > Controls, and the map's fade while moving)

I.GAME = {
	{ key = "slopes", title = "Camera follows slopes", say = "Tilts as you climb and descend",
		desc = "The camera tilts up as you climb a slope and down as you descend. (Options > Controls > Follow Terrain)",
		want = { cameraTerrainTilt = "1" } },
	{ key = "mapFade", title = "Map fades as you move", say = "See the world through the map",
		desc = "The open map turns half see-through while you move. It's solid again when you stop or hover it.",
		want = { mapFade = "1" } },
}

-- The ones this client has and lets an addon set.
local function Switches()
	local out = {}
	for _, def in ipairs(I.GAME) do
		if S.Can(def) or S.Is(def) then out[#out + 1] = def end
	end
	return out
end

local function SetSwitch(def, on)
	if on then S.Take(def) else S.Return(def) end
	Tell("game", def.key)
	return S.Is(def) == on
end

-- The HUD fading when idle
--
-- Anything happening keeps the HUD up: a fight, a target, a cast, typing, a window or pop-up, the cursor
-- carrying something or resting on the interface (not the world, nor a nameplate in it), layout mode,
-- being dead. Health and power coming back after a fight fire UNIT_HEALTH / UNIT_POWER_UPDATE (the
-- numbers themselves are secret), and stop once they are full. Using things counts too: an instant
-- spell or an item, looting, a quest taken or handed in, the game refusing something, a modifier key.
-- The cursor moving brings it back; it doesn't move while the camera turns, and the character moving
-- doesn't bring it back either: that is the point of the fade. It does count as you being there.

local IDLE = 30       -- seconds of nothing before it fades
local OUT = 1.5       -- seconds to fade away
local BACK = 0.15     -- seconds to come back
local CHECK = 0.1     -- seconds between looks at the screen
local MOVE = 4        -- cursor travel that counts as moving it, in screen pixels
local PANELS = { "left", "center", "right", "doublewide", "fullscreen" }
local WINDOWS = { "SettingsPanel" }   -- the map keeps watch instead

-- The watch
local REST = 0.45     -- how much of a piece shows while you play
local NEWS = 12       -- seconds a piece stays lit for news
local LIT_IN = 0.3    -- seconds a piece takes to light up
local LIT_OUT = 2.5   -- and to settle again
local AWAY = 60       -- seconds of nothing after the fade before you are away
local AWAY_IN = 3.5   -- seconds the board takes to come up
local AWAY_OUT = 0.5  -- and to fall once you are back

local driver = CreateFrame("Frame")
driver:Hide()
local listen = CreateFrame("Frame")
local news = CreateFrame("Frame")
local alpha, faded = 1, false
local last, since, cx, cy = 0, 0, nil, nil   -- last: when something last wanted the HUD up
local active = 0                              -- when you were last heard from: last, or the character moving
local casting, broken = false, false
local calm = { on = false, held = 0, EVERY = 0.1 }   -- nothing to do but wait for stillness (Update): looked at EVERY seconds
local holds, quiets, stills = {}, {}, {}

local function Set(a)
	if a == alpha then return end
	alpha = a
	UIParent:SetAlpha(a)
	local now = a < 1
	if now ~= faded then
		faded = now
		Shy:Fire("SHY_IMMERSION_FADE", faded)
	end
end

local function Enabled()
	return not broken and Db().fade == true
end

local function Active()
	return not broken and (Db().fade == true or next(quiets) ~= nil)
end

local function Shown(frame)
	if type(frame) ~= "table" or not frame.IsShown then return false end
	local shown = frame:IsShown()
	return not issecretvalue(shown) and shown == true
end

-- On screen: shown, and so is everything it stands on.
local function Visible(frame)
	if type(frame) ~= "table" or not frame.IsVisible then return false end
	local visible = frame:IsVisible()
	return not issecretvalue(visible) and visible == true
end

-- The game's windows, and ours (Shy.HUD.AnyWindow says when one of ours is open).
local function Windows()
	for _, key in ipairs(PANELS) do
		if GetUIPanel(key) then return true end
	end
	for _, name in ipairs(UISpecialFrames) do
		if Visible(_G[name]) then return true end
	end
	for _, name in ipairs(WINDOWS) do
		if Visible(_G[name]) then return true end
	end
	return Shy.HUD.AnyWindow() or StaticPopup_IsAnyDialogShown() or IsAnyBagOpen()
end

-- The cursor resting on a piece of the interface: you are reading it. The world and what stands in it
-- (a nameplate is forbidden: nothing can be asked of it) is not.
local function OnInterface()
	local foci = GetMouseFoci()
	local frame = foci and foci[1]
	if not frame then return false end
	while frame do
		if frame == WorldFrame or (frame.IsForbidden and frame:IsForbidden()) then return false end
		frame = frame:GetParent()
	end
	return true
end

local function Resting()
	local ok, on = pcall(OnInterface)
	return ok and on
end

local function Busy()
	return InCombatLockdown() or UnitAffectingCombat("player") or UnitExists("target") or casting
		or next(holds) ~= nil or GetCurrentKeyBoardFocus() ~= nil or GetCursorInfo() ~= nil or SpellIsTargeting()
		or UnitIsDeadOrGhost("player") or Shy.HUD.IsUnlocked() or S.IsOpen() or Windows() or Resting()
end

-- The quiet screen, piece by piece (see the header)

local SOFT_IN = 0.3   -- seconds a piece takes to come back while a dialog is up
local SOFT_OUT = 0.9  -- and to go quiet again
local DWELL = 0.3     -- seconds the cursor rests on a piece before it comes back
local GRACE = 6       -- seconds a piece stays after the cursor last moved outside the dialog
local HANDBACK = 1.5  -- seconds a piece stays once the cursor is back on the dialog
local TIPS = { "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefTooltip", "ItemRefShoppingTooltip1",
	"ItemRefShoppingTooltip2" }
local BAGS = { "ContainerFrameCombinedBags", "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
	"ContainerFrame5", "ContainerFrame6", "ContainerFrame7" }

local areas = {}      -- a Shy box -> { was = ignored its parent's alpha, base = its own alpha, level = 0 to 1 }
local hooked = {}     -- frames whose own SetAlpha is followed
local lifted = {}     -- a window or tooltip -> whether it ignored its parent's alpha before
local seen, shown = {}, {}   -- a piece ("screen", "world" or a box) -> since when the cursor rests on it; shown
local plates = 1      -- how much of the nameplates shows (SHY_IMMERSION_QUIET)
local moved, back = 0, nil   -- when the cursor last moved outside the dialog; when it came back onto it
local writing = false
local Shade                  -- the watch's housing shader, below

-- The watch's pieces: the frames keeping watch with each, how much of it shows now, and whether it is lit.
-- A lift piece is lifted off UIParent's alpha and never dimmed (the game writes the map's own).
local function Piece(lift)
	return { frames = {}, level = 1, lift = lift }
end
local pieces = { chat = Piece(), group = Piece(), minimap = Piece(), map = Piece(true) }
local BUILT_IN = {
	chat = function(fn) ChatFrameUtil.ForEachChatFrame(fn) end,
	group = function(fn) fn(rawget(_G, "PartyFrame")) end,
	minimap = function(fn) fn(rawget(_G, "MinimapCluster")) end,
	map = function(fn) fn(rawget(_G, "WorldMapFrame")) end,
}
local kept = {}       -- a frame keeping watch -> { key, frame, base = its own alpha, was = ignored its parent's alpha,
                      --   housing = a panel rather than content, house = its housing regions, own = their own alphas }
local shade = 1               -- how much of the housing shows: 1 with the HUD, else 0
local away, awayAt = 0, nil   -- how far the away board is up; when you went away
local tally = {}              -- what came in while away: word -> count
-- The board itself is Away.lua's (I.board), told how far up it is at every frame.

-- What came in while away, as words: "2 whispers", "5 group lines" ...
local TALLY = {
	CHAT_MSG_WHISPER = "whisper", CHAT_MSG_BN_WHISPER = "whisper",
	CHAT_MSG_PARTY = "group", CHAT_MSG_PARTY_LEADER = "group", CHAT_MSG_RAID = "group", CHAT_MSG_RAID_LEADER = "group",
	CHAT_MSG_RAID_WARNING = "group", CHAT_MSG_INSTANCE_CHAT = "group", CHAT_MSG_INSTANCE_CHAT_LEADER = "group",
	CHAT_MSG_GUILD = "guild", CHAT_MSG_OFFICER = "guild",
	GROUP_ROSTER_UPDATE = "change",
}
local WORDS = {
	{ "whisper", "%d whisper", "%d whispers" }, { "group", "%d group line", "%d group lines" },
	{ "guild", "%d guild line", "%d guild lines" }, { "change", "the group changed", "the group changed" },
}

local function Since(seconds)
	local minutes = math.floor(seconds / 60)
	if minutes < 60 then return minutes .. " min" end
	return math.floor(minutes / 60) .. " h " .. (minutes % 60) .. " min"
end

-- What came in, as words, in the order of WORDS.
local function Came()
	local out = {}
	for _, def in ipairs(WORDS) do
		local n = tally[def[1]]
		if n then out[#out + 1] = { word = def[1], text = (n == 1 and def[2] or def[3]):format(n) } end
	end
	return out
end

local function AwayWords(now)
	local out = { Since(now - active) }
	for _, entry in ipairs(Came()) do out[#out + 1] = entry.text end
	return table.concat(out, ", ")
end

local function Quieting()
	return not broken and next(quiets) ~= nil and not InCombatLockdown() and not Shy.HUD.IsUnlocked()
end

local function Over(frame)
	if type(frame) ~= "table" or not frame.IsMouseOver or not Shown(frame) then return false end
	local over = frame:IsMouseOver()
	return not issecretvalue(over) and over == true
end

local function Paint(box, area)
	writing = true
	box:SetAlpha(area.base * area.level)
	writing = false
end

-- A kept frame's alpha: its own, times how much of its piece shows.
local function Dim(frame, entry)
	writing = true
	frame:SetAlpha(entry.base * pieces[entry.key].level)
	writing = false
end

-- An owner setting its frame's alpha while it is quiet or keeping watch: kept as the frame's own, and
-- the quiet or the watch laid over it.
local function Followed(frame, a)
	if writing or issecretvalue(a) then return end
	local area, entry = areas[frame], kept[frame]
	if area then
		area.base = a
		Paint(frame, area)
	elseif entry then
		entry.base = a
		if entry.housing then Shade(entry) elseif not pieces[entry.key].lift then Dim(frame, entry) end
	end
end

local function Follow(frame)
	if hooked[frame] then return end
	hooked[frame] = true
	hooksecurefunc(frame, "SetAlpha", Shy.Clocked("immersion: a frame's alpha set", Followed))
end

local function Owner(box)
	for _, frame in pairs(quiets) do
		if frame == box then return true end
	end
	return false
end

-- Shy's own boxes, each its own piece; windows are lifted instead.
local function Gather()
	Shy.HUD.Each(function(box)
		if areas[box] or box.foreign or box.window or not Shown(box) or Owner(box) then return end
		local base = box:GetAlpha()
		if issecretvalue(base) then return end
		areas[box] = { was = box:IsIgnoringParentAlpha() == true, base = base, level = alpha }
		Follow(box)
		box:SetIgnoreParentAlpha(true)
		Paint(box, areas[box])
	end)
end

local function Let(box)
	local area = areas[box]
	areas[box] = nil
	writing = true
	box:SetAlpha(area.base)
	box:SetIgnoreParentAlpha(area.was)
	writing = false
end

-- Windows and the game's tooltips stay solid; never a protected frame.
local function Lift(frame)
	if lifted[frame] ~= nil or not Shown(frame) or frame:IsProtected() then return end
	lifted[frame] = frame:IsIgnoringParentAlpha() == true
	frame:SetIgnoreParentAlpha(true)
end

-- The game's tooltips and Shy's hovers (ShyTip shows the game's in a hover and hides the tooltip itself).
local function Tips()
	for _, name in ipairs(TIPS) do Lift(_G[name]) end
	if Shy.Hover and Shy.Hover.Each then Shy.Hover.Each(Lift) end
end

local function Lifts()
	Tips()
	for _, key in ipairs(PANELS) do
		local frame = GetUIPanel(key)
		if frame then Lift(frame) end
	end
	for _, name in ipairs(BAGS) do Lift(_G[name]) end
	for _, name in ipairs(UISpecialFrames) do Lift(_G[name]) end
	-- The game's questions (dropping an item, abandoning a quest) are answered over the dialog, so they stay seen.
	StaticPopup_ForEachShownDialog(Lift)
	Shy.HUD.Each(function(box)
		if box.window and not box.foreign then Lift(box) end
	end)
	for frame, was in pairs(lifted) do
		if not Shown(frame) then
			lifted[frame] = nil
			frame:SetIgnoreParentAlpha(was)
		end
	end
end

local function Unlift()
	for frame, was in pairs(lifted) do frame:SetIgnoreParentAlpha(was) end
	wipe(lifted)
end

local function Plates(level)
	if level == plates then return end
	plates = level
	Shy:Fire("SHY_IMMERSION_QUIET", level)
end

-- The watch

-- A frame the game hides for a roleset (ShyFrames stands the party frame down that way) isn't on screen.
local function Filtered(frame)
	return type(frame.IsRolesetFiltered) == "function" and frame:IsRolesetFiltered() == true
end

-- A piece's housing: every region in a frame's shyHousing, the frame's own and its children's, each
-- with its own alpha to go back to.
-- Gathered again at every look, since a piece can be repainted or drawn more while kept: a region's own
-- alpha (entry.own) is what it had when first seen.
-- Nothing is made while it walks (it runs ten times a second while the HUD is faded): the kit's regions are
-- gathered into one kept list, the children walked as the game hands them over.
local skinned = {}
local function Take(entry, list)
	for _, region in ipairs(list) do
		if entry.own[region] == nil then
			local a = region:GetAlpha()
			entry.own[region] = not issecretvalue(a) and a or false
		end
		if entry.own[region] then entry.house[#entry.house + 1] = region end
	end
end
local Housing
local function Children(entry, depth, ...)
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		if type(child) == "table" then Housing(child, entry, depth) end
	end
end
function Housing(frame, entry, depth)
	if type(frame.shyHousing) == "table" then Take(entry, frame.shyHousing) end
	wipe(skinned)
	Take(entry, Shy.Skin.Housing(frame, skinned))
	if depth < 4 then Children(entry, depth + 1, frame:GetChildren()) end
end

-- The housing of a kept frame, and a frame that is housing itself, at how much of the housing shows.
function Shade(entry)
	for _, region in ipairs(entry.house) do region:SetAlpha(entry.own[region] * shade) end
	if entry.housing then
		writing = true
		entry.frame:SetAlpha(entry.base * shade)
		writing = false
	end
end

-- A kept frame as the watch wants it now: its content at its piece's level, its housing at the shade.
local function Apply(entry)
	if entry.housing then
		Shade(entry)
	else
		if not pieces[entry.key].lift then Dim(entry.frame, entry) end
		Shade(entry)
	end
end

local function Keep(key, frame, housing)
	if type(frame) ~= "table" or kept[frame] or areas[frame] or not Shown(frame) or Filtered(frame) then return end
	local base = frame:GetAlpha()
	if issecretvalue(base) then return end
	local entry = { key = key, frame = frame, base = base, was = frame:IsIgnoringParentAlpha() == true, housing = housing,
		house = {}, own = {} }
	if not housing then Housing(frame, entry, 0) end
	kept[frame] = entry
	-- Its own alpha written meanwhile (by its owner, or the game) is folded in as the new base.
	Follow(frame)
	frame:SetIgnoreParentAlpha(true)
	Apply(entry)
end

local function Hand(frame)
	local entry = kept[frame]
	kept[frame] = nil
	writing = true
	if not pieces[entry.key].lift then frame:SetAlpha(entry.base) end
	frame:SetIgnoreParentAlpha(entry.was)
	writing = false
	for region, own in pairs(entry.own) do
		if own then region:SetAlpha(own) end
	end
end

-- Everything keeping watch handed back as it was; the pieces rest.
local function Stand()
	for frame in pairs(kept) do Hand(frame) end
	for _, piece in pairs(pieces) do piece.level, piece.lit = 1, nil end
	shade, away, awayAt = 1, 0, nil
	wipe(tally)
	if I.board then I.board.Drop() end
end

-- Every piece's frames that are on screen keep watch; one hidden meanwhile is handed back.
local keepers = {}
local function Muster()
	for key, piece in pairs(pieces) do
		local builtIn = BUILT_IN[key]
		if builtIn then
			-- One keeper a piece, made once.
			local keep = keepers[key]
			if not keep then
				keep = function(frame) Keep(key, frame) end
				keepers[key] = keep
			end
			builtIn(keep)
		end
		for frame, how in pairs(piece.frames) do Keep(key, frame, how == "housing") end
	end
	for frame, entry in pairs(kept) do
		if not Shown(frame) then
			Hand(frame)
		else
			-- Repainted or drawn more meanwhile: its housing is gathered again, and all of it set as the
			-- watch wants it now, whatever was written to it since.
			if not entry.housing then
				wipe(entry.house)
				Housing(frame, entry, 0)
			end
			Apply(entry)
		end
	end
end

-- Where a piece is wanted: full while lit, else at rest, and down with the HUD as far as the away board
-- is up (the board has the chat). A piece lit while you were away (lit = true) is lit once you are
-- heard from, for a while.
local function Level(piece, now)
	local lit = false
	if piece.lit == true then
		if awayAt then lit = true else piece.lit = now + NEWS end
	end
	if piece.lit and piece.lit ~= true then
		if now < piece.lit then lit = true else piece.lit = nil end
	end
	return (lit and 1 or REST) * (1 - away)
end

-- The board, by how far away you are.
local function Board(now)
	if I.board then I.board.Set(away, now, Since(now - active), Came()) end
end

-- Each frame while the watch is up. The HUD wanted back brings every piece to full as quickly, and once
-- the HUD is all the way back everything is handed back.
local function Keeping(dt, now, want)
	local to = (awayAt and want < 1) and 1 or 0
	local was = away
	if to > away then away = min(1, away + dt / AWAY_IN) elseif to < away then away = max(0, away - dt / AWAY_OUT) end
	if away ~= was or away > 0 then Board(now) end
	for key, piece in pairs(pieces) do
		local wanted = want == 1 and 1 or Level(piece, now)
		local level = piece.level
		if wanted > level then
			level = min(wanted, level + dt / (want == 1 and BACK or LIT_IN))
		elseif wanted < level then
			level = max(wanted, level - dt / LIT_OUT)
		end
		if level ~= piece.level then
			piece.level = level
			if not piece.lift then
				for frame, entry in pairs(kept) do
					if entry.key == key and not entry.housing then Dim(frame, entry) end
				end
			end
		end
	end
	-- The housing goes with the HUD, at the HUD's pace, and comes back with it alone.
	local house = want
	local shaded = shade
	if house > shade then shade = min(house, shade + dt / BACK) elseif house < shade then shade = max(house, shade - dt / OUT) end
	if shade ~= shaded then
		for _, entry in pairs(kept) do Shade(entry) end
	end
	-- Handed back once the HUD is all the way back and the board has fallen.
	if want == 1 and alpha == 1 and away == 0 then Stand() end
end

-- Everything back at once: a fight, an error, the dialog gone in layout mode.
local function Release()
	for box in pairs(areas) do Let(box) end
	Unlift()
	Stand()
	wipe(seen)
	wipe(shown)
	Plates(1)
end

local function InDialog()
	for _, frame in pairs(quiets) do
		if Over(frame) then return true end
	end
	return false
end

-- What the cursor is on: "world", "screen" (the game's own pieces), a Shy box, or nothing to bring back.
local function Under()
	local foci = GetMouseFoci()
	local focus = foci and foci[1]
	local frame = focus
	while frame do
		if frame == WorldFrame then return "world" end
		if frame.IsForbidden and frame:IsForbidden() then return "screen" end
		if areas[frame] then return frame end
		if lifted[frame] ~= nil then return nil end
		frame = frame:GetParent()
	end
	return focus and "screen" or "world"
end

-- Looks at the cursor: which pieces are wanted now, and which stay.
local function Look(now)
	local inside = InDialog()
	local want = {}
	if inside then
		back = back or now
	else
		back = nil
		-- A forbidden frame can't be asked anything: on this client that is a nameplate in the world.
		local ok, piece = pcall(Under)
		if not ok then piece = "world" end
		if piece then want[piece] = true end
		for box in pairs(areas) do
			if Over(box) then want[box] = true end
		end
	end
	local dragging = IsMouseButtonDown("LeftButton") or GetCursorInfo() ~= nil
	local stay = dragging or (inside and now - back < HANDBACK) or (not inside and now - moved < GRACE)
	for piece in pairs(want) do
		seen[piece] = seen[piece] or now
		if now - seen[piece] >= DWELL then shown[piece] = true end
	end
	for piece in pairs(seen) do
		if not want[piece] then seen[piece] = nil end
	end
	for piece in pairs(shown) do
		if not want[piece] and not stay then shown[piece] = nil end
	end
end

-- Softly while the dialog is up; the dialog gone, everything is back as quickly as the screen.
local function Ease(level, to, dt, quiet)
	if to > level then return min(to, level + dt / (quiet and SOFT_IN or BACK)) end
	if to < level then return max(to, level - dt / SOFT_OUT) end
	return level
end

-- Each frame while quiet, or while coming back from it.
local function Pieces(dt, quiet)
	for box, area in pairs(areas) do
		local to = (quiet and not shown[box]) and 0 or 1
		local level = Ease(area.level, to, dt, quiet)
		if level ~= area.level then
			area.level = level
			Paint(box, area)
		end
		if not quiet and level == 1 and alpha == 1 then Let(box) end
	end
	Plates(Ease(plates, (quiet and not shown.world) and 0 or 1, dt, quiet))
	if not quiet and alpha == 1 then Unlift() end
end

local function Want()
	if InCombatLockdown() then return 1 end
	if next(quiets) and not Shy.HUD.IsUnlocked() then return shown.screen and 1 or 0 end
	if not Enabled() then return 1 end
	return GetTime() - last >= IDLE and 0 or 1
end

local function Update(self, dt)
	local now = GetTime()
	local x, y = GetCursorPosition()
	if cx and abs(x - cx) + abs(y - cy) > MOVE then
		last, active = now, now
		if not InDialog() then moved = now end
	end
	cx, cy = x, y
	local quiet = Quieting()
	since = since + dt
	if since >= CHECK then
		since = 0
		if Busy() then last, active = now, now end
		if IsPlayerMoving() then active = now end
		if quiet then
			Gather()
			Lifts()
			if next(stills) then
				wipe(seen)
				wipe(shown)
			else
				Look(now)
			end
		elseif not next(quiets) and Enabled() and now - last >= IDLE then
			Muster()
			-- Away: nothing heard from you for a minute after the fade.
			if now - active - IDLE >= AWAY then awayAt = awayAt or now else awayAt = nil end
		end
	end
	if not quiet and next(quiets) and InCombatLockdown() then Release() end
	local want = Want()
	local soft = next(quiets) ~= nil and not InCombatLockdown()
	if want > alpha then
		Set(min(want, alpha + dt / (soft and SOFT_IN or BACK)))
	elseif want < alpha then
		Set(max(want, alpha - dt / (soft and SOFT_OUT or OUT)))
	end
	Pieces(dt, quiet)
	if next(kept) then
		-- A dialog taking the screen has it whole: the watch stands down.
		if quiet or next(quiets) then Stand() else Keeping(dt, now, want) end
	end
	if alpha == 1 and not Active() and not next(areas) and not next(kept) and plates == 1 then self:Hide() end
	-- Calm: the HUD whole and wanted so, nothing quiet, lifted or keeping watch. All there is to do is wait for
	-- you to go still, and that is looked at CALM seconds apart, not at every frame.
	calm.on = alpha == 1 and want == 1 and not quiet and not next(quiets) and not next(areas) and not next(kept) and plates == 1
end

-- An error must never leave the screen faded: the HUD comes back and stays for the session.
calm.Frame = Shy.Clocked("immersion: frame", function(self, dt)
	local ok, err = pcall(Update, self, dt)
	if ok then return end
	broken = true
	Set(1)
	pcall(Release)
	self:Hide()
	geterrorhandler()(err)
end)
driver:SetScript("OnUpdate", function(self, dt)
	if calm.on then
		calm.held = calm.held + dt
		if calm.held < calm.EVERY then return end
		dt, calm.held = calm.held, 0
	end
	calm.Frame(self, dt)
end)

local function Poke()
	last = GetTime()
	active = last
end

local EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_ENTER_COMBAT", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD",
	"CINEMATIC_STOP", "PLAYER_DEAD", "LOOT_OPENED", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "UI_ERROR_MESSAGE",
	"MODIFIER_STATE_CHANGED", "BAG_UPDATE_DELAYED" }
local PLAYER = { "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
	"UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED" }
local CASTS = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }
local ENDS = { UNIT_SPELLCAST_STOP = true, UNIT_SPELLCAST_CHANNEL_STOP = true, UNIT_SPELLCAST_INTERRUPTED = true,
	UNIT_SPELLCAST_FAILED = true }

listen:SetScript("OnEvent", function(_, event)
	Poke()
	if CASTS[event] then casting = true elseif ENDS[event] then casting = false end
	-- A fight brings everything back at once.
	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_ENTER_COMBAT" then
		Set(1)
		Release()
	end
end)

-- What is news for a piece: people talking (channels and the game's own lines aren't), the group
-- changing or a member's health moving, a new area. A whisper is lit longer.
local NEWS_OF = {
	CHAT_MSG_SAY = "chat", CHAT_MSG_YELL = "chat", CHAT_MSG_EMOTE = "chat", CHAT_MSG_PARTY = "chat",
	CHAT_MSG_PARTY_LEADER = "chat", CHAT_MSG_RAID = "chat", CHAT_MSG_RAID_LEADER = "chat", CHAT_MSG_RAID_WARNING = "chat",
	CHAT_MSG_INSTANCE_CHAT = "chat", CHAT_MSG_INSTANCE_CHAT_LEADER = "chat", CHAT_MSG_GUILD = "chat",
	CHAT_MSG_OFFICER = "chat", CHAT_MSG_WHISPER = "chat", CHAT_MSG_BN_WHISPER = "chat",
	GROUP_ROSTER_UPDATE = "group", READY_CHECK = "group",
	ZONE_CHANGED = "minimap", ZONE_CHANGED_INDOORS = "minimap", ZONE_CHANGED_NEW_AREA = "minimap",
}
local LONGER = { CHAT_MSG_WHISPER = 20, CHAT_MSG_BN_WHISPER = 20 }

news:SetScript("OnEvent", function(_, event, unit)
	if event == "UNIT_HEALTH" then
		if type(unit) == "string" and not issecretvalue(unit) and unit:sub(1, 5) == "party" then I.News("group") end
		return
	end
	local word = TALLY[event]
	if word and awayAt then tally[word] = (tally[word] or 0) + 1 end
	I.News(NEWS_OF[event], LONGER[event])
end)

-- Starts or stops the driver and its events after any change.
local function Wake()
	calm.on = false   -- (looked at on the next frame, whatever it waited for)
	if Active() then
		if not listen.on then
			listen.on = true
			for _, event in ipairs(EVENTS) do listen:RegisterEvent(event) end
			for _, event in ipairs(PLAYER) do listen:RegisterUnitEvent(event, "player") end
			for event in pairs(NEWS_OF) do news:RegisterEvent(event) end
			news:RegisterEvent("UNIT_HEALTH")
		end
		Poke()
		driver:Show()
	else
		if listen.on then
			listen.on = nil
			listen:UnregisterAllEvents()
			news:UnregisterAllEvents()
			casting = false
		end
		-- Switched off mid-fade: it comes back as quickly as for a fight, then the driver stops itself.
		driver:SetShown(alpha < 1 or next(areas) ~= nil or next(lifted) ~= nil or next(kept) ~= nil or plates < 1)
	end
end

function I.Fade()
	return Db().fade == true
end

function I.SetFade(on)
	on = on and true or false
	if Db().fade == on then return end
	Db().fade = on
	Wake()
	Tell("fade", on)
end

function I.Hold(key, on)
	holds[key] = on and true or nil
	Poke()
end

function I.Quiet(key, on, frame, still)
	quiets[key] = on and (frame or true) or nil
	stills[key] = (on and still) and true or nil
	if not next(quiets) then
		wipe(seen)
		wipe(shown)
	end
	Wake()
end

function I.Faded()
	return faded
end

-- A window or tooltip just shown by a dialog: solid at once rather than at the next look, and with a
-- tooltip whatever hover or comparison came up with it.
function I.Solid(frame)
	if not Quieting() then return end
	Lift(frame)
	Tips()
end

-- A question of the game's asked while a dialog quiets the screen: solid as it comes, not at the next look.
hooksecurefunc("StaticPopup_Show", function()
	if Quieting() then StaticPopup_ForEachShownDialog(Lift) end
end)

function I.Watch(key, frame, how)
	if type(key) ~= "string" or type(frame) ~= "table" then return end
	local piece = pieces[key]
	if how == false then
		if not piece then return end
		piece.frames[frame] = nil
		if kept[frame] then Hand(frame) end
		return
	end
	if not piece then
		piece = Piece()
		pieces[key] = piece
	end
	piece.frames[frame] = how == "housing" and "housing" or true
	Follow(frame)
end

function I.News(key, seconds)
	local piece = pieces[key]
	if not piece then return end
	piece.lit = awayAt and true or GetTime() + (seconds or NEWS)
	if next(kept) then Shy:Fire("SHY_IMMERSION_NEWS", key) end
end

function I.Depth()
	return away
end

function I.AwayLine()
	if away > 0 then return AwayWords(GetTime()) end
end

Shy:On("SHY_HUD_LAYOUT", Poke)
Shy:On("SHY_LOGIN", Wake)

-- /shy watch: what keeps watch right now, piece by piece, for when something on screen looks wrong.
-- (For finding faults: what keeps watch while the HUD is faded. Not listed.)
Shy.Command("watch", nil, function()
	local count = 0
	for _ in pairs(kept) do count = count + 1 end
	core:Print(("watch: HUD %.2f, shade %.2f, away %.2f%s, wants %d, %d kept"):format(alpha, shade, away,
		awayAt and " (away)" or "", Want(), count))
	for frame, entry in pairs(kept) do
		local name = frame.GetName and frame:GetName() or frame.id
		core:Print(("  %s %s %s: alpha %.2f of %.2f, %s, level %.2f, %d housing"):format(entry.key,
			entry.housing and "housing" or "content", tostring(name), frame:GetAlpha(), entry.base,
			frame:IsIgnoringParentAlpha() and "lifted" or "not lifted", pieces[entry.key].level, #entry.house))
	end
end)

-- The choices, for the setup window and the /shy window

local QUESTING = {
	{ value = "guide", glyph = "book", name = "Guide", say = "A levelling guide picks your next step." },
	{ value = "zone", glyph = "go", name = "Zone", say = "Quests by zone. You choose where to go." },
}
-- What happens at a quest giver is one choice: quests taken in a click, or read, and then how their
-- text comes. Instant turn-in and a kind of quest text are never picked together.
-- Each `say` fits two lines of a tile a quarter of the setup page wide: a third line runs out of its foot.
local GIVERS = {
	{ value = "turnIn", glyph = "use", name = "Instant turn-in", say = "Accepts and hands in as you talk." },
	{ value = "instant", glyph = "fly", name = "Instant text", say = "Quest text shows all at once." },
	{ value = "normal", glyph = "note", name = "Normal text", say = "Quest text fades in as you read." },
	{ value = "immersive", glyph = "talk", name = "Immersive", say = "Talking heads tell the story." },
}
local TEXTS = {
	{ value = "instant", glyph = "fly", name = "Instant", say = "Quest text shows all at once." },
	{ value = "normal", glyph = "note", name = "Normal", say = "Quest text fades in as you read." },
	{ value = "immersive", glyph = "talk", name = "Immersive", say = "Talking heads tell the story." },
}
local NO_GUIDE = "The guides end at level 60."
local TILE_MIN = 170   -- a tile narrower than this has no room for its words: the row breaks in two
local ARROW = { title = "Waypoint arrow", say = "Points the way to your next step and says how far it is.",
	desc = "At the top of the screen an arrow points the way to your next step and says how far it is." }
local ARROW_WIDEST, ARROW_WIDEST_NARROW = 180, 120   -- the room its picture's plate gives the words, on a wide card and a narrow one
local FADE = { title = "Fade HUD when idle", say = "Chat, group and minimap stay readable",
	desc = "Out of combat your UI fades after 30 seconds idle. Chat, your group, the minimap and the map stay dimly readable and light up when something happens. A minute later an away screen shows your character, big chat and what you missed. Anything you do brings it all back." }

local VOICE = { title = "Voices", say = "People speak their lines aloud.",
	desc = "In the immersive dialog, people speak their lines in recorded voices and the pages turn as they go." }
local GREETING = { title = "Greetings every time", say = "Not only the first time you meet.",
	desc = "People greet you and read their quests aloud every time you talk to them, not only the first time." }

local TILE_H, TEXT_H, GAP, SUB, BREAK, ROW, BAND = 58, 58, 8, 17, 10, 38, 66
local WELL, WELL_PAD = 6, 10   -- the arrow's well: in from its card's edges, and round the arrow in it
local WELL_SHADE = { 0, 0, 0 }

-- The waypoint arrow's card: its picture in a well at the left (the arrow as it stands on screen, quiet
-- while off), its name and what it does beside that, its switch at the right end. A click anywhere on it
-- turns it.
local function ArrowCard(parent, width, quest, Get, Set)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, BAND)
	UI.Skin(b)
	b.lit = b:CreateTexture(nil, "ARTWORK")
	b.lit:SetPoint("TOPLEFT", 1, -1)
	b.lit:SetPoint("BOTTOMLEFT", 1, 1)
	b.lit:SetWidth(2)
	UI.Paint(b.lit, Shy.Theme.Accent)

	local x = WELL + 4
	b.sample = quest.ArrowSample and quest:ArrowSample(b, width >= 700 and ARROW_WIDEST or ARROW_WIDEST_NARROW) or nil
	if b.sample then
		b.well = b:CreateTexture(nil, "BORDER")
		b.well:SetPoint("TOPLEFT", WELL + 2, -WELL)
		b.well:SetPoint("BOTTOMLEFT", WELL + 2, WELL)
		b.well:SetWidth(b.sample:GetWidth() + 2 * WELL_PAD)
		UI.Paint(b.well, WELL_SHADE, 0.32)   -- a shade, so it is a well on the card lit or not
		b.rule = b:CreateTexture(nil, "ARTWORK")
		b.rule:SetPoint("TOPLEFT", b.well, "TOPRIGHT")
		b.rule:SetPoint("BOTTOMLEFT", b.well, "BOTTOMRIGHT")
		b.rule:SetWidth(1)
		UI.Paint(b.rule, C.rowEdge)
		b.sample:SetPoint("LEFT", b.well, "LEFT", WELL_PAD, 0)
		x = WELL + 2 + b.sample:GetWidth() + 2 * WELL_PAD + 14
	end

	-- A tick, as every setting has: the card takes the click, the box only shows it.
	b.switch = UI.Checkbox(b, "", Get, Set)
	b.switch:EnableMouse(false)
	b.switch:SetPoint("RIGHT", -14, 0)
	-- The name stands just over the card's middle and the sentence under it, so one line or two sit centred.
	b.name = UI.Text(b, ARROW.title, 13)
	b.name:SetPoint("BOTTOMLEFT", b, "LEFT", x, 1)
	b.say = UI.Text(b, ARROW.say, 11, false, C.dim)
	b.say:SetPoint("TOPLEFT", b, "LEFT", x, -3)
	b.say:SetWidth(width - x - 52)   -- its words end before the tick
	b.say:SetJustifyV("TOP")
	b.say:SetMaxLines(2)

	function b:Refresh()
		local on = Get()
		self.switch:Refresh()
		self.lit:SetShown(on)
		UI.SetFill(self, on and C.row or C.bg)
		UI.Ink(self.name, on and C.head or C.text)
		if self.sample then self.sample:Set(on) end
	end
	b:SetScript("OnClick", function()
		Set(not Get())
		PlaySound(Get() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	end)
	b:SetScript("OnEnter", function(self) UI.SetBorder(self, C.hot) end)
	b:SetScript("OnLeave", function(self) UI.SetBorder(self, C.border) end)
	return b
end

-- Quest text size: a line of quest text in a well at the size picked, the slider at the right end.
local SIZE = { title = "Quest text size", sample = "Bring me eight wolf pelts, and I will see you rewarded.",
	desc = "The size of quest and gossip text, in the game's windows and the immersive dialog." }
local SIZE_H, SIZE_SLIDER = 52, 190
local sampleFont

-- The game's quest font at the size picked; it must have a font before any text is set in it.
local function SampleFont(size)
	if not sampleFont then sampleFont = CreateFont("ShyQuestTextSample") end
	sampleFont:CopyFontObject(QuestFont)
	sampleFont:SetFontHeight(I.QuestFontHeight("QuestFont", size))
	return sampleFont
end

local function SizeCard(parent, width, Get, Set)
	local b = CreateFrame("Frame", nil, parent)
	b:SetSize(width, SIZE_H)
	UI.Skin(b)
	local wellW = width - SIZE_SLIDER - 2 * WELL - 28
	local well = CreateFrame("Frame", nil, b)
	well:SetPoint("TOPLEFT", WELL, -WELL)
	well:SetPoint("BOTTOMLEFT", WELL, WELL)
	well:SetWidth(wellW)
	well:SetClipsChildren(true)
	local shade = well:CreateTexture(nil, "BORDER")
	shade:SetAllPoints()
	UI.Paint(shade, WELL_SHADE, 0.32)
	b.sample = UI.Words(well, SampleFont(Get()), C.text, { wrap = false })
	b.sample:SetPoint("LEFT", WELL_PAD, 0)
	b.sample:SetWidth(wellW - 2 * WELL_PAD)
	b.sample:SetText(SIZE.sample)

	local percent = function(v) return math.floor(v + 0.5) .. "%" end
	b.slider = UI.Slider(b, SIZE.title, I.SIZE_MIN * 100, I.SIZE_MAX * 100, I.SIZE_STEP * 100,
		function() return Get() * 100 end, function(v) Set(math.floor(v + 0.5) / 100) end,
		{ width = SIZE_SLIDER, format = percent, desc = SIZE.desc })
	b.slider:SetPoint("RIGHT", -14, 0)

	function b:Refresh()
		self.slider:Refresh()
		SampleFont(Get())
		UI.Ink(self.sample, C.text)   -- the game's quest text is ink on parchment: here it stands on graphite
	end
	return b
end

-- Many CVars can't be set in combat; a refusal would be recorded as the game keeping it.
local function CanWrite()
	if not InCombatLockdown() then return true end
	core:Print("game settings can't be changed in combat.")
	return false
end

local function Refused(title)
	core:Print("\"" .. title .. "\" can only be changed in the game's Options window.")
end

function I.Section(parent, width, plan)
	local f = CreateFrame("Frame", nil, parent)
	local quest, arrow = Quest(), Arrow()
	local function Pick() return plan.immersion end
	local function Touch(key) Pick().touched[key] = true end

	local get, set = {}, {}
	if plan then
		get.questing = function() return Pick().questing end
		get.text = function() return Pick().text end
		get.turnIn = function() return Pick().turnIn end
		get.arrow = function() return Pick().arrow end
		get.fade = function() return Pick().fade end
		get.size = function() return Pick().size or I.TextSize() end
		get.voice = function() return Pick().voice end
		get.greetings = function() return Pick().greetings end
		get.game = function(def) return Pick().game[def.key] end
		for _, key in ipairs({ "questing", "text", "turnIn", "arrow", "fade", "size", "voice", "greetings" }) do
			set[key] = function(v)
				Pick()[key] = v
				Touch(key)
			end
		end
		set.game = function(def, v) Pick().game[def.key] = v end
	else
		get.questing, get.text, get.turnIn, get.fade = I.Questing, I.QuestText, I.InstantTurnIn, I.Fade
		get.arrow, set.arrow = I.WaypointArrow, I.SetWaypointArrow
		get.size, set.size = I.TextSize, I.SetTextSize
		get.voice, set.voice = I.ReadAloud, I.SetReadAloud
		get.greetings, set.greetings = I.Greetings, I.SetGreetings
		get.game = function(def) return S.Is(def) end
		set.questing, set.turnIn, set.fade = I.SetQuesting, I.SetInstantTurnIn, I.SetFade
		set.text = function(v)
			if v ~= "immersive" and not CanWrite() then return end
			if not I.SetQuestText(v) then Refused("Instant Quest Text") end
		end
		set.game = function(def, v)
			if not CanWrite() then return end
			if not SetSwitch(def, v) then Refused(def.title) end
		end
	end

	local y = 0
	local function Caption(text)
		local caption = UI.Text(f, text:upper(), 11, true, C.dim)
		caption:SetPoint("TOPLEFT", 0, -y)
		y = y + SUB
		return caption
	end
	-- A choice as tiles: across in one row while each has room for its words, else in two rows.
	local function Tiles(list, height, choose)
		local count = #list
		local per = (width - (count - 1) * GAP) / count >= TILE_MIN and count or math.ceil(count / 2)
		local each = (width - (per - 1) * GAP) / per
		local tiles = {}
		for i, entry in ipairs(list) do
			local tile = S.Tile(f, each, nil, entry.name, function()
				choose(entry.value)
				f:Refresh()
			end, height)
			Shy.Hover.Glyph(tile.glyph, entry.glyph)
			tile.say:SetText(entry.say)
			tile.say:SetMaxLines(2)   -- what a tile this tall has room for under its name
			tile:SetPoint("TOPLEFT", ((i - 1) % per) * (each + GAP), -y - math.floor((i - 1) / per) * (height + GAP))
			tile.value = entry.value
			tiles[i] = tile
		end
		y = y + math.ceil(count / per) * (height + GAP) - GAP
		return tiles
	end

	-- At a quest giver: quests taken in a click, or read, and then how the text comes. One choice over the
	-- two settings, so they can't be set against each other. What instant turn-in still stops for (a
	-- choice of rewards) comes at once.
	local function Meet(value)
		if value == "turnIn" then
			set.turnIn(true)
			if plan or not InCombatLockdown() then set.text("instant") end
		else
			set.turnIn(false)
			set.text(value)
		end
	end
	local function Met(turnIn, text)
		return turnIn and "turnIn" or text
	end

	-- Top down: how you quest, then what happens at a quest giver. Without ShyQuest there is no turn-in
	-- to choose, and the quest text is asked alone.
	local questing, givers, texts
	if quest then
		Caption("Questing")
		questing = Tiles(QUESTING, TILE_H, function(v) set.questing(v) end)
		y = y + BREAK
		Caption("Quest givers")
		givers = Tiles(GIVERS, TILE_H, Meet)
	else
		Caption("Quest text")
		texts = Tiles(TEXTS, TEXT_H, function(v) set.text(v) end)
	end
	-- How large the quest text reads, under how it comes.
	y = y + GAP
	local size = SizeCard(f, width, function() return get.size() end, function(v)
		set.size(v)
		f:Refresh()
	end)
	size:SetPoint("TOPLEFT", 0, -y)
	f.size = size
	-- Voices, under the text they speak; only with the voice addon installed. Greetings every time beside
	-- them, two to a row as the screen's switches are, where that addon's setting can be reached.
	local voice, greeting
	if I.ReadAloud() ~= nil then
		y = y + SIZE_H + 6
		local both = I.Greetings() ~= nil
		local wide = both and (width - GAP) / 2 or width
		voice = S.Row(f, wide, VOICE, function() return get.voice() and true or false end, function(v)
			set.voice(v)
			f:Refresh()
		end)
		voice:SetPoint("TOPLEFT", 0, -y)
		f.voice = voice
		if both then
			greeting = S.Row(f, wide, GREETING, function() return get.greetings() and true or false end, function(v)
				set.greetings(v)
				f:Refresh()
			end)
			greeting:SetPoint("TOPLEFT", wide + GAP, -y)
			f.greeting = greeting
		end
		y = y + ROW + BREAK
	else
		y = y + SIZE_H + BREAK
	end

	Caption("Screen and camera")
	local half = (width - GAP) / 2
	-- The waypoint arrow: one card across. The arrow itself, as ShyQuest draws it on screen, leads in a
	-- well at the left; what it is fills the middle; its switch ends the card. The whole card is the switch.
	local band
	if arrow then
		band = ArrowCard(f, width, arrow, function() return get.arrow() and true or false end, function(v)
			set.arrow(v)
			f:Refresh()
		end)
		band:SetPoint("TOPLEFT", 0, -y)
		f.arrow = band
		y = y + BAND + 6
	end

	local items = {}
	items[#items + 1] = { item = FADE, get = get.fade, set = set.fade }
	for _, def in ipairs(Switches()) do
		items[#items + 1] = { item = def, get = function() return get.game(def) end, set = function(v) set.game(def, v) end }
	end
	local rows = {}
	for i, entry in ipairs(items) do
		local row = S.Row(f, half, entry.item, function() return entry.get() and true or false end, function(v)
			entry.set(v)
			f:Refresh()
		end)
		row:SetPoint("TOPLEFT", ((i - 1) % 2) * (half + GAP), -y - math.floor((i - 1) / 2) * (ROW + 6))
		rows[i] = row
	end
	y = y + math.ceil(#items / 2) * (ROW + 6) - 6
	f:SetSize(width, y)

	-- In the setup window the tile the game has now is marked "in use".
	function f:Refresh()
		if questing then
			local now, has = I.Questing(), quest:HasGuide()
			for _, tile in ipairs(questing) do
				tile:Paint(get.questing() == tile.value, plan ~= nil and now == tile.value)
			end
			questing[1].say:SetText(has and QUESTING[1].say or NO_GUIDE)
		end
		if givers then
			local now, picked = Met(I.InstantTurnIn(), I.QuestText()), Met(get.turnIn(), get.text())
			for _, tile in ipairs(givers) do
				tile:Paint(picked == tile.value, plan ~= nil and now == tile.value)
			end
		else
			local now = I.QuestText()
			for _, tile in ipairs(texts) do
				tile:Paint(get.text() == tile.value, plan ~= nil and now == tile.value)
			end
		end
		size:Refresh()
		if voice then voice:Refresh() end
		if greeting then greeting:Refresh() end
		if band then band:Refresh() end
		for _, row in ipairs(rows) do row:Refresh() end
	end
	return f
end

-- The setup step

local function Plan(plan)
	local quest = Quest()
	-- A character's first setup recommends the fade and the arrow; after that, as it has them.
	local first = not S.Done()
	local p = { text = I.QuestText(), size = I.TextSize(), fade = first or I.Fade(), game = {}, touched = {} }
	-- Voices too, with the voice addon installed.
	if I.ReadAloud() ~= nil then p.voice = first or I.ReadAloud() end
	-- Greetings as the voice addon has them, never recommended: a greeting heard before stays quiet, and a page
	-- with no recording says so on the stage, which is what a silent page was.
	if I.Greetings() ~= nil then p.greetings = I.Greetings() end
	if quest then
		-- Guide unless the player chose zones, or no guide fits this character.
		p.questing = quest:QuestStyle() == "guide" and quest:HasGuide() and "guide" or "zone"
		p.turnIn = quest:InstantTurnIn()
	end
	if Arrow() then p.arrow = first or I.WaypointArrow() end
	for _, def in ipairs(Switches()) do p.game[def.key] = S.Is(def) end
	plan.immersion = p
end

local WORD = { instant = "instant", normal = "normal", immersive = "immersive" }

local function Lines(plan)
	local p = plan.immersion
	local head = {}
	if p.questing then head[1] = p.questing == "guide" and "guide questing" or "zone questing" end
	head[#head + 1] = p.turnIn and "instant turn-in" or (WORD[p.text] .. " quest text")
	if p.size and abs(p.size - 1) >= 0.001 then head[#head + 1] = ("quest text at %d%%"):format(math.floor(p.size * 100 + 0.5)) end
	local text = table.concat(head, ", "):gsub("^%l", string.upper)
	local sub = {}
	if p.voice ~= nil then sub[#sub + 1] = p.voice and "voices on" or "no voices" end
	if p.greetings then sub[#sub + 1] = "greetings every time" end
	if p.arrow then sub[#sub + 1] = "a waypoint arrow on screen" end
	sub[#sub + 1] = p.fade and "the HUD fades when idle" or "the HUD stays up"
	for _, def in ipairs(Switches()) do
		if p.game[def.key] then sub[#sub + 1] = (def.title:gsub("^%u", string.lower)) end
	end
	return { { text = text, sub = table.concat(sub, "; ") } }
end

-- Profile settings: questing, turn-in, the immersive choice, the text's size and the fade.
local function Apply(answers)
	if answers.questing ~= nil then I.SetQuesting(answers.questing) end
	if answers.turnIn ~= nil then I.SetInstantTurnIn(answers.turnIn) end
	if answers.text ~= nil then I.SetQuestText(answers.text) end
	if answers.size ~= nil then I.SetTextSize(answers.size) end
	if answers.fade ~= nil then I.SetFade(answers.fade) end
end

local function Run(plan)
	local p, act = plan.immersion, S.Act(plan)
	-- The game's settings aren't a profile's: they are set now.
	WriteText(p.text)
	for _, def in ipairs(Switches()) do
		local want = p.game[def.key]
		if want ~= nil and want ~= S.Is(def) then SetSwitch(def, want) end
	end
	-- Nor is the waypoint arrow: it is the character's own, whatever profile it plays on.
	if p.arrow ~= nil then I.SetWaypointArrow(p.arrow) end
	-- Nor are the voices and greetings: they are the voice addon's own settings.
	if p.voice ~= nil then I.SetReadAloud(p.voice) end
	if p.greetings ~= nil then I.SetGreetings(p.greetings) end
	-- Joining a profile keeps its settings except what was changed here.
	local answers = {}
	for _, key in ipairs({ "questing", "turnIn", "text", "size", "fade" }) do
		if act ~= "use" or p.touched[key] then answers[key] = p[key] end
	end
	if act == "stay" then Apply(answers) else S.Wait("immersion", answers) end
	return false
end

S.Step({
	id = "immersion", order = 22, title = "Play", glyph = "book",
	ask = "How do you want to quest?",
	lead = "How you pick up and hand in quests, and how much of the UI you see while you play.",
	brief = function(plan)
		local p = plan.immersion
		local text = p.turnIn and "instant turn-in" or (WORD[p.text] .. " text")
		if p.questing then return (p.questing == "guide" and "Guide" or "Zone") .. ", " .. text end
		return (text:gsub("^%l", string.upper))
	end,
	Plan = Plan,
	Build = function(parent, width, plan) return I.Section(parent, width, plan) end,
	Lines = Lines,
	Run = Run,
	Later = Apply,
})

-- The /shy window's Play room: the same choices first, each applied as it is made.

Shy.HubSection("play", function(page, top)
	local section = I.Section(page, page.width)
	Shy.HubPlace(page, section, top)
	return section, function() section:Refresh() end
end, 10)

Shy.HubBrief("play", function()
	local quest = Quest()
	local text = I.InstantTurnIn() and "instant turn-in" or (WORD[I.QuestText()] .. " text")
	if quest then return (I.Questing() == "guide" and "Guide" or "Zone") .. ", " .. text end
	return (text:gsub("^%l", string.upper))
end)
