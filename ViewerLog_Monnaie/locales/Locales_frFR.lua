local addonName, ns = ...

-- Localisation ViewerLog_Monnaie. Table et ns.L propres à la dépendance.

ns.locales = ns.locales or {}

ns.locales["frFR"] = {
    TT_OWNED_BY   = "Possédé par",
    TT_TOTAL      = "Total",
}

-- Traduction : langue AltViewerLog si dispo, sinon client ; repli enUS puis tag.
function ns.L(key)
    local lang = (_G.AltViewerLogDB and _G.AltViewerLogDB.settings and _G.AltViewerLogDB.settings.lang) or GetLocale()
    local tbl = ns.locales[lang] or ns.locales["enUS"]
    return (tbl and tbl[key]) or (ns.locales["enUS"] and ns.locales["enUS"][key]) or ("[VLM:" .. tostring(key) .. "]")
end
