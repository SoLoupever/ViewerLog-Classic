local addonName, ns = ...

-- Scanner courrier (boîte aux lettres).
-- Le contenu du courrier n'est lisible que boîte ouverte : core/Events.lua
-- tient l'état _mailOpen et n'appelle ScanMail que dans ce cas. On réécrit
-- alors charData.mail EN ENTIER (même vide) pour refléter les retraits — un
-- courrier vidé ne laisse donc pas de résidu dans l'index.
-- Debounce queue + OnUpdate comme les autres scanners (MAIL_INBOX_UPDATE
-- arrive en rafale). Format : charData.mail = { { id, count }, ... }.

local ATTACH_MAX = _G.ATTACHMENTS_MAX_RECEIVE or 16

local _scanFrame  = nil   -- frame OnUpdate (créée une fois)
local _scanQueued = false

local function ExecuteMailScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    -- Réécriture complète, indexée à plat (le courrier n'a pas de slots stables).
    local mail = {}
    local numItems = GetInboxNumItems() or 0
    for index = 1, numItems do
        -- itemCount = pièces jointes du message ; 0 = argent seul → on saute.
        local itemCount = select(8, GetInboxHeaderInfo(index))
        if itemCount and itemCount > 0 then
            for attach = 1, ATTACH_MAX do
                local _, itemID, _, count = GetInboxItem(index, attach)
                if itemID then
                    mail[#mail + 1] = { id = itemID, count = count or 1 }
                end
            end
        end
    end

    charData.mail = (#mail > 0) and mail or nil

    ns.InvalidateIndex({ chars = true })

    -- Rafraîchit la tooltip visible (cf. ScanBags).
    if GameTooltip:IsShown() then
        local _, link = GameTooltip:GetItem()
        if link then
            GameTooltip:SetHyperlink(link)
        end
    end
end

local function QueueMailScan()
    if not _scanQueued then
        _scanQueued = true
        _scanFrame:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            ExecuteMailScan()
        end)
    end
end

-- Crée la frame OnUpdate une seule fois (après PLAYER_LOGIN). Idempotente.
function ns.InitMailScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_MailScanFrame")
end

-- Appelé par Events.lua uniquement quand la boîte aux lettres est ouverte.
function ns.ScanMail()
    if not _scanFrame then return end
    QueueMailScan()
end
