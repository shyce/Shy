-- In an item's tooltip (the game's and a clicked link's; ShyTip's card keeps every line): under a heading, the market
-- price each on your market and how old it is, and, hovered on a stack in your bags, what the stack is worth. Worked out
-- once an item and again when prices change.
--   Tooltip.Lines(item, owner)   { { words, copper | text } } or nil: what the lines say
--   Tooltip.For(tip, data, ours) writes them on a tooltip (ours: the game's or a link's)

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local Tooltip = {}
ns.Tooltip = Tooltip

local HEAD = Shy.Hover.Heading("At the auction house")
local said = {}      -- item -> its lines, or false; let go when prices change (the book's stamp)
local saidAt

-- The stack the tooltip's owner stands for, when it is a bag slot of yours (the game's bag buttons and ShyBags' answer
-- GetBagID and GetID).
local function Stack(owner)
	if type(owner) ~= "table" or not owner.GetBagID or not owner.GetID then return nil end
	local ok, bag, slot = pcall(function() return owner:GetBagID(), owner:GetID() end)
	if not ok or type(bag) ~= "number" or type(slot) ~= "number" then return nil end
	local info = C_Container.GetContainerItemInfo(bag, slot)
	local count = info and info.stackCount
	return type(count) == "number" and not issecretvalue(count) and count > 1 and count or nil
end

function Tooltip.Lines(item, owner)
	if saidAt ~= ns.Book.Stamp() then
		said, saidAt = {}, ns.Book.Stamp()
	end
	local lines = said[item]
	if lines == nil then
		local price = ns.Book.Price(item)
		lines = false
		if price and price.market then
			lines = { { "Market", price.market } }
			if price.at then lines[2] = { "Seen", UI.Ago(price.at) } end
		end
		said[item] = lines
	end
	if not lines then return nil end
	local stack = Stack(owner)
	if not stack then return lines end
	local out = { unpack(lines) }
	out[#out + 1] = { ("Stack of %d"):format(stack), lines[1][2] * stack }
	return out
end

function Tooltip.For(tip, data, ours)
	if not (ours and T.db.tooltip) then return end
	local id = data and data.id
	if issecretvalue(id) or type(id) ~= "number" then return end
	local lines = Tooltip.Lines(id, tip:GetOwner())
	if not lines then return end
	local dim, text = UI.colors.dim, UI.colors.text
	tip:AddLine(" ")
	tip:AddLine(HEAD, dim[1], dim[2], dim[3])
	for _, line in ipairs(lines) do
		local right = type(line[2]) == "number" and UI.Money(math.floor(line[2] + 0.5), true) or line[2]
		tip:AddDoubleLine(line[1], right, dim[1], dim[2], dim[3], text[1], text[2], text[3])
	end
end

-- Asked for once every addon has logged in, so these lines stand after everyone else's.
function Tooltip.Hook()
	Shy.OnTip(Enum.TooltipDataType.Item, "what it sells for", function(tip, data)
		Tooltip.For(tip, data, tip == GameTooltip or tip == ItemRefTooltip)
	end)
end

function Tooltip.Init()
	Shy:On("SHY_LOGIN", Tooltip.Hook)
end
