-- The game's own frames in layout mode: everything Edit Mode places (bars, chat, bags, micro menu,
-- minimap, loot, alerts and the rest) and the beta's issue reporter. Each is adopted into Shy.HUD
-- unless an addon has taken it; an addon that takes one later wins. Edit Mode frames move and resize
-- with their Base methods, so no Edit Mode code runs from here; one the player moves in Edit Mode
-- goes back to Edit Mode.

local HUD = Shy.HUD

local F = {}
HUD.Frames = F

-- Left out: the main bar's end caps are its art.
local SKIP = { [Enum.EditModeSystem.MainActionBarEndCap] = true }
-- Kept at the game's size: docked chat windows and their tabs don't follow the first window's scale.
local FIXED = { [Enum.EditModeSystem.ChatFrame] = true }

local function Title(frame)
	local ok, name = pcall(frame.GetSystemName, frame)
	if ok and type(name) == "string" and name ~= "" then return name end
	return frame:GetName() or "Game frame"
end

local function Adopt(frame, id, title, editMode, scale)
	if HUD.Adopted(frame) then return end
	HUD.Adopt(frame, { id = id, title = title, editMode = editMode, plain = editMode, scale = scale, generic = true })
end

function F.AdoptAll()
	for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
		local system = frame.system
		if system and not SKIP[system] then
			local id = "game." .. (frame:GetName() or (system .. "." .. (frame.systemIndex or 0)))
			Adopt(frame, id, Title(frame), true, not FIXED[system])
		end
	end
	local reporter = PTR_IssueReporter   -- only on a client with the beta's reporting tool
	if reporter then Adopt(reporter, "game.PTR_IssueReporter", "Issue reporter", false, true) end
end

-- After the frame that fired, so an addon adopting on the same event goes first. Systems that load
-- later (the cooldown viewers, the damage meter) register with Edit Mode as their addon loads.
local ready, soon = false, false
local function Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = false
		F.AdoptAll()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then ready = true end
	if ready then Soon() end
end)
