local addonName, ns = ...

-- Panneau de paramètres : coque (titre, onglets, pied) qui assemble les
-- sections construites par les autres modules options/*.
-- Ouvert par options/Minimap.lua, core/Init.lua (slash) et api/API.lua.

ns.UI = ns.UI or {}

local PANEL_W, PANEL_H = 660, 700
local COL_L_W = 290 -- colonne persos (onglet Général)

-- Bornes de redimensionnement (cf. options/PanelResize.lua).
local RESIZE_MIN_W, RESIZE_MAX_W = PANEL_W, PANEL_W + 400
local RESIZE_MIN_H, RESIZE_MAX_H = 650, 1500

local panel, tabs

-- ── Onglet Général : infobulle, listes persos / guildes ──
local function BuildGeneralPage(page)
    local tt = ns.UI.BuildTooltipSection(page)

    local lists = CreateFrame("Frame", nil, page)
    lists:SetPoint("TOPLEFT",     tt.frame, "BOTTOMLEFT", 0, 0)
    lists:SetPoint("BOTTOMRIGHT", page,     "BOTTOMRIGHT", 0, 10)
    ns.UI.HSep(lists, -4, 10)

    local chars  = ns.UI.BuildCharacterList(lists, COL_L_W)
    local guilds = ns.UI.BuildGuildList(lists, COL_L_W)

    ns._optRefreshChars  = chars.Populate
    ns._optRefreshGuilds = guilds.Populate

    return {
        Refresh = function()
            tt.Refresh()
            chars.Populate()
            guilds.Populate()
        end,
    }
end

local TAB_DEFS = {
    { id = "general", labelKey = "TAB_GENERAL", build = BuildGeneralPage },
    { id = "modules", labelKey = "TAB_MODULES", build = function(page) return ns.UI.BuildDependenciesSection(page) end },
    { id = "theme",   labelKey = "TAB_THEME",   build = function(page) return ns.UI.BuildThemePage(page) end },
}

local function BuildPanel()
    if panel then return panel end

    ns.UI.ApplyTheme(ns.UI.GetSetting("theme"))

    panel = CreateFrame("Frame", "VL_MinimapPanel", UIParent, "BackdropTemplate")

    local savedW = ns.UI.GetSetting("panelWidth")
    local savedH = ns.UI.GetSetting("panelHeight")
    savedW = savedW and math.max(RESIZE_MIN_W, math.min(RESIZE_MAX_W, savedW)) or PANEL_W
    savedH = savedH and math.max(RESIZE_MIN_H, math.min(RESIZE_MAX_H, savedH)) or PANEL_H
    panel:SetSize(savedW, savedH)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(s) s:StartMoving() end)
    panel:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    panel:SetClampedToScreen(true)
    panel:SetPoint("TOPRIGHT", Minimap, "TOPLEFT", -8, 0)
    panel:Hide()
    table.insert(UISpecialFrames, "VL_MinimapPanel")

    -- Bandeau d'en-tête (thèmes qui définissent `band`).
    local band = panel:CreateTexture(nil, "BACKGROUND")
    band:SetPoint("TOPLEFT",  panel, "TOPLEFT",  2, -2)
    band:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)
    band:SetHeight(90)

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", 16, -14)

    local closeBtn = ns.UI.Button(panel, 30, 30, "X")
    closeBtn:SetPoint("TOPRIGHT", -12, -12)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    -- Zone de contenu des onglets.
    local content = ns.UI.StyledFrame(panel, nil, nil, "inner")
    content:SetPoint("TOPLEFT",     panel, "TOPLEFT",     12, -92)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 52)

    tabs = ns.UI.BuildTabs(panel, content, TAB_DEFS)

    -- Pied : Discord à gauche, nom de l'addon à droite.
    ns.UI.BuildDiscordButton(panel, "BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12, 96, 28)

    local brand = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brand:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -24, 20)
    brand:SetText("ViewerLog")
    ns.UI.Tint(brand, "textDim")

    ns.UI.BindTheme(function(C)
        panel:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
        panel:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
        if C.band then
            band:SetColorTexture(C.band[1], C.band[2], C.band[3], C.band[4])
            band:Show()
        else
            band:Hide()
        end
        titleFS:SetText(string.format("|c%sVIEWER|r|c%sLOG|r", C.titleA, C.titleB))
    end)

    ns.UI.MakeResizeGrip(panel, RESIZE_MIN_W, RESIZE_MIN_H, RESIZE_MAX_W, RESIZE_MAX_H)

    panel:SetScript("OnShow", function()
        if tabs.Current() then tabs.Refresh() else tabs.Select("general") end
    end)

    return panel
end

function ns.UI.ShowPanel()
    BuildPanel():Show()
end

function ns.UI.TogglePanel()
    local p = BuildPanel()
    if p:IsShown() then p:Hide() else p:Show() end
end
