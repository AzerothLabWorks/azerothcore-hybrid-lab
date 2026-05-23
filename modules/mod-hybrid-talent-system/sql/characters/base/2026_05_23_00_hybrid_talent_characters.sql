DROP TABLE IF EXISTS `character_hybrid_spell`;
CREATE TABLE `character_hybrid_spell` (
  `guid` INT UNSIGNED NOT NULL,
  `spell_id` INT UNSIGNED NOT NULL,
  `learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

