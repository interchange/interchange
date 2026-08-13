# XHTML

Makes Interchange emit XHTML-style self-closing tags -- adding the ` /`
trailer to standalone elements it generates (`<br />`, `<img ... />`). Reach
for it when your templates target XHTML and you want Interchange's built-in
output to match.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    XHTML  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`).

- Global default: `No`.
- Catalog default: the global `XHTML` value, so a catalog inherits the
  server setting unless it overrides it.

## Description

When `XHTML` is on, Interchange sets the internal trailer string
`$Vend::Xtrailer` to ` /`; when off it is empty (`lib/Vend/Dispatch.pm`):

```perl
if($Vend::Cfg->{XHTML}) {
    $Vend::Xtrailer = ' /';
}
else {
    $Vend::Xtrailer = '';
}
```

Code that emits standalone tags interpolates `$Vend::Xtrailer` just before
the closing `>`, so form builders, menus, and the like produce `<br />`
under XHTML and `<br>` otherwise. The trailer is chosen per request from the
catalog's setting.

This affects only the standalone-tag ending. The other two XHTML
requirements -- lowercase attribute names and quoted attribute values -- are
already standard in Interchange's generated markup regardless of this
directive.

### Global

In `interchange.cfg`, `XHTML` sets the server-wide default (`$Global::XHTML`,
default `No`) that catalogs inherit.

### Catalog

In `catalog.cfg`, `XHTML` overrides the inherited default for that catalog.

## Examples

Turn XHTML output on for a catalog (in `catalog.cfg`):

```
XHTML  Yes
```

Or set the server-wide default in `interchange.cfg`:

```
XHTML  Yes
```

## Notes

Interchange's generated markup is only gradually made fully XHTML-compliant,
so enabling `XHTML` does not guarantee every fragment of built-in output is
valid XHTML. It reliably controls the self-closing-tag trailer via
`$Vend::Xtrailer`.

## See also

[UTF8](UTF8.md), [Variable](Variable.md) (the `MV_HTML4_COMPLIANT`
variable), the [templating](../guides/templating.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (global `$Global::XHTML`,
catalog `$C->{XHTML}`); consumed in `lib/Vend/Dispatch.pm`, which sets
`$Vend::Xtrailer` used across `lib/Vend/Form.pm`, `lib/Vend/Menu.pm`, and
`lib/Vend/Interpolate.pm`.
