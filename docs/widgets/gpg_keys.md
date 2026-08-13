# gpg_keys

Renders a picker of the GPG public keys available on the server, so an
administrator can choose which key encrypts a value (for example the key used
to encrypt order data). It is a thin wrapper over the [combo](combo.md) widget.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an `mv_metadata`
record so the admin [table_editor](../admin-tags/table_editor.md) draws the
control for a field. Attribute values shown here are Interchange Tag Language
(ITL) tag attributes.

## Usage

    [display type=gpg_keys name=FIELD]

To select it in the admin UI, set the field's `mv_metadata` `type` column to
`gpg_keys`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable for the chosen key |
| `value` | (empty) | Pre-selected key |
| `variant` | `combo` | Underlying widget type to render the list as |

Because the default variant is `combo`, the `combo` options (`cols`,
`reverse`, `textarea`, …) apply as well.

## Description

`gpg_keys` calls the admin tag `[get-gpg-keys]` to obtain the list of available
keys and puts it in `passed`. It then sets the widget type to `variant` (default
`combo`) and, when that is `combo`, attaches the `nullselect` filter so the
empty free-text half of the combo is discarded on submit. Rendering is handed
to the shared `Vend::Form::display` dispatcher, so the final HTML is whatever
the chosen variant produces (by default a [combo](combo.md): a `<select>` of
keys plus an add-value text box).

The list content depends entirely on the keys installed in the server's GPG
keyring, so no deterministic option list can be shown here.

## Examples

A GPG key picker:

    [display type=gpg_keys name=encrypt_key value="[value encrypt_key]"]

Rendered HTML (shape only — actual `<option>`s come from the keyring):

    <input type="text" name="encrypt_key" size="" value="">
    <select name="encrypt_key">
    <option value="0xABCD1234">Jane Admin &lt;jane@example.com&gt;</option>
    ...
    </select>

Render the keys as a plain dropdown instead of a combo:

    [display type=gpg_keys name=encrypt_key variant=select]

## See also

- [combo](combo.md) — the default underlying widget
- [add-gpg-key](../admin-tags/) and [get-gpg-keys](../admin-tags/) — admin
  tags that manage the keyring
- The `encrypt` filter (`../filters/`) and
  [payments](../guides/payments.md) guide

## Source

Defined in `code/Widget/gpg_keys.widget`; its inline routine calls
`$Tag->get_gpg_keys()` and finishes with `Vend::Form::display` in
`lib/Vend/Form.pm`.
