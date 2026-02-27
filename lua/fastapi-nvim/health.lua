local M = {}

function M.check()
  vim.health.start("fastapi-nvim")

  -- Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 is required")
  end

  -- telescope.nvim
  local ok_telescope = pcall(require, "telescope")
  if ok_telescope then
    vim.health.ok("telescope.nvim found")
  else
    vim.health.error(
      "telescope.nvim not found",
      "Install nvim-telescope/telescope.nvim"
    )
  end

  -- plenary.nvim (required by telescope)
  local ok_plenary = pcall(require, "plenary")
  if ok_plenary then
    vim.health.ok("plenary.nvim found")
  else
    vim.health.warn(
      "plenary.nvim not found",
      "Install nvim-lua/plenary.nvim (required by telescope.nvim)"
    )
  end

  -- Python files reachable from cwd
  local py_files = vim.fn.glob(vim.fn.getcwd() .. "/**/*.py", false, true)
  local count = 0
  for _, f in ipairs(py_files) do
    if not f:find("/.venv/", 1, true) and not f:find("/__pycache__/", 1, true) then
      count = count + 1
    end
  end

  if count > 0 then
    vim.health.ok(count .. " Python file(s) found in cwd")
  else
    vim.health.warn("No Python files found in cwd — open Neovim from your project root")
  end
end

return M
