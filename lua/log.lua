local log = {}

---@return string
local function arg_to_str(...)
  local args = { ... }
  for i = 1, #args do
    args[i] = tostring(args[i])
  end
  local str = table.concat(args, ' ')
  return str
end

function log.info(...)
  vim.notify(arg_to_str(...), vim.log.levels.INFO)
end

function log.error(...)
  vim.notify(arg_to_str(...), vim.log.levels.ERROR)
end

return log
