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

-- ── Callbacks ─────────────────────────────────────────────────────
-- Notifie les modules sans les connaître.
-- Événements : CHARACTER_DELETED(realm, char), GUILD_DELETED(guildKey).
local listeners = {}

function ns.RegisterCallback(event, fn)
    if type(event) ~= "string" or type(fn) ~= "function" then return false end
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
    end
    list[#list + 1] = fn
    return true
end

local function Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

-- ── Personnages ───────────────────────────────────────────────────

-- cb(charName, realmName, charData) pour chaque personnage connu.
function ns.ForEachCharacter(cb)
    for realmName, realmData in pairs(ViewerLogDB) do
        if ns.IsRealm(realmName, realmData) then
            for charName, charData in pairs(realmData) do
                if type(charData) == "table" then cb(charName, realmName, charData) end
            end
        end
    end
end

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
-- Notifie les modules (GUILD_DELETED).
function ns.DeleteGuildData(guildKey)
    if not guildKey or not ViewerLogDB.guilds or not ViewerLogDB.guilds[guildKey] then
        return false
    end
    ViewerLogDB.guilds[guildKey] = nil
    Fire("GUILD_DELETED", guildKey)
    return true
end

-- ── Personnage courant ────────────────────────────────────────────

function ns.GetCurrentCharacterKey()
    local realm, player = ns.GetPlayerIdentity()
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

-- Supprime un perso et notifie les modules (CHARACTER_DELETED).
function ns.DeleteCharacter(realm, char)
    if not realm or not char then return false end
    if ViewerLogDB[realm] and ViewerLogDB[realm][char] then
        ViewerLogDB[realm][char] = nil
        if not next(ViewerLogDB[realm]) then
            ViewerLogDB[realm] = nil
        end
        Fire("CHARACTER_DELETED", realm, char)
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
-- GetCurrentCharData / ForEachCharacter / RegisterCallback sont exposées pour
-- les dépendances (Items / Guild / Reput / Professions), qui ont leur propre ns.
-- GetBags / GetBank / GetInventoryInfo / GetTooltipEntry / InvalidateIndex / ScanItems
-- sont posées par ViewerLog_Items (absentes si non installé).
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
pub.ForEachCharacter            = ns.ForEachCharacter
pub.RegisterCallback            = ns.RegisterCallback
pub.GetGold                     = ns.GetGold
pub.GetAllGuilds                = ns.GetAllGuilds
pub.GetGuild                    = ns.GetGuild
pub.DeleteGuildData              = ns.DeleteGuildData
pub.DeleteCharacter             = ns.DeleteCharacter
pub.GetCurrentCharacterKey      = ns.GetCurrentCharacterKey
pub.GetPlayerIdentity           = ns.GetPlayerIdentity
pub.GetReputations              = ns.GetReputations
pub.GetEstimatedRestedPct       = ns.GetEstimatedRestedPct
pub.GetFactionIconPath          = ns.GetFactionIconPath
-- ScanGuildBank / ScanReputations / RegisterProfessionsCallback ne sont plus
-- posées ici : chaque dépendance les ajoute elle-même sur cette table après
-- son chargement (garanti par RequiredDeps). Absentes si non installée.
