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
      hooks = {
        on_select_commit = function(commit)
          print('selected commit:', commit.hash)
        end,
        on_select_range_commit = function(from, to)
          print('selected range:', from.hash, to.hash)
        end,
      },
    },
    keys = {
      {
        "<leader>gl",
        function()
          require('gitgraph').draw({}, { all = true, max_count = 5000 })
        end,
        desc = "GitGraph - Draw",
      },
    },
  },

```

## View commit with [Diffview.nvim](https://github.com/sindrets/diffview.nvim)

When in the git graph buffer you can open `Diffview` on the commit under the cursor with `Enter`.
or for **multiple** commit if on `visual mode`
```lua
  {
    'isakbm/gitgraph.nvim',
    dependencies = { 'sindrets/diffview.nvim' },
    ---@type I.GGConfig
    opts = {
      hooks = {
        -- Check diff of a commit
        on_select_commit = function(commit)
          vim.notify('DiffviewOpen ' .. commit.hash .. '^!')
          vim.cmd(':DiffviewOpen ' .. commit.hash .. '^!')
        end,
        -- Check diff from commit a -> commit b
        on_select_range_commit = function(from, to)
          vim.notify('DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
          vim.cmd(':DiffviewOpen ' .. from.hash .. '~1..' .. to.hash)
        end,
      },
    },
  },
```

## Use custom symbols to drawl graph
For example, use **kitty** drawl branch symbols [more detail](https://github.com/kovidgoyal/kitty/pull/7681)
```lua
  symbols = {
    merge_commit = '',
    commit = '',
    merge_commit_end = '',
    commit_end = '',

    -- Advanced symbols
    GVER = '',
    GHOR = '',
    GCLD = '',
    GCRD = '╭',
    GCLU = '',
    GCRU = '',
    GLRU = '',
    GLRD = '',
    GLUD = '',
    GRUD = '',
    GFORKU = '',
    GFORKD = '',
    GRUDCD = '',
    GRUDCU = '',
    GLUDCD = '',
    GLUDCU = '',
    GLRDCL = '',
    GLRDCR = '',
    GLRUCL = '',
    GLRUCR = '',
  },
```

# Keymaps

... more keymaps to come ... 

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

