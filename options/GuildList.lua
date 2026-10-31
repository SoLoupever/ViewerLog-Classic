local addonName, ns = ...

-- Liste des guildes scannées (suppression individuelle).
-- Lignes réutilisées entre deux Populate (pas de recréation de frames).

ns.UI = ns.UI or {}

local ROW_H = 22

-- block : conteneur ; colX : décalage X de la colonne droite.
function ns.UI.BuildGuildList(block, colX)
    local sec = ns.UI.SectionTitle(block, ns.L("SECTION_GUILDS"), block, "TOPLEFT", colX + 16, -18)

    local guildBg, _, child = ns.UI.MakeScrollBox(block, 0, 0, nil, nil)
    guildBg:ClearAllPoints()
    guildBg:SetPoint("TOPLEFT",     sec,   "BOTTOMLEFT",  -6, -6)
    guildBg:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -10, 0)

    local pool = {}

    local empty = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    empty:SetPoint("TOPLEFT", 4, -4)
    ns.UI.Tint(empty, "textDisabled")
    empty:SetText(ns.L("NO_GUILD_SCANNED"))

    local function GetRow(i)
        local r = pool[i]
        if r then return r end

        r = CreateFrame("Frame", nil, child)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -(i - 1) * ROW_H)

        r.nm = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.nm:SetPoint("LEFT", 4, 0)

        r.del = ns.UI.DeleteBtn(r, function()
            StaticPopup_Show("VL_DEL_GUILD",
                r.guildName or r.key, nil, { key = r.key })
        end)
        r.del:SetPoint("RIGHT", -2, 0)

        r.sep = r:CreateTexture(nil, "BACKGROUND")
        r.sep:SetHeight(1)
        r.sep:SetPoint("BOTTOMLEFT",  r, "BOTTOMLEFT",  0, 0)
        r.sep:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
        ns.UI.Tint(r.sep, "rowSep")

        pool[i] = r
        return r
    end

    local function Populate()
        local rows = {}
        if ViewerLogDB.guilds then
            for key, gData in pairs(ViewerLogDB.guilds) do
                if type(gData) == "table" then
                    rows[#rows + 1] = { key = key, data = gData }
                end
            end
        end
        table.sort(rows, function(a, b)
            return (a.data.guildName or "") < (b.data.guildName or "")
        end)

        for i, row in ipairs(rows) do
            local r, g = GetRow(i), row.data
            r.key, r.guildName = row.key, g.guildName
            r.nm:SetText(string.format("|cffffff88%s|r |cff555555(%s)|r",
                g.guildName or "?", g.realm or "?"))
            r:Show()
        end
        for i = #rows + 1, #pool do pool[i]:Hide() end

        empty:SetShown(#rows == 0)
        child:SetHeight(math.max(#rows > 0 and #rows * ROW_H or 30, 1))
    end

    return { Populate = Populate }
end
