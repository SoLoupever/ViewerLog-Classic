local addonName, ns = ...

-- Scanner réputations.
-- Capture les réputations du perso via l'API historique (GetFactionInfo /
-- GetNumFactions) : C_Reputation.GetFactionDataByIndex et consorts n'existent
-- qu'en retail (11.0.0+), absents sur Classic. C_MajorFactions (renom DF/TWW)
-- reste testé mais ne matchera jamais aucune faction Classic.
-- Compat WoW Forever (bêta) : GetFactionInfo/GetNumFactions/Expand·Collapse-
-- AllFactionHeaders sont des globaux dépréciés côté Retail. Sur Retail ils
-- restent utilisables (pont de compatibilité du client), mais WoW Forever
-- n'a pas ce pont -> ces globaux y valent nil. On préfère donc les
-- équivalents C_Reputation (GetFactionDataByIndex, GetNumFactions,
-- Expand/CollapseAllFactionHeaders) quand ils existent, avec repli sur les
-- globaux pour Classic où seuls ces derniers existent. Cf. GetFactionEntryAt
-- et les locales _ExpandAllFactionHeaders / _CollapseAllFactionHeaders /
-- _GetNumFactions ci-dessous.
-- Itération : la liste est positionnelle et les factions sous header replié
-- sont invisibles → ExpandAllFactionHeaders puis CollapseAllFactionHeaders.
-- Écriture différentielle : UPDATE_FACTION ne dit pas quelle faction a
-- changé → relecture complète, mais on ne réécrit (EntriesEqual) que les
-- factions réellement modifiées, en place.
-- Deux modes (ScanFactionRange factorise la logique) :
--   · Synchrone — logout / commande manuelle (résultat immédiat).
--   · Étalé sur plusieurs frames — UPDATE_FACTION / scan initial (lisse le
--     pic CPU ; budget de temps par frame, cf. TICK_BUDGET_MS).
-- Déclencheurs (Init.lua) : ENTERING_WORLD (5 s, étalé, 1×/session),
-- UPDATE_FACTION (debounce 2 s, étalé), logout (synchrone).

local math_floor = math.floor
local math_min   = math.min
local time       = time

-- ── Compat API réputation (Retail <11.0 & Classic vs Retail 11.0+ & WoW
-- Forever) ──────────────────────────────────────────────────────────────
-- On choisit la fonction moderne C_Reputation quand elle existe (Retail
-- 11.0+, WoW Forever) et on ne retombe sur le vieux global que s'il n'y a
-- pas d'équivalent C_Reputation (Classic). Vérifié par fonction et non par
-- simple présence de la table C_Reputation (elle existe déjà sur Classic
-- pour d'autres usages du fichier, cf. IsMajorFaction/IsFactionParagon plus
-- bas, mais sans forcément exposer GetFactionDataByIndex/GetNumFactions/
-- Expand·CollapseAllFactionHeaders).
local _ExpandAllFactionHeaders =
    (C_Reputation and C_Reputation.ExpandAllFactionHeaders) or ExpandAllFactionHeaders
local _CollapseAllFactionHeaders =
    (C_Reputation and C_Reputation.CollapseAllFactionHeaders) or CollapseAllFactionHeaders
local _GetNumFactions =
    (C_Reputation and C_Reputation.GetNumFactions) or GetNumFactions
local _GetFactionDataByIndex = C_Reputation and C_Reputation.GetFactionDataByIndex

-- Lit une entrée de la liste réputation à l'index i, quelle que soit l'API
-- disponible. Renvoie les mêmes valeurs positionnelles que l'ancien
-- GetFactionInfo (name, standingID, bottom, top, standingVal, isHeader,
-- hasRep, isChild, fid) pour ne rien changer à ScanFactionRange.
-- Champs FactionData (C_Reputation.GetFactionDataByIndex) mappés d'après
-- la doc Blizzard : reaction→standingID, currentReactionThreshold→bottom,
-- nextReactionThreshold→top, currentStanding→standingVal,
-- isHeaderWithRep→hasRep, factionID→fid.
local function GetFactionEntryAt(i)
    if _GetFactionDataByIndex then
        local fd = _GetFactionDataByIndex(i)
        if not fd then return nil end
        return fd.name, fd.reaction, fd.currentReactionThreshold, fd.nextReactionThreshold,
               fd.currentStanding, fd.isHeader, fd.isHeaderWithRep, fd.isChild, fd.factionID
    end
    -- GetFactionInfo (legacy) : name, description, standingID, barMin,
    -- barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed,
    -- hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus.
    local name, _, standingID, bottom, top, standingVal, _, _,
          isHeader, _, hasRep, _, isChild, fid = GetFactionInfo(i)
    return name, standingID, bottom, top, standingVal, isHeader, hasRep, isChild, fid
end

-- ── Debounce UPDATE_FACTION ───────────────────────────────────────
-- Peut fire à chaque mob tué en farm de réputation → report de 2 s.
local _repTimer = nil

-- ── Étalement sur plusieurs frames ────────────────────────────────
-- Lisse le pic d'un scan complet (100-150 factions). Budget de TEMPS par
-- frame (et non un nombre fixe de factions) : majeures et paragon coûtent
-- plus, on mesure via debugprofilestop() et on s'arrête au dépassement.
-- TICK_BATCH espace juste les vérifications de temps.
local TICK_BUDGET_MS = 1.0
local TICK_BATCH      = 5
local _scanFrame = nil
local _scanToken = 0  -- incrémenté par scan : invalide un scan étalé
                       -- encore en cours si un plus récent démarre.

-- Fenêtre de réputation Blizzard ouverte : Expand/CollapseAllFactionHeaders
-- referme la faction ouverte → on reporte le scan étalé à sa fermeture.
local _pendingAfterClose = false
local _closeWatcher      = false

local function BlizzRepFrameShown()
    return ReputationFrame and ReputationFrame:IsShown()
end

local function EnsureCloseWatcher()
    if _closeWatcher or not ReputationFrame then return end
    _closeWatcher = true
    ReputationFrame:HookScript("OnHide", function()
        if _pendingAfterClose then
            _pendingAfterClose = false
            ns.ScanReputations(true)
        end
    end)
end

-- Compare une entrée stockée à une entrée fraîchement lue (hors updatedAt).
-- true si rien n'a changé pour cette faction.
local function EntriesEqual(a, b)
    if not a then return false end
    return a.name           == b.name
       and a.reaction       == b.reaction
       and a.standing       == b.standing
       and a.bottom         == b.bottom
       and a.top            == b.top
       and a.expansionGroup == b.expansionGroup
       and a.expansionOrder == b.expansionOrder
       and a.isAccountWide  == b.isAccountWide
       and a.isMajor        == b.isMajor
       and a.renown         == b.renown
       and a.renownEarned   == b.renownEarned
       and a.renownCap      == b.renownCap
       and a.maxRenown      == b.maxRenown
       and a.isUnlocked     == b.isUnlocked
       and a.paragonValue   == b.paragonValue
       and a.paragonCap     == b.paragonCap
       and a.paragonLevel   == b.paragonLevel
       and a.paragonReady   == b.paragonReady
end

-- Traite les factions [fromIndex, toIndex], n'écrit que celles qui ont changé
-- (EntriesEqual). Retourne l'index suivant + le groupe d'extension courant.
local function ScanFactionRange(reps, fromIndex, toIndex, numFac, expGroup, expOrder, now)
    for i = fromIndex, toIndex do
        local name, standingID, bottom, top, standingVal,
              isHeader, hasRep, isChild, fid = GetFactionEntryAt(i)
        if not name then
            return numFac + 1, expGroup, expOrder  -- fin de liste anticipée
        end

        -- Header de niveau supérieur → nouveau groupe d'extension.
        if isHeader and not isChild then
            expOrder = expOrder + 1
            expGroup = name
        end

        -- isHeader pur (ex. "Alliance") ignoré ; hasRep (= isHeaderWithRep) gardé.
        if (not isHeader or hasRep) then
            if fid and fid > 0 then

                local entry = {
                    name           = name,
                    reaction       = standingID,
                    standing       = standingVal,
                    bottom         = bottom,
                    top            = top,
                    expansionGroup = expGroup,
                    expansionOrder = expOrder,
                    -- Pas de notion de réputation compte-large côté API Classic.
                }

                -- ── Faction majeure (Renom) ────────────────────────
                -- DF / TWW : avancement via C_MajorFactions (pas reaction/standing).
                if C_Reputation.IsMajorFaction(fid) and C_MajorFactions then
                    local mfd = C_MajorFactions.GetMajorFactionData(fid)
                    if mfd then
                        entry.isMajor      = true
                        entry.renown       = mfd.renownLevel
                        entry.renownEarned = mfd.renownReputationEarned
                        entry.renownCap    = mfd.renownLevelThreshold
                        entry.maxRenown    = mfd.maxLevel
                        entry.isUnlocked   = mfd.isUnlocked or nil
                    end
                end

                -- ── Paragon ────────────────────────────────────────
                -- cur = total cumulé, cap = seuil par niveau → progress = cur % cap.
                if C_Reputation.IsFactionParagon(fid) then
                    local cur, cap, _, hasReward =
                        C_Reputation.GetFactionParagonInfo(fid)
                    if cur and cap and cap > 0 then
                        entry.paragonValue = cur % cap
                        entry.paragonCap   = cap
                        entry.paragonLevel = math_floor(cur / cap)
                        entry.paragonReady = hasReward or nil
                    end
                end

                -- N'écrit/horodate que si la faction a changé.
                if not EntriesEqual(reps[fid], entry) then
                    entry.updatedAt = now
                    reps[fid] = entry
                end
            end
        end
    end
    return toIndex + 1, expGroup, expOrder
end

-- ── Scan synchrone (un seul passage) ────────────────────────────
-- Logout / commande manuelle : résultat attendu immédiatement.
local function ExecuteReputationScanSync()
    -- GetCurrentCharData vit dans le core → accès via l'API partagée.
    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetCurrentCharData then return end
    local charData = vlAPI.GetCurrentCharData()
    if not charData then return end

    _ExpandAllFactionHeaders()

    local numFac = _GetNumFactions()
    local now    = time()

    -- Réutilise la table existante (diff en place).
    charData.reputations = charData.reputations or {}

    ScanFactionRange(charData.reputations, 1, numFac, numFac, nil, 0, now)

    _CollapseAllFactionHeaders()
end

-- ── Scan étalé (plusieurs frames) ───────────────────────────────
-- UPDATE_FACTION en combat, scan initial du login (cf. TICK_BUDGET_MS).
local function ExecuteReputationScanChunked()
    -- Fenêtre native ouverte : on reporte (cf. EnsureCloseWatcher).
    if BlizzRepFrameShown() then
        _pendingAfterClose = true
        EnsureCloseWatcher()
        return
    end

    local vlAPI = _G.ViewerLogAPI
    if not vlAPI or not vlAPI.GetCurrentCharData then return end
    local charData = vlAPI.GetCurrentCharData()
    if not charData then return end

    _ExpandAllFactionHeaders()

    local numFac = _GetNumFactions()
    local now    = time()

    charData.reputations = charData.reputations or {}
    local reps = charData.reputations

    local nextIndex = 1
    local expGroup, expOrder = nil, 0

    _scanToken = _scanToken + 1
    local myToken = _scanToken

    if not _scanFrame then
        _scanFrame = CreateFrame("Frame")
    end

    _scanFrame:SetScript("OnUpdate", function(self)
        -- Un scan plus récent a démarré → celui-ci est obsolète, on l'abandonne
        -- (les factions déjà traitées restent écrites, revérifiées ensuite).
        if myToken ~= _scanToken then
            self:SetScript("OnUpdate", nil)
            return
        end

        -- Petits lots jusqu'au dépassement du budget de temps. Pas de
        -- debugprofilestart() (timer global partagé) : on prend juste la
        -- différence de deux debugprofilestop().
        local startTime = debugprofilestop()
        repeat
            local toIndex = math_min(nextIndex + TICK_BATCH - 1, numFac)
            nextIndex, expGroup, expOrder =
                ScanFactionRange(reps, nextIndex, toIndex, numFac, expGroup, expOrder, now)
        until nextIndex > numFac or (debugprofilestop() - startTime) >= TICK_BUDGET_MS

        if nextIndex > numFac then
            self:SetScript("OnUpdate", nil)
            _CollapseAllFactionHeaders()
        end
    end)
end

-- ── API publique ──────────────────────────────────────────────────

-- Scan des réputations. debounce = true → délai 2 s puis scan étalé
-- (UPDATE_FACTION, login), sinon scan synchrone immédiat (logout, manuel).
function ns.ScanReputations(debounce)
    if debounce then
        if _repTimer then _repTimer:Cancel() end
        _repTimer = C_Timer.NewTimer(2.0, function()
            _repTimer = nil
            ExecuteReputationScanChunked()
        end)
    else
        -- Annule le debounce et un scan étalé en cours (token invalidé).
        if _repTimer then _repTimer:Cancel(); _repTimer = nil end
        _scanToken = _scanToken + 1
        if _scanFrame then _scanFrame:SetScript("OnUpdate", nil) end
        ExecuteReputationScanSync()
    end
end
