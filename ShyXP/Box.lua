-- The stats box: a card with the XP bar and stat tiles, a Shy.HUD box. The same card is the options preview.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local WIDTH, PAD = 264, 10
local GOLD = { 1, 0.78, 0.25 }   -- quest XP ready; matches the default questColor
local BRONZE = { 0.82, 0.46, 0.22 }   -- the whole log's quest XP; matches the default logColor
local HINTS = { { "left", "Move" }, { "right", "Menu" }, { "left", "Shift: share" } }   -- the box's hover

ns.cards = {}

-- Colors are palette tables kept by reference, so they follow the theme.
ns.TILES = {
	{ key = "eta", label = "Time to level", color = C.text, value = function()
		local eta = S.TimeToLevel()
		return eta and S.Duration(eta) or "-"
	end },
	{ key = "bubbles", label = "Bubbles to go", color = C.text, value = function()
		return ("%.1f"):format(S.Bubbles())
	end },
	{ key = "pace", label = "XP per hour", color = C.text, value = function()
		local pace = S.Pace()
		return pace and (S.Short(pace) .. " / h") or "-"
	end },
	{ key = "quests", label = "Quest XP ready", color = GOLD, value = function()
		local q, n = S.QuestXP()
		return n > 0 and ("+" .. S.Short(q) .. "  (" .. n .. ")") or "none"
	end },
	{ key = "log", label = "Quest XP in log", color = BRONZE, value = function()
		local q, n = S.LogXP()
		return n > 0 and ("+" .. S.Short(q) .. "  (" .. n .. ")") or "none"
	end },
	{ key = "kills", label = "Kills to level", color = C.text, value = function()
		local kills = S.KillsToLevel()
		return kills and ("~" .. kills) or "-"
	end },
	{ key = "rested", label = "Rested", color = C.hot, value = function()
		local rested, fraction = S.Rested()
		return rested > 0 and ("+" .. math.floor(fraction * 100) .. "%") or "none"
	end },
	{ key = "level", label = "This level", color = C.dim, value = function()
		return S.Duration((S.ThisLevel()))
	end },
}

-- A text is told its words only when they change: the card is said again at every XP and quest change.
local function Say(fs, text)
	if fs.said == text then return end
	fs.said = text
	fs:SetText(text)
end

local function SetFontSize(fs, size)
	UI.TitleFace(fs, size)
end

-- interactive: takes the mouse and shows the stats tooltip.
function ns.CreateCard(parent, onResize, interactive)
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(WIDTH)
	UI.Panel(card, { hud = true })   -- hud: uses the shared background opacity

	card.level = UI.Text(card, "", 18, true)
	card.percent = UI.Text(card, "", 18, true, C.hot)
	card.detail = UI.Text(card, "", 12, false, C.dim)

	local bar = ns.CreateXPBar(card)
	card.bar = bar

	card.tiles = {}
	for i, def in ipairs(ns.TILES) do
		local tile = CreateFrame("Frame", nil, card)
		tile:SetSize((WIDTH - PAD * 2 - 10) / 2, 34)
		tile.label = UI.Text(tile, def.label:upper(), 10, false, C.dim)
		tile.label:SetPoint("TOPLEFT")
		tile.value = UI.Text(tile, "", 16, true, def.color)
		tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -2)
		tile.def = def
		card.tiles[i] = tile
	end

	function card:Layout()
		local db = T.db.box
		local compact = db.style == "compact"
		self.level:ClearAllPoints()
		self.percent:ClearAllPoints()
		bar:ClearAllPoints()
		local height
		if compact then
			SetFontSize(self.level, 14)
			SetFontSize(self.percent, 14)
			self.level:SetPoint("TOPLEFT", PAD, -8)
			self.percent:SetPoint("LEFT", self.level, "RIGHT", 6, 0)
			self.detail:ClearAllPoints()
			self.detail:SetPoint("RIGHT", self, "TOPRIGHT", -PAD, -15)
			self.detail:Show()
			bar:SetPoint("TOPLEFT", PAD, -27)
			bar:SetPoint("TOPRIGHT", -PAD, -27)
			bar:SetHeight(5)
			for _, tile in ipairs(self.tiles) do tile:Hide() end
			height = 40
		else
			SetFontSize(self.level, 18)
			SetFontSize(self.percent, 18)
			self.level:SetPoint("TOPLEFT", PAD, -10)
			self.percent:SetPoint("TOPRIGHT", -PAD, -10)
			self.detail:Hide()
			bar:SetPoint("TOPLEFT", PAD, -36)
			bar:SetPoint("TOPRIGHT", -PAD, -36)
			bar:SetHeight(10)
			local shown = 0
			for _, tile in ipairs(self.tiles) do
				local on = db.tiles[tile.def.key]
				tile:SetShown(on)
				if on then
					local col, row = shown % 2, math.floor(shown / 2)
					tile:ClearAllPoints()
					tile:SetPoint("TOPLEFT", PAD + col * (tile:GetWidth() + 10), -56 - row * 40)
					shown = shown + 1
				end
			end
			height = 56 + math.ceil(shown / 2) * 40 + (shown > 0 and 0 or -6)
		end
		self:SetHeight(height)
		if onResize then onResize(WIDTH, height) end
	end

	function card:Refresh()
		local cur, max, level = S.Progress()
		Say(self.level, "Level " .. level)
		Say(self.percent, ("%.1f%%"):format(cur / max * 100))
		bar:Update()

		local parts = {}
		for _, tile in ipairs(self.tiles) do
			local value = tile.def.value()
			Say(tile.value, value)
			if T.db.box.tiles[tile.def.key] and #parts < 2 and value ~= "-" and value ~= "none" then
				parts[#parts + 1] = value
			end
		end
		Say(self.detail, table.concat(parts, "  \194\183  "))
	end

	if interactive then
		card:EnableMouse(true)
		card:SetScript("OnEnter", function(self) ns.ShowSummaryTooltip(self, HINTS) end)
		card:SetScript("OnLeave", function(self) UI.TipHide(self) end)
	end

	ns.cards[card] = true
	card:Layout()
	card:Refresh()
	return card
end

local box
local fighting = false   -- from the fight's start, which the game tells just before the lockdown begins

local function Shown()
	local db = T.db.box
	-- dockedBy: another addon shows the level itself (API.lua).
	return db.shown and S.Active() and not ns.dockedBy and not (db.hideInCombat and (fighting or InCombatLockdown()))
end

local switched   -- the switch as the bus last heard it

function ns.UpdateBox()
	if box then Shy.HUD.Update(box) end
	local on = T:IsOn()
	if on ~= switched then
		switched = on
		Shy:Fire("SHY_XP_SWITCH")
	end
end

local function BoxMenu(root)
	local db = T.db.box
	root:CreateRadio("Card: bar and stat tiles", function() return db.style == "card" end, function()
		db.style = "card"
		ns.Refresh()
	end)
	root:CreateRadio("Compact: one slim line", function() return db.style == "compact" end, function()
		db.style = "compact"
		ns.Refresh()
	end)
	local stats = root:CreateButton("Stats shown")
	for _, def in ipairs(ns.TILES) do
		stats:CreateCheckbox(def.label, function() return db.tiles[def.key] end, function()
			db.tiles[def.key] = not db.tiles[def.key]
			ns.Refresh()
		end)
	end
	root:CreateCheckbox("Hide in combat", function() return db.hideInCombat end, function()
		db.hideInCombat = not db.hideInCombat
		ns.Refresh()
	end)
	root:CreateDivider()
	root:CreateButton("Share my progress", ns.Share)
	root:CreateButton("Options", function() T:OpenOptions() end)
	root:CreateButton("Hide this box", function()
		db.shown = false
		ns.Refresh()
		T:Print("stats box hidden. Turn it back on in the options: /shyxp")
	end)
end

function ns.SetupBox()
	box = Shy.HUD.Create({
		id = "shyxp",
		title = "XP stats",
		width = WIDTH,
		height = 150,
		point = { "TOP", "TOP", 0, -150 },
		shown = Shown,
		-- Last in the column down from the top's middle, under the zone's name.
		top = { order = 50 },
		-- Another piece (ShyQuest's guide) shows the level: the box is out of layout mode too.
		away = function() return ns.dockedBy ~= nil end,
	})
	local card = ns.CreateCard(box, function(w, h) box:SetSize(w, h) end, true)
	card:SetPoint("TOPLEFT")
	-- A mouse-up that ends a drag is not a click.
	card:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and IsShiftKeyDown() and not Shy.HUD.WasDragged(box) then ns.Share() end
	end)
	Shy.HUD.Manage(box, card, BoxMenu)

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	-- Only "Hide in combat" goes by the fight.
	events:SetScript("OnEvent", function(_, event)
		fighting = event == "PLAYER_REGEN_DISABLED"
		if T.db.box.hideInCombat then ns.UpdateBox() end
	end)
end
