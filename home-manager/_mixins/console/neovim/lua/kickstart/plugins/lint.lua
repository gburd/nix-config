return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      -- Point markdownlint at the global ~/.markdownlint.json unconditionally.
      -- nvim-lint runs `markdownlint --stdin` (buffer piped in), so markdownlint
      -- has no file path to walk up from and does config discovery from nvim's
      -- CWD. Launch nvim anywhere ~/.markdownlint.json isn't an ancestor (e.g.
      -- /scratch, /tmp, a project outside $HOME) and it falls back to noisy
      -- defaults: MD010 hard-tabs (the norm in Postgres work), MD013
      -- line-length, etc. Passing --config makes those non-errors everywhere.
      -- (Hard tabs stay disabled via ~/.markdownlint.json's MD010 = false.)
      local mdl = lint.linters.markdownlint
      local mdcfg = vim.fn.expand '~/.markdownlint.json'
      if vim.fn.filereadable(mdcfg) == 1 then
        mdl.args = { '--config', mdcfg, '--stdin' }
      end

      -- Configure linters by filetype
      -- Note: All linters are provided by Nix (see default.nix)
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        python = { 'ruff', 'mypy' }, -- ruff for style, mypy for types
        sh = { 'shellcheck' },
        bash = { 'shellcheck' },
        -- Rust uses rust-analyzer built-in diagnostics + clippy
        -- C/C++ uses clangd built-in diagnostics + clang-tidy
      }

      -- Create autocommand for linting on relevant events
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify
          if vim.bo.modifiable then
            lint.try_lint()
          end
        end,
      })

      -- Optional: Lint on keymap
      vim.keymap.set('n', '<leader>ll', function()
        lint.try_lint()
      end, { desc = '[L]int: Run [L]inters' })
    end,
  },
}
