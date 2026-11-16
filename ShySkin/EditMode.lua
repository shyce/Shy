-- Edit Mode as Shy's layout editor: its window, the picked frame's settings and the layout dialogs in
-- Shy's panels and controls; every frame's highlight in layout mode's look (Shy.HUD.Overlay); the grid
-- in layout mode's lines and the snap guides in its gold. ShyCore's Editor.lua brings Shy's own pieces
-- in. Nothing is drawn on a frame that lays itself out: panels go on the dialogs' borders, the rest on
-- controls and on the highlight frames.

local ADDON, ns = ...
local UI, HUD, B = Shy.UI, Shy.HUD, Shy.Brand
local C = Shy.Skin.colors

local HEAD = ns.WINDOW.title          -- the title strip, as every Shy-dressed window's
local CLOSE = { 4, 6, 4, 2 }          -- where the close plate stands in its button, centred on that strip
local LABELS = { "Label", "HorizontalLabel", "VerticalLabel" }   -- a highlight's own name, in Blizzard's font
local NINE = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }
local DIALOGS = { "EditModeLayoutDialog", "EditModeImportLayoutDialog", "EditModeImportLayoutLinkDialog", "EditModeUnsavedChangesDialog" }
local BUTTONS = { "AcceptButton", "CancelButton", "SaveAndProceedButton", "ProceedButton" }
local TITLES = { "FramesTitle", "CombatTitle", "MiscTitle" }
local GOLD = { 1, 0.81, 0.38, 0.9 }   -- the snap guide's gold, as layout mode's (UI.colors.alert)

local overlays = setmetatable({}, { __mode = "k" })   -- highlight frame -> its Shy.HUD overlay (the frame's name on it)
local END_CAP = Enum.EditModeSystem.MainActionBarEndCap
local hovered = setmetatable({}, { __mode = "k" })    -- highlight frame -> the mouse is on it
local module

-- A frame's highlight

-- Blizzard lays its nine slice again whenever the highlight changes state.
local function Look(selection)
	local o = overlays[selection]
	if not o then return end
	local on = module.on
	if on then
		for _, key in ipairs(NINE) do module.kit:Hide(selection[key]) end
		for _, key in ipairs(LABELS) do
			if type(selection[key]) == "table" then module.kit:Hide(selection[key]) end
		end
		if type(selection.MouseOverHighlight) == "table" then module.kit:HideRegions(selection.MouseOverHighlight) end
	end
	local frame = selection:GetParent()
	-- The highlight ignores its frame's alpha: a frame faded out of sight (ShyDock's swing bars) has none.
	local alpha = frame:GetEffectiveAlpha()
	local faded = issecretvalue(alpha) or alpha < 0.05
	-- A piece seated in another (ShyDock's cockpit): that piece's one sheet covers it.
	local box = HUD.Adopted(frame)
	local seated = box ~= nil and box.still == true and box.given ~= nil
	-- The main bar's gryphons, hidden by the console's layout: Edit Mode shows them anyway, so they are faded.
	local dock = Shy.addons.Dock
	local gone = frame.system == END_CAP and frame.isVisible == false and dock ~= nil and dock.ConsoleActive ~= nil and dock:ConsoleActive()
	if on and gone then module.kit:Fade(frame, 0) end
	o:SetShown(on and not faded and not seated and not gone)
	if on then
		-- The sheet fits the piece's own panel where that is larger than the frame (ShyChat's window,
		-- ShySkin's minimap).
		o:Fit(HUD.HousingOf(frame) or selection)
		o:Look(selection.isSelected and "picked" or (hovered[selection] and "hover" or "idle"))
	end
end

local function Name(frame)
	local ok, name = pcall(frame.GetSystemName, frame)
	if ok and type(name) == "string" then return name end
	return ""
end

local function Dress(frame)
	local selection = frame.Selection
	if not selection or overlays[selection] then return end
	overlays[selection] = HUD.Overlay(selection, { label = Name(frame), size = 12 })
	for _, method in ipairs({ "ShowHighlighted", "ShowSelected" }) do
		if type(selection[method]) == "function" then hooksecurefunc(selection, method, Look) end
	end
	selection:HookScript("OnEnter", function(self)
		hovered[self] = true
		Look(self)
	end)
	selection:HookScript("OnLeave", function(self)
		hovered[self] = nil
		Look(self)
	end)
end

local function Highlights()
	for _, frame in ipairs(EditModeManagerFrame.registeredSystemFrames) do
		Dress(frame)
		if frame.Selection then Look(frame.Selection) end
	end
end

-- The grid and the snap guides are lines Blizzard colors as it lays them (the grid again each time
-- it shows, so switched off there is nothing to put back).

local function Grid()
	local grid = EditModeManagerFrame.Grid
	if not (module.on and grid.linePool) then return end
	for line in grid.linePool:EnumerateActive() do
		local _, _, x, y = line:GetStartPoint()
		if x == 0 and y == 0 then
			local r, g, b = UI.colors.hot[1], UI.colors.hot[2], UI.colors.hot[3]
			line:SetColorTexture(r, g, b, 0.35)
		else
			line:SetColorTexture(1, 1, 1, 0.06)
		end
	end
end

local function Guides()
	local pool = EditModeManagerFrame.magnetismPreviewLinePool
	if not (module.on and pool) then return end
	for line in pool:EnumerateActive() do line:SetColorTexture(unpack(GOLD)) end
end

-- Color first, so the kit records Blizzard's: a font object brings its own.
local function Label(kit, text)
	if not text then return end
	kit:Text(text, UI.colors.text)
	kit:FontObject(text, UI.TextFont(12))
	kit:Text(text, UI.colors.text)
end

-- The window

local function Window(kit)
	local frame = EditModeManagerFrame
	local set = ns.Dialog(kit, frame, { title = HEAD, close = CLOSE })
	-- The window's title is the editor's own ("Shy layout"), on the strip's middle where every Shy window has it.
	kit:Hide(frame.Title)
	ns.Own(kit, frame.Border, "title", function(owner)
		local title = UI.TitleText(owner, "", UI.HEAD.window.text)
		UI.OnHead(title, "LEFT", set, "LEFT", UI.HeadLeft(set) + 2)
		UI.Themed(title, function() return B.Name(" layout") end)
		return title
	end)
	kit:Fade(frame.Tutorial, 0)
	kit:Text(frame.LayoutLabel, UI.colors.dim)
	kit:FontObject(frame.LayoutLabel, UI.TextFont(12))
	kit:Text(frame.LayoutLabel, UI.colors.dim)
	ns.Dropdown(kit, frame.LayoutDropdown)
	for _, key in ipairs({ "ShowGridCheckButton", "EnableSnapCheckButton", "EnableAdvancedOptionsCheckButton" }) do
		if frame[key] then ns.Toggle(kit, frame[key]) end
	end
	ns.Slider(kit, frame.GridSpacingSlider.Slider)
	ns.Button(kit, frame.SaveChangesButton)
	ns.Button(kit, frame.RevertAllChangesButton)

	local settings = frame.AccountSettings
	for _, toggle in pairs(settings.settingsCheckButtons or {}) do
		if type(toggle) == "table" and toggle.Button then ns.Toggle(kit, toggle) end
	end
	local expander = settings.Expander
	if expander then
		kit:Hide(expander.Divider)
		kit:FontObject(expander.Label, UI.TitleFont(12))
		kit:Text(expander.Label, UI.colors.hot)
	end
	local container = settings.SettingsContainer
	if container then
		if container.ScrollBar then ns.ScrollBar(kit, container.ScrollBar) end
		local advanced = container.ScrollChild and container.ScrollChild.AdvancedOptionsContainer
		for _, key in ipairs(TITLES) do
			local head = advanced and advanced[key]
			if head and head.Title then
				kit:FontObject(head.Title, UI.TitleFont(13))
				kit:Text(head.Title, UI.colors.head)
			end
		end
	end
	if settings.BorderArt then
		kit:HideRegions(settings.BorderArt)
		for _, piece in ipairs(NINE) do kit:Hide(settings.BorderArt[piece]) end
		kit:Plate(settings.BorderArt, { fill = C.well, border = UI.colors.border })
	end
end

-- The picked frame's settings: its controls are pooled and laid out as it is picked.

local function Settings(kit)
	local dialog = EditModeSystemSettingsDialog
	ns.Dialog(kit, dialog, { title = HEAD, close = CLOSE })
	local pools = dialog.pools
	if pools then
		for frame in pools:EnumerateActiveByTemplate("EditModeSettingSliderTemplate") do
			Label(kit, frame.Label)
			ns.Slider(kit, frame.Slider)
		end
		for frame in pools:EnumerateActiveByTemplate("EditModeSettingDropdownTemplate") do
			Label(kit, frame.Label)
			ns.Dropdown(kit, frame.Dropdown)
		end
		for frame in pools:EnumerateActiveByTemplate("EditModeSettingCheckboxTemplate") do ns.Toggle(kit, frame) end
		for button in pools:EnumerateActiveByTemplate("EditModeSystemSettingsDialogExtraButtonTemplate") do ns.Button(kit, button) end
	end
	local buttons = dialog.Buttons
	if buttons then
		if buttons.RevertChangesButton then ns.Button(kit, buttons.RevertChangesButton) end
		kit:Hide(buttons.Divider)
	end
end

local function Dialogs(kit)
	for _, name in ipairs(DIALOGS) do
		local dialog = _G[name]
		if dialog and dialog.Border then
			ns.Dialog(kit, dialog)
			for _, key in ipairs(BUTTONS) do
				if dialog[key] then ns.Button(kit, dialog[key]) end
			end
			if dialog.LayoutNameEditBox then ns.Input(kit, dialog.LayoutNameEditBox) end
			if dialog.CharacterSpecificLayoutCheckButton then ns.Toggle(kit, dialog.CharacterSpecificLayoutCheckButton) end
		end
	end
end

local function PaintAll(m)
	Window(m.kit)
	Settings(m.kit)
	Dialogs(m.kit)
	Highlights()
	Grid()
end

module = ns.Module({
	id = "editmode",
	title = "Edit Mode",
	desc = "Restyles Edit Mode to match: its window, settings and dialogs, the highlight on each piece, and the grid and snap lines in your color.",

	Hook = function(m)
		hooksecurefunc(EditModeSystemSettingsDialog, "UpdateDialog", function()
			if m.on then Settings(m.kit) end
		end)
		hooksecurefunc(EditModeManagerFrame.Grid, "UpdateGrid", Grid)
		hooksecurefunc(EditModeManagerFrame, "RefreshSnapPreviewLines", Guides)
		-- Frames loaded since (the cooldown viewers, the damage meter) register as their addon loads.
		EventRegistry:RegisterCallback("EditMode.Enter", function()
			if m.on then PaintAll(m) end
		end, m)
		-- A piece seated in another, taken out or taken apart (ShyDock's cockpit): its highlight shows or hides at once.
		Shy:On("SHY_HUD_STILL", function(box)
			local frame = box and box.foreign
			local selection = frame and frame.Selection
			if selection and overlays[selection] then Look(selection) end
		end)
	end,

	Paint = PaintAll,

	Clear = function()
		for selection in pairs(overlays) do Look(selection) end
	end,
})
module.overlays = overlays
