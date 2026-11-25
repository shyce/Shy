-- The auction house window: our own in the game's place. The game's AuctionHouseFrame stays the panel the game opens
-- and closes (its events, its warnings and errors go on working); ours is its child, so it comes and goes with it, and
-- the game's pieces stay where they are, hidden (Shy.Shop.Veil: each asks its parent for the window, so none may be
-- moved). The header names it and holds the pages as tabs; the foot is the
-- scan bar (Foot.lua), or the page's own. A page registers itself:
--   ns.AddPage{ key, label, order, Build = function(page) end, Draw = function(page, width, height) end,
--               Count = function() return n, gold end,   -- an optional count after the tab's words (gold: wants you)
--               Foot = { Build = function(band, L) end, Draw = function(band, width) end } }
--   Foot: a foot of its own in the scan bar's place while it is up: a band in the scan bar's make (Foot.Band), L its
--   measures (pad, market, button, buttonHeight) for what stands in it to line up with the scan bar's.
-- W.Draw() lays the page in view again (next frame: W.Stale()).

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Shop = Shy.Shop

local W = {}
ns.Window = W

local L = {
	w = 760, h = 540,        -- made at
	least = { 640, 440 },    -- dragged down to at the least
	foot = 60,               -- the scan bar's band
	pad = 10,                -- from the window's edge to what is in it
}
W.L = L

local pages, byKey = {}, {}
local box, tabs, kit
local current

function ns.AddPage(def)
	pages[#pages + 1] = def
	byKey[def.key] = def
	table.sort(pages, function(a, b) return a.order < b.order end)
end

-- The page's room: under the header, over the foot.
function W.Top() return UI.HEAD.window.line + UI.LINE + 6 end
function W.Box() return box end
function W.Page() return current end

local function Body()
	local w, h = L.w, L.h
	if box then w, h = UI.BodySize(box) end   -- (its body's: clear of its look's work round the edge, UI.Body)
	local width, height = math.floor(w), math.floor(h)
	if issecretvalue(width) or width <= 0 then width = L.w end
	if issecretvalue(height) or height <= 0 then height = L.h end
	return width, height - W.Top() - L.foot
end

-- (A page that fails is reported to the error bag and the rest goes on: the window stays ours. Only failing to stand
-- in the game's window's place gives that back, Take below.)
local function Safely(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then geterrorhandler()(err) end
end

function W.Draw()
	if not (box and box:IsVisible()) then return end
	local width, height = Body()
	for i, def in ipairs(pages) do
		local n, gold = nil, false
		if def.Count then
			local ok, a, b = pcall(def.Count)
			if ok then n, gold = a, b end
		end
		tabs:SetBadge(i, gold and n or 0)
		tabs:SetCount(i, (not gold and n and n > 0) and n or nil)
		def.frame:SetShown(def.key == current)
		if def.band then def.band:SetShown(def.key == current) end
		if def.key == current then
			if not def.built then
				def.built = true
				Safely(def.Build, def.frame)
				if def.band then Safely(def.Foot.Build, def.band, ns.Foot.L) end
			end
			Safely(def.Draw, def.frame, width, height)
			if def.band then Safely(def.Foot.Draw, def.band, width) end
		end
	end
	local own = byKey[current] and byKey[current].band
	if ns.Foot then
		ns.Foot.Shown(not own)
		if not own then Safely(ns.Foot.Draw, width) end
	end
end

W.Stale = Shop.Later(function() W.Draw() end)

-- A page in view: from its tab (Select calls back here) or from W.Open.
local function Show(key)
	if key ~= current then ns.Note("page", key) end
	current = key
	T.db.page = key
	W.Draw()
end

-- Our window is up (the auction house open, the setting on).
function W.IsUp() return box ~= nil and box:IsShown() end

function W.Open(key)
	if not byKey[key] then return end
	for i, def in ipairs(pages) do
		if def.key == key then tabs:Select(i) end
	end
end

local function Build()
	local labels = {}
	for i, def in ipairs(pages) do labels[i] = def.label end
	box = UI.Window({
		id = "shyauction", title = "Auction house", width = L.w, height = L.h,
		point = { "TOPLEFT", "TOPLEFT", 16, -116 },
		shown = function() return T.db.window == true end,
		head = { size = "window", title = "Auction House", icon = T.mark,
			tabs = { labels, function(i) Show(pages[i].key) end } },
		grip = { flow = function() W.Stale() end, min = { L.least[1], L.least[2] } },
		-- (Closed by its ×: the auction house closes, as the game's own window does it.)
		close = function() C_AuctionHouse.CloseAuctionHouse() end,
	})
	box:SetParent(AuctionHouseFrame)
	tabs = box.head.tabs
	-- Its pages and foot stand on its body: clear of its look's work round the edge (UI.Body).
	local body = UI.Body(box)
	for _, def in ipairs(pages) do
		local frame = CreateFrame("Frame", nil, body)
		frame:SetPoint("TOPLEFT", 0, -W.Top())
		frame:SetPoint("BOTTOMRIGHT", 0, L.foot)
		frame:Hide()
		def.frame = frame
		if def.Foot then
			def.band = ns.Foot.Band(body, L.foot)
			def.band:Hide()
		end
	end
	if ns.Foot then ns.Foot.Build(body, L.foot) end
	current = byKey[T.db.page] and T.db.page or pages[1].key
end

-- The game's window emptied for ours (and given back when the setting is off).
local function Take()
	if not T.db.window then return end
	if not box then Build() end
	kit = kit or Shy.Skin.NewKit()
	Shy.HUD.Update(box)
	Shop.Veil(kit, AuctionHouseFrame, box)
	-- (Laid out the frame after: what a page draws can't undo the stand-in.)
	C_Timer.After(0, function() W.Open(current) end)
end

local function GiveBack()
	if not box then return end
	Shop.Unveil(AuctionHouseFrame)
	if kit then kit:Restore() end
	Shy.HUD.Update(box)
end

-- The setting changed: ours, or the game's own, from the next opening (and now, if it is open).
function W.Apply()
	if not AuctionHouseFrame then return end
	if T.db.window then
		if AuctionHouseFrame:IsShown() then Take() end
	else
		GiveBack()
	end
end

local hooked = false
local function Hook()
	if hooked or not AuctionHouseFrame then return end
	hooked = true
	AuctionHouseFrame:HookScript("OnShow", function()
		Shop.Try(W, Take, function(text) T:Print(text) end)
	end)
	-- An item right-clicked in your bags goes to the game's sell frame, hidden under ours: Sell takes it too.
	hooksecurefunc(AuctionHouseFrame, "SetPostItem", function(_, location)
		if W.IsUp() and ns.SellItem then Safely(ns.SellItem, location) end
	end)
	if AuctionHouseFrame:IsShown() then Shop.Try(W, Take, function(text) T:Print(text) end) end
end

-- (The game's auction house is loaded when first opened.)
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_AuctionHouseUI" then Hook() end
end)
function W.Start()
	if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then Hook() end
	Shy:On("SHY_AUCTION", function() W.Stale() end)
end

-- Shop.Try's module: off for the session after an error, the game's window back.
W.title = "The auction house window"
function W.IsOn() return T.db.window end
function W:Refresh() if not self:IsOn() then GiveBack() end end
