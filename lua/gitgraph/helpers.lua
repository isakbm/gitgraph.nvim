local helper = {}

---@param graph I.Row[]
---@param r integer
local function get_commit_from_row(graph, r)
  -- trick to map both the commit row and the message row to the provided commit
  local row = 2 * (math.floor((r - 1) / 2)) + 1 -- 1 1 3 3 5 5 7 7
  local commit = graph[row].commit
  return commit
end

function helper.apply_buffer_options(buf_id)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.cmd('set filetype=gitgraph')
  vim.api.nvim_buf_set_name(buf_id, 'GitGraph')

  local options = {
    'foldcolumn=0',
    'foldlevel=999',
    'norelativenumber',
    'nospell',
    'noswapfile',
  }
  -- Vim's `setlocal` is currently more robust compared to `opt_local`
  vim.cmd(('silent! noautocmd setlocal %s'):format(table.concat(options, ' ')))
end

---@param buf_id integer
---@param graph I.Row[]
---@param hooks I.Hooks
function helper.apply_buffer_mappings(buf_id, graph, hooks)
  vim.keymap.set('n', '<CR>', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local commit = get_commit_from_row(graph, row)
    if commit then
      hooks.on_select_commit(commit)
    end
  end, { buffer = buf_id, desc = 'select commit under cursor' })

  vim.keymap.set('v', '<CR>', function()
    -- make sure visual selection is done
    vim.cmd('noau normal! "vy"')

    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]

    local to_commit = get_commit_from_row(graph, start_row)
    local from_commit = get_commit_from_row(graph, end_row)

    if from_commit and to_commit then
      hooks.on_select_range_commit(from_commit, to_commit)
    end
  end, { buffer = buf_id, desc = 'select range of commit' })
end

---@param cmd string
---@return boolean -- true if failure (exit code ~= 0) false otherwise (exit code == 0)
--- note that this method was sadly neede since there's some strange bug with lua's handle:close?
--- it doesn't get the exit code correctly by itself?
function helper.check_cmd(cmd)
  local res = io.popen(cmd .. ' 2>&1; echo $?')
  if not res then
    return true
  end
  local last_line = '1'
  for line in res:lines() do
    last_line = line
  end
  res:close()
  return last_line ~= '0'
end

return helper
