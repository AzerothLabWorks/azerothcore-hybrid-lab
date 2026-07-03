-- Remove already-granted legacy Hybrid Talent Beacon items from character inventories.

SET @HYBRID_BEACON := 1915;

DELETE ci
FROM `character_inventory` ci
JOIN `item_instance` ii ON ii.`guid` = ci.`item`
WHERE ii.`itemEntry` = @HYBRID_BEACON;

DELETE FROM `item_instance`
WHERE `itemEntry` = @HYBRID_BEACON;
