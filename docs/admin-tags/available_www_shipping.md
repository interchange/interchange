# available_www_shipping

List the real-time ("www") shipping modes available on this server, based on
which shipping Perl modules are installed. Currently this means the UPS modes
offered when `Business::UPS` is present. Used in the admin UI shipping setup.
This tag is part of the Interchange admin UI toolset (the tags in
`code/UI_Tag/`, loaded when the admin UI feature is enabled), not a storefront
tag.

## Syntax

    [available_www_shipping]
    [available_www_shipping only]

Standalone tag (no end tag). In scalar context (ordinary ITL use) the return
value is a tab-and-newline option list; it is not reparsed as Interchange Tag
Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `only`    | none    | Restrict the check to one carrier. When set and it does not match `ups`, the UPS modes are skipped. |

Positional order: `only`.

## Description

`[available_www_shipping]` checks whether `Business::UPS` can be loaded (unless
`only` is set to a value that excludes UPS). If it can, the tag returns the
fixed list of supported UPS service codes and descriptions — Next Day Air,
2nd Day Air, Ground, Worldwide Express, and so on.

Output depends on calling context:

- In scalar context (normal tag use) it returns one line per mode of the form
  `UPSE:CODE<TAB>UPS: Description`, suitable for a select-widget option list.
- In list context (when called as `$Tag->available_www_shipping` from Perl) it
  returns a flat list of `code => { type, description }` pairs.

If the required module is not installed, the tag returns an empty string (or an
empty list).

## Examples

Populate a shipping-mode dropdown with the available real-time modes:

    [accessories attribute=ship_mode type=select
        passed="[available_www_shipping]"]

When `Business::UPS` is installed, the scalar output begins:

    UPSE:1DM	UPS: Next Day Air Early AM
    UPSE:1DML	UPS: Next Day Air Early AM Letter
    UPSE:1DA	UPS: Next Day Air
    ...

## Notes

The mode list is hard-coded in the tag; it reflects the UPS service set the tag
was written for and is not fetched live from the carrier. Whether the modes
appear at all is gated solely on `Business::UPS` being loadable.

## See also

- [available_ups_internal](available_ups_internal.md)
- [read_shipping](read_shipping.md)
- Concepts: [shipping](../guides/shipping.md)

## Source

Defined in `code/UI_Tag/available_www_shipping.coretag`. Implemented by the
inline Routine in that file.
