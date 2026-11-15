-- The shop's parts are ShyCore's (Shy.Shop, Shop.lua there: the attic, the desk, buttons, steppers and the rest); a
-- failed draw says so here in ShySkin's voice.

local ADDON, ns = ...

local Shop = setmetatable({}, { __index = Shy.Shop })
ns.Shop = Shop

function Shop.Try(module, draw)
	return Shy.Shop.Try(module, draw, function(text) ns.T:Print(text) end)
end
