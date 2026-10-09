return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
        require("tokyonight").setup({
            on_highlights = function(hl, c)
                hl.RenderMarkdownCode = { fg = "#c47050" }
                hl["@markup.raw.markdown_inline"] = { fg = "#c47050" }
                hl.CursorLine = { bg = "#d7d9e3" } -- lighter current-line highlight (theme default #c4c8da)
            end,
        })
        vim.cmd[[colorscheme tokyonight-day]]
    end,
}
