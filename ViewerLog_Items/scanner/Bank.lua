local addonName, ns = ...

-- Scanner banque personnelle.
-- Deux modèles selon le client, chacun détecté par ses propres globals :
--   · banque classique : BANK_CONTAINER + sacs de banque
--     (NUM_BAG_SLOTS+1 … +NUM_BANKBAGSLOTS), comme Blizzard_BankFrame ;
--   · onglets de banque : Enum.BagIndex.CharacterBankTab_N si l'enum les expose.
-- Auto-protégé par la garde anySlots ; l'état "banque ouverte" est géré par Init.lua.

local wipe = wipe

local BANK_CONTAINERS = {}
local function AddContainer(bag)
    if bag then BANK_CONTAINERS[#BANK_CONTAINERS + 1] = bag end
end

AddContainer(BANK_CONTAINER)
for bag = (NUM_BAG_SLOTS or 0) + 1, (NUM_BAG_SLOTS or 0) + (NUM_BANKBAGSLOTS or 0) do
    AddContainer(bag)
end

local bagIndex = Enum and Enum.BagIndex
if bagIndex then
    for i = 1, 9 do
        AddContainer(bagIndex["CharacterBankTab_" .. i])
    end
end

-- ns.IsBankBag → routage BAG_UPDATE ; ns.BANK_BAG_SET → nettoyage Init.
local BANK_BAG_SET = {}
for _, bag in ipairs(BANK_CONTAINERS) do
    BANK_BAG_SET[bag] = true
end
ns.BANK_BAG_SET = BANK_BAG_SET

function ns.IsBankBag(bagID)
    return BANK_BAG_SET[bagID] == true
end

local _pendingBankBags = {}
local _scanFrame       = nil
local _scanQueued      = false

local function ExecuteBankScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    -- Aucun slot lisible = banque fermée : on préserve l'existant.
    local anySlots = false
    for _, bag in ipairs(BANK_CONTAINERS) do
        if (C_Container.GetContainerNumSlots(bag) or 0) > 0 then
            anySlots = true
            break
        end
    end
    if not anySlots then
        wipe(_pendingBankBags)
        return
    end

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    charData.bank = charData.bank or {}

    -- File vide → scan complet.
    if not next(_pendingBankBags) then
        for _, bag in ipairs(BANK_CONTAINERS) do _pendingBankBags[bag] = true end
    end

    for bag in pairs(_pendingBankBags) do
        ns.ScanContainerInto(bag, charData.bank)
    end
    wipe(_pendingBankBags)

    ns.InvalidateIndex({ chars = true })
    ns.RefreshTooltip()
end

local function QueueBankScan(bagID)
    if bagID then
        _pendingBankBags[bagID] = true
    end
    if not _scanQueued then
        _scanQueued = true
        _scanFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            ExecuteBankScan()
        end)
    end
end

-- Idempotent.
function ns.InitBankScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_BankScanFrame")
end

-- ScanBank() = complet ; ScanBank(bagID) = partiel.
function ns.ScanBank(bagID)
    if not _scanFrame then return end
    if bagID then
        QueueBankScan(bagID)
    else
        wipe(_pendingBankBags)
        QueueBankScan(nil)
    end
end
