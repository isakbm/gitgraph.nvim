# gitgraph.nvim

> NOTE: this project is still very WIP and there is no help documentation other that this README.md for now.

Git Graph plugin for neovim.

# Goals

- 100% lua
- temporal topological order
- branches stick to their lane
- easy to follow branch crossings 
- easy to spot merge commits and branch children
- compatible with sindrets.diffview
- easily configurable date formats
- easily configurable highlight groups

# Usage

> Note that this is still very early days and things may rapidly change in the beginning


```lua
  {
    'isakbm/gitgraph.nvim',
    dependencies = { 'sindrets/diffview.nvim' },
    ---@type I.GGConfig
    opts = {
      symbols = {
        merge_commit = 'M',
        commit = '*',
      },
      format = {
        timestamp = '%H:%M:%S %d-%m-%Y',
        fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
      },
    },
    init = function()
      vim.keymap.set('n', '<leader>gl', function()
        require('gitgraph').draw({}, { all = true, max_count = 5000 })
      end, { desc = 'new git graph' })
    end,
  },

```

# Keymaps

When in the git graph buffer you can open diffview on the commit under the cursor with `Enter`.

... morekeymaps to come

# Highlights 

## information

  - 'GitGraphHash'
  - 'GitGraphTimestamp'
  - 'GitGraphAuthor'
  - 'GitGraphBranchName'
  - 'GitGraphBranchTag'
  - 'GitGraphBranchMsg'

## branch highlights

  - 'GitGraphBranch1' 
  - 'GitGraphBranch2' 
  - 'GitGraphBranch3' 
  - 'GitGraphBranch4' 
  - 'GitGraphBranch5' 

