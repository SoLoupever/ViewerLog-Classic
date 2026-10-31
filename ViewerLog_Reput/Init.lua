local addonName, ns = ...

-- Init ViewerLog_Reput : écoute les événements de réputation et déclenche
-- le scanner. Partage ViewerLogDB.

local frame = CreateFrame("Frame", "ViewerLog_Reput_EventFrame")
local _isLoggingOut = false
local _hasScanned   = false

-- Événements de changement de réputation → scan debouncé.
local REP_CHANGE_EVENTS = {
    UPDATE_FACTION                     = true,
    QUEST_LOG_UPDATE                   = true,
    MAJOR_FACTION_RENOWN_LEVEL_CHANGED = true,
    MAJOR_FACTION_UNLOCKED             = true,
}

-- MAJOR_FACTION_* n'existe pas sur tous les clients Classic (Renown = Dragonflight+).
-- IsEventValid filtre proprement, pcall en filet de sécurité si l'API est absente.
local function SafeRegisterEvent(f, event)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then
        return
    end
    pcall(f.RegisterEvent, f, event)
end

SafeRegisterEvent(frame, "PLAYER_LOGIN")
SafeRegisterEvent(frame, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(frame, "PLAYER_LOGOUT")
SafeRegisterEvent(frame, "PLAYER_LEAVING_WORLD")
for ev in pairs(REP_CHANGE_EVENTS) do
    SafeRegisterEvent(frame, ev)
end

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Scan initial différé (1×/session), en mode étalé.
        if not _hasScanned then
            _hasScanned = true
            C_Timer.After(5, function() ns.ScanReputations(true) end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Se redéclenche après chaque écran de chargement : sert
        -- juste à annuler le flag posé par PLAYER_LEAVING_WORLD lors
        -- d'un simple changement de zone. Pas de scan ici.
        _isLoggingOut = false

    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        -- Sauvegarde finale synchrone (le jeu peut se fermer juste après).
        _isLoggingOut = true
        ns.ScanReputations()

    elseif REP_CHANGE_EVENTS[event] then
        -- Debounce 2 s + écriture différentielle (dans le scanner)
        -- absorbent les rafales et évitent de réécrire l'inchangé.
        if not _isLoggingOut then
            ns.ScanReputations(true)
        end
    end
end)

-- Exposition sur l'API partagée (consommée par AltViewerLog_Reput).
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.ScanReputations = ns.ScanReputations
end
