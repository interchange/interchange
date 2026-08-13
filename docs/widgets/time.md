# time

Renders a `<select>` dropdown of times of day in fixed increments (every 15
minutes by default) across a 24-hour span. Reach for it when a field holds a
time-of-day and you want the user to pick from a menu rather than type it. Pair
it with the [date](date.md) widget for a full date-and-time entry.

## Usage

    [display type=time name=FIELD]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `time`. The stored value is a
four-digit `HHMM` string (24-hour), for example `1345` for 1:45 pm.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. |
| `value` | (looked up) | Current time as `HHMM`; the matching option is preselected (rounded to the nearest quarter hour). |
| `minutes` | `0,15,30,45` | Which minutes to offer each hour. Accepts `half` (0,30), `hourly` (0), `ten`/`tens` (every 10), or an explicit comma list. |
| `start_hour` | `0` | First hour offered (0–23). |
| `end_hour` | `23` | Last hour offered (0–23). |
| `ampm` | off | When set, append a localized `am`/`pm` marker to each label. |
| `blank` | off | Prepend an empty placeholder option. |
| `time` | off | With `time_adjust`, base the auto-selected default on the current time. |
| `time_adjust` | none | Hours (e.g. `+2` or `-5`) to shift the current-time default when `time` is set. |
| `select_class`, `select_style`, `select_extra` | none | Attributes added to the `<select>` tag. |
| `option_class`, `option_style`, `option_extra` | none | Attributes added to each `<option>` tag. |

The compound type form encodes several of these: `type=time_ampm` sets `ampm`,
`type=time_blank` sets `blank`, `type=time_9-17` sets `start_hour`/`end_hour`,
and `type=time_half` / `type=time_hourly` / `type=time_tens` set `minutes`.

## Description

`time` builds a `<select>` whose options step through the requested hours and
minutes. Each `<option>` value is a four-digit `HHMM` string; the label is a
`H:MM` time, with the special hours 0 and 12 labelled `midnight` and `noon`
(localized via `errmsg`). When `ampm` is set, a localized `am`/`pm` marker is
appended.

If no `value` is supplied, the widget defaults the selection to the next hour
on the hour (based on the server clock, optionally shifted by `time_adjust`);
any supplied value is rounded to the nearest quarter hour before matching.

## Examples

A basic time selector:

    [display type=time name=appt]

renders a dropdown of the form (options run 00:00 through 23:45 in 15-minute
steps; trimmed here):

    <SELECT NAME="appt"><OPTION VALUE="0000">midnight<OPTION VALUE="0015"> 0:15<OPTION VALUE="0030"> 0:30 ... <OPTION VALUE="1200">noon ... <OPTION VALUE="2345">23:45</SELECT>

Half-hour steps between 9 am and 5 pm with am/pm labels:

    [display type=time name=appt minutes=half start_hour=9 end_hour=17 ampm=1]

renders options at 09:00, 09:30, 10:00, ... each labelled with an `am`/`pm`
suffix.

## Notes

- Without `ampm`, hour labels use the 24-hour number with a leading space for
  single-digit hours (e.g. ` 9:15`, `13:45`); `midnight` and `noon` still
  replace the 0:00 and 12:00 labels.
- The auto-selected default depends on the server's current time, so the
  preselected option is not deterministic across renders. Supply a `value` to
  pin the selection.
- With `blank` set the widget emits a leading placeholder option (value `0`).
- The historic reference flags this widget as "considerably more complex than
  what is documented"; the options above are read from the current routine in
  `Vend::Form`.

## See also

- [date](date.md) — companion date selector
- [select](select.md) — the general dropdown this resembles

## Source

Defined in `code/Widget/time.widget`, whose inline routine uses
`Vend::Form::round_to_fifteen` in `lib/Vend/Form.pm`.
