-- The options page.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, WIDTH = 24, 560

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local keys

	local function Build()
		UI.PageHeader(panel, T)

		if not ns.isShaman then
			local note = UI.Text(panel, "This is for shamans only. It does nothing on this character.", 14, false, UI.colors.dim)
			note:SetWidth(WIDTH)
			At(note, panel, LEFT, -120)
			return
		end

		keys = At(Shy.Keys.Room(panel, Shy.Keys.WIDE), panel, LEFT, -112)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		if keys then keys:Refresh() end
	end)

	function panel:OnDefault()
		T:ResetDB()
		if keys then keys:Refresh() end
	end

	return panel
end
