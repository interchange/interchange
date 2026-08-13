# zerofix

Strips leading zeros from the value.

## Syntax

    [filter zerofix]TEXT[/filter]
    [value name=field filter="zerofix"]

`zerofix` takes no arguments.

## Description

The filter removes every `0` at the very start of the value and returns the
rest. A value with no leading zero is returned unchanged. A value consisting
entirely of zeros becomes the empty string.

Two edge cases follow from the implementation (`/^0*(.*)/`, returning the
captured remainder):

- Zeros are only stripped from the left end. `zerofix` on `0.50` yields `.50`,
  and interior or trailing zeros are untouched.
- The capture stops at the first line break, so on multi-line input everything
  from the first newline onward is discarded. Use `zerofix` on single-line,
  numeric-style values.

## Examples

    [filter zerofix]000123456[/filter]

produces:

    123456

No leading zero, unchanged:

    [filter zerofix]4200[/filter]

produces:

    4200

All zeros become empty:

    [filter zerofix]000[/filter]

produces (nothing):


## See also

- [digits](digits.md) — keep only digit characters
- [integer](integer.md) — coerce to an integer
- [commify](commify.md) — add thousands separators to a number

## Source

Defined in `code/Filter/zerofix.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
