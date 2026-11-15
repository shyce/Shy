-- The other quest addon and ShyQuest on at the same time: where it draws or does the same thing with its
-- own setting on, ShyQuest leaves that thing to it and keeps what it has no counterpart for (the route,
-- the trail, numbered places, errands, danger warnings). Only its public API and its settings are read;
-- nothing of it is called or written.
--
--   Y.To(what, ...)   true while the other addon does `what`:
--     "tooltips"                  quest lines on the game's tooltips
--     "drops"                     ... with drop chances
--     "map", kind, mini           marks of `kind` ("pickup", "turnin", "goal", "party") on the world map,
--                                 or with `mini` the minimap. The world map is ShyQuest's while ShyMaps
--                                 draws it: the other addon's marks are under its view.
--     "plates", unit              an icon on that unit's nameplate
--     "giver"                     accepting or handing in at quest givers
--     "tracker"                   a quest tracker of its own, built from the watch list
--     "announce", kind            the party line ShyQuest's T.db.party.tell[kind] would say
--   Settings changed there apply here within a couple of seconds (ns.Apply).

local ADDON, ns = ...
local T = ns.T

local Y = {}
ns.Yield = Y

local OTHER = "Questie"         -- its folder and its global
local SHUT_UP = "questieShutUp" -- its switch that silences every party line

local EVERY = 2              -- seconds between looks at the other addon's settings

-- ShyQuest's announcement kinds to the other addon's own switches.
local ANNOUNCE = { objectives = "questAnnounceObjectives", accepted = "questAnnounceAccepted",
	handedIn = "questAnnounceCompleted", abandoned = "questAnnounceAbandoned" }
-- Map kinds to the switch for that kind of icon.
local KINDS = { pickup = "enableAvailable", turnin = "enableTurnins", goal = "enableObjectives", party = "showPartyQuestObjectives" }

-- The other addon's settings once it has started, else nil.
local function Profile()
	if not C_AddOns.IsAddOnLoaded(OTHER) then return nil end
	local other = _G[OTHER]
	if type(other) ~= "table" or type(other.db) ~= "table" then return nil end
	local api = other.API
	if type(api) ~= "table" or api.isReady ~= true then return nil end
	if type(other.IsEnabled) == "function" and not other:IsEnabled() then return nil end
	local profile = other.db.profile
	return type(profile) == "table" and profile or nil
end

local function On(value)
	return value == true
end

-- Whether the other addon's nameplate icon stands on this unit's plate.
local function Plated(profile, unit)
	if not On(profile.nameplateEnabled) or IsInInstance() then return false end
	if type(unit) ~= "string" or issecretvalue(unit) then return false end
	local guid = UnitGUID(unit)
	if type(guid) ~= "string" or issecretvalue(guid) then return false end
	local ask = _G[OTHER].API.GetQuestObjectiveIconForUnit
	if type(ask) ~= "function" then return false end
	local ok, icon = pcall(ask, guid)
	return ok and icon ~= nil
end

local function Says(profile, kind)
	if On(profile[SHUT_UP]) then return false end
	-- An item that starts a quest: the other addon tells the party, or else the player alone.
	if kind == "starts" then return true end
	local channel = profile.questAnnounceChannel
	local key = ANNOUNCE[kind]
	return key ~= nil and On(profile[key]) and (channel == "party" or channel == "both")
end

function Y.To(what, a, b)
	local profile = Profile()
	if not profile then return false end
	if what == "tooltips" then
		return On(profile.enableTooltips)
	elseif what == "drops" then
		return On(profile.enableTooltips) and On(profile.enableTooltipDroprates)
	elseif what == "map" then
		if not On(profile.enabled) or not On(profile[KINDS[a] or ""]) then return false end
		if a == "party" and not On(profile.enableObjectives) then return false end
		if b then return On(profile.enableMiniMapIcons) end
		local maps = Shy.addons.Maps
		if maps and maps.IsOn and maps:IsOn() then return false end
		return On(profile.enableMapIcons)
	elseif what == "plates" then
		return Plated(profile, a)
	elseif what == "giver" then
		local accept = profile.autoAccept
		return On(profile.autocomplete) or (type(accept) == "table" and On(accept.enabled))
	elseif what == "tracker" then
		return On(profile.trackerEnabled)
	elseif what == "announce" then
		return Says(profile, a)
	end
	return false
end

-- Everything ShyQuest steps aside for, as one string: a change means it applies its settings again.
local function Signature()
	local out = {}
	for _, ask in ipairs({ { "tooltips" }, { "drops" }, { "giver" }, { "tracker" } }) do
		out[#out + 1] = Y.To(ask[1]) and "1" or "0"
	end
	for kind in pairs(KINDS) do
		out[#out + 1] = Y.To("map", kind) and "1" or "0"
		out[#out + 1] = Y.To("map", kind, true) and "1" or "0"
	end
	return table.concat(out)
end

local was
local function Look()
	local now = Signature()
	if was ~= nil and now ~= was then ns.Apply() end
	was = now
end

Shy:On("SHY_LOGIN", function()
	if not C_AddOns.IsAddOnLoaded(OTHER) then return end
	local other = _G[OTHER]
	local api = type(other) == "table" and other.API
	if type(api) == "table" and type(api.RegisterOnReady) == "function" then
		pcall(api.RegisterOnReady, function() C_Timer.After(0, Look) end)
	end
	Look()
	C_Timer.NewTicker(EVERY, Look)
	Shy:On("SHY_MAPS", Look)
end)
