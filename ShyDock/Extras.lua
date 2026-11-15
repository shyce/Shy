-- The extra ability over the cockpit, and an encounter's bar under the column at the top's middle.
--
--                  [ * ]            the extra ability: a slot on the cockpit's top line
--     [g][g][g][g]        [b][b]
--     +---------- cockpit ---------+
--
-- An extra ability is a button the game hands you for a fight or a quest. It comes up in a slot of its
-- own, centred over the cockpit where the cooldowns are watched, a little smaller than the game makes it
-- (Layout.Over plans the slot). The game hangs the button in a frame 256 wide with a picture round it
-- that would lie over the cockpit, so the picture is put away while the slot is seated; the button's own
-- look is ShySkin's, as every action button's is.
--
-- An encounter's bar (the bar a fight gives you to watch) was written to the same spot. It is as tall as
-- the fight makes it, and over the slot it reached the character, so in play it hangs under the column
-- down from the top's middle instead (Shy.Top.Foot), where what a fight shows is looked for; the Edit
-- Mode layout has it over the slot, for when nobody arranges the screen.
--
-- Both are Edit Mode frames, adopted into Shy.HUD and placed with the engine's own SetPointBase, so no
-- Edit Mode code runs from here. One moved in Edit Mode stays the player's until it is reset there or
-- the console is set up again (ns.char.loose). The slot is a frame of ours placed by coordinates: Edit
-- Mode's sheet and layout mode's mover lie over it, not over the game's wide frame, and a light blooms
-- round it as an ability arrives.
-- Registers itself with Arrange.lua (A.Also), which never calls this file directly.

local ADDON, ns = ...
local HUD, UI, Skin = Shy.HUD, Shy.UI, Shy.Skin
local C = UI.colors

local E = {}
ns.Extras = E

local BLOOM = 5          -- how far the arrival's light reaches past the slot
local ARRIVE = 0.9       -- seconds it takes to fade

local extra, encounter   -- the game's two frames, as boxes
local seat               -- where the button stands: a frame of ours
local kit = Skin.NewKit()
local dressed = false
local soon

local function Near(a, b)
	if a == nil or b == nil then return a == b end
	return a[1] == b[1] and a[2] == b[2] and math.abs(a[3] - b[3]) < 0.05 and math.abs(a[4] - b[4]) < 0.05
end

local function Give(box, home, scale)
	if Near(box.given, home) and box.givenScale == scale then return end
	HUD.SetHome(box, home, scale)
end

-- The picture the game draws round the button, away while the slot is seated.
local function Dress(on)
	if on == dressed then return end
	dressed = on
	if on then kit:Hide(ExtraActionButton1.style) else kit:Restore() end
end

local function Stand()
	if not extra then return end
	local on = ns.Arrange.On()
	local over
	if on then
		local _, now = ns.Layout.Plan()
		over = ns.Layout.Over(ns.Layout.Cockpit(now))
	end
	local seated = on and not ns.char.loose.extra
	if seated then
		Give(extra, { "BOTTOM", "BOTTOM", over.x, over.extra }, over.scale)
		local button = over.button
		seat:ClearAllPoints()
		seat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", button[1], button[2])
		seat:SetSize(button[3] - button[1], button[4] - button[2])
	else
		Give(extra, nil, nil)
	end
	seat:SetShown(seated)
	Dress(seated)
	Give(encounter, on and not ns.char.loose.encounter and { "TOP", "TOP", 0, -Shy.Top.Foot() } or nil, nil)
end

-- Next frame, once: whoever arranges the screen is often asked several times in a frame.
function E.Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = nil
		Stand()
	end)
end

local function Adopt(frame, key, title, scale)
	return HUD.Adopt(frame, {
		id = "shydock-" .. key, title = title, editMode = true, plain = true, scale = scale,
		-- Moved in Edit Mode: drop its home without re-placing it mid-drag. The slot is ours to put away
		-- at once, and the game's picture is back round the button.
		taken = function(box)
			ns.char.loose[key] = true
			box.given, box.placed = nil, nil
			if box == extra then
				seat:Hide()
				Dress(false)
			end
		end,
		-- Reset to its default position in Edit Mode: back in its place.
		reset = function()
			ns.char.loose[key] = nil
			E.Soon()
		end,
	})
end

-- Returns the slot's frame and the two boxes.
function E.Parts()
	return seat, extra, encounter
end

function E.Start()
	if extra then return end
	seat = CreateFrame("Frame", nil, UIParent)
	seat:SetFrameStrata("LOW")
	seat:Hide()
	-- An ability arriving is something to see: a light round the slot that blooms and is gone.
	seat.light = seat:CreateTexture(nil, "OVERLAY")
	seat.light:SetTexture(Skin.GLOW)
	seat.light:SetTextureSliceMargins(Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE, Skin.GLOW_SLICE)
	seat.light:SetPoint("TOPLEFT", -BLOOM, BLOOM)
	seat.light:SetPoint("BOTTOMRIGHT", BLOOM, -BLOOM)
	UI.Tint(seat.light, C.alert)
	seat.light:SetAlpha(0)
	seat.arrive = seat.light:CreateAnimationGroup()
	local fade = seat.arrive:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	fade:SetDuration(ARRIVE)
	fade:SetSmoothing("OUT")

	extra = Adopt(ExtraAbilityContainer, "extra", "Extra ability", true)
	encounter = Adopt(EncounterBar, "encounter", "Encounter bar")
	-- The slot is what stands on the screen for the game's wide frame.
	HUD.SetHousing(ExtraAbilityContainer, seat)
	HUD.Cover(extra, seat)
	-- Only for an ability really handed over: Edit Mode and quick keybinds show the frame empty, and laying
	-- out the screen (setting up a layout) can too; none of that is an arrival.
	ExtraActionBarFrame:HookScript("OnShow", function()
		if not seat:IsShown() or not C_ActionBar.HasExtraActionBar() then return end
		seat.arrive:Stop()
		seat.arrive:Play()
	end)
	ns.Arrange.Also(E.Soon)
	-- The column at the top arranged again (a piece made, sized or dragged; the game's widgets up there):
	-- the bar under it follows.
	hooksecurefunc(Shy.Top, "Apply", E.Soon)
	E.Soon()
end

Shy:On("SHY_LOGIN", E.Start)
