-- Stands a default row down while ours has its place, with Frame:SetRolesets("alwaysBlocked"), keeping each
-- frame's own tags to restore. Hide or SetPoint on them would taint Edit Mode, and Blizzard shows them again itself.
-- SetRolesets is protected: out of combat only. IsRolesetFiltered() confirms the engine took it.

local ADDON, ns = ...
local T = ns.T

local B = {}
ns.Blizzard = B

local BLOCKED = "alwaysBlocked"
local FRAMES = { "BuffFrame", "DebuffFrame" }

local own = {}      -- frame name -> its rolesets before we blocked it (false for none)
local refused       -- the engine didn't filter them: don't retry this session

local function Restore(name)
	_G[name]:SetRolesets(own[name] or nil)
	own[name] = nil
end

local function StandDown(name)
	local frame = _G[name]
	local tags = frame:GetRolesetNames()
	-- A frame with no tags returns "roleless".
	own[name] = (#tags > 0 and tags[1] ~= "roleless") and table.concat(tags, ",") or false
	frame:SetRolesets(BLOCKED)
	-- Only a shown frame can confirm the engine filters it.
	if frame:IsShown() and not frame:IsRolesetFiltered() then return false end
	return true
end

-- A default row goes when ours takes its place beside the minimap: the shelf's buffs, or its debuffs.
local function Wanted(name)
	if refused then return false end
	if name == "DebuffFrame" then return T.db.debuffs end
	return T.db.shelf
end

local function Sync()
	for _, name in ipairs(FRAMES) do
		local want = Wanted(name)
		if want and own[name] == nil then
			if not StandDown(name) then
				refused = true
				for stood in pairs(own) do Restore(stood) end
				T:Print("couldn't hide the default buffs, so they stay on.")
				return
			end
		elseif not want and own[name] ~= nil then
			Restore(name)
		end
	end
end

function B.IsDown(name)
	return own[name] ~= nil
end

local waiting
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
	if waiting then
		waiting = nil
		Sync()
	end
end)

function B.Apply()
	if InCombatLockdown() then
		waiting = true
	else
		Sync()
	end
end
