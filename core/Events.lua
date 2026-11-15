local addonName, ns = ...

-- Events : socle du noyau (identité, équipement, XP, guilde).
-- Objets, réputation, métiers et coffre de guilde ont leur propre event frame
-- dans leur dépendance ; ils ne partagent que ViewerLogDB / _G.ViewerLogAPI.

local frame = CreateFrame("Frame", "ViewerLog_EventFrame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("TIME_PLAYED_MSG")

-- ── Debounce ScanCharacterMeta ────────────────────────────────────
-- Les events XP/repos arrivent en rafale : un seul appel 0.5s après le dernier.
local _metaTimer = nil
local function ScheduleMetaScan()
    if _metaTimer then _metaTimer:Cancel() end
    _metaTimer = C_Timer.NewTimer(0.5, function()
        _metaTimer = nil
        ns.ScanCharacterMeta()
    end)
end

frame:SetScript("OnEvent", function(self, event, ...)

    -- ── Connexion ────────────────────────────────────────────
    if event == "PLAYER_LOGIN" then
        ViewerLogDB.settings = ViewerLogDB.settings or {}

    -- ── Entrée dans le monde ─────────────────────────────────
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.ScanIdentity()
        C_Timer.After(3, function() ns.ScanEquipment() end)
        C_Timer.After(8, function() ns.ScanCharacterMeta() end)

    -- ── Personnage vivant (après résurrection) ───────────────
    elseif event == "PLAYER_ALIVE" then
        ns.ScanEquipment()

    -- ── Déconnexion / sortie du monde ────────────────────────
    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        ns.ScanIdentity(true)
        ns.ScanCharacterMeta()
        RequestTimePlayed()

    -- ── Équipement ───────────────────────────────────────────
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.ScanEquipment()
        ns.ScanItemLevel()

    -- ── Or personnage ────────────────────────────────────────
    elseif event == "PLAYER_MONEY" then
        local charData = ns.GetCurrentCharData()
        if charData then
            local gold = GetMoney()
            if gold and gold >= 0 then charData.gold = gold end
        end

    -- ── Guilde ───────────────────────────────────────────────
    elseif event == "PLAYER_GUILD_UPDATE" then
        if not IsInGuild() then
            local charData = ns.GetCurrentCharData()
            if charData then charData.guild = nil end
        else
            ns.ScanCharacterMeta()
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        ns.ScanCharacterMeta()

    -- ── XP / repos — debounce ────────────────────────────────
    elseif event == "UPDATE_EXHAUSTION"
        or event == "PLAYER_UPDATE_RESTING"
        or event == "PLAYER_XP_UPDATE" then
        ScheduleMetaScan()

    -- ── Temps joué ───────────────────────────────────────────
    elseif event == "TIME_PLAYED_MSG" then
        local totalTime = ...
        local charData  = ns.GetCurrentCharData()
        if charData then charData.timePlayed = totalTime end
    end
end)
