# read_shipping

Load a shipping-definition file into the running catalog configuration. Reach
for it in admin UI shipping tools to (re)read `shipping.asc` after it has been
edited, so the current request sees the updated methods without a full
reconfigure.

`[read_shipping]` is part of the admin UI tag set in `code/UI_Tag/`, loaded
when the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [read_shipping]
    [read_shipping file]
    [read_shipping file=path/to/shipping.asc]

Standalone tag (no end tag). Returns the status of the read (true on success).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file` | the catalog's configured shipping file | Path to the shipping-definition file to read. Omit to read the catalog default. |

Positional order: `file` (`PosNumber 1`). Because the tag declares `addAttr`,
additional options are passed through to the underlying reader.

## Description

`[read_shipping]` calls Interchange's `read_shipping` routine to parse a
shipping-definition file and load its methods into
`$Vend::Cfg->{Shipping_line}` and `$Vend::Cfg->{Shipping_desc}` for the current
process.

After loading, the tag cleans up a stray header row: if the first shipping
line is the literal `code` / `description` placeholder pair, it drops that line
and removes the corresponding `code` description entry, so an exported header
row does not leak into the active shipping methods.

The return value is the reader's status, which is true when the file was read
successfully.

## Examples

Reload the catalog's default shipping file and note success:

    <!-- Shipping reloaded, success=[read_shipping] -->

Read a specific file (as the admin shipping editor does after saving), guarding
a "changes applied" message on the result:

    [if type=explicit compare="[read_shipping [scratch ui_shipping_asc]]"]
      Shipping methods reloaded.
    [/if]

## Notes

`[read_shipping]` affects only the current Interchange process's configuration;
it does not rewrite the file or perform a global reconfigure. To persist and
propagate changes to all processes, the admin flow follows it with the normal
apply/reconfigure step.

## See also

- [write_shipping](write_shipping.md)
- Concepts: [shipping](../guides/shipping.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/read_shipping.coretag` as an inline `UserTag` Routine
(registered `UserTag read-shipping`, `PosNumber 1`, `addAttr`), wrapping the
`read_shipping` routine in `Vend::Ship`.
