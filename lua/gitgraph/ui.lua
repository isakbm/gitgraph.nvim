-- by maarutan ❤️
-- https://github.com/maarutan
-- 2025-11-07
---------------------------------------

local M = {}
local state = { buf = nil, win = nil }

function M.open(lines, highlights, cfg)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.update(state.buf, lines, highlights)
    vim.api.nvim_set_current_win(state.win)
    return state.buf, state.win
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'gitgraph'
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = true

  local win
  if cfg.layout == 'float' then
    local width = cfg.width <= 1 and math.floor(vim.o.columns * cfg.width) or cfg.width
    local height = cfg.height <= 1 and math.floor(vim.o.lines * cfg.height) or cfg.height

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)
    win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = cfg.border or 'single',
    })
  elseif cfg.layout == 'split' then
    vim.cmd('split')
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  elseif cfg.layout == 'vsplit' then
    vim.cmd('vsplit')
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  elseif cfg.layout == 'full' then
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  else
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  end

  pcall(vim.api.nvim_win_set_option, win, 'number', false)
  pcall(vim.api.nvim_win_set_option, win, 'relativenumber', false)
  pcall(vim.api.nvim_win_set_option, win, 'wrap', false)
  pcall(vim.api.nvim_win_set_var, win, 'cinnamon_ignore', true)
  pcall(function()
    vim.b[buf].cinnamon_no_scroll = true
  end)

  if cfg.close then
    vim.keymap.set('n', cfg.close, function()
      if not vim.api.nvim_win_is_valid(win) then
        state.buf, state.win = nil, nil
        return
      end
      if cfg.layout == 'full' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      else
        local wins = vim.api.nvim_list_wins()
        if #wins <= 1 then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        else
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
      state.buf, state.win = nil, nil
    end, { buffer = buf, nowait = true })
  end

  if lines and #lines > 0 then
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end

  if highlights then
    for _, hl in ipairs(highlights) do
      pcall(vim.api.nvim_buf_add_highlight, buf, -1, hl.hg, hl.row - 1, hl.start, hl.stop)
    end
  end

  state.buf, state.win = buf, win
  return buf, win
end

function M.update(buf, lines, highlights)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local prev_modifiable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
  if highlights then
    for _, hl in ipairs(highlights) do
      pcall(vim.api.nvim_buf_add_highlight, buf, -1, hl.hg, hl.row - 1, hl.start, hl.stop)
    end
  end
  vim.bo[buf].modifiable = prev_modifiable
end

return M
