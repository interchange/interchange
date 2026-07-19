# links

Renders a list of options as clickable links instead of a form control. Each
link resubmits the current page with the field set to that option's value, so
it works like a navigable radio group.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws it for
a field. Attribute values shown here are Interchange Tag Language (ITL) tag
attributes.

## Usage

    [display type=links name=FIELD passed="a=Apple,b=Banana"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`links`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable each link sets |
| `value` | (empty) | Current value; the matching link is emphasized |
| `passed` / `lookup` / `lookup_query` | (none) | Source of the option list |
| `joiner` | `<br>` | Markup between links |
| `href` | current page (`MV_PAGE`) | Page each link targets |
| `form` | `mv_action=return` | Extra form parameters carried in the link |
| `template` | (built-in) | Per-link HTML template |
| `o_template` | (built-in) | Template for `~~Region~~` group headings |
| `extra` | (none) | Attributes added to each `<a>` tag |
| `nbsp` | off | Convert label spaces to `&nbsp;` |
| `secure` | off | Build secure (HTTPS) links |
| `empty` | off | Include options with an empty value |

## Description

`links` maps to `Vend::Form::links`. For each option it builds an anchor whose
URL (via `tag_area`) reloads `href` with `name=value` plus the `form`
parameters; the option matching the current `value` is wrapped in `<b>`. Labels
are HTML-encoded unless a `decode_entities` pre-filter is set. An option value
of the form `~~Text~~` is treated as a bold group heading rather than a link.
Links are joined with `joiner` (a line break by default).

## Examples

Category links that reload the page with `cat` set:

    [display type=links name=cat value="books" passed="books=Books,music=Music"]

Rendered HTML (trimmed; URLs abbreviated):

    <a href="/cgi-bin/...?cat=books...">
      <b>Books</b>
    </a>
    <br>
    <a href="/cgi-bin/...?cat=music...">Music</a>

Lay the links out on one line with a separator, keeping label spaces intact:

    [display type=links name=cat joiner=" | " nbsp=1
             passed="new=New Arrivals,sale=On Sale"]

## See also

- [radio](radio.md) — a form-control single-choice sibling
- [select](select.md) — dropdown single-choice control
- [templating](../guides/templating.md)

## Source

Defined in `code/Widget/links.widget`; maps to `Vend::Form::links` in
`lib/Vend/Form.pm`.
