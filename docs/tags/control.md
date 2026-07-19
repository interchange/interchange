# control

Reads (or, with `set`, stores) one attribute of the current "control"
record — the indexed set of options that drives a page
[component](component.md). Reach for it inside a component template to pull
out the values an editor configured for that component instance.

## Syntax

    [control name default]
    [control name=attr default=value]
    [control]                            (advance the control index)
    [control reset=1]                    (reset the index)

Standalone tag (no end tag). Output is not reparsed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (none)  | Attribute to read; omit to manage the index. |
| `default` | (none)  | Value returned when the attribute is empty. |
| `space`   | (none)  | Switch to a named control array (by `$Tmp` key). |
| `reset`   | (none)  | With no `name`, reset the control index to 0. |
| `set`     | (none)  | With a `name` and no `default`, copy the scratch value of that name into the current control record. |

Positional order: `name`, `default`. `[control]` accepts arbitrary
additional attributes (`addAttr`). The attribute name is lowercased and
any hyphens are converted to underscores before lookup.

## Description

Interchange keeps an array of control records (`$Control`) and a current
index (the `control_index` scratch value). The [component](component.md)
tag populates one record per component with the attributes the catalog or
admin configured, then interpolates the component body; inside that body
`[control attr]` retrieves those attributes.

Two modes:

**Read a named attribute.** `[control name default]` returns
`$Control->[index]{name}` if it is set, otherwise the scratch variable of
the same name if that is non-empty, otherwise `default`. With `set` and no
`default`, it instead copies the current scratch value of `name` into the
control record (used to seed a control from scratch).

**Manage the index (no `name`).** A bare `[control]` increments
`control_index` and returns the new value. `[control reset=1]` resets the
index to 0. `[control space=NAME]` switches `$Control` to a separate array
stored under the `$Tmp` key `NAME` and resets the index — letting nested or
parallel component sets keep independent controls.

## Examples

Inside a component template, read a configured banner text with a
fallback (from the strap `fortune` component):

    [control name=banner default="[L]Just a thought...[/L]"]

Read a column count with a positional default:

    [control cols 2]

Reset the control index before iterating a fresh set of records:

    [control reset=1]

## Notes

`[control]` is almost always used together with [component](component.md)
and, in the admin content editor, [control-set](control-set.md), which
batch-populates a control record. It is rarely useful on its own outside
the component/region machinery. See the
[templating](../guides/templating.md) guide for the full component model.

## See also

[control-set](control-set.md), [component](component.md),
[scratch](scratch.md), the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/control.coretag` (inline `Routine`).
