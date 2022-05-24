local config = require("react-extract.config")
local utils = require("react-extract.utils")
local ts = require("react-extract.ts")
local opts

local M = {}

local ACTION_MATCH_PATTERNS = {
  "^Add import",
  "^Import"
}

local get_declaration_properties_str = function(properties)
  if #properties > 0 then
    return "{ " .. table.concat(properties, ", ") .. " }"
  end
  return ""
end


local get_constructor_properties_str = function(properties)
  local properties_str = " "
  for _, property in ipairs(properties) do
    properties_str = properties_str .. property .. "={" .. property .. "} "
  end
  return properties_str
end


local get_type_properties_str = function(properties, indent_char)
  local properties_str = ""
  for _, property in ipairs(properties) do
    local property_str = string.gsub(
      opts.ts_type_property_template,
      "%[INDENT%]",
      string.rep(indent_char, utils.get_indent(indent_char, 1))
    )
    property_str = string.gsub(property_str, "%[PROPERTY%]", property)
    properties_str = properties_str .. property_str
  end

  return properties_str
end


-- Replaces placeholders in component template string and returns
-- table of lines
local replace_placeholders_and_split = function(s, name, properties, indent_char)
  s = string.gsub(s, "%[COMPONENT_NAME%]", name)
  s = string.gsub(
    s,
    "%[PROPERTIES%]",
    get_declaration_properties_str(properties)
  )
  s = string.gsub(
    s,
    "%[INDENT%]",
    string.rep(indent_char, utils.get_indent(indent_char, 1))
  )
  s = string.gsub(
    s,
    "%[TYPE_PROPERTIES%]",
    get_type_properties_str(properties, indent_char)
  )
  local lines = utils.split(s, "\n")
  for i, line in ipairs(lines) do
    lines[i] = string.gsub(line, "%[EMPTY_LINE%]", "")
  end

  return lines
end


local construct_new_component_lines = function(
  component_name,
  lines,
  properties,
  indent_char,
  ext
)
  local all_lines = replace_placeholders_and_split(
    ext == "tsx" and opts.ts_template_before or opts.js_template_before,
    component_name,
    properties,
    indent_char
  )
  local end_lines = replace_placeholders_and_split(
    ext == "tsx" and opts.ts_template_after or opts.js_template_after,
    component_name,
    properties,
    indent_char
  )
  utils.table_extend(all_lines, lines)
  utils.table_extend(all_lines, end_lines)
  return all_lines
end


local get_new_component_position = function(node)
  local position
  if node ~= nil and opts.local_extract_strategy ~= "EOF" then
    if opts.local_extract_strategy == "BEFORE" then
      position, _, _ = node:start()
    elseif opts.local_extract_strategy == "AFTER" then
      position, _, _ = node:end_()
      position = position + 1 -- to match indexing with nvim
    end
  else
    position = vim.api.nvim_buf_line_count(0)
  end
  return position
end


-- adds empty line to the start or to the end based
-- on extract position strategy
local add_empty_line = function(lines)
  if opts.local_extract_strategy == "BEFORE" then
    table.insert(lines, "")
  else
    table.insert(lines, 1, "")
  end
end


local insert_component_content_to_new_file = function(
  filepath,
  lines,
  properties,
  indent_char
)
  vim.api.nvim_command("edit " .. filepath)
  local new_buffer = vim.api.nvim_get_current_buf()
  local component_name, ext = utils.get_filename_base_and_extension(filepath)

  lines = construct_new_component_lines(component_name, lines, properties, indent_char, ext)

  vim.api.nvim_buf_set_lines(new_buffer, 0, -1, false, lines)
  vim.api.nvim_command("write")

  return component_name
end

-- returns row number where component was inserted to and number of inserted lines
local insert_component_content_to_current_file = function(
  component_name,
  lines,
  properties,
  indent_char
)
  local _, ext = utils.get_filename_base_and_extension(vim.api.nvim_buf_get_name(0))
  lines = construct_new_component_lines(component_name, lines, properties, indent_char, ext)
  add_empty_line(lines)
  local node = ts.get_original_component_node()
  local position = get_new_component_position(node)

  vim.api.nvim_buf_set_lines(0, position, position, false, lines)
  return position, #lines
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
  end, opts.autoimport_defer_ms)
end


local replace_content_in_original = function(
  original_buffer,
  original_start,
  original_end,
  indentation_str,
  new_component_name,
  properties,
  use_autoimport
)
  vim.api.nvim_set_current_buf(original_buffer)

  local properties_str = get_constructor_properties_str(properties)

  vim.api.nvim_buf_set_lines(
    original_buffer,
    original_start,
    original_end,
    false,
    {
      indentation_str
      .. "<"
      .. new_component_name
      .. properties_str
      .. "/>"
    }
  )

  -- set cursor on new component so we can get code actions
  vim.api.nvim_win_set_cursor(0, { original_start + 1, #indentation_str + 1 })

  if use_autoimport then
    autoimport_component()
  end
end


local reduce_lines_indent = function(lines, indent_char)
  local min_indent = utils.get_indent(indent_char, opts.jsx_indent_level)
  local initial_indent = #string.match(lines[1], "^%s+")
  local sub_indent = initial_indent - min_indent
  local sub_indent_pattern = "^" .. string.rep("%s", sub_indent)

  local reduced_lines = {}
  for _, line in ipairs(lines) do
    local reduced_line = string.gsub(line, sub_indent_pattern, "")
    table.insert(reduced_lines, reduced_line)
  end
  return reduced_lines
end


-- adds prefix to each identifier based on it's original
-- position in extracted JSX
local add_prefix_to_identifiers = function(
  positions,
  lines,
  original_start,
  prefix
)
  local prefix_len = #prefix
  for row, row_positions in pairs(positions) do
    local line_index = row - original_start + 1
    local line = lines[line_index]
    -- keep track of indexes of already prefixed identifiers in current line
    local added_to_index = {}
    for _, position in pairs(row_positions) do
      local added_num = #utils.filter_table(added_to_index, position["col"], utils.less_than)
      line = string.sub(line, 1, position["col"] + added_num * prefix_len)
        .. prefix
        .. string.sub(line, position["col"] + 1 + added_num * prefix_len, -1)
      table.insert(added_to_index, position["col"])
    end
    lines[line_index] = line
  end

  return lines
end


local extract_handler = function(user_input, to_new_file)
  if user_input == nil or user_input == "" then
    return
  end

  if to_new_file and not utils.create_file(user_input) then
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
  local identifiers, positions = ts.get_identifiers(original_start)
  if opts.use_class_props then
    selection_lines = add_prefix_to_identifiers(
      positions,
      selection_lines,
      original_start,
      "this.props."
    )
  end
  selection_lines = reduce_lines_indent(selection_lines, indent_char)

  local component_name
  local inserted_before -- lines inserted before original component
  if to_new_file then
    component_name = insert_component_content_to_new_file(
      user_input,
      selection_lines,
      identifiers,
      indent_char
    )
    inserted_before = 0
  else
    component_name = user_input
    local new_component_start, inserted_num = insert_component_content_to_current_file(
      component_name,
      selection_lines,
      identifiers,
      indent_char
    )
    inserted_before = new_component_start > original_start and 0 or inserted_num
  end

  replace_content_in_original(
    original_buffer,
    original_start + inserted_before,
    original_end + inserted_before,
    indent_str,
    component_name,
    identifiers,
    opts.use_autoimport and to_new_file
  )

  local key = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(key, 'm', false)
end


M.extract_to_current_file = function()
  local input_opts = { prompt = "Enter component name: " }
  vim.ui.input(input_opts, function(component_name) return extract_handler(component_name, false) end)
end


M.extract_to_new_file = function()
  local input_opts = {
    prompt = "Enter path to new component: ",
    completion = "dir",
  }
  vim.ui.input(input_opts, function(filename) return extract_handler(filename, true) end)
end


-- TODO map to new functions
M.extract_to_component = function()
end


M.setup = function(user_opts)
  opts = config.apply_options(user_opts)
end


return M
