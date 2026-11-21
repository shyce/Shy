-- Chat bubbles in the theme's housing, as an item's card: the speaker's name as the head on the card's band,
-- the words under the band's line. The housing is the hover's, worn in the look the theme chose (its mini
-- make, as every hover's), and solid in every look: a bubble stands over the world, so nothing shows through
-- it and the words read the same over snow or shadow. Every ink is worked out against the look's own fill
-- (Theme.Readable, Theme.Vivid) and the words wear the theme's text effect, so they read in every look.
-- One hue a bubble: a player's class, an NPC's reaction (mint, gold, soft red, as its tooltip's; the game's
-- color for NPC talk when it isn't on screen to ask). The hue is the light in the top edge, the edge (a fifth
-- back toward white, as a quality edge is), the band's wash and line, the name. The words stay near white,
-- leaning a little toward the color chat gives their kind; the kind's own color is kept to a small word at
-- the head's right ("yells", "Party", "whispers"), and a language you don't speak by default stands quietly
-- before it, as the chat window shows it.
--
-- A bubble is Blizzard's: a holder from C_ChatBubbles.GetAllChatBubbles whose one child is a single frame
-- carrying the nine slice, the words (String) and the tail (Tail), so each bubble draws whole. Ours does the
-- same: one frame of our own on the child holds the housing, the head and a copy of the words, and
-- Blizzard's art and words are faded through a kit. Two bubbles never interleave and the newest stands on
-- top. The game draws bubbles in the world's units, which don't follow the interface's size: ours is scaled
-- to the interface, the size of its tooltips. It stands on the game's bubble's foot, so it grows up from the
-- speaker's head, as wide as the words (up to a line's width) or as the head needs.
-- There is no event for a bubble, so after a message the bubbles are looked over for a short while and each
-- is matched to a message by its words. Words are secret while chat is locked down (in combat in some
-- places): such a bubble is left as the game draws it. Bubbles in an instance are forbidden and left alone.

local ADDON, ns = ...
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = UI.colors
local B = {}
ns.Bubbles = B

local CORE = Shy.MEDIA
local db, on
local made = setmetatable({}, { __mode = "k" })      -- bubble child -> our pieces on it
local showing = setmetatable({}, { __mode = "k" })   -- bubble child -> the words it was dressed for (true: left to the game)
local recent = {}                                    -- messages heard lately, oldest first
local looker, since, lastHeard = nil, 0, 0
local stack, restack = 0, false                      -- the order bubbles were dressed in; the levels want setting again

-- Blizzard's pieces on the child, by name: the nine slice's, the tail, the words.
local PIECES = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center", "Tail", "String" }
-- Round the words: the box's sides and foot this far out, its top this far above them (with a head: the band
-- and the gap under its line).
local PAD = { side = 10, foot = 9, top = 9, headed = 24 }
local WRAP = 250                 -- the words' widest line; longer words wrap
local SLACK = 1                  -- room past the words' measure, so the last word stays on its line
local TIP = 3                    -- the tail's tip this far under the game's bubble's foot (in the game's units)
local REACH, DROP = 18, 3        -- the shadow's reach past the housing, and how far down it falls (the hover's)
local LIGHT = 12                 -- height of the top light
local HEAD, NAME_Y = 16, 8.5     -- the band's line this far down from the box's top; the name's middle at NAME_Y
local NAME, WORD = 10, 9         -- font sizes: the name, the words at the head's right
local SIDE, GAP = 10, 6          -- the name's and the kind's word's distance in from the sides, and between words
local BAND = { top = 0.20, foot = 0.06, line = 0.9, shadow = 0.55, fall = 6 }   -- the card's
local TINT = 0.65                -- the words: their kind's color taken this far toward the text color
local KEEP = 10                  -- seconds a message is kept to match a bubble
local LOOK = 0.05                -- seconds between looks while bubbles are up or a message was just heard
local IDLE = 0.25                -- seconds between looks otherwise (a bubble can come without a message heard)
local REST = 3                   -- seconds after the last bubble or message before the looks slow down
local WHITE = { 1, 1, 1 }
local OUTLINES = { OUTLINE = "OUTLINE", THICKOUTLINE = "OUTLINE, THICK" }

-- Every kind of talk the game puts in a bubble.
local KINDS = {
	CHAT_MSG_SAY = "SAY", CHAT_MSG_YELL = "YELL",
	CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY_LEADER",
	CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID_LEADER", CHAT_MSG_RAID_WARNING = "RAID_WARNING",
	CHAT_MSG_MONSTER_SAY = "MONSTER_SAY", CHAT_MSG_MONSTER_YELL = "MONSTER_YELL", CHAT_MSG_MONSTER_PARTY = "MONSTER_PARTY",
	CHAT_MSG_MONSTER_WHISPER = "MONSTER_WHISPER",
}
local NPC = { MONSTER_SAY = true, MONSTER_YELL = true, MONSTER_PARTY = true, MONSTER_WHISPER = true }
-- Say and yell are heard by anyone near, so they are measured against the language you speak to them in.
local NEAR = { SAY = true, YELL = true }
-- Talk raised over the rest, whose color its housing wears: a yell in yell red, a raid warning in its orange, in every
-- look's own parts (UI.SetAccent: a galaxy's halo, a grove's gems and leaves, the matrix's phosphor) and the frame's
-- edge and the tail; the name and its band keep who is speaking. Its color is the chat window's, read once
-- (`loud`, again on a settings change).
local LOUD = { YELL = "YELL", MONSTER_YELL = "YELL", RAID_WARNING = "RAID_WARNING" }
local loud = {}

-- The word at the head's right, from the game's own strings: the verb of "%s yells: ", the label of "[Party] %s: ".
local function Verb(template) return type(template) == "string" and template:match("%%s%s*(.-)%s*:") or nil end
local function Label(template) return type(template) == "string" and template:match("%[(.-)%]") or nil end
local TAGS = {
	YELL = Verb(CHAT_YELL_GET), MONSTER_YELL = Verb(CHAT_YELL_GET), MONSTER_WHISPER = Verb(CHAT_MONSTER_WHISPER_GET),
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

-- The language, when it isn't the one you'd hear that kind of talk in (the chat window's rule): another
-- race's tongue, or the other faction's.
local function Language(kind, language)
	if issecretvalue(language) or type(language) ~= "string" or language == "" then return nil end
	local usual = NEAR[kind] and GetAlternativeDefaultLanguage() or GetDefaultLanguage()
	if language == usual then return nil end
	return language
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

local function Heard(event, text, name, language, _, _, _, _, _, _, _, _, guid)
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
	recent[#recent + 1] = { text = text, words = Plain(text), key = Key(text), name = who, class = class, hue = hue,
		level = level, kind = kind, language = Language(kind, language), at = now }
	lastHeard = now
	B.Look()
end

-- The pieces

-- The look's own fill, as it stands under the words: what every ink on a bubble is worked out against.
local function Ground()
	local panel = C.panel
	local r, g, b = UI.LookFill(Theme.Look(), panel[1], panel[2], panel[3], 1)
	return r, g, b
end

local function Gradient(owner, layer, sublevel)
	local t = owner:CreateTexture(nil, layer, nil, sublevel)
	t:SetColorTexture(1, 1, 1)
	return t
end

-- A quiet word at the head's right: the theme's text face, lettered as the theme letters.
local function Small(owner)
	local fs = owner:CreateFontString(nil, "OVERLAY", nil, 6)
	fs:SetFontObject(UI.TextFont(WORD))
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetWordWrap(false)
	UI.Letter(fs)
	return fs
end

local function Build(child)
	local p = { kit = Skin.NewKit() }
	-- One frame on the child holds everything, the words with it, so the bubble draws whole. As the child's
	-- own it shows, hides and fades with it.
	local box = CreateFrame("Frame", nil, child)
	p.box = box
	-- The housing: the hover's, in the look's mini make, solid (no opacity: nothing shows through a bubble).
	UI.Panel(box, { mini = true, brackets = false, line = false, fill = C.panel, looks = true })
	box.shyEdge:SetTexture(CORE .. "HoverEdge")
	box.shyEdge:SetTextureSliceMargins(8, 8, 8, 8)
	-- The hover's soft shadow under it, onto the world.
	p.shade = box:CreateTexture(nil, "BACKGROUND", nil, -8)
	p.shade:SetTexture(CORE .. "HoverShade")
	p.shade:SetTextureSliceMargins(28, 28, 28, 28)
	p.shade:SetPoint("TOPLEFT", -REACH, REACH - DROP)
	p.shade:SetPoint("BOTTOMRIGHT", REACH, -REACH - DROP)
	-- The head's band (an item card's): a wash of the hue down the head, a line of it under the head fading
	-- out at both ends, and a soft shadow falling from that line onto the words. Laid inside the look's
	-- border (Fit).
	p.band = Gradient(box, "BACKGROUND", 1)
	p.rise = Gradient(box, "BORDER", 2)
	p.fall = Gradient(box, "BORDER", 2)
	p.drop = Gradient(box, "BORDER", 1)
	p.drop:SetHeight(BAND.fall)
	p.drop:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, BAND.shadow))
	p.head = { p.band, p.rise, p.fall, p.drop }
	-- The tail in the look's own make (UI.LookTail): its inside, the look's own face laid again and cut to the tail's
	-- shape (the opening over it too); the look's edge layers running on round it; and the notch, cut from the
	-- housing's own edge where it would cross the flanks. Made as many as the look asks for, kept for the next.
	p.insideMask = box:CreateMaskTexture()
	p.notch = box:CreateMaskTexture()
	p.insides, p.tails, p.notched = {}, {}, setmetatable({}, { __mode = "k" })
	p.light = box:CreateTexture(nil, "ARTWORK", nil, 1)
	p.light:SetTexture(CORE .. "HoverLight")
	p.light:SetPoint("TOPLEFT", 4, 0)
	p.light:SetPoint("TOPRIGHT", -4, 0)
	p.light:SetHeight(LIGHT)
	-- The words, wrapping as the game's do (a long word too), lettered for the fill they stand on.
	p.text = box:CreateFontString(nil, "OVERLAY", nil, 5)
	p.text:SetShadowOffset(1, -1)
	p.text:SetShadowColor(0, 0, 0, 1)
	p.text:SetJustifyH("CENTER")
	p.text:SetWordWrap(true)
	p.text:SetNonSpaceWrap(true)
	UI.Letter(p.text, { ground = Ground })
	-- The head: the name at the left, the kind's word at the right, a language before it, each as wide as its text.
	p.name = box:CreateFontString(nil, "OVERLAY", nil, 6)
	UI.TitleFace(p.name, NAME)
	p.name:SetShadowOffset(1, -1)
	p.name:SetShadowColor(0, 0, 0, 1)
	p.name:SetWordWrap(false)
	p.name:SetJustifyH("LEFT")
	p.name:SetPoint("LEFT", box, "TOPLEFT", SIDE, -NAME_Y)
	p.word = Small(box)
	p.word:SetJustifyH("RIGHT")
	p.word:SetPoint("RIGHT", box, "TOPRIGHT", -SIDE, -NAME_Y - 0.5)
	p.language = Small(box)
	p.language:SetJustifyH("RIGHT")
	UI.Ink(p.language, C.dim)
	-- A player's level, quietly after the name.
	p.level = Small(box)
	p.level:SetJustifyH("LEFT")
	p.level:SetPoint("LEFT", p.name, "RIGHT", GAP - 2, -0.5)
	UI.Ink(p.level, C.dim)
	-- The inks, each worked out against the look's fill whenever the theme paints (p.ink, p.hue, p.kind: Dress's).
	p.inks = {
		[p.text] = function()
			local c, r, g, b = p.ink, Ground()
			return Theme.Readable(c[1], c[2], c[3], r, g, b, Theme.LC_BODY)
		end,
		[p.name] = function()
			local c, r, g, b = p.hue or Theme.skin.metal, Ground()
			return Theme.Vivid(c[1], c[2], c[3], r, g, b, Theme.LC_LABEL)
		end,
		[p.word] = function()
			local c, r, g, b = p.kind, Ground()
			return Theme.Vivid(c[1], c[2], c[3], r, g, b, Theme.LC_LABEL)
		end,
	}
	p.ink, p.kind = WHITE, WHITE
	made[child] = p
	return p
end

-- A string's measure, or `none` where the game won't give it.
local function Measured(value, none)
	if issecretvalue(value) or type(value) ~= "number" then return none end
	return value
end

-- What stands at the head's right: the kind's word at the side, a language before it.
local function Right(p)
	local word = p.word:GetText()
	p.language:ClearAllPoints()
	if word and word ~= "" then
		p.language:SetPoint("RIGHT", p.word, "LEFT", -GAP, 0)
	else
		p.language:SetPoint("RIGHT", p.box, "TOPRIGHT", -SIDE, -NAME_Y - 0.5)
	end
end

-- How wide a string's words are, or 0 when it is hidden or empty.
local function Wide(fs)
	local words = fs:IsShown() and fs:GetText()
	if not words or words == "" then return 0 end
	return Measured(fs:GetStringWidth(), 0)
end

-- How wide the head is: the name, its level, the language and the kind's word, with the gaps between them.
local function Head(p)
	local level, language, word = Wide(p.level), Wide(p.language), Wide(p.word)
	local right = word + language + ((word > 0 and language > 0) and GAP or 0)
	return SIDE + Wide(p.name) + (level > 0 and (GAP - 2 + level) or 0) + (right > 0 and (GAP + right) or 0) + SIDE
end

-- The box round the words: as wide as they are (up to WRAP) or as the head needs, its top higher by the
-- head's room when there is one; the band inside the look's border. Measured at the size it is drawn at, and
-- fitted again whenever the words or the head measure otherwise (the interface's size changed, or their font
-- did since); `again` lays it out whatever they measure.
local function Fit(p, again)
	local text = p.text
	local wide = math.min(math.ceil(Measured(text:GetUnboundedStringWidth(), WRAP)) + SLACK, WRAP)
	if text:GetWidth() ~= wide then text:SetWidth(wide) end
	local high = Measured(text:GetStringHeight(), 0)
	local need = p.headed and Head(p) or 0
	local fit = p.fit
	if not again and fit and fit.wide == wide and fit.high == high and fit.need == need then return end
	p.fit = { wide = wide, high = high, need = need }
	local top = p.headed and PAD.headed or PAD.top
	local box = p.box
	box:SetSize(math.max(wide + 2 * PAD.side, need), top + high + PAD.foot)
	text:ClearAllPoints()
	text:SetPoint("TOP", box, "TOP", 0, -top)
	-- The band inside the look's border.
	local l, t, r = UI.LookBorder(box.shyLook)
	p.band:ClearAllPoints()
	p.band:SetPoint("TOPLEFT", l, -t)
	p.band:SetPoint("TOPRIGHT", -r, -t)
	p.band:SetHeight(math.max(1, HEAD - t))
	p.rise:ClearAllPoints()
	p.rise:SetPoint("TOPLEFT", box, "TOPLEFT", l, -HEAD)
	p.rise:SetPoint("BOTTOMRIGHT", box, "TOP", 0, -HEAD - 1)
	p.fall:ClearAllPoints()
	p.fall:SetPoint("TOPLEFT", box, "TOP", 0, -HEAD)
	p.fall:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -r, -HEAD - 1)
	p.drop:ClearAllPoints()
	p.drop:SetPoint("TOPLEFT", l, -HEAD - 1)
	p.drop:SetPoint("TOPRIGHT", -r, -HEAD - 1)
end

-- The tail in the look the housing wears: its inside and its edge layers, each tinted, faded and blended as the look
-- does its own face and edge, laid from the box's foot; the housing's edge cut where the tail turns it down. Its
-- point's drop sets where the box stands (Place).
local function Tail(p)
	local name, tail, layers, inside = UI.LookTail(p.box.shyLook)
	if not tail then return end
	local box = p.box
	local file = CORE .. "Tail" .. name
	local function Lay(t)
		t:SetSize(tail.w, tail.h)
		t:ClearAllPoints()
		t:SetPoint("TOP", box, "BOTTOM", 0, tail.up)
	end
	Lay(p.insideMask)
	p.insideMask:SetTexture(file .. "Inside", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	Lay(p.notch)
	p.notch:SetTexture(file .. "Notch", "CLAMPTOWHITE", "CLAMPTOWHITE")
	for i, part in ipairs(inside) do
		local t = p.insides[i]
		if not t then
			t = box:CreateTexture(nil, "OVERLAY", nil, -8 + math.min(i, 3) - 1)
			t:AddMaskTexture(p.insideMask)
			p.insides[i] = t
		end
		Lay(t)
		if part.file then
			t:SetTexture(part.file, "REPEAT", "REPEAT")
			t:SetTexCoord(0, tail.w / part.tile, 0, tail.h / part.tile)
			UI.Tint(t, part.color, part.alpha or 1)
		else
			t:SetTexCoord(0, 1, 0, 1)
			UI.Paint(t, part.fill and Ground or part.color, part.alpha or 1)
		end
		t:SetBlendMode(part.blend or "BLEND")
		t:Show()
	end
	for i = #inside + 1, #p.insides do p.insides[i]:Hide() end
	for i, layer in ipairs(layers) do
		local t = p.tails[i]
		if not t then
			t = box:CreateTexture(nil, "OVERLAY", nil, math.min(0, -5 + i))
			p.tails[i] = t
		end
		Lay(t)
		t:SetTexture(file .. layer.layer)
		t:SetBlendMode(layer.blend or "BLEND")
		UI.Tint(t, layer.color, layer.alpha or 1)
		t:Show()
	end
	for i = #layers + 1, #p.tails do p.tails[i]:Hide() end
	for _, t in ipairs(UI.LookEdges(box.shyLook)) do
		if not p.notched[t] then
			t:AddMaskTexture(p.notch)
			p.notched[t] = true
		end
	end
	if p.tailDrop ~= tail.drop then
		p.tailDrop = tail.drop
		p.ratio = nil   -- (stood again for its point)
	end
end

-- The interface's size against the world's the game draws bubbles in.
local function Ratio(child)
	local mine, its = UIParent:GetEffectiveScale(), child:GetEffectiveScale()
	if issecretvalue(its) or type(its) ~= "number" or its <= 0 then return 1 end
	return mine / its
end

-- The box at the interface's size, standing on the game's bubble's foot with the tail's tip where its tip is.
local function Place(p, child)
	local ratio = Ratio(child)
	if p.ratio == ratio then return end
	p.ratio = ratio
	p.box:SetScale(ratio)
	p.box:ClearAllPoints()
	p.box:SetPoint("BOTTOM", child, "BOTTOM", 0, (p.tailDrop or 0) - TIP / ratio)
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
		fontString:SetFontObject(font.family(db.bubbleSize, flags))
		UI.Follow(fontString)
	elseif font.font then
		fontString:SetFont(font.font, db.bubbleSize, flags)
	else
		fontString:SetFont((ChatFontNormal:GetFont()), db.bubbleSize, flags)
	end
end

local function Dress(child, words, message)
	local p = made[child] or Build(child)
	for _, key in ipairs(PIECES) do p.kit:Hide(child[key]) end
	p.box:Show()
	p.unheard = message == nil
	local kind = message and KindColor(message.kind) or WHITE
	-- The bubble's one hue: a player's class, an NPC's reaction.
	local hue = message and (ClassColor(message.class) or message.hue)
	p.ink, p.kind, p.hue = Toward(kind, C.text, TINT), kind, hue
	Wear(p.text)
	p.text:SetText(words)
	-- Raised talk: the look's own parts in its color.
	local raised = message and LOUD[message.kind]
	if raised and not loud[raised] then loud[raised] = KindColor(raised) end
	raised = raised and loud[raised]
	UI.SetAccent(p.box, raised)
	-- The edge art is grey: the hue (raised talk's, else the speaker's) tints it a fifth of the way back toward white,
	-- so the bevel still reads.
	local edge = (raised or hue) and Toward(raised or hue, WHITE, 0.2) or Theme.skin.metal
	UI.SetBorder(p.box, edge)
	p.light:SetShown(hue ~= nil)
	if hue then UI.Tint(p.light, hue) end
	local named = message and message.name
	if not db.bubbleNames then named = nil end
	p.name:SetShown(named ~= nil)
	p.word:SetShown(named ~= nil)
	p.language:SetShown(named ~= nil and message.language ~= nil)
	local banded = named and hue
	for _, region in ipairs(p.head) do region:SetShown(banded ~= nil) end
	if named then
		p.name:SetText(named)
		p.level:SetText(message.level and tostring(message.level) or "")
		p.word:SetText(TAGS[message.kind] or "")
		p.language:SetText(message.language or "")
	end
	p.level:SetShown(named ~= nil and message.level ~= nil)
	-- (The inks are functions of p.ink, p.kind and p.hue: painted for them now, and again with the theme.)
	for fs, ink in pairs(p.inks) do UI.Ink(fs, ink) end
	if banded then
		local r, g, b = hue[1], hue[2], hue[3]
		p.band:SetGradient("VERTICAL", CreateColor(r, g, b, BAND.foot), CreateColor(r, g, b, BAND.top))
		local lit = Toward(hue, WHITE, 0.25)
		local faint, bright = CreateColor(lit[1], lit[2], lit[3], 0), CreateColor(lit[1], lit[2], lit[3], BAND.line)
		p.rise:SetGradient("HORIZONTAL", faint, bright)
		p.fall:SetGradient("HORIZONTAL", bright, faint)
	end
	p.headed = named ~= nil
	Right(p)
	-- Scaled to the interface before the words are measured: the game lays them out wider or narrower at
	-- another size.
	Tail(p)
	Place(p, child)
	Fit(p, true)
	-- Newest on top; dressed again for a setting, it keeps its place.
	if not p.order or p.words ~= words then
		stack = stack + 1
		p.order = stack
		restack = true
	end
	p.words = words
end

-- Blizzard's art and words back, ours put away.
local function Undress(child)
	local p = made[child]
	if not p then return end
	p.kit:Restore()
	p.box:Hide()
	p.order, p.words = nil, nil
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
local up = {}   -- the dressed bubbles of a pass, to stack

local function ByOrder(a, b) return a.order < b.order end

-- Each dressed bubble a level over the one dressed before it, all over the game's own.
local function Restack()
	restack = false
	local base = 0
	for _, entry in ipairs(up) do
		local level = entry.child:GetFrameLevel()
		if not issecretvalue(level) and type(level) == "number" and level > base then base = level end
	end
	table.sort(up, ByOrder)
	for i, entry in ipairs(up) do entry.box:SetFrameLevel(base + i) end
end

-- One pass over the bubbles up now. Returns how many there are, and how many the game keeps to itself.
function B.Pass()
	if not on then return 0, 0 end
	local bubbles = C_ChatBubbles.GetAllChatBubbles(true)
	local count, forbidden = 0, 0
	for i = #up, 1, -1 do up[i] = nil end
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
					-- Secret words: the game's own bubble.
					if showing[child] ~= true then
						Undress(child)
						showing[child] = true
					end
				elseif showing[child] ~= text then
					Dress(child, text, Match(text))
					showing[child] = text
				else
					local p = made[child]
					if p then
						-- Seen before its message was heard: dressed for it once it is.
						local message = p.unheard and Match(text)
						if message then
							Dress(child, text, message)
						else
							Place(p, child)
							Fit(p)
						end
					end
				end
				local p = made[child]
				if p and p.order then up[#up + 1] = { child = child, box = p.box, order = p.order } end
			end
		end
	end
	if restack then Restack() end
	if count > 0 then lastSeen = GetTime() end
	-- Inside an instance the game keeps its bubbles to itself: said once, so nobody waits for a look that can't come.
	if forbidden > 0 and not toldForbidden then
		toldForbidden = true
		ns.T:Print("inside instances the game keeps its own chat bubbles. They can't be restyled there.")
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
	elseif on then
		for kind in pairs(loud) do loud[kind] = nil end
		for child in pairs(showing) do showing[child] = nil end
		B.Pass()
	end
end

function B.Init(settings)
	db = settings
	B.events = CreateFrame("Frame")
	B.events:SetScript("OnEvent", function(_, ...) Heard(...) end)
end
