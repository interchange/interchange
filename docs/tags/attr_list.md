# attr_list

Interpolate `{name}` placeholders in the body from a set of attributes or a
Perl hash. Reach for it when you have a record or option hash and want a small
template that fills in fields, with light conditional logic, without writing
Perl. Invoke it as `[attr-list]` or `[attr_list]` — Interchange treats the
hyphen and underscore as the same tag name.

## Syntax

    [attr-list foo=bar baz=quux]{FOO} and {BAZ}[/attr-list]
    [attr-list hash="`$Tag->record(...)`"] ... [/attr-list]

Container tag (has an end tag; the body is the template). The body is scanned
for `{...}` placeholders and returned with them replaced; the result is not
otherwise reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `hash`    | none    | A Perl hash reference supplying the replacement values. When given (and it is a reference), it replaces the named-attribute source entirely. |

Positional order: none (`PosNumber` is 0). The tag is declared `noRearrange`,
so attribute order is preserved as written.

Because the tag declares `addAttr`, every attribute you pass becomes a key
available to the placeholders — this is the normal way to feed it values when
you are not passing a `hash`.

## Description

The tag collects its named attributes into a hash and, unless `hash` holds a
reference, uses that attribute hash as the value source. It then calls
`Vend::Interpolate::tag_attr_list`, which rewrites the following placeholder
forms in the body (keys are matched case-sensitively against the hash):

| Placeholder | Replaced with |
|-------------|---------------|
| `{NAME}` | the value of `NAME` |
| `{NAME?SET:UNSET}` | value of key `SET` if `NAME` is non-empty, else value of key `UNSET` |
| `{NAME\|text}` | value of `NAME`, or the literal `text` if `NAME` is false |
| `{NAME text}` | the literal `text` if `NAME` is true, else empty |
| `{NAME?}...{/NAME?}` | the enclosed contents if `NAME` is true |
| `{NAME:}...{/NAME:}` | the enclosed contents if `NAME` is **false** |
| `{table:column:key}` | a [data](data.md) lookup of that table/column/key |

The conditional block forms use `?` for the true case and `:` for the false
case — they are distinct markers, not the same delimiter repeated.

## Examples

Fill placeholders from named attributes:

    [attr-list first=Jane last=Doe]Hello, {FIRST} {LAST}.[/attr-list]

produces:

    Hello, Jane Doe.

Provide a default for a missing value:

    [attr-list name=""]User: {NAME|guest}[/attr-list]

produces:

    User: guest

Show a block only when a value is present, and an alternative when it is not:

    [attr-list stock=0]
      {STOCK?}In stock: {STOCK}{/STOCK?}
      {STOCK:}Out of stock{/STOCK:}
    [/attr-list]

produces (whitespace aside):

    Out of stock

Drive the template from a hash reference instead of individual attributes:

    [attr-list hash=`$Tag->record({ table => 'products', key => '00-0011' })`]
      {description} — {price}
    [/attr-list]

## Notes

Placeholder keys are matched exactly as written against the hash keys. When you
feed values as named attributes, Interchange lower-cases attribute names, so
use lower-case keys (`{first}`) unless you deliberately supply a hash with
other casing. The [uc-attr-list](uc-attr-list.md) variant folds `{UPPER}`
placeholders to lower-case keys for you.

Historic documentation listed the false-conditional block as a second
`{NAME?}...{/NAME?}` form; the code uses `{NAME:}...{/NAME:}` for the false
case, as documented above.

## See also

- [uc-attr-list](uc-attr-list.md)
- [data](data.md), [record](record.md)
- Concepts: [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/attr_list.coretag` (inline Routine), which wraps
`Vend::Interpolate::tag_attr_list`.
