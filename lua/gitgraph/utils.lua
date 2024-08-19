local M = {}

---@param next I.Commit
---@param prev_commit_row I.Row
---@param prev_connector_row I.Row
---@param commit_row I.Row
---@param connector_row I.Row
function M.resolve_bi_crossing(prev_commit_row, prev_connector_row, commit_row, connector_row, next)
  -- if false then
  -- if false then -- get_is_bi_crossing(graph, next_commit, #graph) then
  -- print 'we have a bi crossing'
  -- void all repeated reservations of `next` from
  -- this and the previous row
  local prev_row = commit_row
  local this_row = connector_row
  assert(prev_row and this_row, 'expecting two prior rows due to bi-connector')

  --- example of what this does
  ---
  --- input:
  ---
  ---   j i i          │ │ │
  ---   j i i          ⓮ │ │     <- prev
  ---   g i i h        ⓸─⓵─ⓥ─╮   <- bi connector
  ---
  --- output:
  ---
  ---   j i i          │ ⓶─╯
  ---   j i            ⓮ │       <- prev
  ---   g i   h        ⓸─│───╮   <- bi connector
  ---
  ---@param row I.Row
  ---@return integer
  local function void_repeats(row)
    local start_voiding = false
    local ctr = 0
    for k, cell in ipairs(row.cells) do
      if cell.commit and cell.commit.hash == next.hash then
        if not start_voiding then
          start_voiding = true
        elseif not row.cells[k].emphasis then
          -- else

          row.cells[k] = { connector = ' ' } -- void it
          ctr = ctr + 1
        end
      end
    end
    return ctr
  end

  void_repeats(prev_row)
  void_repeats(this_row)

  -- we must also take care when the prev prev has a repeat where
  -- the repeat is not the direct parent of its child
  --
  --   G                        ⓯
  --   e d c                    ⓸─ⓢ─╮
  --   E D C F                  │ │ │ ⓯
  --   e D C c b a d            ⓶─⓵─│─⓴─ⓢ─ⓢ─? <--- to resolve this
  --   E D C C B A              ⓮ │ │ │ │ │
  --   c D C C b A              ⓸─│─ⓥ─ⓥ─⓷ │
  --   C D     B A              │ ⓮     │ │
  --   C c     b a              ⓶─ⓥ─────⓵─⓷
  --   C       B A              ⓮       │ │
  --   b       B a              ⓸───────ⓥ─⓷
  --   B         A              ⓚ         │
  --   a         A              ⓶─────────╯
  --   A                        ⓚ
  local prev_prev_row = prev_connector_row -- graph[#graph - 2]
  local prev_prev_prev_row = prev_commit_row -- graph[#graph - 3]
  assert(prev_prev_row and prev_prev_prev_row)
  do
    local start_voiding = false
    local ctr = 0
    ---@type I.Cell?
    local replacer = nil
    for k, cell in ipairs(prev_prev_row.cells) do
      if cell.commit and cell.commit.hash == next.hash then
        if not start_voiding then
          start_voiding = true
          replacer = cell
        elseif k ~= prev_prev_prev_row.commit.j then
          local ppcell = prev_prev_prev_row.cells[k]
          if (not ppcell) or (ppcell and ppcell.connector == ' ') then
            prev_prev_row.cells[k] = { connector = ' ' } -- void it
            replacer.emphasis = true
            ctr = ctr + 1
          end
        end
      end
    end
  end

  -- assert(prev_rep_ctr == this_rep_ctr)

  -- newly introduced tracking cells can be squeezed in
  --
  -- before:
  --
  --   j i i          │ ⓶─╯
  --   j i            ⓮ │
  --   g i   h        ⓸─│───╮
  --
  -- after:
  --
  --   j i i          │ ⓶─╯
  --   j i            ⓮ │
  --   g i h          ⓸─│─╮
  --
  -- can think of this as scooting the cell to the left
  -- when the cell was just introduced
  -- TODO: implement this at some point
  -- for k, cell in ipairs(this_row.cells) do
  --   if cell.commit and not prev_row.cells[k].commit and not this_row.cells[k - 2] then
  --   end
  -- end
end

-- heuristic to check if this row contains a "bi-crossing" of branches
--
-- a bi-crossing is when we have more than one branch "propagating" horizontally
-- on a connector row
--
-- this can only happen when the commit on the row
-- above the connector row is a merge commit
-- but it doesn't always happen
--
-- in addition to needing a merge commit on the row above
-- we need the span (interval) of the "emphasized" connector cells
-- (they correspond to connectors to the parents of the merge commit)
-- we need that span to overlap with at least one connector cell that
-- is destined for the commit on the next row
-- (the commit before the merge commit)
-- in addition, we need there to be more than one connector cell
-- destined to the next commit
--
-- here is an example
--
--
--   j i i          ⓮ │ │   j -> g h
--   g i i h        ?─?─?─╮
--   g i   h        │ ⓚ   │ i
--
--
-- overlap:
--
--   g-----h 1 4
--     i-i   2 3
--
-- NOTE how `i` is the commit that the `i` cells are destined for
--      notice how there is more than on `i` in the connector row
--      and that it lies in the span of g-h
--
-- some more examples
--
-- -------------------------------------
--
--   S T S          │ ⓮ │ T -> R S
--   S R S          ?─?─?
--   S R            ⓚ │   S
--
--
-- overlap:
--
--   S-R    1 2
--   S---S  1 3
--
-- -------------------------------------
--
--
--   c b a b        ⓮ │ │ │ c -> Z a
--   Z b a b        ?─?─?─?
--   Z b a          │ ⓚ │   b
--
-- overlap:
--
--   Z---a    1 3
--     b---b  2 4
--
-- -------------------------------------
--
-- finally a negative example where there is no problem
--
--
--   W V V          ⓮ │ │ W -> S V
--   S V V          ⓸─⓵─╯
--   S V            │ ⓚ   V
--
-- no overlap:
--
--   S-V    1 2
--     V-V  2 3
--
-- the reason why there is no problem (bi-crossing) above
-- follows from the fact that the span from V <- V only
-- touches the span S -> V it does not overlap it, so
-- figuratively we have S -> V <- V which is fine
--
-- TODO:
-- FIXME: need to test if we handle two bi-connectors in succession
--        correctly
--
---@param commit_row I.Row
---@param connector_row I.Row
---@param next_commit I.Commit?
---@return boolean -- whether or not this is a bi crossing
---@return boolean -- whether or not it can be resolved safely by edge lifting
function M.get_is_bi_crossing(commit_row, connector_row, next_commit)
  if not next_commit then
    return false, false
  end

  local prev = commit_row.commit
  assert(prev, 'expected a prev commit')

  if #prev.parents < 2 then
    return false, false -- bi-crossings only happen when prev is a merge commit
  end

  local row = connector_row

  ---@param k integer
  local function interval_upd(x, k)
    if k < x.start then
      x.start = k
    end
    if k > x.stop then
      x.stop = k
    end
  end

  -- compute the emphasized interval (merge commit parent interval)
  local emi = { start = #row.cells, stop = 1 }
  for k, cell in ipairs(row.cells) do
    if cell.commit and cell.emphasis then
      interval_upd(emi, k)
    end
  end

  -- compute connector interval
  local coi = { start = #row.cells, stop = 1 }
  for k, cell in ipairs(row.cells) do
    if cell.commit and cell.commit.hash == next_commit.hash then
      interval_upd(coi, k)
    end
  end

  -- unsafe if starts of intervals overlap and are equal to direct parent location
  local safe = not (emi.start == coi.start and prev.j == emi.start)

  -- return earily when connector interval is trivial
  if coi.start == coi.stop then
    return false, safe
  end

  -- print('emi:', vim.inspect(emi))
  -- print('coi:', vim.inspect(coi))

  -- check overlap
  do
    -- are intervals identical, then that counts as overlap
    if coi.start == emi.start and coi.stop == emi.stop then
      return true, safe
    end
  end
  for _, k in pairs(emi) do
    -- emi endpoints inside coi ?
    if coi.start < k and k < coi.stop then
      return true, safe
    end
  end
  for _, k in pairs(coi) do
    -- coi endpoints inside emi ?
    if emi.start < k and k < emi.stop then
      return true, safe
    end
  end

  return false, safe
end

---@param graph I.Row[]
---@param r integer
function M.get_commit_from_row(graph, r)
  -- trick to map both the commit row and the message row to the provided commit
  local row = 2 * (math.floor((r - 1) / 2)) + 1 -- 1 1 3 3 5 5 7 7
  local commit = graph[row].commit
  return commit
end

function M.apply_buffer_options(buf)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf })
  vim.cmd('set filetype=gitgraph')
  vim.api.nvim_buf_set_name(buf, 'GitGraph')

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
function M.apply_buffer_mappings(buf_id, graph, hooks)
  vim.keymap.set('n', '<CR>', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local commit = M.get_commit_from_row(graph, row)
    if commit then
      hooks.on_select_commit(commit)
    end
  end, { buffer = buf_id, desc = 'select commit under cursor' })

  vim.keymap.set('v', '<CR>', function()
    -- make sure visual selection is done
    vim.cmd('noau normal! "vy"')

    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]

    local to_commit = M.get_commit_from_row(graph, start_row)
    local from_commit = M.get_commit_from_row(graph, end_row)

    if from_commit and to_commit then
      hooks.on_select_range_commit(from_commit, to_commit)
    end
  end, { buffer = buf_id, desc = 'select range of commit' })
end

---@param cmd string
---@return boolean -- true if failure (exit code ~= 0) false otherwise (exit code == 0)
--- note that this method was sadly neede since there's some strange bug with lua's handle:close?
--- it doesn't get the exit code correctly by itself?
function M.check_cmd(cmd)
  local is_windows = package.config:sub(1, 1) == '\\'
  local final_cmd = cmd

  if is_windows then
    final_cmd = final_cmd .. ' && echo 0 || echo 1'
  else
    final_cmd = final_cmd .. ' 2>&1; echo $?'
  end

  local res = io.popen(final_cmd)
  if not res then
    return true
  end

  local output, last_line = {}, '1'
  for line in res:lines() do
    table.insert(output, line)
  end
  last_line = output[#output] -- in both cases, the last line contains the exit status

  res:close()

  return vim.trim(last_line or '') ~= '0'
end

return M
