CREATE TABLE IF NOT EXISTS `character_hybrid_spell` (
  `guid` INT UNSIGNED NOT NULL,
  `spell_id` INT UNSIGNED NOT NULL,
  `learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `character_hybrid_action` (
  `guid` INT UNSIGNED NOT NULL,
  `spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,
  `button` TINYINT UNSIGNED NOT NULL,
  `spell_id` INT UNSIGNED NOT NULL,
  PRIMARY KEY (`guid`, `spec`, `button`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `character_hybrid_spell_dependency` (
  `guid` INT UNSIGNED NOT NULL,
  `trigger_spell_id` INT UNSIGNED NOT NULL,
  `granted_spell_id` INT UNSIGNED NOT NULL,
  `learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`guid`, `trigger_spell_id`, `granted_spell_id`),
  KEY `idx_guid_granted_spell` (`guid`, `granted_spell_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
