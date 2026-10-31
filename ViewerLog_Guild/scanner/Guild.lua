local addonName, ns = ...

-- Scanner coffre de guilde.
-- ViewerLogDB.guilds[guildKey] = {
--     guildName, realm, scannedBy, scanTime, guildLeader,
--     money   = N,
--     details = { visited = bool },
--     tabs    = { [i] = { name, icon, isViewable,
--                         items = { [slot] = { id, count, link, quality, icon } } } },
-- }

local NUM_GUILD_BANK_SLOTS = 98

-- Exposée par le core sur _G.ViewerLogAPI (no-op si le core n'est pas chargé).
local function InvalidateGuildIndex()
    local api = _G.ViewerLogAPI
    if api and api.InvalidateIndex then
        api.InvalidateIndex({ guild = true })
    end
end

local scanFrame  = CreateFrame("Frame", "ViewerLog_GuildScanFrame")
local bankIsOpen = false

-- ── Chargement asynchrone des données item ────────────────────────
-- Une requête réseau par itemID (callbacks groupés), relancée toutes les
-- 0,4 s tant que la réponse tarde. Auto-désactivé quand la file est vide.

local _pendingItems = {}
local _loaderFrame  = CreateFrame("Frame")
_loaderFrame.elapsed = 0

_loaderFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
_loaderFrame:SetScript("OnEvent", function(_, _, itemID)
    local cbs = _pendingItems[itemID]
    if cbs then
        _pendingItems[itemID] = nil
        for _, cb in ipairs(cbs) do cb() end
    end
end)

_loaderFrame.OnUpdate = function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.4 then
        self.elapsed = 0
        for itemID in pairs(_pendingItems) do
            C_Item.RequestLoadItemDataByID(itemID)
        end
    end
    if not next(_pendingItems) then
        self.elapsed = 0
        self:SetScript("OnUpdate", nil)
    end
end

local function LoadItemData(itemID, callback)
    if C_Item.IsItemDataCachedByID(itemID) then
        callback()
        return
    end
    if not _pendingItems[itemID] then
        _pendingItems[itemID] = {}
        C_Item.RequestLoadItemDataByID(itemID)
        _loaderFrame:SetScript("OnUpdate", _loaderFrame.OnUpdate)
    end
    table.insert(_pendingItems[itemID], callback)
end

-- ── Helpers ───────────────────────────────────────────────────────

local function EnsureGuildsDB()
    ViewerLogDB.guilds = ViewerLogDB.guilds or {}
    return ViewerLogDB.guilds
end

-- Supprime les autres entrées de la même guilde (nom unique par royaume).
local function PurgeStaleDuplicates(db, keepKey, guildName)
    for k, e in pairs(db) do
        if k ~= keepKey and type(e) == "table"
           and e.guildName ~= nil and e.guildName == guildName then
            db[k] = nil
        end
    end
end

-- Clé stable = nom + royaume DE LA GUILDE (4e retour de GetGuildInfo, identique
-- pour tous les membres même sur royaumes connectés ; repli normalisé si nil).
local function GetGuildKey()
    local guildName, _, _, realm = GetGuildInfo("player")
    if not guildName then return nil, nil, nil end
    realm = realm or GetNormalizedRealmName()
    return guildName .. "-" .. realm, guildName, realm
end

-- Chef de guilde, résolu une fois à l'ouverture du coffre.
local function GetGuildLeader()
    C_GuildInfo.GuildRoster()
    for i = 1, GetNumGuildMembers() do
        local name, _, rank = GetGuildRosterInfo(i)
        if rank == 0 and name then
            return name:match("^([^%-]+)") or name
        end
    end
    return nil
end

-- ── Session de scan ───────────────────────────────────────────────
-- Buffer en mémoire ; CommitSession() écrit en base quand tous les
-- callbacks async de la génération courante sont résolus. _scanGen
-- invalide les callbacks d'un scan supplanté (fermeture mid-scan).

local sessionBuffer = nil
local _scanGen      = 0

local CommitSession
CommitSession = function()
    if not sessionBuffer then return end
    local guildKey = sessionBuffer.guildKey
    if not guildKey then sessionBuffer = nil; return end

    local tabCount = 0
    for _ in pairs(sessionBuffer.tabs) do tabCount = tabCount + 1 end
    if tabCount == 0 then sessionBuffer = nil; return end

    local db = EnsureGuildsDB()
    db[guildKey] = {
        guildName   = sessionBuffer.guildName,
        realm       = sessionBuffer.realm,
        scannedBy   = UnitName("player"),
        scanTime    = time(),
        guildLeader = sessionBuffer.leader,
        money       = sessionBuffer.money or 0,
        details     = { visited = true },
        tabs        = sessionBuffer.tabs,
    }

    PurgeStaleDuplicates(db, guildKey, sessionBuffer.guildName)
    sessionBuffer = nil
    InvalidateGuildIndex()
end

-- Scanne un onglet ; onDone() quand tous ses slots sont résolus.
local function SnapshotTab(tabIndex, myGen, onDone)
    if not sessionBuffer or myGen ~= _scanGen then
        onDone()
        return
    end

    local tabName, tabIcon, isViewable = GetGuildBankTabInfo(tabIndex)

    local tab = {
        name       = tabName or (ns.L("GUILD_TAB_FALLBACK") .. tabIndex),
        icon       = tabIcon or "",
        isViewable = isViewable == true,
        items      = {},
    }
    sessionBuffer.tabs[tabIndex] = tab

    -- Onglet non accessible : enregistré pour conserver isViewable = false.
    if not isViewable then onDone(); return end

    local waiting  = 0
    local loopDone = false

    local function CheckDone()
        if loopDone and waiting == 0 then
            onDone()
        end
    end

    for slot = 1, NUM_GUILD_BANK_SLOTS do
        local link = GetGuildBankItemLink(tabIndex, slot)
        if link then
            local itemID = C_Item.GetItemInfoInstant(link)
            if itemID then
                local function DoSlot()
                    local texture, count, _, _, quality =
                        GetGuildBankItemInfo(tabIndex, slot)
                    tab.items[slot] = {
                        id      = itemID,
                        count   = count or 1,
                        link    = link,
                        quality = quality,
                        icon    = texture,
                    }
                end

                if C_Item.IsItemDataCachedByID(itemID) then
                    DoSlot()
                else
                    waiting = waiting + 1
                    LoadItemData(itemID, function()
                        if myGen == _scanGen and sessionBuffer then
                            DoSlot()
                        end
                        waiting = waiting - 1
                        CheckDone()
                    end)
                end
            end
        end
    end

    loopDone = true
    CheckDone()
end

-- Scanne tous les onglets accessibles. onDone = CommitSession pour committer
-- (fermeture / scan forcé) ; sans onDone, tient le buffer à jour sans écrire.
local function SnapshotAllAccessible(onDone)
    if not sessionBuffer then
        if onDone then onDone() end
        return
    end

    _scanGen = _scanGen + 1
    local myGen = _scanGen

    sessionBuffer.tabs  = {}
    sessionBuffer.money = GetGuildBankMoney() or 0

    local numTabs = GetNumGuildBankTabs() or 0
    if numTabs == 0 then
        if onDone then onDone() end
        return
    end

    local remaining = numTabs

    local function OnTabDone()
        if myGen ~= _scanGen then return end
        remaining = remaining - 1
        if remaining == 0 and onDone then
            onDone()
        end
    end

    for i = 1, numTabs do
        SnapshotTab(i, myGen, OnTabDone)
    end
end

-- ── Événements du coffre ──────────────────────────────────────────

function ns.OnGuildBankOpened()
    if not IsInGuild() then return end
    bankIsOpen = true

    local guildKey, guildName, realm = GetGuildKey()
    if not guildKey then return end

    sessionBuffer = {
        guildKey  = guildKey,
        guildName = guildName,
        realm     = realm,
        leader    = GetGuildLeader(),
        money     = GetGuildBankMoney() or 0,
        tabs      = {},
    }

    -- Requête des onglets accessibles ; GUILDBANKBAGSLOTS_CHANGED suivra.
    local numTabs    = GetNumGuildBankTabs() or 0
    local currentTab = GetCurrentGuildBankTab() or 1
    for i = 1, numTabs do
        local _, _, isViewable = GetGuildBankTabInfo(i)
        if isViewable and i ~= currentTab then QueryGuildBankTab(i) end
    end
    local _, _, curViewable = GetGuildBankTabInfo(currentTab)
    if curViewable then QueryGuildBankTab(currentTab) end
end

function ns.OnGuildBankClosed()
    bankIsOpen = false
    if sessionBuffer then
        SnapshotAllAccessible(CommitSession)
    end
end

-- Slots changés : snapshot différé d'un frame, sans commit (coffre ouvert).
local function OnNextFrame(self)
    self:SetScript("OnUpdate", nil)
    if bankIsOpen and sessionBuffer then
        SnapshotAllAccessible()
    end
end

function ns.OnGuildBankSlotsChanged()
    if bankIsOpen and sessionBuffer then
        scanFrame:SetScript("OnUpdate", OnNextFrame)
    end
end

-- Onglets modifiés : mise à jour légère des métadonnées, sans rescan des slots.
function ns.OnGuildBankTabsChanged()
    if not bankIsOpen then return end
    local guildKey = GetGuildKey()
    if not guildKey then return end
    local entry = EnsureGuildsDB()[guildKey]
    if not entry then return end

    local numTabs = GetNumGuildBankTabs() or 0
    for i = 1, numTabs do
        local tabName, tabIcon, isViewable = GetGuildBankTabInfo(i)
        if entry.tabs[i] then
            entry.tabs[i].name       = tabName or (ns.L("GUILD_TAB_FALLBACK") .. i)
            entry.tabs[i].icon       = tabIcon or ""
            entry.tabs[i].isViewable = isViewable == true
        end
    end
end

-- Mouvement d'or : mise à jour O(1) du champ money.
function ns.OnGuildBankMoneyChanged()
    if not bankIsOpen then return end
    local guildKey = GetGuildKey()
    if not guildKey then return end
    local db = EnsureGuildsDB()
    if db[guildKey] then
        db[guildKey].money = GetGuildBankMoney() or 0
    end
    if sessionBuffer and sessionBuffer.guildKey == guildKey then
        sessionBuffer.money = GetGuildBankMoney() or 0
    end
end

-- ── API publique ──────────────────────────────────────────────────

-- Scan complet + commit immédiat, puis recrée un buffer pour la suite.
function ns.ScanGuildBank()
    if not bankIsOpen or not sessionBuffer then return end

    local savedKey    = sessionBuffer.guildKey
    local savedName   = sessionBuffer.guildName
    local savedRealm  = sessionBuffer.realm
    local savedLeader = sessionBuffer.leader

    SnapshotAllAccessible(function()
        CommitSession()
        if bankIsOpen then
            sessionBuffer = {
                guildKey  = savedKey,
                guildName = savedName,
                realm     = savedRealm,
                leader    = savedLeader,
                money     = GetGuildBankMoney() or 0,
                tabs      = {},
            }
        end
    end)
end

function ns.DeleteGuild(guildKey)
    if ViewerLogDB.guilds and ViewerLogDB.guilds[guildKey] then
        ViewerLogDB.guilds[guildKey] = nil
        InvalidateGuildIndex()
        return true
    end
    return false
end

-- ── Migration unique : fusionne les doublons hérités (par nom, plus récent). ──
local GUILDS_DEDUP_VERSION = 1

function ns.MigrateGuildDuplicates()
    if not ViewerLogDB then return end
    if (ViewerLogDB.guildsDedupVersion or 0) >= GUILDS_DEDUP_VERSION then
        return
    end

    local db         = EnsureGuildsDB()
    local bestKeyFor = {}
    local toRemove   = {}

    for k, e in pairs(db) do
        if type(e) == "table" and e.guildName then
            local identity = "name:" .. e.guildName
            local kept = bestKeyFor[identity]
            if not kept then
                bestKeyFor[identity] = k
            else
                local keptTime = (db[kept] and db[kept].scanTime) or 0
                if (e.scanTime or 0) > keptTime then
                    toRemove[#toRemove + 1] = kept
                    bestKeyFor[identity]    = k
                else
                    toRemove[#toRemove + 1] = k
                end
            end
        end
    end

    if #toRemove > 0 then
        for _, k in ipairs(toRemove) do db[k] = nil end
        InvalidateGuildIndex()
    end

    ViewerLogDB.guildsDedupVersion = GUILDS_DEDUP_VERSION
end

local _migFrame = CreateFrame("Frame")
_migFrame:RegisterEvent("PLAYER_LOGIN")
_migFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.MigrateGuildDuplicates()
end)
