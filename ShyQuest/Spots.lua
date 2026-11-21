-- Tricky spots with a picture: a jump, a leap into the sea, a ledge to walk off (Data/Spots.lua, each
-- with a picture in Media/Spots drawn from the game's own map art). Within a spot's reach the card
-- says so under the leading stop, and that row's hover carries the picture: the way over the art,
-- and a ring at the jump. Nothing is said about a spot the player isn't near, because the map
-- pictures need no pointer.
--
--   ns.Spots.Near() -> spot or nil          the spot the player stands within reach of: { key, name, caption,
--                                            kind, world, north, west, radius, file, yards }
--   ns.Spots.Block(stop) -> block or nil     Shy.Hover's picture block for a stop's hover, where a spot is near

local ADDON, ns = ...
local W = ns.World
local C = Shy.UI.colors

local Spots = {}
ns.Spots = Spots

local MEDIA = "Interface\\AddOns\\ShyQuest\\Media\\Spots\\"
local list

local function Fields(text)
	local out = {}
	for piece in (text .. "^"):gmatch("([^%^]*)%^") do out[#out + 1] = piece end
	return out
end

local function List()
	if list then return list end
	list = {}
	for key, text in pairs(ns.data.spots or {}) do
		local f = Fields(text)
		list[#list + 1] = { key = key, name = f[1], caption = f[2], kind = f[3], world = tonumber(f[4]), north = tonumber(f[5]),
			west = tonumber(f[6]), radius = tonumber(f[7]) or 300, file = MEDIA .. key }
	end
	table.sort(list, function(a, b) return a.key < b.key end)
	return list
end

function Spots.Near()
	if not (W.Known() and W.continent and W.north) then return nil end
	local best
	for _, spot in ipairs(List()) do
		if spot.world == W.continent and spot.north then
			local yards = W.Between(W.north, W.west, spot.north, spot.west)
			if yards <= spot.radius and (not best or yards < best.yards) then
				best = spot
				spot.yards = yards
			end
		end
	end
	return best
end

-- The card's note under the stop that leads: the spot's name, for its row's hover.
ns.cardNotes = ns.cardNotes or {}
table.insert(ns.cardNotes, function(stop)
	if stop.kind == "errand" or stop.kind == "fly" then return nil end
	local lead = ns.Route.stops[1]
	if lead ~= stop then return nil end
	local spot = Spots.Near()
	if not spot then return nil end
	return { text = spot.name, color = C.text, sign = "note", sub = "Hover the row for the picture" }
end)

function Spots.Block(stop)
	local lead = ns.Route.stops[1]
	if not stop or lead ~= stop then return nil end
	local spot = Spots.Near()
	if not spot then return nil end
	return { picture = { file = spot.file, caption = spot.caption } }
end
