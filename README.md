# gitgraph.nvim

Git Graph plugin for neovim.

> NOTE: this project is still very WIP and there is no help documentation aside from this README.md.

# Roadmap - Goals

### Completed

- ✔️ 100% lua
- ✔️ temporal topological order
- ✔️ branches stick to their lane
- ✔️ easy to spot merge commits and branch children
- ✔️ hooks for easy extension with [diffview.nvim](https://github.com/sindrets/diffview.nvim) etc
- ✔️ easily configurable date formats
- ✔️ easily configurable highlight groups
- ✔️ performant scrolling
- ✔️ easy to follow branch crossings

### Future

- auto updating graph
- performant load times for large repos

# Screenshots

<img width="42%" alt="image" src="https://github.com/user-attachments/assets/cecc231a-07ac-4557-bbca-9da438b4379b">
<img width="42%" alt="image" src="https://github.com/user-attachments/assets/c38aa5a5-274c-41b7-b552-7464f1331708">

# Usage

> Note that this is still very early days and things may rapidly change in the beginning

```lua
  {
    'isakbm/gitgraph.nvim',
    event = "VeryLazy",
    opts = {
      git_cmd = "git",

      window = {
        layout = "float", -- float || split || vsplit || full
        -- if layout is float
        width = 0.8, -- screen share or number of columns
        height = 0.8, -- screen share or number of lines

        close = "q", -- if current buffer is gitgraph, close it
        border = "rounded", -- single || double || rounded || none
      },

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
	keys = { { "<leader>gl", "<cmd>GitGraph<cr>", desc = "GitGraph - Toggle" } },
  },

```

## View commit with [Diffview.nvim](https://github.com/sindrets/diffview.nvim)

When in the git graph buffer you can open `Diffview` on the commit under the cursor with `Enter`.

When in visual mode you get the `Diffview` for the selected range.

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

## Use custom symbols

For example, use **kitty** branch symbols [more detail](https://github.com/kovidgoyal/kitty/pull/7681)

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
