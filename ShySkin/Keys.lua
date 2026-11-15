-- The game's keys and menu bar buttons for a window of ours that stands in for one of the game's (the talent
-- window, the spellbook): while it is taken, every key the player bound to the game's action clicks a button of
-- ours instead (an override binding, which follows the player's changes to their keys), and a button of ours
-- lies over the menu bar's button for it. Bindings are set and dropped out of a fight only (the game refuses
-- them in one); the cover comes and goes at once.
--
--   ns.Keys.Take(id, opts)   -- opts: binding (the game's, "TOGGLETALENTS"), button (the global name of a button of
--                            -- ours the keys click), micro (the menu bar's button), click = function() end (the cover's
--                            -- click), tip = function(cover) end (its hover)
--   ns.Keys.Give(id)         -- the game's keys and button again
--   ns.Keys.Taken(id)

local ADDON, ns = ...
local UI = Shy.UI

local Keys = {}
ns.Keys = Keys

local taken = {}   -- id -> { opts, owner, cover, on }

-- The override bindings: one owner a window, cleared and set again from the player's own keys.
local function Bind(entry)
	ns.AfterCombat("keys:" .. entry.id, function()
		ClearOverrideBindings(entry.owner)
		if not entry.on then return end
		for _, key in ipairs({ GetBindingKey(entry.opts.binding) }) do
			SetOverrideBindingClick(entry.owner, false, key, entry.opts.button)
		end
	end)
end

-- A button over the menu bar's own, the size of it, that clicks ours. The game's button keeps its highlight
-- while the mouse is on the cover.
local function Cover(entry)
	local micro = entry.opts.micro
	if entry.cover or not micro then return entry.cover end
	local cover = CreateFrame("Button", nil, micro)
	cover:SetAllPoints(micro)
	cover:SetFrameLevel(micro:GetFrameLevel() + 5)
	cover:RegisterForClicks("LeftButtonUp")
	cover:SetScript("OnClick", function() entry.opts.click() end)
	cover:SetScript("OnEnter", function(self)
		micro:LockHighlight()
		if entry.opts.tip then entry.opts.tip(self) end
	end)
	cover:SetScript("OnLeave", function(self)
		micro:UnlockHighlight()
		UI.TipHide(self)
	end)
	entry.cover = cover
	return cover
end

function Keys.Take(id, opts)
	local entry = taken[id]
	if not entry then
		entry = { id = id, owner = CreateFrame("Frame") }
		taken[id] = entry
	end
	entry.opts, entry.on = opts, true
	Bind(entry)
	local cover = Cover(entry)
	if cover then cover:Show() end
end

function Keys.Give(id)
	local entry = taken[id]
	if not entry or not entry.on then return end
	entry.on = false
	Bind(entry)
	if entry.cover then
		entry.cover:Hide()
		if entry.opts.micro then entry.opts.micro:UnlockHighlight() end
	end
end

function Keys.Taken(id)
	return taken[id] ~= nil and taken[id].on
end

-- The player changed their keys: every taken binding follows.
local watch = CreateFrame("Frame")
watch:RegisterEvent("UPDATE_BINDINGS")
watch:SetScript("OnEvent", function()
	for _, entry in pairs(taken) do
		if entry.on then Bind(entry) end
	end
end)
