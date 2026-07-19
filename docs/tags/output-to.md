# output-to

Capture the body of the tag and append it to a named output buffer instead of
emitting it where the tag appears. You pair it with [unpack](unpack.md) to
"unpack" those buffers elsewhere on the page — for example, collecting markup
scattered through a page into a single `<head>` block.

## Syntax

    [output-to name]BODY[/output-to]
    [output-to name="buffername"]BODY[/output-to]

Container tag (has an end tag, processes its body). The body is *not* returned
in place; it is stored and produces empty output at the tag's location. The
stored body is interpolated later, when [unpack](unpack.md) emits the buffer.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | `''`    | Name of the output buffer to append the body to. |

Positional order: `name`.

The tag accepts arbitrary extra attributes (`addAttr`), but only `name` is
used.

## Description

Interchange builds the final page in an ordered list of output segments
(`@Vend::Output`). `[output-to]` pushes its body onto that list as a new
segment and records the segment's index under the lowercased buffer `name` in
`%Vend::OutPtr`. Nothing is returned at the point of use, so the body
disappears from its original location.

The companion [unpack](unpack.md) tag looks up a buffer by name and emits all
segments collected under it, in the order they were captured. This lets you
write content in the natural place in a template but have it rendered
somewhere earlier or later — the classic case being CSS or `<script>` tags
declared inside a component but rendered in the document head.

Passing an empty name (`name=""`) targets the default (unnamed) buffer.

## Examples

Collect two fragments into a buffer named `htmlhead` and unpack them in the
document head:

    <html>
    <head>
    [unpack htmlhead]
    </head>
    <body>

    ...somewhere deep in a component...
    [output-to htmlhead]
    <style>.sale { color: red }</style>
    [/output-to]

    ...and in another component...
    [output-to htmlhead]
    <script src="/js/widget.js"></script>
    [/output-to]

Both `<style>` and `<script>` fragments render inside `<head>`, in capture
order, even though they were written further down the page.

## Notes

- The buffer name is lowercased, so `htmlHead` and `htmlhead` are the same
  buffer.
- Order of appearance within a buffer is preserved; a buffer accumulates every
  `[output-to]` body that names it.
- The captured body is interpolated by [unpack](unpack.md), not at capture
  time, so tags inside the body run in the context where they are unpacked.

## See also

- [unpack](unpack.md) — emit the buffers this tag fills
- [seti](seti.md) / [set](set.md) — store a value in a scratch variable
- [templating guide](../guides/templating.md)

## Source

Defined in `code/SystemTag/output_to.tag` (registered tag name `output-to`).
Implemented by the inline `Routine` in that file, which manipulates
`@Vend::Output` and `%Vend::OutPtr`.
