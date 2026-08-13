# content_modify

Apply one or more edit operations (save, publish, delete, add/remove component,
and so on) to the page, template, or component currently held in the content
editor's session store. This is the action side of the content editor; the
[content_editor](content_editor.md) tag renders the form and this tag processes
the submission. This tag is part of the Interchange admin UI toolset (the tags
in `code/UI_Tag/`, loaded when the admin UI feature is enabled), not a
storefront tag.

## Syntax

    [content_modify op name type]
    [content_modify op=publish name=index.html type=page]

Standalone tag (no end tag). The return value is `1` on success (or the result
of an immediate action); it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default            | Description |
|-----------|--------------------|-------------|
| `op`      | CGI `ui_content_op` | One or more whitespace/comma-separated operation names to apply. |
| `name`    | CGI `ui_name`      | Name of the item to operate on. |
| `type`    | CGI `ui_type`      | Item type: `page`, `template`, or `component`. |

Positional order: `op`, `name`, `type` (three positional parameters).

The tag declares `addAttr`; `values_ref` may be supplied to override the CGI
values hash the defaults are read from.

## Description

`[content_modify]` calls `UI::ContentEditor::content_modify`. When `op`, `name`,
or `type` is not passed, each falls back to the corresponding CGI variable
(`ui_content_op`, `ui_name`, `ui_type`), which is how the editor form's hidden
fields drive it.

If the operation is one of the registered *immediate* actions, it runs at once
and its result is returned. Otherwise the tag fetches the named item from the
session content store (dying via the editor's error mechanism if it is not
found) and applies each operation in turn, choosing a type-specific handler
where one exists and a common handler otherwise. Unknown operations and failed
operations are reported through the editor's error/warning functions. On
completion it returns `1`.

Because the item is read from the editor's session store, `[content_modify]` is
meant to run after a `[content_editor]` form has populated that store for the
same item.

## Examples

The editor exposes this tag to its own form template through the scratch
variable `ce_modify`, so a submit target typically expands to:

    [content-modify]

Applied explicitly, publishing an edited page whose details are in the CGI
submission:

    [content_modify op=publish]

Naming everything explicitly:

    [content_modify op=save name=search_box type=component]

## Notes

The set of valid operation names (immediate actions, per-type actions, and
common actions) is defined by dispatch tables inside `UI::ContentEditor`; this
page documents the three attributes the tag reads and the CGI fallbacks, not
the full operation catalog. Passing an unrecognized `op` produces an error
through the editor rather than a silent no-op.

## See also

- [content_editor](content_editor.md), [content_info](content_info.md)
- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/content_modify.coretag` (registered as the tag
`content-modify`; ITL treats hyphen and underscore in tag names as
equivalent). Implemented by `UI::ContentEditor::content_modify`
(`dist/lib/UI/ContentEditor.pm`).
