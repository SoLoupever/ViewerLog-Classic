local addonName, ns = ...

-- Registre de thèmes du panneau. Un thème = un fichier ui/themes/*.lua
-- qui appelle ns.UI.RegisterTheme. ns.UI.Colors est muté sur place :
-- les modules gardent leur référence et se re-skinnent via BindTheme.

ns.UI = ns.UI or {}
ns.UI.Colors = {}

local C = ns.UI.Colors
local DEFAULT_THEME = "hybrid"

local themes, order, binders = {}, {}, {}
local currentId

function ns.UI.RegisterTheme(id, def)
    if not themes[id] then order[#order + 1] = id end
    themes[id] = def
end

-- Liste ordonnée { { id, def }, ... } pour la page Thème.
function ns.UI.GetThemes()
    local list = {}
    for i, id in ipairs(order) do list[i] = { id = id, def = themes[id] } end
    return list
end

function ns.UI.GetThemeId()
    return currentId
end

-- fn(C) est appelée tout de suite si un thème est actif, puis à chaque changement.
function ns.UI.BindTheme(fn)
    binders[#binders + 1] = fn
    if currentId then fn(C) end
end

function ns.UI.ApplyTheme(id)
    if not themes[id] then id = DEFAULT_THEME end
    local def = themes[id]
    if not def then return end
    currentId = id
    wipe(C)
    for k, v in pairs(def.colors) do C[k] = v end
    for i = 1, #binders do binders[i](C) end
end
