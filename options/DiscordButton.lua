local addonName, ns = ...

-- Bouton Discord + fenêtre de copie du lien.
-- Pas d'API WoW pour ouvrir un lien : EditBox copiable (Ctrl+A / Ctrl+C).

ns.UI = ns.UI or {}

local DISCORD_URL = "https://discord.gg/2gfEKGAT46"

local dlg

local function EnsureDialog()
    if dlg then return dlg end
    local C = ns.UI.Colors

    dlg = CreateFrame("Frame", "VL_DiscordDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(360, 112)
    dlg:SetPoint("CENTER")
    dlg:SetFrameStrata("DIALOG")
    dlg:SetToplevel(true)
    dlg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    dlg:SetBackdropColor(0.05, 0.05, 0.07, 0.98)
    dlg:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", dlg.StartMoving)
    dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
    tinsert(UISpecialFrames, "VL_DiscordDialog")

    dlg.title = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dlg.title:SetPoint("TOP", 0, -14)
    dlg.title:SetText(ns.L("DISCORD_BTN_LABEL"))

    local close = CreateFrame("Button", nil, dlg, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    dlg.hintFS = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dlg.hintFS:SetPoint("TOP", 0, -38)
    dlg.hintFS:SetText(ns.L("DISCORD_HINT"))

    local box = ns.UI.StyledFrame(dlg, nil, nil, "box")
    box:SetPoint("TOPLEFT", 16, -58)
    box:SetPoint("TOPRIGHT", -16, -58)
    box:SetHeight(22)

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 6, 0)
    edit:SetPoint("BOTTOMRIGHT", -6, 0)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    dlg.edit = edit

    return dlg
end

local function OpenDiscordDialog()
    EnsureDialog()
    dlg.edit:SetText(DISCORD_URL)
    dlg:Show()
    dlg:Raise()
    dlg.edit:SetFocus()
    dlg.edit:HighlightText()
end

-- Ancré par (point, relTo, relPoint, x, y).
function ns.UI.BuildDiscordButton(parent, point, relTo, relPoint, x, y, width, height)
    local btn = ns.UI.Button(parent, width, height, ns.L("DISCORD_BTN_LABEL"))
    btn:SetPoint(point, relTo, relPoint, x, y)

    btn:HookScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.L("DISCORD_BTN_TIP"), 1, 1, 0.7, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", OpenDiscordDialog)

    return btn
end
