local addonName, ns = ...

-- Infobulle monnaies : hook sur Enum.TooltipDataType.Currency (indépendant
-- du hook Item du core, aucune collision). Réutilise les réglages partagés
-- ViewerLogDB.settings (pas de préférences parallèles). Style calqué sur
-- core/tooltip/Hook.lua pour rester cohérent.

local ICON = {
    HORDE    = "|TInterface\\Icons\\PVPCurrency-Honor-Horde:14:14:0:0|t",
    ALLIANCE = "|TInterface\\Icons\\PVPCurrency-Honor-Alliance:14:14:0:0|t",
}

-- ── Cache couleurs de classe ──────────────────────────────────────
-- Duplication volontaire de core/tooltip/Hook.lua (ns du core inaccessible).
local classHex = {}
local function GetClassHex(class)
    if not classHex[class] then
        local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
               or { r = 0.8, g = 0.8, b = 0.8 }
        classHex[class] = string.format("FF%02x%02x%02x",
            math.floor(c.r * 255 + 0.5),
            math.floor(c.g * 255 + 0.5),
            math.floor(c.b * 255 + 0.5))
    end
    return classHex[class]
end

-- ── Injection dans l'infobulle ────────────────────────────────────

local function AppendCurrencyInfo(tooltip, currencyID)
    local s = ViewerLogDB and ViewerLogDB.settings or {}
    if s.hideTooltip or s.disableTooltip         then return end
    if s.tooltipOnShift and not IsShiftKeyDown() then return end

    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetAllCharacters or not vlAPI.GetCharacterByKey then return end

    local showIcons = not s.hideTooltipIcons
    local showRealm = not s.hideRealmTooltip

    local rows, total = {}, 0

    for _, key in ipairs(vlAPI.GetAllCharacters()) do
        local d = vlAPI.GetCharacterByKey(key)
        local entry = d and d.currencies and d.currencies[currencyID]
        local qty = entry and entry.quantity or 0
        if qty > 0 then
            local charName, realmName = key:match("^(.+)@(.+)$")
            rows[#rows + 1] = { char = charName, realm = realmName, class = d.class, faction = d.faction, qty = qty }
            total = total + qty
        end
    end

    if #rows == 0 then return end

    table.sort(rows, function(a, b) return a.qty > b.qty end)

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        ns.L("TT_OWNED_BY"),
        string.format("|cffb266ff%s :|r  |cffffffff%d|r", ns.L("TT_TOTAL"), total),
        1, 0.80, 0, 1, 1, 1)

    for _, r in ipairs(rows) do
        local hex = GetClassHex(r.class or "WARRIOR")

        local factionIcon = ""
        if showIcons then
            if     r.faction == "Horde"    then factionIcon = ICON.HORDE    .. " "
            elseif r.faction == "Alliance" then factionIcon = ICON.ALLIANCE .. " "
            end
        end

        local left
        if showRealm then
            left = string.format("%s|c%s%s|r |c%s(%s)|r", factionIcon, hex, r.char, hex, r.realm)
        else
            left = string.format("%s|c%s%s|r", factionIcon, hex, r.char)
        end

        tooltip:AddDoubleLine(left, string.format("|cffffffff%d|r", r.qty), 1, 1, 1, 1, 1, 1)
    end
end

-- ── Enregistrement du hook ──────────────────────────────────────────
-- Si disableTooltip est actif au chargement, le hook n'est pas enregistré
-- (réactivation → /reload). Même gate que core/tooltip/Hook.lua.

local disabled = ViewerLogDB and ViewerLogDB.settings and ViewerLogDB.settings.disableTooltip

if not disabled then
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType and Enum.TooltipDataType.Currency then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Currency, function(tooltip, data)
            local id = data and (data.id or data.currencyID)
            if id then AppendCurrencyInfo(tooltip, id) end
        end)
    end
end
