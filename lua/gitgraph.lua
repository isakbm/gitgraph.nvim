local log = require('gitgraph.log')
local config = require('gitgraph.config')
local highlights = require('gitgraph.highlights')

local M = {
  config = config.defaults,

  buf = nil, ---@type integer?
  graph = {}, ---@type I.Row[]
}

--- Setup
---@param user_config I.GGConfig
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config)

  highlights.set_highlights()

  math.randomseed(os.time())

  log.set_level(M.config.log_level)
end

--- Draws the gitgraph in buffer
---@param options I.DrawOptions
---@param args I.GitLogArgs
---@return nil
function M.draw(options, args)
  return require('gitgraph.draw').draw(M.config, options, args)
end

--- Tests the gitgraph plugin
---@return string[]
---@return boolean
function M.test()
  return require('gitgraph.tests').run_tests(M.config.symbols, M.config.format.fields)
end

--- Draws a random gitgraph
function M.random()
  return require('gitgraph.tests').run_random(M.config.symbols, M.config.format.fields)
end

return M
