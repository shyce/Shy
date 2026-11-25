-- Click casting: a click on any of these unit frames, or a key pressed while the mouse is on one, casts a
-- spell on whoever is in it, and your target stays yours. A healer's whole job on the grid: see who is low, act.
--
-- A binding is an input and what it does, kept by class (T.db.clicks[class][input] = what).
--   input   a mouse button, the first five, with any keys held: "1", "shift-1", "alt-ctrl-2" (the keys in the
--           game's order: alt, ctrl, shift)
--           anything else, with any keys held: "key:F", "key:CTRL-SHIFT-1", "key:BUTTON6" (a key, or a mouse
--           button past the fifth, in the game's own binding words)
--   what    a spell's name (its highest rank you know, whatever you learn later), a spell's ID (that rank and no
--           other: a low rank kept for its cost), "target", or "menu" (a mouse click only)
-- Any spell in your book can be bound: on a friend's frame a heal, on your target's target a curse.
--
-- The frames are secure, so everything is set out of a fight (ns.AfterCombat):
--   a mouse click   is the frame's own attributes ("shift-type1" = "spell", "shift-spell1"): the game casts, on
--                   the frame's unit. An input with no binding does what it always did, but Mouse 3 to 5:
--                   the frame would swallow them, so they press what their key does on your bars (C.Through).
--   a key           can't be an attribute of the frame. Each has a secure button of its own (KEYS.helpers); as
--                   the mouse comes onto a frame, a snippet of the game's restricted code hands that frame's
--                   unit to them and binds the keys to them, for as long as the mouse is there (ENTER, LEAVE).
--                   Off the frames the keys are whatever they always were.
-- With "Cast on press" a bound click acts as the button goes down. A button that can open the menu (the right
-- one, or any bound to it) stays on its release: a menu opened on the press would take the release as a pick.
-- A key acts on its press or its release as the game's own action bars do.

local ADDON, ns = ...
local T, F = ns.T, ns.Frames
local UI = Shy.UI

local C = {}
ns.Clicks = C

C.ICON = "Interface\\AddOns\\ShyFrames\\Media\\Click"   -- a pointer clicking: the spellbook's tab, the window's head

local MOUSE = { LeftButton = "1", RightButton = "2", MiddleButton = "3", Button4 = "4", Button5 = "5" }
local CLICK = { ["1"] = "LeftButton", ["2"] = "RightButton", ["3"] = "MiddleButton", ["4"] = "Button4", ["5"] = "Button5" }
local MOUSE_NAME = { ["1"] = "Left click", ["2"] = "Right click", ["3"] = "Middle click", ["4"] = "Button 4", ["5"] = "Button 5" }
local DEFAULT = { ["1"] = "target", ["2"] = "menu" }     -- what a button does with no binding, whatever is held
local KINDS = { target = "target", menu = "togglemenu" } -- a binding that is no spell -> the button's type
local NAMES = { target = "Target", menu = "Menu" }
-- Their pictures, in the make of click casting's own: wherever a spell would show its icon, they show theirs.
local PICTURES = { target = "Interface\\AddOns\\ShyFrames\\Media\\ClickTarget", menu = "Interface\\AddOns\\ShyFrames\\Media\\ClickMenu" }

-- The picture of what a binding does: a spell's icon, or targeting's or the menu's own. With nothing asked for,
-- click casting's.
function C.Picture(what)
	if what == nil then return C.ICON end
	return PICTURES[what] or C_Spell.GetSpellTexture(what)
end
-- Keys that are no binding of their own: the ones held with another, and what the game keeps.
local NO_KEY = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true,
	ESCAPE = true, PRINTSCREEN = true, UNKNOWN = true }
local KEY = "key:"

-- Your class's bindings: input -> what it does.
function C.Binds()
	local class = UnitClassBase("player") or "NONE"
	local all = T.db.clicks
	all[class] = all[class] or {}
	return all[class]
end

---------------------------------------------------------------------------
-- Inputs
---------------------------------------------------------------------------

local function Held(upper)
	local held = (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "") .. (IsShiftKeyDown() and "shift-" or "")
	return upper and held:upper() or held
end

-- The mouse click being made right now, as an input: the button with the keys held. A button past the fifth is
-- bound as a key is (the frames' own clicks name five).
function C.Input(click)
	local n = MOUSE[click]
	if n then return Held() .. n end
	local extra = click and click:match("^Button(%d+)$")
	if extra then return KEY .. Held(true) .. "BUTTON" .. extra end
	return nil
end

-- The key being pressed right now, as an input; nil for a key that is none of its own (Shift, Escape).
function C.KeyInput(key)
	if not key or NO_KEY[key] then return nil end
	return KEY .. Held(true) .. key
end

-- An input apart: its held keys ("alt-ctrl-", lower case), then its mouse button's number or its key.
local function Parts(input)
	if input:sub(1, #KEY) == KEY then
		local rest, mods = input:sub(#KEY + 1), ""
		for _, mod in ipairs({ "ALT-", "CTRL-", "SHIFT-" }) do
			if rest:sub(1, #mod) == mod and #rest > #mod then
				mods, rest = mods .. mod:lower(), rest:sub(#mod + 1)
			end
		end
		return mods, nil, rest
	end
	local mods, n = input:match("^([a-z%-]*)(%d)$")
	return mods or "", n, nil
end

local MOD_WORD = { alt = "Alt", ctrl = "Ctrl", shift = "Shift" }

-- An input in words: "Shift + Left click", "Ctrl + F", "Button 6".
function C.Words(input)
	local mods, n, key = Parts(input)
	local words = {}
	for mod in mods:gmatch("(%a+)%-") do words[#words + 1] = MOD_WORD[mod] end
	if n then
		words[#words + 1] = MOUSE_NAME[n]
	else
		local extra = key:match("^BUTTON(%d+)$")
		words[#words + 1] = extra and ("Button " .. extra) or GetBindingText(key)
	end
	return table.concat(words, " + ")
end

-- A binding in words.
function C.Label(what)
	if what == nil then return "" end
	if NAMES[what] then return NAMES[what] end
	if type(what) == "number" then
		local name, rank = C_Spell.GetSpellName(what), C_Spell.GetSpellSubtext(what)
		if not name then return "" end
		if rank and rank ~= "" then return name .. " (" .. rank .. ")" end
		return name
	end
	return what
end

-- Every binding as it stands, in the order it is listed: the mouse first (by button, then by keys held), then
-- the keys by name. A left and a right click with nothing bound say what they do anyway (`default`).
--   -> { { input, what, default }, ... }
function C.List()
	local binds, list = C.Binds(), {}
	for input, what in pairs(binds) do list[#list + 1] = { input = input, what = what } end
	for n, what in pairs(DEFAULT) do
		if binds[n] == nil then list[#list + 1] = { input = n, what = what, default = true } end
	end
	local function Rank(entry)
		local mods, n, key = Parts(entry.input)
		return n and 0 or 1, n or key, #mods, mods
	end
	table.sort(list, function(a, b)
		local ak, an, al, am = Rank(a)
		local bk, bn, bl, bm = Rank(b)
		if ak ~= bk then return ak < bk end
		if an ~= bn then return an < bn end
		if al ~= bl then return al < bl end
		return am < bm
	end)
	return list
end

-- The inputs bound to a spell (by its name, or by `id` for one rank), as listed.
function C.Of(name, id)
	local list = {}
	for _, entry in ipairs(C.List()) do
		if not entry.default and (entry.what == name or entry.what == id) then list[#list + 1] = entry.input end
	end
	return list
end

---------------------------------------------------------------------------
-- On the frames
---------------------------------------------------------------------------

-- How each mouse button is registered: all on release, or (cast on press, with a spell on a click) each of the
-- five on its press but the ones that can open the menu.
function C.Registered(binds)
	local spell, menu = false, { ["2"] = true }
	for input, what in pairs(binds) do
		local _, n = Parts(input)
		if n then
			if what == "menu" then menu[n] = true elseif not KINDS[what] then spell = true end
		end
	end
	if not (spell and T.db.press) then return { "AnyUp" } end
	local list = {}
	for _, n in ipairs({ "1", "2", "3", "4", "5" }) do list[#list + 1] = CLICK[n] .. (menu[n] and "Up" or "Down") end
	return list
end

-- Mouse 3, 4 and 5 over a frame go to the frame, never to the key they're bound to. One with no click of its own
-- here presses that key's button on your bars instead, so a key's heal lands on whoever is in the frame.
local BARS = { MULTIACTIONBAR1 = "MultiBarBottomLeft", MULTIACTIONBAR2 = "MultiBarBottomRight", MULTIACTIONBAR3 = "MultiBarRight",
	MULTIACTIONBAR4 = "MultiBarLeft", MULTIACTIONBAR5 = "MultiBar5", MULTIACTIONBAR6 = "MultiBar6", MULTIACTIONBAR7 = "MultiBar7" }
local HELD = { "", "alt-", "ctrl-", "shift-", "alt-ctrl-", "alt-shift-", "ctrl-shift-", "alt-ctrl-shift-" }

-- The button a binding presses, by name, and the mouse button it presses it with; nil for a binding that
-- presses no button.
local function Pressed(command)
	local n = command:match("^ACTIONBUTTON(%d+)$")
	if n then return "ActionButton" .. n, "LeftButton" end
	local bar, i = command:match("^(MULTIACTIONBAR%d)BUTTON(%d+)$")
	if bar and BARS[bar] then return BARS[bar] .. "Button" .. i, "LeftButton" end
	return command:match("^CLICK ([^:]+):(.+)$")
end

-- Mouse 3 to 5, with any keys held, that have no click of their own here: input -> the macro that presses
-- their key's button (it presses on the way down or up as your bars do); and all of it in a line, to tell
-- whether it changed.
local wearing = ""      -- the line the frames last wore
function C.Through(binds)
	local through, said = {}, {}
	local down = GetCVarBool("ActionButtonUseKeyDown") and " 1" or ""
	for n = 3, 5 do
		for _, held in ipairs(HELD) do
			local input = held .. n
			if binds[input] == nil then
				local name, click = Pressed(GetBindingAction(held:upper() .. "BUTTON" .. n) or "")
				if name then
					through[input] = ("/click %s %s%s"):format(name, click, down)
					said[#said + 1] = input .. "=" .. through[input]
				end
			end
		end
	end
	return through, table.concat(said, ";")
end

local worn = setmetatable({}, { __mode = "k" })   -- a frame's button -> the attributes it was given

local function Dress(button, binds, clicks, through)
	-- (nil clears one: the frame's own "*type1" and "*type2" answer again.)
	for _, name in ipairs(worn[button] or {}) do button:SetAttribute(name, nil) end
	local set = {}
	for input, text in pairs(through) do
		local mods, n = Parts(input)
		button:SetAttribute(mods .. "type" .. n, "macro")
		button:SetAttribute(mods .. "macrotext" .. n, text)
		set[#set + 1] = mods .. "type" .. n
		set[#set + 1] = mods .. "macrotext" .. n
	end
	for input, what in pairs(binds) do
		local mods, n = Parts(input)
		if n then
			local kind = KINDS[what] or "spell"
			button:SetAttribute(mods .. "type" .. n, kind)
			set[#set + 1] = mods .. "type" .. n
			if kind == "spell" then
				button:SetAttribute(mods .. "spell" .. n, what)
				set[#set + 1] = mods .. "spell" .. n
			end
		end
	end
	worn[button] = set
	button:RegisterForClicks(unpack(clicks))
end

-- The keys. `lit` is the frame the mouse is on, kept in the header's own restricted code: a frame that goes
-- without the mouse leaving it (a member gone) is let go of as the next is come onto, or as it hides.
local KEYS = { helpers = {}, wrapped = setmetatable({}, { __mode = "k" }) }
local ENTER = [[
	if lit and lit ~= self then lit:ClearBindings() end
	lit = self
	local unit = self:GetAttribute("unit")
	for i = 1, control:GetAttribute("keys") or 0 do
		local helper = control:GetFrameRef("key" .. i)
		helper:SetAttribute("unit", unit)
		self:SetBindingClick(true, control:GetAttribute("key" .. i), helper:GetName(), "LeftButton")
	end
]]
local LEAVE = [[
	self:ClearBindings()
	if lit == self then lit = nil end
]]

local function Keys(binds)
	if not KEYS.header then
		KEYS.header = CreateFrame("Frame", "ShyFramesKeys", UIParent, "SecureHandlerBaseTemplate")
	end
	local header = KEYS.header
	local list = {}
	for input, what in pairs(binds) do
		local _, n, key = Parts(input)
		if key and what ~= "menu" then list[#list + 1] = input end
	end
	table.sort(list)
	for i, input in ipairs(list) do
		local helper = KEYS.helpers[i]
		if not helper then
			helper = CreateFrame("Button", "ShyFramesKey" .. i, UIParent, "SecureActionButtonTemplate")
			helper:RegisterForClicks("AnyUp", "AnyDown")
			header:SetFrameRef("key" .. i, helper)
			KEYS.helpers[i] = helper
		end
		local what = binds[input]
		local kind = KINDS[what] or "spell"
		helper:SetAttribute("type", kind)
		helper:SetAttribute("spell", kind == "spell" and what or nil)
		header:SetAttribute("key" .. i, input:sub(#KEY + 1))
	end
	header:SetAttribute("keys", #list)
	for _, frame in ipairs(F.list) do
		local button = frame.button
		if not KEYS.wrapped[button] then
			KEYS.wrapped[button] = true
			SecureHandlerWrapScript(button, "OnEnter", header, ENTER)
			SecureHandlerWrapScript(button, "OnLeave", header, LEAVE)
			SecureHandlerWrapScript(button, "OnHide", header, LEAVE)
		end
		ClearOverrideBindings(button)   -- a frame the mouse is on wears the old keys: gone until it comes on again
	end
end

-- Every frame wears the bindings as they stand. After the fight, in one.
function C.Apply()
	ns.AfterCombat("clicks", function()
		local binds = C.Binds()
		local through, line = C.Through(binds)
		local clicks = C.Registered(binds)
		wearing = line
		for _, frame in ipairs(F.list) do Dress(frame.button, binds, clicks, through) end
		Keys(binds)
	end)
end

---------------------------------------------------------------------------
-- Changing them
---------------------------------------------------------------------------

local panels = {}          -- every panel made
local undo                 -- your bindings as they were before the last change

local function Copy(binds)
	local copy = {}
	for input, what in pairs(binds) do copy[input] = what end
	return copy
end

-- What an input does, said whole: "Shift + Left click casts Renew."
local function Sentence(input, what)
	local words = C.Words(input)
	if what == "target" then return words .. " targets." end
	if what == "menu" then return words .. " opens the menu." end
	return words .. " casts " .. C.Label(what) .. "."
end

local function Tell(text, input)
	for _, panel in ipairs(panels) do
		panel:Refresh()
		panel:Told(text, input)
		if panel.changed then panel.changed() end   -- whoever stands the panel draws what it shows of them again
	end
	Shy.Settings.Refresh()   -- the settings say how many are bound
end

-- Binds an input (nil lets it go). Every panel says so, and the change can be taken back (C.Undo).
--   -> true, or false and why not
function C.Set(input, what)
	local binds = C.Binds()
	local before = binds[input]
	if before == what then return true end
	local _, n = Parts(input)
	if what == "menu" and not n then return false, "The menu needs a mouse click, not a key." end
	undo = Copy(binds)
	binds[input] = what
	C.Apply()
	local text
	if what ~= nil then
		text = Sentence(input, what)
		if before ~= nil and not NAMES[before] then text = text .. " It cast " .. C.Label(before) .. " before." end
	else
		text = C.Words(input) .. " is free again."
	end
	Tell(text, what ~= nil and input or nil)
	return true
end

-- Takes the last change back, whole.
function C.Undo()
	if not undo then return end
	local binds = C.Binds()
	wipe(binds)
	for input, what in pairs(undo) do binds[input] = what end
	undo = nil
	C.Apply()
	Tell("Put back as it was.")
end

-- The spells in your book that can be cast, by name.  -> { [name] = true }
function C.Known()
	local known = {}
	local bank = Enum.SpellBookSpellBank.Player
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info and not info.isGuild and not info.offSpecID then
			for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				if item and item.itemType == Enum.SpellBookItemType.Spell and item.name and not item.isPassive then
					known[item.name] = true
				end
			end
		end
	end
	return known
end

-- A healer's first clicks, by class: each click with the spells it would take, the first you know winning. A
-- left click still targets and a right click still opens the menu. (The spells by their English names: on
-- another language's client none is known, and nothing is offered.)
local STARTER = {
	PRIEST = {
		{ "shift-1", "Flash Heal", "Lesser Heal" }, { "ctrl-1", "Renew" }, { "alt-1", "Power Word: Shield" },
		{ "3", "Greater Heal", "Heal", "Lesser Heal" }, { "shift-2", "Dispel Magic" }, { "ctrl-2", "Abolish Disease", "Cure Disease" },
		{ "alt-2", "Prayer of Mending" },
	},
	DRUID = {
		{ "shift-1", "Regrowth" }, { "ctrl-1", "Rejuvenation" }, { "alt-1", "Lifebloom" }, { "3", "Healing Touch" },
		{ "shift-2", "Remove Curse" }, { "ctrl-2", "Abolish Poison", "Cure Poison" }, { "alt-2", "Wild Growth", "Nourish" },
	},
	SHAMAN = {
		{ "shift-1", "Lesser Healing Wave", "Healing Wave" }, { "ctrl-1", "Riptide" }, { "alt-1", "Earth Shield" },
		{ "3", "Healing Wave" }, { "shift-2", "Cure Poison" }, { "ctrl-2", "Cure Disease" }, { "alt-2", "Chain Heal" },
	},
	PALADIN = {
		{ "shift-1", "Flash of Light" }, { "ctrl-1", "Holy Shock" }, { "alt-1", "Sacred Shield", "Blessing of Protection" },
		{ "3", "Holy Light" }, { "shift-2", "Cleanse", "Purify" }, { "ctrl-2", "Beacon of Light" }, { "alt-2", "Lay on Hands" },
	},
}

-- The clicks a healer's start would add as things stand: those of the class's whose click is free, each with the
-- first of its spells you know that no other of them took.  -> { { input, spell }, ... }
function C.Starter()
	local plan, list = STARTER[UnitClassBase("player") or ""], {}
	if not plan then return list end
	local binds, known, taken = C.Binds(), C.Known(), {}
	for _, what in pairs(binds) do taken[what] = true end
	for _, entry in ipairs(plan) do
		if binds[entry[1]] == nil then
			for i = 2, #entry do
				if known[entry[i]] and not taken[entry[i]] then
					taken[entry[i]] = true
					list[#list + 1] = { input = entry[1], spell = entry[i] }
					break
				end
			end
		end
	end
	return list
end

-- Binds them, as one change.
function C.SetUp()
	local list = C.Starter()
	if #list == 0 then return end
	local binds = C.Binds()
	undo = Copy(binds)
	for _, entry in ipairs(list) do binds[entry.input] = entry.spell end
	C.Apply()
	Tell(#list .. " clicks set up for healing. Change any of them, or Undo to take them all back.")
end

---------------------------------------------------------------------------
-- The panel: your clicks and keys
---------------------------------------------------------------------------
-- Every binding as a row: the spell's picture, its name, and the click or key that casts it in gold. It is the
-- right column of the spellbook's click casting page (T:ClickPanel, ShySkin's book) and the body of the window
-- that stands alone where there is no such page (C.Window): one make, wherever it is.
--   a row      the mouse on it shows a cross at its end: that, or a right click on the row, lets the binding go.
--              A left and a right click with nothing bound stand first, quiet: what they do anyway.
--   the wheel  scrolls the list when it is longer than its room
--   nothing bound   says how to bind, and (a healing class) offers a start: the class's usual heals on Shift, Ctrl
--              and Alt with the left and right buttons, in one press
--   the line   under the list: what was just changed, or what whoever stands the panel says (panel:Say), with
--              Undo beside it
-- A new binding's row is lit for a moment, and the list scrolls to it.

local P = { row = 36, icon = 28, head = 22, line = 36, flash = 0.8, quiet = 0.55 }
C.PANEL = P

local function Row(panel, i)
	local row = CreateFrame("Button", nil, panel)
	row:SetSize(panel.width, P.row - 4)   -- (its width, and its words', are the panel's: Fit)
	row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -(P.head + (i - 1) * P.row))
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(P.icon, P.icon)
	row.icon:SetPoint("LEFT")
	row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- One light for the mouse on a row: a band from the picture's edge to the row's end. The slot has none of
	-- its own (a frame lit round the picture with a band starting under it read as two things, and as broken).
	row.slot = Shy.Slot.New(row, { to = row.icon, icon = row.icon, size = P.icon, hover = false })
	row.hot = row:CreateTexture(nil, "HIGHLIGHT")
	row.hot:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
	row.hot:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 2)
	row.hot:SetColorTexture(1, 1, 1, 0.06)
	row.name = UI.Text(row, "", 12)
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
	row.name:SetWidth(panel.width - P.icon - 8 - 18)
	row.name:SetWordWrap(false)
	row.words = UI.Text(row, "", 11, false, UI.colors.alert)
	row.words:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
	row.words:SetWidth(panel.width - P.icon - 8 - 18)
	row.words:SetWordWrap(false)
	-- The cross: there while the mouse is on the row.
	row.cross = row:CreateTexture(nil, "OVERLAY")
	row.cross:SetSize(10, 10)
	row.cross:SetPoint("RIGHT", -4, 0)
	row.cross:SetTexture(Shy.MEDIA .. "GlyphClose")
	UI.Tint(row.cross, UI.colors.dim)
	row.cross:Hide()
	-- Lit for a moment when it is new: a wash on a frame of its own, whose alpha is the light's.
	local light = CreateFrame("Frame", nil, row)
	light:SetAllPoints()
	light:SetFrameLevel(row:GetFrameLevel())
	light:SetAlpha(0)
	local wash = light:CreateTexture(nil, "BACKGROUND")
	wash:SetAllPoints()
	wash:SetColorTexture(1, 1, 1, 1)
	UI.Tint(wash, Shy.Theme.Accent)
	row.lit = light:CreateAnimationGroup()
	local fade = row.lit:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.5)
	fade:SetToAlpha(0)
	fade:SetDuration(P.flash)
	fade:SetSmoothing("OUT")
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self)
		local entry = self.entry
		if entry and not entry.default then C.Set(entry.input, nil) end
	end)
	row:SetScript("OnEnter", function(self)
		local entry = self.entry
		if not entry then return end
		self.cross:SetShown(not entry.default)
		panel:Say(entry.default and (Sentence(entry.input, entry.what) .. " Bind it to change that.")
			or (Sentence(entry.input, entry.what) .. " Click to let it go."))
	end)
	row:SetScript("OnLeave", function(self)
		self.cross:Hide()
		panel:Say(nil)
	end)
	return row
end

-- A panel on `parent`. It is laid out by the room it is given (panel:Fit), top to bottom, each piece under the
-- one before: its name, as many rows as the room holds (one at the least), the line with Undo. With
-- nothing bound the start's button stands in the first free row's place, so nothing ever lies over anything.
--   panel:Fit(width, height)   its room; lays it out and draws it
--   panel:Refresh()
--   panel:Say(text | nil)      its line says that (nil: what was last changed again)
--   panel.changed              called after any change of the bindings (its owner's, to draw what it shows of them)
function C.Panel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel.width, panel.count, panel.offset = 1, 1, 0
	panel:EnableMouseWheel(true)
	local title = UI.Text(panel, "Your clicks and keys", 13, true)
	title:SetPoint("TOPLEFT", 0, 0)
	panel.tally = UI.Text(panel, "", 11, false, UI.colors.dim)
	panel.tally:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -2)
	panel.rows = {}
	panel.start = UI.Button(panel, "Set up healing clicks", 120, function() C.SetUp() end)
	panel.start:Hide()
	panel.undo = UI.Button(panel, "Undo", 52, function() C.Undo() end)
	panel.undo:Hide()
	panel.line = UI.Text(panel, "", 12)
	panel.line:SetHeight(P.line)
	panel.line:SetJustifyV("MIDDLE")
	panel.line:SetWordWrap(true)
	local function Line()
		panel.line:SetText(panel.said or panel.last or panel.idle or "")
		local can = undo ~= nil and panel.said == nil
		panel.undo:SetShown(can)
		panel.line:SetWidth(panel.width - (can and 58 or 0))
	end
	function panel:Say(text)
		self.said = text
		Line()
	end
	function panel:Fit(width, height)
		self.width = width
		self.count = math.max(1, math.floor((height - P.head - 4 - P.line) / P.row))
		self.height = P.head + self.count * P.row + 4 + P.line
		self:SetSize(width, self.height)
		for i = #self.rows + 1, self.count do self.rows[i] = Row(self, i) end
		for i, row in ipairs(self.rows) do
			row:SetWidth(width)
			row.name:SetWidth(width - P.icon - 8 - 18)
			row.words:SetWidth(width - P.icon - 8 - 18)
			if i > self.count then row:Hide() end
		end
		local foot = P.head + self.count * P.row + 4
		self.line:ClearAllPoints()
		self.line:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -foot)
		self.undo:ClearAllPoints()
		self.undo:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -(foot + 6))
		self.start:SetWidth(width)
		self:Refresh()
	end

	function panel:Refresh()
		-- Not laid out yet (shown before it was given its room: seen in game, an error on its first row): nothing
		-- to draw on. Its rows are there for as many as it shows, whoever asks first.
		if not self.height then return end
		for i = #self.rows + 1, self.count do self.rows[i] = Row(self, i) end
		local list = C.List()
		-- Another class's bindings (another character): what was last changed was not theirs.
		local binds = C.Binds()
		if self.of ~= binds then self.of, self.last = binds, nil end
		local bound = 0
		for _, entry in ipairs(list) do
			if not entry.default then bound = bound + 1 end
		end
		self.offset = math.max(0, math.min(self.offset, #list - self.count))
		local shown = 0
		for i = 1, self.count do
			local row = self.rows[i]
			local entry = list[self.offset + i]
			row.entry = entry
			row:SetShown(entry ~= nil)
			if entry then
				shown = i
				row.icon:SetTexture(C.Picture(entry.what))
				row.name:SetText(C.Label(entry.what))
				row.words:SetText(C.Words(entry.input))
				row:SetAlpha(entry.default and P.quiet or 1)
			end
		end
		self.tally:SetText(bound > 0 and (bound .. " bound") or "")
		-- The start is offered while nothing is bound, to a class that has one, in the first free row's place.
		local start = bound == 0 and shown < self.count and #C.Starter() > 0
		self.start:SetShown(start)
		if start then
			self.start:ClearAllPoints()
			self.start:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(P.head + shown * P.row + 4))
		end
		self.idle = bound == 0 and (self.how or "Nothing bound yet. Open your spellbook and press the click casting tab on its right edge.") or nil
		Line()
	end
	-- A change: its words on the line, its row lit and in sight.
	function panel:Told(text, input)
		self.last = text
		if input then
			for index, entry in ipairs(C.List()) do
				if entry.input == input then
					if index <= self.offset or index > self.offset + self.count then
						self.offset = math.max(0, index - self.count)
						self:Refresh()
					end
					local row = self.rows[index - self.offset]
					if row and self:IsVisible() then
						row.lit:Stop()
						row.lit:Play()
					end
				end
			end
		end
		Line()
	end
	panel:SetScript("OnMouseWheel", function(self, delta)
		self.offset = math.max(0, self.offset - delta)
		self:Refresh()
	end)
	panel:SetScript("OnShow", function(self)
		self.said = nil
		self:Refresh()
	end)
	panels[#panels + 1] = panel
	return panel
end

---------------------------------------------------------------------------
-- Where click casting is set up
---------------------------------------------------------------------------
-- One place: the spellbook's click casting page (ShySkin's book), where a spell is picked and given a click.
-- C.Open goes there. Without that book there is no page to go to: the list then stands alone in a small window,
-- which says what it is and where spells are bound.

local WIN = { pad = 16, width = 300, rows = 8, note = 44 }
local win, open
C.SAYS = {
	what = "What your clicks and keys cast on the frame under your mouse. Right-click one to let it go.",
	-- Why there is no page: the spellbook isn't the restyled one, or the addon that restyles it is off.
	off = "To bind a spell, switch on Spellbook and talents under Skin. Its book has a click casting tab.",
	none = "Binding a spell needs the Skin addon. Its spellbook has a click casting tab.",
	fight = "you can set up click casting once the fight is over.",
}

-- Whether the spellbook has a click casting page: ShySkin with its spellbook on.
function C.Paged()
	local skin = Shy.addons.Skin
	if not skin then return false end
	if skin.ClickCasting then return true end
	local modules = skin.db and skin.db.modules
	return modules ~= nil and modules.spells ~= false and PlayerSpellsUtil ~= nil and PlayerSpellsUtil.OpenToSpellBookTab ~= nil
end

-- The page is up: the list stands in it (the book asked for one: T:ClickPanel).
local function Seated()
	for _, panel in ipairs(panels) do
		if not (win and panel == win.panel) and panel:IsVisible() then return true end
	end
	return false
end

-- Turns the open book to its click casting page, by its tab. False while the book has no such tab.
local function Turn()
	if Seated() then return true end
	local tab = ShySkinSpellClicks
	if not (tab and tab:IsVisible()) then return false end
	tab:Click()
	return true
end

local function Create()
	local top = UI.HEAD.window.line + UI.LINE
	win = UI.Window({
		id = "shyframes.clicks", name = "ShyFramesClicksWindow", title = "Click casting",
		width = WIN.width, height = 100,
		point = { "CENTER", "CENTER", 0, 60 },
		shown = function() return open end,
		grip = { flow = function() end, min = { WIN.width, 100 } },
		strata = "HIGH",
		onClose = function() open = false end,
		head = { size = "window", icon = C.ICON, title = "Click casting" },
	})
	-- On the window's body: clear of the look's work round the edge (UI.Body), the window that much bigger.
	local body = UI.Body(win)
	win.note = UI.Text(body, "", 11, false, UI.colors.dim)
	win.note:SetPoint("TOPLEFT", WIN.pad, -(top + WIN.pad))
	win.note:SetSize(WIN.width - 2 * WIN.pad, WIN.note)
	win.note:SetJustifyH("LEFT")
	win.note:SetJustifyV("TOP")
	win.note:SetWordWrap(true)
	win.panel = C.Panel(body)
	win.panel.how = "Nothing bound yet."
	win.panel:SetPoint("TOPLEFT", WIN.pad, -(top + WIN.pad + WIN.note + 6))
	win.panel:Fit(WIN.width - 2 * WIN.pad, P.head + WIN.rows * P.row + 4 + P.line)
	Shy.HUD.Made(win, WIN.width, top + WIN.pad + WIN.note + 6 + win.panel.height + WIN.pad)
end

-- The list on its own, where there is no page: it says what it is, and where a spell is bound.
function C.Window()
	if not win then Create() end
	win.note:SetText(C.SAYS.what .. " " .. (Shy.addons.Skin and C.SAYS.off or C.SAYS.none))
	open = true
	Shy.HUD.Update(win)
	win:Raise()
	win.panel:Refresh()
end

-- Click casting's setup: the spellbook at its click casting page, or the list's own window where there is none.
-- The /shy window is put away, so what opens isn't behind it.
function C.Open()
	if InCombatLockdown() then
		T:Print(C.SAYS.fight)
		return
	end
	if Shy.Hub and Shy.Hub.Close then Shy.Hub.Close() end
	if not C.Paged() then return C.Window() end
	C.Close()
	local skin = Shy.addons.Skin
	if skin.ClickCasting then return skin:ClickCasting() end
	PlayerSpellsUtil.OpenToSpellBookTab()
	if Turn() then return end
	-- The book draws its tabs as it shows: asked again once it has.
	C_Timer.After(0, function()
		if not Turn() then C.Window() end
	end)
end

function C.Close()
	open = false
	if win then Shy.HUD.Update(win) end
end

function C.Listen()
	-- A spell learned or lost (ShyCore says only a real change): a panel's pictures and what a start would offer
	-- may have changed.
	Shy:On("SHY_SPELLS", function()
		for _, panel in ipairs(panels) do
			if panel:IsVisible() then panel:Refresh() end
		end
	end)
	-- Your key bindings changed, or whether your bars cast on the way down: what Mouse 3 to 5 press on a frame.
	-- (A layout of your keys binds many at once: they are looked at once, after.)
	local keys, waiting = CreateFrame("Frame"), false
	-- (one that leaves Mouse 3 to 5 as they were dresses no frame)
	local Again = Shy.Clocked("ShyFrames clicks", function()
		waiting = false
		if select(2, C.Through(C.Binds())) ~= wearing then C.Apply() end
	end)
	keys:RegisterEvent("UPDATE_BINDINGS")
	keys:RegisterEvent("CVAR_UPDATE")
	keys:SetScript("OnEvent", function(_, event, name)
		if waiting or (event == "CVAR_UPDATE" and name ~= "ActionButtonUseKeyDown") then return end
		waiting = true
		C_Timer.After(0, Again)
	end)
end
