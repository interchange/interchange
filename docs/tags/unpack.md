# unpack

Flush the deferred output regions built up by [output-to](output-to.md) into
the current page template, then hand the assembled page to the normal template
processor. Reach for it at the very bottom of a layout page that collects
named fragments earlier in the page (or in included components) and drops them
into their final positions here.

## Syntax

    [unpack] TEMPLATE [/unpack]

Container tag: it has an end tag. Its body is the page template. The body is
interpolated (the tag is declared `Interpolate`), so ITL inside it runs before
`unpack` templatizes the result. Interchange Tag Language is abbreviated ITL
throughout.

## Attributes

`unpack` takes arbitrary named attributes (`addAttr`) but defines none of its
own and has no positional parameters (`PosNumber` is 0).

## Description

Interchange can defer chunks of page output into named buffers instead of
emitting them where they are written. [output-to](output-to.md) is the tag
that captures a chunk into a buffer; a companion `[output]`-style tag places a
marker where the buffer's contents should later appear. `unpack` performs that
deferred assembly:

1. It runs image-path substitution (`substitute_image`) over the template
   body so relative image URLs are rewritten.
2. If multi-output buffering is active, it runs each buffer's registered
   output filters over the captured fragments.
3. Otherwise it runs image substitution over every collected output fragment.
4. It clears the multi-output state, sets the `no_image_rewrite` pragma so the
   rewrite is not repeated, and passes the body to `Vend::Page::templatize`
   for normal template handling.

`unpack` returns nothing itself; its effect is to emit the finished page.
Because it templatizes the body, you place your final layout (the
`[include ...]` of a layout file, for example) inside it.

## Examples

The strap demo's `BOTTOM` variable collects two named regions and then unpacks
the chosen layout template around them:

    [output name=copyright]
    __COPYRIGHT__

    [output name=edit_controls]
    __ADL_PAGE__

    [unpack]
    [include file="templates/layout/[either][scratch display_class][or]leftright[/either]"]
    [/unpack]

The `[output name=...]` blocks stash content into named regions; the layout
file included inside `[unpack]` contains the matching markers, so the copyright
and edit-control fragments land in their designated slots when the page is
assembled.

## Notes

`unpack` is a low-level piece of Interchange's page-assembly machinery and is
normally supplied by the catalog's template set rather than written by hand.
The region-capture side of the mechanism (`[output-to]` and the `[output]`
marker tag) must run earlier on the same page for `unpack` to have anything to
place.

## See also

- [output-to](output-to.md) — captures content into a deferred region
- [include](include.md) — pull in a layout or component file
- [Templating guide](../guides/templating.md)

## Source

Defined in `code/SystemTag/unpack.coretag` (registered name `unpack`). Its
routine drives `Vend::Interpolate::substitute_image` and
`Vend::Page::templatize`, using the `@Vend::Output` / `%Vend::OutPtr` /
`%Vend::OutFilter` buffers that [output-to](output-to.md) populates.
