-- In an item's tooltip, where else the account has it: a heading, then a line a place with its count at the right
-- (GameTooltip and ItemRefTooltip only).

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Store = ns.Store

local Tooltip = {}
ns.Tooltip = Tooltip

T.defaults.tooltip = true

local MOST = 4       -- other characters named, before the rest are counted as one line
local HEAD = Shy.Hover.Heading("You also have")
local said = {}      -- itemID -> its lines or false; cleared on every scan

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

local function OnItem(tip, data)
	if not T.db.tooltip or (tip ~= GameTooltip and tip ~= ItemRefTooltip) then return end
	local id = data and data.id
	if issecretvalue(id) or type(id) ~= "number" then return end
	local lines = said[id]
	if lines == nil then
		lines = Lines(id)
		said[id] = lines
	end
	if not lines then return end
	local dim, text = UI.colors.dim, UI.colors.text
	tip:AddLine(" ")
	tip:AddLine(HEAD, dim[1], dim[2], dim[3])
	for _, line in ipairs(lines) do
		local color = line[3] or dim
		tip:AddDoubleLine(line[1], tostring(line[2]), color[1], color[2], color[3], text[1], text[2], text[3])
	end
end

-- Asked for once every addon has logged in, so these lines are the last on the tooltip: nothing of another addon's
-- stands under the heading.
function Tooltip.Init()
	Shy:On("SHY_LOGIN", function() Shy.OnTip(Enum.TooltipDataType.Item, "where else you have it", OnItem) end)
	Shy:On("SHY_BAGS_SCANNED", function() said = {} end)
end
