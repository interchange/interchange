# vars_and_comments

Runs Interchange's standard variable-substitution and comment-stripping pass
over the value — the same preprocessing normally applied to a whole page.

## Syntax

    [filter vars_and_comments]TEXT[/filter]
    [value name=field filter="vars_and_comments"]

`vars_and_comments` takes no arguments. It is marked private, so it is not
offered in the admin UI's filter menus, but it works wherever filters are
applied.

## Description

The filter hands the value to `Vend::Interpolate::vars_and_comments`, the
routine Interchange runs on every page before tag interpolation. On the value
it performs the same steps that pass does:

- Reads and applies any `[pragma name value]` tags.
- Substitutes global Variables (`@_NAME_@`) and catalog Variables
  (`__NAME__`, `@__NAME__@`) with their configured values; if the
  `dynamic_variables` pragma is on, dynamic lookups are used.
- Removes `[comment]...[/comment]` blocks.
- Unwraps Interchange tags embedded in HTML comments (`<!--[tag ...]-->`
  becomes `[tag ...]`), unless the `no_html_comment_embed` pragma is set.

It does **not** interpolate ordinary ITL tags — only variables, pragmas, and
comments are processed. In restricted mode (`$Vend::restricted`) the routine
returns without making any substitutions, so the value is passed through
unchanged.

## Examples

With the catalog Variable `COMPANY` set to `Acme`:

    [filter vars_and_comments]Welcome to __COMPANY__[/filter]

produces:

    Welcome to Acme

A comment block in the input is removed:

    [filter vars_and_comments]Visible[comment] hidden [/comment] text[/filter]

produces:

    Visible text

## See also

- [variables](../variables/) — catalog and global Variable reference
- [pragmas](../pragmas/) — the pragmas honored by this pass
- [templating](../guides/templating.md) — how pages are interpolated

## Source

Defined in `code/Filter/vars_and_comments.filter`
(`CodeDef vars_and_comments Visibility private`); calls
`Vend::Interpolate::vars_and_comments` (`lib/Vend/Interpolate.pm`).
