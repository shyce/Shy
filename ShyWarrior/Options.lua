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

function ns.CreateOptions()
	local panel = CreateFrame("Frame")
	local group = UI.Group(function() ns.Refresh() end)

	local function Build()
		UI.PageHeader(panel, T)

		if not ns.isWarrior then
			local note = UI.Text(panel, "This is for warriors only. It does nothing on this character.", 14, false, UI.colors.dim)
			note:SetWidth(560)
			At(note, panel, LEFT, -120)
			return
		end

		local function On(section) return function() return T.db[section].shown end end

		-- Left: what lights up on your cooldowns and bars.
		At(UI.Header(panel, "Openings", COL), panel, LEFT, -112)
		At(group:Checkbox(panel, "Light up openings", Get("openings", "shown"), Set("openings", "shown"),
			{ desc = "Execute, Overpower, Revenge, Victory Rush and Raging Blow light up in your color on your cooldowns or bars while you can use them." }), panel, LEFT, -144)
		At(group:Checkbox(panel, "Interrupts", Get("openings", "interrupt"), Set("openings", "interrupt"),
			{ enabled = On("openings"), desc = "Pummel or Shield Bash lights up while your target casts something you can interrupt." }), panel, LEFT, -172)
		At(group:Checkbox(panel, "Charge in range", Get("openings", "charge"), Set("openings", "charge"),
			{ enabled = On("openings"), desc = "Charge or Intercept lights up while your target is in reach." }), panel, LEFT, -200)
		At(group:Checkbox(panel, "Sound", Get("openings", "sound"), Set("openings", "sound"),
			{ enabled = On("openings"), desc = "Plays a soft ping when something lights up." }), panel, LEFT, -228)

		At(UI.Header(panel, "Shouts", COL), panel, LEFT, -272)
		At(group:Checkbox(panel, "Light up your shout", Get("shout", "shown"), Set("shout", "shown"),
			{ desc = "Your shout lights up when it's down or running out and you have the rage. If it isn't on a bar, it shows in the middle instead." }), panel, LEFT, -304)
		At(group:Checkbox(panel, "Battle Shout", Get("shout", "battle"), Set("shout", "battle"),
			{ enabled = On("shout") }), panel, LEFT, -332)
		At(group:Checkbox(panel, "Commanding Shout", Get("shout", "commanding"), Set("shout", "commanding"),
			{ enabled = On("shout"), desc = "Only once you know it." }), panel, LEFT, -360)
		At(group:Slider(panel, "Remind when less than", 5, 60, 5, Get("shout", "warnSeconds"), Set("shout", "warnSeconds"),
			{ width = COL, enabled = On("shout"), format = function(v) return v .. " sec" end,
				desc = "Out of a fight, reminds you this long before your shout runs out. In one, just before." }), panel, LEFT, -388)

		At(Shy.HUD.LayoutButton(panel, COL), panel, LEFT, -452)

		-- Right: the light round the screen.
		At(UI.Header(panel, "Screen light", COL), panel, RIGHT, -112)
		At(group:Checkbox(panel, "Full rage", Get("rage", "shown"), Set("rage", "shown"),
			{ desc = "In a fight, the edge of the screen lights in your color as your rage nears full, in the look you picked." }), panel, RIGHT, -144)
		At(group:Slider(panel, "Light from", 0.5, 0.95, 0.05, Get("rage", "from"), Set("rage", "from"),
			{ width = COL, enabled = function() return T.db.rage.shown end,
				format = function(v) return math.floor(v * 100 + 0.5) .. "% rage" end }), panel, RIGHT, -172)
		At(group:Checkbox(panel, "Threat", Get("threat", "glow"), Set("threat", "glow"),
			{ desc = "In a group fight, the light turns gold as threat slips and red once it's lost. Not tanking, it comes as you near pulling." }), panel, RIGHT, -226)
		At(group:Dropdown(panel, "You are", {
			{ value = "auto", text = "By role or stance" },
			{ value = "tank", text = "Always the tank" },
			{ value = "dps", text = "Never the tank" },
		}, Shy.ThreatRolePick, Shy.SetThreatRole, { width = COL,
			desc = "By role or stance: your group role, else your tank or healer layout's, else Defensive Stance. Your nameplates and threat meter read you the same way." }), panel, RIGHT, -254)
		At(group:Slider(panel, "Brightness", 0.2, 1, 0.1, Get("threat", "strength"), Set("threat", "strength"),
			{ width = COL, format = function(v) return math.floor(v * 100 + 0.5) .. "%" end }), panel, RIGHT, -308)
		At(UI.Button(panel, "Try the light", COL, function() ns.Threat.Try() end), panel, RIGHT, -354)

		At(group:Checkbox(panel, "Aggro alarm", Get("threat", "alarm"), Set("threat", "alarm"),
			{ desc = "When you're tanking and a mob turns to someone else, the light flashes and Taunt lights up red." }), panel, RIGHT, -396)
		At(group:Checkbox(panel, "Aggro sound", Shy.ThreatSound, Shy.SetThreatSound,
			{ desc = "A short alarm when a mob you tank goes to someone who isn't a tank, or when you pull one yourself." }), panel, RIGHT, -424)

		local note = UI.Text(panel, "Sunder Armor, Thunder Clap, Demoralizing Shout and your shout's time are bars in your cooldown manager.", 12, false, UI.colors.dim)
		note:SetWidth(COL)
		At(note, panel, RIGHT, -462)
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
		ns.Refresh()
	end

	return panel
end
