-- Hides Blizzard's bag frames and follows their open state.
-- The frames are reparented to a never-shown frame (the attic): IsShown still answers for Blizzard's code, so bag
-- keys, vendors, mail, bank, AH and Escape keep working, and OnShow/OnHide never run.
-- Blizzard's bag functions are post-hooked; they nest, so state is read once on the next frame (last hook wins).
-- Never call those functions from addon code: CloseAllBags would taint FRAME_THAT_OPENED_BAGS, the bank reads it,
-- and item clicks then get blocked. Our controls Show/Hide the reparented frames directly.
-- Frames are only reparented while none is shown; moving a shown one would run its scripts tainted.
-- On a gamepad the default bags are kept (they carry the gamepad bag bar).
--   Takeover.Visible() returns window up, key ring up; OnChange(fn(visible, keys)); OnSwitch(fn(on))

local ADDON, ns = ...

local Takeover = {}
ns.Takeover = Takeover

local KEYS = Enum.BagIndex.Keyring

local attic
local frames = {}      -- Blizzard's bag frames
local home = {}        -- frame -> its original parent
local want, on = false, false
local soft = false     -- opened from our own controls while Blizzard's bags are closed
local visible, keys = false, false
local last             -- the last bag call: "toggle", "close", "keys" or "sync"
local listeners = {}
local switches = {}
local pending = false  -- Settle is due next frame

local function OnGamepad()
	return C_InputInterfaceStyle.GetCurrentStyle() == Enum.InputDeviceInterfaceType.Gamepad
end

-- Returns any bag shown, key ring shown.
local function Shown()
	local bags, ring = false, false
	for _, frame in ipairs(frames) do
		if frame:IsShown() then
			if frame ~= ContainerFrameCombinedBags and frame:GetID() == KEYS then ring = true else bags = true end
		end
	end
	return bags, ring
end

-- Only while reparented, where Hide runs no scripts.
local function HideBags()
	for _, frame in ipairs(frames) do
		if frame:IsShown() and (frame == ContainerFrameCombinedBags or frame:GetID() ~= KEYS) then frame:Hide() end
	end
end

local function Tell(nowVisible, nowKeys)
	if nowVisible == visible and nowKeys == keys then return end
	if on or visible or keys then
		if nowVisible ~= visible then PlaySound(nowVisible and SOUNDKIT.IG_BACKPACK_OPEN or SOUNDKIT.IG_BACKPACK_CLOSE) end
		if nowKeys ~= keys then PlaySound(nowKeys and SOUNDKIT.KEY_RING_OPEN or SOUNDKIT.KEY_RING_CLOSE) end
	end
	visible, keys = nowVisible, nowKeys
	for _, fn in ipairs(listeners) do ns.Guard(fn, visible, keys) end
end

local function Apply()
	local should = want and not OnGamepad()
	-- Claimed before the frames move and released after they return, so other addons leave them alone.
	if should then ns.Own("window", true) end
	if should == on then return end
	local bags, ring = Shown()
	if bags or ring then return end   -- retried at the next close
	for _, frame in ipairs(frames) do
		if should then
			home[frame] = frame:GetParent()
			frame:SetParent(attic)
		elseif home[frame] then
			FrameUtil.SetParentMaintainRenderLayering(frame, home[frame])
		end
	end
	on = should
	if not on then
		soft = false
		Tell(false, false)
		ns.Own("window", false)
	end
	for _, fn in ipairs(switches) do ns.Guard(fn, on) end
end

local function Settle()
	pending = false
	local call = last
	last = nil
	if not on then
		Apply()
		return
	end
	-- One window for every bag: any toggle while it is up closes it.
	if call == "toggle" and visible then
		HideBags()
		soft = false
	elseif call == "close" then
		soft = false
	end
	local bags, ring = Shown()
	Tell(bags or soft, ring)
	if want ~= on or OnGamepad() then Apply() end
end

local function Called(kind)
	last = kind
	if pending then return end
	pending = true
	C_Timer.After(0, Settle)
end

function Takeover.Set(value)
	want = value and true or false
	Apply()
end

function Takeover.IsOn() return on end
function Takeover.Attic() return attic end
function Takeover.Visible() return visible, keys end
function Takeover.OnChange(fn) listeners[#listeners + 1] = fn end
function Takeover.OnSwitch(fn) switches[#switches + 1] = fn end

function Takeover.Open()
	if not on or visible then return end
	soft = true
	last = nil
	Settle()
end

-- Bags and key ring.
function Takeover.Close()
	if not on or not (visible or keys) then return end
	for _, frame in ipairs(frames) do
		if frame:IsShown() then frame:Hide() end
	end
	soft = false
	last = nil
	Settle()
end

function Takeover.CloseKeys()
	if not on or not keys then return end
	for _, frame in ipairs(frames) do
		if frame ~= ContainerFrameCombinedBags and frame:IsShown() and frame:GetID() == KEYS then frame:Hide() end
	end
	last = nil
	Settle()
end

function Takeover.Toggle()
	if visible then Takeover.Close() else Takeover.Open() end
end

function Takeover.Init()
	attic = CreateFrame("Frame", nil, UIParent)
	attic:SetAllPoints(UIParent)   -- Blizzard anchors a bag to its parent and measures it
	attic:Hide()

	frames[1] = ContainerFrameCombinedBags
	for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do frames[#frames + 1] = frame end

	local function Sync() Called("sync") end
	local function Toggled() Called("toggle") end
	local function Closed() Called("close") end
	hooksecurefunc("ToggleBackpack", Toggled)
	hooksecurefunc("ToggleAllBags", Toggled)
	hooksecurefunc("ToggleBag", function(id) Called(id == KEYS and "keys" or "toggle") end)
	hooksecurefunc("OpenBag", Sync)
	hooksecurefunc("OpenBackpack", Sync)
	hooksecurefunc("OpenAllBags", Sync)
	hooksecurefunc("OpenAllBagsMatchingContext", Sync)
	hooksecurefunc("CloseBag", function(id) Called(id == KEYS and "keys" or "close") end)
	hooksecurefunc("CloseBackpack", Closed)
	-- With a frame argument it only closes bags that frame opened (mailbox, vendor).
	hooksecurefunc("CloseAllBags", function(frame) Called(frame and "sync" or "close") end)

	-- Blizzard reparents its bags for a full-screen frame.
	local function Moved()
		if not on then return end
		on = false
		Called("sync")
	end
	hooksecurefunc("ContainerFrame_SetFullScreenFrame", Moved)
	hooksecurefunc("ContainerFrame_ClearFullScreenFrame", Moved)

	local events = CreateFrame("Frame")
	events:RegisterEvent("INPUT_DEVICE_INTERFACE_TRANSITION")   -- mouse to gamepad and back
	events:SetScript("OnEvent", function() Called("sync") end)
end
