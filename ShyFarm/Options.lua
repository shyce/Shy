-- Options: the piece as a live preview (your session, or a made-up one), starting and ending a session, then what
-- the loot is worth and how the clock counts.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270
local GAP, LOWER = 28, 200   -- between the preview and the section under it; that section's height
local PREVIEW_ROWS = 4

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local VALUE = {
	{ value = "auction", text = "Auction price, else vendor" },
	{ value = "vendor", text = "Vendor price" },
}

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local preview, session
	local function Preview()
		if not preview then return end
		local s = ns.Session.Current()
		local view = s and ns.Card.View(s) or ns.Card.SAMPLE
		-- (As tall as what it shows, as the piece on screen is: three rows at the least, PREVIEW_ROWS at the most.)
		local rows = math.max(ns.Card.K.LEAST, math.min(#view.rows, PREVIEW_ROWS))
		preview:SetSize(ns.Card.K.WIDTH, ns.Card.Height(view, rows))
		preview:Fill(view)
		if session then session:SetLabel(s and "End the session" or "Start a session") end
	end
	local group = UI.Group(function()
		ns.Apply()
		Preview()
	end)

	local function Build()
		UI.PageHeader(panel, T)

		preview = ns.CreateCard(panel)
		preview:SetPoint("TOPLEFT", LEFT, -112)
		Preview()

		local switchLabel = UI.Text(panel, "On screen while you farm", 15, true)
		switchLabel:SetPoint("TOPLEFT", RIGHT, -114)
		local switch = group:Switch(panel, "On screen while you farm", Get("on"), Set("on"),
			{ desc = "What your session made, an hour, and the loot. With the console it stands at the top left, over how to play." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		session = At(UI.Button(panel, "Start a session", COL, function()
			if ns.Session.Current() then ns.Session.Stop() else ns.Session.Begin() end
			Preview()
		end), panel, RIGHT, -150)
		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, -182)
		At(group:Checkbox(panel, "Start when you fish", Get("fishing"), Set("fishing"), {
			desc = "Casting your line starts a session by itself." }), panel, RIGHT, -220)
		At(group:Checkbox(panel, "Sound when you have them all", Get("sound"), Set("sound"), {
			desc = "A chime when you hold as many as you set out to farm." }), panel, RIGHT, -246)
		At(group:Checkbox(panel, "Start when you loot a favorite", Get("loot"), Set("loot"), {
			desc = "Looting a favorite starts farming it and counts that loot, unless you ended farming it." }), panel, RIGHT, -272)

		-- Under the preview, whatever height it stands at (a band, the farmed item and its price come and go): its
		-- section hangs from the preview's foot, so nothing ever lies over it.
		local lower = CreateFrame("Frame", nil, panel)
		lower:SetSize(COL, LOWER)
		lower:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -GAP)
		At(UI.Header(lower, "What loot is worth", COL), lower, 0, 0)
		At(group:Dropdown(lower, "Count loot at", VALUE, Get("value"), Set("value"), { width = COL,
			desc = "An auction price once you've seen one, else what a vendor pays. Junk and items that bind when picked up always count at the vendor's. You can pick another for any item from its row." }), lower, 0, -30)
		At(group:Checkbox(lower, "Read auction house prices", Get("auction"), Set("auction"), {
			desc = "At the auction house, every search you make keeps its lowest price, and the piece offers to look up the ones you lack. Nothing is read anywhere else." }), lower, 0, -84)
		At(group:Checkbox(lower, "Look them up as it opens", Get("autoCheck"), Set("autoCheck"), {
			enabled = function() return T.db.auction end,
			desc = "Opening the auction house looks up the prices your session lacks, without a click." }), lower, 16, -110)
		At(group:Checkbox(lower, "Say prices in chat", Get("tell"), Set("tell"), {
			enabled = function() return T.db.auction end,
			desc = "Each price looked up at the auction house is said in chat, with what it was before." }), lower, 16, -136)
		local forget = At(UI.Button(lower, "Forget auction prices", COL, function() end), lower, 0, -172)
		UI.Twice(forget, function()
			for _, entry in pairs(T.db.prices) do entry.ah, entry.at, entry.none = nil, nil, nil end
			ns.Changed("price")
		end)

		local y = -320
		At(UI.Header(panel, "The clock and the piece", COL), panel, RIGHT, y)
		At(group:Slider(panel, "Stop the clock after", 0, 15, 1, Get("idle"), Set("idle"), { width = COL,
			format = function(v) return v == 0 and "Never" or (v .. " min") end,
			desc = "With nothing looted, killed or cast for this long, the clock stops at the last thing you did, so a break doesn't lower your gold an hour." }), panel, RIGHT, y - 30)
		At(group:Slider(panel, "Loot rows at first", 3, 10, 1, Get("rows"), Set("rows"), { width = COL,
			desc = "How tall it starts. Drag its corner to size it yourself; what doesn't fit adds up in the last row." }), panel, RIGHT, y - 84)
		local note = UI.Text(panel, "Right-click any loot row to pick its price, or type your own.", 12, false, UI.colors.dim)
		note:SetWidth(COL)
		note:SetWordWrap(true)
		At(note, panel, RIGHT, y - 140)
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			Preview()
		end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		Preview()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ns.Apply()
		Preview()
	end

	return panel
end
