-- Drawers: a piece of the screen that slides out of a pull and tucks away into it.
--
-- A drawer is a set of frames (the game's or ours) standing in a bay, a pull beside the bay, and a
-- panel of the console's make behind the frames that slides. The pull is on the bay's `side`, the edge
-- the drawer tucks toward: a drawer with its pull on the left slides out rightward and back leftward,
-- one with its pull on top slides down and back up. Tucked, only the pull shows. An upright pull is a
-- handle of steel in its middle (the rest takes the mouse unseen), a level one a strip saying what the
-- drawer holds; a level one at a grip of its own is the header of the panel, a console piece's, and folds as
-- every piece does (UI.FoldHead: its title, the caret after it pointing down while pinned out and onward while
-- tucked, the strip lit under the mouse); tucked, the panel is that header alone, UI.FOLDED tall, with no line
-- under it. The other pulls carry a chevron pointing the way a click sends the drawer.
-- Pointing at the pull slides the drawer out (the panel grows from that edge, the frames fade in as
-- it covers them); off the drawer it slides back after a moment. Clicking the pull pins the drawer
-- out, clicking again tucks it, and a drawer just tucked stays tucked until the mouse has left it.
-- The pin is kept per Edit Mode layout, beside Shy's pieces (ShyCoreDB.hud, the active layout's
-- table: Editor.lua switches it, Edit Mode's Revert puts it back).
--
--   Shy.Drawer.Create{ id, title, side = "top" | "bottom" | "left" | "right", default = "open" | "tucked",
--                      frames = { frame, ... } | function() return { ... } end,
--                      rect = function() return left, bottom, right, top end,   -- the bay, UIParent units; nil:
--                                                                                -- nothing to show; false: secret, keep
--                      grip = function() return left, bottom, right, top end,   -- where the pull stands; without one
--                                                                                -- it is a strip inside the bay's side
--                      near = function() return true end,   -- the pull shows only while this says so (or the mouse
--                                                           -- is on the pull or the drawer); without one, always
--                      housing = frame | nil,   -- a panel of the caller's over the bay, kept out of sight
--                                               -- while the drawer draws its own, sliding one
--                      over = true,             -- the drawer slides out over other pieces: its panel stands over
--                                               -- them, solid while it does (pinned or held out it has room
--                                               -- of its own, and the opacity setting's fill)
--                      pad = 5,                 -- the panel's reach past the bay (0: the bay is the panel)
--                      held = function() return false end,     -- true: out always, with no pull (a switch of
--                                                              -- the caller's turned the drawer off)
--                      paneled = function() return true end,   -- false: no panel is drawn
--                      help = "...",            -- a sentence for the pull's hover
--                      carry = box,             -- a Shy.HUD box the pull drags, like a window's title bar
--                                               -- (a click that ends a drag leaves the drawer as it is)
--                      catch = function() return true end,     -- false: no catcher is needed (the caller has put
--                                                              -- the frames out of the mouse's way itself)
--                      onOut = function(d) end,       -- the drawer starts out of its pull (before anything shows)
--                      onTucked = function(d) end,    -- the drawer is all the way in
--                      shown = function() return true end }   -- whether the drawer is in use at all
--   d:Touch()        measure again next frame and once settled (the frames laid out, a layout applied)
--   d:Apply()        measure now and show the drawer's state, with no motion
--   d:Sync()         measure now, keeping the drawer as it is (mid-slide, out under the mouse); its state is
--                    shown afresh only when it comes into use or goes out of it
--   d:SetShown(on)   off: the frames and the caller's panel get their own alpha back and the pull goes
--   d:IsOpen()       pinned out
--   d:Pin(open)      pin it out or tuck it, and keep that for this layout
--   d:Toggle()
--   Shy.Drawer.Find(id)   Shy.Drawer.SetDefault(id, mode)   Shy.Drawer.Reset(id, mode)   Shy.Drawer.ApplyAll()
--   Shy.Drawer.Holding(frame)   the drawer in use that holds this frame (or a frame it is in) and shows a pull,
--                    and that pull: what points at something a drawer may tuck away points at its pull
--   Shy.Drawer.Tick(dt)   a moment passes (the driver's OnUpdate)
-- Bus: "SHY_DRAWER" (id, open) when a drawer is pinned or tucked.
--
-- Rules. A frame is faded with SetAlpha and nothing else: never shown, hidden, moved or reparented,
-- so a protected frame (an action bar) can be in a drawer and tucked in a fight; what moves is the
-- drawer's own panel. While its frames are out of sight a catcher of ours lies over the bay, so no
-- button nobody can see is clicked. The pull, the catcher and the panel are plain frames placed by
-- coordinates, never anchored to a frame of the game's. A frame is in one fader: a drawer's frames
-- are not Immersion's pieces (its fade of UIParent multiplies into theirs by itself). The frames'
-- own alpha is followed through a post-hook on SetAlpha and laid under the drawer's, as Immersion
-- does. In Edit Mode and in layout mode every drawer is out. Keys still press what a tucked drawer holds.

local Shy = Shy
local UI, Theme = Shy.UI, Shy.Theme
local C = UI.colors
local max, min = math.max, math.min

local D = {}
Shy.Drawer = D

D.STRIP = 12            -- the pull's thickness
D.PIN = 30              -- a pull with no grip of its own: the tab's length while pinned out
D.LINGER = 0.6          -- seconds the drawer stays out after the mouse leaves it
D.OUT, D.BACK = 0.18, 0.15    -- seconds to slide out and to slide back
D.SHOW, D.HIDE = 0.12, 0.25   -- seconds for a pull to come up and to go
local PAD = 5           -- the panel's reach past the bay, unless the caller says
local SETTLE = 0.3      -- the frames have laid out by now
local STEP = 0.02       -- the driver looks this often while anything is under way
local REST = 0.25       -- ... and this often with every drawer at rest and the mouse still
local resting = false   -- every drawer at rest, as the last step left them
local stirred = false   -- something was said to a drawer since: looked at on the next frame, mouse or no

local drawers, order = {}, {}
local fading = {}       -- frame -> the drawer fading it
local base = {}         -- frame -> its own alpha, the one its owner set
local hooked = {}       -- frames whose SetAlpha is followed
local overrides = {}    -- id -> "open" | "tucked", set by an addon over the drawer's own default
local writing = false
local editing, unlocked = false, false
local covered = false   -- the world map has the whole screen (Shy.HUD's SHY_HUD_COVERED)
local driver

local function Shown(frame)
	if type(frame) ~= "table" or not frame.IsShown then return false end
	local shown = frame:IsVisible()
	return not issecretvalue(shown) and shown == true
end

local function Over(frame)
	if not Shown(frame) or not frame.IsMouseOver then return false end
	local over = frame:IsMouseOver()
	return not issecretvalue(over) and over == true
end

-- The slide, eased: out quick and settling.
local function Ease(p)
	return 1 - (1 - p) * (1 - p)
end

-- The frames come up over the second half of the slide, once the panel is under them.
local function Fade(p)
	if p <= 0.5 then return 0 end
	return (p - 0.5) * 2
end

-- (Kept on the drawer: read at every step, and joined each time it was a string made and thrown away.)
local function Key(d)
	local key = d.key
	if not key then
		key = "drawer:" .. d.id
		d.key = key
	end
	return key
end

local function Saved(d)
	local hud = Shy.core and Shy.core.db and Shy.core.db.hud
	return hud and hud[Key(d)]
end

-- Pinned out: as saved for this layout, else as the addon or the drawer itself says.
local function Pinned(d)
	local saved = Saved(d)
	if saved and saved.open ~= nil then return saved.open == true end
	return (overrides[d.id] or d.default) == "open"
end

local function Held(d)
	return d.held ~= nil and d.held() == true
end

-- Under the world map at full screen (covered) every drawer is away: tucked, with no pull.
local function Out(d)
	return not covered and (Pinned(d) or editing or unlocked or Held(d))
end

-- A level pull standing at a grip of its own is the header of the panel's housing: the panel runs from the
-- pull's far edge and is exactly as wide as the pull, the pull's rect alone while tucked, so the two are one
-- piece (the pull's own housing steps aside, Paint). Held out there is no pull, and the panel is the bay's
-- alone, its header put away.
local function Joined(d)
	return d.gripRect ~= nil and (d.side == "top" or d.side == "bottom") and not Held(d)
end

-- The panel slid out `p` of the way from the pull's edge across the bay.
local function Slide(d, p)
	local panel, l, b, r, t = d.panel, d.bay[1], d.bay[2], d.bay[3], d.bay[4]
	local side, k = d.side, Ease(p)
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	local pad = d.pad
	local pl, pb, pr, pt
	if Joined(d) then
		local g = d.gripRect
		pl, pr = g[1], g[3]
		if side == "top" then
			pt, pb = g[4], g[2] - (g[2] - (b - pad)) * k
		else
			pb, pt = g[2], g[4] + (t + pad - g[4]) * k
		end
	else
		if side == "left" then r = l + (r - l) * k
		elseif side == "right" then l = r - (r - l) * k
		elseif side == "top" then b = t - (t - b) * k
		else t = b + (t - b) * k end
		pl, pb, pr, pt = l - pad, b - pad, r + pad, t + pad
	end
	pl, pb, pr, pt = max(0, pl), max(0, pb), min(W, pr), min(H, pt)
	panel:ClearAllPoints()
	panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", pl, pb)
	panel:SetSize(max(1, pr - pl), max(1, pt - pb))
	-- The frames are the panel's content (a look with a well sinks them, its rim round them), never nearer an
	-- edge than they stand out (so the rim keeps its width while the panel slides). Headed by the pull, the
	-- panel's head and its well are the look's zones instead.
	local h, holds, bay = d.panel.shyLook, d.holds, d.bay
	if holds and not Joined(d) then
		-- Out all the way the panel is the bay and its pad: how far in the frames stand then, on each side.
		local ol, ob = holds[1] - max(0, bay[1] - pad), holds[2] - max(0, bay[2] - pad)
		local orr, ot = min(W, bay[3] + pad) - holds[3], min(H, bay[4] + pad) - holds[4]
		-- (One table a drawer, written over each step: a slide is many steps.)
		local keep = d.keepIn or {}
		d.keepIn = keep
		keep[1], keep[2], keep[3], keep[4] = max(holds[1] - pl, ol), max(pt - holds[4], ot), max(pr - holds[3], orr), max(holds[2] - pb, ob)
		UI.LookContent(h, keep)
	else
		UI.LookContent(h, nil)
	end
	-- Headed by the pull, the panel is the pull's housing too: there while the pull is, slid out or not; its line
	-- comes with the content under it, so tucked it is the header alone (UI.FoldLine).
	if Joined(d) then
		panel:SetAlpha(p > 0.001 and 1 or d.reveal)
		panel:SetShown(p > 0.001 or d.reveal > 0)
		UI.FoldLine(panel, p > 0.001)
	else
		panel:SetAlpha(1)
		panel:SetShown(p > 0.001 and (d.paneled == nil or d.paneled() == true))
	end
end

-- The frames' alpha: their own, times how far the drawer is out; the panel slid that far.
local function Paint(d)
	local fade = Fade(d.level)
	writing = true
	for _, frame in ipairs(d.list) do frame:SetAlpha((base[frame] or 1) * fade) end
	if d.house then d.house:SetAlpha(0) end
	writing = false
	if d.bay then Slide(d, d.level) end
	-- Joined to the panel, the pull's housing gives way to the panel's: one piece.
	if d.pull.plate then d.pull.plate:SetShown(not (d.bay ~= nil and Joined(d))) end
	-- No catcher under the full-screen map: it would lie over the map and take the map's clicks.
	d.catcher:SetShown(d.bay ~= nil and fade <= 0 and not covered and (d.catch == nil or d.catch() == true))
end

-- Says so when the drawer starts out of its pull, and when it is all the way in.
local function Tell(d)
	local out = d.want == true or d.level > 0
	if out == d.told then return end
	d.told = out
	local fn = out and d.onOut or d.onTucked
	if fn then fn(d) end
end

-- An owner setting its frame's alpha while it is in a drawer: kept as the frame's own, the drawer laid over it.
-- (Only that frame is laid again: the panel, the pull and the catcher stand as they did. The game sets a bar's
-- alpha again and again, and each time the whole drawer was painted and its panel's look fitted anew.)
local function Followed(frame, a)
	if writing or issecretvalue(a) then return end
	base[frame] = a
	local d = fading[frame]
	if not d then return end
	local to = a * Fade(d.level)
	if frame == d.house then to = 0 end
	if to == a then return end
	writing = true
	frame:SetAlpha(to)
	writing = false
end

local function Follow(frame, d)
	if fading[frame] == d then return end
	fading[frame] = d
	if not hooked[frame] then
		hooked[frame] = true
		local a = frame:GetAlpha()
		base[frame] = (a == nil or issecretvalue(a)) and 1 or a
		hooksecurefunc(frame, "SetAlpha", Shy.Clocked("drawer: a frame's alpha set", Followed))
	end
end

-- A frame let out of a drawer gets its own alpha back.
local function Release(frame)
	fading[frame] = nil
	writing = true
	frame:SetAlpha(base[frame] or 1)
	writing = false
end

-- A pull's chevron points the way a click sends the drawer: out of the pull, or back into it while pinned.
-- An upright pull is a handle of steel standing in the seam (PullRim, PullFill: 10 x 40 at two texels a unit).
local KNOB_W, KNOB_H = 10, 40
local CARET, CARET_STRIP = 14, 10   -- the caret's triangle fills only the middle of its file
local TURN = { right = math.pi / 2, left = -math.pi / 2, up = math.pi, down = 0 }
local AWAY = { left = "right", right = "left", top = "down", bottom = "up" }
local BACK = { left = "left", right = "right", top = "up", bottom = "down" }

local function Look(pull, over)
	if pull.rim then
		UI.Tint(pull.rim, over and C.hot or Theme.skin.metal)
	else
		UI.SetBorder(pull.plate, over and C.hot or Theme.skin.metal)
	end
	UI.Tint(pull.caret, over and Theme.skin.lit or Theme.skin.glyph)
end

-- The pull's light: a line along the edge facing the drawer, lit while the drawer is pinned out.
local function Light(d)
	local light, side = d.pull.light, d.side
	if not light then return end
	light:ClearAllPoints()
	if side == "top" then
		light:SetPoint("BOTTOMLEFT", 2, 1)
		light:SetPoint("BOTTOMRIGHT", -2, 1)
		light:SetHeight(1)
	elseif side == "bottom" then
		light:SetPoint("TOPLEFT", 2, -1)
		light:SetPoint("TOPRIGHT", -2, -1)
		light:SetHeight(1)
	elseif side == "left" then
		light:SetPoint("TOPRIGHT", -1, -2)
		light:SetPoint("BOTTOMRIGHT", -1, 2)
		light:SetWidth(1)
	else
		light:SetPoint("TOPLEFT", 1, -2)
		light:SetPoint("BOTTOMLEFT", 1, 2)
		light:SetWidth(1)
	end
end

-- The panel of a drawer that slides out over other pieces is solid only while it is over them: out for
-- good (pinned, or held out), or a header tucked in, it stands in room of its own, as see-through as
-- every other panel.
local function Ground(d)
	if not d.over then return end
	local roomy = Pinned(d) or Held(d) or (d.headed ~= nil and d.level <= 0)
	if roomy == d.roomy then return end
	d.roomy = roomy
	if d.panel.shyStrip then d.panel.shyStripColor = roomy and C.hudStrip or C.bgHot end
	UI.Panel(d.panel, { fill = roomy and C.hud or C.panel })
end

-- The pull: at its grip, or a strip inside the bay's side (a tab at the strip's end while pinned).
local function Dress(d)
	Ground(d)
	local pull, side, pinned = d.pull, d.side, Pinned(d)
	local upright = side == "left" or side == "right"
	local tall   -- an upright pull's height, for its handle
	pull:ClearAllPoints()
	-- (d.at: where the pull stands, left, bottom, right, top on the screen, for Lidded.)
	local at, bay = d.at, d.bay
	if d.gripRect then
		local g = d.gripRect
		pull:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", g[1], g[2])
		pull:SetSize(g[3] - g[1], g[4] - g[2])
		tall = g[4] - g[2]
		at[1], at[2], at[3], at[4] = g[1], g[2], g[3], g[4]
	elseif upright then
		pull:SetWidth(D.STRIP)
		pull:SetPoint(side == "left" and "TOPLEFT" or "TOPRIGHT")
		if pinned then pull:SetHeight(D.PIN) else pull:SetPoint(side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT") end
		tall = pinned and D.PIN or (bay[4] - bay[2])
		local left = side == "left" and bay[1] or bay[3] - D.STRIP
		at[1], at[2], at[3], at[4] = left, bay[4] - tall, left + D.STRIP, bay[4]
	else
		pull:SetHeight(D.STRIP)
		if pinned then
			pull:SetWidth(D.PIN)
			pull:SetPoint(side == "top" and "TOPRIGHT" or "BOTTOMRIGHT")
		else
			pull:SetPoint(side == "top" and "TOPLEFT" or "BOTTOMLEFT")
			pull:SetPoint(side == "top" and "TOPRIGHT" or "BOTTOMRIGHT")
		end
		local foot = side == "top" and bay[4] - D.STRIP or bay[2]
		at[1], at[2], at[3], at[4] = pinned and bay[3] - D.PIN or bay[1], foot, bay[3], foot + D.STRIP
	end
	pull.caret:SetRotation(TURN[(pinned and BACK or AWAY)[side]])
	if upright then
		pull.fill:SetHeight(min(KNOB_H, max(1, tall - 4)))
		return
	end
	-- Heading the panel, the pull is the piece's header: the panel's strip and line (put away while there is
	-- none to head), the title and the chevron on its middle as on every piece.
	local joined = Joined(d)
	if d.headed and joined ~= d.joined then
		d.joined = joined
		UI.PanelHead(d.panel, joined)
		UI.LookZones(d.panel.shyLook, joined and d.headed or 0)
	end
	pull.caret:ClearAllPoints()
	if d.fold then
		d.fold:SetShown(joined)
		d.fold:Set(pinned)
	end
	pull.caret:SetShown(not joined)
	pull.label:SetShown(not joined)
	if joined then
		pull.light:Hide()
		return
	end
	-- A strip says what it holds; the short tab of a pinned one has room for the chevron alone.
	pull.caret:SetSize(CARET_STRIP, CARET_STRIP)
	local text = (pinned and not d.gripRect) and "" or d.title
	pull.label:SetText(text)
	UI.Ink(pull.label, pinned and C.head or C.text)
	if text == "" then pull.caret:SetPoint("CENTER") else pull.caret:SetPoint("RIGHT", -3, 0) end
	pull.light:SetShown(pinned)
end

-- Where the bay is now, and the handle over it.
-- Where the drawer's frames stand, all together: { left, bottom, right, top } in UIParent units, or nil (none on
-- screen, or a rect the game keeps to itself).
local function Holds(d)
	local originX, originY = UIParent:GetScaledRect()
	local scale = UIParent:GetEffectiveScale()
	local function Known(...)
		for i = 1, select("#", ...) do
			local v = select(i, ...)
			if v == nil or issecretvalue(v) then return false end
		end
		return true
	end
	if not Known(originX, originY, scale) then return nil end
	local out
	for _, frame in ipairs(d.list) do
		if Shown(frame) then
			local left, bottom, width, height = frame:GetScaledRect()
			if not Known(left, bottom, width, height) then return nil end
			local l, b = (left - originX) / scale, (bottom - originY) / scale
			local r, t = l + width / scale, b + height / scale
			out = out and { min(out[1], l), min(out[2], b), max(out[3], r), max(out[4], t) } or { l, b, r, t }
		end
	end
	return out
end

local function Measure(d)
	stirred = true
	if not d.on then return end
	local frames = type(d.frames) == "function" and d.frames() or d.frames
	local keep = {}
	for _, frame in ipairs(frames or {}) do
		if type(frame) == "table" then
			keep[frame] = true
			Follow(frame, d)
		end
	end
	for i = #d.list, 1, -1 do
		if not keep[d.list[i]] then Release(d.list[i]) end
	end
	wipe(d.list)
	for _, frame in ipairs(frames or {}) do
		if type(frame) == "table" then d.list[#d.list + 1] = frame end
	end
	if type(d.housing) == "table" and d.house ~= d.housing then
		if d.house then Release(d.house) end
		d.house = d.housing
		Follow(d.house, d)
	end
	local l, b, r, t = d.rect()
	if l == false then return end   -- secret: the handle stays where it was
	-- Clamped to the screen, like the console's housings.
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	if l ~= nil then l, b, r, t = max(0, l), max(0, b), min(W, r), min(H, t) end
	if l == nil or #d.list == 0 or r - l < 1 or t - b < 1 then
		d.bay, d.gripRect = nil, nil
		d.handle:Hide()
		d.panel:Hide()
		return
	end
	d.bay = { l, b, r, t }
	d.holds = Holds(d)
	d.gripRect = nil
	if d.grip then
		local gl, gb, gr, gt = d.grip()
		if gl then d.gripRect = { gl, gb, gr, gt } end
	end
	d.handle:ClearAllPoints()
	d.handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", l, b)
	d.handle:SetSize(r - l, t - b)
	d.handle:Show()
	Dress(d)
	Paint(d)
end

-- How much of the pull shows.
local function Reveal(d, reveal)
	d.reveal = reveal
	d.pull:SetAlpha(reveal)
	d.pull:EnableMouse(reveal > 0 and not d.yields)
	if d.bay and Joined(d) then Slide(d, d.level) end   -- the header is the panel's: it comes and goes with the pull
end

-- A window lies over the pieces of the screen, a drawer with them; the pull and the catcher stand a layer
-- above it, over the game's frames. So the mouse on a window is on nothing of a drawer's (Shy.HUD.OverWindow):
-- its catcher and its pull let the mouse through to the window, and it does not come out for it.
local function Yield(d, on)
	d.yields = on or nil
	d.catcher:EnableMouse(not on)
	d.pull:EnableMouse(d.reveal > 0 and not on)
end

-- And a pull a window lies over is away while it does: it would be drawn across the window.
local function Lidded(d)
	local at = d.at
	return at[1] ~= nil and Shy.HUD.WindowOn(at[1], at[2], at[3], at[4])
end

-- A moment passes: every drawer slides out under the mouse on its pull (or pinned, or while the screen
-- is being arranged), stays out while the mouse is on it, and slides back a moment after. One just
-- tucked by its pull waits for the mouse to leave. A pull with a `near` shows only while that says so.
-- Returns whether anything is under way (a drawer sliding or waiting to slide back, a pull coming or going, the
-- mouse on one, a piece in hand): with nothing, the driver looks again only as the mouse moves, or now and then.
function D.Tick(dt)
	if covered then return false end   -- away, as ApplyAll left them
	local busy = false
	-- (While the screen is being arranged every drawer is out and its pull is the arranging's.)
	local arranging = editing or unlocked
	local windowed = not arranging and Shy.HUD.OverWindow()
	-- A piece dragged, or sized by a handle (the quest card's foot drawn down over the menu's pull): the mouse is
	-- that piece's until it is let go. A drawer goes on to where it was going, and neither comes out nor is let
	-- go of for a mouse that only passes over it; no pull comes up for it either.
	local inHand = not arranging and Shy.HUD.InHand()
	for _, d in ipairs(order) do
		if d.on and d.bay then
			if windowed ~= (d.yields == true) then Yield(d, windowed) end
			local hover, want = false, d.want == true
			if not inHand then
				hover = not windowed and d.reveal > 0 and Over(d.pull)
				if not hover and not windowed and d.level > 0 then
					hover = Over(d.panel)
					for _, frame in ipairs(d.list) do
						if hover then break end
						hover = Over(frame)
					end
				end
				if d.asleep and not hover then d.asleep = nil end
				want = Out(d) or (hover and not d.asleep)
			end
			local level = d.level
			if want then
				d.linger = nil
				level = min(1, level + dt / D.OUT)
			else
				d.linger = (d.linger or 0) + dt
				if d.linger >= D.LINGER then level = max(0, level - dt / D.BACK) end
			end
			if want ~= d.want or level ~= d.level then
				d.want, d.level = want, level
				Tell(d)
				Dress(d)
				Paint(d)
				busy = true
			end
			-- (On its way out, or out with nothing holding it: it slides back once its moment is up.)
			if inHand or (want and level < 1) or (not want and level > 0) then busy = true end
			-- The pull: none while the drawer is held out, always while the screen is arranged, none under a window;
			-- else while it has nothing to be near, or is near it (as it was, while a piece is in hand: nil).
			local near
			if Held(d) then
				near = false
			elseif arranging then
				near = true
			elseif Lidded(d) then
				near = false
			elseif d.near == nil then
				near = true
			elseif not inHand then
				near = hover or d.near() == true
			end
			if near ~= nil then
				local reveal = near and min(1, d.reveal + dt / D.SHOW) or max(0, d.reveal - dt / D.HIDE)
				if reveal ~= d.reveal then
					Reveal(d, reveal)
					busy = true
				end
			end
		end
	end
	return busy
end

local Drawer = {}
Drawer.__index = Drawer

function Drawer:Measure() Measure(self) end

function Drawer:Touch()
	if self.pending then return end
	self.pending = true
	C_Timer.After(0, function() Measure(self) end)
	C_Timer.After(SETTLE, function()
		self.pending = nil
		Measure(self)
	end)
end

-- The drawer's state as it stands, with no motion: out while pinned (or the screen is being arranged), else tucked.
function Drawer:Apply()
	self.on = self.shownFn == nil or self.shownFn() == true
	if not self.on then
		self:SetShown(false)
		return
	end
	self.want = Out(self)
	self.level = self.want and 1 or 0
	self.linger, self.asleep = nil, nil
	Reveal(self, (covered or Held(self)) and 0 or (self.near == nil or editing or unlocked) and 1 or self.reveal)
	Tell(self)
	Measure(self)
end

function Drawer:Sync()
	local on = self.shownFn == nil or self.shownFn() == true
	if on ~= self.on then self:Apply() else Measure(self) end
end

function Drawer:SetShown(on)
	on = on and true or false
	if on then
		self.on = true
		self:Apply()
		return
	end
	self.on = false
	stirred = true
	for _, frame in ipairs(self.list) do Release(frame) end
	wipe(self.list)
	if self.house then
		Release(self.house)
		self.house = nil
	end
	self.bay, self.gripRect = nil, nil
	self.handle:Hide()
	self.panel:Hide()
	self.want, self.level = true, 1   -- no drawer: its frames are simply there
	Tell(self)
end

function Drawer:IsOpen() return Pinned(self) end

-- Pinned out or tucked by hand: the drawer slides there from where it is.
function Drawer:Pin(open)
	local hud = Shy.core and Shy.core.db and Shy.core.db.hud
	if hud then hud[Key(self)] = { open = open and true or false } end
	self.want = Out(self)
	self.asleep = not self.want or nil   -- tucked by hand: it stays so until the mouse leaves it
	self.linger = D.LINGER
	stirred = true
	Tell(self)
	if self.bay then Dress(self) end   -- nothing on screen: dressed when it is measured there
	Shy:Fire("SHY_DRAWER", self.id, Pinned(self))
end

function Drawer:Toggle() self:Pin(not Pinned(self)) end

local function Start()
	if driver then return end
	driver = CreateFrame("Frame")
	local waited = 0
	local cx, cy
	local tick = Shy.Clocked("drawer: each step", function(dt) return D.Tick(dt) end)
	-- With every drawer at rest nothing changes but by the mouse (onto a pull, off a drawer) or by something said
	-- to a drawer (Stir): it is looked at as the mouse moves, and every REST seconds for what comes without it (a
	-- window opened under the mouse, a frame of a drawer's shown).
	driver:SetScript("OnUpdate", function(_, elapsed)
		waited = waited + elapsed
		if waited < STEP then return end
		local dt = waited
		if resting then
			local x, y = GetCursorPosition()
			if not stirred and x == cx and y == cy and waited < REST then return end
			cx, cy = x, y
			-- (Its first step after a rest is one step long: a drawer woken slides, it doesn't leap.)
			dt = STEP
		end
		stirred = false
		resting = not tick(dt)
		waited = 0
	end)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		editing = true
		D.ApplyAll()
	end, D)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		editing = false
		D.ApplyAll()
	end, D)
	Shy:On("SHY_HUD_LAYOUT", function(on)
		unlocked = on and true or false
		D.ApplyAll()
	end)
	Shy:On("SHY_HUD_COVERED", function(on)
		covered = on and true or false
		D.ApplyAll()
	end)
	-- Another layout's table, or one put back (Editor.lua's Follow and Revert, HUD.ResetAll): the pins re-read.
	hooksecurefunc(Shy.HUD.Act, "ApplyAll", D.ApplyAll)
	hooksecurefunc(Shy.HUD, "ResetAll", D.ApplyAll)
end

function D.Create(def)
	assert(def and def.id and not drawers[def.id], "a drawer needs an id of its own")
	Start()
	local d = setmetatable({
		id = def.id, title = def.title or "", side = def.side or "top", default = def.default or "tucked",
		frames = def.frames, rect = def.rect, grip = def.grip, near = def.near, housing = def.housing, shownFn = def.shown,
		pad = def.pad or PAD, held = def.held, paneled = def.paneled, catch = def.catch, onOut = def.onOut, onTucked = def.onTucked,
		list = {}, at = {}, level = 0, reveal = 0, want = false, on = false, over = def.over == true,
	}, Drawer)
	local handle = CreateFrame("Frame", "ShyDrawer" .. def.id:gsub("%W", ""), UIParent)
	handle:SetFrameStrata("HIGH")
	handle:EnableMouse(false)
	handle:Hide()
	d.handle = handle
	-- Over the bay while its frames are out of sight: nothing nobody can see takes a click.
	local catcher = CreateFrame("Frame", nil, handle)
	catcher:SetAllPoints()
	catcher:EnableMouse(true)
	catcher:Hide()
	d.catcher = catcher
	local pull = CreateFrame("Button", nil, handle)
	pull:SetFrameLevel(handle:GetFrameLevel() + 2)
	local upright = d.side == "left" or d.side == "right"
	-- A level pull's housing is a frame of its own (it gives way to the panel's, Paint), its words and
	-- chevron on a face over it.
	local face = pull
	if not upright then
		pull.plate = CreateFrame("Frame", nil, pull)
		pull.plate:SetAllPoints()
		face = CreateFrame("Frame", nil, pull)
		face:SetAllPoints()
		face:SetFrameLevel(pull.plate:GetFrameLevel() + 1)
	end
	pull.caret = face:CreateTexture(nil, "OVERLAY")
	pull.caret:SetTexture(Shy.MEDIA .. "GlyphCaret")
	if upright then
		-- The whole pull takes the mouse; only the handle in its middle is drawn.
		pull.fill = pull:CreateTexture(nil, "BACKGROUND")
		pull.fill:SetTexture(Shy.MEDIA .. "PullFill")
		pull.fill:SetSize(KNOB_W, KNOB_H)
		pull.fill:SetPoint("CENTER")
		UI.Tint(pull.fill, C.bg)
		pull.rim = pull:CreateTexture(nil, "BORDER")
		pull.rim:SetTexture(Shy.MEDIA .. "PullRim")
		pull.rim:SetAllPoints(pull.fill)
		pull.caret:SetSize(CARET, CARET)
		pull.caret:SetPoint("CENTER")
	else
		UI.Panel(pull.plate, { hud = true, line = false, brackets = false })
		pull.label = UI.Text(face, d.title, 10, true, C.text)
		pull.label:SetPoint("CENTER")
		pull.caret:SetSize(CARET_STRIP, CARET_STRIP)
		pull.light = face:CreateTexture(nil, "ARTWORK")
		UI.Paint(pull.light, Theme.Accent)
		pull.light:Hide()
	end
	-- At a grip of its own a level pull may head the panel, folding it as every piece folds.
	local heads = def.grip ~= nil and not upright
	Look(pull, false)
	pull:SetScript("OnClick", function()
		if def.carry and Shy.HUD.WasDragged(def.carry) then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		d:Toggle()
	end)
	pull:SetScript("OnEnter", function(self) Look(self, true) end)
	pull:SetScript("OnLeave", function(self) Look(self, false) end)
	if def.help and not heads then UI.Help(pull, d.title, def.help) end
	if def.carry then Shy.HUD.Carry(def.carry, pull) end
	d.pull = pull
	Light(d)
	-- The sliding panel: the console's make, under the frames it carries. One that slides out over
	-- other pieces is solid and stands over them (the game's buttons are a level above still). One a
	-- level pull may head is a console piece with a header (d.headed: top edge to its line's foot).
	local panel = CreateFrame("Frame", nil, UIParent)
	panel:SetFrameStrata(def.over and "MEDIUM" or "LOW")
	panel:SetFrameLevel(def.over and 1 or 30)
	panel:EnableMouse(false)
	panel:Hide()
	if heads then
		UI.Panel(panel, { cap = true, title = UI.HEAD_STRIP, facets = false, hud = true })
		d.headed = UI.HEAD_STRIP + UI.LINE
		d.fold = UI.FoldHead(pull, panel, { title = d.title })
		d.fold:SetShown(false)
	else
		UI.Panel(panel, { cap = true, facets = false, line = false, brackets = 10, hud = not def.over })
	end
	d.panel = panel
	drawers[def.id] = d
	order[#order + 1] = d
	return d
end

function D.Find(id) return drawers[id] end

function D.Holding(frame)
	for _, d in ipairs(order) do
		if d.on and d.bay and not Held(d) and d.reveal > 0 then
			local f = frame
			while f do
				for _, held in ipairs(d.list) do
					if held == f then return d, d.pull end
				end
				f = f:GetParent()
			end
		end
	end
end

-- An addon's own default for a drawer, over the one it was made with (a layout's choice).
function D.SetDefault(id, mode)
	overrides[id] = mode
	local d = drawers[id]
	if d then d:Apply() end
end

-- Back to a default: the pin kept for this layout is dropped.
function D.Reset(id, mode)
	local d = drawers[id]
	local hud = Shy.core and Shy.core.db and Shy.core.db.hud
	if hud and d then hud[Key(d)] = nil end
	D.SetDefault(id, mode)
end

function D.ApplyAll()
	for _, d in ipairs(order) do
		if d.on or (d.shownFn and d.shownFn()) then d:Apply() end
	end
end
