-- Settings: the farm window, your session, then what loot is worth.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local VALUE = {
	{ value = "auction", text = "Whichever pays more" },
	{ value = "vendor", text = "Vendor price" },
}

-- Read when it is used: nothing on screen to draw again.
local function Quiet() end

-- With the auction addon on, the auction house is its own to read: the settings for reading it here go.
local function Reads() return Shy.addons.Auction == nil end
local function Reading() return T.db.auction end

-- How the session stands, in a word or two.
local function Stands()
	local S = ns.Session
	local s = S.Current()
	if not s then return "None" end
	if s.state == "paused" then return "Paused" end
	if s.state == "ready" then return "Not started" end
	if S.Running(s) then return "Running" end
	return S.Used(s) and "Resting" or "Waiting for loot"
end

local function CanStart()
	local s = ns.Session.Current()
	return not (s and ns.Session.Running(s))
end

-- (As the window's own Reset: nothing to end while nothing has counted and nothing is picked.)
local function CanEnd()
	local s = ns.Session.Current()
	return s ~= nil and (ns.Session.Used(s) or s.want ~= nil or s.mob ~= nil)
end

local function Made()
	local s = ns.Session.Current()
	local value = s and ns.Session.Used(s) and ns.Session.Value(s) or 0
	return value > 0 and ns.Prices.Text(value, 10) or ""
end

-- The auction prices this addon read itself.
local function Kept()
	local n = 0
	for _, entry in pairs(T.db.prices) do
		if entry.ah or entry.none then n = n + 1 end
	end
	return n
end

T:Settings({
	apply = function() ns.Apply() end,
	{ key = "on", label = "Show while you farm", words = "window session loot gold hour",
		desc = "Your loot and gold an hour sit on screen while a session runs. Off, your sessions still count." },
	Shy.Settings.Layout("Move the farm window, or drag its corner to size it."),

	{ section = "Your session" },
	{ label = "Start a session", button = "Start", says = Stands, enabled = CanStart, run = function() ns.Start() end,
		desc = "Counts what you loot, kill and catch from now on." },
	{ label = "End the session", button = "End", confirm = true, says = Made, enabled = CanEnd,
		run = function() ns.Session.Stop() end,
		desc = "Saves it with your past sessions. A fresh one waits for your next loot." },
	{ key = "fishing", label = "Start when you fish", apply = Quiet, desc = "Casting your line starts a session." },
	{ key = "idle", label = "Stop the clock after", min = 0, max = 15, step = 1, apply = Quiet, words = "idle afk break rest",
		format = function(v) return v == 0 and "Never" or (v .. " min") end,
		desc = "The clock stops after this long with no loot, kill or cast. A break won't lower your gold an hour." },
	{ key = "sound", label = "Sounds", apply = Quiet, words = "chime",
		desc = "A chime when a session starts or pauses by itself, and when you have as many as you wanted." },

	{ section = "What loot is worth" },
	{ key = "value", label = "Count loot at", items = VALUE, words = "auction vendor price",
		apply = function() ns.Changed("price") end,
		desc = "Loot counts at its auction price once you have one, or the vendor's if that pays more. Junk and soulbound loot count at vendor price." },
	{ key = "auction", label = "Read auction prices", shown = Reads, words = "auction house ah",
		apply = function()
			ns.Auction.Rest()
			ns.Apply()
		end,
		desc = "Your searches at the auction house save their lowest price. The farm window offers to look up the ones it's missing." },
	{ key = "autoCheck", label = "Check as it opens", sub = true, shown = Reads, enabled = Reading, apply = Quiet,
		desc = "Opening the auction house looks up every price your session is missing." },
	{ key = "tell", label = "Say prices in chat", sub = true, shown = Reads, enabled = Reading, apply = Quiet,
		desc = "Each price looked up shows in chat, with what it was before." },
	{ label = "Saved auction prices", button = "Forget", confirm = true, shown = Reads,
		says = function()
			local n = Kept()
			return n == 0 and "None" or (n .. " saved")
		end,
		enabled = function() return Kept() > 0 end,
		run = function()
			local book = T.db.prices
			for item, entry in pairs(book) do
				entry.ah, entry.at, entry.none = nil, nil, nil
				if next(entry) == nil then book[item] = nil end
			end
			ns.Changed("price")
		end,
		desc = "Forgets every auction price saved here. Prices you typed yourself stay." },
	{ note = "Right-click a loot row to pick its price or type your own." },
})
