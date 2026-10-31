local addonName, ns = ...

ns.locales = {}

-- ── Français ─────────────────────────────────────────
ns.locales["frFR"] = {
    -- ── Infobulle d'objet (addon ViewerLog_Tooltip) ─────────────
    TT_OWNED_BY = "Possédé par",
    TT_BAG      = "Sac",
    TT_BANK     = "Banque",
    TT_MAIL     = "Courrier",
    TT_GUILD    = "Guilde",
    TT_TOTAL    = "Total",

    -- ── Commandes slash /vl ──────────────────────────────────────
    SLASH_SCAN_DONE          = "Scan inventaire effectué.",
    SLASH_REPUT_SCAN_DONE    = "Scan réputations effectué.",
    SLASH_REPUT_NONE         = "Dépendance ViewerLog_Reput non installée.",
    SLASH_GUILD_SCAN_STARTED = "Scan coffre de guilde lancé.",
    SLASH_GUILD_SCAN_DONE    = "Scan coffre de guilde terminé.",
    SLASH_GUILD_NONE_OPEN    = "Aucun coffre de guilde ouvert.",
    SLASH_HELP_OPTIONS       = "  /vl |cffffff00options|r   — paramètres",
    SLASH_HELP_SCAN          = "  /vl |cffffff00scan|r      — scan inventaire",
    SLASH_HELP_REPUT         = "  /vl |cffffff00reput|r     — scan réputations",
    SLASH_HELP_GUILD         = "  /vl |cffffff00guild|r     — scan coffre de guilde",

    -- ── Panneau de paramètres (options/*) ───────────────
    DELETE_BTN          = "Supprimer",
    CANCEL_BTN          = "Annuler",

    TT_PREVIEW_HEADER   = "Aperçu infobulle",
    PREVIEW_CHAR_SAMPLE  = "VotrePerso",
    PREVIEW_REALM_SAMPLE = "Royaume",
    PREVIEW_GUILD_SAMPLE = "NomGuilde",

    TAB_GENERAL = "Général",
    TAB_MODULES = "Modules",
    TAB_THEME   = "Thème",

    TT_CARD_TITLE          = "Infobulle ViewerLog",
    TT_CARD_DESC           = "Affiche vos personnages dans l'infobulle des objets",
    CB_TOOLTIP_ENABLED_TIP = "Affiche ou masque l'ajout d'infos ViewerLog dans les infobulles.\n|cffaaaaaa(Effet immédiat, dans les deux sens.)|r",
    SECTION_TOOLTIP_SHOW   = "AFFICHER DANS L'INFOBULLE",
    CB_SHOW_ICONS          = "Les icônes",
    CB_SHOW_ICONS_TIP      = "Affiche les icônes (faction, guilde) devant les lignes.",
    CB_SHOW_GUILD          = "Les guildes",
    CB_SHOW_GUILD_TIP      = "Affiche les lignes relatives aux guildes.",
    CB_SHOW_REALM          = "Le royaume",
    CB_SHOW_REALM_TIP      = "Affiche le royaume à côté du nom des personnages dans les infobulles.",

    SECTION_CHARACTERS = "PERSONNAGES",
    SECTION_GUILDS     = "GUILDES",

    SECTION_THEME  = "THÈME DU PANNEAU",
    THEME_HYBRID   = "ViewerLog",
    THEME_BLIZZARD = "Blizzard",

    DISCORD_BTN_LABEL   = "Discord",
    DISCORD_BTN_TIP     = "Rejoindre le serveur Discord de ViewerLog",
    DISCORD_HINT        = "Sélectionne tout (Ctrl+A) puis copie (Ctrl+C).",

    SECTION_DEP_VL       = "ViewerLog",
    SECTION_DEP_AVL      = "AltViewerLog",

    DEP_TOOLTIP          = "Infobulle |cffb45cff(ViewerLog_Tooltip)|r",
    DEP_GUILD            = "Guilde |cff4a9eff(ViewerLog_Guild)|r",
    DEP_REPUT            = "Réputations |cffb45cff(ViewerLog_Reput)|r",
    DEP_PROF             = "Métiers |cff4ade80(ViewerLog_Professions)|r",
    DEP_MONNAIE          = "Monnaies |cffb45cff(ViewerLog_Monnaie)|r",
    DEP_RECETTE          = "Recettes |cff4ade80(ViewerLog_Recette)|r",
    -- Colonne AltViewerLog (droite)
    DEP_AVL_CORE         = "AltViewerLog |cff4da6ff(cœur)|r",
    DEP_AVL_GUILD        = "Guilde |cff4a9eff(AltViewerLog_GuildeLog)|r",
    DEP_AVL_REPUT        = "Réputations |cffb45cff(AltViewerLog_Reput)|r",
    DEP_AVL_PROF         = "Métiers |cff4ade80(AltViewerLog_Professions)|r",
    DEP_AVL_GRAPH        = "Graphique |cff4da6ff(AltViewerLog_Graph)|r",
    DEP_AVL_MONNAIE      = "Monnaies |cffb45cff(AltViewerLog_Monnaie)|r",
    DEP_AVL_RECETTE      = "Recettes |cff4ade80(AltViewerLog_Recette)|r",
    DEP_VL_TIP           = "Active ou désactive ce module ViewerLog, ainsi que le module AltViewerLog associé.\n|cffaaaaaa(Nécessite un /reload)|r",
    DEP_AVL_TIP          = "Active ou désactive uniquement ce module AltViewerLog, sans toucher à ViewerLog.\n|cffaaaaaa(Nécessite un /reload)|r",
    DEP_TIP              = "Active ou désactive cette dépendance, ainsi que le plugin AltViewerLog associé.\n|cffaaaaaa(Nécessite un /reload)|r",
    DEP_NOT_INSTALLED    = "Dépendance non installée.",
    NO_CHAR_REGISTERED   = "Aucun personnage enregistré.",
    NO_GUILD_SCANNED     = "Aucune guilde scannée.",

    POPUP_RELOAD_TEXT    = "Ce changement nécessite un rechargement de l'interface pour prendre effet.\nRecharger maintenant ?",
    POPUP_RELOAD_BTN1    = "Recharger",
    POPUP_RELOAD_BTN2    = "Plus tard",
    POPUP_DEL_CHAR_TEXT  = "Supprimer |cffffff00%s|r de ViewerLogDB ?\n|cffaaaaaa(irréversible)|r",
    POPUP_DEL_GUILD_TEXT = "Supprimer le coffre de guilde\n|cffffff00%s|r ?\n|cffaaaaaa(irréversible)|r",

    MINIMAP_TT_CLICK     = "Clic gauche : Paramètres",

    -- Section injectée dans le panneau Settings de AltViewerLog
    VL_SECTION_DESC      = "Les infobulles, personnages et guildes se gèrent dans ViewerLog.",
    VL_OPEN_SETTINGS_BTN = "Ouvrir les paramètres ViewerLog",
}

-- Traduction : langue choisie dans AltViewerLog si dispo, sinon celle du client.
function ns.L(key)
    local lang = (_G.AltViewerLogDB and _G.AltViewerLogDB.settings
                  and _G.AltViewerLogDB.settings.lang)
                 or GetLocale()
    local t = ns.locales[lang] or ns.locales["frFR"]
    return t[key] or ("[VL:" .. key .. "]")
end
