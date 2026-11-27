-- Shy.Others: the addons of other people's this character runs, and those of them doing a job a Shy addon here
-- already does. Your addons, a window of its own, lists those at every login while any is on: each with a button
-- that turns it off (or back on) for this character at once, gone at the next reload. Until you keep them (Keep
-- these), it asks again: its × only puts it away till the next login.
--
-- What an addon does is read from what it says of itself: its title, its category and its notes. No addon is
-- known by name. One Shy works with (O.Beside) is never put forward.
--
--   Shy.Others.Beside(folder, by)   the addon in `folder` works with `by` (a Shy addon, or "Shy")
--   Shy.Others.List()      every one: { { name, title, notes, on, by, say, beside, members }, ... }, those a Shy
--                          addon does first. by: that Shy addon; members: its folders (its group, what needs it)
--   Shy.Others.Doubled(all)   those a Shy addon does, on and not kept (or switched this session); with `all` also
--                          those off or kept
--   Shy.Others.On(entry)   switched on for this character (as the game will load it)
--   Shy.Others.Switch(entry, on)   on or off for this character now, every folder of it, the game's list saved
--   Shy.Others.Moved(entry)   switched since this session began: the reload brings it in or takes it away
--   Shy.Others.Keep(entry)   left on: yours, never put forward again
--   Shy.Others.Pending()   anything switched this session
--   Shy.Others.Open(all)   the window: those due, or with `all` every one Shy does, kept or off (/shy addons)
--   Shy.Others.IsOpen()
--
-- Account-wide, by character: ShyCoreDB.addons[character] = { off = { [folder] = true } turned off here,
-- kept = { [name] = true } kept on with a Shy addon doing its job }.

local Shy = Shy
local P, UI = Shy.Profiles, Shy.UI
local C = UI.colors
local core = Shy.core
Shy.core.keep.addons = true

local O = {}
Shy.Others = O

-- The jobs a Shy addon does, the first that fits an addon is its. `words`: the start of a word in its title or
-- category (an addon's title split where its words run together). `phrases`: in its notes, which say more and
-- so must say it plainly. Each is a Lua pattern, lower case, and stands at the start of a word.
local JOBS = {
	{ by = "ShyCore", say = "Shy does all of this", phrases = { "ui replacement", "interface replacement", "complete ui", "ui overhaul" } },
	{ by = "ShyQuest", words = { "quest", "leveling", "levelling" },
		phrases = { "quest log", "quest tracker", "quest helper", "quest objectives", "leveling guide", "levelling guide" } },
	{ by = "ShyBags", words = { "bag", "inventory", "bank" }, phrases = { "your bags", "all bags", "all your bags", "one bag", "bags and bank", "bag and bank" } },
	{ by = "ShyAuction", words = { "auction" }, phrases = { "auction house" } },
	{ by = "ShyMaps", words = { "map", "world ?map", "atlas" }, phrases = { "world map", "fog of war", "dungeon maps?" } },
	{ by = "ShyCore", words = { "minimap button", "button bag" }, phrases = { "minimap buttons" } },
	{ by = "ShyChat", words = { "chat" }, phrases = { "chat frames?", "chat windows?", "chat tabs?", "channel names", "chat history" } },
	{ by = "ShyPlates", words = { "plate", "nameplate", "name plate" }, phrases = { "name ?plates?" } },
	{ by = "ShyFrames", words = { "unit ?frames?", "party ?frames?" }, phrases = { "unit frames?", "player frame", "target frame", "party frames?" } },
	{ by = "ShyTip", words = { "tooltip", "tip%f[%W]" } },
	{ by = "ShyThreat", words = { "threat", "aggro" }, phrases = { "threat meter", "who has aggro" } },
	{ by = "ShyDock", words = { "damage meter", "dps", "meter", "action ?bars?" }, phrases = { "damage meter", "dps meter", "action ?bars?" } },
	{ by = "ShyBuffs", words = { "buff ?frame", "buff ?bar", "aura ?frame" }, phrases = { "buffs and debuffs", "buff frames?", "your buffs" } },
	{ by = "ShyXP", words = { "xp%f[%W]", "xp ?bar", "experience" },
		phrases = { "xp bar", "experience bar", "xp per hour", "xp an hour", "time to level", "reputation bar" } },
	{ by = "ShyHits", words = { "combat text", "damage text" }, phrases = { "combat text", "floating damage", "damage numbers" } },
	{ by = "ShyGear", words = { "upgrade" }, phrases = { "upgrades? for", "best quest reward", "stat weights?" } },
	{ by = "ShyGroup", words = { "group finder", "lfg", "lfm" }, phrases = { "group finder", "looking for group", "find a group" } },
	{ by = "ShyRecap", words = { "death recap" }, phrases = { "death recap", "what killed you", "who killed you" } },
	{ by = "ShyMonitor", words = { "cpu", "profiler" }, phrases = { "addon cpu", "addon memory", "memory usage", "cpu usage" } },
	{ by = "ShyTweaks", words = { "auto ?repair", "junk" }, phrases = { "auto%-?repair", "sells? junk", "sells? gr[ae]y", "vendor junk", "skip gossip" } },
	{ by = "ShyWay", words = { "waypoint" }, phrases = { "waypoints?", "arrow to" } },
	{ by = "ShyFarm", phrases = { "gold per hour", "gold an hour", "loot tracker", "farming session" } },
	{ by = "ShySkin", words = { "skins?%f[%W]" }, phrases = { "reskins?", "skins? the game", "restyles?" } },
	{ by = "ShyKeys", words = { "keybind", "key ?binding" }, phrases = { "key ?bindings?", "keybinds?" } },
}

local beside = {}   -- folder -> what it works with
local loaded = {}   -- folder -> its switch as the session began
local touched = {}  -- folder -> switched by the player this session (what a reload is asked for)

function O.Beside(folder, by) beside[folder] = by end

-- An addon's words without the game's color and picture codes.
local function Plain(text)
	if type(text) ~= "string" then return "" end
	return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " "))
end

-- Its title without the version some put after it ("Name v1.2.3").
local function Titled(text)
	return (Plain(text):gsub("%s+[vV]?%d+%.[%d%.]*%s*$", ""))
end

local function Has(text, patterns)
	for _, pattern in ipairs(patterns or {}) do
		if text:find("%f[%w]" .. pattern) then return true end
	end
	return false
end

-- A number made from a folder's name: how the addons Shy knows by name are kept (Data/Others.lua), so no name ships.
-- Its name in lower case, each byte added to 31 times what came before, kept under 2^31 - 1.
function O.Hash(name)
	local h = 0
	name = name:lower()
	for i = 1, #name do h = (h * 31 + name:byte(i)) % 2147483647 end
	return h
end

-- A folder Shy knows by name: the job, while the Shy addon that does it is here.
local ALL = { by = "ShyCore", say = "Shy does all of this" }
local function Known(name)
	local by = Shy.OTHERS and Shy.OTHERS[O.Hash(name)]
	if by == "all" then return ALL end
	return by and Shy.addons[by:sub(4)] and { by = by } or nil
end

-- The Shy addon that does what this one does, while it is here: by what it says of itself.
local function Job(title, category, notes)
	local named = (title:gsub("(%l)(%u)", "%1 %2") .. " " .. category):lower()
	notes = notes:lower()
	for _, job in ipairs(JOBS) do
		if Shy.addons[job.by:sub(4)] and (Has(named, job.words) or Has(notes, job.phrases)) then return job end
	end
end

local function Me() return UnitGUID("player") end

local function On(name)
	local on = C_AddOns.GetAddOnEnableState(name, Me()) > Enum.AddOnEnableState.None
	if loaded[name] == nil then loaded[name] = on end
	return on
end

local function Book()
	local db = ShyCoreDB
	db.addons = db.addons or {}
	local me = P.Character()
	db.addons[me] = db.addons[me] or {}
	local book = db.addons[me]
	book.off, book.kept, book.with = book.off or {}, book.kept or {}, book.with or {}
	return book
end

-- Every addon of someone else's this character runs, or that was turned off here, one row a group (the game groups
-- an addon's own parts under it: its Group). One another needs to load goes with it when a Shy addon does its job,
-- and is left to that one when not (a library). Those a Shy addon does first, then the rest, each by title.
function O.List()
	local book = Book()
	local info, order = {}, {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local name, title, notes, _, _, security = C_AddOns.GetAddOnInfo(i)
		if name and security ~= "SECURE" then
			info[name] = { title = Titled(title), notes = Plain(notes), on = On(name), group = C_AddOns.GetAddOnMetadata(name, "Group") }
			order[#order + 1] = name
		end
	end
	-- The addon it is grouped under, else itself.
	local function Head(name)
		local group = info[name].group
		return (group and group ~= name and info[group]) and group or name
	end
	local entries, heads = {}, {}
	for _, name in ipairs(order) do
		local head, a = Head(name), info[name]
		if (a.on or book.off[name]) and not head:find("^Shy") then
			local entry = entries[head]
			if not entry and (info[head].on or book.off[head]) then
				local h = info[head]
				local category = Plain(C_AddOns.GetAddOnMetadata(head, "Category")) .. " " .. Plain(C_AddOns.GetAddOnMetadata(head, "X-Category"))
				entry = { name = head, title = h.title ~= "" and h.title or head, notes = h.notes, on = h.on, members = {} }
				entry.beside = beside[head]
				entry.job = not entry.beside and Job(entry.title, category, entry.notes) or nil
				entries[head] = entry
				heads[#heads + 1] = head
			end
			if entry then
				if name == head then table.insert(entry.members, 1, name) else entry.members[#entry.members + 1] = name end
			end
		end
	end
	-- Whose job each is: a folder of it Shy knows by name (the row then takes that one's title: a group may be headed
	-- by its shared parts), else what its head says of itself.
	for _, head in ipairs(heads) do
		local entry = entries[head]
		local job
		if not entry.beside then
			for _, name in ipairs(entry.members) do
				job = Known(name)
				if job then
					if name ~= head and info[name].title ~= "" then entry.title = info[name].title end
					break
				end
			end
		end
		job = job or entry.job
		entry.job = nil
		if job then entry.by, entry.say = job.by, job.say end
	end
	-- Who is there for whom, by group: one needs another to load, or is named for it (one of its parts in a folder of
	-- its own: "Bars_Skins" for "Bars").
	local neededBy, partsOf = {}, {}
	local function For(map, of, head)
		if of and of ~= head and entries[of] then
			map[of] = map[of] or {}
			map[of][head] = true
		end
	end
	for _, head in ipairs(heads) do
		for _, name in ipairs(entries[head].members) do
			for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do For(neededBy, info[dep] and Head(dep), head) end
			for part in name:gmatch("[^_%-]+") do
				if part ~= name and info[part] then For(partsOf, Head(part), head) end
			end
		end
	end
	-- Its parts go with it. A Shy addon doing its job, so does all that needs it. Not, and something else still
	-- needs it, it is a library: left to what needs it.
	local gone = {}
	local function Fold(entry, map)
		for _, other in ipairs(heads) do
			if map and map[other] and not gone[other] and other ~= entry.name then
				for _, name in ipairs(entries[other].members) do entry.members[#entry.members + 1] = name end
				gone[other] = true
			end
		end
	end
	for _, head in ipairs(heads) do
		local entry = entries[head]
		if not gone[head] then
			Fold(entry, partsOf[head])
			if entry.by then
				Fold(entry, neededBy[head])
			else
				for other in pairs(neededBy[head] or {}) do
					if not gone[other] then gone[head] = true end
				end
			end
		end
	end
	local list = {}
	for _, head in ipairs(heads) do
		if not gone[head] then list[#list + 1] = entries[head] end
	end
	table.sort(list, function(a, b)
		if (a.by ~= nil) ~= (b.by ~= nil) then return a.by ~= nil end
		return a.title:lower() < b.title:lower()
	end)
	return list
end

function O.On(entry) return On(entry.name) end

function O.Doubled(all)
	local book, out = Book(), {}
	for _, entry in ipairs(O.List()) do
		if entry.by and (all or O.Moved(entry) or (entry.on and not book.kept[entry.name])) then out[#out + 1] = entry end
	end
	return out
end

-- An addon that says it is a library: in its category, its title ("(lib)") or its folder ("Lib...", "!...").
local function Library(name)
	local title = Plain(C_AddOns.GetAddOnTitle(name)):lower()
	local kind = (Plain(C_AddOns.GetAddOnMetadata(name, "Category")) .. " " .. Plain(C_AddOns.GetAddOnMetadata(name, "X-Category"))):lower()
	return name:find("^!") ~= nil or name:lower():find("^lib") ~= nil or title:find("%(lib%)") ~= nil
		or title:find("%f[%w]lib%f[%W]") ~= nil or kind:find("librar") ~= nil
end

-- Another's addon here (not Blizzard's, not ours).
local function Theirs(name)
	if not (name and C_AddOns.DoesAddOnExist(name)) or name:find("^Shy") then return false end
	local _, _, _, _, _, security = C_AddOns.GetAddOnInfo(name)
	return security ~= "SECURE"
end

-- What an addon uses: all it needs to load, all the way down, and the libraries it may use.
local function Uses(entry)
	local out, seen = {}, {}
	for _, name in ipairs(entry.members) do seen[name] = true end
	local function Walk(name)
		local function Take(dep, library)
			if dep and not seen[dep] and Theirs(dep) and (not library or Library(dep)) then
				seen[dep] = true
				out[#out + 1] = dep
				Walk(dep)
			end
		end
		for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do Take(dep) end
		for _, dep in ipairs({ C_AddOns.GetAddOnOptionalDependencies(name) }) do Take(dep, true) end
	end
	for _, name in ipairs(entry.members) do Walk(name) end
	return out
end

-- What it used that nothing still on needs, turned off with it (kept in book.with, to come back with it).
-- moving: the player is switching it now (the reload is theirs to ask for).
local function Sweep(entry, book, me, moving)
	local leaving = {}
	for _, name in ipairs(entry.members) do leaving[name] = true end
	local uses = Uses(entry)
	for _, name in ipairs(uses) do leaving[name] = true end
	local still = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and not leaving[name] and On(name) then
			for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do still[dep] = true end
			for _, dep in ipairs({ C_AddOns.GetAddOnOptionalDependencies(name) }) do still[dep] = true end
		end
	end
	local with = book.with[entry.name] or {}
	local swept = false
	for _, name in ipairs(uses) do
		if not still[name] and On(name) then
			C_AddOns.DisableAddOn(name, me)
			book.off[name] = true
			with[#with + 1] = name
			swept = true
			if moving then touched[name] = true end
		end
	end
	if #with > 0 then book.with[entry.name] = with end
	return swept
end

function O.Switch(entry, on)
	local book, me = Book(), Me()
	local names = { unpack(entry.members) }
	if on then
		for _, name in ipairs(book.with[entry.name] or {}) do names[#names + 1] = name end
		book.with[entry.name] = nil
	end
	for _, name in ipairs(names) do
		On(name)   -- (what the session began with, read before it changes)
		touched[name] = true
		if on then
			C_AddOns.EnableAddOn(name, me)
			book.off[name] = nil
		else
			C_AddOns.DisableAddOn(name, me)
			book.off[name] = true
		end
	end
	if not on then Sweep(entry, book, me, true) end
	entry.on = on
	if on then book.kept[entry.name] = nil end
	C_AddOns.SaveAddOns()
end

function O.Moved(entry)
	local was = loaded[entry.name]
	return was ~= nil and was ~= On(entry.name)
end

function O.Keep(entry)
	Book().kept[entry.name] = true
end

function O.Pending()
	for name in pairs(touched) do
		if loaded[name] ~= On(name) then return true end
	end
	return false
end

-- The window

local K = {
	WIDTH = 460, PAD = 14, GAP = 6, TEXT = 12, SMALL = 11, ROW = 24, SWITCH = 76, BUTTON = 24, LEAST_BUTTON = 110,
	WAIT = 4,          -- seconds after logging in before it is asked
	AGAIN = 10,        -- seconds before asking again, while a fight or setup is in the way
	TRIES = 30,
}

local win, open, shown
local rows, made = {}, {}

-- Those left on are the player's: never put forward again.
local function KeepOn()
	for _, entry in ipairs(shown or {}) do
		if O.On(entry) then O.Keep(entry) end
	end
end

-- Closed, a reload is asked for when an addon was switched: it comes or goes then.
local function Close()
	open = false
	if win then Shy.HUD.Update(win) end
	if O.Pending() then Shy.Reload("Reload to finish switching your addons.") end
end

-- What the foot asks: keep them or turn them all off; the reload once one was switched; nothing left to decide.
local function Foot()
	if O.Pending() then return "reload" end
	for _, entry in ipairs(shown or {}) do
		if O.On(entry) and not Book().kept[entry.name] then return "decide" end
	end
	return "done"
end
local FEET = { decide = { "Keep these", "Turn all off" }, reload = { nil, "Reload" }, done = { nil, "Got it" } }

local function Refresh()
	for _, row in ipairs(rows) do
		local entry = row.entry
		local on, moved = O.On(entry), O.Moved(entry)
		if moved then
			row.by:SetText(on and "On after you reload" or "Off after you reload")
			UI.Ink(row.by, C.alert)
		else
			row.by:SetText(on and (entry.say or (entry.by .. " does this")) or "Off")
			UI.Ink(row.by, C.dim)
		end
		UI.Ink(row.name, on and C.text or C.dim)
		row.button:SetLabel(moved and "Undo" or on and "Turn off" or "Turn on")
	end
	local words = FEET[Foot()]
	win.keep:SetShown(words[1] ~= nil)
	if words[1] then win.keep:SetLabel(words[1]) end
	win.go:SetLabel(words[2])
end

local function Create()
	win = UI.Window({
		id = "shy.addons", name = "ShyAddonsWindow", title = "Your addons",
		width = K.WIDTH, height = 200,
		point = { "CENTER", "CENTER", 0, 60 }, strata = "DIALOG",
		shown = function() return open end,
		-- (closed by the ×, Esc or a loading screen: nothing decided; it asks again next time)
		onClose = function()
			if open then Close() end
		end,
		head = { size = "window", icon = core.mark, title = "Your addons" },
	})
	win.body = UI.Body(win)
	win.keep = UI.Button(win.body, "Keep these", K.LEAST_BUTTON, function()
		KeepOn()
		Close()
	end)
	win.keep:HookScript("OnEnter", function(self)
		UI.Tip(self, "Keep these", "Shy won't ask about them again. Type /shy addons to see them.", { side = "TOP" })
	end)
	win.keep:HookScript("OnLeave", function(self) UI.TipHide(self) end)
	win.go = UI.Button(win.body, "Turn all off", K.LEAST_BUTTON, function()
		local foot = Foot()
		if foot == "decide" then
			for _, entry in ipairs(shown) do
				if O.On(entry) then O.Switch(entry, false) end
			end
			Refresh()
			return
		end
		-- (Reloading after switching some: those left on were looked at, and kept.)
		if foot == "reload" then KeepOn() end
		Close()
	end)
	win.go:SetPrimary(true)
	win.go:SetPoint("BOTTOMRIGHT", win.body, "BOTTOMRIGHT", -K.PAD, K.PAD)
	win.keep:SetPoint("RIGHT", win.go, "LEFT", -K.GAP, 0)
end

-- A sentence, then a line an addon: its name, at its right the Shy addon that does its job and its button.
local function Lay()
	for _, region in ipairs(made) do region:Hide() end
	wipe(made)
	wipe(rows)
	local function Keep(region)
		made[#made + 1] = region
		return region
	end
	local body, inner = win.body, K.WIDTH - 2 * K.PAD
	local y = UI.HEAD.window.line + UI.LINE + K.PAD
	local say = Keep(UI.Words(body, UI.TextFont(K.TEXT), C.dim))
	say:SetJustifyV("TOP")
	say:SetWordWrap(true)
	say:SetWidth(inner)
	say:SetText("Shy already does what these do. Two addons doing one job can clash.")
	say:SetPoint("TOPLEFT", K.PAD, -y)
	y = y + math.ceil(say:GetStringHeight()) + K.GAP + 2
	for _, entry in ipairs(shown) do
		local name = Keep(UI.Text(body, entry.title, K.TEXT, false, C.text))
		name:SetPoint("LEFT", body, "TOPLEFT", K.PAD, -y - K.ROW / 2)
		local button = Keep(UI.Button(body, "Turn off", K.SWITCH, function()
			O.Switch(entry, not O.On(entry))
			Refresh()
		end))
		button:SetPoint("RIGHT", body, "TOPRIGHT", -K.PAD, -y - K.ROW / 2)
		local by = Keep(UI.Text(body, "", K.SMALL, false, C.dim))
		by:SetPoint("RIGHT", button, "LEFT", -K.GAP - 2, 0)
		rows[#rows + 1] = { name = name, button = button, by = by, entry = entry }
		y = y + K.ROW + 2
	end
	UI.BodyFit(win, K.WIDTH, y + K.GAP + K.BUTTON + K.PAD)
	Refresh()
end

-- Those due, or with `all` every one Shy does; none, nothing shown.
function O.Open(all)
	local list = O.Doubled(all)
	if #list == 0 then return false end
	if not win then Create() end
	shown = list
	Lay()
	open = true
	Shy.HUD.Update(win)
	win:Raise()
	return true
end

function O.IsOpen() return open == true end
function O.Window() return win, rows end

-- As you log in, every time while one is due: once the game has settled, out of a fight, the setup window put away
-- or done.
local tries = 0
local function Try()
	local setup = Shy.Setup
	local waiting = setup and (setup.IsOpen() or not (setup.Done() or (setup.Away and setup.Away())))
	if InCombatLockdown() or waiting then
		tries = tries + 1
		if tries < K.TRIES then C_Timer.After(K.AGAIN, Try) end
		return
	end
	O.Open()
end

-- At login, the switches as the game loaded them, and those turned off here that have left the folder forgotten.
-- Then the window, when one is due.
Shy:On("SHY_LOGIN", function()
	wipe(loaded)
	wipe(touched)
	tries = 0
	local book = Book()
	for name in pairs(book.off) do
		if not C_AddOns.DoesAddOnExist(name) then book.off[name] = nil end
	end
	-- (What one turned off here left behind, before it was swept with it: it goes at the next reload.)
	local swept = false
	for _, entry in ipairs(O.List()) do
		if not entry.on and book.off[entry.name] then swept = Sweep(entry, book, Me()) or swept end
	end
	if swept then C_AddOns.SaveAddOns() end
	C_Timer.After(K.WAIT, Try)
end)

Shy.Command("addons", "the addons Shy already does, to turn off", function()
	if not O.Open(true) then core:Print("none of your addons do what Shy does.") end
end)
