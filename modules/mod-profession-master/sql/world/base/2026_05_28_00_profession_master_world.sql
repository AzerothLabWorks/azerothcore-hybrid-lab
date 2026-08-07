SET @ENTRY := 190020;
SET @PROFESSION_BEACON := 3500;
SET @VENDOR_ENTRY := 190021;
SET @VENDOR_BEACON := 3501;
SET @VENDOR_SOURCE := 12959;

DELETE FROM `creature_template` WHERE `entry` = @ENTRY;
DELETE FROM `creature_template` WHERE `entry` = @VENDOR_ENTRY;
DELETE FROM `creature_template_model` WHERE `CreatureID` = @ENTRY;
DELETE FROM `creature_template_model` WHERE `CreatureID` = @VENDOR_ENTRY;
DELETE FROM `npc_vendor` WHERE `entry` = @VENDOR_ENTRY;
DELETE FROM `item_template` WHERE `entry` = @PROFESSION_BEACON;
DELETE FROM `item_template` WHERE `entry` = @VENDOR_BEACON;

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

CREATE TEMPORARY TABLE `tmp_profession_vendor_template`
SELECT *
FROM `creature_template`
WHERE `entry` = @VENDOR_SOURCE
LIMIT 1;

UPDATE `tmp_profession_vendor_template`
SET
    `entry` = @VENDOR_ENTRY,
    `name` = 'Mira Packwhistle',
    `subname` = 'Traveling Vendor',
    `npcflag` = 129,
    `gossip_menu_id` = 0,
    `faction` = 35,
    `rank` = 0,
    `unit_flags` = 0,
    `unit_flags2` = 0,
    `dynamicflags` = 0,
    `type_flags` = 0,
    `flags_extra` = 0,
    `AIName` = '',
    `ScriptName` = 'npc_profession_vendor';

INSERT INTO `creature_template`
SELECT *
FROM `tmp_profession_vendor_template`;

DROP TEMPORARY TABLE `tmp_profession_vendor_template`;

INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
SELECT @VENDOR_ENTRY, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`
FROM `creature_template_model`
WHERE `CreatureID` = @VENDOR_SOURCE;

INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`)
SELECT @VENDOR_ENTRY, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `VerifiedBuild`
FROM `npc_vendor`
WHERE `entry` = @VENDOR_SOURCE;

CREATE TEMPORARY TABLE `tmp_profession_beacon_item`
SELECT *
FROM `item_template`
WHERE `entry` = 6948
LIMIT 1;

UPDATE `tmp_profession_beacon_item`
SET
    `entry` = @PROFESSION_BEACON,
    `class` = 15,
    `subclass` = 0,
    `name` = 'Profession Master Beacon',
    `displayid` = 1046,
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
    `description` = 'Summons the Profession Master to your location.',
    `ScriptName` = 'item_profession_master_beacon',
    `VerifiedBuild` = 0;

INSERT INTO `item_template`
SELECT *
FROM `tmp_profession_beacon_item`;

DROP TEMPORARY TABLE `tmp_profession_beacon_item`;

CREATE TEMPORARY TABLE `tmp_profession_vendor_beacon_item`
SELECT *
FROM `item_template`
WHERE `entry` = 6948
LIMIT 1;

UPDATE `tmp_profession_vendor_beacon_item`
SET
    `entry` = @VENDOR_BEACON,
    `class` = 15,
    `subclass` = 0,
    `name` = 'Traveling Vendor Beacon',
    `displayid` = 1046,
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
    `description` = 'Summons a traveling vendor to your location.',
    `ScriptName` = 'item_profession_vendor_beacon',
    `VerifiedBuild` = 0;

INSERT INTO `item_template`
SELECT *
FROM `tmp_profession_vendor_beacon_item`;

DROP TEMPORARY TABLE `tmp_profession_vendor_beacon_item`;
