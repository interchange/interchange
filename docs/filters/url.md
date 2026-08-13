# url

Alias for [urldecode](urldecode.md). Decodes URL percent-encoding (`%XX` hex
escapes) back into the characters they represent.

`url`, `urld`, and `urldecode` name the same filter; `urldecode` holds the
implementation. See [urldecode](urldecode.md) for syntax, behavior, and
examples.

## Example

    [filter url]a%20b[/filter]

produces:

    a b

## Source

Declared as an alias of `urldecode` in `code/Filter/urldecode.filter`
(`CodeDef url Alias urldecode`).
