local addonName, ns = ...

-- Onglet Thème : une ligne par thème enregistré (cf. Theme.lua).
-- Choix stocké dans ViewerLogDB.settings.theme.

ns.UI = ns.UI or {}

local ROW_H, ROW_GAP = 46, 8

function ns.UI.BuildThemePage(page)
    local sec = ns.UI.SectionTitle(page, ns.L("SECTION_THEME"), page, "TOPLEFT", 16, -16)

    local rows = {}
    local prev, prevPoint = sec, "BOTTOMLEFT"

    for _, t in ipairs(ns.UI.GetThemes()) do
        local id, def = t.id, t.def

        local row = CreateFrame("Button", nil, page, "BackdropTemplate")
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT",  prev, prevPoint, (prev == sec) and -6 or 0, (prev == sec) and -12 or -ROW_GAP)
        row:SetPoint("RIGHT", page, "RIGHT", -10, 0)
        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        name:SetPoint("LEFT", 16, 0)
        name:SetText(ns.L(def.labelKey))
        ns.UI.Tint(name, "text")

        -- Pastilles : fond, bordure, accent du thème représenté.
        local keys = { "bg", "border", "accent" }
        for i, k in ipairs(keys) do
            local sw = row:CreateTexture(nil, "ARTWORK")
            sw:SetSize(22, 22)
            sw:SetPoint("RIGHT", row, "RIGHT", -16 - (#keys - i) * 28, 0)
            local c = def.colors[k]
            sw:SetColorTexture(c[1], c[2], c[3], 1)
        end

        row:SetScript("OnClick", function()
            if ns.UI.GetThemeId() == id then return end
            ns.UI.SetSetting("theme", id)
            ns.UI.ApplyTheme(id)
        end)

        rows[id] = row
        prev, prevPoint = row, "BOTTOMLEFT"
    end

    -- Sélection = bordure d'accentuation, sinon bordure de boîte.
    local function SkinRows(C)
        local cur = ns.UI.GetThemeId()
        for id, row in pairs(rows) do
            local on = (id == cur)
            local bg = on and C.tabActiveBg or C.box
            local bd = on and C.tabActiveBorder or C.boxBorder
            row:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
            row:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
        end
    end
    ns.UI.BindTheme(SkinRows)

    return { Refresh = function() SkinRows(ns.UI.Colors) end }
end
