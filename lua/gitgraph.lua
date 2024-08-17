local log = require('gitgraph.log')
local config = require('gitgraph.config')

local BRANCH_HGS = require('gitgraph.highlights').BRANCH_HGS
local ITEM_HGS = require('gitgraph.highlights').ITEM_HGS

---@class I.Highlight
---@field hg string -- NOTE: fine to use string since lua internalizes strings
---@field row integer
---@field start integer
---@field stop integer

local M = {
  config = config.defaults,

  buf = nil, ---@type integer?
  graph = {}, ---@type I.Row[]
}

--- Setup
---@param user_config I.GGConfig
function M.setup(user_config)
  M.config = vim.tbl_deep_extend('force', M.config, user_config)

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
