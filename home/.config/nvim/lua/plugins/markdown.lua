-- In-editor markdown: beautiful rendering, live editing, tables, cross-file nav.
-- Neovim 0.12 bundles the markdown + markdown_inline treesitter parsers, so no
-- nvim-treesitter plugin is needed; the renderer works off the built-in parse
-- tree. (Add nvim-treesitter later only if you want syntax highlighting inside
-- code fences of other languages.)
--
-- RENDERER: render-markdown.nvim (this branch) vs markview.nvim (nvim-markdown
-- branch). Swap branches to compare the two.
return {
  -- Renderer. Renders in normal mode; the cursor line is un-rendered (raw) via
  -- anti-conceal so you edit in place. Insert mode shows raw text by default.
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    init = function()
      -- Base highlighting for the raw text left visible (cursor line, inline
      -- code). Idempotent; bundled parser makes this free.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'markdown',
        callback = function() pcall(vim.treesitter.start) end,
      })
    end,
    opts = {},  -- render-markdown's tuned defaults.
                -- To also render while editing (match markview's hybrid feel):
                --   opts = { render_modes = { 'n', 'c', 'i' } }
  },

  -- Editing ergonomics: toggle bold/italic, follow links, list continuation, TOC.
  {
    'tadmccorkle/markdown.nvim',
    ft = { 'markdown' },
    opts = {},
  },

  -- Tables: align pipes as you type, Tab between cells (edits the real text).
  {
    'dhruvasagar/vim-table-mode',
    ft = { 'markdown' },
    init = function()
      vim.g.table_mode_corner = '|'  -- github-flavored table corners
    end,
  },

  -- Cross-file navigation: marksman LSP (binary installed via home.nix).
  -- Neovim 0.11+ already maps grn (rename), gra (code action), K (hover) on
  -- attach, so only completion and a snacks-consistent grr are wired here.
  -- `gd` stays mapped to the snacks picker in navigation.lua.
  {
    'neovim/nvim-lspconfig',  -- ships lsp/marksman.lua that vim.lsp.enable reads
    ft = { 'markdown' },
    config = function()
      vim.lsp.config('marksman', {
        on_attach = function(client, bufnr)
          if client:supports_method('textDocument/completion') then
            vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
          end
          vim.keymap.set('n', 'grr', function() Snacks.picker.lsp_references() end,
            { buffer = bufnr, desc = 'References' })
        end,
      })
      vim.lsp.enable('marksman')
    end,
  },
}
