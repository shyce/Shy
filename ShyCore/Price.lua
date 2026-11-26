-- Shy.Price: what a thing fetches, one way for the whole family. A vendor's price is the game's. The auction
-- house's is the auction addon's book where it is on (its scans). Without it, it's a book another addon keeps.
--   Shy.Price.Vendor(item)          copper a vendor pays for one: 0 when no vendor buys it, nil while the game
--                                   hasn't loaded the item
--   Shy.Price.Auction(item)         what one goes for at the auction house, and when that was seen; nil without one
--   Shy.Price.Cut()                 the share of a sale the auction house keeps (a faction's 5% without the auction addon)
--   Shy.Price.Fetch(item, count)    what `count` of it fetch at the auction house, less its cut; nil without a price
--   Shy.Price.Better(vendor, house) "auction" when the auction house pays a tenth more than a vendor, else "vendor"
--                                   (both whole sums in copper; house nil: "vendor")
--   Shy.Price.Book(read)            another addon's book: read(item) -> copper, at. Asked only without the auction addon.

local P = {}
Shy.Price = P

local CUT = 0.05      -- a faction's auction house
local BETTER = 1.1    -- the auction house must pay this much more than a vendor to be worth the trip

local books = {}

function P.Vendor(item)
	local name, _, _, _, _, _, _, _, _, _, sell = C_Item.GetItemInfo(item)
	if not name then return nil end
	return sell or 0
end

function P.Auction(item)
	local house = Shy.addons.Auction
	if house and house.Price then
		local price = house:Price(item)
		if price and price.market then return price.market, price.at end
		return nil
	end
	for _, read in ipairs(books) do
		local copper, at = read(item)
		if copper then return copper, at end
	end
	return nil
end

function P.Cut()
	local house = Shy.addons.Auction
	return house and house.Cut and house:Cut() or CUT
end

function P.Fetch(item, count)
	local each = P.Auction(item)
	if not each then return nil end
	return math.floor(each * (count or 1) * (1 - P.Cut()) + 0.5)
end

function P.Better(vendor, house)
	if house and house > (vendor or 0) * BETTER then return "auction" end
	return "vendor"
end

function P.Book(read)
	books[#books + 1] = read
end
