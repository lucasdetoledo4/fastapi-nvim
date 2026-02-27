local M = {}

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

-- Fixed-width 5-char badges
local METHOD_BADGE = {
  GET       = "GET  ",
  POST      = "POST ",
  PUT       = "PUT  ",
  DELETE    = "DEL  ",
  PATCH     = "PTCH ",
  OPTIONS   = "OPT  ",
  HEAD      = "HEAD ",
  WEBSOCKET = "WS   ",
}

-- Collect sorted list of unique methods present in a route list
local function available_methods(routes)
  local seen, list = {}, {}
  for _, r in ipairs(routes) do
    if not seen[r.method] then
      seen[r.method] = true
      table.insert(list, r.method)
    end
  end
  table.sort(list)
  return list
end

-- Filter routes by method (nil = all)
local function filter(routes, method)
  if not method then return routes end
  local out = {}
  for _, r in ipairs(routes) do
    if r.method == method then table.insert(out, r) end
  end
  return out
end

-- Core picker — `all_routes` is the unfiltered master list so the method
-- filter action can always reset to it; `active_filter` is the current method
-- string or nil.
local function open_picker(all_routes, active_filter)
  local display_routes = filter(all_routes, active_filter)

  local pickers       = require("telescope.pickers")
  local finders       = require("telescope.finders")
  local conf          = require("telescope.config").values
  local actions       = require("telescope.actions")
  local action_state  = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 5 },        -- method badge
      { width = 32 },       -- owner + route path
      { remaining = true }, -- function name
    },
  })

  local function make_display(entry)
    local r     = entry.value
    local badge = METHOD_BADGE[r.method] or r.method
    local hl    = METHOD_HL[r.method] or "Normal"
    -- Show owner as a dim prefix so the full path is immediately identifiable
    local path_display = r.owner and (r.owner .. " " .. r.path) or r.path
    return displayer({
      { badge,          hl },
      { path_display,   "TelescopeResultsComment" },
      { r.func_name,    "TelescopeResultsIdentifier" },
    })
  end

  -- Title reflects active filter + total shown
  local filter_tag = active_filter and (" [" .. active_filter .. "]") or ""
  local title = " FastAPI Routes" .. filter_tag
              .. "  " .. #display_routes .. "/" .. #all_routes

  pickers.new({}, {
    prompt_title = title,
    finder = finders.new_table({
      results = display_routes,
      entry_maker = function(r)
        -- ordinal includes method + path + func + owner so all are searchable
        return {
          value    = r,
          display  = make_display,
          ordinal  = table.concat({ r.method, r.path, r.func_name, r.owner }, " "),
          filename = r.filepath,
          lnum     = r.lnum + 1,
          col      = 0,
        }
      end,
    }),
    sorter    = conf.generic_sorter({}),
    previewer = conf.grep_previewer({}),

    attach_mappings = function(prompt_bufnr, map)
      -- <CR>: jump to route definition
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local sel = action_state.get_selected_entry()
        if sel then
          vim.cmd("edit " .. vim.fn.fnameescape(sel.filename))
          vim.api.nvim_win_set_cursor(0, { sel.lnum, 0 })
          vim.cmd("normal! zz")
        end
      end)

      -- <C-f>: pick a method filter (or reset to all) via vim.ui.select
      local function choose_filter()
        actions.close(prompt_bufnr)
        local methods = available_methods(all_routes)
        local choices = { "All methods" }
        for _, m in ipairs(methods) do
          table.insert(choices, m)
        end
        vim.ui.select(choices, { prompt = "Filter by method:" }, function(choice)
          if not choice then return end
          local new_filter = choice == "All methods" and nil or choice
          open_picker(all_routes, new_filter)
        end)
      end

      map("i", "<C-f>", choose_filter)
      map("n", "<C-f>", choose_filter)

      return true
    end,
  }):find()
end

-- Public entry point
function M.pick_routes(routes)
  open_picker(routes, nil)
end

return M
