# UserTag

Defines a custom Interchange Tag Language (ITL) tag -- an extension tag you
can call from pages like any built-in tag. Reach for it to package Perl (or
interpolatable HTML) behind a `[your-tag ...]` name, either server-wide or
for a single catalog.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    UserTag  tag-name  parameter  value

Three tokens: the tag name, a definition parameter, and its value. A tag is
built up over several `UserTag` lines, one parameter each. The primary
parameters:

| Parameter    | Meaning                                                     |
|--------------|-------------------------------------------------------------|
| `Routine`    | Perl `sub { ... }` that implements the tag                  |
| `Order`      | Space-separated names of the tag's positional attributes    |
| `Attr...`    | `attrAlias`, `addAttr`, `attrDefault` etc. to shape attrs   |
| `hasEndTag`  | Tag takes a body: `[tag]...[/tag]`                          |
| `Interpolate`| Interpolate the tag's output/body for further ITL           |
| `PosNumber`  | Number of positional parameters                             |
| `HTML`       | Treat the value as interpolatable HTML instead of a sub     |
| `Documentation`| Inline description                                        |

Names use word characters; hyphens in the tag name are converted to
underscores (so a tag defined as `my-tag` is invoked `[my-tag]` or
`[my_tag]`). Default: empty (no user tags beyond those Interchange ships).

Parsed by `parse_tag`. `UserTag` is the special case that defines an ITL
tag; the same directive machinery, delegated to `parse_mapped_code`, also
backs sibling code types such as [CodeDef](CodeDef.md).

## Description

The `Routine` sub receives the tag's parameters (positional values in
`Order`, then any named attributes, then the body if `hasEndTag` is set)
and returns the text that replaces the tag on the page. Interchange loads
its own core and system tags this way; the files under `code/` are
essentially large sets of `UserTag` lines.

### Global

Defined in `interchange.cfg` (typically via `include usertag/*.tag`), a
global user tag is available to every catalog on the server and its
`Routine` runs **without** [Safe](../glossary.md) restrictions -- it has
full Perl access. Use global tags for trusted, server-wide extensions.

### Catalog

Defined in `catalog.cfg`, a user tag belongs only to that catalog. Its
`Routine` is compiled inside a `Safe` compartment (unless the catalog is
listed in [AllowGlobal](AllowGlobal.md)), so it cannot reach outside the
sandbox -- the same restriction applies to embedded Perl in that catalog.
If a catalog tag has the same name as a global one, the local definition
overrides it and a warning is logged.

## Examples

A minimal global tag that returns a greeting (in a file included from
`interchange.cfg`):

```
UserTag  hello  Routine  sub { return "Hello, world!"; }
```

Called on a page:

```
[hello]
```

produces:

    Hello, world!

A tag with a positional parameter and a body:

```
UserTag  shout  Order      prefix
UserTag  shout  hasEndTag
UserTag  shout  Routine    <<EOR
sub {
    my ($prefix, $body) = @_;
    return $prefix . uc($body);
}
EOR
```

Called as:

```
[shout prefix="LOUD: "]quiet text[/shout]
```

produces:

    LOUD: QUIET TEXT

## Notes

Because a catalog-scope tag runs under `Safe`, operations such as opening
files or calling system routines are trapped; move such logic into a global
tag or list the catalog in [AllowGlobal](AllowGlobal.md) if it must run
unrestricted. The Perl inside a `Routine` is not evaluated until the tag is
first used.

## See also

[CodeDef](CodeDef.md), [AllowGlobal](AllowGlobal.md),
[TagInclude](TagInclude.md), [Variable](Variable.md), the
[perl-embedding](../guides/perl-embedding.md) and
[templating](../guides/templating.md) guides.

## Source

Parsed by `parse_tag` in `lib/Vend/Config.pm` (storing to
`$Global::UserTag` or `$C->{UserTag}`); the compiled `Routine` is invoked by
the tag interpolator in `lib/Vend/Interpolate.pm`.
