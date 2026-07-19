# Filter

Automatically runs named [filters](../filters/) over incoming CGI variables on
every request, so their values are already cleaned up by the time your pages
read them. Reach for it to normalize form input in one place instead of
filtering at each point of use.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Filter  variable  filter_name[ filter_name...]

Parsed as a hash of `variable` to filter specification. Each line names one CGI
variable and one or more filters to apply to it; multiple filters are given as
a single (usually quoted) space-separated list and applied in order. Default:
empty (no automatic filtering).

CGI variable (Common Gateway Interface): a value submitted by the browser, such
as a form field. A filter is a named transformation registered with Interchange
(see the [filters](../filters/) reference).

## Description

Early in request dispatch -- before your pages run -- Interchange walks the
`Filter` hash and applies each variable's filters to the corresponding
submitted value in place. By the time a page calls [cgi](../tags/cgi.md) or
[value](../tags/value.md), the value has already been filtered.

The directive accumulates across lines; a per-session filter set
(`$Vend::Session->{Filter}`) is applied in addition, if present. Each value in
the hash must be a filter spec; a malformed entry is logged and skipped.

## Examples

Multi-select and similar widgets return their choices null-separated. Turn the
nulls into spaces automatically:

```
Filter mail_lists  null_to_space
```

Apply two filters in order -- lowercase, then capitalize the first letter:

```
Filter firstname  "lc ucfirst"
```

After this, a submitted `firstname` of `mARK` reaches your pages as `Mark`.

## Notes

`Filter` applies to CGI input only. You can achieve the same effect ad hoc with
the [filter](../tags/filter.md) tag at the point of use, but declaring it once
with `Filter` reduces repetition and the chance of forgetting it somewhere.

## See also

[FormIgnore](FormIgnore.md), the [filter](../tags/filter.md) and
[cgi](../tags/cgi.md) tags, the [filters](../filters/) reference, the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm`, which calls `Vend::Interpolate::input_filter_do` for
each variable in the `Filter` hash.
