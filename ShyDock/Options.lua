-- Options page: the switches, the screen preview with the layouts and sizes
-- (Preview.lua), the bars a character has, layout mode, and the way back to
-- the previous layout.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local C = UI.colors

local LEFT, WIDE = 24, 600
local BUTTON, GAP = 190, 14

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Help(frame, title, text)
	UI.Help(frame, title, text, { side = "RIGHT" })
end

local function Action(page, y, label, line, help, onClick)
	local button = At(UI.Button(page, label, BUTTON, onClick), page, LEFT, y)
	Help(button, label, help)
	local text = UI.Text(page, line, 12, false, C.dim)
	text:SetPoint("LEFT", button, "RIGHT", GAP, 0)
	text:SetWidth(WIDE - BUTTON - GAP)
	text:SetWordWrap(true)
	return button
end

-- The bars: a tile per step with a small drawing of its rows and side bars.
local STEP_NAMES = { "One bar", "Two bars", "Three bars", "Every bar" }
local STEP_H = 70

local function StepTile(parent, width, i, onClick)
	local L = ns.Layout
	local step = L.STEPS[i]
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, STEP_H)
	UI.Skin(b)
	b.name = UI.Text(b, STEP_NAMES[i], 13, true)
	b.name:SetPoint("TOPLEFT", 10, -8)
	b.used = UI.Text(b, "in use", 10, true, C.good)
	b.used:SetPoint("TOPRIGHT", -8, -9)
	b.drawing = ns.Preview.BarsDrawing(b, 5, 1)
	b.drawing:SetPoint("BOTTOM", 0, 10)

	-- In use: the step's bars in the accent; otherwise in the text color.
	function b:Paint(inUse, wanted)
		self.used:SetShown(inUse)
		UI.SetFill(self, inUse and C.row or C.bg)
		UI.SetBorder(self, (inUse or self.hover) and C.hot or wanted and C.alert or C.border)
		if inUse then self.drawing:Paint(nil, step) else self.drawing:Paint(step, nil) end
	end
	b:SetScript("OnEnter", function(self)
		self.hover = true
		UI.SetBorder(self, C.hot)
	end)
	b:SetScript("OnLeave", function(self)
		self.hover = false
		if parent.Stand then parent.Stand() end
	end)
	b:SetScript("OnClick", function()
		if InCombatLockdown() then return end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		onClick(i)
	end)
	return b
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)
	local goBack, section, steps, know

	local function Stand()
		section:Refresh()
		goBack:SetAlpha((InCombatLockdown() or not ns.Layout.IsActive()) and 0.4 or 1)
		local L = ns.Layout
		local active, now = L.IsActive(), L.StepNow()
		local abilities = L.Abilities()
		local need = L.StepFor(abilities)
		for i, tile in ipairs(steps) do
			tile:SetAlpha(InCombatLockdown() and 0.4 or 1)
			tile:Paint(active and now == i, need == i and need > now)
		end
		local fits = need <= now and "your bars have room for them" or ("they need " .. STEP_NAMES[need]:lower())
		know:SetText(("You know %d abilities: %s. Click a tile to set up with those bars; bars put away keep their buttons. Needs a reload."):format(abilities, fits))
	end
	panel.Stand = function() if panel.built then Stand() end end

	-- A fight begins or ends: only what it dims, and only on show (the page stands again as it opens).
	local function Dim()
		if not panel:IsVisible() then return end
		local fighting = InCombatLockdown()
		if section.Dim then section:Dim() end
		goBack:SetAlpha((fighting or not ns.Layout.IsActive()) and 0.4 or 1)
		for _, tile in ipairs(steps) do tile:SetAlpha(fighting and 0.4 or 1) end
	end

	local function Build()
		UI.PageHeader(panel, T)

		At(UI.Header(panel, "Console", WIDE), panel, LEFT, -112)
		At(group:Checkbox(panel, "Bar housing", Get("housing"), Set("housing"), {
			desc = "A steel frame behind the bottom action bars and the side bars. It follows the bars when you move them in Edit Mode and hides the main bar's gryphons.",
		}), panel, LEFT, -144)
		At(group:Checkbox(panel, "Menu in a drawer", Get("menuDrawer"), Set("menuDrawer"), {
			desc = "The micro menu and bags tuck away under the guide. Point at its header to use them; click it to keep them out.",
			enabled = Get("arrange"),
		}), panel, LEFT + 340, -144)
		At(group:Checkbox(panel, "Arrange boxes around the console", Get("arrange"), Set("arrange"), {
			desc = "While you use the console, your other addons' boxes get their own spots around it. A box you moved stays put until you set up the console again.",
		}), panel, LEFT, -170)
		At(group:Checkbox(panel, "Dock guide and group status", Get("deck"), Set("deck"), {
			desc = "Stacks the guide and group status under the minimap in one panel, with a tab to show or hide each; your level shows on the guide. The deck moves as one piece; right-click it to take a box out and place it yourself, or put it back.",
			enabled = Get("arrange"),
		}), panel, LEFT + 20, -196)
		-- The cooldown manager: the picker (its size and the tracked bars' side), its switches,
		-- and the way into taking it apart.
		At(UI.Header(panel, "Cooldown manager", WIDE), panel, LEFT, -236)
		local y = -266
		if ns.Vessel and ns.Vessel.Section then
			local picker = At(ns.Vessel.Section(panel, WIDE), panel, LEFT, y)
			y = y - picker:GetHeight() - 16
		end
		At(group:Checkbox(panel, "Combo points on the cooldown manager", Get("blades"), Set("blades"), {
			desc = "Rogue combo points (ShyRogue) sit in the cooldown manager's top edge and move with it. Off, they are a separate box and tracked buffs take that spot.",
			enabled = Get("arrange"),
		}), panel, LEFT, y)
		At(group:Checkbox(panel, "See-through cooldown manager", Get("cockpitFollow"), Set("cockpitFollow"), {
			desc = "The cooldown manager and cast bar use the Opacity set on /shy. Off, they are solid.",
		}), panel, LEFT, y - 26)
		At(group:Checkbox(panel, "Swing timer", Get("swing"), Set("swing"), {
			desc = "While you swing, a bar for each weapon takes your cast bar's spot until you cast, gold when a next-swing ability is queued and red when your target is out of reach.",
		}), panel, LEFT + 340, y)
		At(group:Checkbox(panel, "Cooldowns in combat only", Get("cooldownsInCombat"), function(v)
			T.db.cooldownsInCombat = v
			ns.Layout.CooldownsInCombat()
		end, {
			desc = "Shows your essential and utility cooldowns only in a fight; tracked buffs stay up. Needs a reload.",
		}), panel, LEFT + 340, y - 26)
		At(group:Checkbox(panel, "Bars and pings on it", Get("joined"), Set("joined"), {
			desc = "Puts your tracked bars beside the cooldown manager and the pings and markers in its end. Off, each has a place of its own you can drag in layout mode; in a layout by role your bars always stand by your frames.",
			enabled = Get("arrange"),
		}), panel, LEFT, y - 52)
		y = y - 88
		if ns.Pieces then
			Action(panel, y, "Take apart",
				"Every piece gets a handle of its own: drag one out, or back onto its socket.",
				"Opens layout mode with the cooldown manager taken apart. Drag a piece away to take it out; drop it back on its socket to seat it again. A piece taken out is its own box: drag it, size it with the wheel, lock it. Works in Edit Mode too.",
				function()
					if InCombatLockdown() then return end
					ns.Pieces.Enter()
				end)
			y = y - 36
		end
		Action(panel, y, "Center the cooldown manager",
			"Moves it back under your character.",
			"Moves the cooldown manager back to its default spot under your character.",
			function()
				if InCombatLockdown() then return end
				ns.Move.Reset()
				Stand()
			end)
		y = y - 50

		At(UI.Header(panel, "Your screen", WIDE), panel, LEFT, y)
		local lead = UI.Text(panel, "Your screen with the console set up. Hover a layout or size to preview it; pick one and press Set up.", 12, false, C.dim)
		At(lead, panel, LEFT, y - 28)
		lead:SetWidth(WIDE)
		lead:SetWordWrap(true)
		section = At(ns.Preview.Section(panel, WIDE), panel, LEFT, y - 54)
		y = y - 54 - section:GetHeight() - 20

		At(UI.Header(panel, "Bars", WIDE), panel, LEFT, y)
		steps = {}
		local each = (WIDE - 3 * 8) / 4
		for i = 1, #ns.Layout.STEPS do
			steps[i] = At(StepTile(panel, each, i, function(step)
				local L = ns.Layout
				-- Picked by hand: the bars aren't offered again until the abilities need more than this.
				ns.char.asked = math.max(ns.char.asked or 0, L.StepFor(L.Abilities()))
				L.Report(L.SetUp(nil, nil, { step = step, words = "Your bars are set. Reload to apply them." }))
				Stand()
			end), panel, LEFT + (i - 1) * (each + 8), y - 32)
		end
		know = UI.Text(panel, "", 12, false, C.dim)
		At(know, panel, LEFT, y - 32 - STEP_H - 10)
		know:SetWidth(WIDE)
		know:SetWordWrap(true)
		local under = y - 32 - STEP_H - 10 - 34

		local arrange = Action(panel, under - 12, "Layout mode",
			"Drag the cooldown manager, the bars and any on-screen piece into place. Also on /shy.",
			"Everything on screen can be dragged and resized with snapping, the game's own bars and windows too. The cooldown manager moves as one piece; scroll over it to resize it, and right-click it to take it apart.",
			function() Shy.HUD.SetUnlocked(true) end)
		Shy.HUD.EditModeKey(arrange)   -- opens Edit Mode, dressed as the layout editor
		goBack = Action(panel, under - 48, "Go back to my layout",
			"Switches to the Edit Mode layout you used before. Needs a reload.",
			"The console's layout stays in Edit Mode's list as \"Shy\", so setting up again is quick. Delete it there like any other layout.",
			function() ns.Layout.Report(ns.Layout.GoBack()) end)

		local note = UI.Text(panel, "Everything in the console can still be moved in layout mode or Edit Mode, and the housing follows the bars. A cooldown manager piece you take out or move there stays put until you put it back or set up again. A damage meter you dragged by its title stays where you put it; right-click its title to hand it back to the console.", 12, false, C.dim)
		At(note, panel, LEFT, under - 88)
		note:SetWidth(WIDE)
		note:SetWordWrap(true)

		panel:RegisterEvent("PLAYER_REGEN_DISABLED")
		panel:RegisterEvent("PLAYER_REGEN_ENABLED")
		panel:SetScript("OnEvent", Dim)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		Stand()
	end)
	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
		ns.Layout.CooldownsInCombat()
	end
	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then
			group:Refresh()
			Stand()
		end
		ns.Preview.Refresh()
	end
	return panel
end
