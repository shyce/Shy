-- The stats box: a card with the bar and stat tiles, a Shy.HUD box.
-- Its head is what the bar is of (your level, or the faction you track) and how far along; under the bar a line of
-- what is left and when; then the stats, three to a row, close.

local ADDON, ns = ...
local T, S = ns.T, ns.Stats
local UI = Shy.UI
local C = UI.colors

local WIDTH, PAD = 282, 10
local K = {
	head = -9,              -- the head's words, down from the top
	bar = -31, barH = 10,   -- the bar
	line = -49,             -- the line under it: what is left, and when
	tiles = -63,            -- the first row of stats
	columns = 3, gap = 8,   -- stats to a row, and between them
	tileH = 27, pitch = 32, -- a stat's height, and from one row to the next
	foot = 8,               -- under the last row
}
local GOLD = { 1, 0.78, 0.25 }   -- quest XP ready; matches the default questColor
local BRONZE = { 0.82, 0.46, 0.22 }   -- the whole log's quest XP; matches the default logColor
local HINTS = { { "left", "Move" }, { "right", "Menu" }, { "left", "Shift: share" } }   -- the box's hover
local DOT = "  \194\183  "

ns.cards = {}

-- Colors are palette tables kept by reference, so they follow the theme.
ns.TILES = {
	{ key = "eta", label = "Time to level", color = C.text, value = function()
		local eta = S.TimeToLevel()
		return eta and S.Duration(eta) or "-"
	end },
	{ key = "pace", label = "XP per hour", color = C.text, value = function()
		local pace = S.Pace()
		return pace and S.Short(pace) or "-"
	end },
	{ key = "kills", label = "Kills to level", color = C.text, value = function()
		local kills = S.KillsToLevel()
		return kills and ("~" .. kills) or "-"
	end },
	{ key = "quests", label = "Quests ready", color = GOLD, value = function()
		local q, n = S.QuestXP()
		return n > 0 and ("+" .. S.Short(q) .. " (" .. n .. ")") or "none"
	end },
	{ key = "log", label = "In your log", color = BRONZE, value = function()
		local q, n = S.LogXP()
		return n > 0 and ("+" .. S.Short(q) .. " (" .. n .. ")") or "none"
	end },
	{ key = "rested", label = "Rested", color = C.hot, value = function()
		local rested, fraction = S.Rested()
		return rested > 0 and ("+" .. math.floor(fraction * 100) .. "%") or "none"
	end },
	{ key = "bubbles", label = "Bubbles to go", color = C.text, value = function()
		return ("%.1f"):format(S.Bubbles())
	end },
	{ key = "level", label = "This level", color = C.text, value = function()
		return S.Duration((S.ThisLevel()))
	end },
}

-- The stats while the box shows a reputation (Rep.lua).
ns.REP_TILES = {
	{ key = "eta", label = "Time to next", color = C.text, value = function()
		local eta = ns.Rep.TimeToNext()
		return eta and S.Duration(eta) or "-"
	end },
	{ key = "pace", label = "Per hour", color = C.text, value = function()
		local pace = ns.Rep.Pace()
		return pace and S.Short(pace) or "-"
	end },
	{ key = "count", label = "Kills or quests", color = C.text, value = function()
		local count = ns.Rep.GainsToNext()
		return count and ("~" .. S.Number(count)) or "-"
	end },
	{ key = "session", label = "This session", color = C.good, value = function()
		local got = ns.Rep.Session()
		return got > 0 and ("+" .. S.Short(got)) or "none"
	end },
	{ key = "quests", label = "Quests for it", color = GOLD, value = function()
		local ready, all = ns.Rep.Quests()
		if all == 0 then return "none" end
		return ready > 0 and (ready .. " ready of " .. all) or tostring(all)
	end },
	{ key = "time", label = "This standing", color = C.text, value = function()
		local rec = ns.Rep.Record()
		return rec and S.Duration(rec.time) or "-"
	end },
}

-- The tiles and their switches for what the box shows now.
local function Tiles(card)
	if S.Mode() == "rep" then return card.repTiles, T.db.box.repTiles end
	return card.tiles, T.db.box.tiles
end

-- A text is told its words only when they change: the card is said again at every XP and quest change.
local function Say(fs, text)
	if fs.said == text then return end
	fs.said = text
	fs:SetText(text)
end

local function SetFontSize(fs, size)
	UI.TitleFace(fs, size)
end

-- The line under the bar: what is left and when. "9,991 XP to go · ~1h 12m to 19"; "Honored · 6,600 to Revered · ~2h".
local function Line()
	if S.Mode() == "rep" then
		local into, span, data = ns.Rep.Progress()
		local word, color = ns.Rep.Standing(data.reaction)
		local text = UI.Wrap(color, word)
		local next_ = ns.Rep.Next(data.reaction)
		if next_ then
			text = text .. DOT .. UI.Wrap(C.text, S.Number(span - into)) .. " to " .. next_
			local eta = ns.Rep.TimeToNext()
			if eta then text = text .. DOT .. "~" .. S.Duration(eta) end
		end
		return text
	end
	local cur, max, level = S.Progress()
	local text = UI.Wrap(C.text, S.Number(max - cur)) .. " XP to go"
	local eta = S.TimeToLevel()
	if eta then text = text .. DOT .. "~" .. S.Duration(eta) .. " to " .. (level + 1) end
	return text
end

-- interactive: takes the mouse and shows the stats tooltip.
function ns.CreateCard(parent, onResize, interactive)
	local card = CreateFrame("Frame", nil, parent)
	card:SetWidth(WIDTH)
	UI.Panel(card, { hud = true })   -- hud: uses the shared background opacity

	card.level = UI.Text(card, "", 16, true)
	card.percent = UI.Text(card, "", 16, true, C.hot)
	card.detail = UI.Text(card, "", 12, false, C.dim)
	card.line = UI.Text(card, "", 11, false, C.dim)
	card.line:SetWordWrap(false)

	local bar = ns.CreateXPBar(card)
	card.bar = bar

	local tileW = (WIDTH - PAD * 2 - (K.columns - 1) * K.gap) / K.columns
	local function MakeTiles(defs)
		local list = {}
		for i, def in ipairs(defs) do
			local tile = CreateFrame("Frame", nil, card)
			tile:SetSize(tileW, K.tileH)
			tile.label = UI.Text(tile, def.label:upper(), 9, false, C.dim)
			tile.label:SetPoint("TOPLEFT")
			tile.label:SetWidth(tileW)
			tile.label:SetWordWrap(false)
			tile.value = UI.Text(tile, "", 13, true, def.color)
			tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -2)
			tile.value:SetWidth(tileW)
			tile.value:SetWordWrap(false)
			tile.value:SetJustifyH("LEFT")
			tile.def = def
			tile:Hide()
			list[i] = tile
		end
		return list
	end
	card.tiles = MakeTiles(ns.TILES)
	card.repTiles = MakeTiles(ns.REP_TILES)
	-- A faction's name may be long: it is cut short before the percent, never written over it.
	card.level:SetWordWrap(false)

	function card:Layout()
		local db = T.db.box
		local compact = db.style == "compact"
		local tiles, switches = Tiles(self)
		for _, tile in ipairs(tiles == self.tiles and self.repTiles or self.tiles) do tile:Hide() end
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
			self.line:Hide()
			self.level:SetWidth(0)
			bar:SetPoint("TOPLEFT", PAD, -27)
			bar:SetPoint("TOPRIGHT", -PAD, -27)
			bar:SetHeight(5)
			for _, tile in ipairs(tiles) do tile:Hide() end
			height = 40
		else
			SetFontSize(self.level, 16)
			SetFontSize(self.percent, 16)
			self.level:SetPoint("TOPLEFT", PAD, K.head)
			self.level:SetPoint("RIGHT", self.percent, "LEFT", -8, 0)
			self.level:SetJustifyH("LEFT")
			self.percent:SetPoint("TOPRIGHT", -PAD, K.head)
			self.detail:Hide()
			bar:SetPoint("TOPLEFT", PAD, K.bar)
			bar:SetPoint("TOPRIGHT", -PAD, K.bar)
			bar:SetHeight(K.barH)
			self.line:ClearAllPoints()
			self.line:SetPoint("LEFT", self, "TOPLEFT", PAD, K.line)
			self.line:SetPoint("RIGHT", self, "TOPRIGHT", -PAD, K.line)
			self.line:Show()
			local shown = 0
			for _, tile in ipairs(tiles) do
				local on = switches[tile.def.key]
				tile:SetShown(on)
				if on then
					local col, row = shown % K.columns, math.floor(shown / K.columns)
					tile:ClearAllPoints()
					tile:SetPoint("TOPLEFT", PAD + col * (tileW + K.gap), K.tiles - row * K.pitch)
					shown = shown + 1
				end
			end
			local rows = math.ceil(shown / K.columns)
			height = rows > 0 and (-K.tiles + (rows - 1) * K.pitch + K.tileH + K.foot) or (-K.line + 8 + K.foot)
		end
		self:SetHeight(height)
		if onResize then onResize(WIDTH, height) end
	end

	function card:Refresh()
		-- The mode changed since the tiles were laid out (a faction picked, the top level reached).
		local mode = S.Mode()
		if mode ~= self.mode then
			self.mode = mode
			self:Layout()
		end
		if mode == "rep" then
			local into, span, data = ns.Rep.Progress()
			Say(self.level, data.name)
			Say(self.percent, ("%.1f%%"):format(into / span * 100))
		else
			local cur, max, level = S.Progress()
			Say(self.level, "Level " .. level)
			Say(self.percent, ("%.1f%%"):format(cur / max * 100))
		end
		bar:Update()
		if self.line:IsShown() then Say(self.line, Line()) end

		local tiles, switches = Tiles(self)
		local parts = {}
		for _, tile in ipairs(tiles) do
			local value = tile.def.value()
			Say(tile.value, value)
			if switches[tile.def.key] and #parts < 2 and value ~= "-" and value ~= "none" then
				parts[#parts + 1] = value
			end
		end
		Say(self.detail, table.concat(parts, DOT))
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
	-- (On the quest window while it can't carry them, hidden, the bars stand here.)
	local place = ns.Place()
	return (place == "box" or (place == "quest" and not ns.dockedBy)) and S.Mode() ~= nil and not (db.hideInCombat and (fighting or InCombatLockdown()))
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
	if ns.Rep then
		local track = root:CreateButton("Track")
		track:SetIcon(UI.MenuGlyph("track"))
		local data = ns.Rep.On() and ns.Rep.Watched()
		track:SetSub(data and data.name or "Experience")
		ns.Rep.Menu(track)
		root:CreateDivider()
	end
	root:CreateRadio("Card: bar and stat tiles", function() return db.style == "card" end, function()
		db.style = "card"
		ns.Refresh()
	end)
	root:CreateRadio("Compact: one slim line", function() return db.style == "compact" end, function()
		db.style = "compact"
		ns.Refresh()
	end)
	root:CreateDivider()
	root:CreateButton("Share my progress", ns.Share)
	root:CreateButton("Settings", function() T:OpenOptions() end)
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
		-- The bars are elsewhere: the box is out of layout mode too.
		away = function() return not Shown() end,
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
