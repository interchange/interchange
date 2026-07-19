# traffic_report

Summarize the catalog's traffic log into an HTML table of visits, hits, page
views, product views, cart adds, and orders, broken down by month or by day.
The admin UI uses it for its traffic/analytics screen. This tag is part of the
admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin UI feature
is enabled), not a storefront tag.

## Syntax

    [traffic_report]
    [traffic_report by_day=1]
    [traffic_report show="date visits hits orders" begin_date=20260101]

Standalone tag (no end tag). Returns an HTML `<table>`. When no traffic log
exists, it returns an empty result.

## Attributes

| Attribute    | Default                                   | Description |
|--------------|-------------------------------------------|-------------|
| `save`       | none                                      | Positional flag (accepted; the report itself is generated live). |
| `show`       | `date affiliate visits hits pages views incart orders` | Columns to include, in order. |
| `header`     | built-in labels                           | Hash overriding individual column header labels. |
| `affiliate`  | CGI `affiliate`                           | Restrict the report to one affiliate code. |
| `begin_date` | CGI `ui_begin_date`                       | Start date (run through the `date_change` filter). |
| `end_date`   | CGI `ui_end_date`                         | End date (run through the `date_change` filter). |
| `by_day`     | CGI `ui_by_day`                           | Group by day (`YYYYMMDD`) instead of by month (`YYYYMM`). |

Positional order: `save`. Remaining named attributes are collected as options
(`addAttr`).

## Description

The tag reads the tracking file named by the [TrackFile](../config/TrackFile.md)
directive — a tab-delimited log Interchange writes when tracking is enabled —
and aggregates each line into per-period buckets. A period is a month by
default, or a day when `by_day` is set. For each period it counts distinct
visits, raw hits, and the tracked actions `VIEWPAGE`, `VIEWPROD`, `ADDITEM`, and
`ORDER`, mapping them to the `pages`, `views`, `incart`, and `orders` columns; it
also shows each action as a percentage of that period's visits. Visits are
delimited by the `VISIT_TIMEOUT` variable (default 300 seconds) — a gap longer
than the timeout, or a new session, starts a new visit.

`begin_date`/`end_date` limit the range (both filtered through `date_change`),
and `affiliate` limits the report to a single affiliate. The columns rendered,
and their order, come from `show`; header labels come from the built-in set,
overridable per column with `header`. If the track file is absent or cannot be
opened, the tag returns without producing the table.

## Examples

Full monthly report:

    [traffic_report]

Daily breakdown of just a few columns:

    [traffic_report by_day=1 show="date visits hits orders"]

Report a single affiliate over a date range:

    [traffic_report affiliate=partner1 begin_date=20260101 end_date=20260331]

## Notes

The report depends on tracking being enabled and [TrackFile](../config/TrackFile.md)
being written; with no log file the tag produces no table. The output is a
pre-styled table using the admin UI's `r*` CSS classes (`rnorm`, `rmarq`,
`rborder`), so it is meant to be dropped into an admin page rather than styled
from scratch.

## See also

- [TrackFile](../config/TrackFile.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [logging and debugging](../guides/logging-debugging.md)

## Source

Defined in `code/UI_Tag/traffic_report.coretag` as an inline `UserTag` Routine
(registered `UserTag traffic-report`; hyphen and underscore spellings are
equivalent when invoking the tag).
