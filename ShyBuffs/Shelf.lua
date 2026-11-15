-- The shelf beside the minimap: what you carry between fights, and every debuff on you under it.
--
--     [f][f][long][long][long][weapon] | +---- minimap ----
--                 [debuff][debuff][debuff] |
--
-- From the minimap leftward: your weapon's coating (framed in your color), then timed buffs, the one soonest
-- out first, then the buffs that never run out, in the same run. Rows wrap downward. Your debuffs start a row
-- of their own under them in the same form, framed in their kind's color. Every buff stands here, short ones
-- too. The look is a setting (T.db.look), each a container of its own built when first wanted:
--   run     icons, a hair of your color draining under each, the time under that
--   pills   each a pill: its icon and its time beside it, its foot draining
--   bars    one to a line: name, time, the bar running down (a debuff's in its kind's color)
--   watch   larger icons, the time in the icon's foot, the frame a bezel of your color running out round it
-- In every look a time is gold in its last half minute and beats in its last ten, and one that comes slides in
-- from the minimap's side. The tooltip of the one under the mouse is Caster.lua's.

local ADDON, ns = ...
local T, K = ns.T, ns.Kit
local HUD, Skin = Shy.HUD, Shy.Skin

local S = {}
ns.Shelf = S

local ICON = 26                  -- an icon at the default size; the setting scales the row
local GAP, APART = 3, 9          -- between two icons, and before the debuffs
local PER_ROW = 8
local LASTING = 30 * 86400       -- any duration counts as timed; none at all does not
local WIDTH = PER_ROW * ICON + (PER_ROW - 1) * GAP
local PILL = 64                  -- a pill's width: four to a row, on a row of their own width
local WATCH = 30                 -- the watch's icons: seven to a row
local BAR_GAP = 2                -- between two bars

local SLOTS = { AuraContainerItemEnchantmentSlot.MainHand, AuraContainerItemEnchantmentSlot.OffHand }

-- Each look: its pieces' specs (Kit.Maker's or Kit.BarMaker's), the coating's size, and how tall it stands in
-- layout mode (a few rows of buffs and one of debuffs). `timed` and `kept` are the long and forever groups' filters.
local LOOKS = {
	run = {
		coating = { size = ICON, time = "under", drain = true, plain = true, cancel = true, arrive = true },
		long = { size = ICON, time = "under", drain = true, plain = true, cancel = true, arrive = true },
		forever = { size = ICON, plain = true, cancel = true, arrive = true },
		harm = { size = ICON, time = "under", drain = true, plain = true, harm = true, arrive = true },
		row = ICON + K.DRAIN + K.TIME_UNDER + GAP, rows = 3,
	},
	pills = {
		coating = { size = ICON, pill = PILL, time = "beside", plain = true, cancel = true, arrive = true },
		long = { size = ICON, pill = PILL, time = "beside", plain = true, cancel = true, arrive = true },
		-- One that never runs out has no time: its pill is its icon in a plate of the same make.
		forever = { size = ICON, pill = ICON + 2 * K.PILL_PAD, plain = true, cancel = true, arrive = true },
		harm = { size = ICON, pill = PILL, time = "beside", plain = true, harm = true, arrive = true },
		row = ICON + 2 * K.PILL_PAD + GAP, rows = 5,
		line = 4 * PILL + 3 * GAP,
	},
	watch = {
		coating = { size = WATCH, time = "foot", watch = true, cancel = true, arrive = true },
		long = { size = WATCH, time = "foot", watch = true, cancel = true, arrive = true },
		forever = { size = WATCH, plain = true, cancel = true, arrive = true },
		harm = { size = WATCH, time = "foot", watch = true, harm = true, arrive = true },
		row = WATCH + GAP, rows = 3,
	},
	bars = {
		coating = { width = WIDTH, time = true, cancel = true, arrive = true },
		long = { width = WIDTH, time = true, cancel = true, arrive = true },
		forever = { width = WIDTH, cancel = true, arrive = true },
		harm = { width = WIDTH, time = true, harm = true, arrive = true },
		row = K.BAR + BAR_GAP, rows = 10,
		bars = true,
	},
}

S.LOOKS, S.WIDTH, S.GAP, S.APART = LOOKS, WIDTH, GAP, APART

local box
local made = {}                  -- look -> its container, built when first wanted

-- Beside ShySkin's minimap panel when there is one, else the game's minimap: the row's top on its top line, a
-- seam left of it. The row's top right corner from the screen's; nil while neither can be measured.
local function Corner()
	local skin = Shy.addons.Skin
	local left, _, _, top
	if skin and skin.MinimapPanel then left, _, _, top = skin:MinimapPanel() end
	if not left then
		left, top = MinimapCluster:GetLeft(), MinimapCluster:GetTop()
		if left == nil or issecretvalue(left) or issecretvalue(top) then return nil end
		local scale = MinimapCluster:GetEffectiveScale() / UIParent:GetEffectiveScale()
		left, top = left * scale, top * scale
	end
	local dock = Shy.addons.Dock
	local seam = dock and dock.Seam and dock:Seam() or 4
	return left - seam - UIParent:GetWidth(), top - UIParent:GetHeight()
end

local function Home()
	local x, y = Corner()
	return { "TOPRIGHT", "TOPRIGHT", x or -260, y or -6 }
end

-- The panel is as wide as the quest tracker's and is placed again whenever that, the game's own layout or the
-- map's shape changes, and nothing tells of it: the corner is looked at twice a second, and the shelf goes
-- with it. A place you gave the shelf yourself stays yours.
local FOLLOW = 0.5
local corner = {}   -- the corner the home was last given: x, y

local function Follow()
	if not box then return end
	local x, y = Corner()
	if not x then return end
	if corner.x and math.abs(x - corner.x) < 0.05 and math.abs(y - corner.y) < 0.05 then return end
	corner.x, corner.y = x, y
	HUD.SetHome(box, { "TOPRIGHT", "TOPRIGHT", x, y })
end

local function Scale()
	return T.db.size / ICON
end

local function Shown()
	return T.db.shelf or T.db.debuffs
end

local function Look()
	return LOOKS[T.db.look] and T.db.look or "run"
end

-- Every timed buff, and the ones known never to run out.
local function Filters()
	return { maxDuration = LASTING }, { includeSpellIDs = T.db.known.forever }
end

-- A piece's spec with the group's own fields.
local function With(spec, more)
	local out = {}
	for key, value in pairs(spec) do out[key] = value end
	for key, value in pairs(more) do out[key] = value end
	return out
end

local function Build(look)
	local L = LOOKS[look]
	local c = K.Container(box, { point = "TOPRIGHT", across = "Left", up = "Down", line = L.line or WIDTH })
	K.Place(c, box, "TOPRIGHT", 0, 0)
	local timed, kept = Filters()
	local coat = With(L.coating, { steel = Skin.colors.on })
	if L.bars then
		for _, slot in ipairs(SLOTS) do K.AddCoating(c, slot, K.BarMaker(coat), { WIDTH, K.BAR }) end
		K.CoatingLayout(c, {
			placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups,
			elementSpacing = BAR_GAP, groupSpacing = BAR_GAP, lineSpacing = BAR_GAP, groupLineSpacing = BAR_GAP,
			elementWidth = WIDTH, elementHeight = K.BAR,
		})
		K.AddGroup(c, "long", "HELPFUL", K.BarGroup(With(L.long, { gap = BAR_GAP, filters = timed, sort = AuraContainerSortMethod.ExpirationOnly })))
		K.AddGroup(c, "forever", "HELPFUL", K.BarGroup(With(L.forever, { gap = BAR_GAP, filters = kept, sort = AuraContainerSortMethod.NameOnly })))
		K.AddGroup(c, "harm", "HARMFUL", K.BarGroup(With(L.harm, { gap = BAR_GAP, line = APART, newLine = true })))
		return c
	end
	-- The coating's piece is a group's piece in all but its filters, so it lays out as one of the row.
	local piece = K.Group(coat)
	for _, slot in ipairs(SLOTS) do
		K.AddCoating(c, slot, piece.initializeFrame, { piece.layout.elementWidth, coat.size })
	end
	K.CoatingLayout(c, {
		placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups,
		elementSpacing = GAP, groupSpacing = GAP, lineSpacing = GAP, groupLineSpacing = GAP,
		elementWidth = piece.layout.elementWidth, elementHeight = piece.layout.elementHeight,
	})
	K.AddGroup(c, "long", "HELPFUL", K.Group(With(L.long, { gap = GAP, filters = timed, sort = AuraContainerSortMethod.ExpirationOnly })))
	K.AddGroup(c, "forever", "HELPFUL", K.Group(With(L.forever, { gap = GAP, filters = kept, sort = AuraContainerSortMethod.NameOnly })))
	K.AddGroup(c, "harm", "HARMFUL", K.Group(With(L.harm, { gap = GAP, line = APART, newLine = true })))
	return c
end

-- Every container takes the same settings; only the look's watches you.
local function Set(c, on)
	K.Scale(c, Scale())
	local buffs = T.db.shelf and true or false
	K.Enable(c, "long", buffs)
	K.Enable(c, "forever", buffs)
	for _, slot in ipairs(SLOTS) do K.EnableCoating(c, slot, buffs) end
	K.Enable(c, "harm", T.db.debuffs and true or false)
	K.Watch(c, "player", on and Shown())
end

-- The mouse on the shelf means the icons are yours. The second answer is the box, for whoever stands
-- something beside the row.
function S.Under()
	if not (box and box:IsShown() and Shown()) then return nil end
	local over = box:IsMouseOver()
	if issecretvalue(over) then return nil end
	-- Rows that run past the box's foot are the shelf's too.
	local rows = made[Look()]
	if not over and rows then
		local ok, on = pcall(rows.IsMouseOver, rows)
		over = ok and not issecretvalue(on) and on
	end
	if not over then return nil end
	return "player", { "TOPRIGHT", box, "TOPLEFT", -GAP, 0 }
end

function S.Apply()
	if not box then return end
	HUD.Update(box)
	ns.WhenFree("shelf", function()
		local look = Look()
		made[look] = made[look] or Build(look)
		local scale = Scale()
		local L = LOOKS[look]
		box:SetSize((L.line or WIDTH) * scale, L.rows * L.row * scale)
		for which, c in pairs(made) do Set(c, which == look) end
		-- Named for what it holds in the layout editor: the default debuff row stands down for it.
		if box then box.title = T.db.debuffs and "Buffs and debuffs" or "Buffs" end
	end)
end

-- The left end of the shelf's first row, for what stands beyond it (Missing.lua): the box, and an icon's size there.
function S.End()
	local L = LOOKS[Look()]
	return box, (L.long.size or ICON) * Scale()
end

function S.Start()
	local L = LOOKS[Look()]
	box = HUD.Create({
		id = "shybuffs-shelf", title = "Buffs",
		width = (L.line or WIDTH) * Scale(), height = L.rows * L.row * Scale(),
		point = Home(),
		shown = Shown,
	})
	-- A buff that never runs out was seen for the first time: the forever group takes it.
	Shy:On("SHY_BUFFS_KNOWN", function()
		ns.WhenFree("shelf-known", function()
			local _, kept = Filters()
			for _, c in pairs(made) do K.Filters(c, "forever", kept) end
		end)
	end)
	Shy:On("SHY_CONSOLE", Follow)
	local events = CreateFrame("Frame")
	events:RegisterEvent("UI_SCALE_CHANGED")
	events:RegisterEvent("DISPLAY_SIZE_CHANGED")
	events:SetScript("OnEvent", Follow)
	C_Timer.NewTicker(FOLLOW, Follow)
end
