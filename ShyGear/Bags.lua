-- Marks upgrades in the default bags. Marks are textures added to slot buttons; no hooks, no writes to Blizzard's frames.

local ADDON, ns = ...
local T = ns.T

local marks = setmetatable({}, { __mode = "k" })   -- slot button -> mark
local pending

local function Bags()
	local list = { ContainerFrameCombinedBags }
	for _, frame in ipairs(ContainerFrameContainer.ContainerFrames) do list[#list + 1] = frame end
	return list
end

local function MarkSlot(button, on)
	local kind
	local bag = on and button:IsShown() and button:GetBagID()
	if bag then
		local link = C_Container.GetContainerItemLink(bag, button:GetID())
		kind = link and ns.MarkFor(ns.Judge(link))
	end
	local mark = marks[button]
	if kind and not mark then
		mark = ns.CreateMark(button)
		marks[button] = mark
	end
	if mark then mark:Set(kind) end
end

local function Update()
	pending = false
	local on = T.db.bags
	for _, frame in ipairs(Bags()) do
		if frame:IsShown() or not on then
			for _, button in ipairs(frame.Items) do MarkSlot(button, on) end
		end
	end
end

-- Bag events arrive in bursts: update once, next frame.
local function Soon()
	if pending then return end
	pending = true
	C_Timer.After(0, Update)
end

function ns.SetupBags()
	EventRegistry:RegisterCallback("ContainerFrame.OpenBag", Soon, ns)
	local events = CreateFrame("Frame")
	-- An item still loading is asked again through the refreshers when it arrives (ShyGear.lua).
	events:RegisterEvent("BAG_UPDATE_DELAYED")
	events:SetScript("OnEvent", Soon)
	ns.refreshers[#ns.refreshers + 1] = Update   -- refreshers already run once a frame
end
