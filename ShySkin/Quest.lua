-- The quest giver's windows: while this is on, quest text that isn't immersive stands in a window of the family's
-- (Shy.Talk's window, ShyCore/Talk.lua) in place of the game's quest and gossip windows: the speaker's face and what
-- the page is about in a band under the header, the words lit as the voice says them, the suggested reward, the
-- buttons in a foot, and a window that flows to any size. Off, the game's own windows are back.

local ADDON, ns = ...

local function Wear(on)
	if Shy.Talk and Shy.Talk.Window then Shy.Talk.Window(on) end
end

ns.Module({
	id = "questwindow",
	title = "Quest and gossip windows",
	desc = "Shows quest givers and other NPCs in a window of your theme you can size, with voices, suggested rewards and your guide's notes.",

	Paint = function() Wear(true) end,

	Clear = function(m)
		if not m.on then Wear(false) end
	end,
})
