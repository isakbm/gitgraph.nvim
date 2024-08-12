local M = {}

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

return M
