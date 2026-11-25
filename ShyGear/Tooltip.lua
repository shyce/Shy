-- Verdict lines in item tooltips (a section, Shy.Tips: the game's and a clicked link's, not the comparison tooltips):
-- one line to read at a glance ("Upgrade for Arms: +4% damage, +2% survival", with the bags' arrow; what it
-- takes away in red), and under it, dim, only what changes how to take it. What each stat is worth is ShyTip's comparison's:
-- where its card shows that, for an item in the place of one you wear, the line is the verdict alone ("Upgrade for Arms").

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local function Add(tip, text, color)
	tip:AddLine(text, color[1], color[2], color[3], true)
end

-- The mark's glyph as a picture at the start of a line, in its color.
local function Glyph(file, color)
	local r, g, b = math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255)
	return ("|T%s%s:14:14:0:0:32:32:0:32:0:32:%d:%d:%d|t "):format(ns.MEDIA, file, r, g, b)
end

local verdicts = 0   -- goes up whenever ShyGear says its verdicts may have changed: what was said is let go

local function OnItem(about, tip)
	local link = about.link
	if type(link) ~= "string" or issecretvalue(link) or C_Item.IsEquippedItem(link) then return end
	local v = ns.Judge(link)
	if not v or v.kind == "cant" then return end

	local C = UI.colors
	-- What an upgrade costs you stands out in red; a worse item's line stays quiet throughout.
	local better = v.kind == "upgrade" or v.kind == "later"
	-- (ShyTip's comparison says the numbers under this line: once is enough.)
	local compared = v.over ~= nil and Shy.Tip ~= nil and Shy.Tip.Compares ~= nil and Shy.Tip.Compares()
	local words = not compared and ns.Words(v, better and C.bad or nil) or nil
	local build = ns.ForName()
	local upgrade = build and ("Upgrade for " .. build) or "Upgrade"
	local said = words and (": " .. words) or ""
	if v.kind == "upgrade" then
		Add(tip, Glyph("Up", C.good) .. upgrade .. said, C.good)
	elseif v.kind == "later" then
		Add(tip, Glyph("Soon", C.alert) .. ("%s at level %d"):format(upgrade, v.later) .. said, C.alert)
	elseif T.db.worse then
		local who = build and (" for " .. build) or ""
		if v.kind == "worse" then
			Add(tip, "Worse" .. who .. said, C.dim)
		else
			Add(tip, "About the same" .. who, C.dim)
		end
		return
	else
		return
	end

	local notes = {}
	if not v.over then notes[#notes + 1] = "Fills an empty slot." end
	local light, own = ns.Stopgap(v)
	if light and own then notes[#notes + 1] = ("%s is a stopgap until you find %s."):format(light, own) end
	if v.extra then notes[#notes + 1] = "Its effects aren't counted." end
	if #notes > 0 then Add(tip, table.concat(notes, " "), C.dim) end
end

function ns.SetupTooltip()
	Shy.Tips.Add({ id = "is it better", order = 10, on = function() return T.db.tooltip == true end,
		-- (Worse gear's line is a setting of its own: it is in the stamp too.)
		stamp = function() return verdicts * 2 + (T.db.worse and 1 or 0) end, build = OnItem })
	Shy:On("SHY_GEAR", function() verdicts = verdicts + 1 end)
end
