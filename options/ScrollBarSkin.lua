local addonName, ns = ...

-- Scrollbar "moderne" : remplace le rendu Blizzard par défaut (flèches +
-- slider gris épais) par une piste fine + un pouce bleu clair. Un seul
-- skin pour toute ScrollFrame du panneau (persos + guildes).
-- Purement visuel : le scroll reste géré nativement par la ScrollFrame
-- (SetVerticalScroll / GetVerticalScrollRange), rien n'est réimplémenté
-- côté logique. 

local BAR_W = 8
local THUMB_COLOR = { 0.45, 0.75, 1.00 } -- bleu clair ViewerLog

ns.UI = ns.UI or {}

function ns.UI.SkinScrollBar(scrollFrame)
    -- Masque la scrollbar Blizzard native fournie par le template
    -- (la ScrollFrame garde toute sa logique de scroll, seul son
    -- widget visuel enfant est caché).
    local nativeBar = scrollFrame.ScrollBar
        or (scrollFrame:GetName() and _G[scrollFrame:GetName() .. "ScrollBar"])
    if nativeBar then
        nativeBar:Hide()
        nativeBar:EnableMouse(false)
        nativeBar.Show = function() end
    end

    local track = CreateFrame("Frame", nil, scrollFrame)
    track:SetWidth(BAR_W)
    track:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", BAR_W - 2, -2)
    track:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", BAR_W - 2, 2)
    local trackTex = track:CreateTexture(nil, "BACKGROUND")
    trackTex:SetAllPoints()
    trackTex:SetColorTexture(0, 0, 0, 0.25)

    local thumb = CreateFrame("Button", nil, track)
    thumb:SetWidth(BAR_W)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints()
    if thumbTex.SetMask then
        pcall(thumbTex.SetMask, thumbTex, "Interface\\Masks\\CircleMaskScalable")
    end

    local function ThumbColor(alpha)
        thumbTex:SetColorTexture(THUMB_COLOR[1], THUMB_COLOR[2], THUMB_COLOR[3], alpha)
    end
    ThumbColor(0.55)

    -- Recalcule taille/position du pouce à partir de l'état natif de
    -- la ScrollFrame (aucune donnée dupliquée, juste relue).
    local function Update()
        local range  = scrollFrame:GetVerticalScrollRange() or 0
        local trackH = track:GetHeight() or 1

        if range <= 0 then
            track:Hide()
            return
        end
        track:Show()

        local visH   = scrollFrame:GetHeight() or 1
        local thumbH = math.max(24, trackH * (visH / (visH + range)))
        thumb:SetHeight(thumbH)

        local scroll    = scrollFrame:GetVerticalScroll() or 0
        local maxOffset = math.max(0, trackH - thumbH)
        local pos       = (range > 0) and (scroll / range) * maxOffset or 0
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -pos)
    end

    -- Hooks natifs : pas de OnUpdate en boucle, seulement recalcul
    -- quand quelque chose a réellement changé (taille, contenu, scroll).
    scrollFrame:HookScript("OnScrollRangeChanged", Update)
    scrollFrame:HookScript("OnVerticalScroll", Update)
    scrollFrame:HookScript("OnSizeChanged", Update)

    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        if range <= 0 then return end
        local cur = self:GetVerticalScroll() or 0
        local step = 45
        self:SetVerticalScroll(math.min(range, math.max(0, cur - delta * step)))
    end)

    -- Survol : piste/pouce plus visibles (effet "overlay scrollbar")
    local function OnEnterArea()
        if thumb.dragging then return end
        ThumbColor(0.8)
        trackTex:SetColorTexture(0, 0, 0, 0.35)
    end
    local function OnLeaveArea()
        if thumb.dragging then return end
        ThumbColor(0.55)
        trackTex:SetColorTexture(0, 0, 0, 0.25)
    end
    scrollFrame:HookScript("OnEnter", OnEnterArea)
    scrollFrame:HookScript("OnLeave", OnLeaveArea)
    thumb:SetScript("OnEnter", OnEnterArea)
    thumb:SetScript("OnLeave", OnLeaveArea)

    -- Drag du pouce
    thumb:RegisterForDrag("LeftButton")
    thumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        ThumbColor(0.95)
    end)
    thumb:SetScript("OnDragStop", function(self)
        self.dragging = false
        OnLeaveArea()
    end)
    thumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local range = scrollFrame:GetVerticalScrollRange() or 0
        if range <= 0 then return end
        local trackH = track:GetHeight() or 1
        local thumbH = self:GetHeight() or 1
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end

        local scale = track:GetEffectiveScale()
        local _, cursorY = GetCursorPosition()
        cursorY = cursorY / scale

        local offset = (track:GetTop() or 0) - cursorY - (thumbH / 2)
        offset = math.max(0, math.min(maxOffset, offset))
        scrollFrame:SetVerticalScroll((offset / maxOffset) * range)
    end)

    Update()
end
