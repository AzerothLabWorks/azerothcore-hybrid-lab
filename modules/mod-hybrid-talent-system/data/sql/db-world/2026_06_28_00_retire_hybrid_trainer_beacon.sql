-- Retire the legacy Hybrid Talent Master NPC and beacon item.
-- The HybridTalentUI addon and /hybridui command path are now the supported interface.

SET @HYBRID_TRAINER := 190010;
SET @HYBRID_BEACON := 1915;

DELETE FROM `creature`
WHERE `id` = @HYBRID_TRAINER;

UPDATE `creature_template`
SET
  `npcflag` = 0,
  `gossip_menu_id` = 0,
  `AIName` = '',
  `ScriptName` = ''
WHERE `entry` = @HYBRID_TRAINER;

DELETE FROM `item_template`
WHERE `entry` = @HYBRID_BEACON;
