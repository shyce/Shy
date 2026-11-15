-- On ShyDock's swing bar a poisoned weapon's bar takes its poison's color: a module of the swing bar
-- (ShyDock's T:AddSwingModule), its colors keyed by the coating kinds ShyDock reads off the weapon.

local ADDON, ns = ...

-- Hand-picked: fixed for every player, independent of the theme, and clear of the bar's own white, red
-- and gold, and of the steel a sharpening stone gives it.
ns.POISON_COLORS = {
	instant     = { 0.74, 1.00, 0.26 },   -- lime
	deadly      = { 0.22, 0.86, 0.48 },   -- emerald
	numbing     = { 0.25, 0.88, 0.82 },   -- teal
	crippling   = { 0.36, 0.66, 1.00 },   -- azure
	mindnumbing = { 0.56, 0.58, 1.00 },   -- periwinkle
	occult      = { 0.76, 0.50, 1.00 },   -- violet
	wound       = { 1.00, 0.48, 0.80 },   -- rose
	sebacious   = { 0.90, 0.74, 0.50 },   -- sand
	atrophic    = { 0.74, 0.66, 0.78 },   -- ash
	poison      = { 0.62, 0.80, 0.56 },   -- sage: any other poison
}

function ns.SetupSwing()
	local dock = Shy.addons.Dock
	if not (dock and dock.AddSwingModule) then return end
	dock:AddSwingModule({ Coat = function(kind) return ns.POISON_COLORS[kind] end })
end
