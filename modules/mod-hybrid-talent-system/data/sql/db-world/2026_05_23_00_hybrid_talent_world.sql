CREATE TABLE IF NOT EXISTS `hybrid_spell_template` (
  `spell_id` INT UNSIGNED NOT NULL,
  `class_mask` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Classes that may not learn this spell. Use source class mask to keep spells cross-class only.',
  `required_level` TINYINT UNSIGNED NOT NULL DEFAULT 10,
  `cost` SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  `category` VARCHAR(64) NOT NULL DEFAULT '',
  `role_mask` TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Reserved: 1 damage, 2 healing, 4 tank, 8 utility, 16 passive.',
  `flags` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Reserved for future restrictions.',
  PRIMARY KEY (`spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hybrid_synergy_template` (
  `synergy_id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `required_spell_1` INT UNSIGNED NOT NULL,
  `required_spell_2` INT UNSIGNED NOT NULL,
  `reward_spell` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`synergy_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Class masks:
-- Warrior 1, Paladin 2, Hunter 4, Rogue 8, Priest 16, Death Knight 32,
-- Shaman 64, Mage 128, Warlock 256, Druid 1024.
--
-- This first pool intentionally uses mostly low-rank, low-risk spells. Expand it
-- slowly after testing each spell in real combat, with playerbots, and after relog.

REPLACE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`) VALUES
-- Warrior
(78,    1,    10, 1, 'Warrior - Strike',       1, 0), -- Heroic Strike
(100,   1,    10, 2, 'Warrior - Mobility',     8, 0), -- Charge
(772,   1,    10, 1, 'Warrior - Bleed',        1, 0), -- Rend
(6673,  1,    10, 2, 'Warrior - Buff',         8, 0), -- Battle Shout

-- Paladin
(633,   2,    10, 4, 'Paladin - Cooldown',    10, 0), -- Lay on Hands
(853,   2,    10, 3, 'Paladin - Control',      8, 0), -- Hammer of Justice
(19740, 2,    10, 2, 'Paladin - Buff',         8, 0), -- Blessing of Might
(20271, 2,    10, 1, 'Paladin - Strike',       1, 0), -- Judgement of Light

-- Hunter
(2973,  4,    10, 1, 'Hunter - Shot',          1, 0), -- Raptor Strike
(3044,  4,    10, 2, 'Hunter - Shot',          1, 0), -- Arcane Shot
(13163, 4,    10, 2, 'Hunter - Aspect',        8, 0), -- Aspect of the Monkey
(1494,  4,    10, 1, 'Hunter - Utility',       8, 0), -- Track Beasts

-- Rogue
(1752,  8,    10, 1, 'Rogue - Strike',         1, 0), -- Sinister Strike
(2098,  8,    10, 2, 'Rogue - Finisher',       1, 0), -- Eviscerate
(5277,  8,    10, 3, 'Rogue - Defensive',      4, 0), -- Evasion
(1784,  8,    10, 3, 'Rogue - Stealth',        8, 0), -- Stealth

-- Priest
(17,    16,   10, 2, 'Priest - Defensive',     6, 0), -- Power Word: Shield
(139,   16,   10, 1, 'Priest - Heal',          2, 0), -- Renew
(589,   16,   10, 1, 'Priest - Shadow',        1, 0), -- Shadow Word: Pain
(1243,  16,   10, 2, 'Priest - Buff',          8, 0), -- Power Word: Fortitude

-- Shaman
(331,   64,   10, 1, 'Shaman - Heal',          2, 0), -- Healing Wave
(403,   64,   10, 1, 'Shaman - Nature',        1, 0), -- Lightning Bolt
(8042,  64,   10, 2, 'Shaman - Shock',         1, 0), -- Earth Shock
(8075,  64,   10, 2, 'Shaman - Buff',          8, 0), -- Strength of Earth Totem

-- Mage
(116,   128,  10, 1, 'Mage - Frost',           1, 0), -- Frostbolt
(133,   128,  10, 1, 'Mage - Fire',            1, 0), -- Fireball
(1459,  128,  10, 2, 'Mage - Buff',            8, 0), -- Arcane Intellect
(2136,  128,  10, 2, 'Mage - Fire',            1, 0), -- Fire Blast

-- Warlock
(172,   256,  10, 1, 'Warlock - Shadow',       1, 0), -- Corruption
(348,   256,  10, 1, 'Warlock - Fire',         1, 0), -- Immolate
(1454,  256,  10, 2, 'Warlock - Utility',      8, 0), -- Life Tap
(5782,  256,  10, 3, 'Warlock - Control',      8, 0), -- Fear

-- Druid
(774,   1024, 10, 1, 'Druid - Heal',           2, 0), -- Rejuvenation
(8921,  1024, 10, 1, 'Druid - Arcane',         1, 0), -- Moonfire
(467,   1024, 10, 2, 'Druid - Buff',           8, 0), -- Thorns
(5176,  1024, 10, 1, 'Druid - Nature',         1, 0); -- Wrath

-- Synergy rewards should use custom passive spell IDs that exist in your DBC.
-- Leave this table empty until those custom spells are created.
