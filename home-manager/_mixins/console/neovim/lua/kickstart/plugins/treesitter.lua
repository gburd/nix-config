return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    -- Pin to the master branch + commit-style config. lazy.nvim's default
    -- has drifted toward the incompatible `main`-branch rewrite (which drops
    -- nvim-treesitter.configs and the highlight/indent module API used
    -- below); without this pin a plugin update silently breaks the whole
    -- spec. `master` keeps the configs API.
    branch = 'master',
    -- :TSUpdate recompiles parsers against the running neovim. Stale `.so`
    -- parsers compiled for an OLDER neovim ABI cause
    -- `attempt to call method 'range' (a nil value)` crashes after a neovim
    -- upgrade. If that ever recurs after bumping neovim, run :TSUpdate (or
    -- wipe ~/.local/share/nvim/lazy/nvim-treesitter/parser/*.so and reopen).
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter`
    opts = {
      ensure_installed = { 'bash', 'c', 'diff', 'html', 'lua', 'luadoc', 'markdown', 'markdown_inline', 'query', 'vim', 'vimdoc' },
      -- Autoinstall languages that are not installed
      auto_install = true,
      highlight = {
        enable = true,
        -- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
        --  If you are experiencing weird indenting issues, add the language to
        --  the list of additional_vim_regex_highlighting and disabled languages for indent.
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
    -- There are additional nvim-treesitter modules that you can use to interact
    -- with nvim-treesitter. You should go explore a few and see what interests you:
    --
    --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
    --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
    --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
  },
}
-- vim: ts=2 sts=2 sw=2 et
