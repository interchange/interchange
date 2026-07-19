# local

Run a block of ITL with a temporary, private copy of scratch and/or values,
restoring the originals when the block ends. Reach for it when you want to
drop in code that sets scratch or form values without leaking those changes
to the rest of the page or session.

## Syntax

    [local scratch="name1 name2"] ... [/local]
    [local scratch="foo" values="bar" extra="carts"] ... [/local]

Container tag. The body is interpolated, then the saved state is restored.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `scratch` | (none)  | Space/quote-separated list of scratch keys to localize. |
| `values`  | (none)  | Space/quote-separated list of values (form) keys to localize. |
| `extra`   | (none)  | Additional session hash names to localize wholesale (e.g. `carts`), comma/space separated. |

Positional order: `scratch`.
Alias: `scratches` for `scratch`. Alias: `value` for `values`.

## Description

Interchange keeps several per-session data spaces: **scratch**
(`$Scratch`, page-scratch variables) and **values** (`$Values`, form field
values) among them. `[local]` snapshots the specific keys you name, runs the
body, then puts the snapshot back — so any `[set]`, `[value ... set=...]`,
or other mutation inside the block is undone afterward.

Snapshots are deep-copied (via `Storable::dclone`) so nested structures are
preserved, with one caveat: code references stored directly in a localized
top-level array are lost by the clone. Code references living in
non-localized keys survive untouched.

Keys named in `scratch=`/`values=` that do not exist when the block starts
are *deleted* on restore if the body created them, so localization is clean
in both directions. The `extra` attribute localizes an entire named session
hash (for example `carts`) rather than individual keys.

## Examples

Localize a single scratch variable so a change inside the block does not
persist:

    [set foo]bar[/set]

    [local scratch="foo"]
      [set foo]nonbar[/set]
      Inside: [scratch foo]
    [/local]

    Outside: [scratch foo]

produces:

    Inside: nonbar
    Outside: bar

Localize both a scratch and a form value at once:

    [local scratch="mode" values="quantity"]
      [set mode]preview[/set]
      ... code that reads [scratch mode] and [value quantity] ...
    [/local]

## Notes

Because the body is deep-copied and re-interpolated, localizing large
structures repeatedly has a cost; localize only the keys you actually
touch.

## See also

- [set](set.md), [seti](seti.md) — set scratch variables
- [scratch](scratch.md), [value](value.md) — read them back
- [tmp](tmp.md) — temporary variables with block scope in Perl terms
- [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/local.coretag` (inline `Routine`).
