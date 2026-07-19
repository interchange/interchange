# History

Sets how many of a visitor's most recent page requests Interchange keeps in the
session history. Reach for it to enable "return to your last search results"
style navigation, which reads back through this saved click history.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    History  COUNT

An integer number of clicks to retain. Default: `0` (history disabled).

## Description

When `History` is greater than zero, Interchange records each page request in a
per-session history list (`$Vend::Session->{History}`), trimming the oldest
entries so the list never exceeds `COUNT`. Each entry stores the path and its
form context, which lets the catalog send a visitor back to an earlier state --
for example returning to the exact search-results page they came from after
adding an item to the cart.

With `History` at its default of `0`, no history is recorded and history-based
navigation has nothing to draw on.

## Examples

Keep the ten most recent clicks (from the strap demo `catalog.cfg`):

```
History 10
```

## Notes

The count is a cap on stored entries, not a guarantee they all remain
meaningful -- requests marked no-cache are recorded as expired placeholders.
History lives in the session, so it is per visitor and cleared when the session
is.

## See also

[SessionExpire](SessionExpire.md), [SaveExpire](SaveExpire.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`; consumed by `url_history`
in `lib/Vend/Dispatch.pm`, which caps `$Vend::Session->{History}` at
`$Vend::Cfg->{History}` entries.
