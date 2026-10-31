local addonName, ns = ...

-- Localisation ViewerLog_Guild. Table et ns.L propres à la dépendance.

ns.locales = {}

ns.locales["frFR"] = {
    -- scanner/Guild.lua — nom de fallback pour un onglet sans nom
    GUILD_TAB_FALLBACK = "Onglet ",
}

function ns.L(key)
    local lang = (_G.AltViewerLogDB and _G.AltViewerLogDB.settings
                  and _G.AltViewerLogDB.settings.lang)
                 or GetLocale()
    local t = ns.locales[lang] or ns.locales["frFR"]
    return t[key] or ("[VLG:" .. key .. "]")
end
