# TagInclude

Selects which discovered tags (and other code declarations) are actually
compiled into the running server. Reach for it to trim the tag set for security
or performance, or to switch specific tags off without deleting their code.

**Scope:** global (`interchange.cfg`)

## Syntax

    TagInclude  [!]ALL|:group|tag ...

A space-separated list of tokens. Each token is a tag name, or a group name
prefixed with `:` (see [TagGroup](TagGroup.md)), or the literal `ALL` meaning
every discovered tag. A leading `!` on a token excludes it. Tokens are applied
in order, so `ALL !:crufty` means "everything except the crufty group." Default:
`ALL`.

## Description

Interchange first scans the [TagDir](TagDir.md) directories for code, then
assigns the results to groups via [TagGroup](TagGroup.md), then applies
`TagInclude` to decide which of those tags to compile and make available. A tag
that is not included is simply not defined for the server; pages that use it get
an unknown-tag result.

`TagInclude` is evaluated at server start; changing it requires a restart.

## Examples

Include everything except one group and one specific tag
(in `interchange.cfg`):

```
TagInclude ALL !:crufty !get_url
```

This compiles in all tags, drops the `crufty` group, and additionally drops the
[get_url](../tags/get-url.md) tag.

## See also

[TagGroup](TagGroup.md), [TagDir](TagDir.md), [CodeDef](CodeDef.md),
[UserTag](UserTag.md), the [configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_tag_include` in `lib/Vend/Config.pm`; consumed there via
`$Global::TagInclude` when the discovered tags are compiled.
