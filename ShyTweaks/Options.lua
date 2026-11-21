-- Settings: every tweak a switch under its kind, with its own settings under it while it is on. A tweak
-- another addon does for now is left out, and so are its settings.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

ns.RefreshOptions = Shy.Settings.Refresh

local ROW, WIDE = 26, 300

-- "ClassTrainerFrame" -> "Class Trainer"
local function FriendlyName(name)
	return (name:gsub("Frame$", ""):gsub("(%l)(%u)", "%1 %2"))
end

-- The windows you moved, each with a way back to where the game puts it.
local function WindowList(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(WIDE, 1)
	local rows = {}
	function f:Refresh()
		local names = ns.MovedWindows()
		for i, name in ipairs(names) do
			local row = rows[i]
			if not row then
				row = CreateFrame("Frame", nil, f)
				row:SetSize(WIDE, 24)
				row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
				row.label = UI.Text(row, "", 13)
				row.label:SetPoint("LEFT")
				row.reset = UI.Button(row, "Reset", 64, function()
					ns.ResetFrame(row.name)
					Shy.Settings.Refresh()
				end)
				row.reset:SetPoint("LEFT", 190, 0)
				rows[i] = row
			end
			row.name = name
			local saved = T.db.frames[name]
			local scale = saved.scale and ("  |cff888888" .. math.floor(saved.scale * 100 + 0.5) .. "%|r") or ""
			row.label:SetText(FriendlyName(name) .. scale)
			row:Show()
		end
		for i = #names + 1, #rows do rows[i]:Hide() end
		f:SetHeight(math.max(1, #names * ROW))
	end
	return f
end

local function AtWork(feature)
	return feature:IsOn() and not feature:Away()
end

-- One of a tweak's own settings: in the list while the tweak is at work, stood in under it.
local function Option(feature, o)
	local entry = { sub = true, label = o.label, desc = o.desc, words = feature.title, settle = o.settle,
		shown = function() return AtWork(feature) and (not o.shown or o.shown(feature)) and true or false end,
		enabled = o.enabled and function() return o.enabled(feature) end or nil }
	if o.kind == "windows" then
		entry.label = nil
		entry.build = WindowList
		entry.height = function() return math.max(1, #ns.MovedWindows() * ROW) end
		entry.words = feature.title .. " moved windows reset"
		return entry
	end
	if o.kind == "button" then
		entry.button, entry.confirm = o.button, o.confirm
		entry.run = function()
			o.run(feature)
			Shy.Settings.Refresh()
		end
		return entry
	end
	entry.key = "options." .. feature.id .. "." .. o.key
	entry.set = function(v) feature:SetOption(o.key, v) end
	if o.kind == "slider" then
		entry.min, entry.max, entry.step, entry.format = o.min, o.max, o.step, o.format
	elseif o.kind == "dropdown" then
		entry.items = o.items
	elseif o.kind == "input" then
		entry.text, entry.placeholder = true, o.placeholder
	end
	return entry
end

-- Told once every tweak has registered: the files that hold them load before this is called.
function ns.TellSettings()
	local list = {
		apply = function() end,
		reset = function() T:ResetAll() end,
	}
	for _, category in ipairs(ns.CATEGORIES) do
		list[#list + 1] = { section = category }
		for _, feature in ipairs(ns.features) do
			if feature.category == category then
				list[#list + 1] = { key = "features." .. feature.id, label = feature.title, desc = feature.desc, words = feature.keywords,
					set = function(v) feature:SetOn(v) end,
					shown = (feature.yields or feature.leftOut) and function() return not feature:Away() end or nil,
					says = feature.says and function() return feature.says(feature) end or nil }
				for _, o in ipairs(feature.options or {}) do list[#list + 1] = Option(feature, o) end
			end
		end
	end
	T:Settings(list)
end
