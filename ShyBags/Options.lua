-- Settings: the window, the bag bar, what happens at a vendor, item tooltips and the marks on your items.

local ADDON, ns = ...
local T = ns.T

ns.RefreshOptions = Shy.Settings.Refresh

-- Everything at once, after Defaults. A setting changed alone says what it touches.
local function Apply()
	ns.BagBar.Apply()
	ns.Window.Apply()
	ns.Tile.Restyle()
	ns.Marks.Refresh()
end

-- Read as it is used: at a vendor, on a tooltip.
local function Kept() end

local function Marked()
	ns.Tile.Restyle()
	ns.Marks.Refresh()
end

local function Windowed() return T.db.window end
local function Selling() return T.db.sellJunk end
local function Repairing() return T.db.repair end

-- A mark tells its own name and sentence where it is made.
local function Mark(def)
	return { key = "marks." .. def.id, label = def.title, desc = def.desc, words = "mark slot corner icon",
		get = function() return ns.Marks.IsOn(def) end,
		default = function() return def.default ~= false end,
		apply = Marked }
end

local list = {
	apply = Apply,

	{ section = "Window" },
	{ key = "window", label = "One bag window", words = "default bags bank mailbox auctions characters alts",
		apply = function() ns.Window.Apply() end,
		desc = "Every bag you carry opens as one window, with your bank, mail, auctions and alts a click away. Off brings the game's own bags back." },
	{ label = "Fit bags automatically", sub = true, enabled = Windowed, words = "size shape columns wider taller",
		get = function() return ns.Window.AutoShape() end, set = function(v) ns.Window.SetAutoShape(v) end, default = true,
		desc = "The window sizes itself to your bags. Drag its bottom right corner to pick a shape yourself." },
	{ key = "apart", label = "Special bags apart", sub = true, enabled = Windowed,
		words = "herb quiver ammo soul enchanting reagent profession separate split own run",
		apply = function() ns.Window.Refresh() end,
		desc = "A herb bag, quiver, soul bag or reagent bag gets a run of slots of its own, under its name. Off, they sit in with the rest." },
	{ note = "On a gamepad you keep the default bags.", alert = true,
		shown = function() return T.db.window and ns.Takeover.Gamepad() end },
	{ note = "Your slots take the icon shape you pick under Theme." },

	{ section = "Bag bar" },
	{ key = "bagRow", label = "Bag slots", enabled = Windowed, words = "column key ring keyring quiver carried",
		apply = function() ns.Window.Refresh() end,
		desc = "A slot for each bag you carry and the key ring, beside your items. The bag button on the window's rail shows and hides them too." },
	{ key = "bar", label = "Default bag bar", default = "hidden", words = "bag buttons backpack hide restyle",
		items = {
			{ value = "hidden", text = "Hidden" },
			{ value = "restyled", text = "Restyled" },
			{ value = "plain", text = "Default" },
		},
		get = function()
			if T.db.bar then return "hidden" end
			return T.db.bagbar and "restyled" or "plain"
		end,
		set = function(v)
			T.db.bar = v == "hidden"
			if v ~= "hidden" then T.db.bagbar = v == "restyled" end
		end,
		apply = function() ns.BagBar.Apply() end,
		desc = "Hide the game's bag buttons, or restyle them to match your other icons. Your bags always open with the bag key." },

	{ section = "At a vendor" },
	{ key = "sellJunk", label = "Sell junk", words = "grey gray trash auto", apply = Kept,
		desc = "Your junk sells as you open a vendor. Hold Shift while you open one to keep it." },
	{ key = "sellReport", label = "Say the total", sub = true, enabled = Selling, apply = Kept,
		desc = "Chat says what it sold for." },
	{ key = "repair", label = "Repair gear", words = "auto durability armor", apply = Kept,
		desc = "Your gear is repaired as you open a vendor who can. Hold Shift while you open one to skip it." },
	{ key = "repairGuild", label = "Use guild funds", sub = true, enabled = Repairing, words = "guild bank gold", apply = Kept,
		desc = "The guild pays when your rank allows it. If not, you do." },
	{ key = "repairReport", label = "Say the cost", sub = true, enabled = Repairing, apply = Kept,
		desc = "Chat says what the repair cost." },

	{ section = "Item tooltips" },
	{ key = "tooltip", label = "Who else has it", words = "count alts bank mailbox auctions also have", apply = Kept,
		desc = "An item's tooltip says how many more are in your bank, mail and auctions, and on your alts." },

	{ section = "Item marks" },
}
for _, def in ipairs(ns.Marks.List()) do
	if def.title then list[#list + 1] = Mark(def) end
end

T:Settings(list)

-- A mark made later joins the others: they end the list.
function ns.TellMark(def)
	if def.title then T:Settings({ Mark(def) }) end
end

-- The default bags come and go with a gamepad: the note above follows.
ns.Takeover.OnSwitch(function() Shy.Settings.Refresh() end)
