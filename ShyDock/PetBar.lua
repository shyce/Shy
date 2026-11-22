-- The pet bar's housing: a slim piece in the theme's look round the game's pet bar, as the experience bar under
-- the bars wears, for every class with a pet. The console plans its room (Console.PET).
--
-- Like the racks, it follows the bar by reading its rectangle: never anchored to it (the bar is protected) and
-- never drawn on it (a bar measures its regions to lay out). It shows while the console's layout is in use, the
-- bar stands where the layout put it and the game shows it: a pet out. A bar you moved yourself gets none.

local ADDON, ns = ...
local T = ns.T
local UI, Console = Shy.UI, ns.Console

local B = {}
ns.PetBar = B

local SETTLE = 0.3
local EVENTS = { "PLAYER_ENTERING_WORLD", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED",
	"PET_BAR_UPDATE", "PLAYER_REGEN_ENABLED" }

local piece, driver, pending

-- Whether the layout in use is the console's and has the pet bar where it put it.
local function Placed()
	if not (T.db.housing and ns.Layout.IsActive()) then return false end
	return ns.Layout.InPlace(Enum.EditModeSystem.ActionBar, Enum.EditModeActionBarSystemIndices.PetActionBar)
end

function B.Measure()
	local left, bottom, right, top = Console.Rect(PetActionBar)
	if left == false then return end   -- secret rect: keep the last place
	if not left or not Placed() then
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

function B.Touch()
	if pending or not piece then return end
	pending = true
	C_Timer.After(0, B.Measure)
	C_Timer.After(SETTLE, function()
		pending = nil
		B.Measure()
	end)
end

function B.Apply()
	if not piece then return end
	UI.SetFill(piece, ns.Graphite)
	B.Measure()
end

function B.Start()
	-- LOW, like the housing and the racks: under the bar's buttons.
	piece = CreateFrame("Frame", "ShyDockPetBar", UIParent)
	piece:SetFrameStrata("LOW")
	piece:SetFrameLevel(30)
	piece:EnableMouse(false)
	piece:Hide()
	UI.Panel(piece, { hud = true, mini = true, slim = true, brackets = false, line = false })
	B.frame = piece

	driver = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do driver:RegisterEvent(event) end
	driver:RegisterUnitEvent("UNIT_PET", "player")
	driver:SetScript("OnEvent", B.Touch)
	-- The game shows and hides the bar itself, in a fight too: the housing goes with it.
	PetActionBar:HookScript("OnShow", B.Touch)
	PetActionBar:HookScript("OnHide", function() piece:Hide() end)
	EventRegistry:RegisterCallback("EditMode.SavedLayouts", B.Touch, B)
	EventRegistry:RegisterCallback("EditMode.Enter", function() driver:SetScript("OnUpdate", B.Measure) end, B)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		driver:SetScript("OnUpdate", nil)
		B.Touch()
	end, B)
	Shy:On("SHY_CONSOLE", B.Touch)
	B.Apply()
end
