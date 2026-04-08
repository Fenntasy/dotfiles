-- Highlight, edit, and navigate code
return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate',
  dependencies = {
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  config = function()
    -- New nvim-treesitter only handles parser installation.
    -- Highlighting and indent are now built into Neovim via vim.treesitter.
    require('nvim-treesitter').setup()

    -- Install parsers
    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        local ensure_installed = {
          'lua',
          'python',
          'javascript',
          'typescript',
          'vimdoc',
          'vim',
          'regex',
          'terraform',
          'sql',
          'dockerfile',
          'toml',
          'json',
          'java',
          'groovy',
          'go',
          'gitignore',
          'graphql',
          'yaml',
          'make',
          'cmake',
          'markdown',
          'markdown_inline',
          'bash',
          'tsx',
          'css',
          'html',
        }
        local installed = require('nvim-treesitter.config').get_installed()
        for _, lang in ipairs(ensure_installed) do
          if not vim.tbl_contains(installed, lang) then
            vim.cmd('TSInstall ' .. lang)
          end
        end
      end,
      once = true,
    })

    -- Textobjects setup (new standalone API)
    require('nvim-treesitter-textobjects').setup {
      select = {
        lookahead = true,
      },
      move = {
        set_jumps = true,
      },
    }

    -- Textobject select keymaps
    local select = require('nvim-treesitter-textobjects.select')
    vim.keymap.set({ 'x', 'o' }, 'aa', function() select.select_textobject('@parameter.outer') end)
    vim.keymap.set({ 'x', 'o' }, 'ia', function() select.select_textobject('@parameter.inner') end)
    vim.keymap.set({ 'x', 'o' }, 'af', function() select.select_textobject('@function.outer') end)
    vim.keymap.set({ 'x', 'o' }, 'if', function() select.select_textobject('@function.inner') end)
    vim.keymap.set({ 'x', 'o' }, 'ac', function() select.select_textobject('@class.outer') end)
    vim.keymap.set({ 'x', 'o' }, 'ic', function() select.select_textobject('@class.inner') end)

    -- Textobject move keymaps
    local move = require('nvim-treesitter-textobjects.move')
    vim.keymap.set({ 'n', 'x', 'o' }, ']m', function() move.goto_next_start('@function.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']]', function() move.goto_next_start('@class.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, ']M', function() move.goto_next_end('@function.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, '][', function() move.goto_next_end('@class.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[m', function() move.goto_previous_start('@function.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[[', function() move.goto_previous_start('@class.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[M', function() move.goto_previous_end('@function.outer') end)
    vim.keymap.set({ 'n', 'x', 'o' }, '[]', function() move.goto_previous_end('@class.outer') end)

    -- Textobject swap keymaps
    local swap = require('nvim-treesitter-textobjects.swap')
    vim.keymap.set('n', '<leader>a', function() swap.swap_next('@parameter.inner') end)
    vim.keymap.set('n', '<leader>A', function() swap.swap_previous('@parameter.inner') end)

    -- Register additional file extensions
    vim.filetype.add { extension = { tf = 'terraform' } }
    vim.filetype.add { extension = { tfvars = 'terraform' } }
    vim.filetype.add { extension = { pipeline = 'groovy' } }
    vim.filetype.add { extension = { multibranch = 'groovy' } }
  end,
}
