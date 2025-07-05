-- Simple test for GitGraph dual-pane functionality
local M = {}

function M.test_dual()
  print("Testing GitGraph dual-pane...")

  -- Check if we're in a git repo
  local utils = require('gitgraph.utils')
  if utils.check_cmd('git status') then
    print("ERROR: Not in a git repository")
    return false
  end

  -- Try to call the dual-pane function
  local ok, err = pcall(function()
    require('gitgraph').draw_dual({}, { all = true, max_count = 10 })
  end)

  if ok then
    print("✓ GitGraph dual-pane test PASSED")
    return true
  else
    print("✗ GitGraph dual-pane test FAILED:", err)
    return false
  end
end

-- Create test command
vim.api.nvim_create_user_command('GitGraphTest', M.test_dual, {
  desc = 'Test GitGraph dual-pane functionality'
})

return M
