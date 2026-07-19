# if_not_volatile

Output the body only when the current request is not "volatile" — that is,
only on a normally rendered page, not on a volatile request such as a page
being built for the search/robot cache. Reach for it to guard content or
side-effecting tags that should run once per real page view.

## Syntax

    [if_not_volatile] ... body ... [/if_not_volatile]

Container tag (has an end tag). The body is not pre-interpolated
(`Interpolate 0`), but the returned body is reparsed as Interchange Tag
Language (ITL) in the normal way (`NoReparse 0`), so tags inside it run when
the block is emitted.

## Attributes

This tag takes no attributes.

## Description

Interchange marks certain requests as *volatile* by setting
`$::Instance->{Volatile}`. A volatile request is one that should not have
lasting or repeated side effects — for example a page rendered while
pre-building/caching pages. `[if_not_volatile]` returns its body unchanged
when the request is *not* volatile, and returns the empty string when it is.

Use it to wrap content or tags whose effect should happen only on a genuine,
non-cached page view (hit counters, tracking pixels, one-shot logic).

## Examples

Only record a banner impression on real page views:

    [if_not_volatile]
        [banner category=homepage]
    [/if_not_volatile]

Show a message that should not appear in pre-built cached output:

    [if_not_volatile]
        <p>Welcome back, [value fname]!</p>
    [/if_not_volatile]

## Notes

- This is the container companion to the request-volatility concept used by
  [history-scan](history-scan.md), which only records non-volatile page
  views in the visitor's history stack.

## See also

- [if](if.md) — general conditional container
- [history-scan](history-scan.md) — relies on the same volatility flag
- [timed-build](timed-build.md) — caches page fragments, one of the
  situations that produces volatile rendering

## Source

Defined in `code/UserTag/if_not_volatile.tag` (registers the tag
`if_not_volatile`). Implemented by an inline Routine that tests
`$::Instance->{Volatile}`.
