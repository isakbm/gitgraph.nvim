local log = require('gitgraph.log')

---@class I.GGSymbols
---@field merge_commit string
---@field commit string
---@field merge_commit_end string
---@field commit_end string
---@field GVER string
---@field GHOR string
---@field GCLD string
---@field GCRD string
---@field GCLU string
---@field GCRU string
---@field GLRU string
---@field GLRD string
---@field GLUD string
---@field GRUD string
---@field GFORKU string
---@field GFORKD string
---@field GRUDCD string
---@field GRUDCU string
---@field GLUDCD string
---@field GLUDCU string
---@field GLRDCL string
---@field GLRDCR string
---@field GLRUCL string
---@field GLRUCR string

---@alias I.GGVarName "hash" | "timestamp" | "author" | "branch_name" | "tag" | "message"

---@class I.GGFormat
---@field timestamp string
---@field fields I.GGVarName[]

---@class I.Hooks
---@field on_select_commit fun(commit: I.Commit)
---@field on_select_range_commit fun(from: I.Commit, to: I.Commit)

---@class I.GGConfig
---@field symbols I.GGSymbols
---@field format I.GGFormat
---@field hooks I.Hooks
---@field log_level integer

local M = {}

---@type I.GGConfig
M.defaults = {
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
}

return M
