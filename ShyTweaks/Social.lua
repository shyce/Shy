-- Invites, strangers, duels, summons and resurrections.

local ADDON, ns = ...

local SEPARATOR = Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
local NEAR = { "target", "mouseover", "focus", "softfriend", "softenemy", "softinteract" }

-- The one rule every block here asks: friends, Battle.net friends and guildmates.
local function Known(guid)
	if not guid or not canaccessvalue(guid) then return false end
	return C_FriendList.IsFriend(guid) or IsGuildMember(guid) or C_BattleNet.GetAccountInfoByGUID(guid) ~= nil
end

local function Plain(v)
	return v ~= nil and canaccessvalue(v) and v ~= ""
end

-- A player in view who goes by this name (first name alone, or with the surname).
local function Called(unit, name)
	local exists, player = UnitExists(unit), UnitIsPlayer(unit)
	if not (canaccessvalue(exists, player) and exists and player) then return false end
	local first, surname = UnitName(unit)
	if not Plain(first) then return false end
	if first == name then return true end
	return Plain(surname) and first .. SEPARATOR .. surname == name
end

local function GuidCalled(name)
	for _, unit in ipairs(NEAR) do
		if Called(unit, name) then return UnitGUID(unit) end
	end
	local raid = IsInRaid()
	for i = 1, raid and 40 or 4 do
		local unit = (raid and "raid" or "party") .. i
		if Called(unit, name) then return UnitGUID(unit) end
	end
	for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
		local unit = not nameplate:IsForbidden() and nameplate.unitToken
		if type(unit) == "string" and Called(unit, name) then return UnitGUID(unit) end
	end
end

-- The same rule for a request that comes with a name only (a duel): the player in view by that name,
-- else the friends list and Battle.net friends by character name.
local function KnownName(name)
	if not Plain(name) then return false end
	name = Ambiguate(name, "none")
	if Known(GuidCalled(name)) then return true end
	if C_FriendList.GetFriendInfo(name) then return true end
	for i = 1, BNGetNumFriends() do
		local account = C_BattleNet.GetFriendAccountInfo(i)
		local who = account and account.gameAccountInfo and account.gameAccountInfo.characterName
		if Plain(who) and Ambiguate(who, "none") == name then return true end
	end
	return false
end

-- A soulstone or Reincarnation ready: how to come back is the player's choice.
local function CanRaiseSelf()
	for _, option in ipairs(C_DeathInfo.GetSelfResurrectOptions()) do
		local usable = option.canUse
		if canaccessvalue(usable) and usable then return true end
	end
	return false
end

-- Blizzard shows its popup on the same event, so hide it on the next frame.
local function HidePopup(...)
	local names = { ... }
	C_Timer.After(0, function()
		for _, name in ipairs(names) do StaticPopup_Hide(name) end
	end)
end

ns.Feature({
	id = "partyInvites",
	category = "Social",
	title = "Accept party invites",
	desc = "You join the group as soon as a friend or guildmate invites you.",
	keywords = "group party invite auto accept friends guild",
	default = false,
	events = {
		PARTY_INVITE_REQUEST = function(_, _, _, _, _, _, _, _, _, inviterGUID)   -- (event, name, three roles, native realm, cross shard, multiple roles)
			if not Known(inviterGUID) then return end
			AcceptGroup()
			HidePopup("PARTY_INVITE")
		end,
	},
})

-- The page of a quest someone shares: the player who shared it stands as "questnpc". An item's page
-- or an NPC's never carries a player there, so neither is ever declined.
local function SharedByStranger(fromItem)
	if fromItem ~= nil and (not canaccessvalue(fromItem) or fromItem ~= 0) then return false end
	local guid, me = UnitGUID("questnpc"), UnitGUID("player")
	if guid == nil or not canaccessvalue(guid) or guid == me then return false end
	return guid:find("^Player%-") ~= nil and not Known(guid)
end

-- For other addons (Shy.addons.Tweaks:TurnsShareAway()): whether the quest page open now is a
-- stranger's share this addon declines, so nothing accepts it first.
function ns.T:TurnsShareAway()
	local f = ns.Get("strangers")
	return f ~= nil and f.running == true and f.opt.quests == true and SharedByStranger(nil)
end

ns.Feature({
	id = "strangers",
	category = "Social",
	title = "Turn strangers away",
	desc = "Anyone who isn't a friend or guildmate is declined for you. Pick what for below.",
	keywords = "stranger block decline request join group party invite quest share shared battle.net bnet friend request spam",
	default = false,
	options = {
		{ key = "invites", kind = "checkbox", label = "Party invites", default = false,
			desc = "A stranger's party invite is declined." },
		{ key = "requests", kind = "checkbox", label = "Requests to join", default = true,
			desc = "A stranger asking to join your group is declined." },
		{ key = "quests", kind = "checkbox", label = "Shared quests", default = false,
			desc = "A quest shared by a stranger in your group is declined." },
		{ key = "battleNet", kind = "checkbox", label = "All Battle.net requests", default = false,
			desc = "Every Battle.net friend request is declined as it arrives, whoever sent it." },
	},
	events = {
		PARTY_INVITE_REQUEST = function(f, _, _, _, _, _, _, _, _, inviterGUID)
			if not f.opt.invites or Known(inviterGUID) then return end
			DeclineGroup()
			HidePopup("PARTY_INVITE")
		end,
		GROUP_INVITE_CONFIRMATION = function(f)
			if not f.opt.requests then return end
			local invite = GetNextPendingInviteConfirmation()
			if invite == nil or not canaccessvalue(invite) then return end
			local kind, _, guid = GetInviteConfirmationInfo(invite)
			if not canaccessvalue(kind) or kind ~= LE_INVITE_CONFIRMATION_REQUEST then return end
			if guid == nil or not canaccessvalue(guid) or Known(guid) then return end
			RespondToInviteConfirmation(invite, false)
			C_Timer.After(0, function() StaticPopup_Hide("GROUP_INVITE_CONFIRMATION", invite) end)
		end,
		QUEST_DETAIL = function(f, _, fromItem)
			if f.opt.quests and SharedByStranger(fromItem) then DeclineQuest() end
		end,
		BN_FRIEND_INVITE_ADDED = function(f)
			if not f.opt.battleNet then return end
			for i = BNGetNumFriendInvites(), 1, -1 do
				local info = C_BattleNet.GetFriendInviteInfo(i)
				local id = info and info.inviteID
				if id ~= nil and canaccessvalue(id) then BNDeclineFriendInvite(id) end
			end
		end,
	},
})

ns.Feature({
	id = "declineDuels",
	category = "Social",
	title = "Decline duels",
	desc = "Duel requests are declined before the box pops up.",
	keywords = "duel challenge request auto decline block death friends",
	default = false,
	options = {
		{ key = "friends", kind = "checkbox", label = "Allow friends and guildmates", default = true,
			desc = "A friend or guildmate can still ask you." },
	},
	events = {
		DUEL_REQUESTED = function(f, _, name)
			if f.opt.friends and KnownName(name) then return end
			CancelDuel()
			HidePopup("DUEL_REQUESTED")
		end,
		DUEL_TO_THE_DEATH_REQUESTED = function(f, _, name)
			if f.opt.friends and KnownName(name) then return end
			CancelDuel()
			HidePopup("DUEL_TO_THE_DEATH_REQUESTED")
		end,
	},
})

ns.Feature({
	id = "whisperInvite",
	category = "Social",
	title = "Invite by whisper",
	desc = "Anyone who whispers you the keyword gets an invite. In a group, you need lead or assist.",
	keywords = "whisper keyword inv invite auto group party lfg raid",
	default = false,
	options = {
		{ key = "keyword", kind = "input", label = "Keyword", default = "inv", placeholder = "inv",
			desc = "The word to whisper you." },
		{ key = "knownOnly", kind = "checkbox", label = "Friends and guildmates only", default = false,
			desc = "A whisper from anyone else gets no invite." },
	},
	events = {
		CHAT_MSG_WHISPER = function(f, _, text, sender, _, _, _, _, _, _, _, _, _, guid)
			if issecretvalue(text) or issecretvalue(sender) then return end
			if strtrim(text):lower() ~= strtrim(f.opt.keyword):lower() then return end
			if f.opt.knownOnly and not Known(guid) then return end
			if IsInGroup() and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then return end
			C_PartyInfo.InviteUnit(sender)
		end,
	},
})

ns.Feature({
	id = "acceptSummon",
	category = "Social",
	title = "Accept summons",
	desc = "You take a warlock's or a meeting stone's summon, unless you're in a fight.",
	keywords = "summon warlock meeting stone portal auto accept",
	default = false,
	events = {
		CONFIRM_SUMMON = function()
			C_Timer.After(0.5, function()
				if C_SummonInfo.GetSummonConfirmTimeLeft() > 0 and not UnitAffectingCombat("player") then
					C_SummonInfo.ConfirmSummon()
					StaticPopup_Hide("CONFIRM_SUMMON")
				end
			end)
		end,
	},
})

ns.Feature({
	id = "acceptRes",
	category = "Social",
	title = "Accept resurrections",
	desc = "You take a resurrection out of combat, unless a soulstone or Reincarnation is ready.",
	keywords = "resurrect resurrection rez res revive dead auto accept soulstone reincarnation",
	default = false,
	options = {
		{ key = "notInCombat", kind = "checkbox", label = "Not while they fight", default = true,
			desc = "You stay down while whoever is raising you is still in combat." },
	},
	events = {
		RESURRECT_REQUEST = function(f, _, caster)
			if InCombatLockdown() or UnitAffectingCombat("player") or CanRaiseSelf() then return end
			if f.opt.notInCombat then
				if not canaccessvalue(caster) then return end
				local busy = UnitAffectingCombat(caster)
				if not canaccessvalue(busy) or busy then return end
			end
			AcceptResurrect()
			HidePopup("RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER")
		end,
	},
})

ns.Feature({
	id = "releaseBG",
	category = "Combat",
	title = "Release in battlegrounds",
	desc = "You release as soon as you die in a battleground, unless you can raise yourself.",
	keywords = "battleground bg pvp die death auto release spirit graveyard",
	default = false,
	events = {
		PLAYER_DEAD = function()
			local _, kind = IsInInstance()
			if kind ~= "pvp" or #C_DeathInfo.GetSelfResurrectOptions() > 0 then return end
			C_Timer.After(1, function()
				if UnitIsDead("player") and not UnitIsGhost("player") then RepopMe() end
			end)
		end,
	},
})
