local addonName, ns = ...

-- Init : namespace, base de données et utilitaires partagés.

ViewerLogDB = ViewerLogDB or {}

-- Table publique, peuplée par api/API.lua une fois les scanners chargés.
_G.ViewerLogAPI = {}

-- Version du contrat d'API publique (≠ version .toc). À incrémenter sur
-- tout changement cassant de l'API ou du format ViewerLogDB.
ns.API_VERSION = 2

-- ── Clés réservées dans ViewerLogDB (non-realms) ────────────

local RESERVED_KEYS = {
    settings                = true,
    guilds                  = true,
    -- Héritées d'anciennes SavedVariables (plus écrites, gardées pour ignorer
    -- proprement une DB migrée depuis une version antérieure).
    warbandBank             = true,
    warbandGold             = true,
    warbandCustomCategories = true,
    profFileIDs             = true,
    disable2DPreview        = true,
    hiddenExpansions        = true,
    hiddenProfessions       = true,
    woodPanelEnabled        = true,
    -- Module ViewerLog_Housing
    housing                 = true,
}

-- true si la clé est un royaume de joueurs.
function ns.IsRealm(key, value)
    if RESERVED_KEYS[key]      then return false end
    if type(value) ~= "table"  then return false end
    return true
end

-- Forever : le royaume n'existe plus, la clé devient le ruleset et le nom
-- prend le nom de famille.
local function GetRulesetName()
    local active, rule = C_GameRules.IsGameRuleActive, Enum.GameRule
    local pvp = rule.PvPRuleset and active(rule.PvPRuleset)
    local rp  = rule.RPRuleset and active(rule.RPRuleset)
    if pvp and rp then return "RPPvP" end
    if pvp then return "PvP" end
    if rp then return "RP" end
    if rule.HardcoreRuleset and active(rule.HardcoreRuleset) then return "HC" end
    return "PvE"
end

-- (realm, nom) du perso connecté, mis en cache une fois valide.
local _realm, _name
function ns.GetPlayerIdentity()
    if _name then return _realm, _name end
    local name, extra = UnitName("player")
    if not name or name == "" then return nil, nil end

    local realm
    if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
        local sep = Constants and Constants.CharacterNameSeparatorConsts
            and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
        if not (sep and extra and extra ~= "") then return nil, nil end
        name  = name .. sep .. extra
        realm = GetRulesetName()
    else
        realm = GetRealmName()
        if not realm or realm == "" then return nil, nil end
    end
    _realm, _name = realm, name
    return realm, name
end

-- (charData, realm, player) du perso connecté ; crée les entrées manquantes.
function ns.GetCurrentCharData()
    local realm, player = ns.GetPlayerIdentity()
    if not realm then return nil, nil, nil end
    ViewerLogDB[realm]         = ViewerLogDB[realm] or {}
    ViewerLogDB[realm][player] = ViewerLogDB[realm][player] or {}
    return ViewerLogDB[realm][player], realm, player
end

-- ── Commandes slash ──────────────────────────────────────────

SLASH_VIEWERLOG1 = "/vl"
SLASH_VIEWERLOG2 = "/viewerlog"

SlashCmdList["VIEWERLOG"] = function(msg)
    msg = msg and strtrim(msg:lower()) or ""
    -- Scans des dépendances : posés sur _G.ViewerLogAPI une fois chargées.
    local vlAPI = _G.ViewerLogAPI

    if msg == "options" or msg == "opt" or msg == "config" then
        if ns.OpenOptions then ns.OpenOptions() end

    elseif msg == "scan" then
        if vlAPI and vlAPI.ScanItems then vlAPI.ScanItems() end
        if vlAPI and vlAPI.ScanBasicProfessions then vlAPI.ScanBasicProfessions() end
        print("|cff9955ff[ViewerLog]|r " .. ns.L("SLASH_SCAN_DONE"))

    elseif msg == "reput" then
        if vlAPI and vlAPI.ScanReputations then
            vlAPI.ScanReputations()
            print("|cff9955ff[ViewerLog]|r " .. ns.L("SLASH_REPUT_SCAN_DONE"))
        else
            print("|cff9955ff[ViewerLog]|r " .. ns.L("SLASH_REPUT_NONE"))
        end

    elseif msg == "guild" then
        if vlAPI and vlAPI.ScanGuildBank then
            vlAPI.ScanGuildBank()
            print("|cff9955ff[ViewerLog]|r " .. ns.L("SLASH_GUILD_SCAN_STARTED"))
        else
            print("|cff9955ff[ViewerLog]|r " .. ns.L("SLASH_GUILD_NONE_OPEN"))
        end

    else
        print("|cff9955ff[ViewerLog]|r" .. ns.L("SLASH_HELP_OPTIONS"))
        print("|cff9955ff[ViewerLog]|r" .. ns.L("SLASH_HELP_SCAN"))
        print("|cff9955ff[ViewerLog]|r" .. ns.L("SLASH_HELP_REPUT"))
        print("|cff9955ff[ViewerLog]|r" .. ns.L("SLASH_HELP_GUILD"))
    end
end
