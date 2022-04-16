local utils = require("react-extract.utils")

local M = {}

local ACTION_MATCH_PATTERNS = {
  "^Add import",
  "^Import"
}

local insert_component_content = function(filepath, lines, indent_char)
  vim.api.nvim_command("edit " .. filepath)
  local new_buffer = vim.api.nvim_get_current_buf()
  local component_name = filepath:match("^.+/(.+)[.].+$")

  -- TODO: make this configurable
  local all_lines = {
    "export const " .. component_name .. " = () => {",
    string.rep(indent_char, utils.get_indent(indent_char, 1)) .. "return (",
  }
  local end_lines = {
    string.rep(indent_char, utils.get_indent(indent_char, 1)) .. ")",
    "}"
  }
  utils.table_extend(all_lines, lines)
  utils.table_extend(all_lines, end_lines)

  vim.api.nvim_buf_set_lines(new_buffer, 0, -1, false, all_lines)
  vim.api.nvim_command("write")

  return component_name
end

local autoimport_component = function()
  -- heavily inspired by implementation in https://github.com/neovim/neovim/blob/master/runtime/lua/vim/lsp/buf.lua
  local tsserver = utils.get_tsserver()
  if tsserver == nil then
    return
  end

  local context = {
    -- we dont use vim.diagnostic.get here because its not updated yet
    -- at this point
    diagnostics = {{ code = 2304 }} -- code for "Cannot find name ..." error
  }
  local params = vim.lsp.util.make_range_params()
  params.context = context

  -- defer code action request
  vim.defer_fn(function()
    vim.lsp.buf_request_all(0, "textDocument/codeAction", params, function(results)
      local import_action
      for client_id, result in pairs(results) do
        if client_id == tsserver.id then
          for _, action in pairs(result.result or {}) do
            for _, pattern in pairs(ACTION_MATCH_PATTERNS) do
              if string.find(action.title, pattern) ~= nil then
                import_action = action
                break
              end
            end
          end
        end
      end

      if import_action == nil then
        return
      end

      local command_params = {
        command=import_action.command.command,
        arguments=import_action.command.arguments,
        workDoneToken=import_action.command.workDoneToken
      }

      vim.lsp.buf_request(0, "workspace/executeCommand", command_params)
    end)
  end, 350)
end

local replace_content_in_original = function(
  original_buffer,
  original_start,
  original_end,
  indentation_str,
  new_component_name
)
  vim.api.nvim_set_current_buf(original_buffer)

  vim.api.nvim_buf_set_lines(
    original_buffer,
    original_start,
    original_end,
    false,
    {indentation_str .. "<" .. new_component_name .. " />"}
  )

  -- set cursor on new component so we can get code actions
  vim.api.nvim_win_set_cursor(0, { original_start + 1, #indentation_str + 1 })

  autoimport_component()
end

local reduce_lines_indent = function(lines, indent_char)
  local min_indent = utils.get_indent(indent_char, 2)
  local initial_indent = #string.match(lines[1], "^%s+")
  local sub_indent = math.max(initial_indent - min_indent, min_indent)
  local sub_indent_pattern = "^" .. string.rep("%s", sub_indent)

  local reduced_lines = {}
  for _, line in ipairs(lines) do
    local reduced_line = string.gsub(line, sub_indent_pattern, "")
    table.insert(reduced_lines, reduced_line)
  end
  return reduced_lines
end

local handle_user_input = function(filepath)
  if filepath == nil or filepath == "" then
    return
  end

  if not utils.create_file(filepath) then
    return
  end

  local original_buffer = vim.api.nvim_get_current_buf()
  local original_start, original_end = utils.get_selection_range()

  local selection_lines = vim.api.nvim_buf_get_lines(
    original_buffer,
    original_start,
    original_end,
    true
  )
  local indent_char = string.sub(selection_lines[1], 1, 1)
  local indent_str = utils.get_indentation_string(
    selection_lines[1],
    indent_char
  )
  local selection_lines = reduce_lines_indent(selection_lines, indent_char)
  local component_name = insert_component_content(
    filepath,
    selection_lines,
    indent_char
  )

  replace_content_in_original(
    original_buffer,
    original_start,
    original_end,
    indent_str,
    component_name
  )
end

M.extract_to_component = function()
  local input_opts = {
    prompt = "Enter path to new component: ",
    completion = "dir",
  }
  vim.ui.input(input_opts, handle_user_input)
end

return M
