-- Fades the main frames (player, target, party) out of combat. Off by default.
-- Alpha is the one property of a secure frame that may change in combat.
-- Secret health or power counts as "hurt", so the frames stay visible.

local ADDON, ns = ...
local T, L, F, Units = ns.T, ns.Layout, ns.Frames, ns.Units

local Fd = {}
ns.Fader = Fd

local OPACITY = { in_combat = 1, target = 1, hurt = 0.75, out_of_combat = 0 }
local PER_SECOND = 2   -- a full fade takes half a second

local state = "out_of_combat"
local changing = {}    -- frames mid-fade
local driver = CreateFrame("Frame")
local pending

function Fd.State()
	return state
end

-- Hurt: health below full, or power off its resting level.
local function Recalculate()
	if UnitAffectingCombat("player") then
		state = "in_combat"
	elseif UnitExists("target") then
		state = "target"
	else
		local hp, max, secret = Units.Health("player")
		local unrested = Units.PowerUnrested()
		if secret or unrested == nil or hp < max or unrested then
			state = "hurt"
		else
			state = "out_of_combat"
		end
	end
end

function Fd.Final(frame)
	if not T.db.fade or not L.LAYOUTS[L.UNITS[frame.kind].layout].fades then return 1 end
	return OPACITY[state]
end

local function Glide(_, elapsed)
	local step, busy = elapsed * PER_SECOND, false
	for frame in pairs(changing) do
		local final = Fd.Final(frame)
		local alpha = frame.alpha or 1
		if alpha < final then alpha = math.min(final, alpha + step) else alpha = math.max(final, alpha - step) end
		frame.alpha = alpha
		frame.button:SetAlpha(alpha)
		if alpha == final then changing[frame] = nil else busy = true end
	end
	if not busy then driver:SetScript("OnUpdate", nil) end
end

-- A hidden frame isn't faded: Fd.Shown sets its alpha when it shows.
local function Start(frame)
	if not frame.button:IsShown() or (frame.alpha or 1) == Fd.Final(frame) then return end
	changing[frame] = true
	driver:SetScript("OnUpdate", Glide)
end

function Fd.Shown(frame)
	local final = Fd.Final(frame)
	frame.alpha = final
	frame.button:SetAlpha(final)
	changing[frame] = nil
end

function Fd.Apply()
	Recalculate()
	for _, frame in ipairs(F.list) do Start(frame) end
end

-- Deferred one frame: a target change and the end of combat arrive together.
local function Due()
	pending = nil
	Fd.Apply()
end
local function Soon()
	if pending then return end
	pending = true
	C_Timer.After(0, Due)
end

function Fd.Start()
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_TARGET_CHANGED")
	for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
		events:RegisterUnitEvent(event, "player")
	end
	events:SetScript("OnEvent", function()
		if T.db.fade then Soon() end
	end)
end
