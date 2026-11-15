-- Bars that grow with the character (ns.char.grow): when the abilities known
-- outgrow the bars (Layout.StepFor), a card over the console offers the next
-- step. Each step is offered once (ns.char.asked); taking it sets the console
-- up with that step's bars, which needs a reload. Never in a fight, in Edit
-- Mode or layout mode, or while the setup window is open.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local G = {}
ns.Grow = G

local W, H = 360, 118
local WAIT = 1.5     -- after a spell is learned: the spellbook settles, and a level up's learning comes together
local ROWS = { "a second row of bars", "a third row of bars" }

local card, editing, pending

-- The step the abilities ask for, and the step the bars are at; nil when there's nothing to ask.
function G.Want()
	if not (ns.char.grow and ns.Layout.IsActive()) then return nil end
	local L = ns.Layout
	local abilities = L.Abilities()
	local need, now = L.StepFor(abilities), L.StepNow()
	-- (keys laid out stand on all three rows and both flyouts' bars, however few abilities there are yet)
	if Shy.Keys and Shy.Keys.Wanted and Shy.Keys.Wanted() then need = math.max(need, L.KEYED) end
	if need <= now or need <= (ns.char.asked or 0) then return nil end
	return need, now, abilities
end

-- "You know 23 abilities. A third row of bars gives them room."
function G.Words(need, now, abilities)
	local L = ns.Layout
	local want, have = L.STEPS[need], L.STEPS[now]
	local more = {}
	local rows = want.rows - have.rows
	if rows == 1 then more[#more + 1] = ROWS[want.rows - 1] elseif rows > 1 then more[#more + 1] = "two more rows of bars" end
	if want.sides > have.sides then more[#more + 1] = "a second side bar" end
	local room = table.concat(more, " and "):gsub("^%l", string.upper)
	local many = #more > 1 or rows > 1
	return ("You know %d abilities. %s%sthem room."):format(abilities, room, many and " give " or " gives ")
end

local function Hold(on)
	local I = Shy.Immersion
	if I and I.Hold then I.Hold("shydock-grow", on) end
end

function G.Hide()
	if card and card:IsShown() then
		card:Hide()
		Hold(false)
	end
end

local function Build()
	card = CreateFrame("Frame", "ShyDockGrow", UIParent)
	card:SetSize(W, H)
	card:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
	card:SetFrameStrata("HIGH")
	card:EnableMouse(true)   -- so clicks don't fall through to the world
	card:Hide()
	UI.Head(card, { title = "More room" })
	-- What is on in the text color, what would come in the accent.
	card.drawing = ns.Preview.BarsDrawing(card, 5, 1)
	card.drawing:SetPoint("TOPLEFT", 12, -32)
	card.words = UI.Text(card, "", 12)
	card.words:SetPoint("TOPLEFT", card.drawing, "TOPRIGHT", 14, 2)
	card.words:SetWidth(W - 14 - card.drawing:GetWidth() - 14 - 10)
	card.words:SetWordWrap(true)
	local later = UI.Text(card, "Turn this off in /shydock.", 10, false, C.dim)
	later:SetPoint("BOTTOMLEFT", 10, 14)

	card.add = UI.Button(card, "Add bars", 96, function()
		if InCombatLockdown() then return end
		local need = card.need
		ns.char.asked = math.max(ns.char.asked or 0, need)
		G.Hide()
		ns.Layout.Report(ns.Layout.SetUp(nil, nil, { step = need, words = "Your new bars are ready. Reload to show them." }))
	end)
	card.add:SetPoint("BOTTOMRIGHT", -8, 8)
	UI.SetFill(card.add, C.fill)
	card.later = UI.Button(card, "Not now", 76, function()
		-- Asked again only when a later step is needed.
		ns.char.asked = math.max(ns.char.asked or 0, card.need or 0)
		G.Hide()
	end)
	card.later:SetPoint("RIGHT", card.add, "LEFT", -6, 0)
end

local function Busy()
	return InCombatLockdown() or editing or Shy.HUD.IsUnlocked() or (Shy.Setup and Shy.Setup.IsOpen())
end

function G.Check()
	pending = nil
	if Busy() then
		if InCombatLockdown() then
			G.Hide()
			G.asked = true   -- looked at again once the fight is over
		end
		return
	end
	local need, now, abilities = G.Want()
	if not need then
		G.Hide()
		return
	end
	if not card then Build() end
	card.need = need
	local L = ns.Layout
	card.drawing:Paint(L.STEPS[now], L.STEPS[need])
	card.words:SetText(G.Words(need, now, abilities))
	card.add.text:SetText((L.STEPS[need].rows - L.STEPS[now].rows) + (L.STEPS[need].sides - L.STEPS[now].sides) > 1 and "Add bars" or "Add a bar")
	if not card:IsShown() then
		card:Show()
		Hold(true)
	end
end

-- Once things settle: learning several spells at a level up fires several events.
function G.Soon()
	if pending then return end
	pending = true
	C_Timer.After(WAIT, G.Check)
end

local started

function G.Start()
	if started then return end
	started = true
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED" }) do
		events:RegisterEvent(event)
	end
	events:RegisterEvent("PLAYER_REGEN_DISABLED")
	-- After a fight the card is looked at again only if the fight put it away or something asked meanwhile.
	local owed
	events:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_DISABLED" then
			owed = card ~= nil and card:IsShown()
			G.Hide()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if owed or G.asked then G.Soon() end
			owed, G.asked = nil, nil
		else
			G.Soon()
		end
	end)
	EventRegistry:RegisterCallback("EditMode.Enter", function()
		editing = true
		G.Hide()
	end, G)
	EventRegistry:RegisterCallback("EditMode.Exit", function()
		editing = nil
		G.Soon()
	end, G)
	Shy:On("SHY_HUD_LAYOUT", function(on)
		if on then G.Hide() else G.Soon() end
	end)
	-- A while after logging in, when the setup window has had its chance.
	C_Timer.After(10, G.Soon)
end

Shy:On("SHY_LOGIN", function() G.Start() end)
