local addonName, ns = ...

-- Scanner : utilitaire de conteneur partagé (sac, banque).
-- Utilisé par Bags.lua, Bank.lua.

-- Écrit le contenu de `bag` dans dest[bag] = { [slot] = {id, count, link} }.
-- Réutilise les tables existantes (moins de pression GC sur scans répétés).
-- link = hyperlink complet : nécessaire pour les objets dont les stats
-- dépendent de l'instance (niveau d'amélioration, sockets…).
-- Bag sans slot (onglet non acheté / pas en cache) → dest[bag] retiré.
function ns.ScanContainerInto(bag, dest)
    local numSlots = C_Container.GetContainerNumSlots(bag)
    if not numSlots or numSlots == 0 then
        dest[bag] = nil
        return
    end

    local bagTable = dest[bag]
    if not bagTable then
        bagTable = {}
        dest[bag] = bagTable
    end

    for slot = 1, numSlots do
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info and info.itemID then
            local entry = bagTable[slot]
            if entry then
                entry.id    = info.itemID
                entry.count = info.stackCount or 1
                entry.link  = info.hyperlink
            else
                bagTable[slot] = { id = info.itemID, count = info.stackCount or 1, link = info.hyperlink }
            end
        elseif bagTable[slot] then
            bagTable[slot] = nil
        end
    end

    -- Purge des slots > numSlots restés d'un scan précédent (conteneur rétréci).
    for slot in pairs(bagTable) do
        if slot > numSlots then
            bagTable[slot] = nil
        end
    end
end
