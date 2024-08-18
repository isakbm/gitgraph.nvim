local utils = require('gitgraph.utils')
local highlights = require('gitgraph.highlights')
local log = require('gitgraph.log')

---@class I.Highlight
---@field hg string -- NOTE: fine to use string since lua internalizes strings
---@field row integer
---@field start integer
---@field stop integer

local M = {}

---@class I.GitLogArgs
---@field all? boolean
---@field revision_range? string
---@field max_count? integer
---@field skip? integer

---@param config I.GGConfig
---@param options I.DrawOptions
---@param args I.GitLogArgs
---@return I.Row[]
---@return string[]
---@return I.Highlight[]
---@return integer?
function M.gitgraph(config, options, args)
  --- depends on `git`
  local data = require('gitgraph.git').git_log_pretty(args, config.format.timestamp)

  --- does the magic
  local start = os.clock()
  local graph, lines, highlights, head_loc = M._gitgraph(data, options, config.symbols, config.format.fields)
  local dur = os.clock() - start
  log.info('_gitgraph dur:', dur * 1000, 'ms')

  return graph, lines, highlights, head_loc
end

---@param data I.RawCommit[]
---@param opt I.DrawOptions
---@param sym I.GGSymbols
---@param fields I.GGVarName[]
---@return I.Row[]
---@return string[]
---@return I.Highlight[]
---@return integer? -- head location
---@return boolean -- true if contained bi-crossing
function M._gitgraph(data, opt, sym, fields)
  local ITEM_HGS = highlights.ITEM_HGS
  local BRANCH_HGS = highlights.BRANCH_HGS

  local NUM_BRANCH_COLORS = #BRANCH_HGS

  local found_bi_crossing = false

  -- git graph symbols
  -- NOTE: We emmy type these to string, we expect them all
  --       to be set. The only reason the config types are
  --       string? (i.e potentially nil) is to allow a user to
  --       pass in only a subset of symbols without being bombarded
  --       with warnings of missing options.
  local GVER = sym.GVER ---@type string -- '│'
  local GHOR = sym.GHOR ---@type string -- '─'
  local GCLD = sym.GCLD ---@type string -- '╮'
  local GCRD = sym.GCRD ---@type string -- '╭'
  local GCLU = sym.GCLU ---@type string -- '╯'
  local GCRU = sym.GCRU ---@type string -- '╰'
  local GLRU = sym.GLRU ---@type string -- '┴'
  local GLRD = sym.GLRD ---@type string -- '┬'
  local GLUD = sym.GLUD ---@type string -- '┤'
  local GRUD = sym.GRUD ---@type string -- '├'

  local GFORKU = sym.GFORKU ---@type string -- '┼'
  local GFORKD = sym.GFORKD ---@type string -- '┼'

  local GRUDCD = sym.GRUDCD ---@type string -- '├'
  local GRUDCU = sym.GRUDCU ---@type string -- '├'
  local GLUDCD = sym.GLUDCD ---@type string -- '┤'
  local GLUDCU = sym.GLUDCU ---@type string -- '┤'

  local GLRDCL = sym.GLRDCL ---@type string -- '┬'
  local GLRDCR = sym.GLRDCR ---@type string -- '┬'
  local GLRUCL = sym.GLRUCL ---@type string -- '┴'
  local GLRUCR = sym.GLRUCR ---@type string -- '┴'

  local GRCM = sym.commit ---@type string
  local GMCM = sym.merge_commit ---@type string
  local GRCME = sym.commit_end ---@type string
  local GMCME = sym.merge_commit_end ---@type string

  -- opt.pretty = true

  GFORKU = opt.pretty and '⓵' or GFORKU -- '┼'
  GFORKD = opt.pretty and '⓴' or GFORKD -- '┼'

  GRUDCD = opt.pretty and '⓶' or GRUDCD -- '├'
  GRUDCU = opt.pretty and '⓸' or GRUDCU -- '├'
  GLUDCD = opt.pretty and '⓷' or GLUDCD -- '┤'
  GLUDCU = opt.pretty and '⓹' or GLUDCU -- '┤'

  GLRDCL = opt.pretty and 'ⓢ' or GLRDCL -- '┬'
  GLRDCR = opt.pretty and 'ⓣ' or GLRDCR -- '┬'
  GLRUCL = opt.pretty and 'ⓥ' or GLRUCL -- '┴'
  GLRUCR = opt.pretty and 'ⓤ' or GLRUCR -- '┴'

  GRCM = opt.pretty and 'ⓚ' or GRCM
  GMCM = opt.pretty and '⓮' or GMCM
  GRCME = opt.pretty and 'ⓛ' or GRCME
  GMCME = opt.pretty and '⓯' or GMCME

  -- PERFORMANCE
  -- TODO: look at https://www.lua.org/gems/sample.pdf

  --
  -- local git_cmd = [[git log --all --pretty='format:%s%x00%aD%x00%H%x00%P']]

  ---@class I.Row
  ---@field i integer
  ---@field cells I.Cell[]
  ---@field commit I.Commit? -- there's a single comit for every even "second"

  -- TODO: make this into a proper class OO
  --       should have the following methods
  --       - hash : would return the commit hash or nil if cell is not a commit
  --       - conn : would return the connector symbol or nil if cell is not a connector
  --       - str  : would return the string representation
  --
  ---@class I.Cell
  ---@field is_commit boolean? -- when true this cell is a real commit
  ---@field commit I.Commit? -- a cell is associated with a commit, but the empty column gaps don't have them
  ---@field symbol string?
  ---@field connector string? -- a cell is eventually given a connector
  ---@field emphasis boolean? -- when true indicates that this is a direct parent of cell on previous row

  ---@class I.Commit
  ---@field hash string
  ---@field is_void boolean -- used for the "reservation" logic ... a bit confusing I have to admit
  ---@field msg string
  ---@field branch_names string[]
  ---@field tags string[]
  ---@field debug string?
  ---@field author_date string
  ---@field author_name string
  ---@field explored boolean
  ---@field i integer
  ---@field j integer
  ---@field parents string[]
  ---@field children string[]

  ---@type table<string, I.Commit>
  local commits = {}

  ---@type I.Commit[]
  local sorted_commits = {}

  ---@type string[]
  local hashes = {}

  for _, dc in ipairs(data) do
    hashes[#hashes + 1] = dc.hash

    local commit = {
      explored = false,
      msg = dc.msg,
      branch_names = dc.branch_names,
      tags = dc.tags,
      author_date = dc.author_date,
      author_name = dc.author_name,
      hash = dc.hash,
      i = -1,
      j = -1,
      parents = dc.parents,
      is_void = false,
      children = {},
    }

    sorted_commits[#sorted_commits + 1] = commit
    commits[dc.hash] = commit
  end

  do
    local start = os.clock()
    -- populate children
    -- for _, c in pairs(commits) do
    -- NOTE: you want to be very careful here with the order
    --       keep in mind that `pairs` does not keep an order
    --       while `ipairs` does keep an order
    for _, h in ipairs(hashes) do
      local c = commits[h]

      -- children
      for _, h in ipairs(c.parents) do
        local p = commits[h]
        if p then
          p.children[#p.children + 1] = c.hash
        else
          -- create a virtual parent, it is not added to the list of commit hashes
          commits[h] = {
            hash = h,
            author_name = 'virtual',
            is_void = false,
            msg = 'virtual parent',
            explored = false,
            author_date = 'unknown',
            parents = {},
            children = { c.hash },
            branch_names = {},
            tags = {},
            i = -1,
            j = -1,
          }
        end
      end
    end

    local dur = os.clock() - start
    log.info('children dur:', dur * 1000, 'ms')
  end

  ---@param sorted_commits I.Commit[]
  ---@return I.Row[]
  local function straight_j(sorted_commits)
    ---@type I.Row[]
    local graph = {}

    ---@param cells I.Cell[]
    ---@return I.Cell[]
    local function propagate(cells)
      local new_cells = {}
      for _, cell in ipairs(graph[#graph].cells) do
        if cell.connector then
          new_cells[#new_cells + 1] = { connector = ' ' }
        elseif cell.commit then
          assert(cell.commit)
          new_cells[#new_cells + 1] = { commit = cell.commit }
        else
          new_cells[#new_cells + 1] = { connector = ' ' }
        end
      end
      return new_cells
    end

    ---@param cells I.Cell[]
    ---@param hash string
    ---@param start integer?
    ---@return integer?
    local function find(cells, hash, start)
      local start = start or 1
      for idx = start, #cells do
        local c = cells[idx]
        if c.commit and c.commit.hash == hash then
          return idx
        end
      end
      return nil
    end

    ---@param cells I.Cell[]
    ---@param start integer?
    ---@return integer
    local function next_vacant_j(cells, start)
      local start = start or 1
      for i = start, #cells, 2 do
        local cell = cells[i]
        if cell.connector == ' ' then
          return i
        end
      end
      return #cells + 1
    end

    for i, c in ipairs(sorted_commits) do
      ---@type I.Cell[]
      local rowc = {}

      ---@type integer?
      local j = nil

      do
        --
        -- commit row
        --
        if #graph > 0 then
          rowc = propagate(graph[#graph].cells)
          j = find(graph[#graph].cells, c.hash)
        end

        -- if reserved location use it
        if j then
          c.j = j
          rowc[j] = { commit = c, is_commit = true }

          -- clear any supurfluous reservations
          for k = j + 1, #rowc do
            local v = rowc[k]
            if v.commit and v.commit.hash == c.hash then
              rowc[k] = { connector = ' ' }
            end
          end
        else
          j = next_vacant_j(rowc)
          c.j = j
          rowc[j] = { commit = c, is_commit = true }
          rowc[j + 1] = { connector = ' ' }
        end

        local row_idx = #graph + 1
        graph[row_idx] = { i = row_idx, cells = rowc, commit = c }
      end

      if i < #sorted_commits then
        -- connector row (reservation row)
        --
        -- first we propagate
        local rowc = propagate(graph[#graph].cells)

        local num_active = 0
        for _, cell in ipairs(rowc) do
          if cell.commit then
            num_active = num_active + 1
          end
        end

        if num_active > 1 or #c.parents > 0 then
          --
          -- connector row
          --
          -- at this point we should have a valid position for our commit (we have 'inserted' it)
          assert(j)
          local our_loc = j

          -- now we proceed to add the parents of the commit we just added
          --

          if #c.parents > 0 then
            ---@param rem_parents string[]
            local function reserve_remainder(rem_parents)
              --
              -- reserve the rest of the parents in slots to the right of us
              --
              -- ... another alternative is to reserve rest of the parents of c if they have not already been reserved
              -- for i = 2, #c.parents do
              for _, h in ipairs(rem_parents) do
                local j = find(graph[#graph].cells, h, our_loc)
                if not j then
                  local j = next_vacant_j(rowc, our_loc)
                  rowc[j] = { commit = commits[h], emphasis = true }
                  rowc[j + 1] = { connector = ' ' }
                else
                  rowc[j].emphasis = true
                end
              end
            end

            -- we start by peeking at next commit and seeing if it is one of our parents
            -- we only do this if one of our propagating branches is already destined for this commit
            local next_commit = sorted_commits[i + 1]
            ---@type I.Cell?
            local tracker = nil
            if next_commit then
              for _, cell in ipairs(rowc) do
                if cell.commit and cell.commit.hash == next_commit.hash then
                  tracker = cell
                  break
                end
              end
            end

            local next_p_idx = nil -- default to picking first parent
            if tracker and next_commit then
              -- this loop updates next_p_idx to the next commit if they are identical
              for k, h in ipairs(c.parents) do
                if h == next_commit.hash then
                  next_p_idx = k
                  break
                end
              end
            end

            -- next_p_idx = nil

            -- add parents
            if next_p_idx then
              assert(tracker)
              -- if next commit is our parent then we do some complex logic
              if #c.parents == 1 then
                -- simply place parent at our location
                rowc[our_loc].commit = commits[c.parents[1]]
                rowc[our_loc].emphasis = true
              else
                -- void the cell at our location (will be replaced by our parents in a moment)
                rowc[our_loc] = { connector = ' ' }

                -- put emphasis on tracker for the special parent
                tracker.emphasis = true

                -- only reserve parents that are different from next commit
                ---@type string[]
                local rem_parents = {}
                for k, h in ipairs(c.parents) do
                  if k ~= next_p_idx then
                    rem_parents[#rem_parents + 1] = h
                  end
                end

                assert(#rem_parents == #c.parents - 1, 'unexpected amount of rem parents')
                reserve_remainder(rem_parents)

                -- we fill this with the next commit if it is empty, a bit hacky
                if rowc[our_loc].connector == ' ' then
                  rowc[our_loc].commit = tracker.commit
                  rowc[our_loc].emphasis = true
                  rowc[our_loc].connector = nil
                  tracker.emphasis = false
                end
              end
            else
              -- simply add first parent at our location and then reserve the rest
              rowc[our_loc].commit = commits[c.parents[1]]
              rowc[our_loc].emphasis = true

              local rem_parents = {}
              for k = 2, #c.parents do
                rem_parents[#rem_parents + 1] = c.parents[k]
              end

              reserve_remainder(rem_parents)
            end

            local row_idx = #graph + 1
            graph[row_idx] = { i = row_idx, cells = rowc }

            -- handle bi-connector rows
            local is_bi_crossing, bi_crossing_safely_resolveable = utils.get_is_bi_crossing(graph, next_commit, #graph)

            -- used for troubleshooting and tracking complexity of tests
            if is_bi_crossing then
              found_bi_crossing = true
            end

            local next = sorted_commits[i + 1]

            -- if get_is_bi_crossing(graph, next_commit, #graph) then
            if is_bi_crossing and bi_crossing_safely_resolveable then
              utils.resolve_bi_crossing(graph, next)
            end
          else
            -- if we're here then it means that this commit has no common ancestors with other commits
            -- ... a different family ... see test `different family`

            -- we must remove the already propagated connector for the current commit since it has no parents
            for i = 1, #rowc do
              local cell = rowc[i]
              if cell.commit and cell.commit.hash == c.hash then
                rowc[i] = { connector = ' ' }
              end
            end
            local row_idx = #graph + 1
            graph[row_idx] = { i = row_idx, cells = rowc }
          end
        end
      end
    end

    return graph
  end

  local graph = straight_j(sorted_commits)

  ---@class I.DrawOptions
  ---@field mode? 'debug' | 'test'
  ---@field pretty? boolean

  ---@param graph I.Row[]
  ---@param options I.DrawOptions
  ---@return string[]
  ---@return I.Highlight[]
  ---@return integer?
  local function graph_to_lines(options, graph)
    ---@type integer?
    local head_loc = 1

    ---@type string[]
    local lines = {}

    ---@type I.Highlight[]
    local highlights = {}

    ---@param cell I.Cell
    ---@return string
    local function commit_cell_symb(cell)
      assert(cell.is_commit)

      if options.mode == 'debug' then
        return cell.commit.msg
      end

      if #cell.commit.parents > 1 then
        -- merge commit
        return #cell.commit.children == 0 and GMCME or GMCM
      else
        -- regular commit
        return #cell.commit.children == 0 and GRCME or GRCM
      end
    end

    ---@param row I.Row
    ---@return string
    local function row_to_str(row)
      local row_str = ''
      for j = 1, #row.cells do
        local cell = row.cells[j]
        if cell.connector then
          cell.symbol = cell.connector -- TODO: connector and symbol should not be duplicating data?
        else
          assert(cell.commit)
          cell.symbol = commit_cell_symb(cell)
        end

        row_str = row_str .. cell.symbol
      end
      return row_str
    end

    ---@param row I.Row
    ---@return I.Highlight[]
    local function row_to_highlights(row)
      local row_hls = {}
      local offset = 0

      for j = 1, #row.cells do
        local cell = row.cells[j]

        local width = cell.symbol and #cell.symbol or 1
        local start = offset
        local stop = start + width
        offset = offset + width

        if cell.commit then
          local hg = 'GitGraphBranch' .. tostring(j % NUM_BRANCH_COLORS + 1)
          row_hls[#row_hls + 1] = { hg = hg, row = row.i, start = start, stop = stop }
        elseif cell.symbol == GHOR then
          -- take color from first right cell that attaches to this connector
          for k = j + 1, #row.cells do
            local rcell = row.cells[k]

            -- TODO: would be nice with a better way than this hacky method of
            --       to figure out where our vertical branch is
            local continuations = {
              GCLD,
              GCLU,
              --
              GFORKD,
              GFORKU,
              --
              GLUDCD,
              GLUDCU,
              --
              GLRDCL,
              GLRUCL,
            }

            if rcell.commit and vim.tbl_contains(continuations, rcell.symbol) then
              local hg = 'GitGraphBranch' .. tostring(k % NUM_BRANCH_COLORS + 1)
              row_hls[#row_hls + 1] = { hg = hg, row = row.i, start = start, stop = stop }
              break
            end
          end
        end
      end
      return row_hls
    end

    ---@param row I.Row
    ---@return string
    local function row_to_test(row)
      local row_str = ''

      for i = 1, #row.cells do
        local cell = row.cells[i]
        if cell.connector then
          row_str = row_str .. cell.connector
        else
          assert(cell.commit)
          local symbol = cell.commit.msg
          symbol = cell.emphasis and symbol:lower() or symbol
          row_str = row_str .. symbol
        end
      end

      return row_str
    end

    ---@param row I.Row
    ---@return string
    local function row_to_debg(row)
      local row_str = ''
      for i = 1, #row.cells do
        local cell = row.cells[i]
        local symbol = ' '
        if cell.commit then
          symbol = cell.commit.msg
          symbol = cell.emphasis and symbol:lower() or symbol
        end
        row_str = row_str .. symbol
      end
      return row_str
    end

    local width = 0
    for _, row in ipairs(graph) do
      if #row.cells > width then
        width = #row.cells
      end
    end

    -- TODO: could obviously do it better than this
    local head_found = false

    for idx = 1, #graph do
      local proper_row = graph[idx]

      local row_str_arr = {}
      local offset = 0

      ---@param stuff string
      local function add_to_row(stuff)
        row_str_arr[#row_str_arr + 1] = stuff
        offset = offset + #stuff + 1 -- add one because a space will be implied later with concat separator
      end

      -- TODO: limit this so we do not leave the screen?
      local padding = width + 2

      -- part 1
      if options.mode == 'debug' then
        add_to_row(row_to_debg(proper_row))
        add_to_row((' '):rep(padding - #proper_row.cells))
        add_to_row(row_to_str(proper_row))
      elseif options.mode == 'test' then
        add_to_row(row_to_test(proper_row))
      else
        add_to_row(row_to_str(proper_row))
      end

      if options.mode ~= 'test' then
        local c = proper_row.commit
        if c then
          local hash = c.hash:sub(1, 7)
          local timestamp = c.author_date
          local author = c.author_name

          local branch_names = #c.branch_names > 0 and ('(%s)'):format(table.concat(c.branch_names, ' | ')) or nil

          local is_head = false
          if not head_found then
            is_head = branch_names and branch_names:match('HEAD %->') or false
            if is_head then
              head_found = true
              head_loc = idx
            end
          end

          local tags = #c.tags > 0 and ('(%s)'):format(table.concat(c.tags, ' | ')) or nil

          local items = {
            ['hash'] = hash,
            ['timestamp'] = timestamp,
            ['author'] = author,
            ['branch_name'] = branch_names,
            ['tag'] = tags,
          }

          local pad_size = padding - #proper_row.cells

          if is_head then
            pad_size = pad_size - 2
          end
          local pad_str = (' '):rep(pad_size)
          add_to_row(pad_str)
          if is_head then
            add_to_row('*')
          end

          --- add hihlights for hash, timestamp, branch_names and tags
          for _, name in ipairs(fields) do
            local value = items[name]
            if value then
              highlights[#highlights + 1] = {
                hg = ITEM_HGS[name].name,
                row = idx,
                start = offset,
                stop = offset + #value,
              }
              add_to_row(value)
            end
          end

          if options.mode == 'debug' then
            local parents = ''
            for _, h in ipairs(graph[idx].commit.parents) do
              local p = commits[h]
              parents = parents .. (p and p.msg or '?')
            end

            local children = ''
            for _, h in ipairs(graph[idx].commit.children) do
              local p = commits[h]
              children = children .. (p and p.msg or '?')
            end
            if #children == 0 then
              children = '_'
            end
            add_to_row(':  ' .. children .. ' ' .. c.msg .. ' ' .. parents)
          end
        else
          local c = graph[idx - 1].commit
          assert(c)
          if options.mode ~= 'debug' then
            add_to_row((' '):rep(padding - #proper_row.cells))
            add_to_row((' '):rep(7))

            highlights[#highlights + 1] = {
              start = offset,
              stop = offset + #c.msg,
              row = idx,
              hg = ITEM_HGS['message'].name,
            }

            add_to_row(c.msg)
          end

          -- row_str = row_str:gsub('%s*$', '')
        end

        for _, hl in ipairs(row_to_highlights(proper_row)) do
          highlights[#highlights + 1] = hl
        end
      end

      if options.mode == 'debug' then
        lines[#lines + 1] = table.concat(row_str_arr, ' '):gsub('%s*$', '')
      else
        lines[#lines + 1] = table.concat(row_str_arr, ' ')
      end
    end

    return lines, highlights, head_loc
  end

  -- if true then
  --   return graph_to_lines(graph)
  -- end

  -- print '---- stage 1 ---'
  -- show_graph(graph)
  -- print '----------------'

  -- store stage 1 graph
  --
  ---@param c I.Cell?
  ---@return string?
  local function hash(c)
    return c and c.commit and c.commit.hash
  end

  -- inserts vertical and horizontal pipes
  for i = 2, #graph - 1 do
    local row = graph[i]

    ---@param cells I.Cell[]
    local function count_emph(cells)
      local n = 0
      for _, c in ipairs(cells) do
        if c.commit and c.emphasis then
          n = n + 1
        end
      end
      return n
    end

    local num_emphasized = count_emph(graph[i].cells)

    -- vertical connections
    for j = 1, #row.cells do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]

      local tch, bch = hash(this), hash(below)

      if not this.is_commit and not this.connector then
        -- local ch = row.commit and row.commit.hash
        -- local row_commit_is_child = ch and vim.tbl_contains(this.commit.children, ch)
        -- local trivial_continuation = (not row_commit_is_child) and (new_columns < 1 or ach == tch or acc == GVER)
        -- local trivial_continuation = (new_columns < 1 or ach == tch or acc == GVER)
        local ignore_this = (num_emphasized > 1 and (this.emphasis or false))

        if not ignore_this and bch == tch then -- and trivial_continuation then
          local has_repeats = false
          local first_repeat = nil
          for k = 1, #row.cells, 2 do
            local cell_k, cell_j = row.cells[k], row.cells[j]
            local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)

            -- local rkc, rjc = row.cells[k].commit, row.cells[j].commit

            if k ~= j and (rkc and rjc) and rkc.hash == rjc.hash then
              has_repeats = true
              first_repeat = k
              break
            end
          end

          if not has_repeats then
            local cell = graph[i].cells[j]
            cell.connector = GVER
          else
            local k = first_repeat
            local this_k = graph[i].cells[k]
            local below_k = graph[i + 1].cells[k]

            local bkc, tkc = (not below_k.connector and below_k.commit), (not this_k.connector and this_k.commit)

            -- local bkc, tkc = below_k.commit, this_k.commit
            if (bkc and tkc) and bkc.hash == tkc.hash then
              local cell = graph[i].cells[j]
              cell.connector = GVER
            end
          end
        end
      end
    end

    do
      -- we expect number of rows to be odd always !! since the last
      -- row is a commit row without a connector row following it
      assert(#graph % 2 == 1)
      local last_row = graph[#graph]
      for j = 1, #last_row.cells do
        local cell = last_row.cells[j]
        if cell.commit and not cell.is_commit then
          cell.connector = GVER
        end
      end
    end

    -- horizontal connections
    --
    -- a stopped connector is one that has a void cell below it
    --
    local stopped = {}
    for j = 1, #row.cells do
      local this = graph[i].cells[j]
      local below = graph[i + 1].cells[j]
      if not this.connector and (not below or below.connector == ' ') then
        assert(this.commit)
        stopped[#stopped + 1] = j
      end
    end

    -- now lets get the intervals between the stopped connetors
    -- and other connectors of the same commit hash
    local intervals = {}
    for _, j in ipairs(stopped) do
      local curr = 1
      for k = curr, j do
        local cell_k, cell_j = row.cells[k], row.cells[j]
        local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)
        if (rkc and rjc) and (rkc.hash == rjc.hash) then
          if k < j then
            intervals[#intervals + 1] = { start = k, stop = j }
          end
          curr = j
          break
        end
      end
    end

    -- add intervals for the connectors of merge children
    -- these are where we have multiple connector commit hashes
    -- for a single merge child, that is, more than one connector
    --
    -- TODO: this method presented here is probably universal and covers
    --       also for the previously computed intervals ... two birds one stone?
    do
      local low = #row.cells
      local high = 1
      for j = 1, #row.cells do
        local c = row.cells[j]
        if c.emphasis then
          if j > high then
            high = j
          end
          if j < low then
            low = j
          end
        end
      end

      if high > low then
        intervals[#intervals + 1] = { start = low, stop = high }
      end
    end

    if i % 2 == 0 then
      for _, interval in ipairs(intervals) do
        local a, b = interval.start, interval.stop
        for j = a + 1, b - 1 do
          local this = graph[i].cells[j]
          if this.connector == ' ' then
            this.connector = GHOR
          end
        end
      end
    end
  end

  -- print '---- stage 2 -------'

  -- insert symbols on connector rows
  --
  -- note that there are 8 possible connections
  -- under the assumption that any connector cell
  -- has at least 2 neighbors but no more than 3
  --
  -- there are 4 ways to make the connections of three neighbors
  -- there are 6 ways to make the connections of two neighbors
  -- however two of them are the vertical and horizontal connections
  -- that have already been taken care of
  --
  for i = 1, #graph do
    -- we assert that our cells know associated commits when
    -- appropriate
    local cells = graph[i].cells
    for _, cell in ipairs(cells) do
      local con = cell.connector
      if con ~= ' ' and con ~= GHOR then
        if not cell.commit then
          print('bad cell:', vim.inspect(cell))
        end
        -- assert(cell.commit, 'expected commit')
      end
    end
  end

  for i = 2, #graph, 2 do
    local row = graph[i]
    local above = graph[i - 1]
    local below = graph[i + 1]

    -- local is_bi_crossing = get_is_bi_crossing(graph, i)

    for j = 1, #row.cells do
      local this = row.cells[j]

      if this.connector == GVER then
        -- because they are already taken care of
        goto continue
      end

      local lc = row.cells[j - 1]
      local rc = row.cells[j + 1]
      local uc = above and above.cells[j]
      local dc = below and below.cells[j]

      local l = lc and (lc.connector ~= ' ' or lc.commit) or false
      local r = rc and (rc.connector ~= ' ' or rc.commit) or false
      local u = uc and (uc.connector ~= ' ' or uc.commit) or false
      local d = dc and (dc.connector ~= ' ' or dc.commit) or false

      -- number of neighbors
      local nn = 0

      local symb_id = ''
      for _, b in ipairs({ l, r, u, d }) do
        if b then
          nn = nn + 1
          symb_id = symb_id .. '1'
        else
          symb_id = symb_id .. '0'
        end
      end

      local symbol = ({
        -- two neighbors (no straights)
        ['1010'] = GCLU,
        ['1001'] = GCLD,
        ['0110'] = GCRU,
        ['0101'] = GCRD,
        -- three neighbors
        ['1110'] = GLRU,
        ['1101'] = GLRD,
        ['1011'] = GLUD,
        ['0111'] = GRUD,
      })[symb_id] or '?'

      if i == #graph and symbol == '?' then
        symbol = GVER
      end

      local commit_dir_above = above.commit and above.commit.j == j

      ---@type 'l' | 'r' | nil -- placement of commit horizontally, only relevant if this is a connector row and if the cell is not immediately above or below the commit
      local clh_above = nil
      local commit_above = above.commit and above.commit.j ~= j
      if commit_above then
        clh_above = above.commit.j < j and 'l' or 'r'
      end

      if clh_above and symbol == GLRD then
        if clh_above == 'l' then
          symbol = GLRDCL -- '<'
        elseif clh_above == 'r' then
          symbol = GLRDCR -- '>'
        end
      elseif symbol == GLRU then
        -- because nothing else is possible with our
        -- current implicit graph building rules?
        symbol = GLRUCL -- '<'
      end

      local merge_dir_above = commit_dir_above and #above.commit.parents > 1

      if symbol == GLUD then
        symbol = merge_dir_above and GLUDCU or GLUDCD
      end

      if symbol == GRUD then
        symbol = merge_dir_above and GRUDCU or GRUDCD
      end

      if nn == 4 then
        symbol = merge_dir_above and GFORKD or GFORKU
      end

      if row.cells[j].commit then
        row.cells[j].connector = symbol
      end

      ::continue::
      --
    end
  end

  local lines, highlights, head_loc = graph_to_lines(opt, graph)

  return graph, lines, highlights, head_loc, found_bi_crossing
end

return M
