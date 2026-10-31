local addonName, ns = ...

-- Scanner métiers (données de base).
-- Collecte nom, icône, skillLine et rang via GetProfessions() /
-- GetProfessionInfo() dans charData.professions. N'ouvre pas le panneau
-- métier ni C_TradeSkillUI (scan approfondi → scanner/Deep.lua).
-- Déclencheurs : PLAYER_LOGIN +8 s, SKILL_LINES_CHANGED (debounce 3 s).
-- Point d'entrée : ns.ScanBasicProfessions() (aussi appelé par /vl scan).

-- ── Collecte des slots actifs ─────────────────────────────────────
-- GetProfessions() retourne jusqu'à 6 valeurs dont certaines nil.
-- On vérifie chaque slot un par un (ipairs s'arrêterait au 1er nil).
local function CollectSlots()
    local slots = {}
    local p1, p2, ar, fi, co = GetProfessions()

    local function addSlot(idx, isSecondary)
        if not idx then return end
        local name, icon, rank, maxRank, _, _, skillLine = GetProfessionInfo(idx)
        if name and skillLine then
            slots[#slots + 1] = {
                name      = name,
                icon      = icon,
                rank      = rank,
                maxRank   = maxRank,
                skillLine = skillLine,
                secondary = isSecondary,
            }
        end
    end

    addSlot(p1, false)
    addSlot(p2, false)
    addSlot(ar, true)
    addSlot(fi, true)
    addSlot(co, true)
    return slots
end

-- ── Scan basique ─────────────────────────────────────────────────
function ns.ScanBasicProfessions()
    -- GetCurrentCharData vit dans le core → accès via l'API partagée.
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetCurrentCharData then return end
    local charData = vlAPI.GetCurrentCharData()
    if not charData then return end

    local slots = CollectSlots()
    if #slots == 0 then return end

    charData.professions = charData.professions or {}

    -- Purge des métiers abandonnés ou remplacés
    local current = {}
    for _, s in ipairs(slots) do current[s.name] = true end
    for i = #charData.professions, 1, -1 do
        if not current[charData.professions[i].name] then
            table.remove(charData.professions, i)
        end
    end

    -- Mise à jour ou création des entrées
    for _, slot in ipairs(slots) do
        local found = false
        for _, p in ipairs(charData.professions) do
            if p.name == slot.name then
                p.icon      = slot.icon      or p.icon
                p.skillLine = slot.skillLine or p.skillLine
                p.secondary = slot.secondary
                p.basicRank = slot.rank
                p.basicMax  = slot.maxRank
                -- Tier de base seulement si pas encore de scan approfondi.
                if not p.scanned then
                    p.tiers = {{ name = slot.name, level = slot.rank, max = slot.maxRank, manual = false }}
                end
                found = true
                break
            end
        end
        if not found then
            charData.professions[#charData.professions + 1] = {
                name         = slot.name,
                icon         = slot.icon,
                skillLine    = slot.skillLine,
                secondary    = slot.secondary,
                basicRank    = slot.rank,
                basicMax     = slot.maxRank,
                tiers        = {{ name = slot.name, level = slot.rank, max = slot.maxRank, manual = false }},
                knownRecipes = {},
                scanned      = false,   -- passé à true par le scan approfondi (Deep.lua)
            }
        end
    end

    ns.NotifyProfessionsScanned()
end

-- ── Table de callbacks multi-listener ─────────────────────────────
-- Les consommateurs s'enregistrent via ns.RegisterProfessionsCallback.
local profCallbacks = {}

-- Notifie les consommateurs (scan de base ou approfondi terminé).
function ns.NotifyProfessionsScanned()
    for _, fn in ipairs(profCallbacks) do fn() end
end

function ns.RegisterProfessionsCallback(fn)
    if type(fn) == "function" then
        profCallbacks[#profCallbacks + 1] = fn
    end
end

-- ── Hooks appelés par Init.lua ────────────────────────────────────
-- PLAYER_LOGIN +8 s : GetProfessions() fiable une fois le perso chargé.
function ns.OnProfessionsLogin()
    C_Timer.After(8, ns.ScanBasicProfessions)
end

-- SKILL_LINES_CHANGED (gain de rang / changement de métier), debounce 3 s.
local _skillPending = false
function ns.OnSkillLinesChanged()
    if _skillPending then return end
    _skillPending = true
    C_Timer.After(3, function()
        _skillPending = false
        ns.ScanBasicProfessions()
    end)
end
