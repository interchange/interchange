# getlocale

Returns the name of the currently active locale. `[getlocale]` is an
**extended alias**: the parser rewrites it in place to

    [setlocale get=1]

so it is [setlocale](setlocale.md) preset to *read* rather than change
the locale.

## Syntax

    [getlocale]

## Examples

    Current locale: [getlocale]

produces (in a default strap catalog):

    Current locale: en_US

## See also

[setlocale](setlocale.md), [loc](loc.md),
[Internationalization](../guides/internationalization.md)

## Source

Defined in the parser's built-in alias table (`%Alias`,
`lib/Vend/Parse.pm` ~line 251: `getlocale => 'setlocale get=1'`);
behavior implemented by [setlocale](setlocale.md).
