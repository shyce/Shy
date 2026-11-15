-- LFM and LFG posts seen in chat channels: one per player, replaced by a
-- repost, expired after `expire` minutes. Secret chat lines are skipped.

local ADDON, ns = ...
local T, D = ns.T, ns.Data
local Bd = {}
ns.Board = Bd

Bd.posts = {}        -- newest first
local byName = {}

function Bd.Get(name)
	return byName[name]
end

local function OnChannel(text, sender, channel, guid)
	if issecretvalue(text) or issecretvalue(sender) then return end
	if T.db.skipChannels[channel] then return end
	local name = ns.Short(sender)
	if name == ns.Me() then return end

	local class, level
	if guid and canaccessvalue(guid) and guid ~= "" then
		local _
		_, class, _, _, _, _, _, level = GetPlayerInfoByGUID(guid)
	end
	local parsed = ns.Parse.Message(text, level, UnitLevel("player"))
	if not parsed then return end

	local post = byName[name]
	if post then
		for i, other in ipairs(Bd.posts) do
			if other == post then
				table.remove(Bd.posts, i)
				break
			end
		end
	else
		post = { name = name, first = time() }
		byName[name] = post
	end
	post.text = Shy.UI.PlainText(text)
	post.foreign = ns.Parse.Foreign(post.text, GetLocale())
	post.kind, post.keys, post.roles = parsed.kind, parsed.keys, parsed.roles
	post.count, post.size = parsed.count, parsed.size
	post.class, post.level, post.guid = class or post.class, level or post.level, guid
	post.channel, post.last = channel, time()
	table.insert(Bd.posts, 1, post)
	ns.Changed()
end

local function Prune()
	local cutoff = time() - T.db.expire * 60
	local removed = false
	for i = #Bd.posts, 1, -1 do
		local post = Bd.posts[i]
		if post.last < cutoff then
			table.remove(Bd.posts, i)
			byName[post.name] = nil
			removed = true
		end
	end
	if removed then ns.Changed() end
end

-- Foreign posts are stored but hidden, so the option applies live.
function Bd.Readable(post)
	return not post.foreign or not T.db.myLanguage
end

-- Whether one dungeon, raid or zone is for this level, as the game decides.
function Bd.ForLevel(d, level)
	return D.Fits(d, level)
end

-- A post that names nothing always fits.
function Bd.FitsLevel(post, level)
	if #post.keys == 0 then return true end
	for _, key in ipairs(post.keys) do
		local d = D.byKey[key]
		if d and Bd.ForLevel(d, level) then return true end
	end
	return false
end

-- A chat group that named no roles may need any; a Group Finder group
-- (post.have set) lists its open roles exactly.
function Bd.HasRole(post, role)
	if next(post.roles) then return post.roles[role] or false end
	if post.kind == "lfg" then return D.CanFill(post.class, role) end
	return post.have == nil
end

function Bd.About(post, key)
	for _, k in ipairs(post.keys) do
		if k == key then return true end
	end
	return false
end

-- "Deadmines", "Scarlet Library +2": the game's short name where it has one.
function Bd.DungeonText(post)
	local first = post.keys[1] and D.byKey[post.keys[1]]
	if not first then return nil end
	local name = first.short or first.name
	if #post.keys == 1 then return name end
	return name .. " +" .. (#post.keys - 1)
end

function Bd.Init()
	local events = CreateFrame("Frame")
	events:RegisterEvent("CHAT_MSG_CHANNEL")
	events:SetScript("OnEvent", function(_, _, text, sender, _, _, _, _, _, _, channel, _, _, guid)
		OnChannel(text, sender, channel, guid)
	end)
	C_Timer.NewTicker(15, Prune)
end
