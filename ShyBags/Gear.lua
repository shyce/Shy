-- ShyGear's upgrade arrow in a slot's top left corner. Only live items of this character are judged.

local ADDON, ns = ...
local T = ns.T

local Gear = {}
ns.Gear = Gear

function Gear.Init()
	local gear = Shy.addons.Gear
	if not (gear and gear.Judge and gear.MarkFor and gear.Mark) then return end

	-- Once: carry over ShyGear's own bag setting.
	if not T.db.adoptedGear then
		T.db.adoptedGear = true
		if type(ShyGearDB) == "table" and ShyGearDB.bags == false then T.db.marks.upgrade = false end
	end

	T:RegisterMark({
		id = "upgrade", channel = "tl", title = "Upgrades",
		desc = "An arrow on gear better than what you have equipped, outlined if you need more levels to use it.",
		test = function(item)
			if not item.live then return nil end
			local link = C_Container.GetContainerItemLink(item.bag, item.slot)
			return link and gear:MarkFor(gear:Judge(link)) or nil
		end,
		make = function(tile) return gear:Mark(tile) end,
		show = function(mark, kind) mark:Set(kind) end,
	})

	-- ShyGear says when its verdicts may have changed: gear, level, stats, build, or something it waited
	-- on (an item's data, stats kept back in a fight) having come in. A slot painted before then is painted again.
	local due = false
	Shy:On("SHY_GEAR", function()
		if due then return end
		due = true
		C_Timer.After(0.2, function()
			due = false
			ns.Marks.Refresh()
		end)
	end)
end
