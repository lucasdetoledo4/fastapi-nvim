# fastapi-nvim

A Neovim plugin for managing FastAPI routes, ported from the official [FastAPI VSCode extension](https://github.com/fastapi/fastapi-vscode).

Browse, search, and navigate all your FastAPI path operations without leaving Neovim.

## Features

- **Route picker** — fuzzy-search all routes across your project via Telescope
- **Method filter** — narrow results to a specific HTTP method with `<C-f>`
- **Virtual text** — each `@app.get(...)` decorator is annotated inline with the method and path
- **Prefix resolution** — resolves `APIRouter(prefix=...)` and `include_router(..., prefix=...)` to show full route paths
- **Multi-line decorators** — correctly parses decorators that span multiple lines
- **which-key integration** — keymaps registered automatically (supports v2 and v3)
- **Health check** — run `:checkhealth fastapi-nvim` to diagnose setup issues
- **Zero config** — auto-discovers routes by scanning for FastAPI decorators

## Requirements

- Neovim >= 0.10
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

### lazy.nvim

```lua
{
  "lucasdetoledo4/fastapi-nvim",
  ft           = "python",
  dependencies = { "nvim-telescope/telescope.nvim" },
  keys = {
    { "<leader>fa", function() require("fastapi-nvim").routes() end,  desc = "FastAPI: browse routes" },
    { "<leader>fA", function() require("fastapi-nvim").refresh() end, desc = "FastAPI: refresh routes" },
  },
  config = function()
    require("fastapi-nvim").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "lucasdetoledo4/fastapi-nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("fastapi-nvim").setup()
  end,
}
```

## Usage

| Keymap / Command | Action |
|---|---|
| `<leader>fa` / `:FastAPIRoutes` | Open the route picker |
| `<leader>fA` / `:FastAPIRefresh` | Re-scan the project and refresh cache |
| `<C-f>` *(inside picker)* | Filter routes by HTTP method |
| `:FastAPIDebug` | Print raw parsed routes for the current buffer (useful for reporting issues) |

The virtual text is rendered automatically when you open any `.py` file.

## Configuration

All options and their defaults:

```lua
require("fastapi-nvim").setup({
  -- Root directory to scan (defaults to cwd)
  root = nil,

  -- Show METHOD + path as EOL virtual text on decorator lines
  virtual_text = true,

  -- Set to false to disable a keymap
  keymaps = {
    routes  = "<leader>fa",
    refresh = "<leader>fA",
  },
})
```

## How it works

The plugin scans all `.py` files in your project (excluding `.venv`, `__pycache__`, `.git`, etc.) and detects FastAPI route decorators, including multi-line ones:

```python
@app.get("/items/{id}")                           # single-line
@router.post("/users")                            # router-scoped
@api.api_route("/ping", methods=["GET", "HEAD"])  # api_route

@app.put(                                         # multi-line
    "/items/{id}",
    response_model=Item,
)
```

Prefixes from `APIRouter` and `include_router` are resolved automatically:

```python
# items.py
router = APIRouter(prefix="/items")

@router.get("/{id}")   # shown as /api/v1/items/{id}

# main.py
app.include_router(router, prefix="/api/v1")
```

Results are cached for 15 seconds and invalidated on `:FastAPIRefresh`.

## Supported HTTP methods

`GET` · `POST` · `PUT` · `DELETE` · `PATCH` · `OPTIONS` · `HEAD` · `WEBSOCKET`

## License

MIT
