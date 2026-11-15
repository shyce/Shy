-- Options page: a live preview (a sample death in the real line and ledger), then the settings.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 350, 270

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end
local function On() return T.db.on end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Apply() end)
	local line, ledger

	-- A fresh sample each time the page opens, so its age and unseen state reset.
	local function Renew()
		local sample = ns.Death.Sample()
		ledger:Set(sample)
		line:Set(sample)
	end

	local function Build()
		UI.PageHeader(panel, T)

		line = ns.CreateLine(panel)
		line:SetPoint("TOP", panel, "TOPLEFT", 335, -116)
		line:EnableMouse(true)
		line:SetScript("OnMouseUp", function(self)
			self.view.death.seen = true
			self:Light()
		end)
		ledger = ns.CreateLedger(panel)
		ledger:SetPoint("TOP", line, "BOTTOM", 0, -5)
		ledger.close:Hide()
		Renew()
		local y = -116 - ledger:GetHeight() - 5 - ns.LINE.h - 22

		local label = UI.Text(panel, "Show death recap", 15, true)
		label:SetPoint("TOPLEFT", LEFT, y)
		local switch = group:Switch(panel, "Show death recap", Get("on"), Set("on"),
			{ desc = "When you die, a line shows who killed you and how long ago. Click it for every blow. It stays through release, the corpse run and a reload." })
		switch:SetPoint("LEFT", label, "RIGHT", 12, 0)

		local header = UI.Header(panel, "Recap line", COL)
		header:SetPoint("TOPLEFT", LEFT, y - 40)
		local stay = group:Dropdown(panel, "Stays on screen", {
			{ value = "closed", text = "Until I close it" },
			{ value = "alive",  text = "Until I'm alive again" },
		}, Get("stay"), Set("stay"), { width = COL, enabled = On,
			desc = "Keep the line until you close it, or hide it once you are alive again." })
		stay:SetPoint("TOPLEFT", LEFT, y - 70)
		local creatures = group:Checkbox(panel, "Show PvE deaths", Get("creatures"), Set("creatures"),
			{ enabled = On, desc = "Off: only deaths to players show the line. Deaths to creatures, falling and drowning are still recorded, and /shyrecap shows the last one." })
		creatures:SetPoint("TOPLEFT", LEFT, y - 126)

		local use = UI.Header(panel, "Controls", COL)
		use:SetPoint("TOPLEFT", RIGHT, y - 40)
		local how = UI.Text(panel, "Click the line to see every blow, click it again to close them. Shift-click to share the death in chat, right-click for more. Drag to move it.\n\n/shyrecap shows your last death again.", 12, false, UI.colors.dim)
		how:SetWidth(COL)
		how:SetPoint("TOPLEFT", RIGHT, y - 70)
		local arrange = Shy.HUD.LayoutButton(panel, COL)
		arrange:SetPoint("TOPLEFT", RIGHT, y - 178)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		else
			Renew()
		end
		group:Refresh()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ns.Apply()
	end

	ns.RefreshOptions = function()
		if panel.built then group:Refresh() end
	end
	return panel
end
