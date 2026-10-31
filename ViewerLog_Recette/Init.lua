local addonName, ns = ...

-- Init ViewerLog_Recette : dépendance optionnelle de ViewerLog.
-- Écoute TRADE_SKILL_SHOW / TRADE_SKILL_LIST_UPDATE et déclenche
-- scanner/Recipes.lua. ns et event frame propres ; partage ViewerLogDB.
-- Purement réactif à l'ouverture d'une fenêtre de métier (rien au login/logout).

local frame = CreateFrame("Frame", "ViewerLog_Recette_EventFrame")

frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_LIST_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRADE_SKILL_SHOW" then
        -- Court délai : laisse la liste de recettes se peupler avant lecture.
        C_Timer.After(0.5, function() ns.ScanOpenProfessionRecipes() end)

    elseif event == "TRADE_SKILL_LIST_UPDATE" then
        -- Peut se répéter fenêtre ouverte (apprentissage, filtre) ;
        -- debounce 1 s interne à Recipes.lua.
        ns.ScanOpenProfessionRecipes(true)
    end
end)

-- ── Exposition sur l'API partagée ───────────────────────────────────
-- _G.ViewerLogAPI existe déjà (core chargé avant, via RequiredDeps).
-- ScanOpenProfessionRecipes / GetRecipes définies entièrement ici : le core
-- ignore les recettes, désinstaller ce dossier retire la fonctionnalité.
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.ScanOpenProfessionRecipes = ns.ScanOpenProfessionRecipes
    _G.ViewerLogAPI.GetRecipes                = ns.GetRecipes
end
