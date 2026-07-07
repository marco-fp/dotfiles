return {
  {
    'gbprod/nord.nvim',
    lazy = false,
    priority = 1000,  -- load before everything else so highlights apply
    config = function()
      require('nord').setup({ transparent = true })
      vim.cmd.colorscheme('nord')
    end,
  },
  {
    'folke/which-key.nvim',
    lazy = false,
    config = true,  -- popup that shows what my leader keys do
  },
}

