# restrict

Restricts which Interchange Tag Language (ITL) tags may execute inside its
body, so you can safely interpolate text of uncertain origin — a stored
template, an admin-edited field, a user-submitted snippet. Any tag not
permitted is passed through as literal text instead of running. Reach for it
whenever you must parse ITL you do not fully trust.

## Syntax

    [restrict]BODY[/restrict]
    [restrict enable="tag1 tag2"]BODY[/restrict]
    [restrict policy=allow disable="tag1 tag2"]BODY[/restrict]

Container tag (has an end tag). Its body is interpolated under the restriction
policy; the body is *not* automatically reparsed afterward (it is in the
parser's `%NoReparse` set), because `[restrict]` interpolates the body itself.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `enable`  | (none)  | Whitelist: tags still allowed under a `deny` policy. |
| `disable` | (none)  | Blacklist: tags forbidden. Overrides `enable`. |
| `policy`  | `deny`  | `deny` forbids all tags except `enable`; `allow` permits all except `disable`. |
| `log`     | `all`   | How loudly to log refused tags: `all`, `once`, or `none`. |

Positional order: `enable`. Both `enable` and `disable` accept
space-separated or comma-separated tag names.

## Description

`[restrict]` builds a per-block restriction table covering every known tag and
installs it for the duration of its body:

- **`policy=deny`** (the default, and the safe choice) forbids every tag,
  then re-enables only those named in `enable`.
- **`policy=allow`** permits every tag, then forbids only those named in
  `disable`.

`disable` always wins over `enable`. Tags that are already admin-restricted
in the catalog stay forbidden regardless of policy, so `[restrict]` can only
tighten access, never loosen it below the catalog's own limits. Restrictions
also nest — an inner `[restrict]` composes with the outer one.

When the parser reaches a forbidden tag inside the block, it does **not**
execute it: the tag's literal source text is emitted instead, and a message
is logged according to `log` (`all` logs every attempt, `once` logs the first
occurrence of each, `none` stays silent):

    Restricted tag (...) attempted during restriction '...'

Note what `[restrict]` does and does not cover. It constrains *tags*. Perl in
`[perl]`/`[calc]` is separately constrained by the catalog's Safe
compartment. And data emitted by tags like [value](value.md) is separately
protected by the escaping of `[` to `&#91;` (see the
[safe_data](../pragmas/safe_data.md) pragma). For untrusted input you
generally want all three protections; the [security](../guides/security.md)
guide covers how they fit together.

## Examples

Interpolate a snippet allowing only a safe handful of display tags —
everything else is shown literally and logged:

    [restrict enable="page area value data"]
    [value greeting]         <- runs
    [include /etc/passwd]    <- refused, emitted as text, logged
    [/restrict]

Deny everything (the default) to display a stored template as inert text:

    [restrict]
    [calc]... anything ...[/calc]
    [/restrict]

Allow-by-exception, forbidding just the dangerous tags, and log only once per
tag:

    [restrict policy=allow disable="perl calc mvasp file include" log=once]
    ... mostly-trusted template body ...
    [/restrict]

## Notes

Prefer the default `deny` policy with an explicit `enable` list for genuinely
untrusted input: it fails closed, so a tag you forgot to consider is refused
rather than run. `policy=allow` is appropriate only when you are excluding a
known-bad, exhaustively-listed set.

`[restrict]` invalidates page caching for the block.

## See also

The [security](../guides/security.md) guide (the `[restrict]` and Safe
compartment sections) and the [templating](../guides/templating.md) guide;
the [safe_data](../pragmas/safe_data.md) pragma; [value](value.md),
[perl](perl.md), [calc](calc.md).

## Source

Defined inline in `lib/Vend/Parse.pm` as `$Routine{restrict}`, which builds
the restriction table (`$Vend::Cfg->{AdminSub}`, `$Vend::restricted`) and
interpolates the body under it. Enforcement — emitting a forbidden tag as
literal text and logging it — is in `Vend::Parse::start`.
