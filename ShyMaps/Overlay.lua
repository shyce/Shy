-- The overlay's switches. The overlay itself (the map faintly over the whole screen while its window is
-- closed, under everything else, clicks passing through) is the view's (View.lua): here is what turns it
-- on and off.
--   One key (Key Bindings, ShyMaps: "Map overlay"): with the map open, the map closes onto the overlay;
--   else the overlay comes or goes.
--   The button on the map's bar (left of the look switch), lit while the overlay is on: off, a click closes
--   the map onto it; on, a click turns it off and the map stays.
--   /shymaps overlay, and the options page.
-- The map window opens over it as ever (the game's own key) and the overlay comes back as it closes.
-- Closing the window from a click or a key of ours runs through one secure button (ShyMapsOverlayKey), which
-- clicks the window's own close button: the game's map is never shown or hidden from addon code. That button
-- is the key's binding, and is laid over the bar's button while the mouse is on it, out of a fight; in a
-- fight the bar's button turns the overlay on for when the map closes.

local ADDON, ns = ...
local T = ns.T

local Overlay = {}
ns.Overlay = Overlay

local KEY = "ShyMapsOverlayKey"

BINDING_HEADER_SHYMAPS = "ShyMaps"
_G["BINDING_NAME_CLICK " .. KEY .. ":LeftButton"] = "Map overlay"

function Overlay.Set(on)
	T.db.overlay = on == true
	ns.Apply()
end

local function WindowShown()
	local map = rawget(_G, "WorldMapFrame")
	return map ~= nil and map:IsShown() == true
end

-- The secure button. A binding's click is one Click(): the action runs on it (useOnKeyDown off), and on a
-- mouse button's release.
local key = CreateFrame("Button", KEY, UIParent, "SecureActionButtonTemplate")
key:SetFrameStrata("FULLSCREEN_DIALOG")
key:SetFrameLevel(500)
key:RegisterForClicks("AnyUp")
key:SetAttribute("type", "click")
key:SetAttribute("useOnKeyDown", false)
key:Hide()

-- The window's close button, as the button's click (set out of a fight, once the window is loaded).
local armed = false
local function Arm()
	if armed or InCombatLockdown() then return end
	local map = rawget(_G, "WorldMapFrame")
	local border = map and map.BorderFrame
	local close = type(border) == "table" and border.CloseButton
	if type(close) ~= "table" then return end
	key:SetAttribute("clickbutton", close)
	armed = true
end

local function Away()
	key.owner = nil
	if not InCombatLockdown() then key:Hide() end
end

local was = false   -- the window was open as the click began
key:SetScript("PreClick", function() was = WindowShown() end)
key:SetScript("PostClick", function()
	-- (Open, the window has just closed onto the overlay; closed, the overlay comes or goes.)
	if was then Overlay.Set(true) else Overlay.Set(not T.db.overlay) end
	was = false
	Away()
end)

-- Laid over the bar's button, the hover and the press are the button's under it, for its look.
local function Tell(script)
	return function(self, ...)
		local owner = self.owner
		local fn = owner and owner:GetScript(script)
		if fn then fn(owner, ...) end
	end
end
key:SetScript("OnEnter", Tell("OnEnter"))
key:SetScript("OnLeave", function(self)
	Tell("OnLeave")(self)
	Away()
end)
key:HookScript("OnMouseDown", Tell("OnMouseDown"))
key:HookScript("OnMouseUp", Tell("OnMouseUp"))

local function Lay(button)
	if InCombatLockdown() or T.db.overlay or not armed then return end
	local left, bottom, width, height = button:GetLeft(), button:GetBottom(), button:GetWidth(), button:GetHeight()
	if not left then return end
	local s = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
	key.owner = button
	key:ClearAllPoints()
	key:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
	key:SetSize(width * s, height * s)
	key:Show()
end

-- The button on the map's bar.
T:BarButton("overlay", {
	art = Shy.MEDIA .. "GlyphRestore", size = 12, order = -1,
	tip = "Map overlay",
	text = "The map faintly over the whole screen while this window is closed. Clicks go through it.",
	hints = function()
		return { { "left", T.db.overlay and "Turn it off" or "Close the map onto it" } }
	end,
	lit = function() return T.db.overlay == true end,
	-- (Only in a fight, or before the window's close button is known: the secure button has the click otherwise.)
	click = function()
		local on = not T.db.overlay
		Overlay.Set(on)
		if on and WindowShown() then T:Print("the overlay shows when you close the map.") end
	end,
	made = function(button) button:HookScript("OnEnter", Lay) end,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- (Laid over the bar as the fight begins: gone before the lockdown holds it there.)
		Away()
	else
		Arm()
	end
end)
Arm()
