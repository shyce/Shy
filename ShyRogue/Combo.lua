-- Combo points: round pips on a UI.Panel, with a pulsing halo at full.
-- Lit pips use Shy.Theme.Combo (gold to crimson), not the accent: a rogue's class color is the energy bar's yellow.
-- Docked by ShyDock (Shy.HUD's `docked` callback), the box becomes a slot of five leaning blades instead.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI
local Steel = Shy.Skin.colors

local MEDIA = "Interface\\AddOns\\ShyRogue\\Media\\"
local PIP, GAP, PAD = 24, 8, 10
-- Docked geometry; the numbers must match the Dock*.tga art. The slot is w x h with its texture `slot` past it;
-- `count` blades, each `body` x `tall`, leaning `lean` of their height, `gap` apart, the first at (x, y);
-- blade textures reach `margin` past the blade, the glow `glow`.
local DOCK = {
	w = 112, h = 14, slot = 4,
	count = 5, body = 16, tall = 8, lean = 5 / 7, gap = 3,
	x = 6.986, y = 3,
	margin = 3, canvas = { 28, 14 },
	glow = 6, glowCanvas = { 34, 20 },
	art = MEDIA .. "DockBlade", well = MEDIA .. "DockWell", shadow = MEDIA .. "DockShadow",
	light = MEDIA .. "DockGlow", slotArt = MEDIA .. "DockSlot",
}
T.Blades = DOCK   -- read by ShyDock's preview
local GAIN = 0.35                    -- seconds a blade flashes when its point arrives
local LIGHT = 0.4                    -- strength of a lit blade's glow

local box, pips, halo = nil, {}, nil
local blades, row = {}, nil
local docked = false
local points, maxPoints = 0, 5
local Wake

local function Wanted()
	local db = T.db.combo
	if not db.shown then return false end
	if db.when == "always" then return true end
	if db.when == "combat" then return UnitAffectingCombat("player") end
	return UnitExists("target") and UnitCanAttack("player", "target")
end

local function Size()
	if docked then
		box:SetSize(DOCK.w, DOCK.h)
	else
		box:SetSize(PAD * 2 + maxPoints * PIP + (maxPoints - 1) * GAP, PIP + PAD * 2)
	end
	halo:SetSize(box:GetWidth() + 40, box:GetHeight() + 50)
end

local function Build()
	for i = 1, maxPoints do
		local pip = pips[i]
		if not pip then
			pip = CreateFrame("Frame", nil, box)
			pip:SetSize(PIP, PIP)
			local mask = pip:CreateMaskTexture()
			mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			mask:SetAllPoints()
			pip.ring = pip:CreateTexture(nil, "BACKGROUND")
			pip.ring:SetAllPoints()
			pip.ring:AddMaskTexture(mask)
			pip.light = function() return Shy.Theme.Combo(i, maxPoints) end
			pip.fill = pip:CreateTexture(nil, "ARTWORK")
			pip.fill:SetPoint("TOPLEFT", 3, -3)
			pip.fill:SetPoint("BOTTOMRIGHT", -3, 3)
			pip.fill:SetColorTexture(1, 1, 1, 1)
			pip.fill:AddMaskTexture(mask)
			pip.shine = pip:CreateTexture(nil, "OVERLAY")
			pip.shine:SetPoint("TOPLEFT", 5, -4)
			pip.shine:SetPoint("TOPRIGHT", -5, -4)
			pip.shine:SetHeight(PIP / 3)
			pip.shine:SetColorTexture(1, 1, 1, 0.3)
			pip.shine:AddMaskTexture(mask)
			pips[i] = pip
		end
		pip:ClearAllPoints()
		pip:SetPoint("CENTER", box, "LEFT", PAD + PIP / 2 + (i - 1) * (PIP + GAP), 0)
		pip:SetShown(not docked)
	end
	for i = maxPoints + 1, #pips do pips[i]:Hide() end
	Size()
end

-- Docked art sits at fractional offsets; pixel snapping would make the gaps between blades uneven.
local function Art(layer, sublevel, file)
	local t = row:CreateTexture(nil, layer, nil, sublevel)
	t:SetTexture(file)
	t:SetSnapToPixelGrid(false)
	t:SetTexelSnappingBias(0)
	return t
end

-- Each blade is a well, shadow, glow, fill and flash. The slot art fits DOCK.count blades;
-- any other maximum stretches the blades to fill the same width, keeping the gap.
local function BuildBlades()
	local D = DOCK
	if not row then
		row = CreateFrame("Frame", nil, box)
		row:SetAllPoints()
		row:Hide()
		row.slot = Art("BACKGROUND", 0, D.slotArt)
		row.slot:SetPoint("BOTTOMLEFT", -D.slot, -D.slot)
		row.slot:SetSize(D.w + 2 * D.slot, D.h + 2 * D.slot)
		UI.Tint(row.slot, Steel.metal)
	end
	local room = D.count * D.body + (D.count - 1) * D.gap
	local body = (room + D.gap) / maxPoints - D.gap
	local stretch = (body + D.lean * D.tall) / (D.body + D.lean * D.tall)
	for i = 1, maxPoints do
		local b = blades[i]
		if not b then
			b = {}
			b.well = Art("ARTWORK", 0, D.well)
			b.shadow = Art("ARTWORK", 1, D.shadow)
			b.shadow:SetVertexColor(0, 0, 0)
			b.shadow:SetAlpha(0)
			b.glow = Art("ARTWORK", 2, D.light)
			b.glow:SetBlendMode("ADD")
			b.glow:SetAlpha(0)
			b.fill = Art("ARTWORK", 3, D.art)
			b.fill:SetAlpha(0)
			b.flash = Art("OVERLAY", 0, D.art)
			b.flash:SetBlendMode("ADD")
			b.flash:SetAlpha(0)
			blades[i] = b
		end
		local r, g, bl = Shy.Theme.Combo(i, maxPoints)
		local x = D.x + (i - 1) * (body + D.gap)
		for _, t in ipairs({ b.well, b.shadow, b.fill, b.flash }) do
			t:ClearAllPoints()
			t:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x - D.margin * stretch, D.y - D.margin)
			t:SetSize(D.canvas[1] * stretch, D.canvas[2])
			t:Show()
		end
		b.glow:ClearAllPoints()
		b.glow:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x - D.glow * stretch, D.y - D.glow)
		b.glow:SetSize(D.glowCanvas[1] * stretch, D.glowCanvas[2])
		b.glow:Show()
		b.well:SetVertexColor(0.05 + r * 0.26, 0.05 + g * 0.26, 0.05 + bl * 0.26)
		b.glow:SetVertexColor(r * LIGHT, g * LIGHT, bl * LIGHT)   -- additive blend: darker means fainter
		b.fill:SetVertexColor(r, g, bl)
	end
	for i = maxPoints + 1, #blades do
		for _, t in pairs(blades[i]) do
			if type(t) == "table" then t:Hide() end
		end
	end
end

local function Paint()
	for i = 1, maxPoints do
		local lit = i <= points
		local pip = pips[i]
		if pip then
			UI.Paint(pip.ring, lit and Steel.metal or Steel.idle)
			UI.Tint(pip.fill, lit and pip.light or Steel.well)
			pip.shine:SetShown(lit)
		end
		local b = blades[i]
		if b then
			b.fill:SetAlpha(lit and 1 or 0)
			b.shadow:SetAlpha(lit and 1 or 0)
			b.glow:SetAlpha(lit and 1 or 0)
		end
	end
end

-- The light: a breath at full, a flash on each point that arrives, a pip that pops. It runs only while one of
-- them does (Wake starts it); with nothing to light the box costs nothing a frame.
local function Animate(self, dt)
	local full = points >= maxPoints and maxPoints > 0
	local t = GetTime()
	if docked then
		local busy = full
		local breath = full and (0.7 + 0.3 * math.sin(t * 5)) or 1
		for i, b in ipairs(blades) do
			if b.flashing then
				b.flashing = b.flashing - dt
				if b.flashing <= 0 then b.flashing = nil end
				b.flash:SetAlpha(b.flashing and b.flashing / GAIN or 0)
				busy = true
			end
			-- Short of full the glow stands as Paint left it; only a full row breathes.
			if full and i <= points then b.glow:SetAlpha(breath) end
		end
		return busy
	end
	if full then
		halo:SetAlpha(0.45 + 0.25 * math.sin(t * 5))
		halo:SetVertexColor(Shy.Theme.Combo(maxPoints, maxPoints))
		self.haloLit = true
	elseif self.haloLit ~= false then
		halo:SetAlpha(0)
		self.haloLit = false
	end
	if self.pop then
		self.pop = self.pop - dt * 4
		local lit = pips[points]
		if lit then
			local s = PIP * (1 + 0.25 * math.max(0, self.pop))
			lit:SetSize(s, s)
		end
		if self.pop <= 0 then
			self.pop = nil
			for _, pip in ipairs(pips) do pip:SetSize(PIP, PIP) end
		end
	end
	return full or self.pop ~= nil
end

local function Run(self, dt)
	if not Animate(self, dt) then self:SetScript("OnUpdate", nil) end
end

function Wake()
	if box and not box:GetScript("OnUpdate") then box:SetScript("OnUpdate", Run) end
end

local function Update()
	local count = GetComboPoints("player", "target")
	-- Can be a secret value in combat; keep the last count shown.
	if issecretvalue(count) then return end
	local newMax = UnitPowerMax("player", Enum.PowerType.ComboPoints)
	local rebuilt = false
	if not issecretvalue(newMax) and newMax > 0 and newMax ~= maxPoints then
		maxPoints = newMax
		Build()
		if row then BuildBlades() end
		rebuilt = true
	end
	if count > points then
		box.pop = 1
		for i = points + 1, count do
			if blades[i] then blades[i].flashing = GAIN end
		end
	end
	-- Your energy moving is a power event too, many a second: the pips are painted only when they change.
	local changed = rebuilt or count ~= points
	points = count
	if changed then
		Paint()
		Wake()
	end
	Shy.HUD.Update(box)
end

-- Docked: the slot and blades with no panel. Undocked: the pips on their panel.
local function SetDocked(on)
	docked = on and true or false
	for _, key in ipairs({ "shyBg", "shyEdge", "shyLine", "shyStrip" }) do
		if box[key] then box[key]:SetShown(not docked) end
	end
	for _, t in ipairs(box.shyBrackets or {}) do t:SetShown(not docked) end
	for _, pip in ipairs(pips) do pip:SetShown(not docked) end
	halo:SetShown(not docked)
	if docked then
		BuildBlades()
		row:Show()
	elseif row then
		row:Hide()
	end
	Size()
	Paint()
	Wake()
end

function ns.SetupCombo()
	box = Shy.HUD.Create({
		id = "shyrogue-combo",
		title = "Combo points",
		width = 170,
		height = 44,
		point = { "CENTER", "CENTER", 0, -170 },
		shown = Wanted,
		docked = function(_, on) SetDocked(on) end,
	})
	UI.Panel(box, { brackets = 10, hud = true })

	-- The halo goes under the panel's fill, the box's lowest layer, so it needs a frame one level down.
	local under = CreateFrame("Frame", nil, box)
	under:SetAllPoints()
	under:SetFrameLevel(math.max(0, box:GetFrameLevel() - 1))
	halo = under:CreateTexture(nil, "BACKGROUND")
	halo:SetTexture(B.GLOW)
	halo:SetBlendMode("ADD")
	halo:SetPoint("CENTER")
	halo:SetAlpha(0)

	Build()
	Paint()   -- Update() skips painting when the first count is secret

	Wake()

	box:EnableMouse(true)
	box:SetScript("OnEnter", function(self) ns.ShowLootTooltip(self) end)
	box:SetScript("OnLeave", function(self) UI.TipHide(self) end)

	local events = CreateFrame("Frame")
	events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
	for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", Update)
	table.insert(ns.refreshers, Update)
	Update()
end
