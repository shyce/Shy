-- The party-sync wire format of the other quest addon (its addon message prefix, Wire.PREFIX; message
-- version 5), so groups share quest progress with either addon. Format only; Party.lua decides what is sent.
--
-- A message is one Lua table, packed as the value of key 1 of a one-entry outer table.
-- Each object starts with a type byte:
--      32..253   the integer (byte - 32): 0 to 221
--      12, 13    one byte follows: an integer under 255 (13 negative)
--      14, 15    two bytes, big-endian: under 65530 (15 negative)
--      2, 3      four bytes (3 negative)        4, 5   eight bytes (5 negative)
--      6         four bytes: an IEEE single
--      7, 8      a string: one (7) or two (8) length bytes, then its bytes
--      9         four bytes: the hash of a string seen earlier in this message (read, never written)
--      10, 11    a keyed table: a count (one byte, two for 11), then key, value pairs
--      20,21,22  a list: a count (one, two or four bytes), then the values
--      16, 17    false, true        1, 18, 19   nil
-- A message can't contain a zero byte: 0 is written as 238, 237 as 237 1, 238 as 237 2.
--
-- An addon message is 255 bytes at most. That addon's messaging library splits longer ones into parts with a first byte of
-- 1 (first), 2 (more) or 3 (last), and prefixes a whole message that starts with such a byte with 4.
-- What is sent here always fits one part and begins with "!", so it needs no mark.

local ADDON, ns = ...

local Wire = {}
ns.Wire = Wire

Wire.PREFIX = "questie"
Wire.VERSION = 5             -- the message version: readers take any 5.x
Wire.LONGEST = 255           -- bytes in one addon message

local CONTROL, ZERO = 237, 238
local char, byte, floor = string.char, string.byte, math.floor

-- Writing

local function PutByte(out, value)
	if value == 0 then
		out[#out + 1] = char(ZERO)
	elseif value == CONTROL then
		out[#out + 1] = char(CONTROL, 1)
	elseif value == ZERO then
		out[#out + 1] = char(CONTROL, 2)
	else
		out[#out + 1] = char(value)
	end
end

local function PutBytes(out, value, count)
	for i = count - 1, 0, -1 do PutByte(out, floor(value / 256 ^ i) % 256) end
end

local Put

local function PutNumber(out, value)
	assert(value == floor(value), "only whole numbers are sent")
	local sign = 0
	if value < 0 then value, sign = -value, 1 end
	if value > 2147483646 then
		PutByte(out, 4 + sign)
		PutBytes(out, value, 8)
	elseif value < 222 and sign == 0 then
		PutByte(out, 32 + value)
	elseif value < 255 then
		PutByte(out, 12 + sign)
		PutByte(out, value)
	elseif value < 65530 then
		PutByte(out, 14 + sign)
		PutBytes(out, value, 2)
	else
		PutByte(out, 2 + sign)
		PutBytes(out, value, 4)
	end
end

local function PutString(out, value)
	if #value > 254 then
		PutByte(out, 8)
		PutBytes(out, #value, 2)
	else
		PutByte(out, 7)
		PutByte(out, #value)
	end
	for i = 1, #value do PutByte(out, byte(value, i)) end
end

-- A table's keys in a stable order: numbers, then strings.
local function Keys(value)
	local keys = {}
	for key, v in pairs(value) do
		if v then keys[#keys + 1] = key end      -- false values are omitted, as the format does
	end
	table.sort(keys, function(a, b)
		if type(a) ~= type(b) then return type(a) == "number" end
		return a < b
	end)
	return keys
end

local function PutTable(out, value)
	local keys = Keys(value)
	local list = #keys == #value
	for i, key in ipairs(keys) do
		if key ~= i then list = false end
	end
	if list then
		if #keys > 254 then
			PutByte(out, 21)
			PutBytes(out, #keys, 2)
		else
			PutByte(out, 20)
			PutByte(out, #keys)
		end
		for _, key in ipairs(keys) do Put(out, value[key]) end
	else
		if #keys > 254 then
			PutByte(out, 11)
			PutBytes(out, #keys, 2)
		else
			PutByte(out, 10)
			PutByte(out, #keys)
		end
		for _, key in ipairs(keys) do
			Put(out, key)
			Put(out, value[key])
		end
	end
end

function Put(out, value)
	local kind = type(value)
	if kind == "number" then
		PutNumber(out, value)
	elseif kind == "string" then
		PutString(out, value)
	elseif kind == "table" then
		PutTable(out, value)
	elseif kind == "boolean" then
		PutByte(out, value and 17 or 16)
	else
		error("can't be sent: " .. kind)
	end
end

-- A table as the bytes of one message.
function Wire.Encode(packet)
	local out = {}
	PutNumber(out, 1)
	PutTable(out, packet)
	return table.concat(out)
end

-- Reading

local function Hash(text)
	local h = 5381
	for i = 1, #text do h = (31 * h + byte(text, i)) % 4294967296 end
	return h
end
Wire.Hash = Hash

local function GetByte(read)
	local value = byte(read.text, read.at)
	read.at = read.at + 1
	if value == ZERO then return 0 end
	if value == CONTROL then
		local which = byte(read.text, read.at)
		read.at = read.at + 1
		return which == 1 and CONTROL or ZERO
	end
	return value       -- nil past the end: the caller's arithmetic errors and Decode's pcall catches it
end

local function GetBytes(read, count)
	local value = 0
	for _ = 1, count do value = value * 256 + GetByte(read) end
	return value
end

local function GetString(read, length)
	local bytes = {}
	for i = 1, length do bytes[i] = char(GetByte(read)) end
	return table.concat(bytes)
end

local function Remember(read, value)
	if type(value) == "string" then
		local hash = Hash(value)
		if not read.seen[hash] then read.seen[hash] = value end
	end
	return value
end

-- An IEEE single from its 32 bits.
local function Single(bits)
	local sign = bits >= 2147483648 and -1 or 1
	local expo = floor(bits / 8388608) % 256
	local mant = bits % 8388608
	if expo == 0 and mant == 0 then return 0 end
	if expo == 255 then return mant == 0 and sign * math.huge or 0 end
	return sign * (1 + mant / 8388608) * 2 ^ (expo - 127)
end

local Get

local function GetTable(read, count)
	local out = {}
	for _ = 1, count do
		local key = Remember(read, Get(read))
		local value = Remember(read, Get(read))
		if key ~= nil then out[key] = value end
	end
	return out
end

local function GetList(read, count)
	local out = {}
	for i = 1, count do out[i] = Remember(read, Get(read)) end
	return out
end

function Get(read)
	local kind = GetByte(read)
	if kind > 31 then return kind - 32 end
	if kind == 2 then return GetBytes(read, 4) end
	if kind == 3 then return -GetBytes(read, 4) end
	if kind == 4 then return GetBytes(read, 8) end
	if kind == 5 then return -GetBytes(read, 8) end
	if kind == 6 then return Single(GetBytes(read, 4)) end
	if kind == 7 then return GetString(read, GetByte(read)) end
	if kind == 8 then return GetString(read, GetBytes(read, 2)) end
	if kind == 9 then return read.seen[GetBytes(read, 4)] end
	if kind == 10 then return GetTable(read, GetByte(read)) end
	if kind == 11 then return GetTable(read, GetBytes(read, 2)) end
	if kind == 12 then return GetByte(read) end
	if kind == 13 then return -GetByte(read) end
	if kind == 14 then return GetBytes(read, 2) end
	if kind == 15 then return -GetBytes(read, 2) end
	if kind == 16 then return false end
	if kind == 17 then return true end
	if kind == 20 then return GetList(read, GetByte(read)) end
	if kind == 21 then return GetList(read, GetBytes(read, 2)) end
	if kind == 22 then return GetList(read, GetBytes(read, 4)) end
	return nil       -- 1, 18, 19
end

-- The table a message carries, or nil. Input is untrusted: it may be truncated or garbage.
function Wire.Decode(text)
	local read = { text = text, at = 1, seen = {} }
	local ok, outer = pcall(GetTable, read, 1)
	local packet = ok and outer[1]
	return type(packet) == "table" and packet or nil
end

-- Parts

local FIRST, NEXT, LAST, WHOLE = 1, 2, 3, 4
local MOST_PARTS = 8         -- drop a message split into more parts than this

-- A message as the addon messages to send: itself when it fits, else marked parts of 254 bytes.
function Wire.Frames(text)
	if #text <= Wire.LONGEST then return { text } end
	local size = Wire.LONGEST - 1
	local frames = { char(FIRST) .. text:sub(1, size) }
	local at = size + 1
	while at + size <= #text do
		frames[#frames + 1] = char(NEXT) .. text:sub(at, at + size - 1)
		at = at + size
	end
	frames[#frames + 1] = char(LAST) .. text:sub(at)
	return frames
end

-- One addon message from `from`. Returns the whole message once complete; `parts` is the caller's buffer.
function Wire.Receive(parts, from, text)
	local mark = byte(text, 1)
	if not mark or mark > 9 then return text end
	local rest = text:sub(2)
	if mark == WHOLE then return rest end
	if mark == FIRST then
		parts[from] = { rest }
	elseif mark == NEXT or mark == LAST then
		local waiting = parts[from]
		if not waiting then return nil end
		waiting[#waiting + 1] = rest
		if mark == LAST then
			parts[from] = nil
			return table.concat(waiting)
		elseif #waiting > MOST_PARTS then
			parts[from] = nil
		end
	end
	return nil
end
