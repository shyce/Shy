-- The game's pop-ups wait as notices at the top instead: loot won, a boss's banner and its loot,
-- achievements, level ups and what they bring, recipes, mounts and pets learned. While it is on, the
-- frames that pop them up stop hearing those events (as "Hide error spam" does for the red text) and
-- they are heard here; each frame gets them back when it goes off.

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors

local KEEP = 8                -- rows a notice keeps, the newest first
local HOLD = 12               -- seconds a notice stands after the last of its kind came, before it leaves by itself
local TOASTS_AT_ONCE = 20     -- the most event toasts read off the game's queue in one go

-- What each of the game's frames hears that is a notice here. Criteria toasts (a step of an achievement)
-- are taken and dropped: the achievement itself is the notice.
local TAKEN = {
	AlertFrame = { "ACHIEVEMENT_EARNED", "CRITERIA_EARNED", "LOOT_ITEM_ROLL_WON", "SHOW_LOOT_TOAST", "SHOW_LOOT_TOAST_UPGRADE",
		"SHOW_LOOT_TOAST_LEGENDARY_LOOTED", "NEW_RECIPE_LEARNED", "NEW_MOUNT_ADDED", "NEW_PET_ADDED" },
	BossBanner = { "BOSS_KILL", "ENCOUNTER_LOOT_RECEIVED" },
	EventToastManagerFrame = { "DISPLAY_EVENT_TOASTS" },
}
local taken = {}              -- frame name -> { event = true } for what this took and gives back

local news = {}               -- kind -> rows, the newest first, with .total since it was last cleared (by hand,
                              -- or by itself: a notice leaves HOLD after the last of its kind, and the next one
                              -- of that kind begins a count of its own)

local function Plain(v)
	if v == nil or issecretvalue(v) then return nil end
	return v
end

local function ItemName(link)
	link = Plain(link)
	if type(link) ~= "string" then return nil end
	return link:match("%[(.-)%]") or link
end

local function Quality(link)
	local q = link and C_Item.GetItemQualityByID(link)
	if not q then return nil end
	local r, g, b = C_Item.GetItemQualityColor(q)
	return { r, g, b }, q
end

-- A hyperlink the game's tooltip can show, or nil.
local function Link(link)
	link = Plain(link)
	if type(link) ~= "string" or not link:find("|H", 1, true) then return nil end
	return link
end

-- A spell's rank as the game words it ("Rank 2"), or the kind word a spell's card has at its head.
local function SpellWord(id)
	local rank = Plain(C_Spell.GetSpellSubtext(id))
	return (rank and rank ~= "") and rank or "Spell"
end

-- The kinds of news: their sign, the color it stands in and the hover's head.
local KINDS = {
	loot = { order = 20, glyph = "loot", head = "Loot",
		Color = function(rows)
			local best, color = -1, C.alert
			for _, row in ipairs(rows) do
				if row.quality and row.quality > best then best, color = row.quality, row.color end
			end
			return color
		end },
	boss = { order = 21, glyph = "kill", color = C.good,
		Head = function(rows) return rows.total == 1 and "Boss defeated" or "Bosses defeated" end },
	feat = { order = 22, glyph = "star", color = C.alert,
		Head = function(rows) return rows.total == 1 and "Achievement" or "Achievements" end },
	-- The level reached heads what it brings (its row is the head, not one of them).
	level = { order = 23, glyph = "up", color = C.hot,
		Head = function(rows)
			for _, row in ipairs(rows) do
				if row.head then return row.text end
			end
			return #rows == 1 and "New spell" or "New spells"
		end },
	learned = { order = 24, glyph = "book", color = C.hot, head = "Learned" },
}
local ORDER = { "loot", "boss", "feat", "level", "learned" }

local Post

local function Clear(kind)
	news[kind] = nil
	Shy.Notices.Clear("toasts." .. kind)
end

local function ClearAll()
	for _, kind in ipairs(ORDER) do Clear(kind) end
end

local function Others(kind)
	for _, other in ipairs(ORDER) do
		if other ~= kind and news[other] then return true end
	end
	return false
end

-- The rows the list shows: a boss stands with its loot under it; the level reached is the heading, and a
-- row only while it brought nothing else.
local function Rows(kind)
	local out, heads = {}, {}
	for _, row in ipairs(news[kind] or {}) do
		if row.head then
			heads[#heads + 1] = row
		else
			out[#out + 1] = row
			for _, under in ipairs(row.loot or {}) do out[#out + 1] = under end
		end
	end
	if #out == 0 then return heads end
	return out
end

function Post(kind)
	local rows = news[kind]
	if not rows or #rows == 0 then
		Clear(kind)
		return
	end
	local k = KINDS[kind]
	Shy.Notices.Post("toasts." .. kind, {
		order = k.order, glyph = k.glyph,
		color = k.Color and k.Color(rows) or k.color,
		count = rows.total,
		title = k.Head and k.Head(rows) or k.head,
		says = "Click to see them. Right-click to clear.",
		note = function()
			local more = rows.total - #rows
			if more > 0 then return "And " .. more .. " more" end
		end,
		rows = function() return Rows(kind) end,
		hold = ns.Toasts.hold,
		gone = function() news[kind] = nil end,
		menu = function(root)
			root:CreateButton("Clear", function() Clear(kind) end)
			if Others(kind) then root:CreateButton("Clear every alert", ClearAll) end
		end,
	})
end

-- Where ShyCore has the column's head, loot won and a level reached also take its circle for a moment:
-- the item's own picture and its name in its quality's color, or the level's sign and the level.
local SAY = 3
local function Lifted(color)
	return { color[1] + (1 - color[1]) * 0.3, color[2] + (1 - color[2]) * 0.3, color[3] + (1 - color[3]) * 0.3 }
end

local function Say(kind, row, rows)
	local N = Shy.Notices
	if not (N and N.Voice) then return end
	if kind == "loot" and row.icon then
		local sub
		if row.link then sub = select(3, C_Item.GetItemInfoInstant(row.link)) end
		local what = (type(sub) == "string" and not issecretvalue(sub) and sub ~= "") and sub:upper() or "LOOT"
		N.Voice("toast", { priority = 15, hold = SAY, icon = row.icon, color = row.color or C.alert,
			title = row.text, titleColor = row.color and Lifted(row.color) or C.text,
			under = rows.total > 1 and (what .. "  ·  " .. rows.total .. " WON") or what,
			click = function() Shy.Notices.Open("toasts.loot") end })
	elseif kind == "level" and row.head then
		N.Voice("toast", { priority = 15, hold = SAY, glyph = "level", color = C.hot, title = row.text, titleColor = C.text,
			under = row.right or "", click = function() Shy.Notices.Open("toasts.level") end })
	end
end

local function Add(kind, row)
	if not row or not row.text then return end
	local rows = news[kind]
	if not rows then
		rows = { total = 0 }
		news[kind] = rows
	end
	table.insert(rows, 1, row)
	rows[KEEP + 1] = nil
	rows.total = rows.total + 1
	Post(kind)
	Say(kind, row, rows)
end

-- Loot

local function Item(link, quantity)
	quantity = Plain(quantity)
	local color, quality = Quality(Plain(link))
	return {
		icon = Plain(link) and C_Item.GetItemIconByID(link) or nil,
		text = ItemName(link),
		link = Link(link),
		color = color, quality = quality,
		right = quantity and quantity > 1 and ("x" .. quantity) or nil,
	}
end

local function Loot(_, event, ...)
	if event == "LOOT_ITEM_ROLL_WON" then
		local link, quantity = ...
		Add("loot", Item(link, quantity))
	elseif event == "SHOW_LOOT_TOAST" then
		local kind, link, quantity = ...
		if kind == "item" or kind == "currency" then
			Add("loot", Item(link, quantity))
		elseif kind == "money" and Plain(quantity) then
			Add("loot", { glyph = "coin", tint = C.alert, text = UI.Money(quantity) })
		end
	elseif event == "SHOW_LOOT_TOAST_UPGRADE" then
		local link, quantity = ...
		Add("loot", Item(link, quantity))
	elseif event == "SHOW_LOOT_TOAST_LEGENDARY_LOOTED" then
		Add("loot", Item((...), 1))
	end
end

-- A boss, and what it dropped for the group.

local function Boss(_, event, ...)
	if event == "BOSS_KILL" then
		local id, name = ...
		name = Plain(name)
		if not name then return end
		Add("boss", { glyph = "kill", tint = C.good, text = name, encounter = id, loot = {} })
	else
		local id, _, link, quantity, player, class = ...
		local _, instanceType = GetInstanceInfo()
		if instanceType ~= "party" and instanceType ~= "raid" then return end
		local boss
		for _, row in ipairs(news.boss or {}) do
			if row.encounter == id then
				boss = row
				break
			end
		end
		if not boss then return end
		local row = Item(link, quantity)
		if not row.text then return end
		row.indent = 1
		player = Plain(player)
		if player then
			row.right = Ambiguate(player, "short")
			local tone = Plain(class) and C_ClassColor.GetClassColor(class)
			if tone then row.rightColor = { tone:GetRGB() } end
		end
		boss.loot[#boss.loot + 1] = row
		Post("boss")
	end
end

-- Achievements: as the game toasts them, an achievement earned before on another character only when it
-- says so.

local function Feat(_, event, id, earnedBefore)
	if event ~= "ACHIEVEMENT_EARNED" then return end
	local _, name, points, _, _, _, _, _, flags, icon, _, isGuild = GetAchievementInfo(id)
	if not name then return end
	if not isGuild and earnedBefore and not FlagsUtil.IsSet(flags, ACHIEVEMENT_FLAGS_TOAST_ON_REPEAT_COMPLETION) then return end
	Add("feat", { icon = icon, text = Plain(name), right = points and points > 0 and tostring(points) or nil, rightColor = C.alert })
end

-- Recipes, mounts and pets learned.

local function Learned(_, event, id)
	if event == "NEW_RECIPE_LEARNED" then
		if not C_CVar.GetCVarBool("enableLearnedRecipeToasts") then return end
		Add("learned", { icon = C_Spell.GetSpellTexture(id), text = Plain(C_Spell.GetSpellName(id)), spell = id, right = "Recipe", rightColor = C.dim })
	elseif event == "NEW_MOUNT_ADDED" then
		local name, spell, icon = C_MountJournal.GetMountInfoByID(id)
		Add("learned", { icon = icon, text = Plain(name), spell = Plain(spell), right = "Mount", rightColor = C.dim })
	elseif event == "NEW_PET_ADDED" then
		local info = C_PetJournal.GetPetInfoTableByPetID(id)
		if info then Add("learned", { icon = info.icon, text = Plain(info.customName or info.name), right = "Pet", rightColor = C.dim }) end
	end
end

-- Level ups and what they bring: the game keeps these in a queue of its own, read off here as they come.
-- The level reached heads the notice; each spell it brings is a row of its own, as a spell (its card on
-- hover). A spell learned at any other time is a thing learned.

local function Toast(info)
	local TYPE = Enum.EventToastEventType
	local title, sub = Plain(info.title), Plain(info.subtitle)
	if sub == "" then sub = nil end
	local link = Link(info.link)
	local spell = link and tonumber(link:match("|Hspell:(%d+)"))
	if info.eventType == TYPE.LevelUp then
		if title and title ~= "" then Add("level", { head = true, icon = info.iconFileID, text = title, right = sub }) end
	elseif spell then
		local name = Plain(C_Spell.GetSpellName(spell)) or sub or title
		Add(info.eventType == TYPE.SpellLearned and "learned" or "level",
			{ icon = info.iconFileID, text = name, spell = spell, link = link, right = SpellWord(spell), rightColor = C.dim })
	elseif title and title ~= "" then
		Add("level", { icon = info.iconFileID, text = sub or title, link = link, right = sub and title or nil, rightColor = C.dim })
	end
end

local function Toasts()
	if EventToastManagerFrame:IsCurrentlyToasting() then return end
	local seen = {}
	for _ = 1, TOASTS_AT_ONCE do
		local info = C_EventToastManager.GetNextToastToDisplay()
		if not info or seen[info.eventToastID] then break end
		seen[info.eventToastID] = true
		Toast(info)
		C_EventToastManager.RemoveCurrentToast()
	end
end

local function Take()
	for name, events in pairs(TAKEN) do
		local frame = _G[name]
		if frame then
			taken[name] = taken[name] or {}
			for _, event in ipairs(events) do
				if frame:IsEventRegistered(event) then
					frame:UnregisterEvent(event)
					taken[name][event] = true
				end
			end
		end
	end
end

local function GiveBack()
	for name, events in pairs(taken) do
		local frame = _G[name]
		for event in pairs(events) do frame:RegisterEvent(event) end
		taken[name] = nil
	end
end

ns.Feature({
	id = "toasts",
	category = "System",
	title = "Alerts as notices",
	desc = "Loot, boss kills, achievements and level ups wait as notices up top instead of popping up mid-screen.",
	keywords = "alert alerts toast toasts popup banner boss loot achievement level up recipe mount pet notice notices",
	default = true,
	events = {
		LOOT_ITEM_ROLL_WON = Loot, SHOW_LOOT_TOAST = Loot, SHOW_LOOT_TOAST_UPGRADE = Loot, SHOW_LOOT_TOAST_LEGENDARY_LOOTED = Loot,
		BOSS_KILL = Boss, ENCOUNTER_LOOT_RECEIVED = Boss,
		ACHIEVEMENT_EARNED = Feat,
		NEW_RECIPE_LEARNED = Learned, NEW_MOUNT_ADDED = Learned, NEW_PET_ADDED = Learned,
		DISPLAY_EVENT_TOASTS = Toasts,
	},
	Enable = Take,
	Disable = function()
		GiveBack()
		ClearAll()
	end,
})

-- For tests and for the report: what is waiting, by kind.
-- (hold: how long a notice stands; nil keeps every one until it is cleared by hand.)
ns.Toasts = { news = news, taken = taken, Clear = Clear, ClearAll = ClearAll, hold = HOLD }
