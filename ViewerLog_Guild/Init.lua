local addonName, ns = ...

-- Init ViewerLog_Guild : dépendance optionnelle de ViewerLog.
-- Écoute les événements du coffre de guilde et déclenche scanner/Guild.lua.
-- ns et event frame propres (isolée du core), mais partage ViewerLogDB.

local frame = CreateFrame("Frame", "ViewerLog_Guild_EventFrame")

frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")       -- slots changés
frame:RegisterEvent("GUILDBANK_UPDATE_TABS")           -- onglets ajoutés/modifiés
frame:RegisterEvent("GUILDBANK_UPDATE_MONEY")          -- dépôt d'or
frame:RegisterEvent("GUILDBANK_UPDATE_WITHDRAWMONEY")  -- retrait d'or
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

frame:SetScript("OnEvent", function(self, event, ...)

    -- ── Slots changés ────────────────────────────────────────
    if event == "GUILDBANKBAGSLOTS_CHANGED" then
        if ns.OnGuildBankSlotsChanged then ns.OnGuildBankSlotsChanged() end

    -- ── Onglets modifiés (achat, permissions, nom, icône) ────
    -- Mise à jour légère des métadonnées, sans re-scanner les slots.
    elseif event == "GUILDBANK_UPDATE_TABS" then
        if ns.OnGuildBankTabsChanged then ns.OnGuildBankTabsChanged() end

    -- ── Or déposé ou retiré (même handler) ───────────────────
    elseif event == "GUILDBANK_UPDATE_MONEY"
        or event == "GUILDBANK_UPDATE_WITHDRAWMONEY" then
        if ns.OnGuildBankMoneyChanged then ns.OnGuildBankMoneyChanged() end

    -- ── Ouverture / fermeture du banquier de guilde ──────────
    -- Seul ce module écoute PLAYER_INTERACTION_MANAGER_FRAME_SHOW/HIDE
    -- (banque bataillon retirée du core, banque perso via BANKFRAME_*).
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local iType = ...
        if iType == Enum.PlayerInteractionType.GuildBanker then
            if ns.OnGuildBankOpened then ns.OnGuildBankOpened() end
        end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local iType = ...
        if iType == Enum.PlayerInteractionType.GuildBanker then
            if ns.OnGuildBankClosed then ns.OnGuildBankClosed() end
        end
    end
end)

-- ── Exposition sur l'API partagée ───────────────────────────────
-- _G.ViewerLogAPI existe déjà (core chargé avant, via RequiredDeps).
-- Consommée par AltViewerLog_GuildeLog.
if _G.ViewerLogAPI then
    _G.ViewerLogAPI.ScanGuildBank = ns.ScanGuildBank
end
