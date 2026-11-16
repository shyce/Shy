-- ShyBuffs: your buffs and debuffs. What matters in a fight stands on your frame; the rest waits beside the minimap.
-- In a fight the game keeps what an aura is to itself, so every icon is drawn by the game's own aura
-- container (Blizzard_AuraContainer): we say which auras go where and what an icon is made of.
-- A container's buttons can't be touched while auras are secret: settings wait for the fight to end (ns.WhenFree).

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyBuffs\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Buffs",
	category = "combat",
	icon = MEDIA .. "ShyBuffs",
	smallIcon = MEDIA .. "ShyBuffsSmall",
	savedVariables = "ShyBuffsDB",
	defaults = {
		shelf = true,          -- long buffs beside the minimap
		look = "run",          -- how they stand there: "run", "pills", "bars" or "watch" (Shelf.lua)
		debuffs = true,        -- every debuff on you in a row under them
		frames = true,         -- buffs and debuffs on the unit frames
		missing = true,        -- what you lack that someone with you can cast
		size = 32,             -- an icon beside the minimap
		-- Learned while auras can be read, by spell: buffs that never run out.
		known = { forever = {} },
	},
	keep = { known = true },
})
ns.T = T

local started

-- Reported once: a container's refusals can't all be foreseen from its source.
local told
function ns.Try(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not told then
		told = true
		geterrorhandler()(err)
	end
	return ok
end

-- The game hands auras over: no fight, and no place that keeps them.
function ns.Free()
	return not InCombatLockdown() and not C_Secrets.ShouldAurasBeSecret()
end

local jobs, order = {}, {}
local function Run()
	if not ns.Free() then return end
	local todo, keys = jobs, order
	jobs, order = {}, {}
	for _, key in ipairs(keys) do ns.Try(todo[key]) end
end

-- Runs fn now, or once auras can be read again. One job per key: a repeat replaces the queued one.
function ns.WhenFree(key, fn)
	if ns.Free() then
		ns.Try(fn)
		return
	end
	if not jobs[key] then order[#order + 1] = key end
	jobs[key] = fn
end

local waiter = CreateFrame("Frame")
waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
waiter:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
waiter:SetScript("OnEvent", function() C_Timer.After(0, Run) end)

-- An aura icon's tooltip is the game's own and can't be replaced; it can be given the graphite of ours.
local function DressTip()
	local fill, edge = Shy.UI.colors.tip, Shy.UI.colors.border
	ns.Try(AuraContainerInbound.SetTooltipNineSlice, {
		layoutName = "TooltipDefaultLayout",
		centerColor = CreateColor(fill[1], fill[2], fill[3], fill[4] or 1),
		borderColor = CreateColor(edge[1], edge[2], edge[3], 1),
	})
end
Shy:On("SHY_THEME", function() if started then DressTip() end end)

-- Applies every setting. Safe at any time.
function T:Apply()
	if not started then return end
	ns.Blizzard.Apply()
	ns.Shelf.Apply()
	ns.Plates.Apply()
	ns.Missing.Apply()
	if ns.Grid then ns.Grid.Apply() end
	if ns.RefreshOptions then ns.RefreshOptions() end
end

-- Whether rows of icons stand on ShyFrames' frames (ShyFrames keeps a housing under your target's then).
function T:Rows()
	return started and ns.Plates.On() and true or false
end

-- Which unit's rows of icons the mouse is on; on the shelf, the box too ({ point, box, ... }).
function T:AuraUnderMouse()
	if not started then return nil end
	local unit, at = ns.Shelf.Under()
	if unit then return unit, at end
	return ns.Plates.Under()
end

function T:OnLoad()
	-- A saved bars switch is read as the shelf's bars look.
	if self.db.bars ~= nil then
		if self.db.bars == true then self.db.look = "bars" end
		self.db.bars = nil
	end
	-- The shelf's icons grew: a save still at the old default takes the new one, once.
	if not self.db.grown then
		if self.db.size == 26 then self.db.size = 32 end
		self.db.grown = true
	end
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	-- After every addon's login: ShyFrames has made its frames by then.
	Shy:On("SHY_LOGIN", function()
		started = true
		DressTip()
		ns.Learn.Start()
		ns.Shelf.Start()
		ns.Plates.Start()
		ns.Missing.Start()
		ns.Caster.Start()
		if ns.Grid then ns.Grid.Start() end
		T:Apply()
	end)
end

SLASH_SHYBUFFS1 = "/shybuffs"
SLASH_SHYBUFFS2 = "/sbuffs"
SlashCmdList.SHYBUFFS = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "move" then
		Shy.HUD.SetUnlocked(true)
	elseif cmd == "who" then
		Shy.UI.ShowCopyBox("ShyBuffs: who cast a buff", ns.Caster.Report())
	else
		T:Print("commands:")
		print("  /shybuffs  - open options")
		print("  /shybuffs move  - open layout mode")
		print("  /shybuffs who  - which buff the tooltip last found (hover one first)")
	end
end
