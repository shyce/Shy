-- ShyKeys: Kept up: new abilities, the bags, the build
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local Bags, Before, Macro, Pick = ns.Bags, ns.Before, ns.Macro, ns.Pick
local SOON, loading, watched = ns.SOON, ns.loading, ns.watched

---------------------------------------------------------------------------
-- Kept up: new abilities, the bags, the build
---------------------------------------------------------------------------

local watch, waiting, turning, growing, soon

-- The class's keys for this character, when its addon is here: { addon, jobs, opts }.
function Keys.Mine()
	return watched[1]
end

-- Jobs that had nothing to do may have now (a spell trained, food bought): they come to their keys, each said.
local function Grow()
	soon = false
	if InCombatLockdown() then
		growing = true
		return
	end
	growing = false
	for _, entry in ipairs(watched) do
		if Keys.Has(entry.addon) and not Keys.Old(entry.addon) and not Keys.Paused(entry.addon) and (entry.waiting ~= 0 or entry.stale) then
			entry.stale = nil
			local result = Keys.Apply(entry.addon, entry.jobs, entry.opts)
			if result then
				entry.waiting = result.waiting
				for _, job in ipairs(result.new) do
					entry.addon:Print(("%s is on %s now."):format(job.name, Keys.Key(result.at[job.name])))
				end
				for _, job in ipairs(result.moved) do
					entry.addon:Print(("%s moved to %s."):format(job.name, Keys.Key(result.at[job.name])))
				end
			end
		end
	end
end
Keys.Grow = Grow

local function Later()
	if soon then return end
	soon = true
	C_Timer.After(SOON, Grow)
end
Keys.Later = Later

-- Every watched job from the bags whose macro was made here is written again where the bags hold better (or
-- another) now; one not yet on its key comes to it when the bags first hold what it uses. Macros can't be
-- written in a fight: it waits for the end of one.
local function Follow()
	if InCombatLockdown() then
		waiting = true
		return
	end
	waiting = false
	local best               -- the bags, read once and only when a job needs them
	for _, entry in ipairs(watched) do
		local made = entry.addon.db and entry.addon.db.keysMade
		made = made and made[UnitGUID("player")]
		if made and next(made) and not Keys.Old(entry.addon) then
			local before = Before(entry.addon)
			for _, job in ipairs(Keys.Jobs(entry.jobs, entry.opts.build and (entry.opts.build()))) do
				if job.supply and job.key then
					best = best or Bags()
					if made[job.name] and job.item then
						-- (the item itself: another goes on its button, which only a layout may do)
						if Pick(job, best, before) ~= before.last[job.name] then
							entry.stale = true
							Later()
						end
					elseif made[job.name] then
						Macro(job, made, best, before)
					else
						for _, kind in ipairs(job.supply) do
							if best[kind] then
								entry.waiting = nil
								Later()
							end
						end
					end
				end
			end
		end
	end
end
Keys.Follow = Follow

-- The build changed (another was picked, or the talents now fit another): a character whose keys were laid
-- out here has them laid out again for it, and is told. In a fight it waits for the end of it.
local function Turn()
	if InCombatLockdown() then
		turning = true
		return
	end
	turning = false
	local who = UnitGUID("player")
	for _, entry in ipairs(watched) do
		local opts, db = entry.opts, entry.addon.db
		if opts and opts.build and db.keysFollow == true and Keys.Has(entry.addon) and not Keys.Old(entry.addon) and not Keys.Paused(entry.addon) then
			local build, name = opts.build()
			if (db.keysBuild and db.keysBuild[who]) ~= (build or "") then
				local result = Keys.Apply(entry.addon, entry.jobs, opts)
				if result then
					entry.waiting = result.waiting
					entry.addon:Print(("your keys are laid out for %s now."):format(name or "your talents"))
				end
			end
		end
	end
end
Keys.Turn = Turn

function Keys.Watch(addon, jobs, opts)
	watched[#watched + 1] = { addon = addon, jobs = jobs, opts = opts or {} }
	Keys.gen = Keys.gen + 1   -- (whose keys are drawn has changed)
	if watch then return end
	watch = CreateFrame("Frame")
	for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE",
		"ITEM_DATA_LOAD_RESULT", "NEW_MOUNT_ADDED" }) do
		watch:RegisterEvent(event)
	end
	watch:RegisterUnitEvent("UNIT_PET", "player")
	watch:SetScript("OnEvent", function(_, event, item)
		if event == "PLAYER_REGEN_ENABLED" then
			if waiting then Follow() end
			if turning then Turn() end
			if growing then Later() end
		elseif event == "ITEM_DATA_LOAD_RESULT" then
			-- (something in the bags the game hadn't loaded when they were read: it may be food)
			if loading[item] then
				loading[item] = nil
				Follow()
			end
		elseif event == "BAG_UPDATE_DELAYED" or event == "UNIT_PET" then
			Follow()   -- (another pet eats other things)
		else
			Keys.gen = Keys.gen + 1   -- (what you know changed: what the keys show is worked out again)
			if event == "PLAYER_LEVEL_UP" or event == "NEW_MOUNT_ADDED" then   -- (and what in your bags you can use, what you can ride)
				for _, entry in ipairs(watched) do entry.stale = true end
			end
			Later()
		end
	end)
	Shy:On("SHY_BUILD", Turn)
	Shy:On("SHY_TALENTS", Turn)
end

-- What the files after this one use.
ns.Follow, ns.Turn, ns.soon, ns.waiting = Follow, Turn, soon, waiting
ns.watch = watch
