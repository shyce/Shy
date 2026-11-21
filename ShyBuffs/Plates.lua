-- Buffs and debuffs on ShyFrames' unit frames, standing on each one's top edge in a housing of the look's mini
-- make (Kit.Shell).
--
--   you         your debuffs, then your short buffs (a heal over time, a shield): what a fight puts on you
--   target      as the game orders them: its buffs (half a row at most), then every debuff on it, yours first (a hair of your
--               color under each), everyone's with its time: a raid boss's whole set, so a raid leader sees what is up
--               and a warlock whose curse is on
--   party       debuffs on the cell, then its buffs, up to the reminders at the cell's other end
--
-- Each frame's row grows from its portrait's end (ShyFrames' T:IconStart): yours from the left, your target's from
-- the right, so the pair mirrors. Past a round portrait it starts after the circle, on the housing's top edge.
--
-- A plate's icons stand in two rows at most, a party cell's in one: the room ShyFrames makes over each (T:Riser),
-- with the party's row, the target's target or the cooldown manager above it. One pitch for every icon. Each group's
-- cap is what its rows hold after the groups before it (`caps`), so nothing ever passes the room: the order of the
-- groups says what goes first, and your own auras come first within each (the game's order).
-- Each row is one container, a child of its secure button: it shows, hides, scales and fades with it.

local ADDON, ns = ...
local T, K, Learn = ns.T, ns.Kit, ns.Learn

local P = {}
ns.Plates = P

local GAP = 2
local MINE = 5             -- your own debuffs on your target at most
local SHORT = 5            -- your short buffs on your frame at most
local HARM_CELL = 3        -- a party member's debuffs at most
local LEVEL = 8            -- a container over its frame's own art, marks and words (seven over the frame)

local rows = {}            -- unit -> { button, room, list = { { c, shell, rows, line(), caps(cols) }, ... } }
local bands = {}           -- unit -> a frame of ours over the rows' place: a container's size is kept from us
local room = {}            -- unit -> what stands at the row's far end (the reminders' tray), its width
local frames               -- ShyFrames

-- How many icons a line `line` long holds.
local function Fit(line, size)
	return math.max(1, math.floor((line + GAP) / (size + GAP)))
end

-- A row's line for `cols` icons, exactly: the next one wraps.
local function Long(cols, size)
	return cols * (size + GAP) - GAP
end

-- The room a frame's icons have over it.
local function Room(r, lift, lines)
	return lift + r.foot + lines * r.size + (lines - 1) * GAP + r.pad
end

-- A container on `button`, flowing from its `side` top corner (its housing places it: K.FitShell).
local function Stand(button, side, line)
	local right = side == "RIGHT"
	local c = K.Container(button, { point = right and "BOTTOMRIGHT" or "BOTTOMLEFT", across = right and "Left" or "Right", up = "Up", line = line })
	c:SetFrameLevel(button:GetFrameLevel() + LEVEL)
	return c
end

-- A group of a row, at one pitch with the group before it; on to the next row inside the room (its cap keeps it).
local function Group(r, spec)
	spec.size, spec.gap, spec.after, spec.line = r.size, GAP, 0, GAP
	return K.Group(spec)
end

-- Where a frame's row starts: the side it grows from, how far in, and how far down the frame's housing stands
-- (ShyFrames' T:IconStart; the left, the plate's own ends and no drop where it can't tell).
local function Start(kind, r)
	local side, past, drop = "LEFT", 0, 0
	if frames.IconStart then side, past, drop = frames:IconStart(kind) end
	return side, past > 0 and past + GAP or r.ends, drop
end

-- A row: its container, its housing, how many rows it may take, its line's room (`line()`, from where it starts),
-- and each group's cap for so many icons a row (`caps(cols)`). It stands `lift` over the housing's top.
local function Row(button, r, kind, lift, lines, line, caps)
	local side, inset, drop = Start(kind, r)
	local row = { rows = lines, line = line, caps = caps, side = side, inset = inset, rise = lift, lift = lift - drop,
		kind = kind }
	row.cols = Fit(line(row), r.size)
	row.c = Stand(button, side, Long(row.cols, r.size))
	return row
end

local function House(button, r, row)
	row.shell = K.Shell(row.c, { edge = button, side = row.side, inset = row.inset, lift = row.lift, size = r.size, gap = GAP })
	K.FitShell(row.shell, row.cols, row.rows)
end

local BUILD = {}

-- Your debuffs a row, your short buffs after them.
function BUILD.player(unit, button, r)
	local row = Row(button, r, "player", 0, r.lines, function(row) return button:GetWidth() - row.inset - r.ends end, function(cols)
		return { harm = cols, short = math.min(SHORT, (r.lines - 1) * cols) }
	end)
	local most = row.caps(row.cols)
	K.AddGroup(row.c, "harm", "HARMFUL", Group(r, { most = most.harm, time = "in", harm = true }))
	K.AddGroup(row.c, "short", "HELPFUL", Group(r, {
		most = most.short, time = "in", cancel = true,
		filters = { maxDuration = Learn.SHORT }, sort = AuraContainerSortMethod.ExpirationOnly,
	}))
	House(button, r, row)
	return { room = Room(r, 0, r.lines), list = { row } }
end

-- As the game orders them: its buffs, half a row at most, then every debuff, yours first, through the rest.
function BUILD.target(unit, button, r)
	-- Combo points have the edge itself on a rogue's or a druid's target: the rows stand on their housing.
	local lift = r.stacked and r.combo or 0
	local row = Row(button, r, "target", lift, r.lines, function(row) return button:GetWidth() - row.inset - r.ends end,
		function(cols)
			-- (Half a row of buffs at most: the rest of the room is the debuffs'.)
			local buffs = math.floor(cols / 2)
			local mine = math.min(MINE, cols)
			return { buffs = buffs, mine = mine, theirs = r.lines * cols - buffs - mine }
		end)
	local most = row.caps(row.cols)
	K.AddGroup(row.c, "buffs", "HELPFUL", Group(r, { most = most.buffs }))
	K.AddGroup(row.c, "mine", "HARMFUL|PLAYER", Group(r, { most = most.mine, time = "in", harm = true, mine = true }))
	K.AddGroup(row.c, "theirs", "HARMFUL|!PLAYER", Group(r, { most = most.theirs, time = "in", harm = true }))
	House(button, r, row)
	return { room = Room(r, lift, r.lines), list = { row } }
end

-- Debuffs, then buffs, in one row up to the reminders at the cell's other end.
function BUILD.party(unit, button, r)
	local row = Row(button, r, "party", 0, 1, function(row)
		local far = room[unit] or 0
		return button:GetWidth() - row.inset - r.ends - (far > 0 and far + GAP or 0)
	end, function(cols)
		local harm = math.min(HARM_CELL, cols)
		return { harm = harm, buffs = cols - harm }
	end)
	local most = row.caps(row.cols)
	K.AddGroup(row.c, "harm", "HARMFUL", Group(r, { most = most.harm, time = "in", harm = true }))
	K.AddGroup(row.c, "buffs", "HELPFUL", Group(r, { most = most.buffs }))
	House(button, r, row)
	return { room = Room(r, 0, 1), list = { row } }
end

local function Build()
	local r = frames:Riser()
	frames:EachFrame(function(_, kind, unit, button)
		local build = BUILD[kind]
		if build and not rows[unit] then
			local made = build(unit, button, r)
			made.button, made.kind = button, kind
			rows[unit] = made
				local band = CreateFrame("Frame", nil, button)
			band:SetHeight(made.room)
			bands[unit] = band
			P.Band(unit, made.list[1].lift - made.list[1].rise)
		end
	end)
end

-- Each row fitted to its frame as it stands now: where it starts, its line, its caps, its housings.
local function Refit()
	if not next(rows) then return end
	local r = frames:Riser()
	for unit, made in pairs(rows) do
		local _, inset, drop = Start(made.kind, r)
		for _, row in ipairs(made.list) do
			local moved = inset ~= row.inset or row.rise - drop ~= row.lift
			row.inset, row.lift = inset, row.rise - drop
			local line = row.line(row)
			if not issecretvalue(line) and line then
				local cols = Fit(line, r.size)
				K.Line(row.c, Long(cols, r.size))
				for key, most in pairs(row.caps(cols)) do K.Most(row.c, key, most) end
				if cols ~= row.cols or moved then
					row.cols = cols
					row.shell.o.inset, row.shell.o.lift = row.inset, row.lift
					K.FitShell(row.shell, cols, row.rows)
				end
			end
		end
		P.Band(unit, -drop)
	end
end

-- The unit whose rows the mouse is over.
function P.Under()
	if not P.On() then return nil end
	for unit, band in pairs(bands) do
		if band:IsVisible() then
			local over = band:IsMouseOver()
			if not issecretvalue(over) and over then return unit end
		end
	end
end

-- The frame over a unit's rows (the mouse's), and, with `y`, laid that far up from its frame's top.
function P.Band(unit, y)
	local band = bands[unit]
	if band and y and band.y ~= y then
		band.y = y
		local button = rows[unit].button
		band:ClearAllPoints()
		band:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, y)
		band:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, y)
	end
	return band
end

-- A unit's rows: { { c, shell, cols, rows }, ... }, for tests and the tooltip.
function P.Rows(unit)
	return rows[unit] and rows[unit].list
end

-- Whether the unit frames carry buffs and debuffs: ShyFrames is there, and the setting is on.
function P.On()
	return frames ~= nil and T.db.frames
end

-- Something `width` wide stands at the far end of `unit`'s row (0: nothing): the row stops short of it.
function P.Room(unit, width)
	if (room[unit] or 0) == width then return end
	room[unit] = width
	ns.WhenFree("plates-fit", Refit)
end

function P.Apply()
	if not frames then return end
	ns.WhenFree("plates", function()
		if not next(rows) then Build() end
		-- A cell of the healing grid carries its marks inside it (Grid.lua): no row over it.
		local grid = ns.Grid ~= nil and ns.Grid.On()
		for unit, made in pairs(rows) do
			local on = T.db.frames and not (grid and made.kind == "party")
			for _, row in ipairs(made.list) do K.Watch(row.c, unit, on) end
		end
	end)
	Shy:Fire("SHY_BUFFS_ROWS")
end

-- A row whose unit became someone else: the game refreshes on aura events, not on this.
local function Refresh(prefix)
	for unit, made in pairs(rows) do
		if unit:find(prefix, 1, true) == 1 then
			for _, row in ipairs(made.list) do ns.Try(row.c.UpdateAllAuras, row.c) end
		end
	end
end

function P.Start()
	frames = Shy.addons.Frames
	if not (frames and frames.EachFrame) then
		frames = nil
		return
	end
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:SetScript("OnEvent", function(_, event)
		Refresh(event == "PLAYER_TARGET_CHANGED" and "target" or "party")
	end)
	-- ShyFrames sized its frames again (a layout's party cells are narrower or wider), or laid them out again (a round
	-- portrait came or went: where each row starts).
	Shy:On("SHY_FRAMES_FIT", function() ns.WhenFree("plates-fit", Refit) end)
	Shy:On("SHY_FRAMES", function() ns.WhenFree("plates-fit", Refit) end)
end
