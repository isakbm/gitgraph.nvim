local log = require('gitgraph.log')
local utils = require('gitgraph.utils')
local core = require('gitgraph.core')

local M = {}

---@param config I.GGConfig
---@param options I.DrawOptions
---@param args I.GitLogArgs
function M.draw(config, options, args)
  M.graph = {}

  local so = os.clock()

  if utils.check_cmd('git --version') then
    log.error('git command not found, please install it')
    return
  end

  if utils.check_cmd('git status') then
    log.error('does not seem to be a valid git repo')
    return
  end

  -- reuse or create buffer
  do
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
      M.buf = vim.api.nvim_create_buf(false, true)
    end
  end

  -- set active buffer to this one
  local buf = M.buf
  assert(buf)
  vim.api.nvim_win_set_buf(0, buf)

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf }) -- make modifiable
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf }) -- unlisted
  vim.api.nvim_set_option_value('wrap', false, { scope = 'local' }) -- turn off linewrap

  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1) -- clear highlights

  -- clear
  do
    local cl_start = os.clock()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    local clear_dur = os.clock() - cl_start
    log.info('clear dur', clear_dur * 1000, 'ms')
  end

  -- extract graph data
  local graph, lines, highlights, head_loc = core.gitgraph(config, options, args)
  M.graph = graph

  local start = os.clock()
  -- put graph data in buffer
  do
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines) -- text

    -- highlights

    local function high()
      for _, hl in ipairs(highlights) do
        local offset = 1
        vim.api.nvim_buf_add_highlight(buf, -1, hl.hg, hl.row - 1, hl.start - 1 + offset, hl.stop + offset)
      end
    end

    local co = coroutine.create(high)

    local function wait_poll()
      if coroutine.status(co) ~= 'dead' then
        coroutine.resume(co)
        vim.defer_fn(wait_poll, 16) -- Adjust delay as needed
      end
    end

    vim.defer_fn(wait_poll, 1)
  end

  do
    local cursor_line = head_loc
    vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
  end

  utils.apply_buffer_options(buf)
  utils.apply_buffer_mappings(buf, M.graph, config.hooks)
  local dur = os.clock() - start
  log.info('rest dur:', dur * 1000, 'ms')

  local tot_dur = os.clock() - so
  log.info('total dur:', tot_dur * 1000, 'ms')
end

return M
