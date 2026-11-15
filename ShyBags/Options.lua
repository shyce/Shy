-- The options page: the window, item marks, vendor automation, the bag bar and the saved characters.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Store = ns.Store

local LEFT, RIGHT, COL, WIDE = 24, 330, 270, 600

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local function Line(c)
	local color = c.class and C_ClassColor.GetClassColor(c.class)
	local name = Store.Name(c)
	if color then name = Shy.Theme.Wrap({ color.r, color.g, color.b }, name) end
	local money = c.money and UI.Money(c.money) or "gold unknown"
	local bags = (c.bags and c.bags.at) and ("bags seen " .. ns.Ago(c.bags.at)) or "bags not scanned yet"
	return name .. "   " .. money .. "   " .. Shy.Theme.Wrap(UI.colors.dim, bags)
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local function Apply()
		ns.BagBar.Apply()
		ns.Window.Apply()
		ns.Tile.Restyle()
		ns.Marks.Refresh()
	end
	local group = UI.Group(Apply)
	local list

	local function Refresh()
		group:Refresh()
		local lines = {}
		for _, entry in ipairs(Store.List()) do lines[#lines + 1] = Line(entry.char) end
		if #lines == 0 then lines[1] = "No characters yet. Log one in to add it." end
		list:SetText(table.concat(lines, "\n"))
	end

	local function Build()
		UI.PageHeader(panel, T)

		At(UI.Header(panel, "Window", COL), panel, LEFT, -112)
		At(group:Checkbox(panel, "Use one bag window", Get("window"), Set("window"),
			{ desc = "One window for your bags, bank, mailbox, auctions and other characters. Off uses the default bags. Applies the next time your bags open." }), panel, LEFT, -144)
		At(group:Checkbox(panel, "Fit bags automatically", ns.Window.AutoShape, ns.Window.SetAutoShape,
			{ desc = "Sizes the window to fit your bags. Drag its bottom right corner to make it wider or taller instead." }), panel, LEFT, -172)
		local shape = At(UI.Text(panel, "Slot shape is set in /shy, for every icon.", 12, false, UI.colors.dim), panel, LEFT, -206)
		shape:SetWidth(COL)
		shape:SetWordWrap(true)

		At(UI.Header(panel, "Item marks", COL), panel, LEFT, -252)
		local y = -284
		for _, def in ipairs(ns.Marks.List()) do
			At(group:Checkbox(panel, def.title,
				function() return ns.Marks.IsOn(def) end,
				function(v) T.db.marks[def.id] = v and true or false end,
				{ desc = def.desc }), panel, LEFT, y)
			y = y - 28
		end

		At(UI.Header(panel, "Vendor", COL), panel, RIGHT, -112)
		At(group:Checkbox(panel, "Sell junk", Get("sellJunk"), Set("sellJunk"),
			{ desc = "Sells your junk when you open a vendor. Hold Shift while opening the vendor to skip it." }), panel, RIGHT, -144)
		At(group:Checkbox(panel, "Print the total", Get("sellReport"), Set("sellReport"),
			{ enabled = Get("sellJunk"), desc = "Prints what the junk sold for in chat." }), panel, RIGHT, -172)
		At(group:Checkbox(panel, "Repair gear", Get("repair"), Set("repair"),
			{ desc = "Repairs everything when you open a vendor who can. Hold Shift while opening the vendor to skip it." }), panel, RIGHT, -208)
		At(group:Checkbox(panel, "Use guild funds", Get("repairGuild"), Set("repairGuild"),
			{ enabled = Get("repair"), desc = "Pays for repairs from the guild bank when your rank allows it, otherwise from your own gold." }), panel, RIGHT, -236)
		At(group:Checkbox(panel, "Print the cost", Get("repairReport"), Set("repairReport"),
			{ enabled = Get("repair"), desc = "Prints the repair cost in chat." }), panel, RIGHT, -264)

		At(UI.Header(panel, "Bag bar", COL), panel, RIGHT, -304)
		At(group:Checkbox(panel, "Bag slots in the window", Get("bagRow"), Set("bagRow"),
			{ desc = "A column of the bags you carry and the key ring beside your items. The bag button on the window's rail shows and hides it too." }), panel, RIGHT, -336)
		At(group:Checkbox(panel, "Hide the default bag bar", Get("bar"), Set("bar"),
			{ desc = "Takes the default bag buttons off the screen. Your bags open with the bag key." }), panel, RIGHT, -364)
		At(group:Checkbox(panel, "Restyle the default bar", Get("bagbar"), Set("bagbar"),
			{ enabled = function() return not T.db.bar end, desc = "Restyles the default bag buttons to match your other icons and removes the bar's border." }), panel, RIGHT, -392)

		At(UI.Header(panel, "Item tooltips", COL), panel, RIGHT, -432)
		At(group:Checkbox(panel, "Show who else has it", Get("tooltip"), Set("tooltip"),
			{ desc = "Lists how many more of an item are in your bank, mailbox or auctions, or on another character." }), panel, RIGHT, -464)

		local below = math.min(y, -496) - 16
		At(UI.Header(panel, "Characters", WIDE), panel, LEFT, below)
		list = UI.Text(panel, "", 12)
		list:SetWidth(WIDE)
		list:SetSpacing(6)
		At(list, panel, LEFT, below - 32)
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		Refresh()
	end)
	function panel:OnDefault()
		T:ResetDB()
		Apply()
		Refresh()
	end
	ns.RefreshOptions = function()
		if panel.built then Refresh() end
	end
	return panel
end
