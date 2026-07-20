# pre_page

Names a `Sub` or `GlobalSub` that Interchange runs over a page *after* Variable
substitution but *before* Interchange Tag Language (ITL) tags are interpolated.
Reach for it to programmatically rewrite page markup once variables are resolved
but before tags run.

**Default:** unset (no pre-page routine runs).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma pre_page=ROUTINE_NAME

Page-wide, anywhere in an Interchange page:

    [pragma pre_page ROUTINE_NAME]

Block-wide, around an ITL block:

    [tag pragma pre_page]ROUTINE_NAME[/tag]

The value is the name of a [Sub](../config/Sub.md) or
[GlobalSub](../config/GlobalSub.md).

## Description

When `pre_page` holds a routine name, `vars_and_comments()` calls that routine
after page `Variable` values have been substituted and after
`[comment]` blocks are stripped, but before the ITL parser interpolates tags. A
*reference* to the page contents is passed as the sole argument; the routine
edits the page in place through `$$ref`.

This is the middle of the three page-processing hooks:
[init_page](init_page.md) fires first (before variables), `pre_page` fires next
(after variables, before tags), and [post_page](post_page.md) fires last (around
output image rewriting).

## Examples

Register a routine that lowercases all HTML tag names before interpolation. In
`catalog.cfg`:

    Pragma  pre_page=downcase_tags
    Sub <<EOS
    sub downcase_tags {
        my $pref = shift;
        $$pref =~ s{(</?)([A-Za-z][\w-]*)}{$1 . lc($2)}ge;
        return;
    }
    EOS

## Notes

The `pre_page` and [post_page](post_page.md) hooks are frequently confused. In
the current code `pre_page` runs from `vars_and_comments()` (before tag
interpolation), while `post_page` runs from `substitute_image()` (around the
output image-rewrite stage, after tags have run).

## See also

- [init_page](init_page.md)
- [post_page](post_page.md)
- [Pragma](../config/Pragma.md)
- [Sub](../config/Sub.md), [GlobalSub](../config/GlobalSub.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `vars_and_comments()` in
`lib/Vend/Interpolate.pm` (invoked via `Vend::Dispatch::run_macro`).
