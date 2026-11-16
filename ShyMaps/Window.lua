-- The map in a window of its own: the family's window, sized by width and height at any corner or side, that holds
-- the map's view while it is open (View.Host): the map, what stands over it, the breadcrumb and the bar on a strip
-- under its header, and the map's menu at the strip's end where the game's filter stands. The game's own window is
-- left as it is: opening it hands the view back and closes this one.
--
-- It opens from its key (Key Bindings, ShyMaps: "Map window"), the map's menu or /shymaps window. The game's map is
-- never closed from addon code: a secure button (ShyMapsWindowKey) clicks the game window's own close button, the
-- key's binding and the menu's row both through it, and this window opens after.

local ADDON, ns = ...
local T, View = ns.T, ns.View
local UI = Shy.UI
local C = UI.colors

local Window = {}
ns.Window = Window

local KEY = "ShyMapsWindowKey"
_G["BINDING_NAME_CLICK " .. KEY .. ":LeftButton"] = "Map window"

local L = {
	w = 900, h = 640,         -- made at
	least = { 520, 380 },     -- the least it flows to
	head = 32,                -- its header
	strip = 34,               -- the strip under it: the breadcrumb and the bar (the game's NavBar's height)
	pad = 6,                  -- round the map
	menu = 22,                -- the map's menu at the strip's end, on the bar's line (Controls.lua: 11 under the strip's top)
	line = 11,
	reach = 54,               -- room left at the strip's right end for it (the bar stands 11 past the strip's end)
}

local box, well, strip

local function GameShown()
	local map = rawget(_G, "WorldMapFrame")
	return map ~= nil and map:IsShown() == true
end

local function Make()
	if box then return box end
	box = UI.Window({
		id = "shymaps.window",
		name = "ShyMapsWindow",
		title = "Map",
		width = L.w, height = L.h,
		point = { "CENTER", "CENTER", 0, 20 },
		shown = function() return false end,
		grip = { flow = true, min = L.least },
		strata = "HIGH",
		maximize = true,
		head = { size = "window", icon = T.mark, title = "Map" },
	})
	-- Everything under the header stands on the body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)
	-- The strip: the breadcrumb at its left, the bar at its right (Nav.lua, Controls.lua), dark as the game's.
	strip = CreateFrame("Frame", nil, box)
	strip:SetPoint("TOPLEFT", body, "TOPLEFT", L.pad, -L.head)
	strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", -L.reach, -L.head)
	strip:SetHeight(L.strip)
	local band = box:CreateTexture(nil, "BACKGROUND", nil, 2)
	band:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
	band:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", -L.pad, -L.head - L.strip)
	band:SetColorTexture(0, 0, 0, 0.85)
	-- The map's menu, where the game's filter stands on its own window: a plate as the bar's buttons are.
	local plate = CreateFrame("Frame", nil, box)
	plate:SetSize(L.menu, L.menu)
	plate:SetPoint("TOPRIGHT", body, "TOPRIGHT", -L.pad - 6, -L.head - L.line)
	plate:SetFrameLevel(View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	UI.Skin(plate, C.bgHot)
	local menu = CreateFrame("Button", nil, plate)
	menu:SetAllPoints()
	menu.glyph = menu:CreateTexture(nil, "ARTWORK")
	menu.glyph:SetTexture(Shy.MEDIA .. "GlyphFunnel")
	menu.glyph:SetSize(12, 12)
	menu.glyph:SetPoint("CENTER")
	UI.Tint(menu.glyph, C.text)
	UI.Press(menu, { fill = C.bgHot, bare = true, sink = { menu.glyph } })
	menu:SetScript("OnClick", function(self) UI.DropMenu(self, function(root) T:MapMenu(root) end) end)
	menu:SetScript("OnEnter", function(self) UI.Tip(self, "Show on the map", nil, { side = "BOTTOM" }) end)
	menu:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	-- The well: the map, under the strip to the window's foot.
	well = CreateFrame("Frame", nil, box)
	well:SetPoint("TOPLEFT", body, "TOPLEFT", L.pad, -L.head - L.strip)
	well:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -L.pad, L.pad)
	box:HookScript("OnShow", function() View.Host({ box = box, well = well, strip = strip }) end)
	box:HookScript("OnHide", function() View.Host(nil) end)
	return box
end

function Window.Shown() return box ~= nil and box:IsShown() end

-- Our window opened or closed (the game's map closed first, by the secure button, where it was open).
function Window.Set(on)
	if not T.db.on then return end
	if on then
		Make():Show()
		box:Raise()
	elseif box then
		box:Hide()
	end
end

-- The secure button: its click is the game window's close button's (armed out of a fight once the window is
-- loaded), and our window opens after it, or closes where it was the one open.
local key = CreateFrame("Button", KEY, UIParent, "SecureActionButtonTemplate")
key:RegisterForClicks("AnyUp")
key:SetAttribute("type", "click")
key:SetAttribute("useOnKeyDown", false)
key:Hide()

local armed = false
local function Arm()
	if armed or InCombatLockdown() then return end
	local map = rawget(_G, "WorldMapFrame")
	local close = map and type(map.BorderFrame) == "table" and map.BorderFrame.CloseButton
	if type(close) ~= "table" then return end
	key:SetAttribute("clickbutton", close)
	armed = true
end
Window.Close = function()
	Arm()
	local map = rawget(_G, "WorldMapFrame")
	local border = map and map.BorderFrame
	local close = type(border) == "table" and border.CloseButton
	return type(close) == "table" and close or nil
end

local was = false
key:SetScript("PreClick", function() was = GameShown() end)
key:SetScript("PostClick", function()
	Window.Set(was or not Window.Shown())
	was = false
end)

-- The game's window opening takes the view back: ours closes.
local function Watch()
	local map = rawget(_G, "WorldMapFrame")
	if not map or Window.watching then return end
	Window.watching = true
	map:HookScript("OnShow", function()
		if Window.Shown() then box:Hide() end
	end)
	Arm()
end

-- The map's menu: open the map in its own window (the game's closes first), or, in ours, back in the game's.
function Window.MenuRow(root)
	if not T.db.on then return end
	if Window.Shown() then
		local micro = rawget(_G, "QuestLogMicroButton")
		if micro then
			root:CreateButton("Back in the game's window"):SetSecure({ type = "click", clickbutton = micro })
		end
	else
		local close = Window.Close()
		if close then
			root:CreateButton("In a window of its own"):SetSecure({ type = "click", clickbutton = close }, function() Window.Set(true) end)
		end
	end
end

-- Faded while you move, as the game fades its own window (its "mapFade" setting), never while the mouse is on it.
local FADE = { least = 0.5, speed = 4 }
local fader = CreateFrame("Frame")
local function Fade(_, dt)
	if not (box and box:IsShown()) then
		fader:SetScript("OnUpdate", nil)
		return
	end
	local want = (IsPlayerMoving() and GetCVarBool("mapFade") and not box:IsMouseOver()) and FADE.least or 1
	local now = box:GetAlpha()
	if math.abs(now - want) < 0.01 then
		box:SetAlpha(want)
		if want == 1 and not IsPlayerMoving() then fader:SetScript("OnUpdate", nil) end
		return
	end
	box:SetAlpha(now + (want - now) * math.min(1, dt * FADE.speed))
end
fader:RegisterEvent("PLAYER_STARTED_MOVING")
fader:RegisterEvent("PLAYER_STOPPED_MOVING")
fader:SetScript("OnEvent", function()
	if box and box:IsShown() then fader:SetScript("OnUpdate", Fade) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
	Watch()
	Arm()
end)

ns.OnApply(function()
	if not T.db.on and Window.Shown() then box:Hide() end
end)
