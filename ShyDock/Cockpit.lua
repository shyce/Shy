-- The cockpit: the art behind the HUD under the character. One plate round the personal
-- resource display and the cooldowns' rows (Layout.lua plans the rows; nothing is drawn
-- round a row: the rows stand in the plate). While a cast is up the cast bar is a row of it,
-- joined to the display's block (one frame round the bars, the swing row and the cast bar's row,
-- hairlines of its steel between): the plate grows down round it, quickly, the foot row riding its
-- foot down with it, and shrinks back after a moment's hold. With the display out of the vessel the
-- row hangs under what is left, framed alone in the same steel. Beside it, a flap of the same make
-- for the tracked bars while any is up, joined to the plate by a rib.
--
-- Layout.lua seats the Blizzard frames (Layout.Cockpit); this file draws behind
-- them. The art is placed by coordinates from the plan: never anchored to a
-- Blizzard frame (the stance bar is protected, the rest belong to Edit Mode) and
-- never drawn on one. Each row is measured from what currently shows in it.
-- The plate shows only while the console layout is active and the display (or the
-- essential cooldowns) is at its seat; if the player moved it in Edit Mode the plate hides.
-- Blizzard only sizes the cast bar in SetLook, so its size is set when the plate
-- is drawn and after each SetLook, and the original size is restored on release.
--
-- The plate and the flap are housings of the family's make (ShyCore's UI.Panel, as the bar housing is),
-- so they wear the theme's look (Theme.Look: forged, steel, clear or eclipse; UI.lua, "The looks") like
-- every piece on screen, and follow the Background strength unless "See-through" is off (cockpitFollow).
-- The display is one block whatever the look: one steel frame round its bars (and the swing row), with
-- nothing drawn in the gaps between them, so the plate shows through. The art eases between plans; the
-- look's light (in the top edge, or round the slab) brightens in a fight; a row lights gold for a moment
-- when an essential cooldown ends (the gems') or a form changes (the stances').
--
-- API (for ShySkin and ShyRogue):
--   Shy.addons.Dock:Cockpit() -> left, bottom, right, top   UIParent units; nil while hidden
--   Shy.addons.Dock:CockpitHolds(key)   "display" | "essential" | "utility" | "stances" | "blades" | "cast" | "buffs" | "bars" | "swing"
--   Shy.addons.Dock:CockpitCast() -> side, gap   spell icon size and its gap to the bar; nil unless the cockpit holds the cast bar
--   Shy.addons.Dock:StripBays() -> rest, fight   the Shift strip's bay at the plate's end (Layout.lua's Bay), now and as
--                                                a fight will have it: where ShyTip's pings and markers stand
--   Shy.addons.Dock:CockpitWing(out, rider)      the plate grows over the bay (false: back in), sliding like a hover's
--                                                foot; `rider` is a frame faded in as it slides out (ShyTip's pings and markers)
--   "SHY_COCKPIT" on the bus (up)       the plate showed, hid or moved, the strip's bay changed, or the cast bar's numbers changed

local ADDON, ns = ...
local T = ns.T
local UI, Theme, Skin = Shy.UI, Shy.Theme, Shy.Skin
local abs, max, min, floor = math.abs, math.max, math.min, math.floor

local K = {}
ns.Cockpit = K

-- The housings' make: the bar housing's (Housing.lua), following the Background strength.
local HOUSING = { cap = true, facets = false, line = false, brackets = 10, hud = true, mini = true }   -- (the look's mini border)
K.HOUSING = HOUSING
local function FillIn(frame)
	return UI.LookFillIn(frame and frame.shyLook)
end
local SETTLE = 0.3
local SLACK = 3        -- a piece within this of its seat counts as seated
local SLIDE = 0.16     -- seconds the wing takes to slide out; a hover's foot takes the same
local EASE = 0.15      -- seconds the art takes to a new plan, and a row's light to fade
local PULSE = 0.4      -- seconds a row's gold light lasts
local REST, FIGHT = 0.6, 1   -- the accent light's strength out of a fight, and in one
local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_SHAPESHIFT_FORM" }
-- The first of these on screen decides whether the plate shows.
local HELD = { { key = "display", rect = "display" }, { key = "essential", rect = "gems" } }
local INSIDE = { display = true, essential = true, utility = true, stances = true, blades = true, cast = true, buffs = true,
	bars = true, swing = true }
local box, gems, tiles, stances, buffs, flap, driver, pending
local plan         -- the plan the plate was last drawn from
local flapPlan     -- the plan the flap was last drawn from (a home of the bars' own outlives the plate)
local tilesAt, stancesAt, gemsAt, buffsAt   -- the rows' rects as last measured
local buffsSoon
local pulsing = {}    -- essential items whose cooldown's end is followed
local docksWas     -- last value of "blades dock in the top edge"
local dressWas     -- the layout, scale and bars' side last applied
local casting      -- the cockpit holds the cast bar
local castWas      -- the cast bar's own size, to restore: { width, height }
local castSaid     -- signature last fired for the cast bar
local wing, slider -- the floor of the plate's grown part, and the frame that slides it
local wingWant, wingNow, wingSpan = 0, 0, 0   -- the bay's width while it is out, slid out so far, and the last width
local wingRider    -- frame faded in as the wing slides out
local wingOut = false   -- the Shift strip is up: the plate reaches over its bay
local bayWas       -- the bay the strip was last told of
local rowsWas      -- how much stood in the gems' row and the foot row's groups when the plate was last drawn
-- The plate glides to a new shape (a fight begins and the cooldowns come, one is learned, a row grows): it is
-- drawn at `drawn`, on its way to K.rect, which stays the plate as planned. The cast bar's row opens
-- quickly (the bar is there at once; the plate catches it up) and closes a little slower, and only after
-- a moment's hold: casts come back to back, and the row stays open for the next one.
local GLIDE = 0.22
local CAST_OPEN, CAST_CLOSE, CAST_HOLD = 0.1, 0.2, 0.35
local castEnded   -- when the last cast ended (GetTime), while the row is held open for the next
local drawn, glide, glider
local later        -- the layout shows the essential cooldowns only in combat
local fighting = false
local apart = false   -- the vessel is taken apart (Pieces.lua): the plate stays up whatever stands in it

local function Rows()
	local rows = {}
	for _, def in ipairs(ns.Layout.ROWS) do rows[def.key] = def end
	return rows
end

local function Present(c)
	if c.present then return c.present end
	local _, now = ns.Layout.Plan()
	return ns.Layout.Present(now)
end

-- Is a core piece on screen and seated? nil when the rect is secret or nothing shows (keep the
-- current state). A piece dragged off in Edit Mode is loose (Move.lua), so a seated one on screen
-- holds the plate up wherever the game last stood it: its seat follows a frame later. Taken apart, the
-- plate stays; with both core pieces out, whatever is left holds it up.
local function Held(c)
	if apart then return true end
	local rows = Rows()
	local present = Present(c)
	for _, def in ipairs(HELD) do
		if not ns.char.loose[def.key] then
			local l = ns.Layout.RowRect(rows[def.key])
			if l == false then return nil end
			if l then return true end
		end
	end
	-- Neither core piece can hold it up: both taken out, or neither there by design (a layout by role has no
	-- display, and the gems wait for a fight). Then whatever is left holds it up, from the first draw on.
	local noDisplay = ns.char.loose.display or not present.display
	local noGems = ns.char.loose.essential or ns.Layout.CombatOnly("essential")
	if noDisplay and noGems then
		return (present.tiles or present.buffs or present.swing) and true or false
	end
	return nil
end

-- Eases: an object's alpha drifts to a target over EASE seconds.

local eases = {}   -- frame -> target alpha
local easer

local function Easing(_, elapsed)
	local any = false
	for frame, target in pairs(eases) do
		local now = frame:GetAlpha()
		local step = elapsed / EASE
		if now < target then now = min(target, now + step) else now = max(target, now - step) end
		frame:SetAlpha(now)
		if now == target then eases[frame] = nil else any = true end
	end
	if not any then easer:Hide() end
end

local function Drift(frame, target)
	eases[frame] = target
	if not easer then
		easer = CreateFrame("Frame")
		easer:SetScript("OnUpdate", Easing)
	end
	easer:Show()
end

-- Place a frame or region at a plan rect (x from the screen's centre). Only what changed is set: a plan drawn
-- again unchanged (a fight's edge, a buff coming) moves nothing. Every frame and region placed here is ours and
-- placed only here, so what it was last given is where it stands.
local placedAt = setmetatable({}, { __mode = "k" })   -- frame -> { x, y, w, h } last given
local function Place(frame, rect)
	local x, y = UIParent:GetWidth() / 2 + rect[1], rect[2]
	local w, h = max(1, rect[3] - rect[1]), max(1, rect[4] - rect[2])
	local at = placedAt[frame]
	if at and at[1] == x and at[2] == y and at[3] == w and at[4] == h then return end
	if not at then
		at = {}
		placedAt[frame] = at
	end
	at[1], at[2], at[3], at[4] = x, y, w, h
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
	frame:SetSize(w, h)
end

-- Show a frame, fading in unless `quiet` (a drag); or hide it at once.
local function Fade(frame, on, quiet)
	if on then
		if not frame:IsShown() then
			if quiet then
				frame:SetAlpha(1)
			else
				frame:SetAlpha(0)
				Drift(frame, 1)
			end
			frame:Show()
		end
	else
		eases[frame] = nil
		frame:SetAlpha(1)
		frame:Hide()
	end
end

local function Seat(frame, rect, quiet)
	Place(frame, rect)
	Fade(frame, true, quiet)
end

-- The cast bar

-- Size the cast bar from plan `c`, or restore its own size with nil. Skipped
-- while protected in combat; PLAYER_REGEN_ENABLED measures again.
local function SizeCast(c)
	local bar = PlayerCastingBarFrame
	if not bar or (bar:IsProtected() and InCombatLockdown()) then return end
	if c then
		-- The plan is in screen units; SetSize takes the frame's own.
		local scale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local width, height = c.castWidth / scale, c.castHeight / scale
		if not castWas then castWas = { bar:GetWidth(), bar:GetHeight() } end
		if abs(bar:GetWidth() - width) > 0.01 or abs(bar:GetHeight() - height) > 0.01 then bar:SetSize(width, height) end
	elseif castWas then
		bar:SetSize(castWas[1], castWas[2])
		castWas = nil
		-- Its own size back: stood again where the game has it, by the new width.
		local adopted = Shy.HUD.Adopted(bar)
		if adopted then Shy.HUD.Apply(adopted) end
	end
end

-- Take or release the cast bar for plan `c` (nil: the plate is hidden).
-- Returns true when CockpitCast's answer or the bar's size changed.
local function Cast(c)
	casting = c ~= nil and PlayerCastingBarFrame ~= nil and ns.Layout.WasSeated("cast") and not ns.char.loose.cast
	SizeCast(casting and c or nil)
	local said = casting and table.concat({ c.castSide, c.castGap, c.castWidth, c.castHeight }, " ") or false
	if said == castSaid then return false end
	castSaid = said
	return true
end

-- The personal resource display

-- Since build 70291 the display also shows combo points (ClassFrameContainer)
-- and a druid's mana in form (AlternatePowerBar) under its two bars. The plate
-- makes room for the mana bar (the plan's altH); the class bar would stand in
-- the gems, so while the cockpit holds the display it is kept hidden, and on
-- release it follows the Edit Mode settings again. Every Blizzard path that
-- shows it ends in UpdateFrameHeight; a ticker in K.Start follows that height (never post-hook it: UNIT_AURA).
local EXTRAS = { "ClassFrameContainer" }
local bare = false   -- the cockpit holds the display

local function Strip()
	if not bare then return end
	local display = PersonalResourceDisplayFrame
	for _, key in ipairs(EXTRAS) do
		if display[key]:IsShown() then display[key]:Hide() end
	end
end

-- In the cockpit the display's bars stand a seam apart (Layout.lua's BARS_GAP), not the 4 the display keeps
-- at the least: after the display anchors its power bar (and a druid's mana bar) they are anchored again a
-- seam under the bar over them, and after it sets its height it is set to the bars' span. Hooked in
-- K.Start; nothing else of the display is touched, and released it lays itself out again.
local function Tighten()
	if not bare then return end
	local display = PersonalResourceDisplayFrame
	-- The seam is the plan's, in the display's own units: a whole pixel or two at the scale it is seated at.
	local seam = ns.Layout.BARS.gap
	if plan and plan.scales.display then seam = plan.m.seam / plan.scales.display end
	local health, power, alt = display.HealthBarsContainer, display.PowerBar, display.AlternatePowerBar
	local healthH, powerH, altH = health:GetHeight(), power:GetHeight(), alt:GetHeight()
	local altShown = alt:IsShown()
	if issecretvalue(healthH) or issecretvalue(powerH) or issecretvalue(altH) or issecretvalue(altShown) then return end
	local hideHealth, hidePower = display.hideHealth == true, display.hidePower == true
	local height, over = 0, nil
	if not hideHealth then
		height, over = healthH, health
	end
	if not hidePower then
		if over then
			power:ClearAllPoints()
			power:SetPoint("TOP", over, "BOTTOM", 0, -seam)
			height = height + seam
		end
		height, over = height + powerH, power
	end
	if altShown then
		if over then
			alt:ClearAllPoints()
			alt:SetPoint("TOP", over, "BOTTOM", 0, -seam)
			height = height + seam
		end
		height = height + altH
	end
	display:SetHeight(max(height, 15))
end

local function Bare(on)
	local display = PersonalResourceDisplayFrame
	if not display or bare == on then return end
	bare = on
	if on then
		Strip()
	else
		display.ClassFrameContainer:SetShown(not display.hideClassInfo and display:GetClassFrameInfo() ~= nil)
		display.AlternatePowerBar:SetShown(not display.hideAltPower and display:HasAlternatePowerBar() == true)
	end
	-- Called by hand: before the display's first setup its pieces have no scripts that would. Released, the
	-- display's own anchors and height come back.
	display:UpdatePowerBarAnchor()
	display:UpdateAdditionalBarAnchors()
	display:UpdateFrameHeight()
	Tighten()
end

-- The plate, its rows, the cast piece

local function Tell(changed)
	if changed then Shy:Fire("SHY_COCKPIT", K.rect ~= nil) end
end

-- keep: the flap stays as it is (a home of the bars' own: Apart redraws it); else it goes with the plate.
local function Down(keep)
	local had = K.rect ~= nil
	K.rect, plan, bayWas, drawn, glide, rowsWas = nil, nil, nil, nil, nil, nil
	glider:Hide()
	box:Hide()
	if not keep then
		Fade(flap, false)
		flapPlan = nil
	end
	Bare(false)
	local cast = Cast(nil)
	Tell(had or cast)
end

-- One group of the foot row as it shows (the utility cooldowns at its left end, the stance bar at its
-- right), a pad round it, in plan units. nil when it doesn't show; `last` (else the plan's) when its rect is
-- secret.
local function TileSlot(c, key, last)
	if ns.char.loose[key] then return nil end
	local middle, pad = UIParent:GetWidth() / 2, c.m.slot
	local band = c.rects.tiles[4] - pad   -- planned top of the tiles
	local l, b, r, t = ns.Layout.RowRect(Rows()[key])
	if l == false then
		local planned = c.rects[key]
		return last or (planned and { planned[1] - pad, planned[2] - pad, planned[3] + pad, planned[4] + pad })
	end
	-- A row moved elsewhere in Edit Mode isn't in the row.
	if not (l and t > c.row + SLACK and b < band - SLACK) then return nil end
	return { l - middle - pad, b - pad, r - middle + pad, t + pad }
end

-- The row of tracked buffs that show, a pad round them, while their row is seated. nil with no buff up
-- or the row elsewhere (moved in Edit Mode); the last rect when secret.
local function BuffSlot(c)
	if ns.char.loose.buffs or c.buffsIn == "over" then return nil end
	local l, b, r, t = ns.Layout.RowRect(Rows().buffs)
	if l == false then return buffsAt end
	if not l then return nil end
	local middle = UIParent:GetWidth() / 2
	if abs(b - c.buffs) > SLACK or r - middle > c.buffsRight + SLACK then return nil end
	local pad = c.m.slot
	return { l - middle - pad, b - pad, r - middle + pad, t + pad }
end

local Flap

-- The game keeps a place in the column for every tracked bar, up or not (CooldownViewer.xml:
-- includeAsLayoutChildWhenHidden), so a bar that is down between two that are up left a hole. The bars that show
-- are stood in the column's first places, in their own order. A place is an anchor the game gave (kept as its
-- layout hands them out), so the spacing stays the game's. Only the items' anchors are set (C API: nothing of
-- the viewer is written or hooked); the game's next layout puts every bar back in its own place, which PollBars
-- sees by `at` and has closed up again.
local stack = {
	places = {},                                  -- place -> { point, to, relativePoint, x, y } as the game laid it out
	stood = setmetatable({}, { __mode = "k" }),   -- item -> the place it was last stood in here
	up = {},                                      -- the bars that show, in the column's order
	at = nil,                                     -- what the anchors of the bars that show add up to, as left here
	order = function(a, b) return a.layoutIndex < b.layoutIndex end,
}

local function Stack(pool)
	local places, stood, up = stack.places, stack.stood, stack.up
	local n = 0
	stack.at = nil
	for item in pool:EnumerateActive() do
		if issecretvalue(item) then return end
		local index, shown = item.layoutIndex, item:IsShown()
		if issecretvalue(index) or issecretvalue(shown) or type(index) ~= "number" then return end
		local point, to, relativePoint, x, y = item:GetPoint(1)
		if issecretvalue(point) or issecretvalue(x) or issecretvalue(y) or point == nil then return end
		-- Not where it was last stood: the game has laid the column out again, and this is its own place's anchor.
		local mine = places[stood[item] or 0]
		if not (mine and mine[1] == point and mine[2] == to and mine[3] == relativePoint
			and abs(mine[4] - x) < 0.01 and abs(mine[5] - y) < 0.01) then
			stood[item] = nil
			local place = places[index]
			if not place then
				place = {}
				places[index] = place
			end
			place[1], place[2], place[3], place[4], place[5] = point, to, relativePoint, x, y
		end
		if shown then
			n = n + 1
			up[n] = item
		end
	end
	for i = #up, n + 1, -1 do up[i] = nil end
	table.sort(up, stack.order)
	local at = 0
	for k = 1, n do
		local item, place = up[k], places[k]
		if place and (stood[item] or item.layoutIndex) ~= k then
			item:ClearAllPoints()
			item:SetPoint(place[1], place[2], place[3], place[4], place[5])
			stood[item] = k
		end
		local _, _, _, x, y = item:GetPoint(1)
		at = at + 2 * x + y
	end
	stack.at = at
end

-- The 30x220 template at the health bar's height, width put back (or, in a home of their own, the home's width:
-- c.barsWidth over the plan's bar width), and the bars that show closed up (Stack). Only the items are scaled
-- and anchored (C API). Writing iconScale / barWidthScale onto BuffBarCooldownViewer taints its aura map.
local function FitItems(c)
	local viewer = BuffBarCooldownViewer
	local want = ns.Layout.TRACKED
	if not (viewer and want) then return end
	local width = (viewer.baseBarWidth or 220) * want.width
	if c and c.barsWidth and c.m and c.m.barW > 0 then width = width * c.barsWidth / c.m.barW end
	local pool = viewer.itemFramePool
	if not (pool and pool.EnumerateActive) then return end
	for item in pool:EnumerateActive() do
		if item.Bar and not issecretvalue(item) then
			item:SetScale(want.icon)
			item:SetWidth(width)
		end
	end
	Stack(pool)
end

-- A buff or a tracked bar showed or hid: redo only its row or the flap, next frame. Runs throughout
-- combat, so it stays cheap.
function K.Buffs()
	if buffsSoon then return end
	buffsSoon = true
	C_Timer.After(0, function()
		buffsSoon = nil
		if K.rect and plan then
			if InCombatLockdown() then K.owed = true end
			FitItems(plan)
			buffsAt = BuffSlot(plan)
			if buffsAt then Seat(buffs, buffsAt) else Fade(buffs, false) end
			Flap(plan)
			if ns.Move then ns.Move.Touch() end
		elseif flapPlan and flapPlan.barsApart then
			-- The plate is down, the bars' home of their own isn't.
			if InCombatLockdown() then K.owed = true end
			FitItems(flapPlan)
			Flap(flapPlan)
			if ns.Move then ns.Move.Touch() end
		end
	end)
end

-- Tracked buff icons and bars show and hide without a new layout. The buff row and flap are remeasured on
-- K.Buffs (next frame). Never post-hook CooldownViewer or PersonalResourceDisplay from UNIT_AURA: that
-- taints the cooldown manager's aura map (RegisterAuraInstanceIDItemFrame).
local POLL = 0.05
-- The display as last seen: its height (to a thousandth) and whether its mana and class bars show. Compared as
-- numbers twenty times a second: nothing is made for it.
local display = { seen = false }

-- The display's state now, or nil when it can't be read.
local function DisplayNow()
	local d = PersonalResourceDisplayFrame
	if not d then return nil end
	-- Hidden, nothing of it is drawn: what changed meanwhile is found the first look after it shows.
	local up = d:IsShown()
	if issecretvalue(up) or not up then return nil end
	local h = d:GetHeight()
	if issecretvalue(h) then return nil end
	local alt = d.AlternatePowerBar and d.AlternatePowerBar:IsShown()
	local cls = d.ClassFrameContainer and d.ClassFrameContainer:IsShown()
	if issecretvalue(alt) or issecretvalue(cls) then return nil end
	return floor((h or 0) * 1000 + 0.5), alt and true or false, cls and true or false
end

local function Redisplay()
	Strip()
	Tighten()
	K.Touch()
	if ns.Move then ns.Move.Touch() end
end

-- The tracked bars that show, as a bit per item, last seen. A bar comes and goes with any unit's aura (a debuff on
-- your target is one), not only yours, so the flap is told by this rather than by UNIT_AURA alone. Read only: the
-- viewer's pool is walked, nothing of it is written or hooked. So too when the game lays the column out again
-- with the same bars up: they are back in their own places, off where Stack left them (their anchors' sum).
local barsSeen = 0
local function PollBars()
	local viewer = BuffBarCooldownViewer
	local pool = viewer and viewer.itemFramePool
	if not (pool and pool.EnumerateActive and (flapPlan or plan)) then return end
	local seen, at = 0, stack.at and 0 or nil
	for item in pool:EnumerateActive() do
		if issecretvalue(item) then return end
		local shown = item:IsShown()
		if issecretvalue(shown) then return end
		if shown then
			-- By its place in the column (the pool's order isn't kept).
			seen = seen + 2 ^ min(40, tonumber(item.layoutIndex) or 0)
			if at then
				local _, _, _, x, y = item:GetPoint(1)
				if issecretvalue(x) or issecretvalue(y) or x == nil then at = nil else at = at + 2 * x + y end
			end
		end
	end
	local moved = at ~= nil and abs(at - stack.at) > 0.01
	if seen ~= barsSeen or moved then
		barsSeen = seen
		if moved then stack.at = at end   -- told once, whether or not the bars are fitted again
		K.Buffs()
	end
end

local function PollDisplay()
	PollBars()
	local h, alt, cls = DisplayNow()
	if h == nil then return end
	local was = display.seen
	if was and display.h == h and display.alt == alt and display.cls == cls then return end
	display.seen, display.h, display.alt, display.cls = true, h, alt, cls
	if was then C_Timer.After(0, Redisplay) end
end

-- The wing: the plate grown rightward under a piece that comes and goes. The
-- housing grows, as a hover's does by its foot; K.rect stays the plate without it.

-- The wing's floor at the plate's end the bay is at, its groove on the side that joins the plate.
local function WingSide(side, pixel)
	if wing.side == side and wing.pixel == pixel then return end
	wing.side, wing.pixel = side, pixel
	local left = side == "left"
	wing:ClearAllPoints()
	local inset = FillIn(box)
	wing:SetPoint(left and "TOPLEFT" or "TOPRIGHT", left and inset or -inset, -inset)
	wing:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", left and inset or -inset, inset)
	wing.groove:ClearAllPoints()
	wing.groove:SetWidth(pixel)
	wing.groove:SetPoint(left and "TOPRIGHT" or "TOPLEFT")
	wing.groove:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT")
	wing.lip:ClearAllPoints()
	wing.lip:SetWidth(pixel)
	wing.lip:SetPoint(left and "TOPRIGHT" or "TOPLEFT", left and -pixel or pixel, 0)
	wing.lip:SetPoint(left and "BOTTOMRIGHT" or "BOTTOMLEFT", left and -pixel or pixel, 0)
end

local function Grow()
	local r, bay = drawn or K.rect, plan and plan.strip
	if r and bay then
		WingSide(bay.side, 1 / (plan.ppu or 1))
		local left = bay.side == "left" and r[1] - wingNow or r[1]
		Place(box, { left, r[2], left + r[3] - r[1] + wingNow, r[4] })
		wing:SetShown(wingNow > 0)
		wing:SetWidth(max(1, wingNow))
	end
	if wingRider then wingRider:SetAlpha(wingSpan > 0 and wingNow / wingSpan or 1) end
end

local function Slide(self, elapsed)
	local step = wingSpan * elapsed / SLIDE
	if wingNow < wingWant then wingNow = min(wingWant, wingNow + step) else wingNow = max(wingWant, wingNow - step) end
	Grow()
	if wingNow == wingWant then self:Hide() end
end

local function Gliding(self, elapsed)
	glide.t = min(1, glide.t + elapsed / glide.span)
	local eased = 1 - (1 - glide.t) ^ 3   -- quick off the mark, settling in
	for i = 1, 4 do drawn[i] = glide.from[i] + (glide.to[i] - glide.from[i]) * eased end
	if glide.t >= 1 then
		glide = nil
		self:Hide()
	end
	Grow()
end

-- The plate to rect `r`: gliding there from where it is drawn in `span` seconds (GLIDE unless said), or
-- there at once (`still`: it is dragged, or it was not up).
local function Shape(r, still, span)
	if still or not drawn then
		drawn, glide = { r[1], r[2], r[3], r[4] }, nil
		glider:Hide()
	else
		glide = { from = { drawn[1], drawn[2], drawn[3], drawn[4] }, to = { r[1], r[2], r[3], r[4] }, t = 0, span = span or GLIDE }
		glider:Show()
	end
	Grow()
end

-- The plate reaches over the bay as the plan has it now (a fight's start can change the bay while it is out).
local function Reach()
	local bay = plan and plan.strip
	wingWant = (wingOut and bay) and bay.width or 0
	if wingWant > 0 then wingSpan = wingWant end
	Grow()
	slider:SetShown(wingNow ~= wingWant)
end

function T:CockpitWing(out, rider)
	wingOut = out and true or false
	wingRider = wingOut and rider or nil
	Reach()
end

-- The Shift strip's bay, in UIParent units: as the plate has it now, and as a fight will have it (the rows
-- that wait for one showing), since a fight can start while the strip is up. Each is { side, left, bottom,
-- width, height, cell, at }; `at` is every button's top left corner from the resting bay's top left (x
-- rightward, y downward), the four pings and then the markers. nil while the plate is down.
function T:StripBays()
	if not (K.rect and plan and plan.strip) then return nil end
	local middle = UIParent:GetWidth() / 2
	local rest = plan.strip
	local function Out(bay)
		local out = { side = bay.side, left = bay.left + middle, bottom = bay.bottom, width = bay.width, height = bay.height,
			cell = bay.cell, at = {} }
		local dx, dy = bay.left - rest.left, (rest.bottom + rest.height) - (bay.bottom + bay.height)
		for i, at in ipairs(bay.at) do out.at[i] = { at[1] + dx, at[2] + dy } end
		return out
	end
	local _, now = ns.Layout.Plan()
	return Out(rest), Out(ns.Layout.Fighting(now).strip)
end

-- The tracked bars' flap while a bar is up: beside the plate, the plan's barsWing rect, as tall as the bars that
-- show, joined to the plate by its rib (the plan's rib rect, as tall as the shorter of the two); or, in a home of
-- their own (c.barsApart, a layout by role), from the edge the home keeps (c.barsGrow) round the bars that show,
-- up whether the plate is or not. Fades in; goes at once.
function Flap(c, quiet)
	local r = c.rects.barsWing
	flapPlan = r and c or nil
	if not r or ns.char.loose.bars then
		Fade(flap, false, quiet)
		return
	end
	local l, b, _, t = ns.Layout.RowRect(Rows().bars)
	if l == false then return end   -- secret: as it was
	if not l then
		Fade(flap, false, quiet)
		return
	end
	-- The icon fills the row and the bar fills the icon, so the flap hugs the row. The bottom follows the
	-- bars, and a hidden row under the one that is up leaves no empty band.
	local pixel = 1 / (c.ppu or 1)
	local function Snap(v) return floor(v / pixel + 0.5) * pixel end
	local top = Snap(t + c.m.pad)
	local bottom = Snap(b - c.m.pad)
	local least = c.m.barH + 2 * c.m.pad
	if c.barsApart and c.barsGrow == "down" then
		-- The edge the home keeps stays put, whatever shows: the bars grow away from it.
		top = r[4]
		bottom = min(bottom, top - least)
	elseif c.barsApart then
		bottom = r[2]
		top = max(top, bottom + least)
	elseif top < bottom + c.m.pad then
		top = bottom + c.m.barH + 2 * c.m.pad
	end
	Seat(flap, { r[1], bottom, r[3], top }, quiet)
	local rib, box = c.rects.rib, c.rects.box
	if rib and box then
		-- The rib is the strip between plate and flap, only as tall as they overlap.
		local foot, head = max(bottom, box[2]), min(top, box[4])
		if head < foot then
			foot, head = min(top, box[4]), min(top, box[4]) + c.m.barH
		end
		Place(flap.rib, { rib[1], foot, rib[3], head })
		flap.rib:Show()
	else
		flap.rib:Hide()
	end
end

-- The look is the theme's and ShyCore dresses the housings; what was drawn is only signed, so a change
-- of size or the bars' side is told of (Draw).
local function Dress(c)
	local sign = table.concat({ c.scale or 1, c.barsSide or "" }, " ")
	if dressWas ~= sign then
		dressWas = sign
		return true
	end
	return false
end

-- The look's light (in the top edge, or round the slab) rests out of a fight and brightens in one.
local function LightStrength(quiet)
	local strength = fighting and FIGHT or REST
	for _, f in ipairs({ box, flap }) do
		local h = f.shyLook
		if h then
			for _, light in ipairs({ h.light, h.halo }) do
				if quiet then light:SetAlpha(strength) else Drift(light, strength) end
			end
		end
	end
end

-- A row's light, for a moment. Gold: an essential cooldown ended (the gems'), a form changed (the stances').
-- In `color` (your own): the row came or grew.
function K.Pulse(slot, color)
	if not (K.rect and slot and slot:IsShown()) then return end
	local lit = slot.lit
	if not lit then
		lit = slot:CreateTexture(nil, "OVERLAY")
		lit:SetPoint("TOPLEFT", -2, 2)
		lit:SetPoint("BOTTOMRIGHT", 2, -2)
		lit:SetTexture(Skin.GLOW)
		lit:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
		lit:SetBlendMode("ADD")
		lit:SetAlpha(0)
		lit.fade = lit:CreateAnimationGroup()
		local alpha = lit.fade:CreateAnimation("Alpha")
		alpha:SetFromAlpha(0.85)
		alpha:SetToAlpha(0)
		alpha:SetDuration(PULSE)
		alpha:SetSmoothing("OUT")
		lit.fade:SetScript("OnFinished", function() lit:SetAlpha(0) end)
		slot.lit = lit
	end
	UI.Tint(lit, color or UI.colors.alert, 1)
	lit.fade:Stop()
	lit.fade:Play()
end

-- An essential item's cooldown ends (not a global one): the gems' row lights.
local function Pulsed(item)
	if issecretvalue(item) or pulsing[item] then return end
	local cooldown = item.Cooldown
	if type(cooldown) ~= "table" or not cooldown.HookScript then return end
	pulsing[item] = true
	cooldown:HookScript("OnCooldownDone", function()
		local real = item.isOnActualCooldown
		if not issecretvalue(real) and real and gemsAt then K.Pulse(gems) end
	end)
end

local function PulseEssential()
	local essential = EssentialCooldownViewer
	if not essential then return end
	if essential.itemFramePool and essential.itemFramePool.EnumerateActive then
		for item in essential.itemFramePool:EnumerateActive() do Pulsed(item) end
	elseif essential.items then
		for _, item in ipairs(essential.items) do Pulsed(item) end
	end
end

-- The display's block: one frame round the display's bars and the swing row, which stand a seam apart
-- (Tighten); each seam a hairline of the frame's steel, so the block reads as one piece cut by its own frame.
local SEAM_ALPHA = 0.85

-- One frame round a rect, hairlines of its steel across it (`lines`: rects; b.seams is their pool).
local function Framed(b, rect, lines)
	Place(b, rect)
	b:Show()
	for i, line in ipairs(lines) do
		local t = b.seams[i]
		if not t then
			t = b:CreateTexture(nil, "BORDER", nil, 1)
			b.seams[i] = t
		end
		Theme.Paint(t, Theme.skin.metal, SEAM_ALPHA)
		Place(t, line)
		t:Show()
	end
	for i = #lines + 1, #b.seams do b.seams[i]:Hide() end
end

-- The block, and the cast bar's row while a cast is up: joined to the block (a seam under its last bar,
-- in its frame) or in a frame of its own under what hangs at the plate's foot; in the row a hairline
-- between the spell's picture and the bar. The grid's measures: the frame, the bars and their seams are
-- whole pixels.
local function Block(c, present)
	local b, own = box.shyBlock, box.shyCast
	local d = c.rects.display
	local m = c.m
	local F, seam = m.frame, m.seam
	local castUp = casting and c.casting and c.rects.cast ~= nil
	local joined = castUp and c.castIn == "block" and d ~= nil and present.display
	local function CastLine(lines)
		lines[#lines + 1] = { c.castLeft - c.castGap, c.cast, c.castLeft, c.cast + c.castHeight }
	end
	if castUp and not joined then
		local lines = {}
		CastLine(lines)
		local fresh = not own:IsShown()
		Framed(own, c.rects.cast, lines)
		-- Hanging under the plate, it fades in (the plate has nothing to glide for it).
		if fresh then
			own:SetAlpha(0)
			Drift(own, 1)
		end
	else
		eases[own] = nil
		own:SetAlpha(1)
		own:Hide()
	end
	local sw = c.rects.swing
	if not (d and present.display) then
		-- The slim display of a layout by role (no health or power): the swing row in the block's frame alone.
		if sw and present.swing then
			Framed(b, { sw[1] - F, sw[2] - F, sw[3] + F, sw[4] + F }, {})
		else
			b:Hide()
		end
		return
	end
	local foot = d[2]
	if sw and present.swing then foot = sw[2] end
	if joined then foot = c.cast end
	local lines = {}
	local y = d[4] - m.health
	lines[#lines + 1] = { d[1], y - seam, d[3], y }
	y = y - seam - m.power
	if d[2] < y - seam / 2 then lines[#lines + 1] = { d[1], y - seam, d[3], y } end
	if sw and present.swing then lines[#lines + 1] = { d[1], sw[4], d[3], sw[4] + seam } end
	if joined then
		local top = c.cast + c.castHeight
		lines[#lines + 1] = { d[1], top, d[3], top + seam }
		CastLine(lines)
	end
	Framed(b, { d[1] - F, foot - F, d[3] + F, d[4] + F }, lines)
end

-- Draw everything from plan `c`. quiet: don't fire SHY_COCKPIT for a move, and no easing.
local function Draw(c, quiet)
	local middle = UIParent:GetWidth() / 2
	local r = c.rects.box
	local was = K.rect
	local changed = not (was and was[1] == r[1] and was[2] == r[2] and was[3] == r[3] and was[4] == r[4])
	local present = Present(c)
	local span
	if plan ~= nil and (plan.casting or false) ~= (c.casting or false) then span = c.casting and CAST_OPEN or CAST_CLOSE end
	plan = c
	local dressed = Dress(c)
	if changed then
		K.rect = { r[1], r[2], r[3], r[4] }
		Shape(r, quiet or not box:IsShown(), span)
		Fade(box, true, quiet)
	end
	-- The display's class bar is kept off only while the display is seated.
	Bare(present.display)
	Block(c, present)
	-- The gems' row is measured; the plan's rect is used until the viewer shows, unless the
	-- viewer waits for a fight: then there is no row until it shows.
	local rows = Rows()
	local l, b, rr, t = nil, nil, nil, nil
	-- A loose row stands elsewhere (taken apart, its seat waits empty): the plan's rect, not a measure.
	if present.gems and not ns.char.loose.essential then l, b, rr, t = ns.Layout.RowRect(rows.essential) end
	if not present.gems or (l == nil and later) then
		Fade(gems, false, quiet)
		gemsAt = nil
	else
		local slot = c.rects.gems
		local pad = c.gems - slot[2]
		if l then slot = { l - middle - pad, b - pad, rr - middle + pad, t + pad } end
		Seat(gems, slot, quiet)
		gemsAt = slot
	end
	tilesAt = TileSlot(c, "utility", tilesAt)
	if tilesAt then Seat(tiles, tilesAt, quiet) else Fade(tiles, false, quiet) end
	stancesAt = TileSlot(c, "stances", stancesAt)
	if stancesAt then Seat(stances, stancesAt, quiet) else Fade(stances, false, quiet) end
	-- A row that came (a fight began) or grew (a cooldown or a stance learned) lights for a moment in your color.
	local grown = { gems = gemsAt and gemsAt[3] - gemsAt[1] or 0, tall = gemsAt and gemsAt[4] - gemsAt[2] or 0,
		tiles = tilesAt and tilesAt[3] - tilesAt[1] or 0, stances = stancesAt and stancesAt[3] - stancesAt[1] or 0 }
	if rowsWas and not quiet then
		if grown.gems > rowsWas.gems + 1 or grown.tall > rowsWas.tall + 1 then K.Pulse(gems, Theme.Accent) end
		if grown.tiles > rowsWas.tiles + 1 then K.Pulse(tiles, Theme.Accent) end
		if grown.stances > rowsWas.stances + 1 then K.Pulse(stances, Theme.Accent) end
	end
	rowsWas = grown
	K.blades = c.rects.blades ~= nil   -- ShyRogue draws the blades and their slot
	buffsAt = BuffSlot(c)
	if buffsAt then Seat(buffs, buffsAt, quiet) else Fade(buffs, false, quiet) end
	FitItems(c)
	Flap(c, quiet)
	box:Show()
	-- The Shift strip's bay goes by the plate: it is told when the bay changes, and the plate reaches as far.
	local bay = c.strip
	local bayNow = table.concat({ bay.side, bay.left, bay.bottom, bay.width, bay.height, bay.cell, bay.rows }, " ")
	local bayChanged = bayNow ~= bayWas
	bayWas = bayNow
	Reach()
	local cast = Cast(c)
	if cast or ((changed or dressed or bayChanged) and not quiet) then Tell(true) end
end

-- The plate is down (or not yet up): the tracked bars' home of their own (a layout by role) is drawn all the same,
-- since your bars show out of a fight too; the flap beside the plate goes with it.
local function Apart(c)
	if c and c.barsApart then
		FitItems(c)
		Flap(c)
	else
		Fade(flap, false)
		flapPlan = nil
	end
end

-- `now`, `c`: the plan's inputs and the cockpit's plan, when the caller has just made them from the screen as it
-- stands (Move.Sync, when seating moved nothing); else they are made here.
local function Measured(now, c)
	-- Measured in a fight, the plate is looked at again once it ends (rects can be secret, sizes held).
	if InCombatLockdown() then K.owed = true end
	if not ns.Layout.IsActive() then return Down() end
	later = ns.Layout.CombatOnly("essential")
	if not (now and c) then
		local _
		_, now = ns.Layout.Plan()
		c = ns.Layout.Cockpit(now)
	end
	local held = Held(c)
	if held == nil then
		if not K.rect then return Apart(c) end   -- stay hidden until the seats can be read
	elseif not held then
		Down(c.barsApart)
		return Apart(c)
	end
	Draw(c)
	PulseEssential()
end

function K.Measure() return Measured() end
function K.MeasureFrom(now, c) return Measured(now, c) end

-- Called every frame while the cockpit is dragged (Move.lua).
function K.Follow(c)
	if K.rect then Draw(c, true) end
end

function K.Touch()
	if pending then return end
	pending = true
	C_Timer.After(0, function()
		K.Measure()
	end)
	C_Timer.After(SETTLE, function()
		pending = nil
		K.Measure()
	end)
end

-- Taken apart (Pieces.lua): the plate stays up while its pieces are dragged about.
function K.SetApart(on)
	apart = on and true or false
	K.Measure()
end

function K.Apply()
	for _, f in ipairs({ box, flap }) do UI.SetFill(f, ns.CockpitGraphite) end
	-- Docking or undocking the blades moves the tracked buffs to the other edge; another size or side for
	-- the bars moves every piece.
	local docks = T.db.arrange and T.db.blades
	local vessel = table.concat({ T.db.cockpitScale or 1, T.db.barsSide or "", T.db.swing and 1 or 0, T.db.joined and 1 or 0 }, " ")
	local changed = (docksWas ~= nil and docksWas ~= docks) or (K.vessel ~= nil and K.vessel ~= vessel)
	docksWas, K.vessel = docks, vessel
	if changed then
		-- Every seat moves: the pieces are seated at once (Move.Sync measures the cockpit after), not a frame on.
		ns.Move.Sync()
		ns.Arrange.Soon()
	else
		K.Measure()
	end
end

function T:Cockpit()
	local r = K.rect
	if not r then return nil end
	local middle = UIParent:GetWidth() / 2
	return r[1] + middle, r[2], r[3] + middle, r[4]
end

function T:CockpitHolds(key)
	if K.rect == nil or not INSIDE[key] then return false end
	if key == "blades" then return K.blades == true end
	if key == "cast" then return casting == true end
	if key == "buffs" then return plan ~= nil and plan.buffsIn ~= "over" and not ns.char.loose.buffs end
	if key == "bars" then return plan ~= nil and plan.rects.barsWing ~= nil end
	if key == "swing" then return plan ~= nil and plan.rects.swing ~= nil end
	return not ns.char.loose[key == "essential" and "essential" or key]
end

function T:CockpitCast()
	if not (casting and plan) then return nil end
	return plan.castSide, plan.castGap
end

-- The plan the plate was last drawn from (Pieces.lua's sockets), or nil.
function K.Plan() return plan end

-- Is the cast bar's row held open after a cast, waiting for the next one? (Layout.Casting asks.)
function K.CastHeld()
	return castEnded ~= nil and GetTime() - castEnded < CAST_HOLD
end

-- A housing of the family's make (the bar housing's), in the theme's look; its fill the HUD's graphite,
-- solid when the cockpit doesn't follow the Background setting.
local function Boxed(frame)
	UI.Panel(frame, HOUSING)
	UI.SetFill(frame, ns.CockpitGraphite)
end

-- A row's area: invisible, the gold light's home.
local function Area()
	local slot = CreateFrame("Frame", nil, box)
	slot:SetFrameLevel(box:GetFrameLevel() + 1)
	return slot
end

function K.Start()
	box = CreateFrame("Frame", "ShyDockCockpit", UIParent)
	-- BACKGROUND: under every frame seated in it.
	box:SetFrameStrata("BACKGROUND")
	box:SetFrameLevel(5)
	box:EnableMouse(false)
	box:Hide()
	Boxed(box)
	-- The display's block: its frame. And the cast bar's row's, for when it stands apart from the block.
	local function Steel()
		local f = CreateFrame("Frame", nil, box)
		f:SetFrameLevel(box:GetFrameLevel() + 1)
		f.frame = f:CreateTexture(nil, "BORDER")
		f.frame:SetAllPoints()
		f.frame:SetTexture(Skin.FRAME)
		f.frame:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
		Theme.Tint(f.frame, Theme.skin.metal)
		f.seams = {}
		f:Hide()
		return f
	end
	box.shyBlock = Steel()
	box.shyCast = Steel()
	K.frame = box

	gems = Area()
	K.gems = gems
	tiles = Area()
	tiles:Hide()
	K.tiles = tiles
	stances = Area()
	stances:Hide()
	K.stances = stances
	buffs = Area()
	buffs:Hide()
	K.buffs = buffs

	-- The wing's floor: as wide as has slid out, darker than the plate, with a groove where it joins.
	wing = CreateFrame("Frame", nil, box)
	local inset = FillIn(box)
	wing:SetPoint("TOPRIGHT", -inset, -inset)
	wing:SetPoint("BOTTOMRIGHT", -inset, inset)
	wing:SetWidth(1)
	wing:Hide()
	wing.floor = wing:CreateTexture(nil, "BACKGROUND")
	wing.floor:SetAllPoints()
	wing.floor:SetColorTexture(0, 0, 0, 0.30)
	wing.groove = wing:CreateTexture(nil, "BORDER")
	wing.groove:SetWidth(1)
	wing.groove:SetPoint("TOPLEFT")
	wing.groove:SetPoint("BOTTOMLEFT")
	wing.groove:SetColorTexture(0, 0, 0, 0.85)
	wing.lip = wing:CreateTexture(nil, "BORDER")
	wing.lip:SetWidth(1)
	wing.lip:SetPoint("TOPLEFT", 1, 0)
	wing.lip:SetPoint("BOTTOMLEFT", 1, 0)
	wing.lip:SetColorTexture(1, 1, 1, 0.07)
	K.wing = wing
	slider = CreateFrame("Frame")
	slider:Hide()
	slider:SetScript("OnUpdate", Slide)
	K.slider = slider
	glider = CreateFrame("Frame")
	glider:Hide()
	glider:SetScript("OnUpdate", Gliding)
	K.glider = glider

	-- The tracked bars' flap: the plate's make, beside it, and its rib; or their home of their own in a layout by
	-- role, which shows with the plate down too. Its own frame, hidden with the plate where it is the plate's (Down).
	flap = CreateFrame("Frame", "ShyDockCockpitBars", UIParent)
	flap:SetFrameStrata(box:GetFrameStrata())
	flap:SetFrameLevel(box:GetFrameLevel())
	flap:EnableMouse(false)
	flap:Hide()
	Boxed(flap)
	flap.rib = flap:CreateTexture(nil, "BORDER")
	flap.rib:SetTexture(UI.RIB, "REPEAT", "REPEAT")
	flap.rib:SetVertTile(true)
	Theme.Tint(flap.rib, Theme.skin.metal)
	flap.rib:Hide()
	K.flap = flap

	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:RegisterUnitEvent("UNIT_AURA", "player")   -- every nameplate and raid member would wake it otherwise
	-- The frames a fight can show or hide by their own settings (Layout.FightShows): the vessel's rows and the
	-- totems, but for those whose showing and hiding is followed already (hooked below: the essential and utility
	-- cooldowns, the display, the cast bar).
	local HOOKED = { EssentialCooldownViewer = true, UtilityCooldownViewer = true, PersonalResourceDisplayFrame = true,
		PlayerCastingBarFrame = true }
	local rowFrames = { "MultiCastActionBarFrame" }
	for _, def in ipairs(ns.Layout.ROWS) do
		for _, name in ipairs({ def.frame, def.stead }) do
			if not HOOKED[name] then rowFrames[#rowFrames + 1] = name end
		end
	end
	driver:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
			fighting = event == "PLAYER_REGEN_DISABLED"
			LightStrength()
			-- The plate is drawn again only where the fight's edge changes it: a row shown in fights only, or
			-- after a fight that drew it while the game kept rects to itself and the cast bar's size could not be set.
			local owed = K.owed
			K.owed = nil
			if not (ns.Layout.FightShows(rowFrames) or (not fighting and owed)) then return end
		elseif event == "UPDATE_SHAPESHIFT_FORM" then
			if stancesAt then K.Pulse(stances) end
			return
		elseif event == "UNIT_AURA" then
			K.Buffs()
			return
		end
		K.Touch()
	end)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", K.Touch, K)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		driver:SetScript("OnUpdate", K.Measure)
	end, K)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		driver:SetScript("OnUpdate", nil)
		K.Touch()
	end, K)
	-- A look dressed anew rests its light; a fight already on brightens it again.
	Shy:On("SHY_THEME", function() LightStrength(true) end)
	-- Move.Sync measures the plate from the plan it seats the pieces by: a sync due next frame is the plate's
	-- measure too, and the plate isn't planned twice in a frame. With only a settle's sync to come, it is measured itself.
	local function Changed()
		if ns.Move and ns.Move.Touch() == true and ns.Layout.IsActive() then return end
		K.Touch()
	end
	EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
		C_Timer.After(0, Changed)
	end, K)
	local function SoonChanged()
		C_Timer.After(0, Changed)
	end
	for _, viewer in ipairs({ EssentialCooldownViewer, UtilityCooldownViewer }) do
		if viewer then
			viewer:HookScript("OnShow", SoonChanged)
			viewer:HookScript("OnHide", SoonChanged)
		end
	end
	PulseEssential()
	local display = PersonalResourceDisplayFrame
	if display then
		display:HookScript("OnShow", K.Touch)
		display:HookScript("OnHide", K.Touch)
		PollDisplay()   -- as it stands now: only a change from this is acted on
	end
	C_Timer.NewTicker(POLL, PollDisplay)
	-- SetLook resets the cast bar's size: remember the new original, then size it again. A cast beginning
	-- opens the bar's row in the plate at once (the plate grows down round it, quickly); the cast over (the
	-- bar fading, PlayFadeAnim, or hidden) closes it after a moment's hold, unless another cast has begun.
	local bar = PlayerCastingBarFrame
	if bar then
		-- The row opening or closing seats the foot row again (it rides the plate's foot): Changed, not Touch.
		bar:HookScript("OnShow", function()
			if casting then SizeCast(plan) end
			castEnded = nil
			Changed()
		end)
		-- A cast's end (the fade, or a hide with no fade) starts the hold, and the close after it; while one
		-- runs, the fade's hide does not start another. A hide after the row has closed is nothing: the row
		-- must not open again, empty. A cast begun while the last bar still fades ends into a hold of its own.
		local function Ended()
			if not (plan and plan.casting) then return end
			if castEnded and GetTime() - castEnded < CAST_HOLD then return end
			castEnded = GetTime()
			C_Timer.After(CAST_HOLD + 0.05, Changed)
		end
		bar:HookScript("OnHide", Ended)
		if bar.PlayFadeAnim then hooksecurefunc(bar, "PlayFadeAnim", Ended) end
		hooksecurefunc(bar, "SetLook", function(self)
			if castWas then castWas = { self:GetWidth(), self:GetHeight() } end
			if casting then SizeCast(plan) end
		end)
	end
end
