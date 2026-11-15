-- Whether the data the addons carry was made for this game. Shy.DataBuilds names the game build this
-- release's data was last checked against, and the few sets that weren't checked against it. A release
-- older than the running game, or a set left unchecked, is a notice at the top until the game updates
-- again; it speaks in Shy's own version, not the game's build. The /shy window says quietly what it matches.
--
--   Shy.DataCheck.Game()     -- the running game's build, a number
--   Shy.DataCheck.Checked()  -- the game build this release was checked against, a number
--   Shy.DataCheck.Version()  -- Shy's version, "4.0.21"
--   Shy.DataCheck.Newer()    -- whether the game is past the build this release was checked against
--   Shy.DataCheck.Late()     -- the loaded addons' sets left unchecked: { name, addon, build }
--   Shy.DataCheck.Words()    -- a line for the /shy window and its color, or nil with nothing to say
--   Shy.DataCheck.Copy()     -- the whole list in the copy box

local Shy = Shy
local UI = Shy.UI
local C = UI.colors
local core = Shy.core
core.keep.dataSeen = true   -- the game build the notice was hidden at: the account's

local D = {}
Shy.DataCheck = D

function D.Game()
	local _, build = GetBuildInfo()
	return tonumber(build) or 0
end

function D.Checked()
	return tonumber(Shy.DataBuilds and Shy.DataBuilds.build) or 0
end

function D.Version()
	local ok, version = pcall(C_AddOns.GetAddOnMetadata, "ShyCore", "Version")
	return ok and type(version) == "string" and version or "?"
end

function D.Newer()
	return D.Checked() > 0 and D.Game() > D.Checked()
end

local function Loaded(addon)
	if addon == "ShyCore" then return true end
	return C_AddOns.IsAddOnLoaded(addon) and true or false
end

function D.Late()
	local out = {}
	for _, entry in ipairs(Shy.DataBuilds and Shy.DataBuilds.late or {}) do
		local name, addon = entry[1], entry[2]
		if name and addon and Loaded(addon) then
			out[#out + 1] = { name = name, addon = addon, build = tonumber(entry[3]) or 0 }
		end
	end
	return out
end

local function Plural(n, one, many)
	return n == 1 and one or (n .. " " .. many)
end

function D.Words()
	if not Shy.DataBuilds then return nil end
	local late = #D.Late()
	if late > 0 then return Plural(late, "1 data set", "data sets") .. " not yet checked", C.alert end
	if D.Newer() then return "Shy " .. D.Version() .. " is from before this game update", C.alert end
	return "Data matches this game", C.dim
end

local function Names(late)
	local names = {}
	for _, set in ipairs(late) do names[#names + 1] = set.name end
	return table.concat(names, ", ")
end

function D.Copy()
	local lines = { "Shy " .. D.Version(), "Checked on game build " .. D.Checked(), "Game: build " .. D.Game(), "" }
	local late = D.Late()
	for _, set in ipairs(late) do
		lines[#lines + 1] = ("%s (%s): not yet checked"):format(set.name, set.addon)
	end
	if #late == 0 then
		lines[#lines + 1] = D.Newer() and "Every data set was checked on the older build." or "Every data set was checked on this build."
	end
	UI.ShowCopyBox("Data and the game", table.concat(lines, "\n"))
end

local function Notice()
	local N = Shy.Notices
	if not N then return end
	local late, game = D.Late(), D.Game()
	local newer = D.Newer()
	if (#late == 0 and not newer) or core.db.dataSeen == game then
		N.Clear("data")
		return
	end
	local says = {}
	if #late > 0 then says[#says + 1] = Names(late) .. (#late == 1 and " hasn't" or " haven't") .. " been checked yet." end
	if newer then
		says[#says + 1] = "This version was checked on an older game update. Most data doesn't change between updates."
	end
	N.Post("data", {
		order = 20, glyph = "note", color = C.alert, count = #late > 0 and #late or 1,
		title = #late > 0 and (Plural(#late, "Data not yet checked", "data sets not yet checked"))
			or ("Game updated since Shy " .. D.Version()),
		note = "Shy " .. D.Version(),
		says = table.concat(says, "\n\n") .. "\n\nClick copies the list. Right-click hides it until the game updates.",
		click = function() D.Copy() end,
		menu = function(root)
			root:CreateButton("Copy the list", function() D.Copy() end)
			root:CreateButton("Hide until the game updates", function()
				core.db.dataSeen = game
				N.Clear("data")
			end)
		end,
	})
end

Shy:On("SHY_LOGIN", Notice)
Shy.Command("data", "compare the addons' data with this game", function() D.Copy() end)
