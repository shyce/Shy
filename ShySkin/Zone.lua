-- The zone's name as a new area is entered. The game writes it over the world in its own gold; here it
-- is the headline of the column down from the top's middle, of one make with the arrow and the messages
-- under it: the name on a plaque that runs to a point at either end, lit along its top in the land's
-- color, the area and whose land it is under it in small capitals.
--
-- The game still decides what is said and when: its two frames (the zone's, and the area's under it)
-- come and go as ever with their words faded, and this follows them: what each says, while it shows,
-- and how long it has left. An area said by itself stands on the plaque.
--
--   ns.Zone.Sample(parent)   -- the piece as a picture, the box's size (layout mode, the screen's preview)
--   ns.Zone.Now()            -- what is up: { mode, name, area, land, kind, plate, under, word } (alphas)
--   ns.Zone.Banner()         -- the frame on screen

local ADDON, ns = ...
local UI, Theme, HUD = Shy.UI, Shy.Theme, Shy.HUD
local C = UI.colors
local MEDIA = Shy.MEDIA

local Z = {}
ns.Zone = Z

local ID = "game.zone"
local WIDTH, HEIGHT = 420, 60
local NAME, ALONE = 20, 16                -- the zone's name; an area's name said by itself
local TALL, TALL_ALONE = 30, 26           -- the plaque for each
local POINT, PAD, LIGHT, REACH = 10, 14, 12, 6   -- REACH: the column's plaque shadow (PlaqueShade) past the plaque
local LEAST = 160
local AREA, LAND = 11, 10                 -- the lines under the plaque, in capitals
local GAP, STEP = 4, 2                    -- the plaque to the first line; one line to the next
local IN, OUT, QUICK = 0.25, 0.6, 0.15    -- fade in; fade out before the game's time is up; when the game drops it
local RISE = 6                            -- how far the plaque rises as it comes in

local banner, box
local drawings = setmetatable({}, { __mode = "k" })
local now = { mode = "zone", plate = 0, under = 0, word = 0, up = 1 }
local seenStart
local failed

-- The land

-- The game's word for a land, as it writes it: a side's own, contested, a sanctuary, open to all.
local function Kind()
	local kind = C_PvP.GetZonePVPInfo()
	if issecretvalue(kind) then return nil end
	return kind
end

local function Tone(kind)
	if kind == "friendly" then return C.good end
	if kind == "hostile" or kind == "arena" or kind == "combat" then return C.bad end
	if kind == "contested" then return C.alert end
	if kind == "sanctuary" then return Theme.light end
	return Theme.Accent
end

-- What the game would say of the land, for the picture.
local function Said(kind)
	local _, _, faction = C_PvP.GetZonePVPInfo()
	if kind == "sanctuary" then return SANCTUARY_TERRITORY end
	if kind == "arena" then return FREE_FOR_ALL_TERRITORY end
	if kind == "contested" then return CONTESTED_TERRITORY end
	if kind == "combat" then return COMBAT_ZONE end
	if (kind == "friendly" or kind == "hostile") and type(faction) == "string" and not issecretvalue(faction) and faction ~= "" then
		return FACTION_CONTROLLED_TERRITORY:format(faction)
	end
	return ""
end

-- Small capitals: the game's "(Contested Territory)" as CONTESTED TERRITORY.
local function Caps(text)
	if issecretvalue(text) then return text end
	text = text:match("^%s*%((.-)%)%s*$") or text
	if text:find("|", 1, true) then return text end
	return (text:gsub("[a-z]+", string.upper))
end

-- Drawing

local function Words(parent, font)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFontObject(font)
	UI.Follow(fs)   -- a title keeps up with the theme's font
	fs:SetShadowOffset(1, -1)
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetJustifyH("CENTER")
	fs:SetWordWrap(false)
	return fs
end

local function Even(w) return 2 * math.ceil(w / 2) end

-- A width the string needs, or nil where the game keeps it secret.
local function Measure(fs)
	local w = fs:GetStringWidth()
	if w == nil or issecretvalue(w) then return nil end
	return w
end

-- The housing at the opacity of the hovers: words over the world want the darker tier.
local function Look(d)
	Shy.Top.Make.Look(d)   -- the column's make, in the look's material
end

-- The pieces on a frame of the box's size: the plaque (its own frame, so it fades and rises by itself)
-- and the two lines under it.
local function Draw(f)
	local d = {}
	local plate = CreateFrame("Frame", nil, f)
	plate:SetSize(LEAST, TALL)
	plate:SetPoint("TOP", f, "TOP", 0, 0)
	d.plate = plate
	d.shade = plate:CreateTexture(nil, "BACKGROUND", nil, -8)
	d.shade:SetTexture(MEDIA .. "PlaqueShade")
	d.shade:SetTextureSliceMargins(12, 12, 12, 12)
	d.shade:SetPoint("TOPLEFT", -REACH, REACH - 2)
	d.shade:SetPoint("BOTTOMRIGHT", REACH, -REACH - 2)
	d.head = plate:CreateTexture(nil, "BORDER")
	d.head:SetTexture(MEDIA .. "HoverPlaqueEnd")
	d.head:SetTexCoord(1, 0, 0, 1)
	d.head:SetPoint("TOPLEFT")
	d.head:SetPoint("BOTTOMLEFT")
	d.head:SetWidth(POINT)
	d.tail = plate:CreateTexture(nil, "BORDER")
	d.tail:SetTexture(MEDIA .. "HoverPlaqueEnd")
	d.tail:SetPoint("TOPRIGHT")
	d.tail:SetPoint("BOTTOMRIGHT")
	d.tail:SetWidth(POINT)
	d.mid = plate:CreateTexture(nil, "BORDER")
	d.mid:SetTexture(MEDIA .. "HoverPlaqueMid")
	d.mid:SetPoint("TOPLEFT", d.head, "TOPRIGHT")
	d.mid:SetPoint("BOTTOMRIGHT", d.tail, "BOTTOMLEFT")
	Shy.Top.Make.Material(plate, d, plate)
	-- The land's color as light in the plaque's top edge, from point to point.
	d.light = plate:CreateTexture(nil, "ARTWORK")
	d.light:SetTexture(MEDIA .. "HoverLight")
	d.light:SetHeight(LIGHT)
	d.light:SetPoint("TOPLEFT", POINT, 0)
	d.light:SetPoint("TOPRIGHT", -POINT, 0)
	d.name = Words(plate, UI.TitleFont(NAME))
	d.name:SetPoint("CENTER", plate, "CENTER", 0, 0)
	UI.Ink(d.name, C.text)
	d.area = Words(f, UI.TextFont(AREA))
	d.area:SetPoint("TOP", plate, "BOTTOM", 0, -GAP)
	UI.Ink(d.area, C.head)
	d.land = Words(f, UI.TextFont(LAND))
	Look(d)
	drawings[d] = true
	return d
end

-- What the drawing says: s = { name, area, land (the game's words), kind, alone }.
local function Lay(d, s)
	local alone = s.alone
	UI.TitleFace(d.name, alone and ALONE or NAME)
	d.name:SetText(s.name)
	local name = Measure(d.name)
	local width = name and (name + 2 * (POINT + PAD)) or WIDTH
	d.plate:SetSize(Even(math.max(LEAST, math.min(WIDTH, width))), alone and TALL_ALONE or TALL)
	UI.Tint(d.light, Tone(s.kind))
	local area = s.area ~= "" and s.area or nil
	if area then d.area:SetText(Caps(area)) end
	d.area:SetShown(area ~= nil)
	local land = s.land ~= "" and s.land or nil
	if land then d.land:SetText(Caps(land)) end
	d.land:SetShown(land ~= nil)
	d.land:ClearAllPoints()
	if area then
		d.land:SetPoint("TOP", d.area, "BOTTOM", 0, -STEP)
	else
		d.land:SetPoint("TOP", d.plate, "BOTTOM", 0, -GAP)
	end
	UI.Ink(d.land, Tone(s.kind))
end

-- The piece as a picture: where you are now, as it would be said on entering.
function Z.Sample(parent)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(WIDTH, HEIGHT)
	f:EnableMouse(false)
	local d = Draw(f)
	local function Read()
		local name, area, kind = GetZoneText(), GetSubZoneText(), Kind()
		Lay(d, { name = name, area = area ~= name and area or "", land = Said(kind), kind = kind })
	end
	f:SetScript("OnShow", Read)
	Read()
	f.drawing = d
	return f
end

-- Following the game's two frames

local function Text(fs)
	local text = fs:GetText()
	if text == nil then return "" end
	return text
end

-- Words the game keeps secret can't be compared: two secrets are taken as the same words.
local function Same(a, b)
	if issecretvalue(a) or issecretvalue(b) then return issecretvalue(a) and issecretvalue(b) end
	return a == b
end

local function Empty(text)
	return not issecretvalue(text) and text == ""
end

-- How long a frame of the game's has left to show, or nil while it doesn't.
local function Left(frame)
	if not frame:IsShown() or type(frame.startTime) ~= "number" then return nil end
	return FadingFrame_GetRemainingTime(frame)
end

-- One piece's alpha: in at IN while its frame shows, out over the last OUT of its time, quickly when the
-- game takes it away early (a toast in the middle of the screen).
local function Follow(alpha, left, elapsed)
	if not left then return math.max(0, alpha - elapsed / QUICK) end
	return math.max(0, math.min(1, alpha + elapsed / IN, left / OUT))
end

local function Read()
	local zone, sub = ZoneTextFrame, SubZoneTextFrame
	local start = sub.startTime
	-- An area said while the zone's name isn't up stands on the plaque by itself.
	if zone:IsShown() then
		now.mode = "zone"
	elseif sub:IsShown() and start ~= seenStart then
		now.mode = "alone"
	end
	seenStart = start
	local arena = Text(PVPArenaTextString)
	local s = { kind = Kind(), alone = now.mode == "alone" }
	if s.alone then
		s.name, s.area, s.plate = Text(SubZoneTextString), "", sub
	else
		s.name, s.area, s.plate = Text(ZoneTextString), Text(SubZoneTextString), zone
	end
	if not Empty(arena) then
		s.land, s.word = arena, sub
	elseif s.alone then
		s.land, s.word = "", sub
	else
		s.land, s.word = Text(PVPInfoTextString), zone
	end
	return s
end

local function Fit()
	if not (banner and box) then return end
	banner:SetScale(box:GetScale())
end

local function Box()
	if box then return box end
	box = HUD.Find(ID)
	if box then
		banner:ClearAllPoints()
		banner:SetPoint("TOP", box, "TOP", 0, 0)
		hooksecurefunc(box, "SetScale", Fit)
		Fit()
	end
	return box
end

local said = {}

-- The notices' ribbon at the column's head takes the zone's name when it can (ShyCore's Notices.Headline):
-- this module still follows the game and says what and how strongly; the ribbon draws it.
local function Ribbon()
	return Shy.Notices ~= nil and Shy.Notices.Headline ~= nil
end

local function Tell(s)
	if Empty(s.name) or now.plate <= 0 then
		Shy.Notices.Headline(nil)
		return
	end
	Shy.Notices.Headline({ name = s.name, land = (not Empty(s.land or "")) and Caps(s.land) or nil,
		area = (not s.alone and not Empty(s.area or "")) and Caps(s.area) or nil, color = Tone(s.kind),
		alpha = now.plate, side = math.max(now.under, now.word) })
end

local function Tick(_, elapsed)
	local s = Read()
	local d = banner.drawing
	-- New words come in from nothing; the same words said again stay up.
	if not Same(s.name, said.name) or s.alone ~= said.alone then now.plate, now.up = 0, 0 end
	if not Same(s.area, said.area) then now.under = 0 end
	if not Same(s.land, said.land) then now.word = 0 end
	if not (Same(s.name, said.name) and Same(s.area, said.area) and Same(s.land, said.land) and s.kind == said.kind and s.alone == said.alone) then
		Lay(d, s)
		said = s
	end
	local area = SubZoneTextFrame
	now.plate = Empty(s.name) and 0 or Follow(now.plate, Left(s.plate), elapsed)
	now.under = (s.alone or Empty(s.area)) and 0 or Follow(now.under, Left(area), elapsed)
	now.word = Empty(s.land) and 0 or Follow(now.word, Left(s.word), elapsed)
	if now.up < 1 or said.risen ~= true then
		now.up = math.min(1, now.up + elapsed / IN)
		local eased = 1 - (1 - now.up) * (1 - now.up)
		d.plate:SetPoint("TOP", banner, "TOP", 0, -RISE * (1 - eased))
		said.risen = now.up >= 1
	end
	d.plate:SetAlpha(now.plate)
	d.area:SetAlpha(now.under)
	d.land:SetAlpha(now.word)
	local done = not (ZoneTextFrame:IsShown() or area:IsShown()) and now.plate == 0 and now.under == 0 and now.word == 0
	if Ribbon() then
		if done then Shy.Notices.Headline(nil) else Tell(said) end
	end
	if done then
		banner:Hide()
		said = {}
	end
end

local function Safe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		if banner then banner:Hide() end
		if Ribbon() then pcall(Shy.Notices.Headline, nil) end
		if not failed then
			failed = tostring(err)
			geterrorhandler()(err)
		end
	end
end

local function Wake()
	if not (Z.on and banner and Box()) or banner:IsShown() then return end
	now.plate, now.under, now.word, now.up = 0, 0, 0, 0
	said = {}
	-- (Drawn by the ribbon, the banner only keeps time.)
	banner:SetAlpha(Ribbon() and 0 or 1)
	banner:Show()
end

local function Build()
	if banner then return end
	banner = CreateFrame("Frame", nil, UIParent)
	banner:SetSize(WIDTH, HEIGHT)
	banner:SetFrameStrata("LOW")
	banner:EnableMouse(false)
	banner:Hide()
	banner.drawing = Draw(banner)
	banner:SetScript("OnUpdate", function(self, elapsed) Safe(Tick, self, elapsed) end)
	for _, frame in ipairs({ ZoneTextFrame, SubZoneTextFrame }) do
		frame:HookScript("OnShow", function() Safe(Wake) end)
	end
	Shy:On("SHY_THEME", function()
		for d in pairs(drawings) do Look(d) end
	end)
end

function Z.Now()
	return { mode = now.mode, name = said.name, area = said.area, land = said.land, kind = said.kind,
		plate = now.plate, under = now.under, word = now.word, shown = banner ~= nil and banner:IsShown() }
end

function Z.Banner() return banner end

local function Looked(on)
	if Shy.Top and Shy.Top.Look then
		-- (In the ribbon, the zone's box leaves the column: the ribbon is where it stands.)
		if on then Shy.Top.Look(ID, Z.Sample, WIDTH, HEIGHT, Ribbon()) else Shy.Top.Look(ID) end
	end
end

ns.Module({
	id = "zone",
	title = "Zone name",
	desc = "Shows the zone's name on a plate as you enter, lit by who controls it, with the area's name under it.",

	Ready = function() return ZoneTextFrame ~= nil and SubZoneTextFrame ~= nil end,

	Hook = function() Build() end,

	Paint = function(m, kit)
		kit:Hide(ZoneTextString)
		kit:Hide(PVPInfoTextString)
		kit:Hide(SubZoneTextString)
		kit:Hide(PVPArenaTextString)
		local was = Z.on
		Z.on = true
		if not was then
			Looked(true)
			if ZoneTextFrame:IsShown() or SubZoneTextFrame:IsShown() then Safe(Wake) end
		end
	end,

	Clear = function(m)
		if m.on then return end
		Z.on = false
		if banner then banner:Hide() end
		if Ribbon() then Shy.Notices.Headline(nil) end
		said = {}
		Looked(false)
	end,
})
