-- The core's minimap button and addon compartment entry (click: the hub; right-click: a menu of
-- every addon), and Shy.MinimapButton for addons that need a button of their own.
-- On a round map a button is a round icon on the rim. On a square map nothing of ours stands on
-- the map: the buttons are flat ones in a row in the map's title strip.

local Shy = Shy
local B, UI, Theme = Shy.Brand, Shy.UI, Shy.Theme
local S = Shy.Skin.colors
local core = Shy.core
local WriteGathered   -- the menu's rows for other addons' buttons ("Other addons' buttons", below)
local buttons = {}    -- the family's buttons, in the order made (Shy.MinimapButton, below)
local tracked = false -- tracking has a place of its own on the map (Shy.SetMinimapTracking): not a row of the menu

local function OpenHub()
	Shy.Hub.Open()
end

-- The family's buttons folded into this menu (PlaceRow): by the addon whose row carries them, and
-- the rest.
local function Folded()
	local byAddon, loose = {}, {}
	for _, b in ipairs(buttons) do
		if b.folded and not b.def.core and b:IsShown() then
			if b.def.addon then byAddon[b.def.addon] = b else loose[#loose + 1] = b end
		end
	end
	return byAddon, loose
end

-- The one menu: the setup window first under a rule, then the family's own three (the task manager with
-- the errors new since it was last read, /shy, layout mode), then what the strip folded in (tracking, the launch, the bug reporter), then
-- the addons, then other addons' buttons.
-- Shy.WriteMenu(root, done) writes it into a menu writer's root (the game menu's Shy button opens it
-- too); done(), if given, runs after an entry has done its work.
function Shy.WriteMenu(root, done)
	local function Then(fn)
		if not done then return fn end
		return function(...)
			fn(...)
			done()
		end
	end
	-- The setup window first, on its own: the quick way back to every choice made in it.
	if Shy.Setup then
		root:CreateButton("Set up", Then(function() Shy.Setup.Open() end)):SetIcon({ Theme.MarkArt(Shy.MEDIA .. "SetupMark", UI.MENU_ROW.icon) })
	end
	-- What's new again, told or not.
	if Shy.News then
		root:CreateButton("What's new", Then(function() Shy.News.Open(true) end)):SetIcon(UI.MenuGlyph("info"))
	end
	-- The addons Shy does, while there are any: how many are still on and not kept, beside it.
	local others = Shy.Others and Shy.Others.Doubled(true) or {}
	if #others > 0 then
		local row = root:CreateButton("Your addons", Then(function() Shy.Others.Open(true) end))
		row:SetIcon(UI.MenuGlyph("options"))
		local due = 0
		for _, entry in ipairs(Shy.Others.Doubled()) do
			if Shy.Others.On(entry) then due = due + 1 end
		end
		if due > 0 then row:SetDetail(UI.Wrap(UI.colors.alert, due == 1 and "1 to look at" or (due .. " to look at"))) end
	end
	if Shy.Setup or Shy.News or #others > 0 then root:CreateDivider() end
	-- (ShyMonitor loads as it is first asked for.)
	local fresh = Shy.Errors and Shy.Errors.Fresh() or 0
	local monitor = root:CreateButton("Task manager", Then(function() Shy.Monitor() end))
	monitor:SetIcon({ Theme.MarkArt("Interface\\AddOns\\ShyMonitor\\Media\\ShyMonitorMark", UI.MENU_ROW.icon) })
	if fresh > 0 then monitor:SetDetail(Shy.UI.Wrap(Shy.UI.colors.alert, fresh == 1 and "1 error" or (fresh .. " errors"))) end
	root:CreateButton("Open /shy", Then(OpenHub)):SetIcon({ Theme.MarkArt(Shy.core.mark, UI.MENU_ROW.icon) })
	-- Edit Mode, dressed as Shy's layout editor, opens from a secure row.
	local layout = root:CreateButton("Layout mode")
	layout:SetIcon({ Theme.MarkArt(Shy.MEDIA .. "LayoutMark", UI.MENU_ROW.icon) })
	layout:SetSecure({ type = "macro", macrotext = SLASH_EDITMODE1 }, done)

	local byAddon, loose = Folded()
	local tracking = Shy.MinimapFolding() and not tracked and MinimapCluster and MinimapCluster.Tracking and MinimapCluster.Tracking.Button
	if tracking or #loose > 0 then root:CreateDivider() end
	-- The game's tracking list, as a submenu of ours (its rows the game's own, with their pictures).
	local rows = tracking and Shy.UI.GameDescription(tracking)
	if rows then
		local entry = root:CreateButton("Tracking")
		entry:SetSub("What the minimap shows")
		entry:SetIcon(Shy.UI.MenuGlyph("track"))
		Shy.UI.GameEntries(entry, rows)
	end
	for _, b in ipairs(loose) do
		local label = b.def.label
		if type(label) == "function" then label = label(b) end
		local entry = root:CreateButton(tostring(label or b.def.name), Then(function() b.def.onClick(b, "LeftButton") end))
		if b.def.secure then entry:SetSecure(b.def.secure, done) end
		if b.def.detail then
			local said = b.def.detail(b)
			if said then entry:SetDetail(said) end
		end
	end

	-- The addons with something to open, under their categories, by name (as the /shy window lists them).
	root:CreateDivider()
	for _, group in ipairs(Shy.Listed(function(a) return Shy.Settings.told[a.suffix] or a.OpenWindow end)) do
		root:CreateTitle(group.title)
		for _, a in ipairs(group.addons) do
			local entry = root:CreateButton(a.suffix, Then(function()
				if a.OpenWindow then a:OpenWindow() else a:OpenOptions() end
			end))
			entry:SetIcon({ Theme.MarkArt(a.mark, UI.MENU_ROW.icon) })
			local folded = byAddon[a]
			if folded and (folded.unread or 0) > 0 then entry:SetDetail(Shy.UI.Wrap(Shy.UI.colors.alert, tostring(folded.unread) .. " new")) end
		end
	end
	WriteGathered(root, Then)
end

local function OpenMenu(owner)
	Shy.UI.ContextMenu(owner, function(root) Shy.WriteMenu(root) end)
end

-- The game's master volume, 0 to 1, and what the hover says of it.
local VOLUME = "Sound_MasterVolume"
local function Volume()
	return tonumber(C_CVar.GetCVar(VOLUME)) or 1
end

local function Loudness()
	if C_CVar.GetCVar("Sound_EnableAllSound") == "0" then return "Sound off" end
	return ("Volume %d%%"):format(math.floor(Volume() * 100 + 0.5))
end

-- The hover of the core's button and of its entry in the game's addon menu: what a click does, said
-- at once, close to the mouse. The list of addons is the right click's menu: listed in a hover it
-- looked like something to click, and was gone before the mouse reached it.
-- The button on the map (`draggable`) also takes the mouse wheel: its note is the volume then.
local function ShowTip(owner, side, draggable)
	local n = 0
	for _, a in ipairs(Shy.order) do
		if not a.internal then n = n + 1 end
	end
	local menu = not Shy.MinimapFolding() and "Right-click lists your addons."
		or (tracked and "Right-click: your addons, the task manager." or "Right-click: tracking, your addons, the task manager.")
	UI.Tip(owner, Shy.Brand.FAMILY, draggable and ("Click opens /shy. " .. menu .. " The mouse wheel sets the volume.")
		or ("Click opens /shy. " .. menu), {
		side = side,
		note = draggable and Loudness() or (n == 1 and "1 addon" or (n .. " addons")),
		-- In the square map's strip the buttons are a fixed row: nothing to drag.
		hints = draggable and Shy.MinimapShape() == "ROUND" and { { "left", "Drag" } } or nil,
	})
end

local function HideTip(owner)
	UI.TipHide(owner)
end

-- Addon compartment (functions named in ShyCore.toc)

function ShyCore_OnCompartmentClick(_, mouseButton)
	if mouseButton == "RightButton" then OpenMenu() else OpenHub() end
end

function ShyCore_OnCompartmentEnter(_, menuButton)
	ShowTip(menuButton)
end

function ShyCore_OnCompartmentLeave(_, menuButton)
	HideTip(menuButton)
end

-- Minimap buttons

local SIZE, ICON, ICON_HOVER, ICON_PRESSED = 31, 27, 31, 24   -- on the rim

-- Round minimap: each button on the ring at its saved angle.
local RING = 5                        -- button center, this far past the round map's rim
-- Square minimap: a row in the map's title strip, in creation order, each button a flat plate like
-- the strip's own (tracking, the calendar) with the addon's glyph on it. A button with a count is
-- wider: glyph and number in gold.
local STRIP, GLYPH, GAP = 16, 12, 2   -- a strip button's side; its glyph; between two buttons
local REST = 0.62                     -- a strip glyph's opacity at rest
local CLEAR = { 0, 0, 0, 0 }
local COUNT_IN, COUNT_END = 2, 4      -- a count: this far past the glyph; the plate's end past it
local LIGHT, LIGHT_PEAK = 1.2, 0.7    -- Light(): seconds it takes, up and down; its brightest
local shape = "ROUND"

-- The row: a frame as wide as the buttons showing, in the strip's own units whatever size the map is
-- set to. It ends `gap` before the frame the strip's owner names (Shy.MinimapStrip); with none named
-- it stands over the map's top right corner.
local rail = CreateFrame("Frame", nil, Minimap)
rail:SetSize(1, STRIP)
local railEnd, railGap = nil, GAP

local PlaceAll

-- In the strip, with "Gather addon buttons" on, the family's own buttons fold into the core's: the row
-- holds the one S button, and the others are rows of its right-click menu (Shy.MinimapFolding). A button
-- made to `stay` (quick access: ShyGroup's) keeps its place in the row beside it.
function Shy.MinimapFolding()
	return shape == "SQUARE" and core.db.minimap and core.db.gather ~= false
end

-- Whoever dresses the map says tracking has a place of its own on it: the menu then leaves it out.
function Shy.SetMinimapTracking(own)
	tracked = own == true
end

local function PlaceRow()
	local to = railEnd or Minimap
	local scale = to:GetEffectiveScale() / Minimap:GetEffectiveScale()
	rail:SetScale(scale)
	rail:ClearAllPoints()
	if railEnd then
		rail:SetPoint("RIGHT", railEnd, "LEFT", -railGap, 0)
	else
		rail:SetPoint("BOTTOMRIGHT", Minimap, "TOPRIGHT", 0, railGap)
	end
	local folding = Shy.MinimapFolding()
	local x = 0
	for _, button in ipairs(buttons) do
		button:Dress(true, scale)
		button.folded = folding and not button.def.core and not button.def.stay
		if button.folded then
			button:ClearAllPoints()   -- (nowhere: a frame with no point is not drawn and takes no mouse)
		elseif button:IsShown() then
			if x > 0 then x = x + GAP end
			button:ClearAllPoints()
			button:SetPoint("LEFT", rail, "LEFT", x, 0)
			x = x + button:GetWidth()
		end
	end
	-- Never nothing wide: what ends at the row's left edge keeps a place to end at.
	rail:SetWidth(math.max(x, 0.01))
end

function PlaceAll()
	if shape == "SQUARE" then
		PlaceRow()
	else
		for _, button in ipairs(buttons) do
			button:Dress(false, 1)
			button.folded = false
			if button.placed then
				local angle = math.rad(button.def.getAngle())
				local reach = Minimap:GetWidth() / 2 + RING
				button:ClearAllPoints()
				button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * reach, math.sin(angle) * reach)
			end
		end
	end
	for _, button in ipairs(buttons) do
		if button.cover then button.cover:Fit() end
	end
end

-- Called by whichever addon reshapes the minimap: "SQUARE", or "ROUND" to hand it back.
function Shy.SetMinimapShape(to)
	shape = to
	PlaceAll()
end

function Shy.MinimapShape()
	return shape
end

-- Called by whoever lays out the square map's title strip, each time it does: the row of buttons
-- ends `gap` left of `before`, a frame standing in the strip (none: the strip is gone). Returns the
-- row's frame, as wide as the buttons showing: what stands left of them ends at its left edge.
function Shy.MinimapStrip(before, gap)
	railEnd, railGap = before, gap or GAP
	PlaceAll()
	return rail
end

Minimap:HookScript("OnSizeChanged", function() PlaceAll() end)

-- A button with def.secure is covered by a secure button that takes the mouse: its left click does the
-- secure action, and hover, press, drag and every click are passed on to the button under it. A click
-- from addon code would run the game's handler in our taint, and what it builds would stay tainted
-- (the issue reporter's survey then can't send). The cover stands on UIParent by coordinates, never
-- anchored to the button: anything a protected frame is anchored to becomes protected, and the button
-- must stay free to move in a fight. It follows the button out of combat; in a fight it stays put.
local FOLLOW = 0.25   -- seconds between looks at where the button is (the minimap can be dragged)
local function Cover(button)
	local cover = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
	cover:RegisterForClicks("AnyUp", "AnyDown")
	cover:RegisterForDrag("LeftButton")
	-- The left button's attributes only: a right click does nothing secure.
	for key, value in pairs(button.def.secure) do cover:SetAttribute(key .. "1", value) end
	cover:Hide()
	local function Tell(script)
		return function(_, ...)
			local fn = button:GetScript(script)
			if fn then fn(button, ...) end
		end
	end
	cover:SetScript("OnEnter", Tell("OnEnter"))
	cover:SetScript("OnLeave", Tell("OnLeave"))
	cover:HookScript("OnMouseDown", Tell("OnMouseDown"))
	cover:HookScript("OnMouseUp", Tell("OnMouseUp"))
	cover:SetScript("OnDragStart", Tell("OnDragStart"))
	cover:SetScript("OnDragStop", Tell("OnDragStop"))
	cover:SetScript("PostClick", function(_, mouseButton, down)
		if not down then button.def.onClick(button, mouseButton) end
	end)

	local at = {}
	function cover:Fit()
		if InCombatLockdown() then return end
		local left, bottom = button:GetLeft(), button:GetBottom()
		if button.folded or not (left and bottom and button:IsVisible()) then
			self:Hide()
			return
		end
		local scale = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local x, y, w, h = left * scale, bottom * scale, button:GetWidth() * scale, button:GetHeight() * scale
		-- (Looked at four times a second: only what changed is set.)
		local strata, level = button:GetFrameStrata(), button:GetFrameLevel() + 10
		if at.strata ~= strata then
			at.strata = strata
			self:SetFrameStrata(strata)
		end
		if at.level ~= level then
			at.level = level
			self:SetFrameLevel(level)
		end
		if not (at.x == x and at.y == y and at.w == w and at.h == h) then
			at.x, at.y, at.w, at.h = x, y, w, h
			self:ClearAllPoints()
			self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
			self:SetSize(w, h)
		end
		self:Show()
	end

	local since = 0
	cover:SetScript("OnUpdate", Shy.Clocked("minimap: a secure button's cover", function(self, dt)
		since = since + dt
		if since < FOLLOW then return end
		since = 0
		self:Fit()
	end))
	button.cover = cover
end

-- A fight's end: every cover to where its button now is.
local afterFight = CreateFrame("Frame")
afterFight:RegisterEvent("PLAYER_REGEN_ENABLED")
afterFight:SetScript("OnEvent", function() PlaceAll() end)
Minimap:HookScript("OnShow", function() PlaceAll() end)

--   local button = Shy.MinimapButton({
--       name = "ShyThingMinimapButton",          -- global frame name
--       icon = path,                             -- a round icon, for the round map's rim
--                                                -- (or function(button) returning a frame of the caller's: the round face)
--       glyph = path,                            -- a flat white glyph (32 x 32), for the square map's strip
--                                                -- (or function(texture, size) that puts one on the texture)
--       getAngle = function() return db.minimapAngle end,   -- degrees around the round minimap
--       setAngle = function(v) db.minimapAngle = v end,
--       onClick = function(self, mouseButton) end,
--       onEnter = function(self) end,
--       onLeave = function(self) end,
--       -- In the square map's strip, with "Gather addon buttons" on, the button folds into the core's
--       -- menu as a row (its click is the row's):
--       addon = T,                               -- the addon's own row carries its count instead
--       label = "Report a bug",                  -- or function() -> the row's words (no addon)
--       detail = function() return "..." end,    -- dim words at the row's right
--       stay = true,                             -- quick access: it keeps its own place in the strip, folding never
--       -- A left click that must run in the game's own hands (pressing one of the game's buttons):
--       -- a SecureActionButton's attributes, done before onClick is told of the click.
--       secure = { type = "click", clickbutton = SomeGameButton },
--   })
--   button:Place()        -- after the saved angle is known
--   button:SetShown(...)  -- starts hidden
--   button:SetBadge(n)    -- a count: on the corner of a round button, beside the glyph in the strip; 0 hides it
--   button:SetTint(color) -- the glyph's color at rest in the strip (a palette table); nil: steel
--   button:Light(color)   -- lights up once, as something comes into play
--   button:TipSide()      -- for its hover's opts.side: under the button in the strip, left of it on the rim
function Shy.MinimapButton(def)
	local button = CreateFrame("Button", def.name, Minimap)
	button.def = def
	button:SetSize(SIZE, SIZE)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:Hide()

	-- On the rim: the round icon, a turning halo under it on hover, the count on its corner.
	local halo = button:CreateTexture(nil, "BACKGROUND")
	halo:SetTexture(B.GLOW)
	halo:SetBlendMode("ADD")
	halo:SetSize(58, 58)
	halo:SetPoint("CENTER")
	halo:SetAlpha(0)

	local icon
	if type(def.icon) == "function" then
		icon = def.icon(button)
	else
		icon = button:CreateTexture(nil, "ARTWORK")
		Theme.Icon(icon, def.icon)
	end
	icon:SetSize(ICON, ICON)
	icon:SetPoint("CENTER")

	-- Light(): when it lit up, and in what color.
	local litAt, litColor

	local anim = CreateFrame("Frame", nil, button)
	local target = { size = ICON, halo = 0 }
	local current = { size = ICON, halo = 0 }
	local spin = 0
	-- (At rest, its icon at size and its halo out, it stops: Wake starts it as anything changes.)
	anim:SetScript("OnUpdate", Shy.Clocked("minimap: a button's light", function(self, dt)
		local k = math.min(1, dt * 12)
		current.size = current.size + (target.size - current.size) * k
		current.halo = current.halo + (target.halo - current.halo) * k
		if not litAt and target.halo == 0 and math.abs(target.size - current.size) < 0.01 and current.halo < 0.002 then
			current.size, current.halo = target.size, 0
			icon:SetSize(current.size, current.size)
			halo:SetAlpha(0)
			self:Hide()
			return
		end
		icon:SetSize(current.size, current.size)
		spin = spin + dt
		local light = 0
		if litAt then
			local t = (GetTime() - litAt) / LIGHT
			if t >= 1 then litAt = nil else light = LIGHT_PEAK * math.sin(t * math.pi) end
		end
		halo:SetAlpha(math.max(current.halo, light))
		halo:SetRotation(spin * 0.6)
		if light > current.halo then
			UI.Tint(halo, litColor)
		else
			halo:SetVertexColor(B.Cycle(spin * 0.4))
		end
	end))
	local function Wake()
		if not button.inStrip then anim:Show() end
	end

	local badge = CreateFrame("Frame", nil, button)
	badge:SetSize(15, 15)
	badge:SetPoint("TOPRIGHT", 3, 3)
	badge:SetFrameLevel(button:GetFrameLevel() + 2)
	badge.bg = badge:CreateTexture(nil, "BACKGROUND")
	badge.bg:SetAllPoints()
	Theme.Paint(badge.bg, UI.colors.alert)
	badge.text = UI.Text(badge, "", 11, true, UI.colors.onAlert)
	badge.text:SetShadowColor(0, 0, 0, 0)   -- no shadow under dark text on gold
	badge.text:SetPoint("CENTER", 0, 0)
	badge:Hide()

	-- In the strip: the glyph bare on the header, the count after it. No plate: it rests quiet and
	-- lights up under the mouse.
	local plate = CreateFrame("Frame", nil, button)
	plate:SetAllPoints()
	UI.Skin(plate, CLEAR, CLEAR)
	plate:Hide()
	-- The plate is housing: it fades with the HUD, as the strip's own plates do.
	button.shyHousing = { plate.shyBg, plate.shyEdges[1], plate.shyEdges[2], plate.shyEdges[3], plate.shyEdges[4] }
	local glyph = plate:CreateTexture(nil, "ARTWORK")
	if type(def.glyph) == "function" then def.glyph(glyph, GLYPH) else glyph:SetTexture(def.glyph) end
	glyph:SetSize(GLYPH, GLYPH)
	local count = UI.Text(plate, "", 11, true, UI.colors.alert)
	count:SetPoint("LEFT", glyph, "RIGHT", COUNT_IN, 0)
	button.stripGlyph, button.stripWords = glyph, count
	-- Light():a soft light behind the glyph, up and down once.
	local shine = plate:CreateTexture(nil, "BORDER", nil, 7)
	shine:SetTexture(B.GLOW)
	shine:SetSize(STRIP * 2, STRIP * 2)
	shine:SetPoint("CENTER", glyph, "CENTER")
	shine:SetAlpha(0)

	local unread = 0
	local tint
	local over, down = false, false

	-- The glyph as it is now: quiet at rest, gold while there is a count, lit under the mouse with a
	-- soft light behind it, a step down while pressed.
	local function Ink()
		UI.Tint(glyph, unread > 0 and UI.colors.alert or over and S.lit or tint or S.glyph)
		glyph:SetAlpha(over and 1 or unread > 0 and 1 or REST)
		UI.Ink(count, unread > 0 and UI.colors.alert or tint or UI.colors.text)
		if not litAt then
			UI.Tint(shine, S.lit)
			shine:SetAlpha(over and 0.35 or 0)
		end
		glyph:ClearAllPoints()
		glyph:SetPoint("LEFT", plate, "LEFT", (STRIP - GLYPH) / 2 + (down and 1 or 0), down and -1 or 0)
	end

	-- One face or the other. `scale` brings a strip button to the strip's units.
	function button:Dress(strip, scale)
		self.inStrip = strip
		self:SetScale(scale)
		plate:SetShown(strip)
		icon:SetShown(not strip)
		halo:SetShown(not strip)
		anim:SetShown(not strip)
		badge:SetShown(not strip and unread > 0)
		if strip then
			local say = unread > 0 and (unread > 9 and "9+" or tostring(unread)) or ""
			count:SetText(say)
			self:SetSize(say ~= "" and (STRIP - GLYPH) / 2 + GLYPH + COUNT_IN + count:GetStringWidth() + COUNT_END or STRIP, STRIP)
			Ink()
		else
			self:SetSize(SIZE, SIZE)
		end
	end

	function button:SetBadge(n)
		unread = n
		self.unread = n
		badge.text:SetText(n > 9 and "9+" or n)
		badge:SetWidth(n > 9 and 21 or 15)
		PlaceAll()   -- a count makes a strip button wider, and the row with it
	end

	function button:SetTint(color)
		tint = color
		Ink()
	end

	function button:Light(color)
		litAt, litColor = GetTime(), color or UI.colors.hot
		Wake()
		UI.Tint(shine, litColor)
		local at = litAt
		plate:SetScript("OnUpdate", function(frame)
			local t = (GetTime() - at) / LIGHT
			if t >= 1 then
				shine:SetAlpha(0)
				frame:SetScript("OnUpdate", nil)
			else
				shine:SetAlpha(LIGHT_PEAK * math.sin(t * math.pi))
			end
		end)
	end

	function button:Place()
		self.placed = true
		PlaceAll()
	end

	function button:TipSide()
		return self.inStrip and "BOTTOM" or "LEFT"
	end

	buttons[#buttons + 1] = button
	-- Showing or hiding a button moves the ones after it in the row.
	button:HookScript("OnShow", PlaceAll)
	button:HookScript("OnHide", PlaceAll)

	local function FollowCursor(self)
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		def.setAngle(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
		self:Place()
	end

	local function StopDrag(self)
		if not self.dragging then return end
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		self:UnregisterEvent("GLOBAL_MOUSE_UP")
	end

	button:SetScript("OnDragStart", function(self)
		if shape == "SQUARE" then return end   -- the row is fixed
		self.dragging = true
		def.onLeave(self)
		self:SetScript("OnUpdate", FollowCursor)
		-- This client sometimes never fires OnDragStop; any mouse release ends the drag.
		self:RegisterEvent("GLOBAL_MOUSE_UP")
	end)
	button:SetScript("OnDragStop", StopDrag)
	button:SetScript("OnEvent", StopDrag)

	button:SetScript("OnClick", def.onClick)

	button:SetScript("OnEnter", function(self)
		if self.cover then self.cover:Fit() end   -- the mouse found the button itself: the cover was out of place
		if not self.dragging then def.onEnter(self) end
		target.size, target.halo = ICON_HOVER, 0.85
		over = true
		Wake()
		Ink()
	end)
	button:SetScript("OnLeave", function(self)
		def.onLeave(self)
		target.size, target.halo = ICON, 0
		over, down = false, false
		Wake()
		Ink()
	end)
	button:SetScript("OnMouseDown", function()
		target.size = ICON_PRESSED
		down = true
		Wake()
		Ink()
	end)
	button:SetScript("OnMouseUp", function(self)
		target.size = self:IsMouseOver() and ICON_HOVER or ICON
		down = false
		Wake()
		Ink()
	end)

	if def.secure then Cover(button) end
	PlaceAll()
	return button
end

local button = Shy.MinimapButton({
	name = "ShyMinimapButton",
	core = true,
	icon = Shy.MEDIA .. "ShyRound",
	glyph = Shy.MEDIA .. "ShyGlyph",
	getAngle = function() return core.db.minimapAngle end,
	setAngle = function(v) core.db.minimapAngle = v end,
	onClick = function(self, mouseButton)
		if mouseButton == "RightButton" then OpenMenu(self) else OpenHub() end
	end,
	onEnter = function(self) ShowTip(self, self:TipSide(), true) end,
	onLeave = HideTip,
})

-- The mouse wheel on it sets the game's master volume, a step a notch; the hover says where it is.
local VOLUME_STEP = 0.05
button:EnableMouseWheel(true)
button:SetScript("OnMouseWheel", function(self, delta)
	local steps = 1 / VOLUME_STEP
	local to = math.max(0, math.min(1, math.floor((Volume() + delta * VOLUME_STEP) * steps + 0.5) / steps))
	C_CVar.SetCVar(VOLUME, tostring(to))
	ShowTip(self, self:TipSide(), true)
end)

-- Other addons' buttons
-- Buttons other addons stand on the minimap leave it for a hidden holder of ours and are listed in the
-- core button's right-click menu, where a click (left or right) clicks them. Only while the core's button
-- is there to list them, and the setting is on (ShyCoreDB.gather, on unless set false). Taken: a named
-- Button of another addon, neither forbidden nor protected, button sized, that answers a click, and either
-- wears the ring nearly every addon's minimap button wears, or comes from an addon's folder and can be
-- dragged (a map pin can't). Blizzard's frames never wear that ring here; nothing of a Blizzard_ or a Shy
-- folder is taken. Given back, each goes to the parent, layer and level it had.
local RING_FILE = "Interface\\Minimap\\MiniMap-TrackingBorder"
local SMALLEST, LARGEST = 16, 48   -- a button's side; pins are smaller, panels larger
local attic = CreateFrame("Frame", nil, UIParent)
attic:Hide()
local ringProbe = attic:CreateTexture()
ringProbe:SetTexture(RING_FILE)
local taken, gathered = {}, {}   -- frame -> { parent, strata, level }; the frames, in the order found
local owed = false               -- a change waits for the fight to end

local function Gathering()
	return core.db.minimap and core.db.gather ~= false
end

local function Plain(value)
	if value == nil or issecretvalue(value) then return nil end
	return value
end

-- The addon folder a frame was made from, when the game says.
local function Folder(frame)
	local where = Plain(frame:GetSourceLocation())
	return type(where) == "string" and where:match("[Aa]dd[Oo]ns[/\\]([^/\\]+)") or nil
end

local function IsRing(file)
	file = Plain(file)
	if type(file) == "number" then
		local ring = Plain(ringProbe:GetTextureFileID())
		return type(ring) == "number" and ring > 0 and file == ring
	end
	return type(file) == "string" and (file:gsub("/", "\\")):lower() == RING_FILE:lower()
end

local function WearsRing(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:GetObjectType() == "Texture" and IsRing(region:GetTexture()) then return true end
	end
	return false
end

local function Ours(frame)
	for _, mine in ipairs(buttons) do
		if mine == frame then return true end
	end
	return false
end

local function Theirs(frame)
	if frame:IsForbidden() or frame:IsProtected() or frame:GetObjectType() ~= "Button" then return false end
	local name = Plain(frame:GetName())
	if type(name) ~= "string" or name:find("^Shy") or Ours(frame) then return false end
	local w, h = Plain(frame:GetWidth()), Plain(frame:GetHeight())
	if not (w and h) or w < SMALLEST or w > LARGEST or h < SMALLEST or h > LARGEST then return false end
	if not (frame:GetScript("OnClick") or frame:GetScript("OnMouseUp")) then return false end
	local folder = Folder(frame)
	if folder and (folder:find("^Blizzard_") or folder:find("^Shy")) then return false end
	if WearsRing(frame) then return true end
	return folder ~= nil and frame:GetScript("OnDragStart") ~= nil
end

local function Take(frame)
	if not taken[frame] then
		taken[frame] = { parent = frame:GetParent(), strata = frame:GetFrameStrata(), level = frame:GetFrameLevel() }
		gathered[#gathered + 1] = frame
	end
	frame:SetParent(attic)
end

local function Gather()
	if InCombatLockdown() then
		owed = true
		return
	end
	owed = false
	if not Gathering() then
		for _, frame in ipairs(gathered) do
			local was = taken[frame]
			if frame:GetParent() == attic then
				frame:SetParent(was.parent)
				frame:SetFrameStrata(was.strata)
				frame:SetFrameLevel(was.level)
			end
		end
		wipe(taken)
		wipe(gathered)
		return
	end
	for _, holder in ipairs({ Minimap, MinimapBackdrop }) do
		for _, frame in ipairs({ holder:GetChildren() }) do
			-- Its addon stood it on the map again: taken again.
			local ok, theirs = true, taken[frame] ~= nil
			if not theirs then ok, theirs = pcall(Theirs, frame) end
			if ok and theirs then Take(frame) end
		end
	end
end

local function Strip(text)
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""))
end

-- What the button is called: its data's label, else its addon's title, else its frame's name without
-- the prefix a shared library gives it (up to an underscore) or the words "minimap" and "button".
local function Called(frame)
	local data = frame.dataObject
	local label = type(data) == "table" and Plain(data.label)
	if type(label) == "string" and Strip(label) ~= "" then return Strip(label) end
	local folder = Folder(frame)
	local title = folder and Plain(C_AddOns.GetAddOnTitle(folder))
	if type(title) == "string" and Strip(title) ~= "" then return Strip(title) end
	local name = frame:GetName()
	local short = name:gsub("^.*_", ""):gsub("[Mm]ini[Mm]ap[Bb]utton$", ""):gsub("[Mm]ini[Mm]ap$", ""):gsub("[Bb]utton$", "")
	return short ~= "" and short or name
end

-- Its picture for the menu row: the `icon` it keeps, else its first picture that isn't the ring.
local function Picture(frame)
	local icon = frame.icon
	if not (type(icon) == "table" and icon.GetObjectType and icon:GetObjectType() == "Texture") then
		icon = nil
		for _, region in ipairs({ frame:GetRegions() }) do
			if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "ARTWORK" and not IsRing(region:GetTexture()) then
				icon = region
				break
			end
		end
	end
	if not icon then return nil end
	local atlas = Plain(icon:GetAtlas())
	if type(atlas) == "string" and atlas ~= "" then return { { atlas = atlas } } end
	local file = Plain(icon:GetTexture())
	if file == nil or file == 0 or file == "" then return nil end
	local left, top, _, bottom, right = icon:GetTexCoord()
	if Plain(left) and Plain(top) and Plain(bottom) and Plain(right) and right > left and bottom > top then
		return { { file, coords = { left, right, top, bottom } } }
	end
	return { file }
end

-- A click from the menu is a click on the button, with the mouse button the row was clicked with.
local function Press(frame, mouseButton)
	if frame:GetScript("OnClick") then
		frame:Click(mouseButton)
	else
		frame:GetScript("OnMouseUp")(frame, mouseButton, true)
	end
end

-- then_(fn): Shy.WriteMenu's wrap for an entry's click.
function WriteGathered(root, then_)
	Gather()
	local list = {}
	for _, frame in ipairs(gathered) do
		if frame:IsShown() then
			local ok, name = pcall(Called, frame)
			list[#list + 1] = { frame = frame, name = ok and name or "?" }
		end
	end
	if #list == 0 then return end
	table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
	root:CreateDivider()
	root:CreateTitle("Other addons")
	for _, row in ipairs(list) do
		local entry = root:CreateButton(row.name, then_(function(_, _, mouseButton)
			local ok, err = pcall(Press, row.frame, mouseButton)
			if not ok then geterrorhandler()(err) end
		end))
		entry:SetRightClick()
		local ok, picture = pcall(Picture, row.frame)
		if ok and picture then entry:SetIcon(picture) end
	end
end

-- The buttons gathered now, for whoever asks (the tests, a report).
function Shy.GatheredButtons()
	local out = {}
	for i, frame in ipairs(gathered) do out[i] = frame end
	return out
end

-- Other addons make their buttons as they load and at login: looked for again after each.
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:RegisterEvent("PLAYER_REGEN_ENABLED")
watch:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_ENABLED" and not owed then return end
	C_Timer.After(0, Gather)
end)

function Shy.UpdateMinimapButton()
	button:Place()
	button:SetShown(core.db.minimap)
	Gather()
end

function core:OnLogin()
	Shy.UpdateMinimapButton()
	-- Some make theirs a little after login.
	C_Timer.After(2, Gather)
	C_Timer.After(10, Gather)
end
