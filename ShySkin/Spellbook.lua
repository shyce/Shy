-- The spellbook and talent window (PlayerSpellsFrame, in load-on-demand Blizzard_PlayerSpells). The window
-- wears the family's header; the talent tab is Talents.lua's; the spellbook tab is the Classic book again:
-- one page of two columns of six, the skill lines as square tabs down the right edge, Page N between two
-- arrows, the ranks check top right, the tree's own painting from the talent window as the page's ground.
--
-- How it stays safe (see Shop.lua for the attic):
--   * Blizzard's window stays the UI panel. The spellbook tab's own pieces go to the attic; the window is
--     sized to the book while it shows, and the game's size is asked for again when the module goes off.
--   * Casting from the book is the game's protected business, so a page's twelve spells are secure action
--     buttons of ours, in one secure holder that is a child of Blizzard's SpellBookFrame: it shows and hides
--     with the spellbook tab, in a fight too. The window is protected in a fight anyway (the game's own book
--     holds a secure spell button): our code can't size or move it then, so secure sizers of ours size it
--     (Arm). They are set up out of a fight: a window first loaded in one keeps the game's size until it ends.
--   * The book is read and written into the holder's store out of a fight (each spell's action by tab and
--     index). The tabs, the arrows and the wheel turn pages in the holder's own secure code, so a page can be
--     turned and cast from in a fight; what is drawn follows the page the holder says it shows.
--   * Nothing is written on a Blizzard frame or table. With a gamepad, the game's own book stays.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local Theme = Shy.Theme
local Slot = Shy.Slot
local C, SC = UI.colors, Skin.colors
local Shop, Talents = ns.Shop, ns.Talents
local WIN = ns.WINDOW

-- One padding all round (PAD): the sides of the grid and the band, the arrows' corners. The grid's rows and
-- its two columns have one gap between them (GAP), the rule over the foot sits halfway between the last row
-- and the arrows.
local PAD, GAP = 18, 14
local SLOT = 40                    -- a spell's slot: a size up from a bag's (Slot.SIZE), as the Classic book's were large
local W = 420                      -- the book
local PER = 12                     -- spells a page: two columns of six, the left one filled first
local ROWS = 6
local CELL_W = (W - 2 * PAD - 2 * GAP) / 2
local COL, ROW = CELL_W + 2 * GAP, SLOT + GAP   -- column and row pitch
local GRID_X, GRID_Y = PAD, ns.WINDOW.head + 46   -- the first spell's top left: under the band with the tree's name
local TEXT_X = SLOT + 8
local TEXT_W = CELL_W - TEXT_X - 2
local ARROW = 24
local FOOT = PAD + ARROW + 12      -- the rule over the foot, up from the book's foot
local H = GRID_Y + (ROWS - 1) * ROW + SLOT + 13 + FOOT
-- The book flows: dragged by its right side, its foot or the corner between, the window is that much wider
-- and taller and its page holds as many columns and rows of spells as fit, never a larger spell. W and H are
-- the least it goes to, and the size it is made at. `fit` is the book as it stands.
local MOST = 60                    -- spells a page at the most: each is a secure button, made once
local fit = { w = W, h = H, cols = 2, rows = ROWS, per = PER, cell = CELL_W }
local function Fit(w, h)
	w = math.max(W, math.min(w or W, UIParent:GetWidth() - 80))
	h = math.max(H, math.min(h or H, UIParent:GetHeight() - 80))
	local cols = math.max(2, math.floor((w - 2 * PAD + 2 * GAP) / (CELL_W + 2 * GAP)))
	local rows = math.max(ROWS, math.floor((h - GRID_Y - 13 - FOOT - SLOT) / ROW) + 1)
	while cols * rows > MOST and rows > ROWS do rows = rows - 1 end
	while cols * rows > MOST and cols > 2 do cols = cols - 1 end
	fit.w, fit.h, fit.cols, fit.rows, fit.per = w, h, cols, rows, cols * rows
	fit.cell = (w - 2 * PAD - (cols - 1) * 2 * GAP) / cols
end
local TAB = ns.SIDE_TAB             -- a side tab on the spine, as the character window's
local TAB_ICON, TAB_PITCH = TAB.slot, TAB.h + 2   -- 2 between two, as Blizzard's are
local SEARCH_W = 136
local CONTROL = UI.HEAD.window.control   -- the search box's and the cog's height, as every window header's controls
local ICON = { 0.08, 0.92, 0.08, 0.92 }
local DIM = 0.74                   -- a tab's icon while it isn't the open page
local ART = { alpha = 0.55, top = 0.4 }    -- the page's painting: its strength; how far down the spare height its cut starts
local BURNS = { "TOP", "BOTTOM", "LEFT", "RIGHT", "MIDDLE" }
local CVAR = { ranks = "ShowAllSpellRanks", passives = "spellBookHidePassives", flyouts = "spellBookHideFlyouts" }

local M                            -- the module
local own = {}                     -- our frames, made once
local book = { tabs = {} }         -- what the store holds: tabs[i] = { name, icon, line, tree, items = { ... } }
local new = {}                     -- skill line index -> true while a spell learned there is unseen
local query                        -- the search, while one stands
local missing                      -- true: the results page lists the spells on none of your bars, as the game's book can
local stale                        -- the book changed in a fight: read it again after
local binding = false              -- binding clicks: a click on a spell binds it to that click on ShyFrames' unit frames
local Draw, Bake, Stale

-- ShyFrames, when it is there and its frames take click bindings: the book is where they are easiest made.
local function Binder()
	local frames = Shy.addons.Frames
	return frames and frames.BindClick and frames.ClickInput and frames.ClickKeyInput and frames.ClicksOf and frames.ClickWords
		and frames.ClickPanel and frames.ClickIcon and frames or nil
end

-- How a spell of the book is bound: a lower rank as itself (by its ID), the highest by name, so it stays the
-- highest as you learn more.  -> name or nil, ID or nil
local function Bound(item)
	if C_SpellBook.IsSpellBookItemLowRank(item.slot, item.bank) then return nil, item.spell end
	return item.name, nil
end

local function Frame() return PlayerSpellsFrame end
local function Book() return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame end

-- Whether the book is ours: not with a gamepad, whose controls drive the game's book.
local function Ours()
	return not (InputUtil and InputUtil.IsGamepadUIEnabled())
end

local function OnBook()
	local f = Frame()
	return f and f:IsShown() and f:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook)
end

---------------------------------------------------------------------------
-- Reading the book
---------------------------------------------------------------------------

local PET_COMMANDS   -- a pet command's name -> its slash command

local function Commands()
	if PET_COMMANDS then return PET_COMMANDS end
	PET_COMMANDS = {}
	for name, slash in pairs({ PET_ACTION_ATTACK = "SLASH_PET_ATTACK1", PET_ACTION_FOLLOW = "SLASH_PET_FOLLOW1",
		PET_ACTION_WAIT = "SLASH_PET_STAY1", PET_ACTION_MOVE_TO = "SLASH_PET_MOVE_TO1", PET_MODE_ASSIST = "SLASH_PET_ASSIST1",
		PET_MODE_AGGRESSIVE = "SLASH_PET_AGGRESSIVE1", PET_MODE_DEFENSIVE = "SLASH_PET_DEFENSIVE1", PET_MODE_PASSIVE = "SLASH_PET_PASSIVE1" }) do
		if _G[name] and _G[slash] then PET_COMMANDS[_G[name]] = _G[slash] end
	end
	return PET_COMMANDS
end

-- The game's own rule for what the book lists (SpellBookFrameMixin:ShouldDisplaySpellBookItem).
local function Listed(slot, bank)
	local kind = C_SpellBook.GetSpellBookItemType(slot, bank)
	if not kind then return false end
	if Kiosk.IsEnabled() and kind == Enum.SpellBookItemType.FutureSpell then return false end
	if not query and C_CVar.GetCVarBool(CVAR.passives) and C_SpellBook.IsSpellBookItemPassive(slot, bank) then return false end
	if not query and not C_CVar.GetCVarBool(CVAR.ranks) and C_SpellBook.IsSpellBookItemLowRank(slot, bank) then return false end
	local flyouts = not C_CVar.GetCVarBool(CVAR.flyouts)
	if not flyouts and kind == Enum.SpellBookItemType.Flyout then return false end
	if flyouts and C_SpellBook.IsSpellBookItemLooseFlyoutMember(slot, bank) then return false end
	return true
end

local asked = {}   -- spell -> true once its rank was asked to load (once a session: one with none answers at once)

-- On none of your bars: a spell, a pet's spell or a flyout you could place (the game's own test, as its book's).
local function Missing(item, info)
	local kind = item.kind
	if kind ~= "spell" and kind ~= "pet" and kind ~= "flyout" then return false end
	local status = SpellSearchUtil and SpellSearchUtil.GetActionbarStatusForSpellBookItemInfo(info)
	return status ~= nil and status == ActionButtonUtil.ActionBarActionStatus.MissingFromAllBars
end

local function Item(slot, bank)
	local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
	if not info or not info.name then return nil end
	local T = Enum.SpellBookItemType
	local item = { slot = slot, bank = bank, name = info.name, icon = info.iconID, spell = info.spellID,
		action = info.actionID, sub = info.subName or "" }
	if info.itemType == T.FutureSpell then
		item.kind = "future"
		local level = C_SpellBook.GetSpellBookItemLevelLearned(slot, bank)
		if level and level > UnitLevel("player") then
			item.sub = SPELLBOOK_AVAILABLE_AT:format(level)
		else
			item.sub = SPELLBOOK_TRAINABLE
			item.trainer = true
		end
	elseif info.itemType == T.Flyout then
		item.kind = "flyout"
	elseif bank == Enum.SpellBookSpellBank.Pet then
		item.kind = Commands()[info.name] and "command" or "pet"
	elseif info.isPassive then
		item.kind = "passive"
	else
		item.kind = "spell"
	end
	if item.kind ~= "future" and item.sub == "" then
		if info.isPassive then
			item.sub = SPELL_PASSIVE
		elseif item.spell then
			local sub = C_Spell.GetSpellSubtext(item.spell)
			if sub and sub ~= "" then
				item.sub = sub
			elseif not asked[item.spell] then
				-- The rank is loaded on demand; the book is read again a frame after it comes.
				asked[item.spell] = true
				Spell:CreateFromSpellID(item.spell):ContinueOnSpellLoad(function()
					if M and M.on then Stale() end
				end)
			end
		end
	end
	item.missing = Missing(item, info)
	return item
end

-- A search, the spells on none of your bars, or both: what the results page lists.
local function Matches(item)
	if query and not item.name:lower():find(query, 1, true) then return false end
	if missing and not item.missing then return false end
	return true
end

local function Read()
	local tabs = {}
	local tree = 0
	local Player, Pet = Enum.SpellBookSpellBank.Player, Enum.SpellBookSpellBank.Pet
	for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
		local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if info and not info.shouldHide then
			local general = line == Enum.SpellBookSkillLineIndex.General
			local tab = { name = general and GENERAL_SPELLS or info.name, line = line, items = {} }
			if general then
				local class = C_SpellBook.GetClassSkillLineInfo()
				tab.icon = class and class.iconID or info.iconID
			else
				tab.icon = info.iconID
				tree = tree + 1
				tab.tree = tree <= 3 and tree or nil
			end
			for i = 1, info.numSpellBookItems or 0 do
				local slot = info.itemIndexOffset + i
				if Listed(slot, Player) then tab.items[#tab.items + 1] = Item(slot, Player) end
			end
			tabs[#tabs + 1] = tab
		end
	end
	local count, token = C_SpellBook.HasPetSpells()
	if count and count > 0 and PetHasSpellbook() then
		local tab = { name = (token and _G["PET_TYPE_" .. token]) or PET, icon = GetPetIcon(), pet = true, items = {} }
		for slot = 1, count do
			if Listed(slot, Pet) then tab.items[#tab.items + 1] = Item(slot, Pet) end
		end
		tabs[#tabs + 1] = tab
	end
	local found = { name = SEARCH, items = {}, search = true }
	if query or missing then
		for _, tab in ipairs(tabs) do
			for _, item in ipairs(tab.items) do
				if Matches(item) then found.items[#found.items + 1] = item end
			end
		end
	end
	return tabs, found
end

---------------------------------------------------------------------------
-- The secure holder
---------------------------------------------------------------------------

-- Turns the page the holder shows: "tab" picks a tab (its last page), "turn" steps, "go" goes to a page.
-- Each tab remembers its page ("at" .. tab). The store holds every spell's attributes by tab and index.
local TURN = [[
	if name ~= "tab" and name ~= "turn" and name ~= "go" then return end
	if value == nil then return end
	local store = self:GetFrameRef("store")
	local tab = self:GetAttribute("tab") or 1
	local count = store:GetAttribute("n" .. tab) or 0
	local per = self:GetAttribute("per") or 12
	local pages = max(1, ceil(count / per))
	local at = self:GetAttribute("at" .. tab) or 1
	if name == "turn" then
		at = at + value
		self:SetAttribute("turn", nil)
	elseif name == "go" then
		at = value
		self:SetAttribute("go", nil)
	end
	if at > pages then at = pages end
	if at < 1 then at = 1 end
	self:SetAttribute("at" .. tab, at)
	for i = 1, per do
		local cell = self:GetFrameRef("cell" .. i)
		local key = tab .. "_" .. ((at - 1) * per + i)
		cell:SetAttribute("type1", store:GetAttribute("t" .. key))
		cell:SetAttribute("type2", store:GetAttribute("u" .. key))
		cell:SetAttribute("spell", store:GetAttribute("s" .. key))
		cell:SetAttribute("macrotext1", store:GetAttribute("m" .. key))
		cell:SetAttribute("macrotext2", store:GetAttribute("r" .. key))
		cell:SetAttribute("pickup", store:GetAttribute("p" .. key))
	end
	self:SetAttribute("shown", tab .. ":" .. at .. ":" .. pages)
]]

local PICK_TAB = [[ self:GetParent():SetAttribute("tab", self:GetID()) ]]
local PICK_TURN = [[ self:GetParent():SetAttribute("turn", self:GetAttribute("step")) ]]
local WHEEL = [[ self:GetParent():SetAttribute("turn", delta > 0 and -1 or 1) ]]
local DRAG = [[
	local spell = self:GetAttribute("pickup")
	if spell then return "spell", spell end
]]

-- What the holder shows: tab, page, pages.
local function Shown()
	local holder = own.holder
	local text = holder and holder:GetAttribute("shown")
	if not text then return 1, 1, 1 end
	local tab, at, pages = text:match("^(%d+):(%d+):(%d+)$")
	return tonumber(tab) or 1, tonumber(at) or 1, tonumber(pages) or 1
end

-- The book's tab by the holder's number: 0 is the search's results.
local function TabAt(index)
	if index == 0 then return own.found end
	return book.tabs[index]
end

-- A spell's secure attributes: type (left and right click), spell, macros, what a drag picks up.
local function Actions(item)
	if not item then return end
	local kind = item.kind
	if kind == "spell" then
		return "spell", "spell", item.spell or item.name, nil, nil, item.spell
	elseif kind == "flyout" then
		return "flyout", "flyout", item.action
	elseif kind == "pet" then
		return "spell", "macro", item.spell or item.name, nil, SLASH_PET_AUTOCASTTOGGLE1 .. " " .. item.name
	elseif kind == "command" then
		local slash = Commands()[item.name]
		return "macro", "macro", nil, slash, slash
	end
	-- Passive and future spells do nothing when clicked, as the game's book.
end

local written = {}   -- store attribute -> the value written last

local function Put(store, key, value)
	if written[key] == value then return end
	written[key] = value
	store:SetAttribute(key, value)
end

-- Writes every tab's spells into the store, and the holder's tab again so the page is set from it.
-- Out of a fight only; in one, the old book stays until it ends.
Bake = function()
	if not (M and M.on and own.holder) then return end
	if InCombatLockdown() then
		stale = true
		return
	end
	stale = false
	local tabs, found = Read()
	book.tabs, own.found = tabs, found
	local store = own.store
	local seen = {}
	local function Write(index, tab)
		Put(store, "n" .. index, #tab.items)
		seen["n" .. index] = true
		for n, item in ipairs(tab.items) do
			local key = index .. "_" .. n
			local t, u, s, m, r, p = Actions(item)
			for prefix, value in pairs({ t = t or false, u = u or false, s = s or false, m = m or false, r = r or false, p = p or false }) do
				Put(store, prefix .. key, value or nil)
				seen[prefix .. key] = true
			end
		end
	end
	for index, tab in ipairs(tabs) do Write(index, tab) end
	Write(0, found)
	for key in pairs(written) do
		if not seen[key] then Put(store, key, nil) end
	end
	-- The tabs: one secure button a tab.
	for i, button in ipairs(own.tabs) do
		local tab = tabs[i]
		if tab then button:Show() else button:Hide() end
	end
	local holder = own.holder
	local at = holder:GetAttribute("tab")
	local results = query ~= nil or missing == true
	if at == nil or (at ~= 0 and not tabs[at]) or (at == 0 and not results) then
		-- The first class tree, as the original opened on.
		at = (tabs[2] and not tabs[2].pet) and 2 or 1
	end
	holder:SetAttribute("tab", results and 0 or at)
end

Stale = function()
	if own.waiting then return end
	own.waiting = true
	C_Timer.After(0, function()
		own.waiting = false
		Bake()
	end)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function Text(parent, font, color, layer)
	return UI.Words(parent, font, color, { layer = layer })
end

local function Gradient(texture, direction, from, to)
	texture:SetColorTexture(1, 1, 1, 1)
	texture:SetGradient(direction, CreateColor(unpack(from)), CreateColor(unpack(to)))
end

-- A spell's tooltip, the game's own.
local function ShowSpell(self)
	local item = self.item
	if not item then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetSpellBookItem(item.slot, item.bank)
	-- The line the game's own book adds for a spell on none of your bars.
	if self.slot and self.slot.fresh then GameTooltip_AddColoredLine(GameTooltip, TALENT_BUTTON_TOOLTIP_NOT_ON_ACTION_BAR, LIGHTBLUE_FONT_COLOR) end
	GameTooltip:Show()
end

-- Shift-click: the spell's link in chat, or its name in the macro being written.
local function Link(self)
	local item = self.item
	if not item then return end
	if MacroFrameText and MacroFrameText:HasFocus() then
		if item.kind ~= "passive" then
			local sub = item.sub ~= "" and item.kind ~= "future" and ("(" .. item.sub .. ")") or ""
			ChatFrameUtil.InsertLink(item.name .. sub)
		end
		return
	end
	local link = C_SpellBook.GetSpellBookItemTradeSkillLink(item.slot, item.bank) or C_SpellBook.GetSpellBookItemLink(item.slot, item.bank)
	if link then ChatFrameUtil.InsertLink(link) end
end

-- A drag the holder's code didn't take (a pet's spell, a flyout): the game's own pickup.
local function Drag(self)
	local item = self.item
	if item and (item.kind == "pet" or item.kind == "command" or item.kind == "flyout") then
		C_SpellBook.PickupSpellBookItem(item.slot, item.bank)
	end
end

---------------------------------------------------------------------------
-- The click casting page
---------------------------------------------------------------------------
-- Pressing click casting's tab turns the book's page into the place clicks and keys are bound (ShyFrames'
-- bindings: a click on one of its unit frames, or a key pressed with the mouse on one, casts a spell on whoever
-- is in it). It is two steps, each said over its column, left to right:
--   1  Pick a spell   the left: your spells as a list, every castable spell in the book under its skill line's
--               name (All spells, the default) or the open tab's alone, with what a frame does anyway, Target and
--               Menu, at its head. A click picks one: it is lit, and stays picked. A skill line's tab on the spine
--               narrows the list to that line (the tab lit; pressed again, or All spells ticked, it is every
--               spell again); the search narrows it; All ranks adds the lower ranks; the wheel scrolls. A spell
--               that is bound says its clicks and keys in gold where its rank stood.
--   2  Give it a click or a key   the right: the pad shows the spell picked, and listens. Click the pad with the
--               mouse button you want, or press a key, with any of Shift, Ctrl and Alt held (what is held shows
--               on the pad as it is held). It is bound; the same again lets it go; another adds another.
--               Under the pad, every binding you have (ShyFrames' own list, T:ClickPanel): what was just bound is
--               lit there, a click on one lets it go, Undo takes the last change back.
-- Keys are the page's only while a spell is picked and the mouse is on the book: otherwise they are the game's.
-- The page is ours and unprotected, laid over the book's secure spells, which it never touches: a fight, the
-- tab pressed again, Done or the book closing takes it away and the book is as it was.

local PAGE = {
	top = 76,              -- the steps' names, down from the page's top
	step = 22,             -- a step's name over its column
	row = 36,              -- a spell of the list
	icon = 28,
	pad = 88,              -- the pad's height
	checks = 30,           -- the list's checks, under it
	gutter = 20,           -- between the two columns, the rule in its middle
	fade = 0.22, slide = 22,   -- arriving: the page fades in, the right column slides in from the right
	beat = 0.8,            -- the pad's light, while it listens
}
-- (The page is laid out by the room the book has, LayPage: the two columns share its width, the list is as
-- many rows as its height holds, the bindings take what is left under the pad. Nothing has a place of its own
-- that another piece could come to stand on.)

-- What a frame does anyway, bindable as a spell is: its name, what it is to ShyFrames.
local ACTS = {
	{ kind = "act", name = "Target", what = "target", sub = "What a left click does" },
	{ kind = "act", name = "Menu", what = "menu", sub = "What a right click does" },
}

-- Whether the list shows every spell in the book (the default) or the open tab's alone.
local function AllSpells()
	return ns.T.db.options.clickAll ~= false
end

-- The list: what a frame does anyway, then the spells that can go on a click, each skill line under its name
-- when it is every spell. A search's results stand alone.
--   -> the items, the open tab, and (every spell) where the open tab's line starts
local function PageItems()
	local at = Shown()
	local list, start = {}, nil
	local function Add(tab, head)
		local first = true
		for _, item in ipairs(tab and tab.items or {}) do
			if item.kind == "spell" and item.spell then
				if head and first then list[#list + 1] = { kind = "head", name = tab.name } end
				first = false
				list[#list + 1] = item
			end
		end
	end
	local found = TabAt(0)
	if at == 0 and found then
		Add(found)
		return list, at
	end
	for _, act in ipairs(ACTS) do list[#list + 1] = act end
	-- A skill line's tab pressed on the spine: that line's spells alone, until it is pressed again.
	local only = own.page and own.page.only
	if only and TabAt(only) then
		Add(TabAt(only))
	elseif AllSpells() then
		for i, tab in ipairs(book.tabs) do
			if not tab.pet then
				if i == at then start = #list end
				Add(tab, true)
			end
		end
	else
		Add(TabAt(at))
	end
	return list, at, start
end

-- What an item is to ShyFrames: a frame's own doing as itself, the highest rank by name, a lower rank by its ID.
local function What(item)
	if item.kind == "act" then return item.what, nil end
	return Bound(item)
end

-- The clicks and keys that cast it, in words: "Shift + Left click, F".
local function ClicksOf(frames, item)
	local words = {}
	for i, input in ipairs(frames:ClicksOf(What(item))) do words[i] = frames:ClickWords(input) end
	return table.concat(words, ", ")
end

-- Whether two items of the list are the same thing to bind.
local function Same(a, b)
	if not (a and b) then return false end
	local an, ai = What(a)
	local bn, bi = What(b)
	return an == bn and ai == bi
end

local DrawPage

-- A click made on the pad or a key pressed, with a spell picked: that input casts it on a unit frame from now
-- on; the same again lets it go.
local function Bind(item, input)
	local frames = Binder()
	if not (frames and item and input) then return end
	local name, id = What(item)
	local held = false
	for _, other in ipairs(frames:ClicksOf(name, id)) do
		if other == input then held = true end
	end
	local what = name or id
	if held then what = nil end
	local ok, why = frames:BindClick(input, what)
	own.page.table:Say((not ok and why) or nil)
	DrawPage()
end

-- What is held, in words, for the pad: "Ctrl + Shift".
local function HeldWords()
	local words = {}
	if IsAltKeyDown() then words[#words + 1] = "Alt" end
	if IsControlKeyDown() then words[#words + 1] = "Ctrl" end
	if IsShiftKeyDown() then words[#words + 1] = "Shift" end
	return table.concat(words, " + ")
end

-- The pad: the spell picked, and where its click is made.
local function DrawPad()
	local page, frames = own.page, Binder()
	local pad, item = page.pad, page.picked
	local picture = item and (item.icon or (item.what and frames:ClickIcon(item.what))) or nil
	pad.icon:SetShown(picture ~= nil)
	pad.slot:Empty(picture == nil)
	if picture then pad.icon:SetTexture(picture) end
	if not item then
		pad.name:SetText("No spell picked")
		UI.Ink(pad.name, C.dim)
		pad.words:SetText("")
		pad.hint:SetText("Pick a spell on the left first.")
		pad.glow:Hide()
		pad.breath:Stop()
		return
	end
	pad.name:SetText(item.name)
	UI.Ink(pad.name, C.text)
	local clicks = ClicksOf(frames, item)
	pad.words:SetText(clicks ~= "" and clicks or "Not bound yet")
	UI.Ink(pad.words, clicks ~= "" and C.alert or C.dim)
	local held = HeldWords()
	if held ~= "" then
		pad.hint:SetText(held .. " + ...   now click here, or press a key.")
	else
		pad.hint:SetText("Click here with any mouse button, or press a key. Hold Shift, Ctrl or Alt to add them.")
	end
	pad.glow:Show()
	if not pad.breath:IsPlaying() then pad.breath:Play() end
end

local function Pad(page)
	local pad = CreateFrame("Button", nil, page)
	local well = pad:CreateTexture(nil, "BACKGROUND")
	well:SetAllPoints()
	well:SetColorTexture(0, 0, 0, 0.38)
	local edge = pad:CreateTexture(nil, "BORDER")
	edge:SetAllPoints()
	edge:SetTexture(Skin.FRAME)
	edge:SetTextureSliceMargins(Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE, Skin.FRAME_SLICE)
	UI.Tint(edge, C.border)
	-- Listening: a light in from its edges, breathing. On a frame of its own, whose alpha is the light's.
	pad.glow = CreateFrame("Frame", nil, pad)
	pad.glow:SetAllPoints()
	pad.glow:SetFrameLevel(pad:GetFrameLevel())
	local soft = pad.glow:CreateTexture(nil, "ARTWORK")
	soft:SetAllPoints()
	soft:SetTexture(Skin.GLOW)
	soft:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	soft:SetBlendMode("ADD")
	UI.Tint(soft, Theme.Accent)
	pad.breath = pad.glow:CreateAnimationGroup()
	pad.breath:SetLooping("BOUNCE")
	local fade = pad.breath:CreateAnimation("Alpha")
	fade:SetFromAlpha(0.9)
	fade:SetToAlpha(0.3)
	fade:SetDuration(PAGE.beat)
	fade:SetSmoothing("IN_OUT")
	pad.glow:Hide()
	pad.icon = pad:CreateTexture(nil, "ARTWORK")
	pad.icon:SetSize(36, 36)
	pad.icon:SetPoint("TOPLEFT", 10, -10)
	pad.icon:SetTexCoord(unpack(ICON))
	pad.slot = Slot.New(pad, { to = pad.icon, icon = pad.icon, hover = false })
	pad.name = Text(pad, UI.TitleFont(14))
	pad.name:SetPoint("TOPLEFT", pad.icon, "TOPRIGHT", 8, -2)
	pad.name:SetWordWrap(false)
	pad.words = Text(pad, UI.TextFont(11), C.dim)
	pad.words:SetPoint("TOPLEFT", pad.name, "BOTTOMLEFT", 0, -2)
	pad.words:SetWordWrap(false)
	pad.hint = Text(pad, UI.TextFont(11), C.dim)
	pad.hint:SetPoint("BOTTOMLEFT", 10, 8)
	pad.hint:SetJustifyV("BOTTOM")
	pad:RegisterForClicks("AnyUp")
	pad:SetScript("OnClick", function(_, click)
		local frames = Binder()
		if frames and page.picked then Bind(page.picked, frames:ClickInput(click)) end
	end)
	pad:RegisterEvent("MODIFIER_STATE_CHANGED")
	pad:SetScript("OnEvent", function()
		if page:IsShown() then DrawPad() end
	end)
	return pad
end

local function PageRow(page, i)
	local row = CreateFrame("Button", nil, page)
	row:SetHeight(PAGE.row - 4)
	row:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, -(PAGE.top + PAGE.step + (i - 1) * PAGE.row))
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(PAGE.icon, PAGE.icon)
	row.icon:SetPoint("LEFT")
	row.icon:SetTexCoord(unpack(ICON))
	-- One light for the mouse on a row: a band from the picture's edge to the row's end. The slot has none of
	-- its own (seen in game on a row with no picture: a gold frame round an empty socket with a band starting
	-- under it, two lights that read as one broken).
	row.slot = Slot.New(row, { to = row.icon, icon = row.icon, hover = false })
	row.hot = row:CreateTexture(nil, "HIGHLIGHT")
	row.hot:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
	row.hot:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	-- Picked: a wash of your color behind its words, a line of light at its end.
	row.wash = row:CreateTexture(nil, "BACKGROUND")
	row.wash:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 4, 0)
	row.wash:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetWidth(2)
	row.mark:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.mark:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row.name = Text(row, UI.TitleFont(13))
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
	row.name:SetWordWrap(false)
	row.sub = Text(row, UI.TextFont(11), C.dim)
	row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
	row.sub:SetWordWrap(false)
	-- A skill line's name, where the list is every spell: its own row, no picture.
	row.head = Text(row, UI.TitleFont(12), C.head)
	row.head:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 4)
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetHeight(1)
	row.rule:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
	row.rule:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	row:SetScript("OnClick", function(self)
		local item = self.item
		if not item or item.kind == "head" then return end
		page.picked = item
		page.table:Say(nil)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		DrawPage()
	end)
	return row
end

local function BuildPage()
	local frame, frames = Frame(), Binder()
	local page = CreateFrame("Frame", nil, own.body)
	page:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -WIN.head)
	page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	page:SetFrameLevel(own.holder:GetFrameLevel() + 10)
	page:EnableMouse(true)          -- nothing under it is clicked
	page:EnableMouseWheel(true)
	page:Hide()
	page.offset = 0
	-- Its ground: the panel's own color, whole (the spells under it don't show through), deepening toward the
	-- foot; a rule under its head, and one between the columns.
	local ground = page:CreateTexture(nil, "BACKGROUND", nil, -2)
	ground:SetAllPoints()
	UI.Paint(ground, C.panel, 1)
	local depth = page:CreateTexture(nil, "BACKGROUND", nil, -1)
	depth:SetAllPoints()
	Gradient(depth, "VERTICAL", { 0, 0, 0, 0.42 }, { 0, 0, 0, 0 })
	local under = page:CreateTexture(nil, "BORDER")
	under:SetHeight(1)
	under:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -(PAGE.top - 12))
	under:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -(PAGE.top - 12))
	UI.Paint(under, C.border, 0.9)
	page.between = page:CreateTexture(nil, "BORDER")
	page.between:SetWidth(1)
	UI.Paint(page.between, C.border, 0.6)

	-- Its head: click casting's picture, its name, what it is for; Done at the far end, clear of the words.
	page.icon = page:CreateTexture(nil, "ARTWORK")
	page.icon:SetSize(36, 36)
	page.icon:SetPoint("TOPLEFT", GRID_X, -14)
	page.icon:SetTexCoord(unpack(ICON))
	page.icon:SetTexture(frames:ClickIcon())
	Slot.New(page, { to = page.icon, icon = page.icon, hover = false })
	page.done = UI.Button(page, "Done", 58, function()
		binding = false
		Draw()
	end)
	page.done:SetPoint("RIGHT", page, "TOPRIGHT", -GRID_X, -32)
	page.title = Text(page, UI.TitleFont(18), C.head)
	page.title:SetPoint("TOPLEFT", page.icon, "TOPRIGHT", 10, 2)
	page.title:SetText("Click casting")
	page.note = Text(page, UI.TextFont(12), C.dim)
	page.note:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -3)
	page.note:SetPoint("RIGHT", page.done, "LEFT", -12, 0)
	page.note:SetWordWrap(false)
	page.note:SetText("Cast on a unit frame with one click or key.")

	-- The two steps, named over their columns.
	local function Step(number, words)
		local n = Text(page, UI.TitleFont(14), C.head)
		n:SetText(number)
		UI.Ink(n, C.alert)
		local w = Text(page, UI.TitleFont(13), C.head)
		w:SetPoint("LEFT", n, "RIGHT", 7, 0)
		w:SetText(words)
		w.number = n
		return w
	end
	page.step1 = Step("1", "Pick a spell")
	page.step1.number:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, -PAGE.top)
	page.step2 = Step("2", "Give it a click or a key")

	-- The list, and what it lists.
	page.rows = {}
	page.none = Text(page, UI.TextFont(12), C.dim)
	page.none:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, -(PAGE.top + PAGE.step + 8))
	page.none:SetText("Nothing in your book by that name can go on a click.")
	page.thumb = page:CreateTexture(nil, "ARTWORK")
	page.thumb:SetWidth(3)
	UI.Paint(page.thumb, C.border)
	page:SetScript("OnMouseWheel", function(self, delta)
		self.offset = math.max(0, self.offset - delta)
		DrawPage()
	end)
	page.all = UI.Checkbox(page, "All spells", function() return AllSpells() and not page.only end, function(on)
		ns.T.db.options.clickAll = on
		page.only, page.offset = nil, 0
		Draw()
	end, { box = 14, size = 11, desc = "Lists every spell in your book. When off, you only see the open tab's spells." })
	page.ranks = UI.Checkbox(page, "All ranks", function() return C_CVar.GetCVarBool(CVAR.ranks) end, function(on)
		C_CVar.SetCVar(CVAR.ranks, on and "1" or "0")
		Bake()
	end, { box = 14, size = 11, desc = "Lists every rank of a spell you know, so you can bind a cheaper rank to its own click." })

	-- The pad, and under it every binding.
	page.pad = Pad(page)
	page.table = frames:ClickPanel(page)
	page.table.how = "Nothing bound yet."
	-- A binding let go or put back in the list itself: the spells say so too.
	page.table.changed = function()
		if page:IsShown() then DrawPage() end
	end

	-- A key pressed with a spell picked and the mouse on the book binds it; any other key is the game's
	-- (Escape closes the book).
	page:EnableKeyboard(true)
	page:SetScript("OnKeyDown", function(self, key)
		local binder = Binder()
		local input = self.picked and binder and self:IsMouseOver() and binder:ClickKeyInput(key)
		self:SetPropagateKeyboardInput(not input)
		if input then Bind(self.picked, input) end
	end)

	-- Arriving: the page fades in over the spells while the right column slides in from the right.
	page.arrive = page:CreateAnimationGroup()
	local fade = page.arrive:CreateAnimation("Alpha")
	fade:SetFromAlpha(0)
	fade:SetToAlpha(1)
	fade:SetDuration(PAGE.fade)
	fade:SetSmoothing("OUT")
	page.slides = {}
	for i, piece in ipairs({ page.pad, page.table }) do
		local slide = piece:CreateAnimationGroup()
		local from = slide:CreateAnimation("Translation")
		from:SetOffset(PAGE.slide, 0)
		from:SetDuration(0)
		from:SetOrder(1)
		local back = slide:CreateAnimation("Translation")
		back:SetOffset(-PAGE.slide, 0)
		back:SetDuration(PAGE.fade)
		back:SetSmoothing("OUT")
		back:SetOrder(2)
		page.slides[i] = slide
	end

	-- Away with the book, or in a fight: the spells under it cast again.
	page:SetScript("OnHide", function(self)
		binding = false
		self.only = nil
		self:Hide()
	end)
	page:RegisterEvent("PLAYER_REGEN_DISABLED")
	page:SetScript("OnEvent", function(self)
		if not binding then return end
		self:Hide()
		Draw()
	end)
	own.page = page
end

-- The page laid out for the book's size: the two columns share its width (the list a little the wider), the
-- list is as many rows as its height holds over its checks, and under the pad the bindings take the rest.
local function LayPage()
	local page = own.page
	local width, height = fit.w - 4, fit.h - WIN.head - 2
	local inner = width - 2 * GRID_X - PAGE.gutter
	local right = math.floor(inner * 0.48)
	local left = inner - right
	local top = PAGE.top + PAGE.step
	local count = math.max(3, math.floor((height - top - PAGE.checks - 12) / PAGE.row))
	for i = #page.rows + 1, count do page.rows[i] = PageRow(page, i) end
	for i, row in ipairs(page.rows) do
		row:SetWidth(left)
		row.name:SetWidth(left - PAGE.icon - 12)
		row.sub:SetWidth(left - PAGE.icon - 12)
		if i > count then row:Hide() end
	end
	page.none:SetWidth(left)
	local foot = top + count * PAGE.row + 8
	page.all:ClearAllPoints()
	page.all:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X, -foot)
	page.ranks:ClearAllPoints()
	page.ranks:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X + 96, -foot)
	local x = GRID_X + left + PAGE.gutter
	page.between:ClearAllPoints()
	page.between:SetPoint("TOPLEFT", page, "TOPLEFT", x - PAGE.gutter / 2, -PAGE.top)
	page.between:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", x - PAGE.gutter / 2, 14)
	page.step2.number:ClearAllPoints()
	page.step2.number:SetPoint("TOPLEFT", page, "TOPLEFT", x, -PAGE.top)
	local pad = page.pad
	pad:ClearAllPoints()
	pad:SetPoint("TOPLEFT", page, "TOPLEFT", x, -top)
	pad:SetSize(right, PAGE.pad)
	pad.name:SetWidth(right - 36 - 28)
	pad.words:SetWidth(right - 36 - 28)
	pad.hint:SetWidth(right - 20)
	page.table:ClearAllPoints()
	page.table:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(top + PAGE.pad + 10))
	page.table:Fit(right, height - (top + PAGE.pad + 10) - 12)
	page.left, page.count = left, count
	page.laid = fit.w .. "x" .. fit.h
end

DrawPage = function()
	local page, frames = own.page, Binder()
	if not (page and frames) then return end
	if page.laid ~= fit.w .. "x" .. fit.h then LayPage() end
	local items, at, start = PageItems()
	local most = math.max(0, #items - page.count)
	-- A skill line's tab pressed on the spine: the list comes to that line (every spell), or is that tab's.
	if at ~= page.at then
		page.at = at
		page.offset = start or 0
	end
	page.offset = math.min(page.offset, most)
	for i = 1, page.count do
		local row = page.rows[i]
		local item = items[page.offset + i]
		row.item = item
		row:SetShown(item ~= nil)
		if item then
			local head = item.kind == "head"
			-- What a frame does anyway has a picture too (ShyFrames' own), so no row stands on an empty socket.
			local picture = item.icon or (item.what and frames:ClickIcon(item.what)) or nil
			local picked = not head and Same(item, page.picked)
			row.head:SetShown(head)
			row.rule:SetShown(head)
			row.icon:SetShown(not head and picture ~= nil)
			-- A skill line's name stands on no socket at all: not its frame, not its well.
			row.slot:Set({ to = row.icon, icon = row.icon, hover = false, well = not head })
			row.slot:Bare(head)
			row.slot:Empty(not head and picture == nil)
			row.name:SetShown(not head)
			row.sub:SetShown(not head)
			row.hot:SetShown(not head)
			row.wash:SetShown(picked)
			row.mark:SetShown(picked)
			if head then
				row.head:SetText(item.name)
				UI.Paint(row.rule, C.border, 0.7)
			else
				if picture then row.icon:SetTexture(picture) end
				row.name:SetText(item.name)
				UI.Ink(row.name, C.text)
				local hot = C.hot
				Gradient(row.hot, "HORIZONTAL", { hot[1], hot[2], hot[3], 0.22 }, { hot[1], hot[2], hot[3], 0 })
				if picked then
					local r, g, b = Theme.Accent()
					Gradient(row.wash, "HORIZONTAL", { r, g, b, 0.08 }, { r, g, b, 0.34 })
					row.mark:SetColorTexture(1, 1, 1, 1)
					row.mark:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
				end
				-- Its clicks and keys where its rank stands, in gold: what is bound reads at a glance down the list.
				local clicks = ClicksOf(frames, item)
				if clicks ~= "" then
					row.sub:SetText(clicks)
					UI.Ink(row.sub, C.alert)
				else
					row.sub:SetText(item.sub or "")
					UI.Ink(row.sub, C.dim)
				end
			end
		end
	end
	page.none:SetShown(#items == 0)
	-- How far down the list stands: a hair beside it, as long as the share of it on show.
	page.thumb:SetShown(most > 0)
	if most > 0 then
		local track = page.count * PAGE.row - 4
		local long = math.max(16, track * page.count / #items)
		page.thumb:SetHeight(long)
		page.thumb:ClearAllPoints()
		page.thumb:SetPoint("TOPLEFT", page, "TOPLEFT", GRID_X + page.left + 3, -(PAGE.top + PAGE.step + (track - long) * page.offset / most))
	end
	local _, class = UnitClass("player")
	page.all:Refresh()
	page.ranks:SetShown(class ~= "ROGUE" and class ~= "WARRIOR")
	page.ranks:Refresh()
	DrawPad()
	page.table:Refresh()
end

-- Click casting's tab on the spine, the last of them: it turns no page of spells, it turns the page into click
-- casting's. The side tab's make, with click casting's own picture. Ours and unprotected; there only with
-- ShyFrames (DrawTabs).
local function ClickTab(parent, level)
	local tab = CreateFrame("Button", "ShySkinSpellClicks", parent)
	tab:SetSize(TAB.w, TAB.h)
	tab:SetFrameLevel(level)
	tab.wash = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
	tab.wash:SetPoint("TOPLEFT", 0, 1)
	tab.wash:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.hot = tab:CreateTexture(nil, "HIGHLIGHT")
	tab.hot:SetPoint("TOPLEFT", 0, 1)
	tab.hot:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.line = tab:CreateTexture(nil, "ARTWORK")
	tab.line:SetPoint("TOPLEFT")
	tab.line:SetPoint("BOTTOMLEFT")
	tab.line:SetWidth(2)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(TAB_ICON, TAB_ICON)
	tab.icon:SetPoint("CENTER", tab, "CENTER", TAB.x, 0)
	tab.icon:SetTexCoord(unpack(ICON))
	tab.slot = Slot.New(tab, { to = tab.icon, icon = tab.icon })
	tab:SetScript("OnEnter", function(self)
		self.over = true
		UI.Tip(self, "Click casting", "Bind clicks on your unit frames to spells.", { side = "RIGHT" })
		if Draw then Draw() end
	end)
	tab:SetScript("OnLeave", function(self)
		self.over = false
		UI.TipHide(self)
		if Draw then Draw() end
	end)
	tab:SetScript("OnClick", function()
		if InCombatLockdown() and not binding then
			ns.T:Print("you can bind clicks once the fight is over.")
			return
		end
		binding = not binding
		PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
		Draw()
	end)
	return tab
end

local function Cell(holder, i)
	local cell = CreateFrame("Button", "ShySkinSpell" .. i, holder, "SecureActionButtonTemplate")
	cell:SetSize(CELL_W, SLOT)
	local column, row = math.floor((i - 1) / ROWS), (i - 1) % ROWS
	cell:SetPoint("TOPLEFT", holder, "TOPLEFT", GRID_X + column * COL, -(GRID_Y + row * ROW))
	-- On the release only, as the game's own book: a press can start a drag, and a drag must not cast.
	cell:RegisterForClicks("AnyUp")
	cell:SetAttribute("useOnKeyDown", false)
	cell:RegisterForDrag("LeftButton")
	cell:SetAttribute("checkselfcast", true)
	cell:SetAttribute("checkfocuscast", true)
	cell:SetAttribute("flyoutDirection", "RIGHT")
	cell:SetAttribute("shift-type1", "link")
	cell:SetAttribute("shift-type2", "link")
	cell.link = Link

	cell.back = cell:CreateTexture(nil, "BACKGROUND", nil, 1)
	cell.back:SetPoint("TOPLEFT", 18, -2)
	cell.back:SetPoint("BOTTOMRIGHT", -2, 2)
	cell.hot = cell:CreateTexture(nil, "HIGHLIGHT")
	cell.hot:SetPoint("TOPLEFT", 18, -2)
	cell.hot:SetPoint("BOTTOMRIGHT", -2, 2)
	cell.icon = cell:CreateTexture(nil, "ARTWORK")
	cell.icon:SetSize(SLOT, SLOT)
	cell.icon:SetPoint("LEFT")
	cell.icon:SetTexCoord(unpack(ICON))
	cell.slot = Slot.New(cell, { to = cell.icon, icon = cell.icon })
	cell.auto = cell:CreateTexture(nil, "OVERLAY", nil, 1)
	cell.slot:Light(cell.auto)
	cell.auto:Hide()
	cell.cooldown = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
	cell.cooldown:SetAllPoints(cell.icon)
	cell.cooldown:SetDrawEdge(false)
	Slot.Swipe(cell.cooldown)
	cell.name = Text(cell, UI.TitleFont(14))
	cell.name:SetWidth(TEXT_W)
	cell.name:SetMaxLines(2)
	cell.name:SetWordWrap(true)
	cell.sub = Text(cell, UI.TextFont(12), C.dim)
	cell.sub:SetWidth(TEXT_W)
	cell.sub:SetWordWrap(false)

	cell:SetScript("OnEnter", ShowSpell)
	cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cell.UpdateTooltip = ShowSpell
	cell:SetScript("OnDragStart", Drag)
	SecureHandlerWrapScript(cell, "OnDragStart", holder, DRAG)
	holder:SetFrameRef("cell" .. i, cell)
	return cell
end

-- The page's cells as the book stands: as many as a page holds (made as they are first needed), each column
-- filled before the next, the columns sharing the page's width. Secure buttons: out of a fight only.
local function LayCells()
	local holder = own.holder
	for i = #own.cells + 1, fit.per do own.cells[i] = Cell(holder, i) end
	for i, cell in ipairs(own.cells) do
		if i <= fit.per then
			local column, row = math.floor((i - 1) / fit.rows), (i - 1) % fit.rows
			cell:ClearAllPoints()
			cell:SetPoint("TOPLEFT", holder, "TOPLEFT", GRID_X + column * (fit.cell + 2 * GAP), -(GRID_Y + row * ROW))
			cell:SetSize(fit.cell, SLOT)
			cell.name:SetWidth(fit.cell - TEXT_X - 2)
			cell.sub:SetWidth(fit.cell - TEXT_X - 2)
			cell:Show()
		else
			cell:Hide()
		end
	end
	holder:SetAttribute("per", fit.per)
end

local function Tab(holder, i)
	local tab = CreateFrame("Button", "ShySkinSpellTab" .. i, holder, "SecureActionButtonTemplate")
	tab:SetSize(TAB.w, TAB.h)
	tab:SetID(i)
	tab:SetPoint("TOPLEFT", Frame(), "TOPRIGHT", 0, -(TAB.top + (i - 1) * TAB_PITCH))
	tab:RegisterForClicks("AnyUp", "AnyDown")
	tab:SetAttribute("type1", "tab")
	tab:SetAttribute("_tab", PICK_TAB)
	-- The character window's side tab: a slot, a wash of your color and a line of light when open.
	tab.wash = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
	tab.wash:SetPoint("TOPLEFT", 0, 1)
	tab.wash:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.hot = tab:CreateTexture(nil, "HIGHLIGHT")
	tab.hot:SetPoint("TOPLEFT", 0, 1)
	tab.hot:SetPoint("BOTTOMRIGHT", 0, -1)
	tab.line = tab:CreateTexture(nil, "ARTWORK")
	tab.line:SetPoint("TOPLEFT")
	tab.line:SetPoint("BOTTOMLEFT")
	tab.line:SetWidth(2)
	tab.rule = tab:CreateTexture(nil, "ARTWORK")
	tab.rule:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 5, 0)
	tab.rule:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", -5, 0)
	tab.rule:SetHeight(1)
	tab.icon = tab:CreateTexture(nil, "ARTWORK")
	tab.icon:SetSize(TAB_ICON, TAB_ICON)
	tab.icon:SetPoint("CENTER", tab, "CENTER", TAB.x, 0)
	tab.icon:SetTexCoord(unpack(ICON))
	tab.slot = Slot.New(tab, { to = tab.icon, icon = tab.icon })
	-- A spell learned here and not seen yet: gold light round the slot.
	tab.new = tab:CreateTexture(nil, "OVERLAY")
	tab.slot:Light(tab.new, C.alert)
	tab.new:Hide()
	tab:SetScript("OnEnter", function(self)
		self.over = true
		local item = book.tabs[self:GetID()]
		if item then UI.Tip(self, item.name, nil, { side = "RIGHT" }) end
		if Draw then Draw() end
	end)
	tab:SetScript("OnLeave", function(self)
		self.over = false
		UI.TipHide(self)
		if Draw then Draw() end
	end)
	tab:HookScript("PostClick", function(self, _, down)
		if down then return end
		PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
		-- On click casting's page a skill line's tab narrows the list to that line; pressed again, every spell.
		local page = own.page
		if binding and page then
			local id = self:GetID()
			page.only = page.only ~= id and id or nil
			page.offset = 0
			if Draw then Draw() end
		end
	end)
	return tab
end

local function Arrow(holder, step)
	local arrow = CreateFrame("Button", nil, holder, "SecureActionButtonTemplate")
	arrow:SetSize(ARROW, ARROW)
	if step < 0 then
		arrow:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", PAD, PAD)
	else
		arrow:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -PAD, PAD)
	end
	arrow:RegisterForClicks("AnyUp", "AnyDown")
	arrow:SetAttribute("type1", "turn")
	arrow:SetAttribute("_turn", PICK_TURN)
	arrow:SetAttribute("step", step)
	arrow.glyph = arrow:CreateTexture(nil, "OVERLAY")
	arrow.glyph:SetTexture(Skin.GLYPH.caret)
	arrow.glyph:SetSize(10, 10)
	arrow.glyph:SetPoint("CENTER")
	arrow.glyph:SetRotation(step < 0 and -math.pi / 2 or math.pi / 2)
	UI.Concentric(arrow.glyph)
	-- The family's button make. A secure button can't be disabled in a fight: at the first or last page it is
	-- dimmed instead (its click turns nothing there), as a shop's button out of use.
	UI.KeyPress(arrow, { glyphs = { arrow.glyph }, sink = { arrow.glyph } })
	function arrow:SetOff(off)
		self.off = off
		self.dimmed = off
		self:SetAlpha(off and 0.4 or 1)
		self:SetOn(false)   -- paints it again
	end
	arrow:HookScript("PostClick", function(self, _, down) if not down and not self.off then PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN) end end)
	return arrow
end

local function Search(body)
	local box = CreateFrame("EditBox", nil, body)
	box:SetSize(SEARCH_W, CONTROL)
	box:SetAutoFocus(false)
	box:SetFontObject(UI.TextFont(11))
	box:SetTextInsets(19, 4, 0, 0)
	box:SetMaxLetters(40)
	UI.Skin(box, C.bg, C.border)
	box.glass = box:CreateTexture(nil, "OVERLAY")
	box.glass:SetSize(10, 10)
	box.glass:SetPoint("LEFT", 5, 0)
	box.glass:SetAtlas("common-search-magnifyingglass")
	box.glass:SetDesaturated(true)
	UI.Tint(box.glass, C.dim)
	box.hint = Text(box, UI.TextFont(11), C.dim)
	box.hint:SetPoint("LEFT", 19, 0)
	box.hint:SetText(SEARCH)
	box:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEditFocusGained", function(self) UI.SetBorder(self, C.hot) end)
	box:SetScript("OnEditFocusLost", function(self) UI.SetBorder(self, C.border) end)
	box:SetScript("OnTextChanged", function(self)
		local text = strtrim(self:GetText() or "")
		self.hint:SetShown(text == "")
		local was = query
		query = text ~= "" and text:lower() or nil
		if query ~= was then Bake() end
	end)
	return box
end

-- The settings that change what the book lists, the game's own.
local function Settings(body)
	local function Flip(cvar)
		return function()
			C_CVar.SetCVar(cvar, C_CVar.GetCVarBool(cvar) and "0" or "1")
			Bake()
		end
	end
	local gear = UI.MenuButton(body, { height = CONTROL, tip = "What the book lists", menu = { align = "RIGHT" }, write = function(root)
		root:CreateSection("Show in the book")
		local fight = InCombatLockdown()
		local passives = root:CreateCheckbox("Passive spells", function() return not C_CVar.GetCVarBool(CVAR.passives) end, Flip(CVAR.passives))
		passives:SetIcon(UI.MenuGlyph("shows"))
		passives:SetEnabled(not fight)
		local flyouts = root:CreateCheckbox("Spells grouped in flyouts", function() return not C_CVar.GetCVarBool(CVAR.flyouts) end, Flip(CVAR.flyouts))
		flyouts:SetIcon(UI.MenuGlyph("log"))
		flyouts:SetSub("Turn off to list each one separately")
		flyouts:SetEnabled(not fight)
		if fight then passives:SetSub("After the fight") end
		root:CreateSection("Show only")
		local bars = root:CreateCheckbox("Missing from your bars", function() return missing == true end, function()
			missing = not missing
			Bake()
		end)
		bars:SetIcon(UI.MenuGlyph("point"))
		bars:SetSub(fight and "After the fight" or "Spells not on your bars yet")
		bars:SetEnabled(not fight)
	end })
	-- The cog and its caret, evenly spaced (no words).
	gear:SetGlyph(Skin.GLYPH.gear)
	return gear
end

local function Build()
	local frame, spells = Frame(), Book()
	local body = CreateFrame("Frame", nil, spells)
	body:SetAllPoints(frame)
	own.body = body

	own.lead = Text(body, UI.TitleFont(18), C.head)
	own.lead:SetPoint("TOPLEFT", body, "TOPLEFT", GRID_X, -(WIN.head + 12))
	own.lead:SetWidth(W - 2 * GRID_X - 110)
	own.lead:SetWordWrap(false)

	own.ranks = UI.Checkbox(body, "All ranks", function() return C_CVar.GetCVarBool(CVAR.ranks) end, function(on)
		C_CVar.SetCVar(CVAR.ranks, on and "1" or "0")
		Bake()
	end, { box = 14, size = 11, enabled = function() return not InCombatLockdown() end,
		desc = "Lists every rank of a spell you know, not only the highest." })
	-- On the tree's name's middle line.
	own.ranks:SetPoint("RIGHT", body, "TOPRIGHT", -GRID_X, -(WIN.head + 12 + 9))

	own.none = Text(body, UI.TextFont(12), C.dim)
	own.none:SetPoint("TOP", body, "TOP", 0, -(GRID_Y + 2 * ROW))
	own.none:SetText("Nothing in your book by that name.")

	own.rule = body:CreateTexture(nil, "ARTWORK")
	own.rule:SetHeight(1)
	own.rule:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 10, FOOT)
	own.rule:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -10, FOOT)
	own.pageText = Text(body, UI.TitleFont(14), C.head)
	own.pageText:SetJustifyH("CENTER")
	own.pageText:SetPoint("CENTER", body, "BOTTOM", 0, PAD + ARROW / 2)

	own.search = Search(body)
	own.gear = Settings(body)   -- laid on the header row beside the × when the book is painted (PaintBook)
	-- Over the title strip, where a window mover lays its drag handle over the game's title.
	local title = frame.TitleContainer
	local level = math.max(body:GetFrameLevel(), title and title:GetFrameLevel() or 0) + 10
	own.search:SetFrameLevel(level)
	own.gear:SetFrameLevel(level)

	-- The secure holder: the spells, the tabs, the arrows and the wheel.
	local holder = CreateFrame("Frame", "ShySkinBook", spells, "SecureHandlerAttributeTemplate")
	holder:SetAllPoints(frame)
	holder:SetFrameLevel(body:GetFrameLevel() + 4)
	holder:SetAttribute("_onattributechanged", TURN)
	own.holder = holder
	own.store = CreateFrame("Frame", nil, holder, "SecureFrameTemplate")
	holder:SetFrameRef("store", own.store)
	local wheel = CreateFrame("Frame", nil, holder, "SecureHandlerMouseWheelTemplate")
	wheel:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -WIN.head)
	wheel:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
	wheel:SetFrameLevel(holder:GetFrameLevel())
	wheel:EnableMouseWheel(true)
	wheel:SetAttribute("_onmousewheel", WHEEL)
	own.cells, own.tabs = {}, {}
	for i = 1, PER do own.cells[i] = Cell(holder, i) end
	-- Tabs enough for the game's skill lines and a pet's book.
	for i = 1, 8 do own.tabs[i] = Tab(holder, i) end
	own.prev, own.next = Arrow(holder, -1), Arrow(holder, 1)
	holder:HookScript("OnAttributeChanged", function(_, name, value)
		if name ~= "shown" or not M.on then return end
		-- A skill line's tab picked from the results: the search and the filter are done with.
		if (query or missing) and type(value) == "string" and not value:find("^0:") then
			missing = false
			if own.search:GetText() ~= "" then own.search:SetText("") else query = nil end
		end
		Draw()
	end)
	own.clicks = ClickTab(body, holder:GetFrameLevel() + 1)
	own.clicks:Hide()
	-- The results' message over the empty page, above the holder's buttons.
	local over = CreateFrame("Frame", nil, spells)
	over:SetAllPoints(frame)
	over:SetFrameLevel(holder:GetFrameLevel() + 20)
	own.none:SetParent(over)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

-- The page: the window under its head, or the look's well when it sinks one (UI.LOOK_ZONES), so the well's
-- rim frames it.
local function Inset()
	local zone = UI.LOOK_ZONES[Theme.Look()]
	return zone and zone.well and zone.well.IN or 2
end

-- The page's ground: the tree's painting, falling away into the window's graphite at its edges (the burns). It
-- lies on the window itself, as the character window's ground does: a frame of ours would stand over the
-- window's housing, the well's rim with it, and over the words in the page's head and foot.
local function Ground(kit)
	local f, n = Frame(), Inset()
	own.inset = n
	own.art = ns.Own(kit, f, "bookArt", function(o) return o:CreateTexture(nil, "BACKGROUND", nil, 2) end)
	own.art:ClearAllPoints()
	own.art:SetPoint("TOPLEFT", f, "TOPLEFT", n, -WIN.head)
	own.art:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -n, n)
	own.burns = {}
	for i, side in ipairs(BURNS) do
		local t = ns.Own(kit, f, "bookBurn" .. i, function(o) return o:CreateTexture(nil, "BACKGROUND", nil, 3) end)
		t:ClearAllPoints()
		if side == "TOP" or side == "BOTTOM" then
			t:SetPoint(side .. "LEFT", own.art)
			t:SetPoint(side .. "RIGHT", own.art)
		elseif side == "LEFT" or side == "RIGHT" then
			t:SetPoint("TOP" .. side, own.art)
			t:SetPoint("BOTTOM" .. side, own.art)
		else
			t:SetAllPoints(own.art)
		end
		t.side = side
		own.burns[i] = t
	end
end

-- On the window, the ground shows with the book alone (not under the talents).
local function ShowGround()
	if not own.art then return end
	local on = M.on and Book():IsShown()
	own.art:SetShown(on and own.painted == true)
	for _, t in ipairs(own.burns) do t:SetShown(on) end
end

-- The tree's painting: one third of the class's picture from the talent window, cut to the page.
local function Painting(tab)
	local art = own.art
	local f = Frame()
	local visuals = ClassTalentUtil and ClassTalentUtil.GetVisualsForSpecID(f:GetSpecID())
	local atlas = visuals and visuals.background
	local info = atlas and tab and tab.tree and C_Texture.GetAtlasInfo(atlas)
	own.painted = info ~= nil and info.file ~= nil
	if not own.painted then return end
	local l, r = info.leftTexCoord, info.rightTexCoord
	local third = (r - l) / 3
	local w, h = fit.w - 2 * own.inset, fit.h - WIN.head - own.inset
	-- The page is wider for its height than a third of the picture: its full width, a band of its height.
	local band = math.min(1, (w / h) / ((info.width / 3) / info.height))
	local tall = info.bottomTexCoord - info.topTexCoord
	local top = info.topTexCoord + tall * (1 - band) * ART.top
	art:SetTexture(info.file)
	art:SetTexCoord(l + third * (tab.tree - 1), l + third * tab.tree, top, top + tall * band)
	art:SetAlpha(ART.alpha)
	art:SetVertexColor(0.95, 0.95, 0.95)
end

local function Burns()
	local p = C.panel
	local solid, clear = { p[1], p[2], p[3], 0.96 }, { p[1], p[2], p[3], 0 }
	for _, t in ipairs(own.burns) do
		local side = t.side
		if side == "TOP" then
			t:SetHeight(110)
			Gradient(t, "VERTICAL", clear, solid)
		elseif side == "BOTTOM" then
			t:SetHeight(150)
			Gradient(t, "VERTICAL", { p[1], p[2], p[3], 0.92 }, clear)
		elseif side == "LEFT" then
			t:SetWidth(70)
			Gradient(t, "HORIZONTAL", { p[1], p[2], p[3], 0.6 }, clear)
		elseif side == "RIGHT" then
			t:SetWidth(70)
			Gradient(t, "HORIZONTAL", clear, { p[1], p[2], p[3], 0.6 })
		else
			t:SetColorTexture(p[1], p[2], p[3], 0.12)
		end
	end
end

-- The spell's state that changes while the page stands: cooldown, autocast, icon, not on any bar.
local function Live(cell)
	local item = cell.item
	if not item then
		cell.cooldown:Clear()
		cell.auto:Hide()
		return
	end
	-- In a fight its numbers can be secret, and SetCooldown refuses a secret from us: the cooldown is left
	-- as it was last shown, and set again with real numbers once they can be read (the page's next refresh).
	local cooldown = C_SpellBook.GetSpellBookItemCooldown(item.slot, item.bank)
	if cooldown then
		local start, duration, rate = cooldown.startTime, cooldown.duration, cooldown.modRate
		if not (issecretvalue(start) or issecretvalue(duration) or issecretvalue(rate)) then
			cell.cooldown:SetCooldown(start, duration, rate)
		end
	else
		cell.cooldown:Clear()
	end
	local allowed, on = false, false
	if item.bank == Enum.SpellBookSpellBank.Pet then allowed, on = C_SpellBook.GetSpellBookItemAutoCast(item.slot, item.bank) end
	if allowed and on then
		cell.auto:SetVertexColor(Theme.Accent())
		cell.auto:Show()
	else
		cell.auto:Hide()
	end
	local texture = C_SpellBook.GetSpellBookItemTexture(item.slot, item.bank)
	cell.icon:SetTexture(texture or item.icon)
	local info = C_SpellBook.GetSpellBookItemInfo(item.slot, item.bank)
	cell.slot:Fresh(info ~= nil and Missing(item, info))
end

local function Lay(cell)
	-- The name over its rank, the two together in the middle of the slot's height.
	local nameH = cell.name:GetStringHeight()
	local sub = cell.sub:GetText()
	local subH = (sub and sub ~= "") and cell.sub:GetStringHeight() + 1 or 0
	local top = math.floor((SLOT - nameH - subH) / 2 + 0.5)
	cell.name:ClearAllPoints()
	cell.name:SetPoint("TOPLEFT", cell, "TOPLEFT", TEXT_X, -top)
	cell.sub:ClearAllPoints()
	cell.sub:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -1)
end

-- bare: a results page has no empty sockets after its last spell (they read as more to find).
local function DrawCell(cell, item, bare)
	cell.item = item
	local p = C.panel
	if not item then
		cell.icon:Hide()
		cell.name:SetText("")
		cell.sub:SetText("")
		cell.back:Hide()
		cell.slot:Empty(true)
		cell.slot:Set({ to = cell.icon, icon = cell.icon, hover = false, well = not bare })
		cell.slot:Bare(bare)
		cell.slot:Fresh(false)
		cell.hot:Hide()
		Live(cell)
		return
	end
	cell.icon:Show()
	cell.hot:Show()
	cell.back:Show()
	Gradient(cell.back, "HORIZONTAL", { p[1], p[2], p[3], 0.72 }, { p[1], p[2], p[3], 0 })
	local hot = C.hot
	Gradient(cell.hot, "HORIZONTAL", { hot[1], hot[2], hot[3], 0.2 }, { hot[1], hot[2], hot[3], 0 })
	cell.slot:Set({ to = cell.icon, icon = cell.icon })
	cell.slot:Bare(false)
	cell.slot:Empty(item.kind == "future")
	if item.kind == "passive" then cell.slot:Steel(SC.idle) else cell.slot:Steel() end
	local later = item.kind == "future"
	cell.icon:SetDesaturated(later)
	cell.icon:SetAlpha(later and 0.6 or 1)
	cell.name:SetText(item.name)
	UI.Ink(cell.name, later and C.dim or (item.kind == "passive" and C.head) or C.text)
	cell.name:SetAlpha(item.kind == "passive" and 0.82 or 1)
	cell.sub:SetText(item.sub or "")
	UI.Ink(cell.sub, later and C.alert or C.dim)
	Lay(cell)
	Live(cell)
end

local function DrawTabs(at)
	local last
	for i, button in ipairs(own.tabs) do
		local tab = book.tabs[i]
		if tab then
			last = button
			button.icon:SetTexture(tab.icon)
			local open = i == at
			-- On click casting's page a tab is lit while the list is its line's alone.
			if binding and own.page then
				open = own.page.only == i or (own.page.only == nil and not AllSpells() and i == at)
			end
			button.slot:Steel(open and SC.hover or nil)
			local r, g, b = Theme.Accent()
			button.wash:SetShown(open)
			Gradient(button.wash, "HORIZONTAL", { r, g, b, 0.3 }, { r, g, b, 0 })
			local hot = SC.hover
			Gradient(button.hot, "HORIZONTAL", { hot[1], hot[2], hot[3], 0.16 }, { hot[1], hot[2], hot[3], 0 })
			button.line:SetShown(open)
			button.line:SetColorTexture(1, 1, 1, 1)
			button.line:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
			UI.Paint(button.rule, C.border)
			local v = (open or button.over) and 1 or DIM
			button.icon:SetVertexColor(v, v, v)
			if open and tab.line then new[tab.line] = nil end
			button.new:SetShown(tab.line ~= nil and new[tab.line] == true)
		end
	end
	for i, button in ipairs(own.tabs) do
		button.rule:SetShown(book.tabs[i] ~= nil and button ~= last)
	end
	-- Click casting's tab, under the last of them.
	local clicks, frames = own.clicks, Binder()
	if clicks then
		clicks:SetShown(frames ~= nil)
		if frames then
			local count = 0
			for i in ipairs(own.tabs) do
				if book.tabs[i] then count = i end
			end
			clicks:ClearAllPoints()
			clicks:SetPoint("TOPLEFT", Frame(), "TOPRIGHT", 0, -(TAB.top + count * TAB_PITCH))
			if last then last.rule:Show() end   -- the rule between it and the tab over it
			clicks.icon:SetTexture(frames:ClickIcon())
			clicks.slot:Steel(binding and SC.hover or nil)
			local r, g, b = Theme.Accent()
			clicks.wash:SetShown(binding)
			Gradient(clicks.wash, "HORIZONTAL", { r, g, b, 0.3 }, { r, g, b, 0 })
			local hot = SC.hover
			Gradient(clicks.hot, "HORIZONTAL", { hot[1], hot[2], hot[3], 0.16 }, { hot[1], hot[2], hot[3], 0 })
			clicks.line:SetShown(binding)
			clicks.line:SetColorTexture(1, 1, 1, 1)
			clicks.line:SetGradient("VERTICAL", CreateColor(Shy.Brand.Ramp(0)), CreateColor(Shy.Brand.Ramp(1)))
			local v = (binding or clicks.over) and 1 or DIM
			clicks.icon:SetVertexColor(v, v, v)
			last = clicks
		end
	end
	if own.spine then own.spine:Fit(OnBook() and last or nil) end
end

Draw = function()
	if not (M and M.on and own.holder) then return end
	local at, page, pages = Shown()
	local tab = TabAt(at)
	local items = tab and tab.items or {}
	local results = tab ~= nil and tab.search == true
	for i, cell in ipairs(own.cells) do
		if i <= fit.per then DrawCell(cell, items[(page - 1) * fit.per + i], results) end
	end
	-- The results page's head: the search's words, or what it shows.
	local lead = tab and tab.name or ""
	if results then
		local words = query and ("\"" .. (own.search:GetText() or "") .. "\"")
		lead = (words and missing) and (words .. ", missing from your bars") or words or "Missing from your bars"
	end
	own.lead:SetText(lead)
	-- Click casting's page over the spells, while its tab is the open one.
	local frames = binding and Binder()
	if frames and not own.page then BuildPage() end
	if own.page then
		local was = own.page:IsShown()
		own.page:SetShown(frames and true or false)
		if frames then
			DrawPage()
			if not was then
				own.page.arrive:Play()
				for _, slide in ipairs(own.page.slides) do slide:Play() end
			end
		end
	end
	own.none:SetText(query and "Nothing in your book by that name." or "Every spell you can place is on your bars.")
	own.none:SetShown(results and #items == 0)
	own.pageText:SetText(PAGE_NUMBER:format(page))
	own.pageText:SetShown(pages > 1 or #items > 0)
	own.prev:SetOff(page <= 1)
	own.next:SetOff(page >= pages)
	UI.Paint(own.rule, C.border, 0.9)
	-- The ranks check: not for a class whose spells have no ranks, nor a pet's book (as the game's).
	local _, class = UnitClass("player")
	own.ranks:SetShown(not (tab and tab.pet) and class ~= "ROGUE" and class ~= "WARRIOR")
	own.ranks:Refresh()
	if own.art then
		Painting(tab)
		Burns()
	end
	ShowGround()
	DrawTabs(at)
end

-- Cooldowns and autocast while the page stands.
local function Tick()
	if not (M and M.on and own.holder and OnBook()) then return end
	for _, cell in ipairs(own.cells) do Live(cell) end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

-- The window's size with a page open: the book's, or the narrowed talents'; nil leaves the game's.
local function PageSize(tab)
	if tab == PlayerSpellsUtil.FrameTabs.SpellBook then
		if Ours() then return fit.w, fit.h end
	elseif tab == PlayerSpellsUtil.FrameTabs.ClassTalents and Talents.Styled() then
		-- The talents stand 4 over the window's foot and 23 under its top (the game's own anchors).
		return Talents.Width() + 6, Talents.Height() + 27
	end
end

-- In a fight the window is protected (the holder is in it): only secure code may size it then. Secure
-- sizers of ours stand it at the open page's size. The game sizes the window from each page's OnShow, and
-- a frame's children are shown before it, so a sizer must come after that page:
--   * one on the window, made after its pages: it shows with the window, after the open page;
--   * one on each page, as the page hides: going from the book to the talents, the talents show first;
--   * the one on the window again as the mouse comes onto the bare window, for anything left over.
-- Their sizes are set out of a fight; without them they do nothing.
local SIZE = [[
	local w, h
	if self:GetFrameRef("talents"):IsShown() then
		w, h = self:GetAttribute("talents-w"), self:GetAttribute("talents-h")
	elseif self:GetFrameRef("book"):IsShown() then
		w, h = self:GetAttribute("book-w"), self:GetAttribute("book-h")
	end
	if not (w and h) then return end
	local window = self:GetFrameRef("window")
	if abs(window:GetWidth() - w) >= 0.5 or abs(window:GetHeight() - h) >= 0.5 then
		window:SetWidth(w)
		window:SetHeight(h)
	end
]]

local sizers = {}   -- the window's sizer, then each page's

local function Sizer(parent, events)
	local f = Frame()
	local s = CreateFrame("Frame", nil, parent, "SecureHandlerShowHideTemplate, SecureHandlerEnterLeaveTemplate")
	s:SetAllPoints(f)
	-- Under every piece of the window but its own ground; it takes no clicks.
	s:SetFrameLevel(f:GetFrameLevel() + 1)
	s:SetMouseClickEnabled(false)
	s:EnableMouseMotion(events.enter == true)
	s:SetFrameRef("window", f)
	s:SetFrameRef("talents", f.TalentsFrame)
	s:SetFrameRef("book", f.SpellBookFrame)
	for event in pairs(events) do s:SetAttribute("_on" .. event, SIZE) end
	sizers[#sizers + 1] = s
end

-- The sizers made and given the pages' sizes (on), or emptied (off). Out of a fight only.
local function Arm(on)
	local f = Frame()
	if on and #sizers == 0 then
		Sizer(f, { show = true, enter = true })
		Sizer(f.TalentsFrame, { hide = true })
		Sizer(f.SpellBookFrame, { hide = true })
	end
	local tabs = PlayerSpellsUtil.FrameTabs
	for _, s in ipairs(sizers) do
		for key, tab in pairs({ talents = tabs.ClassTalents, book = tabs.SpellBook }) do
			local w, h
			if on then w, h = PageSize(tab) end
			s:SetAttribute(key .. "-w", w)
			s:SetAttribute(key .. "-h", h)
		end
	end
end

local function Size()
	local f = Frame()
	if not f or not (M and M.on) then return end
	local w, h
	if f:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.SpellBook) then
		w, h = PageSize(PlayerSpellsUtil.FrameTabs.SpellBook)
	elseif f:IsFrameTabActive(PlayerSpellsUtil.FrameTabs.ClassTalents) then
		w, h = PageSize(PlayerSpellsUtil.FrameTabs.ClassTalents)
	end
	if not w then return end
	if math.abs(f:GetWidth() - w) < 0.5 and math.abs(f:GetHeight() - h) < 0.5 then return end
	if InCombatLockdown() and f:IsProtected() then
		ns.AfterCombat("spells:size", Size)
		return
	end
	f:SetSize(w, h)
end

-- The book at a new size: its page's columns and rows, its cells, the window. Out of a fight only (the cells
-- and the window are protected); `keep` remembers the size.
local function Flow(w, h, keep)
	if not (M and M.on and own.holder) or InCombatLockdown() then return end
	local per = fit.per
	Fit(w, h)
	if keep then ns.T.db.options.bookSize = { fit.w, fit.h } end
	LayCells()
	own.lead:SetWidth(fit.w - 2 * GRID_X - 110)
	Arm(true)
	Size()
	if fit.per ~= per then
		-- The page turned to again at its new count (the holder's own code keeps it in the book).
		local _, page = Shown()
		own.holder:SetAttribute("go", page)
	end
	Draw()
end

-- Its handles: the right side, the foot and the corner between (the window hangs by its top left corner). The
-- core's own grip, told the window shapes itself: a drag is so much wider and taller, and the book flows.
local function Hold()
	if own.held or not Shy.HUD.GripFrame then return end
	own.held = true
	local from
	Shy.HUD.GripFrame(Frame(), {
		title = "Spellbook",
		points = { "RIGHT", "BOTTOM", "BOTTOMRIGHT" },
		shown = function() return M ~= nil and M.on and Ours() and OnBook() and not InCombatLockdown() end,
		shape = function(wider, taller, phase)
			if phase == "start" then from = { fit.w, fit.h } end
			if not from then return end
			Flow(from[1] + (wider or 0), from[2] + (taller or 0), phase == "stop")
			if phase == "stop" then from = nil end
		end,
	})
end

local function GameSize()
	local f = Frame()
	if not f then return end
	if InCombatLockdown() and f:IsProtected() then
		ns.AfterCombat("spells:size", GameSize)
		return
	end
	f:UpdateSize()
end

-- The book's own pieces, away while ours stands.
local function Theirs()
	local spells = Book()
	local list = {}
	for _, key in ipairs({ "PagedSpellsFrame", "CategoryTabSystem", "PreviousCategoryIcon", "NextCategoryIcon", "SettingsDropdown",
		"SettingsTopFaceIcon", "AssistedCombatRotationSpellFrame", "SearchBox", "SearchBoxIcon", "SearchPreviewContainer", "HelpPlateButton" }) do
		if spells[key] then list[#list + 1] = spells[key] end
	end
	return list
end

-- A spell the game asks the book to show (a link, the game's own search): its tab and page.
local function GoTo(spellID)
	if not (M and M.on and own.holder) or InCombatLockdown() or not spellID then return end
	for index, tab in ipairs(book.tabs) do
		for n, item in ipairs(tab.items) do
			if item.spell == spellID then
				own.holder:SetAttribute("tab", index)
				own.holder:SetAttribute("go", math.ceil(n / fit.per))
				return
			end
		end
	end
end

local EVENTS = { "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELL_UPDATE_COOLDOWN", "PET_BAR_UPDATE",
	"ACTIONBAR_SLOT_CHANGED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UNIT_PET" }

local function OnEvent(_, event, arg1, arg2)
	if not (M and M.on and own.holder) then return end
	if event == "LEARNED_SPELL_IN_SKILL_LINE" then
		if arg2 then new[arg2] = true end
		Stale()
	elseif event == "SPELL_UPDATE_COOLDOWN" or event == "PET_BAR_UPDATE" or event == "UPDATE_SHAPESHIFT_FORM" or event == "ACTIONBAR_SLOT_CHANGED" then
		Tick()
		-- The pet's spells come and go; a spell placed or taken off a bar changes what "missing" lists.
		if event == "PET_BAR_UPDATE" or (missing and event == "ACTIONBAR_SLOT_CHANGED") then Stale() end
	elseif event == "PLAYER_REGEN_DISABLED" then
		own.search:ClearFocus()
		own.search:EnableMouse(false)
		own.search:SetAlpha(0.45)
		own.ranks:Refresh()
	elseif event == "PLAYER_REGEN_ENABLED" then
		own.search:EnableMouse(true)
		own.search:SetAlpha(1)
		own.ranks:Refresh()
		if stale then Bake() end
	elseif event == "UNIT_PET" then
		if arg1 == "player" then Stale() end
	else
		Stale()
	end
end

local function Hook(m)
	local f, spells = Frame(), Book()
	hooksecurefunc(f, "UpdateSize", Size)
	spells:HookScript("OnShow", function()
		if not m.on then return end
		Size()
		if Ours() then
			Bake()
			Draw()
		end
	end)
	spells:HookScript("OnHide", function()
		if m.on and own.spine then own.spine:Fit(nil) end
		if m.on then ShowGround() end
	end)
	f.TalentsFrame:HookScript("OnShow", function() if m.on then Size() end end)
	hooksecurefunc(spells, "GoToSpell", function(_, spellID) GoTo(spellID) end)
	-- The game's pet book binding: the pet's tab.
	hooksecurefunc(spells, "TrySetCategory", function(_, category)
		if not (m.on and own.holder) or InCombatLockdown() then return end
		if category == PlayerSpellsUtil.SpellBookCategories.Pet then
			for index, tab in ipairs(book.tabs) do
				if tab.pet then own.holder:SetAttribute("tab", index) end
			end
		end
	end)
	local watch = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do watch:RegisterEvent(event) end
	watch:SetScript("OnEvent", OnEvent)
	Talents.Hook(m)
end

local function PaintBook(kit, head)
	local spells = Book()
	if not own.body then
		-- Secure buttons are set up out of a fight: until it ends, the game's book stays as it is.
		if InCombatLockdown() then
			ns.AfterCombat("spells:build", function() M:Refresh() end)
			return
		end
		Build()
	end
	for _, key in ipairs({ "TopBar", "BookBGHalved", "BookBGLeft", "BookBGRight", "BookCornerFlipbook", "Bookmark" }) do
		kit:Hide(spells[key])
	end
	Shop.PutAway(spells, unpack(Theirs()))
	own.body:Show()
	Ground(kit)
	kit:HeadRail(head, {
		close = Frame().CloseButton,
		leading = { { own.gear, gap = 5 }, { own.search, gap = 5 } },
		closeGap = 4,
		gap = 5,
		closeTrim = ns.CLOSE[3] or 0,
		closePlate = ns.CLOSE,
	})
	if own.holder:GetParent() ~= spells then
		ns.AfterCombat("spells:holder", function()
			own.holder:SetParent(spells)
			own.holder:SetAllPoints(Frame())
			own.holder:Show()
		end)
	end
	own.spine = ns.Spine(kit, Frame(), "bookSpine")
	Bake()
	Draw()
	-- The size you left it at, and its handles.
	ns.AfterCombat("spells:flow", function()
		local kept = ns.T.db.options.bookSize
		if kept then Flow(kept[1], kept[2]) end
		Hold()
	end)
end

local function Paint(m, kit)
	local f = Frame()
	local head = ns.Window(kit, f)
	if f.PortraitContainer and f.PortraitContainer.portrait then kit:Crop(f.PortraitContainer.portrait, unpack(ICON)) end
	Shop.PutAway(f, f.MaximizeMinimizeButton)
	if Ours() then PaintBook(kit, head) end
	-- The talents: restyled for a window of ours, else the game's own with your build on it.
	if Talents.Styled() then
		Talents.Paint(m, kit)
	elseif Talents.Painted() then
		Talents.Clear(m)
	end
	if ns.TalentBuild then ns.TalentBuild.On(not Talents.Styled()) end
	ns.AfterCombat("spells:sizers", function() Arm(M.on) end)
	Size()
end

local function Clear(m)
	if m.on then return end   -- a repaint: the layout stays
	local f = Frame()
	if own.body then own.body:Hide() end
	if own.spine then own.spine:Fit(nil) end
	if own.holder then
		ns.AfterCombat("spells:holder", function()
			own.holder:Hide()
			own.holder:SetParent(UIParent)
		end)
	end
	Shop.BringBack(Book())
	Shop.BringBack(f)
	if Talents.Painted() then Talents.Clear(m) end
	if ns.TalentBuild then ns.TalentBuild.On(false) end
	ns.AfterCombat("spells:sizers", function() Arm(M.on) end)
	GameSize()
end

M = ns.Module({
	id = "spells",
	title = "Spellbook and talents",
	desc = "You get the Classic spellbook, two columns to a page, and your build marked on the talent window.",
	group = "rebuilt",
	words = "spells abilities",
	Ready = function()
		local f = PlayerSpellsFrame
		return f ~= nil and f.SpellBookFrame ~= nil and f.TalentsFrame ~= nil
	end,
	-- Our own talent window (unless you keep the game's) takes the game's talent key and button from login, not
	-- when the game's window loads.
	Switch = function(m, on)
		if ns.TalentWindow then ns.TalentWindow.On(on and m.opt.gameTalents ~= true) end
	end,
	options = {
		{ key = "gameTalents", label = "Game's talent window", default = false,
			desc = "Your talents in the game's own window instead of ours, with your build's next talents numbered on it." },
	},
	Hook = Hook,
	Paint = Paint,
	Clear = Clear,
	own = own,   -- exposed for inspection
	Flow = function(w, h) Flow(w, h, true) end,   -- the book at that size, kept (the grip's drag; tests)
	Fit = function() return fit end,
	book = book,
})
