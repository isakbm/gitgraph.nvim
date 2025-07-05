# GitGraph Dual-Pane Mode

GitGraph dual-pane mode provides a split-screen interface for viewing Git commit graphs with synchronized scrolling.

## Features

- **Split-screen layout**: Graph visualization in left pane, commit details in right pane
- **Synchronized vertical scrolling**: Both panes scroll together vertically
- **Independent horizontal scrolling**: Each pane can scroll horizontally independently
- **Window switching**: Use `<Tab>` to switch between panes
- **Scroll sync toggle**: Use `<leader>gs` to enable/disable scroll synchronization

## Usage

### Command

```vim
:GitGraphDual [args]
```

### Programmatic Usage

```lua
-- Basic usage
require('gitgraph').draw_dual({}, { all = true, max_count = 5000 })

-- With options
require('gitgraph').draw_dual({}, {
    all = true,
    max_count = 1000,
    revision_range = "HEAD~10..HEAD"
})
```

### Plugin Configuration

Add this to your plugin configuration to automatically register the `GitGraphDual` command:

```lua
return {
    {
        'isakbm/gitgraph.nvim',
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
                "<leader>gph",
                function()
                    require('gitgraph').draw({}, { all = true, max_count = 5000 })
                end,
                desc = "GitGraph - Single Pane",
            },
            {
                "<leader>gpd",
                function()
                    require('gitgraph').draw_dual({}, { all = true, max_count = 5000 })
                end,
                desc = "GitGraph - Dual Pane",
            },
        },
    }
}
```

## Keybindings

| Key | Action |
|-----|--------|
| `<CR>` | Select commit under cursor |
| `<Tab>` | Switch between graph and text panes |
| `<leader>gs` | Toggle scroll synchronization |
| `j/k` | Navigate up/down (synchronized) |
| `h/l` | Horizontal scroll (independent per pane) |
| `v + <CR>` | Select commit range (visual mode) |

## Pane Layout

```
┌─────────────────┬─────────────────────────────────────┐
│                 │                                     │
│   Git Graph     │         Commit Details              │
│   (Visual)      │    (Hash, Author, Date, Message)    │
│                 │                                     │
│     *           │  abc1234 12:34:56 John Doe         │
│     │           │  feat: add new feature              │
│     *           │                                     │
│     │           │  def5678 11:20:30 Jane Smith        │
│     *           │  fix: resolve bug in parser         │
│                 │                                     │
└─────────────────┴─────────────────────────────────────┘
```

## Arguments

The dual-pane mode supports the same arguments as the regular GitGraph:

- `all`: Show all branches
- `max_count=N`: Limit number of commits
- `revision_range`: Specify commit range (e.g., "HEAD~10..HEAD")

## Customization

All standard GitGraph configuration options apply to dual-pane mode:

- `symbols`: Customize graph symbols
- `format`: Configure timestamp and field display
- `hooks`: Set up commit selection handlers
- `highlights`: Customize colors and highlighting

## Technical Notes

- Requires Neovim 0.8+
- Must be run from within a Git repository
- Creates two synchronized buffers with independent horizontal scrolling
- Scroll synchronization can be toggled at runtime