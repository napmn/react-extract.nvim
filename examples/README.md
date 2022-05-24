# Example configurations

## Class component with Typescript

Configuration:

```lua
require("react-extract").setup({
  ts_template_before =
    "type [COMPONENT_NAME]Props = {\n[TYPE_PROPERTIES]}\n[EMPTY_LINE]\n"
    .. "export class [COMPONENT_NAME] extends React.Component<[COMPONENT_NAME]Props> {\n"
    .. "[INDENT]constructor(props: [COMPONENT_NAME]Props) {\n"
    .. "[INDENT][INDENT]super(props)\n"
    .. "[INDENT]}\n[EMPTY_LINE]\n"
    .. "[INDENT]render() {\n[INDENT][INDENT]return (\n",
  ts_template_after = "[INDENT][INDENT])\n[INDENT]}\n}",
  jsx_indent_level = 3,
  use_class_props = true
})
```

Example result:

```js
type ButtonContentProps = {
  answer: any
  count: any
  foo: any
}

export class ButtonContent extends React.Component<ButtonContentProps> {
  constructor(props: ButtonContentProps) {
    super(props)
  }

  render() {
    return (
      <div className="to-be-extracted">
        <div>{this.props.answer + this.props.count}</div>
        <span>{this.props.answer}</span>
        <span>{this.props.foo()}</span>
        <span>some content</span>
        <span>some other content</span>
      </div>
    )
  }
}
```
