-- The meter: a meter window in the dressed damage meter's make, through and through. Its header is the damage
-- meter's: the chooser at the left where the meter's type stands ("Threat", its menu how the numbers read: Tank or
-- Damage), the mob the table is for where the meter shows its fight, and the cog at the right. Its rows are the
-- meter's, as tall and as far apart as the damage meter has its own (DamageMeter:GetBarHeight, GetBarSpacing): a
-- class icon in a slot, a bar in the hatch with a lit top, a dark foot and a bright tip, the name at the left and the
-- number at the right. One builder, ns.CreateCard, makes the box's card and the options' preview.
--
-- It is sized as the damage meter is, from every corner and side (Shy.HUD's flowing grip): its height is how many
-- rows show before the rest scroll (the mouse wheel; a slim marker at the right says where you are), and unused
-- places stand as faint wells, so its size reads at a glance. Until you size it, its size is planned: the width of
-- its home and the setting's rows (Shy.HUD.Made); a setup gives that back.
--
-- It shows in your fights by default; the setting (or the layout editor's "Show out of combat") keeps it up between
-- them too, or keeps it to group fights. Layout mode always shows it, a made-up fight in it, to place and size. Up
-- out of a fight it rests quietly: the last fight's table, said so, or with none yet a line saying all is quiet.
--
-- Where it stands is ShyDock's to plan (Arrange.lua): in a classic layout a meter window standing on the damage
-- meter at its width, the mirror of the stack over chat; in a layout by role by your target, as the role has it.
-- The rows it is planned at are the setting's, fewer where its slot has room for fewer (Dock:MeterRows).
--
-- A bar is how close that player is to pulling the mob (the holder's is full); its color is the class's, as the damage
-- meter's are. The number says the same in the family's threat colors (Theme.Threat, as ShyPlates' bars): a damage
-- dealer's share of the pull, green while far from it, red once they have it; the holder's lead over the next player
-- ("+28%"), green from 130, red at level. On a boss the game keeps the numbers secret: they go to the bar and the words
-- unread, the rows stand by the game's own state, and the header says "in group order".
-- Your row has your color's edge at its left, and stays in the last place when it would fall out (unscrolled).
-- The header lights in the threat colors as you near the pull (tanking: as the next player catches up on you), the
-- same margin ShyPlates colors that mob's bar by (Shy.Threat).

local ADDON, ns = ...
local T, Rd = ns.T, ns.Read
local UI, Theme, HUD = Shy.UI, Shy.Theme, Shy.HUD
local C = UI.colors
local GLYPH = Shy.Skin.GLYPH

local M = {}
ns.Meter = M

local WIDTH = 240
local HEAD = UI.HEAD_STRIP          -- the header (a console piece's, as the dressed damage meter's)
local TOP = HEAD + UI.LINE + 4      -- the first row, down from the top
-- A row's height and the room between two: the damage meter's own (Measure), these until it says.
local ROW, GAP = DAMAGE_METER_DEFAULT_BAR_HEIGHT or 25, DAMAGE_METER_DEFAULT_BAR_SPACING or 4
local MIN_W = 180                   -- the narrowest it is sized to
local SCROLL = 2                    -- the scroll marker's width
local WELL = 0.35                   -- an unused place's well, faint
local PAD, FOOT = 6, 7              -- in from the sides; under the last row
local EDGE = 2                      -- your row's mark
local TIP = 2                       -- the bright end of a fill
local CONTROL = UI.HEAD.piece.line - UI.HEAD.piece.lip   -- a header control's height (the damage meter's choosers)
local EDGE_X = 8                    -- the header's words and controls this far in
local EVERY = 0.2                   -- seconds between looks
local TRY = 10                      -- seconds of the made-up fight
local WARN = 0.5                    -- a margin under this lights the header
local SOUND_GAP = 3                 -- seconds at least between two warning sounds
local FADED = 0.55                  -- a fight gone by, while it lingers
local LEAST = 2                     -- rows at the least: planned, and sized to
local CLASSES = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CROP = 0.018
local PET_SHADE = 0.7               -- a pet's bar: its owner's class color, darker
local NONE = { 0.55, 0.57, 0.62 }   -- a bar whose class the game won't tell
local HINTS = { { "left", "Move" }, { "right", "Menu" } }
local SEP = "  \194\183  "

ns.cards = {}

local function Clamp(x)
	if x < 0 then return 0 elseif x > 1 then return 1 end
	return x
end

local function Readable(v) return v ~= nil and not issecretvalue(v) end

-- A row's margin, for its number's color: 1 held .. 0 lost (Shy.Threat's measure, for that player), or nil.
local function Margin(row)
	if Readable(row.tanking) and row.tanking then
		if row.lead then return Clamp((row.lead - 100) / 30) end
		if Readable(row.status) then return row.status == 3 and 1 or 0.4 end
		return nil
	end
	if Readable(row.scaled) then return Clamp((100 - row.scaled) / 40) end
	if Readable(row.status) then
		if row.status >= 2 then return 0 end
		return row.status == 1 and 0.15 or 1
	end
	return nil
end

local function ClassColor(class)
	if class == nil then return nil end
	local color = C_ClassColor.GetClassColor(class)
	if issecretvalue(color) or not color then return nil end
	return color.r, color.g, color.b
end

-- One row's frame: the slot, the bar and its words.
local function NewRow(card)
	local row = CreateFrame("Frame", nil, card)
	row:SetHeight(ROW)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW, ROW)
	row.icon:SetPoint("LEFT")
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = ROW, flat = true, hover = false })

	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 3, 0)
	bar:SetPoint("BOTTOMRIGHT")
	bar:SetMinMaxValues(0, 100)
	Shy.Skin.HatchBar(bar)
	row.bar = bar
	local well = bar:CreateTexture(nil, "BACKGROUND")
	well:SetAllPoints()
	UI.Paint(well, C.bg, 0.6)
	local fill = bar:GetStatusBarTexture()
	local lit = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	lit:SetColorTexture(1, 1, 1, 0.16)
	lit:SetHeight(1)
	lit:SetPoint("TOPLEFT", fill, "TOPLEFT")
	lit:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
	local shade = bar:CreateTexture(nil, "ARTWORK", nil, 3)
	shade:SetColorTexture(0, 0, 0, 0.4)
	shade:SetHeight(1)
	shade:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
	shade:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
	local tip = bar:CreateTexture(nil, "ARTWORK", nil, 4)
	tip:SetColorTexture(1, 1, 1, 0.3)
	tip:SetWidth(TIP)
	tip:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
	tip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")

	row.mine = row:CreateTexture(nil, "OVERLAY")
	row.mine:SetWidth(EDGE)
	row.mine:SetPoint("TOPRIGHT", row, "TOPLEFT", -2, 0)
	row.mine:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", -2, 0)
	UI.Paint(row.mine, Theme.Accent)

	row.value = UI.Words(bar, UI.NameFont(12, "OUTLINE"), nil, { world = true })
	row.value:SetPoint("RIGHT", -4, 0)
	row.value:SetJustifyH("RIGHT")
	row.name = UI.Words(bar, UI.NameFont(12, "OUTLINE"), nil, { world = true })
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetPoint("RIGHT", row.value, "LEFT", -4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	return row
end

-- Paints a row with what the game said (any number may be secret: it goes straight to its setter).
local function PaintRow(row, data)
	local class = data.class
	local at = Readable(class) and CLASS_ICON_TCOORDS[class]
	if at then
		row.icon:SetTexture(CLASSES)
		row.icon:SetTexCoord(at[1] + CROP, at[2] - CROP, at[3] + CROP, at[4] - CROP)
		row.icon:SetDesaturated(data.pet == true)
		row.icon:SetAlpha(data.pet and 0.6 or 1)
		row.slot:Empty(false)
	else
		row.icon:SetTexture(nil)
		row.slot:Empty(true)
	end
	local r, g, b = ClassColor(Readable(class) and class or nil)
	if not r then r, g, b = NONE[1], NONE[2], NONE[3] end
	if data.pet then r, g, b = r * PET_SHADE, g * PET_SHADE, b * PET_SHADE end
	row.bar:SetStatusBarColor(r, g, b)
	row.bar:SetValue(data.scaled or 0)
	row.name:SetText(data.name or "")
	UI.Ink(row.name, data.pet and C.dim or C.text)
	if Readable(data.tanking) and data.tanking and data.lead then
		row.value:SetFormattedText("%+.0f%%", data.lead - 100)
	elseif data.scaled ~= nil then
		row.value:SetFormattedText("%.0f%%", data.scaled)
	else
		row.value:SetText("")
	end
	local m = Margin(data)
	if m then
		row.value:SetTextColor(Theme.Threat(m))
	else
		UI.Ink(row.value, C.dim)
	end
	row.mine:SetShown(data.me == true)
end

-- How the numbers read (the chooser's menu): by your role (Shy.Role), as a tank's or as anyone else's.
local function ViewMenu(root)
	local db = T.db
	root:CreateTitle("Read the numbers as")
	-- (which role that is now, and why: "Tank, from your Protection build")
	local says = Shy.RoleSays()
	root:CreateRadio(says and ("My role: " .. says) or "My role", function() return db.role == "auto" end, function()
		db.role = "auto"
		ns.Apply()
	end)
	root:CreateRadio("Tank: my lead over the next player", function() return db.role == "tank" end, function()
		db.role = "tank"
		ns.Apply()
	end)
	root:CreateRadio("Damage or healing: how close to the pull", function() return db.role == "dps" end, function()
		db.role = "dps"
		ns.Apply()
	end)
end

-- The rows' height and spacing as the damage meter has its own (Edit Mode's sliders), read when asked. Returns
-- whether they changed.
local function Measure()
	local meter = rawget(_G, "DamageMeter")
	local h = meter and meter.GetBarHeight and meter:GetBarHeight()
	local s = meter and meter.GetBarSpacing and meter:GetBarSpacing()
	local row = (type(h) == "number" and not issecretvalue(h) and h >= 12) and math.floor(h + 0.5) or ROW
	local gap = (type(s) == "number" and not issecretvalue(s) and s >= 0) and math.floor(s + 0.5) or GAP
	local changed = row ~= ROW or gap ~= GAP
	ROW, GAP = row, gap
	return changed
end
M.Measure = Measure

-- The card's height with `n` rows, and the rows a card `height` tall shows.
local function Height(n) return TOP + n * ROW + (n - 1) * GAP + FOOT end
local function Fits(height) return math.max(1, math.floor((height - TOP - FOOT + GAP) / (ROW + GAP))) end
M.Height = Height

-- The card. box: the Shy.HUD box it fills (nil for a preview, which is given its size with card:Flow): it takes the
-- mouse and the wheel, its controls drag the box, its cog opens the box's menu.
function ns.CreateCard(parent, box)
	local card = CreateFrame("Frame", nil, parent)
	card.box = box
	card:SetSize(WIDTH, Height(T.db.rows))
	UI.Panel(card, { cap = true, title = HEAD, facets = false, hud = true })

	-- The header, the damage meter's: the chooser where the meter's type stands, the mob where it shows its fight,
	-- the cog at the right.
	card.view = UI.MenuButton(card, { font = UI.TitleFont(UI.TITLE_SIZE), height = CONTROL, write = ViewMenu, drag = box,
		tip = "How the numbers read. A tank's row is its lead over the next player; anyone else's is how close they are to pulling." })
	card.view:SetLabel("Threat", C.text)
	card.cog = UI.MenuButton(card, { height = CONTROL, drag = box, tip = "Threat meter menu",
		write = function(root) if ns.Meter.Menu then ns.Meter.Menu(root) end end })
	card.cog:SetGlyph(GLYPH.gear)
	card.mob = UI.Text(card, "", 11, true, C.dim)
	card.mob:SetJustifyH("RIGHT")
	card.mob:SetWordWrap(false)

	-- The light along the header: your threat trouble on this mob.
	card.light = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.light:SetColorTexture(1, 1, 1, 1)
	card.light:SetPoint("TOPLEFT", 2, -2)
	card.light:SetPoint("TOPRIGHT", -2, -2)
	card.light:SetHeight(HEAD - 2)
	card.light:SetAlpha(0)
	card.trouble = nil   -- the margin lighting it, or nil

	-- Out of a fight with none to show: a quiet line in the middle of the rows.
	card.quiet = UI.Text(card, "", 12, true, C.dim)
	card.quiet:SetJustifyH("CENTER")
	card.quietLine = UI.Text(card, "", 11, false, C.dim)
	card.quietLine:SetJustifyH("CENTER")
	card.quietLine:SetWordWrap(true)

	-- Where you are in a table longer than the card: a slim marker at the rows' right edge.
	card.track = card:CreateTexture(nil, "ARTWORK")
	card.track:SetWidth(SCROLL)
	UI.Paint(card.track, C.bg, 0.5)
	card.thumb = card:CreateTexture(nil, "ARTWORK", nil, 1)
	card.thumb:SetWidth(SCROLL)
	UI.Paint(card.thumb, Theme.Accent)

	card.rows, card.wells = {}, {}
	card.places = Fits(card:GetHeight())   -- rows it has room for
	card.offset = 0                        -- rows scrolled past

	-- Lays the header out: the chooser and the cog where the dressed damage meter has its own, the mob between them.
	function card:Lay()
		self.view:ClearAllPoints()
		self.cog:ClearAllPoints()
		self.mob:ClearAllPoints()
		UI.OnHead(self.view, "LEFT", self, "LEFT", EDGE_X)
		UI.OnHead(self.cog, "RIGHT", self, "RIGHT", -EDGE_X)
		self.mob:SetPoint("RIGHT", self.cog, "LEFT", -4, 0)
		self.mob:SetPoint("LEFT", self.view, "RIGHT", 6, 0)
	end

	-- The rows it is planned at: the setting's, no more than its slot has room for (ShyDock: Dock:MeterRows).
	function card:Most()
		local most = T.db.rows
		local dock = self.box and Shy.addons.Dock
		local room = dock and dock.MeterRows and dock:MeterRows()
		if room then most = math.max(LEAST, math.min(most, room)) end
		return most
	end

	-- The card at a size (own units): as many places as fit, the table drawn again. The box's grip calls it as it
	-- flows; a preview is sized by it.
	function card:Flow(width, height)
		if not self.box then self:SetSize(width, height) end
		self.places = Fits(height)
		self:Draw()
	end

	-- Fills it with `rows` (Read's form) under the mob's `name`; `note`: a word on how it stands ("in group order",
	-- "last fight"); `faded`: a fight gone by, lingering; `quiet`: { words, line } for a card with nothing to show.
	function card:Fill(rows, name, note, faded, quiet)
		local was = self.filled
		if not was or was[2] ~= name then self.offset = 0 end   -- another mob: from the top
		self.filled = { rows, name, note, faded, quiet }
		self:Draw()
	end

	-- Draws what it was filled with in the places it has: from the top, your row in the last place when it would
	-- fall out; scrolled, the rows from there. An unused place is a faint well.
	function card:Draw()
		local f = self.filled
		if not f then return end
		local rows, name, note, faded, quiet = f[1], f[2], f[3], f[4], f[5]
		local places = self.places
		self.offset = math.max(0, math.min(self.offset, #rows - places))
		local shown
		if self.offset == 0 then
			shown = Rd.Shown(rows, places)
		else
			shown = {}
			for i = 1, places do shown[i] = rows[self.offset + i] end
		end
		local over = #rows > places
		local right = -(PAD + (over and SCROLL + 2 or 0))
		for i = 1, places do
			local top = -(TOP + (i - 1) * (ROW + GAP))
			local data = shown[i]
			local row = self.rows[i]
			if data then
				if not row then
					row = NewRow(self)
					self.rows[i] = row
				end
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", PAD + EDGE + 2, top)
				row:SetPoint("RIGHT", right, 0)
				row:SetHeight(ROW)
				row.icon:SetSize(ROW, ROW)
				PaintRow(row, data)
				row:Show()
			elseif row then
				row:Hide()
			end
			local well = self.wells[i]
			if not well then
				well = self:CreateTexture(nil, "BORDER", nil, 1)
				UI.Paint(well, C.bg, WELL)
				self.wells[i] = well
			end
			well:ClearAllPoints()
			well:SetPoint("TOPLEFT", PAD + EDGE + 2, top)
			well:SetPoint("RIGHT", right, 0)
			well:SetHeight(ROW)
			well:SetShown(data == nil)
		end
		for i = places + 1, #self.rows do self.rows[i]:Hide() end
		for i = places + 1, #self.wells do self.wells[i]:Hide() end
		-- The scroll marker: the track down the rows, the thumb where the places shown stand in the table.
		self.track:SetShown(over)
		self.thumb:SetShown(over)
		if over then
			local tall = places * ROW + (places - 1) * GAP
			self.track:ClearAllPoints()
			self.track:SetPoint("TOPRIGHT", -PAD, -TOP)
			self.track:SetHeight(tall)
			local thumb = math.max(ROW / 2, tall * places / #rows)
			self.thumb:ClearAllPoints()
			self.thumb:SetPoint("TOPRIGHT", -PAD, -(TOP + (tall - thumb) * self.offset / (#rows - places)))
			self.thumb:SetHeight(thumb)
		end
		-- With nothing to show, a quiet word over the wells.
		local q = #rows == 0 and quiet or nil
		self.quiet:SetShown(q ~= nil)
		self.quietLine:SetShown(q ~= nil)
		if q then
			local mid = TOP + (places * (ROW + GAP) - GAP) / 2
			self.quiet:SetText(q[1])
			self.quietLine:SetText(q[2])
			self.quiet:ClearAllPoints()
			self.quiet:SetPoint("BOTTOM", self, "TOP", 0, -(mid - 1))
			self.quietLine:ClearAllPoints()
			self.quietLine:SetPoint("TOP", self, "TOP", 0, -(mid + 2))
			self.quietLine:SetWidth(math.max(60, self:GetWidth() - 2 * (PAD + 8)))
		end
		if name == nil then
			self.mob:SetText("")
		elseif note then
			self.mob:SetText(name .. SEP .. note)
		else
			self.mob:SetText(name)
		end
		self:SetAlpha(faded and FADED or 1)
	end

	-- Scrolled by a row a notch, within the table.
	function card:Scroll(delta)
		local f = self.filled
		if not f then return end
		local most = math.max(0, #f[1] - self.places)
		local offset = math.max(0, math.min(most, self.offset - delta))
		if offset == self.offset then return end
		self.offset = offset
		self:Draw()
	end

	-- The light at your margin (nil: none).
	function card:Trouble(margin)
		if type(margin) ~= "number" or margin >= WARN or not T.db.warn then margin = nil end
		self.trouble = margin
		if margin then
			-- (A gradient is its corners' colors: set whole, never tinted over.)
			local r, g, b = Theme.Threat(margin)
			self.light:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
		end
		self:Breathe()
	end
	function card:Breathe()
		local m = self.trouble
		if not m then
			self.light:SetAlpha(0)
			return
		end
		local worry = 1 - m / WARN
		local breath = 0.5 + 0.5 * math.sin(GetTime() * math.pi * (1 + 2 * worry))
		self.light:SetAlpha((0.25 + 0.45 * worry) * (0.7 + 0.3 * breath))
	end

	if box then
		card:SetAllPoints(box)
		card:EnableMouse(true)
		card:EnableMouseWheel(true)
		card:SetScript("OnMouseWheel", function(self, delta) self:Scroll(delta) end)
		card:SetScript("OnEnter", function(self)
			local text
			if T:IsTank() then
				text = "The top row holds it. Its number is the lead over the next player: at +30% nobody can pull it."
			else
				text = "Each bar is how close that player is to pulling it. Melee pulls at 110% of the holder's threat, range at 130%."
			end
			UI.Tip(self, "Threat", text, { hints = HINTS })
		end)
		card:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	end

	ns.cards[card] = true
	card:Lay()
	card:Fill({}, nil, nil, false)
	return card
end

-- The title's font may change with the theme: the header is laid again.
Shy:On("SHY_THEME", function()
	for card in pairs(ns.cards) do card:Lay() end
end)

-- The box

local box, card, driver
local live = false          -- the game has a table to show
local lastLive = 0          -- when it last had
local kept                  -- the last table shown: { rows, name, sorted, guid }, for while it is kept on
local gone = false          -- the mob that table was of died, or you let go of it: nothing lingers
local trying                -- the made-up fight's start
local warned = false        -- the header was lit at the last look
local soundAt = 0
local fitted                -- the width its home gives it (ShyDock), or nil

local function On() return T.db.on == true end

local function Fighting() return UnitAffectingCombat("player") == true end

-- The last table stays faded a while only while its mob is still there to read (a fight that ended with it alive:
-- it reset, or you got away); the mob dead or let go of, the meter goes with it (Look).
local function Lingering()
	return not live and kept ~= nil and not gone and GetTime() - lastLive < T.db.linger
end

-- When it shows (T.db.when): always; in your fights (a table, the one lingering, or you in combat); in group fights
-- (a table, which Read leaves empty out of a group, or the one lingering).
local function Shown()
	if trying then return true end
	if not On() then return false end
	if live or Lingering() then return true end
	if T.db.when == "always" then return true end
	-- In your fights: but not one you fight alone (no group, no pet), where it would stand empty.
	return T.db.when == "combat" and Fighting() and not ns.Read.Alone()
end

-- Layout mode, Edit Mode or the made-up fight with no fight to show: the sample.
local function Sampling()
	return trying ~= nil or (HUD.IsUnlocked() and not live)
end

-- Its words with nothing to show.
local QUIET = {
	rest = { "All quiet", "Who has aggro shows here once a fight starts." },
	fight = { "No enemy targeted", "Target one to see who has it." },
}

local function Paint()
	if not card then return end
	if Sampling() then
		local rows, name = Rd.Sample()
		card:Fill(rows, name, nil, false)
		card:Trouble(trying and 0.3 or nil)
	elseif live then
		card:Fill(Rd.rows, Rd.name, not Rd.sorted and "in group order" or nil, false)
		card:Trouble(Rd.margin)
	elseif Lingering() then
		card:Fill(kept[1], kept[2], not kept[3] and "in group order" or nil, true)
		card:Trouble(nil)
	elseif Fighting() then
		card:Fill({}, nil, nil, false, QUIET.fight)
		card:Trouble(nil)
	elseif kept then
		card:Fill(kept[1], kept[2], "last fight", false)
		card:Trouble(nil)
	else
		card:Fill({}, nil, nil, false, QUIET.rest)
		card:Trouble(nil)
	end
end

local function Warn()
	local now = card and card.trouble ~= nil and live
	if now and not warned and T.db.sound and GetTime() - soundAt > SOUND_GAP then
		soundAt = GetTime()
		PlaySound(SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING, "Master")
	end
	warned = now and true or false
end

local function Look()
	if trying and GetTime() - trying > TRY then trying = nil end
	if not On() and not trying then
		live = false
	else
		live = Rd.Look() or false
		if live then
			lastLive, gone = GetTime(), false
			local guid = UnitGUID(Rd.mob)
			kept = { Rd.rows, Rd.name, Rd.sorted, not issecretvalue(guid) and guid or nil }
		else
			-- No living enemy to read (it died, or you dropped your target), or another one than the table's: the
			-- meter lets it go at once. Shown always, it keeps the last fight's table, said so.
			local mob = Rd.Mob()
			local guid = mob and UnitGUID(mob)
			if not mob or (kept and kept[4] and guid and not issecretvalue(guid) and guid ~= kept[4]) then gone = true end
			if kept and T.db.when ~= "always" and (gone or GetTime() - lastLive >= T.db.linger) then kept = nil end
		end
	end
	Paint()
	Warn()
	if box then HUD.Update(box) end
	-- At rest it costs nothing a frame: the driver runs only while there is something to follow.
	if driver then
		driver:SetShown(trying ~= nil or live or Lingering() or HUD.IsUnlocked() or (On() and Fighting()))
	end
end
M.Look = Look

function M.Try()
	trying = GetTime()
	Look()
end

-- The driver runs (tests and the report ask).
function M.Awake() return driver ~= nil and driver:IsShown() end

-- The size it is planned at (own units): its home's width (ShyDock's) or its own, and its rows (the setting's, no
-- more than the slot has room for). The box wears it until you size it yourself (Shy.HUD.Made).
function M.Planned()
	local rows = card and card:Most() or T.db.rows
	return fitted or WIDTH, Height(rows)
end
local function Plan()
	if not box then return end
	local w, h = M.Planned()
	HUD.Made(box, w, h)
end

-- The meter's own menu: the cog's, and the first entries of the box's right-click menu.
function M.Menu(root)
	local db = T.db
	ViewMenu(root)
	root:CreateDivider()
	root:CreateTitle("Show it")
	for _, choice in ipairs(ns.WHEN) do
		root:CreateRadio(choice.text, function() return db.when == choice.value end, function()
			db.when = choice.value
			ns.Apply()
		end)
	end
	root:CreateDivider()
	local rows = root:CreateButton("Rows at first")
	for _, n in ipairs({ 4, 6, 8, 10 }) do
		rows:CreateRadio(tostring(n), function() return db.rows == n end, function()
			db.rows = n
			ns.Apply()
		end)
	end
	root:CreateCheckbox("Pets", function() return db.pets end, function()
		db.pets = not db.pets
		ns.Apply()
	end)
	root:CreateCheckbox("Follow the nameplate under the mouse", function() return db.hover end, function()
		db.hover = not db.hover
		ns.Apply()
	end)
	root:CreateCheckbox("Warn me near the pull", function() return db.warn end, function()
		db.warn = not db.warn
		ns.Apply()
	end)
	root:CreateDivider()
	root:CreateButton("Show a made-up fight", M.Try)
	root:CreateButton("Options", function() T:OpenOptions() end)
	root:CreateButton("Hide the meter", function()
		db.on = false
		ns.Apply()
		T:Print("threat meter hidden. Turn it back on in the options: /shythreat")
	end)
end

function M.Start()
	Measure()
	box = HUD.Create({
		id = "shythreat",
		title = "Threat meter",
		width = WIDTH,
		height = Height(T.db.rows),
		-- Alone (no console): standing at the bottom right, over where the damage meter usually is.
		point = { "BOTTOMRIGHT", "BOTTOMRIGHT", -24, 260 },
		shown = Shown,
		-- Sized as the damage meter is, from every corner and side: the card fills it and shows the rows that fit.
		grip = { flow = function(_, w, h) if card then card:Flow(w, h) end end, min = { MIN_W, Height(LEAST) } },
		-- ShyDock gives it the width of its slot: the damage meter's, or its role's (its planned size).
		fit = function(_, width)
			fitted = width
			Plan()
		end,
	})
	card = ns.CreateCard(box, box)
	card:Flow(box:GetWidth(), box:GetHeight())
	HUD.Manage(box, card, M.Menu)
	-- Its own controls on the layout editor's panel: shown in layout mode whatever the setting, so it can be placed
	-- and sized out of a fight, and kept up out of one from here as from the options.
	box.panel = function(panel, Put, group, width)
		local own = panel.threat
		if not own then
			own = {}
			own.out = group:Checkbox(panel, "Show out of combat", function() return T.db.when == "always" end, function(on)
				T.db.when = on and "always" or "combat"
				ns.Apply()
			end, { desc = "Keeps the meter up between fights, with the last fight's table. Off, it shows in combat only." })
			own.options = UI.Button(panel, "Threat meter options", width, function() T:OpenOptions() end)
			panel.threat = own
		end
		Put(own.out, 20)
		Put(own.options, 22)
	end

	driver = CreateFrame("Frame")
	driver:Hide()
	local wait = 0
	driver:SetScript("OnUpdate", function(_, dt)
		if card and card.trouble then card:Breathe() end
		wait = wait - dt
		if wait > 0 then return end
		wait = EVERY
		Look()
	end)
	-- Woken, and asked again at once, when what it reads changes: a fight begins or ends, a mob's threat list
	-- changes (anyone in the group pulling what you target), the mob or the group changes.
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UNIT_THREAT_LIST_UPDATE", "PLAYER_TARGET_CHANGED",
		"UPDATE_MOUSEOVER_UNIT", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "EDIT_MODE_LAYOUTS_UPDATED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event)
		-- The damage meter's rows may have changed size in Edit Mode: these follow.
		if event == "EDIT_MODE_LAYOUTS_UPDATED" then return ns.Apply() end
		wait = 0
		if On() then driver:Show() end
		Look()
	end)
	Shy:On("SHY_HUD_LAYOUT", Look)
	Shy:On("SHY_ROLE", Look)   -- a tank's or healer's layout put on or taken off
	table.insert(ns.appliers, function()
		Measure()
		Plan()
		if card then card:Flow(box:GetWidth(), box:GetHeight()) end
		Look()
	end)
	Plan()
	Look()
end

function M.Parts() return box, card end

-- The meter as a piece of a planned screen (ShyDock's Parts.lua): its width, its height at the setting's rows
-- (head and row: the height at n rows is head + n * row), at its scale; nil while it is off. Bus SHY_THREAT_PIECE
-- whenever that changes, so whoever plans the screen plans again.
function T:Piece()
	if not On() then return nil end
	local n = T.db.rows
	local head, row = TOP - GAP + FOOT, ROW + GAP
	return { id = "shythreat", width = WIDTH, height = head + n * row, scale = box and box:GetScale() or 1,
		head = head, row = row, rows = n }
end

local said
table.insert(ns.appliers, function()
	local piece = T:Piece()
	local now = piece and piece.height or false
	if said ~= nil and said ~= now then Shy:Fire("SHY_THREAT_PIECE") end
	said = now
end)
