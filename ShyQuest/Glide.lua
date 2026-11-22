-- Dropping down a cliff with a slowed fall, and walking across water. Where the way to a place does
-- either (Shy.Way's way.drop, way.fall and way.water), this gives the spell to cast first and the
-- time it saves.
--   Glide.Ahead(continent, north, west [, level, up]) -> the first drop or water still ahead on the trail the
--     maps draw to that place (level, up: W.Prefer's for its stop, as they ask): { kind = "fall" | "water",
--     spell, yards (to where it begins) }, or nil
--   Glide.Cue(continent, north, west [, level, up]) -> while one is close: { kind, spell, name, icon, text, on,
--     saves }
--   Glide.Coming(continent, north, west [, level, up]) -> one anywhere ahead that saves WORTH: { kind, spell,
--     name, icon, text, saves }
--   Glide.Saves(continent, north, west) -> seconds the way saves over one with neither, or nil
--   Glide.Swim(continent, north, west [, level, up]) -> seconds of swimming still ahead on that trail, and
--     the share of what is left of it they are; nil while water is walked on (then Ahead says it)
-- The card's leading row says it (ns.cardNotes), and so do the arrow and the row's hover. A long swim
-- ahead is said there too: a line over the sea reads as a boat otherwise.
-- A known spell with no reagent in any bag can't be counted on. Then the auction house is an errand
-- when it is on the way (no vendor in the data sells either reagent), unless the bank holds some,
-- in which case the bank's row says so.

local ADDON, ns = ...
local T = ns.T
local D, W, L, R = ns.Data, ns.World, ns.Log, ns.Route
local UI = Shy.UI
local C = UI.colors

local Glide = {}
ns.Glide = Glide

local NEAR = 60              -- yards from where a drop or the water begins: time to cast
local RUN = 7                -- yards a second running
local SWIM = 4.7222          -- yards a second swimming
local SWIM_SAID = 90         -- seconds of swimming ahead, at the least, for the card to say it
local SWIM_MOST = 0.5        -- share of the way left that is swum, at the least, for it to be how you get there
local LASTS = 0.4            -- a spell that lasts less is cast nearer: no more than this share of it spent running there
local WORTH = 30             -- seconds: a saving under this is not said
local AGAIN = 10             -- seconds before a saving not worked out is asked again
local KEPT = 40              -- places whose saving is kept

local saved, savedCount = {}, 0   -- [place] = { seconds or false, at }
local moves                  -- what Shy.Way.Moves said when the savings were worked out
local put                    -- "Not now": the reagent whose errand stays away until the bags hold one

-- A spell's row in Shy.Way.data.falls: { spell, seconds, level, reagent, cooldown, waivers }.
local function Row(spell)
	local falls = Shy.Way.data.falls
	if not (falls and spell) then return nil end
	for _, list in ipairs({ falls.spells or {}, falls.water or {} }) do
		for _, row in ipairs(list) do
			if row[1] == spell then return row end
		end
	end
	return nil
end

local function Wet(way, point)
	local swum = way[point * 3]
	return swum ~= nil and swum ~= false and swum ~= 0
end

-- The first drop or water on a way from its point `at` on, and the yards from the player to where it
-- begins (0: on its stretch already).
local function Find(way, at, north, west)
	if not (way.drop or way.water) then return nil end
	local _, fallSpell, _, waterSpell = Shy.Way.Moves()
	local yards = 0
	for i = math.max(2, at), way.n do
		local starts = i == at and 0 or yards
		if way.drop and way.drop[i] then return "fall", way.fall or fallSpell, starts end
		if way.water and Wet(way, i) and (not Wet(way, i - 1) or i == at) then return "water", way.water or waterSpell, starts end
		local toNorth, toWest = way[i * 3 - 2], way[i * 3 - 1]
		if i == at then
			yards = W.Between(north, west, toNorth, toWest)
		else
			yards = yards + W.Between(way[i * 3 - 5], way[i * 3 - 4], toNorth, toWest)
		end
	end
	return nil
end

-- The trail the maps draw to a place, the point of it walked toward and where the player is; nil while
-- it isn't known, aboard something or dead. (ShyWay keeps it, so asking again costs nothing.)
local function Trail(continent, north, west, level, up)
	if not (north and W.Known()) or continent ~= W.continent then return nil end
	if ns.Carried() or UnitIsDeadOrGhost("player") then return nil end
	local way, at = W.Way(continent, north, west, level, up)
	if not (way and type(at) == "number") then return nil end
	local hereNorth, hereWest = W.Here()
	return way, at, hereNorth, hereWest
end

function Glide.Ahead(continent, north, west, level, up)
	local way, at, hereNorth, hereWest = Trail(continent, north, west, level, up)
	if not way then return nil end
	local kind, spell, yards = Find(way, at, hereNorth, hereWest)
	if kind and spell then return { kind = kind, spell = spell, yards = yards } end
	return nil
end

-- A stretch is swum where both its ends are in water, half where one is (as the maps draw it).
function Glide.Swim(continent, north, west, level, up)
	local way, at, hereNorth, hereWest = Trail(continent, north, west, level, up)
	if not way or way.water then return nil end
	local swum, dry = 0, 0
	local fromNorth, fromWest, fromWet = hereNorth, hereWest, Wet(way, math.max(1, at - 1))
	for i = math.max(2, at), way.n do
		local toNorth, toWest, toWet = way[i * 3 - 2], way[i * 3 - 1], Wet(way, i)
		local yards = W.Between(fromNorth, fromWest, toNorth, toWest)
		local wet = (fromWet and toWet) and 1 or (fromWet or toWet) and 0.5 or 0
		swum, dry = swum + yards * wet, dry + yards * (1 - wet)
		fromNorth, fromWest, fromWet = toNorth, toWest, toWet
	end
	local seconds = swum / SWIM
	local whole = seconds + dry / RUN
	if seconds <= 0 or whole <= 0 then return nil end
	return seconds, seconds / whole
end

-- Seconds the way to a place saves over one that neither falls slowed nor walks on water, worked out once
-- per place (and again when what the player can do changes); nil when nothing is saved or it isn't known.
function Glide.Saves(continent, north, west)
	local ground = Shy.Way
	if not (north and W.Known()) or continent ~= W.continent then return nil end
	local deep, _, water = ground.Moves()
	local now = (deep or 0) .. (water and "+" or "")
	if moves ~= now then
		moves = now
		wipe(saved)
		savedCount = 0
	end
	local key = continent .. ":" .. math.floor(north) .. ":" .. math.floor(west)
	local kept = saved[key]
	if kept and (kept[1] or GetTime() - kept[2] < AGAIN) then return kept[1] or nil end
	if savedCount >= KEPT then
		wipe(saved)
		savedCount = 0
	end
	-- (Out of a frame's share of the ground: a way not yet known is asked again next time, kept once it is.
	-- Worked out on the spot, a new lead's two searches held the game still for seconds.)
	local with, state = ground.Ask(continent, W.north, W.west, north, west)
	if state == "working" then return nil end
	local without
	if with then
		without, state = ground.Without(continent, W.north, W.west, north, west, true)
		if state == "working" then return nil end
	end
	local seconds = (with and without and without > with) and without - with or false
	if not kept then savedCount = savedCount + 1 end
	saved[key] = { seconds, GetTime() }
	return seconds or nil
end

-- "Saves 45 sec", "Saves 3 min".
function Glide.SavesText(seconds)
	if seconds < 90 then return ("Saves %d sec"):format(math.floor(seconds / 5 + 0.5) * 5) end
	return ("Saves %d min"):format(math.floor(seconds / 60 + 0.5))
end

-- Whether the spell's aura is on the player now (not known in a fight: no).
local function On(spell)
	local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
	if issecretvalue(aura) then return false end
	return aura ~= nil
end

-- What a spell is called and its picture; the verb for it: cast where it takes a reagent, use otherwise.
local function Spell(spell)
	local row = Row(spell)
	return C_Spell.GetSpellName(spell), C_Spell.GetSpellTexture(spell), (row and row[4] > 0) and "Cast" or "Use", row
end

-- How near the edge or the shore it is cast: a spell that lasts a short while, nearer.
local function Reach(row)
	return math.min(NEAR, (row and row[2] or NEAR) * RUN * LASTS)
end

function Glide.Cue(continent, north, west, level, up)
	local ahead = Glide.Ahead(continent, north, west, level, up)
	if not ahead then return nil end
	local name, icon, verb, row = Spell(ahead.spell)
	if not name or ahead.yards > Reach(row) then return nil end
	local on = On(ahead.spell)
	local text
	if ahead.kind == "fall" then
		text = on and "Jump down" or ("%s %s, then jump"):format(verb, name)
	elseif on then
		return nil
	else
		text = ("%s %s"):format(verb, name)
	end
	local saves = Glide.Saves(continent, north, west)
	return { kind = ahead.kind, spell = ahead.spell, name = name, icon = icon, text = text, on = on,
		saves = saves and saves >= WORTH and saves or nil, yards = ahead.yards }
end

function Glide.Coming(continent, north, west, level, up)
	local ahead = Glide.Ahead(continent, north, west, level, up)
	if not ahead then return nil end
	local saves = Glide.Saves(continent, north, west)
	if not saves or saves < WORTH then return nil end
	local name, icon = Spell(ahead.spell)
	if not name then return nil end
	local text = ahead.kind == "fall" and ("Jump down a cliff with %s"):format(name) or ("Walk across water with %s"):format(name)
	return { kind = ahead.kind, spell = ahead.spell, name = name, icon = icon, text = text, saves = saves, yards = ahead.yards }
end

-- The picture as a line of text shows it, its rim trimmed.
function Glide.IconText(icon, size)
	return ("|T%s:%d:%d:0:0:64:64:5:59:5:59|t"):format(tostring(icon), size, size)
end

-- The card's leading row: the word to cast while the edge or the shore is close, else how much the way
-- saves by it.
local function Note(stop)
	if stop.sample or not stop.north then return nil end
	local level, up = W.Prefer(stop)
	local cue = Glide.Cue(stop.continent, stop.north, stop.west, level, up)
	if cue then
		return { text = cue.text, color = cue.on and C.good or C.alert, icon = cue.icon,
			right = cue.saves and Glide.SavesText(cue.saves), rightColor = C.dim }
	end
	local coming = Glide.Coming(stop.continent, stop.north, stop.west, level, up)
	if coming then
		return { text = coming.text, color = C.dim, icon = coming.icon, right = Glide.SavesText(coming.saves), rightColor = C.good }
	end
	local swim, share = Glide.Swim(stop.continent, stop.north, stop.west, level, up)
	if swim and swim >= SWIM_SAID then
		local minutes = math.floor(swim / 60 + 0.5)
		return { text = (share >= SWIM_MOST and "A %d min swim to get there" or "A %d min swim on the way"):format(minutes), color = C.text }
	end
	return nil
end

-- The leading row's hover: a section of its own.
function Glide.Section(stop)
	if not (stop and stop.north) or stop.sample then return nil end
	local level, up = W.Prefer(stop)
	local found = Glide.Cue(stop.continent, stop.north, stop.west, level, up) or Glide.Coming(stop.continent, stop.north, stop.west, level, up)
	if not found then return nil end
	return { title = "On the way", rows = { { icon = found.icon, text = found.text,
		right = found.saves and Glide.SavesText(found.saves) or nil, rightColor = C.good } } }
end

-- Reagents

-- Whether a spell's reagent is done away with (Reagent Economy's passives, as Shy.Way.data.falls lists them).
local function Waived(waivers)
	for _, waiver in ipairs(waivers or {}) do
		if C_SpellBook.IsSpellKnown(waiver) then return true end
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(waiver)
		if not issecretvalue(aura) and aura ~= nil then return true end
	end
	return false
end

-- The first spell known that slows a fall or walks on water and can't be cast for want of its reagent:
-- { spell, reagent, seconds, glides, water }, or nil.
function Glide.Lacking()
	local falls = Shy.Way.data.falls
	if not falls then return nil end
	for _, list in ipairs({ falls.spells or {}, falls.water or {} }) do
		for _, row in ipairs(list) do
			local spell, reagent = row[1], row[4]
			if reagent > 0 and C_SpellBook.IsSpellKnown(spell) and C_Item.GetItemCount(reagent) == 0 and not Waived(row[6]) then
				return { spell = spell, reagent = reagent, seconds = row[2], glides = row[7] == 1, water = list == falls.water }
			end
		end
	end
	return nil
end

-- Whether the reagent would be worth having for the way to what leads: the ground's way there as though
-- the spell could be cast saves WORTH_IT seconds or more (or is the only way). Asked once a lead and a
-- spell, kept for KEEP_WORTH seconds. With nothing to ask: worth it.
local WORTH_IT, KEEP_WORTH = 60, 120
local worth, worthCount = {}, 0
function Glide.Worth(lack, lead)
	local ground, falls = Shy.Way, Shy.Way.data.falls
	if not (falls and lead and lead.north and lead.continent == W.continent and W.Known()) then
		return true
	end
	local key = ("%d:%d:%d"):format(lack.spell, math.floor(lead.north), math.floor(lead.west))
	local kept = worth[key]
	if kept and GetTime() - kept.at < KEEP_WORTH then return kept.yes end
	local deep = math.floor(falls.speed * lack.seconds * 0.9 + falls.safe)
	-- (Out of a frame's share, as Saves: worth it, as with nothing to ask, until both are known.)
	local now, state = ground.Ask(lead.continent, W.north, W.west, lead.north, lead.west)
	if state == "working" then return kept and kept.yes or true end
	local with
	with, state = ground.With(lead.continent, W.north, W.west, lead.north, lead.west, lack.water and 0 or deep, (lack.glides and not lack.water) and deep or 0,
		lack.water, true)
	if state == "working" then return kept and kept.yes or true end
	local yes = with ~= nil and (now == nil or now - with >= WORTH_IT)
	if not kept then
		if worthCount >= 40 then
			wipe(worth)
			worthCount = 0
		end
		worthCount = worthCount + 1
	end
	worth[key] = { at = GetTime(), yes = yes }
	return yes
end

-- What else holds a reagent: this character's bank (the game's count, else what the bags window last
-- saw of it), and the other characters, by name: { name, count, where }.
function Glide.Held(reagent)
	local bank = math.max(0, C_Item.GetItemCount(reagent, true) - C_Item.GetItemCount(reagent))
	local others = {}
	local bags = Shy.addons.Bags
	if bags and bags.Count then
		local mine = UnitGUID("player")
		local _, places = bags:Count(reagent)
		for _, place in ipairs(places or {}) do
			if place.guid == mine then
				bank = math.max(bank, place.bank or 0)
			elseif place.char then
				local count = (place.bags or 0) + (place.bank or 0) + (place.mail or 0)
				local where = (place.bank or 0) > 0 and "bank" or (place.mail or 0) > 0 and "mail" or "bags"
				if count > 0 then others[#others + 1] = { name = place.char.name, count = count, where = where } end
			end
		end
	end
	return bank, others
end

local function ItemName(id)
	return C_Item.GetItemNameByID(id) or D.Name("items", id) or "reagent"
end

-- The nearest friendly auctioneer: { npc, map, x, y, yards }, or nil.
local function Auctioneer()
	local best
	for _, id in ipairs(D.Town("auction")) do
		local npc = D.Npc(id)
		if npc and L.Friendly(npc) then
			local map, x, y, yards, dungeon = W.Nearest(npc.places)
			if map and yards and not dungeon and (not best or yards < best.yards) then
				best = { npc = npc, map = map, x = x, y = y, yards = yards }
			end
		end
	end
	return best
end

-- Whether restocking reagents is on (Supplies.lua's settings).
local function Stocking()
	local supplies = T.db.supplies
	return supplies ~= nil and supplies.on and supplies.carry.reagents ~= 0
end

-- The auction house as a route errand (R.AddErrand) while on the way, or nil.
local function Errand(lead)
	if not Stocking() then return nil end
	local lack = Glide.Lacking()
	if not lack or put == lack.reagent then return nil end
	local bank, others = Glide.Held(lack.reagent)
	if bank > 0 then return nil end
	-- (Only where the spell would save a good deal on the way to what leads.)
	if not Glide.Worth(lack, lead) then return nil end
	local at = Auctioneer()
	if not at or not R.Passing("glide", at.map, at.x, at.y, lead) then return nil end
	local item, spell = ItemName(lack.reagent), C_Spell.GetSpellName(lack.spell) or ""
	return {
		title = ("Auction house: %s"):format(item),
		lines = { at.npc.title and ("%s, %s"):format(at.npc.name, at.npc.title) or at.npc.name, ("For %s"):format(spell) },
		caption = ("FOR %s  \194\183  BUY AT AUCTION"):format(spell:upper()),
		map = at.map, x = at.x, y = at.y, thing = at.npc, who = at.npc.name,
		mark = "buy",
		first = true,
		hover = function()
			local sections = { { title = "To buy", rows = { { icon = C_Item.GetItemIconByID(lack.reagent), glyph = "coin", text = item,
				right = spell, rightColor = UI.colors.dim } } } }
			if #others > 0 then
				local rows = {}
				for i, other in ipairs(others) do
					rows[i] = { glyph = "bag", text = ("%s: %d"):format(other.name, other.count), right = other.where, rightColor = UI.colors.dim }
				end
				sections[2] = { title = "Your other characters", rows = rows }
			end
			return sections
		end,
		tip = function(tip)
			tip:AddLine(item, 1, 1, 1)
		end,
		menu = function(root)
			root:CreateButton("Not now", function()
				put = lack.reagent
				ns.Refresh()
			end)
		end,
	}
end

R.AddErrand("glide", Errand, "Travel spell reagents")
R.AddOffer("glide", function()
	if not ns.char or not Stocking() then return {} end
	local lack = Glide.Lacking()
	if not lack or Glide.Held(lack.reagent) > 0 then return {} end
	return { { text = ("Auction house: %s"):format(ItemName(lack.reagent)) } }
end)

ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Note)

local events = CreateFrame("Frame")
for _, event in ipairs({ "BAG_UPDATE_DELAYED", "BANKFRAME_OPENED" }) do events:RegisterEvent(event) end
local function Seen(_, event)
	if not ns.char then return end
	local lack = Glide.Lacking()
	if event == "BANKFRAME_OPENED" then
		-- At the bank: the reagent a spell is short of, said once in chat.
		local bank = lack and C_Item.GetItemCount(lack.reagent, true) - C_Item.GetItemCount(lack.reagent) or 0
		if bank > 0 then
			T:Print(("you have |cffffffff%d %s|r in your bank for %s."):format(bank, ItemName(lack.reagent), C_Spell.GetSpellName(lack.spell) or ""))
		end
		return
	end
	if put and (not lack or lack.reagent ~= put) then put = nil end
	-- (A change in the bags builds the route again already, ShyQuest.lua: the guide is asked only when it reads them.)
	if event == "BAG_UPDATE_DELAYED" then return end
	-- (A spell learned: the reagent errand's alone. The errands are fitted again, not the route.)
	ns.RefreshErrands()
end
events:SetScript("OnEvent", Seen)
Shy:On("SHY_SPELLS", function() Seen(nil, "SHY_SPELLS") end)
