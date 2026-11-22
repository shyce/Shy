-- The map's window: the family's window, sized by width and height at any corner or side, that holds the map's
-- view while it is open (View.Host): the map, what stands over it, the breadcrumb and the bar on a strip under its
-- header, and the map's menu at the strip's end. The game's own map window is left as it is: opening it closes this
-- one, so the two never stand together.
--
-- It opens from the game's map key (the key's binding stood in for by ours, Bind), its own key (Key Bindings,
-- ShyMaps: "Map window"), the journal's world side or /shy maps window; the quest log's key opens it with your
-- quests docked beside it (ShyQuest's, T:QuestList), where ShyQuest is. Those keys run through secure buttons
-- (ShyMapsWindowKey, ShyMapsQuestKey), which click the game window's own close button first (the game's map is never closed from
-- addon code), so a key closes the game's map where it is open and this window opens after. It is made over the
-- console, in the screen's middle with your quests beside it, as tall as the screen over the console allows and as
-- wide as the map is for that height (Home), then kept as you size it; T.db.windowScale draws all of it larger or
-- smaller.
--   Window.Set(on)          opens or closes it         Window.Shown()   Window.Toggle(): the quests' toggle
--   Window.Room() -> box, body, top, pad   where what is under the header begins (Sides.lua lays the journal there)
--   Window.Tell(fn)         fn(what) as it is "shown", "hidden" or "sized"

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local Window = {}
ns.Window = Window

local KEY = "ShyMapsWindowKey"
_G["BINDING_NAME_CLICK " .. KEY .. ":LeftButton"] = "Map window"
local QUEST_KEY = "ShyMapsQuestKey"   -- the quest log's keys' secure button

local HEAD = UI.HEAD.window
local L = {
	least = { 520, 380 },     -- the least it flows to
	shape = 1.5,              -- the map's own shape (its art is 1002 by 668): made this wide for its map's height
	gap = 12,                 -- made standing this far over the console (ShyDock), and under the screen's top
	w = 1100, h = 680,        -- made at, at most; without ShyDock's console, at this
	head = HEAD.line + HEAD.lip,   -- its header
	row = 36,                 -- the row under it: the breadcrumb, and at its right the bar and the menu (the journal's bar)
	plate = 22,               -- every plate on the row (Controls.lua's TALL)
	apart = 4,                -- between two plates (Controls.lua's SLOT_GAP)
	pad = 6,                  -- round the map; the row's ends stand flush with it
	nav = 34,                 -- the breadcrumb's strip
	bar = 11,                 -- the bar stands this far past the strip's top right, across and down (Controls.lua's BAR_X, BAR_Y)
	home = 3,                 -- what the window's home was last made by (T.db.windowHome): a size kept from before it goes
	corner = 10,              -- the quests' toggle, in from the map's bottom right corner (the coordinates' INSET)
}
-- (The plates stand in the row's middle; the bar's strip is placed so the bar does too, its end the menu's width
-- and a gap short of the map's right edge.)
L.inset = (L.row - L.plate) / 2

local box, well, strip
local told = {}

local function GameShown()
	local map = rawget(_G, "WorldMapFrame")
	return map ~= nil and map:IsShown() == true
end

local function Say(what)
	for _, fn in ipairs(told) do
		local ok, err = pcall(fn, what)
		if not ok then geterrorhandler()(err) end
	end
end

function Window.Tell(fn) told[#told + 1] = fn end

-- The action bars on the band of the housing (ShyDock's), side by side: the main block and the groups beside it.
-- A bar standing up the screen's side (taller than wide) is no part of it. Read off the bars' own rects, out of a
-- fight; a rect that can't be read is left out. Returns left, bottom, right, top in UIParent units, or nil.
local BARS = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarLeft", "MultiBarRight", "MultiBar5", "MultiBar6", "MultiBar7" }
local function Bars(left, bottom, right, top)
	local unit = UIParent:GetEffectiveScale()
	for _, name in ipairs(BARS) do
		local bar = rawget(_G, name)
		if bar and bar:IsVisible() then
			local ok, l, b, r, t, k = pcall(function() return bar:GetLeft(), bar:GetBottom(), bar:GetRight(), bar:GetTop(), bar:GetEffectiveScale() end)
			if ok and l and not (issecretvalue(l) or issecretvalue(b) or issecretvalue(r) or issecretvalue(t) or issecretvalue(k)) then
				k = k / unit
				l, b, r, t = l * k, b * k, r * k, t * k
				-- (On the housing's band, and lying flat.)
				if r - l >= t - b and b < top and t > bottom then
					left, bottom, right, top = math.min(left, l), math.min(bottom, b), math.max(right, r), math.max(top, t)
				end
			end
		end
	end
	return left, bottom, right, top
end

-- Where it is made: standing over the console, clear of all of it (the action bars, and chat and the meter where
-- they stand taller beside them: ShyDock's Roof), as tall as the screen above allows and as wide as the map is at
-- that height, so the map fills it; in the screen's middle, with your quests docked beside it (ShyQuest's
-- QuestListRoom: the two stand in the middle together). Without ShyDock's housing, a good part of the screen in its
-- middle.
local function Home()
	local quest = Shy.addons.Quest
	local beside = quest and quest.QuestListRoom and quest:QuestListRoom() or 0
	local wide, tall = UIParent:GetWidth(), UIParent:GetHeight()
	local dock = Shy.addons.Dock
	local left, bottom, width, height
	if dock and dock.HousingRect then left, bottom, width, height = dock:HousingRect() end
	if not (left and width and width > 0) then
		local w = math.min(L.w, wide - 2 * L.gap - beside)
		local h = math.min(L.h, tall - 2 * L.gap)
		return math.floor(w), math.floor(h), { "CENTER", "CENTER", -math.floor(beside / 2), 0 }
	end
	local _, _, _, t = Bars(left, bottom, left + width, bottom + height)
	local roof = dock.Roof and dock:Roof() or 0
	local foot = math.max(t, roof) + L.gap
	local h = math.max(L.least[2], math.min(L.h, tall - foot - L.gap))
	local map = h - L.head - L.row - L.pad   -- the map's height in it
	local w = math.max(L.least[1], math.min(L.w, wide - 2 * L.gap - beside, map * L.shape + 2 * L.pad))
	return math.floor(w), math.floor(h), { "BOTTOM", "BOTTOMLEFT", math.floor((wide - beside) / 2), math.floor(foot) }
end

local function Make()
	if box then return box end
	local w, h, point = Home()
	box = UI.Window({
		id = "shymaps.window",
		name = "ShyMapsWindow",
		title = "Map",
		width = w, height = h,
		point = point,
		shown = function() return false end,
		grip = { flow = true, min = L.least },
		strata = "HIGH",
		maximize = true,
		head = { size = "window", icon = T.mark, title = "Map" },
	})
	-- (Made at its home once: a size and place kept from before it had one are let go of.)
	if (T.db.windowHome or 0) < L.home then
		T.db.windowHome = L.home
		Shy.HUD.Forget(box, true)
	end
	-- Everything under the header stands on the body: clear of the look's work round the edge (UI.Body).
	local body = UI.Body(box)
	local top = -L.head
	-- The row's ground, dark as a map's bar, from the header's foot to the map's top, flush with the map.
	local band = box:CreateTexture(nil, "BACKGROUND", nil, 2)
	band:SetPoint("TOPLEFT", body, "TOPLEFT", L.pad, top)
	band:SetPoint("BOTTOMRIGHT", body, "TOPRIGHT", -L.pad, top - L.row)
	band:SetColorTexture(0, 0, 0, 0.85)
	-- The map's menu at the row's right end, flush with the map's edge.
	local plate = CreateFrame("Frame", nil, box)
	plate:SetSize(L.plate, L.plate)
	plate:SetPoint("TOPRIGHT", body, "TOPRIGHT", -L.pad, top - L.inset)
	plate:SetFrameLevel(ns.View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
	UI.Skin(plate, C.bgHot)
	local menu = CreateFrame("Button", nil, plate)
	menu:SetAllPoints()
	menu.glyph = menu:CreateTexture(nil, "ARTWORK")
	menu.glyph:SetTexture(Shy.MEDIA .. "GlyphFunnel")
	menu.glyph:SetSize(12, 12)
	menu.glyph:SetPoint("CENTER")
	UI.Tint(menu.glyph, C.text)
	UI.Press(menu, { fill = C.bgHot, bare = true, sink = { menu.glyph } })
	menu:SetScript("OnClick", function(self) UI.DropMenu(self, function(root) T:MapMenu(root) end) end)
	-- The strip the breadcrumb fills (Nav.lua) and the bar hangs from (Controls.lua): its left flush with the map, its
	-- top right where the bar, hung L.bar past it, stands in the row's middle a gap left of the menu.
	strip = CreateFrame("Frame", nil, box)
	strip:SetPoint("TOPLEFT", body, "TOPLEFT", L.pad, top - L.inset + L.bar)
	strip:SetPoint("TOPRIGHT", body, "TOPRIGHT", -(L.pad + L.plate + L.apart + L.bar), top - L.inset + L.bar)
	strip:SetHeight(L.nav)
	-- The well: the map, under the row to the window's foot.
	well = CreateFrame("Frame", nil, box)
	well:SetPoint("TOPLEFT", body, "TOPLEFT", L.pad, top - L.row)
	well:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -L.pad, L.pad)
	-- Your quests, docked beside it (ShyQuest's, T:QuestList): its toggle stands in the map's bottom right corner; the
	-- coordinates stand beside it (Controls.lua).
	local quest = Shy.addons.Quest
	if quest and quest.QuestList then
		local toggle = CreateFrame("Button", nil, box)
		toggle:SetSize(L.plate, L.plate)
		toggle:SetPoint("BOTTOMRIGHT", well, "BOTTOMRIGHT", -L.corner, L.corner)
		toggle:SetFrameLevel(ns.View.Level("PIN_FRAME_LEVEL_TOPMOST") + 200)
		UI.Skin(toggle, C.bgHot)
		toggle.glyph = toggle:CreateTexture(nil, "ARTWORK")
		toggle.glyph:SetTexture(Shy.Skin.GLYPH.caret)
		toggle.glyph:SetSize(12, 12)
		toggle.glyph:SetPoint("CENTER")
		UI.Tint(toggle.glyph, C.text)
		UI.Press(toggle, { fill = C.bgHot, bare = true, sink = { toggle.glyph } })
		-- (Its arrow points the way the list goes: out to the right while it is shut, back while it is open.)
		function toggle:Point()
			self.glyph:SetRotation(quest:QuestListShown() and -math.pi / 2 or math.pi / 2)
		end
		toggle:SetScript("OnClick", function(self)
			quest:QuestList()
			self:Point()
		end)
		box.questToggle = toggle
		Shy:On("SHY_QUEST_LIST", function() toggle:Point() end)
	end
	box:HookScript("OnShow", function()
		ns.View.Host({ box = box, well = well, strip = strip })
		if quest and quest.QuestListFollow then quest:QuestListFollow(true) end
		if box.questToggle then box.questToggle:Point() end
		Say("shown")
	end)
	box:HookScript("OnHide", function()
		ns.View.Host(nil)
		if quest and quest.QuestListFollow then quest:QuestListFollow(false) end
		-- (Shut faded: open again solid, drawn as ever.)
		box:SetAlpha(1)
		if box.flat then
			box.flat = false
			box:SetIsFrameBuffer(false)
		end
		Say("hidden")
	end)
	box:HookScript("OnSizeChanged", function() Say("sized") end)
	Shy.HUD.SetScale(box, T.db.windowScale or 1)
	return box
end

function Window.Shown() return box ~= nil and box:IsShown() end

-- The quests' toggle in the map's corner, while there is one (the coordinates stand beside it: Controls.lua).
function Window.Toggle() return box and box.questToggle or nil end

-- Where what is under the header begins: the window, its body, how far down the body the header ends, and the map's
-- edge in from the body's.
function Window.Room()
	if not box then return nil end
	return box, UI.Body(box), L.head, L.pad
end

-- The window opened or closed (the game's map closed first, by the secure button, where it was open).
function Window.Set(on)
	if not T.db.on then return end
	if on then
		Make():Show()
		box:Raise()
	elseif box then
		box:Hide()
	end
end

-- The quest log's keys: the window opened with your quests beside it; again, it closes; with the window open and
-- your quests shut, they open. (Closing the window keeps the quests on for next time.)
local function QuestKey(opening)
	local quest = Shy.addons.Quest
	if not (quest and quest.QuestList) then return Window.Set(opening or not Window.Shown()) end
	if opening or not Window.Shown() then
		Window.Set(true)
		quest:QuestList(true)
	elseif quest:QuestListShown() then
		Window.Set(false)
	else
		quest:QuestList(true)
	end
end
-- The secure buttons, one for the map's keys and one for the quest log's: each click is the game window's close
-- button's (armed out of a fight once the window is loaded; a left click, the one it answers), and our window opens
-- after it, or closes where it was the one open.
local was = false
local function Key(name, after)
	local key = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
	key:RegisterForClicks("AnyUp")
	key:SetAttribute("type", "click")
	key:SetAttribute("useOnKeyDown", false)
	key:Hide()
	key:SetScript("PreClick", function() was = GameShown() end)
	key:SetScript("PostClick", function()
		after(was)
		was = false
	end)
	return key
end
local key = Key(KEY, function(open) Window.Set(open or not Window.Shown()) end)
local questKey = Key(QUEST_KEY, QuestKey)

local armed = false
local function Arm()
	if armed or InCombatLockdown() then return end
	local map = rawget(_G, "WorldMapFrame")
	local close = map and type(map.BorderFrame) == "table" and map.BorderFrame.CloseButton
	if type(close) ~= "table" then return end
	key:SetAttribute("clickbutton", close)
	questKey:SetAttribute("clickbutton", close)
	armed = true
end

-- The game's window opening (by its own buttons): ours closes.
local function Watch()
	local map = rawget(_G, "WorldMapFrame")
	if not map or Window.watching then return end
	Window.watching = true
	map:HookScript("OnShow", function()
		if Window.Shown() then box:Hide() end
	end)
	Arm()
end

-- Faded while you move, as the game fades its own window (its "mapFade" setting), never while the mouse is on it.
-- While it is less than solid it is drawn as one picture and that is faded (as the overlay is, View.lua): faded
-- piece by piece, the map's tiles, which overlap a little so no hairline shows between them, would show every
-- overlap as a line, and the coarser tiles under the fine ones through them.
local FADE = { least = 0.5, speed = 4 }
local fader = CreateFrame("Frame")
local function Flat(on)
	if box.flat == on then return end
	box.flat = on
	box:SetIsFrameBuffer(on)
end
local function Fade(_, dt)
	if not (box and box:IsShown()) then
		fader:SetScript("OnUpdate", nil)
		return
	end
	local want = (IsPlayerMoving() and GetCVarBool("mapFade") and not box:IsMouseOver()) and FADE.least or 1
	local now = box:GetAlpha()
	if math.abs(now - want) < 0.01 then
		box:SetAlpha(want)
		Flat(want < 1)
		if want == 1 and not IsPlayerMoving() then fader:SetScript("OnUpdate", nil) end
		return
	end
	Flat(true)
	box:SetAlpha(now + (want - now) * math.min(1, dt * FADE.speed))
end
fader:RegisterEvent("PLAYER_STARTED_MOVING")
fader:RegisterEvent("PLAYER_STOPPED_MOVING")
fader:SetScript("OnEvent", function()
	if box and box:IsShown() then fader:SetScript("OnUpdate", Fade) end
end)

-- The game's map key opens this window, and its quest log's key this window with your quests (where ShyQuest gives
-- them): their keys stand in for the game's bindings, out of a fight (in one, at its end). Set again when the
-- bindings change, only where the keys did (setting them is a change of bindings too).
local bound, pending = "", false
local function Bind()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false
	local on = T.db and T.db.on
	local quest = Shy.addons.Quest
	local maps = on and { GetBindingKey("TOGGLEWORLDMAP") } or {}
	local log = (on and quest and quest.QuestList) and { GetBindingKey("TOGGLEQUESTLOG") } or {}
	local said = table.concat(maps, " ") .. "|" .. table.concat(log, " ")
	if said == bound then return end
	bound = said
	ClearOverrideBindings(key)
	for _, each in ipairs(maps) do SetOverrideBindingClick(key, false, each, KEY, "LeftButton") end
	for _, each in ipairs(log) do SetOverrideBindingClick(key, false, each, QUEST_KEY, "LeftButton") end
end
Window.Bind = Bind

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event)
	Watch()
	Arm()
	if event == "PLAYER_LOGIN" or event == "UPDATE_BINDINGS" or (event == "PLAYER_REGEN_ENABLED" and pending) then Bind() end
end)


ns.OnApply(function()
	if not T.db.on and Window.Shown() then box:Hide() end
	if box and math.abs(box:GetScale() - (T.db.windowScale or 1)) > 0.001 then Shy.HUD.SetScale(box, T.db.windowScale or 1) end
	Bind()
end)
