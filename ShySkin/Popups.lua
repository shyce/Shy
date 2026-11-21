-- The game's pop-ups (StaticPopup1 to 4: the logout countdown, confirmations, invites) as Shy panels with
-- plate buttons. A pop-up lays itself out and measures every region on it, so the plate goes on its
-- background frame (BG), which it measures by its rect alone. Blizzard sets a pop-up up again each time it
-- shows (Init): it is painted again after.

local ADDON, ns = ...

local CLOSE = { 5, 6, 5, 3 }   -- 18×18 plate in the 28×28 button (ns.CLOSE in Widgets.lua)

local function Dialogs()
	return { StaticPopup1, StaticPopup2, StaticPopup3, StaticPopup4 }
end

local function PaintDialog(kit, dialog)
	kit:Hide(dialog.BG.Top)
	kit:Hide(dialog.BG.Bottom)
	local set = kit:Plate(dialog.BG, { panel = true, window = true })
	-- The first is the pop-up's answer (Accept, Resurrect, Release Spirit): the primary.
	for i, button in ipairs(dialog.ButtonContainer.Buttons) do ns.Button(kit, button, nil, nil, i == 1) end
	ns.Button(kit, dialog.ExtraButton)
	set.owner = dialog.BG
	local pack = { closeTrim = CLOSE[3] or 0, closePlate = CLOSE }
	if dialog.CloseButton then
		ns.Close(kit, dialog.CloseButton, CLOSE)
		pack.close = dialog.CloseButton
	end
	kit:HeadRail(set, pack)
	ns.Dropdown(kit, dialog.Dropdown)
end

ns.Module({
	id = "popups",
	title = "Pop-ups",
	desc = "The game's pop-ups, like the logout countdown, become steel panels with plate buttons.",
	group = "window",
	words = "confirm dialog popup",

	Ready = function() return StaticPopup1 ~= nil end,

	Hook = function(mod)
		for _, dialog in ipairs(Dialogs()) do
			hooksecurefunc(dialog, "Init", function(self)
				if mod.on then PaintDialog(mod.kit, self) end
			end)
		end
	end,

	Paint = function(_, kit)
		for _, dialog in ipairs(Dialogs()) do PaintDialog(kit, dialog) end
	end,
})
