-- The bag column: a band beside the ShyBags window's items with a slot for each bag you carry and the key
-- ring, shown and hidden by the rail's bag switch. Hovering a bag lights its slots in the grid; a bag is
-- changed by dragging one on or off its slot, and a click with something carried puts it in. Ordinary bags
-- stand first; bags for one kind of thing (quiver, ammo pouch, soul, herb and enchanting bags) and the key
-- ring stand past a steel rule, framed in their kind's color. The default bag bar stands down (SetRolesets,
-- as the unit frames do) while the setting says so, or is restyled to match, or left alone.
--   BagBar.Apply()      after a setting changes
--   BagBar.Each(fn)     fn(entry) per slot: { button, kind = "bag" | "keys", inv, bag, filled, lit,
--                       special (past the rule), color (its kind's) }
--   BagBar.Frame()      the band, or nil when the window failed to build
--   BagBar.NewSlot(parent, color, template)   a slot of the column's make, for the bank's bag slots too:
--                       { button, icon, slot, light, count }; BagBar.KindColor(bag); BagBar.SIZE, BagBar.GAP
-- The column or the default bar as one choice, for other addons: T:BagButtons(), T:SetBagButtons(where).

local ADDON, ns = ...
local T = ns.T
local UI, Skin, Slot = Shy.UI, Shy.Skin, Shy.Slot
local C, SC = UI.colors, Skin.colors

local BagBar = {}
ns.BagBar = BagBar

T.defaults.bagRow = true         -- the column of bag slots in the window
T.defaults.bar = true            -- hide the default bag bar
T.defaults.bagbar = true         -- with the default bar shown: restyle it

local KEYS = Enum.BagIndex.Keyring
local BLOCKED = "alwaysBlocked"
local SIZE, GAP = Slot.SIZES.compact, 4   -- compact slots: the column is a strip beside the items, not more items
BagBar.SIZE, BagBar.GAP = SIZE, GAP
local SEAM = 13                        -- across the rule, between the ordinary bags and the rest
local CROP = 0.08                      -- trims an icon's dark rim, as on action buttons
local KEYS_ICON = "Interface\\Icons\\INV_Misc_Key_05"

-- A bag's family (the bitfield the game answers with its free slots) and the color of its kind: meaning
-- colors, not the accent. Leather for arrows and shot, shadow for souls, green for herbs, arcane for
-- enchanting, ink, copper and the like for the rest.
local FAMILY = {
	{ bit = 1, color = { 0.78, 0.62, 0.38 } },      -- quiver
	{ bit = 2, color = { 0.78, 0.62, 0.38 } },      -- ammo pouch
	{ bit = 4, color = { 0.64, 0.42, 0.92 } },      -- soul bag
	{ bit = 8, color = { 0.72, 0.50, 0.32 } },      -- leatherworking
	{ bit = 16, color = { 0.56, 0.62, 0.80 } },     -- inscription
	{ bit = 32, color = { 0.44, 0.78, 0.40 } },     -- herbs
	{ bit = 64, color = { 0.52, 0.60, 0.96 } },     -- enchanting
	{ bit = 128, color = { 0.86, 0.60, 0.30 } },    -- engineering
	{ bit = 512, color = { 0.90, 0.48, 0.62 } },    -- gems
	{ bit = 1024, color = { 0.80, 0.52, 0.30 } },   -- mining
}
local OTHER = { 0.62, 0.66, 0.72 }       -- a kind not listed: steel, lighter
local KEYS_COLOR = { 0.84, 0.70, 0.40 }  -- brass

local band, rule
local entries = {}         -- our slots
local own, down, refused   -- the default bar's own rolesets; whether it is stood down; the engine wouldn't
local later = {}           -- protected work waiting for the end of combat, by key
local kit = Skin.NewKit()  -- the restyle of the default bar
local hooked, painted = false, false

local function WhenFree(key, fn)
	if InCombatLockdown() then
		later[key] = fn
	else
		later[key] = nil
		fn()
	end
end

function BagBar.Each(fn)
	for _, e in ipairs(entries) do fn(e) end
end

function BagBar.Frame()
	return band
end

-- The default bar, restyled

-- The backpack and key ring are always filled; a bag slot only with a bag equipped.
local function Filled(button)
	local name = button:GetName()
	if not (type(name) == "string" and name:find("^Character%a*Bag%d+Slot$") and button.HasBagEquipped) then return true end
	return button:HasBagEquipped() and true or false
end

local function PaintButton(button)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Unmask(button.icon, button.SquareMask)
	kit:Crop(button.icon, CROP, 1 - CROP, CROP, 1 - CROP)
	local filled = Filled(button)
	kit:Tile(button, { icon = button.icon }):Empty(not filled)
	kit:Fade(button.icon, filled and 1 or 0)
	kit:Lit(button:GetPushedTexture(), button, SC.lit)
	kit:Lit(button.SlotHighlightTexture, button, SC.on)   -- shown while that bag is open
	kit:Number(button.Count)
	kit:Number(button.FreeSlots)
end

-- Dividers are pooled and created as the bar lays out.
local function HideDividers()
	for _, key in ipairs({ "HorizontalDividersPool", "VerticalDividersPool" }) do
		local pool = BagsBar[key]
		if pool then
			for divider in pool:EnumerateActive() do kit:Hide(divider) end
		end
	end
end

local function PaintDefault()
	kit:Hide(BagsBar.BorderArt)
	for _, button in MainMenuBarBagManager:EnumerateBagButtons() do PaintButton(button) end
	kit:Button(BagBarExpandToggle, SC.glyph, SC.glyph, SC.hover)
	HideDividers()
	painted = true
end

local function Hook()
	if hooked then return end
	hooked = true
	for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
		hooksecurefunc(button, "UpdateTextures", function(self)
			if painted then PaintButton(self) end
		end)
	end
	hooksecurefunc(BagsBar, "UpdateDividers", function()
		if painted then HideDividers() end
	end)
end

-- The default containers are reparented (Takeover.lua) and never signal "open", so the lights are set here.
local function LightDefault()
	if down or not ns.Takeover.IsOn() then return end
	local open = ns.Takeover.Visible()
	for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
		button.SlotHighlightTexture:SetShown(open)
	end
end

-- Standing the default bar down

local function StandDown()
	if down or refused then return end
	local tags = BagsBar:GetRolesetNames()
	-- A frame with no tags returns "roleless".
	own = (#tags > 0 and tags[1] ~= "roleless") and table.concat(tags, ",") or false
	BagsBar:SetRolesets(BLOCKED)
	-- Only a shown frame can confirm the engine filters it.
	if BagsBar:IsShown() and not BagsBar:IsRolesetFiltered() then
		BagsBar:SetRolesets(own or nil)
		refused = true
		T:Print("the default bag bar can't be hidden on this client, so it stays.")
		return
	end
	down = true
	ns.Own("bagbar", true)
end

local function Restore()
	if not down then return end
	BagsBar:SetRolesets(own or nil)
	down = false
	ns.Own("bagbar", false)
end

-- The column

-- Never read where the game has no key ring.
local function Keys()
	local n = 0
	if C_ActionBar.ShouldShowKeyring() ~= true then return n end
	for slot = 1, C_Container.GetContainerNumSlots(KEYS) do
		if C_Container.GetContainerItemInfo(KEYS, slot) then n = n + 1 end
	end
	return n
end

-- The color of a bag's kind, or nil for an ordinary bag.
local function KindColor(bag)
	local _, family = C_Container.GetContainerNumFreeSlots(bag)
	if type(family) ~= "number" or family == 0 then return nil end
	for _, def in ipairs(FAMILY) do
		if math.floor(family / def.bit) % 2 == 1 then return def.color end
	end
	return OTHER
end
BagBar.KindColor = KindColor

local function KeysUp()
	local _, keys = ns.Takeover.Visible()
	return keys == true or ns.Window.Wing() == "keys"
end

local function Relight()
	for _, e in ipairs(entries) do
		e.lit = e.kind == "keys" and KeysUp()
		e.light:SetShown(e.lit)
	end
end

-- Returns true when the slot changed sides of the rule.
local function Paint(e)
	local slot = e.slot
	local was = e.special
	if e.kind == "keys" then
		-- Until the first key is found the ring is a dim slot, as the default one.
		local known = GetCVarBool("showKeyring") == true
		local n = Keys()
		e.filled = true
		e.icon:SetAlpha(known and 1 or 0.4)
		slot:Empty(not known)
		e.count:SetText(n > 0 and n or "")
	else
		local icon = GetInventoryItemTexture("player", e.inv)
		e.filled = icon ~= nil
		e.icon:SetTexture(icon)
		e.icon:SetShown(e.filled)
		slot:Empty(not e.filled)
		e.color = e.filled and KindColor(e.bag) or nil
		e.special = e.color ~= nil
		slot:Steel(e.color)
		-- An ordinary bag shows its quality; a kind's color says enough.
		slot:Quality((e.filled and not e.special) and GetInventoryItemQuality("player", e.inv) or nil)
		e.icon:SetDesaturated(e.filled and IsInventoryItemLocked(e.inv) == true)
	end
	return was ~= e.special
end

-- Down the band: the ordinary bags, then past the rule the bags of a kind and the key ring.
local function Layout()
	if not band then return end
	local order = {}
	local function Take(test)
		for _, e in ipairs(entries) do
			local show = e.kind ~= "keys" or C_ActionBar.ShouldShowKeyring() == true
			e.button:SetShown(show)
			if show and test(e) then order[#order + 1] = e end
		end
	end
	Take(function(e) return e.kind == "bag" and not e.special end)
	Take(function(e) return e.kind == "bag" and e.special end)
	Take(function(e) return e.kind == "keys" end)

	local at, ruleAt = 0, nil
	for i, e in ipairs(order) do
		local past = e.kind == "keys" or e.special
		if i > 1 then
			if past and not ruleAt then
				ruleAt = at + SEAM / 2
				at = at + SEAM
			else
				at = at + GAP
			end
		end
		e.button:ClearAllPoints()
		e.button:SetPoint("TOPLEFT", band, "TOPLEFT", 0, -at)
		at = at + SIZE
	end
	rule:ClearAllPoints()
	if ruleAt then rule:SetPoint("LEFT", band, "TOPLEFT", 0, -ruleAt) end
	rule:SetShown(ruleAt ~= nil)
	band:SetSize(SIZE, math.max(at, SIZE))
end

local function Repaint()
	if not band then return end
	local moved = false
	for _, e in ipairs(entries) do
		if Paint(e) then moved = true end
	end
	Relight()
	if moved then
		Layout()
		ns.Window.Refresh()
	end
end

local function Enter(e)
	local button = e.button
	if e.kind == "keys" then
		local n = Keys()
		UI.Tip(button, "Key ring", n == 0 and "No keys yet." or (n .. (n == 1 and " key" or " keys")), {
			side = "RIGHT",
			hints = { { "left", KeysUp() and "Close" or "Open" } },
		})
	elseif e.filled then
		GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
		GameTooltip:SetInventoryItem("player", e.inv)
		GameTooltip:Show()
		-- Its slots in the grid, empty ones too, stand out in its kind's color, or the accent's light.
		ns.Window.Focus(e.bag, e.color or C.hot)
	else
		UI.Tip(button, "Bag slot", "Drag a bag here to carry it.", { side = "RIGHT" })
	end
end

local function Leave(e)
	UI.TipHide(e.button)
	if e.kind == "bag" then
		GameTooltip:Hide()
		ns.Window.Focus(nil)
	end
end

-- The key ring opens as a wing of the window, and closes again.
local function ToggleKeys()
	local _, keysUp = ns.Takeover.Visible()
	if keysUp then
		ns.Takeover.CloseKeys()
	elseif ns.Window.Wing() == "keys" then
		ns.Window.Open(nil)
	else
		ns.Window.Open("keys")
	end
end

local function Click(e)
	if e.kind == "keys" then
		if CursorHasItem() then PutKeyInKeyRing() else ToggleKeys() end
	elseif CursorHasItem() then
		PutItemInBag(e.inv)
	end
end

-- A bag slot of the column's make on `parent`: the bag's picture in a compact slot (framed in `color`), a
-- pushed glow and a light to show while it is in use. `template`: the game's own button to make it from.
function BagBar.NewSlot(parent, color, template)
	local e = {}
	local button = CreateFrame("Button", nil, parent, template)
	e.button = button
	button:SetSize(SIZE, SIZE)
	button:RegisterForClicks("AnyUp")
	e.icon = button:CreateTexture(nil, "BORDER")
	e.icon:SetAllPoints(button)
	e.icon:SetTexCoord(CROP, 1 - CROP, CROP, 1 - CROP)
	-- A pushed texture is set from an asset; the slot then lays its glow over it.
	button:SetPushedTexture(Skin.BAR)
	e.light = button:CreateTexture(nil, "OVERLAY", nil, 1)
	e.light:Hide()
	e.count = button:CreateFontString(nil, "OVERLAY")
	e.slot = Slot.New(button, { icon = e.icon, color = color, size = SIZE })
	e.slot:Light(button:GetPushedTexture(), SC.lit)
	e.slot:Light(e.light, color or SC.on)
	e.slot:Count(e.count)
	return e
end

local function Make(source)
	local kind = source == KeyRingButton and "keys" or "bag"
	local e = BagBar.NewSlot(band, kind == "keys" and KEYS_COLOR or nil)
	e.source, e.kind, e.special = source, kind, false
	if e.kind == "keys" then
		e.bag, e.color = KEYS, KEYS_COLOR
		e.icon:SetTexture(KEYS_ICON)
	else
		e.inv, e.bag = source:GetID(), source:GetBagID()
	end
	local button = e.button
	button:SetScript("OnEnter", function() Enter(e) end)
	button:SetScript("OnLeave", function() Leave(e) end)
	button:SetScript("OnClick", function() Click(e) end)
	if e.kind == "bag" then
		button:RegisterForDrag("LeftButton")
		button:SetScript("OnDragStart", function()
			if e.filled then PickupBagFromSlot(e.inv) end
		end)
		button:SetScript("OnReceiveDrag", function() PutItemInBag(e.inv) end)
	else
		button:SetScript("OnReceiveDrag", function()
			if CursorHasItem() then PutKeyInKeyRing() end
		end)
	end
	return e
end

local function Rank(e)
	if e.kind == "keys" then return 100 end
	return e.inv
end

-- The rule across the column: a groove cut in the steel, a dark edge over a lit one, the light a
-- reflection that is brightest at the middle and fades toward the ends. No color: steel and white only.
local function MakeRule()
	rule = CreateFrame("Frame", nil, band)
	rule:SetSize(SIZE, 10)
	local wide = SIZE - 4
	rule.shade = rule:CreateTexture(nil, "ARTWORK")
	rule.shade:SetSize(wide, 1)
	rule.shade:SetPoint("CENTER", 0, 1)
	UI.Paint(rule.shade, { 0, 0, 0 }, 0.6)
	-- The lit edge in two halves, each fading away from the middle.
	rule.edge = rule:CreateTexture(nil, "ARTWORK")
	rule.edge:SetSize(wide / 2, 1)
	rule.edge:SetPoint("LEFT", rule, "CENTER", 0, 0)
	rule.edge:SetColorTexture(1, 1, 1, 1)
	rule.edge:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.8), CreateColor(1, 1, 1, 0))
	rule.edgeLow = rule:CreateTexture(nil, "ARTWORK")
	rule.edgeLow:SetSize(wide / 2, 1)
	rule.edgeLow:SetPoint("RIGHT", rule, "CENTER", 0, 0)
	rule.edgeLow:SetColorTexture(1, 1, 1, 1)
	rule.edgeLow:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.8))
	-- A faint white bloom where the light is strongest.
	rule.glow = rule:CreateTexture(nil, "ARTWORK", nil, 1)
	rule.glow:SetTexture(Shy.Brand.GLOW)
	rule.glow:SetBlendMode("ADD")
	rule.glow:SetSize(wide, 12)
	rule.glow:SetPoint("CENTER", 0, 0.5)
	rule.glow:SetAlpha(0.16)
	rule:Hide()
end

local function Build()
	band = CreateFrame("Frame", nil, UIParent)
	band:SetSize(SIZE, SIZE)
	-- The hairline between the items and the column, as the one before a wing.
	band.line = band:CreateTexture(nil, "ARTWORK")
	band.line:SetPoint("TOPLEFT", band, "TOPLEFT", -7, 0)
	band.line:SetPoint("BOTTOMLEFT", band, "BOTTOMLEFT", -7, 0)
	band.line:SetWidth(1)
	UI.Paint(band.line, C.border, 0.9)
	-- Opening the column: it comes up in a short fade.
	band.fade = band:CreateAnimationGroup()
	local alpha = band.fade:CreateAnimation("Alpha")
	alpha:SetFromAlpha(0)
	alpha:SetToAlpha(1)
	alpha:SetDuration(0.18)
	band.Reveal = function()
		band.fade:Stop()
		band.fade:Play()
	end
	band.OnRefresh = Relight
	MakeRule()
	for _, source in MainMenuBarBagManager:EnumerateBagButtons() do
		if not (type(source.IsBackpack) == "function" and source:IsBackpack()) then entries[#entries + 1] = Make(source) end
	end
	table.sort(entries, function(a, b) return Rank(a) < Rank(b) end)
	for _, e in ipairs(entries) do Paint(e) end
	Layout()
	Relight()
	-- Shown for your own bags while the setting is on; the title strip's switch flips it.
	local placed = ns.Window.SetBand(band, nil,
		function(mine) return T.db.bagRow == true and mine ~= false end,
		function(on) T.db.bagRow = on and true or false end)
	if not placed then error("the window is not there to hold the bag column") end
end

function BagBar.Apply()
	if T.db.bar then WhenFree("stand", StandDown) else WhenFree("stand", Restore) end
	if not down and T.db.bagbar then
		Hook()
		PaintDefault()
	elseif painted then
		kit:Restore()
		painted = false
	end
	LightDefault()
	if band then
		Repaint()
		ns.Window.Refresh()
	end
end

-- Where the bag buttons are, as one choice: "window" is the column beside the items with the default bar
-- off the screen, "screen" the default bar and no column.
function T:BagButtons()
	return T.db.bar and "window" or "screen"
end

function T:SetBagButtons(where)
	local window = where ~= "screen"
	T.db.bar, T.db.bagRow = window, window
	BagBar.Apply()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- The key that opens the bags, as the game writes it; nil with none bound.
function T:BagsKey()
	local key = GetBindingKey("TOGGLEBACKPACK") or GetBindingKey("OPENALLBAGS")
	return key and GetBindingText(key) or nil
end

function BagBar.Init()
	-- Once per profile: carry over ShySkin's bag bar setting.
	if not T.db.adoptedBagbar then
		T.db.adoptedBagbar = true
		local old = ShySkinDB
		if type(old) == "table" and type(old.modules) == "table" and old.modules.bagbar == false then T.db.bagbar = false end
	end
	local ok, err = pcall(Build)
	if not ok then
		band = nil
		T:Print("the bag column failed to load: " .. tostring(err))
		geterrorhandler()(err)
	end
	BagBar.Apply()

	ns.Takeover.OnChange(function()
		Relight()
		LightDefault()
	end)
	-- The default bags clear every bag light when the mouse leaves an item.
	EventRegistry:RegisterCallback("ContainerFrameItemButton.ExitButton", function()
		C_Timer.After(0, LightDefault)
	end, BagBar)
	Shy:On("SHY_THEME", function()
		if painted then
			kit:Restore()
			PaintDefault()
		end
	end)

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "CVAR_UPDATE", "PLAYER_REGEN_ENABLED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, arg)
		if event == "PLAYER_REGEN_ENABLED" then
			if not next(later) then return end
			local work = later
			later = {}
			for _, fn in pairs(work) do fn() end
		elseif event == "CVAR_UPDATE" then
			if arg == "showKeyring" then Repaint() end
		else
			Repaint()
		end
	end)
end
