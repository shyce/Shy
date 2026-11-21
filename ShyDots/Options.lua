-- Settings: the switch, the tick sizes learned and the report.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Learned()
	local sizes = 0
	for _ in pairs(T.db.ticks) do sizes = sizes + 1 end
	if sizes == 0 then return "None yet" end
	return sizes == 1 and "1 spell" or sizes .. " spells"
end

T:Settings({
	-- What was learned is no setting: Defaults keeps it.
	reset = function()
		local ticks, spans = T.db.ticks, T.db.spans
		T:ResetDB()
		T.db.ticks, T.db.spans = ticks, spans
		T:Apply()
	end,
	{ key = "on", label = "Track your DoTs", words = "damage over time bleed poison dead kill",
		desc = "Marks the damage your DoTs still have to deal on a mob's health bar. A check shows once it's enough to kill." },
	{ note = "Each spell is marked in its school's color. Nameplates and your unit frames each have their own switch for it." },
	{ label = "Tick sizes", button = "Forget", confirm = true, words = "learned reset", says = Learned,
		run = function() T:Forget() end,
		desc = "Your spells' tick sizes are learned as you fight. Forget them after a big gear or talent change." },
	{ label = "Report", button = "Copy", words = "debug tracked",
		run = function() Shy.UI.ShowCopyBox("ShyDots", T:Report()) end,
		desc = "What's being tracked right now, to copy." },
})
