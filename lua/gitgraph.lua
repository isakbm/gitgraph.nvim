---@class I.Highlight
---@field hg string -- NOTE: fine to use string since lua internalizes strings
---@field row integer
---@field start integer
---@field stop integer

---@class I.GGSymbols
---@field merge_commit? string
---@field commit? string
---@field merge_commit_end? string
---@field commit_end? string
---@field GVER? string
---@field GHOR? string
---@field GCLD? string
---@field GCRD? string
---@field GCLU? string
---@field GCRU? string
---@field GLRU? string
---@field GLRD? string
---@field GLUD? string
---@field GRUD? string
---@field GFORKU? string
---@field GFORKD? string
---@field GRUDCD? string
---@field GRUDCU? string
---@field GLUDCD? string
---@field GLUDCU? string
---@field GLRDCL? string
---@field GLRDCR? string
---@field GLRUCL? string
---@field GLRUCR? string

---@alias I.GGVarName "hash" | "timestamp" | "author" | "branch_name" | "tag" | "message"

---@class I.GGFormat
---@field timestamp? string
---@field fields? I.GGVarName[]

---@class I.Hooks
---@field on_select_commit fun(commit: I.Commit)
---@field on_select_range_commit fun(from: I.Commit, to: I.Commit)

---@class I.GGConfig
---@field symbols? I.GGSymbols
---@field format? I.GGFormat
---@field hooks? I.Hooks

---@class I.HighlightGroup
---@field name string
---@field fg string
---
local M = {
  ---@type I.GGConfig
  config = {
    symbols = {
      merge_commit = 'M',
      commit = '*',
      merge_commit_end = 'M',
      commit_end = '*',

      -- Advanced symbols
      GVER = '│',
      GHOR = '─',
      GCLD = '╮',
      GCRD = '╭',
      GCLU = '╯',
      GCRU = '╰',
      GLRU = '┴',
      GLRD = '┬',
      GLUD = '┤',
      GRUD = '├',
      GFORKU = '┼',
      GFORKD = '┼',
      GRUDCD = '├',
      GRUDCU = '├',
      GLUDCD = '┤',
      GLUDCU = '┤',
      GLRDCL = '┬',
      GLRDCR = '┬',
      GLRUCL = '┴',
      GLRUCR = '┴',
    },
    hooks = {
      on_select_commit = function(commit)
        print('selected commit:', commit.hash)
      end,
      on_select_range_commit = function(from, to)
        print('selected range:', from.hash, to.hash)
      end,
    },
    format = {
      timestamp = '%H:%M:%S %d-%m-%Y',
      fields = { 'hash', 'timestamp', 'author', 'branch_name', 'tag' },
    },
  },
  ---@type integer?
  buf = nil,
  ---@type I.Row[]
  graph = {},
}

-- Follow conventions from mini.nvim
local Helper = {}

---@type table<string, I.HighlightGroup>
local ITEM_HGS = {
  hash = { name = 'GitGraphHash', fg = '#b16286' },
  timestamp = { name = 'GitGraphTimestamp', fg = '#98971a' },
  author = { name = 'GitGraphAuthor', fg = '#458588' },
  branch_name = { name = 'GitGraphBranchName', fg = '#d5651c' },
  tag = { name = 'GitGraphBranchTag', fg = '#d79921' },
  message = { name = 'GitGraphBranchMsg', fg = '#339921' },
}

---@type I.HighlightGroup[]
local BRANCH_HGS = {
  { name = 'GitGraphBranch1', fg = '#458588' },
  { name = 'GitGraphBranch2', fg = '#b16286' },
  { name = 'GitGraphBranch3', fg = '#d79921' },
  { name = 'GitGraphBranch4', fg = '#98971a' },
  { name = 'GitGraphBranch5', fg = '#d5651c' },
}

local NUM_BRANCH_COLORS = #BRANCH_HGS

function M.setup(config)
  M.config = vim.tbl_deep_extend('force', M.config, config)

  local function set_hl(name, highlight)
    local existing_hg = vim.api.nvim_get_hl(0, { name = name })
    if #existing_hg == 0 then
      vim.api.nvim_set_hl(0, name, vim.tbl_deep_extend('force', highlight, { default = true }))
    end
  end

  for _, hg in pairs(BRANCH_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end

  for _, hg in pairs(ITEM_HGS) do
    set_hl(hg.name, { fg = hg.fg })
  end
end

---@param stuff any[]
---@param n integer
---@return any[][]
local function pick(stuff, n)
  assert(n >= 1)

  ---@type any[][]
  local picked = {}
  if n == 1 then
    for _, s in ipairs(stuff) do
      picked[#picked + 1] = { s }
    end
    return picked
  end

  for i, s in ipairs(stuff) do
    ---@type any[]
    local subs = {}
    for j, ss in ipairs(stuff) do
      if i ~= j then
        subs[#subs + 1] = ss
      end
    end

    for _, p in ipairs(pick(subs, n - 1)) do
      local spicked = {}
      spicked[#spicked + 1] = s
      for _, pp in ipairs(p) do
        spicked[#spicked + 1] = pp
      end

      picked[#picked + 1] = spicked
    end
  end

  return picked
end

---@param stuff any[]
---@return  any[][]
local function permutations(stuff)
  return pick(stuff, #stuff)
end

---@param data I.RawCommit[]
---@param opt I.DrawOptions
---@return string[]
---@return I.Highlight[]
local function _gitgraph(data, opt)
  -- git graph symbols
  local GVER = M.config.symbols.GVER -- '│'
  local GHOR = M.config.symbols.GHOR -- '─'
  local GCLD = M.config.symbols.GCLD -- '╮'
  local GCRD = M.config.symbols.GCRD -- '╭'
  local GCLU = M.config.symbols.GCLU -- '╯'
  local GCRU = M.config.symbols.GCRU -- '╰'
  local GLRU = M.config.symbols.GLRU -- '┴'
  local GLRD = M.config.symbols.GLRD -- '┬'
  local GLUD = M.config.symbols.GLUD -- '┤'
  local GRUD = M.config.symbols.GRUD -- '├'

  local GFORKU = opt.pretty and '⓵' or M.config.symbols.GFORKU -- '┼'
  local GFORKD = opt.pretty and '⓴' or M.config.symbols.GFORKD -- '┼'

  local GRUDCD = opt.pretty and '⓶' or M.config.symbols.GRUDCD -- '├'
  local GRUDCU = opt.pretty and '⓸' or M.config.symbols.GRUDCU -- '├'
  local GLUDCD = opt.pretty and '⓷' or M.config.symbols.GLUDCD -- '┤'
  local GLUDCU = opt.pretty and '⓹' or M.config.symbols.GLUDCU -- '┤'

  local GLRDCL = opt.pretty and 'ⓢ' or M.config.symbols.GLRDCL -- '┬'
  local GLRDCR = opt.pretty and 'ⓣ' or M.config.symbols.GLRDCR -- '┬'
  local GLRUCL = opt.pretty and 'ⓥ' or M.config.symbols.GLRUCL -- '┴'
  local GLRUCR = opt.pretty and 'ⓤ' or M.config.symbols.GLRUCR -- '┴'

  -- local GRCM = opt.pretty and 'ⓚ' or '*'
  -- local GMCM = opt.pretty and '⓮' or '●'
  -- local GRCME = opt.pretty and 'ⓛ' or '*'
  -- local GMCME = opt.pretty and '⓯' or '●'

  local GRCM = M.config.symbols.commit
  local GMCM = M.config.symbols.merge_commit
  local GRCME = M.config.symbols.commit_end
  local GMCME = M.config.symbols.merge_commit_end

  -- ORGANIZATION
  -- TODO: look at https://github.com/S1M0N38/my-awesome-plugin.nvim to start making this into a plugin :)
  -- TODO: look at https://github.com/nvim-neorocks/nvim-best-practices
  --
  -- PERFORMANCE
  -- TODO: look at https://www.lua.org/gems/sample.pdf

  -- build a git commit graph
  --
  -- NOTE: you may be interested in knowin the difference between
  --       git log 'author date' and 'commit date'
  --
  --       author date is the original date of the commit when it was first made
  --       commit date is the date at which the commit was modified, i.e by an ammend
  --       or by a rebase or any other action that could modify the commit
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
  -- -@field merge_children string[]
  -- -@field branch_children string[]
  ---
  ---@type table<string, I.Commit>
  local commits = {}

  ---@type string[]
  local hashes = {}

  for _, dc in ipairs(data) do
    hashes[#hashes + 1] = dc.hash

    commits[dc.hash] = {
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
      -- merge_children = {},
      -- branch_children = {},
    }
  end

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

    -- branch children
    -- local h = c.parents[1]
    -- if h then
    --   local p = commits[h]
    --   if p then
    --     p.branch_children[#p.branch_children + 1] = c.hash
    --   end
    -- end

    -- merge children
    -- for i = 2, #c.parents do
    --   local h = c.parents[i]
    --   local p = commits[h]
    --   if p then
    --     p.merge_children[#p.merge_children + 1] = c.hash
    --   end
    -- end
  end

  ---@type I.Commit[]
  local sorted_commits = {}

  local function create_visitor()
    ---@type integer
    local i = 1

    ---@param commit I.Commit
    local function visit(commit)
      if not commit.explored then
        commit.explored = true
        for _, h in ipairs(commit.children) do
          visit(commits[h])
        end
        commit.i = i
        i = i + 1
        sorted_commits[#sorted_commits + 1] = commit
      end
    end

    return visit
  end

  local visit = create_visitor()

  for _, h in ipairs(hashes) do
    visit(commits[h])
  end

  ---@type I.Row[]
  local graph = {}

  ---@type I.Row[]
  local alpha_graph = {}

  ---@type I.Row[]
  local proper_graph = {}

  local debug_intervals = {}

  -- heuristic to check if this row contains a "bi-crossing" of branches
  --
  -- a bi-crossing is when we have more than one branch "propagating" horizontally
  -- on a connector row
  --
  -- this can only happen when the commit on the row
  -- above the connector row is a merge commit
  -- but it doesn't always happen
  --
  -- in addition to needing a merge commit on the row above
  -- we need the span (interval) of the "emphasized" connector cells
  -- (they correspond to connectors to the parents of the merge commit)
  -- we need that span to overlap with at least one connector cell that
  -- is destined for the commit on the next row
  -- (the commit before the merge commit)
  -- in addition, we need there to be more than one connector cell
  -- destined to the next commit
  --
  -- here is an example
  --
  --
  --   j i i          ⓮ │ │   j -> g h
  --   g i i h        ?─?─?─╮
  --   g i   h        │ ⓚ   │ i
  --
  --
  -- overlap:
  --
  --   g-----h 1 4
  --     i-i   2 3
  --
  -- NOTE how `i` is the commit that the `i` cells are destined for
  --      notice how there is more than on `i` in the connector row
  --      and that it lies in the span of g-h
  --
  -- some more examples
  --
  -- -------------------------------------
  --
  --   S T S          │ ⓮ │ T -> R S
  --   S R S          ?─?─?
  --   S R            ⓚ │   S
  --
  --
  -- overlap:
  --
  --   S-R    1 2
  --   S---S  1 3
  --
  -- -------------------------------------
  --
  --
  --   c b a b        ⓮ │ │ │ c -> Z a
  --   Z b a b        ?─?─?─?
  --   Z b a          │ ⓚ │   b
  --
  -- overlap:
  --
  --   Z---a    1 3
  --     b---b  2 4
  --
  -- -------------------------------------
  --
  -- finally a negative example where there is no problem
  --
  --
  --   W V V          ⓮ │ │ W -> S V
  --   S V V          ⓸─⓵─╯
  --   S V            │ ⓚ   V
  --
  -- no overlap:
  --
  --   S-V    1 2
  --     V-V  2 3
  --
  -- the reason why there is no problem (bi-crossing) above
  -- follows from the fact that the span from V <- V only
  -- touches the span S -> V it does not overlap it, so
  -- figuratively we have S -> V <- V which is fine
  --
  -- TODO:
  -- FIXME: need to test if we handle two bi-connectors in succession
  --        correctly
  --
  ---@param i integer -- the row index
  ---@param graph I.Row[] -- the row index
  ---@param next_commit I.Commit -- the next commit
  ---@return boolean -- whether or not this is a bi crossing
  ---@return boolean -- whether or not it can be resolved safely by edge lifting
  local function get_is_bi_crossing(graph, next_commit, i)
    if i % 2 == 1 then
      return false, false -- we're not a connector row NOTE: 1 indexing of lua
    end

    local prev = graph[i - 1].commit
    assert(prev, 'expected a prev commit')

    if #prev.parents < 2 then
      return false, false -- bi-crossings only happen when prev is a merge commit
    end

    local row = graph[i]

    ---@param k integer
    local function interval_upd(x, k)
      if k < x.start then
        x.start = k
      end
      if k > x.stop then
        x.stop = k
      end
    end

    -- compute the emphasized interval (merge commit parent interval)
    local emi = { start = #row.cells, stop = 1 }
    for k, cell in ipairs(row.cells) do
      if cell.commit and cell.emphasis then
        interval_upd(emi, k)
      end
    end

    -- compute connector interval
    local coi = { start = #row.cells, stop = 1 }
    for k, cell in ipairs(row.cells) do
      if cell.commit and cell.commit.hash == next_commit.hash then
        interval_upd(coi, k)
      end
    end

    -- unsafe if starts of intervals overlap and are equal to direct parent location
    local safe = not (emi.start == coi.start and prev.j == emi.start)

    -- return earily when connector interval is trivial
    if coi.start == coi.stop then
      return false, safe
    end

    -- print('emi:', vim.inspect(emi))
    -- print('coi:', vim.inspect(coi))

    -- check overlap
    do
      -- are intervals identical, then that counts as overlap
      if coi.start == emi.start and coi.stop == emi.stop then
        return true, safe
      end
    end
    for _, k in pairs(emi) do
      -- emi endpoints inside coi ?
      if coi.start < k and k < coi.stop then
        return true, safe
      end
    end
    for _, k in pairs(coi) do
      -- coi endpoints inside emi ?
      if emi.start < k and k < emi.stop then
        return true, safe
      end
    end

    return false, safe
  end

  ---@param sorted_commits I.Commit[]
  local function straight_j(sorted_commits)
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
        -- for idx, c in ipairs(cells) do
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
            local is_bi_crossing, bi_crossing_safely_resolveable = get_is_bi_crossing(graph, next_commit, #graph)

            -- if get_is_bi_crossing(graph, next_commit, #graph) then
            if is_bi_crossing and bi_crossing_safely_resolveable then
              -- if false then
              -- if false then -- get_is_bi_crossing(graph, next_commit, #graph) then
              -- print 'we have a bi crossing'
              local next = sorted_commits[i + 1]
              assert(next)
              -- void all repeated reservations of `next` from
              -- this and the previous row
              local prev_row = graph[#graph - 1]
              local this_row = graph[#graph]
              assert(prev_row and this_row, 'expecting two prior rows due to bi-connector')

              ---@param row I.Row
              --- example of what this does
              ---
              --- input:
              ---
              ---   j i i          │ │ │
              ---   j i i          ⓮ │ │     <- prev
              ---   g i i h        ⓸─⓵─ⓥ─╮   <- bi connector
              ---
              --- output:
              ---
              ---   j i i          │ ⓶─╯
              ---   j i            ⓮ │       <- prev
              ---   g i   h        ⓸─│───╮   <- bi connector
              ---
              ---@param row I.Row
              ---@return integer
              local function void_repeats(row)
                local start_voiding = false
                local ctr = 0
                for k, cell in ipairs(row.cells) do
                  if cell.commit and cell.commit.hash == next.hash then
                    if not start_voiding then
                      start_voiding = true
                    elseif not row.cells[k].emphasis then
                      -- else

                      row.cells[k] = { connector = ' ' } -- void it
                      ctr = ctr + 1
                    end
                  end
                end
                return ctr
              end

              local prev_rep_ctr = void_repeats(prev_row)
              local this_rep_ctr = void_repeats(this_row)

              -- we must also take care when the prev prev has a repeat where
              -- the repeat is not the direct parent of its child
              --
              --   G                        ⓯
              --   e d c                    ⓸─ⓢ─╮
              --   E D C F                  │ │ │ ⓯
              --   e D C c b a d            ⓶─⓵─│─⓴─ⓢ─ⓢ─? <--- to resolve this
              --   E D C C B A              ⓮ │ │ │ │ │
              --   c D C C b A              ⓸─│─ⓥ─ⓥ─⓷ │
              --   C D     B A              │ ⓮     │ │
              --   C c     b a              ⓶─ⓥ─────⓵─⓷
              --   C       B A              ⓮       │ │
              --   b       B a              ⓸───────ⓥ─⓷
              --   B         A              ⓚ         │
              --   a         A              ⓶─────────╯
              --   A                        ⓚ
              local prev_prev_row = graph[#graph - 2]
              local prev_prev_prev_row = graph[#graph - 3]
              assert(prev_prev_row and prev_prev_prev_row)
              do
                local start_voiding = false
                local ctr = 0
                ---@type I.Cell?
                local replacer = nil
                for k, cell in ipairs(prev_prev_row.cells) do
                  if cell.commit and cell.commit.hash == next.hash then
                    if not start_voiding then
                      start_voiding = true
                      replacer = cell
                    elseif k ~= prev_prev_prev_row.commit.j then
                      local ppcell = prev_prev_prev_row.cells[k]
                      if (not ppcell) or (ppcell and ppcell.connector == ' ') then
                        prev_prev_row.cells[k] = { connector = ' ' } -- void it
                        replacer.emphasis = true
                        ctr = ctr + 1
                      end
                    end
                  end
                end
              end

              -- assert(prev_rep_ctr == this_rep_ctr)

              -- newly introduced tracking cells can be squeezed in
              --
              -- before:
              --
              --   j i i          │ ⓶─╯
              --   j i            ⓮ │
              --   g i   h        ⓸─│───╮
              --
              -- after:
              --
              --   j i i          │ ⓶─╯
              --   j i            ⓮ │
              --   g i h          ⓸─│─╮
              --
              -- can think of this as scooting the cell to the left
              -- when the cell was just introduced
              -- TODO: implement this at some point
              -- for k, cell in ipairs(this_row.cells) do
              --   if cell.commit and not prev_row.cells[k].commit and not this_row.cells[k - 2] then
              --   end
              -- end
            end
          else
            local row_idx = #graph + 1
            graph[row_idx] = { i = row_idx, cells = { { connector = ' ' }, { connector = ' ' } } }
          end
        end
      end
    end
  end

  straight_j(sorted_commits)

  ---@class I.DrawOptions
  ---@field mode? 'debug' | 'test'
  ---@field pretty? boolean

  ---@param alpha_graph I.Row[]
  ---@param proper_graph I.Row[]
  ---@param options I.DrawOptions
  ---@return string[]
  ---@return I.Highlight[]
  ---@return integer?
  local function graph_to_lines(options, alpha_graph, proper_graph)
    ---@type integer?
    local head_loc = 1

    ---@type string[]
    local lines = {}

    ---@type I.Highlight[]
    local highlights = {}

    local function char_generator()
      local alphabet = {
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
        'G',
        'H',
        'I',
        'J',
        'K',
        'L',
        'M',
        'N',
        'O',
        'P',
        'Q',
        'R',
        'S',
        'T',
        'U',
        'V',
        'W',
      }
      local ctr = #alphabet - 1
      return function()
        local char = alphabet[(ctr % #alphabet) + 1]
        ctr = ctr - 1
        return char
      end
    end

    local next_char = char_generator()

    ---@param cell I.Cell
    ---@return string
    local function commit_cell_symb(cell)
      assert(cell.is_commit)
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
        if cell.connector then
          row_str = row_str .. cell.connector
        else
          assert(cell.commit)

          -- if not cell.commit.debug then
          --   cell.commit.debug = next_char()
          -- end
          --
          -- local symbol = cell.commit.debug or '?'
          local symbol = cell.commit.msg

          symbol = cell.emphasis and symbol:lower() or symbol
          row_str = row_str .. symbol
        end
      end

      return row_str
    end

    local width = 0
    for _, row in ipairs(proper_graph) do
      if #row.cells > width then
        width = #row.cells
      end
    end

    -- TODO: could obviously do it better than this
    local head_found = false

    for idx = 1, #alpha_graph do
      local alpha_row = alpha_graph[idx]
      local proper_row = proper_graph[idx]

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
        add_to_row(row_to_debg(alpha_row))
        add_to_row((' '):rep(padding - #alpha_row.cells))
        add_to_row(row_to_str(proper_row))
      elseif options.mode == 'test' then
        add_to_row(row_to_test(alpha_row))
      else
        add_to_row(row_to_str(proper_row))
      end

      if options.mode ~= 'test' then
        local c = alpha_row.commit
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

          local pad_size = padding - #alpha_row.cells

          if is_head then
            pad_size = pad_size - 2
          end
          local pad_str = (' '):rep(pad_size)
          add_to_row(pad_str)
          if is_head then
            add_to_row('*')
          end

          --- add hihlights for hash, timestamp, branch_names and tags
          for _, name in ipairs(M.config.format.fields) do
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
        else
          local c = alpha_graph[idx - 1].commit
          assert(c)
          if options.mode == 'debug' then
            local parents = ''
            for _, h in ipairs(graph[idx - 1].commit.parents) do
              local p = commits[h]
              parents = parents .. ' ' .. (p and p.msg or '?')
            end
            add_to_row((' '):rep(padding - #alpha_row.cells) .. c.msg .. ' ->> ' .. parents)
          else
            add_to_row((' '):rep(padding - #alpha_row.cells))
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

      lines[#lines + 1] = table.concat(row_str_arr, ' ')
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
  alpha_graph = vim.deepcopy(graph)
  --
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
    local function count_live(cells)
      local n = 0
      for _, r in ipairs(cells) do
        if r.commit or r.connector == GVER then
          n = n + 1
        end
      end
      return n
    end

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
    local curr = 1
    for _, j in ipairs(stopped) do
      for k = curr, j do
        local cell_k, cell_j = row.cells[k], row.cells[j]
        local rkc, rjc = (not cell_k.connector and cell_k.commit), (not cell_j.connector and cell_j.commit)
        if (rkc and rjc) and (rkc.hash == rjc.hash) then
          if j > k then
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
        if not c.connector and c.commit then
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

    debug_intervals[#debug_intervals + 1] = intervals
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

  proper_graph = graph

  M.graph = proper_graph

  return graph_to_lines(opt, alpha_graph, proper_graph)
end

---@class I.GitLogArgs
---@field all? boolean
---@field revision_range? string
---@field max_count? integer
---@field skip? integer

---@class I.RawCommit
---@field hash string
---@field parents string[]
---@field msg string
---@field branch_names string[]
---@field tags string[]
---@field author_date string
---@field author_name string
---

---@param options I.DrawOptions
---@param args I.GitLogArgs
---@return string[]
---@return I.Highlight[]
---@return integer
function M.gitgraph(options, args)
  -- you cannot use both all and range at the same time
  if args.all and args.revision_range then
    args.revision_range = nil
  end

  -- format to enable extracting information
  local revision_range = args.revision_range or ''

  local format = 'format:%s%x00(%D)%x00%ad%x00%an%x00%H%x00%P'
  local date_format = 'format:' .. M.config.format.timestamp -- 'format:%H:%M:%S %d-%m-%Y'
  local all = args.all and '--all' or ''
  local max_count = args.max_count and ('--max-count=%d'):format(args.max_count) or ''
  local skip = args.skip and ('--skip=%d'):format(args.skip) or ''

  local git_cmd = ([[git log %s %s --pretty='%s' --date='%s' %s %s]]):format(revision_range, all, format, date_format, max_count, skip)
  local handle = io.popen(git_cmd)
  if not handle then
    print('no handle?')
    return {}, {}, 1
  end

  ---@type string
  local log = handle:read('*a')

  handle:close()

  ---@type I.RawCommit[]
  local data = {}

  for line in log:gmatch('[^\r\n]+') do
    local iter = line:gmatch('([^%z]+)')
    local msg = iter()
    local describers = iter():gsub('[%(%)]', '') -- tags, branch names etc
    local author_date = iter()
    local author_name = iter()
    local hash = iter()
    local parent_iter = (iter() or ''):gmatch('[^%s]+')

    local branch_names = {}
    local tags = {}
    for desc in describers:gsub(', ', '\0'):gmatch('[^%z]+') do
      if desc:match('tag:.+') then
        tags[#tags + 1] = desc
      else
        branch_names[#branch_names + 1] = desc
      end
    end

    local parents = {}
    for p in parent_iter do
      parents[#parents + 1] = p
    end

    data[#data + 1] = {
      msg = msg,
      branch_names = branch_names,
      tags = tags,
      author_date = author_date,
      author_name = author_name,
      hash = hash,
      parents = parents,
    }
  end

  return _gitgraph(data, options)
end

---@return string[]
local function random_scenario()
  local commits = { 'A', 'B', 'C', 'D', 'E', 'F', 'G' }
  local size = #commits

  local scenario = {}

  for i = size, 1, -1 do
    local hash = commits[i]
    local remaining = {}
    for j = 1, i - 1 do
      remaining[j] = commits[j]
    end

    ---@type string[][]
    local possibilities = pick(remaining, math.random(#remaining))

    ---@type string[]
    local parents = possibilities[math.random(#possibilities)]

    local parents_str = table.concat(parents or {}, '')

    scenario[#scenario + 1] = hash .. (parents_str and (' ' .. parents_str) or '')
  end

  return scenario
end

---@param scenario string[]
---@return string[]
---@param show_graph? boolean
local function run_test_scenario(scenario, show_graph)
  ---@type I.RawCommit[]
  local raw = {}
  for i, r in ipairs(scenario) do
    local iter = r:gmatch('[^%s]+')
    local hash = iter()
    local par_iter = (iter() or ''):gmatch('.')
    local parents = {}
    for parent in par_iter do
      parents[#parents + 1] = parent
    end

    raw[#raw + 1] = {
      msg = hash,
      hash = hash,
      parents = parents,
      branch_names = {},
      tags = {},
      author_name = '',
      author_date = tostring(i),
    }
  end

  local options = { mode = (show_graph and 'debug' or 'test') }
  local lines, _ = _gitgraph(raw, options)

  return lines
end

---@return string[]
---@return boolean
function M.test()
  -- for the random scenario builder
  local seed = os.time()
  print('seeding:', seed)
  math.randomseed(seed)

  local scenarios = {
    {
      name = 'foo',
      commits = {
        'G D',
        'F C',
        'E C',
        'D AB',
        'C A',
        'B A',
        'A',
      },
      expect = {
        'G ',
        'd ',
        'D F ',
        'D c ',
        'D C E ',
        'D C c ',
        'D C   ',
        'a C   b ',
        'A C   B ',
        'A a   B ',
        'A A   B ',
        'A A   a ',
        'A       ',
      },
    },
    {
      name = 'bar',
      commits = {
        'F C',
        'E B',
        'D A',
        'C BA',
        'B A',
        'A',
      },
      expect = {
        'F ',
        'c ',
        'C E ',
        'C b ',
        'C B D ',
        'C B a ',
        'C B A ',
        'b B a ',
        'B   A ',
        'a   A ',
        'A     ',
      },
    },
    {
      name = 'bi-crossing 1',
      commits = {
        'J G',
        'I F',
        'H F',
        'G EB',
        'F D',
        'E A',
        'D A',
        'C A',
        'B A',
        'A',
      },
      expect = {
        'J ',
        'g ',
        'G I ',
        'G f ',
        'G F H ',
        'G F f ',
        'G F   ',
        'e F   b ',
        'E F   B ',
        'E d   B ',
        'E D   B ',
        'a D   B ',
        'A D   B ',
        'A a   B ',
        'A A C B ',
        'A A a B ',
        'A A A B ',
        'A A A a ',
        'A       ',
      },
    },
    {
      name = 'bi-crossing 2',
      commits = {
        'G C',
        'F D',
        'E C',
        'D CB',
        'C A',
        'B A ',
        'A',
      },
      expect = {
        'G ',
        'c ',
        'C F ',
        'C d ',
        'C D E ',
        'C D c ',
        'C D   ',
        'c b   ',
        'C B   ',
        'a B   ',
        'A B   ',
        'A a   ',
        'A     ',
      },
    },
    {
      name = 'strange 1',
      commits = {
        'G ADBEF',
        'F CADEB',
        'E DA',
        'D BC',
        'C BA',
        'B A',
        'A ',
      },
      expect = {
        'G ',
        'a d b e f ',
        'A D B E F ',
        'A d B e c a   b ',
        'A D B E C A   B ',
        'A D B d C a   B ',
        'A D B   C A   B ',
        'A c b   C A   B ',
        'A C B     A   B ',
        'A b B     a   B ',
        'A B       A     ',
        'A a       A     ',
        'A               ',
      },
    },

    {
      name = 'strange 2',
      commits = {
        'G BDECFA',
        'F BECAD',
        'E BAD',
        'D C',
        'C AB',
        'B A',
        'A ',
      },
      expect = {
        'G ',
        'b d e c f a ',
        'B D E C F A ',
        'B d e C b a c   ',
        'B D E C B A C   ',
        'B D d C b a C   ',
        'B D   C B A C   ',
        'B c   C B A C   ',
        'B C       A     ',
        'B b       a     ',
        'B         A     ',
        'a         A     ',
        'A               ',
      },
    },
    {
      name = 'branch out',
      commits = {
        'E AB',
        'D B',
        'C B',
        'B A',
        'A',
      },
      expect = {
        'E ',
        'a b ',
        'A B D ',
        'A B b ',
        'A B B C ',
        'A B B b ',
        'A B     ',
        'A a     ',
        'A       ',
      },
    },
    {
      name = 'branch in',
      commits = {
        'F B',
        'E BDC',
        'D A',
        'C A',
        'B A',
        'A',
      },
      expect = {
        'F ',
        'b ',
        'B E ',
        'B b d c ',
        'B B D C ',
        'B B a C ',
        'B B A C ',
        'B B A a ',
        'B   A A ',
        'a   A A ',
        'A       ',
      },
    },
    {
      name = 'ultra branch in',
      commits = {
        'H E',
        'G E',
        'F EDC',
        'E B',
        'D A',
        'C A',
        'B A',
        'A',
      },
      expect = {
        'H ',
        'e ',
        'E G ',
        'E e ',
        'E   F ',
        'e   d c ',
        'E   D C ',
        'b   D C ',
        'B   D C ',
        'B   a C ',
        'B   A C ',
        'B   A a ',
        'B   A A ',
        'a   A A ',
        'A       ',
      },
    },
    {
      name = 'alphred',
      commits = {
        'G DCBFE',
        'F E',
        'E D',
        'D CA',
        'C A',
        'B A',
        'A',
      },
      expect = {
        'G ',
        'd c b f e ',
        'D C B F E ',
        'D C B e E ',
        'D C B E   ',
        'D C B d   ',
        'D C B     ',
        'a c B     ',
        'A C B     ',
        'A a B     ',
        'A A B     ',
        'A A a     ',
        'A         ',
      },
    },

    {
      name = 'gustav',
      commits = {
        'G ABFCDE',
        'F DCEB',
        'E ACB',
        'D A',
        'C B',
        'B A',
        'A',
      },
      expect = {
        'G ',
        'a b f c d e ',
        'A B F C D E ',
        'A B b c d e ',
        'A B B C D E ',
        'A B B C D a c b ',
        'A B B C D A C B ',
        'A B B C a A C B ',
        'A B B C A A   B ',
        'A B B b A A   B ',
        'A B     A A     ',
        'A a     A A     ',
        'A               ',
      },
    },
    {
      name = 'frank',
      commits = {
        'G EAFDC',
        'F DEA',
        'E C',
        'D CA',
        'C B',
        'B A',
        'A',
      },
      expect = {
        'G ',
        'e a f d c ',
        'E A F D C ',
        'e A a d C ',
        'E A A D C ',
        'c A A D C ',
        'C A A D   ',
        'c A A a   ',
        'C A A A   ',
        'b A A A   ',
        'B A A A   ',
        'a A A A   ',
        'A         ',
      },
    },
    -- {
    --   name = 'short-frank',
    --   commits = {
    --     'G EAFDC',
    --     'F DEA',
    --     'E C',
    --     'D CA',
    --   },
    --   expect = {
    --     'G ',
    --     'e a f d c ',
    --     'E A F D C ',
    --     'e A a d C ',
    --     'E A A D C ',
    --     'c A A D C ',
    --     'C A A D   ',
    --   },
    -- },
    {
      name = 'julia',
      commits = {
        'G BFDEAC',
        'F ECBA',
        'E ACB',
        'D CA',
        'C B',
        'B A',
        'A',
      },
      expect = {
        'G ',
        'b f d e a c ',
        'B F D E A C ',
        'B b D e a c ',
        'B B D E A C ',
        'B B D a A c b ',
        'B B D A A C B ',
        'B B c a A C B ',
        'B B C A A   B ',
        'B B b A A   B ',
        'B     A A     ',
        'a     A A     ',
        'A             ',
      },
    },
  }

  local res = {}

  local failures = 0

  local function report_failure(msg)
    res[#res + 1] = msg
  end

  for _, scenario in ipairs(scenarios) do
    -- if scenario.name ~= 'strange 2' then
    --   goto continue
    -- end

    res[#res + 1] = ' ------ ' .. scenario.name .. ' ------ '

    for _, com in ipairs(scenario.commits) do
      res[#res + 1] = com
    end

    res[#res + 1] = ' ------ ' .. ' result ' .. ' ------ '

    -- currently we only check that the alphabet matrix is
    -- as we expect it to be hence the two locals below
    local alpha_graph = run_test_scenario(scenario.commits)

    -- this is used to visualize the scenario that is being tested
    -- we keep this separate from the actual test result data since
    -- we are not confident yet about the rendering, but we are confident
    -- about the alphabet matrix
    local graph = run_test_scenario(scenario.commits, true)

    for i, line in ipairs(graph) do
      res[#res + 1] = string.format('%02d', i) .. '   ' .. line
    end

    for i, line in ipairs(alpha_graph) do
      if line ~= scenario.expect[i] then
        report_failure('------ FAILURE ------')
        report_failure('failure in scenario ' .. scenario.name .. ' at line ' .. tostring(i))
        report_failure('expected:')
        report_failure('    ' .. (scenario.expect[i] or 'NA'))
        report_failure('got:')
        report_failure('    ' .. line)
        report_failure('---------------------')
        failures = failures + 1
      end
    end

    res[#res + 1] = ''

    ::continue::
  end

  if failures > 0 then
    report_failure(tostring(failures) .. ' failures')
  end

  report_failure(tostring(#scenarios - failures) .. ' of ' .. tostring(#scenarios) .. ' tests passed')

  return res, failures > 0
end

function M.random()
  local commits = random_scenario()
  return run_test_scenario(commits, true)
end

---@param options I.DrawOptions
---@param args I.GitLogArgs
function M.draw(options, args)
  -- reuse or create buffer
  do
    if not M.buf or not vim.api.nvim_buf_is_valid(M.buf) then
      M.buf = vim.api.nvim_create_buf(false, true)
    end
  end

  -- set active buffer to this one
  local buf = M.buf
  assert(buf)
  vim.api.nvim_win_set_buf(0, buf)

  -- make modifiable
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf })

  -- clear
  do
    local prior_buf_size = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, 0, prior_buf_size, false, {})
  end

  -- extract graph data
  local lines, highlights, head_loc = M.gitgraph(options, args)

  -- put graph data in buffer
  do
    -- text
    vim.api.nvim_buf_set_lines(buf, 0, #lines, false, lines)

    -- highlights
    for _, hl in ipairs(highlights) do
      local offset = 1
      vim.api.nvim_buf_add_highlight(buf, 0, hl.hg, hl.row - 1, hl.start - 1 + offset, hl.stop + offset)
    end
  end

  do
    local cursor_line = head_loc
    vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
  end

  Helper.apply_buffer_options(buf)
  Helper.apply_buffer_mappings(buf)
end

Helper.apply_buffer_options = function(buf_id)
  vim.api.nvim_buf_set_option(buf_id, 'modifiable', false)
  vim.cmd('noautocmd silent! set filetype=gitgraph')
  vim.api.nvim_buf_set_name(buf_id, 'GitGraph')

  local options = {
    'foldcolumn=0',
    'foldlevel=999',
    'norelativenumber',
    'nospell',
    'noswapfile',
  }
  -- Vim's `setlocal` is currently more robust compared to `opt_local`
  vim.cmd(('silent! noautocmd setlocal %s'):format(table.concat(options, ' ')))
end

Helper.apply_buffer_mappings = function(buf_id)
  vim.keymap.set('n', '<CR>', function()
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local commit = Helper.get_commit_from_row(row)
    if commit then
      M.config.hooks.on_select_commit(commit)
    end
  end, { buffer = buf_id, desc = 'select commit under cursor' })

  vim.keymap.set('v', '<CR>', function()
    -- make sure visual selection is done
    vim.cmd('noau normal! "vy"')

    local start_row = vim.fn.getpos("'<")[2]
    local end_row = vim.fn.getpos("'>")[2]

    local to_commit = Helper.get_commit_from_row(start_row)
    local from_commit = Helper.get_commit_from_row(end_row)

    if from_commit and to_commit then
      M.config.hooks.on_select_range_commit(from_commit, to_commit)
    end
  end, { buffer = buf_id, desc = 'select range of commit' })
end

Helper.get_commit_from_row = function(r)
  -- trick to map both the commit row and the message row to the provided commit
  local row = 2 * (math.floor((r - 1) / 2)) + 1 -- 1 1 3 3 5 5 7 7
  local commit = M.graph[row].commit
  return commit
end

return M
