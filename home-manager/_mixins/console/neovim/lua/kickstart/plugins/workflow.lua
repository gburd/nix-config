-- workflow.lua
--
-- Enhanced development workflow keybindings
-- For integrated edit-compile-test-debug-commit cycle

return {
  -- This is an "empty" plugin that just sets up keybindings
  -- We use lazy.nvim's init function to run code before plugin loading
  dir = vim.fn.stdpath 'config', -- Point to config dir (not a real plugin)
  init = function()
    -- Quick compile/build keybindings
    vim.keymap.set('n', '<leader>cc', function()
      local ft = vim.bo.filetype
      if ft == 'rust' then
        vim.cmd 'AsyncRun cargo check'
      elseif ft == 'c' or ft == 'cpp' then
        vim.cmd 'AsyncRun cmake --build build'
      elseif ft == 'python' then
        vim.cmd 'AsyncRun python3 -m py_compile %'
      else
        vim.notify('No compile command for filetype: ' .. ft, vim.log.levels.WARN)
      end
    end, { desc = '[C]ompile: Quick [C]heck' })

    -- Build release
    vim.keymap.set('n', '<leader>cb', function()
      local ft = vim.bo.filetype
      if ft == 'rust' then
        vim.cmd 'AsyncRun cargo build --release'
      elseif ft == 'c' or ft == 'cpp' then
        vim.cmd 'AsyncRun cmake --build build --config Release'
      else
        vim.notify('No build command for filetype: ' .. ft, vim.log.levels.WARN)
      end
    end, { desc = '[C]ompile: [B]uild release' })

    -- Run current file/project
    vim.keymap.set('n', '<leader>cr', function()
      local ft = vim.bo.filetype
      if ft == 'rust' then
        vim.cmd 'AsyncRun cargo run'
      elseif ft == 'python' then
        vim.cmd('AsyncRun python3 ' .. vim.fn.expand '%')
      elseif ft == 'sh' or ft == 'bash' then
        vim.cmd('AsyncRun bash ' .. vim.fn.expand '%')
      else
        vim.notify('No run command for filetype: ' .. ft, vim.log.levels.WARN)
      end
    end, { desc = '[C]ompile: [R]un' })

    -- Git commit workflow
    vim.keymap.set('n', '<leader>gc', function()
      vim.cmd 'Git commit'
    end, { desc = '[G]it: [C]ommit' })

    vim.keymap.set('n', '<leader>gp', function()
      vim.cmd 'Git push'
    end, { desc = '[G]it: [P]ush' })

    vim.keymap.set('n', '<leader>gP', function()
      vim.cmd 'Git pull'
    end, { desc = '[G]it: [P]ull' })

    vim.keymap.set('n', '<leader>gs', function()
      vim.cmd 'Git'
    end, { desc = '[G]it: [S]tatus' })

    vim.keymap.set('n', '<leader>gl', function()
      vim.cmd 'Git log'
    end, { desc = '[G]it: [L]og' })

    vim.keymap.set('n', '<leader>gd', function()
      vim.cmd 'Git diff'
    end, { desc = '[G]it: [D]iff' })

    vim.keymap.set('n', '<leader>gb', function()
      vim.cmd 'Git blame'
    end, { desc = '[G]it: [B]lame' })

    -- Better quickfix navigation
    vim.keymap.set('n', '<leader>qo', ':copen<CR>', { desc = '[Q]uickfix: [O]pen' })
    vim.keymap.set('n', '<leader>qc', ':cclose<CR>', { desc = '[Q]uickfix: [C]lose' })
    vim.keymap.set('n', '<leader>qn', ':cnext<CR>', { desc = '[Q]uickfix: [N]ext' })
    vim.keymap.set('n', '<leader>qp', ':cprev<CR>', { desc = '[Q]uickfix: [P]revious' })
    vim.keymap.set('n', '<leader>qf', ':cfirst<CR>', { desc = '[Q]uickfix: [F]irst' })
    vim.keymap.set('n', '<leader>ql', ':clast<CR>', { desc = '[Q]uickfix: [L]ast' })

    -- Location list navigation
    vim.keymap.set('n', '<leader>lo', ':lopen<CR>', { desc = '[L]ocation list: [O]pen' })
    vim.keymap.set('n', '<leader>lc', ':lclose<CR>', { desc = '[L]ocation list: [C]lose' })
    vim.keymap.set('n', '<leader>ln', ':lnext<CR>', { desc = '[L]ocation list: [N]ext' })
    vim.keymap.set('n', '<leader>lp', ':lprev<CR>', { desc = '[L]ocation list: [P]revious' })

    -- Database query execution (for SQL files)
    vim.keymap.set('n', '<leader>xe', function()
      if vim.bo.filetype == 'sql' then
        local query = vim.fn.input 'Database connection string: '
        if query ~= '' then
          vim.cmd('AsyncRun psql ' .. query .. ' -f ' .. vim.fn.expand '%')
        end
      else
        vim.notify('Not a SQL file', vim.log.levels.WARN)
      end
    end, { desc = 'E[x]ecute SQL query' })

    -- Format buffer
    vim.keymap.set('n', '<leader>cf', function()
      vim.lsp.buf.format { async = true }
    end, { desc = '[C]ode: [F]ormat' })

    -- Organize imports (if supported by LSP)
    vim.keymap.set('n', '<leader>co', function()
      vim.lsp.buf.code_action {
        context = { only = { 'source.organizeImports' } },
        apply = true,
      }
    end, { desc = '[C]ode: [O]rganize imports' })
  end,
}
