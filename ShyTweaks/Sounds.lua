-- Mute sounds: the kinds of sound ticked are silenced, file by file (Data/Sounds.lua). The game
-- forgets mutes when it closes, so they are laid again at every login.

local _, ns = ...

if not MuteSoundFile or not UnmuteSoundFile or not ns.sounds then return end

-- key in Data/Sounds.lua, label, description, ticked when the tweak is first switched on
local KINDS = {
	{ "bells",    "City bells",      "The bell, horn or drums each capital sounds on the hour.", true },
	{ "train",    "Train emote",     "The whistle when someone types /train.", true },
	{ "fizzle",   "Spell fizzle",    "The sound of a spell being interrupted.", false },
	{ "tram",     "Deeprun Tram",    "The tram cars starting, running and stopping.", false },
	{ "zeppelin", "Zeppelins",       "The engines, gas bags and horn of a zeppelin.", false },
	{ "strider",  "Mechanostriders", "The clanking steps and whirs of mechanostriders.", false },
}

local muted = {}   -- file ID -> true: what this tweak has muted this session

local function Apply(f)
	local want = {}
	if f.running then
		for _, kind in ipairs(KINDS) do
			local files = ns.sounds[kind[1]]
			if files and f.opt[kind[1]] then
				for _, id in ipairs(files) do want[id] = true end
			end
		end
	end
	for id in pairs(muted) do
		if not want[id] then
			UnmuteSoundFile(id)
			muted[id] = nil
		end
	end
	for id in pairs(want) do
		if not muted[id] then
			MuteSoundFile(id)
			muted[id] = true
		end
	end
end

local options = {}
for _, kind in ipairs(KINDS) do
	if ns.sounds[kind[1]] then
		options[#options + 1] = { key = kind[1], kind = "checkbox", label = kind[2], desc = kind[3], default = kind[4] }
	end
end

ns.Feature({
	id = "muteSounds",
	category = "System",
	title = "Mute sounds",
	desc = "Silences the game sounds you tick below.",
	keywords = "mute sound silence quiet noise audio bell toll hourly horn drums fizzle interrupt train choo tram subway zeppelin mechanostrider gnome mount",
	default = false,
	options = options,
	Enable = Apply,
	Disable = Apply,
	OnOptionChanged = Apply,
})
