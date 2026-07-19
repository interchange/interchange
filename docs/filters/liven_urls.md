# liven_urls

Finds bare URLs in the input and wraps each in an HTML `<a href="...">` anchor,
making them clickable.

## Syntax

    [filter liven_urls]TEXT[/filter]
    [filter liven_urls.PROTO]TEXT[/filter]
    [filter liven_urls.PROTO1.PROTO2]TEXT[/filter]

Each matched URL becomes `<a href="URL">URL</a>`.

## Description

The filter scans the input for URLs and replaces each occurrence with an anchor
that both links to and displays the URL. Matching uses precompiled regular
expressions (derived from Abigail's "Regex for URLs"), one per protocol.

By default three protocols are recognized: `http` (and `https`), `ftp`, and
`mailto`. You can restrict matching to a subset by naming protocols as dotted
arguments — for example `liven_urls.http` matches only web URLs, and
`liven_urls.http.mailto` matches web and mail URLs. Names that are not
recognized are ignored; if none of the requested protocols are available the
input is returned unchanged.

The source file also contains (commented-out) patterns for `news`, `nntp`,
`telnet`, `gopher`, `wais`, `file`, `prospero`, `ldap`, and others. To enable
any of them you must uncomment the corresponding block in
`code/Filter/liven_urls.filter` and restart Interchange; only http/ftp/mailto
are active as shipped.

## Examples

    [filter liven_urls]Visit http://example.com/ today[/filter]

produces:

    Visit <a href="http://example.com/">http://example.com/</a> today

Restrict matching to `mailto:` links only:

    [filter liven_urls.mailto]Write to mailto:sales@example.com now[/filter]

produces:

    Write to <a href="mailto:sales@example.com">mailto:sales@example.com</a> now

## See also

- [mailto](mailto.md)
- [text2html](text2html.md)
- [linkdecode](linkdecode.md)

## Source

Defined in `code/Filter/liven_urls.filter`.
