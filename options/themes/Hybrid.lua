local addonName, ns = ...

-- Thème par défaut.

ns.UI.RegisterTheme("hybrid", {
    labelKey = "THEME_HYBRID",
    colors = {
        titleA = "ffab65d3", titleB = "ffffffff",

        bg          = { 0.02, 0.02, 0.03, 1 },
        border      = { 0.42, 0.35, 0.23, 1 },
        inner       = { 0.05, 0.05, 0.06, 1 },
        innerBorder = { 0.25, 0.22, 0.15, 1 },
        box         = { 0.02, 0.02, 0.03, 1 },
        boxBorder   = { 0.25, 0.22, 0.15, 1 },
        card        = { 0.03, 0.03, 0.04, 1 },
        cardBorder  = { 1.00, 0.82, 0.00, 1 },
        previewBorder = { 0.49, 0.31, 0.78, 1 },

        accent      = { 0.69, 0.38, 0.88 },
        accentDim   = { 0.25, 0.22, 0.15 },
        previewHdr  = { 0.69, 0.38, 0.88 },
        rowSep      = { 0.25, 0.22, 0.15, 0.50 },

        tabBg           = { 0.02, 0.02, 0.03, 1 },
        tabBorder       = { 0.42, 0.35, 0.23, 1 },
        tabText         = { 0.70, 0.88, 0.45 },
        tabActiveBg     = { 0.02, 0.02, 0.03, 1 },
        tabActiveBorder = { 0.62, 0.35, 0.86, 1 },
        tabActiveText   = { 0.78, 0.58, 0.95 },

        checkBg     = { 0.02, 0.02, 0.03, 1 },
        checkBorder = { 1.00, 0.82, 0.00, 1 },

        text         = { 1.00, 1.00, 1.00 },
        textDim      = { 0.65, 0.62, 0.55 },
        textDisabled = { 0.45, 0.45, 0.45 },

        btnBg          = { 0.02, 0.02, 0.03, 1 },
        btnBorder      = { 0.42, 0.35, 0.23, 1 },
        btnText        = { 0.70, 0.88, 0.45 },
        btnHoverBg     = { 0.10, 0.09, 0.06, 1 },
        btnHoverBorder = { 0.62, 0.35, 0.86, 1 },
    },
})
