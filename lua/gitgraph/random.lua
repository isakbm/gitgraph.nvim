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

return random_scenario
