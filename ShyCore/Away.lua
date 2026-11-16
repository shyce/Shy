-- The away board: what the screen becomes once you have been away a while with the HUD faded
-- (Immersion.lua says when, and keeps the clock and the tally). The world goes down to a dusk; a floor
-- rises at the foot of the screen with the accent as light along its line; your character stands on the
-- line at the right, lit from the line and by a halo behind the chest; chat stands large at the left on
-- the dusk, with no housing, whispers in a section of their own over it; a header at the top left says
-- how long you have been away, what came in and how things stand (the frame rate, the latency, the
-- gear's wear, room in the bags, rest banked); and the footer on the floor carries your name, your
-- level and where you stand, the clock, your gold and friends online. Nothing here takes the mouse:
-- anything you do brings the HUD back.
--
--   Shy.Immersion.board.Set(depth, now, since, came)  how far up the board is (0 to 1, hidden at 0), the
--                                                     time away as words, what came in ({ word, text } ...)
--   Shy.Immersion.board.Drop()                        gone at once (a fight)
--   Shy.Immersion.board.frame / .chat / .whispers     the board, its chat and its whispers, once built
--   Shy.Immersion.board.vitals                        the header's line on how things stand
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
