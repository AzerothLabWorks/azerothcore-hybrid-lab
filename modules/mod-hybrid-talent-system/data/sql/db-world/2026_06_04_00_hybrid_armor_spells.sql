-- Expand the hybrid spell MVP with Mage and Warlock armor buffs.
-- First-rank entries are enough because the module upgrades purchased spells
-- to the best available rank for the player's level on login and level-up.

REPLACE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`) VALUES
-- Mage armor spells
(168,   128,  10, 2, 'Mage - Armor',    4, 0), -- Frost Armor
(7302,  128,  30, 2, 'Mage - Armor',    4, 0), -- Ice Armor
(6117,  128,  34, 2, 'Mage - Armor',    4, 0), -- Mage Armor
(30482, 128,  62, 2, 'Mage - Armor',    4, 0), -- Molten Armor

-- Warlock armor spells
(687,   256,  10, 2, 'Warlock - Armor', 4, 0), -- Demon Skin
(706,   256,  20, 2, 'Warlock - Armor', 4, 0), -- Demon Armor
(28176, 256,  62, 2, 'Warlock - Armor', 4, 0); -- Fel Armor
