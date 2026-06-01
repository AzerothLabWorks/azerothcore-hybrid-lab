SET @ENTRY := 190020;
SET @PROFESSION_BEACON := 900020;

DELETE FROM `creature_template` WHERE `entry` = @ENTRY;
DELETE FROM `creature_template_model` WHERE `CreatureID` = @ENTRY;
DELETE FROM `item_template` WHERE `entry` = @PROFESSION_BEACON;

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

SET @MODEL_SOURCE := COALESCE(
    (SELECT `CreatureID` FROM `creature_template_model` WHERE `CreatureID` = 190010 LIMIT 1),
    (SELECT `CreatureID` FROM `creature_template_model` WHERE `CreatureID` = 4968 LIMIT 1),
    (SELECT `CreatureID` FROM `creature_template_model` WHERE `CreatureID` = 68 LIMIT 1)
);

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @ENTRY, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model`
WHERE `CreatureID` = @MODEL_SOURCE;

CREATE TEMPORARY TABLE `tmp_profession_beacon_item`
SELECT *
FROM `item_template`
WHERE `entry` = 6948
LIMIT 1;

UPDATE `tmp_profession_beacon_item`
SET
    `entry` = @PROFESSION_BEACON,
    `name` = 'Profession Master Beacon',
    `Quality` = 3,
    `RequiredLevel` = 1,
    `maxcount` = 1,
    `stackable` = 1,
    `spellcooldown_1` = 60000,
    `description` = 'Summons the Profession Master to your location.',
    `ScriptName` = 'item_profession_master_beacon',
    `VerifiedBuild` = 0;

INSERT INTO `item_template`
SELECT *
FROM `tmp_profession_beacon_item`;

DROP TEMPORARY TABLE `tmp_profession_beacon_item`;
