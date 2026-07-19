# TagGroup

Defines named groups of code declarations (tags, filters, widgets, and other
symbols) so that whole sets can be included or excluded at once with
[TagInclude](TagInclude.md). Reach for it to bundle related tags under a single
label such as `:file` or `:crufty`.

**Scope:** global (`interchange.cfg`)

## Syntax

    TagGroup  groupname  "name1 name2 :othergroup ..."

One or more shell-quoted `groupname "member ..."` pairs. Members are the names
of code declarations found in the [TagDir](TagDir.md) directories; a member
beginning with `:` names another group, whose members are folded in. The group
name is referenced elsewhere with a leading colon (`:groupname`). Groups
accumulate. Default: a large built-in set of standard groups (`$StdTags`) that
Interchange ships with, defining the standard, core, and legacy tag bundles.

## Description

After scanning the [TagDir](TagDir.md) directories, Interchange assigns each
discovered symbol to the groups named in the `TagGroup` directives. Those group
names can then be passed to [TagInclude](TagInclude.md) (or to
[Require](Require.md)/[Suggest](Suggest.md) as `taggroup :name`) to compile a
bundle of tags in or out without listing each one. `TagGroup` only defines the
groupings; it does not by itself include or exclude anything.

`TagGroup` is processed at server start; changing it requires a restart.

## Examples

Define a `file` group and require it (in `interchange.cfg`):

```
TagGroup :file "counter file include log value_extended"

Require taggroup :file
```

Reference the group when choosing what to include:

```
TagInclude ALL !:file
```

## Notes

The default value is the built-in `$StdTags` set, which is large; override or
extend it only when you are managing custom tag bundles. Most catalogs adjust
which tags are active through [TagInclude](TagInclude.md) rather than by
redefining groups.

## See also

[TagInclude](TagInclude.md), [TagDir](TagDir.md), [CodeDef](CodeDef.md),
[Require](Require.md), [Suggest](Suggest.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_tag_group` in `lib/Vend/Config.pm`; consumed there via
`$Global::TagGroup` when symbols are assigned to groups and when
[TagInclude](TagInclude.md) is resolved.
