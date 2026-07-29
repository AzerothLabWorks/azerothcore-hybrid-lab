-- Support Blood Elf warriors in the QA any-race/any-class lane.
--
-- WotLK never shipped this race/class combination, so the stock
-- playercreateinfo tables do not place Arcane Torrent for warriors.

DELETE FROM `playercreateinfo_spell_custom` WHERE `racemask` = 512 AND `classmask` = 1 AND `Spell` = 28730;
INSERT INTO `playercreateinfo_spell_custom` (`racemask`, `classmask`, `Spell`, `Note`) VALUES
(512, 1, 28730, 'Arcane Torrent - Blood Elf Warrior');

DELETE FROM `playercreateinfo_action` WHERE `race` = 10 AND `class` = 1 AND `action` = 28730;
INSERT INTO `playercreateinfo_action` (`race`, `class`, `button`, `action`, `type`) VALUES
(10, 1, 3, 28730, 0);
