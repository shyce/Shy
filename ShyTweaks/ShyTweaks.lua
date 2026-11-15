-- The feature registry: every tweak is an ns.Feature that switches on and off live.
--
-- ns.Feature{ id, category, title, desc, keywords, default,
--   options = { { key, kind = "checkbox"|"slider"|"dropdown"|"input"|"button", label, default, ... } },
--   events = { EVENT = function(feature, event, ...) end },   -- registered only while on
--   Enable(feature), Disable(feature), OnOptionChanged(feature, key) }
-- feature.opt.<key> reads an option.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Tweaks",
	icon = "Interface\\AddOns\\ShyTweaks\\Media\\ShyTweaks",
	smallIcon = "Interface\\AddOns\\ShyTweaks\\Media\\ShyTweaksSmall",
	tagline = "Quality-of-life tweaks you switch on and off",
	savedVariables = "ShyTweaksDB",
	defaults = { features = {}, options = {}, frames = {}, bagOffset = { x = 0, y = 0 } },
})
ns.T = T

ns.CATEGORIES = { "Windows", "Quests & NPCs", "Loot & vendors", "Social", "Combat", "System" }
ns.features = {}
local byId = {}

local FeatureMixin = {}

function FeatureMixin:IsOn()
	return T.db.features[self.id]
end

local function Dispatch(frame, event, ...)
	local handler = frame.feature.events[event]
	if handler then handler(frame.feature, event, ...) end
end

function FeatureMixin:SetOn(on)
	T.db.features[self.id] = on
	self:Sync()
end

function FeatureMixin:Sync()
	local on = self:IsOn()
	if on == self.running then return end
	self.running = on
	if self.events then
		self.eventFrame = self.eventFrame or CreateFrame("Frame")
		self.eventFrame.feature = self
		self.eventFrame:SetScript("OnEvent", Dispatch)
		for event in pairs(self.events) do
			if on then self.eventFrame:RegisterEvent(event) else self.eventFrame:UnregisterEvent(event) end
		end
	end
	local fn = on and self.Enable or self.Disable
	if fn then fn(self) end
end

function FeatureMixin:SetOption(key, value)
	T.db.options[self.id][key] = value   -- saved; feature.opt reads through to it
	if self.running and self.OnOptionChanged then self:OnOptionChanged(key) end
end

function ns.Feature(def)
	local f = Mixin(def, FeatureMixin)
	f.opt = setmetatable({}, { __index = function(_, key) return T.db.options[f.id][key] end })
	T.defaults.features[f.id] = f.default or false
	local optDefaults = {}
	for _, o in ipairs(f.options or {}) do
		if o.key then optDefaults[o.key] = o.default end
	end
	T.defaults.options[f.id] = optDefaults
	table.insert(ns.features, f)
	byId[f.id] = f
	return f
end

function ns.Get(id) return byId[id] end

-- For addons drawing the game's aura icons (ShyBuffs): whether "Show who cast a buff" wants a caster
-- shown on a debuff (harmful true) or a buff.
function T:CasterShown(harmful)
	local f = byId.casters
	if not f or not f.running then return false end
	if harmful then return f.opt.debuffs == true end
	return f.opt.buffs == true
end

-- For other addons (Shy.addons.Tweaks:IsTweakOn(id)): whether a tweak is on. ShyCore's setup asks it
-- before offering a game setting a tweak switches itself.
function T:IsTweakOn(id)
	return self.db ~= nil and self.db.features[id] == true
end

-- Run fn now, or once combat ends (protected frames can't change in combat).
local afterCombat = {}
function ns.OutOfCombat(key, fn)
	if InCombatLockdown() then
		afterCombat[key] = fn
	else
		fn()
	end
end

local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function()
	for key, fn in pairs(afterCombat) do
		afterCombat[key] = nil
		fn()
	end
end)

-- Saves a CVar's value in the feature's options before changing it; ReturnCVar restores it.
function ns.TakeCVar(feature, cvar, value)
	local saved = T.db.options[feature.id]
	saved.restore = saved.restore or {}
	if saved.restore[cvar] == nil then saved.restore[cvar] = GetCVar(cvar) end
	SetCVar(cvar, value)
end

function ns.ReturnCVar(feature, cvar)
	local restore = T.db.options[feature.id].restore
	if restore and restore[cvar] ~= nil then
		SetCVar(cvar, restore[cvar])
		restore[cvar] = nil
	end
end

-- Holding Shift skips automation for one interaction.
function ns.Paused()
	return IsShiftKeyDown()
end

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

-- A feature that is no longer here hands back the game settings it took.
local function ReturnOrphans(db)
	local known = {}
	for _, f in ipairs(ns.features) do known[f.id] = true end
	for id, saved in pairs(db.options or {}) do
		if not known[id] and type(saved) == "table" and saved.restore then
			for cvar, value in pairs(saved.restore) do SetCVar(cvar, value) end
			saved.restore = nil
		end
	end
end

function T:OnLogin()
	ReturnOrphans(self.db)
	for _, f in ipairs(ns.features) do f:Sync() end
end

function T:ResetAll()
	for _, f in ipairs(ns.features) do
		if f.running then
			self.db.features[f.id] = false
			f:Sync()
		end
	end
	self:ResetDB()
	for _, f in ipairs(ns.features) do f:Sync() end
	if ns.ResetWindows then ns.ResetWindows() end
end

SLASH_SHYTWEAKS1 = "/shytweaks"
SLASH_SHYTWEAKS2 = "/stw"
SlashCmdList.SHYTWEAKS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "resetwindows" then
		if ns.ResetWindows then ns.ResetWindows() end
		T:Print("windows and bags reset.")
	elseif cmd == "casters" and ns.CastersReport then
		Shy.UI.ShowCopyBox("ShyTweaks: who cast a buff", ns.CastersReport())
	elseif cmd == "" then
		T:OpenOptions()
	else
		T:Print("commands:")
		print("  /shytweaks  - open options")
		print("  /shytweaks resetwindows  - reset moved windows and bags")
		print("  /shytweaks casters  - who cast each buff on you, and what the last buff tooltip showed")
	end
end
