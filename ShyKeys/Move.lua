-- ShyKeys: How you move: the hand's place on the keyboard
-- (Shy.Keys is written across this folder's files, in the order the TOC lists them.)

local ADDON, ns = ...

local Shy, UI = Shy, Shy.UI
local Keys = Shy.Keys
local DB = ns.DB
local HOT = ns.HOT

---------------------------------------------------------------------------
-- How you move: the hand's place on the keyboard
---------------------------------------------------------------------------

-- Two ways to move, and so two places the hand rests. WASD is the game's own: W forward, S back, the ring finger
-- on A, the middle on W and S, the index on D. ASDF: S forward, F back, the hand a key further right, pinky on A,
-- ring on S (forward), middle on D, index on F (back). Each names its four moving keys (no job stands on one)
-- and the keys under the hand with nothing held, easiest first (while one's own job isn't learned yet, a job you
-- can press that stands behind Shift or a reach comes up to it). With ASDF the ring finger holds S to run, so W
-- over it comes after the keys the middle, index and pinky reach while running. The second side button of the
-- mouse is none of them: a short hand can't reach it in a hurry, so nothing stands in there, and only what is
-- never hurried has it for a key. Nor is the number row: it stands apart from the hand, for what is slow.
Keys.SCHEMES = {
	wasd = { name = "WASD", forward = "W", back = "S", left = "A", right = "D", move = { W = true, A = true, S = true, D = true },
		prime = { "E", "Q", "R", "F", "BUTTON4", "T", "G", "C", "V", "X", "Z", "B" } },
	asdf = { name = "ASDF", forward = "S", back = "F", left = "A", right = "D", move = { A = true, S = true, D = true, F = true },
		prime = { "E", "R", "Q", "G", "BUTTON4", "T", "W", "V", "C", "X", "Z", "B" } },
}

-- The keyboard as the bars draw it: each key's own button, the bars a picture of the board (the main bar Q W E R
-- T, Mouse 4 and 5, then Shift + Q W E R T; the bottom left A S D F G, Shift + Mouse 4 and 5, Shift + A S D F G;
-- the bottom right Z X C V B, two with no key, Shift + Z X C V B). Those three bars are the hand's; the number
-- row stands apart, on the two side bars (the flyouts): 1 2 3 4 5 6 7 8 9 0 - = on the left one, and the same
-- with Shift on the right one, each read as a keyboard is whatever shape its bar has: the first key at the top
-- left, then across, then down (Button; here as on a bar of one line). A key that presses nothing is bound to
-- its own button there when a job needs it (and let go again when it is put back); a moving key never is.
local GRID, ROW = {}, {}     -- (ROW: a key of the number row -> its flyout's bar and its place in reading order)
do
	local n = 0
	for key in HOT.rows[1]:gmatch(".") do
		n = n + 1
		GRID[key], GRID["SHIFT-" .. key] = HOT.plain .. n, HOT.bar .. n
		ROW[key], ROW["SHIFT-" .. key] = { HOT.plain, n }, { HOT.bar, n }
	end
end

-- A flyout's buttons in the order they are read: the top left first, then across, then down. The game says how a
-- bar is laid (isHorizontal, numRows, numButtonsShowable): a bar across fills its rows from the bottom up, an
-- upright one its columns from the left, each downward (its "rows" are then its columns). Buttons the bar
-- doesn't show come after, in their own order.  -> { id = the shape, [n] = the bar's nth button as read }; one
-- table a shape
HOT.shapes, HOT.frames = {}, { MULTIACTIONBAR4BUTTON = "MultiBarLeft", MULTIACTIONBAR3BUTTON = "MultiBarRight" }
local function Shape(bar)
	bar = rawget(_G, HOT.frames[bar]) or HOT
	local across = bar.isHorizontal == true
	local lines = type(bar.numRows) == "number" and math.max(1, bar.numRows) or 1
	local shown = type(bar.numButtonsShowable) == "number" and math.min(NUM_ACTIONBAR_BUTTONS, bar.numButtonsShowable) or NUM_ACTIONBAR_BUTTONS
	local id = (across and "a" or "u") .. lines .. "/" .. shown
	local at = HOT.shapes[id]
	if at then return at end
	local stride = math.floor((shown + lines - 1) / lines)
	local columns, rows = across and stride or lines, across and lines or stride
	at = { id = id }
	local taken, n = {}, 0
	for row = 1, rows do
		for column = 1, columns do
			local button = across and (rows - row) * stride + column or (column - 1) * stride + row
			if button <= shown then
				n = n + 1
				at[n], taken[button] = button, true
			end
		end
	end
	for button = 1, NUM_ACTIONBAR_BUTTONS do
		if not taken[button] then
			n = n + 1
			at[n] = button
		end
	end
	HOT.shapes[id] = at
	return at
end
Keys.Shape = Shape

-- A key's own button: the grid's; a key of the number row's by its flyout's shape.
local function Button(key)
	local row = ROW[key]
	if not row then return GRID[key] end
	return row[1] .. Shape(row[1])[row[2]]
end
for i, key in ipairs({ "Q", "W", "E", "R", "T", "BUTTON4", "BUTTON5", "SHIFT-Q", "SHIFT-W", "SHIFT-E", "SHIFT-R", "SHIFT-T" }) do
	GRID[key] = "ACTIONBUTTON" .. i
end
for i, key in ipairs({ "A", "S", "D", "F", "G", "SHIFT-BUTTON4", "SHIFT-BUTTON5", "SHIFT-A", "SHIFT-S", "SHIFT-D", "SHIFT-F", "SHIFT-G" }) do
	GRID[key] = "MULTIACTIONBAR1BUTTON" .. i
end
for i, key in ipairs({ "Z", "X", "C", "V", "B", "", "", "SHIFT-Z", "SHIFT-X", "SHIFT-C", "SHIFT-V", "SHIFT-B" }) do
	if key ~= "" then GRID[key] = "MULTIACTIONBAR2BUTTON" .. i end
end
Keys.GRID = GRID

-- How you move: as picked (the core's keysMove), else as your keys say (S moving you forward is ASDF).
function Keys.Scheme()
	local picked = DB() and DB().keysMove
	if Keys.SCHEMES[picked] then return picked end
	for _, key in ipairs({ GetBindingKey("MOVEFORWARD") }) do
		if key == "S" then return "asdf" end
	end
	return "wasd"
end

local function Scheme() return Keys.SCHEMES[Keys.Scheme()] end

-- Whether a key is one you move with.
function Keys.Moving(key)
	return Scheme().move[key] == true
end

-- What the files after this one use.
ns.Button, ns.GRID, ns.Scheme, ns.Shape = Button, GRID, Scheme, Shape
