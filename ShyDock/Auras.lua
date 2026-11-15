-- Buffs and debuffs aligned to ShySkin's minimap panel.
--
--     [b][b][b][b][b]|<|  +---- minimap ----
--     [d][d]              |
--
-- Buffs: top on the panel's top line, right end one seam left of the panel.
-- Debuffs: under the buff rows in use, in the buffs' columns. One row is always
-- counted, so they only move when the buffs wrap.
--
-- Both are Edit Mode frames, adopted into Shy.HUD and placed with plain
-- SetPoint so no Edit Mode code runs from addon code. One moved in Edit Mode
-- stays the player's until the next setup (ns.char.loose). Only rows growing
-- left and wrapping down (the default) are handled; others are left alone.
-- Registers itself with Arrange.lua (A.Also), which never calls this file directly.

local ADDON, ns = ...
local HUD = Shy.HUD

local S = {}
ns.Auras = S

local GAP = ns.Console.SEAM
local CELL = 40     -- row height: icon plus duration (BuffFrame.lua, HORIZONTAL_LAYOUT_AURA_HEIGHT)
local FOLD = 15     -- width of the collapse arrow at the row's right end (BuffFrame.xml)

local buffs, debuffs
local rows = 1      -- buff rows in use
local soon
local layoutWas     -- BuffFrame and DebuffFrame container layout last seen

-- ShySkin's minimap panel as left, bottom, right, top; nil without one.
local function Panel()
	local skin = Shy.addons.Skin
	if not (skin and skin.MinimapPanel) then return nil end
	return skin:MinimapPanel()
end

-- The default orientation: icons growing left, wrapping down.
local function Leftward(frame)
	local container = frame.AuraContainer
	return container.isHorizontal == true and not container.addIconsToRight and not container.addIconsToTop
end

-- Buff rows in use. ConsolidatedBuffs is laid out as the first icon while shown (BuffFrameMixin:UpdateGridLayout).
local function Rows()
	local shown = BuffFrame.ConsolidatedBuffs:IsShown() and 1 or 0
	for _, button in ipairs(BuffFrame.auraFrames) do
		if button:IsShown() then shown = shown + 1 end
	end
	return math.max(1, math.ceil(shown / BuffFrame.AuraContainer.iconStride))
end

local function Near(a, b)
	if a == nil or b == nil then return a == b end
	return a[1] == b[1] and a[2] == b[2] and math.abs(a[3] - b[3]) < 0.05 and math.abs(a[4] - b[4]) < 0.05
end

local function Give(box, home)
	if not Near(box.given, home) then HUD.SetHome(box, home) end
end

-- A frame's right and top in screen units; nil when secret.
local function Corner(frame)
	local right, top = frame:GetRight(), frame:GetTop()
	if right == nil or issecretvalue(right) or issecretvalue(top) then return nil end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return right * scale, top * scale
end

local function Stand()
	if not buffs then return end
	local width, height = UIParent:GetWidth(), UIParent:GetHeight()
	local left, _, _, top = Panel()
	local on = left ~= nil and ns.Arrange.On() and Leftward(BuffFrame)

	local home
	if on and not ns.char.loose.buffs then
		home = { "TOPRIGHT", "TOPRIGHT", left - GAP - width, top - height }
	end
	Give(buffs, home)

	-- Debuffs follow the buffs' actual position: the player may have moved them.
	local under
	if on and not ns.char.loose.debuffs and Leftward(DebuffFrame) then
		local right, roof = Corner(BuffFrame)
		if right then
			local container = BuffFrame.AuraContainer
			local scale = container.iconScale or 1
			under = { "TOPRIGHT", "TOPRIGHT", right - FOLD * scale - width,
				roof - rows * (CELL + container.iconPadding) * scale - height }
		end
	end
	Give(debuffs, under)
end

-- Next frame, once. Never post-hook BuffFrame from UNIT_AURA: that taints the cooldown manager's aura map.
function S.Soon()
	if soon then return end
	soon = true
	C_Timer.After(0, function()
		soon = nil
		Stand()
	end)
end

local function Count()
	local now = Rows()
	if now == rows then return false end
	rows = now
	return true
end

-- The two containers' layout as last seen, compared field by field (it is looked at every frame: no text is
-- made for it). Returns true when it changed.
local LAYOUT = { "addIconsToRight", "iconScale", "iconPadding", "isHorizontal" }
local function Differs(container, at)
	local changed = false
	for i, key in ipairs(LAYOUT) do
		local v = container[key]
		if layoutWas[at + i] ~= v then
			layoutWas[at + i] = v
			changed = true
		end
	end
	return changed
end
local function LayoutChanged()
	layoutWas = layoutWas or {}
	local buffsMoved = Differs(BuffFrame.AuraContainer, 0)
	return Differs(DebuffFrame.AuraContainer, #LAYOUT) or buffsMoved
end

-- Runs from a ticker only, never from BuffFrame during UNIT_AURA (that taints the cooldown manager).
local function Watch()
	if Count() then S.Soon() end
	if LayoutChanged() then S.Soon() end
end

local function Adopt(frame, key, title)
	return HUD.Adopt(frame, {
		id = "shydock-" .. key, title = title, editMode = true, plain = true,
		-- Moved in Edit Mode: drop its home without re-placing it mid-drag.
		taken = function(box)
			ns.char.loose[key] = true
			box.given, box.placed = nil, nil
		end,
		-- Reset to its default position in Edit Mode: back by the minimap.
		reset = function()
			ns.char.loose[key] = nil
			S.Soon()
		end,
	})
end

function S.Start()
	if buffs then return end
	buffs = Adopt(BuffFrame, "buffs", "Buffs")
	debuffs = Adopt(DebuffFrame, "debuffs", "Debuffs")
	rows = Rows()
	LayoutChanged()
	-- Every frame, but only schedule Stand next frame (never SetPoint from this tick during UNIT_AURA).
	C_Timer.NewTicker(0, Watch)
	Shy:OnFor("SHY_HUD_MOVED", buffs, function() S.Soon() end)
	ns.Arrange.Also(S.Soon)
	S.Soon()
end

Shy:On("SHY_LOGIN", S.Start)
