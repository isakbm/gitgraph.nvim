local M = {}

---@class I.HighlightGroup
---@field name string
---@field fg string

---@type table<string, I.HighlightGroup>
M.ITEM_HGS = {
  hash = { name = 'GitGraphHash', fg = '#b16286' },
  timestamp = { name = 'GitGraphTimestamp', fg = '#98971a' },
  author = { name = 'GitGraphAuthor', fg = '#458588' },
  branch_name = { name = 'GitGraphBranchName', fg = '#d5651c' },
  tag = { name = 'GitGraphBranchTag', fg = '#d79921' },
  message = { name = 'GitGraphBranchMsg', fg = '#339921' },
}

---@type I.HighlightGroup[]
M.BRANCH_HGS = {
  { name = 'GitGraphBranch1', fg = '#458588' },
  { name = 'GitGraphBranch2', fg = '#b16286' },
  { name = 'GitGraphBranch3', fg = '#d79921' },
  { name = 'GitGraphBranch4', fg = '#98971a' },
  { name = 'GitGraphBranch5', fg = '#d5651c' },
}

--- sets highlight groups if they are missing
function M.set_highlights()
  local function set_hl(name, highlight)
    local existing_hg = vim.api.nvim_get_hl(0, { name = name })
    if #existing_hg == 0 then
      vim.api.nvim_set_hl(0, name, vim.tbl_deep_extend('force', highlight, { default = true }))
    end
  end

  for _, hg in pairs(M.BRANCH_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end

  for _, hg in pairs(M.ITEM_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end
end

return M
