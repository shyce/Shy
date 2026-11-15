-- The corner mark on an icon: arrow (upgrade), outlined arrow (upgrade at a later level), coin (sells for most).
-- Each is one of the slot's pins (Shy.Slot.Pin): a texture on the host, never a frame, as bag slots are protected
-- buttons and regions are safe on them in combat.

local ADDON, ns = ...
local Slot = Shy.Slot

ns.MARK_SIZE = Slot.PIN

-- A pin on `anchor`'s top left corner (the host's own); `low` puts it on the bottom left (the coin).
-- mark:Set(kind): "upgrade", "later", "sell", or nil for none.
function ns.CreateMark(host, anchor, size, low)
	return Slot.Pin(host, anchor, low and "BOTTOMLEFT" or "TOPLEFT", size)
end

-- "upgrade", "later" (only when the level is near) or nil.
function ns.MarkFor(verdict)
	if not verdict then return end
	if verdict.kind == "upgrade" then return "upgrade" end
	if verdict.kind == "later" and verdict.soon then return "later" end
end
