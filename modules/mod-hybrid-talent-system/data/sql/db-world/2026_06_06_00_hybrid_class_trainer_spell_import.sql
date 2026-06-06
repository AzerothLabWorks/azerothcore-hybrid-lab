-- Fill remaining hybrid spell gaps from AzerothCore's class trainer data.
-- This imports missing first-rank class trainer spells while preserving any
-- curated rows already present in hybrid_spell_template.

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
