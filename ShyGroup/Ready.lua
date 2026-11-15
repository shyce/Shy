-- The call to enter a battleground (the game's PVPReadyDialog) lapses after a time the game keeps but
-- doesn't show: a thin bar of ours under the dialog runs it down, gold for the last seconds.

local ADDON, ns = ...
local UI = Shy.UI
local C = UI.colors

local HIGH = 16          -- the bar's well
local INSET = 10         -- in from the dialog's sides
local GAP = 4            -- under the dialog
local SOON = 10          -- seconds left from which it is gold
local LOOK = 0.5         -- how often the game's own count is read again, seconds

local bar, dialog
local span, ends, read = 0, 0, 0   -- the whole wait, when it ends (GetTime), when the game was last asked
local soon

local function Left()
	local index = dialog.activeIndex
	if not index then return 0 end
	return GetBattlefieldPortExpiration(index) or 0
end

-- Seconds as the bar says them: "1:24", then "42".
local function Words(left)
	left = math.max(0, math.ceil(left))
	if left >= 60 then return ("%d:%02d"):format(math.floor(left / 60), left % 60) end
	return tostring(left)
end

local function Tone(gold)
	if soon == gold then return end
	soon = gold
	UI.Tint(bar.fill:GetStatusBarTexture(), gold and C.alert or C.hot)
	UI.Ink(bar.time, gold and C.alert or C.text)
end

-- The game counts in whole seconds; between its counts the bar runs on its own clock, and takes the
-- game's word again whenever the two part by more than a second.
local function Look(now)
	read = now
	local left = Left()
	if left <= 0 then
		bar:Hide()
		return false
	end
	if left > span then span = left end
	if math.abs((ends - now) - left) > 1 then ends = now + left end
	return true
end

local function Run(self)
	local now = GetTime()
	if now - read >= LOOK and not Look(now) then return end
	local left = math.max(0, ends - now)
	self.fill:SetValue(left)
	self.time:SetText(Words(left))
	Tone(left <= SOON)
end

local function Start()
	span, ends, soon = 0, 0, nil
	bar.index = dialog.activeIndex
	if not Look(GetTime()) then return end
	bar.fill:SetMinMaxValues(0, span)
	bar:Show()
	Run(bar)
end

local function Build()
	bar = CreateFrame("Frame", nil, UIParent)
	bar:SetFrameStrata("DIALOG")
	bar:SetHeight(HIGH)
	bar:SetPoint("TOPLEFT", dialog, "BOTTOMLEFT", INSET, -GAP)
	bar:SetPoint("TOPRIGHT", dialog, "BOTTOMRIGHT", -INSET, -GAP)
	bar:Hide()
	UI.Skin(bar, Shy.Theme.skin.well, C.border)
	local shade = bar:CreateTexture(nil, "BORDER", nil, 1)
	shade:SetPoint("TOPLEFT", 1, -1)
	shade:SetPoint("TOPRIGHT", -1, -1)
	shade:SetHeight(2)
	shade:SetColorTexture(0, 0, 0, 0.35)
	local fill = CreateFrame("StatusBar", nil, bar)
	fill:SetPoint("TOPLEFT", 2, -2)
	fill:SetPoint("BOTTOMRIGHT", -2, 2)
	Shy.Skin.HatchBar(fill)
	fill:SetMinMaxValues(0, 1)
	bar.fill = fill
	local time = fill:CreateFontString(nil, "OVERLAY")
	time:SetFontObject(UI.NameFont(11))
	time:SetShadowOffset(1, -1)
	time:SetShadowColor(0, 0, 0, 1)
	time:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	bar.time = time
	Tone(false)
	bar:SetScript("OnUpdate", Run)
	dialog:HookScript("OnShow", Start)
	dialog:HookScript("OnHide", function() bar:Hide() end)
	-- The dialog stays up when the call it shows is replaced by another queue's.
	local events = CreateFrame("Frame")
	events:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
	events:SetScript("OnEvent", function()
		if dialog:IsShown() and (dialog.activeIndex ~= bar.index or not bar:IsShown()) then Start() end
	end)
	if dialog:IsShown() then Start() end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	dialog = PVPReadyDialog
	if dialog then Build() end
end)

ns.Ready = { Bar = function() return bar end, Words = Words }
