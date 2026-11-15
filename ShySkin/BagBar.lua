-- The bag bar: backpack, bag slots and key ring as slots.
-- Blizzard resets a bag button's art in UpdateTextures, so each is repainted after it.

local ADDON, ns = ...
local C = Shy.Skin.colors

-- ShyBags skins the bag bar itself and loads first.
if Shy.addons.Bags then return end

local CROP = 0.08   -- trims the icon's own dark rim

-- The backpack and key ring always count as filled; a bag slot only with a bag in it.
local function Filled(button)
	local name = button:GetName()
	if not (type(name) == "string" and name:find("^Character%a*Bag%d+Slot$") and button.HasBagEquipped) then return true end
	return button:HasBagEquipped() and true or false
end

local function PaintButton(kit, button)
	kit:Hide(button:GetNormalTexture())
	kit:Hide(button:GetHighlightTexture())
	kit:Unmask(button.icon, button.SquareMask)
	kit:Crop(button.icon, CROP, 1 - CROP, CROP, 1 - CROP)
	local filled = Filled(button)
	kit:Tile(button, { icon = button.icon }):Empty(not filled)
	kit:Fade(button.icon, filled and 1 or 0)
	ns.Lit(kit, button:GetPushedTexture(), button, C.lit)
	ns.Lit(kit, button.SlotHighlightTexture, button, C.on)   -- shown while that bag is open
	ns.Number(kit, button.Count)
	ns.Number(kit, button.FreeSlots)   -- the backpack's count of free slots
end

ns.Module({
	id = "bagbar",
	title = "Bag bar",
	desc = "Restyles the bag buttons as steel-framed slots that light up on hover and while that bag is open.",

	Hook = function(m)
		for _, button in MainMenuBarBagManager:EnumerateBagButtons() do
			hooksecurefunc(button, "UpdateTextures", function(self)
				if m.on then PaintButton(m.kit, self) end
			end)
		end
		hooksecurefunc(BagsBar, "UpdateDividers", function(self)
			if m.on then ns.HideDividers(m.kit, self) end
		end)
	end,

	Paint = function(m, kit)
		kit:Hide(BagsBar.BorderArt)
		for _, button in MainMenuBarBagManager:EnumerateBagButtons() do PaintButton(kit, button) end
		kit:Button(BagBarExpandToggle, C.glyph, C.glyph, C.hover)
		ns.HideDividers(kit, BagsBar)
	end,
})
