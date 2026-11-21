-- Settings: where tooltips stand, when they hide, their look and a unit's colors.

local ADDON, ns = ...
local T = ns.T
local floor = math.floor

ns.RefreshOptions = Shy.Settings.Refresh

local function Anchoring() return T.db.enabled end
local function Theming() return T.db.theme end
local function CustomBg() return T.db.customBg end
local function Tapped() return T.db.theme and T.db.grayTapped end
local function Special() return T.db.theme and T.db.specialBorder end
-- A unit's card wears their color on its health bar alone. The rest is for the default tooltip.
local function Plain() return not (T.db.replace and ns.Wing and ns.Unit) end
local function Pct(v) return floor(v * 100 + 0.5) .. "%" end
local function Px(v) return v .. " px" end

-- Read as the next tooltip shows: nothing on screen to change now.
local function Soon() end

local CORNER = {
	TOPLEFT = "Top left", TOP = "Top", TOPRIGHT = "Top right",
	LEFT = "Left", CENTER = "Middle", RIGHT = "Right",
	BOTTOMLEFT = "Bottom left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom right",
}
local corners = {}
for i, point in ipairs(ns.POINTS) do corners[i] = { value = point, text = CORNER[point] } end

-- The colors "Reset" puts back: a unit's, not the background you picked.
local UNIT_COLORS = { "hostile", "neutral", "friendly", "tapped", "elite", "rare", "rareelite", "worldboss" }

-- A real tooltip for you or your target, up while your mouse stays on the button.
local tried
local function Try(unit, button)
	GameTooltip_SetDefaultAnchor(GameTooltip, button)
	if UnitExists(unit) then GameTooltip:SetUnit(unit) else GameTooltip:SetText("Target someone first") end
	GameTooltip:Show()
	if not tried then
		tried = CreateFrame("Frame")
		tried:SetScript("OnUpdate", Shy.Clocked("tip: a tooltip to look at", function(self)
			local up = GameTooltip:IsShown() and GameTooltip:GetOwner() == self.button
			if up and self.button:IsMouseOver() then return end
			if up then GameTooltip:Hide() end
			self:Hide()
		end))
	end
	tried.button = button
	tried:Show()
end

-- Their place on screen, once they are on.
local place = Shy.Settings.Layout("Move the pings and markers.")
place.shown = function() return T.db.strip end

T:Settings({
	apply = function() ns.Looks() end,
	reset = function() ns.Reset() end,

	{ label = "See yours", button = "Show", words = "try preview sample test", run = function(button) Try("player", button) end,
		desc = "Puts your own tooltip up while your mouse stays on the button." },
	{ label = "See your target's", button = "Show", words = "try preview sample test", run = function(button) Try("target", button) end,
		desc = "The same for your target, to see a mob's colors." },

	{ section = "At your cursor" },
	{ key = "enabled", label = "Tooltips at your cursor", words = "anchor mouse corner", apply = Soon,
		desc = "Tooltips for units and things in the world show at your cursor, not in the screen corner." },
	{ key = "follow", label = "Follow your cursor", sub = true, enabled = Anchoring, apply = Soon,
		desc = "The tooltip moves with your cursor." },
	{ key = "point", label = "Corner on your cursor", sub = true, enabled = Anchoring, items = corners, words = "anchor", apply = Soon,
		desc = "Which corner of the tooltip sits on your cursor." },
	{ key = "x", label = "Offset right", sub = true, enabled = Anchoring, min = -ns.OFFSET, max = ns.OFFSET, step = 1, format = Px,
		words = "horizontal x", apply = Soon, desc = "Moves it right of your cursor. Below zero moves it left." },
	{ key = "y", label = "Offset up", sub = true, enabled = Anchoring, min = -ns.OFFSET, max = ns.OFFSET, step = 1, format = Px,
		words = "vertical y", apply = Soon, desc = "Moves it up from your cursor. Below zero moves it down." },

	{ section = "When they hide" },
	{ key = "instantHide", label = "Hide at once", words = "instant fade", apply = Soon,
		desc = "The tooltip goes the moment your mouse leaves someone, with no fade." },
	{ key = "hideInCombat", label = "Hide in combat", words = "fight", apply = Soon,
		desc = "No tooltips for units or the world while you fight. Your bars and bags still show theirs." },
	{ key = "hideOnTarget", label = "Hide on your target", apply = Soon,
		desc = "No tooltip for what you already have targeted. Your target's frame still shows one." },

	{ section = "Look" },
	{ key = "replace", label = "Tooltips as cards", words = "replace default hover compact",
		desc = "Tooltips show as compact cards. The default ones still show where a card can't, like units in a fight." },
	{ note = "On an item's card, hold Shift to see how it compares to yours right away.", shown = function() return T.db.replace end },
	{ key = "shyLook", label = "Dark default tooltips", words = "style graphite steel border",
		desc = "Default tooltips get a dark background and a steel border." },
	{ key = "customBg", label = "Your own background", words = "custom color",
		desc = "Default tooltips get a background color you pick." },
	{ key = "colors.background", label = "Background color", color = true, sub = true, enabled = CustomBg },
	{ key = "font", label = "Tooltip font", items = ns.FONTS, apply = function() ns.Fonts() end,
		desc = "The font on default tooltips. Cards keep their own." },
	{ key = "scale", label = "Tooltip size", min = 0.5, max = 2, step = 0.05, format = Pct, settle = true, words = "scale big small",
		apply = function() T:Apply() end, desc = "How big the tooltip at your mouse is, cards too." },

	{ section = "Unit colors" },
	{ key = "theme", label = "Color unit tooltips", words = "class reaction",
		desc = "A player's tooltip takes their class color. An NPC's shows if it's hostile, neutral or friendly." },
	{ key = "colorBy", label = "Color by", sub = true, enabled = Theming,
		items = {
			{ value = "smart", text = "Class and reaction" },
			{ value = "reaction", text = "Reaction for everyone" },
			{ value = "class", text = "Class, players only" },
		},
		desc = "Class and reaction means class for players and reaction for NPCs." },
	{ key = "colorHealth", label = "Health bar", sub = true, enabled = Theming, words = "unit color" },
	{ key = "colorBorder", label = "Border", sub = true, enabled = Theming, shown = Plain, words = "unit color" },
	{ key = "colorName", label = "Name", sub = true, enabled = Theming, shown = Plain, words = "unit color" },
	{ key = "bgTint", label = "Background tint", sub = true, enabled = Theming, shown = Plain, min = 0, max = 1, step = 0.05, format = Pct,
		desc = "How much of their color washes into the background." },
	{ key = "danger", label = "Mark dangerous mobs", words = "elite rare boss level warning skull",
		desc = "Mobs 3 levels above you, and elites you haven't outleveled, are marked in orange or red." },

	{ section = "Elites, rares and bosses", shown = Plain },
	{ key = "specialBorder", label = "Their own border", enabled = Theming, words = "special elite rare boss",
		desc = "An elite, rare or boss gets a border in its own color." },
	{ key = "colors.elite", label = "Elite", color = true, sub = true, enabled = Special },
	{ key = "colors.rare", label = "Rare", color = true, sub = true, enabled = Special },
	{ key = "colors.rareelite", label = "Rare elite", color = true, sub = true, enabled = Special },
	{ key = "colors.worldboss", label = "Boss", color = true, sub = true, enabled = Special },

	{ section = "Reaction colors" },
	-- (An enemy player's name wears it on a card whether units are colored or not.)
	{ key = "colors.hostile", label = "Enemy", color = true, enabled = function() return T.db.theme or not Plain() end,
		desc = "Hostile mobs and enemy players." },
	{ key = "colors.neutral", label = "Neutral", color = true, enabled = Theming, desc = "Mobs that leave you alone until you hit them." },
	{ key = "colors.friendly", label = "Friendly", color = true, enabled = Theming,
		desc = "Friendly NPCs. Players wear their class color unless you color by reaction." },
	{ key = "grayTapped", label = "Gray out tapped mobs", enabled = Theming, desc = "A mob someone else tagged first takes the Tapped color." },
	{ key = "colors.tapped", label = "Tapped", color = true, sub = true, enabled = Tapped },
	{ label = "All unit colors", button = "Reset", confirm = true, words = "reaction elite rare boss default",
		run = function()
			for _, key in ipairs(UNIT_COLORS) do T.db.colors[key] = Shy.CopyTable(T.defaults.colors[key]) end
			ns.Looks()
		end,
		desc = "Puts the reaction, elite, rare and boss colors back as they shipped." },

	{ section = "Menus and markers" },
	{ key = "emotes", label = "Emotes in unit menus", words = "thank wave right-click", apply = Soon,
		desc = "Right-click someone's frame to thank them, wave or pick another emote." },
	{ key = "strip", label = "Pings and markers on Shift", words = "raid target mark skull world marker",
		apply = function() if ns.Strip then ns.Strip.Apply() end end,
		desc = "Hold Shift with a target to ping or mark it. Right-click a marker to put it on the ground." },
	place,
})
