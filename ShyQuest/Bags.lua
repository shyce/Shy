-- Bag space for quests.
--   Vendor errand: with bags nearly full (LOW_SHARE of the slots or LOW_LEAST free), the nearest
--     vendor is a stop before the guide's step when close by or on the way (R.Passing), else a
--     later row while within LISTED yards. With ShyBags the row makes room either way: a click
--     opens the bags with the cheapest things lit, each to drop, until there is room again, and it
--     says so; with no shop in reach (or nothing a shop would buy) it stands with no place to go
--     to, for that click alone. Nobody is sent across the land to make room. Not when ShyBags
--     finds nothing that could go.
--   Shops: who really buys and sells is noted from the game's own windows and kept for the
--     account. Nobody who showed no shop is a stop again.
--   No room: when a quest's item or reward won't fit, or the game refuses a quest for bag space,
--     one chat line names the cheapest item and ShyBags highlights what could go (MakeRoom).
--   Card note: the leading step warns when it accepts or turns in a quest with no slot free.
-- ShyBags is optional: it supplies item values, and is told which items quests still need (Keep)
-- and which are left from finished quests (Leftover). Free slots count ordinary bags only.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R = ns.Data, ns.World, ns.Log, ns.Route
local UI = Shy.UI

local Bags = {}
ns.Bags = Bags

T.defaults.bags = {
	sell = true,             -- a vendor as a stop on the card when the bags are nearly full
	room = true,             -- name what could go when a quest needs a slot
}

local BACKPACK, LAST_BAG = 0, 4    -- Enum.BagIndex.Backpack to Bag_4
local LOW_SHARE, LOW_LEAST = 0.1, 2
local LISTED = 800           -- yards: with bags nearly full, a vendor this near gets a row on the card
local LISTED_FULL = 2500     -- the same with no slot free
local FULL_REACH = 300       -- yards: with no slot free, a vendor this near counts as on the way
local TOLD_EVERY = 8         -- seconds between chat lines about bag space

local free, total, stale = 0, 0, true
local put = false            -- "Not now": no vendor stop until there is room again
local shop                   -- the shop the row led to when last weighed out of a fight (false: none): a fight keeps it
local told = -TOLD_EVERY

local function Shy_Bags()
	local bags = Shy.addons.Bags
	return bags and bags.Room and bags.Cheapest and bags.MakeRoom and bags.Sort and bags or nil
end

local function Count()
	stale = false
	local shy = Shy_Bags()
	if shy then
		free, total = shy:Room()
		free, total = free or 0, total or 0
		return
	end
	free, total = 0, 0
	for bag = BACKPACK, LAST_BAG do
		local open, family = C_Container.GetContainerNumFreeSlots(bag)
		if family == 0 then
			free = free + (open or 0)
			total = total + C_Container.GetContainerNumSlots(bag)
		end
	end
end

-- Free and total slots in ordinary bags.
function Bags.Free()
	if stale then Count() end
	return free, total
end

-- The free-slot count at or below which bags are "nearly full".
local function Low(slots)
	return math.max(LOW_LEAST, math.floor(slots * LOW_SHARE))
end

-- The cheapest droppable item per ShyBags: { name, link, value, ... } or nil.
local function Cheapest()
	local shy = Shy_Bags()
	return shy and shy:Cheapest(1)[1] or nil
end

local function Sellable()
	local shy = Shy_Bags()
	for _, thing in ipairs(shy and shy:Cheapest() or {}) do
		if (thing.value or 0) > 0 then return true end
	end
	return false
end

local function Coins(copper)
	return UI.Money(copper, false, 11)
end

-- The vendor errand

-- Every friendly vendor position: { npc, map, x, y, continent, north, west }.
local vendors, vendorsFor, vendorsAt
local function Vendors()
	local side = L.Side()
	if vendorsFor ~= side or vendorsAt ~= D.shopsVersion then
		vendors, vendorsFor, vendorsAt = {}, side, D.shopsVersion
		local seen = {}
		for _, kind in ipairs({ "vendor", "repair" }) do
			for _, id in ipairs(D.Town(kind)) do
				local npc = not seen[id] and D.Npc(id)
				seen[id] = true
				for _, place in ipairs(npc and L.Friendly(npc) and npc.places or {}) do
					for i = 1, place.dungeon and 0 or #place.points, 2 do
						local continent, north, west = W.ToWorld(place.map, place.points[i], place.points[i + 1])
						if north then
							vendors[#vendors + 1] = { npc = npc, map = place.map, x = place.points[i], y = place.points[i + 1],
								continent = continent, north = north, west = west }
						end
					end
				end
			end
		end
	end
	return vendors
end

local function Nearest()
	if not W.Known() then return nil end
	local best, least
	for _, at in ipairs(Vendors()) do
		if at.continent == W.continent then
			local yards = W.Between(W.north, W.west, at.north, at.west)
			if not least or yards < least then best, least = at, yards end
		end
	end
	return best, least
end
Bags.Vendor = Nearest

-- The vendor as a route errand (R.AddErrand), or nil.
local function Find(lead)
	if not T.db.bags.sell then return nil end
	local open, slots = Bags.Free()
	if slots == 0 then return nil end
	local low = Low(slots)
	if open > low then
		put, shop = false, nil
		return nil
	end
	if put then return nil end
	local shy = Shy_Bags()
	-- (With ShyBags: only while something in the bags could go, to a shop or dropped.)
	if shy and not Cheapest() then return nil end
	local busy = InCombatLockdown() or UnitOnTaxi("player") or UnitIsDeadOrGhost("player")
	-- The shop it leads to: one in passing, or near enough for a row; and only while something would sell there.
	local at, yards = Nearest()
	local passing = at ~= nil and not busy and R.Passing("sell", at.map, at.x, at.y, lead, open == 0 and FULL_REACH or nil)
	if busy and shop ~= nil then
		-- (In a fight, on a flight or dead nothing is on the way: the shop it led to before stands, so the row
		-- says the same through every pull.)
		at = shop or nil
	else
		if at and ((not passing and yards > (open == 0 and LISTED_FULL or LISTED)) or (shy and not Sellable())) then at, passing = nil, false end
		if not busy then shop = at or false end
	end
	-- (No shop in reach: a row all the same where a click can drop something. Without ShyBags there is none to open.)
	if not at and not shy then return nil end
	local who = at and (at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name) or nil
	local left = open == 0 and "bags full" or ("%d slot%s left"):format(open, open == 1 and "" or "s")
	local full = open == 0 and "BAGS FULL" or "BAGS NEARLY FULL"
	-- What to sell isn't listed here: the menu sorts the bags by worth instead (ShyBags, Sort), and a click
	-- opens the bags with the cheapest things lit, each to drop (ShyBags, MakeRoom), until there is room again.
	local function Sort()
		shy:Sort("worth")
	end
	local function Drop()
		shy:MakeRoom({ need = low + 1, why = open == 0 and "Your bags are full" or "Your bags are nearly full" })
	end
	local title, caption, lines, todo
	if not shy then
		title, caption, lines = "Sell: " .. left, full .. "  \194\183  SELL HERE", { who }
		todo = { { glyph = "coin", lit = true, text = "Sell what you don't need" } }
	elseif at then
		title, caption = "Make room: " .. left, full .. "  \194\183  SELL OR DROP"
		lines = { who, "Sell here, or click to drop the cheapest" }
		todo = { { glyph = "coin", lit = true, text = "Sell what you don't need" },
			{ glyph = "bag", text = "Or click to drop the cheapest" } }
	else
		title, caption = "Make room: " .. left, full .. "  \194\183  DROP SOMETHING"
		lines = { "No shop nearby", "Click to drop the cheapest" }
		todo = { { glyph = "bag", lit = true, text = "Click to drop the cheapest" },
			{ quiet = true, indent = 2, text = "No shop is near. Sell at the next one you pass." } }
	end
	todo[#todo + 1] = { quiet = true, indent = 2, text = "Quest items and rewards need a free slot." }
	return {
		title = title,
		lines = lines,
		caption = caption,
		map = at and at.map, x = at and at.x, y = at and at.y, thing = at and at.npc, who = at and at.npc.name,
		mark = "sell",
		first = passing or nil,
		-- (With ShyBags a click makes room where you stand; the way to the shop is on the menu.)
		click = shy and Drop or nil,
		hint = shy and "Drop the cheapest" or nil,
		hover = function()
			return {
				{ title = "To do", rows = todo },
				{ title = "Room", rows = { { glyph = "bag", text = ("%d of %d slots free"):format(open, slots) } },
					bar = { have = (slots - open) / slots } },
			}
		end,
		tip = function(tip)
			tip:AddLine(("%d of %d slots free."):format(open, slots), 1, 1, 1)
			if shy then tip:AddLine(at and "Sell at a shop, or click to drop the cheapest." or "Click to drop the cheapest.", 1, 1, 1, true) end
			tip:AddLine("Quest items and rewards need a free slot.", 0.6, 0.6, 0.6, true)
		end,
		menuHint = shy and "Sort bags by worth" or nil,
		menu = function(root)
			if shy then root:CreateButton("Sort bags: least worth first", Sort) end
			root:CreateButton("Not now: ask again when they fill up", function()
				put = true
				ns.Refresh()
			end)
			if at then
				root:CreateButton(("%s doesn't buy: find another"):format(at.npc.name), function()
					D.NoteShop(at.npc.id, D.NO_SHOP, true)
					ns.Refresh()
				end)
			end
		end,
	}
end

-- Who keeps a shop
-- Only the running game says who buys and sells. A merchant window is a shop. A gossip window
-- with no goods to browse, or a quest giver with no gossip at all, is none (D.NoteShop).

local BROWSE = 132060        -- Interface\GossipFrame\VendorGossipIcon
local gossiped = {}          -- NPC ids whose gossip window opened this session

local function Talker()
	local guid = UnitGUID("npc")
	if guid == nil or issecretvalue(guid) then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	return kind == "Creature" and tonumber(id) or nil
end

-- Whether the open gossip window offers a shop. An icon that can't be read counts as one.
local function Browses()
	for _, option in ipairs(C_GossipInfo.GetOptions()) do
		local icon = option.overrideIconID or option.icon
		if icon == nil or issecretvalue(icon) or icon == BROWSE then return true end
	end
	return false
end

local function Shop(event)
	local id = Talker()
	if not id then return end
	local what
	if event == "MERCHANT_SHOW" then
		what = CanMerchantRepair() and D.REPAIRS or D.SHOP
	elseif event == "GOSSIP_SHOW" then
		gossiped[id] = true
		if not Browses() then what = D.NO_SHOP end
	elseif not gossiped[id] then
		-- A quest window with no gossip before it.
		what = D.NO_SHOP
	end
	if what and D.NoteShop(id, what) then ns.Refresh() end
end

-- No room for a quest

-- Prints `why` with the cheapest item, and has ShyBags highlight what could go.
local function Tell(need, why)
	if not T.db.bags.room then return end
	local shy = Shy_Bags()
	local lit = shy and shy:MakeRoom({ need = need, why = why }) or nil
	if GetTime() - told < TOLD_EVERY then return end
	told = GetTime()
	local least = lit and lit[1] or Cheapest()
	if least and (least.value or 0) == 0 then
		T:Print(("%s. %s is from a finished quest, so you can toss it."):format(why, least.link or least.name or "?"))
	elseif least then
		T:Print(("%s. Cheapest item in your bags: %s (%s)."):format(why, least.link or least.name or "?", Coins(least.value or 0)))
	else
		T:Print(why .. ".")
	end
end

-- Whether the data says accepting the quest gives an item (kind "s": needed but not counted).
local function Gives(quest)
	for _, token in ipairs(quest and quest.goals or {}) do
		if token.kind == "s" then return true end
	end
	return false
end

-- Whether an error message is one of the game's "inventory full" strings.
local function NoRoom(message)
	if type(message) ~= "string" or issecretvalue(message) then return false end
	if message == ERR_INV_FULL or message == INVENTORY_FULL then return true end
	-- "%s failed: Inventory is full."
	local pattern = ERR_QUEST_FAILED_BAG_FULL_S:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0"):gsub("%%s", ".+")
	return message:find("^" .. pattern .. "$") ~= nil
end

local talking = false        -- a quest window is open

-- Deleting what a quest still needs
-- The game's dialog warns only for what it files as a quest item (questWarn): a key, a stone or a pelt a quest
-- in the log counts or needs is deleted with the plain question. A plate of ours stands under that dialog
-- naming the quest, for as long as the dialog shows. Nothing is stopped or deleted for you.
local DIALOGS = { "DELETE_ITEM", "DELETE_GOOD_ITEM" }
local plate

-- The quest in the log that needs an item, by title, or nil: one whose count is full still hands it in.
function Bags.NeededBy(id)
	for _, tie in ipairs(id and ns.Index and ns.Index.Item(id) or {}) do
		if tie.kind ~= "pickup" and tie.id and L.Has(tie.id) then return tie.title end
	end
end

local function Plate()
	if plate then return plate end
	local C = UI.colors
	plate = CreateFrame("Frame", nil, UIParent)
	plate:SetSize(320, 30)
	plate:SetFrameStrata("DIALOG")
	plate:SetIgnoreParentAlpha(true)     -- seen with the game's dialog while immersive quest text quiets the screen
	UI.Panel(plate, { window = true })   -- beside the game's dialog: the theme's look, as a window wears it
	plate.text = UI.Text(plate, "", 12, false, C.bad)
	plate.text:SetPoint("LEFT", 12, 0)
	plate.text:SetPoint("RIGHT", -12, 0)
	plate.text:SetWordWrap(false)
	plate:Hide()
	plate:SetScript("OnUpdate", Shy.Clocked("frame: bags plate", function(self)
		local dialog = self.dialog
		if not dialog or not dialog:IsShown() or dialog.which ~= self.which then self:Hide() end
	end))
	return plate
end

local function Deleting(questWarn)
	if questWarn == 1 then return end
	local kind, id = GetCursorInfo()
	if kind ~= "item" then return end
	local title = Bags.NeededBy(id)
	if not title then return end
	for _, which in ipairs(DIALOGS) do
		local dialog = StaticPopup_FindVisible(which)
		if dialog then
			local p = Plate()
			p.dialog, p.which = dialog, which
			p.text:SetText(("Needed for %s"):format(title))
			p:SetFrameLevel(dialog:GetFrameLevel() + 5)
			p:ClearAllPoints()
			p:SetPoint("TOP", dialog, "BOTTOM", 0, -4)
			p:Show()
			return
		end
	end
end

-- The card's note for the leading step (ns.cardNotes).
local function Note(stop)
	if not T.db.bags.room or stop.kind == "errand" then return nil end
	local open, slots = Bags.Free()
	if slots == 0 or open > 0 then return nil end
	local takes, hands = false, false
	for _, action in ipairs(stop.view and stop.view.actions or stop.actions or {}) do
		if not action.done then
			if action.kind == "pickup" and Gives(D.Quest(action.id)) then takes = true end
			if action.kind == "turnin" then hands = true end
		end
	end
	if takes then return "Bags full: no room for the quest item" end
	if hands then return "Bags full: a reward may not fit" end
end

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_FINISHED",
	"UI_ERROR_MESSAGE", "MERCHANT_SHOW", "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_PROGRESS", "DELETE_ITEM_CONFIRM" }) do
	events:RegisterEvent(event)
end
local SHOPS = { MERCHANT_SHOW = true, GOSSIP_SHOW = true, QUEST_GREETING = true, QUEST_DETAIL = true, QUEST_PROGRESS = true,
	QUEST_COMPLETE = true }
events:SetScript("OnEvent", function(_, event, _, message, _, questWarn)
	if not ns.char then return end
	if event == "DELETE_ITEM_CONFIRM" then
		-- The game shows its dialog on this same event: look for it a frame on.
		C_Timer.After(0, function() Deleting(questWarn) end)
		return
	end
	if SHOPS[event] then Shop(event) end
	if event == "PLAYER_ENTERING_WORLD" or event == "BAG_UPDATE_DELAYED" then
		stale = true
	elseif event == "QUEST_FINISHED" then
		talking = false
	elseif event == "QUEST_DETAIL" then
		talking = true
		local open = Bags.Free()
		if open == 0 and Gives(D.Quest(GetQuestID())) then
			Tell(1, ("No room for the item from %s"):format(GetTitleText() or "this quest"))
		end
	elseif event == "QUEST_COMPLETE" then
		talking = true
		-- Slots needed: every fixed reward, plus one for a choice.
		local open = Bags.Free()
		local need = GetNumQuestRewards() + (GetNumQuestChoices() > 0 and 1 or 0)
		if need > open then
			Tell(need - open, ("No room for the reward from %s"):format(GetTitleText() or "this quest"))
		end
	elseif event == "UI_ERROR_MESSAGE" then
		-- Only while a quest window is open: full bags while looting is routine.
		if talking and NoRoom(message) then Tell(1, "No room in your bags for that quest") end
	end
end)

Shy:On("SHY_BAGS_ROOM", function()
	stale = true
	if ns.char then ns.Refresh() end
end)

-- Registers with ShyBags once, on the first route build (every addon has loaded by then). How an item
-- stands with the quests is Stash.lua's one answer (Stash.Status), and ShyBags is told all of it:
--   Keep       what a quest needs now or later is never offered to sell or drop
--   Needed     "now" or "later": the quest mark it wears, quest item to the game or not; and how soon its
--              quest comes, which the bags' sort by type puts them in order by
--   Leftover   a quest item no quest needs any more is junk (without Stash.lua: Index.lua's rule)
--   bank jobs  the bank window's lines that take out, put away and clear out in one go (Stash.BankJobs)
--   Holds      whether the bank, or the mailbox, holds something to fetch: the quest mark on that door
local kept = false
local function Stands(id)
	local stash = ns.Stash
	if not (stash and stash.Status) then return nil end
	return stash.Status(id)
end
local function Keep()
	local shy = Shy.addons.Bags
	if kept or not (shy and shy.Keep) then return end
	kept = true
	shy:Keep(function(id)
		local ties = ns.Index and ns.Index.Item(id)
		if type(ties) == "table" and next(ties) ~= nil then return true end
		local how = Stands(id)
		return how == "now" or how == "later"
	end)
	if shy.Needed then
		shy:Needed(function(id)
			local how, _, soon = Stands(id)
			if how == "now" or how == "later" then return how, soon end
		end)
	end
	if shy.Leftover and ns.Index and ns.Index.Quests then
		shy:Leftover(function(id)
			if ns.Stash and ns.Stash.Status then return ns.Stash.Status(id) == "over" end
			local _, behind = ns.Index.Quests(id, true)
			return behind == true
		end)
	end
	for _, job in ipairs(shy.RegisterBankJob and ns.Stash and ns.Stash.BankJobs and ns.Stash.BankJobs() or {}) do
		shy:RegisterBankJob(job)
	end
	-- (Which of the bags' doors, the bank's and the mailbox's, has something to fetch behind it.)
	if shy.Holds and ns.Stash and ns.Stash.Plan then
		shy:Holds(function(place)
			local found = ns.Stash.Plan()
			return #(place == "bank" and found.take or place == "mail" and found.post or {}) > 0
		end)
	end
end
-- A log change, or the guide moving on, can change what bag items mean without any bag event.
local logged, needed
ns.OnRoute(function(rebuilt)
	if not rebuilt then return end
	Keep()
	local needs = ns.Stash and ns.Stash.Stamp and ns.Stash.Stamp()
	if logged ~= L.version or needed ~= needs then
		logged, needed = L.version, needs
		local shy = Shy.addons.Bags
		if shy and shy.RefreshMarks then shy:RefreshMarks() end
	end
end, true)

ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Note)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Sell or drop when bags are nearly full", function() return T.db.bags.sell end, function()
		T.db.bags.sell = not T.db.bags.sell
		ns.Apply()
	end)
end)
ns.CardSwitch("suggestions", function(root)
	root:CreateCheckbox("What to drop when a quest needs room", function() return T.db.bags.room end, function()
		T.db.bags.room = not T.db.bags.room
		ns.Apply()
	end)
end)

-- Guarded: the loaded Route.lua may predate R.AddErrand until the client restarts.
if R and R.AddErrand then R.AddErrand("sell", Find, "Making room when bags fill") end
