-- The swing timer. In the cockpit it is the hand row under health and power, the cast bar's own place
-- (Layout.lua's Finish): there only while your weapons swing, and a cast takes the row from it. The row is
-- the cast bar's to the pixel: your weapon's picture where the spell's is, a seam, the bar; with a weapon in
-- each hand the off hand's mirrors the main hand's at the right end, its bar filling from that end, the two
-- bars a seam apart. A ranged swing (a shot, a wand) takes the one bar with the ranged weapon's picture.
-- Taken out (Pieces.lua) it is the player's to place: the bars side by side in frames of their own.
--
-- Swinging: auto-attack on (PLAYER_ENTER_COMBAT / PLAYER_LEAVE_COMBAT), a shot repeating (START_ / STOP_
-- AUTOREPEAT_SPELL), or a swing still filling its bar; the row stays a moment after, for the next. The
-- layout reads W.Wanted() and W.Hands(); a change touches the cockpit. The stance and totem bars ride the
-- plate's foot and are protected: in a fight they can't follow it. So when a fight begins (still free to move
-- them) with one of those bars showing, the row opens at once and stays open until the fight is over. The swing
-- stands in it; with no swing timer seated there the cast bar's row is held open instead (W.HeldEmpty), once
-- you have cast in a fight.
--
-- Fill: white (Theme.SCHOOL physical), the temporary weapon enchant's color
-- (C_Item.GetWeaponEnchantInfo + Coatings.lua; a module's, such as ShyRogue's
-- poisons, before the bar's own), or red while the target is out of range. A module
-- may lay a fill of its own over the main hand's (ShyPaladin's seal, colored from
-- the aura even while that is secret). A queued next-swing ability (NextSwing.lua
-- + C_Spell.IsCurrentSpell) fills the main-hand bar gold over any of those, with a
-- gold frame round the main hand and a sheen; out of range it stays red, the frame still gold.
-- Timing is PLAYER_SWING (duration, hand), the event Blizzard_SwingTimer uses;
-- the combat log isn't available to addons on this client.
-- While the timer is on, the showSwingTimer CVar is turned on so the client keeps
-- time, and its three default bars are faded, in Edit Mode too (ours stand in
-- for them). Edit Mode's own "Swing Timer" switch is turned off, so after a reload
-- it doesn't lay them out either. All of it is restored when the timer is off.

local ADDON, ns = ...
local T = ns.T
local Skin, Theme, UI, HUD = Shy.Skin, Shy.Theme, Shy.UI, Shy.HUD

local W = {}
ns.Swing = W

local ID = "shydock-swing"

local MAIN, OFF, RANGED = Enum.PlayerSwingType.MainHand, Enum.PlayerSwingType.OffHand, Enum.PlayerSwingType.Ranged
local FRAME = 2           -- how far a bar's frame extends outside it
local BETWEEN = 7         -- taken out: the gap between the two bars (their frames end up 3 apart)
local RANGE_EVERY = 0.25  -- seconds between looks at the target's reach and a queued blow
local HOLD = 0.35         -- seconds the row stays after the swing stops (the cast bar's row holds as long)
local ATTACK = 6603       -- Auto Attack (the game's own action bars ask by it): bare hands' picture
local CROP = 0.08         -- the pictures' dark rim, cropped away as the cast bar's is
local CVAR = "showSwingTimer"
local SHOWN_IN_EDIT_MODE = Enum.EditModeAccountSetting.ShowSwingTimer
local NATIVE = { "SwingTimerMainHandFrame", "SwingTimerOffHandFrame", "SwingTimerRangedFrame" }
local EVENTS = { "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "PLAYER_TARGET_CHANGED", "WEAPON_SLOT_CHANGED",
	"PLAYER_ENTERING_WORLD", "UNIT_ATTACK_SPEED", "EDIT_MODE_LAYOUTS_UPDATED", "WEAPON_ENCHANT_CHANGED",
	"PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM" }
-- Whether you swing at all: followed while the timer is on, shown or not.
local STATE_EVENTS = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL",
	"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
local HAND = { [MAIN] = Enum.WeaponSlot.MainHand, [OFF] = Enum.WeaponSlot.OffHand }
-- The protected bars in the foot row (Layout.ROWS' stances and its stead, Move.lua's totems).
local PINNED = { "StanceBar", "PossessActionBar", "MultiCastActionBarFrame" }

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
local icons = {}                 -- [MAIN], [OFF]: the weapons' pictures, in the cockpit's row
local wells = {}                 -- [MAIN], [OFF]: under each bar's track, as under the cast bar's
local box                        -- the row's HUD box
local face                       -- the pictures and bars: shown while the row is the swing's
local driver, events
local up = false        -- the timer is on and has a place: the cockpit's row, or the player's
local ranged = false    -- the last swing was ranged
local far = false       -- target out of range
local queued = false    -- a next-swing ability is queued
local mine              -- this class's next-swing spells (NextSwing.lua) while the row shows; nil if none
local coat = {}         -- [MAIN], [OFF]: enchant color, or nil
local art               -- the queued-state textures on the main-hand bar (LoadedArt)
local loaded = false    -- they are showing
local setting           -- T.db.swing as last applied
local sinceRange = 0
-- Swinging, and the row's opening and closing.
local attacking = false   -- auto-attack is on
local repeating = false   -- a shot (or a wand) repeats
local busyWas = false     -- swinging when last looked
local idleSince           -- when the swing stopped: the row stays HOLD after
local held = false        -- opened in this fight with a protected bar in the foot row: open until it ends
local told = false       -- W.Wanted() as the layout was last told
local handsTold = 1       -- W.Hands() as the layout was last told

local Native

-- Modules: other addons adding to the bar (T:AddSwingModule, ShyDock.lua). Each is a table of any of
--   Attach(bar)   the main-hand bar, once it exists: art of the module's own on it
--   Shown(up)     whether the timer is on, at once and on every change
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

-- A weapon in the off hand. UnitAttackSpeed's second value is the off hand's speed, nil without one (the
-- game's own timer asks the same); in a fight the game keeps the speeds to itself, and then the item in the
-- off hand's slot says it: a weapon, not a shield or a held thing.
local function TwoHands()
	local _, speed = UnitAttackSpeed("player")
	if not issecretvalue(speed) then return speed ~= nil and speed > 0 end
	local item = GetInventoryItemID("player", INVSLOT_OFFHAND)
	if item == nil or issecretvalue(item) then return false end
	local _, _, _, _, _, class = C_Item.GetItemInfoInstant(item)
	return not issecretvalue(class) and class == Enum.ItemClass.Weapon
end

-- The bars the swing has: one per hand in melee with two weapons, else one.
function W.Hands()
	return (up and not ranged and TwoHands()) and 2 or 1
end

local function Busy()
	return attacking or repeating or (bars[MAIN] ~= nil and (bars[MAIN].ends ~= nil or bars[OFF].ends ~= nil))
end

-- A stance or totem bar shows: protected, it can't follow the plate's foot in a fight.
local function Pinned()
	for _, name in ipairs(PINNED) do
		local frame = _G[name]
		if frame then
			local shown = frame:IsShown()
			if not issecretvalue(shown) and shown then return true end
		end
	end
	return false
end

-- The plan changes: the cockpit is planned again (Move.lua seats the pieces and measures it, else it measures itself).
local function Changed()
	if ns.Move and ns.Move.Touch() == true and ns.Layout.IsActive() then return end
	if ns.Cockpit then ns.Cockpit.Touch() end
end

-- The cockpit holds the row (the plate is up, the timer not taken out).
local function Seated()
	return T.CockpitHolds ~= nil and T:CockpitHolds("swing")
end

-- Does the hand row want to be open for the swing? (Layout.lua's plan reads it.) Held for the fight, it is. In a
-- fight that found it unheld, with a stance or totem bar in the foot row, it stays as the fight found it.
function W.Wanted()
	if not T.db.swing then return false end
	if held and Seated() then return true end
	if InCombatLockdown() and Pinned() and Seated() then return told end
	return Busy() or (idleSince ~= nil and GetTime() - idleSince < HOLD)
end

-- The row held open for this fight with no swing timer seated in it: the cast bar's row stays open (Layout.Casting).
function W.HeldEmpty()
	return held and not (T.db.swing and Seated())
end

-- The pictures and bars show: in the cockpit while the plate has the row open for the swing, and not while a
-- cast is taking it (gone at once, before the plate is drawn again); taken out, while you swing (and in layout mode).
local function Showing()
	if not up then return false end
	if not Seated() then return W.Wanted() or HUD.IsUnlocked() end
	local plan = ns.Cockpit.Plan()
	if not (plan and plan.swinging) then return false end
	return not (T:CockpitHolds("cast") and ns.Layout.Casting())
end

local Pictures
local function Show()
	if not face then return end
	local now = Showing()
	if face:IsShown() == now then return end
	if now then Pictures() end
	face:SetShown(now)
end

-- Is the swing busy, and has the layout been told? Called on every change of either.
local Recheck, Rechecked
function Recheck()
	local busy = T.db.swing and Busy() or false
	if busy then
		idleSince = nil
	elseif busyWas then
		idleSince = GetTime()
		C_Timer.After(HOLD + 0.05, Rechecked)
	end
	busyWas = busy
	local want = W.Wanted()
	if want ~= told then
		told = want
		Changed()
	end
	Show()
end

-- The row's hold after the swing stops, run out.
Rechecked = Shy.Clocked("ShyDock swing hold", function() Recheck() end)

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

-- The gold frame: round the main hand's picture and bar in the cockpit's row, round the bar alone taken out.
local function Ring(seated)
	local bar = bars[MAIN]
	art.lit:ClearAllPoints()
	art.lit:SetPoint("TOPLEFT", seated and icons[MAIN] or bar, "TOPLEFT", -FRAME, FRAME)
	art.lit:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", FRAME, -FRAME)
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

-- In the cockpit the row stands in the display's block, which frames it (Cockpit.lua): the bars get a frame
-- of their own only out of it. Under each bar's track the well the cast bar has under its own.
local framed

local function Paint()
	local alone = not Seated()
	if framed ~= nil and framed ~= alone then kit:Restore() end
	framed = alone
	local well = Skin.colors.well
	for kind, bar in pairs(bars) do
		kit:Bar(bar)
		if alone then kit:Frame(bar, { x = -FRAME, y = -FRAME }) end
		wells[kind]:SetColorTexture(well[1], well[2], well[3], well[4] or 1)
	end
	Color()
end

-- The weapons' pictures: the ranged weapon's for a shot, else each hand's; bare hands show Auto Attack's.
-- A druid in a form fights with what the form has, not the weapon held: Auto Attack's picture.
local function Clawed()
	local _, class = UnitClassBase("player")
	return class == "DRUID" and GetShapeshiftFormID() ~= nil
end

function Pictures()
	local fist = C_Spell.GetSpellTexture(ATTACK)
	if Clawed() then
		icons[MAIN]:SetTexture(fist)
		icons[OFF]:SetTexture(fist)
		return
	end
	icons[MAIN]:SetTexture(GetInventoryItemTexture("player", ranged and INVSLOT_RANGED or INVSLOT_MAINHAND) or fist)
	icons[OFF]:SetTexture(GetInventoryItemTexture("player", INVSLOT_OFFHAND) or fist)
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
	local was = bar.ends ~= nil
	bar.duration, bar.ends = nil, nil
	bar:SetValue(0)
	Run()
	if was then Recheck() end
end

local function Begin(bar, duration)
	if issecretvalue(duration) or not duration or duration <= 0 then return end
	bar.duration, bar.ends = duration, GetTime() + duration
	bar:SetValue(0)
	Run()
	Recheck()
end

-- A region at a plan's rect (UIParent units), in the box seated at the plan's rect for it and its scale.
local function Put(region, rect, origin, scale)
	region:ClearAllPoints()
	region:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", (rect[1] - origin[1]) / scale, (rect[2] - origin[2]) / scale)
	region:SetSize((rect[3] - rect[1]) / scale, (rect[4] - rect[2]) / scale)
end

-- The row as the plan has it in the cockpit; taken out, one bar across the box, or two side by side.
local function Place()
	local main, off = bars[MAIN], bars[OFF]
	-- One bar or two: the plan is planned again for the other, open or not (the row is one height either way), so
	-- the first blows find both bars there.
	local hands = W.Hands()
	if hands ~= handsTold then
		handsTold = hands
		Changed()
	end
	if not up then
		Show()
		return
	end
	if face:IsShown() then Pictures() end
	local plan = ns.Cockpit.Plan()
	local hand = plan and plan.hand
	if hand and Seated() then
		local origin, scale = plan.rects.swing, plan.scales.swing
		Put(icons[MAIN], hand.icons[1], origin, scale)
		Put(main, hand.bars[1], origin, scale)
		icons[MAIN]:Show()
		main:Show()
		local two = hand.bars[2] ~= nil
		if two then
			Put(icons[OFF], hand.icons[2], origin, scale)
			Put(off, hand.bars[2], origin, scale)
		else
			Clear(off)
		end
		icons[OFF]:SetShown(two)
		off:SetShown(two)
		-- The off hand's bar fills from its own picture, at the right end.
		off:SetReverseFill(two)
		Ring(true)
	else
		local width, height = box:GetWidth(), box:GetHeight()
		local two = hands == 2
		local each = two and (width - BETWEEN) / 2 or width
		icons[MAIN]:Hide()
		icons[OFF]:Hide()
		main:ClearAllPoints()
		main:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
		main:SetSize(each, height)
		main:Show()
		off:SetReverseFill(false)
		if two then
			off:ClearAllPoints()
			off:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", each + BETWEEN, 0)
			off:SetSize(each, height)
			off:Show()
		else
			Clear(off)
			off:Hide()
		end
		Ring(false)
	end
	if loaded then Crossing() end
	Show()
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

-- A fight begins. This is the last moment the stance and totem bars may move: with one showing, the row opens at
-- once for whatever the plate holds in it, and the pieces are seated for it now, not a frame on. The swing timer
-- always has it; with that off, the cast bar has it once you have cast in a fight (ns.char.fightCasts, kept), so
-- a warrior's plate doesn't grow an empty row. (Told is not enough: auto-attack may have told it this same frame, and Move.lua seats the pieces a frame on.)
local function Fight()
	local cast = T.CockpitHolds ~= nil and T:CockpitHolds("cast") and ns.char.fightCasts
	if not (Pinned() and ((T.db.swing and Seated()) or cast)) then return end
	held = true
	told = W.Wanted()
	local plan = ns.Cockpit.Plan()
	if not (plan and (plan.swinging or plan.casting)) then ns.Move.Sync() end
	Show()
end

local function OnEvent(_, event, a, b)
	if event == "PLAYER_SWING" then
		Swung(a, b)
		Queue()   -- the swing may have used the queued ability
	elseif event == "PLAYER_ENTER_COMBAT" or event == "PLAYER_LEAVE_COMBAT" then
		attacking = event == "PLAYER_ENTER_COMBAT"
		Recheck()
	elseif event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
		repeating = event == "START_AUTOREPEAT_SPELL"
		Recheck()
	elseif event == "PLAYER_REGEN_DISABLED" then
		Fight()
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- The fight over: the row closes, unless something still has it. The pieces are seated now, not a frame on.
		local was = held
		held = false
		Recheck()
		if was then ns.Move.Sync() end
	elseif event == "CURRENT_SPELL_CAST_CHANGED" or event == "ACTIONBAR_UPDATE_STATE" then
		Queue()
	elseif event == "WEAPON_SLOT_CHANGED" then
		Rearmed()
		Coat()
	elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
		if face:IsShown() then Pictures() end
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

-- Fade the default swing bars while ours stand in for them.
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

-- Turn showSwingTimer on and Edit Mode's swing timer switch off while the timer is on; restore the
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

-- The timer has a place with the cockpit's plate, or wherever the player put it once taken out.
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
	-- On or off: the row may open or close, which moves everything under it.
	if setting ~= nil and setting ~= T.db.swing then
		ns.Move.Touch()
		ns.Arrange.Soon()
	end
	setting = T.db.swing
	Sync()
	Recheck()
end

function W.Start()
	local U = ns.Layout.UNITS
	-- In the cockpit the box is the hand row inside its frame: the display's width, the health bar's height.
	box = HUD.Create({
		id = ID, title = "Swing timer",
		width = U.DISPLAY_W, height = U.HEALTH,
		point = { "BOTTOM", "BOTTOM", 0, 300 },   -- placeholder: Move.lua seats it
		shown = function() return up end,
	})
	box:EnableMouse(false)
	W.box = box
	face = CreateFrame("Frame", nil, box)
	face:SetAllPoints(box)
	face:SetFrameLevel(box:GetFrameLevel() + 1)
	face:Hide()
	W.face = face
	for _, kind in ipairs({ MAIN, OFF }) do
		local icon = face:CreateTexture(nil, "ARTWORK")
		icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
		icon:Hide()
		icons[kind] = icon
		local bar = CreateFrame("StatusBar", nil, face)
		bar:SetFrameLevel(face:GetFrameLevel() + 1)
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(0)
		bar:Hide()
		local well = bar:CreateTexture(nil, "BACKGROUND")
		well:SetAllPoints(bar)
		wells[kind] = well
		bars[kind] = bar
	end
	W.bars, W.icons = bars, icons
	art = LoadedArt(bars[MAIN])
	W.art = art
	Paint()   -- the fill exists before the modules' frame is hung on it
	own = CreateFrame("Frame", nil, bars[MAIN])
	own:SetAllPoints(bars[MAIN]:GetStatusBarTexture() or bars[MAIN])
	own:SetFrameLevel(bars[MAIN]:GetFrameLevel() + 1)
	for _, module in ipairs(modules) do Tell(module, "Attach", bars[MAIN]) end
	-- A child of the box, so OnUpdate only runs while the timer is on (the pictures and bars may be out of sight).
	driver = CreateFrame("Frame", nil, box)
	driver:SetScript("OnUpdate", Shy.Clocked("ShyDock swing", OnUpdate))
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", OnEvent)
	-- Auto-attack already on (a reload mid-fight): nothing says so again.
	local on = C_Spell.IsCurrentSpell(ATTACK)
	attacking = not issecretvalue(on) and on == true
	for _, event in ipairs(STATE_EVENTS) do events:RegisterEvent(event) end
	-- The plate moved, changed shape or handed the row over: placed again, and dressed again only when the plate
	-- takes up or lets go of the row.
	Shy:On("SHY_COCKPIT", function()
		Sync()
		local alone = not Seated()
		if alone ~= framed then Paint() end
	end)
	Shy:On("SHY_THEME", Paint)
	Shy:On("SHY_HUD_LAYOUT", Show)
	-- A cast takes the row from the swing at once; the swing comes back when the plate hands it back. A cast in a
	-- fight with a stance or totem bar up is kept in mind: from the next fight on, the row is held for the cast bar.
	local cast = PlayerCastingBarFrame
	if cast then
		local Shown = Shy.Clocked("ShyDock swing: cast bar", Show)
		cast:HookScript("OnShow", Shy.Clocked("ShyDock swing: cast bar", function()
			if InCombatLockdown() and Pinned() then ns.char.fightCasts = true end
			Show()
		end))
		cast:HookScript("OnHide", Shown)
	end
	-- Taken out and sized by the player: the bars fill the box again.
	box:HookScript("OnSizeChanged", function() if up then Place() end end)
	-- Edit Mode resets the default bars' alpha as it opens and closes.
	EventRegistry:RegisterCallback("EditMode.Enter", Native, W)
	EventRegistry:RegisterCallback("EditMode.Exit", Native, W)
	Recheck()
end
