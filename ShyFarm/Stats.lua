-- Your favorites and what your farming of each came to. A favorite (T.db.favorites[item] = { goal, added }) is a
-- thing you farm again and again: the finder lists them with their stats and a graph, a click farms one again at the
-- goal you last farmed it to. Its stats come from your past sessions (this character's history) and the one going
-- on: how many sessions, how many looted, how many an hour on average and at best, the gold an hour those sessions
-- made, your odds from what you looted yourself, and what one is worth.

local ADDON, ns = ...
local T, S, P = ns.T, ns.Session, ns.Prices

local St = {}
ns.Stats = St

local K = {
	SERIES = 12,   -- sessions a graph shows, the latest last
	LEAST = 60,    -- seconds a session must have run to say an hour of it
}

function St.IsFavorite(item)
	return item ~= nil and T.db.favorites[item] ~= nil
end

-- Kept or let go; kept, it remembers the goal it is farmed to (the session's, if it is farmed now).
function St.Favorite(item, on)
	if not item then return end
	if on == nil then on = not St.IsFavorite(item) end
	if on then
		local s = S.Current()
		local goal = s and s.want and s.want.item == item and s.want.goal or nil
		T.db.favorites[item] = T.db.favorites[item] or { added = time(), goal = goal }
		P.Facts(item)
	else
		T.db.favorites[item] = nil
	end
	ns.Changed("favorite")
end

-- A favorite farmed to a goal remembers it for the next time.
function St.Farmed(item, goal)
	local fav = T.db.favorites[item]
	if fav and goal then fav.goal = goal end
end

-- What your farming of an item came to: { sessions, looted, hours, rate, best, gold, series, golds, live, odds,
-- oddsFrom, worth, from }. series and golds: an hour of it and gold an hour, a value a session (the latest last;
-- live: the last is the session going on).
function St.Of(item)
	local out = { sessions = 0, looted = 0, hours = 0, best = 0, series = {}, golds = {}, live = false }
	local seconds, value = 0, 0
	local function Take(n, secs, worth, live)
		if not n or n <= 0 or secs < K.LEAST then return end
		out.sessions, out.looted = out.sessions + 1, out.looted + n
		seconds, value = seconds + secs, value + worth
		local rate = n * 3600 / secs
		out.best = math.max(out.best, rate)
		out.series[#out.series + 1] = rate
		out.golds[#out.golds + 1] = worth * 3600 / secs
		out.live = live
	end
	local history = S.History() or {}
	for i = #history, 1, -1 do
		local kept = history[i]
		Take(kept.items and kept.items[item], kept.seconds or 0, kept.value or 0, false)
	end
	local s = S.Current()
	if s then Take(s.items[item], S.Seconds(s), S.Value(s), true) end
	while #out.series > K.SERIES do
		table.remove(out.series, 1)
		table.remove(out.golds, 1)
	end
	out.hours = seconds / 3600
	out.rate = seconds > 0 and out.looted * 3600 / seconds or nil
	out.gold = seconds > 0 and value * 3600 / seconds or nil
	local drops = S.Drops(item)[1]
	if drops then out.odds, out.oddsFrom = S.Odds(drops.drops, drops.corpses), drops.name end
	out.worth, out.from = P.Value(item)
	return out
end

-- Every favorite with its stats, by name.
function St.Favorites()
	local list = {}
	for item, fav in pairs(T.db.favorites) do
		list[#list + 1] = { item = item, goal = fav.goal, name = C_Item.GetItemNameByID(item), stats = St.Of(item) }
	end
	table.sort(list, function(a, b)
		if (a.name ~= nil) ~= (b.name ~= nil) then return a.name ~= nil end
		if a.name and a.name ~= b.name then return a.name < b.name end
		return a.item < b.item
	end)
	return list
end

-- A favorite's stats as a hover's rows (Shy.Hover's row form).
function St.Rows(item)
	local st = St.Of(item)
	local rows = {}
	local function Row(glyph, text, right) rows[#rows + 1] = { glyph = glyph, text = text, right = right } end
	if st.sessions == 0 then
		Row("clock", "Not farmed yet", "")
	else
		Row("clock", st.sessions == 1 and "1 session" or (st.sessions .. " sessions"), ("%.1f h"):format(st.hours))
		Row("bag", "Looted", tostring(st.looted))
		Row("up", "An hour, on average", ("%d"):format(math.floor(st.rate + 0.5)))
		Row("star", "Your best hour", ("%d"):format(math.floor(st.best + 0.5)))
		if st.gold then Row("coin", "Gold an hour, on average", P.Text(st.gold)) end
	end
	if st.odds then Row("kill", "From " .. (st.oddsFrom or "a creature"), st.odds) end
	if st.worth and st.worth > 0 then Row("coin", "One is worth", P.Text(st.worth) .. " " .. P.FROM[st.from]) end
	return rows
end

St.K = K
