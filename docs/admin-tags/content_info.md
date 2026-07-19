# content_info

Return information about the components (or templates) available to the content
editor: an option list for a select widget, a single component's label or
class, or a component's parsed structure. This tag is part of the Interchange
admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin UI feature
is enabled), not a storefront tag.

## Syntax

    [content_info]
    [content_info templates=1]
    [content_info code=NAME label=1]

Standalone tag (no end tag). The return value is an option string or a single
value; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute    | Default      | Description |
|--------------|--------------|-------------|
| `dir`        | none         | Content directory to scan (passed through to the component/template lookup). |
| `templates`  | not set      | Operate on templates instead of components. |
| `delimiter`  | `,`          | Delimiter between option entries in the returned list. |
| `code`       | none         | A specific component/template code, used with `label`, `structure`, or `show_class`. |
| `label`      | not set      | Return just the label for `code`. |
| `show_class` | not set      | Return just the class for `code`. |
| `structure`  | not set      | Return the parsed component record for `code`. |
| `class`      | none         | Restrict the option list to components of this class (or `ALL`). |
| `no_sort`    | not set      | Do not sort the list by label. |
| `no_none`    | not set      | Omit the leading "No component" / "No template" entry. |

Positional order: `dir`.

The tag declares `addAttr`, so the options above are read from the options
hash.

## Description

`[content_info]` calls `UI::ContentEditor::content_info`. Its default job is to
build a `delimiter`-separated option list of the available components (or, with
`templates`, templates), each entry `code=Label`, with a default marker `*`
appended to labels of default items and a leading "No component"/"No template"
choice unless `no_none` is set. The list is cached per request.

When `code` is given together with a selector attribute, the tag instead
returns a single fact about that item: its `label`, its class (`show_class`),
or its full parsed `structure` record.

Results can be narrowed with `class` (only components whose class matches, or
`ALL`) and reordered with `no_sort`.

## Examples

Populate a template chooser (as the page editor does):

    [content_editor ... ][content_info templates=1][/content_editor]

Used directly to build a component dropdown:

    [accessories attribute=component type=select
        passed="[content_info]"]

Look up one component's label:

    [content_info code=search_box label=1]

## Notes

The option-list shape (`code=Label`, comma-delimited, with a `*` default
marker) matches what the form-widget builder expects for a `passed` option
string, which is why it is usually handed straight to a select widget.

The available-components/templates scan and the meaning of "class" are defined
by `UI::ContentEditor`; this page documents the attributes the tag reads and
the four return modes, not the internal component-discovery rules.

## See also

- [content_editor](content_editor.md), [content_modify](content_modify.md)
- [accessories](../tags/accessories.md)
- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/content_info.coretag` (registered as the tag
`content-info`; ITL treats hyphen and underscore in tag names as equivalent).
Implemented by `UI::ContentEditor::content_info`
(`dist/lib/UI/ContentEditor.pm`).
