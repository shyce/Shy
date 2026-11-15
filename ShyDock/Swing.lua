-- The swing timer: a row in the cockpit under health and power. One bar, or two
-- side by side (main hand left) with an off-hand weapon; a ranged swing takes the one bar.
--
-- Fill: white (Theme.SCHOOL physical), the temporary weapon enchant's color
-- (C_Item.GetWeaponEnchantInfo + Coatings.lua; a module's, such as ShyRogue's
-- poisons, before the bar's own), or red while the target is out of range. A module
-- may lay a fill of its own over the main hand's (ShyPaladin's seal, colored from
-- the aura even while that is secret). A queued next-swing ability (NextSwing.lua
-- + C_Spell.IsCurrentSpell) fills the main-hand bar gold over any of those, with a
-- gold frame and a sheen; out of range it stays red, the frame still gold.
-- Timing is PLAYER_SWING (duration, hand), the event Blizzard_SwingTimer uses;
-- the combat log isn't available to addons on this client.
-- The bars stand in a Shy.HUD box of the display's width, a piece of the cockpit:
-- Move.lua seats it at rects.swing in the plan (Layout.lua) at the vessel's size,
-- and taken out (Pieces.lua) it is the player's to place.
-- While the row shows, the showSwingTimer CVar is turned on so the client keeps
-- time, and its three default bars are faded, in Edit Mode too (the row stands in
-- for them). Edit Mode's own "Swing Timer" switch is turned off, so after a reload
-- it doesn't lay them out either. All of it is restored when the row hides.

local ADDON, ns = ...
local T = ns.T
local Skin, Theme, UI, HUD = Shy.Skin, Shy.Theme, Shy.UI, Shy.HUD

local W = {}
ns.Swing = W

local ID = "shydock-swing"

local MAIN, OFF, RANGED = Enum.PlayerSwingType.MainHand, Enum.PlayerSwingType.OffHand, Enum.PlayerSwingType.Ranged
local FRAME = 2           -- how far a bar's frame extends outside it
local BETWEEN = 7         -- gap between the two bars (their frames end up 3 apart)
local RANGE_EVERY = 0.25  -- seconds between looks at the target's reach and a queued blow
local CVAR = "showSwingTimer"
local SHOWN_IN_EDIT_MODE = Enum.EditModeAccountSetting.ShowSwingTimer
local NATIVE = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }
local EVENTS = { "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED", "WEAPON_SLOT_CHANGED",
	"PLAYER_ENTERING_WORLD", "UNIT_ATTACK_SPEED", "EDIT_MODE_LAYOUTS_UPDATED", "WEAPON_ENCHANT_CHANGED" }
local HAND = { [MAIN] = Enum.WeaponSlot.MainHand, [OFF] = Enum.WeaponSlot.OffHand }

-- Bar colors by temporary weapon enchant (keys from Coatings.lua): what any class can put on a weapon.
-- Hand-picked: fixed for every player, independent of the theme, and clear of the white, red and gold
-- the bar already uses. A module may color a kind of its own first (ShyRogue's poisons); anything
-- else is OTHER.
local SCHOOL = Theme.SCHOOL
local STEEL = { 0.62, 0.80, 1.00 }
local WIND = { 0.62, 0.96, 0.92 }
local MANA = { 0.42, 0.56, 1.00 }
local OTHER = { 0.80, 0.78, 0.92 }
local COAT = {
	-- Sharpening stones and weightstones
	sharpened = STEEL, weighted = STEEL, critical = STEEL, hit = STEEL, attackpowervsundead = STEEL,
	striking = STEEL, precision = STEEL, accuracy = STEEL, quickening = STEEL,
	-- Shaman weapon enchants and other elemental ones
	flametongue = SCHOOL[4], flametonguetotem = SCHOOL[4], flame = SCHOOL[4], baleflame = SCHOOL[4], firestone = SCHOOL[4],
	frostbrand = SCHOOL[16], frost = SCHOOL[16], balefrost = SCHOOL[16], chillknife = SCHOOL[16], iceknife = SCHOOL[16],
	frostoil = SCHOOL[16],
	windfury = WIND, windfurytotem = WIND, windwrath = WIND, wildstrikes = WIND, spark = WIND,
	rockbiter = { 0.82, 0.64, 0.44 },   -- earth
	earthlivingweapon = SCHOOL[8],
	shadowoil = SCHOOL[32], spellstone = SCHOOL[32],
	-- Caster oils
	wizardoil = SCHOOL[64], manaoil = MANA, blackfathommanaoil = MANA, manablade = MANA,
}

-- The second is what Blizzard's action buttons use for their checked state (ActionButton.lua).
local QUEUE_EVENTS = { "CURRENT_SPELL_CAST_CHANGED", "ACTIONBAR_UPDATE_STATE" }

-- The queued look. These numbers match ShyTweaks' Icons.lua, which shows the same state on the action button.
local HEAVY = 1.4                          -- gold frame thickness relative to the steel one
local SHEEN_W, SHEEN = 46, 0.8             -- sheen width and alpha
local SWEEP_TIME, SWEEP_REST = 0.7, 0.4    -- sheen crossing time, and the pause between
local FLASH, FLASH_TIME = 0.8, 0.28        -- flash alpha and duration when the ability is queued

local kit = Skin.NewKit()        -- our bars
local nativeKit = Skin.NewKit()  -- the default swing bars, faded
local bars = {}                  -- [MAIN], [OFF]
local box                        -- the row's HUD box
local driver, events
local up = false        -- the row shows
local ranged = false    -- the last swing was ranged
local far = false       -- target out of range
local queued = false    -- a next-swing ability is queued
local mine              -- this class's next-swing spells (NextSwing.lua) while the row shows; nil if none
local coat = {}         -- [MAIN], [OFF]: enchant color, or nil
local art               -- the queued-state textures on the main-hand bar (LoadedArt)
local loaded = false    -- they are showing
local setting           -- T.db.swing as last applied
local sinceRange = 0

local Native

-- Modules: other addons adding to the bar (T:AddSwingModule, ShyDock.lua). Each is a table of any of
--   Attach(bar)   the main-hand bar, once it exists: art of the module's own on it
--   Shown(up)     whether the row shows, at once and on every change
--   Coat(kind)    a color { r, g, b } for a coating kind (Coatings.lua's keys), or nil: asked before COAT
-- Adding one returns a handle: handle.Overlay() gives a frame over the main-hand bar's fill, exactly as
-- wide as the fill is now, shown only while the fill is a module's to color (in reach, no blow queued,
-- melee): the module lays art of its own in it.
local modules = {}
local own                   -- the modules' frame over the main-hand fill

local function Tell(module, key, ...)
	if module[key] then xpcall(module[key], geterrorhandler(), ...) end
end

local Coat

function W.Overlay()
	return own
end

function W.Add(module)
	modules[#modules + 1] = module
	if bars[MAIN] then
		Tell(module, "Attach", bars[MAIN])
		Tell(module, "Shown", up)
		if up and module.Coat then Coat(true) end
	end
	return { Overlay = W.Overlay }
end

-- A coating's color: a module's, else the bar's own table, else OTHER.
local function Tint(kind)
	for _, module in ipairs(modules) do
		if module.Coat then
			local ok, color = xpcall(module.Coat, geterrorhandler(), kind)
			if ok and color then return color end
		end
	end
	return COAT[kind] or OTHER
end

-- UnitAttackSpeed's second value is the off hand's speed, nil without a weapon there.
local function TwoHands()
	local _, speed = UnitAttackSpeed("player")
	return not issecretvalue(speed) and speed ~= nil and speed > 0
end

-- Fill color: out of range, then a queued blow (the main hand's), then the coating; the modules' overlays
-- show over the main hand's fill only when neither of the first two has it.
local function Color()
	local bad, gold = UI.colors.bad, UI.colors.alert
	local r, g, b = Theme.School(1)
	for kind, bar in pairs(bars) do
		local coated = not ranged and coat[kind]
		if far then
			bar:SetStatusBarColor(bad[1], bad[2], bad[3])
		elseif kind == MAIN and queued and not ranged then
			bar:SetStatusBarColor(gold[1], gold[2], gold[3])
		elseif coated then
			bar:SetStatusBarColor(coated[1], coated[2], coated[3])
		else
			bar:SetStatusBarColor(r, g, b)
		end
	end
	if own then own:SetShown(not far and not ranged and not queued) end
end

-- Queued-state art: a heavier gold frame, a looping sheen clipped to the bar, and a flash.
local function LoadedArt(bar)
	local a = {}
	a.lit = bar:CreateTexture(nil, "OVERLAY", nil, 2)
	a.lit:SetTexture(Skin.FRAME)
	a.lit:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
	a.lit:SetScale(HEAVY)
	a.lit:SetPoint("TOPLEFT", bar, "TOPLEFT", -FRAME, FRAME)
	a.lit:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", FRAME, -FRAME)
	a.lit:Hide()
	local clip = CreateFrame("Frame", nil, bar)
	clip:SetAllPoints(bar)
	clip:SetClipsChildren(true)
	a.sheen = clip:CreateTexture(nil, "OVERLAY")
	a.sheen:SetTexture(Shy.Brand.SHEEN)
	a.sheen:SetBlendMode("ADD")
	a.sheen:SetAlpha(SHEEN)
	a.sheen:SetPoint("TOPRIGHT", clip, "TOPLEFT")
	a.sheen:SetPoint("BOTTOMRIGHT", clip, "BOTTOMLEFT")
	a.sheen:SetWidth(SHEEN_W)
	a.sheen:Hide()
	a.sweep = a.sheen:CreateAnimationGroup()
	a.sweep:SetLooping("REPEAT")
	a.cross = a.sweep:CreateAnimation("Translation")
	a.cross:SetDuration(SWEEP_TIME)
	a.cross:SetEndDelay(SWEEP_REST)
	a.flash = clip:CreateTexture(nil, "OVERLAY", nil, 1)
	a.flash:SetColorTexture(1, 1, 1)
	a.flash:SetBlendMode("ADD")
	a.flash:SetAllPoints(clip)
	a.flash:SetAlpha(0)
	a.arming = a.flash:CreateAnimationGroup()
	local fade = a.arming:CreateAnimation("Alpha")
	fade:SetFromAlpha(FLASH)
	fade:SetToAlpha(0)
	fade:SetDuration(FLASH_TIME)
	fade:SetSmoothing("OUT")
	return a
end

-- The sheen's travel depends on the bar's width, which changes with one or two bars.
local function Crossing()
	art.cross:SetOffset(bars[MAIN]:GetWidth() + SHEEN_W, 0)
end

local function Arm()
	local now = queued and not ranged
	if now == loaded then return end
	loaded = now
	local gold = UI.colors.alert
	art.lit:SetVertexColor(gold[1], gold[2], gold[3])
	art.lit:SetShown(now)
	art.sheen:SetShown(now)
	art.sweep:Stop()
	art.arming:Stop()
	if now then
		Crossing()
		art.sweep:Play()
		art.arming:Play()
	end
end

-- In the cockpit the row stands in the display's block, which frames it with the bars (Cockpit.lua): the
-- bars get a frame of their own only out of it.
local framed

local function Paint()
	local alone = not (T.CockpitHolds and T:CockpitHolds("swing"))
	if framed ~= nil and framed ~= alone then kit:Restore() end
	framed = alone
	for _, bar in pairs(bars) do
		kit:Bar(bar)
		if alone then kit:Frame(bar, { x = -FRAME, y = -FRAME }) end
	end
	Color()
end

-- The frame driver runs only while there is something to move or watch: a swing filling its bar, a queued blow
-- waiting to be spent (the game says when one is queued, not always the moment a swing spends it), or a target
-- whose reach can change with nothing said (PLAYER_SWING_RANGE_UPDATE doesn't always come on this client). With
-- no target and no swing it stops; a new target is an event.
local aimed = false     -- the game answered for a target's reach the last time it was asked
local function Run()
	if not driver then return end
	driver:SetShown(queued or aimed or bars[MAIN].ends ~= nil or bars[OFF].ends ~= nil)
end

local function Clear(bar)
	bar.duration, bar.ends = nil, nil
	bar:SetValue(0)
	Run()
end

local function Begin(bar, duration)
	if issecretvalue(duration) or not duration or duration <= 0 then return end
	bar.duration, bar.ends = duration, GetTime() + duration
	bar:SetValue(0)
	Run()
end

-- One bar across the box, or two side by side with a weapon in each hand.
local function Place()
	local main, off = bars[MAIN], bars[OFF]
	if not up then
		main:Hide()
		off:Hide()
		return
	end
	local width, height = box:GetWidth(), box:GetHeight()
	-- In the cockpit the row is the plan's: as wide as the display and as tall as the grid has it, to the pixel
	-- (the box's own size times its scale can be a fraction of one off).
	local plan = ns.Cockpit.Plan()
	local scale = plan and plan.rects.swing and plan.scales.swing
	if scale and T:CockpitHolds("swing") then width, height = plan.m.displayW / scale, plan.m.swing / scale end
	local two = not ranged and TwoHands()
	local each = two and (width - BETWEEN) / 2 or width
	main:ClearAllPoints()
	main:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
	main:SetSize(each, height)
	main:Show()
	if loaded then Crossing() end
	if two then
		off:ClearAllPoints()
		off:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", each + BETWEEN, 0)
		off:SetSize(each, height)
		off:Show()
	else
		Clear(off)
		off:Hide()
	end
end

local function Range()
	local reach = C_SwingTimer.IsTargetWithinSwingRange(ranged and RANGED or MAIN)   -- nil with no target
	local isFar = not issecretvalue(reach) and reach == false
	local nowAimed = issecretvalue(reach) or reach ~= nil
	if nowAimed ~= aimed then
		aimed = nowAimed
		Run()
	end
	if isFar == far then return end
	far = isFar
	Color()
end

-- A next-swing spell is "current" from the key press until the swing uses it or it is cancelled.
local function Queue()
	local now = false
	if mine then
		for _, spell in ipairs(mine) do
			local current = C_Spell.IsCurrentSpell(spell)
			if not issecretvalue(current) and current then
				now = true
				break
			end
		end
	end
	if now == queued then return end
	queued = now
	Arm()
	Color()
	Run()
end

-- force: a module came with colors of its own, so the colors are asked again.
function Coat(force)
	local changed = false
	for kind, slot in pairs(HAND) do
		local now
		for _, enchant in pairs(C_Item.GetWeaponEnchantInfo(slot)) do
			local has, id = enchant.hasEnchant, enchant.enchantID
			if not issecretvalue(has) and has and not issecretvalue(id) and ns.coatings[id] then
				now = Tint(ns.coatings[id])
				break
			end
		end
		if now ~= coat[kind] then coat[kind], changed = now, true end
	end
	if changed or force then Color() end
end

-- Switch between ranged (one bar) and melee.
local function Mode(shot)
	if shot == ranged then return end
	ranged = shot
	Clear(bars[MAIN])
	Clear(bars[OFF])
	Place()
	Range()
	Color()
	Arm()
end

local function Swung(duration, kind)
	if issecretvalue(kind) then return end
	if kind == RANGED then
		Mode(true)
		Begin(bars[MAIN], duration)
	elseif kind == MAIN or kind == OFF then
		Mode(false)
		if bars[kind]:IsShown() then Begin(bars[kind], duration) end
	end
end

-- Weapon swapped: restart a running swing at the new speed, as the default bars do.
local function Rearmed()
	Place()
	if ranged then return end
	local main, off = UnitAttackSpeed("player")
	if bars[MAIN].ends then Begin(bars[MAIN], main) end
	if bars[OFF].ends and bars[OFF]:IsShown() then Begin(bars[OFF], off) end
end

local function OnEvent(_, event, a, b)
	if event == "PLAYER_SWING" then
		Swung(a, b)
		Queue()   -- the swing may have used the queued ability
	elseif event == "CURRENT_SPELL_CAST_CHANGED" or event == "ACTIONBAR_UPDATE_STATE" then
		Queue()
	elseif event == "WEAPON_SLOT_CHANGED" then
		Rearmed()
		Coat()
	elseif event == "WEAPON_ENCHANT_CHANGED" then
		Coat()
	elseif event == "UNIT_ATTACK_SPEED" then
		if not issecretvalue(a) and a == "player" then Place() end
	elseif event == "PLAYER_ENTERING_WORLD" then
		Place()
		Range()
		Coat()
	elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
		-- Edit Mode just reset the default bars' alpha: fade them again next frame.
		C_Timer.After(0, Native)
	else
		Range()
	end
end

local function OnUpdate(_, elapsed)
	local now = GetTime()
	for _, bar in pairs(bars) do
		if bar.ends then
			local left = bar.ends - now
			if left <= 0 then
				Clear(bar)
			else
				bar:SetValue(1 - left / bar.duration)
			end
		end
	end
	-- The target's reach and a queued blow are looked at again now and then.
	sinceRange = sinceRange + elapsed
	if sinceRange >= RANGE_EVERY then
		sinceRange = 0
		Range()
		Queue()
	end
	Run()
end

-- Fade the default swing bars while ours show.
function Native()
	nativeKit:Restore()
	if not up then return end
	for _, name in ipairs(NATIVE) do
		local frame = _G[name]
		if frame then nativeKit:Hide(frame) end
	end
end

-- Edit Mode's account setting that shows the default bars in Edit Mode.
local function EditModeShows()
	for _, info in ipairs(C_EditMode.GetAccountSettings()) do
		if info.setting == SHOWN_IN_EDIT_MODE then return info.value end
	end
	return 1
end

-- Turn showSwingTimer on and Edit Mode's swing timer switch off while the row shows; restore the
-- saved values after.
local function Switch()
	if up then
		if T.db.swingWas == nil then T.db.swingWas = GetCVar(CVAR) or "0" end
		if GetCVar(CVAR) ~= "1" then SetCVar(CVAR, 1) end
		if T.db.swingEditWas == nil then
			T.db.swingEditWas = EditModeShows()
			C_EditMode.SetAccountSetting(SHOWN_IN_EDIT_MODE, 0)
		end
	else
		if T.db.swingWas ~= nil then
			SetCVar(CVAR, T.db.swingWas)
			T.db.swingWas = nil
		end
		if T.db.swingEditWas ~= nil then
			C_EditMode.SetAccountSetting(SHOWN_IN_EDIT_MODE, T.db.swingEditWas)
			T.db.swingEditWas = nil
		end
	end
end

-- The row shows with the cockpit's box, or wherever the player put it once taken out.
local function Sync()
	local now = T.db.swing and (ns.Cockpit.rect ~= nil or ns.char.loose.swing == true) or false
	if now ~= up then
		up = now
		for _, event in ipairs(EVENTS) do
			if up then events:RegisterEvent(event) else events:UnregisterEvent(event) end
		end
		local _, class = UnitClassBase("player")
		mine = up and ns.nextSwing[class] or nil
		for _, event in ipairs(QUEUE_EVENTS) do
			if mine then events:RegisterEvent(event) else events:UnregisterEvent(event) end
		end
		ranged, far, queued = false, false, false
		coat[MAIN], coat[OFF] = nil, nil
		Arm()
		Clear(bars[MAIN])
		Clear(bars[OFF])
		Color()
		Switch()
		Native()
		HUD.Update(box)
		for _, module in ipairs(modules) do Tell(module, "Shown", up) end
	end
	Place()
	if up then
		Range()
		Queue()
		Coat()
	end
end

function W.Apply()
	if not driver then return end
	-- The row changes the box's height, which moves everything under it.
	if setting ~= nil and setting ~= T.db.swing then
		ns.Move.Touch()
		ns.Arrange.Soon()
	end
	setting = T.db.swing
	Sync()
end

function W.Start()
	local U = ns.Layout.UNITS
	box = HUD.Create({
		id = ID, title = "Swing timer",
		width = U.DISPLAY_W, height = U.SWING_H,
		point = { "BOTTOM", "BOTTOM", 0, 300 },   -- placeholder: Move.lua seats it
		shown = function() return up end,
	})
	box:EnableMouse(false)
	W.box = box
	for _, kind in ipairs({ MAIN, OFF }) do
		local bar = CreateFrame("StatusBar", nil, box)
		bar:SetFrameLevel(box:GetFrameLevel() + 2)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar:Hide()
		bars[kind] = bar
	end
	W.bars = bars
	art = LoadedArt(bars[MAIN])
	W.art = art
	Paint()   -- the fill exists before the modules' frame is hung on it
	own = CreateFrame("Frame", nil, bars[MAIN])
	own:SetAllPoints(bars[MAIN]:GetStatusBarTexture() or bars[MAIN])
	own:SetFrameLevel(bars[MAIN]:GetFrameLevel() + 1)
	for _, module in ipairs(modules) do Tell(module, "Attach", bars[MAIN]) end
	-- A child of the box, so OnUpdate only runs while the row shows.
	driver = CreateFrame("Frame", nil, box)
	driver:SetScript("OnUpdate", OnUpdate)
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", OnEvent)
	-- The plate moved or changed shape: the bars are dressed again only when the plate takes up or lets go of the row.
	Shy:On("SHY_COCKPIT", function()
		Sync()
		local alone = not (T.CockpitHolds and T:CockpitHolds("swing"))
		if alone ~= framed then Paint() end
	end)
	Shy:On("SHY_THEME", Paint)
	-- Sized with the vessel, or by the player once taken out: the bars fill the box again.
	box:HookScript("OnSizeChanged", function() if up then Place() end end)
	-- Edit Mode resets the default bars' alpha as it opens and closes.
	EventRegistry:RegisterCallback("EditMode.Enter", Native, W)
	EventRegistry:RegisterCallback("EditMode.Exit", Native, W)
end
