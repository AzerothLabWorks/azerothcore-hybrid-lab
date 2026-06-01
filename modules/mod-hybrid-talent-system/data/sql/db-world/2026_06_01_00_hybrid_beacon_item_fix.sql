SET @HYBRID_BEACON := 65010;

DELETE FROM `item_template` WHERE `entry` = @HYBRID_BEACON;

CREATE TEMPORARY TABLE `tmp_hybrid_beacon_item_fix`
SELECT *
FROM `item_template`
WHERE `entry` = 6948
LIMIT 1;

UPDATE `tmp_hybrid_beacon_item_fix`
SET
    `entry` = @HYBRID_BEACON,
    `name` = 'Hybrid Talent Beacon',
    `displayid` = 6418,
    `Quality` = 3,
    `Flags` = 64,
    `FlagsExtra` = 0,
    `ItemLevel` = 1,
    `RequiredLevel` = 1,
    `maxcount` = 1,
    `stackable` = 1,
    `spellid_1` = 483,
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
FROM `tmp_hybrid_beacon_item_fix`;

DROP TEMPORARY TABLE `tmp_hybrid_beacon_item_fix`;
