-- Additions to Blizzard's tracker: distance under each quest marker, and an "N elsewhere" count in its header.
-- Taint: nothing is written on tracker tables and its layout is never called. Labels are our own frames
-- parented to a block and re-placed after each Blizzard layout, because blocks are reused.

local ADDON, ns = ...
local T = ns.T
local W, L, R = ns.World, ns.Log, ns.Route
local UI = Shy.UI
local C = UI.colors

local GUTTER_X, GUTTER_Y = -17, -19   -- under the marker, from a block's top left corner
local labels = {}                     -- labels in use, by quest
local spare = {}                      -- labels waiting to be used
local badge

-- Distance

-- "240y", "1.2k"
local function Short(yards)
	if yards >= 9950 then return ("%dk"):format(math.floor(yards / 1000 + 0.5)) end
	if yards >= 1000 then return ("%.1fk"):format(yards / 1000) end
	return ("%dy"):format(math.floor(yards + 0.5))
end

-- Each quest's distance to its first route stop, and the quest of the leading stop.
local function Distances()
	local out, first = {}, nil
	-- Flights and errands never lead (as R.Lead in Route.lua).
	local lead = 1
	while R.stops[lead] and (R.stops[lead].kind == "fly" or R.stops[lead].kind == "errand") do lead = lead + 1 end
	for i, stop in ipairs(R.stops) do
		for _, action in ipairs(stop.actions) do
			if action.kind ~= "pickup" and out[action.id] == nil then
				out[action.id] = stop.yards or false
				if i == lead then first = action.id end
			end
		end
	end
	return out, first
end

local function Label()
	local label = table.remove(spare)
	if not label then
		label = CreateFrame("Frame", nil, UIParent)
		label:SetSize(30, 10)
		label.text = label:CreateFontString(nil, "OVERLAY")
		label.text:SetFont(Shy.FONT_ROUNDED, 9, "")
		label.text:SetShadowOffset(1, -1)
		label.text:SetShadowColor(0, 0, 0, 0.9)
		label.text:SetPoint("CENTER")
	end
	return label
end

local function Release(id)
	local label = labels[id]
	labels[id] = nil
	label:Hide()
	label:SetParent(UIParent)
	spare[#spare + 1] = label
end

-- Called after each Blizzard layout.
local function Attach()
	local wanted = {}
	if T.db.beside.distance then
		local yards, first = Distances()
		for index = 1, C_QuestLog.GetNumQuestWatches() do
			local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
			local block = id and yards[id] and QuestObjectiveTracker:GetExistingBlock(id)
			if block and block:IsVisible() then
				wanted[id] = true
				local label = labels[id]
				if not label then
					label = Label()
					labels[id] = label
				end
				label:SetParent(block)
				label:SetFrameLevel(block:GetFrameLevel())
				label:ClearAllPoints()
				label:SetPoint("TOP", block, "TOPLEFT", GUTTER_X, GUTTER_Y)
				label.text:SetText(Short(yards[id]))
				UI.Ink(label.text, id == first and C.text or C.dim)
				label:Show()
			end
		end
	end
	for id in pairs(labels) do
		if not wanted[id] then Release(id) end
	end
end

local function Measure()
	if not next(labels) then return end
	local yards = Distances()
	for id, label in pairs(labels) do
		if yards[id] then label.text:SetText(Short(yards[id])) end
	end
end

-- Elsewhere

-- Quests held back for other zones: not watched, and not untracked by hand.
local function Elsewhere()
	local out = {}
	if T.db.track ~= "zone" or not T.db.beside.elsewhere then return out end
	local watched = {}
	for index = 1, C_QuestLog.GetNumQuestWatches() do
		local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
		if id then watched[id] = true end
	end
	local says = ns.char.watch or {}
	for _, entry in ipairs(L.order) do
		if not watched[entry.id] and says[entry.id] ~= false and not entry.failed then out[#out + 1] = entry end
	end
	return out
end

local function BadgeTip(self)
	local held = Elsewhere()
	if #held == 0 then return end
	UI.Ink(self.text, C.hot)
	local yards, rows = Distances(), {}
	for _, entry in ipairs(held) do
		local where = entry.header or ""
		if yards[entry.id] then where = where .. (where ~= "" and ", " or "") .. W.Yards(yards[entry.id]) end
		local color = GetQuestDifficultyColor((entry.level or 0) > 0 and entry.level or L.Level())
		rows[#rows + 1] = { text = entry.title, right = where, color = { color.r, color.g, color.b }, rightColor = C.dim }
	end
	UI.Tip(self, #held == 1 and "1 quest in another zone" or (#held .. " quests in other zones"),
		"Tracked again when you get there. Track one in the quest log to keep it listed.",
		{ side = "LEFT", width = 300, sections = { { rows = rows } } })
end

local function Badge()
	local header = ObjectiveTrackerFrame.Header
	if not badge then
		badge = CreateFrame("Frame", nil, header)
		badge:SetHeight(14)
		badge.text = UI.Text(badge, "", 10, false, C.dim)
		badge.text:SetPoint("RIGHT")
		badge:SetPoint("RIGHT", header.MinimizeButton, "LEFT", -6, 0)
		badge:EnableMouse(true)
		badge:SetScript("OnEnter", BadgeTip)
		badge:SetScript("OnLeave", function(self)
			UI.Ink(self.text, C.dim)
			UI.TipHide(self)
		end)
	end
	local count = #Elsewhere()
	if count == 0 then
		badge:Hide()
		return
	end
	badge.text:SetText(count .. " elsewhere")
	badge:SetWidth(badge.text:GetStringWidth() + 4)
	badge:Show()
end

local function Apply()
	Attach()
	Badge()
end
ns.ApplyBeside = Apply

Shy:On("SHY_LOGIN", function()
	hooksecurefunc(QuestObjectiveTracker, "Update", Attach)
	ns.OnApply(Apply)
	ns.OnRoute(function(rebuilt, measured)
		if rebuilt then Apply() elseif measured ~= false then Measure() end
	end, true)
	local events = CreateFrame("Frame")
	events:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	events:SetScript("OnEvent", Badge)
end)
