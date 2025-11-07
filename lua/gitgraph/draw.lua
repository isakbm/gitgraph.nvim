local log = require('gitgraph.log')
local utils = require('gitgraph.utils')
local core = require('gitgraph.core')
local ui = require('gitgraph.ui')

local M = {
  graph = {},
  buf = nil,
  win = nil,
}

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

  if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
    M.buf = vim.api.nvim_create_buf(false, true)
  end

  local buf = M.buf
  local win

  if config.window then
    buf, win = ui.open({}, {}, config.window)
  else
    win = 0
    vim.api.nvim_win_set_buf(win, buf)
  end

  M.win = win

  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  vim.api.nvim_set_option_value('wrap', false, { scope = 'local' })
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})

  local graph, lines, highlights, head_loc = core.gitgraph(config, options, args)
  M.graph = graph

  vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)

  local function apply_highlights()
    for _, hl in ipairs(highlights) do
      local offset = 1
      vim.api.nvim_buf_add_highlight(buf, -1, hl.hg, hl.row - 1, hl.start - 1 + offset, hl.stop + offset)
    end
  end

  local co = coroutine.create(apply_highlights)
  local function poll()
    if coroutine.status(co) ~= 'dead' then
      coroutine.resume(co)
      vim.defer_fn(poll, 16)
    end
  end
  vim.defer_fn(poll, 1)

  if head_loc then
    vim.api.nvim_win_set_cursor(0, { head_loc, 0 })
  end

  utils.apply_buffer_options(buf)
  utils.apply_buffer_mappings(buf, M.graph, config.hooks)

  local tot_dur = os.clock() - so
  log.info('total dur:', tot_dur * 1000, 'ms')
end

--- закрыть окно gitgraph
function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    pcall(vim.api.nvim_win_close, M.win, true)
  end
  M.win, M.buf, M.graph = nil, nil, {}
end

--- переключение отображения графа
function M.toggle(config, options, args)
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    M.close()
  else
    M.draw(config, options, args)
  end
end

return M
