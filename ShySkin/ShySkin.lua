-- ShySkin: restyles Blizzard's default UI. A module fades Blizzard's art and draws its own through a
-- Shy.Skin kit: regions only, so it is safe on protected buttons and in combat, and fully restorable.
--
-- ns.Module{...}:
--   id, title, desc                -- shown in the options
--   options = { { key =, label =, desc =, default = } }
--   Ready(m)        -- optional: false while its Blizzard frames aren't loaded
--   Switch(m, on)   -- optional: on every refresh, before Ready is asked (what doesn't wait for the game's frames)
--   Hook(m)         -- once, on first switch-on: post-hooks where Blizzard redraws
--   Paint(m, kit)   -- must be safe to run again at any time
--   Clear(m)        -- optional: restore what the kit doesn't track (m.on is already the new state)
-- m.opt.<key> reads an option; m.on is true while the module is painting.
--
-- Kits are restored and repainted on SHY_THEME, so painters read colors as they run, never copies.
--
-- Shared helpers:
--   ns.HideDividers(kit, bar)              -- the lines between a bar's buttons
--   ns.Number(kit, fontString)             -- the rounded number font
--   ns.Lit(kit, texture, button, color)    -- pressed / active art as the slot's glow
--   ns.Close(kit, button, inset, glyph, size)   -- a window's close (or maximize, restore) as a keyed square
--   ns.Own(kit, owner, key, build)         -- our own region, made once per frame, hidden with the module
--   ns.Gloss(kit, owner, opts)             -- a highlight across the top of a strip or button
--   ns.AfterCombat(key, fn)                -- run now, or when combat ends
--
-- Widgets.lua has painters for Blizzard's stock controls. One module per file; Spellbook (with
-- Talents.lua) is the exception to "regions only": it lays its window out again (Shop.lua's attic; its
-- spells are secure buttons of ours). Merchant, Trainer, Mail, Professions, Social and Guild go further: a
-- window of our own in the game's emptied one.

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShySkin\\Media\\"
local UI = Shy.UI

local T = Shy:NewAddon(ADDON, {
	suffix = "Skin",
	category = "interface",
	icon = MEDIA .. "ShySkin",
	smallIcon = MEDIA .. "ShySkinSmall",
	savedVariables = "ShySkinDB",
	defaults = { modules = {}, options = {} },
})
ns.T = T

-- For other addons, through Shy.addons.Skin: .owns[piece] is true while a module here provides that
-- piece and the other addon should not (SHY_SKIN_OWNS fires on change).
--   trainAll   the trainer window has its own "Train all"; ShyTweaks hides its button
--   flights    the flight master's window offers the guide's flight; ShyQuest doesn't take it the moment the map opens
T.owns = {}

function ns.Claim(piece, on)
	on = on and true or nil
	if T.owns[piece] == on then return end
	T.owns[piece] = on
	Shy:Fire("SHY_SKIN_OWNS", piece, on == true)
end

ns.modules = {}
local byId = {}
local started = false

-- Combat lockdown: frames that protected frames are anchored to can't be moved or sized in combat.

local jobs, order = {}, {}   -- key -> job, and the keys in request order
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function()
	if #order == 0 then return end
	local todo, keys = jobs, order
	jobs, order = {}, {}
	for _, key in ipairs(keys) do todo[key]() end
end)

-- Runs fn now, or when combat ends. One job per key: a newer one replaces the waiting one.
-- Returns true when it ran at once.
function ns.AfterCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return true
	end
	if not jobs[key] then order[#order + 1] = key end
	jobs[key] = fn
	return false
end

-- Our own regions: made once per frame, hidden when the kit is restored.

local made = setmetatable({}, { __mode = "k" })   -- owner -> key -> region
local worn = setmetatable({}, { __mode = "k" })   -- kit -> regions it is showing

function ns.Own(kit, owner, key, build)
	local regions = made[owner]
	if not regions then
		regions = {}
		made[owner] = regions
	end
	local region = regions[key]
	if not region then
		region = build(owner)
		regions[key] = region
	end
	local showing = worn[kit]
	if not showing then
		showing = {}
		worn[kit] = showing
	end
	showing[region] = true
	region:Show()
	return region
end

local function HideOwn(kit)
	local showing = worn[kit]
	if not showing then return end
	for region in pairs(showing) do region:Hide() end
	wipe(showing)
end

-- opts: key (for a second gloss on one frame), over (region to cover; defaults to owner),
-- x, y or inset = { l, t, r, b }, layer, sublevel, alpha.
function ns.Gloss(kit, owner, opts)
	opts = opts or {}
	local gloss = ns.Own(kit, owner, opts.key or "gloss", function()
		local t = owner:CreateTexture(nil, opts.layer or "ARTWORK", nil, opts.sublevel or 0)
		t:SetTexture(UI.GLOSS)
		return t
	end)
	local over = opts.over or owner
	local x, y = opts.x or 0, opts.y or 0
	local inset = opts.inset or { x, y, x, y }
	gloss:ClearAllPoints()
	gloss:SetPoint("TOPLEFT", over, "TOPLEFT", inset[1], -inset[2])
	gloss:SetPoint("BOTTOMRIGHT", over, "BOTTOMRIGHT", -inset[3], inset[4])
	gloss:SetAlpha(opts.alpha or 1)
	return gloss
end

-- Modules

local ModuleMixin = {}

function ModuleMixin:IsOn()
	return T.db.modules[self.id]
end

-- Restores Blizzard's art, then paints again if the module is on.
local function Sync(m)
	if not started then return end
	-- Whatever a module does before its Blizzard frames are loaded (windows of its own).
	if m.Switch then m.Switch(m, m:IsOn() and true or false) end
	if m.Ready and not m:Ready() then return end
	local on = m:IsOn()
	if not on and not m.on then return end   -- never on: nothing to restore
	if not m.hooked then
		m.hooked = true
		if m.Hook then m:Hook() end
	end
	m.kit:Restore()
	HideOwn(m.kit)
	local was = m.on
	m.on = on
	if was and m.Clear then m:Clear() end
	if on then m:Paint(m.kit) end
end

-- pcall: one module's error must not stop the others.
function ModuleMixin:Refresh()
	local ok, err = pcall(Sync, self)
	if not ok then geterrorhandler()(err) end
end

function ModuleMixin:SetOn(on)
	T.db.modules[self.id] = on
	self:Refresh()
end

function ModuleMixin:SetOption(key, value)
	T.db.options[self.id][key] = value
	self:Refresh()
end

function ns.Module(def)
	local m = Mixin(def, ModuleMixin)
	m.kit = Shy.Skin.NewKit()
	m.on = false
	m.opt = setmetatable({}, { __index = function(_, key) return T.db.options[m.id][key] end })
	T.defaults.modules[m.id] = true
	local optDefaults = {}
	for _, o in ipairs(m.options or {}) do optDefaults[o.key] = o.default end
	T.defaults.options[m.id] = optDefaults
	table.insert(ns.modules, m)
	byId[m.id] = m
	return m
end

function ns.Get(id) return byId[id] end

function T:Apply()
	for _, m in ipairs(ns.modules) do m:Refresh() end
end

-- Shared painters

-- Dividers are pooled and created as the bar lays out.
function ns.HideDividers(kit, bar)
	for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = bar[key]
		if pool then
			for divider in pool:EnumerateActive() do kit:Hide(divider) end
		end
	end
end

function ns.Number(kit, fontString)
	kit:Font(fontString, Shy.FONT_ROUNDED, nil, "OUTLINE")
end

-- The slot's glow in a color, following the slot shape.
function ns.Lit(kit, texture, button, color)
	kit:Lit(texture, button, color)
end

-- A window's close (or maximize, restore) button as the family's: a keyed square with its glyph drawn in it, the
-- size of its header's controls and their glyph (UI.HEAD: "window" unless told; a console piece's is "piece")
-- whatever the button's own. inset = { l, t, r, b }: where in the button the square stands (its middle the middle
-- of that rect). glyph: the cross unless told; size: the glyph's, the header's unless told.
function ns.Close(kit, button, inset, glyph, size, head)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetPushedTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Hide(button:GetDisabledTexture())
	local make = UI.HEAD[head or "window"]
	local slot = make.control
	button:SetSize(slot, slot)
	return kit:Key(button, { inset = { 0, 0, 0, 0 }, size = slot, icon = glyph or UI.CLOSE_GLYPH, iconSize = size or make.glyph, own = true })
end

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	started = true
	self:Apply()
	-- Leaving Edit Mode lays every bar out again.
	EventRegistry:RegisterCallback("EditMode.Exit", function() T:Apply() end, T)
end

-- Kits hold the colors they painted with.
Shy:On("SHY_THEME", function() T:Apply() end)
-- Slots follow a shape change themselves; cooldown swipes are set by the painters.
Shy:On("SHY_SLOT", function() T:Apply() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, isLogin, isReload)
	-- (A login's or a reload's own entering of the world comes a moment after everything was painted at login,
	-- behind the same loading screen: painting it all a second time was half of what a login cost.)
	if event == "ADDON_LOADED" or (event == "PLAYER_ENTERING_WORLD" and (isLogin == true or isReload == true)) then
		-- Load-on-demand Blizzard addons, and frames the game made since login; modules already on are left alone.
		for _, m in ipairs(ns.modules) do
			if not m.on then m:Refresh() end
		end
	else
		T:Apply()
	end
end)

SLASH_SHYSKIN1 = "/shyskin"
SLASH_SHYSKIN2 = "/sskin"
SlashCmdList.SHYSKIN = function(input)
	local cmd = strtrim(input or ""):lower()
	local m = byId[cmd]
	if cmd == "" then
		T:OpenOptions()
	elseif m then
		m:SetOn(not m:IsOn())
		T:Print(m.title .. (m:IsOn() and ": restyled." or ": back to default."))
		if ns.RefreshOptions then ns.RefreshOptions() end
	else
		T:Print("commands:")
		print("  /shyskin  - open options")
		for _, mod in ipairs(ns.modules) do
			print("  /shyskin " .. mod.id .. "  - toggle " .. mod.title:lower())
		end
	end
end
