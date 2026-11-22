-- Shy.Errors: every Lua error from any addon is kept in a bag instead of popping a window in the middle
-- of the screen, so a fight goes on and the errors are read later, as one block of text to copy.
--
--   Shy.Errors.Report()      -- the bag as text: the client, the addons loaded, then each error
--   Shy.Errors.EntryText(key)  -- one entry as text, ready to paste
--   Shy.Errors.Open()        -- the window: the entries on the left, the one picked on the right
--   Shy.Errors.CopyAll()     -- the report in the copy box
--   Shy.Errors.Read(key)     -- an entry looked at: no longer new
--   Shy.Errors.Remove(key)   -- one entry out of the bag
--   Shy.Errors.Clear()       -- empties the bag
--   Shy.Errors.Fresh()       -- how many entries nobody has looked at yet
--   Shy.Errors.List()        -- the entries, oldest first
--   Shy.Errors.Sorted()      -- the entries, the one seen last first
--   Shy.Errors.Popup()       -- true: errors also go to the game's own error window
--   Shy.Errors.SetPopup(on)
--
-- Bus: SHY_ERRORS (fresh, total) a frame after the bag changes, never from inside the error handler.
--
-- One entry per error: the same message from the same line is one entry with a count, so an error that
-- happens every frame is one line, not thousands. The bag keeps the most recent MAX entries, each with
-- its message, stack and locals cut to size, and lives in ShyCoreDB.errors for the account.
-- Blocked and forbidden calls of protected functions and the game's Lua warnings are kept too.
-- While the game's window is off, the game is still told of each new error once (its log keeps it),
-- but never while that window could show, and never again for a repeat: a thousand of them bring up
-- the game's "too many errors" dialog.

local Shy = Shy
local core = Shy.core

local E = {}
Shy.Errors = E

local MAX = 40            -- entries kept
local MESSAGE = 800       -- characters of a message
local STACK_LINES = 14    -- lines of a stack
local STACK = 2400        -- characters of a stack
local LOCALS = 1200       -- characters of the locals
local SECRET = "(a message the game hides from addons)"

-- The bag is the account's: it stays with every profile and survives a reset.
core.keep = core.keep or {}
core.keep.errors = true

local bag = { list = {}, session = 0 }   -- ShyCoreDB.errors once the core has loaded
local byKey = {}                         -- key -> entry
local busy = false                       -- inside the handler: an error in it is dropped
local pending = false                    -- SHY_ERRORS is on its way
local told = false                       -- the one chat line of a session was said
local previous                           -- the handler that was there before ours
local refused                            -- why the game would not take our handler

local function Cut(s, most)
	if #s > most then return s:sub(1, most) .. " ..." end
	return s
end

-- Protected strings in a dump (|K...|k) are kept as plain letters, as the game's own window does.
local function Plain(s)
	return (s:gsub("|([kK])", "%1"))
end

local function Text(v)
	if v == nil then return nil end
	if issecretvalue(v) then return SECRET end
	if type(v) == "string" then return v end
	local ok, s = pcall(tostring, v)
	if ok and type(s) == "string" and not issecretvalue(s) then return s end
	return "(an error that is not text)"
end

local function TrimStack(stack)
	if not stack or issecretvalue(stack) then return "" end
	local lines, n = {}, 0
	for line in stack:gmatch("[^\n]+") do
		n = n + 1
		if n > STACK_LINES then
			lines[#lines + 1] = "..."
			break
		end
		lines[#lines + 1] = line
	end
	return Cut(table.concat(lines, "\n"), STACK)
end

-- Where an error came from: the first addon named in its message, else in its stack.
local function Owner(message, stack)
	return message:match("AddOns[/\\]([%w_%-%.]+)[/\\]") or stack:match("AddOns[/\\]([%w_%-%.]+)[/\\]")
end

local function Version(addon)
	if not addon then return nil end
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, addon, "Version")
	if ok and type(version) == "string" and version ~= "" and not issecretvalue(version) then return version end
end

local function Where()
	local ok, zone, area = pcall(function() return GetRealZoneText(), GetSubZoneText() end)
	if not ok or type(zone) ~= "string" or issecretvalue(zone) then return nil end
	local place = zone
	if type(area) == "string" and not issecretvalue(area) and area ~= "" and area ~= zone then place = zone .. ", " .. area end
	local inside, name, kind, _, difficulty = pcall(GetInstanceInfo)
	if inside and type(kind) == "string" and not issecretvalue(kind) and kind ~= "none" and type(name) == "string" and not issecretvalue(name) then
		place = place .. " (in " .. name .. (type(difficulty) == "string" and difficulty ~= "" and not issecretvalue(difficulty) and (", " .. difficulty) or "") .. ")"
	end
	return place
end

-- A table's or a function's address changes from one error to the next: it is not part of what an error is.
local function KeyOf(kind, message, stack)
	local first = stack:match("^[^\n]*") or ""
	return kind .. "\n" .. message:gsub(":%s*%x%x%x%x%x%x%x%x+", ": ?") .. "\n" .. first
end

local function Index()
	wipe(byKey)
	for _, entry in ipairs(bag.list) do
		if entry.key then byKey[entry.key] = entry end
	end
end

-- The bag keeps the entries seen most recently.
local function Trim()
	while #bag.list > MAX do
		local oldest, at = nil, 1
		for i, entry in ipairs(bag.list) do
			if not oldest or (entry.last or 0) < (oldest.last or 0) then oldest, at = entry, i end
		end
		table.remove(bag.list, at)
		if oldest.key then byKey[oldest.key] = nil end
	end
end

local function Say()
	if told or InCombatLockdown() then return end
	told = true
	local latest
	for _, entry in ipairs(bag.list) do
		if entry.fresh and entry.kind ~= "warning" and (not latest or (entry.last or 0) >= (latest.last or 0)) then latest = entry end
	end
	if not latest then return end
	local from = latest.addon and (" from " .. latest.addon) or ""
	core:Print("caught an error" .. from .. ". Type |cffffd200/shy errors|r to see it.")
end

-- A frame later, out of the handler: whatever listens may draw, and an error of its own is just an error.
local function Soon()
	if pending then return end
	pending = true
	C_Timer.After(0, function()
		pending = false
		Say()
		Shy:Fire("SHY_ERRORS", E.Fresh(), #bag.list)
	end)
end

-- Into the bag: a new entry, or one more of one already there. True when it is new.
-- site: the stack line that tells this entry from others with the same message (default: the stack's first).
local function Put(kind, message, stack, locals, from, site)
	local key = KeyOf(kind, message, site or stack)
	local now = GetServerTime()
	local entry = byKey[key]
	if entry then
		entry.count = entry.count + 1
		entry.last = now
		-- Seen in the report and back in a later session: it wants looking at again.
		if not entry.fresh and entry.read ~= bag.session then entry.fresh = true end
		entry.lastSession = bag.session
		Soon()
		return false
	end
	local addon = from or Owner(message, stack)
	entry = {
		key = key, kind = kind, count = 1, first = now, last = now, session = bag.session, lastSession = bag.session,
		message = Cut(message, MESSAGE), stack = stack, locals = locals and Cut(Plain(locals), LOCALS) or nil,
		addon = addon, version = Version(addon), where = Where(), fresh = true,
	}
	bag.list[#bag.list + 1] = entry
	byKey[key] = entry
	Trim()
	Soon()
	return true
end

-- The handler. The stack is read here, in the handler itself, so the level counts from the error;
-- the rest runs under pcall.
local function Handler(message)
	if busy then return end
	busy = true
	local stack, locals, new = "", nil, false
	local height, errorHeight = GetCallstackHeight(), GetErrorCallstackHeight()
	local level = errorHeight and (height - (errorHeight - 1)) or 2
	if level < 2 or level > height then level = 2 end
	local raw = debugstack(level)
	local ok = pcall(function()
		local text = Text(message) or "(no message)"
		stack = TrimStack(raw)
		local key = KeyOf("error", text, stack)
		new = byKey[key] == nil
		if new then
			local dump = debuglocals(level + 2, true)
			if type(dump) == "string" and not issecretvalue(dump) then locals = dump end
		end
		new = Put("error", text, stack, locals)
	end)
	busy = false
	if not previous then return end
	-- The game's own handler, called from here so its stack level still counts from the error.
	if bag.popup or (not ok) or (new and not C_CVar.GetCVarBool("scriptErrors")) then
		previous(message)
	end
end

local function Install()
	local now = geterrorhandler()
	if now == Handler then return end
	previous = now
	local ok, err = pcall(seterrorhandler, Handler)
	if not ok then
		refused = Text(err)
		previous = nil
	end
end

Install()

-- Protected calls an addon was kept from, and the game's Lua warnings. A blocked or forbidden call is told
-- while it is being made, so the stack read here leads to the line that made it; each line is its own entry.
-- The game names a call it can't put a name to "UNKNOWN()": said here as a protected action.
local UNNAMED = "UNKNOWN()"
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:RegisterEvent("LUA_WARNING")
watch:RegisterEvent("PLAYER_LOGIN")
watch:RegisterEvent("PLAYER_REGEN_ENABLED")
watch:SetScript("OnEvent", function(_, event, a, b)
	if event == "PLAYER_LOGIN" then
		-- Whatever loaded after us and put a handler of its own in place is handed every error after ours.
		Install()
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		if not told and E.Fresh() > 0 then Say() end
		return
	end
	if busy then return end
	busy = true
	-- The stack from the call the game refused, and the level of the first addon line in it (its locals).
	local raw, at
	if event ~= "LUA_WARNING" then
		raw = debugstack(2)
		for level = 2, 6 do
			local line = debugstack(level, 1, 0)
			if type(line) == "string" and not issecretvalue(line) and line:find("AddOns[/\\]") then
				at = level
				break
			end
		end
	end
	pcall(function()
		if event == "LUA_WARNING" then
			Put("warning", Cut(Text(a) or "", MESSAGE), "")
		else
			local addon, what = Text(a) or "?", Text(b) or "?"
			local forbidden = event == "ADDON_ACTION_FORBIDDEN"
			local unnamed = what == UNNAMED
			local words
			if forbidden then
				words = unnamed and "%s is not allowed to take a protected action" or "%s is not allowed to call %s"
			else
				-- In a fight, the lockdown; out of one, a call the game allows only straight from a click or key press.
				local why = InCombatLockdown() and "in a fight" or "without a click or key press"
				words = (unnamed and "%s was blocked from a protected action " or "%s was blocked from calling %s ") .. why
			end
			local stack = TrimStack(raw)
			local site = stack:match("[^\n]*AddOns[/\\][^\n]*")
			if stack == "" then stack = "[" .. addon .. "]" end
			local kind = forbidden and "forbidden" or "blocked"
			local message = words:format(addon, what)
			local locals
			if at and byKey[KeyOf(kind, message, site or stack)] == nil then
				local dump = debuglocals(at + 2, true)
				if type(dump) == "string" and not issecretvalue(dump) and dump ~= "" then locals = dump end
			end
			Put(kind, message, stack, locals, addon, site)
		end
	end)
	busy = false
end)

-- What came before the core's saved table was ready joins what the bag kept.
Shy:On("SHY_ADDON_LOADED", function(a)
	if a ~= core then return end
	local saved = core.db.errors
	if type(saved) ~= "table" or type(saved.list) ~= "table" then saved = { list = {} } end
	saved.session = (tonumber(saved.session) or 0) + 1
	local early = bag.list
	bag = saved
	for _, entry in ipairs(bag.list) do entry.session = entry.session or bag.session end
	Index()
	for _, entry in ipairs(early) do
		local kept = byKey[entry.key]
		if kept then
			kept.count, kept.last, kept.fresh = kept.count + entry.count, entry.last, true
		else
			entry.session, entry.lastSession = bag.session, bag.session
			bag.list[#bag.list + 1] = entry
			byKey[entry.key] = entry
		end
	end
	Trim()
	core.db.errors = bag
	Shy.Hold("scriptErrors", bag.popup and "1" or "0")
	if #early > 0 or E.Fresh() > 0 then Soon() end
end)

function E.List()
	return bag.list
end

function E.Fresh()
	local n = 0
	for _, entry in ipairs(bag.list) do
		if entry.fresh and entry.kind ~= "warning" then n = n + 1 end
	end
	return n
end

function E.Popup()
	return bag.popup == true
end

function E.SetPopup(on)
	bag.popup = on and true or nil
	Shy.Hold("scriptErrors", on and "1" or "0")
	Soon()
end

function E.Clear()
	wipe(bag.list)
	wipe(byKey)
	Soon()
end

function E.Get(key)
	return byKey[key]
end

function E.Read(key)
	local entry = byKey[key]
	if not entry or not entry.fresh then return end
	entry.fresh = nil
	entry.read = bag.session
	Soon()
end

function E.Remove(key)
	local entry = byKey[key]
	if not entry then return end
	for i, each in ipairs(bag.list) do
		if each == entry then
			table.remove(bag.list, i)
			break
		end
	end
	byKey[key] = nil
	Soon()
end

-- The one seen last first; of two seen in the same second, the one caught later.
function E.Sorted()
	local list, at = {}, {}
	for i, entry in ipairs(bag.list) do
		list[i] = entry
		at[entry] = i
	end
	table.sort(list, function(a, b)
		if (a.last or 0) ~= (b.last or 0) then return (a.last or 0) > (b.last or 0) end
		return at[a] > at[b]
	end)
	return list
end

local function When(t)
	return t and date("%Y-%m-%d %H:%M:%S", t) or "?"
end

local KIND = { error = "Error", warning = "Warning", blocked = "Blocked", forbidden = "Forbidden" }

local function Loaded()
	local out = {}
	for i = 1, C_AddOns.GetNumAddOns() do
		local name = C_AddOns.GetAddOnInfo(i)
		if name and C_AddOns.IsAddOnLoaded(i) then
			out[#out + 1] = name .. " " .. (Version(name) or "?")
		end
	end
	return table.concat(out, ", ")
end

local function Client()
	local version, build, _, interface = GetBuildInfo()
	return ("Client: %s, build %s, interface %s"):format(tostring(version), tostring(build), tostring(interface))
end

local function From(entry)
	return entry.addon and (entry.addon .. (entry.version and (" " .. entry.version) or "")) or "unknown addon"
end

-- An entry's head line and what follows it, as the report has them.
local function Told(lines, entry, number)
	local head = ("%s from %s, %d %s, first %s (session %s), last %s"):format(KIND[entry.kind] or entry.kind, From(entry),
		entry.count, entry.count == 1 and "time" or "times", When(entry.first), tostring(entry.session), When(entry.last))
	if entry.where then head = head .. ", " .. entry.where end
	lines[#lines + 1] = number and (number .. ". " .. head) or head
	lines[#lines + 1] = entry.message
	if entry.stack and entry.stack ~= "" and entry.kind == "error" then
		lines[#lines + 1] = "Stack:"
		lines[#lines + 1] = entry.stack
	end
	if entry.locals and entry.locals ~= "" then
		lines[#lines + 1] = "Locals:"
		lines[#lines + 1] = entry.locals
	end
end

function E.Report()
	local lines = {
		Shy.Brand.FAMILY .. " error report",
		Client(),
		("Written %s, session %d. The game's error window: %s."):format(When(GetServerTime()), bag.session or 0, bag.popup and "on" or "off"),
		-- With the game's taint log on, this client reports errors that aren't.
		"Taint log: " .. (C_CVar.GetCVar("taintLog") or "not in this client"),
		"Addons: " .. Loaded(),
	}
	if refused then lines[#lines + 1] = "The game kept its own error handler: " .. refused end
	local list, times = {}, 0
	for _, entry in ipairs(bag.list) do
		list[#list + 1] = entry
		times = times + entry.count
	end
	-- The most recent last, where the copy box opens.
	table.sort(list, function(a, b) return (a.last or 0) < (b.last or 0) end)
	lines[#lines + 1] = ""
	if #list == 0 then
		lines[#lines + 1] = "No errors caught."
		return table.concat(lines, "\n")
	end
	lines[#lines + 1] = ("%d %s, %d %s in all."):format(#list, #list == 1 and "entry" or "entries", times, times == 1 and "time" or "times")
	for i, entry in ipairs(list) do
		lines[#lines + 1] = ""
		Told(lines, entry, i)
	end
	return table.concat(lines, "\n")
end

function E.EntryText(key)
	local entry = byKey[key]
	if not entry then return "" end
	local lines = { Shy.Brand.FAMILY .. " error", Client(), "" }
	Told(lines, entry)
	return table.concat(lines, "\n")
end

function E.CopyAll()
	Shy.UI.ShowCopyBox(Shy.Brand.FAMILY .. ": errors", E.Report())
end

-- The window: the entries down the left, newest first; the one picked on the right, whole. Built the
-- first time it opens, from the core's widgets, which load after this file.

local WIDTH, HEIGHT = 860, 520
local PAD = 12
local LIST = 300          -- the list's width
local ROW = 46            -- a row and the gap under it
local BAR = 44            -- the picked entry's head: its addon, and the buttons
local FACT = 70           -- a fact's label
local UI, C, B
local win, list, details, empty, head
local rows, facts = {}, {}
local open, picked = false, nil

local function Pipes(s)
	return (tostring(s or ""):gsub("|", "||"))
end

local function Ago(t)
	local d = GetServerTime() - (t or 0)
	if d < 60 then return "just now" end
	if d < 3600 then return math.floor(d / 60) .. " min ago" end
	if d < 86400 then return math.floor(d / 3600) .. " h ago" end
	return date("%b %d", t)
end

-- A row's line: the file and line, then what went wrong.
local function Short(entry)
	local first = entry.message:match("^[^\n]*") or ""
	local file, line, rest = first:match("([%w_%-%.]+%.lua):(%d+):%s*(.*)")
	if file then return file .. ":" .. line .. "  " .. rest end
	return first
end

-- A Shy addon has its own small icon and name; any other is its name.
local function Family(name)
	if not name then return nil end
	local a = Shy.addons[(name:gsub("^Shy", ""))]
	if a and a.name == name then return a end
end

local function Named(entry)
	local a = Family(entry.addon)
	local name = a and B.Name(a.suffix) or (entry.addon and Pipes(entry.addon)) or "Unknown addon"
	return name, a
end

-- A Shy addon's own small icon at `size`; any other addon's error the bug, at the size it is drawn for.
local function Badge(texture, entry, size, on)
	local a = Family(entry.addon)
	if a then
		texture:SetSize(size, size)
		Shy.Theme.Icon(texture, a.mark)
	else
		Shy.Theme.Plain(texture)
		texture:SetSize(14, 14)
		texture:SetTexture(Shy.MEDIA .. "GlyphBug")
		UI.Tint(texture, on and C.onPickDim or C.dim)
	end
end

-- The stack, its file:line parts in the light of the accent and the rest dim.
local function Stack(text)
	local hot, dim = "|cff" .. UI.Hex(C.hot), "|cff" .. UI.Hex(C.dim)
	local out = {}
	for line in Pipes(text):gmatch("[^\n]+") do
		local file, n, rest = line:match("^%[(.-)%]:(%d+):(.*)$")
		if file then
			file = file:gsub("^@?Interface[/\\]AddOns[/\\]", "")
			out[#out + 1] = hot .. file .. ":" .. n .. "|r" .. dim .. rest .. "|r"
		else
			out[#out + 1] = dim .. line .. "|r"
		end
	end
	return table.concat(out, "\n")
end

local function Para(parent, size, color)
	local fs = UI.Words(parent, UI.TextFont(size), color)
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	return fs
end

local Fill

local function Pick(key)
	picked = key
	E.Read(key)
	Fill()
end

-- The picked row wears the theme's picked face and the inks lifted to read on it.
local function Look(row)
	local on = row.key == picked
	UI.SetFill(row, on and C.pick or C.row)
	UI.SetBorder(row, (on or row.over) and C.hot or C.rowEdge)
	local entry = byKey[row.key]
	if not entry then return end
	row.name:SetText((Named(entry)))
	UI.Ink(row.name, on and C.onPick or C.text)
	UI.Ink(row.count, on and C.onPick or C.text)
	UI.Ink(row.what, on and C.onPickDim or C.dim)
	UI.Ink(row.when, on and C.onPickDim or C.dim)
	Badge(row.icon, entry, 16, on)
end

local function Row(i)
	local row = rows[i]
	if row then return row end
	row = CreateFrame("Button", nil, list.content)
	row:SetSize(LIST - 14, ROW - 4)
	row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
	UI.Skin(row, C.row, C.rowEdge)
	row.new = row:CreateTexture(nil, "ARTWORK")
	row.new:SetPoint("TOPLEFT", 2, -2)
	row.new:SetPoint("BOTTOMLEFT", 2, 2)
	row.new:SetWidth(3)
	UI.Paint(row.new, C.alert)
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(16, 16)
	row.icon:SetPoint("CENTER", row, "TOPLEFT", 18, -14)
	row.name = UI.Text(row, "", 13)
	row.name:SetPoint("TOPLEFT", 32, -7)
	row.name:SetWidth(LIST - 14 - 32 - 56)
	row.name:SetWordWrap(false)
	row.count = UI.Text(row, "", 12, false, C.text)
	row.count:SetPoint("TOPRIGHT", -8, -7)
	row.count:SetJustifyH("RIGHT")
	row.what = UI.Text(row, "", 11, false, C.dim)
	row.what:SetPoint("TOPLEFT", 32, -25)
	row.what:SetWidth(LIST - 14 - 32 - 70)
	row.what:SetWordWrap(false)
	row.when = UI.Text(row, "", 11, false, C.dim)
	row.when:SetPoint("TOPRIGHT", -8, -25)
	row.when:SetJustifyH("RIGHT")
	row:SetScript("OnClick", function(self) Pick(self.key) end)
	row:SetScript("OnEnter", function(self)
		self.over = true
		Look(self)
	end)
	row:SetScript("OnLeave", function(self)
		self.over = nil
		Look(self)
	end)
	rows[i] = row
	return row
end

-- The picked entry, laid down the right at `width`.
local function Show(entry, width)
	local name = Named(entry)
	Badge(head.icon, entry, 18)
	head.name:SetText(name .. (entry.version and ("  |cff" .. UI.Hex(C.dim) .. entry.version .. "|r") or ""))
	local d = details.content
	d:SetWidth(width - 14)
	local inner = width - 14
	d.message:SetWidth(inner)
	d.message:SetText(Pipes(entry.message))
	local y = d.message:GetStringHeight() + 14
	local seen = entry.count == 1 and "Once" or (entry.count .. " times")
	local said = {
		{ "Kind", KIND[entry.kind] or entry.kind },
		{ "Seen", seen },
		{ "First", When(entry.first) },
		{ "Last", When(entry.last) },
		{ "Session", tostring(entry.session or "?") .. (entry.session == bag.session and ", this one" or "") },
		{ "Where", entry.where and Pipes(entry.where) or "Not known" },
	}
	for i, fact in ipairs(said) do
		local f = facts[i]
		if not f then
			f = { label = UI.Text(d, "", 11, false, C.dim), value = Para(d, 12, C.text) }
			facts[i] = f
		end
		f.label:SetText(fact[1])
		f.label:ClearAllPoints()
		f.label:SetPoint("TOPLEFT", 0, -y - 1)
		f.value:SetWidth(inner - FACT)
		f.value:SetText(fact[2])
		f.value:ClearAllPoints()
		f.value:SetPoint("TOPLEFT", FACT, -y)
		y = y + math.max(14, f.value:GetStringHeight()) + 4
	end
	local function Block(title, body, text)
		local has = text and text ~= ""
		title:SetShown(has)
		body:SetShown(has)
		if not has then return end
		y = y + 12
		title:ClearAllPoints()
		title:SetPoint("TOPLEFT", 0, -y)
		y = y + 18
		body:SetWidth(inner)
		body:SetText(text)
		body:ClearAllPoints()
		body:SetPoint("TOPLEFT", 0, -y)
		y = y + body:GetStringHeight()
	end
	Block(d.stackTitle, d.stack, entry.kind == "error" and entry.stack ~= "" and Stack(entry.stack) or nil)
	Block(d.localsTitle, d.locals, entry.locals and Pipes(entry.locals) or nil)
	d:SetHeight(y + 8)
	details:Update()
end

function Fill()
	if not win or not open then return end
	local sorted = E.Sorted()
	local some = #sorted > 0
	if picked and not byKey[picked] then picked = nil end
	if not picked and some then
		picked = sorted[1].key
		E.Read(picked)
	end
	for i, entry in ipairs(sorted) do
		local row = Row(i)
		row.key = entry.key
		row.count:SetText(entry.count > 1 and ("\195\151" .. entry.count) or "")
		row.what:SetText(Pipes(Short(entry)))
		row.when:SetText(Ago(entry.last))
		row.new:SetShown(entry.fresh == true)
		Look(row)
		row:Show()
	end
	for i = #sorted + 1, #rows do rows[i]:Hide() end
	list.content:SetHeight(math.max(1, #sorted * ROW))
	list:Update()
	list:SetShown(some)
	details:SetShown(some)
	head:SetShown(some)
	empty:SetShown(not some)
	for _, b in ipairs(win.head.buttons) do b:SetUsable(some) end
	if some then Show(byKey[picked], details:GetWidth()) end
end

local function Lay(_, width, height)
	local bodyTop = UI.HEAD.window.line + UI.LINE + PAD
	list:SetSize(LIST, height - bodyTop - PAD)
	local right = width - LIST - PAD * 3
	head:SetWidth(right)
	details:SetSize(right, height - bodyTop - BAR - PAD)
	empty:SetWidth(width - 80)
	if open then Fill() end
end

local function Create()
	UI, C, B = Shy.UI, Shy.UI.colors, Shy.Brand
	local top = UI.HEAD.window.line + UI.LINE + PAD
	win = UI.Window({
		id = "shy.errors", name = "ShyErrorsWindow", title = "Errors",
		width = WIDTH, height = HEIGHT,
		point = { "CENTER", "CENTER", 0, 40 },
		shown = function() return open end,
		grip = { flow = Lay, min = { 700, 360 } },
		strata = "HIGH",
		onClose = function() open = false end,
		head = { size = "window", icon = Shy.MEDIA .. "ErrorsMark", title = "Errors",
			buttons = { { "Copy all", 84, function() E.CopyAll() end }, { "Clear all", 84, function() end } } },
	})
	UI.Twice(win.head.buttons[2], function() E.Clear() end)
	-- Everything under the header stands on the body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(win)

	list = UI.ScrollArea(body, LIST, HEIGHT - top - PAD)
	list:SetPoint("TOPLEFT", PAD, -top)

	-- The picked entry's head: its addon, and what can be done with it.
	head = CreateFrame("Frame", nil, body)
	head:SetPoint("TOPLEFT", PAD * 2 + LIST, -top)
	head:SetSize(WIDTH - LIST - PAD * 3, BAR - 10)
	head.icon = head:CreateTexture(nil, "ARTWORK")
	head.icon:SetSize(18, 18)
	head.icon:SetPoint("CENTER", head, "LEFT", 9, 0)
	head.name = UI.Text(head, "", 15, true)
	head.name:SetPoint("LEFT", head, "LEFT", 26, 0)
	head.name:SetWordWrap(false)
	local clear = UI.Button(head, "Clear", 70, function()
		local sorted = E.Sorted()
		for i, entry in ipairs(sorted) do
			if entry.key == picked then
				local after = sorted[i + 1] or sorted[i - 1]
				picked = after and after.key or nil
				E.Remove(entry.key)
				if picked then E.Read(picked) end
				break
			end
		end
		Fill()
	end)
	clear:SetPoint("RIGHT", 0, 0)
	local copy = UI.Button(head, "Copy", 70, function()
		if picked then Shy.UI.ShowCopyBox(Shy.Brand.FAMILY .. ": error", E.EntryText(picked)) end
	end)
	copy:SetPoint("RIGHT", clear, "LEFT", -8, 0)
	head.name:SetPoint("RIGHT", copy, "LEFT", -12, 0)
	head.copy, head.clear = copy, clear

	details = UI.ScrollArea(body, WIDTH - LIST - PAD * 3, HEIGHT - top - BAR - PAD)
	details:SetPoint("TOPLEFT", PAD * 2 + LIST, -top - BAR)
	local d = details.content
	d.message = Para(d, 13, C.text)
	d.message:SetPoint("TOPLEFT")
	d.stackTitle = UI.Text(d, "Stack", 12, true, C.dim)
	d.stack = Para(d, 12, C.text)
	d.localsTitle = UI.Text(d, "Locals", 12, true, C.dim)
	d.locals = Para(d, 11, C.dim)

	empty = UI.Text(body, "No errors caught.", 13, false, C.dim)
	empty:SetPoint("CENTER", 0, -10)
	empty:SetJustifyH("CENTER")

	Lay(win, WIDTH, HEIGHT)
	Shy:On("SHY_ERRORS", Fill)
	Shy:On("SHY_THEME", Fill)
end

function E.Open()
	if not win then Create() end
	open = true
	Shy.HUD.Update(win)
	win:Raise()
	Fill()
end

function E.Close()
	open = false
	if win then Shy.HUD.Update(win) end
end

-- The window as it is, for the tests.
function E.Window()
	return win, rows, picked, head, empty, details
end

-- /shy's commands are the hub's, which loads after this file.
Shy:On("SHY_ADDON_LOADED", function(a)
	if a ~= core or not Shy.Command then return end
	Shy.Command("errors", "the addon errors caught so far", function() E.Open() end)
	Shy.Command("errors clear", nil, function()
		E.Clear()
		core:Print("errors cleared.")
	end)
	-- One error on purpose, to see the bag at work.
	Shy.Command("errors test", nil, function()
		geterrorhandler()("A test error, raised by /shy errors test.")
	end)
end)
