-- neogit.lua
--
-- Neogit: a magit-style Git interface for Neovim (stage hunks, commit/amend,
-- branch, rebase, push/pull, log graph). Pairs with diffview.nvim for the
-- magit-like diff/merge views. Complements (doesn't replace) vim-fugitive +
-- gitsigns already in the config.
--
-- Open with :Neogit or <leader>gg.
return {
  {
    'NeogitOrg/neogit',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'sindrets/diffview.nvim', -- already a top-level spec; listed so neogit's diffview integration loads it
      'nvim-telescope/telescope.nvim', -- pickers (branches, etc.)
    },
    cmd = { 'Neogit' },
    keys = {
      { '<leader>gg', '<cmd>Neogit<cr>', desc = '[G]it: Neo[g]it (magit)' },
      { '<leader>gD', '<cmd>DiffviewOpen<cr>', desc = '[G]it: [D]iffview (working tree)' },
      { '<leader>gh', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it: file [h]istory' },
    },
    opts = {
      integrations = {
        diffview = true,
        telescope = true,
      },
    },
  },
}
