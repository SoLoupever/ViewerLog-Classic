local addonName, ns = ...

-- Abstraction API recettes selon le client.
-- Deux familles réelles seulement (vérifié dans les sources Blizzard) :
--   "moderne" : Retail + Forever/Camelot → C_TradeSkillUI schématique
--               (GetFilteredRecipeIDs / GetCategories / GetRecipeInfo).
--   "legacy"  : Classic Era / TBC / MoP  → API globale par index
--               (GetNumTradeSkills / GetTradeSkillInfo), pas de C_TradeSkillUI.
-- Détection par capacité, pas par WOW_PROJECT_ID : évite de dépendre d'un
-- identifiant de version pour chaque nouveau flavor client (ex. Camelot).
-- Isolé de Recipes.lua pour que les futurs changements d'API par client
-- ne touchent pas la logique de fusion/stockage.

local HAS_MODERN = C_TradeSkillUI ~= nil
    and C_TradeSkillUI.GetFilteredRecipeIDs ~= nil
    and C_TradeSkillUI.GetRecipeInfo ~= nil
    and C_TradeSkillUI.GetCategories ~= nil
    and C_TradeSkillUI.GetCategoryInfo ~= nil

local HAS_LEGACY = GetNumTradeSkills ~= nil and GetTradeSkillInfo ~= nil

ns.RecipeAPI = { hasModern = HAS_MODERN, hasLegacy = HAS_LEGACY }

-- ── Nom du métier ouvert ─────────────────────────────────────────
function ns.RecipeAPI.GetOpenProfessionName()
    if HAS_MODERN and C_TradeSkillUI.GetBaseProfessionInfo then
        local info = C_TradeSkillUI.GetBaseProfessionInfo()
        local n = info and (info.professionName or info.parentProfessionName or info.name)
        if n and n ~= "" then return n end
    end
    if HAS_LEGACY then
        -- Global, pas namespacé C_TradeSkillUI sur ces clients.
        local name = GetTradeSkillLine()
        if name and name ~= "" then return name end
    end
    return nil
end

-- ── Fenêtre de métier exploitable ────────────────────────────────
function ns.RecipeAPI.IsReady()
    if HAS_MODERN then
        return not C_TradeSkillUI.IsTradeSkillReady or C_TradeSkillUI.IsTradeSkillReady()
    end
    if HAS_LEGACY then
        return (GetNumTradeSkills() or 0) > 0
    end
    return false
end

-- ── Filtres UI moderne (sauvegarde / reset / restauration) ───────
-- GetFilteredRecipeIDs respecte les filtres d'affichage courants (appris,
-- non appris, sources...). Sans reset, un filtre actif au moment du scan
-- ferait disparaître des recettes du résultat.
local function CaptureFilters()
    return {
        showLearned    = C_TradeSkillUI.GetShowLearned(),
        showUnlearned  = C_TradeSkillUI.GetShowUnlearned(),
        onlyMakeable   = C_TradeSkillUI.GetOnlyShowMakeableRecipes(),
        onlySkillUp    = C_TradeSkillUI.GetOnlyShowSkillUpRecipes(),
        onlyFirstCraft = C_TradeSkillUI.GetOnlyShowFirstCraftRecipes(),
    }
end

local function ApplyFilters(f)
    C_TradeSkillUI.SetShowLearned(f.showLearned)
    C_TradeSkillUI.SetShowUnlearned(f.showUnlearned)
    C_TradeSkillUI.SetOnlyShowMakeableRecipes(f.onlyMakeable)
    C_TradeSkillUI.SetOnlyShowSkillUpRecipes(f.onlySkillUp)
    C_TradeSkillUI.SetOnlyShowFirstCraftRecipes(f.onlyFirstCraft)
end

local function ResetFiltersForScan()
    C_TradeSkillUI.SetShowLearned(true)
    C_TradeSkillUI.SetShowUnlearned(true)
    C_TradeSkillUI.SetOnlyShowMakeableRecipes(false)
    C_TradeSkillUI.SetOnlyShowSkillUpRecipes(false)
    C_TradeSkillUI.SetOnlyShowFirstCraftRecipes(false)
end

-- Racine de la chaîne de catégories = regroupement le plus proche d'un
-- "palier" d'extension côté API moderne (pas de champ dédié sur la recette).
local function RootCategoryName(categoryID)
    local info = C_TradeSkillUI.GetCategoryInfo(categoryID)
    local hops = 0
    while info and info.parentCategoryID and hops < 8 do
        info = C_TradeSkillUI.GetCategoryInfo(info.parentCategoryID)
        hops = hops + 1
    end
    return info and info.name or nil
end

-- ── Itération recettes : moderne (Retail + Camelot/Forever) ──────
-- callback(key, name, icon, learned, tier)
function ns.RecipeAPI.ForEachRecipeModern(profName, callback)
    local saved = CaptureFilters()
    ResetFiltersForScan()

    local ids = C_TradeSkillUI.GetFilteredRecipeIDs()
    for _, recipeID in ipairs(ids or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info then
            local tier = (info.categoryID and RootCategoryName(info.categoryID)) or profName
            callback(recipeID, info.name, info.icon, info.learned or false, tier)
        end
    end

    ApplyFilters(saved)
end

-- ── Itération recettes : legacy (Classic Era / TBC / MoP) ────────
-- La fenêtre de métier du joueur ne liste QUE les recettes déjà apprises
-- (pas de vue "non apprises" côté client sur cette API) → learned = true.
-- Pas d'identifiant persistant exposé : clé dérivée de l'ID présent dans
-- le lien de l'objet crafté, repli sur le nom si le lien n'en contient pas.
-- Pas de notion de palier d'extension sur cette API → repli sur profName.
function ns.RecipeAPI.ForEachRecipeLegacy(profName, callback)
    local total = GetNumTradeSkills() or 0
    for i = 1, total do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType ~= "header" and skillType ~= "subheader" then
            local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local key  = (link and tonumber(link:match(":(%d+)"))) or name
            local icon = GetTradeSkillIcon and GetTradeSkillIcon(i)
            callback(key, name, icon, true, profName)
        end
    end
end
