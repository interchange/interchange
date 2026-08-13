# AutoVariable

Copies the current values of named configuration directives into the
Variable space, so a page can read a directive's value as
`__VariableName__`. Reach for it to surface a config value (a URL, an email
address, a limit) to templates without hardcoding it twice.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    AutoVariable  directive ...

A whitespace-, comma-, or null-separated list of directive names. Default:
`UrlJoiner` (global); empty (catalog).

## Description

For each named directive, `parse_autovar` (in `lib/Vend/Config.pm`) reads
the directive's current value and re-exports it as one or more Variables:

- **Scalar** directive -- exported as a Variable of the same name, so
  `VendURL` becomes `__VendURL__`.
- **Array** directive -- each element is exported as
  `__Name_index__`, for example `__SafeUntrap_0__` for the first element.
- **Hash** directive -- each pair is exported under the *hash key* itself,
  for example a `SysLog` hash with a `command` key becomes `__command__`.

Export is not dynamic: it captures the directive's value at the moment the
`AutoVariable` line is processed. If a later directive changes the value,
re-issue `AutoVariable` to refresh the Variable.

### Global

In `interchange.cfg` the default is `UrlJoiner`, which publishes the
server's URL-joining string as a Variable.

### Catalog

In `catalog.cfg` the default is empty; list the catalog directives you
want exposed.

## Examples

Expose several catalog directives (in `catalog.cfg`):

```
VendURL     http://www.example.com/cgi-bin/ic/catalog
SecureURL   https://www.example.com/cgi-bin/ic/catalog
MailOrderTo orders@example.com
SafeUntrap  sort
SysLog      command  /usr/bin/logger

AutoVariable VendURL SecureURL MailOrderTo SafeUntrap SysLog
```

Read a scalar on a page:

```
Orders are e-mailed to: __MailOrderTo__
```

Read the first element of an array directive:

```
First SafeUntrap value is: __SafeUntrap_0__
```

Read a hash value -- note the Variable is named by the hash key, not by
the directive:

```
Syslog command is: __command__
```

## Notes

Hash keys that contain non-word characters or whitespace are skipped, and
only the first level of array and hash structure is exported. Because hash
entries export under the bare key name, choose directives whose keys will
not collide with existing Variables.

## See also

[Variable](Variable.md), the [configuration](../guides/configuration.md) and
[templating](../guides/templating.md) guides.

## Source

Parsed by `parse_autovar` in `lib/Vend/Config.pm`, which calls
`parse_variable` to populate the Variable space.
