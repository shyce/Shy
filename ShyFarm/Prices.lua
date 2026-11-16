-- What a thing is worth. Each item keeps up to three prices in the account's book (T.db.prices[item]): the auction
-- house's lowest when you last looked (ah, at; none: nobody was selling), your own (own), and which of them it goes
-- by (use: "auction" | "vendor" | "own", nil to follow the setting). The vendor's is the game's sell price. Junk and
-- things bound when picked up go by the vendor's alone.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local P = {}
ns.Prices = P

P.FROM = { auction = "auction", vendor = "vendor", own = "yours" }
local STALE = 6 * 3600     -- an auction price older than this is checked again at the auction house

local function Book(item, make)
	local book = T.db.prices
	local entry = book[item]
	if not entry and make then
		entry = {}
		book[item] = entry
	end
	return entry
end

-- The game's facts about an item: quality, sell price, bound when picked up. Until the game has it (it is asked for,
-- and GET_ITEM_INFO_RECEIVED says when it comes), the loot data's where it has them, else nil.
local asked = {}
function P.Facts(item)
	local name, _, quality, _, _, _, _, _, _, _, sell, _, _, bind = C_Item.GetItemInfo(item)
	if not name then
		if not asked[item] then
			asked[item] = true
			C_Item.RequestLoadItemDataByID(item)
		end
		local known = ns.Worth and ns.Worth.Item(item)
		if known then return known.quality, known.sell, known.bound end
		return nil
	end
	return quality, sell or 0, bind == 1
end

function P.Vendor(item)
	local _, sell = P.Facts(item)
	return sell
end

-- The auction house's price and when it was seen: the auction addon's book where it is on (its scans), else what
-- this addon read itself.
local function Market(item)
	local house = Shy.addons.Auction
	if house and house.Price then
		local price = house:Price(item)
		if price then return price.market, price.at end
		return nil
	end
	local entry = Book(item)
	return entry and entry.ah, entry and entry.at
end
P.Auction = Market

function P.Own(item)
	local entry = Book(item)
	return entry and entry.own
end

-- Whether the auction house can tell a price for it at all: not junk, not bound when picked up.
function P.Sellable(item)
	local quality, _, bound = P.Facts(item)
	if quality == nil then return true end
	return quality > 0 and not bound
end

-- What one is worth, and where that comes from: your pick for it, else your own price, else the setting's
-- (an auction price when you have one, else the vendor's). nil while the game hasn't said.
function P.Value(item)
	local entry = Book(item)
	local use = entry and entry.use
	local sellable = P.Sellable(item)
	if use == "own" and entry.own then return entry.own, "own" end
	local ah = sellable and use ~= "vendor" and Market(item)
	if use == "auction" and ah then return ah, "auction" end
	if use ~= "vendor" then
		if entry and entry.own and use == nil then return entry.own, "own" end
		-- (Valued at the auction house: whichever pays more, it or the vendor, since that's where you'd sell it.)
		if T.db.value == "auction" and ah then
			local sell = P.Vendor(item)
			if sell and sell > ah then return sell, "vendor" end
			return ah, "auction"
		end
	end
	local sell = P.Vendor(item)
	if sell then return sell, "vendor" end
	return nil
end

-- Whether it wants you to say how to value it: it could fetch more at the auction house than you have a price
-- for. Not while you value things at the vendor's, nor once you picked how.
function P.Needs(item)
	if T.db.value == "vendor" or not P.Sellable(item) then return false end
	local entry = Book(item)
	return not ((entry and (entry.use or entry.own)) or Market(item))
end

-- Whether the auction house should be asked about it here: it is sold there, and its price is old or missing. Never
-- while the auction addon is on: its scans price everything.
function P.Wanting(item)
	if not T.db.auction or not P.Sellable(item) then return false end
	if Shy.addons.Auction then return false end
	local entry = Book(item)
	if entry and entry.use and entry.use ~= "auction" then return false end
	local at = entry and (entry.at or entry.none)
	return not at or time() - at > STALE
end

function P.SetAuction(item, copper)
	local entry = Book(item, true)
	if copper then
		entry.ah, entry.at, entry.none = copper, time(), nil
	else
		entry.none = time()
	end
	ns.Changed("price")
end

function P.SetOwn(item, copper)
	local entry = Book(item, true)
	entry.own, entry.use = copper, "own"
	ns.Changed("price")
end

-- Goes by the auction's, the vendor's or your own price from now on (nil: the setting's).
function P.Use(item, source)
	local entry = Book(item, true)
	entry.use = source
	ns.Changed("price")
end

function P.Using(item)
	local entry = Book(item)
	return entry and entry.use
end

-- Money, short: from a gold up no copper, from a hundred gold up no silver either.
function P.Text(copper, size, at)
	copper = math.floor((copper or 0) + 0.5)
	if copper >= COPPER_PER_GOLD then copper = copper - copper % COPPER_PER_SILVER end
	return UI.Money(copper, true, size, at)
end

-- A price as typed (UI.ParseMoney).
P.Parse = UI.ParseMoney

-- How old an auction price is, in words (UI.Ago).
P.Age = UI.Ago

-- The game has an item's facts now: whatever showed it unpriced is drawn again.
local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, _, item)
	if asked[item] then
		asked[item] = nil
		ns.Changed("item")
	end
end)
