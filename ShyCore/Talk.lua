-- Shy.Talk: the quest dialog of immersive quest text. While quest text is "immersive", talking to a quest
-- giver or a gossip NPC puts the talk on a stage: a dark wash rising from the foot of the screen, its top
-- edge lit with the accent; the speaker's head in a seal standing on that line, their name on a plaque
-- pinned to it, their words under it read out a page at a time, and your answers under the words
-- (options, quests, objectives, rewards, buttons). Space or a click reads on, Backspace or a right-click
-- goes back a page (or plays the first again), the wheel turns pages, 1-9 pick, Esc leaves.
--
-- Space always leads somewhere, and pressed enough always ends the talk: once the words are read it gives
-- the page's answer, and its keycap stands on whatever it gives. On a list it gives the lead quest (one
-- ready to hand in, else one offered; never an option, which opens another window, nor an offer an addon
-- would have you pass by) and its cap stands at that row's right end; with no quest to lead, or an answer
-- that can't be given yet (a hand-in short of its items, a quest with a cost to pay), it says Goodbye. A reward to choose always has one suggested
-- (ShyGear's pick, else the first) lit as chosen with a word saying why; Complete with the suggestion
-- standing asks first (the one reward alone, Take it or Choose another; Backspace goes back, a number goes
-- back with that reward chosen), while a reward you chose yourself is handed in at once. An option's row
-- carries the glyph of what it opens. Shift+Space (or a click on its cap, which stands beside Read on
-- while there is reading left) skips: all the words at once, the answers in, and the page's answer given
-- as Space gives it, the dialog still seen; a reward to choose it skips to the question, never past it.
--
--   Shy.Talk.Page()          while it stands in for the game's windows: the page the game is on, "gossip",
--                            "greeting", "detail", "progress" or "reward" (nil otherwise)
--   Shy.Talk.IsOn()          the game's quest and gossip windows are stood down
--   Shy.Talk.Speaker(kind)   the unit whose head a page shows ("questnpc" or "npc"), nil for none
--   Shy.Talk.Want(id, fn)    what your addon would have the player pick on a gossip page (ShyQuest: the
--                            trainer's line at the trainer its card sent you to). fn(npc, lines) is asked
--                            as each page comes, with the NPC's id (nil when withheld) and the page's lines
--                            in order, each { index, id, kind, name } (kind: what it opens, by the game's
--                            icon: "train", "unlearn", "vendor", "auction", "fly", "inn", "bank", "battle",
--                            "petition", "tabard", "heal" or "talk"), and answers one of the lines and a
--                            few words why, or nil. The line is picked for you a frame after the page
--                            comes, dialog or not, unless Shift is held, someone answered the page first,
--                            or a quest comes first (one ready to hand in or newly offered: the dialog
--                            leads that, and the line is picked when you talk again). Shown instead, its
--                            row carries the words, and leads where no quest does. A talk you came to for
--                            a quest (a quest's page was up in it) is left alone: the line is neither
--                            picked nor led, and Space ends the talk.
--   Shy.Talk.Note(id, fn)    a word on a quest offered you that your addon wouldn't have you take (ShyQuest:
--                            "Not in your guide"). fn(questID) is asked as a list or a quest's page is drawn and
--                            answers the words or nil. The quest's row is quiet (its mark and title dimmed,
--                            never led to by Space), and carries the words at its right end after a skip
--                            glyph, both in the "no" tone; a quest's own page shows them beside its title.
--                            Nothing is said where no addon answers (a zone followed, no guide).
--   Shy.Talk.Pass(id, fn)    an offered quest Space should pass by, without a word (ShyQuest: off your guide, or
--                            one your settings leave out, gray among them). fn(questID) is asked as a list is
--                            drawn and answers true to pass it: its row is quiet and still there to click, and
--                            Space leads another, else says Goodbye. A line asked for (Want) isn't held back by it.
--   Shy.Talk.Shell(win)      the make of the talk's window on a window of your addon's (see "The shell"); its
--                            measures are Shy.Talk.WIN
--   Shy.Talk.Yield()         your window takes the talk's place (a vendor's goods): the talk's window is gone at
--                            once and where it stood is answered (left, top, width, height), nil while none is up
--
-- Voices (Shy.Voice): with the voice addon installed, the speaker's recorded line plays as the page comes
-- (that addon finds and plays it from the game's events, and keeps the NPC's own greeting from talking
-- over it), and the stage shows it in its own words (ui.Voice): the word being heard lit in the accent at
-- full strength (Voice.Ink), the words typed out as the voice reaches them (as that addon's settings ask), the pages
-- turning with the voice (only forward, only for a line begun since this page came, never back onto a page
-- you went back from), the seal's light breathing, and a key at the foot's right end to stop the voice or
-- play it again. A line is over once its page is: an answer of yours stops it there and then (Mine), as does
-- the talk ending (you walk away or leave), and the page left behind never has its line begun late either
-- (Voice.Hush with its words). Reading on by yourself leaves the voice where it is (a recording plays from
-- its start only, so it can't be moved on to your page): it reaches you. A talk the dialog never stood in
-- for (an instant turn-in) keeps its voice. A quest page whose line you have heard is not read
-- again by itself: the voice's key stands ready to play it (Voice.lua). A quest page no voice pack has says
-- so there instead ("No voice yet", ui.Missing), with a key to send its text to be voiced where the voice
-- addon takes it. Space, Backspace and the pips turn the pages as ever.
--
-- The game's QuestFrame and GossipFrame are reparented to a frame that is never shown (the attic), and
-- only while neither is shown. Their own event code still opens and closes them, so IsShown answers, the
-- panel manager and Esc keep working, and their OnShow / OnHide never run. Of what those did, ending the
-- talk is done here (CloseQuest, C_GossipInfo.CloseGossip) when the player leaves it. The game's panels
-- under QuestFrame are put away before it goes home: up here none of them ever hid the others. While it is
-- up there QuestFrame hears no QUEST_ITEM_UPDATE: it would lay its rewards out with no layout to go by.
--
-- A page is shown a frame after it came, and only while the game's window for it is open (the game may
-- answer a page itself, or decline to open its window) and nobody has answered it meanwhile: picking,
-- accepting, handing in and closing are post-hooked, so another addon acting on the page (ShyQuest's
-- instant turn-in, a gossip skipper) is noticed and the dialog never flashes. Whatever is left unanswered
-- for PACE.wait seconds is shown after all. Choosing another kind of quest text ends a talk in progress and
-- gives the windows back the moment they are closed.
--
-- The head: a character model takes its unit only while it is shown and drops it when hidden unless told
-- to keep it, so the model is asked once the dialog is up (and again whenever it shows), keeps its model
-- while hidden, and is never hidden itself: a speaker with no head (a notice, a book) gets an emblem over
-- an empty model. A quest page's speaker is "questnpc", a gossip page's "npc"; either stands in for the other.
-- A model can't be masked, and is drawn over every texture of its own strata, so the window it stands
-- in is its own square, framed in steel.
--
-- Motion is light, and never in the way: the stage comes up in under a second with a gleam running once
-- along its line, the seal and then the plaque fade in, the words come with a soft fading front, the seal's
-- light breathes while they are said and settles after, the answers arrive in a short cascade once the
-- first page is read. Any key or click finishes what is moving at once. Nothing runs a frame while still.

local Shy = Shy
local UI, Theme, I = Shy.UI, Shy.Theme, Shy.Immersion
local C = UI.colors
local max, min = math.max, math.min
local MEDIA = Shy.MEDIA

local Talk = {}
Shy.Talk = Talk

-- The stage, in units (the Talk art is drawn to these numbers).
local R = 112                -- the seal's radius: the place the speaker stands, its middle on the line
local RIM = 7                -- the name stands this far inside the seal's right edge
local LINE = R + 2           -- the stage line, from the box's top: the seal's centre stands 2 above it
-- The wash: it fades in `up` over the line and is full `down` under it; the darker band under the line (`shade`), the
-- line's light (`light`) and its light on the world and the stage (`glowUp`, `glowDown`); the world darkening toward
-- the line (`vignette`); the accent behind the head (`halo`).
local STAGE = { up = 90, down = 110, shade = 32, light = 16, glowUp = 40, glowDown = 24, vignette = 260, halo = 1.5 * R }
-- The figure: its frame from this far left of the dialog to `clear` short of the name, this tall over the line (the
-- body cut there); the glow behind the head this high over the seal's middle, held this soft.
local FIGURE = { left = -70, clear = 4, tall = 300, headY = 145, glow = 0.35 }
local NAME_X = 2 * R - RIM + 2   -- the plaque's start, past the figure's frame (a model draws over any texture of its strata)
local NAME_Y = LINE + 1
local PLAQUE_H = 24
local PLAQUE_END = PLAQUE_H * 16 / 36
local RING = 28              -- the ring at the plaque's head
local TEXT_X = NAME_X + 12
local TEXT_W = 640
-- The words and what stands under them, top down (one table: the file is at the game's 200 locals):
--   top    the words, this far under the plaque (it stands on the line, PLAQUE_H tall)
--   least  their height at the least: two lines
--   clear  Space's key (KEY.h tall) this far under their last line, the pips and the chevrons on its row: as
--          much air under the words as over them
--   rule   the hairline, this far under that row's middle
--   body   the answers, this far under it
local SPEECH = { top = 22, least = 47, clear = 13, rule = 16, body = 24 }
-- The window (quest text in a window: see "The window"): its made and least size, the band under its header (the
-- speaker's face and what the page is about), the foot holding its buttons, the room round the words, the face's
-- square and the model's zoom on it, the ring with the page's mark, a pill's height and gap.
local WIN = { w = 470, h = 600, least = { 380, 420 }, band = 82, face = 58, foot = 38, pad = 14, top = 16, bar = 14,
	zoom = 0.9, ring = 22, pill = 18, pillGap = 6, button = 12, between = 8,
	-- The page the words stand on: the words this far in from its sides; it reaches this far over them and under the
	-- controls' row; the answers stand this far under it; its feathered edge.
	inset = 14, over = 10, under = 8, after = 14, feather = 22,
	-- The foot's buttons: their height and words, the quiet one's room round its words, the voice's key.
	key = 22, word = 12, quiet = 10, voice = 22,
	-- The quest's words (the speech and its paragraphs among the answers), before the quest text size setting scales them.
	text = 13 }
local TEXT_Y = NAME_Y + PLAQUE_H / 2 + SPEECH.top
local PIP = 12               -- pips, that far apart
local PIPS = 8
local ROW_H = 30             -- a row; the buttons stand 8 under the last
-- A key: its cap (Space's is as wide as its word and pad), its font, and where a row's mark stands past
-- it (the words 13 past the mark).
-- Space's cap beside the buttons stands at their height, its word at hintFont with hintPad of room.
local KEY = { w = 20, h = 18, pad = 12, font = 11, mark = 32, hintFont = 12, hintPad = 24 }
local SLICE = UI.KEY_SLICE   -- the edge and the face of a keyed piece's art (TalkButton, TalkFace)
local TILE_H, ICON = 36, 36
local TILE_ROW = TILE_H + 18 -- offered rewards' rows
local TILE_GAP, PICK_GAP = 250, 300    -- rewards two across: offered, and to choose from
local PICK_H, PICK_ROW = 44, 52        -- a reward to choose: its height (the slot 4 inside), and its rows
local PICK_IN = (PICK_H - ICON) / 2
local AFTER_PICK, AFTER_TILE = 16, 12  -- from the last row's slot to what comes next
local GAINS_H = 28           -- the money and experience line, to the buttons
local BUTTON_H = 24
local WIDTH = TEXT_X + TEXT_W
local ZOOM = 0.55            -- the model's portrait zoom: head and chest
local TURN = 0.3             -- radians the head is turned toward the words

-- The pace of the words and of the window: characters, seconds, units.
local PACE = {
	page = 220,  -- most characters on a page of speech
	cps = 60,
	spread = 36,  -- characters read out a second, and the width of the fading front
	whole = 4096,  -- a fading front past the end of any page
	wait = 3,  -- seconds an answer asked for by someone else may take
	look = 0.25,  -- seconds between looks while ShyQuest waits for the game
	linger = 0.2,  -- seconds a closed page waits for the next before the dialog goes
	answer = 1,  -- seconds clicks wait after one of ours, for the game's answer
	enter = 0.6,  -- the entrance
	leave = 0.2,  -- the exit
	cascade = 0.2,
	stagger = 0.06,  -- an answer arriving, and the gap to the next
	lift = 10,  -- units an answer rises as it arrives
	breath = 2.4,  -- seconds a breath of the seal's light takes while words are said
	light = 0.85,
	lightLow = 0.75,
	lightSpeak = 0.25,  -- the glow behind the head at rest, and its breath
	flash = 0.4,  -- seconds the light brightens as a page opens
}

local DIGITS = {}
for i = 1, 9 do
	DIGITS[tostring(i)] = i
	DIGITS["NUMPAD" .. i] = i
end
local PAGES = { gossip = true, greeting = true, detail = true, progress = true, reward = true }
-- What an option opens, by the game's icon for it (the files under Interface\GossipFrame), and the glyph
-- its row wears for that.
local OPTIONS = {
	kind = {
		[132053] = "talk", [1019848] = "talk",   -- gossip, chat bubble
		[132060] = "vendor", [528409] = "auction",
		[132058] = "train", [132059] = "unlearn",
		[132057] = "fly",                        -- flight master
		[132052] = "inn",                        -- innkeeper
		[132050] = "bank",
		[132051] = "battle",                     -- battlemaster
		[132055] = "petition",
		[132056] = "tabard", [132054] = "heal",
	},
	glyph = { talk = "talk", vendor = "coin", auction = "coin", train = "book", unlearn = "book", fly = "fly",
		inn = "home", bank = "bag", battle = "kill", petition = "note", tabard = "star", heal = "star" },
	-- Where a guard can point you (a page of directions): each place by its words (lowercased, the first match
	-- wins) and its mark: the minimap's own tracking mark (a name), or the game's icon for it (an "Icons\\" path,
	-- worn round as the tracking marks are). A trade (a trainer's list) wears its own icon; a class's name is a trainer.
	place = {
		{ "alchemy", "Icons\\Trade_Alchemy" }, { "blacksmith", "Icons\\Trade_BlackSmithing" },
		{ "cooking", "Icons\\INV_Misc_Food_15" }, { "enchant", "Icons\\Trade_Engraving" },
		{ "engineer", "Icons\\Trade_Engineering" }, { "first aid", "Icons\\Spell_Holy_SealOfSacrifice" },
		{ "fishing", "Icons\\Trade_Fishing" }, { "herbalis", "Icons\\Trade_Herbalism" },
		{ "leatherwork", "Icons\\Trade_LeatherWorking" }, { "mining", "Icons\\Trade_Mining" },
		{ "skinning", "Icons\\INV_Misc_Pelt_Wolf_01" }, { "tailor", "Icons\\Trade_Tailoring" },
		{ "guild", "Icons\\INV_Shirt_GuildTabard_01" }, { "tram", "Icons\\Ability_Mount_MechaStrider" },
		{ "auction", "Auctioneer" }, { "bank", "Banker" }, { "%f[%a]inn", "Innkeeper" }, { "mail", "Mailbox" },
		{ "stable", "StableMaster" }, { "gryphon", "FlightMaster" }, { "wind rider", "FlightMaster" },
		{ "hippogryph", "FlightMaster" }, { "bat handler", "FlightMaster" }, { "flight", "FlightMaster" },
		{ "battlemaster", "BattleMaster" }, { "barber", "Barbershop" }, { "profession", "Profession" },
		{ "weapon", "Class" }, { "class", "Class" }, { "trainer", "Class" },
	},
	tracking = "Interface\\Minimap\\Tracking\\",
	icons = "Interface\\",
	round = "Interface\\CharacterFrame\\TempPortraitAlphaMask",   -- an icon worn round
	-- A page of directions: places two across, each a tile this tall with this gap, its mark this size, its key
	-- this far in; at least `least` places, and half of them known, make one.
	tile = { h = 40, gap = 8, icon = 22, inset = 8, least = 3 },
}

-- The tracking mark for a place a guard can point you to, by the option's words; nil for one not known.
function OPTIONS.Place(name)
	if issecretvalue(name) or type(name) ~= "string" then return nil end
	local words = name:lower()
	for _, place in ipairs(OPTIONS.place) do
		if words:find(place[1]) then
			return (place[2]:find("^Icons\\") and OPTIONS.icons or OPTIONS.tracking) .. place[2]
		end
	end
	local classes = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
	if type(classes) == "table" then
		for _, class in pairs(classes) do
			if words == class:lower() then return OPTIONS.tracking .. "Class" end
		end
	end
end

-- A page of directions: options only, every one a plain line, enough of them and half of them places known. Returns
-- each option's mark (false for a place not known), or nil for any other page.
function OPTIONS.Directions(options)
	if #options < OPTIONS.tile.least then return nil end
	local marks, known = {}, 0
	for i, option in ipairs(options) do
		local icon = option.overrideIconID or option.icon
		if issecretvalue(icon) or (icon and OPTIONS.kind[icon] and OPTIONS.kind[icon] ~= "talk") then return nil end
		marks[i] = OPTIONS.Place(option.name) or false
		if marks[i] then known = known + 1 end
	end
	if known * 2 < #options then return nil end
	return marks
end
local INK = { grey = { 0.30, 0.31, 0.35 }, black = { 0, 0, 0 }, white = { 1, 1, 1 } }

local s = {
	want = false, on = false,
	kind = nil,        -- the page the game is on
	gen = 0,           -- counts pages and closes
	pageAt = 0,        -- when the last page (or close) came
	heardAt = nil,     -- when someone else last answered the game
	mine = false,      -- one of our own calls is running
	gossips = 0,       -- counts gossip pages, dialog or not
	gossipAt = 0,      -- when the last came
	picked = nil,      -- the gossip page a line asked for was looked for on
	questAt = nil,     -- when a quest's page last came (Ask.Quested)
	overAt = nil,      -- when the game's windows were last all shut after a talk
	open = false,      -- the dialog is up
	leaving = nil,     -- the dialog is on its way out
	shownGen = nil,    -- gen of what the dialog shows
	busy = nil,        -- when we last asked the game something
	toQuest = false,   -- the last row picked was a quest
	pages = {}, page = 1, progress = 0, length = 0, revealing = false, breath = 0,
	arrived = false,   -- the answers are in
	lead = nil,        -- the row Space gives
	choice = 0, choices = 0,
	suggested = false, -- the choice standing is the suggestion, not the player's
	why = nil,         -- the word on the suggested reward
	confirming = false,   -- the reward page asks about the suggestion
	rows = 0, tiles = 0, chips = 0, lines = 0, caps = 0, goals = 0,
	directions = false,   -- the gossip page is a guard's directions: its places stand as tiles
	voiced = nil,      -- the furthest page the voice turned to on this page's talk
	voicing = nil,     -- the voice is being shown on the words (ui.Voice)
	said = nil,       -- the words of the page shown, whole (nil where withheld)
	voiceText = nil,   -- the words as the voice last marked them, nil for the page as it is
	missing = false,   -- no voice pack has this quest page's line (ui.Missing)
	contribute = false,   -- ... and its text can be sent to be voiced
	make = "stage",    -- how the talk is worn: "stage" (immersive) or "window" (Talk.Window)
	windowed = false,  -- quest text that isn't immersive stands in a window of ours (Talk.Window)
}
local ui = { keyed = {}, w = TEXT_W }   -- keyed: every key, to dress again as the theme changes; w: the words' column
local W = {}   -- the window (see "The window")
local attic
local home = {}

local function Window(kind)
	return kind == "gossip" and GossipFrame or QuestFrame
end

local function Blizzard()
	return { QuestFrame, GossipFrame }
end

local function AnyShown()
	return QuestFrame:IsShown() or GossipFrame:IsShown()
end

-- Text the game may withhold goes to a setter as it is.
local function Say(fs, text)
	if issecretvalue(text) or text then fs:SetText(text) else fs:SetText("") end
end

local function Readable(text)
	return text ~= nil and not issecretvalue(text)
end

-- A flag the game may withhold: a withheld one counts as no.
local function Yes(flag)
	return not issecretvalue(flag) and flag == true
end

local function Ease(k)
	k = max(0, min(1, k))
	return 1 - (1 - k) ^ 3
end

-- Pages of speech: paragraphs together while they fit, a long one by sentences. Withheld text is one page.

local function Sentences(para)
	local list, from = {}, 1
	while from <= #para do
		local _, stop = para:find("[%.!%?]+[\"')]*%s+", from)
		if not stop then
			list[#list + 1] = para:sub(from)
			break
		end
		list[#list + 1] = para:sub(from, stop)
		from = stop + 1
	end
	return list
end

local function Pages(text)
	local out = {}
	if text == nil then return out end
	if issecretvalue(text) then
		out[1] = text
		return out
	end
	local page = ""
	local function Put(piece, joint)
		piece = piece:gsub("^%s+", ""):gsub("%s+$", "")
		if piece == "" then return end
		if page ~= "" and #page + #joint + #piece > PACE.page then
			out[#out + 1] = page
			page = ""
		end
		page = page == "" and piece or (page .. joint .. piece)
	end
	for para in (text:gsub("\r", "") .. "\n"):gmatch("(.-)\n") do
		if para:find("%S") then
			if #para <= PACE.page then
				Put(para, "\n\n")
			else
				for i, sentence in ipairs(Sentences(para)) do Put(sentence, i == 1 and "\n\n" or " ") end
			end
		end
	end
	if page ~= "" then out[#out + 1] = page end
	return out
end

-- Our own calls into the game; the post-hooks below tell them from anyone else's. Each is an answer of yours:
-- what the page was saying is over, whatever page comes of it.
local function Mine(fn, ...)
	if s.open and s.talkAt then Shy.Voice.Hush(s.talkAt, s.said) end
	s.mine, s.busy = true, GetTime()
	local ok, err = pcall(fn, ...)
	s.mine = false
	if not ok then geterrorhandler()(err) end
end

local function Busy()
	return s.busy ~= nil and GetTime() - s.busy < PACE.answer
end

-- Motion: tweens run on one frame's OnUpdate, which is cleared the moment none is left.

local tweens = {}
local animator = CreateFrame("Frame")

local function Run(list)
	for _, tween in ipairs(list) do
		tween.fn(1)
		if tween.done then tween.done() end
	end
end

local function Step(_, dt)
	local over = {}
	for key, tween in pairs(tweens) do
		tween.t = tween.t + dt
		if tween.t >= tween.dur then
			tweens[key] = nil
			over[#over + 1] = tween
		else
			tween.fn(tween.t / tween.dur)
		end
	end
	Run(over)
	if not next(tweens) then animator:SetScript("OnUpdate", nil) end
end

local function Tween(key, dur, fn, done)
	tweens[key] = { t = 0, dur = dur, fn = fn, done = done }
	fn(0)
	animator:SetScript("OnUpdate", Step)
end

-- Finishes one tween, or every one: what a key or a click does to anything still moving.
local function Settle(key)
	local over = {}
	for k, tween in pairs(tweens) do
		if not key or k == key then
			tweens[k] = nil
			over[#over + 1] = tween
		end
	end
	Run(over)
	if not next(tweens) then animator:SetScript("OnUpdate", nil) end
end

-- Pieces

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

-- A flat color that runs out to the right (or down): kept in step with the theme by Repaint.
local washes = {}

local function PaintWash(t, def)
	local c = def.color
	local r, g, b
	if type(c) == "function" then r, g, b = c() else r, g, b = c[1], c[2], c[3] end
	t:SetGradient(def.vertical and "VERTICAL" or "HORIZONTAL", CreateColor(r, g, b, def.alpha), CreateColor(r, g, b, 0))
end

local function Wash(parent, layer, sub, color, alpha, vertical)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
	t:SetColorTexture(1, 1, 1, 1)
	washes[t] = { color = color, alpha = alpha, vertical = vertical }
	PaintWash(t, washes[t])
	return t
end

local function Repaint()
	for t, def in pairs(washes) do PaintWash(t, def) end
	for k in pairs(ui.keyed) do
		if k.state then k:Look(k.state) end
	end
end

-- One of the dialog's sliced pieces over the whole of its frame: a keyed piece's face and edge.
local function Sliced(parent, file, layer, color, sub, alpha)
	local t = Art(parent, file, layer, sub, color, alpha)
	t:SetTextureSliceMargins(SLICE, SLICE, SLICE, SLICE)
	t:SetAllPoints()
	return t
end

-- What every keyed piece (a key, a button) is made of: the family's (UI.Keyed), with the accent as light
-- along its top when it is Space's or the primary.
local Keyed = UI.Keyed

-- (Its words wear the text effect, as the kit's do: they stand on the look's own housings.)
local function Shadowed(fs)
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	return Shy.Theme.Wear(fs)
end

-- Lilita One's line: ascender 0.923 and descender 0.220 of its size, capitals and digits 0.705 tall. A string
-- is centred on its capitals: its measured line box, moved by this share of its height.
local CAP_LIFT = ((0.923 - 0.220) - 0.705) / 2 / (0.923 + 0.220)

local function Centre(fs, frame)
	local tall = fs:GetStringHeight()
	if issecretvalue(tall) or not tall then tall = 0 end
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", frame, "CENTER", 0, tall * CAP_LIFT)
end

-- A key: a keyed piece holding its digit or word. At rest graphite in a steel edge, the word in the text
-- ink (the dim ink, and fainter, on a faint row); "over" (its row under the mouse) the hot edge and the
-- head ink; "lit" (chosen, or Space's, which always stands lit) a face in the accent (Look), the hot edge
-- and light along its top.
local function Key(parent, word, wide)
	local k = CreateFrame("Frame", nil, parent)
	k:SetSize(wide or KEY.w, KEY.h)
	Keyed(k, KEY.h)
	k.text = Shadowed(k:CreateFontString(nil, "OVERLAY"))
	UI.TitleFace(k.text, KEY.font)
	UI.Ink(k.text, C.text)
	function k:Set(text)
		self.text:SetText(text)
		Centre(self.text, self)
	end
	-- As wide as its word and a little room.
	function k:Fit()
		local wide = self.text:GetStringWidth()
		if issecretvalue(wide) or not wide then wide = 30 end
		self:SetWidth(math.floor(wide + (self.pad or KEY.pad) + 0.5))
	end
	-- Painted as the buttons are, so a cap reads as one of them in every look (a look's corner marks crowd a cap
	-- this small): lit, the primary button's make and its very face, the accent itself (a gradient's color where it
	-- stands), so its word takes the same ink as the button's: on a mid tone like rose, where white and black read
	-- about alike, a face of its own could tip the other way. Dressed again as the theme changes (Repaint), so a new accent decides again.
	function k:Look(state)
		self.state = state
		local lit, over = state == "lit", state == "over"
		self.face = (lit and Theme.Accent) or (over and C.bgHot) or C.bg
		UI.Tint(self.fill, self.face, (lit and 1) or 0.94)
		UI.Tint(self.edge, (lit or over) and C.hot or Theme.skin.metal)
		self.light:SetAlpha(lit and 0.9 or 0)
		-- Its word in the ink and shadow its face asks for, where it stands (UI.FaceInk).
		UI.FaceInk(self.text, self, self.face, ((lit or over) and C.head) or (self.faint and C.dim) or C.text)
	end
	-- Its size: a row's cap, or beside the buttons as tall as they are, its word at theirs.
	function k:Size(tall, font, pad)
		self:SetHeight(tall)
		UI.TitleFace(self.text, font)
		self.pad = pad
		self:Fit()
		Centre(self.text, self)
	end
	-- On a faint row (a quest not yet yours to take), the key fades with its words.
	function k:Faint(faint)
		self.faint = faint == true
		self:SetAlpha(faint and 0.55 or 1)
	end
	ui.keyed[k] = true
	k:Set(word)
	return k
end

-- The game's tooltip over the quiet screen, beside the slot: solid while it is read, the screen left as it is.
local function TipOn(self)
	if not self.tip then return end
	GameTooltip:SetOwner(self.cell or self, "ANCHOR_RIGHT")
	self.tip(GameTooltip)
	GameTooltip:Show()
	I.Solid(GameTooltip)
	self.peeking = true
end

local function TipOff(self)
	if not self.peeking then return end
	self.peeking = false
	GameTooltip:Hide()
end

local Arrive   -- the answers come in

local function Pressed(button, fn)
	button:SetScript("OnClick", function(self)
		if self.off or Busy() then return end
		fn(self)
	end)
end

-- A row's or a pick's two states, each its own channel. Under the mouse it is quiet: a faint wash of the
-- accent, the key's edge in the hot shade and its word brighter, a pick's slot rim in the hot shade.
-- Chosen (a pick), or the answer given (a row): the accent's wash with light along its foot, the key lit
-- and a pick's slot rim in the accent. Chosen wins. Space's cap on the lead row always stands lit. now: no
-- fade (a page laid out, a frame hidden).
local function State(frame, now)
	local on = frame.on == true
	local over = frame.over == true and not on
	local toOn, toOver = on and 1 or 0, over and 1 or 0
	if now then
		Settle(frame)
		frame.glow:SetAlpha(toOn)
		frame.hover:SetAlpha(toOver)
	else
		local fromOn, fromOver = frame.glow:GetAlpha(), frame.hover:GetAlpha()
		Tween(frame, 0.12, function(k)
			local e = Ease(k)
			frame.glow:SetAlpha(fromOn + (toOn - fromOn) * e)
			frame.hover:SetAlpha(fromOver + (toOver - fromOver) * e)
		end)
	end
	if frame.key then frame.key:Look((on and "lit") or (frame.over and "over") or "idle") end
	if frame.cap then frame.cap:Look("lit") end
	if frame.glyph then UI.Tint(frame.glyph, (on or frame.over) and C.hot or C.dim) end
	if frame.rimOn then
		frame.rimOver:SetShown(over)
		frame.rimOn:SetShown(on)
	end
end

local function Over(frame, on)
	frame.over = on
	State(frame)
end

local function Watched(frame)
	frame:HookScript("OnEnter", function(self) Over(self, true) end)
	frame:HookScript("OnLeave", function(self) Over(self, false) end)
	frame:HookScript("OnHide", function(self)
		self.over = false
		State(self, true)
	end)
end

-- A row's two washes of the accent, fading to the right: a full one with light along its foot (chosen),
-- and a faint one (under the mouse), across the frame's width. pad: how far they reach over and under the row.
local function Washes(frame, pad)
	local function Layer()
		local f = CreateFrame("Frame", nil, frame)
		f:SetPoint("TOPLEFT", -10, pad)
		f:SetPoint("BOTTOMRIGHT", 0, -pad)
		f:SetFrameLevel(frame:GetFrameLevel())
		f:SetAlpha(0)
		return f
	end
	local glow = Layer()
	Wash(glow, "BACKGROUND", 0, Theme.Accent, 0.22):SetAllPoints()
	local foot = Light(glow, "HoverLight", "BORDER", 0, Theme.light)
	foot:SetPoint("BOTTOMLEFT", 2, -6)
	foot:SetPoint("BOTTOMRIGHT", -40, -6)
	foot:SetHeight(9)
	foot:SetAlpha(0.9)
	local hover = Layer()
	Wash(hover, "BACKGROUND", 0, Theme.Accent, 0.09):SetAllPoints()
	frame.glow, frame.hover = glow, hover
end

-- A key in a row or a pick: a click on it is the row's. (No hover of its own: a number on a row says what it does.)
local function OwnKey(owner)
	local k = Key(owner, "")
	k.owned = true
	k:SetScript("OnEnter", function() Over(owner, true) end)
	k:SetScript("OnLeave", function() Over(owner, false) end)
	k:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self:IsMouseOver() then owner:Click() end
	end)
	return k
end

-- Mouse on a row or a pick, and its keys.
local function Touchable(frame, on)
	frame:EnableMouse(on)
	if frame.key and frame.key.owned then frame.key:EnableMouse(on) end
	if frame.cap then frame.cap:EnableMouse(on) end
end

-- A button: a keyed piece at a word's size, graphite in a steel edge; the primary one in the accent's deep
-- shade, its edge in the hot shade and light along its top. Under the mouse the edge goes hot, the words
-- brighter and a wash of the accent comes over the face. Its hover says what it does, and its key when
-- Space gives it.
local function NewButton(parent, index)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(110, BUTTON_H)
	Keyed(b, BUTTON_H)
	b.glow = Sliced(b, "TalkFace", "ARTWORK", Theme.Accent, 1)
	b.glow:SetAlpha(0)
	b.text = Shadowed(b:CreateFontString(nil, "OVERLAY"))
	UI.TitleFace(b.text, 13)
	Centre(b.text, b)
	b.index = index
	b:SetScript("OnEnter", function(self)
		if self.off then return end
		Tween(self, 0.12, function(k) self.glow:SetAlpha(0.14 * Ease(k)) end)
		UI.Tint(self.edge, C.hot)
		if not self.primary then UI.FaceInk(self.text, self, self.face, C.head) end
	end)
	b:SetScript("OnLeave", function(self)
		local from = self.glow:GetAlpha()
		Tween(self, 0.12, function(k) self.glow:SetAlpha(from * (1 - Ease(k))) end)
		UI.Tint(self.edge, self.primary and C.hot or Theme.skin.metal)
		UI.FaceInk(self.text, self, self.face, self.primary and C.head or C.text)
	end)
	Pressed(b, function(self)
		PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
		self.act()
	end)
	-- Its hover only where it says what can't be seen: why it waits, or that it asks first.
	UI.Help(b, function(self)
		if not (self.off or self.explain) then return nil end
		return self.text:GetText() .. (ui.space == self and " (Space)" or "")
	end, function(self) return self.say end)
	return b
end

-- Where an answer stands; while arriving it is lifted a little and faded.
local function Place(frame, lift)
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", ui.body, "TOPLEFT", frame.ax, -(frame.ay + (lift or 0)))
end

-- One of the answers: unseen, and not under the mouse, until they come in.
local function Arriving(frame, mouse)
	ui.arrivals[#ui.arrivals + 1] = frame
	frame:SetAlpha(s.arrived and (frame.dim or 1) or 0)
	frame.mouse = mouse
	if mouse then Touchable(frame, s.arrived) end
end

local function Stand(frame, x, y, mouse)
	frame.ax, frame.ay = x, y
	Place(frame)
	frame:Show()
	Arriving(frame, mouse)
end

-- The foot's buttons; the first is the page's answer. Space gives it once the words are read, or, where
-- it can't be given (off, or never Space's), the second if that one takes Space (Goodbye): pressed
-- enough, Space always ends the talk.
local function Buttons(first, second)
	local any, x = false, 0
	ui.space = nil
	for i, def in ipairs({ first or false, second or false }) do
		local b = ui.buttons[i]
		b:SetShown(def ~= false)
		if def then
			any = true
			UI.TitleFace(b.text, s.make == "window" and WIN.word or 13)
			b:SetHeight(s.make == "window" and WIN.key or BUTTON_H)
			b.text:SetText(def.text)
			b.act, b.off, b.explain = def.act, def.off == true, def.explain == true
			b.space = def.space == true and not b.off and ui.space == nil and (i == 1 or not s.lead)
			if b.space then ui.space = b end
			b.say = b.off and def.wait or def.say
			b.dim = b.off and 0.45 or 1
			b.primary = i == 1
			local wide = b.text:GetStringWidth()
			if issecretvalue(wide) then wide = 60 end
			-- Its width, and the least it may give way to in a narrow window (W.Foot): its words and a little room.
			b.full, b.least = max(110, wide + 34), math.ceil(wide + 24)
			b:SetWidth(b.full)
			Centre(b.text, b)
			b.face = b.primary and Theme.Accent or C.bg
			UI.Tint(b.fill, b.face, b.primary and 1 or 0.94)
			UI.Tint(b.edge, b.primary and C.hot or Theme.skin.metal)
			b.light:SetAlpha(b.primary and 0.9 or 0)
			if s.make == "window" then
				-- In the window's foot, laid there by W.Foot; they come in with the answers.
				b.ax = nil
				b:Show()
				Arriving(b, true)
			else
				Stand(b, x, ui.y, true)
			end
			-- Its word in the ink and shadow its face asks for, once it stands where it will (UI.FaceInk).
			UI.FaceInk(b.text, b, b.face, b.primary and C.head or C.text)
			x = x + b:GetWidth() + 10
		end
	end
	if any and s.make ~= "window" then ui.y = ui.y + BUTTON_H end
	return any
end

-- A caption in small capitals.
local function Caption(text)
	s.caps = s.caps + 1
	local fs = ui.caps[s.caps]
	if not fs then
		fs = Shadowed(ui.body:CreateFontString(nil, "OVERLAY"))
		fs:SetFontObject(UI.TextFont(10))
		UI.Ink(fs, C.dim)
		fs:SetJustifyH("LEFT")
		ui.caps[s.caps] = fs
	end
	fs:SetText(text)
	Stand(fs, 0, ui.y)
	ui.y = ui.y + 16
end

-- The game's words among the answers.
local function Para(text, color, size)
	s.lines = s.lines + 1
	local fs = ui.lines[s.lines]
	if not fs then
		fs = Shadowed(ui.body:CreateFontString(nil, "OVERLAY"))
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		ui.lines[s.lines] = fs
	end
	fs:SetFontObject(UI.TextFont(math.floor((size and size - W.Smaller() or W.Words()) * I.TextSize() + 0.5)))   -- the quest text size picked
	fs:SetSpacing(2)
	UI.Ink(fs, color or C.text)
	fs:SetWidth(ui.w)
	Say(fs, text)
	Stand(fs, 0, ui.y)
	local tall = fs:GetStringHeight()
	if issecretvalue(tall) then tall = 20 end
	ui.y = ui.y + tall + 8
end

-- A quest with a page of its own (a letter, a notice) closes it with a seal and a signature, as the game's
-- window does (QuestInfo_ShowSeal): the signature in the title face at the left, the seal's own art beside it.
-- The seal is the game's picture, drawn as it is; where the quest has neither, nothing stands.
local SIGN = { h = 78, art = 160, inset = 6 }
local function Seal()
	local id = GetQuestID()
	if not id or issecretvalue(id) then return end
	local theme = C_QuestLog.GetQuestDetailsTheme(id)
	if type(theme) ~= "table" or issecretvalue(theme.signature) or issecretvalue(theme.seal) then return end
	local words = theme.signature
	local atlas = theme.seal
	local hasWords = type(words) == "string" and words ~= ""
	local hasArt = type(atlas) == "string" and atlas ~= "" and C_Texture.GetAtlasInfo(atlas) ~= nil
	if not (hasWords or hasArt) then return end
	local sign = ui.sign
	if not sign then
		sign = CreateFrame("Frame", nil, ui.body)
		sign:SetSize(ui.w, SIGN.h)
		sign.text = Shadowed(sign:CreateFontString(nil, "OVERLAY"))
		sign.text:SetFontObject(UI.NameFont(22))
		UI.Ink(sign.text, C.head)
		sign.text:SetPoint("LEFT", 0, -10)
		sign.text:SetWidth(SIGN.art - 12)
		sign.text:SetJustifyH("LEFT")
		sign.text:SetMaxLines(2)
		sign.art = sign:CreateTexture(nil, "ARTWORK")
		sign.art:SetPoint("TOPLEFT", SIGN.art, -SIGN.inset)
		ui.sign = sign
	end
	sign:SetWidth(ui.w)
	sign.text:SetText(hasWords and words or "")
	sign.art:SetShown(hasArt)
	if hasArt then sign.art:SetAtlas(atlas, true) end
	ui.y = ui.y + 4
	Stand(sign, 0, ui.y)
	ui.y = ui.y + SIGN.h
end

-- An objective: its words, and how far along at the right.
local function Goal(text, have, need)
	s.goals = s.goals + 1
	local goal = ui.goals[s.goals]
	if not goal then
		goal = CreateFrame("Frame", nil, ui.body)
		goal:SetSize(ui.w, 20)
		goal.text = Shadowed(goal:CreateFontString(nil, "OVERLAY"))
		goal.text:SetFontObject(UI.TextFont(14))
		UI.Ink(goal.text, C.text)
		goal.text:SetPoint("TOPLEFT", 0, -2)
		goal.text:SetJustifyH("LEFT")
		goal.text:SetWordWrap(true)
		goal.text:SetMaxLines(2)
		goal.count = Shadowed(goal:CreateFontString(nil, "OVERLAY"))
		goal.count:SetFontObject(UI.TextFont(14))
		UI.Ink(goal.count, C.dim)
		goal.count:SetPoint("TOPLEFT", goal.text, "TOPRIGHT", 16, 0)
		ui.goals[s.goals] = goal
	end
	Say(goal.text, text)
	-- The words hug their count; one too long for the column (its count kept at the right) wraps to a second line.
	goal.text:SetWidth(0)
	local wide = goal.text:GetStringWidth()
	if issecretvalue(wide) or not wide then wide = 0 end
	goal:SetWidth(ui.w)
	local room = ui.w - 70
	if wide > room then goal.text:SetWidth(room) end
	if issecretvalue(have) or issecretvalue(need) then
		goal.count:SetText(("%s/%s"):format(have, need))
	elseif need and need > 0 then
		goal.count:SetText(("%d/%d"):format(have or 0, need))
	else
		goal.count:SetText("")
	end
	local tall = goal.text:GetStringHeight()
	if issecretvalue(tall) or not tall or tall < 16 then tall = 16 end
	goal:SetHeight(max(20, tall + 4))
	Stand(goal, 0, ui.y)
	ui.y = ui.y + goal:GetHeight()
end

-- What the game lists for a quest, when it does (a quest already yours).
local function Goals()
	local list = C_QuestLog.GetQuestObjectives(GetQuestID())
	if not list then return end
	for _, goal in ipairs(list) do
		if issecretvalue(goal.text) or (goal.text and goal.text ~= "") then
			Goal(goal.text, goal.numFulfilled, goal.numRequired)
		end
	end
end

-- A row: a key, a mark, the words, and on the lead row Space's cap at its right end. mark: "!" offered,
-- "?" ready, "-" in progress, "talk" an option (with the glyph of what it opens, by the game's icon).
local function Row(def)
	s.rows = s.rows + 1
	local i = s.rows
	local row = ui.rows[i]
	if not row then
		row = CreateFrame("Button", nil, ui.body)
		Washes(row, 2)
		row.key = OwnKey(row)
		row.key:SetPoint("LEFT", 0, 0)
		row.cap = OwnKey(row)
		row.cap:Set("Space")
		row.cap:Fit()
		row.cap:SetPoint("RIGHT", -2, 0)
		row.cap:Look("lit")
		row.mark = Shadowed(row:CreateFontString(nil, "OVERLAY"))
		UI.TitleFace(row.mark, 16)
		row.mark:SetPoint("CENTER", row, "LEFT", KEY.mark, -1)
		row.glyph = row:CreateTexture(nil, "OVERLAY")
		row.glyph:SetSize(15, 15)
		row.glyph:SetPoint("CENTER", row, "LEFT", KEY.mark, 0)
		row.label = Shadowed(row:CreateFontString(nil, "OVERLAY"))
		row.label:SetFontObject(UI.TextFont(15))
		row.label:SetPoint("LEFT", KEY.mark + 13, -0.6)
		row.label:SetWidth(ui.w - KEY.mark - 17)
		row.label:SetJustifyH("LEFT")
		row.label:SetWordWrap(true)
		row.label:SetMaxLines(2)
		-- Why a line is asked for (an addon's words), at the row's right end.
		row.why = Shadowed(row:CreateFontString(nil, "OVERLAY"))
		row.why:SetFontObject(UI.TextFont(12))
		row.why:SetJustifyH("RIGHT")
		-- A quest an addon wouldn't have you take (Talk.Note): a skip glyph before its words.
		row.offGlyph = row:CreateTexture(nil, "OVERLAY")
		row.offGlyph:SetSize(12, 12)
		row.offGlyph:SetPoint("RIGHT", row.why, "LEFT", -4, 0)
		local skip = UI.MenuGlyph("skip")[1]
		row.offGlyph:SetTexture(skip[1])
		row.offGlyph:SetTexCoord(unpack(skip.coords))
		-- The hairline under the row, from past its key, fading to the right.
		row.rule = Wash(row, "BACKGROUND", 1, INK.white, 0.10)
		row.rule:SetPoint("BOTTOMLEFT", KEY.w + 8, 0)
		row.rule:SetPoint("BOTTOMRIGHT", 0, 0)
		row.rule:SetHeight(1)
		-- As a place's tile: a card a shade off the page, a lip of light along its top and a groove along its foot,
		-- and the place's mark in its own colors (never tinted with the row's state).
		row.card = row:CreateTexture(nil, "BACKGROUND", nil, -2)
		row.card:SetAllPoints()
		row.card:SetColorTexture(1, 1, 1, 0.045)
		row.lip = row:CreateTexture(nil, "BACKGROUND", nil, -1)
		row.lip:SetColorTexture(1, 1, 1, 0.07)
		row.lip:SetPoint("TOPLEFT")
		row.lip:SetPoint("TOPRIGHT")
		row.lip:SetHeight(1)
		row.groove = row:CreateTexture(nil, "BACKGROUND", nil, -1)
		row.groove:SetColorTexture(0, 0, 0, 0.55)
		row.groove:SetPoint("BOTTOMLEFT")
		row.groove:SetPoint("BOTTOMRIGHT")
		row.groove:SetHeight(1)
		row.place = row:CreateTexture(nil, "OVERLAY")
		row.place:SetSize(OPTIONS.tile.icon, OPTIONS.tile.icon)
		-- An icon (a trade's, the guild's) is worn round, as the tracking marks are, its square frame trimmed away.
		row.round = row:CreateMaskTexture()
		row.round:SetTexture(OPTIONS.round, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		row.round:SetAllPoints(row.place)
		row.rounded = false
		-- Its pieces stood as a row (its key, its mark, the words) or as a tile (the place's mark, the words, its key at
		-- the right end, so a tile past the ninth has no gap where a key would be); `at` is where the mark's middle
		-- stands, `from` where the words begin, `keyRoom` what the key takes at the right.
		function row:Lay(tile)
			if self.tiled == tile then return end
			self.tiled = tile
			local t = OPTIONS.tile
			local at = tile and (t.inset + t.icon / 2) or KEY.mark
			self.from = at + (tile and (t.icon / 2 + 10) or 13)
			self.keyRoom = tile and (KEY.w + t.inset + 6) or 0
			self.key:ClearAllPoints()
			if tile then self.key:SetPoint("RIGHT", -t.inset, 0) else self.key:SetPoint("LEFT", 0, 0) end
			self.mark:ClearAllPoints()
			self.mark:SetPoint("CENTER", self, "LEFT", at, -1)
			self.glyph:ClearAllPoints()
			self.glyph:SetPoint("CENTER", self, "LEFT", at, 0)
			self.place:ClearAllPoints()
			self.place:SetPoint("CENTER", self, "LEFT", at, 0)
			self.label:ClearAllPoints()
			self.label:SetPoint("LEFT", self.from, -0.6)
			for _, piece in ipairs({ self.card, self.lip, self.groove }) do piece:SetShown(tile) end
			for _, layer in ipairs({ self.glow, self.hover }) do
				layer:ClearAllPoints()
				if tile then
					layer:SetAllPoints()
				else
					layer:SetPoint("TOPLEFT", -10, 2)
					layer:SetPoint("BOTTOMRIGHT", 0, -2)
				end
			end
		end
		row.tiled = nil
		Watched(row)
		-- The answer given is lit until the game's answer comes (a new page lays the rows out again).
		Pressed(row, function(self)
			PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
			s.toQuest = self.quest
			self.on = true
			State(self)
			local gen = s.gen
			C_Timer.After(PACE.answer, function()
				if s.gen ~= gen or not self.on then return end
				self.on = false
				State(self)
			end)
			self.act()
		end)
		-- A trainer's spell: the game's tooltip, as its own window shows.
		row:HookScript("OnEnter", function(self)
			if not self.spell then return end
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpellByID(self.spell)
			GameTooltip:Show()
			I.Solid(GameTooltip)
			self.peeking = true
		end)
		row:HookScript("OnLeave", TipOff)
		row:HookScript("OnHide", TipOff)
		ui.rows[i] = row
	end
	-- A place a guard can point you to stands as a tile, two across (def.tile: its column); any other answer is a row.
	-- The last of an odd number of places takes its line's whole width, so no line has an empty half.
	local tile = def.tile ~= nil
	local alone = tile and def.last and def.tile == 0
	local wide = (tile and not alone) and math.floor((ui.w - OPTIONS.tile.gap) / 2) or ui.w
	row:Lay(tile)
	row.label:SetFontObject(UI.TextFont((tile and 14 or 15) - W.Smaller()))
	row.key:SetShown(i <= 9)
	row.key:Set(tostring(i))
	local talk = def.mark == "talk"
	row.mark:SetShown(not talk)
	row.mark:SetText(def.mark == "-" and "?" or def.mark)
	-- A faint row (gray, passed by, in progress) is a tad quieter, its gold and its words (Theme.Quiet), never faded out.
	UI.Ink(row.mark, ((def.mark == "-" or def.note) and C.dim) or (def.faint and C.quietAlert) or C.alert)
	-- A known place wears its tracking mark; any other line the glyph of what it opens (a place not known: the way).
	local marked = tile and def.place
	row.place:SetShown(marked and true or false)
	if marked then
		row.place:SetTexture(def.place)
		local icon = def.place:find(OPTIONS.icons .. "Icons\\", 1, true) == 1
		row.place:SetTexCoord(icon and 0.08 or 0, icon and 0.92 or 1, icon and 0.08 or 0, icon and 0.92 or 1)
		if icon ~= row.rounded then
			if icon then row.place:AddMaskTexture(row.round) else row.place:RemoveMaskTexture(row.round) end
			row.rounded = icon
		end
	end
	row.glyph:SetShown(talk and not marked)
	if talk and not marked then
		Shy.Hover.Glyph(row.glyph, tile and "go" or OPTIONS.glyph[OPTIONS.kind[def.icon]] or "talk", 15)
	end
	local faint = def.faint or def.mark == "-"
	UI.Ink(row.label, faint and C.quiet or C.text)
	row.key:Faint(faint)
	Say(row.label, def.text)
	row.lead = def.lead == true
	row.cap:SetShown(row.lead and not (s.revealing or s.page < #s.pages))
	local why = def.why or def.note
	row.why:SetText(why or "")
	row.why:SetShown(why ~= nil)
	UI.Ink(row.why, def.note and C.bad or C.dim, def.note and 0.85 or 1)
	row.offGlyph:SetShown(def.note ~= nil)
	if def.note then UI.Tint(row.offGlyph, C.bad, 0.85) end
	row.why:ClearAllPoints()
	if row.lead then row.why:SetPoint("RIGHT", row.cap, "LEFT", -10, 0) else row.why:SetPoint("RIGHT", -6, 0) end
	local whyWide = why and row.why:GetStringWidth() or 0
	if issecretvalue(whyWide) then whyWide = 80 end
	if def.note then whyWide = whyWide + 16 end
	-- (On a tile that leads, its key stands before Space's cap.)
	if tile then
		row.key:ClearAllPoints()
		if row.lead then row.key:SetPoint("RIGHT", row.cap, "LEFT", -6, 0) else row.key:SetPoint("RIGHT", -OPTIONS.tile.inset, 0) end
	end
	row.label:SetWidth(wide - row.from - 4 - row.keyRoom - (row.lead and (row.cap:GetWidth() + 12) or 0) - (why and (whyWide + 12) or 0))
	row.rule:SetShown(not tile)
	row.kind = def.mark
	row.act, row.spell, row.off, row.quest = def.act, def.spell, def.act == nil, def.mark ~= "talk"
	row.on = false
	State(row, true)
	local tall = row.label:GetStringHeight()
	if issecretvalue(tall) then tall = 18 end
	if tile then
		-- Two to a line: the line goes down after the right one, or after the last.
		local t = OPTIONS.tile
		row:SetSize(wide, max(t.h, tall + 12))
		Stand(row, def.tile * (wide + t.gap), ui.y, true)
		if def.tile == 1 or def.last then ui.y = ui.y + row:GetHeight() + t.gap end
		return
	end
	row:SetSize(ui.w, max(ROW_H, tall + 12))
	Stand(row, 0, ui.y, true)
	ui.y = ui.y + row:GetHeight()
end

local function QualityColor(quality)
	return quality and not issecretvalue(quality) and quality > Enum.ItemQuality.Common
		and ColorManager.GetColorDataForBagItemQuality(quality) or nil
end

-- What ShyGear says of an item, if it is loaded: a word and its color.
local function Verdict(link)
	local gear = Shy.addons.Gear
	if not (link and gear and gear.Judge and gear.MarkFor) then return end
	local ok, verdict = pcall(gear.Judge, gear, link)
	if not ok or not verdict then return end
	local kind = gear:MarkFor(verdict)
	if kind == "upgrade" then
		local words = gear.Words and gear:Words(verdict) or ""
		return "Upgrade" .. (words ~= "" and (": " .. words) or ""), C.good, kind
	elseif kind == "later" then
		return "Upgrade later", C.alert, kind
	end
end

local function Choose(n)
	if n < 1 or n > s.choices then return end
	s.choice, s.suggested, s.why = n, false, nil
	for i = 1, s.tiles do
		local tile = ui.tiles[i]
		tile.on = i == n
		State(tile)
	end
	PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
	Talk.Refresh()
end

-- The slot's own light over its frame: the hot shade under the mouse, the accent chosen.
local function Rim(tile, color, sub)
	local t = tile.cell:CreateTexture(nil, "OVERLAY", nil, sub)
	tile.slot:Light(t, color)
	t:Hide()
	return t
end

-- An item in the family's slot with its name beside, and ShyGear's word under the name: a reward, or
-- something to bring. Picks (a reward to choose) carry a key, and show what is chosen and what is under
-- the mouse (State).
local function NewTile(pool, index, pick)
	local tile = CreateFrame("Button", nil, ui.body)
	tile:SetSize(pick and PICK_GAP - 10 or TILE_GAP - 10, pick and PICK_H or TILE_H)
	tile.cell = CreateFrame("Frame", nil, tile)
	tile.cell:SetSize(ICON, ICON)
	tile.cell:SetPoint("TOPLEFT", 0, pick and -PICK_IN or 0)
	tile.icon = tile.cell:CreateTexture(nil, "ARTWORK")
	tile.icon:SetAllPoints()
	tile.slot = Shy.Slot.New(tile.cell, { icon = tile.icon })
	tile.count = tile.cell:CreateFontString(nil, "OVERLAY")
	tile.slot:Count(tile.count)
	if pick then
		Washes(tile, 0)
		tile.rimOver = Rim(tile, C.hot, 1)
		tile.rimOn = Rim(tile, Theme.Accent, 2)
		tile.key = OwnKey(tile)
		tile.key:SetPoint("LEFT", tile.cell, "RIGHT", 10, 0)
	end
	tile.name = Shadowed(tile:CreateFontString(nil, "OVERLAY"))
	tile.name:SetFontObject(UI.TextFont(14))
	tile.name:SetJustifyH("LEFT")
	tile.name:SetWordWrap(false)
	tile.say = Shadowed(tile:CreateFontString(nil, "OVERLAY"))
	tile.say:SetFontObject(UI.TextFont(11))
	tile.say:SetJustifyH("LEFT")
	tile.say:SetWordWrap(false)
	-- The words stand past the key while it is shown, else beside the slot.
	function tile:Indent()
		local from = ICON + 10 + ((self.key and self.key:IsShown()) and (KEY.w + 7) or 0)
		for _, fs in ipairs({ self.name, self.say }) do
			fs:ClearAllPoints()
			fs:SetPoint("LEFT", self.cell, "LEFT", from, fs == self.name and 4 or -11)
			fs:SetPoint("RIGHT", -4, 0)
		end
	end
	tile:Indent()
	tile:EnableMouse(true)
	if pick then
		Watched(tile)
		Pressed(tile, function() Choose(index) end)
	end
	tile:HookScript("OnEnter", TipOn)
	tile:HookScript("OnLeave", TipOff)
	tile:HookScript("OnHide", TipOff)
	pool[index] = tile
	return tile
end

-- The room a tile's words want: past the slot (and key), the longer of its name and word, and the room after.
-- A name the game withholds can't be measured: it wants all there is.
local function Wants(tile)
	local most = 0
	for _, fs in ipairs({ tile.name, tile.say }) do
		local wide = fs:GetUnboundedStringWidth()
		if issecretvalue(wide) then return math.huge end
		most = max(most, wide or 0)
	end
	return ICON + 10 + ((tile.key and tile.key:IsShown()) and (KEY.w + 7) or 0) + math.ceil(most) + 4
end

-- { icon, name, count, quality, link, tip = function(tooltip) }. pick: a choice to make. Two across while
-- every name reads whole there (at the stage's measure, else half the column); otherwise one to a row across
-- the whole column, as is a reward alone.
local function Tiles(list, pick)
	local half = math.floor(ui.w / 2)
	local pool, tall = ui.chips, TILE_ROW
	if pick then pool, tall = ui.tiles, PICK_ROW end
	local drawn = {}
	for n, def in ipairs(list) do
		local index = pick and s.tiles + 1 or s.chips + 1
		if pick then s.tiles = index else s.chips = index end
		local tile = pool[index] or NewTile(pool, index, pick)
		drawn[n] = tile
		tile.name:SetFontObject(UI.TextFont(14 - W.Smaller()))
		tile.icon:SetTexture(def.icon)
		local count = def.count
		tile.count:SetText((count and not issecretvalue(count) and count > 1) and tostring(count) or "")
		local color = QualityColor(def.quality)
		tile.slot:Quality(def.quality)
		Say(tile.name, def.name)
		UI.Ink(tile.name, color and { color.r, color.g, color.b } or C.text)
		local words, ink, mark = Verdict(def.link)
		if def.link and s.saying then s.saying[#s.saying + 1] = words or "" end
		-- The suggested reward says why it is, where ShyGear's word doesn't already (asked about too: nokey).
		if pick and s.suggested and (n == s.choice or def.nokey) and not words then words = s.why or "Suggested" end
		tile.say:SetText(words or "")
		UI.Ink(tile.say, ink or C.dim)
		local gear = Shy.addons.Gear
		if mark and gear and gear.Mark and not tile.gear then tile.gear = gear:Mark(tile.cell, tile.icon) end
		if tile.gear then tile.gear:Set(mark) end
		tile.tip = def.tip
		if pick then
			tile.key:SetShown(n <= 9 and not def.nokey)
			tile.key:Set(tostring(n))
			tile:Indent()
			tile.on = n == s.choice
		end
	end
	local wants = 0
	for _, tile in ipairs(drawn) do wants = max(wants, Wants(tile)) end
	local across, gap = 1, ui.w
	if #drawn > 1 then
		local snug = min(pick and PICK_GAP or TILE_GAP, half)
		if wants <= snug - 10 then across, gap = 2, snug
		elseif wants <= half - 10 then across, gap = 2, half end
	end
	for n, tile in ipairs(drawn) do
		tile:SetWidth(across == 2 and gap - 10 or gap)
		if pick then State(tile, not s.arrived) end
		Stand(tile, ((n - 1) % across) * gap, ui.y + math.floor((n - 1) / across) * tall, true)
	end
	-- What comes next stands under the last row's slot, however many rows there are.
	local rows = math.ceil(#list / across)
	if rows == 0 then return end
	local foot = ui.y + (rows - 1) * tall + (pick and PICK_IN or 0) + ICON
	ui.y = foot + (pick and AFTER_PICK or AFTER_TILE)
end

-- Money and experience on one line; experience at the left when there is no money.
local function Gains(money, xp)
	local coins, gain = money and money > 0, xp and xp > 0
	ui.money:SetText(coins and UI.Money(money) or "")
	ui.xp:SetText(gain and ("%d XP"):format(xp) or "")
	ui.money:SetShown(coins)
	ui.xp:SetShown(gain)
	if not (coins or gain) then return end
	if coins then
		Stand(ui.money, 0, ui.y)
		if gain then
			ui.xp.ax = nil
			ui.xp:ClearAllPoints()
			ui.xp:SetPoint("LEFT", ui.money, "RIGHT", 20, 0)
			Arriving(ui.xp)
		end
	else
		Stand(ui.xp, 0, ui.y)
	end
	ui.y = ui.y + GAINS_H
end

-- The pages

-- An item of the quest's, as the game's own quest window shows it: with what you wear beside it.
local function QuestTip(kind, index)
	return function(tip)
		tip:SetQuestItem(kind, index)
		GameTooltip_ShowCompareItem(tip)
	end
end

local function SpellChips(list)
	local quest = GetQuestID()
	for _, spell in ipairs(C_QuestInfoSystem.GetQuestRewardSpells(quest) or {}) do
		local info = C_QuestInfoSystem.GetQuestRewardSpellInfo(quest, spell)
		if info and info.texture and not C_SpellBook.IsSpellInSpellBook(spell, Enum.SpellBookSpellBank.Player, true) then
			list[#list + 1] = { icon = info.texture, name = info.name, tip = function(tip) tip:SetSpellByID(spell) end }
		end
	end
end

local function ItemChips(kind, count, list)
	for i = 1, count do
		local name, texture, number, quality = GetQuestItemInfo(kind, i)
		list[#list + 1] = { icon = texture, name = name, count = number, quality = quality, link = GetQuestItemLink(kind, i),
			tip = QuestTip(kind, i) }
	end
	return list
end

-- What a quest gives: choices to pick from (at hand-in), or shown (offered); the rest after.
local function Rewards(picking)
	-- The reward to suggest among those to choose from: ShyGear's pick (the best upgrade, else what sells
	-- for the most), else the first. Asked again at every refresh while the suggestion stands, since an
	-- item may load late.
	local function Suggest(choices)
		local gear = Shy.addons.Gear
		if gear and gear.PickReward then
			local list = {}
			for i = 1, choices do
				local _, _, count = GetQuestItemInfo("choice", i)
				list[i] = { link = GetQuestItemLink("choice", i), count = not issecretvalue(count) and count or 1 }
			end
			local ok, pick = pcall(gear.PickReward, gear, list)
			if ok and pick and pick.index then
				return pick.index, pick.kind == "sell" and "Sells for the most" or nil
			end
		end
		-- Without the picker, the first reward ShyGear calls an upgrade (now, else later).
		local later
		for i = 1, choices do
			local _, _, kind = Verdict(GetQuestItemLink("choice", i))
			if kind == "upgrade" then return i end
			later = later or (kind == "later" and i) or nil
		end
		return later or 1
	end
	local choices, fixed = GetNumQuestChoices(), GetNumQuestRewards()
	s.saying = {}   -- ShyGear's word on each item drawn (Tiles), to tell when a new verdict changes one
	s.choices = picking and choices > 1 and choices or 0
	if s.choices > 0 then
		if s.choice == 0 or s.suggested then
			s.choice, s.why = Suggest(choices)
			s.suggested = true
		end
		Caption("CHOOSE A REWARD")
		Tiles(ItemChips("choice", choices, {}), true)
	elseif choices > 1 then
		Caption("CHOICE OF")
		Tiles(ItemChips("choice", choices, {}))
	end
	local list = {}
	if choices == 1 then ItemChips("choice", 1, list) end
	ItemChips("reward", fixed, list)
	SpellChips(list)
	if #list > 0 then
		Caption(s.choices > 0 and "YOU ALSO GET" or "REWARDS")
		Tiles(list)
	end
	Gains(GetRewardMoney(), GetRewardXP())
end

local function Close()
	Mine(function()
		if s.kind == "gossip" then C_GossipInfo.CloseGossip() else CloseQuest() end
	end)
	PlaySound(SOUNDKIT.IG_QUEST_CANCEL)
end

local GOODBYE = { text = "Goodbye", act = Close, say = "Ends the conversation.", space = true }

-- Lines asked for
-- What other addons would have you pick on a gossip page (Shy.Talk.Want), asked as each page comes with
-- the NPC and the page's lines.

-- notes: Talk.Note's, facts: Talk.Facts', passes: Talk.Pass', by id; OVER: seconds after a close the windows must stay
-- shut for the talk to be over (kept here: the file has no locals to spare)
local Ask = { wants = {}, notes = {}, facts = {}, passes = {}, OVER = 1 }

-- What your addon knows of a quest the window shows (ShyQuest: your guide, its chain, where it's handed in). fn(questID,
-- kind) is asked as a quest's page is drawn (kind: "detail", "progress" or "reward") and answers a list of
-- { text, tone } (tone: "good", "bad", "alert", "hot" or nil for the quiet ink), or nil. The window shows them as pills
-- under the quest's title, in the order the addons registered, as many as fit.
function Talk.Facts(id, fn)
	if not Ask.facts[id] then Ask.facts[#Ask.facts + 1] = id end
	Ask.facts[id] = fn
end

function Talk.Note(id, fn)
	Ask.notes[id] = fn
end

-- The first word an addon has on an offered quest; nil for none (or a quest it can't be told about).
function Ask.Noted(quest)
	if quest == nil or issecretvalue(quest) then return nil end
	for _, fn in pairs(Ask.notes) do
		local ok, words = pcall(fn, quest)
		if not ok then geterrorhandler()(words) elseif type(words) == "string" and words ~= "" then return words end
	end
	return nil
end

function Talk.Pass(id, fn)
	Ask.passes[id] = fn
end

-- Whether Space passes an offered quest by: an addon would have you leave it (Talk.Pass), or has a word against it
-- (Talk.Note, `note` when already asked). A quest that can't be told about is never passed.
function Ask.Passed(quest, note)
	if quest == nil or issecretvalue(quest) then return false end
	if note ~= nil then return true end
	for _, fn in pairs(Ask.passes) do
		local ok, yes = pcall(fn, quest)
		if not ok then geterrorhandler()(yes) elseif yes == true then return true end
	end
	return false
end

function Talk.Want(id, fn)
	local wants = Ask.wants
	for i, want in ipairs(wants) do
		if want.id == id then
			table.remove(wants, i)
			break
		end
	end
	if fn == nil then return end   -- forgotten
	wants[#wants + 1] = { id = id, fn = fn }
	table.sort(wants, function(a, b) return a.id < b.id end)
end

function Ask.Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	return tonumber((select(6, strsplit("-", guid))))
end

-- The page's lines in order, each { index, id, kind, name }; one the game keeps secret is left out.
function Ask.Lines()
	local lines = {}
	for _, option in ipairs(C_GossipInfo.GetOptions()) do
		local index, id, name = option.orderIndex, option.gossipOptionID, option.name
		local icon = option.overrideIconID or option.icon
		if index ~= nil and not issecretvalue(index) and not issecretvalue(id) then
			lines[#lines + 1] = { index = index, id = id, kind = (not issecretvalue(icon) and OPTIONS.kind[icon]) or "talk",
				name = not issecretvalue(name) and name or nil }
		end
	end
	table.sort(lines, function(a, b) return a.index < b.index end)
	return lines
end

-- The line an addon asks for on this page and its words, or nil.
function Ask.Line()
	if #Ask.wants == 0 then return nil end
	local lines = Ask.Lines()
	if #lines == 0 then return nil end
	local npc = Ask.Talker()
	for _, want in ipairs(Ask.wants) do
		local ok, line, why = pcall(want.fn, npc, lines)
		if not ok then
			geterrorhandler()(line)
		elseif line then
			return line, why
		end
	end
end

-- A quest on the page comes before a line asked for: one ready to hand in, or a new one offered that Space
-- wouldn't pass by.
function Ask.QuestFirst()
	for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
		if Yes(quest.isComplete) then return true end
	end
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		if not Yes(quest.isTrivial) and not Ask.Passed(quest.questID, Ask.Noted(quest.questID)) then return true end
	end
	return false
end

-- This talk was about a quest: a quest's page came since the game's windows were last all shut. What you
-- came for is done; a line asked for waits for the next talk.
function Ask.Quested()
	return s.questAt ~= nil and (s.overAt == nil or s.overAt < s.questAt)
end

-- A window closed: once none is left a moment later, the talk is over.
function Ask.Over()
	if not AnyShown() then s.overAt = GetTime() end
end

-- The line asked for is picked for you a frame after its page comes, whether or not the dialog stands in
-- for the game's window: never with Shift held, nor when anyone answered the page first (another addon,
-- the game picking a lone line itself), nor while a quest comes first or came earlier in this talk (the
-- dialog leads that, and the line is picked when you talk again). Looked for once a page. The pick is
-- heard like anyone's: the dialog waits for what comes of it.
function Ask.Pick()
	if s.picked == s.gossips then return end
	s.picked = s.gossips
	if not GossipFrame:IsShown() or IsShiftKeyDown() then return end
	if s.heardAt and s.heardAt >= s.gossipAt then return end
	if Ask.QuestFirst() or Ask.Quested() then return end
	local line = Ask.Line()
	if line then C_GossipInfo.SelectOptionByIndex(line.index) end
end

local Answer = {}

-- The row Space gives in a list: a quest ready to hand in, else one offered, the plain before the faint;
-- then a line asked for, unless this talk was about a quest (Ask.Quested); never one in progress, an offer
-- passed by (Ask.Passed) or another option.
local function Lead(defs)
	s.lead = nil
	local best, rank = nil, 0
	local quested = Ask.Quested()
	for i, def in ipairs(defs) do
		local r = 0
		if def.pass then r = 0
		elseif def.act and def.mark == "?" then r = def.faint and 2 or 4
		elseif def.act and def.mark == "!" then r = def.faint and 1 or 3
		elseif def.act and def.asked and not quested then r = 2 end
		if r > rank then best, rank = i, r end
	end
	if best then
		defs[best].lead = true
		s.lead = best
	end
	for _, def in ipairs(defs) do Row(def) end
	if #defs > 0 then ui.y = ui.y + 8 end   -- air between the rows and the buttons
end

-- The reward page asking about the suggestion, or back to the choice; the answers come in again.
local function Confirm(on)
	s.confirming = on
	PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
	s.arrived = false
	Talk.Refresh()
	Arrive()
end

local function NoTitle()
	ui.title:SetText("")
	ui.title:Hide()
	ui.level:Hide()
	ui.off:Hide()
	ui.offGlyph:Hide()
end

-- The quest's title, with its level beside it; offered (`offered`), an addon's word on it under it.
local function QuestTitle(offered)
	local note = offered and Ask.Noted(GetQuestID()) or nil
	ui.off:SetShown(note ~= nil)
	ui.offGlyph:SetShown(note ~= nil)
	if note then
		ui.off:SetText(note)
		UI.Ink(ui.off, C.bad, 0.85)
		UI.Tint(ui.offGlyph, C.bad, 0.85)
	end
	Say(ui.title, GetTitleText())
	if s.make == "window" then
		ui.title:Show()   -- in the band, at once (W.Band)
		ui.title:SetAlpha(1)
	else
		Stand(ui.title, 0, ui.y)
	end
	local level = C_QuestLog.GetQuestDifficultyLevel(GetQuestID())
	if issecretvalue(level) then
		ui.level:SetText(("%s"):format(level))
	elseif level and level > 0 then
		ui.level:SetText(("%d"):format(level))
	else
		ui.level:SetText("")
	end
	ui.level:Show()
	if s.make == "window" then
		ui.level:SetAlpha(1)
	else
		Arriving(ui.level)
		ui.y = ui.y + 30 + (note and 20 or 0)
	end
end

function Answer.gossip()
	NoTitle()
	local defs = {}
	for _, quest in ipairs(C_GossipInfo.GetAvailableQuests()) do
		local id = quest.questID
		local note = Ask.Noted(id)
		local pass = Ask.Passed(id, note)
		defs[#defs + 1] = { mark = "!", text = quest.title, faint = Yes(quest.isTrivial) or pass, note = note, pass = pass,
			act = not issecretvalue(id) and function() Mine(C_GossipInfo.SelectAvailableQuest, id) end or nil }
	end
	for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
		local id = quest.questID
		defs[#defs + 1] = { mark = Yes(quest.isComplete) and "?" or "-", text = quest.title,
			act = not issecretvalue(id) and function() Mine(C_GossipInfo.SelectActiveQuest, id) end or nil }
	end
	local options = C_GossipInfo.GetOptions()
	local sortable = true
	for _, option in ipairs(options) do
		if issecretvalue(option.orderIndex) then sortable = false end
	end
	if sortable then table.sort(options, function(a, b) return (a.orderIndex or 0) < (b.orderIndex or 0) end) end
	local asked, why = Ask.Line()
	-- A guard's directions (a list of places and nothing else): the places as tiles, two across.
	local places = #defs == 0 and OPTIONS.Directions(options) or nil
	s.directions = places ~= nil
	for n, option in ipairs(options) do
		local index, spell = option.orderIndex, option.spellID
		local icon = option.overrideIconID or option.icon
		local mine = asked ~= nil and not issecretvalue(index) and index == asked.index
		defs[#defs + 1] = { mark = "talk", text = option.name, spell = not issecretvalue(spell) and spell or nil,
			icon = not issecretvalue(icon) and icon or nil, asked = mine, why = mine and why or nil,
			tile = places and (n - 1) % 2 or nil, place = places and places[n] or nil, last = places and n == #options or nil,
			act = not issecretvalue(index) and function() Mine(C_GossipInfo.SelectOptionByIndex, index) end or nil }
	end
	Lead(defs)
	return Buttons(nil, GOODBYE)
end

function Answer.greeting()
	NoTitle()
	local defs = {}
	for i = 1, GetNumActiveQuests() do
		local title, done = GetActiveTitle(i)
		defs[#defs + 1] = { mark = Yes(done) and "?" or "-", text = title, faint = Yes(IsActiveQuestTrivial(i)),
			act = function() Mine(SelectActiveQuest, i) end }
	end
	for i = 1, GetNumAvailableQuests() do
		local trivial, _, _, _, id = GetAvailableQuestInfo(i)
		local note = Ask.Noted(id)
		local pass = Ask.Passed(id, note)
		defs[#defs + 1] = { mark = "!", text = GetAvailableTitle(i), faint = Yes(trivial) or pass, note = note, pass = pass,
			act = function() Mine(SelectAvailableQuest, i) end }
	end
	Lead(defs)
	return Buttons(nil, GOODBYE)
end

function Answer.detail()
	QuestTitle(true)
	local goal = GetObjectiveText()
	if issecretvalue(goal) or (goal and goal ~= "") then Para(goal) end
	local group = GetSuggestedGroupSize()
	if group and not issecretvalue(group) and group > 0 then Para(("Suggested group: %d"):format(group), C.alert, 13) end
	Goals()
	ui.y = ui.y + 8
	Rewards(false)
	Seal()
	local auto = QuestGetAutoAccept()
	return Buttons({ text = auto and "Okay" or "Accept", space = true,
		say = auto and "You already have this quest." or "Accepts the quest.", act = function()
		PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
		if QuestFlagsPVP() then
			StaticPopup_Show("CONFIRM_ACCEPT_PVP_QUEST")
		elseif auto then
			Mine(AcknowledgeAutoAcceptQuest)
		else
			Mine(AcceptQuest)
		end
	end }, not auto and { text = "Decline", act = Close, say = "Turns the quest down." } or nil)
end

function Answer.progress()
	QuestTitle()
	Goals()
	local list = {}
	if not C_QuestOffer.GetHideRequiredItems() then
		for i = 1, GetNumQuestItems() do
			if IsQuestItemHidden(i) == 0 then
				local name, texture, number = GetQuestItemInfo("required", i)
				list[#list + 1] = { icon = texture, name = name, count = number, tip = QuestTip("required", i) }
			end
		end
	end
	if #list > 0 then
		ui.y = ui.y + 8
		Caption("BRING")
		Tiles(list)
	end
	local cost = GetQuestMoneyToGet()
	if cost > 0 then Para("Costs " .. UI.Money(cost), cost > GetMoney() and C.bad or C.alert, 13) end
	Seal()
	local ready = IsQuestCompletable()
	return Buttons({ text = "Continue", space = true, off = not ready, say = "Hands over what the quest asks for.",
		wait = "Bring everything the quest asks for first.", act = function()
		PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
		Mine(CompleteQuest)
	end }, GOODBYE)
end

-- The suggested reward alone, asked about before it is taken.
function Answer.asking()
	QuestTitle()
	Caption("TAKE THIS ONE?")
	local n = s.choice
	local name, texture, number, quality = GetQuestItemInfo("choice", n)
	Tiles({ { icon = texture, name = name, count = number, quality = quality, link = GetQuestItemLink("choice", n),
		tip = QuestTip("choice", n), nokey = true } }, true)
	local tile = ui.tiles[1]
	tile.on = true
	State(tile, true)
	s.choices = 0   -- nothing to pick here: a click on it does nothing, and a number goes back (Pick)
	return Buttons({ text = "Take it", space = true, say = "Hands the quest in for this reward.", act = function()
		Mine(GetQuestReward, n)
	end }, { text = "Choose another", say = "Back to the rewards. Backspace works too.", act = function() Confirm(false) end })
end

function Answer.reward()
	if s.confirming then return Answer.asking() end
	QuestTitle()
	Rewards(true)
	local cost = GetQuestMoneyToGet()
	if cost > 0 then Para("Costs " .. UI.Money(cost), cost > GetMoney() and C.bad or C.alert, 13) end
	Seal()
	local choices = GetNumQuestChoices()
	local pick = choices == 1 and 1 or s.choice
	local asks = choices > 1 and s.suggested
	-- A cost is paid with a click, never with Space.
	return Buttons({ text = "Complete", space = cost == 0, off = choices > 1 and s.choice == 0, explain = asks or cost > 0,
		say = (asks and "Confirms your reward, then hands the quest in.")
			or (cost > 0 and "Pays the cost and hands the quest in.") or "Hands the quest in.",
		wait = "Choose a reward first.", act = function()
		if asks then Confirm(true) else Mine(GetQuestReward, pick) end
	end }, GOODBYE)
end

-- The speech

local function Pips()
	local count = #s.pages
	local many = count > 1
	for i, pip in ipairs(ui.pips) do
		pip:SetShown(many and i <= count)
		local lit = i == s.page
		UI.Tint(pip.art, lit and Theme.light or INK.grey)
		pip.halo:SetShown(lit)
	end
	ui.back:SetShown(many)
	ui.next:SetShown(many)
	if many then
		ui.next:ClearAllPoints()
		ui.next:SetPoint("CENTER", ui.foot, "LEFT", 18 + PIP * min(count, PIPS) + 12, 0)
	end
	UI.Tint(ui.next.art, s.page < count and C.head or C.dim)
end

-- The hint: the key that reads on, at the pips; once all is read, the key that gives the page's answer,
-- at the right of the buttons. A lead row carries Space's cap itself, so the hint stands down for it.
local function Hint()
	local word, reading
	-- (In the window a single page has no controls' row to stand Read on in: W.Turns.)
	if (s.revealing or s.page < #s.pages) and not (s.make == "window" and not W.Turns()) then
		word, reading = "Read on", true
	elseif not s.lead and ui.space and s.make ~= "window" then
		-- (In the window the button Space gives says so itself: W.Foot.)
		word = ui.space.text:GetText()
	end
	ui.hint:SetShown(word ~= nil)
	ui.hint.reading = reading == true
	-- Skip's cap stands beside Read on while there is reading left to skip.
	ui.skip:SetShown(reading == true)
	-- One cap for Space: the lead row wears it only once Space gives the row.
	if s.lead and ui.rows[s.lead] then ui.rows[s.lead].cap:SetShown(not reading) end
	ui.hintText:SetText(word or "")
	ui.hint:ClearAllPoints()
	ui.hintText:ClearAllPoints()
	-- At the pips a key's size; beside the buttons one of them.
	if reading then ui.hint:Size(KEY.h, KEY.font, KEY.pad) else ui.hint:Size(BUTTON_H, KEY.hintFont, KEY.hintPad) end
	if reading then
		local many = #s.pages > 1
		ui.hint:SetPoint("LEFT", ui.foot, "LEFT", many and (18 + PIP * min(#s.pages, PIPS) + 30) or -2, 0)
		ui.hintText:SetPoint("LEFT", ui.hint, "RIGHT", 7, 0)
	else
		ui.hintText:SetPoint("RIGHT", ui.body, "TOPRIGHT", 0, -((ui.space and ui.space.ay) or 0) - BUTTON_H / 2)
		ui.hint:SetPoint("RIGHT", ui.hintText, "LEFT", -7, 0)
	end
	-- Moved: its face is the gradient's color where it stands now.
	ui.hint:Look("lit")
	-- In the window, the foot makes room for it (or lets it go) again.
	if s.make == "window" and s.open then W.Foot() end
end

-- The glow behind the head, settled after the words.
local function Hush()
	local from = ui.sealLight:GetAlpha()
	Tween("hush", 0.5, function(k) ui.sealLight:SetAlpha(from + (PACE.light - from) * Ease(k)) end)
end

local function Done()
	s.revealing = false
	ui.reader:SetScript("OnUpdate", nil)
	Hush()
	Hint()
	if s.page == 1 then Arrive() end
end

local function Reveal(_, dt)
	s.progress = s.progress + dt * PACE.cps
	s.breath = s.breath + dt
	ui.text:SetAlphaGradient(s.progress, PACE.spread)
	local breath = PACE.lightLow + PACE.lightSpeak * (0.5 - 0.5 * math.cos(2 * math.pi * s.breath / PACE.breath))
	ui.sealLight:SetAlpha(min(1, breath + 0.3 * max(0, 1 - s.breath / PACE.flash)))
	if s.progress >= s.length + PACE.spread then Done() end
end

local function ShowPage(n)
	s.page = n
	local text = s.pages[n]
	Say(ui.text, text)
	s.voiceText = nil
	Settle("hush")
	if Readable(text) and not (s.make == "window" and I.QuestText() == "instant") then
		s.length, s.progress, s.revealing, s.breath = strlenutf8(text), 0, true, 0
		ui.text:SetAlphaGradient(0, PACE.spread)
		ui.reader:SetScript("OnUpdate", Reveal)
	else
		-- Withheld words can't be counted: shown whole.
		s.revealing = false
		ui.text:SetAlphaGradient(PACE.whole, PACE.spread)
		ui.reader:SetScript("OnUpdate", nil)
		Arrive()
	end
	Pips()
	Hint()
end

local function Finish()
	s.progress = s.length + PACE.spread
	ui.text:SetAlphaGradient(s.progress, PACE.spread)
	Done()
end

-- Space, a click on the words or the wheel: the rest of this page, the next page, then (Space alone) the
-- page's answer: the lead row, or the button Space gives. While the game answers the last press, Space
-- is swallowed rather than handed on: it never jumps you mid-talk.
local function Advance(byKey)
	Settle("enter")
	if s.revealing then
		Finish()
		return true
	end
	if not s.arrived then
		Arrive(true)
		return true
	end
	-- Answers still coming in are all in at once, and the key does what it does as well.
	Settle("cascade")
	if s.page < #s.pages then
		ShowPage(s.page + 1)
		return true
	end
	if not byKey then return false end
	local lead = s.lead and ui.rows[s.lead]
	local gives = (lead and not lead.off and lead) or ui.space
	if not gives then return false end
	if not Busy() then gives:Click() end
	return true
end

-- Shift+Space, or a click on the Skip cap: the last page whole, the answers in, and the page's answer
-- given as Space gives it. The reading is skipped, never the talk: the dialog is seen, and a reward to
-- choose is asked about as ever.
local function Skip()
	Settle("enter")
	if #s.pages > 0 and s.page < #s.pages then ShowPage(#s.pages) end
	if s.revealing then Finish() end
	Arrive(true)
	Settle("cascade")
	return Advance(true)
end

-- Backspace, a right-click on the words or the wheel: the page before, or this one again from the start;
-- while the reward page asks, back to the choice.
local function Back()
	Settle("enter")
	if s.confirming then
		Confirm(false)
		return true
	end
	if #s.pages == 0 or not Readable(s.pages[s.page]) then return false end
	ShowPage(max(1, s.page - 1))
	return true
end

local function Pick(n)
	-- While the reward page asks, a number is that reward chosen by you: back to the choice with it lit.
	if s.confirming then
		local count = GetNumQuestChoices()
		if issecretvalue(count) or n > count then return false end
		s.choice, s.suggested, s.why = n, false, nil
		Confirm(false)
		return true
	end
	if s.choices > 0 then
		if n > s.choices then return false end
		Choose(n)
		return true
	end
	-- A number with a row to it is the dialog's, even while the game answers the last press or the row
	-- can't be picked: handed on, it would press an action bar.
	local row = ui.rows[n]
	if n > s.rows or not row then return false end
	if not s.arrived then Arrive(true) end
	if not (row.off or Busy()) then row:Click() end
	return true
end

-- The answers come in after the first page is read (or at once when asked for), one after another, each
-- rising into its place.
function Arrive(now)
	if s.arrived then
		if now then Settle("cascade") end
		return
	end
	s.arrived = true
	local list = ui.arrivals
	for _, frame in ipairs(list) do
		if frame.mouse then Touchable(frame, true) end
	end
	local total = PACE.cascade + PACE.stagger * max(0, #list - 1)
	Tween("cascade", total, function(k)
		local t = k * total
		for i, frame in ipairs(list) do
			local e = Ease((t - (i - 1) * PACE.stagger) / PACE.cascade)
			frame:SetAlpha((frame.dim or 1) * e)
			if frame.ax then Place(frame, PACE.lift * (1 - e)) end
		end
	end)
	if now then Settle("cascade") end
end

-- The head

-- Who speaks: a quest page's "questnpc", a gossip page's "npc", either standing in for the other.
function Talk.Speaker(kind)
	local order = kind == "gossip" and { "npc", "questnpc" } or { "questnpc", "npc" }
	for _, unit in ipairs(order) do
		local exists = UnitExists(unit)
		if not issecretvalue(exists) and exists then return unit end
	end
end

-- The camera on the model once it has one: head and shoulders, turned a little toward the words.
local function Frame()
	if s.make == "window" then return W.Camera(ui.model) end
	ui.model:SetPortraitZoom(ZOOM)
	ui.model:SetRotation(TURN)
	ui.model:SetLight(true, W.Light())
end

-- Asked while the model is shown: hidden, it neither takes a unit nor keeps one.
local function Face()
	if not (s.kind and ui.model:IsVisible()) then return end
	local unit = Talk.Speaker(s.kind)
	local shown = false
	if unit then
		local withheld = C_Secrets.ShouldUnitIdentityBeSecret(unit)
		if not issecretvalue(withheld) and not withheld then
			local ok, set = pcall(ui.model.SetUnit, ui.model, unit)
			shown = ok and (issecretvalue(set) or set ~= false)
		end
	end
	if shown then
		Frame()
	else
		ui.model:ClearModel()
	end
	ui.face = shown and unit or nil
	ui.emblem:SetShown(not shown)
	if W.emblem then W.emblem:SetShown(not shown) end
end

local function Measure(text)
	ui.text:SetText(text)
	local tall = ui.text:GetStringHeight()
	return issecretvalue(tall) and 0 or tall
end

-- Hides what the last page used.
local function Clear()
	for _, pool in ipairs({ ui.rows, ui.tiles, ui.chips, ui.lines, ui.caps, ui.goals }) do
		for _, region in ipairs(pool) do region:Hide() end
	end
	ui.money:Hide()
	ui.xp:Hide()
	if ui.sign then ui.sign:Hide() end
	s.rows, s.tiles, s.chips, s.lines, s.caps, s.goals, s.choices = 0, 0, 0, 0, 0, 0, 0
	s.lead, ui.space = nil, nil
	ui.y = 0
	wipe(ui.arrivals)
end

-- The answers alone (a choice made, an item loaded); the words stay where they are.
local function Fill()
	Clear()
	local buttons = Answer[s.kind]()
	if s.rows > 0 then ui.rows[s.rows].rule:Hide() end
	local need = ui.y + (buttons and 12 or 0)
	Hint()
	return need
end

-- The mark in the ring at the plaque's head: what this talk is about.
local function Mark(kind)
	local mark, color = nil, C.alert
	if kind == "detail" then
		mark = "!"
	elseif kind == "reward" then
		mark = "?"
	elseif kind == "progress" then
		mark = "?"
		if not IsQuestCompletable() then color = C.dim end
	else
		local offered, ready, going = false, false, false
		for i = 1, s.rows do
			local kind = ui.rows[i].kind
			if kind == "!" then offered = true elseif kind == "?" then ready = true elseif kind == "-" then going = true end
		end
		if offered then mark = "!" elseif ready then mark = "?" elseif going then mark, color = "?", C.dim end
	end
	ui.mark:SetShown(mark ~= nil)
	ui.glyph:SetShown(mark == nil)
	ui.mark:SetText(mark or "")
	-- Centred by its ink, not its advance: the "!" stands a little left of its own box.
	ui.mark:SetPoint("CENTER", ui.ring, "CENTER", mark == "!" and 1 or 0, 0)
	UI.Ink(ui.mark, color)
	if W.mark then W.Mark(mark, color) end
end

-- The words' height follows the longest page, so nothing jumps between pages; the answers hang under.
-- The box is sized to what its page needs (the words' room is the tallest page's, so the answers never
-- jump between pages) and the HUD clamps it to the screen holding its top, so a tall page lifts the whole
-- stage rather than running off the foot. Sideways, every line of words has the column's width or an
-- ellipsis (rows wrap to two lines, a title, a name, an item's name and an objective are cut or wrapped),
-- so nothing runs past the column or off the screen.
local function Fit(answerNeed)
	if s.make == "window" then return W.Fit(answerNeed) end
	-- The controls' row: its middle, so Space's key stands SPEECH.clear under the words' last line.
	local foot = TEXT_Y + max(SPEECH.least, ui.textTall) + KEY.h / 2 + SPEECH.clear
	ui.foot:SetPoint("TOPLEFT", ui.box, "TOPLEFT", TEXT_X, -foot)
	ui.reader:SetHeight(foot - TEXT_Y + 20)
	ui.rule:SetPoint("TOPLEFT", ui.box, "TOPLEFT", TEXT_X, -(foot + SPEECH.rule))
	ui.body:SetPoint("TOPLEFT", ui.box, "TOPLEFT", TEXT_X, -(foot + SPEECH.body))
	Mark(s.kind)
	Shy.HUD.Resize(ui.box, WIDTH, max(2 * R, foot + SPEECH.body + answerNeed + 12))
end

function Talk.Refresh()
	if not (s.open and s.kind) then return end
	Fit(Fill())
end

local Build

local function Words(kind)
	if kind == "gossip" then return C_GossipInfo.GetText() end
	if kind == "greeting" then return GetGreetingText() end
	if kind == "detail" then return GetQuestText() end
	if kind == "progress" then return GetProgressText() end
	return GetRewardText()
end

local function Name(unit)
	local name = unit and UnitName(unit)
	Say(ui.name, name)
	local wide = ui.name:GetStringWidth()
	if issecretvalue(wide) or not wide then wide = 120 end
	-- A name longer than the column is cut with an ellipsis rather than run off the plaque's end.
	local room = TEXT_W - 60
	ui.name:SetWidth(wide > room and room or 0)
	wide = min(wide, room)
	ui.strip:SetWidth(16 + wide + 20)
	ui.plaque:SetShown(s.make ~= "window" and (issecretvalue(name) or name ~= nil))
	if s.make == "window" then W.Name(name) end
end

local function Render()
	Build()
	W.Make(s.make)
	W.Page()
	local kind = s.kind
	Name(Talk.Speaker(kind))
	local words = Words(kind)
	s.pages = Pages(words)
	-- The page's words are up: its line may be said, though the talk left this page a moment ago.
	s.said = Readable(words) and words or nil
	Shy.Voice.Opened(s.said)
	ui.textTall = 0
	for _, page in ipairs(s.pages) do ui.textTall = max(ui.textTall, Measure(page)) end
	s.choice, s.busy, s.arrived = 0, nil, false
	s.suggested, s.why, s.confirming = false, nil, false
	s.voiced, s.voicing = 1, nil
	Settle("cascade")
	local need = Fill()
	ShowPage(1)
	if #s.pages == 0 then Arrive() end
	Fit(need)
	s.shownGen = s.gen
	if ui.box:IsVisible() then Face() end
	-- The voice: none of this page's yet, its key down until one begins; or none to come.
	ui.Missing()
end

-- The entrance: the stage comes up with a gleam running once along its line, the seal out of the dark,
-- the plaque after it, the words with their reveal.
local function Unfurl(k)
	local t = k * PACE.enter
	ui.stage:SetAlpha(Ease(t / 0.3))
	ui.seal:SetAlpha(Ease(t / 0.35))
	ui.under:SetAlpha(Ease(t / 0.35))
	ui.plaque:SetAlpha(Ease((t - 0.25) / 0.3))
	ui.reader:SetAlpha(Ease((t - 0.3) / 0.3))
	local run = (t - 0.1) / 0.5
	ui.gleam:SetAlpha(k < 1 and max(0, math.sin(math.pi * max(0, min(1, run)))) or 0)
	local wide = UIParent:GetWidth()
	if issecretvalue(wide) then wide = 1600 end
	ui.gleam:ClearAllPoints()
	ui.gleam:SetPoint("CENTER", ui.line, "LEFT", wide * max(0, min(1, run)), 0)
end

local function Open()
	if s.leaving then
		s.leaving = nil
		Settle("leave")
	end
	if s.open then return end
	s.open = true
	-- When this talk began: its voice is the lines begun since, hushed as it ends (Shut).
	s.talkAt = s.pageAt
	if s.make == "window" then return W.Open() end
	ui.box:SetAlpha(1)
	Shy.HUD.Update(ui.box)
	ui.stage:SetShown(ui.box:IsShown())
	ui.under:SetShown(ui.box:IsShown())
	ui.keys:SetShown(not InCombatLockdown())
	-- Still: nothing behind the dialog comes back under the cursor; windows and tooltips stay solid.
	I.Quiet("talk", true, ui.box, true)
	Face()
	Tween("enter", PACE.enter, Unfurl)
	PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
end

-- soft: it fades out over a moment; otherwise it is gone at once (the talk ended under it, or another window
-- takes its place).
-- The talk's voice ends with it: walked away from, left or answered, the line stops. A talk the dialog never
-- stood in for (an instant turn-in, the game's own windows) is no business of this, so its voice plays on.
local function Shut(soft, quiet)
	if not s.open then return end
	s.open, s.shownGen = false, nil
	if s.talkAt then Shy.Voice.Hush(s.talkAt, s.said) end
	s.talkAt = nil
	s.revealing = false
	ui.reader:SetScript("OnUpdate", nil)
	ui.keys:Hide()
	I.Quiet("talk", false)
	-- (quiet: another window takes its place, Talk.Yield: nothing closed to the ear)
	if not quiet then PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE) end
	Settle()
	-- What the talk is worn in: the stage's dialog, or the window.
	local shell = s.make == "window" and W.win or ui.box
	if soft then
		local token = {}
		s.leaving = token
		Tween("leave", PACE.leave, function(k)
			shell:SetAlpha(1 - Ease(k))
			if shell == ui.box then
				ui.stage:SetAlpha(1 - Ease(k))
				ui.under:SetAlpha(1 - Ease(k))
			end
		end)
		C_Timer.After(PACE.leave, function()
			if s.leaving ~= token then return end
			s.leaving = nil
			Shy.HUD.Update(shell)
		end)
	else
		s.leaving = nil
		-- Hiding it puts away a tooltip of ours (OnHide).
		Shy.HUD.Update(shell)
	end
end

-- Keys: Space reads on, Shift+Space skips, Backspace goes back, 1-9 pick; everything else (Esc included)
-- goes on to the game. Key propagation can't be changed in combat, so the frame that takes keys is down
-- while in one. It takes the keyboard once, at load, out of combat.
local function OnKey(self, key)
	local used = false
	local typing = GetCurrentKeyBoardFocus()
	if key == "SPACE" and not typing and IsShiftKeyDown() and not (IsControlKeyDown() or IsAltKeyDown()) then
		used = Skip()
	elseif not (IsModifierKeyDown() or typing) then
		if key == "SPACE" then
			used = Advance(true)
		elseif key == "BACKSPACE" then
			used = Back()
		elseif DIGITS[key] then
			used = Pick(DIGITS[key])
		end
	end
	self:SetPropagateKeyboardInput(not used)
end

ui.keys = CreateFrame("Frame", nil, UIParent)
ui.keys:Hide()
ui.keys:EnableKeyboard(true)
ui.keys:SetScript("OnKeyDown", OnKey)

local function Chevron(parent, flip)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(14, 14)
	b.art = Art(b, "TalkChevron", "ARTWORK", 0, C.dim)
	b.art:SetSize(12, 12)
	b.art:SetPoint("CENTER")
	if flip then b.art:SetTexCoord(1, 0, 0, 1) end
	b:SetScript("OnEnter", function(self) UI.Tint(self.art, C.hot) end)
	b:SetScript("OnLeave", function(self) UI.Tint(self.art, self.lit and C.head or C.dim) end)
	return b
end

-- The stage: a wash over the foot of the screen that follows the box's line and spans the screen.
local function BuildStage(box)
	local stage = CreateFrame("Frame", nil, UIParent)
	ui.stage = stage
	stage:SetFrameStrata("MEDIUM")
	stage:SetFrameLevel(6)   -- over the head's frame (level 2): a level of 0 or 1 is clamped and ties are drawn in creation order
	stage:SetIgnoreParentAlpha(true)
	stage:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
	stage:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT")
	stage:Hide()
	-- The line: where the wash's top edge lies, level with the seal's foot.
	local line = CreateFrame("Frame", nil, stage)
	ui.line = line
	line:SetHeight(1)
	line:SetPoint("LEFT", UIParent, "LEFT")
	line:SetPoint("RIGHT", UIParent, "RIGHT")
	line:SetPoint("TOP", box, "TOP", 0, -LINE)
	-- The world darkens toward the line, and at the foot's left corner.
	local dusk = stage:CreateTexture(nil, "BACKGROUND", nil, -8)
	dusk:SetColorTexture(1, 1, 1, 1)
	dusk:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.28), CreateColor(0, 0, 0, 0))
	dusk:SetPoint("BOTTOMLEFT", line, "TOPLEFT")
	dusk:SetPoint("BOTTOMRIGHT", line, "TOPRIGHT")
	dusk:SetHeight(STAGE.vignette)
	local corner = Art(stage, "Glow", "BACKGROUND", -7, INK.black, 0.3)
	corner:SetSize(700, 700)
	corner:SetPoint("CENTER", line, "LEFT", 0, -100)
	-- The wash: its fade over the line, then solid to the foot of the screen, with frost over both.
	local fade = Art(stage, "TalkStage", "BACKGROUND", -6, C.panel, 0.86)
	fade:SetPoint("TOPLEFT", line, "TOPLEFT", 0, STAGE.up)
	fade:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, STAGE.up)
	fade:SetHeight(STAGE.up + STAGE.down)
	local floor = stage:CreateTexture(nil, "BACKGROUND", nil, -6)
	UI.Paint(floor, C.panel, 0.86)
	floor:SetPoint("TOPLEFT", fade, "BOTTOMLEFT")
	floor:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT")
	local frost = stage:CreateTexture(nil, "BACKGROUND", nil, -5)
	UI.Frost(frost)
	frost:SetAlpha(0.25)
	frost:SetPoint("TOPLEFT", fade, "TOPLEFT")
	frost:SetPoint("BOTTOMRIGHT", floor, "BOTTOMRIGHT")
	local mask = stage:CreateMaskTexture()
	mask:SetTexture(MEDIA .. "TalkStageMask", "CLAMP", "CLAMP")
	mask:SetAllPoints(fade)
	frost:AddMaskTexture(mask)
	-- Under the line a darker band; the line itself the accent as light, falling onto both sides.
	local shade = Art(stage, "TalkStageShade", "BACKGROUND", -4)
	shade:SetPoint("TOPLEFT", line, "TOPLEFT")
	shade:SetPoint("TOPRIGHT", line, "TOPRIGHT")
	shade:SetHeight(STAGE.shade)
	local glow = Light(stage, "TalkStageGlow", "BORDER", 0)
	glow:SetPoint("TOPLEFT", line, "TOPLEFT", 0, STAGE.glowUp)
	glow:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, STAGE.glowUp)
	glow:SetHeight(STAGE.glowUp + STAGE.glowDown)
	glow:SetAlpha(0.1)
	local light = Light(stage, "TalkStageLight", "BORDER", 1)
	light:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 1.5)
	light:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 1.5)
	light:SetHeight(STAGE.light)
	ui.gleam = Light(stage, "TalkGleam", "ARTWORK", 0, Theme.light)
	ui.gleam:SetSize(128, 16)
	ui.gleam:SetPoint("CENTER", line, "LEFT", 0, 0)
	ui.gleam:SetAlpha(0)
	box:HookScript("OnShow", function() stage:Show() end)
	box:HookScript("OnHide", function() stage:Hide() end)
	-- A dialog's ground, not a piece of the HUD: as solid whatever the Background setting.
	stage.wash, stage.floor, stage.light = fade, floor, light
	-- (Its other pieces by name, for a look that dresses the stage its own way: Stage.lua.)
	stage.art = { frost = frost, shade = shade, glow = glow }
	return stage
end

local function BuildSeal(box)
	-- The head: no window round it. The speaker stands behind the stage, head and chest rising out of its line, the
	-- model's frame cut at the line so the body goes down behind the seam; a soft glow of the accent behind the head
	-- is its light. The seal is the place it stands (the dialog is held there to move it).
	local seal = CreateFrame("Frame", nil, box)
	ui.seal = seal
	seal:SetSize(2 * R, 2 * R)
	seal:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
	seal:SetFrameLevel(box:GetFrameLevel() + 4)
	-- A frame of its own beside the stage, a strata over it (a child would draw under the dialog's own ground).
	local under = CreateFrame("Frame", nil, UIParent)
	ui.under = under
	under:SetFrameStrata("HIGH")
	under:SetFrameLevel(box:GetFrameLevel() + 5)
	under:SetIgnoreParentAlpha(true)
	under:SetPoint("BOTTOMLEFT", box, "TOPLEFT", FIGURE.left, -LINE)
	under:SetPoint("BOTTOMRIGHT", box, "TOPLEFT", NAME_X - FIGURE.clear, -LINE)
	under:SetHeight(FIGURE.tall)
	under:Hide()
	box:HookScript("OnShow", function() under:Show() end)
	box:HookScript("OnHide", function() under:Hide() end)
	-- The glow behind the head, breathing while the words are said: its own frame holds it soft.
	local glow = CreateFrame("Frame", nil, under)
	glow:SetAllPoints()
	glow:SetAlpha(FIGURE.glow)
	ui.sealLight = Light(glow, "Glow", "BACKGROUND", -6)
	ui.sealLight:SetSize(STAGE.halo, STAGE.halo)
	ui.sealLight:SetPoint("CENTER", seal, "CENTER", 0, FIGURE.headY)
	ui.sealLight:SetAlpha(PACE.light)
	ui.model = CreateFrame("PlayerModel", nil, under)
	ui.model:SetAllPoints()
	ui.model:SetFrameLevel(box:GetFrameLevel() + 5)
	ui.model:SetKeepModelOnHide(true)
	ui.model:SetScript("OnShow", Face)
	ui.model:SetScript("OnModelLoaded", Frame)
	local rim = CreateFrame("Frame", nil, seal)
	ui.rim = rim
	rim:SetPoint("BOTTOMLEFT", seal, "LEFT", 0, -2)
	rim:SetPoint("TOPRIGHT")
	rim:SetFrameLevel(seal:GetFrameLevel() + 2)
	-- A notice, a book or anything else with no head: a note, quietly, standing over the line.
	ui.emblem = rim:CreateTexture(nil, "ARTWORK", nil, 0)
	Shy.Hover.Glyph(ui.emblem, "note")
	UI.Tint(ui.emblem, C.head, 0.55)
	ui.emblem:SetSize(64, 64)
	ui.emblem:SetPoint("CENTER", seal, "CENTER", 0, 50)
	ui.emblem:Hide()
	-- The head is where the dialog is held to move it.
	rim:EnableMouse(true)
	Shy.HUD.DragHandle(box, rim)
	seal.art = {}
	return seal
end

local function BuildPlaque(box)
	-- The name on the family's plaque, pinned on the line out of the seal, the talk's mark in a ring at
	-- its head.
	local plaque = CreateFrame("Frame", nil, box)
	ui.plaque = plaque
	plaque:SetSize(1, PLAQUE_H)
	plaque:SetPoint("LEFT", box, "TOPLEFT", NAME_X, -NAME_Y)
	-- Over the seal's ring (its rim frame, the seal's level + 2): the ring at the plaque's head lies on it.
	plaque:SetFrameLevel(ui.rim:GetFrameLevel() + 2)
	ui.strip = Art(plaque, "HoverPlaqueMid", "ARTWORK", 0, Theme.skin.metal)
	ui.strip:SetPoint("TOPLEFT", RING * 0.2, 0)   -- tucked under the ring at its head: no gap between them
	ui.strip:SetSize(120, PLAQUE_H)
	local tip = Art(plaque, "HoverPlaqueEnd", "ARTWORK", 0, Theme.skin.metal)
	tip:SetPoint("TOPLEFT", ui.strip, "TOPRIGHT")
	tip:SetSize(PLAQUE_END, PLAQUE_H)
	local gloss = plaque:CreateTexture(nil, "ARTWORK", nil, 1)
	gloss:SetTexture(UI.GLOSS)
	gloss:SetPoint("TOPLEFT", ui.strip, "TOPLEFT", 2, -2)
	gloss:SetPoint("TOPRIGHT", ui.strip, "TOPRIGHT", 2, -2)
	gloss:SetHeight(PLAQUE_H / 2 - 2)
	gloss:SetAlpha(0.18)
	ui.name = Shadowed(plaque:CreateFontString(nil, "OVERLAY"))
	ui.name:SetFontObject(UI.NameFont(16))
	UI.Ink(ui.name, C.head)
	ui.name:SetPoint("LEFT", ui.strip, "LEFT", 22, -0.8)
	ui.name:SetWordWrap(false)
	local shade = Art(plaque, "TalkRingShade", "ARTWORK", 1, INK.black, 0.8)
	shade:SetSize(RING * 1.48, RING * 1.48)
	shade:SetPoint("CENTER", plaque, "LEFT", -12 + RING / 2, 0)
	local ring = Art(plaque, "TalkRing", "ARTWORK", 2, Theme.skin.metal)
	ui.ring = ring
	ring:SetSize(RING, RING)
	ring:SetPoint("CENTER", shade, "CENTER")
	ui.mark = Shadowed(plaque:CreateFontString(nil, "OVERLAY"))
	UI.TitleFace(ui.mark, 19)
	UI.Ink(ui.mark, C.alert)
	ui.mark:SetPoint("CENTER", ring, "CENTER")
	ui.glyph = plaque:CreateTexture(nil, "OVERLAY")
	ui.glyph:SetSize(15, 15)
	ui.glyph:SetPoint("CENTER", ring, "CENTER", 0, 0)
	Shy.Hover.Glyph(ui.glyph, "talk")
	UI.Tint(ui.glyph, C.hot)
	ui.glyph:Hide()
	plaque.art = { tip = tip, gloss = gloss, strip = ui.strip }
	return plaque
end

local function BuildSpeech(box)
	-- The words: a click reads on, a right-click goes back, the wheel turns pages.
	local reader = CreateFrame("Frame", nil, box)
	ui.reader = reader
	reader:SetPoint("TOPLEFT", box, "TOPLEFT", TEXT_X - 12, -(TEXT_Y - 6))
	reader:SetSize(TEXT_W + 30, 120)
	reader:SetFrameLevel(box:GetFrameLevel() + 2)
	reader:EnableMouse(true)
	reader:EnableMouseWheel(true)
	reader:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" then Advance(false) elseif button == "RightButton" then Back() end
	end)
	reader:SetScript("OnMouseWheel", function(_, delta)
		if delta > 0 then Back() else Advance(false) end
	end)
	local text = Shadowed(reader:CreateFontString(nil, "OVERLAY"))
	text:SetFontObject(UI.TextFont(math.floor(16 * I.TextSize() + 0.5)))
	UI.Ink(text, C.text)
	text:SetPoint("TOPLEFT", box, "TOPLEFT", TEXT_X, -TEXT_Y)
	text:SetWidth(TEXT_W)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetSpacing(2)
	text:SetWordWrap(true)
	ui.text = text

	-- Their foot: back, a pip a page, forward; the key that reads on.
	local foot = CreateFrame("Frame", nil, reader)
	ui.foot = foot
	foot:SetSize(TEXT_W, 1)
	foot:SetPoint("TOPLEFT", box, "TOPLEFT", TEXT_X, -200)
	ui.back = Chevron(reader)
	ui.back:SetPoint("CENTER", foot, "LEFT", 4, 0)
	ui.back:SetScript("OnClick", Back)
	ui.pips = {}
	for i = 1, PIPS do
		local pip = CreateFrame("Button", nil, reader)
		pip:SetSize(12, 12)
		pip:SetPoint("CENTER", foot, "LEFT", 18 + (i - 1) * PIP, 0)
		pip.halo = Light(pip, "Glow", "ARTWORK", 0)
		pip.halo:SetSize(16, 16)
		pip.halo:SetPoint("CENTER")
		pip.halo:SetAlpha(0.55)
		pip.art = Art(pip, "TalkPip", "ARTWORK", 1, INK.grey)
		pip.art:SetAllPoints()
		pip:SetScript("OnClick", function()
			Settle("enter")
			if i <= #s.pages and Readable(s.pages[i]) then ShowPage(i) end
		end)
		pip:Hide()
		ui.pips[i] = pip
	end
	ui.next = Chevron(reader, true)
	ui.next.lit = true
	ui.next:SetScript("OnClick", function() Advance(false) end)
	-- Space's key, lit as Space's always is: a click on it is Space.
	ui.hint = Key(reader, "Space")
	ui.hint:Fit()
	ui.hint:Look("lit")
	ui.hint:EnableMouse(true)
	ui.hint:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self:IsMouseOver() then Advance(true) end
	end)
	ui.hintText = Shadowed(reader:CreateFontString(nil, "OVERLAY"))
	ui.hintText:SetFontObject(UI.TextFont(12))
	UI.Ink(ui.hintText, C.dim)
	ui.hintText:SetWordWrap(false)
	ui.hint:HookScript("OnShow", function() ui.hintText:Show() end)
	ui.hint:HookScript("OnHide", function() ui.hintText:Hide() end)
	-- Skip's cap, beside Read on: a click on it is Shift+Space.
	ui.skip = Key(reader, "Shift+Space")
	ui.skip:Fit()
	ui.skip:EnableMouse(true)
	ui.skip:SetPoint("LEFT", ui.hintText, "RIGHT", 18, 0)
	ui.skip:Look("idle")
	ui.skip:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self:IsMouseOver() then Skip() end
	end)
	ui.skipText = Shadowed(reader:CreateFontString(nil, "OVERLAY"))
	ui.skipText:SetFontObject(UI.TextFont(12))
	UI.Ink(ui.skipText, C.dim)
	ui.skipText:SetWordWrap(false)
	ui.skipText:SetText("Skip")
	ui.skipText:SetPoint("LEFT", ui.skip, "RIGHT", 7, 0)
	ui.skip:HookScript("OnShow", function() ui.skipText:Show() end)
	ui.skip:HookScript("OnHide", function() ui.skipText:Hide() end)
	ui.skip:Hide()
	-- The voice's key, at the foot's right end while a line of this talk is said or stopped (ui.Voice): a
	-- click stops it, or plays it again from its start.
	ui.voice = Key(reader, "Stop voice")
	ui.voice:Fit()
	ui.voice:EnableMouse(true)
	ui.voice:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
	ui.voice:Look("idle")
	ui.voice:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self:IsMouseOver() then Shy.Voice.Toggle(s.pageAt) end
	end)
	ui.voice:Hide()
	-- In its place on a quest page no voice pack has (ui.Missing): a quiet word saying so, and where the page's
	-- text can be sent to be voiced, a key that opens the voice addon's own box for it.
	ui.contribute = Key(reader, "Contribute")
	ui.contribute:Fit()
	ui.contribute:EnableMouse(true)
	ui.contribute:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
	ui.contribute:Look("idle")
	ui.contribute:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self:IsMouseOver() then Shy.Voice.Contribute() end
	end)
	UI.Help(ui.contribute, "Contribute", "Sends this page's text so it can be voiced.")
	ui.contribute:Hide()
	ui.missing = Shadowed(reader:CreateFontString(nil, "OVERLAY"))
	ui.missing:SetFontObject(UI.TextFont(12))
	UI.Ink(ui.missing, C.dim)
	ui.missing:SetWordWrap(false)
	ui.missing:SetText("No voice yet")
	ui.missing:Hide()

	-- The hairline under them, fading to the right.
	ui.rule = Wash(box, "ARTWORK", 0, INK.white, 0.07)
	ui.rule:SetPoint("TOPLEFT", box, "TOPLEFT", TEXT_X, -230)
	ui.rule:SetSize(TEXT_W, 1)
end

local function BuildAnswers(box)
	-- Your answers under the words.
	local body = CreateFrame("Frame", nil, box)
	ui.body = body
	body:SetPoint("TOPLEFT", box, "TOPLEFT", TEXT_X, -240)
	body:SetSize(TEXT_W, 1)
	body:SetFrameLevel(box:GetFrameLevel() + 2)
	ui.title = Shadowed(body:CreateFontString(nil, "OVERLAY"))
	ui.title:SetFontObject(UI.NameFont(18))
	UI.Ink(ui.title, C.text)
	ui.title:SetWidth(TEXT_W - 60)
	ui.title:SetJustifyH("LEFT")
	ui.title:SetWordWrap(false)
	ui.level = Shadowed(body:CreateFontString(nil, "OVERLAY"))
	ui.level:SetFontObject(UI.NameFont(13))
	UI.Ink(ui.level, C.alert)
	ui.level:SetPoint("BOTTOMLEFT", ui.title, "BOTTOMRIGHT", 10, 1)
	ui.level:Hide()
	-- An offered quest an addon wouldn't have you take (Talk.Note): its words under the title, after a skip glyph.
	ui.offGlyph = body:CreateTexture(nil, "OVERLAY")
	ui.offGlyph:SetSize(12, 12)
	ui.offGlyph:SetPoint("TOPLEFT", ui.title, "BOTTOMLEFT", 1, -7)
	local skip = UI.MenuGlyph("skip")[1]
	ui.offGlyph:SetTexture(skip[1])
	ui.offGlyph:SetTexCoord(unpack(skip.coords))
	ui.offGlyph:Hide()
	ui.off = Shadowed(body:CreateFontString(nil, "OVERLAY"))
	ui.off:SetFontObject(UI.TextFont(12))
	ui.off:SetPoint("LEFT", ui.offGlyph, "RIGHT", 4, 0)
	ui.off:Hide()
	ui.money = Shadowed(body:CreateFontString(nil, "OVERLAY"))
	ui.money:SetFontObject(UI.TextFont(13))
	UI.Ink(ui.money, C.text)
	ui.money:Hide()
	ui.xp = Shadowed(body:CreateFontString(nil, "OVERLAY"))
	ui.xp:SetFontObject(UI.TextFont(13))
	UI.Ink(ui.xp, C.dim)
	ui.xp:SetPoint("LEFT", ui.money, "RIGHT", 20, 0)
	ui.xp:Hide()
	ui.rows, ui.tiles, ui.chips, ui.lines, ui.caps, ui.goals, ui.arrivals = {}, {}, {}, {}, {}, {}, {}
	ui.buttons = { NewButton(body, 1), NewButton(body, 2) }
	return body
end

function Build()
	if ui.box then return end
	local box = Shy.HUD.Create({
		id = "shytalk.stage", title = "Quest dialog", width = WIDTH, height = 2 * R,
		point = { "TOP", "BOTTOM", -90, 300 + LINE },
		shown = function() return s.make == "stage" and (s.open or s.leaving ~= nil) end,
		window = true, hang = true, name = "ShyTalkDialog",
	})
	ui.box = box
	box:SetFrameStrata("HIGH")
	box:SetToplevel(true)
	-- The rest of the screen fades while a talk is up; this stays.
	box:SetIgnoreParentAlpha(true)
	table.insert(UISpecialFrames, "ShyTalkDialog")
	-- Esc (or anything else) closed it: the talk ends, as the game's window ends it. Hidden with the
	-- whole interface, it is still up.
	box:SetScript("OnHide", function(self)
		if self:IsShown() or not s.open then return end
		Shut()
		if s.kind then Close() end
	end)

	local stage = BuildStage(box)
	BuildSeal(box)
	BuildPlaque(box)
	BuildSpeech(box)
	local answer = BuildAnswers(box)
	Repaint()
	Shy:On("SHY_THEME", Repaint)
	-- In a look that dresses the stage its own way, its pieces stand in housings of that look (Stage.lua).
	if Shy.Stage then Shy.Stage.Talk(box, ui, { line = LINE, nameX = NAME_X, plaqueEnd = PLAQUE_END,
		nameAt = { 22, -0.8 }, nameSize = 16 }) end

	-- Its pieces by name, for whoever looks at it.
	local speech = ui.reader
	box.stage, box.speech, box.answer, box.keys, box.animator = stage, speech, answer, ui.keys, animator
	speech.name, speech.words, speech.model, speech.emblem, speech.pips = ui.name, ui.text, ui.model, ui.emblem, ui.pips
	speech.hint, speech.hintText, speech.back, speech.next, speech.reader = ui.hint, ui.hintText, ui.back, ui.next, ui.reader
	speech.skip, speech.skipText = ui.skip, ui.skipText
	speech.voice, speech.contribute, speech.missing = ui.voice, ui.contribute, ui.missing
	speech.sealLight, speech.seal, speech.plaque, speech.mark, speech.gleam = ui.sealLight, ui.seal, ui.plaque, ui.mark, ui.gleam
	speech.rim, speech.ring = ui.rim, ui.ring
	speech.foot = ui.foot
	answer.title, answer.level, answer.buttons, answer.rows, answer.tiles, answer.chips = ui.title, ui.level, ui.buttons, ui.rows, ui.tiles, ui.chips
	answer.off = ui.off
	answer.goals, answer.money, answer.xp, answer.caps = ui.goals, ui.money, ui.xp, ui.caps
	answer.Sign = function() return ui.sign end
end

-- The window
-- Quest text that isn't immersive, while ShySkin's quest windows are on (Talk.Window): the same talk in a window of the
-- family's that flows (dragged by a corner or a side it is laid again at that size, never scaled). Under its header,
-- which names the speaker, a band: their face in a slot with the page's mark at its corner, and what the page is about
-- (the quest's title and level, an addon's word on it and the pills of Talk.Facts; on a list, who the speaker is or
-- where you are, and what waits there). The words and the answers scroll between the band and the foot. The foot is a
-- hover's foot (a floor with a groove along its top): the voice's keys at its left end, the buttons at its right, the
-- page's answer last and Space's cap before the button Space gives. Everything the stage does is done here too: the
-- words read out a page at a time and lit as the voice says them, the keys, the suggested reward. Instant quest text shows each page whole.

W.TONE = { good = C.good, bad = C.bad, alert = C.alert, hot = C.hot }

-- The window's words stand a size under the stage's: a window is read closer, and narrow it must hold its lines.
function W.Smaller()
	return s.make == "window" and 1 or 0
end

-- The quest's own words: the stage's 16, the window's a little smaller again (WIN.text).
function W.Words()
	return s.make == "window" and WIN.text or 16
end

-- The shell: the make of the talk's window, on the talk's own (W.Build) and on a window of another addon's that
-- carries a talk on (ShySkin's vendor), so the two are the same to the unit and one can take the other's place
-- (Talk.Yield) with nothing in the band moving. The band under the header (your color's wash, a groove along its
-- foot), the speaker's square in it with the page's mark on its corner, the band's two lines and its pills, the foot
-- (a hover's: its floor under a groove and a lip of light) and the plain reading ground between the two.
--   local shell = Shy.Talk.Shell(win)     -- win: a UI.Window
--   shell.band, shell.foot, shell.ground (its color: ground.fill)
--   shell.face, shell.rim (what stands over a model), shell.slot, shell.emblem (shown for a speaker with no head)
--   shell.badge, shell.ring, shell.mark, shell.glyph    -- the page's mark; shell:Sign(letter, color) writes it, and
--                                         -- shell:Sign(nil, nil, name) shows one of Shy.Hover's glyphs there
--   shell.left                            -- where the band's words start, past the face
--   shell.role, shell.sub                 -- its two lines
--   shell.pills; shell:Pills(facts, y, from) -> shown   -- { { text, tone } } as pills at y, from shell.left (or
--                                         -- `from`, past something of yours on their line), as many as fit (tone:
--                                         -- "good", "bad", "alert", "hot" or none); nil puts them all away
--   shell:Head(unit) -> shown             -- the unit's head in the face (a model of the shell's own, shell.model,
--                                         -- framed and lit as the talk's), else the emblem; nil for nobody
--   shell:Who(unit)                       -- the line under the unit's name on its tooltip ("Trade Supplies"), or ""
--   shell:Answers(buttons, taken) -> x    -- UI.Buttons in the foot from its right end: the first filled, the rest
--                                         -- their words alone, each at its least width when short of room (taken:
--                                         -- what the foot's left end holds). x: where they end, from the foot's right.
--                                         -- Words stand in the middle of their button; button.keep is a width one
--                                         -- is held to while its words change, so nothing beside it moves
-- Shy.Talk.WIN: its measures (w, h, least, band, face, foot, pad, button, between, quiet, key, pill, pillGap).
W.Shelled = {}

-- Lit from the front and a little from the side, over a soft fill, so the face reads in the dark well
-- rather than standing in it as a shadow.
function W.Light()
	ui.headLight = ui.headLight or { omnidirectional = false, point = CreateVector3D(-1, 0.4, -0.3),
		ambientIntensity = 0.75, ambientColor = CreateColor(0.8, 0.8, 0.8),
		diffuseIntensity = 0.7, diffuseColor = CreateColor(1, 0.97, 0.92) }
	return ui.headLight
end

-- The camera on a model in a window's face: head and shoulders, straight on.
function W.Camera(model)
	model:SetPortraitZoom(WIN.zoom)
	model:SetRotation(0)
	model:SetLight(true, W.Light())
end

function W.Shell(win)
	local shell = setmetatable({ win = win, pills = {} }, { __index = W.Shelled })
	local head0 = UI.HEAD.window.line + UI.LINE
	-- The band and the foot stand on the window's body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(win)

	-- The band: your color's wash from the left over the window's ground, a groove along its foot.
	local band = CreateFrame("Frame", nil, win)
	band:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -head0)
	band:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -head0)
	band:SetHeight(WIN.band)
	band:SetFrameLevel(win:GetFrameLevel() + 2)
	shell.band = band
	Wash(band, "BACKGROUND", 1, Theme.Accent, 0.12):SetAllPoints()
	local groove = band:CreateTexture(nil, "BORDER")
	groove:SetColorTexture(0, 0, 0, 0.85)
	groove:SetPoint("BOTTOMLEFT")
	groove:SetPoint("BOTTOMRIGHT")
	groove:SetHeight(1)
	local lip = band:CreateTexture(nil, "BORDER")
	lip:SetColorTexture(1, 1, 1, 0.07)
	lip:SetPoint("BOTTOMLEFT", 0, 1)
	lip:SetPoint("BOTTOMRIGHT", 0, 1)
	lip:SetHeight(1)

	-- The face: the model in a dark well, the slot's frame and the page's mark over it. A model draws over every texture
	-- of its own strata, so what stands over it is a strata up.
	local face = CreateFrame("Frame", nil, band)
	face:SetSize(WIN.face, WIN.face)
	face:SetPoint("LEFT", WIN.pad, 0)
	local well = face:CreateTexture(nil, "BACKGROUND")
	well:SetAllPoints()
	well:SetColorTexture(0, 0, 0, 0.6)
	shell.face = face
	local rim = CreateFrame("Frame", nil, face)
	rim:SetAllPoints()
	rim:SetFrameStrata(win:GetFrameStrata() == "HIGH" and "DIALOG" or "HIGH")
	shell.rim = rim
	shell.slot = Shy.Slot.New(rim, { well = false, hover = false })
	shell.emblem = rim:CreateTexture(nil, "ARTWORK")
	Shy.Hover.Glyph(shell.emblem, "note")
	UI.Tint(shell.emblem, C.head, 0.55)
	shell.emblem:SetSize(30, 30)
	shell.emblem:SetPoint("CENTER")
	shell.emblem:Hide()
	-- The page's mark sits on the slot's corner, over its frame: a frame of its own a level up, since the slot's
	-- pieces are the rim's own textures and would draw over anything else of the rim's.
	local badge = CreateFrame("Frame", nil, rim)
	badge:SetAllPoints()
	badge:SetFrameLevel(rim:GetFrameLevel() + 2)
	shell.badge = badge
	local shade = Art(badge, "TalkRingShade", "ARTWORK", 1, INK.black, 0.8)
	shade:SetSize(WIN.ring * 1.48, WIN.ring * 1.48)
	shade:SetPoint("CENTER", face, "BOTTOMRIGHT", -2, 2)
	local ring = Art(badge, "TalkRing", "ARTWORK", 2, Theme.skin.metal)
	ring:SetSize(WIN.ring, WIN.ring)
	ring:SetPoint("CENTER", shade, "CENTER")
	shell.ring = ring
	shell.mark = Shadowed(badge:CreateFontString(nil, "OVERLAY"))
	UI.TitleFace(shell.mark, 15)
	shell.mark:SetPoint("CENTER", ring, "CENTER")
	shell.glyph = badge:CreateTexture(nil, "OVERLAY")
	shell.glyph:SetSize(12, 12)
	shell.glyph:SetPoint("CENTER", ring, "CENTER")
	Shy.Hover.Glyph(shell.glyph, "talk")
	UI.Tint(shell.glyph, C.hot)
	shell.glyph:Hide()

	-- The band's words, past the face: on a list, who the speaker is (or where you are) and what waits there.
	shell.left = WIN.pad + WIN.face + 14
	shell.role = Shadowed(band:CreateFontString(nil, "OVERLAY"))
	shell.role:SetFontObject(UI.NameFont(17))
	UI.Ink(shell.role, C.head)
	shell.role:SetPoint("TOPLEFT", band, "TOPLEFT", shell.left, -18)
	shell.role:SetJustifyH("LEFT")
	shell.role:SetWordWrap(false)
	shell.sub = Shadowed(band:CreateFontString(nil, "OVERLAY"))
	shell.sub:SetFontObject(UI.TextFont(12))
	UI.Ink(shell.sub, C.dim)
	shell.sub:SetPoint("TOPLEFT", shell.role, "BOTTOMLEFT", 0, -7)
	shell.sub:SetJustifyH("LEFT")
	shell.sub:SetWordWrap(false)

	-- The foot: a hover's foot, its floor under a groove and a lip of light.
	local foot = CreateFrame("Frame", nil, win)
	foot:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 2, 2)
	foot:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
	foot:SetHeight(WIN.foot)
	foot:SetFrameLevel(win:GetFrameLevel() + 6)
	shell.foot = foot
	local floor = foot:CreateTexture(nil, "BACKGROUND")
	floor:SetAllPoints()
	floor:SetColorTexture(0, 0, 0, 0.30)
	local top = foot:CreateTexture(nil, "BORDER")
	top:SetColorTexture(0, 0, 0, 0.85)
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(1)
	local shine = foot:CreateTexture(nil, "BORDER")
	shine:SetColorTexture(1, 1, 1, 0.07)
	shine:SetPoint("TOPLEFT", 0, -1)
	shine:SetPoint("TOPRIGHT", 0, -1)
	shine:SetHeight(1)

	-- The reading ground: the look keeps the frame, the band and the foot; the words and the answers stand on the
	-- window's own plain color, never on a look's art.
	local ground = CreateFrame("Frame", nil, win)
	ground:SetPoint("TOPLEFT", band, "BOTTOMLEFT")
	ground:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
	ground:SetFrameLevel(win:GetFrameLevel() + 1)
	ground.fill = ground:CreateTexture(nil, "BACKGROUND")
	ground.fill:SetAllPoints()
	UI.Paint(ground.fill, C.panel, 1)
	shell.ground = ground
	return shell
end

-- The page's mark: a letter ("!", "?") in a color, or a glyph (the talk's own unless named).
function W.Shelled:Sign(mark, color, glyph)
	self.mark:SetShown(mark ~= nil)
	self.glyph:SetShown(mark == nil)
	self.mark:SetText(mark or "")
	-- Centred by its ink, not its advance: the "!" stands a little left of its own box.
	self.mark:SetPoint("CENTER", self.ring, "CENTER", mark == "!" and 1 or 0, 0)
	if mark then UI.Ink(self.mark, color) end
	if glyph and glyph ~= self.glyphName then
		self.glyphName = glyph
		Shy.Hover.Glyph(self.glyph, glyph)
	end
end

-- Facts as pills along the band from its words' start, as many as fit its width; the rest are left out.
function W.Shelled:Pills(facts, y, from)
	local shown = 0
	local x = from or self.left
	local room = W.Width0(self.win) - 4 - WIN.pad   -- (the band's width, from the window's: the band is laid later)
	for _, fact in ipairs(facts or {}) do
		if type(fact.text) == "string" and fact.text ~= "" then
			local pill = self.pills[shown + 1]
			if not pill then
				pill = CreateFrame("Frame", nil, self.band)
				pill:SetHeight(WIN.pill)
				pill.fill = pill:CreateTexture(nil, "BACKGROUND")
				pill.fill:SetAllPoints()
				pill.edge = pill:CreateTexture(nil, "BORDER")
				pill.edge:SetPoint("TOPLEFT")
				pill.edge:SetPoint("BOTTOMLEFT")
				pill.edge:SetWidth(2)
				pill.text = Shadowed(pill:CreateFontString(nil, "OVERLAY"))
				pill.text:SetFontObject(UI.TextFont(11))
				pill.text:SetPoint("LEFT", 8, 0)
				pill.text:SetWordWrap(false)
				self.pills[shown + 1] = pill
			end
			pill.text:SetText(fact.text)
			local wide = math.ceil(pill.text:GetStringWidth() + 16)
			if x + wide > room then break end
			shown = shown + 1
			local tone = W.TONE[fact.tone]
			UI.Paint(pill.fill, tone or C.text, tone and 0.16 or 0.07)
			UI.Paint(pill.edge, tone or C.dim, 0.9)
			UI.Ink(pill.text, tone or C.text)
			pill:SetWidth(wide)
			pill:ClearAllPoints()
			pill:SetPoint("TOPLEFT", self.band, "TOPLEFT", x, y)
			pill:Show()
			x = x + wide + WIN.pillGap
		end
	end
	for i = shown + 1, #self.pills do self.pills[i]:Hide() end
	return shown
end

-- Who a unit is beyond its name: the line under it on its tooltip ("Innkeeper", "Trade Supplies"), else "".
function W.Shelled:Who(unit)
	if not unit then return "" end
	local ok, text = pcall(function()
		local data = C_TooltipInfo.GetUnit(unit)
		local line = data and data.lines and data.lines[2]
		return line and line.leftText
	end)
	if not ok or type(text) ~= "string" or issecretvalue(text) or text == "" or text:find(LEVEL, 1, true) then return "" end
	return text
end

-- The unit's head in the face, in a model of the shell's own (the talk's window lends its own instead: W.Make).
-- Asked while the model is shown, and again whenever it shows: hidden, a model neither takes a unit nor keeps one.
function W.Shelled:Head(unit)
	local model = self.model
	if not model then
		model = CreateFrame("PlayerModel", nil, self.face)
		model:SetPoint("TOPLEFT", self.face, "TOPLEFT", 1, -1)
		model:SetPoint("BOTTOMRIGHT", self.face, "BOTTOMRIGHT", -1, 1)
		model:SetFrameLevel(self.face:GetFrameLevel() + 1)
		model:SetKeepModelOnHide(true)
		model:SetScript("OnShow", function() self:Head(self.unit) end)
		model:SetScript("OnModelLoaded", W.Camera)
		self.model = model
	end
	self.unit = unit
	local shown = false
	if unit and model:IsVisible() then
		local exists = UnitExists(unit)
		local withheld = C_Secrets.ShouldUnitIdentityBeSecret(unit)
		if not issecretvalue(exists) and exists and not issecretvalue(withheld) and not withheld then
			local ok, set = pcall(model.SetUnit, model, unit)
			shown = ok and (issecretvalue(set) or set ~= false)
		end
	end
	if shown then W.Camera(model) else model:ClearModel() end
	self.emblem:SetShown(not shown)
	return shown
end

-- UI.Buttons in the foot, from its right end: the first is the page's answer, filled; the others are their words
-- alone. Short of room each takes the width of its words.
function W.Shelled:Answers(buttons, taken)
	local gap = WIN.between
	local room = W.Width0(self.win) - 4 - 2 * WIN.button - (taken or 0)
	local need = 0
	for i, b in ipairs(buttons) do
		local quiet = i > 1
		b:SetPrimary(not quiet)
		b:SetBare(quiet)
		local wide = b.text:GetUnboundedStringWidth()
		wide = (issecretvalue(wide) or not wide) and 0 or math.ceil(wide)
		local keep = b.keep or 0
		b.full = quiet and (wide + 2 * WIN.quiet) or max(96, wide + 34, keep)
		b.least = quiet and b.full or max(wide + 22, keep - 12)
		need = need + b.full + (i > 1 and gap or 0)
	end
	local least = need > room
	local right = -WIN.button
	for _, b in ipairs(buttons) do
		b:SetWidth(least and b.least or b.full)
		b.text:SetWidth(b:GetWidth() - 8)
		b.text:SetWordWrap(false)
		b.text:SetJustifyH("CENTER")
		b:ClearAllPoints()
		b:SetPoint("RIGHT", self.foot, "RIGHT", right, 0)
		b:Show()
		right = right - b:GetWidth() - gap
	end
	return right
end

function W.Build()
	if W.win then return end
	local win = UI.Window({
		id = "shytalk.window", name = "ShyTalkWindow", title = "", width = WIN.w, height = WIN.h,
		point = { "TOPLEFT", "TOPLEFT", 16, -116 },
		shown = function() return s.make == "window" and (s.open or s.leaving ~= nil) end,
		head = { size = "window", title = " " },
		grip = { flow = function() W.Flow() end, min = { WIN.least[1], WIN.least[2] } },
		-- Closed (its ×, Esc): the talk ends, as the game's window ends it.
		onClose = function()
			if not s.open then return end
			Shut()
			if s.kind then Close() end
		end,
	})
	W.win = win
	-- Its band, face, foot and ground: the shell's.
	local shell = W.Shell(win)
	W.shell = shell
	local band, foot, face, ground = shell.band, shell.foot, shell.face, shell.ground
	W.band, W.foot, W.face, W.ground = band, foot, face, ground
	W.rim, W.slot, W.emblem, W.badge, W.ring, W.mark, W.glyph = shell.rim, shell.slot, shell.emblem, shell.badge, shell.ring, shell.mark, shell.glyph
	W.left, W.role, W.sub, W.pills = shell.left, shell.role, shell.sub, shell.pills

	-- The voice's key at the foot's left end (W.VoiceKeys).
	local voice = CreateFrame("Button", nil, foot)
	voice:SetSize(WIN.voice, WIN.voice)
	voice:SetPoint("LEFT", foot, "LEFT", WIN.button - 4, 0)
	voice.glyph = voice:CreateTexture(nil, "ARTWORK")
	voice.glyph:SetTexture(Shy.Skin.GLYPH.voice)
	voice.glyph:SetSize(12, 12)
	voice.glyph:SetPoint("CENTER")
	voice:SetScript("OnClick", function()
		if W.state then Shy.Voice.Toggle(s.pageAt) elseif s.contribute then Shy.Voice.Contribute() end
	end)
	voice:HookScript("OnEnter", function(self) self.over = true W.VoiceInk() end)
	voice:HookScript("OnLeave", function(self) self.over = false W.VoiceInk() end)
	UI.Help(voice, function()
		if W.state == "speaking" then return "Stop voice" end
		if W.state then return "Play voice" end
		return "No voice yet"
	end, function()
		if not W.state and s.contribute then return "Click to send this page's text so it can be voiced." end
	end)
	voice:Hide()
	W.voice = voice

	-- The words and the answers, scrolling between the band and the foot.
	local area = UI.ScrollArea(win, WIN.w, WIN.h, { smooth = true, shades = C.panel })
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", band, "BOTTOMLEFT", WIN.pad - 2, -2)
	area:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -6, 2)
	area:SetFrameLevel(win:GetFrameLevel() + 3)
	W.area, W.sheet = area, area.content

	-- The page under the words (W.Surface): a card a shade off the ground, or the quest's own paper laid to cover it.
	local page = UI.PaperPage(W.sheet, { feather = WIN.feather })
	page:SetFrameLevel(W.sheet:GetFrameLevel() + 1)
	W.page = page
	win.page, win.ground = page, ground

	-- Its pieces by name, for whoever looks at it.
	win.band, win.foot, win.face, win.area = band, foot, face, area
	win.role, win.sub, win.mark, win.pills, win.emblem = W.role, W.sub, W.mark, W.pills, W.emblem
	win.voice = W.voice
end

-- The column the words and the answers stand in, at the window's width now.
function W.Width()
	if s.make ~= "window" or not W.win then return end
	local wide = UI.BodySize(W.win)   -- (its body's: UI.Body)
	if issecretvalue(wide) or not wide or wide <= 0 then wide = WIN.w end
	local area = math.floor(wide - (WIN.pad - 2) - 2 - 6 - 2)   -- band's inset, the area's left, its right, the foot's
	local sheet = area - WIN.bar
	local column = sheet - 2 * WIN.inset
	ui.w = column
	W.sheet:SetWidth(sheet)
	ui.text:SetWidth(column)
	ui.reader:SetWidth(column + 30)
	ui.foot:SetWidth(column)
	ui.rule:SetWidth(column)
	ui.body:SetWidth(column)
	local words = max(80, wide - W.left - WIN.pad - 4)
	ui.title:SetWidth(words - 40)   -- the level stands after it
	W.role:SetWidth(words)
	W.sub:SetWidth(words)
end

-- How the talk is worn: its pieces handed between the stage and the window.
function W.Make(make)
	if W.made == make then return end
	if make == "stage" and not W.win then
		W.made = make   -- (the stage is how it was built)
		return
	end
	W.made = make
	local window = make == "window"
	if window then W.Build() end
	local sheet = window and W.sheet or ui.box
	ui.reader:SetParent(sheet)
	ui.rule:SetParent(sheet)
	ui.body:SetParent(sheet)
	ui.reader:SetFrameLevel(sheet:GetFrameLevel() + 2)
	ui.body:SetFrameLevel(sheet:GetFrameLevel() + 2)
	local x, y = window and WIN.inset or TEXT_X, window and WIN.top or TEXT_Y
	ui.rule:SetShown(not window)   -- (in the window the page's edge parts the words from the answers)
	ui.text:ClearAllPoints()
	ui.text:SetPoint("TOPLEFT", sheet, "TOPLEFT", x, -y)
	ui.reader:ClearAllPoints()
	ui.reader:SetPoint("TOPLEFT", sheet, "TOPLEFT", x - 12, -(y - 6))
	-- The wheel scrolls the window; pages turn by a click, the chevrons, Space and Backspace.
	ui.reader:EnableMouseWheel(not window)
	-- The buttons and the voice's keys stand in the foot.
	local foot = window and W.foot or ui.body
	for _, b in ipairs(ui.buttons) do
		b:SetParent(foot)
		b:SetFrameLevel(foot:GetFrameLevel() + 2)
	end
	local keys = window and W.foot or ui.reader
	for _, k in ipairs({ ui.voice, ui.contribute }) do
		k:SetParent(keys)
		k:SetFrameLevel(keys:GetFrameLevel() + 2)
		k:ClearAllPoints()
	end
	ui.missing:SetParent(keys)
	if window then
		ui.voice:SetPoint("LEFT", W.foot, "LEFT", WIN.button, 0)
		ui.contribute:SetPoint("LEFT", ui.missing, "RIGHT", 7, 0)
	else
		ui.voice:SetPoint("RIGHT", ui.foot, "RIGHT", 0, 0)
		ui.contribute:SetPoint("RIGHT", ui.foot, "RIGHT", 0, 0)
	end
	-- The quest's title heads the band.
	for _, region in ipairs({ ui.title, ui.level, ui.offGlyph, ui.off }) do region:SetParent(window and W.band or ui.body) end
	-- The speaker's face.
	ui.model:SetParent(window and W.face or ui.under)
	ui.model:ClearAllPoints()
	if window then
		ui.model:SetPoint("TOPLEFT", W.face, "TOPLEFT", 1, -1)
		ui.model:SetPoint("BOTTOMRIGHT", W.face, "BOTTOMRIGHT", -1, 1)
	else
		ui.model:SetAllPoints()
	end
	ui.model:SetFrameLevel(ui.model:GetParent():GetFrameLevel() + 1)
	ui.text:SetFontObject(UI.TextFont(math.floor(W.Words() * I.TextSize() + 0.5)))
	if window then
		W.Width()
	else
		for _, b in ipairs(ui.buttons) do
			b.fill:SetAlpha(1)
			b.edge:SetAlpha(1)
		end
		if W.voice then W.voice:Hide() end
		-- On the stage the words stand on its wash: inked for the panel's color it is made of.
		UI.FaceInk(ui.text, ui.box, C.panel, C.text)
		UI.FaceInk(ui.hintText, ui.box, C.panel, C.dim)
		UI.FaceInk(ui.skipText, ui.box, C.panel, C.dim)
		ui.w = TEXT_W
		ui.text:SetWidth(TEXT_W)
		ui.reader:SetWidth(TEXT_W + 30)
		ui.foot:SetWidth(TEXT_W)
		ui.rule:SetWidth(TEXT_W)
		ui.body:SetWidth(TEXT_W)
		ui.title:SetWidth(TEXT_W - 60)
	end
end

-- A new page: the window's column at its width, the scroll at the top.
function W.Page()
	if s.make ~= "window" or not W.win then return end
	W.keys = nil
	W.Width()
	W.area:SetVerticalScroll(0)
end


function W.Name(name)
	if not W.win then return end
	Say(W.win.head.title, name)
end

function W.Mark(mark, color)
	W.shell:Sign(mark, color, "talk")
end

-- Who the speaker is beyond their name: the line under it on their tooltip ("Innkeeper", "Trade Supplies"), else "".
function W.Role()
	return W.shell:Who(Talk.Speaker(s.kind))
end

-- What waits on a list: "1 to hand in · 2 offered".
function W.Waiting()
	local ready, offered, going = 0, 0, 0
	for i = 1, s.rows do
		local kind = ui.rows[i].kind
		if kind == "?" then ready = ready + 1 elseif kind == "!" then offered = offered + 1 elseif kind == "-" then going = going + 1 end
	end
	local said = {}
	if ready > 0 then said[#said + 1] = ("%d to hand in"):format(ready) end
	if offered > 0 then said[#said + 1] = ("%d offered"):format(offered) end
	if going > 0 then said[#said + 1] = ("%d in progress"):format(going) end
	return table.concat(said, "  ·  ")
end

-- The band: a quest's title, an addon's word on it and the pills; on a list, the speaker and what waits there.
function W.Band()
	local quest = ui.title:IsShown()
	W.role:SetShown(not quest)
	W.sub:SetShown(not quest)
	if quest then
		ui.title:ClearAllPoints()
		ui.title:SetPoint("TOPLEFT", W.band, "TOPLEFT", W.left, -12)
		local list = {}
		local id = GetQuestID()
		if id and not issecretvalue(id) and id > 0 then
			for _, key in ipairs(Ask.facts) do
				local ok, facts = pcall(Ask.facts[key], id, s.kind)
				if ok and type(facts) == "table" then
					for _, fact in ipairs(facts) do list[#list + 1] = fact end
				end
			end
		end
		W.shell:Pills(list, ui.off:IsShown() and -60 or -40)
	else
		W.shell:Pills(nil)
		-- Who they are, else where you are; under it what waits on the list, else where you are. A guard's page of
		-- directions says so, over where you are.
		local role = W.Role()
		local place = GetMinimapZoneText() or ""
		if s.kind == "gossip" and s.directions then
			W.role:SetText("Directions")
			W.sub:SetText(place)
		else
			W.role:SetText(role ~= "" and role or place)
			local waiting = W.Waiting()
			W.sub:SetText(waiting ~= "" and waiting or (role ~= "" and place or ""))
		end
	end
end

-- The foot: one button stands out, the page's answer (Space gives it, as its hover says), at the right end; the other
-- (Decline, Goodbye) is quiet, its words alone, lit under the mouse; the voice is one key at the left end, a speaker
-- that stops or plays the line. Laid again whenever any of them changes (a page, the voice, a new size); short of
-- room the answer gives way to its words' width.
function W.Width0(region)
	local wide = region:IsObjectType("FontString") and region:GetStringWidth() or region:GetWidth()
	if issecretvalue(wide) or not wide then return 0 end
	return wide
end

function W.Foot()
	if not W.win then return end
	local gap = WIN.between
	local room = UI.BodySize(W.win) - 4 - 2 * WIN.button   -- (the foot stands on its body: UI.Body)
	local buttons = {}
	for _, b in ipairs(ui.buttons) do
		if b:IsShown() then buttons[#buttons + 1] = b end
	end
	local need = W.voice:IsShown() and (WIN.voice + gap) or 0
	for i, b in ipairs(buttons) do
		local quiet = i > 1
		b.fill:SetAlpha(quiet and 0 or 1)
		b.edge:SetAlpha(quiet and 0 or 1)
		if quiet then b.light:SetAlpha(0) end
		local wide = W.Width0(b.text)
		b.full = quiet and math.ceil(wide + 2 * WIN.quiet) or max(96, math.ceil(wide + 34))
		b.least = quiet and b.full or math.ceil(wide + 22)
		need = need + b.full + (i > 1 and gap or 0)
	end
	local least = need > room
	local right = -WIN.button
	for _, b in ipairs(buttons) do
		b:SetWidth(least and b.least or b.full)
		Centre(b.text, b)
		b:ClearAllPoints()
		b:SetPoint("RIGHT", W.foot, "RIGHT", right, 0)
		right = right - b:GetWidth() - gap
	end
end

-- The voice's key: lit while a line plays (a click stops it), plain once stopped (a click plays it again), faint on a
-- page no voice pack has (a click sends its text to be voiced, where that can be done).
function W.VoiceInk()
	local key = W.voice
	if key.over then
		UI.Tint(key.glyph, C.hot)
	elseif W.state == "speaking" then
		UI.Tint(key.glyph, C.hot)
	elseif W.state then
		UI.Tint(key.glyph, C.text)
	else
		UI.Tint(key.glyph, C.dim, 0.6)
	end
end

function W.VoiceKeys(state, missing)
	W.state = state
	W.voice:SetShown(state ~= nil or missing)
	W.VoiceInk()
	for _, piece in ipairs({ ui.voice, ui.contribute, ui.missing }) do piece:Hide() end
end

-- Whether the window's controls' row (the pips, the chevrons, Read on) stands under the words: only where there are
-- pages to turn. A single page reads on with Space alone, and its page is as tall as its words.
function W.Turns()
	return #s.pages > 1
end

-- The window's Fit: the words, the controls' row, the rule and the answers down the sheet, the sheet as tall as they
-- are; the band and the foot. The words take their own height, a line at the least.
function W.Fit(answerNeed)
	local top, x = WIN.top, WIN.inset
	local _, line = ui.text:GetFont()
	local words = max(line or WIN.text, ui.textTall)
	local turns = W.Turns()
	local foot = top + words + (turns and (KEY.h / 2 + SPEECH.clear) or 0)
	ui.foot:ClearAllPoints()
	ui.foot:SetPoint("TOPLEFT", W.sheet, "TOPLEFT", x, -foot)
	ui.reader:SetHeight(foot - top + 20)
	-- The page: from over the words to under them, or under the controls' row where it stands; the sheet's width.
	local pageTop, pageFoot = top - WIN.over, foot + (turns and KEY.h / 2 or 0) + WIN.under
	W.page:ClearAllPoints()
	W.page:SetPoint("TOPLEFT", W.sheet, "TOPLEFT", 0, -pageTop)
	W.page:SetSize(W.sheet:GetWidth(), pageFoot - pageTop)
	W.Surface()
	local below = pageFoot + WIN.after
	ui.body:ClearAllPoints()
	ui.body:SetPoint("TOPLEFT", W.sheet, "TOPLEFT", x, -below)
	Mark(s.kind)
	W.sheet:SetHeight(below + answerNeed + WIN.pad)
	W.area:Update()
	W.Band()
	W.Foot()
end

-- A quest's own paper, where it has one and the quest text contrast setting doesn't ask for plain pages: a material
-- (stone, marble, silver, bronze; GetQuestBackgroundMaterial, as the game's window lays it), the quest's theme (a
-- letter's paper: C_QuestLog.GetQuestDetailsTheme), or on a gossip page the speaker's own make (its texture kit).
-- Returns { atlas = file, material } or { material, pieces = true }: material names the ink the words take. nil: our page.
W.MATERIAL = UI.PAPER_TONE

function W.Paper()
	if QuestTextContrast.IsEnabled() then return nil end
	if s.kind == "gossip" then
		local kit = GossipFrame.textureKit
		if not kit or issecretvalue(kit) then return nil end
		local atlas = QuestTextContrast.GetTextureKitBackgroundAtlas(kit)
		if atlas == QuestTextContrast.GetDefaultBackgroundAtlas() then return nil end
		return { atlas = atlas, material = "Parchment" }
	end
	local material = GetQuestBackgroundMaterial()
	if material and not issecretvalue(material) and W.MATERIAL[material] and material ~= "Parchment" then
		return { material = material, pieces = true }
	end
	if s.kind == "greeting" then return nil end
	local id = GetQuestID()
	if not id or issecretvalue(id) or id <= 0 then return nil end
	local theme = C_QuestLog.GetQuestDetailsTheme(id)
	local atlas = type(theme) == "table" and theme.background
	if type(atlas) ~= "string" or issecretvalue(atlas) or atlas == "" or not C_Texture.GetAtlasInfo(atlas) then return nil end
	return { atlas = atlas, material = "Parchment" }
end

-- The page under the words, at the size the window gives it. Our own page: a card a shade off the ground, its edge a
-- hairline. A quest's paper: laid to cover the page (scaled by whichever side asks more, cropped at the other, its top
-- kept), its edges feathered into the page so a crop never shows a cut, whatever size the window flows to. The words
-- are inked for what they stand on (UI.FaceInk): the theme's text on our page, readable on any theme, and the game's
-- ink for that paper on a paper, drawn toward a readable one where it falls short.
function W.Surface()
	local page = W.page
	local paper = W.Paper()
	local face, ink = page:Lay(paper)
	UI.FaceInk(ui.text, page, face, ink)
	UI.FaceInk(ui.hintText, page, face, paper and ink or C.dim)
	UI.FaceInk(ui.skipText, page, face, paper and ink or C.dim)
end

function W.Open()
	W.win:SetAlpha(1)
	Shy.HUD.Update(W.win)
	ui.keys:SetShown(not InCombatLockdown())
	Face()
	ui.reader:SetAlpha(0)
	Tween("enter", PACE.enter / 2, function(k) ui.reader:SetAlpha(Ease(k)) end)
	PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
end

-- Dragged to another size: the column at the new width, the pages measured again in it and the page laid again.
function W.Flow()
	W.Width()
	if not (s.open and s.kind and s.make == "window" and s.shownGen == s.gen) then return end
	ui.textTall = 0
	for _, page in ipairs(s.pages) do ui.textTall = max(ui.textTall, Measure(page)) end
	if s.voiceText then ui.text:SetText(s.voiceText) else Say(ui.text, s.pages[s.page]) end
	Talk.Refresh()
end

-- Deciding what shows

local Decide, Apply

local function Soon(delay)
	local gen = s.gen
	C_Timer.After(delay, function()
		if s.gen == gen then Decide() end
	end)
end

-- Ends a talk the dialog no longer stands in for: the windows go home once closed.
local function Release()
	if s.kind and AnyShown() then Close() end
	Shut()
end

function Decide()
	if s.want ~= s.on then
		if not s.want then Release() end
		Apply()
		return
	end
	if not s.on then return end
	local kind = s.kind
	if not kind then
		Shut(true)
		return
	end
	-- The game kept its window shut (it answered the page itself, or another window is in the way).
	if not Window(kind):IsShown() then return end
	-- A line asked for is picked before the page is shown.
	if kind == "gossip" then Ask.Pick() end
	-- Answered by someone else as it came (or picked for you): wait for what comes of it, but not for ever.
	if s.heardAt and s.heardAt >= s.pageAt then
		local left = PACE.wait - (GetTime() - s.pageAt)
		if left > 0 then
			Soon(left)
			return
		end
	end
	local quest = Shy.addons.Quest
	if quest and quest.TalkWaiting and quest:TalkWaiting() then
		Soon(PACE.look)
		return
	end
	if s.open and s.shownGen == s.gen then return end
	Render()
	Open()
end

function Apply()
	if s.want == s.on then return end
	if AnyShown() then return end   -- tried again as they close
	for _, frame in ipairs(Blizzard()) do
		if s.want then
			home[frame] = frame:GetParent()
			frame:SetParent(attic)
		elseif home[frame] then
			for _, panel in ipairs({ QuestFrameGreetingPanel, QuestFrameDetailPanel, QuestFrameProgressPanel, QuestFrameRewardPanel }) do
				if panel:GetParent() == frame and panel:IsShown() then panel:Hide() end
			end
			FrameUtil.SetParentMaintainRenderLayering(frame, home[frame])
		end
	end
	-- Put away, the game's quest window is never laid out, and its answer to a reward's item loading lays
	-- the rewards out by a layout it was never given: an error on a quest with two rewards side by side,
	-- before any quest was read in the log. Up here it hears no item load (the dialog shows the item itself:
	-- Refresh); home again, it does.
	if s.want then
		QuestFrame:UnregisterEvent("QUEST_ITEM_UPDATE")
	else
		QuestFrame:RegisterEvent("QUEST_ITEM_UPDATE")
	end
	s.on = s.want
	if not s.on then s.kind = nil end
	-- The voice addon's own buttons for the game's windows have no window to stand on while this stands in.
	Shy.Voice.Stood(s.on)
end

local function Want()
	local mode = I.QuestText()
	s.want = mode == "immersive" or s.windowed
	-- Immersive quest text is worn on the stage, any other in the window. A change while a talk is up shows it in
	-- the other at once.
	local make = mode == "immersive" and "stage" or "window"
	if make ~= s.make then
		local up = s.open
		if up then Shut() end
		s.make = make
		if up and s.kind and s.want then
			s.shownGen = nil
			Soon(0)
		end
	end
	if s.want ~= s.on then
		if not s.want then Release() end
		Apply()
	end
end

-- Someone else answered the game. A page that came in the same frame (GetTime is the frame's) is theirs,
-- whichever of us heard the event first. Heard whether or not the dialog stands in: a line asked for is
-- never picked over their answer.
local function Heard()
	if s.mine then return end
	s.heardAt = GetTime()
end

local QUEST = { QUEST_GREETING = "greeting", QUEST_DETAIL = "detail", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "reward" }

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "PLAYER_LOGIN" then
		attic = CreateFrame("Frame", nil, UIParent)
		attic:SetAllPoints(UIParent)   -- the panel manager places a window against its parent's edges
		attic:Hide()
		for _, name in ipairs({ "SelectAvailableQuest", "SelectActiveQuest", "AcceptQuest", "CompleteQuest", "GetQuestReward",
			"CloseQuest", "AcknowledgeAutoAcceptQuest" }) do
			hooksecurefunc(name, Heard)
		end
		for _, name in ipairs({ "SelectOption", "SelectOptionByIndex", "SelectAvailableQuest", "SelectActiveQuest", "CloseGossip" }) do
			hooksecurefunc(C_GossipInfo, name, Heard)
		end
		hooksecurefunc(C_PlayerInteractionManager, "ClearInteraction", Heard)
		-- The game's window, put away, still answers an item loading by showing its rewards; never laid
		-- out in a window, they stand loose on the screen.
		hooksecurefunc("QuestInfo_ShowRewards", function()
			local rewards = QuestInfoFrame.rewardsFrame
			if s.on and rewards and not rewards:GetParent() then rewards:Hide() end
		end)
		Want()
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		if ui.keys then ui.keys:Hide() end
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		if ui.keys and s.open then ui.keys:Show() end
		return
	end
	if event == "GOSSIP_SHOW" then
		-- A line asked for is picked a frame on, dialog or not: anyone acting on the event itself goes first.
		s.gossips, s.gossipAt = s.gossips + 1, GetTime()
		C_Timer.After(0, Ask.Pick)
	end
	-- A quest's page makes this talk one about a quest; the windows all shut a moment after a close end it.
	if QUEST[event] and event ~= "QUEST_GREETING" then s.questAt = GetTime() end
	if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then C_Timer.After(Ask.OVER, Ask.Over) end
	if not s.on then
		if s.want then C_Timer.After(0, Apply) end
		return
	end
	if event == "QUEST_ITEM_UPDATE" or event == "QUEST_LOG_UPDATE" then
		-- Names and pictures that weren't loaded yet; a quest's state in a list.
		if s.open and s.shownGen == s.gen and (event == "QUEST_ITEM_UPDATE" or s.kind == "gossip" or s.kind == "greeting") then
			Talk.Refresh()
		end
		return
	end
	local linger = PACE.linger
	if event == "GOSSIP_SHOW" then
		s.kind = "gossip"
	elseif QUEST[event] then
		s.kind = QUEST[event]
	elseif event == "GOSSIP_CLOSED" then
		if s.kind ~= "gossip" then return end
		s.kind = nil
		-- The talk carries on after a quest picked here: its page is on its way. After an option it
		-- carries on in the game's own window (a vendor, a trainer, a flight map), and the dialog goes.
		if arg and s.toQuest then linger = PACE.wait end
	elseif event == "QUEST_FINISHED" then
		if s.kind == "gossip" then return end
		s.kind = nil
	end
	s.gen = s.gen + 1
	s.pageAt = GetTime()
	-- A closed page waits a moment: the next one often follows (a quest picked from a list).
	Soon(s.kind and 0 or linger)
end)
for _, event in ipairs({ "PLAYER_LOGIN", "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS",
	"QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ITEM_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
	events:RegisterEvent(event)
end

-- ShyGear's verdicts came in or changed (an item it waited on, your gear, level or build): the rewards on
-- show say so, and the suggestion follows while it still stands. Drawn again only when ShyGear's word on
-- one of them changed from what the tiles say.
Shy:On("SHY_GEAR", function()
	if not (s.on and s.open and s.shownGen == s.gen and (s.kind == "detail" or s.kind == "reward")) or s.confirming then return end
	local now = {}
	for _, kind in ipairs({ "choice", "reward" }) do
		local count = kind == "choice" and GetNumQuestChoices() or GetNumQuestRewards()
		for i = 1, count do
			local link = GetQuestItemLink(kind, i)
			if link then now[#now + 1] = Verdict(link) or "" end
		end
	end
	local drawn = { unpack(s.saying or {}) }
	table.sort(now)
	table.sort(drawn)
	if table.concat(now, "\031") ~= table.concat(drawn, "\031") then Talk.Refresh() end
end)

Shy:On("SHY_IMMERSION", function(what)
	if what == "questText" and attic then Want() end
	if what == "textSize" and ui.text then ui.text:SetFontObject(UI.TextFont(math.floor(W.Words() * I.TextSize() + 0.5))) end
end)

function Talk.Page()
	if s.on and PAGES[s.kind] then return s.kind end
end

function Talk.IsOn()
	return s.on
end

-- Quest text that isn't immersive in a window of ours (ShySkin's quest windows), or the game's own again: live, a talk
-- that is up moving over as the game's windows close.
function Talk.Window(on)
	s.windowed = on == true
	if attic then Want() end
end

-- How the talk is worn now: "stage" or "window".
function Talk.Make()
	return s.make
end

-- The make of the talk's window for a window of another addon's, and its measures (see "The shell").
Talk.Shell, Talk.WIN = W.Shell, WIN

-- Another window takes the talk's place: a vendor's goods once its line was picked, in a window of the same make
-- (Talk.Shell), so the talk turns into it where it stands. The talk's window, up or on its way out, is gone at once
-- and without its sound, and where it stood is answered: left, top, width and height in UIParent's units. nil while
-- no window of the talk's is up (the stage goes its own way, and so does whoever asked).
function Talk.Yield()
	local win = W.win
	if s.make ~= "window" or not win or not (s.open or s.leaving) then return nil end
	local left, top, wide, tall = win:GetLeft(), win:GetTop(), win:GetWidth(), win:GetHeight()
	local scale = win:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if s.open then
		Shut(false, true)
	else
		s.leaving = nil
		Settle("leave")
		Shy.HUD.Update(win)
	end
	for _, n in ipairs({ left or false, top or false, wide or false, tall or false, scale or false }) do
		if issecretvalue(n) or type(n) ~= "number" then return nil end
	end
	return left * scale, top * scale, wide * scale, tall * scale
end

-- The voice (Voice.lua), while a line begun since this page came is said: the stage's own words show it
-- as the voice addon's captions would (the word being heard lit in Voice.Ink, a step behind the voice's own
-- reckoning so it never runs ahead of what you hear; the words typed
-- out as the voice reaches them, as its settings ask), our own reveal standing down; the pages turn as
-- the voice reaches them, only forward and never back onto a page you went back from; the seal's light
-- breathes; the voice's key says whether a click stops it or plays it again. Once it stops, the page
-- reads as it is. Asked twenty times a second while a line plays, and as a page opens.
function ui.Voice()
	local state = Shy.Voice.State(s.pageAt)
	ui.voice:SetShown(state ~= nil)
	if state then
		ui.voice:Set(state == "paused" and "Play voice" or "Stop voice")
		ui.voice:Fit()
	end
	-- No line of this page's at all: where it stands, a word saying so and the key to send its text.
	local missing = state == nil and s.missing == true
	ui.contribute:SetShown(missing and s.contribute == true)
	ui.missing:SetShown(missing)
	ui.missing:ClearAllPoints()
	if s.make == "window" then
		-- In the window's foot, from its left end: the word, then the key to send the text.
		ui.missing:SetPoint("LEFT", W.foot, "LEFT", WIN.button, 0)
		ui.contribute:ClearAllPoints()
		ui.contribute:SetPoint("LEFT", ui.missing, "RIGHT", 7, 0)
	elseif ui.contribute:IsShown() then
		ui.missing:SetPoint("RIGHT", ui.contribute, "LEFT", -7, 0)
	else
		ui.missing:SetPoint("RIGHT", ui.foot, "RIGHT", 0, 0)
	end
	-- In the window the voice is one key in the foot, laid again only when it changes.
	local keys = tostring(state) .. tostring(missing) .. tostring(s.contribute)
	if s.make == "window" then
		W.VoiceKeys(state, missing)
		if W.keys ~= keys then
			W.keys = keys
			W.Foot()
		end
	end
	if not (state == "speaking" and #s.pages > 0) then
		if s.voiceText then
			s.voiceText = nil
			Say(ui.text, s.pages[s.page])
		end
		if s.voicing then
			s.voicing = nil
			Hush()
		end
		return
	end
	local ink = Shy.Voice.Ink()
	local at, text = Shy.Voice.Read(s.pages, s.pageAt, s.page, ink)
	if not at then return end
	s.voicing = true
	if s.revealing then Finish() end
	if at > s.page and at > (s.voiced or 1) then
		s.voiced = at
		ShowPage(at)
		if s.revealing then Finish() end
		at, text = Shy.Voice.Read(s.pages, s.pageAt, s.page, ink)
	end
	if text and text ~= s.voiceText then
		s.voiceText = text
		ui.text:SetText(text)
	elseif not text and s.voiceText then
		s.voiceText = nil
		Say(ui.text, s.pages[s.page])
	end
	Settle("hush")
	ui.sealLight:SetAlpha(PACE.lightLow + PACE.lightSpeak * (0.5 - 0.5 * math.cos(2 * math.pi * GetTime() / PACE.breath)))
end

Shy.Voice.Follow(function()
	if s.open and s.shownGen == s.gen and ui.voice then ui.Voice() end
end)

-- Whether the page has a recording: asked as it opens, and again once the game has filled in the quest
-- (its number can still be the last quest's that early). Quest pages only: most gossip (a vendor's, a
-- trainer's) has none, and saying so at every one would only be noise.
function ui.Missing()
	local kind = s.kind
	s.missing = kind ~= nil and kind ~= "gossip" and Shy.Voice.Missing(kind) == true
	s.contribute = s.missing and Shy.Voice.CanContribute()
	ui.Voice()
	local gen = s.gen
	C_Timer.After(0.6, function()
		if not (s.open and s.shownGen == gen) then return end
		s.missing = Shy.Voice.Missing(kind) == true
		s.contribute = s.missing and Shy.Voice.CanContribute()
		ui.Voice()
	end)
end
