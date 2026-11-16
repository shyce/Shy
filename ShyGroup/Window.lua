-- The main window: the core's UI.Window. The header drags it and holds the emblem, tabs and
-- buttons; one page per tab. Esc closes.

local ADDON, ns = ...
local T = ns.T
local UI = Shy.UI
local W = ns.W
local Win = {}
ns.Window = Win

Win.WIDTH, Win.HEIGHT = 820, 660
Win.HEADER = UI.HEAD.main.line + UI.LINE   -- the header, down to its line's foot

local TABS = { "Run", "Replies", "Browse" }
Win.RUN, Win.REPLIES, Win.BROWSE = 1, 2, 3
local box, tabs, who
local pages = {}

local function Refresh()
	if not box or not box:IsShown() then return end
	tabs:SetBadge(Win.REPLIES, ns.People.Unread())
	who:SetShown(ns.Listing.Available())
	pages[ns.char.tab]:Refresh()
end

local function SelectTab(i)
	ns.char.tab = i
	for j, page in ipairs(pages) do page:SetShown(j == i) end
	Refresh()
end

-- look: this comes from the player's own click or key, so the Group Finder may
-- be asked for its listings now (a search needs a hardware event).
function Win.SetOpen(open, tab, look)
	ns.char.open = open
	if tab then tabs:Select(tab) end
	Shy.HUD.Update(box)
	Refresh()
	if open and look then ns.Search.Auto() end
	ns.Changed()   -- the status box is shown only while the window is closed
end

function Win.ShowThread(name)
	ns.Replies.Select(name)
	Win.SetOpen(true, Win.REPLIES)
end

function Win.Init()
	box = UI.Window({
		id = "shygroup",
		name = "ShyGroupWindow",
		title = "ShyGroup window",
		width = Win.WIDTH,
		height = Win.HEIGHT,
		point = { "CENTER", "CENTER", 0, 30 },
		shown = function() return ns.char.open end,
		onClose = function()
			if not ns.char.open then return end
			ns.char.open = false
			ns.Changed()
		end,
		close = function() Win.SetOpen(false) end,
		head = {
			brand = T.suffix, icon = T.mark, tabs = { TABS, SelectTab },
			-- The Who list stays the game's own.
			buttons = { { "Options", 76, function() T:OpenOptions() end }, { "Who", 54, function() ns.Listing.OpenWho() end } },
		},
	})
	tabs = box.head.tabs
	-- A tab clicked by hand is a hardware event: the Group Finder can be asked.
	for _, t in ipairs(tabs.tabs) do
		t:HookScript("OnClick", function() ns.Search.Auto() end)
	end
	who = box.head.buttons[2]
	W.Tip(who, "Who list", "Opens the Group Finder's Who tab, ready to type a name, guild or level.")

	-- The pages stand on the window's body: clear of its look's work round the edge (UI.Body).
	local body = UI.Body(box)
	for i, create in ipairs({ ns.Recruit.Create, ns.Replies.Create, ns.BoardTab.Create }) do
		local page = CreateFrame("Frame", nil, body)
		page:SetPoint("TOPLEFT", 0, -Win.HEADER)
		page:SetPoint("BOTTOMRIGHT")
		page:Hide()
		create(page)
		pages[i] = page
	end
	tabs:Select(ns.char.tab)

	ns.OnChange(Refresh)
	-- Keeps "2m" ages and countdowns current, while the window is up: closed, nothing ticks.
	local ticker
	box:HookScript("OnShow", function()
		if not ticker then ticker = C_Timer.NewTicker(1, Refresh) end
	end)
	box:HookScript("OnHide", function()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
	end)
	if box:IsShown() then ticker = C_Timer.NewTicker(1, Refresh) end
end
