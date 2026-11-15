-- The options page.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Get(section, key) return function() return T.db[section][key] end end
local function Set(section, key) return function(v) T.db[section][key] = v end end

local function PoisonItems()
	local items = {}
	for _, kind in ipairs(ns.POISONS) do items[#items + 1] = { value = kind.key, text = kind.name } end
	return items
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Refresh() end)
	local lootText

	local function Build()
		UI.PageHeader(panel, T)

		if not ns.isRogue then
			local note = UI.Text(panel, "This is for rogues only. It does nothing on this character.", 14, false, UI.colors.dim)
			note:SetWidth(560)
			At(note, panel, LEFT, -120)
			return
		end

		local function Poisons() return T.db.poisons.shown end

		At(UI.Header(panel, "Poisons", COL), panel, LEFT, -112)
		At(group:Checkbox(panel, "Poison reminder", Get("poisons", "shown"), Set("poisons", "shown"),
			{ desc = "Out of combat, shows a box when a weapon has no poison or its poison is running out. Click the poison to apply it." }), panel, LEFT, -144)
		At(group:Dropdown(panel, "Main hand poison", PoisonItems(), Get("poisons", "mainHand"), Set("poisons", "mainHand"),
			{ width = COL, enabled = Poisons, desc = "Uses the highest rank in your bags that you can use." }), panel, LEFT, -172)
		At(group:Dropdown(panel, "Off hand poison", PoisonItems(), Get("poisons", "offHand"), Set("poisons", "offHand"),
			{ width = COL, enabled = Poisons, desc = "Uses the highest rank in your bags that you can use." }), panel, LEFT, -224)
		At(group:Slider(panel, "Remind when less than", 1, 10, 1, Get("poisons", "warnMinutes"), Set("poisons", "warnMinutes"),
			{ width = COL, enabled = Poisons, format = function(v) return v .. " min" end,
				desc = "Reminds you when a poison has less than this long left." }), panel, LEFT, -278)
		At(group:Slider(panel, "Or fewer charges than", 0, 40, 5, Get("poisons", "warnCharges"), Set("poisons", "warnCharges"),
			{ width = COL, enabled = Poisons, format = function(v) return v == 0 and "Off" or tostring(v) end,
				desc = "Also reminds you when a poison has fewer charges than this left." }), panel, LEFT, -322)
		At(group:Slider(panel, "Low stock warning below", 0, 20, 1, Get("poisons", "lowStock"), Set("poisons", "lowStock"),
			{ width = COL, enabled = Poisons, format = function(v) return v == 0 and "Off" or tostring(v) end,
				desc = "The reminder also warns when you carry fewer of a poison than this." }), panel, LEFT, -366)

		At(UI.Header(panel, "Combo points", COL), panel, RIGHT, -112)
		At(group:Checkbox(panel, "Big combo points", Get("combo", "shown"), Set("combo", "shown"),
			{ desc = "Large pips that fill from gold to red and glow at full combo points. On the console they are blades." }), panel, RIGHT, -144)
		At(group:Dropdown(panel, "Show", {
			{ value = "target", text = "With an enemy targeted" },
			{ value = "combat", text = "In combat" },
			{ value = "always", text = "Always" },
		}, Get("combo", "when"), Set("combo", "when"), { width = COL, enabled = function() return T.db.combo.shown end }), panel, RIGHT, -172)

		At(UI.Header(panel, "Lockboxes", COL), panel, RIGHT, -236)
		At(group:Checkbox(panel, "Offer to open lockboxes", Get("lockboxes", "shown"), Set("lockboxes", "shown"),
			{ desc = "Out of combat, shows a lockbox from your bags that your Lockpicking can open. Click it to pick the lock." }), panel, RIGHT, -268)

		At(UI.Header(panel, "Pick Pocket", COL), panel, RIGHT, -308)
		lootText = UI.Text(panel, "", 12)
		lootText:SetSpacing(4)
		At(lootText, panel, RIGHT, -338)
		At(group:Checkbox(panel, "Print loot in chat", Get("pickpocket", "report"), Set("pickpocket", "report"),
			{ desc = "Prints the coin and items from each Pick Pocket in chat." }), panel, RIGHT, -382)
		At(UI.Button(panel, "Reset totals", COL, function()
			ns.ResetLoot()
			ns.Refresh()
		end), panel, RIGHT, -412)

		At(Shy.HUD.LayoutButton(panel, COL), panel, LEFT, -418)
	end

	-- The labels carry a theme color inline, so UI.Themed rewrites them when the theme changes.
	local function LootText()
		local lines = {}
		for _, line in ipairs(ns.LootLines()) do
			lines[#lines + 1] = UI.Wrap(UI.colors.dim, line[1]) .. "   " .. line[2]
		end
		return table.concat(lines, "\n")
	end

	local function RefreshLoot()
		if lootText then UI.Themed(lootText, LootText) end
	end

	ns.RefreshOptions = function()
		if not panel.built or not panel:IsVisible() then return end
		group:Refresh()
		RefreshLoot()
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
		RefreshLoot()
	end)

	function panel:OnDefault()
		T:ResetDB()
		ns.Refresh()
	end

	return panel
end
