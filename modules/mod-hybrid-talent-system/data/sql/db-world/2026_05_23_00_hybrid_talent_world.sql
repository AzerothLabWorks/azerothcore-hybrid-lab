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

SET @HYBRID_BEACON := 1915;

DELETE FROM `item_template` WHERE `entry` = @HYBRID_BEACON;

CREATE TEMPORARY TABLE `tmp_hybrid_beacon_item`
SELECT *
FROM `item_template`
WHERE `entry` = 6948
LIMIT 1;

UPDATE `tmp_hybrid_beacon_item`
SET
    `entry` = @HYBRID_BEACON,
    `class` = 15,
    `subclass` = 0,
    `name` = 'Hybrid Talent Beacon',
    `displayid` = 1183,
    `Quality` = 3,
    `Flags` = 64,
    `FlagsExtra` = 0,
    `ItemLevel` = 1,
    `RequiredLevel` = 1,
    `InventoryType` = 0,
    `maxcount` = 1,
    `stackable` = 1,
    `spellid_1` = 439,
    `spelltrigger_1` = 0,
    `spellcharges_1` = 0,
    `spellppmRate_1` = 0,
    `spellcooldown_1` = 60000,
    `spellcategory_1` = 0,
    `spellcategorycooldown_1` = -1,
    `spellid_2` = 0,
    `spelltrigger_2` = 0,
    `spellcharges_2` = 0,
    `spellppmRate_2` = 0,
    `spellcooldown_2` = -1,
    `spellcategory_2` = 0,
    `spellcategorycooldown_2` = -1,
    `spellid_3` = 0,
    `spelltrigger_3` = 0,
    `spellcharges_3` = 0,
    `spellppmRate_3` = 0,
    `spellcooldown_3` = -1,
    `spellcategory_3` = 0,
    `spellcategorycooldown_3` = -1,
    `spellid_4` = 0,
    `spelltrigger_4` = 0,
    `spellcharges_4` = 0,
    `spellppmRate_4` = 0,
    `spellcooldown_4` = -1,
    `spellcategory_4` = 0,
    `spellcategorycooldown_4` = -1,
    `spellid_5` = 0,
    `spelltrigger_5` = 0,
    `spellcharges_5` = 0,
    `spellppmRate_5` = 0,
    `spellcooldown_5` = -1,
    `spellcategory_5` = 0,
    `spellcategorycooldown_5` = -1,
    `bonding` = 1,
    `description` = 'Summons the Hybrid Talent Master to your location.',
    `ScriptName` = 'item_hybrid_talent_beacon',
    `VerifiedBuild` = 0;

INSERT INTO `item_template`
SELECT *
FROM `tmp_hybrid_beacon_item`;

DROP TEMPORARY TABLE `tmp_hybrid_beacon_item`;

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
(1715,  1,    10, 1, 'Warrior - Control',      8, 0), -- Hamstring
(72,    1,    12, 2, 'Warrior - Interrupt',    8, 0), -- Shield Bash
(7384,  1,    12, 1, 'Warrior - Strike',       1, 0), -- Overpower
(6343,  1,    10, 1, 'Warrior - AoE',          1, 0), -- Thunder Clap

-- Paladin
(633,   2,    10, 4, 'Paladin - Cooldown',    10, 0), -- Lay on Hands
(853,   2,    10, 3, 'Paladin - Control',      8, 0), -- Hammer of Justice
(465,   2,    10, 2, 'Paladin - Aura',         8, 0), -- Devotion Aura
(635,   2,    10, 1, 'Paladin - Heal',         2, 0), -- Holy Light
(19740, 2,    10, 2, 'Paladin - Buff',         8, 0), -- Blessing of Might
(20271, 2,    10, 1, 'Paladin - Judgement',    1, 0), -- Judgement of Light
(53408, 2,    12, 1, 'Paladin - Judgement',    8, 0), -- Judgement of Wisdom
(20154, 2,    16, 1, 'Paladin - Seal',         1, 0), -- Seal of Righteousness
(53407, 2,    28, 1, 'Paladin - Judgement',    8, 0), -- Judgement of Justice
(498,   2,    10, 2, 'Paladin - Defensive',    4, 0), -- Divine Protection
(1044,  2,    18, 2, 'Paladin - Utility',      8, 0), -- Hand of Freedom
(4987,  2,    18, 2, 'Paladin - Cleanse',      8, 0), -- Cleanse

-- Hunter
(2973,  4,    10, 1, 'Hunter - Shot',          1, 0), -- Raptor Strike
(3044,  4,    10, 2, 'Hunter - Shot',          1, 0), -- Arcane Shot
(13163, 4,    10, 2, 'Hunter - Aspect',        8, 0), -- Aspect of the Monkey
(1494,  4,    10, 1, 'Hunter - Utility',       8, 0), -- Track Beasts
(5116,  4,    10, 1, 'Hunter - Control',       8, 0), -- Concussive Shot
(13165, 4,    10, 2, 'Hunter - Aspect',        8, 0), -- Aspect of the Hawk
(781,   4,    14, 2, 'Hunter - Mobility',      8, 0), -- Disengage

-- Rogue
(1752,  8,    10, 1, 'Rogue - Strike',         1, 0), -- Sinister Strike
(2098,  8,    10, 2, 'Rogue - Finisher',       1, 0), -- Eviscerate
(1766,  8,    12, 2, 'Rogue - Interrupt',      8, 0), -- Kick
(5277,  8,    10, 3, 'Rogue - Defensive',      4, 0), -- Evasion
(1784,  8,    10, 3, 'Rogue - Stealth',        8, 0), -- Stealth
(2842,  8,    10, 1, 'Rogue - Poison',         8, 0), -- Poisons
(8681,  8,    10, 1, 'Rogue - Poison',         1, 0), -- Instant Poison
(2823,  8,    20, 1, 'Rogue - Poison',         1, 0), -- Deadly Poison
(3408,  8,    20, 1, 'Rogue - Poison',         8, 0), -- Crippling Poison
(5761,  8,    24, 1, 'Rogue - Poison',         8, 0), -- Mind-numbing Poison
(13218, 8,    32, 1, 'Rogue - Poison',         1, 0), -- Wound Poison
(26786, 8,    68, 1, 'Rogue - Poison',         8, 0), -- Anesthetic Poison

-- Priest
(17,    16,   10, 2, 'Priest - Defensive',     6, 0), -- Power Word: Shield
(139,   16,   10, 1, 'Priest - Heal',          2, 0), -- Renew
(589,   16,   10, 1, 'Priest - Shadow',        1, 0), -- Shadow Word: Pain
(1243,  16,   10, 2, 'Priest - Buff',          8, 0), -- Power Word: Fortitude
(527,   16,   18, 2, 'Priest - Dispel',        8, 0), -- Dispel Magic
(586,   16,   22, 2, 'Priest - Utility',       8, 0), -- Fade
(8092,  16,   10, 1, 'Priest - Shadow',        1, 0), -- Mind Blast

-- Death Knight
(45477, 32,   10, 1, 'Death Knight - Frost',   1, 0), -- Icy Touch
(45462, 32,   10, 1, 'Death Knight - Disease', 1, 0), -- Plague Strike
(47541, 32,   10, 2, 'Death Knight - Runic',   1, 0), -- Death Coil
(49576, 32,   10, 3, 'Death Knight - Grip',    8, 0), -- Death Grip
(48266, 32,   10, 2, 'Death Knight - Presence',4, 0), -- Blood Presence
(48707, 32,   10, 3, 'Death Knight - Defensive',4,0), -- Anti-Magic Shell
(47528, 32,   55, 2, 'Death Knight - Interrupt',8, 0), -- Mind Freeze
(47476, 32,   59, 3, 'Death Knight - Silence', 8, 0), -- Strangulate

-- Shaman
(331,   64,   10, 1, 'Shaman - Heal',          2, 0), -- Healing Wave
(403,   64,   10, 1, 'Shaman - Nature',        1, 0), -- Lightning Bolt
(8017,  64,   10, 1, 'Shaman - Weapon',        1, 0), -- Rockbiter Weapon
(8024,  64,   10, 1, 'Shaman - Weapon',        1, 0), -- Flametongue Weapon
(8042,  64,   10, 2, 'Shaman - Shock',         1, 0), -- Earth Shock
(8075,  64,   10, 2, 'Shaman - Buff',          8, 0), -- Strength of Earth Totem
(324,   64,   10, 1, 'Shaman - Shield',        4, 0), -- Lightning Shield
(546,   64,   16, 2, 'Shaman - Utility',       8, 0), -- Ghost Wolf
(57994, 64,   16, 2, 'Shaman - Interrupt',     8, 0), -- Wind Shear
(8033,  64,   20, 1, 'Shaman - Weapon',        1, 0), -- Frostbrand Weapon
(8232,  64,   30, 1, 'Shaman - Weapon',        1, 0), -- Windfury Weapon
(370,   64,   12, 2, 'Shaman - Purge',         8, 0), -- Purge
(526,   64,   16, 2, 'Shaman - Cleanse',       8, 0), -- Cure Toxins

-- Mage
(116,   128,  10, 1, 'Mage - Frost',           1, 0), -- Frostbolt
(133,   128,  10, 1, 'Mage - Fire',            1, 0), -- Fireball
(1459,  128,  10, 2, 'Mage - Buff',            8, 0), -- Arcane Intellect
(168,   128,  10, 2, 'Mage - Armor',           4, 0), -- Frost Armor
(2136,  128,  10, 2, 'Mage - Fire',            1, 0), -- Fire Blast
(130,   128,  10, 1, 'Mage - Utility',         8, 0), -- Slow Fall
(475,   128,  18, 2, 'Mage - Cleanse',         8, 0), -- Remove Curse
(1953,  128,  20, 2, 'Mage - Mobility',        8, 0), -- Blink
(2139,  128,  24, 2, 'Mage - Interrupt',       8, 0), -- Counterspell
(122,   128,  10, 2, 'Mage - Control',         8, 0), -- Frost Nova
(7302,  128,  30, 2, 'Mage - Armor',           4, 0), -- Ice Armor
(6117,  128,  34, 2, 'Mage - Armor',           4, 0), -- Mage Armor
(30482, 128,  62, 2, 'Mage - Armor',           4, 0), -- Molten Armor

-- Warlock
(172,   256,  10, 1, 'Warlock - Shadow',       1, 0), -- Corruption
(348,   256,  10, 1, 'Warlock - Fire',         1, 0), -- Immolate
(1454,  256,  10, 2, 'Warlock - Utility',      8, 0), -- Life Tap
(687,   256,  10, 2, 'Warlock - Armor',        4, 0), -- Demon Skin
(5782,  256,  10, 3, 'Warlock - Control',      8, 0), -- Fear
(702,   256,  10, 1, 'Warlock - Curse',        1, 0), -- Curse of Weakness
(688,   256,  10, 3, 'Warlock - Summon',       8, 0), -- Summon Imp
(5697,  256,  16, 2, 'Warlock - Utility',      8, 0), -- Unending Breath
(706,   256,  20, 2, 'Warlock - Armor',        4, 0), -- Demon Armor
(28176, 256,  62, 2, 'Warlock - Armor',        4, 0), -- Fel Armor

-- Druid
(774,   1024, 10, 1, 'Druid - Heal',           2, 0), -- Rejuvenation
(8921,  1024, 10, 1, 'Druid - Arcane',         1, 0), -- Moonfire
(467,   1024, 10, 2, 'Druid - Buff',           8, 0), -- Thorns
(5176,  1024, 10, 1, 'Druid - Nature',         1, 0), -- Wrath
(8946,  1024, 14, 2, 'Druid - Cleanse',        8, 0), -- Cure Poison
(2782,  1024, 24, 2, 'Druid - Cleanse',        8, 0), -- Remove Curse
(5215,  1024, 20, 3, 'Druid - Stealth',        8, 0); -- Prowl

-- Fill remaining class-trainer spells from the AzerothCore trainer data.
-- Curated rows above stay untouched; this only inserts missing first-rank
-- trainer spells so the module does not need a manual row for every gap.
INSERT IGNORE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`)
SELECT
  COALESCE(sr.`first_spell_id`, ts.`SpellId`) AS `spell_id`,
  class_trainers.`class_mask`,
  GREATEST(MIN(CASE WHEN ts.`ReqLevel` > 0 THEN ts.`ReqLevel` ELSE 1 END), 1) AS `required_level`,
  2 AS `cost`,
  CONCAT(class_trainers.`class_name`, ' - Trainer') AS `category`,
  8 AS `role_mask`,
  0 AS `flags`
FROM `trainer_spell` ts
JOIN `trainer` t ON t.`Id` = ts.`TrainerId` AND t.`Type` = 0
JOIN (
  SELECT 1 AS `trainer_id`, 1 AS `class_mask`, 'Warrior' AS `class_name`
  UNION ALL SELECT 3, 2, 'Paladin'
  UNION ALL SELECT 7, 4, 'Hunter'
  UNION ALL SELECT 9, 8, 'Rogue'
  UNION ALL SELECT 11, 16, 'Priest'
  UNION ALL SELECT 13, 32, 'Death Knight'
  UNION ALL SELECT 14, 64, 'Shaman'
  UNION ALL SELECT 16, 128, 'Mage'
  UNION ALL SELECT 31, 256, 'Warlock'
  UNION ALL SELECT 33, 1024, 'Druid'
) class_trainers ON class_trainers.`trainer_id` = ts.`TrainerId`
LEFT JOIN `spell_ranks` sr ON sr.`spell_id` = ts.`SpellId`
WHERE ts.`SpellId` > 0
  AND ts.`ReqSkillLine` = 0
GROUP BY COALESCE(sr.`first_spell_id`, ts.`SpellId`), class_trainers.`class_mask`, class_trainers.`class_name`;

-- Synergy rewards should use custom passive spell IDs that exist in your DBC.
-- Leave this table empty until those custom spells are created.
