# harness

Run a block of Interchange Tag Language (ITL) and check its output against an
expected value, reporting `OK`, `NOT OK`, or `DIED`. Reach for it when
writing regression or smoke tests for catalog tags and pages.

## Syntax

    [harness]BODY[/harness]
    [harness expected="..." name="..."]BODY[/harness]

Container tag (has an end tag and processes its body). The body is
interpolated as ITL, and the tag returns a one-line status string. Its own
output is not reparsed.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `expected` | `OK`    | Value the interpolated body result must match (as a regular expression). |
| `name`     | `testNNN` (auto-incrementing) | Label included in the result message to identify the test. |

Positional order: none (all parameters are named).

Because the tag declares `addAttr`, any other attribute is accepted and
ignored.

The `expected` and `not` values may also be supplied inside the body using
`[expected]...[/expected]` and `[not]...[/not]` marker blocks, which override
the `expected` attribute and set a "must not match" pattern respectively.

## Description

`[harness]` interpolates its body as ITL, then compares the result:

- If interpolation throws a Perl error, the tag returns
  `DIED in test NAME. $@: ...`.
- If an `expected` value is set (default `OK`), the result must match it as a
  regular expression, or the tag returns `NOT OK NAME: RESULT!=EXPECTED`.
- If a `not` value is set, the result must *not* match it, or the tag returns
  `NOT OK NAME: RESULT==NOT`.
- Otherwise the tag returns `OK NAME`.

Leading and trailing whitespace is trimmed from the body before evaluation.
Each unnamed harness gets an auto-incrementing name (`test001`, `test002`,
...); supply `name` to make failures easier to locate.

It is conceptually similar to [try](try.md)/[catch](catch.md), but instead of
trapping errors for display it asserts on the result and reports test status.

## Examples

Assert that a body produces the literal string `OK`:

    [harness]OK[/harness]

produces:

    OK test001

Assert against a specific value with a name:

    [harness name="price-check" expected="10.00"][price 00-0011][/harness]

If the price matches, this produces:

    OK price-check

otherwise something like:

    NOT OK price-check: 9.99!=10.00

Use the in-body `[expected]` marker instead of the attribute:

    [harness name="greeting"]
    [expected]Hello, world[/expected]
    Hello, world
    [/harness]

## Notes

`expected` and `not` are matched as Perl regular expressions, not as literal
strings, so regex metacharacters in the value are significant.

## See also

- [try](try.md)
- [catch](catch.md)
- Concepts: [logging and debugging](../guides/logging-debugging.md)

## Source

Defined in `code/SystemTag/harness.coretag` as an inline Routine, which calls
`Vend::Interpolate::interpolate_html` to evaluate the body.
