local addonName, ns = ...

-- Scanner recettes de métier.
-- Capture toutes les recettes (connues et non, selon capacité client) du
-- métier ouvert : nom, icône, statut appris, palier d'extension.
-- Détail API par client → scanner/RecipeAPI.lua (moderne / legacy). Cette
-- fusion/stockage ne dépend que du contrat callback(key, name, icon,
-- learned, tier) de RecipeAPI, pas des fonctions Blizzard elles-mêmes.
-- La liste n'est lisible que fenêtre de métier ouverte (ouverture par code
-- = protégée) → aucun scan passif ici.
-- Stockage FUSIONNÉ (pas remplacé) : charData.recipes[profName].entries
-- s'enrichit scan après scan. Séparé de charData.professions pour ne pas
-- créer de dépendance croisée avec AltViewerLog_Professions.
-- formatVersion : reconstruit charData.recipes si la forme a changé.
-- Déclencheurs (Init.lua) : TRADE_SKILL_SHOW (0.5 s), TRADE_SKILL_LIST_UPDATE
-- (debounce 1 s). Pas de scan au login/logout.

local time = time
local FORMAT_VERSION = 2

-- ── Scan du métier actuellement ouvert (fusion, pas remplacement) ──
local function ExecuteRecipeScan()
    local api = ns.RecipeAPI
    if not api or not (api.hasModern or api.hasLegacy) then return end
    if not api.IsReady() then return end

    local profName = api.GetOpenProfessionName()
    if not profName then return end

    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetCurrentCharData then return end
    local charData = vlAPI.GetCurrentCharData()
    if not charData then return end

    charData.recipes = charData.recipes or {}
    local slot = charData.recipes[profName]
    if not slot or slot.formatVersion ~= FORMAT_VERSION or type(slot.entries) ~= "table" then
        slot = { entries = {}, total = 0, known = 0, formatVersion = FORMAT_VERSION, updatedAt = 0 }
    end

    local changed = false
    local function OnRecipe(key, name, icon, learned, tier)
        local existing = slot.entries[key]
        if not existing
            or existing.learned ~= learned
            or existing.tier    ~= tier
            or existing.name    ~= name
            or existing.icon    ~= icon
        then
            slot.entries[key] = { name = name, icon = icon, learned = learned, tier = tier }
            changed = true
        end
    end

    if api.hasModern then
        api.ForEachRecipeModern(profName, OnRecipe)
    else
        api.ForEachRecipeLegacy(profName, OnRecipe)
    end

    if changed then
        local total, known = 0, 0
        for _, e in pairs(slot.entries) do
            total = total + 1
            if e.learned then known = known + 1 end
        end
        slot.total     = total
        slot.known     = known
        slot.updatedAt = time()
        charData.recipes[profName] = slot
    end
end

-- ── Debounce TRADE_SKILL_LIST_UPDATE ──────────────────────────────
local _listTimer = nil

-- Scan du métier ouvert. debounce = true → délai 1 s (TRADE_SKILL_LIST_UPDATE),
-- sinon scan immédiat (TRADE_SKILL_SHOW).
function ns.ScanOpenProfessionRecipes(debounce)
    if debounce then
        if _listTimer then _listTimer:Cancel() end
        _listTimer = C_Timer.NewTimer(1.0, function()
            _listTimer = nil
            ExecuteRecipeScan()
        end)
    else
        if _listTimer then _listTimer:Cancel(); _listTimer = nil end
        ExecuteRecipeScan()
    end
end

-- ── Accesseur ──────────────────────────────────────────────────────
-- Retourne { [professionName] = { entries = {[key]={name,icon,learned,tier}},
-- total, known, updatedAt } } ou nil. key = recipeID (moderne) ou itemID/nom
-- (legacy) — opaque pour l'appelant (il ne fait qu'itérer dessus).
function ns.GetRecipes(charName, realmName)
    local vlAPI = _G.ViewerLogAPI
    local d = vlAPI and vlAPI.GetCharacter and vlAPI.GetCharacter(charName, realmName)
    return d and d.recipes
end
