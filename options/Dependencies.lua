local addonName, ns = ...

-- Onglet Modules : active/désactive les addons satellites ViewerLog
-- (colonne gauche) et AltViewerLog (colonne droite). Cascade/symétrie
-- décrites ci-dessous.

ns.UI = ns.UI or {}

-- ── Dépendances optionnelles ─────────────────────────────────────
-- Deux colonnes indépendantes :
--   · Gauche  = modules ViewerLog (ViewerLog_X). Basculer une case ici
--     agit AUSSI sur le module AltViewerLog associé (avlName) :
--       - décocher ViewerLog_Guild → décoche AltViewerLog_GuildeLog (cascade)
--       - cocher   ViewerLog_Guild → coche   AltViewerLog_GuildeLog (symétrique)
--   · Droite  = AltViewerLog + ses modules (AltViewerLog_X). Basculer une
--     case ici n'agit QUE sur ce module Alt, sans jamais toucher ViewerLog.
-- L'activation/désactivation d'un addon ne prend effet qu'au /reload
-- suivant → popup VL_RELOAD_UI après chaque bascule.
-- avlName = contrepartie AltViewerLog à faire suivre (cascade/symétrie).
-- Monnaie et Recette n'ont PAS d'addon AltViewerLog_* dédié (la partie
-- recettes vit dans AltViewerLog_Professions) → avlName = nil.
local VL_MODULES = {
    { vlName = "ViewerLog_Tooltip",     avlName = nil,                        labelKey = "DEP_TOOLTIP" },
    { vlName = "ViewerLog_Guild",       avlName = "AltViewerLog_GuildeLog",   labelKey = "DEP_GUILD"   },
    { vlName = "ViewerLog_Reput",       avlName = "AltViewerLog_Reput",       labelKey = "DEP_REPUT"   },
    { vlName = "ViewerLog_Professions", avlName = "AltViewerLog_Professions", labelKey = "DEP_PROF"    },
    { vlName = "ViewerLog_Monnaie",     avlName = nil,                        labelKey = "DEP_MONNAIE" },
    { vlName = "ViewerLog_Recette",     avlName = nil,                        labelKey = "DEP_RECETTE" },
}

-- Colonne droite : uniquement les addons AltViewerLog qui existent réellement
-- (cœur + plugins). Graphique n'a pas de contrepartie ViewerLog (il lit les
-- données du cœur ViewerLog) : il reste donc purement à droite.
local AVL_MODULES = {
    { avlName = "AltViewerLog",             labelKey = "DEP_AVL_CORE"  },
    { avlName = "AltViewerLog_GuildeLog",   labelKey = "DEP_AVL_GUILD" },
    { avlName = "AltViewerLog_Reput",       labelKey = "DEP_AVL_REPUT" },
    { avlName = "AltViewerLog_Professions", labelKey = "DEP_AVL_PROF"  },
    { avlName = "AltViewerLog_Graph",       labelKey = "DEP_AVL_GRAPH" },
}

-- L'addon existe-t-il dans la liste (installé, activé ou non) ?
local function AddonExists(name)
    if not C_AddOns or not C_AddOns.GetAddOnInfo then return false end
    local ok, info = pcall(C_AddOns.GetAddOnInfo, name)
    return ok and info ~= nil
end

-- État activé/désactivé. Plusieurs signatures essayées (l'API a changé de
-- forme selon les versions), repli sur IsAddOnLoaded.
local function AddonIsEnabled(name)
    if not C_AddOns then return false end
    if C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, name)
        if ok and type(state) == "number" then return state ~= 0 end
        local ok2, state2 = pcall(C_AddOns.GetAddOnEnableState, nil, name)
        if ok2 and type(state2) == "number" then return state2 ~= 0 end
    end
    if C_AddOns.IsAddOnLoaded then
        local ok3, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        if ok3 then return loaded end
    end
    return false
end

local function SetAddonEnabled(name, enabled)
    if not C_AddOns or not AddonExists(name) then return false end
    local fn = enabled and C_AddOns.EnableAddOn or C_AddOns.DisableAddOn
    if not fn then return false end
    return (pcall(fn, name))
end

-- Une ligne = une checkbox (même composant que les réglages infobulles).
-- Grisée et décochée si le module n'est pas installé.
-- refreshOther : callback appelé après une bascule pour resynchroniser
-- la colonne d'en face (une bascule gauche modifie aussi une case droite).

-- Colonne GAUCHE (ViewerLog) : cascade vers le module Alt associé.
local function BuildVLRow(parent, anchor, offX, offY, mod, refreshOther)
    local installed = AddonExists(mod.vlName)
    local cb = ns.UI.Checkbox(parent,
        ns.L(mod.labelKey),
        installed and ns.L("DEP_VL_TIP") or ns.L("DEP_NOT_INSTALLED"),
        anchor, offX, offY,
        function() return installed and AddonIsEnabled(mod.vlName) end,
        function(v)
            SetAddonEnabled(mod.vlName, v)
            -- Cascade (désactivation) et symétrie (réactivation) vers Alt.
            if mod.avlName then SetAddonEnabled(mod.avlName, v) end
            if refreshOther then refreshOther() end
            StaticPopup_Show("VL_RELOAD_UI")
        end)
    if not installed then ns.UI.SetCheckboxEnabled(cb, false) end
    return cb
end

-- Colonne DROITE (AltViewerLog) : agit uniquement sur ce module Alt.
local function BuildAVLRow(parent, anchor, offX, offY, mod)
    local installed = AddonExists(mod.avlName)
    local cb = ns.UI.Checkbox(parent,
        ns.L(mod.labelKey),
        installed and ns.L("DEP_AVL_TIP") or ns.L("DEP_NOT_INSTALLED"),
        anchor, offX, offY,
        function() return installed and AddonIsEnabled(mod.avlName) end,
        function(v)
            SetAddonEnabled(mod.avlName, v)
            StaticPopup_Show("VL_RELOAD_UI")
        end)
    if not installed then ns.UI.SetCheckboxEnabled(cb, false) end
    return cb
end

-- Construit la page Modules (cadre deux colonnes) dans `page`.
-- Renvoie { Refresh } à appeler à l'affichage.
function ns.UI.BuildDependenciesSection(page)
    local DEP_BOX_H   = 250
    local COL_RIGHT_X = 322

    local depBox = ns.UI.StyledFrame(page, nil, nil, "box")
    depBox:SetPoint("TOPLEFT",  page, "TOPLEFT",  10, -10)
    depBox:SetPoint("TOPRIGHT", page, "TOPRIGHT", -10, -10)
    depBox:SetHeight(DEP_BOX_H)

    -- En-têtes de colonnes
    local hdrVL = depBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrVL:SetPoint("TOPLEFT", depBox, "TOPLEFT", 12, -10)
    hdrVL:SetText(ns.L("SECTION_DEP_VL"))
    ns.UI.Tint(hdrVL, "accent")

    local hdrAVL = depBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdrAVL:SetPoint("TOPLEFT", depBox, "TOPLEFT", COL_RIGHT_X, -10)
    hdrAVL:SetText(ns.L("SECTION_DEP_AVL"))
    ns.UI.Tint(hdrAVL, "accent")

    -- Séparateur vertical entre les deux colonnes
    local depVSep = depBox:CreateTexture(nil, "ARTWORK")
    depVSep:SetWidth(1)
    depVSep:SetPoint("TOPLEFT",    depBox, "TOPLEFT",    COL_RIGHT_X - 12, -6)
    depVSep:SetPoint("BOTTOMLEFT", depBox, "BOTTOMLEFT", COL_RIGHT_X - 12,  6)
    ns.UI.Tint(depVSep, "accentDim", 0.80)

    -- Ancres de tête : chaque ligne s'ancre au BOTTOMLEFT de la précédente.
    local leftTopAnchor = CreateFrame("Frame", nil, depBox)
    leftTopAnchor:SetSize(1, 1)
    leftTopAnchor:SetPoint("TOPLEFT", depBox, "TOPLEFT", 12, -30)

    local rightTopAnchor = CreateFrame("Frame", nil, depBox)
    rightTopAnchor:SetSize(1, 1)
    rightTopAnchor:SetPoint("TOPLEFT", depBox, "TOPLEFT", COL_RIGHT_X, -30)

    -- Resynchronise la colonne droite après une bascule gauche.
    local depAVLRows
    local function RefreshAVLRows()
        if not depAVLRows then return end
        for i, mod in ipairs(AVL_MODULES) do
            local cb = depAVLRows[i]
            local installed = AddonExists(mod.avlName)
            ns.UI.SetCheckboxEnabled(cb, installed)
            cb:SetChecked(installed and AddonIsEnabled(mod.avlName))
        end
    end

    local depVLRows = {}
    local prevRow = leftTopAnchor
    for i, mod in ipairs(VL_MODULES) do
        depVLRows[i] = BuildVLRow(depBox, prevRow, 0, (i == 1) and 0 or -8, mod, RefreshAVLRows)
        prevRow = depVLRows[i]
    end

    depAVLRows = {}
    prevRow = rightTopAnchor
    for i, mod in ipairs(AVL_MODULES) do
        depAVLRows[i] = BuildAVLRow(depBox, prevRow, 0, (i == 1) and 0 or -8, mod)
        prevRow = depAVLRows[i]
    end

    local function Refresh()
        for i, mod in ipairs(VL_MODULES) do
            local cb = depVLRows[i]
            local installed = AddonExists(mod.vlName)
            ns.UI.SetCheckboxEnabled(cb, installed)
            cb:SetChecked(installed and AddonIsEnabled(mod.vlName))
        end
        RefreshAVLRows()
    end

    return { Refresh = Refresh }
end
