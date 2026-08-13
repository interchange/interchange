# uneval

Serialize a Perl data structure to a Perl-source string, for dumping a session
element or a passed reference while debugging. This tag is part of the admin UI
toolset (registered from `code/UI_Tag/` and loaded only when the administrative
interface is enabled), not a storefront tag.

## Syntax

    [uneval name=session_key]
    [uneval ref="[perl] return \%some_hash; [/perl]"]

Standalone tag (no end tag). Returns the serialized string produced by
`Vend::Util::uneval`.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | none    | Key into the current session hash (`$Vend::Session`) whose value is serialized when no `ref` is given. |
| `ref`     | none    | A reference to serialize directly; overrides `name`. |

Positional order: `name` (the single positional parameter; pass `ref` as a named
attribute).

## Description

When `ref` is supplied, the tag serializes that reference. Otherwise it looks up
`name` in the current session hash (`$Vend::Session->{name}`) and serializes
that. The output is Perl source — the same representation Interchange uses
internally to store nested structures — so it is most useful for inspecting what
is actually held in the session (carts, values, scratch, and similar) or the
shape of a structure you built in embedded Perl.

## Examples

Dump the session's shopping carts:

    [uneval name=carts]

Dump the session's form values:

    [uneval name=values]

Serialize a structure produced inline:

    [uneval ref="[perl] return { sku => 'os28004', qty => 2 }; [/perl]"]

produces:

    {
      qty => 2,
      sku => 'os28004'
    }

## Notes

This is a debugging aid; the serialized output can be large for a busy session
and is not meant for display to shoppers. It is the tag form of the same
`uneval` routine used throughout the server.

## See also

- [dump_session](dump_session.md)
- Concepts: [sessions](../guides/sessions.md),
  [logging and debugging](../guides/logging-debugging.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/uneval.coretag`, registered as the UserTag `uneval`.
Implemented with `Vend::Util::uneval` (inline Routine).
