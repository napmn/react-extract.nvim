local M = {}

local available_local_extract_strategies = {
  EOF = true,
  BEFORE = true,
  AFTER = true
}
local default_local_extract_strategy = "BEFORE"

local defaults = {
  ts_type_property_template = "[INDENT][PROPERTY]: any\n",
  ts_template_before =
    "type [COMPONENT_NAME]Props = {\n[TYPE_PROPERTIES]}\n[EMPTY_LINE]\n"
    .. "export const [COMPONENT_NAME]: React.FC<[COMPONENT_NAME]Props> = "
    .. "([PROPERTIES]) => {\n"
    .. "[INDENT]return (\n",
  ts_template_after = "[INDENT])\n}",
  js_template_before =
    "export const [COMPONENT_NAME] = "
    .. "([PROPERTIES]) => {\n"
    .. "[INDENT]return (\n",
  js_template_after = "[INDENT])\n}",
  jsx_indent_level = 2,
  use_class_props = false,
  use_autoimport = true,
  autoimport_defer_ms = 350,
  local_extract_strategy = default_local_extract_strategy
}

M.apply_options = function(user_opts)
  user_opts = user_opts or {}
  if user_opts.local_extract_strategy ~= nil
    and available_local_extract_strategies[user_opts.local_extract_strategy] == nil then
      vim.notify("Extract strategy " .. user_opts.local_extract_strategy .. " does not exist.", "error")
      user_opts.local_extract_strategy = default_local_extract_strategy
    end
  return vim.tbl_deep_extend("force", {}, defaults, user_opts or {})
end

return M
