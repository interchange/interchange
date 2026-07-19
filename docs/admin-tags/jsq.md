# jsq

Quote a block of text so it is safe to drop into a JavaScript string literal,
performing simple `$variable` substitution as it goes. Reach for it when
emitting long strings into inline `<script>` blocks in admin UI pages instead
of hand-escaping quotes and newlines.

`[jsq]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when the
administrative interface is enabled; it is not a storefront tag.

## Syntax

    [jsq]text with newlines and $vars[/jsq]

Container tag (has an end tag and processes its body). The body is **not**
reparsed as Interchange Tag Language (ITL) — the tag declares `NoReparse` —
so ITL inside the block is left untouched.

## Attributes

This tag takes no attributes. It has one positional slot but reads none
(`PosNumber 0`); its only input is the body text.

Alias: `jsquote` is registered as an alias for `jsq` (see
[jsquote](jsquote.md)).

## Description

`[jsq]` splits its body into lines and returns each line as a separate quoted
JavaScript string joined with the ` +` concatenation operator, so the result
drops directly into a JavaScript expression. For each line it:

- prefers single quotes, falling back to double quotes if the line contains a
  single quote, and escapes single quotes only if the line contains both;
- escapes carriage returns as `\r`;
- rewrites `$name` or `${name}` (not preceded by a backslash) into a
  concatenated JavaScript variable reference, i.e. `' + name + '`.

A leading blank line is stripped. An empty body yields `''`. Unlike
[jsqn](jsqn.md), `[jsq]` performs the `$variable` substitution.

## Examples

Embedding a multi-line string with an interpolated variable:

    <script>
      var astring = 'just an insert';
      var somevar = [jsq] Big long string you don't
      want to have to quote for JS, and you want to
      insert the variable $astring.[/jsq];
    </script>

expands to:

    <script>
      var astring = 'just an insert';
      var somevar = " Big long string you don't" +
      '  want to have to quote for JS, and you want to' +
      '  insert the variable ' + astring + '.';
    </script>

## Notes

The substitution targets JavaScript variables, not Interchange values: `$name`
becomes a reference to the JavaScript variable `name`, evaluated in the
browser. To insert an Interchange value, resolve it before the block (for
example with `[scratch]` or `[value]`).

## See also

- [jsqn](jsqn.md) — same quoting without `$variable` substitution
- [jsquote](jsquote.md) — alias for this tag

## Source

Defined in `code/UI_Tag/jsq.coretag` as an inline `UserTag` Routine
(`UserTag jsq`, `hasEndTag`, `NoReparse`). `UserTag jsquote Alias jsq`
registers the `jsquote` alias in the same file.
