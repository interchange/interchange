# download

Suppresses all output interpolation so that verbatim content is delivered
untouched. Set it when a page's body is a file download or other literal payload
that might otherwise contain constructs resembling Interchange variables
(`__NAME__`) or tags (`[tag]`).

**Default:** off — output is interpolated and image paths are rewritten.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma download

Page-wide, anywhere in an Interchange page:

    [pragma download]
    [pragma download 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma download]1[/tag]

This is a boolean pragma.

## Description

When `download` is set, Interchange changes how a response is emitted:

- `substitute_image()` returns immediately, so no image-path rewriting or
  `post_page` processing is applied to the body.
- In `Vend::Dispatch::response()`, the body is handed straight to the responder
  (`$H->respond`) instead of being queued and filtered through the normal output
  path.

The pragma is primarily used internally. For example, the
[deliver](../tags/deliver.md) tag sets it while sending a file, and the ITL
`[bounce]` handler sets it before writing its short redirect body. You could set
it catalog-wide to turn Interchange into a pure content-delivery engine and then
clear it (`[pragma download 0]`) only on the few pages that need normal
processing.

## Examples

Deliver one page's contents verbatim, with no variable or tag interpolation:

    [pragma download]
    Raw payload: __THIS_IS_NOT_A_VARIABLE__ and [this-is-not-a-tag].

Re-enable normal processing on a page under a catalog that sets `download` by
default:

    [pragma download 0]

## Notes

Because this pragma changes the delivery path, setting it mid-page has limited
effect once output has begun; it is most predictable set at the top of a page or
in `catalog.cfg`.

## See also

- [deliver](../tags/deliver.md)
- [post_page](post_page.md)
- [no_image_rewrite](no_image_rewrite.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `substitute_image()` in
`lib/Vend/Interpolate.pm`, in `response()` in `lib/Vend/Dispatch.pm`, and set by
the `[bounce]` handler in `lib/Vend/Parse.pm`.
