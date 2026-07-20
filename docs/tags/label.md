# label

Marks the point a [goto](goto.md) jumps to. On its own it produces no output;
it is simply a named marker in the page for the parser's forward-skip
mechanism.

## Syntax

    [label name]
    [label name=labelname]

Standalone tag (no end tag). It is a marker read by [goto](goto.md), not an
ordinary tag, and has no useful embedded-Perl call.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (none)  | The label name a matching [goto](goto.md) targets. |

Positional order: `name`.

The bare (`[label name]`), positional-name, and quoted
(`[label name="name"]`) forms are all recognized by the [goto](goto.md)
scanner.

## Description

`[label]` is inert during normal rendering: its routine returns the empty
string, so a page that reaches a `[label]` without any preceding jump simply
emits nothing where it stands. Its only purpose is to give
[goto](goto.md) a place to resume. A `[goto name=X]` removes everything from
itself up to and including the `[label name=X]` that follows it.

Because it is only a marker, `[label]` is not an end tag and does not enclose
anything; the region skipped is defined entirely by the positions of the
`[goto]` and the `[label]`.

## Examples

    [goto name=skip if="[scratch hide_details]"]
      Detailed description shown only when hide_details is off.
    [label skip]
    Always shown.

## See also

[goto](goto.md); the [templating](../guides/templating.md) guide.

## Source

Parser control marker. The `%Routine` entry in `lib/Vend/Parse.pm` is a stub
returning `''`; the label is located by the regex in
`Vend::Parse::goto_buf` when a [goto](goto.md) fires.
