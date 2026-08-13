# init_page

Names a `Sub` or `GlobalSub` that Interchange runs over a page's raw text
*before* any Variable substitution or tag interpolation. Reach for it when you
want to wrap or rewrite whole pages (for example, apply a template to pages that
lack one) at the earliest possible processing stage.

**Default:** unset (no init routine runs).

## Syntax

Catalog-wide, in `catalog.cfg`, giving the routine name as the value:

    Pragma init_page=ROUTINE_NAME

Page-wide, anywhere in an Interchange page (rarely useful for this pragma —
see Notes):

    [pragma init_page ROUTINE_NAME]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma init_page]ROUTINE_NAME[/tag]

The value is the name of a [Sub](../config/Sub.md) or
[GlobalSub](../config/GlobalSub.md). Setting the pragma to `1` or leaving the
value empty is meaningless here — a routine name is required.

## Description

When `init_page` holds a routine name, that routine is called from
`vars_and_comments()` at the very start of page processing, before page
`Variable` values (`@_NAME_@` / `__NAME__`) are substituted and before ITL tags
are interpolated. A *reference* to the page contents is passed as the sole
argument, so the routine edits the page in place by modifying `$$ref`.

The routine runs once per top-level page (Interchange guards re-entry with
`$Vend::PageInit`), so it does not fire again for nested interpolation.

## Examples

Wrap any page that does not already contain a Variable reference with a common
top-and-bottom template. In `catalog.cfg`:

    Pragma  init_page=wrap_page
    Sub <<EOS
    sub wrap_page {
        my $pref = shift;
        return if $$pref =~ m{\@_[A-Z]\w+_\@};
        $$pref =~ m{<!--+ title:\s*(.*?)\s+-->}
            and $Scratch->{page_title} = $1;
        $$pref = <<EOF;
    \@_MYTEMPLATE_TOP_\@
    <!--BEGIN CONTENT -->
    $$pref
    <!-- END CONTENT -->
    \@_MYTEMPLATE_BOTTOM_\@
    EOF
        return;
    }
    EOS

## Notes

Because `init_page` acts before the page's own tags are seen, setting it from
inside the page with `[pragma init_page ...]` is generally too late to be
useful; set it in `catalog.cfg` instead.

Related processing-stage pragmas run at later points: [pre_page](pre_page.md)
runs after Variable substitution but before tag interpolation, and
[post_page](post_page.md) runs around output image rewriting.

## See also

- [pre_page](pre_page.md)
- [post_page](post_page.md)
- [Pragma](../config/Pragma.md)
- [Sub](../config/Sub.md), [GlobalSub](../config/GlobalSub.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `vars_and_comments()` in
`lib/Vend/Interpolate.pm` (the routine is invoked via
`Vend::Dispatch::run_macro`).
