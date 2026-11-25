-- The Crates page of the auction house's window: every crate you hold and what it still needs, and the shopping list in
-- the scan bar's place. What you buy comes by mail, so nothing is filled here. Its tab counts the crates ready to fill.

local ADDON, ns = ...

local Page = {}
ns.Page = Page

local auction = Shy.addons.Auction
if not (auction and auction.AddPage) then return end

local list, foot
local INSET = { left = 10, right = 12, top = 4, bottom = 6 }   -- as the other pages stand in the window

auction:AddPage({
	key = "crates", label = "Crates", order = 5,
	Build = function(frame)
		local inner = CreateFrame("Frame", nil, frame)
		inner:SetPoint("TOPLEFT", INSET.left, -INSET.top)
		inner:SetPoint("BOTTOMRIGHT", -INSET.right, INSET.bottom)
		list = ns.List.New(inner)
	end,
	Draw = function(_, width, height)
		list:Draw(width - INSET.left - INSET.right, height - INSET.top - INSET.bottom)
	end,
	Count = function()
		return ns.Plan.Ready(), false
	end,
	Foot = {
		Build = function(band, L) foot = ns.Wares.New(band, L, "buy") end,
		Draw = function(_, width) foot:Draw(width) end,
	},
})

Shy:On("SHY_CRATES", function() auction:Redraw() end)
Page.List = function() return list end
Page.Foot = function() return foot end
