# input-filter

Registers (or removes) a filter that Interchange applies automatically to a CGI
variable on every future request in the session. Reach for it to sanitize or
normalize a form field once — for example forcing an email to lowercase or
stripping non-digits from a phone number — without repeating a `filter=`
attribute everywhere the value is read.

## Syntax

    [input-filter name op="filter1 filter2"] [/input-filter]
    [input-filter name=field remove=1] [/input-filter]
    [input-filter name] routine text [/input-filter]

Container tag (has an end tag). It produces no output; the body, if any, is a
Perl routine (see Description). Output is not interpolated.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (none)  | CGI variable to attach the filter to. |
| `op`      | (none)  | Filter(s) to apply, as understood by [filter](filter.md). |
| `routine` | (none)  | Perl expression run on the value (also acceptable as the body). |
| `remove`  | `0`     | Remove any registered filter for `name` instead of adding one. |

Positional order: `name`. Aliases: `var` and `variable` for `name`, `ops` for
`op`. The tag accepts arbitrary additional attributes (`addAttr`).

## Description

The tag maps to `Vend::Interpolate::input_filter`, which records the filter in
the session (`$Vend::Session->{Filter}`). Unlike the `Filter` catalog directive
(which is fixed at configuration time), an input-filter is set at run time from a
page and persists in the session, so it affects the named CGI variable on
subsequent submissions.

- With `op`, the named filter operations are stored for `name` and applied to
  incoming values of that variable.
- With a body (or `routine`), the text is treated as a Perl routine that is
  interpolated and run on the value.
- With `remove=1`, the registered filter for `name` is deleted.

The stored filter runs during input processing (`input_filter_do`), before your
pages read the value with [cgi](cgi.md) or [value](value.md) — so by the time
you read it, it is already filtered.

## Examples

Force the `email` field to lowercase on every submission:

    [input-filter email op=lower][/input-filter]

Strip everything but digits from a phone field:

    [input-filter name=phone op=digits][/input-filter]

Remove a previously registered filter:

    [input-filter name=email remove=1][/input-filter]

## Notes

- The filter lives in the session, so it applies until removed or the session
  ends — not just for the current page.
- To filter a value once at the point of use (without storing anything), use the
  `filter=` attribute on [cgi](cgi.md) or the [filter](filter.md) tag instead.

## See also

- [filter](filter.md) — apply filters to a block of text
- [cgi](cgi.md) — read CGI values (with an optional one-shot `filter=`)
- `Filter` directive — config-time input filters (see [../config/](../config/))
- Filter reference: [../filters/](../filters/)

## Source

Defined in `code/SystemTag/input_filter.coretag`. Implemented by
`Vend::Interpolate::input_filter` in `lib/Vend/Interpolate.pm`.
