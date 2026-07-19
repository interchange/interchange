# SearchProfile

Names files that contain reusable search profile definitions. Reach for it to
move complex search parameters out of your HTML pages and into named profiles
that a search can invoke by name.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SearchProfile  filename ...

One or more profile filenames (relative to the catalog root). Each file may hold
several profiles separated by `__END__` on a line of its own; each profile is
named by a leading `__NAME__ name` line. Default: empty.

## Description

A search profile is a saved block of search specification parameters (the same
`mv_*` search variables you would otherwise put on a form). Loading them from a
file lets a search request select a whole set of parameters with a single
`mv_profile=name`, keeping pages clean and letting one definition drive many
searches.

Profiles are loaded at configuration time into an indexed list; each `__NAME__`
becomes a lookup key. A search names the profile through the `mv_profile` search
variable, and Interchange applies that profile's parameters before running the
search. This is the search-side counterpart of [OrderProfile](OrderProfile.md),
which validates order and form submissions.

Within a profile file, each opening `__NAME__` token must be left-aligned, and
each `__END__` must sit alone on its line with no surrounding whitespace.

## Examples

Load search profiles from a file. In `catalog.cfg`:

```
SearchProfile  include/profiles/searchprofiles
```

Load from more than one file:

```
SearchProfile  etc/profiles.search etc/search.profiles
```

## See also

[OrderProfile](OrderProfile.md), [Profile](Profile.md), the
[search](../guides/search.md) guide.

## Source

Parsed by `parse_profile` in `lib/Vend/Config.pm` (populating `SearchProfile`
and its `SearchProfileName` index). Consumed in `lib/Vend/Scan.pm`
(`find_search_params`).
