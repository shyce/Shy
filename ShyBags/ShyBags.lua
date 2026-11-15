-- ShyBags: your bags, bank, mail, auctions and gold across every character, in one window.
-- Parts are optional at run time: check ns.<Part> before calling into a file that loads later.
--
-- For other addons, through Shy.addons.Bags:
--   .owns[piece]    true while ShyBags handles that piece (SHY_BAGS_OWNS when it changes): "window" while
--                   its window stands in for the default bags, "bagbar" while the default bag bar is stood down
--   :BagButtons()   where the bag buttons are: "window" (a column beside the items, the default bar off the
--                   screen) or "screen" (the default bar); :SetBagButtons(where) changes it at once
--   :BagsKey()      the key that opens the bags, as the game writes it, or nil with none bound
--   :Count(itemID)  total on the account, and who has them where
--   :RegisterKeyword({ word, help, test })   a search keyword
--   :Room()         free, total ordinary slots (no key ring, quiver, soul bag or profession bag)
--   :Cheapest(n)    up to n items that can be dropped or sold, cheapest first; each
--                   { bag, slot, id, link, name, count, value = stack price in copper, junk }
--   :MakeRoom(opts) opens the window with the cheapest lit and returns them. opts = { need = slots (1), why = text }.
--                   Ends once `need` slots are free or the window closes; :MakeRoom(false) ends it.
--   :Alts()         your other characters you can mail (this realm and side): { name, full, class, level } each;
--                   name addresses a letter, full is name and surname
--   :Sort(order, reversed)   shows the bags by "type" (what to keep, then what quests need, then what can go;
--                   within each by kind, then name), "worth" (vendor price, cheapest first),
--                   "age" (newest first) or "bags"; reversed: from the last slot back with the empty slots
--                   leading, most expensive or oldest first. A sorted order also opens the window.
--   :Keep(test)     test(itemID, bag, slot) true: never offered by Cheapest
--   :Leftover(test) test(itemID, bag, slot) true: a quest item whose quest is done or abandoned; treated as junk.
--                   :RefreshMarks() re-evaluates after a quest changes.
--   :Needed(test)   test(itemID, bag, slot) "now" or "later": a quest needs it (the game may call it no quest
--                   item: meat, cloth). It wears the quest mark for needed now, or for needed later, in the
--                   bags and in the bank. A second answer, a number, is how soon its quest comes (lower:
--                   sooner): the sort by type lays what quests need in that order.
--   :Holds(test)    test(place) true while your "bank" or your "mail" holds something a quest needs with you:
--                   the quest mark stands on that door in the window's foot.
--   :Mailed()       what this character's mailbox held when last read: item -> how many (not to keep or change)
--   :Banked()       the same of its bank
--   :RegisterBankJob(def)   a job the bank window offers at a banker, in its foot: def = { id, order, pin,
--                   look = function() return words, says end, run = function() end } (BankWindow.lua).
--                   :RefreshBank() has the jobs asked again.
--   :SaleList()     what to sell at a vendor, grouped (junk, outgrown, plain, house), each with why and both prices;
--                   :SaleCheck(id, on, kind) ticks one (unticking keeps it for ten levels, for good at the highest);
--                   :Sell(rows) sells them a few a second; :Selling() how that stands (Sellout.lua)
-- Bus: SHY_BAGS_SCANNED(guid, source), SHY_BAGS_ROOM(free, total) once per burst of bag updates,
-- SHY_BAGS_SOLD(copper), SHY_BAGS_REPAIRED(copper, byGuild), SHY_BAGS_SALE("progress" done of | "done").

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyBags\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Bags",
	icon = MEDIA .. "ShyBags",
	smallIcon = MEDIA .. "ShyBagsSmall",
	tagline = "Your bags, your bank and every character's, in one window",
	savedVariables = "ShyBagsDB",
	defaults = {},   -- each file adds its own (T.defaults.x = ...)
	-- One-time migration flags: account facts that a reset must not clear.
	keep = { adoptedVendor = true, adoptedBagbar = true, adoptedGear = true },
})
ns.T = T
ns.MEDIA = MEDIA

T.owns = {}

function ns.Own(piece, on)
	on = on and true or nil
	if T.owns[piece] == on then return end
	T.owns[piece] = on
	Shy:Fire("SHY_BAGS_OWNS", piece, on == true)
end

-- Helpers

function ns.Now()
	return time()
end

local function Count(n, one)
	return n .. " " .. one .. (n == 1 and "" or "s") .. " ago"
end

function ns.Ago(t)
	local s = math.max(0, ns.Now() - t)
	if s < 90 then return "just now" end
	if s < 3600 then return Count(math.floor(s / 60 + 0.5), "minute") end
	if s < 86400 then return Count(math.floor(s / 3600 + 0.5), "hour") end
	return Count(math.floor(s / 86400 + 0.5), "day")
end

-- Isolates a part's errors from the others.
function ns.Guard(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then geterrorhandler()(err) end
	return ok
end

-- Slash commands

local commands, order = {}, {}

function ns.Command(word, help, fn)
	if not commands[word] then order[#order + 1] = word end
	commands[word] = { help = help, fn = fn }
end

SLASH_SHYBAGS1 = "/shybags"
SLASH_SHYBAGS2 = "/sbags"
SlashCmdList.SHYBAGS = function(input)
	local word, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	word = word:lower()
	if word == "" then
		T:OpenOptions()
	elseif commands[word] then
		commands[word].fn(rest)
	else
		T:Print("commands:")
		print("  /shybags  - open options")
		for _, name in ipairs(order) do
			-- A command with no help line is a diagnostic: it runs, but isn't listed.
			if commands[name].help then print("  /shybags " .. name .. "  - " .. commands[name].help) end
		end
	end
end

-- Lifecycle

local PARTS = { "Scan", "Mail", "Auctions", "Ledger", "Index", "Search", "Marks", "Room", "Order", "Takeover",
	"Window", "Bank", "Vendor", "BagBar", "BankWindow", "AuctionWindow", "Sellout", "Gear", "Tooltip", "Check" }

function T:OnLoad()
	-- Migrates the old per-addon slot shape to Shy.Slot, once.
	local shape = self.db.shape
	self.db.shape = nil
	if shape and shape ~= "now" then Shy.Slot.Set(shape) end
	ns.Store.Open()
	if ns.CreateOptions then self:RegisterOptions(ns.CreateOptions()) end
end

function T:OnLogin()
	ns.Store.Login()
	for _, name in ipairs(PARTS) do
		local part = ns[name]
		if part and part.Init then ns.Guard(part.Init) end
	end
end
