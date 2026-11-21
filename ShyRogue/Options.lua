-- Settings: poisons, combo points, lockboxes and pick pocket, then the way to your keys.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Mine() return ns.isRogue end
local function Poisons() return T.db.poisons.shown end
local function Count(v) return v == 0 and "Off" or tostring(v) end

local poisons = {}
for _, kind in ipairs(ns.POISONS) do poisons[#poisons + 1] = { value = kind.key, text = kind.name } end

local layout = Shy.Settings.Layout("Move the poison reminder, your combo points and the lockbox button.")
layout.shown = Mine

T:Settings({
	apply = function() ns.Refresh() end,
	{ note = "This one is for rogues. It does nothing on this character.", shown = function() return not ns.isRogue end },
	layout,
	{ note = "The poison reminder and the lockbox button change after a fight, not during one.", shown = Mine },

	{ section = "Poisons", shown = Mine },
	{ key = "poisons.shown", label = "Poison reminder", words = "weapon coat apply",
		desc = "Out of combat, a box shows when a weapon has no poison or it's running out. Click the poison to put it on." },
	{ key = "poisons.mainHand", label = "Main hand poison", items = poisons, sub = true, enabled = Poisons,
		desc = "You get the highest rank in your bags that you can use." },
	{ key = "poisons.offHand", label = "Off hand poison", items = poisons, sub = true, enabled = Poisons },
	{ key = "poisons.warnMinutes", label = "Remind when under", min = 1, max = 10, step = 1, sub = true, enabled = Poisons,
		format = function(v) return v .. " min" end, desc = "Reminds you when a poison has less than this long left." },
	{ key = "poisons.warnCharges", label = "Or fewer charges than", min = 0, max = 40, step = 5, sub = true, enabled = Poisons,
		format = Count, desc = "Reminds you when a poison has fewer charges than this, too." },
	{ key = "poisons.lowStock", label = "Low stock under", min = 0, max = 20, step = 1, sub = true, enabled = Poisons,
		format = Count, desc = "The box warns you when you carry fewer of a poison than this." },

	{ section = "Combo points", shown = Mine },
	{ key = "combo.shown", label = "Big combo points", words = "pips blades",
		desc = "Large pips that fill from gold to red and glow when full. On the console they're blades." },
	{ key = "combo.when", label = "When to show", sub = true, enabled = function() return T.db.combo.shown end,
		items = {
			{ value = "target", text = "With an enemy targeted" },
			{ value = "combat", text = "In combat" },
			{ value = "always", text = "Always" },
		} },

	{ section = "Lockboxes", shown = Mine },
	{ key = "lockboxes.shown", label = "Open lockboxes", words = "lockpicking pick lock junkbox",
		desc = "Out of combat, a lockbox in your bags that you can pick shows as a button. Click it to pick the lock." },

	{ section = "Pick Pocket", shown = Mine },
	{ label = "Totals so far", button = "Reset", confirm = true, words = "pickpocket coin money",
		says = function()
			local all = ShyRogueCharDB
			return all and ("%s, %d items"):format(ns.Money(all.money), all.items) or ""
		end,
		run = function()
			ns.ResetLoot()
			ns.Refresh()
		end,
		desc = "Starts your pick pocket totals from nothing. /shy rogue loot says them all in chat." },

	{ section = "Keys", needs = "Keys", shown = Mine },
	{ label = "Your keys", button = "Open", words = "hotkeys bindings macros bars layout abilities",
		run = function() Shy.Hub.Open("keys") end,
		desc = "See what each key does, lay them out, or put them back." },
})
