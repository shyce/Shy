-- Restyles the chat windows as a console panel: tab names in the title strip (accent line under the
-- selected one), the text, and a typing row at the foot while the edit box is open. All through
-- Shy.Skin kits, so switching it off restores Blizzard's art.
-- The typing row: the panel never moves, and at rest the text runs to its foot. When the box opens
-- the window lifts from its foot (Shy.HUD.Lift): the text glides up, the box hangs in the foot, and a
-- seam lit in the channel's color rides up over it, fading out along it. A moment after the box closes
-- they glide back down. (The panel is drawn to a rect of ours whose foot drops as the window lifts.)
--
-- Taint: the chat box runs protected slash commands. Never call an FCF_ or FCFDock_ function and
-- never write a field on a chat window, tab or the dock; only post-hook. No frame is moved, and
-- the only resize is a tab to its name (FitTab).
-- Kit paint keeps its colors, so L.Apply runs again on SHY_THEME (ShyChat.lua).
--
-- Layout is measured from Blizzard's background, where it anchors the tabs: the edit box is 32
-- tall from 4 above the background's foot, the button column 29 wide and 3 clear of it.
-- Blizzard animates the alpha of its background and border, so they can't be faded out: they get
-- empty art (CLEAR). It also fades tabs; while the panel is drawn, names, line and highlight
-- ignore their tab's alpha.
-- Tab widths: every tab is as wide as its name (FitTab). Blizzard sizes static docked tabs and
-- undocked windows that way but doesn't remeasure when the font changes or a window leaves the
-- dock, and it gives the dock's other tabs an equal share of the strip, so they are fitted after
-- each of its passes (a post-hook; FCFDock_UpdateTabs is never called, it would taint the dock).
-- A shared tab keeps Blizzard's share while the dock overflows, and a whisper's its fixed width.

local ADDON, ns = ...
local UI = Shy.UI
local Skin = Shy.Skin
local C = Skin.colors
local L = {}
ns.Look = L

local kit = Skin.NewKit()        -- windows, tabs and their buttons
local editKit = Skin.NewKit()    -- the edit boxes, which have their own switch
local hooked, on, editOn

local CLEAR = { 0, 0, 0, 0 }
local WHITE = { 1, 1, 1, 1 }
-- Strength of the hover glow behind a tab's name. Blizzard resets the texture's color and alpha
-- when it recolors the tab, so the strength is multiplied into the color.
local LIGHT = 0.3
local PIECES = {
	"Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
	"LeftTexture", "RightTexture", "BottomTexture", "TopTexture",
}
local TAB_ART = { "Left", "Middle", "Right", "HighlightLeft", "HighlightRight", "ActiveRight" }
local EDIT_ART = { "Left", "Mid", "Right", "FocusLeft", "FocusMid", "FocusRight" }
local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }
local BUTTON_TINT = { C.glyph, C.lit, C.hover, C.idle }

-- Blizzard's background, out from the chat frame's sides { left, top, right, bottom }.
local BACKGROUND = { 2, 3, 15, 6 }
-- The strip's height, and its foot's distance above the background's top: Blizzard stands a tab's
-- name 9 above the background (a 32 tab on it, the name 7 under the tab's middle): the strip's
-- middle between its lip and its line, where every header's words stand (UI.HEAD_MID).
local STRIP, STRIP_FOOT = UI.HEAD_STRIP, 1
-- Window.lua places the toolbar in the strip under the header's lip.
L.STRIP, L.STRIP_FOOT, L.CHANNEL = STRIP, STRIP_FOOT, STRIP - UI.HEAD_LIP
-- The panel, out from the background.
local HEAD = STRIP_FOOT + STRIP
local LEFT, RIGHT, FOOT = 6, 1, 28
-- With the button column on a side, that side extends 3 past the column's well.
local COLUMN = 36
local WELL_INSET = { -1, -1, -1, -2 }
-- The edit box's plate with default windows, inside the edit box's 32 tall rectangle.
local EDIT_INSET = { 1, 5, 4, 5 }
-- The typing row: it opens in OPEN seconds, and closes in CLOSE after a HOLD. Its seam stands SEAM_Y
-- under the background's foot (the box's top is 4 over it), SEAM_IN in from the panel's sides, its
-- hairlines fading in and out over SEAM_ENDS; the channel's light reaches SEAM_SHARE of the way across.
local OPEN, CLOSE, HOLD = 0.1, 0.2, 1
local SEAM_Y, SEAM_IN, SEAM_ENDS, SEAM_SHARE = 2, 3, 48, 0.7
-- The glow behind a tab's name, under the mouse or open: the tab's own width less TAB_IN at each
-- end (tabs stand 1 apart), from LIGHT_UP over the name down to the panel's line.
local LIGHT_UP, TAB_IN = 3, 1
-- Left inset of the edit box's text: Blizzard's, and ours (aligned with the chat text).
local BLIZZARD_PAD, EDIT_PAD = 15, 5

local function Empty(name)
	for _, piece in ipairs(PIECES) do kit:Art(_G[name .. piece], CLEAR) end
end

-- One of our glyphs in place of a button's own art, inset by x and y.
local function Glyph(button, file, x, y)
	for i, getter in ipairs(BUTTON_ART) do
		kit:Art(button[getter](button), file, { fit = button, x = x, y = y, color = BUTTON_TINT[i] })
	end
end

local function ScrollBar(bar)
	kit:Regions(bar.Track, C.inset)
	kit:Regions(bar.Track.Thumb, C.metal)
	kit:Tint(bar.Back.Texture, C.metal)
	kit:Tint(bar.Forward.Texture, C.metal)
end

-- The panel

-- The panel's inset from Blizzard's background, with the button column on side "L", "R" or
-- "" (hidden). Negative is outward. The foot is the typing row's (Body).
local function Inset(side)
	return { side == "L" and -COLUMN or -LEFT, -HEAD, side == "R" and -COLUMN or -RIGHT, 0 }
end

local wings = setmetatable({}, { __mode = "k" })   -- chat frame -> the panel art it shows now

-- The panel must draw under the tab names. Art on a child of the chat window was drawn over the
-- docked tabs whatever strata the child had, so the panel's frame is a child of the window's
-- parent at the bottom of BACKGROUND. Not being the window's child, it is shown and hidden with
-- the window by hand, here and in Watch.
local unders = setmetatable({}, { __mode = "k" })   -- chat frame -> the frame its panel is drawn on

local function Under(frame)
	local under = unders[frame]
	if not under then
		under = CreateFrame("Frame", nil, frame:GetParent())
		under.isUnder = true
		under:SetAllPoints(frame)
		under:SetFrameStrata("BACKGROUND")
		under:SetFrameLevel(0)
		unders[frame] = under
		-- The chat window's housing while the HUD is faded: gone while you play, back while you are away.
		local immersion = Shy.Immersion
		if immersion and immersion.Watch then immersion.Watch("chat", under, "housing") end
	end
	under:SetShown(frame:IsShown())
	return under
end
L.Under = Under

-- Moving and resizing. The first window is the piece (the game's default chat frame, which Edit
-- Mode places); the windows docked with it stand on it. With "Move and resize" on, a drag on the
-- title strip where no tab stands moves it, as does a drag on the first window's own tab (Blizzard
-- leaves that tab to Edit Mode), and the panel's corners and sides resize it from where they are
-- (the core's grip). Only the engine's own SetPointBase, SetSize and sizing touch the window: no chat
-- function is called.
local piece                                           -- the first window as a Shy.HUD box
local grabs = setmetatable({}, { __mode = "k" })      -- chat frame -> the handle under its strip

local function Movable()
	return on == true and ns.T.db.move == true
end

-- The panel whose corner the grip stands on: the docked window that is open.
local function GripRegion()
	if not Movable() then return nil end
	local set = wings[GeneralDockManager.selected or DEFAULT_CHAT_FRAME]
	return set and kit:Outline(set) or nil
end

-- What lies over each part of the panel on a layer of its own, far above the window's: there that
-- part's handle stands over it, or it would hide the handle and take the mouse everywhere but a
-- sliver past the edge. Along the top, the tabs: they stand over the title strip and well past the
-- panel's top edge (the one standing highest serves for all of them). Along the foot, Blizzard's
-- edit box, to its right end, corners included (the open window's box, or the first window's:
-- whichever is on screen). Nothing lies on the sides.
local function GripAbove(point)
	if point == "LEFT" or point == "RIGHT" then return nil end
	if point == "TOP" or point == "TOPLEFT" or point == "TOPRIGHT" then
		local docked = GeneralDockManager.DOCKED_CHAT_FRAMES
		local highest, level
		for _, frame in ipairs(type(docked) == "table" and docked or {}) do
			local tab = _G[frame:GetName() .. "Tab"]
			local at = tab and tab:IsShown() and tab:GetFrameLevel()
			if at and (not level or at > level) then highest, level = tab, at end
		end
		return highest
	end
	for _, frame in ipairs({ GeneralDockManager.selected or DEFAULT_CHAT_FRAME, DEFAULT_CHAT_FRAME }) do
		local box = frame.editBox
		if box then
			local visible = box:IsVisible()
			if not issecretvalue(visible) and visible == true then return box end
		end
	end
	return nil
end

-- A window taken out of the dock is held all the way round as the docked piece is, and sized as
-- Blizzard's corner sizes it, saved as that corner saves it. Over its top its tab, over its foot its
-- edit box, as GripAbove's.
local floated = setmetatable({}, { __mode = "k" })

local function FloatAbove(frame)
	return function(point)
		if point == "LEFT" or point == "RIGHT" then return nil end
		if point:find("TOP", 1, true) then
			local tab = _G[frame:GetName() .. "Tab"]
			return tab and tab:IsShown() and tab or nil
		end
		local box = frame.editBox
		local visible = box and box:IsVisible()
		if box and not issecretvalue(visible) and visible == true then return box end
		return nil
	end
end

local function Float(frame)
	if floated[frame] or not Shy.HUD.GripFrame then return end
	floated[frame] = true
	Shy.HUD.GripFrame(frame, {
		id = "shychat." .. frame:GetName(), title = "Chat", size = true, above = FloatAbove(frame),
		over = function()
			local set = wings[frame]
			return set and kit:Outline(set) or nil
		end,
		shown = function() return Movable() and not frame.isDocked and not frame.isLocked and not frame.isUninteractable end,
		kept = function() FCF_SavePositionAndDimensions(frame) end,
	})
end

local grip                                            -- the piece's corner grip
local yielded = setmetatable({}, { __mode = "k" })    -- edit box -> its hit rect insets before
local relooked = setmetatable({}, { __mode = "k" })   -- edit boxes whose showing and pressing are followed

-- Standing over the edit box is not enough to be found under the mouse: the box is raised over
-- everything on its layer each time it is pressed, the grip with it, until the grip is looked at
-- again. So the box also gives the mouse up at its right end, where its text never reaches: the part
-- of it that lies in the grip's corner, measured from `region`'s edge (Blizzard hangs its end 8 past
-- the scroll bar, which is the panel's edge). Without a region it takes the mouse back.
local function Yield(frame, region)
	local box = frame.editBox
	if InCombatLockdown() and box:IsProtected() then return end
	local was = yielded[box]
	if not (region and grip) then
		if was then
			yielded[box] = nil
			box:SetHitRectInsets(was[1], was[2], was[3], was[4])
		end
		return
	end
	if not was then
		was = { box:GetHitRectInsets() }
		yielded[box] = was
	end
	-- The handles on the foot are looked at again the moment the box opens, closes or is pressed.
	if not relooked[box] then
		relooked[box] = true
		local function Relook()
			C_Timer.After(0, function() grip:Follow() end)
		end
		box:HookScript("OnShow", Relook)
		box:HookScript("OnHide", Relook)
		box:HookScript("OnMouseDown", Relook)
	end
	-- Nothing where the box ends short of the corner (the button column on that side widens the panel).
	local give = grip.core
	local edge, right = region:GetRight(), box:GetRight()
	if edge and right and not issecretvalue(edge) and not issecretvalue(right) then give = math.max(0, give + right - edge) end
	box:SetHitRectInsets(was[1], was[2] + give, was[3], was[4])
end

-- Same id as the core's own adoption of the frame, so a place given to it in layout mode is kept.
local function Piece(frame)
	if piece then return piece end
	piece = Shy.HUD.Adopt(frame, { id = "game." .. frame:GetName(), title = "Chat", editMode = true, plain = true })
	local tab = _G[frame:GetName() .. "Tab"]
	if tab then Shy.HUD.Manage(piece, tab, false, Movable) end
	if Shy.HUD.Grip then grip = Shy.HUD.Grip(piece, { size = true, over = GripRegion, above = GripAbove }) end
	return piece
end

-- The handle lies under the strip, on the panel's own frame at the bottom of BACKGROUND: tabs and
-- the toolbar, which stand higher, take the mouse where they are.
local function Grab(frame, set)
	local first = DEFAULT_CHAT_FRAME
	if frame == first then Piece(frame) end
	local grab = grabs[frame]
	local docked = frame == first or (frame.isDocked and true or false)
	local can = piece ~= nil and set ~= nil and docked and Movable()
	Yield(frame, can and set.fill or nil)
	if not (can and set.strip) then
		if grab then grab:Hide() end
		return
	end
	if not grab then
		grab = CreateFrame("Frame", nil, Under(frame))
		grabs[frame] = grab
		Shy.HUD.Manage(piece, grab, nil, Movable)
	end
	grab:ClearAllPoints()
	grab:SetPoint("TOPLEFT", set.strip, "TOPLEFT")
	grab:SetPoint("BOTTOMRIGHT", set.strip, "BOTTOMRIGHT")
	grab:Show()
end

-- The typing row

-- The channel the box is set to, as a color.
local function ChannelColor(editBox)
	local chatType = editBox:GetChatType()
	local key = chatType == "CHANNEL" and ("CHANNEL" .. (editBox:GetChannelTarget() or "")) or chatType
	local info = ChatTypeInfo[key] or ChatTypeInfo[chatType]
	return info and { info.r, info.g, info.b, 1 }
end

-- The rect a window's panel is drawn to with the edit box restyled: Blizzard's background, its foot
-- `drop` lower while the row is open (whole units, so the panel's edge stays crisp as it glides). The
-- first window and the ones docked with it are lifted that much from their foot as it opens (Shy.HUD.Lift,
-- the piece's): the text rises, the box hangs in the foot, and the panel stays where it is.
local bodies = setmetatable({}, { __mode = "k" })   -- chat frame -> its rect
local feet = setmetatable({}, { __mode = "k" })     -- chat frame -> { at = how open (0 to 1), to, closeAt, drop }

local function Foot(frame)
	local foot = feet[frame]
	if not foot then
		foot = { at = 0, to = 0 }
		feet[frame] = foot
	end
	return foot
end

-- The panel's foot band while the row is open (the look's zones, UI.LookZones): from its bottom up to the row's seam.
local function Band(frame, drop)
	local set = wings[frame]
	if set and set.look then UI.LookZones(set.look, nil, drop > SEAM_Y and drop - SEAM_Y or 0) end
end

local function Drop(frame, drop)
	local body, bg = bodies[frame], frame.Background
	body:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT", 0, -drop)
	body:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", 0, -drop)
	Foot(frame).drop = drop
	Band(frame, drop)
end

local function Body(frame)
	if not bodies[frame] then
		local body = CreateFrame("Frame", nil, Under(frame))
		body:SetPoint("TOPLEFT", frame.Background, "TOPLEFT")
		body:SetPoint("TOPRIGHT", frame.Background, "TOPRIGHT")
		bodies[frame] = body
		Drop(frame, 0)
	end
	return bodies[frame]
end

-- A hairline fading in from its left end and out at its right, over SEAM_ENDS each.
local function Hairline(row, r, g, b, a)
	local line = {}
	for i = 1, 3 do
		local t = row:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(1, 1, 1, 1)
		t:SetHeight(1)
		line[i] = t
	end
	line[1]:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a))
	line[2]:SetVertexColor(r, g, b, a)
	line[3]:SetGradient("HORIZONTAL", CreateColor(r, g, b, a), CreateColor(r, g, b, 0))
	line[1]:SetWidth(SEAM_ENDS)
	line[3]:SetWidth(SEAM_ENDS)
	line[2]:SetPoint("TOPLEFT", line[1], "TOPRIGHT")
	line[2]:SetPoint("BOTTOMRIGHT", line[3], "BOTTOMLEFT")
	return line
end

-- The options' preview draws the row with these.
L.Hairline, L.SEAM_SHARE = Hairline, SEAM_SHARE

local rows = setmetatable({}, { __mode = "k" })   -- chat frame -> its row: the seam and the light along it

-- The channel's light: from the seam's left end, SEAM_SHARE of the way across.
local function Reach(row)
	local frame = row.frame
	local width = frame.Background:GetWidth()
	if not width or issecretvalue(width) then return end
	local inset = row.inset
	row.light:SetWidth(math.max(1, (width - inset[1] - inset[3] - 2 * SEAM_IN) * SEAM_SHARE))
end

-- Where the box's words stand, for a look that frames them itself: units in from the panel's left and right edges to
-- where they start and end, and down from the top of the row's band to their middle (the same all the way through
-- the glide: the box and the band's top both hang from the background). Nil while the box isn't laid out.
local TEXT_RIGHT = 13   -- the right text inset (IndentText)
local function Field(frame, h)
	local box, bg, to = frame.editBox, frame.Background, h.to
	local l, r = to:GetLeft(), to:GetRight()
	local el, er, eb, et, bb = box:GetLeft(), box:GetRight(), box:GetBottom(), box:GetTop(), bg:GetBottom()
	local ks, ts = box:GetEffectiveScale(), to:GetEffectiveScale()
	for _, v in ipairs({ l or 0, r or 0, el or 0, er or 0, eb or 0, et or 0, bb or 0, ks or 0, ts or 0 }) do
		if issecretvalue(v) then return end
	end
	if not (l and r and el and er and eb and et and bb and ks and ts and ts > 0) then return end
	local k = ks / ts   -- the box's units in the panel's
	return { left = el * k - l + EDIT_PAD * k, right = r - er * k + TEXT_RIGHT * k, mid = (bb - SEAM_Y - (eb + et) / 2) * k }
end

-- What the box says, for a look that draws the typing row itself (UI.LookFoot): its voice, its color, whether it is
-- only holding text (not typed in), and where its words stand.
local VOICES = { SAY = "say", YELL = "yell", WHISPER = "whisper", BN_WHISPER = "whisper", EMOTE = "emote" }
local function Speak(frame)
	local set = wings[frame]
	if not (set and set.look) then return end
	local box = frame.editBox
	local color = ChannelColor(box)
	UI.LookFoot(set.look, color and { voice = VOICES[box:GetChatType()] or "channel", color = color, idle = not box:HasFocus(),
		field = Field(frame, set.look) } or nil)
end

local function Tint(frame)
	local row = rows[frame]
	local color = row and ChannelColor(frame.editBox)
	if color then row.light:SetVertexColor(color[1], color[2], color[3]) end
	Speak(frame)
end

-- The seam over the row, a dark hairline over a faint light one (cut into the panel), the channel's
-- light along it; laid across the panel at `inset` (its button column's side).
local function Row(frame, inset)
	local row = rows[frame]
	if not row then
		row = CreateFrame("Frame", nil, Under(frame))
		row:SetAllPoints(frame)
		row.frame = frame
		row.dark = Hairline(row, 0, 0, 0, 0.45)
		row.lit = Hairline(row, 1, 1, 1, 0.06)
		row.light = row:CreateTexture(nil, "ARTWORK", nil, 1)
		row.light:SetTexture(UI.LookArt.SEAM)
		row.light:SetHeight(UI.LookArt.SEAM_H)
		row:SetScript("OnSizeChanged", Reach)
		row:SetAlpha(0)
		row:Hide()
		rows[frame] = row
	end
	row.inset = inset
	local bg = frame.Background
	local left, right = inset[1] + SEAM_IN, -inset[3] - SEAM_IN
	for i, line in ipairs({ row.dark, row.lit }) do
		local y = -SEAM_Y - (i - 1)
		line[1]:ClearAllPoints()
		line[1]:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", left, y)
		line[3]:ClearAllPoints()
		line[3]:SetPoint("TOPRIGHT", bg, "BOTTOMRIGHT", right, y)
	end
	row.light:ClearAllPoints()
	row.light:SetPoint("TOPLEFT", bg, "BOTTOMLEFT", left, -SEAM_Y)
	Reach(row)
	Tint(frame)
end

local function Ease(x)
	return x * x * (3 - 2 * x)
end

-- Windows standing where the first does: it and the ones docked with it (they hang on it). (The game
-- marks a docked window with 1, not true.)
local function Docked(frame)
	return frame == DEFAULT_CHAT_FRAME or (frame.isDocked and true or false)
end

-- Every window's foot and row as open as its box is now. The docked windows share one: the most open of
-- their boxes, which the piece is lifted by. An undocked window isn't the piece: its panel grows down.
local function Lay()
	local docked = 0
	for frame, foot in pairs(feet) do
		if Docked(frame) then docked = math.max(docked, foot.at) end
	end
	local live = on and editOn
	local lift = live and math.floor(FOOT * Ease(docked) + 0.5) or 0
	if piece then Shy.HUD.Lift(piece, lift) end
	for frame, foot in pairs(feet) do
		local open = live and Ease(Docked(frame) and docked or foot.at) or 0
		if bodies[frame] then
			local drop = Docked(frame) and lift or math.floor(FOOT * open + 0.5)
			if drop ~= foot.drop then Drop(frame, drop) end
		end
		local row = rows[frame]
		if row then
			-- It rides up from under the panel's foot with the window: unseen until it is nearly there. A look that
			-- draws the typing row itself (UI.LookOwnsFoot) wears its own instead.
			local set = wings[frame]
			row:SetAlpha(open * open)
			row:SetShown(open > 0 and not (set and set.look and UI.LookOwnsFoot(set.look)))
		end
	end
end

-- Is someone typing in the box? Shown with its focus, or holding unsent text (the chat style that
-- keeps a closed box up shows it faded, with neither).
local function Typing(box)
	if not box:IsShown() then return false end
	if box:HasFocus() then return true end
	local text = box:GetText()
	return not issecretvalue(text) and text ~= nil and text ~= ""
end

local glider = CreateFrame("Frame")
glider:Hide()
glider:SetScript("OnUpdate", Shy.Clocked("chat: the typing row", function(self, elapsed)
	local now, busy, moved, landed = GetTime(), false, false, false
	for _, foot in pairs(feet) do
		if foot.closeAt and now >= foot.closeAt then foot.to, foot.closeAt = 0, nil end
		if foot.at ~= foot.to then
			local opening = foot.to > foot.at
			local step = elapsed / (opening and OPEN or CLOSE)
			foot.at = opening and math.min(foot.to, foot.at + step) or math.max(foot.to, foot.at - step)
			moved = true
			if foot.at == foot.to then landed = true end
		end
		if foot.at ~= foot.to or foot.closeAt then busy = true end
	end
	if moved then Lay() end
	-- The box hangs from the window's foot, which was lifted: look again at the corner grip's handles.
	if landed and grip then grip:Follow() end
	if not busy then self:Hide() end
end))

-- Open the row while the box is typed in; close it a moment after it isn't.
local function Want(frame)
	local foot = Foot(frame)
	if on and editOn and Typing(frame.editBox) then
		foot.to, foot.closeAt = 1, nil
	elseif foot.to == 1 and not foot.closeAt then
		foot.closeAt = GetTime() + HOLD
	end
	Speak(frame)   -- typed in or only holding text
	glider:Show()
end

local attended = setmetatable({}, { __mode = "k" })   -- chat frames whose box is followed

local function Attend(frame)
	if attended[frame] then return end
	attended[frame] = true
	local function Again() Want(frame) end
	local box = frame.editBox
	box:HookScript("OnShow", Again)
	box:HookScript("OnHide", Again)
	box:HookScript("OnEditFocusGained", Again)
	box:HookScript("OnEditFocusLost", Again)
end

-- At once, as the settings stand (no glide when a setting changes).
local function Settle(frame)
	Attend(frame)
	local foot = Foot(frame)
	foot.closeAt = nil
	foot.to = (on and editOn and Typing(frame.editBox)) and 1 or 0
	foot.at = foot.to
end

-- The open tab's stretch of the line: a mark of the core's on its window's own line (the wing in use), the
-- line's own make in every look (a lit length of the riveted trim, a bar of light on the others). Moved to
-- the new line when the wing changes; shown while Blizzard has the tab selected (TabColors).
local marked = setmetatable({}, { __mode = "k" })   -- tab -> its mark
local function TabMark(frame)
	local tab = _G[frame:GetName() .. "Tab"]
	if not tab then return end
	local set, was = wings[frame], marked[tab]
	local mark = on and set and set.line and kit:Mark(tab, set.line).mark or nil
	if was and was ~= mark then was:Hide() end
	marked[tab] = mark
	if on then kit:Fade(tab.ActiveMiddle, mark and 0 or 1) end
	if not mark then return end
	mark:Span(tab, tab, TAB_IN)
	mark:SetShown(tab.ActiveMiddle:IsShown())
end
function L.TabMark(tab) return marked[tab] end

-- Draw a window's panel at the width its button column needs. Each width is its own art, made
-- on first use (keyed); the previous one is hidden. With the edit box restyled it is drawn to the
-- row's rect, and the row's seam laid across it.
-- Which side of a window Blizzard's button column stands on now ("": hidden), and the one each window's panel
-- was last fitted for.
local function Side(frame)
	if not frame.buttonFrame:IsShown() then return "" end
	return frame.buttonSide == "right" and "R" or "L"
end
local sided = setmetatable({}, { __mode = "k" })

local function Wing(frame)
	local strength = Shy.Theme.Strength()
	local side = Side(frame)
	sided[frame] = side
	local set
	if strength > 0 then
		-- hud: opacity follows the Background setting.
		set = kit:Plate(Under(frame), {
			key = "wing" .. side .. (editOn and "Foot" or ""), to = editOn and Body(frame) or frame.Background,
			inset = Inset(side), panel = true, cap = true, title = STRIP, hud = true,
		})
	end
	if editOn then Row(frame, Inset(side)) end
	local was = wings[frame]
	if was and was ~= set then
		for _, region in ipairs(was) do region:Hide() end
		if was.outline then was.outline:Hide() end
	end
	wings[frame] = set
	TabMark(frame)
	Band(frame, Foot(frame).drop or 0)
	-- The layout editor fits its sheet to the panel rather than the message frame.
	Shy.HUD.SetHousing(frame, set and kit:Outline(set) or nil)
	Grab(frame, set)
end
-- (On the clock: a panel fitted is a housing dressed, the costliest thing the chat does.)
Wing = Shy.Clocked("chat: a window's panel fitted", Wing)

local watched = setmetatable({}, { __mode = "k" })
local frameOf = setmetatable({}, { __mode = "k" })   -- tab -> its chat frame
-- Windows with lines added while out of sight (a docked tab not open): their name is gold until opened.
local unread = setmetatable({}, { __mode = "k" })
local TabColors

function L.Unread(frame) return unread[frame] == true end

-- Refit the panel whenever Blizzard's column shows or hides; note new lines while the window is away.
local function Watch(frame)
	if watched[frame] then return end
	watched[frame] = true
	local tab = _G[frame:GetName() .. "Tab"]
	if tab then frameOf[tab] = frame end
	hooksecurefunc(frame, "AddMessage", function(self)
		if self:IsVisible() or unread[self] then return end
		unread[self] = true
		if tab then TabColors(tab, false) end
	end)
	frame:HookScript("OnShow", function(self)
		if not unread[self] then return end
		unread[self] = nil
		if tab then TabColors(tab, tab.ActiveMiddle:IsShown()) end
	end)
	local function Fit()
		if on then Wing(frame) end
	end
	-- (The column come or gone on a window in sight: fitted once for the side it now stands on, however many
	-- say so. Out of sight, the window is fitted as it shows.)
	local function Column()
		if on and frame:IsShown() and Side(frame) ~= sided[frame] then Wing(frame) end
	end
	frame.buttonFrame:HookScript("OnShow", Column)
	frame.buttonFrame:HookScript("OnHide", Column)
	-- OnShow/OnHide don't fire for a column whose window isn't visible: refit when the window shows.
	frame:HookScript("OnShow", Fit)
	-- Every window is checked each time: one hidden while the whole UI is hidden fires nothing.
	local function Follow()
		for window, under in pairs(unders) do under:SetShown(window:IsShown()) end
	end
	frame:HookScript("OnShow", Follow)
	frame:HookScript("OnHide", Follow)
end

-- Window.lua calls this after hiding or showing columns: each window in sight whose column is no longer where
-- its panel was fitted for is fitted again. A window out of sight (another tab's) is fitted as it shows (Watch):
-- fitting every window at every coming and going of the columns dressed ten panels each time the mouse came
-- onto the chat or left it.
function L.Refit()
	if not on then return end
	for frame in pairs(watched) do
		if frame:IsShown() and Side(frame) ~= sided[frame] then Wing(frame) end
	end
end

-- Tabs

local solid = {}   -- region -> whether it ignored its parent's alpha before

-- Stop a region fading with its tab.
local function Solid(region)
	if not region or solid[region] ~= nil then return end
	solid[region] = region:IsIgnoringParentAlpha()
	local faded = Shy.Immersion and Shy.Immersion.Faded()
	region:SetIgnoreParentAlpha(not faded or solid[region])
end

-- While the HUD fades when idle (Shy.Immersion), solid tab regions fade with it.
Shy:On("SHY_IMMERSION_FADE", function(faded)
	for region, was in pairs(solid) do region:SetIgnoreParentAlpha(not faded or was) end
end)

local tiled = {}   -- texture -> whether Blizzard tiled its art

-- Blizzard tiles a tab's middle art; a glow has to be stretched instead.
local function Stretch(texture)
	if tiled[texture] == nil then tiled[texture] = texture:GetHorizTile() end
	texture:SetHorizTile(false)
end

local shadows = {}   -- a tab's name -> Blizzard's shadow

-- A hard shadow keeps names readable over a transparent strip. It doesn't change the measured width.
local function Shadow(name)
	if not shadows[name] then
		shadows[name] = { color = { name:GetShadowColor() }, offset = { name:GetShadowOffset() } }
	end
	name:SetShadowColor(0, 0, 0, 1)
	name:SetShadowOffset(1, -1)
end

local function ResetTabArt()
	for region, was in pairs(solid) do region:SetIgnoreParentAlpha(was) end
	wipe(solid)
	for texture, was in pairs(tiled) do texture:SetHorizTile(was) end
	wipe(tiled)
	for name, was in pairs(shadows) do
		name:SetShadowColor(unpack(was.color))
		name:SetShadowOffset(unpack(was.offset))
	end
	wipe(shadows)
end

-- An unselected tab's name rests this far from the palette's dim toward its text color: stepped
-- back, so the open tab, a hovered one and one with new lines (gold) stand out.
local QUIET = 0.3

-- Computed from the palette each time, so it follows the theme.
local function NameColor(bright)
	local text, dim = UI.colors.text, UI.colors.dim
	if bright then return text[1], text[2], text[3] end
	return dim[1] + (text[1] - dim[1]) * QUIET, dim[2] + (text[2] - dim[2]) * QUIET, dim[3] + (text[3] - dim[3]) * QUIET
end
L.NameColor = NameColor

-- Post-hook on FCFTab_UpdateColors. A whisper tab (selectedColorTable) keeps Blizzard's colors.
function TabColors(tab, selected)
	if not on or not kit:Has(tab.ActiveMiddle) then return end
	if marked[tab] then marked[tab]:SetShown(selected and true or false) end
	local own = tab.selectedColorTable
	if own then
		tab.HighlightMiddle:SetVertexColor(own.r * LIGHT, own.g * LIGHT, own.b * LIGHT)
		return
	end
	local alert, light = UI.colors.alert, Shy.Theme.light
	tab.HighlightMiddle:SetVertexColor(C.hover[1] * LIGHT, C.hover[2] * LIGHT, C.hover[3] * LIGHT)
	-- The open tab: its stretch of the line lit (its mark; with no panel, its own art: a tint would show
	-- that art again, so only then), a glow rising from it (as UI.Tabs lights a window's).
	if not marked[tab] then tab.ActiveMiddle:SetVertexColor(light[1], light[2], light[3]) end
	tab.ActiveLeft:SetVertexColor(C.hover[1], C.hover[2], C.hover[3])
	tab.glow:SetVertexColor(alert[1], alert[2], alert[3])
	local name = tab:GetFontString()
	-- New lines since the window was last open, or a flash of the game's (a whisper): gold.
	local frame = frameOf[tab]
	if not selected and ((frame and unread[frame]) or ChatFrameUtil.IsTabAlerting(tab)) then
		name:SetTextColor(alert[1], alert[2], alert[3])
	else
		name:SetTextColor(NameColor(selected or tab:IsMouseOver()))
	end
end

-- Blizzard recolors a tab only on selection, not when a flash starts or stops.
local function Alerted(frame)
	local tab = _G[frame:GetName() .. "Tab"]
	TabColors(tab, tab.ActiveMiddle:IsShown())
end

-- The dock's overflow, once the tabs don't fit: its arrow at the row's end (gold while a tab out of
-- sight has news) and its list of every window as a panel of the family's, the count in its title
-- strip, rows in the title font: the open one plain, one with new lines gold with a line of light
-- flashing under it (Blizzard animates that texture's alpha, so it gets art, not a fade).

local overflowRows = setmetatable({}, { __mode = "k" })

local function PaintOverflowRow(row)
	if overflowRows[row] then return end
	overflowRows[row] = true
	kit:FontObject(row:GetFontString(), UI.TitleFont())
	kit:Art(row.highlight, Shy.Brand.GLOW, { blend = "ADD" })
	kit:Tint(row.highlight, C.hover)
	kit:Art(row.glow, WHITE, { blend = "BLEND" })
	kit:Place(row.glow, nil, UI.LINE, { "BOTTOMLEFT", row, "BOTTOMLEFT", 2, -1 }, { "BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, -1 })
end

-- Post-hook on FCFDockOverflowListButton_SetValue: Blizzard writes the row's colors on every update.
local function OverflowRowColors(row, frame)
	if not on then return end
	PaintOverflowRow(row)
	local tab = _G[frame:GetName() .. "Tab"]
	if not tab or tab.selectedColorTable then return end   -- a whisper window keeps Blizzard's colors
	local alert = UI.colors.alert
	row.glow:SetVertexColor(alert[1], alert[2], alert[3])
	local name = row:GetFontString()
	if frame == GeneralDockManager.selected then
		name:SetTextColor(NameColor(true))
	elseif unread[frame] or ChatFrameUtil.IsTabAlerting(tab) then
		name:SetTextColor(alert[1], alert[2], alert[3])
	else
		name:SetTextColor(NameColor(false))
	end
end

local OVERFLOW_TITLE = 18

local function PaintOverflow()
	local button = GeneralDockManager.overflowButton
	kit:Button(button, C.metal, C.lit, UI.colors.alert)
	local list = button.list
	if not list then return end
	if list.NineSlice then kit:Hide(list.NineSlice) end
	local set = kit:Plate(list, { key = "overflow", panel = true, title = OVERFLOW_TITLE })
	if list.numTabs then
		kit:FontObject(list.numTabs, UI.TitleFont())
		kit:Text(list.numTabs, UI.colors.dim)
		-- On the strip's middle, as every header's words, at Blizzard's margin (the list is the count and 24 each side).
		kit:Place(list.numTabs, nil, nil, UI.HeadPoint("LEFT", set, "LEFT", 24))
	end
	for _, row in ipairs(list.buttons or {}) do PaintOverflowRow(row) end
end

local lit = setmetatable({}, { __mode = "k" })   -- tabs with hover hooks

local function LightUp(tab)
	if lit[tab] then return end
	lit[tab] = true
	local function Follow(self)
		TabColors(self, self.ActiveMiddle:IsShown())
	end
	tab:HookScript("OnEnter", Follow)
	tab:HookScript("OnLeave", Follow)
end

local function PaintTab(tab, housed, frame)
	local name = tab:GetFontString()
	kit:FontObject(name, UI.TitleFont())
	-- Blizzard's anchors (ChatTabArtTemplate).
	kit:Place(name, nil, nil, { "LEFT", tab.Left, "LEFT", 0, -7 }, { "RIGHT", tab.Right, "RIGHT", 0, -7 })
	for _, key in ipairs(TAB_ART) do kit:Hide(tab[key]) end
	-- Shown by Blizzard while the tab is selected. Its stretch of the panel's accent line is lit by a mark of
	-- the core's (TabMark), and this art faded out; with no panel (no Background) it is that line itself. It
	-- stays where that stretch is (the line runs along the strip's foot, STRIP_FOOT over Blizzard's
	-- background), for the glow to rise from...
	kit:Art(tab.ActiveMiddle, WHITE, { blend = "BLEND" })
	kit:Place(tab.ActiveMiddle, nil, UI.LineHeight(tab),
		{ "TOP", frame.Background, "TOP", 0, STRIP_FOOT },
		{ "LEFT", tab, "LEFT", TAB_IN, 0 },
		{ "RIGHT", tab, "RIGHT", -TAB_IN, 0 })
	-- ...and a glow rising from that line behind the name, as wide: the hover light's box exactly.
	kit:Art(tab.ActiveLeft, UI.GLOSS, { blend = "BLEND", coords = { 0, 1, 1, 0 } })
	kit:Place(tab.ActiveLeft, nil, nil,
		{ "TOP", name, "TOP", 0, LIGHT_UP },
		{ "BOTTOM", tab.ActiveMiddle, "BOTTOM", 0, 0 },
		{ "LEFT", tab, "LEFT", TAB_IN, 0 },
		{ "RIGHT", tab, "RIGHT", -TAB_IN, 0 })
	-- Shown on hover: becomes a glow behind the name, in the same box.
	kit:Art(tab.HighlightMiddle, Shy.Brand.GLOW, { blend = "ADD" })
	Stretch(tab.HighlightMiddle)
	kit:Place(tab.HighlightMiddle, nil, nil,
		{ "TOP", name, "TOP", 0, LIGHT_UP },
		{ "BOTTOM", tab.ActiveMiddle, "BOTTOM", 0, 0 },
		{ "LEFT", tab, "LEFT", TAB_IN, 0 },
		{ "RIGHT", tab, "RIGHT", -TAB_IN, 0 })
	-- The alert flash: Blizzard animates this texture's alpha, so it gets new art, not a fade. It
	-- flashes where the open tab's light would be.
	kit:Art(tab.glow, WHITE, { blend = "BLEND" })
	kit:Place(tab.glow, nil, UI.LineHeight(tab),
		{ "TOP", frame.Background, "TOP", 0, STRIP_FOOT },
		{ "LEFT", tab, "LEFT", TAB_IN, 0 },
		{ "RIGHT", tab, "RIGHT", -TAB_IN, 0 })
	if housed then
		Solid(name)
		Solid(tab.ActiveMiddle)
		Solid(tab.ActiveLeft)
		Solid(tab.HighlightMiddle)
		Solid(tab.conversationIcon)   -- a whisper tab's portrait
	end
	Shadow(name)
	LightUp(tab)
	TabMark(frame)
	TabColors(tab, tab.ActiveMiddle:IsShown())
end

-- Resize a tab to its name in the current font (see the header), with the arithmetic of
-- PanelTemplates_TabResize: the name, 20 around it, the tab's padding, and never narrower than
-- its two end pieces. Sets widths only; writes no field and calls no chat function. True when
-- the tab was sized.
local TAB_SIDES = 20

local function FitTab(frame)
	local tab = _G[frame:GetName() .. "Tab"]
	if not tab then return end
	-- A whisper window's tab has a fixed width; its chat type and name can be secret.
	local kind = frame.chatType
	if issecretvalue(kind) or kind == "WHISPER" or kind == "BN_WHISPER" then return end
	-- The dock gives each of its other tabs the same share of the room left, and scrolls them by
	-- that share once they overflow: they keep it then, and no name gets more than it.
	local share
	if frame.isDocked and not frame.isStaticDocked then
		if GeneralDockManager.overflowButton:IsShown() then return end
		share = GeneralDockManager.scrollFrame.dynTabSize
	end
	local name = tab:GetFontString()
	local padding = tab.sizePadding or 0
	local ends = tab.Left:GetWidth() + tab.Right:GetWidth()
	local most = share and math.max(share, ends)   -- Blizzard's own width for a shared tab
	local width = most
	if on or not share then
		local had = name:GetWidth()
		name:SetWidth(0)   -- unbounded, to measure the whole name
		local wide = name:GetStringWidth()
		if issecretvalue(wide) then
			name:SetWidth(had)   -- the measured width can be secret: leave Blizzard's
			return
		end
		width = math.max(wide + TAB_SIDES + padding, ends)
		if most then width = math.min(width, most) end
	end
	name:SetWidth(width - TAB_SIDES - padding)
	tab:SetWidth(width)
	return true
end

local function FitTabs()
	ChatFrameUtil.ForEachChatFrame(FitTab)
end

-- Blizzard's pass over the dock hands the shared tabs their share again. It can run every frame,
-- so a tab is measured only when its width isn't the one it was fitted to.
local fitted = setmetatable({}, { __mode = "k" })   -- shared tab -> its width after the last fit

local function Refit(frame)
	if not frame.isDocked or frame.isStaticDocked then return end
	local tab = _G[frame:GetName() .. "Tab"]
	if not tab then return end
	local width = tab:GetWidth()
	if issecretvalue(width) or width == fitted[tab] then return end
	fitted[tab] = nil
	if not FitTab(frame) then return end
	width = tab:GetWidth()
	if not issecretvalue(width) then fitted[tab] = width end
end

-- Restore Blizzard's tab colors (it only sets them when a tab changes).
local function ResetTab(tab)
	local c = tab.selectedColorTable or DEFAULT_TAB_SELECTED_COLOR_TABLE
	tab.HighlightMiddle:SetVertexColor(c.r, c.g, c.b)
	tab.glow:SetVertexColor(c.r, c.g, c.b)
	if tab.selectedColorTable then return end
	tab.ActiveMiddle:SetVertexColor(c.r, c.g, c.b)
	tab.ActiveLeft:SetVertexColor(c.r, c.g, c.b)
	tab:GetFontString():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
end

local function PaintFrame(frame, strength)
	local name = frame:GetName()
	local housed = strength > 0
	Empty(name)
	Empty(name .. "ButtonFrame")
	Watch(frame)
	Wing(frame)
	if housed then
		local housing = math.min(1, strength + 0.25)
		-- On the column itself, so it shows and hides with it.
		kit:Plate(frame.buttonFrame, { inset = WELL_INSET,
			fill = { UI.colors.bg[1], UI.colors.bg[2], UI.colors.bg[3], housing },
			border = { C.edge[1], C.edge[2], C.edge[3], housing } })
	end
	kit:Button(frame.buttonFrame.minimizeButton, C.metal, C.lit, C.hover)
	Glyph(frame.ScrollToBottomButton, ns.MEDIA .. "Bottom", 2, 1)
	-- Blizzard blinks this while there are newer lines below.
	kit:Art(frame.ScrollToBottomButton.Flash, ns.MEDIA .. "Bottom", { fit = frame.ScrollToBottomButton, x = 2, y = 1, color = C.hover })
	-- Our grip stands over Blizzard's corner wherever it can be dragged: the corner's art goes.
	if Movable() then
		if frame ~= DEFAULT_CHAT_FRAME then Float(frame) end
		for _, getter in ipairs(BUTTON_ART) do kit:Hide(frame.ResizeButton[getter](frame.ResizeButton)) end
	else
		Glyph(frame.ResizeButton, ns.MEDIA .. "Grip", 2, 2)
	end
	ScrollBar(frame.ScrollBar)
	PaintTab(_G[name .. "Tab"], housed, frame)
end

-- The edit box: on restyled windows its art is gone and it stands in the typing row, the row's light
-- in the channel's color; with default windows a flat box, bordered in the channel's color.

-- Start the typed text right after the header ("Say:", "[2. Trade]:") as Blizzard does, with
-- the header `pad` in from the left.
local function IndentText(editBox, pad)
	local width = editBox.header:GetWidth()
	if editBox.headerSuffix:IsShown() then width = width + editBox.headerSuffix:GetWidth() end
	if editBox.languageHeader:IsShown() then width = width + editBox.languageHeader:GetWidth() end
	editBox:SetTextInsets(pad + width, TEXT_RIGHT, 0, 0)
end

-- Post-hook on the edit box's UpdateHeader, which resets the text insets; the channel may have changed.
function L.EditHeader(editBox)
	if not editOn then return end
	IndentText(editBox, EDIT_PAD)
	if on then
		Tint(editBox.chatFrame)
	else
		editKit:Plate(editBox, { inset = EDIT_INSET, fill = UI.colors.bg, border = ChannelColor(editBox) })
	end
end

local function PaintEdit(editBox)
	local name = editBox:GetName()
	for _, suffix in ipairs(EDIT_ART) do editKit:Hide(_G[name .. suffix]) end
	local start = { "LEFT", editBox, "LEFT", EDIT_PAD, 0 }
	editKit:Place(editBox.header, nil, nil, start)
	editKit:Place(editBox.prompt, nil, nil, start)
	-- The chat style that keeps a closed box up shows a prompt (and a newcomer's hint) in it, under a
	-- panel whose row has closed: there is no row to stand in.
	if on then
		editKit:Hide(editBox.prompt)
		editKit:Hide(editBox.NewcomerHint)
	end
	L.EditHeader(editBox)
end

-- For ShyDock: Shy.wings.chat is how far the panel reaches outside ChatFrame1's rectangle,
-- { left, top, right, bottom } = BACKGROUND + the panel's inset (8, 26, 16, 6), or nil with default
-- windows. The bottom is the panel's whether the typing row is open or not: the window lifts from its
-- foot for the row, inside the panel. The button column's side isn't counted, and the reach is the same
-- whatever the Background setting.
local function Announce()
	local reach
	if on then
		local inset = Inset("")
		reach = {}
		for i = 1, 4 do reach[i] = BACKGROUND[i] - inset[i] end
	end
	local was = Shy.wings.chat
	local same = was == reach   -- both nil
	if was and reach then
		same = was[1] == reach[1] and was[2] == reach[2] and was[3] == reach[3] and was[4] == reach[4]
	end
	if same then return end
	Shy.wings.chat = reach
	Shy:Fire("SHY_WINGS")
end

-- Apply the settings to every chat window. Safe to call at any time, and again for new windows.
function L.Apply()
	local db = ns.T.db
	local was, wasEdit = on, editOn
	on, editOn = db.windowSkin, db.editSkin
	kit:Restore()
	editKit:Restore()
	ResetTabArt()
	wipe(wings)
	wipe(sided)
	for _, grab in pairs(grabs) do grab:Hide() end   -- shown again with each panel drawn
	ChatFrameUtil.ForEachChatFrame(function(frame)
		Yield(frame, nil)   -- and each edit box gives its corner up again with its panel
		if editOn then
			PaintEdit(frame.editBox)
		elseif wasEdit then
			IndentText(frame.editBox, BLIZZARD_PAD)
		end
	end)
	if on then
		if not hooked then
			hooked = true
			hooksecurefunc("FCFTab_UpdateColors", TabColors)
			hooksecurefunc("FCF_StartAlertFlash", Alerted)
			hooksecurefunc("FCF_StopAlertFlash", Alerted)
			-- Blizzard moves the button column to the other side when the window crosses the screen.
			hooksecurefunc("FCF_SetButtonSide", function(frame)
				if on and watched[frame] then Wing(frame) end
			end)
			-- An undocked window's tab is sized from a width cached under the previous font.
			hooksecurefunc("FCFDock_RemoveChatFrame", function(_, frame)
				if not on then return end
				FitTab(frame)
				-- Out of the dock it is no longer part of the piece: its strip drags nothing.
				if watched[frame] then Grab(frame, wings[frame]) end
			end)
			hooksecurefunc("FCFDock_UpdateTabs", function()
				if on then ChatFrameUtil.ForEachChatFrame(Refit) end
			end)
			-- A new name is measured even if the dock hands the tab the width it had.
			hooksecurefunc("FCF_SetWindowName", function(frame)
				local tab = _G[frame:GetName() .. "Tab"]
				if tab then fitted[tab] = nil end
			end)
			hooksecurefunc("FCFDockOverflowListButton_SetValue", OverflowRowColors)
		end
		ChatFrameUtil.ForEachChatFrame(function(frame) PaintFrame(frame, Shy.Theme.Strength()) end)
		kit:Button(ChatFrameMenuButton, C.metal, C.lit, C.hover)
		PaintOverflow()
	elseif was then
		ChatFrameUtil.ForEachChatFrame(function(frame) ResetTab(_G[frame:GetName() .. "Tab"]) end)
	end
	-- Each typing row as open as its box is now (closed with either restyle off).
	ChatFrameUtil.ForEachChatFrame(Settle)
	Lay()
	-- The tab font just changed.
	if on or was then FitTabs() end
	Announce()
end
