# jsqn

Quote a block of text so it is safe to drop into a JavaScript string literal,
**without** performing any variable substitution. Reach for it when the text
contains literal `$` characters you want preserved, such as regular
expressions or currency strings, in an admin UI `<script>` block.

`[jsqn]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when the
administrative interface is enabled; it is not a storefront tag.

## Syntax

    [jsqn]text with newlines and literal $ signs[/jsqn]

Container tag (has an end tag and processes its body). The body is **not**
reparsed as Interchange Tag Language (ITL) — the tag declares `NoReparse`.

## Attributes

This tag takes no attributes. It has one positional slot but reads none
(`PosNumber 0`); its only input is the body text.

## Description

`[jsqn]` behaves like [jsq](jsq.md) except it does not rewrite `$variable`
references. It splits its body into lines and returns each line as a separate
quoted JavaScript string joined with ` +`. For each line it:

- prefers single quotes, falling back to double quotes if the line contains a
  single quote, and escapes single quotes only if the line contains both;
- escapes carriage returns as `\r`.

A leading blank line is stripped. An empty body yields `''`. Because no
substitution is done, `$` characters pass through literally.

## Examples

Embedding a multi-line string whose `$astring` is meant literally:

    <script>
      var astring = 'just an insert';
      var somevar = [jsqn] Big long string you don't
      want to have to quote for JS, and you don't want to
      insert the variable $astring.[/jsqn];
    </script>

expands to:

    <script>
      var astring = 'just an insert';
      var somevar = " Big long string you don't" +
      '  want to have to quote for JS, and you don't want to' +
      '  insert the variable $astring.';
    </script>

## See also

- [jsq](jsq.md) — same quoting with `$variable` substitution

## Source

Defined in `code/UI_Tag/jsqn.coretag` as an inline `UserTag` Routine
(`UserTag jsqn`, `hasEndTag`, `NoReparse`).
