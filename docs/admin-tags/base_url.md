# base_url

Return the catalog's non-secure base URL (the `VendURL` the server was
configured with). Handy in the admin UI for building absolute links back into
the running catalog. This tag is part of the Interchange admin UI toolset (the
tags in `code/UI_Tag/`, loaded when the admin UI feature is enabled), not a
storefront tag.

## Syntax

    [base_url]

Standalone tag (no end tag) and no attributes. The return value is a URL
string; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

This tag takes no attributes or positional parameters.

## Description

`[base_url]` returns `$Vend::Cfg->{VendURL}`, the base URL Interchange computes
for the catalog's ordinary (non-secure) links. It is the same value the
[area](../tags/area.md) and [page](../tags/page.md) tags build ordinary links
from. Use it when you need the bare catalog URL as a string, for example to
construct a link outside the normal tag machinery.

## Examples

Show the catalog base URL:

    [base_url]

might produce:

    http://www.example.com/cgi-bin/mycatalog

Build an absolute link to a page:

    <a href="[base_url]/index.html">Storefront home</a>

## Notes

This returns the non-secure `VendURL`. For the secure base, use the
`SecureURL` configuration value (for example via
[global_value](global_value.md) or `[var]`); `[base_url]` does not switch to it.

## See also

- [area](../tags/area.md), [page](../tags/page.md)
- [global_value](global_value.md)
- Config: [VendURL](../config/VendURL.md)

## Source

Defined in `code/UI_Tag/base_url.coretag` (registered as the tag `base-url`;
ITL treats hyphen and underscore in tag names as equivalent). Implemented by
the inline Routine `sub { return $Vend::Cfg->{VendURL} }`.
