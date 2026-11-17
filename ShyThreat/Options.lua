-- Options: the meter as a live preview (a made-up fight), when it shows and what it shows beside it, then warnings.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270
local PREVIEW_ROWS = 4

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function On() return T.db.on == true end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local preview
	local function Preview()
		if not preview then return end
		local rows, name = ns.Read.Sample()
		-- Four rows, whatever the setting: the page keeps its shape, and the rest of the sample scrolls.
		ns.Meter.Measure()
		preview:Flow(preview:GetWidth(), ns.Meter.Height(PREVIEW_ROWS))
		preview:Fill(rows, name, nil, false)
		preview:Trouble(T.db.warn and 0.3 or nil)
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

		local switchLabel = UI.Text(panel, "Threat meter on screen", 15, true)
		switchLabel:SetPoint("TOPLEFT", RIGHT, -114)
		local switch = group:Switch(panel, "Threat meter on screen", On, Set("on"),
			{ desc = "Who has aggro on the mob you're fighting and who is about to pull it. With the console it stands on the damage meter, or by your target in a layout by role." })
		switch:SetPoint("LEFT", switchLabel, "RIGHT", 12, 0)

		At(group:Dropdown(panel, "Show it", ns.WHEN, Get("when"), Set("when"), { width = COL, enabled = On,
			desc = "In combat shows it while you fight with a group or a pet: alone there's nobody to compare with. Always keeps it up between fights with the last fight's table. Layout mode always shows it, so you can move and size it." }), panel, RIGHT, -150)

		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, -204)
		At(UI.Button(panel, "Show a made-up fight", COL, function() ns.Meter.Try() end), panel, RIGHT, -236)

		local y = -300
		At(UI.Header(panel, "What it shows", COL), panel, LEFT, y)
		At(group:Slider(panel, "Rows at first", 3, 10, 1, Get("rows"), Set("rows"), { width = COL, enabled = On,
			desc = "How tall it starts. Drag its corner in layout mode to size it yourself; scroll for the rest. Your own row always shows." }), panel, LEFT, y - 30)
		At(group:Checkbox(panel, "Pets", Get("pets"), Set("pets"), { enabled = On,
			desc = "Pets get a row of their own, in their owner's color, darker." }), panel, LEFT, y - 84)
		At(group:Checkbox(panel, "Follow the nameplate under the mouse", Get("hover"), Set("hover"), { enabled = On,
			desc = "In a fight, hover an enemy's nameplate to see its threat; the meter goes back to your target after." }), panel, LEFT, y - 110)
		At(group:Slider(panel, "Stays after a fight", 0, 20, 1, Get("linger"), Set("linger"), { width = COL,
			enabled = function() return On() and T.db.when ~= "always" end,
			format = function(v) return v == 0 and "No" or (v .. " s") end,
			desc = "When a fight ends with your target still alive, its table stays faded this long. It goes at once when the mob dies or you drop your target." }), panel, LEFT, y - 140)

		At(UI.Header(panel, "You", COL), panel, RIGHT, y)
		At(group:Dropdown(panel, "Read me as", {
			{ value = "auto", text = "My role" },
			{ value = "tank", text = "Tank" },
			{ value = "dps",  text = "Damage or healing" },
		}, Shy.ThreatRolePick, Shy.SetThreatRole, { width = COL, enabled = On,
			desc = "A tank's trouble is the next player catching up; anyone else's is getting close to the pull. Your nameplates read you the same way." }), panel, RIGHT, y - 30)
		At(group:Checkbox(panel, "Warn me near the pull", Get("warn"), Set("warn"), { enabled = On,
			desc = "The meter's header lights gold, then red: as you near the pull, or, tanking, as the next player catches up." }), panel, RIGHT, y - 84)
		At(group:Checkbox(panel, "Aggro sound", Shy.ThreatSound, Shy.SetThreatSound, {
			desc = "A short alarm when a mob you tank goes to someone who isn't a tank, or when you pull one yourself." }), panel, RIGHT, y - 110)
		if Shy.addons.Plates then
			local note = UI.Text(panel, "Your nameplates turn the same colors on the same mob.", 12, false, UI.colors.dim)
			note:SetWidth(COL)
			note:SetWordWrap(true)
			At(note, panel, RIGHT, y - 146)
		end
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then group:Refresh() end
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
