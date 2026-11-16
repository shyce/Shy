-- ShyMonitor: the task manager. What every addon costs the game, from all of them down to the one handler
-- behind a number, read from what the addons register with ShyCore (the clocks, counters and memory
-- hooks) and from the game's own profiler. Loaded when first opened; closed, nothing of it runs.
--
--   /shymon                open or close the window
--   /shymon <addon>        open at that addon (the name, or its suffix: quest, way)
--   /shymon errors         the errors
--   Shy.Monitor(view, key) opens it from anywhere (ShyCore loads it)

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyMonitor\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Monitor",
	category = "interface",
	icon = MEDIA .. "ShyMonitor",
	smallIcon = MEDIA .. "ShyMonitorSmall",
	savedVariables = "ShyMonitorDB",
	defaults = {
		watch = 30,   -- seconds between clean-ups while Watch is on
	},
})
ns.T = T

-- Set only what changed: a region is given a value once per change, never per refresh.
local floor, format = math.floor, string.format
function ns.Text(fs, text)
	if fs.shyText ~= text then
		fs.shyText = text
		fs:SetText(text)
	end
end
-- A number shown with `fmt`: the text is remade only when its shown digits change (`steps` an
-- integer, the digits past the point as a power of ten).
function ns.Num(fs, value, fmt, steps)
	local key = floor(value * (steps or 1) + 0.5)
	if fs.shyKey ~= key then
		fs.shyKey = key
		fs:SetText(format(fmt, value))
	end
end
function ns.Width(region, w)
	if region.shyW ~= w then
		region.shyW = w
		region:SetWidth(w)
	end
end
function ns.Height(region, h)
	if region.shyH ~= h then
		region.shyH = h
		region:SetHeight(h)
		return true
	end
	return false
end
-- A region hung from its parent's top left at (x, y), again only when the place changed.
function ns.At(region, x, y)
	if region.shyX ~= x or region.shyY ~= y then
		region.shyX, region.shyY = x, y
		region:ClearAllPoints()
		region:SetPoint("TOPLEFT", x, -y)
		return true
	end
	return false
end
function ns.Shown(region, on)
	on = on and true or false
	if region.shyShown ~= on then
		region.shyShown = on
		region:SetShown(on)
	end
end

-- The errors are ShyCore's own window, until the task manager has a view of them.
function T:Open(view, key)
	if view == "errors" and not ns.Window.Views().errors then
		Shy.Errors.Open()
		return
	end
	ns.Window.Open(view or "addons", key)
end

function T:OpenWindow()
	ns.Window.Open("addons")
end

local function AddonNamed(word)
	for _, addon in ipairs(Shy.order) do
		if addon.name:lower() == word or addon.suffix:lower() == word or ("shy" .. addon.suffix:lower()) == word then return addon.name end
	end
end

SLASH_SHYMONITOR1 = "/shymonitor"
SLASH_SHYMONITOR2 = "/shymon"
SlashCmdList.SHYMONITOR = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		ns.Window.Toggle()
	elseif cmd == "errors" then
		T:Open("errors")
	elseif AddonNamed(cmd) then
		ns.Window.Open("addon", AddonNamed(cmd))
	else
		T:Print("commands:")
		print("  /shymon  - open or close the task manager")
		print("  /shymon <addon>  - open at that addon")
		print("  /shymon errors  - the errors caught")
	end
end
