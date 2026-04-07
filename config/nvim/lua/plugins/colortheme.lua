return {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
        on_highlights = function(hl, c)
            hl.RenderMarkdownCode = { bg = c.bg_highlight }
            hl["@markup.raw.markdown_inline"] = {
                bg = c.bg_highlight, fg = c.blue,
            }
        end,
    },
    config = function()
        vim.cmd[[colorscheme tokyonight-day]]
    end,
}
