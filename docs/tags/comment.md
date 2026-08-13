# comment

Removes its body from the page, producing no output. Reach for it to
annotate templates or to disable a block of Interchange Tag Language (ITL)
or HTML without deleting it.

## Syntax

    [comment]...anything...[/comment]

Container tag (has an end tag). The body is discarded; the tag always
returns the empty string.

## Attributes

None.

## Description

Interchange normally strips `[comment]...[/comment]` blocks very early, in
`Vend::Interpolate::vars_and_comments`, before tags are interpolated — so
the body is never processed and never reaches the browser. This tag exists
as a backstop: it catches any `[comment]` blocks that survive that early
pass, such as blocks produced by reparsed output from a [perl](perl.md) or
[calc](calc.md) block. Its implementation is simply a routine that returns
`''`, so whatever is inside is thrown away.

Unlike an HTML comment (`<!-- ... -->`), which is sent to the browser and
visible in page source, a `[comment]` block is removed server-side and
never transmitted. Prefer it when the hidden content should not be exposed
to the client.

Interchange's block parser matches balanced `[comment]`/`[/comment]`
pairs, so comment blocks may be nested.

## Examples

Plain commentary in a template:

    [comment]
      Homepage hero — swap the banner here for seasonal promotions.
    [/comment]

Temporarily disable a block of ITL. The [nitems](nitems.md) tag below
never runs and produces no output:

    [comment]
      You have [nitems] items in your cart.
    [/comment]

## Notes

Because the body is discarded wholesale, do not place a template's only
copy of important markup inside a `[comment]` while "commenting it out"
across a save — it is removed from the output entirely.

Metadata blocks in component templates (the `ui_name:` / `label:` headers
you will see at the top of files under `templates/components/`) are written
inside a `[comment]` block for exactly this reason: the admin reads them,
the storefront never renders them.

## See also

[debug](debug.md), the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/comment.coretag` (inline `Routine`,
`sub { '' }`). Early removal is handled by
`Vend::Interpolate::vars_and_comments` in `lib/Vend/Interpolate.pm`.
