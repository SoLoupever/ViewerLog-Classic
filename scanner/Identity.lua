local addonName, ns = ...

-- Identité du personnage : niveau, classe, faction, or, ilvl, dernière connexion.
-- Socle du noyau, indépendant des scanners d'objets.

local math_floor = math.floor
local select     = select
local time       = time

-- Niveau d'objet moyen équipé.
function ns.ScanItemLevel()
    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local _, avgEquipped = GetAverageItemLevel()
    local ilvl = math_floor(avgEquipped or 0)
    if ilvl > 0 then charData.ilvl = ilvl end
end

-- isLogout : au logout l'or n'est réécrit que si > 0, lastLogin intact.
function ns.ScanIdentity(isLogout)
    local charData = ns.GetCurrentCharData()
    if not charData then return end

    local gold = GetMoney()
    if gold and (isLogout and gold > 0 or gold >= 0) then charData.gold = gold end

    charData.level   = UnitLevel("player")
    charData.class   = select(2, UnitClass("player"))
    charData.faction = UnitFactionGroup("player")

    if not isLogout then charData.lastLogin = time() end

    ns.ScanItemLevel()
end
