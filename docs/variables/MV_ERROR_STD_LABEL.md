# MV_ERROR_STD_LABEL

Overrides the default markup the [error](../tags/error.md) tag emits for a
field's standard label. Reach for it to restyle how required-field labels and
their error messages are rendered catalog-wide.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_ERROR_STD_LABEL  template-text

The value is a template used for the `std_label` output of the `error` tag.
Default: unset (the built-in template is used).

## Description

The `error` tag can emit a "standard label" for a form field, combining the
field label with any error text. When `MV_ERROR_STD_LABEL` is set, its value
replaces the built-in template. The current built-in template wraps the label
in a `<span>` with a contrast CSS class (the `CSS_CONTRAST` variable, default
`mv_contrast`) and shows the error in small italics, and bolds the label when
the field is required. In the template, `{LABEL}` is the field label, `%s` is
filled with the error text, and `{REQUIRED text}` emits `text` only for
required fields.

If your custom template contains no `%s`, the error text is not shown — include
`%s` where you want it (unlike the unset case, Interchange does not append one
for you when `MV_ERROR_STD_LABEL` is set).

## Examples

Wrap error labels in a CSS class instead of inline color (`%s` receives the
error text):

    Variable  MV_ERROR_STD_LABEL  <span class="field-error">{LABEL} (%s)</span>

## See also

[error](../tags/error.md), the [forms](../guides/forms.md) guide.

## Source

Consumed in `code/SystemTag/error.coretag` via
`$::Variable->{MV_ERROR_STD_LABEL}`.
