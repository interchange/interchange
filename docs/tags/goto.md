# goto

Skips all page content from the `[goto]` tag forward to a matching
[label](label.md) tag, optionally only when a condition is true. Reach for it
to jump over a section of a page — for example to bail out of the rest of a
page once you know it should not be rendered.

## Syntax

    [goto name]
    [goto name=labelname if=condition]

Standalone tag (no end tag). It is a parser control tag, not an ordinary tag:
it is handled specially and cannot be called from embedded Perl as
`$Tag->goto(...)`.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (none)  | The name of the [label](label.md) to jump to. |
| `if`      | (true)  | Only jump when this value is true. |

Positional order: `name`, `if`.

The `if` attribute (and its counterpart `unless`) is a plain truth test on
the attribute's already-interpolated value — *not* an [if](if.md)-style
`type term op` test. A value of `0`, empty, or whitespace is false; anything
else is true. There is also an `abort` attribute, used only in the "no name"
form below.

## Description

When `[goto]` fires, Interchange discards everything remaining in the current
parse buffer up to and including the matching `[label name=...]` tag, then
continues parsing after that label. Concretely (`goto_buf` in
`lib/Vend/Parse.pm`):

- If a matching `[label name=...]` is found later in the buffer, the text
  between the `[goto]` and that label is removed and parsing resumes after
  the label.
- If no matching label is found but a `</body>` tag exists, everything up to
  `</body>` is removed.
- If neither is found, the rest of the buffer is discarded and the page is
  sent as-is.

The `[label]` must come *after* the `[goto]`; this is a forward skip only, so
do not use it to build loops.

### Conditional skip

With `if` (or `unless`), the jump happens only when the condition is
true/false respectively. The condition is evaluated to a plain truth value
*before* `[goto]` runs, so interpolate any test into it:

    [set go]0[/set]
    [goto name="there" if="[scratch go]"]
    This line is still shown, because [scratch go] is 0.
    [label there]

### The no-name form

`[goto]` with no `name` (or an empty name) stops the page immediately: the
rest of the buffer is discarded and the response is sent. Add `abort=1` to
also abort the request's normal completion.

## Examples

Skip a block when the visitor is not logged in:

    [goto name=members_only if="[if !session logged_in]1[/if]"]
    ... members-only content, skipped for anonymous visitors ...
    [label members_only]

End the page early once an error is known:

    [if scratch fatal_error]
    An error occurred; please try again.
    [goto]
    [/if]
    ... the rest of this page is not rendered ...

## Notes

Skipping past an end tag with `[goto]` will leave unbalanced tags and can
break the page — the skipped region should contain whole, balanced markup.

Use one `[goto]`/`[label]` pair per parse buffer. Because `goto_buf` matches
the first label of the given name in the remaining buffer, multiple pairs on
one page can interact in surprising ways.

## See also

[label](label.md), [if](if.md), [bounce](bounce.md); the
[templating](../guides/templating.md) guide.

## Source

Parser control tag. Registered in `%Routine`/`%Special` in
`lib/Vend/Parse.pm` (the `%Routine` entry is a stub returning `''`); the real
behavior is in `Vend::Parse::start` (the `$tag eq 'goto'` branch) and the
`Vend::Parse::goto_buf` helper.
