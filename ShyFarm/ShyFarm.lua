-- Farming sessions: what you grind or fish, what it is worth and how fast it comes. Session.lua counts what
-- reaches your bags, Prices.lua says what each thing is worth, Auction.lua reads the auction house when you ask,
-- Card.lua is the piece on the screen.
--
-- Public (Shy.addons.Farm):
--   T:Session()             the session, or nil: { state ("ready" | "running" | "paused"), kind, seconds, value, coin,
--                           kills, corpses, catches, want (the item counted), goal, mob (the creature farmed) }
--   T:Farm(item, goal)      farm an item: a session is set up for it if none goes on (ready: it asks to start as you
--                           reach where it drops), and the best camp to farm it is your active waypoint (ShyQuest);
--                           goal: how many you want, or nil
--   T:FarmMob(npc, [item], [goal])   farm a creature: all it drops counts, at your prices; item: the one of them
--                           counted on its own (to `goal`). Its best camp is your active waypoint
--   T:FarmAnything()        record everything: nothing in particular farmed, all you loot counts, the clock going now
--   T:Loots(npc)            whether the loot tables know a creature (it has something to loot)
--   T:FarmsFor([item])      the farms last weighed for `item` (nil: for gold), or nil; and whether a weighing is going
--   T:Favorites()           your favorites with their stats: { { item, goal, name, stats } }, by name
--   T:IsFavorite(item) / T:Favorite(item, on)   one kept or let go (nil: turned)
--   T:StatRows(item)        a favorite's stats as a hover's rows
--   T:Graph(parent, w, h)   a graph of its sessions (graph:Show(item)); a click turns it between items and gold
--   T:Stop()                ends the session going on
--   T:Worth(item)           what one is worth as you value it: copper, and where that comes from ("auction",
--                           "vendor", "own"), or nil
--   T:Drops(item)           what you have looted of it yourself, from which creatures: { { creature, name, drops,
--                           corpses } }, most corpses first
--   T:FarmMenu(root, item)  its rows in a menu of another addon's (the finder's item menu)
--   T:ItemLines(item, add)  its lines in a hover of another addon's: add(left, right) for each
--   T:RankFarms([item])     weighs every farm you could farm again, over a few frames (only those that drop `item`)
--   T:Farmable(item)        whether creatures are a way to get an item: one drops it at least once in ten kills
--   T:Farms()               the farms, best first by gold an hour, and how the weighing stands ("working" | "done" |
--                           "missing"): Farms.lua has a farm's fields
--   T:Pace()                seconds a kill takes you: your sessions' own, else a usual fight's; and whether it is yours
--   T:KillWorth(npc)        copper a kill of a creature brings on average, and what brings most of it ({ item, per,
--                           copper } each); nil for a creature the data doesn't know
-- Bus: SHY_FARM (why) whenever the session, a price or the farms change ("farms").

local ADDON, ns = ...

local T = Shy:NewAddon(ADDON, {
	suffix = "Farm",
	category = "items",
	icon = "Interface\\AddOns\\ShyFarm\\Media\\ShyFarm",
	smallIcon = "Interface\\AddOns\\ShyFarm\\Media\\ShyFarmSmall",
	savedVariables = "ShyFarmDB",
	defaults = {
		on = true,            -- the piece on screen while a session goes on
		fishing = true,       -- fishing starts a session by itself
		value = "auction",    -- "auction": an auction price when you have one, else the vendor's | "vendor": the vendor's
		auction = true,       -- read prices at the auction house (only when you open it)
		autoCheck = false,    -- check what wants a price as soon as the auction house opens
		tell = true,          -- say in chat what a lookup at the auction house found
		idle = 5,             -- minutes with nothing done before the clock stops (0: never)
		rows = 6,             -- loot rows it is planned at
		sound = true,         -- a sound when you have what you wanted
		prices = {},          -- [item] = { ah, at, none, own, use }: the account's price book
		seen = {},            -- [creature] = { name, n (corpses looted), i = { [item] = count } }: your own drops
		fishSpells = {},      -- [spell] = true: the spells whose loot was a catch (learned as you fish)
		favorites = {},       -- [item] = { goal, added }: what you farm again and again (the finder lists them)
		graph = "items",      -- what a favorite's graph shows: "items" an hour, or "gold" an hour
	},
	keep = { prices = true, seen = true, fishSpells = true, favorites = true },
})
ns.T = T

local appliers = {}
ns.appliers = appliers

function ns.Apply()
	for _, fn in ipairs(appliers) do fn() end
	if ns.RefreshOptions then ns.RefreshOptions() end
	Shy:Fire("SHY_SWITCH", "shyfarm")   -- its piece's switch in layout mode follows its setting
end

-- Something changed that the piece and other addons show: said the frame after, each kind of change once and in
-- order (a farm started and stopped in one frame says both), the appliers run once.
local whys = {}
local function Say()
	local said = whys
	whys = {}
	for _, why in ipairs(said) do Shy:Fire("SHY_FARM", why) end
	for _, fn in ipairs(appliers) do fn() end
end
function ns.Changed(why)
	for _, each in ipairs(whys) do
		if each == why then return end
	end
	whys[#whys + 1] = why
	if #whys == 1 then C_Timer.After(0, Say) end
end

-- Public

function T:Session()
	local S = ns.Session
	local s = S and S.Current()
	if not s then return nil end
	return { state = s.state, kind = S.Kind(s), seconds = S.Seconds(s), value = S.Value(s), coin = s.coin, kills = S.Kills(s),
		corpses = s.corpses, catches = s.catches, want = s.want and s.want.item, goal = s.want and s.want.goal,
		mob = s.mob and s.mob.npc }
end

-- (It leads there too: the best camp to farm it is your active waypoint.)
function T:Farm(item, goal)
	ns.Session.Target(nil, item, goal)
	if item and ns.Card and ns.Card.Lead then ns.Card.Lead() end
end

function T:FarmMob(npc, item, goal)
	if not npc then return end
	ns.Session.Target(npc, item, goal)
	if ns.Card and ns.Card.Lead then ns.Card.Lead() end
end

-- Record everything: nothing in particular farmed, all you loot counts, the clock going now.
function T:FarmAnything()
	ns.Session.Target(nil, nil)
	ns.Session.Clock()
	if ns.Card and ns.Card.Paint then ns.Card.Paint() end
end

function T:Loots(npc)
	return npc ~= nil and ns.loot ~= nil and ns.loot.creatures[npc] ~= nil
end

function T:FarmsFor(item) return ns.Farms.For(item) end

function T:Stop()
	ns.Session.Stop()
end

function T:Favorites() return ns.Stats.Favorites() end
function T:IsFavorite(item) return ns.Stats.IsFavorite(item) end
function T:Favorite(item, on) ns.Stats.Favorite(item, on) end
function T:StatRows(item) return ns.Stats.Rows(item) end
function T:Graph(parent, width, height) return ns.Graph(parent, width, height) end

function T:Worth(item)
	return ns.Prices.Value(item)
end

function T:Drops(item)
	return ns.Session.Drops(item)
end

function T:RankFarms(item) ns.Farms.Rank(item) end
function T:Farmable(item) return item ~= nil and ns.Farms.Farmable(item) end
function T:Farms() return ns.Farms.List() end
function T:Pace() return ns.Farms.Pace() end

-- (most: how many of what brings most, 5 unless told.)
function T:KillWorth(npc, most)
	local copper = ns.Worth.Worth(npc)
	if not copper then return nil end
	return copper, ns.Worth.Best(npc, most or 5)
end

-- The finder's item menu: farm it, to a count or not.
function T:FarmMenu(root, item)
	if not item then return end
	root:CreateDivider()
	root:CreateButton("Farm this", function() T:Farm(item) end)
	root:CreateCheckbox("Favorite", function() return ns.Stats.IsFavorite(item) end, function() ns.Stats.Favorite(item) end)
	local count = root:CreateButton("Farm this many")
	for _, n in ipairs({ 5, 10, 20, 40 }) do
		count:CreateButton(tostring(n), function() T:Farm(item, n) end)
	end
end

-- An item's lines in another addon's hover: its worth, and what you have looted of it yourself.
function T:ItemLines(item, add)
	local copper, from = ns.Prices.Value(item)
	if copper and copper > 0 then add("Worth", ns.Prices.Text(copper) .. "  " .. ns.Prices.FROM[from]) end
	local drops = ns.Session.Drops(item)
	for i, each in ipairs(drops) do
		if i > 3 then break end
		add(("You, from %s"):format(each.name or "a creature"), ("%d in %d"):format(each.drops, each.corpses))
	end
end

function T:OnLoad()
	ns.char = ShyFarmCharDB or {}
	ShyFarmCharDB = ns.char
	ns.char.history = ns.char.history or {}
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	ns.Session.Start()
	ns.Auction.Start()
	ns.Card.Start()
end

function T:OpenWindow()
	ns.Card.Reveal()
end

local function Help()
	T:Print("commands:")
	print("  /shyfarm  - open options")
	print("  /shyfarm start  - start a session")
	print("  /shyfarm reset  - save this session and start fresh (stop works too)")
	print("  /shyfarm show  - show the window (starts a session if none is going)")
	print("  /shyfarm pause  - pause or go on")
	print("  /shyfarm farm <item>  - farm an item (its link, ID or name)")
	print("  /shyfarm find  - find an item or a creature to farm")
	print("  /shyfarm price <item> <price>  - set your own price, like 1g 20s")
end

-- An item from words: a link, an ID, or a name in your bags or the session.
local function ItemFrom(text)
	text = strtrim(text or "")
	local id = tonumber(text:match("item:(%d+)") or text:match("^#?(%d+)$") or "")
	if id then return id end
	if text == "" then return nil end
	return ns.Session.Named(text)
end

SLASH_SHYFARM1 = "/shyfarm"
SlashCmdList.SHYFARM = function(input)
	local cmd, rest = strtrim(input or ""):match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "start" then
		ns.Session.Begin()
	elseif cmd == "reset" or cmd == "stop" or cmd == "end" then
		ns.Session.Stop()
	elseif cmd == "show" then
		ns.Card.Reveal()
	elseif cmd == "pause" then
		ns.Session.Pause()
	elseif cmd == "farm" then
		local item = ItemFrom(rest)
		if item then T:Farm(item) else T:Print("which item? Shift-click it, or give its ID.") end
	elseif cmd == "find" then
		if not (ns.Card.Find and ns.Card.Find()) then T:Print("you need ShyQuest turned on for that.") end
	elseif cmd == "price" then
		local link, amount = rest:match("^(|c.-|r)%s*(.*)$")
		if not link then link, amount = rest:match("^(%S+)%s*(.*)$") end
		local item, copper = ItemFrom(link), ns.Prices.Parse(amount)
		if item and copper then
			ns.Prices.SetOwn(item, copper)
			T:Print(("your price for %s is %s."):format(C_Item.GetItemNameByID(item) or "it", ns.Prices.Text(copper)))
		else
			T:Print("give the item and a price, like: /shyfarm price 2672 1g 20s")
		end
	else
		Help()
	end
end
