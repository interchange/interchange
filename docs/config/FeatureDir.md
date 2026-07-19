# FeatureDir

Names the directory that holds installable Interchange *features* -- bundles of
configuration and files that a catalog pulls in with the [Feature](Feature.md)
directive. Set it once, globally, to point at wherever your feature bundles
live.

**Scope:** global (`interchange.cfg`)

## Syntax

    FeatureDir  DIRECTORY

A single directory. A relative path is made absolute against the Interchange
root (`Global::VendRoot`); trailing slashes are stripped. Default: `features`
(that is, the `features/` directory under the Interchange root).

## Description

A *feature* is a small directory of files -- catalog-config fragments, global
config, init scripts, and files to copy into the catalog -- that adds a piece
of functionality to a catalog. When a `catalog.cfg` names one with
[Feature](Feature.md), Interchange looks for a subdirectory of that name inside
`FeatureDir` and installs its contents.

`FeatureDir` sets the search root for that lookup. It is read at server startup
and used by the feature installer; a catalog's `Feature quickpoll` line, for
instance, resolves to `FeatureDir/quickpoll`.

## Examples

Use the default location under the Interchange root:

```
FeatureDir  features
```

Point at an absolute path shared across installations:

```
FeatureDir  /usr/local/interchange/features
```

## See also

[Feature](Feature.md), [Require](Require.md), [Capability](Capability.md).

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm`; consumed by
`parse_feature` in the same file, which joins `$Global::FeatureDir` with the
feature name to locate the feature directory.
