-- The small bars' housings: a slim piece in the theme's look round the game's pet bar, as the experience bar under
-- the bars wears, for every class with a pet; and one round the stance bar until the console's layout is in use
-- (in use, the cooldown manager holds your stances). The console plans the pet bar's room (Console.PET).
--
-- Like the racks, each follows its bar by reading its rectangle: never anchored to it (the bar is protected) and
-- never drawn on it (a bar measures its regions to lay out). With the console's layout in use the pet bar's shows
-- while the bar stands where the layout put it and the game shows it: a pet out. A bar you moved yourself gets
-- none. Until then both bars stand as the game's layout or your own has them, and each wears its piece there.

local ADDON, ns = ...
local T = ns.T
local UI, Console = Shy.UI, ns.Console

local B = {}
ns.PetBar = B

local SETTLE = 0.3
local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_REGEN_ENABLED" }

-- Each bar, its piece's name and whether it wears one now.
local BARS = {
	{ bar = "PetActionBar", name = "ShyDockPetBar",
		-- The console's layout in use: only where the layout put the bar.
		wears = function(active)
			return not active or ns.Layout.InPlace(Enum.EditModeSystem.ActionBar, Enum.EditModeActionBarSystemIndices.PetActionBar)
		end },
	{ bar = "StanceBar", name = "ShyDockStanceBar", level = 31,   -- over the housing's lip, which it stands on
		wears = function(active) return not active end },
}
local driver, pending

local function Measure(def)
	local piece = def.piece
	local left, bottom, right, top = Console.Rect(_G[def.bar])
	if left == false then return end   -- secret rect: keep the last place
	if not left or not T.db.housing or not def.wears(ns.Layout.IsActive()) then
		piece:Hide()
		return
	end
	local pad = Console.PET.pad
	piece:ClearAllPoints()
	piece:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left - pad, bottom - pad)
	piece:SetSize(right - left + 2 * pad, top - bottom + 2 * pad)
	-- The buttons are its content: a look with a well sinks them, its rim round them.
	UI.LookContent(piece.shyLook, { pad, pad, pad, pad })
	piece:Show()
end

function B.Measure()
	for _, def in ipairs(BARS) do
		if def.piece then Measure(def) end
	end
end

function B.Touch()
	if pending or not B.frame then return end
	pending = true
	C_Timer.After(0, B.Measure)
	C_Timer.After(SETTLE, function()
		pending = nil
		B.Measure()
	end)
end

function B.Apply()
	if not B.frame then return end
	for _, def in ipairs(BARS) do UI.SetFill(def.piece, ns.Graphite) end
	B.Measure()
end

function B.Start()
	for _, def in ipairs(BARS) do
		-- LOW, like the housing and the racks: under the bar's buttons.
		local piece = CreateFrame("Frame", def.name, UIParent)
		piece:SetFrameStrata("LOW")
		piece:SetFrameLevel(def.level or 30)
		piece:EnableMouse(false)
		piece:Hide()
		UI.Panel(piece, { hud = true, mini = true, slim = true, brackets = false, line = false })
		def.piece = piece
		-- The game shows and hides the bar itself, in a fight too: the housing goes with it.
		local bar = _G[def.bar]
		bar:HookScript("OnShow", B.Touch)
		bar:HookScript("OnHide", function() piece:Hide() end)
	end
	B.frame, B.stances = BARS[1].piece, BARS[2].piece

	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:RegisterUnitEvent("UNIT_PET", "player")
	driver:SetScript("OnEvent", B.Touch)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", B.Touch, B)
	EventRegistry:RegisterCallback("EditMode.Enter", function() driver:SetScript("OnUpdate", B.Measure) end, B)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		driver:SetScript("OnUpdate", nil)
		B.Touch()
	end, B)
	Shy:On("SHY_CONSOLE", B.Touch)
	B.Apply()
end
