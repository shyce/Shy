-- Staying alive: what is dangerous where the route leads, what to drink when health runs low, and air.
--   Danger: hostile elites, rares and creatures well above the player whose spawns lie within REACH
--     of the leading stop are named under it on the card (ns.cardNotes), the same ones tooltips flag
--     (Hover.lua, H.Danger). Spawns come from the data. Hostile means no title, no quests and no
--     side, or the other side's. Careful play only, and off with tooltips' "Warn about dangerous
--     creatures".
--   Low health: ShyCore's alert (Shy.Alarm) under the character, with the best healing in the bags
--     (a healthstone, a potion, a bandage), off cooldown first. Health is secret to addons, so the
--     game evaluates it on a curve and the alert's strength is set from that. It fades in under LOW
--     of full health with nothing read.
--   Air and fatigue: the game's mirror timers. Under COMING seconds of breath, or whenever fatigue
--     drains, the alert warns over the head in amber. Under AIR it turns red and flies down under
--     the character. It counts the seconds down, with its weave full when it first shows.
-- Careful play (the hardcore route, or a hardcore realm) is stricter, never louder: more creatures
-- count, the reach is wider and the alert comes sooner. Nothing here plays a sound or writes in chat.

local ADDON, ns = ...
local T = ns.T
local D, L, W = ns.Data, ns.Log, ns.World
local UI = Shy.UI

local Safety = {}
ns.Safety = Safety

T.defaults.safety = { on = true }    -- the low health and air alerts

local UNITS = 9999
local REACH, REACH_CAREFUL = 120, 200      -- yards from the leading stop
local STEEP_CAREFUL = 4                    -- careful: levels above the player that count
Safety.STEEP = 5                           -- ... and otherwise: well above, a danger in any play
Safety.SPAN = 5                            -- levels a creature's range may span and still be its own
local NAMED = 1                            -- creatures named in the note; the rest are counted
local LOW, LOW_CAREFUL = 0.35, 0.5         -- share of health under which the alert shows
local FADE = 0.1                           -- ... fading in over this much more
local COMING, COMING_CAREFUL = 40, 60      -- seconds of breath under which it warns (amber, over the head)
local AIR, AIR_CAREFUL = 20, 30            -- ... and is urgent (red, down under the character)

-- Careful play: the hardcore route or a hardcore realm.
function Safety.Careful()
	return T.db.guide.hardcore == true or C_GameRules.IsHardcoreActive()
end

-- Danger near the lead

local maps = {}              -- map -> { { npc, north, west }, ... } the hostile creatures' spawns on it

local function Hostile(npc)
	if npc.title or (npc.gives and npc.gives[1]) or (npc.takes and npc.takes[1]) then return false end
	return npc.side == "" or not L.Friendly(npc)
end

-- A map's world rectangle, for placing every spawn on it with two lookups.
local function Rect(map)
	local continent, n0, w0 = W.ToWorld(map, 0, 0)
	local _, n1, w1 = W.ToWorld(map, UNITS, UNITS)
	if not continent or not n1 then return nil end
	return n0, w0, n1 - n0, w1 - w0
end

-- Every hostile creature's spawn on a map, read from the data once.
local function OnMap(map)
	local list = maps[map]
	if list then return list end
	list = {}
	maps[map] = list
	local n0, w0, dn, dw = Rect(map)
	if not n0 then return list end
	local pattern = "[%^;]" .. map .. "[@ah:]"
	for id, text in pairs(ns.data.npcs or {}) do
		if text:find(pattern) then
			local npc = D.Npc(id)
			if npc and npc.maxLevel > 0 and Hostile(npc) then
				for _, place in ipairs(D.Ground(npc)) do
					if place.map == map and not place.dungeon then
						local points = place.points
						for i = 1, #points - 1, 2 do
							list[#list + 1] = { npc = npc, north = n0 + dn * points[i + 1] / UNITS, west = w0 + dw * points[i] / UNITS }
						end
					end
				end
			end
		end
	end
	-- Each spawn by the square of the grid it stands in (REACH_CAREFUL a side), by its place in the list.
	local cells = {}
	for index, spawn in ipairs(list) do
		local key = math.floor(spawn.north / REACH_CAREFUL) .. ":" .. math.floor(spawn.west / REACH_CAREFUL)
		local cell = cells[key]
		if not cell then
			cell = {}
			cells[key] = cell
		end
		cell[#cell + 1] = index
	end
	list.cells = cells
	return list
end

-- The spawns of a map within `reach` (REACH_CAREFUL at most) of a place could be: those in the nine squares
-- round it, in the list's own order.
local function Round(list, north, west)
	local out = {}
	if not list.cells then return out end
	local row, column = math.floor(north / REACH_CAREFUL), math.floor(west / REACH_CAREFUL)
	for dn = -1, 1 do
		for dw = -1, 1 do
			for _, index in ipairs(list.cells[(row + dn) .. ":" .. (column + dw)] or {}) do out[#out + 1] = index end
		end
	end
	table.sort(out)
	for i, index in ipairs(out) do out[i] = list[index] end
	return out
end

-- How dangerous a creature is to the player: { kind, why, above } or nil.
local function Threat(npc, careful)
	local danger = ns.Hover and ns.Hover.Danger and ns.Hover.Danger(npc.id)
	-- (A span wider than SPAN levels is the data's guess, not the creature's: a cat of 7 to 30. Its low end.)
	local level = npc.maxLevel
	if npc.minLevel and level - npc.minLevel > Safety.SPAN then level = npc.minLevel end
	local above = level - L.Level()
	-- Only what is really dangerous: an elite, or a creature well above you (a ravasaur pack), not every
	-- creature a level or two up near the stop.
	if not danger and above >= (careful and STEEP_CAREFUL or Safety.STEEP) then
		danger = { kind = "", why = ("%d levels above you"):format(above) }
	end
	if danger then danger.above = above end
	return danger
end

-- The dangerous creatures within reach of a place, the worst first: { { npc, danger } }.
function Safety.Near(map, north, west, careful)
	local reach, found, seen = careful and REACH_CAREFUL or REACH, {}, {}
	for _, spawn in ipairs(Round(OnMap(map), north, west)) do
		local npc = spawn.npc
		local apart = not seen[npc] and W.Between(north, west, spawn.north, spawn.west)
		if apart and apart <= reach then
			local danger = Threat(npc, careful)
			-- (Only above you, no elite or rare: it counts at the stop itself, REACH, not the careful reach.)
			if danger and (danger.kind ~= "" or apart <= REACH) then
				seen[npc] = true
				found[#found + 1] = { npc = npc, danger = danger }
			end
		end
	end
	table.sort(found, function(a, b)
		local ae, be = a.danger.kind ~= "", b.danger.kind ~= ""
		if ae ~= be then return ae end
		if a.danger.above ~= b.danger.above then return a.danger.above > b.danger.above end
		return a.npc.name < b.npc.name
	end)
	return found
end

-- The hostile creatures `keep(npc)` picks whose spawns lie within `reach` yards (REACH_CAREFUL at most) of a way,
-- in Data.lua's places format: each once, in the order the way meets them.
function Safety.Along(places, reach, keep)
	local found, seen = {}, {}
	local function Look(map, north, west)
		for _, spawn in ipairs(Round(OnMap(map), north, west)) do
			local npc = spawn.npc
			if not seen[npc] and W.Between(north, west, spawn.north, spawn.west) <= reach and keep(npc) then
				seen[npc] = true
				found[#found + 1] = npc
			end
		end
	end
	for _, place in ipairs(places) do
		local points, last = place.points, nil
		for i = 1, #points - 1, 2 do
			local continent, north, west = W.ToWorld(place.map, points[i], points[i + 1])
			if continent and north then
				-- Looked at every `reach` yards along the way, so nothing between two points is missed.
				local steps = last and math.max(1, math.ceil(W.Between(last[1], last[2], north, west) / reach)) or 1
				for step = last and 1 or steps, steps do
					local share = step / steps
					Look(place.map, last and last[1] + (north - last[1]) * share or north, last and last[2] + (west - last[2]) * share or west)
				end
				last = { north, west }
			end
		end
	end
	return found
end

local said = {}              -- the note last worked out: { key, text }

local function Note(stop)
	if not T.db.hover.careful or stop.kind == "errand" or not stop.map or not stop.north then return nil end
	-- Careful play only, as the tooltips and the chat warning are.
	local careful = Safety.Careful()
	if not careful then return nil end
	local key = ("%d:%d:%d:%d:%s"):format(stop.map, stop.x or 0, stop.y or 0, L.Level(), tostring(careful))
	if said.key ~= key then
		local near = Safety.Near(stop.map, stop.north, stop.west, careful)
		local text
		if #near > 0 then
			local first = near[1]
			text = ("Careful: %s, %s"):format(first.npc.name, first.danger.why)
			if #near > NAMED then text = ("%s, and %d more"):format(text, #near - NAMED) end
		end
		said = { key = key, text = text }
	end
	if said.text then return said.text, nil, "kill" end
end

-- The alerts: low health and air

local HEALTH, AIR_ALARM = "shyquest.health", "shyquest.air"   -- the two alerts (Shy.Alarm)
local curve, curveFor
local pick                   -- the item the alert offers: { id, icon, name }
local timer                  -- the mirror timer counting down: { name, label, max, scale }

local function Curve()
	local careful = Safety.Careful()
	if curve and curveFor == careful then return curve end
	local low = careful and LOW_CAREFUL or LOW
	curve, curveFor = C_CurveUtil.CreateCurve(), careful
	curve:SetType(Enum.LuaCurveType.Linear)
	curve:AddPoint(0, 1)
	curve:AddPoint(low, 1)
	curve:AddPoint(low + FADE, 0)
	curve:AddPoint(1, 0)
	return curve
end

-- Your health as a share (0 to 1), as the game evaluates it: a secret, for the alert's weave to show as is.
local whole
local function Whole()
	if not whole then
		whole = C_CurveUtil.CreateCurve()
		whole:SetType(Enum.LuaCurveType.Linear)
		whole:AddPoint(0, 0)
		whole:AddPoint(1, 1)
	end
	return UnitHealthPercent("player", true, whole)
end

-- What heals, by kind: healthstones first, then potions, then bandages, each strongest first.
local healing
local function Healing()
	if healing then return healing end
	local stones, potions, bandages = {}, {}, {}
	for id in pairs(ns.data.stones or {}) do stones[#stones + 1] = { id = id, amount = ns.data.stones[id] } end
	for id in pairs(ns.data.supplies or {}) do
		local item = ns.Supplies and ns.Supplies.Item(id)
		if item and item.potion and item.heal > 0 then potions[#potions + 1] = { id = id, amount = item.heal } end
	end
	for _, text in pairs(ns.data.aid or {}) do
		local kind, item = text:match("^(%a)%^(%d+)")
		if kind == "b" then bandages[#bandages + 1] = { id = tonumber(item), amount = tonumber(item) } end
	end
	healing = {}
	for _, list in ipairs({ stones, potions, bandages }) do
		table.sort(list, function(a, b) return a.amount > b.amount end)
		for _, each in ipairs(list) do healing[#healing + 1] = each.id end
	end
	return healing
end

local function Ready(id)
	local start, duration = C_Item.GetItemCooldown(id)
	return not start or start == 0 or (duration or 0) <= 1.5
end

-- What of it is in the bags, best first: read again only when the bags change (BAG_UPDATE_DELAYED), not at
-- every change of health.
local carried
function Safety.Carried()
	if not carried then
		carried = {}
		for _, id in ipairs(Healing()) do
			if C_Item.GetItemCount(id) > 0 then carried[#carried + 1] = id end
		end
	end
	return carried
end

-- The item to offer: the first that is carried and usable, off cooldown before on it.
function Safety.Pick()
	local later
	for _, id in ipairs(Safety.Carried()) do
		if C_Item.IsUsableItem(id) then
			if Ready(id) then return id end
			later = later or id
		end
	end
	return later
end

local function Shown()
	return T.db.safety.on and not UnitIsDeadOrGhost("player")
end

-- Low health: the alert under your character, with the best healing you carry (grey while it cools down)
-- and how many. It is raised whenever there is something to drink; its strength is the curve on your
-- health, so it shows only as health runs low, and never flies (it could come again and again in a fight).
local function Health()
	local Alarm = Shy.Alarm
	local id = Shown() and Safety.Pick() or nil
	if not id then
		Alarm.Clear(HEALTH)
		return
	end
	if not pick or pick.id ~= id then
		pick = { id = id, icon = C_Item.GetItemIconByID(id), name = C_Item.GetItemNameByID(id) or "" }
	end
	local count = C_Item.GetItemCount(id)
	-- (One alert, raised again with what changed in it: every change of health raises it.)
	local def = pick.def
	if not def then
		def = { priority = 10, title = "LOW HEALTH", alpha = function() return UnitHealthPercent("player", true, Curve()) end }
		pick.def = def
	end
	def.under, def.icon, def.dim, def.right, def.share = pick.name, pick.icon, not Ready(id), count > 1 and tostring(count) or nil, Whole()
	Alarm.Raise(HEALTH, def)
end

local function Seconds()
	if not timer then return nil end
	local left = GetMirrorTimerProgress(timer.name)
	if left == nil then return nil end
	return left / 1000
end

-- Air or fatigue running out: the urgent alert (it takes the head and flies down under your character),
-- counting down while a timer drains under its mark.
local function Air()
	local Alarm = Shy.Alarm
	-- Breath and fatigue only: feign death's timer is one you started yourself.
	local danger = timer and (timer.name == "BREATH" or timer.name == "EXHAUSTION")
	local left = Shown() and danger and timer.scale < 0 and Seconds()
	local careful = Safety.Careful()
	local breath = timer and timer.name == "BREATH"
	-- Breath warns under COMING and is urgent under AIR; fatigue warns while it drains and is urgent under
	-- AIR too.
	local coming = breath and (careful and COMING_CAREFUL or COMING) or math.huge
	if not (left and left <= coming) then
		Alarm.Clear(AIR_ALARM)
		return
	end
	local urgent = left <= (careful and AIR_CAREFUL or AIR)
	-- The weave is full as it first shows and runs out with the air, so its length tells the time left.
	local span = breath and coming or timer.max / 1000
	Alarm.Raise(AIR_ALARM, {
		priority = 20, warn = not urgent, fly = urgent, covers = timer.name, title = (timer.label or ""):upper(),
		right = ("%ds"):format(math.max(0, math.ceil(left))),
		share = math.max(0, math.min(1, left / span)),
	})
end

local built = false
local function Build()
	built = true
end

function Safety.Apply()
	if not built then return end
	Air()
	Health()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, name, value, maxValue, scale, _, label)
	if event == "PLAYER_LOGIN" then
		Build()
		for _, each in ipairs({ "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
			"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MIRROR_TIMER_PAUSE" }) do
			self:RegisterEvent(each)
		end
		self:RegisterUnitEvent("UNIT_HEALTH", "player")
		self:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
		Safety.Apply()
		return
	end
	-- (Health changing says nothing of the air, nor of what you carry: the alert is raised again, no more.)
	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		Health()
		return
	end
	if event == "BAG_UPDATE_DELAYED" then carried = nil end
	if event == "MIRROR_TIMER_START" then
		timer = { name = name, label = label or name, max = math.max(1, maxValue or 1), scale = scale or -1 }
	elseif event == "MIRROR_TIMER_STOP" then
		if timer and timer.name == name then timer = nil end
	elseif event == "MIRROR_TIMER_PAUSE" then
		if timer and timer.name == name then timer.scale = value and value > 0 and 0 or -1 end
	end
	-- The count down is looked at while a timer runs.
	if event:find("^MIRROR_TIMER") then
		local since = 0
		self:SetScript("OnUpdate", timer and function(_, elapsed)
			since = since + elapsed
			if since < 0.1 then return end
			since = 0
			Air()
		end or nil)
	end
	Air()
	Health()
end)

ns.OnApply(function() Safety.Apply() end)

ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, Note)

-- Settings: the alerts, the stops the route adds by itself, and what a window can do by itself (off unless asked for).
local function Petted()
	local _, class = UnitClass("player")
	return class == "HUNTER" or class == "WARLOCK"
end
-- Read when it is used: nothing on screen to draw again.
local function AtUse() end

T:Settings({
	{ section = "On the road" },
	{ key = "safety.on", label = "Health and breath alerts", words = "healthstone potion bandage drowning",
		desc = "Low on health, your healthstone, potion or bandage shows under your character. Low on breath, a warning counts it down." },

	{ section = "Stops added for you" },
	{ key = "flights.on", label = "Flight paths", words = "errand flight master",
		desc = "A flight master you haven't met becomes a stop when it's on your way." },
	{ key = "hearth.on", label = "Hearthstone", words = "errand inn",
		desc = "Hearthing becomes a step when it saves you time." },
	{ key = "train.on", label = "Class trainer", words = "errand spells",
		desc = "Your trainer becomes a stop when you have spells to learn." },
	{ key = "weapons.on", label = "Weapon master", words = "errand skill",
		desc = "A weapon master becomes a stop when there's a weapon to learn." },
	{ key = "stash.take", label = "Bank and mailbox", words = "errand quest items",
		desc = "Your bank or mailbox becomes a stop when it holds something a quest needs." },
	{ key = "camp.on", label = "Campfires and cooking", words = "errand boat",
		desc = "Reminds you to sit by campfires, and to cook on boat rides." },
	{ key = "pets.on", label = "Your pet", words = "errand hunter warlock beast training", shown = Petted,
		desc = "Your pet's trainer, its new skills and your class's pet quests become stops." },
	{ key = "legacy.on", label = "Legacy points", words = "suggestion",
		desc = "The quest window tells you when you have Legacy points to spend." },

	{ section = "Done for you" },
	{ key = "supplies.auto", label = "Buy what you need", words = "vendor auto buy food water reagents", apply = AtUse,
		desc = "Opening a vendor buys what your quests need and the food, water and reagents you're short on. Hold Shift to skip it." },
	{ key = "train.auto", label = "Train at your trainer", words = "auto learn spells", apply = AtUse,
		desc = "Opening your class trainer learns every spell you can afford. Hold Shift to skip it." },
	{ key = "stash.auto", label = "Take quest items out", words = "bank withdraw",
		desc = "Opening your bank takes out what your quests need. Hold Shift to skip it." },
	{ key = "stash.autoAway", label = "Store what can wait", words = "bank deposit",
		desc = "Opening your bank also puts away what no quest needs for a while. Hold Shift to skip it." },
})
