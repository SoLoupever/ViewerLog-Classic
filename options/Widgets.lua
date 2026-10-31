local addonName, ns = ...

-- Widgets UI de base, réutilisés par les autres modules ui/*.
-- Couleurs lues dans ns.UI.Colors (cf. Theme.lua), re-skin via BindTheme.

ns.UI = ns.UI or {}
local C = ns.UI.Colors

local FLAT = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}
local DEL_RED = { 0.55, 0.08, 0.08 }
local DEL_HOV = { 0.80, 0.15, 0.15 }
local CHECK_TEX = "Interface\\Buttons\\UI-CheckBox-Check"

-- ── Réglages (registre unique : ViewerLogDB.settings) ───────
function ns.UI.GetSetting(key)
    return (ViewerLogDB.settings or {})[key]
end

function ns.UI.SetSetting(key, val)
    ViewerLogDB.settings = ViewerLogDB.settings or {}
    ViewerLogDB.settings[key] = val
end

-- ── Registres de skin (clés faibles) ────────────────────────
local frames  = setmetatable({}, { __mode = "k" }) -- frame  -> kind
local tinted  = setmetatable({}, { __mode = "k" }) -- region -> { colorKey, alpha }
local buttons = setmetatable({}, { __mode = "k" })
local checks  = setmetatable({}, { __mode = "k" })

local KIND = {
    box     = { "box",  "boxBorder"     },
    inner   = { "inner", "innerBorder"  },
    card    = { "card", "cardBorder"    },
    preview = { "box",  "previewBorder" },
}

local function SkinFrame(f, kind)
    local k = KIND[kind]
    local bg, bd = C[k[1]], C[k[2]]
    if not bg then return end
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    f:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4] or 1)
end

local function ApplyTint(obj, key, alpha)
    local c = C[key]
    if not c then return end
    if obj.SetTextColor then
        obj:SetTextColor(c[1], c[2], c[3], 1)
    else
        obj:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
    end
end

local function SkinButton(b)
    local bg = b._hover and C.btnHoverBg or C.btnBg
    local bd = b._hover and C.btnHoverBorder or C.btnBorder
    if not bg then return end
    b:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    b:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
    local t = C.btnText
    b.label:SetTextColor(t[1], t[2], t[3], 1)
end

local function SkinCheck(cb)
    local bg, bd = C.checkBg, C.checkBorder
    if not bg then return end
    cb:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    cb:SetBackdropBorderColor(bd[1], bd[2], bd[3], cb._off and 0.35 or bd[4])
end

ns.UI.BindTheme(function()
    for f, kind in pairs(frames)  do SkinFrame(f, kind) end
    for o, t    in pairs(tinted)  do ApplyTint(o, t[1], t[2]) end
    for b in pairs(buttons)       do SkinButton(b) end
    for cb in pairs(checks)       do SkinCheck(cb) end
end)

-- Colore un FontString (texte) ou une Texture (aplat) avec une clé du thème.
function ns.UI.Tint(obj, key, alpha)
    tinted[obj] = { key, alpha }
    ApplyTint(obj, key, alpha)
end

-- ── Constructeurs ───────────────────────────────────────────
-- kind : "box" (défaut), "inner", "card", "preview".
function ns.UI.StyledFrame(parent, w, h, kind)
    kind = kind or "box"
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if w and h then f:SetSize(w, h) end
    f:SetBackdrop(FLAT)
    frames[f] = kind
    SkinFrame(f, kind)
    return f
end

function ns.UI.SectionTitle(parent, text, relTo, relPoint, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", relTo, relPoint, x or 0, y or 0)
    fs:SetText(text)
    ns.UI.Tint(fs, "accent")
    return fs
end

-- Ligne de séparation sur toute la largeur de `frame`.
function ns.UI.HSep(frame, offY, padX)
    padX = padX or 0
    local t = frame:CreateTexture(nil, "ARTWORK")
    t:SetHeight(1)
    t:SetPoint("TOPLEFT",  frame, "TOPLEFT",  padX,  offY)
    t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padX, offY)
    ns.UI.Tint(t, "accentDim", 0.80)
    return t
end

function ns.UI.Button(parent, w, h, text, font)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    b:SetBackdrop(FLAT)
    b.label = b:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    b.label:SetPoint("CENTER")
    b.label:SetText(text or "")
    b:HookScript("OnEnter", function(s) s._hover = true;  SkinButton(s) end)
    b:HookScript("OnLeave", function(s) s._hover = false; SkinButton(s) end)
    buttons[b] = true
    SkinButton(b)
    return b
end

function ns.UI.Checkbox(parent, label, tip, anchor, offX, offY, getter, setter)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offX, offY)
    cb:SetBackdrop(FLAT)

    local ck = cb:CreateTexture(nil, "ARTWORK")
    ck:SetTexture(CHECK_TEX)
    ck:SetPoint("TOPLEFT", -4, 4)
    ck:SetPoint("BOTTOMRIGHT", 4, -4)
    cb:SetCheckedTexture(ck)
    cb.check = ck

    cb:SetChecked(getter())
    local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    lbl:SetText(label)
    ns.UI.Tint(lbl, "text")
    cb.text = lbl

    if tip then
        cb:SetScript("OnEnter", function(s)
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:AddLine(tip, 1, 1, 0.7, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    cb:SetScript("OnClick", function(s) setter(s:GetChecked()) end)

    checks[cb] = true
    SkinCheck(cb)
    return cb
end

function ns.UI.SetCheckboxEnabled(cb, enabled)
    if enabled then cb:Enable() else cb:Disable() end
    cb._off = not enabled
    cb.check:SetDesaturated(not enabled)
    ns.UI.Tint(cb.text, enabled and "text" or "textDisabled")
    SkinCheck(cb)
end

function ns.UI.DeleteBtn(parent, onClickFn)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(76, 17)
    btn:SetBackdrop(FLAT)
    btn:SetBackdropColor(0.05, 0.05, 0.05, 1)
    btn:SetBackdropBorderColor(DEL_RED[1], DEL_RED[2], DEL_RED[3], 1)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("CENTER")
    lbl:SetText("|cffff4444" .. ns.L("DELETE_BTN") .. "|r")
    btn:SetScript("OnEnter", function(s)
        s:SetBackdropColor(0.15, 0.03, 0.03, 1)
        s:SetBackdropBorderColor(DEL_HOV[1], DEL_HOV[2], DEL_HOV[3], 1)
    end)
    btn:SetScript("OnLeave", function(s)
        s:SetBackdropColor(0.05, 0.05, 0.05, 1)
        s:SetBackdropBorderColor(DEL_RED[1], DEL_RED[2], DEL_RED[3], 1)
    end)
    btn:SetScript("OnClick", onClickFn)
    return btn
end

function ns.UI.MakeScrollBox(parent, ax, ay, aw, ah)
    local bg = ns.UI.StyledFrame(parent, aw, ah)
    bg:SetPoint("TOPLEFT", parent, "TOPLEFT", ax, ay)
    local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     bg, "TOPLEFT",     4,  -4)
    sf:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -22,  4)
    local child = CreateFrame("Frame", nil, sf)
    child:SetWidth(math.max(1, sf:GetWidth()))
    child:SetHeight(1)
    sf:SetScrollChild(child)
    ns.UI.SkinScrollBar(sf)

    -- La largeur du contenu suit celle de la ScrollFrame (panneau redimensionnable).
    sf:HookScript("OnSizeChanged", function()
        child:SetWidth(math.max(1, sf:GetWidth()))
    end)

    return bg, sf, child
end
