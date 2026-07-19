# bar-button

Render one entry of a navigation bar, showing a highlighted version when its
page is the page currently being viewed and a normal version otherwise. Reach
for it to build a menu where the "you are here" item looks different.

## Syntax

    [bar-button page="cat/hats"]
    normal appearance
    [selected]highlighted appearance[/selected]
    [/bar-button]

Container tag (processes its body). The body holds the normal link markup plus
an inner `[selected]...[/selected]` block giving the current-page appearance.

## Attributes

| Attribute | Default              | Description |
|-----------|----------------------|-------------|
| `page`    |                      | The page this button links to (positional 1). |
| `current` | `@_MV_PAGE_@` global | The page to compare against; defaults to the page being viewed. |

Positional order: `page`, `current`.

## Description

The tag compares `page` with `current`. When they differ (this is not the
current page), it returns the body with the `[selected]...[/selected]` block
removed — the ordinary button. When they match (this is the current page), it
returns only the contents of the `[selected]` block — the highlighted button.

`current` defaults to `$Global::Variable->{MV_PAGE}`, the path of the page
Interchange is rendering, so in normal use you supply only `page` and the tag
highlights itself automatically when the shopper is on that page.

The body is not interpolated by the tag itself; whatever ITL it contains is
processed by the surrounding page as usual.

## Examples

A single navigation entry that highlights on its own page:

    [bar-button page="cat/hats"]
    <a href="[area cat/hats]">Hats</a>
    [selected]<a href="[area cat/hats]" class="active">Hats</a>[/selected]
    [/bar-button]

On every page except `cat/hats` this emits the plain link; on `cat/hats` it
emits the `class="active"` version. Repeat one `[bar-button]` per menu item to
build the whole bar.

## Notes

- `current` compares against `$Global::Variable->{MV_PAGE}`; if you render the
  bar in a context where that is not the shopper-facing page (an included
  component, an email), pass `current` explicitly.

## See also

- [area](area.md) — build the link targets
- [selected](selected.md) — the option-state tag of the same name (unrelated
  mechanism)
- The [templating guide](../guides/templating.md)

## Source

Defined in `code/UserTag/bar_button.tag` (inline `Routine`), registered as
`bar-button`.
