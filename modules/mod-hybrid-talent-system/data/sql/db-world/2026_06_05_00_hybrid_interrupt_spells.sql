-- Expand the hybrid spell MVP with non-talent interrupt and silence tools.

REPLACE INTO `hybrid_spell_template`
(`spell_id`, `class_mask`, `required_level`, `cost`, `category`, `role_mask`, `flags`) VALUES
-- Warrior
(72,    1,   12, 2, 'Warrior - Interrupt',      8, 0), -- Shield Bash

-- Rogue
(1766,  8,   12, 2, 'Rogue - Interrupt',        8, 0), -- Kick

-- Death Knight
(47528, 32,  55, 2, 'Death Knight - Interrupt', 8, 0), -- Mind Freeze
(47476, 32,  59, 3, 'Death Knight - Silence',   8, 0), -- Strangulate

-- Shaman
(57994, 64,  16, 2, 'Shaman - Interrupt',       8, 0), -- Wind Shear

-- Mage
(2139,  128, 24, 2, 'Mage - Interrupt',         8, 0); -- Counterspell
