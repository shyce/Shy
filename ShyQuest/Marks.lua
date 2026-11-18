-- Marks: the one set of pictures used on the card, the world map, the minimap, nameplates and the tracker.
--
--   dark glass, gold bezel, gold !     quest to pick up
--   gold face, dark ?                  quest to turn in
--   dark glass, bezel and emblem in    objective: what it asks for (KIND), each kind with an emblem and a
--   its kind's color                   color of its own: red swords to kill, an orchid pouch to loot, a
--                                      green cog to gather or use, a gold speech bubble to talk, and an
--                                      ice blue banner for a place to go to or where the data doesn't say;
--                                      a lime weary face for someone to escort; and a red skull where the
--                                      character's body lies while they are dead
--   dark glass, bezel and sign in      an errand (SIGN): sell (vendor), train (trainer), buy (quest item
--   its errand's color                 vendor) ...: copper where coin changes hands, periwinkle where
--                                      something is learned, teal where the way gets shorter (ERRAND)
--   dark glass, steel bezel, white     a guide step with no number, a flight, an errand with no sign
--   sign
--   numbered map pin                   a route place (slate, a white number; the live one white, a graphite
--                                      number, as the trail's light) or a zone with its quest count
--   lit: the face in the color, the    the one being worked on, under the mouse, or clicked: it keeps
--   bezel a lighter tint of it, a      the color its ground has on the map; a white mark lit wears your
--   soft bloom round it, dark emblem   color, its sign in the ink that reads on it (Theme.OnColor)
--
-- A plate has one bezel. Shape is the kind, color is the state. Gold, white, slate, an objective's
-- and an errand's colors are fixed meanings and do not follow the accent: a yellow accent would match the
-- quest givers' gold, a tan or a brown one would sink into the map's ground. Only a lit white mark (where
-- you are headed, with nothing of its own to say) has the accent: on its lit face it stands off the ground.
-- The pictures are textures, not font strings (text on the map is drawn at one size and stretched):
-- two sheets, Marks.tga (64px cells) and MarksSmall.tga (32px), 8 by 5, grey and white for tinting.
-- A TGA has no mipmaps, so a mark uses the sheet nearer its on-screen size.

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors
local D, L = ns.Data, ns.Log

-- These colors must match the media builder's.
local MARK = {
	gold = C.alert, onGold = C.onAlert,
	gem = { 0.44, 0.80, 1.00 },        -- ice blue: an objective of no kind of its own
	route = { 0.96, 0.96, 0.98 },      -- white: the route
	-- A route place's pin: a cool deep slate, which stands off the maps' warm ground and wears no kind's color.
	slate = { 0.26, 0.31, 0.42 },
	steel = { 0.74, 0.74, 0.78 },      -- a dark plate's rim
	graphite = { 0.08, 0.08, 0.09 },   -- a number or an emblem on a light plate
	-- The tracker's dressed buttons (Look.lua) keep a violet for a selected quest and a lavender under the mouse.
	focus = { 0.52, 0.34, 0.96 },
	hover = { 0.80, 0.72, 1.00 },
}
ns.MARK = MARK
-- A lighter tint of a color: `by` of the way to white.
local function Lighter(color, by)
	return { color[1] + (1 - color[1]) * by, color[2] + (1 - color[2]) * by, color[3] + (1 - color[3]) * by }
end

-- What an objective asks for, each kind with a color: its mark wears it wherever the mark stands, and
-- so does the ground it is done on (Ground.lua; word: its name in the ground's hover). A kind's emblem is the
-- sheet's picture of its name (ns.ToneSign). "find" is a search result's, not an objective's: the glass,
-- in the route's white.
local KIND = {
	kill = { color = { 0.96, 0.28, 0.30 }, word = "Kill" },
	loot = { color = { 0.86, 0.46, 0.98 }, word = "Loot" },
	gather = { color = { 0.30, 0.90, 0.58 }, word = "Gather" },
	talk = { color = MARK.gold, word = "Talk" },
	-- Something to buy from a vendor: the price tag of the nameplate's buy sign, in the coin copper.
	buy = { color = { 1.00, 0.62, 0.30 }, word = "Buy" },
	go ={ color = MARK.gem, word = "Explore" },
	find = { color = MARK.route, word = "Find" },
	-- Where the character's body lies while they are dead (Death.lua): a skull, in the red the game
	-- writes "Corpse" in. A mark only: it has no ground.
	body = { color = { 1.00, 0.20, 0.20 }, word = "Body" },
	-- Someone to walk with (Escort.lua): a weary face, in lime. Its ground is where the walk ends.
	escort = { color = { 0.74, 0.94, 0.32 }, word = "Escort" },
	-- Where you farm an item (ShyFarm's farm stop): its ground, its creatures and its mark in a turquoise no other
	-- kind wears, cool against the maps' warm ground; its emblem is the loot's bag.
	farm = { color = { 0.12, 0.88, 0.80 }, word = "Farm" },
}
ns.KIND = KIND
Shy.Kinds = KIND      -- the other addons' circles take an objective's color from here
-- How a place serves a quest (Route.lua's GoalPlaces; "start", "go" and "find" are Ground.lua's) to its kind.
local HOW = { kill = "kill", drops = "loot", holds = "gather", use = "gather", gives = "talk", sells = "buy", start = "talk",
	go = "go", find = "find", escort = "escort", farm = "farm" }
ns.HOW = HOW
-- An index tie's kind (Index.lua) to an objective's.
local TIED = { kill = "kill", drop = "loot", use = "gather", holds = "gather", sells = "buy" }

-- A mark's color for an objective of kind `tone`; ice blue for none.
function ns.ToneColor(tone)
	return tone and KIND[tone] and KIND[tone].color or MARK.gem
end

-- The emblem of an objective of kind `tone`, as the name of its picture (what a search found has the
-- glass); the banner for none.
local BORROWS = { farm = "loot" }   -- a kind drawn with another's emblem
function ns.ToneSign(tone)
	return BORROWS[tone] or (KIND[tone] and tone) or "go"
end

-- The kind of what one goal token asks for (Data.lua, goals), or nil. An item is looted where a creature
-- drops it, else gathered where an object holds it, else got from someone (as Route.lua's GoalPlaces).
local RANK = { loot = 3, gather = 2, buy = 1, talk = 1 }
local function TokenKind(token)
	if token.kind == "c" or token.kind == "k" then return "kill" end
	if token.kind == "o" then return "gather" end
	if token.kind ~= "i" then return nil end
	local item = D.Item(token.id)
	if not item then return nil end
	local kind = item.more and item.more[1] and "loot" or nil
	for _, source in ipairs(item.sources) do
		local each = source.kind == "v" and "buy" or "talk"
		if source.kind == "o" then
			each = "gather"
		elseif source.kind == "n" then
			local npc = D.Npc(source.id)
			-- No drop chance, and they give or take quests: they hand it over.
			if source.chance or not (npc and (npc.gives or npc.takes)) then each = "loot" end
		end
		if not kind or RANK[each] > RANK[kind] then kind = each end
	end
	return kind
end

-- The kind of a quest's objective `objective`, or of the first one not finished. A quest with nothing
-- to count is "escort" where someone is walked somewhere, "go" where there is a place to reach. nil
-- when the data doesn't say.
function ns.QuestKind(id, objective)
	local quest = D.Quest(id)
	local tokens
	if L.Has(id) then
		local goals = L.Goals(id)
		local goal = objective and goals[objective]
		if not goal then
			for _, each in ipairs(goals) do
				if not each.finished then
					goal = each
					break
				end
			end
		end
		tokens = goal and goal.tokens
	end
	for _, token in ipairs(tokens or quest and quest.goals or {}) do
		local kind = TokenKind(token)
		if kind then return kind end
	end
	if D.Escort(id) then return "escort" end
	if quest and #quest.trigger > 0 then return "go" end
end

-- The same for one item: what gets it.
function ns.ItemKind(id)
	return TokenKind({ kind = "i", id = id })
end

-- The kind of the objective a stop is for (a merged stop: its first member's), nil for any other stop.
-- The stop's own source says it where the route chose one: a vendor in reach is someone to talk to.
-- A quest's stop in a mood of its own (MOOD, mark:SetMood): every quest of it skipped and set aside (Route.lua's
-- R.Skip), else every one too low to give XP; nil for the rest, and for any other stop.
function ns.StopMood(stop)
	if not stop or (stop.kind ~= "pickup" and stop.kind ~= "turnin") then return nil end
	local actions = stop.actions or {}
	if #actions == 0 then return nil end
	local aside, low = true, true
	for _, action in ipairs(actions) do
		if not (ns.Route and ns.Route.Aside and ns.Route.Aside(action.id)) then aside = false end
		if not ((action.level or 0) > 0 and L.Trivial(action.level)) then low = false end
	end
	return aside and "aside" or low and "trivial" or nil
end

function ns.StopTone(stop)
	if stop.tone then return stop.tone end
	if stop.kind ~= "goal" then return nil end
	if stop.source then return HOW[stop.source.how] end
	local action = stop.actions and stop.actions[1]
	return action and action.id and ns.QuestKind(action.id, stop.objective) or nil
end

-- The kind of what a tie has a creature, object or item do for its quest (Index.lua).
function ns.TieTone(tie)
	return TIED[tie.kind] or (tie.item and TokenKind({ kind = "i", id = tie.item.id })) or ns.QuestKind(tie.id, tie.index)
end

-- The kind of what a guide's line has you do: the objective of a "complete" line, the item of a "collect".
function ns.LineTone(line)
	if not line.id then return nil end
	if line.command == "collect" then return ns.ItemKind(line.id) end
	return ns.QuestKind(line.id, line.objective or tonumber((line.spec or ""):match("^%s*%-?%d+%s*,%s*(%d+)")))
end

-- A quest of several objectives tells them apart wherever they show (the card's rows, the map's marks,
-- its key and its dots): each objective has a letter, A, B, C ... in the quest's own order (so it never
-- changes while the rows re-sort), and a shade of its kind's color. The shades step in lightness first,
-- each kept apart from every other meaning color by the marks' clash rule; the letter carries who is
-- who, the shade only has to differ. A kind's own color is its first shade, so a quest whose objectives
-- are of different kinds keeps every kind's own color. A quest of one objective has none of this.
local SHADES = {
	kill = { KIND.kill.color, { 0.78, 0.03, 0.25 }, { 0.82, 0.13, 0.01 }, { 0.87, 0.18, 0.32 } },
	loot = { KIND.loot.color, { 0.64, 0.18, 0.66 }, { 0.88, 0.71, 1.00 }, { 0.75, 0.32, 0.82 } },
	gather = { KIND.gather.color, { 0.00, 0.60, 0.35 }, { 0.59, 1.00, 0.82 }, { 0.25, 0.73, 0.36 } },
	talk = { KIND.talk.color, { 0.75, 0.52, 0.00 }, { 0.80, 0.68, 0.21 }, { 1.00, 0.91, 0.71 } },
	buy = { KIND.buy.color, { 0.66, 0.30, 0.04 }, { 1.00, 0.86, 0.72 }, { 0.80, 0.44, 0.10 } },
	go = { KIND.go.color, { 0.00, 0.54, 0.69 }, { 0.74, 0.91, 1.00 }, { 0.31, 0.64, 0.85 } },
	escort = { KIND.escort.color, { 0.38, 0.67, 0.01 }, { 0.91, 1.00, 0.78 }, { 0.67, 0.76, 0.06 } },
}
ns.SHADES = SHADES
local LETTERS = "ABCDEFGH"
local DONE_SHADE = { 0.45, 0.45, 0.47 }   -- an objective finished: its disc goes grey
ns.DONE_SHADE = DONE_SHADE

-- A quest's objectives as they are told apart, by objective index: { index, letter, kind, shade }; nil
-- for a quest of one objective (or none in the log). Kept per quest until its objectives change.
local identities = {}
function ns.Objectives(id)
	local goals = id and L.Has(id) and L.Goals(id)
	if not goals then return nil end
	local shown = 0
	for _, goal in ipairs(goals) do
		if goal.text and goal.text ~= "" then shown = shown + 1 end
	end
	if shown < 2 then return nil end
	local kept = identities[id]
	if kept and kept.goals == goals then return kept end
	kept = { goals = goals }
	local letter, rank = 0, {}
	for index, goal in ipairs(goals) do
		if goal.text and goal.text ~= "" and letter < #LETTERS then
			letter = letter + 1
			local kind = ns.QuestKind(id, index)
			local ladder = SHADES[kind] or SHADES.go
			rank[ladder] = (rank[ladder] or 0) + 1
			kept[index] = { index = index, letter = LETTERS:sub(letter, letter), kind = kind,
				shade = ladder[(rank[ladder] - 1) % #ladder + 1] }
		end
	end
	identities[id] = kept
	return kept
end

-- One objective's identity, or nil (a quest of one objective).
function ns.Objective(id, index)
	local all = index and ns.Objectives(id)
	return all and all[index] or nil
end

-- The identity of the objective a stop's mark is for (an objective's own mark on the maps), or nil.
-- kind: what the mark is drawn as (ns.StopMark's).
function ns.StopLetter(stop, kind)
	if kind ~= "goal" or not stop.objective or stop.members then return nil end
	local action = stop.actions and stop.actions[1]
	return action and action.kind == "goal" and ns.Objective(action.id, stop.objective) or nil
end

-- The letter disc: the objective's letter cut out of a disc of its shade, on a deep case of the same hue
-- a little larger (so it reads on the map's ground and on the card alike). Letters.tga: 32 texel cells,
-- eight across, two down (the faces A to H, then the case), each picture 28 texels across in the middle
-- of its cell: drawn for 14 units.
local LETTER_ART = ns.MEDIA .. "Letters"
local function LetterCell(texture, column, row)
	texture:SetTexCoord((column * 32 + 2) / 256, (column * 32 + 30) / 256, (row * 32 + 2) / 64, (row * 32 + 30) / 64)
end
local LETTER_DEEP = 0.24     -- the case, and so the letter: this much of the shade
local LETTER_ON_MARK, LETTER_AT = 0.5, 0.36   -- on a mark: its size, and how far right and down of the plate's middle, in marks

function ns.CreateLetter(parent, size)
	local disc = CreateFrame("Frame", nil, parent)
	disc:SetSize(size, size)
	disc.case = disc:CreateTexture(nil, "ARTWORK", nil, 1)
	disc.case:SetAllPoints()
	disc.case:SetTexture(LETTER_ART)
	LetterCell(disc.case, 0, 1)
	disc.face = disc:CreateTexture(nil, "ARTWORK", nil, 2)
	disc.face:SetAllPoints()
	disc.face:SetTexture(LETTER_ART)
	-- one: an objective (ns.Objective's), or nil to hide. done: finished, so grey and quiet.
	function disc:Set(one, done)
		self:SetShown(one ~= nil)
		if not one then return end
		local at = (LETTERS:find(one.letter, 1, true) or 1) - 1
		if self.at ~= at then
			self.at = at
			LetterCell(self.face, at, 0)
		end
		local shade = done and DONE_SHADE or one.shade
		self.face:SetVertexColor(shade[1], shade[2], shade[3], 1)
		self.case:SetVertexColor(shade[1] * LETTER_DEEP, shade[2] * LETTER_DEEP, shade[3] * LETTER_DEEP, 1)
		self:SetAlpha(done and 0.6 or 1)
	end
	disc:Hide()
	return disc
end

local SHEETS ={ ns.MEDIA .. "MarksSmall", ns.MEDIA .. "Marks" }   -- 32px cells, 64px cells
local LARGE_FROM = 40        -- on-screen pixels from which the large sheet is used
local COLS, ROWS = 8, 8       -- (the last rows of the sheet are empty: it stays a power of two tall)
-- badge is the dark glass (no bezel of its own), lit the face of a lit plate, ring the one bezel, bloom the
-- soft light round a lit plate.
local CELL = { badge = 0, lit = 1, kill = 2, loot = 3, ring = 4, pin = 5, gather = 6, ["!"] = 8, ["?"] = 9, sell = 20, train = 21,
	buy = 22, weapon = 23, aid = 24, flight = 25, home = 26, potion = 27, herb = 28, talk = 29, go = 30, bloom = 31, body = 32,
	talent = 33, reset = 34, escort = 35, sail = 36, escortLate = 37, escortDone = 38, tram = 39, pet = 40,
	zeppelin = 41, skill = 42, dungeon = 43, find = 44, shut = 45, open = 46, bank = 47, mail = 48 }
local BLOOM_SCALE = 1.6      -- the bloom's picture is shown this many times the mark's size (the media builder's)
local LIT_BEZEL, LIT_BLOOM = 0.45, 0.25   -- a lit plate's bezel and bloom: this far from its color toward white
-- A lit white plate wears the accent: as functions, so it follows the theme as it changes.
local Theme = Shy.Theme
local function AccentLighter(by)
	return function()
		local r, g, b = Theme.Accent()
		return r + (1 - r) * by, g + (1 - g) * by, b + (1 - b) * by
	end
end
local ACCENT_BEZEL, ACCENT_BLOOM = AccentLighter(LIT_BEZEL), AccentLighter(LIT_BLOOM)
local DIGIT = 10             -- cell of "0"; 1 to 9 follow
-- Signs: an errand's `mark` or a goal stop's `mark` (Route.lua). The key is both the kind and the cell name.
--   sell a vendor for full bags, train a class trainer, buy a vendor's goods, weapon a weapon master,
--   aid first aid's trainer, flight a flight master, home the inn or the hearthstone, potion potions
--   to make or look for, herb a herb to buy, talent a talent point to spend, reset talents to unlearn
--   at a class trainer, sail a boat to take, zeppelin a zeppelin to take, tram the tram to take, pet a
--   pet's trainer, its training or its class quest (Pets.lua: a paw print), skill a skill or profession
--   to learn (an anvil), dungeon a dungeon to run (a stone gateway), bank a banker with something of a
--   quest's to take out or put away (Stash.lua: a strongbox), mail a mailbox with a letter that holds some
--   (an envelope).
-- A sign wears the color of what its errand is about, so an errand is told from a quest and from
-- another kind of errand at a glance: copper where coin or what you own changes hands, periwinkle where something is
-- learned, teal where the way gets shorter, the sea's color for a boat (apart from a flight's teal; an
-- airboat flies, and wears the flight's wing and teal), ember for a zeppelin, fawn for a pet, stone for a
-- dungeon. (The ways of getting about wear the family's travel colors: Shy.Theme.TRAVEL.)
local ERRAND = {
	coin = KIND.buy.color,
	learn = { 0.62, 0.70, 1.00 },
	travel = Shy.Theme.TRAVEL.flight,
	sea = Shy.Theme.TRAVEL.boat,
	pet = { 0.90, 0.74, 0.56 },
	zeppelin = Shy.Theme.TRAVEL.zeppelin,
	stone = { 0.84, 0.78, 0.66 },
}
local SIGN = { sell = ERRAND.coin, buy = ERRAND.coin, potion = ERRAND.coin, herb = ERRAND.coin, bank = ERRAND.coin, mail = ERRAND.coin,
	train = ERRAND.learn, weapon = ERRAND.learn, aid = ERRAND.learn, talent = ERRAND.learn, reset = ERRAND.learn,
	flight = ERRAND.travel, home = ERRAND.travel, sail = ERRAND.sea, tram = ERRAND.travel, pet = ERRAND.pet,
	zeppelin = ERRAND.zeppelin, skill = ERRAND.learn, dungeon = ERRAND.stone }
ns.ERRAND = ERRAND

-- The color of an errand's sign, nil for what is no sign.
function ns.SignColor(sign)
	return SIGN[sign]
end
-- What stands for a stop that is on the route but has no sign of its own: a flight's wing, the glass of
-- what a search found (Find.lua, a "found" stop), else the banner.
local PLAIN = { guide = "go", errand = "go", fly = "flight", found = "find", way = "go", shut = "shut", open = "open" }
-- The pin's geometry, as shares of its cell (must match the media builder's PIN_*): its point and its
-- head's middle above the cell's middle, the number's scale on its head.
local PIN_TIP, PIN_HEAD, PIN_NUMBER = 0.46, 0.14, 0.78
local PIN_SIDE = 0.12        -- empty margin each side of the pin's head
-- Each digit's ink width as a share of its cell (printed by the media builder).
local INK = { [0] = 0.404, 0.359, 0.393, 0.395, 0.420, 0.393, 0.400, 0.389, 0.412, 0.400 }
local GAP, FIT, MOST = 0.045, 0.58, 0.92  -- two digits: gap, total width they share, maximum scale
local WHITE = { 1, 1, 1 }

-- What a mark of `kind` wears: its color and its picture's cell. nil for a hand-in (its look is all its
-- own) and for a map pin (a number).
local function Look(kind, tone)
	if kind == "pickup" then return MARK.gold, CELL["!"] end
	-- An errand: its sign, in the color of what the errand is about.
	if SIGN[kind] then return SIGN[kind], CELL[kind] end
	-- A place on the route with nothing to say of itself: the sign in the route's white.
	if PLAIN[kind] then return MARK.route, CELL[PLAIN[kind]] end
	-- An objective: its kind's emblem, in its kind's color.
	if kind ~= "turnin" and kind ~= "step" and kind ~= "zone" then return ns.ToneColor(tone), CELL[ns.ToneSign(tone)] end
end

-- A round mark's layers: the color of its lit face (nil: the glass alone), its bezel, its bloom (nil:
-- none) and what stands on it. Lit (worked on, hovered or clicked): the face in the mark's color, the
-- bezel a lighter tint of it, a bloom round it, what is on it dark; a lit white mark wears the accent. A
-- color may be a function, so it follows the theme as it changes.
local function Layers(kind, color, lit)
	if kind == "turnin" then
		local gold = MARK.gold
		return gold, lit and Lighter(gold, LIT_BEZEL) or { gold[1] * 0.7, gold[2] * 0.7, gold[3] * 0.7 },
			lit and Lighter(gold, LIT_BLOOM) or nil, MARK.onGold
	elseif lit and color == MARK.route then
		return Theme.Accent, ACCENT_BEZEL, ACCENT_BLOOM, C.onAccent
	elseif lit then
		return color, Lighter(color, LIT_BEZEL), Lighter(color, LIT_BLOOM), kind == "pickup" and MARK.onGold or MARK.graphite
	end
	return nil, color == MARK.route and MARK.steel or color, nil, color
end

-- A quest's mark in a mood of its own (mark:SetMood), its shape the same: what is on offer, set apart from what is
-- worth your while. The game grays a quest too low to give XP; a quest you set aside rests in a burnished bronze, a
-- gold gone quiet, so the two never read alike, nor either as a quest worth taking. Both stand a little back
-- (alpha); lit (hovered, clicked), they wear their own color as a lit mark does.
local MOOD = {
	trivial = { color = { 0.58, 0.58, 0.60 }, alpha = 0.8 },   -- pewter: too low to give XP
	aside = { color = { 0.70, 0.47, 0.25 }, alpha = 0.9 },     -- bronze: you set it aside
}
ns.MOOD = MOOD
local function MoodLayers(kind, mood, lit)
	local c = mood.color
	if kind == "turnin" then
		return c, lit and Lighter(c, LIT_BEZEL) or { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7 }, lit and Lighter(c, LIT_BLOOM) or nil, MARK.graphite
	end
	if lit then return c, Lighter(c, LIT_BEZEL), Lighter(c, LIT_BLOOM), MARK.graphite end
	return nil, c, nil, c
end

local function CellCoords(cell)
	local col, row = cell % COLS, math.floor(cell / COLS)
	return { col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS }
end

local function Now(color)
	if type(color) == "function" then return { color() } end
	return color
end

-- A round mark as the textures of a frame that draws it itself (a nameplate's tag: Plates.lua), in the
-- form ShyPlates takes a tag: the glass (back), the lit face (face, when lit), what stands on it (the
-- picture) and the bezel (over). Its colors are read now: make it again when the theme changes. No
-- bloom: a nameplate has no room round its mark.
-- `flat` is the same mark for a square home (the compartment of a nameplate's housing, where a disc in
-- a box is a blob at that size): its picture alone, nothing under it and nothing round it, cut to the
-- drawing so it fills the square. It wears the mark's own color (a hand-in's gold); lit, the lighter
-- tint a lit bezel has (a lit white mark: of your color).
local FLAT_TRIM = 2 / 32     -- the empty margin round the widest picture, as a share of its cell
local function Trimmed(cell)
	local coords = CellCoords(cell)
	local wide, tall = (coords[2] - coords[1]) * FLAT_TRIM, (coords[4] - coords[3]) * FLAT_TRIM
	return { coords[1] + wide, coords[2] - wide, coords[3] + tall, coords[4] - tall }
end

function ns.MarkTag(kind, lit, tone)
	local color, glyph = Look(kind, tone)
	lit = lit and true or false
	local face, bezel, _, ink = Layers(kind, color, lit)
	if kind == "turnin" then glyph, color = CELL["?"], MARK.gold end
	return { texture = SHEETS[1], coords = CellCoords(glyph), color = Now(ink),
		back = { coords = CellCoords(CELL.badge), color = WHITE },
		face = face and { coords = CellCoords(CELL.lit), color = Now(face) } or nil,
		over = { coords = CellCoords(CELL.ring), color = Now(bezel) },
		flat = { coords = Trimmed(glyph), color = Now(lit and bezel or color) } }
end

-- The cell each of a mark's textures shows, so a mark laid again as it was asks nothing of the game.
local cellOf = setmetatable({}, { __mode = "k" })
local function Show(texture, cell)
	if cellOf[texture] ~= cell then
		cellOf[texture] = cell
		local col, row = cell % COLS, math.floor(cell / COLS)
		texture:SetTexCoord(col / COLS, (col + 1) / COLS, row / ROWS, (row + 1) / ROWS)
	end
	texture:Show()
end

-- A cell's SetTexCoord values, for files that draw the pictures themselves (Look.lua, Plates.lua).
function ns.MarkPicture(name)
	return CellCoords(CELL[name])
end
ns.MARKS_SMALL = SHEETS[1]

-- A picture of this sheet as a sign ShyCore's marks wear (Shy.Maps.Mark, a trip's mark): the same table
-- for the same name.
local foreign = {}
function ns.MarkSign(name)
	local sign = foreign[name]
	if not sign and CELL[name] then
		sign = { sheets = SHEETS, cell = CELL[name], cols = COLS, rows = ROWS }
		foreign[name] = sign
	end
	return sign
end

-- A stop's mark kind: its sign if it has one, else its kind. A stop that says its own kind of thing
-- (stop.tone: a ghost's body) is marked as an objective of that kind.
function ns.StopMark(stop)
	if stop.tone then return "goal" end
	return SIGN[stop.mark] and stop.mark or stop.kind
end

-- What a stop is for, as a mark's kind and (for an objective) what it asks for: a guide's step is its
-- first open line's, as on its hover (CardHover.lua). nil where there is nothing to say (a step that
-- only goes somewhere, a zone).
local COMMAND_SIGN = { train = "train", fp = "flight", hs = "home", home = "home", fly = "fly", vendor = "buy", skill = "skill",
	dungeon = "dungeon" }
-- ... and a line that has you use something or find a creature is an objective of that kind.
local COMMAND_TONE = { use = "gather", mob = "kill", target = "kill", unitscan = "kill" }
function ns.StopSign(stop)
	if stop.view then
		for _, view in ipairs(stop.views or { stop.view }) do
			for _, line in ipairs(view.lines) do
				if not line.done and not line.soft then
					if line.mark then return line.mark, line.mark == "goal" and ns.LineTone(line) or nil end
					-- No quest's line, but with a mark of its own: an item to get is an objective of the kind
					-- that gets it; a trainer, a flight point, the inn, a vendor, a skill and a dungeon have
					-- their errands' signs; something to use or a creature to find, an objective's kind.
					if line.command == "collect" and line.id then return "goal", ns.LineTone(line) end
					if COMMAND_SIGN[line.command] then return COMMAND_SIGN[line.command] end
					if COMMAND_TONE[line.command] then return "goal", COMMAND_TONE[line.command] end
				end
			end
		end
		return nil
	end
	local kind = ns.StopMark(stop)
	if kind == "zone" or kind == "guide" or kind == "errand" then return nil end
	return kind, ns.StopTone(stop)
end

-- The color of what a stop is for (StopSign): an objective's kind's, gold for a quest to take or hand in,
-- an errand's; nil for a stop that only goes somewhere.
function ns.StopColor(stop)
	local sign, tone = ns.StopSign(stop)
	if sign == "goal" then return ns.ToneColor(tone) end
	if sign == "pickup" or sign == "turnin" then return MARK.gold end
	if sign == "fly" then return ERRAND.travel end
	return sign and SIGN[sign] or nil
end

-- A mark as an inline texture escape, for tooltip lines. One cell each: text can't layer pictures,
-- so an objective is its emblem alone.
local SMALL = 32             -- cell size of the small sheet
local INLINE = { pickup = { "!", MARK.gold }, turnin = { "?", MARK.gold } }
-- tone: for an objective, its kind (KIND), whose emblem and color it takes.
function ns.MarkText(kind, size, tone)
	local look = INLINE[kind]
	local cell, color = CELL[look and look[1] or ns.ToneSign(tone)], look and look[2] or ns.ToneColor(tone)
	local col, row = cell % COLS, math.floor(cell / COLS)
	local text = ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(SHEETS[1], size, size, COLS * SMALL, ROWS * SMALL,
		col * SMALL, (col + 1) * SMALL, row * SMALL, (row + 1) * SMALL,
		math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
	return text
end

-- A mark on a hover seat (Shy.Hover): created once per seat, set on every show.
-- lead: the size it asks of a card's row. inner: the mark's own size, when smaller than its seat.
-- tone: an objective's kind (KIND).
function ns.MarkSeat(kind, lead, inner, tone)
	return { key = "shyquest-mark" .. (inner or ""), sig = "shyquest-mark:" .. kind .. (tone or ""), lead = lead, set = function(seat)
		if not seat.mark then
			seat.mark = ns.CreateMark(seat, inner or seat:GetWidth(), "small")
			seat.mark:SetPoint("CENTER")
		end
		seat.mark:Set(kind, nil, nil, tone)
	end }
end

-- fixed: "small" or "large" picks the sheet, for a mark on a frame that can't be measured (a
-- nameplate); otherwise the mark measures its on-screen size.
-- tipped: the mark is on a map, so a pin's point is at the mark's middle with its head above.
-- Otherwise a pin is centered.
function ns.CreateMark(parent, size, fixed, tipped)
	local mark = CreateFrame("Frame", nil, parent)
	mark:SetSize(size, size)
	-- The bloom behind, the glass, a lit face over it, the bezel, the glyphs.
	local bloom = mark:CreateTexture(nil, "BACKGROUND")
	local plate = mark:CreateTexture(nil, "BORDER")
	plate:SetAllPoints()
	local face = mark:CreateTexture(nil, "BORDER", nil, 1)
	face:SetAllPoints(plate)
	local bezel = mark:CreateTexture(nil, "BORDER", nil, 2)
	bezel:SetAllPoints(plate)
	-- lift: the picture's middle above the mark's, in sizes (so a tipped pin's point is on the place).
	-- head: the pin head's middle above that.
	local lift, head = 0, 0
	local shaped                 -- whether the mark is shaped as a pin now (nil: not shaped yet)
	local function Shape(isPin)
		if shaped == isPin then return end
		shaped = isPin
		lift = (isPin and tipped) and PIN_TIP or 0
		head = isPin and PIN_HEAD or 0
		plate:ClearAllPoints()
		plate:SetPoint("CENTER", mark, "CENTER", 0, lift * size)
		plate:SetSize(size, size)
		bloom:ClearAllPoints()
		bloom:SetPoint("CENTER", plate, "CENTER", 0, 0)
		bloom:SetSize(size * BLOOM_SCALE, size * BLOOM_SCALE)
		-- A tipped pin is drawn above the mark's frame: move the hit rect onto the picture, from the
		-- point to the top of the head and as wide as the head.
		if tipped then
			local up = lift * size
			mark:SetHitRectInsets(isPin and PIN_SIDE * size or 0, isPin and PIN_SIDE * size or 0, -up, up)
		end
	end
	local glyphs = {}
	for i = 1, 2 do
		glyphs[i] = mark:CreateTexture(nil, "ARTWORK")
	end
	local regions = { bloom, plate, face, bezel, glyphs[1], glyphs[2] }
	local sheet, hovered, chosen, picked = nil, false, false, false

	-- Use the sheet nearer the mark's current on-screen size.
	local function Sheet()
		local want
		if fixed then
			want = SHEETS[fixed == "large" and 2 or 1]
		else
			local _, height = GetPhysicalScreenSize()
			local pixels = size * mark:GetEffectiveScale() * height / 768
			want = SHEETS[pixels > LARGE_FROM and 2 or 1]
		end
		if want ~= sheet then
			sheet = want
			for _, region in ipairs(regions) do
				region:SetTexture(sheet)
				cellOf[region] = nil
			end
			return true
		end
		return false
	end

	-- A glyph on the picture's middle (or a pin's head), `offset` sizes to the side.
	local function Glyph(i, cell, color, share, offset, fade)
		local glyph = glyphs[i]
		glyph:ClearAllPoints()
		glyph:SetPoint("CENTER", mark, "CENTER", (offset or 0) * size, (lift + head) * size)
		glyph:SetSize(size * (share or 1), size * (share or 1))
		UI.Tint(glyph, color, fade or 1)
		Show(glyph, cell)
	end

	-- One digit centered, or two spaced by their ink widths. scale: smaller on a pin's head.
	local function Number(count, color, scale)
		scale = scale or 1
		count = math.max(0, math.min(99, math.floor(tonumber(count) or 0)))
		if count < 10 then
			Glyph(1, DIGIT + count, color, scale)
			return
		end
		local tens, ones = math.floor(count / 10), count % 10
		local width = INK[tens] + GAP + INK[ones]
		local share = math.min(MOST, FIT / width) * scale
		Glyph(1, DIGIT + tens, color, share, (-width / 2 + INK[tens] / 2) * share)
		Glyph(2, DIGIT + ones, color, share, (width / 2 - INK[ones] / 2) * share)
	end

	-- What the mark is of: kind, color, glyph, count (Set); drawn by Apply in the mark's state.
	local look = {}

	-- A round plate: the glass under everything, a lit `faceColor` over it or none, the bezel, and the
	-- bloom round a lit plate.
	local function Plate(faceColor, bezelColor, bloomColor, fade)
		fade = fade or 1
		UI.Tint(plate, WHITE, fade)
		Show(plate, CELL.badge)
		if faceColor then
			UI.Tint(face, faceColor, fade)
			Show(face, CELL.lit)
		else
			face:Hide()
		end
		UI.Tint(bezel, bezelColor, fade)
		Show(bezel, CELL.ring)
		if bloomColor then
			UI.Tint(bloom, bloomColor, fade)
			Show(bloom, CELL.bloom)
		else
			bloom:Hide()
		end
	end

	-- Draw the mark in its state (Layers).
	local function Apply()
		local lit = picked or hovered or chosen
		local kind, color = look.kind, look.color
		glyphs[1]:Hide()
		glyphs[2]:Hide()
		if kind == "step" or kind == "zone" then
			-- A map pin: slate with a white number; lit, the route's white with a graphite one.
			face:Hide()
			bezel:Hide()
			bloom:Hide()
			UI.Tint(plate, lit and MARK.route or MARK.slate, 1)
			Show(plate, CELL.pin)
			Number(look.count, lit and MARK.graphite or MARK.route, PIN_NUMBER)
		else
			local faceColor, bezelColor, bloomColor, ink = Layers(kind, color, lit)
			-- (A quest in a mood of its own: MOOD.)
			local mood = (kind == "pickup" or kind == "turnin") and MOOD[look.mood] or nil
			if mood then faceColor, bezelColor, bloomColor, ink = MoodLayers(kind, mood, lit) end
			local fade = mood and not lit and mood.alpha or 1
			Plate(faceColor, bezelColor, bloomColor, fade)
			Glyph(1, kind == "turnin" and CELL["?"] or look.glyph, ink, nil, nil, fade)
		end
	end

	-- kind: turnin | pickup | goal | guide | fly | errand | step | zone | a sign (SIGN).
	-- singled: chosen by the player (for a step: the live one); the mark is lit.
	-- count: a step's number or a zone's quest count; a "guide" mark with a count is drawn as a step.
	-- tone: an objective's kind (KIND): its emblem and its color.
	-- (Set as it was last, on the same sheet: it is drawn as it is.)
	local was = {}
	function mark:Set(kind, singled, count, tone)
		local resheeted = Sheet()
		singled = singled and true or false
		if not resheeted and was.set and was.kind == kind and was.singled == singled and was.count == count
			and was.tone == tone then
			return
		end
		was.set, was.kind, was.singled, was.count, was.tone = true, kind, singled, count, tone
		chosen = singled
		self.singled = chosen     -- read by callers
		if kind == "guide" and count then kind = "step" end
		Shape(kind == "step" or kind == "zone")
		local mood = look.mood   -- (kept across: SetMood's)
		wipe(look)
		look.mood = mood
		look.kind, look.count = kind, count
		look.color, look.glyph = Look(kind, tone)
		if look.color and not SIGN[kind] and not PLAIN[kind] and kind ~= "pickup" then look.tone = tone end
		Apply()
	end

	-- Another picture on the same mark, until the next Set: the escort's face as the walk goes
	-- ("escortLate" past its time, "escortDone" at its end). nil puts the kind's own back.
	function mark:SetEmblem(name)
		local cell = CELL[name] or (look.tone and CELL[ns.ToneSign(look.tone)]) or look.glyph
		if cell == look.glyph then return end
		look.glyph = cell
		-- (The next Set draws the kind's own again, even as it was.)
		was.set = nil
		Apply()
	end

	-- A quest's mood (MOOD): "trivial" (too low to give XP), "aside" (you set it aside), or nil.
	function mark:SetMood(mood)
		mood = MOOD[mood] and mood or nil
		if mood == look.mood then return end
		look.mood = mood
		Apply()
	end

	function mark:SetHovered(on)
		on = on and true or false
		if on == hovered then return end
		hovered = on
		Apply()
	end

	function mark:SetPicked(on)
		on = on and true or false
		if on == picked then return end
		picked = on
		Apply()
	end

	-- The letter of the objective the mark is for, in a quest of several (ns.Objective's; nil for none):
	-- its disc over the plate's lower right, as a numbered place's mark stands over its pin's.
	function mark:SetLetter(one)
		if not one and not self.letter then return end
		if not self.letter then
			self.letter = ns.CreateLetter(self, LETTER_ON_MARK * size)
			self.letter:SetPoint("CENTER", plate, "CENTER", LETTER_AT * size, -LETTER_AT * size)
			self.letter:SetFrameLevel(self:GetFrameLevel() + 2)
		end
		self.letter:Set(one)
	end

	return mark
end
