local addonName, ns = ...

-- Barre d'onglets + pages (construites à la première ouverture).
-- defs = { { id, labelKey, build = function(page) return { Refresh = fn } end } }

ns.UI = ns.UI or {}

local TAB_H, TAB_GAP = 30, 8
local FLAT = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

function ns.UI.BuildTabs(panel, content, defs)
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT",  panel, "TOPLEFT",  12, -52)
    bar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -52)
    bar:SetHeight(TAB_H)

    local tabs, pages, built = {}, {}, {}
    local current

    local function SkinTab(id)
        local tab, on = tabs[id], (id == current)
        local bg = on and ns.UI.Colors.tabActiveBg     or ns.UI.Colors.tabBg
        local bd = on and ns.UI.Colors.tabActiveBorder or ns.UI.Colors.tabBorder
        local tx = on and ns.UI.Colors.tabActiveText   or ns.UI.Colors.tabText
        if not bg then return end
        tab:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        tab:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
        tab.label:SetTextColor(tx[1], tx[2], tx[3], 1)
    end

    local function Layout(w)
        local n = #defs
        local tw = (w - TAB_GAP * (n - 1)) / n
        for i, d in ipairs(defs) do
            local tab = tabs[d.id]
            tab:SetWidth(tw)
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * (tw + TAB_GAP), 0)
        end
    end

    local api = {}

    function api.Select(id)
        if current == id then return end
        local prev = current
        current = id
        if prev then pages[prev]:Hide(); SkinTab(prev) end
        if not built[id] then
            built[id] = pages[id].def.build(pages[id]) or {}
        end
        pages[id]:Show()
        SkinTab(id)
        if built[id].Refresh then built[id].Refresh() end
    end

    function api.Refresh()
        local b = current and built[current]
        if b and b.Refresh then b.Refresh() end
    end

    function api.Current() return current end

    for _, d in ipairs(defs) do
        local tab = CreateFrame("Button", nil, bar, "BackdropTemplate")
        tab:SetHeight(TAB_H)
        tab:SetBackdrop(FLAT)
        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tab.label:SetPoint("CENTER")
        tab.label:SetText(ns.L(d.labelKey))
        local id = d.id
        tab:SetScript("OnClick", function() api.Select(id) end)
        tabs[id] = tab

        local page = CreateFrame("Frame", nil, content)
        page:SetAllPoints(content)
        page:Hide()
        page.def = d
        pages[id] = page
    end

    bar:SetScript("OnSizeChanged", function(_, w) Layout(w) end)
    Layout(bar:GetWidth() or 0)

    ns.UI.BindTheme(function()
        for _, d in ipairs(defs) do SkinTab(d.id) end
    end)

    return api
end
