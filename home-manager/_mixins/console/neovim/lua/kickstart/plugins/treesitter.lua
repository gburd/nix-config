return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    -- Pin to the master branch + commit-style config. lazy.nvim's default
    -- has drifted toward the incompatible `main`-branch rewrite (which drops
    -- nvim-treesitter.configs and the highlight/indent module API used
    -- below); without this pin a plugin update silently breaks the whole
    -- spec. `master` keeps the configs API.
    branch = 'master',
    -- :TSUpdate recompiles parsers against the running neovim.
    build = ':TSUpdate',
    main = 'nvim-treesitter.configs', -- Sets main module to use for opts

    -- Neovim 0.12 ships its own treesitter queries for c, lua, markdown,
    -- markdown_inline, query, vim and vimdoc, and nvim-treesitter's master
    -- branch does not support 0.12 (its README says so outright: "Neovim 0.10
    -- or 0.11 (Neovim 0.12 is not supported)"). Where both provide a query the
    -- plugin's copy sits earlier on the runtimepath and wins.
    --
    -- For markdown that combination is broken. The plugin's injections.scm
    -- captures the fence language as @_lang and resolves it with its own
    -- (#set-lang-from-info-string!) directive, while 0.12's query uses the
    -- standard @injection.language capture. When the directive is not applied
    -- the capture yields no node, and highlighting a fenced code block dies
    -- with "attempt to call method 'range' (a nil value)" from
    -- vim/treesitter.lua:get_range. Verified by isolation: plain prose and
    -- inline code are fine, only fenced blocks fail.
    --
    -- The only lever that actually works is removing the plugin's query files
    -- for the languages the runtime already owns. Two other approaches were
    -- tried and measured as ineffective: prepending VIMRUNTIME to the
    -- runtimepath in init() (lazy.nvim adds the plugin path afterwards), and
    -- re-registering the runtime text with vim.treesitter.query.set() in
    -- config() (query.get_files still resolved the plugin's copy).
    --
    -- So prune them here. This runs at startup, is idempotent, and re-applies
    -- after a plugin update reinstates the files. The plugin is kept for what
    -- it is still good for: compiling and updating parsers, since 0.12 bundles
    -- none.
    init = function()
      -- ONLY markdown/markdown_inline. Pruning every language the runtime
      -- ships was measured to break lua and vim: the runtime's newer queries
      -- reference node types the plugin's older compiled parsers do not have
      -- ("Invalid field name 'operator'", "Invalid node type 'tab'"). Queries
      -- and parsers have to come from the same generation, and for these two
      -- languages the plugin supplies both consistently. Markdown is the
      -- exception because there the plugin's own query is the thing that is
      -- broken under 0.12.
      local runtime_owned = { 'markdown', 'markdown_inline' }
      local base = vim.fn.stdpath 'data' .. '/lazy/nvim-treesitter/queries/'
      for _, lang in ipairs(runtime_owned) do
        -- Only prune when the runtime genuinely provides this language, so a
        -- future neovim that drops a query does not leave us with none.
        if vim.uv.fs_stat(vim.env.VIMRUNTIME .. '/queries/' .. lang) then
          local dir = base .. lang
          if vim.uv.fs_stat(dir) then
            vim.fn.delete(dir, 'rf')
          end
        end
      end
    end,
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
