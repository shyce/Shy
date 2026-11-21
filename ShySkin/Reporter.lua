-- The game's issue reporter (this client's bug button, "Issue Reporter") as one of the family's minimap
-- buttons: it moves with the minimap, so it stands right in every layout a setup chooses, and wears the
-- family's look. Its hover says what a click reports (the game's own words for it, which change with what
-- is in play); a click presses the game's own button through a secure action, so the game's survey comes
-- up as ever and is the game's own: pressed from our code, the survey would be ours and could not send.
--
-- The game's frame floats where the player last dragged it. While this is on it is faded and seated under
-- our button, small enough to be wholly under it, so no stray click ever lands on it.
--
--   ns.Reporter.Button()   -- our button

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local R = {}
ns.Reporter = R

local GLYPH = Shy.MEDIA .. "GlyphBug"
local ICON = "Interface\\HelpFrame\\HelpIcon-Bug"
local FIT = 0.2          -- the game's frame at this share fits under our button
local button
local parking = false

-- The game's frame under ours.
local function Park()
	if parking or not (R.on and button) then return end
	parking = true
	local frame = PTR_IssueReporter
	frame:SetScale(button:GetEffectiveScale() / UIParent:GetEffectiveScale() * FIT)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", button, "CENTER", 0, 0)
	parking = false
end

-- What a click reports now, in the game's words ("Zone Bug" and the like).
local function Context()
	local data = PTR_IssueReporter.Data
	local context = data and data.CurrentBugButtonContext
	if type(context) ~= "string" or issecretvalue(context) or context == "" then return nil end
	return context
end

local function Build()
	if button then return end
	button = Shy.MinimapButton({
		name = "ShySkinReporterButton",
		label = "Report a bug",
		detail = Context,
		icon = ICON,
		glyph = GLYPH,
		getAngle = function() return T.db.reporterAngle or 200 end,
		setAngle = function(v) T.db.reporterAngle = v end,
		secure = { type = "click", clickbutton = PTR_IssueReporter.ReportBug },
		onClick = function(self, mouseButton)
			if mouseButton == "RightButton" then return end
			UI.TipHide(self, true)
		end,
		onEnter = function(self)
			UI.Tip(self, "Report a bug", Context(), { side = self:TipSide(), hints = { { "left", "Report" } } })
		end,
		onLeave = function(self) UI.TipHide(self) end,
	})
	hooksecurefunc(PTR_IssueReporter, "SetPoint", Park)
	PTR_IssueReporter:HookScript("OnShow", Park)
end

function R.Button() return button end

ns.Module({
	id = "reporter",
	title = "Issue reporter",
	desc = "The game's bug reporter becomes a small button by your minimap.",
	group = "screen",
	words = "bug report",
	-- (The reporter comes with test builds of the game alone.)
	shown = function() return PTR_IssueReporter ~= nil end,

	Ready =function() return PTR_IssueReporter ~= nil and PTR_IssueReporter.ReportBug ~= nil end,

	Hook = function() Build() end,

	Paint = function(m, kit)
		kit:Hide(PTR_IssueReporter)
		R.on = true
		button:Place()
		button:SetShown(true)
		Park()
	end,

	Clear = function(m)
		if m.on then return end
		R.on = false
		if button then button:SetShown(false) end
		-- The game's frame back where the game puts it, at its own size.
		PTR_IssueReporter:SetScale(1)
		local place = PTR_IssueReporter:GetScript("OnShow")
		if place then place(PTR_IssueReporter) end
	end,
})
