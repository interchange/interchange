# component

Render a named page component -- a reusable fragment of Interchange Tag
Language (ITL) stored in the `component` table or in a template file -- and
optionally cache its rendered output. Components drive the region/slot layout
of the strap demo's pages.

## Syntax

    [component NAME]
    [component component=NAME attr=value ...]

Standalone tag (no end tag). The component body is fetched and interpolated
as ITL, so its output is reparsed by Interchange.

## Attributes

| Attribute            | Default                        | Description |
|----------------------|--------------------------------|-------------|
| `component`          |                                | Name of the component to render (also the first positional). |
| `default`            |                                | Component name to fall back to when `component` is empty. |
| `comp_table`         | `MV_COMPONENT_TABLE` or `component` | Table holding component records. |
| `comp_dir`           | `MV_COMPONENT_DIR` or `templates/components` | Directory searched when the component has no `comptext` in the table. |
| `comp_cache`         | `MV_COMPONENT_CACHE` or `component_cache` | Table used to cache rendered output. |
| `no_image_substitute`|                                | Suppress relative-image rewriting when the record routes output. |

Positional order: `component`.

Any attribute whose name does not begin with `comp` is written to the current
control record (see [control](control.md)) instead of being treated as an
option -- this is how `[component group=vertical output=...]` passes `group`
and `output` down to the component being rendered.

## Description

`component` looks up a named component and returns its rendered ITL. Name
resolution is: the `component` attribute (or first positional), then the
current control record's `component` value, then the `default` attribute. A
name of `none` (or an empty name) renders nothing but still advances the
control index so an empty slot has no side effect.

The component text is located in this order:

1. If the component table exists, its `comptext` column for the record.
2. Otherwise the file `comp_dir/NAME` (default `templates/components/NAME`).

When a session is teleported (a preview of a future date, via
`$Vend::Session->{teleport}`), the tag instead selects the row whose
`show_date`/`expiration_date` window contains that time, letting you schedule
component changes.

### Caching

If a component record sets `cache_interval` and the cache table
(`comp_cache`) exists, the rendered output is stored and reused until the
interval elapses. `cache_options` names control values to fold into the cache
key so variants cache separately.

### Output routing

If the component record has an `output` column, the rendered result is sent to
that named output region with `output_to` and the tag returns nothing;
relative images in the result are rewritten unless `no_image_substitute` is
set.

Every call increments `$::Scratch->{control_index}`, keeping component and
[control](control.md) iteration in step. See
[../guides/templating.md](../guides/templating.md) for the region/component
model.

## Examples

Render a single component by name:

    [component fortune]

Render whatever component the current control record names, into a region:

    [component group=content output="[control output top]"]

The strap demo's `TOP` variable stacks several such calls to lay out a page;
each pulls its component name and options from the control list built earlier
on the page.

## Notes

The tag depends on the control/region machinery: `component` values, the
`control_index` scratch counter, and the `$::Control` list are normally set up
by [control](control.md) and `control-set` earlier in the page. Used on its
own with an explicit name it simply renders a table row or template file.

## See also

[control](control.md), [control-set](control-set.md),
[../guides/templating.md](../guides/templating.md),
[MV_COMPONENT_DIR](../variables/MV_COMPONENT_DIR.md),
[MV_COMPONENT_TABLE](../variables/MV_COMPONENT_TABLE.md)

## Source

Defined in `code/UserTag/component.tag`. Implemented by the inline Routine in
that file.
