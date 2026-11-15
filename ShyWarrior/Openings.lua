-- Openings: while an ability is there to be used, its own icon in the cooldown manager lights up in your color,
-- a frame and a sheen across it; one the cooldown manager doesn't show (Raging Blow, or one taken off it) lights
-- on the action bar instead. Execute, Overpower, Revenge, Victory Rush and Raging Blow as the game makes them
-- usable; Overpower also for a few seconds after your target dodges, framed in gold with the stance it needs
-- when you stand in another; Pummel or Shield Bash while your target casts something you can interrupt;
-- Charge or Intercept while your target is in reach; Taunt in red when a mob you were tanking turns to someone
-- else (Threat.lua calls ns.Openings.Aggro). Only what the game answers in a fight is asked: whether a spell is
-- usable and in range, never an aura. The light is our own textures on the game's buttons, nothing more.

local ADDON, ns = ...
local T = ns.T
local UI, Slot, B, Theme = Shy.UI, Shy.Slot, Shy.Brand, Shy.Theme

local O = {}
ns.Openings = O

local DODGE = 5              -- seconds Overpower stays open after a dodge
local AGGRO = 8              -- seconds the Taunt cue stays at most
local EVERY = 0.15           -- seconds between looks while a target is there (range changes with no event)
local BUTTON = 45            -- the size the art is drawn for; other icons scale from it
local RIM = 3                -- how far a button's frame overlaps its icon
local SWEEP_TIME, SWEEP_REST = 0.7, 0.5
local LOST = { 0.95, 0.24, 0.32 }
local VIEWERS = { { name = "EssentialCooldownViewer", size = 50 }, { name = "UtilityCooldownViewer", size = 30 } }
local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft",
	"MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7" }
local KEYS = { "execute", "overpower", "revenge", "victoryRush", "ragingBlow", "pummel", "shieldBash",
	"charge", "intercept", "taunt", "mockingBlow", "battleShout", "commandingShout" }

local lit = {}               -- key -> { look = "open" | "stance" | "aggro", note } while it should light
local was = {}               -- key -> true for what lit at the last look (for the sound)
local arts = setmetatable({}, { __mode = "k" })   -- button -> its art
local byID = {}              -- any rank's spell ID -> key
for _, key in ipairs(KEYS) do
	for _, id in ipairs(ns.spells[key].ranks) do byID[id] = key end
end
local dodgedAt = 0
local aggro                  -- { at } while a mob you tanked has turned
local driver

local function Enemy()
	return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target")
end

local function Usable(id)
	return C_Spell.IsSpellUsable(id) == true
end

-- What should light now, into `lit`.
local function Light(key, look, note)
	lit[key] = { look = look, note = note }
end

local function Interrupt()
	local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo("target")
	if name == nil then
		local channel, _, _, _, _, _, chNot = UnitChannelInfo("target")
		name, notInterruptible = channel, chNot
	end
	if name == nil or issecretvalue(name) or issecretvalue(notInterruptible) or notInterruptible then return end
	local fallback
	for _, key in ipairs({ "shieldBash", "pummel" }) do
		local id = ns.Known(key)
		if id and ns.Ready(id) then
			if Usable(id) then return Light(key, "open") end
			local fits, stance = ns.Stance(key)
			if not fits and not fallback then fallback = { key, stance } end
		end
	end
	if fallback then Light(fallback[1], "stance", fallback[2]) end
end

local function Reach()
	for _, key in ipairs({ "charge", "intercept" }) do
		local id = ns.Known(key)
		if id and Usable(id) and ns.Ready(id) and C_Spell.IsSpellInRange(id, "target") == true then
			return Light(key, "open")
		end
	end
end

local function Aggro()
	if not aggro then return end
	if GetTime() - aggro.at > AGGRO then
		aggro = nil
		return
	end
	for _, key in ipairs({ "taunt", "mockingBlow" }) do
		local id = ns.Known(key)
		if id and ns.Ready(id) then return Light(key, "aggro") end
	end
end

local function Opening(key, dodge)
	local id = ns.Known(key)
	if not id or not ns.Ready(id) then return end
	if Usable(id) then return Light(key, "open") end
	if dodge and GetTime() - dodgedAt < DODGE then
		local fits, stance = ns.Stance(key)
		if not fits then Light(key, "stance", stance) end
	end
end

local function Ask()
	wipe(lit)
	Aggro()
	for _, key in ipairs(ns.Shout.Wanted()) do Light(key, "open") end
	if not T.db.openings.shown or not Enemy() then return end
	if T.db.openings.interrupt then Interrupt() end
	for _, key in ipairs({ "execute", "revenge", "victoryRush", "ragingBlow" }) do Opening(key) end
	Opening("overpower", true)
	if T.db.openings.charge then Reach() end
end

---------------------------------------------------------------------------
-- The light on a button
---------------------------------------------------------------------------

local function Piece(button, layer, sublevel, piece, k)
	local t = button:CreateTexture(nil, layer, nil, sublevel)
	Slot.Follow(t, piece, button)
	t:SetScale(k)
	return t
end

local function Art(button, size)
	local art = arts[button]
	if art then return art end
	local k = size / BUTTON
	art = { k = k }
	art.glow = Piece(button, "ARTWORK", 6, "glow", k)
	art.glow:SetBlendMode("ADD")
	art.rim = Piece(button, "OVERLAY", 2, "frame", k * 1.4)
	local mask = button:CreateMaskTexture()
	Slot.Follow(mask, "mask", button, RIM * k, RIM * k)
	art.wash = button:CreateTexture(nil, "ARTWORK", nil, 6)
	art.wash:SetPoint("TOPLEFT", button, "TOPLEFT", RIM * k, -RIM * k)
	art.wash:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -RIM * k, RIM * k)
	art.wash:SetColorTexture(1, 1, 1)
	art.wash:SetBlendMode("ADD")
	art.wash:AddMaskTexture(mask)
	-- A looping, masked animation: no script runs while it sweeps.
	local inner = size - 2 * RIM * k
	art.sheen = button:CreateTexture(nil, "ARTWORK", nil, 7)
	art.sheen:SetTexture(B.SHEEN)
	art.sheen:SetBlendMode("ADD")
	art.sheen:SetAlpha(0.55)
	art.sheen:SetSize(inner, inner)
	art.sheen:SetPoint("CENTER", button, "CENTER", -inner, 0)
	art.sheen:AddMaskTexture(mask)
	art.sweep = art.sheen:CreateAnimationGroup()
	art.sweep:SetLooping("REPEAT")
	local cross = art.sweep:CreateAnimation("Translation")
	cross:SetOffset(2 * inner, 0)
	cross:SetDuration(SWEEP_TIME)
	cross:SetEndDelay(SWEEP_REST)
	-- The stance it needs, small, on a fade at the icon's foot.
	art.fade = button:CreateTexture(nil, "OVERLAY", nil, 3)
	art.fade:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", RIM * k, RIM * k)
	art.fade:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -RIM * k, RIM * k)
	art.fade:SetHeight(size * 0.42)
	art.fade:SetColorTexture(1, 1, 1)
	art.fade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.9), CreateColor(0, 0, 0, 0))
	art.note = button:CreateFontString(nil, "OVERLAY")
	art.note:SetFontObject(UI.NameFont(math.max(8, math.floor(size * 0.2 + 0.5)), "OUTLINE"))
	art.note:SetPoint("BOTTOM", button, "BOTTOM", 0, RIM * k + 1)
	art.note:SetWidth(size - 2 * RIM * k)
	art.note:SetWordWrap(false)
	art.parts = { art.glow, art.rim, art.wash, art.sheen, art.fade, art.note }
	for _, part in ipairs(art.parts) do part:Hide() end
	arts[button] = art
	return art
end

-- Lights a button in a look, or (nil) puts it out.
local function Paint(button, size, light)
	local art = light and Art(button, size) or arts[button]
	if not art then return end
	local look, note = light and light.look, light and light.note
	if art.look == look and art.noted == note then return end
	art.look, art.noted = look, note
	if not look then
		for _, part in ipairs(art.parts) do part:Hide() end
		art.sweep:Stop()
		return
	end
	local r, g, b
	if look == "aggro" then
		r, g, b = LOST[1], LOST[2], LOST[3]
	elseif look == "stance" then
		local c = UI.colors.alert
		r, g, b = c[1], c[2], c[3]
	else
		r, g, b = Theme.Accent()
	end
	art.glow:SetVertexColor(r, g, b, look == "stance" and 0.45 or 0.9)
	art.rim:SetVertexColor(r, g, b)
	art.wash:SetVertexColor(r, g, b, look == "stance" and 0 or 0.14)
	for _, part in ipairs({ art.glow, art.rim, art.wash }) do part:Show() end
	local moving = look ~= "stance"
	art.sheen:SetShown(moving)
	if moving then art.sweep:Play() else art.sweep:Stop() end
	art.note:SetText(note or "")
	art.note:SetTextColor(r, g, b)
	art.note:SetShown(note ~= nil)
	art.fade:SetShown(note ~= nil)
end

-- The cooldown viewers' icons, once Blizzard_CooldownViewer has loaded. Their icons are pooled: whatever an
-- icon held at the last look, it is asked again.
local function EachItem(fn)
	if not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then return end
	for _, v in ipairs(VIEWERS) do
		local viewer = _G[v.name]
		if viewer and viewer.itemFramePool then
			for item in viewer.itemFramePool:EnumerateActive() do
				if not issecretvalue(item) then fn(item, v.size, viewer) end
			end
		end
	end
end

local function ItemKey(item)
	local ok, shown = pcall(item.GetSpellID, item)
	if ok and shown ~= nil and not issecretvalue(shown) and byID[shown] then return byID[shown] end
	local base = item:GetBaseSpellID()
	if base ~= nil and not issecretvalue(base) then return byID[base] end
end

local function ButtonKey(button)
	local action = button.action
	if action == nil or issecretvalue(action) then return end
	local kind, id, sub = GetActionInfo(action)
	if not canaccessvalue(kind, id, sub) then return end
	if kind == "spell" or (kind == "macro" and sub == "spell") then return byID[id] end
end

local function Show()
	local shown = {}             -- keys lit on a cooldown icon in view
	EachItem(function(item, size)
		local key = ItemKey(item)
		local light = key and lit[key]
		Paint(item, size, light)
		if light and item:IsVisible() then shown[key] = true end
	end)
	for _, name in ipairs(BARS) do
		local bar = _G[name]
		for _, button in ipairs(bar and bar.actionButtons or {}) do
			local key = ButtonKey(button)
			local light = key and not shown[key] and lit[key] or nil
			Paint(button, BUTTON, light)
			if light and button:IsVisible() then shown[key] = true end
		end
	end
	ns.Shout.Placed(shown)
end

local function Update()
	Ask()
	local came = false
	for key, light in pairs(lit) do
		if light.look == "open" and not was[key] then came = true end
	end
	wipe(was)
	for key, light in pairs(lit) do was[key] = light.look == "open" end
	if came and T.db.openings.sound then PlaySound(SOUNDKIT.MAP_PING, "Master") end
	Show()
end
O.Update = Update

-- What lights now, for the tests and the report: key -> look.
function O.Lit()
	local out = {}
	for key, light in pairs(lit) do out[key] = light.look end
	return out
end

-- A mob you were tanking has turned (or, with false, you have it back).
function O.Aggro(lost)
	aggro = lost and { at = GetTime() } or nil
	Update()
	if aggro then driver:Show() end
end

local function Watching()
	return aggro ~= nil or Enemy()
end

function ns.SetupOpenings()
	driver = CreateFrame("Frame")
	local wait = 0
	driver:SetScript("OnUpdate", function(self, dt)
		wait = wait - dt
		if wait > 0 then return end
		wait = EVERY
		Update()
		if not Watching() then self:Hide() end
	end)

	local hooked = false
	local function Hook()
		if hooked or not C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer") then return end
		hooked = true
		for _, v in ipairs(VIEWERS) do
			local viewer = _G[v.name]
			-- The viewer hands its icons out again: light them as they now are, next frame.
			if viewer then hooksecurefunc(viewer, "RefreshData", function() C_Timer.After(0, Show) end) end
		end
	end
	Hook()

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN",
		"UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ACTIONBAR_SLOT_CHANGED",
		"ADDON_LOADED" }) do
		events:RegisterEvent(event)
	end
	events:RegisterUnitEvent("UNIT_COMBAT", "target")
	for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED" }) do
		events:RegisterUnitEvent(event, "target")
	end
	events:SetScript("OnEvent", function(_, event, arg, action)
		if event == "ADDON_LOADED" then
			if arg == "Blizzard_CooldownViewer" then Hook() end
			return
		elseif event == "UNIT_COMBAT" then
			if issecretvalue(action) or action ~= "DODGE" then return end
			dodgedAt = GetTime()
		elseif event == "PLAYER_TARGET_CHANGED" then
			dodgedAt = 0
		end
		Update()
		if Watching() then driver:Show() end
	end)
	-- Your color moved: what is lit in it is painted again.
	Shy:On("SHY_THEME", function()
		for _, art in pairs(arts) do art.look = nil end
		Show()
	end)
	table.insert(ns.refreshers, Update)
	Update()
end
