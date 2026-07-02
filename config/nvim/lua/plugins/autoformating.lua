-- Format on save (conform.nvim) and linting (nvim-lint).
-- Replaces none-ls/null-ls, which broke on Neovim 0.12 by depending on a
-- removed LSP internal (vim.lsp._request_name_to_capability). conform and
-- nvim-lint run the tools directly and don't touch LSP client internals.
-- The tools themselves are installed via Mason in lsp.lua's ensure_installed.
return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = {
      formatters_by_ft = {
        lua = { 'stylua' },
        sh = { 'shfmt' },
        terraform = { 'terraform_fmt' },
        python = { 'ruff_fix', 'ruff_format' },
        html = { 'prettier' },
        json = { 'prettier' },
        yaml = { 'prettier' },
        markdown = { 'prettier' },
        javascript = { 'prettier', 'eslint_d' },
        typescript = { 'prettier', 'eslint_d' },
        javascriptreact = { 'prettier', 'eslint_d' },
        typescriptreact = { 'prettier', 'eslint_d' },
      },
      -- Synchronous format on save; fall back to LSP formatting when no
      -- conform formatter is configured for the filetype. 3s ceiling covers
      -- prettier/eslint_d cold starts; warm saves are unaffected.
      format_on_save = { timeout_ms = 3000, lsp_format = 'fallback' },
      formatters = {
        shfmt = { prepend_args = { '-i', '4' } },
        -- `--extend-select I` keeps ruff's import sorting, matching the old
        -- none-ls ruff source. Appended because the builtin args start with
        -- the `check` subcommand — prepending would put the flag before it.
        ruff_fix = { append_args = { '--extend-select', 'I' } },
        -- eslint_d is not a conform built-in; defined here so lint autofixes
        -- still apply on save (as the old none-ls eslint_d formatter did).
        -- require_cwd skips it in projects without an ESLint config, where
        -- eslint_d would exit nonzero and error every save. A config living
        -- only in package.json#eslintConfig can't be detected by filename.
        eslint_d = {
          command = 'eslint_d',
          args = { '--fix-to-stdout', '--stdin', '--stdin-filename', '$FILENAME' },
          stdin = true,
          cwd = function(_, ctx)
            return vim.fs.root(ctx.dirname, {
              '.eslintrc',
              '.eslintrc.js',
              '.eslintrc.cjs',
              '.eslintrc.json',
              '.eslintrc.yaml',
              '.eslintrc.yml',
              'eslint.config.js',
              'eslint.config.mjs',
              'eslint.config.cjs',
              'eslint.config.ts',
              'eslint.config.mts',
              'eslint.config.cts',
            })
          end,
          require_cwd = true,
        },
      },
    },
  },
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      require('lint').linters_by_ft = {
        make = { 'checkmake' },
        -- In-buffer ESLint diagnostics, replacing the removed eslint_lsp.
        -- nvim-lint's eslint_d returns nothing when no ESLint config exists.
        javascript = { 'eslint_d' },
        typescript = { 'eslint_d' },
        javascriptreact = { 'eslint_d' },
        typescriptreact = { 'eslint_d' },
      }
      local group = vim.api.nvim_create_augroup('nvim-lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
        group = group,
        callback = function()
          require('lint').try_lint()
        end,
      })
    end,
  },
}
