# filesafe

Escapes the input so it is safe to use as a filename, replacing characters
that are special to the filesystem or shell with URL-style `%XX` escapes.

## Syntax

    [filter filesafe]TEXT[/filter]
    [value name=field filter="filesafe"]

## Description

The filter passes the input to `Vend::Util::escape_chars`, which walks the
string one character at a time and replaces any character outside the safe set
with a `%` followed by its two-digit hexadecimal code (the same `%XX` notation
used in URLs). The safe set is fixed in `lib/Vend/Util.pm`:

    A-Z  a-z  0-9  -  :  _  .  $  /

Every other character — spaces, parentheses, semicolons, quotes, shell
metacharacters, high-bit bytes — is escaped. Note that the forward slash `/`
is in the safe set, so filesafe preserves directory separators; it makes each
*path component* shell-safe rather than collapsing a path to a single name. To
reduce a path to its final component instead, use
[strip_path](strip_path.md).

Use filesafe whenever a user-supplied value becomes part of a filename or is
passed to an external command, so the value cannot introduce shell
metacharacters. Empty input yields empty output.

## Examples

    [filter filesafe]my report (final).txt[/filter]

Spaces and parentheses are percent-escaped, for example producing:

    my%20report%20%28final%29.txt

(The exact set of escaped characters follows the catalog's escape table.)

## See also

- [strip_path](strip_path.md)
- [pagefile](pagefile.md)
- [mime_type](mime_type.md)
- [urlencode](urlencode.md)

## Source

Defined in `code/Filter/filesafe.filter`; the routine calls
`Vend::Util::escape_chars` in `lib/Vend/Util.pm`.
