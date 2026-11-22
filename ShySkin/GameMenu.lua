-- The game menu (Esc) as a Shy window: its buttons as plates, and a Shy button on a row of its own above
-- them. The Shy button's words open the settings; its caret, or a right click, opens the Shy menu (ShyCore's
-- Shy.WriteMenu, as the minimap button's), and picking from it closes the game menu.
-- The menu is a vertical layout frame that makes its buttons again on every show (InitButtons). The plate
-- goes on its border, which the layout ignores, and grows up over the Shy row; the Shy button is ours, on
-- the border too, so the layout never measures it and Blizzard's code never reads it. The plate is the
-- menu's housing, so ShyTweaks' window mover drags it by its strip and scales it by its corners and sides.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors

local W, H = 200, 28            -- a menu button: Blizzard's are 36 tall (MainMenuFrameButtonTemplate), stood at H
local BUTTON = { 2, 2, 2, 2 }   -- the plate in a button: rows of 24 with 4 between (the layout stacks them flush)
local TEXT = 14                 -- the buttons' words
local SECTION = 20              -- between sections, as MainMenuFrameMixin:AddSection
local ROOM = 14                 -- the plate's margin round the rows, and the title line's above them

-- Blizzard's buttons stood at H, with the height each had, to give back when the skin lets go. The menu lays
-- its buttons out by their heights just after it makes them (InitButtons, then the layout on show).
local tall = setmetatable({}, { __mode = "k" })
local GLYPH = 16                -- the Shy glyph before its words
local TAIL = 28                 -- the Shy button's caret part, at its right end

-- The plate's inset on the menu: round the rows, and up over the Shy row and the title strip.
local function Inset(frame)
	local left, right = frame.leftPadding or 28, frame.rightPadding or 28
	local top, bottom = frame.topPadding or 48, frame.bottomPadding or 34
	local shyTop = H - (top - SECTION)   -- the Shy button's top, above the menu's
	return {
		left + BUTTON[1] - ROOM,
		-(shyTop - BUTTON[2] + ROOM + UI.HEAD.window.line),
		right + BUTTON[3] - ROOM,
		bottom + BUTTON[4] - ROOM,
	}
end

-- The panel manager refuses addon code in a fight: the menu stays up then (Esc closes it).
local function Leave()
	if GameMenuFrame:IsShown() and not InCombatLockdown() then HideUIPanel(GameMenuFrame) end
end

local function OnTail(button)
	local x = GetCursorPosition() / button:GetEffectiveScale()
	return x >= button:GetRight() - TAIL
end

-- The caret: bright while the mouse is on its part or the menu is open, flipped while open.
local function Look(button)
	local lit = button.open or (button:IsMouseOver() and OnTail(button))
	local c = lit and UI.colors.text or C.glyph
	button.caret:SetVertexColor(c[1], c[2], c[3])
	if button.open then button.caret:SetTexCoord(0, 1, 1, 0) else button.caret:SetTexCoord(0, 1, 0, 1) end
	button.split:SetShown(button.open or button:IsMouseOver())
end

local function OpenList(button)
	UI.DropMenu(button, function(root) Shy.WriteMenu(root, Leave) end, {
		fit = true,
		onShow = function(self) self.open = true; Look(self) end,
		onHide = function(self) self.open = nil; Look(self) end,
	})
end

local function Build(owner)
	local holder = CreateFrame("Frame", nil, owner)
	holder:EnableMouse(true)   -- the plate above the menu: a click there doesn't fall through to the world
	local b = CreateFrame("Button", nil, holder)
	holder.button = b
	b:SetSize(W, H)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local text = b:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", (GLYPH + 6) / 2, 0)
	b:SetFontString(text)
	b:SetNormalFontObject(GameFontHighlight)
	b:SetText("Shy")
	b.glyph = b:CreateTexture(nil, "OVERLAY")
	b.glyph:SetTexture(Shy.MEDIA .. "ShyGlyph")
	b.glyph:SetSize(GLYPH, GLYPH)
	b.glyph:SetPoint("RIGHT", text, "LEFT", -6, 0)
	b.caret = b:CreateTexture(nil, "OVERLAY")
	b.caret:SetTexture(Skin.GLYPH.caret)
	b.caret:SetSize(10, 10)
	b.caret:SetPoint("CENTER", b, "RIGHT", -(BUTTON[3] + TAIL / 2), -1)
	b.split = b:CreateTexture(nil, "OVERLAY")
	b.split:SetWidth(1)
	b.split:SetPoint("TOP", b, "TOPRIGHT", -(BUTTON[3] + TAIL), -(BUTTON[2] + 5))
	b.split:SetPoint("BOTTOM", b, "BOTTOMRIGHT", -(BUTTON[3] + TAIL), BUTTON[4] + 5)

	b:SetScript("OnEnter", function(self)
		self:SetScript("OnUpdate", Look)
		Look(self)
		UI.Tip(self, "Shy", nil, { side = "RIGHT", hints = { { "left", "Home" }, { "right", "Menu" } } })
	end)
	b:SetScript("OnLeave", function(self)
		self:SetScript("OnUpdate", nil)
		Look(self)
		UI.TipHide(self)
	end)
	b:SetScript("OnClick", function(self, mouseButton)
		UI.TipHide(self, true)
		if mouseButton == "RightButton" or OnTail(self) then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			OpenList(self)
			return
		end
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
		Leave()
		Shy.Hub.Open("home")
	end)
	b:SetScript("OnHide", function(self)
		self:SetScript("OnUpdate", nil)
		if UI.MenuOwner() == self then UI.CloseMenu() end
	end)
	return holder
end

local function PaintShy(kit, frame, inset)
	local holder = ns.Own(kit, frame.Border, "shy", Build)
	-- Under the window mover's drag strip on the title (a child of the menu, a level up); the button above both.
	holder:SetFrameLevel(frame:GetFrameLevel())
	holder.button:SetFrameLevel(frame:GetFrameLevel() + 2)
	holder:ClearAllPoints()
	holder:SetPoint("TOPLEFT", frame, "TOPLEFT", inset[1], -inset[2])
	holder:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -inset[3], 0)
	local b = holder.button
	b:ClearAllPoints()
	b:SetPoint("BOTTOM", frame, "TOP", 0, -((frame.topPadding or 48) - SECTION))
	ns.Button(kit, b, BUTTON, TEXT)
	b.glyph:SetVertexColor(Shy.Theme.Accent())
	local edge = C.edge
	b.split:SetColorTexture(edge[1], edge[2], edge[3], 1)
	Look(b)
end

-- Blizzard's buttons, made again on every show.
local function PaintButtons(kit)
	for button in GameMenuFrame.buttonPool:EnumerateActive() do
		if not tall[button] then tall[button] = button:GetHeight() end
		button:SetHeight(H)
		ns.Button(kit, button, BUTTON, TEXT)
	end
end

ns.Module({
	id = "gamemenu",
	title = "Game menu",
	desc = "The Esc menu becomes a steel panel, with a button on top that opens these settings.",
	group = "window",
	words = "escape main",

	Ready = function() return GameMenuFrame ~= nil end,

	Hook = function(mod)
		hooksecurefunc(GameMenuFrame, "InitButtons", function()
			if mod.on then PaintButtons(mod.kit) end
		end)
	end,

	Paint = function(_, kit)
		local frame = GameMenuFrame
		local inset = Inset(frame)
		local border = frame.Border
		kit:HideRegions(border)
		for _, piece in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
			"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center", "Bg" }) do
			kit:Hide(border[piece])
		end
		local header = frame.Header
		kit:Hide(header.LeftBG)
		kit:Hide(header.RightBG)
		kit:Hide(header.CenterBG)
		local set = kit:Head(border, { to = frame, inset = inset, text = header.Text, right = UI.HEAD.window.pad })
		-- The panel is larger than the menu: the window mover drags it by the panel's strip and grips its corners.
		Shy.HUD.SetHousing(frame, kit:Outline(set))
		PaintShy(kit, frame, inset)
		PaintButtons(kit)
	end,

	Clear = function()
		Shy.HUD.SetHousing(GameMenuFrame, nil)
		for button, height in pairs(tall) do button:SetHeight(height) end
		wipe(tall)
	end,
})
