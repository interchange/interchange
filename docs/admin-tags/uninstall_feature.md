# uninstall_feature

Remove a catalog feature that was previously installed through Interchange's
Feature mechanism, reversing the files and configuration that feature added.
This tag is part of the admin UI toolset (registered from `code/UI_Tag/` and
loaded only when the administrative interface is enabled), not a storefront tag.

## Syntax

    [uninstall_feature name]
    [uninstall_feature name=feature]

Standalone tag (no end tag). Runs for its side effects (removing the feature).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Name of the feature to uninstall (a subdirectory of the global feature directory). |

Positional order: `name`.

## Description

A *feature* is a packaged bundle of pages, configuration, and initialization
files kept under the server's feature directory (`$Global::FeatureDir`) and
installed into a catalog via the Feature mechanism. This tag uninstalls one such
feature by name: it locates the feature's directory, and if found, works through
its `.global`, `.init`, `.uninstall`, and configuration files to undo what the
feature added to the current catalog. If no directory matches the given name, it
issues a configuration warning (`Feature '<name>' not found, skipping.`) and does
nothing.

The tag must run in catalog context (it dies with `Not in catalog context.`
otherwise), so invoke it from an administrative catalog page.

## Examples

Uninstall a feature named `reviews`:

    [uninstall_feature reviews]

Uninstall using the named attribute form:

    [uninstall_feature name=gift_certs]

## Notes

Because uninstalling a feature edits catalog files and configuration, run it only
from properly gated admin pages, and expect to
[reconfig](reconfig.md) the catalog afterward so the removed configuration stops
taking effect.

## See also

- [reconfig](reconfig.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [configuration](../guides/configuration.md)

## Source

Defined in `code/UI_Tag/uninstall_feature.tag`, registered as the UserTag
`uninstall_feature`. Implemented by `Vend::Config::uninstall_feature`
(MapRoutine).
