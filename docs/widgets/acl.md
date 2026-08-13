# acl

Renders a small table for editing an access-control list (ACL): one row per
object with a text field for the object name, a permission dropdown
(none / read / read-write / delete), and an "allow tar" checkbox.

A *widget* is a form control that Interchange renders through its metadata
system. You reach for it with the [display](../admin-tags/display.md) or
[widget](../admin-tags/widget.md) tag, or by naming it in an
[mv_metadata](../admin-tags/table_editor.md) record so the admin table editor
draws the control for a field. Attribute values shown here are Interchange
Tag Language (ITL) tag attributes.

## Usage

    [display type=acl name=FIELD value="..."]

To select it in the admin UI, set the `type` column of the field's
`mv_metadata` record to `acl`:

| code (`table::column`) | type | width | height |
|------------------------|------|-------|--------|
| `access::acl`          | acl  | 16    | 5      |

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | (required) | Form variable that receives the serialized ACL |
| `value` | (empty) | Current ACL, as an `acl2hash`-style string |
| `width` | `16` | Size of each object-name text input |
| `height` | `5` | Number of rows drawn; two blank rows are always appended |
| `filter` | `acl2hash` | Filter applied to the *submitted* value (string to hash) |
| `pre_filter` | `hash2acl` | Filter applied to the *incoming* value for editing |

`filter` and `pre_filter` are only set to their `acl2hash` / `hash2acl`
defaults when you have not supplied a `filter` of your own; setting `filter`
suppresses both defaults.

## Description

The incoming value is passed through the `pre_filter` (`hash2acl`) to produce
a comma-separated list of `object=permission` pairs, which the widget splits
into rows. Each row emits several form fields that share the field's `name`:

- a text input for the object name, followed by a hidden field with value `=`
- a `<select>` of permissions (`n` none, `r` read, `rw` read-write,
  `d` delete), pre-selected from the permission letters in the value
- a checkbox with value `t` ("allow tar"), followed by a hidden field with
  value `,`

Because every control uses the same `name`, the browser submits them in order
and the interleaved `=` and `,` hidden fields reconstruct the
`object=perm,object=perm` string, which the `filter` (`acl2hash`) turns back
into the stored hash. The widget always draws `height - 2` value rows plus two
empty rows so there is room to add entries.

## Examples

Render an editor for an ACL string of two objects:

    [display type=acl name=doc_acl value="report=rw,summary=r"]

Rendered HTML (trimmed to one populated row):

    <table cellpadding="0" cellspacing="0"><tr>
    <th style="font-size: small">Object</th>
    <th align="left" style="font-size: small">Permissions</th>
    <th align="center" style="font-size: small">Allow tar</th>
    </tr>
      <tr>
        <td>
          <input type="text" name="doc_acl" value="report" size="16" style="font-size: small">
          <input type="hidden" name="doc_acl" value="=">
        </td>
        <td>
          <select name="doc_acl" style="font-size: small">
            <option value="n">none</option>
            <option value="r">read</option>
            <option value="rw" SELECTED>read-write</option>
            <option value="d">delete</option>
          </select>
        </td>
        <td align=center>
          <input type="checkbox" name="doc_acl" value="t" style="font-size: small">
          <input type="hidden" name="doc_acl" value=",">
        </td>
      </tr>
      ...
    </table>

Widen the object-name inputs and show more rows:

    [display type=acl name=doc_acl value="[value doc_acl]" width=32 height=8]

## See also

- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md) —
  tags that render a widget
- [table_editor](../admin-tags/table_editor.md) — admin editor that draws
  widgets from `mv_metadata`
- The `acl2hash` and `hash2acl` filters (`../filters/`)
- [user-database](../guides/user-database.md) — where per-user ACLs live

## Source

Defined in `code/Widget/acl.widget`. The row-building logic is inline in that
file's `Routine`; the value round-trips through the `acl2hash` / `hash2acl`
filters in `code/Filter/`.
