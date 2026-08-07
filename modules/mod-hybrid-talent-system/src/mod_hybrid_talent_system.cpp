#include "Chat.h"
#include "CellImpl.h"
#include "CommandScript.h"
#include "Config.h"
#include "Creature.h"
#include "CreatureScript.h"
#include "DBCStores.h"
#include "DatabaseEnv.h"
#include "GridNotifiers.h"
#include "GridNotifiersImpl.h"
#include "GossipDef.h"
#include "Group.h"
#include "Item.h"
#include "ItemScript.h"
#include "Log.h"
#include "ObjectMgr.h"
#include "Pet.h"
#include "Player.h"
#include "PlayerScript.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "Spell.h"
#include "SpellAuras.h"
#include "SpellMgr.h"
#include "TemporarySummon.h"
#include "UnitScript.h"
#include "WorldSession.h"
#include "WorldScript.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstddef>
#include <exception>
#include <list>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <unordered_set>
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
    uint8 TalentMinLevel = 10;
    uint16 TalentPointsPerInterval = 1;
    uint8 TalentPointIntervalLevels = 2;
    uint16 TalentMaxPoints = 35;
    uint32 ResetCostCopper = 100000;
    uint32 TrainerNpcEntry = 190010;
    constexpr uint32 LegacyBeaconItemEntry1 = 900010;
    constexpr uint32 LegacyBeaconItemEntry2 = 65010;
    constexpr uint32 LegacyBeaconItemEntry3 = 1854;
    constexpr uint32 EarthTotemItemEntry = 5175;
    constexpr uint32 FireTotemItemEntry = 5176;
    constexpr uint32 WaterTotemItemEntry = 5177;
    constexpr uint32 AirTotemItemEntry = 5178;
    uint32 BeaconItemEntry = 1915;
    bool GrantBeaconOnLogin = false;
    uint32 BeaconSummonDurationSeconds = 300;
    bool RestoreOnLogin = true;
    bool EnableSynergies = true;
    bool AutoUpgradeRanks = true;
    bool MirrorPetBuffs = true;
    bool MirrorGroupBuffs = true;
    float MirrorGroupBuffRange = 100.0f;
    bool NormalizeClassBuffDuration = false;
    uint32 NormalizeClassBuffDurationSeconds = 1800;
    bool CompanionAutoLoot = false;
    float CompanionAutoLootRadius = 10.0f;
    uint32 CompanionAutoLootIntervalMs = 1500;
    bool CompanionAutoLootOutOfCombatOnly = true;
    bool CompanionAutoLootRequireNonCombatCompanion = true;
    bool CompanionAutoLootPrioritizePlayerInGroups = false;
    std::unordered_set<uint32> PetBuffSpellIds;
    std::unordered_set<uint32> NormalizeClassBuffSpellIds;
    std::map<uint32, std::set<uint32>> SpellDependencyGrants;
    std::map<uint32, std::map<uint32, uint32>> SpellDependencyItems;

    std::map<uint32, HybridSpellTemplate> SpellTemplates;
    std::vector<HybridSynergyTemplate> SynergyTemplates;
    std::map<ObjectGuid::LowType, uint32> PendingHybridActionRestoreMs;
    std::map<ObjectGuid::LowType, uint32> CompanionAutoLootTimers;

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

    void RemoveHybridTalentRanks(Player* player, TalentEntry const* talentInfo);
    uint8 GetTalentMaxRank(TalentEntry const* talentInfo);

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

    uint16 CalculateEarnedTalentPoints(Player const* player)
    {
        if (!player || player->GetLevel() < TalentMinLevel)
            return 0;

        uint8 interval = TalentPointIntervalLevels ? TalentPointIntervalLevels : 1;
        uint16 points = static_cast<uint16>(((player->GetLevel() - TalentMinLevel) / interval + 1) * TalentPointsPerInterval);
        return std::min<uint16>(points, TalentMaxPoints);
    }

    uint8 GetNextPointLevel(uint8 currentLevel, uint8 minLevel, uint8 intervalLevels, uint16 pointsPerInterval, uint16 maxPoints)
    {
        if (!pointsPerInterval || !maxPoints)
            return 0;

        uint8 interval = intervalLevels ? intervalLevels : 1;

        for (uint16 level = currentLevel + 1; level <= DEFAULT_MAX_LEVEL; ++level)
        {
            if (level < minLevel)
                continue;

            uint16 earned = static_cast<uint16>(((level - minLevel) / interval + 1) * pointsPerInterval);
            if (earned > maxPoints)
                earned = maxPoints;

            uint16 currentEarned = currentLevel < minLevel
                ? 0
                : static_cast<uint16>(((currentLevel - minLevel) / interval + 1) * pointsPerInterval);
            if (currentEarned > maxPoints)
                currentEarned = maxPoints;

            if (earned > currentEarned)
                return static_cast<uint8>(level);
        }

        return 0;
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

    uint16 GetSpentTalentPoints(ObjectGuid::LowType guid)
    {
        QueryResult result = CharacterDatabase.Query("SELECT `rank` FROM character_hybrid_talent WHERE guid = {}", guid);
        if (!result)
            return 0;

        uint16 spent = 0;
        do
        {
            spent += (*result)[0].Get<uint8>();
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

    std::unordered_set<uint32> ParseSpellIdSet(std::string const& value)
    {
        std::unordered_set<uint32> spellIds;
        std::stringstream stream(value);
        std::string token;

        while (std::getline(stream, token, ','))
        {
            token.erase(std::remove_if(token.begin(), token.end(), [](unsigned char c) { return std::isspace(c); }), token.end());
            if (token.empty())
                continue;

            try
            {
                spellIds.insert(static_cast<uint32>(std::stoul(token)));
            }
            catch (std::exception const&)
            {
                LOG_WARN("module.hybridtalents", "Ignoring invalid pet buff spell id '{}' in HybridTalentSystem.PetBuffSpellIds.", token);
            }
        }

        return spellIds;
    }

    std::map<uint32, std::set<uint32>> ParseSpellDependencyGrantMap(std::string const& value)
    {
        std::map<uint32, std::set<uint32>> dependencyGrants;
        std::stringstream entryStream(value);
        std::string entry;

        while (std::getline(entryStream, entry, ';'))
        {
            entry.erase(std::remove_if(entry.begin(), entry.end(), [](unsigned char c) { return std::isspace(c); }), entry.end());
            if (entry.empty())
                continue;

            std::size_t separator = entry.find(':');
            if (separator == std::string::npos || separator == 0 || separator + 1 >= entry.length())
            {
                LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency grant entry '{}'. Expected trigger:grant,grant.", entry);
                continue;
            }

            uint32 triggerSpellId = 0;
            try
            {
                triggerSpellId = static_cast<uint32>(std::stoul(entry.substr(0, separator)));
            }
            catch (std::exception const&)
            {
                LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency trigger in '{}'.", entry);
                continue;
            }

            std::stringstream grantStream(entry.substr(separator + 1));
            std::string grantToken;
            while (std::getline(grantStream, grantToken, ','))
            {
                if (grantToken.empty())
                    continue;

                try
                {
                    uint32 grantSpellId = static_cast<uint32>(std::stoul(grantToken));
                    if (grantSpellId)
                        dependencyGrants[triggerSpellId].insert(grantSpellId);
                }
                catch (std::exception const&)
                {
                    LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency grant '{}' in '{}'.", grantToken, entry);
                }
            }
        }

        return dependencyGrants;
    }

    std::map<uint32, std::map<uint32, uint32>> ParseSpellDependencyItemMap(std::string const& value)
    {
        std::map<uint32, std::map<uint32, uint32>> dependencyItems;
        std::stringstream entryStream(value);
        std::string entry;

        while (std::getline(entryStream, entry, ';'))
        {
            entry.erase(std::remove_if(entry.begin(), entry.end(), [](unsigned char c) { return std::isspace(c); }), entry.end());
            if (entry.empty())
                continue;

            std::size_t separator = entry.find(':');
            if (separator == std::string::npos || separator == 0 || separator + 1 >= entry.length())
            {
                LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency item entry '{}'. Expected trigger:item or trigger:item=count,item=count.", entry);
                continue;
            }

            uint32 triggerSpellId = 0;
            try
            {
                triggerSpellId = static_cast<uint32>(std::stoul(entry.substr(0, separator)));
            }
            catch (std::exception const&)
            {
                LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency item trigger in '{}'.", entry);
                continue;
            }

            std::stringstream itemStream(entry.substr(separator + 1));
            std::string itemToken;
            while (std::getline(itemStream, itemToken, ','))
            {
                if (itemToken.empty())
                    continue;

                uint32 count = 1;
                std::string itemIdText = itemToken;
                std::size_t countSeparator = itemToken.find('=');
                if (countSeparator != std::string::npos)
                {
                    itemIdText = itemToken.substr(0, countSeparator);
                    try
                    {
                        count = std::max<uint32>(1, static_cast<uint32>(std::stoul(itemToken.substr(countSeparator + 1))));
                    }
                    catch (std::exception const&)
                    {
                        LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency item count '{}' in '{}'.", itemToken.substr(countSeparator + 1), entry);
                        continue;
                    }
                }

                try
                {
                    uint32 itemId = static_cast<uint32>(std::stoul(itemIdText));
                    if (itemId)
                        dependencyItems[triggerSpellId][itemId] = count;
                }
                catch (std::exception const&)
                {
                    LOG_WARN("module.hybridtalents", "Ignoring invalid hybrid dependency item '{}' in '{}'.", itemToken, entry);
                }
            }
        }

        return dependencyItems;
    }

    bool IsMirroredBuffSpell(uint32 spellId)
    {
        return PetBuffSpellIds.count(spellId) != 0 || PetBuffSpellIds.count(GetFirstRankSpellId(spellId)) != 0;
    }

    bool IsNormalizedClassBuffSpell(uint32 spellId)
    {
        return NormalizeClassBuffSpellIds.count(spellId) != 0 || NormalizeClassBuffSpellIds.count(GetFirstRankSpellId(spellId)) != 0;
    }

    void NormalizeBuffDuration(Unit* target, uint32 spellId)
    {
        if (!NormalizeClassBuffDuration || !target || !IsNormalizedClassBuffSpell(spellId))
            return;

        Aura* aura = target->GetAura(spellId);
        if (!aura)
            return;

        int32 duration = static_cast<int32>(NormalizeClassBuffDurationSeconds * IN_MILLISECONDS);
        if (duration <= 0 || aura->GetMaxDuration() < 0)
            return;

        aura->SetMaxDuration(duration);
        aura->SetDuration(duration);
    }

    void NormalizeBuffDurationForAffectedTargets(Player* player, Unit* explicitTarget, uint32 spellId)
    {
        if (!player)
            return;

        NormalizeBuffDuration(explicitTarget ? explicitTarget : player, spellId);

        if (explicitTarget != player)
            NormalizeBuffDuration(player, spellId);

        if (Pet* pet = player->GetPet())
            NormalizeBuffDuration(pet, spellId);

        Group* group = player->GetGroup();
        if (!group)
            return;

        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member || member == player || member == explicitTarget)
                continue;

            NormalizeBuffDuration(member, spellId);
        }
    }

    void CastMirroredBuff(Player* caster, Unit* target, uint32 spellId, bool checkRange)
    {
        if (!caster || !target || !target->IsAlive())
            return;

        if (checkRange && !caster->IsWithinDistInMap(target, MirrorGroupBuffRange, true, false, false))
            return;

        if (target->HasAura(spellId))
            return;

        caster->CastSpell(target, spellId, true);
        NormalizeBuffDuration(target, spellId);
    }

    void MirrorBuffToPetAndGroup(Player* player, Spell* spell)
    {
        if (!Enabled || (!MirrorPetBuffs && !MirrorGroupBuffs) || !player || !spell)
            return;

        SpellInfo const* spellInfo = spell->GetSpellInfo();
        if (!spellInfo)
            return;

        Unit* target = spell->m_targets.GetUnitTarget();
        NormalizeBuffDurationForAffectedTargets(player, target, spellInfo->Id);

        if (!IsMirroredBuffSpell(spellInfo->Id))
            return;

        if (target && target != player)
            return;

        if (MirrorPetBuffs)
        {
            if (Pet* pet = player->GetPet())
                CastMirroredBuff(player, pet, spellInfo->Id, false);
        }

        if (!MirrorGroupBuffs)
            return;

        Group* group = player->GetGroup();
        if (!group)
            return;

        for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
        {
            Player* member = itr->GetSource();
            if (!member || member == player)
                continue;

            CastMirroredBuff(player, member, spellInfo->Id, true);
        }
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
        CharacterDatabase.DirectExecute("REPLACE INTO character_hybrid_spell (guid, spell_id) VALUES ({}, {})", guid, spellId);
    }

    void DeleteHybridSpell(ObjectGuid::LowType guid, uint32 spellId)
    {
        CharacterDatabase.DirectExecute("DELETE FROM character_hybrid_spell WHERE guid = {} AND spell_id = {}", guid, spellId);
    }

    void DeleteHybridSpells(ObjectGuid::LowType guid)
    {
        CharacterDatabase.DirectExecute("DELETE FROM character_hybrid_spell WHERE guid = {}", guid);
        CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {}", guid);
        CharacterDatabase.Execute("DELETE FROM character_hybrid_spell_dependency WHERE guid = {}", guid);
    }

    bool IsHybridSpellDependencyGrantTracked(ObjectGuid::LowType guid, uint32 triggerSpellId, uint32 grantedSpellId)
    {
        QueryResult result = CharacterDatabase.Query("SELECT 1 FROM character_hybrid_spell_dependency WHERE guid = {} AND trigger_spell_id = {} AND granted_spell_id = {} LIMIT 1",
            guid, triggerSpellId, grantedSpellId);
        return !!result;
    }

    bool HasAnyHybridSpellDependencyGrant(ObjectGuid::LowType guid, uint32 grantedSpellId)
    {
        QueryResult result = CharacterDatabase.Query("SELECT 1 FROM character_hybrid_spell_dependency WHERE guid = {} AND granted_spell_id = {} LIMIT 1",
            guid, grantedSpellId);
        return !!result;
    }

    void SaveHybridSpellDependencyGrant(ObjectGuid::LowType guid, uint32 triggerSpellId, uint32 grantedSpellId)
    {
        CharacterDatabase.Execute("REPLACE INTO character_hybrid_spell_dependency (guid, trigger_spell_id, granted_spell_id) VALUES ({}, {}, {})",
            guid, triggerSpellId, grantedSpellId);
    }

    void DeleteHybridSpellDependencyGrant(ObjectGuid::LowType guid, uint32 triggerSpellId, uint32 grantedSpellId)
    {
        CharacterDatabase.Execute("DELETE FROM character_hybrid_spell_dependency WHERE guid = {} AND trigger_spell_id = {} AND granted_spell_id = {}",
            guid, triggerSpellId, grantedSpellId);
    }

    std::set<uint32> GetTrackedHybridSpellDependencyGrants(ObjectGuid::LowType guid, uint32 triggerSpellId)
    {
        std::set<uint32> grantedSpellIds;
        QueryResult result = CharacterDatabase.Query("SELECT granted_spell_id FROM character_hybrid_spell_dependency WHERE guid = {} AND trigger_spell_id = {}",
            guid, triggerSpellId);
        if (!result)
            return grantedSpellIds;

        do
        {
            grantedSpellIds.insert((*result)[0].Get<uint32>());
        } while (result->NextRow());

        return grantedSpellIds;
    }

    uint8 GetSavedHybridTalentRank(ObjectGuid::LowType guid, uint32 talentId)
    {
        QueryResult result = CharacterDatabase.Query("SELECT `rank` FROM character_hybrid_talent WHERE guid = {} AND talent_id = {}", guid, talentId);
        if (!result)
            return 0;

        return (*result)[0].Get<uint8>();
    }

    void SaveHybridTalent(ObjectGuid::LowType guid, uint32 talentId, uint8 rank)
    {
        CharacterDatabase.DirectExecute("REPLACE INTO character_hybrid_talent (guid, talent_id, `rank`) VALUES ({}, {}, {})", guid, talentId, rank);
    }

    void DeleteHybridTalent(ObjectGuid::LowType guid, uint32 talentId)
    {
        CharacterDatabase.DirectExecute("DELETE FROM character_hybrid_talent WHERE guid = {} AND talent_id = {}", guid, talentId);
    }

    void DeleteHybridTalents(ObjectGuid::LowType guid)
    {
        CharacterDatabase.DirectExecute("DELETE FROM character_hybrid_talent WHERE guid = {}", guid);
    }

    std::map<uint32, uint8> GetKnownHybridTalentRanks(ObjectGuid::LowType guid)
    {
        std::map<uint32, uint8> talentRanks;

        QueryResult result = CharacterDatabase.Query("SELECT talent_id, `rank` FROM character_hybrid_talent WHERE guid = {}", guid);
        if (!result)
            return talentRanks;

        do
        {
            Field* fields = result->Fetch();
            talentRanks[fields[0].Get<uint32>()] = fields[1].Get<uint8>();
        } while (result->NextRow());

        return talentRanks;
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

    void PersistCharacterSpell(ObjectGuid::LowType guid, uint32 spellId)
    {
        CharacterDatabase.DirectExecute("REPLACE INTO character_spell (guid, spell, specMask) VALUES ({}, {}, {})", guid, spellId, SPEC_MASK_ALL);
    }

    void UpdateHybridActionButtons(Player* player, uint32 spellId, uint32 bestSpellId)
    {
        if (!player)
            return;

        bool changed = false;
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint8 spec = player->GetActiveSpec();
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
                {
                    CharacterDatabase.Execute("REPLACE INTO character_hybrid_action (guid, spec, button, spell_id) VALUES ({}, {}, {}, {})",
                        guid, spec, button, spellId);
                    changed = true;
                }
            }
        }

        QueryResult result = CharacterDatabase.Query("SELECT button, action FROM character_action WHERE guid = {} AND spec = {} AND type = {}",
            guid, spec, ACTION_BUTTON_SPELL);

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
                {
                    CharacterDatabase.Execute("REPLACE INTO character_hybrid_action (guid, spec, button, spell_id) VALUES ({}, {}, {}, {})",
                        guid, spec, button, spellId);
                    changed = true;
                }
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

    bool IsKnownHybridTalentActionSpell(ObjectGuid::LowType guid, uint32 actionSpellId, uint32& talentSpellId)
    {
        std::map<uint32, uint8> talentRanks = GetKnownHybridTalentRanks(guid);
        for (auto const& pair : talentRanks)
        {
            TalentEntry const* talentInfo = sTalentStore.LookupEntry(pair.first);
            if (!talentInfo)
                continue;

            uint8 maxRank = GetTalentMaxRank(talentInfo);
            uint8 rank = std::min<uint8>(pair.second, maxRank);
            if (!rank)
                continue;

            uint32 rankSpellId = talentInfo->RankID[rank - 1];
            if (rankSpellId && rankSpellId == actionSpellId)
            {
                talentSpellId = rankSpellId;
                return true;
            }
        }

        return false;
    }

    bool IsKnownHybridDependencyActionSpell(ObjectGuid::LowType guid, uint32 actionSpellId, uint32& dependencySpellId)
    {
        for (auto const& pair : SpellDependencyGrants)
        {
            for (uint32 grantedSpellId : pair.second)
            {
                if (!HasAnyHybridSpellDependencyGrant(guid, grantedSpellId))
                    continue;

                if (IsSameSpellChain(grantedSpellId, actionSpellId))
                {
                    dependencySpellId = grantedSpellId;
                    return true;
                }
            }
        }

        return false;
    }

    bool IsKnownTemplateActionSpell(Player const* player, uint32 actionSpellId, uint32& templateSpellId)
    {
        if (!player)
            return false;

        for (auto const& pair : SpellTemplates)
        {
            uint32 spellId = pair.first;
            if (!IsSameSpellChain(spellId, actionSpellId))
                continue;

            if (!PlayerHasSpellInChain(player, spellId))
                continue;

            templateSpellId = spellId;
            return true;
        }

        return false;
    }

    bool PlayerHasActionSpell(Player* player, uint32 spellId)
    {
        if (!player)
            return false;

        for (uint8 button = 0; button < MAX_ACTION_BUTTONS; ++button)
        {
            ActionButton const* actionButton = player->GetActionButton(button);
            if (actionButton && actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction() == spellId)
                return true;
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
            {
                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, spec, button);
                continue;
            }

            if (actionButton->GetType() != ACTION_BUTTON_SPELL)
            {
                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, spec, button);
                continue;
            }

            uint32 managedSpellId = 0;
            if (!IsKnownHybridActionSpell(guid, actionButton->GetAction(), managedSpellId) &&
                !IsKnownHybridTalentActionSpell(guid, actionButton->GetAction(), managedSpellId) &&
                !IsKnownHybridDependencyActionSpell(guid, actionButton->GetAction(), managedSpellId) &&
                !IsKnownTemplateActionSpell(player, actionButton->GetAction(), managedSpellId))
            {
                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, spec, button);
                continue;
            }

            CharacterDatabase.Execute("REPLACE INTO character_hybrid_action (guid, spec, button, spell_id) VALUES ({}, {}, {}, {})",
                guid, spec, button, managedSpellId);
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

            uint32 bestSpellId = spellId;
            uint32 talentSpellId = 0;
            if (HasHybridSpellInChain(guid, spellId))
                bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;
            else if (IsKnownHybridTalentActionSpell(guid, spellId, talentSpellId))
                bestSpellId = talentSpellId;
            else if (HasAnyHybridSpellDependencyGrant(guid, spellId))
                bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;
            else if (PlayerHasSpellInChain(player, spellId))
                bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, spellId) : spellId;
            else
                continue;

            if (!player->HasSpell(bestSpellId))
                continue;

            ActionButton const* actionButton = player->GetActionButton(button);
            if (actionButton && actionButton->GetType() == ACTION_BUTTON_SPELL && actionButton->GetAction() == bestSpellId)
                continue;

            if (actionButton)
            {
                if (actionButton->GetType() == ACTION_BUTTON_SPELL && IsSameSpellChain(actionButton->GetAction(), bestSpellId))
                {
                    if (player->addActionButton(button, bestSpellId, ACTION_BUTTON_SPELL))
                        changed = true;
                    continue;
                }

                if (!PlayerHasActionSpell(player, bestSpellId))
                    continue;

                CharacterDatabase.Execute("DELETE FROM character_hybrid_action WHERE guid = {} AND spec = {} AND button = {}", guid, player->GetActiveSpec(), button);
                continue;
            }

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

    bool HasActiveCompanionAutoLootTrigger(Player* player)
    {
        if (!player)
            return false;

        if (!CompanionAutoLootRequireNonCombatCompanion)
            return true;

        Creature* companion = player->GetCompanionPet();
        if (!companion && !player->GetCritterGUID().IsEmpty())
            companion = ObjectAccessor::GetCreature(*player, player->GetCritterGUID());

        return companion && companion->IsAlive() && companion->IsInWorld()
            && companion->GetOwnerGUID() == player->GetGUID()
            && (companion->IsCritter() || companion->GetCreatureType() == CREATURE_TYPE_NON_COMBAT_PET);
    }

    bool CanCompanionAutoLootCreature(Player* player, Creature* creature)
    {
        if (!player || !creature)
            return false;

        if (!creature->isDead() || creature->IsAlive() || !creature->IsWithinDistInMap(player, CompanionAutoLootRadius))
            return false;

        if (!creature->IsDamageEnoughForLootingAndReward() || creature->IsLootRewardDisabled())
            return false;

        if (player->HasPendingBind())
            return false;

        if (!player->isAllowedToLoot(creature))
            return false;

        Loot* loot = &creature->loot;
        if (!loot || loot->isLooted() || loot->loot_type == LOOT_SKINNING || loot->loot_type == LOOT_PICKPOCKETING)
            return false;

        if (!loot->gold && !loot->hasItemForAll() && !loot->hasItemFor(player))
            return false;

        return true;
    }

    void CompanionAutoLootMoney(Player* player, Loot* loot)
    {
        if (!player || !loot || !loot->gold)
            return;

        uint32 gold = loot->gold;
        sScriptMgr->OnPlayerBeforeLootMoney(player, loot);
        loot->NotifyMoneyRemoved();

        if (Group* group = player->GetGroup())
        {
            std::vector<Player*> playersNear;
            for (GroupReference* itr = group->GetFirstMember(); itr != nullptr; itr = itr->next())
            {
                Player* member = itr->GetSource();
                if (member && player->IsAtLootRewardDistance(member))
                    playersNear.push_back(member);
            }

            if (!playersNear.empty())
            {
                uint32 goldPerPlayer = uint32(gold / playersNear.size());
                for (Player* member : playersNear)
                {
                    member->ModifyMoney(goldPerPlayer);
                    member->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, goldPerPlayer);

                    WorldPacket data(SMSG_LOOT_MONEY_NOTIFY, 4 + 1);
                    data << uint32(goldPerPlayer);
                    data << uint8(playersNear.size() > 1 ? 0 : 1);
                    member->SendDirectMessage(&data);
                }
            }
        }
        else
        {
            sScriptMgr->OnPlayerAfterCreatureLootMoney(player);
            player->ModifyMoney(gold);
            player->UpdateAchievementCriteria(ACHIEVEMENT_CRITERIA_TYPE_LOOT_MONEY, gold);

            WorldPacket data(SMSG_LOOT_MONEY_NOTIFY, 4 + 1);
            data << uint32(gold);
            data << uint8(1);
            player->SendDirectMessage(&data);
        }

        sScriptMgr->OnLootMoney(player, gold);
        loot->gold = 0;
    }

    bool CompanionAutoLootItems(Player* player, Creature* creature)
    {
        if (!player || !creature)
            return false;

        Loot* loot = &creature->loot;
        bool lootedAny = false;
        ObjectGuid previousLootGuid = player->GetLootGUID();
        player->SetLootGUID(creature->GetGUID());

        uint32 maxSlot = loot->GetMaxSlotInLootFor(player);
        for (uint32 slot = 0; slot < maxSlot; ++slot)
        {
            LootItem* lootItem = loot->LootItemInSlot(slot, player);
            if (!lootItem || lootItem->is_looted || lootItem->is_blocked || !lootItem->AllowedForPlayer(player, loot->sourceWorldObjectGUID))
                continue;

            // In grouped play, keep roll/master-loot protections unless QA explicitly prioritizes the player over bots.
            if (!CompanionAutoLootPrioritizePlayerInGroups && player->GetGroup() && !lootItem->is_underthreshold && !lootItem->freeforall && !lootItem->rollWinnerGUID)
                continue;

            InventoryResult msg = EQUIP_ERR_OK;
            LootItem* stored = player->StoreLootItem(static_cast<uint8>(slot), loot, msg);
            if (stored && msg == EQUIP_ERR_OK)
                lootedAny = true;
            else if (msg != EQUIP_ERR_OK)
                break;
        }

        player->SetLootGUID(previousLootGuid);
        return lootedAny;
    }

    void CleanupCompanionAutoLootCreature(Player* player, Creature* creature)
    {
        if (!player || !creature)
            return;

        Loot* loot = &creature->loot;
        if (!loot->isLooted())
            return;

        creature->AllLootRemovedFromCorpse();
        creature->RemoveDynamicFlag(UNIT_DYNFLAG_LOOTABLE);
        loot->RemoveLooter(player->GetGUID());
        loot->clear();
    }

    bool TryCompanionAutoLootCreature(Player* player, Creature* creature)
    {
        if (!CanCompanionAutoLootCreature(player, creature))
            return false;

        Loot* loot = &creature->loot;
        CompanionAutoLootMoney(player, loot);
        bool lootedAny = CompanionAutoLootItems(player, creature);
        CleanupCompanionAutoLootCreature(player, creature);
        return lootedAny || loot->isLooted();
    }

    void ProcessCompanionAutoLoot(Player* player, uint32 diff)
    {
        if (!player || !CompanionAutoLoot)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint32& timer = CompanionAutoLootTimers[guid];
        if (timer > diff)
        {
            timer -= diff;
            return;
        }

        timer = CompanionAutoLootIntervalMs;

        if (!player->IsInWorld() || !player->IsAlive() || player->GetLootGUID())
            return;

        if (CompanionAutoLootOutOfCombatOnly && player->IsInCombat())
            return;

        if (!HasActiveCompanionAutoLootTrigger(player))
            return;

        std::list<Creature*> creatures;
        Acore::AllWorldObjectsInRange check(player, CompanionAutoLootRadius);
        Acore::CreatureListSearcher<Acore::AllWorldObjectsInRange> searcher(player, creatures, check);
        Cell::VisitObjects(player, searcher, CompanionAutoLootRadius);

        for (Creature* creature : creatures)
        {
            if (TryCompanionAutoLootCreature(player, creature))
                break;
        }
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

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        if (!player->HasSpell(bestSpellId))
        {
            DeletePersistedHybridSpellRanks(guid, spellId);
            player->learnSpell(bestSpellId, false);
        }
        PersistCharacterSpell(guid, bestSpellId);

        UpdateHybridActionButtons(player, spellId, bestSpellId);

        return bestSpellId;
    }

    uint32 GetDependencyTriggerSpellId(uint32 spellId)
    {
        for (auto const& pair : SpellDependencyGrants)
            if (IsSameSpellChain(pair.first, spellId))
                return pair.first;

        return 0;
    }

    uint32 GetDependencyItemTriggerSpellId(uint32 spellId)
    {
        for (auto const& pair : SpellDependencyItems)
            if (IsSameSpellChain(pair.first, spellId))
                return pair.first;

        return 0;
    }

    void AddConfiguredDependencyItems(uint32 spellId, std::map<uint32, uint32>& requiredItems)
    {
        uint32 triggerSpellId = GetDependencyItemTriggerSpellId(spellId);
        if (!triggerSpellId)
            return;

        auto itr = SpellDependencyItems.find(triggerSpellId);
        if (itr == SpellDependencyItems.end())
            return;

        for (auto const& pair : itr->second)
        {
            uint32 itemId = pair.first;
            uint32 count = std::max<uint32>(1, pair.second);
            if (itemId)
                requiredItems[itemId] = std::max(requiredItems[itemId], count);
        }
    }

    uint32 GetDefaultTotemItemForCategory(Player const* player, uint32 requiredTotemCategoryId)
    {
        if (!player || !requiredTotemCategoryId)
            return 0;

        static std::array<uint32, 4> const defaultTotemItems =
        {
            EarthTotemItemEntry,
            FireTotemItemEntry,
            WaterTotemItemEntry,
            AirTotemItemEntry
        };

        for (uint32 itemId : defaultTotemItems)
            if (ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId))
                if (player->IsTotemCategoryCompatiableWith(itemTemplate, requiredTotemCategoryId))
                    return itemId;

        return 0;
    }

    std::map<uint32, uint32> GetHybridSpellRequiredItems(Player const* player, uint32 spellId, bool includeSatisfiedCategories = false)
    {
        std::map<uint32, uint32> requiredItems;

        AddConfiguredDependencyItems(spellId, requiredItems);

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
            return requiredItems;

        for (uint8 index = 0; index < 2; ++index)
        {
            if (spellInfo->Totem[index])
                requiredItems[spellInfo->Totem[index]] = std::max<uint32>(requiredItems[spellInfo->Totem[index]], 1);

            uint32 requiredCategory = spellInfo->TotemCategory[index];
            if (!requiredCategory || (!includeSatisfiedCategories && player && player->HasItemTotemCategory(requiredCategory)))
                continue;

            uint32 defaultItemId = GetDefaultTotemItemForCategory(player, requiredCategory);
            if (defaultItemId)
                requiredItems[defaultItemId] = std::max<uint32>(requiredItems[defaultItemId], 1);
        }

        return requiredItems;
    }

    uint32 ApplyHybridSpellDependencyItems(Player* player, uint32 spellId, bool announce)
    {
        if (!player)
            return 0;

        std::map<uint32, uint32> requiredItems = GetHybridSpellRequiredItems(player, spellId);
        std::vector<std::string> addedNames;
        for (auto const& pair : requiredItems)
        {
            uint32 itemId = pair.first;
            uint32 requiredCount = std::max<uint32>(1, pair.second);
            uint32 currentCount = player->GetItemCount(itemId, true);
            if (currentCount >= requiredCount)
                continue;

            uint32 addCount = requiredCount - currentCount;
            if (!player->AddItem(itemId, addCount))
            {
                LOG_WARN("module.hybridtalents", "Could not add hybrid dependency item {} x{} to player {}.", itemId, addCount, player->GetGUID().ToString());
                continue;
            }

            if (ItemTemplate const* itemTemplate = sObjectMgr->GetItemTemplate(itemId))
                addedNames.push_back(itemTemplate->Name1);
            else
                addedNames.push_back(std::to_string(itemId));
        }

        if (announce && !addedNames.empty())
        {
            std::string message = "Hybrid support item added: ";
            for (std::size_t index = 0; index < addedNames.size(); ++index)
            {
                if (index)
                    message += ", ";
                message += addedNames[index];
            }
            message += ".";
            ChatHandler(player->GetSession()).PSendSysMessage("{}", message);
        }

        return static_cast<uint32>(addedNames.size());
    }

    bool KnownHybridSpellRequiresItem(Player const* player, uint32 ignoredSpellId, uint32 requiredItemId)
    {
        if (!player || !requiredItemId)
            return false;

        std::set<uint32> knownSpellIds = GetKnownHybridSpellIds(player->GetGUID().GetCounter());
        for (uint32 knownSpellId : knownSpellIds)
        {
            if (IsSameSpellChain(knownSpellId, ignoredSpellId))
                continue;

            std::map<uint32, uint32> requiredItems = GetHybridSpellRequiredItems(player, knownSpellId, true);
            if (requiredItems.count(requiredItemId))
                return true;
        }

        return false;
    }

    void RemoveHybridSpellDependencyItems(Player* player, uint32 spellId)
    {
        if (!player)
            return;

        std::map<uint32, uint32> requiredItems = GetHybridSpellRequiredItems(player, spellId, true);
        for (auto const& pair : requiredItems)
        {
            uint32 itemId = pair.first;
            if (!itemId || KnownHybridSpellRequiresItem(player, spellId, itemId))
                continue;

            uint32 currentCount = player->GetItemCount(itemId, true);
            if (currentCount)
                player->DestroyItemCount(itemId, currentCount, true, false);
        }
    }

    uint32 ApplyHybridSpellDependencyGrants(Player* player, uint32 spellId, bool announce)
    {
        if (!player)
            return 0;

        uint32 triggerSpellId = GetDependencyTriggerSpellId(spellId);
        if (!triggerSpellId)
            return 0;

        auto itr = SpellDependencyGrants.find(triggerSpellId);
        if (itr == SpellDependencyGrants.end())
            return 0;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::vector<std::string> learnedNames;

        for (uint32 grantedSpellId : itr->second)
        {
            if (!sSpellMgr->GetSpellInfo(grantedSpellId))
            {
                LOG_WARN("module.hybridtalents", "Hybrid dependency grant {} for trigger {} has no SpellInfo.", grantedSpellId, triggerSpellId);
                continue;
            }

            bool tracked = IsHybridSpellDependencyGrantTracked(guid, triggerSpellId, grantedSpellId);
            bool alreadyKnown = PlayerHasSpellInChain(player, grantedSpellId);
            if (alreadyKnown && !tracked)
                continue;

            uint32 bestSpellId = AutoUpgradeRanks ? GetBestHybridSpellRankForPlayer(player, grantedSpellId) : grantedSpellId;
            if (!player->HasSpell(bestSpellId))
            {
                DeletePersistedHybridSpellRanks(guid, grantedSpellId);
                player->learnSpell(bestSpellId, false);

                if (SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(bestSpellId))
                    learnedNames.push_back(spellInfo->SpellName[0]);
            }
            PersistCharacterSpell(guid, bestSpellId);

            SaveHybridSpellDependencyGrant(guid, triggerSpellId, grantedSpellId);
        }

        if (announce && !learnedNames.empty())
        {
            std::string message = "Hybrid support learned: ";
            for (std::size_t index = 0; index < learnedNames.size(); ++index)
            {
                if (index)
                    message += ", ";
                message += learnedNames[index];
            }
            message += ".";
            ChatHandler(player->GetSession()).PSendSysMessage("{}", message);
        }

        return static_cast<uint32>(learnedNames.size());
    }

    void RemoveHybridSpellDependencyGrants(Player* player, uint32 spellId)
    {
        if (!player)
            return;

        uint32 triggerSpellId = GetDependencyTriggerSpellId(spellId);
        if (!triggerSpellId)
            return;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::set<uint32> grantedSpellIds = GetTrackedHybridSpellDependencyGrants(guid, triggerSpellId);

        for (uint32 grantedSpellId : grantedSpellIds)
        {
            DeleteHybridSpellDependencyGrant(guid, triggerSpellId, grantedSpellId);

            if (HasAnyHybridSpellDependencyGrant(guid, grantedSpellId))
                continue;

            if (HasHybridSpellInChain(guid, grantedSpellId))
                continue;

            RemoveHybridActionButtons(player, grantedSpellId);
            RemoveHybridSpellRanks(player, grantedSpellId);
            DeletePersistedHybridSpellRanks(guid, grantedSpellId);
        }
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
            ApplyHybridSpellDependencyGrants(player, spellId, false);
            ApplyHybridSpellDependencyItems(player, spellId, false);
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
            RemoveHybridSpellDependencyGrants(player, spellId);
            RemoveHybridActionButtons(player, spellId);
            RemoveHybridSpellRanks(player, spellId);
        }

        for (HybridSynergyTemplate const& synergy : SynergyTemplates)
        {
            RemoveHybridActionButtons(player, synergy.RewardSpell);
            if (player->HasSpell(synergy.RewardSpell))
                player->removeSpell(synergy.RewardSpell, SPEC_MASK_ALL, false);
        }

        std::map<uint32, uint8> talentRanks = GetKnownHybridTalentRanks(guid);
        for (auto const& pair : talentRanks)
            if (TalentEntry const* talentInfo = sTalentStore.LookupEntry(pair.first))
                RemoveHybridTalentRanks(player, talentInfo);

        DeleteHybridSpells(guid);
        DeleteHybridTalents(guid);
    }

    void LoadConfig()
    {
        Enabled = sConfigMgr->GetOption<bool>("HybridTalentSystem.Enable", true);
        MinLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MinLevel", 10));
        PointsPerInterval = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointsPerInterval", 1));
        PointIntervalLevels = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.PointIntervalLevels", 2));
        MaxPoints = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.MaxPoints", 35));
        TalentMinLevel = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.TalentMinLevel", 10));
        TalentPointsPerInterval = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.TalentPointsPerInterval", 1));
        TalentPointIntervalLevels = static_cast<uint8>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.TalentPointIntervalLevels", 2));
        TalentMaxPoints = static_cast<uint16>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.TalentMaxPoints", 35));
        ResetCostCopper = sConfigMgr->GetOption<uint32>("HybridTalentSystem.ResetCostCopper", 100000);
        TrainerNpcEntry = sConfigMgr->GetOption<uint32>("HybridTalentSystem.TrainerNpcEntry", 190010);
        BeaconItemEntry = sConfigMgr->GetOption<uint32>("HybridTalentSystem.BeaconItemEntry", 1915);
        GrantBeaconOnLogin = sConfigMgr->GetOption<bool>("HybridTalentSystem.GrantBeaconOnLogin", true);
        BeaconSummonDurationSeconds = sConfigMgr->GetOption<uint32>("HybridTalentSystem.BeaconSummonDurationSeconds", 300);
        RestoreOnLogin = sConfigMgr->GetOption<bool>("HybridTalentSystem.RestoreOnLogin", true);
        EnableSynergies = sConfigMgr->GetOption<bool>("HybridTalentSystem.EnableSynergies", true);
        AutoUpgradeRanks = sConfigMgr->GetOption<bool>("HybridTalentSystem.AutoUpgradeRanks", true);
        MirrorPetBuffs = sConfigMgr->GetOption<bool>("HybridTalentSystem.MirrorPetBuffs", true);
        MirrorGroupBuffs = sConfigMgr->GetOption<bool>("HybridTalentSystem.MirrorGroupBuffs", true);
        MirrorGroupBuffRange = sConfigMgr->GetOption<float>("HybridTalentSystem.MirrorGroupBuffRange", 100.0f);
        NormalizeClassBuffDuration = sConfigMgr->GetOption<bool>("HybridTalentSystem.NormalizeClassBuffDuration.Enable", false);
        NormalizeClassBuffDurationSeconds = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.NormalizeClassBuffDuration.Seconds", 1800), 60, 7200);
        CompanionAutoLoot = sConfigMgr->GetOption<bool>("HybridTalentSystem.CompanionAutoLoot.Enable", false);
        CompanionAutoLootRadius = std::clamp(sConfigMgr->GetOption<float>("HybridTalentSystem.CompanionAutoLoot.Radius", 10.0f), 1.0f, 40.0f);
        CompanionAutoLootIntervalMs = std::clamp<uint32>(sConfigMgr->GetOption<uint32>("HybridTalentSystem.CompanionAutoLoot.IntervalMs", 1500), 250, 10000);
        CompanionAutoLootOutOfCombatOnly = sConfigMgr->GetOption<bool>("HybridTalentSystem.CompanionAutoLoot.OutOfCombatOnly", true);
        CompanionAutoLootRequireNonCombatCompanion = sConfigMgr->GetOption<bool>("HybridTalentSystem.CompanionAutoLoot.RequireNonCombatCompanion", true);
        CompanionAutoLootPrioritizePlayerInGroups = sConfigMgr->GetOption<bool>("HybridTalentSystem.CompanionAutoLoot.PrioritizePlayerInGroups", false);
        PetBuffSpellIds = ParseSpellIdSet(sConfigMgr->GetOption<std::string>("HybridTalentSystem.PetBuffSpellIds",
            "1243,21562,14752,27681,976,27683,1459,23028,604,1008,19740,25782,19742,25894,20217,25898,1126,21849,467"));
        NormalizeClassBuffSpellIds = ParseSpellIdSet(sConfigMgr->GetOption<std::string>("HybridTalentSystem.NormalizeClassBuffDuration.SpellIds",
            "469,6673,1243,21562,14752,27681,976,27683,1459,23028,604,1008,19740,25782,19742,25894,20217,25898,1038,19977,20911,25899,1126,21849,467"));
        SpellDependencyGrants = ParseSpellDependencyGrantMap(sConfigMgr->GetOption<std::string>("HybridTalentSystem.SpellDependencyGrants",
            "1515:883,2641,982,6991,5149,1002,136;697:1120;712:1120;691:1120"));
        SpellDependencyItems = ParseSpellDependencyItemMap(sConfigMgr->GetOption<std::string>("HybridTalentSystem.SpellDependencyItems",
            ""));
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

        CharacterDatabase.Execute("CREATE TABLE IF NOT EXISTS `character_hybrid_spell_dependency` ("
            "`guid` INT UNSIGNED NOT NULL,"
            "`trigger_spell_id` INT UNSIGNED NOT NULL,"
            "`granted_spell_id` INT UNSIGNED NOT NULL,"
            "`learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`guid`, `trigger_spell_id`, `granted_spell_id`),"
            "KEY `idx_guid_granted_spell` (`guid`, `granted_spell_id`)"
            ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        CharacterDatabase.Execute("CREATE TABLE IF NOT EXISTS `character_hybrid_talent` ("
            "`guid` INT UNSIGNED NOT NULL,"
            "`talent_id` INT UNSIGNED NOT NULL,"
            "`rank` TINYINT UNSIGNED NOT NULL DEFAULT 1,"
            "`learned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
            "PRIMARY KEY (`guid`, `talent_id`)"
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

    std::string SanitizeAddonField(std::string text, std::size_t maxLength)
    {
        for (char& ch : text)
            if (ch == '\t' || ch == '\n' || ch == '\r' || ch == '|')
                ch = ' ';

        text = TruncateHybridText(text, maxLength);
        while (!text.empty() && std::isspace(static_cast<unsigned char>(text.back())))
            text.pop_back();

        return text;
    }

    bool StartsWithIgnoreCase(std::string const& text, std::string const& prefix)
    {
        if (text.length() < prefix.length())
            return false;

        for (std::size_t index = 0; index < prefix.length(); ++index)
            if (std::tolower(static_cast<unsigned char>(text[index])) != std::tolower(static_cast<unsigned char>(prefix[index])))
                return false;

        return true;
    }

    bool EqualsIgnoreCase(std::string const& left, std::string const& right)
    {
        if (left.length() != right.length())
            return false;

        for (std::size_t index = 0; index < left.length(); ++index)
            if (std::tolower(static_cast<unsigned char>(left[index])) != std::tolower(static_cast<unsigned char>(right[index])))
                return false;

        return true;
    }

    bool GetTalentRequiredHybridSpell(TalentEntry const* talentInfo, TalentTabEntry const* talentTabInfo, uint32& requiredSpellId, std::string& requiredSpellName)
    {
        requiredSpellId = 0;
        requiredSpellName.clear();

        if (!talentInfo || !talentTabInfo || !talentInfo->RankID[0])
            return false;

        SpellInfo const* talentSpellInfo = sSpellMgr->GetSpellInfo(talentInfo->RankID[0]);
        if (!talentSpellInfo)
            return false;

        std::string talentName = talentSpellInfo->SpellName[0];
        std::string const improvedPrefix = "Improved ";
        if (!StartsWithIgnoreCase(talentName, improvedPrefix))
            return false;

        std::string baseSpellName = talentName.substr(improvedPrefix.length());
        if (baseSpellName.empty())
            return false;

        for (auto const& pair : SpellTemplates)
        {
            HybridSpellTemplate const& templ = pair.second;
            if (templ.ClassMask != talentTabInfo->ClassMask)
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
            if (!spellInfo)
                continue;

            if (!EqualsIgnoreCase(spellInfo->SpellName[0], baseSpellName))
                continue;

            requiredSpellId = templ.SpellId;
            requiredSpellName = spellInfo->SpellName[0];
            return true;
        }

        return false;
    }

    bool PlayerMeetsTalentSpellRequirement(Player const* player, TalentEntry const* talentInfo, TalentTabEntry const* talentTabInfo, std::string* missingReason = nullptr)
    {
        if (!player)
            return false;

        uint32 requiredSpellId = 0;
        std::string requiredSpellName;
        if (!GetTalentRequiredHybridSpell(talentInfo, talentTabInfo, requiredSpellId, requiredSpellName))
            return true;

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        if (HasHybridSpellInChain(guid, requiredSpellId) || PlayerHasSpellInChain(player, requiredSpellId))
            return true;

        if (missingReason)
            *missingReason = "Requires " + requiredSpellName;

        return false;
    }

    uint32 GetHybridClassIndexForMask(uint32 classMask)
    {
        for (uint32 classIndex = 0; classIndex < HybridClasses.size(); ++classIndex)
            if (HybridClasses[classIndex].ClassMask == classMask)
                return classIndex;

        return 0;
    }

    std::vector<uint32> GetHybridUiSpellIds()
    {
        std::vector<uint32> spellIds;
        spellIds.reserve(SpellTemplates.size());

        for (auto const& pair : SpellTemplates)
            spellIds.push_back(pair.first);

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

    uint8 GetTalentMaxRank(TalentEntry const* talentInfo)
    {
        if (!talentInfo)
            return 0;

        uint8 maxRank = 0;
        for (uint8 rank = 0; rank < MAX_TALENT_RANK; ++rank)
            if (talentInfo->RankID[rank])
                maxRank = rank + 1;

        return maxRank;
    }

    uint8 GetKnownTalentRank(Player const* player, TalentEntry const* talentInfo)
    {
        if (!player || !talentInfo)
            return 0;

        for (int8 rank = MAX_TALENT_RANK - 1; rank >= 0; --rank)
            if (talentInfo->RankID[rank] && player->HasSpell(talentInfo->RankID[rank]))
                return rank + 1;

        return 0;
    }

    bool IsHybridTalentAllowedForPlayer(Player const* player, TalentEntry const* talentInfo, TalentTabEntry const* talentTabInfo)
    {
        if (!player || !talentInfo || !talentTabInfo)
            return false;

        if (player->GetLevel() < TalentMinLevel)
            return false;

        if (talentTabInfo->ClassMask & player->getClassMask())
            return false;

        return talentInfo->RankID[0] && sSpellMgr->GetSpellInfo(talentInfo->RankID[0]);
    }

    void RemoveHybridTalentActionButtons(Player* player, TalentEntry const* talentInfo)
    {
        if (!player || !talentInfo)
            return;

        for (uint8 rank = 0; rank < MAX_TALENT_RANK; ++rank)
            if (talentInfo->RankID[rank])
                RemoveHybridActionButtons(player, talentInfo->RankID[rank]);
    }

    void RemoveHybridTalentRanks(Player* player, TalentEntry const* talentInfo)
    {
        if (!player || !talentInfo)
            return;

        for (uint8 rank = 0; rank < MAX_TALENT_RANK; ++rank)
            if (talentInfo->RankID[rank] && player->HasSpell(talentInfo->RankID[rank]))
                player->removeSpell(talentInfo->RankID[rank], SPEC_MASK_ALL, false);
    }

    void RestoreHybridTalents(Player* player)
    {
        if (!player)
            return;

        bool restored = false;
        std::map<uint32, uint8> talentRanks = GetKnownHybridTalentRanks(player->GetGUID().GetCounter());
        for (auto const& pair : talentRanks)
        {
            TalentEntry const* talentInfo = sTalentStore.LookupEntry(pair.first);
            if (!talentInfo)
                continue;

            uint8 maxRank = GetTalentMaxRank(talentInfo);
            if (!maxRank)
                continue;

            uint8 rank = std::min<uint8>(pair.second, maxRank);
            if (!rank)
                continue;

            uint32 spellId = talentInfo->RankID[rank - 1];
            if (!spellId || !sSpellMgr->GetSpellInfo(spellId))
                continue;

            RemoveHybridTalentRanks(player, talentInfo);
            player->learnSpell(spellId, false);
            restored = true;
        }

        if (restored)
        {
            RestoreHybridActionButtons(player);
            player->SendActionButtons(1);
        }
    }

    void RefreshNativeTalentPoints(Player* player)
    {
        if (!player)
            return;

        player->InitTalentForLevel();
        player->SendTalentsInfoData(false);
    }

    std::vector<uint32> GetHybridUiTalentIds()
    {
        std::vector<uint32> talentIds;
        talentIds.reserve(sTalentStore.GetNumRows());

        for (uint32 talentId = 0; talentId < sTalentStore.GetNumRows(); ++talentId)
        {
            TalentEntry const* talentInfo = sTalentStore.LookupEntry(talentId);
            if (!talentInfo || !talentInfo->RankID[0])
                continue;

            TalentTabEntry const* talentTabInfo = sTalentTabStore.LookupEntry(talentInfo->TalentTab);
            if (!talentTabInfo || !talentTabInfo->ClassMask || talentTabInfo->petTalentMask)
                continue;

            if (!sSpellMgr->GetSpellInfo(talentInfo->RankID[0]))
                continue;

            talentIds.push_back(talentId);
        }

        std::sort(talentIds.begin(), talentIds.end(), [](uint32 leftTalentId, uint32 rightTalentId)
        {
            TalentEntry const* left = sTalentStore.LookupEntry(leftTalentId);
            TalentEntry const* right = sTalentStore.LookupEntry(rightTalentId);
            if (!left || !right)
                return leftTalentId < rightTalentId;

            TalentTabEntry const* leftTab = sTalentTabStore.LookupEntry(left->TalentTab);
            TalentTabEntry const* rightTab = sTalentTabStore.LookupEntry(right->TalentTab);
            uint32 leftClassMask = leftTab ? leftTab->ClassMask : 0;
            uint32 rightClassMask = rightTab ? rightTab->ClassMask : 0;
            if (leftClassMask != rightClassMask)
                return leftClassMask < rightClassMask;

            uint32 leftTabPage = leftTab ? leftTab->tabpage : 0;
            uint32 rightTabPage = rightTab ? rightTab->tabpage : 0;
            if (leftTabPage != rightTabPage)
                return leftTabPage < rightTabPage;

            if (left->Row != right->Row)
                return left->Row < right->Row;

            if (left->Col != right->Col)
                return left->Col < right->Col;

            SpellInfo const* leftInfo = sSpellMgr->GetSpellInfo(left->RankID[0]);
            SpellInfo const* rightInfo = sSpellMgr->GetSpellInfo(right->RankID[0]);
            std::string leftName = leftInfo ? leftInfo->SpellName[0] : std::to_string(leftTalentId);
            std::string rightName = rightInfo ? rightInfo->SpellName[0] : std::to_string(rightTalentId);
            return leftName < rightName;
        });

        return talentIds;
    }

    void SendHybridUiSnapshot(ChatHandler* handler, Player* player)
    {
        if (!handler || !player)
            return;

        if (!Enabled)
        {
            handler->PSendSysMessage("HYUI\tERROR\tHybrid Talent System is disabled.");
            return;
        }

        uint16 earned = CalculateEarnedPoints(player);
        uint16 spent = GetSpentPoints(player->GetGUID().GetCounter());
        uint16 available = earned > spent ? earned - spent : 0;
        uint16 talentEarned = CalculateEarnedTalentPoints(player);
        uint16 talentSpent = GetSpentTalentPoints(player->GetGUID().GetCounter());
        uint16 talentAvailable = talentEarned > talentSpent ? talentEarned - talentSpent : 0;
        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        std::vector<uint32> spellIds = GetHybridUiSpellIds();
        std::vector<uint32> talentIds = GetHybridUiTalentIds();

        handler->PSendSysMessage("HYUI\tBEGIN\t1\t{}\t{}\t{}\t{}", earned, spent, available, static_cast<uint32>(spellIds.size()));
        handler->PSendSysMessage("HYUI\tSTATUS\t{}\t{}\t{}\t{}\t{}\t{}", player->GetLevel(), MinLevel, PointsPerInterval, PointIntervalLevels ? PointIntervalLevels : 1, MaxPoints,
            GetNextPointLevel(player->GetLevel(), MinLevel, PointIntervalLevels, PointsPerInterval, MaxPoints));
        handler->PSendSysMessage("HYUI\tTALENTSTATUS\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}", talentEarned, talentSpent, talentAvailable, TalentMinLevel, TalentPointsPerInterval, TalentPointIntervalLevels ? TalentPointIntervalLevels : 1, TalentMaxPoints,
            GetNextPointLevel(player->GetLevel(), TalentMinLevel, TalentPointIntervalLevels, TalentPointsPerInterval, TalentMaxPoints));

        for (uint32 spellId : spellIds)
        {
            auto itr = SpellTemplates.find(spellId);
            if (itr == SpellTemplates.end())
                continue;

            HybridSpellTemplate const& templ = itr->second;
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(templ.SpellId);
            if (!spellInfo)
                continue;

            bool baseClassBlocked = templ.ClassMask && (templ.ClassMask & player->getClassMask());
            bool levelBlocked = player->GetLevel() < templ.RequiredLevel;
            bool alreadyKnownInSpellbook = PlayerHasSpellInChain(player, templ.SpellId);
            bool known = HasHybridSpellInChain(guid, templ.SpellId) || (!baseClassBlocked && alreadyKnownInSpellbook);
            bool pointsBlocked = available < templ.Cost;
            bool canLearn = !known && !baseClassBlocked && !levelBlocked && !alreadyKnownInSpellbook && !pointsBlocked;
            uint32 classIndex = GetHybridClassIndexForMask(templ.ClassMask);
            std::string reason;

            if (known)
                reason = "Known";
            else if (baseClassBlocked)
                reason = "Own class";
            else if (alreadyKnownInSpellbook)
                reason = "Already known";
            else if (levelBlocked)
                reason = "Requires level " + std::to_string(templ.RequiredLevel);
            else if (pointsBlocked)
                reason = "Needs " + std::to_string(templ.Cost) + " point" + (templ.Cost == 1 ? "" : "s");
            else
                reason = "Available";

            handler->PSendSysMessage("HYUI\tSPELL\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                templ.SpellId,
                classIndex,
                templ.RequiredLevel,
                templ.Cost,
                known ? 1 : 0,
                canLearn ? 1 : 0,
                SanitizeAddonField(spellInfo->SpellName[0], 48),
                SanitizeAddonField(GetHybridSpellDescription(templ), 110),
                SanitizeAddonField(reason, 40));
        }

        for (uint32 talentId : talentIds)
        {
            TalentEntry const* talentInfo = sTalentStore.LookupEntry(talentId);
            if (!talentInfo)
                continue;

            TalentTabEntry const* talentTabInfo = sTalentTabStore.LookupEntry(talentInfo->TalentTab);
            if (!talentTabInfo)
                continue;

            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(talentInfo->RankID[0]);
            if (!spellInfo)
                continue;

            uint32 classIndex = GetHybridClassIndexForMask(talentTabInfo->ClassMask);
            bool baseClassBlocked = talentTabInfo->ClassMask & player->getClassMask();
            uint8 maxRank = GetTalentMaxRank(talentInfo);
            uint8 savedRank = GetSavedHybridTalentRank(guid, talentInfo->TalentID);
            uint8 knownRank = baseClassBlocked ? savedRank : std::max(savedRank, GetKnownTalentRank(player, talentInfo));
            uint8 displayRank = knownRank < maxRank ? knownRank + 1 : maxRank;
            uint32 displaySpellId = talentInfo->RankID[displayRank ? displayRank - 1 : 0];
            if (!displaySpellId || !sSpellMgr->GetSpellInfo(displaySpellId))
                displaySpellId = talentInfo->RankID[0];

            bool levelBlocked = player->GetLevel() < TalentMinLevel;
            bool maxed = knownRank >= maxRank;
            std::string requirementReason;
            bool requirementBlocked = !PlayerMeetsTalentSpellRequirement(player, talentInfo, talentTabInfo, &requirementReason);
            bool pointsBlocked = talentAvailable < 1;
            bool canLearn = !baseClassBlocked && !levelBlocked && !maxed && !requirementBlocked && !pointsBlocked;
            std::string reason;

            if (baseClassBlocked)
                reason = "Own class";
            else if (maxed)
                reason = "Max rank";
            else if (levelBlocked)
                reason = "Requires level " + std::to_string(TalentMinLevel);
            else if (requirementBlocked)
                reason = requirementReason;
            else if (pointsBlocked)
                reason = "Needs 1 talent point";
            else
                reason = "Available";

            handler->PSendSysMessage("HYUI\tTALENT\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}\t{}",
                talentInfo->TalentID,
                displaySpellId,
                classIndex,
                talentTabInfo->tabpage,
                talentInfo->Row,
                talentInfo->Col,
                maxRank,
                knownRank,
                canLearn ? 1 : 0,
                SanitizeAddonField(spellInfo->SpellName[0], 48),
                SanitizeAddonField(reason, 40));
        }

        handler->PSendSysMessage("HYUI\tEND");
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
        RemoveHybridSpellDependencyGrants(player, spellId);
        RemoveHybridSpellDependencyItems(player, spellId);
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
        ApplyHybridSpellDependencyGrants(player, spellId, true);
        ApplyHybridSpellDependencyItems(player, spellId, true);
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

    bool TryLearnHybridTalent(Player* player, uint32 talentId)
    {
        if (!player)
            return false;

        TalentEntry const* talentInfo = sTalentStore.LookupEntry(talentId);
        if (!talentInfo)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That talent is not available.");
            return false;
        }

        TalentTabEntry const* talentTabInfo = sTalentTabStore.LookupEntry(talentInfo->TalentTab);
        if (!IsHybridTalentAllowedForPlayer(player, talentInfo, talentTabInfo))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not meet the requirements for that hybrid talent.");
            return false;
        }

        uint8 maxRank = GetTalentMaxRank(talentInfo);
        uint8 currentRank = GetSavedHybridTalentRank(player->GetGUID().GetCounter(), talentId);
        if (currentRank >= maxRank)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That hybrid talent is already at maximum rank.");
            return false;
        }

        std::string requirementReason;
        if (!PlayerMeetsTalentSpellRequirement(player, talentInfo, talentTabInfo, &requirementReason))
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not meet the requirements for that hybrid talent: {}.", requirementReason);
            return false;
        }

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint16 earned = CalculateEarnedTalentPoints(player);
        uint16 spent = GetSpentTalentPoints(guid);
        if (earned <= spent)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You do not have enough hybrid talent points.");
            return false;
        }

        uint8 nextRank = currentRank + 1;
        uint32 spellId = talentInfo->RankID[nextRank - 1];
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId);
        if (!spellInfo)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That hybrid talent rank is missing spell data.");
            return false;
        }

        RemoveHybridTalentRanks(player, talentInfo);
        SaveHybridTalent(guid, talentId, nextRank);
        player->learnSpell(spellId, false);
        RefreshNativeTalentPoints(player);

        ChatHandler(player->GetSession()).PSendSysMessage("{} learned at hybrid talent rank {}/{}.",
            spellInfo->SpellName[0], nextRank, maxRank);
        return true;
    }

    bool TryUnlearnHybridTalent(Player* player, uint32 talentId)
    {
        if (!player)
            return false;

        TalentEntry const* talentInfo = sTalentStore.LookupEntry(talentId);
        if (!talentInfo)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("That talent is not available.");
            return false;
        }

        ObjectGuid::LowType guid = player->GetGUID().GetCounter();
        uint8 currentRank = GetSavedHybridTalentRank(guid, talentId);
        if (!currentRank)
        {
            ChatHandler(player->GetSession()).PSendSysMessage("You have not learned that hybrid talent.");
            return false;
        }

        RemoveHybridTalentActionButtons(player, talentInfo);
        RemoveHybridTalentRanks(player, talentInfo);

        uint8 newRank = currentRank - 1;
        if (newRank)
        {
            uint32 spellId = talentInfo->RankID[newRank - 1];
            if (spellId && sSpellMgr->GetSpellInfo(spellId))
            {
                SaveHybridTalent(guid, talentId, newRank);
                player->learnSpell(spellId, false);
            }
            else
                DeleteHybridTalent(guid, talentId);
        }
        else
            DeleteHybridTalent(guid, talentId);

        RefreshNativeTalentPoints(player);

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(talentInfo->RankID[0]);
        ChatHandler(player->GetSession()).PSendSysMessage("{} hybrid talent rank unlearned. 1 hybrid talent point refunded.",
            spellInfo ? spellInfo->SpellName[0] : std::to_string(talentId));
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
    HybridTalentPlayerScript() : PlayerScript("HybridTalentPlayerScript", { PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_LEVEL_CHANGED, PLAYERHOOK_ON_UPDATE, PLAYERHOOK_ON_SAVE, PLAYERHOOK_ON_SPELL_CAST, PLAYERHOOK_ON_LOGOUT }) { }

    void OnPlayerLogin(Player* player) override
    {
        if (Enabled)
            GrantHybridBeacon(player);

        if (Enabled && RestoreOnLogin)
        {
            RestoreHybridSpells(player);
            RestoreHybridTalents(player);
            RefreshNativeTalentPoints(player);
            ScheduleHybridActionRestore(player);
        }
    }

    void OnPlayerLevelChanged(Player* player, uint8 /*oldLevel*/) override
    {
        if (Enabled)
        {
            SaveHybridActionButtons(player);
            RestoreHybridSpells(player);
            RestoreHybridTalents(player);
            RefreshNativeTalentPoints(player);
            SaveHybridActionButtons(player);
            ScheduleHybridActionRestore(player);
        }
    }

    void OnPlayerUpdate(Player* player, uint32 diff) override
    {
        if (Enabled)
        {
            ProcessHybridActionRestore(player, diff);
            ProcessCompanionAutoLoot(player, diff);
        }
    }

    void OnPlayerSave(Player* player) override
    {
        if (Enabled)
            SaveHybridActionButtons(player);
    }

    void OnPlayerSpellCast(Player* player, Spell* spell, bool /*skipCheck*/) override
    {
        MirrorBuffToPetAndGroup(player, spell);
    }

    void OnPlayerLogout(Player* player) override
    {
        if (!player)
            return;

        CompanionAutoLootTimers.erase(player->GetGUID().GetCounter());
    }
};

class HybridTalentUnitScript : public UnitScript
{
public:
    HybridTalentUnitScript() : UnitScript("HybridTalentUnitScript", true, { UNITHOOK_ON_AURA_APPLY }) { }

    void OnAuraApply(Unit* unit, Aura* aura) override
    {
        if (!unit || !aura)
            return;

        NormalizeBuffDuration(unit, aura->GetId());
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
            uint16 talentEarned = CalculateEarnedTalentPoints(player);
            uint16 talentSpent = GetSpentTalentPoints(player->GetGUID().GetCounter());
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid points: {} earned, {} spent, {} available.", earned, spent, earned > spent ? earned - spent : 0);
            ChatHandler(player->GetSession()).PSendSysMessage("Hybrid talent points: {} earned, {} spent, {} available.", talentEarned, talentSpent, talentEarned > talentSpent ? talentEarned - talentSpent : 0);
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

        static ChatCommandTable hybridUiCommands =
        {
            { "refresh",       HandleHybridUiRefreshCommand,       SEC_PLAYER, Console::No },
            { "learn",         HandleHybridUiLearnCommand,         SEC_PLAYER, Console::No },
            { "unlearn",       HandleHybridUiUnlearnCommand,       SEC_PLAYER, Console::No },
            { "learntalent",   HandleHybridUiLearnTalentCommand,   SEC_PLAYER, Console::No },
            { "unlearntalent", HandleHybridUiUnlearnTalentCommand, SEC_PLAYER, Console::No }
        };

        static ChatCommandTable commandTable =
        {
            { "hybrid", hybridCommands },
            { "hybridui", hybridUiCommands }
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

    static bool HandleHybridUiRefreshCommand(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        SendHybridUiSnapshot(handler, player);
        return true;
    }

    static bool HandleHybridUiLearnCommand(ChatHandler* handler, uint32 spellId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        TryLearnHybridSpell(player, spellId);
        SendHybridUiSnapshot(handler, player);
        return true;
    }

    static bool HandleHybridUiUnlearnCommand(ChatHandler* handler, uint32 spellId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        TryUnlearnHybridSpell(player, spellId);
        SendHybridUiSnapshot(handler, player);
        return true;
    }

    static bool HandleHybridUiLearnTalentCommand(ChatHandler* handler, uint32 talentId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        TryLearnHybridTalent(player, talentId);
        SendHybridUiSnapshot(handler, player);
        return true;
    }

    static bool HandleHybridUiUnlearnTalentCommand(ChatHandler* handler, uint32 talentId)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        TryUnlearnHybridTalent(player, talentId);
        SendHybridUiSnapshot(handler, player);
        return true;
    }
};

void AddHybridTalentSystemScripts()
{
    new HybridTalentWorldScript();
    new HybridTalentPlayerScript();
    new HybridTalentUnitScript();
    new HybridTalentCommandScript();
}
