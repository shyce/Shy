-- The micro menu (Edit Mode's "Menu"): each button becomes a slot.
-- Blizzard shows PushedBackground while a button's window is open, so that texture carries the glow.
-- The game menu button keeps its color: Blizzard turns it green, yellow or red while downloading.
--
-- A button's alert (the game's help tip saying you have unopened items in your collection, a talent to
-- spend, ...) is said on the family's card beside the menu, or beside the drawer's pull while a drawer
-- holds the menu (tucked, its buttons stand far too small to point at). The game's tip still decides
-- when an alert shows and goes; while the card speaks for it, it is only faded and deaf, and it gets both
-- back as it closes. The card's face and its x are secure clicks on the game's own buttons (the micro
-- button, the tip's close), so the game hears them as yours and nothing of its own is written by us:
-- two buttons of ours laid over the card by coordinates out of a fight, put away as one begins.

local ADDON, ns = ...
local UI = Shy.UI
local C = Shy.Skin.colors

local INSET = 3     -- buttons overlap their neighbours by a few pixels
local OPEN = 0.6    -- alpha of an open window's glow; Blizzard only shows and hides that texture

local function PaintButton(kit, button)
	kit:Hide(button.Background)
	kit:Tile(button, { x = INSET, y = INSET })
	kit:Lit(button.PushedBackground, button, UI.colors.fill, INSET, INSET)
	kit:Fade(button.PushedBackground, OPEN)
	kit:Button(button, C.glyph, C.lit, C.hover, button == MainMenuMicroButton)
end

-- Blizzard parents every micro button it uses to the menu.
local function PaintButtons(kit)
	for _, child in ipairs({ MicroMenu:GetChildren() }) do
		if child.Background and child.PushedBackground then PaintButton(kit, child) end
	end
end

-- The alerts

local SYSTEM = "MicroButtons"   -- the help tips the micro menu's alerts are shown as
local CARD = "shyskin.alert"    -- the card's Shy.Hover.Stay id
local GAP = 6                   -- between the card and what it stands beside

local alert = {}                -- tip (the game's help tip), button (its micro button), text
local deaf = {}                 -- tip -> what it had before it was faded and deafened
local hooked = {}               -- tips whose OnHide is followed (they are pooled and reused)
local keys                      -- { face, close }: the secure buttons over the card

-- The button's name as its tooltip says it, without the key bound to it.
local function Name(button)
	local words = button and button.tooltipText
	if type(words) ~= "string" then return nil end
	words = UI.PlainText(words):gsub("%s*%b()%s*$", "")
	return words ~= "" and words or nil
end

-- Beside the menu, toward the middle of the screen: on the left of a menu in the right half, hung from its
-- top in the upper half and stood on its foot in the lower.
local function Where(button)
	local anchor = button:GetParent() or button
	local _, pull = Shy.Drawer.Holding(button)
	if pull then anchor = pull end
	local x, y = anchor:GetCenter()
	local left, top = true, true
	if x and y and not issecretvalue(x) and not issecretvalue(y) then
		local s = anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
		left = x * s > UIParent:GetWidth() / 2
		top = y * s > UIParent:GetHeight() / 2
	end
	local edge = top and "TOP" or "BOTTOM"
	if left then return { edge .. "RIGHT", anchor, edge .. "LEFT", -GAP, 0 } end
	return { edge .. "LEFT", anchor, edge .. "RIGHT", GAP, 0 }
end

local function Deafen(tip)
	if deaf[tip] then return end
	deaf[tip] = { alpha = tip:GetAlpha(), mouse = tip:IsMouseEnabled(),
		close = tip.CloseButton and tip.CloseButton:IsMouseEnabled(), okay = tip.OkayButton and tip.OkayButton:IsMouseEnabled() }
	tip:SetAlpha(0)
	tip:EnableMouse(false)
	if tip.CloseButton then tip.CloseButton:EnableMouse(false) end
	if tip.OkayButton then tip.OkayButton:EnableMouse(false) end
end

local function Hear(tip)
	local was = deaf[tip]
	if not was then return end
	deaf[tip] = nil
	tip:SetAlpha(was.alpha)
	tip:EnableMouse(was.mouse)
	if tip.CloseButton then tip.CloseButton:EnableMouse(was.close) end
	if tip.OkayButton then tip.OkayButton:EnableMouse(was.okay) end
end

local function PutKeysAway()
	if not keys or InCombatLockdown() then return end
	keys.face:Hide()
	keys.close:Hide()
	keys.at = nil
end

-- The card goes and the game's tip is its own again.
local function Let()
	local tip = alert.tip
	alert.tip, alert.button, alert.text = nil, nil, nil
	if tip then Hear(tip) end
	Shy.Hover.Stay(CARD, nil)
	PutKeysAway()
end

-- A key over a region of the card, in UIParent's units.
local function Cover(key, card, region, level)
	local left, bottom, width, height = region:GetRect()
	if not (left and bottom and width and height) or issecretvalue(left) then
		key:Hide()
		return false
	end
	local s = region:GetEffectiveScale() / UIParent:GetEffectiveScale()
	key:SetFrameStrata(card:GetFrameStrata())
	key:SetFrameLevel(card:GetFrameLevel() + level)
	key:ClearAllPoints()
	key:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * s, bottom * s)
	key:SetSize(width * s, height * s)
	key:Show()
	return true
end

-- The keys over the card where it stands now (out of a fight only: they are the game's secure buttons).
local function Lay()
	if not keys or InCombatLockdown() then return end
	local card, tip = Shy.Hover.Staying(CARD), alert.tip
	if not (card and tip and tip:IsShown()) then
		PutKeysAway()
		return
	end
	keys.face:SetAttribute("clickbutton", alert.button)
	keys.close:SetAttribute("clickbutton", tip.CloseButton)
	if not Cover(keys.face, card, card, 20) then return end
	if card.x and card.x:IsShown() and tip.CloseButton then
		Cover(keys.close, card, card.x, 30)
	else
		keys.close:Hide()
	end
	keys.at = { card:GetRect() }
end

-- The card moved or grew (its hints slid down, the menu was dragged): the keys follow.
local function Moved(card)
	local at = keys.at
	if not at then return true end
	local left, bottom, width, height = card:GetRect()
	return left ~= at[1] or bottom ~= at[2] or width ~= at[3] or height ~= at[4]
end

local function Keys()
	if keys then return keys end
	local function Key(name)
		local key = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
		key:RegisterForClicks("AnyUp", "AnyDown")
		key:SetAttribute("type1", "click")
		key:Hide()
		return key
	end
	keys = { face = Key("ShySkinAlertKey"), close = Key("ShySkinAlertClose") }
	-- The x lights under the mouse as it does when nothing lies over it.
	local function Pass(script)
		return function()
			local card = Shy.Hover.Staying(CARD)
			local x = card and card.x
			local fn = x and x:GetScript(script)
			if fn then fn(x) end
		end
	end
	keys.close:SetScript("OnEnter", Pass("OnEnter"))
	keys.close:SetScript("OnLeave", Pass("OnLeave"))
	keys.face:SetScript("OnUpdate", Shy.Clocked("frame: menu alert keys", function()
		if InCombatLockdown() then return end
		local card = Shy.Hover.Staying(CARD)
		if not (card and alert.tip) then
			PutKeysAway()
		elseif Moved(card) then
			Lay()
		end
	end))
	return keys
end

-- The game's tip closed (its own x, its window opened, another alert came first): so does the card.
local function Closed(tip)
	if alert.tip == tip then Let() end
end

-- x on the card in a fight, where the keys can't be laid: the card goes, and the game's tip stays quiet
-- until the game closes it.
local function Dismiss()
	Shy.Hover.Stay(CARD, nil)
end

local function Take(tip)
	local info = tip.info
	local button = tip.relativeRegion
	if not (info and button) then return end
	if alert.tip and alert.tip ~= tip then Let() end
	if not hooked[tip] then
		hooked[tip] = true
		tip:HookScript("OnHide", Closed)
	end
	alert.tip, alert.button, alert.text = tip, button, info.text
	Deafen(tip)
	local name = Name(button)
	Shy.Hover.Stay(CARD, { title = name, text = info.text, hints = { { "left", name and ("Open " .. name) or "Open" } } },
		{ at = Where(button), onClose = Dismiss })
	Keys()
	Lay()
end

-- The micro menu's alert showing now, if any.
local function Showing()
	for tip in HelpTip.framePool:EnumerateActive() do
		if tip.info and tip.info.system == SYSTEM then return tip end
	end
end

ns.MenuAlert = { Parts = function() return alert, keys, deaf end, Name = Name, Where = Where }

ns.Module({
	id = "menu",
	title = "Menu",
	desc = "Restyles the micro menu buttons as steel-framed slots that light up on hover and glow while their window is open, and shows their alerts on a card beside the menu.",

	Hook = function(m)
		-- Blizzard swaps the icons' art whenever a window opens or closes.
		hooksecurefunc("UpdateMicroButtons", function()
			if m.on then PaintButtons(m.kit) end
		end)
		hooksecurefunc(HelpTip, "Show", function(_, _, info)
			if not (m.on and info and info.system == SYSTEM) then return end
			for tip in HelpTip.framePool:EnumerateActive() do
				if tip.info == info then
					Take(tip)
					return
				end
			end
		end)
		-- The keys are secure: away as a fight begins, back over the card once it ends.
		local fight = CreateFrame("Frame")
		fight:RegisterEvent("PLAYER_REGEN_DISABLED")
		fight:RegisterEvent("PLAYER_REGEN_ENABLED")
		fight:SetScript("OnEvent", function(_, event)
			if not keys then return end
			if event == "PLAYER_REGEN_DISABLED" then
				keys.face:Hide()
				keys.close:Hide()
				keys.at = nil
			else
				Lay()
			end
		end)
	end,

	Paint = function(m, kit)
		kit:Hide(MicroMenu.BorderArt)
		kit:Hide(MicroMenu.BackgroundArt)
		PaintButtons(kit)
		local tip = Showing()
		if tip then Take(tip) end
	end,

	Clear = function()
		Let()
	end,
})
