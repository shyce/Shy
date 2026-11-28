-- Settings: your seal's color on the swing bar and seal twisting, then the way to your keys.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Mine() return ns.isPaladin end

local twists = { { value = "off", text = "Off" }, { value = "light", text = "Light only" } }
for _, sound in ipairs(ns.Twist.SOUNDS) do twists[#twists + 1] = { value = sound.key, text = sound.text } end

T:Settings({
	{ note = "This one is for paladins. It does nothing on this character.", shown = function() return not ns.isPaladin end },
	{ note = "Your seal shows on the swing bar. That needs the Dock addon switched on.",
		shown = function() return ns.isPaladin and not Shy.addons.Dock end },

	{ section = "On the swing bar", needs = "Dock", shown = Mine },
	{ key = "color", label = "Color by seal", words = "swing timer righteousness command crusader",
		desc = "Your swing bar fills in the color of the seal you have up. Out of range is still red." },
	{ key = "twist", label = "Seal twisting", items = twists, words = "unsealed wrath echo sound ding chime bell",
		-- (You hear the sound you pick.)
		apply = function(v)
			T:Apply()
			ns.Twist.Play(v)
		end,
		desc = "With Unsealed Wrath, the bar's end glows while your next swing carries an Echo. It flashes when the swing lands." },
	{ note = "Both show on your swing timer, so keep it switched on." },

	{ section = "Keys", needs = "Keys", shown = Mine },
	{ label = "Your keys", button = "Open", words = "hotkeys bindings macros bars layout abilities",
		run = function() Shy.Hub.Open("keys") end,
		desc = "See what each key does, set them up, or put them back." },
})
