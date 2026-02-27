local M = {}

M._config = {
  root         = nil,  -- auto-detect from cwd
  virtual_text = true, -- show method+path as EOL virtual text on decorator lines
  keymaps = {
    routes  = "<leader>fa", -- open route picker
    refresh = "<leader>fA", -- refresh routes cache
  },
}

-- Virtual text namespace
local ns_id = vim.api.nvim_create_namespace("fastapi_nvim_vt")

-- Route cache
local _cache = { routes = nil, timestamp = 0, root = nil }
local CACHE_TTL_MS = 15000 -- 15 seconds

local function get_routes(force)
  local root = M._config.root or vim.fn.getcwd()
  local now  = vim.uv.now()

  if not force
    and _cache.routes
    and _cache.root == root
    and (now - _cache.timestamp) < CACHE_TTL_MS
  then
    return _cache.routes
  end

  local discovery  = require("fastapi-nvim.discovery")
  _cache.routes    = discovery.discover_routes(root)
  _cache.timestamp = now
  _cache.root      = root
  return _cache.routes
end

-- METHOD highlight groups for virtual text
local METHOD_HL = {
  GET       = "DiagnosticOk",
  POST      = "DiagnosticInfo",
  PUT       = "DiagnosticWarn",
  DELETE    = "DiagnosticError",
  PATCH     = "DiagnosticWarn",
  OPTIONS   = "Comment",
  HEAD      = "Comment",
  WEBSOCKET = "DiagnosticHint",
}

-- Open Telescope route picker
function M.routes()
  local ok, picker = pcall(require, "fastapi-nvim.telescope_picker")
  if not ok then
    vim.notify("fastapi-nvim: " .. picker, vim.log.levels.ERROR)
    return
  end

  local routes = get_routes()
  if #routes == 0 then
    vim.notify(
      "fastapi-nvim: no routes found in " .. (M._config.root or vim.fn.getcwd()),
      vim.log.levels.WARN
    )
    return
  end

  picker.pick_routes(routes)
end

-- Force refresh + report count
function M.refresh()
  local routes = get_routes(true)
  vim.notify(
    "fastapi-nvim: refreshed — " .. #routes .. " route(s) found",
    vim.log.levels.INFO
  )
end

-- Render virtual text for all FastAPI decorators in a buffer
function M.update_virtual_text(bufnr)
  if not M._config.virtual_text then return end
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if not filepath:match("%.py$") then return end

  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local discovery = require("fastapi-nvim.discovery")
  local routes    = discovery.parse_routes(filepath)

  for _, route in ipairs(routes) do
    local hl = METHOD_HL[route.method] or "Comment"
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, route.lnum, 0, {
      virt_text     = {
        { "  ", "Comment" },
        { route.method, hl },
        { " " .. route.path, "Comment" },
      },
      virt_text_pos = "eol",
      priority      = 100,
    })
  end
end

function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", M._config, opts or {})

  -- User commands
  vim.api.nvim_create_user_command("FastAPIRoutes",
    function() M.routes() end,
    { desc = "Browse FastAPI routes (Telescope)" }
  )
  vim.api.nvim_create_user_command("FastAPIRefresh",
    function() M.refresh() end,
    { desc = "Refresh FastAPI routes cache" }
  )

  -- Keymaps
  local km = M._config.keymaps
  if km.routes then
    vim.keymap.set("n", km.routes, M.routes,  { desc = "FastAPI: browse routes" })
  end
  if km.refresh then
    vim.keymap.set("n", km.refresh, M.refresh, { desc = "FastAPI: refresh routes" })
  end

  -- Virtual text: render on Python buffer enter / save
  if M._config.virtual_text then
    local aug = vim.api.nvim_create_augroup("FastAPINvim", { clear = true })
    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
      group   = aug,
      pattern = "*.py",
      callback = function(ev)
        -- Defer slightly so the buffer is fully loaded
        vim.schedule(function()
          M.update_virtual_text(ev.buf)
        end)
      end,
    })
  end
end

return M
