-- Settings: every part a switch, under its kind, with its own switches while it is on.
-- Told as this file loads: it is the last, so every module has registered.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- The kinds, in the order they stand: a module's `group`, its caption, and what closes it.
local GROUPS = {
	{ "screen", "On your screen", function(list)
		list[#list + 1] = { note = "To move or size a bar or frame, or hide your main bar's gryphons, use Edit Mode." }
		list[#list + 1] = Shy.Settings.Layout("Move the messages, the armor stand and the breath bars.")
	end },
	{ "window", "The game's windows" },
	{ "rebuilt", "Windows made new" },
}

-- One of a part's own switches: in the list while the part is on (and its own `shown` says so), stood in under it.
local function Option(m, o)
	return { sub = true, key = "options." .. m.id .. "." .. o.key, label = o.label, desc = o.desc, words = m.title,
		shown = function()
			return m:IsOn() == true and (m.shown == nil or m.shown() == true) and (o.shown == nil or o.shown() == true)
		end,
		set = function(v) m:SetOption(o.key, v) end }
end

-- (A switch paints its own part again and no other.)
local list = {
	apply = function() end,
	reset = function()
		T:ResetDB()
		T:Apply()
	end,
	{ note = "Switch a part off and the game's own look is back at once. In a fight a few wait until it ends." },
}
for _, group in ipairs(GROUPS) do
	local captioned = false
	for _, m in ipairs(ns.modules) do
		if (m.group or GROUPS[1][1]) == group[1] then
			if not captioned then
				captioned = true
				list[#list + 1] = { section = group[2] }
			end
			list[#list + 1] = { key = "modules." .. m.id, label = m.title, desc = m.desc, words = m.words, shown = m.shown,
				set = function(v) m:SetOn(v) end }
			for _, o in ipairs(m.options or {}) do list[#list + 1] = Option(m, o) end
		end
	end
	if captioned and group[3] then group[3](list) end
end
T:Settings(list)
