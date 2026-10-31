local addonName, ns = ...

-- Init ViewerLog_Professions : dépendance optionnelle de ViewerLog.
-- Scan de base (scanner/Professions.lua) et approfondi (scanner/Deep.lua)
-- des métiers. ns et event frame propres ; données via ViewerLogAPI.

local frame = CreateFrame("Frame", "ViewerLog_Professions_EventFrame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("TRADE_SKILL_SHOW")

frame:SetScript("OnEvent", function(self, event, ...)

    -- PLAYER_LOGIN : GetProfessions() est fiable seulement ~8 s après
    -- login (délai géré en interne par ns.OnProfessionsLogin).
    if event == "PLAYER_LOGIN" then
        ns.OnProfessionsLogin()
        ns.OnDeepLogin()

    -- SKILL_LINES_CHANGED : gain de rang ou changement de métier.
    -- Chaque scanner gère son propre debounce (3 s).
    elseif event == "SKILL_LINES_CHANGED" then
        ns.OnSkillLinesChanged()
        ns.OnDeepSkillLines()

    -- TRADE_SKILL_SHOW : panneau métier ouvert → scan approfondi passif.
    elseif event == "TRADE_SKILL_SHOW" then
        ns.OnTradeSkillShow()
    end
end)

-- ── Exposition sur l'API partagée ───────────────────────────────
-- RegisterProfessionsCallback : consommée par AltViewerLog.
-- ScanBasicProfessions : consommée par /vl scan (core).
-- ScanAllProfessions : scan approfondi, consommée par AltViewerLog_Professions.
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.RegisterProfessionsCallback = ns.RegisterProfessionsCallback
    _G.ViewerLogAPI.ScanBasicProfessions        = ns.ScanBasicProfessions
    _G.ViewerLogAPI.ScanAllProfessions          = ns.ScanAllProfessions
end
