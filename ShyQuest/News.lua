-- What's new in a release, told once as you log in (Shy.News: ShyCore). Each item is its release's alone: a title
-- and a line or two, and the switches this character turned off that go with it, to turn back on in one click.

local ADDON, ns = ...
local T, R = ns.T, ns.Route

if not (Shy.News and Shy.News.Add) then return end

-- An errand for the list, when this character has it off either way: put away from its row (R.Hush), or its
-- switch in the card's menu off. One line for both, named as its switch is; turned on, both come back.
local function Errand(out, id, db, key, text)
	local hushed, off = R.Hushed(id), db ~= nil and db[key] == false
	if not (hushed or off) then return end
	out[#out + 1] = { text = text, on = function()
		if hushed then R.Hush(id, false) end
		if off then
			db[key] = true
			ns.Apply()
		end
	end }
end

Shy.News.Add({
	id = "shyquest-5.2.6", release = "5.2.6", addon = ADDON,
	title = "Your quest card", icon = ns.MEDIA .. "ShyQuestMark",
	lines = {
		"Class quests have a row of their own. It says what you'll learn and picks the giver that fits your road.",
		"Your hearthstone, flight paths and bank trips lead again when they save time.",
		"In town you're told to top up water when you're under half a stack.",
	},
	off = function()
		local out = {}
		if not ns.char then return out end
		local db = T.db
		Errand(out, "classquest", db.classQuests, "on", "Your class quests")
		Errand(out, "hearth", db.hearth, "on", "Hearth when it saves time")
		Errand(out, "sethome", nil, nil, R.ErrandName("sethome") or "Setting your home inn")
		Errand(out, "flightpath", db.flights, "on", "Flight paths along the way")
		Errand(out, "bank", db.stash, "take", "Fetch quest items from bank and mailbox")
		Errand(out, "mailbox", nil, nil, R.ErrandName("mailbox") or "Quest items in your mailbox")
		Errand(out, "supplies", db.supplies, "on", "Restock when food, water or reagents run low")
		return out
	end,
})
