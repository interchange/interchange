# run_profile

Validate a set of submitted values against a form profile and return the
pass/fail status, so an admin page can check input without going through the
normal order-processing path. A form profile is a named block of validation
rules (required fields, format checks, and so on). This tag is part of the admin
UI toolset (the tags in `code/UI_Tag/`, loaded when the admin UI feature is
enabled), not a storefront tag.

## Syntax

    [run_profile check=name]
    [run_profile profile="required=email\nemail=email email"]
    [run_profile name=stored_profile cgi=1]

Standalone tag (no end tag). Returns the check status (typically the success
message or empty on failure), or nothing when `hide` is set.

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `check`           | none    | Name of the check; also selects the scratch profile `profile_<check>` when `profile` is not given. |
| `cgi`             | off     | Validate the CGI request values (`%CGI::values`) instead of the session `Values`. |
| `profile`         | scratch `profile_<check>` | Inline profile text (the validation rules) to run. |
| `name`            | none    | Run a persistent, already-stored profile of this name instead of building a temporary one. |
| `ref`             | none    | A hash reference of values to validate; overrides `cgi`/`Values` selection. |
| `no_error`        | on\*    | Add `&noerror=1` so failed checks do not set error messages. Defaults on when building a temporary profile. |
| `overwrite_error` | off     | Add `&overwrite=1` so a check's error replaces rather than appends. |
| `hide`            | off     | Return nothing (undef) regardless of the status. |

Positional order: `check`, `cgi`, `profile`, `name`. Remaining named attributes
are collected as options (`addAttr`).

\* When you pass an inline `profile` (no `name`), `no_error` defaults to on;
supply `no_error=0` to let failures record their errors.

## Description

The values to validate are chosen in this order: an explicit `ref` hash, else
the CGI request values when `cgi` is true, else the session `Values`.

If `name` is given the tag simply runs that stored profile. Otherwise it takes
the profile text from `profile` (or from the scratch variable
`profile_<check>`), and if there is none it returns success (`1`) immediately —
no profile means nothing to fail. When there is profile text, the tag wraps it
with `&fatal=1` (and `&noerror=1`/`&overwrite=1` per the options), stores it in a
temporary session scratch key, runs it through Interchange's order-check
machinery, and then removes the temporary key. The status returned is the result
of that check; with `hide` set the tag returns nothing so it can be used purely
for its side effects.

## Examples

Run a stored profile against the current form values:

    [run_profile name=address_check]

Validate the incoming request against inline rules and branch on the result:

    [if type=explicit compare="[run_profile cgi=1 no_error=0
        profile='
    email=required
    email=email A valid email is required.
    ']"]
      Thanks, your address checks out.
    [else]
      [error name=email]
    [/if]

Run the profile stashed in scratch under `profile_signup`:

    [run_profile check=signup]

## Notes

The check rule syntax is the same used by order profiles and
`mv_order_profile`; see the [forms](../guides/forms.md) guide for the available
checks. When `no_error` is left on (the default for inline profiles), a failure
returns a false status but records no `[error]` messages.

## See also

- Concepts: [forms](../guides/forms.md), [admin UI](../guides/admin-ui.md)
- [Glossary: form profile](../glossary.md)

## Source

Defined in `code/UI_Tag/run_profile.coretag` as an inline `UserTag` Routine
(registered `UserTag run-profile`; hyphen and underscore spellings are
equivalent when invoking the tag). Validation runs through Interchange's
`check_order` order-profile machinery.
