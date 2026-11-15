local addonName, ns = ...

-- Scanner enchères. Lisible HV ouvert (Init.lua tient _auctionOpen).
-- charData.auctions = { [itemID] = quantité }, réécrit en entier à chaque scan.
-- Objets vendus ignorés (plus possédés). Liste incomplète : pas d'écriture.
-- Deux API selon le client, détectées une fois au chargement :
--   · moderne  : C_AuctionHouse (OWNED_AUCTIONS_UPDATED)
--   · classique : GetOwnerAuctionItems (AUCTION_OWNED_LIST_UPDATE)

local MODERN = C_AuctionHouse ~= nil and C_AuctionHouse.QueryOwnedAuctions ~= nil

-- Événement de livraison de la liste ; événements demandant un nouveau Query.
ns.AUCTION_LIST_EVENT = MODERN and "OWNED_AUCTIONS_UPDATED" or "AUCTION_OWNED_LIST_UPDATE"
ns.AUCTION_REQUERY_EVENTS = MODERN and { "AUCTION_CANCELED", "AUCTION_HOUSE_AUCTION_CREATED" } or {}

local _scanQueued  = false
local _queryQueued = false

-- Renvoie { [itemID] = qty } (nil si vide), ou false si liste incomplète.
local function ReadModern()
    if not C_AuctionHouse.HasFullOwnedAuctionResults() then return false end

    local active = Enum.AuctionStatus.Active
    local auctions
    for i = 1, C_AuctionHouse.GetNumOwnedAuctions() do
        local info = C_AuctionHouse.GetOwnedAuctionInfo(i)
        if info and info.status == active then
            auctions = auctions or {}
            local id = info.itemKey.itemID
            auctions[id] = (auctions[id] or 0) + info.quantity
        end
    end
    return auctions
end

local SOLD = 1

local function ReadLegacy()
    local num, total = GetNumAuctionItems("owner")
    if not num or (total and total > num) then return false end

    local auctions
    for i = 1, num do
        local _, _, count, _, _, _, _, _, _, _, _, _, _, _, _, saleStatus, itemID = GetAuctionItemInfo("owner", i)
        if not itemID then return false end
        if saleStatus ~= SOLD then
            auctions = auctions or {}
            auctions[itemID] = (auctions[itemID] or 0) + (count or 1)
        end
    end
    return auctions
end

local Read = MODERN and ReadModern or ReadLegacy

local function ExecuteAuctionScan()
    _scanQueued = false

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local auctions = Read()
    if auctions == false then return end

    charData.auctions = auctions
    ns.InvalidateIndex({ chars = true })
    ns.RefreshTooltip()
end

-- Appelé sur ns.AUCTION_LIST_EVENT (rafales : debounce).
function ns.ScanAuctions()
    if _scanQueued then return end
    _scanQueued = true
    C_Timer.After(0.5, ExecuteAuctionScan)
end

-- Demande la liste ; la réponse arrive via ns.AUCTION_LIST_EVENT.
function ns.QueryAuctions()
    if _queryQueued then return end
    _queryQueued = true
    C_Timer.After(0.5, function()
        _queryQueued = false
        if MODERN then
            C_AuctionHouse.QueryOwnedAuctions({})
        else
            GetOwnerAuctionItems()
        end
    end)
end
