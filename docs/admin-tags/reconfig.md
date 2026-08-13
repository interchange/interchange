# reconfig

Queue a catalog for reconfiguration so the Interchange server rereads its
configuration on the next request, without restarting the daemon. Reach for it
from an administrative page after a change that requires a config reload (a new
database definition, an edited `catalog.cfg`, an installed feature). This tag is
part of the admin UI toolset (registered from `code/UI_Tag/` and loaded only
when the administrative interface is enabled), not a storefront tag.

## Syntax

    [reconfig]
    [reconfig name=catalog table=tablename file=importfile]

Standalone tag (no end tag). Returns `1` when the reconfiguration request is
queued, or an empty/undefined value if the current catalog is not permitted to
reconfigure the named catalog.

## Attributes

| Attribute | Default              | Description |
|-----------|----------------------|-------------|
| `name`    | current catalog name | Catalog to reconfigure. |
| `table`   | none                 | Optional table name to reimport as part of the reconfiguration. |
| `file`    | none                 | Optional source file for that table's import. |

Positional order: `name`, `table`, `file`.

## Description

The tag writes a reconfiguration request to the file `reconfig` in the server's
run directory (`$Global::RunDir`); the running Interchange server notices that
request and rebuilds the catalog's configuration on its next access.

Before queuing, it enforces a permission rule: the request succeeds only if the
*current* catalog is the special administrative catalog `_mv_admin` or is the
same catalog named in `name`. A catalog may reconfigure itself; only `_mv_admin`
may reconfigure another. On failure it sets the scratch/values error
`mv_error_tag_restart` to `Not authorized to reconfig that catalog.` and returns
undefined. If the target catalog has no registered `script` (its dispatch name),
the tag logs an error and returns undefined.

If both `table` and `file` are supplied, they are appended to the queued request
so that the reconfiguration also reimports `table` from `file`. Companion tag
[reconfig_time](reconfig_time.md) reads back the server's status file to report
when the reconfiguration completed.

## Examples

Reconfigure the current catalog:

    [reconfig]

Reconfigure a named catalog from the admin catalog:

    [reconfig name=shop]

Reconfigure and reimport one table from a file as part of the same request:

    [reconfig name=shop table=products file=products.txt]

## Notes

The tag only *queues* the request; the actual reload happens when the server
next processes a request for that catalog. Poll [reconfig_time](reconfig_time.md)
to learn the outcome.

## See also

- [reconfig_time](reconfig_time.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [configuration](../guides/configuration.md)

## Source

Defined in `code/UI_Tag/reconfig.coretag`, registered as the UserTag `reconfig`
(inline Routine).
