# uc-attr-list

Interpolate `{PLACEHOLDER}` markers in the tag body from a set of named
attributes or a hash reference, exactly like [attr-list](attr_list.md) but
with the placeholder names written in uppercase. Reach for it when you have
a template fragment whose fill-in slots you would rather write as `{NAME}`
than as Interchange Tag Language (ITL) tags.

## Syntax

    [uc-attr-list attr1=value attr2=value] BODY [/uc-attr-list]
    [uc-attr-list hash=`HASHREF`] BODY [/uc-attr-list]

Container tag: it has an end tag and processes its body. The body is the
template that carries the `{...}` placeholders; the tag returns the body with
every placeholder replaced.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `hash`    | none    | A Perl hash reference whose keys supply placeholder values. When given, it replaces the named-attribute set. |

The tag also takes arbitrary named attributes (`addAttr`): any attribute you
pass becomes a value available to the placeholders. There are no positional
parameters (`PosNumber` is 0) and attributes are not rearranged
(`noRearrange`), so an attribute named the same as a placeholder is passed
through verbatim.

## Description

`uc-attr-list` matches the same placeholder grammar as
[attr-list](attr_list.md), but the marker names are written in uppercase and
folded to lowercase before the lookup. So `{FIRST_NAME}` reads the
`first_name` attribute (or the `first_name` key of the `hash` reference).

Supported placeholders, where `NAME` is an uppercase key:

| Placeholder | Replacement |
|-------------|-------------|
| `{NAME}` | value of `name` |
| `{NAME?other:else}` | value of `other` if `name` is non-empty, else value of `else` |
| `{NAME\|literal}` | value of `name`, or the literal text if `name` is false |
| `{NAME literal}` | the literal text if `name` is true, else empty |
| `{NAME?}...{/NAME?}` | the enclosed text if `name` is true |
| `{NAME:}...{/NAME:}` | the enclosed text if `name` is false |
| `{table::column::key}` | a database lookup, equivalent to [data](data.md) |

Values are substituted literally; the tag does no HTML or ITL escaping of its
own.

## Examples

Fill a greeting from named attributes:

    [uc-attr-list first_name="Jane" last_name="Doe"]
    Hello {FIRST_NAME} {LAST_NAME}!
    [/uc-attr-list]

produces:

    Hello Jane Doe!

Show a block only when a value is present:

    [uc-attr-list status="active"]
    {STATUS?}Your account is {STATUS}.{/STATUS?}
    {STATUS:}No status on file.{/STATUS:}
    [/uc-attr-list]

produces:

    Your account is active.

Supply a fallback for a missing value:

    [uc-attr-list nickname=""]
    Welcome back, {NICKNAME|guest}.
    [/uc-attr-list]

produces:

    Welcome back, guest.

## Notes

The upper- and lower-case variants exist so the template author can pick the
convention that reads best against the surrounding markup; they are otherwise
identical. Prior Akopia documentation for this tag transcribed the
`{NAME:}...{/NAME:}` (false) row as a second "if true" row — the code treats
the two forms as opposites, as shown above.

## See also

- [attr-list](attr_list.md) — the lowercase-placeholder equivalent
- [data](data.md) — the database lookup behind `{table::column::key}`
- [Templating guide](../guides/templating.md)

## Source

Defined in `code/SystemTag/uc_attr_list.coretag` (registered name
`uc-attr-list`). The routine wraps `Vend::Interpolate::tag_attr_list` with its
uppercase flag set.
