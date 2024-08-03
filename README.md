# gitgraph.nvim

Git Graph plugin for neovim.

> NOTE: this project is still very WIP and there is no help documentation aside from this README.md.

# Screenshots

![image](https://github.com/user-attachments/assets/cecc231a-07ac-4557-bbca-9da438b4379b)

<img width="572" alt="image" src="https://github.com/user-attachments/assets/c38aa5a5-274c-41b7-b552-7464f1331708">

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

... moreke ymaps to come ... 

# Highlights Groups

## commit information

  - 'GitGraphHash'
  - 'GitGraphTimestamp'
  - 'GitGraphAuthor'
  - 'GitGraphBranchName'
  - 'GitGraphBranchTag'
  - 'GitGraphBranchMsg'

## branch colors

  - 'GitGraphBranch1' 
  - 'GitGraphBranch2' 
  - 'GitGraphBranch3' 
  - 'GitGraphBranch4' 
  - 'GitGraphBranch5' 

