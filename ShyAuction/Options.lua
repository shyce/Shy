-- Options: scanning, and how the prices on your market stand.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

-- How the prices on your market stand, in a line.
local function Standing()
	local at = ns.Book.ScannedAt()
	local count = ns.Book.Count()
	if count == 0 then return "No prices on your market yet. Open the auction house to scan it." end
	return ("Prices for %d items on your market, scanned %s."):format(count, at and UI.Ago(at) or "by searches only")
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() end)
	local line, scan

	local function Refresh()
		if not line then return end
		line:SetText(Standing())
		local wait = ns.Scan.Wait()
		local usable, why = ns.Scan.IsOpen() and wait == 0 and not ns.Scan.State(), nil
		if not ns.Scan.CAN then usable, why = false, "This game has no whole-house scan."
		elseif not ns.Scan.IsOpen() then why = "Open the auction house first."
		elseif wait > 0 then why = ("The server allows the next scan in %d min."):format(math.ceil(wait / 60)) end
		scan:SetUsable(usable, why)
	end

	local function Build()
		UI.PageHeader(panel, T)
		local head = UI.Header(panel, "Scanning")
		head:SetPoint("TOPLEFT", LEFT, -112)
		local auto = group:Checkbox(panel, "Scan as it opens", Get("autoScan"), Set("autoScan"),
			{ desc = "Scans the whole auction house when you open it, as often as the server allows." })
		auto:SetPoint("TOPLEFT", LEFT, -148)
		local window = group:Checkbox(panel, "Our auction window", Get("window"), function(v)
			T.db.window = v
			ns.Window.Apply()
		end, { desc = "Buy, Sell, Auctions and Farm in one window, with the scan along its foot, in place of the game's." })
		window:SetPoint("TOPLEFT", LEFT, -176)
		local tip = group:Checkbox(panel, "Prices on items", Get("tooltip"), Set("tooltip"),
			{ desc = "An item's market price, how old it is, and a stack's worth on its tooltip." })
		tip:SetPoint("TOPLEFT", RIGHT, -148)
		scan = UI.Button(panel, "Scan now", COL, function()
			local ok, why = ns.Scan.Full()
			if not ok then T:Print(why) end
			Refresh()
		end)
		scan:SetPoint("TOPLEFT", RIGHT, -146)
		line = UI.Text(panel, "", 12)
		line:SetPoint("TOPLEFT", LEFT, -214)
		line:SetWidth(RIGHT + COL - LEFT)
		Refresh()
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then Build(); self.built = true end
		group:Refresh()
		Refresh()
	end)
	Shy:On("SHY_AUCTION", function() if panel.built and panel:IsShown() then Refresh() end end)
	function panel:OnDefault() T:ResetDB() end
	ns.RefreshOptions = function() if panel.built then group:Refresh(); Refresh() end end
	return panel
end
