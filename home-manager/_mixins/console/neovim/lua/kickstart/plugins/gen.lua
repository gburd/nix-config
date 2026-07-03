-- gen.lua
--
-- gen.nvim: generate/transform text in the buffer with an LLM, without
-- leaving Neovim (from Kun Chen's agentic workflow, chapter "Neovim as
-- editor"). gen.nvim defaults to a local Ollama endpoint, but its `command`
-- option is a Lua function returning the curl invocation, so we point it at
-- the loopback LiteLLM gateway (the same Bedrock proxy the CLI agents use)
-- via its OpenAI-compatible /v1/chat/completions endpoint.
--
-- Usage: visually select code (or not) then :Gen  (or <leader>ai), pick a
-- prompt (Ask / Enhance_Code / Review_Code / ...). Output replaces the
-- selection or opens in a float depending on the prompt.
--
-- The LiteLLM key is read from ~/.config/litellm/keys/pi.key at startup.
return {
  {
    'David-Kunz/gen.nvim',
    cmd = { 'Gen' },
    keys = {
      { '<leader>ai', ':Gen<CR>', mode = { 'n', 'v' }, desc = '[AI] gen.nvim menu' },
      { '<leader>aa', ':Gen Ask<CR>', mode = { 'n', 'v' }, desc = '[A]I: [A]sk about selection' },
    },
    config = function()
      local gen = require 'gen'

      -- Read the per-agent LiteLLM virtual key (pi's), fall back to master.
      local function litellm_key()
        local paths = {
          vim.fn.expand '~/.config/litellm/keys/pi.key',
          vim.fn.expand '~/.config/litellm/master.key',
        }
        for _, p in ipairs(paths) do
          local f = io.open(p, 'r')
          if f then
            local k = f:read('*l') or ''
            f:close()
            if k ~= '' then return k end
          end
        end
        return ''
      end

      gen.setup {
        model = 'claude-sonnet-5', -- fast tier for in-editor edits
        display_mode = 'float',
        show_prompt = true,
        show_model = true,
        no_auto_close = false,
        -- Route through the loopback LiteLLM gateway (OpenAI-compatible),
        -- NOT Ollama. gen.nvim treats the command's stdout as the raw model
        -- text (json_response=false), so we make a NON-streaming request and
        -- extract choices[0].message.content with jq — gen.nvim then shows
        -- exactly that text. (OpenAI SSE streaming doesn't match gen.nvim's
        -- Ollama-shaped parser, so we avoid it.)
        command = function(options)
          local key = litellm_key()
          local body = {
            model = options.model,
            stream = false,
            messages = { { role = 'user', content = options.prompt } },
          }
          return 'curl --silent -X POST http://127.0.0.1:4000/v1/chat/completions'
            .. " -H 'Content-Type: application/json'"
            .. " -H 'Authorization: Bearer " .. key .. "'"
            .. ' -d ' .. vim.fn.shellescape(vim.fn.json_encode(body))
            .. " | jq -r '.choices[0].message.content // .error.message // empty'"
        end,
        -- stdout is already the plain model text (jq-extracted), not JSON.
        json_response = false,
      }
    end,
  },
}
