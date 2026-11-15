-- Action bar and cooldown manager icons: cooldown numbers, a highlight on active
-- abilities, a fill for abilities you lack the power for, and an out of range tint.
--
-- Only textures (and one status bar per button) are added to Blizzard's buttons;
-- nothing of theirs is moved, sized, shown or hidden, so it is safe on protected
-- buttons and in combat.
-- UnitPower can be secret, so `afford` never does arithmetic with it: the value
-- goes straight to a status bar, and the shade and line anchor to the end of its fill.

local ADDON, ns = ...
local UI, Skin, Theme, B, Slot = Shy.UI, Shy.Skin, Shy.Theme, Shy.Brand, Shy.Slot

local BUTTON = 45      -- action button size the art is drawn for; other icons scale from it
local RIM = 3          -- how far a button's frame overlaps its icon
local GLOW = 0.75      -- alpha of the active glow
local WASH = 0.12      -- alpha of the gold wash over the icon
local HEAVY = 1.4      -- gold frame thickness, relative to the steel one
local BRACKET = 11     -- corner bracket stroke length
local BRACKET_COLOR = { 1.00, 0.98, 0.90 }
local SHEEN = 0.5      -- alpha of the sweeping sheen
local SWEEP_TIME, SWEEP_REST = 0.7, 0.4
local FLASH = 0.75
local FLASH_TIME = 0.28
local RECHECK = 0.2    -- seconds between re-checks of active buttons
local SHADE = { 0.024, 0.024, 0.031, 0.74 }   -- over the unfilled part of an icon
local LINE = 2         -- width of the fill's leading line
local FOOT = 5         -- height of the bar style
-- A status bar hides its fill at its minimum, and the shade anchors to that fill:
-- a minimum just below zero is never reached.
local FLOOR = -0.001
local SMOOTH = Enum.StatusBarInterpolation.ExponentialEaseOut
local LACKING = { 0.5, 0.5, 1.0 }   -- Blizzard's "not enough power" tint (ActionButton.lua, UpdateUsable)
local FAR = { 1.00, 0.33, 0.30 }    -- out of range multiply color

local BARS = {
	"MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft",
	"MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7",
}
local NUMBER_BARS = { "PetActionBar", "StanceBar" }   -- cooldown numbers only
local VIEWERS = { { name = "EssentialCooldownViewer", size = 50 }, { name = "UtilityCooldownViewer", size = 30 } }

local numbers, armed, afford, range

-- Buttons and icons

local holders = {}   -- button or icon -> its state
local buttons = {}   -- the action buttons' holders
local viewers        -- the two cooldown viewers, once Blizzard_CooldownViewer has loaded

local FollowButton, FollowItem, SyncItems

-- A secret value counts as false.
local function Yes(value)
	if issecretvalue(value) then return false end
	return value and true or false
end

-- Runs fn once on the next frame, however often it is asked for.
local waiting, runners = {}, {}   -- key -> what runs next frame; key -> the one closure that runs it
local function Later(key, fn)
	if waiting[key] then return end
	waiting[key] = fn
	local run = runners[key]
	if not run then
		run = function()
			local job = waiting[key]
			waiting[key] = nil
			job()
		end
		runners[key] = run
	end
	C_Timer.After(0, run)
end

local function Holder(frame, icon, size, item)
	local h = holders[frame]
	if not h then
		h = { frame = frame, icon = icon, size = size, k = size / BUTTON, item = item }
		holders[frame] = h
	end
	return h
end

local function Buttons()
	if #buttons == 0 then
		for _, name in ipairs(BARS) do
			for _, button in ipairs(_G[name].actionButtons) do
				local h = Holder(button, button.icon, BUTTON)
				buttons[#buttons + 1] = h
				FollowButton(h)
			end
		end
	end
	return buttons
end

local function Viewers()
	if viewers then return viewers end
	local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer")
	if not loaded then return nil end
	viewers = {}
	for i, v in ipairs(VIEWERS) do
		local frame = _G[v.name]
		viewers[i] = { frame = frame, size = v.size }
		hooksecurefunc(frame, "RefreshData", function() Later("items", SyncItems) end)
	end
	return viewers
end

-- Viewer icons are pooled, so the active ones are enumerated each time.
local function EachItem(fn)
	local rows = Viewers()
	if not rows then return end
	for _, v in ipairs(rows) do
		for item in v.frame.itemFramePool:EnumerateActive() do
			if not issecretvalue(item) then
				local h = Holder(item, item.Icon, v.size, true)
				FollowItem(h)
				fn(h)
			end
		end
	end
end

-- Cooldown numbers

local numbersKit = Skin.NewKit()
local unfaced = {}   -- buttons whose numbers still have the default font

-- A cooldown's font string may not exist until its first cooldown runs.
local function Face()
	if not next(unfaced) then return end
	local font = UI.NameFont(numbers.opt.size, "OUTLINE")
	local color = UI.colors.text
	for button in pairs(unfaced) do
		local text = button.cooldown:GetCountdownFontString()
		if text then
			unfaced[button] = nil
			-- A font object carries its own color: record the color first, re-apply it after.
			numbersKit:Text(text, color)
			numbersKit:FontObject(text, font)
			numbersKit:Text(text, color)
		end
	end
end

local function FaceAll()
	numbersKit:Restore()
	wipe(unfaced)
	for _, bars in ipairs({ BARS, NUMBER_BARS }) do
		for _, name in ipairs(bars) do
			for _, button in ipairs(_G[name].actionButtons) do
				if button.cooldown then unfaced[button] = true end
			end
		end
	end
	Face()
end

numbers = ns.Feature({
	id = "cooldownNumbers",
	category = "Combat",
	title = "Cooldown numbers",
	desc = "Shows the seconds left on action bar cooldowns. The cooldown manager has its own setting for this in Edit Mode.",
	keywords = "cooldown cooldowns cd numbers countdown timer seconds text action bar button",
	default = true,
	options = {
		{ key = "size", kind = "slider", label = "Number size", min = 12, max = 24, step = 1, default = 18,
			format = function(v) return tostring(math.floor(v + 0.5)) end,
			desc = "Font size of the numbers. They scale with your bars in Edit Mode." },
	},
	events = { ACTIONBAR_UPDATE_COOLDOWN = Face },
	Enable = function(f)
		ns.TakeCVar(f, "countdownForCooldowns", 1)
		FaceAll()
	end,
	Disable = function(f)
		numbersKit:Restore()
		wipe(unfaced)
		ns.ReturnCVar(f, "countdownForCooldowns")
	end,
	OnOptionChanged = FaceAll,
})

-- Armed (active abilities)

local armedKit = Skin.NewKit()   -- hides Blizzard's CheckedTexture while the highlight shows

-- A Slot piece ("glow", "frame") over the whole button, following the chosen slot shape.
local function Piece(frame, layer, sublevel, piece, scale)
	local t = frame:CreateTexture(nil, layer, nil, sublevel)
	Slot.Follow(t, piece, frame)
	t:SetScale(scale)
	return t
end

-- One mask per button in the slot's shape, shared by every tweak that clips to the icon.
local function PictureMask(h)
	if not h.clip then
		h.clip = h.frame:CreateMaskTexture()
		Slot.Follow(h.clip, "mask", h.frame, RIM * h.k, RIM * h.k)
	end
	return h.clip
end

local function OverPicture(region, frame, k)
	region:SetPoint("TOPLEFT", frame, "TOPLEFT", RIM * k, -RIM * k)
	region:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RIM * k, RIM * k)
end

local CORNERS = { { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 }, { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }

local function Brackets(frame, k, art)
	local long, thick, inset = BRACKET * k, math.max(1.5, 2 * k), k
	for _, corner in ipairs(CORNERS) do
		for stroke = 1, 2 do
			local t = frame:CreateTexture(nil, "OVERLAY", nil, 3)
			t:SetColorTexture(BRACKET_COLOR[1], BRACKET_COLOR[2], BRACKET_COLOR[3])
			t:SetPoint(corner[1], frame, corner[1], corner[2] * inset, corner[3] * inset)
			if stroke == 1 then t:SetSize(long, thick) else t:SetSize(thick, long) end
			art.parts[#art.parts + 1] = t
			art.corner[t] = corner[1]
		end
	end
end

-- A bracket only shows on a corner the slot's shape keeps square.
local function ShowArmed(art, on)
	for _, region in ipairs(art.parts) do
		local corner = art.corner[region]
		region:SetShown(on and (corner == nil or Slot.Square(corner)))
	end
end

-- Gold (UI.colors.alert), not the accent: an accent near steel hides the state.
local function ArmedArt(h)
	local art = h.armed
	if art then return art end
	local frame, k = h.frame, h.k
	local gold = UI.colors.alert
	art = { parts = {}, corner = {} }
	local function Part(region)
		art.parts[#art.parts + 1] = region
		return region
	end
	local mask = PictureMask(h)
	art.glow = Part(Piece(frame, "ARTWORK", 6, "glow", k))
	art.glow:SetBlendMode("ADD")
	UI.Tint(art.glow, gold, GLOW)
	art.wash = Part(frame:CreateTexture(nil, "ARTWORK", nil, 6))
	art.wash:SetBlendMode("ADD")
	OverPicture(art.wash, frame, k)
	UI.Paint(art.wash, gold, WASH)
	art.wash:AddMaskTexture(mask)
	-- A looping, masked animation: no script runs while it sweeps.
	local inner = h.size - 2 * RIM * k
	art.sheen = Part(frame:CreateTexture(nil, "ARTWORK", nil, 6))
	art.sheen:SetTexture(B.SHEEN)
	art.sheen:SetBlendMode("ADD")
	art.sheen:SetAlpha(SHEEN)
	art.sheen:SetSize(inner, inner)
	art.sheen:SetPoint("CENTER", frame, "CENTER", -inner, 0)
	art.sheen:AddMaskTexture(mask)
	art.sweep = art.sheen:CreateAnimationGroup()
	art.sweep:SetLooping("REPEAT")
	local cross = art.sweep:CreateAnimation("Translation")
	cross:SetOffset(2 * inner, 0)
	cross:SetDuration(SWEEP_TIME)
	cross:SetEndDelay(SWEEP_REST)
	art.lit = Part(Piece(frame, "OVERLAY", 2, "frame", k * HEAVY))
	UI.Tint(art.lit, gold)
	Brackets(frame, k, art)
	art.flash = Part(frame:CreateTexture(nil, "OVERLAY", nil, 4))
	art.flash:SetColorTexture(1, 1, 1)
	art.flash:SetBlendMode("ADD")
	art.flash:SetPoint("TOPLEFT", frame, "TOPLEFT", 2 * k, -2 * k)
	art.flash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2 * k, 2 * k)
	art.flash:AddMaskTexture(mask)
	art.flash:SetAlpha(0)
	art.anim = art.flash:CreateAnimationGroup()
	local fade = art.anim:CreateAnimation("Alpha")
	fade:SetFromAlpha(FLASH)
	fade:SetToAlpha(0)
	fade:SetDuration(FLASH_TIME)
	fade:SetSmoothing("OUT")
	h.armed = art
	return art
end

-- Lit buttons are re-checked every RECHECK seconds: the game signals a queued
-- attack, but no event is guaranteed for the swing that consumes it.
local lit = {}   -- holders lit now
local watch = CreateFrame("Frame")
watch:Hide()
local SyncArmed

local function SetArmed(h, on)
	if on == (h.on or false) then return end
	h.on = on
	lit[h] = on or nil
	watch:SetShown(next(lit) ~= nil)
	local art = ArmedArt(h)
	ShowArmed(art, on)
	art.anim:Stop()
	art.sweep:Stop()
	if on then
		art.anim:Play()
		art.sweep:Play()
	end
end

local function Current(spell)
	if not issecretvalue(spell) and not spell then return false end
	return Yes(C_Spell.IsCurrentSpell(spell)) or Yes(C_Spell.IsAutoRepeatSpell(spell))
end

-- For an action button, the same checks as ActionBarActionButtonMixin:UpdateState.
function SyncArmed(h)
	local on = false
	if h.item then
		local item = h.frame
		-- The spell shown may override the base spell (a talent, a form).
		local ok, shown = pcall(item.GetSpellID, item)
		on = Current(item:GetBaseSpellID()) or (ok and Current(shown))
	else
		local action = h.frame.action
		if not issecretvalue(action) and action then
			on = Yes(C_ActionBar.IsCurrentAction(action)) or Yes(C_ActionBar.IsAutoRepeatAction(action))
		end
	end
	SetArmed(h, on)
end

local sinceWatch = 0
watch:SetScript("OnUpdate", function(_, elapsed)
	sinceWatch = sinceWatch + elapsed
	if sinceWatch < RECHECK then return end
	sinceWatch = 0
	for h in pairs(lit) do SyncArmed(h) end
end)

local function SyncArmedItems()
	EachItem(SyncArmed)
end

local function SyncArmedAll()
	for _, h in ipairs(Buttons()) do SyncArmed(h) end
	SyncArmedItems()
end

armed = ns.Feature({
	id = "armed",
	category = "Combat",
	title = "Highlight active abilities",
	desc = "An ability that is queued, casting or auto-repeating (Heroic Strike, Auto Shot) gets a gold frame and a sweeping sheen. Works on action bars and the cooldown manager.",
	keywords = "armed queued toggle toggled active on checked heroic strike cleave maul raptor next swing auto shot casting highlight glow border button ability cooldown manager essential",
	default = true,
	events = {
		CURRENT_SPELL_CAST_CHANGED = SyncArmedItems,
		-- The game answers it on each button with an action by SetChecked (ActionBarActionButtonMixin:UpdateState),
		-- which each button's hook follows: only the cooldown manager's icons are looked at here.
		ACTIONBAR_UPDATE_STATE = SyncArmedItems,
		START_AUTOREPEAT_SPELL = SyncArmedItems,
		STOP_AUTOREPEAT_SPELL = SyncArmedItems,
		PLAYER_ENTER_COMBAT = SyncArmedItems,
		PLAYER_LEAVE_COMBAT = SyncArmedItems,
	},
	Enable = function()
		for _, h in ipairs(Buttons()) do
			armedKit:Hide(h.frame.CheckedTexture)
			SyncArmed(h)
		end
		SyncArmedItems()
		if ns.WarmIcons then ns.WarmIcons() end
	end,
	Disable = function()
		armedKit:Restore()
		for _, h in pairs(holders) do
			if h.armed then SetArmed(h, false) end
		end
	end,
})

-- Afford (power cost)

local costed = {}   -- holders whose spell costs power

local function Spell(h)
	if h.item then
		local item = h.frame
		local ok, shown = pcall(item.GetSpellID, item)
		if ok and not issecretvalue(shown) and shown then return shown end
		return item:GetBaseSpellID()
	end
	local action = h.frame.action
	if issecretvalue(action) or not action then return nil end
	local kind, id, sub = GetActionInfo(action)
	if not canaccessvalue(kind, id, sub) then return nil end
	if kind == "spell" or (kind == "macro" and sub == "spell") then return id end
	return nil
end

-- Returns amount, power type, or nil when free. With two costs (energy and
-- combo points) the player's main power type wins.
local function Cost(spell)
	if issecretvalue(spell) or not spell then return nil end
	local costs = C_Spell.GetSpellPowerCost(spell)
	if issecretvalue(costs) or not costs then return nil end
	local main = UnitPowerType("player")
	local need, kind
	for _, c in ipairs(costs) do
		if not canaccessvalue(c.minCost, c.cost, c.type, c.requiredAuraID, c.hasRequiredAura) then return nil end
		local amount = c.minCost > 0 and c.minCost or c.cost
		if amount > 0 and (c.requiredAuraID == 0 or c.hasRequiredAura) then
			if not issecretvalue(main) and c.type == main then return amount, c.type end
			if not need then need, kind = amount, c.type end
		end
	end
	return need, kind
end

local function Lacking(h)
	if h.item then
		if h.frame.spellOutOfRange then return false end   -- Blizzard tints it red itself
		local _, lacking = C_Spell.IsSpellUsable(h.spell)
		return Yes(lacking)
	end
	local action = h.frame.action
	if issecretvalue(action) or not action then return false end
	local _, lacking = C_ActionBar.IsUsableAction(action)
	return Yes(lacking)
end

local function AffordArt(h)
	local frame = h.frame
	local gauge = CreateFrame("StatusBar", nil, frame)
	gauge:SetStatusBarTexture(Skin.BAR)
	gauge.fill = gauge:GetStatusBarTexture()
	gauge.track = gauge:CreateTexture(nil, "BACKGROUND")
	gauge.track:SetAllPoints(gauge)
	gauge.track:SetColorTexture(0, 0, 0, 0.82)
	h.gauge = gauge

	-- Textures on the button, not the gauge, so they stay under its frame, cooldown and keybind.
	h.lack = frame:CreateTexture(nil, "ARTWORK", nil, 2)
	h.lack:SetColorTexture(SHADE[1], SHADE[2], SHADE[3], SHADE[4])
	h.lack:SetPoint("TOPLEFT", gauge.fill, "TOPRIGHT")
	h.lack:SetPoint("BOTTOMRIGHT", gauge, "BOTTOMRIGHT")
	h.lack:AddMaskTexture(PictureMask(h))
	-- The leading line, with a dark edge either side so it reads over a bright icon.
	local width = math.max(1.5, LINE * h.k)
	h.edge = frame:CreateTexture(nil, "ARTWORK", nil, 3)
	h.edge:SetColorTexture(0, 0, 0, 0.6)
	h.edge:SetWidth(width + 2)
	h.line = frame:CreateTexture(nil, "ARTWORK", nil, 4)
	h.line:SetColorTexture(1, 1, 1)
	h.line:SetWidth(width)
	for _, t in ipairs({ h.edge, h.line }) do
		t:SetPoint("TOP", gauge.fill, "TOPRIGHT")
		t:SetPoint("BOTTOM", gauge.fill, "BOTTOMRIGHT")
	end
end

-- Applies the chosen style and color. In the fill style the gauge is transparent and only positions the shade and line.
local function Dress(h)
	local gauge, frame = h.gauge, h.frame
	local rim = RIM * h.k
	local bar = afford.opt.style == "bar"
	gauge:ClearAllPoints()
	gauge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", rim, rim)
	if bar then
		gauge:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -rim, rim + FOOT * h.k)
	else
		gauge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -rim, -rim)
	end
	gauge.track:SetShown(bar)
	if afford.opt.color == "power" then
		local r, g, b = Theme.Power(h.power)
		gauge:SetStatusBarColor(r, g, b, bar and 1 or 0)
		local c = CreateColor(r, g, b)
		h.line:SetGradient("VERTICAL", c, c)
	else
		local r, g, b = Theme.Accent()
		gauge:SetStatusBarColor(r, g, b, bar and 1 or 0)
		h.line:SetGradient("VERTICAL", CreateColor(B.Ramp(0)), CreateColor(B.Ramp(1)))
	end
end

-- Blizzard's "not enough power" tint is removed while the icon fills.
local function Tint(h, clear)
	if clear then
		h.cleared = true
		h.icon:SetVertexColor(1, 1, 1)
	elseif h.cleared then
		h.cleared = nil
		if h.cost and Lacking(h) then
			if h.item then
				h.icon:SetVertexColor(CooldownViewerConstants.ITEM_NOT_ENOUGH_MANA_COLOR:GetRGBA())
			else
				h.icon:SetVertexColor(LACKING[1], LACKING[2], LACKING[3])
			end
		end
	end
end

local function PaintAfford(h)
	local short = (afford.running and h.short) or false
	if not h.gauge then
		if not short then return end
		AffordArt(h)
	end
	local gauge = h.gauge
	if short and not h.dressed then
		Dress(h)
		gauge:SetMinMaxValues(FLOOR, h.cost)
		gauge:SetValue(UnitPower("player", h.power))
		h.dressed = true
	end
	local picture = short and afford.opt.style ~= "bar"
	gauge:SetShown(short)
	h.lack:SetShown(picture)
	h.edge:SetShown(picture)
	h.line:SetShown(picture)
	Tint(h, picture)
end

-- lacking: the game's answer when a hook has just received one, else nil.
local function Judge(h, lacking)
	local short = false
	if h.cost then
		if lacking == nil then lacking = Lacking(h) else lacking = Yes(lacking) end
		short = lacking
		if short then
			-- Lacking, yet power covers the cost read here: the cost is wrong, so keep the default look.
			local power = UnitPower("player", h.power)
			if not issecretvalue(power) and power >= h.cost then short = false end
		end
	end
	if short ~= (h.short or false) then h.dressed = nil end
	h.short = short
	PaintAfford(h)
end

local function Read(h)
	local spell = Spell(h)
	local cost, power = Cost(spell)
	if cost ~= h.cost or power ~= h.power then h.dressed = nil end
	h.spell, h.cost, h.power = spell, cost, power
	costed[h] = cost and true or nil
	Judge(h)
end

local function ReadAll()
	if not afford.running then return end
	for _, h in ipairs(Buttons()) do Read(h) end
	EachItem(Read)
end

local function Reread()
	Later("costs", ReadAll)
end

local function Redress()
	for _, h in pairs(holders) do
		if h.gauge then
			h.dressed = nil
			PaintAfford(h)
		end
	end
end

local function Power(_, _, unit)
	if issecretvalue(unit) or unit ~= "player" then return end
	for h in pairs(costed) do
		if h.short and h.gauge then h.gauge:SetValue(UnitPower("player", h.power), SMOOTH) end
	end
end

afford = ns.Feature({
	id = "afford",
	category = "Combat",
	title = "Show power toward abilities",
	desc = "An ability you lack the rage, energy or mana for fills from the left as the power comes in. Works on action bars and the cooldown manager.",
	keywords = "afford cost rage energy mana power resource fill progress enough not enough usable button ability action bar cooldown manager line bar",
	default = true,
	options = {
		{ key = "style", kind = "dropdown", label = "Style", default = "fill",
			items = {
				{ value = "fill", text = "Icon fills" },
				{ value = "bar", text = "Bar under the icon" },
			},
			desc = "Icon fills: the part you have power for is in full color, the rest is dark. Bar under the icon: the icon keeps the default look and a slim bar fills below it." },
		{ key = "color", kind = "dropdown", label = "Color", default = "theme",
			items = {
				{ value = "theme", text = "Accent color" },
				{ value = "power", text = "Rage red, energy gold, mana blue" },
			},
			desc = "Colors the line or bar in your accent color, or by power type." },
	},
	events = {
		UNIT_POWER_FREQUENT = Power,
		ACTIONBAR_SLOT_CHANGED = Reread,
		ACTIONBAR_PAGE_CHANGED = Reread,
		UPDATE_BONUS_ACTIONBAR = Reread,
		UPDATE_SHAPESHIFT_FORM = Reread,
		SPELLS_CHANGED = Reread,
		PLAYER_ENTERING_WORLD = Reread,
		COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = Reread,
	},
	Enable = ReadAll,
	Disable = function()
		for _, h in pairs(holders) do PaintAfford(h) end
	end,
	OnOptionChanged = Redress,
})

-- Out of range

local function RangeArt(h)
	local art = h.range
	if art then return art end
	local frame, k = h.frame, h.k
	art = {}
	-- Blend MOD multiplies the icon red, so it stays recognizable.
	art.wash = frame:CreateTexture(nil, "ARTWORK", nil, 5)
	art.wash:SetColorTexture(FAR[1], FAR[2], FAR[3])
	art.wash:SetBlendMode("MOD")
	art.wash:SetPoint("TOPLEFT", frame, "TOPLEFT", RIM * k, -RIM * k)
	art.wash:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -RIM * k, RIM * k)
	art.wash:AddMaskTexture(PictureMask(h))
	art.ring = Piece(frame, "OVERLAY", 1, "glow", k)
	UI.Tint(art.ring, UI.colors.bad)
	h.range = art
	return art
end

local function SetFar(h, far)
	if far == (h.far or false) then return end
	h.far = far
	local art = RangeArt(h)
	art.wash:SetShown(far)
	art.ring:SetShown(far)
end

-- The hook only fires when the game's answer changes; a new target or page needs asking.
local function SyncRange(h)
	local action = h.frame.action
	local far = false
	if not issecretvalue(action) and action then
		local inRange = C_ActionBar.IsActionInRange(action)   -- nil: no target, or no range
		far = not issecretvalue(inRange) and inRange == false
	end
	SetFar(h, far)
end

local function SyncRangeAll()
	if not range.running then return end
	for _, h in ipairs(Buttons()) do SyncRange(h) end
end

local function Rerange()
	Later("range", SyncRangeAll)
end

local followingRange

range = ns.Feature({
	id = "outOfRange",
	category = "Combat",
	title = "Tint out of range abilities",
	desc = "When your target is out of range, the whole button turns red, not just the keybind.",
	keywords = "range out of range far distance reach close enough melee charge red tint button ability attack target",
	default = true,
	events = {
		PLAYER_TARGET_CHANGED = Rerange,
		ACTIONBAR_SLOT_CHANGED = Rerange,
		ACTIONBAR_PAGE_CHANGED = Rerange,
		UPDATE_BONUS_ACTIONBAR = Rerange,
		UPDATE_SHAPESHIFT_FORM = Rerange,
		PLAYER_ENTERING_WORLD = Rerange,
	},
	Enable = function()
		if not followingRange then
			followingRange = true
			hooksecurefunc("ActionButton_UpdateRangeIndicator", function(button, checksRange, inRange)
				local h = holders[button]
				if h and range.running then
					SetFar(h, Yes(checksRange) and not issecretvalue(inRange) and not inRange)
				end
			end)
		end
		SyncRangeAll()
		if ns.WarmIcons then ns.WarmIcons() end
	end,
	Disable = function()
		for _, h in pairs(holders) do
			if h.range then SetFar(h, false) end
		end
	end,
})

-- Hooks

-- Post-hooks can't be removed, so each checks that its tweak is on.
function FollowButton(h)
	local button = h.frame
	hooksecurefunc(button, "SetChecked", function()
		if armed.running then SyncArmed(h) end
	end)
	-- UpdateUsable(action, isUsable, notEnoughMana) has just tinted the icon.
	hooksecurefunc(button, "UpdateUsable", function(_, _, _, lacking)
		if afford.running then Judge(h, lacking) end
	end)
end

function FollowItem(h)
	if h.followed then return end
	h.followed = true
	hooksecurefunc(h.frame, "RefreshIconColor", function()
		if afford.running then Judge(h) end
	end)
end

function SyncItems()
	if armed.running then SyncArmedItems() end
	if afford.running then EachItem(Read) end
end

-- The art is made before it is wanted: a button lit or tinted for the first time used to make its textures,
-- mask and animations right then, and the first target out of range does that for a whole bar at once, at a
-- pull. Out of a fight, a few buttons a frame, every button with an action and every cooldown manager icon gets
-- its art made, hidden; one that gets an action later still makes its own when it is first wanted.
local WARM = 4         -- buttons dressed a frame
local warmer = CreateFrame("Frame")
warmer:Hide()
local warmAt, warmItems = 1, false
local function Warm(h)
	if armed.running and not h.armed then ShowArmed(ArmedArt(h), h.on or false) end
	if range.running and not h.item and not h.range then
		local art = RangeArt(h)
		art.wash:SetShown(h.far or false)
		art.ring:SetShown(h.far or false)
	end
end
warmer:SetScript("OnUpdate", function(self)
	if InCombatLockdown() then return end
	local list = Buttons()
	local done = 0
	while done < WARM and warmAt <= #list do
		local h = list[warmAt]
		warmAt = warmAt + 1
		local action = h.frame.action
		local has = not issecretvalue(action) and action and C_ActionBar.HasAction(action)
		if not issecretvalue(has) and has and ((armed.running and not h.armed) or (range.running and not h.range)) then
			Warm(h)
			done = done + 1
		end
	end
	if warmAt > #list then
		if warmItems then
			warmItems = false
			EachItem(Warm)
		end
		self:Hide()
	end
end)
local function WarmAll()
	warmAt, warmItems = 1, true
	warmer:Show()
end
ns.WarmIcons = WarmAll

-- The cooldown manager may load after the tweaks have started.
local late = CreateFrame("Frame")
late:RegisterEvent("ADDON_LOADED")
late:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_CooldownViewer" then Later("items", SyncItems) end
end)

-- Kit-painted and directly colored art doesn't follow the theme by itself.
Shy:On("SHY_THEME", function()
	if numbers.running then FaceAll() end
	if afford.running then Redress() end
end)

-- Slot.Follow pieces update themselves; which corners are square has changed.
Shy:On("SHY_SLOT", function()
	for h in pairs(lit) do ShowArmed(h.armed, true) end
end)
