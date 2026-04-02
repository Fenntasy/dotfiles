---
name: nvim-config
description: >
  Answer questions about the user's Neovim configuration. Covers keymaps,
  plugins, LSP servers, formatters, and editor options. Use when the user asks
  "what's the shortcut for X", "how did I configure X", "which LSP handles Y",
  or "how does X work in my vim config".
version: 1.0.0
date: 2026-04-02
user-invocable: true
argument-hint: "e.g. 'shortcut for file search' or 'which formatter runs on save'"
context:
  - config/nvim/lua/core/keymaps.lua
  - config/nvim/lua/core/options.lua
  - config/nvim/lua/plugins/telescope.lua
  - config/nvim/lua/plugins/lsp.lua
  - config/nvim/lua/plugins/autocompletion.lua
  - config/nvim/lua/plugins/autoformating.lua
  - config/nvim/lua/plugins/neotree.lua
  - config/nvim/lua/plugins/treesitter.lua
  - config/nvim/lua/plugins/gitsigns.lua
  - config/nvim/lua/plugins/bufferline.lua
  - config/nvim/lua/plugins/lualine.lua
  - config/nvim/lua/plugins/colortheme.lua
  - config/nvim/init.lua
---

# Neovim Config Q&A

Answer questions about the user's Neovim config by reading the context files
loaded above. Always cite the specific file and relevant lines.

## How to answer

- **"What's the shortcut for X?"** — search keymaps.lua first, then plugin
  files (telescope.lua, lsp.lua, neotree.lua, etc.)
- **"How did I configure X?"** — find the relevant plugin file and explain
  the options set
- **"Which LSP/formatter handles X?"** — check lsp.lua for servers,
  autoformating.lua for formatters (none-ls sources)
- **"What does this option do?"** — check options.lua and explain the setting

## Config structure

| File | Contains |
|------|----------|
| `core/keymaps.lua` | All global keymaps; leader = `Space` |
| `core/options.lua` | Editor settings (indent, search, display, etc.) |
| `plugins/telescope.lua` | Fuzzy finder keymaps (`<leader>s*`, `<leader>g*`) |
| `plugins/lsp.lua` | LSP servers (Mason), LSP keymaps (`gd`, `gr`, `K`, etc.) |
| `plugins/autocompletion.lua` | nvim-cmp + LuaSnip keymaps |
| `plugins/autoformating.lua` | none-ls formatters, format-on-save autocmd |
| `plugins/neotree.lua` | File explorer keymaps (`<leader>e`, `<leader>w`, `\`) |
| `plugins/treesitter.lua` | Syntax, text objects, incremental selection |
| `plugins/gitsigns.lua` | Git gutter signs |
| `plugins/bufferline.lua` | Buffer tabs (`Tab`, `Shift+Tab`, `<leader>x`) |
| `plugins/lualine.lua` | Status line appearance and mode colors |
| `plugins/colortheme.lua` | Color scheme (Tokyo Night Day) |

## Key conventions

- Leader key is `Space`
- `<leader>s*` — search/telescope commands
- `<leader>g*` — git telescope commands
- `C-*` — Ctrl shortcuts
- `gd`, `gr`, `gI`, `gD` — LSP navigation
