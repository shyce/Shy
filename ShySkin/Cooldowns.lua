-- The cooldown manager (Blizzard_CooldownViewer): every icon in its four viewers a slot, tracked bars hatched.
-- Item state is never queried: Blizzard's own textures (out of range, debuff border, pandemic) are restyled.
-- Items are pooled, so painting follows OnAcquireItemFrame and AnchorPandemicStateFrame.
-- Nothing is drawn on the viewers themselves (they lay out their items) and no item is moved, sized or shown;
-- only a tracked bar is anchored against its icon (AlignBar), and Clear puts Blizzard's anchors back.
-- A cooldown's swipe texture can't be read back and texture scales aren't tracked by the kit: Clear restores both.

local ADDON, ns = ...
local UI, Skin, Theme = Shy.UI, Shy.Skin, Shy.Theme
local C = Skin.colors

local SWIPE = "Interface\\AddOns\\ShySkin\\Media\\Swipe"
local BLIZZARD_SWIPE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"   -- from CooldownViewer.xml
local OVERLAY = "ui-hud-cooldownmanager-iconoverlay"                        -- atlas of the soft border round an icon

local BUTTON = 45    -- action button size the slot's frame is drawn for
local RIM = 3        -- how far the frame covers the icon
local GLOSS = 0.8    -- gloss alpha, as on the action bars
local WOVEN = { tile = true }   -- unit frames tile the hatch along the bar (UnitFrames.lua)

local viewers             -- { frame =, size =, paint =, bars = }
local borders             -- debuff border atlas -> color
local dressed = {}        -- items skinned since the last restore
local hooked = {}         -- items with a debuff border hook
local tiles = {}          -- tracked buff or bar -> its icon's slot
local swiped = {}         -- cooldown with our swipe -> its item
local scaled = {}         -- Blizzard textures we rescaled
local drained = setmetatable({}, { __mode = "k" })   -- status bar -> clipped hatch fill, kept across Clear
local aligned = {}        -- tracked bar -> Blizzard's anchors, while it stands against its icon
local found = setmetatable({}, { __mode = "k" })   -- icon holder -> { mask, overlay }

-- Blizzard's rounded mask and soft border are unnamed: found once, by GetMaskTexture and by atlas.
local function Unnamed(holder, icon)
	local parts = found[holder]
	if parts then return parts end
	parts = {}
	found[holder] = parts
	local masks = icon:GetNumMaskTextures()
	if not issecretvalue(masks) and masks > 0 then
		local mask = icon:GetMaskTexture(1)
		if not issecretvalue(mask) then parts.mask = mask end
	end
	for _, region in ipairs({ holder:GetRegions() }) do
		if not issecretvalue(region) and region:IsObjectType("Texture") then
			local atlas = region:GetAtlas()
			if not issecretvalue(atlas) and type(atlas) == "string" and atlas:lower() == OVERLAY then
				parts.overlay = region
			end
		end
	end
	return parts
end

-- Scales our art so the frame is as thick as on an action button of this size.
local function Fine(regions, scale)
	for _, region in ipairs(regions) do region:SetScale(scale) end
end

-- The same for a Blizzard texture carrying our art; remembered for Clear.
local function FineArt(texture, scale)
	scaled[texture] = true
	texture:SetScale(scale)
end

-- Durations carry a localized letter ("5 m"), so they need a font family.
local function Face(fontString)
	local _, size = fontString:GetFont()
	return UI.NameFont(math.floor((size or 12) + 0.5), "OUTLINE")
end

-- holder: the frame the icon is drawn on (the item, or a bar's icon box).
local function PaintIcon(m, kit, holder, icon, scale)
	local parts = Unnamed(holder, icon)
	kit:Unmask(icon, parts.mask)
	kit:Hide(parts.overlay)
	local tile = kit:Tile(holder, { hover = false, icon = icon })
	Fine(tile, scale)
	if m.opt.gloss then tile:Clip(ns.Gloss(kit, holder, { x = RIM * scale, y = RIM * scale, sublevel = 1, alpha = GLOSS })) end
	return tile
end

-- The swipe color Blizzard last set; tracked buffs always use the default.
local function SwipeColor(item)
	local c = item.cooldownSwipeColor
	if issecretvalue(c) or type(c) ~= "table" then c = CooldownViewerConstants.ITEM_COOLDOWN_COLOR end
	return c.r, c.g, c.b, c.a
end

local function PaintCooldown(kit, item)
	local cooldown = item.Cooldown
	if not swiped[cooldown] then
		swiped[cooldown] = item
		-- The slot's shape (its level for the cooldown's size, following a change of shape); ours on the square.
		Shy.Slot.Swipe(cooldown, { color = { SwipeColor(item) }, square = SWIPE })
	end
	local numbers = cooldown:GetCountdownFontString()
	if numbers then kit:FontObject(numbers, Face(numbers)) end
end

-- A texture Blizzard shows and hides itself, as the slot's glow. x, y: its outset past the slot.
local function Lit(kit, texture, color, scale, x, y)
	kit:Lit(texture, texture:GetParent(), color, (x or 0) / scale, (y or 0) / scale)
	FineArt(texture, scale)
end

-- Debuff type (tracked buffs and bars)

-- Returns the debuff type's color, false for no border, or nil when the atlas is secret or unknown.
local function Kind(border)
	local art = border.Texture
	local frame, shown, atlas = border:IsShown(), art:IsShown(), art:GetAtlas()
	if issecretvalue(frame) or issecretvalue(shown) or issecretvalue(atlas) then return nil end
	if not (frame and shown) or type(atlas) ~= "string" or atlas == "" then return false end
	return borders[atlas:lower()]
end

-- An unreadable border stays Blizzard's, with our frame hidden.
local function ShowKind(kit, item)
	local tile, border = tiles[item], item.DebuffBorder
	if not tile then return end
	local kind = Kind(border)
	kit:Fade(border.Texture, kind == nil and 1 or 0)
	tile:Bare(kind == nil)
	if kind then tile:Mark(kind:GetRGB()) else tile:Mark() end
end

local function FollowKind(m, item)
	if hooked[item] then return end
	hooked[item] = true
	hooksecurefunc(item.DebuffBorder, "UpdateFromAuraData", function()
		if m.on then ShowKind(m.kit, item) end
	end)
end

-- The bar's text and light, lifted over the hatch (a child frame draws over its parent's own regions).
local function Lifted(bar)
	return { bar.Name, bar.Duration, bar.Pip }
end

-- Made once per bar and kept, so turning the look off and on again makes nothing new.
local function BarDrain(kit, bar, tall)
	local d = drained[bar]
	if not d then
		d = Skin.BarDrain(bar, tall)
		d.front = CreateFrame("Frame", nil, bar)
		d.front:SetAllPoints(bar)
		d.front:EnableMouse(false)
		drained[bar] = d
	end
	local level = bar:GetFrameLevel()
	d:SetFrameLevel(level + 1)
	d.front:SetFrameLevel(level + 4)
	kit:Art(d.fill, tall and Skin.HATCH_TALL or Skin.HATCH, WOVEN)
	kit:Tint(d.fill, { Theme.Accent() }, true)
	for _, region in ipairs(Lifted(bar)) do region:SetParent(d.front) end
	d:AttachPip(bar.Pip, -1)
	d:Show()
	d.front:Show()
	return d
end

-- The three kinds of item

local function PaintSpell(m, kit, item, scale)
	PaintIcon(m, kit, item, item.Icon, scale)
	PaintCooldown(kit, item)
	ns.Number(kit, item.ChargeCount.Current)
	Lit(kit, item.OutOfRange, UI.colors.bad, scale)
end

local function PaintBuff(m, kit, item, scale)
	tiles[item] = PaintIcon(m, kit, item, item.Icon, scale)
	PaintCooldown(kit, item)
	ns.Number(kit, item.Applications.Applications)
	FollowKind(m, item)
	ShowKind(kit, item)
end

-- The template leaves the bar 19 tall and 2 short of its icon. The icon is the slot: the bar meets it,
-- top, foot and the line between them, so the two borders are one. With the icon hidden (name only)
-- the bar takes the icon's place, as Blizzard's does.
local function AlignBar(item)
	local box, bar = item.Icon, item.Bar
	if not (box and bar) then return end
	local shown = box:IsShown()
	if issecretvalue(shown) then return end
	if not aligned[bar] then
		local points = {}
		for i = 1, bar:GetNumPoints() do points[i] = { bar:GetPoint(i) } end
		aligned[bar] = points
	end
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", box, shown and "TOPRIGHT" or "TOPLEFT", 0, 0)
	bar:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
end

local function UnalignBar(bar)
	local points = aligned[bar]
	if not points then return end
	aligned[bar] = nil
	bar:ClearAllPoints()
	for _, point in ipairs(points) do bar:SetPoint(unpack(point)) end
end

local function PaintBar(m, kit, item, scale)
	local box, bar = item.Icon, item.Bar
	AlignBar(item)
	tiles[item] = PaintIcon(m, kit, box, box.Icon, scale)

	local barH = bar:GetHeight()
	local tall = not issecretvalue(barH) and type(barH) == "number" and barH >= 26
	-- Local height of the 30 template. 10px on a 15px bar is two thirds of that, the resource display's text.
	local lineH = (not issecretvalue(barH) and type(barH) == "number" and barH >= 18) and barH or 30
	local size = math.max(8, math.floor(lineH * 2 / 3 + 0.5))
	local inset = math.max(4, math.floor(lineH / 3 + 0.5))
	kit:Font(box.Applications, Shy.FONT_ROUNDED, math.max(8, size - 4), "OUTLINE")
	local set = kit:Bar(bar)
	kit:Art(set.track, tall and Skin.HATCH_TALL or Skin.HATCH, WOVEN)
	kit:Tint(set.track, C.well, true)
	kit:Tint(bar:GetStatusBarTexture(), { Theme.Accent() }, true)
	bar:GetStatusBarTexture():SetAlpha(0)   -- the cropped fill only marks the edge; BarDrain draws the hatch
	BarDrain(kit, bar, tall)
	kit:Hide(bar.BarBG)          -- Blizzard's track
	-- On the bar, as the slot is on the icon: the borders share a top, a foot and the join.
	Fine(kit:Frame(bar), scale)
	kit:Tint(bar.Pip, Theme.light)
	kit:FontObject(bar.Name, UI.NameFont(size, "OUTLINE"))
	kit:Text(bar.Name, UI.colors.text)
	kit:Font(bar.Duration, Shy.FONT_ROUNDED, size, "OUTLINE")
	-- On the bar's middle at the health bar's inset, the name leaving the time its room.
	kit:Place(bar.Name, nil, size, { "LEFT", bar, "LEFT", inset, 0 }, { "RIGHT", bar, "RIGHT", -(inset + size), 0 })
	kit:Place(bar.Duration, nil, size, { "RIGHT", bar, "RIGHT", -inset, 0 })

	FollowKind(m, item)
	ShowKind(kit, item)
end

local function PaintItem(m, kit, v, item)
	if dressed[item] then
		-- Handed out again: Blizzard has just anchored the bar past its icon and may have a new fill.
		if v.bars then
			AlignBar(item)
			local drain = drained[item.Bar]
			if drain then drain:Bind() end
		end
		return
	end
	dressed[item] = true
	v.paint(m, kit, item, v.size / BUTTON)
end

-- The pandemic border sits 6 outside an icon (CooldownViewerMixin) and 9 by 10 outside a bar (BuffBarCooldownViewerMixin).
local function PaintPandemic(kit, v, frame)
	local scale = v.size / BUTTON
	local border = frame.Border.Border
	if v.bars then
		kit:Art(border, Skin.FRAME, { fit = frame.Border, x = 9 / scale, y = 10 / scale,
			slice = Skin.FRAME_SLICE, color = UI.colors.alert })
		FineArt(border, scale)
		kit:Hide(frame.Texture)
	else
		Lit(kit, border, UI.colors.alert, scale, 6, 6)
		kit:Hide(frame.FX)
	end
end

ns.Module({
	id = "cooldowns",
	title = "Cooldown manager",
	desc = "The game's cooldown manager takes your icon shape, with its bars in your color.",
	group = "screen",
	words = "tracked buffs",
	options = {
		{ key = "gloss", label = "Glossy icons", default = true,
			desc = "A soft highlight runs across the top of each icon." },
	},

	Ready = function()
		local _, loaded = C_AddOns.IsAddOnLoaded("Blizzard_CooldownViewer")
		return loaded
	end,

	Hook = function(m)
		viewers = {
			{ frame = EssentialCooldownViewer, size = 50, paint = PaintSpell },
			{ frame = UtilityCooldownViewer, size = 30, paint = PaintSpell },
			{ frame = BuffIconCooldownViewer, size = 40, paint = PaintBuff },
			{ frame = BuffBarCooldownViewer, size = 30, paint = PaintBar, bars = true },
		}
		borders = {}
		for _, info in pairs(AuraUtil.GetDebuffDisplayInfoTable()) do
			borders[info.basicAtlas:lower()] = info.color
			if info.dispelAtlas then borders[info.dispelAtlas:lower()] = info.color end
		end
		for _, v in ipairs(viewers) do
			hooksecurefunc(v.frame, "OnAcquireItemFrame", function(_, item)
				if m.on and not issecretvalue(item) then PaintItem(m, m.kit, v, item) end
			end)
			hooksecurefunc(v.frame, "AnchorPandemicStateFrame", function(_, frame)
				if m.on and not issecretvalue(frame) then PaintPandemic(m.kit, v, frame) end
			end)
		end
		-- The viewer's SetBarContent anchors every bar 2 past its icon (or on it, name only): against the icon again.
		hooksecurefunc(BuffBarCooldownViewer, "SetBarContent", function(viewer)
			if not m.on then return end
			for item in viewer.itemFramePool:EnumerateActive() do
				if not issecretvalue(item) and dressed[item] then AlignBar(item) end
			end
		end)
	end,

	Paint = function(m, kit)
		for _, v in ipairs(viewers) do
			for item in v.frame.itemFramePool:EnumerateActive() do PaintItem(m, kit, v, item) end
			for frame in v.frame.pandemicIconPool:EnumerateActive() do PaintPandemic(kit, v, frame) end
		end
	end,

	Clear = function()
		for cooldown, item in pairs(swiped) do
			Shy.Slot.Unswipe(cooldown)
			cooldown:SetSwipeTexture(BLIZZARD_SWIPE, SwipeColor(item))
		end
		for texture in pairs(scaled) do texture:SetScale(1) end
		for bar, drain in pairs(drained) do
			for _, region in ipairs(Lifted(bar)) do region:SetParent(bar) end
			drain.front:Hide()
			drain:Hide()
			bar:GetStatusBarTexture():SetAlpha(1)
		end
		for bar in pairs(aligned) do UnalignBar(bar) end
		wipe(swiped)
		wipe(scaled)
		wipe(dressed)
	end,
})
