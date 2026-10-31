local addonName, ns = ...

-- Events : écoute les événements du jeu et déclenche les scanners.
-- Ne gère que le socle (perso, sacs, banque, or, équipement).
-- Réputation, métiers et coffre de guilde ont leur propre event frame
-- dans leur dépendance ; ils ne partagent que ViewerLogDB / _G.ViewerLogAPI.

local frame = CreateFrame("Frame", "ViewerLog_EventFrame")

-- bagID valides pour charData.bags (sacs perso). Source de vérité banque :
-- ns.BANK_BAG_SET (scanner/Bank.lua). VALID_BAGS reste local à ce fichier.
local VALID_BAGS = { [0]=true,[1]=true,[2]=true,[3]=true,[4]=true,[5]=true }

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("BAG_UPDATE")             -- bagID précis → routing sac/banque
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED") -- onglets banque TWW
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("PLAYER_GUILD_UPDATE")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("MAIL_SHOW")               -- ouverture boîte aux lettres
frame:RegisterEvent("MAIL_INBOX_UPDATE")       -- contenu du courrier reçu/à jour
frame:RegisterEvent("MAIL_CLOSED")

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

-- ── État "banque ouverte" ──────────────────────────────────────────
-- Garde propre à ce fichier (seul à écouter BANKFRAME_*). Hors banque,
-- GetContainerNumSlots renvoie 0 et un scan écraserait les données. Le
-- debounce des BAG_UPDATE est géré dans Bank.lua.
local _bankOpen        = false
-- Courrier : lisible uniquement boîte ouverte. GetInboxNumItems renvoie 0
-- hors boîte, indiscernable d'un courrier vide ; _mailOpen sert donc de
-- seule garde (scan écrit charData.mail y compris vide → nettoyage correct).
local _mailOpen        = false

frame:SetScript("OnEvent", function(self, event, ...)

    -- ── Connexion ────────────────────────────────────────────
    if event == "PLAYER_LOGIN" then
        ViewerLogDB.settings = ViewerLogDB.settings or {}
        -- Un Init idempotent par module scanner (crée sa frame OnUpdate).
        ns.InitBagScanner()
        ns.InitBankScanner()
        ns.InitMailScanner()

    -- ── Entrée dans le monde ─────────────────────────────────
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reset du flag logout : PLAYER_LEAVING_WORLD fire à chaque écran de
        -- chargement, pas qu'à la déconnexion. Sans ce reset, le handler
        -- BAG_UPDATE (conditionné par _isLoggingOut) resterait bloqué.
        -- À faire AVANT ScanBags ci-dessous pour un scan normal (isLogout=false).
        ns._isLoggingOut = false

        -- Nettoyage des bagID mal indexés (anciennes versions rangeaient de la
        -- banque dans charData.bags). BANK_BAG_SET = vérité banque, VALID_BAGS = sacs.
        for realmName, realmData in pairs(ViewerLogDB) do
            if ns.IsRealm(realmName, realmData) then
                for _, charData in pairs(realmData) do
                    if type(charData) == "table" then
                        if charData.bags then
                            for bag in pairs(charData.bags) do
                                if not VALID_BAGS[bag] then
                                    charData.bags[bag] = nil
                                end
                            end
                        end
                        if charData.bank then
                            for bag in pairs(charData.bank) do
                                if not ns.BANK_BAG_SET[bag] then
                                    charData.bank[bag] = nil
                                end
                            end
                        end
                    end
                end
            end
        end
        ns.ScanBags("ENTERING_WORLD")
        ns.InvalidateIndexAll()
        C_Timer.After(3, function() ns.ScanEquipment() end)
        C_Timer.After(8, function() ns.ScanCharacterMeta() end)

    -- ── Personnage vivant (après résurrection) ───────────────
    elseif event == "PLAYER_ALIVE" then
        ns.ScanEquipment()

    -- ── Déconnexion / sortie du monde ────────────────────────
    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        ns._isLoggingOut = true
        ns.ScanCharacterMeta()
        RequestTimePlayed()
        ns.ScanBags("LOGOUT")
        -- Pas d'InvalidateIndex : l'index n'est plus utilisé jusqu'au prochain login.

    -- ── Routage BAG_UPDATE ─────────────────────────────────────
    -- bagID exact → appel direct au bon scanner (chacun a son debounce interne).
    -- _bankOpen : hors banque, les slots ne sont pas lisibles.
    elseif event == "BAG_UPDATE" then
        local bagID = ...
        if not ns._isLoggingOut then
            if ns.IsBankBag(bagID) then
                if _bankOpen then ns.ScanBank(bagID) end
            else
                ns.ScanBags("BAG_UPDATE", bagID)
            end
        end

    -- ── Banque personnelle ───────────────────────────────────────
    elseif event == "BANKFRAME_OPENED" then
        _bankOpen = true
        ns.ScanBank()

    elseif event == "BANKFRAME_CLOSED" then
        _bankOpen = false
        ns.ScanBank()

    -- ── Onglets banque TWW ────────────────────────────────────
    -- BAG_UPDATE ne couvre pas toujours les onglets CharacterBankTab.
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if _bankOpen and not ns._isLoggingOut then
            ns.ScanBank()
        end

    -- ── Équipement ───────────────────────────────────────────
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        ns.ScanEquipment()

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

    -- ── Courrier ──────────────────────────────────────────────
    -- MAIL_SHOW : boîte ouverte. MAIL_INBOX_UPDATE : contenu reçu/modifié
    -- (rafales, debouncé par le scanner). MAIL_CLOSED : on coupe la garde.
    elseif event == "MAIL_SHOW" then
        _mailOpen = true
        ns.ScanMail()

    elseif event == "MAIL_INBOX_UPDATE" then
        if _mailOpen and not ns._isLoggingOut then
            ns.ScanMail()
        end

    elseif event == "MAIL_CLOSED" then
        _mailOpen = false
    end
end)
