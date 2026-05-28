SET @ENTRY := 190020;

DELETE FROM `creature_template` WHERE `entry` = @ENTRY;

CREATE TEMPORARY TABLE `tmp_profession_master_template`
SELECT *
FROM `creature_template`
WHERE `entry` IN (190010, 4968, 68)
ORDER BY FIELD(`entry`, 190010, 4968, 68)
LIMIT 1;

UPDATE `tmp_profession_master_template`
SET
    `entry` = @ENTRY,
    `name` = 'Artisan Nexus-Weaver',
    `subname` = 'Profession Master',
    `npcflag` = 1,
    `gossip_menu_id` = 0,
    `faction` = 35,
    `rank` = 0,
    `unit_flags` = 0,
    `unit_flags2` = 0,
    `dynamicflags` = 0,
    `type_flags` = 0,
    `flags_extra` = 0,
    `AIName` = '',
    `ScriptName` = 'npc_profession_master';

INSERT INTO `creature_template`
SELECT *
FROM `tmp_profession_master_template`;

DROP TEMPORARY TABLE `tmp_profession_master_template`;
