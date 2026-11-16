-- ShyFrames: unit frames for player, target, target's target, pet, focus, party and party pets.
-- The frames are secure buttons: never moved, sized, shown or hidden in combat (ns.AfterCombat).

local ADDON, ns = ...
local MEDIA = "Interface\\AddOns\\ShyFrames\\Media\\"

local T = Shy:NewAddon(ADDON, {
	suffix = "Frames",
	category = "combat",
	icon = MEDIA .. "ShyFrames",
	smallIcon = MEDIA .. "ShyFramesSmall",
	savedVariables = "ShyFramesDB",
	defaults = {
		units = { player = true, target = true, targettarget = true, pet = true, focus = true, party = true, partypet = true },
		hideBlizzard = true,
		fade = false,
		doom = true,           -- what your damage over time still has to deal, on the target's bar (ShyDots)
		mend = true,           -- what your heals over time still have to heal, at the end of a friend's health (ShyHots)
		size = 0.94,           -- two 248 wide plates span ShyDock's 468 wide housing
		grid = "auto",         -- the party as a healing grid: "auto" (while you're the healer), "on" or "off"
		press = true,          -- a click bound to a spell casts as the button goes down (Clicks.lua)
		-- Click casting, by class: [class][mod .. button] = "target", "menu", a spell's name or its ID.
		clicks = {},
	},
	keep = { clicks = true },   -- what you bound is no setting: a reset keeps it
})
ns.T = T

-- Whether the party should stand as the healing grid: tight cells with you among them. By default while you're
-- the healer (the role your group gave you, else a healer's layout in use: Shy.Role).
function ns.GridWanted()
	local mode = T.db.grid
	if mode == "on" then return true end
	if mode == "off" then return false end
	return Shy.Role() == "healer"
end

-- Whether it stands so now. The frames are secure: they change over out of a fight only, when Place.lua lays
-- them out (ns.TakeGrid), and everything else goes by how they stand.
local grid = false
function ns.Grid()
	return grid
end

function ns.TakeGrid()
	grid = ns.GridWanted()
	return grid
end

-- The test party: every seat of the party's box nobody holds shows a sample member (Frames.lua's F.SAMPLES), so
-- the frames can be looked at, placed and set up without a group. On while the screen is being arranged (layout
-- mode) and while asked for (T:Test, `/shyframes test`); never kept past a reload. Taken up and put away with
-- the frames, as the grid is (ns.TakeSample); in a fight the game itself hides the samples, and shows them after.
local testing, sampling = false, false
function ns.SampleWanted()
	return (testing or Shy.HUD.IsUnlocked()) and T.db.units.party == true
end

function ns.Sampling()
	return sampling
end

function ns.TakeSample()
	sampling = ns.SampleWanted()
	return sampling
end

-- Turns the test party on or off (toggles it when not told which). Returns whether it is on now.
function T:Test(on)
	if on == nil then on = not testing end
	testing = on and true or false
	if ns.Place and ns.Place.boxes.party then ns.Place.Reseat() end   -- once the frames stand
	if ns.RefreshOptions then ns.RefreshOptions() end
	return testing
end

function T:Testing()
	return testing
end

-- Whether sample members stand in the empty seats just now (ShyBuffs marks their cells as it would in a fight).
function T:Sampling()
	return sampling
end

local started

local jobs, order = {}, {}   -- key -> job, and the keys in the order queued
local combat = CreateFrame("Frame")
combat:RegisterEvent("PLAYER_REGEN_ENABLED")
combat:SetScript("OnEvent", function()
	local todo, keys = jobs, order
	jobs, order = {}, {}
	for _, key in ipairs(keys) do todo[key]() end
end)

-- Runs fn now, or after combat. One job per key: a repeat replaces the queued one. Returns true if it ran now.
function ns.AfterCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return true
	end
	if not jobs[key] then order[#order + 1] = key end
	jobs[key] = fn
	return false
end

-- Applies every setting. Safe at any time.
function T:Apply()
	if not started then return end
	ns.Place.Apply()      -- waits for combat to end
	ns.Frames.Redraw()
	ns.Fader.Apply()
	ns.Blizzard.Apply()
	if ns.Clicks then ns.Clicks.Apply() end
	-- ShyDock listens for this.
	Shy:Fire("SHY_FRAMES")
	if ns.RefreshOptions then ns.RefreshOptions() end
end

function T:OnLoad()
	self:RegisterOptions(ns.CreateOptions())
end

function T:OnLogin()
	started = true
	ns.Frames.Start()
	ns.Place.Start()
	ns.Fader.Start()
	if ns.Clicks then ns.Clicks.Listen() end
	self:Apply()
end

-- For ShyDock: height of the player and target plates, in UIParent units.
-- Your health's fill as your frame draws it (the color picked, toned to read under the frame's words), for the
-- other bar of your health (the cockpit's under your character) to wear the same.
function T:HealthFill()
	local r, g, b = Shy.Skin.HealthRGB()
	return ns.Units.Tone(r, g, b)
end

function T:PlatesHeight()
	local _, height = ns.Layout.Size("player")
	return height * self.db.size
end

-- For ShyDock: how wide the small frames beside the plates are, in UIParent units, the left side's (pet
-- and focus, the wider) and the right's (the target's target); 0 for a side with none there (switched off,
-- or moved somewhere of the player's own).
function T:Beside()
	local function Width(kind)
		if not self.db.units[kind] then return 0 end
		local box = Shy.HUD.Find("shyframes-" .. kind)
		if box and Shy.HUD.IsPlaced(box) then return 0 end
		return ns.Layout.Size(kind) * self.db.size * (box and box:GetScale() or 1)
	end
	return math.max(Width("pet"), Width("focus")), Width("targettarget")
end

-- What rises over the player's and target's plates, in layout units: combo points, and ShyBuffs' row of icons
-- when it is there (on the combo points for a class that builds them). The same for both: they stay level.
function ns.Rise()
	return ns.Layout.Overhang(Shy.addons.Buffs ~= nil, UnitClassBase("player"))
end

-- What rises over a party member's cell: ShyBuffs' row of icons, or nothing. A cell of the healing grid carries
-- its marks inside it, so the cells stand close.
function ns.CellRise()
	if Shy.addons.Buffs == nil or ns.Grid() then return 0 end
	local L = ns.Layout
	return L.Rise(L.RISER.cell, 1)
end

-- Whether ShyBuffs' icons on your target's plate stand on the combo points' housing just now: the housing is then
-- always there under them, empty or not, so they never float over the edge.
function ns.Plinth()
	local buffs = Shy.addons.Buffs
	return ns.Layout.Stacked(UnitClassBase("player")) and buffs ~= nil and buffs.Rows ~= nil and buffs:Rows() and true or false
end

-- For ShyDock's layouts by role, which stand these frames round your character: each frame's size in UIParent
-- units ({ w, h } by kind: player, target, targettarget, focus, pet), at its box's scale, with what rises over
-- your frame and your target's (the riser: combo points, ShyBuffs' icons) counted in their height.
function T:Sizes()   -- (and `cell`, below)
	local out = {}
	local rise = ns.Rise()
	for _, kind in ipairs({ "player", "target", "targettarget", "focus", "pet" }) do
		local w, h = ns.Layout.Size(kind)
		local box = Shy.HUD.Find("shyframes-" .. kind)
		local k = self.db.size * (box and box:GetScale() or 1)
		if kind == "player" or kind == "target" then h = h + rise end
		out[kind] = { w * k, h * k }
	end
	-- One cell of the healing grid too (`cell`): the console draws its screen by it where the party stands so.
	local make = ns.Layout.LAYOUTS.grid
	local box = Shy.HUD.Find("shyframes-party")
	local k = self.db.size * (box and box:GetScale() or 1)
	out.cell = { make.width * k, make.height * k }
	-- And the party standing as a column (`column`; the console reads its height): four cells, or the grid's five,
	-- with what rises over each and the seams between them.
	local cells = ns.Grid() and 5 or 4
	local w, h = ns.Layout.Size("party")
	out.column = { w * k, cells * (ns.CellRise() + h) * k + (cells - 1) * ns.Place.SEAM * (box and box:GetScale() or 1) }
	return out
end

-- Whether the party would stand as the healing grid in a layout made for `layoutRole` ("healer", "tank" or nil):
-- the console asks for the layouts it draws, the one in use or not. (As Shy.Role: your group's word first.)
function T:GridIn(layoutRole)
	local mode = self.db.grid
	if mode ~= "auto" then return mode == "on" end
	local role = UnitGroupRolesAssigned("player")
	if not issecretvalue(role) and (role == "TANK" or role == "HEALER" or role == "DAMAGER") then return role == "HEALER" end
	return layoutRole == "healer"
end

-- How far ShyFrames reaches over the player's and target's plates: the tallest riser (combo points,
-- or the icons ShyBuffs stands there) and, with party frames on, the party's row over that with its own icons.
function T:Overhang()
	local rise = ns.Rise() * self.db.size
	if self.db.units.party then
		local _, cell = ns.Layout.Size("party")
		rise = rise + ns.Place.SEAM + (cell + ns.CellRise()) * self.db.size
	end
	return rise
end

-- For ShyBuffs, which draws every buff and debuff on these frames.
--   fn(key, kind, unit, button)   kind: "player", "target", "party" ...; a party member's pet has none
function T:EachFrame(fn)
	for _, frame in ipairs(ns.Frames.list) do
		if frame.kind ~= "partypet" and frame.index ~= 0 then fn(frame.key, frame.kind, frame.unit, frame.button) end
	end
end

-- The healing grid, for ShyBuffs, which marks its cells.
--   T:Grid()       whether the party stands as the grid just now ("SHY_FRAMES_FIT" fires when that changes)
--   T:EachCell(fn) fn(key, unit, button, bar) for each of its cells, yours included: `bar` is the cell's health
--                  bar, whose foot the marks stand in
--   T:GridRoom()   that room, in a cell's own units: { seats, mark, gap, hair, harm, foot, ends } (Layout.lua, L.GRID)
function T:Grid()
	return ns.Grid()
end

function T:EachCell(fn)
	for _, frame in ipairs(ns.Frames.list) do
		if frame.kind == "party" then fn(frame.key, frame.unit, frame.button, frame.plate.bars.health) end
	end
end

function T:GridRoom()
	return ns.Layout.GRID
end

-- Click casting, for whoever binds by being clicked or pressed on (ShySkin's spellbook): Clicks.lua's own.
--   T:ClickInput(click)     the mouse click being made now, as an input ("LeftButton" with Shift held -> "shift-1")
--   T:ClickKeyInput(key)    the key being pressed now, as one ("F" with Ctrl held -> "key:CTRL-F"); nil for a key
--                           that is none of its own (Shift, Escape)
--   T:ClickWords(input)     "Shift + Left click", "Ctrl + F"
--   T:ClicksOf(name, id)    the inputs bound to a spell, by name or by that rank's ID
--   T:BindClick(input, what)   what: a spell's name (its highest rank), its ID (that rank), "target", "menu", or
--                           nil to unbind  -> true, or false and why not
--   T:ClickIcon(what)       click casting's own picture; with "target" or "menu", that one's
--   T:ClickPanel(parent)    the list of every binding, for whoever binds to stand beside its spells (Clicks.lua's
--                           C.Panel: :Fit(width, height) its room, .how (what it says while nothing is bound),
--                           .changed (called after any change), :Refresh(), :Say(text | nil))
function T:ClickInput(click) return ns.Clicks.Input(click) end
function T:ClickKeyInput(key) return ns.Clicks.KeyInput(key) end
function T:ClickWords(input) return ns.Clicks.Words(input) end
function T:ClicksOf(name, id) return ns.Clicks.Of(name, id) end
function T:BindClick(input, what) return ns.Clicks.Set(input, what) end
function T:ClickIcon(what) return ns.Clicks.Picture(what) end
function T:ClickPanel(parent) return ns.Clicks.Panel(parent) end

-- The housing icons stand in on a plate's top edge: its art and its measures, in a plate's own units. `size` is a
-- plate's icons, in `lines` rows at most, `cell` a party member's, in one; `stacked`: your target's stand on its
-- combo points, `combo` high. The room made over the frames is that and no more: nothing may stand past it.
function T:Riser()
	local L = ns.Layout
	return { fill = L.RISER_FILL, edge = L.RISER_EDGE, slice = L.RISER_SLICE, size = L.RISER.size, lines = L.RISER.lines,
		cell = L.RISER.cell,
		gap = L.RISER.gap, pad = L.RISER.pad, foot = L.RISER.foot, ends = L.RISER.ends, combo = L.COMBO.rise,
		stacked = L.Stacked(UnitClassBase("player")) }
end

-- Whether a plate kind ("player", "target", ...) is on screen. "SHY_PLATE" (kind, shown) fires on change.
function T:PlateShown(kind)
	return ns.Frames.Shown(kind)
end

SLASH_SHYFRAMES1 = "/shyframes"
SLASH_SHYFRAMES2 = "/sframes"
SlashCmdList.SHYFRAMES = function(input)
	local cmd = strtrim(input or ""):lower()
	if cmd == "" then
		T:OpenOptions()
	elseif cmd == "move" then
		Shy.HUD.SetUnlocked(true)
	elseif cmd == "clicks" and ns.Clicks then
		ns.Clicks.Open()
	elseif cmd == "test" then
		if T:Test() then
			T:Print("the test party is on: a sample member in every empty seat. /shyframes test again turns it off.")
		else
			T:Print("the test party is off.")
		end
	else
		T:Print("commands:")
		print("  /shyframes  - open options")
		print("  /shyframes move  - open layout mode")
		print("  /shyframes clicks  - set up click casting")
		print("  /shyframes test  - show a sample party, to see and place the party frames without a group")
	end
end
