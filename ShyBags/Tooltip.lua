-- In an item's tooltip (a section of it, Shy.Tips), where else the account has it: a heading, then a line a place with
-- its count at the right. Worked out once an item, again after a scan.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Store = ns.Store

local Tooltip = {}
ns.Tooltip = Tooltip

T.defaults.tooltip = true

local MOST = 4       -- other characters named, before the rest are counted as one line
local stamp = 0      -- goes up with every scan: what the section said is let go

-- { place, count, color } a line: your bank, mailbox and auctions, then each other character in their class's color.
local function Lines(id)
	local _, places = ns.Index.Count(id)
	local lines, named, more, rest = {}, 0, 0, 0
	for _, place in ipairs(places) do
		if place.guid == Store.Guid() then
			if place.bank > 0 then lines[#lines + 1] = { "Your bank", place.bank } end
			if place.mail > 0 then lines[#lines + 1] = { "Your mailbox", place.mail } end
			if place.auction > 0 then lines[#lines + 1] = { "Your auctions", place.auction } end
		else
			local count = place.bags + place.keys + place.bank + place.mail + place.auction
			if count > 0 and named < MOST then
				named = named + 1
				local class = place.char.class and C_ClassColor.GetClassColor(place.char.class)
				lines[#lines + 1] = { Store.Name(place.char), count, class and { class:GetRGB() } or nil }
			elseif count > 0 then
				more, rest = more + 1, rest + count
			end
		end
	end
	if #lines == 0 then return false end
	if more > 0 then lines[#lines + 1] = { more == 1 and "1 more character" or (more .. " more characters"), rest } end
	return lines
end

function Tooltip.Build(about, out)
	if type(about.id) ~= "number" then return end
	local lines = Lines(about.id)
	if not lines then return end
	local dim, text = UI.colors.dim, UI.colors.text
	out:Section("You also have")
	for _, line in ipairs(lines) do
		out:Row({ text = line[1], color = line[3] or dim, right = tostring(line[2]), rightColor = text })
	end
end

function Tooltip.Init()
	Shy.Tips.Add({ id = "where else you have it", order = 50, on = function() return T.db.tooltip == true end,
		stamp = function() return stamp end, build = Tooltip.Build })
	Shy:On("SHY_BAGS_SCANNED", function() stamp = stamp + 1 end)
end
