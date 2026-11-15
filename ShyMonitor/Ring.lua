-- A ring of numbers of a fixed size, made once: the last n samples of something, oldest to newest.
--   ns.Ring.New(n) -> ring
--   ring:Push(v)         the newest, over the oldest once full
--   ring:Get(i)          1 is the oldest kept, ring.count the newest; nil past them
--   ring:Last()          the newest, or nil
--   ring:Max()           the largest kept (0 when empty)
--   ring:Clear()

local _, ns = ...
local Ring = {}
Ring.__index = Ring
ns.Ring = Ring

function Ring.New(n)
	local ring = setmetatable({ n = n, at = 0, count = 0 }, Ring)
	for i = 1, n do ring[i] = 0 end
	return ring
end

function Ring:Push(v)
	local at = self.at % self.n + 1
	self[at] = v
	self.at = at
	if self.count < self.n then self.count = self.count + 1 end
end

function Ring:Get(i)
	if i < 1 or i > self.count then return nil end
	return self[(self.at - self.count + i - 1) % self.n + 1]
end

function Ring:Last()
	if self.count == 0 then return nil end
	return self[self.at]
end

function Ring:Max()
	local most = 0
	for i = 1, self.count do
		local v = self:Get(i)
		if v > most then most = v end
	end
	return most
end

function Ring:Clear()
	self.at, self.count = 0, 0
end
