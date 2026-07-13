local log = require('gitgraph.log')
local utils = require('gitgraph.utils')
local core = require('gitgraph.core')

local M = {}

local NS = vim.api.nvim_create_namespace('GitGraphDual')

-- Store window and buffer IDs for synchronization
M.graph_win = nil
M.graph_buf = nil
M.text_win = nil
M.text_buf = nil

-- Synchronization state
M.sync_scroll = true
M.updating_scroll = false

-- Synchronize vertical scrolling between windows
local function sync_vertical_scroll()
  if M.updating_scroll or not M.sync_scroll then
    return
  end

  M.updating_scroll = true

  local current_win = vim.api.nvim_get_current_win()
  local current_line = vim.api.nvim_win_get_cursor(current_win)[1]

  -- Sync to the other window
  if current_win == M.graph_win and M.text_win and vim.api.nvim_win_is_valid(M.text_win) then
    vim.api.nvim_win_set_cursor(M.text_win, { current_line, 0 })
  elseif current_win == M.text_win and M.graph_win and vim.api.nvim_win_is_valid(M.graph_win) then
    vim.api.nvim_win_set_cursor(M.graph_win, { current_line, 0 })
  end

  M.updating_scroll = false
end

-- Set up scroll synchronization autocmds
local function setup_scroll_sync()
  local group = vim.api.nvim_create_augroup('GitGraphDualSync', { clear = true })

  -- Cursor moved events
  vim.api.nvim_create_autocmd('CursorMoved', {
    group = group,
    callback = function()
      local current_win = vim.api.nvim_get_current_win()
      if current_win == M.graph_win or current_win == M.text_win then
        sync_vertical_scroll()
      end
    end,
  })

  -- Clean up when buffers are deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      if args.buf == M.graph_buf or args.buf == M.text_buf then
        M.graph_win = nil
        M.graph_buf = nil
        M.text_win = nil
        M.text_buf = nil
      end
    end,
  })
end

-- Apply buffer options for graph window
local function apply_graph_buffer_options(buf, win)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  -- Use unique name with timestamp to avoid conflicts
  local timestamp = os.time()
  vim.api.nvim_buf_set_name(buf, 'GitGraph-Dual-' .. timestamp)
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf }) -- ← самоочистка при закрытии вкладки

  -- Set window-local options
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_option_value('wrap', false, { win = win })
    vim.api.nvim_set_option_value('cursorline', true, { win = win })
    vim.api.nvim_set_option_value('winfixbuf', true, { win = win }) -- ← окно неподменяемо: gf/:edit сюда не влетит
  end

  local options = {
    'foldcolumn=0',
    'foldlevel=999',
    'norelativenumber',
    'nospell',
    'noswapfile',
  }

  -- Apply options to buffer
  vim.api.nvim_buf_call(buf, function()
    vim.cmd(('silent! noautocmd setlocal %s'):format(table.concat(options, ' ')))
  end)
end

-- Apply buffer options for text window
local function apply_text_buffer_options(buf, win)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  -- Use unique name with timestamp to avoid conflicts
  local timestamp = os.time()
  vim.api.nvim_buf_set_name(buf, 'GitGraph-Text-Dual-' .. timestamp)
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf }) -- ← самоочистка при закрытии вкладки

  -- Set window-local options
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_option_value('wrap', false, { win = win })
    vim.api.nvim_set_option_value('cursorline', true, { win = win })
    vim.api.nvim_set_option_value('winfixbuf', true, { win = win }) -- ← окно неподменяемо: gf/:edit сюда не влетит
  end

  local options = {
    'foldcolumn=0',
    'foldlevel=999',
    'norelativenumber',
    'nospell',
    'noswapfile',
  }

  -- Apply options to buffer
  vim.api.nvim_buf_call(buf, function()
    vim.cmd(('silent! noautocmd setlocal %s'):format(table.concat(options, ' ')))
  end)
end

-- Apply key mappings for both buffers
local function apply_dual_buffer_mappings(graph_buf, text_buf, graph_data, hooks)
  -- Function to get commit from current line
  local function get_current_commit()
    local current_win = vim.api.nvim_get_current_win()
    local row = vim.api.nvim_win_get_cursor(current_win)[1]
    return utils.get_commit_from_row(graph_data, row)
  end

  -- Function to get commit range from visual selection
  local function get_visual_commit_range()
    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]
    local to_commit = utils.get_commit_from_row(graph_data, start_row)
    local from_commit = utils.get_commit_from_row(graph_data, end_row)
    return from_commit, to_commit
  end

  -- Set up mappings for both buffers
  for _, buf in ipairs({ graph_buf, text_buf }) do
    vim.keymap.set('n', '<CR>', function()
      local commit = get_current_commit()
      if commit then
        hooks.on_select_commit(commit)
      end
    end, { buffer = buf, desc = 'select commit under cursor' })

    vim.keymap.set('v', '<CR>', function()
      vim.cmd('noau normal! "vy"')
      local from_commit, to_commit = get_visual_commit_range()
      if from_commit and to_commit then
        hooks.on_select_range_commit(from_commit, to_commit)
      end
    end, { buffer = buf, desc = 'select range of commits' })

    -- Add toggle for scroll synchronization
    vim.keymap.set('n', '<leader>gs', function()
      M.sync_scroll = not M.sync_scroll
      print('GitGraph scroll sync: ' .. (M.sync_scroll and 'ON' or 'OFF'))
    end, { buffer = buf, desc = 'toggle scroll synchronization' })

    -- Navigation shortcuts
    vim.keymap.set('n', '<Tab>', function()
      if vim.api.nvim_get_current_win() == M.graph_win and M.text_win and vim.api.nvim_win_is_valid(M.text_win) then
        vim.api.nvim_set_current_win(M.text_win)
      elseif vim.api.nvim_get_current_win() == M.text_win and M.graph_win and vim.api.nvim_win_is_valid(M.graph_win) then
        vim.api.nvim_set_current_win(M.graph_win)
      end
    end, { buffer = buf, desc = 'switch between graph and text windows' })

    -- Close dual-pane tab
    vim.keymap.set('n', 'q', function()
      vim.cmd('tabclose')
    end, { buffer = buf, desc = 'close dual-pane tab' })

    -- Refresh dual-pane
    vim.keymap.set('n', '<C-l>', function()
      M.refresh()
    end, { buffer = buf, desc = 'refresh dual-pane gitgraph' })
  end
end

-- Store last used parameters for refresh
M.last_config = nil
M.last_options = nil
M.last_args = nil

-- Refresh function for dual-pane mode
function M.refresh()
  if not M.last_config or not M.last_options or not M.last_args then
    print('GitGraph: No previous dual-pane session to refresh')
    return
  end

  -- Check if windows and buffers are still valid
  if not M.graph_win or not vim.api.nvim_win_is_valid(M.graph_win) or
      not M.text_win or not vim.api.nvim_win_is_valid(M.text_win) or
      not M.graph_buf or not vim.api.nvim_buf_is_valid(M.graph_buf) or
      not M.text_buf or not vim.api.nvim_buf_is_valid(M.text_buf) then
    print('GitGraph: Dual-pane windows/buffers are no longer valid')
    return
  end

  M.draw_content(M.last_config, M.last_options, M.last_args)
end

-- Helper function to draw content (separated from tab/window creation)
function M.draw_content(config, options, args)
  if utils.check_cmd('git --version') then
    log.error('git command not found, please install it')
    return
  end

  if utils.check_cmd('git status') then
    log.error('does not seem to be a valid git repo')
    return
  end

  -- Store parameters for refresh
  M.last_config = config
  M.last_options = options
  M.last_args = args

  -- Make buffers modifiable for editing
  vim.api.nvim_set_option_value('modifiable', true, { buf = M.graph_buf })
  vim.api.nvim_set_option_value('modifiable', true, { buf = M.text_buf })

  -- Clear both buffers
  vim.api.nvim_buf_set_lines(M.graph_buf, 0, -1, false, {})
  vim.api.nvim_buf_set_lines(M.text_buf, 0, -1, false, {})

  -- Clear highlights
  vim.api.nvim_buf_clear_namespace(M.graph_buf, -1, 0, -1)
  vim.api.nvim_buf_clear_namespace(M.text_buf, -1, 0, -1)

  -- Extract graph data using modified core function
  local graph, graph_lines, text_lines, graph_highlights, text_highlights, head_loc = core.gitgraph_dual(config,
    options, args)
  M.graph = graph -- Store for mappings compatibility

  -- Populate graph buffer
  vim.api.nvim_buf_set_lines(M.graph_buf, 0, #graph_lines, false, graph_lines)

  -- Populate text buffer
  vim.api.nvim_buf_set_lines(M.text_buf, 0, #text_lines, false, text_lines)

  -- Apply highlights asynchronously
  local function apply_highlights()
    vim.api.nvim_buf_clear_namespace(M.graph_buf, NS, 0, -1)
    vim.api.nvim_buf_clear_namespace(M.text_buf, NS, 0, -1)
    -- Graph highlights
    for _, hl in ipairs(graph_highlights) do
      if hl.start and hl.stop and hl.start >= 0 and hl.stop >= hl.start then
        vim.hl.range(
          M.graph_buf,
          NS,
          hl.hg,
          { hl.row - 1, hl.start },
          { hl.row - 1, hl.stop }
        )
      end
    end

    -- Text highlights
    for _, hl in ipairs(text_highlights) do
      if hl.start and hl.stop and hl.start >= 0 and hl.stop >= hl.start then
        vim.hl.range(
          M.text_buf,
          NS,
          hl.hg,
          { hl.row - 1, hl.start },
          { hl.row - 1, hl.stop }
        )
      end
    end
  end

  local co = coroutine.create(apply_highlights)

  local function wait_poll()
    if coroutine.status(co) ~= 'dead' then
      coroutine.resume(co)
      vim.defer_fn(wait_poll, 16) -- Adjust delay as needed
    end
  end

  vim.defer_fn(wait_poll, 1)

  -- Set cursor position to head location
  local cursor_line = head_loc or 1
  if M.graph_win and vim.api.nvim_win_is_valid(M.graph_win) then
    vim.api.nvim_win_set_cursor(M.graph_win, { cursor_line, 0 })
  end
  if M.text_win and vim.api.nvim_win_is_valid(M.text_win) then
    vim.api.nvim_win_set_cursor(M.text_win, { cursor_line, 0 })
  end

  -- Apply buffer options
  apply_graph_buffer_options(M.graph_buf, M.graph_win)
  apply_text_buffer_options(M.text_buf, M.text_win)

  -- Set focus to graph window
  if M.graph_win and vim.api.nvim_win_is_valid(M.graph_win) then
    vim.api.nvim_set_current_win(M.graph_win)
  end
end

---@param config I.GGConfig
---@param options I.DrawOptions
---@param args I.GitLogArgs
function M.draw(config, options, args)
  -- Open in new tab for dual-pane mode
  vim.cmd('tabnew')
  local leftover = vim.api.nvim_get_current_buf() -- пустой [No Name] от tabnew

  -- Create new buffers for this tab
  M.graph_buf = vim.api.nvim_create_buf(false, true)
  M.text_buf = vim.api.nvim_create_buf(false, true)

  -- Create vertical split layout
  vim.cmd('vsplit')

  -- Set up graph window (left)
  M.graph_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.graph_win, M.graph_buf)

  -- Set up text window (right)
  vim.cmd('wincmd l')
  M.text_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(M.text_win, M.text_buf)

  -- ← добить осиротевший буфер от tabnew (больше не показан ни в одном окне)
  if vim.api.nvim_buf_is_valid(leftover)
      and leftover ~= M.graph_buf and leftover ~= M.text_buf
      and vim.api.nvim_buf_get_name(leftover) == '' then
    pcall(vim.api.nvim_buf_delete, leftover, { force = true })
  end

  -- Draw content using helper function
  M.draw_content(config, options, args)

  -- Apply mappings
  apply_dual_buffer_mappings(M.graph_buf, M.text_buf, M.graph, config.hooks)

  -- Set up scroll synchronization
  setup_scroll_sync()
end

return M
