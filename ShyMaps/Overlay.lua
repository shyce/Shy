-- The overlay's switches. The overlay itself (the map faintly over the whole screen while its window is
-- closed, under everything else, clicks passing through) is the view's (View.lua): here is what turns it
-- on and off.
--   One key (Key Bindings, ShyMaps: "Map overlay"): with the map's window open, it closes onto the overlay;
--   else the overlay comes or goes.
--   "Map overlay" in the map's menu: on, the map's window closes onto it. Off, the map stays.
--   /shymaps overlay, and the options page.
-- The map's window opens over it as ever and the overlay comes back as it closes.

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
	return ns.Window ~= nil and ns.Window.Shown()
end

-- The key's button (its binding clicks it): the window open, it closes onto the overlay; else the overlay comes or goes.
local key = CreateFrame("Button", KEY, UIParent)
key:Hide()
key:SetScript("OnClick", function()
	if WindowShown() then
		Overlay.Set(true)
		ns.Window.Set(false)
	else
		Overlay.Set(not T.db.overlay)
	end
end)

-- In the map's menu, off the bar.
T:BarButton("overlay", {
	order = -1,
	menu = function(root)
		root:CreateCheckbox("Map overlay", function() return T.db.overlay == true end, function()
			local on = not T.db.overlay
			Overlay.Set(on)
			if on and WindowShown() then ns.Window.Set(false) end
		end)
	end,
})
