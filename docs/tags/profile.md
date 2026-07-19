# profile

Activate a named order or search profile — a stored block of `mv_*` settings —
so it runs on subsequent form submissions, or run it immediately. Reach for it
to switch validation/behavior sets (for example a "dealer" checkout profile)
from within a page.

## Syntax

    [profile name]
    [profile name=dealer run=1]
    [profile restore=1]

Standalone tag (no end tag). By default the tag records the profile in the
session so it is applied on the next request; with `run=1` it also applies the
profile's configuration changes at once.

## Attributes

| Attribute | Default   | Description |
|-----------|-----------|-------------|
| `name`    | none      | The profile to activate (positional). |
| `tag`     | `default` | Namespace label under which the profile is registered in the session `Autoload`. |
| `set`     | see below | Register the profile to run on later requests. |
| `run`     | see below | Apply the profile's config changes immediately. |
| `restore` | none      | With no `name`, restore configuration saved before profiles were applied. |
| `joiner`  | `` ` ` `` (space) | Separator when listing active profiles (no `name` given). |
| `success` | empty     | Value returned when the operation succeeds. |
| `failure` | empty     | Value returned when the named profile does not exist. |

Positional order: `name`.

When neither `set` nor `run` is given, both default on, so `[profile dealer]`
both applies the `dealer` profile now and registers it for following requests.
Writing the name as `tag-name` (for example `[profile checkout-dealer]`) splits
off `checkout` as the `tag` namespace and forces `run=1`.

## Description

A *profile* is a named set of `mv_*` variables and configuration overrides kept
in the catalog's profile repository. Order profiles (see the `OrderProfile`
directive) drive checkout validation; search profiles drive canned searches.
`[profile]` is the ITL front end to that repository.

Called with a `name`, the tag:

1. Looks the profile up in `$Vend::Cfg->{Profile_repository}`. If it is not
   found, an error is logged and the `failure` value is returned.
2. With `run` on, copies the profile's values into the running configuration,
   saving the prior values so `restore` can undo them, and returns `success`.
3. With `set` on, adds `tag-name` to the session `Autoload` list (first
   removing any other profile registered under the same `tag`), so the profile
   is applied ahead of each subsequent page.

Called with no `name`, the tag returns the list of currently registered
profiles joined by `joiner`; with `restore=1` and no name it restores the
saved configuration and drops the matching `Autoload` entries.

## Examples

Activate the `dealer` profile — applied now and on the following requests:

    [profile dealer]

Apply a profile immediately without registering it for later:

    [profile name=guest run=1 set=0]

Clear a previously set profile and restore normal configuration:

    [profile restore=1]

## Notes

Profile names must match `[A-Za-z_]+`; invalid characters cause an error and
the `failure` value to be returned. The set of runnable profiles comes from the
catalog configuration (`OrderProfile`, `SearchProfile`, and related
directives), not from this tag — `[profile]` only selects among them.

## See also

- [update](update.md), [search](search.md)
- Concepts: [cart and checkout](../guides/cart-and-checkout.md),
  [forms](../guides/forms.md), [configuration](../guides/configuration.md)

## Source

Defined in `code/SystemTag/profile.coretag`. Implemented by
`Vend::Interpolate::tag_profile`.
