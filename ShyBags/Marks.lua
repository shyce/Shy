-- Item marks. Each mark has a channel; one mark shows per channel, the first registered (or `after`) winning.
--   border quality (grey too: a dull frame); glow new; tr the quest's mark; bl junk or bind on equip;
--   tl upgrade (Gear.lua); top vendor price (Room.lua); tint unusable
-- A test takes an item and returns what to show, or nil. item = { id, quality, count, bound, quest, starter,
--   bind, live, bag, slot (when live), guid, source, over, needed, ahead }
-- The quest's mark is one mark in three states (each a shape of its own: whole, in outline, broken), by what
-- the item is to your quests now:
--   needed now       `quest` (the game calls it a quest item) or `needed` (it doesn't, but a quest needs it:
--                    meat, cloth); `starter` for one that starts a quest
--   needed later     `ahead`: a quest wants it, and it can wait in the bank until then
--   no longer needed `over`: a quest item whose quests are all behind you
-- The game says none of this but "quest item", so the rest comes from other addons' tests, asked only about
-- this character's items: T:Needed's answer "now" or "later" (anything else true is "now"; a second answer,
-- a number, is how soon its quest comes, for the sort by type), T:Leftover's yes about a quest item.
--   Marks.Register({ id, channel, after, title, desc, default, with, test, make, show })
--       title, desc: its switch in the settings. with: another mark's id, whose switch it follows instead
--       make(tile) creates custom art once per slot; show(mark, kind) shows it, or hides it when kind is nil
--   Marks.For(item)        channel -> { id, kind, def } for the enabled marks that apply

local ADDON, ns = ...
local T = ns.T
local Store = ns.Store

local Marks = {}
ns.Marks = Marks

Marks.CHANNELS = { "border", "glow", "tr", "bl", "tl", "top", "tint" }

T.defaults.marks = {}   -- mark id -> shown; nil: the mark's default

local list = {}         -- in test order
local byId = {}
local changed = {}      -- refresh listeners
local leftovers = {}    -- other addons' leftover tests
local needs = {}        -- other addons' "a quest needs this" tests

function Marks.Leftover(id, bag, slot)
	for _, test in ipairs(leftovers) do
		local ok, yes = pcall(test, id, bag, slot)
		if ok and yes then return true end
	end
	return false
end

-- "now", "later", or nil: the first test's word that a quest needs it. Second, when the test says: how soon
-- its quest comes, a number to put things in order by (lower: sooner).
function Marks.Needed(id, bag, slot)
	for _, test in ipairs(needs) do
		local ok, when, soon = pcall(test, id, bag, slot)
		if ok and when then return when == "later" and "later" or "now", type(soon) == "number" and soon or nil end
	end
	return nil
end

-- How an item stands with your quests, as its mark shows it: "now", "later", "over" or nil, and with the
-- first two how soon (Marks.Needed). `quest`: the game calls it a quest item.
local function Standing(id, quest, bag, slot)
	if quest and Marks.Leftover(id, bag, slot) then return "over" end
	local when, soon = Marks.Needed(id, bag, slot)
	if when then return when, soon end
	return quest and "now" or nil
end

-- The same of a live slot, for what is not drawing it (the sort by type).
function Marks.Stands(id, bag, slot)
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	return Standing(id, quest ~= nil and (quest.questID or quest.isQuestItem) and true or false, bag, slot)
end

function Marks.Register(def)
	assert(def.id and def.channel and def.test, "a mark needs an id, a channel and a test")
	if byId[def.id] then return end
	byId[def.id] = def
	local at = #list + 1
	if def.after then
		for index, other in ipairs(list) do
			if other.id == def.after then at = index + 1 end
		end
	end
	table.insert(list, at, def)
	-- One that comes after the settings were told (another addon's, at login) joins them.
	if ns.TellMark then ns.TellMark(def) end
end

-- A mark with `with` has no switch of its own: it is on while that mark is.
function Marks.IsOn(def)
	def = def.with and byId[def.with] or def
	local set = T.db.marks[def.id]
	if set == nil then return def.default ~= false end
	return set
end

-- The same by its id, for what wears a mark outside a slot (a door of the window).
function Marks.On(id)
	local def = byId[id]
	return def ~= nil and Marks.IsOn(def)
end

function Marks.SetOn(id, on)
	local def = byId[id]
	T.db.marks[def and def.with or id] = on and true or false
	Marks.Refresh()
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function Marks.List() return list end

function Marks.For(item)
	local out = {}
	for _, def in ipairs(list) do
		if not out[def.channel] and Marks.IsOn(def) then
			local kind = def.test(item)
			if kind then out[def.channel] = { id = def.id, kind = kind, def = def } end
		end
	end
	return out
end

function Marks.OnRefresh(fn) changed[#changed + 1] = fn end

-- only: { [bag * 1000 + slot] = true }, the slots whose marks changed; nil for every slot.
function Marks.Refresh(only)
	for _, fn in ipairs(changed) do ns.Guard(fn, only) end
end

-- Whether a live slot's item is new (picked up since the bags were last opened). False when the game keeps
-- the answer back: a secret can't be tested for truth.
function Marks.IsNew(bag, slot)
	local new = C_NewItems.IsNewItem(bag, slot)
	if issecretvalue(new) then return false end
	return new == true
end

-- A live slot as an item, or nil.
function Marks.Item(bag, slot)
	local info = C_Container.GetContainerItemInfo(bag, slot)
	if not info or not info.itemID then return nil end
	local item = { id = info.itemID, quality = info.quality, count = info.stackCount, bound = info.isBound,
		noValue = info.hasNoValue, locked = info.isLocked, live = true, bag = bag, slot = slot, guid = Store.Guid(),
		source = (bag >= Enum.BagIndex.CharacterBankTab_1 and "bank") or (bag == Enum.BagIndex.Keyring and "keys") or "bags" }
	local quest = C_Container.GetContainerItemQuestInfo(bag, slot)
	if quest then
		item.starter = (quest.questID and not quest.isActive) and true or false
		item.quest = (item.starter or quest.questID or quest.isQuestItem) and true or false
	end
	local how = Standing(item.id, item.quest, bag, slot)
	if how == "over" then
		item.over, item.starter = true, false
	elseif how then
		if not item.quest then item.needed = true end
		if how == "later" then item.ahead = true end
	end
	local _, _, bind = Store.Fact(item.id)
	item.bind = bind
	return item
end

-- A stored slot string as an item, or nil.
function Marks.Remembered(slot, guid, source)
	local link, count, flags, name = Store.Unpack(slot)
	if not link then return nil end
	local id = Store.ItemID(link)
	local quality, _, bind = Store.Fact(id or 0)
	local item = { id = id, item = link, name = name, quality = quality, count = count, bind = bind, guid = guid, source = source,
		bound = flags:find("b", 1, true) ~= nil, quest = flags:find("[qs]") ~= nil, starter = flags:find("s", 1, true) ~= nil }
	if Marks.Over(item) then
		item.over, item.starter = true, false
	elseif id and needs[1] and guid == Store.Guid() then
		local when = Marks.Needed(id)
		if when and not item.quest then item.needed = true end
		if when == "later" then item.ahead = true end
	end
	return item
end

-- Only this character's stored items: other characters' quests are unknown.
function Marks.Over(item)
	return item.quest == true and item.id ~= nil and item.guid == Store.Guid() and Marks.Leftover(item.id)
end

-- Built-in marks

Marks.Register({
	id = "quality", channel = "border", title = "Quality",
	desc = "Each slot's border shows the item's quality color. Grays get a dull one.",
	test = function(item)
		local quality = item.quality
		if quality and quality ~= Enum.ItemQuality.Common then return quality end
	end,
})

Marks.Register({
	id = "new", channel = "glow", title = "New items",
	desc = "Anything new since you last opened your bags glows until you point at it.",
	test = function(item)
		return item.live and Marks.IsNew(item.bag, item.slot) or false
	end,
})

-- The quest's mark in its states. One switch for them all ("quest"): a state switched off alone would
-- leave the whole mark in its place.
-- Registered before "starter" and "quest", which it replaces on a leftover.
Marks.Register({
	id = "over", channel = "tr", with = "quest",
	test = function(item) return item.over end,
})

Marks.Register({
	id = "starter", channel = "tr", with = "quest",
	test = function(item) return item.starter end,
})

-- Before "quest" and "needed", which it stands in for on what can wait.
Marks.Register({
	id = "ahead", channel = "tr", with = "quest",
	test = function(item) return item.ahead end,
})

Marks.Register({
	id = "quest", channel = "tr", title = "Quest marks",
	desc = "Items a quest needs or starts get the quest mark. It's in outline on what can wait and broken on what you can drop.",
	test = function(item) return item.quest end,
})

Marks.Register({
	id = "needed", channel = "tr", with = "quest",
	test = function(item) return item.needed end,
})

Marks.Register({
	id = "junk", channel = "bl", title = "Junk",
	desc = "Greys and quest leftovers a vendor will buy get a coin.",
	test = function(item)
		if item.over then return item.noValue == false end
		return item.quality == Enum.ItemQuality.Poor and not item.noValue
	end,
})

Marks.Register({
	id = "boe", channel = "bl", title = "Bind on equip",
	desc = "Gear that binds when equipped gets a tag while you can still trade it.",
	test = function(item) return item.bind == Enum.ItemBind.OnEquip and not item.bound end,
})

-- For other addons.
function T:RegisterMark(def)
	Marks.Register(def)
	Marks.Refresh()
end

-- Also invalidates Room's list, which depends on the leftover tests.
function T:RefreshMarks()
	if ns.Room and ns.Room.Forget then ns.Room.Forget() end
	Marks.Refresh()
end

function T:Leftover(test)
	leftovers[#leftovers + 1] = test
	self:RefreshMarks()
end

function T:Needed(test)
	needs[#needs + 1] = test
	self:RefreshMarks()
end
