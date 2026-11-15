-- Shy.Stage: immersive mode worn in the theme's look. The quest dialog's stage (Talk.lua) and the away board's floor
-- (Away.lua) are drawn in the family's own make under Forged; in any other look the stage itself is dressed in that
-- look, never a window set over it: a talk under Heritage stands on the game's own bronze, under Comic on an inked page:
--   the floor   the stage's ground is a housing of the look across the whole foot of the screen, its top edge on the
--               stage's line and the rest run past the screen's sides and foot, so the look's ground, its art and its
--               light span the stage and the words stand on it as they do on the family's own
--   the name    no plate: the ring pinned solid on the stage's line and the name lettered on the line beside it, in the
--               look's title ink over a soft shadow; a look that letters captions (Comic) sets it in a solid caption
--               box of the look in your color instead, the name in the ink that reads on it
--   the lines   the stage's line along the screen and the rule between the words and the answers are the look's own
--               header line (UI.LookLine: a seam, a trim of metal, the game's bronze bar, a burnt seam, chipped paint)
--   the board   the away board's floor is the same housing, its top edge on the board's line
-- Every piece follows the theme live: a change of look, color, gradient or look option re-dresses a talk that is up.
--
--   Shy.Stage.Talk(box, ui, m)   Talk.lua, once its dialog is built: its pieces (ui) and measures (m: line, nameX,
--                                the plaque's end)
--   Shy.Stage.Floor(board, p)    Away.lua, once its floor is built: p = { floor, lit, line, ground, frost, shade,
--                                glow, light }
--   Shy.Stage.Dressed()          the look the stage is worn in now ("forged": the family's own make), for tests
--   Shy.Stage.talk / .away       the pieces made, once made: floor, plaque, caption, line, rule / floor
-- (The speaker stands in no frame in any look: head and chest rise out of the line, Talk.lua's.)
local Shy = Shy
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors

local Stage = {}
Shy.Stage = Stage

-- The plaque's housing round its strip (left, top, right, bottom).
local PLAQUE_PAD = { 4, 3, 4, 3 }
-- The room over the rule for a look's light off its line (the eclipse's flare).
local RULE_ROOM = 10
-- A floor runs past the screen's sides and foot by this, so only its top edge is seen.
local OVER = 60
-- What a look does beyond the housings, by look: caption = the name in a caption box in your color.
local WAYS = { comic = { caption = true } }
-- The name on the line: this far past the ring, its middle this far over the line; the shadow under it this much wider
-- and this tall, this dark.
local NAME = { gap = 7, up = 11, size = 17, poolWide = 90, poolTall = 56, pool = 0.55 }

local talk, away

-- The look the stage wears: the family's own make under Forged, the theme's look otherwise.
local function Worn()
	return Theme.Look()
end

function Stage.Dressed()
	return Worn()
end

-- A housing's fill: the panel's color as dense as the stage's own ground (a dialog's, whatever the Background setting),
-- so the words read on it as they do on the stage.
local GROUND = 0.88
local function Ground()
	local c = C.panel
	return c[1], c[2], c[3], GROUND
end

-- A caption's fill: solid, nothing seen through it.
local function Solid()
	local c = C.panel
	return c[1], c[2], c[3], 1
end

-- A housing of the theme's look on `parent` at `level`: a window's make (its look worn whole, never faded with the HUD).
local function Housing(parent, level, fill)
	local f = CreateFrame("Frame", nil, parent)
	f:SetFrameLevel(level)
	UI.Panel(f, { window = true, line = false, fill = fill or Ground })
	return f
end

-- A floor of the look: across the screen from `line` down, past the sides and foot so only its top edge shows.
local function Floor(parent, level, line, foot)
	local f = Housing(parent, level)
	f:SetPoint("TOPLEFT", line, "TOPLEFT", -OVER, 0)
	f:SetPoint("BOTTOMRIGHT", foot, "BOTTOMRIGHT", OVER, -OVER)
	return f
end

-- The family's own pieces: seen under Forged, put away under a look that dresses the stage. (Their owners never show
-- or hide them, only fade them, so their own alphas and breaths are left as they are.)
local function Own(list, on)
	for _, region in ipairs(list) do region:SetShown(on) end
end

-- One of the stage's lines, worn as the look's header line; `room` the region over it a look's light may reach up to.
local function Line(owner, to, room)
	local line = UI.HeadLine(owner)
	line:SetPoint("TOPLEFT", to, "TOPLEFT")
	line:SetPoint("TOPRIGHT", to, "TOPRIGHT")
	line.room = room
	return line
end

local function DressLine(line, look, plain)
	line:SetShown(not plain)
	if not plain then UI.LookLine(line:GetParent(), line, look, line.room) end
end

-- The caption box's ink: what reads on it. The box is your color held where its words read (UI.colors.face,
-- Theme.FaceFor: a warrior's tan holds neither white nor black at a name's contrast), the ink the one for it.
local function CaptionInk()
	local ink = UI.colors.onFace
	return ink[1], ink[2], ink[3]
end

local function DressTalk()
	local t = talk
	if not t then return end
	local look = Worn()
	local plain = look == "forged"
	local way = WAYS[look] or {}
	local caption = way.caption and not plain
	t.floor:SetShown(not plain)
	t.plaque:SetShown(caption and t.ui.plaque:IsShown())
	t.plaque.on = caption
	-- The family's own: the stage's frost under Forged and Frosted alone; its ground (the wash's fade and the floor: left
	-- under a look's floor they would darken a band below the line), the dark band under the line and its light, the
	-- plaque's metal, the rule's hairline under Forged alone. The dusk over the world stays, easing it into the floor.
	local stage = t.ui.stage
	local art = stage.art
	Own({ art.frost }, plain or look == "clear")
	Own({ stage.wash, stage.floor, art.shade, art.glow, stage.light }, plain)
	Own({ t.ui.strip, t.ui.plaque.art.tip, t.ui.plaque.art.gloss }, plain)
	Own({ t.ui.rule }, plain)
	DressLine(t.line, look, plain)
	DressLine(t.rule, look, plain)
	-- The name: on the plaque (Forged's metal, or a caption box), or on the line beside the ring.
	local seam = not plain and not caption
	local name = t.ui.name
	name:ClearAllPoints()
	if seam then
		name:SetFontObject(UI.NameFont(NAME.size))
		name:SetPoint("LEFT", t.ui.ring, "RIGHT", NAME.gap, NAME.up)
	else
		name:SetFontObject(UI.NameFont(t.m.nameSize))
		name:SetPoint("LEFT", t.ui.strip, "LEFT", t.m.nameAt[1], t.m.nameAt[2])
	end
	t.pool:SetShown(seam)
	-- The caption: your color under the name, lettered in the ink that reads on it, with no shadow.
	t.caption:SetShown(caption)
	if caption then
		UI.Ink(name, CaptionInk)
		name:SetShadowColor(0, 0, 0, 0)
	else
		UI.Ink(name, seam and function() return UI.TitleInk(C.head) end or C.head)
		name:SetShadowColor(0, 0, 0, 1)
	end
end

local function DressAway()
	local a = away
	if not a then return end
	local plain = Worn() == "forged"
	a.floor:SetShown(not plain)
	Own({ a.p.ground, a.p.shade, a.p.glow, a.p.light }, plain)
	Own({ a.p.frost }, plain or Worn() == "clear")
end

local function Dress()
	DressTalk()
	DressAway()
end

function Stage.Talk(box, ui, m)
	if talk then return end
	talk = { box = box, ui = ui, m = m }
	Stage.talk = talk
	-- The floor: on the stage's own frame, over its wash (whose fade over the line still eases the world into it) and
	-- under the dialog, which stands a strata above; it comes and goes with the stage.
	local stage = ui.stage
	local floor = Floor(stage, stage:GetFrameLevel() + 1, ui.line, stage)
	talk.floor = floor
	-- The caption box: under the name, the ring at its head standing over its start; solid.
	local plaque = Housing(box, ui.plaque:GetFrameLevel() - 1, Solid)
	plaque:SetPoint("TOPLEFT", ui.strip, "TOPLEFT", -PLAQUE_PAD[1], PLAQUE_PAD[2])
	plaque:SetPoint("BOTTOMRIGHT", ui.strip, "BOTTOMRIGHT", m.plaqueEnd + PLAQUE_PAD[3], -PLAQUE_PAD[4])
	talk.plaque = plaque
	local caption = plaque:CreateTexture(nil, "BACKGROUND", nil, -5)
	caption:SetPoint("TOPLEFT", 1.5, -1.5)
	caption:SetPoint("BOTTOMRIGHT", -1.5, 1.5)
	Theme.Paint(caption, UI.colors.face)
	caption:Hide()
	talk.caption = caption
	-- Shown with the dialog's plaque (no name, no plaque), and only under a look that dresses it.
	local function Follow()
		plaque:SetShown(plaque.on == true and ui.plaque:IsShown())
		plaque:SetAlpha(ui.plaque:GetAlpha())
	end
	for _, method in ipairs({ "Show", "Hide", "SetShown", "SetAlpha" }) do hooksecurefunc(ui.plaque, method, Follow) end
	-- The soft shadow under the name on the line, so it reads over any world: on the dialog's plaque, going with it.
	local pool = ui.plaque:CreateTexture(nil, "BACKGROUND", nil, -8)
	pool:SetTexture(Shy.MEDIA .. "Glow")
	pool:SetVertexColor(0, 0, 0, NAME.pool)
	pool:SetPoint("TOPLEFT", ui.name, "LEFT", -NAME.poolWide / 2, NAME.poolTall / 2)
	pool:SetPoint("BOTTOMRIGHT", ui.name, "RIGHT", NAME.poolWide / 2, -NAME.poolTall / 2)
	pool:Hide()
	talk.pool = pool
	-- The stage's line along the floor's top edge (the wash's rise over it is the room for a look's light), and the rule.
	talk.line = Line(floor, ui.line, stage.wash)
	local room = box:CreateTexture(nil, "ARTWORK")
	room:SetPoint("BOTTOMLEFT", ui.rule, "TOPLEFT")
	room:SetPoint("BOTTOMRIGHT", ui.rule, "TOPRIGHT")
	room:SetHeight(RULE_ROOM)
	talk.rule = Line(box, ui.rule, room)
	DressTalk()
end

function Stage.Floor(board, p)
	if away then return end
	away = { p = p }
	Stage.away = away
	-- On the floor's own frame (its alpha rises with the board), at its level: drawn before the figure and the words,
	-- which stand at the same level and were made after.
	away.floor = Floor(p.floor, p.floor:GetFrameLevel(), p.line, board)
	DressAway()
end

Shy:On("SHY_THEME", Dress)
