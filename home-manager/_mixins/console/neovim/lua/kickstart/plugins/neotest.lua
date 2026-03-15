-- neotest.lua
--
-- Testing framework integration for Neovim
-- Supports: Rust, Python, C/C++ (via gtest/ctest)

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'antoinemadec/FixCursorHold.nvim',
    'nvim-treesitter/nvim-treesitter',

    -- Language-specific adapters
    'rouge8/neotest-rust', -- Rust (cargo test, cargo-nextest)
    'nvim-neotest/neotest-python', -- Python (pytest, unittest)
    'alfaix/neotest-gtest', -- C/C++ (GoogleTest)
    'nvim-neotest/neotest-plenary', -- Lua (for neovim plugin development)
  },
  keys = {
    {
      '<leader>tt',
      function()
        require('neotest').run.run()
      end,
      desc = '[T]est: Run nearest [T]est',
    },
    {
      '<leader>tf',
      function()
        require('neotest').run.run(vim.fn.expand '%')
      end,
      desc = '[T]est: Run current [F]ile',
    },
    {
      '<leader>tF',
      function()
        require('neotest').run.run(vim.fn.getcwd())
      end,
      desc = '[T]est: Run all test [F]iles',
    },
    {
      '<leader>td',
      function()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = '[T]est: [D]ebug nearest test',
    },
    {
      '<leader>ts',
      function()
        require('neotest').run.stop()
      end,
      desc = '[T]est: [S]top',
    },
    {
      '<leader>ta',
      function()
        require('neotest').run.attach()
      end,
      desc = '[T]est: [A]ttach to nearest test',
    },
    {
      '<leader>to',
      function()
        require('neotest').output.open { enter = true, auto_close = true }
      end,
      desc = '[T]est: Show [O]utput',
    },
    {
      '<leader>tO',
      function()
        require('neotest').output_panel.toggle()
      end,
      desc = '[T]est: Toggle [O]utput panel',
    },
    {
      '<leader>tS',
      function()
        require('neotest').summary.toggle()
      end,
      desc = '[T]est: Toggle [S]ummary',
    },
    {
      '[t',
      function()
        require('neotest').jump.prev { status = 'failed' }
      end,
      desc = '[T]est: Jump to previous failed test',
    },
    {
      ']t',
      function()
        require('neotest').jump.next { status = 'failed' }
      end,
      desc = '[T]est: Jump to next failed test',
    },
  },
  config = function()
    local neotest = require 'neotest'

    neotest.setup {
      adapters = {
        -- Rust adapter (supports cargo test and cargo-nextest)
        require 'neotest-rust' {
          args = { '--no-capture' },
          -- Use cargo-nextest if available, fall back to cargo test
          dap_adapter = 'lldb',
        },

        -- Python adapter (pytest)
        require 'neotest-python' {
          dap = {
            justMyCode = false,
            console = 'integratedTerminal',
          },
          args = { '--log-level', 'DEBUG', '--quiet' },
          runner = 'pytest',
          -- Auto-detect virtual environments
          python = function()
            local cwd = vim.fn.getcwd()
            if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
              return cwd .. '/venv/bin/python'
            elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
              return cwd .. '/.venv/bin/python'
            else
              return 'python3'
            end
          end,
        },

        -- C/C++ adapter (GoogleTest)
        require 'neotest-gtest'.setup {
          -- Optional: specify gtest executable
          -- gtest_executable = 'path/to/gtest_executable'
        },

        -- Lua/Neovim plugin development
        require 'neotest-plenary',
      },
      -- Benchmark support
      benchmark = {
        enabled = true,
      },
      -- Consumer configuration
      consumers = {},
      -- Default strategy for running tests
      default_strategy = 'integrated',
      -- Diagnostic configuration
      diagnostic = {
        enabled = true,
        severity = vim.diagnostic.severity.ERROR,
      },
      -- Floating window configuration
      floating = {
        border = 'rounded',
        max_height = 0.8,
        max_width = 0.8,
        options = {},
      },
      -- Highlight configuration
      highlights = {
        adapter_name = 'NeotestAdapterName',
        border = 'NeotestBorder',
        dir = 'NeotestDir',
        expand_marker = 'NeotestExpandMarker',
        failed = 'NeotestFailed',
        file = 'NeotestFile',
        focused = 'NeotestFocused',
        indent = 'NeotestIndent',
        marked = 'NeotestMarked',
        namespace = 'NeotestNamespace',
        passed = 'NeotestPassed',
        running = 'NeotestRunning',
        select_win = 'NeotestWinSelect',
        skipped = 'NeotestSkipped',
        target = 'NeotestTarget',
        test = 'NeotestTest',
        unknown = 'NeotestUnknown',
        watching = 'NeotestWatching',
      },
      -- Icon configuration
      icons = {
        child_indent = '│',
        child_prefix = '├',
        collapsed = '─',
        expanded = '╮',
        failed = '✖',
        final_child_indent = ' ',
        final_child_prefix = '╰',
        non_collapsible = '─',
        passed = '✔',
        running = '⟳',
        running_animated = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
        skipped = '↷',
        unknown = '?',
        watching = '👁',
      },
      -- Jump configuration
      jump = {
        enabled = true,
      },
      -- Log level
      log_level = vim.log.levels.WARN,
      -- Output configuration
      output = {
        enabled = true,
        open_on_run = 'short',
      },
      -- Output panel configuration
      output_panel = {
        enabled = true,
        open = 'botright split | resize 15',
      },
      -- Project configuration
      projects = {},
      -- Quick fix configuration
      quickfix = {
        enabled = true,
        open = false,
      },
      -- Run configuration
      run = {
        enabled = true,
      },
      -- Running status icon
      running = {
        concurrent = true,
      },
      -- State configuration
      state = {
        enabled = true,
      },
      -- Status configuration
      status = {
        enabled = true,
        signs = true,
        virtual_text = false,
      },
      -- Strategies available
      strategies = {
        integrated = {
          height = 40,
          width = 120,
        },
      },
      -- Summary window configuration
      summary = {
        enabled = true,
        expand_errors = true,
        follow = true,
        mappings = {
          attach = 'a',
          clear_marked = 'M',
          clear_target = 'T',
          debug = 'd',
          debug_marked = 'D',
          expand = { '<CR>', '<2-LeftMouse>' },
          expand_all = 'e',
          jumpto = 'i',
          mark = 'm',
          next_failed = 'J',
          output = 'o',
          prev_failed = 'K',
          run = 'r',
          run_marked = 'R',
          short = 'O',
          stop = 'u',
          target = 't',
          watch = 'w',
        },
        open = 'botright vsplit | vertical resize 50',
      },
      -- Watch configuration
      watch = {
        enabled = true,
        symbol_queries = {
          python = [[
            (function_definition) @symbol
            (class_definition) @symbol
          ]],
          rust = [[
            (function_item) @symbol
            (impl_item) @symbol
          ]],
        },
      },
    }
  end,
}
