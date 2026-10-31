local addonName, ns = ...

-- Localisation ViewerLog_Recette. Table et ns.L propres à la dépendance.

ns.locales = ns.locales or {}

ns.locales["frFR"] = {
    RECIPES_LABEL   = "Recettes %d / %d",
    RECIPES_NO_DATA = "Aucune donnée — ouvrez ce métier une fois",
    RECIPES_TOOLTIP = "%d / %d recettes connues",
    RECIPES_FOLD    = "Replier",
    RECIPES_UNFOLD  = "Déplier",
    RECIPES_OTHER   = "Autres",
}

-- Traduction : langue AltViewerLog si dispo, sinon client ; repli enUS puis tag.
function ns.L(key)
    local lang = (_G.AltViewerLogDB and _G.AltViewerLogDB.settings and _G.AltViewerLogDB.settings.lang) or GetLocale()
    local tbl = ns.locales[lang] or ns.locales["enUS"]
    return (tbl and tbl[key]) or (ns.locales["enUS"] and ns.locales["enUS"][key]) or ("[VLREC:" .. tostring(key) .. "]")
end
