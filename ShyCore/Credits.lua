-- Sources: who Shy is built with, at the foot of /shy's Tools room. Each work a row: its name and who made it,
-- what it gives Shy, its licence; a click on the row lays its link over it, selected to copy. The words above
-- the rows say whose Shy is and under what licence. The credit at the rail's foot opens here
-- (Hub.OpenAt("tools", Credits.HEAD)). ShyCore\CREDITS.txt says the same at more length, for the files.

local Shy = Shy
local UI = Shy.UI
local C = UI.colors

local Credits = {}
Shy.Credits = Credits

Credits.HEAD = "Sources"
Credits.LEAD = "Shy is free software under the GNU GPL, version 3. World of Warcraft and its art belong to Blizzard."

-- name, by whom (or nil), what it gives Shy, its licence, its link (or nil).
Credits.WORKS = {
	{ name = "QuestieDB and Questie", by = "the Questie team", gives = "Quests, who gives them and where things are",
		licence = "GPL 3", link = "https://github.com/Questie/QuestieDB" },
	{ name = "CMaNGOS classic-db", by = "the CMaNGOS team", gives = "Escorts, summons, loot, bosses and where creatures stand",
		licence = "GPL 3", link = "https://github.com/cmangos/classic-db" },
	{ name = "Google Fonts", gives = "Nunito, Noto, Lilita One and the theme's lettering",
		licence = "OFL 1.1", link = "https://github.com/google/fonts" },
	{ name = "BigNoodle Titling", by = "James Arboghast, Sentinel Type", gives = "The names on your unit frames",
		licence = "Free to share" },
}

local L = { row = 34, gap = 2, name = 12, words = 11, glyph = 14, pad = 8, lead = 10 }

local function Row(page, work)
	local row = CreateFrame("Button", nil, page)
	row:SetSize(page.width, L.row)
	local name = UI.Text(row, work.name, L.name, false, C.text)
	name:SetPoint("TOPLEFT", L.pad, -4)
	if work.by then
		local by = UI.Text(row, "by " .. work.by, L.words, false, C.dim)
		by:SetPoint("LEFT", name, "RIGHT", 6, 0)
	end
	local gives = UI.Text(row, work.gives, L.words, false, C.dim)
	gives:SetPoint("TOPLEFT", L.pad, -19)
	local right = -L.pad
	local sink = { name, gives }
	if work.link then
		local glyph = row:CreateTexture(nil, "OVERLAY")
		glyph:SetSize(L.glyph, L.glyph)
		UI.GlyphArt(glyph, "link")
		glyph:SetPoint("RIGHT", right, 0)
		right = right - L.glyph - 8
		sink[#sink + 1] = glyph
		row:SetScript("OnClick", function(self)
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
			UI.CopyField(self, work.link)
		end)
	else
		row:EnableMouse(false)
	end
	local licence = UI.Text(row, work.licence, L.words, false, C.dim)
	licence:SetPoint("RIGHT", right, 0)
	UI.Press(row, { bare = true, sink = sink })
	row.name, row.gives, row.licence = name, gives, licence
	return row
end

Shy.HubSection("tools", function(page, top)
	local head = Shy.HubHead(page, top, Credits.HEAD)
	local lead = UI.Text(page, Credits.LEAD, L.words, false, C.dim)
	lead:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -L.lead)
	lead:SetWidth(page.width)
	lead:SetWordWrap(true)
	local last = lead
	Credits.rows = {}
	for i, work in ipairs(Credits.WORKS) do
		local row = Row(page, work)
		row:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or -L.gap)
		Credits.rows[i] = row
		last = row
	end
	return last
end, 90)
