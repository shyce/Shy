-- Generated file. Do not edit by hand.
-- Where each cooldown stands in the cooldown manager, by class and leveling build: spell IDs in order.
--   essential, utility: cooldowns; bars, buffs: auras; hideCooldowns, hideAuras: neither. Read by Lineup.lua.
Shy.CooldownLineups = {
	DRUID = {
		cat = {
			essential = { 1822, 1079, 407995, 417141, 6807, 414644, 8921, 5570, 18562, 408120 },   -- Rake, Rip, Primal Bite, Berserk, Maul, Lacerate, Moonfire, Insect Swarm, Swiftmend, Wild Growth
			utility = { 1322605, 1850, 1238122, 5211, 8998, 22812, 29166, 17116, 22842, 6795, 5229, 5209, 20484, 740 },   -- Shifting Power, Dash, Feral Charge, Bash, Cower, Barkskin, Innervate, Nature's Swiftness, Frenzied Regeneration, Growl, Enrage, Challenging Roar, Rebirth, Tranquility
			bars = { 1822, 1079, 770, 1126 },   -- Rake, Rip, Faerie Fire, Mark of the Wild
			buffs = { 16864, 417141, 1850, 5215, 22812 },   -- Omen of Clarity, Berserk, Dash, Prowl, Barkskin
			hideAuras = { 1319289 },   -- Druid Forms
		},
		bear = {
			essential = { 6807, 414644, 407995, 417141, 1822, 1079, 8921, 5570, 18562, 408120 },   -- Maul, Lacerate, Primal Bite, Berserk, Rake, Rip, Moonfire, Insect Swarm, Swiftmend, Wild Growth
			utility = { 6795, 5211, 1238122, 5229, 22842, 22812, 5209, 1850, 29166, 17116, 20484, 740 },   -- Growl, Bash, Feral Charge, Enrage, Frenzied Regeneration, Barkskin, Challenging Roar, Dash, Innervate, Nature's Swiftness, Rebirth, Tranquility
			bars = { 414644, 99, 770, 1126, 467 },   -- Lacerate, Demoralizing Roar, Faerie Fire, Mark of the Wild, Thorns
			buffs = { 16864, 5229, 22842, 417141, 22812 },   -- Omen of Clarity, Enrage, Frenzied Regeneration, Berserk, Barkskin
			hideAuras = { 1319289 },   -- Druid Forms
		},
		balance = {
			essential = { 8921, 5570, 408120, 18562, 1822, 1079, 6807, 407995, 414644, 417141 },   -- Moonfire, Insect Swarm, Wild Growth, Swiftmend, Rake, Rip, Maul, Primal Bite, Lacerate, Berserk
			utility = { 29166, 17116, 22812, 20484, 740, 5211, 1238122, 1850, 6795, 5229, 22842, 5209 },   -- Innervate, Nature's Swiftness, Barkskin, Rebirth, Tranquility, Bash, Feral Charge, Dash, Growl, Enrage, Frenzied Regeneration, Challenging Roar
			bars = { 8921, 5570, 770, 1126, 467 },   -- Moonfire, Insect Swarm, Faerie Fire, Mark of the Wild, Thorns
			buffs = { 408248, 16880, 16864, 16850, 17116, 22812 },   -- Eclipse, Nature's Grace, Omen of Clarity, Improved Starfire, Nature's Swiftness, Barkskin
			hideAuras = { 1319289 },   -- Druid Forms
		},
		resto = {
			essential = { 18562, 408120, 8921, 5570, 1822, 1079, 6807, 407995, 414644, 417141 },   -- Swiftmend, Wild Growth, Moonfire, Insect Swarm, Rake, Rip, Maul, Primal Bite, Lacerate, Berserk
			utility = { 17116, 29166, 20484, 740, 22812, 5211, 1850, 1238122, 6795, 5229, 22842, 5209 },   -- Nature's Swiftness, Innervate, Rebirth, Tranquility, Barkskin, Bash, Dash, Feral Charge, Growl, Enrage, Frenzied Regeneration, Challenging Roar
			bars = { 774, 8936, 408120, 1126, 467 },   -- Rejuvenation, Regrowth, Wild Growth, Mark of the Wild, Thorns
			buffs = { 17116, 16864, 29166, 22812, 16689 },   -- Nature's Swiftness, Omen of Clarity, Innervate, Barkskin, Nature's Grasp
			hideAuras = { 1319289 },   -- Druid Forms
		},
		feralpvp = {
			essential = { 1822, 1079, 407995, 417141, 6807, 8921, 414644, 5570, 18562, 408120 },   -- Rake, Rip, Primal Bite, Berserk, Maul, Moonfire, Lacerate, Insect Swarm, Swiftmend, Wild Growth
			utility = { 1322605, 5211, 1238122, 1850, 22812, 17116, 22842, 29166, 8998, 5229, 6795, 5209, 20484, 740 },   -- Shifting Power, Bash, Feral Charge, Dash, Barkskin, Nature's Swiftness, Frenzied Regeneration, Innervate, Cower, Enrage, Growl, Challenging Roar, Rebirth, Tranquility
			bars = { 1822, 1079, 770, 339, 1126 },   -- Rake, Rip, Faerie Fire, Entangling Roots, Mark of the Wild
			buffs = { 16864, 417141, 1850, 5215, 22812, 17116 },   -- Omen of Clarity, Berserk, Dash, Prowl, Barkskin, Nature's Swiftness
			hideAuras = { 1319289 },   -- Druid Forms
		},
	},
	HUNTER = {
		bm = {
			essential = { 3044, 1978, 2643, 1293241, 19574, 3045, 2973, 1495, 13795, 13813 },   -- Arcane Shot, Serpent Sting, Multi-Shot, Summon Hawk, Bestial Wrath, Rapid Fire, Raptor Strike, Mongoose Bite, Immolation Trap, Explosive Trap
			utility = { 19577, 5116, 1499, 13809, 781, 5384, 19503, 20736, 19263, 3043, 3034 },   -- Intimidation, Concussive Shot, Freezing Trap, Frost Trap, Disengage, Feign Death, Scatter Shot, Distracting Shot, Deterrence, Scorpid Sting, Viper Sting
			bars = { 1130, 1978, 1324056 },   -- Hunter's Mark, Serpent Sting, Aspects
			buffs = { 19574, 19621, 3045, 415405 },   -- Bestial Wrath, Frenzy, Rapid Fire, Rapid Killing
		},
		mm = {
			essential = { 19434, 3044, 1978, 2643, 1310687, 3045, 1293241, 2973, 1495, 13795, 13813 },   -- Aimed Shot, Arcane Shot, Serpent Sting, Multi-Shot, Sniper Shot, Rapid Fire, Summon Hawk, Raptor Strike, Mongoose Bite, Immolation Trap, Explosive Trap
			utility = { 19503, 5116, 1499, 13809, 781, 5384, 20736, 19263, 3043, 3034 },   -- Scatter Shot, Concussive Shot, Freezing Trap, Frost Trap, Disengage, Feign Death, Distracting Shot, Deterrence, Scorpid Sting, Viper Sting
			bars = { 1130, 1978, 1324056 },   -- Hunter's Mark, Serpent Sting, Aspects
			buffs = { 3045, 415405, 1223987, 1310687 },   -- Rapid Fire, Rapid Killing, Rapid Recuperation, Sniper Shot
		},
		survival = {
			essential = { 2973, 1495, 1317257, 1978, 3044, 13795, 13813, 2643, 3045, 1293241 },   -- Raptor Strike, Mongoose Bite, Strider Kick, Serpent Sting, Arcane Shot, Immolation Trap, Explosive Trap, Multi-Shot, Rapid Fire, Summon Hawk
			utility = { 19306, 781, 19263, 1499, 13809, 5116, 5384, 19503, 19577, 20736, 3043, 3034 },   -- Counterattack, Disengage, Deterrence, Freezing Trap, Frost Trap, Concussive Shot, Feign Death, Scatter Shot, Intimidation, Distracting Shot, Scorpid Sting, Viper Sting
			bars = { 1130, 1978, 1324056 },   -- Hunter's Mark, Serpent Sting, Aspects
			buffs = { 1310532, 19263, 19306, 1317257, 3045 },   -- Expose Prey, Deterrence, Counterattack, Strider Kick, Rapid Fire
		},
		lonewolf = {
			essential = { 19434, 2643, 3044, 1978, 1310687, 3045, 1293241, 13813, 13795, 2973, 1495 },   -- Aimed Shot, Multi-Shot, Arcane Shot, Serpent Sting, Sniper Shot, Rapid Fire, Summon Hawk, Explosive Trap, Immolation Trap, Raptor Strike, Mongoose Bite
			utility = { 5384, 1499, 13809, 19503, 5116, 781, 20736, 19263, 3034, 3043 },   -- Feign Death, Freezing Trap, Frost Trap, Scatter Shot, Concussive Shot, Disengage, Distracting Shot, Deterrence, Viper Sting, Scorpid Sting
			bars = { 1130, 1978, 1324056, 1299346 },   -- Hunter's Mark, Serpent Sting, Aspects, Trueshot Aura
			buffs = { 3045, 415405, 1223987 },   -- Rapid Fire, Rapid Killing, Rapid Recuperation
		},
		bmpvp = {
			essential = { 3044, 1978, 2643, 19574, 3045, 1293241, 19434, 2973, 1495 },   -- Arcane Shot, Serpent Sting, Multi-Shot, Bestial Wrath, Rapid Fire, Summon Hawk, Aimed Shot, Raptor Strike, Mongoose Bite
			utility = { 19577, 19503, 5116, 1499, 13809, 3034, 3043, 781, 5384, 19263, 20736 },   -- Intimidation, Scatter Shot, Concussive Shot, Freezing Trap, Frost Trap, Viper Sting, Scorpid Sting, Disengage, Feign Death, Deterrence, Distracting Shot
			bars = { 1130, 1978, 1324056 },   -- Hunter's Mark, Serpent Sting, Aspects
			buffs = { 19574, 19621, 19263, 3045 },   -- Bestial Wrath, Frenzy, Deterrence, Rapid Fire
		},
	},
	MAGE = {
		frost = {
			essential = { 120, 2136, 11113, 12043, 12042, 11129 },   -- Cone of Cold, Fire Blast, Blast Wave, Presence of Mind, Arcane Power, Combustion
			utility = { 122, 11426, 1953, 2139, 11958, 12472, 12051, 1318827, 6143, 543 },   -- Frost Nova, Ice Barrier, Blink, Counterspell, Ice Block, Cold Snap, Evocation, Mana Gems, Frost Ward, Fire Ward
			bars = { 11426, 7302, 168, 6117, 1459 },   -- Ice Barrier, Ice Armor, Frost Armor, Mage Armor, Arcane Intellect
			buffs = { 400647, 11958, 1463, 6143, 543 },   -- Fingers of Frost, Ice Block, Mana Shield, Frost Ward, Fire Ward
		},
		fire = {
			essential = { 2136, 11113, 11129, 120, 12043, 12042 },   -- Fire Blast, Blast Wave, Combustion, Cone of Cold, Presence of Mind, Arcane Power
			utility = { 122, 1953, 2139, 11958, 12051, 1318827, 543, 6143, 11426, 12472 },   -- Frost Nova, Blink, Counterspell, Ice Block, Evocation, Mana Gems, Fire Ward, Frost Ward, Ice Barrier, Cold Snap
			bars = { 28682, 11119, 6117, 7302, 168, 1459 },   -- Combustion, Ignite, Mage Armor, Ice Armor, Frost Armor, Arcane Intellect
			buffs = { 400624, 11103, 11095, 543, 1463, 11958 },   -- Heating Up, Impact, Improved Scorch, Fire Ward, Mana Shield, Ice Block
		},
		arcane = {
			essential = { 12042, 12043, 2136, 120, 11113, 11129 },   -- Arcane Power, Presence of Mind, Fire Blast, Cone of Cold, Blast Wave, Combustion
			utility = { 122, 1953, 2139, 12051, 1318827, 11958, 11426, 12472, 543, 6143 },   -- Frost Nova, Blink, Counterspell, Evocation, Mana Gems, Ice Block, Ice Barrier, Cold Snap, Fire Ward, Frost Ward
			bars = { 400574, 6117, 7302, 168, 1459 },   -- Arcane Blast, Mage Armor, Ice Armor, Frost Armor, Arcane Intellect
			buffs = { 400588, 11213, 12042, 12043, 1463, 11958 },   -- Missile Barrage, Arcane Concentration, Arcane Power, Presence of Mind, Mana Shield, Ice Block
		},
		frostaoe = {
			essential = { 120, 2136, 11113, 12043, 12042, 11129 },   -- Cone of Cold, Fire Blast, Blast Wave, Presence of Mind, Arcane Power, Combustion
			utility = { 122, 11426, 1953, 12472, 11958, 12051, 1318827, 2139, 6143, 543 },   -- Frost Nova, Ice Barrier, Blink, Cold Snap, Ice Block, Evocation, Mana Gems, Counterspell, Frost Ward, Fire Ward
			bars = { 11426, 7302, 168, 6117, 1459 },   -- Ice Barrier, Ice Armor, Frost Armor, Mage Armor, Arcane Intellect
			buffs = { 11185, 400647, 11958, 1463, 6143 },   -- Improved Blizzard, Fingers of Frost, Ice Block, Mana Shield, Frost Ward
		},
		frostpvp = {
			essential = { 120, 2136, 11113, 12043, 12042, 11129 },   -- Cone of Cold, Fire Blast, Blast Wave, Presence of Mind, Arcane Power, Combustion
			utility = { 122, 2139, 1953, 11958, 11426, 12472, 12051, 1318827, 6143, 543 },   -- Frost Nova, Counterspell, Blink, Ice Block, Ice Barrier, Cold Snap, Evocation, Mana Gems, Frost Ward, Fire Ward
			bars = { 11426, 7302, 168, 6117, 118 },   -- Ice Barrier, Ice Armor, Frost Armor, Mage Armor, Polymorph
			buffs = { 400647, 11958, 1463, 6143, 543 },   -- Fingers of Frost, Ice Block, Mana Shield, Frost Ward, Fire Ward
		},
	},
	PALADIN = {
		ret = {
			essential = { 20271, 879, 24275, 26573, 2812, 1310994 },   -- Judgement, Exorcism, Hammer of Wrath, Consecration, Holy Wrath, Swift Judgement
			utility = { 853, 20066, 498, 1311015, 1044, 1310897, 1022, 633, 6940, 19752 },   -- Hammer of Justice, Repentance, Divine Protection, Templar's Bulwark, Blessing of Freedom, Voice of Truth, Blessing of Protection, Lay on Hands, Blessing of Sacrifice, Divine Intervention
			bars = { 1323522, 19740, 21183, 20186 },   -- Seals, Blessing of Might, Judgement of the Crusader, Judgement of Wisdom
			buffs = { 20049, 440668, 1310735, 498, 1311015 },   -- Vengeance, Vindication, Unsealed Wrath, Divine Protection, Templar's Bulwark
			hideCooldowns = { 1323522 },   -- Seals
			hideAuras = { 465, 7294, 19746, 19876, 19888, 19891 },   -- Devotion Aura, Retribution Aura, Concentration Aura, Shadow Resistance Aura, Frost Resistance Aura, Fire Resistance Aura
		},
		holy = {
			essential = { 1311606, 1310911, 20271, 26573, 879, 24275, 2812 },   -- Holy Shock, Light's Vigil, Judgement, Consecration, Exorcism, Hammer of Wrath, Holy Wrath
			utility = { 20216, 633, 1022, 498, 1311015, 1044, 6940, 853, 1310897, 19752 },   -- Divine Favor, Lay on Hands, Blessing of Protection, Divine Protection, Templar's Bulwark, Blessing of Freedom, Blessing of Sacrifice, Hammer of Justice, Voice of Truth, Divine Intervention
			bars = { 1323522, 19742, 20185, 20186 },   -- Seals, Blessing of Wisdom, Judgement of Light, Judgement of Wisdom
			buffs = { 426065, 20216, 1310909, 498 },   -- Infusion of Light, Divine Favor, Light's Vigil, Divine Protection
			hideCooldowns = { 1323522 },   -- Seals
			hideAuras = { 465, 7294, 19746, 19876, 19888, 19891 },   -- Devotion Aura, Retribution Aura, Concentration Aura, Shadow Resistance Aura, Frost Resistance Aura, Fire Resistance Aura
		},
		prot = {
			essential = { 20925, 26573, 20271, 879, 24275, 2812, 1310994 },   -- Holy Shield, Consecration, Judgement, Exorcism, Hammer of Wrath, Holy Wrath, Swift Judgement
			utility = { 1311015, 853, 498, 633, 1022, 1044, 1310897, 6940, 2878, 19752 },   -- Templar's Bulwark, Hammer of Justice, Divine Protection, Lay on Hands, Blessing of Protection, Blessing of Freedom, Voice of Truth, Blessing of Sacrifice, Turn Undead, Divine Intervention
			bars = { 25780, 20925, 1323522, 20217 },   -- Righteous Fury, Holy Shield, Seals, Blessing of Kings
			buffs = { 20128, 20177, 1311015, 498 },   -- Redoubt, Reckoning, Templar's Bulwark, Divine Protection
			hideCooldowns = { 1323522 },   -- Seals
			hideAuras = { 465, 7294, 19746, 19876, 19888, 19891 },   -- Devotion Aura, Retribution Aura, Concentration Aura, Shadow Resistance Aura, Frost Resistance Aura, Fire Resistance Aura
		},
		retpvp = {
			essential = { 20271, 879, 24275, 1311606, 26573, 1310994 },   -- Judgement, Exorcism, Hammer of Wrath, Holy Shock, Consecration, Swift Judgement
			utility = { 853, 20066, 1044, 498, 1022, 1311015, 633, 6940, 19752 },   -- Hammer of Justice, Repentance, Blessing of Freedom, Divine Protection, Blessing of Protection, Templar's Bulwark, Lay on Hands, Blessing of Sacrifice, Divine Intervention
			bars = { 1323522, 19740, 21183, 853 },   -- Seals, Blessing of Might, Judgement of the Crusader, Hammer of Justice
			buffs = { 20049, 1310735, 498, 1044, 440668 },   -- Vengeance, Unsealed Wrath, Divine Protection, Blessing of Freedom, Vindication
			hideCooldowns = { 1323522 },   -- Seals
			hideAuras = { 465, 7294, 19746, 19876, 19888, 19891 },   -- Devotion Aura, Retribution Aura, Concentration Aura, Shadow Resistance Aura, Frost Resistance Aura, Fire Resistance Aura
		},
	},
	PRIEST = {
		shadow = {
			essential = { 8092, 589, 2944, 1309595, 17, 14914, 402174, 401859 },   -- Mind Blast, Shadow Word: Pain, Devouring Plague, Shadow Word: Death, Power Word: Shield, Holy Fire, Penance, Prayer of Mending
			utility = { 8122, 15487, 586, 15286, 14751, 6346, 10060, 9484 },   -- Psychic Scream, Silence, Fade, Vampiric Embrace, Inner Focus, Fear Ward, Power Infusion, Shackle Undead
			bars = { 589, 2944, 15286, 588 },   -- Shadow Word: Pain, Devouring Plague, Vampiric Embrace, Inner Fire
			buffs = { 15473, 15270, 15326, 15257, 10901, 6788 },   -- Shadowform, Spirit Tap, Blackout, Shadow Weaving, Power Word: Shield, Weakened Soul
		},
		wand = {
			essential = { 17, 589, 8092, 402174, 14914, 1309595, 2944, 401859 },   -- Power Word: Shield, Shadow Word: Pain, Mind Blast, Penance, Holy Fire, Shadow Word: Death, Devouring Plague, Prayer of Mending
			utility = { 8122, 586, 14751, 10060, 6346, 15487, 15286, 9484 },   -- Psychic Scream, Fade, Inner Focus, Power Infusion, Fear Ward, Silence, Vampiric Embrace, Shackle Undead
			bars = { 589, 10901, 588, 139 },   -- Shadow Word: Pain, Power Word: Shield, Inner Fire, Renew
			buffs = { 15270, 6788, 14751, 10060, 431622 },   -- Spirit Tap, Weakened Soul, Inner Focus, Power Infusion, Divine Aegis
		},
		disc = {
			essential = { 17, 402174, 401859, 14914, 589, 8092, 1309595, 2944 },   -- Power Word: Shield, Penance, Prayer of Mending, Holy Fire, Shadow Word: Pain, Mind Blast, Shadow Word: Death, Devouring Plague
			utility = { 14751, 10060, 6346, 8122, 586, 15487, 15286, 9484 },   -- Inner Focus, Power Infusion, Fear Ward, Psychic Scream, Fade, Silence, Vampiric Embrace, Shackle Undead
			bars = { 10901, 139, 401859, 588 },   -- Power Word: Shield, Renew, Prayer of Mending, Inner Fire
			buffs = { 14751, 10060, 431622, 6788, 14531 },   -- Inner Focus, Power Infusion, Divine Aegis, Weakened Soul, Martyrdom
		},
		holy = {
			essential = { 401859, 17, 14914, 402174, 589, 8092, 1309595 },   -- Prayer of Mending, Power Word: Shield, Holy Fire, Penance, Shadow Word: Pain, Mind Blast, Shadow Word: Death
			utility = { 14751, 586, 8122, 6346, 10060, 15487, 15286, 9484 },   -- Inner Focus, Fade, Psychic Scream, Fear Ward, Power Infusion, Silence, Vampiric Embrace, Shackle Undead
			bars = { 139, 401859, 10901, 588 },   -- Renew, Prayer of Mending, Power Word: Shield, Inner Fire
			buffs = { 1284536, 14892, 20711, 14751, 27811 },   -- Holy Purpose, Inspiration, Spirit of Redemption, Inner Focus, Blessed Recovery
		},
		shadowpvp = {
			essential = { 8092, 589, 1309595, 2944, 17, 14914, 402174, 401859 },   -- Mind Blast, Shadow Word: Pain, Shadow Word: Death, Devouring Plague, Power Word: Shield, Holy Fire, Penance, Prayer of Mending
			utility = { 8122, 15487, 586, 6346, 15286, 14751, 10060, 9484 },   -- Psychic Scream, Silence, Fade, Fear Ward, Vampiric Embrace, Inner Focus, Power Infusion, Shackle Undead
			bars = { 589, 15286, 2944, 10901 },   -- Shadow Word: Pain, Vampiric Embrace, Devouring Plague, Power Word: Shield
			buffs = { 15473, 15326, 10901, 6788, 6346, 14531 },   -- Shadowform, Blackout, Power Word: Shield, Weakened Soul, Fear Ward, Martyrdom
		},
	},
	ROGUE = {
		combat = {
			essential = { 1329283, 5171, 14251, 13877, 13750, 14278, 1943, 8647, 14177, 14183, 14185 },   -- Shank, Slice and Dice, Riposte, Blade Flurry, Adrenaline Rush, Ghostly Strike, Rupture, Expose Armor, Cold Blood, Premeditation, Preparation
			utility = { 1766, 1776, 408, 2983, 5277, 1966, 11327, 2094, 1725 },   -- Kick, Gouge, Kidney Shot, Sprint, Evasion, Feint, Vanish, Blind, Distract
			bars = { 5171, 13877, 13750 },   -- Slice and Dice, Blade Flurry, Adrenaline Rush
			buffs = { 2983, 5277, 14251, 14144, 11327 },   -- Sprint, Evasion, Riposte, Remorseless Attacks, Vanish
		},
		assassination = {
			essential = { 1329283, 5171, 1943, 703, 14177, 8647, 14278, 14251, 13877, 13750, 14183, 14185 },   -- Shank, Slice and Dice, Rupture, Garrote, Cold Blood, Expose Armor, Ghostly Strike, Riposte, Blade Flurry, Adrenaline Rush, Premeditation, Preparation
			utility = { 1766, 1776, 408, 2983, 5277, 1966, 11327, 2094, 1725 },   -- Kick, Gouge, Kidney Shot, Sprint, Evasion, Feint, Vanish, Blind, Distract
			bars = { 5171, 1943, 703, 1310703 },   -- Slice and Dice, Rupture, Garrote, Venom
			buffs = { 1310703, 14177, 14144, 2983, 5277, 11327 },   -- Venom, Cold Blood, Remorseless Attacks, Sprint, Evasion, Vanish
		},
		subtlety = {
			essential = { 1329283, 1316709, 5171, 14278, 14183, 14185, 1943, 14177, 8647, 14251, 13877, 13750 },   -- Shank, Death Mark, Slice and Dice, Ghostly Strike, Premeditation, Preparation, Rupture, Cold Blood, Expose Armor, Riposte, Blade Flurry, Adrenaline Rush
			utility = { 1766, 1776, 408, 11327, 2983, 5277, 2094, 1966, 1725 },   -- Kick, Gouge, Kidney Shot, Vanish, Sprint, Evasion, Blind, Feint, Distract
			bars = { 5171, 1316709, 16511, 1943, 703 },   -- Slice and Dice, Death Mark, Hemorrhage, Rupture, Garrote
			buffs = { 1329326, 14144, 2983, 5277, 11327, 1784 },   -- Ghostly Strike, Remorseless Attacks, Sprint, Evasion, Vanish, Stealth
		},
		subpvp = {
			essential = { 14278, 1316709, 14183, 14185, 1329283, 5171, 1943, 14177, 8647, 14251 },   -- Ghostly Strike, Death Mark, Premeditation, Preparation, Shank, Slice and Dice, Rupture, Cold Blood, Expose Armor, Riposte
			utility = { 1766, 408, 1776, 2094, 11327, 2983, 5277, 1966, 1725 },   -- Kick, Kidney Shot, Gouge, Blind, Vanish, Sprint, Evasion, Feint, Distract
			bars = { 5171, 1316709, 16511, 408, 1833 },   -- Slice and Dice, Death Mark, Hemorrhage, Kidney Shot, Cheap Shot
			buffs = { 1329326, 2983, 5277, 11327, 14177, 1784 },   -- Ghostly Strike, Sprint, Evasion, Vanish, Cold Blood, Stealth
		},
	},
	SHAMAN = {
		enh = {
			essential = { 17364, 8042, 8050, 8056, 425336, 408341, 421, 3599, 8190, 16188, 408521 },   -- Stormstrike, Earth Shock, Flame Shock, Frost Shock, Rage of the Farseer, Fire Nova, Chain Lightning, Searing Totem, Magma Totem, Nature's Swiftness, Riptide
			utility = { 2484, 8177, 8143, 5730, 437009 },   -- Earthbind Totem, Grounding Totem, Tremor Totem, Stoneclaw Totem, Totemic Call
			bars = { 324, 8050 },   -- Lightning Shield, Flame Shock
			buffs = { 16256, 425336, 1223031, 16164, 2645 },   -- Flurry, Rage of the Farseer, Improved Stormstrike, Elemental Focus, Ghost Wolf
		},
		ele = {
			essential = { 8050, 421, 8042, 8056, 408341, 16188, 3599, 8190, 17364, 425336, 408521 },   -- Flame Shock, Chain Lightning, Earth Shock, Frost Shock, Fire Nova, Nature's Swiftness, Searing Totem, Magma Totem, Stormstrike, Rage of the Farseer, Riptide
			utility = { 2484, 8177, 8143, 5730, 437009 },   -- Earthbind Totem, Grounding Totem, Tremor Totem, Stoneclaw Totem, Totemic Call
			bars = { 8050, 324, 408510 },   -- Flame Shock, Lightning Shield, Water Shield
			buffs = { 16164, 1222988, 16188, 30160, 2645 },   -- Elemental Focus, Earthbound, Nature's Swiftness, Elemental Devastation, Ghost Wolf
		},
		resto = {
			essential = { 408521, 16188, 421, 8042, 8050, 8056, 408341, 3599, 17364, 425336 },   -- Riptide, Nature's Swiftness, Chain Lightning, Earth Shock, Flame Shock, Frost Shock, Fire Nova, Searing Totem, Stormstrike, Rage of the Farseer
			utility = { 16190, 437009, 2484, 8177, 8143 },   -- Mana Tide Totem, Totemic Call, Earthbind Totem, Grounding Totem, Tremor Totem
			bars = { 408510, 408521, 324 },   -- Water Shield, Riptide, Lightning Shield
			buffs = { 16188, 16176, 2645 },   -- Nature's Swiftness, Ancestral Healing, Ghost Wolf
		},
		tank = {
			essential = { 17364, 8042, 8050, 8056, 425336, 408341, 421, 3599, 8190, 16188 },   -- Stormstrike, Earth Shock, Flame Shock, Frost Shock, Rage of the Farseer, Fire Nova, Chain Lightning, Searing Totem, Magma Totem, Nature's Swiftness
			utility = { 2484, 8177, 8143, 5730, 437009 },   -- Earthbind Totem, Grounding Totem, Tremor Totem, Stoneclaw Totem, Totemic Call
			bars = { 324, 8050, 408510 },   -- Lightning Shield, Flame Shock, Water Shield
			buffs = { 16256, 1223031, 425336, 2645 },   -- Flurry, Improved Stormstrike, Rage of the Farseer, Ghost Wolf
		},
		pvp = {
			essential = { 17364, 8042, 8056, 8050, 425336, 408341, 16188, 421, 3599 },   -- Stormstrike, Earth Shock, Frost Shock, Flame Shock, Rage of the Farseer, Fire Nova, Nature's Swiftness, Chain Lightning, Searing Totem
			utility = { 2484, 8177, 8143, 5730, 437009 },   -- Earthbind Totem, Grounding Totem, Tremor Totem, Stoneclaw Totem, Totemic Call
			bars = { 324, 8050, 8056 },   -- Lightning Shield, Flame Shock, Frost Shock
			buffs = { 16188, 16256, 425336, 2645 },   -- Nature's Swiftness, Flurry, Rage of the Farseer, Ghost Wolf
		},
	},
	WARLOCK = {
		aff = {
			essential = { 172, 1319652, 18265, 348, 980, 603, 1225228, 1293817, 17877, 6353 },   -- Corruption, Curses, Siphon Life, Immolate, Bane of Agony, Bane of Doom, Bane of Havoc, Conflagrate, Shadowburn, Soul Fire
			utility = { 6789, 5484, 6229, 18288, 1326057, 693, 1122 },   -- Death Coil, Howl of Terror, Shadow Ward, Amplify Curse, Healthstone, Create Soulstone, Inferno
			bars = { 172, 980, 1319652, 18265, 348, 706, 687 },   -- Corruption, Bane of Agony, Curses, Siphon Life, Immolate, Demon Armor, Demon Skin
			buffs = { 18094, 437032, 18288, 6229, 1293816 },   -- Nightfall, Soul Harvest, Amplify Curse, Shadow Ward, Shadow
		},
		demo = {
			essential = { 172, 348, 1319652, 980, 603, 1225228, 6353, 18265, 1293817, 17877 },   -- Corruption, Immolate, Curses, Bane of Agony, Bane of Doom, Bane of Havoc, Soul Fire, Siphon Life, Conflagrate, Shadowburn
			utility = { 6789, 5484, 6229, 1326057, 693, 18288, 1122 },   -- Death Coil, Howl of Terror, Shadow Ward, Healthstone, Create Soulstone, Amplify Curse, Inferno
			bars = { 172, 348, 980, 1319652, 706, 687, 19028 },   -- Corruption, Immolate, Bane of Agony, Curses, Demon Armor, Demon Skin, Soul Link
			buffs = { 18788, 440870, 6229, 18094, 1293816, 426311 },   -- Demonic Sacrifice, Decimation, Shadow Ward, Nightfall, Shadow, Flame
		},
		destro = {
			essential = { 348, 1293817, 17877, 6353, 172, 1319652, 980, 603, 1225228, 18265 },   -- Immolate, Conflagrate, Shadowburn, Soul Fire, Corruption, Curses, Bane of Agony, Bane of Doom, Bane of Havoc, Siphon Life
			utility = { 6789, 5484, 6229, 1326057, 693, 18288, 1122 },   -- Death Coil, Howl of Terror, Shadow Ward, Healthstone, Create Soulstone, Amplify Curse, Inferno
			bars = { 348, 172, 980, 1319652, 706, 687 },   -- Immolate, Corruption, Bane of Agony, Curses, Demon Armor, Demon Skin
			buffs = { 440870, 17793, 18119, 426311, 1293816, 6229 },   -- Decimation, Improved Shadow Bolt, Aftermath, Flame, Shadow, Shadow Ward
		},
		demopvp = {
			essential = { 172, 1319652, 348, 980, 603, 1225228, 18265, 17877, 1293817, 6353 },   -- Corruption, Curses, Immolate, Bane of Agony, Bane of Doom, Bane of Havoc, Siphon Life, Shadowburn, Conflagrate, Soul Fire
			utility = { 6789, 5484, 6229, 18288, 1326057, 693, 1122 },   -- Death Coil, Howl of Terror, Shadow Ward, Amplify Curse, Healthstone, Create Soulstone, Inferno
			bars = { 172, 1319652, 980, 18265, 5782, 706, 19028 },   -- Corruption, Curses, Bane of Agony, Siphon Life, Fear, Demon Armor, Soul Link
			buffs = { 18094, 6229, 18288, 19028, 1293816 },   -- Nightfall, Shadow Ward, Amplify Curse, Soul Link, Shadow
		},
	},
	WARRIOR = {
		arms = {
			essential = { 12294, 7384, 5308, 1240193, 772, 78, 1680, 12292, 6343, 20569, 1310222, 12328 },   -- Mortal Strike, Overpower, Execute, Slam, Rend, Heroic Strike, Whirlwind, Sweeping Strikes, Thunder Clap, Cleave, Spearing Strike, Death Wish
			utility = { 100, 20252, 6552, 402927, 2687, 18499, 5246, 676, 20230, 1719, 871 },   -- Charge, Intercept, Pummel, Victory Rush, Bloodrage, Berserker Rage, Intimidating Shout, Disarm, Retaliation, Recklessness, Shield Wall
			bars = { 6673, 7386, 772, 12292 },   -- Battle Shout, Sunder Armor, Rend, Sweeping Strikes
			buffs = { 1289682, 12317, 12328, 1719, 20230 },   -- Bloodthrill, Enrage, Death Wish, Recklessness, Retaliation
			hideAuras = { 1319507 },   -- Stances
		},
		fury = {
			essential = { 23881, 1680, 5308, 78, 20569, 7384, 1240193, 12328, 1310222 },   -- Bloodthirst, Whirlwind, Execute, Heroic Strike, Cleave, Overpower, Slam, Death Wish, Spearing Strike
			utility = { 100, 20252, 6552, 18499, 2687, 402927, 5246, 676, 1719, 20230, 871 },   -- Charge, Intercept, Pummel, Berserker Rage, Bloodrage, Victory Rush, Intimidating Shout, Disarm, Recklessness, Retaliation, Shield Wall
			bars = { 6673, 7386, 12328 },   -- Battle Shout, Sunder Armor, Death Wish
			buffs = { 12319, 12317, 18499, 1719, 16487 },   -- Flurry, Enrage, Berserker Rage, Recklessness, Blood Craze
			hideAuras = { 1319507 },   -- Stances
		},
		protsolo = {
			essential = { 23922, 6572, 7386, 78, 6343, 5308, 7384, 772, 20569, 12809 },   -- Shield Slam, Revenge, Sunder Armor, Heroic Strike, Thunder Clap, Execute, Overpower, Rend, Cleave, Concussion Blow
			utility = { 2565, 72, 100, 355, 2687, 402927, 676, 694, 12975, 871, 1161 },   -- Shield Block, Shield Bash, Charge, Taunt, Bloodrage, Victory Rush, Disarm, Mocking Blow, Last Stand, Shield Wall, Challenging Shout
			bars = { 6673, 2565, 7386, 6343, 1160 },   -- Battle Shout, Shield Block, Sunder Armor, Thunder Clap, Demoralizing Shout
			buffs = { 12975, 871, 12317 },   -- Last Stand, Shield Wall, Enrage
			hideAuras = { 1319507 },   -- Stances
		},
		prot = {
			essential = { 23922, 6572, 7386, 78, 6343, 20569, 12809, 5308 },   -- Shield Slam, Revenge, Sunder Armor, Heroic Strike, Thunder Clap, Cleave, Concussion Blow, Execute
			utility = { 355, 2565, 72, 694, 100, 20252, 2687, 676, 1161, 12975, 871 },   -- Taunt, Shield Block, Shield Bash, Mocking Blow, Charge, Intercept, Bloodrage, Disarm, Challenging Shout, Last Stand, Shield Wall
			bars = { 7386, 6343, 1160, 6673, 2565 },   -- Sunder Armor, Thunder Clap, Demoralizing Shout, Battle Shout, Shield Block
			buffs = { 12975, 871, 12317 },   -- Last Stand, Shield Wall, Enrage
			hideAuras = { 1319507 },   -- Stances
		},
		armspvp = {
			essential = { 12294, 7384, 5308, 1240193, 772, 78, 1680, 12292, 12328 },   -- Mortal Strike, Overpower, Execute, Slam, Rend, Heroic Strike, Whirlwind, Sweeping Strikes, Death Wish
			utility = { 100, 20252, 6552, 72, 5246, 676, 18499, 2687, 402927, 20230, 1719, 871 },   -- Charge, Intercept, Pummel, Shield Bash, Intimidating Shout, Disarm, Berserker Rage, Bloodrage, Victory Rush, Retaliation, Recklessness, Shield Wall
			bars = { 6673, 772, 1715 },   -- Battle Shout, Rend, Hamstring
			buffs = { 18499, 12328, 1719, 20230, 1289682 },   -- Berserker Rage, Death Wish, Recklessness, Retaliation, Bloodthrill
			hideAuras = { 1319507 },   -- Stances
		},
	},
}
