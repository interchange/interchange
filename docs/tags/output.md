# output

Redirects the output that follows it into a named region ("space") of the
page instead of the normal document flow. Reach for it to collect fragments —
such as `<head>` additions or a sidebar — from anywhere on a page and have
them assembled into the right place by the page template.

## Syntax

    [output name=spacename]
    [output name=""]

Standalone tag (no end tag). It is a parser control tag handled specially in
`lib/Vend/Parse.pm`; there is no embedded-Perl `$Tag->output(...)` call.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (none)  | The named region subsequent output is sent to. |

The tag also accepts the extended-output attributes read by `destination()`:
`output_filter` (a [filter](filter.md) applied to the region), `output_extended`,
and `no_image_parse` (skip the automatic image-path rewrite for the region).

## Description

Normally everything a page emits accumulates in one buffer that becomes the
response body. `[output name=spacename]` switches the destination so that
everything parsed *after* it is appended to the region `spacename` instead.
Emit `[output name=""]` to send output back to the default (main) region.

Named regions are stored in `@Vend::Output` / `%Vend::OutPtr` and are placed
into the finished page in one of two ways:

- **Page template placeholders.** `Vend::Page::templatize` replaces a
  `{{SPACENAME}}` placeholder (the region name upper-cased) in the catalog's
  page template with the collected contents of that region. This is how
  fragments like a page's `htmlhead` end up in the document `<head>` no
  matter where on the page they were produced.
- **Multi-output responses.** When any named region is used,
  `Vend::MultiOutput` is set and `Vend::Dispatch::response` emits each region
  (applying its `output_filter`, if any) in turn.

For the common case of capturing a *block* of a page into a region, the
container tag `[output-to name=...] ... [/output-to]` is usually more
convenient — it scopes the capture to its body rather than switching the
destination for everything that follows. `[output]` is the lower-level
standalone switch; both feed the same region machinery.

## Examples

Direct a stylesheet link into the `htmlhead` region, which the page template
drops into the document head via its `{{HTMLHEAD}}` placeholder:

    [output name=htmlhead]
    <link rel="stylesheet" href="[area href=special.css]">
    [output name=""]

Equivalent capture with the container companion tag:

    [output-to name=htmlhead]
    <link rel="stylesheet" href="[area href=special.css]">
    [/output-to]

## Notes

The region name is lower-cased internally; the matching template placeholder
is the upper-cased form (`htmlhead` region ↔ `{{HTMLHEAD}}` placeholder).

By default, image paths in a named region are rewritten just as in the main
output; pass `no_image_parse=1` to suppress that for the region.

## See also

[output-to](output-to.md), the [templating](../guides/templating.md) guide.

## Source

Parser control tag. Registered in `%Routine`/`%Special` in
`lib/Vend/Parse.pm` (the `%Routine` entry is a stub returning `''`); the real
work is in `Vend::Parse::start` (the `$tag eq 'output'` branch) and
`Vend::Parse::destination`. Regions are consumed by `Vend::Page::templatize`
and `Vend::Dispatch::response`.
