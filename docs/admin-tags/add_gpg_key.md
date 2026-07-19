# add_gpg_key

Import an ASCII-armored GnuPG public key into the server's GPG keyring, used
when setting up encrypted-payment or encrypted-email delivery from the admin
interface. This tag is part of the Interchange admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [add_gpg_key name]
    [add_gpg_key name=fieldname text=... return_id=1]

Standalone tag (no end tag). The return value is a status string or key ID; it
is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `name`      | none    | Name of the CGI form field whose value holds the key text, used when `text` is not given. |
| `text`      | none    | The ASCII-armored key text itself. Takes precedence over `name`. |
| `return_id` | not set | When true, parse GPG's output and return the imported key's ID instead of `1`. |
| `success`   | not set | Value to return on success (when `return_id` is not set). |
| `failure`   | not set | Value to return on failure. |

Positional order: `name`.

The tag declares `addAttr`, so the named attributes above are read from the
options hash.

## Description

`[add_gpg_key]` shells out to the `gpg` executable (the path in the global
variable `GPG_PATH`, or `gpg` if unset) and imports a public key with
`gpg --import --batch`. The key text comes from the `text` attribute if given,
otherwise from the CGI field named by `name`; leading and trailing whitespace
is stripped before import.

On a failed import (non-zero exit from `gpg`) the tag sets the scratch variable
`ui_failure` to an error message and returns the `failure` value (or nothing).
On success it sets scratch `ui_message` to a confirmation that includes the
output of `gpg --list-keys`.

The return value on success depends on the options:

- With `return_id`, the tag reads GPG's stderr capture file and returns the
  hexadecimal key ID of the imported key (or the literal string
  `Failed ID get?` if it cannot be parsed).
- Otherwise, if `success` is set, that value is returned.
- Otherwise `1` is returned.

GPG's stderr is captured to `SESSIONID.gpg_results` in the catalog's
`ScratchDir`.

## Examples

Import a key pasted into a form field named `gpg_key`:

    [add_gpg_key gpg_key]

Import key text held in a scratch variable and capture the resulting key ID:

    [seti keyid][add_gpg_key text="[scratch pasted_key]" return_id=1][/seti]
    Imported key ID: [scratch keyid]

## Notes

The tag depends on a working `gpg` binary and a writable GnuPG home for the web
server user. If either is missing the import fails and `ui_failure` is set.

The exact wording of the success and failure messages is passed through
`errmsg` for localization.

## See also

- [get_gpg_keys](get_gpg_keys.md)
- [crypt](crypt.md)
- Concepts: [payments](../guides/payments.md), [email](../guides/email.md)

## Source

Defined in `code/UI_Tag/add_gpg_key.coretag` (registered as the tag
`add-gpg-key`; ITL treats hyphen and underscore in tag names as equivalent).
Implemented by the inline Routine in that file.
