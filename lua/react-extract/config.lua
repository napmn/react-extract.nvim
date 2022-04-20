local M = {}

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
  use_autoimport = true,
  autoimport_defer_ms = 350
}

M.apply_options = function(user_opts)
  return vim.tbl_deep_extend("force", {}, defaults, user_opts or {})
end

return M
