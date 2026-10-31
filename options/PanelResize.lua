local addonName, ns = ...

-- Poignée de redimensionnement du panneau de paramètres (bas-droite).
-- Taille calculée à la main depuis le delta curseur (pas de StartSizing) :
-- bornes appliquées à chaque frame de drag, OnUpdate actif seulement
-- pendant le geste. Taille persistée dans ViewerLogDB.settings.

ns.UI = ns.UI or {}

function ns.UI.MakeResizeGrip(panel, minW, minH, maxW, maxH, onResizeStop)
    local grip = CreateFrame("Frame", nil, panel)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)
    grip:SetFrameLevel(panel:GetFrameLevel() + 50)
    grip:EnableMouse(true)

    local tex = grip:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    local hl = grip:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

    local startX, startY, startW, startH

    local function OnUpdate()
        local cx, cy = GetCursorPosition()
        local s = panel:GetEffectiveScale()
        local w = startW + (cx - startX) / s
        local h = startH + (startY - cy) / s
        panel:SetSize(math.max(minW, math.min(maxW, w)),
                      math.max(minH, math.min(maxH, h)))
    end

    local function Stop()
        grip:SetScript("OnUpdate", nil)
        ViewerLogDB.settings = ViewerLogDB.settings or {}
        ViewerLogDB.settings.panelWidth  = panel:GetWidth()
        ViewerLogDB.settings.panelHeight = panel:GetHeight()
        if onResizeStop then onResizeStop() end
    end

    grip:SetScript("OnMouseDown", function(_, btn)
        if btn ~= "LeftButton" then return end
        -- Ancrage TOPLEFT : le panneau grandit vers le bas-droite.
        local x, y = panel:GetLeft(), panel:GetTop()
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)

        startX, startY = GetCursorPosition()
        startW, startH = panel:GetWidth(), panel:GetHeight()
        grip:SetScript("OnUpdate", OnUpdate)
    end)
    grip:SetScript("OnMouseUp", function(_, btn)
        if btn ~= "LeftButton" then return end
        Stop()
    end)
    grip:SetScript("OnHide", function(s)
        if s:GetScript("OnUpdate") then Stop() end
    end)

    panel.resizeGrip = grip
    return grip
end
