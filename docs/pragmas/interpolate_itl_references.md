# interpolate_itl_references

Enables Interchange Tag Language (ITL) interpolation of reference-style tag
attributes (the `col.NAME`, `.NAME`, and similar dotted/array attribute forms).
Set it when you need ITL inside those attribute values to be evaluated.

**Default:** off — reference-based attribute values are used verbatim.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma interpolate_itl_references

Page-wide, anywhere in an Interchange page:

    [pragma interpolate_itl_references]
    [pragma interpolate_itl_references 0]

Block-wide, around an ITL block:

    [tag pragma interpolate_itl_references]1[/tag]

This is a boolean pragma.

## Description

When the tag parser assigns a value into a reference-based attribute (an
attribute built up as a hash element like `col.quantity` or an array element),
it normally stores the value literally. When `interpolate_itl_references` is set
and the value contains something that looks like an ITL tag
(`[word ... ]`), the parser runs that value through
`Vend::Interpolate::interpolate_html()` first, so embedded tags are evaluated
before the value is stored.

## Examples

Allow an ITL tag inside a `col.` attribute value:

    [pragma interpolate_itl_references]

    [tmp testing]foobar'ed[/tmp]

    [record
      table=inventory
      key=newkey
      col.quantity=300
      col.stock_message="[scratch testing]"
    ]

With the pragma set, `col.stock_message` is stored as `foobar'ed` (the result of
`[scratch testing]`) rather than the literal tag text.

## Notes

This affects only reference-based (dotted/array) attributes handled by the tag
parser, not ordinary scalar attributes.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in the attribute-parsing loop of
`lib/Vend/Parser.pm`.
