local status_ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
if not status_ok then
  return {
    get_identifiers = function() return {} end
  }
end

local utils = require("react-extract.utils")

local M = {}

-- Tries to recursively find correct jsx_element node based on
-- initial node and original_start row.
-- "parent" strategy is used to go up in the tree (assumes initial node
-- is after correct jsx_element node)
-- "next_sibling" strategy is used when jsx_element is found but its
-- position does not match give original_start (initial node is before
-- correct jsx_element node)
local function find_jsx_element(node, strategy, original_start)
  local new_node
  if strategy == "parent" then
    new_node = node:parent()
  end

  if strategy == "next_sibling" then
    new_node = node:next_sibling()
  end

  if new_node == nil then
    return
  end

  if new_node:type() == "jsx_element" or new_node:type() == "jsx_fragment" then
    local start_row, _, _ = new_node:start()
    if start_row == original_start then
      return new_node
    else
      -- jsx_element found but in different range than selected
      -- continue with original node and different strategy
      return find_jsx_element(node, "next_sibling", original_start)
    end
  elseif new_node:type() == "jsx_closing_element" and new_node:parent():type() == "jsx_element" then
    return new_node:parent()
  else
    return find_jsx_element(new_node, "parent", original_start)
  end
end

-- Recursively finds all child nodes of node matching given node_type
local function find_children_by_type(node, node_type)
  local t = {}
  for child, name in node:iter_children() do
    if child:type() == node_type then
      table.insert(t, child)
    else
      utils.table_extend(t, find_children_by_type(child, node_type))
    end
  end
  return t
end

-- Returns set of identifiers found in given list
-- of jsx_expression nodes.
local function find_indentifiers_in_expressions(jsx_expressions)
  local t = {}
  for _, expression in ipairs(jsx_expressions) do
    utils.table_extend(t, find_children_by_type(expression, "identifier"))
  end

  local set = {}
  for _, identifier in ipairs(t) do
    set[ts_utils.get_node_text(identifier, 0)[1]] = true
  end

  local identifiers = {}
  for identifier in pairs(set) do
    table.insert(identifiers, identifier)
  end
  return identifiers
end

M.get_identifiers = function(start_row)
  -- local original_start, _ = utils.get_selection_range()
  local node = ts_utils.get_node_at_cursor()
  if node == nil then
    vim.notify("No node found", "error")
    return
  end

  local jsx_element = find_jsx_element(node, "parent", start_row)
  if jsx_element == nil then
    vim.notify("JSX element not found", "error")
    return
  end

  local jsx_expressions = find_children_by_type(jsx_element, "jsx_expression")
  local identifiers = find_indentifiers_in_expressions(jsx_expressions)
  table.sort(identifiers)
  return identifiers
end

return M
