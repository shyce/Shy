-- The crates in a window of their own, where you fill them: anywhere, once what they take is in your bags. Each row's
-- Fill (or Open) is the game's own button, one click; the shopping list along its foot says what is still to get.
-- A secure window: it steps aside in a fight and comes back after. /shy crates, or the crate on the bags' rail.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Shop = Shy.Shop

local Window = {}
ns.Window = Window

-- foot: the shopping list's band, measured as the auction house's scan bar (Wares.lua lays it the same way).
local L = { w = 640, h = 380, least = { 520, 280 }, pad = 10, foot = 58,
	measures = { pad = 12, market = 200, button = 124, buttonHeight = 26 } }
local box, page, list, foot
local open = false
local fromBags = false   -- opened from the crate on the bags' rail: it closes with them

local function Top() return UI.HEAD.window.line + UI.LINE + 6 end

local function Draw()
	if not (box and box:IsVisible()) then return end
	local w, h = UI.BodySize(box)
	if issecretvalue(w) or issecretvalue(h) then return end
	list:Draw(math.floor(w) - L.pad * 2, math.floor(h) - Top() - L.foot - L.pad)
	foot:Draw(math.floor(w), list:Upcoming())
end
local Stale = Shop.Later(Draw)

local function Build()
	box = UI.Window({
		id = "shycrates", name = "ShyCratesWindow", title = "Waylaid Crates", width = L.w, height = L.h,
		point = { "CENTER", "CENTER", 0, 60 },
		shown = function() return open end,
		secure = true,
		onClose = function()
			open = false
			ns.Rail.Refresh()
		end,
		head = { size = "window", title = "Waylaid Crates", icon = T.mark },
		grip = { flow = function() Stale() end, min = { L.least[1], L.least[2] } },
	})
	local body = UI.Body(box)
	page = CreateFrame("Frame", nil, body)
	page:SetPoint("TOPLEFT", L.pad, -Top())
	page:SetPoint("BOTTOMRIGHT", -L.pad, L.foot + L.pad)
	list = ns.List.New(page, true)
	local band = CreateFrame("Frame", nil, body)
	band:SetPoint("BOTTOMLEFT")
	band:SetPoint("BOTTOMRIGHT")
	band:SetHeight(L.foot)
	band.rule = Shop.Rule(band)
	band.rule:SetPoint("TOPLEFT")
	band.rule:SetPoint("TOPRIGHT")
	foot = ns.Wares.New(band, L.measures, "fill")
	-- A fill's countdown: the crate's button and Fill next alone, each tenth; all of it again as it ends.
	ns.Cast.Watch(function()
		if not box:IsVisible() then return end
		if ns.Cast.Now() then
			list:Tick()
			foot:Tick()
		else
			Stale()
		end
	end)
	box:HookScript("OnShow", Stale)
	-- (Drawn again after a fight: what changed during it waited.)
	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:SetScript("OnEvent", Stale)
	Shy:On("SHY_CRATES", Stale)
end

function Window.Open(bags)
	if not box then Build() end
	fromBags = bags == true
	open = true
	Shy.HUD.Update(box)
	Draw()
	ns.Rail.Refresh()
end

-- bags: only if the bags opened it.
function Window.Close(bags)
	if not box or (bags and not fromBags) then return end
	open = false
	Shy.HUD.Update(box)
	ns.Rail.Refresh()
end

function Window.Toggle(bags)
	if open then Window.Close() else Window.Open(bags) end
end

function Window.Shown() return box ~= nil and box:IsShown() end
function Window.List() return list end
function Window.Foot() return foot end
