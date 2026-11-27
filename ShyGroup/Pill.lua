-- Your run at the top of the screen and the minimap button. The run (its name, group size, missing roles) and
-- the replies waiting are rows of ShyCore's group piece (Shy.Party), in the drawer under the head with the
-- routes your friends suggest; a deck shows that piece under its "Group" tab.

local ADDON, ns = ...
local T = ns.T
local B, UI = Shy.Brand, Shy.UI
local C = UI.colors
local Run, People = ns.Run, ns.People
local Pl = {}
ns.Pill = Pl

-- Something to say: a run on, or replies waiting.
local function Wanted()
	if not T.db.pill or ns.char.open then return false end
	return Run.Get() ~= nil or People.Unread() > 0
end

function Pl.Init()
	-- (Without ShyCore's group piece there is nothing at the top to say it in; the minimap button stays.)
	local Party = Shy.Party or { Setting = function() end, Toggle = function() end, Run = function() end }
	Party.Setting("run", {
		label = "Your run", hint = "Your run, group size and replies waiting.",
		get = function() return T.db.pill end,
		set = function(on)
			T.db.pill = on
			T:Apply()
		end,
	})
	-- ShyDock's deck shows the piece as a switch: gold while a reply is unread, offered only while there is a run
	-- or a reply.
	Party.Toggle({
		label = "Group",
		tip = "Your run: group size, roles still needed and unread replies.",
		get = function() return T.db.pill end,
		set = function(on)
			T.db.pill = on
			T:Apply()
		end,
		alert = function() return People.Unread() > 0 end,
		wanted = function() return Run.Get() ~= nil or People.Unread() > 0 end,
	})

	-- Always from a click: the Group Finder can be asked on the way in.
	local function Open()
		ns.Window.SetOpen(true, People.Unread() > 0 and ns.Window.REPLIES or ns.Window.RUN, true)
	end
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

	-- The run as rows of the group piece: its name, what it still needs and how many of how many; the replies
	-- waiting under it.
	local function Say()
		if not Wanted() then
			Party.Run(nil)
			return
		end
		local run = Run.Get()
		Party.Run({
			name = run and run.name or nil, count = run and Run.Count() or nil, size = run and run.size or nil,
			need = run and (Run.NeedText() and ("Need " .. Run.NeedText()) or "Recruiting") or nil,
			full = run ~= nil and Run.IsFull(), unread = People.Unread(),
			open = function(replies)
				ns.Window.SetOpen(true, (replies or not run) and ns.Window.REPLIES or ns.Window.RUN, true)
			end,
			menu = function(root)
				root:CreateButton("Open ShyGroup", Open)
				if Run.Get() then root:CreateButton("Finish the run", function() Run.Stop() end) end
			end,
		})
	end

	local function Refresh()
		button:Place()
		button:SetShown(T.db.minimap)
		button:SetBadge(People.Unread())
		Say()
	end

	ns.OnChange(Refresh)
	Pl.Refresh = Refresh
end
