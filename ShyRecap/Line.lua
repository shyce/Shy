-- The on-screen recap line (a Shy.HUD box) and the ledger a click on it opens.
-- The line leads the column down from the top's middle (Shy.Top gives it its place there, over the
-- Return to Graveyard button and the waypoint arrow). The ledger opens downward from it.
-- The ledger never opens unasked: a click opens it, another closes it, Shift-click shares.

local ADDON, ns = ...
local T = ns.T
local HUD = Shy.HUD
local LINE = ns.LINE

local GAP = 5    -- between the line and the ledger
local HOME = { "TOP", "TOP", 0, -4 }   -- until the column places it

local box, line, ledger
local hold             -- the ledger's own box, hung from the line: sized apart from it
local test             -- the sample view shown by "/shyrecap test"
local viewing          -- an earlier death shown in the ledger instead of the line's

-- The view the line shows, or nil when it should be hidden.
local function Current()
	if test then return test end
	local up = ns.char.up
	local death = up and T:IsOn() and ns.Latest() or nil
	-- "/shyrecap" (up == "asked") shows any death; otherwise the "creatures" filter applies.
	if death and (up == "asked" or ns.Wanted(death)) then return ns.View(death) end
end

local function Fold()
	viewing = nil
	ledger:Hide()
	HUD.Update(hold)
end

-- The ledger's box is as large as the ledger and hangs from the line: below it, or above it when there
-- is no room below (each measured at its own size). Its grip scales it about the point it hangs by.
local function Hang()
	if not ledger:IsShown() then return end
	HUD.Resize(hold, ledger:GetWidth(), ledger:GetHeight())
	local below = box:GetBottom()
	local over = below ~= nil and (ledger:GetHeight() + GAP) * hold:GetScale() > below * box:GetScale()
	hold.grip.hung = over and "BOTTOM" or "TOP"
	HUD.Attach(hold, line, over and "BOTTOM" or "TOP", over and "TOP" or "BOTTOM", 0, over and GAP or -GAP)
end

local function Tell(view)
	ledger:Set(view)
	Hang()
end

local function Unfold(view)
	ledger:Show()
	HUD.Update(hold)
	Tell(view)
end

-- While a ghost can go back (the game's button shows), the line carries the way back at its end: one
-- ribbon, the killer and then the action, ShyCore's own (Shy.Top.Graveyard), the line's plaque under both.
-- The line is the column's width (Shy.Top.Width: the widest plate any piece up there needs), its ring's
-- middle under the head's circle's, so the column reads as one piece. The way back to the graveyard is a
-- row of the column's own under it, as wide.
local function Ghost()
	if not box then return end
	local Top = Shy.Top
	local ring = Top.Make.RING
	local need = line:Need()
	Top.Want(box, box:IsShown() and need or 0)
	local plate = math.max(need, Top.Width())
	line:SetWidth(plate + ring / 2)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", box, "TOPLEFT", Top.SPINE - ring / 2, 0)
	HUD.Resize(box, plate + 2 * Top.SPINE, LINE.h)
	line:Tick()
end

function ns.Refresh()
	if not box then return end
	local view = Current()
	if view then
		line:Set(view)
	elseif HUD.IsUnlocked() then
		line:Set(ns.Death.Sample())   -- a sample to position in layout mode
	end
	HUD.Update(box)
	Ghost()
	if not view then
		Fold()
	elseif ledger:IsShown() then
		Tell(viewing and ns.View(viewing) or view)
	end
end

-- stay == "alive": hide the line once alive, unless it was opened by command.
local function Rise()
	if ns.char.up ~= true or T.db.stay ~= "alive" then return end
	local dead = UnitIsDeadOrGhost("player")
	if issecretvalue(dead) or dead then return end
	ns.char.up = false
	ns.Refresh()
end

-- Shows the last death's line again. False when there is none.
function ns.Open()
	if not (box and T:IsOn() and ns.Latest()) then return false end
	test = nil
	ns.char.up = "asked"
	ns.Refresh()
	return true
end

function ns.Test()
	if not box then return end
	Fold()
	test = ns.Death.Sample()
	ns.Refresh()
	T:Print("sample death shown. Click the line for the recap, x to close.")
end

-- Returns the box, the line, the ledger and the ledger's own box.
function ns.Parts()
	return box, line, ledger, hold
end

local function CloseLine()
	if test then test = nil else ns.char.up = false end
	Fold()
	ns.Refresh()
end

local function Menu(root)
	-- Not the sample: it is nobody's death.
	local death = not test and line.view and line.view.death
	if death then
		Shy.UI.TellMenu(root, ns.Killer(death) and "Tell who killed you" or "Tell where you died",
			function() return ns.ShareText(death) end, function() return ns.Where(death) end)
	end
	root:CreateButton("Options", function() T:OpenOptions() end)
	root:CreateButton("Close", CloseLine)
end

-- The line as a picture, for a drawing of the screen: a made-up death, and nothing on it takes the mouse.
local function Picture(parent)
	local picture = ns.CreateLine(parent)
	picture:Set(ns.Death.Sample())
	picture.close:EnableMouse(false)
	return picture
end

function ns.SetupLine()
	box = HUD.Create({
		id = "shyrecap", title = "Death recap",
		width = LINE.w, height = LINE.h, point = HOME,
		shown = function() return Current() ~= nil end,
		-- Its options' "Show death recap".
		switch = {
			get = function() return T.db.on ~= false end,
			set = function(on)
				T.db.on = on
				ns.Apply()
				if ns.RefreshOptions then ns.RefreshOptions() end
			end,
			hint = "What killed you, when you die",
		},
		top = { order = 10, sample = Picture, passing = true },
	})
	line = ns.CreateLine(box)
	line:SetPoint("TOPLEFT")
	line.onClose = CloseLine

	-- The ledger stands in a box of its own, so its corners and sides size it apart from the line and
	-- the size is kept. The box is carried: where it stands is the line's to say (Hang), never kept.
	hold = HUD.Create({
		id = "shyrecap.ledger", title = "Death recap",
		width = ns.LEDGER.w, height = 100, point = HOME, window = true,
		shown = function() return ledger ~= nil and ledger:IsShown() and box:IsShown() end,
	})
	hold:SetFrameStrata("DIALOG")
	HUD.SetCarried(hold, true)
	ledger = ns.CreateLedger(hold)
	ledger:SetPoint("TOPLEFT")
	ledger:Hide()
	hold.grip = { over = ledger, hung = "TOP" }
	HUD.Update(hold)
	ledger.onClose = Fold
	ledger.onEarlier = function(death)
		if test then return end   -- a sample's earlier deaths have no records
		viewing = death
		Tell(ns.View(death))
	end
	-- Sized, or placed again by the core: back on the line.
	local function Rehang(which)
		if which == hold then Hang() end
	end
	Shy:On("SHY_HUD_RESIZED", Rehang)
	Shy:On("SHY_HUD_MOVED", Rehang)

	line:EnableMouse(true)
	line:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or HUD.WasDragged(box) or not line.view or HUD.IsUnlocked() then return end
		if IsShiftKeyDown() then
			ns.Share(line.view.death)
			return
		end
		if ledger:IsShown() then
			Fold()
			return
		end
		local death = line.view.death
		if not death.seen then
			death.seen = true
			line:Light()
		end
		Unfold(line.view)
	end)
	HUD.Manage(box, line, Menu)

	-- The column's width changed: the line is laid at it.
	Shy:On("SHY_TOP_WIDTH", Ghost)
	box:HookScript("OnShow", Ghost)
	box:HookScript("OnHide", Ghost)

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_ALIVE")
	events:RegisterEvent("PLAYER_UNGHOST")
	events:SetScript("OnEvent", function()
		-- Releasing fires PLAYER_ALIVE as a ghost; check again shortly in case the state updates late.
		Rise()
		C_Timer.After(0.5, Rise)
	end)
	Shy:On("SHY_HUD_LAYOUT", function(on)
		if on then Fold() end
		ns.Refresh()
	end)
	Shy:On("SHY_THEME", ns.Refresh)
	ns.OnApply(function()
		Rise()
		ns.Refresh()
	end)
	-- Keeps "12 min ago" current.
	C_Timer.NewTicker(15, function()
		if not box:IsShown() then return end
		line:Tick()
		if ledger:IsShown() then ledger:Tick() end
	end)

	Rise()
	ns.Refresh()
end
