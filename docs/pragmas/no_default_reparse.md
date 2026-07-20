# no_default_reparse

Turns off the default reparsing of container-tag output. By default Interchange
reparses the output of container tags for further Interchange Tag Language (ITL)
tags; set this pragma to make that opt-in per tag instead.

**Default:** off — container-tag output is reparsed by default (`reparse=1` is
assumed).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma no_default_reparse

Page-wide, anywhere in an Interchange page:

    [pragma no_default_reparse]
    [pragma no_default_reparse 0]

Block-wide, around an ITL block:

    [tag pragma no_default_reparse]1[/tag]

This is a boolean pragma.

## Description

When the parser handles a container (has-end-tag) ITL tag, it normally sets
`reparse=1` unless the tag is in the internal `%NoReparse` list or the tag was
given an explicit `reparse` attribute. That means tag output is scanned again for
ITL tags. When `no_default_reparse` is set, this automatic `reparse=1` is not
applied, so a tag's output is left as-is unless reparsing is explicitly
requested.

Reparsing can still be turned on where you want it: by the `Reparse` setting in a
tag's own definition, or by passing the universal `reparse=1` attribute to any
container tag.

## Examples

Disable default reparsing catalog-wide. In `catalog.cfg`:

    Pragma no_default_reparse

Then request reparsing only where needed:

    [seti foo][area href=index][/seti]
    [tmp bar reparse=1][scratch foo][/tmp]

## Notes

Turning this on can be a performance win on pages with heavy container-tag output
that does not need a second parsing pass, at the cost of having to add
`reparse=1` where nested tags in output must still be interpolated.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in the `start()`
tag-dispatch handler in `lib/Vend/Parse.pm`.
