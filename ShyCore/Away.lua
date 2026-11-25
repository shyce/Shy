-- The away board: what the screen becomes once you have been away a while with the HUD faded
-- (Immersion.lua says when, and keeps the clock and the tally). The world goes down to a dusk; a floor
-- rises at the foot of the screen with the accent as light along its line; your character stands on the
-- line at the right, lit from the line and by a halo behind the chest; chat stands large at the left on
-- the dusk, with no housing, whispers in a section of their own over it; a header at the top left says
-- how long you have been away, what came in and how things stand (the frame rate, the latency, the
-- gear's wear, room in the bags, rest banked); the column at the right tells your story (gold on every
-- character, Waylaid Crates, Merchant's Favor and Honor Points over the game's statistics rolling up like credits); and the
-- footer on the floor carries your name, your level and where you stand, the clock, your gold and friends
-- online. Nothing here takes the mouse: anything you do brings the HUD back.
--
--   Shy.Immersion.board.Set(depth, now, since, came)  how far up the board is (0 to 1, hidden at 0), the
--                                                     time away as words, what came in ({ word, text } ...)
--   Shy.Immersion.board.Drop()                        gone at once (a fight)
--   Shy.Immersion.board.frame / .chat / .whispers     the board, its chat and its whispers, once built
--   Shy.Immersion.board.vitals                        the header's line on how things stand
--   Shy.Immersion.board.story                         the story's column: heads (the figures), entries (the roll), rows
--
-- Chat is the tab you are on: as the board comes up, the selected window's last lines are copied into
-- the board's own message frame, each as the window holds it (ShyChat's rewriting included), and while
-- it is up every line that window takes (AddMessage post-hooked on every window) is copied the frame
-- after, once ShyChat has had its turn. A line is only ever handed on, never read, so one the game
-- keeps secret is safe. Whispers come the same way from the Tells window (Setup's whispers tab, named
-- short to fit the row) when there is one, else from the first window carrying whispers, told apart by
-- the event each line came with. The whispers section stands only while there are whispers, and not
-- when the tab you are on is the Tells tab itself. ShyChat, when loaded, dresses both frames in the
-- chat's face and spacing.
--
-- The rise is one choreography over the depth: the veil first, the floor rising into place, then the
-- light along the line with a gleam running once along it, the figure out of the dark, the words last.
-- Falling, the same in reverse, words first and the veil last.

local Shy = Shy
local UI, Theme, B, I, S = Shy.UI, Shy.Theme, Shy.Brand, Shy.Immersion, Shy.Setup
local C = UI.colors
local MEDIA = Shy.MEDIA
local max, min, sin, pi = math.max, math.min, math.sin, math.pi

local EDGE = 48            -- margin from the screen's edges
local FOOT = 92            -- the floor's height: the footer stands on it
local FLOOR_RISE = 40      -- how far the floor rises into place
local CHAT_W = 0.44        -- the chat column's share of the screen's width
local CHAT_LIFT = 22       -- the column's foot above the line
local HEAD_H = 92          -- the header's room over the column
local TEXT = 18            -- the lines' size
local LINES = 150          -- chat lines the board keeps
local WHISPER_SHARE = 0.38 -- the most of the column the whispers section takes
local WHISPER_HEAD = 30    -- its title's room
local LINE_H = 25          -- about a line of the text, with its spacing: the section grows by its lines
local WHISPER_GAP = 18     -- between the section and the chat under it
local FIGURE_X = 0.71      -- where the character stands, as a share of the width
local FIGURE_H = 0.60      -- its height, of the screen's
local FIGURE_RISE = 14     -- how far it rises into place
local HALO = 1.1           -- the halo's size, of the figure's height
local HALO_AT = 0.62       -- how high up the figure it is centred
local DISTANCE = 1.1       -- camera distance: air round the figure
local TURN = 0.35          -- radians the character turns toward the words
local EMBLEM = 40
local VEIL = 0.52          -- how dark the world goes
local DUSK = 0.45          -- the dusk at the left, under the words
local DUSK_W = 0.55        -- its reach, of the width
local STAGE_UP, STAGE_DOWN = 90, 110   -- the floor's wash fades in over the line and is full under it
local SHADE_H, LIGHT_H = 32, 16        -- the darker band under the line; the line's light
local GLOW_UP, GLOW_DOWN = 40, 24      -- its light on the world and the floor
local GLEAM_W, GLEAM_H = 128, 16
local WHISPER_EVENTS = { CHAT_MSG_WHISPER = true, CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER = true,
	CHAT_MSG_BN_WHISPER_INFORM = true }

local board, ui = nil, {}
local up, lastDepth, at = false, 0, 0
local mirrored = {}        -- chat windows whose lines are heard
local current, source      -- the window the chat shows (the tab you were on); the one whispers come from
local own                  -- the Tells window, when there is one
local heard = {}           -- a window -> lines it took since the last sync
local syncing = false
local whispers = 0         -- whisper lines the board holds

local Board = {}
I.board = Board

local function Ease(a, b, v)
	local t = min(1, max(0, (v - a) / (b - a)))
	return t * t * (3 - 2 * t)
end

local function Art(parent, file, layer, sub, color, alpha)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
	t:SetTexture(MEDIA .. file)
	if color then UI.Tint(t, color, alpha or 1) end
	return t
end

local function Light(parent, file, layer, sub, color)
	local t = Art(parent, file, layer or "OVERLAY", sub, color or Theme.Accent)
	t:SetBlendMode("ADD")
	return t
end

local function Plain(v)
	if issecretvalue(v) then return nil end
	return v
end

local function Shown(frame)
	if type(frame) ~= "table" or not frame.IsShown then return false end
	local shown = frame:IsShown()
	return not issecretvalue(shown) and shown == true
end

-- Text in the family's running font, keeping the ink and shadow UI.Text gave it.
local function Words(parent, size, color, face)
	local fs = UI.Text(parent, "", size, false, color)
	fs:SetFontObject(face or UI.TextFont(size))
	UI.Ink(fs, color or C.text)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return fs
end

-- The windows

local function Window(id)
	return rawget(_G, "ChatFrame" .. id)
end

-- The window's number, as the game's chat settings know it.
local function Id(frame)
	for id = 1, Constants.ChatFrameConstants.MaxChatWindows do
		if Window(id) == frame then return id end
	end
end

local function CarriesWhispers(id)
	for _, group in ipairs({ GetChatWindowMessages(id) }) do
		if group == "WHISPER" or group == "BN_WHISPER" then return true end
	end
	return false
end

-- The tab you are on: the dock's selected window, else the first window on screen.
local function Current()
	local dock = GENERAL_CHAT_DOCK
	local selected = type(dock) == "table" and dock.selected
	if Shown(selected) and not IsCombatLog(selected) then return selected end
	local found
	ChatFrameUtil.ForEachChatFrame(function(frame)
		if not found and Shown(frame) and not IsCombatLog(frame) then found = frame end
	end)
	return found
end

-- Where tells are read from: the Tells window, else the tab you are on if it carries whispers, else
-- the first window that does.
local function Source()
	if own then return own end
	local id = current and Id(current)
	if id and CarriesWhispers(id) then return current end
	for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
		local frame = Window(i)
		if frame and not IsCombatLog(frame) and CarriesWhispers(i) then return frame end
	end
end

-- The lines

-- A line's extra values as the game adds them: the kind's id, access and type ids, then the event.
local function IsWhisper(...)
	local event = select(4, ...)
	return not issecretvalue(event) and WHISPER_EVENTS[event] == true
end

-- A line as its window holds it, handed on to one of the board's frames.
local function Place(onto, whispersOnly, ...)
	if select("#", ...) == 0 then return end
	if whispersOnly and not IsWhisper(select(5, ...)) then return end
	onto:AddMessage(...)
	if onto == ui.whispers then whispers = whispers + 1 end
end

-- The section stands under its title as tall as its lines need (a whisper and a half each, since long
-- ones wrap; the newest show if that falls short), never more than its share of the column.
local function Layout()
	local section = whispers > 0 and current ~= own
	ui.whisperHead:SetShown(section)
	ui.whispers:SetShown(section)
	if section then
		ui.whispers:SetHeight(max(LINE_H, min(ui.whisperRoom or LINE_H, (whispers * 1.5 + 0.5) * LINE_H)))
		ui.chat:SetPoint("TOPLEFT", ui.whispers, "BOTTOMLEFT", 0, -WHISPER_GAP)
	else
		ui.chat:SetPoint("TOPLEFT", board, "TOPLEFT", EDGE, -(EDGE + HEAD_H))
	end
end

-- The window's newest `count` lines, oldest first: a window's message 1 is its oldest, as the game's
-- message frame keeps them.
local function Copy(frame, count, onto, whispersOnly)
	local n = frame:GetNumMessages()
	if issecretvalue(n) or type(n) ~= "number" then return end
	for i = max(1, n - min(count, LINES) + 1), n do Place(onto, whispersOnly, frame:GetMessageInfo(i)) end
end

-- The last lines of the windows the board shows.
local function Fill()
	ui.chat:Clear()
	ui.whispers:Clear()
	whispers = 0
	if current then Copy(current, LINES, ui.chat, false) end
	if source and current ~= own then Copy(source, LINES, ui.whispers, source ~= own) end
	Layout()
	ui.chat:ScrollToBottom()
	ui.whispers:ScrollToBottom()
end

-- Lines a window took since the last look, copied the frame after so ShyChat has rewritten them.
local function Sync()
	syncing = false
	if not up then
		wipe(heard)
		return
	end
	for frame, n in pairs(heard) do
		if frame == current then Copy(frame, n, ui.chat, false) end
		if frame == source and current ~= own then Copy(frame, n, ui.whispers, source ~= own) end
	end
	wipe(heard)
	Layout()
end

local function Echo(frame)
	if not up or not (frame == current or frame == source) then return end
	heard[frame] = (heard[frame] or 0) + 1
	if syncing then return end
	syncing = true
	C_Timer.After(0, Sync)
end

local function Mirror()
	ChatFrameUtil.ForEachChatFrame(function(frame)
		if mirrored[frame] or IsCombatLog(frame) then return end
		mirrored[frame] = true
		hooksecurefunc(frame, "AddMessage", Shy.Clocked("away: a chat line", Echo))
	end)
end

-- The pieces

local function BuildFloor()
	local line = CreateFrame("Frame", nil, board)
	ui.line = line
	line:SetHeight(1)
	line:SetPoint("LEFT", board, "LEFT")
	line:SetPoint("RIGHT", board, "RIGHT")
	line:SetPoint("BOTTOM", board, "BOTTOM", 0, FOOT)
	-- The floor: a wash fading in over the line, solid under it, with frost over both.
	local floor = CreateFrame("Frame", nil, board)
	ui.floor = floor
	floor:SetAllPoints()
	floor:SetAlpha(0)
	local fade = Art(floor, "TalkStage", "BACKGROUND", -6, C.panel, 0.9)
	fade:SetPoint("TOPLEFT", line, "TOPLEFT", 0, STAGE_UP)
	fade:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, STAGE_UP)
	fade:SetHeight(STAGE_UP + STAGE_DOWN)
	local ground = floor:CreateTexture(nil, "BACKGROUND", nil, -6)
	UI.Paint(ground, C.panel, 0.9)
	ground:SetPoint("TOPLEFT", fade, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT", board, "BOTTOMRIGHT")
	local frost = floor:CreateTexture(nil, "BACKGROUND", nil, -5)
	UI.Frost(frost)
	frost:SetAlpha(0.25)
	frost:SetPoint("TOPLEFT", fade, "TOPLEFT")
	frost:SetPoint("BOTTOMRIGHT", ground, "BOTTOMRIGHT")
	local mask = floor:CreateMaskTexture()
	mask:SetTexture(MEDIA .. "TalkStageMask", "CLAMP", "CLAMP")
	mask:SetAllPoints(fade)
	frost:AddMaskTexture(mask)
	local shade = Art(floor, "TalkStageShade", "BACKGROUND", -4)
	shade:SetPoint("TOPLEFT", line, "TOPLEFT")
	shade:SetPoint("TOPRIGHT", line, "TOPRIGHT")
	shade:SetHeight(SHADE_H)
	-- The line's light, falling onto the world and the floor, and the gleam that runs along it once.
	local lit = CreateFrame("Frame", nil, board)
	ui.lit = lit
	lit:SetAllPoints()
	lit:SetAlpha(0)
	local glow = Light(lit, "TalkStageGlow", "BORDER", 0)
	glow:SetPoint("TOPLEFT", line, "TOPLEFT", 0, GLOW_UP)
	glow:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, GLOW_UP)
	glow:SetHeight(GLOW_UP + GLOW_DOWN)
	glow:SetAlpha(0.1)
	local light = Light(lit, "TalkStageLight", "BORDER", 1)
	light:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 1.5)
	light:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 1.5)
	light:SetHeight(LIGHT_H)
	ui.gleam = Light(board, "TalkGleam", "ARTWORK", 0, Theme.light)
	ui.gleam:SetSize(GLEAM_W, GLEAM_H)
	ui.gleam:SetPoint("CENTER", line, "LEFT", 0, 0)
	ui.gleam:SetAlpha(0)
	-- In a look that dresses the stage its own way, the floor is a housing of that look (Stage.lua).
	if Shy.Stage then
		Shy.Stage.Floor(board, { floor = floor, lit = lit, line = line, ground = ground, frost = frost, shade = shade, glow = glow, light = light })
	end
end

local function Camera()
	ui.model:SetPortraitZoom(0)
	ui.model:SetCamDistanceScale(DISTANCE)
	ui.model:SetRotation(TURN)
end

local function BuildFigure()
	local stand = CreateFrame("Frame", nil, board)
	ui.stand = stand
	stand:SetPoint("BOTTOM", ui.line, "TOP", 0, 2)
	stand:SetAlpha(0)
	-- The halo behind the chest, and a pool of the same light at the feet.
	ui.halo = Light(stand, "Glow", "BACKGROUND", -6)
	ui.halo:SetAlpha(0.3)
	ui.pool = Light(stand, "Glow", "BACKGROUND", -6)
	ui.pool:SetAlpha(0.12)
	ui.model = CreateFrame("PlayerModel", nil, stand)
	ui.model:SetAllPoints()
	ui.model:SetKeepModelOnHide(true)
	ui.model:SetScript("OnModelLoaded", Camera)
end

-- A message frame of the board's: large running text, no fading, nothing to click.
local function Messages(parent)
	local frame = CreateFrame("ScrollingMessageFrame", nil, parent)
	frame:SetFontObject(UI.TextFont(TEXT))
	frame:SetJustifyH("LEFT")
	frame:SetShadowColor(0, 0, 0, 1)
	frame:SetShadowOffset(1, -1)
	frame:SetFading(false)
	frame:SetMaxLines(LINES)
	frame:SetTextCopyable(false)
	frame:EnableMouse(false)
	return frame
end

local function BuildWords()
	local words = CreateFrame("Frame", nil, board)
	ui.words = words
	words:SetAllPoints()
	words:SetAlpha(0)
	-- The tells section: a title in gold with a hairline running out to the right, the lines under it.
	local head = CreateFrame("Frame", nil, words)
	ui.whisperHead = head
	head:SetHeight(WHISPER_HEAD)
	head:SetPoint("TOPLEFT", board, "TOPLEFT", EDGE, -(EDGE + HEAD_H))
	head.title = UI.Text(head, "Whispers", 16, true, C.alert)
	head.title:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 8)
	head.rule = head:CreateTexture(nil, "ARTWORK")
	head.rule:SetColorTexture(1, 1, 1, 1)
	head.rule:SetGradient("HORIZONTAL", CreateColor(C.alert[1], C.alert[2], C.alert[3], 0.8),
		CreateColor(C.alert[1], C.alert[2], C.alert[3], 0))
	head.rule:SetHeight(1)
	head.rule:SetPoint("BOTTOMLEFT", head, "BOTTOMLEFT", 0, 2)
	head.rule:SetPoint("BOTTOMRIGHT", head, "BOTTOMRIGHT", 0, 2)
	head:Hide()
	ui.whispers = Messages(words)
	Board.whispers = ui.whispers
	ui.whispers:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
	ui.whispers:Hide()
	-- The chat column, standing on the dusk.
	ui.chat = Messages(words)
	Board.chat = ui.chat
	ui.chat:SetPoint("TOPLEFT", board, "TOPLEFT", EDGE, -(EDGE + HEAD_H))
	ui.chat:SetPoint("BOTTOM", ui.line, "TOP", 0, CHAT_LIFT)
	local chat = Shy.addons.Chat
	if chat and chat.Dress then
		chat:Dress(ui.chat)
		chat:Dress(ui.whispers)
	end
	-- The header: the emblem, Away, the time, what came in, how things stand.
	local emblem = B.CreateEmblem(words, Shy.core.mark, EMBLEM)
	emblem:SetPoint("TOPLEFT", board, "TOPLEFT", EDGE, -(EDGE - 8))
	ui.title = UI.Text(words, "Away", 26, true)
	ui.title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 12, -2)
	ui.since = UI.Text(words, "", 26, true, C.dim)
	ui.since:SetPoint("LEFT", ui.title, "RIGHT", 10, 0)
	ui.came = Words(words, 14, C.dim)
	ui.came:SetPoint("TOPLEFT", ui.title, "BOTTOMLEFT", 0, -4)
	ui.vitals = Words(words, 14, C.dim)
	Board.vitals = ui.vitals
	ui.vitals:SetPoint("TOPLEFT", ui.came, "BOTTOMLEFT", 0, -4)
	-- The footer, on the floor.
	ui.name = Words(words, 20, C.text, UI.NameFont(20))
	ui.name:SetPoint("TOPLEFT", ui.line, "TOPLEFT", EDGE, -14)
	ui.where = Words(words, 14, C.dim)
	ui.where:SetPoint("TOPLEFT", ui.name, "BOTTOMLEFT", 0, -6)
	ui.clock = UI.Text(words, "", 40, true)
	ui.clock:SetPoint("CENTER", ui.line, "TOP", 0, -FOOT / 2)
	ui.clock:SetJustifyH("CENTER")
	ui.gold = Words(words, 18, C.text, UI.NameFont(18))
	ui.gold:SetPoint("TOPRIGHT", ui.line, "TOPRIGHT", -EDGE, -14)
	ui.gold:SetJustifyH("RIGHT")
	ui.friends = Words(words, 14, C.dim)
	ui.friends:SetPoint("TOPRIGHT", ui.gold, "BOTTOMRIGHT", 0, -6)
	ui.friends:SetJustifyH("RIGHT")
end

local BuildStory   -- (the story's column: below, with the rest of it)

local function Build()
	if board then return end
	board = CreateFrame("Frame", nil, UIParent)
	Board.frame = board
	board:SetAllPoints()
	board:SetFrameStrata("MEDIUM")
	board:SetFrameLevel(8)
	board:EnableMouse(false)
	board:SetIgnoreParentAlpha(true)
	board:Hide()
	ui.veil = board:CreateTexture(nil, "BACKGROUND", nil, -8)
	ui.veil:SetAllPoints()
	ui.veil:SetColorTexture(0, 0, 0, 1)
	ui.veil:SetAlpha(0)
	ui.dusk = board:CreateTexture(nil, "BACKGROUND", nil, -7)
	ui.dusk:SetColorTexture(1, 1, 1, 1)
	ui.dusk:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, DUSK), CreateColor(0, 0, 0, 0))
	ui.dusk:SetPoint("TOPLEFT")
	ui.dusk:SetPoint("BOTTOMLEFT")
	ui.dusk:SetAlpha(0)
	BuildFloor()
	BuildFigure()
	BuildWords()
	BuildStory()
end

-- What the header and the footer say

local function Hex(color)
	local floor = math.floor
	return ("|cff%02x%02x%02x"):format(floor(color[1] * 255 + 0.5), floor(color[2] * 255 + 0.5), floor(color[3] * 255 + 0.5))
end

local function Came(came)
	local parts = {}
	for _, entry in ipairs(came or {}) do
		local text = entry.text
		if entry.word == "whisper" then text = Hex(C.alert) .. text .. "|r" end
		parts[#parts + 1] = text
	end
	local n = #parts
	if n == 0 then return "Nothing new" end
	if n == 1 then return parts[1] end
	if n == 2 then return parts[1] .. " and " .. parts[2] end
	return table.concat(parts, ", ", 1, n - 1) .. ", and " .. parts[n]
end

local function Where()
	local level, class = Plain(UnitLevel("player")), Plain((UnitClass("player")))
	local sub, zone = Plain(GetSubZoneText()), Plain(GetZoneText())
	local place = (sub and sub ~= "" and sub) or zone or ""
	local who = (level and class) and ("Level " .. level .. " " .. class) or class or ""
	local here = place ~= "" and ((IsResting() and "resting at " or "in ") .. place) or ""
	if who ~= "" and here ~= "" then return who .. ", " .. here end
	return who .. here
end

local function Friends()
	local n = Plain(C_FriendList.GetNumOnlineFriends())
	if not n or n == 0 then return "" end
	return n == 1 and "1 friend online" or (n .. " friends online")
end

local function Percent(part, whole)
	return math.floor(part / whole * 100 + 0.5) .. "%"
end

-- How things stand, read afresh each second: the frame rate, the latency to the world (home while the
-- world's is still unknown), the gear's wear over every worn piece, room in the ordinary bags, and the
-- rest banked below the cap, as a share of the level. A reading with nothing to say is left out.
local function Vitals()
	local parts = {}
	local fps = Plain(GetFramerate())
	if fps and fps > 0 then parts[#parts + 1] = math.floor(fps + 0.5) .. " fps" end
	local _, _, home, world = GetNetStats()
	local ms = Plain(world)
	if not ms or ms <= 0 then ms = Plain(home) end
	if ms and ms > 0 then parts[#parts + 1] = math.floor(ms + 0.5) .. " ms" end
	local left, whole = 0, 0
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local cur, most = GetInventoryItemDurability(slot)
		cur, most = Plain(cur), Plain(most)
		if cur and most and most > 0 then left, whole = left + cur, whole + most end
	end
	if whole > 0 then parts[#parts + 1] = "durability " .. Percent(left, whole) end
	local open = 0
	for bag = Enum.BagIndex.Backpack, Enum.BagIndex.Bag_4 do
		local n, family = C_Container.GetContainerNumFreeSlots(bag)
		n, family = Plain(n), Plain(family)
		if n and family == 0 then open = open + n end
	end
	parts[#parts + 1] = open == 0 and "bags full" or (open == 1 and "1 bag slot free" or (open .. " bag slots free"))
	if not GameRulesUtil.IsPlayerAtEffectiveMaxLevel() and not IsXPUserDisabled() then
		local rested, most = Plain(GetXPExhaustion()), Plain(UnitXPMax("player"))
		if rested and most and rested > 0 and most > 0 then parts[#parts + 1] = "rested " .. Percent(rested, most) end
	end
	return table.concat(parts, ", ")
end

local function Refresh(since, came)
	ui.since:SetText(since or "")
	ui.came:SetText(Came(came))
	ui.vitals:SetText(Vitals())
	ui.clock:SetText(GameTime_GetTime(true))
	ui.where:SetText(Where())
	ui.gold:SetText(UI.Money(GetMoney(), true, 16))
	ui.friends:SetText(Friends())
end

-- Your story: the column at the right
--
-- What your bags know across your characters stands at the top, mirroring the header, each with its picture: gold on
-- every character, Waylaid Crates, Merchant's Favor, Honor Points (ShyBags and ShyCrates; this character's alone
-- without them). The figures count up
-- as the board rises. Under them the game's statistics roll up like credits, the best first, then the game's
-- groups, the most exciting first, each under its name in the accent. They fade in at the foot and out at the top,
-- and start over once through. Read as the board comes up; a pool of rows a screen's worth deep carries the roll.

local STORY = {
	X = 0.80,          -- the column's left edge, as a share of the width: clear of the figure
	BIG = 30,          -- a figure at the top
	SMALL = 12,        -- labels and captions
	VALUE = 17,        -- a statistic
	STEP = 58,         -- from one figure at the top to the next
	UNDER = 32,        -- a figure's label under it
	GAP = 10,          -- between the figures and the roll
	CAP = 42,          -- a caption's room, its air above it
	ROW = 42,          -- a statistic's room
	RULE = 150,        -- the caption's hairline
	FADE = 56,         -- the roll fades over this at both ends
	SPEED = 14,        -- units a second
	STEPS = 24,        -- the figures count up in this many steps
	HEADS = 4,
	ICON = 26,         -- a figure's picture, at its left (Shy.Slot)
	ICON_GAP = 8,
}
-- The statistics that lead the roll, the best first (the client's Achievement IDs).
local BEST = {
	193,    -- Largest hit dealt
	189,    -- Largest heal cast
	1098,   -- Onyxia kills
	334,    -- Most gold ever owned
	332,    -- Most expensive auction sold
	395,    -- Warsong Gulch flags captured
	319,    -- Duels won
	1336,   -- Creature type killed the most
	594,    -- Deaths from Hogger
	1042,   -- Number of hugs
}
-- Then the game's groups, the most exciting first (the client's Achievement_Category IDs). Any other follows in the
-- game's own order.
local GROUPS = {
	14821,  -- Boss Kills
	141,    -- Combat
	136,    -- Honorable Kills
	137,    -- Killing Blows
	153,    -- Battlegrounds
	154,    -- World PvP
	140,    -- Wealth
	135,    -- Creatures
	133,    -- Quests
	134,    -- Travel
	147,    -- Reputation
	191,    -- Gear
	14807,  -- Dungeons & Raids
	173,    -- Professions
	178,    -- Secondary Skills
	132,    -- Skills
	145,    -- Consumables
	131,    -- Social
	130,    -- Character
	122,    -- Deaths
	126,    -- Deaths in the world
	125,    -- Deaths in dungeons and raids
	124,    -- Deaths in battlegrounds
	127,    -- Resurrection
	21,     -- Player vs. Player
}
local RANK = {}
for i, id in ipairs(GROUPS) do RANK[id] = i end

local story = { rows = {}, entries = {}, heads = {}, at = 0, first = 1, room = 0 }
Board.story = story

-- A statistic's value as the game words it (a count, a sum in coins, a name), or nil where there is none. A "most"
-- one comes as its count and its answer, "1496 (Eastern Kingdoms)": the answer alone, and true.
local function Readable(v)
	v = Plain(v)
	if type(v) == "number" then v = tostring(v) end
	if type(v) ~= "string" or v == "" or v == "--" then return nil end
	local answer = v:match("^%s*[%d,.]+%s*%((.-)%)%s*$")
	if answer and answer ~= "" then return answer, true end
	local n = tonumber(v)
	if n then return n > 0 and BreakUpLargeNumbers(n) or nil end
	return v
end

-- Under a "most" one's answer, what it is the most of: "Continent with the most Honorable Kills" reads "Most
-- Honorable Kills" under Eastern Kingdoms, "Creature type killed the most" reads "Killed the most" under Beast.
local function MostOf(label)
	local rest = label:match("^.- with the most (.+)$")
	if rest then return "Most " .. rest end
	local done = label:match("^.- (%a+ the most)$") or label:match("^.- (%a+ most)$")
	if done then return done:sub(1, 1):upper() .. done:sub(2) end
	return label
end

local function Named(id)
	local _, name = GetAchievementInfo(id)
	name = Plain(name)
	if type(name) ~= "string" or name == "" or name:find("<", 1, true) or name:find("UNUSED", 1, true) then return nil end
	return name
end

-- A group's name, with its parent's where the name alone says too little ("Deaths · World").
local function GroupName(id)
	local name, parent = GetCategoryInfo(id)
	name, parent = Plain(name), Plain(parent)
	if type(name) ~= "string" then return nil end
	if type(parent) ~= "number" or parent == -1 then return name end
	local over, top = GetCategoryInfo(parent)
	over, top = Plain(over), Plain(top)
	if type(over) ~= "string" or top == -1 or name:find(over, 1, true) then return name end
	return over .. " · " .. name
end

local function Add(entries, kind, value, label)
	local h = kind == "cap" and STORY.CAP or STORY.ROW
	local last = entries[#entries]
	entries[#entries + 1] = { kind = kind, value = value, label = label, y = last and (last.y + last.h) or 0, h = h }
end

-- The roll: your best, then each group with something in it, the most exciting first.
local function Statistics()
	local entries = {}
	local list = GetStatisticsCategoryList() or {}
	local ids, groups, byId = {}, {}, {}
	for key, id in pairs(list) do
		if type(key) == "number" then ids[#ids + 1] = key end
	end
	table.sort(ids)
	for order, key in ipairs(ids) do
		local category = list[key]
		local rows = {}
		for i = 1, Plain(GetCategoryNumAchievements(category)) or 0 do
			local quantity, skip, id = GetStatistic(category, i)
			id = Plain(id)
			if not Plain(skip) and id then
				local value, most = Readable(quantity)
				local label = Named(id)
				if value and label then
					if most then label = MostOf(label) end
					local row = { value = value, label = label }
					rows[#rows + 1] = row
					byId[id] = row
				end
			end
		end
		if #rows > 0 then groups[#groups + 1] = { name = GroupName(category), rows = rows, rank = RANK[category] or (#GROUPS + order) } end
	end
	local best = false
	for _, id in ipairs(BEST) do
		local row = byId[id]
		if row then
			if not best then Add(entries, "cap", "Your best") end
			best = true
			Add(entries, "stat", row.value, row.label)
			row.taken = true
		end
	end
	table.sort(groups, function(a, b) return a.rank < b.rank end)
	for _, group in ipairs(groups) do
		local named = false
		for _, row in ipairs(group.rows) do
			if not row.taken then
				if not named and group.name then Add(entries, "cap", group.name) end
				named = true
				Add(entries, "stat", row.value, row.label)
			end
		end
	end
	return entries
end

-- A currency as a figure: how many your characters hold (ShyBags), this one's alone without it, with its name and
-- picture as the game gives them (the bags show the same).
local function Currency(id, name)
	local bags = Shy.addons.Bags
	local info = C_CurrencyInfo.GetCurrencyInfo(id)
	local n = bags and bags.Currency and bags:Currency(id) or Plain(info and info.quantity) or 0
	local icon = info and Plain(info.iconFileID)
	return { n = n, label = info and Plain(info.name) or name, icon = icon ~= 0 and icon or nil }
end

-- The figures at the top: { n or copper, label, icon }. Gold on every character where there is more than one (this
-- one's stands on the floor); Waylaid Crates and Merchant's Favor with ShyCrates; Honor Points.
local function Highlights()
	local out = {}
	local bags, crates = Shy.addons.Bags, Shy.addons.Crates
	local gold = bags and bags.Gold and bags:Gold()
	if gold and gold.chars > 1 then
		out[#out + 1] = { copper = gold.hand + gold.mail + gold.sold, label = ("Gold, %d characters"):format(gold.chars) }
	end
	if crates and crates.Count then
		out[#out + 1] = { n = crates:Count(), label = "Waylaid Crates", icon = crates.Icon and crates:Icon() or nil }
		local favor = crates.Favor and crates:Favor()
		if favor then out[#out + 1] = Currency(favor, "Merchant's Favor") end
	end
	out[#out + 1] = Currency(Constants.CurrencyConsts.HONOR_CURRENCY_ID, "Honor Points")
	return out
end

-- A figure at the top, counted up to `share` of itself.
local function Figure(head, share)
	local it = head.it
	if it.copper then
		head.value:SetText(UI.Money(math.floor(it.copper * share), true, STORY.BIG))
	else
		head.value:SetText(BreakUpLargeNumbers(math.floor(it.n * share + 0.5)))
	end
end

local function Count(depth)
	local share = math.floor(Ease(0.5, 1, depth) * STORY.STEPS + 0.5) / STORY.STEPS
	if share == story.counted then return end
	story.counted = share
	for _, head in ipairs(story.heads) do
		if head.it then Figure(head, share) end
	end
end

local function RollRow()
	local row = CreateFrame("Frame", nil, story.window)
	row:SetHeight(STORY.ROW)
	row.cap = Words(row, STORY.SMALL, Theme.Accent)
	row.cap:SetJustifyH("RIGHT")
	row.cap:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 14)
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetColorTexture(1, 1, 1, 1)
	row.rule:SetSize(STORY.RULE, 1)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 8)
	row.value = UI.Text(row, "", STORY.VALUE, true)
	row.value:SetJustifyH("RIGHT")
	row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT")
	row.label = Words(row, STORY.SMALL, C.dim)
	row.label:SetJustifyH("RIGHT")
	row.label:SetWordWrap(false)
	row.label:SetPoint("TOPRIGHT", row.value, "BOTTOMRIGHT", 0, -3)
	row:Hide()
	return row
end

local function Dress(row, e)
	row.entry = e
	local cap = e.kind == "cap"
	row.cap:SetShown(cap)
	row.rule:SetShown(cap)
	row.value:SetShown(not cap)
	row.label:SetShown(not cap)
	if cap then
		row.cap:SetText(e.value:upper())
	else
		row.value:SetText(e.value)
		row.label:SetText(e.label)
	end
	row:SetHeight(e.h)
end

-- Each frame: the list a little further up, the rows on screen given what stands there now.
local function Roll(_, elapsed)
	local entries = story.entries
	local n = #entries
	if n == 0 then return end
	local room = story.room
	if room <= 0 then return end
	local last = entries[n]
	local whole = last.y + last.h + room
	story.at = story.at + elapsed * STORY.SPEED
	if story.at >= whole then
		story.at = story.at % whole
		story.first = 1
	end
	local top = room - story.at
	while story.first < n and top + entries[story.first].y + entries[story.first].h < 0 do story.first = story.first + 1 end
	local used = 0
	for i = story.first, n do
		local e = entries[i]
		local y = top + e.y
		if y >= room then break end
		used = used + 1
		local row = story.rows[used]
		if not row then
			row = RollRow()
			story.rows[used] = row
			row:SetWidth(story.width or 1)
			row.rule:SetGradient("HORIZONTAL", story.from, story.to)
		end
		if row.entry ~= e then Dress(row, e) end
		row:SetPoint("TOPRIGHT", story.window, "TOPRIGHT", 0, -y)
		local middle = y + e.h / 2
		row:SetAlpha(max(0, min(1, middle / STORY.FADE, (room - middle) / STORY.FADE)))
		if not row:IsShown() then row:Show() end
	end
	for i = used + 1, #story.rows do
		local row = story.rows[i]
		if row:IsShown() then
			row:Hide()
			row.entry = nil
		end
	end
end

function BuildStory()
	local column = CreateFrame("Frame", nil, ui.words)
	story.frame = column
	column:SetPoint("TOPRIGHT", board, "TOPRIGHT", -EDGE, -(EDGE - 8))
	column:SetPoint("BOTTOM", ui.line, "TOP", 0, CHAT_LIFT)
	for i = 1, STORY.HEADS do
		local head = {}
		head.value = UI.Text(column, "", STORY.BIG, true)
		head.value:SetJustifyH("RIGHT")
		head.value:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -(i - 1) * STORY.STEP)
		head.label = Words(column, STORY.SMALL, C.dim)
		head.label:SetJustifyH("RIGHT")
		head.label:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, -((i - 1) * STORY.STEP + STORY.UNDER))
		-- Its picture at its left, in the family's slot: it moves out as the figure counts up.
		head.holder = CreateFrame("Frame", nil, column)
		head.holder:SetSize(STORY.ICON, STORY.ICON)
		head.holder:SetPoint("RIGHT", head.value, "LEFT", -STORY.ICON_GAP, 0)
		head.icon = head.holder:CreateTexture(nil, "ARTWORK")
		head.icon:SetAllPoints()
		head.slot = Shy.Slot.New(head.holder, { icon = head.icon, size = STORY.ICON, hover = false })
		head.holder:Hide()
		story.heads[i] = head
	end
	local window = CreateFrame("Frame", nil, column)
	story.window = window
	window:SetClipsChildren(true)
	window:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT")
	window:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT")
	window:SetScript("OnUpdate", Shy.Clocked("away: the roll", Roll))
end

-- As the board comes up: the figures and the roll read afresh, the roll from its start.
local function Tell()
	-- (The board covers the screen: its measure is UIParent's, known before the board is laid out.)
	local width = max(1, UIParent:GetWidth() * (1 - STORY.X) - EDGE)
	story.frame:SetWidth(width)
	story.width = width
	local r, g, b = Theme.AccentSolid()
	story.from, story.to = CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.7)
	local its = Highlights()
	for i, head in ipairs(story.heads) do
		local it = its[i]
		head.it = it
		head.value:SetShown(it ~= nil)
		head.label:SetShown(it ~= nil)
		if it then head.label:SetText(it.label:upper()) end
		if it and it.icon then head.icon:SetTexture(it.icon) end
		head.holder:SetShown(it ~= nil and it.icon ~= nil)
	end
	story.counted = nil
	local below = #its * STORY.STEP + STORY.GAP
	story.window:SetPoint("TOPLEFT", story.frame, "TOPLEFT", 0, -below)
	-- (Worked out, not measured: the floor's line it stands on is still rising.)
	story.room = UIParent:GetHeight() - (EDGE - 8) - FOOT - CHAT_LIFT - below
	story.entries = Statistics()
	story.at, story.first = 0, 1
	for _, row in ipairs(story.rows) do
		row:SetWidth(width)
		row.rule:SetGradient("HORIZONTAL", story.from, story.to)
		row:Hide()
		row.entry = nil
	end
end

-- The first frame up: the screen's measure, the character, the windows and their lines.
local function Rise(now)
	local w, h = board:GetWidth(), board:GetHeight()
	ui.dusk:SetWidth(max(1, w * DUSK_W))
	local column = max(1, w * CHAT_W - EDGE)
	ui.chat:SetWidth(column)
	ui.whisperHead:SetWidth(column)
	ui.whisperRoom = max(LINE_H, (h - EDGE - HEAD_H - FOOT - CHAT_LIFT) * WHISPER_SHARE)
	ui.whispers:SetSize(column, ui.whisperRoom)
	local fh = h * FIGURE_H
	ui.standX = (FIGURE_X - 0.5) * w
	ui.stand:SetSize(max(1, fh * 0.5), max(1, fh))
	ui.halo:SetSize(fh * HALO, fh * HALO)
	ui.halo:SetPoint("CENTER", ui.stand, "BOTTOM", 0, fh * HALO_AT)
	ui.pool:SetSize(fh * 0.84, fh * 0.5)
	ui.pool:SetPoint("CENTER", ui.stand, "BOTTOM", 0, 0)
	local ok, set = pcall(ui.model.SetUnit, ui.model, "player")
	if ok and (issecretvalue(set) or set ~= false) then Camera() else ui.model:ClearModel() end
	local name, surname = UnitName("player")
	name, surname = Plain(name), Plain(surname)
	ui.name:SetText((name or "") .. ((surname and surname ~= "") and (" " .. surname) or ""))
	Mirror()
	local id = S.TellsWindow and S.TellsWindow()
	own = id and Window(id) or nil
	if own and not Shown(own) then own = nil end
	current = Current()
	source = Source()
	wipe(heard)
	Fill()
	Tell()
	at = now
end

function Board.Set(depth, now, since, came)
	if depth <= 0 then
		if up then Board.Drop() end
		return
	end
	Build()
	if not up then
		up = true
		board:Show()
		Rise(now)
		Refresh(since, came)
	end
	local k = Ease(0, 1, depth)
	ui.veil:SetAlpha(VEIL * Ease(0, 0.5, depth))
	ui.dusk:SetAlpha(k)
	ui.line:SetPoint("BOTTOM", board, "BOTTOM", 0, FOOT - FLOOR_RISE * (1 - k))
	ui.floor:SetAlpha(k)
	ui.lit:SetAlpha(Ease(0.45, 0.7, depth))
	-- The gleam runs once along the line as it lights, on the way up only.
	local g = Ease(0.45, 0.9, depth)
	if depth >= lastDepth and g > 0 and g < 1 then
		ui.gleam:SetPoint("CENTER", ui.line, "LEFT", board:GetWidth() * g, 0)
		ui.gleam:SetAlpha(sin(pi * g))
	else
		ui.gleam:SetAlpha(0)
	end
	local f = Ease(0.35, 1, depth)
	ui.stand:SetAlpha(f)
	ui.stand:SetPoint("BOTTOM", ui.line, "TOP", ui.standX or 0, 2 - FIGURE_RISE * (1 - f))
	ui.words:SetAlpha(Ease(0.5, 1, depth))
	-- (The figures count up on the way up only.)
	if depth >= lastDepth then Count(depth) end
	lastDepth = depth
	if now - at >= 1 then
		at = now
		Refresh(since, came)
	end
end

function Board.Drop()
	up, lastDepth, current, source, own = false, 0, nil, nil, nil
	wipe(heard)
	if not board then return end
	ui.gleam:SetAlpha(0)
	board:Hide()
end
