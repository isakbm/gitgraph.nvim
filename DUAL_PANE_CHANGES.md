# GitGraph Dual-Pane Implementation - Changes Summary

## Overview

This document summarizes the implementation of dual-pane functionality for the GitGraph.nvim plugin. The dual-pane mode provides a split-screen interface with synchronized vertical scrolling and independent horizontal scrolling.

## Files Added

### Core Implementation
- `lua/gitgraph/draw_dual.lua` - Main dual-pane rendering logic
- `plugin/gitgraph.lua` - Auto-registration of GitGraphDual command
- `DUAL_PANE.md` - Comprehensive documentation for dual-pane mode

## Files Modified

### `lua/gitgraph.lua`
- Added `draw_dual()` function for dual-pane mode
- Maintained backward compatibility with existing API

### `lua/gitgraph/core.lua`
- Added `gitgraph_dual()` function
- Added `_gitgraph_dual()` internal function
- Added `graph_to_lines_dual()` function to separate graph and text data
- Enhanced data processing to support dual-pane rendering

### `README.md`
- Added dual-pane mode documentation
- Updated feature list
- Added usage examples and keybindings

## Key Features Implemented

### 1. Dual-Pane Layout
- **Left pane**: Visual git graph representation
- **Right pane**: Commit details (hash, timestamp, author, message, branches, tags)
- Automatic vertical split creation

### 2. Synchronized Scrolling
- Vertical scrolling synchronized between panes
- Independent horizontal scrolling per pane
- Toggle synchronization with `<leader>gs`

### 3. Window Management
- Switch between panes with `<Tab>`
- Proper window and buffer handling
- Automatic cleanup on buffer deletion

### 4. Enhanced Navigation
- All original keybindings preserved
- Additional dual-pane specific keybindings
- Visual mode support for commit range selection

## Technical Implementation Details

### Data Separation
The `graph_to_lines_dual()` function separates the original combined output into:
- `graph_lines[]` - Pure graph visualization (symbols only)
- `text_lines[]` - Commit information (hash, author, date, message, etc.)
- Separate highlight arrays for each pane

### Window Synchronization
- Uses Neovim's autocmd system for cursor movement detection
- Maintains window validity checks
- Prevents recursive synchronization with `updating_scroll` flag

### Error Handling
- Safe API calls with pcall where appropriate
- Graceful fallbacks for invalid data
- Proper validation of window and buffer handles

## Usage Integration

### Command Registration
The plugin automatically registers the `GitGraphDual` command when loaded, making it available immediately after plugin setup.

### API Compatibility
```lua
-- Original single-pane mode (unchanged)
require('gitgraph').draw({}, { all = true, max_count = 5000 })

-- New dual-pane mode
require('gitgraph').draw_dual({}, { all = true, max_count = 5000 })
```

### Plugin Configuration
Works seamlessly with existing plugin configurations. Users can add dual-pane keybindings alongside existing ones:

```lua
keys = {
    -- Original single-pane
    { "<leader>gph", function() require('gitgraph').draw({}, { all = true, max_count = 5000 }) end },
    -- New dual-pane
    { "<leader>gpd", function() require('gitgraph').draw_dual({}, { all = true, max_count = 5000 }) end },
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

## Benefits

1. **Enhanced Readability**: Separate panes make it easier to read both graph structure and commit details
2. **Better Space Utilization**: Graph symbols don't compete with text for horizontal space
3. **Flexible Navigation**: Independent horizontal scrolling allows focusing on either graph or details
4. **Preserved Functionality**: All original features remain available
5. **Easy Adoption**: Minimal configuration required, works with existing setups

## Backward Compatibility

- All existing functionality preserved
- Original `draw()` function unchanged
- Existing configurations continue to work
- No breaking changes to the API

## Performance Considerations

- Minimal overhead compared to single-pane mode
- Same data processing with additional separation step
- Efficient buffer and window management
- No impact on original functionality performance