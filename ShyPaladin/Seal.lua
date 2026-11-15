-- The seal in place, and its color on ShyDock's swing bar.
-- The color is the game's to show. In a fight an addon can't read auras at all (even a slot walk is
-- refused), so the bar wears an aura container, the frames the game draws secret auras with: one group per
-- kind of seal admitting only that kind's spell IDs, its one frame a hatch in the kind's color laid over
-- the fill (Swing.lua's Overlay). The game shows the frame whose seal is up and hides it when the seal
-- goes, so a cancelled seal loses its color on the spot, in a fight too. Which seal is up is also followed
-- for Twist.lua and the report: from the auras where the game lets them be read
-- (C_Secrets.ShouldSpellAuraBeSecret, seal by seal) and from your casts and their 30 seconds while it keeps
-- them secret (Judgement doesn't spend a seal on this client; Seals.lua: every seal, by kind). ShyPaladin's
-- one module of the swing bar (ShyDock's T:AddSwingModule) lives here; Twist.lua's light rides it.

local ADDON, ns = ...
local T = ns.T
local Skin = Shy.Skin

local S = {}
ns.Seal = S

local SEAL_TIME = 30          -- a seal's duration (every rank's, in the client's tables)

-- Hand-picked: fixed for every player, independent of the theme, and clear of the bar's own white, red
-- and gold, and of the steel and the mana blue a stone or an oil gives it.
S.COLORS = {
	righteousness = { 1.00, 0.95, 0.35 },   -- lemon
	command       = { 1.00, 0.58, 0.22 },   -- amber
	crusader      = { 0.45, 0.95, 0.85 },   -- turquoise: the faster swing
	fury          = { 1.00, 0.32, 0.62 },   -- rose
	justice       = { 0.70, 0.50, 1.00 },   -- violet
	light         = { 0.55, 0.95, 0.45 },   -- green
	wisdom        = { 0.30, 0.68, 1.00 },   -- cerulean
	martyrdom     = { 0.64, 0.38, 0.50 },   -- dusky mauve: the seal that bleeds you
}
local OTHER = { 0.85, 0.80, 0.95 }   -- a seal the table doesn't know

S.kind, S.ends = nil, nil   -- the seal in place, and when it runs out
S.groups = {}               -- per kind of seal: { kind, ids = { [spell] = true }, color, make }
local up = false            -- the swing row shows
local watchers = {}         -- S.Watch
local run = 0               -- expiry timers set so far: only the latest counts
local swing                 -- the swing bar's handle (Overlay), once joined
local attached = false      -- the main-hand bar exists
local over                  -- the handle's frame over the fill
local events

function S.Color(kind)
	return S.COLORS[kind] or OTHER
end

-- fn(kind, was) when the seal in place changes: kind is nil when it ran out or went; was is the seal a
-- cast replaced while that one still ran, nil for one read from the auras or run out.
function S.Watch(fn)
	watchers[#watchers + 1] = fn
end

-- A group's frame: a hatch in the seal's color over the whole fill (the frame itself is a point in the
-- container's layout).
local function Maker(group)
	return function(button)
		local tex = button:CreateTexture(nil, "ARTWORK")
		Skin.Hatch(tex)
		tex:SetAllPoints(over)
		tex:SetVertexColor(group.color[1], group.color[2], group.color[3])
		return tex
	end
end

local function Build()
	local byKind = {}
	for spell, kind in pairs(ns.seals) do
		local group = byKind[kind]
		if not group then
			group = { kind = kind, ids = {}, color = S.Color(kind) }
			byKind[kind] = group
			S.groups[#S.groups + 1] = group
		end
		group.ids[spell] = true
	end
	table.sort(S.groups, function(a, b) return a.kind < b.kind end)
	local c = CreateFrame("AuraContainer", nil, over, "CustomAuraContainerTemplate")
	c:SetPoint("LEFT")
	c:SetFlowLayoutAnchorPoint("LEFT")
	c:SetEnabled(false)
	c:Hide()
	for _, group in ipairs(S.groups) do
		group.make = Maker(group)
		c:AddAuraGroup("seal-" .. group.kind, "HELPFUL", {
			maxFrameCount = 1, initializeFrame = group.make, candidateFilters = { includeSpellIDs = group.ids },
			sortMethod = AuraContainerSortMethod.Default, layout = { elementWidth = 1, elementHeight = 1 },
		})
	end
	S.container = c
end

local function Show()
	local c = S.container
	if not c then return end
	if up and T.db.color then
		c:SetUnit("player")
		c:SetEnabled(true)
		c:Show()
	else
		c:SetEnabled(false)
		c:Hide()
	end
end

-- The container needs the bar and the handle both: whichever comes second builds it.
local function Ready()
	if over or not (attached and swing) then return end
	over = swing.Overlay()
	Build()
	Show()
end

local Set

local function Expire(this)
	if run == this and S.kind then Set(nil, nil) end
end

function Set(kind, ends, was)
	local changed, retimed = kind ~= S.kind, ends ~= S.ends
	S.kind, S.ends = kind, ends
	if retimed then
		run = run + 1
		if ends then
			local this = run
			-- An end already past (an aura read as you log in) expires on the next frame.
			C_Timer.After(math.max(0, ends - GetTime() + 0.05), function() Expire(this) end)
		end
	end
	if not changed then return end
	for _, fn in ipairs(watchers) do xpcall(fn, geterrorhandler(), kind, was) end
end

-- The auras, seal by seal, where the game lets them be read: GetPlayerAuraBySpellID answers nil for a
-- secret aura too, so a "none" counts only when no seal is secret right now.
local function Read()
	local kind, ends, sure = nil, nil, true
	for spell, k in pairs(ns.seals) do
		if C_Secrets.ShouldSpellAuraBeSecret(spell) then
			sure = false
		else
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
			if issecretvalue(aura) or aura then
				kind = k
				local at = not issecretvalue(aura) and aura.expirationTime
				if at and not issecretvalue(at) and at > 0 then
					ends = at
				else
					ends = k == S.kind and S.ends or GetTime() + SEAL_TIME
				end
				break
			end
		end
	end
	if kind then
		Set(kind, ends)
	elseif sure then
		Set(nil, nil)
	end
end

local function Cast(spell)
	local kind = ns.seals[spell]
	if not kind then return end
	local now = GetTime()
	local was = S.kind ~= kind and S.ends and S.ends > now and S.kind or nil
	Set(kind, now + SEAL_TIME, was)
end

local function OnEvent(_, event, a, b, c)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if not issecretvalue(c) then Cast(c) end
	else
		Read()
	end
end

local WATCHED = { "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

local function Follow(now)
	if now then
		events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
		events:RegisterUnitEvent("UNIT_AURA", "player")
		for _, event in ipairs(WATCHED) do events:RegisterEvent(event) end
		Read()
	else
		events:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		events:UnregisterEvent("UNIT_AURA")
		for _, event in ipairs(WATCHED) do events:UnregisterEvent(event) end
		Set(nil, nil)
	end
end

-- The swing bar's module: the container is the seal's; the light and the flash are Twist.lua's.
local module = {}

function module.Attach(bar)
	attached = true
	ns.Twist.Attach(bar)
	Ready()
end

function module.Shown(shown)
	up = shown and true or false
	ns.Twist.Shown(up)
	Follow(up)
	Show()
end

function S.Apply()
	Show()
end

-- What the seal follows, for the copy box.
function S.Report()
	return ("Swing bar: %s  seal: %s (%s s left)  colors the bar: %s (%s)  auras secret now: %s"):format(
		swing and (up and "showing" or "hidden") or "none (ShyDock)", tostring(S.kind),
		S.ends and ("%.0f"):format(S.ends - GetTime()) or "-", tostring(T.db.color),
		S.container and (S.container:IsShown() and "container up" or "container down") or "no container",
		tostring(C_Secrets.ShouldAurasBeSecret()))
end

function S.Start()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", OnEvent)
	local dock = Shy.addons.Dock
	if dock and dock.AddSwingModule then swing = dock:AddSwingModule(module) end
	Ready()
end
