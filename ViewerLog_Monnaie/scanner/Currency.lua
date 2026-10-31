local addonName, ns = ...

-- Scanner monnaies.
-- Capture les monnaies découvertes du perso connecté via C_CurrencyInfo
-- (pas l'or, géré par le core). La liste est positionnelle : on déplie les
-- en-têtes repliés (invisibles sinon), on scanne, puis on restaure l'état.
-- Scan synchrone en un passage (assez peu de monnaies pour ne pas chunker).
-- Déclencheurs (Init.lua) : ENTERING_WORLD (5 s), CURRENCY_DISPLAY_UPDATE
-- (debounce 1.5 s), logout (immédiat).

local time = time

-- ── Extraction robuste du currencyID ──────────────────────────────
-- currencyID absent sur certains clients → repli sur le lien.
local function GetListEntryID(index, info)
    if info.currencyID then
        return info.currencyID
    end
    local link = C_CurrencyInfo.GetCurrencyListLink and C_CurrencyInfo.GetCurrencyListLink(index)
    if link then
        local id = link:match("currency:(%d+)")
        if id then return tonumber(id) end
    end
    return nil
end

-- ── Déplie tous les en-têtes repliés ───────────────────────────────
-- Retourne les en-têtes dépliés (par nom) pour pouvoir restaurer ensuite.
local function ExpandAllCurrencyHeaders()
    local expandedNames = {}
    local i, guard = 1, 0
    while i <= C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(i, true)
            expandedNames[info.name] = true
        end
        i = i + 1
        guard = guard + 1
        if guard > 2000 then break end -- garde-fou anti-boucle infinie
    end
    return expandedNames
end

-- Replie les en-têtes dépliés par ce scan. Reparcourt par nom (les index
-- se décalent quand un en-tête amont est déplié).
local function RestoreHeaderState(expandedNames)
    if not next(expandedNames) then return end
    for i = C_CurrencyInfo.GetCurrencyListSize(), 1, -1 do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isHeader and info.isHeaderExpanded and expandedNames[info.name] then
            C_CurrencyInfo.ExpandCurrencyList(i, false)
        end
    end
end

-- ── Scan synchrone (un seul passage) ────────────────────────────────
local function ExecuteCurrencyScan()
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetCurrentCharData then return end
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then return end

    local charData = vlAPI.GetCurrentCharData()
    if not charData then return end

    local expandedNames = ExpandAllCurrencyHeaders()

    local now = time()
    local cur = {}

    for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        -- isDiscovered ~= false : si le champ manque, on inclut plutôt qu'exclut.
        if info and not info.isHeader and not info.isTotal and info.isDiscovered ~= false then
            local id = GetListEntryID(i, info)
            if id then
                cur[id] = {
                    name      = info.name,
                    quantity  = info.quantity or 0,
                    icon      = info.iconFileID,
                    updatedAt = now,
                }
            end
        end
    end

    RestoreHeaderState(expandedNames)

    charData.currencies = cur
end

-- ── Debounce CURRENCY_DISPLAY_UPDATE ──────────────────────────────
local _curTimer = nil

-- Scan des monnaies. debounce = true → délai 1.5 s (absorbe les rafales),
-- sinon scan immédiat (connexion / déconnexion).
function ns.ScanCurrencies(debounce)
    if debounce then
        if _curTimer then _curTimer:Cancel() end
        _curTimer = C_Timer.NewTimer(1.5, function()
            _curTimer = nil
            ExecuteCurrencyScan()
        end)
    else
        if _curTimer then
            _curTimer:Cancel()
            _curTimer = nil
        end
        ExecuteCurrencyScan()
    end
end

-- ── Accesseur ──────────────────────────────────────────────────────
-- Exposé sur _G.ViewerLogAPI depuis Init.lua (co-localisé avec les données).
-- Retourne { [currencyID] = { name, quantity, icon, updatedAt } } ou nil.
function ns.GetCurrencies(charName, realmName)
    local vlAPI = _G.ViewerLogAPI
    local d = vlAPI and vlAPI.GetCharacter and vlAPI.GetCharacter(charName, realmName)
    return d and d.currencies
end
