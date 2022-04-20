local config = require("react-extract.config").config
local M = {}
local loop = vim.loop

-- TODO: check for windows?
M.PATH_SEPARATOR = "/"

M.split = function(str, sep)
  local items = {}
  local pattern = string.format("([^%s]+)", sep)

  for item in string.gmatch(str, pattern) do
    table.insert(items, item)
  end

  return items
end

M.table_extend = function(t1, t2)
  for _, item in ipairs(t2) do
    table.insert(t1, item)
  end
end

local create_dir = function(path)
  if not loop.fs_stat(path) then
    loop.fs_mkdir(path, 493)
  end
end

local create_dirs = function(dirs)
  local checked = {}
  for _, dir in pairs(dirs) do
    table.insert(checked, dir)
    create_dir(table.concat(checked, M.PATH_SEPARATOR))
  end
end

M.create_file = function(filepath)
  if loop.fs_stat(filepath) then
    vim.notify("File already exists", "error")
    return false
  end

  local parts = M.split(filepath, M.PATH_SEPARATOR)
  -- pop last element
  local filename = table.remove(parts)
  -- create parent directories if necessary
  create_dirs(parts)

  -- create file
  local open_mode = loop.constants.O_CREAT + loop.constants.O_WRONLY + loop.constants.O_TRUNC
  local fd = loop.fs_open(filepath, "w", open_mode)
  if not fd then
    vim.notify("Could not create file " .. filename, "error")
    return false
  end
  loop.fs_chmod(filepath, 420)
  loop.fs_close(fd)

  return true
end

M.get_tsserver = function()
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == "tsserver" then
      return client
    end
  end
end

M.get_indentation_string = function(line, indent_char)
  local match = string.match(line, "^" .. indent_char .. "+")
  return string.rep(indent_char, #match)
end

M.get_selection_range = function()
  local original_start = vim.fn.getpos("v")[2] - 1
  local original_end = vim.fn.getcurpos()[2]

  if original_start > original_end then
    -- visual selection started from the bottom
    original_start, original_end = original_end - 1, original_start + 1
  end

  return original_start, original_end
end

M.get_indent = function(indent_char, multiplicator)
  local indent
  if indent_char == "\t" then
    indent = multiplicator
  else
    indent = multiplicator * vim.api.nvim_buf_get_option(0, "shiftwidth")
  end

  return indent
end

M.get_filename = function(path)
  local parts = M.split(path, M.PATH_SEPARATOR)
  return parts[#parts]
end

return M
