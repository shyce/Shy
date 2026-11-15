-- Options: where buffs and debuffs stand, and what is shown.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, RIGHT, COL = 24, 330, 270

local function At(w, x, y)
	w:SetPoint("TOPLEFT", w:GetParent(), "TOPLEFT", x, y)
	return w
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)

	local function HasFrames()
		return Shy.addons.Frames ~= nil
	end

	local function Build()
		UI.PageHeader(panel, T)

		At(UI.Header(panel, "Beside the minimap", COL), LEFT, -112)
		At(group:Dropdown(panel, "Buffs", {
			{ value = "run", text = "Icons" },
			{ value = "pills", text = "Pills" },
			{ value = "bars", text = "Bars" },
			{ value = "watch", text = "Watch" },
			{ value = "off", text = "The default row" },
		}, function()
			if not T.db.shelf then return "off" end
			return T.db.look
		end, function(v)
			T.db.shelf = v ~= "off"
			if v ~= "off" then T.db.look = v end
		end, { width = COL, desc = "Weapon poisons, oils and stones first, then the buff running out soonest next to the minimap, and the ones that never run out last. Icons: a thin line in your color drains under each, with the time below. Pills: each icon with its time beside it. Bars: one per line with its name. Watch: bigger icons with the time inside, their frame draining in your color. Times turn gold in the last 30 seconds and pulse in the last 10. Debuffs use the same style." }),
			LEFT, -140)
		At(group:Checkbox(panel, "Debuffs", function() return T.db.debuffs end, function(v) T.db.debuffs = v end,
			{ desc = "Shows your debuffs under your buffs in the same style, framed in their type's color, instead of the default debuff row." }),
			LEFT, -192)
		At(group:Slider(panel, "Size", 20, 44, 2, function() return T.db.size end, function(v) T.db.size = v end,
			{ width = COL, enabled = function() return T.db.shelf or T.db.debuffs end, desc = "Size of the icons beside the minimap; bars scale with it." }),
			LEFT, -222)
		At(group:Checkbox(panel, "Missing buffs", function() return T.db.missing end, function(v) T.db.missing = v end,
			{ desc = "Shows a grey icon in a gold frame for a buff you don't have that someone in your group can cast: Intellect, Fortitude, Spirit, Mark of the Wild or Shadow Protection. Yours show at the left of your buffs, a party member's on their frame." }),
			LEFT, -274)
		At(Shy.HUD.LayoutButton(panel, COL), LEFT, -310)

		-- (The frames are ShyFrames': without it, no section, and the note stands at the column's head.)
		local y = -112
		if HasFrames() then
			At(UI.Header(panel, "On your frames", COL), RIGHT, -112)
			At(group:Checkbox(panel, "Buffs and debuffs on unit frames", function() return T.db.frames end, function(v) T.db.frames = v end,
				{ desc = "Your frame shows your debuffs and any buff with a minute or less left. Your target's shows your debuffs large, everyone else's small, and its buffs above. Party frames show debuffs, with buffs in rows above. Needs ShyFrames." }),
				RIGHT, -140)
			y = -176
		end
		local note = UI.Text(panel, "Debuff frames are colored by type: poison green, curse purple, magic blue, disease amber, red for the rest. Hover one by the minimap to see who cast it. Right-click one of your buffs to remove it. Changes made in a fight apply after it ends.", 12, false, UI.colors.dim)
		note:SetWidth(COL)
		At(note, RIGHT, y)
	end

	ns.RefreshOptions = function()
		if panel.built and panel:IsVisible() then group:Refresh() end
	end

	panel:SetScript("OnShow", function(self)
		if not self.built then
			Build()
			self.built = true
		end
		group:Refresh()
	end)

	-- What was learned of the game's buffs is not a setting: a reset keeps it.
	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
	end

	return panel
end
