-- The feature registry: every tweak is an ns.Feature that switches on and off live.
--
-- ns.Feature{ id, category, title, desc, keywords, default,
--   options = { { key, kind = "checkbox"|"slider"|"dropdown"|"input"|"button", label, desc, default, ... } },
--   events = { EVENT = function(feature, event, ...) end },   -- registered only while on
--   Enable(feature), Disable(feature), OnOptionChanged(feature, key),
--   yields(),          -- true while another addon does this: the tweak stands down and its row is left out
--   leftOut(),         -- true while its row alone is left out: the tweak keeps out of the other's way itself
--   says(feature) }    -- a few words after its name in the settings: what the game does about it by itself
-- A button option says its word (`button`) and what it does (`run`); any option may say when it is `shown`.
-- feature.opt.<key> reads an option. Disable only undoes what Enable did: it never runs for a tweak that was
-- not on.

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Tweaks",
	category = "interface",
	icon = "Interface\\AddOns\\ShyTweaks\\Media\\ShyTweaks",
	smallIcon = "Interface\\AddOns\\ShyTweaks\\Media\\ShyTweaksSmall",
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

function FeatureMixin:Yields()
	return self.yields ~= nil and self.yields() == true
end

-- Its row isn't told for now: another addon does this, whether the tweak stands down or keeps itself away.
function FeatureMixin:Away()
	return self:Yields() or (self.leftOut ~= nil and self.leftOut() == true)
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
	local on = (self:IsOn() and not self:Yields()) or false
	if on == (self.running or false) then
		self.running = on
		return
	end
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

-- Another addon took a job over or gave it back: the tweaks that stand down for one look again (those that
-- have started: login starts them all).
local function Resync()
	for _, f in ipairs(ns.features) do
		if f.yields and f.running ~= nil then f:Sync() end
	end
	Shy.Settings.Refresh()
end
for _, bus in ipairs({ "SHY_BAGS_OWNS", "SHY_SKIN_OWNS", "SHY_NAMEPLATES" }) do Shy:On(bus, Resync) end

-- For addons drawing the game's aura icons (ShyBuffs): whether "Who cast that buff" wants a caster
-- shown on a debuff (harmful true) or a buff.
function T:CasterShown(harmful)
	local f = byId.casters
	if not f or not f.running then return false end
	if harmful then return f.opt.debuffs == true end
	return f.opt.buffs == true
end

-- For other addons (Shy.addons.Tweaks:IsTweakOn(id)): whether a tweak is on and at work. ShyCore's setup
-- asks it before offering a game setting a tweak switches itself.
function T:IsTweakOn(id)
	local f = byId[id]
	return f ~= nil and self.db ~= nil and self.db.features[id] == true and not f:Yields()
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

-- A game setting a tweak holds while it is on. What you had is kept once, however many tweaks hold the same
-- setting, and comes back when the last of them lets go.
local function Had(cvar)
	for _, saved in pairs(T.db.options) do
		local restore = type(saved) == "table" and saved.restore
		if restore and restore[cvar] ~= nil then return restore[cvar] end
	end
end

local function Same(a, b)
	if a == b then return true end
	local x, y = tonumber(a), tonumber(b)
	return x ~= nil and x == y
end

function ns.TakeCVar(feature, cvar, value)
	local now = GetCVar(cvar)
	if now == nil then return end   -- (the game has no such setting)
	local saved = T.db.options[feature.id]
	saved.restore = saved.restore or {}
	if saved.restore[cvar] == nil then
		local had = Had(cvar)
		if had == nil then had = now end
		saved.restore[cvar] = had
	end
	if not Same(now, value) then SetCVar(cvar, value) end
end

function ns.ReturnCVar(feature, cvar)
	local restore = T.db.options[feature.id].restore
	local had = restore and restore[cvar]
	if had == nil then return end
	restore[cvar] = nil
	if Had(cvar) == nil and not Same(GetCVar(cvar), had) then SetCVar(cvar, had) end
end

-- For other addons (Shy.addons.Tweaks:Holds(cvar)): whether a tweak holds this game setting right now.
function T:Holds(cvar)
	return self.db ~= nil and Had(cvar) ~= nil
end

-- Holding Shift skips automation for one interaction.
function ns.Paused()
	return IsShiftKeyDown()
end

function T:OnLoad()
	if ns.TellSettings then ns.TellSettings() end
end

-- Tweaks that are gone. Each hands back the game settings it took, and its switch is forgotten.
local RETIRED = { "combatPlates", "declineGuild" }

-- A tweak that isn't at work holds no game setting: one that is gone, or one switched off in a fight you
-- logged out of.
local function ReturnLeftovers(db)
	for id, saved in pairs(db.options) do
		local f = byId[id]
		if type(saved) == "table" and saved.restore and not (f and f:IsOn() and not f:Yields()) then
			for cvar, value in pairs(saved.restore) do
				saved.restore[cvar] = nil
				if Had(cvar) == nil and GetCVar(cvar) ~= nil then SetCVar(cvar, value) end
			end
			saved.restore = nil
		end
	end
	for _, id in ipairs(RETIRED) do
		if not byId[id] then db.features[id], db.options[id] = nil, nil end
	end
end

-- Declining strangers' invites was a switch under party invites, and accepting was a second switch under
-- the first. Declining is one of the things strangers are turned away for now, and accepting is the tweak.
local function MoveInvites(db)
	local old, strangers = db.options.partyInvites, db.options.strangers
	if type(old) ~= "table" or (old.acceptKnown == nil and old.declineStrangers == nil) then return end
	if db.features.partyInvites == true and type(strangers) == "table" then
		if old.declineStrangers == true then
			if db.features.strangers ~= true then
				db.features.strangers = true
				strangers.requests, strangers.quests, strangers.battleNet = false, false, false
			end
			strangers.invites = true
		end
		if old.acceptKnown == false then db.features.partyInvites = false end
	end
	old.acceptKnown, old.declineStrangers = nil, nil
end

function T:OnLogin()
	MoveInvites(self.db)
	ReturnLeftovers(self.db)
	for _, f in ipairs(ns.features) do f:Sync() end
end

function T:ResetAll()
	-- A fight keeps some tweaks from letting go. Everything goes back together once it ends.
	if InCombatLockdown() then
		ns.OutOfCombat("reset", function()
			T:ResetAll()
			Shy.Settings.Refresh()
		end)
		T:Print("your tweaks go back to their defaults when the fight ends.")
		return
	end
	for _, f in ipairs(ns.features) do
		if f.running then
			self.db.features[f.id] = false
			f:Sync()
		end
	end
	if ns.ResetWindows then ns.ResetWindows() end
	self:ResetDB()
	for _, f in ipairs(ns.features) do f:Sync() end
end

T:Command("resetwindows", "put the windows and bags you moved back", function()
	if ns.ResetWindows then ns.ResetWindows() end
	if ns.ResetBags then ns.ResetBags() end
	T:Print("your windows and bags are back where the game puts them.")
end)

-- (For finding faults: who cast each buff on you, and what the last buff tooltip showed. Not listed.)
T:Command("casters", nil, function()
	if ns.CastersReport then Shy.UI.ShowCopyBox("Who cast that buff", ns.CastersReport()) end
end)
