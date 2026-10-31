local addonName, ns = ...

-- API publique (lecture seule), accessible via _G.ViewerLogAPI.
-- Les données ne se modifient que via les scanners.

-- ── Utilitaires ───────────────────────────────────────────────────

local function SplitKey(key)
    return key:match("^(.+)@(.+)$")
end

-- ── État général ──────────────────────────────────────────────────

function ns.IsReady()
    return ViewerLogDB ~= nil
end

function ns.OpenOptionsPanel()
    if ns.OpenOptions then ns.OpenOptions() end
end

-- ── Personnages ───────────────────────────────────────────────────

-- Liste des clés "Nom@Realm".
function ns.GetAllCharacters()
    local list = {}
    for realmName, realmData in pairs(ViewerLogDB) do
        if ns.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" then
                    list[#list + 1] = charName .. "@" .. realmName
                end
            end
        end
    end
    return list
end

function ns.GetCharacterByKey(key)
    local charName, realmName = SplitKey(key)
    if not charName then return nil end
    return ViewerLogDB[realmName] and ViewerLogDB[realmName][charName]
end

function ns.GetCharacter(charName, realmName)
    return ViewerLogDB[realmName] and ViewerLogDB[realmName][charName]
end

-- ── Inventaire ────────────────────────────────────────────────────
-- Format sacs/banque : { [bagIndex] = { [slot] = { id, count } } }

function ns.GetBags(charName, realmName)
    local d = ns.GetCharacter(charName, realmName)
    return d and d.bags
end

function ns.GetBank(charName, realmName)
    local d = ns.GetCharacter(charName, realmName)
    return d and d.bank
end

-- ── Or (en cuivres) ───────────────────────────────────────────────

function ns.GetGold(charName, realmName)
    local d = ns.GetCharacter(charName, realmName)
    return d and d.gold or 0
end

-- ── Guildes ───────────────────────────────────────────────────────
-- Format : { ["NomGuilde@Realm"] = { guildName, realm, scanTime, tabs } }

function ns.GetAllGuilds()
    return ViewerLogDB.guilds
end

function ns.GetGuild(guildKey)
    return ViewerLogDB.guilds and ViewerLogDB.guilds[guildKey]
end

-- Réimplémentée ici (et non déléguée à ViewerLog_Guild) pour rester
-- fonctionnelle même sans cette dépendance : nettoyage de données résiduelles.
function ns.DeleteGuildData(guildKey)
    if not guildKey or not ViewerLogDB.guilds or not ViewerLogDB.guilds[guildKey] then
        return false
    end
    ViewerLogDB.guilds[guildKey] = nil
    ns.InvalidateIndexAll()
    return true
end

-- ── Infobulles ────────────────────────────────────────────────────

-- Infos de possession pour un itemID (via index pré-construit, O(1)).
function ns.GetInventoryInfo(itemID)
    return ns.tooltipIndex and ns.tooltipIndex[itemID]
end

function ns.RefreshIndex()
    ns.InvalidateIndexAll()
end

-- ── Personnage courant ────────────────────────────────────────────

function ns.GetCurrentCharacterKey()
    local player = UnitName("player")
    local realm  = GetRealmName()
    if player and realm then
        return player .. "@" .. realm
    end
    return nil
end

-- ── Réputations ───────────────────────────────────────────────────
-- Format : { [factionID] = { name, reaction, standing, bottom, top,
--   isAccountWide, isMajor, renown, renownEarned, renownCap, maxRenown,
--   isUnlocked, paragonValue, paragonCap, paragonLevel, paragonReady,
--   updatedAt } }
function ns.GetReputations(charName, realmName)
    local d = ns.GetCharacter(charName, realmName)
    return d and d.reputations
end

-- ── Suppression ───────────────────────────────────────────────────

-- Supprime un perso et invalide l'index tooltip.
function ns.DeleteCharacter(realm, char)
    if not realm or not char then return false end
    if ViewerLogDB[realm] and ViewerLogDB[realm][char] then
        ViewerLogDB[realm][char] = nil
        if not next(ViewerLogDB[realm]) then
            ViewerLogDB[realm] = nil
        end
        ns.InvalidateIndexAll()
        return true
    end
    return false
end

-- ── XP reposé ────────────────────────────────────────────────────

-- % de XP reposé estimé (projection temporelle, fonctionne hors ligne).
function ns.GetEstimatedRestedPct(charName, realmName)
    local d = ns.GetCharacter(charName, realmName)
    if not d then return nil end
    return ns.EstimateRestedPct(d.rested, d.maxXP)
end

-- ── Icônes de faction ────────────────────────────────────────────
-- Interface\Icons\inv_misc_tournaments_banner_orc / ...symbol_human (icônes
-- du tournoi Argent, ajoutées en Mists of Pandaria) sont absentes des
-- données client sur TBC Classic et MoP Classic → on bascule sur
-- Interface\TargetingFrame\UI-PVP-Horde / UI-PVP-Alliance (texture du cadre
-- joueur de Blizzard, présente depuis Vanilla) uniquement pour ces deux
-- versions. WoW Forever (build 1.60.x) et les autres flavors Classic
-- gardent les icônes d'origine, non signalées comme cassées.
-- Calculé une seule fois au chargement, pas à chaque appel.
local IS_TBC_OR_MOP = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
                    or WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

local FACTION_ICON_PATH = IS_TBC_OR_MOP and {
    Horde    = "Interface\\TargetingFrame\\UI-PVP-Horde",
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
} or {
    Horde    = "Interface\\Icons\\inv_misc_tournaments_banner_orc",
    Alliance = "Interface\\Icons\\Inv_misc_tournaments_symbol_human",
}

-- Chemin de texture brut (sans balise |T|t), déjà adapté à la version
-- cliente. Second retour : true si c'est le jeu d'icônes "de secours"
-- (TargetingFrame), pour que l'appelant puisse l'afficher plus grand.
-- nil si faction inconnue.
function ns.GetFactionIconPath(faction)
    return FACTION_ICON_PATH[faction], IS_TBC_OR_MOP
end

-- ── Table d'API publique ──────────────────────────────────────────
-- Peuple _G.ViewerLogAPI (créée vide par core/Init.lua). Seules ces
-- fonctions sont exposées ; le namespace interne (ns) reste privé.
-- GetCurrentCharData / InvalidateIndex sont exposées pour les dépendances
-- (Guild / Reput / Professions), qui ont leur propre ns.
local pub = _G.ViewerLogAPI
pub.API_VERSION                 = ns.API_VERSION
pub.L                           = ns.L
pub.IsReady                     = ns.IsReady
pub.IsRealm                     = ns.IsRealm
pub.OpenOptionsPanel            = ns.OpenOptionsPanel
pub.GetAllCharacters            = ns.GetAllCharacters
pub.GetCharacterByKey           = ns.GetCharacterByKey
pub.GetCharacter                = ns.GetCharacter
pub.GetCurrentCharData          = ns.GetCurrentCharData
pub.GetBags                     = ns.GetBags
pub.GetBank                     = ns.GetBank
pub.GetGold                     = ns.GetGold
pub.GetAllGuilds                = ns.GetAllGuilds
pub.GetGuild                    = ns.GetGuild
pub.DeleteGuildData              = ns.DeleteGuildData
pub.DeleteCharacter             = ns.DeleteCharacter
pub.GetInventoryInfo            = ns.GetInventoryInfo
-- Exposée pour l'addon ViewerLog_Tooltip (applique les rebuilds lazy avant lecture).
pub.GetTooltipEntry             = ns.GetTooltipEntry
pub.RefreshIndex                = ns.RefreshIndex
pub.InvalidateIndex             = ns.InvalidateIndex
pub.GetCurrentCharacterKey      = ns.GetCurrentCharacterKey
pub.GetReputations              = ns.GetReputations
pub.GetEstimatedRestedPct       = ns.GetEstimatedRestedPct
pub.GetFactionIconPath          = ns.GetFactionIconPath
-- ScanGuildBank / ScanReputations / RegisterProfessionsCallback ne sont plus
-- posées ici : chaque dépendance les ajoute elle-même sur cette table après
-- son chargement (garanti par RequiredDeps). Absentes si non installée.
