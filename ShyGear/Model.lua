-- Scores a gear change as percent on each thing a way of playing cares about (axes), weighed for the
-- character's talent build. Stat conversions are asked of the client as the character sheet does: strength
-- and agility to attack power and crit, ratings to percent at the character's level, intellect to mana and
-- spell crit, spirit to regen, armor to damage taken. Hand-set numbers are marked.
--
-- Axes: damage (melee), shoot (ranged), spell (spell damage), heal, tough (effective health from health,
--   armor, dodge, parry and block), mana (the pool), regen (mana between pulls; health for those without
--   mana), wand.
-- Verdict: { kind = "upgrade" | "later" | "same" | "worse" | "cant", score (weighted percent),
--   axes = { damage =, tough =, ... }, d (stat changes), item, over (replaced item; nil for an empty slot),
--   slot, later (required level), soon (within SOON levels), extra (an effect that isn't scored),
--   why (for "cant"), light (lighter armor than the character's own), heavier (the character's own armor
--   over lighter), keep (score used when choosing between items; halved for light armor) }

local ADDON, ns = ...
local T = ns.T

-- Hand-set: what one percent on each axis is worth to a way of playing; its main axis is 1.
--   hand     where its weapon damage comes from: "melee" or "ranged" (nil: spells)
--   armored  wants the heaviest armor it can wear (casters take their stats from any)
--   shield   keeps a shield in the off hand: a weapon is never weighed for it
--   cat      a point of agility is attack power in cat form, whatever form it is weighed in
--   armor    multiplier on armor from items (bear form)
ns.ROLES = {
	melee  = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.08 },
	ranged = { hand = "ranged", armored = true, shoot = 1, tough = 0.25, mana = 0.2, regen = 0.2 },
	tank   = { hand = "melee", armored = true, shield = true, tough = 1, damage = 0.5, shoot = 0.05, regen = 0.05 },
	caster = { spell = 1, tough = 0.3, mana = 0.45, regen = 0.4, wand = 0.2 },
	healer = { heal = 1, spell = 0.2, tough = 0.25, mana = 0.65, regen = 0.45, wand = 0.2 },
}
local R = ns.ROLES

-- Hand-set: the same for each of ShyQuest's talent builds, by class and build id.
ns.BUILDS = {
	WARRIOR = {
		protsolo = { hand = "melee", armored = true, shield = true, tough = 1, damage = 0.9, shoot = 0.05, regen = 0.06 },
		arms     = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.08 },
		fury     = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.07 },
		prot     = { hand = "melee", armored = true, shield = true, tough = 1, damage = 0.45, shoot = 0.05, regen = 0.03 },
		armspvp  = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.75, regen = 0.02 },
	},
	ROGUE = {
		combat        = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.06 },
		assassination = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.06 },
		subtlety      = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.3, regen = 0.06 },
		subpvp        = { hand = "melee", armored = true, damage = 1, shoot = 0.05, tough = 0.7, regen = 0.03 },
	},
	HUNTER = {
		bm       = { hand = "ranged", armored = true, shoot = 1, tough = 0.25, mana = 0.2, regen = 0.2 },
		mm       = { hand = "ranged", armored = true, shoot = 1, tough = 0.25, mana = 0.25, regen = 0.2 },
		survival = { hand = "melee", armored = true, damage = 1, tough = 0.35, mana = 0.2, regen = 0.2 },
		lonewolf = { hand = "ranged", armored = true, shoot = 1, tough = 0.25, mana = 0.3, regen = 0.15 },
		bmpvp    = { hand = "ranged", armored = true, shoot = 1, tough = 0.7, mana = 0.25, regen = 0.1 },
	},
	PALADIN = {
		ret     = { hand = "melee", armored = true, damage = 1, spell = 0.1, heal = 0.1, tough = 0.3, mana = 0.15, regen = 0.1 },
		holy    = { heal = 1, damage = 0.2, spell = 0.05, tough = 0.3, mana = 0.7, regen = 0.35 },
		prot    = { hand = "melee", armored = true, shield = true, tough = 1, damage = 0.5, spell = 0.2, heal = 0.05, mana = 0.3, regen = 0.1 },
		holypvp = { heal = 1, damage = 0.25, spell = 0.15, tough = 0.9, mana = 0.5, regen = 0.15 },
	},
	SHAMAN = {
		enh   = { hand = "melee", armored = true, damage = 1, spell = 0.15, heal = 0.1, tough = 0.3, mana = 0.25, regen = 0.15 },
		ele   = { spell = 1, damage = 0.05, heal = 0.1, tough = 0.4, mana = 0.55, regen = 0.4 },
		resto = { heal = 1, spell = 0.25, damage = 0.1, tough = 0.3, mana = 0.6, regen = 0.4 },
		tank  = { hand = "melee", armored = true, shield = true, tough = 1, damage = 0.55, spell = 0.1, heal = 0.05, mana = 0.2, regen = 0.1 },
		pvp   = { hand = "melee", armored = true, damage = 1, spell = 0.2, heal = 0.1, tough = 0.7, mana = 0.2, regen = 0.05 },
	},
	DRUID = {
		cat      = { hand = "melee", cat = true, damage = 1, heal = 0.1, tough = 0.3, mana = 0.1, regen = 0.1 },
		bear     = { hand = "melee", cat = true, armor = 2.8, tough = 1, damage = 0.45, heal = 0.05, mana = 0.05, regen = 0.05 },
		balance  = { spell = 1, heal = 0.15, tough = 0.35, mana = 0.5, regen = 0.4 },
		resto    = { heal = 1, spell = 0.2, damage = 0.1, tough = 0.25, mana = 0.6, regen = 0.5 },
		feralpvp = { hand = "melee", cat = true, damage = 1, heal = 0.1, tough = 0.7, mana = 0.15, regen = 0.05 },
	},
	MAGE = {
		frost    = { spell = 1, tough = 0.3, mana = 0.4, regen = 0.35, wand = 0.15 },
		fire     = { spell = 1, tough = 0.3, mana = 0.4, regen = 0.35, wand = 0.15 },
		arcane   = { spell = 1, tough = 0.3, mana = 0.8, regen = 0.45, wand = 0.1 },
		frostaoe = { spell = 1, tough = 0.4, mana = 0.55, regen = 0.4, wand = 0.05 },
		frostpvp = { spell = 1, tough = 0.8, mana = 0.4, regen = 0.15, wand = 0.05 },
	},
	WARLOCK = {
		aff     = { spell = 1, tough = 0.45, mana = 0.3, regen = 0.45, wand = 0.25 },
		drain   = { spell = 1, tough = 0.8, mana = 0.35, regen = 0.45, wand = 0.2 },
		demo    = { spell = 1, tough = 0.5, mana = 0.3, regen = 0.45, wand = 0.25 },
		destro  = { spell = 1, tough = 0.4, mana = 0.45, regen = 0.4, wand = 0.15 },
		demopvp = { spell = 1, tough = 0.9, mana = 0.3, regen = 0.2, wand = 0.05 },
	},
	PRIEST = {
		shadow  = { spell = 1, heal = 0.05, tough = 0.35, mana = 0.45, regen = 0.6, wand = 0.4 },
		wand    = { wand = 1, spell = 0.5, heal = 0.1, tough = 0.4, mana = 0.4, regen = 0.5 },
		disc    = { heal = 1, spell = 0.25, tough = 0.3, mana = 0.6, regen = 0.45, wand = 0.3 },
		holy    = { heal = 1, spell = 0.2, tough = 0.25, mana = 0.65, regen = 0.5, wand = 0.3 },
		discpvp = { heal = 1, spell = 0.3, tough = 0.9, mana = 0.5, regen = 0.2, wand = 0.1 },
	},
}

-- Multiplier on survival for the player's lean setting.
local LEAN = { damage = 0.5, balanced = 1, tough = 2 }

local ARMOR_PER_AGILITY = 2   -- a local in Blizzard's PaperDollFrameStats.lua
local DEFENSE_EACH = 0.04     -- STAT_PER_DEFENSE there: a defense point's miss, dodge, parry and block
local FORM_AP_PER_AGILITY = 1 -- the character sheet's druid line: a point of agility in cat form
local OFF_HAND = 0.5          -- off-hand weapons hit for half; not in any client table
-- The game's hit caps against a target of your level (CR_*_HIT_CAP_TOOLTIP): melee and ranged, dual
-- wielding, spells.
local MISS, MISS_DUAL, MISS_SPELL = 5, 24, 4
local DODGED = 5              -- BASE_ENEMY_DODGE_CHANCE[0] in Blizzard's PaperDollFrameStats.lua
local CRIT_SPELL = 0.5        -- a spell crit adds 50%, a weapon crit 100%
local CAN_BLOCK = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local BLOCK_BASE = 5          -- block chance a shield brings, before skill
-- Hand-set: share of a blocked hit a block stops; share of physical damage that comes from swings and
-- shots (what haste speeds up).
local BLOCKED, HASTED = 0.3, 0.7
-- Hand-set: percent a point of spell damage (healing) adds to a top-rank spell, times your level, before
-- any you have; each point you have already makes the next worth a little less.
local SPELL_SHARE, HEAL_SHARE = 17, 7
local HEAL_AS_SPELL = 1 / 3   -- healing on an item also adds a third as much spell damage

-- Talents (Data/Talents.lua) count at the ranks you have. Hand-set: the share of physical damage from
-- abilities, which crit damage talents touch; the share of the time Spirit Tap is up while leveling; spell
-- damage per Intellect from Arcane Blast (15% a charge, two charges on average).
local ABILITY_SHARE, TAPPED, BLAST = 0.5, 0.5, 0.3

-- Armor proficiency spells, heaviest first: { weight, spellID } (Plate Mail, Mail, Leather, Cloth).
local TRAINED = { { 4, 750 }, { 3, 8737 }, { 2, 9077 }, { 1, 9078 } }
-- Hand-set: between two upgrades, lighter armor than the character's own counts for this much.
local STOPGAP = 0.5

local MARGIN = 1    -- weighted percent within which a trade counts as "same"
local DOWN = 3      -- weighted percent lighter armor must gain to replace your own type
local SOON = 3      -- levels ahead an upgrade is still marked
local STALE = 5     -- seconds a snapshot of the character is kept (buffs change it)

local AXES = { "damage", "shoot", "spell", "heal", "tough", "mana", "regen", "wand" }
local AXIS_NAME = { spell = "spell damage", heal = "healing", tough = "survival", mana = "mana", wand = "wand damage" }
local DPS_OF = { [INVSLOT_MAINHAND] = "mainDps", [INVSLOT_OFFHAND] = "offDps", [INVSLOT_RANGED] = "rangedDps" }
-- Ratings and the combat rating each is read as, by what it counts for.
local RATINGS = {
	hit = CR_HIT_MELEE, hitRanged = CR_HIT_RANGED, spellHit = CR_HIT_SPELL,
	crit = CR_CRIT_MELEE, critRanged = CR_CRIT_RANGED, spellCrit = CR_CRIT_SPELL,
	haste = CR_HASTE_MELEE, hasteRanged = CR_HASTE_RANGED, spellHaste = CR_HASTE_SPELL,
	expertise = CR_EXPERTISE, defense = CR_DEFENSE_SKILL, dodge = CR_DODGE, parry = CR_PARRY, block = CR_BLOCK,
}

local me
local verdicts = {}
local talents   -- what your talents add, read from the tree when they change (ns.ForgetTalents)
local NO_TALENTS = { stat = {}, apOf = {}, spellOf = {}, healOf = {}, armor = 0, crit = 0, tap = 0, blast = false, names = {} }

local function Plain(...)
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v == nil or issecretvalue(v) then return false end
	end
	return true
end

-- Value of one more point of a stat, from the client's function of the whole stat.
local function Slope(fn, stat, at)
	local here, there = fn(stat, at), fn(stat, at + 10)
	if not Plain(here, there) then return end
	return (there - here) / 10
end

-- A rating's percent per point at the character's level.
local function Rate(rating)
	local n = GetCombatRatingBonusForCombatRatingValue(rating, 100)
	if not Plain(n) then return 0 end
	return n / 100
end

local function Per(amount, of)
	return of > 0 and amount / of or 0
end

local function Dps(item)
	return item and item.stats.dps or 0
end

-- What your talents add, in percent: { stat = { int = 10 }, apOf, spellOf, healOf (by stat), armor, crit,
-- tap, blast, names }. Read from the active talents' nodes; nil while the game hasn't the tree yet.
local function Talents()
	if talents then return talents end
	local data = ns.TALENTS
	if not data then return nil end
	local config = C_SpecializationInfo.GetCombatConfigIDForSpecGroup(C_SpecializationInfo.GetActiveSpecGroup())
	local info = config and C_Traits.GetConfigInfo(config)
	if not info or not info.treeIDs then return nil end
	local t = { stat = {}, apOf = {}, spellOf = {}, healOf = {}, armor = 0, crit = 0, tap = 0, blast = false, names = {} }
	for _, tree in ipairs(info.treeIDs) do
		for _, node in ipairs(C_Traits.GetTreeNodes(tree) or {}) do
			local at = C_Traits.GetNodeInfo(config, node)
			local entry = at and at.activeEntry
			local id, rank = entry and entry.entryID, entry and entry.rank
			local talent = Plain(id, rank) and rank > 0 and data[id]
			if talent then
				t.names[#t.names + 1] = ("%s %d"):format(talent[2], rank)
				for i = 3, #talent do
					local kind, stats, amounts = talent[i][1], talent[i][2], talent[i][3]
					local n = amounts[math.min(rank, #amounts)]
					if t[kind] and stats then
						for _, stat in ipairs(stats) do t[kind][stat] = (t[kind][stat] or 0) + n end
					elseif kind == "blast" then
						t.blast = true
					elseif type(t[kind]) == "number" then
						t[kind] = t[kind] + n
					end
				end
			end
		end
	end
	table.sort(t.names)
	talents = t
	return t
end

function ns.ForgetTalents()
	talents = nil
end

-- What gear is weighed for: the weights, and the build's name when it is a build.
local function Profile(class)
	local focus = ns.Focus()
	if focus == "build" then
		local build = ns.Build()
		local own = build and ns.BUILDS[class] and ns.BUILDS[class][build.id]
		if own then return own, focus, build.name end
		focus = ns.Focuses()[1]
	end
	return R[focus], focus, nil
end

-- Snapshot of the character; nil while any stat is secret (SecretWhenUnitStatsRestricted).
local function Build()
	local class = ns.Class()
	local level, health = UnitLevel("player"), UnitHealthMax("player")
	local _, armor = UnitArmor("player")
	local ap, apUp, apDown = UnitAttackPower("player")
	local rap, rapUp, rapDown = UnitRangedAttackPower("player")
	local _, str = UnitStat("player", LE_UNIT_STAT_STRENGTH)
	local _, agi = UnitStat("player", LE_UNIT_STAT_AGILITY)
	local _, int = UnitStat("player", LE_UNIT_STAT_INTELLECT)
	local _, spi = UnitStat("player", LE_UNIT_STAT_SPIRIT)
	local mana = UnitPowerMax("player", Enum.PowerType.Mana)
	if not Plain(class, level, health, armor, ap, apUp, apDown, rap, rapUp, rapDown, str, agi, int, spi, mana) then return end

	local apPerStr = Slope(GetAttackPowerForStat, LE_UNIT_STAT_STRENGTH, str)
	local apPerAgi = Slope(GetAttackPowerForStat, LE_UNIT_STAT_AGILITY, agi)
	local rapPerStr = Slope(GetRangedAttackPowerForStat, LE_UNIT_STAT_STRENGTH, str)
	local rapPerAgi = Slope(GetRangedAttackPowerForStat, LE_UNIT_STAT_AGILITY, agi)
	local critPerAgi = Slope(GetCritChanceFromStat, LE_UNIT_STAT_AGILITY, agi)
	local spellCritPerInt = Slope(GetSpellCritChanceFromStat, LE_UNIT_STAT_INTELLECT, int)
	local hpPerSta = UnitHPPerStamina("player")
	local crit, rangedCrit, spellCrit = GetCritChance(), GetRangedCritChance(), GetSpellCritChance()
	local hit, rangedHit, spellHit = GetHitModifier(), GetRangedHitModifier(), GetSpellHitModifier()
	local hitRating, rangedRating, spellRating = GetCombatRatingBonus(CR_HIT_MELEE), GetCombatRatingBonus(CR_HIT_RANGED), GetCombatRatingBonus(CR_HIT_SPELL)
	local haste, rangedHaste, spellHaste = GetMeleeHaste(), GetRangedHaste(), GetCombatRatingBonus(CR_HASTE_SPELL)
	local expertise = GetExpertise()
	local dodge, parry, block = GetDodgeChance(), GetParryChance(), GetBlockChance()
	local dodgeFromAgi = GetDodgeChanceFromAttribute()
	local power, healing = GetSpellBonusDamage(2), GetSpellBonusHealing()   -- 2: fire, as the sheet's lowest school
	local manaRegen = GetManaRegen()
	local hpRegen = GetHealthRegen()
	local manaFromSpi, hpFromSpi = GetManaRegenFromSpirit(), GetHealthRegenFromSpirit()
	if not Plain(apPerStr, apPerAgi, rapPerStr, rapPerAgi, critPerAgi, spellCritPerInt, hpPerSta, crit, rangedCrit,
		spellCrit, hit, rangedHit, spellHit, hitRating, rangedRating, spellRating, haste, rangedHaste, spellHaste,
		expertise, dodge, parry, block, dodgeFromAgi, power, healing, manaRegen, hpRegen, manaFromSpi, hpFromSpi) then
		return
	end

	local profile, focus, buildName = Profile(class)
	local weigh = {}
	for _, axis in ipairs(AXES) do weigh[axis] = profile[axis] end
	if weigh.tough then weigh.tough = weigh.tough * LEAN[T.db.lean] end

	local own   -- heaviest armor the character can wear
	if profile.armored then
		for _, trained in ipairs(TRAINED) do
			if C_SpellBook.IsSpellKnown(trained[2]) then
				own = trained[1]
				break
			end
		end
	end

	local rate = {}
	for key, rating in pairs(RATINGS) do rate[key] = Rate(rating) end

	-- Talents: a stat worth more of itself, or of another. Attack power from intellect is the client's
	-- where it says so, else the talent's.
	local tal = Talents() or NO_TALENTS
	local times = {}
	for _, stat in ipairs({ "str", "agi", "sta", "int", "spi" }) do times[stat] = 1 + (tal.stat[stat] or 0) / 100 end
	local apPerInt = Slope(GetAttackPowerForStat, LE_UNIT_STAT_INTELLECT, int) or 0
	local mainAxis = (profile.hand == "melee" and "damage") or (profile.hand == "ranged" and "shoot")
		or ((profile.heal or 0) > (profile.spell or 0) and "heal") or "spell"

	local main, off, ranged = ns.Worn(INVSLOT_MAINHAND), ns.Worn(INVSLOT_OFFHAND), ns.Worn(INVSLOT_RANGED)
	return {
		at = GetTime(), class = class, level = level, focus = focus, buildName = buildName,
		weigh = weigh, hand = profile.hand, shield = profile.shield, armorTimes = profile.armor or 1, own = own,
		health = health, armor = armor, mana = mana, spirit = spi,
		ap = ap + apUp + apDown, rap = rap + rapUp + rapDown,
		apPerStr = apPerStr, apPerAgi = profile.cat and math.max(apPerAgi, FORM_AP_PER_AGILITY) or apPerAgi,
		rapPerStr = rapPerStr, rapPerAgi = rapPerAgi,
		critPerAgi = critPerAgi * 100, spellCritPerInt = spellCritPerInt * 100,   -- the client returns a fraction
		dodgePerAgi = Per(dodgeFromAgi * 100, agi),
		hpPerSta = hpPerSta,
		manaPerInt = mana > 0 and MANA_PER_INTELLECT or 0,
		crit = crit, rangedCrit = rangedCrit, spellCrit = spellCrit,
		hit = hit + hitRating, rangedHit = rangedHit + rangedRating, spellHit = spellHit + spellRating,
		haste = haste, rangedHaste = rangedHaste, spellHaste = spellHaste, expertise = expertise,
		dodge = dodge, parry = parry, block = block, canBlock = CAN_BLOCK[class] or false,
		power = power, healing = healing,
		manaRegen = manaRegen, hpRegen = hpRegen,
		manaPerSpi = Per(manaFromSpi, spi), hpPerSpi = Per(hpFromSpi, spi),
		rate = rate,
		talents = tal, times = times, mainAxis = mainAxis,
		apOfInt = math.max(apPerInt, (tal.apOf.int or 0) / 100),
		mainDps = Dps(main), offDps = Dps(off), rangedDps = Dps(ranged),
		twoHand = main ~= nil and main.equipLoc == "INVTYPE_2HWEAPON",
		dualWielding = main ~= nil and off ~= nil and Dps(off) > 0,
		dual = CanDualWield(),
	}
end

local function Me()
	if me and GetTime() - me.at > STALE then ns.Stale() end
	if not me then me = Build() end
	return me
end

-- Percent more that lands: misses (or dodges) at `now`, under `cap`, after `delta` more.
local function Lands(now, delta, cap)
	local before, after = math.max(0, cap - now), math.max(0, cap - now - delta)
	return (before - after) / (100 - before) * 100
end

-- Percent more from a crit chance `delta` higher than `now`, a crit adding `bonus` of a hit.
local function Crits(now, delta, bonus)
	return delta * bonus / (1 + now * bonus / 100)
end

-- Effective health: what it takes to bring you down against an attacker of your level.
local function Tough(health, armor, avoid)
	local through = 1 - C_PaperDollInfo.GetArmorEffectiveness(math.max(armor, 0), me.level)
	return health / math.max(through * (1 - math.min(avoid, 95) / 100), 0.05)
end

-- Stat and weapon deltas as percent on each axis.
local function Axes(d)
	-- A primary stat counts with what your talents add to it.
	local times, tal = me.times, me.talents
	local function S(key) return (d[key] or 0) * (times[key] or 1) end
	-- Spell damage, healing or attack power your talents give as a share of stats.
	local function From(of, but)
		local n = 0
		for stat, pct in pairs(of) do
			if stat ~= but then n = n + S(stat) * pct / 100 end
		end
		return n
	end
	-- Talents' extra crit damage counts on your main kind of damage: on abilities for weapons.
	local more = tal.crit / 100
	local critMelee = 1 + (me.mainAxis == "damage" and more * ABILITY_SHARE or 0)
	local critRanged = 1 + (me.mainAxis == "shoot" and more * ABILITY_SHARE or 0)
	local critSpell = CRIT_SPELL * (1 + (me.mainAxis == "spell" and more or 0))
	local a = {}
	local magic, rate = ATTACK_POWER_MAGIC_NUMBER, me.rate

	-- Melee: weapon damage and attack power, then crit, hit, expertise and haste.
	local base = me.mainDps + me.offDps * OFF_HAND + me.ap / magic
	local gain = S("mainDps") + S("offDps") * OFF_HAND
		+ (S("ap") + S("feral") + S("str") * me.apPerStr + S("agi") * me.apPerAgi + S("int") * me.apOfInt
			+ From(tal.apOf, "int")) / magic
	a.damage = base > 0 and gain / base * 100 or 0
	a.damage = a.damage + Crits(me.crit, S("agi") * me.critPerAgi + S("crit") * rate.crit, critMelee)
		+ Lands(me.hit, S("hit") * rate.hit, me.dualWielding and MISS_DUAL or MISS)
		+ Lands(me.expertise, S("expertise") * rate.expertise, DODGED)
		+ S("haste") * rate.haste / (1 + me.haste / 100) * HASTED

	-- Ranged: the same for the ranged weapon; nothing without one.
	if me.rangedDps > 0 or S("rangedDps") > 0 then
		base = me.rangedDps + me.rap / magic
		gain = S("rangedDps") + (S("rap") + S("ap") + S("str") * me.rapPerStr + S("agi") * me.rapPerAgi) / magic
		a.shoot = gain / base * 100 + Crits(me.rangedCrit, S("agi") * me.critPerAgi + S("crit") * rate.critRanged, critRanged)
			+ Lands(me.rangedHit, S("hit") * rate.hitRanged, MISS)
			+ S("haste") * rate.hasteRanged / (1 + me.rangedHaste / 100) * HASTED
	else
		a.shoot = 0
	end

	-- Spells: power against a spell's base amount, crit, hit and haste. Healing never misses.
	local spellCrit = S("int") * me.spellCritPerInt + (S("crit") + S("spellCrit")) * rate.spellCrit
	local quicker = S("haste") * rate.spellHaste / (1 + me.spellHaste / 100)
	local power = S("power") + S("spell") + S("heal") * HEAL_AS_SPELL + From(tal.spellOf) + (tal.blast and S("int") * BLAST or 0)
	a.spell = power / (me.level * 100 / SPELL_SHARE + me.power) * 100
		+ Crits(me.spellCrit, spellCrit, critSpell) + Lands(me.spellHit, (S("hit") + S("spellHit")) * rate.spellHit, MISS_SPELL) + quicker
	a.heal = (S("power") + S("heal") + From(tal.healOf)) / (me.level * 100 / HEAL_SHARE + me.healing) * 100
		+ Crits(me.spellCrit, spellCrit, CRIT_SPELL) + quicker

	-- Survival: health, armor, and the hits that never land (dodge, parry, block, a defense point's share of each).
	local defense = S("defense") * rate.defense * DEFENSE_EACH
	local parry = me.parry > 0 and 1 or 0
	local blockNow = me.block
	local blockThen = me.block
	if d.shieldOff then blockThen = 0 elseif d.shieldOn and me.canBlock then blockThen = BLOCK_BASE end
	local blocks = blockThen > 0 and 1 or 0
	local avoid = me.dodge + me.parry + blockNow * BLOCKED
	local avoidThen = avoid + S("agi") * me.dodgePerAgi + S("dodge") * rate.dodge + defense * (2 + parry)
		+ parry * S("parry") * rate.parry
		+ (blockThen - blockNow + blocks * (S("block") * rate.block + defense)) * BLOCKED
	local before = Tough(me.health, me.armor, avoid)
	local after = Tough(me.health + S("sta") * me.hpPerSta + S("health"),
		me.armor + S("armor") * me.armorTimes * (1 + tal.armor / 100) + S("agi") * ARMOR_PER_AGILITY, avoidThen)
	a.tough = (after / before - 1) * 100

	a.mana = me.mana > 0 and (S("int") * me.manaPerInt + S("mana")) / me.mana * 100 or 0

	-- Regen between pulls: mana for those with mana (mana per 5 sec counts in full), health for the rest.
	-- Spirit Tap's extra spirit after a kill counts for the share of the time it is up.
	local spirit = S("spi") * (1 + tal.tap / 100 * TAPPED)
	if me.mana > 0 then
		a.regen = (spirit * me.manaPerSpi + S("mp5") / 5) / math.max(me.manaRegen, 0.5) * 100
	else
		a.regen = (spirit * me.hpPerSpi + S("hp5") / 5) / math.max(me.hpRegen, 0.5) * 100
	end

	local wand = S("rangedDps")
	if me.rangedDps > 0 then
		a.wand = math.max(-100, math.min(100, wand / me.rangedDps * 100))
	else
		a.wand = wand > 0 and 100 or 0
	end
	return a
end

local function Score(axes)
	local score = 0
	for axis, w in pairs(me.weigh) do score = score + w * axes[axis] end
	return score
end

-- Slots the item could go in, with the slots it would empty.
local function Places(item)
	local loc = item.equipLoc
	if loc == "INVTYPE_2HWEAPON" then
		return { { slot = INVSLOT_MAINHAND, off = { INVSLOT_MAINHAND, INVSLOT_OFFHAND } } }
	end
	local places = {}
	for _, slot in ipairs(item.slots) do
		if slot == INVSLOT_OFFHAND then
			-- Nothing beside a two-hander; an off-hand weapon needs dual wield, and a build that keeps a
			-- shield there never puts one in.
			local weapon = loc == "INVTYPE_WEAPON" or loc == "INVTYPE_WEAPONOFFHAND"
			if not me.twoHand and (not weapon or (me.dual and not me.shield)) then
				places[#places + 1] = { slot = slot, off = { slot } }
			end
		else
			places[#places + 1] = { slot = slot, off = { slot } }
		end
	end
	return places
end

-- Stat deltas with the item in that place; nil while an equipped item isn't loaded.
local function Change(item, place)
	local d = {}
	for key, n in pairs(item.stats) do
		if key ~= "dps" then d[key] = n end
	end
	local hand = DPS_OF[place.slot]
	if hand then d[hand] = Dps(item) end

	local over, shield
	for _, slot in ipairs(place.off) do
		if GetInventoryItemLink("player", slot) then
			local worn = ns.Worn(slot)
			if not worn then return end
			over = over or worn
			shield = shield or worn.equipLoc == "INVTYPE_SHIELD"
			for key, n in pairs(worn.stats) do
				if key ~= "dps" then d[key] = (d[key] or 0) - n end
			end
			local wornHand = DPS_OF[slot]
			if wornHand then d[wornHand] = (d[wornHand] or 0) - Dps(worn) end
		end
	end
	-- Blocking goes and comes with a shield.
	local mine = item.equipLoc == "INVTYPE_SHIELD"
	if shield and not mine then d.shieldOff = true elseif mine and not shield then d.shieldOn = true end
	return d, over
end

-- Returns whether any weighted axis gains, and whether any loses.
local function Sided(axes)
	local gains, loses = false, false
	for axis, w in pairs(me.weigh) do
		if w > 0 then
			if axes[axis] > 0.005 then gains = true elseif axes[axis] < -0.005 then loses = true end
		end
	end
	return gains, loses
end

function ns.Judge(link)
	local item = ns.Read(link)
	if not item or not item.slots then return end
	if not Me() then return ns.Later() end
	local known = verdicts[link]
	if known then return known end

	local v
	if not item.usable then
		v = { kind = "cant", why = item.why }
	else
		for _, place in ipairs(Places(item)) do
			local d, over = Change(item, place)
			if not d then return ns.Later() end
			local axes = Axes(d)
			local score = Score(axes)
			if not v or score > v.score then v = { score = score, axes = axes, d = d, over = over, slot = place.slot } end
		end
		if not v then return end   -- no slot it can go in
		local over = v.over
		v.light = item.weight ~= nil and me.own ~= nil and item.weight < me.own or nil
		v.heavier = item.weight ~= nil and item.weight == me.own and over ~= nil and over.weight ~= nil
			and over.weight < item.weight or nil
		-- Lighter armor in place of heavier must clear more than a margin.
		local down = v.light and over ~= nil and over.weight ~= nil and over.weight > item.weight
		-- MARGIN applies to trades only: a pure gain or anything in an empty slot is an upgrade, a pure loss is
		-- worse. Your own armor over lighter is an upgrade whenever it gains something and costs nothing overall.
		local gains, loses = Sided(v.axes)
		if v.score >= (down and DOWN or MARGIN) or (not down and v.score > 0 and (not loses or not over))
			or (v.heavier and gains and v.score >= 0) then
			v.kind = "upgrade"
			if item.later and item.later > me.level then
				v.kind, v.later, v.soon = "later", item.later, item.later - me.level <= SOON
			end
		elseif v.score <= -MARGIN or (v.score < 0 and not gains) then
			v.kind = "worse"
		else
			v.kind = "same"
		end
		v.extra = item.extra or (over and over.extra) or nil
		v.keep = v.score * (v.light and v.score > 0 and STOPGAP or 1)
	end
	v.item = item
	verdicts[link] = v
	return v
end

local function AxisName(axis)
	if axis == "damage" then return me.hand == "ranged" and "melee damage" or "damage" end
	if axis == "shoot" then return me.hand == "ranged" and "damage" or "ranged damage" end
	if axis == "regen" then return me.mana > 0 and "mana regen" or "health regen" end
	if axis == "spell" and not me.weigh.spell and me.weigh.heal then return "healing" end
	return AXIS_NAME[axis]
end

local function Percent(n)
	local text = math.abs(n) >= 10 and ("%+.0f"):format(n) or ("%+.1f"):format(n):gsub("%.0$", "")
	return text .. "%"
end

-- The weighted axes of a change, largest weighted first: { { axis, n, weight } }.
local function Ranked(axes)
	local parts = {}
	for _, axis in ipairs(AXES) do
		local w, n = me.weigh[axis], axes[axis]
		if w and w * n ~= 0 then parts[#parts + 1] = { axis = axis, n = n, weight = math.abs(w * n) } end
	end
	table.sort(parts, function(a, b) return a.weight > b.weight end)
	return parts
end

-- "+4.2% damage, -1% survival", largest weighted change first. loss: a color what it takes away is written in.
function ns.Words(v, loss)
	if not v or not v.axes or not me then return "" end
	local parts = Ranked(v.axes)
	local words = {}
	-- Up to three; the first is always shown, however small.
	for i = 1, math.min(3, #parts) do
		if i > 1 and parts[i].weight < 0.25 then break end
		words[i] = Percent(parts[i].n) .. " " .. AxisName(parts[i].axis)
		if loss and parts[i].n < 0 then
			words[i] = ("|cff%02x%02x%02x%s|r"):format(math.floor(loss[1] * 255 + 0.5), math.floor(loss[2] * 255 + 0.5), math.floor(loss[3] * 255 + 0.5), words[i])
		end
	end
	return table.concat(words, ", ")
end

-- What each stat changed is worth to you, most first:
-- { { key, n, name, worth (weighted percent), says ("+1.4% damage", "very little", "no use to you") } }.
local SAME_AS = { mainDps = "dps", offDps = "dps", rangedDps = "dps" }
local function Parts(d)
	local list = {}
	for key, n in pairs(d) do
		if type(n) == "number" and n ~= 0 then
			local one = Axes({ [key] = n })
			local top = Ranked(one)[1]
			local stat = ns.STAT_KEY[SAME_AS[key] or key]
			list[#list + 1] = {
				key = key, n = n, name = stat and ns.StatName(stat) or key, worth = Score(one),
				says = not top and "no use to you" or top.weight < 0.05 and "very little"
					or (Percent(top.n) .. " " .. AxisName(top.axis)),
			}
		end
	end
	table.sort(list, function(a, b)
		if a.worth ~= b.worth then return a.worth > b.worth end
		return a.name < b.name
	end)
	return list
end

function ns.Parts(v)
	if not v or not v.d or not me then return nil end
	return Parts(v.d)
end

-- What each stat is worth putting `link` on in place of the worn items `worn` (links), or nil.
function ns.Trade(link, worn)
	local item = ns.Read(link)
	if not item or not item.slots or not item.usable or not Me() then return nil end
	local off, used = {}, {}
	for _, wornLink in ipairs(worn) do
		for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
			if not used[slot] and GetInventoryItemLink("player", slot) == wornLink then
				used[slot], off[#off + 1] = true, slot
				break
			end
		end
	end
	if #off == 0 then return nil end
	local d = Change(item, { slot = off[1], off = off })
	return d and Parts(d)
end

-- Whether `link` is weighed in place of the worn item `wornLink`: false when your build would never put
-- it there (a one-hander against a tank's shield), nil when that can't be said.
function ns.Weighs(link, wornLink)
	local item = ns.Read(link)
	if not item or not item.slots or not Me() then return nil end
	for _, place in ipairs(Places(item)) do
		for _, slot in ipairs(place.off) do
			if GetInventoryItemLink("player", slot) == wornLink then return true end
		end
	end
	return false
end

-- For light armor: its type and the character's own type, localized.
function ns.Stopgap(v)
	if not v or not v.light or not me then return end
	return v.item.kind, ns.ArmorName(me.own)
end

-- The talent build gear is weighed for, as the player knows it ("Arms"), or nil.
function ns.ForName()
	local m = Me()
	return m and m.buildName or nil
end

-- What one point of each stat gives, a line each.
function ns.Rates()
	local m = Me()
	if not m then return end
	local ranged = m.hand == "ranged"
	local perStr, perAgi = ranged and m.rapPerStr or m.apPerStr, ranged and m.rapPerAgi or m.apPerAgi
	local power = ranged and "ranged attack power" or "attack power"
	local function Plainly(n) return (("%.2f"):format(n):gsub("%.?0+$", "")) end
	local lines = {}
	if perStr > 0 then lines[#lines + 1] = ("1 Strength: %s %s"):format(Plainly(perStr), power) end
	local agility = {}
	if perAgi > 0 then agility[#agility + 1] = ("%s %s"):format(Plainly(perAgi), power) end
	if m.critPerAgi > 0 then agility[#agility + 1] = ("%.2f%% crit"):format(m.critPerAgi) end
	agility[#agility + 1] = ARMOR_PER_AGILITY .. " armor"
	lines[#lines + 1] = "1 Agility: " .. table.concat(agility, ", ")
	lines[#lines + 1] = ("1 Stamina: %d health"):format(m.hpPerSta)
	if m.mana > 0 then
		lines[#lines + 1] = ("1 Intellect: %d mana, %.2f%% spell crit"):format(m.manaPerInt, m.spellCritPerInt)
		lines[#lines + 1] = ("1 Spirit: %s mana every 5 sec out of combat"):format(Plainly(m.manaPerSpi * 5))
	elseif m.hpPerSpi > 0 then
		lines[#lines + 1] = ("1 Spirit: %s health every 5 sec out of combat"):format(Plainly(m.hpPerSpi * 5))
	end
	if m.rate.crit > 0 then lines[#lines + 1] = ("10 Crit: %s%% crit"):format(Plainly(m.rate.crit * 10)) end
	lines[#lines + 1] = ("%s %s: 1 damage per second"):format(Plainly(ATTACK_POWER_MAGIC_NUMBER), power)
	return lines
end

function ns.Stale()
	me = nil
	wipe(verdicts)
end

-- Every input to a verdict as text, for /shy gear report.
function ns.Report()
	local m = Me()
	if not m then return "Your stats are hidden right now (some fights do this). Try again out of combat." end
	local lines = {
		("%s, level %d, gearing for: %s (%s)"):format(m.class, m.level, m.buildName or ns.FOCUS_NAME[m.focus], T.db.lean),
		("Attack power %d (ranged %d), health %d, armor %d, mana %d, spirit %d"):format(m.ap, m.rap, m.health, m.armor, m.mana, m.spirit),
		("Weapons: main %.1f dps, off %.1f, ranged %.1f%s%s"):format(m.mainDps, m.offDps, m.rangedDps, m.twoHand and ", two-handed" or "", m.dual and ", can dual wield" or ""),
		("Crit %.2f%% (ranged %.2f%%, spells %.2f%%), hit %.2f%% (ranged %.2f%%, spells %.2f%%), expertise %.2f%%"):format(m.crit, m.rangedCrit, m.spellCrit, m.hit, m.rangedHit, m.spellHit, m.expertise),
		("Dodge %.2f%%, parry %.2f%%, block %.2f%%; spell power %d, healing %d"):format(m.dodge, m.parry, m.block, m.power, m.healing),
		("Regen out of combat: %.1f mana, %.1f health a second"):format(m.manaRegen, m.hpRegen),
		("One strength: %.2f attack power (%.2f ranged)"):format(m.apPerStr, m.rapPerStr),
		("One agility: %.2f attack power (%.2f ranged), %.3f%% crit, %.3f%% dodge, %d armor"):format(m.apPerAgi, m.rapPerAgi, m.critPerAgi, m.dodgePerAgi, ARMOR_PER_AGILITY),
		("One stamina: %.1f health. One intellect: %d mana, %.3f%% spell crit"):format(m.hpPerSta, m.manaPerInt, m.spellCritPerInt),
		("One spirit: %.3f mana, %.3f health a second"):format(m.manaPerSpi, m.hpPerSpi),
		("One rating: %.3f%% hit, %.3f%% crit, %.3f%% haste, %.3f%% expertise, %.3f defense"):format(m.rate.hit, m.rate.crit, m.rate.haste, m.rate.expertise, m.rate.defense),
		("%s attack power: 1 damage per second. Armor stops %.1f%% from level %d"):format(tostring(ATTACK_POWER_MAGIC_NUMBER), C_PaperDollInfo.GetArmorEffectiveness(math.max(m.armor, 0), m.level) * 100, m.level),
		m.own and ("Your armor: %s. Lighter armor is a stopgap: between upgrades it counts for %d%%"):format(tostring(ns.ArmorName(m.own)), STOPGAP * 100)
			or m.hand and "Your armor: no armor training found, so every type counts the same"
			or "Your armor: every type counts the same (caster stats are on cloth)",
		"Talents that change what a stat is worth: " .. (#m.talents.names > 0 and table.concat(m.talents.names, ", ") or "none"),
		"",
		"Weights (per percent):",
	}
	for _, axis in ipairs(AXES) do
		if m.weigh[axis] then lines[#lines + 1] = ("  %s %.2f"):format(AxisName(axis), m.weigh[axis]) end
	end
	lines[#lines + 1] = ""
	lines[#lines + 1] = "Equipped, as read:"
	for slot = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
		local link = GetInventoryItemLink("player", slot)
		if link then
			local item = ns.Read(link)
			local stats = {}
			if item then
				for key, n in pairs(item.stats) do stats[#stats + 1] = key .. " " .. n end
				table.sort(stats)
				if item.extra then stats[#stats + 1] = "(an effect, not weighed)" end
				if item.unread then
					local names = {}
					for i, key in ipairs(item.unread) do names[i] = ns.StatName(key) end
					stats[#stats + 1] = "(not counted: " .. table.concat(names, ", ") .. ")"
				end
			end
			lines[#lines + 1] = ("  %d %s: %s"):format(slot, item and item.name or "?", item and table.concat(stats, ", ") or "not read yet")
		end
	end
	return table.concat(lines, "\n")
end
