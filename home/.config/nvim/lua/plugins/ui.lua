return {
  {
    'gbprod/nord.nvim',
    lazy = true,
    opts = {},
  },
  {
    'folke/tokyonight.nvim',
    lazy = true,
    opts = {},
  },
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = true,
    opts = { auto_integrations = true },
  },
  {
    'ellisonleao/gruvbox.nvim',
    lazy = true,
    opts = { contrast = 'hard' },
  },
  {
    'rebelot/kanagawa.nvim',
    lazy = true,
    opts = { theme = 'wave' },
  },
  {
    'rose-pine/neovim',
    name = 'rose-pine',
    lazy = true,
    opts = { dark_variant = 'moon' },
  },
  {
    'folke/which-key.nvim',
    lazy = false,
    config = true,  -- popup that shows what my leader keys do
  },
}
