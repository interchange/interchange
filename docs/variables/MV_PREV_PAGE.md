# MV_PREV_PAGE

Holds the relative path of the previously served page, without the page suffix.
Reach for it when a page needs to know where the visitor came from — for
"return to previous page" links or conditional navigation.

**Scope:** runtime (set by the Interchange server; read-only)

Like [MV_PAGE](MV_PAGE.md), this is a variable in the `MV_*` namespace that the
server maintains automatically rather than one you set in a configuration file.

## Syntax

    @@MV_PREV_PAGE@@

Stored in `$Global::Variable`, so reference it with the global-variable form
`@@MV_PREV_PAGE@@` or with [var](../tags/var.md) and the global flag:

    [var MV_PREV_PAGE 1]

Default: none (set per request).

## Description

On each request the server copies the prior request's page path into
`$Global::Variable->{MV_PREV_PAGE}`, relative to the catalog's pages directory
and with the `HTMLsuffix` stripped. A visitor who moved from
`pages/index.html` to `pages/ord/basket.html` sees `MV_PREV_PAGE` equal to
`index` while `MV_PAGE` equals `ord/basket`.

## Examples

Offer a link back to the previous page:

    [page @@MV_PREV_PAGE@@]Go back</a>

Show both the current and previous page names:

    Now on @@MV_PAGE@@, came from @@MV_PREV_PAGE@@

## Notes

This variable is maintained by the server and is not intended to be written to.

## See also

[MV_PAGE](MV_PAGE.md), [MV_FILE](MV_FILE.md), [page](../tags/page.md),
the [templating](../guides/templating.md) guide.

## Source

Maintained by the request dispatcher in `lib/Vend/Dispatch.pm` and read via
`$Global::Variable->{MV_PREV_PAGE}`.
