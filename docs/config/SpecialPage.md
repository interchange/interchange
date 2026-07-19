# SpecialPage

Maps Interchange's built-in "special" page roles (the basket, the search
results page, the flypage, the various error pages) to the actual page files in
your catalog. Set it when your catalog uses page names other than the defaults.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SpecialPage  ROLE  PAGE

The value is one or more `role page` pairs (parser type `special`); each line
usually sets one role. Later lines add to or override earlier ones. Default:

    order ord/basket  results results  search results  flypage flypage

so the `order` role resolves to `ord/basket`, `results` and `search` to
`results`, and `flypage` to `flypage`.

Commonly set roles include:

- `catalog` -- the catalog's front/home page.
- `order` -- the shopping basket page (default `ord/basket`).
- `search` / `results` -- the search results page (default `results`).
- `flypage` -- the on-the-fly product detail page (default `flypage`).
- `receipt` -- the order receipt page.
- `failed` -- shown when an order fails.
- `interact` -- shown on various interaction errors, such as a missing
  [FormAction](FormAction.md).
- `missing` -- shown when a requested page does not exist.
- `violation` -- shown on a security violation.
- `badsearch` -- shown when search initialization fails.
- `canceled` -- shown for the `cancel` form action.
- `needfield` -- shown when a required form field is missing.

## Description

`SpecialPage` populates the catalog's `Special` page map. Whenever Interchange
needs one of these role pages -- to display the basket, to report a missing
page, to show search results -- it looks the role up in this map and serves the
mapped page. Because the map is keyed by role, you can rename or relocate any of
these pages without touching the code that references them.

A page value is taken relative to the catalog's page directory. If
[NoAbsolute](NoAbsolute.md) is set, an absolute path is rejected with a warning.
The directory that holds dedicated special pages is set by
[SpecialPageDir](SpecialPageDir.md).

## Examples

Point the front page and error roles at custom pages (from the strap demo's
`catalog.cfg`):

```
SpecialPage  catalog      index
SpecialPage  violation    ../special_pages/violation
SpecialPage  put_handler  admin_publish
SpecialPage  receipt      ../etc/receipt
```

Send both the missing-page and violation roles to one "not found" page and use
`cart` as the basket:

```
SpecialPage catalog   index
SpecialPage missing   not_found
SpecialPage violation not_found
SpecialPage order     cart
```

## See also

[SpecialPageDir](SpecialPageDir.md), [DirectoryIndex](DirectoryIndex.md),
[SpecialSub](SpecialSub.md), [NoAbsolute](NoAbsolute.md).

## Source

Parsed by `parse_special` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{SpecialPage}` and copied to `$Vend::Cfg->{Special}`); consulted
throughout page display and dispatch.
