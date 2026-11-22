-- A hunter's pet wears its mood on its frame (T.db.mood): the game's face for it leads the pet's name, and round a
-- portrait like the game's the ring turns gold while it is content and red while it is unhappy. Pointing at the face
-- says what the mood does to its damage, whether its loyalty is rising and what it eats.
-- Only our own regions change, so it shows in a fight too. The face takes no click: the frame under it does.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI

local M = {}
ns.Mood = M

local FACES = { "UI-PetMad", "UI-PetNeutral", "UI-PetHappiness" }   -- the game's, by its mood: 1 to 3
local WORDS = { PET_HAPPINESS1, PET_HAPPINESS2, PET_HAPPINESS3 }
local HAPPY = 3
local FACE = 16   -- a little over the pet's name (15)

local mood, damage, loyalty   -- as last read; mood nil with no hunter's pet out

-- The mood now, or nil: none for a pet that isn't a hunter's, or with the setting off.
local function Read()
	if not T.db.mood then return nil end
	local _, hunters = HasPetUI()
	if issecretvalue(hunters) or not hunters then return nil end
	local m, d, l = C_PetInfo.GetPetHappiness()
	if m == nil or issecretvalue(m) or not FACES[m] then return nil end
	if issecretvalue(d) then d = nil end
	if issecretvalue(l) then l = nil end
	return m, d, l
end

-- The ring's color for a unit's portrait: the mood's, while your pet isn't happy. nil leaves the ring as picked.
function M.Ring(unit)
	if unit ~= "pet" or not mood or mood == HAPPY then return nil end
	return mood == 1 and UI.colors.bad or UI.colors.alert
end

-- What the face's hover says: what it can't show.
local function Content()
	local rows = {}
	if damage then rows[#rows + 1] = { text = PET_DAMAGE_PERCENTAGE:format(damage) } end
	if loyalty and loyalty > 0 then
		rows[#rows + 1] = { text = GAINING_LOYALTY, color = UI.colors.good }
	elseif loyalty and loyalty < 0 then
		rows[#rows + 1] = { text = LOSING_LOYALTY, color = UI.colors.bad }
	end
	local diet = C_PetInfo.GetPetFoodTypes()
	rows[#rows + 1] = { text = PET_DIET_TEMPLATE:format(#diet > 0 and table.concat(diet, PET_FOOD_DELIMIT) or NONE) }
	return { title = WORDS[mood], sections = { { rows = rows } } }
end

-- The face, leading the plate's name, and what the mouse points at over it.
local function Build(plate)
	local face = plate.overlay:CreateTexture(nil, "OVERLAY")
	face:SetSize(FACE, FACE)
	face:Hide()
	local hit = CreateFrame("Frame", nil, plate.overlay)
	hit:SetAllPoints(face)
	hit:SetMouseMotionEnabled(true)
	hit:SetMouseClickEnabled(false)
	hit:Hide()
	hit:SetScript("OnEnter", function(self)
		if mood then Shy.Hover.Show(self, Content()) end
	end)
	hit:SetScript("OnLeave", function(self) Shy.Hover.Hide(self) end)
	plate.lead, plate.moodHit = face, hit
	plate:ArrangeName()
end

-- A plate shows mood `m` (1 to 3; nil: none), with what it does to the pet's damage and loyalty: the face, the name
-- after it, the ring.
function M.Dress(plate, m, d, l)
	mood, damage, loyalty = m, d, l
	if not plate.moodHit then Build(plate) end
	local face = plate.lead
	if m then face:SetAtlas(FACES[m]) end
	local shown = m ~= nil
	if shown ~= face:IsShown() then
		face:SetShown(shown)
		plate.moodHit:SetShown(shown)
		plate:ArrangeName()
	end
	if ns.Portrait then ns.Portrait.Retint(plate) end
end

-- Read again and shown on your pet's frame.
function M.Update()
	local frame = ns.Frames and ns.Frames.byKey.pet
	if frame then M.Dress(frame.plate, Read()) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PET_UI_UPDATE")
events:RegisterUnitEvent("UNIT_PET", "player")
events:RegisterUnitEvent("UNIT_HAPPINESS", "pet")
events:SetScript("OnEvent", Shy.Clocked("ShyFrames mood", M.Update))
