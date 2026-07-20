# get_gpg_keys

List the public keys in a GPG keyring as `id=description` pairs, suitable for
populating a select widget. It is part of the administrative UI toolset
(loaded only when the admin UI is enabled), not a storefront tag; the admin
uses it to let a user pick the GPG key for encrypting order data.

## Syntax

    [get_gpg_keys]
    [get_gpg_keys dir=DIRECTORY long=1 none=1]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the shipped admin writes it as `[get-gpg-keys ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `dir`     |         | GPG home directory (passed to `gpg --homedir`). |
| `long`    |         | Use the long description format including date and id. |
| `none`    |         | Prepend an empty `=none` entry (a "no key" choice). |
| `joiner`  | `,\n`   | Separator between entries. |

Positional order: `dir` (the first parameter). Named and positional
parameters cannot be mixed: if any `name=value` attribute is present, the tag
takes the named path and a bare positional token is silently discarded. So
`[get_gpg_keys /path/to/keyring]` is valid, but alongside `long=1` or `none=1`
the directory must be written as `dir=/path/to/keyring`.

Positional arguments are also never interpolated: a `[tag]` written in a
positional slot arrives as literal text. To build an argument from other
data, use a named attribute with a quoted value — see
[Tag syntax](../guides/templating.md#tag-syntax).

## Description

The tag runs the GPG executable — `$Global::Variable->{GPG_PATH}` or `gpg`
on the `PATH` — with `--list-keys` and parses the `pub` lines of its output.
For each public key it emits an option string:

- default format: `id=description`
- `long` format: `id=description (date DATE, id ID)`

The strings are HTML-escaped (`<`, `>`, and `,` are encoded) so they can be
dropped straight into an options list, then joined with `joiner`. With
`none`, a leading `=none` option is added.

## Examples

Fetch the available keys into a scratch variable with [tmp](../tags/tmp.md),
then feed them to a select widget:

    [tmp pgp_keys][get_gpg_keys][/tmp]
    [display type=select name=pgp_key options="[scratch pgp_keys]"]

Include a "no key" choice and the long descriptions:

    [get_gpg_keys none=1 long=1]

## Notes

- GPG must be installed and reachable; set the `GPG_PATH` global variable if
  it is not on the default `PATH`.
- The `dir` (homedir) argument is filtered for safe characters, but the
  current implementation builds the flag as `--homedir$dir` without a
  separating space, so it does not work as intended; keys come from the
  default keyring unless this is corrected. Verify against your GPG version
  before relying on `dir`.

## See also

- [add_gpg_key](add_gpg_key.md) — import a key into the keyring
- The [payments guide](../guides/payments.md) and
  [security guide](../guides/security.md)
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/get_gpg_keys.coretag`. Implemented by the inline
Routine, which shells out to `gpg --list-keys`.
