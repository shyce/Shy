-- Error spam, action bar text, player and NPC names, camera, screen effects and the beta issue reporter.

local ADDON, ns = ...

local TakeCVar, ReturnCVar = ns.TakeCVar, ns.ReturnCVar

-- Combat

local SPAM = {}
for _, key in ipairs({
	"ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_MANA", "ERR_OUT_OF_FOCUS",
	"ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "SPELL_FAILED_NOT_READY",
	"SPELL_FAILED_OUT_OF_RANGE", "ERR_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE", "ERR_BADATTACKPOS",
	"SPELL_FAILED_LINE_OF_SIGHT", "ERR_BADATTACKFACING", "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_NOT_BEHIND",
	"ERR_NO_ATTACK_TARGET", "ERR_GENERIC_NO_TARGET", "ERR_INVALID_ATTACK_TARGET", "SPELL_FAILED_BAD_TARGETS",
	"SPELL_FAILED_TARGETS_DEAD", "SPELL_FAILED_NO_COMBO_POINTS", "SPELL_FAILED_SPELL_IN_PROGRESS",
	"SPELL_FAILED_MOVING", "ERR_NOT_WHILE_MOVING", "SPELL_FAILED_CASTER_AURASTATE",
}) do
	if _G[key] then SPAM[_G[key]] = true end
end

ns.Feature({
	id = "hideErrors",
	category = "Combat",
	title = "Hide error spam",
	desc = "The red \"Not enough rage\" and \"Out of range\" lines stay off your screen. Real errors, like full bags, still show.",
	keywords = "error errors red text spam messages rage energy mana range cooldown uierrors hide not ready yet",
	default = true,
	options = {
		{ key = "combatOnly", kind = "checkbox", label = "Only in combat", default = false,
			desc = "Out of a fight, you see every error again." },
	},
	events = {
		UI_ERROR_MESSAGE = function(f, _, messageType, message)
			local hide = not issecretvalue(message) and SPAM[message] and (not f.opt.combatOnly or InCombatLockdown())
			if not hide then UIErrorsFrame:TryDisplayMessage(messageType, message, RED_FONT_COLOR:GetRGB()) end
		end,
	},
	-- UIErrorsFrame stops listening; the handler above re-displays what is kept.
	Enable = function() UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE") end,
	Disable = function() UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE") end,
})

local BAR_PREFIXES = {
	"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
	"MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local function BarText(feature)
	ns.OutOfCombat("barText", function()
		local on = feature.running
		for _, prefix in ipairs(BAR_PREFIXES) do
			for i = 1, 12 do
				local button = _G[prefix .. i]
				if button then
					if button.HotKey then button.HotKey:SetAlpha((on and feature.opt.keybinds) and 0 or 1) end
					if button.Name then button.Name:SetAlpha((on and feature.opt.macros) and 0 or 1) end
				end
			end
		end
	end)
end

-- (Left out while ShySkin's action bars are on: they have the same two switches.)
ns.Feature({
	id = "barText",
	category = "Combat",
	title = "Hide action bar text",
	desc = "Your action buttons lose their keybinds and macro names.",
	keywords = "action bar bars button keybind hotkey macro text name clean hide",
	default = false,
	yields = function()
		local skin = Shy.addons.Skin
		return skin ~= nil and skin.owns ~= nil and skin.owns.barText == true
	end,
	options = {
		{ key = "keybinds", kind = "checkbox", label = "Keybinds", default = true },
		{ key = "macros", kind = "checkbox", label = "Macro names", default = true },
	},
	Enable = BarText,
	Disable = BarText,
	OnOptionChanged = BarText,
})

-- Player names

-- Overhead names are engine-drawn and can't be recolored, so name-only
-- nameplates replace them (Blizzard's CVars), with the name redrawn on top.
-- Friendly plates in instances are forbidden to addons: only the CVars apply there.
-- Nameplates are restricted (no measuring, no reading anchors): Blizzard's name
-- is faded out and a new one drawn over it, never moved.
-- Both names tweaks stand down while ShyPlates draws the nameplates: it writes the names itself.

local FRIENDLY_NAMES = {
	nameplateShowFriendlyPlayers = 1,
	nameplateShowOnlyNameForFriendlyPlayerUnits = 1,
	nameplateUseClassColorForFriendlyPlayerUnitNames = 1,
}
local ALLY_ATLAS = "friendslist-recentallies-yellow"
-- UI.NameFont families: the chosen face for Latin and Cyrillic, Blizzard's fonts for Korean and Chinese.
local FONTS = {
	{ value = "shy", text = "Rounded", font = Shy.FONT_ROUNDED,
		files = { roman = Shy.FONT_ROUNDED, russian = Shy.FONT_ROUNDED } },
	{ value = "game", text = "Game font", font = "Fonts\\FRIZQT__.TTF",
		files = { roman = "Fonts\\FRIZQT__.TTF", russian = "Fonts\\FRIZQT___CYR.TTF" } },
}
local OUTLINES = { none = "", thin = "OUTLINE", thick = "OUTLINE, THICK" }

local classNames, npcNames
local hookedNames
local ourNames = setmetatable({}, { __mode = "k" })    -- plate unit frame -> name string
local ourTitles = setmetatable({}, { __mode = "k" })   -- plate unit frame -> job line under an NPC's name
local faded = setmetatable({}, { __mode = "k" })       -- plate unit frames whose bars are faded out

local function ClassColor(unit)
	local _, class = UnitClass(unit)
	if issecretvalue(class) or not class then return nil end
	return RAID_CLASS_COLORS[class]
end

local function IsRecentAlly(unit)
	local guid = UnitGUID(unit)
	if issecretvalue(guid) or not guid then return false end
	return C_RecentAllies.IsSystemEnabled() and C_RecentAllies.IsRecentAllyByGUID(guid)
end

-- The classic nameplate style turns a name yellow on mouseover.
local function Highlighted(frame)
	if not (frame.optionTable and frame.optionTable.nameMouseoverColor) then return false end
	local over = UnitIsUnit(frame.displayedUnit, "mouseover")
	return not issecretvalue(over) and over
end

local function IsPlate(frame)
	local unit = frame.unit
	return type(unit) == "string" and unit:find("^nameplate") and frame.IsPlayer ~= nil
end

local function PlayerPlate(frame)
	return IsPlate(frame) and frame:IsPlayer()
end

-- "player", "npc", or nil to leave Blizzard's name.
local function Kind(frame)
	if not IsPlate(frame) then return nil end
	local feature = frame:IsPlayer() and classNames or npcNames
	if not feature.running then return nil end
	local wanted = feature.opt.enemy
	if frame:IsFriend() then wanted = feature.opt.friendly end
	if not wanted then return nil end
	return feature == classNames and "player" or "npc"
end

local function NameFont(key, size, flags)
	local look = FONTS[1]
	for _, item in ipairs(FONTS) do
		if item.value == key then look = item end
	end
	return Shy.UI.NameFont(size, flags, look.files, look.value)
end

local function Badge(size)
	return " " .. CreateAtlasMarkup(ALLY_ATLAS, size, size)
end

-- One anchor, so the name is never clipped. A name-only plate anchors at its
-- bottom, lifted by the setting plus `raise` (room for a line underneath).
local function Place(frame, nameOnly, raise)
	local ours = ourNames[frame]
	ours:ClearAllPoints()
	if nameOnly then
		ours:SetPoint("BOTTOM", frame, "BOTTOM", 0, classNames.opt.lift + raise)
	else
		ours:SetPoint("BOTTOM", frame.HealthBarsContainer, "TOP", 0, 3)
	end
end

-- NPCs have no native name-only mode: fade these (never hide or move them;
-- plates are restricted and Blizzard shows and hides the pieces itself).
local BARS = { "HealthBarsContainer", "PlayerLevelDiffFrame", "ClassificationFrame", "AurasFrame" }

local function ShowBars(frame, shown)
	if shown and not faded[frame] then return end
	faded[frame] = not shown or nil
	for _, key in ipairs(BARS) do frame[key]:SetAlpha(shown and 1 or 0) end
end

local function HideTitle(frame)
	local title = ourTitles[frame]
	if title then title:Hide() end
end

local PaintName

local function OurName(frame)
	local ours = ourNames[frame]
	if ours then return ours end
	ours = frame:CreateFontString(nil, "OVERLAY")
	ours:SetWordWrap(false)
	ours:SetJustifyH("CENTER")
	ourNames[frame] = ours
	hooksecurefunc(frame, "UpdateAnchors", function(self)
		if not self:IsForbidden() and ourNames[self]:IsShown() then PaintName(self) end
	end)
	hooksecurefunc(frame.name, "Hide", function() ours:Hide() end)
	hooksecurefunc(frame.name, "Show", function() PaintName(frame) end)
	hooksecurefunc(frame.name, "SetShown", function() PaintName(frame) end)
	return ours
end

-- Font and outline come from classNames for every name; only the size differs.
local function Dress(ours, size)
	local opt = classNames.opt
	ours:SetFontObject(NameFont(opt.font, math.floor(size + 0.5), OUTLINES[opt.outline]))
	ours:SetShadowOffset(1, -1)
	ours:SetShadowColor(0, 0, 0, 0.8)
end

local function NameColor(frame)
	if Highlighted(frame) then
		local c = frame.optionTable.nameMouseoverColor
		return c.r, c.g, c.b
	end
	local c = ClassColor(frame.unit)
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

-- NPC names

-- Reaction colors; must match ShyTip's.
local HOSTILE, NEUTRAL, FRIENDLY, TAPPED = { 1, 0.27, 0.27 }, { 1, 0.85, 0.25 }, { 0.35, 1, 0.40 }, { 0.6, 0.6, 0.6 }
local ELITE = { elite = true, rareelite = true, worldboss = true }
local TITLE_GAP = 2

local function NPCColor(frame)
	if Highlighted(frame) then
		local c = frame.optionTable.nameMouseoverColor
		return c.r, c.g, c.b
	end
	local unit = frame.unit
	local tapped, reaction = UnitIsTapDenied(unit), UnitReaction(unit, "player")
	if issecretvalue(tapped) or issecretvalue(reaction) or not reaction then return 1, 1, 1 end
	local c = tapped and TAPPED or reaction <= 3 and HOSTILE or reaction == 4 and NEUTRAL or FRIENDLY
	return c[1], c[2], c[3]
end

-- Not the target and not in combat. A secret answer counts as busy (full plate).
local function Idle(frame)
	local unit = frame.unit
	local target, fighting = UnitIsUnit(unit, "target"), UnitAffectingCombat(unit)
	if issecretvalue(target) or issecretvalue(fighting) then return false end
	return not target and not fighting
end

-- "  12" or "  12+" (elite) in difficulty color.
local function LevelText(unit)
	local attackable, level, class = UnitCanAttack("player", unit), UnitEffectiveLevel(unit), UnitClassification(unit)
	if issecretvalue(attackable) or issecretvalue(level) or issecretvalue(class) or not attackable then return "" end
	local plus = ELITE[class] and "+" or ""
	if level <= 0 then return "  |cffff4040??" .. plus .. "|r" end
	local c = GetCreatureDifficultyColor(level)
	return ("  |cff%02x%02x%02x%d%s|r"):format(math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5), level, plus)
end

-- A friendly NPC's job ("Innkeeper") is its tooltip's second line, unless that line is its level.
local LEVEL_LINE = TOOLTIP_UNIT_LEVEL:match("^(.-)%%s")
local jobs = {}   -- NPC name -> job, or false for none

local function Job(frame, name)
	if not npcNames.opt.jobs or not frame:IsFriend() or issecretvalue(name) then return nil end
	local job = jobs[name]
	if job == nil then
		job = false
		local data = C_TooltipInfo.GetUnit(frame.unit)
		local line = data and data.lines[2]
		local text = line and line.leftText
		if text and not issecretvalue(text) and text ~= "" and LEVEL_LINE ~= "" and text:sub(1, #LEVEL_LINE) ~= LEVEL_LINE then
			job = text
		end
		jobs[name] = job
	end
	return job or nil
end

local function ShowTitle(frame, text, size)
	local title = ourTitles[frame]
	if not title then
		title = frame:CreateFontString(nil, "OVERLAY")
		title:SetWordWrap(false)
		title:SetJustifyH("CENTER")
		title:SetPoint("TOP", ourNames[frame], "BOTTOM", 0, -TITLE_GAP)
		ourTitles[frame] = title
	end
	Dress(title, size)
	-- Not UI.Ink: the theme reads a region's color back, which a restricted
	-- plate forbids. Repainted on SHY_THEME instead.
	local c = Shy.UI.colors.head
	title:SetTextColor(c[1], c[2], c[3])
	title:SetText(text)
	title:Show()
end

-- Post-hook on CompactUnitFrame_UpdateName.
function PaintName(frame)
	if frame:IsForbidden() then return end
	local ours = ourNames[frame]
	local text = frame.name:GetText()
	local kind = Kind(frame)

	if not kind then
		if ours and ours:IsShown() then
			ours:Hide()
			frame.name:SetAlpha(1)
		end
		HideTitle(frame)
		if IsPlate(frame) then ShowBars(frame, true) end
		-- Not restyled, but a recent ally still gets the badge.
		if classNames.running and classNames.opt.allies and PlayerPlate(frame) and IsRecentAlly(frame.unit)
			and (issecretvalue(text) or text) then
			frame.name:SetText(text .. Badge(12))
		end
		return
	end

	ours = OurName(frame)
	if not frame.name:IsShown() or (not issecretvalue(text) and not text) then
		ours:Hide()
		HideTitle(frame)
		ShowBars(frame, true)
		return
	end

	if kind == "player" then
		ShowBars(frame, true)
		HideTitle(frame)
		Dress(ours, classNames.opt.size)
		Place(frame, frame:IsShowOnlyName(), 0)
		if classNames.opt.allies and IsRecentAlly(frame.unit) then
			text = text .. Badge(math.floor(classNames.opt.size * 0.9 + 0.5))
		end
		ours:SetText(text)
		ours:SetTextColor(NameColor(frame))
	else
		local opt = npcNames.opt
		local idle = Idle(frame)
		local job = idle and Job(frame, text)
		local jobSize = math.max(8, opt.size - 3)
		ShowBars(frame, not idle)
		Dress(ours, opt.size)
		Place(frame, idle, job and (jobSize + TITLE_GAP + 1) or 0)
		ours:SetText(idle and opt.level and (text .. LevelText(frame.unit)) or text)
		ours:SetTextColor(NPCColor(frame))
		if job then ShowTitle(frame, job, jobSize) else HideTitle(frame) end
	end
	frame.name:SetAlpha(0)
	ours:Show()
end

-- Blizzard redraws every visible name; the PaintName hook follows.
local function RefreshNames()
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local frame = not plate:IsForbidden() and plate.UnitFrame
		if frame and frame.unit and not frame:IsForbidden() then CompactUnitFrame_UpdateName(frame) end
	end
end

local function HookNames()
	if hookedNames then return end
	hooksecurefunc("CompactUnitFrame_UpdateName", PaintName)
	hookedNames = true
end

local function ApplyNames(f)
	ns.OutOfCombat("classNames", function()
		local on = f.running
		local friendly = on and f.opt.friendly
		for cvar, value in pairs(FRIENDLY_NAMES) do
			if friendly then TakeCVar(f, cvar, value) else ReturnCVar(f, cvar) end
		end
		if on and f.opt.enemy then
			TakeCVar(f, "nameplateShowClassColor", 1)
		else
			ReturnCVar(f, "nameplateShowClassColor")
		end
	end)
	RefreshNames()
end

local function Restyled(f) return f.opt.friendly or f.opt.enemy end

local function PlatesOn()
	local plates = Shy.addons.Plates
	return plates ~= nil and plates.IsOn ~= nil and plates:IsOn() == true
end

-- Which side is restyled is a game setting too. The rest only redraws the names.
local HOLDS = { friendly = true, enemy = true }

classNames = ns.Feature({
	id = "classNames",
	category = "Social",
	title = "Restyle player names",
	desc = "Player names overhead take their class color and a font you pick. Off, the game's nameplate options decide.",
	keywords = "class color colour colored names name nameplates plates friendly enemy players pvp recent allies font size outline",
	default = false,
	yields = PlatesOn,
	options = {
		{ key = "friendly", kind = "checkbox", label = "Friendly players", default = true,
			desc = "A friendly player shows a name alone, with no health bar." },
		{ key = "enemy", kind = "checkbox", label = "Enemy players", default = true,
			desc = "An enemy player's name and health bar take their class color." },
		{ key = "allies", kind = "checkbox", label = "Mark recent allies", default = true,
			desc = "Players you grouped with lately get a badge after their name." },
		{ key = "font", kind = "dropdown", label = "Name font", default = "shy", items = FONTS, enabled = Restyled,
			desc = "Both fonts can write a name in any alphabet." },
		{ key = "size", kind = "slider", label = "Player name size", min = 9, max = 18, step = 1, default = 15, enabled = Restyled,
			settle = true, format = function(v) return tostring(math.floor(v + 0.5)) end,
			desc = "How big player names are. A long name is never cut short." },
		{ key = "lift", kind = "slider", label = "Name height", min = -20, max = 40, step = 1, default = 0,
			settle = true, enabled = function(f) return f.opt.friendly end,
			format = function(v) return v == 0 and "Right above the head" or ((v > 0 and "+" or "") .. math.floor(v + 0.5)) end,
			desc = "How far above the head a friendly name sits." },
		{ key = "outline", kind = "dropdown", label = "Outline", default = "thin", enabled = Restyled,
			items = {
				{ value = "none", text = "Shadow only" },
				{ value = "thin", text = "Thin outline" },
				{ value = "thick", text = "Thick outline" },
			},
			desc = "A dark outline keeps names readable over bright ground and sky." },
	},
	events = {
		PLAYER_ENTERING_WORLD = ApplyNames,
		RECENT_ALLIES_CACHE_UPDATE = RefreshNames,
		RECENT_ALLY_DATA_UPDATED = RefreshNames,
	},
	Enable = function(f)
		HookNames()
		ApplyNames(f)
	end,
	Disable = ApplyNames,
	OnOptionChanged = function(f, key)
		if HOLDS[key] then ApplyNames(f) else RefreshNames() end
	end,
})

-- NPC names

-- A plate names an NPC only when the "NPC Names" rules allow, and Blizzard's
-- name-only mode covers friendly players alone. So nameplateShowAll and
-- nameplateForceShowUnitName are set, and an idle NPC's bars are faded here.

-- For state that changes without Blizzard redrawing the name (target, combat).
local function RepaintNames()
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local frame = not plate:IsForbidden() and plate.UnitFrame
		if frame and frame.unit and not frame:IsForbidden() then PaintName(frame) end
	end
end

-- A new target changes only two plates: the one targeted now and the one that was. The rest are left as they
-- are drawn. An answer the game keeps secret is drawn as busy, and the next change draws every plate again.
local targetFrame, unsure = nil, true
local function RepaintTarget()
	local was, all = targetFrame, unsure
	targetFrame, unsure = nil, false
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local frame = not plate:IsForbidden() and plate.UnitFrame
		if frame and frame.unit and not frame:IsForbidden() then
			local is = UnitIsUnit(frame.unit, "target")
			if issecretvalue(is) then
				unsure = true
				PaintName(frame)
			elseif is then
				targetFrame = frame
				PaintName(frame)
			elseif all or frame == was then
				PaintName(frame)
			end
		end
	end
end

Shy:On("SHY_THEME", function()
	if npcNames.running then RepaintNames() end
end)

local function RepaintUnit(_, _, unit)
	if issecretvalue(unit) or type(unit) ~= "string" or not unit:find("^nameplate") then return end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	local frame = plate and not plate:IsForbidden() and plate.UnitFrame
	if frame and not frame:IsForbidden() then PaintName(frame) end
end

local function ApplyNPCNames(f)
	ns.OutOfCombat("npcNames", function()
		local on = f.running
		local function Want(cvar, wanted)
			if wanted then TakeCVar(f, cvar, 1) else ReturnCVar(f, cvar) end
		end
		Want("nameplateShowAll", on)
		Want("nameplateForceShowUnitName", on)
		Want("nameplateShowEnemies", on and f.opt.enemy)
		Want("nameplateShowFriendlyNpcs", on and f.opt.friendly and not IsInInstance())
	end)
	RefreshNames()
end

npcNames = ns.Feature({
	id = "npcNames",
	category = "Social",
	title = "Restyle NPC names",
	desc = "An NPC you aren't fighting shows just its name, in its reaction color. Off, the game's nameplate options decide.",
	keywords = "npc names name nameplates plates creatures mobs monsters vendors guards quest level elite innkeeper trainer hover mouseover reaction",
	default = false,
	yields = PlatesOn,
	options = {
		{ key = "friendly", kind = "checkbox", label = "Friendly NPCs", default = true,
			desc = "Guards, vendors and trainers show their name in green. Outdoors only." },
		{ key = "jobs", kind = "checkbox", label = "NPC titles", default = true,
			enabled = function(f) return f.opt.friendly end,
			desc = "A friendly NPC's job goes under its name, like Innkeeper or Flight Master." },
		{ key = "enemy", kind = "checkbox", label = "Enemies and creatures", default = true,
			desc = "A hostile mob's name is red and a neutral one's yellow. Its health bar shows once you target or fight it." },
		{ key = "level", kind = "checkbox", label = "Levels", default = true,
			enabled = function(f) return f.opt.enemy end,
			desc = "Anything you can attack shows its level after its name. A + marks an elite." },
		{ key = "size", kind = "slider", label = "NPC name size", min = 9, max = 18, step = 1, default = 13,
			settle = true, format = function(v) return tostring(math.floor(v + 0.5)) end,
			desc = "How big NPC names are. Their font and outline are the ones picked for player names." },
	},
	events = {
		PLAYER_ENTERING_WORLD = ApplyNPCNames,
		PLAYER_TARGET_CHANGED = RepaintTarget,
		PLAYER_REGEN_DISABLED = RepaintNames,
		PLAYER_REGEN_ENABLED = RepaintNames,
		UNIT_FLAGS = RepaintUnit,
	},
	Enable = function(f)
		HookNames()
		ApplyNPCNames(f)
	end,
	Disable = ApplyNPCNames,
	OnOptionChanged = function(f, key)
		if HOLDS[key] then ApplyNPCNames(f) else RefreshNames() end
	end,
})

-- System

local FAR = 2.6           -- the furthest the game lets the camera go
local SLIDER_END = 2.0    -- where the game's own Max Camera Distance slider stops

ns.Feature({
	id = "cameraDistance",
	category = "System",
	title = "Zoom out further",
	desc = "Your camera pulls back past the end of the game's Max Camera Distance slider.",
	keywords = "camera zoom out distance far max",
	default = false,
	says = function(f)
		local now = tonumber(GetCVar("cameraDistanceMaxZoomFactor"))
		if not f:IsOn() and now and now > SLIDER_END + 0.01 then return "already on in the game" end
	end,
	Enable = function(f) TakeCVar(f, "cameraDistanceMaxZoomFactor", FAR) end,
	Disable = function(f) ReturnCVar(f, "cameraDistanceMaxZoomFactor") end,
})

local function ScreenEffects(f)
	TakeCVar(f, "ffxGlow", 0)
	if f.opt.death then
		TakeCVar(f, "ffxDeath", 0)
		TakeCVar(f, "ffxNether", 0)
	else
		ReturnCVar(f, "ffxDeath")
		ReturnCVar(f, "ffxNether")
	end
end

ns.Feature({
	id = "crispScreen",
	category = "System",
	title = "Remove screen glow",
	desc = "The soft glow over the whole screen that washes out colors goes away.",
	keywords = "glow bloom blur screen effect death ghost graphics crisp sharp",
	default = false,
	says = function(f)
		if not f:IsOn() and GetCVar("ffxGlow") == "0" then return "already off in the game" end
	end,
	options = {
		{ key = "death", kind = "checkbox", label = "No blur while dead", default = false,
			desc = "The gray haze over the world while you're a ghost goes too." },
	},
	Enable = ScreenEffects,
	OnOptionChanged = ScreenEffects,
	Disable = function(f)
		ReturnCVar(f, "ffxGlow")
		ReturnCVar(f, "ffxDeath")
		ReturnCVar(f, "ffxNether")
	end,
})

-- The issue reporter

-- Blizzard_PTRFeedback (beta and PTR only). PTR_IssueReporter is one unprotected
-- frame holding the label and bug button. Blizzard shows and hides it with plain
-- Show / Hide; post-hooks on those track what it wants. Don't HookScript OnShow:
-- Blizzard re-sets that script at PLAYER_ENTERING_WORLD.

local reporter = PTR_IssueReporter   -- nil on a client without the tool

if reporter then
	local hideReporter
	-- Whether Blizzard wants the reporter shown. Nil until the tweak is first
	-- switched on (Disable runs once at login for every feature that is off).
	local wanted
	local putting   -- set during this file's own Show / Hide

	local function PutReporter()
		if wanted == nil then return end
		putting = true
		reporter:SetShown(wanted and not hideReporter.running)
		putting = false
	end

	-- Post-hook on PopFrameAttachedSurvey. A hidden survey sends nothing.
	local function TuckQuestion(pop)
		if not (hideReporter.running and hideReporter.opt.questions) then return end
		local box = pop and pop.frame and reporter.Data.FrameAttachedSurveyFrames[pop.frame]
		if box then box:Hide() end
	end

	-- Post-hook on HookIntoTooltip, which appends the reporter's line (under a
	-- blank one unless noGap). A tooltip can't drop a line, so both are emptied
	-- and the tooltip resized; a tooltip holding nothing else is hidden.
	local function TuckLine(tooltip, _, _, _, noGap)
		if not (hideReporter.running and hideReporter.opt.tooltips) then return end
		if not tooltip or tooltip:IsForbidden() then return end
		local last = tooltip:NumLines()
		local line = last > 0 and tooltip:GetLeftLine(last)
		local text = line and line:GetText()
		if not text or issecretvalue(text) then return end
		if not (text:find(reporter.BugTooltipPartialString, 1, true) or text == reporter.MissingBindTooltipString) then return end
		local gap = not noGap and last > 1 and tooltip:GetLeftLine(last - 1)
		local above = gap and gap:GetText()
		if issecretvalue(above) or above ~= " " then gap = nil end
		if last == (gap and 2 or 1) then
			tooltip:Hide()
			return
		end
		line:SetText("")
		line:Hide()
		if gap then
			gap:SetText("")
			gap:Hide()
		end
		tooltip:Show()
	end

	hideReporter = ns.Feature({
		id = "hideReporter",
		category = "System",
		title = "Hide the issue reporter",
		desc = "The beta's Issue Reporter label and bug button go away. Its key (F6) still reports what you point at.",
		keywords = "issue reporter bug report feedback button ptr beta test realm survey hide remove key bindings",
		default = false,
		options = {
			{ key = "tooltips", kind = "checkbox", label = "Hide its tooltip line", default = true,
				desc = "Tooltips lose their \"Press F6 to submit an issue\" line. The key still works." },
			{ key = "questions", kind = "checkbox", label = "Hide its quest survey", default = true,
				desc = "The survey under the quest window stays shut at a turn-in. Nothing is sent for that quest." },
		},
		Enable = function()
			if wanted == nil then
				wanted = reporter:IsShown()
				hooksecurefunc(reporter, "Show", function()
					if putting then return end
					wanted = true
					PutReporter()
				end)
				hooksecurefunc(reporter, "Hide", function()
					if not putting then wanted = false end
				end)
				hooksecurefunc(reporter, "PopFrameAttachedSurvey", TuckQuestion)
				hooksecurefunc(reporter, "HookIntoTooltip", TuckLine)
			end
			PutReporter()
		end,
		Disable = PutReporter,
	})
end
