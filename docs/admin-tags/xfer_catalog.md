# xfer_catalog

Package an entire catalog into a gzipped tar image for backup or transfer,
exporting its databases, dumping any SQL databases with their native tools, and
generating a `restore.sh` script that rebuilds the catalog on the destination.
Reach for it from the admin backup screen to snapshot a catalog or move it to
another server.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [xfer_catalog]
    [xfer_catalog show_error=1 keep_together="orders logs" addcatline=1]

Standalone tag (no end tag). It builds the archive as a side effect and returns
`1` on success (or an error string when `show_error` is set). Its output is
reparsed as Interchange Tag Language (ITL) by default.

The tag name is registered as `xfer-catalog`; Interchange treats hyphens and
underscores in tag names interchangeably, so `[xfer_catalog]` and
`[xfer-catalog]` are the same tag.

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `file`            | none    | Positional parameter 1. Accepted but not used by the current routine (see Notes). |
| `backup_old`      | `0`     | Rename an existing `xfer` working directory to `xfer.backup.DATE` instead of deleting it. |
| `show_error`      | none    | Return the error message to the page on failure instead of returning undef. |
| `keep_together`   | CGI `keep_together` | Space/comma/null list of exclude categories to keep in the archive (sets the corresponding `keep_NAME`). |
| `keep_NAME`       | none    | Per-category override; when true, keep that category (see the category list below). Also read from the like-named CGI value. |
| `variables`       | built-in list | Space/comma/null list of catalog [variables](../variables/README.md) to capture into `site.txt` for the restore; defaults to a fixed deployment set. |
| `create_db`       | CGI `create_db` | Have the restore script create the SQL database before loading the dump. |
| `create_command`  | driver default | Override the database-creation command used by the restore script. |
| `restore_command` | driver default | Override the SQL restore command used by the restore script. |
| `addcatline`      | CGI `addcatline` | Generate `xfer/addcatline.pl` so the restore adds a `Catalog` line to `interchange.cfg`. |
| `rename`          | CGI `rename` | New catalog name used in the generated `Catalog` line and restore messages. |

Positional order: `file`.

The tag declares `addAttr`, and several controls (`keep_together`, `create_db`,
`addcatline`, `rename`, and the per-category `keep_NAME` flags) also read the
matching CGI form value, so the tag works when driven directly from the backup
form.

## Description

The tag works in a `xfer/` scratch directory under the catalog root, with
`exports/` and `dumps/` subdirectories. An existing `xfer/` is removed, or
renamed to `xfer.backup.DATE` when `backup_old` is set.

**Databases.** It walks every configured database. Text/DBM databases are
exported to `xfer/exports/`, and their on-disk source files are added to the
tar exclude list. SQL databases whose driver it recognizes (MySQL and
PostgreSQL) are dumped with their native tools — `mysqldump` or `pg_dump` — into
`xfer/dumps/`, using host/port/user/password parsed out of the DSN. The dump
and restore commands can be overridden through the
`DUMP_COMMAND_MYSQL`, `RESTORE_COMMAND_MYSQL`, `CREATE_COMMAND_MYSQL` (and
`_PG`) [variables](../variables/README.md).

**Exclusions.** A set of categories is excluded from the tarball by default:
`tmp`, `session`, `usertrack`, `orders`, `survey`, `logs`, `backup`, `config`,
`upload`, and `download`. Any category can be retained with `keep_NAME=1` (or
by listing it in `keep_together`), for example `keep_orders=1`. The exclude
list is written to an `exclude-files` file that `tar -X` consults.

**Restore script.** The tag builds `xfer/restore.sh`, which copies exported
text databases back into `products/`, optionally creates and reloads the SQL
database from the main dump, sets up the image directory, optionally compiles
and installs a link program, and — with `addcatline` — runs `xfer/addcatline.pl`
to insert a `Catalog` line into `interchange.cfg`. The selected `variables` are
written to `products/site.txt` so the restored catalog picks up destination
settings (`SERVER_NAME`, `CGI_URL`, `DOCROOT`, `SQLDSN`, and so on).

**Archive.** Finally it runs `tar -X exclude-files -c -z -f CATNAME.tar.gz .`
in the catalog root, producing `CATNAME.tar.gz` (named for the catalog). It
returns `1` on success; on any failure it logs the error and returns it to the
page when `show_error` is set, otherwise undef.

## Examples

Create a backup tarball of the current catalog, surfacing any error to the
page:

    [xfer_catalog show_error=1]

Keep the orders and logs in the archive instead of excluding them:

    [xfer_catalog keep_together="orders logs"]

Prepare a transfer to another server under a new catalog name, having the
restore script create the database and add the `Catalog` line (as the admin
transfer form drives it):

    [if cgi do_xfer]
      [tmp xfer_success][xfer_catalog addcatline=1 create_db=1 rename="[cgi rename]"][/tmp]
    [/if]

## Notes

- The `file` positional attribute is accepted but the current routine does not
  use it; the tarball is always named `CATNAME.tar.gz` for the catalog. The
  historic documentation lists `file` as required — the code does not read it.
  Pass control through the other attributes instead.
- The tag shells out to `tar`, `mysqldump`/`pg_dump`, and (in the generated
  restore script) database tools; those must be installed and on `PATH`. It is
  a privileged, filesystem-heavy operation meant for admin use.
- SQL dumping is limited to the MySQL and PostgreSQL drivers; databases on
  other SQL drivers fall back to text export.

## See also

- [backup_database](backup_database.md) and [backup_file](backup_file.md) —
  narrower backup operations
- The [databases guide](../guides/databases.md) and the
  [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/xfer_catalog.coretag` as an inline Routine. It calls
`Vend::Data::export_database`, shells out to native SQL dump tools and `tar`,
and writes `xfer/restore.sh` plus `exclude-files`.
