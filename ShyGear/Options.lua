-- The options page.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Get(key) return function() return T.db[key] end end
local function Set(key) return function(v) T.db[key] = v end end

local LEGEND = {
	{ "upgrade", "Upgrade" },
	{ "later", "Upgrade in a few levels" },
	{ "sell", "Reward that sells for the most" },
}

-- The talent build first (ShyQuest's, the setup's pick) when its weights are known, then the class's roles.
local function FocusItems()
	local items = {}
	local build = ns.Build()
	local known = build and ns.BUILDS[ns.Class()]
	if known and known[build.id] then items[1] = { value = "build", text = "Your build: " .. build.name } end
	for _, focus in ipairs(ns.Focuses()) do items[#items + 1] = { value = focus, text = ns.FOCUS_NAME[focus] } end
	return items
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Refresh() end)
	local rates, gearFor

	local function Build()
		UI.PageHeader(panel, T)

		At(UI.Header(panel, "What you gear for", COL), panel, LEFT, -112)
		gearFor = group:Dropdown(panel, "Gear for", FocusItems(),
			function() return ns.Focus() end,
			function(v) ShyGearCharDB.focus = v ~= "build" and v or nil end,
			{ width = COL, desc = "Decides what counts as an upgrade. Follows your talent build unless you pick a role." })
		At(gearFor, panel, LEFT, -144)
		At(group:Dropdown(panel, "Damage or survival", {
			{ value = "damage", text = "Favor damage" },
			{ value = "balanced", text = "Balanced" },
			{ value = "tough", text = "Favor survival" },
		}, Get("lean"), Set("lean"), { width = COL, desc = "How much health and armor count when an item trades damage for survival." }), panel, LEFT, -198)

		At(UI.Header(panel, "What your stats give", COL), panel, LEFT, -262)
		rates = UI.Text(panel, "", 12)
		rates:SetWidth(COL)
		rates:SetSpacing(4)
		At(rates, panel, LEFT, -294)

		At(UI.Header(panel, "Show upgrades", COL), panel, RIGHT, -112)
		At(group:Checkbox(panel, "In item tooltips", Get("tooltip"), Set("tooltip"),
			{ desc = "Upgrade tooltips show what would change and what the item replaces." }), panel, RIGHT, -144)
		At(group:Checkbox(panel, "Also for non-upgrades", Get("worse"), Set("worse"),
			{ enabled = Get("tooltip"), desc = "Adds a tooltip line to gear that is worse than or about the same as what you have equipped." }), panel, RIGHT, -172)
		At(group:Checkbox(panel, "In your bags", Get("bags"), Set("bags"),
			{ desc = "Marks upgrades in your bags with the arrow shown below." }), panel, RIGHT, -200)

		At(UI.Header(panel, "Quest rewards", COL), panel, RIGHT, -240)
		At(group:Dropdown(panel, "Reward choices", {
			{ value = "off", text = "Do nothing" },
			{ value = "mark", text = "Mark the best" },
			{ value = "select", text = "Mark and select the best" },
		}, Get("reward"), Set("reward"), { width = COL, desc = "Puts the arrow on the best upgrade and the coin on the reward that sells for the most. Select also picks the upgrade, or the coin's reward when there's no upgrade; you can still click another." }), panel, RIGHT, -272)
		-- (ShyQuest turns the quests in: without it there is no reward to pick, and no switch, and the marks move up.)
		local y = -366
		if Shy.addons.Quest then
			At(group:Checkbox(panel, "Pick obvious rewards", Get("take"), Set("take"), {
				desc = "Needs ShyQuest to turn in quests for you. Takes the reward when one upgrade clearly wins or nothing is an upgrade, and says which in chat. Potions, bags, items with effects and later-level upgrades are left to you.",
			}), panel, RIGHT, -326)
		else
			y = -340
		end

		At(UI.Header(panel, "Marks", COL), panel, RIGHT, y)
		for i, row in ipairs(LEGEND) do
			local tile = CreateFrame("Frame", nil, panel)
			tile:SetSize(26, 26)
			Shy.Slot.New(tile, { hover = false })
			At(tile, panel, RIGHT, y - 32 - (i - 1) * 32)
			ns.CreateMark(tile, nil, nil, row[1] == "sell"):Set(row[1])
			local label = UI.Text(panel, row[2], 12)
			label:SetPoint("LEFT", tile, "RIGHT", 10, 0)
		end
	end

	local function Rates()
		local lines = ns.Rates()
		if not lines then return UI.Wrap(UI.colors.dim, "Your stats are hidden right now.") end
		lines[#lines + 1] = UI.Wrap(UI.colors.dim, "For your class at your level.")
		return table.concat(lines, "\n")
	end

	-- The build named in the list can change (ShyQuest's pick) while the page is built.
	local function RefreshRates()
		if gearFor then gearFor:SetItems(FocusItems()) end
		if rates then UI.Themed(rates, Rates) end
	end

	ns.RefreshOptions = function()
		if not panel.built or not panel:IsVisible() then return end
		group:Refresh()
		RefreshRates()
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		RefreshRates()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ShyGearCharDB.focus = nil
		ns.Refresh()
	end

	return panel
end
