# DisplayErrors

Sends Interchange runtime errors to the visitor's browser in addition to the
error log. Reach for it while developing or debugging a catalog; leave it off in
production.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    DisplayErrors  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No` in both scopes.

Because error display can leak internal detail to end users, it is gated in two
places: the global directive must be on before any catalog is allowed to show
errors, and the catalog directive then decides whether that particular catalog
does so.

### Global

Enabling `DisplayErrors` in `interchange.cfg` turns on server-wide error
capture (errors are accumulated in `$Vend::Errors`) and permits catalogs to
display errors. With the global flag off, catalog-level `DisplayErrors` has no
visible effect.

### Catalog

With the global flag on, `DisplayErrors Yes` in `catalog.cfg` makes that catalog
append error text to its output. It also installs a `$SIG{__DIE__}` handler for
the request so that an otherwise fatal error is rendered as a "FATAL error" HTML
page instead of an opaque failure (`lib/Vend/Dispatch.pm`).

## Examples

Enable error display for development. In `interchange.cfg`:

```
DisplayErrors Yes
```

and in the catalog's `catalog.cfg`:

```
DisplayErrors Yes
```

## Notes

This directive changes the operation of `$SIG{__DIE__}` and can affect other
aspects of program flow. Do not enable it in normal production operation: errors
shown to visitors may reveal file paths, SQL, or other internals. Rely on
[ErrorFile](ErrorFile.md) and the logs instead.

## See also

[ErrorFile](ErrorFile.md), [ErrorDestination](ErrorDestination.md),
[DebugFile](DebugFile.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (both the `global_directives()`
and `catalog_directives()` tables); consumed in `lib/Vend/Dispatch.pm` and
`lib/Vend/Util.pm` (`$Global::DisplayErrors`, `$Vend::Cfg->{DisplayErrors}`).
