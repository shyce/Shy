-- Options: the switch, how it shows, and the learned sizes.

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

		local label = UI.Text(panel, "Track your HoTs", 15, true)
		label:SetPoint("TOPLEFT", LEFT, -112)
		local switch = group:Switch(panel, "Track your HoTs", function() return T.db.on end,
			function(v) T.db.on = v end, { desc = "Shows the healing your HoTs still have to tick on the unit frames." })
		switch:SetPoint("LEFT", label, "RIGHT", 12, 0)

		local header = UI.Header(panel, "How it shows", COL)
		header:SetPoint("TOPLEFT", LEFT, -156)
		local note = UI.Text(panel, "Past the end of someone's health, the healing your HoTs still have to give is marked in each spell's color: gold for holy, green for nature. When there's no room left for it, it folds back over the end of the bar: that much would be wasted.", 12, false, UI.colors.dim)
		note:SetWidth(COL * 2)
		note:SetPoint("TOPLEFT", LEFT, -186)
		local where = UI.Text(panel, "ShyFrames shows it on you, your party and your target, with its own switch.", 12, false, UI.colors.dim)
		where:SetWidth(COL * 2)
		where:SetPoint("TOPLEFT", LEFT, -236)

		local learned = UI.Header(panel, "Tick sizes", COL)
		learned:SetPoint("TOPLEFT", LEFT, -270)
		status = UI.Text(panel, "", 12, false, UI.colors.dim)
		status:SetWidth(COL * 2)
		status:SetJustifyH("LEFT")
		status:SetPoint("TOPLEFT", LEFT, -300)
		local forget = UI.Button(panel, "Forget tick sizes", 150, function()
			T:Forget()
			ns.RefreshOptions()
		end)
		forget:SetPoint("TOPLEFT", LEFT, -346)
		local report = UI.Button(panel, "Copy report", 150, function()
			UI.ShowCopyBox("ShyHots", T:Report())
		end)
		report:SetPoint("LEFT", forget, "RIGHT", 12, 0)
	end

	local function Status()
		local sizes = 0
		for _ in pairs(T.db.shares) do sizes = sizes + 1 end
		if sizes == 0 then
			status:SetText("Nothing learned yet. A tick's size comes from the spell's own numbers and your healing power; what your talents add is learned from a tick out of a fight, on someone still hurt.")
		else
			status:SetFormattedText("Learned for %d spells. Forget them after a talent change.", sizes)
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
		local shares, family, spans = T.db.shares, T.db.family, T.db.spans
		T:ResetDB()
		T.db.shares, T.db.family, T.db.spans = shares, family, spans
		T:Apply()
	end

	return panel
end
