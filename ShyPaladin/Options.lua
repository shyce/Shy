-- The options page.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local LEFT, COL = 24, 270
local ROW, HALF = 20, 135   -- the color legend: a row per seal, two columns

-- The seals as the bar colors them, in the order they are usually learned.
local ORDER = { "righteousness", "command", "crusader", "fury", "justice", "light", "wisdom", "martyrdom" }

local function At(w, page, x, y)
	w:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
	return w
end

local function Legend(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(COL, ROW * math.ceil(#ORDER / 2))
	for i, kind in ipairs(ORDER) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local c = ns.Seal.Color(kind)
		local chip = f:CreateTexture(nil, "ARTWORK")
		chip:SetColorTexture(c[1], c[2], c[3])
		chip:SetSize(18, 6)
		chip:SetPoint("TOPLEFT", f, "TOPLEFT", col * HALF, -row * ROW - 7)
		local name = UI.Text(f, (kind:gsub("^%l", string.upper)), 13)
		name:SetPoint("LEFT", chip, "RIGHT", 8, 0)
	end
	return f
end

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() T:Apply() end)

	local function Build()
		UI.PageHeader(panel, T)

		if not ns.isPaladin then
			local note = UI.Text(panel, "This is for paladins only. It does nothing on this character.", 14, false, UI.colors.dim)
			note:SetWidth(560)
			At(note, panel, LEFT, -120)
			return
		end
		-- Everything it shows is on ShyDock's swing bar: without ShyDock there is nothing to set.
		if not Shy.addons.Dock then
			local note = UI.Text(panel, "Your seals show on ShyDock's swing bar. Turn on ShyDock to see them.", 14, false, UI.colors.dim)
			note:SetWidth(560)
			At(note, panel, LEFT, -120)
			return
		end

		local y = -112
		if ns.Seal then
			At(UI.Header(panel, "Seal color", COL), panel, LEFT, y)
			At(group:Checkbox(panel, "Color by seal", function() return T.db.color end, function(v) T.db.color = v end, {
				desc = "The swing bar fills in the color of the seal you have up, over any stone or oil on the weapon. Out of range still shows red. Needs ShyDock's swing timer." }),
				panel, LEFT, y - 32)
			local legend = At(Legend(panel), panel, LEFT, y - 60)
			group:Add({ Refresh = function() legend:SetAlpha(T.db.color and 1 or 0.4) end })
			y = y - 60 - legend:GetHeight() - 16
		end

		At(UI.Header(panel, "Seal twisting", COL), panel, LEFT, y)
		local items = { { value = "off", text = "Off" }, { value = "light", text = "Light only" } }
		for _, sound in ipairs(ns.Twist.SOUNDS) do items[#items + 1] = { value = sound.key, text = sound.text } end
		At(group:Dropdown(panel, "On the swing bar", items, function() return T.db.twist end, function(v)
			T.db.twist = v
			ns.Twist.Play(v)
		end, { width = COL,
			desc = "With Unsealed Wrath, the end of the swing bar lights up while your next swing carries an Echo, then flashes and plays a sound when it lands. Needs ShyDock's swing timer." }),
			panel, LEFT, y - 32)
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

	function panel:OnDefault()
		T:ResetDB()
		T:Apply()
	end

	return panel
end
