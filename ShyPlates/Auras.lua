-- The aura row above the name: crowd control from anyone, your debuffs, stealable buffs.
-- Auras can be secret, so the game's aura container (Blizzard_AuraContainer) filters, sorts and lays them out.
-- The container can't be reconfigured in combat or while auras are secret: changes wait (Auras.waiting).

local ADDON, ns = ...
local L = ns.Layout
local UI, Skin = Shy.UI, Shy.Skin

local Auras = {}
ns.Auras = Auras

local MINE, STEAL = 5, 2   -- max shown; crowd control is one

-- rim: the border's color table (kept by reference so it follows the theme).
local function Pieces(frame, w, h, rim)
	frame:SetSize(w, h)
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	-- Crop a square icon to the button's aspect, inside the icon's own border.
	local crop = (1 - h / w) / 2 * 0.84
	icon:SetTexCoord(0.08, 0.92, 0.08 + crop, 0.92 - crop)
	local cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
	cooldown:SetAllPoints(icon)
	cooldown:SetReverse(true)             -- the shade grows as time runs out
	cooldown:SetDrawEdge(false)
	cooldown:SetDrawBling(false)
	cooldown:SetHideCountdownNumbers(true)   -- the time is our own text
	cooldown:SetSwipeColor(0, 0, 0, 0.55)
	local over = CreateFrame("Frame", nil, frame)
	over:SetAllPoints()
	over:SetFrameLevel(cooldown:GetFrameLevel() + 1)
	local edge = over:CreateTexture(nil, "BORDER")
	edge:SetAllPoints()
	edge:SetTexture(L.EDGE)
	edge:SetTextureSliceMargins(L.EDGE_SLICE, L.EDGE_SLICE, L.EDGE_SLICE, L.EDGE_SLICE)
	edge:SetVertexColor(rim[1], rim[2], rim[3])
	local function Label(size, point, x, y)
		local fs = UI.Words(over, UI.NameFont(size, "OUTLINE"), nil, { world = true, justify = "CENTER" })
		fs:SetPoint(point, x, y)
		return fs
	end
	local time = Label(9, "CENTER", 0, 0)
	local count = Label(8, "BOTTOMRIGHT", 1, -1)
	return { icon = icon, cooldown = cooldown, edge = edge, time = time, count = count, rim = rim }
end

-- initializeFrame for a group. EnableMouse goes last: if the game refuses it, the button is already complete.
local function Maker(plate, scale, rim)
	return function(button)
		local p = Pieces(button, L.AURA_W * scale, L.AURA_H * scale, rim)
		table.insert(plate.auraPieces, p)
		button:SetIcon(p.icon)
		button:SetDurationCooldown(p.cooldown)
		button:SetDurationText(p.time)
		button:SetApplicationCount(p.count)
		button:EnableMouse(false)
	end
end

local function Group(plate, scale, most, rim, filters)
	return {
		maxFrameCount = most,
		initializeFrame = Maker(plate, scale, rim),
		candidateFilters = filters,
		sortMethod = AuraContainerSortMethod.Expiration,
		layout = {
			elementSpacing = L.AURA_GAP, groupSpacing = L.AURA_GAP,
			elementWidth = L.AURA_W * scale, elementHeight = L.AURA_H * scale,
		},
	}
end

local GROUPS = { "control", "mine", "steal" }

local function Container(plate)
	local c = CreateFrame("AuraContainer", nil, plate.root, "CustomAuraContainerTemplate")
	c:SetPoint("BOTTOM", plate.name, "TOP", 0, L.AURA_RISE)
	-- The container sizes to its contents, so a single BOTTOM anchor centers the row.
	c:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
	c:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Up)
	c:SetEnabled(false)
	c:Hide()
	c:AddAuraGroup("control", "HARMFUL|CROWD_CONTROL", Group(plate, L.CONTROL, 1, Skin.colors.lit))
	c:AddAuraGroup("mine", "HARMFUL|PLAYER|!CROWD_CONTROL", Group(plate, 1, MINE, Skin.colors.metal))
	c:AddAuraGroup("steal", "HELPFUL", Group(plate, 1, STEAL, UI.colors.alert, { isStealable = true }))
	return c
end

function Auras.Build(plate)
	plate.auraPieces, plate.auraSetting = {}, {}
	plate.auras = Container(plate)
end

local function Restricted()
	return InCombatLockdown() or C_Secrets.ShouldAurasBeSecret()
end
Auras.Restricted = Restricted

Auras.pending = setmetatable({}, { __mode = "k" })   -- plates whose groups wait for the fight to end

-- The fight is over: each plate that waited has its groups set.
function Auras.CatchUp()
	Auras.waiting = false
	for plate in pairs(Auras.pending) do Auras.Arrange(plate) end
end

-- Applies settings: enabled groups and scale.
function Auras.Arrange(plate)
	local c, db = plate.auras, ns.T.db
	if not c then return end
	if Restricted() then
		-- Retried by Driver.lua once allowed, for this plate alone (Auras.CatchUp): a plate built in a fight
		-- needs its own groups set, not every plate laid out again.
		ns.Auras.waiting = true
		Auras.pending[plate] = true
		return
	end
	Auras.pending[plate] = nil
	local want = { control = db.control, mine = db.auras, steal = db.steal, scale = db.auraSize }
	local have = plate.auraSetting
	for _, key in ipairs(GROUPS) do
		if have[key] ~= want[key] then
			c:SetAuraGroupEnabled(key, want[key])
			have[key] = want[key]
		end
	end
	if have.scale ~= want.scale then
		c:SetScale(want.scale)
		have.scale = want.scale
	end
end

-- Auras show only for a non-friendly unit on a full plate.
function Auras.Attach(plate)
	local c, unit = plate.auras, plate.unit
	if not c then return end
	local db = ns.T.db
	local wanted = unit ~= nil and plate.mode == "full" and (db.auras or db.control or db.steal) and not plate:IsFriend()
	if not wanted then
		Auras.Detach(plate)
		return
	end
	if plate.auraUnit ~= unit then
		c:SetUnit(unit)
		plate.auraUnit = unit
	end
	if not plate.aurasOn then
		c:SetEnabled(true)
		c:Show()
		plate.aurasOn = true
	end
end

function Auras.Detach(plate)
	local c = plate.auras
	if not c or not plate.aurasOn then return end
	plate.aurasOn = false
	c:SetEnabled(false)
	c:Hide()
end

-- Repaints borders on a theme change. Skipped while restricted: the borders catch up on the next change.
function Auras.Paint(plate)
	if plate.auraPieces and not Restricted() then
		for _, p in ipairs(plate.auraPieces) do
			p.edge:SetVertexColor(p.rim[1], p.rim[2], p.rim[3])
		end
	end
end
