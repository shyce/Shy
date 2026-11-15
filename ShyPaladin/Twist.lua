-- Seal twisting on ShyDock's swing bar, with Unsealed Wrath: each main-hand swing stores the seal in place
-- (one the talent echoes) as an Echo for a while; the first swing under another seal, or none, spends it.
-- While the next swing would spend one (an Echo stored, another seal in place), a light in your color
-- breathes at the main-hand bar's right end; the swing that spends it flashes the bar and rings
-- (T.db.twist: "off", "light", or the sound's key).
-- The seal in place is Seal.lua's (S.Watch tells of a change); the Echo auras are read wherever the game
-- lets them be, Echo by Echo, and followed by the swings where it doesn't (Seals.lua: the talent, its
-- Echoes and how long one lasts).

local ADDON, ns = ...
local T = ns.T
local Theme = Shy.Theme

local TW = {}
ns.Twist = TW

TW.SOUNDS = {
	{ key = "ding", text = "Light and a ding", kit = SOUNDKIT.MAP_PING },
	{ key = "chime", text = "Light and a chime", kit = SOUNDKIT.UI_BNET_TOAST },
	{ key = "bell", text = "Light and a bell", kit = SOUNDKIT.READY_CHECK },
}
local PIP_W = 10              -- the light's width at the bar's end
local BREATH = 0.9            -- seconds for the light to swell or fade
local FLASH, FLASH_TIME = 0.9, 0.35

local MAIN = Enum.PlayerSwingType.MainHand
local ECHOED = {}             -- kind -> true for the seals Unsealed Wrath echoes
for kind in pairs(ns.twist.echoes) do ECHOED[kind] = true end

local stored, ends            -- the kind the swings have stored, and when it runs out (GetTime)
local echo                    -- the kind the next swing spends: stored, while another seal is in place
local asked = 0               -- the last expiry timer asked for (an older one finds itself stale)
local up = false              -- the swing row shows
local on = false              -- the talent known, the setting on and the row showing
local pip, breath, lands, flash, events

local function Talent()
	return C_SpellBook.IsSpellKnown(ns.twist.talent) == true
end

function TW.Play(key)
	for _, sound in ipairs(TW.SOUNDS) do
		if sound.key == key then PlaySound(sound.kit, "Master") end
	end
end

local function Show()
	if not pip then return end
	local now = on and echo ~= nil
	if now == pip:IsShown() then return end
	pip:SetShown(now)
	if now then breath:Play() else breath:Stop() end
end

-- What the next swing spends, from what is stored and the seal in place now; the light follows.
local Settle
local function Expire(mine)
	if mine == asked then Settle() end
end

function Settle()
	local now = GetTime()
	if stored and ends and ends <= now then stored, ends = nil, nil end
	local seal = ns.Seal and ns.Seal.kind
	echo = (stored and stored ~= seal) and stored or nil
	if stored and ends then
		asked = asked + 1
		local mine = asked
		C_Timer.After(ends - now + 0.05, function() Expire(mine) end)
	end
	Show()
end

-- Stored for the talent's time from now.
local function Store(kind)
	if kind and ECHOED[kind] then
		stored, ends = kind, GetTime() + ns.twist.seconds
	else
		stored, ends = nil, nil
	end
end

-- The Echo auras, where the game lets them be read (C_Secrets.ShouldSpellAuraBeSecret, each; a secret
-- one reads as nil): a "none" counts only when every one could be read. An aura's own end is taken when it
-- can be read; else the time the swings gave it stands.
local function Read()
	local found, at, sure = nil, nil, true
	for kind, spell in pairs(ns.twist.echoes) do
		if C_Secrets.ShouldSpellAuraBeSecret(spell) then
			sure = false
		else
			local aura = C_UnitAuras.GetPlayerAuraBySpellID(spell)
			if issecretvalue(aura) or aura then
				found = kind
				local last = not issecretvalue(aura) and aura.expirationTime
				at = type(last) == "number" and not issecretvalue(last) and last > 0 and last or nil
			end
		end
	end
	if found then
		if found ~= stored or at then stored, ends = found, at or ends or GetTime() + ns.twist.seconds end
	elseif sure then
		stored, ends = nil, nil
	else
		return
	end
	Settle()
end

-- The seal in place changed (Seal.lua): what is stored now waits for the next swing, or is its own again.
local function Replaced()
	Settle()
end

local function OnEvent(_, event, a, b)
	if event == "PLAYER_SWING" then
		if not issecretvalue(b) and b == MAIN then
			-- This swing spends what another seal stored, and stores the seal in place.
			local spent = echo ~= nil
			Store(ns.Seal and ns.Seal.kind)
			Settle()
			if spent and on and lands then
				flash:Stop()
				flash:Play()
				TW.Play(T.db.twist)
			end
		end
	elseif event == "SPELLS_CHANGED" then
		TW.Apply()
	else
		Read()
	end
end

local WATCHED = { "PLAYER_SWING", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }

function TW.Apply()
	if not events then return end
	local now = up and T.db.twist ~= "off" and Talent()
	if now ~= on then
		on = now
		if on then
			events:RegisterUnitEvent("UNIT_AURA", "player")
			for _, event in ipairs(WATCHED) do events:RegisterEvent(event) end
			Read()
		else
			events:UnregisterEvent("UNIT_AURA")
			for _, event in ipairs(WATCHED) do events:UnregisterEvent(event) end
		end
	end
	if pip then
		local r, g, b = Theme.Accent()
		pip:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
		lands:SetColorTexture(r, g, b)
	end
	Show()
end

-- The swing bar's main-hand bar (Seal.lua's module hands it on): the light and the flash are its.
function TW.Attach(bar)
	local clip = CreateFrame("Frame", nil, bar)
	clip:SetAllPoints(bar)
	clip:SetClipsChildren(true)
	clip:SetFrameLevel(bar:GetFrameLevel() + 3)
	pip = clip:CreateTexture(nil, "OVERLAY")
	pip:SetColorTexture(1, 1, 1)
	pip:SetBlendMode("ADD")
	pip:SetPoint("TOPRIGHT")
	pip:SetPoint("BOTTOMRIGHT")
	pip:SetWidth(PIP_W)
	pip:Hide()
	breath = pip:CreateAnimationGroup()
	breath:SetLooping("BOUNCE")
	local swell = breath:CreateAnimation("Alpha")
	swell:SetFromAlpha(0.35)
	swell:SetToAlpha(1)
	swell:SetDuration(BREATH)
	swell:SetSmoothing("IN_OUT")
	lands = clip:CreateTexture(nil, "OVERLAY", nil, 1)
	lands:SetAllPoints(clip)
	lands:SetBlendMode("ADD")
	lands:SetAlpha(0)
	flash = lands:CreateAnimationGroup()
	local fade = flash:CreateAnimation("Alpha")
	fade:SetFromAlpha(FLASH)
	fade:SetToAlpha(0)
	fade:SetDuration(FLASH_TIME)
	fade:SetSmoothing("OUT")
	TW.art = { pip = pip, lands = lands, flash = flash }
	TW.Apply()
end

function TW.Shown(shown)
	up = shown and true or false
	TW.Apply()
end

-- What the twist follows, for the copy box.
function TW.Report()
	local lines = {
		ns.Seal and ns.Seal.Report() or "",
		("Twist: talent known: %s  setting: %s  watching: %s  stored: %s for %s s  echo waiting: %s"):format(tostring(Talent()),
			tostring(T.db.twist), tostring(on), tostring(stored), ends and ("%.1f"):format(ends - GetTime()) or "-", tostring(echo)),
	}
	-- Secrecy: 0 never, 1 always, 2 in restricted situations (a fight); the aura's is what the color and
	-- the Echo can read, the cast's what the following falls back on.
	for spell, kind in pairs(ns.seals) do
		if C_SpellBook.IsSpellKnown(spell) then
			lines[#lines + 1] = ("%s %d: aura %s, secret now %s; casts %s"):format(kind, spell,
				tostring(C_Secrets.GetSpellAuraSecrecy(spell)), tostring(C_Secrets.ShouldSpellAuraBeSecret(spell)),
				tostring(C_Secrets.GetSpellCastSecrecy(spell)))
		end
	end
	for kind, spell in pairs(ns.twist.echoes) do
		lines[#lines + 1] = ("echo of %s %d: aura %s, secret now %s"):format(kind, spell,
			tostring(C_Secrets.GetSpellAuraSecrecy(spell)), tostring(C_Secrets.ShouldSpellAuraBeSecret(spell)))
	end
	return table.concat(lines, "\n")
end

function TW.Start()
	events = CreateFrame("Frame")
	events:SetScript("OnEvent", OnEvent)
	-- Always: a talent learned or a respec turns the twist on or off.
	events:RegisterEvent("SPELLS_CHANGED")
	Shy:On("SHY_THEME", TW.Apply)
	if ns.Seal then ns.Seal.Watch(Replaced) end   -- guarded: a newly added file isn't loaded until the client restarts
	TW.Apply()
end
