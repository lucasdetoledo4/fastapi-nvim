local M = {}

local HTTP_METHODS = {
  "get", "post", "put", "delete", "patch", "options", "head", "websocket",
}

local EXCLUDED_PATTERNS = {
  "/.venv/", "/venv/", "/.env/",
  "/__pycache__/", "/.git/",
  "/node_modules/", "/site-packages/",
  "/dist/", "/build/",
}

local function is_excluded(filepath)
  for _, pattern in ipairs(EXCLUDED_PATTERNS) do
    if filepath:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

-- Look ahead from line i to find the function name
local function find_func_name(lines, i)
  for j = i + 1, math.min(i + 6, #lines) do
    local fline = lines[j]
    if fline then
      local name = fline:match("^%s*async%s+def%s+([%w_]+)")
                or fline:match("^%s*def%s+([%w_]+)")
      if name then return name end
      -- Stop if we hit a non-decorator, non-empty, non-def line
      if not fline:match("^%s*$") and not fline:match("^%s*@") then
        break
      end
    end
  end
  return "unknown"
end

-- Scan ahead from line i+1 to find the first string literal (route path)
-- used when the decorator spans multiple lines
local function find_path_multiline(lines, i)
  local n = #lines
  for j = i + 1, math.min(i + 10, n) do
    local l = lines[j]
    if l then
      local p = l:match('^%s*"([^"]*)"') or l:match("^%s*'([^']*)'")
      if p then return p end
      -- stop if we hit the closing paren or a keyword argument before the path
      if l:match("^%s*%)") or l:match("^%s*[%w_]+=") then break end
    end
  end
  return nil
end

-- Parse a single Python file and return all route definitions
function M.parse_routes(filepath)
  local ok, lines = pcall(vim.fn.readfile, filepath)
  if not ok or not lines then return {} end

  local routes = {}
  local n = #lines

  for i = 1, n do
    local line = lines[i]

    -- Match @obj.METHOD("path") or @obj.METHOD('path')
    -- Handles both single-line and multi-line decorators
    for _, method in ipairs(HTTP_METHODS) do
      local owner, path =
        line:match("^%s*@([%w_]+)%." .. method .. '%s*%("([^"]*)"')
      if not owner then
        owner, path =
          line:match("^%s*@([%w_]+)%." .. method .. "%s*%('([^']*)'")
      end

      -- Multi-line: @obj.method( with path on the next lines
      if not owner then
        owner = line:match("^%s*@([%w_]+)%." .. method .. "%s*%(")
        if owner then
          path = find_path_multiline(lines, i)
          if not path then owner = nil end
        end
      end

      if owner and path then
        table.insert(routes, {
          method    = method:upper(),
          path      = path,
          func_name = find_func_name(lines, i),
          owner     = owner,
          lnum      = i - 1, -- 0-indexed for nvim API
          filepath  = filepath,
        })
        break
      end
    end

    -- Match @obj.api_route("path", methods=["GET", "POST", ...])
    -- Also supports multi-line
    local owner, path =
      line:match('^%s*@([%w_]+)%.api_route%s*%("([^"]*)"')
    if not owner then
      owner, path =
        line:match("^%s*@([%w_]+)%.api_route%s*%('([^']*)'")
    end
    if not owner then
      owner = line:match("^%s*@([%w_]+)%.api_route%s*%(")
      if owner then
        path = find_path_multiline(lines, i)
        if not path then owner = nil end
      end
    end

    if owner and path then
      local methods = {}
      local methods_str = line:match("methods%s*=%s*%[(.-)%]")
      if methods_str then
        for m in methods_str:gmatch('["\']([^"\']+)["\']') do
          table.insert(methods, m:upper())
        end
      end
      if #methods == 0 then
        methods = { "GET" }
      end

      local func_name = find_func_name(lines, i)
      for _, method in ipairs(methods) do
        table.insert(routes, {
          method    = method,
          path      = path,
          func_name = func_name,
          owner     = owner,
          lnum      = i - 1,
          filepath  = filepath,
        })
      end
    end
  end

  return routes
end

-- Find all Python files in root, excluding irrelevant dirs
function M.find_python_files(root)
  root = root or vim.fn.getcwd()
  local all_files = vim.fn.glob(root .. "/**/*.py", false, true)

  local files = {}
  for _, f in ipairs(all_files) do
    if not is_excluded(f) then
      table.insert(files, f)
    end
  end
  return files
end

-- Discover all routes across the entire project
function M.discover_routes(root)
  local files = M.find_python_files(root)
  local all_routes = {}

  for _, filepath in ipairs(files) do
    local routes = M.parse_routes(filepath)
    for _, route in ipairs(routes) do
      table.insert(all_routes, route)
    end
  end

  table.sort(all_routes, function(a, b)
    if a.filepath == b.filepath then
      return a.lnum < b.lnum
    end
    return a.filepath < b.filepath
  end)

  return all_routes
end

return M
