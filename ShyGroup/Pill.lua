-- The status box (a Shy.HUD box shown while the window is closed: run, group
-- size, missing roles, unread replies) and the minimap button.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI
local C = UI.colors
local METAL = Shy.Skin.colors.metal   -- a panel's resting edge color
local Run, People = ns.Run, ns.People
local Pl = {}
ns.Pill = Pl

local WIDTH, HEIGHT = 270, 46   -- width must match ShyQuest's card: they stack flush on ShyDock's deck
local box

-- Something to say: a run on, or replies waiting.
local function Wanted()
	if not T.db.pill or ns.char.open then return false end
	return Run.Get() ~= nil or People.Unread() > 0
end

-- Docked on a deck it is this box; anywhere else it is a notice in the ribbon at the screen's top (Notice).
local function Shown()
	return Wanted() and (box ~= nil and box.docked == true or Shy.Notices == nil)
end

function Pl.Init()
	box = Shy.HUD.Create({
		id = "shygroup-status",
		title = "ShyGroup status",
		width = WIDTH,
		height = HEIGHT,
		point = { "TOP", "TOP", 0, -96 },
		shown = Shown,
		-- In the column down from the top's middle, under the waypoint arrow, while no deck has it.
		top = { order = 35, passing = true },
		-- ShyDock's deck shows this as a switch: gold while a reply is unread,
		-- offered only while `wanted` is true.
		toggle = {
			label = "Group",
			tip = "Your run: group size, roles still needed and unread replies.",
			get = function() return T.db.pill end,
			set = function(on)
				T.db.pill = on
				T:Apply()
			end,
			alert = function() return People.Unread() > 0 end,
			wanted = function() return Run.Get() ~= nil or People.Unread() > 0 end,
		},
		-- Docked in a column, the box takes the column's width.
		fit = function(self, w) self:SetWidth(w) end,
		-- On the deck the column draws the panel, so the box hides its own.
		docked = function(self, on)
			self.shyBg:SetShown(not on)
			self.shyEdge:SetShown(not on)
			self.shyLine:SetShown(not on)
			for _, bracket in ipairs(self.shyBrackets) do bracket:SetShown(not on) end
			-- (Docked it is this box; let go of, the notice again.)
			if Pl.Refresh then Pl.Refresh() end
		end,
	})
	-- Small brackets: full-size ones crowd a box this short.
	UI.Panel(box, { brackets = 10, hud = true })
	-- Keeps watch with the group while the HUD is faded; a reply lights it (People.lua).
	local immersion = Shy.Immersion
	if immersion and immersion.Watch then immersion.Watch("group", box) end

	local title = UI.Text(box, "", 15, true)
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetWidth(WIDTH - 62)
	title:SetWordWrap(false)
	local count = UI.Text(box, "", 15, true, C.hot)
	count:SetPoint("TOPRIGHT", -10, -8)
	local detail = UI.Text(box, "", 12, false, C.dim)
	detail:SetPoint("BOTTOMLEFT", 10, 8)

	local badge = CreateFrame("Frame", nil, box)
	badge:SetHeight(18)
	badge:SetPoint("BOTTOMRIGHT", -8, 6)
	badge.bg = badge:CreateTexture(nil, "BACKGROUND")
	badge.bg:SetAllPoints()
	UI.Paint(badge.bg, C.alert)   -- gold, not the accent
	badge.text = UI.Text(badge, "", 11, true, C.onAlert)
	badge.text:SetShadowColor(0, 0, 0, 0)   -- no shadow under dark text on gold
	badge.text:SetPoint("CENTER")

	-- Always from a click: the Group Finder can be asked on the way in.
	local function Open()
		ns.Window.SetOpen(true, People.Unread() > 0 and ns.Window.REPLIES or ns.Window.RUN, true)
	end
	box:EnableMouse(true)
	box:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and not Shy.HUD.WasDragged(box) then Open() end
	end)
	Shy.HUD.Manage(box, box, function(root)
		root:CreateButton("Open ShyGroup", Open)
	end)
	box:SetScript("OnEnter", function(self)
		UI.SetBorder(self, C.hot)
		UI.Tip(self, "ShyGroup", nil, { hints = { { "left", "Open" }, { "left", "Drag" }, { "right", "More" } } })
	end)
	box:SetScript("OnLeave", function(self)
		UI.SetBorder(self, METAL)
		UI.TipHide(self)
	end)

	-- Minimap button
	local function ButtonMenu(owner)
		Shy.UI.ContextMenu(owner, function(root)
			root:CreateTitle(B.Name(T.suffix))
			if ns.char.open then
				root:CreateButton("Close window", function() ns.Window.SetOpen(false) end)
			else
				root:CreateButton("Open window", Open)
			end
			if Run.Get() then
				root:CreateButton("Finish the run", function() Run.Stop() end)
			end
			root:CreateButton("Settings", function() T:OpenOptions() end)
			if ns.Listing.Available() then
				root:CreateButton("Who list", function() ns.Listing.OpenWho() end)
				root:CreateButton("Default Group Finder", function() ns.Listing.OpenBlizzard() end)
			end
		end)
	end

	local button = Shy.MinimapButton({
		name = "ShyGroupMinimapButton",
		addon = T,
		icon = T.smallIcon,
		glyph = "Interface\\AddOns\\ShyGroup\\Media\\ShyGroupGlyph",
		stay = true,   -- quick access: never folded into the core's button
		getAngle = function() return T.db.minimapAngle end,
		setAngle = function(v) T.db.minimapAngle = v end,
		onClick = function(self, mouseButton)
			if mouseButton == "RightButton" then
				ButtonMenu(self)
			elseif ns.char.open then
				ns.Window.SetOpen(false)
			else
				Open()
			end
		end,
		onEnter = function(self)
			local run, rows, text = Run.Get(), {}, nil
			if run then
				rows[#rows + 1] = { glyph = "star", text = run.name, right = Run.Count() .. "/" .. run.size, rightColor = C.hot }
				local need = Run.NeedText()
				if Run.IsFull() then
					rows[#rows + 1] = { text = "Group is full", color = C.good, indent = 1 }
				else
					rows[#rows + 1] = { text = need and ("Need " .. need) or "Recruiting", quiet = true, indent = 1 }
				end
				if ns.Listing.State() == "run" then
					rows[#rows + 1] = { text = "Listed in the Group Finder", color = C.good, indent = 1 }
				end
			else
				text = "No run yet. Click to pick a dungeon, raid or zone."
			end
			local unread = People.Unread()
			if unread > 0 then
				rows[#rows + 1] = { glyph = "talk", tint = C.alert, text = unread == 1 and "1 reply waiting" or (unread .. " replies waiting"), color = C.alert }
			end
			local hints = { { "left", ns.char.open and "Close" or "Open" }, { "right", "More" } }
			if Shy.MinimapShape() == "ROUND" then hints[3] = { "left", "Drag" } end
			UI.Tip(self, "ShyGroup", text, { side = self:TipSide(), hints = hints, sections = #rows > 0 and { { rows = rows } } or nil })
		end,
		onLeave = function(self) UI.TipHide(self) end,
	})

	-- The run as a notice: the people sign and how many of how many, gold while a reply waits; the run,
	-- what it still needs and the replies in its hover.
	local function Notice()
		local N = Shy.Notices
		if not N then return end
		if not Wanted() or box.docked then
			N.Clear("group")
			return
		end
		local run, unread = Run.Get(), People.Unread()
		local note
		if run then
			local need = Run.NeedText()
			note = Run.IsFull() and "Group is full" or (need and ("Need " .. need) or "Recruiting")
		end
		if unread > 0 then
			local replies = unread == 1 and "1 reply waiting" or (unread .. " replies waiting")
			note = note and (note .. ". " .. replies) or replies
		end
		N.Post("group", {
			order = 30, icon = Shy.MEDIA .. "GlyphPeople", color = unread > 0 and C.alert or C.good,
			text = run and (Run.Count() .. "/" .. run.size) or tostring(unread),
			title = run and run.name or "ShyGroup",
			says = "Click opens ShyGroup. Right-click for more.",
			note = note,
			click = Open,
			menu = function(root)
				root:CreateButton("Open ShyGroup", Open)
				if run then root:CreateButton("Finish the run", function() Run.Stop() end) end
			end,
		})
	end

	local function Refresh()
		button:Place()
		button:SetShown(T.db.minimap)
		button:SetBadge(People.Unread())

		Notice()
		Shy.HUD.Update(box)
		if not box:IsShown() then return end
		local run = Run.Get()
		if run then
			title:SetText(run.name)
			count:SetText(Run.Count() .. "/" .. run.size)
			local need = Run.NeedText()
			if Run.IsFull() then
				detail:SetText("Group is full")
				UI.Ink(detail, C.good)
			else
				detail:SetText(need and ("Need " .. need) or "Recruiting")
				UI.Ink(detail, C.dim)
			end
		else
			title:SetText("ShyGroup")
			count:SetText("")
			detail:SetText("")
		end
		local unread = People.Unread()
		badge:SetShown(unread > 0)
		badge.text:SetText(unread == 1 and "1 reply" or (unread .. " replies"))
		badge:SetWidth(badge.text:GetStringWidth() + 14)
	end

	ns.OnChange(Refresh)
	Shy:On("SHY_HUD_LAYOUT", Refresh)
	Pl.Refresh = Refresh
end
