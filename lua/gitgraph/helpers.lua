local helper = {}

---@param graph I.Row[]
---@param r integer
local get_commit_from_row = function(graph, r)
  -- trick to map both the commit row and the message row to the provided commit
  local row = 2 * (math.floor((r - 1) / 2)) + 1 -- 1 1 3 3 5 5 7 7
  local commit = graph[row].commit
  return commit
end

helper.apply_buffer_options = function(buf_id)
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
helper.apply_buffer_mappings = function(buf_id, graph, hooks)
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

return helper
