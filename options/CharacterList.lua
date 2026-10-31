local addonName, ns = ...

-- Liste des personnages enregistrés (suppression individuelle).
-- Lignes réutilisées entre deux Populate (pas de recréation de frames).

ns.UI = ns.UI or {}

local ROW_H = 22

local function ClassColorStr(class)
    local col = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class and string.upper(class) or ""]
    if col and col.colorStr then return col.colorStr end
    if col then
        return string.format("ff%02x%02x%02x",
            math.floor((col.r or 0.8) * 255),
            math.floor((col.g or 0.8) * 255),
            math.floor((col.b or 0.8) * 255))
    end
    return "ffcccccc"
end

-- block : conteneur ; colWidth : largeur de la colonne gauche.
function ns.UI.BuildCharacterList(block, colWidth)
    local sec = ns.UI.SectionTitle(block, ns.L("SECTION_CHARACTERS"), block, "TOPLEFT", 16, -18)

    local charBg, _, child = ns.UI.MakeScrollBox(block, 0, 0, nil, nil)
    charBg:ClearAllPoints()
    charBg:SetPoint("TOPLEFT",     sec,   "BOTTOMLEFT", -6, -6)
    charBg:SetPoint("BOTTOMRIGHT", block, "BOTTOMLEFT", colWidth, 0)

    local pool = {}

    local empty = child:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    empty:SetPoint("TOPLEFT", 4, -4)
    ns.UI.Tint(empty, "textDisabled")
    empty:SetText(ns.L("NO_CHAR_REGISTERED"))

    local function GetRow(i)
        local r = pool[i]
        if r then return r end

        r = CreateFrame("Frame", nil, child)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT",  child, "TOPLEFT",  0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -4, -(i - 1) * ROW_H)

        r.fx = r:CreateTexture(nil, "OVERLAY")
        r.fx:SetSize(14, 14)
        r.fx:SetPoint("LEFT", 2, 0)

        r.nm = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.nm:SetPoint("LEFT",  r, "LEFT",  20,  0)
        r.nm:SetPoint("RIGHT", r, "RIGHT", -82, 0)
        r.nm:SetJustifyH("LEFT")

        r.del = ns.UI.DeleteBtn(r, function()
            StaticPopup_Show("VL_DEL_CHAR",
                r.charName .. " (" .. r.realm .. ")", nil,
                { char = r.charName, realm = r.realm })
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
        for realmName, realmData in pairs(ViewerLogDB) do
            if ns.IsRealm(realmName, realmData) then
                for charName, data in pairs(realmData) do
                    if type(data) == "table" then
                        rows[#rows + 1] = { realm = realmName, char = charName, data = data }
                    end
                end
            end
        end
        table.sort(rows, function(a, b)
            if a.realm ~= b.realm then return a.realm < b.realm end
            return a.char < b.char
        end)

        for i, row in ipairs(rows) do
            local r, data = GetRow(i), row.data
            r.charName, r.realm = row.char, row.realm
            local icon = ns.GetFactionIconPath(data.faction)
            if icon then r.fx:SetTexture(icon) end
            local cs = ClassColorStr(data.class)
            r.nm:SetText(string.format("|c%s[%s]|r |c%s%s|r  |c%sLv%d|r",
                cs, row.realm, cs, row.char, cs, data.level or 0))
            r:Show()
        end
        for i = #rows + 1, #pool do pool[i]:Hide() end

        empty:SetShown(#rows == 0)
        child:SetHeight(math.max(#rows > 0 and #rows * ROW_H or 30, 1))
    end

    return { Populate = Populate }
end
