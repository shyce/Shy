-- Move and scale Blizzard windows (every UIPanelWindows entry plus the world map), and move the bags.
-- The panel manager re-anchors a window each time it opens; a post-hook on SetPoint re-applies the saved spot.
-- Switched off, a window you moved goes back to the game's size and spot, and its title bar drags nothing.

local ADDON, ns = ...
local T = ns.T

local EXTRA_FRAMES = { "WorldMapFrame" }
local TITLE_STRIP = 24          -- drag strip height for a window without a TitleContainer
local TITLE_CLEAR = 30          -- room left for the close button in its corner
local hooked = {}
local handles = {}       -- window -> its drag handle
local hookedBags = {}
local titleHandles = {}  -- bag -> drag handle over its title bar
local windowsOn, bagsOn

local function Saved(frame)
	return T.db.frames[frame:GetName()]
end

local function Locked(frame)
	return InCombatLockdown() and frame:IsProtected()
end

local function Apply(frame)
	local saved = Saved(frame)
	if not windowsOn or not saved or frame.shyApplying then return end
	if frame == WorldMapFrame and WorldMapFrame:IsMaximized() then return end
	if Locked(frame) then
		ns.OutOfCombat(frame, function() Apply(frame) end)
		return
	end
	frame.shyApplying = true
	if saved.scale then frame:SetScale(saved.scale) end
	if saved.point then
		frame:ClearAllPoints()
		frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
	end
	frame.shyApplying = false
end

local function Remember(frame)
	local saved = T.db.frames[frame:GetName()] or {}
	local point, _, relPoint, x, y = frame:GetPoint(1)
	saved.point, saved.relPoint, saved.x, saved.y = point, relPoint, x, y
	T.db.frames[frame:GetName()] = saved
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- While a window moves, the guides show what it lines up with; let go of, it snaps there.
local guideDriver = CreateFrame("Frame")

local function OnDragStart(frame)
	if not windowsOn or Locked(frame) then return end
	if frame == WorldMapFrame and WorldMapFrame:IsMaximized() then return end
	frame.shyWasClamped = frame:IsClampedToScreen()
	frame:SetClampedToScreen(true)
	frame:StartMoving()
	frame.shyMoving = true
	guideDriver:SetScript("OnUpdate", function() Shy.HUD.Guide(frame) end)
end

local function OnDragStop(frame)
	if not frame.shyMoving then return end
	frame.shyMoving = false
	guideDriver:SetScript("OnUpdate", nil)
	frame:StopMovingOrSizing()
	local x, y = Shy.HUD.Guide(frame)
	Shy.HUD.Unguide()
	if x and not Locked(frame) then
		frame.shyApplying = true
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
		frame.shyApplying = false
	end
	frame:SetClampedToScreen(frame.shyWasClamped)
	-- The position is saved here, not in the client's layout cache.
	frame:SetUserPlaced(false)
	Remember(frame)
end

-- Every corner and side of an open window scales it (the core's grip), what lies opposite staying put.
-- Made as a window first shows: most are never opened.
local gripped = {}

local function Grip(frame)
	if gripped[frame] or not windowsOn or not Shy.HUD.GripFrame then return end
	-- A window that shapes itself (the dressed spellbook flows: more spells, not larger ones) keeps its own
	-- handles. It is asked again each time it shows: its owner may take hold of it later, or let go.
	if Shy.HUD.ShapesItself and Shy.HUD.ShapesItself(frame) then return end
	gripped[frame] = true
	Shy.HUD.GripFrame(frame, {
		title = function()
			local text = frame.TitleContainer and frame.TitleContainer.TitleText and frame.TitleContainer.TitleText:GetText()
			-- A dialog's header (DialogHeaderTemplate: the game menu's).
			if not text and frame.Header and frame.Header.Text then text = frame.Header.Text:GetText() end
			if type(text) == "string" and not issecretvalue(text) and text ~= "" then return text end
			return "Window"
		end,
		-- Its panel where one is drawn for it larger than the frame.
		over = function() return Shy.HUD.HousingOf(frame) or frame end,
		shown = function()
			return windowsOn and T.db.options.moveWindows.cornerScale
				and not (frame == WorldMapFrame and WorldMapFrame:IsMaximized())
		end,
		held = function(_, on) frame.shyApplying = on end,
		kept = function()
			Remember(frame)
			T.db.frames[frame:GetName()].scale = frame:GetScale()
		end,
	})
end

-- Over the title bar only: with the whole window registered, scroll bar thumbs and sliders start a
-- window drag. A window with a panel drawn for it larger than itself (Shy.HUD.SetHousing: ShySkin's game
-- menu) is dragged by that panel's title strip, placed again as it shows.
local function PlaceHandle(frame)
	local handle = handles[frame]
	if not handle then return end
	handle:ClearAllPoints()
	local housing = Shy.HUD.HousingOf(frame)
	local title = frame.TitleContainer or (frame.BorderFrame and frame.BorderFrame.TitleContainer)
	if housing then
		handle:SetPoint("TOPLEFT", housing, "TOPLEFT", 0, 0)
		handle:SetPoint("TOPRIGHT", housing, "TOPRIGHT", 0, 0)
		handle:SetHeight(TITLE_STRIP)
		handle:SetFrameLevel(frame:GetFrameLevel() + 1)
	elseif title then
		handle:SetAllPoints(title)
		handle:SetFrameLevel(title:GetFrameLevel() + 1)
	else
		handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
		handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -TITLE_CLEAR, 0)
		handle:SetHeight(TITLE_STRIP)
		handle:SetFrameLevel(frame:GetFrameLevel() + 1)
	end
end

local function Hook(frame)
	if hooked[frame] or not frame.GetName or not frame:GetName() then return end
	-- A load-on-demand window can load in combat; a protected one waits.
	if Locked(frame) then
		ns.OutOfCombat("hook:" .. frame:GetName(), function() Hook(frame) end)
		return
	end
	hooked[frame] = true
	frame:SetMovable(true)
	local handle = CreateFrame("Frame", nil, frame)
	handles[frame] = handle
	PlaceHandle(frame)
	frame:HookScript("OnShow", PlaceHandle)
	handle:EnableMouse(windowsOn == true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function() OnDragStart(frame) end)
	handle:SetScript("OnDragStop", function() OnDragStop(frame) end)
	frame:HookScript("OnHide", OnDragStop)
	frame:HookScript("OnShow", Apply)
	frame:HookScript("OnShow", Grip)
	hooksecurefunc(frame, "SetPoint", Apply)
	Apply(frame)
	if frame:IsShown() then Grip(frame) end
end

local function HookAll()
	for name in pairs(UIPanelWindows) do
		local frame = _G[name]
		if type(frame) == "table" then Hook(frame) end
	end
	for _, name in ipairs(EXTRA_FRAMES) do
		if _G[name] then Hook(_G[name]) end
	end
end

-- A window back as the game has it: its own size at once, and an open one at the default spot (the panel
-- manager places it properly on its next open). In a fight a protected one waits for the end of it.
local function Home(frame)
	if Locked(frame) then
		ns.OutOfCombat("home:" .. frame:GetName(), function()
			if not (windowsOn and Saved(frame)) then Home(frame) end
		end)
		return
	end
	frame.shyApplying = true
	frame:SetScale(1)
	if frame:IsShown() then
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	end
	frame.shyApplying = false
end

local function ResetFrame(name)
	T.db.frames[name] = nil
	local frame = _G[name]
	if type(frame) == "table" and frame.SetScale then Home(frame) end
end

function ns.ResetWindows()
	for name in pairs(T.db.frames) do ResetFrame(name) end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.MovedWindows()
	local list = {}
	for name in pairs(T.db.frames) do list[#list + 1] = name end
	table.sort(list)
	return list
end
ns.ResetFrame = ResetFrame

-- Bags

-- Separate bags are children of ContainerFrameContainer, which Blizzard never
-- re-anchors: offsetting it moves them all. The combined bag is a child of
-- UIParent and anchors to its parent, so it is reparented into the holder.

-- ShyBags has replaced the default bags: leave them alone.
local function BagsTaken()
	local bags = Shy.addons.Bags
	return bags ~= nil and bags.owns.window == true
end

function ns.BagsMoved()
	local o = T.db.bagOffset
	return o.x ~= 0 or o.y ~= 0
end

local function HomeCombinedBag()
	local bag = ContainerFrameCombinedBags
	if BagsTaken() then return end
	ns.OutOfCombat("combinedBag", function()
		local parent = bagsOn and ContainerFrameContainer or UIParent
		local old = bag:GetParent()
		if old == parent then return end
		FrameUtil.SetParentMaintainRenderLayering(bag, parent)
		-- An open bag is still anchored to its old parent; carry the anchor over.
		local point, relativeTo, relativePoint, x, y = bag:GetPoint(1)
		if relativeTo == old then
			bag:ClearAllPoints()
			bag:SetPoint(point, parent, relativePoint, x, y)
		end
	end)
end

function ns.ApplyBags()
	local holder = ContainerFrameContainer
	HomeCombinedBag()
	for _, handle in pairs(titleHandles) do handle:EnableMouse(bagsOn == true) end
	ns.OutOfCombat(holder, function()
		local o = bagsOn and T.db.bagOffset or { x = 0, y = 0 }
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", o.x, o.y)
		holder:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", o.x, o.y)
	end)
end

Shy:On("SHY_BAGS_OWNS", function(piece)
	if piece == "window" and bagsOn ~= nil then ns.ApplyBags() end
end)

local bagDrag

local function BagDragUpdate()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	T.db.bagOffset = {
		x = Shy.HUD.GridStep(bagDrag.x + (x - bagDrag.cx) / scale),
		y = Shy.HUD.GridStep(bagDrag.y + (y - bagDrag.cy) / scale),
	}
	ns.ApplyBags()
end

local dragDriver = CreateFrame("Frame")

local function BagDragStart()
	if not bagsOn or InCombatLockdown() then return end
	local x, y = GetCursorPosition()
	bagDrag = { cx = x, cy = y, x = T.db.bagOffset.x, y = T.db.bagOffset.y }
	dragDriver:SetScript("OnUpdate", BagDragUpdate)
end

local function BagDragStop()
	if not bagDrag then return end
	bagDrag = nil
	dragDriver:SetScript("OnUpdate", nil)
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.ResetBags()
	T.db.bagOffset = { x = 0, y = 0 }
	if bagsOn ~= nil then ns.ApplyBags() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- An unnamed Blizzard button over the bag's title (the bag menu) swallows drags; this handle goes above it.
local function TitleHandle(bag)
	local title = bag.TitleContainer
	local handle = CreateFrame("Frame", nil, bag)
	handle:SetAllPoints(title)
	local level = title:GetFrameLevel()
	for _, child in ipairs({ bag:GetChildren() }) do
		if child.routeToSibling then level = math.max(level, child:GetFrameLevel()) end
	end
	handle:SetFrameLevel(level + 1)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", BagDragStart)
	handle:SetScript("OnDragStop", BagDragStop)
	titleHandles[bag] = handle
end

local function HookBags()
	local bags = { ContainerFrameCombinedBags }
	for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do bags[#bags + 1] = frame end
	for _, frame in ipairs(bags) do
		if not hookedBags[frame] then
			hookedBags[frame] = true
			frame:RegisterForDrag("LeftButton")
			frame:HookScript("OnDragStart", BagDragStart)
			frame:HookScript("OnDragStop", BagDragStop)
			frame:HookScript("OnHide", BagDragStop)
			TitleHandle(frame)
		end
	end
end

-- Features

ns.Feature({
	id = "moveWindows",
	category = "Windows",
	title = "Move and resize windows",
	desc = "Drag a game window by its title bar. It opens there next time.",
	keywords = "drag position map character spellbook talent quest log vendor trainer frame window scale size resize corner edge grip",
	default = true,
	options = {
		{ key = "cornerScale", kind = "checkbox", label = "Resize by the edges", default = true,
			desc = "Drag a corner or an edge of a window to make it bigger or smaller." },
		{ kind = "windows", shown = function() return #ns.MovedWindows() > 0 end },
		{ kind = "button", label = "Moved windows", button = "Reset", shown = function() return #ns.MovedWindows() > 0 end,
			desc = "Every window you moved goes back to where the game opens it, at its own size.",
			run = function() ns.ResetWindows() end },
	},
	events = {
		ADDON_LOADED = function() HookAll() end,
		-- This client sometimes never delivers OnMouseUp to a dragged window.
		GLOBAL_MOUSE_UP = function()
			for frame in pairs(hooked) do
				if frame.shyMoving then OnDragStop(frame) end
			end
		end,
	},
	Enable = function()
		windowsOn = true
		HookAll()
		for frame, handle in pairs(handles) do
			handle:EnableMouse(true)
			Apply(frame)
			if frame:IsShown() then Grip(frame) end
		end
	end,
	Disable = function()
		for frame in pairs(hooked) do
			if frame.shyMoving then OnDragStop(frame) end
		end
		windowsOn = false
		for frame, handle in pairs(handles) do
			handle:EnableMouse(false)
			if Saved(frame) then Home(frame) end
		end
	end,
})

-- (Left out while ShyBags' window stands in for the game's bags: there is nothing of the game's to move.)
ns.Feature({
	id = "moveBags",
	category = "Windows",
	title = "Move bags",
	desc = "Drag an open bag by its title bar to move all your bags. Hold Shift to place them off the grid.",
	keywords = "bags bag inventory backpack container position drag move",
	default = true,
	yields = BagsTaken,
	events = {
		GLOBAL_MOUSE_UP = function() BagDragStop() end,
	},
	options = {
		{ kind = "button", label = "Moved bags", button = "Put back", shown = ns.BagsMoved,
			desc = "Your bags go back to where the game opens them.",
			run = function() ns.ResetBags() end },
	},
	Enable = function()
		bagsOn = true
		HookBags()
		ns.ApplyBags()
	end,
	Disable = function()
		bagsOn = false
		BagDragStop()
		ns.ApplyBags()
	end,
})
