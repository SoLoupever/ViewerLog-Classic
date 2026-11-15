local addonName, ns = ...

-- Scanner sacs.
-- Queue + OnUpdate : BAG_UPDATE arrive en rafale, un seul scan à la frame suivante.

local wipe = wipe

-- Sacs perso : 0 → dernier sac équipé (globals Blizzard, varient selon le client ;
-- NUM_TOTAL_EQUIPPED_BAG_SLOTS inclut le sac de composants quand il existe).
local LAST_BAG = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS
local BAG_SET = {}
for bag = 0, LAST_BAG do BAG_SET[bag] = true end
ns.BAG_SET = BAG_SET

local _pendingBags = {}
local _scanFrame   = nil
local _scanQueued  = false

local function ExecuteScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    charData.bags = charData.bags or {}

    -- File vide → scan complet (login/logout/entering).
    if not next(_pendingBags) then
        for bag in pairs(BAG_SET) do _pendingBags[bag] = true end
    end

    for bag in pairs(_pendingBags) do
        if BAG_SET[bag] then
            ns.ScanContainerInto(bag, charData.bags)
        end
    end
    wipe(_pendingBags)

    ns.InvalidateIndex({ chars = true })
    ns.RefreshTooltip()
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

-- Crée la frame OnUpdate une seule fois (idempotent).
function ns.InitBagScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_BagScanFrame")
end

-- reason "BAG_UPDATE" → scan partiel ; sinon scan complet.
function ns.ScanBags(reason, bagID)
    if not _scanFrame then return end

    if reason == "BAG_UPDATE" then
        if not ns._isLoggingOut then
            QueueBagScan(bagID)
        end
    else
        wipe(_pendingBags)
        QueueBagScan(nil)
    end
end
