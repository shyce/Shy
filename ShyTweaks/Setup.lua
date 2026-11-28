-- The tweaks step of the setup window (Shy.Setup.Questions).
-- Tweaks listed here are asked about, in this order (the window shows the first
-- ten); a tweak not registered on this character is skipped. The line is shown
-- on one line that doesn't wrap: keep it short.

local ADDON, ns = ...

ns.ASKED = {
	-- tweak                suggested   line
	{ "cameraDistance",     true,       "Zoom the camera out further" },
	{ "hideErrors",         true,       "No red \"Not enough energy\" spam" },
	{ "barText",            false,      "No keybinds or macro names on buttons" },
	{ "skipGossip",         true,       "Straight to the vendor or flight map" },
	{ "lootConfirm",        false,      "No \"this will bind to you\" popups" },
	{ "autoRepair",         true,       "Repair at any vendor who can" },
	{ "partyInvites",       true,       "Join when a friend or guildmate invites" },
	{ "declineDuels",       true,       "Decline duel requests" },
	{ "acceptRes",          false,      "Take a resurrection out of combat" },
	{ "acceptSummon",       false,      "Accept summons out of combat" },
}

local function Items()
	local asked = {}
	for order, entry in ipairs(ns.ASKED) do
		asked[entry[1]] = { order = order, suggest = entry[2], say = entry[3] }
	end
	local items = {}
	for _, f in ipairs(ns.features) do
		local a = asked[f.id]
		-- (One another addon does for now isn't asked about.)
		if not f:Away() then
			items[#items + 1] = {
				key = f.id, group = f.category, title = f.title, desc = f.desc, default = f.default or false,
				ask = a ~= nil, order = a and a.order, suggest = a and a.suggest, say = a and a.say,
				get = function() return f:IsOn() and true or false end,
				set = function(on) f:SetOn(on) end,
			}
		end
	end
	return items
end

Shy.Setup.Questions({
	id = "tweaks", order = 25, title = "Tweaks", noun = "tweaks", glyph = "use", tab = "game",
	lead = "Pick the ones you like. The rest of the tweaks are already set to sensible defaults.",
	groups = ns.CATEGORIES,
	items = Items,
})
