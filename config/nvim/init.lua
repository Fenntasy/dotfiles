require 'core.options'
require 'core.keymaps'

-- Compatibility shim for none-ls.nvim with Neovim 0.11+
-- vim.lsp._request_name_to_capability moved to vim.lsp.protocol._request_name_to_capability
if not vim.lsp._request_name_to_capability then
    vim.lsp._request_name_to_capability = vim.lsp.protocol._request_name_to_capability
end

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
    local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
    if vim.v.shell_error ~= 0 then
        error('Error cloning lazy.nvim:\n' .. out)
    end
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
    require 'plugins.neotree',
    require 'plugins.colortheme',
    require 'plugins.bufferline',
    require 'plugins.lualine',
    require 'plugins.treesitter',
    require 'plugins.telescope',
    require 'plugins.lsp',
    require 'plugins.autocompletion',
    require 'plugins.autoformating',
    require 'plugins.gitsigns',
    { 'folke/which-key.nvim' },
    {
        'norcalli/nvim-colorizer.lua',
        config = function()
            require('colorizer').setup()
        end,
    },
}
