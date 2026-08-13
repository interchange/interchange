# catch

Handles errors raised inside a matching `[try]` block, in the manner of a
try/catch construct. Reach for it to recover from a page or checkout step that
died — showing a message, setting an error, or flagging a scratch variable —
instead of letting the failure abort the request.

## Syntax

    [try] ... [/try]
    [catch] error handling [/catch]

    [catch label]
        [catch error-set="Group" error-scratch="failed"]
            fallback text, may contain $ERROR$
        [/catch]

Container tag (has an end tag and processes its body). It is meaningless on its
own — it reads the error captured by the [try](try.md) block with the same
label.

## Attributes

| Attribute       | Default   | Description |
|-----------------|-----------|-------------|
| `label`         | `default` | Label tying this `[catch]` to a `[try]` of the same label. |
| `exact`         | `0`       | Treat each collected error line as a literal pattern to match. |
| `joiner`        | `\n`      | String used to join multiple matched messages. |
| `error_set`     | (none)    | Record the resulting text as an error under this name. |
| `error_scratch` | (none)    | Set this scratch variable to `1` when the block fires. |
| `hide`          | `0`       | Perform side effects but return nothing. |

Positional order: `label`. The tag accepts arbitrary additional attributes
(`addAttr`).

## Description

`[try]` runs its body inside a Perl `eval`; anything that dies is stored in the
session under the block's label (`$Vend::Session->{try}{label}`). `[catch]` with
the same label inspects that stored error:

- If **no** error was recorded, `[catch]` behaves like a failed conditional: it
  emits the `[else] ... [/else]` portion of its body (if any) and drops the
  main body.
- If an error **was** recorded, `[catch]` emits its main body (the `[if]`
  portion). Any literal `$ERROR$` in the body is replaced with the captured
  error text.

Within the body you can match specific errors and substitute custom text using
inline blocks of the form `[/regex/]message[//]`: each block whose regular
expression matches the captured error contributes its `message` to the output
(joined by `joiner`). If no such block matches, the plain body with `$ERROR$`
expansion is used. Set `exact` to match the collected error lines literally
rather than as regexes.

The `error_set` option additionally records the result as a named error (so it
shows up in [error](error.md)), and `error_scratch` sets a scratch flag you can
test later in the page — the common pattern in checkout routes.

Leading and trailing whitespace is trimmed from the returned text. With `hide`
set, the side effects still run but nothing is output.

## Examples

Guard a block and show the error if it failed:

    [try]
        [perl]die "boom\n" if $CGI->{force_error}; return "ok";[/perl]
    [/try]
    [catch]
        Something went wrong: $ERROR$
    [/catch]

Real-world checkout pattern (from the strap `log_transaction`) — record the
failure as a named error and set a scratch flag the route can test:

    [try]
        ... payment processing ...
    [/try]
    [catch error-set="Payment process" error-scratch="mv_route_failed"]
        There was an error accepting payment: $ERROR$
    [/catch]

## Notes

- `[try]` and `[catch]` must share a label; the default label is `default`, so
  an unlabeled pair works together.

## See also

- [try](try.md) — the block whose errors this tag handles
- [error](error.md) — display errors recorded with `error-set`
- [if](if.md), [either](either.md) — related conditionals

## Source

Defined in `code/SystemTag/catch.coretag` (inline `Routine`). The paired
`[try]` tag is implemented by `Vend::Interpolate::try`.
