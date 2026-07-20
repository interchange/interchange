# post_page

Names a `Sub` or `GlobalSub` that Interchange runs over a page's output *before*
image-path substitution. If the routine returns a true value, Interchange skips
the built-in image rewrite entirely. Reach for it to post-process finished page
output (for example, rewrite links) at the last stage before delivery.

**Default:** unset (no post-page routine runs).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma post_page=ROUTINE_NAME

Page-wide, anywhere in an Interchange page:

    [pragma post_page ROUTINE_NAME]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma post_page]ROUTINE_NAME[/tag]

The value is the name of a [Sub](../config/Sub.md) or
[GlobalSub](../config/GlobalSub.md).

## Description

When `post_page` holds a routine name, `substitute_image()` calls that routine
as the first thing it does when rewriting a page's output. A *reference* to the
output text is passed as the sole argument, so the routine edits the text in
place through `$$ref`.

If the routine returns a true value, `substitute_image()` returns immediately
and the normal image-path rewriting (see [no_image_rewrite](no_image_rewrite.md))
is not performed. Return a false value to run your post-processing *and* still
let Interchange rewrite image paths.

This is the last of the three page-processing hooks:
[init_page](init_page.md) (before variables), [pre_page](pre_page.md) (after
variables, before tags), and `post_page` (around output image rewriting, after
tags have run).

## Examples

Rewrite plain relative `<a href>` links written by an HTML editor into proper
Interchange URLs. In `catalog.cfg`:

    Pragma   post_page=relative_urls

    ### Take hrefs like <A HREF="about.html"> and make relative to current dir
    Sub <<EOR
    sub relative_urls {
        my $page = shift;
        my @dirs = split "/", $Tag->var('MV_PAGE', 1);
        pop @dirs;
        my $basedir = join "/", @dirs;
        $basedir .= '/' if $basedir;
        my $sub = sub {
            my ($entire, $pre, $url) = @_;
            return $entire if $url =~ /^\w+:/;
            my($page, $form) = split /\?/, $url, 2;
            my $u = $Tag->area({ href => "$basedir$page", form => $form });
            return qq{$pre"$u"};
        };
        $$page =~ s{(( <a \s+ (?:[^>]+?\s+)? href \s*=\s* )
            (["']) ([^\s"'>]+) \3 )}{ $sub->($1,$2,$4) }gsiex;
        return;
    }
    EOR

The routine above returns nothing (false), so image rewriting still happens
afterward.

## Notes

Prior historic documentation described `post_page` as running "after Variable
processing and before tags are interpolated." That is incorrect for the current
code: `post_page` runs from `substitute_image()`, which processes finished
output. The hook that runs after variables and before tags is
[pre_page](pre_page.md).

Returning true from a `post_page` routine is the supported way to suppress image
rewriting for output produced by that routine.

## See also

- [init_page](init_page.md)
- [pre_page](pre_page.md)
- [no_image_rewrite](no_image_rewrite.md)
- [Pragma](../config/Pragma.md)
- [Sub](../config/Sub.md), [GlobalSub](../config/GlobalSub.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `substitute_image()` in
`lib/Vend/Interpolate.pm` (invoked via `Vend::Dispatch::run_macro`).
