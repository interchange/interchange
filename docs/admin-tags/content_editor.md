# content_editor

Render the admin UI editing form for an Interchange page, template, or
component (the WYSIWYG-style content editor). This tag is part of the
Interchange admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin
UI feature is enabled), not a storefront tag.

## Syntax

    [content_editor name=NAME type=page]
    FORM_TEMPLATE
    [/content_editor]

Container tag (has an end tag). The body, when present, is used as the form
template for the editor. The return value is the editor's HTML form; it is not
reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name of the item to edit (page name, template name, or component name). |
| `type`    | none    | What is being edited: `page`, `template`, or `component`. Determines which editor is invoked. |

Positional order: `name`.

The tag declares `addAttr`; the editor reads many further options (styling
widths, list/prefix names, `new`, and so on) from the options hash. These are
consumed by `UI::ContentEditor` and are not enumerated here — see that module.

## Description

`[content_editor]` is a thin front end to `UI::ContentEditor::editor`, which
dispatches on `type`:

- `type=page` calls the page editor, which reads the page (splitting it into
  its overall settings and per-region components) and builds the editing form.
- `type=template` calls the template editor for a page template's regions,
  components, and controls.
- `type=component` calls the component editor for a single reusable component's
  fields.

If `type` is none of those, the tag returns an error message. As a side effect
it sets the scratch variable `ce_modify` to `[content-modify]`, the companion
tag that applies edits.

The tag body, if given, is passed through as the form template used to render
the editor; when omitted, the built-in template for that type is used.

## Examples

Edit a component named `search_box`, taking the component name from a CGI
variable (as the admin `component_editor` include does):

    [content_editor name="[cgi ui_name]" type="component"]
    ... form template ...
    [/content_editor]

Edit the page `index.html`:

    [content_editor name="index.html" type="page"]

## Notes

This tag drives a large subsystem; the admin UI wraps it in the
`content_editor`, `content_components`, and `content_templates` pages and their
`include/` form templates. The set of recognized options is defined by
`UI::ContentEditor` rather than by the tag itself, so this page documents the
dispatch and the two attributes the tag reads directly, and points to the
module for the rest.

The related admin tags [content_info](content_info.md) (list available
components/templates) and [content_modify](content_modify.md) (apply an edit
operation) are normally used alongside it.

## See also

- [content_info](content_info.md), [content_modify](content_modify.md)
- [table_editor](table_editor.md)
- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/content_editor.coretag` (registered as the tag
`content-editor`; ITL treats hyphen and underscore in tag names as
equivalent). Implemented by `UI::ContentEditor::editor`
(`dist/lib/UI/ContentEditor.pm`), which dispatches to `page_editor`,
`template_editor`, or `component_editor`.
