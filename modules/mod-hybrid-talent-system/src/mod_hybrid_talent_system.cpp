#include "Chat.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DatabaseEnv.h"
#include "GossipDef.h"
#include "Item.h"
#include "ItemScript.h"
#include "Log.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"
#include "WorldScript.h"

#include <algorithm>
#include <cstddef>
#include <map>
#include <set>
#include <string>
#include <vector>

namespace
{
    using namespace Acore::ChatCommands;

    struct HybridSpellTemplate
    {
        uint32 SpellId = 0;
        uint32 ClassMask = 0;
        uint8 RequiredLevel = 1;
        uint16 Cost = 1;
        std::string Category;
        std::string Description;
        uint8 RoleMask = 0;
        uint32 Flags = 0;
    };

    struct HybridSynergyTemplate
    {
        uint32 RequiredSpell1 = 0;
        uint32 RequiredSpell2 = 0;
        uint32 RewardSpell = 0;
    };

    struct HybridClassFilter
    {
        uint32 ClassMask = 0;
        char const* Name = "";
    };

    bool Enabled = true;
    uint8 MinLevel = 10;
    uint16 PointsPerInterval = 1;
    uint8 PointIntervalLevels = 2;
    uint16 MaxPoints = 35;
    uint32 ResetCostCopper = 100000;
    uint32 TrainerNpcEntry = 190010;
    constexpr uint32 LegacyBeaconItemEntry1 = 900010;
    constexpr uint32 LegacyBeaconItemEntry2 = 65010;
    constexpr uint32 LegacyBeaconItemEntry3 = 1854;
    uint32 BeaconItemEntry = 1915;
    bool GrantBeaconOnLogin = true;
    uint32 BeaconSummonDurationSeconds = 300;
    bool RestoreOnLogin = true;
    bool EnableSynergies = true;
    bool AutoUpgradeRanks = true;

    std::map<uint32, HybridSpellTemplate> SpellTemplates;
    std::vector<HybridSynergyTemplate> SynergyTemplates;
    std::map<ObjectGuid::LowType, uint32> PendingHybridActionRestoreMs;

    enum HybridActions : uint32
    {
        ACTION_STATUS = GOSSIP_ACTION_INFO_DEF + 1,
        ACTION_BROWSE = GOSSIP_ACTION_INFO_DEF + 2,
        ACTION_RESET_CONFIRM = GOSSIP_ACTION_INFO_DEF + 3,
        ACTION_RESET_EXECUTE = GOSSIP_ACTION_INFO_DEF + 4,
        ACTION_DISMISS = GOSSIP_ACTION_INFO_DEF + 5,
        ACTION_UNLEARN = GOSSIP_ACTION_INFO_DEF + 6,
        ACTION_CLASS_BASE = GOSSIP_ACTION_INFO_DEF + 100,
        ACTION_BROWSE_PAGE_BASE = GOSSIP_ACTION_INFO_DEF + 1000,
        ACTION_UNLEARN_PAGE_BASE = GOSSIP_ACTION_INFO_DEF + 10000,
        ACTION_UNLEARN_SPELL_BASE = GOSSIP_ACTION_INFO_DEF + 20000,
        ACTION_LEARN_BASE = GOSSIP_ACTION_INFO_DEF + 40000
    };

    constexpr uint32 HybridBrowsePageSize = 12;
    constexpr uint32 HybridUnlearnPageSize = 12;
    constexpr uint32 HybridPageActionStride = 100;
    constexpr uint32 HybridLearnActionStride = 1000;
    constexpr uint32 HybridActionRestoreDelayMs = 1500;

    std::vector<HybridClassFilter> const HybridClasses =
    {
        { 1, "Warrior" },
        { 2, "Paladin" },
        { 4, "Hunter" },
        { 8, "Rogue" },
        { 16, "Priest" },
        { 32, "Death Knight" },
        { 64, "Shaman" },
        { 128, "Mage" },
        { 256, "Warlock" },
        { 1024, "Druid" }
    };

    uint32 GetHybridClassMask(uint32 classIndex)
    {
        if (classIndex >= HybridClasses.size())
            return 0;

        return HybridClasses[classIndex].ClassMask;
    }

    std::string GetHybridClassName(uint32 classIndex)
    {
        if (classIndex >= HybridClasses.size())
            return "Hybrid";

        return HybridClasses[classIndex].Name;
    }

    uint16 CalculateEarnedPoints(Player const* player)
    {
        if (!player || player->GetLevel() < MinLevel)
            return 0;

        uint8 interval = PointIntervalLevels ? PointIntervalLevels : 1;
        uint16 points = static_cast<uint16>(((player->GetLevel() - MinLevel) / interval + 1) * PointsPerInterval);
        return std::min<uint16>(points, MaxPoints);
    }

    uint16 GetSpentPoints(ObjectGuid::LowType guid)
    {
        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return 0;

        uint16 spent = 0;
        do
        {
            uint32 spellId = (*result)[0].Get<uint32>();
            auto itr = SpellTemplates.find(spellId);
            if (itr != SpellTemplates.end())
                spent += itr->second.Cost;
        } while (result->NextRow());

        return spent;
    }

    bool IsAllowedForPlayer(Player const* player, HybridSpellTemplate const& templ)
    {
        if (!player)
            return false;

        if (player->GetLevel() < templ.RequiredLevel)
            return false;

        if (templ.ClassMask && (templ.ClassMask & player->getClassMask()))
            return false;

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
        if (!spellInfo)
            return false;

        return true;
    }

    uint32 GetFirstRankSpellId(uint32 spellId)
    {
        if (uint32 firstRank = sSpellMgr->GetFirstSpellInChain(spellId))
            return firstRank;

        return spellId;
    }

    bool IsSameSpellChain(uint32 leftSpellId, uint32 rightSpellId)
    {
        return GetFirstRankSpellId(leftSpellId) == GetFirstRankSpellId(rightSpellId);
    }

    bool HasHybridSpellInChain(ObjectGuid::LowType guid, uint32 spellId)
    {
        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return false;

        do
        {
            if (IsSameSpellChain((*result)[0].Get<uint32>(), spellId))
                return true;
        } while (result->NextRow());

        return false;
    }

    bool PlayerHasSpellInChain(Player const* player, uint32 spellId)
    {
        if (!player)
            return false;

        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
            if (player->HasSpell(currentSpellId))
                return true;

        return player->HasSpell(spellId);
    }

    void SaveHybridSpell(ObjectGuid::LowType guid, uint32 spellId)
    {
        CharacterDatabase.Execute("REPLACE INTO character_hybrid_spell (guid, spell_id) VALUES ({}, {})", guid, spellId);
    }

    void DeleteHybridSpell(ObjectGuid::LowType guid, uint32 spellId)
    {
        CharacterDatabase.Execute("DELETE FROM character_hybrid_spell WHERE guid = {} AND spell_id = {}", guid, spellId);
    }

    void DeleteHybridSpells(ObjectGuid::LowType guid)
    {
        CharacterDatabase.Execute("DELETE FROM character_hybrid_spell WHERE guid = {}", guid);
        CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {}", guid);
    }

    std::set<uint32> GetKnownHybridSpellIds(ObjectGuid::LowType guid)
    {
        std::set<uint32> spellIds;

        QueryResult result = CharacterDatabase.Query("SELECT spell_id FROM character_hybrid_spell WHERE guid = {}", guid);
        if (!result)
            return spellIds;

        do
        {
            Field* fields = result->Fetch();
            spellIds.insert(fields[0].Get<uint32>());
        } while (result->NextRow());

        return spellIds;
    }

    std::vector<uint32> GetLearnedHybridSpellIds(Player const* player)
    {
        std::vector<uint32> spellIds;
        if (!player)
            return spellIds;

        std::set<uint32> knownSpellIds = GetKnownHybridSpellIds(player->GetGUID().GetCounter());
        for (uint32 spellId : knownSpellIds)
            if (SpellTemplates.count(spellId))
                spellIds.push_back(spellId);

        std::sort(spellIds.begin(), spellIds.end(), [](uint32 leftSpellId, uint32 rightSpellId)
        {
            HybridSpellTemplate const& left = SpellTemplates[leftSpellId];
            HybridSpellTemplate const& right = SpellTemplates[rightSpellId];
            if (left.ClassMask != right.ClassMask)
                return left.ClassMask < right.ClassMask;

            SpellInfo const* leftInfo = sSpellMgr->GetSpellInfo(leftSpellId);
            SpellInfo const* rightInfo = sSpellMgr->GetSpellInfo(rightSpellId);
            std::string leftName = leftInfo ? leftInfo->SpellName[0] : std::to_string(leftSpellId);
            std::string rightName = rightInfo ? rightInfo->SpellName[0] : std::to_string(rightSpellId);
            return leftName < rightName;
        });

        return spellIds;
    }

    uint32 GetBestHybridSpellRankForPlayer(Player const* player, uint32 spellId)
    {
        if (!player)
            return spellId;

        uint32 bestSpellId = spellId;
        for (uint32 nextSpellId = sSpellMgr->GetNextSpellInChain(bestSpellId); nextSpellId; nextSpellId = sSpellMgr->GetNextSpellInChain(bestSpellId))
        {
            SpellInfo const* nextSpellInfo = sSpellMgr->GetSpellInfo(nextSpellId);
            if (!nextSpellInfo)
                break;

            if (nextSpellInfo->SpellLevel && player->GetLevel() < nextSpellInfo->SpellLevel)
                break;

            bestSpellId = nextSpellId;
        }

        return bestSpellId;
    }

    void RemoveHybridSpellRanks(Player* player, uint32 spellId, uint32 exceptSpellId = 0)
    {
        if (!player)
            return;

        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
        {
            if (currentSpellId == exceptSpellId)
                continue;

            if (player->HasSpell(currentSpellId))
                player->removeSpell(currentSpellId, SPEC_MASK_ALL, false);
        }

        if (firstRank == spellId)
            return;

        if (!sSpellMgr->GetSpellInfo(firstRank) && player->HasSpell(spellId) && spellId != exceptSpellId)
            player->removeSpell(spellId, SPEC_MASK_ALL, false);
    }

    void DeletePersistedHybridSpellRanks(ObjectGuid::LowType guid, uint32 spellId)
    {
        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
            CharacterDatabase.Execute("DELETE FROM character_spell WHERE guid = {} AND spell = {}", guid, currentSpellId);

        if (firstRank != spellId && !sSpellMgr->GetSpellInfo(firstRank))
            CharacterDatabase.Execute("DELETE FROM character_spell WHERE guid = {} AND spell = {}", guid, spellId);
    }

    void UpdateHybridActionButtons(Player* player, uint32 spellId, uint32 bestSpellId)
    {
        if (!player)
            return;

        bool changed = false;
        std::set<uint32> chainSpellIds;
        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
            chainSpellIds.insert(currentSpellId);

        if (chainSpellIds.empty())
            chainSpellIds.insert(spellId);

        for (uint32 currentSpellId : chainSpellIds)
        {
            if (currentSpellId == bestSpellId)
                continue;

            for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            {
                ActionButton const* actionButton = player->GetActionButton(button);
                if (!actionButton || actionButton->GetType() != ACTION_BUTTON_SPELL || actionButton->GetAction() != currentSpellId)
                    continue;

                if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                    changed = true;
            }
        }

        QueryResult result = CharacterDatabase.Query("SELECT button, action FROM character_action WHERE guid = {} AND spec = {} AND type = {}",
            player->GetGUID().GetCounter(), player->GetActiveSpec(), ACTION_BUTTON_SPELL);

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint8 button = fields[0].Get<uint8>();
                uint32 action = fields[1].Get<uint32>();

                if (!chainSpellIds.count(action))
                    continue;

                ActionButton const* actionButton = player->GetActionButton(button);
                if (actionButton && actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction() == bestSpellId)
                    continue;

                if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                    changed = true;
            } while (result->NextRow());
        }

        if (changed)
            player->SendActionButtons(1);
    }

    bool IsKnownHybridActionSpell(ObjectGuid::LowType guid, uint32 actionSpellId, uint32& baseSpellId)
    {
        std::set<uint32> knownSpellIds = GetKnownHybridSpellIds(guid);
        for (uint32 knownSpellId : knownSpellIds)
        {
            if (!SpellTemplates.count(knownSpellId))
                continue;

            if (IsSameSpellChain(knownSpellId, actionSpellId))
            {
                baseSpellId = knownSpellId;
                return true;
            }
        }

        return false;
    }

    void SaveHybridActionButtons(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint8 spec = player->GetActiveSpec();

        for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
        {
            ActionButton const* actionButton = player->GetActionButton(button);
            if (!actionButton)
                continue;

            if (actionButton->GetType() != ACTION_BUTTON_SPELL)
            {
                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, spec, button);
                continue;
            }

            uint32 baseSpellId = 0;
            if (!IsKnownHybridActionSpell(guid, actionButton->GetAction(), baseSpellId))
            {
                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, spec, button);
                continue;
            }

            CharacterDatabase.Execute("REPLACE INTO character_hybrid_action (guid, spec, button, spell_id) VALUES ({}, {}, {}, {})",
                guid, spec, button, baseSpellId);
        }
    }

    void RestoreHybridActionButtons(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        QueryResult result = CharacterDatabase.Query("SELECT button, spell_id FROM character_hybrid_action WHERE guid = {} AND spec = {}",
            guid, player->GetActiveSpec());

        if (!result)
            return;

        bool changed = false;
        do
        {
            Field* fields = result->Fetch();
            uint8 button = fields[0].Get<uint8>();
            uint32 spellId = fields[1].Get<uint32>();

            if (!HasHybridSpellInChain(guid, spellId))
                continue;

            uint32 bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;
            if (!player->HasSpell(bestSpellId))
                continue;

            ActionButton const* actionButton = player->GetActionButton(button);
            if (actionButton && actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction() == bestSpellId)
                continue;

            if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                changed = true;
        } while (result->NextRow());

        if (changed)
            player->SendActionButtons(1);
    }

    void ScheduleHybridActionRestore(Player* player)
    {
        if (!player)
            return;

        PendingHybridActionRestoreMs[player->GetGUID().GetCounter()] = HybridActionRestoreDelayMs;
    }

    void ProcessHybridActionRestore(Player* player, uint32 diff)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        auto itr = PendingHybridActionRestoreMs.find(guid);
        if (itr == PendingHybridActionRestoreMs.end())
            return;

        if (itr->second > diff)
        {
            itr->second -= diff;
            return;
        }

        PendingHybridActionRestoreMs.erase(itr);
        RestoreHybridActionButtons(player);
        player->SendActionButtons(1);
    }

    void RemoveHybridActionButtons(Player* player, uint32 spellId)
    {
        if (!player)
            return;

        bool changed = false;
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint32 firstRank = GetFirstRankSpellId(spellId);
        for (uint32 currentSpellId = firstRank; currentSpellId; currentSpellId = sSpellMgr->GetNextSpellInChain(currentSpellId))
        {
            for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
            {
                ActionButton const* actionButton = player->GetActionButton(button);
                if (!actionButton || actionButton->GetType() != ACTION_BUTTON_SPELL || actionButton->GetAction() != currentSpellId)
                    continue;

                player->removeActionButton(button);
                changed = true;
            }

            CharacterDatabase.Execute("DELETE FROM character_action WHERE guid = {} AND type = {} AND action = {}", guid, ACTION_BUTTON_SPELL, currentSpellId);
        }

        CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spell_id = {}", guid, spellId);

        if (changed)
            player->SendActionButtons(1);
    }

    uint32 LearnBestHybridSpellRank(Player* player, uint32 spellId)
    {
        if (!player)
            return spellId;

        uint32 bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;

        if (!player->HasSpell(bestSpellId))
        {
            DeletePersistedHybridSpellRanks(player->GetGUID().GetCounter(), spellId);
            player->learnSpell(bestSpellId, false);
        }

        UpdateHybridActionButtons(player, spellId, bestSpellId);

        return bestSpellId;
    }

    void ApplySynergies(Player* player)
    {
        if (!EnableSynergies || !player)
            return;

        std::set<uint32> known = GetKnownHybridSpellIds(player->GetGUID().GetCounter());

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            bool qualifies = known.count(synergy.RequiredSpell1) && known.count(synergy.RequiredSpell2);

            if (qualifies && !player->HasSpell(synergy.RewardSpell))
                player->learnSpell(synergy.RewardSpell, false);
            else if (!qualifies && player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }
    }

    void RestoreHybridSpells(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::set<uint32> spellIds = GetKnownHybridSpellIds(guid);

        for (uint32 spellId : spellIds)
        {
            if (!SpellTemplates.count(spellId))
                continue;

            LearnBestHybridSpellRank(player, spellId);
        }

        ApplySynergies(player);
        RestoreHybridActionButtons(player);

        if (!spellIds.empty())
            player->SendActionButtons(1);
    }

    void ResetHybridBuild(Player* player)
    {
        if (!player)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::set<uint32> spellIds = GetKnownHybridSpellIds(guid);

        for (uint32 spellId : spellIds)
        {
            RemoveHybridActionButtons(player, spellId);
            RemoveHybridSpellRanks(player, spellId);
        }

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            RemoveHybridActionButtons(player, synergy.RewardSpell);
            if (player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }

        DeleteHybridSpells(guid);
    }

    void LoadConfig()
    {
        Enabled = sConfigMgr->GetOption<bool>("HybridTalentSystem.Enable", true);
        MinLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MinLevel", 10));
        PointsPerInterval = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointsPerInterval", 1));
        PointIntervalLevels = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointIntervalLevels", 2));
        MaxPoints = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MaxPoints", 35));
        ResetCostCopper = sConfigMgr->GetOption<uint32>("HybridTalentSystem.ResetCostCopper", 100000);
        TrainerNpcEntry = sConfigMgr->GetOption<uint32>("HybridTalentSystem.TrainerNpcEntry", 190010);
        BeaconItemEntry = sConfigMgr->GetOption<uint32>("HybridTalentSystem.BeaconItemEntry", 1915);
        GrantBeaconOnLogin = sConfigMgr->GetOption<bool>("HybridTalentSystem.GrantBeaconOnLogin", true);
        BeaconSummonDurationSeconds = sConfigMgr->GetOption<uint32>("HybridTalentSystem.BeaconSummonDurationSeconds", 300);
        RestoreOnLogin = sConfigMgr->GetOption<bool>("HybridTalentSystem.RestoreOnLogin", true);
        EnableSynergies = sConfigMgr->GetOption<bool>("HybridTalentSystem.EnableSynergies", true);
        AutoUpgradeRanks = sConfigMgr->GetOption<bool>("HybridTalentSystem.AutoUpgradeRanks", true);
    }

    void EnsureCharacterTables()
    {
        CharacterDatabase.Execute("CREATE TABLE IF NOT EXISTS `character_hybrid_spell` ("
            "`guid` INT UNSIGNED NOT NULL,"
            "`spell_id` INT UNSIGNED NOT NULL,"
            "`learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`guid`, `spell_id`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        CharacterDatabase.Execute("CREATE TABLE IF NOT EXISTS `character_hybrid_action` ("
            "`guid` INT UNSIGNED NOT NULL,"
            "`spec` TINYINT UNSIGNED NOT NULL DEFAULT 0,"
            "`button` TINYINT UNSIGNED NOT NULL,"
            "`spell_id` INT UNSIGNED NOT NULL,"
            "PRIMARY KEY (`guid`, `spec`, `button`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
    }

    void LoadTemplates()
    {
        SpellTemplates.clear();
        SynergyTemplates.clear();

        QueryResult tableResult = WorldDatabase.Query("SELECT 1 FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'hybrid_spell_template' LIMIT 1");
        if (!tableResult)
        {
            LOG_WARN("module.hybridtalents", "Hybrid Talent System tables are missing. Import the module SQL or enable DB updates before using the module.");
            return;
        }

        QueryResult descriptionColumnResult = WorldDatabase.Query("SELECT 1 FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'hybrid_spell_template' AND column_name = 'description' LIMIT 1");
        bool hasDescriptionColumn = !!descriptionColumnResult;
        QueryResult spellResult = WorldDatabase.Query(hasDescriptionColumn
            ? "SELECT spell_id, class_mask, required_level, cost, category, COALESCE(description, ''), role_mask, flags FROM hybrid_spell_template"
            : "SELECT spell_id, class_mask, required_level, cost, category, '', role_mask, flags FROM hybrid_spell_template");
        if (spellResult)
        {
            do
            {
                Field* fields = spellResult->Fetch();

                HybridSpellTemplate templ;
                templ.SpellId = fields[0].Get<uint32>();
                templ.ClassMask = fields[1].Get<uint32>();
                templ.RequiredLevel = fields[2].Get<uint8>();
                templ.Cost = fields[3].Get<uint16>();
                templ.Category = fields[4].Get<std::string>();
                templ.Description = fields[5].Get<std::string>();
                templ.RoleMask = fields[6].Get<uint8>();
                templ.Flags = fields[7].Get<uint32>();

                if (sSpellMgr->GetSpellInfo(templ.SpellId))
                    SpellTemplates[templ.SpellId] = templ;
            } while (spellResult->NextRow());
        }

        QueryResult synergyResult = WorldDatabase.Query("SELECT required_spell_1, required_spell_2, reward_spell FROM hybrid_synergy_template");
        if (synergyResult)
        {
            do
            {
                Field* fields = synergyResult->Fetch();

                HybridSynergyTemplate templ;
                templ.RequiredSpell1 = fields[0].Get<uint32>();
                templ.RequiredSpell2 = fields[1].Get<uint32>();
                templ.RewardSpell = fields[2].Get<uint32>();

                if (sSpellMgr->GetSpellInfo(templ.RewardSpell))
                    SynergyTemplates.push_back(templ);
            } while (synergyResult->NextRow());
        }
    }

    void SendMainMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "View hybrid status", GOSSIP_SENDER_MAIN, ACTION_STATUS);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Learn hybrid spells", GOSSIP_SENDER_MAIN, ACTION_BROWSE);
        AddGossipItemFor(player, GOSSIP_ICON_TRAINER, "Unlearn hybrid spells", GOSSIP_SENDER_MAIN, ACTION_UNLEARN);
        AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Reset hybrid build", GOSSIP_SENDER_MAIN, ACTION_RESET_CONFIRM);
        if (creature->IsSummon())
            if (TempSummon* summon = creature->ToTempSummon())
                if (summon->GetSummonerGUID() == player->GetGUID())
                    AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Dismiss summoned trainer", GOSSIP_SENDER_MAIN, ACTION_DISMISS);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    bool IsPlayerSummonedTrainer(Player* player, Creature* creature)
    {
        if (!player || !creature || !creature->IsSummon())
            return false;

        if (TempSummon* summon = creature->ToTempSummon())
            return summon->GetSummonerGUID() == player->GetGUID();

        return false;
    }

    void SendDismissMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);
        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Dismiss summoned trainer", GOSSIP_SENDER_MAIN, ACTION_DISMISS);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void GrantHybridBeacon(Player* player)
    {
        if (!player || !GrantBeaconOnLogin || !BeaconItemEntry)
            return;

        if (BeaconItemEntry == 1915 && player->HasItemCount(LegacyBeaconItemEntry1, 1, true))
            player->DestroyItemCount(LegacyBeaconItemEntry1, player->GetItemCount(LegacyBeaconItemEntry1, true), true);

        if (BeaconItemEntry == 1915 && player->HasItemCount(LegacyBeaconItemEntry2, 1, true))
            player->DestroyItemCount(LegacyBeaconItemEntry2, player->GetItemCount(LegacyBeaconItemEntry2, true), true);

        if (BeaconItemEntry == 1915 && player->HasItemCount(LegacyBeaconItemEntry3, 1, true))
            player->DestroyItemCount(LegacyBeaconItemEntry3, player->GetItemCount(LegacyBeaconItemEntry3, true), true);

        if (!player->HasItemCount(BeaconItemEntry, 1, true))
            player->AddItem(BeaconItemEntry, 1);
    }

    bool SummonHybridTrainer(Player* player)
    {
        if (!player || !TrainerNpcEntry)
            return false;

        if (Creature* existing = player->FindNearestCreature(TrainerNpcEntry, 15.0f, true))
            if (existing->IsSummon())
                if (TempSummon* summon = existing->ToTempSummon())
                    if (summon->GetSummonerGUID() == player->GetGUID())
                        existing->DespawnOrUnsummon();

        float x = player->GetPositionX();
        float y = player->GetPositionY();
        float z = player->GetPositionZ();
        player->GetClosePoint(x, y, z, player->GetObjectSize(), 2.0f);
        float orientation = player->GetOrientation() + 3.14159f;
        uint32 durationMs = BeaconSummonDurationSeconds * 1000;

        Creature* summon = player->SummonCreature(TrainerNpcEntry, x, y, z, orientation, TEMPSUMMON_TIMED_DESPAWN, durationMs);
        if (!summon)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("The Hybrid Talent Master could not be summoned.");
            return false;
        }

        ChatHandler(player->GetSession()).PSendSysMessage("Hybrid Talent Master summoned.");
        return true;
    }

    std::vector<uint32> GetAvailableHybridSpellIds(Player* player, uint32 sourceClassMask)
    {
        std::vector<uint32> spellIds;
        if (!player)
            return spellIds;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        for (auto const& pair : SpellTemplates)
        {
            HybridSpellTemplate const& templ = pair.second;
            if (!IsAllowedForPlayer(player, templ))
                continue;

            if (sourceClassMask && templ.ClassMask != sourceClassMask)
                continue;

            if (HasHybridSpellInChain(guid, templ.SpellId))
                continue;

            spellIds.push_back(templ.SpellId);
        }

        return spellIds;
    }

    std::string GetHybridSpellDescription(HybridSpellTemplate const& templ)
    {
        if (!templ.Description.empty())
            return templ.Description;

        if (!templ.Category.empty())
            return templ.Category;

        return "Hybrid spell";
    }

    std::string TruncateHybridText(std::string text, std::size_t maxLength)
    {
        if (text.length() <= maxLength)
            return text;

        if (maxLength <= 3)
            return text.substr(0, maxLength);

        return text.substr(0, maxLength - 3) + "...";
    }

    void SendClassMenu(Player* player, Creature* creature)
    {
        ClearGossipMenuFor(player);

        bool foundClass = false;
        for (uint32 classIndex = 0; classIndex < HybridClasses.size(); ++classIndex)
        {
            std::vector<uint32> spellIds = GetAvailableHybridSpellIds(player, HybridClasses[classIndex].ClassMask);
            if (spellIds.empty())
                continue;

            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, std::string(HybridClasses[classIndex].Name) + " spells (" + std::to_string(spellIds.size()) + ")", GOSSIP_SENDER_MAIN, ACTION_CLASS_BASE + classIndex);
            foundClass = true;
        }

        if (!foundClass)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No hybrid spells are currently available.", GOSSIP_SENDER_MAIN, 0);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void SendBrowseMenu(Player* player, Creature* creature, uint32 classIndex, uint32 page = 0)
    {
        ClearGossipMenuFor(player);

        uint16 earned = CalculateEarnedPoints(player);
        uint16 spent = GetSpentPoints(player->GetGUID().GetCounter());
        uint16 available = earned > spent ? earned - spent : 0;
        uint32 sourceClassMask = GetHybridClassMask(classIndex);
        std::vector<uint32> spellIds = GetAvailableHybridSpellIds(player, sourceClassMask);

        uint32 pageCount = spellIds.empty() ? 1 : static_cast<uint32>((spellIds.size() + HybridBrowsePageSize - 1) / HybridBrowsePageSize);
        page = std::min(page, pageCount - 1);

        if (pageCount > 1)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, GetHybridClassName(classIndex) + " page " + std::to_string(page + 1) + " of " + std::to_string(pageCount), GOSSIP_SENDER_MAIN, ACTION_BROWSE_PAGE_BASE + classIndex * HybridPageActionStride + page);

        uint32 start = page * HybridBrowsePageSize;
        uint32 end = std::min<uint32>(start + HybridBrowsePageSize, static_cast<uint32>(spellIds.size()));
        for (uint32 index = start; index < end; ++index)
        {
            auto itr = SpellTemplates.find(spellIds[index]);
            if (itr == SpellTemplates.end())
                continue;

            HybridSpellTemplate const& templ = itr->second;
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
            std::string label = spellInfo ? spellInfo->SpellName[0] : std::to_string(templ.SpellId);
            label += " - ";
            label += TruncateHybridText(GetHybridSpellDescription(templ), 86);
            label += " (lvl ";
            label += std::to_string(templ.RequiredLevel);
            label += ", ";
            label += std::to_string(templ.Cost);
            label += " point";
            label += templ.Cost == 1 ? "" : "s";
            label += ")";

            if (available < templ.Cost)
                label += " (not enough points)";

            AddGossipItemFor(player, GOSSIP_ICON_TRAINER, label, GOSSIP_SENDER_MAIN, ACTION_LEARN_BASE + classIndex * HybridLearnActionStride + index);
        }

        if (spellIds.empty())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "No " + GetHybridClassName(classIndex) + " spells are currently available.", GOSSIP_SENDER_MAIN, ACTION_BROWSE);

        if (page > 0)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Previous page", GOSSIP_SENDER_MAIN, ACTION_BROWSE_PAGE_BASE + classIndex * HybridPageActionStride + page - 1);

        if (page + 1 < pageCount)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Next page", GOSSIP_SENDER_MAIN, ACTION_BROWSE_PAGE_BASE + classIndex * HybridPageActionStride + page + 1);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, ACTION_BROWSE);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    void SendUnlearnMenu(Player* player, Creature* creature, uint32 page = 0)
    {
        ClearGossipMenuFor(player);

        std::vector<uint32> spellIds = GetLearnedHybridSpellIds(player);
        uint32 pageCount = spellIds.empty() ? 1 : static_cast<uint32>((spellIds.size() + HybridUnlearnPageSize - 1) / HybridUnlearnPageSize);
        page = std::min(page, pageCount - 1);

        if (pageCount > 1)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Learned spells page " + std::to_string(page + 1) + " of " + std::to_string(pageCount), GOSSIP_SENDER_MAIN, ACTION_UNLEARN_PAGE_BASE + page);

        uint32 start = page * HybridUnlearnPageSize;
        uint32 end = std::min<uint32>(start + HybridUnlearnPageSize, static_cast<uint32>(spellIds.size()));
        for (uint32 index = start; index < end; ++index)
        {
            auto itr = SpellTemplates.find(spellIds[index]);
            if (itr == SpellTemplates.end())
                continue;

            HybridSpellTemplate const& templ = itr->second;
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
            std::string label = "Unlearn ";
            label += spellInfo ? spellInfo->SpellName[0] : std::to_string(templ.SpellId);
            label += " - refund ";
            label += std::to_string(templ.Cost);
            label += " point";
            label += templ.Cost == 1 ? "" : "s";

            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, label, GOSSIP_SENDER_MAIN, ACTION_UNLEARN_SPELL_BASE + index);
        }

        if (spellIds.empty())
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "You have not learned any hybrid spells.", GOSSIP_SENDER_MAIN, 0);

        if (page > 0)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Previous page", GOSSIP_SENDER_MAIN, ACTION_UNLEARN_PAGE_BASE + page - 1);

        if (page + 1 < pageCount)
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Next page", GOSSIP_SENDER_MAIN, ACTION_UNLEARN_PAGE_BASE + page + 1);

        AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
        SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
    }

    bool TryUnlearnHybridSpell(Player* player, uint32 spellId)
    {
        if (!player)
            return false;

        auto itr = SpellTemplates.find(spellId);
        if (itr == SpellTemplates.end())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That hybrid spell is no longer available.");
            return false;
        }

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        if (!HasHybridSpellInChain(guid, spellId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You have not learned that hybrid spell.");
            return false;
        }

        RemoveHybridActionButtons(player, spellId);
        RemoveHybridSpellRanks(player, spellId);
        DeletePersistedHybridSpellRanks(guid, spellId);
        DeleteHybridSpell(guid, spellId);

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            if (synergy.RequiredSpell1 != spellId && synergy.RequiredSpell2 != spellId)
                continue;

            RemoveHybridActionButtons(player, synergy.RewardSpell);
            if (player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }

        ApplySynergies(player);
        player->SendActionButtons(1);

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        ChatHandler(player->GetSession()).PSendSysMessage("{} unlearned. {} hybrid point{} refunded.",
            spellInfo ? spellInfo->SpellName[0] : std::to_string(spellId),
            itr->second.Cost,
            itr->second.Cost == 1 ? "" : "s");
        return true;
    }

    bool TryLearnHybridSpell(Player* player, uint32 spellId)
    {
        auto itr = SpellTemplates.find(spellId);
        if (itr == SpellTemplates.end())
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That spell is not available as a hybrid spell.");
            return false;
        }

        HybridSpellTemplate const& templ = itr->second;
        if (!IsAllowedForPlayer(player, templ))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not meet the requirements for that spell.");
            return false;
        }

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        if (HasHybridSpellInChain(guid, spellId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already know that spell.");
            return false;
        }

        if (PlayerHasSpellInChain(player, spellId))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You already know that spell.");
            return false;
        }

        uint16 earned = CalculateEarnedPoints(player);
        uint16 spent = GetSpentPoints(guid);
        if (earned < spent || earned - spent < templ.Cost)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough hybrid points.");
            return false;
        }

        SaveHybridSpell(guid, spellId);
        uint32 learnedSpellId = LearnBestHybridSpellRank(player, spellId);
        ApplySynergies(player);
        RestoreHybridActionButtons(player);
        ScheduleHybridActionRestore(player);
        SpellInfo const* learnedSpellInfo = sSpellMgr->GetSpellInfo(learnedSpellId);
        if (learnedSpellId != spellId && learnedSpellInfo)
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid spell learned and upgraded to {}.", learnedSpellInfo->SpellName[0]);
        else
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid spell learned.");
        return true;
    }
}

class HybridTalentWorldScript : public WorldScript
{
public:
    HybridTalentWorldScript() : WorldScript("HybridTalentWorldScript") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        LoadConfig();
    }

    void OnStartup() override
    {
        if (!Enabled)
            return;

        EnsureCharacterTables();
        LoadTemplates();
    }
};

class HybridTalentPlayerScript : public PlayerScript
{
public:
    HybridTalentPlayerScript() : PlayerScript("HybridTalentPlayerScript", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SAVE }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (Enabled)
            GrantHybridBeacon(player);

        if (Enabled && RestoreOnLogin)
        {
            RestoreHybridSpells(player);
            ScheduleHybridActionRestore(player);
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (Enabled)
        {
            RestoreHybridSpells(player);
            ScheduleHybridActionRestore(player);
        }
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (Enabled)
            ProcessHybridActionRestore(player, diff);
    }

    void OnPlayerSave(Player* player) override
    {
        if (Enabled)
            SaveHybridActionButtons(player);
    }
};

class HybridTalentTrainerScript : public CreatureScript
{
public:
    HybridTalentTrainerScript() : CreatureScript("npc_hybrid_talent_master") { }

    bool OnGossipHello(Player* player, Creature* creature) override
    {
        if (!Enabled || creature->GetEntry() != TrainerNpcEntry)
            return false;

        if (player->GetLevel() < MinLevel)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid training unlocks at level {}.", MinLevel);
            if (IsPlayerSummonedTrainer(player, creature))
                SendDismissMenu(player, creature);
            return true;
        }

        player->TalkedToCreature(creature->GetEntry(), creature->GetGUID());
        SendMainMenu(player, creature);
        return true;
    }

    bool OnGossipSelect(Player* player, Creature* creature, uint32 /*sender*/, uint32 action) override
    {
        player->PlayerTalkClass->ClearMenus();

        if (action == 0)
        {
            SendMainMenu(player, creature);
            return true;
        }

        if (action == ACTION_STATUS)
        {
            uint16 earned = CalculateEarnedPoints(player);
            uint16 spent = GetSpentPoints(player->GetGUID().GetCounter());
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid points: {} earned, {} spent, {} available.", earned, spent, earned > spent ? earned - spent : 0);
            SendMainMenu(player, creature);
            return true;
        }

        if (action == ACTION_BROWSE)
        {
            SendClassMenu(player, creature);
            return true;
        }

        if (action == ACTION_UNLEARN)
        {
            SendUnlearnMenu(player, creature);
            return true;
        }

        if (action >= ACTION_CLASS_BASE && action < ACTION_BROWSE_PAGE_BASE)
        {
            SendBrowseMenu(player, creature, action - ACTION_CLASS_BASE);
            return true;
        }

        if (action >= ACTION_BROWSE_PAGE_BASE && action < ACTION_UNLEARN_PAGE_BASE)
        {
            uint32 payload = action - ACTION_BROWSE_PAGE_BASE;
            uint32 classIndex = payload / HybridPageActionStride;
            uint32 page = payload % HybridPageActionStride;
            SendBrowseMenu(player, creature, classIndex, page);
            return true;
        }

        if (action >= ACTION_UNLEARN_PAGE_BASE && action < ACTION_UNLEARN_SPELL_BASE)
        {
            SendUnlearnMenu(player, creature, action - ACTION_UNLEARN_PAGE_BASE);
            return true;
        }

        if (action >= ACTION_UNLEARN_SPELL_BASE && action < ACTION_LEARN_BASE)
        {
            uint32 index = action - ACTION_UNLEARN_SPELL_BASE;
            std::vector<uint32> spellIds = GetLearnedHybridSpellIds(player);
            if (index < spellIds.size())
                TryUnlearnHybridSpell(player, spellIds[index]);
            else
                ChatHandler(player->GetSession()).PSendSysMessage("That hybrid spell option is no longer available.");

            SendUnlearnMenu(player, creature, index / HybridUnlearnPageSize);
            return true;
        }

        if (action == ACTION_RESET_CONFIRM)
        {
            ClearGossipMenuFor(player);
            AddGossipItemFor(player, GOSSIP_ICON_MONEY_BAG, "Confirm reset", GOSSIP_SENDER_MAIN, ACTION_RESET_EXECUTE);
            AddGossipItemFor(player, GOSSIP_ICON_CHAT, "Back", GOSSIP_SENDER_MAIN, 0);
            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, creature->GetGUID());
            return true;
        }

        if (action == ACTION_DISMISS)
        {
            if (creature->IsSummon())
                if (TempSummon* summon = creature->ToTempSummon())
                    if (summon->GetSummonerGUID() == player->GetGUID())
                    {
                        CloseGossipMenuFor(player);
                        creature->DespawnOrUnsummon();
                        return true;
                    }

            SendMainMenu(player, creature);
            return true;
        }

        if (action == ACTION_RESET_EXECUTE)
        {
            if (ResetCostCopper && !player->HasEnoughMoney(ResetCostCopper))
            {
                ChatHandler(player->GetSession()).PSendSysMessage("You need {} gold to reset your hybrid build.", ResetCostCopper / 10000);
                SendMainMenu(player, creature);
                return true;
            }

            if (ResetCostCopper)
                player->ModifyMoney(-static_cast<int32>(ResetCostCopper));

            ResetHybridBuild(player);
            ChatHandler(player->GetSession()).PSendSysMessage("Your hybrid build has been reset.");
            SendMainMenu(player, creature);
            return true;
        }

        if (action >= ACTION_LEARN_BASE)
        {
            uint32 payload = action - ACTION_LEARN_BASE;
            uint32 classIndex = payload / HybridLearnActionStride;
            uint32 index = payload % HybridLearnActionStride;
            std::vector<uint32> spellIds = GetAvailableHybridSpellIds(player, GetHybridClassMask(classIndex));
            if (index < spellIds.size())
                TryLearnHybridSpell(player, spellIds[index]);
            else
                ChatHandler(player->GetSession()).PSendSysMessage("That hybrid spell option is no longer available.");

            SendBrowseMenu(player, creature, classIndex, index / HybridBrowsePageSize);
            return true;
        }

        SendMainMenu(player, creature);
        return true;
    }
};

class HybridTalentBeaconItemScript : public ItemScript
{
public:
    HybridTalentBeaconItemScript() : ItemScript("item_hybrid_talent_beacon") { }

    bool OnUse(Player* player, Item* /*item*/, SpellCastTargets const& /*targets*/) override
    {
        if (!Enabled)
            return true;

        SummonHybridTrainer(player);
        player->CastStop();
        return true;
    }
};

class HybridTalentCommandScript : public CommandScript
{
public:
    HybridTalentCommandScript() : CommandScript("HybridTalentCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable hybridCommands =
        {
            { "reload", HandleReloadCommand, SEC_ADMINISTRATOR, Console::No },
            { "reset",  HandleResetCommand,  SEC_ADMINISTRATOR, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "hybrid", hybridCommands }
        };

        return commandTable;
    }

    static bool HandleReloadCommand(ChatHandler* handler)
    {
        LoadConfig();
        LoadTemplates();
        handler->PSendSysMessage("Hybrid Talent System templates reloaded. {} spells, {} synergies.", static_cast<uint32>(SpellTemplates.size()), static_cast<uint32>(SynergyTemplates.size()));
        return true;
    }

    static bool HandleResetCommand(ChatHandler* handler)
    {
        Player* target = handler->getSelectedPlayer();
        if (!target)
        {
            handler->PSendSysMessage("Select a player first.");
            return false;
        }

        ResetHybridBuild(target);
        handler->PSendSysMessage("Hybrid build reset for {}.", target->GetName());
        return true;
    }
};

void AddHybridTalentSystemScripts()
{
    new HybridTalentWorldScript();
    new HybridTalentPlayerScript();
    new HybridTalentTrainerScript();
    new HybridTalentBeaconItemScript();
    new HybridTalentCommandScript();
}
