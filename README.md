# fastapi-nvim

A Neovim plugin for managing FastAPI routes, ported from the official [FastAPI VSCode extension](https://github.com/fastapi/fastapi-vscode).

Browse, search, and navigate all your FastAPI path operations without leaving Neovim.

## Features

- **Route picker** — fuzzy-search all routes across your project via Telescope
- **Method filter** — narrow results to a specific HTTP method with `<C-f>`
- **Virtual text** — each `@app.get(...)` decorator is annotated inline with the method and path
- **Zero config** — auto-discovers routes by scanning for FastAPI decorators

## Requirements

- Neovim >= 0.9
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation

### lazy.nvim

```lua
{
  "your-username/fastapi-nvim",
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
  "your-username/fastapi-nvim",
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

The plugin scans all `.py` files in your project (excluding `.venv`, `__pycache__`, `.git`, etc.) and detects FastAPI route decorators:

```python
@app.get("/items/{id}")          # detected
@router.post("/users")           # detected
@api.api_route("/ping", methods=["GET", "HEAD"])  # detected
```

Results are cached for 15 seconds and invalidated on `:FastAPIRefresh`.

## Supported HTTP methods

`GET` · `POST` · `PUT` · `DELETE` · `PATCH` · `OPTIONS` · `HEAD` · `WEBSOCKET`

## License

MIT
