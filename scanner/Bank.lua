local addonName, ns = ...

-- Scanner banque personnelle.
-- Conteneurs : -1 (legacy direct), 6–11 (legacy bags), -3 (réactifs),
-- CharacterBankTab_1…6 (onglets TWW, ajoutés dynamiquement si l'enum existe).
-- Debounce queue + OnUpdate identique à Bags.lua (même contrat Init/Scan).
-- Module isolé : ne connaît pas l'état "banque ouverte" (géré par Events.lua),
-- mais reste auto-protégé par la garde anySlots ci-dessous.

local wipe = wipe

-- ── Construction dynamique de la liste de conteneurs ──────────────
local BANK_CONTAINERS = { -1, 6, 7, 8, 9, 10, 11, -3 }
do
    local tabNames = {
        "CharacterBankTab_1", "CharacterBankTab_2", "CharacterBankTab_3",
        "CharacterBankTab_4", "CharacterBankTab_5", "CharacterBankTab_6",
    }
    for _, name in ipairs(tabNames) do
        local val = Enum and Enum.BagIndex and Enum.BagIndex[name]
        if val then
            BANK_CONTAINERS[#BANK_CONTAINERS + 1] = val
        end
    end
end

-- ── Table de lookup ────────────────────────────────────────────────
-- ns.IsBankBag(bagID)  → routage BAG_UPDATE dans Events.lua
-- ns.BANK_BAG_SET[bag] → vérité migration PLAYER_ENTERING_WORLD
local BANK_BAG_SET = {}
for _, bag in ipairs(BANK_CONTAINERS) do
    BANK_BAG_SET[bag] = true
end
ns.BANK_BAG_SET = BANK_BAG_SET

function ns.IsBankBag(bagID)
    return BANK_BAG_SET[bagID] == true
end

-- ── Debounce (queue + OnUpdate) ────────────────────────────────────
local _pendingBankBags = {}
local _scanFrame        = nil   -- frame OnUpdate (créée une fois)
local _scanQueued        = false

local function ExecuteBankScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    -- Garde : aucun slot lisible = banque fermée / données pas reçues.
    -- On préserve l'existant et on sort (protège même si l'appelant oublie
    -- de vérifier l'état "banque ouverte").
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

    -- Bags dirty uniquement ; file vide (appel bare) → scan complet.
    local scanAll = not next(_pendingBankBags)
    if scanAll then
        for _, bag in ipairs(BANK_CONTAINERS) do _pendingBankBags[bag] = true end
    end

    for bag in pairs(_pendingBankBags) do
        ns.ScanContainerInto(bag, charData.bank)
    end
    wipe(_pendingBankBags)

    ns.InvalidateIndex({ chars = true })

    -- Rafraîchit la tooltip visible (cf. ScanBags).
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
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

-- Crée la frame OnUpdate une seule fois (après PLAYER_LOGIN). Idempotente.
function ns.InitBankScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_BankScanFrame")
end

-- ns.ScanBank()      → scan complet
-- ns.ScanBank(bagID) → scan partiel du bag modifié (BAG_UPDATE)
function ns.ScanBank(bagID)
    if not _scanFrame then return end
    if bagID then
        QueueBankScan(bagID)
    else
        wipe(_pendingBankBags)
        QueueBankScan(nil)
    end
end
