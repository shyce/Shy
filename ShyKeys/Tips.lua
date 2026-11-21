-- ShyKeys: A key's tooltip on the bars, the chat commands, and the bindings' log
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Action, Bags, C, Does = ns.Action, ns.Bags, ns.C, ns.Does
local EMPTY, HOT, Hot, KeyAt = ns.EMPTY, ns.HOT, ns.Hot, ns.KeyAt
local Learns, MakeCard, Owns, Pressable = ns.Learns, ns.MakeCard, ns.Owns, ns.Pressable
local SOON, SUPPLIES, Scheme, Seat = ns.SOON, ns.SUPPLIES, ns.Scheme, ns.Seat
local soon, watch, watched = ns.soon, ns.watch, ns.watched

-- A key's tooltip on the bars
---------------------------------------------------------------------------

-- The bars cut a macro's name short ("Bles..."), so a key's button leads its tooltip with the key: the key that
-- presses it and the key's name whole, what the key is for, and what it comes to cast next. Only on a button a
-- job of the layout stands on: its macro by name, or the item or spell it stands as.
--   Keys.On(slot)       -> { name, key ("Shift + 4"; nil with none), what (nil when the name says it), next } or nil
--   Keys.Carded()       whether the game's tooltip is shown as a card that leads with it (ShyTip's says so); the
--                       game's own tooltip gets the same as lines under what the game says (Keys.Tip)
local tipped = {}            -- the jobs by name, for the state they were read in
local function Named()
	local mine = watched[1]
	if not mine then return nil end
	local build = mine.opts.build and (mine.opts.build())
	local stamp = Keys.gen .. "|" .. tostring(build) .. "|" .. Keys.Scheme()
	if tipped.stamp ~= stamp then
		tipped.stamp, tipped.jobs = stamp, {}
		for _, job in ipairs(Keys.Jobs(mine.jobs, build)) do tipped.jobs[job.name] = job end
	end
	return tipped.jobs, mine
end

-- (ShyTip asks for this on every re-read of a button's card, five times a second: its cost is ShyKeys' own.)
local LEAD = Shy.Clock("keys: what a button's card leads with")

function Keys.On(slot)
	local from = debugprofilestop()
	local jobs, mine = Named()
	local who = UnitGUID("player")
	local made = jobs and mine.addon.db.keysMade and mine.addon.db.keysMade[who]
	if not made then
		LEAD:Lap(debugprofilestop() - from)
		return nil
	end
	local name = C_ActionBar.GetActionText(slot)
	if not (name and made[name]) then
		name = nil
		local before = mine.addon.db.keysBefore and mine.addon.db.keysBefore[who]
		local kind, id = GetActionInfo(slot)
		-- (on a button it was put on, or you moved it to: the same spell on a button of your own is yours)
		for held in pairs(before and before.last or EMPTY) do
			if made[held] and Owns(held, before, kind, id) then
				for _, slots in ipairs({ before.placed[held] or EMPTY, before.pinned[held] or EMPTY }) do
					for _, at in ipairs(slots) do
						if at == slot then name = held end
					end
				end
			end
		end
	end
	local job = name and jobs[name]
	if not job then
		LEAD:Lap(debugprofilestop() - from)
		return nil
	end
	-- What it comes to cast next: the first ability of its story past your level.
	local coming
	local _, _, story = Keys.Story(mine.jobs, mine.opts, mine.addon)
	local level = UnitLevel("player")
	for _, step in ipairs(story[job] or EMPTY) do
		if step.name and step.level > level and (not coming or step.level < coming.level) then coming = step end
	end
	local lead = { name = job.name, key = KeyAt({ slot }, mine.opts), what = job.what ~= job.name and job.what or nil,
		next = coming and ("Next: %s at level %d"):format(coming.name, coming.level) or nil }
	LEAD:Lap(debugprofilestop() - from)
	return lead
end

function Keys.Carded() return false end

function Keys.Tip(tooltip)
	if tooltip ~= GameTooltip or Keys.Carded() then return end
	local owner = tooltip:GetOwner()
	if not owner or owner:IsForbidden() then return end
	local slot = owner.action
	if type(slot) ~= "number" or issecretvalue(slot) then return end
	local lead = Keys.On(slot)
	if not lead then return end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(lead.name, lead.key or "", C.head[1], C.head[2], C.head[3], C.dim[1], C.dim[2], C.dim[3])
	if lead.what then tooltip:AddLine(lead.what, C.dim[1], C.dim[2], C.dim[3], true) end
	if lead.next then tooltip:AddLine(lead.next, C.dim[1], C.dim[2], C.dim[3], true) end
	tooltip:Show()
end
Shy.OnTip(TooltipDataProcessor.AllTypes, "a key's job", Keys.Tip)

Shy:On("SHY_LOGIN", function()
	C_Timer.After(SOON, Hot.Follow)
	C_Timer.After(SOON, function()
		local mine = watched[1]
		if mine and Keys.Old(mine.addon) then
			mine.addon:Print("there's a new key layout. Look at it in /shy keys. Your keys stay as they are until you take it.")
		end
	end)
	local keyboard = CreateFrame("Frame")
	keyboard:RegisterEvent("UPDATE_BINDINGS")
	keyboard:RegisterEvent("PLAYER_REGEN_ENABLED")
	keyboard:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
	keyboard:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	keyboard:SetScript("OnEvent", function(_, event)
		if event == "UPDATE_BINDINGS" then
			Keys.gen = Keys.gen + 1   -- (a key bound in the game's own window: what the keys show is worked out again)
		elseif event == "UPDATE_SHAPESHIFT_FORMS" then
			-- (a form, an aura or a stance learned: 1 2 3 press what you stay in wherever the bar now has it, and a
			-- macro that asks for a form by its place is written again)
			Keys.gen = Keys.gen + 1
			for _, entry in ipairs(watched) do entry.stale = true end
			Keys.Later()
			C_Timer.After(SOON, Hot.Follow)
		elseif event == "EDIT_MODE_LAYOUTS_UPDATED" then
			-- (another layout: a flyout's bar may stand another way, and the number row follows it once it has)
			Keys.gen = Keys.gen + 1
			C_Timer.After(SOON, Hot.Follow)
		elseif HOT.follow then
			Hot.Follow()
		end
	end)
	MakeCard()
	-- It follows your level, your build and how you move.
	-- (and what you can afford at your trainer: your gold, and what you've learned there)
	local watch, soon = CreateFrame("Frame"), false
	-- (and your aura, stance or form going on or off)
	for _, event in ipairs({ "PLAYER_LEVEL_UP", "LEARNED_SPELL_IN_SKILL_LINE", "TRAINER_CLOSED",
		"UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS" }) do
		watch:RegisterEvent(event)
	end
	local function Soon()
		if soon then return end
		soon = true
		C_Timer.After(0.2, function()
			soon = false
			ns.cardBox:Fill()
			Shy:Fire("SHY_KEYS_STANCE")
		end)
	end
	watch:SetScript("OnEvent", Soon)
	-- Gold only while the training is weighed against it: at or past the most it costs, coins change no words.
	Shy:On("SHY_MONEY", function(now, was)
		local most = Keys.goldMost
		if not most or (now >= most and (was or 0) >= most) then return end
		Soon()
	end)
	for _, event in ipairs({ "SHY_BUILD", "SHY_TALENTS", "SHY_KEYS_SCHEME" }) do
		Shy:On(event, function() ns.cardBox:Fill() end)
	end
end)

Shy.Command("guide", "how to play at your level, on screen or put away", function()
	Keys.ShowGuide(not Keys.GuideShown())
end)

Shy.Command("keys", "your keys, and what comes to them as you level", function()
	Shy.Hub.Open("keys")
end)

-- Why your keys are as they are, as text: every job, the key it stands on or what it waits for, and what in your
-- bags each of the bags' keys found. For a copy box: a question about a key is answered by reading it.
function Keys.Report()
	local mine = watched[1]
	if not mine then return "No keys for this class." end
	local opts = mine.opts
	local build, buildName
	if opts.build then build, buildName = opts.build() end
	local who = UnitGUID("player")
	local made = mine.addon.db.keysMade and mine.addon.db.keysMade[who] or EMPTY
	local before = mine.addon.db.keysBefore and mine.addon.db.keysBefore[who]
	local pinned = before and before.pinned or EMPTY
	local jobs = Keys.Jobs(mine.jobs, build)
	local best, known = Bags(), {}
	local seats = Seat(jobs, opts, made, best, Learns(opts.knows), known, pinned, before and before.last)
	local lines = {
		("Level %d %s, %s, moving with %s."):format(UnitLevel("player"), (UnitClass("player")), buildName or "no build", Scheme().name),
		Keys.Has(mine.addon) and (Keys.Old(mine.addon) and "Laid out by an earlier layout: nothing changes until you take the new one."
			or ("Laid out, on %s."):format(Keys.Mode() == "shy" and "the hotkeys set up for you" or "your own hotkeys"))
			or "Not laid out: this is what a layout would do.",
		"",
	}
	for _, job in ipairs(jobs) do
		local seat = seats[job]
		local says
		if not job.key then
			says = "no key for the way you move"
		elseif seat and pinned[job.name] then
			says = (KeyAt(pinned[job.name], opts) or "no key") .. "  (where you put it)"
		elseif seat then
			local busy = not Pressable(seat, opts, seat == job.key and job.spare or nil) and Action(seat)
			says = Keys.Key(seat) .. (seat ~= job.key and ("  (its own key is %s: it stands here until that key's ability is learned)"):format(Keys.Key(job.key)) or "")
				.. (busy and busy ~= "" and ("  BUT that key does %s now, so it can't stand there"):format(GetBindingName(busy)) or "")
		elseif job.supply then
			says = ("waits on %s: none in your bags (%s)"):format(Keys.Key(job.key), table.concat(job.supply, " or "))
		else
			local does = Does(job, known, opts.shifts)
			says = ("waits on %s: %s"):format(Keys.Key(job.key), does and #does > 0 and "another key already casts what it would" or "not learned yet")
		end
		lines[#lines + 1] = ("%-18s %s"):format(job.name, says)
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "In your bags:"
	local kinds = {}
	for kind in pairs(SUPPLIES) do kinds[#kinds + 1] = kind end
	table.sort(kinds)
	for _, kind in ipairs(kinds) do
		local item = best[kind]
		lines[#lines + 1] = ("%-18s %s"):format(kind, item and (C_Item.GetItemNameByID(item) or ("item " .. item)) or "none you can use")
	end
	return table.concat(lines, "\n")
end

Shy.Command("why", "why each of your keys is where it is, or what it waits for", function()
	UI.ShowCopyBox("Your keys", Keys.Report())
end)

---------------------------------------------------------------------------
-- Every change to your key bindings, whoever makes it
---------------------------------------------------------------------------

-- What changed your keys, and when: every binding set or let go, every set of them loaded or saved, by this
-- addon, the game's own window or anything else, with the file that asked (ShyKeysDB.keysLog, the last 80, kept
-- through a reload). At each log-in, which key bindings are in use and what a few keys do. /shy bindings shows it.
HOT.logMost = 80
local function Noted(what)
	local db = DB()
	if not db then return end
	db.keysLog = db.keysLog or {}
	local log = db.keysLog
	-- (the file that asked: the first line of the stack past this one)
	local who = "?"
	for line in (debugstack(3) or ""):gmatch("[^\n]+") do
		local file, at = line:match("Interface/AddOns/([^%]\"]+%.lua)[^:]*:(%d+)")
		if file and not file:find("ShyCore/Keys.lua", 1, true) then
			who = file .. ":" .. at
			break
		elseif file then
			who = file .. ":" .. at
			break
		end
	end
	log[#log + 1] = ("%s  set %s  %s  (%s)"):format(date("%H:%M:%S"), tostring(GetCurrentBindingSet()), what, who)
	while #log > HOT.logMost do table.remove(log, 1) end
end
for _, name in ipairs({ "SetBinding", "SetBindingClick", "SetBindingSpell", "SetBindingMacro", "SetBindingItem" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function(key, command)
			Noted(("%s %s = %s"):format(name, tostring(key), tostring(command)))
		end)
	end
end
for _, name in ipairs({ "LoadBindings", "SaveBindings" }) do
	if type(_G[name]) == "function" then
		hooksecurefunc(name, function(set) Noted(("%s(%s)"):format(name, tostring(set))) end)
	end
end
do
	local login = CreateFrame("Frame")
	login:RegisterEvent("PLAYER_LOGIN")
	login:SetScript("OnEvent", function()
		Noted(("logged in: Q = %s, E = %s, 1 = %s, C = %s, Mouse 4 = %s"):format(GetBindingAction("Q"), GetBindingAction("E"),
			GetBindingAction("1"), GetBindingAction("C"), GetBindingAction("BUTTON4")))
	end)
end

-- (For finding faults: every change to your key bindings lately, and who made it. Not listed.)
Shy.Command("bindings", nil, function()
	local log = DB() and DB().keysLog
	UI.ShowCopyBox("Your key bindings, as they changed", log and #log > 0 and table.concat(log, "\n") or "No change to your key bindings yet.")
end)
