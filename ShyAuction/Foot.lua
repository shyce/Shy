-- The scan bar, along the window's foot: your market at the left (its side's emblem, the house, region and ruleset, how
-- fresh its prices are), one bar across the middle that fills as the listings are read (the count and what is left in
-- it, a light at its tip), what the scan has found so far under it, and the button at its end: Scan the house, Stop,
-- Scanned, or waiting with the next scan's countdown in the bar.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local Theme = Shy.Theme
local C = UI.colors
local Shop = Shy.Shop

local F = {}
ns.Foot = F

local L = { market = 200, button = 124, bar = 18, pad = 12 }
local foot, ticker
local Ticking   -- (below: the footer's hide stops it)

local EMBLEM = { Alliance = "communities-icon-faction-alliance", Horde = "communities-icon-faction-horde" }
local SIDE = { Alliance = "Alliance house", Horde = "Horde house", Neutral = "Neutral house" }

function F.Build(box, tall)
	foot = CreateFrame("Frame", nil, box)
	foot:SetPoint("BOTTOMLEFT", 2, 2)
	foot:SetPoint("BOTTOMRIGHT", -2, 2)
	foot:SetHeight(tall - 2)
	-- The band: a floor a little darker than the window, a groove along its top, a lip of light under it.
	foot.floor = foot:CreateTexture(nil, "BACKGROUND")
	foot.floor:SetAllPoints()
	foot.floor:SetColorTexture(0, 0, 0, 0.3)
	foot.groove = foot:CreateTexture(nil, "BORDER")
	foot.groove:SetPoint("TOPLEFT")
	foot.groove:SetPoint("TOPRIGHT")
	foot.groove:SetHeight(1)
	foot.groove:SetColorTexture(0, 0, 0, 0.85)
	foot.lip = foot:CreateTexture(nil, "BORDER")
	foot.lip:SetPoint("TOPLEFT", 0, -1)
	foot.lip:SetPoint("TOPRIGHT", 0, -1)
	foot.lip:SetHeight(1)
	foot.lip:SetColorTexture(1, 1, 1, 0.07)

	-- Your market.
	foot.emblem = foot:CreateTexture(nil, "ARTWORK")
	foot.emblem:SetSize(26, 26)
	foot.emblem:SetPoint("LEFT", L.pad, 0)
	foot.house = Shop.Text(foot, UI.TitleFont(14), C.head)
	foot.house:SetPoint("BOTTOMLEFT", foot.emblem, "RIGHT", 8, 0)
	foot.where = Shop.Text(foot, UI.TextFont(10), C.dim)
	foot.where:SetPoint("TOPLEFT", foot.house, "BOTTOMLEFT", 0, -2)

	-- The bar: a well, its fill hatched, a light at the fill's tip, the words over it, a line of facts under it.
	foot.bar = CreateFrame("Frame", nil, foot)
	foot.bar:SetHeight(L.bar)
	foot.bar:SetPoint("LEFT", L.market, 0)
	foot.bar:SetPoint("RIGHT", -(L.pad + L.button + 12), 0)
	foot.well = foot.bar:CreateTexture(nil, "BACKGROUND")
	foot.well:SetAllPoints()
	foot.well:SetColorTexture(0, 0, 0, 0.55)
	foot.fill = foot.bar:CreateTexture(nil, "ARTWORK")
	foot.fill:SetPoint("TOPLEFT")
	foot.fill:SetPoint("BOTTOMLEFT")
	Shy.Skin.Hatch(foot.fill, L.bar)
	foot.tip = foot.bar:CreateTexture(nil, "OVERLAY")
	foot.tip:SetSize(2, L.bar + 4)
	foot.tip:SetPoint("CENTER", foot.fill, "RIGHT", 0, 0)
	foot.tip:SetColorTexture(1, 1, 1, 0.9)
	foot.edge = CreateFrame("Frame", nil, foot.bar)
	foot.edge:SetAllPoints()
	UI.Skin(foot.edge, { 0, 0, 0, 0 }, C.border)
	foot.words = Shop.Text(foot.bar, UI.NameFont(11), C.text)
	foot.words:SetPoint("CENTER", 0, 0)
	foot.left = Shop.Text(foot, UI.TextFont(10), C.dim)
	foot.left:SetPoint("TOPLEFT", foot.bar, "BOTTOMLEFT", 0, -3)
	foot.right = Shop.Text(foot, UI.TextFont(10), C.dim)
	foot.right:SetPoint("TOPRIGHT", foot.bar, "BOTTOMRIGHT", 0, -3)
	foot.right:SetJustifyH("RIGHT")

	foot.button = UI.Button(foot, "Scan the house", L.button, function()
		if ns.Scan.State() then ns.Scan.Stop() return end
		local ok, why = ns.Scan.Full()
		if not ok then T:Print(why) end
		F.Draw()
	end)
	foot.button:SetHeight(26)
	foot.button:SetPoint("RIGHT", -L.pad, 0)

	-- (While a scan runs or the next one is counted down, the bar is drawn again a few times a second; otherwise not.)
	foot:SetScript("OnShow", function() F.Draw() end)
	foot:SetScript("OnHide", function() Ticking(nil) end)
end

local function Fill(share, color)
	local width = foot.bar:GetWidth()
	if issecretvalue(width) or not width or width <= 0 then width = 300 end
	share = math.max(0, math.min(1, share))
	foot.fill:SetWidth(math.max(1, width * share))
	foot.fill:SetShown(share > 0)
	foot.tip:SetShown(share > 0 and share < 1)
	if share <= 0 then return end
	if color == "accent" then Theme.Tint(foot.fill, Theme.Accent) else Theme.Tint(foot.fill, color or C.dim) end
end

local function Count(n)
	return BreakUpLargeNumbers(math.floor(n + 0.5))
end

-- Words set only where they are other than they were (the bar is drawn again often while it moves).
local said = setmetatable({}, { __mode = "k" })
local function Say(fs, text)
	if said[fs] == text then return end
	said[fs] = text
	fs:SetText(text)
end

-- Drawn again five times a second while the listings are read, once a second while the next scan is counted down,
-- not at all otherwise.
local tickEvery
function Ticking(every)
	if every == tickEvery then return end
	if ticker then ticker:Cancel() ticker = nil end
	tickEvery = every
	if every then ticker = C_Timer.NewTicker(every, Shy.Clocked("auction: the scan bar", function() F.Draw() end)) end
end

function F.Draw()
	if not (foot and foot:IsVisible()) then return end
	-- Your market.
	local key, at = ns.Book.Key(), ns.Book.ScannedAt()
	local region, ruleset, side = (key or ""):match("^(%a+)%-(%a+)%-(%a+)$")
	side = side or UnitFactionGroup("player") or "Neutral"
	if EMBLEM[side] then
		foot.emblem:SetAtlas(EMBLEM[side])
		foot.emblem:SetVertexColor(1, 1, 1)
	else
		Shy.Hover.Glyph(foot.emblem, "coin", 26)
		UI.Tint(foot.emblem, C.alert)
	end
	Say(foot.house, SIDE[side] or side)
	local fresh = at and (time() - at < 3 * 3600)
	local age = at and UI.Ago(at) or "no prices yet"
	Say(foot.where, ("%s · %s  ·  |cff%s%s|r"):format(region or "", ruleset or "", fresh and "66ffc7" or "ffcf61", age))

	-- The scan.
	local state, wait, last = ns.Scan.State(), ns.Scan.Wait(), ns.Scan.Last()
	local button = foot.button
	if not ns.Scan.CAN then
		Fill(0)
		Say(foot.words, "This game has no whole-house scan")
		Say(foot.left, ("%s items priced"):format(Count(ns.Book.Count())))
		Say(foot.right, "from your searches and other players")
		button:SetLabel("Scan the house")
		button:SetUsable(false, "This game has no whole-house scan.")
		button:SetPrimary(false)
		Ticking(nil)
	elseif state then
		if state.state == "asked" then
			Fill(0.02, "accent")
			Say(foot.words, "Asking the house for every listing...")
			Say(foot.left, "")
			Say(foot.right, "")
		else
			Fill(state.of > 0 and state.done / state.of or 0, "accent")
			local left = state.left and (" · about %d s"):format(math.ceil(state.left)) or ""
			Say(foot.words, ("Reading listings %s of %s  |cffc8c8c8%d%%%s|r"):format(Count(state.done), Count(state.of),
				state.of > 0 and math.floor(state.done / state.of * 100) or 0, left))
			Say(foot.left, ("|cffe1eeff%s|r items so far"):format(Count(state.found)))
			Say(foot.right, ("|cffe1eeff%s|r cheaper than before"):format(Count(state.cheaper)))
		end
		button:SetLabel("Stop")
		button:SetUsable(true)
		button:SetPrimary(false)
		Ticking(state.state == "reading" and 0.2 or 1)
	elseif ns.Scan.refused and time() - ns.Scan.refused < 120 then
		Fill(0)
		Say(foot.words, "The house didn't answer the scan  |cffc8c8c8try again|r")
		Say(foot.left, ("%s items priced"):format(Count(ns.Book.Count())))
		Say(foot.right, "")
		button:SetLabel("Scan the house")
		button:SetUsable(ns.Scan.IsOpen(), "Open the auction house first.")
		button:SetPrimary(true)
		Ticking(nil)
	elseif wait > 0 then
		Fill(1 - wait / ns.Scan.K.EVERY, C.dim)
		Say(foot.words, ("Next scan in %d:%02d  |cffc8c8c8the server allows one each 15 min|r"):format(math.floor(wait / 60), wait % 60))
		Say(foot.left, ("%s items priced"):format(Count(ns.Book.Count())))
		Say(foot.right, at and ("Scanned %s"):format(UI.Ago(at)) or "")
		button:SetLabel(last and time() - last.at < 60 and "Scanned" or "Scan the house")
		button:SetUsable(false, ("The server allows the next scan in %d min."):format(math.ceil(wait / 60)))
		button:SetPrimary(false)
		Ticking(1)
	else
		Fill(0)
		Say(foot.words, at and ("Prices %s  |cffc8c8c8scan for fresh ones|r"):format(UI.Ago(at)) or "No prices yet  |cffc8c8c8scan the house|r")
		Say(foot.left, ("%s items priced"):format(Count(ns.Book.Count())))
		Say(foot.right, "")
		button:SetLabel("Scan the house")
		button:SetUsable(ns.Scan.IsOpen(), "Open the auction house first.")
		button:SetPrimary(true)
		Ticking(nil)
	end
	if last and time() - last.at < 60 and not state then
		Fill(1, C.good)
		Say(foot.words, ("%s items priced  |cffc8c8c8just now|r"):format(Count(last.count)))
		Say(foot.left, ("|cff66ffc7%s|r new to the book"):format(Count(last.new)))
		Say(foot.right, ("|cff66ffc7%s|r cheaper than before"):format(Count(last.deals)))
	end
end
