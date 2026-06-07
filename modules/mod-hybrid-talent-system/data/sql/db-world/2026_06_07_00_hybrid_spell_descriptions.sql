-- Add player-facing descriptions for the hybrid trainer menu.
-- Imported trainer rows may leave this blank until they are curated.

ALTER TABLE `hybrid_spell_template`
  ADD COLUMN IF NOT EXISTS `description` TEXT NULL AFTER `category`;

UPDATE `hybrid_spell_template` SET `description` = 'Empowers your next melee swing with extra weapon damage.' WHERE `spell_id` = 78;
UPDATE `hybrid_spell_template` SET `description` = 'Charges an enemy, generates rage, and briefly stuns the target.' WHERE `spell_id` = 100;
UPDATE `hybrid_spell_template` SET `description` = 'Wounds the target, causing bleed damage over time.' WHERE `spell_id` = 772;
UPDATE `hybrid_spell_template` SET `description` = 'Increases attack power for nearby party and raid members.' WHERE `spell_id` = 6673;
UPDATE `hybrid_spell_template` SET `description` = 'Slows the enemy movement speed with a crippling strike.' WHERE `spell_id` = 1715;
UPDATE `hybrid_spell_template` SET `description` = 'Bashes the target with a shield, interrupting spellcasting.' WHERE `spell_id` = 72;
UPDATE `hybrid_spell_template` SET `description` = 'A reactive melee strike usable after the target dodges.' WHERE `spell_id` = 7384;
UPDATE `hybrid_spell_template` SET `description` = 'Blasts nearby enemies, dealing damage and slowing their attacks.' WHERE `spell_id` = 6343;

UPDATE `hybrid_spell_template` SET `description` = 'A major emergency heal that restores a friendly target.' WHERE `spell_id` = 633;
UPDATE `hybrid_spell_template` SET `description` = 'Stuns an enemy for a short duration.' WHERE `spell_id` = 853;
UPDATE `hybrid_spell_template` SET `description` = 'An aura that increases armor for nearby party and raid members.' WHERE `spell_id` = 465;
UPDATE `hybrid_spell_template` SET `description` = 'A direct holy heal for a friendly target.' WHERE `spell_id` = 635;
UPDATE `hybrid_spell_template` SET `description` = 'Blesses a friendly target, increasing melee attack power.' WHERE `spell_id` = 19740;
UPDATE `hybrid_spell_template` SET `description` = 'Judges the target, enabling attackers to heal from striking it.' WHERE `spell_id` = 20271;
UPDATE `hybrid_spell_template` SET `description` = 'Judges the target, enabling attackers to restore mana from striking it.' WHERE `spell_id` = 53408;
UPDATE `hybrid_spell_template` SET `description` = 'Imbues melee attacks with holy damage through a paladin seal.' WHERE `spell_id` = 20154;
UPDATE `hybrid_spell_template` SET `description` = 'Judges the target, limiting movement effects and preventing fleeing.' WHERE `spell_id` = 53407;
UPDATE `hybrid_spell_template` SET `description` = 'Reduces incoming damage for a short defensive window.' WHERE `spell_id` = 498;
UPDATE `hybrid_spell_template` SET `description` = 'Removes and prevents movement-impairing effects for a short time.' WHERE `spell_id` = 1044;
UPDATE `hybrid_spell_template` SET `description` = 'Removes poison, disease, and magic effects from a friendly target.' WHERE `spell_id` = 4987;

UPDATE `hybrid_spell_template` SET `description` = 'A melee attack that deals weapon damage.' WHERE `spell_id` = 2973;
UPDATE `hybrid_spell_template` SET `description` = 'An instant ranged shot dealing arcane damage.' WHERE `spell_id` = 3044;
UPDATE `hybrid_spell_template` SET `description` = 'An aspect that improves dodge while active.' WHERE `spell_id` = 13163;
UPDATE `hybrid_spell_template` SET `description` = 'Shows nearby beasts on the minimap.' WHERE `spell_id` = 1494;
UPDATE `hybrid_spell_template` SET `description` = 'A ranged shot that dazes and slows the target.' WHERE `spell_id` = 5116;
UPDATE `hybrid_spell_template` SET `description` = 'An aspect that increases ranged attack power.' WHERE `spell_id` = 13165;
UPDATE `hybrid_spell_template` SET `description` = 'Leaps backward from the enemy to create distance.' WHERE `spell_id` = 781;

UPDATE `hybrid_spell_template` SET `description` = 'Strikes from the shadows, dealing weapon damage.' WHERE `spell_id` = 1752;
UPDATE `hybrid_spell_template` SET `description` = 'A finishing move that deals damage based on combo points.' WHERE `spell_id` = 2098;
UPDATE `hybrid_spell_template` SET `description` = 'Interrupts spellcasting and prevents that school briefly.' WHERE `spell_id` = 1766;
UPDATE `hybrid_spell_template` SET `description` = 'Greatly increases dodge chance for a short time.' WHERE `spell_id` = 5277;
UPDATE `hybrid_spell_template` SET `description` = 'Enters stealth, allowing you to move unseen.' WHERE `spell_id` = 1784;
UPDATE `hybrid_spell_template` SET `description` = 'Allows the use of rogue poisons.' WHERE `spell_id` = 2842;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that can deal instant nature damage.' WHERE `spell_id` = 8681;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that stacks damage over time.' WHERE `spell_id` = 2823;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that slows movement.' WHERE `spell_id` = 3408;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that slows enemy casting.' WHERE `spell_id` = 5761;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that reduces healing received.' WHERE `spell_id` = 13218;
UPDATE `hybrid_spell_template` SET `description` = 'Coats a weapon with poison that removes an enrage effect.' WHERE `spell_id` = 26786;

UPDATE `hybrid_spell_template` SET `description` = 'A healing-over-time effect for a friendly target.' WHERE `spell_id` = 139;
UPDATE `hybrid_spell_template` SET `description` = 'Deals shadow damage over time to an enemy.' WHERE `spell_id` = 589;
UPDATE `hybrid_spell_template` SET `description` = 'Protects a friendly target with a damage-absorbing shield.' WHERE `spell_id` = 17;
UPDATE `hybrid_spell_template` SET `description` = 'Increases the stamina of party and raid members.' WHERE `spell_id` = 1243;
UPDATE `hybrid_spell_template` SET `description` = 'Dispels magic from a friendly target or enemy.' WHERE `spell_id` = 527;
UPDATE `hybrid_spell_template` SET `description` = 'Temporarily lowers your threat against enemies.' WHERE `spell_id` = 586;
UPDATE `hybrid_spell_template` SET `description` = 'Blasts the target with shadow damage.' WHERE `spell_id` = 8092;

UPDATE `hybrid_spell_template` SET `description` = 'A frost bolt that damages and slows an enemy.' WHERE `spell_id` = 116;
UPDATE `hybrid_spell_template` SET `description` = 'A fiery blast that damages an enemy.' WHERE `spell_id` = 133;
UPDATE `hybrid_spell_template` SET `description` = 'Increases intellect for a friendly target.' WHERE `spell_id` = 1459;
UPDATE `hybrid_spell_template` SET `description` = 'Creates a defensive frost armor that slows attackers.' WHERE `spell_id` = 168;
UPDATE `hybrid_spell_template` SET `description` = 'An instant fire blast that damages an enemy.' WHERE `spell_id` = 2136;
UPDATE `hybrid_spell_template` SET `description` = 'Slows falling speed for a friendly target.' WHERE `spell_id` = 130;
UPDATE `hybrid_spell_template` SET `description` = 'Removes a curse from a friendly target.' WHERE `spell_id` = 475;
UPDATE `hybrid_spell_template` SET `description` = 'Teleports you a short distance forward and breaks stuns/roots.' WHERE `spell_id` = 1953;
UPDATE `hybrid_spell_template` SET `description` = 'Interrupts enemy spellcasting and locks that school briefly.' WHERE `spell_id` = 2139;
UPDATE `hybrid_spell_template` SET `description` = 'Freezes nearby enemies in place.' WHERE `spell_id` = 122;
UPDATE `hybrid_spell_template` SET `description` = 'Creates a stronger frost armor that improves armor and slows attackers.' WHERE `spell_id` = 7302;
UPDATE `hybrid_spell_template` SET `description` = 'Improves resistance to magic and allows mana regeneration while casting.' WHERE `spell_id` = 6117;
UPDATE `hybrid_spell_template` SET `description` = 'Increases critical strike chance and damages attackers with fire.' WHERE `spell_id` = 30482;

UPDATE `hybrid_spell_template` SET `description` = 'Curses the target, causing shadow damage over time.' WHERE `spell_id` = 172;
UPDATE `hybrid_spell_template` SET `description` = 'Burns an enemy with fire damage and additional damage over time.' WHERE `spell_id` = 348;
UPDATE `hybrid_spell_template` SET `description` = 'Converts health into mana.' WHERE `spell_id` = 1454;
UPDATE `hybrid_spell_template` SET `description` = 'Increases armor and health regeneration.' WHERE `spell_id` = 687;
UPDATE `hybrid_spell_template` SET `description` = 'Fears an enemy, causing it to flee briefly.' WHERE `spell_id` = 5782;
UPDATE `hybrid_spell_template` SET `description` = 'Weakens the target, reducing its melee damage.' WHERE `spell_id` = 702;
UPDATE `hybrid_spell_template` SET `description` = 'Summons an imp minion.' WHERE `spell_id` = 688;
UPDATE `hybrid_spell_template` SET `description` = 'Allows underwater breathing for an extended time.' WHERE `spell_id` = 5697;
UPDATE `hybrid_spell_template` SET `description` = 'Increases armor and healing received.' WHERE `spell_id` = 706;
UPDATE `hybrid_spell_template` SET `description` = 'Increases spell power and healing received.' WHERE `spell_id` = 28176;

UPDATE `hybrid_spell_template` SET `description` = 'A quick nature-based direct heal.' WHERE `spell_id` = 331;
UPDATE `hybrid_spell_template` SET `description` = 'Strikes an enemy with lightning damage.' WHERE `spell_id` = 403;
UPDATE `hybrid_spell_template` SET `description` = 'Imbues your weapon with extra attack power.' WHERE `spell_id` = 8017;
UPDATE `hybrid_spell_template` SET `description` = 'Imbues your weapon with extra fire damage.' WHERE `spell_id` = 8024;
UPDATE `hybrid_spell_template` SET `description` = 'A nature shock that damages an enemy.' WHERE `spell_id` = 8042;
UPDATE `hybrid_spell_template` SET `description` = 'Summons a totem that increases nearby strength and agility.' WHERE `spell_id` = 8075;
UPDATE `hybrid_spell_template` SET `description` = 'Surrounds you with lightning that damages attackers.' WHERE `spell_id` = 324;
UPDATE `hybrid_spell_template` SET `description` = 'Transforms you into Ghost Wolf for faster movement.' WHERE `spell_id` = 546;
UPDATE `hybrid_spell_template` SET `description` = 'Interrupts spellcasting at range with a burst of wind.' WHERE `spell_id` = 57994;
UPDATE `hybrid_spell_template` SET `description` = 'Imbues your weapon with frost damage and a movement slow.' WHERE `spell_id` = 8033;
UPDATE `hybrid_spell_template` SET `description` = 'Imbues your weapon with a chance for extra attacks.' WHERE `spell_id` = 8232;
UPDATE `hybrid_spell_template` SET `description` = 'Removes beneficial magic effects from an enemy.' WHERE `spell_id` = 370;
UPDATE `hybrid_spell_template` SET `description` = 'Removes poison and disease effects from a friendly target.' WHERE `spell_id` = 526;

UPDATE `hybrid_spell_template` SET `description` = 'A healing-over-time effect for a friendly target.' WHERE `spell_id` = 774;
UPDATE `hybrid_spell_template` SET `description` = 'Burns the target with arcane damage and damage over time.' WHERE `spell_id` = 8921;
UPDATE `hybrid_spell_template` SET `description` = 'Causes attackers to take nature damage when striking the target.' WHERE `spell_id` = 467;
UPDATE `hybrid_spell_template` SET `description` = 'A direct nature damage spell.' WHERE `spell_id` = 5176;
UPDATE `hybrid_spell_template` SET `description` = 'Removes one poison effect from a friendly target.' WHERE `spell_id` = 8946;
UPDATE `hybrid_spell_template` SET `description` = 'Removes a curse from a friendly target.' WHERE `spell_id` = 2782;
UPDATE `hybrid_spell_template` SET `description` = 'Enter stealth while in cat form.' WHERE `spell_id` = 5215;

UPDATE `hybrid_spell_template` SET `description` = 'A frost strike that infects the target with Frost Fever.' WHERE `spell_id` = 45477;
UPDATE `hybrid_spell_template` SET `description` = 'A disease-based shadow attack for Death Knights.' WHERE `spell_id` = 45462;
UPDATE `hybrid_spell_template` SET `description` = 'Spends runic power to damage an enemy or heal undead allies.' WHERE `spell_id` = 47541;
UPDATE `hybrid_spell_template` SET `description` = 'Pulls an enemy to you and forces it to attack you briefly.' WHERE `spell_id` = 49576;
UPDATE `hybrid_spell_template` SET `description` = 'A presence that increases damage and returns some healing from damage dealt.' WHERE `spell_id` = 48266;
UPDATE `hybrid_spell_template` SET `description` = 'Absorbs harmful magic and prevents magical debuffs for a short time.' WHERE `spell_id` = 48707;
UPDATE `hybrid_spell_template` SET `description` = 'Interrupts spellcasting with a freezing shock.' WHERE `spell_id` = 47528;
UPDATE `hybrid_spell_template` SET `description` = 'Silences an enemy from range for a short duration.' WHERE `spell_id` = 47476;
