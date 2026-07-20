# tabbed_display

Break a block of content into a dynamic tabbed panel display: each panel gets a
clickable tab, and selecting a tab reveals its panel. The admin UI uses it to
organize long record editors into tabs. This tag is part of the admin UI toolset
(the tags in `code/UI_Tag/`, loaded when the admin UI feature is enabled), not a
storefront tag.

## Syntax

    [tabbed_display OPTIONS]
        [tabbed-panel Title of panel one]
        Contents of panel one
        [/tabbed-panel]
        [tabbed-panel Title of panel two]
        Contents of panel two
        [/tabbed-panel]
    [/tabbed_display]

Container tag. Its body is interpolated as Interchange Tag Language (ITL), but
the result is not reparsed (`NoReparse`). The `[tabbed-panel TITLE]...
[/tabbed-panel]` blocks are markup parsed by this tag, not separate ITL tags:
`TITLE` becomes the tab label and the block body becomes the panel. It returns
the HTML (styles plus panels) for the tabbed widget.

## Attributes

All attributes are named (`addAttr`; no positional parameters). Sizes are in
pixels so the widget can compute its layout.

| Attribute              | Default    | Description |
|------------------------|------------|-------------|
| `titles`               | from body  | Panel titles as an array reference, or a null- or newline-separated string; overrides titles in the body. |
| `contents`             | from body  | Panel contents as an array reference or null-separated string; when set, the body is ignored. |
| `tab_bgcolor_template` | `#xxxxxx`  | Color template; each `x` is replaced to make a descending-brightness series (selected tab `#eeeeee`, then `#dddddd`, ...). Use `#ffffxx` for a yellow series. |
| `tab_height`           | `20`       | Height of a tab. |
| `tab_width`            | `120`      | Width of a tab. |
| `panel_height`         | `600`      | Height of the panel area. |
| `panel_width`          | `800`      | Width of the panel area. |
| `panel_id`             | `mvpan`    | Unique id; give a second display on the same page its own id. |
| `tab_horiz_offset`     | `10`       | Horizontal offset for tabs in multi-row tab layouts. |
| `tab_vert_offset`      | `8`        | Vertical offset for tabs in multi-row tab layouts. |
| `tab_style`            | see source | CSS applied to the tab portion. |
| `panel_style`          | see source | CSS applied to the panel portion. |
| `panel_prepend`        | none       | String prepended to every panel (e.g. `<table>`). |
| `panel_append`         | none       | String appended to every panel (e.g. `</table>`). |

## Description

If `contents` is supplied (array or null-separated), it provides the panels and
the body is ignored; otherwise the tag scans the body for `[tabbed-panel]`
blocks. Titles come from `titles` when given, else from each `[tabbed-panel
TITLE]` label. The rendering — color series, tab rows, and panel show/hide — is
produced by `Vend::Table::Editor::tabbed_display`.

`panel_prepend`/`panel_append` let each panel be wrapped in shared markup; the
table editor uses `<table>`/`</table>` so panel bodies can be plain table rows.

### Use in embedded Perl

The tag is callable as `$Tag->tabbed_display` with array references:

    my @titles   = ('Title 1', 'Title 2');
    my @contents = ('Content of panel 1', 'Content of panel 2');
    return $Tag->tabbed_display({
        titles       => \@titles,
        contents     => \@contents,
        panel_width  => 600,
        panel_height => 400,
        tab_bgcolor_template => '#ffffxx',
    });

## Examples

A two-panel display driven by the body:

    [tabbed_display panel_width=500 panel_height=300]
        [tabbed-panel Description]
        [item-field description]
        [/tabbed-panel]
        [tabbed-panel Pricing]
        Price: [item-price]
        [/tabbed-panel]
    [/tabbed_display]

A yellow tab series with a second display on the same page (note the distinct
`panel_id`):

    [tabbed_display tab_bgcolor_template="#ffffxx" panel_id=details]
        [tabbed-panel One]...[/tabbed-panel]
        [tabbed-panel Two]...[/tabbed-panel]
    [/tabbed_display]

## Notes

The `tab_height` and `tab_width` defaults documented here (`20` and `120`) are
the values the current code applies. The tag's older embedded documentation
lists `30` and `100`; the code wins. The selected-tab color of `#eeeeee` comes
from the default panel shade, not from `#xxxxxx` literally.

## See also

- [table_editor](table_editor.md)
- Concepts: [admin UI](../guides/admin-ui.md), [templating](../guides/templating.md)

## Source

Defined in `code/UI_Tag/tabbed_display.coretag` (registered `UserTag
tabbed-display`; hyphen and underscore spellings are equivalent when invoking
the tag). Implemented by `Vend::Table::Editor::tabbed_display`.
