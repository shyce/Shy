-- Pings and raid markers for your target on secure buttons, shown while Shift is held with a target:
-- the pings in a row over the markers. A right-click on a marker puts it on the ground instead.
-- Secure buttons can't be created, moved or shown in combat, so they are built beforehand and shown by a
-- state driver. A Shy.HUD box sets the position; the holder is placed at the box's coordinates out of
-- combat, never anchored to it (anchoring would make the box protected).
-- With ShyDock's cockpit up the box is docked in the bay at the plate's end (ShyDock's Arrange.lua). The
-- cockpit plans the bay with the plate's own padding (Shy.addons.Dock:StripBays): as tall as the plate,
-- the buttons in three rows, two or one, whichever the plate's height gives the biggest buttons. The block
-- then has no panel of its own: the plate grows over the bay while it is up
-- (Shy.addons.Dock:CockpitWing). A fight can change the plate (the cooldowns that wait for one show), so
-- the bay is given as it stands and as a fight will have it; both layouts are worked out beforehand and
-- the state driver picks one, since a fight can start while Shift is held.

local ADDON, ns = ...
local UI, Slot = Shy.UI, Shy.Slot

local Strip = {}
ns.Strip = Strip

local CELL, GAP, ROW_GAP, PAD = 24, 3, 4, 5   -- alone: button size, gap across, gap between rows, outer padding
local ROWS = 2                                -- alone: rows of buttons (Measures)
local MARKS = { 8, 7, 6, 5, 4, 3, 2, 1 } -- skull first
-- The world marker of each raid marker's shape (the game numbers them differently).
local WORLD = { 5, 6, 3, 2, 7, 1, 4, 8 }
-- Pings left to right for something you can attack; number is /ping's own for it.
local PINGS = {
	{ kind = "Attack", name = "PING_TYPE_ATTACK", word = "Attack", number = 1 },
	{ kind = "Warning", name = "PING_TYPE_WARNING", word = "Warning", number = 2 },
	{ kind = "Assist", name = "PING_TYPE_ASSIST", word = "Assist", number = 4 },
	{ kind = "OnMyWay", name = "PING_TYPE_ON_MY_WAY", word = "On my way", number = 3 },
}
-- And for anyone else.
local FRIEND = { "Assist", "OnMyWay", "Warning", "Attack" }
local ORDERS = { "foe", "friend" }
-- Shift held with a target: "foe" for something you can attack, "friend" for the rest. Only a target
-- counts, since the buttons act on it: the mouse has left whoever it was on by the time one is
-- clicked. A corpse counts only if it is an ally's, so looting with Shift brings nothing.
local RULE = "[nomod:shift] hide; [@target,harm,nodead] foe; [@target,help][@target,exists,nodead] friend; hide"
-- In the cockpit's bay: the same, in a fight as the bay will be then ("fightfoe", "fightfriend").
local BAYS = "[nomod:shift] hide; [@target,harm,nodead,combat] fightfoe; [@target,help,combat][@target,exists,nodead,combat] fightfriend; "
	.. "[@target,harm,nodead] foe; [@target,help][@target,exists,nodead] friend; hide"
-- Stands every button for the state's layout ("base" or "fight") and order, then shows the block.
-- Lay below does the same out of combat.
local HELD = [[
	if newstate == "hide" then
		self:Hide()
	else
		local layout, order = "base", newstate
		if newstate == "fightfoe" then
			layout, order = "fight", "foe"
		elseif newstate == "fightfriend" then
			layout, order = "fight", "friend"
		end
		self:SetAttribute("order", order)
		self:SetAttribute("layout", layout)
		for index = 1, self:GetAttribute("count") do
			local button = self:GetFrameRef("button" .. index)
			local key = layout .. order .. index
			local size = self:GetAttribute(layout .. "size" .. index)
			button:SetWidth(size)
			button:SetHeight(size)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", "$parent", "TOPLEFT", self:GetAttribute(key .. "x"), self:GetAttribute(key .. "y"))
		end
		self:Show()
	end
]]
local MARK_ART = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
local ART = { "shyBg", "shyEdge", "shyLine", "shyStrip" }   -- a panel's own art, hidden while docked

local box, strip                         -- the HUD box, and the secure holder placed over it
local things, pings                      -- the buttons in order, and how many of them are pings
local pending                            -- work queued for the end of combat
local waiter                             -- frame that retries Start after combat
local docked = false                     -- ShyDock has the box in the cockpit's bay
local fitted                             -- what the block was last laid out for
local inBay = false                      -- laid out for the cockpit's bay

-- Buttons in order: { icon = file | atlas = name, tip, text, secure = attributes }, the pings first.
-- A ping also has its kind and `friend`, its place in the other order. Returns them and the ping count.
local function Things()
	local list = {}
	if C_Ping and C_Ping.GetTextureKitForType and Enum.PingSubjectType then
		for _, ping in ipairs(PINGS) do
			local kind = Enum.PingSubjectType[ping.kind]
			local kit = kind and C_Ping.GetTextureKitForType(kind)
			if kit then
				list[#list + 1] = { kind = ping.kind, atlas = "Ping_Wheel_Icon_" .. kit, tip = _G[ping.name] or ping.word,
					text = "Pings your target.",
					secure = { type = "macro", macrotext = "/ping [@target] " .. ping.number } }
			end
		end
	end
	local count = #list
	local seat = 0
	for _, kind in ipairs(FRIEND) do
		for index = 1, count do
			if list[index].kind == kind then
				seat = seat + 1
				list[index].friend = seat
			end
		end
	end
	for _, index in ipairs(MARKS) do
		-- Right button: the game hands you the world marker to place with a click on the ground.
		list[#list + 1] = { icon = MARK_ART .. index, tip = _G["RAID_TARGET_" .. index] or ("Mark " .. index),
			text = "Marks your target; click again to remove it. Right-click to place it on the ground instead (in a group).",
			secure = { type = "raidtarget", action = "toggle", marker = index, unit = "target",
				type2 = "worldmarker", action2 = "toggle", marker2 = WORLD[index] } }
	end
	return list, count
end

-- The cockpit's bay as it stands and as a fight will have it; nil when the block stands alone.
local function Bays()
	local dock = Shy.addons.Dock
	if not (docked and dock and dock.StripBays and dock.CockpitWing) then return nil end
	return dock:StripBays()
end

-- The block's measures alone: { cell, width, height }, and x(column) and y(row) for a button's top left corner.
-- Two rows, as in the cockpit's bay: the pings two by two, then (the padding between the groups) the markers four
-- by two. So the block is as tall as a unit frame (2 x 24 + 4 + 2 x 5 = 62) and every look frames it alike: a
-- look sizes its corners from a piece's shorter side.
local function Measures()
	local pingColumns = math.ceil(pings / ROWS)
	local markColumns = math.ceil((#things - pings) / ROWS)
	local m = { cell = CELL, marksAt = PAD + (pingColumns > 0 and pingColumns * (CELL + GAP) - GAP + PAD or 0) }
	m.width = m.marksAt + markColumns * (CELL + GAP) - GAP + PAD
	m.height = 2 * PAD + ROWS * CELL + (ROWS - 1) * ROW_GAP
	function m.y(row) return -(PAD + (row - 1) * (CELL + ROW_GAP)) end
	return m
end

-- Where a button stands alone: a ping in its place two by two (in `order`: attack and warning over assist and
-- on my way for something you can attack), a marker in the group after them, row by row.
local function Seat(index, m, order)
	if index <= pings then
		local place = (order == "friend" and things[index].friend or index) - 1
		return PAD + (place % 2) * (CELL + GAP), m.y(math.floor(place / 2) + 1)
	end
	local at = index - pings - 1
	local columns = math.ceil((#things - pings) / ROWS)
	return m.marksAt + (at % columns) * (CELL + GAP), m.y(math.floor(at / columns) + 1)
end

-- Where a button stands in a bay: the bay has a place for each of four pings, then for the markers.
local function BaySeat(index, bay, order)
	local place = 4 + index - pings
	if index <= pings then place = order == "friend" and things[index].friend or index end
	local at = bay.at[place]
	return at[1], -at[2], bay.cell
end

-- Hands the holder's own code a layout: each button's size, and its place in either order from the
-- holder's top left corner. seat(index, order) returns x, y and size.
local function Remember(layout, seat)
	for index = 1, #things do
		for _, order in ipairs(ORDERS) do
			local x, y, size = seat(index, order)
			strip:SetAttribute(layout .. order .. index .. "x", x)
			strip:SetAttribute(layout .. order .. index .. "y", y)
			strip:SetAttribute(layout .. "size" .. index, size)
		end
	end
end

-- Stands a frame's buttons for a layout and order, as the holder's own code does. Out of combat only.
local function Lay(frame, cells, layout, order)
	for index, cell in ipairs(cells) do
		local key = layout .. order .. index
		local size = strip:GetAttribute(layout .. "size" .. index)
		cell:SetSize(size, size)
		if cell.slot then cell.slot:Set({ icon = cell.picture, size = size }) end   -- the level drawn for its size
		cell:ClearAllPoints()
		cell:SetPoint("TOPLEFT", frame, "TOPLEFT", strip:GetAttribute(key .. "x"), strip:GetAttribute(key .. "y"))
	end
end

-- Draws the panel and a slot per button on the box (layout-mode preview) and on the secure holder.
-- make(parent, thing, index) returns the frame for each slot.
local function Dress(frame, make)
	UI.Panel(frame, { hud = true, brackets = false, line = false })
	frame.cells = {}
	for index, thing in ipairs(things) do
		local cell = make(frame, thing, index)
		local picture = cell:CreateTexture(nil, "BORDER")
		picture:SetPoint("TOPLEFT", 2, -2)
		picture:SetPoint("BOTTOMRIGHT", -2, 2)
		if thing.atlas then picture:SetAtlas(thing.atlas) else picture:SetTexture(thing.icon) end
		cell.picture = picture
		cell.slot = Slot.New(cell, { icon = picture })
		frame.cells[index] = cell
	end
end

-- Tells the cockpit the block is up, so its plate grows over the bay under it; out false: back in.
local function Wing(out)
	local dock = Shy.addons.Dock
	if not (inBay and dock and dock.CockpitWing) then return end
	dock:CockpitWing(out, strip)
end

-- Lays the block out for where it stands: in the cockpit's bay (as it is, and as a fight will have it) or
-- alone. Out of combat only.
local function Fit()
	local rest, fight = Bays()
	local sign = "alone"
	if rest then
		local parts = {}
		for _, bay in ipairs({ rest, fight }) do
			parts[#parts + 1] = table.concat({ bay.left, bay.bottom, bay.width, bay.height, bay.cell }, " ")
			for _, at in ipairs(bay.at) do parts[#parts + 1] = at[1] .. " " .. at[2] end
		end
		sign = table.concat(parts, " ")
	end
	if fitted == sign then return end
	fitted = sign
	local order = strip:GetAttribute("order") or "foe"
	if rest then
		Shy.HUD.Resize(box, rest.width, rest.height)
		strip:SetSize(rest.width, rest.height)
		Remember("base", function(index, each) return BaySeat(index, rest, each) end)
		Remember("fight", function(index, each) return BaySeat(index, fight, each) end)
	else
		local m = Measures()
		Shy.HUD.Resize(box, m.width, m.height)
		strip:SetSize(m.width, m.height)
		Remember("base", function(index, each)
			local x, y = Seat(index, m, each)
			return x, y, m.cell
		end)
	end
	strip.rule = rest and BAYS or RULE
	Lay(box, box.cells, "base", "foe")
	Lay(strip, strip.buttons, (rest and strip:GetAttribute("layout") == "fight") and "fight" or "base", order)
	strip:SetAttribute("order", order)
	if not rest then strip:SetAttribute("layout", "base") end
	-- In the bay the cockpit's plate is the panel.
	if inBay and not rest then
		Wing(false)
		strip:SetAlpha(1)
	end
	inBay = rest ~= nil
	for _, key in ipairs(ART) do
		if strip[key] then strip[key]:SetShown(not inBay) end
	end
	if strip:IsShown() then Wing(true) end
end

-- Moves the holder to the box. Queued until combat ends.
local function Stand()
	if not (box and strip) then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = nil
	local left, bottom = box:GetLeft(), box:GetBottom()
	if not (left and bottom) then return end
	strip:SetScale(box:GetScale())
	strip:ClearAllPoints()
	strip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
end

-- Lays the block out and registers or removes the state driver to match the option.
function Strip.Apply()
	if not strip then return end
	if InCombatLockdown() then
		pending = true
		return
	end
	Fit()
	local on = ns.T.db.strip ~= false
	if on then
		-- The cockpit tells of every change, a fight's start among them: the driver is only given a new rule.
		if strip.driven ~= strip.rule then
			RegisterStateDriver(strip, "held", strip.rule)
			strip.driven = strip.rule
		end
	else
		UnregisterStateDriver(strip, "held")
		strip.driven = nil
		-- Back to "hide", so the rule starts from there when it is turned on again.
		strip:SetAttribute("state-held", "hide")
		strip:Hide()
	end
	strip.ruled = on
	Shy.HUD.Update(box)
	Stand()
end

-- Returns the box, the holder and its buttons.
function Strip.Pieces()
	return box, strip, strip and strip.buttons
end

function Strip.Start()
	if box then return end
	if InCombatLockdown() then
		-- Loaded in combat: build after it ends.
		if not waiter then
			waiter = CreateFrame("Frame")
			waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
			waiter:SetScript("OnEvent", function(self)
				self:UnregisterEvent("PLAYER_REGEN_ENABLED")
				Strip.Start()
			end)
		end
		return
	end
	things, pings = Things()
	local m = Measures()
	box = Shy.HUD.Create({
		id = "shytip-strip",
		title = "Pings and markers",
		width = m.width,
		height = m.height,
		point = { "BOTTOM", "BOTTOM", 0, 300 },
		-- The box itself only shows in layout mode; in play the secure holder is here.
		shown = function() return false end,
		docked = function(_, on)
			docked = on
			Strip.Apply()
		end,
	})
	Dress(box, function(parent) return CreateFrame("Frame", nil, parent) end)

	strip = CreateFrame("Frame", "ShyTipStrip", UIParent, "SecureHandlerStateTemplate")
	strip:SetFrameStrata("HIGH")
	strip:SetAttribute("_onstate-held", HELD)
	strip:Hide()
	Dress(strip, function(parent, thing, index)
		local button = CreateFrame("Button", "ShyTipStripButton" .. index, parent, "SecureActionButtonTemplate")
		button:RegisterForClicks("AnyUp", "AnyDown")
		for key, value in pairs(thing.secure) do button:SetAttribute(key, value) end
		UI.Help(button, thing.tip, thing.text)
		return button
	end)
	strip.buttons = strip.cells
	-- What the holder's own code needs to stand the buttons (it can move them in combat).
	strip:SetAttribute("count", #things)
	for index, button in ipairs(strip.buttons) do strip:SetFrameRef("button" .. index, button) end
	strip:HookScript("OnShow", function() Wing(true) end)
	strip:HookScript("OnHide", function() Wing(false) end)

	-- The holder follows the box when it is moved.
	Shy:On("SHY_HUD_MOVED", function(moved) if moved == box then Stand() end end)
	Shy:On("SHY_HUD_LAYOUT", Stand)
	-- The cockpit came, went or changed, or its bay did.
	Shy:On("SHY_COCKPIT", Strip.Apply)
	-- Also when the box is given a new home (setup, reset, the console arranging it).
	hooksecurefunc(box, "SetPoint", function() C_Timer.After(0, Stand) end)
	local after = CreateFrame("Frame")
	after:RegisterEvent("PLAYER_REGEN_ENABLED")
	after:RegisterEvent("PLAYER_ENTERING_WORLD")
	after:RegisterEvent("UI_SCALE_CHANGED")
	after:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and pending then Strip.Apply() else Stand() end
	end)
	Strip.Apply()
	-- HUD boxes get their saved positions shortly after login.
	C_Timer.After(1, Stand)
end
