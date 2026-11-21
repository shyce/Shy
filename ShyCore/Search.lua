-- Shy.Search: short texts found as you type. Several words in any order. A word is found whole, by how it
-- begins, inside a longer word, or a letter or two off. Nothing here draws.
--
--   local index = Shy.Search.New()
--   index:Add(id, { { text, weight }, ... })   a thing to find and its plain texts. A heavier text ranks higher
--   index:Find(query) -> ids, n                the best first. The list is the index's own: read it before the next Find
--   index:Score(id)                            how well the last Find fits it, or nil
--   index:Ranges(id, field, out, whole) -> out where the last Find's words stand in that text: from, to, from, to.
--                                              whole: each found word from its first letter to its last, never a
--                                              part of one, and never two as one
--   index:Size()                               how many things it holds
--   Shy.Search.Mark(text, ranges, open, close) the text with each range between `open` and `close`
--   Shy.Search.Cut(text, ranges, most, out)    -> text, out: about `most` letters round the first range
local Shy = Shy
local find, byte, sub, lower, gmatch = string.find, string.byte, string.sub, string.lower, string.gmatch
local concat, sort = table.concat, table.sort

local Search = {}
Shy.Search = Search

-- How good each kind of find is, of 1. NEAR: a letter off, less again for each letter more.
-- FIRST: a text's first word found counts for more. MEMO: typed words whose finds are kept.
local RANK = { WHOLE = 1, BEGINS = 0.82, LONGER = 0.1, INSIDE = 0.5, NEAR = 0.42, OFF = 0.12, FIRST = 1.15, MEMO = 48 }
local WORD = "()([%w\128-\255]+)()"
local DOTS = "\226\128\166"
local BIG = 99

-- How many letters off a typed word may be, by its length.
local function Slack(n)
	return n >= 8 and 2 or n >= 4 and 1 or 0
end

-- How far the typed letters are from the beginning of a word: letters changed, added, dropped or swapped.
-- Only `most` off or nearer counts. Returns how far, and how much of the word they covered.
local rowA, rowB, rowC = {}, {}, {}
local function Near(qb, n, wb, lw, most)
	local m = lw < n + most and lw or n + most
	local prev2, prev, cur = rowA, rowB, rowC
	for j = 0, m do prev[j] = j <= most and j or BIG end
	for i = 1, n do
		local lo = i - most
		if lo < 1 then lo = 1 end
		local hi = i + most
		if hi > m then hi = m end
		local least = (lo == 1 and i <= most) and i or BIG
		cur[lo - 1] = least
		local qi = qb[i]
		for j = lo, hi do
			local wj = wb[j]
			local d = prev[j - 1] + (qi == wj and 0 or 1)
			local over = prev[j] + 1
			if over < d then d = over end
			local back = cur[j - 1] + 1
			if back < d then d = back end
			if i > 1 and j > 1 and qi == wb[j - 1] and qb[i - 1] == wj then
				local swap = prev2[j - 2] + 1
				if swap < d then d = swap end
			end
			cur[j] = d
			if d < least then least = d end
		end
		if hi < m then cur[hi + 1] = BIG end
		if least > most then return nil end
		prev2, prev, cur = prev, cur, prev2
	end
	local best, upto = BIG, 0
	local lo = n - most
	if lo < 1 then lo = 1 end
	local hi = n + most
	if hi > m then hi = m end
	for j = lo, hi do
		local d = prev[j]
		if d < best or (d == best and j == lw) then best, upto = d, j end
	end
	if best > most then return nil end
	return best, upto
end

local Index = {}
Index.__index = Index

function Search.New()
	return setmetatable({
		ids = {}, at = {}, fields = {},          -- by number: its id; by id: its number; its texts
		words = {}, list = {}, post = {}, bytes = {},   -- a word's number, the words, where each stands, its letters
		memo = {}, memoed = 0,                   -- a typed word's finds
		sets = {}, hits = {}, score = {}, found = {}, n = 0,
	}, Index)
end

function Index:Size() return #self.ids end

function Index:Add(id, texts)
	local doc = #self.ids + 1
	self.ids[doc], self.at[id] = id, doc
	local fields = {}
	self.fields[doc] = fields
	for f, entry in ipairs(texts) do
		local text, weight = entry[1] or "", entry[2] or 1
		local toks = {}
		for from, word, to in gmatch(lower(text), WORD) do
			local w = self.words[word]
			if not w then
				w = #self.list + 1
				self.list[w], self.words[word], self.post[w] = word, w, {}
			end
			local post = self.post[w]
			local at = #post
			post[at + 1], post[at + 2], post[at + 3] = doc, f, #toks == 0 and 1 or 0
			local t = #toks
			toks[t + 1], toks[t + 2], toks[t + 3] = w, from, to - 1
		end
		fields[f] = { text = text, weight = weight, toks = toks }
	end
	-- (What was found before no longer holds.)
	if self.memoed > 0 then
		self.memo, self.memoed = {}, 0
	end
end

local function Bytes(self, w)
	local b = self.bytes[w]
	if not b then
		b = { byte(self.list[w], 1, -1) }
		self.bytes[w] = b
	end
	return b
end

-- Every word a typed word finds: how good the find is, and which of the word's letters it covers.
local function Matches(self, q)
	local set = self.memo[q]
	if set then return set end
	set = { q = {}, at = {}, len = {} }
	local n, most = #q, Slack(#q)
	local direct = false
	for w, word in ipairs(self.list) do
		local s = find(word, q, 1, true)
		if s == 1 then
			local lw = #word
			set.q[w] = lw == n and RANK.WHOLE or (RANK.BEGINS + RANK.LONGER * n / lw)
			set.at[w], set.len[w] = 0, n
			direct = true
		elseif s and n >= 3 then
			set.q[w], set.at[w], set.len[w] = RANK.INSIDE, s - 1, n
			direct = true
		end
	end
	-- Near words only where the typed one stands nowhere as it is: a typo, not a word begun.
	if not direct and most > 0 then
		local qb = { byte(q, 1, -1) }
		for w, word in ipairs(self.list) do
			local lw = #word
			if lw >= n - most then
				local off, upto = Near(qb, n, Bytes(self, w), lw, most)
				if off then
					set.q[w], set.at[w], set.len[w] = RANK.NEAR - RANK.OFF * (off - 1), 0, upto
				end
			end
		end
	end
	if self.memoed >= RANK.MEMO then
		self.memo, self.memoed = {}, 0
	end
	self.memo[q], self.memoed = set, self.memoed + 1
	return set
end

-- The best first; ties in the order they were added.
local scoring
local function Better(a, b)
	local sa, sb = scoring[a], scoring[b]
	if sa ~= sb then return sa > sb end
	return a < b
end

function Index:Find(query)
	local sets, hits, score, found = self.sets, self.hits, self.score, self.found
	for i = #sets, 1, -1 do sets[i] = nil end
	for doc in pairs(score) do score[doc] = nil end
	for doc in pairs(found) do found[doc] = nil end
	local seen = self.seen or {}
	self.seen = seen
	for word in pairs(seen) do seen[word] = nil end
	for _, word in gmatch(lower(query or ""), WORD) do
		if not seen[word] then
			seen[word] = true
			sets[#sets + 1] = Matches(self, word)
		end
	end
	local want = #sets
	local best = self.best or {}
	self.best = best
	local most = 0
	for t = 1, want do
		for doc in pairs(best) do best[doc] = nil end
		for w, q in pairs(sets[t].q) do
			local post = self.post[w]
			for i = 1, #post, 3 do
				local doc = post[i]
				local s = q * self.fields[doc][post[i + 1]].weight
				if post[i + 2] == 1 then s = s * RANK.FIRST end
				if s > (best[doc] or 0) then best[doc] = s end
			end
		end
		for doc, s in pairs(best) do
			score[doc] = (score[doc] or 0) + s
			local count = (found[doc] or 0) + 1
			found[doc] = count
			if count > most then most = count end
		end
	end
	-- Every word found, or with none like that, as many of them as any text has.
	local n = 0
	for doc, count in pairs(found) do
		if count == most then
			n = n + 1
			hits[n] = doc
		else
			score[doc] = nil
		end
	end
	for i = #hits, n + 1, -1 do hits[i] = nil end
	scoring = score
	sort(hits, Better)
	for i = 1, n do hits[i] = self.ids[hits[i]] end
	self.n = n
	return hits, n
end

function Index:Score(id)
	local doc = self.at[id]
	return doc and self.score[doc] or nil
end

-- A range never ends inside a letter of several bytes.
local function Whole(text, to)
	local nxt = byte(text, to + 1)
	while nxt and nxt >= 128 and nxt < 192 do
		to = to + 1
		nxt = byte(text, to + 1)
	end
	return to
end

function Index:Ranges(id, field, out, whole)
	out = out or {}
	for i = #out, 1, -1 do out[i] = nil end
	local doc = self.at[id]
	local entry = doc and self.fields[doc][field]
	if not entry then return out end
	local toks, sets, n = entry.toks, self.sets, 0
	for i = 1, #toks, 3 do
		local w, from, to = toks[i], toks[i + 1], toks[i + 2]
		local a, b
		for t = 1, #sets do
			local set = sets[t]
			if set.q[w] then
				local s = from + set.at[w]
				local e = s + set.len[w] - 1
				if e > to then e = to end
				if not a or s < a then a = s end
				if not b or e > b then b = e end
			end
		end
		if a and whole then
			out[n + 1], out[n + 2] = from, to
			n = n + 2
		elseif a then
			b = Whole(entry.text, b)
			-- (Words side by side read as one light.)
			if n > 0 and a <= out[n] + 2 then
				if b > out[n] then out[n] = b end
			else
				out[n + 1], out[n + 2] = a, b
				n = n + 2
			end
		end
	end
	return out
end

local parts = {}
function Search.Mark(text, ranges, open, close)
	if not ranges or #ranges == 0 then return text end
	local n, at = 0, 1
	for i = 1, #ranges, 2 do
		local from, to = ranges[i], ranges[i + 1]
		parts[n + 1], parts[n + 2], parts[n + 3], parts[n + 4] = sub(text, at, from - 1), open, sub(text, from, to), close
		n, at = n + 4, to + 1
	end
	parts[n + 1] = sub(text, at)
	n = n + 1
	local marked = concat(parts, "", 1, n)
	for i = n, 1, -1 do parts[i] = nil end
	return marked
end

-- A long text cut to the stretch round what was found, at whole words, with dots where it was cut.
function Search.Cut(text, ranges, most, out)
	out = out or {}
	for i = #out, 1, -1 do out[i] = nil end
	local long = #text
	if not ranges or #ranges == 0 or long <= most or ranges[2] <= most then
		for i = 1, ranges and #ranges or 0 do out[i] = ranges[i] end
		return text, out
	end
	local from = ranges[1] - math.floor(most / 3)
	if from < 1 then from = 1 end
	local space = find(text, " ", from, true)
	if from > 1 and space and space < ranges[1] then from = space + 1 end
	local to = from + most - 1
	if to >= long then
		to = long
	else
		local cut = to
		while cut > ranges[2] and byte(text, cut) ~= 32 do cut = cut - 1 end
		to = cut > ranges[2] and cut - 1 or Whole(text, to)
	end
	local head = from > 1 and DOTS or ""
	local shift = #head - (from - 1)
	local n = 0
	for i = 1, #ranges, 2 do
		local a, b = ranges[i], ranges[i + 1]
		if a >= from and b <= to then
			out[n + 1], out[n + 2] = a + shift, b + shift
			n = n + 2
		end
	end
	return head .. sub(text, from, to) .. (to < long and DOTS or ""), out
end
