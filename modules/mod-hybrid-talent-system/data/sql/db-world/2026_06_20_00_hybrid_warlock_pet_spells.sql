-- Add normal controllable warlock demon summons to the hybrid spell trainer.

REPLACE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`) VALUES
(688, 256, 10, 3, 'Warlock - Summon', 8, 0),
(697, 256, 10, 3, 'Warlock - Summon', 8, 0),
(712, 256, 20, 3, 'Warlock - Summon', 8, 0),
(691, 256, 30, 3, 'Warlock - Summon', 8, 0);

SET @hybrid_warlock_pet_desc_sql := IF(
  EXISTS (
    SELECT 1
    FROM `information_schema`.`columns`
    WHERE `table_schema` = DATABASE()
      AND `table_name` = 'hybrid_spell_template'
      AND `column_name` = 'description'
  ),
  "UPDATE `hybrid_spell_template`
   SET `description` = CASE `spell_id`
     WHEN 688 THEN 'Summons an imp minion.'
     WHEN 697 THEN 'Summons a voidwalker minion.'
     WHEN 712 THEN 'Summons a succubus minion.'
     WHEN 691 THEN 'Summons a felhunter minion.'
     ELSE `description`
   END
   WHERE `spell_id` IN (688, 697, 712, 691)",
  "SELECT 1"
);

PREPARE hybrid_warlock_pet_desc_stmt FROM @hybrid_warlock_pet_desc_sql;
EXECUTE hybrid_warlock_pet_desc_stmt;
DEALLOCATE PREPARE hybrid_warlock_pet_desc_stmt;
