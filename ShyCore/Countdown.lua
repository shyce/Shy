-- The days up to WoW Forever: a clock in the minimap's row of buttons (on the rim of a round map) with
-- the time to launch beside it, whose hover counts down to name reservation and to launch. It is gold
-- while names can be reserved and is gone once the game is out.
--
--   Shy.Countdown.Phase(now)   -- "before", "open" (names can be reserved), "soon" (reservation over), "out"
--   Shy.Countdown.Update()     -- looks again (once a second while there is anything to count down to)

local Shy = Shy
local UI = Shy.UI
local C = UI.colors
local core = Shy.core
core.keep.countdown = true   -- its place on a round map's rim, and until when it is hidden: the account's

local K = {}
Shy.Countdown = K

-- The moments by the server's clock (seconds, UTC). Name reservation was announced as a day with no
-- hour: it is taken to start as that day begins on the Pacific coast, and is only ever shown as a date.
local OPENS = 1793084400     -- October 27, 2026, 00:00 Pacific
local CLOSES = 1793779200    -- November 4, 00:00 Pacific: names can be reserved through November 3
local LAUNCH = 1793833200    -- November 4, 15:00 Pacific
K.OPENS, K.CLOSES, K.LAUNCH = OPENS, CLOSES, LAUNCH

local FACE = 27              -- the round face on the rim (the minimap buttons' icon size)
local ANGLE = 240            -- its place on the rim at first, degrees
local WEEKDAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local MONTHS = { "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER",
	"OCTOBER", "NOVEMBER", "DECEMBER" }

function K.Phase(now)
	if now >= LAUNCH then return "out" end
	if now >= CLOSES then return "soon" end
	if now >= OPENS then return "open" end
	return "before"
end

local function Saved()
	core.db.countdown = core.db.countdown or {}
	return core.db.countdown
end

-- A day as a count of days, from date's table: calendar days between two moments where the player is.
local function DayNumber(t)
	local y, m = t.year, t.month
	if m <= 2 then y = y - 1 end
	local era = math.floor(y / 400)
	local years = y - era * 400
	local days = math.floor((153 * ((m + 9) % 12) + 2) / 5) + t.day - 1
	return era * 146097 + years * 365 + math.floor(years / 4) - math.floor(years / 100) + days
end

local function DaysBetween(from, to)
	return DayNumber(date("*t", to)) - DayNumber(date("*t", from))
end

-- "October 27", or with its weekday "Tuesday, October 27": where the player is.
local function Day(t, weekday)
	local d = date("*t", t)
	local words = _G["MONTH_" .. MONTHS[d.month]] .. " " .. d.day
	if not weekday then return words end
	return _G["WEEKDAY_" .. WEEKDAYS[d.wday]] .. ", " .. words
end

local function Hour(t)
	local d = date("*t", t)
	return GameTime_GetFormattedTime(d.hour, d.min, true)
end

local function Days(n)
	if n <= 0 then return "Today" end
	if n == 1 then return "Tomorrow" end
	return n .. " days"
end

-- "21d 04:32:09", the last day "04:32:09".
local function Clock(left)
	left = math.max(0, math.floor(left))
	local d, h, m, s = math.floor(left / 86400), math.floor(left % 86400 / 3600), math.floor(left % 3600 / 60), left % 60
	if d > 0 then return ("%dd %02d:%02d:%02d"):format(d, h, m, s) end
	return ("%02d:%02d:%02d"):format(h, m, s)
end

local function Rows(now, phase)
	local rows = {}
	if phase == "before" then
		rows[#rows + 1] = { text = "Name reservation", right = Days(DaysBetween(now, OPENS)), rightColor = C.hot }
		rows[#rows + 1] = { text = Day(OPENS) .. " to " .. Day(CLOSES - 1), quiet = true, indent = 1 }
	elseif phase == "open" then
		rows[#rows + 1] = { text = "Name reservation", right = "Open now", rightColor = C.alert, lit = true }
		rows[#rows + 1] = { text = "Through " .. Day(CLOSES - 1, true), quiet = true, indent = 1 }
	end
	rows[#rows + 1] = { text = "Launch", right = Clock(LAUNCH - now), rightColor = C.hot }
	rows[#rows + 1] = { text = Day(LAUNCH, true) .. ", " .. Hour(LAUNCH), quiet = true, indent = 1 }
	return rows
end

local button, face
local phase                  -- as last looked at
local ticker

local function Tip(owner)
	local now = GetServerTime()
	UI.Tip(owner, "WoW Forever", nil, {
		side = owner:TipSide(),
		sections = { { rows = Rows(now, K.Phase(now)) } },
		hints = { { "right", "Hide" } },
	})
end

local function Hide()
	Saved().hidden = phase == "before" and OPENS or LAUNCH
	UI.TipHide(button, true)
	K.Update()
end

local function Menu(owner)
	UI.ContextMenu(owner, function(root)
		root:CreateTitle("WoW Forever")
		root:CreateButton(phase == "before" and "Hide until reservation opens" or "Hide until launch", Hide)
	end)
end

function K.Update()
	if not button then return end
	local now = GetServerTime()
	local was = phase
	phase = K.Phase(now)
	if phase == "out" then
		if was ~= "out" then
			UI.TipHide(button, true)
			button:Hide()
		end
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
		return
	end
	local hidden = Saved().hidden
	button:SetShown(not (hidden and now < hidden))
	if phase ~= was then
		-- Gold while names can be reserved; your color before and after.
		local color = phase == "open" and C.alert or C.hot
		button:SetTint(color)
		face:Set("clock", color, phase == "open")
		button:Light(color)
	end
	if Shy.Hover.Owner() == button then Tip(button) end
end

local function Start()
	if button or K.Phase(GetServerTime()) == "out" then return end
	button = Shy.MinimapButton({
		name = "ShyCountdownButton",
		label = "Launch",
		detail = function() return Clock(LAUNCH - GetServerTime()) end,
		icon = function(parent)
			face = Shy.Maps.Mark(parent, FACE)
			return face
		end,
		glyph = function(texture, size) Shy.Hover.Glyph(texture, "clock", size) end,
		getAngle = function() return Saved().angle or ANGLE end,
		setAngle = function(v) Saved().angle = v end,
		onClick = function(self, mouseButton)
			if mouseButton == "RightButton" then Menu(self) end
		end,
		onEnter = Tip,
		onLeave = function(self) UI.TipHide(self) end,
	})
	button:Place()
	K.Update()
	ticker = C_Timer.NewTicker(1, Shy.Clocked("countdown: each second", K.Update))
	Shy.Command("countdown", "show or hide the countdown to launch", function()
		if not button or phase == "out" then return end
		local hidden = Saved().hidden
		if hidden and GetServerTime() < hidden then
			Saved().hidden = nil
			K.Update()
		else
			Hide()
		end
	end)
end

Shy:On("SHY_LOGIN", Start)
