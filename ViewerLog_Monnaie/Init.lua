local addonName, ns = ...

-- Init ViewerLog_Monnaie : dépendance optionnelle de ViewerLog.
-- Écoute CURRENCY_DISPLAY_UPDATE et déclenche scanner/Currency.lua.
-- ns et event frame propres, flag logout local → dépendance autonome ;
-- partage seulement ViewerLogDB.

local frame = CreateFrame("Frame", "ViewerLog_Monnaie_EventFrame")
local _isLoggingOut = false

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        _isLoggingOut = false
        -- Scan initial différé : garantit des données même pour un
        -- personnage qui ne gagne aucune monnaie cette session.
        C_Timer.After(5, function() ns.ScanCurrencies() end)

    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        _isLoggingOut = true
        ns.ScanCurrencies()

    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        -- Peut se déclencher en rafale (plusieurs monnaies gagnées
        -- d'un coup) ; le debounce de 1.5 s interne à Currency.lua
        -- absorbe la rafale.
        if not _isLoggingOut then
            ns.ScanCurrencies(true)
        end
    end
end)

-- ── Exposition sur l'API partagée ───────────────────────────────────
-- _G.ViewerLogAPI existe déjà (core chargé avant, via RequiredDeps).
-- ScanCurrencies / GetCurrencies sont définies entièrement ici : le core
-- ignore les monnaies, désinstaller ce dossier retire la fonctionnalité.
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.ScanCurrencies = ns.ScanCurrencies
    _G.ViewerLogAPI.GetCurrencies  = ns.GetCurrencies
end
