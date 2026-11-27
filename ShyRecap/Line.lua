-- The on-screen recap line (a Shy.HUD box) and the ledger a click on it opens.
-- The line is a row in the drawer under the head at the top's middle (Shy.Top's tray), with the bars and the
-- messages. The ledger opens downward from the drawer's foot.
-- The ledger never opens unasked: a click opens it, another closes it, Shift-click shares.

local ADDON, ns = ...
local T = ns.T
local HUD = Shy.HUD
local LINE = ns.LINE

local GAP = 5    -- between the line and the ledger
local HOME = { "TOP", "TOP", 0, -4 }   -- until the column places it

local box, line, ledger
local tray             -- the line's tray: in the head's drawer, or by itself
local hold             -- the ledger's own box, hung from the line: sized apart from it
local test             -- the sample view shown by "/shy recap test"
local viewing          -- an earlier death shown in the ledger instead of the line's

-- The view the line shows, or nil when it should be hidden.
local function Current()
	if test then return test end
	local up = ns.char.up
	local death = up and T:IsOn() and ns.Latest() or nil
	-- "/shy recap" (up == "asked") shows any death; otherwise the "creatures" filter applies.
	if death and (up == "asked" or ns.Wanted(death)) then return ns.View(death) end
end

local function Fold()
	viewing = nil
	ledger:Hide()
	HUD.Update(hold)
end

-- The ledger's box is as large as the ledger and hangs from the drawer the line is in (from the line by
-- itself): below it, or above it when there is no room below (each measured at its own size). Its grip
-- scales it about the point it hangs by.
local function Hang()
	if not ledger:IsShown() then return end
	HUD.Resize(hold, ledger:GetWidth(), ledger:GetHeight())
	local from = Shy.Top.Hung(box) and Shy.Top.Drawer() or line
	local below = from:GetBottom()
	local over = below ~= nil and (ledger:GetHeight() + GAP) * hold:GetScale() > below * from:GetEffectiveScale() / UIParent:GetEffectiveScale()
	hold.grip.hung = over and "BOTTOM" or "TOP"
	HUD.Attach(hold, from, over and "BOTTOM" or "TOP", over and "TOP" or "BOTTOM", 0, over and GAP or -GAP)
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

-- The line in its tray: as wide as the column's rows, from the drawer's inner face to its inner face (by
-- itself, inside its own border).
local function Lay()
	if not (box and tray) then return end
	local width, inset = tray:Fit(line:Need(), box:IsShown() and LINE.h or 0)
	line:SetWidth(width)
	line:ClearAllPoints()
	line:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
	line:Rule(Shy.Top.Hung(box))
	line:Tick()
	Hang()
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
	Lay()
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
	if not T:IsOn() then
		T:Print("death recap is off.")
		return
	end
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
	root:CreateButton("Settings", function() T:OpenOptions() end)
	root:CreateButton("Close", CloseLine)
end

-- The line as a picture, for a drawing of the screen: a made-up death in a tray by itself, and nothing on it
-- takes the mouse.
local function Picture(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:EnableMouse(false)
	local picture = ns.CreateLine(f)
	picture:Set(ns.Death.Sample())
	picture.close:EnableMouse(false)
	return Shy.Top.Make.Still(f, math.max(LINE.w, picture:Need()), { picture })
end

function ns.SetupLine()
	box = HUD.Create({
		id = "shyrecap", title = "Death recap",
		width = LINE.w, height = LINE.h, point = HOME,
		shown = function() return Current() ~= nil end,
		-- Its setting, "Death recap". ns.Apply tells the settings it changed.
		switch = {
			get = function() return T.db.on ~= false end,
			set = function(on)
				T.db.on = on
				ns.Apply()
			end,
			hint = "What killed you, when you die",
		},
		-- A row in the drawer under the head, after breath and fatigue.
		top = { order = 10, sample = Picture, passing = true, wrap = true },
	})
	box:SetFrameStrata("DIALOG")
	line = ns.CreateLine(box)
	line:SetPoint("TOPLEFT")
	line.onClose = CloseLine
	tray = Shy.Top.Tray(box, { lay = Lay })

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

	-- (The column's width, who hangs and the look are its tray's to tell: Lay. Shown or hidden, it takes its room or
	-- gives it back.)
	box:HookScript("OnShow", Lay)
	box:HookScript("OnHide", Lay)

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
		if not T:IsOn() then test = nil end   -- switched off, a sample goes too
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
