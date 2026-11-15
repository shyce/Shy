-- What the client's tables don't say about a tick. Each entry names its reason.

local _, ns = ...

-- Ticks that aren't all the same size, as a share of the average, first to last. The tables give one base
-- a tick; the ramp is the server's rule for the spell. Bane of Agony (every rank) ticks at half, then once,
-- then one and a half times its average: 12 ticks over 24 seconds.
local AGONY = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
ns.ramps = {
	[980] = AGONY, [1014] = AGONY, [6217] = AGONY, [11711] = AGONY, [11712] = AGONY, [11713] = AGONY,
}
