-- Settings: the auction window, prices on tooltips and scanning.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- The prices on your market, in a few words.
local function Standing()
	if ns.Scan.State() then return "scanning" end
	local count = ns.Book.Count()
	if count == 0 then return "none yet" end
	local at = ns.Book.ScannedAt()
	return ("%s items, %s"):format(BreakUpLargeNumbers(count), at and Shy.UI.Ago(at) or "from searches")
end

local function CanScan() return ns.Scan.CAN end

-- Space, and its hint on the Post button.
local function Keys()
	ns.SellKeys()
	ns.Window.Stale()
end

T:Settings({
	reset = function()
		T:ResetDB()
		ns.Window.Apply()
		Keys()
	end,
	{ key = "window", label = "Auction window", words = "auction house ah buy sell default replace",
		apply = function() ns.Window.Apply() end,
		desc = "One window to buy, sell, watch your auctions and find farms. Off gives you the default one." },
	{ key = "spacePosts", label = "Space posts", sub = true, words = "spacebar key sell stack",
		enabled = function() return T.db.window end, apply = Keys,
		desc = "On the Sell tab, each press of Space posts your next stack." },
	{ note = "The auction window hit an error. You have the default one until you reload.", alert = true,
		shown = function() return ns.Window.failed end },

	{ section = "Prices" },
	{ key = "tooltip", label = "Prices on tooltips", words = "item worth market value stack",
		desc = "An item's tooltip shows its market price and what your stack is worth." },
	{ key = "autoScan", label = "Scan when it opens", shown = CanScan, words = "auto automatic",
		desc = "Opening the auction house reads every price there, as often as the server allows." },
	{ label = "Market prices", button = "Scan now", shown = CanScan, says = Standing, words = "scan refresh update",
		enabled = function() return ns.Scan.IsOpen() and not ns.Scan.State() end,
		run = function()
			local ok, why = ns.Scan.Full()
			if not ok then T:Print(why) end
		end,
		desc = ("Reads every price at the auction house. It has to be open, and the server allows one scan every %d minutes.")
			:format(ns.Scan.K.EVERY / 60) },
})

-- A scan begins or ends, the auction house opens or closes: the scan's row reads again.
Shy:On("SHY_AUCTION", function() Shy.Settings.Refresh() end)
