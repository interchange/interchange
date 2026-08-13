# href

`[href]` is an alias of [area](area.md). It builds the URL to an Interchange
page or action — the value that goes inside an `href="..."` attribute — and
behaves identically to `[area]` in every respect (same attributes, same
positional order `href`, `arg`, same output).

Use whichever name reads better at the call site; they resolve to the same
implementation.

## Example

    <a href="[href ord/basket]">View cart</a>

is exactly equivalent to:

    <a href="[area ord/basket]">View cart</a>

See [area](area.md) for the full attribute list, description, and further
examples.

## Source

Defined as `UserTag href Alias area` in `code/SystemTag/area.coretag`.
Implemented by `Vend::Interpolate::tag_area`.
