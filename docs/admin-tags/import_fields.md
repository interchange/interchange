# import_fields

Load or update a database table from a delimited text file (or a spreadsheet
converted to one), with optional add, delete, cleanse, and filtering. It is
part of the administrative UI toolset (loaded only when the admin UI is
enabled), not a storefront tag; the admin uses it to bulk-import data
uploaded through its screens.

## Syntax

    [import_fields table]
    [import_fields table=t file=f add=1 delimiter=TAB]

Standalone tag. It returns a progress log (see below).

## Attributes

| Attribute       | Default | Description |
|-----------------|---------|-------------|
| `table`         |         | Target table (omit with `multiple`, where the file names its own tables). |
| `file`          | `<ProductDir>/<table>.update` | Input file to read. |
| `fields`        | first line of file | Space/delimiter-separated field names; first must be the key column. |
| `delimiter`     | tab     | Field delimiter in the file. |
| `add`           |         | Insert records whose key does not yet exist (otherwise they are skipped). |
| `delete`        |         | Honor `DELETE` marker lines to remove records. |
| `cleanse`       |         | After import, delete any pre-existing record not present in the file. |
| `autonumber`    |         | Assign keys to blank-key rows via the table's auto-number. |
| `transactions`  |         | Wrap the load in database transactions and commit at the end. |
| `multiple`      |         | The file contains multiple tables, each introduced by a form-feed + table name. |
| `ignore_fields` |         | Space/comma list of columns in the file to ignore. |
| `filter_field`  |         | Per-column filters to apply to incoming values (see below). |
| `convert`       |         | `auto` or `xls` to convert a spreadsheet to text first. |
| `move`          |         | After import, rename the input file with a timestamp. |
| `dir`           |         | With `move`, directory to move the timestamped file into. |
| `quiet`         |         | Suppress the progress log (`quiet` greater than 1 returns nothing). |

Positional order: `table` (the first parameter).

## Description

The tag reads the input file line by line and updates the table with
`set_slice`. Unless `fields` is given, the first line supplies the field
names; the first name is the key column. Each subsequent line is split on
the delimiter into a record.

Key behaviors:

- **Add vs. update.** Existing keys are updated in place. Unknown keys are
  skipped unless `add` is set, in which case they are inserted (a blank key
  needs `autonumber`).
- **Delete.** With `delete`, a line whose key is empty and whose first field
  is `DELETE` removes the record named by the next field.
- **Cleanse.** With `cleanse`, any record already in the table but absent
  from the file is deleted after the load — making the table mirror the file.
- **Filters.** `filter_field` lines (`column=filter`, or `table:column=filter`
  with `multiple`) run each incoming value through the named
  [filters](../filters/) before storing. The credit-card number column is
  always encrypted.
- **Multiple tables.** With `multiple`, a form-feed followed by a table name
  switches the active table mid-file, so one upload can populate several
  tables.
- **Spreadsheets.** `convert=xls` (or `auto`, which infers from the file
  extension) converts an Excel workbook to tab-delimited text via
  `Spreadsheet::ParseExcel` before importing.

The tag returns an HTML `<pre>` progress log (records processed, added,
deleted, and any errors) unless `quiet` is greater than 1. On a fatal error
it emits a standalone HTML error page and exits the request.

## Examples

Update the demo `products` table from its default update file
(`products/products.update`), adding new SKUs:

    [import_fields table=products add=1]

Load a pipe-delimited upload, replacing the table's contents exactly and
archiving the file afterward:

    [import_fields
        table=inventory
        file="tmp/inventory_upload.txt"
        delimiter="|"
        add=1
        cleanse=1
        move=1
        dir="archive"]

Apply a filter to an incoming column:

    [import_fields table=userdb filter_field="password=encrypt_do"]

## Notes

- Filenames and directories come straight from options; run this only from
  trusted admin contexts.
- The credit-card number column (`mv_credit_card_number`) is force-encrypted
  on import regardless of `filter_field`.
- `convert=xls` requires `Spreadsheet::ParseExcel` to be installed.

## See also

- [export_database](export_database.md) — write a table back out to text
- The [databases guide](../guides/databases.md)
- [Filters reference](../filters/)
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/import_fields.coretag`. Implemented by the inline
Routine in that file.
