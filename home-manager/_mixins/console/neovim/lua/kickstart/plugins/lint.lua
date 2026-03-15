return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

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
