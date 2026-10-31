local addonName, ns = ...

-- Section Infobulle de l'onglet Général : carte on/off, cases d'affichage, aperçu.
-- Les clés hide* gardent leur nom dans ViewerLogDB.settings (case cochée = affiché).

ns.UI = ns.UI or {}

local BLOCK_H = 214
local PREVIEW_W, PREVIEW_H = 270, 89

local OPTIONS = {
    { key = "hideTooltipIcons",   label = "CB_SHOW_ICONS"   },
    { key = "hideGuildTooltip",   label = "CB_SHOW_GUILD"   },
    { key = "hideRealmTooltip",   label = "CB_SHOW_REALM"   },
}

function ns.UI.BuildTooltipSection(page)
    local S, SetS = ns.UI.GetSetting, ns.UI.SetSetting

    local block = CreateFrame("Frame", nil, page)
    block:SetPoint("TOPLEFT",  page, "TOPLEFT",  0, 0)
    block:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    block:SetHeight(BLOCK_H)

    local preview

    -- Carte : titre, description, case à cocher on/off (à droite).
    local card = ns.UI.StyledFrame(block, nil, nil, "card")
    card:SetPoint("TOPLEFT",  block, "TOPLEFT",  10, -10)
    card:SetPoint("TOPRIGHT", block, "TOPRIGHT", -10, -10)
    card:SetHeight(62)

    local title = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText(ns.L("TT_CARD_TITLE"))
    ns.UI.Tint(title, "text")

    local desc = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 16, -36)
    desc:SetText(ns.L("TT_CARD_DESC"))
    ns.UI.Tint(desc, "textDim")

    local cbMain, cbs

    local function UpdateDependents()
        local enabled = not S("disableTooltip")
        for _, cb in ipairs(cbs) do ns.UI.SetCheckboxEnabled(cb, enabled) end
        preview:SetAlpha(enabled and 1 or 0.35)
    end

    cbMain = ns.UI.Checkbox(card, "", ns.L("CB_TOOLTIP_ENABLED_TIP"), card, 0, 0,
        function() return not S("disableTooltip") end,
        function(v) SetS("disableTooltip", not v); UpdateDependents() end)
    cbMain:ClearAllPoints()
    cbMain:SetPoint("RIGHT", card, "RIGHT", -16, 0)
    cbMain:SetSize(26, 26)

    -- Cases d'affichage.
    local sec = ns.UI.SectionTitle(block, ns.L("SECTION_TOOLTIP_SHOW"), card, "BOTTOMLEFT", 6, -16)

    cbs = {}
    local prev = sec
    for i, o in ipairs(OPTIONS) do
        cbs[i] = ns.UI.Checkbox(block, ns.L(o.label), ns.L(o.label .. "_TIP"),
            prev, 0, (i == 1) and -12 or -10,
            function() return not S(o.key) end,
            function(v) SetS(o.key, not v); preview.Refresh() end)
        prev = cbs[i]
    end

    preview = ns.UI.BuildTooltipPreview(block, card, 0, -16, PREVIEW_W, PREVIEW_H)

    local function Refresh()
        cbMain:SetChecked(not S("disableTooltip"))
        for i, o in ipairs(OPTIONS) do cbs[i]:SetChecked(not S(o.key)) end
        UpdateDependents()
        preview.Refresh()
    end

    return { frame = block, Refresh = Refresh }
end
