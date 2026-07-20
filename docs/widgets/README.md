# Widgets

Widgets render an HTML form control for a database field or form variable. You
select one with the `widget=` attribute of the
[accessories](../tags/accessories.md) tag, or through a field's metadata in the
admin table editor. Each page below documents one widget — the control it
renders, its options, and a runnable example. See the
[forms](../guides/forms.md) and [admin-ui](../guides/admin-ui.md) guides for
where widgets fit in.

## Text inputs

- [text](text.md) — a single-line `<input type="text">` box; the default
  widget for a field with no options.
- [textarea](textarea.md) — a multi-line `<textarea>` for free-form text.
- [htmlarea](htmlarea.md) — a rich-text (WYSIWYG) editor, falling back to a
  plain textarea.
- [default](default.md) — the fallback widget that renders a plain HTML control
  when a requested type has no routine of its own.

## Selects and combos

- [select](select.md) — a `<select>` dropdown from value/label choices; the
  default widget for a field with options.
- [multiple](multiple.md) — a `<select multiple>` scrolling list box for
  choosing several values at once.
- [combo](combo.md) — a dropdown plus a free-text input, to pick an existing
  option or type a new value.
- [movecombo](movecombo.md) — a dropdown beside a text box that appends the
  chosen option, to assemble a list.
- [movecombo_replace](movecombo_replace.md) — like [movecombo](movecombo.md)
  but replaces the text box, collecting exactly one value.
- [links](links.md) — a list of options rendered as clickable links that
  resubmit the page, like a navigable radio group.
- [country_select](country_select.md) — a country dropdown from the `country`
  table that drives a companion state control.
- [state_select](state_select.md) — the dynamic state/province control filled
  in by [country_select](country_select.md).

## Checkboxes and radios

- [checkbox](checkbox.md) — one checkbox per option; the standard multi-value
  box control.
- [check_nbsp](check_nbsp.md) — like [checkbox](checkbox.md) but with
  `&nbsp;`-joined labels so multi-word labels stay on one line.
- [radio](radio.md) — a group of radio buttons, one per choice.
- [radio_nbsp](radio_nbsp.md) — like [radio](radio.md) but with
  `&nbsp;`-joined labels.
- [yesno](yesno.md) — a Yes/No control storing `1` for Yes and empty for No.
- [noyes](noyes.md) — a No/Yes control with reversed sense: No stores `1`, Yes
  stores empty.
- [ynzero](ynzero.md) — a Yes/No control storing `1` for Yes and an explicit
  `0` for No.

## Date and time

- [date](date.md) — a calendar date as month/day/year dropdowns, optionally
  with a time dropdown.
- [time](time.md) — a dropdown of times of day in fixed increments across a
  24-hour span.

## Files and uploads

- [uploadhelper](uploadhelper.md) — a file-upload control that saves the file
  to disk and stores its path.
- [uploadblob](uploadblob.md) — a file-upload control that stores the file
  directly into a database BLOB column.
- [imagehelper](imagehelper.md) — an image-upload control with a link to the
  current image and the hidden upload fields.
- [imagedir](imagedir.md) — a picker of the existing image files in a server
  directory (a [combo](combo.md) wrapper).

## Admin-specific

- [acl](acl.md) — a table for editing an access-control list: object name,
  permission dropdown, and an "allow tar" checkbox per row.
- [gpg_keys](gpg_keys.md) — a picker of the server's GPG public keys (a
  [combo](combo.md) wrapper).
- [option_format](option_format.md) — a grid of text inputs for editing an
  option list, one row per choice.

## Display-only

- [display](display.md) — read-only; shows the *label* of the currently
  selected option instead of an editable control.
- [value](value.md) — read-only; shows a field's value as HTML-entity-encoded
  text with no control.
- [realvalue](realvalue.md) — like [value](value.md) but *unencoded*, passing
  any HTML or ITL through literally.
- [labels](labels.md) — read-only; outputs the labels of every option in a
  list, joined by a delimiter.
- [options](options.md) — read-only; shows the option *values* as
  comma-joined plain text.
- [show](show.md) — read-only; shows an option list as `value=label` pairs in
  plain text.
