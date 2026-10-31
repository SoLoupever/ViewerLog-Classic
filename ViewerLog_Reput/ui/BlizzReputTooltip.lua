local addonName, ns = ...

-- UI / INFOBULLE BLIZZARD — Perso le plus avancé
-- Au survol d'une faction (fenêtre native), ajoute au tooltip le perso
-- du compte le plus avancé. Lecture seule, additif (OnEnter natif).

local LOCALES = {
    frFR = { BEST_CHAR = "Plus avancé :", CHAR = "%s (%s)" },
    enUS = { BEST_CHAR = "Most advanced:", CHAR = "%s (%s)" },
}
local function T()
    local lang = (ViewerLogDB and ViewerLogDB.settings and ViewerLogDB.settings.lang)
                 or GetLocale()
    return LOCALES[lang] or LOCALES.enUS
end

-- Comparaison par palier strict (renom/réaction, puis paragon).
local function IsMoreAdvanced(d, best)
    if not best then return true end
    if d.isMajor then
        if (d.renown or 0) ~= (best.renown or 0) then
            return (d.renown or 0) > (best.renown or 0)
        end
        return (d.paragonLevel or 0) > (best.paragonLevel or 0)
    end
    if (d.reaction or 0) ~= (best.reaction or 0) then
        return (d.reaction or 0) > (best.reaction or 0)
    end
    if (d.standing or 0) ~= (best.standing or 0) then
        return (d.standing or 0) > (best.standing or 0)
    end
    return (d.paragonLevel or 0) > (best.paragonLevel or 0)
end

local function GetBestCharacter(fid)
    local api = _G.ViewerLogAPI
    if not api or not api.IsReady or not api.IsReady() or not fid then return nil end
    local bChar, bRealm, bClass, bData
    for _, key in ipairs(api.GetAllCharacters()) do
        local cData = api.GetCharacterByKey(key)
        local d = cData and cData.reputations and cData.reputations[fid]
        if d and IsMoreAdvanced(d, bData) then
            local c, r = key:match("^(.+)@(.+)$")
            bChar, bRealm, bClass, bData = c, r, cData.class, d
        end
    end
    return bChar, bRealm, bClass, bData
end

if _G.ViewerLogAPI then
    _G.ViewerLogAPI.GetBestReputationCharacter = GetBestCharacter
end

-- Libellé de rang, via chaînes Blizzard (localisées automatiquement).
local function RankLabel(d)
    if d.isMajor then
        return (RENOWN_LEVEL_LABEL or "Renown %d"):format(d.renown or 0)
    end
    return _G["FACTION_STANDING_LABEL" .. (d.reaction or 4)] or ""
end

-- ── Ajoute la ligne au tooltip ───────────────────────────────────
local function AppendBestCharLine(tooltip, fid, isAccountWide)
    if not fid then return end
    -- Réputation de compte : valeur partagée → pas de « meilleur perso ».
    if isAccountWide then return end
    if C_Reputation and C_Reputation.IsAccountWideReputation
       and C_Reputation.IsAccountWideReputation(fid) then
        return
    end

    local bChar, bRealm, bClass, bData = GetBestCharacter(fid)
    if not bChar or not bData then return end
    -- Inutile si c'est le perso connecté (déjà affiché par Blizzard).
    if bChar == UnitName("player") and bRealm == GetRealmName() then return end

    local t  = T()
    local cc = (bClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[bClass])
               or NORMAL_FONT_COLOR
    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(t.BEST_CHAR, t.CHAR:format(bChar, bRealm),
        0.70, 0.70, 0.70, cc.r, cc.g, cc.b)
    tooltip:AddLine(RankLabel(bData), 0.70, 0.70, 0.70)
    tooltip:Show()
end

-- factionID d'une ligne de la ScrollBox (nil pour un header).
local function GetRowFaction(row)
    local ed  = row.elementData or (row.GetElementData and row:GetElementData())
    local fid = row.factionID or (ed and ed.factionID)
    return fid, ed and ed.isAccountWide
end

-- Accroché APRÈS le OnEnter natif : le tooltip est déjà rempli.
local function OnRowEnter(row)
    if not GameTooltip:IsShown() then return end
    AppendBestCharLine(GameTooltip, GetRowFaction(row))
end

-- Accroche (une fois) chaque ligne visible.
local function HookVisibleRows()
    local sb = _G.ReputationFrame and _G.ReputationFrame.ScrollBox
    if not sb or not sb.EnumerateFrames then return end
    for _, row in sb:EnumerateFrames() do
        if row and not row.__avlRepHooked and row.HookScript then
            row.__avlRepHooked = true
            row:HookScript("OnEnter", OnRowEnter)
        end
    end
end

-- Mise en place (une seule fois).
local _wired = false
local function SetupHook()
    if _wired then return true end
    local repFrame = _G.ReputationFrame
    if not repFrame then return false end
    _wired = true

    -- hooksecurefunc + hook différé : hors du chemin sécurisé Blizzard
    -- (pas de taint, contrairement à RegisterCallback).
    local function DeferHook() C_Timer.After(0, HookVisibleRows) end

    local sb = repFrame.ScrollBox
    if sb and sb.Update then
        hooksecurefunc(sb, "Update", DeferHook)   -- nouvelles lignes au scroll/refresh
    end
    repFrame:HookScript("OnShow", DeferHook)
    DeferHook()
    return true
end

-- ReputationFrame est chargée à la demande (Blizzard_ReputationFrame).
if not SetupHook() then
    local loader = CreateFrame("Frame")
    loader:RegisterEvent("PLAYER_LOGIN")
    loader:RegisterEvent("ADDON_LOADED")
    loader:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" and arg1 ~= "Blizzard_ReputationFrame" then return end
        if SetupHook() then
            self:UnregisterAllEvents()
            self:SetScript("OnEvent", nil)
        end
    end)
end
