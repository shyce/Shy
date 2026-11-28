-- Frame positions: one Shy.HUD box per frame (the party and its pets share one).
-- The HUD hides a secure box in combat, so each button is parented to UIParent and only anchored to its box.
-- Default positions: on ShyDock's housing while its console is in use; where the game's own frames stand while it
-- isn't yet (GameHomes); without ShyDock, fixed offsets scaled by screen height.
-- On the housing the party is a row of four cells over the player's plate and the target's, exactly as wide as the two.
--
-- The party's box is sized by its cells' width and height, not by a scale alone: in layout mode every corner and
-- side of it makes the cells wider or taller, and its panel there has a Width and a Height (by scale
-- alone, a tank's column could only be made narrower by making everything on it smaller). The size is kept with the box's place (its entry, as `w` and `h` in layout units, with `cell`
-- the kind it was given to: the row's and column's "squad", or the healing grid's, which are made differently),
-- so "Reset size", another Edit Mode layout and a setup that forgets sizes all give the planned cells back.

local ADDON, ns = ...
local T, L, F = ns.T, ns.Layout, ns.Frames
local HUD = Shy.HUD

local P = {}
ns.Place = P

local BASE_HEIGHT = 1200      -- the screen height the offsets below were measured on
local MEET_X, MEET_Y = 29, 160.6    -- where player and target meet: right of center, above the bottom
P.SEAM = 4                    -- between two party cells, and from their row to what rises under it

local BOXES = {
	{ id = "shyframes-player", title = "Player frame", kind = "player", keys = { "player" } },
	{ id = "shyframes-target", title = "Target frame", kind = "target", keys = { "target" } },
	{ id = "shyframes-targettarget", title = "Target's target", kind = "targettarget", keys = { "targettarget" } },
	{ id = "shyframes-pet", title = "Pet frame", kind = "pet", keys = { "pet" } },
	{ id = "shyframes-focus", title = "Focus frame", kind = "focus", keys = { "focus" } },
	{ id = "shyframes-party", title = "Party frames", kind = "party", party = true,
		keys = { "party1", "party2", "party3", "party4", "partypet1", "partypet2", "partypet3", "partypet4", F.SELF } },
}
P.boxes = {}   -- by kind: the HUD box
local PARTY = BOXES[#BOXES]
local NO_HANDLES = {}   -- the handles the party's box offers out of layout mode

-- The party's cells as the player made them: { width, height } in layout units, or nil while they are as planned.
local asked   -- the size a handle in the hand asks for meanwhile
local held    -- that handle's drag: the cells as it began, how many share it, the role's plan as it stood (Reshape)
local worn    -- the one the box was last laid out with ("width height"), or false
local function Kept()
	local hud = Shy.core and Shy.core.db and Shy.core.db.hud
	return hud and hud[PARTY.id]
end
local function Own()
	if asked then return asked end
	local kept = Kept()
	if kept and kept.w and kept.h and kept.cell == L.UNITS.party.layout then return { kept.w, kept.h } end
	return nil
end

-- Where the player's and target's plates meet, from the screen's bottom center; half the gap between them;
-- the console's seam (0 without one); and the console, when there is one.
local function Meet()
	local size = T.db.size
	local width = L.Size("player") * size
	local k = UIParent:GetHeight() / BASE_HEIGHT
	local dock = Shy.addons.Dock
	local left, bottom, dockWidth, dockHeight
	if dock and dock.HousingRect then left, bottom, dockWidth, dockHeight = dock:HousingRect() end
	if not left then return MEET_X * k, MEET_Y * k, 0, 0, nil end
	-- On the console every piece keeps its seam from the next: the plates from the bars under them,
	-- from each other (as far as the housing's width allows) and from the small frames.
	local seam = dock.Seam and dock:Seam() or 0
	local half = math.max(0, math.min(seam, dockWidth - 2 * width)) / 2
	return left + dockWidth / 2 - UIParent:GetWidth() / 2, bottom + dockHeight + seam, half, seam, dock
end

-- A game frame's rectangle on the screen, in UIParent units from its bottom left: left, bottom, right, top.
-- nil while it can't be read.
local function GameRect(name)
	local left, bottom, width, height = _G[name]:GetScaledRect()
	if ns.Units.Secret(left, bottom, width, height) or not (left and bottom and width and height) then return nil end
	local originX, originY = UIParent:GetScaledRect()
	local scale = UIParent:GetEffectiveScale()
	return (left - originX) / scale, (bottom - originY) / scale, (left + width - originX) / scale, (bottom + height - originY) / scale
end

-- A console that isn't in use yet (ShyDock is on, the Edit Mode layout in use is the game's or the player's own):
-- nothing was laid out round these frames, so each stands where that layout has the game's. Yours and your
-- target's on the middle of the game's; your focus under your frame and your target's target under your target's,
-- each at its outer end, so the two sides mirror; your pet under your focus; the party a column hung where the
-- game's hangs. nil with the console in use, without ShyDock, or while the game's frames can't be read.
local GAME = { player = "PlayerFrame", target = "TargetFrame", party = "PartyFrame" }

local function GameHomes()
	local dock = Shy.addons.Dock
	if not (dock and dock.ConsoleActive) or dock:ConsoleActive() then return nil end
	local size, half = T.db.size, UIParent:GetWidth() / 2
	local homes = { partyShape = "column", partyWidth = L.CELL.squad[1] * size }
	local ends = {}   -- by kind: the plate's left, bottom and right as it stands there
	for _, kind in ipairs({ "player", "target" }) do
		local left, bottom, right, top = GameRect(GAME[kind])
		if not left or right <= left or top <= bottom then return nil end
		local x, y = (left + right) / 2, (bottom + top) / 2
		local width, height = L.Size(kind)
		homes[kind] = { "CENTER", "BOTTOM", x - half, y }
		ends[kind] = { x - width * size / 2, y - height * size / 2, x + width * size / 2 }
	end
	local left, _, _, top = GameRect(GAME.party)   -- (with nobody in it the game's has no size: its corner is enough)
	if not left then return nil end
	homes.party = { "TOPLEFT", "BOTTOM", left - half, top }
	local _, focus = L.Size("focus")
	homes.focus = { "TOPLEFT", "BOTTOM", ends.player[1] - half, ends.player[2] - P.SEAM }
	homes.pet = { "TOPLEFT", "BOTTOM", ends.player[1] - half, ends.player[2] - 2 * P.SEAM - focus * size }
	homes.targettarget = { "TOPRIGHT", "BOTTOM", ends.target[3] - half, ends.target[2] - P.SEAM }
	return homes
end

-- Where every frame is stood by something that planned the whole screen: ShyDock's layout by role
-- (Dock:UnitHomes), or the game's own places while the console isn't in use (GameHomes). nil in a classic
-- layout, or with no console: the plates stand on the housing, or at their own place.
local function RoleHomes()
	-- (ShyDock builds its plan anew at every asking: while a handle is dragged, the one it began with serves.)
	if held and HUD.Sizing and HUD.Sizing() then return held.role end
	local dock = Shy.addons.Dock
	return dock and dock.UnitHomes and dock:UnitHomes() or GameHomes()
end

-- A box's size in layout units, and each frame's offset in it (from its top left, y downward). The party is a row
-- of four as wide as the player's plate, the target's and what lies between them; a layout by role may ask for it
-- as a row or a column as wide as its group (`partyShape`, `partyWidth`). Each cell's row of icons (ns.CellRise)
-- is in the box, over the cell: in a column it stands between one cell and the next.
-- The healing grid is as many cells as hold someone, each its own width, the box no wider (or taller) than they
-- are: it is centred on its home, so it stays in the middle whoever comes and goes. A seat nobody holds stands
-- on past the box's end, where its cell shows should someone join in a fight.
-- Cells the player sized (Own) are that size whatever the plan: the box is as wide and tall as they make it.
local function Plan(def)
	local width, height = L.Size(def.kind)
	if not def.party then return width, height, { [def.keys[1]] = { 0, 0 } } end
	local size = T.db.size
	local gap = P.SEAM / size
	local role = RoleHomes()
	local column = role and role.partyShape == "column"
	local grid = ns.Grid()
	-- Each kind of cell as it is made; the row's and the column's as wide as their place.
	for name, made in pairs(L.CELL) do
		local layout = L.LAYOUTS[name]
		layout.width, layout.height = made[1], made[2]
	end
	local span
	if role then
		span = role.partyWidth / size
		if column then L.LAYOUTS.squad.width = span else L.FitSquad(span, gap) end
	else
		local _, _, half = Meet()
		span = 2 * L.Size("player") + 2 * half / size
		L.FitSquad(span, gap)
	end
	local own = Own()
	L.Cell(own and own[1], own and own[2])
	worn = own and (own[1] .. " " .. own[2]) or false
	width, height = L.Size("party")
	local rise = ns.CellRise()
	local cell, sliver = L.Of("party"), L.LAYOUTS.sliver
	local spots = {}
	local seats, count = F.Seats()
	for seat, key in ipairs(seats) do
		local x, y = (seat - 1) * (width + gap), rise
		if column then x, y = 0, rise + (seat - 1) * (rise + height + gap) end
		spots[key] = { x, y }
		local member = key:match("^party(%d)$")
		if member then spots["partypet" .. member] = { x + width - cell.pad.side - sliver.width, y + cell.pad.top } end
	end
	spots[F.SELF] = spots[F.SELF] or { 0, rise }   -- out of the grid it never shows
	local cells = grid and math.max(1, count) or 4
	if column then return width, cells * (rise + height) + (cells - 1) * gap, spots end
	return cells * width + (cells - 1) * gap, rise + height, spots
end

-- How many cells the party's box holds across and down.
local function Cells()
	local role = RoleHomes()
	local cells = 4
	if ns.Grid() then
		local _, count = F.Seats()
		cells = math.max(1, count)
	end
	if role and role.partyShape == "column" then return 1, cells end
	return cells, 1
end

-- What the party's box was last laid out by: the grid or the row, and who stands where.
local function Seating()
	local grid, sample = ns.GridWanted(), ns.SampleWanted()
	local seats, count = F.Seats(grid, sample)
	return (grid and "grid " or "row ") .. (sample and "sample " or "") .. count .. " " .. table.concat(seats, " ")
end
local seated

-- How far the party's row stands over the plates' top edge: clear of what rises from it.
function P.Lift()
	return ns.Rise() * T.db.size + P.SEAM
end

-- Each box's default position: { boxPoint, screenPoint, x, y }. In ShyDock's layouts by role, where the role
-- stands each frame round your character; with the console not in use yet, where the game's frames stand.
function P.Homes()
	local role = RoleHomes()
	if role then
		-- (A row comes centred on its place, a column hung from it by the side your frames are on: cells narrower or
		-- wider than planned stay in the middle, or by your frames.)
		return { player = role.player, target = role.target, targettarget = role.targettarget, focus = role.focus,
			pet = role.pet, party = role.party }
	end
	local size = T.db.size
	local width, height = L.Size("player")
	width, height = width * size, height * size
	local x, y, half, seam, dock = Meet()
	local out = half + width + seam
	local _, small = L.Size("focus")
	small = small * size
	-- Beside the plates the small frames stand on their foot: your target's target down at your target's outer
	-- end, your focus its mirror at yours, your pet over your focus.
	local homes = {
		player = { "BOTTOMRIGHT", "BOTTOM", x - half, y },
		target = { "BOTTOMLEFT", "BOTTOM", x + half, y },
		focus = { "BOTTOMRIGHT", "BOTTOM", x - out, y },
		pet = { "BOTTOMRIGHT", "BOTTOM", x - out, y + small + seam },
		targettarget = { "BOTTOMLEFT", "BOTTOM", x + out, y },
		-- Centred over where your plate and your target's meet: as wide as the two as planned, and in the middle
		-- whatever its cells' width (the grid's, or one the player gave them).
		party = { "BOTTOM", "BOTTOM", x, y + height + P.Lift() },
	}
	-- When the console's wings reach the plates' height, the small frames go on its roof.
	local roof = dock and dock.Roof and dock:Roof()
	if roof and roof > y + height - small then
		-- Flush with the wing they stand on, not with the plate beside it.
		local leftEdge, rightEdge = x - half - width, x + half + width
		if dock.WingEdges then leftEdge, rightEdge = dock:WingEdges() end
		homes.focus = { "BOTTOMRIGHT", "BOTTOM", leftEdge, roof + seam }
		homes.pet = { "BOTTOMRIGHT", "BOTTOM", leftEdge, roof + seam + small + seam }
		homes.targettarget = { "BOTTOMLEFT", "BOTTOM", rightEdge, roof + seam }
	end
	return homes
end

-- Sizes a box and anchors its frames in it. Out of combat only.
local function Fit(def)
	local box, size = P.boxes[def.kind], T.db.size
	local width, height, spots = Plan(def)
	box:SetSize(width * size, height * size)
	local scale = size * box:GetScale()
	for _, key in ipairs(def.keys) do
		local frame = F.byKey[key]
		local button, spot = frame.button, spots[key]
		button:SetScale(scale)
		button:SetSize(L.Size(frame.kind))
		button:ClearAllPoints()
		-- Offsets are in the button's own scale, so in layout units.
		button:SetPoint("TOPLEFT", box, "TOPLEFT", spot[1], -spot[2])
		F.Watch(frame)
	end
	HUD.Update(box)
end

function P.Home()
	local homes = P.Homes()
	for kind, box in pairs(P.boxes) do HUD.SetHome(box, homes[kind]) end
end

function P.Apply()
	ns.AfterCombat("place", function()
		-- Your frame's height and your target's, with the buttons that carry them: never one without the other.
		L.MainHeight(T.db.height)
		-- The party's cells take the grid's make or the row's here, with the frames that carry them: never one
		-- without the other.
		L.Party(ns.TakeGrid())
		ns.TakeSample()
		seated = Seating()
		for _, def in ipairs(BOXES) do Fit(def) end
		P.Home()
		F.Redraw()
		-- The cells may be wider or narrower: ShyBuffs fits its rows to them.
		Shy:Fire("SHY_FRAMES_FIT")
	end)
end

-- Someone came or went, a role was given, you became the healer, or the test party was asked for: the party's box
-- is laid out again if who stands where changed (after the fight, in one).
function P.Reseat()
	if Seating() ~= seated then P.Apply() end
end

-- The party's cells, sized by the player

-- A cell's width and height within what its kind allows, in whole layout units.
local function Within(width, height)
	local least, most = L.CELL_LEAST[L.UNITS.party.layout], L.CELL_MOST
	return math.floor(math.max(least[1], math.min(most[1], width)) + 0.5), math.floor(math.max(least[2], math.min(most[2], height)) + 0.5)
end

-- The party's cells are that wide and tall from now on, kept for their kind; everything fitted to them is fitted
-- again (after the fight, in one).
function P.SetCell(width, height)
	width, height = Within(width, height)
	local kept = HUD.Act.Keep(P.boxes.party)
	kept.w, kept.h, kept.cell = width, height, L.UNITS.party.layout
	T:Apply()
end

-- A handle of the party's box dragged (Shy.HUD.Grip's shape): the box so much wider and taller than it was when
-- pressed, shared out among the cells across it and down it. The cells follow the mouse; the size is kept, and the
-- rest of the screen told, when the handle is let go. No drag begins in a fight, and a fight ends one.
local function Reshape(wider, taller, phase, point)
	local box = P.boxes.party
	if phase == "start" then
		held = nil
		if InCombatLockdown() then return end
		local width, height = L.Size("party")
		local across, down = Cells()
		held = { w = width, h = height, across = across, down = down, hold = HUD.Hold(box, point), placed = HUD.IsPlaced(box),
			role = RoleHomes() }
		held.w0, held.h0 = Within(width, height)   -- in whole units, as a drag that came to nothing would leave them
	end
	local s = held
	if not s then return end
	local size = T.db.size
	local width, height = Within(s.w + (wider or 0) / size / s.across, s.h + (taller or 0) / size / s.down)
	local free = not InCombatLockdown()
	if free and not (asked and asked[1] == width and asked[2] == height) then
		asked = { width, height }
		Fit(PARTY)
		for _, key in ipairs(PARTY.keys) do
			local plate = F.byKey[key].plate
			plate:Arrange()
			plate:Update()
		end
		Shy:Fire("SHY_FRAMES_FIT")
		s.hold()
	end
	if phase ~= "stop" then return end
	held = nil
	-- (A drag that came to nothing keeps nothing: the cells are as planned again, to the fraction.)
	if asked and (asked[1] ~= s.w0 or asked[2] ~= s.h0) then
		local kept = HUD.Act.Keep(box)
		kept.w, kept.h, kept.cell = asked[1], asked[2], L.UNITS.party.layout
	end
	asked = nil
	-- A box the player placed keeps the edges the handle never moved; one at its home stands there at its new size.
	if free then
		if s.placed then s.hold(true) else HUD.Apply(box) end
	end
	T:Apply()
end

-- The box's own controls on the layout editor's panel: its cells' width and height, each taken as its knob is let
-- go (the frames are fitted again by them, and the panel stands beside them).
local function Panel(panel, Put, group, width)
	local own = panel.partyCells
	if not own then
		own = {}
		local function Knob(label, index, desc)
			local pending
			return group:Slider(panel, label, math.min(L.CELL_LEAST.squad[index], L.CELL_LEAST.grid[index]), L.CELL_MOST[index], 1,
				function() return pending or math.floor(select(index, L.Size("party")) + 0.5) end,
				function(v) pending = v end,
				{ width = width, desc = desc,
					settle = function(v)
						pending = nil
						local w, h = L.Size("party")
						if v == math.floor((index == 1 and w or h) + 0.5) then return end
						if index == 1 then w = v else h = v end
						P.SetCell(w, h)
					end })
		end
		own.width = Knob("Width", 1, "How wide each party member's frame is.")
		own.height = Knob("Height", 2, "How tall each party member's frame is.")
		panel.partyCells = own
	end
	Put(own.width, 38)
	Put(own.height, 38)
end

-- The stance bar is placed by Edit Mode; an older console layout may leave it under a plate.

local function Rect(frame)
	local left, bottom, width, height = frame:GetScaledRect()
	if ns.Units.Secret(left, bottom, width, height) or not (left and bottom and width and height) then return nil end
	return left, bottom, left + width, bottom + height
end

-- Whether the stance bar overlaps the player or target plate.
function P.Crowded()
	local shown = StanceBar:IsShown()
	if ns.Units.Secret(shown) or not shown then return false end
	local left, bottom, right, top = Rect(StanceBar)
	if not left then return false end
	for _, key in ipairs({ "player", "target" }) do
		local l, b, r, t = Rect(P.boxes[key])
		-- Over 2 units: touching edges are normal on the console.
		if l and math.min(right, r) - math.max(left, l) > 2 and math.min(top, t) - math.max(bottom, b) > 2 then return true end
	end
	return false
end

local told
function P.TellIfCrowded()
	if told or not Shy.addons.Dock or not (T.db.units.player or T.db.units.target) then return end
	if P.Crowded() then
		told = true
		T:Print("your stance bar overlaps your frames. Set up the console again (/shy setup) to move it.")
	end
end

function P.Start()
	C_Timer.After(5, P.TellIfCrowded)   -- after the action bars have laid out
	L.Party(ns.TakeGrid())
	local homes = P.Homes()
	for _, def in ipairs(BOXES) do
		local width, height = Plan(def)
		local box = HUD.Create({
			id = def.id, title = def.title, secure = true,
			width = width * T.db.size, height = height * T.db.size,
			point = homes[def.kind],
			shown = function() return T.db.units[def.kind] end,
			-- The party's box is held by every corner and side while the screen is being arranged, and only then:
			-- in play its cells are clicked right to their edges. A drag makes the cells wider or taller.
			grip = def.party and {
				shape = Reshape, corners = "slim",
				points = function() return not HUD.IsUnlocked() and NO_HANDLES or nil end,
				tip = "Drag to make the party's frames wider or taller.",
			} or nil,
		})
		P.boxes[def.kind] = box
		if def.party then
			-- The party keeps watch while the HUD is faded.
			local immersion = Shy.Immersion
			if immersion and immersion.Watch then immersion.Watch("group", box) end
			box.panel = Panel
		end
		-- Layout mode resizes a box by its scale: the frames follow.
		hooksecurefunc(box, "SetScale", function()
			ns.AfterCombat("fit-" .. def.kind, function() Fit(def) end)
		end)
	end
	-- The console moved or changed width: the party's cells are cut to the plates' span.
	Shy:On("SHY_CONSOLE", function()
		P.Apply()
		F.Redraw()
	end)
	-- In a layout by role your frames stand clear of the cooldown manager: it grew or shrank, they follow.
	Shy:On("SHY_COCKPIT", function()
		if RoleHomes() then ns.AfterCombat("home", P.Home) end
	end)
	local events = CreateFrame("Frame")
	events:RegisterEvent("UI_SCALE_CHANGED")
	events:RegisterEvent("DISPLAY_SIZE_CHANGED")
	events:SetScript("OnEvent", function() P.Home() end)
	-- Another Edit Mode layout came into use, or the one in use was changed: the game's frames may stand elsewhere,
	-- and the console may be in use now or no longer. Next frame, once the game has laid its frames out.
	local layouts = CreateFrame("Frame")
	layouts:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	local again = Shy.Clocked("frames: another layout", P.Apply)
	layouts:SetScript("OnEvent", function() C_Timer.After(0, again) end)
	-- Who stands where in the party's box, and whether it is the healing grid.
	local roster = CreateFrame("Frame")
	roster:RegisterEvent("GROUP_ROSTER_UPDATE")
	roster:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	roster:SetScript("OnEvent", P.Reseat)
	Shy:On("SHY_ROLE", P.Reseat)
	-- The screen is being arranged, or no longer: the test party comes and goes with it, and the party's handles.
	Shy:On("SHY_HUD_LAYOUT", function()
		P.Reseat()
		local grip = HUD.Grip and HUD.Grip(P.boxes.party)
		if grip then grip:Follow() end
	end)
	-- The party's box placed again (a reset of its size, another Edit Mode layout, a setup that forgets sizes): its
	-- cells as they are kept for it now.
	hooksecurefunc(HUD, "Apply", function(box)
		if box ~= P.boxes.party or asked then return end
		local own = Own()
		if (own and (own[1] .. " " .. own[2]) or false) ~= worn then P.Apply() end
	end)
end
