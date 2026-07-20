# MV_SUBJECT

Holds the subject of the special page currently being interpolated, as a safer
substitute for the `[subject]` placeholder. Reach for it in special-page
templates (such as email bodies) that need to reference their own subject.

**Scope:** runtime (set by the Interchange server; read-only)

## Syntax

    @@MV_SUBJECT@@

Default: none (set when a special page with a subject is rendered).

## Description

When the server renders a special page that carries a subject, it substitutes
the literal `[subject]` in the page and also stores the subject in
`$Global::Variable->{MV_SUBJECT}` before interpolating the page. Reading
`@@MV_SUBJECT@@` is a more secure alternative to the `[subject]` pseudo-tag,
because it is an ordinary variable reference rather than raw text interpolated
into the page.

## Examples

Reference the subject inside a special page:

    Subject was: @@MV_SUBJECT@@

## Notes

This variable is set by the server for the duration of a special page's
interpolation; it is not something you set in configuration.

## See also

The [email](../guides/email.md) and [templating](../guides/templating.md)
guides.

## Source

Set in `lib/Vend/Page.pm` (special-page rendering) via
`$Global::Variable->{MV_SUBJECT}`.
