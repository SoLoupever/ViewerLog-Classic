local addonName, ns = ...

-- Scanner sacs & méta personnage.
-- Queue + OnUpdate : les BAG_UPDATE arrivent en rafale ; on marque les sacs
-- dirty et on scanne une seule fois à la frame suivante.

local math_floor = math.floor
local time       = time
local select     = select
local wipe       = wipe

-- ── Scan des sacs ─────────────────────────────────────────────────
local _pendingBags  = {}
local _scanFrame    = nil   -- frame OnUpdate (créée une fois)
local _scanQueued   = false

local function ExecuteScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    local charData, realm, player = ns.GetCurrentCharData()
    if not charData then return end

    local isLogout = ns._isLoggingOut

    -- Or : au logout on ne réécrit que si > 0 (évite d'écraser par 0).
    local gold = GetMoney()
    if not isLogout then
        if gold and gold >= 0 then charData.gold = gold end
    else
        if gold and gold > 0 then charData.gold = gold end
    end

    -- Niveau d'objet moyen équipé
    local _, avgEquipped = GetAverageItemLevel()
    local ilvl = math_floor(avgEquipped or 0)
    if ilvl > 0 then charData.ilvl = ilvl end

    -- Méta de base
    charData.level   = UnitLevel("player")
    charData.class   = select(2, UnitClass("player"))
    charData.faction = UnitFactionGroup("player")

    if not isLogout then charData.lastLogin = time() end

    charData.bags = charData.bags or {}

    -- Bags dirty uniquement ; si pending vide → scan complet (login/logout/entering).
    local scanAll = not next(_pendingBags)
    if scanAll then
        for bag = 0, 5 do _pendingBags[bag] = true end
    end

    for bag in pairs(_pendingBags) do
        if bag >= 0 and bag <= 5 then
            ns.ScanContainerInto(bag, charData.bags)
        end
    end
    wipe(_pendingBags)

    ns.InvalidateIndex({ chars = true })

    -- Rafraîchit la tooltip visible : le post-call ne fire qu'à la construction,
    -- SetHyperlink la reconstruit avec l'index à jour.
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
end

local function QueueBagScan(bagID)
    if bagID then
        _pendingBags[bagID] = true
    end
    if not _scanQueued then
        _scanQueued = true
        _scanFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            ExecuteScan()
        end)
    end
end

-- Crée la frame OnUpdate une seule fois (après PLAYER_LOGIN).
function ns.InitBagScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_BagScanFrame")
end

-- Point d'entrée appelé par Events.lua.
function ns.ScanBags(reason, bagID)
    if not _scanFrame then return end

    if reason == "BAG_UPDATE" then
        -- Scan partiel : uniquement le bag modifié.
        if not ns._isLoggingOut then
            QueueBagScan(bagID)
        end
    else
        -- Scan complet (ENTERING_WORLD, LOGOUT, MANUAL).
        wipe(_pendingBags)
        QueueBagScan(nil)
    end
end
