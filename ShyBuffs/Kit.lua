-- What an icon is made of, and the housing a row of them stands in on a frame's top edge.
-- The game makes a container's buttons ten at a time, sometimes in a fight, and calls Kit.Maker's function for each.
-- Everything a button has is given to it there: afterwards it can't be touched while auras are secret.
--
-- The housing round a row on a frame's edge is the look's mini make, one piece round all of its icons (K.Shell).

local ADDON, ns = ...
local UI, Skin, Theme, Slot = Shy.UI, Shy.Skin, Shy.Theme, Shy.Slot

local K = {}
ns.Kit = K

local TIME_UNDER = 13   -- room under an icon for its time
local SOON = 30         -- seconds left when a time turns gold
K.TIME_UNDER = TIME_UNDER

local INK = { 0.925, 0.910, 0.870 }

-- A debuff's kind to its frame color, as the game wants it: keys are its dispel names, "None" for the rest.
local harm
local function Harm()
	if not harm then
		harm = {}
		for kind, c in pairs(Theme.HARM) do harm[kind] = CreateColor(c[1], c[2], c[3]) end
	end
	return harm
end

-- Gold while under SOON seconds are left, the names' ink otherwise; in the last BEAT seconds the gold beats,
-- full on each second and faint on each half.
local BEAT, FAINT = 10, 0.38
local soon
local function Soon()
	if not soon then
		local gold = UI.colors.alert
		soon = C_CurveUtil.CreateColorCurve()
		soon:SetType(Enum.LuaCurveType.Linear)
		for half = 0, BEAT * 2 - 1 do
			soon:AddPoint(half / 2, CreateColor(gold[1], gold[2], gold[3], half % 2 == 0 and 1 or FAINT))
		end
		soon:AddPoint(BEAT, CreateColor(gold[1], gold[2], gold[3], 1))
		soon:AddPoint(SOON, CreateColor(gold[1], gold[2], gold[3], 1))
		soon:AddPoint(SOON + 0.01, CreateColor(INK[1], INK[2], INK[3], 1))
		soon:AddPoint(86400, CreateColor(INK[1], INK[2], INK[3], 1))
	end
	return soon
end

local function Label(parent, size)
	return UI.Words(parent, UI.NameFont(size, "OUTLINE"), INK, { world = true, justify = "CENTER" })
end

-- What is made on an icon is colored directly, not through the theme: it reads a region's color back on a change,
-- which a button's own regions refuse in a fight.
local housed = setmetatable({}, { __mode = "k" })   -- texture -> its piece (Wear)

local function Wear(texture, piece)
	if piece == "edge" then
		-- The look's steel, as on ShyFrames' own risers (UI.PieceTone).
		local r, g, b = UI.PieceTone.edge()()
		texture:SetVertexColor(r, g, b)
	elseif piece == "bar" then
		local c = UI.colors.fill
		texture:SetVertexColor(c[1], c[2], c[3], 1)
	elseif piece == "still" then
		-- A bar for a buff that never runs out: the fill, quieter.
		local c = UI.colors.fill
		texture:SetVertexColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1)
	elseif piece == "steel" then
		local c = Skin.colors.on
		texture:SetVertexColor(c[1], c[2], c[3], 1)
	elseif piece == "pill" then
		-- A pill's plate is its own and overlaps none: it can be as see-through as the Background setting.
		local c = UI.colors.hud
		texture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
	elseif piece == "bezel" then
		-- The watch's bezel: a cooldown swiping the slot frame's band, in your color.
		Slot.Ring(texture, { color = { Theme.Accent() } })
	elseif piece == "drain" then
		local r, g, b = Theme.Accent()
		texture:SetVertexColor(r, g, b, 1)
	end
end

-- The theme changed: what is made on the icons is colored again, once the buttons may be touched.
Shy:On("SHY_THEME", function()
	ns.WhenFree("housing", function()
		for texture, piece in pairs(housed) do Wear(texture, piece) end
	end)
end)

local SOLID = "Interface\\Buttons\\WHITE8X8"
K.DRAIN = 4                          -- what a drain takes under an icon: its gap and its hair
local ARRIVE_X, ARRIVE_TIME = 10, 0.3   -- how far one arriving slides in, and how long it takes
local SWEEP_W, SWEEP_TIME, SWEEP_DELAY = 22, 0.5, 0.12   -- the light across one arriving
local GOLDEN = {}   -- the time's binding, gold when nearly out (made on first use: the theme is ready then)

-- An aura's time with no space before its unit ("40m", "8s"), so it never wraps: one unit, kept to half
-- again its range as the game keeps it (90 seconds is "90s", 90 minutes "90m").
local function Tight()
	local f = C_StringUtil.CreateNumericRuleFormatter()
	local up, down = Enum.NumericRuleFormatRounding.Up, Enum.NumericRuleFormatRounding.Down
	f:SetBreakpoints({
		{ threshold = 0, format = "%ds", components = { { step = 1, rounding = up } } },
		{ threshold = 1 + 1.5 * SECONDS_PER_MIN, format = "%dm", components = { { div = SECONDS_PER_MIN, step = 1, rounding = down } } },
		{ threshold = 1 + 1.5 * SECONDS_PER_HOUR, format = "%dh", components = { { div = SECONDS_PER_HOUR, step = 1, rounding = down } } },
		{ threshold = 1 + 1.5 * SECONDS_PER_DAY, format = "%dd", components = { { div = SECONDS_PER_DAY, step = 1, rounding = down } } },
	})
	return f
end

local function Timed(label)
	label:SetWordWrap(false)
	if not GOLDEN.textColor then
		GOLDEN.textColor = { curve = Soon(), property = Enum.DurationTextBindingProperty.RemainingDuration }
		GOLDEN.textFormatter = Tight()
	end
	return GOLDEN
end

-- A debuff's piece takes its kind's color from the game, never your color: what it is reads at a glance.
local function Kind(button, texture)
	button:AddDispelTypeTexture(texture, {
		style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
		showWithoutDispelType = true,
		customDispelColorMap = Harm(),
	})
end

-- A hair of your color running out with the time (a debuff's in its kind's); `cell`: a pill's icon, the hair
-- underlining the time beside it. `foot`: in the foot of the housing it stands in (`foot` high), in your color
-- whatever it is: on a frame's row, what is yours among everyone's.
local function Drain(button, cell, debuff, foot)
	local bar = CreateFrame("StatusBar", nil, button)
	if cell then
		bar:SetPoint("BOTTOMLEFT", cell, "BOTTOMRIGHT", K.PILL_PAD + 1, 0)
		bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -(K.PILL_PAD + 1), K.PILL_PAD)
	elseif foot then
		bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, -foot)
		bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, -foot)
		debuff = false
	else
		bar:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
		bar:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
	end
	bar:SetHeight(foot or 2)
	bar:SetStatusBarTexture(SOLID)
	bar:SetReverseFill(not foot)   -- the shelf's runs out away from the minimap, a row's toward its start
	local trough = bar:CreateTexture(nil, "BACKGROUND")
	trough:SetAllPoints()
	trough:SetColorTexture(0, 0, 0, 0.55)
	local fill = bar:GetStatusBarTexture()
	if debuff then
		Kind(button, fill)
	else
		housed[fill] = "drain"
		Wear(fill, "drain")
	end
	bar:SetMinMaxValues(0, 1)
	button:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection.RemainingTime, interpolation = Enum.StatusBarInterpolation.Immediate })
end

K.PILL_PAD = 2   -- round the icon inside a pill

-- A pill's plate: its own, the family's beveled edge round a fill at the Background setting; a debuff's edge
-- in its kind's color, a coating's in your color. The icon in it stands bare: the pill's is its one edge.
-- On a frame of its own under the icon: the game draws no texture made on its button itself.
local function Pill(button, debuff, steel)
	local plate = CreateFrame("Frame", nil, button)
	plate:SetAllPoints()
	plate:SetFrameLevel(button:GetFrameLevel())
	local fill = plate:CreateTexture(nil, "BACKGROUND")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", -1, 1)
	fill:SetTexture(SOLID)
	housed[fill] = "pill"
	Wear(fill, "pill")
	local edge = plate:CreateTexture(nil, "BORDER")
	edge:SetAllPoints()
	edge:SetTexture(Skin.FRAME)
	edge:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
	if debuff then
		Kind(button, edge)
	else
		local piece = steel and "steel" or "edge"
		housed[edge] = piece
		Wear(edge, piece)
	end
end

-- Every arrival made, so they can be hushed (below): { from, back, fade, sheen }.
local arrivals = {}

-- One that comes in slides from the minimap's side as it shows, and a light crosses its icon. The game plays
-- both when the aura is first shown; they must belong to a child of the button, and may move the button.
local function Arrive(button, cell)
	local motion = CreateFrame("Frame", nil, button)
	local slide = motion:CreateAnimationGroup()
	local from = slide:CreateAnimation("Translation")
	from:SetTarget(button)
	from:SetOffset(ARRIVE_X, 0)
	from:SetDuration(0)
	from:SetOrder(1)
	local back = slide:CreateAnimation("Translation")
	back:SetTarget(button)
	back:SetOffset(-ARRIVE_X, 0)
	back:SetDuration(ARRIVE_TIME)
	back:SetSmoothing("OUT")
	back:SetOrder(2)
	local fade = slide:CreateAnimation("Alpha")
	fade:SetTarget(button)
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(ARRIVE_TIME)
	fade:SetOrder(2)
	button:AddAuraShownAnimation(slide)
	local clip = CreateFrame("Frame", nil, button)
	clip:SetAllPoints(cell)
	clip:SetClipsChildren(true)
	local sheen = clip:CreateTexture(nil, "OVERLAY")
	sheen:SetTexture(Shy.Brand.SHEEN)
	sheen:SetBlendMode("ADD")
	sheen:SetAlpha(0.8)
	sheen:SetPoint("TOPRIGHT", clip, "TOPLEFT")
	sheen:SetPoint("BOTTOMRIGHT", clip, "BOTTOMLEFT")
	sheen:SetWidth(SWEEP_W)
	local sweep = sheen:CreateAnimationGroup()
	local cross = sweep:CreateAnimation("Translation")
	cross:SetOffset(cell:GetWidth() + SWEEP_W, 0)
	cross:SetDuration(SWEEP_TIME)
	cross:SetStartDelay(SWEEP_DELAY)
	cross:SetSmoothing("OUT")
	button:AddAuraShownAnimation(sweep)
	arrivals[#arrivals + 1] = { from = from, back = back, fade = fade, sheen = sheen }
end

-- The game shows every icon again when it rebuilds a container: on UNIT_FLAGS and UNIT_FACTION of yours (it
-- watches those for any group filtered by spell, as the shelf's never-ending buffs are), and when a group's
-- filters change. It hides each icon and shows it again, which plays its arrival as though the aura had just come:
-- every buff slid in again on leaving a fight or looting. Around those rebuilds the arrivals are hushed (they play
-- with nothing moving and no light) and given back a moment later, so only an aura that comes slides in.
-- They are our own animations, told only while auras can be read.
local HUSH = 0.6
local hushed, hushes = false, 0
local function Voice(on)
	for _, a in ipairs(arrivals) do
		pcall(a.from.SetOffset, a.from, on and ARRIVE_X or 0, 0)
		pcall(a.back.SetOffset, a.back, on and -ARRIVE_X or 0, 0)
		pcall(a.fade.SetFromAlpha, a.fade, on and 0 or 1)
		pcall(a.sheen.SetAlpha, a.sheen, on and 0.8 or 0)
	end
end
local function Unhush()
	if not hushed then return end
	if not ns.Free() then
		ns.WhenFree("arrivals", Unhush)
		return
	end
	hushed = false
	Voice(true)
end
function K.Hush()
	if not ns.Free() then return false end
	if not hushed then
		hushed = true
		Voice(false)
	end
	hushes = hushes + 1
	local mine = hushes
	C_Timer.After(HUSH, function()
		if mine == hushes then Unhush() end
	end)
	return true
end
function K.Hushed() return hushed end

-- The rebuilds the game makes on its own. At a fight's end the flags may change while auras are still kept from
-- us: the end of the fight hushes too, before the container's next frame redraws.
local rebuilds = CreateFrame("Frame")
rebuilds:RegisterUnitEvent("UNIT_FLAGS", "player")
rebuilds:RegisterUnitEvent("UNIT_FACTION", "player")
rebuilds:RegisterEvent("PLAYER_REGEN_ENABLED")
rebuilds:SetScript("OnEvent", function() K.Hush() end)

-- A button is the game's: it runs no script of ours and its own tooltip takes no lines (see K.Tip).
--
-- spec:
--   size      the icon, square
--   time      "in" (over the icon's foot), "foot" (in the icon's foot on a fade), "under" (below it),
--             "beside" (a pill's, right of its icon) or nil; all but "in" gold when nearly out, beating at the last
--   drain     a hair of your color under the icon running out with the time (the time, if under, under it)
--   pill      a pill this wide: a plate of its own, the icon at its left, its foot draining
--   watch     the frame a bezel: its band lit in your color for the time left, running out round the icon
--   plain     no shade over the icon at all
--   arrive    one that comes slides in from the minimap's side with a light across it
--   harm      a debuff: its frame takes its kind's color
--   cancel    a right click removes it (your own buffs)
--   steel     a frame color of its own (a weapon's coating: your color)
--   mine      yours among everyone's: a hair of your color under it (`foot` high), running out with the time
--   through   a mark inside a frame you click (a cell of the healing grid): it takes no mouse, so every click
--             lands on the frame under it, and it has no tooltip
function K.Maker(spec)
	local size = spec.size
	return function(button)
		local pad = spec.pill and K.PILL_PAD or 0
		button:SetSize(spec.pill or size, size + 2 * pad)
		if spec.pill then Pill(button, spec.harm, spec.steel) end
		local cell = button
		if spec.pill then
			cell = CreateFrame("Frame", nil, button)
			cell:SetSize(size, size)
			cell:SetPoint("LEFT", button, "LEFT", pad, 0)
			cell:SetFrameLevel(button:GetFrameLevel() + 1)
		end
		local icon = cell:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- crops the icon's built-in border
		local slot = Slot.New(button, { to = spec.pill and cell or nil, icon = icon, size = size, color = spec.steel })
		if spec.pill then slot:Bare(true) end   -- one edge to a pill: its own
		local cooldown
		if not spec.plain then
			cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
			cooldown:SetAllPoints(icon)
			cooldown:SetDrawBling(false)
			cooldown:SetDrawEdge(false)
			cooldown:SetHideCountdownNumbers(true)   -- the time is our own text
			if spec.watch then
				-- The frame itself runs out round the icon: its band lit for the time left, nothing over the
				-- picture. A debuff's in ink: its frame wears its kind already, and a swipe can't take it.
				cooldown:SetReverse(false)
				if spec.harm then
					Slot.Ring(cooldown, { color = { INK[1], INK[2], INK[3], 0.9 }, size = size })
				else
					housed[cooldown] = "bezel"
					Slot.Ring(cooldown, { color = { Theme.Accent() }, size = size })   -- a new color keeps the size
				end
			else
				cooldown:SetReverse(true)                -- the shade grows as time runs out
				Slot.Swipe(cooldown, { size = size })
			end
		end
		local over = CreateFrame("Frame", nil, button)
		over:SetAllPoints()
		over:SetFrameLevel((cooldown or cell):GetFrameLevel() + 1)

		button:SetIcon(icon)
		if cooldown then button:SetDurationCooldown(cooldown) end
		if spec.drain or (spec.pill and spec.time) then Drain(button, spec.pill and cell, spec.harm) end
		if spec.mine then Drain(button, nil, spec.harm, spec.foot or 2) end
		if spec.time == "under" then
			local time = Label(over, 11)
			time:SetPoint("TOP", button, "BOTTOM", 0, spec.drain and -(K.DRAIN + 2) or -2)
			button:SetDurationText(time, Timed(time))
		elseif spec.time == "beside" then
			-- Centred on the room beside the icon, by one point: a time is never cut short.
			local time = Label(over, 12)
			time:SetPoint("CENTER", button, "RIGHT", -(spec.pill - size - pad) / 2, 1)
			button:SetDurationText(time, Timed(time))
		elseif spec.time == "foot" then
			local fade = over:CreateTexture(nil, "BACKGROUND")
			fade:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
			fade:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
			fade:SetHeight(size * 0.52)
			fade:SetColorTexture(1, 1, 1)
			fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0))
			local time = Label(over, math.max(9, math.floor(size * 0.36 + 0.5)))
			time:SetPoint("BOTTOM", icon, "BOTTOM", 0, 1)
			button:SetDurationText(time, Timed(time))
		elseif spec.time == "in" then
			local time = Label(over, math.max(9, math.floor(size * 0.42 + 0.5)))
			time:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
			button:SetDurationText(time)
		end
		local count = Label(over, Slot.CountSize(size))
		count:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 1, 1)
		button:SetApplicationCount(count)
		if spec.arrive then Arrive(button, cell) end

		-- A debuff's icon framed in its kind's color; a pill's edge is that already.
		if spec.harm and not spec.pill then
			local mark = over:CreateTexture(nil, "ARTWORK")
			Slot.Follow(mark, "mark", cell, 0, 0, size)
			Kind(button, mark)
		end
		if spec.cancel then button:SetCancelAuraButtons("RightButtonUp") end
		if spec.through then
			-- (Asked for, not relied on: where the game refuses, the mark keeps its own tooltip and its few units
			-- of the frame.)
			pcall(button.EnableMouse, button, false)
		else
			K.Tip(button, "ANCHOR_BOTTOMLEFT")
		end
	end
end

-- A debuff's piece in its kind's color, for what a recipe adds to a button of its own.
K.Kind = Kind

-- An icon's own tooltip is the game's forbidden one: it takes no lines and is no hover of ours. Out of a fight
-- Caster.lua works out which icon the mouse is on and shows the game's ordinary tooltip for it, so the icon's
-- own is given no place (an unanchored tooltip never draws). In a fight it has its place back (K.Tips).
local tips = {}        -- button -> where its own tooltip stands when it has a place
local owning = false   -- ours is the tooltip: the icons' own have no place

function K.Tip(button, anchor)
	tips[button] = anchor
	button:SetTooltipAnchorPoint(owning and "ANCHOR_NONE" or anchor)
end

-- Takes the icons' own tooltip away (true) or gives it back (false). Returns how many icons refused.
function K.Tips(own)
	owning = own and true or false
	local refused = 0
	for button, anchor in pairs(tips) do
		if not pcall(button.SetTooltipAnchorPoint, button, owning and "ANCHOR_NONE" or anchor) then refused = refused + 1 end
	end
	return refused
end

function K.Owning()
	return owning
end

local hits = setmetatable({}, { __mode = "k" })   -- a group's options -> { width, height } of the part the mouse can be on

-- A group's options for AddAuraGroup. spec is Kit.Maker's, and:
--   most      how many icons at most (any number when nil)
--   filters   candidate filters
--   sort      an AuraContainerSortMethod
--   gap       between two icons, and to the group before it
--   after     between this group and the one before it instead (0: one pitch through both)
--   line      to the row before it; newLine starts a row of its own
function K.Group(spec)
	local tall = spec.size + (spec.drain and K.DRAIN or 0) + (spec.time == "under" and TIME_UNDER or 0)
		+ (spec.pill and 2 * K.PILL_PAD or 0)
	local wide = spec.pill or spec.size
	local options = {
		maxFrameCount = spec.most,
		initializeFrame = K.Maker(spec),
		candidateFilters = spec.filters,
		sortMethod = spec.sort or AuraContainerSortMethod.Default,
		layout = {
			elementSpacing = spec.gap, groupSpacing = spec.after or spec.gap,
			lineSpacing = spec.line or spec.gap, groupLineSpacing = spec.line or spec.gap,
			forceNewLine = spec.newLine and true or false,
			elementWidth = wide, elementHeight = tall,
		},
	}
	hits[options] = { wide, spec.size + (spec.pill and 2 * K.PILL_PAD or 0) }
	return options
end

-- A bar: the icon at the left end, the name along the bar, the time at the right end, the bar itself running
-- down as the time does. The game fills every one of them; who cast it is the tooltip's to say.
--
-- spec:
--   width     the bar's width; height (default K.BAR) its height and the icon's size
--   time      true: the bar and a time run down; otherwise the bar stands full (a buff that never runs out)
--   cancel    a right click removes it
--   steel     a frame and fill color of its own (a weapon's coating: your color)
--   harm      a debuff: its bar filled and its icon framed in its kind's color, never your color
--   arrive    one that comes slides in from the minimap's side with a light across its icon
K.BAR = 18
local TROUGH = { 0.05, 0.05, 0.055, 0.9 }

function K.BarMaker(spec)
	local height = spec.height or K.BAR
	return function(button)
		button:SetSize(spec.width, height)
		-- The icon, in a slot of its own at the left end.
		local cell = CreateFrame("Frame", nil, button)
		cell:SetSize(height, height)
		cell:SetPoint("LEFT", button, "LEFT", 0, 0)
		local icon = cell:CreateTexture(nil, "ARTWORK")
		icon:SetAllPoints()
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		Slot.New(button, { to = cell, icon = icon, size = height, color = spec.steel })
		button:SetIcon(icon)
		-- The bar, from the icon to the right end.
		local bar = CreateFrame("StatusBar", nil, button)
		bar:SetPoint("TOPLEFT", cell, "TOPRIGHT", 3, -1)
		bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
		Skin.HatchBar(bar)
		local fill = bar:GetStatusBarTexture()
		local trough = bar:CreateTexture(nil, "BACKGROUND")
		trough:SetAllPoints()
		Skin.Hatch(trough)
		trough:SetVertexColor(TROUGH[1], TROUGH[2], TROUGH[3], TROUGH[4])
		if spec.harm then
			-- A debuff runs down in its kind's color, so it never reads as one of your buffs.
			button:AddDispelTypeTexture(fill, {
				style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
				showWithoutDispelType = true,
				customDispelColorMap = Harm(),
			})
		else
			local piece = (spec.steel and "steel") or (spec.time and "bar") or "still"
			housed[fill] = piece
			Wear(fill, piece)
		end
		bar:SetMinMaxValues(0, 1)
		if spec.time then
			button:SetDurationBar(bar, { direction = Enum.StatusBarTimerDirection.RemainingTime, interpolation = Enum.StatusBarInterpolation.Immediate })
		else
			bar:SetValue(1)
		end
		local over = CreateFrame("Frame", nil, button)
		over:SetAllPoints()
		over:SetFrameLevel(bar:GetFrameLevel() + 1)
		local time
		if spec.time then
			time = Label(over, 11)
			time:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
			button:SetDurationText(time, Timed(time))
		end
		-- The name takes the bar up to the time.
		local name = Label(over, 11)
		name:SetJustifyH("LEFT")
		name:SetWordWrap(false)
		name:SetPoint("LEFT", bar, "LEFT", 4, 0)
		if time then name:SetPoint("RIGHT", time, "LEFT", -4, 0) else name:SetPoint("RIGHT", bar, "RIGHT", -4, 0) end
		button:SetSpellName(name)
		local count = Label(over, Slot.CountSize(height))
		count:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 1, -1)
		button:SetApplicationCount(count)
		if spec.harm then
			-- A debuff's bar: its icon framed in its kind's color, as an icon of the row is.
			local mark = over:CreateTexture(nil, "ARTWORK")
			Slot.Follow(mark, "mark", cell, 0, 0, height)
			button:AddDispelTypeTexture(mark, {
				style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
				showWithoutDispelType = true,
				customDispelColorMap = Harm(),
			})
		end
		if spec.arrive then Arrive(button, cell) end
		if spec.cancel then button:SetCancelAuraButtons("RightButtonUp") end
		K.Tip(button, "ANCHOR_LEFT")
	end
end

-- A group of bars for AddAuraGroup, one to a line. spec is Kit.BarMaker's, and most, filters, sort, gap, line,
-- newLine as Kit.Group's.
function K.BarGroup(spec)
	local options = {
		maxFrameCount = spec.most,
		initializeFrame = K.BarMaker(spec),
		candidateFilters = spec.filters,
		sortMethod = spec.sort or AuraContainerSortMethod.Default,
		layout = {
			elementSpacing = spec.gap, groupSpacing = spec.gap,
			lineSpacing = spec.gap, groupLineSpacing = spec.line or spec.gap,
			forceNewLine = spec.newLine and true or false,
			elementWidth = spec.width, elementHeight = spec.height or K.BAR,
		},
	}
	hits[options] = { spec.width, spec.height or K.BAR }
	return options
end

-- What each container was told. The game tells nobody where an icon stands or which aura it shows, but it
-- places them by rules that can be followed (Caster.lua), given what is kept here:
--   plan = { parent, flow, at = { frame, corner, x, y }, scale, unit, on,
--            groups = { { key, filter, options, filters, hit, on }, ... },
--            coating = { order = { slot, ... }, on = { [slot] = bool }, hit, layout } }
local plans = {}

function K.Plans()
	return plans
end

-- A container on `parent`, not yet watching anyone.
-- flow: { point (where the first icon stands), across, up ("Left" | "Right", "Up" | "Down"), line (a row's width) }
function K.Container(parent, flow)
	local c = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	c:SetFlowLayoutAnchorPoint(flow.point)
	c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection[flow.across], AnchorUtil.FlowDirection[flow.up])
	if flow.line then c:SetFlowLayoutMaximumLineSize(flow.line) end
	c:SetEnabled(false)
	c:Hide()
	plans[c] = { parent = parent, flow = flow, scale = 1, groups = {}, coating = { order = {}, on = {} } }
	return c
end

-- The container's first icon stands at `corner` of `frame`, moved by x, y. The point is its flow's.
function K.Place(c, frame, corner, x, y)
	c:SetPoint(plans[c].flow.point, frame, corner, x or 0, y or 0)
	plans[c].at = { frame = frame, corner = corner, x = x or 0, y = y or 0 }
end

-- A row's longest line, told again (its frame's width changed, or what stands at its end).
function K.Line(c, line)
	local flow = plans[c].flow
	if flow.line == line then return end
	c:SetFlowLayoutMaximumLineSize(line)
	flow.line = line
end

function K.Scale(c, scale)
	if plans[c].scale == scale and plans[c].scaled then return end
	c:SetScale(scale)
	plans[c].scale, plans[c].scaled = scale, true
end

local function GroupOf(c, key)
	for _, group in ipairs(plans[c].groups) do
		if group.key == key then return group end
	end
end

-- `options`: Kit.Group's or Kit.BarGroup's.
function K.AddGroup(c, key, filter, options)
	c:AddAuraGroup(key, filter, options)
	table.insert(plans[c].groups, { key = key, filter = filter, options = options, filters = options.candidateFilters,
		hit = hits[options], on = true })
end

function K.Filters(c, key, filters)
	K.Hush()   -- new filters rebuild the container: what shows stays as it is
	c:SetAuraGroupCandidateFilters(key, filters)
	GroupOf(c, key).filters = filters
end

-- How many icons a group shows at most, told again. The game hands its icons out afresh: hushed, as for filters.
function K.Most(c, key, most)
	local group = GroupOf(c, key)
	if group.options.maxFrameCount == most then return end
	K.Hush()
	c:SetAuraGroupMaxFrameCount(key, most)
	group.options.maxFrameCount = most
end

-- A slot: one aura in one place of its own (the first the filter and `filters` let through), where a group is a
-- row of them. The game makes its button at once and hands it to `make` (a Kit.Maker's function, or one that
-- calls it and places the button: a slot's button stands where it is put, the container lays out none of them).
-- Returns the button.
function K.AddSlot(c, key, filter, make, filters)
	local button = c:AddAuraSlot(key, filter, { initializeFrame = make, candidateFilters = filters })
	local plan = plans[c]
	plan.slots = plan.slots or {}
	plan.slots[key] = { filter = filter, filters = filters, button = button }
	return button
end

-- The game rebuilds the whole container on every SetAuraGroupEnabled and SetItemEnchantmentEnabled, changed or
-- not, showing every icon again: told only when it changes.
function K.Enable(c, key, on)
	local group = GroupOf(c, key)
	if group.on == on then return end
	c:SetAuraGroupEnabled(key, on)
	group.on = on
end

-- A weapon's coating. `maker`: Kit.Maker's or Kit.BarMaker's function; `hit`: { width, height } of its button.
function K.AddCoating(c, slot, maker, hit)
	c:AddItemEnchantment(slot, { initializeFrame = maker })
	local coating = plans[c].coating
	table.insert(coating.order, slot)
	coating.on[slot], coating.hit = true, hit
end

function K.CoatingLayout(c, layout)
	c:SetItemEnchantmentLayout(layout)
	plans[c].coating.layout = layout
end

function K.EnableCoating(c, slot, on)
	local coating = plans[c].coating
	if coating.on[slot] == on then return end
	c:SetItemEnchantmentEnabled(slot, on)
	coating.on[slot] = on
end

-- Starts or stops a container watching `unit`.
function K.Watch(c, unit, on)
	plans[c].unit, plans[c].on = unit, on and true or false
	if on then
		c:SetUnit(unit)
		c:SetEnabled(true)
		c:Show()
	else
		c:SetEnabled(false)
		c:Hide()
	end
	local shell = plans[c].shell
	if shell then shell.holder:SetShown(on and true or false) end
end

-- The housing round a row of icons on a frame's edge: the look's mini make (UI.Panel's `mini`), one piece round
-- all of them, standing on the frame's top edge, with its own line on every side: the icons
-- stand the same room in from each, whatever the frame's look draws along its edge.
--
-- The game sizes a container to its icons and keeps that size from us in a fight, and a housing must know its own
-- (the look fits its art to it, and our code may compare no size it can't read). So there is a housing for each
-- shape the row can take (k icons in one row, or a full row and j rows: a row fills before the next starts), each
-- of a size we know, anchored to the frame; and the game picks the one that fits. Two bars of ours are told the
-- container's width and height (values the game may keep secret, which a bar takes), and every housing stands in
-- two windows, one riding each bar's fill end, placed to be over that housing only at its width and its height:
-- an icon more moves a fill end further than any housing is wide. Nothing of ours compares a size. An empty
-- container is one unit square, so no window is over anything then. The windows' foot is the housing's: what the
-- look's line reaches past it (a gradient, a shadow) is cut there, never laid over the frame under it.
-- The housing has the same room on every side of the icons (K.ShellRoom): the icons stand that far over its foot,
-- so the shell places its container too (K.Place), and again when the look changes.
--   o: edge (the frame whose top edge the icons stand on), side ("LEFT" or "RIGHT": the corner they start from),
--      inset (from that corner to the first icon), lift (what stands between the edge and the housing: combo
--      points), size, gap
local SHELL_BAR = 30   -- the bars and windows stand this far down inside the frame
local SHELL_TALL = 600 -- a window's height, up from the housing's foot: over the housing wherever it is
local shells = {}

local function ShellBar(s)
	local bar = CreateFrame("StatusBar", nil, s.holder)
	bar:SetStatusBarTexture(SOLID)
	bar:GetStatusBarTexture():SetAlpha(0)
	bar:SetHeight(1)
	bar:SetPoint("LEFT", s.o.edge, "TOPLEFT", 0, -SHELL_BAR)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar:SetFrameLevel(s.level)
	return bar
end

function K.Shell(c, o)
	-- Over the frame and its rim, under the icons (the container stands higher still).
	local s = { c = c, o = o, shapes = {}, level = o.edge:GetFrameLevel() + 3 }
	s.holder = CreateFrame("Frame", nil, o.edge)
	s.holder:SetFrameLevel(s.level)
	s.holder:SetPoint("TOPLEFT", o.edge, "TOPLEFT")
	s.holder:SetSize(1, 1)
	s.holder:Hide()
	s.wide, s.tall = ShellBar(s), ShellBar(s)
	s.holder:SetScript("OnUpdate", function()
		s.wide:SetValue(c:GetWidth())
		s.tall:SetValue(c:GetHeight())
	end)
	plans[c].shell = s
	shells[#shells + 1] = s
	return s
end

-- One shape's housing and its two windows, made once.
local function Shape(s, i)
	local shape = s.shapes[i]
	if shape then return shape end
	local tall = CreateFrame("Frame", nil, s.holder)
	tall:SetClipsChildren(true)
	local wide = CreateFrame("Frame", nil, tall)
	wide:SetClipsChildren(true)
	local housing = CreateFrame("Frame", nil, wide)
	housing:SetSize(1, 1)
	UI.Panel(housing, { hud = true, mini = true, brackets = false, line = false })
	for _, f in ipairs({ tall, wide, housing }) do f:SetFrameLevel(s.level) end
	shape = { tall = tall, wide = wide, housing = housing }
	s.shapes[i] = shape
	return shape
end

-- The room round a housing's icons: the border hugs them, as far from each as they are from one another, so a row
-- and its housing read as one grid and no dark band of the housing's fill stands round them.
-- The icons stand over the look's line where it reaches inside the housing's edge (they are a level higher), so a
-- deep border never covers a picture.
K.SHELL_ROOM = 2
function K.ShellRoom()
	return K.SHELL_ROOM
end

-- Lays the housings out for a row of `cols` icons at most, in `rows` rows, and stands the container where its
-- icons go. Again on a change of look (its border); only while auras can be read (the container is told).
function K.FitShell(s, cols, rows)
	s.cols, s.rows = cols, rows
	local o = s.o
	local pitch = o.size + o.gap
	local shapes = {}
	for k = 1, cols do shapes[#shapes + 1] = { k, 1 } end
	for j = 2, rows do shapes[#shapes + 1] = { cols, j } end
	local around = K.ShellRoom()
	local lift = o.lift or 0
	local drop = lift + around
	local right = o.side == "RIGHT"
	K.Place(s.c, o.edge, right and "TOPRIGHT" or "TOPLEFT", right and -o.inset or o.inset, drop)
	local widest = cols * pitch - o.gap + 2 * around + 6
	-- Each bar's reach: an icon less (or the empty unit square) moves its fill end past the widest window.
	local reachW, reachH = cols * pitch, rows * pitch
	local barW = math.ceil(widest * reachW / (o.size - 1))
	local barH = math.ceil(widest * reachH / (o.size - 1))
	s.wide:SetWidth(barW)
	s.wide:SetMinMaxValues(0, reachW)
	s.tall:SetWidth(barH)
	s.tall:SetMinMaxValues(0, reachH)
	local edgeW = o.edge:GetWidth()
	for i, at in ipairs(shapes) do
		local shape = Shape(s, i)
		local w, h = at[1] * pitch - o.gap, at[2] * pitch - o.gap
		local hw, hh = w + 2 * around, around + h + around
		local left = o.side == "RIGHT" and edgeW - o.inset - w - around or o.inset - around
		local housing = shape.housing
		housing:ClearAllPoints()
		housing:SetPoint("BOTTOMLEFT", o.edge, "TOPLEFT", left, lift)
		housing:SetSize(hw, hh)
		-- The windows: over the housing (and 3 to either side) when the fill ends stand at its width and its height,
		-- rising from its foot: nothing of it is drawn over the frame (or the combo points) it stands on.
		for _, pair in ipairs({ { shape.wide, s.wide, w, reachW, barW }, { shape.tall, s.tall, h, reachH, barH } }) do
			local window, bar, value, reach, long = pair[1], pair[2], pair[3], pair[4], pair[5]
			window:ClearAllPoints()
			window:SetSize(hw + 6, SHELL_TALL)
			window:SetPoint("BOTTOMLEFT", bar:GetStatusBarTexture(), "RIGHT", left - 3 - long * value / reach, SHELL_BAR + lift)
		end
		shape.tall:Show()
	end
	for i = #shapes + 1, #s.shapes do s.shapes[i].tall:Hide() end
end

-- A new look: new borders, so new room round the icons.
Shy:On("SHY_THEME", function()
	ns.WhenFree("shells", function()
		for _, s in ipairs(shells) do
			if s.cols then K.FitShell(s, s.cols, s.rows) end
		end
	end)
end)

-- Buffs learned by spell while auras can be read: the ones that never run out. The game has no filter for
-- them, but it filters by spell.

local Learn = {}
ns.Learn = Learn

Learn.SHORT = 60   -- a buff lasting no longer stands on your frame too, where you watch in a fight

local function Read()
	if not ns.Free() then return end
	local known = ns.T.db.known
	local changed = false
	for i = 1, 255 do
		local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not aura then break end
		local id, duration = aura.spellId, aura.duration
		if not issecretvalue(id) and not issecretvalue(duration) and id and duration == 0 and not known.forever[id] then
			known.forever[id] = true
			changed = true
		end
	end
	if changed then Shy:Fire("SHY_BUFFS_KNOWN") end
end

function Learn.Start()
	local pending
	local function Due()
		pending = nil
		Read()
	end
	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:SetScript("OnEvent", function()
		if pending then return end
		pending = true
		C_Timer.After(0.2, Due)
	end)
	Read()
end
