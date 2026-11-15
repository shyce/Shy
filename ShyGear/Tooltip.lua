-- Verdict lines in item tooltips (GameTooltip and ItemRefTooltip only, not the comparison tooltips):
-- one line to read at a glance ("Upgrade for Arms: +4% damage, +2% survival", with the bags' arrow; what it
-- takes away in red), and under it, dim, only what changes how to take it. What each stat is worth is ShyTip's comparison's.

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

-- Tooltip data carries a GUID for a bag item, a hyperlink otherwise.
local function Link(data)
	if not data then return end
	local guid, link = data.guid, data.hyperlink
	if issecretvalue(guid) or issecretvalue(link) then return end
	if guid then return C_Item.GetItemLinkByGUID(guid) end
	return link
end

local function OnItem(tip, data)
	if not T.db.tooltip or (tip ~= GameTooltip and tip ~= ItemRefTooltip) then return end
	local link = Link(data)
	if type(link) ~= "string" or issecretvalue(link) or C_Item.IsEquippedItem(link) then return end
	local v = ns.Judge(link)
	if not v or v.kind == "cant" then return end

	local C = UI.colors
	-- What an upgrade costs you stands out in red; a worse item's line stays quiet throughout.
	local better = v.kind == "upgrade" or v.kind == "later"
	local words = ns.Words(v, better and C.bad or nil)
	local build = ns.ForName()
	local upgrade = build and ("Upgrade for " .. build) or "Upgrade"
	if v.kind == "upgrade" then
		Add(tip, Glyph("Up", C.good) .. upgrade .. ": " .. words, C.good)
	elseif v.kind == "later" then
		Add(tip, Glyph("Soon", C.alert) .. ("%s at level %d: %s"):format(upgrade, v.later, words), C.alert)
	elseif T.db.worse then
		local who = build and (" for " .. build) or ""
		if v.kind == "worse" then
			Add(tip, "Worse" .. who .. ": " .. words, C.dim)
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
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItem)
end
