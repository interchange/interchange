# control-set

Populates one control record in a single block, reading a group of
`[name]value[/name]` pairs from its body. Reach for it to define the
attributes of a page [component](component.md) instance without writing
each value to scratch first.

## Syntax

    [control-set index]
      [attr1]value1[/attr1]
      [attr2]value2[/attr2]
    [/control-set]

Container tag (has an end tag). It returns nothing; its effect is to set
values in the control array.

## Attributes

| Attribute | Default             | Description |
|-----------|---------------------|-------------|
| `index`   | current `control_index` | Control record to populate. |

Positional order: `index`. `[control-set]` accepts arbitrary additional
attributes (`addAttr`).

## Description

The body is scanned for balanced `[name]...[/name]` pairs. For each pair,
the name is lowercased, hyphens become underscores, and the enclosed text
is stored as `$Control->[index]{name}` — the same records that
[control](control.md) reads. Unlike setting values through
[set](set.md)/[scratch](scratch.md), `control-set` writes directly to the
control array and does not touch the Scratch namespace.

If you omit `index`, the current `control_index` is used. After processing
the body, the tag increments `control_index`, so consecutive
`[control-set]` blocks populate successive control records.

The pair names inside the body are literal control-attribute names, not
other ITL tags — the tag matches them with a simple `[word]...[/word]`
pattern rather than interpolating them as tags.

## Examples

Populate a component's control record with a banner and a flag:

    [control-set]
      [banner]Featured this week[/banner]
      [short]1[/short]
    [/control-set]

Then read the values back inside the component body with
[control](control.md):

    [control name=banner default="Just a thought..."]

## Notes

`[control-set]` is the mechanism the admin content editor uses to emit a
component's configured attributes (see `dist/lib/UI/ContentEditor.pm` and
`dist/lib/UI/ui.cfg`, which generate `[control-set]` blocks). You will
rarely hand-write it outside that context; on storefront templates the
attributes usually arrive through [component](component.md) instead.

## See also

[control](control.md), [component](component.md), [set](set.md), the
[templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/control_set.coretag` (inline `Routine`). The
registered tag name is `control-set`.
