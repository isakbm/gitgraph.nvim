local log = {
  level = vim.log.levels.ERROR,
}

---@return string
local function arg_to_str(...)
  local args = { ... }
  for i = 1, #args do
    args[i] = vim.inspect(args[i])
  end
  local str = table.concat(args, ' ')
  return str
end

function log.info(...)
  if log.level > vim.log.levels.INFO then
    return
  end
  vim.notify(arg_to_str(...), vim.log.levels.INFO)
end

function log.error(...)
  if log.level > vim.log.levels.ERROR then
    return
  end
  vim.notify(arg_to_str(...), vim.log.levels.ERROR)
end

function log.set_level(level)
  log.level = level
end

return log
