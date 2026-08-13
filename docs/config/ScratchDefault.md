# ScratchDefault

Defines initial values for scratch variables that Interchange assigns to
every new session. Reach for it to set per-session defaults -- such as URL
style flags or a default locale -- without setting them on every page.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ScratchDefault  name value [name value ...]

One or more `name value` pairs (`parse_hash`) merged into a hash. Default:
empty.

## Description

Scratch is Interchange's per-session scratchpad: named values (reached as
`$Scratch->{name}` in embedded Perl or with the
[scratch](../tags/scratch.md) and [seti](../tags/seti.md) tags) that persist
for the life of a session but not beyond it. When a new session is created,
Interchange copies the `ScratchDefault` hash into that session's scratch
space, so each listed name starts at the given value.

The hash is consumed in `lib/Vend/Session.pm` when a session's scratch is
initialized (and again in `lib/Vend/Interpolate.pm` and
`lib/Vend/UserDB.pm` where scratch defaults are re-applied). Common uses set
control flags that shape URLs and page behavior for the whole session.

## Examples

Produce cleaner URLs by suppressing the session ID and the page counter,
and appending `.html` (from the historic default style):

```
ScratchDefault  mv_no_session_id  1
ScratchDefault  mv_no_count       1
ScratchDefault  mv_add_dot_html   1
```

Set a default locale for the catalog:

```
ScratchDefault  mv_locale de_DE
```

Multiple pairs may share one line:

```
ScratchDefault  mv_no_session_id 1  mv_no_count 1
```

## Notes

Because these are only *defaults* applied at session creation, a page or
process that later changes the scratch value overrides them for that
session. See the [sessions](../guides/sessions.md) guide and the
[scratch](../glossary.md) glossary entry for background. To set default
form *values* rather than scratch, use [ValuesDefault](ValuesDefault.md).

## See also

[ValuesDefault](ValuesDefault.md), [scratch](../tags/scratch.md),
[HTMLsuffix](HTMLsuffix.md), the
[sessions](../guides/sessions.md) and
[internationalization](../guides/internationalization.md) guides.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; applied to new-session
scratch in `lib/Vend/Session.pm` (also `lib/Vend/Interpolate.pm`,
`lib/Vend/UserDB.pm`).
