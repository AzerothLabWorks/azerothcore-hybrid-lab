-- Add Tame Beast as the visible hybrid spell that unlocks the hunter pet toolkit.

REPLACE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`) VALUES
(1515, 4, 10, 3, 'Hunter - Pet', 8, 0);

SET @hybrid_hunter_pet_desc_sql := IF(
  EXISTS (
    SELECT 1
    FROM `information_schema`.`columns`
    WHERE `table_schema` = DATABASE()
      AND `table_name` = 'hybrid_spell_template'
      AND `column_name` = 'description'
  ),
  "UPDATE `hybrid_spell_template`
   SET `description` = 'Tame a beast to become your companion. Learning this hybrid spell also grants the hunter pet management toolkit.'
   WHERE `spell_id` = 1515",
  "SELECT 1"
);

PREPARE hybrid_hunter_pet_desc_stmt FROM @hybrid_hunter_pet_desc_sql;
EXECUTE hybrid_hunter_pet_desc_stmt;
DEALLOCATE PREPARE hybrid_hunter_pet_desc_stmt;
