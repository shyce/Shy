-- A crate's section on its tooltip (Shy.Tips): the bundles that fill it, the one to use first leading, each with its
-- picture and what it costs (a vendor's price or the auction house's, the cheaper); what you hold enough of is lit.
-- Last, where to fill it. Kept until your bags, a price or where you stand change (the plan's stamp).

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local Tooltip = {}
ns.Tooltip = Tooltip

local HERE, AWAY = "What it needs is on the Crates tab", "Fill it with /shy crates"

-- Where to fill it: at the auction house its window's tab, else the command.
local function Where()
	local auction = Shy.addons.Auction
	return auction and auction.IsOpen and auction:IsOpen() and HERE or AWAY
end

local function Name(item)
	local name = C_Item.GetItemNameByID(item)
	if not name then C_Item.RequestLoadItemDataByID(item) end
	return name
end

function Tooltip.Build(about, out)
	local id = about.id
	if type(id) ~= "number" then return end
	local kind = ns.Plan.Is(id)
	if not kind then return end
	local C = UI.colors
	if kind == "label" then
		-- (Every bundle's name first: one still on its way, and the section waits for it.)
		local bundles = ns.Plan.Of(id)
		for _, b in ipairs(bundles) do
			if not Name(b.item) then return end
		end
		out:Section("Fill with any one")
		for _, b in ipairs(bundles) do
			local name = Name(b.item)
			out:Row({
				icon = C_Item.GetItemIconByID(b.item),
				text = (b.have > 0 and not b.ready) and ("%d of %d %s"):format(b.have, b.need, name) or ("%d %s"):format(b.need, name),
				color = b.ready and C.good or C.text,
				right = b.cost and UI.Money(math.floor(b.cost + 0.5), true) or "No price",
				rightColor = b.cost and C.text or C.dim,
			})
		end
	end
	out:Text(kind == "unread" and "Open it with /shy crates" or Where(), C.dim)
end

function Tooltip.Start()
	Shy.Tips.Add({ id = "crate bundles", order = 40, on = function() return T.db.tooltip == true end,
		stamp = function() return ns.Plan.Stamp() end, build = Tooltip.Build })
end
