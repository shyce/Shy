-- Settings: how your frames look, which ones you have, the party's, and click casting.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

local function Percent(v) return math.floor(v * 100 + 0.5) .. "%" end
local function Partied() return T.db.units.party end
-- Whether the addon that counts what is still to come is there and switched on.
local function Counting(suffix)
	local addon = Shy.addons[suffix]
	return addon ~= nil and addon.IsOn ~= nil and addon:IsOn()
end

-- The portrait is a file of its own: a client that has not loaded it yet shows none of these.
local function Portraits() return ns.Portrait ~= nil end
local function Pictured()
	local db = T.db.portrait
	return db.pair ~= "none" or db.small ~= "none" or db.party ~= "none"
end
local Faces = {
	{ value = "none", text = "None" },
	{ value = "class", text = "Class icon" },
	{ value = "face", text = "2D face" },
	{ value = "head", text = "3D head" },
}
local Styles = {
	{ value = "ours", text = "Set in the frame" },
	{ value = "blizzard", text = "Like the game's" },
}
local Rings = {
	{ value = "steel", text = "Steel" },
	{ value = "accent", text = "Your color" },
	{ value = "class", text = "Class color" },
}
local function Ringed() return Pictured() and T.db.portrait.style == "blizzard" end

local function Bound()
	local count = 0
	for _ in pairs(ns.Clicks.Binds()) do count = count + 1 end
	return count == 0 and "None" or (count .. " bound")
end

T:Settings({
	{ key = "size", label = "Size", min = 0.6, max = 1.4, step = 0.02, settle = true, format = Percent, words = "scale big small",
		desc = "How big every frame is." },
	{ note = "At 94% your frame and your target's are as wide as the console.", needs = "Dock" },
	-- (The whole HUD fading when idle fades your frame too: this one is left out while that is on.)
	{ key = "fade", label = "Fade out of combat", words = "hide transparent",
		shown = function() return not ns.Fader.Yields() end,
		apply = function() ns.Fader.Apply() end,
		desc = "Out of a fight your frame fades away once you have no target and you're back to full. You can still click it." },
	{ key = "height", label = "Frame height", words = "tall taller stock default size portrait",
		items = { { value = "compact", text = "Compact" }, { value = "game", text = "Like the game's" } },
		desc = "How tall your frame and your target's are. The console makes room either way." },
	{ key = "healthText", label = "Health text", words = "health numbers percent current max missing deficit",
		items = {
			{ value = "smart", text = "Smart" }, { value = "percent", text = "Percent" }, { value = "current", text = "Current" },
			{ value = "both", text = "Current and max" }, { value = "missing", text = "Missing" },
			{ value = "full", text = "Everything" }, { value = "none", text = "None" },
		},
		desc = "Smart shows your own health, what a friend is missing and an enemy's percent." },
	{ key = "hurtOnly", label = "Health when hurt", words = "health text numbers full hide",
		desc = "Health numbers stay hidden until you or your target take damage." },
	-- (Whether the marks are tracked is the other addon's switch. These two say where they show.)
	{ key = "doom", label = "DoT marks", needs = "Dots", words = "dots damage over time kill dead",
		shown = function() return Counting("Dots") end,
		apply = function() if ns.Doom then ns.Doom() end end,
		desc = "Your DoT marks show on an enemy's health bar on these frames too. You turn tracking them on or off under Dots." },
	{ key = "mend", label = "HoT marks", needs = "Hots", words = "hots heal over time healing to come",
		shown = function() return Counting("Hots") end,
		apply = function() if ns.Mend then ns.Mend() end end,
		desc = "Your HoT marks show on a friend's health bar on these frames too. You turn tracking them on or off under Hots." },
	Shy.Settings.Layout("Move and size your frames."),

	{ section = "Frames" },
	{ key = "units.player", label = "Player", desc = "Your own health and power." },
	{ key = "units.target", label = "Target", words = "combo points",
		desc = "Whoever you have targeted, with your combo points along the top." },
	{ key = "units.targettarget", label = "Target's target", words = "tot", desc = "Who your target is targeting, in a smaller frame beside it." },
	{ key = "units.pet", label = "Pet", desc = "Your pet, in a small frame beside yours." },
	{ key = "mood", label = "Pet mood", sub = true, words = "happiness happy content unhappy feed diet loyalty hunter",
		shown = function() return UnitClassBase("player") == "HUNTER" end,
		enabled = function() return T.db.units.pet end,
		apply = function() if ns.Mood then ns.Mood.Update() end end,
		desc = "Your pet's mood leads its name. Its ring turns gold when it's content and red when it's unhappy." },
	{ key = "units.focus", label = "Focus", desc = "Your focus, in a small frame beside yours." },
	{ key = "hideBlizzard", label = "Hide default frames", words = "blizzard unit",
		desc = "Hides the game's own frame for each one you switch on here. Raid frames and the cast bar stay." },

	{ section = "Portrait", shown = Portraits },
	{ key = "portrait.pair", label = "You and your target", items = Faces, words = "face head 3d class icon picture player",
		shown = Portraits,
		desc = "A picture at the end of your frame, and at the far end of your target's." },
	{ key = "portrait.small", label = "Small frames", items = Faces, words = "face head 3d class icon picture pet focus tot target's target",
		shown = Portraits,
		desc = "A picture on your pet, your focus and your target's target." },
	{ key = "portrait.party", label = "Party", items = Faces, words = "face head 3d class icon picture group",
		shown = Portraits,
		desc = "A picture at the end of each party member's frame. The healing grid has none." },
	{ key = "portrait.style", label = "Style", items = Styles, words = "portrait round circle ring square game blizzard",
		shown = Portraits, enabled = Pictured,
		desc = "Pick Like the game's to put each picture in a round ring at the very end of its frame." },
	{ key = "portrait.ring", label = "Ring", items = Rings, sub = true, words = "portrait round circle color",
		shown = Portraits, enabled = Ringed,
		desc = "The ring's color, unless your look brings a ring of its own." },
	{ key = "portrait.level", label = "Level circle", sub = true, words = "portrait level number ring",
		shown = Portraits, enabled = function() return Ringed() and T.db.portrait.pair ~= "none" end,
		desc = "Your level and your target's sit in a small ring of their own on the picture." },
	{ key = "control", label = "Crowd control", words = "sheep polymorph fear stun cc loss of control",
		shown = Portraits, enabled = Pictured,
		desc = "A sheeped, feared or stunned unit shows what holds it, and for how long, over its picture." },

	{ section = "Party" },
	{ key = "units.party", label = "Party frames", words = "group range aggro",
		desc = "Your party in a row above your frames. Someone out of range fades, and aggro turns their edge red." },
	{ key = "units.partypet", label = "Party pets", sub = true, enabled = Partied,
		desc = "Each pet gets a green bar at the end of its owner's health. Click it to target the pet." },
	{ key = "grid", label = "Healing grid", enabled = Partied, words = "healer raid cells",
		items = {
			{ value = "auto", text = "While you're the healer" },
			{ value = "on", text = "Always" },
			{ value = "off", text = "Never" },
		},
		desc = "You and your party in one tight grid, tanks first. You count as the healer by your group role or your healer layout." },
	{ note = "In the grid your own heals show along the bottom of each frame, and a debuff you can remove lights the whole frame.",
		needs = "Buffs" },
	{ label = "Test party", button = "Show / hide", enabled = Partied, words = "sample preview",
		says = function() return T:Testing() and "On" or "Off" end,
		run = function() T:Test() end,
		desc = "Fills the empty party seats with samples, so you can set them up without a group. Layout mode shows them too." },
	{ note = "Party frames hide while you're in a raid." },

	{ section = "Click casting" },
	{ label = "Clicks and keys", button = "Set up", words = "bind mouse heal spell spellbook", says = Bound,
		run = function() ns.Clicks.Open() end,
		desc = function()
			if ns.Clicks.Paged() then return "Opens your spellbook at its click casting page. Pick a spell there, then give it a click or a key." end
			return "Opens the list of what your clicks and keys cast. Binding a spell needs the restyled spellbook, under Skin."
		end },
	{ key = "press", label = "Cast on press", words = "mouse down release",
		apply = function() ns.Clicks.Apply() end,
		desc ="A bound click casts as the button goes down, not when you let go. One that opens the menu still waits." },

	{ note = "Left-click a frame to target it, right-click for its menu. If you change these in a fight, they kick in after it." },
})
