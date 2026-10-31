local addonName, ns = ...

-- Scanner méta personnage, équipement & XP reposé.
--   ScanCharacterMeta  — guilde, XP, repos
--   ScanEquipment      — objets équipés + ilvl par slot
--   EstimateRestedPct  — projection de XP reposé hors ligne
-- Déclenchés depuis core/Events.lua.

local math_floor = math.floor
local time       = time
local ipairs     = ipairs

-- ── Scan des métadonnées du personnage ────────────────────────────

function ns.ScanCharacterMeta()
    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local guildName = GetGuildInfo("player")
    if guildName then
        charData.guild = (guildName ~= "") and guildName or nil
    end

    local maxXP = UnitXPMax("player")
    if maxXP and maxXP > 0 then
        local rawRested  = GetXPExhaustion() or 0
        charData.rested = {
            currentRestedXP = math_floor(rawRested),
            currentXP       = math_floor(UnitXP("player") or 0),
            maxXP           = maxXP,
            isRestingArea   = IsResting() and true or false,
            updatedAt       = time(),
        }
        charData.maxXP = maxXP
    end
end

-- ── Estimation du % de XP reposé (fonctionne hors ligne) ─────────

local RESTED_PER_8H  = 0.05
local SECONDS_PER_8H = 8 * 3600
local RESTED_CAP_MUL = 1.5

function ns.EstimateRestedPct(rested, maxXP)
    if not rested or not maxXP or maxXP <= 0 then return nil end

    local base      = rested.currentRestedXP or 0
    local updatedAt = rested.updatedAt       or 0
    local cap       = math_floor(maxXP * RESTED_CAP_MUL)
    local estimated = base

    -- Projection : gain de repos accumulé depuis updatedAt si en zone de repos.
    if rested.isRestingArea and updatedAt > 0 then
        local elapsed    = math.max(0, time() - updatedAt)
        local gainPerSec = (maxXP * RESTED_PER_8H) / SECONDS_PER_8H
        estimated = math.min(estimated + math_floor(elapsed * gainPerSec), cap)
    end

    estimated = math.max(0, estimated)
    if estimated <= 0 then return nil end
    return math.min(math_floor((estimated / maxXP) * 100), 150)
end

-- ── Scan de l'équipement porté ────────────────────────────────────

local SLOT_NAMES = {
    "HEADSLOT", "NECKSLOT", "SHOULDERSLOT", "BACKSLOT", "CHESTSLOT",
    "WRISTSLOT", "HANDSSLOT", "WAISTSLOT", "LEGSSLOT", "FEETSLOT",
    "FINGER0SLOT", "FINGER1SLOT", "TRINKET0SLOT", "TRINKET1SLOT",
    "MAINHANDSLOT", "SECONDARYHANDSLOT",
}
ns.SLOT_NAMES = SLOT_NAMES

local SLOT_IDS = {}
local slotIDsReady = false

local function EnsureSlotIDs()
    if slotIDsReady then return end
    for _, name in ipairs(SLOT_NAMES) do
        SLOT_IDS[name] = GetInventorySlotInfo(name)
    end
    slotIDsReady = true
end

function ns.ScanEquipment()
    EnsureSlotIDs()
    local charData = ns.GetCurrentCharData()
    if not charData then return end

    charData.gear      = charData.gear      or {}
    charData.equipIlvl = charData.equipIlvl or {}

    local INVALID_EQUIP_LOC = {
        INVTYPE_BAG              = true,
        INVTYPE_QUIVER           = true,
        INVTYPE_AMMO             = true,
        INVTYPE_NON_EQUIP_IGNORE = true,
    }

    for _, slotName in ipairs(SLOT_NAMES) do
        local slotID = SLOT_IDS[slotName]
        local itemID = GetInventoryItemID("player", slotID)
        if itemID then
            local link = GetInventoryItemLink("player", slotID)
            if link then
                -- GetItemInfo global déprécié (nil sans loadDeprecationFallbacks) -> C_Item.
                local _, _, _, _, _, _, _, _, itemEquipLoc = C_Item.GetItemInfo(link)
                local isDefinitelyInvalid = itemEquipLoc ~= nil
                    and (itemEquipLoc == "" or INVALID_EQUIP_LOC[itemEquipLoc])

                if isDefinitelyInvalid then
                    charData.gear[slotName]      = nil
                    charData.equipIlvl[slotName] = nil
                else
                    charData.gear[slotName] = link:match("|H(.+)|h")
                    local loc = ItemLocation:CreateFromEquipmentSlot(slotID)
                    if loc and loc:IsValid() then
                        local lvl = C_Item.GetCurrentItemLevel(loc)
                        if lvl then charData.equipIlvl[slotName] = lvl end
                    end
                end
            end
        else
            charData.gear[slotName]      = nil
            charData.equipIlvl[slotName] = nil
        end
    end
    -- Pas d'InvalidateIndex : l'équipement n'est pas dans l'index tooltip.
end
