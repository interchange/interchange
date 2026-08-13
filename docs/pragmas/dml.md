# dml

Controls how the internal `update_data()` routine writes database records: as an
upsert (the default), insert-preserving, or strictly the requested operation.
Reach for it when `[import]`-style data writes must not silently create or
clobber records.

**Default:** unset — traditional "update or insert" (upsert) behavior.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma dml=strict
    Pragma dml=preserve

Page-wide, anywhere in an Interchange page:

    [pragma dml strict]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma dml]strict[/tag]

The value is one of: empty/unset, `preserve`, or `strict`.

## Description

`dml` (Data Manipulation Language) governs `Vend::Data::update_data()`, which
backs bulk data updates. The behavior by value:

- **unset** — the traditional, backward-compatible behavior: update the record if
  it exists, otherwise insert it (upsert).
- **`preserve`** — an update that finds no existing record may still fall through
  to an insert, but an insert will not overwrite existing data. Records can be
  added, but existing data is never clobbered.
- **`strict`** — the requested action is the only action performed: an update
  only updates (no fall-through insert), and an insert only inserts.

Internally `update_data()` sets its slice operation to the requested `$function`
(instead of the default `upsert`) when `dml` is `strict`, or when the function is
`insert` and `dml` is `preserve`.

## Examples

Force strict semantics catalog-wide so updates never accidentally create rows. In
`catalog.cfg`:

    Pragma dml=strict

## Notes

This pragma only affects code paths that go through `update_data()`. Direct
`[import]` of records or lower-level database calls are not governed by it.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `update_data()` in
`lib/Vend/Data.pm`.
