-- Forever's camp as route errands: a campfire's benefits while one burns near, and cooking aboard a ship.
--   By the fire: a campfire someone built nearby puts an aura on you (Data/Kit.lua, ns.data.camp.near).
--     While it is there, out of a fight, without the camp's benefits (or with under RENEW of them left),
--     the row asks you to sit by it: a minute sitting by a welcoming fire gives them for an hour (the
--     tent's rested experience among them, once an hour). Gone while you sit (the game's own aura counts
--     the minute) and once they are had.
--   Cooking aboard: on a boat, a zeppelin or the tram (Shy.Way.Riding), with Cooking, a way to build a fire (a
--     campfire kit in the bags, or the wood for the first one) and raw food a known recipe still raises
--     the skill with, the row names what to cook and the points it should bring; its click opens the
--     recipe.
-- Auras are read only out of a fight (they are secret in one). Nothing is cooked or built for you.

local ADDON, ns = ...
local T = ns.T
local R = ns.Route
local UI = Shy.UI
local C = UI.colors

local Camp = {}
ns.Camp = Camp

T.defaults.camp = { on = true }      -- the campfire and cooking aboard as rows on the card

local RENEW = 5 * 60         -- seconds of benefits left under which sitting again is asked
local SLIM = 0.3             -- a recipe less likely than this to raise the skill is not worth the food
local WORTH = 2              -- points of skill the food must be good for

local recipes                -- { spell, item, count, yellow, grey, auto, needs = { { id, count } } }
local fires = {}             -- campfire kits, by item
local put                    -- "Not now": no fire row until the fire is gone
local seen                   -- what the auras said last: "near:benefits:sitting"

local function Data()
	return ns.data.camp
end

local function Load()
	if recipes then return end
	recipes = {}
	for spell, text in pairs(ns.data.cook or {}) do
		local f = {}
		for field in (text .. "^"):gmatch("(.-)%^") do f[#f + 1] = field end
		local recipe = { spell = spell, item = tonumber(f[1]), count = tonumber(f[2]) or 1, yellow = tonumber(f[3]) or 0,
			grey = tonumber(f[4]) or 0, auto = f[5] == "a", needs = {} }
		for id, many in (f[6] or ""):gmatch("(%d+):(%d+)") do recipe.needs[#recipe.needs + 1] = { tonumber(id), tonumber(many) } end
		recipes[#recipes + 1] = recipe
	end
	table.sort(recipes, function(a, b) return a.yellow > b.yellow end)
	for id in ((Data() or {}).fires or ""):gmatch("%d+") do fires[tonumber(id)] = true end
end

-- An aura of the player's, by spell, out of a fight: the aura, false for none, nil when it can't be told.
local function Aura(spell)
	if InCombatLockdown() then return nil end
	local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
	if aura == nil then return false end
	if issecretvalue(aura) then return nil end
	return aura
end

-- Seconds an aura has left, or nil for one that doesn't run out.
local function Left(aura)
	local ends = aura.expirationTime
	if ends == nil or issecretvalue(ends) or ends == 0 then return nil end
	return ends - GetTime()
end

-- By the fire

local function Fire()
	local camp = Data()
	if not camp or not T.db.camp.on or UnitIsDeadOrGhost("player") or UnitOnTaxi("player") then return nil end
	local near, benefits, sitting = Aura(camp.near), Aura(camp.benefits), Aura(camp.sitting)
	seen = ("%s:%s:%s"):format(tostring(near and true), tostring(benefits and true), tostring(sitting and true))
	-- (Gone from the fire: "Not now" is over. In a fight it can't be told.)
	if near == false then put = nil end
	if not near then return nil end
	if put or sitting ~= false or benefits == nil then return nil end
	local left = benefits and Left(benefits)
	if benefits and (not left or left > RENEW) then return nil end
	local rested = Aura(camp.rested)
	local lines = { benefits and ("Your Camp Benefits run out in %d min"):format(math.max(1, math.ceil(left / 60)))
		or "Sit a minute for an hour of Camp Benefits" }
	if rested == false and not GameRulesUtil.IsPlayerAtEffectiveMaxLevel() then lines[2] = "You'll earn rested XP too" end
	return {
		title = "Sit by the campfire",
		lines = lines,
		caption = "CAMPFIRE NEARBY",
		strip = "Right here",
		mark = "home",
		first = true,
		menu = function(root)
			root:CreateButton("Not now", function()
				put = true
				ns.Refresh()
			end)
		end,
	}
end

-- Cooking aboard

local function Known(recipe)
	return recipe.auto or C_SpellBook.IsSpellKnown(recipe.spell)
end

-- What the bags can cook that still raises the skill: { recipe, count, points }, or nil.
function Camp.Cooking()
	local camp = Data()
	if not camp then return nil end
	local skill = C_SkillInfo.GetSkillLineInfoByID(camp.cooking)
	if not skill or (skill.rank or 0) <= 0 or skill.rank >= (skill.maxRank or 0) then return nil end
	Load()
	for _, recipe in ipairs(recipes) do
		local chance = ns.Aid and ns.Aid.Chance and ns.Aid.Chance(recipe, skill.rank) or 0
		if chance >= SLIM and Known(recipe) then
			local count = math.huge
			for _, need in ipairs(recipe.needs) do
				count = math.min(count, math.floor(C_Item.GetItemCount(need[1]) / need[2]))
			end
			if count > 0 and count < math.huge then
				local points = 0
				local at = skill.rank
				for _ = 1, count do
					if at >= skill.maxRank then break end
					local each = ns.Aid.Chance(recipe, at)
					points, at = points + each, at + each
				end
				if points >= WORTH then return { recipe = recipe, count = count, points = math.floor(points + 0.5) } end
			end
		end
	end
end

-- A fire can be built: a campfire kit in the bags, or what the first one is made of (its recipe comes with
-- the skill).
local function Buildable()
	Load()
	for id in pairs(fires) do
		if C_Item.GetItemCount(id) > 0 then return true end
	end
	local wood = Data().wood or ""
	if wood == "" then return false end
	for id, many in wood:gmatch("(%d+):(%d+)") do
		if C_Item.GetItemCount(tonumber(id)) < tonumber(many) then return false end
	end
	return true
end

local function Aboard()
	local camp = Data()
	if not camp or not T.db.camp.on or InCombatLockdown() then return nil end
	if not Shy.Way.Riding() then return nil end
	if not Buildable() then return nil end
	local cook = Camp.Cooking()
	if not cook then return nil end
	local recipe = cook.recipe
	local name = C_Item.GetItemNameByID(recipe.item) or "food"
	return {
		title = ("Cook %d %s"):format(cook.count * recipe.count, name),
		lines = { ("About %d Cooking point%s on the way"):format(cook.points, cook.points == 1 and "" or "s") },
		caption = "ABOARD  \194\183  COOKING",
		mark = "train",
		first = true,
		hint = "Open the recipe",
		click = function()
			if not InCombatLockdown() then C_TradeSkillUI.OpenRecipe(recipe.spell) end
		end,
		hover = function()
			local rows = {}
			for i, need in ipairs(recipe.needs) do
				rows[i] = { icon = C_Item.GetItemIconByID(need[1]), glyph = "bag", text = C_Item.GetItemNameByID(need[1]) or "",
					right = ("%d"):format(C_Item.GetItemCount(need[1])), rightColor = C.dim }
			end
			return { { title = "Goes in", rows = rows } }
		end,
	}
end

-- The auras change often: the route is asked again only when what they say for these rows differs from what
-- the route was last built with (Fire keeps that).
local events = CreateFrame("Frame")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(_, event)
	if not ns.char then return end
	-- (A change in the bags builds the route again already, ShyQuest.lua, cooking aboard among its errands.)
	if event == "BAG_UPDATE_DELAYED" then return end
	local camp = Data()
	if not camp or not T.db.camp.on or InCombatLockdown() then return end
	local now =("%s:%s:%s"):format(tostring(Aura(camp.near) and true), tostring(Aura(camp.benefits) and true),
		tostring(Aura(camp.sitting) and true))
	if now ~= seen then
		seen = now
		ns.RefreshRoute()
	end
end)

ns.CardSwitch("errands", function(root)
	root:CreateCheckbox("Campfire and cooking aboard", function() return T.db.camp.on end, function()
		T.db.camp.on = not T.db.camp.on
		ns.Apply()
	end)
end)

if R and R.AddErrand then
	R.AddErrand("camp", Fire, "Sitting by campfires")
	R.AddErrand("cook", Aboard, "Cooking aboard ship")
end
