# reconfig_time

Read back a catalog's reconfiguration status file, so an administrative page can
report the result of a pending or completed [reconfig](reconfig.md). This tag is
part of the admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin
UI feature is enabled), not a storefront tag.

## Syntax

    [reconfig_time]
    [reconfig_time name=catalog]

Standalone tag (no end tag). Returns the contents of the catalog's status file
(the message and timestamp the server wrote after its last reconfiguration), or
an empty string.

## Attributes

| Attribute | Default              | Description |
|-----------|----------------------|-------------|
| `name`    | current catalog name | Catalog whose reconfiguration status to read. |

Positional order: `name`.

## Description

The tag returns the contents of the file `status.<name>` in the server's run
directory (`$Global::RunDir`). Interchange writes that file when it processes a
queued [reconfig](reconfig.md) request, so its contents tell you whether the
last reconfiguration succeeded and when.

As with [reconfig](reconfig.md), a permission rule applies: the tag returns an
empty string unless the current catalog is the administrative catalog
`_mv_admin` or is the same catalog named in `name`. A catalog may read its own
status; only `_mv_admin` may read another's.

## Examples

Show the current catalog's last reconfiguration status:

    [reconfig_time]

Report a named catalog's status from the admin catalog:

    Last reconfig of shop: [reconfig_time name=shop]

Trigger a reconfiguration and display its recorded result:

    [reconfig name=shop]
    Status: [reconfig_time name=shop]

## Notes

The status file is only present after the server has actually performed a
reconfiguration; before the first reconfig the tag returns an empty string.

## See also

- [reconfig](reconfig.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [configuration](../guides/configuration.md)

## Source

Defined in `code/UI_Tag/reconfig_time.coretag` as an inline `UserTag` Routine
(registered `UserTag reconfig-time`; hyphen and underscore spellings are
equivalent when invoking the tag).
