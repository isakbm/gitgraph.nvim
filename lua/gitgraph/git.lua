local log = require('gitgraph.log')

local M = {}

---@class I.RawCommit
---@field hash string
---@field parents string[]
---@field msg string
---@field branch_names string[]
---@field tags string[]
---@field author_date string
---@field author_name string

---@param args I.GitLogArgs
---@param date_format string
---@return I.RawCommit[]
function M.git_log_pretty(args, date_format)
  local start = os.clock()

  -- you cannot use both all and range at the same time
  if args.all and args.revision_range then
    args.revision_range = nil
  end

  local cli = [[git log %s %s --pretty="%s" --date="%s" %s %s --date-order]]

  local cli_args = {
    args.revision_range or '', -- revision range
    args.all and '--all' or '', -- all branches?
    -- 'format:%s%x00(%D)%x00%ad%x00%an%x00%H%x00%P', -- format makes it easy to extract info
    'format:%s%x00(%D)%x00%ad%x00%an%x00%h%x00%p', -- format makes it easy to extract info
    'format:' .. date_format, -- date format
    args.max_count and ('--max-count=%d'):format(args.max_count) or '', -- max count
    args.skip and ('--skip=%d'):format(args.skip) or '', -- skip
  }

  local git_cmd = (cli):format(unpack(cli_args))

  local io_handle = io.popen(git_cmd)
  if not io_handle then
    log.error('FATAL: no io handle to git_cmd result')
    return {}
  end

  ---@type string
  local git_cmd_out = io_handle:read('*a')

  io_handle:close()

  ---@type I.RawCommit[]
  local data = {}

  for line in git_cmd_out:gmatch('[^\r\n]+') do
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

  local dur = os.clock() - start
  log.info('cli duration:', dur * 1000, 'ms')

  return data
end

return M
