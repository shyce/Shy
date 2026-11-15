-- The quest survey: asks the server about every quest the data knows, once, so that what it says of
-- each (which quest it offers next, its levels) can be read back into the data for everyone.
-- /shyquest survey starts it. It goes on across sessions until it is done, two quests a second out
-- of fights and loading screens, and stops by itself when the server stops answering. Only on an
-- account gathering quest data (/shyquest dev): players get the answers in the addon's own files.

local ADDON, ns = ...
local T = ns.T

local S = {}
ns.Survey = S

local PACE = 0.5             -- seconds between questions
local ABREAST = 20           -- questions out without an answer before it waits
local PATIENCE = 30          -- seconds it waits for one before stopping
local SETTLE = 10            -- seconds after entering the world before it goes on
local ID = "shyquest.survey"
local HELP = "|cff888888/shyquest survey stop|r ends it."

local ids                    -- every quest the data knows, in order
local running, loading = false, false
local asked = {}             -- questions out: [quest] = true
local out, heard = 0, 0      -- how many are out; when an answer last came
local run = 0                -- the start this timer chain belongs to

local function Build() return (select(2, GetBuildInfo())) end

local function State()
	local s = T.db.survey
	if not s then
		s = { build = "", at = 0, answered = 0, missing = {}, done = false }
		T.db.survey = s
	end
	return s
end

local function Ids()
	if not ids then
		ids = {}
		for id in pairs(ns.data.quests) do ids[#ids + 1] = id end
		table.sort(ids)
	end
	return ids
end

local function Minutes(count) return math.max(1, math.ceil(count * PACE / 60)) end

local function Busy() return loading or InCombatLockdown() end

local function Post()
	local s, total = State(), #Ids()
	Shy.Notices.Post(ID, {
		order = 60, glyph = "talk", color = Shy.UI.colors.hot,
		text = ("%d%%"):format(math.floor(100 * s.at / total)),
		title = "Quest survey",
		says = "Click stops it.",
		note = ("%d of %d asked, about %d min left"):format(s.at, total, Minutes(total - s.at)),
		click = function() S.Stop() end,
	})
end

local function Finish()
	local s = State()
	s.done, s.build, running = true, Build(), false
	run = run + 1
	Shy.Notices.Clear(ID)
	T:Print(("quest survey done: %d quests answered, %d unknown to the server. Log out once to save the answers."):format(s.answered, #s.missing))
end

function S.Stop(why)
	if not running then return end
	running = false
	run = run + 1
	Shy.Notices.Clear(ID)
	local s = State()
	T:Print(("quest survey %s at %d of %d. |cff888888/shyquest survey|r goes on with it."):format(why or "stopped", s.at, #Ids()))
end

local function Step(mine)
	if mine ~= run or not running then return end
	local s, list = State(), Ids()
	if not Busy() then
		if s.at >= #list then
			if out == 0 or GetTime() - heard > PATIENCE then return Finish() end
		elseif out >= ABREAST then
			if GetTime() - heard > PATIENCE then return S.Stop("paused: the server stopped answering") end
		else
			-- The next quest the client doesn't have yet; the ones it has count as answered.
			local sent = false
			while s.at < #list and not sent do
				s.at = s.at + 1
				local id = list[s.at]
				if HaveQuestData(id) then
					s.answered = s.answered + 1
				else
					asked[id] = true
					out = out + 1
					C_QuestLog.RequestLoadQuestByID(id)
					sent = true
				end
			end
			Post()
			if s.at >= #list and out == 0 then return Finish() end
		end
	end
	C_Timer.After(PACE, function() Step(mine) end)
end

local function Heard(id, success)
	if issecretvalue(id) or issecretvalue(success) or not asked[id] then return end
	asked[id] = nil
	out = math.max(out - 1, 0)
	heard = GetTime()
	local s = State()
	if success then
		s.answered = s.answered + 1
	else
		s.missing[#s.missing + 1] = id
	end
end

local function Start(quiet)
	local s = State()
	if s.build ~= Build() then
		s.build, s.at, s.answered, s.done = Build(), 0, 0, false
		wipe(s.missing)
	end
	running = true
	run = run + 1
	out, heard = 0, GetTime()
	wipe(asked)
	if not quiet then
		local total = #Ids()
		if s.at > 0 then
			T:Print(("quest survey goes on: %d of %d, about %d min left. %s"):format(s.at, total, Minutes(total - s.at), HELP))
		else
			T:Print(("asking the server about %d quests, two a second out of fights: about %d min. Keep playing; %s"):format(total, Minutes(total), HELP))
		end
	end
	Step(run)
end

-- A survey left unfinished goes on by itself, once the world has settled after a login.
function S.Resume()
	local s = State()
	if not T.db.dev or running or s.done or s.at == 0 then return end
	if s.build ~= Build() then
		T:Print("the game was patched since the quest survey began: |cff888888/shyquest survey|r starts it over.")
		return
	end
	C_Timer.After(SETTLE, function()
		if not T.db.dev or running or s.done then return end
		T:Print(("quest survey goes on: %d of %d. %s"):format(s.at, #Ids(), HELP))
		Start(true)
	end)
end

function S.Running() return running end

function S.Report()
	local s = State()
	local lines = {
		("Quest survey. Game build %s; the survey's %s."):format(Build(), s.build ~= "" and s.build or "none yet"),
		("%s: %d of %d quests asked, %d answered, %d unknown to the server."):format(
			s.done and "Done" or running and "Running" or "Stopped", s.at, #Ids(), s.answered, #s.missing),
		"The game keeps the answers in its Cache\\WDB folder, written at logout.",
	}
	if #s.missing > 0 then lines[#lines + 1] = "Unknown: " .. table.concat(s.missing, ", ") end
	return table.concat(lines, "\n")
end

-- /shyquest survey [stop | again | report]
function S.Command(word)
	local s = State()
	if not T.db.dev and word ~= "report" then
		T:Print("the quest survey gathers data for the addon's own files. |cff888888/shyquest dev|r turns that on.")
	elseif word == "stop" then
		if running then S.Stop() else T:Print("no quest survey is running.") end
	elseif word == "report" then
		Shy.UI.ShowCopyBox("ShyQuest: quest survey", S.Report())
	elseif word == "again" then
		if running then S.Stop() end
		s.at, s.answered, s.done = 0, 0, false
		wipe(s.missing)
		Start()
	elseif running then
		local total = #Ids()
		T:Print(("quest survey: %d of %d asked, about %d min left. %s"):format(s.at, total, Minutes(total - s.at), HELP))
	elseif s.done and s.build == Build() then
		T:Print("the quest survey is done for this build. |cff888888/shyquest survey report|r shows it; |cff888888/shyquest survey again|r starts over.")
	else
		Start()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("QUEST_DATA_LOAD_RESULT")
frame:RegisterEvent("LOADING_SCREEN_ENABLED")
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local resumed = false
frame:SetScript("OnEvent", function(_, event, a, b)
	if event == "QUEST_DATA_LOAD_RESULT" then
		Heard(a, b)
	elseif event == "LOADING_SCREEN_ENABLED" then
		loading = true
	elseif event == "LOADING_SCREEN_DISABLED" then
		loading = false
	elseif not resumed then
		resumed = true
		S.Resume()
	end
end)
