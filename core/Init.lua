local addonName, ns = ...

-- Init : namespace, base de données et utilitaires partagés.

ViewerLogDB = ViewerLogDB or {}

-- Table publique, peuplée par api/API.lua une fois les scanners chargés.
_G.ViewerLogAPI = {}

-- Version du contrat d'API publique (≠ version .toc). À incrémenter sur
-- tout changement cassant de l'API ou du format ViewerLogDB.
ns.API_VERSION = 1

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

-- (charData, realm, player) du perso connecté ; crée les entrées manquantes.
function ns.GetCurrentCharData()
    local realm  = GetRealmName()
    local player = UnitName("player")
    if not realm or realm == "" or not player or player == "" then
        return nil, nil, nil
    end
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
        ns.ScanBags("MANUAL")
        ns.ScanBank()
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
