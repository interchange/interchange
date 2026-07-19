# rand

Return one randomly chosen alternative from a set. The alternatives are
given in the tag body (separated by a marker) or read from a file. Reach for
it to rotate taglines, tips, banners, or any bit of content on each page
view.

## Syntax

    [rand] choice one[alt]choice two[alt]choice three [/rand]
    [rand file="FILE"][/rand]
    [rand separator="MARKER"] a MARKER b MARKER c [/rand]

Container tag (has an end tag). The body is used as the source text unless a
`file` is given.

## Attributes

| Attribute   | Default    | Description |
|-------------|------------|-------------|
| `file`      | *(none)*   | Read the alternatives from this file instead of from the body. |
| `separator` | `\[alt\]`  | Regular expression that separates alternatives. The default matches the literal marker `[alt]`. |

Positional order: `file`.

## Description

`[rand]` splits its source text into pieces on the `separator` pattern and
returns one piece chosen uniformly at random. The source is the file named
by `file` when supplied, otherwise the tag body. The default separator is
the literal marker `[alt]` (the default value `\[alt\]` is the regular
expression that matches it), so with no `separator` you divide alternatives
with `[alt]`.

`separator` is used as a Perl regular expression, so metacharacters have
their regex meaning; escape them (as the default does with `\[` and `\]`)
when you want them matched literally.

Note the chosen piece is returned as-is; whitespace around your `[alt]`
markers becomes part of the alternatives, so trim it if it matters.

## Examples

Rotate one of three greetings on each view:

    [rand]Welcome![alt]Hello![alt]Good to see you![/rand]

Use a custom separator:

    [rand separator="\|"]red|green|blue[/rand]

Pick a random line-delimited tip from a file:

    [rand file="config/tips.txt" separator="\n"][/rand]

## Notes

- For randomly ordered or weighted advertising specifically, see
  [banner](banner.md), which draws from the banner table.
- Randomness is per render; combine with [if_not_volatile](if_not_volatile.md)
  or caching tags if you need it to behave predictably during page builds.

## See also

- [banner](banner.md) — rotating/weighted banners from a table
- [either](either.md) — return the first non-empty `[or]`-separated
  alternative (deterministic, not random)
- [file](file.md) — read file contents

## Source

Defined in `code/UserTag/rand.tag` (registers the tag `rand`). Implemented
by an inline Routine that splits the source on `separator` and returns a
random element.
