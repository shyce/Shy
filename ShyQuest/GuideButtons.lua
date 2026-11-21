-- Secure buttons for the live guide step, in a strip under the card's lead:
--   a tile per item, spell or macro (view.uses)
--   a chip per creature to fight or to find (view.targets). It targets and raid-marks the creature.
--     A right click marks it and, if one is there, pings it for your group (Ping).
-- Someone to talk to has no chip: the card names them and their nameplate is marked.
-- Quests' own items (the ones the game's tracker has a button for) get a tile too.
--
-- The strip holds secure children, so it can't be the card's child (the card shows, hides, moves and
-- resizes in combat). It is its own frame over the room the card reserves (ns.SetCardDock), placed
-- by screen coordinates out of combat (ns.CardBox) and shown by a state driver.
--
-- A creature the leading step names for one task (view.targets' `of`: the kills attached to an
-- objective) has its chip under that task's count on the card, not in the block under the head.
-- The count says what to get and the chips under it say who from, each said once. The card says
-- which counts it shows (ns.CardClaims) and where the room under each starts (ns.CardSlots). The
-- strip says how much room each group takes (ns.SetCardDock's rooms). Chips are only ever moved out
-- of combat. In a fight the card lays its lines round where they are (Stood, Extent).

local ADDON, ns = ...
local T = ns.T
local D, L, G, R = ns.Data, ns.Log, ns.Guide, ns.Route
local UI = Shy.UI
local C = UI.colors

local PAD = ns.CARD_PAD   -- the card's width (ns.CardWidth) can change, so it is read at layout
local LEFT = ns.CARD_DOCK_LEFT or PAD   -- the strip starts right of the card's rail
local TILE, LINE, GAP = 28, 20, 6
local TILES, LINES = 5, 6
local UNDER, FOOT = 2, 1                    -- a group of chips under its count: the air over it, and under it
local STEEP = 3                             -- levels above the player that earn a warning
local QUESTION = 134400                     -- question-mark icon, for a macro without one
local RAID_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
-- NPCs: star, circle, diamond, triangle. Mobs: skull, cross, square. Awaited spawn: moon.
local MARKERS = { target = { 1, 2, 3, 4 }, mob = { 8, 7, 6 }, scan = { 5 } }
local SEEN_FOR = 20                          -- seconds a sighting keeps its chip lit
local AGAIN_AFTER = 90                       -- seconds before the same creature is announced again

BINDING_HEADER_SHYQUEST = "ShyQuest"
_G["BINDING_NAME_CLICK ShyQuestTarget1:LeftButton"] = "Target guide step NPC or mob"
_G["BINDING_NAME_CLICK ShyQuestUse1:LeftButton"] = "Use guide step item or spell"

local box
local tiles, lines = {}, {}
local uses, targets = {}, {}                 -- what the strip shows now
local markers = {}                           -- raid marker per target name
local awaited = {}                           -- the live steps' targets, shown or not: whose sighting is told
local applied                                -- signature the buttons were last set up for
local tall = 0                               -- height taken on the card, under its head
local groups = {}                            -- target name -> the task (G.TaskKey) whose count its chip stands under
local rooms, roomsSaid                       -- key -> { tall, names }: what each group takes there; and as one text
local stood, stoodSlots = {}, nil            -- key -> { at, tall }: where each group was last stood; the card's slots then
local Stand
local stoodLeft, stoodTop, stoodHead         -- card position and heading height when the strip was last placed
local dirty = false                          -- a change is waiting for combat to end
local seen = {}                              -- name -> when it was last sighted

local function Setting(key)
	local value = T.db.guide[key]
	if value == nil then return true end
	return value
end

-- What the live steps need

-- An item in the bags or a known spell; `always` (":p" in a guide) shows it regardless.
local function Ready(use)
	if use.kind == "item" then return use.always or C_Item.GetItemCount(use.id) > 0 end
	if use.kind == "spell" then return use.always or C_SpellBook.IsSpellKnown(use.id) end
	return true
end

-- Guide macros are one line: "\n" for line breaks, "spell:1234" for a spell's name.
local function MacroText(body)
	local text = body:gsub("\\n", "\n")
	return (text:gsub("spell:(%d+)", function(id) return C_Spell.GetSpellName(tonumber(id)) or ("spell:" .. id) end))
end

local function Marker(kind, nth)
	local list = MARKERS[kind]
	return list[(nth - 1) % #list + 1]
end

-- Targets of the live steps in card order, and each one's marker by name. Also used by Plates.lua.
function ns.StepTargets()
	local list, marker, nth = {}, {}, {}
	if not ns.Following() then return list, marker end
	for _, stop in ipairs(R.stops) do
		local view = stop.kind == "guide" and stop.view
		if view and view.uses then
			for _, target in ipairs(view.targets) do
				if not marker[target.name] and #list < LINES then
					nth[target.kind] = (nth[target.kind] or 0) + 1
					marker[target.name] = Marker(target.kind, nth[target.kind])
					list[#list + 1] = target
				end
			end
		end
	end
	return list, marker
end

local function Gather()
	uses, targets, markers, awaited = {}, {}, {}, {}
	if not Setting("buttons") then return end
	-- The strip stands under the card's lead. While something beside the guide leads (an errand, a
	-- flight), the guide's own buttons wait.
	local lead = R.stops[1]
	-- (Dead, there is nothing to use or to target: no buttons at all under the way back to the body.)
	if lead ~= nil and lead.urgent then return end
	local aside = lead ~= nil and (lead.kind == "errand" or lead.kind == "fly")
	local known = {}
	local function Add(use)
		local key = use.kind .. tostring(use.id)
		if not known[key] and #uses < TILES and Ready(use) then
			known[key] = true
			uses[#uses + 1] = use
		end
	end
	for _, stop in ipairs(ns.Following() and not aside and R.stops or {}) do
		local view = stop.kind == "guide" and stop.view
		for _, use in ipairs(view and view.uses or {}) do Add(use) end
		-- An item a `destroy` line says to be rid of, while any is left: a tile that destroys it, clicked twice.
		for _, line in ipairs(view and view.lines or {}) do
			if line.command == "destroy" and line.id and not line.done and C_Item.GetItemCount(line.id) > 0 then
				Add({ kind = "destroy", id = line.id })
			end
		end
	end
	-- The item a quest's objectives are done with, which the game's tracker has a button for: while
	-- the card stands in for the tracker (Tracker.lua), the lead's quests have theirs here. The lead's
	-- alone: the strip stands under that row, and another quest's item there reads as this quest's.
	if lead ~= nil and not aside and ns.TrackerParked and ns.TrackerParked() then
		for _, action in ipairs(lead.actions or {}) do
			local index = action.kind ~= "pickup" and L.Has(action.id) and C_QuestLog.GetLogIndexForQuestID(action.id)
			local link = index and GetQuestLogSpecialItemInfo(index)
			local id = link and tonumber(link:match("item:(%d+)"))
			if id then Add({ kind = "item", id = id }) end
		end
	end
	local list, marks = ns.StepTargets()
	awaited = list
	-- Someone to talk to has no chip: the card names them, and their nameplate wears the quest's mark
	-- (Plates.lua, which still knows every one of the step's creatures). So an errand or a flight that
	-- leads has none at all, and the guide's step only its creatures to fight or to find.
	-- And the chips stand under the lead, so they are there only while the lead is a step of the guide's with
	-- a creature of its own to fight or find. Under a hand-in, an accept or a quest done on the way, the
	-- creatures of the steps after it would read as what that row asks for.
	local view = not aside and lead ~= nil and lead.kind == "guide" and lead.view or nil
	local own = false
	for _, target in ipairs(view and view.uses and view.targets or {}) do
		if target.kind ~= "target" then own = true end
	end
	if own then
		markers = marks
		for _, target in ipairs(list) do
			if target.kind ~= "target" then targets[#targets + 1] = target end
		end
	end
end

-- The chips that stand under a count on the card's lead: the leading step's own creatures, each named for one
-- task, where the card shows that task's count.
local function Group()
	groups = {}
	local lead = R.stops[1]
	local view = lead and lead.kind == "guide" and lead.view
	local claims = view and ns.CardClaims and ns.CardClaims()
	if not claims then return end
	local shown = {}
	for _, target in ipairs(targets) do shown[target] = true end
	for _, target in ipairs(view.targets) do
		local key = target.of and shown[target] and G.TaskKey(view, target.of)
		if key and claims[key] then groups[target.name] = key end
	end
end

local function Signature()
	local parts = { tostring(Setting("marks") and not IsInGroup()), tostring(Setting("marks")) }
	for _, use in ipairs(uses) do parts[#parts + 1] = use.kind .. tostring(use.id) end
	for _, target in ipairs(targets) do parts[#parts + 1] = target.kind .. target.name .. "@" .. (groups[target.name] or "") end
	return table.concat(parts, "|")
end

-- Buttons

-- Returns the level text ("17-18", "24+" for an elite) and the max level.
local function Level(target)
	local npc = target.kind ~= "target" and target.npc and D.Npc(target.npc)
	if not npc or npc.maxLevel <= 0 then return nil end
	local low = npc.minLevel > 0 and npc.minLevel or npc.maxLevel
	local text = low == npc.maxLevel and tostring(low) or (low .. "-" .. npc.maxLevel)
	if npc.rank >= 1 and npc.rank <= 3 then text = text .. "+" end
	return text, npc.maxLevel
end

-- Chip text: name, then level in its difficulty color.
--   short: the name's last word and the initials of the rest ("Murloc Minor Tidecaller" -> "MM. Tidecaller"), as
--   a name on a unit's frame is cut (UI.ShortName); the chip's hover has it whole.
local function Label(target, short)
	local name = target.name
	if short and name:find(" ") then name = UI.ShortName(name, UI.Letters(name) - 1) end
	local text, level = Level(target)
	if not text then return name end
	local color = GetCreatureDifficultyColor(level)
	local function Part(v) return math.floor(v * 255 + 0.5) end
	return ("%s  |cff%02x%02x%02x%s|r"):format(name, Part(color.r), Part(color.g), Part(color.b), text)
end

-- Items and spells use GameTooltip; macros and targets use UI.Tip.
local function Tip(self)
	local use, target = self.use, self.target
	if use and (use.kind == "item" or use.kind == "spell") then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		if use.kind == "item" then GameTooltip:SetHyperlink("item:" .. use.id) else GameTooltip:SetSpellByID(use.id) end
		GameTooltip:Show()
	elseif use and use.kind == "destroy" then
		UI.Tip(self, "Destroy " .. (C_Item.GetItemNameByID(use.id) or "it"), "Your guide doesn't need it anymore.", { side = "LEFT",
			hints = { { "left", "Click twice to destroy" } } })
	elseif use then
		UI.Tip(self, use.name, "Macro for this step:", { side = "LEFT",
			sections = { { rows = { { glyph = "note", text = MacroText(use.body) } } } }, hints = { { "left", "Run macro" } } })
	elseif target then
		local rows = {}
		local text, level = Level(target)
		local tone
		if text then
			local color = GetCreatureDifficultyColor(level)
			tone = { color.r, color.g, color.b }
			rows[#rows + 1] = { glyph = "kill", tint = tone, color = tone, text = "Level " .. text }
			local above = level - L.Level()
			if above >= STEEP then
				rows[#rows + 1] = { glyph = "up", tint = C.alert, color = C.alert,
					text = ("%d levels above you. Expect misses and resists."):format(above) }
			end
		end
		local says, click
		if target.kind == "target" then
			click = "Target"
		elseif target.kind == "scan" then
			says, click = "You're waiting for it to spawn.", "Target when near"
		else
			click = "Target nearest"
		end
		-- The creature itself, turning on the stage (as every hover of a creature has it), over its level and the rest.
		local light = tone or C.hot
		local body = {}
		if target.npc and ns.CardHover and ns.CardHover.Creature then body[1] = { model = ns.CardHover.Creature(target.npc, light) } end
		if #rows > 0 then body[#body + 1] = { rows = rows } end
		if says then body[#body + 1] = { text = says, color = C.dim } end
		Shy.Hover.Show(self, { card = true, about = "chip:" .. target.name, title = target.name, light = light, body = body,
			hints = { { "left", click }, { "right", IsInGroup() and "Mark it and ping your group" or "Mark it and ping" } } }, { side = "LEFT" })
	end
end

local function Untip(self)
	GameTooltip:Hide()
	UI.TipHide(self)
end

-- Destroying an item (a destroy tile): the first click asks ("Sure?" on the tile for SURE seconds), the
-- second picks the first stack of it out of the bags and deletes it; the game's own question comes up for
-- anything it holds dear.
local SURE = 4
local function Destroy(tile)
	local use = tile.use
	if not use or use.kind ~= "destroy" then return end
	if not tile.sure or GetTime() > tile.sure then
		tile.sure = GetTime() + SURE
		tile.count:SetText("Sure?")
		return
	end
	tile.sure = nil
	for bag = Enum.BagIndex.Backpack, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
		for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and not issecretvalue(id) and id == use.id then
				C_Container.PickupContainerItem(bag, slot)
				DeleteCursorItem()
				return
			end
		end
	end
end

local function CreateTile(i)
	local tile = CreateFrame("Button", "ShyQuestUse" .. i, box, "SecureActionButtonTemplate")
	tile:SetSize(TILE, TILE)
	tile:SetPoint("TOPLEFT", LEFT + (i - 1) * (TILE + 4), 0)
	tile:RegisterForClicks("AnyUp", "AnyDown")
	tile:SetScript("PostClick", function(self, _, down)
		if not down then Destroy(self) end
	end)
	tile.icon = tile:CreateTexture(nil, "ARTWORK")
	tile.icon:SetPoint("TOPLEFT", 1, -1)
	tile.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	tile.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	tile.count = tile:CreateFontString(nil, "OVERLAY")
	tile.slot = Shy.Slot.New(tile, { icon = tile.icon })
	tile.slot:Count(tile.count)
	tile:SetScript("OnEnter", Tip)
	tile:SetScript("OnLeave", Untip)
	tile:Hide()
	return tile
end

-- A chip's right click, once its macro has looked for the creature and marked it: found (it is your target
-- now), it is pinged. The game's own ping goes out on the minimap where you stand, which everyone in your
-- group sees; their copies of ShyWay ring, name it at the top and stand it on their map, and the rest get
-- its mark and a pin in the group's chat (Shy.Way.Share.Ping). Not found, the game's error line says so.
local function Ping(line)
	local target = line.target
	if not target then return end
	local name = UnitExists("target") and UnitName("target") or nil
	if name == nil or issecretvalue(name) or name ~= target.name then
		UIErrorsFrame:AddMessage(("No %s in sight."):format(target.name), RED_FONT_COLOR:GetRGBA())
		return
	end
	Minimap:PingLocation(0, 0)
	local share = Shy.Way.Share
	if Shy.Way.missing or not (share and share.Ping and share.Here) then return end
	local here = share.Here()
	if here then share.Ping({ map = here.map, x = here.x, y = here.y, title = target.name }, markers[target.name]) end
end

local CHIP_TEXT, CHIP_END = 22, 7             -- text inset, and padding after it
local function CreateLine(i)
	local line = CreateFrame("Button", "ShyQuestTarget" .. i, box, "SecureActionButtonTemplate")
	line:SetSize(ns.CardWidth() - LEFT - PAD, LINE - 2)
	line:RegisterForClicks("AnyUp", "AnyDown")
	UI.Skin(line, C.bg, C.rowEdge)
	line:SetAttribute("type", "macro")
	-- (Both the press and the release come by: the macro has run by the release, whichever it runs on.)
	line:SetScript("PostClick", function(self, button, down)
		if button == "RightButton" and not down then Ping(self) end
	end)
	-- Gold while its creature was sighted recently.
	line.glow = line:CreateTexture(nil, "BACKGROUND")
	line.glow:SetAllPoints()
	UI.Paint(line.glow, C.alert, 0.22)
	line.glow:Hide()
	local hover = line:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	UI.Paint(hover, C.hot, 0.14)
	line.mark = line:CreateTexture(nil, "ARTWORK")
	line.mark:SetSize(14, 14)
	line.mark:SetPoint("LEFT", 4, 0)
	line.name = UI.Words(line, UI.NameFont(12), nil, { wrap = false })
	line.name:SetPoint("LEFT", CHIP_TEXT, 0)
	line:SetScript("OnEnter", Tip)
	line:SetScript("OnLeave", Untip)
	line:Hide()
	return line
end

-- Counts and glows only: safe in combat.
local function Freshen()
	local now = GetTime()
	for _, tile in ipairs(tiles) do
		local use = tile.use
		if use and (use.kind == "item" or use.kind == "destroy") then
			local count = C_Item.GetItemCount(use.id)
			if use.kind == "destroy" and tile.sure and now <= tile.sure then
				tile.count:SetText("Sure?")
			else
				tile.sure = nil
				tile.count:SetText(count > 1 and count or "")
			end
		elseif use then
			tile.count:SetText("")
		end
	end
	for _, line in ipairs(lines) do
		local target = line.target
		local at = target and seen[target.name]
		line.glow:SetShown(at ~= nil and now - at < SEEN_FOR)
	end
end

-- Only while the card leads with the step they are for: a filter that puts another stop in the lead (or none)
-- puts the strip away until it is cleared.
local function Shown()
	return Setting("buttons") and (#uses + #targets) > 0 and (not ns.CardLeads or ns.CardLeads())
end

-- Places the strip under the card's heading, out of combat only. Anchored to UIParent by
-- coordinates: anchoring a secure frame to the card would make the card protected.
function Stand()
	if not box or InCombatLockdown() then return end
	local host, on = ns.CardBox()
	local show = Shown() and host ~= nil and on
	-- The card makes its room first: the block under its head, and under each count what that count's chips
	-- take. (Where that is news to it, it lays itself out again and has the strip stood then: Card.lua's Fill.)
	ns.SetCardDock(show and tall or 0, show and rooms or nil, show and roomsSaid or nil)
	local left, top = host and host:GetLeft(), host and host:GetTop()
	stoodLeft, stoodTop, stoodHead = left, top, ns.CARD_HEAD
	if show and left and top then
		box:SetScale(host:GetScale())
		box:SetFrameLevel(host:GetFrameLevel() + 20)
		box:ClearAllPoints()
		box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top - ns.CARD_HEAD)
		box:SetAlpha(1)
	else
		show = false
	end
	-- Each group under its count, where the card says that count's room starts.
	local slots = ns.CardSlots()
	stood, stoodSlots = {}, slots
	for _, line in ipairs(lines) do
		if line.target and line.group then
			local at = show and slots and slots[line.group]
			line:SetShown(at ~= nil and at ~= false)
			if at then
				stood[line.group] = { at = at, tall = rooms[line.group].tall }
				line:ClearAllPoints()
				line:SetPoint("TOPLEFT", LEFT + line.x, -(at + UNDER + line.y))
			end
		end
	end
	-- Follows the card's "hide in combat" setting.
	local rule = show and (T.db.card.hideInCombat and "[combat] hide; show" or "show") or "hide"
	if box.rule ~= rule then
		box.rule = rule
		RegisterStateDriver(box, "visibility", rule)
	end
end

-- Sets attributes and layout; deferred while in combat.
local function Apply()
	if not box then return end
	if InCombatLockdown() then
		dirty = true
		return
	end
	dirty = false
	Group()
	local signature = Signature()
	if signature ~= applied then
		applied = signature
		local marking = Setting("marks") and not IsInGroup()
		for i, tile in ipairs(tiles) do
			local use = uses[i]
			tile.use = use
			tile:SetShown(use ~= nil)
			if use then
				tile.icon:SetDesaturated(use.kind == "destroy")
				tile.sure = nil
				if use.kind == "item" then
					tile:SetAttribute("type", "item")
					tile:SetAttribute("item", "item:" .. use.id)
					tile.icon:SetTexture(C_Item.GetItemIconByID(use.id))
				elseif use.kind == "destroy" then
					-- (No secure action: the click is answered by the tile's own script, Destroy.)
					tile:SetAttribute("type", nil)
					tile.icon:SetTexture(C_Item.GetItemIconByID(use.id))
				elseif use.kind == "spell" then
					tile:SetAttribute("type", "spell")
					tile:SetAttribute("spell", use.id)
					tile.icon:SetTexture(C_Spell.GetSpellTexture(use.id))
				else
					tile:SetAttribute("type", "macro")
					tile:SetAttribute("macrotext", MacroText(use.body))
					tile.icon:SetTexture(use.icon or QUESTION)
				end
			end
		end
		-- Chips flow left to right and wrap: those of a count on the card in a flow of their own under it (Stand
		-- puts them there), the rest in the block under the tiles.
		local inner = ns.CardWidth() - LEFT - PAD
		local block = { x = 0, y = #uses > 0 and TILE + GAP or 0 }
		local flows, said = {}, {}
		rooms = {}
		-- A flow whose chips don't fit on one line with their names whole says every name short (Label), so more
		-- of them stand side by side: how wide each flow is whole.
		local whole = {}
		for i, line in ipairs(lines) do
			local target = targets[i]
			if target then
				local key = groups[target.name] or block
				line.name:SetWidth(0)
				line.name:SetText(Label(target))
				whole[key] = (whole[key] and whole[key] + GAP or 0) + CHIP_TEXT + math.ceil(line.name:GetStringWidth()) + CHIP_END
			end
		end
		for i, line in ipairs(lines) do
			local target = targets[i]
			line.target = target
			line.group = target and groups[target.name] or nil
			line:SetShown(target ~= nil and line.group == nil)
			if target then
				local marker = markers[target.name]
				local text ="/cleartarget\n/targetexact " .. target.name
				-- "!" keeps a marker that is already set instead of toggling it off.
				if marking then text = text .. "\n/tm !" .. marker end
				line:SetAttribute("macrotext", text)
				-- A right click marks it whoever you are with (the mark is for them to see) and pings it (Ping).
				local shout = "/cleartarget\n/targetexact " .. target.name
				if Setting("marks") then shout = shout .. "\n/tm !" .. marker end
				line:SetAttribute("macrotext2", shout)
				line.mark:SetTexture(RAID_ICON .. marker)
				line.mark:SetDesaturated(not marking)
				line.mark:SetAlpha(marking and 1 or 0.6)
				line.name:SetWidth(0)
				line.name:SetText(Label(target, whole[line.group or block] > inner))
				UI.Ink(line.name, target.kind == "target" and C.good or target.kind == "scan" and C.alert or C.text)
				local wide = CHIP_TEXT + math.ceil(line.name:GetStringWidth()) + CHIP_END
				if wide > inner then
					wide = inner
					line.name:SetWidth(inner - CHIP_TEXT - CHIP_END)
				end
				local key = line.group
				local flow = block
				if key then
					flow = flows[key] or { x = 0, y = 0 }
					flows[key] = flow
				end
				if flow.x > 0 and flow.x + wide > inner then flow.x, flow.y = 0, flow.y + LINE end
				line:SetWidth(wide)
				line.x, line.y = flow.x, flow.y
				flow.x, flow.used = flow.x + wide + GAP, true
				if key then
					local room = rooms[key] or { names = {} }
					rooms[key] = room
					room.names[target.name:lower()] = true
					room.tall = UNDER + flow.y + LINE - 2 + FOOT
				else
					line:ClearAllPoints()
					line:SetPoint("TOPLEFT", LEFT + line.x, -line.y)
				end
			end
		end
		local y = block.y + (block.used and LINE or 0)
		tall = y > 0 and y + 2 or 0
		for key, room in pairs(rooms) do said[#said + 1] = key .. "=" .. room.tall end
		table.sort(said)
		roomsSaid = signature .. "||" .. table.concat(said, "|")
		box:SetSize(ns.CardWidth(), math.max(1, tall))
	end
	Freshen()
	Stand()
end

local function Update()
	Gather()
	Apply()
end

-- Sighting an awaited creature

local function Sighted(unit)
	if not Setting("scan") or #awaited == 0 then return end
	local name = UnitName(unit)
	-- Names can be secret in instances and PvP.
	if name == nil or issecretvalue(name) then return end
	local dead = UnitIsDead(unit)
	if issecretvalue(dead) or dead then return end
	for _, target in ipairs(awaited) do
		if target.kind == "scan" and target.name == name then
			local now = GetTime()
			local last = seen[name]
			seen[name] = now
			if not last or now - last > AGAIN_AFTER then
				PlaySound(SOUNDKIT.RAID_WARNING)
				T:Print(("|cffffffff%s|r is up. Your step needs it."):format(name))
			end
			Freshen()
			return
		end
	end
end

-- No background and no mouse on the strip itself, so the card takes clicks between the buttons.
local function Create()
	box = CreateFrame("Frame", "ShyQuestStepButtons", UIParent)
	box:SetSize(ns.CardWidth(), 1)
	box:SetFrameStrata("MEDIUM")
	box:Hide()
	for i = 1, TILES do tiles[i] = CreateTile(i) end
	for i = 1, LINES do lines[i] = CreateLine(i) end
end

Shy:On("SHY_LOGIN", function()
	local events = CreateFrame("Frame")
	for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "GROUP_ROSTER_UPDATE",
		"NAME_PLATE_UNIT_ADDED", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED" }) do
		events:RegisterEvent(event)
	end
	events:SetScript("OnEvent", function(_, event, unit)
		if event == "NAME_PLATE_UNIT_ADDED" then
			Sighted(unit)
		elseif event == "UPDATE_MOUSEOVER_UNIT" then
			Sighted("mouseover")
		elseif event == "PLAYER_TARGET_CHANGED" then
			Sighted("target")
		elseif event == "PLAYER_REGEN_ENABLED" then
			-- Secure buttons can't be created or set up in combat. (Always, not only for a change that
			-- waited: a card laid in the fight round chips it couldn't move is laid again by this, Stand.)
			if not box then Create() end
			Update()
		elseif box then
			Update()
		end
	end)
	-- A spell learned or lost (ShyCore says only when the book really changed).
	Shy:On("SHY_SPELLS", function() if box then Update() end end)
	if not InCombatLockdown() then Create() end
	ns.OnRoute(function(rebuilt)
		if rebuilt and box then Update() end
	end, true)
	if ns.OnApply then ns.OnApply(function()
		applied = nil
		if box then Update() end
	end) end
	-- The strip can't follow a drag, so it fades out until the card is dropped.
	Shy:On("SHY_HUD_MOVING", function(moved)
		if box and moved == ns.CardBox() then box:SetAlpha(0) end
	end)
	Shy:On("SHY_HUD_MOVED", function(moved)
		if box and moved == ns.CardBox() then
			dirty = dirty or InCombatLockdown()
			Stand()
		end
	end)
	Shy:On("SHY_HUD_LAYOUT", function() Stand() end)
	-- Sighting glows time out.
	C_Timer.NewTicker(5, function()
		if box and next(seen) then Freshen() end
	end)
	-- Re-place the strip once the card has settled somewhere new for two frames (a docked card
	-- is re-anchored a frame after its height changes), or its heading has changed height (the
	-- whole guide's progress bar comes and goes over the lead).
	local function Apart(a, b)
		if a == nil or b == nil then return a ~= b end
		return math.abs(a - b) > 0.05
	end
	local lastLeft, lastTop
	events:SetScript("OnUpdate", Shy.Clocked("frame: guide buttons", function()
		local host = box and ns.CardBox()
		if not host then return end
		-- (Nothing in the strip: it is away wherever the card stands. Given something, it is stood then (Apply),
		-- and a card that moved meanwhile is seen here at the next frame.)
		if #uses + #targets == 0 then return end
		local left, top = host:GetLeft(), host:GetTop()
		local still = not Apart(left, lastLeft) and not Apart(top, lastTop)
		lastLeft, lastTop = left, top
		if InCombatLockdown() or Shy.HUD.IsDragging(host) then return end
		-- (Or its lead has laid its counts anew: the chips under them go where their room is now.)
		if still and (Apart(left, stoodLeft) or Apart(top, stoodTop) or Apart(ns.CARD_HEAD, stoodHead)
			or ns.CardSlots() ~= stoodSlots) then Apply() end
	end))
end)

ns.GuideButtons = {
	-- (After every fill of the card: which counts it shows may have changed, and where they are. The card is
	-- told of a new route before this file is: what the step names is gathered here, not waited for.)
	Stand = function() Update() end,
	-- For the card, laid in a fight: where each group of chips stands under the strip's top, by its task, and
	-- how far down the lowest thing in the strip reaches.
	Stood = function()
		local out = {}
		for key, each in pairs(stood) do out[key] = each.at end
		return out
	end,
	Extent = function()
		local most = tall
		for _, each in pairs(stood) do most = math.max(most, each.at + each.tall) end
		return most
	end,
	Uses = function() return uses end,
	Targets = function() return targets end,
	Tiles = function() return tiles end,
	Lines = function() return lines end,
	Box = function() return box end,
}
