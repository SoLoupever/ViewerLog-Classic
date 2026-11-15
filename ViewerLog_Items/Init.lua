local addonName, ns = ...

-- Init Items : événements du jeu → scanners d'objets.
-- Frame propre ; partage uniquement _G.ViewerLogAPI avec le noyau.

local frame = CreateFrame("Frame", "ViewerLog_Items_EventFrame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_LEAVING_WORLD")
frame:RegisterEvent("BAG_UPDATE")             -- bagID précis → routage sac/banque
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
frame:RegisterEvent("MAIL_SHOW")
frame:RegisterEvent("MAIL_INBOX_UPDATE")
frame:RegisterEvent("MAIL_CLOSED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent(ns.AUCTION_LIST_EVENT)    -- dépend de l'API HV du client
for _, ev in ipairs(ns.AUCTION_REQUERY_EVENTS) do
    frame:RegisterEvent(ev)
end

-- Hors banque / courrier / HV, les données ne sont pas lisibles : un scan
-- écraserait l'existant.
local _bankOpen    = false
local _mailOpen    = false
local _auctionOpen = false

-- ENTERING_WORLD fire à chaque écran de chargement : nettoyage une fois par session.
local _sessionReady = false

-- Retire les bagID mal indexés (anciennes versions : ids Retail en dur).
local function CleanupBagIDs()
    ns.vl.ForEachCharacter(function(_, _, charData)
        if charData.bags then
            for bag in pairs(charData.bags) do
                if not ns.BAG_SET[bag] then charData.bags[bag] = nil end
            end
        end
        -- Set banque vide = détection échouée : on ne purge rien.
        if charData.bank and next(ns.BANK_BAG_SET) then
            for bag in pairs(charData.bank) do
                if not ns.BANK_BAG_SET[bag] then charData.bank[bag] = nil end
            end
        end
    end)
end

-- Notifications du noyau : l'index doit être reconstruit.
ns.vl.RegisterCallback("CHARACTER_DELETED", function()
    ns.InvalidateIndex({ chars = true })
end)

ns.vl.RegisterCallback("GUILD_DELETED", function()
    ns.InvalidateIndex({ guild = true })
end)

frame:SetScript("OnEvent", function(self, event, ...)

    if event == "PLAYER_LOGIN" then
        ns.InitBagScanner()
        ns.InitBankScanner()
        ns.InitMailScanner()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- LEAVING_WORLD fire à chaque loading : reset avant ScanBags.
        ns._isLoggingOut = false

        if not _sessionReady then
            _sessionReady = true
            CleanupBagIDs()
        end
        ns.ScanBags("ENTERING_WORLD")

    elseif event == "PLAYER_LOGOUT"
        or event == "PLAYER_LEAVING_WORLD" then
        ns._isLoggingOut = true
        ns.ScanBags("LOGOUT")

    -- bagID exact → bon scanner (debounce interne).
    elseif event == "BAG_UPDATE" then
        local bagID = ...
        if not ns._isLoggingOut then
            if ns.IsBankBag(bagID) then
                if _bankOpen then ns.ScanBank(bagID) end
            else
                ns.ScanBags("BAG_UPDATE", bagID)
            end
        end

    elseif event == "BANKFRAME_OPENED" then
        _bankOpen = true
        ns.ScanBank()

    elseif event == "BANKFRAME_CLOSED" then
        _bankOpen = false
        ns.ScanBank()

    -- BAG_UPDATE ne couvre pas toujours la banque principale.
    elseif event == "PLAYERBANKSLOTS_CHANGED" then
        if _bankOpen and not ns._isLoggingOut then ns.ScanBank() end

    -- Courrier : MAIL_INBOX_UPDATE arrive en rafale (debounce dans le scanner).
    elseif event == "MAIL_SHOW" then
        _mailOpen = true
        ns.ScanMail()

    elseif event == "MAIL_INBOX_UPDATE" then
        if _mailOpen and not ns._isLoggingOut then ns.ScanMail() end

    elseif event == "MAIL_CLOSED" then
        _mailOpen = false

    -- HV ouvert → on demande la liste, AUCTION_OWNED_LIST_UPDATE la livre.
    elseif event == "AUCTION_HOUSE_SHOW" then
        _auctionOpen = true
        ns.QueryAuctions()

    elseif event == "AUCTION_HOUSE_CLOSED" then
        _auctionOpen = false

    elseif event == ns.AUCTION_LIST_EVENT then
        if _auctionOpen and not ns._isLoggingOut then ns.ScanAuctions() end

    -- Création / annulation : la liste serveur a changé, on la redemande.
    elseif event == "AUCTION_CANCELED"
        or event == "AUCTION_HOUSE_AUCTION_CREATED" then
        if _auctionOpen then ns.QueryAuctions() end
    end
end)
