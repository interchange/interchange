# try

Run a block of ITL and trap any fatal error (`die`) it raises, storing the
error under a label instead of aborting the page. Pair it with a matching
[catch](catch.md) block to display or handle the failure. Reach for it around
code that can die — a risky [calc](calc.md), a [query](query.md), a payment
call.

## Syntax

    [try label=NAME]
    ...ITL that might die...
    [/try]
    [catch NAME]error handling[/catch]

Container tag (has an end tag). The body is interpolated normally; if it
completes, its output is returned like any block.

## Attributes

| Attribute | Default   | Description |
|-----------|-----------|-------------|
| `label`   | `default` | Name tying this block to its [catch](catch.md) block (positional). |
| `status`  | off       | Return `1` on success, `0` on error, instead of the body output. |
| `hide`    | off       | Suppress the body output regardless of success or failure. |
| `clean`   | off       | Suppress the body output only if it errored; otherwise return the partial output produced before the error. |

Positional order: `label`.

## Description

`[try]` clears its error slot (`$Session->{try}{`*label*`}`), removes any active
`die` handler, and evaluates its body inside a Perl `eval`. If the body dies,
the error text is appended to `$Session->{try}{`*label*`}` and normal parsing
continues after the block; the page is not aborted. The matching
[catch](catch.md) block — identified by the same label — then runs, and can
read the stored error via `$Session->{try}{`*label*`}`.

By default `[try]` returns whatever output the body produced up to the point of
failure. The options change that:

- `status` makes the tag return a boolean (`1` ok, `0` failed) — handy inside an
  [if](if.md).
- `hide` throws the body output away in all cases (run purely for side effects).
- `clean` returns the body output only when it succeeded, so a half-finished
  block leaves nothing on the page.

The label defaults to `default`, so a single unlabeled `[try]`/`[catch]` pair
works without naming.

## Examples

Trap a division-by-zero in a [calc](calc.md) and show a message via
[catch](catch.md):

    [set divisor]0[/set]

    [try label=div]
      [calc] 1 / [scratch divisor] [/calc]
    [/try]

    [catch div]Division error[/catch]

Show the verbatim error message that `[try]` stored:

    [try label=divide][calc] 1 / [scratch divisor] [/calc][/try]

    [catch divide]
      Error was: [calc]$Session->{try}{divide}[/calc]
    [/catch]

Use `status` to branch on success:

    [if type=explicit compare="[try status=1 label=chk][query ...][/query][/try]"]
    Query ran.
    [else]
    Query failed — see log.
    [/else]
    [/if]

## Notes

`[try]` only traps fatal errors (`die` / uncaught exceptions). ITL that merely
produces wrong or empty output without dying is not an "error" as far as `[try]`
is concerned. The trapped message persists in the session under its label until
the next `[try]` with that label resets it.

## See also

- [catch](catch.md), [calc](calc.md), [if](if.md)
- Concepts: [logging and debugging](../guides/logging-debugging.md),
  [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/try.coretag`. Implemented by
`Vend::Interpolate::try`.
