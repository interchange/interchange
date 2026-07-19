# date

Renders a calendar date as three dropdowns (month, day, year), optionally
followed by a time dropdown. It is the standard control for date fields in
forms and the admin editor.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=date name=FIELD value="[value FIELD]"]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`date`. Date fields usually also carry a `date_change` filter so free-form
input is normalized.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable for the date |
| `value` | current date | Current value; digits `YYYYMMDDHHMM` (non-digits are run through the `date_change` filter first) |
| `blank` | off | Add a leading blank option to each dropdown so "no date" is possible |
| `year_begin` | `UI_DATE_BEGIN` variable | First year offered (a value under 100 is treated as an offset from this year) |
| `year_end` | `UI_DATE_END` variable, else this year + 10 | Last year offered |
| `time` | off | Append a time-of-day dropdown |
| `time_adjust` | (none) | Hour offset applied to the default "now" time, e.g. `-5` |
| `ampm` | on (with `time`) | Show 12-hour am/pm times instead of 24-hour |
| `minutes` | `0,15,30,45` | Minute granularity: `half`, `hourly`, `ten`, or an explicit list |
| `start_hour` / `end_hour` | `0` / `23` | Restrict the hours offered |
| `select_class` / `select_style` / `select_extra` | (none) | Attributes added to each `<select>` |
| `option_class` / `option_style` / `option_extra` | (none) | Attributes added to each `<option>` |

## Description

`date` maps to `Vend::Form::date_widget`. It emits a month `<select>`
(localized month names), a day `<select>` (1–31), and a year `<select>`, joined
by hidden `<input value="/">` fields that all share the field's `name`; the
browser concatenates them into a `MM/DD/YYYY`-style string on submit. When no
value is supplied the current date is pre-selected (with `time`, the next hour
on the hour). With `time` a fourth `<select>` of times is appended, preceded by
a hidden `<input value=":">` separator.

The year range defaults to the `UI_DATE_BEGIN` and `UI_DATE_END`
[variables](../variables/); pass `year_begin`/`year_end` to override per field.

## Examples

A date field defaulting to the value on file:

    [display type=date name=create_date value="[value create_date]"]

Rendered HTML (trimmed to the first options of each dropdown):

    <select name="create_date"><option value="01">January</option>...</select>
    <input type="hidden" name="create_date" value="/">
    <select name="create_date"><option value="01">1</option>...</select>
    <input type="hidden" name="create_date" value="/">
    <select name="create_date"><option>2026</option>...</select>

Specify an explicit year range (from the historic examples, verified against
the code):

    [display type=date name=create_date value="[value create_date]"
             year_begin=1975 year_end=2020]

Add a half-hourly am/pm time selector:

    [display type=date name=appointment value="[value appointment]"
             time=1 minutes=half]

## See also

- [time](time.md) — a standalone time-of-day selector
- The `date_change` and `convert_date` filters (`../filters/`)
- [UI_DATE_BEGIN and UI_DATE_END](../variables/) variables

## Source

Defined in `code/Widget/date.widget`; maps to `Vend::Form::date_widget` in
`lib/Vend/Form.pm`.
