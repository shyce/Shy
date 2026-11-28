-- Settings: where your buffs and debuffs stand, and which ones show.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- The row beside the minimap is up: your buffs, your debuffs or both.
local function Beside()
	if T.db.shelf or T.db.debuffs then return true end
	return false, "Your buffs and debuffs are both in the game's own rows."
end

-- Yours stand at the end of that row, a party member's on their frame.
local function Reminded()
	if Beside() then return true end
	local frames = Shy.addons.Frames
	if frames and frames.EachFrame and not (ns.Grid and ns.Grid.On()) then return true end
	return false, "Needs your buffs or debuffs beside the minimap."
end

local position = Shy.Settings.Layout("Move your buffs and debuffs.")
position.enabled = Beside

T:Settings({
	-- (Whether the size was carried over from an old save is not a setting: Defaults keeps it.)
	reset = function()
		T:ResetDB()
		T.db.grown = true
		T:Apply()
	end,
	{ section = "Beside the minimap" },
	{ key = "look", label = "Buffs", default = "run", words = "icons pills bars watch shelf style",
		items = {
			{ value = "run", text = "Icons" },
			{ value = "pills", text = "Pills" },
			{ value = "bars", text = "Bars" },
			{ value = "watch", text = "Watch" },
			{ value = "off", text = "The default row" },
		},
		get = function()
			if not T.db.shelf then return "off" end
			return T.db.look
		end,
		set = function(v)
			T.db.shelf = v ~= "off"
			if v ~= "off" then T.db.look = v end
		end,
		desc = "How your buffs look. The one running out soonest sits next to the minimap." },
	{ key = "debuffs", label = "Debuffs", desc = "Your debuffs go under your buffs, in the same style. With this off, they stay in the game's row." },
	{ key = "size", label = "Size", min = 20, max = 44, step = 2, settle = true, enabled = Beside,
		desc = "How big the icons are." },
	{ key = "missing", label = "Missing buffs", words = "intellect fortitude spirit mark of the wild shadow protection",
		enabled = Reminded,
		desc = "Shows a gray icon for a buff someone in your group can cast and you don't have." },
	position,
	{ note = "A debuff's frame is the color of its type. Right-click a buff to remove it. Changes you make in a fight kick in after it." },

	{ section = "On your frames", needs = "Frames" },
	{ key = "frames", label = "On unit frames", words = "buffs debuffs target party",
		desc = "Puts buffs and debuffs on your frame, your target's and your party's." },
})
