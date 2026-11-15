-- Chat bubbles in the hover's housing, as an item's card: the speaker's name as the head on the card's band,
-- the words under the band's line. One hue a bubble, the speaker's class color: the light in the top edge,
-- the edge (tinted a fifth back toward white, as a quality edge is), the band's wash and line, the name.
-- The words stay near white, taken a little toward the color chat gives that kind of message (say, yell,
-- party, raid), and the kind's own color is kept to a small word after the name. An NPC's hue is its
-- reaction, as its tooltip's (mint, gold, soft red), or the game's color for NPC talk when it isn't on
-- screen to ask.
--
-- A bubble is Blizzard's: a holder from C_ChatBubbles.GetAllChatBubbles whose one child carries the words
-- (String) and the tail (Tail) inside a nine slice, standing INSET out from the words. Nothing is written
-- onto it: its art is faded through a kit and ours stands in a box of our own on the child, closer round
-- the words than the game's own margin. Its top stands higher by the head's room only when there is a
-- head, and it is as wide as the words or as the head needs (the game sizes a bubble to its words, and
-- "hey" is narrower than a name). Its edge is laid from the edge
-- art's own pieces so the foot's strip can end either side of the tail, whose picture carries the join.
-- There is no event for a bubble, so after a message the bubbles are looked over for a short while and each
-- is matched to a message by its words. Words can be secret (chat in lockdown): such a bubble gets the
-- housing alone. Bubbles in an instance are forbidden and left alone.

local ADDON, ns = ...
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = UI.colors
local B = {}
ns.Bubbles = B

local MEDIA, CORE = ns.MEDIA, Shy.MEDIA
local kit = Skin.NewKit()
local db, on
local made = setmetatable({}, { __mode = "k" })      -- bubble child -> our pieces on it
local showing = setmetatable({}, { __mode = "k" })   -- bubble child -> the words it was dressed for
local recent = {}                                    -- messages heard lately, oldest first
local looker, since, lastHeard = nil, 0, 0

-- Blizzard's pieces on the child, by name: the nine slice's and the tail.
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center", "Tail" }
-- The child stands 16 out from the words. The box's top: this far above the child's with a head, this far
-- inside it without; its foot and sides this far inside the child's.
local HEADED, BARE, FOOT, SIDES = 8, 7, 7, 6
local EDGE, EDGE_ART = 8, 32     -- the edge art: a corner's size, and the picture's
local REACH, DROP = 18, 3        -- the shadow's reach past the housing, and how far down it falls (the hover's)
local SHADE_MID = 0.5            -- darkness of HoverShade's middle
local LIGHT = 12                 -- height of the top light
local HEAD, NAME_Y = 16, 8.5     -- the band's line this far down from the box's top; the name's middle at NAME_Y
local NAME, WORD = 10, 9         -- font sizes: the name, the kind's word
local SIDE, GAP = 10, 6          -- the name's and the word's distance in from the sides, and between them
local BAND = { top = 0.20, foot = 0.06, line = 0.9, shadow = 0.55, fall = 6 }   -- the card's
local TAIL_W, TAIL_H, TAIL_OVER = 20, 14, 4   -- the tail's picture, and how far it reaches up over the foot
local TINT = 0.65                -- the words: their kind's color taken this far toward the text color
local KEEP = 10                  -- seconds a message is kept to match a bubble
local LOOK = 0.05                -- seconds between looks while bubbles are up or a message was just heard
local IDLE = 0.25                -- seconds between looks otherwise (a bubble can come without a message heard)
local REST = 3                   -- seconds after the last bubble or message before the looks slow down
local WHITE = { 1, 1, 1 }
local OUTLINES = { OUTLINE = "OUTLINE", THICKOUTLINE = "OUTLINE, THICK" }

local KINDS = {
	CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL",
	CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
	CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER", CHAT_MSG_RAID_WARNING = "RAID_WARNING",
	CHAT_MSG_MONSTER_SAY = "MONSTER_SAY", CHAT_MSG_MONSTER_YELL = "MONSTER_YELL", CHAT_MSG_MONSTER_PARTY = "MONSTER_PARTY",
}
local NPC = { MONSTER_SAY = true, MONSTER_YELL = true, MONSTER_PARTY = true }

-- The word after the name, from the game's own strings: the verb of "%s yells: ", the label of "[Party] %s: ".
local function Verb(template) return type(template) == "string" and template:match("%%s%s*(.-)%s*:") or nil end
local function Label(template) return type(template) == "string" and template:match("%[(.-)%]") or nil end
local TAGS = {
	YELL = Verb(CHAT_YELL_GET), MONSTER_YELL = Verb(CHAT_YELL_GET),
	PARTY = Label(CHAT_PARTY_GET), PARTY_LEADER = Label(CHAT_PARTY_GET), MONSTER_PARTY = Label(CHAT_PARTY_GET),
	RAID = Label(CHAT_RAID_GET), RAID_LEADER = Label(CHAT_RAID_GET), RAID_WARNING = Label(CHAT_RAID_GET),
}

-- The chat window's color for that kind of message.
local function KindColor(kind)
	local info = kind and ChatTypeInfo[kind]
	if info and info.r then return { info.r, info.g, info.b } end
	return WHITE
end

local function ClassColor(class)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then return { color:GetRGB() } end
end

-- An NPC's hue is its reaction, as its tooltip's: mint, gold or soft red. The NPC is found by its GUID
-- among the units it is likely to be (the one you talk to, under the cursor, targeted) and the nameplates.
local UNITS = { "npc", "softinteract", "mouseover", "target", "focus" }

local function ReactionOf(unit, guid)
	local g = UnitGUID(unit)
	if issecretvalue(g) or g ~= guid then return end
	local reaction = UnitReaction(unit, "player")
	if issecretvalue(reaction) or type(reaction) ~= "number" then return end
	if reaction <= 3 then return C.bad end
	if reaction == 4 then return C.alert end
	return C.good
end

-- fn(unit) for each unit the speaker might be, until one answers.
local function EachUnit(fn)
	for _, unit in ipairs(UNITS) do
		local found = fn(unit)
		if found then return found end
	end
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		if not nameplate:IsForbidden() and nameplate.unitToken then
			local found = fn(nameplate.unitToken)
			if found then return found end
		end
	end
end

local function ReactionHue(guid)
	return EachUnit(function(unit) return ReactionOf(unit, guid) end)
end

-- A player's level: what the game says of the GUID, or the level of the unit that is them, if on screen.
local function Known(level)
	return not issecretvalue(level) and type(level) == "number" and level > 0 and level or nil
end

local function LevelOf(guid, told)
	local level = Known(told)
	if level then return level end
	return EachUnit(function(unit)
		local g = UnitGUID(unit)
		if issecretvalue(g) or g ~= guid then return end
		return Known(UnitLevel(unit))
	end)
end

local function Toward(color, to, by)
	return { color[1] + (to[1] - color[1]) * by, color[2] + (to[2] - color[2]) * by, color[3] + (to[3] - color[3]) * by }
end

-- Messages

-- The words as a bubble shows them: no color codes, a link's text alone, no pictures.
local function Plain(text)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|T.-|t", "")
	return text
end

-- What two texts must share to be the same words: plain, no brackets, spaces collapsed, any case (a link
-- the game rewrites on its way back, as a quest's, still matches).
local function Key(text)
	local key = Plain(text):gsub("[%[%]]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""):lower()
	return key
end

local function Forget(now)
	local keep = 1
	while recent[keep] and now - recent[keep].at > KEEP do keep = keep + 1 end
	if keep > 1 then
		for i = keep, #recent do recent[i - keep + 1] = recent[i] end
		for i = #recent, #recent - keep + 2, -1 do recent[i] = nil end
	end
end

local function Match(words)
	for i = #recent, 1, -1 do
		local m = recent[i]
		if m.words == words or m.text == words then return m end
	end
	local key = Key(words)
	for i = #recent, 1, -1 do
		if recent[i].key == key then return recent[i] end
	end
end

local function Heard(event, text, name, _, _, _, _, _, _, _, _, _, guid)
	local kind = KINDS[event]
	if not kind or issecretvalue(text) or type(text) ~= "string" then return end
	local who
	if not issecretvalue(name) and type(name) == "string" and name ~= "" then
		who = NPC[kind] and name or Ambiguate(name, "short")
	end
	local class, hue, level
	local known = not issecretvalue(guid) and type(guid) == "string" and guid ~= ""
	if NPC[kind] then
		-- Its reaction while it is on screen; the game's color for NPC talk when it isn't.
		hue = (known and ReactionHue(guid)) or KindColor(kind)
	elseif known then
		local _, file, _, _, _, _, _, told = GetPlayerInfoByGUID(guid)
		if type(file) == "string" then class = file end
		level = LevelOf(guid, told)
	end
	local now = GetTime()
	Forget(now)
	recent[#recent + 1] = { text = text, words = Plain(text), key = Key(text), name = who, class = class, hue = hue, level = level, kind = kind, npc = NPC[kind], at = now }
	lastHeard = now
	B.Look()
end

-- The pieces

local function Sliced(owner, layer, sublevel, file, margin)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(file)
	t:SetTextureSliceMargins(margin, margin, margin, margin)
	return t
end

-- One piece of the edge art: a corner, or a strip of it between the corners (stretched along the edge).
local function EdgePiece(owner, left, top, right, bottom)
	local t = owner:CreateTexture(nil, "BORDER", nil, 0)
	t:SetTexture(CORE .. "HoverEdge")
	t:SetTexCoord(left / EDGE_ART, right / EDGE_ART, top / EDGE_ART, bottom / EDGE_ART)
	return t
end

local function Gradient(owner, layer, sublevel)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetColorTexture(1, 1, 1)
	return t
end

local function Words(owner, size, title)
	local fs = owner:CreateFontString(nil, "OVERLAY", nil, 6)
	fs:SetFontObject(title and UI.TitleFont(size) or UI.TextFont(size))
	UI.Follow(fs)   -- a title keeps up with the theme's font
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetWordWrap(false)
	return fs
end

local function Build(child)
	local p = {}
	-- The box everything stands in; Fit sizes it to the child or the head. It stands beside the child under
	-- its holder, a level below it, so the words draw over our fill (a child frame's regions would cover them).
	local box = CreateFrame("Frame", nil, child:GetParent() or child)
	box:SetFrameLevel(math.max(0, child:GetFrameLevel() - 1))
	p.box = box
	p.shade = Sliced(box, "BACKGROUND", -8, CORE .. "HoverShade", 28)
	p.shade:SetPoint("TOPLEFT", -REACH, REACH - DROP)
	p.shade:SetPoint("BOTTOMRIGHT", REACH, -REACH - DROP)
	p.bg = box:CreateTexture(nil, "BACKGROUND", nil, -6)
	p.bg:SetPoint("TOPLEFT", 2, -2)
	p.bg:SetPoint("BOTTOMRIGHT", -2, 2)
	-- The shadow is SHADE_MID black under the whole bubble: the fill's alpha is solved for both to reach the tip's strength.
	local function Fill()
		local panel = C.panel
		return panel[1], panel[2], panel[3], 1 - (1 - Theme.TipStrength()) / (1 - SHADE_MID)
	end
	UI.Paint(p.bg, Fill)
	p.frost = box:CreateTexture(nil, "BACKGROUND", nil, -5)
	p.frost:SetPoint("TOPLEFT", 2, -2)
	p.frost:SetPoint("BOTTOMRIGHT", -2, 2)
	UI.Frost(p.frost)
	-- The tail's inside is the fill, carried on under the foot.
	p.tailFill = box:CreateTexture(nil, "BACKGROUND", nil, -6)
	p.tailFill:SetTexture(MEDIA .. "BubbleTailFill")
	p.tailFill:SetSize(TAIL_W, TAIL_H)
	p.tailFill:SetPoint("TOP", box, "BOTTOM", 0, TAIL_OVER)
	UI.Tint(p.tailFill, Fill)
	-- The head's band (an item card's): a wash of the color down the head, a line of it under the head
	-- fading out at both ends, and a soft shadow falling from that line onto the words.
	p.band = Gradient(box, "BACKGROUND", 1)
	p.band:SetPoint("TOPLEFT", 2, -2)
	p.band:SetPoint("TOPRIGHT", -2, -2)
	p.band:SetHeight(HEAD - 2)
	p.rise = Gradient(box, "BORDER", 2)
	p.rise:SetPoint("TOPLEFT", box, "TOPLEFT", 2, -HEAD)
	p.rise:SetPoint("BOTTOMRIGHT", box, "TOP", 0, -HEAD - 1)
	p.fall = Gradient(box, "BORDER", 2)
	p.fall:SetPoint("TOPLEFT", box, "TOP", 0, -HEAD)
	p.fall:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -2, -HEAD - 1)
	p.drop = Gradient(box, "BORDER", 1)
	p.drop:SetPoint("TOPLEFT", 2, -HEAD - 1)
	p.drop:SetPoint("TOPRIGHT", -2, -HEAD - 1)
	p.drop:SetHeight(BAND.fall)
	p.drop:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, BAND.shadow))
	-- The edge from its art's pieces: four corners, three strips, and the foot's strip in two round the tail.
	local art = EDGE_ART - EDGE
	p.tail = box:CreateTexture(nil, "ARTWORK", nil, 2)
	p.tail:SetTexture(MEDIA .. "BubbleTail")
	p.tail:SetSize(TAIL_W, TAIL_H)
	p.tail:SetPoint("TOP", box, "BOTTOM", 0, TAIL_OVER)
	local tl, tr = EdgePiece(box, 0, 0, EDGE, EDGE), EdgePiece(box, art, 0, EDGE_ART, EDGE)
	local bl, br = EdgePiece(box, 0, art, EDGE, EDGE_ART), EdgePiece(box, art, art, EDGE_ART, EDGE_ART)
	for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(EDGE, EDGE) end
	tl:SetPoint("TOPLEFT")
	tr:SetPoint("TOPRIGHT")
	bl:SetPoint("BOTTOMLEFT")
	br:SetPoint("BOTTOMRIGHT")
	local top, left, right = EdgePiece(box, EDGE, 0, art, EDGE), EdgePiece(box, 0, EDGE, EDGE, art), EdgePiece(box, art, EDGE, EDGE_ART, art)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	local footLeft, footRight = EdgePiece(box, EDGE, art, art, EDGE_ART), EdgePiece(box, EDGE, art, art, EDGE_ART)
	footLeft:SetPoint("TOPLEFT", bl, "TOPRIGHT")
	footLeft:SetPoint("BOTTOMRIGHT", p.tail, "TOPLEFT", 0, -TAIL_OVER)
	footRight:SetPoint("TOPRIGHT", br, "TOPLEFT")
	footRight:SetPoint("BOTTOMLEFT", p.tail, "TOPRIGHT", 0, -TAIL_OVER)
	p.edge = { tl, tr, bl, br, top, left, right, footLeft, footRight, p.tail }
	p.light = box:CreateTexture(nil, "ARTWORK", nil, 1)
	p.light:SetTexture(CORE .. "HoverLight")
	p.light:SetPoint("TOPLEFT", 4, 0)
	p.light:SetPoint("TOPRIGHT", -4, 0)
	p.light:SetHeight(LIGHT)
	-- The head: the name at the left, the kind's word at the right, each as wide as its text.
	p.name = Words(box, NAME, true)
	p.name:SetJustifyH("LEFT")
	p.name:SetPoint("LEFT", box, "TOPLEFT", SIDE, -NAME_Y)
	p.word = Words(box, WORD)
	p.word:SetJustifyH("RIGHT")
	p.word:SetPoint("RIGHT", box, "TOPRIGHT", -SIDE, -NAME_Y - 0.5)
	-- A player's level, quietly after the name.
	p.level = Words(box, WORD)
	p.level:SetJustifyH("LEFT")
	p.level:SetPoint("LEFT", p.name, "RIGHT", GAP - 2, -0.5)
	UI.Ink(p.level, C.dim)
	p.head = { p.band, p.rise, p.fall, p.drop }
	p.all = { p.shade, p.bg, p.frost, p.tailFill, p.band, p.rise, p.fall, p.drop, p.light, p.name, p.level, p.word, unpack(p.edge) }
	made[child] = p
	return p
end

-- The box over the child: its width, or the head's when that is more. Returns false while the child's
-- width can't be read (the game hasn't laid a new bubble out yet, or its words are secret), so the
-- next look fits it again.
local function Fit(p, child, headed)
	local box = p.box
	box:ClearAllPoints()
	box:SetPoint("TOP", child, "TOP", 0, headed and HEADED or -BARE)
	box:SetPoint("BOTTOM", child, "BOTTOM", 0, FOOT)
	local wide, known = nil, true
	if headed then
		local width = child:GetWidth()
		known = not issecretvalue(width) and type(width) == "number" and width > 0
		local word, level = p.word:GetText(), p.level:IsShown() and p.level:GetText()
		local need = SIDE + p.name:GetStringWidth() + ((level and level ~= "") and (GAP - 2 + p.level:GetStringWidth()) or 0)
			+ ((word and word ~= "") and (GAP + p.word:GetStringWidth()) or 0) + SIDE
		if known and width - 2 * SIDES < need then wide = need end
	end
	if wide then
		box:SetWidth(wide)
	else
		box:SetWidth(0)   -- the sides' anchors size it
		box:SetPoint("LEFT", child, "LEFT", SIDES, 0)
		box:SetPoint("RIGHT", child, "RIGHT", -SIDES, 0)
	end
	p.fitted = known
	return known
end

-- The box fades as the bubble does: its alpha is the child's, looked at every look.
local function Follow(p, child)
	local alpha = child:GetAlpha()
	if not issecretvalue(alpha) and type(alpha) == "number" then p.box:SetAlpha(alpha) end
end

local function Font()
	for _, f in ipairs(ns.FONTS) do
		if f.value == db.font then return f end
	end
	return ns.FONTS[1]
end

-- The words in the chat's face at the bubble's size.
local function Wear(fontString)
	local font = Font()
	local flags = OUTLINES[db.outline] or ""
	if font.family then
		kit:FontObject(fontString, font.family(db.bubbleSize, flags))
	elseif font.font then
		kit:Font(fontString, font.font, db.bubbleSize, flags)
	else
		kit:Font(fontString, (ChatFontNormal:GetFont()), db.bubbleSize, flags)
	end
end

local function Dress(child, message)
	local p = made[child] or Build(child)
	for _, key in ipairs(PIECES) do kit:Hide(child[key]) end
	p.box:Show()
	for _, region in ipairs(p.all) do region:Show() end
	Wear(child.String)
	local kind = message and KindColor(message.kind) or WHITE
	kit:Text(child.String, Toward(kind, C.text, TINT))
	-- The bubble's one hue: a player's class, an NPC's reaction.
	local hue = message and (ClassColor(message.class) or message.hue)
	-- The edge art is grey: the hue tints it a fifth of the way back toward white, so the bevel still reads.
	local edge = hue and Toward(hue, WHITE, 0.2) or WHITE
	for _, piece in ipairs(p.edge) do UI.Tint(piece, edge) end
	p.light:SetShown(hue ~= nil)
	if hue then UI.Tint(p.light, hue) end
	local named = message and message.name
	if not db.bubbleNames then named = nil end
	p.name:SetShown(named ~= nil)
	p.word:SetShown(named ~= nil)
	local banded = named and hue
	for _, region in ipairs(p.head) do region:SetShown(banded ~= nil) end
	if named then
		p.name:SetText(named)
		UI.Ink(p.name, hue or Theme.skin.metal)
		p.level:SetText(message.level and tostring(message.level) or "")
		p.word:SetText(TAGS[message.kind] or "")
		UI.Ink(p.word, kind)
	end
	p.level:SetShown(named ~= nil and message.level ~= nil)
	if banded then
		local r, g, b = hue[1], hue[2], hue[3]
		p.band:SetGradient("VERTICAL", CreateColor(r, g, b, BAND.foot), CreateColor(r, g, b, BAND.top))
		local lit = Toward(hue, WHITE, 0.25)
		local faint, bright = CreateColor(lit[1], lit[2], lit[3], 0), CreateColor(lit[1], lit[2], lit[3], BAND.line)
		p.rise:SetGradient("HORIZONTAL", faint, bright)
		p.fall:SetGradient("HORIZONTAL", bright, faint)
	end
	p.headed = named ~= nil
	Fit(p, child, p.headed)
	Follow(p, child)
end

-- Blizzard's art back, ours put away.
local function Undress(child)
	local p = made[child]
	if not p then return end
	p.box:Hide()
	showing[child] = nil
end

-- Our pieces on a bubble's child, if it has been dressed.
function B.Pieces(child) return made[child] end

-- The child that carries the words: the holder's one child, or the holder itself.
local function WordsOf(bubble)
	local child = bubble:GetChildren()
	if child and child.String then return child end
	if bubble.String then return bubble end
end

-- Looking

local toldForbidden, lastSeen = false, 0

-- One pass over the bubbles up now. Returns how many there are, and how many the game keeps to itself.
function B.Pass()
	if not on then return 0, 0 end
	local bubbles = C_ChatBubbles.GetAllChatBubbles(true)
	local count, forbidden = 0, 0
	for _, bubble in ipairs(bubbles) do
		if bubble:IsForbidden() then
			forbidden = forbidden + 1
		else
			local child = WordsOf(bubble)
			if child and child:IsForbidden() then forbidden = forbidden + 1 end
			if child and not child:IsForbidden() then
				count = count + 1
				local text = child.String:GetText()
				if issecretvalue(text) then
					if showing[child] ~= true then
						Dress(child, nil)
						showing[child] = true
					end
				elseif showing[child] ~= text then
					Dress(child, Match(text))
					showing[child] = text
				else
					local p = made[child]
					if p and not p.fitted then Fit(p, child, p.headed) end
					if p then Follow(p, child) end
				end
			end
		end
	end
	if count > 0 then lastSeen = GetTime() end
	-- Inside an instance the game keeps its bubbles to itself: said once, so nobody waits for a look that can't come.
	if forbidden > 0 and not toldForbidden then
		toldForbidden = true
		ns.T:Print("inside instances the game keeps its own chat bubbles; they can't be restyled there.")
	end
	return count, forbidden
end

-- Looks all the while the look is on: quick while bubbles are up or a message was just heard, slow otherwise.
local function OnLook(_, elapsed)
	since = since + elapsed
	local now = GetTime()
	local busy = now - lastHeard < REST or now - lastSeen < REST
	if since < (busy and LOOK or IDLE) then return end
	since = 0
	B.Pass()
end

-- Look at the bubbles now (after a message, or when the look is switched on).
function B.Look()
	if not on then return end
	if not looker then
		looker = CreateFrame("Frame")
		looker:SetScript("OnUpdate", OnLook)
	end
	since = LOOK
	looker:Show()
end

-- Everything up now in the current settings; or, switched off, Blizzard's own bubbles again.
function B.Apply()
	local want = db.bubbles
	if want and not on then
		on = true
		for event in pairs(KINDS) do B.events:RegisterEvent(event) end
		lastHeard = GetTime()
		B.Pass()
		B.Look()
	elseif not want and on then
		on = false
		for event in pairs(KINDS) do B.events:UnregisterEvent(event) end
		if looker then looker:Hide() end
		for child in pairs(made) do Undress(child) end
		kit:Restore()
	elseif on then
		for child in pairs(showing) do showing[child] = nil end
		kit:Restore()
		B.Pass()
	end
end

function B.Init(settings)
	db = settings
	B.events = CreateFrame("Frame")
	B.events:SetScript("OnEvent", function(_, ...) Heard(...) end)
end
