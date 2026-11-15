-- The cooldown manager's choices: its size and the tracked bars' side, their names and words, for the
-- picker (Picker.lua) and the editor's panel (Pieces.lua). It has one layout (Layout.lua's L.Seated).

local ADDON, ns = ...

local V = ns.Vessel or {}
ns.Vessel = V

V.SIZES = { "small", "medium", "large" }
V.SIDES = { "left", "right" }
V.SCALES = { small = 0.85, medium = 1, large = 1.25 }
V.NAMES = {
	small = "Small", medium = "Medium", large = "Large",
	left = "Left", right = "Right",
}
V.WORDS = {
	small = "Smaller icons and bars.",
	medium = "The normal size.",
	large = "Bigger icons and bars, easier to read.",
	left = "Tracked bars hang off the left side.",
	right = "Tracked bars hang off the right side.",
}

-- The size chip a scale stands for, or nil between them.
function V.SizeOf(scale)
	for key, each in pairs(V.SCALES) do
		if math.abs(each - scale) < 0.001 then return key end
	end
	return nil
end
