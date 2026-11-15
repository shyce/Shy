-- Your shout: Battle Shout and Commanding Shout, timed. When one is down or about to run out and you have the
-- rage to shout it, Openings lights its button (the cooldown manager's or the action bar's) as it lights an
-- opening; when it stands on no button you can see, a small box shows it with its name instead.
-- Out of a fight the time is read from your buff. In one the game won't let an addon read buffs at all, so it
-- is timed from your cast: as long as it lasted for you last time it was read (talents included), else the
-- client's own duration (Data/Spells.lua's `seconds`).

local ADDON, ns = ...
local T = ns.T
local UI, Kit = Shy.UI, ns.Kit

local S = {}
ns.Shout = S

local SIZE, GAP, NOTE = 36, 10, 16
local SOON_FIGHTING = 3      -- in a fight, light it this many seconds before it runs out
local SHOUTS = {
	{ key = "battleShout", option = "battle" },
	{ key = "commandingShout", option = "commanding" },
}

local ends = {}              -- key -> when it runs out (GetTime), 0 when down, nil when not known yet
local lasts = {}             -- key -> how long it lasted for you when last read
local byID = {}
for _, s in ipairs(SHOUTS) do
	for _, id in ipairs(ns.spells[s.key].ranks) do byID[id] = s.key end
end
local box, any = nil, false
local icons = {}
local wantedWas = ""

local function Fighting()
	return InCombatLockdown() or UnitAffectingCombat("player") == true
end

-- Out of a fight: the buff as it is.
local function Read(key)
	for _, id in ipairs(ns.spells[key].ranks) do
		local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
		if issecretvalue(aura) then return end
		if aura then
			local e, d = aura.expirationTime, aura.duration
			if issecretvalue(e) or issecretvalue(d) then return end
			ends[key] = e == 0 and math.huge or e
			if d and d > 0 then lasts[key] = d end
			return
		end
	end
	ends[key] = 0
end

local function ReadAll()
	if Fighting() then return end
	for _, s in ipairs(SHOUTS) do Read(s.key) end
end

-- The shouts that want doing now, as keys.
function S.Wanted()
	local list = {}
	if not T.db.shout.shown or UnitIsDeadOrGhost("player") then return list end
	local soon = Fighting() and SOON_FIGHTING or T.db.shout.warnSeconds
	for _, s in ipairs(SHOUTS) do
		local id = T.db.shout[s.option] and ns.Known(s.key)
		local left = (ends[s.key] or 0) - GetTime()
		if id and left <= soon and C_Spell.IsSpellUsable(id) == true then list[#list + 1] = s.key end
	end
	return list
end

-- Openings has lit what it could; `shown` holds the keys lit on a button you can see. The rest are the box's.
function S.Placed(shown)
	if not box then return end
	local n = 0
	for _, key in ipairs(S.Wanted()) do
		if not shown[key] then
			n = n + 1
			local icon, id = icons[n], ns.Known(key)
			icon:SetSpell(id)
			icon.note:SetText(C_Spell.GetSpellName(id) or "")
			icon:Show()
		end
	end
	for i = n + 1, #icons do icons[i]:Hide() end
	local width = n * SIZE + math.max(0, n - 1) * GAP
	for i = 1, n do
		icons[i]:ClearAllPoints()
		icons[i]:SetPoint("TOPLEFT", box, "TOP", -width / 2 + (i - 1) * (SIZE + GAP), 0)
	end
	any = n > 0
	Shy.HUD.Update(box)
end

-- Openings looks again only when what is wanted has changed.
local function Check()
	local now = table.concat(S.Wanted(), ",")
	if now ~= wantedWas then
		wantedWas = now
		ns.Openings.Update()
	end
end

function ns.SetupShout()
	local wide = #SHOUTS * SIZE + (#SHOUTS - 1) * GAP + 2 * 40   -- room for both names under them
	box = Shy.HUD.Create({
		id = "shywarrior-shout",
		title = "Shout reminder",
		width = wide,
		height = SIZE + NOTE,
		point = { "CENTER", "CENTER", 0, -140 },
		shown = function() return any end,
	})
	for i = 1, #SHOUTS do
		local icon = Kit.Icon(box, SIZE)
		UI.Ink(icon.note, UI.colors.alert)
		local beat = icon.icon:CreateAnimationGroup()
		beat:SetLooping("BOUNCE")
		local fade = beat:CreateAnimation("Alpha")
		fade:SetFromAlpha(1)
		fade:SetToAlpha(0.45)
		fade:SetDuration(0.8)
		fade:SetSmoothing("IN_OUT")
		beat:Play()
		local c = UI.colors.alert
		icon:Glow(c[1], c[2], c[3], 0.5)
		icon:Hide()
		icons[i] = icon
	end

	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "PLAYER_DEAD",
		"PLAYER_UNGHOST", "PLAYER_ALIVE" }) do
		events:RegisterEvent(event)
	end
	events:RegisterUnitEvent("UNIT_AURA", "player")
	events:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
	events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	events:SetScript("OnEvent", function(_, event, _, _, spell)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			if spell == nil or issecretvalue(spell) or not byID[spell] then return end
			local key = byID[spell]
			ends[key] = GetTime() + (lasts[key] or ns.spells[key].seconds)
		else
			ReadAll()
		end
		Check()
	end)
	-- A shout running out sends no event.
	C_Timer.NewTicker(1, function()
		ReadAll()
		Check()
	end)
	table.insert(ns.refreshers, function()
		ReadAll()
		wantedWas = nil
		Check()
	end)
	ReadAll()
	Check()
end
