# Limit

Sets numeric and behavioral limits that tune assorted Interchange
subsystems -- cart quantities, list-text truncation, DBM open retries,
robot/session expiry, and more. Reach for it to override one of these
built-in ceilings without touching code.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Limit  KEY  VALUE

Parsed as key/value pairs into a hash; repeat the directive (or give
several pairs) to set more than one key. Keys not set fall back to the
built-in default shown below. Directive default:
`option_list 5000 chained_cost_levels 32 robot_expire 1`.

## Description

`Limit` is a catch-all hash of tunables consulted throughout the code as
`$::Limit->{KEY}`. The keys actually read by the current code, with their
effective defaults:

| Key | Default | Effect |
|-----|---------|--------|
| `cart_quantity_per_line` | none | Caps the quantity of any single cart line; excess is clamped to this value. |
| `chained_cost_levels` | 32 | Maximum recursion depth for chained cost (pricing) calculations. |
| `dbm_open_retries` | 10 | Times to retry opening a DBM file before giving up. |
| `file_lock_retries` | 5 | Times to retry acquiring a file lock. |
| `ip_session_expire` | 60 | Grace period used in IP/robot session expiry checks. |
| `list_text_size` | none | Maximum length of an item's text in list output before truncation. |
| `list_text_overflow` | none | If set to `abort`, over-long list text aborts instead of truncating. |
| `lockout_reset_seconds` | 30 | Pause length used in robot lockout accounting (see [RobotLimit](RobotLimit.md)). |
| `logdata_error_length` | none | If greater than 0, truncates logged error messages to this length. |
| `no_ship_message` | none | Suppresses the "cannot ship" message when set. |
| `option_list` | 5000 | Maximum number of option-list entries handled. |
| `profile_check_varname_regex` | `\w[-\w]*` | Regex constraining variable names in form-profile checks. |
| `robot_expire` | 1 | Expiry (in days) for flagged-robot session records. |
| `session_id_length` | 8 | Number of characters in a generated session ID. |
| `override_tag` | none | Internal flag consulted during tag overriding. |

The directive is read at catalog configuration time; keys it does not set
keep their built-in fallbacks.

## Examples

Expire flagged robots almost immediately, for testing (put in
`catalog.cfg`):

```
Limit robot_expire 0.01
```

Cap per-line cart quantity and lengthen the session ID:

```
Limit cart_quantity_per_line 99
Limit session_id_length 16
```

## Notes

The robot/session keys (`robot_expire`, `ip_session_expire`,
`lockout_reset_seconds`) work together with [RobotLimit](RobotLimit.md) and
[LockoutCommand](LockoutCommand.md) to govern robot handling.

The exact units and full semantics of a few thinly-used keys
(`ip_session_expire`, `no_ship_message`, `list_text_overflow`,
`override_tag`) are only lightly exercised in the code; test before relying
on precise behavior.

## See also

[RobotLimit](RobotLimit.md), [LockoutCommand](LockoutCommand.md),
[OrderLineLimit](OrderLineLimit.md), the
[performance](../guides/performance.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`, loaded into `$::Limit` in
`lib/Vend/Dispatch.pm`; individual keys are read across `lib/Vend/`
(`Session.pm`, `Cart.pm`, `File.pm`, `Data.pm`, `Interpolate.pm`,
`Util.pm`, `Error.pm`).
