-- Hides the default unit frames with Frame:SetRolesets("alwaysBlocked"), keeping each frame's own tags to restore.
-- Hide/SetPoint on these frames would taint Edit Mode. SetRolesets is protected: out of combat only.
-- "alwaysBlocked" is an engine name not found in Blizzard's Lua, so IsRolesetFiltered() confirms it afterwards.

local ADDON, ns = ...
local T = ns.T

local B = {}
ns.Blizzard = B

local BLOCKED = "alwaysBlocked"
-- Unit switch -> the default frame it replaces. PetFrame is listed in case Edit Mode detached it from PlayerFrame.
local FRAMES = { player = "PlayerFrame", pet = "PetFrame", target = "TargetFrame", focus = "FocusFrame", party = "PartyFrame" }

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

local function Sync()
	for unit, name in pairs(FRAMES) do
		local want = T.db.hideBlizzard and T.db.units[unit] and not refused
		if want and own[name] == nil then
			if not StandDown(name) then
				refused = true
				for stood in pairs(own) do Restore(stood) end
				T:Print("couldn't hide the default unit frames, so they stay on.")
				return
			end
		elseif not want and own[name] ~= nil then
			Restore(name)
		end
	end
end

function B.IsDown(unit)
	return own[FRAMES[unit]] ~= nil
end

function B.Apply()
	ns.AfterCombat("blizzard", Sync)
end
