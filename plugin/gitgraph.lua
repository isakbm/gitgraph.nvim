-- GitGraph.nvim plugin initialization
-- Auto-registers commands when plugin is loaded

local function setup_commands()
  -- Register GitGraphDual command
  vim.api.nvim_create_user_command('GitGraphDual', function(opts)
    local gitgraph = require('gitgraph')
    local args = {}

    -- Parse command arguments
    if opts.args and opts.args ~= '' then
      -- Simple parsing for common arguments
      if string.find(opts.args, 'all') then
        args.all = true
      end

      local max_count = string.match(opts.args, 'max_count=(%d+)')
      if max_count then
        args.max_count = tonumber(max_count)
      end
    end

    gitgraph.draw_dual({}, args)
  end, {
    desc = 'Open GitGraph in dual-pane mode',
    nargs = '*',
    complete = function(arglead, cmdline, cursorpos)
      return { 'all', 'max_count=1000', 'max_count=5000' }
    end
  })

  -- Register original GitGraph command if not already registered
  if vim.fn.exists(':GitGraph') == 0 then
    vim.api.nvim_create_user_command('GitGraph', function(opts)
      local gitgraph = require('gitgraph')
      local args = {}

      if opts.args and opts.args ~= '' then
        if string.find(opts.args, 'all') then
          args.all = true
        end

        local max_count = string.match(opts.args, 'max_count=(%d+)')
        if max_count then
          args.max_count = tonumber(max_count)
        end
      end

      gitgraph.draw({}, args)
    end, {
      desc = 'Open GitGraph in single-pane mode',
      nargs = '*',
      complete = function(arglead, cmdline, cursorpos)
        return { 'all', 'max_count=1000', 'max_count=5000' }
      end
    })
  end
end

-- Setup commands when plugin loads
setup_commands()
