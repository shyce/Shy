-- The crate on the bags' rail, above the bag slots' switch, while you hold crates: it opens the crates window, and
-- glimmers while one can be filled from your bags (what you bought, taken from the mail). Every answer it gives is the
-- plan's, kept until your bags or a price change.

local ADDON, ns = ...
local T = ns.T

local Rail = {}
ns.Rail = Rail

local function Bags()
	local bags = Shy.addons.Bags
	return bags and bags.RegisterRailButton and bags or nil
end

function Rail.Refresh()
	local bags = Bags()
	if bags then bags:RefreshRail() end
end

local function Tip(button)
	local held, ready = ns.Plan.Held(), ns.Plan.Ready()
	local says
	if ready > 0 then
		says = ready == 1 and "1 crate is ready to fill." or ("%d crates are ready to fill."):format(ready)
	elseif held.unread then
		says = held.unread.count == 1 and "1 crate to open." or ("%d crates to open."):format(held.unread.count)
	else
		says = "Nothing to fill yet."
	end
	Shy.UI.Tip(button, "Waylaid Crates", says, { side = "TOP", hints = { { "left", ns.Window.Shown() and "Close" or "Open" } } })
end

function Rail.Start()
	local bags = Bags()
	if not bags then return end
	bags:RegisterRailButton({
		id = "crates", order = 10, icon = T.mark,
		shown = function()
			local held = ns.Plan.Held()
			return held.labels[1] ~= nil or held.unread ~= nil
		end,
		lit = function() return ns.Window.Shown() end,
		glimmer = function() return ns.Plan.Ready() > 0 end,
		tip = Tip,
		click = function()
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			ns.Window.Toggle(true)
		end,
		-- Opened from your bags, it closes with them.
		hidden = function() ns.Window.Close(true) end,
	})
	Shy:On("SHY_CRATES", Rail.Refresh)
end
