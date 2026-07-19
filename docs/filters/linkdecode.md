# linkdecode

Un-escapes hex-encoded (`%XX`) Interchange tags found inside the `action`,
`href`, and `src` attributes of HTML markup, so bracketed ITL that was URL-
encoded is turned back into live tags.

## Syntax

    [filter linkdecode]HTML[/filter]
    [value name=field filter="linkdecode"]

## Description

The filter scans the input for three specific attribute contexts and
un-hexifies their quoted values:

- `<form ... action="...">`
- any tag with `href="..."`
- any tag beginning with `i` (for example `<img>`) with `src="..."`

In each case the value must be quoted and must begin with `%5b` (the URL
encoding of `[`) — that is, it must look like a hex-encoded Interchange tag such
as `%5bpage ...%5d`. The matched value is passed through `unhexify`, restoring
`[` and `]` and any other `%XX` sequences, so the embedded ITL can interpolate.
Text that does not match these attribute patterns is left untouched.

It is named `linkdecode` precisely because it only touches link-bearing
attributes; feed it lines containing HTML anchors, forms, or image tags whose
URLs carry encoded Interchange tags. The filter is marked `Visibility private`.

## Examples

An anchor whose `href` holds a hex-encoded `[area ...]` tag is decoded back to
bracket form:

    [filter linkdecode]<a href="%5barea href=flypage arg=os28004%5d">Roller</a>[/filter]

produces (the `%5b`/`%5d` become `[`/`]`, ready to interpolate):

    <a href="[area href=flypage arg=os28004]">Roller</a>

## See also

- [urldecode](urldecode.md)
- [urlencode](urlencode.md)
- [liven_urls](liven_urls.md)

## Source

Defined in `code/Filter/linkdecode.filter`; uses `unhexify` from
`lib/Vend/Util.pm`.
