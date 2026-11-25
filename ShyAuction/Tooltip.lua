-- In an item's tooltip (a section of it, Shy.Tips: the game's and a clicked link's): under a heading, the market
-- price each on your market and how old it is, and, hovered on a stack in your bags, what the stack is worth. Worked out
-- once an item and again when prices change.
--   Tooltip.Lines(item, owner)   { { words, copper | text } } or nil: what the lines say
--   Tooltip.Build(about, out)     its section on an item's tooltip (Shy.Tips)

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local Tooltip = {}
ns.Tooltip = Tooltip

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

-- Its section on an item's tooltip (Shy.Tips): the price lines under their heading, kept until prices change.
function Tooltip.Build(about, out)
	if type(about.id) ~= "number" then return end
	local lines = Tooltip.Lines(about.id, about.owner)
	if not lines then return end
	local dim, text = UI.colors.dim, UI.colors.text
	out:Section("At the auction house")
	for _, line in ipairs(lines) do
		local right = type(line[2]) == "number" and UI.Money(math.floor(line[2] + 0.5), true) or line[2]
		out:Row({ text = line[1], color = dim, right = right, rightColor = text })
	end
end

function Tooltip.Init()
	Shy.Tips.Add({ id = "what it sells for", order = 60, on = function() return T.db.tooltip == true end,
		stamp = function() return ns.Book.Stamp() end, per = function(about) return Stack(about.owner) end,
		build = Tooltip.Build })
end
