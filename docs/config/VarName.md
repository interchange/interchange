# VarName

Remaps Interchange variable names to shorter or arbitrary names in the URLs
Interchange generates and reads. Reach for it to shrink long `mv_*`
parameter names in query strings (for example writing `id` in the URL for
`mv_session_id`).

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    VarName  original_name  remapped_name

Whitespace-separated pairs parsed by `parse_varname`: the internal
Interchange variable name followed by the name to expose in URLs. Several
pairs may appear on one line, and each `VarName` line adds to the mapping.
Default: empty (the built-in mappings from `etc/varnames`, see below).

## Description

Interchange keeps two lookup hashes: `VN` (internal name to URL name) and
`IV` (URL name back to internal name). `parse_varname` populates both, so a
`VarName mv_session_id session` line makes Interchange write `session=...`
in generated URLs and, on the way in, translate `session=...` back to
`mv_session_id` before processing (`lib/Vend/Server.pm`). The remapping is
purely cosmetic -- it shortens URLs; it does not hide or secure anything.

### Global

Defined in `interchange.cfg`, the mappings go into `$Global::VN` /
`$Global::IV` and apply to every catalog. On first use Interchange seeds the
global set from `etc/varnames` (writing that file if it does not yet exist),
so the shipped short names are always present.

### Catalog

Defined in `catalog.cfg`, the mappings are copied from the global set and
then extended per catalog (`$C->{VN}` / `$C->{IV}`), letting one catalog add
or change remappings without affecting others.

## Examples

Remap the session id to a short URL parameter (in `interchange.cfg` or
`catalog.cfg`):

```
VarName  mv_session_id  session
```

Use an even shorter name:

```
VarName  mv_session_id  id
```

## Notes

Interchange already ships with a set of remappings to keep URLs short; see
`etc/varnames` for the list. When remapping `mv_*` names, avoid two-letter
target names -- most two-letter tokens are reserved for
[search](../guides/search.md) parameters. Names of one, three, or more
characters are safe.

## See also

[Variable](Variable.md), [ScratchDefault](ScratchDefault.md),
[UrlSepChar](UrlSepChar.md), the [search](../guides/search.md) guide.

## Source

Parsed by `parse_varname` in `lib/Vend/Config.pm` (populating the `IV`/`VN`
hashes, global or per-catalog); consumed when reading form/URL input in
`lib/Vend/Server.pm`.
