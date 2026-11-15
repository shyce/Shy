-- The ways as they are found: while the ground is still working out the way of any of the route's legs
-- on the world map (each drawn as a bow meanwhile), a small plate at the map's top turns its spinner and
-- names the place whose way is being found, the next as each comes in, with how many are found; once the
-- last is in it shows a check a moment and goes. A map opened with every way already known shows none.
--
--   ns.Ways.Update(status)   the legs as LayLegs left them (ns.LEGS.status)

local ADDON, ns = ...
local R = ns.Route
local UI = Shy.UI
local C = UI.colors
local Maps = Shy.Maps

local Ways = {}
ns.Ways = Ways

local PAD = 9               -- inside the plate
local TALL = 24             -- the plate's height
local GLYPH = 14            -- its spinner, or its check
local NAME_MOST = 200       -- the widest a place's name stands
local LINGER = 1.4          -- seconds it stays once every way is found
local FADE = 0.25           -- seconds it takes to come and go, and a name to give way to the next
local CHECK = Shy.MEDIA .. "GlyphCheckS"

local holder, plate
local alpha, want = 0, 0
local doneAt                -- when the last way came in; nil while one is still being worked out
local active = false        -- a way was being worked out since the plate last went
local said                  -- the words it shows now
local nameAlpha = 1

local function Build()
	-- (Over the window of whatever draws the map, the game or ShyMaps: Shy.Maps.Over.)
	holder = CreateFrame("Frame", nil, Maps.Canvas():GetCanvasContainer())
	holder:SetSize(1, 1)
	holder:SetFrameStrata("HIGH")
	Maps.Over(holder, "TOP", 0, -10)
	plate = CreateFrame("Frame", nil, holder)
	plate:SetFrameStrata("HIGH")
	plate:SetHeight(TALL)
	plate:EnableMouse(false)
	UI.Panel(plate, { brackets = false })
	plate.spin = UI.Spinner(plate, GLYPH)
	plate.spin:SetPoint("LEFT", PAD, 0)
	plate.done = plate:CreateTexture(nil, "ARTWORK")
	plate.done:SetTexture(CHECK)
	plate.done:SetSize(GLYPH, GLYPH)
	plate.done:SetPoint("CENTER", plate.spin, "CENTER")
	UI.Tint(plate.done, Shy.Skin.colors.on)
	plate.name = UI.Text(plate, "", 12, false, C.text)
	plate.name:SetPoint("LEFT", plate.spin, "RIGHT", 7, 0)
	plate.name:SetWordWrap(false)
	plate.count = UI.Text(plate, "", 11, false, C.dim)
	plate.count:SetPoint("LEFT", plate.name, "RIGHT", 8, 0)
	plate:SetAlpha(0)
	holder:Hide()
	-- (The map closed: it starts afresh at the next opening.)
	holder:SetScript("OnHide", function()
		alpha, want, active, doneAt, said = 0, 0, false, nil, nil
		plate:SetAlpha(0)
	end)
	holder:SetScript("OnUpdate", Shy.Clocked("frame: ways", function(_, elapsed)
		-- Under the map's note while that shows.
		local note = ns.MapNote
		local below = note and note:IsShown() and -(note:GetHeight() + 6) or 0
		if plate.below ~= below then
			plate.below = below
			plate:ClearAllPoints()
			plate:SetPoint("TOP", holder, "TOP", 0, below)
		end
		if doneAt and GetTime() - doneAt >= LINGER then want, active = 0, false end
		if alpha ~= want then
			alpha = want > alpha and math.min(1, alpha + elapsed / FADE) or math.max(0, alpha - elapsed / FADE)
			plate:SetAlpha(alpha)
			if alpha == 0 then
				holder:Hide()
				return
			end
		end
		-- A new name comes in over a moment.
		if nameAlpha < 1 then
			nameAlpha = math.min(1, nameAlpha + elapsed / FADE)
			plate.name:SetAlpha(nameAlpha)
		end
	end))
end

-- The place a leg leads to, as the route names it.
local function Name(leg)
	local ok, title = pcall(R.Describe, leg.stop)
	return ok and title or nil
end

function Ways.Update(status)
	local working, found, first = 0, 0, nil
	for i = 1, status.n do
		local leg = status[i]
		if leg.state == "working" then
			working = working + 1
			first = first or leg
		elseif leg.state ~= nil then
			found = found + 1
		end
	end
	-- Nothing being worked out, and nothing was since the plate last went: nothing to say.
	if working == 0 and not active then return end
	if not plate then Build() end
	if status.n == 0 then
		want = 0
		return
	end
	if working > 0 then
		active, doneAt, want = true, nil, 1
	elseif not doneAt then
		doneAt = GetTime()
	end
	local words = first and (Name(first) or "Finding the way") or "Ways found"
	if words ~= said then
		said = words
		plate.name:SetText(words)
		-- (The first name is there at once; each after it comes in.)
		nameAlpha = alpha > 0 and 0 or 1
		plate.name:SetAlpha(nameAlpha)
	end
	plate.spin:SetShown(working > 0)
	plate.done:SetShown(working == 0)
	plate.count:SetText(("%d/%d"):format(found, status.n))
	-- (A long name runs out short of NAME_MOST: the plate stays small.)
	plate.name:SetWidth(0)
	local wide = math.min(NAME_MOST, plate.name:GetStringWidth())
	plate.name:SetWidth(wide)
	plate:SetWidth(PAD + GLYPH + 7 + wide + 8 + plate.count:GetStringWidth() + PAD + 2)
	holder:Show()
end
