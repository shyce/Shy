-- Options: the switch, what is being followed now, and the learned sizes.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, COL = 24, 300

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)
	local status

	local function Build()
		UI.PageHeader(panel, T)

		local label = UI.Text(panel, "Track your DoTs", 15, true)
		label:SetPoint("TOPLEFT", LEFT, -112)
		local switch = group:Switch(panel, "Track your DoTs", function() return T.db.on end,
			function(v) T.db.on = v end, { desc = "Shows the DoT damage left to tick on nameplates and the target frame." })
		switch:SetPoint("LEFT", label, "RIGHT", 12, 0)

		local header = UI.Header(panel, "How it shows", COL)
		header:SetPoint("TOPLEFT", LEFT, -156)
		local note = UI.Text(panel, "On a mob's health bar, the DoT damage still to come is marked off its health in each spell's school color. Once it covers all the health left, a check mark shows the mob is as good as dead: move on.", 12, false, UI.colors.dim)
		note:SetWidth(COL * 2)
		note:SetPoint("TOPLEFT", LEFT, -186)
		local where = UI.Text(panel, "ShyPlates shows it on nameplates and ShyFrames on the target frame, each with its own switch.", 12, false, UI.colors.dim)
		where:SetWidth(COL * 2)
		where:SetPoint("TOPLEFT", LEFT, -224)

		local learned = UI.Header(panel, "Tick sizes", COL)
		learned:SetPoint("TOPLEFT", LEFT, -270)
		status = UI.Text(panel, "", 12, false, UI.colors.dim)
		status:SetWidth(COL * 2)
		status:SetJustifyH("LEFT")
		status:SetPoint("TOPLEFT", LEFT, -300)
		local forget = UI.Button(panel, "Forget tick sizes", 150, function()
			wipe(T.db.ticks)
			wipe(T.db.spans)
			ns.RefreshOptions()
		end)
		forget:SetPoint("TOPLEFT", LEFT, -346)
		local report = UI.Button(panel, "Copy report", 150, function()
			UI.ShowCopyBox("ShyDots", T:Report())
		end)
		report:SetPoint("LEFT", forget, "RIGHT", 12, 0)
	end

	local function Status()
		local sizes = 0
		for _ in pairs(T.db.ticks) do sizes = sizes + 1 end
		if sizes == 0 then
			status:SetText("Nothing learned yet. Each spell's tick size is learned after a fight you use it in; until then it comes from the spell's own numbers.")
		else
			status:SetFormattedText("Learned for %d spells. Forget them after a big gear or talent change.", sizes)
		end
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			Status()
		end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		Status()
	end)

	function panel:OnDefault()
		local ticks, spans = T.db.ticks, T.db.spans
		T:ResetDB()
		T.db.ticks, T.db.spans = ticks, spans
		T:Apply()
	end

	return panel
end
