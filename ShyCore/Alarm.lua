-- Shy.Alarm: what must be seen now (breath running out, fatigue, your health low and what to drink). The
-- head's make in the alarm's colors: the circle in the arrow's make with an exclamation mark (or what it is
-- about), a tall plaque of weave, white words, a light round it. It is one piece in one motion:
--
--   warning (`warn`)  the head itself becomes it, in amber: the mark in its circle, its plate the weave,
--                     draining. It takes the place of the guide's arrow (it is the head's first voice).
--   urgent (`fly`)    the head flashes red, then the alert leaves it and travels down to "Alert end" under
--                     your character (slow, fast, slow, growing to that place's size), the head its guide
--                     again behind it; it lands with a flash and beats there, quicker as it runs out.
--   gone              from under your character it goes back up into the head, quickly, and is gone.
--   quiet             (your health, which can run low again and again in a fight) it stands at the end
--                     only, at the strength its owner gives, its light beating slowly; it never flies.
--
--   Shy.Alarm.Raise(id, {
--       priority = 10,                    -- the highest raised shows
--       warn = true, or fly = true,       -- a warning or urgent (else quiet)
--       title = "Breath",                 -- the plate's words
--       under = "Major Healing Potion",   -- optional: the line under them
--       right = "13s",                    -- optional: at the plate's right end (in the head, at the end of the title's line)
--       icon = fileID | path,             -- a picture in the circle (round; dim = true greys it: not ready), or
--       sign = name | path,               -- a head sign (Shy.Top.Make.SIGNS), a hover glyph's name or a file
--                                         -- drawn for 24 units, in the circle's light (else the exclamation
--                                         -- mark)
--       color = { r, g, b },              -- optional: a warning's own color (breath's blue, as its bar in the drawer);
--                                         -- urgent is crimson whatever it is about
--       share = 0.6,                      -- optional: the weave drains to this share; under LOW it beats quicker
--                                         -- (a secret, your health as the game evaluates it, is shown as is)
--       alpha = function() end,           -- optional, quiet: its strength, read on Raise and Update (may be a
--                                         -- secret: a curve's result on your health)
--       covers = "BREATH",                -- optional: what it says in another's place (a mirror timer's bar
--                                         -- steps aside while it shows: Shy.Alarm.Covers)
--   })                                    -- raised again, it is updated in place
--   Shy.Alarm.Update(id)                  -- read again
--   Shy.Alarm.Clear(id)
--   Shy.Alarm.Up()                        -- the id showing, or nil
--   Shy.Alarm.Covers(what)                -- does the alert up now say this (its `covers`)
-- Bus: SHY_ALARM when what is up, or what it covers, changes.

local Shy = Shy
local HUD, UI, B, Theme = Shy.HUD, Shy.UI, Shy.Brand, Shy.Theme
local MEDIA = Shy.MEDIA

local A = {}
Shy.Alarm = A

local CIRCLE, FACE = 46, 56        -- the circle (Dial, drawn 46 across in a 56 canvas), as the head's
local R = CIRCLE / 2
local TALL = 34                    -- the tall plaque, centred on the circle
local PLATE_Y = (CIRCLE - TALL) / 2
local INSET, END, GAP = 10, 12, 12 -- circle to words; words to the point; the words to what stands at the right
local POINT = 15                   -- the tall plaque's pointed end
local LIGHT = 12
local PICTURE = 40                 -- a picture in the circle: its face (41 across, inside the ring's dark line)
local ZOOM = 0.08                  -- an icon's square frame, cut away on each side so its art fills the round
local ALERT = "alert"              -- the exclamation mark: a head sign (Shy.Top.Make.Sign), filling the face
local BEAM, BEAM_ALPHA = 0.8, 0.35 -- the light in the circle's middle, as the head's
local TITLE, UNDER, RIGHT = 16, 11, 18
local LEAST = 150                  -- the words never narrower
local HALO = 26                    -- how far the light reaches past the plate
-- The motion, in seconds: the head red before it goes, travelling down, settling as it lands, going back
-- up; then a beat every BEAT (QUICK under LOW of its share left), its swell taking SWELL of it.
local HOLD, TRAVEL, SETTLE, HOME = 0.45, 0.65, 0.3, 0.25
local BEAT, QUICK, LOW, SWELL = 1.1, 0.55, 0.35, 0.4
local OVER = 1.07                  -- how much larger than its end size it arrives, before it settles
local VOICE = 100                  -- the head's voice for it: over every other
local CRIMSON = Theme.COMBO[#Theme.COMBO]   -- urgent
local AMBER = Theme.COMBO[3]               -- coming
local WHITE = { 1, 1, 1 }
local SAMPLE = { title = "Breath", sign = "breath", right = "13s", share = 0.45 }

local alarms = {}                  -- id -> def
local up                           -- the id showing
local head, to                     -- where it starts (the head's box) and ends (layout mode's box)
local card
local stage, since                 -- "warn", "fly", "quiet" or "home", and since when (GetTime)
local driver                       -- runs Tick each frame, only while the card moves or beats (a stage but "warn")
local back                         -- going home: where it was, { x, y, scale }
local unseen = false               -- a quiet alert at no strength at all (your health whole): it stands unseen, and still
local quiet = { fresh = true, at = 0, RATE = 30 }   -- a quiet alert's beat: looked at RATE times a second (Tick)

-- The alert as drawn: a frame as wide as the plate and the circle's half either side, so it is centred on
-- the plate. Card(parent) -> c; c:Set(def) lays it to fit its words.
local function Card(parent)
	local Make = Shy.Top.Make
	local c = CreateFrame("Frame", nil, parent)
	c:SetSize(LEAST + 2 * R, CIRCLE)
	c:EnableMouse(false)
	c.plate = CreateFrame("Frame", nil, c)
	c.plate:SetPoint("TOP", 0, -PLATE_Y)
	c.plate:SetHeight(TALL)
	-- The light round the whole plate, under everything.
	c.halo = c:CreateTexture(nil, "BACKGROUND", nil, -8)
	c.halo:SetTexture(B.GLOW)
	c.halo:SetPoint("TOPLEFT", c.plate, "TOPLEFT", -HALO - R, HALO)
	c.halo:SetPoint("BOTTOMRIGHT", c.plate, "BOTTOMRIGHT", HALO, -HALO)
	c.p = Make.Plaque(c.plate, true)
	Make.Shape(c.plate, c.p, 0, 0, true, TALL)
	Make.Look(c.p)
	c.drain = Make.Drain(c.plate, true)
	Make.Fill(c.p, c.drain)
	local over = CreateFrame("Frame", nil, c)
	over:SetAllPoints()
	over:SetFrameLevel(c.drain:GetFrameLevel() + 3)
	c.light = over:CreateTexture(nil, "ARTWORK")
	c.light:SetTexture(MEDIA .. "HoverLight")
	c.light:SetHeight(LIGHT)
	c.light:SetPoint("TOPLEFT", c.plate, "TOPLEFT", R, 0)
	c.light:SetPoint("TOPRIGHT", c.plate, "TOPRIGHT", -POINT, 0)
	UI.Tint(c.light, WHITE, 0.6)
	c.glow = over:CreateTexture(nil, "BACKGROUND")
	c.glow:SetTexture(B.GLOW)
	c.glow:SetSize(CIRCLE * 1.8, CIRCLE * 1.8)
	c.glow:SetPoint("CENTER", c.plate, "LEFT")
	-- The flash it lands with: a ring of light out of the circle.
	c.burst = over:CreateTexture(nil, "OVERLAY", nil, 2)
	c.burst:SetTexture(B.GLOW)
	c.burst:SetPoint("CENTER", c.plate, "LEFT")
	c.burst:SetBlendMode("ADD")
	c.burst:SetAlpha(0)
	c.face = over:CreateTexture(nil, "ARTWORK", nil, 2)
	c.face:SetTexture(MEDIA .. "Dial")
	c.face:SetSize(FACE, FACE)
	c.face:SetPoint("CENTER", c.plate, "LEFT")
	UI.Tint(c.face, Theme.skin.metal)
	c.picture = over:CreateTexture(nil, "ARTWORK", nil, 3)
	c.picture:SetSize(PICTURE, PICTURE)
	c.picture:SetPoint("CENTER", c.face, "CENTER")
	c.round = over:CreateMaskTexture()
	c.round:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	c.round:SetAllPoints(c.picture)
	c.picture:AddMaskTexture(c.round)
	-- Behind the exclamation mark, the head's arrow's make: the weave on the dark face and a light in its middle.
	c.weave = over:CreateTexture(nil, "ARTWORK", nil, 3)
	c.weave:SetTexture(MEDIA .. "HatchDisc" .. PICTURE)
	c.weave:SetSize(PICTURE, PICTURE)
	c.weave:SetPoint("CENTER", c.face, "CENTER")
	c.beam = over:CreateTexture(nil, "ARTWORK", nil, 4)
	c.beam:SetTexture(B.GLOW)
	c.beam:SetSize(CIRCLE * BEAM, CIRCLE * BEAM)
	c.beam:SetPoint("CENTER", c.face, "CENTER")
	c.sign = over:CreateTexture(nil, "OVERLAY")
	c.sign:SetPoint("CENTER", c.face, "CENTER")
	UI.Concentric(c.glow, c.burst, c.face, c.picture, c.weave, c.beam, c.sign)
	-- A light that sweeps along the plate on each beat, kept to the plaque by the weave's mask.
	c.sweep = c.drain.window:CreateTexture(nil, "OVERLAY")
	c.sweep:SetTexture(MEDIA .. "Sheen")
	c.sweep:SetBlendMode("ADD")
	c.sweep:SetSize(TALL * 2.5, TALL)
	c.sweep:AddMaskTexture(c.drain.mask)
	c.sweep:SetAlpha(0)
	local function Words(size, font)
		return UI.Words(over, font(size), WHITE, { wrap = false })
	end
	c.title = Words(TITLE, UI.TitleFont)
	c.under = Words(UNDER, UI.NameFont)
	c.right = Words(RIGHT, UI.TitleFont)
	c.right:SetJustifyH("RIGHT")

	function c:Set(def)
		local tone = def.warn and (def.color or AMBER) or CRIMSON
		UI.Tint(self.drain.fill, tone, 1)
		UI.Tint(self.halo, tone, 1)
		UI.Tint(self.glow, tone, 1)
		UI.Tint(self.burst, tone, 1)
		self.title:SetText(def.title or "")
		self.under:SetText(def.under or "")
		self.right:SetText(def.right or "")
		local pictured = def.icon ~= nil
		self.picture:SetShown(pictured)
		self.sign:SetShown(not pictured)
		self.weave:SetShown(not pictured)
		self.beam:SetShown(not pictured)
		if pictured then
			UI.Tint(self.face, Theme.skin.metal)
			self.picture:SetTexture(def.icon)
			self.picture:SetTexCoord(ZOOM, 1 - ZOOM, ZOOM, 1 - ZOOM)
			self.picture:SetDesaturated(def.dim == true)
		else
			local light = Shy.Top.Make.Light(tone)
			local size = Shy.Top.Make.Sign(self.sign, def.sign or ALERT)
			self.sign:SetSize(size, size)
			UI.Tint(self.sign, light)
			UI.Tint(self.face, light)
			Shy.Skin.WeaveTint(self.weave, light)
			UI.Tint(self.beam, light, BEAM_ALPHA)
		end
		local function Width(fs)
			local w = fs:GetStringWidth()
			if w == nil or issecretvalue(w) then return 0 end
			return math.ceil(w)
		end
		local right = Width(self.right)
		local words = math.max(LEAST, Width(self.title), Width(self.under))
		local plate = 2 * math.ceil((R + INSET + words + (right > 0 and GAP + right or 0) + END + POINT) / 2)
		self.plate:SetWidth(plate)
		self:SetWidth(plate + 2 * R)
		-- The two lines as a block on the plate's middle; what stands at the right on the middle too.
		local under = def.under ~= nil and def.under ~= ""
		self.title:ClearAllPoints()
		self.under:ClearAllPoints()
		self.right:ClearAllPoints()
		self.title:SetPoint("LEFT", self.plate, "LEFT", R + INSET, under and 6 or 0)
		self.under:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -2)
		self.right:SetPoint("RIGHT", self.plate, "RIGHT", -(END + POINT), 0)
		self.under:SetShown(under)
		self.drain:Share(def.share or 1)
		Shy.Top.Make.Look(self.p)
	end
	return c
end

-- Where a place's middle stands, in UIParent's units, and the alert's scale there.
local function Spot(box)
	local x, y = box:GetCenter()
	local k = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * k, y * k, box:GetScale()
end

local function Out(u) return 1 - (1 - u) ^ 3 end
local function In(u) return u ^ 3 end
local function InOut(u) return u < 0.5 and 4 * u ^ 3 or 1 - (2 - 2 * u) ^ 3 / 2 end

-- The alert's middle at x, y (UIParent's units), at a scale: laid only where that is another place or scale (a
-- quiet alert stands still, and is asked this at every frame).
local put = {}
local function Put(x, y, scale)
	if put.x == x and put.y == y and put.scale == scale then return end
	put.x, put.y, put.scale = x, y, scale
	card:SetScale(scale)
	card:ClearAllPoints()
	card:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end
-- A region's alpha, set only when it is another (in the screen's 8-bit steps).
local function Alpha(region, a)
	a = math.floor(a * 255 + 0.5) / 255
	if region.shyAlpha ~= a then
		region.shyAlpha = a
		region:SetAlpha(a)
	end
end

-- A heartbeat: a swell and a fall at the start of each beat, then rest. Returns how far it swells (0 to 1)
-- and how far through the swell it is (0 to 1, nil at rest).
local function Beat(now, def)
	-- (A share that is a secret, your health's, is the game's to lay, never compared here.)
	local plain = def.share ~= nil and not issecretvalue(def.share)
	local period = (plain and def.share < LOW) and QUICK or BEAT
	local u = (now % period) / period
	if u >= SWELL then return 0, nil end
	return math.sin(math.pi * u / SWELL), u / SWELL
end

-- The sweep along the plate, `along` of the way across (nil: none).
local function Sweep(along)
	local sweep = card.sweep
	if not along then
		Alpha(sweep, 0)
		return
	end
	local w = card.plate:GetWidth()
	local span = sweep:GetWidth()
	sweep:ClearAllPoints()
	sweep:SetPoint("LEFT", card.drain, "LEFT", -span + (w + span) * along, 0)
	Alpha(sweep, 0.55 * math.sin(math.pi * along))
end

-- The head's voice: the alarm in the head (a warning, or urgent before it leaves), or none.
local function Voice(def, tone)
	if not def then
		Shy.Notices.Voice("alarm", nil)
		return
	end
	-- (The plate is a bar: as long as its own words, whatever was said before it.)
	Shy.Notices.Voice("alarm", { priority = VOICE, glyph = def.sign or ALERT, color = tone, fill = tone, share = def.share, pulse = true, title = def.title, titleColor = WHITE,
		under = def.under, right = def.right })
end

-- Every frame while there is one (its own clock: the alert is hidden while the head speaks for it).
local function Tick()
	if not stage or stage == "warn" then
		if driver then driver:Hide() end
		return
	end
	if driver and not driver:IsShown() then driver:Show() end
	local now = GetTime()
	local t = now - since
	-- A quiet alert stands where it ends and only its light beats, slowly: laid as it is raised or read again
	-- (quiet.fresh, Show), then looked at QUIET times a second, and not at all while it stands unseen.
	if stage == "quiet" and not quiet.fresh then
		if unseen then
			driver:Hide()
			return
		end
		if now - quiet.at < 1 / quiet.RATE then return end
	end
	quiet.fresh, quiet.at = false, now
	Alpha(card.burst, 0)
	Sweep(nil)
	local x1, y1, s1 = Spot(to)
	if stage == "home" then
		-- Back up into the head, quickly, and gone.
		local x0, y0, s0 = Spot(head)
		local u = math.min(1, t / HOME)
		local e = In(u)
		Put(back.x + (x0 - back.x) * e, back.y + (y0 - back.y) * e, back.scale + (s0 - back.scale) * e)
		card:SetAlpha(1 - u)
		if u >= 1 then
			stage = nil
			card:Hide()
		end
		return
	end
	local def = alarms[up]
	if stage == "quiet" then
		local b = Beat(now, def)
		Put(x1, y1, s1)
		Alpha(card.halo, 0.25 + 0.3 * b)
		Alpha(card.glow, 0.55 + 0.45 * b)
		return
	end
	-- Urgent: the head is red for HOLD, then the alert leaves it.
	local x0, y0, s0 = Spot(head)
	t = t - HOLD
	if t < 0 then return end
	if not card:IsShown() then
		Voice(nil)
		card:SetAlpha(1)
		card:Show()
	end
	if t < TRAVEL then
		local e = InOut(t / TRAVEL)
		Put(x0 + (x1 - x0) * e, y0 + (y1 - y0) * e, s0 + (s1 * OVER - s0) * e)
		Alpha(card.halo, 1)
		Alpha(card.glow, 1)
	elseif t < TRAVEL + SETTLE then
		-- Landing: it settles to its size and a flash rings out of the circle.
		local u = (t - TRAVEL) / SETTLE
		Put(x1, y1, s1 * (OVER - (OVER - 1) * Out(u)))
		Alpha(card.burst, 1 - u)
		local reach = CIRCLE * (1.2 + 2.2 * Out(u))
		card.burst:SetSize(reach, reach)
	else
		local b, along = Beat(now, def)
		Put(x1, y1, s1 * (1 + 0.035 * b))
		Alpha(card.halo, 0.45 + 0.55 * b)
		Alpha(card.glow, 0.55 + 0.45 * b)
		Sweep(along)
	end
end

-- Off the screen: an alert standing under your character goes back up into the head first.
local function Away()
	Voice(nil)
	if card:IsShown() and stage ~= "home" then
		local x, y = card:GetCenter()
		local scale = card:GetScale()
		local k = card:GetEffectiveScale() / UIParent:GetEffectiveScale()
		back = { x = x * k, y = y * k, scale = scale }
		stage, since = "home", GetTime()
		if driver then driver:Show() end
		return
	end
	if stage ~= "home" then
		stage = nil
		card:Hide()
	end
end

local function Show()
	if not card then return end
	local best, rank
	for id, def in pairs(alarms) do
		local p = def.priority or 0
		if not rank or p > rank then best, rank = id, p end
	end
	local was = up
	up = best
	local def = up and alarms[up]
	if not def or HUD.IsUnlocked() then
		Away()
		return
	end
	local now = def.fly and "fly" or def.warn and "warn" or "quiet"
	if up ~= was or now ~= stage then
		-- A warning turned urgent goes on from the head as it is; anything else begins now.
		if now == "fly" and stage == "warn" and up == was then since = GetTime() - HOLD / 2 else since = GetTime() end
		if now ~= "quiet" then card:Hide() end
		stage = now
	end
	card:Set(def)
	if stage == "warn" then
		Voice(def, def.color or AMBER)
		card:Hide()
	elseif stage == "fly" then
		if not card:IsShown() then Voice(def, CRIMSON) end
	else
		Voice(nil)
		local strength
		if def.alpha then strength = def.alpha() end
		-- (A strength the game keeps to itself is handed on as it is, and the alert beats: it may well show.)
		local plain = not issecretvalue(strength)
		if plain and strength == nil then strength = 1 end
		unseen = plain and strength == 0
		card:SetAlpha(strength)
		card:Show()
	end
	quiet.fresh = true
	Tick()
end

function A.Up()
	return up
end

function A.Covers(what)
	local def = up and alarms[up]
	return def ~= nil and def.covers == what
end

-- Shown again, and told on the bus when what is up, or what it covers, changed.
local said
local function Tell()
	Show()
	local def = up and alarms[up]
	local now = (up or "") .. "|" .. tostring(def and def.covers)
	if now ~= said then
		said = now
		Shy:Fire("SHY_ALARM")
	end
end

function A.Raise(id, def)
	alarms[id] = def
	Tell()
end

function A.Update(id)
	if alarms[id] then Tell() end
end

function A.Clear(id)
	if not alarms[id] then return end
	alarms[id] = nil
	Tell()
end

-- The end as layout mode shows it: the alert at the place's size.
local function Sample(parent)
	local c = Card(parent)
	c:Set(SAMPLE)
	c.halo:SetAlpha(0.5)
	return c
end

local function Build()
	if card then return end
	-- It starts in the head and ends under your character.
	head = Shy.Notices.Plate():GetParent()
	local probe = Sample(UIParent)
	local w, h = probe:GetWidth(), probe:GetHeight()
	probe:Hide()
	to = HUD.Create({
		id = "shy.alarm.end", title = "Alert end", width = w, height = h, point = { "CENTER", "CENTER", 0, -140 },
		shown = function() return false end,
	})
	Sample(to):SetPoint("CENTER")
	card = Card(UIParent)
	card:SetFrameStrata("DIALOG")
	card:Hide()
	driver = CreateFrame("Frame")
	driver:SetScript("OnUpdate", Shy.Clocked("alarm: frame", Tick))
	Shy:On("SHY_HUD_LAYOUT", Show)
	Shy:On("SHY_THEME", function() Shy.Top.Make.Look(card.p) end)
	Show()
end

Shy:On("SHY_HEAD", Build)
