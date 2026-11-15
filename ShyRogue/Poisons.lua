-- Poison reminders: a box when a weapon's poison is missing or running out, with a reapply button per weapon.
-- The buttons are secure (use item on a weapon slot), so the box hides in combat and is only laid out outside it.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local WIDTH, PAD, ROW = 290, 10, 40
local TOP = UI.HEAD.piece.line + UI.LINE + 8   -- the first row, under the header

local SLOTS = {
	{ key = "mainHand", label = "Main hand", slot = INVSLOT_MAINHAND, weapon = Enum.WeaponSlot.MainHand },
	{ key = "offHand", label = "Off hand", slot = INVSLOT_OFFHAND, weapon = Enum.WeaponSlot.OffHand },
}

local box, rows, lowStock
local state = {}

local function PoisonKind(key)
	for _, kind in ipairs(ns.POISONS) do
		if kind.key == key then return kind end
	end
end

-- Highest usable rank in the bags: item ID, count.
function ns.BestPoison(key)
	local kind = PoisonKind(key)
	if not kind then return end
	for i = #kind.items, 1, -1 do
		local id = kind.items[i]
		local count = C_Item.GetItemCount(id)
		if count > 0 and C_Item.IsUsableItem(id) then return id, count end
	end
end

local function HasWeapon(slot)
	local id = GetInventoryItemID("player", slot)
	if not id then return false end
	local classID = select(6, C_Item.GetItemInfoInstant(id))
	return classID == Enum.ItemClass.Weapon
end

-- A poison is the weapon's temporary enchant.
local function Coating(weaponSlot)
	for _, enchant in ipairs(C_Item.GetWeaponEnchantInfo(weaponSlot)) do
		if enchant.hasEnchant and enchant.enchantType ~= Enum.ItemEnchantType.Permanent then return enchant end
	end
end

-- The name comes from the weapon's tooltip line, "Instant Poison VI (29 min)".
-- A tooltip is built to read it, so a name found is kept by the enchant's ID: a scan runs every few seconds.
local coatingNames = {}
local function CoatingName(slot, enchant)
	local id = enchant and enchant.enchantID
	if id and coatingNames[id] then return coatingNames[id] end
	local data = C_TooltipInfo.GetInventoryItem("player", slot)
	for _, line in ipairs(data and data.lines or {}) do
		local name = line.leftText and line.leftText:match("^(.-) %(%d+ %a+%)$")
		if name then
			if id then coatingNames[id] = name end
			return name
		end
	end
	return "Poison"
end

local function Scan()
	local db = T.db.poisons
	for _, s in ipairs(SLOTS) do
		local st = state[s.key] or {}
		state[s.key] = st
		st.weapon = HasWeapon(s.slot)
		local coating = st.weapon and Coating(s.weapon)
		st.coated = coating ~= nil
		st.timeLeft = coating and coating.timeLeft / 1000 or 0
		st.charges = coating and coating.charges or 0
		st.name = coating and CoatingName(s.slot, coating)
		st.item, st.count = ns.BestPoison(db[s.key])
		st.need = st.weapon and (not st.coated or st.timeLeft < db.warnMinutes * 60
			or (st.charges > 0 and st.charges < db.warnCharges))
	end
end

local function Needed()
	if not T.db.poisons.shown or UnitLevel("player") < 20 then return false end
	for _, st in pairs(state) do
		if st.need then return true end
	end
	return false
end

local function Status(st)
	if not st.coated then return "No poison", C.bad end
	local minutes = math.floor(st.timeLeft / 60)
	local time = minutes >= 1 and (minutes .. "m left") or (math.floor(st.timeLeft) .. "s left")
	local text = st.name .. "  \194\183  " .. time
	if st.charges > 0 then text = text .. "  \194\183  " .. st.charges .. " charges" end
	return text, st.need and C.alert or C.good
end

local function CreateRow(i, s)
	local row = CreateFrame("Frame", nil, box)
	row:SetSize(WIDTH - PAD * 2, ROW - 4)
	row:SetPoint("TOPLEFT", PAD, -TOP - (i - 1) * ROW)

	row.weapon = row:CreateTexture(nil, "ARTWORK")
	row.weapon:SetSize(28, 28)
	row.weapon:SetPoint("LEFT")
	Shy.Slot.New(row, { to = row.weapon, icon = row.weapon, hover = false })
	row.label = UI.Text(row, s.label, 13, true)
	row.label:SetPoint("TOPLEFT", row.weapon, "TOPRIGHT", 8, 0)
	row.status = UI.Text(row, "", 11)
	row.status:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
	row.status:SetWidth(WIDTH - PAD * 2 - 80)
	row.status:SetWordWrap(false)

	local button = CreateFrame("Button", nil, row, "SecureActionButtonTemplate")
	button:SetSize(30, 30)
	button:SetPoint("RIGHT")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button:SetAttribute("type", "item")
	button:SetAttribute("target-slot", s.slot)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", 1, -1)
	button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	button.count = button:CreateFontString(nil, "OVERLAY")
	button.slot = Shy.Slot.New(button, { icon = button.icon })
	button.slot:Count(button.count)
	button:SetScript("OnEnter", function(self)
		local sections
		if self.itemID then
			sections = { { rows = { { icon = self.icon:GetTexture(), text = C_Item.GetItemNameByID(self.itemID) or "",
				right = ("%d in bags"):format(C_Item.GetItemCount(self.itemID)), rightColor = C.dim } } } }
		end
		UI.Tip(self, s.label, nil, { side = "RIGHT", sections = sections, hints = { { "left", "Apply" } } })
	end)
	button:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	row.button = button

	row.missing = UI.Text(row, "", 11, false, C.dim)
	row.missing:SetPoint("RIGHT")
	return row
end

local function Layout()
	if InCombatLockdown() then return end
	local db = T.db.poisons
	local shown = 0
	for i, s in ipairs(SLOTS) do
		local st, row = state[s.key], rows[i]
		row:SetShown(st.weapon)
		if st.weapon then
			shown = shown + 1
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", PAD, -TOP - (shown - 1) * ROW)
			row.weapon:SetTexture(GetInventoryItemTexture("player", s.slot))
			local text, color = Status(st)
			row.status:SetText(text)
			UI.Ink(row.status, color)
			if st.item then
				row.button.itemID = st.item
				row.button:SetAttribute("item", "item:" .. st.item)
				row.button.icon:SetTexture(C_Item.GetItemIconByID(st.item))
				row.button.count:SetText(st.count)
				row.button:Show()
				row.missing:Hide()
			else
				row.button.itemID = nil
				row.button:Hide()
				row.missing:SetText("none in bags")
				row.missing:Show()
			end
		end
	end

	local low = {}
	for _, s in ipairs(SLOTS) do
		local st = state[s.key]
		if st.weapon and st.item and st.count < db.lowStock then
			local name = C_Item.GetItemNameByID(st.item) or "poison"
			low[name] = st.count
		end
	end
	local lowText = {}
	for name, count in pairs(low) do lowText[#lowText + 1] = ("%s: %d left"):format(name, count) end
	lowStock:SetText(#lowText > 0 and ("Running low  \194\183  " .. table.concat(lowText, ", ")) or "")
	lowStock:ClearAllPoints()
	lowStock:SetPoint("TOPLEFT", PAD, -TOP - shown * ROW)

	box:SetHeight(TOP + shown * ROW + (#lowText > 0 and 20 or 4))
end

local function Update()
	if InCombatLockdown() then return end
	Scan()
	Layout()
	Shy.HUD.Update(box)
end

function ns.SetupPoisons()
	box = Shy.HUD.Create({
		id = "shyrogue-poisons",
		title = "Poisons",
		width = WIDTH,
		height = 120,
		point = { "CENTER", "CENTER", 0, 180 },
		shown = Needed,
		secure = true,
	})
	local head = UI.Head(box, { title = "Poisons", panel = { hud = true } })
	local hint = UI.Text(head, "click to reapply", 11, false, C.dim)
	hint:SetPoint("RIGHT", head, "TOPRIGHT", -PAD, -head.mid)
	lowStock = UI.Text(box, "", 11, false, C.alert)

	rows = {}
	for i, s in ipairs(SLOTS) do rows[i] = CreateRow(i, s) end

	local events = CreateFrame("Frame")
	-- Yours alone: a party member changing gear says nothing of your weapons.
	events:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", Update)
	-- No event fires as a poison's time runs down, so poll.
	C_Timer.NewTicker(5, Update)
	table.insert(ns.refreshers, Update)
	Update()
end
