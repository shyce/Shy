-- An icon of ShyWarrior's own (the shout reminder's): icon, Shy.Slot, a cooldown sweep, a light behind it and a
-- line of words under it.
--   icon:SetSpell(id)   icon:Glow(r, g, b, a)   icon.note (the words under)

local ADDON, ns = ...
local UI, Slot, B = Shy.UI, Shy.Slot, Shy.Brand

local K = {}
ns.Kit = K

local INK = { 0.925, 0.910, 0.870 }

function K.Icon(parent, size)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(size, size)
	f.glow = f:CreateTexture(nil, "BACKGROUND")
	f.glow:SetTexture(B.GLOW)
	f.glow:SetBlendMode("ADD")
	f.glow:SetPoint("CENTER")
	f.glow:SetSize(size * 1.9, size * 1.9)
	f.glow:SetAlpha(0)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.slot = Slot.New(f, { icon = f.icon, hover = false })
	f.note = UI.Words(f, UI.NameFont(math.max(10, math.floor(size * 0.3 + 0.5)), "OUTLINE"), INK, { world = true, justify = "CENTER" })
	f.note:SetPoint("TOP", f, "BOTTOM", 0, -3)
	function f:SetSpell(id)
		if self.spell == id then return end
		self.spell = id
		self.icon:SetTexture(id and C_Spell.GetSpellTexture(id) or nil)
	end
	function f:Glow(r, g, b, a)
		self.glow:SetVertexColor(r, g, b)
		self.glow:SetAlpha(a or 0.8)
	end
	return f
end
