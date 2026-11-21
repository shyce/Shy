-- Settings: the switch, the tick sizes learned and the report.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Learned()
	local sizes = 0
	for _ in pairs(T.db.shares) do sizes = sizes + 1 end
	if sizes == 0 then return "None yet" end
	return sizes == 1 and "1 spell" or sizes .. " spells"
end

T:Settings({
	-- What was learned is no setting: Defaults keeps it.
	reset = function()
		local shares, family, spans = T.db.shares, T.db.family, T.db.spans
		T:ResetDB()
		T.db.shares, T.db.family, T.db.spans = shares, family, spans
		T:Apply()
	end,
	{ key = "on", label = "Track your HoTs", words = "healing over time renew rejuvenation overheal wasted",
		desc = "Marks the healing your HoTs still have to give past the end of a friend's health. What would be wasted folds back over the bar." },
	{ note = "Each spell is marked in its color, gold for holy and green for nature. Your unit frames have their own switch for it." },
	{ label = "Tick sizes", button = "Forget", confirm = true, words = "learned reset", says = Learned,
		run = function() T:Forget() end,
		desc = "Your spells' tick sizes are learned outside a fight, on someone still hurt. Forget them after a talent change." },
	{ label = "Report", button = "Copy", words = "debug tracked",
		run = function() Shy.UI.ShowCopyBox("ShyHots", T:Report()) end,
		desc = "What's being tracked right now, to copy." },
})
