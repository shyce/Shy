-- Settings: the way to your keys. They are set in the Keys room, for every class the same.

local ADDON, ns = ...
local T = ns.T

T:Settings({
	{ label = "Your keys", button = "Open", needs = "Keys", words = "hotkeys bindings macros bars layout abilities",
		shown = function() return ns.isDruid end,
		run = function() Shy.Hub.Open("keys") end,
		desc = "See what each key does, set them up, or put them back." },
	{ note = "This one is for druids. It does nothing on this character.", shown = function() return not ns.isDruid end },
})
