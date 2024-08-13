local log = require('gitgraph.log')
local helper = require('gitgraph.helpers')
local core = require('gitgraph.core')

local BRANCH_HGS = require('gitgraph.highlights').BRANCH_HGS
local ITEM_HGS = require('gitgraph.highlights').ITEM_HGS

---@class I.Highlight
---@field hg string -- NOTE: fine to use string since lua internalizes strings
---@field row integer
---@field start integer
---@field stop integer

---@class I.GGSymbols
---@field merge_commit? string
---@field commit? string
---@field merge_commit_end? string
---@field commit_end? string
---@field GVER? string
---@field GHOR? string
---@field GCLD? string
---@field GCRD? string
---@field GCLU? string
---@field GCRU? string
---@field GLRU? string
---@field GLRD? string
---@field GLUD? string
---@field GRUD? string
---@field GFORKU? string
---@field GFORKD? string
---@field GRUDCD? string
---@field GRUDCU? string
---@field GLUDCD? string
---@field GLUDCU? string
---@field GLRDCL? string
---@field GLRDCR? string
---@field GLRUCL? string
---@field GLRUCR? string

---@alias I.GGVarName "hash" | "timestamp" | "author" | "branch_name" | "tag" | "message"

---@class I.GGFormat
---@field timestamp? string
---@field fields? I.GGVarName[]

---@class I.Hooks
---@field on_select_commit fun(commit: I.Commit)
---@field on_select_range_commit fun(from: I.Commit, to: I.Commit)

---@class I.GGConfig
---@field symbols? I.GGSymbols
---@field format? I.GGFormat
---@field hooks? I.Hooks
---@field log_level? integer

---@class I.HighlightGroup
---@field name string
---@field fg string
---
local M = {
  ---@type I.GGConfig
  config = {
    symbols = {
      merge_commit = 'M',
      commit = '*',
      merge_commit_end = 'M',
      commit_end = '*',

      -- Advanced symbols
      GVER = '│',
      GHOR = '─',
      GCLD = '╮',
      GCRD = '╭',
      GCLU = '╯',
      GCRU = '╰',
      GLRU = '┴',
      GLRD = '┬',
      GLUD = '┤',
      GRUD = '├',
      GFORKU = '┼',
      GFORKD = '┼',
      GRUDCD = '├',
      GRUDCU = '├',
      GLUDCD = '┤',
      GLUDCU = '┤',
      GLRDCL = '┬',
      GLRDCR = '┬',
      GLRUCL = '┴',
      GLRUCR = '┴',
    },
    hooks = {
      on_select_commit = function(commit)
        log.info('selected commit:', commit.hash)
      end,
      on_select_range_commit = function(from, to)
        log.info('selected range:', from.hash, to.hash)
      end,
    },
    format = {
      timestamp = '%H:%M:%S %d-%m-%Y',
      fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
    },
    log_level = vim.log.levels.ERROR,
  },
  ---@type integer?
  buf = nil,
  ---@type I.Row[]
  graph = {},
}

function M.setup(config)
  M.config = vim.tbl_deep_extend('force', M.config, config)

  local function set_hl(name, highlight)
    local existing_hg = vim.api.nvim_get_hl(0, { name = name })
    if #existing_hg == 0 then
      vim.api.nvim_set_hl(0, name, vim.tbl_deep_extend('force', highlight, { default = true }))
    end
  end

  for _, hg in pairs(BRANCH_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end

  for _, hg in pairs(ITEM_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end

  -- used for random graph testing
  math.randomseed(os.time())

  -- set log level
  log.set_level(M.config.log_level)
end

---@param options I.DrawOptions
---@param args I.GitLogArgs
function M.draw(options, args)
  M.graph = {}

  local so = os.clock()

  if helper.check_cmd('git --version') then
    log.error('git command not found, please install it')
    return
  end

  if helper.check_cmd('git status') then
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

  -- make modifiable
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

  -- unlisted
  vim.api.nvim_set_option_value('buflisted', false, { buf = buf })

  -- turn off linewrap
  vim.api.nvim_set_option_value('wrap', false, { scope = 'local' })

  -- clear highlights
  vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)

  -- clear
  do
    local cl_start = os.clock()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    local clear_dur = os.clock() - cl_start
    log.info('clear dur', clear_dur * 1000, 'ms')
  end

  -- extract graph data
  local lines, highlights, head_loc = M.gitgraph(options, args)

  local start = os.clock()
  -- put graph data in buffer
  do
    -- text
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)

    local function high()
      for _, hl in ipairs(highlights) do
        local offset = 1
        vim.api.nvim_buf_add_highlight(buf, -1, hl.hg, hl.row - 1, hl.start - 1 + offset, hl.stop + offset)
      end
    end

    -- highlights
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

  helper.apply_buffer_options(buf)
  helper.apply_buffer_mappings(buf, M.graph, M.config.hooks)
  local dur = os.clock() - start
  log.info('rest dur:', dur * 1000, 'ms')

  local tot_dur = os.clock() - so
  log.info('total dur:', tot_dur * 1000, 'ms')
end

---@class I.GitLogArgs
---@field all? boolean
---@field revision_range? string
---@field max_count? integer
---@field skip? integer

---@class I.RawCommit
---@field hash string
---@field parents string[]
---@field msg string
---@field branch_names string[]
---@field tags string[]
---@field author_date string
---@field author_name string
---

---@param options I.DrawOptions
---@param args I.GitLogArgs
---@return string[]
---@return I.Highlight[]
---@return integer?
function M.gitgraph(options, args)
  --- depends on `git`
  local data = require('gitgraph.git').git_log_pretty(args, M.config.format.timestamp)

  --- does the magic
  local start = os.clock()
  local graph, lines, highlights, head_loc = core._gitgraph(data, options, M.config.symbols, M.config.format.fields)
  M.graph = graph
  local dur = os.clock() - start
  log.info('_gitgraph dur:', dur * 1000, 'ms')

  return lines, highlights, head_loc
end

---@return string[]
---@return boolean
function M.test()
  return require('gitgraph.tests').run_tests(M.config.symbols, M.config.format.fields)
end

function M.random()
  return require('gitgraph.tests').run_random(M.config.symbols, M.config.format.fields)
end

return M
