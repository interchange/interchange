# calc

Evaluate the body as Perl and return the result. Reach for it for small
inline calculations or one-line expressions on a page — arithmetic, a lookup
through `$Tag`, setting a session value — without the heavier setup of
[perl](perl.md).

## Syntax

    [calc] EXPRESSION [/calc]

Container tag (has an end tag). The body is first interpolated for Interchange
Tag Language (ITL) — nested tags are expanded — and the resulting text is then
evaluated as Perl. The value of the last expression is returned. Use
[calcn](calcn.md) for the non-interpolated variant.

## Attributes

None. `[calc]` takes no attributes; everything is in the body.

## Description

`[calc]` runs its body through `Vend::Interpolate::tag_calc`. Because the tag
is declared `Interpolate`, any ITL in the body is expanded *before* the Perl
runs, so you can build an expression out of tag output.

The Perl executes inside Interchange's `Safe` compartment (the same sandbox as
[perl](perl.md)), which restricts dangerous operations. Within it the usual
Interchange globals are available, including `$Tag`, `$Session`, `$Values`,
`$CGI`, `$Scratch`, and `$Items`. The return value is the last evaluated
expression; call bare `return` to return nothing.

Variable state persists across `[calc]` blocks on the same page: a variable set
in one block is visible in later blocks, so you can accumulate a value through a
loop.

If the body dies (for example, a division by zero or a Safe violation), the
error is logged; when the block is inside a [try](try.md) with a label, the
message is stored in `$Session->{try}{label}` for a [catch](catch.md) block to
handle. On error `[calc]` returns an empty string inside Safe (0 otherwise).

## Examples

A simple arithmetic expression:

    Current magic number is: [calc]2 + int(rand(10))[/calc]

Read a session value through `$Tag`:

    Welcome, [calc]$Tag->data('session', 'username')[/calc]

Set a value and display it (the assignment's result is returned):

    [calc]$Session->{mv_order_number} = $Values->{mv_order_number}[/calc]

Return nothing (perform work with no output):

    [calc] my $n = 5; $Scratch->{count} = $n; return; [/calc]

## Notes

`[calc]` is a lower-overhead alternative to [perl](perl.md): it takes no
arguments, pre-opens no database tables, and does no extra wrapping. Use
`[perl]` (or [mvasp](mvasp.md)) when you need table access or a larger program.

Because the body is interpolated first, a literal `[` in your Perl will be
treated as the start of an ITL tag. When that is a problem, use
[calcn](calcn.md), whose body is not pre-interpolated.

Embedded Perl runs only when the catalog permits it; see
[perl embedding](../guides/perl-embedding.md) for the security model.

## See also

- [calcn](calcn.md)
- [perl](perl.md), [mvasp](mvasp.md)
- [try](try.md), [catch](catch.md)
- Concepts: [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/calc.coretag`. Implemented by
`Vend::Interpolate::tag_calc`.
