-- Layout updates (Layout.lua, L.SHAPE): a console set up before a release moved what a setup writes is offered the
-- new places on a card over the console, at every login until the player picks. "Update" moves only what is as
-- the setup left it; "Keep mine" asks no more for this update; × asks again next login. An update that would move
-- nothing marks the console current with no card. After the update's reload a notice says it is done, and its
-- right click puts the old layout back. Never in a fight, in Edit Mode or layout mode, or while setup is open.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local U = {}
ns.Update = U

local W, H = 340, 104
local NOTICE = "shydock-update"

local card, editing

local function Hold(on)
	local I = Shy.Immersion
	if I and I.Hold then I.Hold("shydock-update", on) end
end

function U.Hide()
	if card and card:IsShown() then
		card:Hide()
		Hold(false)
	end
end

-- "Your layout has new places for 3 pieces. Anything you moved stays where you put it."
function U.Words(moved)
	local pieces = moved == 1 and "one piece" or (moved .. " pieces")
	return ("Your layout has new places for %s. Anything you moved stays where you put it."):format(pieces)
end

local function Build()
	card = CreateFrame("Frame", "ShyDockUpdate", UIParent)
	card:SetSize(W, H)
	card:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	card:SetFrameStrata("HIGH")
	card:EnableMouse(true)   -- so clicks don't fall through to the world
	card:Hide()
	UI.Head(card, { title = "Layout update", close = function() U.Hide() end })
	local body = UI.Body(card)
	UI.BodyFit(card, W, H)
	card.words = UI.Text(body, "", 12)
	card.words:SetPoint("TOPLEFT", 12, -32)
	card.words:SetWidth(W - 24)
	card.words:SetWordWrap(true)
	card.update = UI.Button(body, "Update", 86, function()
		if InCombatLockdown() then return end
		U.Hide()
		ns.Layout.Report(ns.Layout.Update())
	end)
	card.update:SetPoint("BOTTOMRIGHT", -8, 8)
	UI.SetFill(card.update, C.fill)
	card.keep = UI.Button(body, "Keep mine", 86, function()
		ns.Layout.SkipUpdate()
		U.Hide()
	end)
	card.keep:SetPoint("RIGHT", card.update, "LEFT", -6, 0)
end

local function Busy()
	return InCombatLockdown() or editing or Shy.HUD.IsUnlocked() or (Shy.Setup and Shy.Setup.IsOpen())
end

-- The notice after an update's reload: it is done, and the old layout is a right click away.
local function Told()
	if not ns.char.updated then return end
	ns.char.updated = nil
	local notices = Shy.Notices
	if not (notices and notices.Post) then return end
	notices.Post(NOTICE, {
		order = 70, glyph = "note", color = C.hot,
		title = "Layout updated",
		says = "Right-click to put the old layout back.",
		hold = 60,
		menu = function(root)
			root:CreateButton("Put the old layout back", function()
				notices.Clear(NOTICE)
				ns.Layout.Report(ns.Layout.UndoUpdate())
			end)
		end,
	})
end

function U.Check()
	if Busy() then
		if InCombatLockdown() then U.Hide() end
		return
	end
	local moved = ns.Layout.UpdateWaiting()
	if not (moved and moved > 0) then
		U.Hide()
		return
	end
	if not card then Build() end
	card.words:SetText(U.Words(moved))
	if not card:IsShown() then
		card:Show()
		Hold(true)
	end
end

local started

function U.Start()
	if started then return end
	started = true
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	local owed
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			owed = card ~= nil and card:IsShown()
			U.Hide()
		elseif owed then
			owed = nil
			U.Check()
		end
	end)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		editing = true
		U.Hide()
	end, U)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		editing = nil
		U.Check()
	end, U)
	Shy:On("SHY_HUD_LAYOUT", function(on)
		if on then U.Hide() else U.Check() end
	end)
	-- A while after logging in: the bars laid out, a setup's first login settled (ShyDock.lua's five seconds).
	C_Timer.After(8, function()
		Told()
		U.Check()
	end)
end

Shy:On("SHY_LOGIN", function() U.Start() end)
