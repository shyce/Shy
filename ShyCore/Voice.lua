-- Shy.Voice: the people you talk to speak in recorded voices, when the voice addon (OTHER) and its voice
-- packs are installed. That addon finds and plays each line itself, from the game's own quest and gossip
-- events, and silences the NPC's greeting ahead of a line so the two never talk over each other.
--
-- In the immersive dialog (Talk.lua) the voice is ours to show: the stage's own words light the word being
-- said and type out as the voice reaches them (as the voice addon's settings ask), its pages turn with the
-- voice, and a key of the stage's plays and stops it. The voice addon's own windows show the line as they
-- do, standing on a piece of Shy's layout ("Voice captions"): placed by layout mode like any other, at home
-- at the foot of the screen's empty middle, growing up from it. A quest or gossip line is already on screen
-- in the quest window whatever kind of quest text is picked, so its captions show only with instant turn-in,
-- where no window does; every other line (places, books, bosses) keeps them.
--
-- A quest's page is read to you once. Opened again, its line (one this character has heard: ShyCoreDB.voice)
-- is taken out of the voice addon's queue as it is queued and waits as a stopped line, for the voice's key to
-- play; with greetings read every time (V.Greetings) it is read every time too. Only the voice addon's own
-- read of a page is held back (one queued within AUTO seconds of the game opening or closing a quest page):
-- a line asked for with one of its Play buttons always plays.
--
-- A page the talk has left (answered, or the talk ended under it) is over: its line stops, and where the
-- voice addon comes to it only after (it reads a page a moment after it opens, and one answered sooner once
-- the quest is taken or handed in) it never begins.
--
--   Shy.Voice.Has()              the voice addon is installed and speaks the API this was written for
--   Shy.Voice.On()               its quest and gossip voices are on; nil without it
--   Shy.Voice.SetOn(on)          turns them on or off, through its own switches
--   Shy.Voice.Greetings() / SetGreetings(on)   NPCs' opening greetings, and quest pages opened again, read at
--                                every talk (true), or once: a quest giver's greeting as the voice addon reads
--                                it by default, a quest's page as above (false); nil where its setting can't
--                                be reached
--   Shy.Voice.Follow(fn)         fn() twenty times a second while a quest or gossip line plays, and once
--                                more as it stops or pauses, or is held back
--   Shy.Voice.State(since)       "speaking" or "paused" for the line begun at or after `since` (GetTime);
--                                "paused" too for one held back since then; nil for none
--   Shy.Voice.Toggle(since)      stops the line speaking, or plays a stopped one again from its start; with
--                                `since`, plays the line held back since then
--   Shy.Voice.Hush(since, words) ends the line begun at or after `since` for good: its talk is over. With
--                                `words` (the page's text, whole) that page is left: its line never begins
--   Shy.Voice.Opened(words)      a page of these words is up (again): its line may be said
--   Shy.Voice.Read(pages, since, shown, color)   where the line begun since `since` is in `pages` (plain
--                                text, a page each) and how page `shown` reads: the page number the voice
--                                is on, and the page's text with the word being heard (BEHIND seconds
--                                after the addon's own reckoning) wrapped in `color`
--                                (an escape, |cffrrggbb) and cut where the voice has typed to; nil, nil
--                                while no such line is being said or it can't be found in the pages. A
--                                page past the voice's is left as it is (text nil): you read ahead
--   Shy.Voice.Missing(kind)      no voice pack has the line of the page the game is on (Talk's kind): true,
--                                false, or nil where it can't be told (voices off, or the addon can't be asked)
--   Shy.Voice.CanContribute() / Contribute()   the page's text can be sent to be voiced / open the addon's
--                                own box to send it
--   Shy.Voice.Stood(on)          the talk stands in for the game's quest and gossip windows (or no longer does):
--                                the voice addon's own buttons for those windows are out of sight meanwhile
--   Shy.Voice.Ink()              the lit word's ink, as an escape: the accent held to read on the dark stage
--   Shy.Voice.stand              the layout piece the voice addon's windows stand on
--
-- Only its public API is used: its global, IsCompatible(API), IsPartOn / SetPartOn of its "quests" and
-- "gossip" parts, RegisterCallback (CLIP_QUEUED, CLIP_STARTED, CLIP_STOPPED, AUDIO_CHANGED), a clip's key,
-- text and source (its Remove and PlayNow), EndMuteGameDialogueAhead, GetCaption, GetNowPlaying, IsPaused,
-- TogglePause, Skip, SplitCaption and WordMarks (the matching its own captions use: MarkLinks, Align, Pick,
-- Cut, Spans, Want). Its windows are found by their global names (WINDOWS), anchored to the stand (whenever
-- it places one again, it is put back: a post-hook on SetPoint) and held in a veil of ours over UIParent,
-- which hides them while a window already shows their line.

local Shy = Shy
local HUD = Shy.HUD
local core = Shy.core

local V = {}
Shy.Voice = V
core.keep.voice = true   -- ShyCoreDB.voice: the quest lines each character has heard, the account's

local OTHER = "Spoken"   -- its global
local API = 1            -- the version of its API this was written for
local PARTS = { "quests", "gossip" }
local LOOK = 0.05        -- seconds between looks at a line playing: as often as its own captions look
-- Its windows, by their globals (OTHER .. name): the captions, the small player and the large one.
local WINDOWS = { "SubtitleFrame", "MinimalPlayerFrame", "PlayerFrame" }
local STAND = { w = 560, h = 96 }
-- Seconds the lit word stays behind the voice's own reckoning: its words are timed by an estimate (each a
-- share of the line by its letters; the voice packs carry no word times), which runs up to a word ahead on
-- some lines. A word lit before the one before it is fully heard reads as running ahead, so it stays about a
-- spoken word behind (a quarter second was still ahead at times).
local BEHIND = 0.45
-- Seconds after the game opens or closes a quest page in which a quest line queued is the voice addon's own
-- read of it; and seconds a page the talk has left keeps its line from beginning (as long as the voice addon
-- keeps a page it never read, to read once the quest is taken or handed in).
local AUTO, LATE = 1.5, 10
-- The game's events that open or close a quest page, or have the voice addon read one it came too late for.
local PAGES = { "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ACCEPTED", "QUEST_TURNED_IN" }

local followers = {}
local playing        -- { clip, began } while a quest or gossip line plays
local last           -- the last quest or gossip line begun, kept while it is stopped: { clip, began }
local ticker
local hooked = false
local found = {}     -- clip, pages, paragraphs, map, span: the last line matched against the last pages
local pageAt         -- when the game last opened or closed a quest page
local kept           -- { clip, at }: a quest line held back (heard before), for the voice's key to play
local asking         -- that line while it is played, asked for
local past = {}      -- a page's words -> when the talk left it

local function Other()
	local other = _G[OTHER]
	if type(other) == "table" and type(other.IsCompatible) == "function" and other:IsCompatible(API) then return other end
end

function V.Has()
	return Other() ~= nil
end

function V.On()
	local other = Other()
	if not other then return nil end
	for _, part in ipairs(PARTS) do
		if not other:IsPartOn(part) then return false end
	end
	return true
end

function V.SetOn(on)
	local other = Other()
	if not other then return end
	for _, part in ipairs(PARTS) do
		if other:IsPartOn(part) ~= on then other:SetPartOn(part, on) end
	end
end

function V.Follow(fn)
	followers[#followers + 1] = fn
end

-- How often an NPC's opening greeting is read: its quests part reads a quest giver's once by default, so a
-- greeting heard before is silent at every talk after. Not in the voice addon's API, so this one setting is
-- reached through its quests part's own settings (its Ace addon's saved profile, found through LibStub), and
-- only while it stands as that addon keeps it: a number in its Audio table.
local GREETINGS = { addon = OTHER .. "Quests", always = 1, default = 2 }

-- Its quests part, as an Ace addon (through LibStub), for the two things its API doesn't carry.
local function Quests()
	if not Other() then return nil end
	local stub = rawget(_G, "LibStub")
	local ace = stub and stub("AceAddon-3.0", true)
	local quests = ace and ace:GetAddon(GREETINGS.addon, true)
	if type(quests) == "table" then return quests end
end

local function Greeting()
	local quests = Quests()
	local db = quests and quests.db
	local profile = type(db) == "table" and db.profile
	local audio = type(profile) == "table" and profile.Audio
	if type(audio) == "table" and type(audio.GossipFrequency) == "number" then return audio end
end

-- Greetings read every time (true), or as that addon reads them by default (false); nil where it can't be told.
function V.Greetings()
	local audio = Greeting()
	if not audio then return nil end
	return audio.GossipFrequency == GREETINGS.always
end

function V.SetGreetings(on)
	local audio = Greeting()
	if audio then audio.GossipFrequency = on and GREETINGS.always or GREETINGS.default end
end

-- A page with no recording: no voice pack has its line (a quest new to this client, say), so the NPC's own
-- greeting is heard in its place. Its quests part answers it for a page named by its event
-- (GetVisibleLine(event): no window looked at), and can send the page's text to be voiced: its Contribute
-- (HasGap, Show) looks at the game's quest panels as shown, which they still are in the attic. That lives in
-- its quests part's own table, the one global it keeps (every voice pack calls into it by that name).
local QUESTS_TABLE = "VoiceOver"
local EVENTS = { greeting = "QUEST_GREETING", detail = "QUEST_DETAIL", progress = "QUEST_PROGRESS", reward = "QUEST_COMPLETE",
	gossip = "GOSSIP_SHOW" }

-- True where the voices are on and no pack has the line of the page the game is on (Talk's kind); false
-- where one has; nil where it can't be told.
function V.Missing(kind)
	if not V.On() then return nil end
	local quests, event = Quests(), EVENTS[kind]
	if not (quests and event and type(quests.GetVisibleLine) == "function") then return nil end
	local ok, line = pcall(quests.GetVisibleLine, quests, event)
	if not ok then return nil end
	return line == nil
end

local function Contribution()
	local own = rawget(_G, QUESTS_TABLE)
	local contribute = type(own) == "table" and rawget(own, "Contribute")
	if type(contribute) == "table" and type(contribute.HasGap) == "function" and type(contribute.Show) == "function" then
		return contribute
	end
end

-- Its own buttons for the game's quest and gossip windows (Contribute for a page no pack has, Listen with its
-- autoplay off): frames of UIParent's that it stands at the corner of the game's window, wherever that is. While the
-- talk stands in for those windows they are in the attic and still have a place on the screen, so its Contribute
-- stood loose across our window's band (and on the stage, in the air). The talk has its own key for the same, so
-- while it stands in they hang from a frame that is never shown, and they are UIParent's again, in their own
-- strata, once the game's windows are back. Found in its quests part's table, as its Contribute is; a button made
-- later is taken as a page is asked about.
local BUTTONS = { "ContributeButton", "DialogPlayButton" }
local closet = CreateFrame("Frame", nil, UIParent)
closet:Hide()
local stood = false  -- the talk stands in for the game's windows
local tucked = {}    -- its button -> the strata it had

local function Tuck()
	local own = rawget(_G, QUESTS_TABLE)
	if type(own) ~= "table" then return end
	for _, name in ipairs(BUTTONS) do
		local holder = rawget(own, name)
		local button = type(holder) == "table" and rawget(holder, "button")
		if type(button) == "table" and type(button.SetParent) == "function" then
			if stood and not tucked[button] then
				tucked[button] = button:GetFrameStrata()
				button:SetParent(closet)
			elseif not stood and tucked[button] then
				button:SetParent(UIParent)
				button:SetFrameStrata(tucked[button])
				tucked[button] = nil
			end
		end
	end
end

-- The talk says whether it stands in for the game's quest and gossip windows (Talk.lua, as that changes).
function V.Stood(on)
	stood = on == true
	Tuck()
end

-- Whether the page's text can be sent to be voiced (and the player hasn't hidden that addon's Contribute).
function V.CanContribute()
	Tuck()
	local contribute = Other() and Contribution()
	if not contribute then return false end
	local ok, gap = pcall(contribute.HasGap, contribute)
	return ok and gap == true
end

-- Opens the voice addon's own box for sending the page's text.
function V.Contribute()
	local contribute = Other() and Contribution()
	if contribute then pcall(contribute.Show, contribute) end
end

local function Tell()
	for _, fn in ipairs(followers) do fn() end
end

local function Look()
	if playing then Tell() end
end

local function Ours(clip)
	local source = type(clip) == "table" and clip.source
	local key = type(source) == "table" and source.key
	return key == PARTS[1] or key == PARTS[2]
end

-- The quest lines this character has heard, by the voice addon's key for each.
local function Lines()
	local db = rawget(_G, "ShyCoreDB")
	if not db then return nil end
	db.voice = db.voice or {}
	db.voice.heard = db.voice.heard or {}
	local me = Shy.Profiles.Character()
	db.voice.heard[me] = db.voice.heard[me] or {}
	return db.voice.heard[me]
end

-- A line's words, as the voice addon shows them.
local function Words(clip)
	local present = clip.present
	local words = type(present) == "table" and present.transcript or clip.text
	if type(words) == "string" then return words end
end

-- Takes a line out of the voice addon's queue as it is queued, before a word of it is said; the NPC's own
-- greeting, silenced ahead of it, comes back. False where its queue keeps it.
local function Drop(other, clip)
	if clip.source:Remove(clip) == false then return false end
	if type(other.EndMuteGameDialogueAhead) == "function" then other:EndMuteGameDialogueAhead() end
	return true
end

-- The voice addon's windows, held over UIParent: shown unless the line last begun is a quest or gossip line
-- a window already shows, which is every time but with instant turn-in.
local veil = CreateFrame("Frame", nil, UIParent)
veil:SetAllPoints(UIParent)
local begun          -- the line last begun, of any part

local function Veil()
	veil:SetShown(not Ours(begun) or Shy.Immersion.InstantTurnIn() == true)
end

-- A line queued: one of a page the talk has left never begins, and the voice addon's own read of a quest
-- page heard before is held back for the voice's key, unless greetings are read every time.
local function Queued(clip)
	local other = Other()
	if not (other and Ours(clip)) or clip == asking then return end
	local source = clip.source
	if type(source.Remove) ~= "function" or type(source.PlayNow) ~= "function" then return end
	local now = GetTime()
	-- A quest line queued at any other time than round a page's opening or closing was asked for, and plays.
	local quest = source.key == PARTS[1]
	if quest and not (pageAt and now - pageAt <= AUTO) then return end
	local words = Words(clip)
	local gone = words and past[words]
	if gone and now - gone <= LATE then
		Drop(other, clip)
		return
	end
	if not quest or V.Greetings() ~= false then return end
	local heard = Lines()
	if not (heard and type(clip.key) == "string" and heard[clip.key]) then return end
	if Drop(other, clip) then
		kept = { clip = clip, at = now }
		Tell()
	end
end

local function Started(clip)
	begun = clip
	Veil()
	if not Ours(clip) then return end
	-- A line of a talk begun: one held back before it is past. A quest's line is heard from here on.
	kept = nil
	if clip.source.key == PARTS[1] and type(clip.key) == "string" then
		local heard = Lines()
		if heard then heard[clip.key] = true end
	end
	playing = { clip = clip, began = GetTime() }
	-- The same line again (stopped and played): it began now, as far as a page is concerned.
	last = playing
	if not ticker then ticker = C_Timer.NewTicker(LOOK, Look) end
	Tell()
end

-- finished: said to its end (else stopped, or taken out of the queue).
local function Stopped(clip, finished)
	if not (playing and playing.clip == clip) then return end
	playing = nil
	if finished and last and last.clip == clip then last.ended = true end
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
	Tell()
end

-- The line begun at or after `since` is the one at the head still, speaking or stopped.
local function Live(other, since)
	return last ~= nil and not last.ended and last.began >= since and other:GetNowPlaying() == last.clip
end

function V.State(since)
	local other = Other()
	if not other then return nil end
	if Live(other, since) then return other:IsPaused() and "paused" or "speaking" end
	if kept and kept.at >= since then return "paused" end
	return nil
end

function V.Toggle(since)
	local other = Other()
	if not other then return end
	if since and kept and kept.at >= since and not Live(other, since) then
		-- Held back, and asked for now: played as the voice addon plays a line asked for.
		local clip = kept.clip
		kept, asking = nil, clip
		local ok, err = pcall(clip.source.PlayNow, clip.source, clip)
		asking = nil
		if not ok then geterrorhandler()(err) end
		Tell()
		return
	end
	other:TogglePause()
end

-- The talk a line belongs to ended under it (the immersive dialog closed: you walked away, left or answered):
-- the quest or gossip line begun at or after `since` stops, speaking or paused. Whatever waits after it in
-- the voice addon's queue carries on. With the page's words, the page is left: its line, come to late, is
-- taken out as it is queued (Queued).
function V.Hush(since, words)
	local other = Other()
	if not other then return end
	if not issecretvalue(words) and type(words) == "string" then
		local now = GetTime()
		for page, at in pairs(past) do
			if now - at > LATE then past[page] = nil end
		end
		past[words] = now
	end
	if kept and kept.at >= since then kept = nil end
	if Live(other, since) then other:Skip() end
end

function V.Opened(words)
	if not issecretvalue(words) and type(words) == "string" then past[words] = nil end
end

-- The lit word's ink, as an escape: the accent kept a color (Theme.Vivid) where it reads on the dark stage as a
-- label does (one word at a time, read along with the voice), so it stands apart from the near-white words round it
-- by its color. An accent with too little color left for that (a priest's white, a silver) takes the gold.
local LIT = { least = 0.3 }   -- the least color (Theme.Chroma) the lit word may carry before it takes the gold
function V.Ink()
	local Theme, C = Shy.Theme, Shy.UI.colors
	local r, g, b = Theme.Accent()
	local p = C.panel
	r, g, b = Theme.Vivid(r, g, b, p[1], p[2], p[3], Theme.LC_LABEL)
	return "|cff" .. Theme.Hex(Theme.Chroma(r, g, b) < LIT.least and C.alert or { r, g, b })
end

-- The word being heard: the caption's own reckoning of its words, BEHIND seconds back. Without the line's
-- length (or its words' places in it) the caption's own word.
local function Heard(caption)
	local length = tonumber(caption.clip and caption.clip.length)
	local words, total = caption.words, caption.totalWeight
	if not (length and length > 0 and total and total > 0 and caption.progress and words[1] and words[1].finish) then
		return caption.activeWord
	end
	local target = math.max(0, caption.progress * length - BEHIND) / length * total
	for i, word in ipairs(words) do
		if word.finish > target then return i end
	end
	return #words
end

function V.Read(pages, since, shown, color)
	local other = Other()
	if not (other and last and not last.ended and last.began >= since and other.WordMarks and other.SplitCaption) then return nil end
	local marks = other:WordMarks()
	local caption = other:GetCaption()
	if not (marks and caption and caption.clip == last.clip and caption.words) then return nil end
	if found.clip ~= caption.clip or found.pages ~= pages then
		local paragraphs = {}
		for i, text in ipairs(pages) do
			if issecretvalue(text) or type(text) ~= "string" then return nil end
			paragraphs[i] = { text = text, words = marks.MarkLinks(text, other:SplitCaption(text)) }
		end
		found.clip, found.pages, found.paragraphs = caption.clip, pages, paragraphs
		found.map, found.span = marks.Align(caption.words, paragraphs)
	end
	local map, span, paragraphs = found.map, found.span, found.paragraphs
	if not map then return nil end
	-- Where the voice is: the word being said (or the last before it the pages have), else how far it typed.
	local word = marks.Pick(map, caption.speaking and Heard(caption) or nil)
	local cutP, cutByte = marks.Cut(caption, map, span, paragraphs)
	local at = (word and map[word].p) or cutP
	if not at or not paragraphs[shown] or (cutP and shown > cutP) then return at, nil end
	-- One word lit, the one being heard: its neighbour lit with it ran ahead of the voice.
	local spans
	if caption.highlight and word then spans = marks.Spans(map, paragraphs, word) end
	return at, marks.Want(paragraphs[shown], shown, span, cutP, cutByte, spans, color)
end

-- The stand: where the voice addon's own windows go, a piece of layout mode.

local held = {}      -- its windows put on the stand, each hooked once
local placing = false

local function Hold(frame)
	placing = true
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", V.stand, "BOTTOM", 0, 0)
	placing = false
end

-- Its windows as they exist: each is made when it is first needed (the captions as their first line begins,
-- after that line's start is told), so asked again as lines begin and as its queue changes.
local function Take()
	if not (V.stand and Other()) then return end
	for _, name in ipairs(WINDOWS) do
		local frame = _G[OTHER .. name]
		if type(frame) == "table" and type(frame.SetPoint) == "function" and not held[frame] then
			held[frame] = true
			local strata = frame:GetFrameStrata()
			frame:SetParent(veil)
			frame:SetFrameStrata(strata)
			hooksecurefunc(frame, "SetPoint", function(self)
				if not placing then Hold(self) end
			end)
			Hold(frame)
		end
	end
end

-- At home at the foot of the screen's empty middle, clear of the bars: what Shy's layout leaves open.
local function Home()
	if not V.stand or HUD.IsPlaced(V.stand) then return end
	local left, bottom, right = HUD.Room(V.stand)
	HUD.SetHome(V.stand, { "BOTTOM", "BOTTOMLEFT", (left + right) / 2, bottom })
end

local function Stand()
	local box = HUD.Create({
		id = "shycore.voice", title = "Voice captions",
		width = STAND.w, height = STAND.h,
		point = { "BOTTOM", "BOTTOM", 0, 220 },
		-- Only in layout mode, and only with a voice to place: the windows on it show themselves.
		shown = function() return false end,
		away = function() return not V.Has() end,
	})
	local say = Shy.UI.Text(box, "Voice captions show here", 12, false, Shy.UI.colors.dim)
	say:SetPoint("CENTER")
	V.stand = box
	Home()
	return box
end

-- Heard once every addon has loaded, whichever loaded first.
local function Hook()
	local other = Other()
	if hooked or not other then return end
	hooked = true
	other:RegisterCallback("CLIP_QUEUED", Queued)
	other:RegisterCallback("CLIP_STARTED", function(clip)
		Take()
		Started(clip)
	end)
	other:RegisterCallback("CLIP_STOPPED", Stopped)
	other:RegisterCallback("AUDIO_CHANGED", Take)
	local pages = CreateFrame("Frame")
	for _, event in ipairs(PAGES) do pages:RegisterEvent(event) end
	pages:SetScript("OnEvent", function() pageAt = GetTime() end)
	Stand()
	Take()
	Tuck()
	-- The rest of the screen settles after login: its room is measured again then (and its buttons, made by then,
	-- are out of the talk's way).
	C_Timer.After(2, function()
		Home()
		Tuck()
	end)
end

Shy:On("SHY_LOGIN", Hook)
Shy:On("SHY_HUD_LAYOUT", Home)
Shy:On("SHY_IMMERSION", function(what)
	if what == "turnIn" then Veil() end
end)
Shy:On("SHY_HUD_MOVED", function(box)
	if box ~= V.stand then Home() end
end)
