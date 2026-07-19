# SetGroup

Switches the Unix primary group Interchange runs under while serving a given
catalog. Reach for it to give each catalog its own group identity for file
permissions, so catalogs sharing one server can be isolated from each other.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SetGroup  groupname

A single Unix group name. The name is validated at configuration time -- the
Interchange user must belong to the group -- and converted to its numeric group
ID (GID). Default: empty (no group change).

## Description

By default the Interchange server and every catalog it serves run under the same
Unix user and group. `SetGroup` changes the effective group once Interchange has
determined which catalog is handling the request, so that catalog's file
operations happen under the named group. Combined with
[ReadPermission](ReadPermission.md) and
[WritePermission](WritePermission.md), this lets catalogs
share a host while keeping their files private to their own group.

The switch is applied per request as the catalog is dispatched. If the group
cannot be set, Interchange logs the failure and continues under the original
group.

## Examples

Run a catalog under the `catuser1` group. In `catalog.cfg`:

```
SetGroup  catuser1
```

## Notes

To use `SetGroup`, the Interchange user must be a member of the target group; if
it is not, configuration fails validation. Because a process's supplementary
group list is limited (32 groups on Linux), a single server can serve only about
31 distinct `SetGroup` catalogs.

## See also

[ReadPermission](ReadPermission.md),
[WritePermission](WritePermission.md), [CatalogUser](CatalogUser.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_valid_group` in `lib/Vend/Config.pm` (validates membership and
returns the GID). Consumed in `lib/Vend/Dispatch.pm` (`dispatch`), which sets
`$)` to the group.
