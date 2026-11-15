local addonName, ns = ...

-- Lien vers l'API du noyau (RequiredDeps : déjà chargée).

local vl = _G.ViewerLogAPI
ns.vl = vl
ns.GetCurrentCharData = vl.GetCurrentCharData
