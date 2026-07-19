# FileControl

Maps a file or directory path to a Perl routine that decides, per access,
whether Interchange may read or write it. Reach for it to enforce custom access
rules on catalog files beyond the built-in owner/group checks.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    FileControl  path  CODE

`path` is a file or directory path (relative to the catalog). `CODE` is one of:

- an anonymous Perl subroutine, `sub { ... }` (commonly a here-document);
- the name of a defined [Sub](Sub.md)/[GlobalSub](GlobalSub.md);
- a mapped routine name such as `Vend::YourModule::file_control`.

The directive accumulates: each line registers one path-to-routine mapping.
Default: empty (no file-control routines; only the standard permission checks
apply).

## Description

Whenever Interchange is about to read or write a file through its safe file
layer (`allowed_file`), it consults the registered `FileControl` routines. The
lookup walks up the path: it tries the exact path, then each parent directory,
until it finds a registered routine or runs out of components. The first match
decides.

The routine is called with the filename, the matched path, a write flag, and
Perl caller information; it must return a boolean -- a true value allows the
access, a false value denies it. A denied access is logged as "Denied
read/write access to ... by FileControl".

### Global

A global `FileControl` in `interchange.cfg` (stored in `$Global::FileControl`)
is checked for every catalog, before any catalog-level routine. Global control
routines run outside the `Safe` compartment.

### Catalog

A catalog `FileControl` in `catalog.cfg` applies to that catalog only and is
checked after the global routines. Both must allow the access for it to
proceed. The superuser bypasses catalog-level (but not global) control.

## Examples

Decide read and write access with an inline routine (`catalog.cfg`):

```
FileControl test_page <<EOR
sub {
    my ($fn, $path, $write, @caller) = @_;

    # Allow writes only to files whose name contains "foo"
    return $fn =~ /foo/ if $write;

    # Allow reads except for files whose name contains "bar"
    return $fn !~ /bar/;
}
EOR
```

Use a named [Sub](Sub.md) instead of inline code:

```
Sub <<EOF
sub filecontrol_access {
    my ($fn, $path, $write, @caller) = @_;
    return $fn =~ /foo/ if $write;
    return $fn !~ /bar/;
}
EOF

FileControl test_directory/test_page filecontrol_access
```

In `interchange.cfg`, a mapped package routine can be used globally:

```
FileControl test_page Vend::YourModule::file_control
```

## Notes

`FileControl` is parsed like [ActionMap](ActionMap.md) and
[FormAction](FormAction.md) but drives file-access decisions rather than URL
dispatch. Its checks compose with [NoAbsolute](NoAbsolute.md) and the
owner/group permission checks; all applicable checks must pass.

## See also

[ActionMap](ActionMap.md), [FormAction](FormAction.md),
[NoAbsolute](NoAbsolute.md), [Sub](Sub.md), [GlobalSub](GlobalSub.md),
[AllowGlobal](AllowGlobal.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_action` in `lib/Vend/Config.pm`; consumed by `file_control`
and `allowed_file` in `lib/Vend/File.pm`.
