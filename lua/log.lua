local log = {}

function log.info(msg)
  vim.notify(msg, vim.log.levels.INFO)
end

function log.error(msg)
  vim.notify(msg, vim.log.levels.ERROR)
end

return log
