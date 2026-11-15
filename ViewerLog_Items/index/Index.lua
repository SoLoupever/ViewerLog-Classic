local addonName, ns = ...

-- Index infobulle (lazy rebuild).
-- Les scanners invalident des sources ; le rebuild n'a lieu qu'à la demande
-- de l'infobulle (GetTooltipEntry). O(1) par scan.
-- Sources propres : chars (sacs, banque, courrier, enchères), guild
-- (via vl.GetAllGuilds). Autres modules : ns.RegisterIndexSource(name, rebuild).
--
-- ns.tooltipIndex[itemID] = {
--   chars      = { ["Nom@Realm"] = { char, realm, class, faction, bagCount, bankCount, mailCount, auctionCount } },
--   guildCount = N,
--   guilds     = { [guildName] = N },
--   sources    = { [name] = { total = N, labels = { [label] = N } } },
-- }

ns.tooltipIndex = {}

-- Sale au chargement : le premier accès construit l'index.
local pending    = { chars = true, guild = true }
local anyPending = true
local builders   = {}

-- Invalide une ou plusieurs sources ({ chars = true, ... }).
function ns.InvalidateIndex(sources)
    for name in pairs(sources) do
        if pending[name] ~= nil then
            pending[name] = true
            anyPending = true
        end
    end
end

function ns.InvalidateIndexAll()
    for name in pairs(pending) do pending[name] = true end
    anyPending = true
end

-- ── Entrées ───────────────────────────────────────────────────────

local function GetEntry(idx, id)
    local entry = idx[id]
    if not entry then
        entry = { chars = {}, guildCount = 0 }
        idx[id] = entry
    end
    return entry
end

local function GetCharEntry(idx, id, key, charName, realmName, data)
    local entry = GetEntry(idx, id)
    local ce = entry.chars[key]
    if not ce then
        ce = {
            char         = charName,
            realm        = realmName,
            class        = data.class,
            faction      = data.faction,
            bagCount     = 0,
            bankCount    = 0,
            mailCount    = 0,
            auctionCount = 0,
        }
        entry.chars[key] = ce
    end
    return ce
end

-- Conteneur (sacs ou banque) d'un perso.
local function IndexContainer(idx, slots, field, key, charName, realmName, data)
    if not slots then return end
    for _, slotData in pairs(slots) do
        if type(slotData) == "table" then
            for _, item in pairs(slotData) do
                local id    = type(item) == "table" and item.id    or item
                local count = type(item) == "table" and item.count or 1
                if id then
                    local ce = GetCharEntry(idx, id, key, charName, realmName, data)
                    ce[field] = ce[field] + count
                end
            end
        end
    end
end

-- Courrier : liste plate { { id, count }, ... }.
local function IndexMail(idx, mail, key, charName, realmName, data)
    if not mail then return end
    for _, item in ipairs(mail) do
        local id = item.id
        if id then
            local ce = GetCharEntry(idx, id, key, charName, realmName, data)
            ce.mailCount = ce.mailCount + (item.count or 1)
        end
    end
end

-- Enchères : { [itemID] = quantité }.
local function IndexAuctions(idx, auctions, key, charName, realmName, data)
    if not auctions then return end
    for id, count in pairs(auctions) do
        local ce = GetCharEntry(idx, id, key, charName, realmName, data)
        ce.auctionCount = ce.auctionCount + count
    end
end

-- ── Rebuilds partiels ─────────────────────────────────────────────

local function RebuildChars(idx)
    -- Efface sans remplacer les tables (moins de GC).
    for _, entry in pairs(idx) do
        wipe(entry.chars)
    end

    ns.vl.ForEachCharacter(function(charName, realmName, data)
        local key = charName .. "@" .. realmName
        IndexContainer(idx, data.bags, "bagCount",  key, charName, realmName, data)
        IndexContainer(idx, data.bank, "bankCount", key, charName, realmName, data)
        IndexMail(idx, data.mail, key, charName, realmName, data)
        IndexAuctions(idx, data.auctions, key, charName, realmName, data)
    end)
end

local function RebuildGuild(idx)
    for _, entry in pairs(idx) do
        entry.guildCount = 0
        if entry.guilds then wipe(entry.guilds) end
    end

    local guilds = ns.vl.GetAllGuilds and ns.vl.GetAllGuilds()
    if not guilds then return end

    for _, gData in pairs(guilds) do
        if type(gData) == "table" and gData.tabs then
            local gName = gData.guildName or "?"
            for _, tab in pairs(gData.tabs) do
                if tab and tab.items then
                    for _, item in pairs(tab.items) do
                        if item and item.id then
                            local entry = GetEntry(idx, item.id)
                            local count = item.count or 1
                            entry.guildCount = entry.guildCount + count
                            entry.guilds = entry.guilds or {}
                            entry.guilds[gName] = (entry.guilds[gName] or 0) + count
                        end
                    end
                end
            end
        end
    end
end

builders.chars = RebuildChars
builders.guild = RebuildGuild

-- ── Sources externes ──────────────────────────────────────────────

-- rebuild(add) : add(itemID, count, label) pour chaque objet possédé.
-- Un échec de la source n'affecte pas l'index des autres.
function ns.RegisterIndexSource(name, rebuild)
    if type(name) ~= "string" or type(rebuild) ~= "function" then return false end
    builders[name] = function(idx)
        for _, entry in pairs(idx) do
            local s = entry.sources and entry.sources[name]
            if s then
                s.total = 0
                if s.labels then wipe(s.labels) end
            end
        end
        local ok, err = pcall(rebuild, function(id, count, label)
            local entry = GetEntry(idx, id)
            local sources = entry.sources
            if not sources then
                sources = {}
                entry.sources = sources
            end
            local s = sources[name]
            if not s then
                s = { total = 0 }
                sources[name] = s
            end
            s.total = s.total + count
            if label then
                s.labels = s.labels or {}
                s.labels[label] = (s.labels[label] or 0) + count
            end
        end)
        if not ok then geterrorhandler()(err) end
    end
    pending[name] = true
    anyPending = true
    return true
end

-- ── Nettoyage ─────────────────────────────────────────────────────
-- Retire les entrées vides (borne la taille de l'index).
local function IsEmpty(entry)
    if next(entry.chars) ~= nil or entry.guildCount > 0 then return false end
    if entry.sources then
        for _, s in pairs(entry.sources) do
            if s.total > 0 then return false end
        end
    end
    return true
end

local function PruneEmptyEntries(idx)
    for id, entry in pairs(idx) do
        if IsEmpty(entry) then idx[id] = nil end
    end
end

local function ApplyPending()
    local idx = ns.tooltipIndex
    anyPending = false
    for name, flag in pairs(pending) do
        if flag then
            pending[name] = false
            builders[name](idx)
        end
    end
    PruneEmptyEntries(idx)
end

-- Rebuild complet.
function ns.BuildTooltipIndex()
    local idx = ns.tooltipIndex
    for k in pairs(idx) do idx[k] = nil end
    ns.InvalidateIndexAll()
    ApplyPending()
end

-- Accès lazy (ViewerLog_Tooltip). Coût nul si rien n'a changé.
function ns.GetTooltipEntry(itemID)
    if anyPending then ApplyPending() end
    return ns.tooltipIndex[itemID]
end
