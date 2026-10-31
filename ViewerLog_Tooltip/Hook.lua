local addonName, ns = ...

-- ViewerLog_Tooltip : infobulle d'objet.
-- options d'affichage (icônes / guilde / royaume).

local VL = _G.ViewerLogAPI
if not VL then return end   -- ViewerLog absent : rien à injecter.

local L = VL.L

-- ── Icônes ───────────────────────────────────────────────────────
-- Le choix du jeu d'icônes de faction (et sa taille) est centralisé dans
-- ViewerLog (VL.GetFactionIconPath) : même logique de détection de version
-- que la liste de personnages du panneau, pas de doublon ici.

local function FactionIcon(faction)
    local path, isBig = VL.GetFactionIconPath(faction)
    if not path then return "" end
    local size = isBig and 24 or 14
    local yOffset = isBig and -5 or 0
    return string.format("|T%s:%d:%d:0:%d|t", path, size, size, yOffset)
end

local ICON = {
    GUILD = "|TInterface\\Icons\\achievement_guildperk_honorablemention:14:14:0:0|t",
}

-- ── Cache couleurs de classe ──────────────────────────────────────

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

local function AppendInfo(tooltip, itemID)
    if not itemID then return end

    local s = ViewerLogDB and ViewerLogDB.settings or {}
    -- Désactivation "douce" via la case du menu ViewerLog (addon reste chargé).
    if s.disableTooltip then return end
    if s.tooltipOnShift and not IsShiftKeyDown() then return end

    local entry = VL.GetTooltipEntry(itemID)
    if not entry then return end

    local showIcons  = not s.hideTooltipIcons
    local showGuild  = not s.hideGuildTooltip
    local showRealm  = not s.hideRealmTooltip

    local hasChars   = next(entry.chars)       ~= nil
    local hasGuild   = (entry.guildCount       or 0) > 0 and showGuild
    if not hasChars and not hasGuild then return end

    -- Total pré-calculé (affiché dans l'en-tête "Owned by").
    local preTotal = 0
    for _, ce in pairs(entry.chars) do
        preTotal = preTotal + (ce.bagCount or 0) + (ce.bankCount or 0) + (ce.mailCount or 0)
    end
    if hasGuild   then preTotal = preTotal + entry.guildCount   end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine(
        L("TT_OWNED_BY"),
        string.format("|cffb266ff%s :|r  |cffffffff%d|r", L("TT_TOTAL"), preTotal),
        1, 0.80, 0, 1, 1, 1)

    local grandTotal = 0

    -- ── Personnages ───────────────────────────────────────────
    for _, ce in pairs(entry.chars) do
        local total = (ce.bagCount or 0) + (ce.bankCount or 0) + (ce.mailCount or 0)
        if total > 0 then
            grandTotal = grandTotal + total
            local hex  = GetClassHex(ce.class or "WARRIOR")

            local factionIcon = ""
            if showIcons then
                factionIcon = FactionIcon(ce.faction)
                if factionIcon ~= "" then factionIcon = factionIcon .. " " end
            end

            local left
            if showRealm then
                left = string.format("%s|c%s%s|r |c%s(%s)|r",
                    factionIcon, hex, ce.char, hex, ce.realm)
            else
                left = string.format("%s|c%s%s|r", factionIcon, hex, ce.char)
            end

            local parts = {}
            if (ce.bagCount  or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.bagCount,  L("TT_BAG"))
            end
            if (ce.bankCount or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.bankCount, L("TT_BANK"))
            end
            if (ce.mailCount or 0) > 0 then
                parts[#parts+1] = string.format("|cffffffff%d :|r |cffa335ee%s|r", ce.mailCount, L("TT_MAIL"))
            end

            tooltip:AddDoubleLine(left, table.concat(parts, "  |cff444444·|r  "),
                1, 1, 1, 1, 1, 1)
        end
    end

    -- ── Guildes ───────────────────────────────────────────────
    if hasGuild then
        grandTotal = grandTotal + entry.guildCount
        if entry.guilds then
            for gName, gCount in pairs(entry.guilds) do
                local left  = (showIcons and ICON.GUILD .. " " or "") ..
                              "|cff40c0ff" .. L("TT_GUILD") .. " " .. gName .. "|r"
                local right = string.format("|cffffffff%d|r", gCount)
                tooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
            end
        end
    end
end

-- ── Enregistrement du hook ────────────────────────────────────────
if TooltipDataProcessor and C_TooltipInfo then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
        function(tooltip, data)
            if data and data.id then AppendInfo(tooltip, data.id) end
        end)
else
    -- Chemin Classic (Era/TBC/Wrath/Cata/MoP). "ready" évite un double
    -- ajout si OnTooltipSetItem se redéclenche avant que le tooltip ne
    local ready = true
    GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
        if not ready then return end
        local _, link = tooltip:GetItem()
        if link then
            AppendInfo(tooltip, tonumber(link:match("item:(%d+)")))
            tooltip:Show()
        end
        ready = false
    end)
    GameTooltip:HookScript("OnTooltipCleared", function()
        ready = true
    end)
end
