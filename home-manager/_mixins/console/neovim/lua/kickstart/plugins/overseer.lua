return {
  {
    'stevearc/overseer.nvim',
    opts = {},
    keys = {
      {
        '<leader>or',
        '<cmd>OverseerRun<cr>',
        desc = '[O]verseer [R]un',
      },
      {
        '<leader>ot',
        '<cmd>OverseerToggle<cr>',
        desc = '[O]verseer [T]oggle',
      },
      {
        '[q',
        function()
          if require('trouble').is_open() then
            require('trouble').prev { skip_groups = true, jump = true }
          else
            local ok, err = pcall(vim.cmd.cprev)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = 'Next Source of Trouble',
      },
      {
        ']q',
        function()
          if require('trouble').is_open() then
            require('trouble').next { skip_groups = true, jump = true }
          else
            local ok, err = pcall(vim.cmd.cnext)
            if not ok then
              vim.notify(err, vim.log.levels.ERROR)
            end
          end
        end,
        desc = 'Previous Source of Trouble',
      },
    },
  },
}
