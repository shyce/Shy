-- The Group Finder: your roles, the run's listing, and opening ShyGroup in
-- place of the default window. A description can only be typed in Blizzard's
-- own edit box, and so can a custom listing, which is nothing but one.
-- Create / Update / Remove need a hardware event: call only from a click.
-- In instances and encounters the entry's activities are secret.

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local L = {}
ns.Listing = L

local LISTING_TAB, WHO_TAB = 1, 3

-- GetGeneralPlaystyleString is in a file this client doesn't load; the global strings exist.
L.STYLES = {
	{ value = Enum.LFGEntryGeneralPlaystyle.Learning,   text = GROUP_FINDER_GENERAL_PLAYSTYLE1 },
	{ value = Enum.LFGEntryGeneralPlaystyle.FunRelaxed, text = GROUP_FINDER_GENERAL_PLAYSTYLE2 },
	{ value = Enum.LFGEntryGeneralPlaystyle.FunSerious, text = GROUP_FINDER_GENERAL_PLAYSTYLE3 },
	{ value = Enum.LFGEntryGeneralPlaystyle.Expert,     text = GROUP_FINDER_GENERAL_PLAYSTYLE4 },
}

function L.StyleName(value)
	value = value or T.db.playstyle
	for _, style in ipairs(L.STYLES) do
		if style.value == value then return style.text end
	end
	return ""
end

function L.Available()
	return C_LFGInfo.IsGroupFinderEnabled()
		and C_LFGList.GetPremadeGroupFinderStyle() == Enum.PremadeGroupFinderStyle.Vanilla
		and C_LFGInfo.CanPlayerUsePremadeGroup()
end

function L.CanEdit()
	return not IsInGroup(LE_PARTY_CATEGORY_HOME) or UnitIsGroupLeader("player", LE_PARTY_CATEGORY_HOME)
end

-- Your listing's activity ids; nil with no listing or a secret one.
local function Activities()
	if not C_LFGList.HasActiveEntryInfo() then return nil end
	local entry = C_LFGList.GetActiveEntryInfo()
	if not entry or issecretvalue(entry) then return nil end
	local ids = entry.activityIDs
	if not ids or issecretvalue(ids) then return nil end
	for _, id in ipairs(ids) do
		if issecretvalue(id) then return nil end
	end
	return ids
end

local function ForRun(d, run)
	return run ~= nil and (d.key == run.key or (d.kind == "custom" and run.key == "custom"))
end

-- none | run | other | hidden (listed, but the activities are secret)
function L.State()
	if not C_LFGList.HasActiveEntryInfo() then return "none" end
	local ids = Activities()
	if not ids then return "hidden" end
	local run = ns.Run.Get()
	for _, id in ipairs(ids) do
		local d = D.byActivity[id]
		if d and ForRun(d, run) then return "run" end
	end
	return "other"
end

-- The dungeons, raids and zones your listing names.
function L.Dungeons()
	local out, seen = {}, {}
	for _, id in ipairs(Activities() or {}) do
		local d = D.byActivity[id]
		if d and d.kind ~= "custom" and not seen[d] then
			seen[d] = true
			out[#out + 1] = d
		end
	end
	return out
end

-- The listing's description: a protected string that can be shown, not read.
-- nil when there is none.
function L.Comment()
	if not C_LFGList.HasActiveEntryInfo() then return nil end
	local entry = C_LFGList.GetActiveEntryInfo()
	if not entry or issecretvalue(entry) then return nil end
	local comment = entry.comment
	if not comment or issecretvalue(comment) or comment == "" then return nil end
	return comment
end

-- The style the listing is up with; nil when unknown.
function L.Style()
	if not C_LFGList.HasActiveEntryInfo() then return nil end
	local entry = C_LFGList.GetActiveEntryInfo()
	if not entry or issecretvalue(entry) then return nil end
	local style = entry.generalPlaystyle
	if style == nil or issecretvalue(style) then return nil end
	return style
end

-- How long the listing has been up, in seconds; nil when unknown.
function L.Age()
	if not C_LFGList.HasActiveEntryInfo() then return nil end
	local entry = C_LFGList.GetActiveEntryInfo()
	if not entry or issecretvalue(entry) then return nil end
	local duration = entry.duration
	if not duration or issecretvalue(duration) then return nil end
	return duration
end

-- Roles: the ticks the Group Finder shows on your own listing. The game keeps them.

local function Write(roles)
	C_LFGListRoles.SetRoles({ tank = roles.tank or false, healer = roles.healer or false, dps = roles.dps or false })
end

function L.Roles()
	local roles = C_LFGListRoles.GetRoles()
	if not roles or issecretvalue(roles) then return { tank = false, healer = false, dps = false } end
	return { tank = roles.tank or false, healer = roles.healer or false, dps = roles.dps or false }
end

-- The one role ticked; nil when none or several.
function L.SoloRole()
	local roles = L.Roles()
	local only
	for _, role in ipairs(D.ROLES) do
		if roles[role] then
			if only then return nil end
			only = role
		end
	end
	return only
end

-- Ticking a role on makes it your seat in the run; ticking your seat off hands
-- the seat to another ticked role, or back to a guess.
function L.ToggleRole(role)
	local roles = L.Roles()
	roles[role] = not roles[role]
	Write(roles)
	local me = ns.Me()
	if roles[role] then
		ns.Run.SetRole(me, role)
	elseif ns.char.role == role then
		local other
		for _, r in ipairs(D.ROLES) do
			if roles[r] then
				other = r
				break
			end
		end
		if other then
			ns.Run.SetRole(me, other)
		else
			ns.char.role = nil
			local run = ns.Run.Get()
			if run then
				run.roles[me] = nil
				ns.Run.FillRoles()
			end
		end
	end
	ns.Changed()
end

-- Solo, the listing shows your ticked roles: make sure your seat in the run is
-- among them, unless that seat is a guess. Other ticks are kept.
function L.SyncRoles()
	if IsInGroup(LE_PARTY_CATEGORY_HOME) then return end
	local run = ns.Run.Get()
	local me = ns.Me()
	local role = run and run.roles[me] or ns.char.role
	if not role or (run and ns.Run.IsGuess(me)) then return end
	local roles = L.Roles()
	if roles[role] then return end
	roles[role] = true
	Write(roles)
end

-- Listing and unlisting

-- "List me" alone, "List the group" as its leader, "Update" when listed for something else.
function L.Verb()
	local state = L.State()
	if state == "other" then return "Update" end
	if state == "run" then return "Remove" end
	return IsInGroup(LE_PARTY_CATEGORY_HOME) and "List the group" or "List me"
end

function L.Post()
	local run = ns.Run.Get()
	if not run or not L.CanEdit() then return end
	local d = D.byKey[run.key]
	if not d then
		-- A run of your own is listed under Custom, in words the game's own box takes.
		L.OpenBlizzard(LISTING_TAB)
		return
	end
	local data = { activityIDs = d.ids, newPlayerFriendly = T.db.friendly }
	if C_LFGList.HasActiveEntryInfo() then
		C_LFGList.UpdateListing(data)
	else
		data.generalPlaystyle = T.db.playstyle
		C_LFGList.CreateListing(data)
	end
	L.SyncRoles()
end

function L.Remove()
	if C_LFGList.HasActiveEntryInfo() and L.CanEdit() then C_LFGList.RemoveListing() end
end

-- Takeover: post-hooks on LFGVanilla_ShowFrame / ToggleFrame close Blizzard's
-- window in the same frame and open ShyGroup, except on the Who tab and in combat.

local own = false   -- true while L.OpenBlizzard is showing the default window
local took          -- last takeover: when, and whether ShyGroup was already open

local function AfterShow()
	if own or not T.db.takeover or InCombatLockdown() then return end
	if LFGParentFrame.selectedTab == WHO_TAB then return end
	HideUIPanel(LFGParentFrame)
	took = { at = GetTime(), wasOpen = ns.char.open }
	-- Not a hardware event when a meeting stone opened the window, so no search here.
	ns.Window.SetOpen(true)
end

-- The toggle key closes ShyGroup again if it was open before the takeover.
-- The key or button that toggled is a hardware event: the Group Finder can be asked now.
local function AfterToggle()
	if took and took.at == GetTime() then
		if took.wasOpen then ns.Window.SetOpen(false) else ns.Search.Auto() end
	end
	took = nil
end

-- tab: the listing tab by default; L.WHO for the Who list.
L.WHO = WHO_TAB

function L.OpenBlizzard(tab)
	GroupFinderVanillaStyle_LoadUI()
	own = true
	LFGVanilla_ShowFrame(tab or LISTING_TAB)
	own = false
end

-- The game's Who list, with its search box ready to type in. Its box lets go of
-- focus as the tab shows, so the focus comes a frame later.
function L.OpenWho()
	L.OpenBlizzard(WHO_TAB)
	C_Timer.After(0, function()
		local box = rawget(_G, "WhoFrameEditBox")
		if box and box:IsVisible() then box:SetFocus() end
	end)
end

-- The description is typed in the game's own box, which its listing tab shows
-- only while something is listed: the window opens there with the box focused.
function L.OpenDescription()
	if not C_LFGList.HasActiveEntryInfo() then return end
	L.OpenBlizzard(LISTING_TAB)
	C_Timer.After(0, function()
		local frame = rawget(_G, "LFGListingFrame")
		local view = frame and frame.ActivityView
		local box = view and view.Comment and view.Comment.EditBox
		if box and box:IsVisible() then box:SetFocus() end
	end)
end

function L.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("LFG_LIST_ACTIVE_ENTRY_UPDATE")
	events:RegisterEvent("LFG_LIST_ENTRY_CREATION_FAILED")
	events:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TIMEOUT")
	events:RegisterEvent("LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS")
	events:RegisterEvent("LFG_LIST_ROLE_UPDATE")
	events:RegisterEvent("LFG_LIST_AVAILABILITY_UPDATE")
	events:SetScript("OnEvent", function(_, event)
		if event == "LFG_LIST_ENTRY_CREATION_FAILED" then
			T:Print("couldn't list your group. Try again in a moment.")
		elseif event == "LFG_LIST_ENTRY_EXPIRED_TIMEOUT" then
			T:Print("your Group Finder listing expired. List again from the Run tab.")
		elseif event == "LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS" then
			T:Print("your group is full, so your Group Finder listing came down.")
		elseif event == "LFG_LIST_AVAILABILITY_UPDATE" then
			D.Init()
			ns.Parse.Rebuild(T.db.extraWords)
		end
		ns.Changed()
	end)
	EventUtil.ContinueOnAddOnLoaded("Blizzard_GroupFinder_VanillaStyle", function()
		hooksecurefunc("LFGVanilla_ShowFrame", AfterShow)
		hooksecurefunc("LFGVanilla_ToggleFrame", AfterToggle)
	end)
end
