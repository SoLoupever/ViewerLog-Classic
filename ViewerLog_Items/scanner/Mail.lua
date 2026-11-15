local addonName, ns = ...

-- Scanner courrier. Lisible boîte ouverte uniquement (Init.lua tient _mailOpen).
-- charData.mail réécrit en entier (même vide) pour refléter les retraits.
-- Format : charData.mail = { { id, count }, ... }.

local ATTACH_MAX = _G.ATTACHMENTS_MAX_RECEIVE or 16

local _scanFrame  = nil
local _scanQueued = false

local function ExecuteMailScan()
    _scanQueued = false
    _scanFrame:SetScript("OnUpdate", nil)

    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local mail = {}
    for index = 1, GetInboxNumItems() or 0 do
        -- 8e retour = nb de pièces jointes ; 0 = argent seul.
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
    ns.RefreshTooltip()
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

-- Idempotent.
function ns.InitMailScanner()
    if _scanFrame then return end
    _scanFrame = CreateFrame("Frame", "ViewerLog_MailScanFrame")
end

-- Appelé par Init.lua uniquement boîte ouverte.
function ns.ScanMail()
    if not _scanFrame then return end
    QueueMailScan()
end
