-- Options: a live preview (a real plate showing the player), look settings and a switch per frame.

local ADDON, ns = ...
local T, L, Plate = ns.T, ns.Layout, ns.Plate
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local UNIT_SWITCHES = {
	{ "player", "Player", "Your own frame." },
	{ "target", "Target", "Your target's frame, with your combo points along its top edge." },
	{ "targettarget", "Target's target", "A smaller frame next to your target's." },
	{ "pet", "Pet", "A small frame next to your own." },
	{ "focus", "Focus", "A small frame next to your own, below your pet's." },
	{ "party", "Party", "A row above your frame and your target's. Members fade when out of range, and their edge turns red when they have aggro. Hidden in raids." },
	{ "partypet", "Party pets", "A green bar at the end of a party member's health. Click it to target the pet." },
}

local function At(w, x, y)
	w:SetPoint("TOPLEFT", w:GetParent(), "TOPLEFT", x, y)
	return w
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)
	local plate

	local function ShowPreview()
		if not plate then return end
		plate:Arrange()
		plate:Update()
	end

	local function Build()
		UI.PageHeader(panel, T)

		local strip = CreateFrame("Frame", nil, panel)
		strip:SetSize(COL + 10, 112)
		strip:SetPoint("TOPLEFT", LEFT, -112)
		UI.Skin(strip, UI.colors.bg)
		local preview = CreateFrame("Frame", nil, strip)
		preview:SetPoint("BOTTOM", 0, 10)
		preview:SetSize(L.Size("player"))
		plate = Plate.Create(preview, "player")
		plate:SetUnit("player")

		At(UI.Header(panel, "Look", COL), LEFT, -240)
		-- Taken as the knob is let go: every frame is fitted again by it, and the console round them.
		local asked
		At(group:Slider(panel, "Size", 0.6, 1.4, 0.02, function() return asked or T.db.size end, function(v) asked = v end,
			{ width = COL, format = function(v) return math.floor(v * 100 + 0.5) .. "%" end,
			desc = "Scales every frame. At 94% your frame and your target's together are as wide as the console.",
			settle = function(v)
				asked = nil
				T.db.size = v
			end }),
			LEFT, -268)
		At(group:Checkbox(panel, "Fade out of combat", function() return T.db.fade end, function(v) T.db.fade = v end,
			{ desc = "Out of combat, your frame and your target's fade out unless you have a target, and stay faintly visible while you're hurt or low on mana. You can still click them." }),
			LEFT, -320)
		-- (The damage to come is ShyDots' and the healing to come ShyHots': without one, no switch for it, and
		-- what is under it moves up.)
		local y = -346
		if Shy.addons.Dots then
			At(group:Checkbox(panel, "As good as dead", function() return T.db.doom end, function(v) T.db.doom = v end,
				{ desc = "Marks the DoT damage still to come on your target's health bar, in each spell's school color, with a check before the name once it's enough to kill. Needs ShyDots." }),
				LEFT, y)
			y = y - 26
		end
		if Shy.addons.Hots then
			At(group:Checkbox(panel, "Healing to come", function() return T.db.mend end, function(v) T.db.mend = v end,
				{ desc = "Marks the healing your HoTs still have to give at the end of a friend's health, in each spell's color: gold for holy, green for nature. Needs ShyHots." }),
				LEFT, y)
			y = y - 26
		end
		y = y - 10
		At(Shy.HUD.LayoutButton(panel, COL), LEFT, y)
		local colors = UI.Text(panel, "Health bars use the class color for players, and red, yellow or green for creatures. Missing health is a darker shade of the same color.", 12, false, UI.colors.dim)
		colors:SetWidth(COL)
		At(colors, LEFT, y - 40)

		At(UI.Header(panel, "Frames", COL), RIGHT, -112)
		for i, def in ipairs(UNIT_SWITCHES) do
			local key = def[1]
			At(group:Checkbox(panel, def[2], function() return T.db.units[key] end, function(v) T.db.units[key] = v end,
				{ desc = def[3] }), RIGHT, -140 - (i - 1) * 26)
		end

		At(UI.Header(panel, "Default frames", COL), RIGHT, -336)
		At(group:Checkbox(panel, "Hide default unit frames", function() return T.db.hideBlizzard end,
			function(v) T.db.hideBlizzard = v end,
			{ desc = "Hides the default frame for each frame switched on above. Raid frames and the cast bar are not affected." }),
			RIGHT, -364)
		local note = UI.Text(panel, "Left-click a frame to target it, right-click for its menu. Changes made in combat apply after the fight. Test party fills the empty party seats with samples until you press it again; layout mode shows them too.", 12, false, UI.colors.dim)
		note:SetWidth(COL)
		At(note, RIGHT, -398)

		-- (The marks inside a cell are ShyBuffs': without it the grid is the frames alone, and says no more.)
		local marks = Shy.addons.Buffs and " Your own heals show along the bottom of each frame, and a debuff you can remove lights the whole frame in its color." or ""
		At(UI.Header(panel, "Healing", COL), RIGHT, -476)
		At(group:Dropdown(panel, "Healing grid", {
			{ value = "auto", text = "While you're the healer" },
			{ value = "on", text = "Always" },
			{ value = "off", text = "Never" },
		}, function() return T.db.grid end, function(v) T.db.grid = v end,
			{ width = COL, enabled = function() return T.db.units.party end,
			desc = "Shows your party and you as one tight group of small frames: tanks first, then you, then everyone else." .. marks .. " You count as the healer when your group gives you the role, or while you use the healer layout." }),
			RIGHT, -504)
		-- Two buttons side by side: the click bindings' window, and the test party.
		local half = (COL - 8) / 2
		if ns.Clicks then
			At(UI.Button(panel, "Click casting", half, function() ns.Clicks.Open() end), RIGHT, -560)
		end
		At(UI.Button(panel, "Test party", half, function() T:Test() end), RIGHT + half + 8, -560)
	end

	ns.RefreshOptions = function()
		if not panel.built then return end
		ShowPreview()
		if panel:IsVisible() then group:Refresh() end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		ShowPreview()
	end)

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
	end

	return panel
end
